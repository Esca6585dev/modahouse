"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import { InfiniteFooter } from "@/components/Masonry";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { timeAgo } from "@/lib/format";
import { usePaged, useRequireAuth } from "@/lib/hooks";
import type { Notification } from "@/lib/types";

const TEXT: Record<Notification["type"], string> = {
  like: "piniňizi halady",
  comment: "piniňize teswir ýazdy",
  save: "piniňizi tagtasyna sakladý",
  follow: "sizi yzarlap başlady",
};

export default function NotificationsPage() {
  const { user } = useRequireAuth();
  const { setUnread } = useAuth();
  const paged = usePaged(user ? `notes:${user.id}` : null, (page) => api.notifications(page));
  const marked = useRef(false);
  const [, setTick] = useState(0);

  // Mark everything read once the first page is on screen (unread items stay highlighted for this visit).
  useEffect(() => {
    if (!paged.loaded || paged.error || marked.current) return;
    marked.current = true;
    api.readAll().then(() => setUnread(0), () => { marked.current = false; });
  }, [paged.loaded, paged.error, setUnread]);

  // Refresh relative times every minute.
  useEffect(() => {
    const t = window.setInterval(() => setTick((n) => n + 1), 60_000);
    return () => window.clearInterval(t);
  }, []);

  useEffect(() => { document.title = "Habarnamalar · ModaHouse"; }, []);

  return (
    <div className="page narrow-sm">
      <h1 className="page-title">Habarnamalar</h1>
      {!user || !paged.loaded ? (
        <ul className="notes">
          {[0, 1, 2, 3, 4].map((i) => <li key={i} className="note"><div className="skeleton" style={{ height: 56, width: "100%" }} /></li>)}
        </ul>
      ) : paged.error && paged.items.length === 0 ? (
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{paged.error}</p>
          <button className="btn btn-primary" onClick={paged.reload}>Gaýtadan synanyş</button>
        </div>
      ) : paged.items.length === 0 ? (
        <div className="empty">
          <h2>Habarnama ýok</h2>
          <p>Biri pinleriňizi halasa, teswir ýazsa ýa-da sizi yzarlasa, şu ýerde görersiňiz.</p>
          <Link href="/" className="btn btn-primary">Ideýalara seret</Link>
        </div>
      ) : (
        <ul className="notes">
          {paged.items.map((n) => {
            const href = n.pin ? `/pin/${n.pin.id}` : `/u/${n.actor.username}`;
            return (
              <li key={n.id} className={`note ${n.read ? "" : "unread"}`}>
                <Link href={`/u/${n.actor.username}`} className="note-avatar"><Avatar user={n.actor} size={48} /></Link>
                <Link href={href} className="note-text">
                  <span><strong>{n.actor.name}</strong> {TEXT[n.type] ?? ""}</span>
                  {n.pin && <span className="note-pin">“{n.pin.title}”</span>}
                  <span className="note-time">{timeAgo(n.createdAt)}</span>
                </Link>
                {n.pin && (
                  <Link href={href} className="note-thumb" aria-label={n.pin.title}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={n.pin.imageUrl} alt="" loading="lazy" />
                  </Link>
                )}
                {!n.read && <span className="note-dot" aria-label="Täze" />}
              </li>
            );
          })}
        </ul>
      )}
      <InfiniteFooter paged={paged} />
    </div>
  );
}
