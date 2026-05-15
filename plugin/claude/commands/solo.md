---
description: 자연어/spec → 분석·완료조건·합의·실행·검증·커밋 7단계 자율 실행 (어느 프로젝트든 동작)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task
---

# /solo — 완전 자율 빌드 에이전트

`/solo "작업"` 또는 `/solo --spec ./01.spec/feature.md` 호출. planner가 검증 가능한 완료조건을 자동 설정하고 Codex 합의 → 실행 루프 → 검증 → 커밋까지 7 phase 자율 처리.

## 실행 절차 (Claude main)

1. **SKILL 로드**: 다음 파일을 Read
   - 우선: 현재 작업 디렉토리에 `plugin/claude/skills/solo/SKILL.md` 가 있으면 그 파일
   - 폴백: `/Users/nathaneast/.claude/plugins/nathaneast-aiacht/plugin/claude/skills/solo/SKILL.md`

2. **PLUGIN_LIB 결정** (헬퍼 스크립트 경로):
   - 우선: 현재 디렉토리 `plugin/claude/hooks/lib/` 존재 시 → 절대경로 사용
   - 폴백: `/Users/nathaneast/.claude/plugins/nathaneast-aiacht/plugin/claude/hooks/lib/`

3. **SKILL.md 본문 따라 실행**:
   - SKILL.md 내 `plugin/claude/hooks/lib/solo-X.sh` 모든 호출을 → `$PLUGIN_LIB/solo-X.sh` 로 치환해서 실행
   - 예: `bash plugin/claude/hooks/lib/solo-triage.sh` → `bash /Users/nathaneast/.claude/plugins/nathaneast-aiacht/plugin/claude/hooks/lib/solo-triage.sh`
   - Phase 0~6 의사코드 그대로 수행

4. **상태 파일 위치**: 현재 작업 디렉토리 기준 `.omc/state/`, `.omc/plans/`, `.omc/logs/solo/`, `.omc/locks/`, `solo-result/` 사용 (현재 프로젝트에 산출).

## 옵션 플래그

| 플래그 | 동작 |
|---|---|
| `--spec <path>` | 마크다운 spec 파일 입력 |
| `--notify discord\|telegram` | 종료 시 알림 |
| `--isolated` | git worktree 격리 실행 |
| `--no-tdd` | TDD red-first 해제 (사유 자동 로깅) |
| `--resume` | 직전 phase에서 재개 |

## 사용 예시

```
/solo "토스 결제 위젯을 /payment 페이지에 통합"
/solo --spec ./01.spec/payment.md --notify discord
/solo --resume
```

## 진행 상황

실행 중 언제든 `/pg` 입력 → 현재 phase / criteria 통과율 / 비용 즉시 출력.

## 안전장치

- `.env*` 가드 (절대), Codex 합의 (절대), critical 100% 의무
- 비용 cap $20 ($15/$18 자동 다운그레이드), 시간 cap 24h
- 동시 실행 락, 마커 충돌 검사, push/PR 자동 안 함

---

User invoked `/solo` with arguments:

$ARGUMENTS
