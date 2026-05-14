# Skill: build

`/build "<PRD 또는 작업 설명>"` — 8~10시간 자동 빌드 진입점. ralph + consensus + openspec 통합.

## 흐름

1. PRD를 `spec/prd.md` 또는 `01.spec/prd.md`에 기록
2. ralph 모드 시작 + scripts/build-iteration-gate.sh wrapper로 다음 강제:
   - 매 Task TDD (테스트 먼저)
   - 매 Task 후 /consensus
   - 매 Task 단위 커밋
3. 완료까지 자동 반복

## 안전장치

- /consensus 3단 폴백 자동 (Codex 장애 시 critic 대체 → pause)
- Task 단위 커밋 강제 (build-iteration-gate.sh)
- max-hours 옵션 (기본 무제한, 권장 10시간)

## 호출

`/build "PRD: <description>"` 또는 `bash scripts/build.sh "<PRD>"`
