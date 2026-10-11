"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import Avatar from "@/components/Avatar";
import { ChevronRightIcon, HashIcon, ScanIcon, StoreIcon, TrophyIcon, VerifiedIcon } from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import PhotoSearchButton from "@/components/PhotoSearchButton";
import SearchBar from "@/components/SearchBar";
import ShopCard from "@/components/ShopCard";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { compact } from "@/lib/format";
import { useCategories, usePaged } from "@/lib/hooks";
import type { BusinessCard, Pin, SearchResult } from "@/lib/types";

const TILE_COLORS = ["#D7263D", "#262B2F", "#7A2E3A", "#C2185B", "#3B4A6B", "#8D6E63", "#2E7D32", "#6A1B9A", "#F57C00", "#00838F"];

function Results({ q }: { q: string }) {
  const { user, ready } = useAuth();
  const [res, setRes] = useState<SearchResult | null>(null);
  const paged = usePaged(ready ? `sq:${q}:${user?.id ?? 0}` : null, (page) => api.pins({ q, page }));

  useEffect(() => {
    document.title = `“${q}” · Gözleg · ModaHouse`;
    let alive = true;
    setRes(null);
    api.search(q).then((r) => alive && setRes(r), () => alive && setRes({ users: [], tags: [] }));
    return () => { alive = false; };
  }, [q]);

  return (
    <>
      {res && res.users.length > 0 && (
        <section className="sr-block">
          <h2 className="block-title">Adamlar we dükanlar</h2>
          <div className="sr-people">
            {res.users.map((u) => (
              <Link key={u.id} href={`/u/${u.username}`} className="sr-person">
                <Avatar user={u} size={64} />
                <strong>{u.name}{u.verified && <VerifiedIcon size={13} />}</strong>
                <span>@{u.username}</span>
                {u.isBusiness && <span className="sr-biz">Dükan</span>}
              </Link>
            ))}
          </div>
        </section>
      )}
      {res && res.tags.length > 0 && (
        <section className="sr-block">
          <h2 className="block-title">Hashteglar</h2>
          <div className="sr-tags">
            {res.tags.map((t) => (
              <Link key={t.tag} href={`/tag/${encodeURIComponent(t.tag)}`} className="sr-tag">
                <span className="sr-hash"><HashIcon size={18} /></span>
                <span><strong>#{t.tag}</strong><small>{compact(t.count)} post</small></span>
              </Link>
            ))}
          </div>
        </section>
      )}
      <h2 className="block-title">Postlar</h2>
      <PinFeed
        paged={paged}
        empty={
          <div className="empty">
            <h2>“{q}” boýunça post tapylmady</h2>
            <p>Başga söz bilen gözläň ýa-da surat bilen synap görüň.</p>
            <PhotoSearchButton className="btn btn-primary" />
          </div>
        }
      />
    </>
  );
}

function Discover() {
  const cats = useCategories();
  const { ready } = useAuth();
  const [shops, setShops] = useState<BusinessCard[] | null>(null);
  const [covers, setCovers] = useState<Record<string, Pin>>({});

  useEffect(() => { document.title = "Gözleg · ModaHouse"; }, []);
  useEffect(() => {
    if (!ready) return;
    api.businesses({ page: 1, limit: 6 }).then((p) => setShops(p.items), () => setShops([]));
    api.pins({ page: 1, limit: 50 }).then((p) => {
      const m: Record<string, Pin> = {};
      for (const pin of p.items) if (!m[pin.category]) m[pin.category] = pin;
      setCovers(m);
    }, () => {});
  }, [ready]);

  return (
    <>
      <div className="search-links">
        <Link href="/visual" className="search-link photo">
          <span className="sl-icon red"><ScanIcon size={22} /></span>
          <span><strong>Surat bilen gözle</strong><small>Suraty saýla — meňzeş köýnekleri tap</small></span>
          <ChevronRightIcon />
        </Link>
        <Link href="/top" className="search-link">
          <span className="sl-icon gold"><TrophyIcon size={22} /></span>
          <span><strong>Top 10 köýnekçi</strong><small>Hepdäniň iň gowy dükanlary</small></span>
          <ChevronRightIcon />
        </Link>
        <Link href="/shops" className="search-link">
          <span className="sl-icon"><StoreIcon size={22} /></span>
          <span><strong>Ähli dükanlar</strong><small>Kategoriýa boýunça saýla</small></span>
          <ChevronRightIcon />
        </Link>
      </div>

      <h2 className="block-title">Kategoriýalar</h2>
      <div className="cat-tiles">
        {(cats ?? []).map((c, i) => {
          const cover = covers[c.slug];
          return (
            <Link key={c.slug} href={`/?c=${encodeURIComponent(c.slug)}`} className={`cat-tile ${cover ? "has-img" : ""}`} style={{ background: cover?.color ?? TILE_COLORS[i % TILE_COLORS.length] }}>
              {cover && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={cover.imageUrl} alt="" loading="lazy" />
              )}
              <span>{c.name}</span>
            </Link>
          );
        })}
        {cats === null && [0, 1, 2, 3].map((i) => <span key={i} className="cat-tile skeleton" />)}
      </div>

      {shops && shops.length > 0 && (
        <>
          <div className="block-head">
            <h2 className="block-title">Dükanlar</h2>
            <Link href="/shops" className="text-link">Hemmesi</Link>
          </div>
          <div className="shop-grid">
            {shops.map((b) => <ShopCard key={b.id} b={b} />)}
          </div>
        </>
      )}
    </>
  );
}

function SearchView() {
  const params = useSearchParams();
  const q = params.get("q")?.trim() ?? "";
  return (
    <div className={`page search-page ${q ? "" : "narrow"}`}>
      <div className="search-page-bar">
        <SearchBar className="search-big" autoFocus={!q} />
      </div>
      {q ? <Results q={q} /> : <Discover />}
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<div className="page" />}>
      <SearchView />
    </Suspense>
  );
}
