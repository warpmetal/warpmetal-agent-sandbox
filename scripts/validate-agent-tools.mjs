#!/usr/bin/env node

import { readFileSync } from "node:fs";

const expectedPackages = new Map([
  [
    "@anthropic-ai/claude-code",
    {
      version: "2.1.263",
      integrity:
        "sha512-kvvBK6/69iTRYnq0TKVyxVZs1CxYCJGojshQSP+2qaDb66A2xtI4zbCuqkZUWLkFGmHSRqhFf/ATpzH2UNKcwg==",
    },
  ],
  [
    "@openai/codex",
    {
      version: "0.153.4",
      integrity:
        "sha512-wbHDmit7S/YvBGVX1DQmk13xtWblZ2cApeJ/pB7xDZ10Cna+DZc5ij7f0F4OxdsXN4FW1oLT48OpogUI1+8Y2w==",
    },
  ],
]);

const expectedTools = [
  {
    id: "codex",
    displayName: "Codex CLI",
    version: "0.153.4",
    executable: "codex",
    versionCommand: ["codex", "--version"],
    loginCommand: ["codex", "login", "--device-auth"],
    loginKind: "device-code",
  },
  {
    id: "claude",
    displayName: "Claude Code",
    version: "2.1.263",
    executable: "claude",
    versionCommand: ["claude", "--version"],
    loginCommand: ["claude"],
    loginKind: "interactive",
  },
  {
    id: "cursor",
    displayName: "Cursor CLI",
    version: "2026.09.02-c22c1a3",
    executable: "agent",
    versionCommand: ["agent", "--version"],
    loginCommand: ["agent", "login"],
    loginKind: "browser",
  },
];

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const packageJson = readJson("package.json");
const packageLock = readJson("package-lock.json");
const manifest = readJson("agent-tools.json");

assert(packageJson.private === true, "package.json must remain private");
assert(
  JSON.stringify(packageJson.dependencies) ===
    JSON.stringify(Object.fromEntries([...expectedPackages].map(([name, value]) => [name, value.version]))),
  "package.json dependencies must contain only the exact frozen CLI versions",
);
assert(packageLock.lockfileVersion === 3, "package-lock.json must use lockfileVersion 3");

for (const [name, expected] of expectedPackages) {
  const entry = packageLock.packages[`node_modules/${name}`];
  assert(entry?.version === expected.version, `${name} lockfile version mismatch`);
  assert(entry?.integrity === expected.integrity, `${name} lockfile integrity mismatch`);
}

for (const architecture of ["x64", "arm64"]) {
  const codex = packageLock.packages[`node_modules/@openai/codex-linux-${architecture}`];
  const claude = packageLock.packages[`node_modules/@anthropic-ai/claude-code-linux-${architecture}`];
  assert(codex?.version === "0.153.4-linux-" + architecture, `Codex ${architecture} package is not locked`);
  assert(claude?.version === "2.1.263", `Claude ${architecture} package is not locked`);
  assert(typeof codex.integrity === "string", `Codex ${architecture} package lacks integrity`);
  assert(typeof claude.integrity === "string", `Claude ${architecture} package lacks integrity`);
}

assert(
  JSON.stringify(manifest) ===
    JSON.stringify({ schema: "warpmetal.agent-tools.v1", tools: expectedTools }),
  "agent-tools.json must exactly match warpmetal.agent-tools.v1",
);

const serializedManifest = JSON.stringify(manifest).toLowerCase();
for (const forbidden of [
  "api-key",
  "apikey",
  "authorization",
  "credential",
  "password",
  "private-key",
  "secret",
  "token",
  "http://",
  "https://",
]) {
  assert(!serializedManifest.includes(forbidden), `manifest contains forbidden text: ${forbidden}`);
}

process.stdout.write(
  `${JSON.stringify({ schema: manifest.schema, tools: manifest.tools.map(({ id, version }) => ({ id, version })) })}\n`,
);
