#!/bin/sh
set -eu

image="${1:?usage: test-image.sh IMAGE}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

docker run --rm \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user 1000:1000 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --mount "type=bind,src=${script_dir}/test-browser.cjs,dst=/opt/warpmetal/test-browser.cjs,readonly" \
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
    command -v playwright
    command -v python3
    command -v ssh
    test "$PLAYWRIGHT_VERSION" = 1.62.0
    test "$PLAYWRIGHT_BROWSERS_PATH" = /ms-playwright
    font_file=$(fc-match --format "%{file}" sans-serif)
    test -n "$font_file"
    test -r "$font_file"
    ! command -v sshd
    ! command -v docker
    ! command -v podman
    node /opt/warpmetal/test-browser.cjs
  '
