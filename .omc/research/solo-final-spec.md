# `/solo` — Final Spec (v2, 합의 후)

> OMC critic (5/10) + Codex critic (6/10) 모두 v1을 **REQUEST_CHANGES**.
> 본 v2는 두 리뷰의 합의점을 반영한 최종 설계.

---

## 합의된 핵심 변경 (v1 → v2)

| # | 변경 | 근거 |
|---|---|---|
| 1 | **`small` 도 합의 루프 의무화** | 사용자 룰 `consensus-loop` = "모든 설계/개발/QA 합의 의무" |
| 2 | **`--fast` 에서 합의 스킵 제거** | `--fast`는 plan 압축만 허용, 합의는 항상 |
| 3 | **브랜치 기본값 `dev`** (마커 없을 때) | `branch-strategy/SKILL.md` 정합성. `feature/*`는 dev에서 분기 |
| 4 | **Codex 직접 MCP 호출 금지** | `/codex:review` 슬래시 경유만. consensus-loop §rules |
| 5 | **Phase 0 트리아지 = 규칙 1차 + LLM 2차** | confidence 0~1 출력, 낮으면 strict 자동 승격 |
| 6 | **Phase 6 가중치 학습 폐기** | 대신 Reflexion in-context (최근 3 reflection 주입) |
| 7 | **폴백 합의 재정의** | Codex 실패 → Gemini critic (1차), 둘 다 실패 → "DEGRADED_REVIEW" 모드 + 사용자 confirm 의무 |
| 8 | **운영 가드 6종 추가** | 비용 캡, 락, 알림, worktree, 타임아웃, 로그 보존 |
| 9 | **상태 파일 경로 통일** | `.omc/state/solo-*.json` |

---

## 1. 호출

```bash
/solo "<자연어 작업>"
/solo --plan-only "..."       # 계획만 (실행 X). 합의는 수행.
/solo --strict "..."          # 모든 단계 합의 + verifier opus 강제
/solo --no-tdd "..."          # TDD 해제 (사유 로깅 + 결과물에 표시)
/solo --no-consensus "..."    # 합의 해제 (사용자 명시 확인 — 위험)
/solo --isolated "..."        # git worktree 격리 실행
/solo --resume                # 직전 phase에서 재개
/solo --notify discord        # 종료 시 알림 (discord|telegram|none)
```

**금지된 조합**: `--no-consensus` + auth/schema/security 변경 패턴 감지 → 자동 거부.

---

## 2. 파이프라인 (7 phases)

### Phase 0 — TRIAGE (Claude main)

**1차 규칙 기반**:
- 의도 키워드 → intent 후보 (build|fix|refactor|explain|research|review|design|test|docs|setup)
- 위험 키워드 정규식: `(auth|session|token|jwt|password|secret)`, `(schema|migration|alter\s+table|drop)`, `\.env`, `(rm\s+-rf|--force|reset\s+--hard)`
- 위험 매치 = 강제 standard 승격, security 라벨 추가

**2차 LLM 분류** (Claude main 자기 수행):
- 출력 스키마: `{intent, scope, risk_labels[], confidence∈[0,1], rationale_3lines}`
- `confidence < 0.7` → 자동 `--strict` 승격 + 사용자 1회 confirm
- `--no-consensus`가 켜졌어도 risk_labels에 `security` 있으면 거부

**산출물**: `.omc/state/solo-routing.json`

### Phase 1 — PLAN (조건부, opus)

- `scope=small` 이고 위험 없음 → 1줄 plan만 (스킵 아님; 합의 위해 최소 plan)
- 그 외 → `oh-my-claudecode:planner` (opus)
- 산출물: `.omc/plans/solo-{run_id}.md`
- 모호 medium+ → 사용자 1회 확인

### Phase 2 — CONSENSUS (의무, scope 무관)

**경로 강제**:
1. `/codex:review --wait` (슬래시만, MCP 직접호출 금지)
2. VERDICT 파싱 3단 폴백 (consensus-loop SKILL §파싱)
3. APPROVE → Phase 3 / REQUEST_CHANGES → 계획 수정 → 재시도 (max 4)

**폴백 순서** (Codex 장애):
1. Codex 재시도 (백오프 5/10/20s, 3회)
2. `mcp__g__ask_gemini` (agent_role=critic) — primary 폴백
3. 둘 다 실패 → **DEGRADED_REVIEW** 모드:
   - OMC `critic` + `security-reviewer` 2중 리뷰 (단일 critic 금지)
   - 결과물 + `.omc/state/USER_CONFIRM_NEEDED` 마커 작성
   - 자동 커밋 금지, 사용자 확인 후만 Phase 3 진행

