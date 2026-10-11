"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { CloseIcon, SearchIcon } from "./Icons";
import PhotoSearchButton from "./PhotoSearchButton";

/** Header search: text goes to /search?q= (posts, people, hashtags); the camera opens search by photo. */
export default function SearchBar({ className = "", autoFocus }: { className?: string; autoFocus?: boolean }) {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  const current = path === "/search" || path === "/" ? params.get("q") ?? "" : "";
  const [value, setValue] = useState(current);

  // Keep the box in sync with the URL (back/forward, chip clicks).
  useEffect(() => setValue(current), [current]);

  const go = (q: string) => {
    router.push(q ? `/search?q=${encodeURIComponent(q)}` : "/search");
  };

  return (
    <form
      className={`search ${className}`}
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        go(value.trim());
      }}
    >
      <SearchIcon />
      <input
        type="search"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Gözle: köýnek, dükan, #hashtag…"
        aria-label="Gözleg"
        enterKeyHint="search"
        autoFocus={autoFocus}
      />
      {value && (
        <button type="button" className="search-clear" aria-label="Arassala" onClick={() => { setValue(""); if (current) go(""); }}>
          <CloseIcon size={16} />
        </button>
      )}
      <PhotoSearchButton />
    </form>
  );
}
