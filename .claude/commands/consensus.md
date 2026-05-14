---
description: Claude 작업 → Codex 리뷰 → 합의 도달까지 자동 루프
---

# /consensus

사용자가 작업을 지시하면 자동으로 합의 루프를 돌린다. max-loops 4 + 3단 폴백.

## 인자

`$ARGUMENTS` — 합의 대상 작업 설명 (예: "auth 모듈 리팩터링", "테스트 추가")

## 실행

```
bash .claude/hooks/lib/consensus-loop.sh "$ARGUMENTS"
```

스크립트는 Claude의 작업 수행 후 `/codex:review --wait`를 반복 호출, VERDICT 파싱, max-loops 또는 합의까지 진행.

## 부트스트랩 기간 사용 제한

Phase 4 도입 직후이므로, 무인 빌드(`/build`)에서는 max-loops와 알림이 필수 활성. 사용자 부재 중에는 폴백 3단(일시정지) 권장.
