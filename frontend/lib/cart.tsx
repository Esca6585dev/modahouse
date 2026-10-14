"use client";

import { useRouter } from "next/navigation";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { api, errorMessage, getToken } from "./api";
import { useAuth } from "./auth";
import { useLoginHref } from "./hooks";
import type { Cart } from "./types";

type CartState = {
  count: number;
  setCount: (n: number) => void;
  refresh: () => Promise<void>;
  /** Adds a product line; returns the updated cart. Throws an Error with a Turkmen message on failure. */
  add: (b: { pinId: number; color?: string; size?: string; quantity?: number }) => Promise<Cart>;
};

const CartContext = createContext<CartState | null>(null);

export function CartProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const [count, setCount] = useState(0);

  const refresh = useCallback(async () => {
    if (!getToken()) {
      setCount(0);
      return;
    }
    try {
      const res = await api.cartCount();
      setCount(res.count);
    } catch {
      /* keep the last known count */
    }
  }, []);

  const userId = user?.id;
  useEffect(() => {
    if (!userId) {
      setCount(0);
      return;
    }
    refresh();
    const onFocus = () => refresh();
    window.addEventListener("focus", onFocus);
    return () => window.removeEventListener("focus", onFocus);
  }, [userId, refresh]);

  const add = useCallback<CartState["add"]>(async (b) => {
    const cart = await api.addToCart(b);
    setCount(cart.count);
    return cart;
  }, []);

  const value = useMemo(() => ({ count, setCount, refresh, add }), [count, refresh, add]);
  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart(): CartState {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used inside <CartProvider>");
  return ctx;
}

/** Shared "add to cart" handler that redirects guests to login and reports errors through a callback. */
export function useAddToCart(onMessage: (msg: string, kind?: "info" | "error") => void) {
  const { user } = useAuth();
  const { add } = useCart();
  const router = useRouter();
  const loginHref = useLoginHref();
  return useCallback(async (b: { pinId: number; color?: string; size?: string; quantity?: number }) => {
    if (!user) {
      router.push(loginHref());
      return false;
    }
    try {
      await add(b);
      onMessage("Sebede goşuldy");
      return true;
    } catch (e) {
      onMessage(errorMessage(e), "error");
      return false;
    }
  }, [user, add, router, loginHref, onMessage]);
}
