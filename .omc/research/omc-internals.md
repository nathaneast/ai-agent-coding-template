# OMC 내부 분석: 무인 자동 빌드 워크플로우 적합성 평가

**분석 대상**: oh-my-claudecode 4.1.2  
**분석 일자**: 2026-05-14  
**목적**: "1프롬프트 → 10시간 자동 빌드 → 완료조건 충족까지 무인 실행 + 보고서" 워크플로우 구현 가능성 평가

---

## Q1. 무한 루프 메커니즘

**ralph**: `persistent-mode.cjs`의 Stop 훅이 핵심이다. Claude Code가 응답을 끝내려 할 때 Stop 훅이 실행되어 `ralph-state.json`의 `active: true`를 확인하면 `decision: "block"`을 반환해 응답을 강제 재시작한다.

```js
// persistent-mode.cjs:353-369
if (ralph.state?.active && !isStaleState(ralph.state) && isSessionMatch(...)) {
  const iteration = ralph.state.iteration || 1;
  const maxIter = ralph.state.max_iterations || 100;
  if (iteration < maxIter) {
    ralph.state.iteration = iteration + 1;
    console.log(JSON.stringify({ decision: "block", reason: `[RALPH LOOP - ITERATION ${iteration+1}/${maxIter}]...` }));
  }
}
```

**최대 반복**: `max_iterations` 기본값 100. 상태 파일에서 설정 가능.  
**스테일 감지**: `STALE_STATE_THRESHOLD_MS = 2 * 60 * 60 * 1000` (2시간). 마지막 업데이트로부터 2시간 초과 시 자동 비활성화 → **10시간 빌드에는 치명적 제약**.  
**User abort / context limit**: 별도로 감지하여 블로킹을 건너뜀 (교착상태 방지).

**ultrawork**: Stop 훅 Priority 7에서 처리. `max_reinforcements` 기본값 50. 태스크 미완료 시 무조건 continue.

---

## Q2. 완료 조건 검증

**ralph의 완료 판단 구조** (`skills/ralph/SKILL.md`):
1. TODO 항목 전체 완료 확인
2. 빌드/테스트/lint 실행 후 출력 확인
3. `architect` 에이전트(Opus) 호출로 검증
4. 승인 시 `/oh-my-claudecode:cancel` 실행 → 상태 파일 정리

**사용자가 acceptance criteria를 명시하는 공식 인터페이스는 없다.**  
`--prd` 플래그 사용 시 `prd.json`에 `acceptanceCriteria` 배열을 생성하지만, 이는 ralph-init이 LLM 자체적으로 생성하는 것이지 사용자가 구조화된 형식으로 주입하는 입력창이 아니다.

```json
// .omc/prd.json 구조 (ralph-init.md)
{ "userStories": [{ "acceptanceCriteria": ["Criterion 1", "Typecheck passes"], "passes": false }] }
```

**ultraqa** (`ultraqa.md`): `max_cycles: 5` 하드코딩. 동일 실패 3회 반복 시 조기 종료.

---

## Q3. 자기 평가 (Self-Evaluation) 메커니즘

**ralph의 architect 검증은 단순 1회 호출이 아니라 루프다**:
- 검증 실패 시 → 수정 → 동일 아키텍트 재검증 반복
- 코드 크기에 따라 tier가 결정됨: <5파일은 Sonnet(`architect-medium`), >20파일은 Opus(`architect`)
- `SKILL.md`에 "If architect rejects verification, fix the issues and re-verify (do not stop)" 명시

**그러나 진정한 LLM-as-judge 루프는 아니다:**
- 검증 에이전트는 동일 Claude 모델 계열
- 독립적인 판단자(다른 모델, 외부 지표)가 아니라 동일 LLM의 다른 인스턴스
- Codex(`ask_codex`)를 보안/아키텍처 변경 시 cross-check으로 활용할 수 있으나 선택적(optional)

---

## Q4. 무인 모드 안전장치

