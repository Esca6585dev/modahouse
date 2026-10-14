"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";

/**
 * Popover anchored to a button on wide screens, bottom sheet on phones (< 600px).
 * Closes on outside click and Escape.
 */
export default function Popover({
  anchor, open, onClose, width = 300, label, className = "", children,
}: {
  anchor: React.RefObject<HTMLElement | null>;
  open: boolean;
  onClose: () => void;
  width?: number;
  label: string;
  className?: string;
  children: React.ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState<{ top: number; left: number; maxHeight: number } | null>(null);
  const [sheet, setSheet] = useState(false);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  const place = useCallback(() => {
    const b = anchor.current?.getBoundingClientRect();
    if (!b) return;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const isSheet = vw < 600;
    setSheet(isSheet);
    if (isSheet) return;
    const left = Math.min(Math.max(16, b.right - width), vw - width - 16);
    const below = vh - b.bottom - 16;
    const above = b.top - 16;
    if (below >= 300 || below >= above) setPos({ top: b.bottom + 6, left, maxHeight: Math.max(200, below - 6) });
    else {
      const maxHeight = Math.min(480, above - 6);
      setPos({ top: b.top - 6 - maxHeight, left, maxHeight });
    }
  }, [anchor, width]);

  useLayoutEffect(() => {
    if (!open) return;
    place();
    window.addEventListener("resize", place);
    window.addEventListener("scroll", place, true);
    return () => {
      window.removeEventListener("resize", place);
      window.removeEventListener("scroll", place, true);
    };
  }, [open, place]);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      const t = e.target as Node;
      if (ref.current?.contains(t) || anchor.current?.contains(t)) return;
      closeRef.current();
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && closeRef.current();
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, anchor]);

  useEffect(() => {
    if (open) ref.current?.querySelector<HTMLElement>("button, a, input")?.focus({ preventScroll: true });
  }, [open, sheet, pos === null]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!open || (!sheet && !pos)) return null;
  return createPortal(
    <>
      {sheet && <div className="sheet-backdrop" onMouseDown={onClose} />}
      <div
        ref={ref}
        className={`picker ${sheet ? "sheet" : ""} ${className}`}
        style={sheet || !pos ? undefined : { top: pos.top, left: pos.left, width, maxHeight: pos.maxHeight }}
        role="dialog"
        aria-label={label}
        onClick={(e) => e.stopPropagation()}
      >
        {sheet && <span className="sheet-grip" aria-hidden />}
        {children}
      </div>
    </>,
    document.body,
  );
}
