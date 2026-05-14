#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
METRICS="$REPO_ROOT/.omc/learnings/_metrics.json"
if [[ -f "$METRICS" ]] && command -v jq >/dev/null 2>&1; then
  TMP="$(mktemp)"
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.counters.double_check_invoked += 1 | .last_updated = $ts' "$METRICS" > "$TMP" && mv "$TMP" "$METRICS"
fi
echo "double-check counter +1"
