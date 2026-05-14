#!/usr/bin/env bash
set -euo pipefail

# solo-budget.sh — 비용/시간/iteration 카운터 + 다운그레이드 판정
# 상태 파일: .omc/state/solo-budget.json
# 서브커맨드: init | add-cost | inc-iter | check | recommend-tier | limit-reached

# ── 환경변수 오버라이드 ─────────────────────────────────────────────────────
SOLO_MAX_COST_USD="${SOLO_MAX_COST_USD:-20}"
SOLO_MAX_DURATION_H="${SOLO_MAX_DURATION_H:-24}"
SOLO_GRACEFUL_DURATION_H="${SOLO_GRACEFUL_DURATION_H:-10}"
SOLO_MAX_ITERATIONS="${SOLO_MAX_ITERATIONS:-100}"

# ── 상태 파일 경로 ─────────────────────────────────────────────────────────
# git worktree root 기준. 실행 위치에 관계없이 repo root 사용.
_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

_state_file() {
  echo "$(_repo_root)/.omc/state/solo-budget.json"
}

# ── atomic write 헬퍼 ──────────────────────────────────────────────────────
_atomic_write() {
  local target="$1"
  local content="$2"
  local tmp="${target}.tmp.$$"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' "$content" > "$tmp"
  mv "$tmp" "$target"
}

# ── 상태 파일 읽기 ─────────────────────────────────────────────────────────
_read_state() {
  local sf
  sf="$(_state_file)"
  if [[ ! -f "$sf" ]]; then
    echo "solo-budget: state file not found. run 'init' first." >&2
    exit 1
  fi
  cat "$sf"
}

# ── elapsed 초 계산 ────────────────────────────────────────────────────────
_elapsed_seconds() {
  local start_ts="$1"
  local now_ts
  now_ts="$(date +%s)"
  echo $(( now_ts - start_ts ))
}

# ── 서브커맨드: init ───────────────────────────────────────────────────────
cmd_init() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    echo "usage: solo-budget.sh init <run_id>" >&2
    exit 1
  fi
  local now_ts
  now_ts="$(date +%s)"
  local json
  json="$(jq -n \
    --arg run_id "$run_id" \
    --argjson start_ts "$now_ts" \
    '{run_id: $run_id, start_ts: $start_ts, cost_usd: 0.0, iterations: 0}')"
  _atomic_write "$(_state_file)" "$json"
}

# ── 서브커맨드: add-cost ───────────────────────────────────────────────────
cmd_add_cost() {
  local delta="${1:-}"
  if [[ -z "$delta" ]]; then
    echo "usage: solo-budget.sh add-cost <usd>" >&2
    exit 1
  fi
  local sf
  sf="$(_state_file)"
  local current
  current="$(_read_state)"
  local updated
  updated="$(echo "$current" | jq --argjson d "$delta" '.cost_usd += $d')"
  _atomic_write "$sf" "$updated"
}

# ── 서브커맨드: inc-iter ───────────────────────────────────────────────────
cmd_inc_iter() {
  local sf
  sf="$(_state_file)"
  local current
  current="$(_read_state)"
  local updated
  updated="$(echo "$current" | jq '.iterations += 1')"
  _atomic_write "$sf" "$updated"
}

# ── 서브커맨드: check ──────────────────────────────────────────────────────
cmd_check() {
  local state
  state="$(_read_state)"
  local start_ts cost_usd iterations
  start_ts="$(echo "$state" | jq -r '.start_ts')"
  cost_usd="$(echo "$state" | jq -r '.cost_usd')"
  iterations="$(echo "$state" | jq -r '.iterations')"
  local elapsed_s
  elapsed_s="$(_elapsed_seconds "$start_ts")"
  local elapsed_h
  elapsed_h="$(echo "scale=4; $elapsed_s / 3600" | bc)"
  echo "$state" | jq \
    --argjson elapsed_s "$elapsed_s" \
    --argjson elapsed_h "$elapsed_h" \
    '. + {elapsed_seconds: $elapsed_s, elapsed_hours: $elapsed_h}'
}

# ── 서브커맨드: recommend-tier ────────────────────────────────────────────
cmd_recommend_tier() {
  local state
  state="$(_read_state)"
  local cost_usd
  cost_usd="$(echo "$state" | jq -r '.cost_usd')"
  # bc 부동소수점 비교
  local ge18 ge15
  ge18="$(echo "$cost_usd >= 18" | bc -l)"
  ge15="$(echo "$cost_usd >= 15" | bc -l)"
  if [[ "$ge18" -eq 1 ]]; then
    echo "haiku"
  elif [[ "$ge15" -eq 1 ]]; then
    echo "sonnet"
  else
    echo "opus"
  fi
}

# ── criteria_json helper: critical 전부 passed 여부 ──────────────────────
# 반환: 1 = 모두 passed, 0 = 미통과 항목 있음
_critical_all_passed() {
  local criteria_json_path="$1"
  if [[ ! -f "$criteria_json_path" ]]; then
    echo "solo-budget: criteria file not found: $criteria_json_path" >&2
    return 1
  fi
  local result
  result="$(jq '
    [ .must_pass[] | select(.priority == "critical") ] as $crits |
    if ($crits | length) == 0 then 0
    else
      ([ $crits[] | select(.status == "passed") ] | length) as $passed_cnt |
      if $passed_cnt == ($crits | length) then 1 else 0 end
    end
  ' "$criteria_json_path")"
  echo "$result"
}

