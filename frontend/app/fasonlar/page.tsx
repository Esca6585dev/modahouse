// Server-rendered page for searches like "fasonlar", "köýnek fasonlary", "ştapel fasonlar":
// real posts with their titles as image alt text, so search engines can index them.

import type { Metadata } from "next";
import Link from "next/link";
import { backendGet, getPins, siteUrl, SITE_DESCRIPTION, SITE_KEYWORDS, SITE_NAME } from "@/lib/seo";
import type { Category } from "@/lib/types";

export const revalidate = 600;

type Props = { searchParams: Promise<{ c?: string; page?: string }> };

async function load(sp: Awaited<Props["searchParams"]>) {
  const cats = (await backendGet<Category[]>("/categories", 3600)) ?? [];
  const c = cats.some((x) => x.slug === sp.c) ? sp.c! : "";
  const page = Math.max(1, Math.min(50, Number(sp.page) || 1));
  const pins = await getPins(`limit=48&page=${page}${c ? `&category=${encodeURIComponent(c)}` : ""}`);
  return { cats, c, page, pins, catName: cats.find((x) => x.slug === c)?.name ?? "" };
}

export async function generateMetadata({ searchParams }: Props): Promise<Metadata> {
  const { c, catName, page } = await load(await searchParams);
  const base = await siteUrl();
  const title = catName ? `${catName}: fasonlar we suratlar · ${SITE_NAME}` : `Fasonlar 2026: köýnek fasonlary, ştapel we milli fasonlar · ${SITE_NAME}`;
  const url = `${base}/fasonlar${c ? `?c=${encodeURIComponent(c)}` : ""}`;
  return {
    title,
    description: SITE_DESCRIPTION,
    keywords: catName ? [catName, ...SITE_KEYWORDS] : SITE_KEYWORDS,
    alternates: { canonical: page > 1 ? `${url}${c ? "&" : "?"}page=${page}` : url },
    openGraph: { type: "website", siteName: SITE_NAME, title, description: SITE_DESCRIPTION, url },
  };
}

export default async function FasonlarPage({ searchParams }: Props) {
  const { cats, c, page, pins, catName } = await load(await searchParams);
  const base = await siteUrl();
  const items = pins?.items ?? [];
  const href = (changes: { c?: string; page?: number }) => {
    const p = new URLSearchParams();
    const cat = changes.c ?? c;
    if (cat) p.set("c", cat);
    if (changes.page && changes.page > 1) p.set("page", String(changes.page));
    const s = p.toString();
    return s ? `/fasonlar?${s}` : "/fasonlar";
  };
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: catName ? `${catName} — fasonlar` : "Fasonlar",
    description: SITE_DESCRIPTION,
    url: `${base}${href({})}`,
    inLanguage: "tk",
    isPartOf: { "@type": "WebSite", name: SITE_NAME, url: base },
    hasPart: items.slice(0, 24).map((p) => ({
      "@type": "ImageObject",
      name: p.title,
      contentUrl: p.imageUrl.startsWith("http") ? p.imageUrl : `${base}${p.imageUrl}`,
      url: `${base}/pin/${p.id}`,
      ...(p.credit ? { creditText: p.credit } : {}),
    })),
  };

  return (
    <div className="page fason-page">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
      <header className="fason-head">
        <h1 className="page-title">{catName ? `${catName}: fasonlar` : "Fasonlar"}</h1>
        <p className="muted">
          Täze köýnek fasonlary, ştapel fasonlar, milli köýnekler, gelin we toý köýnekleri, ýaka fasonlary we el keşdeleri.
          Halan fasonyňyzy saklaň, tikinçä ugradyň ýa-da ussany ModaHouse-da tapyň.
        </p>
      </header>
      <nav className="chips" aria-label="Bölümler">
        <Link href="/fasonlar" className={`chip ${!c ? "active" : ""}`}>Hemmesi</Link>
        {cats.map((x) => (
          <Link key={x.slug} href={href({ c: x.slug, page: 1 })} className={`chip ${c === x.slug ? "active" : ""}`}>{x.name}</Link>
        ))}
      </nav>
      {items.length === 0 ? (
        <div className="empty">
          <h2>Entek fason ýok</h2>
          <p>Ilkinji fasonyňyzy goşuň!</p>
          <Link href="/create" className="btn btn-primary">Fason goş</Link>
        </div>
      ) : (
        <ul className="fason-grid">
          {items.map((p) => (
            <li key={p.id}>
              <Link href={`/pin/${p.id}`} className="fason-item">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={p.imageUrl}
                  alt={p.title}
                  width={p.width || undefined}
                  height={p.height || undefined}
                  loading="lazy"
                  style={{ background: p.color || undefined }}
                />
                <span className="fason-title">{p.title}</span>
                <span className="muted small">@{p.author.username}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
      <nav className="fason-pager" aria-label="Sahypalar">
        {page > 1 && <Link href={href({ page: page - 1 })} className="btn btn-secondary" rel="prev">Öňki</Link>}
        {pins?.hasMore && <Link href={href({ page: page + 1 })} className="btn btn-secondary" rel="next">Indiki fasonlar</Link>}
        <Link href={c ? `/?c=${encodeURIComponent(c)}` : "/"} className="btn btn-primary">ModaHouse-da aç</Link>
      </nav>
    </div>
  );
}
