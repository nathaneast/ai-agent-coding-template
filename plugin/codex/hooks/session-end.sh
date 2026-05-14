#!/usr/bin/env bash
exec "$(dirname "${BASH_SOURCE[0]}")/../../claude/hooks/session-end.sh" "$@"
