"use client";

import Link from "next/link";
import { businessCategoryLabel, compact } from "@/lib/format";
import type { BusinessCard } from "@/lib/types";
import { PinMapIcon, StoreIcon, VerifiedIcon } from "./Icons";
import Stars from "./Stars";
import StoryAvatar from "./StoryAvatar";
import { useStories } from "./StoryViewer";

export default function ShopCard({ b }: { b: BusinessCard }) {
  const stories = useStories();
  const covers = b.covers.slice(0, 4);
  return (
    <article className="shop-card">
      <Link href={`/u/${b.username}?tab=products`} className={`shop-covers n${Math.max(1, covers.length)}`} aria-label={b.name}>
        {covers.length === 0 && <span className="shop-cover-empty"><StoreIcon size={28} /></span>}
        {covers.map((c, i) => (
          // eslint-disable-next-line @next/next/no-img-element
          <img key={i} src={c} alt="" loading="lazy" />
        ))}
      </Link>
      <div className="shop-body">
        <div className="shop-avatar">
          <StoryAvatar user={b} size={56} ring={b.hasStory ? "unseen" : "none"} onClick={() => stories.openUser(b.username)} />
        </div>
        <Link href={`/u/${b.username}`} className="shop-name">
          <strong>{b.name}</strong>
          {b.verified && <VerifiedIcon size={14} />}
        </Link>
        <span className="shop-cat">
          {businessCategoryLabel(b.category)}
          {b.city && <><span className="dot-sep" /><PinMapIcon size={13} /> {b.city}</>}
        </span>
        <Stars value={b.rating} size={13} count={b.reviewsCount} />
        <div className="shop-stats">
          <span><strong>{compact(b.productsCount)}</strong> haryt</span>
          <span><strong>{compact(b.followersCount)}</strong> yzarlaýjy</span>
        </div>
        <Link href={`/u/${b.username}?tab=products`} className="btn btn-secondary btn-sm btn-block">Dükana gir</Link>
      </div>
    </article>
  );
}