### Phase 3 — EXECUTE (병렬, tiered)

**라우팅 매트릭스** (OMC `team-exec` 기본값과 정합):

| 의도 | 1차 (모델) | 보조 |
|---|---|---|
| build/feature | `executor` (sonnet) | `test-engineer` (TDD red) |
| bug fix | `debugger` → `executor` | `test-engineer` |
| refactor (large) | `deep-executor` (opus) | `quality-reviewer` |
| build/type error | `build-fixer` | — |
| UI/UX | `designer` (sonnet) | `executor` |
| docs | `writer` (haiku) | — |
| security | `security-reviewer` | `executor` |
| research | `document-specialist` | — |
| architecture | `architect` (opus) | `critic` |

**TDD 의무** (`--no-tdd` 해제 외):
- test-engineer가 red 테스트 먼저 작성
- executor가 green 구현

**독립 작업 = 단일 메시지로 동시 발행** (병렬). 설치/빌드/테스트 → `run_in_background: true`.

### Phase 4 — VERIFY

**3가지 신선 증거**:
1. 테스트 → 0 fail
2. `lsp_diagnostics_directory` → 0 error
3. build/typecheck → 성공

**verifier 호출**:
- small → haiku, standard → sonnet, large/security → opus

**보강 게이트** (security/architectural 변경):
- `/codex:adversarial-review --wait` 의무
- 파일 200줄 초과 시 `quality-reviewer` 자동 호출

### Phase 5 — COMMIT

**브랜치 우선순위 (Codex 지적 반영)**:
1. `.harness-main-only` 있음 → main 직커밋 허용
2. `.harness-active` 있음 → `feature/{slug}` 자동 생성 (dev 베이스)
3. 마커 둘 다 없음 → **`dev` 베이스 유지** (보수적 default, `branch-strategy` 정합)

**스테이징**:
- 변경 파일만 명시 (`git add -A`/`.` 금지)
- `.env*` 패턴 감지 시 ABORT (재시도 X)

**메시지**: Conventional Commits + `Co-Authored-By: Claude`.

**pre-commit 실패**:
- `debugger` 호출 → 재커밋 (max 3)
- 3회 실패 → STOP & 사용자 알림

### Phase 6 — REFLECT (단순화)

- 실행 요약을 `.omc/solo-history.jsonl`에 append:
  ```json
  {"run_id","ts","intent","scope","confidence","agents":[],"retries":N,"verdict","duration_s","files_changed":N,"cost_usd":F}
  ```
- **학습 메커니즘**: 다음 `/solo` 호출 시, 동일 intent 최근 3건의 reflection을 in-context로 주입 (Reflexion 패턴)
- **가중치 학습 없음** (vaporware 회피)
- 히스토리는 감사/디버깅용

**실패 패턴 감지**:
- 3+ 동일 intent 연속 REQUEST_CHANGES → 사용자 알림
- 3+ 동일 phase verifier reject → blocker 보고

---

## 3. 사용자 핏 (자동 적용 / 해제 가능 매트릭스)

| 룰 | 강도 | 해제 옵션 |
|---|---|---|
| `.env*` Read/Write/grep 가드 | **절대 강제** (해제 불가) | — |
| Codex 합의 루프 | **절대 강제** | `--no-consensus` (security 변경 시 거부) |
| TDD red-first | 기본 강제 | `--no-tdd` (사유 로깅) |
| 200줄 파일 제한 | 기본 강제 | 해제 옵션 없음 (Phase 4에서 reviewer 호출) |
| `.harness-main-only` 분기 | 자동 감지 | — |
| shadcn/ui + Tailwind 강제 | UI 의도일 때만 | — |
| toast 3s, delete confirm 모달 | UI 의도일 때 designer 컨텍스트 주입 | — |

---

## 4. 운영 안전장치 (신규)

| 항목 | 기본값 | 위치 |
|---|---|---|
| 비용 캡 | `max_cost_usd=5.0`, `max_tokens=2M`, `max_tool_calls=200` | `.omc/state/solo-budget.json` |
| 시간 캡 | 전체 10h, phase별 30min | 동일 |
| 다중 실행 락 | `.omc/locks/solo.lock` (PID+TTL 30min) | — |
| Worktree 격리 | `--isolated`로 활성화 | `psm` 스킬 연동 |
| 알림 | `--notify discord|telegram` | `configure-notifications` 연동 |
| 로그 | `.omc/logs/solo/{run_id}/` (30일 보존) | — |

