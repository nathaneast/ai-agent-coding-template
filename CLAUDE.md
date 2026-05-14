# CLAUDE.md

본 프로젝트의 모든 강제 규칙, 워크플로우, 보안 정책은 아래 파일에 정의되어 있다. **반드시 준수**.

## 핵심 규칙 (필수 참조)

- 📌 [coding](.claude/rules/coding.md) — TypeScript 엄격, 파일 200줄, TDD 필수, 공통화 우선
- 📌 [project](.claude/rules/project.md) — 개발 순서, 환경 분리, 자동화 (MCP 적극 활용)
- 📌 [design](.claude/rules/design.md) — shadcn/ui + Tailwind CSS
- 📌 [user-interaction](.claude/rules/user-interaction.md) — 토스트 3초, 삭제 확인 모달
- 📌 [folder](.claude/rules/folder.md) — 폴더 운영 규칙

## 핵심 워크플로우 스킬 (자동 주입)

`.claude/hooks/session-start.sh`가 매 세션 자동 컨텍스트 주입. 즉시 효력 발생.

- 📌 [branch-strategy](.claude/skills/branch-strategy/SKILL.md) — 브랜치 전략 + 본 프로젝트 예외
- 📌 [tdd-loop](.claude/skills/tdd-loop/SKILL.md) — TDD Red → Green → 합의 → 커밋
- 📌 [consensus-loop](.claude/skills/consensus-loop/SKILL.md) — Codex 합의 루프 (필수)
- 📌 [env-security](.claude/skills/env-security/SKILL.md) — .env 절대 규칙
- 📌 [session-index](.claude/skills/session-index/SKILL.md) — 세션 인덱스 + /resume-session
- 📌 [user-helper](.claude/skills/user-helper/SKILL.md) — 사용자 비효율 자동 감지 → 1줄 제안 (반복/장황/좌절 신호)

## 본 프로젝트 특별 정책

본 프로젝트는 **셋업/하네스 템플릿 성격** — 일반 서비스와 다른 다음 예외 적용:

- **브랜치**: `main` 단일 운영 (dev/main 분리 예외)
- **마커**: 프로젝트 루트의 `.harness-main-only` 파일
- **글로벌 가드**: `~/.claude/hooks/branch-guard.sh` 룰 4가 이 마커 감지 시 main commit 허용

다른 모든 서비스 프로젝트는 위 일반 규칙(`.claude/rules/`)을 따른다.

## QA

CRUD + 유저 인터랙션 시나리오 목록 작성 → Playwright MCP로 1개씩 체크하며 진행.

## 더 자세히

- [README](./README.md) — 프로젝트 소개 + 빠른 시작
- [04.docs/RUNBOOK](./04.docs/RUNBOOK.md) — 일상 운영
- [04.docs/RELEASE_NOTES](./04.docs/RELEASE_NOTES.md) — 버전별 변경
- [04.docs/HANDOFF](./04.docs/HANDOFF.md) — 세션 간 인계 (보존)
