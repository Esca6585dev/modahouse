// Server-rendered topic page (see lib/topics.ts): real posts with their titles
// as image alt text, links to the other topics and languages, and JSON-LD.

import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getPins, siteUrl, SITE_NAME } from "@/lib/seo";
import { LANGS, topic as findTopic, topicPath, TOPICS, UI, type Lang, type Topic } from "@/lib/topics";

const LANG_NAME: Record<Lang, string> = { tk: "Türkmençe", ru: "Русский", en: "English" };
const OG_LOCALE: Record<Lang, string> = { tk: "tk_TM", ru: "ru_RU", en: "en_US" };

export type TopicSearch = Promise<{ page?: string }>;

function resolve(slug: string): Topic {
  const t = findTopic(slug);
  if (!t) notFound();
  return t;
}

const pageOf = (raw?: string) => Math.max(1, Math.min(50, Number(raw) || 1));

export async function topicMetadata(lang: Lang, slug: string, search: TopicSearch): Promise<Metadata> {
  const t = resolve(slug);
  const page = pageOf((await search).page);
  const base = await siteUrl();
  const text = t.text[lang];
  const url = `${base}${topicPath(lang, t.slug)}${page > 1 ? `?page=${page}` : ""}`;
  const languages: Record<string, string> = { "x-default": `${base}${topicPath("tk", t.slug)}` };
  for (const l of LANGS) languages[l] = `${base}${topicPath(l, t.slug)}`;
  return {
    title: `${text.title} · ${SITE_NAME}`,
    description: text.intro,
    keywords: [...text.keywords, "ModaHouse"],
    alternates: { canonical: url, languages },
    openGraph: { type: "website", siteName: SITE_NAME, locale: OG_LOCALE[lang], title: text.title, description: text.intro, url },
  };
}

export default async function TopicPage({ lang, slug, search }: { lang: Lang; slug: string; search: TopicSearch }) {
  const t = resolve(slug);
  const page = pageOf((await search).page);
  const text = t.text[lang];
  const ui = UI[lang];
  const base = await siteUrl();
  const params = new URLSearchParams({ limit: "48", page: String(page) });
  if (t.category) params.set("category", t.category);
  if (t.q) params.set("q", t.q);
  const pins = await getPins(params.toString());
  const items = pins?.items ?? [];
  const here = topicPath(lang, t.slug);
  const openHref = t.category ? `/?c=${t.category}` : t.q ? `/?q=${encodeURIComponent(t.q)}` : "/";

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: text.h1,
    description: text.intro,
    url: `${base}${here}`,
    inLanguage: lang,
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
    <div className="page fason-page" lang={lang}>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
      <nav className="fason-langs" aria-label="Dil">
        {LANGS.map((l) => (
          <Link key={l} href={topicPath(l, t.slug)} hrefLang={l} lang={l} className={l === lang ? "active" : ""} aria-current={l === lang ? "page" : undefined}>
            {LANG_NAME[l]}
          </Link>
        ))}
      </nav>
      <header className="fason-head">
        <h1 className="page-title">{text.h1}</h1>
        <p className="muted">{text.intro}</p>
      </header>
      <nav className="chips" aria-label={ui.topics}>
        {TOPICS.map((x) => (
          <Link key={x.slug} href={topicPath(lang, x.slug)} className={`chip ${x.slug === t.slug ? "active" : ""}`}>
            {x.slug === "fasonlar" ? ui.all : x.text[lang].h1}
          </Link>
        ))}
      </nav>
      {items.length === 0 ? (
        <div className="empty">
          <p>{ui.empty}</p>
          <Link href="/create" className="btn btn-primary">ModaHouse</Link>
        </div>
      ) : (
        <ul className="fason-grid">
          {items.map((p) => (
            <li key={p.id}>
              <Link href={`/pin/${p.id}`} className="fason-item">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.imageUrl} alt={p.title} width={p.width || undefined} height={p.height || undefined} loading="lazy" style={{ background: p.color || undefined }} />
                <span className="fason-title">{p.title}</span>
                <span className="muted small">{ui.by} @{p.author.username}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
      <nav className="fason-pager" aria-label="Pages">
        {page > 1 && <Link href={page === 2 ? here : `${here}?page=${page - 1}`} className="btn btn-secondary" rel="prev">{ui.prev}</Link>}
        {pins?.hasMore && <Link href={`${here}?page=${page + 1}`} className="btn btn-secondary" rel="next">{ui.more}</Link>}
        <Link href={openHref} className="btn btn-primary">{ui.open}</Link>
      </nav>
    </div>
  );
}
