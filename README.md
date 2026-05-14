# ai-agent-coding-template

> 개인 맞춤형 AI 코딩 하네스 — Claude 메인 워커 + Codex 리뷰어 비대칭 듀얼 모델

## 핵심

- **SessionStart 훅 자동 주입**: 매 세션 5개 워크플로우 스킬 자동 컨텍스트화 (~7K 토큰 budget)
- **`/learn` 영속 학습**: `.omc/learnings/{preferences,pitfalls,patterns,glossary}.md` 누적, 카테고리별 자동 트림
- **`/consensus` 합의 루프**: Claude 작업 → Codex 리뷰 → max-loops 4 + 3단 폴백
- **`/resume-session N`**: N개 전 세션 컨텍스트 복원 (problem.md 해결)
- **`/setup-claude` / `/setup-codex` / `/setup-both`**: 양쪽 어댑터 검증
- **`/double-check`**: 사용자 지시 5요소 더블체크
- **자동 프롬프트 아카이빙**: trigram + Jaccard 0.7 중복 감지, 3회 promotion
- **`/merge-skill`**: 로컬 스킬 본 하네스에 흡수
- **`/build`**: PRD 기반 ralph 자동 빌드 + iteration gate

## 빠른 시작

```bash
# 1. 셋업 검증
bash scripts/setup-both.sh

# 2. 테스트 통과 확인
bats .claude/hooks/tests/

# 3. SessionStart 훅 작동 확인 (~7K 토큰)
bash .claude/hooks/session-start.sh | wc -c
```

## 폴더 구조

- `01.spec/` PRD, ADR
- `02.workflow/` SOP
- `04.docs/` RUNBOOK, RELEASE_NOTES, HANDOFF, ONBOARDING
- `05.tasks/` todo, prompt 아카이브
- `openspec/` 구조화 명세 (propose → apply → archive)
- `.claude/`, `.codex/` 도구별 hooks/commands/skills/rules
- `.omc/` 도구 중립 영속 메모리 (learnings, sessions, plans)

## 회사계정 복제

```bash
bash scripts/clone-to-company.sh ~/company-coding/my-new-project
```

상세: `04.docs/ONBOARDING.md`

## License

MIT
