import { AbsoluteFill } from "remotion";
import { c, font, mono } from "./theme";

const Layer: React.FC<{
  n: string; title: string; verdict: string; verdictColor: string; body: string; chips?: string[]; accent: string;
}> = ({ n, title, verdict, verdictColor, body, chips, accent }) => (
  <div style={{ display: "flex", gap: 22, alignItems: "stretch" }}>
    <div style={{ width: 74, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: mono, fontSize: 40, fontWeight: 700, color: accent, background: `${accent}12`, border: `1px solid ${accent}44`, borderRadius: 16 }}>{n}</div>
    <div style={{ flex: 1, background: c.panel, border: `1px solid ${c.border}`, borderLeft: `4px solid ${accent}`, borderRadius: 16, padding: "20px 26px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <span style={{ fontFamily: font, fontSize: 30, fontWeight: 700, color: c.text }}>{title}</span>
        <span style={{ fontFamily: mono, fontSize: 16, fontWeight: 700, color: verdictColor, border: `1px solid ${verdictColor}66`, background: `${verdictColor}14`, borderRadius: 999, padding: "5px 14px" }}>{verdict}</span>
      </div>
      <div style={{ fontFamily: font, fontSize: 20, color: c.dim, marginTop: 10, lineHeight: 1.45 }}>{body}</div>
      {chips && (
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", marginTop: 14 }}>
          {chips.map((ch) => (
            <span key={ch} style={{ fontFamily: mono, fontSize: 16, color: accent, background: `${accent}14`, border: `1px solid ${accent}33`, borderRadius: 8, padding: "5px 12px" }}>{ch}</span>
          ))}
        </div>
      )}
    </div>
  </div>
);

export const Scoring: React.FC = () => (
  <AbsoluteFill style={{ background: `radial-gradient(120% 120% at 50% -10%, ${c.bgTop} 0%, ${c.bg} 60%)`, fontFamily: font, padding: 64, justifyContent: "center", gap: 22 }}>
    <div>
      <div style={{ fontSize: 46, fontWeight: 800, color: c.text, letterSpacing: -1 }}>Three-Layer Evidence Scoring</div>
      <div style={{ fontSize: 22, color: c.dim, marginTop: 6 }}>Separation is the whole point: only deterministic evidence earns points.</div>
    </div>

    <Layer n="1" title="Deterministic rules" verdict="SCORED" verdictColor={c.green} accent={c.green}
      body="Rule-based checks over the event log. Every point cites an event ID — fully auditable, no model in the loop." />
    <Layer n="2" title="LLM rubric panel" verdict="LABELED · NOT A VERDICT" verdictColor={c.amber} accent={c.amber}
      body="A panel grades reasoning against a rubric. Output is always labelled AI analysis — informs a human, never decides." />
    <Layer n="3" title="Context indices" verdict="NEVER SCORED" verdictColor={c.dim} accent={c.blue}
      body="Behavioural context for the reviewer only. Efficiency counts are context, not competence."
      chips={["Eₚ", "EPI", "Entropy", "Hypothesis Convergence", "AI Reliance"]} />

    <div style={{ fontFamily: mono, fontSize: 17, color: c.dim, marginTop: 6, textAlign: "center" }}>
      No employment verdicts · efficiency is context only · every Layer-1 point traces to an event&nbsp;ID&nbsp;&nbsp;<span style={{ color: c.green }}>(D007 / D009)</span>
    </div>
  </AbsoluteFill>
);
