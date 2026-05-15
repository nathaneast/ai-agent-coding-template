#!/usr/bin/env bash
# nathaneast-ai-agent-coding-template installer
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/yunjadong-team/nathaneast-ai-agent-coding-template}"
INSTALL_DIR="$HOME/.claude/plugins/nathaneast-aiacht"
SETTINGS="$HOME/.claude/settings.json"

echo "==> nathaneast-aiacht installer"
echo "    target: $INSTALL_DIR"
echo ""

# 1. clone or pull
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "-> updating existing install"
  git -C "$INSTALL_DIR" pull --ff-only
else
  echo "-> cloning to $INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 2. SessionStart hook merge into global settings.json
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-$(date -u +%Y%m%d-%H%M%S)"

HOOK_PATH="$INSTALL_DIR/plugin/claude/hooks/session-start.sh"
TMP=$(mktemp)
jq --arg cmd "$HOOK_PATH" '
  .hooks = (.hooks // {}) |
  .hooks.SessionStart = (
    (.hooks.SessionStart // []) |
    if any(.[]; .hooks[]? | .command == $cmd) then .
    else . + [{"matcher":"startup|clear|compact","hooks":[{"type":"command","command":$cmd,"timeout":30}]}]
    end
  )
' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

chmod +x "$HOOK_PATH"

# 2.5. 슬래시 커맨드 글로벌 sync (~/.claude/commands/ 에 복사)
COMMANDS_SRC="$INSTALL_DIR/plugin/claude/commands"
COMMANDS_DST="$HOME/.claude/commands"
if [[ -d "$COMMANDS_SRC" ]]; then
  mkdir -p "$COMMANDS_DST"
  cp -f "$COMMANDS_SRC"/*.md "$COMMANDS_DST"/ 2>/dev/null || true
  CMD_COUNT=$(ls "$COMMANDS_SRC"/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "→ ${CMD_COUNT}개 슬래시 커맨드 sync → $COMMANDS_DST"
fi

# 2.6. Codex CLI 측 sync (~/.codex/) — 선택적, 미설치여도 hook 자산은 배치
CODEX_DIR="$HOME/.codex"
CODEX_SRC="$INSTALL_DIR/plugin/codex"
if [[ -d "$CODEX_SRC" ]]; then
  mkdir -p "$CODEX_DIR/hooks" "$CODEX_DIR/prompts" "$CODEX_DIR/skills"

  # hooks/session-start.sh → ~/.codex/hooks/session-start.sh + chmod +x
  CODEX_HOOK_SH="$CODEX_DIR/hooks/session-start.sh"
  cp -f "$CODEX_SRC/hooks/session-start.sh" "$CODEX_HOOK_SH"
  chmod +x "$CODEX_HOOK_SH"

  # hooks.json: 기존 oh-my-codex 등 다른 도구 등록 보존을 위해 SessionStart 배열에 append (중복 방지)
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

  # config.toml: 신규면 cp, 기존이면 [features] codex_hooks=true 만 idempotent merge
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

  # prompts/skills: 비어있을 수 있음. 있으면 sync
  [[ -n "$(ls -A "$CODEX_SRC/prompts" 2>/dev/null)" ]] && cp -rf "$CODEX_SRC/prompts/." "$CODEX_DIR/prompts/" 2>/dev/null || true
  [[ -n "$(ls -A "$CODEX_SRC/skills" 2>/dev/null)" ]]  && cp -rf "$CODEX_SRC/skills/." "$CODEX_DIR/skills/" 2>/dev/null || true

  echo "→ Codex CLI 자산 sync → $CODEX_DIR (config.toml + hooks.json + hooks/session-start.sh)"

  if ! command -v codex >/dev/null 2>&1; then
    echo "ℹ Codex CLI 미설치 — 사용하려면: npm i -g @openai/codex"
  fi
fi

# 3. 글로벌 ~/.claude/CLAUDE.md에 nathaneast-aiacht 섹션 등록 (idempotent)
GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
MARKER="## nathaneast-aiacht"

if [[ ! -f "$GLOBAL_CLAUDE" ]] || ! grep -q "$MARKER" "$GLOBAL_CLAUDE"; then
  touch "$GLOBAL_CLAUDE"
  cat >> "$GLOBAL_CLAUDE" <<'EOF'

## nathaneast-aiacht
- "저장해" / "기억해" / "메모해" → 현재 프로젝트 CLAUDE.md
- "내 PC에만" / "개인용" → 현재 프로젝트 .claude/CLAUDE.local.md
- "글로벌에" / "전역" / "모든 프로젝트에" → 이 파일(~/.claude/CLAUDE.md)
- /ss-re → 현재 세션 컨텍스트 스냅샷 (.omc/snapshot.md)
EOF
  echo "→ 글로벌 ~/.claude/CLAUDE.md에 nathaneast-aiacht 섹션 등록"
else
  echo "→ ~/.claude/CLAUDE.md에 이미 nathaneast-aiacht 섹션 있음 (skip)"
fi

echo ""
echo "Installed at $INSTALL_DIR"
echo "SessionStart hook registered in $SETTINGS"
echo ""
echo "Next:"
echo "  1) In a new project directory, start Claude Code"
echo "  2) Touch .harness-active to enable context injection"
echo "  3) Use /pjt-init to scaffold 01.spec/ ~ 05.tasks/ + openspec/"
