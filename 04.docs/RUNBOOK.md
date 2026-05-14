# RUNBOOK

## 일상 워크플로우

### 새 Task 시작
1. `/double-check "<지시>"` — 이해 확인 (KPI 카운터)
2. 테스트 작성 (TDD Red)
3. 구현 작성 (TDD Green)
4. `/codex:review --wait` 또는 `/consensus "<task>"`
5. 합의 도달 → Task 단위 커밋

### 세션 재개
- `--continue` 가능: 즉시 사용
- 2~3개 전 세션: `/resume-session 2` 또는 `bash scripts/resume-session.sh 2`

### 학습 누적
- `/learn preferences: <text>` 또는 `bash .claude/hooks/lib/learn-add.sh patterns "..."`
- 다음 세션 SessionStart 자동 회수

### 빌드
- 일반: 사용자 옆에서 단계별 진행
- 무인: `/build "<PRD>"` → ralph 자동 (Codex 장애 시 pause)

## 트러블슈팅

### 권한 prompt 반복
- 글로벌 `~/.claude/settings.json` 의 `permissions.defaultMode` = `"bypassPermissions"` 확인
- 프로젝트 `.claude/settings.local.json` 의 광범위 allow 확인

### 합의 루프 무한 진행
- max-loops 4 도달 시 자동 fallback (`.omc/state/USER_CONFIRM_NEEDED` 마커)
- 다음 세션 시작 시 알림 표시

### 세션 인덱스 cap 50
- 자동 트림. 본문 archive는 유지 (`.omc/sessions/archive/`)

## 백업 / 복구

- 글로벌 settings.json: `~/.claude/settings.json.bak-*`
- 학습 archive: `.omc/learnings/_archive/{YYYY-MM}.md`
- 세션 archive: `.omc/sessions/archive/{date}-{sessionId}.md`