# ── 80% pass rate 계산 ────────────────────────────────────────────────────
# 반환: 1 = pass_rate >= 0.8, 0 = 미달
_pass_rate_ok() {
  local criteria_json_path="$1"
  if [[ ! -f "$criteria_json_path" ]]; then
    echo "solo-budget: criteria file not found: $criteria_json_path" >&2
    return 1
  fi
  local result
  result="$(jq '
    (.must_pass | length) as $total |
    if $total == 0 then 0
    else
      ([ .must_pass[] | select(.status == "passed" or .status == "deferred") ] | length) as $ok_cnt |
      if (($ok_cnt / $total) >= 0.8) then 1 else 0 end
    end
  ' "$criteria_json_path")"
  echo "$result"
}

# ── 서브커맨드: limit-reached ─────────────────────────────────────────────
# 사용: limit-reached [criteria_json_path]
# 출력: cost | duration | iterations | graceful_ok | graceful_blocked_critical
#        | critical_pending | graceful_trigger | ok
cmd_limit_reached() {
  local criteria_json_path="${1:-}"

  local state
  state="$(_read_state)"
  local start_ts cost_usd iterations
  start_ts="$(echo "$state" | jq -r '.start_ts')"
  cost_usd="$(echo "$state" | jq -r '.cost_usd')"
  iterations="$(echo "$state" | jq -r '.iterations')"

  local elapsed_s elapsed_h
  elapsed_s="$(_elapsed_seconds "$start_ts")"
  elapsed_h="$(echo "scale=4; $elapsed_s / 3600" | bc)"

  # 한도 초과 판정 (우선순위 순)
  local cost_exceeded
  cost_exceeded="$(echo "$cost_usd >= $SOLO_MAX_COST_USD" | bc -l)"
  if [[ "$cost_exceeded" -eq 1 ]]; then
    echo "cost"
    return
  fi

  local dur_exceeded
  dur_exceeded="$(echo "$elapsed_h >= $SOLO_MAX_DURATION_H" | bc -l)"
  if [[ "$dur_exceeded" -eq 1 ]]; then
    echo "duration"
    return
  fi

  if [[ "$iterations" -ge "$SOLO_MAX_ITERATIONS" ]]; then
    echo "iterations"
    return
  fi

  # 80% rule graceful trigger (10h 기본)
  local graceful_exceeded
  graceful_exceeded="$(echo "$elapsed_h >= $SOLO_GRACEFUL_DURATION_H" | bc -l)"
  if [[ "$graceful_exceeded" -eq 1 ]]; then
    # criteria_json_path 없으면 기존 동작
    if [[ -z "$criteria_json_path" ]]; then
      echo "graceful_trigger"
      return
    fi

    local pass_ok critical_ok
    pass_ok="$(_pass_rate_ok "$criteria_json_path")"
    critical_ok="$(_critical_all_passed "$criteria_json_path")"

    if [[ "$pass_ok" -eq 1 && "$critical_ok" -eq 1 ]]; then
      # 10h 도달 + 80% pass + critical 100% → graceful_ok
      echo "graceful_ok"
      return
    fi

    if [[ "$pass_ok" -eq 1 && "$critical_ok" -eq 0 ]]; then
      # 10h 도달 + 80% pass + critical 미통과
      local hard12_exceeded
      hard12_exceeded="$(echo "$elapsed_h >= 12" | bc -l)"
      if [[ "$hard12_exceeded" -eq 1 ]]; then
        # 12h 도달 + critical 미통과 → critical_pending
        echo "critical_pending"
      else
        # 10h~12h + critical 미통과 → graceful_blocked_critical
        echo "graceful_blocked_critical"
      fi
      return
    fi

    # 80% 미달인 경우: criteria 있어도 graceful_trigger 유지
    echo "graceful_trigger"
    return
  fi

  echo "ok"
}

# ── 진입점 ────────────────────────────────────────────────────────────────
SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  init)          cmd_init "$@" ;;
  add-cost)      cmd_add_cost "$@" ;;
  inc-iter)      cmd_inc_iter ;;
  check)         cmd_check ;;
  recommend-tier) cmd_recommend_tier ;;
  limit-reached) cmd_limit_reached "$@" ;;
  *)
    cat >&2 <<'USAGE'
usage: solo-budget.sh <subcommand> [args]

subcommands:
  init <run_id>       초기화 (start_ts, cost_usd:0, iterations:0)
  add-cost <usd>      cost 누적
  inc-iter            iteration +1
  check               현재 상태 JSON 출력 (elapsed 포함)
  recommend-tier      다운그레이드 권장 tier (opus|sonnet|haiku)
  limit-reached [criteria_json_path]
                      한도 초과 검사 (cost|duration|iterations|graceful_ok|
                      graceful_blocked_critical|critical_pending|graceful_trigger|ok)

env overrides:
  SOLO_MAX_COST_USD          (default 20)
  SOLO_MAX_DURATION_H        (default 24)
  SOLO_GRACEFUL_DURATION_H   (default 10)
  SOLO_MAX_ITERATIONS        (default 100)
USAGE
    exit 1
    ;;
esac
