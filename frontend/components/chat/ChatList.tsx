"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { EditIcon, SearchIcon, SendIcon } from "@/components/Icons";
import { InfiniteFooter } from "@/components/Masonry";
import Modal from "@/components/Modal";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { chatCache, messagePreview, shortAgo, sortChats } from "@/lib/chat";
import { usePaged } from "@/lib/hooks";
import { useRealtime } from "@/lib/realtime";
import type { Chat } from "@/lib/types";
import { ChatAvatar, ChatName } from "./ChatBits";
import ChatPicker from "./ChatPicker";
import { NotifyBanner, useChat, useTyping } from "./ChatProvider";

function ChatRow({ chat, active }: { chat: Chat; active: boolean }) {
  const typing = useTyping(chat.id);
  const m = chat.lastMessage;
  const unread = chat.unreadCount > 0 && !active;
  return (
    <Link
      href={`/messages/${chat.id}`}
      className={`chat-row ${active ? "active" : ""} ${unread ? "unread" : ""}`}
      aria-current={active ? "page" : undefined}
      onClick={() => chatCache.set(chat.id, chat)}
    >
      <ChatAvatar user={chat.other} />
      <span className="chat-row-main">
        <span className="chat-row-top">
          <ChatName user={chat.other} />
          {m && <time className="chat-row-time" dateTime={m.createdAt}>{shortAgo(m.createdAt)}</time>}
        </span>
        <span className="chat-row-bottom">
          {typing ? (
            <span className="chat-row-typing">ýazýar…</span>
          ) : (
            <span className={`chat-row-preview ${m?.deleted ? "deleted" : ""}`}>
              {m ? messagePreview(m) : chat.blocked ? "Bu ulanyja ýazyp bolmaýar" : `@${chat.other.username}`}
            </span>
          )}
          {unread ? (
            <span className="chat-unread" aria-label={`${chat.unreadCount} okalmadyk habar`}>{chat.unreadCount > 99 ? "99+" : chat.unreadCount}</span>
          ) : m?.mine && !m.deleted ? (
            <span className={`chat-row-tick ${m.read ? "read" : ""}`} aria-label={m.read ? "Okaldy" : "Ugradyldy"}>{m.read ? "✓✓" : "✓"}</span>
          ) : null}
        </span>
      </span>
    </Link>
  );
}

const tabActive = () => document.visibilityState === "visible" && document.hasFocus();

