#!/usr/bin/env bash
set -euo pipefail

GLOBAL_DIR="$HOME/.claude/plugins/nathaneast-aiacht"
PERSONAL_URL="${PERSONAL_URL:-https://github.com/nathaneast/nathaneast-ai-agent-coding-template}"

if [[ ! -d "$GLOBAL_DIR/.git" ]]; then
  GLOBAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "ℹ️  Dev mode: using $GLOBAL_DIR"
fi

cd "$GLOBAL_DIR"

if ! git remote get-url personal >/dev/null 2>&1; then
  git remote add personal "$PERSONAL_URL"
  echo "→ remote 'personal' 추가: $PERSONAL_URL"
fi

CURRENT_BRANCH="$(git branch --show-current)"
git push personal "$CURRENT_BRANCH"
echo "✅ mirrored '$CURRENT_BRANCH' to $PERSONAL_URL"
