"use client";

import { createContext, useCallback, useContext, useState } from "react";

type ToastFn = (message: string, kind?: "info" | "error") => void;
const ToastContext = createContext<ToastFn>(() => {});

type Item = { id: number; message: string; kind: "info" | "error" };

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<Item[]>([]);
  const toast = useCallback<ToastFn>((message, kind = "info") => {
    const id = Date.now() + Math.random();
    setItems((l) => [...l.slice(-2), { id, message, kind }]);
  }, []);
  return (
    <ToastContext.Provider value={toast}>
      {children}
      <div className="toasts" aria-live="polite">
        {items.map((t) => (
          <div
            key={t.id}
            className={`toast ${t.kind === "error" ? "toast-error" : ""}`}
            role={t.kind === "error" ? "alert" : "status"}
            onAnimationEnd={() => setItems((l) => l.filter((x) => x.id !== t.id))}
          >
            {t.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export const useToast = () => useContext(ToastContext);
