"use client";

import Link from "next/link";
import { memo, useEffect, useRef } from "react";
import { createPortal } from "react-dom";
import Avatar from "@/components/Avatar";
import { ClockIcon, CloseIcon, DotsIcon, DownloadIcon } from "@/components/Icons";
import { clock, fileExt, fileSize } from "@/lib/chat";
import { priceLabel } from "@/lib/format";
import type { Attachment, Message } from "@/lib/types";

/** A message on screen: server messages plus optimistic ones (negative id until the server answers). */
export type UIMessage = Message & {
  status?: "pending" | "failed";
  /** Upload progress 0..1 for files. */
  progress?: number;
  error?: string;
  /** Kept for "Gaýtadan ugrat". */
  file?: File;
  pinId?: number;
};

const URL_RE = /(https?:\/\/[^\s<]+[^\s<.,;:!?)\]'"])/g;

/** Plain text with clickable links; line breaks kept by CSS. */
function Linkified({ text }: { text: string }) {
  const parts = text.split(URL_RE);
  return (
    <>
      {parts.map((p, i) => (i % 2 === 1
        ? <a key={i} href={p} target="_blank" rel="noopener noreferrer" className="msg-link">{p}</a>
        : <span key={i}>{p}</span>))}
    </>
  );
}

function Ticks({ m }: { m: UIMessage }) {
  if (m.status === "pending") return <span className="msg-tick" aria-label="Ugradylýar"><ClockIcon size={12} /></span>;
  if (m.status === "failed") return <span className="msg-tick failed" aria-label="Ugradylmady">!</span>;
  return <span className={`msg-tick ${m.read ? "read" : ""}`} aria-label={m.read ? "Okaldy" : "Ugradyldy"}>{m.read ? "✓✓" : "✓"}</span>;
}

function ImageBody({ a, m, onOpen, onMedia }: { a: Attachment; m: UIMessage; onOpen: (a: Attachment) => void; onMedia: () => void }) {
  const ratio = a.width > 0 && a.height > 0 ? a.width / a.height : 0;
  const style: React.CSSProperties = ratio
    // A fixed width (not a percentage): the bubble shrinks to fit its content.
    ? { aspectRatio: `${a.width} / ${a.height}`, width: ratio >= 1 ? 280 : Math.max(120, Math.round(300 * ratio)) }
    : {};
  return (
    <button type="button" className={`msg-image ${ratio ? "" : "free"}`} style={style} onClick={() => m.status !== "pending" && onOpen(a)} aria-label="Suraty ulalt">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={a.url} alt={a.name || "Surat"} loading="lazy" onLoad={onMedia} />
      {m.status === "pending" && (
        <span className="msg-upload">
          <span className="spinner light" />
          {typeof m.progress === "number" && m.progress < 1 && <span>{Math.round(m.progress * 100)}%</span>}
        </span>
      )}
    </button>
  );
}

function FileBody({ a, m, onMedia }: { a: Attachment; m: UIMessage; onMedia: () => void }) {
  const pending = m.status === "pending";
  if (!pending && a.mimeType.startsWith("video/")) {
    return <video className="msg-video" src={a.url} controls preload="metadata" playsInline onLoadedMetadata={onMedia} />;
  }
  if (!pending && a.mimeType.startsWith("audio/")) {
    return <audio className="msg-audio" src={a.url} controls preload="metadata" />;
  }
  return (
    <div className="msg-file">
      <span className="file-ext">{fileExt(a.name)}</span>
      <span className="msg-file-text">
        <strong title={a.name}>{a.name || "Faýl"}</strong>
        <span>{pending && typeof m.progress === "number" ? `${Math.round(m.progress * 100)}% · ${fileSize(a.size)}` : fileSize(a.size)}</span>
        {pending && <span className="msg-progress"><span style={{ width: `${Math.max(4, Math.round((m.progress ?? 0) * 100))}%` }} /></span>}
      </span>
      {!pending && m.status !== "failed" && (
        <a className="msg-file-dl" href={a.url} download={a.name} target="_blank" rel="noopener noreferrer" aria-label={`${a.name} ýükle`} title="Ýükle">
          <DownloadIcon size={18} />
        </a>
      )}
    </div>
  );
}

type Props = {
  m: UIMessage;
  /** First / last bubble of a run from the same sender. */
  first: boolean;
  last: boolean;
  onOpenImage: (a: Attachment) => void;
  onMenu: (m: UIMessage, anchor: HTMLElement) => void;
  onRetry: (m: UIMessage) => void;
  onDiscard: (m: UIMessage) => void;
  onMedia: () => void;
};

