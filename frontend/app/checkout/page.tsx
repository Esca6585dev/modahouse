"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import { CheckIcon, ShieldIcon, TruckIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useCart } from "@/lib/cart";
import { money } from "@/lib/format";
import { useRequireAuth } from "@/lib/hooks";
import type { BuyNow, Order, UserBrief } from "@/lib/types";

const CONTACT_KEY = "mh_checkout_contact";
const PHONE_RE = /^[0-9+\-\s]{8,20}$/;

type Line = {
  key: string;
  pinId: number;
  title: string;
  imageUrl: string;
  color: string;
  size: string;
  quantity: number;
  price: number;
  shop: UserBrief;
};

function readContact(): { fullName: string; phone: string; address: string } | null {
  try {
    const raw = window.localStorage.getItem(CONTACT_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveContact(c: { fullName: string; phone: string; address: string }) {
  try {
    window.localStorage.setItem(CONTACT_KEY, JSON.stringify(c));
  } catch {
    /* ignore */
  }
}

function Success({ orders }: { orders: Order[] }) {
  const total = orders.reduce((s, o) => s + o.total, 0);
  return (
    <div className="page narrow-sm">
      <div className="success-card">
        <span className="success-icon"><CheckIcon size={40} /></span>
        <h1>Sargydyňyz kabul edildi!</h1>
        <p className="muted">Dükan sargydy tassyklap, size jaň eder. Töleg haryt gowşurylanda tölenýär.</p>
        <ul className="success-orders">
          {orders.map((o) => (
            <li key={o.id}>
              <span>
                <strong>Sargyt #{o.id}</strong>
                <span className="muted small">{o.business.name} · {o.items.reduce((s, i) => s + i.quantity, 0)} haryt</span>
              </span>
              <strong>{money(o.total)}</strong>
            </li>
          ))}
        </ul>
        {orders.length > 1 && <div className="summary-total"><span>Jemi</span><strong>{money(total)}</strong></div>}
        <div className="success-actions">
          <Link href="/orders" className="btn btn-primary btn-lg">Sargytlarym</Link>
          <Link href="/?feed=products" className="btn btn-secondary btn-lg">Söwdany dowam et</Link>
        </div>
      </div>
    </div>
  );
}

function CheckoutView() {
  const { user } = useRequireAuth();
  const params = useSearchParams();
  const router = useRouter();
  const toast = useToast();
  const { refresh } = useCart();
  const buyId = Number(params.get("buy") ?? 0);
  const buyNow: BuyNow | null = useMemo(() => (buyId > 0 ? {
    pinId: buyId,
    color: params.get("color") || undefined,
    size: params.get("size") || undefined,
    quantity: Math.max(1, Math.min(99, Number(params.get("qty") ?? 1) || 1)),
  } : null), [buyId, params]);
  const itemsParam = params.get("items");
  const selectedIds = useMemo(
    () => (itemsParam ? itemsParam.split(",").map(Number).filter((n) => n > 0) : null),
    [itemsParam],
  );

  const [lines, setLines] = useState<Line[] | null>(null);
  const [cartIds, setCartIds] = useState<number[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [form, setForm] = useState({ fullName: "", phone: "", address: "", note: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<Order[] | null>(null);

  useEffect(() => { document.title = "Sargyt etmek · ModaHouse"; }, []);

  const userId = user?.id;
  useEffect(() => {
    if (!user) return;
    const saved = readContact();
    setForm((f) => ({
      ...f,
      fullName: f.fullName || saved?.fullName || user.name,
      phone: f.phone || saved?.phone || "",
      address: f.address || saved?.address || "",
    }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  useEffect(() => {
    if (!userId) return;
    let alive = true;
    setLoadError(null);
    if (buyNow) {
      api.pin(buyNow.pinId).then(
        (p) => {
          if (!alive) return;
          if (!p.product) {
            setLoadError("Bu haryt satylmaýar");
            return;
          }
          setLines([{
            key: `buy-${p.id}`,
            pinId: p.id,
            title: p.title,
            imageUrl: p.imageUrl,
            color: buyNow.color ?? "",
            size: buyNow.size ?? "",
            quantity: buyNow.quantity ?? 1,
            price: p.product.price,
            shop: p.author,
          }]);
        },
        (e) => alive && setLoadError(errorMessage(e)),
      );
    } else {
      api.cart().then(
        (c) => {
          if (!alive) return;
          const items = c.items.filter((i) => i.available && (!selectedIds || selectedIds.includes(i.id)));
          setCartIds(items.map((i) => i.id));
          setLines(items.map((i) => ({
            key: `cart-${i.id}`,
            pinId: i.pin.id,
            title: i.pin.title,
            imageUrl: i.pin.imageUrl,
            color: i.color,
            size: i.size,
            quantity: i.quantity,
            price: i.pin.price,
            shop: i.pin.author,
          })));
        },
        (e) => alive && setLoadError(errorMessage(e)),
      );
    }
    return () => { alive = false; };
  }, [userId, buyNow, selectedIds]);

  const shops = useMemo(() => {
    const m = new Map<number, { shop: UserBrief; lines: Line[]; total: number }>();
    for (const l of lines ?? []) {
      const g = m.get(l.shop.id) ?? { shop: l.shop, lines: [], total: 0 };
      g.lines.push(l);
      g.total += l.price * l.quantity;
      m.set(l.shop.id, g);
    }
    return [...m.values()];
  }, [lines]);
  const total = shops.reduce((s, g) => s + g.total, 0);

  if (done) return <Success orders={done} />;

  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy || !lines?.length) return;
    if (!form.fullName.trim()) return setError("Adyňyzy we familiýaňyzy ýazyň");
    if (!PHONE_RE.test(form.phone.trim())) return setError("Telefon belgisi nädogry. Mysal: +993 61 234567");
    if (!form.address.trim()) return setError("Eltip bermek üçin salgyňyzy ýazyň");
    setBusy(true);
    setError(null);
    try {
      const contact = { fullName: form.fullName.trim(), phone: form.phone.trim(), address: form.address.trim() };
      const orders = await api.createOrder({
        ...contact,
        note: form.note.trim() || undefined,
        ...(buyNow ? { buyNow } : { cartItemIds: cartIds }),
      });
      saveContact(contact);
      refresh();
      setDone(orders);
      window.scrollTo({ top: 0 });
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  if (loadError) {
    return (
      <div className="page narrow">
        <div className="empty">
          <h2>Sargyt edip bolmaýar</h2>
          <p>{loadError}</p>
          <button className="btn btn-primary" onClick={() => router.back()}>Yza gaýt</button>
        </div>
      </div>
    );
  }

  if (lines && lines.length === 0) {
    return (
      <div className="page narrow">
        <div className="empty">
          <h2>Sargyt etmek üçin haryt ýok</h2>
          <p>Sebediňizde elýeterli haryt ýok.</p>
          <Link href="/cart" className="btn btn-primary">Sebede gaýt</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page narrow">
      <h1 className="page-title">Sargyt etmek</h1>
      <div className="cart-layout checkout-layout">
        <form className="card form checkout-form" onSubmit={submit} noValidate>
          <h2>Eltip bermek maglumatlary</h2>
          <label>
            <span>Ady we familiýasy <span className="req">*</span></span>
            <input value={form.fullName} onChange={set("fullName")} maxLength={100} autoComplete="name" placeholder="Mysal: Aýna Orazowa" />
          </label>
          <label>
            <span>Telefon belgisi <span className="req">*</span></span>
            <input type="tel" inputMode="tel" value={form.phone} onChange={set("phone")} maxLength={20} autoComplete="tel" placeholder="+993 61 234567" />
            <small className="hint">Dükan sargydy tassyklamak üçin size jaň eder</small>
          </label>
          <label>
            <span>Salgy <span className="req">*</span></span>
            <textarea rows={2} value={form.address} onChange={set("address")} maxLength={300} autoComplete="street-address" placeholder="Şäher, köçe, jaý, öý" />
          </label>
          <label>
            Bellik
            <textarea rows={2} value={form.note} onChange={set("note")} maxLength={500} placeholder="Mysal: Agşam 18:00-dan soň jaň ediň" />
          </label>
          <div className="pay-note"><ShieldIcon size={18} /> <span><strong>Töleg gowşurylanda.</strong> Onlaýn töleg ýok: harydy alanyňyzda töleýärsiňiz.</span></div>
          {error && <p className="form-error" role="alert">{error}</p>}
          <button className="btn btn-primary btn-block btn-lg" disabled={busy || !lines}>
            {busy ? "Iberilýär…" : `Sargydy tassykla · ${money(total)}`}
          </button>
        </form>

        <aside className="summary">
          <h2>{buyNow ? "Haryt" : "Sargydyňyz"}</h2>
          {!lines ? (
            <div className="skeleton" style={{ height: 120 }} />
          ) : (
            shops.map((g) => (
              <div key={g.shop.id} className="sum-shop">
                <span className="sum-shop-name">{g.shop.name}</span>
                {g.lines.map((l) => (
                  <div key={l.key} className="sum-line">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={l.imageUrl} alt="" />
                    <div>
                      <strong>{l.title}</strong>
                      <span className="muted small">{[l.color, l.size, `${l.quantity} sany`].filter(Boolean).join(" · ")}</span>
                    </div>
                    <span>{money(l.price * l.quantity)}</span>
                  </div>
                ))}
              </div>
            ))
          )}
          <div className="summary-total"><span>Jemi</span><strong>{money(total)}</strong></div>
          <ul className="summary-notes">
            <li><TruckIcon size={16} /> {shops.length > 1 ? `${shops.length} dükan: ${shops.length} aýry sargyt` : "Dükan size jaň edip eltip berer"}</li>
          </ul>
        </aside>
      </div>
    </div>
  );
}

export default function CheckoutPage() {
  return (
    <Suspense fallback={<div className="page" />}>
      <CheckoutView />
    </Suspense>
  );
}
