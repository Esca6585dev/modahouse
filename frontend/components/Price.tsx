import { BADGE_LABEL, discountPercent, money } from "@/lib/format";
import type { ProductBadge } from "@/lib/types";

/** Price line: sale (with discount), rent ("/ gün") or custom ("-dan başlap"). */
export function Price({ price, oldPrice, big, type }: { price: number; oldPrice?: number; big?: boolean; type?: string }) {
  const off = type === "sale" || !type ? discountPercent(price, oldPrice ?? 0) : 0;
  return (
    <span className={`price-wrap ${big ? "big" : ""}`}>
      <span className="price">
        {money(price)}
        {type === "rent" && <span className="price-unit"> / gün</span>}
        {type === "custom" && <span className="price-unit">{big ? "-dan başlap" : "-dan"}</span>}
      </span>
      {off > 0 && (
        <>
          <s className="old-price">{money(oldPrice ?? 0)}</s>
          {big && <span className="off-pill">-{off}%</span>}
        </>
      )}
    </span>
  );
}

export function Badge({ badge, className = "" }: { badge: ProductBadge | string; className?: string }) {
  if (!badge || !BADGE_LABEL[badge]) return null;
  return <span className={`pbadge pbadge-${badge} ${className}`}>{BADGE_LABEL[badge]}</span>;
}

/** Small "Kärende" / "Tikin" chip for non-sale listings. */
export function ListingChip({ type, className = "" }: { type?: string; className?: string }) {
  if (type === "rent") return <span className={`lchip lchip-rent ${className}`}>Kärende</span>;
  if (type === "custom") return <span className={`lchip lchip-custom ${className}`}>Tikip berýäris</span>;
  return null;
}
