#!/usr/bin/env bash
# .claude/hooks/session-end.sh
# 세션 종료: KPI 카운터 + sessions/index.json append + archive dump
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LEARNINGS_DIR="$REPO_ROOT/.omc/learnings"
SESSIONS_DIR="$REPO_ROOT/.omc/sessions"
mkdir -p "$SESSIONS_DIR/archive"

INPUT=""
[[ -t 0 ]] || INPUT="$(cat 2>/dev/null || true)"

# Extract sessionId from stdin JSON (Claude Code 형식) — fallback to UUID
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // .sessionId // empty' 2>/dev/null || true)"
if [[ -z "$SESSION_ID" ]]; then
  if command -v uuidgen >/dev/null 2>&1; then
    SESSION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  else
    SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  fi
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE="$(date -u +%Y-%m-%d)"
BRANCH="$(cd "$REPO_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
CWD="$REPO_ROOT"

# Last 5 changed files (uncommitted + recent commits)
LAST_FILES_JSON="$(cd "$REPO_ROOT" && {
  (git diff --name-only HEAD 2>/dev/null; git log --name-only --pretty=format: -5 2>/dev/null) \
    | grep -v '^$' | sort -u | head -5 | jq -Rs 'split("\n") | map(select(length>0))'
} || echo '[]')"

# Last 5 commit SHAs
LAST_COMMITS_JSON="$(cd "$REPO_ROOT" && git log --pretty=format:'%H' -5 2>/dev/null | jq -Rs 'split("\n") | map(select(length>0))' || echo '[]')"

# Summary attempt: from stdin or fallback
SUMMARY="$(printf '%s' "$INPUT" | jq -r '.summary // empty' 2>/dev/null || true)"
[[ -z "$SUMMARY" ]] && SUMMARY="Session ended at $TS on $BRANCH"

ARCHIVE_PATH="$SESSIONS_DIR/archive/${DATE}-${SESSION_ID}.md"

# Write archive body
{
  echo "# Session Archive — ${SESSION_ID}"
  echo ""
  echo "- Date: ${TS}"
  echo "- Branch: ${BRANCH}"
  echo "- CWD: ${CWD}"
  echo "- Summary: ${SUMMARY}"
  echo ""
  echo "## Last 5 Files Touched"
  echo ""
  printf '%s\n' "$LAST_FILES_JSON" | jq -r '.[] | "- \(.)"' 2>/dev/null || echo "(none)"
  echo ""
  echo "## Last 5 Commits"
  echo ""
  (cd "$REPO_ROOT" && git log --pretty=format:'- %h %s (%an, %ar)' -5 2>/dev/null) || echo "(none)"
  echo ""
  echo "## Session End Stdin"
  echo ""
  echo '```json'
  printf '%s\n' "$INPUT"
  echo '```'
} > "$ARCHIVE_PATH"

# Append to index.json (atomic via temp + mv)
INDEX="$SESSIONS_DIR/index.json"
[[ -f "$INDEX" ]] || echo "[]" > "$INDEX"

NEW_ENTRY=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg ts "$TS" \
  --arg br "$BRANCH" \
  --arg cwd "$CWD" \
  --arg summary "$SUMMARY" \
  --argjson lf "$LAST_FILES_JSON" \
  --argjson lc "$LAST_COMMITS_JSON" \
  --arg ap "$ARCHIVE_PATH" \
  '{sessionId: $sid, timestamp: $ts, branch: $br, cwd: $cwd, summary: $summary, lastFiles: $lf, lastCommits: $lc, archivePath: $ap}')

TMP=$(mktemp)
jq --argjson new "$NEW_ENTRY" '. += [$new] | (if length > 50 then .[length-50:] else . end)' "$INDEX" > "$TMP" && mv "$TMP" "$INDEX"

# KPI counter: learnings_recalled += 1 (previous session injected learnings)
METRICS="$LEARNINGS_DIR/_metrics.json"
if [[ -f "$METRICS" ]] && command -v jq >/dev/null 2>&1; then
  TMP2=$(mktemp)
  jq --arg ts "$TS" '.counters.learnings_recalled += 1 | .last_updated = $ts' "$METRICS" > "$TMP2" && mv "$TMP2" "$METRICS"
fi

exit 0
