#!/usr/bin/env bash
# One container runs HTTP and generation: upstream splits them for horizontal
# scaling, but one process keeps the template at three services and loads the
# embedding model once. Leave CLAUDE_MEM_GENERATION_DISABLED unset.
set -euo pipefail

port="${PORT:-37877}"
export CLAUDE_MEM_SERVER_PORT="$port" CLAUDE_MEM_WORKER_PORT="$port"

# The key CLI needs the schema the server creates at startup, so set up the
# key in the background once the server answers.
(until curl -fsS -o /dev/null "http://127.0.0.1:$port/healthz"; do sleep 2; done; bun /opt/railway-setup.mjs) &
exec bun /opt/claude-mem/scripts/server-service.cjs --daemon
