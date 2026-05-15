---
description: 로컬 파일/디렉토리 경로를 받아 종류 자동 판별 후 본 하네스 글로벌 레포로 병합 (commit, 옵션 --push)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /merge-solo — 다목적 자동 병합

로컬 파일/디렉토리 경로(여러 개 OK)를 받으면 Claude가 각각의 종류를 판별하고 본 하네스 글로벌 레포(`~/.claude/plugins/nathaneast-aiacht/`)의 올바른 위치로 복사한 뒤 commit 한다. `--push` 옵션 시 origin/nathaneast-old 양쪽 push.

## 사용 예

```
/merge-solo ~/projects/A/.claude/skills/awesome
/merge-solo ~/projects/A/.claude/commands/foo.md ~/projects/A/.claude/hooks/bar.sh
/merge-solo ./my-rule.md ./my-hook.sh --push
/merge-solo ~/temp/agents/checker.md --dry-run
```

## 인자

- 위치 인자: 1개 이상의 로컬 파일/디렉토리 절대/상대 경로 (공백 구분)
- `--push`: commit 후 `origin` + `nathaneast-old` 양쪽 push (기본은 commit만)
- `--dry-run`: 실제 복사/commit 하지 않고 라우팅 계획만 출력

## 종류 판별 매핑 (Claude가 따를 규칙)

| 입력 패턴 | 종류 | 목적지 (글로벌 레포 기준) |
|---|---|---|
| 디렉토리에 `SKILL.md` 포함 | skill | `plugin/claude/skills/<name>/` (디렉토리 통째로) |
| 단일 `*.md` + 부모가 `commands/` 또는 frontmatter에 `description:` | command | `plugin/claude/commands/<name>.md` |
| `*.sh` + 부모가 `hooks/lib/` | hook 헬퍼 | `plugin/claude/hooks/lib/<name>.sh` |
| `*.sh` + 부모가 `hooks/`(lib 아님) | hook 본체 | `plugin/claude/hooks/<name>.sh` |
| `*.md` + 부모가 `rules/` | rule | `plugin/claude/rules/<name>.md` |
| `*.md` + 부모가 `agents/` | agent | `plugin/claude/agents/<name>.md` |
| `*.md` + 부모가 `memory/user/` 또는 `06.memory/` | memory | `plugin/memory/user/<name>.md` |
| 일치 패턴 없음 | unknown | **사용자 1회 확인** (cancel / 강제 위치 지정) |

부모 디렉토리가 명확하지 않으면 파일 내용·확장자로 판단:
- `*.sh` → hook (chmod +x 적용)
- frontmatter `description:` 있는 `.md` → command
- `SKILL.md` 형식이면 → skill (부모 디렉토리 이름이 스킬명)

## 실행 절차

1. **인자 파싱**: 옵션 (`--push`, `--dry-run`) 분리, 나머지를 입력 경로로
2. **경로 존재 검증**: 모든 입력 경로가 실제 존재하는지 확인. 없으면 stderr + 중단
3. **종류 판별**: 각 경로에 위 매핑 적용. 일치 못 하는 항목은 사용자 1회 확인
4. **계획 출력** (`--dry-run` 또는 시작 직전):
   ```
   📋 병합 계획:
     [skill]   ~/projects/A/.claude/skills/awesome  →  plugin/claude/skills/awesome/
     [command] ~/projects/A/.claude/commands/foo.md →  plugin/claude/commands/foo.md
     [hook]    ~/temp/check.sh                       →  plugin/claude/hooks/lib/check.sh
   ```
5. `--dry-run`이면 여기서 종료
6. **복사 실행** (Bash):
   - 디렉토리: `cp -r <src> <dst>`
   - 파일: `cp -f <src> <dst>`
   - `.sh`는 `chmod +x` 자동
   - 글로벌 레포 위치는 `$HOME/.claude/plugins/nathaneast-aiacht/`
7. **commit** (Bash):
   - 글로벌 레포 안에서: `git add <변경된 파일들 명시>`
   - 메시지: `feat(merge-solo): <항목 N개> 병합 — <축약>` (한국어)
   - `--no-verify` 안 씀
8. **push** (`--push` 있을 때):
   - `git push origin main` + `git push nathaneast-old main`
9. **결과 보고** (한국어, 5~8줄):
   - 복사된 파일 수, 종류 카운트
   - commit sha
   - push 여부
   - 다른 PC 동기화 명령 안내: `bash ~/.claude/plugins/nathaneast-aiacht/scripts/update.sh`

## 안전장치

- `.env*` 패턴 감지 → 즉시 ABORT
- 시크릿 의심 패턴(`sk-`, `xoxb-`, `ghp_`, `BEGIN PRIVATE KEY` 등) → 사용자 확인
- 글로벌 레포가 dirty (uncommitted) → stash 권장 + 사용자 확인
- 글로벌 레포 브랜치 ≠ main → 경고 후 사용자 확인 (본 레포는 `.harness-main-only` 마커로 main 단독 운영)
- 같은 이름 파일이 이미 존재 → diff 미리보기 후 사용자 확인 (overwrite/skip)

## 인자 부재

`$ARGUMENTS`가 비어있으면 사용법 안내 + 중단.

---

User invoked `/merge-solo` with arguments:

$ARGUMENTS
