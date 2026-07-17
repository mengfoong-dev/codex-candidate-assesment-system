import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { unlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const MAX_SOURCE_BYTES = 30_000;
const generatedPath = join(tmpdir(), `vibeproof-candidate-${randomUUID()}.mjs`);

async function readCandidateSource() {
  const chunks = [];
  let size = 0;
  for await (const chunk of process.stdin) {
    size += chunk.length;
    if (size > MAX_SOURCE_BYTES) throw new Error("Candidate source exceeds 30 KB");
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}

function wrapCandidate(source) {
  return `
export async function loadWatchPage(deps) {
  const {
    userId,
    videoId,
    requireAuthenticatedUser,
    getVideoDetails,
    getRecommendations,
    getComments,
    renderWatchPage,
  } = deps;
${source}
}
`;
}

function dependencyHarness() {
  const events = [];
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const dependency = (name, value, delay) => async () => {
    events.push(`${name}:start`);
    await wait(delay);
    events.push(`${name}:end`);
    return value;
  };
  return {
    events,
    deps: {
      userId: "candidate-1",
      videoId: "video-42",
      requireAuthenticatedUser: dependency("auth", true, 5),
      getVideoDetails: dependency("details", { title: "Latency investigation" }, 35),
      getRecommendations: dependency("recommendations", ["related-1"], 35),
      getComments: dependency("comments", ["useful comment"], 35),
      renderWatchPage: (value) => value,
    },
  };
}

function result(status, tests, startedAt, error = "") {
  const passed = tests.filter((test) => test.status === "passed").length;
  const failed = tests.filter((test) => test.status === "failed").length;
  return {
    status,
    exit_code: status === "passed" ? 0 : 1,
    duration_ms: Date.now() - startedAt,
    passed,
    failed,
    tests,
    error,
  };
}

async function main() {
  const startedAt = Date.now();
  const tests = [];
  const record = (name, fn) => {
    try {
      fn();
      tests.push({ name, status: "passed" });
    } catch (error) {
      tests.push({ name, status: "failed", message: error.message });
    }
  };

  try {
    const source = await readCandidateSource();
    if (!source.trim()) throw new Error("Candidate source is empty");
    await writeFile(generatedPath, wrapCandidate(source), "utf8");
    const moduleUrl = `${pathToFileURL(generatedPath).href}?v=${Date.now()}`;
    const candidate = await import(moduleUrl);
    const harness = dependencyHarness();
    const output = await candidate.loadWatchPage(harness.deps);
    const { events } = harness;

    record("authentication completes before protected requests", () => {
      const authEnd = events.indexOf("auth:end");
      for (const name of ["details", "recommendations", "comments"]) {
        assert.ok(authEnd >= 0 && events.indexOf(`${name}:start`) > authEnd);
      }
    });
    record("all required data is returned in the correct fields", () => {
      assert.deepEqual(output, {
        details: { title: "Latency investigation" },
        recommendations: ["related-1"],
        comments: ["useful comment"],
      });
    });
    record("independent requests execute concurrently", () => {
      const firstEnd = Math.min(
        events.indexOf("details:end"),
        events.indexOf("recommendations:end"),
        events.indexOf("comments:end"),
      );
      for (const name of ["details", "recommendations", "comments"]) {
        assert.ok(events.indexOf(`${name}:start`) >= 0);
        assert.ok(events.indexOf(`${name}:start`) < firstEnd);
      }
    });

    const failed = tests.some((test) => test.status === "failed");
    console.log(JSON.stringify(result(failed ? "failed" : "passed", tests, startedAt)));
    process.exitCode = failed ? 1 : 0;
  } catch (error) {
    console.log(JSON.stringify(result("failed", tests, startedAt, error.message)));
    process.exitCode = 1;
  } finally {
    await unlink(generatedPath).catch(() => {});
  }
}

await main();
