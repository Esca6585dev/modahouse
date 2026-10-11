"use client";

import Link from "next/link";
import { useState } from "react";
import { useAuth } from "@/lib/auth";
import { useAddToCart } from "@/lib/cart";
import { isForSale } from "@/lib/format";
import { shareUrl } from "@/lib/share";
import type { Pin } from "@/lib/types";
import Avatar from "./Avatar";
import { CartIcon, ExternalIcon, GridIcon, ShareIcon, VerifiedIcon } from "./Icons";
import PinImage from "./PinImage";
import { Badge, Price } from "./Price";
import QuickAddModal from "./QuickAddModal";
import SavePicker from "./SavePicker";
import { useToast } from "./Toast";

export type PinCardAction = { label: string; onClick: (pin: Pin) => void | Promise<void> };

export default function PinCard({ pin, action }: { pin: Pin; action?: PinCardAction }) {
  const [saved, setSaved] = useState(pin.savedBoardIds);
  const [busy, setBusy] = useState(false);
  const [quick, setQuick] = useState(false);
  const [adding, setAdding] = useState(false);
  const { user } = useAuth();
  const toast = useToast();
  const addToCart = useAddToCart(toast);
  const href = `/pin/${pin.id}`;
  const product = pin.product;
  const own = !!user && user.id === pin.author.id;
  const out = !!product && product.stock !== null && product.stock <= 0;

  const onCart = async () => {
    if (!product) return;
    if (product.colors.length > 1 || product.sizes.length > 1) {
      setQuick(true);
      return;
    }
    setAdding(true);
    await addToCart({
      pinId: pin.id,
      color: product.colors[0]?.name,
      size: product.sizes[0],
      quantity: 1,
    });
    setAdding(false);
  };

  return (
    <article className={`pin ${product ? "is-product" : ""}`}>
      <div className="pin-media">
        <Link href={href} aria-label={pin.title}>
          <PinImage pin={pin} />
        </Link>
        {product && <Badge badge={out ? "" : product.badge} className="pin-badge" />}
        {out && <span className="pbadge pbadge-out pin-badge">Gutardy</span>}
        {pin.images.length > 1 && (
          <span className="pin-multi" aria-label={`${pin.images.length} surat`}><GridIcon size={13} /> {pin.images.length}</span>
        )}
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
              onClick={async () => {
                const msg = await shareUrl(href, pin.title);
                if (msg) toast(msg);
              }}
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
        <Link href={href} className="pin-title">{pin.title}</Link>
        {product && (
          <div className="pin-price-row">
            <Price price={product.price} oldPrice={product.oldPrice} />
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
