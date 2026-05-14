# `/solo` — v3 (사용자 답변 반영)

## 사용자 답변 흡수표
| Q | 답변 | v3 반영 |
|---|---|---|
| Q1 | C (planner → Codex critic 합의) | Phase 1 산출물 → Phase 2 합의 의무 |
| Q2 | 자연어 (충분→짧게, 부족→길게) + 검증 명령 형식 | criteria = `{desc, verify_cmd, expected, type}` |
| Q3 | 100% 목표, 시간 초과 시 80% 통과로 graceful exit | 신규 "80% rule" 추가 |
| Q4 | B (100회 / $20 / 24시간) | budget cap 명시 |
| Q5 | 1~3줄 자연어 or 마크다운 경로. 부족해도 진행, 방향 안 엇나가면 OK | `--spec` 옵션 + 가정 진행 + 일탈 감지 |
| Q6 | A (cancel만). 세션 종료 필요 시 `/ss-re` | 중간 개입 채널 없음. `/pg` 진행 보고만 |
| Q7 | C (직전 3 iteration 압축) | Reflection 표준화 |
| Q8 | 터미널 요약 + `solo-result/{run_id}.md` 상세 | 결과물 2단계 |
| 추가 | commit만 (push/PR 없음) | Phase 5 명시 |
| 추가 | 1~10시간 장시간 사용처 | 24h timeout 정합 |
| 추가 | 중간 `pg` 입력 시 진행률 출력 | 신규 `/pg` slash command |

---

## 1. 워크플로우 (이중 단계)

### Stage A (사용자와 티키타카) — `/solo` 외부
- Claude main과 대화하며 설계/기획 다듬기
- 산출물: `01.spec/{feature}.md` 또는 `02.plan/{feature}.md` (자유 위치)
- `/solo`는 이 단계 안 함

### Stage B (`/solo` 자율 실행) — 1~10시간
```bash
/solo "1~3줄 자연어 작업"
/solo --spec ./01.spec/payment.md
/solo --spec ./01.spec/payment.md --notify discord
/solo --resume                          # phase에서 재개
```

---

## 2. 7 Phases (수정)

### Phase 0 — TRIAGE
**입력**: 자연어 프롬프트 + (옵션) `--spec` 마크다운 본문
**처리**:
- 규칙 1차: 위험 키워드 정규식 (auth/schema/.env/migration/secret)
- LLM 2차: `{intent, scope, risk_labels[], confidence∈[0,1], rationale}`
- confidence < 0.7 → 사용자 1회 confirm (예외: `--no-confirm`)
- 위험 라벨 있으면 자동 strict
**산출**: `.omc/state/solo-routing.json`

### Phase 1 — CRITERIA 도출 (핵심)
**주체**: `planner` (opus)
**입력**: 프롬프트 + spec md + routing.json
**산출**: `.omc/state/solo-criteria.json`
```json
{
  "run_id": "20260514-T1234",
  "must_pass": [
    {"id":"C1","desc":"토스 결제 위젯이 /payment에서 렌더링","verify_cmd":"npm test -- payment-render","type":"test","expected":"pass"},
    {"id":"C2","desc":"결제 성공 콜백이 POST /api/payments/callback 호출","type":"test","verify_cmd":"npm test -- payment-callback","expected":"pass"},
    {"id":"C3","desc":"결제 실패 시 toast 3초 표시","type":"visual","verify_cmd":"playwright test payment-failure","expected":"pass"},
    {"id":"C4","desc":"lsp_diagnostics 0 error","type":"lint","expected":"0"},
    {"id":"C5","desc":"각 파일 200줄 이하","type":"lint","verify_cmd":"awk 'END{print NR}' ...","expected":"<=200"}
  ],
  "nice_to_have": [
    {"id":"N1","desc":"로딩 스피너 표시","type":"visual"}
  ]
}
```
**컨텍스트 부족**: 가정 + criteria에 `assumption: true` 마크. 결과물에 명시.

### Phase 2 — CONSENSUS
- `/codex:review --wait` 로 criteria 자체 합의 받음 (구현 전 단계 합의)
- VERDICT: APPROVE → Phase 3 / REQUEST_CHANGES → planner 재호출 (max 4)
- Codex 장애 → Gemini critic → 둘 다 실패 → DEGRADED_REVIEW

### Phase 3 — EXECUTE LOOP (핵심 변경)

