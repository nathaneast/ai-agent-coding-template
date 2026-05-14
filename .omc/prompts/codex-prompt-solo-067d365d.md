---
provider: "codex"
agent_role: "critic"
model: "gpt-5.3-codex"
files:
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/CLAUDE.md"
  - "/Users/nathaneast/.claude/rules/omc-orchestration.md"
timestamp: "2026-05-14T12:07:41.458Z"
---

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


[BLOCKED] File '/Users/nathaneast/.claude/rules/omc-orchestration.md' is outside the working directory. Only files within the project are allowed.

[HEADLESS SESSION] You are running non-interactively in a headless pipeline. Produce your FULL, comprehensive analysis directly in your response. Do NOT ask for clarification or confirmation - work thoroughly with all provided context. Do NOT write brief acknowledgments - your response IS the deliverable.

# /solo 에이전트 설계 리뷰 요청

## 컨텍스트
사용자가 `/solo` 라는 단독 자율 에이전트 슬래시 커맨드를 만들고 싶어 함. 목표:
1. 기존 OMC `ralph`, Codex `goal` 같은 "혼자 끝까지 가는" 에이전트를 능가
2. 이 사용자의 개인 규칙(.env 절대 규칙, TDD 의무, Codex 합의 루프 의무, 단일 main 브랜치, 200줄 제한 등)에 핏하게 동작
3. 본 프로젝트의 `.claude/rules/`, `consensus-loop`, `tdd-loop`, `env-security`, `branch-strategy` 스킬과 충돌 없음

## 리뷰 대상 파일
- `.omc/research/solo-proposal-v1.md` (이 디렉토리)

## 리뷰 질문 (각각 답하시오)

### Q1. 차별화의 진정성
ralph + codex goal과 비교한 "차별점" 표가 진짜 차별인가, 아니면 단순 마케팅인가?
- "자동 라우팅" 매트릭스: 진짜 가치 있는가? 아니면 휴리스틱 라우팅이 오히려 잘못된 에이전트 호출 위험을 키우는가?
- "히스토리 기반 가중치 조정": 실제로 작동할 메커니즘이 있나? 아니면 vaporware?
- 만약 마케팅이면 더 단순한 설계로 줄일 것을 추천하라.

### Q2. 사용자 규칙 자동 적용 — 안전한가?
TDD/.env/합의/브랜치를 자동 강제하는 게:
- 사용자가 모르게 너무 많이 결정해 버려서 오히려 답답해질 위험?
- 어떤 경우에 자동 강제를 해제할 수 있어야 하는가?
- `.harness-main-only` 마커 감지로 브랜치 정책 분기하는 게 견고한가?

### Q3. Phase 0 트리아지의 휴리스틱
의도 분류(build/fix/refactor/...)와 스코프 추정(small/standard/large)이 휴리스틱인데:
- 어떻게 신뢰성 있게 분류할 수 있는가? LLM에 맡기나, 규칙 기반인가?
- 잘못 분류 시 어떤 안전망이 필요한가?
- `--strict` `--fast` 플래그가 휴리스틱 실패를 보완하기에 충분한가?

### Q4. 합의 루프 max 4 + 폴백
- max 4 retry 후 사용자 confirm 대기는 합리적인가?
- Codex 장애 시 OMC critic 폴백 — 단일 critic이 의미 있는 합의를 만드는가? (1인 합의는 합의가 아닌데)
- 더 나은 폴백 전략은?

### Q5. Phase 6 "REFLECT" — 실제로 작동할 학습 메커니즘?
`.omc/solo-history.jsonl` 기반 라우팅 가중치 조정:
- 어떻게 구체적으로 가중치를 업데이트하는가? (식이 없음)
- 가중치 부패(drift) 방지 메커니즘?
- 차라리 history 자체를 다음 라우팅의 in-context 예시로 주는 게 낫지 않나?

### Q6. 빠진 게 있는가?
다음 항목이 누락됐는지 확인:
- 비용/토큰 캡 (장시간 자율 실행의 비용 폭주 방지)
- 사용자 알림 (Discord/Telegram 등) — 장시간 작업 후
- 동시 `/solo` 다중 실행 방지 락
- Worktree 격리 옵션
- 실행 로그 보존 정책

### Q7. 최종 평가
**VERDICT** (한 줄): `APPROVE` / `REQUEST_CHANGES`
**점수** (1-10): ?
**가장 큰 문제 1개**: ?
**가장 큰 강점 1개**: ?
**제안하는 수정 우선순위 Top 3**: ?
