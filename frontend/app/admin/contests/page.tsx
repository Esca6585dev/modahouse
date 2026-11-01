"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { contestPrize, contestWhen, CONTEST_STATUS } from "@/components/ContestBits";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useCategories } from "@/lib/hooks";
import type { Contest } from "@/lib/types";
import { AdminHead, LoadError } from "../shared";

// <input type="datetime-local"> works in local time without a zone.
const local = (d: Date) => new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);

function NewContest({ onCreated }: { onCreated: () => void }) {
  const toast = useToast();
  const cats = useCategories();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("");
  const [prize, setPrize] = useState("");
  const [prizeCoins, setPrizeCoins] = useState(100);
  const [startsAt, setStartsAt] = useState(local(new Date()));
  const [endsAt, setEndsAt] = useState(local(new Date(Date.now() + 7 * 864e5)));
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      await api.admin.createContest({
        title, description, category, prize, prizeCoins,
        startsAt: new Date(startsAt).toISOString(), endsAt: new Date(endsAt).toISOString(),
      });
      toast("Ýaryş döredildi");
      setTitle("");
      setDescription("");
      setPrize("");
      onCreated();
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="card admin-form form" onSubmit={submit}>
      <h2>Täze ýaryş</h2>
      <label>Ady<input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={100} placeholder="Meselem: Hepdäniň iň owadan toý köýnegi" required /></label>
      <label>Beýany<textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} maxLength={1000} placeholder="Düzgünler, kimler gatnaşyp biler…" /></label>
      <div className="form-row">
        <label>
          Bölüm
          <select value={category} onChange={(e) => setCategory(e.target.value)}>
            <option value="">Islendik post</option>
            {(cats ?? []).map((c) => <option key={c.slug} value={c.slug}>{c.name}</option>)}
          </select>
        </label>
        <label>Baýrak teňňesi<input type="number" min={0} max={100000} value={prizeCoins} onChange={(e) => setPrizeCoins(Number(e.target.value))} /></label>
      </div>
      <label>Baýrak (ýazgy)<input value={prize} onChange={(e) => setPrize(e.target.value)} maxLength={200} placeholder="Meselem: hyzmatdaş tikinçide mugt tikin" /></label>
      <div className="form-row">
        <label>Başlaýar<input type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} required /></label>
        <label>Gutarýar<input type="datetime-local" value={endsAt} onChange={(e) => setEndsAt(e.target.value)} required /></label>
      </div>
      <p className="muted small">Ýaryş wagty dolanda özi tamamlanýar: iň köp ses alan post ýeňýär we baýrak teňňesi awtoryna geçýär. Her ulanyja 1 ses.</p>
      <div className="form-actions"><button className="btn btn-primary" disabled={busy || !title.trim()}>Döret</button></div>
    </form>
  );
}

export default function AdminContests() {
  const toast = useToast();
  const [list, setList] = useState<Contest[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const load = useCallback(() => {
    setError(null);
    api.contests().then(setList, (e) => setError(errorMessage(e)));
  }, []);
  useEffect(() => {
    document.title = "Ýaryşlar · Admin · ModaHouse";
    load();
  }, [load]);

  const remove = async (c: Contest) => {
    if (!window.confirm(`«${c.title}» ýaryşy pozulsynmy? Sesler we gatnaşyjylar hem pozular.`)) return;
    try {
      await api.admin.deleteContest(c.id);
      setList((l) => l?.filter((x) => x.id !== c.id) ?? l);
    } catch (e) {
      toast(errorMessage(e), "error");
    }
  };

  return (
    <>
      <AdminHead title="Ýaryşlar" sub="Iň köp ses alan post ýeňýär" />
      <NewContest onCreated={load} />
      {error ? <LoadError message={error} onRetry={load} /> : !list ? (
        <div className="skeleton" style={{ height: 160, borderRadius: 20 }} />
      ) : (
        <div className="contest-list">
          {list.map((c) => (
            <div key={c.id} className={`contest-card ${c.status}`}>
              <span className={`contest-status ${c.status}`}>{CONTEST_STATUS[c.status]}</span>
              <h2><Link href={`/contests/${c.id}`}>{c.title}</Link></h2>
              <p className="muted small">{contestWhen(c)} · {c.entriesCount} gatnaşyjy · {c.votesCount} ses{contestPrize(c) ? ` · ${contestPrize(c)}` : ""}</p>
              {c.winner && <p className="small">Ýeňiji: <strong>@{c.winner.pin.author.username}</strong> ({c.winner.votes} ses)</p>}
              <div className="form-actions"><button className="btn btn-secondary btn-sm danger" onClick={() => remove(c)}>Poz</button></div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}
