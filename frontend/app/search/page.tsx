"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { ChevronRightIcon, SearchIcon, StoreIcon, TrophyIcon } from "@/components/Icons";
import ShopCard from "@/components/ShopCard";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCategories } from "@/lib/hooks";
import type { BusinessCard } from "@/lib/types";

const TILE_COLORS = ["#D7263D", "#262B2F", "#7A2E3A", "#C2185B", "#3B4A6B", "#8D6E63", "#2E7D32", "#6A1B9A", "#F57C00", "#00838F"];

export default function SearchPage() {
  const router = useRouter();
  const cats = useCategories();
  const { ready } = useAuth();
  const [q, setQ] = useState("");
  const [shops, setShops] = useState<BusinessCard[] | null>(null);

  useEffect(() => { document.title = "Gözleg · ModaHouse"; }, []);
  useEffect(() => {
    if (!ready) return;
    api.businesses({ page: 1, limit: 6 }).then((p) => setShops(p.items), () => setShops([]));
  }, [ready]);

  return (
    <div className="page narrow search-page">
      <form
        className="search search-big"
        role="search"
        onSubmit={(e) => {
          e.preventDefault();
          const v = q.trim();
          router.push(v ? `/?q=${encodeURIComponent(v)}` : "/");
        }}
      >
        <SearchIcon size={20} />
        <input type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Köýnek, dükan, ideýa gözle…" aria-label="Gözleg" autoFocus enterKeyHint="search" />
      </form>

      <div className="search-links">
        <Link href="/top" className="search-link">
          <span className="sl-icon red"><TrophyIcon size={22} /></span>
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
        {(cats ?? []).map((c, i) => (
          <Link key={c.slug} href={`/?c=${encodeURIComponent(c.slug)}`} className="cat-tile" style={{ background: TILE_COLORS[i % TILE_COLORS.length] }}>
            {c.name}
          </Link>
        ))}
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
    </div>
  );
}
