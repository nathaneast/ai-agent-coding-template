---
description: 현재 디렉토리에 01.spec~05.tasks + openspec 폴더 + .harness-active 마커 생성
---

# /pjt-init

빈 또는 기존 프로젝트 디렉토리에 본 하네스를 활성화한다.

## 인자

기본 — 인자 없음. 기본 동작.

## 동작

`bash ~/.claude/plugins/nathaneast-aiacht/scripts/pjt-init.sh`

1. 글로벌 위치(`~/.claude/plugins/nathaneast-aiacht/templates/project-init/`)에서 6 폴더 복사
2. `.harness-active` 마커 생성
3. `.gitignore`에 .env 보호 추가
4. 결과 안내

본 레포 자체(`.harness-main-only` 마커 존재)에서 호출 시 no-op + 안내 메시지.