| 위험 | 현재 안전장치 | 한계 |
|------|-------------|------|
| 무한 루프 | `max_iterations: 100` (ralph), `max_reinforcements: 50` (ultrawork) | 기본값 고정, 사용자 설정 UI 없음 |
| 스테일 상태 | 2시간 경과 시 자동 비활성화 | **10시간 빌드 불가** — 2시간마다 상태 리셋됨 |
| Context limit | Stop 훅에서 감지 후 통과 (컴팩션 허용) | 컴팩션 후 재시작 보장 없음 |
| User abort (Ctrl+C) | `isUserAbort()` 감지 후 블로킹 해제 | |
| 비용 폭주 | 없음 | max_cost, budget_cap 개념 없음 |
| 네트워크 장애 | 없음 | 외부 서비스 재시도 로직 없음 |
| Codex 장애 | `SKILL.md`: "If Codex unavailable, proceed with architect alone" | graceful degradation만 |

**max-hours 설정 기능 없음.** 시간 기반 종료 조건이 전혀 없다.

---

## Q5. 보고서 자동 생성

**현재 OMC에 자동 보고서 생성 기능은 없다.**

존재하는 것:
- `autopilot.md`: "display the autopilot summary" 문구만 있고, 저장 경로·형식 미정의
- `ultraqa.md`: cycle 진행 상황을 stdout 로그로 출력 (`[ULTRAQA Cycle N/5]`)
- `ultraqa-state.json`: 사이클 상태 저장, 완료 여부 포함
- `.omc/prd.json`의 `passes` 필드 업데이트 (ralph --prd 모드)

존재하지 않는 것:
- 작업 완료 시 Markdown/JSON 보고서를 파일로 자동 저장하는 로직
- 실행 시간, 에이전트 호출 횟수, 비용, 실패 이력 등 메타데이터 집계
- 공식적인 보고서 출력 경로 (`.omc/reports/` 등)

---

## 사용자 목적 대비 부족 영역 (5가지)

### 1. 스테일 임계값 2시간 — 10시간 빌드 불가
`STALE_STATE_THRESHOLD_MS = 2h`. 장시간 실행 시 상태가 만료되어 루프가 자동 종료된다. 하네스에서 이 값을 늘리거나(`12h` 이상), `last_checked_at`을 주기적으로 갱신하는 heartbeat 메커니즘을 별도로 구현해야 한다.

### 2. 사용자 acceptance criteria 주입 인터페이스 부재
사용자가 완료 조건을 구조화된 형식으로 입력할 공식 창구가 없다. `--prd` 플래그로 LLM이 criteria를 생성하지만, 사용자가 직접 정의한 검증 가능한 조건(예: "API 응답 200ms 이하", "커버리지 80% 이상")을 주입하는 인터페이스가 필요하다.

### 3. 보고서 자동 생성 누락
완료 후 실행 요약(소요 시간, 반복 횟수, 에이전트 비용 추정, 완료된 user story 목록, 실패 이력)을 파일로 저장하는 기능이 없다. 하네스에서 SessionEnd 훅 또는 cancel 스킬 완료 시점에 보고서를 생성하는 로직을 추가해야 한다.

### 4. 비용/시간 안전장치 없음
`max_cost`, `max_hours`, `budget_cap` 개념이 전혀 없다. 10시간 무인 실행 중 비용 폭주를 막을 방법이 없다. 하네스에서 시작 시간 기록 + 주기적 경과 시간 체크 + 임계값 초과 시 자동 종료 로직을 구현해야 한다.

### 5. architect 검증이 동일 LLM 계열 — 진정한 독립 검증 아님
ralph의 architect verification은 동일 Anthropic 모델의 다른 인스턴스다. 독립적인 외부 판단자(Codex cross-check)는 선택적이며, 기본 흐름에 강제되지 않는다. 하네스에서 완료 조건 충족을 주장하기 전에 Codex 검증을 필수 단계로 강제하는 레이어를 추가하는 것이 권장된다.

---

## 하네스 보강 권고 사항

| 영역 | 권고 |
|------|------|
| 장시간 실행 | Stop 훅 stale threshold를 `12h`로 설정하거나, heartbeat 워커로 `last_checked_at` 갱신 |
| Acceptance criteria | `harness-spec.json` 형식으로 사용자 정의 완료 조건을 받고, ralph 루프 내 검증 단계에 주입 |
| 보고서 | SessionEnd 또는 cancel 시점에 `.omc/reports/{timestamp}-summary.md` 자동 생성 |
| 비용 가드 | 시작 시 `max_hours` 파라미터 받고, persistent-mode.cjs 유사 훅으로 경과 시간 체크 |
| 독립 검증 | ralph 완료 직전 Codex cross-check을 필수 단계로 강제 (`/codex:review --wait`) |

