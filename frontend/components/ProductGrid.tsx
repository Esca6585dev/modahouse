"use client";

import Link from "next/link";
import { useState } from "react";
import { useAuth } from "@/lib/auth";
import { useAddToCart } from "@/lib/cart";
import { isForSale } from "@/lib/format";
import type { Paged } from "@/lib/hooks";
import type { Pin } from "@/lib/types";
import { CartIcon, GridIcon } from "./Icons";
import { InfiniteFooter } from "./Masonry";
import { Badge, Price } from "./Price";
import QuickAddModal from "./QuickAddModal";
import Stars from "./Stars";
import { useToast } from "./Toast";

export function ProductTile({ pin }: { pin: Pin }) {
  const { user } = useAuth();
  const toast = useToast();
  const addToCart = useAddToCart(toast);
  const [quick, setQuick] = useState(false);
  const [busy, setBusy] = useState(false);
  const product = pin.product;
  const own = !!user && user.id === pin.author.id;
  const out = !!product && product.stock !== null && product.stock <= 0;

  const onCart = async () => {
    if (!product) return;
    if (product.colors.length > 1 || product.sizes.length > 1) {
      setQuick(true);
      return;
    }
    setBusy(true);
    await addToCart({ pinId: pin.id, color: product.colors[0]?.name, size: product.sizes[0], quantity: 1 });
    setBusy(false);
  };

  return (
    <article className="ptile">
      <Link href={`/pin/${pin.id}`} className="ptile-media" style={{ background: pin.color || "var(--surface)" }} aria-label={pin.title}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={pin.imageUrl} alt={pin.title} loading="lazy" />
        {product && <Badge badge={out ? "" : product.badge} className="pin-badge" />}
        {out && <span className="pbadge pbadge-out pin-badge">Gutardy</span>}
        {pin.images.length > 1 && <span className="pin-multi"><GridIcon size={13} /> {pin.images.length}</span>}
      </Link>
      <div className="ptile-body">
        <Link href={`/pin/${pin.id}`} className="ptile-title">{pin.title}</Link>
        {pin.reviewsCount > 0 && <Stars value={pin.rating} size={12} count={pin.reviewsCount} />}
        <div className="pin-price-row">
          {product ? <Price price={product.price} oldPrice={product.oldPrice} /> : <span className="muted small">Ideýa</span>}
          {product && !own && isForSale(product) && (
            <button className="cart-mini" onClick={onCart} disabled={busy || out} aria-label="Sebede goş" title={out ? "Gutardy" : "Sebede goş"}>
              {busy ? <span className="spinner" /> : <CartIcon size={18} />}
            </button>
          )}
        </div>
      </div>
      {quick && <QuickAddModal pin={pin} onClose={() => setQuick(false)} />}
    </article>
  );
}

export function ProductGridSkeleton({ count = 8 }: { count?: number }) {
  return (
    <div className="pgrid" aria-busy="true">
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="ptile">
          <div className="skeleton" style={{ aspectRatio: "1 / 1" }} />
          <div className="skeleton skeleton-line" />
          <div className="skeleton skeleton-line" style={{ width: "40%" }} />
        </div>
      ))}
    </div>
  );
}

export default function ProductGrid({ paged, empty }: { paged: Paged<Pin>; empty: React.ReactNode }) {
  if (!paged.loaded) return <ProductGridSkeleton />;
  if (paged.error && paged.items.length === 0) {
    return (
      <div className="empty">
        <h2>Ýüklenmedi</h2>
        <p>{paged.error}</p>
        <button className="btn btn-primary" onClick={paged.reload}>Gaýtadan synanyş</button>
      </div>
    );
  }
  if (paged.items.length === 0) return <>{empty}</>;
  return (
    <>
      <div className="pgrid">
        {paged.items.map((p) => <ProductTile key={p.id} pin={p} />)}
      </div>
      <InfiniteFooter paged={paged} />
    </>
  );
}
