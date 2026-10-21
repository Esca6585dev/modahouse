import Avatar from "@/components/Avatar";
import { StoreIcon, VerifiedIcon } from "@/components/Icons";
import type { ChatUser } from "@/lib/types";

/** Avatar with a small store badge for business accounts. */
export function ChatAvatar({ user, size = 52 }: { user: ChatUser; size?: number }) {
  return (
    <span className="chat-avatar" style={{ width: size, height: size }}>
      <Avatar user={user} size={size} />
      {user.isBusiness && <span className="chat-biz" title="Biznes hasaby" aria-label="Biznes hasaby"><StoreIcon size={Math.max(10, Math.round(size * 0.22))} /></span>}
    </span>
  );
}

export function ChatName({ user }: { user: ChatUser }) {
  return (
    <span className="chat-name">
      <span className="chat-name-text">{user.name || user.username}</span>
      {user.verified && <VerifiedIcon size={15} />}
    </span>
  );
}
