#!/usr/bin/env bash
# memory-write-guard.sh — Memory v0.4 G4 비밀 스캔 가드 (PreToolUse Write/Edit)
#
# 동작: stdin으로 받은 hook JSON에서 file_path + content/new_string 추출.
# 메모리 경로(06.memory/, plugin/memory/user/)에 쓰는 경우에만 검사.
# 차단 정규식 매칭 시 exit 2 (PreToolUse hook block).
# 경고 정규식 매칭 시 stderr 경고 + exit 0 (허용).
#
# 차단 패턴: API 토큰, 긴 영문대문자+숫자 (32+), 이메일
# 경고 패턴: NDA·금액·계약 키워드
#
# 인명/회사명 패턴은 본 hook 스킵 — memory.md 룰이 Claude의 자율 거부로 1차 방어.

set -euo pipefail

INPUT=$(cat)

# jq 없으면 정상 통과 (가드 무효화하지 않고 보수적으로 허용은 위험 — 차단 권장이나, 호환성 우선)
if ! command -v jq >/dev/null 2>&1; then
  echo "WARN: memory-write-guard — jq not found, skipping scan" >&2
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')

# 메모리 경로만 검사
case "$FILE_PATH" in
  */06.memory/*|*/plugin/memory/user/*) ;;
  *) exit 0 ;;
esac

# 빈 content는 검사 의미 없음
if [[ -z "$CONTENT" ]]; then
  exit 0
fi

# 차단 정규식 (한 패턴이라도 매칭 → exit 2)
BLOCK_PATTERNS=(
  '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|xoxb-[0-9A-Za-z-]+)'
  '[A-Z0-9]{32,}'
  '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
)

# 경고 정규식 (차단 X, stderr 경고만)
WARN_PATTERNS=(
  '(NDA|nda|계약금|납기일|마감일|선급금)'
)

for pat in "${BLOCK_PATTERNS[@]}"; do
  if printf '%s' "$CONTENT" | grep -qE "$pat"; then
    echo "ERROR: Memory write blocked — pattern matched: $pat" >&2
    echo "FILE: $FILE_PATH" >&2
    echo "메모리 시스템에 시크릿/이메일/토큰 적재 금지. CHANGELOG.md에 사유 기록 후 사용자 재시도." >&2
    exit 2
  fi
done

for pat in "${WARN_PATTERNS[@]}"; do
  if printf '%s' "$CONTENT" | grep -qE "$pat"; then
    echo "WARN: Memory write — sensitive keyword matched: $pat" >&2
    echo "FILE: $FILE_PATH" >&2
    # 경고만 — 차단 X (사용자가 진짜 적층 원할 수도)
  fi
done

exit 0
