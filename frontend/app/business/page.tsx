"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import Avatar from "@/components/Avatar";
import {
  BagIcon, CashIcon, EditIcon, EyeIcon, HeartIcon, PackageIcon, PlusIcon, StarIcon, StoreIcon, UserIcon,
} from "@/components/Icons";
import { InfiniteFooter } from "@/components/Masonry";
import OrderCard from "@/components/OrderCard";
import { Badge, Price } from "@/components/Price";
import Stars from "@/components/Stars";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { businessCategoryLabel, compact, money, num, PERIODS, stockText } from "@/lib/format";
import { usePaged, useRequireAuth } from "@/lib/hooks";
import type { BusinessStats, OrderStatus, StatsPeriod } from "@/lib/types";

const ORDER_FILTERS: { value: OrderStatus | ""; label: string }[] = [
  { value: "", label: "Hemmesi" },
  { value: "new", label: "Täze" },
  { value: "confirmed", label: "Tassyklandy" },
  { value: "shipped", label: "Ýolda" },
  { value: "delivered", label: "Gowşuryldy" },
  { value: "cancelled", label: "Ýatyryldy" },
];

function StatCard({ icon, label, value, tone }: { icon: React.ReactNode; label: string; value: string; tone: string }) {
  return (
    <div className={`stat-card tone-${tone}`}>
      <span className="stat-icon">{icon}</span>
      <span className="stat-label">{label}</span>
      <strong className="stat-value">{value}</strong>
    </div>
  );
}

function Stats({ period }: { period: StatsPeriod }) {
  const [stats, setStats] = useState<BusinessStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    setStats(null);
    setError(null);
    api.businessStats(period).then((s) => alive && setStats(s), (e) => alive && setError(errorMessage(e)));
    return () => { alive = false; };
  }, [period]);

  if (error) return <p className="form-error">{error}</p>;
  if (!stats) {
    return <div className="stat-grid">{[0, 1, 2, 3].map((i) => <div key={i} className="skeleton" style={{ height: 116, borderRadius: 20 }} />)}</div>;
  }
  return (
    <>
      <div className="stat-grid">
        <StatCard tone="blue" icon={<EyeIcon size={20} />} label="Görülme" value={num(stats.views)} />
        <StatCard tone="red" icon={<HeartIcon size={20} />} label="Halanma" value={num(stats.likes)} />
        <StatCard tone="dark" icon={<BagIcon size={20} />} label="Sargyt" value={num(stats.orders)} />
        <StatCard tone="green" icon={<CashIcon size={20} />} label="Girdeji" value={money(stats.revenue)} />
      </div>
      <div className="mini-stats">
        <span><b className={stats.pendingOrders ? "brand-text" : ""}>{num(stats.pendingOrders)}</b> garaşýan sargyt</span>
        <span><StarIcon size={14} /> <b>{stats.rating ? stats.rating.toFixed(1) : "—"}</b> ({num(stats.reviewsCount)} syn)</span>
        <span><PackageIcon size={14} /> <b>{num(stats.productsCount)}</b> haryt</span>
        <span><UserIcon size={14} /> <b>{compact(stats.followersCount)}</b> yzarlaýjy</span>
      </div>
    </>
  );
}

function IncomingOrders({ userId }: { userId: number }) {
  const toast = useToast();
  const [status, setStatus] = useState<OrderStatus | "">("");
  const paged = usePaged(`border:${userId}:${status}`, (page) => api.businessOrders({ status, page }));
  return (
    <>
      <div className="chips" role="tablist">
        {ORDER_FILTERS.map((f) => (
          <button key={f.value} role="tab" aria-selected={status === f.value} className={`chip ${status === f.value ? "active" : ""}`} onClick={() => setStatus(f.value)}>
            {f.label}
          </button>
        ))}
      </div>
      {!paged.loaded ? (
        <div className="order-list">{[0, 1].map((i) => <div key={i} className="skeleton" style={{ height: 240, borderRadius: 24 }} />)}</div>
      ) : paged.error && paged.items.length === 0 ? (
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{paged.error}</p>
          <button className="btn btn-primary" onClick={paged.reload}>Gaýtadan synanyş</button>
        </div>
      ) : paged.items.length === 0 ? (
        <div className="empty empty-card">
          <span className="empty-icon"><BagIcon size={32} /></span>
          <h2>Sargyt ýok</h2>
          <p>{status ? "Bu ýagdaýda sargyt ýok." : "Täze sargyt gelende şu ýerde we habarnamalarda görersiňiz."}</p>
        </div>
      ) : (
        <div className="order-list">
          {paged.items.map((o) => (
            <OrderCard
              key={o.id}
              order={o}
              view="business"
              onStatus={async (ord, s) => {
                const updated = await api.setOrderStatus(ord.id, s);
                paged.setItems((l) => l.map((x) => (x.id === updated.id ? updated : x)));
                toast(`Sargyt #${updated.id}: ${s === "cancelled" ? "ýatyryldy" : "ýagdaýy täzelendi"}`);
              }}
            />
          ))}
        </div>
      )}
      <InfiniteFooter paged={paged} />
    </>
  );
}

