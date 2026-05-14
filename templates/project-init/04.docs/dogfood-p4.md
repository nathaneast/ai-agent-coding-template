# Dogfood P4 — /consensus 흐름 검증

Phase 4 gate: 5/5 PASS

## 시나리오 P4-1: parse-verdict 정확 매칭

```bash
bash .claude/hooks/lib/consensus-loop.sh parse-verdict "VERDICT: APPROVE"
# expect: APPROVE
```

결과: **PASS** — `APPROVE`

---

## 시나리오 P4-2: 동의어 매칭

```bash
bash .claude/hooks/lib/consensus-loop.sh parse-verdict "RECOMMENDATION: APPROVE"
# expect: APPROVE
```

결과: **PASS** — `APPROVE`

---

## 시나리오 P4-3: max-loops 도달 → 폴백 진입

```bash
SF=$(bash .claude/hooks/lib/consensus-loop.sh start "test")
for i in 1 2 3 4; do
  bash .claude/hooks/lib/consensus-loop.sh iterate "$SF" REQUEST_CHANGES
done
# 4번째 호출에서 exit 2, MAX_LOOPS_REACHED
bash .claude/hooks/lib/consensus-loop.sh fallback "$SF" 3
# expect: pause-and-confirm + marker 생성
ls .omc/state/USER_CONFIRM_NEEDED
# 정리
rm -f .omc/state/USER_CONFIRM_NEEDED
```

결과: **PASS**
- loop 1~3: `ITERATING (loop N/4)`
- loop 4: `MAX_LOOPS_REACHED — fallback required` (exit 2)
- fallback 3: `pause-and-confirm` + `.omc/state/USER_CONFIRM_NEEDED` 생성 확인

---

## 시나리오 P4-4: SessionStart 마커 감지

```bash
echo '{"test":1}' > .omc/state/USER_CONFIRM_NEEDED
bash .claude/hooks/session-start.sh | grep -q "USER CONFIRM NEEDED" && echo PASS
rm -f .omc/state/USER_CONFIRM_NEEDED
```

결과: **PASS** — session-start.sh가 `## ⚠️ USER CONFIRM NEEDED` 섹션 출력 확인

---

## 시나리오 P4-5: KPI 카운터

```bash
PRE=$(jq -r '.counters.consensus_first_pass' .omc/learnings/_metrics.json)
SF=$(bash .claude/hooks/lib/consensus-loop.sh start "task")
bash .claude/hooks/lib/consensus-loop.sh iterate "$SF" APPROVE
POST=$(jq -r '.counters.consensus_first_pass' .omc/learnings/_metrics.json)
[[ "$((POST - PRE))" -eq 1 ]] && echo PASS
```

결과: **PASS** — `first_pass: 0 -> 1` (delta=1 확인)

---

## Gate 결과

| 시나리오 | 설명 | 결과 |
|----------|------|------|
| P4-1 | parse-verdict 정확 매칭 | PASS |
| P4-2 | 동의어 매칭 (RECOMMENDATION) | PASS |
| P4-3 | max-loops 4 → 폴백 3단 | PASS |
| P4-4 | SessionStart 마커 감지 | PASS |
| P4-5 | KPI consensus_first_pass 카운터 | PASS |

**Phase 4 gate: 5/5 PASS**

누적 bats: 30/30 (22 기존 + 8 신규)
