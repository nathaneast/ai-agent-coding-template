# Skill: consensus-loop

매 세션 자동 주입. 모든 설계/개발/QA는 Codex 합의 루프 의무.

## 호출 방식

- 자동: `/consensus "<task>"` 슬래시 커맨드 (Phase 4 도입)
- 수동: 합의 루프 절차를 한 단계씩 직접 호출

## 자동 합의 루프 알고리즘 (`/consensus`)

```
LOOP_COUNT=0
MAX_LOOPS=4
while [[ $LOOP_COUNT -lt $MAX_LOOPS ]]; do
  1. Claude가 작업/수정 수행
  2. /codex:review --wait (또는 /codex:adversarial-review --wait)
  3. Codex 응답에서 VERDICT 추출
     - APPROVE → 종결, Task 단위 커밋
     - REQUEST_CHANGES → 피드백 반영 → LOOP_COUNT++
  4. LOOP_COUNT == MAX_LOOPS:
     - 3단 폴백 진입 (§10.3 참조)
done
```

## VERDICT 토큰 파싱 (3단 폴백)

1. **1차**: 정확 매칭 `VERDICT: APPROVE` / `VERDICT: REQUEST_CHANGES`
2. **2차**: 동의어 매칭 `RECOMMENDATION:` / `FINAL:` / `결론:` / `OUTCOME:`
3. **3차**: 본문 키워드 검색 + 사용자 1회 confirm (`approve`/`reject` 빈도)
4. **실패**: 기본값 REQUEST_CHANGES (안전)

## Codex 장애 3단 폴백 (§10.3)

`/consensus`가 Codex 호출 실패/timeout 시:
1. **1단**: Codex 재시도 (최대 3회, exponential backoff 5/10/20초)
2. **2단**: OMC `critic` agent 대체 리뷰 (사용자 사전 승인 필요)
3. **3단**: ralph 일시정지 + `.omc/state/USER_CONFIRM_NEEDED` 마커 작성. 다음 사용자 세션에서 알림.

## 강제 규칙

- 합의 없이 구현 확정 금지
- Codex 리뷰는 `codex-plugin-cc` 스킬 경유만. MCP `mcp__x__ask_codex` 직접 호출 금지 (부트스트랩 정보 수집 예외 §7-bis).
- max-loops 4 초과 시 자동 진행 금지. 사용자 confirm 필요.

## KPI 카운터

- `consensus_first_pass`: 1회 만에 APPROVE 받은 비율
- `consensus_loops_total`: 누적 합의 사이클 횟수

## 부트스트랩 예외

Phase 0~3은 본격 `/consensus` 없이 슬래시 명시 호출(`/codex:review --wait`)이 임시 합의 경로. Phase 4 도입 후 부트스트랩 종료.

## 빠른 참조

- `/codex:review` 표준 리뷰
- `/codex:adversarial-review` 도전 리뷰
- `/codex:rescue` 막힌 문제 위임
- `/codex:status`, `/codex:result` 상태/결과
