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

The image contains general-purpose agent prerequisites plus pinned Playwright
1.62.0 Chromium and a fixed Fontconfig font set for local headless UI testing.
`PLAYWRIGHT_BROWSERS_PATH=/ms-playwright` is shared by user-installed Node or
Python Playwright clients that use the matching browser revision. No browser
daemon or inbound listener is started.

The image runs as UID/GID 1000, contains no SSH server or container engine, and
contains no WarpMetal, payment, wallet, owner SSH, or AI-provider credentials.
The supervisor adds the runtime boundaries: read-only root filesystem, dropped
capabilities, `no-new-privileges`, user namespaces, resource limits, private
workspace storage, network isolation, and forced-command SSH access.

## Local verification

```sh
docker build --pull --platform linux/amd64 --tag warpmetal-agent-sandbox:test --file Containerfile .
sh test-image.sh warpmetal-agent-sandbox:test
```

The test launches real Chromium as UID 1000 under a read-only root filesystem,
dropped capabilities, `no-new-privileges`, and a `noexec` temporary filesystem.
It resolves an installed sans-serif font and renders synthetic mobile and
desktop screenshots. GitHub Actions runs this acceptance test on `linux/amd64`,
then builds `linux/amd64` and `linux/arm64`, publishes SBOM and provenance
attestations, and signs the resulting digest with GitHub OIDC through Sigstore
Cosign. This release does not claim live arm64 browser validation.
