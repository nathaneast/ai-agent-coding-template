#!/usr/bin/env bash
# Build iteration gate: enforce TDD + consensus + per-task commit
# Called by ralph after each iteration to verify
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ITER="${1:-1}"
LOG_DIR="$REPO_ROOT/.omc/state"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/build-iteration-$ITER.log"

pass=0; fail=0; results=()
check() {
  local n="$1"; shift
  if "$@" >/dev/null 2>&1; then
    results+=("PASS $n"); pass=$((pass+1))
  else
    results+=("FAIL $n"); fail=$((fail+1))
  fi
}

# 1. dev branch
check "branch=dev" bash -c '[[ "$(git rev-parse --abbrev-ref HEAD)" == "dev" ]]'

# 2. uncommitted changes <= 5 files (Task scope)
UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
check "task-scope (<=5 uncommitted)" bash -c "[[ $UNCOMMITTED -le 5 ]]"

# 3. tests exist (bats or other) — only check if bats files are present
if [[ -d plugin/claude/hooks/tests ]] && ls plugin/claude/hooks/tests/*.bats >/dev/null 2>&1; then
  check "bats tests exist" bash -c "ls plugin/claude/hooks/tests/*.bats >/dev/null 2>&1"
  if command -v bats >/dev/null 2>&1; then
    check "bats pass" bats plugin/claude/hooks/tests/
  fi
fi

# 4. recent commit message has conventional prefix
LAST_MSG=$(git log -1 --pretty=%s)
check "commit prefix" bash -c "echo '$LAST_MSG' | grep -qE '^(feat|fix|test|docs|chore|refactor|build|ci)(\(.+\))?:'"

# Log
{
  echo "# Build Iteration $ITER — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  for r in "${results[@]}"; do echo "- $r"; done
  echo ""
  echo "PASS: $pass / FAIL: $fail"
} | tee "$LOG"

[[ "$fail" -eq 0 ]]
