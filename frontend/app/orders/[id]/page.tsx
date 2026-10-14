"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { BackIcon } from "@/components/Icons";
import OrderCard from "@/components/OrderCard";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useRequireAuth } from "@/lib/hooks";
import type { Order } from "@/lib/types";

/** One order, for the buyer or the seller (the view is chosen from the order itself). */
export default function OrderPage() {
  const { id } = useParams<{ id: string }>();
  const { user } = useRequireAuth();
  const toast = useToast();
  const [order, setOrder] = useState<Order | null>(null);
  const [error, setError] = useState<{ status: number; message: string } | null>(null);

  const userId = user?.id;
  useEffect(() => {
    if (!userId) return;
    let alive = true;
    api.order(id).then(
      (o) => {
        if (!alive) return;
        setOrder(o);
        document.title = `Sargyt #${o.id} · ModaHouse`;
      },
      (e) => alive && setError({ status: e instanceof ApiError ? e.status : 0, message: errorMessage(e) }),
    );
    return () => { alive = false; };
  }, [id, userId]);

  if (error) {
    return (
      <div className="page narrow-sm">
        <div className="empty">
          <h2>{error.status === 404 ? "Sargyt tapylmady" : "Ýüklenmedi"}</h2>
          <p>{error.message}</p>
          <Link href="/orders" className="btn btn-primary">Sargytlarym</Link>
        </div>
      </div>
    );
  }
  if (!user || !order) {
    return <div className="page narrow-sm"><div className="skeleton" style={{ height: 320, borderRadius: 24, marginTop: 56 }} /></div>;
  }

  const view = order.buyer.id === user.id ? "buyer" : "business";
  return (
    <div className="page narrow-sm">
      <div className="page-head">
        <h1 className="page-title">Sargyt #{order.id}</h1>
        <Link href={view === "buyer" ? "/orders" : "/business?tab=orders"} className="btn btn-secondary btn-sm">
          <BackIcon size={16} /> {view === "buyer" ? "Sargytlarym" : "Biznes paneli"}
        </Link>
      </div>
      <OrderCard
        order={order}
        view={view}
        onCancel={async (o) => {
          setOrder(await api.cancelOrder(o.id));
          toast("Sargyt ýatyryldy");
        }}
        onStatus={async (o, s) => {
          setOrder(await api.setOrderStatus(o.id, s));
          toast("Sargydyň ýagdaýy täzelendi");
        }}
      />
    </div>
  );
}
