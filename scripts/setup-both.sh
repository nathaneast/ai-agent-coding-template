#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== /setup-claude ==="
bash scripts/setup-claude.sh
claude_status=$?

echo ""
echo "=== /setup-codex ==="
bash scripts/setup-codex.sh
codex_status=$?

echo ""
echo "=== diff: Claude vs Codex SessionStart output ==="
bash .claude/hooks/session-start.sh > /tmp/claude-out.$$  2>/dev/null
bash .codex/hooks/session-start.sh > /tmp/codex-out.$$ 2>/dev/null
if diff -q /tmp/claude-out.$$ /tmp/codex-out.$$ >/dev/null; then
  echo "✅ Identical output (dual model symmetric)"
  diff_status=0
else
  echo "❌ Diverged output"
  diff_status=1
fi
rm -f /tmp/claude-out.$$ /tmp/codex-out.$$

if [[ "$claude_status" -eq 0 && "$codex_status" -eq 0 && "$diff_status" -eq 0 ]]; then
  echo ""; echo "✅ /setup-both PASS"; exit 0
else
  echo ""; echo "❌ /setup-both FAIL"; exit 1
fi
