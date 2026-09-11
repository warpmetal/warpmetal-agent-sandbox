FROM docker.io/library/node:22-bookworm-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436

LABEL org.opencontainers.image.title="WarpMetal Agent Sandbox" \
      org.opencontainers.image.description="Fixed, non-privileged userspace for WarpMetal Agent Runtime" \
      org.opencontainers.image.source="https://github.com/warpmetal/warpmetal-agent-sandbox"

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PLAYWRIGHT_VERSION=1.62.0 \
    NODE_PATH=/usr/local/lib/node_modules

ARG TARGETARCH

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
    && npm install --global "playwright@${PLAYWRIGHT_VERSION}" \
    && playwright install --with-deps --only-shell chromium \
    && chmod -R a+rX /ms-playwright /usr/local/lib/node_modules/playwright* \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/* \
    && groupmod --new-name agent node \
    && usermod --login agent --home /home/agent --move-home node \
    && install -d -o agent -g agent -m 0700 /home/agent

ENV HOME=/home/agent \
    USER=agent \
    PATH="/home/agent/.local/bin:${PATH}"

USER 1000:1000
WORKDIR /home/agent
CMD ["/bin/sh"]
