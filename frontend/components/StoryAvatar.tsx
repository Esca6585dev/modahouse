"use client";

import Avatar from "./Avatar";

type Who = { username: string; name: string; avatarUrl: string };

/** Avatar wrapped in an Instagram story ring: gradient when unseen, grey when seen, none without a story. */
export default function StoryAvatar({
  user, size, ring, onClick, label,
}: {
  user: Who;
  size: number;
  ring: "unseen" | "seen" | "none";
  onClick?: () => void;
  label?: string;
}) {
  const inner = (
    <span className={`story-ring ${ring}`} style={{ padding: ring === "none" ? 0 : Math.max(2, Math.round(size * 0.035)) }}>
      <span className="story-ring-gap" style={{ padding: ring === "none" ? 0 : Math.max(2, Math.round(size * 0.035)) }}>
        <Avatar user={user} size={size} />
      </span>
    </span>
  );
  if (!onClick || ring === "none") return inner;
  return (
    <button type="button" className="story-avatar-btn" onClick={onClick} aria-label={label ?? `${user.name} story`}>
      {inner}
    </button>
  );
}
