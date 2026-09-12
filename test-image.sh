#!/bin/sh
set -eu

image="${1:?usage: test-image.sh IMAGE [--login-shell-only]}"
test_mode="${2:-all}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

case "$test_mode" in
  all|--login-shell-only) ;;
  *)
    printf "%s\n" "usage: test-image.sh IMAGE [--login-shell-only]" >&2
    exit 2
    ;;
esac

login_shell_assertions='
  fail() {
    printf "%s\n" "$*" >&2
    exit 1
  }
  assert_command_absent() {
    if command_path=$(command -v "$1" 2>/dev/null); then
      fail "unexpected preinstalled command: $1 -> $command_path"
    fi
  }

  test "$(id -u)" = 1000
  test "$(id -g)" = 1000
  test "$HOME" = /home/agent
  test "$(stat -Lc "%u:%g" "$HOME")" = 1000:1000
  test -w "$HOME"
  test ! -e "$HOME/.profile"
  test ! -e "$HOME/.bashrc"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) fail "login shell PATH does not contain $HOME/.local/bin: $PATH" ;;
  esac

  for command_name in codex claude agent cursor-agent gemini warpmetal-agent-tool-report; do
    assert_command_absent "$command_name"
  done
  ! command -v sshd >/dev/null 2>&1
  ! command -v docker >/dev/null 2>&1
  ! command -v podman >/dev/null 2>&1
  if (: > /etc/warpmetal-login-shell-write-probe) 2>/dev/null; then
    fail "container root is writable from the login shell"
  fi
  printf "%s\n" "login shell contract ok"
'

run_login_shell() {
  keep_stdin="$1"
  shift

  if test "$keep_stdin" = yes; then
    docker_stdin_option=-i
  else
    docker_stdin_option=''
  fi

  # $docker_stdin_option is either the single literal option -i or empty.
  # shellcheck disable=SC2086
  docker run --rm $docker_stdin_option \
    --platform linux/amd64 \
    --network none \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --user 1000:1000 \
    --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
    --tmpfs /home/agent:rw,exec,nosuid,nodev,size=256m,uid=1000,gid=1000,mode=0700 \
    "$image" \
    /bin/sh "$@"
}

login_shell_status=0
if ! run_login_shell no -lc "$login_shell_assertions"; then
  login_shell_status=1
fi
if ! printf "%s\n" "$login_shell_assertions" | run_login_shell yes -l; then
  login_shell_status=1
fi
test "$login_shell_status" = 0 || exit "$login_shell_status"

if test "$test_mode" = --login-shell-only; then
  exit 0
fi

docker run --rm \
  --platform linux/amd64 \
  --network none \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user 1000:1000 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  "$image" \
  /bin/sh -ec '
    fail() {
      printf "%s\n" "$*" >&2
      exit 1
    }
    assert_command_present() {
      command -v "$1" >/dev/null 2>&1 || fail "required base command is missing: $1"
    }
    assert_command_absent() {
      if command_path=$(command -v "$1" 2>/dev/null); then
        fail "unexpected preinstalled command: $1 -> $command_path"
      fi
    }
    assert_path_absent() {
      test ! -e "$1" || fail "unexpected image artifact: $1"
    }

    test "$(id -u)" = 1000
    test "$(id -g)" = 1000
    test "$HOME" = /home/agent
    test "$(getent passwd 1000 | cut -d: -f1)" = agent

    for command_name in bash curl git jq node npm playwright python3 ssh; do
      assert_command_present "$command_name"
    done
    for command_name in codex claude agent cursor-agent gemini warpmetal-agent-tool-report; do
      assert_command_absent "$command_name"
    done

    test "$PLAYWRIGHT_VERSION" = 1.62.0
    test "$PLAYWRIGHT_BROWSERS_PATH" = /ms-playwright
    test -z "${DISABLE_AUTOUPDATER+x}" || fail "unexpected vendor environment setting: DISABLE_AUTOUPDATER"
    test -z "${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC+x}" || fail "unexpected vendor environment setting: CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"

    for image_path in \
      /opt/warpmetal-agent-tools \
      /usr/local/share/warpmetal/agent-tools.json \
      /usr/local/bin/warpmetal-agent-tool-report \
      /usr/local/lib/warpmetal/cursor-agent \
      /usr/local/lib/warpmetal/cursor-agent-wrapper \
      /usr/local/lib/node_modules/@openai/codex \
      /usr/local/lib/node_modules/@anthropic-ai/claude-code \
      /usr/local/lib/node_modules/@google/gemini-cli \
      /etc/codex/config.toml \
      /etc/claude/config.json \
      /etc/cursor/config.json \
      /etc/gemini/config.json \
      /etc/npmrc \
      /usr/local/etc/npmrc
    do
      assert_path_absent "$image_path"
    done

    credential_path=$(find "$HOME" -xdev \
      \( -iname "*auth*" -o -iname "*credential*" -o -iname "*password*" \
         -o -iname "*private*" -o -iname "*secret*" -o -iname "*token*" \
         -o -name "id_rsa" -o -name "id_ed25519" \) \
      -print -quit)
    test -z "$credential_path" || fail "sandbox image home contains credential-like material: $credential_path"

    font_file=$(fc-match --format "%{file}" sans-serif)
    test -n "$font_file"
    test -r "$font_file"
    ! command -v sshd >/dev/null 2>&1
    ! command -v docker >/dev/null 2>&1
    ! command -v podman >/dev/null 2>&1
    printf "%s\n" "static image contract ok"
  '

