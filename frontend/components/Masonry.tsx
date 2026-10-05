import type { Pin } from "@/lib/data";
import PinCard from "./PinCard";

export default function Masonry({ pins, idPrefix }: { pins: Pin[]; idPrefix?: string }) {
  return (
    <div className="masonry">
      {pins.map((p) => (
        <PinCard key={p.id} pin={p} idPrefix={idPrefix} />
      ))}
    </div>
  );
}
