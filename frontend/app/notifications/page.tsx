"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import { InfiniteFooter } from "@/components/Masonry";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { money, ORDER_STATUS_LABEL, timeAgo } from "@/lib/format";
import { StatusPill } from "@/components/OrderCard";
import { usePaged, useRequireAuth } from "@/lib/hooks";
import type { Notification } from "@/lib/types";

const TEXT: Record<Notification["type"], string> = {
  like: "piniňizi halady",
  comment: "piniňize teswir ýazdy",
  save: "piniňizi tagtasyna sakladý",
  follow: "sizi yzarlap başlady",
  order: "täze sargyt etdi",
  order_status: "sargydyňyzyň ýagdaýyny üýtgetdi",
  review: "harydyňyza syn ýazdy",
};

function text(n: Notification): string {
  if (n.type === "order_status" && n.order) {
    // Sent to the buyer on every change, and to the shop when the buyer cancels: keep the wording neutral.
    const s = ORDER_STATUS_LABEL[n.order.status] ?? n.order.status;
    return `sargyt #${n.order.id} ýagdaýyny üýtgetdi: ${s}`;
  }
  if (n.type === "order" && n.order) return `täze sargyt etdi: #${n.order.id}`;
  return TEXT[n.type] ?? "";
}

function hrefFor(n: Notification): string {
  if ((n.type === "order" || n.type === "order_status") && n.order) return `/orders/${n.order.id}`;
  if (n.type === "order") return "/business?tab=orders";
  if (n.type === "order_status") return "/orders";
  if (n.type === "review" && n.pin) return `/pin/${n.pin.id}#reviews`;
  return n.pin ? `/pin/${n.pin.id}` : `/u/${n.actor.username}`;
}

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
          <p>Biri pinleriňizi halasa, teswir ýazsa, sizi yzarlasa ýa-da sargyt etse, şu ýerde görersiňiz.</p>
          <Link href="/" className="btn btn-primary">Ideýalara seret</Link>
        </div>
      ) : (
        <ul className="notes">
          {paged.items.map((n) => {
            const href = hrefFor(n);
            return (
              <li key={n.id} className={`note ${n.read ? "" : "unread"}`}>
                <Link href={`/u/${n.actor.username}`} className="note-avatar"><Avatar user={n.actor} size={48} /></Link>
                <Link href={href} className="note-text">
                  <span><strong>{n.actor.name}</strong> {text(n)}</span>
                  {n.pin && <span className="note-pin">“{n.pin.title}”</span>}
                  {n.order && (
                    <span className="note-order"><StatusPill status={n.order.status} /> {money(n.order.total)}</span>
                  )}
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
