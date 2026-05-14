---
description: 사용자 지시 이해를 5요소(목표/범위/수용/제약/위험)로 더블체크 (double-check 축약)
---

# /dbck

사용자가 직전에 준 지시를 받아 5요소로 분해하고 사용자 확인을 요청한다.

## 인자

`$ARGUMENTS` — 더블체크할 지시 텍스트 (또는 직전 사용자 메시지)

## 실행

1. `bash plugin/claude/hooks/lib/double-check-incr.sh` (KPI 카운터 +1)
2. LLM이 5요소 답변 생성:
   - 🎯 **목표 (Goal)**: 무엇을 달성하려는가?
   - 📦 **범위 (Scope)**: 무엇이 포함/제외되는가?
   - ✅ **수용 기준 (Acceptance)**: 무엇이 "완료"인가?
   - ⚠️ **제약 (Constraints)**: 시간/품질/도구 제약?
   - 🚧 **위험 (Risks)**: 어디가 모호한가?
3. 마지막에 "이대로 맞나요? 아니면 X/Y/Z 중 수정?" 명시
