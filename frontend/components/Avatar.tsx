import { colorFor } from "@/lib/format";

type Who = { username: string; name: string; avatarUrl: string };

export default function Avatar({ user, size = 32 }: { user: Who; size?: number }) {
  const style = { width: size, height: size, fontSize: Math.round(size * 0.42) };
  if (user.avatarUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img className="avatar avatar-img" src={user.avatarUrl} alt="" width={size} height={size} style={style} loading="lazy" />
    );
  }
  return (
    <span className="avatar" style={{ ...style, background: colorFor(user.username || user.name) }} aria-hidden>
      {(user.name || user.username).charAt(0).toLocaleUpperCase("tk")}
    </span>
  );
}
