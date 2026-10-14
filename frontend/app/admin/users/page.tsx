"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import { ChevronLeftIcon, ChevronRightIcon, SearchIcon, UserIcon, VerifiedIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { dateTime, num } from "@/lib/format";
import type { AdminUser, AdminUserFilter } from "@/lib/types";
import { AdminHead, LoadError } from "../shared";

const LIMIT = 20;
const FILTERS: { value: AdminUserFilter; label: string }[] = [
  { value: "", label: "Hemmesi" },
  { value: "admin", label: "Adminler" },
  { value: "business", label: "Biznes" },
  { value: "suspended", label: "Petiklenen" },
];

type Flag = "isAdmin" | "verified" | "suspended";
const FLAG_LABEL: Record<Flag, string> = { isAdmin: "Admin", verified: "Tassyklanan", suspended: "Petikle" };

function doneText(username: string, flag: Flag, value: boolean): string {
  const who = `@${username}`;
  if (flag === "isAdmin") return value ? `${who} indi administrator` : `${who} administratorlykdan aýryldy`;
  if (flag === "verified") return value ? `${who} tassyklandy` : `${who} tassyklamasy aýryldy`;
  return value ? `${who} petiklendi` : `${who} petikden aýryldy`;
}

function Toggle({ user, flag, disabled, title, onChange }: {
  user: AdminUser; flag: Flag; disabled?: boolean; title?: string; onChange: (flag: Flag, value: boolean) => void;
}) {
  return (
    <label className={`switch au-switch ${flag === "suspended" ? "danger" : ""}`} title={title}>
      <input
        type="checkbox"
        checked={user[flag]}
        disabled={disabled}
        onChange={(e) => onChange(flag, e.target.checked)}
        aria-label={`@${user.username}: ${FLAG_LABEL[flag]}`}
      />
      <span className="switch-track"><span /></span>
      <span className="au-switch-label">{FLAG_LABEL[flag]}</span>
    </label>
  );
}

