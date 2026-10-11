"use client";

import { useRouter } from "next/navigation";
import { useRef } from "react";
import { setPendingPhoto } from "@/lib/visualStore";
import { CameraIcon } from "./Icons";

/** Camera button: pick or take a photo, then open the crop + results screen. */
export default function PhotoSearchButton({ className = "", size = 20 }: { className?: string; size?: number }) {
  const input = useRef<HTMLInputElement>(null);
  const router = useRouter();
  const touch = typeof window !== "undefined" && window.matchMedia?.("(pointer: coarse)").matches;
  return (
    <>
      <button
        type="button"
        className={`photo-search-btn ${className}`}
        onClick={() => input.current?.click()}
        aria-label="Surat bilen gözle"
        title="Surat bilen gözle"
      >
        <CameraIcon size={size} />
      </button>
      <input
        ref={input}
        type="file"
        accept="image/*"
        {...(touch ? { capture: "environment" as const } : {})}
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          e.target.value = "";
          if (!f) return;
          setPendingPhoto(f);
          router.push("/visual");
        }}
      />
    </>
  );
}
