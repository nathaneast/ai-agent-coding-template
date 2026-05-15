---
provider: "codex"
agent_role: "critic"
model: "gpt-5.3-codex"
files:
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-spec-v3.md"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/CLAUDE.md"
timestamp: "2026-05-14T12:35:47.322Z"
---

--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-spec-v3.md ---
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


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md ---
# `/solo` — Solo Autonomous Agent (Proposal v1)

## Goal
한 명령으로 idea→working code까지 끝내는 **단독 자율 에이전트**.
경쟁상대: OMC `ralph`, Codex `goal`, OpenSpec autopilot.
차별화: (1) 사용자 핏 — TDD·합의루프·.env·브랜치 규칙 자동 적용, (2) 지능적 라우팅 — 의도 분석해 최적 OMC 에이전트 선택, (3) 자기개선 — 실행 결과를 학습.

## 호출
```
/solo <자연어 작업 설명>
/solo --plan-only "..."     # 계획만 (실행 X)
/solo --fast "..."          # 트리아지에서 small 강제, 합의 스킵
/solo --strict "..."        # 모든 단계 합의 강제 (default는 의도 분석)
/solo --resume              # .omc/solo-state.json 에서 재개
```

## 파이프라인 (7 phases)

### Phase 0 — TRIAGE (Claude main, no delegation)
- 의도 분류: build/fix/refactor/explain/research/review/design/test/docs/setup
- 스코프 추정: small (<5 files, <100 lines) / standard / large (>20 files | security | architectural)
- 사용자 컨텍스트 자동 감지:
  - `.harness-main-only` → 브랜치 정책: main 단독
  - `.harness-active` → 일반 브랜치 정책 (feature/*)
  - 프로젝트 `CLAUDE.md` 파싱 → 추가 규칙 흡수
- 위험 신호: `.env`, secret 패턴, schema migration, auth 등 → 자동 strict 모드 승격
- **출력**: `.omc/state/solo-routing.json`

### Phase 1 — PLAN (조건부, opus)
- small + 위험신호 없음 → SKIP
- 그 외 → `oh-my-claudecode:planner` (opus) 호출
- 산출물: `.omc/plans/solo-{ts}.md` (acceptance criteria, file list, risk)
- 모호한 medium+ → 사용자 1회 확인 (yes/clarify/cancel)

### Phase 2 — CONSENSUS (조건부)
- Phase 1 실행 시 자동 진입
- `/codex:review --wait` 또는 `mcp__plugin_oh-my-claudecode_x__ask_codex` (agent_role=critic)
- VERDICT 파싱 3단 폴백 (consensus-loop SKILL 준수)
- APPROVE → Phase 3. REQUEST_CHANGES → 계획 수정 → 재시도 (max 4)
- Codex 장애 → OMC `critic` 폴백 (사용자 사전 승인 필요)

### Phase 3 — EXECUTE (병렬, tiered)
- 작업 종류별 라우팅 매트릭스:

| 의도 | 1차 에이전트 (모델) | 보조 |
|---|---|---|
| build/feature | `executor` (sonnet) | `test-engineer` (TDD) |
| bug fix | `debugger` (sonnet) → `executor` | `test-engineer` |
| refactor (large) | `deep-executor` (opus) | `quality-reviewer` |
| build/type error | `build-fixer` (sonnet) | — |
| UI/UX | `designer` (sonnet) | `executor` |
| docs | `writer` (haiku) | — |
| security | `security-reviewer` (sonnet) | `executor` |
| research | `document-specialist` (sonnet) | — |
| design audit | `architect` (opus) | `critic` |

- TDD 의무 (consensus-loop 규칙): test-engineer가 red 테스트 먼저 작성 → executor가 green
- 독립 작업은 단일 메시지로 동시 발행
- 설치/빌드/테스트 suite → `run_in_background: true`

### Phase 4 — VERIFY
- 신선한 증거 수집 (3가지):
  1. `npm test` (또는 프로젝트 테스트 커맨드) → 0 fail
  2. `lsp_diagnostics_directory` → 0 error
  3. build / typecheck → 성공
- `verifier` 에이전트 호출:
  - small → haiku
  - standard → sonnet
  - large/security → opus
- security/architectural 변경 → 추가로 `/codex:adversarial-review` 의무

### Phase 5 — COMMIT
- 브랜치 정책 enforce:
  - `.harness-main-only` 존재 → main 직커밋 허용
  - 아니면 → `feature/{slug}` 자동 생성
- 스테이징: 변경 파일만 명시 (절대 `git add -A`/`.` 금지)
- `.env*` 패턴 감지 시 ABORT
- 메시지: Conventional Commits + Co-Authored-By
- pre-commit hook fail → `debugger` → 재커밋 (max 3)

### Phase 6 — REFLECT
- 실행 요약 `.omc/solo-history.jsonl` append (one-line JSON):
  - `{ts, intent, scope, agents, retries, duration, verdict, files_changed}`
- 실패 패턴 (3+ 동일 에이전트 실패) → 사용자 알림
- 다음 실행 시 history 참조해 라우팅 가중치 조정

## 사용자 핏 (자동 적용)
1. **TDD 의무** (consensus-loop §rules) → Phase 3에서 test-engineer first
2. **합의 루프** → Phase 2 mandatory for medium+
3. **.env 절대 규칙** → 모든 Phase에서 `.env*` Read/Write/grep 가드
4. **브랜치 전략** → Phase 5에서 `.harness-main-only` 체크
5. **파일 ≤ 200줄** → Phase 4에서 위반 시 quality-reviewer 자동 호출
6. **toast 3s, delete confirm 모달** → UI 작업에서 designer에 컨텍스트 자동 주입
7. **shadcn/ui + Tailwind** → UI 의도 감지 시 designer에 강제 명시

## 차별점 (vs ralph/codex goal)
| 항목 | ralph | codex goal | **solo** |
|---|---|---|---|
| 자동 라우팅 | 수동 | 수동 | **의도→에이전트 매트릭스** |
| 재시도 전략 | 같은 작업 반복 | 같은 모델 반복 | **다른 에이전트/전략으로 escalate** |
| 사용자 규칙 적용 | 없음 | 없음 | **CLAUDE.md/.rules 자동 흡수** |
| 트리아지 | 없음 (전체 파이프라인) | 없음 | **small은 PLAN/CONSENSUS 스킵** |
| 합의 강제 | 옵션 | 옵션 | **medium+는 의무 (사용자 규칙)** |
| 자기개선 | 없음 | 없음 | **history.jsonl 기반 라우팅 가중치** |
| 종료 신호 | architect approve | model decision | **3가지 신선 증거 + verifier + (security면) Codex adv-review** |

## Kill switches
- `/cancel`, "stop", "멈춰" → 즉시 cleanup
- `.env` 노출 시도 감지 → 절대 ABORT (재시도 X)
- max retries 5/phase → 사용자 confirm 대기
- 미해결 blocker (creds 누락, 사양 불명) → STOP & ask

## 상태 파일
- `.omc/state/solo-routing.json` — Phase 0 결과
- `.omc/state/solo-state.json` — phase 진행 + 재개용
- `.omc/plans/solo-{ts}.md` — Phase 1 산출물
- `.omc/solo-history.jsonl` — Phase 6 학습 데이터

## 구현 위치
- 커맨드: `plugin/claude/commands/solo.md` (thin wrapper)
- 스킬: `plugin/claude/skills/solo/SKILL.md` (전체 로직)
- 보조 스크립트: `plugin/claude/hooks/lib/solo-triage.sh` (의도 분류 휴리스틱)


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/CLAUDE.md ---
# CLAUDE.md

본 프로젝트의 모든 강제 규칙, 워크플로우, 보안 정책은 아래 파일에 정의되어 있다. **반드시 준수**.

## 핵심 규칙 (필수 참조)

- 📌 [coding](.claude/rules/coding.md) — TypeScript 엄격, 파일 200줄, TDD 필수, 공통화 우선
- 📌 [project](.claude/rules/project.md) — 개발 순서, 환경 분리, 자동화 (MCP 적극 활용)
- 📌 [design](.claude/rules/design.md) — shadcn/ui + Tailwind CSS
- 📌 [user-interaction](.claude/rules/user-interaction.md) — 토스트 3초, 삭제 확인 모달
- 📌 [folder](.claude/rules/folder.md) — 폴더 운영 규칙

## 핵심 워크플로우 스킬 (자동 주입)

`.claude/hooks/session-start.sh`가 매 세션 자동 컨텍스트 주입. 즉시 효력 발생.

- 📌 [branch-strategy](.claude/skills/branch-strategy/SKILL.md) — 브랜치 전략 + 본 프로젝트 예외
- 📌 [tdd-loop](.claude/skills/tdd-loop/SKILL.md) — TDD Red → Green → 합의 → 커밋
- 📌 [consensus-loop](.claude/skills/consensus-loop/SKILL.md) — Codex 합의 루프 (필수)
- 📌 [env-security](.claude/skills/env-security/SKILL.md) — .env 절대 규칙
- 📌 [session-index](.claude/skills/session-index/SKILL.md) — 세션 인덱스 + /resume-session

## 본 프로젝트 특별 정책

본 프로젝트는 **셋업/하네스 템플릿 성격** — 일반 서비스와 다른 다음 예외 적용:

- **브랜치**: `main` 단일 운영 (dev/main 분리 예외)
- **마커**: 프로젝트 루트의 `.harness-main-only` 파일
- **글로벌 가드**: `~/.claude/hooks/branch-guard.sh` 룰 4가 이 마커 감지 시 main commit 허용

다른 모든 서비스 프로젝트는 위 일반 규칙(`.claude/rules/`)을 따른다.

## QA

CRUD + 유저 인터랙션 시나리오 목록 작성 → Playwright MCP로 1개씩 체크하며 진행.

## 더 자세히

- [README](./README.md) — 프로젝트 소개 + 빠른 시작
- [04.docs/RUNBOOK](./04.docs/RUNBOOK.md) — 일상 운영
- [04.docs/RELEASE_NOTES](./04.docs/RELEASE_NOTES.md) — 버전별 변경
- [04.docs/HANDOFF](./04.docs/HANDOFF.md) — 세션 간 인계 (보존)


[HEADLESS SESSION] You are running non-interactively in a headless pipeline. Produce your FULL, comprehensive analysis directly in your response. Do NOT ask for clarification or confirmation - work thoroughly with all provided context. Do NOT write brief acknowledgments - your response IS the deliverable.

# /solo v3 리뷰 요청

## 컨텍스트
- v2는 두 리뷰어에서 REQUEST_CHANGES (OMC 5/10, Codex 6/10) 받음
- v3는 사용자 직접 인터뷰 답변 9개 항목 반영
- 핵심 변경: 80% rule, `/pg` 진행 명령, criteria 머신 검증 형식, 일탈 감지, commit-only, solo-result/ 폴더

## 사용 시나리오 (확정됨)
1~10시간 장시간 자율 실행. 사용자는 설계/기획만 티키타카(Stage A) → spec md 작성 → `/solo`로 자율 실행(Stage B) → 결과물 보고서 확인.

## 리뷰 대상
`.omc/research/solo-spec-v3.md`

## 답할 질문 (각각)

### Q1. v2 합의 항목 모두 유지됐는가?
v2에서 합의한 9개 변경(합의 의무, 브랜치 dev 기본값, Codex 슬래시 경유, 트리아지 휴리스틱, Reflexion 폐기→in-context, Gemini 폴백, 운영 가드 6종, 상태 파일 통일, --fast 합의 우회 제거)이 v3에 모두 살아있는가? 누락된 게 있는가?

### Q2. Phase 1 criteria 도출 방식 — 견고한가?
- planner가 LLM으로 criteria를 뽑는데, "머신 검증 가능한 verify_cmd"를 정확히 작성할 수 있는가?
- type=visual/manual은 결국 사람이나 playwright agent에 의존 — 자율 루프 안에서 어떻게 객관적으로 통과 판정?
- criteria 도출이 너무 많거나 너무 적게 나올 때 안전망?

### Q3. 80% rule — 위험 신호?
- 10h 도달 시 80% pass면 graceful exit. 그런데 통과 안 한 20%가 가장 중요한 criterion일 수 있음.
- must_pass 중에서 우선순위가 있어야 하나? (예: security/data-loss는 100% 의무)
- "80%면 OK"가 사용자 룰 위반 가능성?

### Q4. `/pg` 명령 — 실용성?
- 별도 slash command로 분리한 게 맞나, 아니면 `/solo --status`로 통합?
- 출력 형식이 사용자가 5시간 후 깨어나서 "지금 잘 되고 있나" 즉답 가능한가?

### Q5. 일탈 감지 — 가능한가?
- "사용자 명시 키워드가 직전 5 iteration 산출물에 0회" — 휴리스틱이 너무 단순한가?
- 잘못 감지로 멀쩡한 작업 멈춤 위험?

### Q6. Phase 5 — push/PR 없이 commit만?
- 사용자가 commit만 원했음. PR은 본인이 만든다는 의미.
- 그런데 10시간 자율 실행 후 자고 일어났을 때 commit이 main에 쌓여 있다? `.harness-main-only`가 아닌 프로젝트에서는 feature 브랜치 + push 없음 = 사용자가 직접 push해야 함 → 합리적인가?

### Q7. 실용성 — 진짜 1~10시간 돌 수 있는가?
- iteration 100회, 각 30초~5분 = 50min~500min = ~8h. 가능?
- Claude API 비용 $20 cap — Opus 다수 호출 시 한도 가능성?
- 24h soft timeout — 너무 길다? Anthropic API rate limit 우려?

### Q8. 최종 평가
**VERDICT**: APPROVE / REQUEST_CHANGES
**점수**: 1-10
**v2 대비 개선도**: ?
**가장 큰 남은 위험 1개**: ?
**구현 우선순위 Top 3**: ?