function UsersPanel() {
  const { user: me } = useAuth();
  const toast = useToast();
  const params = useSearchParams();
  const router = useRouter();
  const filterParam = params.get("filter") ?? "";
  const filter = (FILTERS.some((f) => f.value === filterParam) ? filterParam : "") as AdminUserFilter;
  const q = params.get("q") ?? "";
  const page = Math.max(1, Number(params.get("page")) || 1);

  const [text, setText] = useState(q);
  const [items, setItems] = useState<AdminUser[] | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<Set<string>>(new Set());
  const [nonce, setNonce] = useState(0);
  const itemsRef = useRef<AdminUser[] | null>(null);
  itemsRef.current = items;

  const go = useCallback((patch: Record<string, string>) => {
    const next = new URLSearchParams(params.toString());
    for (const [k, v] of Object.entries(patch)) {
      if (v) next.set(k, v);
      else next.delete(k);
    }
    if (!("page" in patch)) next.delete("page");
    const s = next.toString();
    router.replace(`/admin/users${s ? `?${s}` : ""}`, { scroll: false });
  }, [params, router]);

  useEffect(() => { document.title = "Ulanyjylar · Admin paneli"; }, []);

  // Debounced search box -> ?q=
  useEffect(() => { setText(q); }, [q]);
  useEffect(() => {
    if (text.trim() === q) return;
    const t = window.setTimeout(() => go({ q: text.trim() }), 350);
    return () => window.clearTimeout(t);
  }, [text, q, go]);

  useEffect(() => {
    let alive = true;
    setItems(null);
    setError(null);
    api.admin.users({ q, filter, page, limit: LIMIT }).then(
      (pg) => { if (alive) { setItems(pg.items); setHasMore(pg.hasMore); } },
      (e) => alive && setError(errorMessage(e)),
    );
    return () => { alive = false; };
  }, [q, filter, page, nonce]);

  const patchItem = (id: number, patch: Partial<AdminUser>) =>
    setItems((l) => l && l.map((u) => (u.id === id ? { ...u, ...patch } : u)));

  const change = async (u: AdminUser, flag: Flag, value: boolean) => {
    if (flag === "suspended" && value && !window.confirm(`@${u.username} petiklensinmi? Ol hasabyna girip bilmez we ähli enjamlardan çykarylar.`)) return;
    if (flag === "isAdmin" && value && !window.confirm(`@${u.username} administrator bolsunmy? Ol admin paneline doly girip biler.`)) return;
    const key = `${u.id}:${flag}`;
    const prev = itemsRef.current?.find((x) => x.id === u.id)?.[flag] ?? !value;
    patchItem(u.id, { [flag]: value });
    setBusy((s) => new Set(s).add(key));
    try {
      const updated = await api.admin.updateUser(u.id, { [flag]: value });
      patchItem(u.id, updated);
      toast(doneText(u.username, flag, value));
    } catch (e) {
      patchItem(u.id, { [flag]: prev });
      toast(errorMessage(e), "error");
    } finally {
      setBusy((s) => {
        const n = new Set(s);
        n.delete(key);
        return n;
      });
    }
  };

  const toggles = (u: AdminUser) => {
    const self = u.id === me?.id;
    const selfTitle = self ? "Özüňizi üýtgedip bilmersiňiz" : undefined;
    return (
      <>
        <Toggle user={u} flag="isAdmin" disabled={self || busy.has(`${u.id}:isAdmin`)} title={selfTitle} onChange={(f, v) => change(u, f, v)} />
        <Toggle user={u} flag="verified" disabled={busy.has(`${u.id}:verified`)} onChange={(f, v) => change(u, f, v)} />
        <Toggle user={u} flag="suspended" disabled={self || busy.has(`${u.id}:suspended`)} title={selfTitle} onChange={(f, v) => change(u, f, v)} />
      </>
    );
  };

  return (
    <>
      <AdminHead title="Ulanyjylar" sub="Adminleri belläň, hasaplary tassyklaň ýa-da petikläň" />

      <div className="admin-toolbar">
        <label className="search admin-search">
          <SearchIcon />
          <input
            type="search"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Ady, ulanyjy ady ýa-da e-poçta"
            aria-label="Ulanyjy gözle"
          />
        </label>
        <div className="chips admin-chips" role="tablist" aria-label="Süzgüç">
          {FILTERS.map((f) => (
            <button key={f.value || "all"} role="tab" aria-selected={filter === f.value} className={`chip ${filter === f.value ? "active" : ""}`} onClick={() => go({ filter: f.value })}>
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {error ? (
        <LoadError message={error} onRetry={() => setNonce((n) => n + 1)} />
      ) : items && items.length === 0 ? (
        <div className="empty empty-card">
          <span className="empty-icon"><UserIcon size={32} /></span>
          <h2>Ulanyjy tapylmady</h2>
          <p>{q ? `“${q}” boýunça hiç kim ýok.` : "Bu süzgüçde ulanyjy ýok."}</p>
          {(q || filter) && <button className="btn btn-secondary" onClick={() => { setText(""); go({ q: "", filter: "" }); }}>Süzgüçleri arassala</button>}
        </div>
      ) : (
        <div className="au-table" aria-busy={!items}>
          <div className="au-row au-headrow" aria-hidden>
            <span>Ulanyjy</span>
            <span>Postlar</span>
            <span>Hasaba alnan</span>
            <span>Admin</span>
            <span>Tassyklanan</span>
            <span>Petikle</span>
          </div>
          {!items
            ? Array.from({ length: 6 }, (_, i) => <div key={i} className="au-row au-skel"><div className="skeleton" /></div>)
            : items.map((u) => (
              <div key={u.id} className={`au-row ${u.suspended ? "is-suspended" : ""}`}>
                <div className="au-user">
                  <Link href={`/u/${u.username}`} className="au-avatar" aria-label={`@${u.username} profili`}><Avatar user={u} size={44} /></Link>
                  <div className="au-name">
                    <Link href={`/u/${u.username}`}>
                      <strong>{u.name || u.username}</strong>
                      {u.verified && <span className="au-verified" aria-label="Tassyklanan"><VerifiedIcon size={15} /></span>}
                    </Link>
                    <span className="muted">@{u.username}{u.email ? ` · ${u.email}` : ""}</span>
                    <span className="au-tags">
                      {u.id === me?.id && <span className="au-tag">Siz</span>}
                      {u.isAdmin && <span className="au-tag admin">Admin</span>}
                      {u.isBusiness && <span className="au-tag">Biznes</span>}
                      {u.suspended && <span className="au-tag danger">Petiklenen</span>}
                    </span>
                  </div>
                </div>
                <span className="au-num" data-label="Postlar">{num(u.pinsCount)}</span>
                <span className="au-date" data-label="Hasaba alnan">{dateTime(u.createdAt).split(",")[0]}</span>
                <div className="au-toggles">{toggles(u)}</div>
              </div>
            ))}
        </div>
      )}

      {items && (page > 1 || hasMore) && (
        <nav className="admin-pager" aria-label="Sahypalar">
          <button className="btn btn-secondary btn-sm" disabled={page <= 1} onClick={() => go({ page: page > 2 ? String(page - 1) : "" })}>
            <ChevronLeftIcon size={18} /> Öňki
          </button>
          <span className="muted">{page}-nji sahypa</span>
          <button className="btn btn-secondary btn-sm" disabled={!hasMore} onClick={() => go({ page: String(page + 1) })}>
            Indiki <ChevronRightIcon size={18} />
          </button>
        </nav>
      )}
    </>
  );
}

export default function AdminUsersPage() {
  return (
    <Suspense fallback={<div className="skeleton" style={{ height: 420, borderRadius: 24 }} />}>
      <UsersPanel />
    </Suspense>
  );
}
