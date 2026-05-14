#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
LOG="$REPO_ROOT/templates/project-init/04.docs/setup-codex.log"
mkdir -p "$REPO_ROOT/templates/project-init/04.docs"

pass=0; fail=0; results=()
check() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then results+=("PASS  $n"); pass=$((pass+1)); else results+=("FAIL  $n"); fail=$((fail+1)); fi; }

check "plugin/codex/config.toml exists" test -f plugin/codex/config.toml
check "codex_hooks feature enabled" grep -q "codex_hooks = true" plugin/codex/config.toml
check "plugin/codex/hooks.json valid JSON" jq -e . plugin/codex/hooks.json
check "SessionStart in hooks.json" bash -c 'jq -e ".hooks.SessionStart[0]" plugin/codex/hooks.json'
check "SessionEnd NOT in hooks.json" bash -c '! jq -e ".hooks.SessionEnd" plugin/codex/hooks.json'
check "plugin/codex/hooks/session-start.sh exec" test -x plugin/codex/hooks/session-start.sh
check "plugin/codex-plugin/plugin.json valid" jq -e . plugin/codex-plugin/plugin.json
check "AGENTS.md exists" test -f AGENTS.md
check "AGENTS.md mentions CLAUDE.md" grep -q "CLAUDE.md" AGENTS.md
check "Codex wrapper simulation" bash plugin/codex/hooks/session-start.sh

{
  echo "# /setup-codex — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  for r in "${results[@]}"; do echo "- $r"; done
  echo ""; echo "PASS: $pass"; echo "FAIL: $fail"
} | tee "$LOG"

[[ "$fail" -eq 0 ]] && { echo ""; echo "✅ /setup-codex PASS"; exit 0; } || { echo ""; echo "❌ /setup-codex FAIL"; exit 1; }
