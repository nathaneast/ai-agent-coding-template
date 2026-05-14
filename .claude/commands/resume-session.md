---
description: N개 전 세션 컨텍스트 복원 (problem.md 해결)
---

# /resume-session

`.omc/sessions/index.json` 의 N번째 전 세션을 복원한다.

## 인자

`$ARGUMENTS` — 정수 N (1=가장 최근, 5=5개 전). 기본값 1.

## 실행

```bash
bash scripts/resume-session.sh ${ARGUMENTS:-1}
```

스크립트는 다음을 출력:
- 시나리오 A: `claude --resume <sessionId>` 명령 (사용자가 직접 실행)
- 시나리오 B: archive 본문을 stdout으로 출력 (현재 세션 컨텍스트로 통합)

## 사용 시점

새 세션 시작 직후, "어디서 이어서 작업할까요?" 라고 묻고 사용자가 `/resume-session 3` 같이 답하면 호출.
