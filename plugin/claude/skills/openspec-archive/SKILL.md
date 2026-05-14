# Skill: openspec-archive

완료된 변경 제안을 archive 처리.

## 호출

`/openspec:archive <change-id>`

## 알고리즘

1. `openspec/changes/<change-id>/` → `openspec/changes/_archive/<YYYY-MM>-<change-id>/` 이동
2. `_archive/` 인덱스 갱신 (`_archive/INDEX.md`)
3. 통합된 specs는 `openspec/specs/`에 잔존
