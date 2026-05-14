# `/solo` — v4 최종 스펙 (구현 기준)

> v3 + 양 리뷰어 합의 9개 수정. 본 문서가 구현의 단일 소스.

## 1. 호출

```bash
/solo "<자연어>"                       # 1~3줄 자연어
/solo --spec ./01.spec/feature.md       # 마크다운 spec
/solo --notify discord|telegram         # 종료 알림
/solo --isolated                        # git worktree 격리 실행
/solo --no-tdd                          # TDD 해제 (사유 로깅)
/solo --resume                          # 직전 phase에서 재개

/pg                                     # 진행 상황 즉시 출력
```

**금지 조합**: security/auth/.env 라벨 감지 + `--no-consensus` (옵션은 의도적으로 제공 안 함)

---

## 2. 7 Phases

### Phase 0 — TRIAGE
**입력**: 프롬프트 (+ spec md)
**처리**:
1. 규칙 1차 — 위험 키워드 정규식:
   - `(auth|session|token|jwt|password|secret)` → critical
   - `(schema|migration|alter\s+table|drop\s+table)` → critical
   - `\.env` → critical
   - `(payment|결제|토스|환불|refund)` → high
2. LLM 2차 (Claude main) — `{intent, scope, risk_labels[], confidence∈[0,1], rationale}`
3. confidence < 0.7 → 사용자 1회 confirm

**산출**: `.omc/state/solo-routing.json`

