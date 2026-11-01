"use client";

import Link from "next/link";
import { useState } from "react";
import { api, ApiError, errorMessage } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { useAuth } from "@/lib/auth";
import type { BoostOption, Pin } from "@/lib/types";
import { ArrowUpIcon, CheckIcon } from "./Icons";
import Modal from "./Modal";
import { useToast } from "./Toast";

const until = dateTime;

/** Owner's "Öňe çykar": spend teňňe to show the post at the top of the feeds. */
export default function BoostBox({ pin, onBoosted }: { pin: Pin; onBoosted: (boostedUntil: string) => void }) {
  const { user, setUser } = useAuth();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [options, setOptions] = useState<BoostOption[] | null>(null);
  const [balance, setBalance] = useState(user?.coins ?? 0);
  const [busy, setBusy] = useState<number | null>(null);
  const [short, setShort] = useState(false);

  const show = async () => {
    setOpen(true);
    setShort(false);
    try {
      const w = await api.wallet();
      setOptions(w.boostOptions);
      setBalance(w.balance);
    } catch (e) {
      toast(errorMessage(e), "error");
      setOpen(false);
    }
  };

  const boost = async (o: BoostOption) => {
    setBusy(o.days);
    try {
      const r = await api.boost(pin.id, o.days);
      setBalance(r.balance);
      if (user) setUser({ ...user, coins: r.balance });
      onBoosted(r.boostedUntil);
      toast(`Post ${until(r.boostedUntil)} çenli öňe çykaryldy`);
      setOpen(false);
    } catch (e) {
      if (e instanceof ApiError && e.status === 402) setShort(true);
      else toast(errorMessage(e), "error");
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="boost-box">
      <div>
        <strong>Öňe çykar</strong>
        <span className="muted small">
          {pin.boostedUntil ? <><CheckIcon size={14} /> {until(pin.boostedUntil)} çenli öňe çykarylan</> : "Postuňyz lentanyň başynda görkeziler"}
        </span>
      </div>
      <button className="btn btn-primary btn-sm" onClick={show}><ArrowUpIcon size={16} /> {pin.boostedUntil ? "Uzalt" : "Öňe çykar"}</button>
      {open && (
        <Modal title="Posty öňe çykar" onClose={() => setOpen(false)}>
          <p className="muted">Balansyňyz: <strong className="coin-amount">{balance} teňňe</strong></p>
          {!options ? (
            <div className="skeleton" style={{ height: 120, borderRadius: 16 }} />
          ) : (
            <div className="boost-options">
              {options.map((o) => (
                <button key={o.days} className="boost-option" disabled={busy !== null || o.coins > balance} onClick={() => boost(o)}>
                  <strong>{o.days} gün</strong>
                  <span>{o.coins} teňňe</span>
                  {busy === o.days && <span className="spinner" />}
                </button>
              ))}
            </div>
          )}
          {(short || (options && options.every((o) => o.coins > balance))) && (
            <p className="form-error">Teňňe ýeterlik däl. <Link href="/coins">Teňňe satyn al</Link></p>
          )}
        </Modal>
      )}
    </div>
  );
}
