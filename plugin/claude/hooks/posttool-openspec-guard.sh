#!/usr/bin/env bash
# PostToolUse guard: warn if openspec/specs/*.md was directly edited
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
PATH_EDITED=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)

if [[ -n "$PATH_EDITED" ]] && [[ "$PATH_EDITED" == */openspec/specs/* ]]; then
  >&2 echo ""
  >&2 echo "⚠️  OpenSpec Guard: openspec/specs/*.md was edited directly."
  >&2 echo "   Recommended: use /openspec:apply <change-id> to integrate via workflow."
  >&2 echo "   Edited: $PATH_EDITED"
  >&2 echo ""
fi

exit 0
