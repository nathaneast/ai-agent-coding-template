---
description: 이 하네스를 Claude Code용으로 셋업
---

# /setup-claude

이 하네스의 Claude Code 측 셋업을 검증/활성화한다.

## 실행 순서

1. `.claude/settings.json` 존재 및 SessionStart/SessionEnd 훅 등록 확인
2. `.claude/hooks/session-start.sh`, `session-end.sh` 실행 권한 확인
3. 5개 자동 주입 스킬 SKILL.md 존재 확인 (branch-strategy, tdd-loop, consensus-loop, env-security, session-index)
4. `.claude-plugin/plugin.json` 메타데이터 jq 검증
5. `.omc/learnings/` 4개 카테고리 파일 존재 확인
6. bats 테스트 통과 확인 (`bats .claude/hooks/tests/`)
7. SessionStart 훅 1회 시뮬레이션 (`bash .claude/hooks/session-start.sh | head -3`)
8. 결과 요약: PASS/FAIL + 누락 항목 목록

## 호출

`bash scripts/setup-claude.sh` 실행. 결과는 `04.docs/setup-claude.log`에 기록.
