# WarpMetal Agent Sandbox

This repository builds the neutral container image used by WarpMetal Agent
Runtime. It is the restricted userspace that each agent enters; it is **not**
the VPS supervisor. The supervisor is the separately signed `warpmetald`
release installed on the VPS host.

## Image

```text
ghcr.io/warpmetal/warpmetal-agent-sandbox@sha256:<digest>
```

Production pins the Linux amd64 image by digest. Mutable tags are not accepted
by the Agent Runtime API or supervisor. Other architectures are unsupported and
fail closed during the image build.

The image provides a general-purpose base with Node.js 22 and npm, Python 3,
Bash, curl, jq, Git, an SSH client, archive utilities, fonts, and Playwright
1.62.0 with headless Chromium. It does **not** preinstall or configure Codex
CLI, Claude Code, Cursor CLI, Gemini CLI, an AI-tool manifest, or a WarpMetal
tool reporter. Selecting sandbox capacity does not select, install, configure,
authenticate, update, or remove an AI CLI.

`PLAYWRIGHT_BROWSERS_PATH=/ms-playwright` exposes the bundled browser revision
to compatible user-installed Node or Python Playwright clients. No browser
daemon or inbound listener is started.

## User-installed tools

Agent Runtime mounts `/home/agent` as the persistent, writable workspace while
the container root remains read-only. The image adds
`/home/agent/.local/bin` to `PATH`; it does not create an npm configuration or
any vendor configuration. Choose an explicit home-local prefix when installing
an npm CLI:

```sh
mkdir -p "$HOME/.local"
npm install --global --prefix "$HOME/.local" <package>
```

For a vendor binary or installer, choose paths beneath `/home/agent`, such as
`$HOME/.local/bin` or `$HOME/.local/opt`. Do not rely on writing to `/usr/local`,
`/opt`, or `/etc`, and do not use `sudo` inside the sandbox.

Users own every installed tool and its version, configuration, authentication,
approval settings, updates, and removal. Authenticate only after connecting to
the intended sandbox. Tool configuration and credentials stored beneath the
persistent home remain with that workspace; WarpMetal does not request, copy,
probe, or report AI-provider credentials.

The outer Runtime container is the sandbox boundary for user-installed tools
and any child processes or subagents they launch. The image provides no nested
Bubblewrap policy, SSH server, Docker or Podman engine, or host container-engine
socket.

## Runtime boundary

The image runs as UID/GID 1000 and contains no WarpMetal, payment, wallet,
owner-SSH, or AI-provider credentials. The supervisor applies the runtime
boundaries: a read-only root filesystem, dropped capabilities,
`no-new-privileges`, user namespaces, resource limits, private workspace
storage, non-host networking, and forced-command SSH access.

## Local verification

```sh
docker build --pull --platform linux/amd64 --tag warpmetal-agent-sandbox:test --file Containerfile .
sh -n test-image.sh
sh test-image.sh warpmetal-agent-sandbox:test
```

The acceptance test runs without network access and verifies that the image has
no baked AI CLI, related artifact, vendor configuration, or credential. As UID
1000, it installs a local test CLI with an explicit home-local npm prefix and
invokes it through `PATH` while the root filesystem remains read-only. It also
launches real Chromium, resolves an installed sans-serif font, and renders
synthetic mobile and desktop screenshots under dropped capabilities,
`no-new-privileges`, and a `noexec` temporary filesystem.

GitHub Actions runs the acceptance test on `linux/amd64`, then publishes the
amd64 image with SBOM and provenance attestations and signs its digest with
GitHub OIDC through Sigstore Cosign.
