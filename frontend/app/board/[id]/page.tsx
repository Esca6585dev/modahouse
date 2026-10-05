"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Avatar from "@/components/Avatar";
import BoardFormModal from "@/components/BoardFormModal";
import { EditIcon, LockIcon, TrashIcon } from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { usePaged } from "@/lib/hooks";
import type { Board, Pin } from "@/lib/types";

export default function BoardPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const toast = useToast();
  const { user, ready } = useAuth();
  const viewer = user?.id ?? 0;
  const [board, setBoard] = useState<Board | null>(null);
  const [state, setState] = useState<"loading" | "ok" | "notfound" | "error">("loading");
  const [error, setError] = useState("");
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    if (!ready) return;
    let alive = true;
    api.board(id).then(
      (b) => {
        if (!alive) return;
        setBoard(b);
        setState("ok");
        document.title = `${b.name} · ModaHouse`;
      },
      (e) => {
        if (!alive) return;
        if (e instanceof ApiError && e.status === 404) setState("notfound");
        else {
          setError(errorMessage(e));
          setState("error");
        }
      },
    );
    return () => { alive = false; };
  }, [id, ready, viewer, nonce]);

  const pins = usePaged(state === "ok" ? `board:${id}:${viewer}` : null, (page) => api.boardPins(Number(id), page));

  if (state === "notfound") {
    return (
      <div className="page">
        <div className="empty">
          <h2>Tagta tapylmady</h2>
          <p>Bu tagta pozulan ýa-da gizlin bolmagy mümkin.</p>
          <Link href="/" className="btn btn-primary">Baş sahypa gaýt</Link>
        </div>
      </div>
    );
  }
  if (state === "error") {
    return (
      <div className="page">
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{error}</p>
          <button className="btn btn-primary" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>
        </div>
      </div>
    );
  }
  if (!board || String(board.id) !== id) {
    return (
      <div className="page">
        <section className="board-head" aria-busy="true">
          <div className="skeleton skeleton-line" style={{ width: 260, height: 36 }} />
          <div className="skeleton skeleton-line" style={{ width: 180 }} />
        </section>
      </div>
    );
  }

  const isOwner = viewer !== 0 && viewer === board.owner.id;

  const remove = async () => {
    if (!window.confirm(`“${board.name}” tagtasyny pozmalymy? Pinleriň özi pozulmaýar.`)) return;
    setDeleting(true);
    try {
      await api.deleteBoard(board.id);
      toast("Tagta pozuldy");
      router.replace(`/u/${board.owner.username}?tab=saved`);
    } catch (e) {
      toast(errorMessage(e), "error");
      setDeleting(false);
    }
  };

  const removePin = async (pin: Pin) => {
    try {
      await api.unsavePin(board.id, pin.id);
      pins.setItems((l) => l.filter((p) => p.id !== pin.id));
      setBoard((b) => (b ? { ...b, pinsCount: Math.max(0, b.pinsCount - 1) } : b));
      toast("Pin tagtadan aýryldy");
    } catch (e) {
      toast(errorMessage(e), "error");
    }
  };

  return (
    <div className="page">
      <section className="board-head">
        <h1>
          {board.name}
          {board.isPrivate && <span className="badge-private"><LockIcon size={13} /> Gizlin</span>}
        </h1>
        {board.description && <p className="bio">{board.description}</p>}
        <Link href={`/u/${board.owner.username}?tab=saved`} className="board-owner">
          <Avatar user={board.owner} size={28} />
          <span>{board.owner.name}</span>
        </Link>
        <p className="muted">{board.pinsCount} pin</p>
        {isOwner && (
          <div className="profile-actions">
            <button className="btn btn-secondary" onClick={() => setEditing(true)}><EditIcon size={16} /> Üýtget</button>
            <button className="btn btn-secondary danger" onClick={remove} disabled={deleting}>
              <TrashIcon size={16} /> {deleting ? "Pozulýar…" : "Poz"}
            </button>
          </div>
        )}
      </section>

      <PinFeed
        paged={pins}
        action={isOwner ? { label: "Tagtadan aýyr", onClick: removePin } : undefined}
        empty={
          <div className="empty">
            <h2>Bu tagta entek boş</h2>
            <p>{isOwner ? "Halan pinleriňizi “Sakla” düwmesi bilen şu tagta goşuň." : "Bu tagtada entek pin ýok."}</p>
            <Link href="/" className="btn btn-primary">Ideýalara seret</Link>
          </div>
        }
      />

      {editing && (
        <BoardFormModal
          board={board}
          onClose={() => setEditing(false)}
          onSaved={(b) => {
            setBoard(b);
            setEditing(false);
            toast("Tagta täzelendi");
          }}
        />
      )}
    </div>
  );
}
