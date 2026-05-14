#!/usr/bin/env bash
# archive-prompt.sh — archive a prompt to 05.tasks/prompt.md with Jaccard dedup
# Usage: archive-prompt.sh <text>
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROMPT="${1:-}"
[[ -z "$PROMPT" ]] && { echo "usage: archive-prompt.sh <text>" >&2; exit 1; }

ARCHIVE="$REPO_ROOT/05.tasks/prompt.md"
PENDING="$REPO_ROOT/.omc/learnings/_pending.jsonl"
mkdir -p "$REPO_ROOT/05.tasks" "$REPO_ROOT/.omc/learnings"
touch "$ARCHIVE" "$PENDING"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HASH="$(printf '%s' "$PROMPT" | shasum -a 256 | cut -d' ' -f1 | head -c 16)"

DUP_FOUND="false"; DUP_SIM="0.00"
if [[ -s "$ARCHIVE" ]]; then
  while IFS= read -r line; do
    line="${line#- }"
    # strip trailing metadata suffix  _(... )_
    line="$(printf '%s' "$line" | sed 's/ _(.*_$//')"
    [[ -z "$line" ]] && continue
    sim="$(bash "$REPO_ROOT/scripts/trigram-jaccard.sh" "$PROMPT" "$line" 2>/dev/null)"
    if awk -v a="$sim" -v t="0.7" 'BEGIN{ exit !(a>=t) }' 2>/dev/null; then
      DUP_FOUND="true"; DUP_SIM="$sim"
      printf '{"ts":"%s","hash":"%s","sim":%s,"prompt":%s}\n' "$TS" "$HASH" "$sim" "$(printf '%s' "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip()))')" >> "$PENDING"
      break
    fi
  done < <(grep -E '^- ' "$ARCHIVE" 2>/dev/null || true)
fi

if [[ "$DUP_FOUND" == "true" ]]; then
  count=$(grep -c "\"hash\":\"$HASH\"" "$PENDING" 2>/dev/null || echo 0)
  count=$(printf '%s' "$count" | tr -d '\n')
  echo "duplicate detected (Jaccard $DUP_SIM, occurrences $count)"
  if [[ "$count" -ge 3 ]] && ! grep -qF "- $PROMPT" "$ARCHIVE" 2>/dev/null; then
    printf -- '- %s _(promoted on %s after %s uses, hash %s)_\n' "$PROMPT" "$TS" "$count" "$HASH" >> "$ARCHIVE"
    echo "promoted to archive after $count uses"
  fi
  exit 0
fi

printf -- '- %s _(added %s, hash %s)_\n' "$PROMPT" "$TS" "$HASH" >> "$ARCHIVE"
echo "new prompt archived"
exit 0
