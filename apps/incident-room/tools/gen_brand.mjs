// Generates VibeProof brand assets (logo, boot splash, title background) via OpenAI gpt-image-1.
// Reads OPENAI_API_KEY from ../../senior-proxy/.env. Never prints the key.
// Usage:  node gen_brand.mjs [logo|splash|bg|all]   (default: all)
// ponytail: one-shot brand generator; keep for reproducible assets, delete if the brand freezes.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { createRequire } from "node:module";

// sharp lives in the scratchpad (not the repo); point SHARP_PATH at it. Only the logo needs it.
const require = createRequire(import.meta.url);

const MODEL = process.env.IMAGE_MODEL ?? "gpt-image-2";
const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(HERE, "../assets/ui/brand");
const HERO = resolve(HERE, "../assets/ui/entry_hero.png");
const ENV = resolve(HERE, "../../senior-proxy/.env");

function apiKey() {
  const line = readFileSync(ENV, "utf8").split(/\r?\n/).find((l) => l.startsWith("OPENAI_API_KEY="));
  const key = line?.slice("OPENAI_API_KEY=".length).trim();
  if (!key) throw new Error(`OPENAI_API_KEY not set in ${ENV}`);
  return key;
}

// Shared brand language so every asset reads as one system.
const PALETTE =
  "Color system: deep navy near-black background (#0E1220), warm amber glow accent (#F29E38), " +
  "cool cyan rim light and thin data-grid lines (#3FA9C9), and a single red alert-chart accent (#E2504B). " +
  "Mood: cinematic night-shift incident war-room, calm-but-urgent, premium developer-tooling brand.";

async function generate(key, prompt, { size }) {
  const res = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: MODEL, prompt, size, quality: "high", output_format: "png", n: 1 }),
  });
  return unpack(res);
}

// gpt-image-2 has no transparent mode, so we render the logo on a flat magenta key and cut it out.
// Magenta (255,0,255) shares no channel signature with the logo's amber/cyan/red/white.
async function keyOutMagenta(buf) {
  const sharp = require(process.env.SHARP_PATH || "sharp");
  const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    if (r > 150 && b > 150 && g < 110) data[i + 3] = 0; // magenta -> transparent
  }
  return sharp(data, { raw: { width: info.width, height: info.height, channels: 4 } })
    .trim({ threshold: 1 }) // crop the empty margins
    .png()
    .toBuffer();
}

async function edit(key, refPath, prompt, { size }) {
  const form = new FormData();
  form.append("model", MODEL);
  form.append("image", new Blob([readFileSync(refPath)], { type: "image/png" }), "ref.png");
  form.append("prompt", prompt);
  form.append("size", size);
  form.append("quality", "high");
  const res = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}` },
    body: form,
  });
  return unpack(res);
}

async function unpack(res) {
  const json = await res.json();
  if (!res.ok) throw new Error(`OpenAI ${res.status}: ${JSON.stringify(json.error ?? json)}`);
  return Buffer.from(json.data[0].b64_json, "base64");
}

const ASSETS = {
  logo: async (key) =>
    keyOutMagenta(
      await generate(
        key,
        `A flat vector brand logo centered on a completely solid, uniform, flat PURE MAGENTA background (RGB 255,0,255 / #FF00FF filling every ` +
          `pixel edge to edge). The magenta must be perfectly flat: NO gradient, NO glow, NO vignette, NO shading, NO texture on the background. ` +
          `The logo itself is FLAT DESIGN: solid clean fills, sharp crisp vector edges, no glow, no bloom, no drop shadow. ` +
          `Layout, left to right on one baseline: (1) a compact geometric emblem = an amber shield outline (#F29E38) containing a rising cyan line-chart (#3FA9C9) ` +
          `that ends in an upward arrow/checkmark, with one small solid red dot (#E2504B) at the chart peak; ` +
          `(2) the wordmark "VibeProof" in a bold modern geometric sans-serif, "Vibe" solid cyan #3FA9C9, "Proof" solid amber #F29E38, high legibility. ` +
          `Do not use magenta/pink anywhere in the logo artwork itself. Spell it exactly "VibeProof", one word, correct clear letters.`,
        { size: "1024x1024" },
      ),
    ),
  splash: (key) =>
    generate(
      key,
      `App boot-splash screen for "VibeProof". Centered brand emblem: a geometric mark fusing a checkmark/shield with a rising ` +
        `signal waveform in amber-to-cyan gradient, with the wordmark "VibeProof" beneath it in a clean geometric sans-serif ` +
        `(soft white "Vibe", amber "Proof"), and a small subdued tagline line "INCIDENT ROOM" in cyan letter-spaced caps under that. ` +
        `Set on a deep navy near-black background with a soft radial amber glow behind the emblem and faint cyan grid lines fading at the edges. ` +
        `Balanced, premium, minimal. Spell "VibeProof" exactly. ${PALETTE}`,
      { size: "1024x1024", transparent: false },
    ),
  bg: (key) =>
    edit(
      key,
      HERO,
      `Reimagine this scene as a title-screen background for the "VibeProof" incident-room game, keeping the same art direction, ` +
        `camera angle, tilt-shift isometric night-office look and the exact same color grading. A single warm amber-lit desk cluster ` +
        `with curved monitors showing red latency spike charts sits in the lower-right third; the left ~40% stays very dark and ` +
        `uncluttered (empty negative space for overlaid text). Cool cyan rim light and faint blue data-grid lines across the floor, ` +
        `city lights blurred in the background windows. Cinematic, moody, high detail, no text, no logos, no watermarks. ${PALETTE}`,
      { size: "1536x1024" },
    ),
};

const which = (process.argv[2] ?? "all").toLowerCase();
const jobs = which === "all" ? Object.keys(ASSETS) : [which];
mkdirSync(OUT, { recursive: true });
const key = apiKey();
for (const name of jobs) {
  if (!ASSETS[name]) throw new Error(`unknown asset "${name}" (logo|splash|bg|all)`);
  process.stdout.write(`generating ${name}... `);
  const buf = await ASSETS[name](key);
  const path = resolve(OUT, `${name}.png`);
  writeFileSync(path, buf);
  console.log(`ok -> ${path} (${(buf.length / 1024).toFixed(0)} KB)`);
}
