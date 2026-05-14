#!/usr/bin/env bash
# solo-dryrun.sh — Phase 1.5 verify_cmd 실행 가능성 사전 검증
# Usage: solo-dryrun.sh [criteria_json_path]
# Output: 갱신된 criteria.json (dryrun_status 필드 추가) + stdout 요약

set -euo pipefail

CRITERIA_JSON="${1:-.omc/state/solo-criteria.json}"

# criteria.json 존재 확인
if [[ ! -f "$CRITERIA_JSON" ]]; then
  echo "[solo-dryrun] ERROR: criteria.json not found: $CRITERIA_JSON" >&2
  exit 1
fi

# jq 존재 확인
if ! command -v jq &>/dev/null; then
  echo "[solo-dryrun] ERROR: jq is required but not found in PATH" >&2
  exit 1
fi

# 스크립트 실행 위치 기준 프로젝트 루트 탐색 (git root 우선)
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ── 헬퍼: npm/yarn 스크립트 존재 여부 확인 ─────────────────────────────────
check_npm_script() {
  local script_name="$1"
  local pkg_json="$PROJECT_ROOT/package.json"

  if [[ ! -f "$pkg_json" ]]; then
    return 1
  fi

  # jq로 scripts 객체에서 해당 키 확인
  local exists
  exists=$(jq --arg name "$script_name" \
    'if .scripts and (.scripts | has($name)) then "yes" else "no" end' \
    "$pkg_json" 2>/dev/null || echo "no")

  [[ "$exists" == '"yes"' ]]
}

# ── 헬퍼: verify_cmd 분류 및 실행 가능성 판정 ─────────────────────────────
check_verify_cmd() {
  local cmd="$1"
  local status="unknown"

  # 1. system tool — 항상 통과
  if echo "$cmd" | grep -qE '^(grep|awk|sed|cat|head|tail|wc|find|ls)\b'; then
    echo "executable"
    return
  fi

  # 2. lsp_diagnostics — MCP tool, 항상 통과
  if echo "$cmd" | grep -qE '^lsp_diagnostics'; then
    echo "executable"
    return
  fi

  # 3. npm test / npm run <script>
  if echo "$cmd" | grep -qE '^npm (test|run)\b'; then
    local script_name
    if echo "$cmd" | grep -qE '^npm test'; then
      script_name="test"
    else
      # "npm run <script>" — 3번째 토큰
      script_name=$(echo "$cmd" | awk '{print $3}')
      # "npm run <script> -- ..." 형태에서 앞부분만
      script_name="${script_name%% *}"
    fi

    if [[ -n "$script_name" ]] && check_npm_script "$script_name"; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 4. yarn test / yarn run <script>
  if echo "$cmd" | grep -qE '^yarn (test|run)\b'; then
    local script_name
    if echo "$cmd" | grep -qE '^yarn test'; then
      script_name="test"
    else
      script_name=$(echo "$cmd" | awk '{print $3}')
      script_name="${script_name%% *}"
    fi

    if [[ -n "$script_name" ]] && check_npm_script "$script_name"; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 5. pnpm test / pnpm run
  if echo "$cmd" | grep -qE '^pnpm (test|run)\b'; then
    local script_name
    if echo "$cmd" | grep -qE '^pnpm test'; then
      script_name="test"
    else
      script_name=$(echo "$cmd" | awk '{print $3}')
      script_name="${script_name%% *}"
    fi

    if [[ -n "$script_name" ]] && check_npm_script "$script_name"; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 6. playwright
  if echo "$cmd" | grep -qiE 'playwright'; then
    local pw_installed=false
    if [[ -d "$PROJECT_ROOT/node_modules/@playwright/test" ]] || \
       [[ -d "$PROJECT_ROOT/node_modules/playwright" ]]; then
      pw_installed=true
    fi
    local pw_config=false
    if ls "$PROJECT_ROOT"/playwright.config.* &>/dev/null 2>&1; then
      pw_config=true
    fi

    if $pw_installed || $pw_config; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 7. pytest / python -m pytest
  if echo "$cmd" | grep -qE '(^pytest\b|python.*-m pytest)'; then
    if command -v pytest &>/dev/null || python3 -m pytest --version &>/dev/null 2>&1; then
      # collect-only dry run으로 실제 수집 가능성 확인 (실패해도 degraded)
      if pytest --collect-only -q &>/dev/null 2>&1 || \
         python3 -m pytest --collect-only -q &>/dev/null 2>&1; then
        echo "executable"
      else
        # pytest는 있지만 수집 실패 → degraded
        echo "degraded"
      fi
    else
      echo "degraded"
    fi
    return
  fi

  # 8. 매칭 안 됨 → unknown
  echo "unknown"
}

