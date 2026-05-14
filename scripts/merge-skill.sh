#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SRC="${1:-}"
[[ -z "$SRC" ]] && { echo "usage: merge-skill.sh <source-path>" >&2; exit 1; }
[[ -e "$SRC" ]] || { echo "source not found: $SRC" >&2; exit 2; }

# Resolve SKILL.md
SKILL_FILE=""
if [[ -d "$SRC" ]]; then
  if [[ -f "$SRC/SKILL.md" ]]; then SKILL_FILE="$SRC/SKILL.md"; fi
elif [[ -f "$SRC" ]] && [[ "$(basename "$SRC")" == "SKILL.md" ]]; then
  SKILL_FILE="$SRC"
fi
[[ -z "$SKILL_FILE" ]] && { echo "no SKILL.md found in $SRC" >&2; exit 3; }

NAME="$(grep -oE '^# Skill: [a-zA-Z0-9_-]+' "$SKILL_FILE" | head -1 | sed 's/^# Skill: //')"
if [[ -z "$NAME" ]]; then
  NAME="$(basename "$(dirname "$SKILL_FILE")")"
fi

TARGET_DIR="$REPO_ROOT/.claude/skills/$NAME"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ -d "$TARGET_DIR" ]]; then
  BACKUP="$TARGET_DIR.bak-$(date -u +%Y%m%dT%H%M%SZ)"
  mv "$TARGET_DIR" "$BACKUP"
  echo "existing skill backed up to $BACKUP"
fi

mkdir -p "$TARGET_DIR"
cp -r "$(dirname "$SKILL_FILE")/." "$TARGET_DIR/"
echo "merged skill '$NAME' to $TARGET_DIR"

# Update plugin.json skills array if not present
PLUGIN="$REPO_ROOT/.claude-plugin/plugin.json"
if [[ -f "$PLUGIN" ]] && command -v jq >/dev/null 2>&1; then
  EXISTS=$(jq --arg n "$NAME" '.skills | index($n)' "$PLUGIN")
  if [[ "$EXISTS" == "null" ]]; then
    TMP=$(mktemp)
    jq --arg n "$NAME" '.skills += [$n]' "$PLUGIN" > "$TMP" && mv "$TMP" "$PLUGIN"
    echo "added '$NAME' to plugin.json skills"
  fi
fi

# History append
HIST="$REPO_ROOT/.omc/learnings/_history.jsonl"
mkdir -p "$(dirname "$HIST")"; touch "$HIST"
printf '{"ts":"%s","action":"merge-skill","name":"%s","source":%s}\n' "$TS" "$NAME" "$(printf '%s' "$SRC" | jq -Rs .)" >> "$HIST"
echo "history logged"
