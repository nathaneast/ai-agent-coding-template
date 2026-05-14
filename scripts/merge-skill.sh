#!/usr/bin/env bash
# v0.2.0: 기본 동작 = 로컬 스킬을 글로벌(`~/.claude/plugins/nathaneast-aiacht/plugin/claude/skills/`)로 promote + git commit
# 옵션: --push (commit + push), --squash <N> (여러 개 1 커밋)
set -euo pipefail

GLOBAL_DIR="$HOME/.claude/plugins/nathaneast-aiacht"
PLUGIN_SKILLS="$GLOBAL_DIR/plugin/claude/skills"
PLUGIN_MANIFEST="$GLOBAL_DIR/plugin/claude-plugin/plugin.json"

PUSH=0
SQUASH=0
declare -a SRCS

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) PUSH=1; shift ;;
    --squash) SQUASH=1; shift ;;
    -*) echo "unknown option: $1" >&2; exit 1 ;;
    *) SRCS+=("$1"); shift ;;
  esac
done

[[ ${#SRCS[@]} -eq 0 ]] && { echo "usage: merge-skill <skill-path> [<skill-path>...] [--push] [--squash]" >&2; exit 1; }

# 글로벌 설치 확인
if [[ ! -d "$GLOBAL_DIR/.git" ]]; then
  # 본 레포에서 직접 실행 (개발 모드)
  GLOBAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  PLUGIN_SKILLS="$GLOBAL_DIR/plugin/claude/skills"
  PLUGIN_MANIFEST="$GLOBAL_DIR/plugin/claude-plugin/plugin.json"
  echo "ℹ️  Dev mode: using $GLOBAL_DIR (not ~/.claude/plugins/nathaneast-aiacht)"
fi

declare -a PROMOTED_NAMES

for SRC in "${SRCS[@]}"; do
  # SKILL.md 위치 확인
  if [[ -d "$SRC" && -f "$SRC/SKILL.md" ]]; then
    SKILL_DIR="$SRC"
  elif [[ -f "$SRC" && "$(basename "$SRC")" == "SKILL.md" ]]; then
    SKILL_DIR="$(dirname "$SRC")"
  else
    echo "❌ SKILL.md 없음: $SRC" >&2
    exit 2
  fi

  NAME="$(basename "$SKILL_DIR")"
  TARGET="$PLUGIN_SKILLS/$NAME"

  # 기존 백업
  if [[ -d "$TARGET" ]]; then
    BACKUP="$TARGET.bak-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$TARGET" "$BACKUP"
    echo "ℹ️  기존 '$NAME' 백업: $BACKUP"
  fi

  # 복사
  mkdir -p "$TARGET"
  cp -r "$SKILL_DIR/." "$TARGET/"
  echo "✅ promoted: $NAME → $TARGET"
  PROMOTED_NAMES+=("$NAME")

  # plugin.json skills 배열 갱신
  if [[ -f "$PLUGIN_MANIFEST" ]]; then
    TMP=$(mktemp)
    jq --arg n "$NAME" '.skills = ((.skills // []) + [$n] | unique)' "$PLUGIN_MANIFEST" > "$TMP" && mv "$TMP" "$PLUGIN_MANIFEST"
  fi
done

# git commit
cd "$GLOBAL_DIR"
git add "$PLUGIN_SKILLS" "$PLUGIN_MANIFEST" 2>/dev/null || true

if [[ "$SQUASH" -eq 1 ]] || [[ ${#PROMOTED_NAMES[@]} -gt 1 ]]; then
  MSG="feat(skills): promote ${PROMOTED_NAMES[*]}"
  git commit -m "$MSG"
else
  MSG="feat(skill): promote ${PROMOTED_NAMES[0]}"
  git commit -m "$MSG"
fi
echo "✅ committed: $MSG"

# push (옵션)
if [[ "$PUSH" -eq 1 ]]; then
  git push origin main
  echo "✅ pushed to origin/main"
else
  echo ""
  echo "ℹ️  push 하려면: cd $GLOBAL_DIR && git push origin main"
  echo "   또는: bash scripts/merge-skill.sh ... --push"
fi
