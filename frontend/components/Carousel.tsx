"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { PinImage } from "@/lib/types";
import { ChevronLeftIcon, ChevronRightIcon } from "./Icons";
import VideoMedia from "./VideoMedia";

/** Swipeable image carousel with "1/N", arrows and thumbnails. Uses CSS scroll-snap for touch. */
export default function Carousel({
  images, title, children, thumbs = true, onDoubleTap, onIndexChange, maxRatio = 1.6, className = "",
}: {
  images: PinImage[];
  title: string;
  children?: React.ReactNode;
  thumbs?: boolean;
  onDoubleTap?: () => void;
  /** current slide, e.g. so "Ýükle" downloads the photo being looked at */
  onIndexChange?: (index: number) => void;
  maxRatio?: number;
  className?: string;
}) {
  const track = useRef<HTMLDivElement>(null);
  const lastTap = useRef(0);
  const [index, setIndex] = useState(0);
  const n = images.length;
  const indexCb = useRef(onIndexChange);
  indexCb.current = onIndexChange;
  useEffect(() => {
    indexCb.current?.(index);
  }, [index]);

  // Tallest image decides the frame ratio (capped), so the box does not jump between slides.
  const ratio = Math.min(maxRatio, Math.max(0.6, ...images.map((im) => (im.height > 0 && im.width > 0 ? im.height / im.width : 1))));

  // While an arrow/thumb scroll animates, scroll events report the slides in between: ignore them
  // until the target is reached, so quick repeated clicks keep advancing.
  const pending = useRef<{ target: number; until: number } | null>(null);

  const go = useCallback((i: number) => {
    const el = track.current;
    if (!el) return;
    const target = Math.max(0, Math.min(n - 1, i));
    pending.current = { target, until: Date.now() + 800 };
    el.scrollTo({ left: target * el.clientWidth, behavior: "smooth" });
    setIndex(target);
  }, [n]);

  useEffect(() => {
    const el = track.current;
    if (!el) return;
    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const i = Math.round(el.scrollLeft / Math.max(1, el.clientWidth));
        const p = pending.current;
        if (p) {
          if (i !== p.target && Date.now() < p.until) return;
          pending.current = null;
        }
        setIndex(i);
      });
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      el.removeEventListener("scroll", onScroll);
      cancelAnimationFrame(raf);
    };
  }, []);

  return (
    <div className={`carousel ${className}`}>
      <div
        className="carousel-frame"
        style={{ aspectRatio: `1 / ${ratio}` }}
        onClickCapture={onDoubleTap ? () => {
          const now = Date.now();
          if (now - lastTap.current < 320) {
            lastTap.current = 0;
            onDoubleTap();
          } else lastTap.current = now;
        } : undefined}
      >
        <div
          className="carousel-track"
          ref={track}
          tabIndex={0}
          aria-roledescription="karusel"
          aria-label={title}
          onKeyDown={(e) => {
            if (e.key === "ArrowRight") go(index + 1);
            if (e.key === "ArrowLeft") go(index - 1);
          }}
        >
          {images.map((im, i) => (
            <div className="carousel-slide" key={im.url + i} style={{ background: im.color || "var(--surface)" }} aria-label={`${i + 1}/${n}`}>
              {im.type === "video" ? (
                <VideoMedia src={im.url} poster={im.posterUrl} fit="cover" />
              ) : (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={im.url} alt={i === 0 ? title : `${title} (${i + 1})`} loading={i === 0 ? "eager" : "lazy"} draggable={false} />
              )}
            </div>
          ))}
        </div>
        {n > 1 && (
          <>
            <span className="carousel-count">{index + 1}/{n}</span>
            <button className="carousel-arrow prev" onClick={() => go(index - 1)} disabled={index === 0} aria-label="Öňki surat">
              <ChevronLeftIcon />
            </button>
            <button className="carousel-arrow next" onClick={() => go(index + 1)} disabled={index === n - 1} aria-label="Indiki surat">
              <ChevronRightIcon />
            </button>
            <div className="carousel-dots" aria-hidden>
              {images.map((_, i) => <span key={i} className={i === index ? "on" : ""} />)}
            </div>
          </>
        )}
        {children}
      </div>
      {n > 1 && thumbs && (
        <div className="thumbs" role="tablist" aria-label="Suratlar">
          {images.map((im, i) => (
            <button
              key={im.url + i}
              role="tab"
              aria-selected={i === index}
              className={`thumb ${i === index ? "on" : ""}`}
              onClick={() => go(i)}
              style={{ background: im.color || "var(--surface)" }}
              aria-label={`${i + 1}-nji surat`}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={im.type === "video" ? im.posterUrl || im.url : im.url} alt="" loading="lazy" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
