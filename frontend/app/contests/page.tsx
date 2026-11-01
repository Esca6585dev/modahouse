"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { contestPrize, contestWhen, CONTEST_STATUS } from "@/components/ContestBits";
import { CrownIcon } from "@/components/Icons";
import { api, errorMessage } from "@/lib/api";
import type { Contest } from "@/lib/types";

export default function ContestsPage() {
  const [list, setList] = useState<Contest[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    document.title = "Ýaryşlar · ModaHouse";
    api.contests().then(setList, (e) => setError(errorMessage(e)));
  }, []);

  return (
    <div className="page narrow">
      <div className="page-head">
        <div>
          <h1 className="page-title">Ýaryşlar</h1>
          <p className="muted">Postuňyzy goşuň, iň köp ses alan ýeňýär. Her ulanyja bir ýaryşda <strong>1 ses</strong>.</p>
        </div>
      </div>
      {error ? (
        <div className="empty"><h2>Ýüklenmedi</h2><p>{error}</p></div>
      ) : !list ? (
        <div className="skeleton" style={{ height: 240, borderRadius: 24 }} />
      ) : list.length === 0 ? (
        <div className="empty"><h2>Entek ýaryş ýok</h2><p>Täze ýaryş yglan edilende şu ýerde görersiňiz.</p></div>
      ) : (
        <div className="contest-list">
          {list.map((c) => (
            <Link key={c.id} href={`/contests/${c.id}`} className={`contest-card ${c.status}`}>
              <span className={`contest-status ${c.status}`}>{CONTEST_STATUS[c.status]}</span>
              <h2>{c.title}</h2>
              {contestPrize(c) && <p className="contest-prize"><CrownIcon size={16} /> {contestPrize(c)}</p>}
              <p className="muted small">{contestWhen(c)} · {c.entriesCount} gatnaşyjy · {c.votesCount} ses</p>
              {c.winner && <p className="small">Ýeňiji: <strong>@{c.winner.pin.author.username}</strong> ({c.winner.votes} ses)</p>}
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
