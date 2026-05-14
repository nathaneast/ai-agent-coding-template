#!/usr/bin/env bash
# push-global-memory.sh — Memory v0.4 글로벌 메모리 push 파이프라인 (3단계 트랜잭션)
#
# STAGE → COMMIT → PUSH (dual remote: yunjadong-team + nathaneast 미러).
# 호출: 본 레포 또는 설치본(~/.claude/plugins/nathaneast-aiacht/) 어디서나.

set -euo pipefail

# === Resolution ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT=""

# 실행 위치 판단: 본 레포 vs 설치본
if [[ -f "$SCRIPT_DIR/../.harness-main-only" ]]; then
  HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"  # 본 레포
else
  HARNESS_ROOT="$HOME/.claude/plugins/nathaneast-aiacht"  # 설치본
fi

if [[ ! -d "$HARNESS_ROOT/plugin/memory/user" ]]; then
  echo "ERROR: $HARNESS_ROOT/plugin/memory/user 없음. PR1 미적용?" >&2
  exit 1
fi

cd "$HARNESS_ROOT"

# === Stage 1: Pre-flight ===
echo "[1/3] STAGE — pre-flight 검사..."

# memory/ 외 변경 있으면 abort
if git status --porcelain | grep -v "^.. plugin/memory/" | grep -qE "^.."; then
  echo "ERROR: plugin/memory/ 외 변경 있음. 별도 커밋 후 재시도." >&2
  git status --porcelain | grep -v "^.. plugin/memory/" >&2
  exit 1
fi

# fetch + pull
git fetch origin main || { echo "ERROR: fetch 실패" >&2; exit 1; }
git pull --rebase --autostash origin main || { echo "ERROR: pull/rebase 실패. 충돌 해결 후 재시도." >&2; exit 1; }

# stage
git add plugin/memory/user/

# === Stage 2: Commit ===
echo "[2/3] COMMIT — staged 변경 검사..."

if git diff --cached --quiet; then
  echo "변경 없음. 종료."
  exit 0
fi

# auto summary
CHANGED_FILES=$(git diff --cached --name-only | wc -l | tr -d ' ')
SUMMARY="memory: update ${CHANGED_FILES} global memory file(s)"

git commit -m "$SUMMARY" || { echo "ERROR: commit 실패" >&2; exit 1; }
COMMIT_SHA=$(git rev-parse HEAD)
echo "Commit: $COMMIT_SHA"

# === Stage 3: Push (dual remote) ===
echo "[3/3] PUSH — yunjadong-team(메인) + nathaneast(미러)..."

# yunjadong-team push (ground truth)
if git push origin main; then
  echo "OK: yunjadong-team push 성공"
else
  echo "ERROR: yunjadong-team push 실패. local commit 유지. 재시도 또는 reset HEAD~1." >&2
  exit 1
fi

# nathaneast push (mirror, --force-with-lease)
if git remote | grep -q "^personal$"; then
  if git push personal main --force-with-lease; then
    echo "OK: nathaneast 미러 push 성공"
  else
    echo "WARN: nathaneast 미러 push 실패. 수동 mirror-personal.sh 실행 필요." >&2
  fi
else
  echo "INFO: personal remote 없음 — 미러 스킵. (gh remote add personal ... 추후)"
fi

# 검증
REMOTE_HEAD=$(git ls-remote origin main | awk '{print $1}')
if [[ "$REMOTE_HEAD" == "$COMMIT_SHA" ]]; then
  echo "OK: ls-remote 검증 통과"
else
  echo "WARN: 원격 HEAD($REMOTE_HEAD) != local HEAD($COMMIT_SHA)" >&2
fi

# === Report ===
echo ""
echo "Global memory push 완료"
echo "변경 파일: $CHANGED_FILES"
echo "다른 PC: bash ~/.claude/plugins/nathaneast-aiacht/scripts/update.sh"
