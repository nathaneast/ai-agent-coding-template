#!/usr/bin/env bash
# .claude/hooks/session-end.sh
# 세션 종료 시 KPI 카운터 + (Phase 5에서) sessions/index.json append
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEARNINGS_DIR="$REPO_ROOT/.omc/learnings"

# stdin에 세션 정보 JSON 받을 수 있음 (sessionId, lastFiles 등) - Phase 5에서 활용
INPUT=""
[[ -t 0 ]] || INPUT="$(cat)"

# learnings_recalled 카운터 증가 (이전 세션이 learnings를 회수했으므로)
METRICS="$LEARNINGS_DIR/_metrics.json"
if [[ -f "$METRICS" ]] && command -v jq >/dev/null 2>&1; then
  TMP="$(mktemp)"
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.counters.learnings_recalled += 1 | .last_updated = $ts' "$METRICS" > "$TMP" && mv "$TMP" "$METRICS"
fi

# Phase 5에서 sessions/index.json append 로직 여기에 추가될 예정

exit 0
