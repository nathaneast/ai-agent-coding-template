---
provider: "codex"
agent_role: "code-reviewer"
model: "gpt-5.3-codex"
files:
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/commands/solo.md"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/commands/pg.md"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/solo/SKILL.md"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-budget.sh"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-lock.sh"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-triage.sh"
  - "/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-dryrun.sh"
timestamp: "2026-05-14T13:31:02.416Z"
---

--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/commands/solo.md ---
---
description: 자연어 또는 spec 파일로 완전 자율 실행 — 분석·완료조건·합의·실행·검증·커밋 7단계 자동화
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /solo — 완전 자율 실행 에이전트

자연어 한 줄 또는 spec 파일을 입력하면 planner가 검증 가능한 완료조건을 자동 설정하고,
Codex 합의 → 실행 루프 → 검증 → 커밋까지 7 phase를 자율 처리한다.

## 옵션 플래그

| 플래그 | 설명 |
|---|---|
| `--spec <path>` | 마크다운 spec 파일 경로로 입력 |
| `--notify discord\|telegram` | 종료 시 알림 전송 |
| `--isolated` | git worktree 격리 실행 |
| `--no-tdd` | TDD red-first 해제 (사유 자동 로깅) |
| `--resume` | 직전 phase에서 재개 |

## 사용 예시

```bash
/solo "토스 결제 위젯을 /payment 페이지에 통합"
/solo --spec ./01.spec/payment.md --notify discord
/solo --resume
```

## 진행 상황 확인

실행 중 언제든 `/pg` 로 현재 phase, criteria 통과율, 비용을 즉시 출력.

---

User invoked `/solo` — invoke the `solo` skill with the following arguments:

$ARGUMENTS


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/commands/pg.md ---
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


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/solo/SKILL.md ---
---
name: solo
description: 자연어 1~3줄 또는 spec md를 받아 분석→완료조건 SET→합의→자율 실행→검증→커밋(=commit only)까지 단일 명령으로 끝내는 자율 워크플로우. critical 100% 의무, 80% graceful exit, /pg 진행률 조회, /codex:review 합의 의무, .env 절대 가드 내장.
---

# `/solo` — 자율 실행 워크플로우 (v4)

본 스킬은 **단일 사용자 + Claude 1인 운영 환경**에서 분석부터 커밋까지 7 phase 전체를 자율 수행한다. 호출 후 사용자는 `/pg`로 진행률만 보고, 종료 시 `solo-result/{run_id}/report.md`를 확인한다.

## 호출 형식

```bash
/solo "<자연어 1~3줄>"           # 기본
/solo --spec ./01.spec/feature.md # 마크다운 spec 입력
/solo --notify discord|telegram   # 종료 알림
/solo --isolated                  # psm worktree 격리 실행
/solo --no-tdd                    # TDD 해제 (사유 로깅 필수)
/solo --resume                    # 직전 run 재개

/pg                               # 진행 상황 출력 (실행 중 언제든지)
/cancel                           # 강제 중단 + 마커 정리
```

**금지 조합**: `risk_labels`에 security/auth/.env가 있을 때 합의 우회 옵션은 제공하지 않는다. Phase 2는 절대 의무.

---

## Phase 0 — TRIAGE

**입력**: 사용자 프롬프트 (+ `--spec` 파일 본문)

### 0-1. 락 획득

`.omc/locks/solo.lock` 검사 (PID + TTL 30min). 활성 락 존재 시:
- 같은 PID → `--resume` 강제 안내 후 STOP
- 다른 PID → "다른 /solo 실행 중. /cancel 후 재시도" STOP
- TTL 만료(stale) → 자동 정리 후 진행

신규 락 작성: `echo "$$:$(date +%s)" > .omc/locks/solo.lock`

### 0-2. 마커 충돌 검사 (v4 #9)

- `.harness-main-only` + `.harness-active` **동시 존재** → 사용자 confirm 1회 ("이상 상태인데 진행할까요?"). 거부 시 STOP.

### 0-3. solo-triage.sh 실행 + routing.json 작성 절차

1. `bash plugin/claude/hooks/lib/solo-triage.sh "<prompt>"` 실행
2. stdout JSON 흡수 (위험 키워드 1차 분류 결과)
3. LLM 2차 분류 (아래 0-4) 결과와 머지
4. 마커 검사: `bash plugin/claude/hooks/lib/solo-lock.sh check-markers`
   - 반환값 예시: `"main-only"`, `"active"`, `"none"`, 또는 두 마커 동시 존재 시 `exit 2`
   - `exit 2` (충돌) → 사용자 confirm 1회: `"두 마커 동시 발견. 어떤 것을 사용? [main-only/active/cancel]"`. cancel 선택 시 STOP.
5. 최종 `solo-routing.json` 작성 — **atomic write** (`.tmp → mv`)

### 0-4. 위험 키워드 정규식 (1차 분류)

프롬프트 + spec 본문 합쳐 매칭:
- `(auth|session|token|jwt|password|secret)` → `critical`
- `(schema|migration|alter\s+table|drop\s+table)` → `critical`
- `\.env` → `critical`
- `(payment|결제|토스|환불|refund)` → `high`

### 0-5. LLM 2차 분류 (Claude main 직접 판정)

JSON 1회 산출:
```json
{
  "intent": "build|fix|refactor|build-error|UI|docs|security",
  "scope": "<1줄 요약>",
  "risk_labels": ["..."],
  "confidence": 0.0-1.0,
  "rationale": "<왜 이렇게 분류했는지 1줄>"
}
```

`confidence < 0.7` → 사용자에게 1회 confirm. 거부 시 STOP.

### 0-6. 산출

`.omc/state/solo-routing.json` 작성 (atomic write: `.tmp → mv`) + `run_id` 생성 (`$(date +%Y%m%dT%H%M)`).

---

## Phase 1 — 분석 + 완료조건 SET (핵심 ★)

**주체**: `planner` (opus) — `Task(subagent_type="oh-my-claudecode:planner", model="opus", ...)`

### 1-1. planner 위임

planner에게 전달할 컨텍스트:
- 원본 프롬프트 + spec md
- `solo-routing.json` (intent/risk_labels)
- 본 프로젝트 룰: `.claude/rules/*.md`, `.claude/skills/*/SKILL.md`

planner는 다음을 산출한다:
1. 요구사항을 검증 가능 단위로 분해 (≤ 7개)
2. 각 단위마다 `verify_cmd` 자동 생성 (실행 가능한 명령어)
3. 각 단위에 `type` 부여: `test | lint | manual | build`

### 1-2. priority 자동 라벨 (v4 #1)

planner 산출 결과에 다음을 후처리로 적용:
- `risk_labels`에 security/auth/.env/schema 포함 → 해당 criteria `priority: critical`
- 모든 `type: lint` 항목 무조건 `priority: critical`
- 나머지 `priority: standard`

### 1-3. 인플레이션 가드 (v4 #4)

- `must_pass.length > 7` → 우선순위 낮은 standard 항목을 `nice_to_have`로 강등
- critical 0개 → routing.risk_labels 기반으로 1개 강제 추가 (예: ".env 노출 없음")
- lint 0개 → `npm run lint` 또는 `lsp_diagnostics_directory 0 error` 1개 강제 추가

### 1-4. 산출

`.omc/state/solo-criteria.json`:
```json
{
  "run_id": "20260514T1234",
  "must_pass": [
    {
      "id": "C1",
      "desc": "...",
      "verify_cmd": "npm test -- ...",
      "type": "test",
      "expected": "pass",
      "priority": "critical|standard",
      "status": "pending",
      "attempts": 0,
      "history": [],
      "assumption": false
    }
  ],
  "nice_to_have": []
}
```

