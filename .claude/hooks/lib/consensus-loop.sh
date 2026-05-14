#!/usr/bin/env bash
# consensus-loop.sh
# Helper for /consensus: tracks loop count, parses VERDICT, manages fallback
# Actual Codex invocation is performed by Claude via slash command
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
METRICS="$REPO_ROOT/.omc/learnings/_metrics.json"
STATE_DIR="$REPO_ROOT/.omc/state"
MARKER="$STATE_DIR/USER_CONFIRM_NEEDED"

CMD="${1:-}"
shift || true

mkdir -p "$STATE_DIR"

case "$CMD" in
  start)
    TASK="${1:-}"
    [[ -z "$TASK" ]] && { echo "usage: consensus-loop.sh start <task>" >&2; exit 1; }
    SESSION_FILE="$STATE_DIR/consensus-$(date -u +%Y%m%dT%H%M%SZ).json"
    cat > "$SESSION_FILE" <<EOF
{
  "task": $(printf '%s' "$TASK" | jq -Rs .),
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "loop_count": 0,
  "max_loops": 4,
  "verdicts": [],
  "status": "running"
}
EOF
    echo "$SESSION_FILE"
    ;;

  parse-verdict)
    INPUT_TEXT="${1:-}"
    [[ -z "$INPUT_TEXT" ]] && { echo "REQUEST_CHANGES"; exit 0; }
    if echo "$INPUT_TEXT" | grep -qE 'VERDICT:\s*APPROVE'; then
      echo "APPROVE"; exit 0
    fi
    if echo "$INPUT_TEXT" | grep -qE 'VERDICT:\s*REQUEST_CHANGES'; then
      echo "REQUEST_CHANGES"; exit 0
    fi
    if echo "$INPUT_TEXT" | grep -qiE '(RECOMMENDATION|FINAL|OUTCOME|결론):\s*(APPROVE|GOOD|LGTM|ACCEPT|승인)'; then
      echo "APPROVE"; exit 0
    fi
    if echo "$INPUT_TEXT" | grep -qiE '(RECOMMENDATION|FINAL|OUTCOME|결론):\s*(REQUEST|REJECT|BLOCK|CHANGES|거부|수정)'; then
      echo "REQUEST_CHANGES"; exit 0
    fi
    approve_count=$(echo "$INPUT_TEXT" | grep -ciE '(approve|lgtm|승인|good)' || echo 0)
    reject_count=$(echo "$INPUT_TEXT" | grep -ciE '(reject|block|거부|수정)' || echo 0)
    if [[ "$approve_count" -gt "$reject_count" ]]; then
      echo "APPROVE"; exit 0
    fi
    echo "REQUEST_CHANGES"
    ;;

  iterate)
    SESSION_FILE="${1:-}"
    VERDICT="${2:-}"
    [[ -f "$SESSION_FILE" ]] || { echo "session not found" >&2; exit 1; }
    LC=$(jq -r '.loop_count' "$SESSION_FILE")
    MAX=$(jq -r '.max_loops' "$SESSION_FILE")
    NEW_LC=$((LC + 1))
    TMP=$(mktemp)
    jq --arg v "$VERDICT" --argjson lc "$NEW_LC" '.loop_count = $lc | .verdicts += [$v]' "$SESSION_FILE" > "$TMP" && mv "$TMP" "$SESSION_FILE"
    if command -v jq >/dev/null 2>&1 && [[ -f "$METRICS" ]]; then
      TMP2=$(mktemp)
      jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.counters.consensus_loops_total += 1 | .last_updated = $ts' "$METRICS" > "$TMP2" && mv "$TMP2" "$METRICS"
    fi
    if [[ "$VERDICT" == "APPROVE" ]]; then
      jq '.status = "approved"' "$SESSION_FILE" > "$TMP" && mv "$TMP" "$SESSION_FILE"
      if [[ "$NEW_LC" -eq 1 ]] && command -v jq >/dev/null 2>&1; then
        TMP3=$(mktemp)
        jq '.counters.consensus_first_pass += 1' "$METRICS" > "$TMP3" && mv "$TMP3" "$METRICS"
      fi
      echo "APPROVED (loop $NEW_LC)"
      exit 0
    fi
    if [[ "$NEW_LC" -ge "$MAX" ]]; then
      jq '.status = "max_loops_reached"' "$SESSION_FILE" > "$TMP" && mv "$TMP" "$SESSION_FILE"
      echo "MAX_LOOPS_REACHED — fallback required"
      exit 2
    fi
    echo "ITERATING (loop $NEW_LC/$MAX)"
    exit 1
    ;;

  fallback)
    SESSION_FILE="${1:-}"
    STAGE="${2:-1}"
    case "$STAGE" in
      1) echo "retry-codex" ;;
      2) echo "critic-substitute" ;;
      3)
        echo "pause-and-confirm"
        printf '{"created_at":"%s","reason":"consensus_fallback","session":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_FILE" > "$MARKER"
        ;;
      *) echo "invalid stage" >&2; exit 1 ;;
    esac
    ;;

  *)
    echo "usage: consensus-loop.sh {start|parse-verdict|iterate|fallback} ..." >&2
    exit 1
    ;;
esac
