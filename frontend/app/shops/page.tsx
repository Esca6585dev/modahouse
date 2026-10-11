"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { SearchIcon } from "@/components/Icons";
import { InfiniteFooter } from "@/components/Masonry";
import ShopCard from "@/components/ShopCard";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { BUSINESS_CATEGORIES } from "@/lib/format";
import { usePaged } from "@/lib/hooks";

function ShopsView() {
  const params = useSearchParams();
  const router = useRouter();
  const { ready } = useAuth();
  const category = params.get("category") ?? "";
  const q = params.get("q") ?? "";
  const [text, setText] = useState(q);
  useEffect(() => setText(q), [q]);
  useEffect(() => { document.title = "Dükanlar · ModaHouse"; }, []);

  const paged = usePaged(ready ? `shops:${category}:${q}` : null, (page) => api.businesses({ q, category, page }));

  const go = (changes: Record<string, string>) => {
    const next = new URLSearchParams(params.toString());
    for (const [k, v] of Object.entries(changes)) {
      if (v) next.set(k, v);
      else next.delete(k);
    }
    const s = next.toString();
    router.replace(s ? `/shops?${s}` : "/shops", { scroll: false });
  };

  return (
    <div className="page shops-page">
      <div className="page-head">
        <div>
          <h1 className="page-title">Dükanlar</h1>
          <p className="muted">Köýnek dükanlary, tikinçiler, butikler we dizaýnerler</p>
        </div>
        <form className="search search-inline" role="search" onSubmit={(e) => { e.preventDefault(); go({ q: text.trim() }); }}>
          <SearchIcon />
          <input type="search" value={text} onChange={(e) => setText(e.target.value)} placeholder="Dükan gözle…" aria-label="Dükan gözle" />
        </form>
      </div>
      <div className="chips" role="list">
        <button className={`chip ${!category ? "active" : ""}`} onClick={() => go({ category: "" })}>Hemmesi</button>
        {BUSINESS_CATEGORIES.map((c) => (
          <button key={c.value} className={`chip ${category === c.value ? "active" : ""}`} onClick={() => go({ category: c.value })}>{c.label}</button>
        ))}
      </div>

      {!paged.loaded ? (
        <div className="shop-grid">
          {[0, 1, 2, 3, 4, 5].map((i) => <div key={i} className="skeleton" style={{ height: 330, borderRadius: 24 }} />)}
        </div>
      ) : paged.error && paged.items.length === 0 ? (
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{paged.error}</p>
          <button className="btn btn-primary" onClick={paged.reload}>Gaýtadan synanyş</button>
        </div>
      ) : paged.items.length === 0 ? (
        <div className="empty">
          <h2>Dükan tapylmady</h2>
          <p>{q || category ? "Başga söz ýa-da kategoriýa bilen synanyşyň." : "Entek dükan ýok. Ilkinji bolup biznes hasabyny açyň!"}</p>
          <Link href="/settings#business" className="btn btn-primary">Biznes hasabyny aç</Link>
        </div>
      ) : (
        <>
          <div className="shop-grid">
            {paged.items.map((b) => <ShopCard key={b.id} b={b} />)}
          </div>
          <InfiniteFooter paged={paged} />
        </>
      )}
    </div>
  );
}

export default function ShopsPage() {
  return (
    <Suspense fallback={<div className="page" />}>
      <ShopsView />
    </Suspense>
  );
}
