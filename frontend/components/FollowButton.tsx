"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLoginHref } from "@/lib/hooks";
import type { Profile } from "@/lib/types";
import { useToast } from "./Toast";

/** Optimistic follow toggle. onChange receives the expected follower delta, then the server profile. */
export default function FollowButton({
  username, isFollowing, onChange, className = "",
}: {
  username: string;
  isFollowing: boolean;
  onChange?: (following: boolean, profile?: Profile) => void;
  className?: string;
}) {
  const { user } = useAuth();
  const router = useRouter();
  const loginHref = useLoginHref();
  const toast = useToast();
  const [on, setOn] = useState(isFollowing);
  const [busy, setBusy] = useState(false);

  useEffect(() => setOn(isFollowing), [isFollowing]);

  if (user?.username === username) return null;

  const toggle = async () => {
    if (!user) {
      router.push(loginHref());
      return;
    }
    const next = !on;
    setOn(next);
    onChange?.(next);
    setBusy(true);
    try {
      const p = next ? await api.follow(username) : await api.unfollow(username);
      setOn(p.isFollowing);
      onChange?.(p.isFollowing, p);
    } catch (e) {
      setOn(!next);
      onChange?.(!next);
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <button
      className={`btn ${on ? "btn-dark" : "btn-primary"} ${className}`}
      onClick={toggle}
      disabled={busy}
      aria-pressed={on}
    >
      {on ? "Yzarlanýar" : "Yzarla"}
    </button>
  );
}
