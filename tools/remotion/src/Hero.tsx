import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { c, font, mono } from "./theme";

// A latency curve: flat ~180ms baseline, then a spike to ~850ms — the exact
// scenario VibeProof runs (homepage p95 180ms -> 850ms while CPU stays 35%).
const W = 560;
const H = 220;
const points = (() => {
  const out: Array<[number, number]> = [];
  const n = 60;
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    // baseline with tiny jitter, then a ramp after t=0.55
    let ms = 180 + Math.sin(t * 22) * 8;
    if (t > 0.55) ms = 180 + (850 - 180) * Math.min(1, (t - 0.55) / 0.35);
    const x = t * W;
    const y = H - ((ms - 120) / (900 - 120)) * H;
    out.push([x, y]);
  }
  return out;
})();
const pathD = points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`).join(" ");
const tip = points[points.length - 1];

const Chip: React.FC<{ label: string; color: string }> = ({ label, color }) => (
  <span
    style={{
      fontFamily: mono, fontSize: 20, color, border: `1px solid ${color}55`,
      background: `${color}14`, padding: "6px 14px", borderRadius: 999, whiteSpace: "nowrap",
    }}
  >
    {label}
  </span>
);

export const Hero: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();

  // Loop-friendly: every frame (incl. frame 0, the GIF poster) is fully drawn.
  const loop = (frame % durationInFrames) / durationInFrames; // 0..1
  const titleFade = 1;
  const titleUp = Math.sin(loop * Math.PI * 2) * 2.5; // gentle float
  const alarm = 0.4 + 0.6 * Math.abs(Math.sin(frame / 5)); // pulsing incident dot
  const breathe = 1 + 0.008 * Math.sin(loop * Math.PI * 2);
  // a highlight dot that scans along the fully-drawn curve
  const scanIdx = Math.min(points.length - 1, Math.round(loop * (points.length - 1)));
  const scan = points[scanIdx];

  return (
    <AbsoluteFill style={{ background: `radial-gradient(120% 140% at 15% -10%, ${c.bgTop} 0%, ${c.bg} 55%)`, fontFamily: font }}>
      {/* faint grid */}
      <AbsoluteFill style={{ opacity: 0.06, backgroundImage: `linear-gradient(${c.blue} 1px, transparent 1px), linear-gradient(90deg, ${c.blue} 1px, transparent 1px)`, backgroundSize: "44px 44px" }} />
      <AbsoluteFill style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between", padding: "0 72px" }}>
        {/* left: wordmark */}
        <div style={{ transform: `translateY(${titleUp}px)`, opacity: titleFade }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 6 }}>
            <div style={{ width: 16, height: 16, borderRadius: 4, background: c.green, boxShadow: `0 0 18px ${c.green}` }} />
            <span style={{ fontFamily: mono, fontSize: 22, color: c.dim, letterSpacing: 2 }}>OWNERSHIP&nbsp;CHALLENGE</span>
          </div>
          <div style={{ fontSize: 92, fontWeight: 800, color: c.text, letterSpacing: -2, lineHeight: 1 }}>
            Vibe<span style={{ color: c.green }}>Proof</span>
          </div>
          <div style={{ fontSize: 30, color: c.dim, marginTop: 14, maxWidth: 520 }}>
            Build with AI. <span style={{ color: c.text }}>Prove you know why it works.</span>
          </div>
          <div style={{ display: "flex", gap: 12, marginTop: 26 }}>
            <Chip label="Godot Incident Room" color={c.blue} />
            <Chip label="FastAPI engines" color={c.violet} />
            <Chip label="Evidence scoring" color={c.green} />
          </div>
        </div>

        {/* right: animated latency spike */}
        <div style={{ transform: `scale(${breathe})`, background: c.panel, border: `1px solid ${c.border}`, borderRadius: 18, padding: 24, width: W + 48 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
            <span style={{ fontFamily: mono, fontSize: 18, color: c.dim }}>homepage&nbsp;p95&nbsp;latency</span>
            <span style={{ fontFamily: mono, fontSize: 18, color: c.amber, opacity: alarm || 0.4 }}>● INCIDENT</span>
          </div>
          <svg width={W} height={H} style={{ display: "block" }}>
            <line x1={0} y1={H - ((180 - 120) / 780) * H} x2={W} y2={H - ((180 - 120) / 780) * H} stroke={c.border} strokeDasharray="4 6" />
            <path d={pathD} fill="none" stroke={c.amber} strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" style={{ filter: `drop-shadow(0 0 6px ${c.amber}88)` }} />
            <circle cx={scan[0]} cy={scan[1]} r={5} fill={c.text} opacity={0.85} />
            <circle cx={tip[0]} cy={tip[1]} r={8} fill={c.red} opacity={alarm} style={{ filter: `drop-shadow(0 0 8px ${c.red})` }} />
            <circle cx={tip[0]} cy={tip[1]} r={4} fill={c.text} />
          </svg>
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8, fontFamily: mono, fontSize: 22 }}>
            <span style={{ color: c.green }}>180 ms</span>
            <span style={{ color: c.dim }}>CPU 35% →</span>
            <span style={{ color: c.amber }}>850 ms</span>
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
