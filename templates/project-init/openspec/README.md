# OpenSpec — Spec-Driven Development

이 디렉터리는 OpenSpec 변경 제안과 완성된 명세를 보관한다.

## 구조

- `changes/<proposal-id>/` — 활성 변경 제안 (proposal.md, design.md, tasks.md, specs/)
- `specs/<spec-name>.md` — 완성된 명세 (archive된 변경 제안의 specs/ 내용이 이곳에 통합)
- `config.yaml` — OpenSpec 워크플로우 설정

## 흐름

1. `/openspec:propose <name>` — `changes/<name>/` 생성, proposal.md/design.md/tasks.md 초안
2. `/openspec:apply <name>` — proposal 검토 후 specs/ 통합
3. `/openspec:archive <name>` — 완료된 변경을 archive 처리

## 01.spec/ 와의 역할 분리

- `01.spec/` — PRD, 유저 스토리, ADR (사람이 직접 쓰는 자유 형식)
- `openspec/` — 구조화된 명세 (스킬 도구가 관리, propose → apply → archive 워크플로우)

상세: `02.workflow/spec-flow.md`
