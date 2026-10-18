"use client";

import { usePathname, useRouter } from "next/navigation";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import { CloseIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { chatCache, messagePreview } from "@/lib/chat";
import { useRealtime } from "@/lib/realtime";
import type { Message } from "@/lib/types";

type OpenOpts = { pin?: number; text?: string };

type ChatState = {
  /** Unread messages in all chats. */
  unread: number;
  refreshUnread: () => void;
  /** The conversation on screen (null when none). */
  activeChatId: number | null;
  setActiveChat: (id: number | null) => void;
  /** chatId → time until which the other side counts as typing. */
  typing: Record<number, number>;
  /** Opens (or creates) the chat with a user and goes to it; logs in first when needed. */
  openChat: (username: string, opts?: OpenOpts) => Promise<void>;
};

const ChatContext = createContext<ChatState | null>(null);

export function useChat(): ChatState {
  const ctx = useContext(ChatContext);
  if (!ctx) throw new Error("useChat must be used inside <ChatProvider>");
  return ctx;
}

/** true while the other side of this chat is typing. */
export function useTyping(chatId: number | null | undefined): boolean {
  const { typing } = useChat();
  return !!chatId && (typing[chatId] ?? 0) > Date.now();
}

const TYPING_MS = 4500;

type Pop = { key: number; chatId: number; message: Message };

const tabActive = () => document.visibilityState === "visible" && document.hasFocus();

export function ChatProvider({ children }: { children: React.ReactNode }) {
  const { user, refreshUnread: refreshNotes } = useAuth();
  const router = useRouter();
  const path = usePathname();
  const toast = useToast();
  const [unread, setUnread] = useState(0);
  const [activeChatId, setActive] = useState<number | null>(null);
  const activeRef = useRef<number | null>(null);
  const [typing, setTyping] = useState<Record<number, number>>({});
  const [pops, setPops] = useState<Pop[]>([]);
  const timer = useRef(0);
  const userId = user?.id ?? 0;

  const setActiveChat = useCallback((id: number | null) => {
    activeRef.current = id;
    setActive(id);
    if (id) setPops((l) => l.filter((p) => p.chatId !== id));
  }, []);

  const refreshUnread = useCallback(() => {
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      api.chatUnread().then((r) => setUnread(r.count ?? 0), () => {});
    }, 250);
  }, []);

  useEffect(() => {
    if (!userId) {
      setUnread(0);
      setTyping({});
      setPops([]);
      return;
    }
    refreshUnread();
    const onFocus = () => refreshUnread();
    window.addEventListener("focus", onFocus);
    return () => window.removeEventListener("focus", onFocus);
  }, [userId, refreshUnread]);

  // Expire typing flags.
  const nextTypingEnd = Math.min(Infinity, ...Object.values(typing));
  useEffect(() => {
    if (!Number.isFinite(nextTypingEnd)) return;
    const t = window.setTimeout(() => {
      const now = Date.now();
      setTyping((m) => Object.fromEntries(Object.entries(m).filter(([, until]) => until > now + 50)));
    }, Math.max(50, nextTypingEnd - Date.now()));
    return () => window.clearTimeout(t);
  }, [nextTypingEnd]);

  useRealtime("typing", ({ chatId, userId: who }) => {
    if (who === userId) return;
    setTyping((m) => ({ ...m, [chatId]: Date.now() + TYPING_MS }));
  });

  useRealtime("message", ({ chatId, message }) => {
    if (message.mine) return;
    setTyping((m) => {
      if (!m[chatId]) return m;
      const next = { ...m };
      delete next[chatId];
      return next;
    });
    refreshUnread();
    const open = activeRef.current === chatId;
    if (open && tabActive()) return;
    // On /messages the chat list itself shows the new message.
    const listVisible = window.location.pathname === "/messages";
    if (document.visibilityState === "visible" && !open && !listVisible) {
      setPops((l) => [...l.filter((p) => p.chatId !== chatId).slice(-2), { key: message.id, chatId, message }]);
    }
    if (typeof Notification !== "undefined" && Notification.permission === "granted" && !tabActive()) {
      try {
        const n = new Notification(message.sender.name || message.sender.username, {
          body: messagePreview(message, false),
          icon: message.sender.avatarUrl || "/icon.svg",
          tag: `chat-${chatId}`,
        });
        n.onclick = () => {
          window.focus();
          router.push(`/messages/${chatId}`);
          n.close();
        };
      } catch {
        /* some mobile browsers only allow notifications from a service worker */
      }
    }
  });

  useRealtime("message_deleted", () => refreshUnread());
  useRealtime("chat:read", () => refreshUnread());
  useRealtime("reconnect", () => {
    refreshUnread();
    refreshNotes();
  });

  // Auto-dismiss in-app message toasts.
  useEffect(() => {
    if (!pops.length) return;
    const t = window.setTimeout(() => setPops((l) => l.slice(1)), 5000);
    return () => window.clearTimeout(t);
  }, [pops]);

  // "(3) ModaHouse": unread messages in the tab title, kept in place when pages change the title.
  useEffect(() => {
    const apply = () => {
      const base = document.title.replace(/^\(\d+\+?\) /, "");
      const want = unread > 0 ? `(${unread > 99 ? "99+" : unread}) ${base}` : base;
      if (document.title !== want) document.title = want;
    };
    apply();
    const obs = new MutationObserver(apply);
    obs.observe(document.head, { subtree: true, childList: true, characterData: true });
    return () => obs.disconnect();
  }, [unread]);

  const openChat = useCallback(async (username: string, opts: OpenOpts = {}) => {
    if (!user) {
      const here = window.location.pathname + window.location.search;
      router.push(`/login?next=${encodeURIComponent(here)}`);
      return;
    }
    try {
      const chat = await api.openChat(username);
      chatCache.set(chat.id, chat);
      const q = new URLSearchParams();
      if (opts.pin) q.set("pin", String(opts.pin));
      if (opts.text) q.set("text", opts.text);
      const s = q.toString();
      router.push(`/messages/${chat.id}${s ? `?${s}` : ""}`);
    } catch (e) {
      toast(errorMessage(e), "error");
    }
  }, [user, router, toast]);

  const value = useMemo<ChatState>(() => ({
    unread, refreshUnread, activeChatId, setActiveChat, typing, openChat,
  }), [unread, refreshUnread, activeChatId, setActiveChat, typing, openChat]);

  const onMessages = path.startsWith("/messages");

  return (
    <ChatContext.Provider value={value}>
      {children}
      {pops.length > 0 && (
        <div className={`chat-pops ${onMessages ? "on-messages" : ""}`} aria-live="polite">
          {pops.map((p) => (
            <div key={p.key} className="chat-pop" role="status">
              <button
                type="button"
                className="chat-pop-body"
                onClick={() => {
                  setPops((l) => l.filter((x) => x.key !== p.key));
                  router.push(`/messages/${p.chatId}`);
                }}
              >
                <Avatar user={p.message.sender} size={40} />
                <span className="chat-pop-text">
                  <strong>{p.message.sender.name || p.message.sender.username}</strong>
                  <span>{messagePreview(p.message, false)}</span>
                </span>
              </button>
              <button type="button" className="chat-pop-close" aria-label="Ýap" onClick={() => setPops((l) => l.filter((x) => x.key !== p.key))}>
                <CloseIcon size={16} />
              </button>
            </div>
          ))}
        </div>
      )}
    </ChatContext.Provider>
  );
}

/** Small banner on the messages page asking for browser notifications (never asked on load). */
export function NotifyBanner() {
  const [show, setShow] = useState(false);
  useEffect(() => {
    if (typeof Notification === "undefined" || Notification.permission !== "default") return;
    try {
      if (window.localStorage.getItem("mh_notify_dismissed")) return;
    } catch {
      /* ignore */
    }
    setShow(true);
  }, []);
  if (!show) return null;
  const dismiss = () => {
    setShow(false);
    try {
      window.localStorage.setItem("mh_notify_dismissed", "1");
    } catch {
      /* ignore */
    }
  };
  return (
    <div className="notify-banner">
      <span>Täze habarlar barada bildiriş alyň</span>
      <button
        type="button"
        className="btn btn-primary btn-sm"
        onClick={() => {
          Notification.requestPermission().then(() => setShow(false), () => setShow(false));
        }}
      >
        Rugsat ber
      </button>
      <button type="button" className="icon-btn notify-close" aria-label="Ýap" onClick={dismiss}><CloseIcon size={16} /></button>
    </div>
  );
}
