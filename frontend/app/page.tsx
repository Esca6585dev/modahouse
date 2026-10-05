"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { MasonrySkeleton, PinFeed } from "@/components/Masonry";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCategories, usePaged } from "@/lib/hooks";

function hrefWith(params: URLSearchParams, changes: Record<string, string | null>) {
  const next = new URLSearchParams(params.toString());
  for (const [k, v] of Object.entries(changes)) {
    if (v) next.set(k, v);
    else next.delete(k);
  }
  const s = next.toString();
  return s ? `/?${s}` : "/";
}

function Feed() {
  const params = useSearchParams();
  const q = params.get("q")?.trim() ?? "";
  const c = params.get("c") ?? "";
  const wantsFollowing = params.get("feed") === "following";
  const { user, ready } = useAuth();
  const cats = useCategories();
  const following = wantsFollowing && !!user;

  const key = ready ? JSON.stringify({ q, c, following, u: user?.id ?? 0 }) : null;
  const paged = usePaged(key, (page) =>
    api.pins({ q, category: c, feed: following ? "following" : undefined, page }));

  const catName = cats?.find((x) => x.slug === c)?.name;

  return (
    <div className="page">
      {user && (
        <div className="feed-toggle" role="tablist" aria-label="Lenta">
          <Link role="tab" aria-selected={!following} href={hrefWith(params, { feed: null })} className={!following ? "active" : ""}>Saňa</Link>
          <Link role="tab" aria-selected={following} href={hrefWith(params, { feed: "following" })} className={following ? "active" : ""}>Yzarlanýanlar</Link>
        </div>
      )}
      <div className="chips" role="list">
        <Link href={hrefWith(params, { c: null })} className={`chip ${!c ? "active" : ""}`} role="listitem">Hemmesi</Link>
        {cats === null
          ? [0, 1, 2, 3, 4, 5].map((i) => <span key={i} className="chip chip-skel" aria-hidden />)
          : cats.map((cat) => (
            <Link
              key={cat.slug}
              href={hrefWith(params, { c: cat.slug })}
              className={`chip ${c === cat.slug ? "active" : ""}`}
              role="listitem"
            >
              {cat.name}
            </Link>
          ))}
      </div>

      {q && (
        <p className="result-note">
          “{q}” boýunça netijeler{catName ? ` · ${catName}` : ""}
        </p>
      )}

      <PinFeed
        paged={paged}
        empty={
          following && !q && !c ? (
            <div className="empty">
              <h2>Lentaňyz entek boş</h2>
              <p>Halaýan awtorlaryňyzy yzarlaň — olaryň täze pinleri şu ýerde görüner.</p>
              <Link href={hrefWith(params, { feed: null })} className="btn btn-primary">Ähli pinlere seret</Link>
            </div>
          ) : (
            <div className="empty">
              <h2>Hiç zat tapylmady</h2>
              <p>Başga söz bilen gözläp görüň ýa-da kategoriýany üýtgediň.</p>
              <Link href="/" className="btn btn-primary">Ähli pinlere gaýt</Link>
            </div>
          )
        }
      />
    </div>
  );
}

export default function Home() {
  return (
    <Suspense fallback={<div className="page"><MasonrySkeleton /></div>}>
      <Feed />
    </Suspense>
  );
}
