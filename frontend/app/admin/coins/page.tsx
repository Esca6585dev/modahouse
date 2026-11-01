"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import Avatar from "@/components/Avatar";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { timeAgo } from "@/lib/format";
import type { CoinRequest } from "@/lib/types";
import { AdminHead, LoadError } from "../shared";

const FILTERS = [
  { value: "pending", label: "Garaşylýan" },
  { value: "approved", label: "Goşulan" },
  { value: "rejected", label: "Ret edilen" },
  { value: "all", label: "Hemmesi" },
];

/** Price of teňňe and how users pay for them. */
function CoinSettings() {
  const toast = useToast();
  const [rate, setRate] = useState("");
  const [payment, setPayment] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    api.admin.settings().then((c) => { setRate(c.coinRate); setPayment(c.coinPayment); }, () => {});
  }, []);
  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      const c = await api.admin.updateSettings({ coinRate: rate, coinPayment: payment });
      setRate(c.coinRate);
      setPayment(c.coinPayment);
      toast("Saklandy");
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      setBusy(false);
    }
  };
  return (
    <form className="card admin-form form" onSubmit={save}>
      <h2>Teňňe sazlamalary</h2>
      <label>
        1 teňňäniň bahasy (manat)
        <input value={rate} onChange={(e) => setRate(e.target.value)} inputMode="decimal" placeholder="1" />
      </label>
      <label>
        Töleg maglumaty
        <textarea rows={3} value={payment} onChange={(e) => setPayment(e.target.value)} maxLength={500}
          placeholder="Meselem: Pul geçirmek üçin +993 6X XXXXXX (Altyn Asyr kartyna). Bellikde ulanyjy adyňyzy ýazyň." />
        <small className="hint">Ulanyjylar teňňe satyn alanda şu ýazgyny görýär.</small>
      </label>
      <div className="form-actions"><button className="btn btn-primary" disabled={busy}>Sakla</button></div>
    </form>
  );
}

export default function AdminCoins() {
  const toast = useToast();
  const [status, setStatus] = useState("pending");
  const [items, setItems] = useState<CoinRequest[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<number | null>(null);

  const load = useCallback(() => {
    setError(null);
    setItems(null);
    api.admin.coinRequests(status, 1).then((pg) => setItems(pg.items), (e) => setError(errorMessage(e)));
  }, [status]);
  useEffect(() => {
    document.title = "Teňňe · Admin · ModaHouse";
    load();
  }, [load]);

  const decide = async (r: CoinRequest, approve: boolean) => {
    setBusy(r.id);
    try {
      const d = await api.admin.decideCoinRequest(r.id, approve);
      setItems((l) => (status === "pending" ? l?.filter((x) => x.id !== r.id) : l?.map((x) => (x.id === r.id ? d : x))) ?? l);
      toast(approve ? `@${r.user.username}: +${r.coins} teňňe` : "Ret edildi");
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      <AdminHead title="Teňňe" sub="Satyn alyş haýyşlary: tölegi barlap tassyklaň" />
      <CoinSettings />
      <div className="chips">
        {FILTERS.map((f) => (
          <button key={f.value} className={`chip ${status === f.value ? "active" : ""}`} onClick={() => setStatus(f.value)}>{f.label}</button>
        ))}
      </div>
      {error ? <LoadError message={error} onRetry={load} /> : !items ? (
        <div className="skeleton" style={{ height: 200, borderRadius: 20 }} />
      ) : items.length === 0 ? (
        <p className="muted">Haýyş ýok.</p>
      ) : (
        <ul className="user-list">
          {items.map((r) => (
            <li key={r.id} className="user-row">
              <Link href={`/u/${r.user.username}`}><Avatar user={r.user} size={40} /></Link>
              <span className="blocked-name">
                <strong>@{r.user.username} · {r.coins} teňňe · {r.price} manat</strong>
                <span className="muted small">{timeAgo(r.createdAt)}{r.note ? ` · «${r.note}»` : ""}</span>
              </span>
              {r.status === "pending" ? (
                <span className="head-actions">
                  <button className="btn btn-secondary btn-sm" disabled={busy === r.id} onClick={() => decide(r, false)}>Ret et</button>
                  <button className="btn btn-primary btn-sm" disabled={busy === r.id} onClick={() => decide(r, true)}>Tassykla</button>
                </span>
              ) : (
                <span className="muted small">{r.status === "approved" ? "Goşuldy" : "Ret edildi"}</span>
              )}
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
