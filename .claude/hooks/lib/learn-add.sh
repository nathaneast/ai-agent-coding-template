#!/usr/bin/env bash
# 학습 추가: 카테고리별 .md에 append + _history.jsonl 메타 + _metrics.json 카운터
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LEARNINGS_DIR="$REPO_ROOT/.omc/learnings"

CATEGORY="${1:-}"
TEXT="${2:-}"

if [[ -z "$CATEGORY" || -z "$TEXT" ]]; then
  echo "usage: learn-add.sh <category> <text>" >&2
  exit 1
fi

case "$CATEGORY" in
  preferences|pitfalls|patterns|glossary) ;;
  *) echo "invalid category: $CATEGORY" >&2; exit 2 ;;
esac

TARGET="$LEARNINGS_DIR/$CATEGORY.md"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HASH="$(printf '%s' "$TEXT" | shasum -a 256 | cut -d' ' -f1 | head -c 16)"

# Append entry
printf -- '- %s _(added %s, %s)_\n' "$TEXT" "$TS" "$HASH" >> "$TARGET"

# History append
printf '{"ts":"%s","category":"%s","hash":"%s","len":%d}\n' "$TS" "$CATEGORY" "$HASH" "${#TEXT}" >> "$LEARNINGS_DIR/_history.jsonl"

# Metrics counter
METRICS="$LEARNINGS_DIR/_metrics.json"
if command -v jq >/dev/null 2>&1; then
  TMP="$(mktemp)"
  jq --arg ts "$TS" '.counters.learnings_added += 1 | .last_updated = $ts' "$METRICS" > "$TMP" && mv "$TMP" "$METRICS"
fi

# Auto-trim
LIMIT=200
[[ "$CATEGORY" == "patterns" || "$CATEGORY" == "glossary" ]] && LIMIT=100

LINES=$(wc -l < "$TARGET" | tr -d ' ')
if [[ "$LINES" -gt "$LIMIT" ]]; then
  ARCHIVE_MONTH="$(date -u +%Y-%m)"
  ARCHIVE_FILE="$LEARNINGS_DIR/_archive/${ARCHIVE_MONTH}.md"
  mkdir -p "$LEARNINGS_DIR/_archive"
  TO_ARCHIVE=$((LINES - LIMIT))
  printf '\n## Archived from %s on %s (%d lines)\n\n' "$CATEGORY" "$TS" "$TO_ARCHIVE" >> "$ARCHIVE_FILE"
  head -n "$TO_ARCHIVE" "$TARGET" >> "$ARCHIVE_FILE"
  tail -n +"$((TO_ARCHIVE + 1))" "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"
fi

echo "added to $CATEGORY ($LINES lines, limit $LIMIT)"
