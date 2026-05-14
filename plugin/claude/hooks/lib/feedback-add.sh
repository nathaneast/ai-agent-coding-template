#!/usr/bin/env bash
# 피드백 append: 03.archive/feedback.md에 1줄 entry 추가
# usage: feedback-add.sh "<free text>"
set -euo pipefail

PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
FEEDBACK_FILE="$PROJECT_CWD/03.archive/feedback.md"

TEXT="${1:-}"
if [[ -z "$TEXT" ]]; then
  echo "usage: feedback-add.sh \"<free text>\"" >&2
  exit 1
fi

# 보안: text 안에 줄바꿈 들어오면 1줄로 정규화 (entry는 항상 1줄)
TEXT="$(printf '%s' "$TEXT" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')"

# feedback.md 없으면 헤더 포함해 생성
if [[ ! -f "$FEEDBACK_FILE" ]]; then
  mkdir -p "$(dirname "$FEEDBACK_FILE")"
  cat > "$FEEDBACK_FILE" <<'EOF'
# Feedback Log

> 사용자가 작업 중 누적시키는 피드백 / 불만 / 개선 요청.
> 추후 resolver 도구가 이 로그를 읽어 미해결 항목을 자동 해소 시도한다.

## Entries

<!-- entries are appended below by feedback-add.sh -->
EOF
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HASH="$(printf '%s' "$TEXT$TS" | shasum -a 256 | cut -d' ' -f1 | head -c 12)"

printf -- '- [%s] %s _hash_: %s _status_: open\n' "$TS" "$TEXT" "$HASH" >> "$FEEDBACK_FILE"

OPEN_COUNT="$(grep -c '_status_: open' "$FEEDBACK_FILE" 2>/dev/null || echo 0)"
echo "added → $FEEDBACK_FILE (open: $OPEN_COUNT, hash: $HASH)"
