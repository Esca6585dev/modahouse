import { palettes, type Pin } from "@/lib/data";

const W = 300;

function wave(y: number, amp: number) {
  return `M0 ${y} Q ${W * 0.25} ${y - amp} ${W * 0.5} ${y} T ${W} ${y} V 9999 H 0 Z`;
}

function blob(cx: number, cy: number, r: number) {
  return `M ${cx} ${cy - r} C ${cx + r * 0.9} ${cy - r} ${cx + r * 1.1} ${cy + r * 0.6} ${cx + r * 0.2} ${cy + r}
    C ${cx - r * 0.7} ${cy + r * 1.3} ${cx - r * 1.2} ${cy + r * 0.1} ${cx - r * 0.8} ${cy - r * 0.5}
    C ${cx - r * 0.5} ${cy - r} ${cx - r * 0.3} ${cy - r} ${cx} ${cy - r} Z`;
}

function archPath(x1: number, x2: number, top: number, bottom: number) {
  const r = (x2 - x1) / 2;
  return `M ${x1} ${bottom} V ${top + r} A ${r} ${r} 0 0 1 ${x2} ${top + r} V ${bottom} Z`;
}

export default function PinArt({ pin, idPrefix = "p" }: { pin: Pin; idPrefix?: string }) {
  const H = Math.round(W * pin.ratio);
  const [a, b, c, d] = palettes[pin.palette];
  const gid = `${idPrefix}-${pin.id}-g`;

  let body: React.ReactNode;
  switch (pin.kind) {
    case "mountains":
      body = (
        <>
          <rect width={W} height={H} fill={`url(#${gid})`} />
          <circle cx={W * 0.68} cy={H * 0.35} r={W * 0.14} fill={c} />
          <path d={`M0 ${H * 0.72} L${W * 0.3} ${H * 0.48} L${W * 0.55} ${H * 0.7} L${W * 0.75} ${H * 0.55} L${W} ${H * 0.75} V${H} H0Z`} fill={d} opacity={0.5} />
          <path d={`M0 ${H * 0.86} L${W * 0.25} ${H * 0.66} L${W * 0.5} ${H * 0.82} L${W * 0.8} ${H * 0.62} L${W} ${H * 0.8} V${H} H0Z`} fill={d} />
        </>
      );
      break;
    case "waves":
      body = (
        <>
          <rect width={W} height={H} fill={`url(#${gid})`} />
          <circle cx={W * 0.3} cy={H * 0.3} r={W * 0.12} fill="#fff" opacity={0.7} />
          <path d={wave(H * 0.55, 28)} fill={b} opacity={0.55} />
          <path d={wave(H * 0.7, 22)} fill={b} />
          <path d={wave(H * 0.85, 18)} fill={d} />
        </>
      );
      break;
    case "circles":
      body = (
        <>
          <rect width={W} height={H} fill={a} />
          <circle cx={W * 0.1} cy={H * 0.08} r={W * 0.3} fill={b} opacity={0.35} />
          <circle cx={W * 0.5} cy={H * 0.52} r={W * 0.36} fill={c} />
          <circle cx={W * 0.5} cy={H * 0.52} r={W * 0.28} fill={b} opacity={0.3} />
          <circle cx={W * 0.42} cy={H * 0.47} r={W * 0.08} fill={b} />
          <circle cx={W * 0.6} cy={H * 0.5} r={W * 0.06} fill={d} />
          <circle cx={W * 0.5} cy={H * 0.6} r={W * 0.07} fill={d} opacity={0.6} />
          <circle cx={W * 0.62} cy={H * 0.62} r={W * 0.035} fill={b} />
          <circle cx={W * 0.9} cy={H * 0.92} r={W * 0.2} fill={d} opacity={0.15} />
        </>
      );
      break;
    case "arch":
      body = (
        <>
          <rect width={W} height={H} fill={a} />
          <rect y={H * 0.86} width={W} height={H * 0.14} fill={d} opacity={0.2} />
          <path d={archPath(W * 0.2, W * 0.8, H * 0.14, H * 0.86)} fill={b} />
          <path d={archPath(W * 0.3, W * 0.7, H * 0.24, H * 0.86)} fill={c} />
          <circle cx={W * 0.5} cy={H * 0.42} r={W * 0.07} fill={d} opacity={0.7} />
          <rect x={W * 0.42} y={H * 0.72} width={W * 0.16} height={H * 0.14} rx={6} fill={d} />
        </>
      );
      break;
    case "stripes":
      body = (
        <>
          <rect width={W} height={H} fill={c} />
          <g transform={`rotate(-20 ${W / 2} ${H / 2})`}>
            {Array.from({ length: 14 }, (_, i) => (
              <rect key={i} x={-W} y={i * 44 - 120} width={W * 3} height={22} fill={i % 3 === 0 ? d : i % 3 === 1 ? b : a} />
            ))}
          </g>
          <circle cx={W / 2} cy={H / 2} r={W * 0.22} fill={c} stroke={d} strokeWidth={6} />
          <circle cx={W / 2} cy={H / 2} r={W * 0.1} fill={b} />
        </>
      );
      break;
    case "blob":
      body = (
        <>
          <rect width={W} height={H} fill={a} />
          <path d={blob(W * 0.35, H * 0.35, W * 0.28)} fill={b} opacity={0.8} />
          <path d={blob(W * 0.65, H * 0.62, W * 0.3)} fill={c} />
          <path d={blob(W * 0.45, H * 0.75, W * 0.14)} fill={d} opacity={0.75} />
          <circle cx={W * 0.78} cy={H * 0.2} r={6} fill={d} />
          <circle cx={W * 0.86} cy={H * 0.26} r={4} fill={d} />
          <circle cx={W * 0.18} cy={H * 0.86} r={5} fill={b} />
        </>
      );
      break;
    case "dress":
      body = (
        <>
          <rect width={W} height={H} fill={`url(#${gid})`} />
          <path
            d={`M ${W * 0.36} ${H * 0.21} L ${W * 0.5} ${H * 0.15} L ${W * 0.64} ${H * 0.21}`}
            fill="none" stroke={d} strokeWidth={4} strokeLinecap="round" strokeLinejoin="round"
          />
          <path d={`M ${W * 0.5} ${H * 0.15} V ${H * 0.12} a 9 9 0 1 1 9 -9`} fill="none" stroke={d} strokeWidth={4} strokeLinecap="round" />
          <path
            d={`M ${W * 0.42} ${H * 0.22} L ${W * 0.46} ${H * 0.22} Q ${W * 0.5} ${H * 0.28} ${W * 0.54} ${H * 0.22} L ${W * 0.58} ${H * 0.22}
               L ${W * 0.61} ${H * 0.44} L ${W * 0.8} ${H * 0.84} Q ${W * 0.5} ${H * 0.9} ${W * 0.2} ${H * 0.84} L ${W * 0.39} ${H * 0.44} Z`}
            fill={b}
          />
          <rect x={W * 0.39} y={H * 0.43} width={W * 0.22} height={H * 0.03} rx={3} fill={d} />
        </>
      );
      break;
    case "plant": {
      const baseY = H * 0.66;
      const L = H * 0.42;
      body = (
        <>
          <rect width={W} height={H} fill={a} />
          <ellipse cx={W / 2} cy={H * 0.9} rx={W * 0.24} ry={H * 0.025} fill={d} opacity={0.15} />
          {[-62, -32, 0, 30, 58].map((deg, i) => (
            <ellipse
              key={deg}
              cx={W / 2}
              cy={baseY - L / 2}
              rx={W * 0.075}
              ry={L / 2}
              fill={i % 2 ? d : b}
              opacity={i % 2 ? 0.75 : 1}
              transform={`rotate(${deg} ${W / 2} ${baseY})`}
            />
          ))}
          <path d={`M ${W * 0.32} ${H * 0.68} H ${W * 0.68} L ${W * 0.63} ${H * 0.89} H ${W * 0.37} Z`} fill={c} />
          <rect x={W * 0.3} y={H * 0.65} width={W * 0.4} height={H * 0.05} rx={4} fill={d} />
        </>
      );
      break;
    }
  }

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="pin-art" role="img" aria-label={pin.title} preserveAspectRatio="xMidYMid slice">
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={a} />
          <stop offset="1" stopColor={pin.kind === "mountains" ? b : c} />
        </linearGradient>
      </defs>
      {body}
    </svg>
  );
}