docker run --rm \
  --platform linux/amd64 \
  --network none \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user 1000:1000 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --tmpfs /home/agent:rw,exec,nosuid,nodev,size=256m,uid=1000,gid=1000,mode=0700 \
  --mount "type=bind,src=${script_dir}/test-browser.cjs,dst=/opt/warpmetal/test-browser.cjs,readonly" \
  --mount "type=bind,src=${script_dir}/test-fixtures/npm-local-cli,dst=/opt/warpmetal/test-npm-cli,readonly" \
  "$image" \
  /bin/sh -ec '
    fail() {
      printf "%s\n" "$*" >&2
      exit 1
    }
    assert_cannot_create() {
      if (umask 077 && : > "$1") 2>/dev/null; then
        fail "container root path is writable: $1"
      fi
    }

    test "$(id -u)" = 1000
    test "$(id -g)" = 1000
    test "$HOME" = /home/agent
    test "$(stat -Lc "%u:%g" "$HOME")" = 1000:1000
    test -w "$HOME"
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) fail "PATH does not contain $HOME/.local/bin: $PATH" ;;
    esac

    test ! -e "$HOME/.npmrc"
    test -r /opt/warpmetal/test-npm-cli/package.json
    test ! -w /opt/warpmetal/test-npm-cli/package.json
    fixture_tarball=$(npm pack \
      --offline \
      --ignore-scripts \
      --pack-destination /tmp \
      /opt/warpmetal/test-npm-cli)
    test "$fixture_tarball" = warpmetal-image-test-local-cli-1.0.0.tgz
    test -r "/tmp/$fixture_tarball"
    npm install --global --prefix "$HOME/.local" \
      --offline \
      --no-audit \
      --no-fund \
      --ignore-scripts \
      "/tmp/$fixture_tarball"
    test "$(command -v warpmetal-image-test-cli)" = "$HOME/.local/bin/warpmetal-image-test-cli"
    test "$(warpmetal-image-test-cli)" = "warpmetal user-local npm fixture ok"

    assert_cannot_create /etc/warpmetal-image-write-probe
    assert_cannot_create /opt/warpmetal-image-write-probe
    assert_cannot_create /usr/local/warpmetal-image-write-probe
    node /opt/warpmetal/test-browser.cjs
    printf "%s\n" "user-local install contract ok"
  '