**컨텍스트 부족 시**: 가정 진행 + `assumption: true` 마크. Phase 6 보고서에 명시.

`.omc/plans/solo-{run_id}.md`: planner 산출 원본 보존.

### 1-5. 타임아웃

Phase 1 자체 30min. 초과 시 사용자 confirm 1회.

---

## Phase 1.5 — DRY-RUN 검증 게이트 (v4 #3)

각 `must_pass[i].verify_cmd`의 **실행 가능성**을 사전 확인 (실제 실행 X).

### 1.5-1. 검사 매트릭스

| 명령 패턴 | 검사 방법 |
|---|---|
| `npm test ...` / `npm run X` | `package.json` `scripts.X` 존재 여부 |
| `playwright test ...` | `node_modules/@playwright/test` 존재 |
| `pytest ...` | `pytest --collect-only` dry run (백그라운드) |
| `lsp_diagnostics_directory` | 항상 가능 (built-in) |
| `bats ...` | `which bats` 존재 |
| 기타 shell | `command -v` 존재성만 |

### 1.5-2. 결과 처리

- 실행 가능 → 유지
- 실행 불가 → `type: manual`로 강등, `criteria.history`에 `{event: "downgraded_to_manual", reason}` 기록
- **모든 verify_cmd 강등** → STOP & 사용자 확인 ("자동 검증 불가능. 수동 검증으로 진행?")

### 1.5-3. atomic write

`.omc/state/solo-criteria.json` → `.tmp` → `mv` (원자적 갱신).

---

## Phase 2 — CONSENSUS

Codex 합의 의무. 우회 옵션 없음.

### 2-1. 1차 호출

`/codex:review --wait` 호출. 컨텍스트:
- `solo-criteria.json` 본체
- `solo-routing.json`
- planner 산출 plans md

### 2-2. VERDICT 파싱 (3단 폴백)

`consensus-loop` SKILL §파싱 그대로 따른다:
1. 정확 매칭 `VERDICT: APPROVE` / `VERDICT: REQUEST_CHANGES`
2. 동의어 `RECOMMENDATION:` / `FINAL:` / `결론:` / `OUTCOME:`
3. 본문 키워드 빈도 + 사용자 1회 confirm
4. 실패 → 기본값 `REQUEST_CHANGES`

### 2-3. 합의 루프

- `APPROVE` → Phase 3 진입
- `REQUEST_CHANGES` → planner 재호출 (피드백 반영) → 재리뷰. `MAX_LOOPS = 4` 초과 시 사용자 confirm.

### 2-4. Codex 장애 폴백 체인

1. **재시도**: 지수 백오프 5/10/20s, 최대 3회
2. **Gemini 대체**: `mcp__plugin_oh-my-claudecode_g__ask_gemini` (agent_role=critic)
3. **둘 다 실패 → DEGRADED_REVIEW 모드**:
   - OMC `critic` + `security-reviewer` 2중 리뷰 (병렬 Task 호출)
   - `.omc/state/USER_CONFIRM_NEEDED` 마커 작성
   - 자동 진행 금지. Phase 3은 사용자 확인 후 시작.

### 2-5. 타임아웃

Phase 2 자체 30min. 초과 시 폴백 체인 강제 진입.

---

## Phase 3 — EXECUTE LOOP (Task Queue + 80% rule)

### 3-1. routing_matrix

| intent | 1차 | 보조 |
|---|---|---|
| build | executor (sonnet) | test-engineer (TDD red) |
| fix | debugger → executor | test-engineer |
| refactor | deep-executor (opus) | quality-reviewer |
| build-error | build-fixer | — |
| UI | designer | executor |
| docs | writer (haiku) | — |
| security | security-reviewer | executor |

### 3-2. 루프 의사코드

```
queue = [c for c in criteria.must_pass if c.status == "pending"]
elapsed_start = now()
iteration = 0
cost_usd = 0
no_progress_rounds = 0

while queue and not exhausted():
    iteration += 1
    progressed_this_round = False

    for criterion in list(queue):
        # (1) agent 선택 + 비용 다운그레이드 (v4 #5)
        agent = routing_matrix[intent][criterion.priority]
        if cost_usd >= 15: agent = downgrade_to_sonnet(agent)
        if cost_usd >= 18: agent = downgrade_to_haiku(agent)  # 단순 작업만

        # (2) TDD red-first (--no-tdd 아닌 경우)
        if not flags.no_tdd and criterion.type == "test":
            tdd_red(criterion)  # test-engineer 호출

        # (3) 위임
        try:
            delegate(agent, criterion)
        except RateLimit:
            backoff(5, 10, 20, 40)  # 지수, max 5회

        # (4) verify_cmd 실행
        verdict = run_shell(criterion.verify_cmd)
        criterion.attempts += 1
        criterion.history.append({
            "attempt": criterion.attempts,
            "agent": agent,
            "verdict": verdict,
            "ts": now()
        })
        atomic_write("solo-criteria.json")  # /pg 즉시 반영 (v4 #8)

        # (5) 결과 처리
        if verdict == "pass":
            criterion.status = "passed"
            queue.remove(criterion)
            progressed_this_round = True
        elif verdict == "fail":
            if criterion.attempts == 3:
                agent = escalate(agent)  # executor→debugger→deep-executor
            elif criterion.attempts == 5:
                write_marker("USER_REVIEW_NEEDED")
                return  # STOP
        elif verdict == "manual":
            criterion.status = "deferred"
            queue.remove(criterion)

    # (6) 라운드 종료 평가
    pass_rate = passed_count / total_must_pass
    critical_pass = all(c.status == "passed"
                       for c in criteria.must_pass
                       if c.priority == "critical")
    elapsed = now() - elapsed_start

    # 100% 완료
    if all(c.status in ["passed", "deferred"] for c in criteria.must_pass):
        break

    # 80% graceful exit (critical 100% 의무)
    if elapsed >= 10*HOUR and pass_rate >= 0.8 and critical_pass:
        break

    # critical 미통과 시 graceful 거부
    if elapsed >= 10*HOUR and pass_rate >= 0.8 and not critical_pass:
        if elapsed >= 12*HOUR:
            write_marker("CRITICAL_PENDING")
            return

    # forced exit
    if cost_usd >= 20 or elapsed >= 24*HOUR or iteration >= 100:
        break

    # 일탈 감지 (v4 #7) — criterion ID 진행률 0% 3회 연속
    if not progressed_this_round:
        no_progress_rounds += 1
        if no_progress_rounds >= 3:
            write_marker("USER_REVIEW_NEEDED")
            return
    else:
        no_progress_rounds = 0

    # Reflection 압축 (직전 3 iteration → 다음 라운드 context)
    reflection = compress_last_3_iterations()
    inject_into_next_round_context(reflection)
```

### 3-3. 운영 가드 상수

| 항목 | 값 |
|---|---|
| MAX_ITERATIONS | 100 |
| MAX_COST_USD | 20 (다운그레이드 $15/$18) |
| MAX_DURATION_HARD | 24h |
| MAX_DURATION_GRACEFUL | 10h (80% rule 트리거) |
| RATE_LIMIT_BACKOFF | 5/10/20/40s, max 5회 |

### 3-4. atomic state write

매 criterion 시도 후:
- `.omc/state/solo-criteria.json` → `.tmp` → `mv`
- `.omc/state/solo-state.json` (phase/iteration/elapsed)
- `.omc/state/solo-budget.json` (cost/time 카운터)

이로써 `/pg` 호출 시 즉시 최신 상태 출력.

### 3-5. 로깅

`.omc/logs/solo/{run_id}/iterations/{N}.log`: 각 iteration agent 호출 + verify 결과 raw.
`.omc/logs/solo/{run_id}/cost-downgrade.log`: $15/$18 도달 시점 기록.

