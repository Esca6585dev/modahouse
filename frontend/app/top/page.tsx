"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";
import { BagIcon, CrownIcon, EyeIcon, HeartIcon, InfoIcon, SlidersIcon, UserIcon, VerifiedIcon } from "@/components/Icons";
import Stars from "@/components/Stars";
import StoryAvatar from "@/components/StoryAvatar";
import { useStories } from "@/components/StoryViewer";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { businessCategoryLabel, num, PERIODS } from "@/lib/format";
import { useBusinessCategories } from "@/lib/hooks";
import type { StatsPeriod, TopEntry } from "@/lib/types";

function Medal({ rank }: { rank: number }) {
  return <span className={`medal medal-${rank <= 3 ? rank : "n"}`} aria-label={`${rank}-nji orun`}>{rank}</span>;
}

function TopCard({ e }: { e: TopEntry }) {
  const b = e.business;
  const stories = useStories();
  const covers = b.covers.slice(0, 4);
  return (
    <article className={`top-card ${e.rank === 1 ? "first" : ""}`}>
      <Medal rank={e.rank} />
      <div className="top-avatar">
        <StoryAvatar user={b} size={96} ring={b.hasStory ? "unseen" : "none"} onClick={() => stories.openUser(b.username)} />
      </div>
      <div className="top-main">
        <div className="top-name-row">
          <div className="top-name">
            <Link href={`/u/${b.username}`}><h2>{b.name}</h2></Link>
            {b.verified && <VerifiedIcon size={16} />}
          </div>
          <div className="score-pill"><span>Umumy bal:</span><strong>{e.score}/100</strong></div>
        </div>
        <div className="top-sub">
          <Stars value={b.rating} size={14} count={b.reviewsCount} />
          <span className="muted small">{businessCategoryLabel(b.category)}{b.city ? ` · ${b.city}` : ""}</span>
        </div>
        <div className="top-stats">
          <span title="Görülme"><EyeIcon size={15} /> {num(e.views)}</span>
          <span title="Halanma"><HeartIcon size={15} /> {num(e.likes)}</span>
          <span title="Sargyt"><BagIcon size={15} /> {num(e.orders)}</span>
        </div>
        <div className="top-bottom">
          <Link href={`/u/${b.username}?tab=products`} className="top-covers" aria-label="Harytlary">
            {covers.map((c, i) => (
              // eslint-disable-next-line @next/next/no-img-element
              <img key={i} src={c} alt="" loading="lazy" />
            ))}
            {e.moreCount > 0 && <span className="top-more">+{e.moreCount}</span>}
          </Link>
          <div className="top-buttons">
            <Link href={`/u/${b.username}`} className="btn btn-outline btn-sm"><UserIcon size={16} /> Profili gör</Link>
            <Link href={`/u/${b.username}?tab=products`} className="btn btn-primary btn-sm"><BagIcon size={16} /> Köýneklerini gör</Link>
          </div>
        </div>
      </div>
    </article>
  );
}

function TopView() {
  const bizCats = useBusinessCategories();
  const params = useSearchParams();
  const router = useRouter();
  const { ready } = useAuth();
  const period = (["week", "month", "all"].includes(params.get("period") ?? "") ? params.get("period") : "week") as StatsPeriod;
  const category = params.get("category") ?? "";
  const [entries, setEntries] = useState<TopEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [filterOpen, setFilterOpen] = useState(false);
  const [nonce, setNonce] = useState(0);
  const filterRef = useRef<HTMLDivElement>(null);

  useEffect(() => { document.title = "Top 10 köýnekçi · ModaHouse"; }, []);

  useEffect(() => {
    if (!ready) return;
    let alive = true;
    setEntries(null);
    setError(null);
    api.top({ period, category: category || undefined }).then(
      (r) => alive && setEntries(Array.isArray(r) ? r : []),
      (e) => alive && setError(errorMessage(e)),
    );
    return () => { alive = false; };
  }, [period, category, ready, nonce]);

  useEffect(() => {
    if (!filterOpen) return;
    const onDown = (e: MouseEvent) => !filterRef.current?.contains(e.target as Node) && setFilterOpen(false);
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [filterOpen]);

  const go = (changes: Record<string, string>) => {
    const q = new URLSearchParams(params.toString());
    for (const [k, v] of Object.entries(changes)) {
      if (v) q.set(k, v);
      else q.delete(k);
    }
    router.replace(`/top?${q.toString()}`, { scroll: false });
  };

  return (
    <div className="page top-page">
      <section className="top-banner">
        <div className="top-banner-icon"><CrownIcon size={34} /></div>
        <div>
          <h1>Top 10 köýnekçi</h1>
          <p className="top-banner-sub">Iň gowy köýnekçiler</p>
          <p className="top-banner-text">Görülme, halanma we zakaz boýunça umumy reýting.</p>
        </div>
        <div className="top-banner-art" aria-hidden>
          <span>1</span><span>2</span><span>3</span>
        </div>
      </section>

      <div className="top-toolbar">
        <div className="seg" role="tablist" aria-label="Döwür">
          {PERIODS.map((p) => (
            <button key={p.value} role="tab" aria-selected={period === p.value} className={period === p.value ? "active" : ""} onClick={() => go({ period: p.value })}>
              {p.label}
            </button>
          ))}
        </div>
        <div className="menu-wrap" ref={filterRef}>
          <button className={`icon-btn ${category ? "current" : ""}`} onClick={() => setFilterOpen((o) => !o)} aria-label="Kategoriýa süzgüji" aria-expanded={filterOpen}>
            <SlidersIcon />
          </button>
          {filterOpen && (
            <div className="menu" role="menu">
              <button role="menuitemradio" aria-checked={!category} className={`menu-item ${!category ? "checked" : ""}`} onClick={() => { go({ category: "" }); setFilterOpen(false); }}>Ähli kategoriýalar</button>
              {bizCats.map((c) => (
                <button key={c.value} role="menuitemradio" aria-checked={category === c.value} className={`menu-item ${category === c.value ? "checked" : ""}`} onClick={() => { go({ category: c.value }); setFilterOpen(false); }}>
                  {c.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
      {category && (
        <p className="result-note">Kategoriýa: <strong>{businessCategoryLabel(category)}</strong> · <button className="link-btn" onClick={() => go({ category: "" })}>Aýyr</button></p>
      )}

      {error ? (
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{error}</p>
          <button className="btn btn-primary" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>
        </div>
      ) : !entries ? (
        <div className="top-list">
          {[0, 1, 2, 3].map((i) => <div key={i} className="skeleton" style={{ height: 180, borderRadius: 24 }} />)}
        </div>
      ) : entries.length === 0 ? (
        <div className="empty">
          <h2>Entek reýting ýok</h2>
          <p>Bu döwürde harytly dükan tapylmady. Başga döwri saýlap görüň.</p>
          <Link href="/shops" className="btn btn-primary">Dükanlara seret</Link>
        </div>
      ) : (
        <div className="top-list">
          {entries.map((e) => <TopCard key={e.business.id} e={e} />)}
        </div>
      )}

      <p className="top-note"><InfoIcon /> Top 10 sanawyna diňe iň gowy 10 köýnekçi girizilýär. Galan köýnekçiler öz profillerinde galýar.</p>
    </div>
  );
}

export default function TopPage() {
  return (
    <Suspense fallback={<div className="page" />}>
      <TopView />
    </Suspense>
  );
}
