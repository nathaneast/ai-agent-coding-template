---
description: 로컬 스킬을 글로벌 본 레포로 promote (+commit)
---

# /merge-skill

로컬 프로젝트의 `.claude/skills/<name>/` 스킬을 본 글로벌 레포 `plugin/claude/skills/`로 복사 + 자동 commit.

## 사용

`/merge-skill ~/projects/A-app/.claude/skills/awesome` — 기본 promote + commit
`/merge-skill <path> --push` — promote + commit + git push origin main
`/merge-skill <a> <b> <c> --squash` — 여러 개를 1 커밋으로 묶음

## 동작

`bash ~/.claude/plugins/nathaneast-aiacht/scripts/merge-skill.sh <path> [<path>...] [--push] [--squash]`

1. 각 스킬 디렉토리(SKILL.md 포함)를 글로벌 `plugin/claude/skills/`로 복사 (백업 자동)
2. `plugin/claude-plugin/plugin.json` skills 배열 갱신
3. `git add + commit` 자동 (메시지: `feat(skill): promote <name>`)
4. `--push` 옵션 시 `git push origin main`
