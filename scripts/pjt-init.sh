#!/usr/bin/env bash
set -euo pipefail

PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
GLOBAL_TEMPLATES="$HOME/.claude/plugins/nathaneast-aiacht/templates/project-init"

# 본 레포 자체에서 호출 시 no-op
if [[ -f "$PROJECT_CWD/.harness-main-only" ]]; then
  echo "ℹ️  본 레포(source-repo)에서는 /pjt-init 동작 안 함 — 이미 모든 폴더 보유"
  exit 0
fi

# 글로벌 설치 확인
if [[ ! -d "$GLOBAL_TEMPLATES" ]]; then
  # 본 레포에서 직접 실행하는 경우 fallback
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ -d "$REPO_ROOT/templates/project-init" ]]; then
    GLOBAL_TEMPLATES="$REPO_ROOT/templates/project-init"
    echo "→ Using local repo templates: $GLOBAL_TEMPLATES"
  else
    echo "❌ 글로벌 설치 위치 없음: $GLOBAL_TEMPLATES" >&2
    echo "   먼저 install.sh 실행하세요" >&2
    exit 1
  fi
fi

echo "==> /pjt-init"
echo "    target: $PROJECT_CWD"
echo ""

# 6 폴더 복사 (기존 컨텐츠 보존)
for dir in 01.spec 02.workflow 03.archive 04.docs 05.tasks openspec; do
  if [[ -d "$PROJECT_CWD/$dir" ]]; then
    echo "→ $dir/ 이미 존재 — 건너뜀"
  else
    cp -r "$GLOBAL_TEMPLATES/$dir" "$PROJECT_CWD/"
    echo "→ $dir/ 생성"
  fi
done

# 마커 생성
if [[ ! -f "$PROJECT_CWD/.harness-active" ]]; then
  cat > "$PROJECT_CWD/.harness-active" <<EOF
# Harness Active Marker
# 본 프로젝트는 nathaneast-ai-agent-coding-template 하네스를 사용한다.
# 글로벌 SessionStart 훅이 이 마커를 감지하여 5 스킬 자동 컨텍스트 주입.
# 마커 삭제 시 본 프로젝트에서 하네스 비활성화.
EOF
  echo "→ .harness-active 마커 생성"
fi

# .gitignore .env 보호
GITIGNORE="$PROJECT_CWD/.gitignore"
touch "$GITIGNORE"
if ! grep -q "^\.env$" "$GITIGNORE" 2>/dev/null; then
  cat >> "$GITIGNORE" <<'EOF'

# .env protection (added by /pjt-init)
.env
.env.*
!.env.example
EOF
  echo "→ .gitignore에 .env 보호 추가"
fi

echo ""
echo "✅ 완료. 다음 Claude Code 세션부터 자동 컨텍스트 주입 시작."
echo "   확인: cd $PROJECT_CWD && claude"
