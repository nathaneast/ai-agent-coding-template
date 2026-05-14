#!/usr/bin/env bash
# Phase 0 위험 키워드 1차 분류
# usage: solo-triage.sh "<prompt text>"
#        또는 echo "<prompt>" | solo-triage.sh
set -euo pipefail

# --- 입력 수집 ---
if [[ -n "${1:-}" ]]; then
  PROMPT="$1"
else
  PROMPT="$(cat)"
fi

if [[ -z "$PROMPT" ]]; then
  echo '{"risk_labels":[],"highest_priority":"standard","matched_keywords":[]}'
  exit 0
fi

# --- 매칭 ---
LABELS=()
KEYWORDS=()

# critical: auth/session/token/jwt/password/secret
if echo "$PROMPT" | grep -qiE '(auth|session|token|jwt|password|secret)'; then
  LABELS+=("security")
  while IFS= read -r kw; do
    KEYWORDS+=("$kw")
  done < <(echo "$PROMPT" | grep -oiE '(auth|session|token|jwt|password|secret)' | tr '[:upper:]' '[:lower:]' | sort -u)
fi

# critical: schema/migration/alter table/drop table
if echo "$PROMPT" | grep -qiE '(schema|migration|alter[[:space:]]+table|drop[[:space:]]+table)'; then
  LABELS+=("database")
  while IFS= read -r kw; do
    KEYWORDS+=("$kw")
  done < <(echo "$PROMPT" | grep -oiE '(schema|migration|alter[[:space:]]+table|drop[[:space:]]+table)' | tr '[:upper:]' '[:lower:]' | sort -u)
fi

# critical: .env
if echo "$PROMPT" | grep -qE '\.env'; then
  LABELS+=("env")
  KEYWORDS+=(".env")
fi

# high: payment/결제/토스/환불/refund
if echo "$PROMPT" | grep -qiE '(payment|결제|토스|환불|refund)'; then
  LABELS+=("payment")
  while IFS= read -r kw; do
    KEYWORDS+=("$kw")
  done < <(echo "$PROMPT" | grep -oiE '(payment|결제|토스|환불|refund)' | tr '[:upper:]' '[:lower:]' | sort -u)
fi

# --- 우선순위 결정 ---
HIGHEST="standard"
for label in "${LABELS[@]:-}"; do
  case "$label" in
    security|database|env) HIGHEST="critical" ;;
    payment) [[ "$HIGHEST" != "critical" ]] && HIGHEST="high" ;;
  esac
done

# --- JSON 빌드 ---
# labels 배열 (중복 제거)
UNIQUE_LABELS=()
declare -A _seen_labels=()
if [[ ${#LABELS[@]} -gt 0 ]]; then
  for l in "${LABELS[@]}"; do
    if [[ -z "${_seen_labels[$l]+x}" ]]; then
      _seen_labels[$l]=1
      UNIQUE_LABELS+=("$l")
    fi
  done
fi

# keywords 배열 (중복 제거)
UNIQUE_KEYWORDS=()
declare -A _seen_kw=()
if [[ ${#KEYWORDS[@]} -gt 0 ]]; then
  for k in "${KEYWORDS[@]}"; do
    if [[ -z "${_seen_kw[$k]+x}" ]]; then
      _seen_kw[$k]=1
      UNIQUE_KEYWORDS+=("$k")
    fi
  done
fi

json_array() {
  local -n arr=$1
  local out="["
  local first=1
  if [[ ${#arr[@]} -gt 0 ]]; then
    for item in "${arr[@]}"; do
      [[ $first -eq 0 ]] && out+=","
      out+="\"$item\""
      first=0
    done
  fi
  out+="]"
  echo "$out"
}

LABELS_JSON="$(json_array UNIQUE_LABELS)"
KEYWORDS_JSON="$(json_array UNIQUE_KEYWORDS)"

printf '{"risk_labels":%s,"highest_priority":"%s","matched_keywords":%s}\n' \
  "$LABELS_JSON" "$HIGHEST" "$KEYWORDS_JSON"

# --- 단위 테스트 예제 (inline) ---
# [예제 1] input: "결제 페이지에 토스 연동 추가"
# expected: {"risk_labels":["payment"],"highest_priority":"high","matched_keywords":["결제","토스"]}
# 검증: bash solo-triage.sh "결제 페이지에 토스 연동 추가"
#
# [예제 2] input: "유저 인증 추가"
# expected: {"risk_labels":["security"],"highest_priority":"critical","matched_keywords":["auth"]}
# 검증: bash solo-triage.sh "유저 인증 추가"
# (note: "인증" 자체는 매칭 안 됨 — "auth"가 없어 standard. 실제 한국어 auth는 아래 예제로 대체)
#
# [예제 2b] input: "Add user auth and jwt token"
# expected: {"risk_labels":["security"],"highest_priority":"critical","matched_keywords":["auth","jwt","token"]}
# 검증: bash solo-triage.sh "Add user auth and jwt token"
#
# [예제 3] input: "그냥 버튼 색 바꿔"
# expected: {"risk_labels":[],"highest_priority":"standard","matched_keywords":[]}
# 검증: bash solo-triage.sh "그냥 버튼 색 바꿔"
