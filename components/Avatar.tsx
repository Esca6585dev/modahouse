import type { Author } from "@/lib/data";

export default function Avatar({ author, size = 32 }: { author: Author; size?: number }) {
  return (
    <span
      className="avatar"
      style={{ width: size, height: size, background: author.color, fontSize: size * 0.42 }}
      aria-hidden
    >
      {author.name.charAt(0)}
    </span>
  );
}
