"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Fragment, useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { BackIcon, BanIcon, ChevronDownIcon, CopyIcon, TrashIcon, UploadIcon, UserIcon } from "@/components/Icons";
import Modal from "@/components/Modal";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { chatCache, dayLabel, isImageFile, newClientId, sameDay } from "@/lib/chat";
import { copyText } from "@/lib/share";
import { emit, useRealtime, useRealtimeConnected } from "@/lib/realtime";
import type { Attachment, Chat, Message, PinPreview } from "@/lib/types";
import { ChatAvatar, ChatName } from "./ChatBits";
import { useChat, useTyping } from "./ChatProvider";
import Composer, { type ComposerHandle, type Draft } from "./Composer";
import MessageBubble, { Lightbox, type UIMessage } from "./MessageBubble";

const PAGE = 30;
const NEAR_BOTTOM = 140;
const GROUP_MS = 5 * 60_000;
const TYPING_PING_MS = 3000;

let localSeq = 0;

/** Server messages by id, then optimistic ones in the order they were written. */
function ordered(list: UIMessage[]): UIMessage[] {
  const server = list.filter((m) => m.id > 0).sort((a, b) => a.id - b.id);
  const local = list.filter((m) => m.id <= 0).sort((a, b) => b.id - a.id);
  return [...server, ...local];
}

/** Puts a server message in place of its optimistic copy (same clientId) or of an older copy. */
function upsertMessage(list: UIMessage[], m: Message): UIMessage[] {
  let i = m.clientId ? list.findIndex((x) => x.clientId === m.clientId && (x.id <= 0 || x.id === m.id)) : -1;
  if (i === -1) i = list.findIndex((x) => x.id === m.id);
  if (i === -1) return ordered([...list, m]);
  const next = [...list];
  next[i] = m;
  return ordered(next);
}

const tabActive = () => document.visibilityState === "visible" && document.hasFocus();

type Menu = { m: UIMessage; top: number; left: number; right: boolean };

