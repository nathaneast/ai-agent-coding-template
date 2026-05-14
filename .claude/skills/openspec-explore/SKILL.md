# Skill: openspec-explore

기존 변경 제안 / 명세 탐색.

## 호출

`/openspec:explore [--changes|--specs] [pattern]`

## 알고리즘

- `--changes`: `openspec/changes/*/proposal.md` 1줄 요약 + 상태
- `--specs`: `openspec/specs/*.md` 제목 + 마지막 수정 시각
- pattern: grep으로 본문 검색
