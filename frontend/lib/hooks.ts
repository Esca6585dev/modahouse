"use client";

import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { api, errorMessage } from "./api";
import { useAuth } from "./auth";
import type { Category, Page } from "./types";

export type Paged<T> = {
  items: T[];
  setItems: React.Dispatch<React.SetStateAction<T[]>>;
  loading: boolean;
  error: string | null;
  hasMore: boolean;
  /** true after the first page arrived (or failed). */
  loaded: boolean;
  loadMore: () => void;
  reload: () => void;
};

/**
 * Page-by-page loader for `Page<T>` endpoints. `key` identifies the list; when it
 * changes the list resets. Pass `null` to wait (e.g. until auth is ready).
 */
export function usePaged<T>(key: string | null, fetchPage: (page: number) => Promise<Page<T>>): Paged<T> {
  const [items, setItems] = useState<T[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [nonce, setNonce] = useState(0);

  const fetchRef = useRef(fetchPage);
  fetchRef.current = fetchPage;
  const gen = useRef(0);
  const nextPage = useRef(1);
  const busy = useRef(false);

  const load = useCallback((g: number) => {
    if (busy.current) return;
    busy.current = true;
    setLoading(true);
    setError(null);
    const page = nextPage.current;
    fetchRef.current(page).then(
      (res) => {
        if (g !== gen.current) return;
        setItems((prev) => (page === 1 ? res.items : [...prev, ...res.items]));
        setHasMore(res.hasMore);
        nextPage.current = page + 1;
      },
      (e) => {
        if (g !== gen.current) return;
        setError(errorMessage(e));
      },
    ).finally(() => {
      if (g !== gen.current) return;
      busy.current = false;
      setLoading(false);
      setLoaded(true);
    });
  }, []);

  useEffect(() => {
    gen.current += 1;
    nextPage.current = 1;
    busy.current = false;
    setItems([]);
    setHasMore(true);
    setLoaded(false);
    setError(null);
    if (key === null) return;
    load(gen.current);
  }, [key, nonce, load]);

  const loadMore = useCallback(() => {
    if (key === null) return;
    load(gen.current);
  }, [key, load]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  return { items, setItems, loading, error, hasMore, loaded, loadMore, reload };
}

let categoriesCache: Category[] | null = null;
let categoriesPromise: Promise<Category[]> | null = null;

export function useCategories(): Category[] | null {
  const [cats, setCats] = useState<Category[] | null>(categoriesCache);
  useEffect(() => {
    if (categoriesCache) return;
    categoriesPromise ??= api.categories().then((c) => (categoriesCache = c)).catch((e) => {
      categoriesPromise = null;
      throw e;
    });
    let alive = true;
    categoriesPromise.then((c) => alive && setCats(c)).catch(() => alive && setCats([]));
    return () => { alive = false; };
  }, []);
  return cats;
}

/** Redirects to /login?next=<current path> once we know the visitor is a guest. */
export function useRequireAuth() {
  const { user, ready, loggedOut } = useAuth();
  const router = useRouter();
  const path = usePathname();
  useEffect(() => {
    if (ready && !user && !loggedOut) {
      const next = path + (typeof window !== "undefined" ? window.location.search : "");
      router.replace(`/login?next=${encodeURIComponent(next)}`);
    }
  }, [ready, user, loggedOut, router, path]);
  return { user, ready };
}

/** Path + query of the current page, for ?next= links. */
export function useLoginHref() {
  const path = usePathname();
  return useCallback(() => {
    const here = typeof window !== "undefined" ? window.location.pathname + window.location.search : path;
    return `/login?next=${encodeURIComponent(here)}`;
  }, [path]);
}
