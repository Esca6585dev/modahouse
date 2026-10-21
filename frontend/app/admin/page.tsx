"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  BagIcon, BanIcon, CheckIcon, ChevronRightIcon, CommentIcon, FlagIcon, GridIcon, PackageIcon, ReelsIcon, ShieldIcon, StoreIcon, TrashIcon,
  UserIcon,
} from "@/components/Icons";
import { api, errorMessage } from "@/lib/api";
import { num } from "@/lib/format";
import Modal from "@/components/Modal";
import { useToast } from "@/components/Toast";
import type { AdminStats, DemoCounts } from "@/lib/types";
import { AdminHead, LoadError } from "./shared";

const CONFIRM_WORD = "AÝYR";

/** Seed accounts and their posts: count them and remove them all before going to production. */
function DemoCard({ onRemoved }: { onRemoved: () => void }) {
  const toast = useToast();
  const [counts, setCounts] = useState<DemoCounts | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [asking, setAsking] = useState(false);
  const [word, setWord] = useState("");
  const [busy, setBusy] = useState(false);
  const [removed, setRemoved] = useState<DemoCounts | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(null);
    api.admin.demo().then(setCounts, (e) => setError(errorMessage(e)));
  }, []);
  useEffect(load, [load]);

  const empty = counts !== null && counts.users === 0 && counts.pins === 0;
  const ok = word.trim().toLocaleUpperCase("tk") === CONFIRM_WORD;

  const remove = async () => {
    if (!ok) return;
    setBusy(true);
    setDeleteError(null);
    try {
      const r = await api.admin.deleteDemo();
      setRemoved(r);
      setAsking(false);
      setWord("");
      setCounts({ users: 0, pins: 0 });
      toast(`${num(r.users)} hasap we ${num(r.pins)} post aýryldy`);
      onRemoved();
    } catch (e) {
      setDeleteError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="card demo-card">
      <div className="demo-head">
        <span className="demo-icon"><TrashIcon size={20} /></span>
        <div>
          <h2>Demo maglumatlary</h2>
          <p className="muted">
            Synag üçin goşulan hasaplar we olaryň postlary. Hakyky ulanyjylara açmazdan (production) öň olary aýryň:
            soňra serwer olary gaýtadan goşmaz.
          </p>
        </div>
      </div>
      {error ? (
        <div className="inline-error"><span>{error}</span><button className="btn btn-secondary btn-sm" onClick={load}>Gaýtadan synanyş</button></div>
      ) : !counts ? (
        <div className="skeleton" style={{ height: 64, borderRadius: 16 }} />
      ) : (
        <>
          <div className="demo-counts">
            <div><strong>{num(counts.users)}</strong><span>demo hasap</span></div>
            <div><strong>{num(counts.pins)}</strong><span>demo post</span></div>
          </div>
          {removed && (
            <p className="demo-done"><CheckIcon size={16} /> {num(removed.users)} hasap we {num(removed.pins)} post aýryldy.</p>
          )}
          {empty ? (
            !removed && <p className="muted small demo-clean"><CheckIcon size={16} /> Demo maglumat ýok: platforma arassa.</p>
          ) : (
            <div className="form-actions">
              <button className="btn btn-primary danger-bg" onClick={() => setAsking(true)}><TrashIcon size={18} /> Demo maglumatlary aýyr</button>
            </div>
          )}
        </>
      )}
      {asking && counts && (
        <Modal title="Demo maglumatlary aýyrmak" onClose={() => !busy && setAsking(false)}>
          <div className="confirm-body">
            <p>
              <strong>{num(counts.users)} hasap</strong> we <strong>{num(counts.pins)} post</strong> (suratlary, teswirleri, halanlary bilen)
              doly pozular. Muny yzyna gaýtaryp bolmaýar.
            </p>
            <label className="demo-confirm">
              <span>Tassyklamak üçin <strong>{CONFIRM_WORD}</strong> diýip ýazyň</span>
              <input value={word} onChange={(e) => setWord(e.target.value)} autoComplete="off" placeholder={CONFIRM_WORD} onKeyDown={(e) => e.key === "Enter" && remove()} />
            </label>
            {deleteError && <p className="form-error" role="alert">{deleteError}</p>}
            <div className="form-actions">
              <button className="btn btn-secondary" onClick={() => setAsking(false)} disabled={busy}>Goý bolsun</button>
              <button className="btn btn-primary danger-bg" disabled={!ok || busy} onClick={remove}>
                {busy ? <span className="spinner light" /> : <TrashIcon size={18} />} Hemmesini aýyr
              </button>
            </div>
          </div>
        </Modal>
      )}
    </section>
  );
}

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
      <DemoCard onRemoved={load} />
    </>
  );
}
