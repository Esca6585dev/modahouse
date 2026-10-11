import { BADGE_LABEL, discountPercent, money } from "@/lib/format";
import type { ProductBadge } from "@/lib/types";

export function Price({ price, oldPrice, big }: { price: number; oldPrice?: number; big?: boolean }) {
  const off = discountPercent(price, oldPrice ?? 0);
  return (
    <span className={`price-wrap ${big ? "big" : ""}`}>
      <span className="price">{money(price)}</span>
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
