"use strict";

const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");

const manifestPath = "/usr/local/share/warpmetal/agent-tools.json";
const expected = [
  { id: "codex", version: "0.153.4" },
  { id: "claude", version: "2.1.263" },
  { id: "cursor", version: "2026.09.02-c22c1a3" },
];

assert.equal(process.env.DISABLE_AUTOUPDATER, "1");
assert.equal(process.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, "1");
const initialHomeEntries = fs.readdirSync(process.env.HOME).sort();
for (const entry of initialHomeEntries) {
  assert.ok(
    !/(auth|credential|password|private|secret|token)/i.test(entry),
    `sandbox home contains credential-like material: ${entry}`,
  );
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
assert.equal(manifest.schema, "warpmetal.agent-tools.v1");
assert.deepEqual(
  manifest.tools.map(({ id, version }) => ({ id, version })),
  expected,
);

const reportText = execFileSync("/usr/local/bin/warpmetal-agent-tool-report", [], {
  encoding: "utf8",
  env: { ...process.env, PATH: "/tmp" },
  maxBuffer: 4_096,
  stdio: ["ignore", "pipe", "pipe"],
  timeout: 20_000,
});
assert.ok(Buffer.byteLength(reportText) < 1_024);

const report = JSON.parse(reportText);
assert.deepEqual(
  report,
  expected.map(({ id, version }) => ({ id, status: "available", version })),
);

assert.deepEqual(fs.readdirSync(process.env.HOME).sort(), initialHomeEntries);
process.stdout.write(`${JSON.stringify(report)}\n`);
