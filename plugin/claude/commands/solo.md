---
description: 자연어 또는 spec 파일로 완전 자율 실행 — 분석·완료조건·합의·실행·검증·커밋 7단계 자동화
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /solo — 완전 자율 실행 에이전트

자연어 한 줄 또는 spec 파일을 입력하면 planner가 검증 가능한 완료조건을 자동 설정하고,
Codex 합의 → 실행 루프 → 검증 → 커밋까지 7 phase를 자율 처리한다.

## 옵션 플래그

| 플래그 | 설명 |
|---|---|
| `--spec <path>` | 마크다운 spec 파일 경로로 입력 |
| `--notify discord\|telegram` | 종료 시 알림 전송 |
| `--isolated` | git worktree 격리 실행 |
| `--no-tdd` | TDD red-first 해제 (사유 자동 로깅) |
| `--resume` | 직전 phase에서 재개 |

## 사용 예시

```bash
/solo "토스 결제 위젯을 /payment 페이지에 통합"
/solo --spec ./01.spec/payment.md --notify discord
/solo --resume
```

## 진행 상황 확인

실행 중 언제든 `/pg` 로 현재 phase, criteria 통과율, 비용을 즉시 출력.

---

User invoked `/solo` — invoke the `solo` skill with the following arguments:

$ARGUMENTS