---

## Phase 4 — VERIFY (종료 직전)

### 4-1. Fresh evidence 재실행

Phase 3 종료 후 **모든 must_pass.verify_cmd를 다시 실행**:
- 캐시된 결과 신뢰 금지. fresh shell 실행만 인정.
- 추가:
  - `mcp__plugin_oh-my-claudecode_t__lsp_diagnostics_directory` → 0 error 확인
  - `npm run build` (또는 프로젝트 빌드 명령) → 성공 확인
  - `npm run typecheck` → 성공 확인

결과 갱신: `solo-criteria.json` history에 `{event: "phase4_recheck", verdict}` 추가.

### 4-2. verifier 호출

크기에 따라 모델 선택:
- 변경 < 5 files, < 100 lines → `verifier` (haiku)
- 표준 → `verifier` (sonnet)
- 변경 > 20 files 또는 security/architectural → `verifier` (opus)

`Task(subagent_type="oh-my-claudecode:verifier", model=tier, prompt="...")`

verifier에게 전달: `solo-criteria.json` 최종 + diff 요약 + Phase 4 fresh evidence.

### 4-3. 보강 게이트 (security/architectural)

`risk_labels`에 security/auth/.env/schema 있거나 변경 > 20 files:
- `/codex:adversarial-review --wait` **의무 호출**
- VERDICT REQUEST_CHANGES → Phase 3 재진입 (1회만 허용, 누적 cost 카운팅)

### 4-4. 200줄 게이트

수정/생성된 파일 중 `wc -l > 200` 있으면 `quality-reviewer` (sonnet) 자동 호출. APPROVE 받을 때까지 분리/리팩터.

### 4-5. Phase 4 타임아웃

30min. 초과 시 사용자 confirm.

---

## Phase 5 — COMMIT (push/PR 절대 안 함)

### 5-1. 브랜치 자동 분기

```
if .harness-main-only exists:
    target_branch = "main"  # 본 프로젝트 예외
elif .harness-active exists:
    target_branch = "feature/{slug}"  # dev 베이스
    git checkout -b feature/{slug} (없으면 생성)
else:
    target_branch = "feature/{slug}"  # 보수적 default, dev 베이스
```

`{slug}`: routing.intent + 핵심 키워드 (예: `feat-toss-payment`).

마커 충돌은 Phase 0에서 이미 차단됨.

### 5-2. 스테이징

- **변경 파일 명시 추가만 허용**. `git add -A`, `git add .` 절대 금지.
- 사용 패턴: `git add <file1> <file2> ...` (정확한 경로)

### 5-3. .env 절대 가드

```bash
git diff --name-only --cached | grep -E '(^|/)\.env($|\.)' && {
    write_marker "ENV_LEAK_ABORTED"
    git reset HEAD .env*
    STOP  # 재시도 X, 사용자 호출
}
```

이는 `.claude/skills/env-security/SKILL.md`의 절대 규칙. 우회 불가.

### 5-4. 커밋 메시지

Conventional Commits + Co-Authored-By. HEREDOC 사용:

```bash
git commit -m "$(cat <<'EOF'
feat(payment): toss integration

- C1, C2 통과 (결제 위젯 + 콜백 처리)
- run_id: 20260514T1234

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 5-5. pre-commit 실패 처리

훅 실패 시:
1. `debugger` agent로 원인 분석
2. 수정 후 **새 commit** (amend 금지)
3. max 3회 시도. 실패 시 STOP & 사용자 호출.

### 5-6. push/PR 절대 금지

- `git push`, `gh pr create` 호출 금지.
- 보고서에 정확한 명령 포함: `git push -u origin feature/{slug}`. 사용자가 직접 실행.

---

## Phase 6 — REPORT

### 6-1. 터미널 출력 (7~9줄)

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

### 6-2. solo-result/{run_id}/report.md

다음 섹션을 모두 포함:
1. **요약** — 작업 1줄, critical 통과율, 전체 통과율, 소요/비용/iteration, 다운그레이드 시점, 커밋 메시지
2. **Criteria 결과 표** — ID/priority/desc/결과/attempts/비고
3. **시도 history (압축)** — 라운드별 핵심 사건만 (escalation 시점 등)
4. **사용 agent 통계** — 호출수/누적 비용
5. **가정한 항목** — `assumption: true` criteria 나열 (사용자 확인 필요)
6. **수동 확인 필요** — manual deferred 각 항목의 검증 단계
7. **다음 권장 액션** — push 명령, PR 작성 안내

`solo-result/{run_id}/reflections.md`: Phase 3 라운드별 reflection 누적.

### 6-3. 알림 (`--notify` 설정 시)

- discord/telegram webhook → 터미널 요약 7줄 전송
- webhook 설정은 `.omc/state/notify-config.json` 참조 (없으면 silent skip)

### 6-4. solo-history.jsonl

누적 학습용. 1줄 append:
```json
{"run_id": "...", "intent": "...", "criteria_count": 7, "pass_rate": 0.86, "cost_usd": 17.80, "elapsed_min": 443, "outcome": "graceful_80", "downgrades": ["opus_to_sonnet_at_6h"]}
```

### 6-5. 락 해제

`.omc/locks/solo.lock` 삭제. 마커 정리:
- 종료 사유에 따라 `USER_CONFIRM_NEEDED` / `USER_REVIEW_NEEDED` / `CRITICAL_PENDING` 보존 (사용자 확인용)
- 정상 종료 시 모두 정리

---

## `/pg` 명령 처리

`/pg` 호출 시 Claude는 다음을 읽어 출력만 한다 (Phase 진행 중단 없음):
- `.omc/state/solo-criteria.json`
- `.omc/state/solo-state.json`
- `.omc/state/solo-budget.json`

출력 양식:
```
🚧 /solo 진행 중 (run_id: 20260514T1234)
Phase: 3 / Round 2
시간: 5h 12m / 24h
비용: $14.20 / $20  ⚠ 다운그레이드 임박 ($15)
Criteria: 4/7 PASS, 2 IN_PROGRESS, 1 DEFERRED
  ✅ C1, C4, C5 (critical), C2 (critical)
  🔄 C7 (critical, attempt 3, document-specialist)
  🔄 C6 (executor)
  ⏸ C3 (manual, deferred)
