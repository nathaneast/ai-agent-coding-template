# RUNBOOK

본 문서는 프로젝트 운영 절차를 기록한다.

---

## /solo

### 개요

`/solo`는 자연어 1줄 또는 spec 파일 하나를 받아 분석 → 완료조건 설정 → 실행 → 검증 → 커밋까지 자율로 처리하는 1줄 자율 빌드 에이전트다.

---

### 빠른 시작

#### 시나리오 A — 짧은 자연어로 바로 실행

```bash
/solo "결제 페이지에 토스 위젯 추가하고 콜백 API 연결"
```

Claude가 의도를 파싱하고, 완료조건(Criteria)을 자동 생성한 뒤 7 phase를 순서대로 실행한다.
`confidence < 0.7`이면 시작 전 1회 확인을 요청한다.

#### 시나리오 B — spec 파일 + Discord 알림

```bash
/solo --spec ./01.spec/toss-payment.md --notify discord
```

상세 요구사항이 마크다운 파일에 있을 때 사용한다.
`--notify discord`를 붙이면 완료 시 Discord webhook으로 7줄 요약이 전송된다.

#### 시나리오 C — 진행 상황 즉시 확인

```bash
/pg
```

실행 중인 `/solo`의 현재 phase, criteria 통과율, 비용, 예상 종료 시간을 즉시 출력한다.
별도 터미널에서 언제든 호출 가능하다.

출력 예시:

```
/solo 진행 중 (run_id: 20260514T1234)
Phase: 3 / Round 2
시간: 5h 12m / 24h
비용: $14.20 / $20  (다운그레이드 임박 $15)
Criteria: 4/7 PASS, 2 IN_PROGRESS, 1 DEFERRED
  C1, C4, C5 (critical), C2 (critical)
  C7 (critical, attempt 3, document-specialist)
  C6 (executor 분리 중)
  C3 (manual, deferred)
직전 reflection: C7 콜백 url 추측 오류 → document-specialist로 토스 환불 API 흡수
예상 종료: 7h 30m
```

---

### 7 Phase 흐름

| Phase | 이름 | 주체 | 핵심 처리 |
|---|---|---|---|
| 0 | TRIAGE | Claude main | 위험 키워드 정규식 1차 분류 + LLM 2차 의도 파싱. confidence < 0.7 → 사용자 confirm 1회 |
| 1 | 분석 + 완료조건 SET | planner (opus) | 요구사항 분해 → 각 단위에 verify_cmd 자동 생성. must_pass 최대 7개, critical 1개 이상, lint 1개 이상 의무 |
| 1.5 | DRY-RUN 게이트 | shell | 각 verify_cmd 실행 가능성 사전 확인. 실행 불가 항목은 manual로 강등. 전체 강등 시 STOP |
| 2 | CONSENSUS | Codex (critic) | planner 산출 criteria를 Codex로 합의. APPROVE → Phase 3 / REQUEST_CHANGES → planner 재호출 (max 4) |
| 3 | EXECUTE LOOP | executor / debugger / deep-executor | Task Queue 패턴으로 criteria 순환 처리. TDD red-first. 3회 실패 시 escalate, 5회 실패 시 사용자 확인 |
| 4 | VERIFY | verifier + lsp | 모든 verify_cmd 재실행. lsp_diagnostics_directory 0 error. build/typecheck 성공. security/arch는 adversarial-review 의무 |
| 5 | COMMIT | git | 변경 파일만 명시 스테이징. .env 감지 즉시 ABORT. Conventional Commits 메시지. push/PR 없음 |
| 6 | REPORT | — | 터미널 7~9줄 요약 + solo-result/{run_id}/report.md 상세 보고서 생성 |

**80% rule**: 10h 경과 + 80% 이상 통과 + critical 100% 통과 시 graceful 종료.
critical 미통과 상태로 10h 경과 시 종료 거부하고 12h 한계에서 CRITICAL_PENDING 마커 기록.

---

### 옵션 플래그

| 플래그 | 설명 | 기본값 |
|---|---|---|
| `"<자연어>"` | 1~3줄 자연어 프롬프트 | — |
| `--spec <경로>` | 마크다운 spec 파일 경로 | — |
| `--notify discord\|telegram` | 종료 시 webhook 알림 전송 | off |
| `--isolated` | git worktree 격리 실행 (psm 연동) | off |
| `--no-tdd` | TDD red-first 해제 (사유 자동 로깅) | off |
| `--resume` | 직전 phase에서 재개 | off |

**금지 조합**: security / auth / .env 라벨 감지 상태에서 `--no-consensus`는 제공하지 않는다.

---

