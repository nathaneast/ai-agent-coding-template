#!/usr/bin/env bash
# plugin/claude/hooks/lib/snapshot-meta.sh
# Snapshot frontmatter 작성 (객관 메타) — 자동/수동 공용
#
# Usage:
#   bash snapshot-meta.sh <project_cwd> <output_path> <auto_save:true|false>

set -euo pipefail

PROJECT_CWD="${1:-$PWD}"
OUT="${2:-$PROJECT_CWD/.omc/snapshot.md}"
AUTO_SAVE="${3:-false}"

mkdir -p "$(dirname "$OUT")"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BRANCH=$(git -C "$PROJECT_CWD" branch --show-current 2>/dev/null || echo "?")
LAST_COMMIT=$(git -C "$PROJECT_CWD" rev-parse --short HEAD 2>/dev/null || echo "?")

# 변경 파일 — git status --short, 최대 20줄
FILES_CHANGED=$(git -C "$PROJECT_CWD" status --short 2>/dev/null | head -20 || true)
FILES_COUNT=$(echo "$FILES_CHANGED" | grep -c . 2>/dev/null || echo 0)

# 활성 모드 감지 (OMC state)
ACTIVE_MODE="none"
for m in ralph autopilot ultrawork ecomode ultraqa swarm ultrapilot pipeline team solo; do
  [[ -f "$PROJECT_CWD/.omc/state/$m-state.json" ]] && ACTIVE_MODE="$m" && break
done

# Claude Code session id (best-effort)
SESSION_ID="${CLAUDE_SESSION_ID:-?}"

# Write frontmatter
{
  echo "---"
  echo "schema_version: 2"
  echo "ts: $TS"
  echo "auto_save: $AUTO_SAVE"
  echo "project: $PROJECT_CWD"
  echo "branch: $BRANCH"
  echo "last_commit: $LAST_COMMIT"
  echo "active_mode: $ACTIVE_MODE"
  echo "session_id: $SESSION_ID"
  echo "files_count: $FILES_COUNT"
  echo "files_changed: |"
  if [[ -n "$FILES_CHANGED" ]]; then
    echo "$FILES_CHANGED" | sed 's/^/  /'
  else
    echo "  (none)"
  fi
  echo "---"
  echo ""
  # Body는 Claude가 채울 영역.
  if [[ "$AUTO_SAVE" == "true" ]]; then
    cat <<'BODY'
## 자동 저장 — Body 미작성

본 스냅샷은 Stop hook이 자동 저장한 메타입니다. 본문은 비어 있으므로
다음 세션에서 정확한 작업 컨텍스트를 받으려면 사용자가 명시 `/ss-re`
호출 또는 Claude main이 회수 시 자동으로 압축 작성을 권장.
BODY
  else
    cat <<'BODY'
## 작업 (Now)
<현재 작업 1~2줄>

## 진행 (Done)
- <완료 항목>

## 다음 즉시 단계 (Next)
1. <첫 단계>
2. <두 번째 단계>

## 블로커 (Blockers)
- <사용자 결정 대기 항목 있으면 명시, 없으면 "없음">

## 다음 세션 권장 첫 명령
`<짧은 명령 또는 자연어 한 줄>`
BODY
  fi
} > "$OUT"

exit 0
