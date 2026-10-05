"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLoginHref } from "@/lib/hooks";
import type { Board } from "@/lib/types";
import { CheckIcon, LockIcon, PlusIcon } from "./Icons";
import { useToast } from "./Toast";

type Props = {
  pinId: number;
  savedBoardIds: number[];
  onChange: (ids: number[]) => void;
  className?: string;
};

const W = 320;

export default function SavePicker({ pinId, savedBoardIds, onChange, className = "" }: Props) {
  const { user } = useAuth();
  const router = useRouter();
  const loginHref = useLoginHref();
  const toast = useToast();
  const btnRef = useRef<HTMLButtonElement>(null);
  const popRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [boards, setBoards] = useState<Board[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [busy, setBusy] = useState<number | "new" | null>(null);
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState("");
  const [pos, setPos] = useState<{ top: number; left: number; maxHeight: number } | null>(null);
  const [sheet, setSheet] = useState(false);

  const saved = savedBoardIds.length > 0;

  const place = useCallback(() => {
    const b = btnRef.current?.getBoundingClientRect();
    if (!b) return;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const isSheet = vw < 600;
    setSheet(isSheet);
    if (isSheet) return;
    const left = Math.min(Math.max(16, b.right - W), vw - W - 16);
    const below = vh - b.bottom - 16;
    const above = b.top - 16;
    if (below >= 280 || below >= above) {
      setPos({ top: b.bottom + 8, left, maxHeight: Math.max(200, below - 8) });
    } else {
      const maxHeight = Math.min(440, above - 8);
      setPos({ top: b.top - 8 - maxHeight, left, maxHeight });
    }
  }, []);

  useLayoutEffect(() => {
    if (!open) return;
    place();
    window.addEventListener("resize", place);
    window.addEventListener("scroll", place, true);
    return () => {
      window.removeEventListener("resize", place);
      window.removeEventListener("scroll", place, true);
    };
  }, [open, place]);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      const t = e.target as Node;
      if (popRef.current?.contains(t) || btnRef.current?.contains(t)) return;
      setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    let alive = true;
    setLoadError(null);
    api.myBoards().then(
      (b) => alive && setBoards(b),
      (e) => alive && setLoadError(errorMessage(e)),
    );
    return () => { alive = false; };
  }, [open]);

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

  const onButton = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!user) {
      router.push(loginHref());
      return;
    }
    setOpen((o) => !o);
  };

  const popover = open && (sheet || pos) ? (
    <>
      {sheet && <div className="sheet-backdrop" onMouseDown={() => setOpen(false)} />}
      <div
        ref={popRef}
        className={`picker ${sheet ? "sheet" : ""}`}
        style={sheet || !pos ? undefined : { top: pos.top, left: pos.left, width: W, maxHeight: pos.maxHeight }}
        role="dialog"
        aria-label="Tagta saýla"
        onClick={(e) => e.stopPropagation()}
      >
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
      </div>
    </>
  ) : null;

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
      {popover && createPortal(popover, document.body)}
    </>
  );
}
