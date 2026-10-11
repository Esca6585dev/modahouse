"use client";

import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { MuteIcon, VolumeIcon } from "./Icons";

// One mute switch for every video on the page (like Instagram): unmuting one unmutes the next.
let muted = true;
const listeners = new Set<() => void>();
const mutedStore = {
  get: () => muted,
  set: (v: boolean) => {
    muted = v;
    listeners.forEach((l) => l());
  },
  subscribe: (l: () => void) => {
    listeners.add(l);
    return () => { listeners.delete(l); };
  },
};

export function useMuted(): [boolean, (v: boolean) => void] {
  const v = useSyncExternalStore(mutedStore.subscribe, mutedStore.get, () => true);
  return [v, mutedStore.set];
}

/**
 * Muted autoplay video that plays only while mostly visible. Tapping toggles sound
 * (unless `onTap` takes over the tap, e.g. for double-tap likes).
 */
export default function VideoMedia({
  src, poster, className = "", fit = "cover", threshold = 0.6, loop = true, showMute = true, onTap, active,
}: {
  src: string;
  poster?: string;
  className?: string;
  fit?: "cover" | "contain";
  threshold?: number;
  loop?: boolean;
  showMute?: boolean;
  onTap?: () => void;
  /** force play/pause from outside (reels); undefined = by visibility */
  active?: boolean;
}) {
  const ref = useRef<HTMLVideoElement>(null);
  const [isMuted, setMuted] = useMuted();
  const [visible, setVisible] = useState(false);
  const [blocked, setBlocked] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || active !== undefined) return;
    const io = new IntersectionObserver(([e]) => setVisible(e.isIntersecting && e.intersectionRatio >= threshold), {
      threshold: [0, threshold, 1],
    });
    io.observe(el);
    return () => io.disconnect();
  }, [threshold, active]);

  const shouldPlay = active ?? visible;
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.muted = isMuted;
    if (shouldPlay) {
      el.play().then(() => setBlocked(false), () => {
        // Autoplay with sound can be blocked: fall back to muted.
        if (!el.muted) {
          el.muted = true;
          el.play().catch(() => setBlocked(true));
        } else setBlocked(true);
      });
    } else el.pause();
  }, [shouldPlay, isMuted]);

  return (
    <div className={`video-media ${className}`} onClick={(e) => {
      e.preventDefault();
      if (onTap) onTap();
      else if (blocked) ref.current?.play().then(() => setBlocked(false), () => {});
      else setMuted(!isMuted);
    }}>
      <video
        ref={ref}
        src={src}
        poster={poster || undefined}
        muted={isMuted}
        loop={loop}
        playsInline
        preload="metadata"
        style={{ objectFit: fit }}
      />
      {showMute && (
        <button
          type="button"
          className="mute-btn"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            setMuted(!isMuted);
          }}
          aria-label={isMuted ? "Sesi aç" : "Sesi öçür"}
        >
          {isMuted ? <MuteIcon size={15} /> : <VolumeIcon size={15} />}
        </button>
      )}
    </div>
  );
}
