"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { BagIcon } from "@/components/Icons";
import { InfiniteFooter } from "@/components/Masonry";
import OrderCard from "@/components/OrderCard";
import { useToast } from "@/components/Toast";
import { api } from "@/lib/api";
import { usePaged, useRequireAuth } from "@/lib/hooks";
import type { OrderStatus } from "@/lib/types";

const FILTERS: { value: OrderStatus | ""; label: string }[] = [
  { value: "", label: "Hemmesi" },
  { value: "new", label: "Täze" },
  { value: "confirmed", label: "Tassyklandy" },
  { value: "shipped", label: "Ýolda" },
  { value: "delivered", label: "Gowşuryldy" },
  { value: "cancelled", label: "Ýatyryldy" },
];

export default function OrdersPage() {
  const { user } = useRequireAuth();
  const toast = useToast();
  const [status, setStatus] = useState<OrderStatus | "">("");
  const paged = usePaged(user ? `orders:${user.id}:${status}` : null, (page) => api.orders({ status, page }));

  useEffect(() => { document.title = "Sargytlarym · ModaHouse"; }, []);

  return (
    <div className="page narrow-sm">
      <h1 className="page-title">Sargytlarym</h1>
      <div className="chips" role="tablist">
        {FILTERS.map((f) => (
          <button key={f.value} role="tab" aria-selected={status === f.value} className={`chip ${status === f.value ? "active" : ""}`} onClick={() => setStatus(f.value)}>
            {f.label}
          </button>
        ))}
      </div>

      {!user || !paged.loaded ? (
        <div className="order-list">{[0, 1].map((i) => <div key={i} className="skeleton" style={{ height: 260, borderRadius: 24 }} />)}</div>
      ) : paged.error && paged.items.length === 0 ? (
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{paged.error}</p>
          <button className="btn btn-primary" onClick={paged.reload}>Gaýtadan synanyş</button>
        </div>
      ) : paged.items.length === 0 ? (
        <div className="empty empty-card">
          <span className="empty-icon"><BagIcon size={36} /></span>
          <h2>{status ? "Bu ýagdaýda sargyt ýok" : "Entek sargydyňyz ýok"}</h2>
          <p>Halan harydyňyzy saýlap, «Zakaz et» düwmesine basyň.</p>
          <Link href="/?feed=products" className="btn btn-primary">Harytlara seret</Link>
        </div>
      ) : (
        <div className="order-list">
          {paged.items.map((o) => (
            <OrderCard
              key={o.id}
              order={o}
              view="buyer"
              onCancel={async (ord) => {
                const updated = await api.cancelOrder(ord.id);
                paged.setItems((l) => l.map((x) => (x.id === updated.id ? updated : x)));
                toast("Sargyt ýatyryldy");
              }}
            />
          ))}
        </div>
      )}
      <InfiniteFooter paged={paged} />
    </div>
  );
}