```
iteration = 0
while iteration < MAX_ITERATIONS (100):
  iteration += 1
  
  for each FAILING criterion in criteria.must_pass:
    1. routing matrix로 agent 선택 (executor/debugger/...)
    2. delegate (TDD red-first)
    3. verify_cmd 실행 → pass/fail 기록
  
  # 80% rule 체크
  pass_rate = passed / total
  elapsed_hours = (now - start) / 3600
  
  if pass_rate == 1.0:
    break (성공)
  
  if elapsed_hours >= 10 AND pass_rate >= 0.8:
    mark deferred → break (graceful 80% exit)
  
  if elapsed_hours >= 24 OR cost_usd >= 20 OR iteration >= 100:
    break (forced exit, 보고서에 명시)
  
  # 일탈 감지
  if same_criterion_failed_3_times AND no_new_progress:
    log → escalate (다른 agent/모델) OR STOP & 사용자 확인
  
  # reflection: 직전 3 iteration의 (시도→결과→교훈) 압축
  reflection = compress_last_3_iterations()
  inject_into_next_iteration_context(reflection)
```

**Routing 매트릭스** (v2와 동일):
| 의도 | 1차 | 보조 |
|---|---|---|
| build | executor | test-engineer |
| fix | debugger → executor | test-engineer |
| refactor | deep-executor | quality-reviewer |
| UI | designer | executor |

### Phase 4 — VERIFY (각 iteration 마지막 + 종료 직전)
- must_pass criterion별 `verify_cmd` 실행
- visual/manual 타입 → `qa-tester` (Playwright) 자동 검증
- 종료 직전 추가:
  - `lsp_diagnostics_directory` → 0 error 확인
  - 200줄 초과 파일 → `quality-reviewer` 자동 호출
  - security 라벨 → `/codex:adversarial-review` 의무

### Phase 5 — COMMIT (push/PR 없음)
- 브랜치 자동 분기 (`.harness-main-only` 있으면 main / `.harness-active` 있으면 `feature/{slug}` / 둘 다 없으면 `dev`)
- `.env*` 패턴 감지 시 ABORT
- 변경 파일만 명시 스테이징
- Conventional Commits + Co-Authored-By
- pre-commit 실패 → `debugger` → 재커밋 (max 3)
- **`git push` 안 함. `gh pr create` 안 함.**

### Phase 6 — REFLECT & 결과물
- `.omc/solo-history.jsonl` 1줄 append
- `solo-result/{run_id}/report.md` 작성 (구조):
  ```markdown
  # /solo Run Report — {run_id}
  ## 요약
  - 작업: ...
  - 통과: 4/5 (80%)
  - 소요: 7h 23m / $14.20 / 87 iterations
  - 커밋: feat: add toss payment integration (HEAD~1)
  
  ## Criteria 결과
  | ID | desc | 결과 | 비고 |
  |---|---|---|---|
  | C1 | 토스 위젯 렌더링 | ✅ PASS | iteration 12 |
  | C2 | 콜백 호출 | ✅ PASS | iteration 23 |
  | C3 | toast 3초 | ✅ PASS | iteration 34 |
  | C4 | lsp 0 error | ✅ PASS | iteration 78 |
  | C5 | 200줄 이하 | ⏸ DEFERRED | 시간 캡, payment.tsx 245줄 |
  
  ## 시도 history (압축)
  ...
  
  ## 사용 agent 통계
  ...
  
  ## 가정한 항목
  - "결제 금액 환불 정책": 가정함 (없음)
  
  ## 다음 권장 액션
  - C5 해결: payment.tsx 분리 (대략 3분 작업)
  ```
- 터미널 출력: 요약 7줄
  ```
  ✅ /solo 완료 (graceful 80%)
  📊 4/5 PASS, 1 DEFERRED
  ⏱ 7h 23m / $14.20 / 87 iterations
  📝 commit: feat: add toss payment integration
  📂 보고서: solo-result/20260514-T1234/report.md
  ⚠ 미통과: C5 (payment.tsx 245줄 → 분리 필요)
  💡 다음: 직접 분리 or /solo "C5 해결"
  ```

---

## 3. 신규 — `/pg` (Progress)

```bash
/pg
```
**출력 (예시)**:
```
🚧 /solo 진행 중 (run_id: 20260514-T1234)
Phase: 3 (EXECUTE)
Iteration: 34 / 100
시간: 3h 12m / 24h
비용: $5.40 / $20
Criteria: 2/5 PASS, 1 IN_PROGRESS, 2 PENDING
직전 실패: C3 (toast 3s) — playwright timeout 3회
지금 작업: designer + executor 병렬 (C3 재시도)
```

