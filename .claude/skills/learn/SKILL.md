# Skill: learn

`/learn` 슬래시 커맨드로 호출. 학습을 `.omc/learnings/` 영속에 누적.

## 사용

`/learn "<카테고리>: <학습 내용>"` 또는 자유 형식.

카테고리: `preferences`, `pitfalls`, `patterns`, `glossary` 중 1개. 자유 형식이면 Claude가 분류 추정.

## 형식

각 entry는 다음 구조를 따른다:
- `- <한 줄 요약>. _Why_: <근거>. _When_: <적용 시점>. _Fix_: <조치 — pitfalls만>`

## 흐름

1. `/learn` 호출 시 입력 텍스트에서 카테고리 추출 (명시 or 추정)
2. `.omc/learnings/<category>.md`에 entry append (위 형식)
3. `_history.jsonl`에 메타 (timestamp, category, hash)
4. `_metrics.json`의 `learnings_added` 증가
5. 자동 트림 임계 초과 시 (`preferences`/`pitfalls` 200줄, `patterns`/`glossary` 100줄) → `_archive/{YYYY-MM}.md`로 가장 오래된 항목 이동

## 충돌 감지

기존 항목과 fuzzy match (Phase 3에서 도입 예정 trigram + Jaccard 0.7) 시 `_pending.jsonl`에 추가 + 사용자 confirm 대기 (`pending_unresolved` 카운터 증가).

## 회수

다음 세션 SessionStart 훅이 `.omc/learnings/*.md`를 자동 컨텍스트 주입. 회수 시 `learnings_recalled` 카운터 증가 (counter는 SessionStart에서 +1).

## 부트스트랩

Phase 2 셋업 직후 본 SKILL 활성. 슬래시 커맨드는 `.claude/commands/learn.md` 참조.
