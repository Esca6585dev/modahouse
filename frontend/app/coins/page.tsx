"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { timeAgo } from "@/lib/format";
import { useRequireAuth } from "@/lib/hooks";
import type { Wallet } from "@/lib/types";

const KIND: Record<string, string> = { topup: "Satyn alyndy", boost: "Öňe çykarmak", prize: "Ýaryş baýragy", admin: "Administrator" };
const STATUS: Record<string, string> = { pending: "Garaşylýar", approved: "Goşuldy", rejected: "Ret edildi" };

export default function CoinsPage() {
  const { user } = useRequireAuth();
  const { setUser } = useAuth();
  const toast = useToast();
  const [w, setW] = useState<Wallet | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [chosen, setChosen] = useState<number | null>(null);
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(() => {
    setError(null);
    api.wallet().then(setW, (e) => setError(errorMessage(e)));
  }, []);
  useEffect(() => {
    document.title = "Teňňelerim · ModaHouse";
    if (user) load();
  }, [user, load]);
  // Keep the header balance in step with the wallet.
  useEffect(() => {
    if (w && user && user.coins !== w.balance) setUser({ ...user, coins: w.balance });
  }, [w]); // eslint-disable-line react-hooks/exhaustive-deps

  const send = async () => {
    if (!chosen) return;
    setBusy(true);
    try {
      await api.requestCoins(chosen, note.trim());
      toast("Haýyş iberildi: töleg barlanandan soň teňňeler goşular");
      setChosen(null);
      setNote("");
      load();
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };

  if (!user || (!w && !error)) return <div className="page narrow-sm"><div className="skeleton" style={{ height: 420, borderRadius: 24 }} /></div>;
  if (error || !w) {
    return (
      <div className="page narrow-sm">
        <div className="empty"><h2>Ýüklenmedi</h2><p>{error}</p><button className="btn btn-primary" onClick={load}>Gaýtadan synanyş</button></div>
      </div>
    );
  }

  return (
    <div className="page narrow-sm">
      <h1 className="page-title">Teňňelerim</h1>
      <section className="card">
        <div className="coin-balance">{w.balance}<span>teňňe</span></div>
        <p className="muted small">
          Teňňe bilen postlaryňyzy <strong>öňe çykaryp</strong> bilersiňiz: olar lentanyň başynda «Öňe çykarylan» bellik bilen görkezilýär.
          Ýaryşlarda ýeňseňiz hem teňňe alýarsyňyz.
        </p>
        <div className="form-actions"><Link href={`/u/${user.username}`} className="btn btn-secondary btn-sm">Postlaryma git</Link><Link href="/contests" className="btn btn-secondary btn-sm">Ýaryşlar</Link></div>
      </section>

      <section className="card">
        <h2>Teňňe satyn al</h2>
        <div className="coin-packages">
          {w.packages.map((p) => (
            <button key={p.coins} className={`boost-option ${chosen === p.coins ? "chosen" : ""}`} aria-pressed={chosen === p.coins} onClick={() => setChosen(p.coins)}>
              <strong>{p.coins} teňňe</strong>
              <span>{p.price} manat</span>
            </button>
          ))}
        </div>
        {chosen && (
          <>
            <p><strong>Nädip tölemeli</strong></p>
            <p className="pay-info">{w.paymentInfo || "Töleg barada administrator bilen habarlaşyň."}</p>
            <label className="form">
              Bellik (islege görä)
              <input value={note} onChange={(e) => setNote(e.target.value)} maxLength={300} placeholder="Meselem: tölegi kim, haçan geçirdi" />
            </label>
            <div className="form-actions">
              <button className="btn btn-secondary" onClick={() => setChosen(null)}>Goý bolsun</button>
              <button className="btn btn-primary" disabled={busy} onClick={send}>{busy ? "Iberilýär…" : `Töledim: ${chosen} teňňe`}</button>
            </div>
          </>
        )}
        {w.requests.length > 0 && (
          <ul className="coin-history">
            {w.requests.map((r) => (
              <li key={r.id}><span>{r.coins} teňňe · {r.price} manat</span><span className="muted">{STATUS[r.status]} · {timeAgo(r.createdAt)}</span></li>
            ))}
          </ul>
        )}
      </section>

      <section className="card">
        <h2>Taryh</h2>
        {w.history.length === 0 ? <p className="muted small">Entek hereket ýok.</p> : (
          <ul className="coin-history">
            {w.history.map((t) => (
              <li key={t.id}>
                <span>{KIND[t.kind] ?? t.kind}{t.note ? ` · ${t.note}` : ""}</span>
                <span><b className={t.amount > 0 ? "coin-plus" : "coin-minus"}>{t.amount > 0 ? `+${t.amount}` : t.amount}</b> <span className="muted small">{timeAgo(t.createdAt)}</span></span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
