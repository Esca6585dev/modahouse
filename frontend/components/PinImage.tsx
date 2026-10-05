import type { Pin } from "@/lib/types";

/** Image box sized by the pin's aspect ratio with its color as a placeholder (no layout shift). */
export default function PinImage({ pin, eager, className = "" }: {
  pin: Pick<Pin, "imageUrl" | "width" | "height" | "color" | "title">;
  eager?: boolean;
  className?: string;
}) {
  const w = pin.width > 0 ? pin.width : 1;
  const h = pin.height > 0 ? pin.height : 1;
  return (
    <div className={`pin-img ${className}`} style={{ aspectRatio: `${w} / ${h}`, background: pin.color || "var(--surface)" }}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={pin.imageUrl}
        alt={pin.title}
        width={w}
        height={h}
        loading={eager ? "eager" : "lazy"}
        decoding="async"
      />
    </div>
  );
}
