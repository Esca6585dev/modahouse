"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { PinImage } from "@/lib/types";
import { ChevronLeftIcon, ChevronRightIcon } from "./Icons";

/** Swipeable image carousel with "1/N", arrows and thumbnails. Uses CSS scroll-snap for touch. */
export default function Carousel({ images, title, children }: { images: PinImage[]; title: string; children?: React.ReactNode }) {
  const track = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const n = images.length;

  // Tallest image decides the frame ratio (capped), so the box does not jump between slides.
  const ratio = Math.min(1.6, Math.max(0.6, ...images.map((im) => (im.height > 0 && im.width > 0 ? im.height / im.width : 1))));

  const go = useCallback((i: number) => {
    const el = track.current;
    if (!el) return;
    const target = Math.max(0, Math.min(n - 1, i));
    el.scrollTo({ left: target * el.clientWidth, behavior: "smooth" });
    setIndex(target);
  }, [n]);

  useEffect(() => {
    const el = track.current;
    if (!el) return;
    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => setIndex(Math.round(el.scrollLeft / Math.max(1, el.clientWidth))));
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      el.removeEventListener("scroll", onScroll);
      cancelAnimationFrame(raf);
    };
  }, []);

  return (
    <div className="carousel">
      <div className="carousel-frame" style={{ aspectRatio: `1 / ${ratio}` }}>
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
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={im.url} alt={i === 0 ? title : `${title} (${i + 1})`} loading={i === 0 ? "eager" : "lazy"} draggable={false} />
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
      {n > 1 && (
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
              <img src={im.url} alt="" loading="lazy" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
