---
description: 학습을 .omc/learnings/에 영속 누적
---

# /learn

사용자 텍스트를 받아 `.omc/learnings/<category>.md`에 append.

## 인자
- `$ARGUMENTS` — 학습 텍스트 (카테고리 prefix 권장, 예: "preferences: 미니멀 셋업 선호")

## 알고리즘

1. `$ARGUMENTS`에서 첫 토큰이 `preferences:`/`pitfalls:`/`patterns:`/`glossary:` 중 하나면 그 카테고리. 아니면 LLM이 추정.
2. `bash .claude/hooks/lib/learn-add.sh "<category>" "<text>"` 실행 (스크립트는 Phase 2.4에서 생성)
3. 결과 출력: 추가된 entry + 카테고리 + 현재 학습 항목 개수

## 예시

```
/learn preferences: 미니멀 셋업 우선. Why: 내일부터 사용. When: 새 스킬 추가.
```

→ `.omc/learnings/preferences.md`에 entry append.
