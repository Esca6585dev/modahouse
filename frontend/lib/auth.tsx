"use client";

import { usePathname } from "next/navigation";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import { api, ApiError, getToken, setToken, UNAUTHORIZED_EVENT } from "./api";
import type { Me } from "./types";

const USER_KEY = "mh_user";
const POLL_MS = 60_000;

type AuthState = {
  user: Me | null;
  /** true once we know whether the visitor is logged in (token checked). */
  ready: boolean;
  login: (login: string, password: string) => Promise<Me>;
  register: (b: { username: string; name: string; email: string; password: string }) => Promise<Me>;
  logout: () => void;
  /** true after an explicit logout (pages then navigate away themselves instead of redirecting to login). */
  loggedOut: boolean;
  refreshUser: () => Promise<void>;
  setUser: (u: Me) => void;
  unread: number;
  refreshUnread: () => Promise<void>;
  setUnread: (n: number) => void;
};

const AuthContext = createContext<AuthState | null>(null);

function readCachedUser(): Me | null {
  try {
    const raw = window.localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as Me) : null;
  } catch {
    return null;
  }
}

function cacheUser(u: Me | null) {
  try {
    if (u) window.localStorage.setItem(USER_KEY, JSON.stringify(u));
    else window.localStorage.removeItem(USER_KEY);
  } catch {
    /* ignore */
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUserState] = useState<Me | null>(null);
  const [ready, setReady] = useState(false);
  const [unread, setUnread] = useState(0);
  const [loggedOut, setLoggedOut] = useState(false);
  const path = usePathname();
  // The explicit-logout flag only matters on the page where it happened.
  useEffect(() => setLoggedOut(false), [path]);
  const userRef = useRef<Me | null>(null);

  const setUser = useCallback((u: Me | null) => {
    userRef.current = u;
    setUserState(u);
    cacheUser(u);
  }, []);

  const clear = useCallback(() => {
    setToken(null);
    setUser(null);
    setUnread(0);
  }, [setUser]);

  const refreshUser = useCallback(async () => {
    if (!getToken()) {
      setUser(null);
      return;
    }
    try {
      setUser(await api.me());
    } catch (e) {
      // Only a rejected token logs the visitor out; network errors / rate limits keep the cached session.
      if (e instanceof ApiError && (e.status === 401 || e.status === 404)) clear();
    }
  }, [clear, setUser]);

  // Restore the session on first load.
  useEffect(() => {
    if (!getToken()) {
      cacheUser(null);
      setReady(true);
      return;
    }
    const cached = readCachedUser();
    if (cached) {
      setUser(cached);
      setReady(true);
    }
    refreshUser().finally(() => setReady(true));
  }, [refreshUser, setUser]);

  // Any API call that comes back 401 with a token means the token is no longer valid.
  useEffect(() => {
    const onUnauthorized = () => clear();
    window.addEventListener(UNAUTHORIZED_EVENT, onUnauthorized);
    return () => window.removeEventListener(UNAUTHORIZED_EVENT, onUnauthorized);
  }, [clear]);

  const refreshUnread = useCallback(async () => {
    if (!getToken()) return;
    try {
      const { count } = await api.unreadCount();
      setUnread(count);
    } catch {
      /* keep the last known count */
    }
  }, []);

  const userId = user?.id;
  useEffect(() => {
    if (!userId) return;
    refreshUnread();
    const t = window.setInterval(refreshUnread, POLL_MS);
    const onFocus = () => refreshUnread();
    window.addEventListener("focus", onFocus);
    return () => {
      window.clearInterval(t);
      window.removeEventListener("focus", onFocus);
    };
  }, [userId, refreshUnread]);

  const logout = useCallback(() => {
    setLoggedOut(true);
    clear();
  }, [clear]);

  const login = useCallback(async (loginName: string, password: string) => {
    const res = await api.login({ login: loginName, password });
    setToken(res.token);
    setUser(res.user);
    setLoggedOut(false);
    return res.user;
  }, [setUser]);

  const register = useCallback(async (b: { username: string; name: string; email: string; password: string }) => {
    const res = await api.register(b);
    setToken(res.token);
    setUser(res.user);
    setLoggedOut(false);
    return res.user;
  }, [setUser]);

  const value = useMemo<AuthState>(() => ({
    user, ready, login, register, logout, loggedOut, refreshUser, setUser, unread, refreshUnread, setUnread,
  }), [user, ready, login, register, logout, loggedOut, refreshUser, setUser, unread, refreshUnread]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
