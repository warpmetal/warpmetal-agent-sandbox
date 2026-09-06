FROM docker.io/library/node:22-bookworm-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436

LABEL org.opencontainers.image.title="WarpMetal Agent Sandbox" \
      org.opencontainers.image.description="Fixed, non-privileged userspace for WarpMetal Agent Runtime" \
      org.opencontainers.image.source="https://github.com/warpmetal/warpmetal-agent-sandbox"

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PLAYWRIGHT_VERSION=1.62.0 \
    NODE_PATH=/usr/local/lib/node_modules \
    DISABLE_AUTOUPDATER=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

ARG TARGETARCH
ARG CURSOR_AGENT_VERSION=2026.09.02-c22c1a3
ARG CURSOR_AGENT_SHA256=b73b59854762535c0fc20d7ccc51c3b5a356a851491088d60a362be48750f53c

COPY package.json package-lock.json /opt/warpmetal-agent-tools/
COPY agent-tools.json /usr/local/share/warpmetal/agent-tools.json
COPY scripts/cursor-agent-wrapper.sh /usr/local/lib/warpmetal/cursor-agent-wrapper
COPY scripts/warpmetal-agent-tool-report.mjs /usr/local/bin/warpmetal-agent-tool-report

RUN case "$TARGETARCH" in amd64) ;; *) echo "unsupported image architecture: $TARGETARCH" >&2; exit 1 ;; esac \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      file \
      fontconfig \
      fonts-dejavu-core \
      fonts-liberation \
      fonts-noto-color-emoji \
      git \
      gzip \
      jq \
      less \
      openssh-client \
      passwd \
      python3 \
      python3-pip \
      python3-venv \
      tar \
      unzip \
      xz-utils \
      zip \
    && cd /opt/warpmetal-agent-tools \
    && npm ci --omit=dev --no-audit --no-fund \
    && ln -s /opt/warpmetal-agent-tools/node_modules/.bin/codex /usr/local/bin/codex \
    && ln -s /opt/warpmetal-agent-tools/node_modules/.bin/claude /usr/local/bin/claude \
    && cursor_archive=/tmp/cursor-agent.tar.gz \
    && curl --fail --location --silent --show-error \
      --output "$cursor_archive" \
      "https://downloads.cursor.com/lab/${CURSOR_AGENT_VERSION}/linux/x64/agent-cli-package.tar.gz" \
    && echo "${CURSOR_AGENT_SHA256}  ${cursor_archive}" | sha256sum --check --strict \
    && install -d -o root -g root -m 0755 /usr/local/lib/warpmetal/cursor-agent \
    && tar --extract --gzip --file "$cursor_archive" \
      --directory /usr/local/lib/warpmetal/cursor-agent --strip-components=1 \
      --no-same-owner --no-same-permissions \
    && chown --recursive root:root /usr/local/lib/warpmetal/cursor-agent \
    && test -x /usr/local/lib/warpmetal/cursor-agent/cursor-agent \
    && ln -s /usr/local/lib/warpmetal/cursor-agent-wrapper /usr/local/bin/agent \
    && ln -s /usr/local/lib/warpmetal/cursor-agent-wrapper /usr/local/bin/cursor-agent \
    && chmod 0555 \
      /usr/local/bin/warpmetal-agent-tool-report \
      /usr/local/lib/warpmetal/cursor-agent-wrapper \
    && chmod 0444 /usr/local/share/warpmetal/agent-tools.json \
    && chmod -R a-w /opt/warpmetal-agent-tools /usr/local/lib/warpmetal/cursor-agent \
    && npm install --global "playwright@${PLAYWRIGHT_VERSION}" \
    && playwright install --with-deps --only-shell chromium \
    && chmod -R a+rX /ms-playwright /usr/local/lib/node_modules/playwright* \
    && npm cache clean --force \
    && command rm --force "$cursor_archive" \
    && rm -rf /var/lib/apt/lists/* \
    && groupmod --new-name agent node \
    && usermod --login agent --home /home/agent --move-home node \
    && install -d -o agent -g agent -m 0700 /home/agent

ENV HOME=/home/agent \
    USER=agent

USER 1000:1000
WORKDIR /home/agent
CMD ["/bin/sh"]
