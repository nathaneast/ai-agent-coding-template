# AGENTS.md — Codex CLI Entrypoint

이 프로젝트는 Claude Code와 Codex CLI 양쪽을 동시 지원하는 비대칭 듀얼 모델 하네스다.

## 핵심 규칙

이 프로젝트의 모든 강제 규칙, 워크플로우, 보안 정책은 **CLAUDE.md** 에 정의되어 있다. Codex CLI 사용자도 동일한 규칙을 따라야 한다.

> 📖 **[CLAUDE.md](./CLAUDE.md)** — 강제 규칙, 브랜치 전략, 합의 루프, TDD 워크플로우, QA, 보안

## Codex 역할 (비대칭 듀얼 모델)

- **Claude**: 메인 워커 (구현, 분석, 디버깅, 작업 수행)
- **Codex**: 리뷰어 (`/codex:review --wait`, `/codex:adversarial-review`)

Codex CLI는 본 프로젝트의 합의 루프에서 리뷰 전담이다. 직접 구현 작업은 Claude에 위임된다.

## 폴더 구조 빠른 참조

- `01.spec/` — PRD, 유저 스토리, ADR
- `02.workflow/` — SOP
- `03.archive/` — 완료 아카이브
- `04.docs/` — RUNBOOK, RELEASE_NOTES, HANDOFF
- `05.tasks/` — todo.md, prompt.md, feedback.md
- `openspec/` — OpenSpec changes/specs
- `policy/` — 기존 규칙 (Phase 6에서 `.claude/rules/`로 마이그레이션 예정)
- `.claude/`, `.codex/` — 도구별 hooks/commands/skills/rules
- `.omc/` — 도구 중립 영속 메모리 (learnings, sessions, plans, state)
- `.claude-plugin/`, `.codex-plugin/` — 마켓플레이스 등록 메타데이터

## 셋업

다음 명령으로 본 하네스를 활성화 (Phase 3에서 구현 예정):

- Claude Code 사용자: `/setup-claude`
- Codex CLI 사용자: `/setup-codex`
- 양쪽 모두: `/setup-both`
