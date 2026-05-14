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

echo ""
echo "Installed at $INSTALL_DIR"
echo "SessionStart hook registered in $SETTINGS"
echo ""
echo "Next:"
echo "  1) In a new project directory, start Claude Code"
echo "  2) Touch .harness-active to enable context injection"
echo "  3) Use /pjt-init to scaffold 01.spec/ ~ 05.tasks/ + openspec/"
