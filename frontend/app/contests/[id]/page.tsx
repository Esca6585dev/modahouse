"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { contestPrize, contestWhen, CONTEST_STATUS } from "@/components/ContestBits";
import { CheckIcon, CrownIcon, HeartIcon } from "@/components/Icons";
import Modal from "@/components/Modal";
import PinImage from "@/components/PinImage";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { categoryName } from "@/lib/format";
import { useCategories } from "@/lib/hooks";
import type { Contest, ContestEntry, Pin } from "@/lib/types";

/** Pick one of your own posts to enter (only the contest's category, when it has one). */
function EnterModal({ contest, onClose, onDone }: { contest: Contest; onClose: () => void; onDone: (c: Contest) => void }) {
  const { user } = useAuth();
  const toast = useToast();
  const [pins, setPins] = useState<Pin[] | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!user) return;
    api.userPins(user.username, 1).then(
      (pg) => setPins(pg.items.filter((p) => !contest.category || p.category === contest.category)),
      () => setPins([]),
    );
  }, [user, contest.category]);

  const enter = async (p: Pin) => {
    setBusy(true);
    try {
      onDone(await api.enterContest(contest.id, p.id));
      toast("Postuňyz ýaryşa goşuldy");
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title="Haýsy postuňyzy goşýarsyňyz?" onClose={onClose} wide>
      {!pins ? <div className="skeleton" style={{ height: 200 }} /> : pins.length === 0 ? (
        <p className="muted">Laýyk postuňyz ýok. <Link href="/create">Täze post goşuň</Link>.</p>
      ) : (
        <div className="contest-pick">
          {pins.map((p) => (
            <button key={p.id} className="contest-pick-item" disabled={busy} onClick={() => enter(p)}>
              <PinImage pin={p} />
              <span>{p.title}</span>
            </button>
          ))}
        </div>
      )}
    </Modal>
  );
}

export default function ContestPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { user } = useAuth();
  const toast = useToast();
  const cats = useCategories();
  const [contest, setContest] = useState<Contest | null>(null);
  const [entries, setEntries] = useState<ContestEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [entering, setEntering] = useState(false);
  const [busy, setBusy] = useState<number | null>(null);

  const load = useCallback(() => {
    api.contest(id).then((r) => {
      setContest(r.contest);
      setEntries(r.entries);
      document.title = `${r.contest.title} · Ýaryşlar · ModaHouse`;
    }, (e) => setError(errorMessage(e)));
  }, [id]);
  useEffect(load, [load]);

  const needLogin = () => router.push(`/login?next=${encodeURIComponent(`/contests/${id}`)}`);

  const vote = async (pinId: number) => {
    if (!user) return needLogin();
    setBusy(pinId);
    try {
      setContest(await api.vote(Number(id), pinId));
      toast("Sesiňiz kabul edildi");
      load();
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(null);
    }
  };

  const leave = async () => {
    try {
      setContest(await api.leaveContest(Number(id)));
      load();
    } catch (e) {
      toast(errorMessage(e), "error");
    }
  };

  if (error) return <div className="page narrow"><div className="empty"><h2>Ýüklenmedi</h2><p>{error}</p></div></div>;
  if (!contest) return <div className="page narrow"><div className="skeleton" style={{ height: 420, borderRadius: 24 }} /></div>;

  const open = contest.status !== "finished";
  const voted = contest.myVotePinId;

  return (
    <div className="page narrow">
      <Link href="/contests" className="muted small">← Ähli ýaryşlar</Link>
      <header className="contest-head">
        <span className={`contest-status ${contest.status}`}>{CONTEST_STATUS[contest.status]}</span>
        <h1 className="page-title">{contest.title}</h1>
        {contest.description && <p>{contest.description}</p>}
        {contestPrize(contest) && <p className="contest-prize"><CrownIcon size={18} /> Baýrak: {contestPrize(contest)}</p>}
        <p className="muted small">
          {contestWhen(contest)} · {contest.entriesCount} gatnaşyjy · {contest.votesCount} ses
          {contest.category && cats ? ` · diňe «${categoryName(contest.category, cats)}»` : ""}
        </p>
        <p className="contest-rule small">Her ulanyja 1 ses. Ses berlenden soň üýtgedilmeýär, öz postuňyza ses berip bolmaýar.</p>
        {open && (
          <div className="form-actions">
            {contest.myEntryPinId ? (
              <button className="btn btn-secondary" onClick={leave}>Ýaryşdan çyk</button>
            ) : (
              <button className="btn btn-primary" onClick={() => (user ? setEntering(true) : needLogin())}>Postuňy goş</button>
            )}
          </div>
        )}
      </header>

      {contest.winner && (
        <section className="contest-winner">
          <CrownIcon size={22} />
          <div>
            <strong>Ýeňiji: @{contest.winner.pin.author.username}</strong>
            <span className="muted small">{contest.winner.votes} ses · {contest.winner.pin.title}</span>
          </div>
          <Link href={`/pin/${contest.winner.pin.id}`} className="btn btn-secondary btn-sm">Gör</Link>
        </section>
      )}

      {entries.length === 0 ? (
        <div className="empty"><p>Entek gatnaşyjy ýok. Ilkinji bolup postuňyzy goşuň!</p></div>
      ) : (
        <ol className="contest-entries">
          {entries.map((e) => {
            const mine = e.pin.author.id === user?.id;
            const myChoice = voted === e.pin.id;
            return (
              <li key={e.pin.id} className={`contest-entry ${e.rank === 1 && e.votes > 0 ? "lead" : ""}`}>
                <span className="contest-rank">{e.rank}</span>
                <Link href={`/pin/${e.pin.id}`} className="contest-entry-img"><PinImage pin={e.pin} /></Link>
                <div className="contest-entry-body">
                  <Link href={`/pin/${e.pin.id}`}><strong>{e.pin.title}</strong></Link>
                  <span className="muted small">@{e.pin.author.username}</span>
                  <span className="contest-votes"><HeartIcon size={14} /> {e.votes} ses</span>
                  {contest.status === "active" && !mine && (
                    myChoice ? (
                      <span className="contest-voted"><CheckIcon size={14} /> Siziň sesiňiz</span>
                    ) : (
                      <button className="btn btn-primary btn-sm" disabled={!!voted || busy !== null} onClick={() => vote(e.pin.id)}>
                        {voted ? "Ses berdiňiz" : "Ses ber"}
                      </button>
                    )
                  )}
                </div>
              </li>
            );
          })}
        </ol>
      )}
      {entering && <EnterModal contest={contest} onClose={() => setEntering(false)} onDone={(c) => { setContest(c); setEntering(false); load(); }} />}
    </div>
  );
}