persistence_volume=''
persistence_label=warpmetal-image-persistence-test
cleanup_persistence_volume() {
  cleanup_status=$?
  trap - 0 1 2 15

  if test -n "$persistence_volume"; then
    if test "${#persistence_volume}" -ne 64 || \
      test -n "$(printf %s "$persistence_volume" | tr -d '0123456789abcdef')"
    then
      printf "%s\n" "refusing to remove unexpected Docker volume name: $persistence_volume" >&2
      cleanup_status=1
    elif observed_label=$(docker volume inspect \
      --format '{{ index .Labels "io.warpmetal.test.purpose" }}' \
      "$persistence_volume" 2>/dev/null)
    then
      if test "$observed_label" != "$persistence_label"; then
        printf "%s\n" "refusing to remove Docker volume with unexpected ownership label: $persistence_volume" >&2
        cleanup_status=1
      elif docker volume rm "$persistence_volume" >/dev/null; then
        printf "%s\n" "removed persistence test volume: $persistence_volume"
      else
        printf "%s\n" "failed to remove persistence test volume: $persistence_volume" >&2
        cleanup_status=1
      fi
    else
      printf "%s\n" "failed to verify persistence test volume before removal: $persistence_volume" >&2
      cleanup_status=1
    fi
  fi

  exit "$cleanup_status"
}
trap cleanup_persistence_volume 0 1 2 15

persistence_volume=$(docker volume create \
  --label "io.warpmetal.test.purpose=$persistence_label")
if test "${#persistence_volume}" -ne 64 || \
  test -n "$(printf %s "$persistence_volume" | tr -d '0123456789abcdef')"
then
  printf "%s\n" "Docker returned an unexpected generated volume name: $persistence_volume" >&2
  exit 1
fi
printf "%s\n" "created persistence test volume: $persistence_volume"

docker run --rm \
  --platform linux/amd64 \
  --network none \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user 1000:1000 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --mount "type=volume,src=${persistence_volume},dst=/home/agent" \
  --mount "type=bind,src=${script_dir}/test-fixtures/npm-local-cli,dst=/opt/warpmetal/test-npm-cli,readonly" \
  "$image" \
  /bin/sh -ec '
    test "$(stat -Lc "%u:%g" "$HOME")" = 1000:1000
    test -w "$HOME"
    fixture_tarball=$(npm pack \
      --offline \
      --ignore-scripts \
      --pack-destination /tmp \
      /opt/warpmetal/test-npm-cli)
    test "$fixture_tarball" = warpmetal-image-test-local-cli-1.0.0.tgz
    npm install --global --prefix "$HOME/.local" \
      --offline \
      --no-audit \
      --no-fund \
      --ignore-scripts \
      "/tmp/$fixture_tarball"
    config_file="$HOME/.config/warpmetal-image-test/config"
    mkdir -p "$(dirname "$config_file")"
    printf %s warpmetal-persistence-config-v1 > "$config_file"
    test "$(sha256sum "$config_file" | cut -d " " -f 1)" = f89137d4dace0ec138d6c9695e172d4db00b6629e48e256a475ad2a88bd2ff46
    printf "%s\n" "persistence install stage ok"
  '

docker run --rm \
  --platform linux/amd64 \
  --network none \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --user 1000:1000 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --mount "type=volume,src=${persistence_volume},dst=/home/agent" \
  "$image" \
  /bin/sh -ec '
    test "$(stat -Lc "%u:%g" "$HOME")" = 1000:1000
    test -w "$HOME"
    test "$(command -v warpmetal-image-test-cli)" = "$HOME/.local/bin/warpmetal-image-test-cli"
    test "$(warpmetal-image-test-cli)" = "warpmetal user-local npm fixture ok"
    config_file="$HOME/.config/warpmetal-image-test/config"
    test -f "$config_file"
    test "$(cat "$config_file")" = warpmetal-persistence-config-v1
    test "$(sha256sum "$config_file" | cut -d " " -f 1)" = f89137d4dace0ec138d6c9695e172d4db00b6629e48e256a475ad2a88bd2ff46
    printf "%s\n" "persistence reuse stage ok"
  '

push_paths=$(awk '
  /^  push:$/ { in_push = 1; next }
  in_push && /^  [^ ]/ { in_push = 0; in_paths = 0 }
  in_push && /^    paths:$/ { in_paths = 1; next }
  in_paths && /^      - / {
    path = $0
    sub(/^      - /, "", path)
    sub(/^"/, "", path)
    sub(/"$/, "", path)
    print path
  }
' "$script_dir/.github/workflows/image.yml")
if test "$push_paths" != Containerfile; then
  printf "release push.paths must contain only Containerfile; got:\n%s\n" "$push_paths" >&2
  exit 1
fi
printf "%s\n" "release push.paths contract ok"
