#!/bin/sh
set -eu

cursor_agent=/usr/local/lib/warpmetal/cursor-agent/cursor-agent

if [ "${WARPMETAL_AGENT_TOOL_PROBE:-}" = "1" ]; then
  export CURSOR_AGENT_CLI_AUTHLESS_MODE=true
fi

exec "$cursor_agent" --disable-auto-update "$@"
