"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { CloseIcon, SearchIcon } from "./Icons";

export default function SearchBar() {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  const current = path === "/" ? params.get("q") ?? "" : "";
  const [value, setValue] = useState(current);

  // Keep the box in sync with the URL (back/forward, chip clicks).
  useEffect(() => setValue(current), [current]);

  const go = (q: string) => {
    const next = new URLSearchParams();
    const c = path === "/" ? params.get("c") : null;
    if (q) next.set("q", q);
    if (c) next.set("c", c);
    const s = next.toString();
    router.push(s ? `/?${s}` : "/");
  };

  return (
    <form
      className="search"
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
        placeholder="Gözle: moda, içki bezeg, tagamlar…"
        aria-label="Gözleg"
        enterKeyHint="search"
      />
      {value && (
        <button type="button" className="search-clear" aria-label="Arassala" onClick={() => { setValue(""); if (current) go(""); }}>
          <CloseIcon size={16} />
        </button>
      )}
    </form>
  );
}