# ── 메인 처리 ─────────────────────────────────────────────────────────────────
TMP_FILE="${CRITERIA_JSON}.tmp.$$"

# 카운터 초기화
cnt_executable=0
cnt_degraded=0
cnt_unknown=0

# must_pass 배열 길이
total=$(jq '.must_pass | length' "$CRITERIA_JSON")

# 각 criterion 처리 (인덱스 기반 순회)
updated_json="$CRITERIA_JSON"

for i in $(seq 0 $((total - 1))); do
  criterion_id=$(jq -r ".must_pass[$i].id" "$CRITERIA_JSON")
  verify_cmd=$(jq -r ".must_pass[$i].verify_cmd // empty" "$CRITERIA_JSON")

  if [[ -z "$verify_cmd" ]]; then
    # verify_cmd 없으면 unknown
    dryrun_status="unknown"
    echo "[solo-dryrun] WARN: $criterion_id has no verify_cmd → unknown"
  else
    dryrun_status=$(check_verify_cmd "$verify_cmd")
  fi

  case "$dryrun_status" in
    executable)
      ((cnt_executable++)) || true
      ;;
    degraded)
      ((cnt_degraded++)) || true
      echo "[solo-dryrun] DEGRADED: $criterion_id — cmd='$verify_cmd' → type 강등 to manual"
      ;;
    unknown)
      ((cnt_unknown++)) || true
      echo "[solo-dryrun] WARN: $criterion_id — cmd='$verify_cmd' → unknown (실행 가능 여부 불명)"
      ;;
  esac

  # degraded면 type을 manual로 강등 + dryrun_status 추가
  # unknown/executable은 dryrun_status만 추가
  if [[ "$dryrun_status" == "degraded" ]]; then
    jq --argjson idx "$i" \
       --arg ds "$dryrun_status" \
       '.must_pass[$idx].dryrun_status = $ds | .must_pass[$idx].type = "manual"' \
       "$CRITERIA_JSON" > "$TMP_FILE" && mv "$TMP_FILE" "$CRITERIA_JSON"
  else
    jq --argjson idx "$i" \
       --arg ds "$dryrun_status" \
       '.must_pass[$idx].dryrun_status = $ds' \
       "$CRITERIA_JSON" > "$TMP_FILE" && mv "$TMP_FILE" "$CRITERIA_JSON"
  fi
done

# ── 전체 강등 검사: 모든 must_pass가 degraded면 STOP 마커 기록 ──────────────
all_degraded=true
for i in $(seq 0 $((total - 1))); do
  ds=$(jq -r ".must_pass[$i].dryrun_status" "$CRITERIA_JSON")
  if [[ "$ds" != "degraded" ]]; then
    all_degraded=false
    break
  fi
done

if $all_degraded && [[ "$total" -gt 0 ]]; then
  echo "[solo-dryrun] STOP: 모든 verify_cmd 실행 불가 → 사용자 확인 필요"
  touch "$(dirname "$CRITERIA_JSON")/USER_CONFIRM_NEEDED"
fi

# ── stdout 요약 ───────────────────────────────────────────────────────────────
echo ""
echo "━━━ [solo-dryrun] Phase 1.5 DRY-RUN 요약 ━━━"
echo "  총 criteria  : $total"
echo "  executable   : $cnt_executable  (그대로 유지)"
echo "  degraded     : $cnt_degraded  (type → manual 강등)"
echo "  unknown      : $cnt_unknown  (경고 — 수동 확인 권장)"
echo "  갱신 파일    : $CRITERIA_JSON"
if $all_degraded && [[ "$total" -gt 0 ]]; then
  echo "  ⚠ STOP 마커 생성됨 — 사용자 확인 후 진행"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
