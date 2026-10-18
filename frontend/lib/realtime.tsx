"use client";

// One app-wide Server-Sent Events connection (GET /api/events) while the visitor is logged in,
// plus a tiny event bus: `useRealtime("message", handler)`.
//
// The browser's own EventSource retry is replaced by exponential backoff (1 s → 30 s); the stream
// reconnects right away when the network comes back or the tab becomes visible. Events sent while
// offline are not replayed, so after a reconnect a synthetic "reconnect" event tells pages to refetch.

import { createContext, useContext, useEffect, useRef, useState } from "react";
import { api, getToken, normMessage } from "./api";
import { useAuth } from "./auth";
import type { Chat, Message, Notification } from "./types";

export type RealtimeEvents = {
  /** Server hello after (re)connecting. */
  ready: { userId: number };
  message: { chatId: number; message: Message };
  message_deleted: { chatId: number; messageId: number };
  /** The other side read up to messageId. */
  read: { chatId: number; userId: number; messageId: number };
  typing: { chatId: number; userId: number };
  notification: { notification: Notification; unreadCount: number };
  /** Local: the stream came back after a drop; refetch what is on screen. */
  reconnect: Record<string, never>;
  /** Local: this client marked a chat read. */
  "chat:read": { chatId: number };
  /** Local: a chat was opened or loaded (the chat list adds it if missing). */
  "chat:upsert": { chat: Chat };
};

export type RealtimeEvent = keyof RealtimeEvents;
type Handler<E extends RealtimeEvent> = (data: RealtimeEvents[E]) => void;

const handlers = new Map<RealtimeEvent, Set<Handler<RealtimeEvent>>>();

/** Dispatches an event to every subscriber (server events and local ones alike). */
export function emit<E extends RealtimeEvent>(event: E, data: RealtimeEvents[E]) {
  const set = handlers.get(event);
  if (!set) return;
  for (const h of Array.from(set)) {
    try {
      (h as Handler<E>)(data);
    } catch (e) {
      console.error(`realtime ${event} handler`, e);
    }
  }
}

/** Subscribes to an event for the component's lifetime; the latest handler is always used. */
export function useRealtime<E extends RealtimeEvent>(event: E, handler: Handler<E>) {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => {
    const fn: Handler<E> = (d) => ref.current(d);
    let set = handlers.get(event);
    if (!set) handlers.set(event, (set = new Set()));
    set.add(fn as Handler<RealtimeEvent>);
    return () => { set.delete(fn as Handler<RealtimeEvent>); };
  }, [event]);
}

const SERVER_EVENTS: RealtimeEvent[] = ["ready", "message", "message_deleted", "read", "typing", "notification"];
const MIN_DELAY = 1000;
const MAX_DELAY = 30_000;

const ConnectedContext = createContext(false);
/** true while the event stream is open. */
export const useRealtimeConnected = () => useContext(ConnectedContext);

export function RealtimeProvider({ children }: { children: React.ReactNode }) {
  const { user, setUnread } = useAuth();
  const userId = user?.id ?? 0;
  const [connected, setConnected] = useState(false);
  const setUnreadRef = useRef(setUnread);
  setUnreadRef.current = setUnread;

  useEffect(() => {
    if (!userId) return;
    let es: EventSource | null = null;
    let timer = 0;
    let delay = MIN_DELAY;
    let failures = 0;
    let everConnected = false;
    let stopped = false;

    const clear = () => {
      window.clearTimeout(timer);
      timer = 0;
      if (es) {
        es.close();
        es = null;
      }
    };

    const connect = () => {
      clear();
      const token = getToken();
      if (stopped || !token) return;
      const src = new EventSource(`/api/events?token=${encodeURIComponent(token)}`);
      es = src;

      src.addEventListener("ready", () => {
        delay = MIN_DELAY;
        failures = 0;
        setConnected(true);
        if (everConnected) emit("reconnect", {});
        everConnected = true;
      });
      for (const name of SERVER_EVENTS) {
        src.addEventListener(name, (ev) => {
          let data: unknown;
          try {
            data = JSON.parse((ev as MessageEvent<string>).data || "{}");
          } catch {
            return;
          }
          if (name === "message") {
            const d = data as RealtimeEvents["message"];
            if (!d?.message) return;
            data = { chatId: d.chatId ?? d.message.chatId, message: normMessage(d.message) };
          }
          if (name === "notification") {
            const d = data as RealtimeEvents["notification"];
            if (typeof d?.unreadCount === "number") setUnreadRef.current(d.unreadCount);
          }
          emit(name, data as RealtimeEvents[typeof name]);
        });
      }
      src.onerror = () => {
        if (es !== src) return;
        // Take over from the browser's fixed retry: back off 1 s, 2 s, 4 s … 30 s.
        src.close();
        es = null;
        setConnected(false);
        failures += 1;
        // A rejected token never recovers: let the normal API path find out (401 logs out).
        if (failures >= 2) api.chatUnread().catch(() => {});
        const wait = Math.min(MAX_DELAY, delay) * (0.8 + Math.random() * 0.4);
        delay = Math.min(MAX_DELAY, delay * 2);
        timer = window.setTimeout(connect, wait);
      };
    };

    const kick = () => {
      if (stopped || es) return;
      delay = MIN_DELAY;
      connect();
    };
    const onVisible = () => document.visibilityState === "visible" && kick();
    const onOffline = () => {
      // Drop the dead socket now; "online" reconnects at once.
      if (!es) return;
      clear();
      setConnected(false);
    };

    connect();
    window.addEventListener("online", kick);
    window.addEventListener("offline", onOffline);
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      stopped = true;
      clear();
      setConnected(false);
      window.removeEventListener("online", kick);
      window.removeEventListener("offline", onOffline);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [userId]);

  return <ConnectedContext.Provider value={connected}>{children}</ConnectedContext.Provider>;
}
