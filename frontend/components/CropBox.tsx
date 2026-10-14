"use client";

import { useRef } from "react";

export type Crop = { x: number; y: number; w: number; h: number };
export const FULL_CROP: Crop = { x: 0, y: 0, w: 1, h: 1 };
export const CENTER_CROP: Crop = { x: 0.15, y: 0.15, w: 0.7, h: 0.7 };

const MIN = 0.12;
const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

type Handle = "move" | "nw" | "ne" | "sw" | "se";

/**
 * Photo with an adjustable frame (drag to move, corners to resize, arrow keys too).
 * `onChange` fires continuously while dragging; `onCommit` when the gesture ends.
 */
export default function CropBox({
  src, crop, onChange, onCommit, alt,
}: { src: string; crop: Crop; onChange: (c: Crop) => void; onCommit?: (c: Crop) => void; alt: string }) {
  const wrap = useRef<HTMLDivElement>(null);
  const drag = useRef<{ handle: Handle; startX: number; startY: number; start: Crop; last: Crop } | null>(null);

  const start = (handle: Handle) => (e: React.PointerEvent) => {
    e.preventDefault();
    e.stopPropagation();
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    drag.current = { handle, startX: e.clientX, startY: e.clientY, start: crop, last: crop };
  };

  const move = (e: React.PointerEvent) => {
    const d = drag.current;
    const r = wrap.current?.getBoundingClientRect();
    if (!d || !r) return;
    const dx = (e.clientX - d.startX) / r.width;
    const dy = (e.clientY - d.startY) / r.height;
    const s = d.start;
    let c: Crop;
    if (d.handle === "move") {
      c = { ...s, x: clamp(s.x + dx, 0, 1 - s.w), y: clamp(s.y + dy, 0, 1 - s.h) };
    } else {
      let x1 = s.x, y1 = s.y, x2 = s.x + s.w, y2 = s.y + s.h;
      if (d.handle.includes("w")) x1 = clamp(x1 + dx, 0, x2 - MIN);
      if (d.handle.includes("e")) x2 = clamp(x2 + dx, x1 + MIN, 1);
      if (d.handle.includes("n")) y1 = clamp(y1 + dy, 0, y2 - MIN);
      if (d.handle.includes("s")) y2 = clamp(y2 + dy, y1 + MIN, 1);
      c = { x: x1, y: y1, w: x2 - x1, h: y2 - y1 };
    }
    d.last = c;
    onChange(c);
  };

  const end = () => {
    const d = drag.current;
    drag.current = null;
    if (d && onCommit) onCommit(d.last);
  };

  const onKey = (e: React.KeyboardEvent) => {
    const step = 0.03;
    const k = e.key;
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(k)) return;
    e.preventDefault();
    let c = { ...crop };
    if (e.shiftKey) {
      if (k === "ArrowRight") c.w = clamp(c.w + step, MIN, 1 - c.x);
      if (k === "ArrowLeft") c.w = clamp(c.w - step, MIN, 1 - c.x);
      if (k === "ArrowDown") c.h = clamp(c.h + step, MIN, 1 - c.y);
      if (k === "ArrowUp") c.h = clamp(c.h - step, MIN, 1 - c.y);
    } else {
      if (k === "ArrowRight") c.x = clamp(c.x + step, 0, 1 - c.w);
      if (k === "ArrowLeft") c.x = clamp(c.x - step, 0, 1 - c.w);
      if (k === "ArrowDown") c.y = clamp(c.y + step, 0, 1 - c.h);
      if (k === "ArrowUp") c.y = clamp(c.y - step, 0, 1 - c.h);
    }
    c = { x: c.x, y: c.y, w: c.w, h: c.h };
    onChange(c);
    onCommit?.(c);
  };

  const pct = (v: number) => `${(v * 100).toFixed(2)}%`;
  return (
    <div className="crop-wrap" ref={wrap} onPointerMove={move} onPointerUp={end} onPointerCancel={end}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={alt} draggable={false} />
      <div
        className="crop-frame"
        style={{ left: pct(crop.x), top: pct(crop.y), width: pct(crop.w), height: pct(crop.h) }}
        onPointerDown={start("move")}
        tabIndex={0}
        role="slider"
        aria-label="Gözleg çarçuwasy: süýşürmek üçin ok düwmeleri, ölçegi üçin Shift + ok"
        aria-valuetext={`${Math.round(crop.w * 100)}% × ${Math.round(crop.h * 100)}%`}
        onKeyDown={onKey}
      >
        <span className="crop-grid" aria-hidden />
        {(["nw", "ne", "sw", "se"] as const).map((h) => (
          <span key={h} className={`crop-handle h-${h}`} onPointerDown={start(h)} aria-hidden />
        ))}
      </div>
    </div>
  );
}
