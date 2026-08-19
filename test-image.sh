#!/bin/sh
set -eu

image="${1:?usage: test-image.sh IMAGE}"

docker run --rm \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user 1000:1000 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \
  "$image" \
  /bin/sh -ec '
    test "$(id -u)" = 1000
    test "$(id -g)" = 1000
    test "$HOME" = /home/agent
    test "$(getent passwd 1000 | cut -d: -f1)" = agent
    command -v bash
    command -v curl
    command -v git
    command -v node
    command -v npm
    command -v python3
    command -v ssh
    ! command -v sshd
    ! command -v docker
    ! command -v podman
  '
