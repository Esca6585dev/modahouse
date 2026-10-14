"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { FEED_VIEWS, PostFeed, ViewSwitch } from "@/components/FeedViews";
import { HashIcon } from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { compact } from "@/lib/format";
import { usePaged, useStoredState } from "@/lib/hooks";

export default function TagPage() {
  const { tag: raw } = useParams<{ tag: string }>();
  const tag = decodeURIComponent(raw).replace(/^#/, "").toLocaleLowerCase("tk");
  const { user, ready } = useAuth();
  const [view, setView] = useStoredState("mh_view", "pinterest", FEED_VIEWS);
  const insta = view === "instagram";
  const [count, setCount] = useState<number | null>(null);
  const [related, setRelated] = useState<{ tag: string; count: number }[]>([]);
  const paged = usePaged(ready ? `tag:${tag}:${insta}:${user?.id ?? 0}` : null, (page) =>
    api.pins({ tag, page, withComments: insta, limit: insta ? 12 : undefined }));

  useEffect(() => {
    document.title = `#${tag} · ModaHouse`;
    let alive = true;
    api.search(tag).then((r) => {
      if (!alive) return;
      setCount(r.tags.find((t) => t.tag.toLocaleLowerCase("tk") === tag)?.count ?? null);
      setRelated(r.tags.filter((t) => t.tag.toLocaleLowerCase("tk") !== tag).slice(0, 8));
    }, () => {});
    return () => { alive = false; };
  }, [tag]);

  const cover = paged.items[0];
  return (
    <div className="page">
      <header className="tag-head">
        <span className="tag-cover" style={{ background: cover?.color }}>
          {cover ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={cover.imageUrl} alt="" />
          ) : (
            <HashIcon size={36} />
          )}
        </span>
        <div className="tag-info">
          <h1>#{tag}</h1>
          <p className="muted">
            {count !== null ? `${compact(count)} post` : paged.loaded ? `${paged.items.length}${paged.hasMore ? "+" : ""} post` : "…"}
          </p>
          {related.length > 0 && (
            <div className="tag-related">
              {related.map((t) => <Link key={t.tag} href={`/tag/${encodeURIComponent(t.tag)}`} className="tag">#{t.tag}</Link>)}
            </div>
          )}
        </div>
        <ViewSwitch value={view} onChange={setView} />
      </header>
      {(() => {
        const empty = (
          <div className="empty">
            <h2>#{tag} bilen post ýok</h2>
            <p>Ilkinji bolup şu hashtag bilen post paýlaşyň.</p>
            <Link href="/create" className="btn btn-primary">Post döret</Link>
          </div>
        );
        return insta ? <PostFeed paged={paged} empty={empty} /> : <PinFeed paged={paged} empty={empty} />;
      })()}
    </div>
  );
}
