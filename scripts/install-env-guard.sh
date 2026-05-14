#!/usr/bin/env bash
# Install env-security guards: .gitignore + .claude/settings.json deny rules
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Ensure .env* is in .gitignore
if [[ -f .gitignore ]]; then
  grep -q "^\.env$" .gitignore 2>/dev/null || echo ".env" >> .gitignore
  grep -q "^\.env\.\*$" .gitignore 2>/dev/null || echo ".env.*" >> .gitignore
fi

# Ensure settings.json deny includes env
if [[ -f .claude/settings.json ]] && command -v jq >/dev/null 2>&1; then
  TMP=$(mktemp)
  jq '
    .permissions.deny = ((.permissions.deny // []) + ["Read(.env*)", "Edit(.env*)", "Write(.env*)"] | unique)
  ' .claude/settings.json > "$TMP" && mv "$TMP" .claude/settings.json
fi

echo "env-guard installed"
