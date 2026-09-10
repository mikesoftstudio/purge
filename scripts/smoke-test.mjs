#!/usr/bin/env node
/**
 * Smoke test for the Purge web app.
 *
 * Verifies the API contract end-to-end against a running server (read-only:
 * scans are non-destructive, nothing is cleaned).
 *
 *   npm start   # in one terminal
 *   node scripts/smoke-test.mjs   # in another
 */

const BASE = process.env.CLEANDEVICE_URL ?? "http://localhost:3000";

async function get(path) {
  const res = await fetch(`${BASE}${path}`);
  const body = await res.json();
  return { status: res.status, body };
}

function assert(cond, label) {
  if (!cond) throw new Error(`FAIL: ${label}`);
  console.log(`  ok — ${label}`);
}

async function main() {
  console.log(`Purge smoke test against ${BASE}\n`);

  // 1. Disk info
  const disk = await get("/api/disk");
  assert(disk.status === 200, "GET /api/disk → 200");
  assert(
    disk.body.freeBytes > 0 && disk.body.home,
    `disk readable (${disk.body.freeBytes} free on ${disk.body.home})`
  );

  // 2. Tool detection
  const tools = await get("/api/tools");
  assert(tools.status === 200, "GET /api/tools → 200");
  assert(["macos", "linux", "windows", "android", "ios"].includes(tools.body.platform), `platform detected (${tools.body.platformLabel})`);
  assert(Array.isArray(tools.body.tools), "tool list present");

  // 3. Scan (read-only)
  const t0 = Date.now();
  const scan = await get("/api/scan");
  const elapsed = Date.now() - t0;
  assert(scan.status === 200, "GET /api/scan → 200");
  assert(Array.isArray(scan.body.results) && scan.body.results.length > 0, `scan returned ${scan.body.results.length} categories`);
  assert(
    scan.body.results.every((r) => typeof r.totalSizeBytes === "number" && r.totalSizeBytes >= 0),
    "all category sizes are non-negative numbers"
  );
  console.log(`  ok — scan completed in ${(elapsed / 1000).toFixed(2)}s, ${(scan.body.totalReclaimableBytes / 1e9).toFixed(2)} GB reclaimable`);

  // 4. Clean endpoint rejects bad input (no side effects)
  const bad = await fetch(`${BASE}/api/clean`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ categories: ["not-a-real-category"] }),
  });
  assert(bad.status === 400, "POST /api/clean unknown category → 400");
  const empty = await fetch(`${BASE}/api/clean`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ categories: [] }),
  });
  assert(empty.status === 400, "POST /api/clean empty categories → 400");

  // 5. Cancel rejects unknown job
  const cancel = await fetch(`${BASE}/api/cancel`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jobId: "bogus" }),
  });
  assert(cancel.status === 404, "POST /api/cancel unknown job → 404");

  console.log("\nAll checks passed.");
}

main().catch((err) => {
  console.error(`\n${err.message}`);
  process.exit(1);
});