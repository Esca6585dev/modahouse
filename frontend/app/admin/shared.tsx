"use client";

import { createContext, useContext } from "react";

/** Lets admin pages refresh the open-report badge in the admin tab bar after they change reports. */
export const AdminBadgeContext = createContext<{ refresh: () => void }>({ refresh: () => {} });
export const useAdminBadge = () => useContext(AdminBadgeContext);

export function AdminHead({ title, sub, children }: { title: string; sub?: string; children?: React.ReactNode }) {
  return (
    <header className="admin-head">
      <div>
        <h1>{title}</h1>
        {sub && <p className="muted">{sub}</p>}
      </div>
      {children}
    </header>
  );
}

export function LoadError({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="empty empty-card admin-error">
      <h2>Ýüklenmedi</h2>
      <p>{message}</p>
      <button className="btn btn-secondary" onClick={onRetry}>Gaýtadan synanyş</button>
    </div>
  );
}
