"use client";

import { useEffect } from "react";
import { SendIcon } from "@/components/Icons";

export default function MessagesHome() {
  useEffect(() => { document.title = "Habarlar · ModaHouse"; }, []);
  return (
    <div className="chat-idle">
      <span className="chat-idle-icon"><SendIcon size={34} /></span>
      <h2>Habarlaryňyz</h2>
      <p className="muted">Çepdäki sanawdan habarlaşygy saýlaň ýa-da täze habar ýazyň. Suratlary, faýllary we postlary ugradyp bilersiňiz.</p>
    </div>
  );
}