**구현**: `.omc/state/solo-state.json` 읽어서 포맷. Claude main이 즉시 응답.

---

## 4. 일탈 감지 (사용자 요청)

"방향이 너무 엇나가지만 않으면 진행" → 객관 지표:
- 3 iteration 연속 같은 criterion 0% 진행 → escalate (다른 agent/모델)
- 5 iteration 연속 → STOP & 사용자 확인 마커
- 전체 변경 파일 중 50% 이상이 criteria와 무관한 디렉토리 → 경고 + 마커
- 사용자 명시 키워드 (예: "결제") 가 직전 5 iteration 산출물에 0회 → 일탈 의심 → STOP

마커: `.omc/state/USER_REVIEW_NEEDED` + 보고서 미리보기 동봉.

---

## 5. 예산 / 한계 (Q4=B 반영)
| 항목 | 값 |
|---|---|
| MAX_ITERATIONS | 100 |
| MAX_COST_USD | 20 |
| MAX_DURATION | 24h (소프트) / 10h (graceful 80% 트리거) |
| MAX_TOKENS | 5M |
| 동시 실행 락 | `.omc/locks/solo.lock` (PID+TTL 30min) |
| 알림 | `--notify discord|telegram` (default: 없음) |

---

## 6. 사용자 핏 (절대/기본/UI한정)
| 룰 | 강도 | 해제 |
|---|---|---|
| `.env*` 가드 | 절대 | 불가 |
| 합의 루프 | 절대 | 불가 (지난 v3 결정) |
| TDD red-first | 기본 | `--no-tdd` |
| 200줄 제한 | 기본 (Phase 4) | 불가 |
| 브랜치 마커 분기 | 자동 | — |
| shadcn/ui + Tailwind | UI 의도일 때 | — |
| toast 3s + delete confirm | UI 의도일 때 designer 컨텍스트 | — |
| commit only (no push/PR) | 절대 | 불가 (사용자 명시) |

---

## 7. 파일 구조

```
.omc/
├── state/
│   ├── solo-routing.json
│   ├── solo-criteria.json          # ← 신규 (Phase 1)
│   ├── solo-state.json             # iteration/phase/elapsed
│   ├── solo-budget.json
│   ├── USER_REVIEW_NEEDED          # 일탈 감지 마커
│   └── USER_CONFIRM_NEEDED         # DEGRADED_REVIEW 마커
├── plans/
│   └── solo-{run_id}.md            # planner 계획
├── logs/solo/{run_id}/
│   ├── phase0~6.log
│   └── iterations/{N}.log
├── locks/
│   └── solo.lock
└── solo-history.jsonl

solo-result/                         # ← 신규 (사용자 직접 열어볼 위치)
└── {run_id}/
    ├── report.md                   # 메인 보고서
    └── reflections.md              # iteration별 reflection 압축
```

---

## 8. 호출 예시 (사용처 시나리오)

### 시나리오 A: 짧은 자연어, 컨텍스트 충분
```bash
/solo "결제 페이지에 토스 SDK v2 결제 위젯 추가, 결제 성공/실패 콜백 처리, 실패 시 toast 3초"
# → planner가 5~7개 criteria 도출 → 합의 → 7시간 자율 실행 → 보고서
```

### 시나리오 B: spec 마크다운 (장시간)
```bash
# Stage A: 사용자와 대화로 01.spec/checkout-flow.md 작성 (1시간)
/solo --spec ./01.spec/checkout-flow.md --notify discord
# → 10시간 자율 → 80% 통과로 graceful exit → 사용자 확인
```

### 시나리오 C: 진행 중 확인
```bash
# 사용자가 5시간 후 잠깐 확인
/pg
# → 위 출력 형식
```

### 시나리오 D: 중단
```bash
/cancel               # 정상 종료
/cancel --force       # 모든 state 클리어
```

---

## 9. v3 합의 메타
- 사용자 답변 9개 항목 모두 반영
- v2의 합의 항목 모두 유지 (.env/TDD/브랜치/합의/200줄/Reflexion/운영가드)
- v3 신규: 80% rule, `/pg`, criteria 머신 검증 가능 형식, 일탈 감지, commit-only, solo-result 폴더

**v3 셀프 점수 추정**: 8.5/10 (장시간 사용처 정합성↑, criteria 명세 추가, 두 워크플로우 분리 명확)

---

## 10. 다음: Codex + OMC critic 합의 루프

이 v3을 두 리뷰어에 보내 합의 받음. 통과 시 구현 시작.
