#!/usr/bin/env bash
# Resume N-th most recent session
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

N="${1:-1}"
INDEX="$REPO_ROOT/.omc/sessions/index.json"

if [[ ! -f "$INDEX" ]] || [[ "$(jq 'length' "$INDEX" 2>/dev/null || echo 0)" -eq 0 ]]; then
  echo "No session index found at $INDEX"
  exit 1
fi

LEN=$(jq 'length' "$INDEX")
if [[ "$N" -gt "$LEN" ]]; then
  echo "Only $LEN sessions available (requested N=$N)"
  exit 2
fi

# N=1 → last entry (-1), N=2 → -2, ...
IDX=$((LEN - N))
ENTRY=$(jq ".[$IDX]" "$INDEX")
SID=$(echo "$ENTRY" | jq -r '.sessionId')
TS=$(echo "$ENTRY" | jq -r '.timestamp')
SUMMARY=$(echo "$ENTRY" | jq -r '.summary')
ARCHIVE=$(echo "$ENTRY" | jq -r '.archivePath')

echo "=== Resuming session $N of $LEN ==="
echo "- sessionId: $SID"
echo "- timestamp: $TS"
echo "- summary: $SUMMARY"
echo "- archive: $ARCHIVE"
echo ""
echo "### Scenario A (if --resume works in your Claude Code):"
echo "    claude --resume $SID"
echo ""
echo "### Scenario B (archive injection — default):"
echo ""
if [[ -f "$ARCHIVE" ]]; then
  echo "--- archive body start ---"
  cat "$ARCHIVE"
  echo "--- archive body end ---"
else
  echo "(archive body not found at $ARCHIVE — only metadata available)"
fi