export default function Conversation({ chatId }: { chatId: number }) {
  const { user } = useAuth();
  const router = useRouter();
  const params = useSearchParams();
  const toast = useToast();
  const { setActiveChat } = useChat();
  const connected = useRealtimeConnected();
  const typing = useTyping(chatId);

  const [chat, setChat] = useState<Chat | null>(() => chatCache.get(chatId) ?? null);
  const [chatError, setChatError] = useState<{ status: number; message: string } | null>(null);
  const [items, setItems] = useState<UIMessage[]>([]);
  const [hasMore, setHasMore] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [olderBusy, setOlderBusy] = useState(false);
  const [newPill, setNewPill] = useState(false);
  const [farFromBottom, setFar] = useState(false);
  const [menu, setMenu] = useState<Menu | null>(null);
  const [confirm, setConfirm] = useState<UIMessage | null>(null);
  const [lightbox, setLightbox] = useState<Attachment | null>(null);
  const [dragging, setDragging] = useState(false);
  const [initialPin, setInitialPin] = useState<PinPreview | null>(null);
  const [initialText] = useState(() => params.get("text") ?? "");
  const [nonce, setNonce] = useState(0);

  const scroller = useRef<HTMLDivElement>(null);
  const composer = useRef<ComposerHandle>(null);
  const itemsRef = useRef(items);
  itemsRef.current = items;
  const nearBottom = useRef(true);
  const stickNext = useRef<"bottom" | "smooth" | null>("bottom");
  const prepend = useRef<{ height: number; top: number } | null>(null);
  const lastMarked = useRef(0);
  const lastTyping = useRef(0);
  const queue = useRef<Promise<void>>(Promise.resolve());
  const dragDepth = useRef(0);
  const localUrls = useRef<string[]>([]);

  // ---------- loading ----------

  useEffect(() => {
    setActiveChat(chatId);
    return () => setActiveChat(null);
  }, [chatId, setActiveChat]);

  useEffect(() => () => localUrls.current.forEach((u) => URL.revokeObjectURL(u)), []);

  const loadChat = useCallback(() => {
    api.chat(chatId).then(
      (c) => {
        chatCache.set(c.id, c);
        setChat(c);
        setChatError(null);
        document.title = `${c.other.name || c.other.username} · Habarlar`;
        emit("chat:upsert", { chat: c });
      },
      (e) => setChatError({ status: e instanceof ApiError ? e.status : 0, message: errorMessage(e) }),
    );
  }, [chatId]);

  useEffect(() => {
    let alive = true;
    setLoaded(false);
    setLoadError(null);
    setItems([]);
    lastMarked.current = 0;
    stickNext.current = "bottom";
    loadChat();
    api.messages(chatId, undefined, PAGE).then(
      (r) => {
        if (!alive) return;
        setItems(ordered(r.items));
        setHasMore(r.hasMore);
        setLoaded(true);
      },
      (e) => {
        if (!alive) return;
        setLoadError(errorMessage(e));
        setLoaded(true);
      },
    );
    return () => { alive = false; };
  }, [chatId, nonce, loadChat]);

  // A post handed over by "ModaHouse-da ýaz" (?pin=…&text=…): attach it, then clean the URL.
  useEffect(() => {
    const pid = Number(params.get("pin"));
    if (!pid && !params.get("text")) return;
    if (pid) {
      api.pin(pid).then((p) => setInitialPin({
        id: p.id, title: p.title, imageUrl: p.images[0]?.type === "video" ? p.images[0].posterUrl || p.imageUrl : p.imageUrl,
        width: p.width, height: p.height, color: p.color, price: p.product?.price ?? 0, listingType: p.product?.listingType ?? "",
      }), () => {});
    }
    router.replace(`/messages/${chatId}`, { scroll: false });
    // Only on arrival.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chatId]);

  // After a reconnect: refetch the chat and the newest page; keep older pages if they still connect.
  useRealtime("reconnect", () => {
    loadChat();
    api.messages(chatId, undefined, PAGE).then((r) => {
      setItems((prev) => {
        const first = r.items[0]?.id ?? 0;
        const overlaps = !r.hasMore || prev.some((m) => m.id === first);
        const older = overlaps ? prev.filter((m) => m.id > 0 && m.id < first) : [];
        const fresh = new Set(r.items.map((m) => m.clientId).filter(Boolean));
        const locals = prev.filter((m) => m.id <= 0 && !fresh.has(m.clientId));
        if (!overlaps) setHasMore(r.hasMore);
        return ordered([...older, ...r.items, ...locals]);
      });
    }, () => {});
  });

  const loadOlder = useCallback(() => {
    const first = itemsRef.current.find((m) => m.id > 0);
    if (!first || olderBusy || !hasMore) return;
    setOlderBusy(true);
    api.messages(chatId, first.id, PAGE).then(
      (r) => {
        const el = scroller.current;
        if (el) prepend.current = { height: el.scrollHeight, top: el.scrollTop };
        setItems((prev) => {
          const have = new Set(prev.map((m) => m.id));
          return ordered([...r.items.filter((m) => !have.has(m.id)), ...prev]);
        });
        setHasMore(r.hasMore);
      },
      (e) => toast(errorMessage(e), "error"),
    ).finally(() => setOlderBusy(false));
  }, [chatId, hasMore, olderBusy, toast]);

  // ---------- scrolling ----------

  const scrollToBottom = useCallback((smooth = false) => {
    const el = scroller.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: smooth ? "smooth" : "auto" });
    nearBottom.current = true;
    setNewPill(false);
    setFar(false);
  }, []);

  useLayoutEffect(() => {
    const el = scroller.current;
    if (!el) return;
    if (prepend.current) {
      // Older messages went in above: keep what the reader was looking at in place.
      el.scrollTop = el.scrollHeight - prepend.current.height + prepend.current.top;
      prepend.current = null;
      return;
    }
    if (stickNext.current) {
      scrollToBottom(stickNext.current === "smooth");
      stickNext.current = null;
    }
  }, [items, loaded, scrollToBottom]);

  // Images and videos finish loading after the first layout: stay at the bottom if we were there.
  const onMedia = useCallback(() => {
    if (nearBottom.current) {
      const el = scroller.current;
      if (el) el.scrollTop = el.scrollHeight;
    }
  }, []);

  // ---------- read receipts ----------

  const markRead = useCallback(() => {
    if (!nearBottom.current || !tabActive()) return;
    const list = itemsRef.current;
    let lastIncoming = 0;
    for (let i = list.length - 1; i >= 0; i--) {
      if (list[i].id > 0 && !list[i].mine) { lastIncoming = list[i].id; break; }
    }
    if (!lastIncoming || lastIncoming <= lastMarked.current) return;
    const prev = lastMarked.current;
    lastMarked.current = lastIncoming;
    api.markRead(chatId, lastIncoming).then(
      () => emit("chat:read", { chatId }),
      () => { lastMarked.current = prev; },
    );
  }, [chatId]);

  useEffect(() => {
    if (loaded) markRead();
  }, [items, loaded, markRead]);

  useEffect(() => {
    const again = () => markRead();
    window.addEventListener("focus", again);
    document.addEventListener("visibilitychange", again);
    return () => {
      window.removeEventListener("focus", again);
      document.removeEventListener("visibilitychange", again);
    };
  }, [markRead]);

  const onScroll = () => {
    const el = scroller.current;
    if (!el) return;
    const gap = el.scrollHeight - el.scrollTop - el.clientHeight;
    nearBottom.current = gap < NEAR_BOTTOM;
    setFar(gap > 600);
    if (nearBottom.current) {
      setNewPill(false);
      markRead();
    }
    if (el.scrollTop < 240 && hasMore && !olderBusy && loaded) loadOlder();
    if (menu) setMenu(null);
  };

  // ---------- live events ----------

  useRealtime("message", ({ chatId: cid, message }) => {
    if (cid !== chatId) return;
    const known = itemsRef.current.some((m) => m.id === message.id || (!!message.clientId && m.clientId === message.clientId));
    if (!known) {
      if (message.mine || nearBottom.current) stickNext.current = "smooth";
      else setNewPill(true);
    }
    setItems((l) => upsertMessage(l, message));
  });

  useRealtime("message_deleted", ({ chatId: cid, messageId }) => {
    if (cid !== chatId) return;
    setItems((l) => l.map((m) => (m.id === messageId ? { ...m, deleted: true, text: "", attachment: null, pin: null } : m)));
  });

  useRealtime("read", ({ chatId: cid, userId, messageId }) => {
    if (cid !== chatId || userId === user?.id) return;
    setItems((l) => l.map((m) => (m.mine && !m.read && m.id > 0 && m.id <= messageId ? { ...m, read: true } : m)));
  });

  // The typing bubble appears at the bottom: keep it visible.
  useEffect(() => {
    if (typing && nearBottom.current) scrollToBottom(true);
  }, [typing, scrollToBottom]);

  // ---------- sending ----------

  const patchLocal = useCallback((clientId: string, patch: Partial<UIMessage>) => {
    setItems((l) => l.map((m) => (m.clientId === clientId && m.id <= 0 ? { ...m, ...patch } : m)));
  }, []);

  const deliver = useCallback((local: UIMessage) => {
    queue.current = queue.current.then(async () => {
      try {
        const sent = local.file
          ? await api.sendFile(chatId, local.file, { text: local.text, clientId: local.clientId }, (p) => patchLocal(local.clientId, { progress: p }))
          : await api.sendMessage(chatId, { text: local.text, pinId: local.pinId, clientId: local.clientId });
        setItems((l) => upsertMessage(l, sent));
        emit("message", { chatId, message: sent });
      } catch (e) {
        patchLocal(local.clientId, { status: "failed", error: errorMessage(e) });
        if (e instanceof ApiError && e.status === 403) {
          setChat((c) => (c ? { ...c, blocked: true } : c));
          toast(errorMessage(e), "error");
        }
      }
    });
  }, [chatId, patchLocal, toast]);

  const send = useCallback((d: Draft) => {
    if (!user) return;
    const now = new Date().toISOString();
    const me = { id: user.id, username: user.username, name: user.name, avatarUrl: user.avatarUrl, isBusiness: user.isBusiness, verified: user.verified };
    const base = (): UIMessage => ({
      id: -(++localSeq), chatId, sender: me, kind: "text", text: "", attachment: null, pin: null,
      clientId: newClientId(), mine: true, read: false, deleted: false, createdAt: now, status: "pending",
    });
    const out: UIMessage[] = [];
    // A single file carries the text as its caption; with several, the text goes on its own.
    const caption = d.files.length === 1 && !d.pin ? d.text : "";
    for (const f of d.files) {
      const url = isImageFile(f) || f.type.startsWith("video/") ? URL.createObjectURL(f) : "";
      if (url) localUrls.current.push(url);
      out.push({
        ...base(), kind: isImageFile(f) ? "image" : "file", text: caption, file: f, progress: 0,
        attachment: { url, name: f.name, size: f.size, mimeType: f.type, width: 0, height: 0 },
      });
    }
    if (d.pin) out.push({ ...base(), kind: "pin", pin: d.pin, pinId: d.pin.id, text: d.text });
    else if (d.text && !caption) out.push({ ...base(), kind: "text", text: d.text });
    if (!out.length) return;
    stickNext.current = "smooth";
    setItems((l) => ordered([...l, ...out]));
    out.forEach(deliver);
    lastTyping.current = 0;
  }, [user, chatId, deliver]);

  const retry = useCallback((m: UIMessage) => {
    patchLocal(m.clientId, { status: "pending", error: undefined, progress: 0 });
    deliver({ ...m, status: "pending" });
  }, [patchLocal, deliver]);

  const closeLightbox = useCallback(() => setLightbox(null), []);

  const discard = useCallback((m: UIMessage) => setItems((l) => l.filter((x) => x !== m && !(x.id <= 0 && x.clientId === m.clientId))), []);

  const onTyping = useCallback(() => {
    const now = Date.now();
    if (now - lastTyping.current < TYPING_PING_MS) return;
    lastTyping.current = now;
    api.typing(chatId).catch(() => {});
  }, [chatId]);

  // ---------- message actions ----------

  const openMenu = useCallback((m: UIMessage, anchor: HTMLElement) => {
    const r = anchor.getBoundingClientRect();
    const right = m.mine;
    const top = Math.min(window.innerHeight - 120, r.bottom + 6);
    setMenu({ m, top, left: right ? Math.max(8, window.innerWidth - r.right) : Math.max(8, r.left), right });
  }, []);

  useEffect(() => {
    if (!menu) return;
    const close = (e: Event) => {
      if (e.target instanceof Element && e.target.closest(".msg-menu")) return;
      setMenu(null);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setMenu(null);
    document.addEventListener("mousedown", close);
    document.addEventListener("touchstart", close);
    document.addEventListener("keydown", onKey);
    window.addEventListener("resize", () => setMenu(null), { once: true });
    return () => {
      document.removeEventListener("mousedown", close);
      document.removeEventListener("touchstart", close);
      document.removeEventListener("keydown", onKey);
    };
  }, [menu]);

  const remove = async (m: UIMessage) => {
    setConfirm(null);
    if (m.id <= 0) return discard(m);
    const before = itemsRef.current;
    setItems((l) => l.map((x) => (x.id === m.id ? { ...x, deleted: true, text: "", attachment: null, pin: null } : x)));
    try {
      await api.deleteMessage(m.id);
      emit("message_deleted", { chatId, messageId: m.id });
    } catch (e) {
      setItems(before);
      toast(errorMessage(e), "error");
    }
  };

  // ---------- drag & drop ----------

  const hasFiles = (e: React.DragEvent) => Array.from(e.dataTransfer.types).includes("Files");
  const dropProps = chat?.blocked ? {} : {
    onDragEnter: (e: React.DragEvent) => {
      if (!hasFiles(e)) return;
      e.preventDefault();
      dragDepth.current += 1;
      setDragging(true);
    },
    onDragOver: (e: React.DragEvent) => {
      if (!hasFiles(e)) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = "copy";
    },
    onDragLeave: () => {
      dragDepth.current = Math.max(0, dragDepth.current - 1);
      if (!dragDepth.current) setDragging(false);
    },
    onDrop: (e: React.DragEvent) => {
      if (!hasFiles(e)) return;
      e.preventDefault();
      dragDepth.current = 0;
      setDragging(false);
      composer.current?.addFiles(e.dataTransfer.files);
    },
  };

  // ---------- render ----------

  if (chatError && !chat) {
    return (
      <div className="chat-conv">
        <div className="conv-missing">
          <h2>{chatError.status === 404 ? "Habarlaşyk tapylmady" : "Ýüklenmedi"}</h2>
          <p className="muted">{chatError.status === 404 ? "Ol pozulan ýa-da size degişli däl bolmagy mümkin." : chatError.message}</p>
          <div className="form-actions">
            <Link href="/messages" className="btn btn-secondary">Habarlar</Link>
            {chatError.status !== 404 && <button className="btn btn-primary" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>}
          </div>
        </div>
      </div>
    );
  }

  const other = chat?.other;
  const status = typing ? "ýazýar…" : !connected ? "Birikdirilýär…" : other ? `@${other.username}` : "";

  return (
    <div className="chat-conv" {...dropProps}>
      <header className="conv-head">
        <Link href="/messages" className="icon-btn conv-back" aria-label="Habarlara gaýt"><BackIcon /></Link>
        {other ? (
          <Link href={`/u/${other.username}`} className="conv-who">
            <ChatAvatar user={other} size={40} />
            <span className="conv-who-text">
              <ChatName user={other} />
              <span className={`conv-status ${typing ? "typing" : ""}`}>{status}</span>
            </span>
          </Link>
        ) : (
          <span className="conv-who">
            <span className="skeleton" style={{ width: 40, height: 40, borderRadius: "50%" }} />
            <span className="skeleton skeleton-line" style={{ width: 140, margin: 0 }} />
          </span>
        )}
        {other && (
          <Link href={`/u/${other.username}`} className="icon-btn" aria-label="Profili gör" title="Profili gör"><UserIcon size={21} /></Link>
        )}
      </header>

      <div className="conv-body">
      <div className="conv-scroll" ref={scroller} onScroll={onScroll}>
        <div className="conv-inner">
          {!loaded ? (
            <div className="conv-loading"><span className="spinner" /></div>
          ) : loadError ? (
            <div className="conv-missing">
              <p className="muted">{loadError}</p>
              <button className="btn btn-secondary btn-sm" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>
            </div>
          ) : (
            <>
              {hasMore ? (
                <div className="conv-older">{olderBusy ? <span className="spinner" /> : <button className="btn btn-secondary btn-sm" onClick={loadOlder}>Öňki habarlar</button>}</div>
              ) : other && (
                <div className="conv-intro">
                  <ChatAvatar user={other} size={88} />
                  <ChatName user={other} />
                  <span className="muted">@{other.username}{other.isBusiness ? " · Biznes hasaby" : ""}</span>
                  <Link href={`/u/${other.username}`} className="btn btn-secondary btn-sm">Profili gör</Link>
                  {items.length === 0 && !chat?.blocked && <p className="muted small">Ilkinji habaryňyzy ýazyň</p>}
                </div>
              )}
              {items.map((m, i) => {
                const prev = items[i - 1];
                const next = items[i + 1];
                const newDay = !prev || !sameDay(prev.createdAt, m.createdAt);
                const joinPrev = !!prev && !newDay && prev.sender.id === m.sender.id
                  && new Date(m.createdAt).getTime() - new Date(prev.createdAt).getTime() < GROUP_MS;
                const joinNext = !!next && sameDay(next.createdAt, m.createdAt) && next.sender.id === m.sender.id
                  && new Date(next.createdAt).getTime() - new Date(m.createdAt).getTime() < GROUP_MS;
                return (
                  <Fragment key={m.clientId && m.id <= 0 ? m.clientId : m.id}>
                    {newDay && <div className="conv-day"><span>{dayLabel(m.createdAt)}</span></div>}
                    <MessageBubble
                      m={m}
                      first={!joinPrev}
                      last={!joinNext}
                      onOpenImage={setLightbox}
                      onMenu={openMenu}
                      onRetry={retry}
                      onDiscard={discard}
                      onMedia={onMedia}
                    />
                  </Fragment>
                );
              })}
              {typing && other && (
                <div className="msg-row theirs first last typing-row" aria-label="ýazýar…">
                  <span className="msg-av"><ChatAvatar user={other} size={28} /></span>
                  <div className="bubble typing-bubble"><span /><span /><span /></div>
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {(newPill || farFromBottom) && (
        <button
          type="button"
          className={`conv-pill ${newPill ? "new" : ""}`}
          onClick={() => scrollToBottom(true)}
          aria-label={newPill ? "Täze habarlar" : "Aşaky habarlara"}
        >
          <ChevronDownIcon size={18} />{newPill && <span>Täze habarlar</span>}
        </button>
      )}
      </div>

      {chat?.blocked ? (
        <div className="conv-blocked"><BanIcon size={18} /> Bu ulanyja ýazyp bolmaýar</div>
      ) : (
        <>
          <Composer
            ref={composer}
            onSend={send}
            onTyping={onTyping}
            initialText={initialText}
            initialPin={initialPin}
            disabled={!chat}
          />
        </>
      )}

      {dragging && (
        <div className="conv-drop" aria-hidden>
          <UploadIcon size={34} />
          <strong>Faýllary şu ýere goýuň</strong>
          <span>Suratlar we resminamalar</span>
        </div>
      )}

      {menu && createPortal(
        <div
          className="msg-menu"
          role="menu"
          style={{ top: menu.top, ...(menu.right ? { right: menu.left } : { left: menu.left }) }}
        >
          {menu.m.text && !menu.m.deleted && (
            <button
              role="menuitem"
              className="menu-item"
              onClick={async () => {
                const t = menu.m.text;
                setMenu(null);
                if (await copyText(t)) toast("Göçürildi");
              }}
            >
              <CopyIcon size={17} /> Göçür
            </button>
          )}
          {menu.m.mine && !menu.m.deleted && (
            <button role="menuitem" className="menu-item danger" onClick={() => { setConfirm(menu.m); setMenu(null); }}>
              <TrashIcon size={17} /> Poz
            </button>
          )}
        </div>,
        document.body,
      )}

      {confirm && (
        <Modal title="Habary pozmak" onClose={() => setConfirm(null)}>
          <div className="confirm-body">
            <p>Habar iki tarapda hem «Bu habar pozuldy» bolup görüner. Muny yzyna gaýtaryp bolmaýar.</p>
            <div className="form-actions">
              <button className="btn btn-secondary" onClick={() => setConfirm(null)}>Goý bolsun</button>
              <button className="btn btn-primary danger-bg" onClick={() => remove(confirm)}><TrashIcon size={17} /> Poz</button>
            </div>
          </div>
        </Modal>
      )}

      {lightbox && <Lightbox a={lightbox} onClose={closeLightbox} />}
    </div>
  );
}
