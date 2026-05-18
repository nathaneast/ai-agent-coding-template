#!/usr/bin/env bash
set -euo pipefail

solo_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

solo_harness_dir() {
  printf '%s/.harness\n' "$(solo_repo_root)"
}

solo_state_dir() {
  printf '%s/state\n' "$(solo_harness_dir)"
}

solo_runs_dir() {
  printf '%s/runs\n' "$(solo_harness_dir)"
}

solo_reports_dir() {
  printf '%s/reports\n' "$(solo_harness_dir)"
}

solo_spec_path() {
  printf '%s/01.spec/harness-spec.json\n' "$(solo_repo_root)"
}

solo_now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

solo_new_run_id() {
  date -u +%Y%m%dT%H%M%SZ
}

solo_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "solo: jq is required" >&2
    exit 1
  fi
}

solo_init_dirs() {
  local root
  root="$(solo_repo_root)"
  mkdir -p \
    "$root/01.spec" \
    "$(solo_state_dir)" \
    "$(solo_runs_dir)" \
    "$(solo_reports_dir)" \
    "$root/.omc/state" \
    "$root/.omc/plans" \
    "$root/solo-result"
}

solo_atomic_write() {
  local target="$1"
  local content="$2"
  local tmp
  mkdir -p "$(dirname "$target")"
  tmp="$(mktemp "${target}.XXXXXX")"
  printf '%s\n' "$content" > "$tmp"
  mv "$tmp" "$target"
}

solo_current_run_id() {
  local f
  f="$(solo_state_dir)/current-run-id"
  [[ -f "$f" ]] && cat "$f"
}

solo_require_run_id() {
  local run_id
  run_id="$(solo_current_run_id || true)"
  if [[ -z "$run_id" ]]; then
    echo "solo: no active run. run /solo first." >&2
    exit 1
  fi
  printf '%s\n' "$run_id"
}

solo_run_dir() {
  local run_id="$1"
  printf '%s/%s\n' "$(solo_runs_dir)" "$run_id"
}

solo_state_file() {
  printf '%s/solo-state.json\n' "$(solo_state_dir)"
}

solo_omc_state_file() {
  printf '%s/.omc/state/solo-state.json\n' "$(solo_repo_root)"
}

solo_is_unsafe_verify_cmd() {
  local cmd="$1"
  case "$cmd" in
    *".env"*|*"git push"*|*"gh pr create"*|*"rm -rf /"*|*"sudo "*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Default per-criteria verify timeout in seconds.
SOLO_VERIFY_TIMEOUT_DEFAULT="${SOLO_VERIFY_TIMEOUT_DEFAULT:-300}"

# Returns 0 if the command matches a weak/tautological pattern (e.g. --help only,
# echo/true, py_compile, test -f, short python -c) OR is wrapped in an exit-code
# masking suffix (|| true, ; exit 0, etc.) that hides verify failures.
solo_is_weak_verify_cmd() {
  local cmd="$1"
  local trimmed
  trimmed="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  # Exit-code masking: trailing "|| true", "|| :", "|| exit 0", "; true", "; :",
  # "; exit 0" forces success regardless of failure. Always weak, even if chained.
  if printf '%s' "$trimmed" | grep -Eq '(\|\||;)[[:space:]]*(true|:|exit[[:space:]]+0)[[:space:]]*$'; then return 0; fi
  # Skip if the command is piped or chained — assume the chain adds real checks.
  # Note: || is allowed here only because masking was caught above; legitimate
  # || (e.g. "cmd || echo failed && false") is rare and should be reviewed.
  case "$trimmed" in
    *"|"*|*"&&"*|*";"*|*">"*) return 1 ;;
  esac
  # Patterns that should never count as real verification.
  if printf '%s' "$trimmed" | grep -Eq '^(echo|true|false|:)([[:space:]].*)?$'; then return 0; fi
  if printf '%s' "$trimmed" | grep -Eq '^printf([[:space:]].*)?$'; then return 0; fi
  if printf '%s' "$trimmed" | grep -Eq '(^|[[:space:]])(--help|--version|-h|-V)[[:space:]]*$'; then return 0; fi
  if printf '%s' "$trimmed" | grep -Eq '(^|[[:space:]])py_compile([[:space:]]|$)'; then return 0; fi
  if printf '%s' "$trimmed" | grep -Eq '^test[[:space:]]+-[xefd][[:space:]]+\S+[[:space:]]*$'; then return 0; fi
  if printf '%s' "$trimmed" | grep -Eq '^python3?[[:space:]]+-c[[:space:]]+["'\''].{0,40}["'\'']$'; then return 0; fi
  return 1
}

# Compute the outcome enum from solo-criteria.json.
# Echoes one of: done | blocked:verify_failed | blocked:needs_user | partial:N/M | running
# Reads must_pass[].status values: passed|failed|needs_user|pending.
solo_compute_outcome() {
  local criteria_file="$1"
  if [[ ! -f "$criteria_file" ]]; then
    printf 'blocked:needs_user\n'
    return 0
  fi
  jq -r '
    .must_pass as $list |
    ($list | length) as $total |
    ($list | map(select(.mode == "manual" or .mode == "manual_pending")) | length) as $manual |
    ($list | map(select(.mode == "auto" or .mode == "hybrid")) | length) as $auto_total |
    ($list | map(select((.mode == "auto" or .mode == "hybrid") and .status == "passed")) | length) as $auto_passed |
    ($list | map(select((.mode == "auto" or .mode == "hybrid") and .status == "failed")) | length) as $auto_failed |
    ($list | map(select((.mode == "manual" or .mode == "manual_pending") and .status == "passed")) | length) as $manual_acked |
    if $total == 0 then "blocked:needs_user"
    elif $auto_failed > 0 then "blocked:verify_failed"
    elif $auto_passed < $auto_total then "partial:\($auto_passed)/\($total)"
    elif $manual > 0 and $manual_acked < $manual then "blocked:needs_user"
    else "done"
    end
  ' "$criteria_file"
}