**마커 충돌 검사** (신규 #9): `.harness-main-only` + `.harness-active` 동시 존재 → 사용자 confirm 1회 (이상 상태)

---

### Phase 1 — 분석 + 완료조건 SET (★ 핵심 ★)
**주체**: `planner` (opus)
**입력**: 프롬프트 + spec md + routing.json + 위험라벨
**처리**:
1. 요구사항 분해 → 검증 가능 단위
2. 각 단위마다 `verify_cmd` 자동 생성
3. **priority 자동 라벨** (신규 #1):
   - `risk_labels`에 security/auth/.env/schema 있으면 → `critical`
   - lint 항목 1개 이상 무조건 critical
4. **인플레이션 가드** (신규 #4):
   - `must_pass.length` ≤ 7
   - critical ≥ 1 (없으면 추가)
   - lint ≥ 1 (없으면 추가)

**산출**: `.omc/state/solo-criteria.json`
```json
{
  "run_id": "20260514T1234",
  "must_pass": [
    {
      "id": "C1",
      "desc": "토스 위젯이 /payment에서 렌더링",
      "verify_cmd": "npm test -- payment-render",
      "type": "test",
      "expected": "pass",
      "priority": "standard",
      "status": "pending",
      "attempts": 0,
      "history": []
    },
    {
      "id": "C2",
      "desc": "결제 콜백 POST /api/payments/callback 처리",
      "verify_cmd": "npm test -- payment-callback",
      "type": "test",
      "expected": "pass",
      "priority": "critical",
      "status": "pending",
      "attempts": 0,
      "history": []
    }
  ],
  "nice_to_have": []
}
```

**컨텍스트 부족 시**: 가정 진행 + `assumption: true` 마크. 보고서 명시.

---

### Phase 1.5 — DRY-RUN 검증 게이트 (신규 #3)
**처리**: 각 `verify_cmd`의 실행 가능성 사전 확인:
- npm script 존재? `package.json scripts.X` 검색
- playwright 설치됨? `node_modules/@playwright` 존재
- pytest? `pytest --collect-only` dry run

**결과**:
- ✅ 실행 가능 → 유지
- ❌ 실행 불가 → type 강등 (test → manual). 보고서에 명시.
- 모든 verify_cmd 강등 → STOP & 사용자 확인

**산출**: `.omc/state/solo-criteria.json` (status 갱신)

---

### Phase 2 — CONSENSUS
**처리**:
1. `/codex:review --wait` (criteria 자체 합의)
2. VERDICT 파싱 3단 폴백 (consensus-loop SKILL §파싱)
3. APPROVE → Phase 3 / REQUEST_CHANGES → planner 재호출 (max 4)

**폴백 순서** (Codex 장애):
1. Codex 재시도 (백오프 5/10/20s, 3회)
2. `mcp__g__ask_gemini` (agent_role=critic)
3. 둘 다 실패 → **DEGRADED_REVIEW**:
   - OMC `critic` + `security-reviewer` 2중 리뷰
   - `.omc/state/USER_CONFIRM_NEEDED` 마커
   - 자동 진행 금지, 사용자 확인 후 Phase 3

---

### Phase 3 — EXECUTE LOOP (Task Queue 패턴, 신규 #6)

```python
queue = [c for c in criteria.must_pass if c.status == "pending"]
elapsed_start = now()

while queue and not exhausted():
    for criterion in list(queue):
        # 1. agent 선택
        agent = routing_matrix[intent][priority]
        if cost_usd >= 15: agent = downgrade(agent)  # 신규 #5
        if cost_usd >= 18: agent = haiku_tier(agent)
        
        # 2. 위임 (TDD red-first)
        if not --no-tdd: tdd_red(criterion)
        result = delegate(agent, criterion)
        
        # 3. verify_cmd 실행
        verdict = run(criterion.verify_cmd)
        criterion.attempts += 1
        criterion.history.append({"attempt": N, "agent": agent, "verdict": verdict})
        atomic_write(criteria_json)  # /pg 즉시 반영 (신규 #8)
        
        # 4. 결과 처리
        if verdict == "pass":
            criterion.status = "passed"
            queue.remove(criterion)
        elif verdict == "fail":
            if criterion.attempts == 3:
                # escalate
                agent = escalate(agent)  # executor→debugger→deep-executor
            elif criterion.attempts == 5:
                # STOP & 사용자 확인
                write_marker("USER_REVIEW_NEEDED")
                break_outer = True
        elif verdict == "manual":
            criterion.status = "deferred"
            queue.remove(criterion)
    
    # 라운드 종료 — 80% rule 체크 (신규 #1 핵심 안전장치)
    pass_rate = passed_count / total_count
    critical_pass = all(c.status == "passed" for c in criteria.must_pass if c.priority == "critical")
    elapsed = now() - elapsed_start
    
    if all(c.status in ["passed", "deferred"] for c in criteria.must_pass):
        break  # 100% 완료
    
    if elapsed >= 10*HOUR and pass_rate >= 0.8 and critical_pass:
        # graceful 80% exit — critical 100% 의무
        break
    
    if elapsed >= 10*HOUR and pass_rate >= 0.8 and not critical_pass:
        # critical 미통과 → graceful exit 거부, 계속 시도 또는 사용자 호출
        if elapsed >= 12*HOUR: write_marker("CRITICAL_PENDING"); break
    
    if cost_usd >= 20 or elapsed >= 24*HOUR or iteration >= 100:
        # forced exit
        break
    
    # 일탈 감지 (신규 #7)
    if no_progress_3_rounds():
        # criteria.must_pass ID 진행률 0% 3회 연속
        write_marker("USER_REVIEW_NEEDED")
        break
    
    # Reflection 압축 (직전 3 iteration → 다음 라운드 context)
    reflection = compress_last_3()
    inject_into_next_round(reflection)
```

**routing_matrix**:
| intent | 1차 | 보조 |
|---|---|---|
| build | executor (sonnet) | test-engineer (TDD red) |
| fix | debugger → executor | test-engineer |
| refactor | deep-executor (opus) | quality-reviewer |
| build-error | build-fixer | — |
| UI | designer | executor |
| docs | writer (haiku) | — |
| security | security-reviewer | executor |

**비용 다운그레이드** (신규 #5):
- $15 도달 → opus 호출 → sonnet
- $18 도달 → sonnet → haiku (단순 작업만)
- rate_limit 에러 → 지수 백오프 (5/10/20/40s, max 5회)

---

### Phase 4 — VERIFY (종료 직전)
**fresh evidence 재실행**:
1. 모든 `must_pass.verify_cmd` 재실행 → 결과 갱신
2. `lsp_diagnostics_directory` → 0 error 확인
3. build/typecheck → 성공

**verifier 호출**:
- small → haiku, standard → sonnet, large/security → opus

**보강 게이트** (security/architectural):
- `/codex:adversarial-review --wait` 의무
- 200줄 초과 파일 → `quality-reviewer` 자동 호출

---

### Phase 5 — COMMIT (push/PR 없음)

**브랜치 자동 분기**:
1. `.harness-main-only` 있음 → main 직커밋
2. `.harness-active` 있음 → `feature/{slug}` 자동 (dev 베이스)
3. 둘 다 없음 → dev 베이스 (보수적 default)
4. 마커 충돌 → Phase 0 단계에서 차단됨

**스테이징**: 변경 파일만 명시 (`git add -A` 금지)

**.env 가드**:
- `git diff --name-only` 출력에 `\.env` 패턴 → ABORT (재시도 X)

**메시지**: Conventional Commits + Co-Authored-By

**pre-commit 실패** → `debugger` → 재커밋 (max 3) → 3회 실패 시 STOP

**push/PR**: 절대 안 함. 보고서에 정확한 `git push -u origin feature/{slug}` 명령 자동 포함

---

### Phase 6 — REPORT

**1. 터미널 출력 (7~9줄)**:
```
✅ /solo 완료 (graceful, critical 100%)
📊 6/7 PASS, 1 manual deferred
⏱ 7h 23m / $17.80 / 87 iterations
🔧 다운그레이드: 6h 시점 opus→sonnet
📝 commit: feat(payment): toss integration
📂 보고서: solo-result/20260514T1234/report.md
⚠ 수동: C3 (playwright config 없음)
💡 push: git push -u origin feature/toss-payment
```

**2. `solo-result/{run_id}/report.md`** (상세):
```markdown
# /solo Run Report — {run_id}

## 요약
- 작업: ...
- critical 통과: 4/4 (100%) ✅
- 전체 통과: 6/7 (86%) graceful
- 소요: 7h 23m / $17.80 / 87 iterations
- 다운그레이드: opus→sonnet at 6h
- 커밋: feat(payment): toss integration

## Criteria 결과
| ID | priority | desc | 결과 | attempts | 비고 |
|---|---|---|---|---|---|
| C1 | standard | 토스 위젯 렌더링 | ✅ PASS | 2 | — |
| C2 | critical | 콜백 처리 | ✅ PASS | 4 | document-specialist 호출 |
| C3 | standard | toast 3s | ⏸ MANUAL | 0 | playwright config 없음 |
| C4 | critical | lsp 0 error | ✅ PASS | 1 | — |
| C5 | critical | .env 노출 없음 | ✅ PASS | 1 | env-security 가드 |
| C6 | standard | 200줄 이하 | ✅ PASS | 1 | — |
| C7 | critical | 환불 콜백 | ✅ PASS | 3 | — |

## 시도 history (압축)
- Round 1: C2/C7 실패, document-specialist escalate
- Round 2: C2 ✅, C7 ✅ (토스 환불 API 문서 흡수)
- Round 3: 전체 verify 재실행 → 통과

## 사용 agent 통계
| agent | 호출수 | 누적 비용 |
|---|---|---|
| executor (sonnet) | 42 | $8.20 |
| planner (opus) | 3 | $4.10 |
| ... | ... | ... |

## 가정한 항목
- "환불 정책": 토스 표준 환불 적용 가정 (사용자 확인 필요)

## 수동 확인 필요
- C3 toast 3s — playwright config 없어서 자동 검증 불가
  - 수동 검증 단계:
    1. `npm run dev`
    2. /payment 결제 실패 시나리오
    3. toast 노출 시간 측정

## 다음 권장 액션
- C3 수동 확인 → 통과면 그대로 push
- push: `git push -u origin feature/toss-payment`
- PR 본인 작성
```

**3. 알림** (`--notify discord` 설정 시):
- Discord webhook으로 터미널 요약 7줄 전송

---

## 3. `/pg` 명령 (신규)

```bash
/pg
```

**구현**: Claude main이 `.omc/state/solo-criteria.json` + `solo-state.json` + `solo-budget.json` 읽어서 출력.

**출력**:
```
🚧 /solo 진행 중 (run_id: 20260514T1234)
Phase: 3 / Round 2
시간: 5h 12m / 24h
비용: $14.20 / $20  ⚠ 다운그레이드 임박 ($15)
Criteria: 4/7 PASS, 2 IN_PROGRESS, 1 DEFERRED
  ✅ C1, C4, C5 (critical), C2 (critical)
  🔄 C7 (critical, attempt 3, document-specialist)
  🔄 C6 (executor 분리 중)
  ⏸ C3 (manual, deferred)
직전 reflection: C7 콜백 url 추측 오류 → document-specialist로 토스 환불 API 흡수
예상 종료: 7h 30m
```

**상태 갱신 주기**: 매 criterion 시도 후 atomic write (`.tmp` → `mv`)

---

## 4. 사용자 핏 매트릭스

| 룰 | 강도 | 해제 |
|---|---|---|
| `.env*` 가드 | 절대 | 불가 |
| Codex 합의 (Phase 2) | 절대 | 불가 |
| TDD red-first | 기본 | `--no-tdd` (사유 로깅) |
| 200줄 제한 (Phase 4) | 기본 | 불가 |
| 브랜치 마커 분기 | 자동 | — |
| critical 100% 의무 | 절대 | 불가 |
| commit only (no push) | 절대 | 불가 |
| shadcn/ui + Tailwind | UI 의도일 때 designer 컨텍스트 | — |

---

## 5. 운영 가드 (v2 완전 복원 + v3 추가)

| 항목 | 값 |
|---|---|
| MAX_ITERATIONS | 100 |
| MAX_COST_USD | 20 (다운그레이드 $15/$18) |
| MAX_DURATION_HARD | 24h |
| MAX_DURATION_GRACEFUL | 10h (80% rule 트리거, critical 100% 의무) |
| PHASE_TIMEOUT | 30min (Phase 1/2/4 — Phase 3은 전체 cap만) |
| LOCK | `.omc/locks/solo.lock` (PID + TTL 30min) |
| WORKTREE 격리 | `--isolated` (psm 연동) |
| 알림 | `--notify discord\|telegram` |
| 로그 보존 | `.omc/logs/solo/{run_id}/` 30일 |
| API rate limit | 지수 백오프 5/10/20/40s, max 5회 |

---

## 6. 파일 구조

```
.omc/
├── state/
│   ├── solo-routing.json
│   ├── solo-criteria.json          # 핵심 (Phase 1)
│   ├── solo-state.json             # phase/iteration/elapsed
│   ├── solo-budget.json            # 비용/시간 카운터
│   ├── USER_CONFIRM_NEEDED         # DEGRADED_REVIEW 마커
│   ├── USER_REVIEW_NEEDED          # 일탈/critical pending 마커
│   └── CRITICAL_PENDING            # 80% 도달 + critical 미통과
├── plans/
│   └── solo-{run_id}.md            # planner 산출
├── logs/solo/{run_id}/
│   ├── phase0~6.log
│   ├── iterations/{N}.log
│   └── cost-downgrade.log
├── locks/
│   └── solo.lock
└── solo-history.jsonl              # 누적 학습 (감사용)

solo-result/                         # 사용자 직접 열어볼 위치
└── {run_id}/
    ├── report.md
    └── reflections.md
```

---

## 7. 구현 파일 (Build 대상)

| 파일 | 종류 | 책임 |
|---|---|---|
| `plugin/claude/commands/solo.md` | 커맨드 wrapper | `/solo` 진입점 |
| `plugin/claude/commands/pg.md` | 커맨드 wrapper | `/pg` 진행 출력 |
| `plugin/claude/skills/solo/SKILL.md` | 스킬 본체 | 전체 7 phase 로직 |
| `plugin/claude/hooks/lib/solo-triage.sh` | 쉘 헬퍼 | Phase 0 규칙 1차 분류 (위험 키워드 정규식) |
| `plugin/claude/hooks/lib/solo-lock.sh` | 쉘 헬퍼 | 락 검사/획득/해제 |
| `plugin/claude/hooks/lib/solo-budget.sh` | 쉘 헬퍼 | 비용/시간/iteration 카운터 + 다운그레이드 판정 |
| `plugin/claude/hooks/lib/solo-dryrun.sh` | 쉘 헬퍼 | Phase 1.5 verify_cmd 실행 가능성 검사 |
| `04.docs/RUNBOOK.md` (추가 섹션) | 문서 | `/solo` 운영 가이드 |

---

## 8. 차별점 표 (최종)

| 항목 | ralph | codex goal | **solo v4** |
|---|---|---|---|
| 분석+완료조건 자동 set | ❌ | ❌ | ✅ planner + dry-run |
| Criteria 머신 검증 형식 | ❌ | ❌ | ✅ verify_cmd |
| Critical priority (절대 의무) | ❌ | ❌ | ✅ 자동 라벨링 |
| 사용자 룰 자동 적용 | ❌ | ❌ | ✅ 7개 룰 |
| 비용 다운그레이드 | ❌ | ❌ | ✅ $15/$18 단계 |
| Task queue 패턴 | ❌ | ❌ | ✅ |
| 80% rule + critical 면제 | ❌ | ❌ | ✅ |
| /pg 즉시 진행률 | ❌ | ❌ | ✅ |
| DEGRADED_REVIEW 모드 | ❌ | ❌ | ✅ |
| commit only (no push) | 부분 | 부분 | ✅ 명시 |
| 운영 가드 7종 | 부분 | 부분 | ✅ 통합 |
| solo-result 보고서 | ❌ | ❌ | ✅ 상세 |

---

## 9. v4 합의 메타

- v2 합의 9개 모두 유지 (운영 가드 회귀 복원)
- v3 신규 5개 (80% rule + critical priority, criteria, /pg, 일탈, commit-only)
- v4 신규 9개:
  1. priority: critical | standard (security/.env/auth 자동)
  2. 80% rule + critical 100% 의무
  3. Phase 1.5 dry-run 게이트
  4. criteria 인플레이션 가드 (max 7, critical ≥ 1, lint ≥ 1)
  5. 비용 다운그레이드 ($15/$18)
  6. Task queue 패턴
  7. 일탈 감지 = criterion ID 진행률 기반
  8. atomic state write (매 시도 후)
  9. 마커 충돌 검사

**v4 셀프 점수 추정**: 9/10. 남은 약점은 (a) verify_cmd LLM 추측 정확도 (운영 데이터로 개선), (b) Anthropic rate limit 실측 부재.
