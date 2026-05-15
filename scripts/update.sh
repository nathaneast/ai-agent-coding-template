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

# 슬래시 커맨드 sync (~/.claude/commands/ 에 항상 최신본 반영)
COMMANDS_SRC="$GLOBAL_DIR/plugin/claude/commands"
COMMANDS_DST="$HOME/.claude/commands"
if [[ -d "$COMMANDS_SRC" ]]; then
  mkdir -p "$COMMANDS_DST"
  cp -f "$COMMANDS_SRC"/*.md "$COMMANDS_DST"/ 2>/dev/null || true
  CMD_COUNT=$(ls "$COMMANDS_SRC"/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo ""
  echo "→ ${CMD_COUNT}개 슬래시 커맨드 sync → $COMMANDS_DST"
fi

# Codex CLI 측 sync (~/.codex/) — install.sh와 동일 절차 (idempotent)
CODEX_DIR="$HOME/.codex"
CODEX_SRC="$GLOBAL_DIR/plugin/codex"
if [[ -d "$CODEX_SRC" ]]; then
  mkdir -p "$CODEX_DIR/hooks" "$CODEX_DIR/prompts" "$CODEX_DIR/skills"
  CODEX_HOOK_SH="$CODEX_DIR/hooks/session-start.sh"
  cp -f "$CODEX_SRC/hooks/session-start.sh" "$CODEX_HOOK_SH"
  chmod +x "$CODEX_HOOK_SH"
  if [[ -f "$CODEX_DIR/hooks.json" ]]; then
    HAS=$(jq --arg cmd "$CODEX_HOOK_SH" \
      '[.hooks.SessionStart[]?.hooks[]? | select(.command == $cmd)] | length' \
      "$CODEX_DIR/hooks.json" 2>/dev/null || echo 0)
    if [[ "$HAS" == "0" ]]; then
      TMP=$(mktemp)
      jq --arg cmd "$CODEX_HOOK_SH" \
        '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{matcher:"startup|clear|compact", hooks:[{type:"command", command:$cmd, timeout:30}]}])' \
        "$CODEX_DIR/hooks.json" > "$TMP" && mv "$TMP" "$CODEX_DIR/hooks.json"
    fi
  else
    jq --arg cmd "$CODEX_HOOK_SH" \
      '.hooks.SessionStart[0].hooks[0].command = $cmd' \
      "$CODEX_SRC/hooks.json" > "$CODEX_DIR/hooks.json"
  fi
  if [[ ! -f "$CODEX_DIR/config.toml" ]]; then
    cp "$CODEX_SRC/config.toml" "$CODEX_DIR/config.toml"
  elif ! grep -q "codex_hooks = true" "$CODEX_DIR/config.toml" 2>/dev/null; then
    cp "$CODEX_DIR/config.toml" "$CODEX_DIR/config.toml.bak-$(date -u +%Y%m%d-%H%M%S)"
    {
      echo ""
      echo "# nathaneast-aiacht hooks (auto-appended)"
      echo "[features]"
      echo "codex_hooks = true"
    } >> "$CODEX_DIR/config.toml"
  fi
  [[ -n "$(ls -A "$CODEX_SRC/prompts" 2>/dev/null)" ]] && cp -rf "$CODEX_SRC/prompts/." "$CODEX_DIR/prompts/" 2>/dev/null || true
  [[ -n "$(ls -A "$CODEX_SRC/skills" 2>/dev/null)" ]]  && cp -rf "$CODEX_SRC/skills/." "$CODEX_DIR/skills/" 2>/dev/null || true
  echo "→ Codex CLI 자산 sync → $CODEX_DIR"
fi
