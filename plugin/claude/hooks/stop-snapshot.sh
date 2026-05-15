#!/usr/bin/env bash
# plugin/claude/hooks/stop-snapshot.sh
# Stop hook: Claude 응답 종료 시 자동 snapshot frontmatter 갱신 (5분 throttle)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# 마커 없으면 skip (다른 프로젝트 방해 X)
if [[ ! -f "$PROJECT_CWD/.harness-active" && ! -f "$PROJECT_CWD/.harness-main-only" ]]; then
  exit 0
fi

mkdir -p "$PROJECT_CWD/.omc/state"

THROTTLE_FILE="$PROJECT_CWD/.omc/state/.snapshot-last-save"
NOW=$(date +%s)
THROTTLE_SEC="${SS_RE_THROTTLE_SEC:-300}"  # 기본 5분

if [[ -f "$THROTTLE_FILE" ]]; then
  LAST=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)
  DIFF=$((NOW - LAST))
  if [[ "$DIFF" -lt "$THROTTLE_SEC" ]]; then
    exit 0
  fi
fi

# Generate snapshot frontmatter (auto_save=true)
bash "$SCRIPT_DIR/lib/snapshot-meta.sh" \
  "$PROJECT_CWD" \
  "$PROJECT_CWD/.omc/snapshot.md" \
  "true" 2>/dev/null || exit 0

echo "$NOW" > "$THROTTLE_FILE"
exit 0
