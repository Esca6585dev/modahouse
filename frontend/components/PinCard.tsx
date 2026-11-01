"use client";

import Link from "next/link";
import { useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useAddToCart } from "@/lib/cart";
import { duration, isForSale } from "@/lib/format";
import type { Pin } from "@/lib/types";
import Avatar from "./Avatar";
import { CartIcon, ExternalIcon, EyeOffIcon, GridIcon, PlayIcon, ShareIcon, VerifiedIcon } from "./Icons";
import PinImage from "./PinImage";
import PinMenu from "./PinMenu";
import { Badge, ListingChip, Price } from "./Price";
import QuickAddModal from "./QuickAddModal";
import SavePicker from "./SavePicker";
import { useShare } from "./ShareSheet";
import { useToast } from "./Toast";

export type PinCardAction = { label: string; onClick: (pin: Pin) => void | Promise<void> };

/** Shown in place of a post after "Gyzyklanmaýaryn", with undo. */
export function HiddenCard({ pin, onUndo, className = "" }: { pin: Pin; onUndo: () => void; className?: string }) {
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  return (
    <div className={`hidden-card ${className}`} role="status">
      <EyeOffIcon size={22} />
      <strong>Gizlenildi</strong>
      <span>Muňa meňzeş postlary azrak görersiňiz.</span>
      <button
        className="btn btn-secondary btn-sm"
        disabled={busy}
        onClick={async () => {
          setBusy(true);
          try {
            await api.unhidePin(pin.id);
            onUndo();
          } catch (e) {
            toast(errorMessage(e), "error");
          } finally {
            setBusy(false);
          }
        }}
      >
        Yzyna al
      </button>
    </div>
  );
}

export default function PinCard({ pin, action }: { pin: Pin; action?: PinCardAction }) {
  const [saved, setSaved] = useState(pin.savedBoardIds);
  const [busy, setBusy] = useState(false);
  const [quick, setQuick] = useState(false);
  const [adding, setAdding] = useState(false);
  const [state, setState] = useState<"shown" | "hidden" | "deleted">("shown");
  const { user } = useAuth();
  const toast = useToast();
  const openShare = useShare();
  const addToCart = useAddToCart(toast);
  const href = `/pin/${pin.id}`;
  const product = pin.product;
  const own = !!user && user.id === pin.author.id;
  const out = !!product && product.stock !== null && product.stock <= 0 && isForSale(product);
  const cover = pin.images[0];
  const isVideo = pin.mediaType === "video" || cover?.type === "video";

  if (state === "deleted") return null;
  if (state === "hidden") {
    return (
      <article className="pin">
        <HiddenCard pin={pin} onUndo={() => setState("shown")} />
      </article>
    );
  }

  const onCart = async () => {
    if (!product) return;
    if (product.colors.length > 1 || product.sizes.length > 1) {
      setQuick(true);
      return;
    }
    setAdding(true);
    await addToCart({ pinId: pin.id, color: product.colors[0]?.name, size: product.sizes[0], quantity: 1 });
    setAdding(false);
  };

  return (
    <article className={`pin ${product ? "is-product" : ""}`}>
      <div className="pin-media">
        <Link href={href} aria-label={pin.title}>
          <PinImage pin={pin} />
        </Link>
        {pin.promoted && <span className="promo-chip">Öňe çykarylan</span>}
        {product && (isForSale(product) ? <Badge badge={out ? "" : product.badge} className="pin-badge" /> : <ListingChip type={product.listingType} className="pin-badge" />)}
        {out && <span className="pbadge pbadge-out pin-badge">Gutardy</span>}
        {isVideo ? (
          <span className="pin-video" aria-label="Wideo"><PlayIcon size={11} /> {duration(cover?.duration ?? 0)}</span>
        ) : pin.images.length > 1 ? (
          <span className="pin-multi" aria-label={`${pin.images.length} surat`}><GridIcon size={13} /> {pin.images.length}</span>
        ) : null}
        <div className="pin-overlay">
          <SavePicker pinId={pin.id} savedBoardIds={saved} onChange={setSaved} className="pin-save" />
          <div className="pin-overlay-bottom">
            {pin.link && (
              <a className="round-btn" href={pin.link} target="_blank" rel="noopener noreferrer" aria-label="Çeşmä git">
                <ExternalIcon size={16} />
              </a>
            )}
            <button
              className="round-btn"
              aria-label="Paýlaş"
              onClick={() => openShare(pin)}
            >
              <ShareIcon size={16} />
            </button>
          </div>
          {action && (
            <button
              className="pin-action btn btn-secondary btn-sm"
              disabled={busy}
              onClick={async () => {
                setBusy(true);
                try {
                  await action.onClick(pin);
                } finally {
                  setBusy(false);
                }
              }}
            >
              {action.label}
            </button>
          )}
        </div>
      </div>
      <div className="pin-meta">
        <div className="pin-title-row">
          <Link href={href} className="pin-title">{pin.title}</Link>
          <PinMenu
            pin={pin}
            savedBoardIds={saved}
            onSavedChange={setSaved}
            onHidden={() => setState("hidden")}
            onDeleted={() => setState("deleted")}
          />
        </div>
        {product && (
          <div className="pin-price-row">
            <Price price={product.price} oldPrice={product.oldPrice} type={product.listingType} />
            {!own && isForSale(product) && (
              <button
                className="cart-mini"
                onClick={onCart}
                disabled={adding || out}
                aria-label="Sebede goş"
                title={out ? "Gutardy" : "Sebede goş"}
              >
                {adding ? <span className="spinner" /> : <CartIcon size={18} />}
              </button>
            )}
          </div>
        )}
        <Link href={`/u/${pin.author.username}`} className="pin-author">
          <Avatar user={pin.author} size={22} />
          <span>{pin.author.name}</span>
          {pin.author.verified && <VerifiedIcon size={13} />}
        </Link>
      </div>
      {quick && <QuickAddModal pin={pin} onClose={() => setQuick(false)} />}
    </article>
  );
}