### 운영 가드

| 항목 | 값 |
|---|---|
| MAX_ITERATIONS | 100 |
| MAX_COST_USD | $20 (다운그레이드 $15/$18) |
| MAX_DURATION_HARD | 24h |
| MAX_DURATION_GRACEFUL | 10h (80% rule 트리거, critical 100% 의무) |
| PHASE_TIMEOUT | 30min (Phase 1/2/4 — Phase 3은 전체 cap만 적용) |
| LOCK | `.omc/locks/solo.lock` (PID + TTL 30min) |
| WORKTREE 격리 | `--isolated` 플래그로 활성화 (psm 연동) |
| API rate limit | 지수 백오프 5/10/20/40s, max 5회 |
| 로그 보존 | `.omc/logs/solo/{run_id}/` 30일 |
| .env 가드 | git diff에 `.env` 패턴 감지 즉시 ABORT (재시도 없음) |

**비용 다운그레이드 단계**:
- $15 도달: opus 호출 → sonnet으로 강등
- $18 도달: sonnet → haiku (단순 작업만)

---

### 사용자 룰 자동 적용 매트릭스

| 룰 | 강도 | 해제 방법 |
|---|---|---|
| `.env*` 가드 (노출/커밋 차단) | 절대 | 불가 |
| Codex 합의 (Phase 2 CONSENSUS) | 절대 | 불가 |
| critical criteria 100% 통과 의무 | 절대 | 불가 |
| commit only, push/PR 없음 | 절대 | 불가 |
| TDD red-first | 기본 활성 | `--no-tdd` (사유 로깅됨) |
| 200줄 파일 제한 검사 (Phase 4) | 기본 활성 | 불가 |
| 브랜치 마커 자동 분기 | 자동 | — |
| shadcn/ui + Tailwind | UI 의도 감지 시 designer 컨텍스트 주입 | — |

**브랜치 분기 규칙**:
1. `.harness-main-only` 존재 → main 직커밋
2. `.harness-active` 존재 → `feature/{slug}` 자동 생성 (dev 베이스)
3. 둘 다 없음 → dev 베이스 (보수적 기본값)
4. 마커 충돌 (둘 다 존재) → Phase 0에서 사용자 confirm 1회 후 진행

---

### 실패 시나리오 + 대응

#### 락 충돌 — 다른 /solo 실행 중

증상: `/solo` 호출 시 "Lock already held" 메시지 출력.

원인: 이전 실행이 비정상 종료되어 `.omc/locks/solo.lock`이 남아 있거나, 실제로 다른 세션이 실행 중.

대응:
```bash
# PID 확인
cat .omc/locks/solo.lock

# 프로세스가 없으면 락 파일 직접 삭제
rm .omc/locks/solo.lock

# 재실행
/solo --resume
```

TTL이 30분이므로 30분 이상 경과한 락 파일은 stale로 간주하고 삭제해도 안전하다.

---

#### 비용 한도 초과 ($20)

증상: 실행 도중 "Budget exhausted" 메시지와 함께 강제 종료. 터미널 요약 및 report.md가 생성된다.

대응:
1. `solo-result/{run_id}/report.md`에서 미완료 criteria 확인
2. 미완료 항목만 골라 다시 `/solo` 호출하거나 직접 작업
3. $15/$18 다운그레이드 로그는 `.omc/logs/solo/{run_id}/cost-downgrade.log` 참조

예방: 작업을 더 작은 단위로 나눠 복수의 `/solo` 호출로 분할 실행.

---

#### critical criteria 미통과

증상: Phase 4 VERIFY 또는 Phase 3 EXECUTE LOOP 종료 시 critical 항목이 PASS가 아닌 상태.

동작: `/solo`는 graceful 종료를 거부하고 계속 시도한다. 12h 한계에 도달하면 `.omc/state/CRITICAL_PENDING` 마커를 기록하고 종료.

대응:
```bash
# 미통과 criteria 확인
cat .omc/state/solo-criteria.json | grep -A5 '"priority": "critical"'

# 마커 확인
ls .omc/state/CRITICAL_PENDING

# 수동으로 해당 criteria 작업 후 재실행
/solo --resume
```

---

#### Codex/Gemini 동시 장애 (DEGRADED_REVIEW)

증상: Phase 2 CONSENSUS에서 Codex 3회 재시도 + Gemini 폴백도 실패. `.omc/state/USER_CONFIRM_NEEDED` 마커 생성. 자동 진행이 멈추고 사용자 확인 대기.

동작: 이 상태에서 OMC `critic` + `security-reviewer` 2중 리뷰를 수행하고 결과를 report에 기록한다. 자동 진행은 절대 하지 않는다.

