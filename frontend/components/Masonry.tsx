"use client";

import { useEffect, useRef } from "react";
import type { Paged } from "@/lib/hooks";
import type { Pin } from "@/lib/types";
import PinCard, { type PinCardAction } from "./PinCard";

const SKELETON_RATIOS = [1.4, 1, 1.25, 0.8, 1.5, 1.1, 0.9, 1.3, 1.2, 1, 1.45, 0.85, 1.15, 1.35, 0.95, 1.25];

export function MasonrySkeleton({ count = 16 }: { count?: number }) {
  return (
    <div className="masonry" aria-busy="true" aria-label="Ýüklenýär">
      {SKELETON_RATIOS.slice(0, count).map((r, i) => (
        <div key={i} className="pin">
          <div className="skeleton" style={{ aspectRatio: `1 / ${r}` }} />
          <div className="skeleton skeleton-line" />
        </div>
      ))}
    </div>
  );
}

/** Calls onVisible when scrolled near; re-arms after every load so a short page keeps filling. */
export function InfiniteFooter({ paged }: { paged: Pick<Paged<unknown>, "loading" | "hasMore" | "error" | "loadMore" | "loaded"> }) {
  const ref = useRef<HTMLDivElement>(null);
  const { loading, hasMore, error, loadMore, loaded } = paged;
  const active = loaded && hasMore && !loading && !error;

  useEffect(() => {
    const el = ref.current;
    if (!el || !active) return;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: "800px 0px" });
    io.observe(el);
    return () => io.disconnect();
  }, [active, loadMore]);

  return (
    <div ref={ref} className="infinite-footer">
      {loading && loaded && <span className="spinner" aria-label="Ýüklenýär" />}
      {error && loaded && (
        <div className="inline-error">
          <span>{error}</span>
          <button className="btn btn-secondary btn-sm" onClick={loadMore}>Gaýtadan synanyş</button>
        </div>
      )}
    </div>
  );
}

export default function Masonry({ pins, action }: { pins: Pin[]; action?: PinCardAction }) {
  return (
    <div className="masonry">
      {pins.map((p) => (
        <PinCard key={p.id} pin={p} action={action} />
      ))}
    </div>
  );
}

/** Full paged pin list: skeleton → masonry + infinite scroll, or the given empty state. */
export function PinFeed({ paged, empty, action }: { paged: Paged<Pin>; empty: React.ReactNode; action?: PinCardAction }) {
  if (!paged.loaded) return <MasonrySkeleton />;
  if (paged.error && paged.items.length === 0) {
    return (
      <div className="empty">
        <h2>Ýüklenmedi</h2>
        <p>{paged.error}</p>
        <button className="btn btn-primary" onClick={paged.reload}>Gaýtadan synanyş</button>
      </div>
    );
  }
  if (paged.items.length === 0) return <>{empty}</>;
  return (
    <>
      <Masonry pins={paged.items} action={action} />
      <InfiniteFooter paged={paged} />
    </>
  );
}
