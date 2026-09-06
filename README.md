# WarpMetal Agent Sandbox

This repository builds the fixed container image used by WarpMetal Agent
Runtime. It is the restricted userspace that each agent enters; it is **not**
the VPS supervisor. The supervisor is the separately signed `warpmetald`
release installed on the VPS host.

## Image

```text
ghcr.io/warpmetal/warpmetal-agent-sandbox@sha256:<digest>
```

Production always pins the multi-architecture image by digest. Mutable tags are
never accepted by the Agent Runtime API or supervisor.

The image contains general-purpose agent prerequisites, all three supported AI
CLIs, pinned Playwright 1.62.0 Chromium, and a fixed Fontconfig font set for
local headless UI testing. The CLI versions are fixed at build time:

- Codex CLI `0.153.4`
- Claude Code `2.1.263`
- Cursor CLI `2026.09.02-c22c1a3`

The npm packages are installed only through the committed lockfile and its
registry integrity values. The official Cursor Linux archive is selected by
the target architecture and verified against a committed SHA-256 value before
extraction. The image build stops on any integrity mismatch. CLI auto-update is
disabled where the tool supports it; the installed files are root-owned and
not writable by the sandbox user.

`PLAYWRIGHT_BROWSERS_PATH=/ms-playwright` is shared by user-installed Node or
Python Playwright clients that use the matching browser revision. No browser
daemon or inbound listener is started.

## Agent tool contract

`/usr/local/share/warpmetal/agent-tools.json` is the immutable
`warpmetal.agent-tools.v1` manifest. It contains exactly the `codex`, `claude`,
and `cursor` tools, including their pinned version, executable, version probe,
and interactive login guidance. It contains no download URL or credential.

The login commands are guidance for a human already connected to the sandbox:

```sh
codex login --device-auth
claude
agent login
```

No account login runs during image build or sandbox creation. Each CLI stores
the user's later authentication state in that sandbox's persistent home or
workspace; WarpMetal does not bake, request, or report those credentials.

`/usr/local/bin/warpmetal-agent-tool-report` reads only the baked manifest,
executes only the three fixed local version probes, and emits a bounded JSON
array in manifest order. Each observation has an `id`, an `available` or
`failed` status, and either the exact version or a generic bounded error. It
does not log in, update, install, or download software and does not include
command output in failures.

The image runs as UID/GID 1000, contains no SSH server or container engine, and
contains no WarpMetal, payment, wallet, owner SSH, or AI-provider credentials.
The supervisor adds the runtime boundaries: read-only root filesystem, dropped
capabilities, `no-new-privileges`, user namespaces, resource limits, private
workspace storage, network isolation, and forced-command SSH access.

## Local verification

```sh
docker build --pull --platform linux/amd64 --tag warpmetal-agent-sandbox:test --file Containerfile .
sh test-image.sh warpmetal-agent-sandbox:test

docker buildx build --pull --platform linux/arm64 --load --tag warpmetal-agent-sandbox:test-arm64 --file Containerfile .
sh test-image.sh warpmetal-agent-sandbox:test-arm64
```

The test runs with no network, launches real Chromium, and verifies every CLI
through the manifest reporter as UID 1000 under a read-only root filesystem,
dropped capabilities, `no-new-privileges`, and a `noexec` temporary filesystem.
It also resolves an installed sans-serif font and renders synthetic mobile and
desktop screenshots. GitHub Actions runs the complete acceptance test on
`linux/amd64` and `linux/arm64`, then publishes one multi-architecture image
with SBOM and provenance attestations and signs its digest with GitHub OIDC
through Sigstore Cosign.
