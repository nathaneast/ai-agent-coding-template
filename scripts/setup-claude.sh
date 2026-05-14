#!/usr/bin/env bash
# Setup verification for Claude Code side of harness
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

LOG_DIR="$REPO_ROOT/templates/project-init/04.docs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/setup-claude.log"

pass=0
fail=0
results=()

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    results+=("PASS  $name")
    pass=$((pass + 1))
  else
    results+=("FAIL  $name")
    fail=$((fail + 1))
  fi
}

check "settings.json exists" test -f plugin/claude/settings.json
check "settings.json valid JSON" jq -e . plugin/claude/settings.json
check "SessionStart hook registered" bash -c 'jq -e ".hooks.SessionStart[0]" plugin/claude/settings.json'
check "SessionEnd hook registered" bash -c 'jq -e ".hooks.SessionEnd[0]" plugin/claude/settings.json'
check "session-start.sh executable" test -x plugin/claude/hooks/session-start.sh
check "session-end.sh executable" test -x plugin/claude/hooks/session-end.sh

for skill in branch-strategy tdd-loop consensus-loop env-security session-index; do
  check "skill $skill/SKILL.md" test -f "plugin/claude/skills/$skill/SKILL.md"
done

check "plugin/claude-plugin/plugin.json valid" jq -e . plugin/claude-plugin/plugin.json
check ".omc/learnings/preferences.md" test -f .omc/learnings/preferences.md
check ".omc/learnings/pitfalls.md" test -f .omc/learnings/pitfalls.md
check ".omc/learnings/patterns.md" test -f .omc/learnings/patterns.md
check ".omc/learnings/glossary.md" test -f .omc/learnings/glossary.md
check ".omc/learnings/_metrics.json valid" jq -e . .omc/learnings/_metrics.json

if command -v bats >/dev/null 2>&1; then
  check "bats tests pass" bats plugin/claude/hooks/tests/
fi

check "SessionStart simulation" bash plugin/claude/hooks/session-start.sh

{
  echo "# /setup-claude — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  for r in "${results[@]}"; do echo "- $r"; done
  echo ""
  echo "PASS: $pass"
  echo "FAIL: $fail"
} | tee "$LOG"

if [[ "$fail" -eq 0 ]]; then
  echo ""
  echo "✅ /setup-claude PASS"
  exit 0
else
  echo ""
  echo "❌ /setup-claude FAIL ($fail items)"
  exit 1
fi
