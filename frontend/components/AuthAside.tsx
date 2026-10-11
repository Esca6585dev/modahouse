"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { Pin } from "@/lib/types";
import { BagIcon, CameraIcon, TrophyIcon } from "./Icons";
import { LogoWordmark } from "./Logo";

/** Brand panel next to the login/register form: a collage of real pins plus the value proposition. */
export default function AuthAside() {
  const [pins, setPins] = useState<Pin[]>([]);
  useEffect(() => {
    api.pins({ page: 1, limit: 12, type: "products" }).then((p) => setPins(p.items), () => {});
  }, []);
  const cols = [0, 1, 2].map((c) => pins.filter((_, i) => i % 3 === c));
  return (
    <aside className="auth-aside" aria-hidden>
      <div className="auth-collage">
        {cols.map((col, i) => (
          <div key={i} className={`ac-col ac-col-${i}`}>
            {col.map((p) => (
              <div key={p.id} className="ac-item" style={{ aspectRatio: `${p.width || 3} / ${p.height || 4}`, background: p.color }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.imageUrl} alt="" />
              </div>
            ))}
          </div>
        ))}
      </div>
      <div className="auth-pitch">
        <LogoWordmark height={40} className="on-dark" />
        <h2>Moda ideýalary tap, sakla we sargyt et</h2>
        <ul>
          <li><CameraIcon size={18} /> Dükanlaryň story-lary we täze modeller</li>
          <li><BagIcon size={18} /> Köýnekleri reňki we ölçegi bilen sargyt et</li>
          <li><TrophyIcon size={18} /> Hepdäniň Top 10 köýnekçisi</li>
        </ul>
      </div>
    </aside>
  );
}
