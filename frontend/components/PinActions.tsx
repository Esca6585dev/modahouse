"use client";

import { useState } from "react";
import { boards } from "@/lib/data";
import { LinkIcon, MoreIcon, ShareIcon } from "./Icons";

export default function PinActions() {
  const [saved, setSaved] = useState(false);
  const [board, setBoard] = useState(boards[0].name);

  return (
    <div className="detail-actions">
      <div className="detail-icons">
        <button className="icon-btn" aria-label="Has köp"><MoreIcon size={22} /></button>
        <button className="icon-btn" aria-label="Paýlaş"><ShareIcon size={22} /></button>
        <button className="icon-btn" aria-label="Baglanyşygy göçür"><LinkIcon size={22} /></button>
      </div>
      <div className="detail-save">
        <select value={board} onChange={(e) => setBoard(e.target.value)} aria-label="Tagta saýla" className="board-select">
          {boards.map((b) => (
            <option key={b.name}>{b.name}</option>
          ))}
        </select>
        <button className={`btn btn-save ${saved ? "saved" : ""}`} onClick={() => setSaved((s) => !s)} aria-pressed={saved}>
          {saved ? "Saklandy" : "Sakla"}
        </button>
      </div>
    </div>
  );
}
