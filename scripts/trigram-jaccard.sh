#!/usr/bin/env bash
# trigram-jaccard.sh — POSIX shell trigram similarity (Jaccard)
# Usage:
#   trigram-jaccard.sh <text1> <text2>              → similarity 0.00~1.00
#   trigram-jaccard.sh --check <text> <file> <thr>  → best sim, exit 0 if >= thr
set -uo pipefail

trigrams_of() {
  local text="$1"
  local lower
  lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:][:punct:]' ' ' | sed 's/^ //; s/ $//')"
  local len=${#lower}
  [[ "$len" -lt 3 ]] && { printf '%s\n' "$lower"; return; }
  local i=0
  while [[ "$i" -le $((len - 3)) ]]; do
    printf '%s\n' "${lower:$i:3}"
    i=$((i + 1))
  done
}

jaccard() {
  local t1="$1" t2="$2"
  local tmp1 tmp2 inter union
  tmp1="$(mktemp)"; tmp2="$(mktemp)"
  trigrams_of "$t1" | sort -u > "$tmp1"
  trigrams_of "$t2" | sort -u > "$tmp2"
  inter="$(comm -12 "$tmp1" "$tmp2" | wc -l | tr -d ' ')"
  union="$(cat "$tmp1" "$tmp2" | sort -u | wc -l | tr -d ' ')"
  rm -f "$tmp1" "$tmp2"
  [[ "$union" -eq 0 ]] && { echo "0.00"; return; }
  awk -v i="$inter" -v u="$union" 'BEGIN { printf "%.2f", i/u }'
}

if [[ "${1:-}" == "--check" ]]; then
  TEXT="${2:-}"
  FILE="${3:-}"
  THRESHOLD="${4:-0.7}"
  [[ -z "$TEXT" || -z "$FILE" ]] && { echo "usage: trigram-jaccard.sh --check <text> <file> <threshold>" >&2; exit 2; }
  BEST_SIM="0.00"
  while IFS= read -r line; do
    line="${line#- }"
    [[ -z "$line" ]] && continue
    sim="$(jaccard "$TEXT" "$line")"
    if awk -v a="$sim" -v b="$BEST_SIM" 'BEGIN{ exit !(a>b) }' 2>/dev/null; then
      BEST_SIM="$sim"
    fi
  done < <(grep -E '^- ' "$FILE" 2>/dev/null || true)
  echo "$BEST_SIM"
  awk -v a="$BEST_SIM" -v t="$THRESHOLD" 'BEGIN{ exit !(a>=t) }'
else
  T1="${1:-}"
  T2="${2:-}"
  [[ -z "$T1" || -z "$T2" ]] && { echo "usage: trigram-jaccard.sh <text1> <text2>" >&2; exit 2; }
  jaccard "$T1" "$T2"
fi
