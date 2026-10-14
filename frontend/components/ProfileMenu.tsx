"use client";

import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLoginHref } from "@/lib/hooks";
import { shareUrl } from "@/lib/share";
import type { Profile } from "@/lib/types";
import { BanIcon, CopyIcon, DotsIcon, ShareIcon } from "./Icons";
import Popover from "./Popover";
import { useToast } from "./Toast";

/** "⋯" on someone else's profile: share, copy link, block / unblock. */
export default function ProfileMenu({ profile, onBlockedChange }: { profile: Profile; onBlockedChange: (blocked: boolean) => void }) {
  const { user } = useAuth();
  const router = useRouter();
  const loginHref = useLoginHref();
  const toast = useToast();
  const btn = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const url = `/u/${profile.username}`;

  const toggleBlock = async () => {
    if (!user) {
      router.push(loginHref());
      return;
    }
    const want = !profile.isBlocked;
    if (want && !window.confirm(`@${profile.username} petiklensinmi? Ol siziň postlaryňyzy görmez, siz hem onuňkyny görmersiňiz. Yzarlamalar aýrylar.`)) return;
    setBusy(true);
    try {
      const r = want ? await api.block(profile.username) : await api.unblock(profile.username);
      onBlockedChange(r.blocked);
      toast(r.blocked ? `@${profile.username} petiklendi` : `@${profile.username} petikden aýryldy`);
      setOpen(false);
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <button ref={btn} className="icon-btn ig-dots" onClick={() => setOpen((o) => !o)} aria-label="Has köp" aria-haspopup="menu" aria-expanded={open}>
        <DotsIcon size={22} />
      </button>
      <Popover anchor={btn} open={open} onClose={() => setOpen(false)} width={260} label="Profil menýusy" className="pin-menu">
        <div className="pm-list" role="menu">
          <button className="menu-item" role="menuitem" onClick={async () => { setOpen(false); const m = await shareUrl(url, profile.name); if (m) toast(m); }}>
            <ShareIcon size={18} /> Profili paýlaş
          </button>
          <button
            className="menu-item"
            role="menuitem"
            onClick={async () => {
              setOpen(false);
              try {
                await navigator.clipboard.writeText(new URL(url, window.location.origin).toString());
                toast("Baglanyşyk göçürildi");
              } catch {
                window.prompt("Baglanyşygy göçüriň:", new URL(url, window.location.origin).toString());
              }
            }}
          >
            <CopyIcon size={18} /> Baglanyşygy göçür
          </button>
          <button className="menu-item danger" role="menuitem" onClick={toggleBlock} disabled={busy}>
            <BanIcon size={18} /> {profile.isBlocked ? "Petigi aýyr" : "Petikle"}
          </button>
        </div>
      </Popover>
    </>
  );
}
