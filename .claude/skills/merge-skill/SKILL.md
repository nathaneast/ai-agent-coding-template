# Skill: merge-skill

로컬 경로의 스킬을 본 하네스에 흡수.

## 호출

`/merge-skill <source-path>`

## 알고리즘

1. `<source-path>`가 디렉터리면 `SKILL.md` 또는 SKILL.md 동등 파일 탐색
2. 본 하네스의 `.claude/skills/<basename>/` 에 복사 (덮어쓰기 전 백업)
3. (선택) `.codex/skills/<basename>/` 미러
4. `.claude-plugin/plugin.json` skills 배열에 추가 (이미 있으면 SKIP)
5. `.omc/learnings/_history.jsonl`에 흡수 이력 기록

## 호환성 검사

- SKILL.md 제목 형식 (`# Skill: <name>`)
- 마크다운 유효성
- 충돌하는 기존 스킬과의 의존성 (있으면 사용자 confirm)
