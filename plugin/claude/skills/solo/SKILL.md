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
