# Spec Flow — 01.spec/ vs openspec/

본 프로젝트는 두 가지 spec 시스템을 동시에 사용한다.

## 01.spec/ — 자유 형식 spec (사람이 직접)

- PRD (제품 요구사항)
- 유저 스토리
- ADR (Architecture Decision Records)
- 기획자/PM이 직접 쓰는 문서

## openspec/ — 구조화 spec (도구 관리)

- changes/<id>/ 변경 제안 워크플로우 (propose → apply → archive)
- specs/<name>.md 완성된 명세
- `/openspec:propose`, `/openspec:apply`, `/openspec:archive`, `/openspec:explore`

## 결합

PRD/스토리(`01.spec/`)에서 시작 → 구현이 필요해진 부분만 `/openspec:propose`로 변경 제안 → 합의 통과 후 `/openspec:apply`로 `openspec/specs/`에 명세 확정.

## 직접 편집 금지

`openspec/specs/*.md`를 직접 편집하면 PostToolUse 훅이 경고한다. 항상 `changes/<id>/` 워크플로우 거쳐야 함.
