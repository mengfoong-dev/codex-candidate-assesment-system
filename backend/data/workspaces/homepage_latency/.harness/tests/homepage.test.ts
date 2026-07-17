// @ts-nocheck — this is a runtime template, type-resolved only inside a materialized sandbox
// (where `vitest` and a sibling `src/` exist). It is run by esbuild/vitest, never typechecked in
// place, so in-repo tsc cannot resolve its imports; @ts-nocheck silences that false positive.
// Real grading tests for the homepage_latency sandbox (run by `vitest run` against the candidate/
// AI-edited files). HIDDEN from the workspace manifest — the candidate never sees this file.
//
// Test names are EXACTLY the backend test ids so `vitest run -t <test_id>` selects one of them.
// The p95_latency check is deterministic (concurrency count under a fixed delay), not timing-based:
// sequential awaits can never overlap (max in-flight = 1) while Promise.all fires all three (= 3).
import { test, expect, vi, afterEach } from "vitest";
import { renderHomepageForUser } from "../src/homepage_orchestrator";

const AUTH_URL = "/internal/auth/session";
const LOOKUP_URLS = ["/internal/profile", "/internal/recommendations", "/internal/notices"];
const isLookup = (url: string) => LOOKUP_URLS.some((u) => url.startsWith(u));

afterEach(() => vi.unstubAllGlobals());

test("correctness_regression", async () => {
  // Records call order so we can assert auth ran before the data lookups and all parts came back.
  const calls: string[] = [];
  vi.stubGlobal("fetch", async (input: unknown) => {
    const url = String(input);
    calls.push(url);
    return { ok: true, json: async () => ({ url }) } as unknown as Response;
  });

  const result = (await renderHomepageForUser("u1")) as {
    profile: unknown;
    recommendations: unknown;
    notices: unknown;
  };

  expect(calls[0]).toContain(AUTH_URL); // authentication happens first
  expect(calls.findIndex(isLookup)).toBeGreaterThan(0); // ...before any data lookup
  expect(result.profile).toBeDefined();
  expect(result.recommendations).toBeDefined();
  expect(result.notices).toBeDefined();
});

test("p95_latency", async () => {
  // Count concurrent in-flight lookups. The 25ms delay guarantees overlap is observable: with
  // Promise.all all three are in flight at once (max = 3); awaited one-by-one it is always 1.
  let inFlight = 0;
  let maxInFlight = 0;
  vi.stubGlobal("fetch", async (input: unknown) => {
    const url = String(input);
    if (isLookup(url)) {
      inFlight++;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise((resolve) => setTimeout(resolve, 25));
      inFlight--;
    }
    return { ok: true, json: async () => ({ url }) } as unknown as Response;
  });

  await renderHomepageForUser("u1");

  expect(maxInFlight).toBeGreaterThanOrEqual(2); // sequential => 1 (fail); parallelized => 3 (pass)
});
