"use client";

import Link from "next/link";
import { useState } from "react";
import { useAddToCart } from "@/lib/cart";
import type { Pin } from "@/lib/types";
import { CartIcon } from "./Icons";
import Modal from "./Modal";
import { Price } from "./Price";
import { ColorSwatches, optionsError, QtyStepper, SizeButtons } from "./ProductOptions";
import { useToast } from "./Toast";

export default function QuickAddModal({ pin, onClose }: { pin: Pin; onClose: () => void }) {
  const product = pin.product!;
  const toast = useToast();
  const addToCart = useAddToCart(toast);
  const [color, setColor] = useState(product.colors.length === 1 ? product.colors[0].name : "");
  const [size, setSize] = useState(product.sizes.length === 1 ? product.sizes[0] : "");
  const [qty, setQty] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const out = product.stock !== null && product.stock <= 0;

  const submit = async () => {
    const err = optionsError(product, color, size);
    if (err) {
      setError(err);
      return;
    }
    setBusy(true);
    const ok = await addToCart({ pinId: pin.id, color: color || undefined, size: size || undefined, quantity: qty });
    setBusy(false);
    if (ok) onClose();
  };

  return (
    <Modal title="Sebede goş" onClose={onClose}>
      <div className="quick-add">
        <div className="qa-head">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={pin.imageUrl} alt="" style={{ background: pin.color }} />
          <div>
            <Link href={`/pin/${pin.id}`} className="qa-title" onClick={onClose}>{pin.title}</Link>
            <span className="muted small">{pin.author.name}</span>
            <Price price={product.price} oldPrice={product.oldPrice} />
          </div>
        </div>
        <ColorSwatches colors={product.colors} value={color} onChange={(c) => { setColor(c); setError(null); }} />
        <SizeButtons sizes={product.sizes} value={size} onChange={(s) => { setSize(s); setError(null); }} />
        <div className="opt-block">
          <div className="opt-label">Sany</div>
          <QtyStepper value={qty} onChange={setQty} max={product.stock ?? 99} />
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}
        <button className="btn btn-primary btn-block btn-lg" onClick={submit} disabled={busy || out}>
          <CartIcon size={20} /> {out ? "Gutardy" : busy ? "Goşulýar…" : "Sebede goş"}
        </button>
      </div>
    </Modal>
  );
}
