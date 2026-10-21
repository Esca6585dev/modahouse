"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { ChartIcon, FlagIcon, ImagesIcon, SettingsIcon, ShieldIcon, UploadIcon, UserIcon } from "@/components/Icons";
import { api } from "@/lib/api";
import { useRequireAuth } from "@/lib/hooks";
import { AdminBadgeContext } from "./shared";

const TABS = [
  { href: "/admin", label: "Umumy", icon: <ChartIcon size={18} /> },
  { href: "/admin/settings", label: "Sazlamalar", icon: <SettingsIcon size={18} /> },
  { href: "/admin/users", label: "Ulanyjylar", icon: <UserIcon size={18} /> },
  { href: "/admin/reports", label: "Şikaýatlar", icon: <FlagIcon size={18} />, badge: true },
  { href: "/admin/upload", label: "Ýükle", icon: <UploadIcon size={18} /> },
  { href: "/admin/import", label: "Suratlar importy", icon: <ImagesIcon size={18} /> },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user } = useRequireAuth();
  const path = usePathname();
  const isAdmin = !!user?.isAdmin;
  const [openReports, setOpenReports] = useState(0);
  const nav = useRef<HTMLElement>(null);

  // On phones the tabs scroll sideways: keep the current one in view.
  useEffect(() => {
    const el = nav.current;
    const tab = el?.querySelector<HTMLElement>(".admin-tab.active");
    if (!el || !tab || el.scrollWidth <= el.clientWidth) return;
    const left = tab.offsetLeft - el.offsetLeft;
    if (left < el.scrollLeft || left + tab.offsetWidth > el.scrollLeft + el.clientWidth) {
      el.scrollTo({ left: Math.max(0, left - 16), behavior: "smooth" });
    }
  }, [path, isAdmin]);

  const refresh = useCallback(() => {
    api.admin.stats().then((s) => setOpenReports(s.openReports), () => {});
  }, []);
  useEffect(() => {
    if (isAdmin) refresh();
  }, [isAdmin, path, refresh]);

  if (!user) {
    return (
      <div className="page admin-page">
        <div className="skeleton" style={{ height: 52, borderRadius: 999, maxWidth: 520, marginBottom: 20 }} />
        <div className="skeleton" style={{ height: 360, borderRadius: 24 }} />
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div className="page narrow-sm">
        <div className="empty empty-card admin-denied">
          <span className="empty-icon"><ShieldIcon size={34} /></span>
          <h2>Bu bölüm diňe administratorlar üçin</h2>
          <p>Siziň hasabyňyzyň bu sahypa girmäge rugsady ýok. Rugsat gerek bolsa, ModaHouse administratoryna ýüz tutuň.</p>
          <Link href="/" className="btn btn-primary">Baş sahypa</Link>
        </div>
      </div>
    );
  }

  const isActive = (href: string) => (href === "/admin" ? path === "/admin" : path.startsWith(href));
  return (
    <AdminBadgeContext.Provider value={{ refresh }}>
      <div className="page admin-page">
        <aside className="admin-side">
          <div className="admin-brand">
            <span className="admin-brand-icon"><ShieldIcon size={20} /></span>
            <div>
              <strong>Admin paneli</strong>
              <span className="muted">@{user.username}</span>
            </div>
          </div>
          <nav ref={nav} className="admin-nav" aria-label="Admin bölümleri">
            {TABS.map((t) => (
              <Link key={t.href} href={t.href} className={`admin-tab ${isActive(t.href) ? "active" : ""}`} aria-current={isActive(t.href) ? "page" : undefined}>
                {t.icon}
                <span>{t.label}</span>
                {t.badge && openReports > 0 && <span className="admin-count" aria-label={`${openReports} açyk şikaýat`}>{openReports > 99 ? "99+" : openReports}</span>}
              </Link>
            ))}
          </nav>
        </aside>
        <section className="admin-main">{children}</section>
      </div>
    </AdminBadgeContext.Provider>
  );
}
