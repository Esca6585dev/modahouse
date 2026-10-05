"use client";

import { useState } from "react";
import { api, errorMessage } from "@/lib/api";
import type { Board } from "@/lib/types";
import Modal from "./Modal";

/** Create (no `board`) or edit a board. */
export default function BoardFormModal({
  board, onClose, onSaved,
}: { board?: Board; onClose: () => void; onSaved: (b: Board) => void }) {
  const [name, setName] = useState(board?.name ?? "");
  const [description, setDescription] = useState(board?.description ?? "");
  const [isPrivate, setIsPrivate] = useState(board?.isPrivate ?? false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      setError("Tagta at beriň");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const body = { name: name.trim(), description: description.trim(), isPrivate };
      const saved = board ? await api.updateBoard(board.id, body) : await api.createBoard(body);
      onSaved(saved);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  return (
    <Modal title={board ? "Tagtany üýtget" : "Täze tagta döret"} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <label>
          Ady
          <input value={name} onChange={(e) => setName(e.target.value)} maxLength={50} placeholder="Mysal üçin: Güýz stili" />
        </label>
        <label>
          Düşündiriş
          <textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} maxLength={300} placeholder="Bu tagta näme barada?" />
        </label>
        <label className="check">
          <input type="checkbox" checked={isPrivate} onChange={(e) => setIsPrivate(e.target.checked)} />
          <span>
            <strong>Gizlin tagta</strong>
            <small>Diňe siz görüp bilersiňiz</small>
          </span>
        </label>
        {error && <p className="form-error" role="alert">{error}</p>}
        <div className="form-actions">
          <button type="button" className="btn btn-secondary" onClick={onClose}>Ýatyr</button>
          <button className="btn btn-primary" disabled={busy}>{busy ? "Saklanýar…" : board ? "Sakla" : "Döret"}</button>
        </div>
      </form>
    </Modal>
  );
}
