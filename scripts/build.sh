#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PRD="${*:-}"
[[ -z "$PRD" ]] && { echo "usage: build.sh \"<PRD description>\"" >&2; exit 1; }

# 1. Record PRD
mkdir -p 01.spec
PRD_FILE="templates/project-init/01.spec/prd-$(date -u +%Y%m%d-%H%M%S).md"
{
  echo "# PRD"
  echo ""
  echo "- Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Triggered by: /build"
  echo ""
  echo "## Description"
  echo ""
  echo "$PRD"
} > "$PRD_FILE"

echo "PRD recorded: $PRD_FILE"
echo ""
echo "Next: invoke /oh-my-claudecode:ralph with the PRD context"
echo "      The build-iteration-gate.sh wrapper enforces TDD + consensus + per-task commits"