직전 reflection: <reflections.md 마지막 줄>
예상 종료: ~7h 30m
```

상태 파일 없으면: "현재 진행 중인 /solo 없음."

---

## `--resume` 처리

`/solo --resume` 호출 시:
1. `.omc/state/solo-state.json` 읽어 마지막 phase 확인
2. 락 stale 정리 + 재획득
3. 마커 우선순위:
   - `USER_REVIEW_NEEDED` / `CRITICAL_PENDING` 존재 → 사용자에게 해결 여부 1회 confirm
   - `USER_CONFIRM_NEEDED` (DEGRADED_REVIEW) → 동일
4. 해당 phase부터 재진입. criteria.must_pass[].status가 pending인 것만 queue 재구성.
5. budget 카운터는 누적 유지 (재개로 cost 초기화 금지).

---

## `/cancel` 처리

`/oh-my-claudecode:cancel` 호출 시:
- 현재 phase 즉시 중단 (in-flight Task 완료까지만 대기)
- `.omc/locks/solo.lock` 삭제
- 마커 정리 (사용자 옵션: `--keep-markers`로 보존 가능)
- `solo-result/{run_id}/report.md`에 `outcome: cancelled` 기록
- 터미널 출력: "/solo 중단됨. 부분 결과는 solo-result/{run_id}/report.md"

---

## State File Discipline

모든 `.omc/state/solo-*.json` 파일 갱신 시 **atomic write** 필수 (`.tmp → mv`):

| 파일 | 갱신 시점 |
|---|---|
| `solo-routing.json` | Phase 0-6 (triage 완료 후) |
| `solo-criteria.json` | Phase 1-4 산출, Phase 1.5 dry-run, Phase 3 매 criterion 시도 후, Phase 4 재검증 |
| `solo-state.json` | Phase 3 매 iteration 후 (phase/iteration/elapsed) |
| `solo-budget.json` | Phase 3 매 iteration 후 (cost/time 카운터) |

구현 패턴:
```bash
tmp=$(mktemp .omc/state/solo-routing.json.XXXXXX.tmp)
echo "$json" > "$tmp"
mv "$tmp" .omc/state/solo-routing.json
```

이로써 `/pg` 호출 시 불완전 파일을 읽는 race condition 방지.

---

## 운영 가드 7종 통합 (재확인)

| 가드 | 위치 | 동작 |
|---|---|---|
| 락 | Phase 0-1 | `.omc/locks/solo.lock` PID+TTL 30min |
| 비용 캡 | Phase 3-2 | $20 hard / $15·$18 다운그레이드 |
| 시간 캡 | Phase 3-2 | 24h hard / 10h graceful |
| 다운그레이드 | Phase 3-2 | opus→sonnet→haiku |
| Rate limit 백오프 | Phase 3-2 | 5/10/20/40s, max 5회 |
| 마커 | Phase 0-2, 2-4, 3-2, 5-3 | `USER_CONFIRM_NEEDED` / `USER_REVIEW_NEEDED` / `CRITICAL_PENDING` / `ENV_LEAK_ABORTED` |
| 알림 | Phase 6-3 | discord/telegram webhook |

---

## v4 신규 9개 안전장치 (체크)

1. ✅ **priority 자동 라벨** — Phase 1-2 (security/.env/auth → critical)
2. ✅ **80% rule + critical 100% 의무** — Phase 3-2 라운드 종료 평가
3. ✅ **Phase 1.5 dry-run 게이트** — verify_cmd 실행 가능성 사전 검증
4. ✅ **인플레이션 가드** — Phase 1-3 (max 7, critical ≥ 1, lint ≥ 1)
5. ✅ **비용 다운그레이드** — Phase 3-2 ($15/$18 단계)
6. ✅ **Task Queue 패턴** — Phase 3-2 의사코드 핵심
7. ✅ **일탈 감지** — Phase 3-2 no_progress_rounds 3회
8. ✅ **atomic state write** — Phase 0/1.5/3-4/6 모든 상태 파일 `.tmp` → `mv`
9. ✅ **마커 충돌 검사** — Phase 0-2

---

## Kill Switches

긴급 정지 수단 (사용자가 실행):
- `DISABLE_OMC=1` 환경 변수 → 모든 OMC 훅 무효화 (전역)
- `OMC_SKIP_HOOKS=solo-*` → solo 관련 훅만 우회
- `/cancel --force` → 모든 상태 파일 강제 정리
- `rm .omc/locks/solo.lock` → 락만 수동 해제

복구: `rm .omc/state/solo-*.json .omc/locks/solo.lock` (단, run 결과는 `solo-result/{run_id}/`에 보존).

---

## 사용자 핏 매트릭스

| 룰 | 강도 | 해제 |
|---|---|---|
| `.env*` 가드 | 절대 | 불가 |
| Codex 합의 (Phase 2) | 절대 | 불가 |
| TDD red-first | 기본 | `--no-tdd` (사유 로깅) |
| 200줄 제한 (Phase 4) | 기본 | 불가 |
| 브랜치 마커 분기 | 자동 | — |
| critical 100% 의무 | 절대 | 불가 |
| commit only (no push) | 절대 | 불가 |
| shadcn/ui + Tailwind | UI 의도 시 designer 컨텍스트 | — |

---

## 파일 구조 (산출물)

```
.omc/
├── state/
│   ├── solo-routing.json           # Phase 0
│   ├── solo-criteria.json          # Phase 1 (핵심)
│   ├── solo-state.json             # phase/iteration/elapsed
│   ├── solo-budget.json            # cost/time
│   ├── USER_CONFIRM_NEEDED         # DEGRADED_REVIEW
│   ├── USER_REVIEW_NEEDED          # 일탈/5회 fail
│   ├── CRITICAL_PENDING            # 80% + critical 미통과
│   └── ENV_LEAK_ABORTED            # .env 가드 발동
├── plans/solo-{run_id}.md
├── logs/solo/{run_id}/
│   ├── phase0~6.log
│   ├── iterations/{N}.log
│   └── cost-downgrade.log
├── locks/solo.lock
└── solo-history.jsonl              # 누적 학습

