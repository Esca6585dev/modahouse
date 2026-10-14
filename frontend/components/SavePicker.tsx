"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLoginHref } from "@/lib/hooks";
import type { Board } from "@/lib/types";
import { CheckIcon, LockIcon, PlusIcon } from "./Icons";
import Popover from "./Popover";
import { useToast } from "./Toast";

type Props = {
  pinId: number;
  savedBoardIds: number[];
  onChange: (ids: number[]) => void;
  className?: string;
};


/** Board list + "new board" form. Used in the Sakla popover and in the ⋯ menu's save sheet. */
export function BoardPickerBody({ pinId, savedBoardIds, onChange }: Omit<Props, "className">) {
  const toast = useToast();
  const [boards, setBoards] = useState<Board[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [busy, setBusy] = useState<number | "new" | null>(null);
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState("");

  useEffect(() => {
    let alive = true;
    setLoadError(null);
    api.myBoards().then(
      (b) => alive && setBoards(b),
      (e) => alive && setLoadError(errorMessage(e)),
    );
    return () => { alive = false; };
  }, []);

  const toggleBoard = async (board: Board) => {
    if (busy !== null) return;
    const isIn = savedBoardIds.includes(board.id);
    setBusy(board.id);
    try {
      const res = isIn ? await api.unsavePin(board.id, pinId) : await api.savePin(board.id, pinId);
      const ids = res?.savedBoardIds ?? savedBoardIds.filter((id) => id !== board.id);
      onChange(ids);
      setBoards((l) => l?.map((b) => (b.id === board.id ? { ...b, pinsCount: Math.max(0, b.pinsCount + (isIn ? -1 : 1)) } : b)) ?? l);
      toast(isIn ? `“${board.name}” tagtasyndan aýryldy` : `“${board.name}” tagtasyna saklandy`);
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(null);
    }
  };

  const createBoard = async (e: React.FormEvent) => {
    e.preventDefault();
    const name = newName.trim();
    if (!name || busy !== null) return;
    setBusy("new");
    try {
      const board = await api.createBoard({ name });
      const res = await api.savePin(board.id, pinId);
      onChange(res.savedBoardIds);
      setBoards((l) => [...(l ?? []), { ...board, pinsCount: 1 }]);
      setNewName("");
      setCreating(false);
      toast(`“${board.name}” tagtasy döredildi we pin saklandy`);
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      <div className="picker-head">Tagta saýlaň</div>
      <div className="picker-list">
        {loadError && <p className="picker-note error-text">{loadError}</p>}
        {!boards && !loadError && (
          <>
            <div className="picker-skel" />
            <div className="picker-skel" />
          </>
        )}
        {boards?.length === 0 && <p className="picker-note">Entek tagtaňyz ýok</p>}
        {boards?.map((b) => {
          const isIn = savedBoardIds.includes(b.id);
          return (
            <button
              key={b.id}
              className={`picker-item ${isIn ? "on" : ""}`}
              onClick={() => toggleBoard(b)}
              disabled={busy !== null}
              aria-pressed={isIn}
            >
              <span className="picker-thumb">
                {b.covers[0] && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={b.covers[0]} alt="" loading="lazy" />
                )}
              </span>
              <span className="picker-name">
                {b.name}
                {b.isPrivate && <LockIcon size={13} />}
              </span>
              <span className="picker-state">
                {busy === b.id ? <span className="spinner" /> : isIn ? <><CheckIcon size={16} /> Saklandy</> : "Sakla"}
              </span>
            </button>
          );
        })}
      </div>
      <div className="picker-foot">
        {creating ? (
          <form className="picker-new" onSubmit={createBoard}>
            <input
              autoFocus
              value={newName}
              maxLength={50}
              onChange={(e) => setNewName(e.target.value)}
              placeholder="Tagtanyň ady"
              aria-label="Täze tagtanyň ady"
            />
            <button className="btn btn-primary btn-sm" disabled={!newName.trim() || busy !== null}>
              {busy === "new" ? "…" : "Döret"}
            </button>
          </form>
        ) : (
          <button className="picker-create" onClick={() => setCreating(true)}>
            <span className="picker-plus"><PlusIcon size={18} /></span> Täze tagta döret
          </button>
        )}
      </div>
    </>
  );
}

export default function SavePicker({ pinId, savedBoardIds, onChange, className = "" }: Props) {
  const { user } = useAuth();
  const router = useRouter();
  const loginHref = useLoginHref();
  const btnRef = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  const saved = savedBoardIds.length > 0;

  const onButton = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!user) {
      router.push(loginHref());
      return;
    }
    setOpen((o) => !o);
  };

  return (
    <>
      <button
        ref={btnRef}
        className={`btn btn-save ${saved ? "saved" : ""} ${className}`}
        onClick={onButton}
        aria-haspopup="dialog"
        aria-expanded={open}
      >
        {saved ? "Saklandy" : "Sakla"}
      </button>
      <Popover anchor={btnRef} open={open} onClose={() => setOpen(false)} width={320} label="Tagta saýla">
        <BoardPickerBody pinId={pinId} savedBoardIds={savedBoardIds} onChange={onChange} />
      </Popover>
    </>
  );
}