function MyProducts({ username }: { username: string }) {
  const paged = usePaged(`bprod:${username}`, (page) => api.pins({ author: username, type: "products", page }));
  if (!paged.loaded) return <div className="skeleton" style={{ height: 240, borderRadius: 24 }} />;
  if (paged.items.length === 0) {
    return (
      <div className="empty empty-card">
        <span className="empty-icon"><PackageIcon size={32} /></span>
        <h2>Entek haryt ýok</h2>
        <p>Suratlar, baha, reňkler we ölçegler bilen ilkinji harydyňyzy goşuň.</p>
        <Link href="/create" className="btn btn-primary"><PlusIcon size={18} /> Haryt goş</Link>
      </div>
    );
  }
  return (
    <>
      <div className="prod-table" role="table">
        <div className="prod-row prod-headrow" role="row">
          <span role="columnheader">Haryt</span>
          <span role="columnheader">Baha</span>
          <span role="columnheader">Galyndy</span>
          <span role="columnheader">Görülme</span>
          <span role="columnheader">Sargyt</span>
          <span role="columnheader" />
        </div>
        {paged.items.map((p) => (
          <div key={p.id} className="prod-row" role="row">
            <Link href={`/pin/${p.id}`} className="prod-cell-main" role="cell">
              <span className="prod-thumb" style={{ background: p.color }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.imageUrl} alt="" loading="lazy" />
              </span>
              <span className="prod-name">
                <strong>{p.title}</strong>
                <span className="muted small">
                  {p.product?.badge ? <Badge badge={p.product.badge} /> : null}
                  {p.reviewsCount > 0 && <Stars value={p.rating} size={11} count={p.reviewsCount} />}
                </span>
              </span>
            </Link>
            <span role="cell" data-label="Baha">{p.product ? <Price price={p.product.price} oldPrice={p.product.oldPrice} /> : "—"}</span>
            <span role="cell" data-label="Galyndy" className={p.product?.stock === 0 ? "danger-text" : ""}>{p.product ? stockText(p.product.stock) : "—"}</span>
            <span role="cell" data-label="Görülme">{num(p.viewsCount)}</span>
            <span role="cell" data-label="Sargyt">{num(p.ordersCount)}</span>
            <span role="cell" className="prod-edit">
              <Link href={`/pin/${p.id}/edit`} className="icon-btn" aria-label="Üýtget" title="Üýtget"><EditIcon size={18} /></Link>
            </span>
          </div>
        ))}
      </div>
      <InfiniteFooter paged={paged} />
    </>
  );
}

function Dashboard() {
  const { user } = useRequireAuth();
  const params = useSearchParams();
  const router = useRouter();
  const period = (["week", "month", "all"].includes(params.get("period") ?? "") ? params.get("period") : "week") as StatsPeriod;
  const tab = params.get("tab") === "products" ? "products" : "orders";

  useEffect(() => { document.title = "Biznes paneli · ModaHouse"; }, []);

  const go = (k: string, v: string) => {
    const q = new URLSearchParams(params.toString());
    q.set(k, v);
    router.replace(`/business?${q.toString()}`, { scroll: false });
  };

  if (!user) return <div className="page narrow"><div className="skeleton" style={{ height: 400, borderRadius: 24 }} /></div>;

  if (!user.isBusiness || !user.business) {
    return (
      <div className="page narrow-sm">
        <div className="empty empty-card">
          <span className="empty-icon"><StoreIcon size={36} /></span>
          <h2>Biznes hasabyňyz ýok</h2>
          <p>Biznes hasabyny açyň: harytlaryňyzy bahasy bilen goşuň, sargyt kabul ediň we statistikany görüň.</p>
          <Link href="/settings#business" className="btn btn-primary">Biznes hasabyny aç</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page narrow dashboard">
      <header className="dash-head">
        <Avatar user={user} size={56} />
        <div className="dash-title">
          <h1>Biznes paneli</h1>
          <span className="muted">{user.name} · {businessCategoryLabel(user.business.category)}</span>
        </div>
        <div className="dash-actions">
          <Link href={`/u/${user.username}`} className="btn btn-secondary">Dükanyňy gör</Link>
          <Link href="/create" className="btn btn-primary"><PlusIcon size={18} /> Haryt goş</Link>
        </div>
      </header>

      <div className="dash-period">
        <h2 className="block-title">Statistika</h2>
        <div className="seg" role="tablist" aria-label="Döwür">
          {PERIODS.map((p) => (
            <button key={p.value} role="tab" aria-selected={period === p.value} className={period === p.value ? "active" : ""} onClick={() => go("period", p.value)}>
              {p.label}
            </button>
          ))}
        </div>
      </div>
      <Stats period={period} />

      <div className="ig-tabs dash-tabs" role="tablist">
        <button role="tab" aria-selected={tab === "orders"} className={tab === "orders" ? "active" : ""} onClick={() => go("tab", "orders")}>
          <BagIcon size={16} /> Gelen sargytlar
        </button>
        <button role="tab" aria-selected={tab === "products"} className={tab === "products" ? "active" : ""} onClick={() => go("tab", "products")}>
          <PackageIcon size={16} /> Harytlar
        </button>
      </div>
      {tab === "orders" ? <IncomingOrders userId={user.id} /> : <MyProducts username={user.username} />}
    </div>
  );
}

export default function BusinessPage() {
  return (
    <Suspense fallback={<div className="page" />}>
      <Dashboard />
    </Suspense>
  );
}