---

## 5. 상태 파일 (경로 통일)

```
.omc/
├── state/
│   ├── solo-routing.json       # Phase 0 산출
│   ├── solo-state.json         # phase 진행 + --resume용
│   ├── solo-budget.json        # 비용/시간 카운터
│   └── USER_CONFIRM_NEEDED     # DEGRADED_REVIEW 마커 (있을 때)
├── plans/
│   └── solo-{run_id}.md        # Phase 1 산출
├── logs/
│   └── solo/{run_id}/
│       ├── phase0-triage.log
│       ├── phase2-consensus.log
│       ├── phase3-execute.log
│       └── phase4-verify.log
├── locks/
│   └── solo.lock               # PID + expires_at
└── solo-history.jsonl          # Phase 6 누적
```

---

## 6. Kill switches

- `/cancel`, "stop", "멈춰" → 즉시 cleanup + 락 해제
- `.env` 노출 시도 → 절대 ABORT (재시도 없음)
- max retries 5/phase → 사용자 confirm 대기
- 비용/시간 캡 초과 → STOP & 알림
- 락 발견 → 기존 실행에 attach 옵션 제시

---

## 7. 차별점 (vs ralph / codex goal) — 진짜 차별만

| 항목 | ralph | codex goal | **solo (v2)** |
|---|---|---|---|
| **사용자 룰 자동 적용** | ❌ | ❌ | ✅ TDD/.env/합의/branch/200줄/shadcn 자동 적용 + 개별 해제 플래그 |
| **위험 신호 강제 승격** | ❌ | ❌ | ✅ auth/schema/.env 정규식 → 자동 strict |
| **DEGRADED_REVIEW 모드** | ❌ | ❌ | ✅ Codex 장애 시 2중 리뷰 + 사용자 confirm |
| **운영 가드 (비용/락/worktree/알림)** | 부분 | 부분 | ✅ 6종 통합 |
| **신뢰도 기반 트리아지** | ❌ | ❌ | ✅ confidence < 0.7 → 사용자 confirm |
| **Reflexion in-context** | ❌ | 부분 | ✅ 최근 3건 reflection 다음 호출 주입 |

**차별 안 됨 (정직 표기)**:
- 라우팅 매트릭스 = OMC team-exec 기본값 재선언 (가치는 있지만 "독창"은 아님)
- 가중치 학습 = vaporware로 판명되어 폐기

---

## 8. 구현 위치

```
plugin/claude/
├── commands/
│   └── solo.md                 # thin wrapper
├── skills/
│   └── solo/
│       ├── SKILL.md            # 전체 로직 (이 문서를 기반으로 작성)
│       └── triage-rules.md     # 위험 키워드 정규식 사전
└── hooks/
    └── lib/
        ├── solo-triage.sh      # Phase 0 규칙 1차 분류
        ├── solo-lock.sh        # 락 검사/획득/해제
        └── solo-budget.sh      # 비용/시간 카운터
```

---

## 9. 합의 결과 메타

- **OMC critic**: REQUEST_CHANGES (5/10) → v2에서 7개 우선순위 반영
- **Codex critic**: REQUEST_CHANGES (6/10) → v2에서 8개 우선순위 반영
- **공통 합의**: 9개 핵심 변경 (위 §합의된 핵심 변경 표)
- **상이점 처리**:
  - OMC: Gemini를 폴백으로 → 채택 (1차 폴백)
  - Codex: 2중 리뷰 → 채택 (Gemini도 실패 시 DEGRADED_REVIEW)

**v2 점수 추정** (셀프): 7.5/10. 남은 약점은 (a) `solo-triage.sh` 의 휴리스틱 정규식 사전이 실제 사용 데이터 없이 튜닝됨, (b) Reflexion in-context의 표본 크기 효과 미검증. 둘 다 운영 후 반복 개선 대상.

---

## 10. 다음 액션 (구현 단계)

1. `plugin/claude/commands/solo.md` (thin wrapper)
2. `plugin/claude/skills/solo/SKILL.md` (이 문서 §1~§6 기반)
3. `plugin/claude/hooks/lib/solo-triage.sh` (Phase 0 규칙 사전)
4. `plugin/claude/hooks/lib/solo-lock.sh`, `solo-budget.sh`
5. 통합 테스트: 4가지 시나리오 (small/standard/security/codex장애)
6. `04.docs/RUNBOOK.md`에 `/solo` 운영 가이드 추가
