#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
LOG="$REPO_ROOT/04.docs/setup-codex.log"
mkdir -p "$REPO_ROOT/04.docs"

pass=0; fail=0; results=()
check() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then results+=("PASS  $n"); pass=$((pass+1)); else results+=("FAIL  $n"); fail=$((fail+1)); fi; }

check ".codex/config.toml exists" test -f .codex/config.toml
check "codex_hooks feature enabled" grep -q "codex_hooks = true" .codex/config.toml
check ".codex/hooks.json valid JSON" jq -e . .codex/hooks.json
check "SessionStart in hooks.json" bash -c 'jq -e ".hooks.SessionStart[0]" .codex/hooks.json'
check "SessionEnd in hooks.json" bash -c 'jq -e ".hooks.SessionEnd[0]" .codex/hooks.json'
check ".codex/hooks/session-start.sh exec" test -x .codex/hooks/session-start.sh
check ".codex/hooks/session-end.sh exec" test -x .codex/hooks/session-end.sh
check ".codex-plugin/plugin.json valid" jq -e . .codex-plugin/plugin.json
check "AGENTS.md exists" test -f AGENTS.md
check "AGENTS.md mentions CLAUDE.md" grep -q "CLAUDE.md" AGENTS.md
check "Codex wrapper simulation" bash .codex/hooks/session-start.sh

{
  echo "# /setup-codex — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  for r in "${results[@]}"; do echo "- $r"; done
  echo ""; echo "PASS: $pass"; echo "FAIL: $fail"
} | tee "$LOG"

[[ "$fail" -eq 0 ]] && { echo ""; echo "✅ /setup-codex PASS"; exit 0; } || { echo ""; echo "❌ /setup-codex FAIL"; exit 1; }
