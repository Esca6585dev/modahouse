"use client";

import { useEffect, useMemo, useState } from "react";
import { CheckIcon, SearchIcon, SendIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { chatCache, newClientId } from "@/lib/chat";
import { emit } from "@/lib/realtime";
import type { Chat, ChatUser, Pin } from "@/lib/types";
import { ChatAvatar, ChatName } from "./ChatBits";
import { useChat } from "./ChatProvider";

type Row = { key: string; user: ChatUser; chat: Chat | null };

/**
 * Recent chats plus a user search. mode "share" sends a post to the selected people (with an
 * optional message); mode "new" opens the conversation with the person picked.
 */
export default function ChatPicker({ mode, pin, onDone }: { mode: "share" | "new"; pin?: Pin; onDone: () => void }) {
  const { user } = useAuth();
  const { openChat } = useChat();
  const toast = useToast();
  const [chats, setChats] = useState<Chat[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [found, setFound] = useState<ChatUser[]>([]);
  const [searching, setSearching] = useState(false);
  const [picked, setPicked] = useState<Map<string, Row>>(new Map());
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let alive = true;
    api.chats(1, 40).then((pg) => alive && setChats(pg.items), (e) => alive && setLoadError(errorMessage(e)));
    return () => { alive = false; };
  }, []);

  const query = q.trim();
  useEffect(() => {
    if (query.length < 2) {
      setFound([]);
      setSearching(false);
      return;
    }
    let alive = true;
    setSearching(true);
    const t = window.setTimeout(() => {
      api.search(query).then(
        (r) => alive && setFound(r.users),
        () => alive && setFound([]),
      ).finally(() => alive && setSearching(false));
    }, 250);
    return () => { alive = false; window.clearTimeout(t); };
  }, [query]);

  const rows = useMemo<Row[]>(() => {
    const s = query.toLocaleLowerCase("tk");
    const fromChats = (chats ?? [])
      .filter((c) => !c.blocked)
      .filter((c) => !s || c.other.name.toLocaleLowerCase("tk").includes(s) || c.other.username.toLowerCase().includes(s))
      .map<Row>((c) => ({ key: c.other.username, user: c.other, chat: c }));
    const have = new Set(fromChats.map((r) => r.key));
    const fromSearch = found
      .filter((u) => u.username !== user?.username && !have.has(u.username))
      .map<Row>((u) => ({ key: u.username, user: u, chat: (chats ?? []).find((c) => c.other.username === u.username) ?? null }))
      .filter((r) => !r.chat?.blocked);
    return [...fromChats, ...fromSearch];
  }, [chats, found, query, user?.username]);

  const toggle = (r: Row) => setPicked((m) => {
    const next = new Map(m);
    if (next.has(r.key)) next.delete(r.key);
    else next.set(r.key, r);
    return next;
  });

  const choose = async (r: Row) => {
    if (mode === "share") return toggle(r);
    setBusy(true);
    try {
      await openChat(r.user.username);
      onDone();
    } finally {
      setBusy(false);
    }
  };

  const send = async () => {
    if (!pin || picked.size === 0) return;
    setBusy(true);
    let ok = 0;
    let lastError = "";
    for (const r of Array.from(picked.values())) {
      try {
        const chat = r.chat ?? (await api.openChat(r.user.username));
        chatCache.set(chat.id, chat);
        const message = await api.sendMessage(chat.id, { text: text.trim(), pinId: pin.id, clientId: newClientId() });
        emit("chat:upsert", { chat: { ...chat, lastMessage: message, updatedAt: message.createdAt } });
        emit("message", { chatId: chat.id, message });
        ok += 1;
      } catch (e) {
        lastError = `${r.user.name || r.user.username}: ${errorMessage(e)}`;
      }
    }
    setBusy(false);
    if (lastError) toast(lastError, "error");
    if (ok) {
      toast(ok === 1 ? "Ugradyldy" : `${ok} adama ugradyldy`);
      onDone();
    }
  };

  const loading = chats === null && !loadError;

  return (
    <div className={`chat-picker mode-${mode}`}>
      {mode === "share" && pin && (
        <div className="cp-pin">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={pin.images[0]?.type === "video" ? pin.images[0].posterUrl || pin.imageUrl : pin.imageUrl} alt="" style={{ background: pin.color || undefined }} />
          <span>{pin.title}</span>
        </div>
      )}
      <label className="chat-search">
        <SearchIcon size={17} />
        <input
          type="search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Ady ýa-da @ulanyjy ady"
          aria-label="Adam gözle"
          autoComplete="off"
        />
      </label>

      <div className="cp-list" role="listbox" aria-multiselectable={mode === "share"} aria-label="Adamlar">
        {loading ? (
          <p className="cp-state"><span className="spinner" /></p>
        ) : loadError && rows.length === 0 ? (
          <p className="cp-state error-text">{loadError}</p>
        ) : rows.length === 0 ? (
          <p className="cp-state muted">
            {searching ? <span className="spinner" /> : query.length >= 2 ? "Hiç kim tapylmady" : "Heniz habarlaşyk ýok. Ady boýunça gözläň"}
          </p>
        ) : (
          <>
            {!query && <p className="cp-caption">Soňky habarlaşyklar</p>}
            {rows.map((r) => {
              const on = picked.has(r.key);
              return (
                <button
                  key={r.key}
                  type="button"
                  role="option"
                  aria-selected={on}
                  className={`cp-row ${on ? "on" : ""}`}
                  onClick={() => choose(r)}
                  disabled={busy && mode === "new"}
                >
                  <ChatAvatar user={r.user} size={44} />
                  <span className="cp-text">
                    <ChatName user={r.user} />
                    <span className="muted">@{r.user.username}</span>
                  </span>
                  {mode === "share" && <span className="cp-check" aria-hidden>{on && <CheckIcon size={14} />}</span>}
                </button>
              );
            })}
          </>
        )}
      </div>

      {mode === "share" && (
        <div className="cp-foot">
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Habar ýazyň (hökman däl)"
            maxLength={2000}
            aria-label="Habar"
            onKeyDown={(e) => e.key === "Enter" && !e.nativeEvent.isComposing && send()}
          />
          <button type="button" className="btn btn-primary" disabled={!picked.size || busy} onClick={send}>
            {busy ? <span className="spinner light" /> : <SendIcon size={18} />}
            {picked.size > 1 ? `Ugrat (${picked.size})` : "Ugrat"}
          </button>
        </div>
      )}
    </div>
  );
}
