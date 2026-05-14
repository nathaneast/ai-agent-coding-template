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
check "SessionEnd hook NOT present" bash -c '! jq -e ".hooks.SessionEnd" plugin/claude/settings.json'
check "session-start.sh executable" test -x plugin/claude/hooks/session-start.sh

for skill in branch-strategy tdd-loop consensus-loop env-security ss-re; do
  check "skill $skill/SKILL.md" test -f "plugin/claude/skills/$skill/SKILL.md"
done

check "plugin/claude-plugin/plugin.json valid" jq -e . plugin/claude-plugin/plugin.json
check "plugin version 0.2.1" bash -c 'jq -e ".version == \"0.2.1\"" plugin/claude-plugin/plugin.json'
check "command ss-re registered" bash -c 'jq -e ".commands | index(\"ss-re\")" plugin/claude-plugin/plugin.json'
check "rules/memory.md exists" test -f plugin/claude/rules/memory.md
check "templates CLAUDE.md exists" test -f templates/project-init/CLAUDE.md
check "templates CLAUDE.local.md exists" test -f templates/project-init/.claude/CLAUDE.local.md
check "templates .gitignore exists" test -f templates/project-init/.gitignore

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
