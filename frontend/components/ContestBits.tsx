import { dateTime } from "@/lib/format";
import type { Contest } from "@/lib/types";

export const CONTEST_STATUS: Record<Contest["status"], string> = { active: "Dowam edýär", upcoming: "Ýakynda", finished: "Tamamlandy" };

const fmt = dateTime;

export function contestWhen(c: Contest): string {
  if (c.status === "upcoming") return `${fmt(c.startsAt)} başlaýar`;
  if (c.status === "active") return `${fmt(c.endsAt)} gutarýar`;
  return `${fmt(c.endsAt)} tamamlandy`;
}

export function contestPrize(c: Contest): string {
  return [c.prize, c.prizeCoins > 0 ? `${c.prizeCoins} teňňe` : ""].filter(Boolean).join(" + ");
}
