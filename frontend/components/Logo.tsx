/**
 * Brand logo (brand/logo-wordmark.svg, logo-wordmark-light.svg, logo-mark.svg) inlined so the letters follow
 * the theme: ink #262B2F on light backgrounds, white in dark mode; the roof and "HOUSE" stay brand red.
 */

const RED = "#D7263D";

export function LogoMark({ size = 36, className = "" }: { size?: number; className?: string }) {
  return (
    <svg className={`logo-mark-svg ${className}`} width={size} height={size} viewBox="0 0 100 100" role="img" aria-label="moda HOUSE">
      <circle cx="50" cy="50" r="48" fill="#FFFFFF" stroke="#262B2F" strokeWidth="4" />
      <g fill="none" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="44" cy="62" r="15" stroke="#262B2F" strokeWidth="7" />
        <path d="M59 77 V33" stroke="#262B2F" strokeWidth="7" />
        <path d="M47 25 L59 14 L71 25" stroke={RED} strokeWidth="6.5" />
      </g>
    </svg>
  );
}

/** Full "moda HOUSE" wordmark, cropped to its content (viewBox of the brand file is 300×160). */
export function LogoWordmark({ height = 36, className = "" }: { height?: number; className?: string }) {
  // Content spans x 8..270, y 9..152 in the brand file.
  const vb = { x: 6, y: 8, w: 266, h: 146 };
  return (
    <svg
      className={`logo-wordmark ${className}`}
      height={height}
      width={Math.round((height * vb.w) / vb.h)}
      viewBox={`${vb.x} ${vb.y} ${vb.w} ${vb.h}`}
      role="img"
      aria-label="moda HOUSE"
    >
      <g className="logo-ink" fill="none" strokeWidth="7.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M14 110 V76 A16 16 0 0 1 46 76 V110 M46 76 A16 16 0 0 1 78 76 V110" />
        <circle cx="114" cy="85" r="24" />
        <circle cx="176" cy="85" r="24" />
        <path d="M200 110 V38" />
        <circle cx="238" cy="85" r="24" />
        <path d="M262 62 V110" />
      </g>
      <path d="M184 30 L200 15 L216 30" fill="none" stroke={RED} strokeWidth="8" strokeLinecap="round" strokeLinejoin="round" />
      <text
        x="264"
        y="147"
        textAnchor="end"
        fontFamily="Montserrat, 'Helvetica Neue', Arial, sans-serif"
        fontSize="30"
        fontWeight="800"
        letterSpacing="2.5"
        fill={RED}
      >
        HOUSE
      </text>
    </svg>
  );
}
