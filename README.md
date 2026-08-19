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

The image intentionally contains only general-purpose agent prerequisites. It
runs as UID/GID 1000, contains no SSH server or container engine, and contains
no WarpMetal, payment, wallet, owner SSH, or AI-provider credentials. The
supervisor adds the runtime boundaries: read-only root filesystem, dropped
capabilities, `no-new-privileges`, user namespaces, resource limits, private
workspace storage, network isolation, and forced-command SSH access.

## Local verification

```sh
docker build --pull --tag warpmetal-agent-sandbox:test --file Containerfile .
sh test-image.sh warpmetal-agent-sandbox:test
```

GitHub Actions builds `linux/amd64` and `linux/arm64`, publishes SBOM and
provenance attestations, and signs the resulting digest with GitHub OIDC through
Sigstore Cosign.
