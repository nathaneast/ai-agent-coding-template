# Skill: openspec-propose

새 변경 제안을 `openspec/changes/<name>/` 에 생성.

## 호출

`/openspec:propose <change-id> "<one-line description>"`

## 알고리즘

1. `openspec/changes/<change-id>/` 디렉터리 생성
2. 다음 4개 파일 초안 생성:
   - `proposal.md` — 변경 이유, 영향 범위, 트레이드오프
   - `design.md` — 기술 설계, 의사결정 근거
   - `tasks.md` — Task 분해 (체크리스트)
   - `specs/` — 신규/수정 명세 디렉터리

## proposal.md 템플릿

```markdown
# Proposal: <change-id>

## 배경

## 변경 내용

## 영향 범위 (Impact)

## 대안 검토

## 위험 / 트레이드오프

## 합의 도달 시 다음 단계

`/openspec:apply <change-id>` 호출 → specs/ 통합 → archive 이동
```