export default function ChatList({ activeId }: { activeId: number | null }) {
  const { user } = useAuth();
  const { activeChatId } = useChat();
  const paged = usePaged<Chat>(user ? `chats:${user.id}` : null, (page) => api.chats(page));
  const { items, setItems } = paged;
  const itemsRef = useRef(items);
  itemsRef.current = items;
  const [q, setQ] = useState("");
  const [composing, setComposing] = useState(false);
  const [, setTick] = useState(0);

  useEffect(() => {
    const t = window.setInterval(() => setTick((n) => n + 1), 60_000);
    return () => window.clearInterval(t);
  }, []);

  useEffect(() => {
    for (const c of items) if (!chatCache.has(c.id)) chatCache.set(c.id, c);
  }, [items]);

  const upsert = (chat: Chat) => setItems((l) => {
    const i = l.findIndex((c) => c.id === chat.id);
    if (i === -1) return sortChats([chat, ...l]);
    const cur = l[i];
    // Keep the newer last message (the list may already have a live one).
    const keepLast = cur.lastMessage && chat.lastMessage && cur.lastMessage.id > chat.lastMessage.id;
    const next = [...l];
    next[i] = { ...chat, lastMessage: keepLast ? cur.lastMessage : chat.lastMessage };
    return sortChats(next);
  });

  useRealtime("message", ({ chatId, message }) => {
    if (!itemsRef.current.some((c) => c.id === chatId)) {
      // A new conversation: fetch it once the list itself is there.
      if (paged.loaded) {
        api.chat(chatId).then((c) => {
          chatCache.set(c.id, c);
          upsert(c);
        }, () => {});
      }
      return;
    }
    setItems((l) => {
      const i = l.findIndex((c) => c.id === chatId);
      if (i === -1) return l;
      const c = l[i];
      const last = c.lastMessage;
      if (last && last.id > message.id) return l;
      const isNew = !last || message.id > last.id;
      const seen = activeChatId === chatId && tabActive();
      const next = [...l];
      next[i] = {
        ...c,
        lastMessage: message,
        unreadCount: c.unreadCount + (isNew && !message.mine && !seen ? 1 : 0),
        updatedAt: message.createdAt,
      };
      return sortChats(next);
    });
  });

  useRealtime("message_deleted", ({ chatId, messageId }) => setItems((l) => l.map((c) => (
    c.id === chatId && c.lastMessage?.id === messageId
      ? { ...c, lastMessage: { ...c.lastMessage, deleted: true, text: "", attachment: null, pin: null } }
      : c
  ))));

  useRealtime("read", ({ chatId, userId, messageId }) => {
    if (userId === user?.id) return;
    setItems((l) => l.map((c) => (
      c.id === chatId && c.lastMessage?.mine && c.lastMessage.id <= messageId && !c.lastMessage.read
        ? { ...c, lastMessage: { ...c.lastMessage, read: true } }
        : c
    )));
  });

  useRealtime("chat:read", ({ chatId }) => setItems((l) => l.map((c) => (c.id === chatId && c.unreadCount ? { ...c, unreadCount: 0 } : c))));
  useRealtime("chat:upsert", ({ chat }) => upsert(chat));
  useRealtime("reconnect", () => paged.reload());

  const shown = useMemo(() => {
    const s = q.trim().toLocaleLowerCase("tk");
    if (!s) return items;
    return items.filter((c) => c.other.name.toLocaleLowerCase("tk").includes(s) || c.other.username.toLowerCase().includes(s));
  }, [items, q]);

  return (
    <div className="chat-list">
      <div className="chat-list-head">
        <h1>Habarlar</h1>
        <button type="button" className="icon-btn" onClick={() => setComposing(true)} aria-label="Täze habar" title="Täze habar">
          <EditIcon size={20} />
        </button>
      </div>
      <label className="chat-search">
        <SearchIcon size={17} />
        <input
          type="search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Gözle"
          aria-label="Habarlaşyklary gözle"
          autoComplete="off"
        />
      </label>
      <NotifyBanner />

      <div className="chat-list-scroll">
        {!paged.loaded ? (
          <div aria-busy="true">
            {Array.from({ length: 7 }, (_, i) => (
              <div key={i} className="chat-row skel">
                <span className="skeleton" style={{ width: 52, height: 52, borderRadius: "50%" }} />
                <span className="chat-row-main">
                  <span className="skeleton skeleton-line" style={{ width: "55%", margin: 0 }} />
                  <span className="skeleton skeleton-line" style={{ width: "80%", margin: "8px 0 0" }} />
                </span>
              </div>
            ))}
          </div>
        ) : paged.error && items.length === 0 ? (
          <div className="chat-empty">
            <p>{paged.error}</p>
            <button className="btn btn-secondary btn-sm" onClick={paged.reload}>Gaýtadan synanyş</button>
          </div>
        ) : items.length === 0 ? (
          <div className="chat-empty">
            <span className="empty-icon"><SendIcon size={30} /></span>
            <h2>Heniz habar ýok</h2>
            <p>Dükanlara we dostlaryňyza göni ýazyň: profilinde «Habar ýaz» düwmesine basyň ýa-da posty «Habar bilen ugradyň».</p>
            <button className="btn btn-primary" onClick={() => setComposing(true)}>Täze habar</button>
          </div>
        ) : shown.length === 0 ? (
          <p className="chat-empty muted">«{q}» boýunça hiç kim tapylmady</p>
        ) : (
          <>
            {shown.map((c) => <ChatRow key={c.id} chat={c} active={c.id === activeId} />)}
            {!q && <InfiniteFooter paged={paged} />}
          </>
        )}
      </div>

      {composing && (
        <Modal title="Täze habar" onClose={() => setComposing(false)}>
          <ChatPicker mode="new" onDone={() => setComposing(false)} />
        </Modal>
      )}
    </div>
  );
}
