# Skill: openspec-apply

승인된 변경 제안의 specs/를 `openspec/specs/`로 통합.

## 호출

`/openspec:apply <change-id>`

## 알고리즘

1. `openspec/changes/<change-id>/specs/*.md`를 `openspec/specs/`로 복사/병합
2. `openspec/changes/<change-id>/tasks.md`의 미완료 항목 경고
3. 통합 후 `apply` 메타데이터를 변경 폴더에 기록

## 합의 의무

`/codex:review --wait` 합의 통과 필요. 부트스트랩 기간은 사용자 명시 confirm.
