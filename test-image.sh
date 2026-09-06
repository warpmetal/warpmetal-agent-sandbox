#!/bin/sh
set -eu

image="${1:?usage: test-image.sh IMAGE}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

docker run --rm \
  --network none \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user 1000:1000 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --mount "type=bind,src=${script_dir}/test-browser.cjs,dst=/opt/warpmetal/test-browser.cjs,readonly" \
  --mount "type=bind,src=${script_dir}/test-tools.cjs,dst=/opt/warpmetal/test-tools.cjs,readonly" \
  "$image" \
  /bin/sh -ec '
    assert_root_owned() {
      test "$(stat -Lc "%u:%g" -- "$1")" = 0:0
    }
    assert_root_owned_tree() {
      test -z "$(find "$1" -xdev \( ! -uid 0 -o ! -gid 0 \) -print -quit)"
    }
    test "$(id -u)" = 1000
    test "$(id -g)" = 1000
    test "$HOME" = /home/agent
    test "$(getent passwd 1000 | cut -d: -f1)" = agent
    command -v bash
    command -v agent
    command -v claude
    command -v codex
    command -v curl
    command -v cursor-agent
    command -v git
    command -v node
    command -v npm
    command -v playwright
    command -v python3
    command -v ssh
    command -v warpmetal-agent-tool-report
    test "$PLAYWRIGHT_VERSION" = 1.62.0
    test "$PLAYWRIGHT_BROWSERS_PATH" = /ms-playwright
    test "$DISABLE_AUTOUPDATER" = 1
    test "$CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" = 1
    assert_root_owned /usr/local/share/warpmetal/agent-tools.json
    assert_root_owned /usr/local/bin/warpmetal-agent-tool-report
    assert_root_owned /usr/local/lib/warpmetal/cursor-agent-wrapper
    assert_root_owned /usr/local/lib/warpmetal/cursor-agent/cursor-agent
    assert_root_owned /opt/warpmetal-agent-tools/node_modules/@openai/codex
    assert_root_owned /opt/warpmetal-agent-tools/node_modules/@anthropic-ai/claude-code
    assert_root_owned_tree /usr/local/lib/warpmetal/cursor-agent
    assert_root_owned_tree /opt/warpmetal-agent-tools/node_modules/@openai
    assert_root_owned_tree /opt/warpmetal-agent-tools/node_modules/@anthropic-ai
    test "$(stat -c %a /usr/local/share/warpmetal/agent-tools.json)" = 444
    test ! -w /usr/local/share/warpmetal/agent-tools.json
    test ! -w /usr/local/bin/warpmetal-agent-tool-report
    test ! -w /usr/local/lib/warpmetal/cursor-agent/cursor-agent
    font_file=$(fc-match --format "%{file}" sans-serif)
    test -n "$font_file"
    test -r "$font_file"
    ! command -v sshd
    ! command -v docker
    ! command -v podman
    node /opt/warpmetal/test-tools.cjs
    node /opt/warpmetal/test-browser.cjs
  '
