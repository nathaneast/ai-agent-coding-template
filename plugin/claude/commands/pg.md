---
description: /solo 진행 상황 즉시 출력
allowed-tools:
  - Read
  - Bash
---

# /pg — Solo 진행 상황 출력

`.omc/state/` 의 세 파일을 읽어 현재 `/solo` 실행 상태를 한눈에 출력한다.

## 실행 절차

1. 아래 세 파일 존재 여부 확인:
   - `.omc/state/solo-criteria.json`
   - `.omc/state/solo-state.json`
   - `.omc/state/solo-budget.json`
2. 하나라도 없으면 즉시 출력:
   ```
   ❌ /solo 실행 중인 작업 없음
   ```
3. 모두 있으면 Read 도구로 읽은 뒤 아래 형식으로 출력한다.

## 출력 형식

```
🚧 /solo 진행 중 (run_id: {run_id})
Phase: {phase} / Round {round}
시간: {elapsed} / 24h
비용: ${cost_usd} / $20  {downgrade_warning}
Criteria: {pass_count}/{total} PASS, {in_progress_count} IN_PROGRESS, {deferred_count} DEFERRED
  ✅ {passed_ids}
  🔄 {in_progress_ids}
  ⏸ {deferred_ids}
직전 reflection: {last_reflection}
예상 종료: {eta}
```

## 필드 규칙

- `run_id`: `solo-criteria.json` 의 `run_id`
- `phase`, `round`: `solo-state.json` 의 `current_phase`, `current_round`
- `elapsed`: `solo-budget.json` 의 `elapsed_human` (예: `5h 12m`)
- `cost_usd`: `solo-budget.json` 의 `cost_usd`
- `downgrade_warning`: cost_usd >= 14 → `⚠ 다운그레이드 임박 ($15)` / >= 17 → `⚠ haiku 전환 임박 ($18)` / 미만 → 공백
- `passed_ids`: status == "passed" 인 항목 — id + critical이면 `(critical)` 표기
- `in_progress_ids`: status == "in_progress" 인 항목 — id, priority, attempts, current_agent
- `deferred_ids`: status == "deferred" 인 항목 — id + `(manual, deferred)`
- `last_reflection`: `solo-state.json` 의 `last_reflection` (없으면 `-`)
- `eta`: `solo-budget.json` 의 `eta` (없으면 `-`)
