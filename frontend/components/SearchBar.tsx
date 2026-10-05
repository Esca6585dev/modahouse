"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { SearchIcon } from "./Icons";

export default function SearchBar() {
  const router = useRouter();
  const params = useSearchParams();
  const [value, setValue] = useState(params.get("q") ?? "");

  return (
    <form
      className="search"
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        const q = value.trim();
        router.push(q ? `/?q=${encodeURIComponent(q)}` : "/");
      }}
    >
      <SearchIcon />
      <input
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Gözle: moda, içki bezeg, tagamlar…"
        aria-label="Gözleg"
      />
    </form>
  );
}
