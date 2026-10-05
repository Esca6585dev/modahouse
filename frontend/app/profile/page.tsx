"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAuth } from "@/lib/auth";

/** Old /profile link: send the visitor to their own profile (or to login). */
export default function ProfileRedirect() {
  const { user, ready } = useAuth();
  const router = useRouter();
  useEffect(() => {
    if (!ready) return;
    router.replace(user ? `/u/${user.username}` : "/login?next=%2Fprofile");
  }, [ready, user, router]);
  return <div className="page"><div className="center muted">Ýüklenýär…</div></div>;
}