solo-result/{run_id}/
├── report.md                       # 사용자 확인용 본체
└── reflections.md                  # 라운드별 압축 회고
```

---

## Final Checklist (완료 기준)

다음을 **모두** 만족해야 Phase 6 종료 처리:

- [ ] `must_pass` 전 항목 `status ∈ {passed, deferred}` (critical 100% passed 의무)
- [ ] Phase 4 fresh evidence: 모든 verify_cmd 재실행 완료
- [ ] `lsp_diagnostics_directory` 0 error
- [ ] build/typecheck 성공
- [ ] verifier APPROVE 받음 (security/large 시 adversarial-review까지)
- [ ] 200줄 초과 파일 없음 (또는 quality-reviewer APPROVE)
- [ ] `.env*` diff 부재 (Phase 5-3 가드 통과)
- [ ] commit 성공 (pre-commit hook 포함)
- [ ] push/PR 미실행 확인
- [ ] `solo-result/{run_id}/report.md` 작성 완료
- [ ] `solo-history.jsonl` append
- [ ] 락 해제, 마커 정리 (또는 사용자 확인용 보존)

체크 미달 항목 존재 시 종료 금지. Phase 3로 복귀 또는 사용자 호출.

---

## 차별점 (참고)

| 항목 | ralph | codex goal | **solo v4** |
|---|---|---|---|
| 분석+완료조건 자동 set | ❌ | ❌ | ✅ planner + dry-run |
| Criteria 머신 검증 | ❌ | ❌ | ✅ verify_cmd |
| Critical priority 절대 의무 | ❌ | ❌ | ✅ 자동 라벨링 |
| 비용 다운그레이드 | ❌ | ❌ | ✅ $15/$18 |
| Task queue 패턴 | ❌ | ❌ | ✅ |
| 80% rule + critical 면제 | ❌ | ❌ | ✅ |
| /pg 즉시 진행률 | ❌ | ❌ | ✅ |
| DEGRADED_REVIEW 모드 | ❌ | ❌ | ✅ |
| commit only (no push) | 부분 | 부분 | ✅ 명시 |
| 운영 가드 7종 통합 | 부분 | 부분 | ✅ |

---

## 실행 첫 단계 (Claude가 `/solo` 호출 받았을 때)

1. 입력 파싱 → `--spec/--notify/--isolated/--no-tdd/--resume` 플래그 추출
2. `--resume` 있으면 위 `--resume 처리` 섹션으로 분기
3. 아니면 Phase 0-1 (락 획득) 시작
4. 사용자에게 첫 발화: `🚀 /solo 시작 (run_id: ...). Phase 0 TRIAGE 진행 중.` 1줄만 출력
5. 이후 phase 진행. `/pg` 호출 외에는 매 phase 종료 시점에만 1~2줄 상태 보고.

장황한 중간 출력 금지. Phase 종료 시점, 마커 작성 시점, 사용자 confirm 필요 시점에만 발화.


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-budget.sh ---
#!/usr/bin/env bash
set -euo pipefail

# solo-budget.sh — 비용/시간/iteration 카운터 + 다운그레이드 판정
# 상태 파일: .omc/state/solo-budget.json
# 서브커맨드: init | add-cost | inc-iter | check | recommend-tier | limit-reached

# ── 환경변수 오버라이드 ─────────────────────────────────────────────────────
SOLO_MAX_COST_USD="${SOLO_MAX_COST_USD:-20}"
SOLO_MAX_DURATION_H="${SOLO_MAX_DURATION_H:-24}"
SOLO_GRACEFUL_DURATION_H="${SOLO_GRACEFUL_DURATION_H:-10}"
SOLO_MAX_ITERATIONS="${SOLO_MAX_ITERATIONS:-100}"

# ── 상태 파일 경로 ─────────────────────────────────────────────────────────
# git worktree root 기준. 실행 위치에 관계없이 repo root 사용.
_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

_state_file() {
  echo "$(_repo_root)/.omc/state/solo-budget.json"
}

# ── atomic write 헬퍼 ──────────────────────────────────────────────────────
_atomic_write() {
  local target="$1"
  local content="$2"
  local tmp="${target}.tmp.$$"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' "$content" > "$tmp"
  mv "$tmp" "$target"
}

# ── 상태 파일 읽기 ─────────────────────────────────────────────────────────
_read_state() {
  local sf
  sf="$(_state_file)"
  if [[ ! -f "$sf" ]]; then
    echo "solo-budget: state file not found. run 'init' first." >&2
    exit 1
  fi
  cat "$sf"
}

# ── elapsed 초 계산 ────────────────────────────────────────────────────────
_elapsed_seconds() {
  local start_ts="$1"
  local now_ts
  now_ts="$(date +%s)"
  echo $(( now_ts - start_ts ))
}

# ── 서브커맨드: init ───────────────────────────────────────────────────────
cmd_init() {
  local run_id="${1:-}"
  if [[ -z "$run_id" ]]; then
    echo "usage: solo-budget.sh init <run_id>" >&2
    exit 1
  fi
  local now_ts
  now_ts="$(date +%s)"
  local json
  json="$(jq -n \
    --arg run_id "$run_id" \
    --argjson start_ts "$now_ts" \
    '{run_id: $run_id, start_ts: $start_ts, cost_usd: 0.0, iterations: 0}')"
  _atomic_write "$(_state_file)" "$json"
}

# ── 서브커맨드: add-cost ───────────────────────────────────────────────────
cmd_add_cost() {
  local delta="${1:-}"
  if [[ -z "$delta" ]]; then
    echo "usage: solo-budget.sh add-cost <usd>" >&2
    exit 1
  fi
  local sf
  sf="$(_state_file)"
  local current
  current="$(_read_state)"
  local updated
  updated="$(echo "$current" | jq --argjson d "$delta" '.cost_usd += $d')"
  _atomic_write "$sf" "$updated"
}

# ── 서브커맨드: inc-iter ───────────────────────────────────────────────────
cmd_inc_iter() {
  local sf
  sf="$(_state_file)"
  local current
  current="$(_read_state)"
  local updated
  updated="$(echo "$current" | jq '.iterations += 1')"
  _atomic_write "$sf" "$updated"
}

# ── 서브커맨드: check ──────────────────────────────────────────────────────
cmd_check() {
  local state
  state="$(_read_state)"
  local start_ts cost_usd iterations
  start_ts="$(echo "$state" | jq -r '.start_ts')"
  cost_usd="$(echo "$state" | jq -r '.cost_usd')"
  iterations="$(echo "$state" | jq -r '.iterations')"
  local elapsed_s
  elapsed_s="$(_elapsed_seconds "$start_ts")"
  local elapsed_h
  elapsed_h="$(echo "scale=4; $elapsed_s / 3600" | bc)"
  echo "$state" | jq \
    --argjson elapsed_s "$elapsed_s" \
    --argjson elapsed_h "$elapsed_h" \
    '. + {elapsed_seconds: $elapsed_s, elapsed_hours: $elapsed_h}'
}

# ── 서브커맨드: recommend-tier ────────────────────────────────────────────
cmd_recommend_tier() {
  local state
  state="$(_read_state)"
  local cost_usd
  cost_usd="$(echo "$state" | jq -r '.cost_usd')"
  # bc 부동소수점 비교
  local ge18 ge15
  ge18="$(echo "$cost_usd >= 18" | bc -l)"
  ge15="$(echo "$cost_usd >= 15" | bc -l)"
  if [[ "$ge18" -eq 1 ]]; then
    echo "haiku"
  elif [[ "$ge15" -eq 1 ]]; then
    echo "sonnet"
  else
    echo "opus"
  fi
}

# ── criteria_json helper: critical 전부 passed 여부 ──────────────────────
# 반환: 1 = 모두 passed, 0 = 미통과 항목 있음
_critical_all_passed() {
  local criteria_json_path="$1"
  if [[ ! -f "$criteria_json_path" ]]; then
    echo "solo-budget: criteria file not found: $criteria_json_path" >&2
    return 1
  fi
  local result
  result="$(jq '
    [ .must_pass[] | select(.priority == "critical") ] as $crits |
    if ($crits | length) == 0 then 0
    else
      ([ $crits[] | select(.status == "passed") ] | length) as $passed_cnt |
      if $passed_cnt == ($crits | length) then 1 else 0 end
    end
  ' "$criteria_json_path")"
  echo "$result"
}

# ── 80% pass rate 계산 ────────────────────────────────────────────────────
# 반환: 1 = pass_rate >= 0.8, 0 = 미달
_pass_rate_ok() {
  local criteria_json_path="$1"
  if [[ ! -f "$criteria_json_path" ]]; then
    echo "solo-budget: criteria file not found: $criteria_json_path" >&2
    return 1
  fi
  local result
  result="$(jq '
    (.must_pass | length) as $total |
    if $total == 0 then 0
    else
      ([ .must_pass[] | select(.status == "passed" or .status == "deferred") ] | length) as $ok_cnt |
      if (($ok_cnt / $total) >= 0.8) then 1 else 0 end
    end
  ' "$criteria_json_path")"
  echo "$result"
}

# ── 서브커맨드: limit-reached ─────────────────────────────────────────────
# 사용: limit-reached [criteria_json_path]
# 출력: cost | duration | iterations | graceful_ok | graceful_blocked_critical
#        | critical_pending | graceful_trigger | ok
cmd_limit_reached() {
  local criteria_json_path="${1:-}"

  local state
  state="$(_read_state)"
  local start_ts cost_usd iterations
  start_ts="$(echo "$state" | jq -r '.start_ts')"
  cost_usd="$(echo "$state" | jq -r '.cost_usd')"
  iterations="$(echo "$state" | jq -r '.iterations')"

  local elapsed_s elapsed_h
  elapsed_s="$(_elapsed_seconds "$start_ts")"
  elapsed_h="$(echo "scale=4; $elapsed_s / 3600" | bc)"

  # 한도 초과 판정 (우선순위 순)
  local cost_exceeded
  cost_exceeded="$(echo "$cost_usd >= $SOLO_MAX_COST_USD" | bc -l)"
  if [[ "$cost_exceeded" -eq 1 ]]; then
    echo "cost"
    return
  fi

  local dur_exceeded
  dur_exceeded="$(echo "$elapsed_h >= $SOLO_MAX_DURATION_H" | bc -l)"
  if [[ "$dur_exceeded" -eq 1 ]]; then
    echo "duration"
    return
  fi

  if [[ "$iterations" -ge "$SOLO_MAX_ITERATIONS" ]]; then
    echo "iterations"
    return
  fi

  # 80% rule graceful trigger (10h 기본)
  local graceful_exceeded
  graceful_exceeded="$(echo "$elapsed_h >= $SOLO_GRACEFUL_DURATION_H" | bc -l)"
  if [[ "$graceful_exceeded" -eq 1 ]]; then
    # criteria_json_path 없으면 기존 동작
    if [[ -z "$criteria_json_path" ]]; then
      echo "graceful_trigger"
      return
    fi

    local pass_ok critical_ok
    pass_ok="$(_pass_rate_ok "$criteria_json_path")"
    critical_ok="$(_critical_all_passed "$criteria_json_path")"

    if [[ "$pass_ok" -eq 1 && "$critical_ok" -eq 1 ]]; then
      # 10h 도달 + 80% pass + critical 100% → graceful_ok
      echo "graceful_ok"
      return
    fi

    if [[ "$pass_ok" -eq 1 && "$critical_ok" -eq 0 ]]; then
      # 10h 도달 + 80% pass + critical 미통과
      local hard12_exceeded
      hard12_exceeded="$(echo "$elapsed_h >= 12" | bc -l)"
      if [[ "$hard12_exceeded" -eq 1 ]]; then
        # 12h 도달 + critical 미통과 → critical_pending
        echo "critical_pending"
      else
        # 10h~12h + critical 미통과 → graceful_blocked_critical
        echo "graceful_blocked_critical"
      fi
      return
    fi

    # 80% 미달인 경우: criteria 있어도 graceful_trigger 유지
    echo "graceful_trigger"
    return
  fi

  echo "ok"
}

# ── 진입점 ────────────────────────────────────────────────────────────────
SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  init)          cmd_init "$@" ;;
  add-cost)      cmd_add_cost "$@" ;;
  inc-iter)      cmd_inc_iter ;;
  check)         cmd_check ;;
  recommend-tier) cmd_recommend_tier ;;
  limit-reached) cmd_limit_reached "$@" ;;
  *)
    cat >&2 <<'USAGE'
usage: solo-budget.sh <subcommand> [args]

subcommands:
  init <run_id>       초기화 (start_ts, cost_usd:0, iterations:0)
  add-cost <usd>      cost 누적
  inc-iter            iteration +1
  check               현재 상태 JSON 출력 (elapsed 포함)
  recommend-tier      다운그레이드 권장 tier (opus|sonnet|haiku)
  limit-reached [criteria_json_path]
                      한도 초과 검사 (cost|duration|iterations|graceful_ok|
                      graceful_blocked_critical|critical_pending|graceful_trigger|ok)

env overrides:
  SOLO_MAX_COST_USD          (default 20)
  SOLO_MAX_DURATION_H        (default 24)
  SOLO_GRACEFUL_DURATION_H   (default 10)
  SOLO_MAX_ITERATIONS        (default 100)
USAGE
    exit 1
    ;;
esac


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-lock.sh ---
#!/usr/bin/env bash
set -euo pipefail

# solo-lock.sh — /solo 동시 실행 방지 락 관리
# 사용법:
#   solo-lock.sh acquire <run_id>   락 획득 시도
#   solo-lock.sh release             락 해제
#   solo-lock.sh check               현재 락 상태 출력

LOCK_DIR=".omc/locks"
LOCK_FILE="${LOCK_DIR}/solo.lock"
TTL_MIN="${SOLO_LOCK_TTL_MIN:-30}"
TTL_SEC=$(( TTL_MIN * 60 ))

# .omc/locks 디렉토리 자동 생성
mkdir -p "${LOCK_DIR}"

_now_epoch() {
  date +%s
}

_read_lock() {
  # 락 파일을 읽어 pid / expires_at / run_id 를 전역 변수에 세팅
  if [[ ! -f "${LOCK_FILE}" ]]; then
    return 1
  fi
  local content
  content="$(cat "${LOCK_FILE}")"
  LOCK_PID="$(printf '%s' "${content}" | grep -o '"pid":[0-9]*' | grep -o '[0-9]*')"
  LOCK_EXPIRES="$(printf '%s' "${content}" | grep -o '"expires_at":[0-9]*' | grep -o '[0-9]*')"
  LOCK_RUN_ID="$(printf '%s' "${content}" | grep -o '"run_id":"[^"]*"' | sed 's/"run_id":"//;s/"//')"
  return 0
}

_write_lock() {
  local pid="$1"
  local run_id="$2"
  local expires_at=$(( $(_now_epoch) + TTL_SEC ))
  local tmp="${LOCK_FILE}.tmp"
  printf '{"pid":%d,"expires_at":%d,"run_id":"%s"}\n' "${pid}" "${expires_at}" "${run_id}" > "${tmp}"
  mv "${tmp}" "${LOCK_FILE}"
}

_is_pid_alive() {
  local pid="$1"
  kill -0 "${pid}" 2>/dev/null
}

_lock_expired() {
  local expires_at="$1"
  local now
  now="$(_now_epoch)"
  [[ "${now}" -ge "${expires_at}" ]]
}

cmd_acquire() {
  local run_id="${1:-}"
  if [[ -z "${run_id}" ]]; then
    echo "ERROR: acquire 에 run_id 인자가 필요합니다." >&2
    exit 2
  fi

  if _read_lock; then
    # 락 파일이 존재함 — 만료 또는 PID 사망 여부 확인
    local stale=0

    if _lock_expired "${LOCK_EXPIRES}"; then
      stale=1
    elif ! _is_pid_alive "${LOCK_PID}"; then
      stale=1
    fi

    if [[ "${stale}" -eq 1 ]]; then
      # 만료/죽은 락 → 강제 획득
      rm -f "${LOCK_FILE}"
      _write_lock "$$" "${run_id}"
      echo "INFO: stale 락 제거 후 획득 (이전 run_id=${LOCK_RUN_ID}, pid=${LOCK_PID})" >&2
      exit 0
    else
      # 유효한 락이 존재 → 충돌
      local now
      now="$(_now_epoch)"
      local remaining=$(( LOCK_EXPIRES - now ))
      echo "ERROR: /solo 이미 실행 중입니다." >&2
      echo "  run_id   : ${LOCK_RUN_ID}" >&2
      echo "  pid      : ${LOCK_PID}" >&2
      echo "  expires  : ${LOCK_EXPIRES} (남은 ${remaining}초)" >&2
      echo "  락 해제하려면: solo-lock.sh release" >&2
      exit 1
    fi
  else
    # 락 파일 없음 → 새로 획득
    _write_lock "$$" "${run_id}"
    echo "INFO: 락 획득 (run_id=${run_id}, pid=$$)" >&2
    exit 0
  fi
}

cmd_release() {
  if [[ -f "${LOCK_FILE}" ]]; then
    rm -f "${LOCK_FILE}"
    echo "INFO: 락 해제됨" >&2
  fi
  # 락 파일이 없으면 silent
  exit 0
}

cmd_check() {
  if _read_lock; then
    local now
    now="$(_now_epoch)"
    local remaining=$(( LOCK_EXPIRES - now ))
    if _lock_expired "${LOCK_EXPIRES}"; then
      echo "EXPIRED"
      echo "  run_id   : ${LOCK_RUN_ID}"
      echo "  pid      : ${LOCK_PID}"
      echo "  만료됨 (${remaining}초 전)"
      exit 1
    elif ! _is_pid_alive "${LOCK_PID}"; then
      echo "STALE (PID ${LOCK_PID} 사망)"
      echo "  run_id   : ${LOCK_RUN_ID}"
      exit 1
    else
      echo "LOCKED"
      echo "  run_id   : ${LOCK_RUN_ID}"
      echo "  pid      : ${LOCK_PID}"
      echo "  expires  : ${LOCK_EXPIRES} (남은 ${remaining}초)"
      exit 0
    fi
  else
    echo "NO_LOCK"
    exit 1
  fi
}

cmd_check_markers() {
  local project_root="${1:-$(pwd)}"
  local main_only_marker="${project_root}/.harness-main-only"
  local active_marker="${project_root}/.harness-active"
  local has_main_only=0
  local has_active=0

  [[ -f "${main_only_marker}" ]] && has_main_only=1
  [[ -f "${active_marker}" ]]    && has_active=1

  if [[ "${has_main_only}" -eq 1 && "${has_active}" -eq 1 ]]; then
    echo "ERROR: 마커 충돌 — .harness-main-only 와 .harness-active 가 동시에 존재합니다." >&2
    echo "  경로: ${project_root}" >&2
    echo "  둘 중 하나를 제거하세요." >&2
    exit 2
  elif [[ "${has_main_only}" -eq 1 ]]; then
    echo "main-only"
    exit 0
  elif [[ "${has_active}" -eq 1 ]]; then
    echo "active"
    exit 0
  else
    echo "none"
    exit 0
  fi
}

# ── 진입점 ──────────────────────────────────────────────
SUBCMD="${1:-}"
shift || true

case "${SUBCMD}" in
  acquire)       cmd_acquire "$@" ;;
  release)       cmd_release ;;
  check)         cmd_check ;;
  check-markers) cmd_check_markers "$@" ;;
  *)
    echo "사용법: solo-lock.sh {acquire <run_id>|release|check|check-markers [프로젝트_경로]}" >&2
    exit 2
    ;;
esac


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-triage.sh ---
#!/usr/bin/env bash
# Phase 0 위험 키워드 1차 분류
# usage: solo-triage.sh "<prompt text>"
#        또는 echo "<prompt>" | solo-triage.sh
set -euo pipefail

# --- 입력 수집 ---
if [[ -n "${1:-}" ]]; then
  PROMPT="$1"
else
  PROMPT="$(cat)"
fi

if [[ -z "$PROMPT" ]]; then
  echo '{"risk_labels":[],"highest_priority":"standard","matched_keywords":[]}'
  exit 0
fi

# --- 매칭 ---
LABELS=()
KEYWORDS=()

# critical: auth/session/token/jwt/password/secret
if echo "$PROMPT" | grep -qiE '(auth|session|token|jwt|password|secret)'; then
  LABELS+=("security")
  while IFS= read -r kw; do
    KEYWORDS+=("$kw")
  done < <(echo "$PROMPT" | grep -oiE '(auth|session|token|jwt|password|secret)' | tr '[:upper:]' '[:lower:]' | sort -u)
fi

# critical: schema/migration/alter table/drop table
if echo "$PROMPT" | grep -qiE '(schema|migration|alter[[:space:]]+table|drop[[:space:]]+table)'; then
  LABELS+=("database")
  while IFS= read -r kw; do
    KEYWORDS+=("$kw")
  done < <(echo "$PROMPT" | grep -oiE '(schema|migration|alter[[:space:]]+table|drop[[:space:]]+table)' | tr '[:upper:]' '[:lower:]' | sort -u)
fi

# critical: .env
if echo "$PROMPT" | grep -qE '\.env'; then
  LABELS+=("env")
  KEYWORDS+=(".env")
fi

# high: payment/결제/토스/환불/refund
if echo "$PROMPT" | grep -qiE '(payment|결제|토스|환불|refund)'; then
  LABELS+=("payment")
  while IFS= read -r kw; do
    KEYWORDS+=("$kw")
  done < <(echo "$PROMPT" | grep -oiE '(payment|결제|토스|환불|refund)' | tr '[:upper:]' '[:lower:]' | sort -u)
fi

# --- 우선순위 결정 ---
HIGHEST="standard"
for label in "${LABELS[@]:-}"; do
  case "$label" in
    security|database|env) HIGHEST="critical" ;;
    payment) [[ "$HIGHEST" != "critical" ]] && HIGHEST="high" ;;
  esac
done

# --- JSON 빌드 ---
# labels 배열 (중복 제거)
UNIQUE_LABELS=()
declare -A _seen_labels=()
if [[ ${#LABELS[@]} -gt 0 ]]; then
  for l in "${LABELS[@]}"; do
    if [[ -z "${_seen_labels[$l]+x}" ]]; then
      _seen_labels[$l]=1
      UNIQUE_LABELS+=("$l")
    fi
  done
fi

# keywords 배열 (중복 제거)
UNIQUE_KEYWORDS=()
declare -A _seen_kw=()
if [[ ${#KEYWORDS[@]} -gt 0 ]]; then
  for k in "${KEYWORDS[@]}"; do
    if [[ -z "${_seen_kw[$k]+x}" ]]; then
      _seen_kw[$k]=1
      UNIQUE_KEYWORDS+=("$k")
    fi
  done
fi

json_array() {
  local -n arr=$1
  local out="["
  local first=1
  if [[ ${#arr[@]} -gt 0 ]]; then
    for item in "${arr[@]}"; do
      [[ $first -eq 0 ]] && out+=","
      out+="\"$item\""
      first=0
    done
  fi
  out+="]"
  echo "$out"
}

LABELS_JSON="$(json_array UNIQUE_LABELS)"
KEYWORDS_JSON="$(json_array UNIQUE_KEYWORDS)"

printf '{"risk_labels":%s,"highest_priority":"%s","matched_keywords":%s}\n' \
  "$LABELS_JSON" "$HIGHEST" "$KEYWORDS_JSON"

# --- 단위 테스트 예제 (inline) ---
# [예제 1] input: "결제 페이지에 토스 연동 추가"
# expected: {"risk_labels":["payment"],"highest_priority":"high","matched_keywords":["결제","토스"]}
# 검증: bash solo-triage.sh "결제 페이지에 토스 연동 추가"
#
# [예제 2] input: "유저 인증 추가"
# expected: {"risk_labels":["security"],"highest_priority":"critical","matched_keywords":["auth"]}
# 검증: bash solo-triage.sh "유저 인증 추가"
# (note: "인증" 자체는 매칭 안 됨 — "auth"가 없어 standard. 실제 한국어 auth는 아래 예제로 대체)
#
# [예제 2b] input: "Add user auth and jwt token"
# expected: {"risk_labels":["security"],"highest_priority":"critical","matched_keywords":["auth","jwt","token"]}
# 검증: bash solo-triage.sh "Add user auth and jwt token"
#
# [예제 3] input: "그냥 버튼 색 바꿔"
# expected: {"risk_labels":[],"highest_priority":"standard","matched_keywords":[]}
# 검증: bash solo-triage.sh "그냥 버튼 색 바꿔"


--- File: /Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/hooks/lib/solo-dryrun.sh ---
#!/usr/bin/env bash
# solo-dryrun.sh — Phase 1.5 verify_cmd 실행 가능성 사전 검증
# Usage: solo-dryrun.sh [criteria_json_path]
# Output: 갱신된 criteria.json (dryrun_status 필드 추가) + stdout 요약

set -euo pipefail

CRITERIA_JSON="${1:-.omc/state/solo-criteria.json}"

# criteria.json 존재 확인
if [[ ! -f "$CRITERIA_JSON" ]]; then
  echo "[solo-dryrun] ERROR: criteria.json not found: $CRITERIA_JSON" >&2
  exit 1
fi

# jq 존재 확인
if ! command -v jq &>/dev/null; then
  echo "[solo-dryrun] ERROR: jq is required but not found in PATH" >&2
  exit 1
fi

# 스크립트 실행 위치 기준 프로젝트 루트 탐색 (git root 우선)
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ── 헬퍼: npm/yarn 스크립트 존재 여부 확인 ─────────────────────────────────
check_npm_script() {
  local script_name="$1"
  local pkg_json="$PROJECT_ROOT/package.json"

  if [[ ! -f "$pkg_json" ]]; then
    return 1
  fi

  # jq로 scripts 객체에서 해당 키 확인
  local exists
  exists=$(jq --arg name "$script_name" \
    'if .scripts and (.scripts | has($name)) then "yes" else "no" end' \
    "$pkg_json" 2>/dev/null || echo "no")

  [[ "$exists" == '"yes"' ]]
}

# ── 헬퍼: verify_cmd 분류 및 실행 가능성 판정 ─────────────────────────────
check_verify_cmd() {
  local cmd="$1"
  local status="unknown"

  # 1. system tool — 항상 통과
  if echo "$cmd" | grep -qE '^(grep|awk|sed|cat|head|tail|wc|find|ls)\b'; then
    echo "executable"
    return
  fi

  # 2. lsp_diagnostics — MCP tool, 항상 통과
  if echo "$cmd" | grep -qE '^lsp_diagnostics'; then
    echo "executable"
    return
  fi

  # 3. npm test / npm run <script>
  if echo "$cmd" | grep -qE '^npm (test|run)\b'; then
    local script_name
    if echo "$cmd" | grep -qE '^npm test'; then
      script_name="test"
    else
      # "npm run <script>" — 3번째 토큰
      script_name=$(echo "$cmd" | awk '{print $3}')
      # "npm run <script> -- ..." 형태에서 앞부분만
      script_name="${script_name%% *}"
    fi

    if [[ -n "$script_name" ]] && check_npm_script "$script_name"; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 4. yarn test / yarn run <script>
  if echo "$cmd" | grep -qE '^yarn (test|run)\b'; then
    local script_name
    if echo "$cmd" | grep -qE '^yarn test'; then
      script_name="test"
    else
      script_name=$(echo "$cmd" | awk '{print $3}')
      script_name="${script_name%% *}"
    fi

    if [[ -n "$script_name" ]] && check_npm_script "$script_name"; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 5. pnpm test / pnpm run
  if echo "$cmd" | grep -qE '^pnpm (test|run)\b'; then
    local script_name
    if echo "$cmd" | grep -qE '^pnpm test'; then
      script_name="test"
    else
      script_name=$(echo "$cmd" | awk '{print $3}')
      script_name="${script_name%% *}"
    fi

    if [[ -n "$script_name" ]] && check_npm_script "$script_name"; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 6. playwright
  if echo "$cmd" | grep -qiE 'playwright'; then
    local pw_installed=false
    if [[ -d "$PROJECT_ROOT/node_modules/@playwright/test" ]] || \
       [[ -d "$PROJECT_ROOT/node_modules/playwright" ]]; then
      pw_installed=true
    fi
    local pw_config=false
    if ls "$PROJECT_ROOT"/playwright.config.* &>/dev/null 2>&1; then
      pw_config=true
    fi

    if $pw_installed || $pw_config; then
      echo "executable"
    else
      echo "degraded"
    fi
    return
  fi

  # 7. pytest / python -m pytest
  if echo "$cmd" | grep -qE '(^pytest\b|python.*-m pytest)'; then
    if command -v pytest &>/dev/null || python3 -m pytest --version &>/dev/null 2>&1; then
      # collect-only dry run으로 실제 수집 가능성 확인 (실패해도 degraded)
      if pytest --collect-only -q &>/dev/null 2>&1 || \
         python3 -m pytest --collect-only -q &>/dev/null 2>&1; then
        echo "executable"
      else
        # pytest는 있지만 수집 실패 → degraded
        echo "degraded"
      fi
    else
      echo "degraded"
    fi
    return
  fi

  # 8. 매칭 안 됨 → unknown
  echo "unknown"
}

# ── 메인 처리 ─────────────────────────────────────────────────────────────────
TMP_FILE="${CRITERIA_JSON}.tmp.$$"

# 카운터 초기화
cnt_executable=0
cnt_degraded=0
cnt_unknown=0

# must_pass 배열 길이
total=$(jq '.must_pass | length' "$CRITERIA_JSON")

# 각 criterion 처리 (인덱스 기반 순회)
updated_json="$CRITERIA_JSON"

for i in $(seq 0 $((total - 1))); do
  criterion_id=$(jq -r ".must_pass[$i].id" "$CRITERIA_JSON")
  verify_cmd=$(jq -r ".must_pass[$i].verify_cmd // empty" "$CRITERIA_JSON")

  if [[ -z "$verify_cmd" ]]; then
    # verify_cmd 없으면 unknown
    dryrun_status="unknown"
    echo "[solo-dryrun] WARN: $criterion_id has no verify_cmd → unknown"
  else
    dryrun_status=$(check_verify_cmd "$verify_cmd")
  fi

  case "$dryrun_status" in
    executable)
      ((cnt_executable++)) || true
      ;;
    degraded)
      ((cnt_degraded++)) || true
      echo "[solo-dryrun] DEGRADED: $criterion_id — cmd='$verify_cmd' → type 강등 to manual"
      ;;
    unknown)
      ((cnt_unknown++)) || true
      echo "[solo-dryrun] WARN: $criterion_id — cmd='$verify_cmd' → unknown (실행 가능 여부 불명)"
      ;;
  esac

  # degraded면 type을 manual로 강등 + dryrun_status 추가
  # unknown/executable은 dryrun_status만 추가
  if [[ "$dryrun_status" == "degraded" ]]; then
    jq --argjson idx "$i" \
       --arg ds "$dryrun_status" \
       '.must_pass[$idx].dryrun_status = $ds | .must_pass[$idx].type = "manual"' \
       "$CRITERIA_JSON" > "$TMP_FILE" && mv "$TMP_FILE" "$CRITERIA_JSON"
  else
    jq --argjson idx "$i" \
       --arg ds "$dryrun_status" \
       '.must_pass[$idx].dryrun_status = $ds' \
       "$CRITERIA_JSON" > "$TMP_FILE" && mv "$TMP_FILE" "$CRITERIA_JSON"
  fi
done

# ── 전체 강등 검사: 모든 must_pass가 degraded면 STOP 마커 기록 ──────────────
all_degraded=true
for i in $(seq 0 $((total - 1))); do
  ds=$(jq -r ".must_pass[$i].dryrun_status" "$CRITERIA_JSON")
  if [[ "$ds" != "degraded" ]]; then
    all_degraded=false
    break
  fi
done

if $all_degraded && [[ "$total" -gt 0 ]]; then
  echo "[solo-dryrun] STOP: 모든 verify_cmd 실행 불가 → 사용자 확인 필요"
  touch "$(dirname "$CRITERIA_JSON")/USER_CONFIRM_NEEDED"
fi

# ── stdout 요약 ───────────────────────────────────────────────────────────────
echo ""
echo "━━━ [solo-dryrun] Phase 1.5 DRY-RUN 요약 ━━━"
echo "  총 criteria  : $total"
echo "  executable   : $cnt_executable  (그대로 유지)"
echo "  degraded     : $cnt_degraded  (type → manual 강등)"
echo "  unknown      : $cnt_unknown  (경고 — 수동 확인 권장)"
echo "  갱신 파일    : $CRITERIA_JSON"
if $all_degraded && [[ "$total" -gt 0 ]]; then
  echo "  ⚠ STOP 마커 생성됨 — 사용자 확인 후 진행"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


[HEADLESS SESSION] You are running non-interactively in a headless pipeline. Produce your FULL, comprehensive analysis directly in your response. Do NOT ask for clarification or confirmation - work thoroughly with all provided context. Do NOT write brief acknowledgments - your response IS the deliverable.

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
