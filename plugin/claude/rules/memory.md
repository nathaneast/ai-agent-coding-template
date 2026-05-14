# Rule: memory

본 하네스에서 메모리는 Claude Code native auto memory를 활용한다. 사용자가 "저장해", "기억해" 등 자연어 트리거 사용 시 Claude는 아래 분기에 따라 저장.

## 위치 분기 (사용자 발언 → 저장 위치)

| 사용자 발언 | 저장 파일 | 적용 범위 |
|------------|----------|----------|
| "저장해" / "기억해" / "메모해" (기본) | `<project>/CLAUDE.md` | 이 프로젝트 (git 추적, 팀 공유) |
| "내 PC에만" / "개인용으로" | `<project>/.claude/CLAUDE.local.md` | 이 프로젝트 + 개인 (gitignore) |
| "글로벌에" / "전역으로" / "모든 프로젝트에" | `~/.claude/CLAUDE.md` | 모든 프로젝트 + 모든 컴퓨터(머신 단위) |

## 저장 형식

각 entry는 timestamp 헤더 + 본문:
```markdown
## 2026-05-14T16:00:00Z
- raw Tailwind 우선 사용
```

## 회수

Claude Code가 매 세션 자동으로 3 파일 모두 컨텍스트에 로드. 별도 호출 불필요.

## 조회/편집

`/memory` 슬래시 커맨드 (Claude Code 공식) — 로드된 메모리 파일 리스트 + 편집기로 열기.

## 정리

파일이 너무 길어지면 사용자가 `/memory`로 열어 직접 정리. 자동 트림 없음.

## 본 하네스 글로벌 룰 (install.sh가 자동 등록)

`~/.claude/CLAUDE.md`에 다음 섹션 자동 append (idempotent):

```markdown
## nathaneast-aiacht
- "저장해" / "기억해" / "메모해" → 현재 프로젝트 CLAUDE.md
- "내 PC에만" / "개인용" → 현재 프로젝트 .claude/CLAUDE.local.md
- "글로벌에" / "전역" / "모든 프로젝트에" → 이 파일(~/.claude/CLAUDE.md)
- /ss-re → 현재 세션 컨텍스트 스냅샷 (.omc/snapshot.md)
```