function MessageBubble({ m, first, last, onOpenImage, onMenu, onRetry, onDiscard, onMedia }: Props) {
  const press = useRef(0);
  const fired = useRef(false);
  const row = useRef<HTMLDivElement>(null);
  const a = m.attachment;
  const hasMenu = !m.deleted && m.status !== "pending" && (m.mine || !!m.text);
  const media = !m.deleted && (m.kind === "image" || m.kind === "pin" || (m.kind === "file" && !!a && /^(video|audio)\//.test(a.mimeType)));

  // Long-press opens the menu on touch screens.
  const startPress = (e: React.TouchEvent) => {
    if (!hasMenu) return;
    const target = e.currentTarget as HTMLElement;
    window.clearTimeout(press.current);
    fired.current = false;
    press.current = window.setTimeout(() => {
      fired.current = true;
      navigator.vibrate?.(10);
      onMenu(m, target);
    }, 450);
  };
  const endPress = (e: React.TouchEvent) => {
    window.clearTimeout(press.current);
    // After a long press, swallow the click/mousedown the browser would emulate (it would close the menu).
    if (fired.current && e.type === "touchend" && e.cancelable) e.preventDefault();
  };

  return (
    <div ref={row} className={`msg-row ${m.mine ? "mine" : "theirs"} ${first ? "first" : ""} ${last ? "last" : ""}`} data-id={m.id}>
      {!m.mine && <span className="msg-av">{last && <Avatar user={m.sender} size={28} />}</span>}
      <div className="msg-col">
        <div className="msg-line">
          <div
            className={`bubble ${m.deleted ? "deleted" : ""} ${media ? "has-media" : ""} kind-${m.kind} ${m.status ?? ""}`}
            onTouchStart={startPress}
            onTouchEnd={endPress}
            onTouchMove={endPress}
            onContextMenu={(e) => {
              if (!hasMenu || !window.matchMedia("(pointer: coarse)").matches) return;
              e.preventDefault();
            }}
          >
            {m.deleted ? (
              <span className="msg-deleted">Bu habar pozuldy</span>
            ) : (
              <>
                {m.kind === "image" && a && <ImageBody a={a} m={m} onOpen={onOpenImage} onMedia={onMedia} />}
                {m.kind === "file" && a && <FileBody a={a} m={m} onMedia={onMedia} />}
                {m.kind === "pin" && m.pin && (
                  <Link href={`/pin/${m.pin.id}`} className="msg-pin">
                    <span
                      className="msg-pin-img"
                      style={{ aspectRatio: m.pin.width && m.pin.height ? `${m.pin.width} / ${Math.min(m.pin.height, m.pin.width * 1.4)}` : "4 / 5", background: m.pin.color || undefined }}
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={m.pin.imageUrl} alt="" loading="lazy" onLoad={onMedia} />
                    </span>
                    <span className="msg-pin-meta">
                      <strong>{m.pin.title || "Post"}</strong>
                      {m.pin.price > 0 && <span className="msg-pin-price">{priceLabel(m.pin)}</span>}
                    </span>
                  </Link>
                )}
                {m.kind === "pin" && !m.pin && <span className="msg-deleted">Post elýeterli däl</span>}
                {m.text && <p className="msg-text"><Linkified text={m.text} /></p>}
              </>
            )}
            <span className="msg-meta">
              <time dateTime={m.createdAt}>{clock(m.createdAt)}</time>
              {m.mine && !m.deleted && <Ticks m={m} />}
            </span>
          </div>
          {hasMenu && (
            <button type="button" className="msg-more" onClick={(e) => onMenu(m, e.currentTarget)} aria-label="Habar hereketleri">
              <DotsIcon size={16} />
            </button>
          )}
        </div>
        {m.status === "failed" && (
          <div className="msg-failed">
            <span>{m.error || "Ugradylmady"}</span>
            <button type="button" onClick={() => onRetry(m)}>Gaýtadan ugrat</button>
            <button type="button" className="muted" onClick={() => onDiscard(m)}>Aýyr</button>
          </div>
        )}
      </div>
    </div>
  );
}

export default memo(MessageBubble);

/** Full-screen image viewer. */
export function Lightbox({ a, onClose }: { a: Attachment; onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);
  return createPortal(
    <div className="lightbox" role="dialog" aria-modal="true" aria-label="Surat" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="lightbox-bar">
        <a href={a.url} download={a.name} className="lightbox-btn" aria-label="Ýükle" title="Ýükle"><DownloadIcon size={20} /></a>
        <button type="button" className="lightbox-btn" onClick={onClose} aria-label="Ýap" title="Ýap"><CloseIcon size={22} /></button>
      </div>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={a.url} alt={a.name || "Surat"} onClick={(e) => e.stopPropagation()} />
    </div>,
    document.body,
  );
}
