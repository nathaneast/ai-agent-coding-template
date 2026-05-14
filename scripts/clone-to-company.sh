#!/usr/bin/env bash
# Clone this harness for company account use.
# Removes personal state, scrubs git history, prepares fresh remote.
set -uo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"
[[ -z "$TARGET" ]] && { echo "usage: clone-to-company.sh <target-path>" >&2; exit 1; }

if [[ -e "$TARGET" ]]; then
  echo "target exists: $TARGET" >&2; exit 2
fi

echo "=== Step 1/3: Copying harness to $TARGET ==="
mkdir -p "$TARGET"
# Use rsync to exclude personal files
EXCLUDE=(
  ".git"
  ".env"
  ".env.*"
  ".claude/settings.local.json"
  ".codex/settings.local.json"
  ".omc/state"
  ".omc/logs"
  ".omc/sessions"
  ".omc/learnings/_history.jsonl"
  ".omc/learnings/_pending.jsonl"
  "node_modules"
  "dist"
  "build"
)
RSYNC_ARGS=()
for e in "${EXCLUDE[@]}"; do RSYNC_ARGS+=("--exclude=$e"); done

if command -v rsync >/dev/null 2>&1; then
  rsync -a "${RSYNC_ARGS[@]}" "$SOURCE/" "$TARGET/"
else
  cp -r "$SOURCE/." "$TARGET/"
  for e in "${EXCLUDE[@]}"; do rm -rf "$TARGET/$e"; done
fi

echo "=== Step 2/3: Resetting git + scrubbing personal data ==="
cd "$TARGET"
rm -rf .git
git init -q -b dev
git add -A
git commit -q -m "chore: clone harness from personal account (scrubbed)"

# Reset _metrics.json counters
if [[ -f .omc/learnings/_metrics.json ]] && command -v jq >/dev/null 2>&1; then
  jq '.counters = (.counters | with_entries(.value = 0)) | .last_updated = now' .omc/learnings/_metrics.json > /tmp/metrics.tmp && mv /tmp/metrics.tmp .omc/learnings/_metrics.json
fi

echo "=== Step 3/3: Installing env-guard ==="
bash "$TARGET/scripts/install-env-guard.sh" 2>/dev/null || echo "(env-guard script not found, skipping)"

echo ""
echo "Clone complete: $TARGET"
echo ""
echo "Next steps (manual):"
echo "  cd $TARGET"
echo "  git remote add origin <company-github-url>"
echo "  git push -u origin dev"
echo ""
echo "Personal files excluded:"
for e in "${EXCLUDE[@]}"; do echo "  - $e"; done
