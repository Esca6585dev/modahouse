"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  BagIcon, BanIcon, ChevronRightIcon, CommentIcon, FlagIcon, GridIcon, PackageIcon, ReelsIcon, ShieldIcon, StoreIcon, UserIcon,
} from "@/components/Icons";
import { api, errorMessage } from "@/lib/api";
import { num } from "@/lib/format";
import type { AdminStats } from "@/lib/types";
import { AdminHead, LoadError } from "./shared";

type Card = { key: keyof AdminStats; label: string; icon: React.ReactNode; tone: string; sub?: (s: AdminStats) => string; href?: string };

const CARDS: Card[] = [
  { key: "users", label: "Ulanyjylar", icon: <UserIcon size={20} />, tone: "blue", sub: (s) => `+${num(s.newUsers7d)} soňky 7 günde`, href: "/admin/users" },
  { key: "businesses", label: "Biznes hasaplary", icon: <StoreIcon size={20} />, tone: "dark", href: "/admin/users?filter=business" },
  { key: "pins", label: "Postlar", icon: <GridIcon size={20} />, tone: "red", sub: (s) => `+${num(s.newPins7d)} soňky 7 günde` },
  { key: "products", label: "Harytlar", icon: <PackageIcon size={20} />, tone: "green" },
  { key: "videos", label: "Wideolar", icon: <ReelsIcon size={20} />, tone: "purple" },
  { key: "comments", label: "Teswirler", icon: <CommentIcon size={20} />, tone: "blue" },
  { key: "orders", label: "Sargytlar", icon: <BagIcon size={20} />, tone: "green" },
  { key: "openReports", label: "Açyk şikaýatlar", icon: <FlagIcon size={20} />, tone: "red", sub: (s) => (s.openReports ? "Seredip çykyň" : "Hemmesi arassa"), href: "/admin/reports" },
  { key: "admins", label: "Adminler", icon: <ShieldIcon size={20} />, tone: "dark", href: "/admin/users?filter=admin" },
  { key: "suspended", label: "Petiklenenler", icon: <BanIcon size={20} />, tone: "gray", href: "/admin/users?filter=suspended" },
];

export default function AdminOverview() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(null);
    setStats(null);
    api.admin.stats().then(setStats, (e) => setError(errorMessage(e)));
  }, []);
  useEffect(() => {
    document.title = "Admin paneli · ModaHouse";
    load();
  }, [load]);

  return (
    <>
      <AdminHead title="Umumy" sub="ModaHouse-yň häzirki ýagdaýy" />
      {error ? (
        <LoadError message={error} onRetry={load} />
      ) : (
        <div className="admin-stats">
          {CARDS.map((c) => {
            if (!stats) return <div key={c.key} className="skeleton admin-stat-skel" />;
            const alert = c.key === "openReports" && stats.openReports > 0;
            const body = (
              <>
                <span className="stat-icon">{c.icon}</span>
                <span className="stat-label">{c.label}</span>
                <strong className="stat-value">{num(stats[c.key])}</strong>
                {c.sub && <span className="admin-stat-sub">{c.sub(stats)}</span>}
                {c.href && <span className="admin-stat-go" aria-hidden><ChevronRightIcon size={18} /></span>}
              </>
            );
            const cls = `stat-card admin-stat tone-${c.tone} ${alert ? "alert" : ""}`;
            return c.href ? (
              <Link key={c.key} href={c.href} className={`${cls} linked`}>{body}</Link>
            ) : (
              <div key={c.key} className={cls}>{body}</div>
            );
          })}
        </div>
      )}
    </>
  );
}
