"use client";

import Link from "next/link";
import { useState } from "react";
import { errorMessage } from "@/lib/api";
import { dateTime, money, ORDER_ACTION_LABEL, ORDER_STATUS_LABEL } from "@/lib/format";
import type { Order, OrderStatus } from "@/lib/types";
import Avatar from "./Avatar";
import { CheckIcon, CloseIcon, PhoneIcon, PinMapIcon, StarIcon } from "./Icons";
import { useToast } from "./Toast";

const FLOW: OrderStatus[] = ["new", "confirmed", "shipped", "delivered"];

export function StatusPill({ status }: { status: OrderStatus }) {
  return <span className={`status-pill st-${status}`}>{ORDER_STATUS_LABEL[status] ?? status}</span>;
}

export function StatusTimeline({ status }: { status: OrderStatus }) {
  if (status === "cancelled") {
    return (
      <div className="timeline cancelled">
        <span className="tl-cancel"><CloseIcon size={16} /> Sargyt ýatyryldy</span>
      </div>
    );
  }
  const current = FLOW.indexOf(status);
  return (
    <ol className="timeline" aria-label={`Ýagdaýy: ${ORDER_STATUS_LABEL[status]}`}>
      {FLOW.map((s, i) => (
        <li key={s} className={`${i < current ? "done" : ""} ${i === current ? "current" : ""}`}>
          <span className="tl-dot">{i <= current ? <CheckIcon size={13} /> : null}</span>
          <span className="tl-label">{ORDER_STATUS_LABEL[s]}</span>
        </li>
      ))}
    </ol>
  );
}

const telHref = (p: string) => `tel:${p.replace(/[^\d+]/g, "")}`;

export default function OrderCard({
  order, view, onCancel, onStatus,
}: {
  order: Order;
  view: "buyer" | "business";
  onCancel?: (o: Order) => Promise<void>;
  onStatus?: (o: Order, s: OrderStatus) => Promise<void>;
}) {
  const toast = useToast();
  const [busy, setBusy] = useState<string | null>(null);
  const other = view === "buyer" ? order.business : order.buyer;
  const count = order.items.reduce((s, i) => s + i.quantity, 0);

  const run = async (key: string, fn: () => Promise<void>) => {
    setBusy(key);
    try {
      await fn();
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(null);
    }
  };

  return (
    <article className="order-card">
      <header className="order-head">
        <Link href={`/u/${other.username}`} className="order-who">
          <Avatar user={other} size={36} />
          <span>
            <strong>{view === "buyer" ? other.name : order.fullName || other.name}</strong>
            <span className="muted small">Sargyt #{order.id} · {dateTime(order.createdAt)}</span>
          </span>
        </Link>
        <StatusPill status={order.status} />
      </header>

      <StatusTimeline status={order.status} />

      <ul className="order-items">
        {order.items.map((it, i) => {
          const body = (
            <>
              <span className="order-thumb">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                {it.imageUrl && <img src={it.imageUrl} alt="" loading="lazy" />}
              </span>
              <span className="order-item-text">
                <strong>{it.title}</strong>
                {(it.color || it.size) && <span className="muted small">{[it.color, it.size].filter(Boolean).join(" · ")}</span>}
              </span>
              <span className="order-item-price">{it.quantity} × {money(it.price)}</span>
            </>
          );
          return (
            <li key={i}>
              {it.pinId ? <Link href={`/pin/${it.pinId}`} className="order-item">{body}</Link> : <div className="order-item">{body}</div>}
              {view === "buyer" && order.status === "delivered" && it.pinId && (
                <Link href={`/pin/${it.pinId}#reviews`} className="btn btn-secondary btn-sm review-cta"><StarIcon size={14} /> Syn ýaz</Link>
              )}
            </li>
          );
        })}
      </ul>

      <div className="order-contact">
        {view === "business" && (
          <>
            <a href={telHref(order.phone)} className="text-link"><PhoneIcon size={14} /> {order.phone}</a>
          </>
        )}
        <span><PinMapIcon size={14} /> {order.address}</span>
        {order.note && <span className="order-note">“{order.note}”</span>}
      </div>

      <footer className="order-foot">
        <span className="order-total">{count} haryt · <strong>{money(order.total)}</strong></span>
        <div className="order-actions">
          {view === "buyer" && order.canCancel && onCancel && (
            <button
              className="btn btn-secondary btn-sm danger"
              disabled={busy !== null}
              onClick={() => window.confirm("Sargydy ýatyrmalymy?") && run("cancel", () => onCancel(order))}
            >
              {busy === "cancel" ? "…" : "Sargydy ýatyr"}
            </button>
          )}
          {view === "business" && onStatus && order.nextStatuses.map((s) => (
            <button
              key={s}
              className={`btn btn-sm ${s === "cancelled" ? "btn-secondary danger" : "btn-primary"}`}
              disabled={busy !== null}
              onClick={() => {
                if (s === "cancelled" && !window.confirm("Sargydy ýatyrmalymy?")) return;
                run(s, () => onStatus(order, s));
              }}
            >
              {busy === s ? "…" : ORDER_ACTION_LABEL[s] ?? ORDER_STATUS_LABEL[s]}
            </button>
          ))}
        </div>
      </footer>
    </article>
  );
}
