# Skill: ss-re

매 세션 자동 주입. `/ss-re` 호출 또는 자연어("스냅샷 저장", "세션 저장")로 트리거 시 컨텍스트 스냅샷 저장.

## 트리거

- 슬래시: `/ss-re`
- 자연어: "스냅샷", "세션 저장", "snapshot save", "ss-re"

## 스냅샷 추출 알고리즘 (Claude가 수행)

다음 6가지를 마크다운으로 종합:

1. **현재 작업 (Now)**: 직전 사용자 메시지 + 직전 Claude 응답에서 핵심 작업 1~2줄
2. **진행 상황 (Done/InProgress)**: 이번 세션 Edit/Write 도구 호출 + TodoList completed 항목
3. **다음 즉시 단계 (Next)**: 1~3개. 사용자에게 묻고 있던 결정이 있으면 명시
4. **변경 파일 (Files)**: `git status --short` Bash 호출
5. **활성 모드 (Mode)**: ralph/일반 — `.omc/state/` 확인
6. **블로커 (Blockers)**: 사용자 결정 대기 항목 (있으면)
7. **(선택) 세션 ID**: `ls ~/.claude/projects/<repo-encoded>/*.jsonl | tail -1` 으로 추정

## 저장

Edit 도구로 `<project>/.omc/snapshot.md` 덮어쓰기:

```markdown
# Session Snapshot

> Saved: <ISO8601 UTC>
> Branch: <git branch>
> CWD: <path>

## Now
<현재 작업 1~2줄>

## Done
- <완료 항목 1>
- <완료 항목 2>

## Next
1. <다음 1>
2. <다음 2>

## Files
\`\`\`
<git status --short 출력>
\`\`\`

## Mode
<ralph/일반>

## Blockers
- <대기 항목> (없으면 "없음")

## Session ID (backup, --resume용)
<sessionId 또는 "추출 실패">
```

## 다음 세션 회수

SessionStart 훅이 `<project>/.omc/snapshot.md` 존재 시 stdout으로 inject. Claude는 첫 응답에서:

> 📍 직전 세션 스냅샷 복원했습니다.
> [Now/Next 요약]
> 그대로 진행할까요? (yes / 변경 / 취소)

사용자 응답 "yes" → 즉시 작업 재개.

## 안전장치

- snapshot.md 디렉토리 없으면 자동 생성
- 기존 파일 덮어쓰기 시 사용자 알림 ("기존 스냅샷 덮어씁니다" — 1줄)
- secret 패턴 자동 제외: `.env`, `*credentials*`, `password=`, `token=`, `sk-` 본문 포함 금지