대응:
```bash
# 마커 및 리뷰 결과 확인
cat .omc/state/solo-criteria.json
ls .omc/state/USER_CONFIRM_NEEDED

# 내용 검토 후 진행 허가 — 마커 삭제로 재개 신호
rm .omc/state/USER_CONFIRM_NEEDED
/solo --resume
```

---

#### 일탈 감지 (USER_REVIEW_NEEDED)

증상: Phase 3에서 3라운드 연속으로 어떤 criteria도 진행률이 0%인 상태. `.omc/state/USER_REVIEW_NEEDED` 마커 생성 후 실행 중단.

원인: verify_cmd가 환경 문제로 항상 실패하거나, 요구사항 해석이 잘못된 경우.

대응:
```bash
# 직전 reflection 확인
cat solo-result/{run_id}/reflections.md

# criteria 상태 확인
cat .omc/state/solo-criteria.json

# 문제 파악 후 마커 삭제 → 재개
rm .omc/state/USER_REVIEW_NEEDED
/solo --resume

# 또는 criteria를 수정하고 처음부터 재실행
/solo "수정된 프롬프트"
```

---

### 결과물 위치

실행 완료 후 다음 경로에 결과물이 생성된다:

```
solo-result/
└── {run_id}/           # 예: 20260514T1234
    ├── report.md       # 상세 보고서 (criteria 결과 표, agent 통계, 가정 항목, 수동 확인 목록)
    └── reflections.md  # 라운드별 reflection 압축 로그
```

**report.md 주요 항목**:
- 작업 요약 및 최종 통과율
- Criteria 결과 표 (ID / priority / 결과 / attempts / 비고)
- 사용 agent 통계 및 누적 비용
- 가정한 항목 목록 (assumption: true 마크된 것)
- 수동 확인 필요 항목 + 수동 검증 단계
- push 명령 (예: `git push -u origin feature/toss-payment`)

`.omc/` 하위 운영 로그:
```
.omc/
├── state/
│   ├── solo-criteria.json     # 핵심 criteria 상태 (실시간 갱신)
│   ├── solo-state.json        # phase / iteration / elapsed
│   ├── solo-budget.json       # 비용 / 시간 카운터
│   └── USER_CONFIRM_NEEDED    # DEGRADED_REVIEW 마커 (존재 시 중단)
│   └── USER_REVIEW_NEEDED     # 일탈 감지 마커 (존재 시 중단)
│   └── CRITICAL_PENDING       # critical 미통과 + 12h 초과 마커
├── logs/solo/{run_id}/
│   ├── phase0~6.log
│   ├── iterations/{N}.log
│   └── cost-downgrade.log
└── locks/
    └── solo.lock
```

---

### 트러블슈팅

**q**: `/pg`를 실행했는데 "solo 실행 중이 아닙니다"라고 나온다.

**a**: `.omc/state/solo-state.json`이 없거나 phase가 `completed`/`failed`로 종료된 상태다. `solo-result/{run_id}/report.md`에서 최종 결과를 확인하라.

---

**q**: `--resume`으로 재개했는데 Phase 0부터 다시 시작한다.

**a**: `.omc/state/solo-state.json`의 `current_phase` 값이 손상되었거나 삭제된 경우다. `cat .omc/state/solo-state.json`으로 phase 값을 확인하고, 없으면 재실행이 불가피하다.

---

**q**: criteria가 전부 manual로 강등되어 Phase 1.5에서 멈췄다.

**a**: verify_cmd로 지정된 npm script, playwright, pytest 등이 프로젝트에 설치되지 않은 상태다. 필요한 도구를 설치하거나, spec을 수동 검증 가능한 형태로 재작성한 뒤 `/solo`를 다시 호출하라.

---

**q**: Phase 5 COMMIT에서 "pre-commit hook 실패"로 3회 연속 실패 후 중단됐다.

**a**: `debugger` agent가 3회 재시도했지만 해결 못한 상태다. `.omc/logs/solo/{run_id}/phase5.log`에서 hook 오류 내용을 확인하고 수동으로 수정한 뒤 `git commit`을 직접 실행하라. `/solo --resume`은 Phase 5부터 재개한다.

---

**q**: report.md에 "assumption: true" 항목이 있다. 어떻게 처리해야 하나?

**a**: 컨텍스트 부족으로 `/solo`가 가정을 적용하고 진행한 항목이다. report.md의 "가정한 항목" 섹션에 상세 내용이 기록된다. 가정이 틀렸으면 해당 항목을 수정하고 `/solo "수정 내용"`으로 재작업하거나 직접 편집하라.
