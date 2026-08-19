FROM docker.io/library/node:22-bookworm-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436

LABEL org.opencontainers.image.title="WarpMetal Agent Sandbox" \
      org.opencontainers.image.description="Fixed, non-privileged userspace for WarpMetal Agent Runtime" \
      org.opencontainers.image.source="https://github.com/warpmetal/warpmetal-agent-sandbox"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      file \
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
    && rm -rf /var/lib/apt/lists/* \
    && groupmod --new-name agent node \
    && usermod --login agent --home /home/agent --move-home node \
    && install -d -o agent -g agent -m 0700 /home/agent

ENV HOME=/home/agent \
    USER=agent

USER 1000:1000
WORKDIR /home/agent
CMD ["/bin/sh"]
