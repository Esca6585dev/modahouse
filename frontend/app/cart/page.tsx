"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import Avatar from "@/components/Avatar";
import { CartIcon, ShieldIcon, TrashIcon, TruckIcon, VerifiedIcon } from "@/components/Icons";
import { Price } from "@/components/Price";
import { QtyStepper } from "@/components/ProductOptions";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useCart } from "@/lib/cart";
import { money } from "@/lib/format";
import { useRequireAuth } from "@/lib/hooks";
import type { Cart, CartItem, UserBrief } from "@/lib/types";

type Group = { shop: UserBrief; items: CartItem[]; subtotal: number; availableIds: number[] };

function groupByShop(items: CartItem[]): Group[] {
  const map = new Map<number, Group>();
  for (const it of items) {
    const shop = it.pin.author;
    let g = map.get(shop.id);
    if (!g) {
      g = { shop, items: [], subtotal: 0, availableIds: [] };
      map.set(shop.id, g);
    }
    g.items.push(it);
    if (it.available) {
      g.subtotal += it.lineTotal;
      g.availableIds.push(it.id);
    }
  }
  return [...map.values()];
}

export default function CartPage() {
  const { user } = useRequireAuth();
  const { setCount } = useCart();
  const toast = useToast();
  const [cart, setCart] = useState<Cart | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<number | "all" | null>(null);
  const [nonce, setNonce] = useState(0);

  useEffect(() => { document.title = "Sebet · ModaHouse"; }, []);

  const userId = user?.id;
  useEffect(() => {
    if (!userId) return;
    let alive = true;
    setError(null);
    api.cart().then(
      (c) => {
        if (!alive) return;
        setCart(c);
        setCount(c.count);
      },
      (e) => alive && setError(errorMessage(e)),
    );
    return () => { alive = false; };
  }, [userId, nonce, setCount]);

  const groups = useMemo(() => (cart ? groupByShop(cart.items) : []), [cart]);
  const availableCount = cart?.items.filter((i) => i.available).length ?? 0;

  const apply = async (key: number | "all", fn: () => Promise<Cart>) => {
    setBusy(key);
    try {
      const c = await fn();
      setCart(c);
      setCount(c.count);
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(null);
    }
  };

  if (!user || (!cart && !error)) {
    return (
      <div className="page narrow">
        <h1 className="page-title">Sebet</h1>
        <div className="cart-layout">
          <div>{[0, 1].map((i) => <div key={i} className="skeleton" style={{ height: 160, borderRadius: 24, marginBottom: 16 }} />)}</div>
          <div className="skeleton" style={{ height: 220, borderRadius: 24 }} />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="page narrow">
        <h1 className="page-title">Sebet</h1>
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{error}</p>
          <button className="btn btn-primary" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>
        </div>
      </div>
    );
  }

  if (!cart || cart.items.length === 0) {
    return (
      <div className="page narrow">
        <h1 className="page-title">Sebet</h1>
        <div className="empty empty-card">
          <span className="empty-icon"><CartIcon size={36} /></span>
          <h2>Sebediňiz boş</h2>
          <p>Halan harytlaryňyzy sebede goşuň we bir gezekde sargyt ediň.</p>
          <Link href="/?feed=products" className="btn btn-primary">Harytlara seret</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page narrow">
      <div className="page-head">
        <h1 className="page-title">Sebet <span className="muted">({cart.count})</span></h1>
        <button
          className="btn btn-secondary btn-sm"
          disabled={busy !== null}
          onClick={() => window.confirm("Sebedi boşatmalymy?") && apply("all", api.clearCart)}
        >
          <TrashIcon size={16} /> Boşat
        </button>
      </div>

      <div className="cart-layout">
        <div className="cart-groups">
          {groups.map((g) => (
            <section key={g.shop.id} className="cart-group">
              <header className="cart-shop">
                <Link href={`/u/${g.shop.username}`} className="cart-shop-link">
                  <Avatar user={g.shop} size={32} />
                  <strong>{g.shop.name}</strong>
                  {g.shop.verified && <VerifiedIcon size={14} />}
                </Link>
                <span className="muted small">{g.items.length} haryt</span>
              </header>
              <ul className="cart-items">
                {g.items.map((it) => (
                  <li key={it.id} className={`cart-item ${it.available ? "" : "unavailable"}`}>
                    <Link href={`/pin/${it.pin.id}`} className="cart-thumb" style={{ background: it.pin.color }}>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      {it.pin.imageUrl && <img src={it.pin.imageUrl} alt="" loading="lazy" />}
                    </Link>
                    <div className="cart-info">
                      <Link href={`/pin/${it.pin.id}`} className="cart-title">{it.pin.title}</Link>
                      <div className="cart-opts">
                        {it.color && <span className="opt-chip">Reňk: {it.color}</span>}
                        {it.size && <span className="opt-chip">Ölçeg: {it.size}</span>}
                      </div>
                      <Price price={it.pin.price} oldPrice={it.pin.oldPrice} />
                      {!it.available && (
                        <span className="cart-warn">
                          {it.pin.stock === 0 ? "Gutardy" : it.pin.stock !== null && it.pin.stock < it.quantity ? `Diňe ${it.pin.stock} sany galdy` : "Häzir elýeterli däl"}
                        </span>
                      )}
                      <div className="cart-row">
                        <QtyStepper
                          small
                          value={it.quantity}
                          max={it.pin.stock ?? 99}
                          onChange={(n) => apply(it.id, () => api.updateCartItem(it.id, n))}
                        />
                        <strong className="cart-line">{money(it.lineTotal)}</strong>
                        <button className="icon-btn danger" onClick={() => apply(it.id, () => api.removeCartItem(it.id))} disabled={busy === it.id} aria-label="Aýyr" title="Aýyr">
                          <TrashIcon size={18} />
                        </button>
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
              <footer className="cart-group-foot">
                <span>Jemi: <strong>{money(g.subtotal)}</strong></span>
                {g.availableIds.length > 0 && groups.length > 1 && (
                  <Link href={`/checkout?items=${g.availableIds.join(",")}`} className="btn btn-secondary btn-sm">Diňe şu dükandan sargyt et</Link>
                )}
              </footer>
            </section>
          ))}
        </div>

        <aside className="summary">
          <h2>Sargyt jemi</h2>
          <div className="summary-row"><span>Harytlar ({cart.count})</span><span>{money(cart.total)}</span></div>
          <div className="summary-row"><span>Eltip bermek</span><span className="ok-text">Dükan bilen ylalaşyk</span></div>
          <div className="summary-total"><span>Jemi</span><strong>{money(cart.total)}</strong></div>
          {availableCount > 0 ? (
            <Link href="/checkout" className="btn btn-primary btn-block btn-lg">Sargyt et</Link>
          ) : (
            <button className="btn btn-primary btn-block btn-lg" disabled>Sargyt et</button>
          )}
          <ul className="summary-notes">
            <li><ShieldIcon size={16} /> Töleg haryt gowşurylanda</li>
            <li><TruckIcon size={16} /> Her dükan üçin aýry sargyt döredilýär</li>
          </ul>
        </aside>
      </div>

      <div className="mobile-bar">
        <span><small>Jemi</small><strong>{money(cart.total)}</strong></span>
        {availableCount > 0 ? (
          <Link href="/checkout" className="btn btn-primary btn-lg">Sargyt et</Link>
        ) : (
          <button className="btn btn-primary btn-lg" disabled>Sargyt et</button>
        )}
      </div>
    </div>
  );
}
