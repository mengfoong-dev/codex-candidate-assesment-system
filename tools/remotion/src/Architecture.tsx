import { AbsoluteFill } from "remotion";
import { c, font, mono } from "./theme";

type Status = "shipped" | "partial" | "planned";
const statusColor: Record<Status, string> = { shipped: c.green, partial: c.amber, planned: c.dim };

const Box: React.FC<{
  title: string; sub?: string; status?: Status; accent?: string; w?: number; big?: boolean;
}> = ({ title, sub, status = "shipped", accent = c.blue, w = 300, big }) => (
  <div
    style={{
      width: w, background: c.panel, borderRadius: 14, padding: big ? "22px 22px" : "16px 18px",
      border: `2px ${status === "planned" ? "dashed" : "solid"} ${status === "planned" ? c.border : accent}`,
      boxShadow: status === "planned" ? "none" : `0 0 0 1px ${accent}22, 0 10px 26px #0006`,
    }}
  >
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10 }}>
      <span style={{ fontFamily: font, fontSize: big ? 30 : 24, fontWeight: 700, color: c.text }}>{title}</span>
      <span style={{ fontFamily: mono, fontSize: 13, color: statusColor[status], border: `1px solid ${statusColor[status]}66`, borderRadius: 999, padding: "2px 9px", whiteSpace: "nowrap" }}>
        {status.toUpperCase()}
      </span>
    </div>
    {sub && <div style={{ fontFamily: mono, fontSize: 16, color: c.dim, marginTop: 8, lineHeight: 1.5 }}>{sub}</div>}
  </div>
);

const Arrow: React.FC<{ label?: string; dir?: "right" | "down" }> = ({ label, dir = "right" }) => (
  <div style={{ display: "flex", flexDirection: dir === "right" ? "row" : "column", alignItems: "center", justifyContent: "center", color: c.dim, padding: "0 6px" }}>
    {label && <span style={{ fontFamily: mono, fontSize: 14, color: c.dim, marginBottom: dir === "down" ? 2 : 0 }}>{label}</span>}
    <span style={{ fontSize: 30, color: c.border }}>{dir === "right" ? "→" : "↓"}</span>
  </div>
);

const Lane: React.FC<{ tag: string; tagColor: string; children: React.ReactNode }> = ({ tag, tagColor, children }) => (
  <div style={{ background: `${tagColor}0D`, border: `1px solid ${tagColor}33`, borderRadius: 20, padding: "22px 26px" }}>
    <div style={{ fontFamily: mono, fontSize: 17, color: tagColor, letterSpacing: 1.5, marginBottom: 18 }}>{tag}</div>
    <div style={{ display: "flex", alignItems: "center", justifyContent: "flex-start", flexWrap: "nowrap" }}>{children}</div>
  </div>
);

export const Architecture: React.FC = () => (
  <AbsoluteFill style={{ background: `radial-gradient(120% 120% at 50% -10%, ${c.bgTop} 0%, ${c.bg} 60%)`, fontFamily: font, padding: 56, justifyContent: "center", gap: 26 }}>
    <div>
      <div style={{ fontSize: 46, fontWeight: 800, color: c.text, letterSpacing: -1 }}>System Architecture</div>
      <div style={{ fontSize: 22, color: c.dim, marginTop: 6 }}>One scenario — <span style={{ color: c.amber }}>Homepage Latency Spike</span> — behind two runtimes.</div>
    </div>

    <Lane tag="CANDIDATE RUNTIME · GODOT 4.7.1 · SHIPPED" tagColor={c.green}>
      <Box title="Candidate" sub="WASD · click · hotkeys" accent={c.blue} w={200} />
      <Arrow label="plays" />
      <Box title="Incident Room" sub="Godot 4.7.1 · GL Compatibility · no candidate code executes" accent={c.green} w={330} big />
      <Arrow label="sits at" />
      <Box title="Desk PC workspace" sub="Investigate · Codex · Files & Tests · Submit fix" accent={c.green} w={320} />
      <Arrow label="append" />
      <Box title="Local evidence" sub="events.jsonl + unscored summary · user:// (offline)" accent={c.green} w={300} />
    </Lane>

    <div style={{ fontFamily: mono, fontSize: 16, color: c.dim, textAlign: "center", marginTop: -8 }}>
      live side-channels (not offline): Godot → <span style={{ color: c.blue }}>Codex assistant-proxy</span> · <span style={{ color: c.blue }}>Sam senior-proxy</span> (apps/senior-proxy · Node → Cohere) · <span style={{ color: c.amber }}>backend grader</span> (optional live score overlay)
    </div>

    <Lane tag="WEB MVP BACKEND · FastAPI · SHIPPED" tagColor={c.violet}>
      <Box title="Frontend" sub="builds against /docs (OpenAPI)" accent={c.blue} w={220} />
      <Arrow label="REST + SSE" />
      <Box title="FastAPI" sub="6 routers /api · event-sourced · CORS · no auth (MVP)" accent={c.violet} w={320} big />
      <Arrow label="asyncio.gather" />
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        <Box title="Simulation Engine" sub="Cohere Command A+ · SSE · read/write file tools" accent={c.blue} w={330} />
        <Box title="Evaluation Engine" sub="3-layer scoring at submit · Proof Replay report" accent={c.green} status="shipped" w={330} />
      </div>
      <Arrow label="persist" />
      <Box title="SQLite · SQLAlchemy async" sub="scenarios · sessions · events · session_files · scoring_results" accent={c.violet} w={320} />
    </Lane>

    <div style={{ display: "flex", gap: 22, fontFamily: mono, fontSize: 16, color: c.dim, marginTop: 4 }}>
      <span><span style={{ color: c.green }}>■</span> shipped</span>
      <span><span style={{ color: c.amber }}>■</span> partial</span>
      <span><span style={{ color: c.dim }}>▢</span> planned / deferred</span>
    </div>
  </AbsoluteFill>
);
