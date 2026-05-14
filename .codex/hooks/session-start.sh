#!/usr/bin/env bash
# .codex/hooks/session-start.sh - Codex CLI wrapper
# Delegates to Claude hook for symmetric dual model behavior
exec "$(dirname "${BASH_SOURCE[0]}")/../../.claude/hooks/session-start.sh" "$@"
