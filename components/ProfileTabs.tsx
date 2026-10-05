"use client";

import { useState } from "react";
import type { Pin } from "@/lib/data";
import Masonry from "./Masonry";
import PinArt from "./PinArt";

type Board = { name: string; pins: Pin[] };

export default function ProfileTabs({ created, boards }: { created: Pin[]; boards: Board[] }) {
  const [tab, setTab] = useState<"created" | "saved">("saved");

  return (
    <>
      <div className="tabs" role="tablist">
        <button role="tab" aria-selected={tab === "created"} className={tab === "created" ? "active" : ""} onClick={() => setTab("created")}>
          Döredilen
        </button>
        <button role="tab" aria-selected={tab === "saved"} className={tab === "saved" ? "active" : ""} onClick={() => setTab("saved")}>
          Saklanan
        </button>
      </div>

      {tab === "created" ? (
        <Masonry pins={created} idPrefix="created" />
      ) : (
        <div className="boards">
          {boards.map((b, bi) => (
            <a key={b.name} href="#" className="board" onClick={(e) => e.preventDefault()}>
              <div className="board-collage">
                {b.pins.slice(0, 3).map((p, i) => (
                  <div key={p.id} className={`bc bc-${i}`}>
                    <PinArt pin={p} idPrefix={`board${bi}`} />
                  </div>
                ))}
              </div>
              <strong>{b.name}</strong>
              <span>{b.pins.length} pin</span>
            </a>
          ))}
        </div>
      )}
    </>
  );
}
