"use client";

import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { api, errorMessage } from "./api";
import { BUSINESS_CATEGORIES } from "./format";
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

let bizCatsCache: { value: string; label: string }[] | null = null;

/** Business categories from GET /business-categories (falls back to the built-in list while loading or offline). */
export function useBusinessCategories(): { value: string; label: string }[] {
  const [cats, setCats] = useState(bizCatsCache ?? BUSINESS_CATEGORIES);
  useEffect(() => {
    if (bizCatsCache) return;
    let alive = true;
    api.businessCategories().then((l) => {
      if (!Array.isArray(l) || !l.length) return;
      bizCatsCache = l.map((c) => ({ value: c.slug, label: c.name }));
      if (alive) setCats(bizCatsCache);
    }, () => {});
    return () => { alive = false; };
  }, []);
  return cats;
}

/** A value remembered in localStorage (per browser), e.g. the feed view. */
export function useStoredState<T extends string>(key: string, initial: T, allowed: readonly T[]): [T, (v: T) => void] {
  const [value, setValue] = useState<T>(initial);
  useEffect(() => {
    try {
      const v = window.localStorage.getItem(key) as T | null;
      if (v && allowed.includes(v)) setValue(v);
    } catch {
      /* storage unavailable */
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  const set = useCallback((v: T) => {
    setValue(v);
    try {
      window.localStorage.setItem(key, v);
    } catch {
      /* ignore */
    }
  }, [key]);
  return [value, set];
}
