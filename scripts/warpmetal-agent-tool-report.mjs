#!/usr/local/bin/node

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const manifestPath = "/usr/local/share/warpmetal/agent-tools.json";
const maximumProbeBytes = 4_096;
const allowedProbes = new Map([
  ["codex", { command: ["codex", "--version"], executable: "/usr/local/bin/codex" }],
  ["claude", { command: ["claude", "--version"], executable: "/usr/local/bin/claude" }],
  ["cursor", { command: ["agent", "--version"], executable: "/usr/local/bin/agent" }],
]);

const probeEnvironment = {
  PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  HOME: "/home/agent",
  USER: "agent",
  LANG: "C.UTF-8",
  DISABLE_AUTOUPDATER: "1",
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1",
  WARPMETAL_AGENT_TOOL_PROBE: "1",
};

function fail(message) {
  process.stderr.write(`warpmetal-agent-tool-report: ${message}\n`);
  process.exit(1);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function commandsMatch(left, right) {
  return (
    Array.isArray(left) &&
    left.length === right.length &&
    left.every((part, index) => part === right[index])
  );
}

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch {
  fail("trusted manifest is missing or invalid");
}

if (
  !isPlainObject(manifest) ||
  manifest.schema !== "warpmetal.agent-tools.v1" ||
  !Array.isArray(manifest.tools) ||
  manifest.tools.length !== allowedProbes.size
) {
  fail("trusted manifest has an unsupported shape");
}

const seen = new Set();
const observations = [];

for (const tool of manifest.tools) {
  if (!isPlainObject(tool) || typeof tool.id !== "string" || seen.has(tool.id)) {
    fail("trusted manifest contains an invalid or duplicate tool id");
  }
  seen.add(tool.id);

  const expectedProbe = allowedProbes.get(tool.id);
  if (
    expectedProbe === undefined ||
    typeof tool.version !== "string" ||
    !commandsMatch(tool.versionCommand, expectedProbe.command)
  ) {
    fail("trusted manifest contains a non-allowlisted probe");
  }

  try {
    const output = execFileSync(expectedProbe.executable, expectedProbe.command.slice(1), {
      encoding: "utf8",
      env: probeEnvironment,
      maxBuffer: maximumProbeBytes,
      stdio: ["ignore", "pipe", "pipe"],
      timeout: 5_000,
    }).trim();

    if (!output.includes(tool.version)) {
      observations.push({
        id: tool.id,
        status: "failed",
        lastError: {
          code: "version_mismatch",
          message: "tool version did not match manifest",
        },
      });
      continue;
    }

    observations.push({
      id: tool.id,
      status: "available",
      version: tool.version,
    });
  } catch {
    observations.push({
      id: tool.id,
      status: "failed",
      lastError: {
        code: "tool_probe_failed",
        message: "tool availability probe failed",
      },
    });
  }
}

if (seen.size !== allowedProbes.size) {
  fail("trusted manifest does not contain the complete tool allowlist");
}

process.stdout.write(`${JSON.stringify(observations)}\n`);
