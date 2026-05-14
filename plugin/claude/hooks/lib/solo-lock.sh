#!/usr/bin/env bash
set -euo pipefail

# solo-lock.sh — /solo 동시 실행 방지 락 관리
# 사용법:
#   solo-lock.sh acquire <run_id>   락 획득 시도
#   solo-lock.sh release             락 해제
#   solo-lock.sh check               현재 락 상태 출력

LOCK_DIR=".omc/locks"
LOCK_FILE="${LOCK_DIR}/solo.lock"
TTL_MIN="${SOLO_LOCK_TTL_MIN:-30}"
TTL_SEC=$(( TTL_MIN * 60 ))

# .omc/locks 디렉토리 자동 생성
mkdir -p "${LOCK_DIR}"

_now_epoch() {
  date +%s
}

_read_lock() {
  # 락 파일을 읽어 pid / expires_at / run_id 를 전역 변수에 세팅
  if [[ ! -f "${LOCK_FILE}" ]]; then
    return 1
  fi
  local content
  content="$(cat "${LOCK_FILE}")"
  LOCK_PID="$(printf '%s' "${content}" | grep -o '"pid":[0-9]*' | grep -o '[0-9]*')"
  LOCK_EXPIRES="$(printf '%s' "${content}" | grep -o '"expires_at":[0-9]*' | grep -o '[0-9]*')"
  LOCK_RUN_ID="$(printf '%s' "${content}" | grep -o '"run_id":"[^"]*"' | sed 's/"run_id":"//;s/"//')"
  return 0
}

_write_lock() {
  local pid="$1"
  local run_id="$2"
  local expires_at=$(( $(_now_epoch) + TTL_SEC ))
  local tmp="${LOCK_FILE}.tmp"
  printf '{"pid":%d,"expires_at":%d,"run_id":"%s"}\n' "${pid}" "${expires_at}" "${run_id}" > "${tmp}"
  mv "${tmp}" "${LOCK_FILE}"
}

_is_pid_alive() {
  local pid="$1"
  kill -0 "${pid}" 2>/dev/null
}

_lock_expired() {
  local expires_at="$1"
  local now
  now="$(_now_epoch)"
  [[ "${now}" -ge "${expires_at}" ]]
}

cmd_acquire() {
  local run_id="${1:-}"
  if [[ -z "${run_id}" ]]; then
    echo "ERROR: acquire 에 run_id 인자가 필요합니다." >&2
    exit 2
  fi

  if _read_lock; then
    # 락 파일이 존재함 — 만료 또는 PID 사망 여부 확인
    local stale=0

    if _lock_expired "${LOCK_EXPIRES}"; then
      stale=1
    elif ! _is_pid_alive "${LOCK_PID}"; then
      stale=1
    fi

    if [[ "${stale}" -eq 1 ]]; then
      # 만료/죽은 락 → 강제 획득
      rm -f "${LOCK_FILE}"
      _write_lock "$$" "${run_id}"
      echo "INFO: stale 락 제거 후 획득 (이전 run_id=${LOCK_RUN_ID}, pid=${LOCK_PID})" >&2
      exit 0
    else
      # 유효한 락이 존재 → 충돌
      local now
      now="$(_now_epoch)"
      local remaining=$(( LOCK_EXPIRES - now ))
      echo "ERROR: /solo 이미 실행 중입니다." >&2
      echo "  run_id   : ${LOCK_RUN_ID}" >&2
      echo "  pid      : ${LOCK_PID}" >&2
      echo "  expires  : ${LOCK_EXPIRES} (남은 ${remaining}초)" >&2
      echo "  락 해제하려면: solo-lock.sh release" >&2
      exit 1
    fi
  else
    # 락 파일 없음 → 새로 획득
    _write_lock "$$" "${run_id}"
    echo "INFO: 락 획득 (run_id=${run_id}, pid=$$)" >&2
    exit 0
  fi
}

cmd_release() {
  if [[ -f "${LOCK_FILE}" ]]; then
    rm -f "${LOCK_FILE}"
    echo "INFO: 락 해제됨" >&2
  fi
  # 락 파일이 없으면 silent
  exit 0
}

cmd_check() {
  if _read_lock; then
    local now
    now="$(_now_epoch)"
    local remaining=$(( LOCK_EXPIRES - now ))
    if _lock_expired "${LOCK_EXPIRES}"; then
      echo "EXPIRED"
      echo "  run_id   : ${LOCK_RUN_ID}"
      echo "  pid      : ${LOCK_PID}"
      echo "  만료됨 (${remaining}초 전)"
      exit 1
    elif ! _is_pid_alive "${LOCK_PID}"; then
      echo "STALE (PID ${LOCK_PID} 사망)"
      echo "  run_id   : ${LOCK_RUN_ID}"
      exit 1
    else
      echo "LOCKED"
      echo "  run_id   : ${LOCK_RUN_ID}"
      echo "  pid      : ${LOCK_PID}"
      echo "  expires  : ${LOCK_EXPIRES} (남은 ${remaining}초)"
      exit 0
    fi
  else
    echo "NO_LOCK"
    exit 1
  fi
}

cmd_check_markers() {
  local project_root="${1:-$(pwd)}"
  local main_only_marker="${project_root}/.harness-main-only"
  local active_marker="${project_root}/.harness-active"
  local has_main_only=0
  local has_active=0

  [[ -f "${main_only_marker}" ]] && has_main_only=1
  [[ -f "${active_marker}" ]]    && has_active=1

  if [[ "${has_main_only}" -eq 1 && "${has_active}" -eq 1 ]]; then
    echo "ERROR: 마커 충돌 — .harness-main-only 와 .harness-active 가 동시에 존재합니다." >&2
    echo "  경로: ${project_root}" >&2
    echo "  둘 중 하나를 제거하세요." >&2
    exit 2
  elif [[ "${has_main_only}" -eq 1 ]]; then
    echo "main-only"
    exit 0
  elif [[ "${has_active}" -eq 1 ]]; then
    echo "active"
    exit 0
  else
    echo "none"
    exit 0
  fi
}

# ── 진입점 ──────────────────────────────────────────────
SUBCMD="${1:-}"
shift || true

case "${SUBCMD}" in
  acquire)       cmd_acquire "$@" ;;
  release)       cmd_release ;;
  check)         cmd_check ;;
  check-markers) cmd_check_markers "$@" ;;
  *)
    echo "사용법: solo-lock.sh {acquire <run_id>|release|check|check-markers [프로젝트_경로]}" >&2
    exit 2
    ;;
esac
