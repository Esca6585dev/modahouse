"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { businessCategoryLabel } from "@/lib/format";
import type { Paged } from "@/lib/hooks";
import type { BusinessCard } from "@/lib/types";
import Avatar from "./Avatar";
import type { Pin } from "@/lib/types";
import { CommentIcon, FeedIcon, GridIcon, HeartIcon, MasonryIcon, PlayIcon, ReelsIcon, ScanIcon, SquareGridIcon, TrophyIcon, VerifiedIcon } from "./Icons";
import InstagramPost from "./InstagramPost";
import { InfiniteFooter } from "./Masonry";
import { compact } from "@/lib/format";

export type FeedView = "pinterest" | "instagram";
export const FEED_VIEWS = ["pinterest", "instagram"] as const;
export type ProfileView = "grid" | "masonry";
export const PROFILE_VIEWS = ["grid", "masonry"] as const;

/** Pinterest (masonry) / Instagram (single column) switch. */
export function ViewSwitch({ value, onChange }: { value: FeedView; onChange: (v: FeedView) => void }) {
  return (
    <div className="view-switch" role="radiogroup" aria-label="Görnüşi">
      <button role="radio" aria-checked={value === "pinterest"} className={value === "pinterest" ? "on" : ""} onClick={() => onChange("pinterest")} title="Pinterest görnüşi">
        <MasonryIcon size={18} /> <span>Pinterest</span>
      </button>
      <button role="radio" aria-checked={value === "instagram"} className={value === "instagram" ? "on" : ""} onClick={() => onChange("instagram")} title="Instagram görnüşi">
        <FeedIcon size={18} /> <span>Instagram</span>
      </button>
    </div>
  );
}

/** Grid / masonry switch used on profiles. */
export function ProfileViewSwitch({ value, onChange }: { value: ProfileView; onChange: (v: ProfileView) => void }) {
  return (
    <div className="view-switch small" role="radiogroup" aria-label="Görnüşi">
      <button role="radio" aria-checked={value === "grid"} className={value === "grid" ? "on" : ""} onClick={() => onChange("grid")} aria-label="Gözenek" title="Gözenek (Instagram)">
        <SquareGridIcon size={17} />
      </button>
      <button role="radio" aria-checked={value === "masonry"} className={value === "masonry" ? "on" : ""} onClick={() => onChange("masonry")} aria-label="Masonry" title="Masonry (Pinterest)">
        <MasonryIcon size={17} />
      </button>
    </div>
  );
}

function FeedState({ paged, empty, skeleton }: { paged: Paged<Pin>; empty: React.ReactNode; skeleton: React.ReactNode }) {
  if (!paged.loaded) return <>{skeleton}</>;
  if (paged.error && paged.items.length === 0) {
    return (
      <div className="empty">
        <h2>Ýüklenmedi</h2>
        <p>{paged.error}</p>
        <button className="btn btn-primary" onClick={paged.reload}>Gaýtadan synanyş</button>
      </div>
    );
  }
  return <>{empty}</>;
}

/** Desktop sidebar next to the Instagram view: me + suggested shops. */
function InstaSidebar() {
  const { user } = useAuth();
  const [shops, setShops] = useState<BusinessCard[] | null>(null);
  useEffect(() => {
    api.businesses({ page: 1, limit: 6 }).then((p) => setShops(p.items.filter((b) => b.id !== user?.id).slice(0, 5)), () => setShops([]));
  }, [user?.id]);
  return (
    <aside className="insta-side">
      {user && (
        <Link href={`/u/${user.username}`} className="is-me">
          <Avatar user={user} size={48} />
          <span><strong>{user.username}</strong><small>{user.name}</small></span>
        </Link>
      )}
      <div className="is-head"><span>Saňa maslahat berilýän dükanlar</span><Link href="/shops">Hemmesi</Link></div>
      <ul className="is-list">
        {(shops ?? []).map((b) => (
          <li key={b.id}>
            <Link href={`/u/${b.username}`} className="is-shop">
              <Avatar user={b} size={36} />
              <span>
                <strong>{b.username}{b.verified && <VerifiedIcon size={12} />}</strong>
                <small>{businessCategoryLabel(b.category)}{b.city ? ` · ${b.city}` : ""}</small>
              </span>
            </Link>
          </li>
        ))}
        {shops === null && [0, 1, 2].map((i) => <li key={i}><span className="skeleton" style={{ display: "block", height: 36, width: "100%" }} /></li>)}
      </ul>
      <nav className="is-links">
        <Link href="/reels"><ReelsIcon size={16} /> Reels</Link>
        <Link href="/top"><TrophyIcon size={16} /> Top 10</Link>
        <Link href="/visual"><ScanIcon size={16} /> Surat bilen gözle</Link>
      </nav>
      <p className="is-foot">© 2026 moda HOUSE · Türkmen modasy</p>
    </aside>
  );
}

/** Instagram view: a single column of full posts. */
export function PostFeed({ paged, empty }: { paged: Paged<Pin>; empty: React.ReactNode }) {
  if (!paged.loaded || paged.items.length === 0) {
    return (
      <FeedState
        paged={paged}
        empty={empty}
        skeleton={
          <div className="post-feed" aria-busy="true">
            {[0, 1].map((i) => (
              <div key={i} className="ig-post">
                <div className="igp-head"><span className="skeleton" style={{ width: 36, height: 36, borderRadius: "50%" }} /><span className="skeleton skeleton-line" style={{ width: 140, margin: 0 }} /></div>
                <div className="skeleton" style={{ aspectRatio: "4 / 5", borderRadius: 0 }} />
                <div className="skeleton skeleton-line" style={{ width: "50%", margin: "14px" }} />
              </div>
            ))}
          </div>
        }
      />
    );
  }
  return (
    <div className="post-layout">
      <div>
        <div className="post-feed">
          {paged.items.map((p) => <InstagramPost key={p.id} pin={p} />)}
        </div>
        <InfiniteFooter paged={paged} />
      </div>
      <InstaSidebar />
    </div>
  );
}

/** Instagram profile grid: square tiles, hover shows likes and comments. */
export function SquareGrid({ paged, empty }: { paged: Paged<Pin>; empty: React.ReactNode }) {
  if (!paged.loaded || paged.items.length === 0) {
    return (
      <FeedState
        paged={paged}
        empty={empty}
        skeleton={<div className="sq-grid" aria-busy="true">{Array.from({ length: 9 }, (_, i) => <div key={i} className="skeleton sq-tile" />)}</div>}
      />
    );
  }
  return (
    <>
      <div className="sq-grid">
        {paged.items.map((p) => (
          <Link key={p.id} href={`/pin/${p.id}`} className="sq-tile" style={{ background: p.color }} aria-label={p.title}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={p.imageUrl} alt={p.title} loading="lazy" />
            {p.mediaType === "video" ? (
              <span className="sq-icon"><PlayIcon size={14} /></span>
            ) : p.images.length > 1 ? (
              <span className="sq-icon"><GridIcon size={14} /></span>
            ) : null}
            <span className="sq-hover">
              <span><HeartIcon size={18} /> {compact(p.likesCount)}</span>
              <span><CommentIcon size={18} /> {compact(p.commentsCount)}</span>
            </span>
          </Link>
        ))}
      </div>
      <InfiniteFooter paged={paged} />
    </>
  );
}
