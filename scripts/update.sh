#!/usr/bin/env bash
# nathaneast-aiacht 글로벌 도구 업데이트
set -euo pipefail

GLOBAL_DIR="$HOME/.claude/plugins/nathaneast-aiacht"

if [[ ! -d "$GLOBAL_DIR/.git" ]]; then
  echo "❌ 글로벌 설치 안 됨: $GLOBAL_DIR" >&2
  echo "   먼저 install.sh 실행" >&2
  exit 1
fi

cd "$GLOBAL_DIR"
echo "==> updating nathaneast-aiacht"
echo "    location: $GLOBAL_DIR"
echo ""

OLD_HEAD=$(git rev-parse HEAD)
git pull --ff-only

NEW_HEAD=$(git rev-parse HEAD)
if [[ "$OLD_HEAD" == "$NEW_HEAD" ]]; then
  echo "✅ Already up to date"
else
  echo "✅ Updated: $OLD_HEAD → $NEW_HEAD"
  echo ""
  echo "Changed files:"
  git diff --name-only "$OLD_HEAD" "$NEW_HEAD" | head -20
fi
