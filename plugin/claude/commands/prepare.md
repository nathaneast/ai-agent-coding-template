---
description: 자연어 목표를 인터뷰로 디테일까지 뽑아내 spec을 잠그고 /solo까지 인입
allowed-tools: Bash, Read, Write, Edit
---

# /prepare — Interactive Spec Lock → /solo Handoff

`/prepare`는 **저장기**가 아니라 **인터뷰어**다. 사용자 입력을 바로 spec으로 굳히지 말고,
**요구사항·완료조건·테스트 방법론** 세 축을 끝까지 캐묻는다. 모든 칸이 검증 가능한 형태로 합의된 뒤에만 잠근다.
잠근 즉시 `/solo`로 자동 인입한다.

---

## 운영 원칙 (절대 어기지 말 것)

1. **질문 없이 저장 금지.** 사용자가 한 줄만 던졌다고 그 한 줄을 spec으로 쓰지 말 것.
2. **티키타카 의무.** 한 번에 묻는 질문은 3~5개로 묶고, 답변이 모호하면 같은 칸을 다시 파고든다.
3. **세 축 빈칸 금지.**
   - **요구사항 축**: `goal` / `in_scope` / `out_of_scope` / `human_decisions`
   - **완료조건 축**: `acceptance_criteria` (각 항목에 `mode` + 정·부·엣지 시나리오 커버)
   - **테스트 방법론 축**: `verify_commands` (자동/수동 구분, 검증 레벨, 데이터 전략)
   모두 구체값으로 채울 때까지 인터뷰 종료 금지.
4. **수용 기준은 검증 가능해야 한다.** "잘 동작한다" 같은 표현은 거절. 측정 가능한 명령/관측치로 환산.
5. **각 acceptance_criterion은 `mode` 필수** — `auto`(자동검증, verify_commands 필수) / `manual`(사용자 ack 필요) / `hybrid`(둘 다). 누락 시 lock 거부.
6. **약한 검증 명령 금지** — `--help`, `--version`, `py_compile`, `test -x <file>`, `echo`, `true`, 40자 미만 `python -c "..."`, `... || true`/`... || :`/`... ; true` 같은 exit-code 마스킹은 lock 차단. 산출물·상태·응답 검사로 대체.
7. **시나리오 커버리지 필수** — 주요 in_scope 항목 1개당 최소 **정상 1 + 비정상/엣지 1**의 acceptance_criterion. 한쪽만 있으면 부족하다고 보고 추가 질문.
8. **사용자가 "이대로 가" 라고 명시할 때까지 잠그지 않는다.** "spec 잠글까요?" 확인을 받은 후에만 lock.
9. **lock 직후 즉시 `/solo` 인입.** 사용자가 별도 명령을 다시 치게 하지 말 것.

---

## 실행 절차

### 0. PLUGIN_LIB 결정
- 현재 repo에 `plugin/claude/hooks/lib/`가 있으면 그 절대경로
- 아니면 `$HOME/.claude/plugins/nathaneast-aiacht/plugin/claude/hooks/lib`

### 1. 초안 생성
```bash
bash "$PLUGIN_LIB/solo-spec.sh" prepare "$ARGUMENTS"
```

### 2. 초안 읽고 3축 갭 분석
`01.spec/harness-spec.json`을 읽는다. 다음 매트릭스로 채점:

| 축 | 칸 | PASS 기준 |
|---|---|---|
| 요구사항 | `goal` | "누가, 무엇을, 왜"가 한 줄로 명확 |
| 요구사항 | `in_scope` | 변경할 파일/엔드포인트/페이지가 구체적으로 나열됨 |
| 요구사항 | `out_of_scope` | 이번에 안 건드릴 인접 영역이 명시됨 |
| 요구사항 | `human_decisions` | 사용자만 결정할 수 있는 모든 트레이드오프 기록 |
| 완료조건 | `acceptance_criteria` | 각 항목: `mode` 명시 + 측정 가능한 관측 + 정/부/엣지 커버 |
| 테스트 | `verify_commands` (auto/hybrid) | 산출물·상태·응답을 실제로 검사하는 명령 (약한 검증 0건) |
| 배포 | `deploy` | 환경/명령/롤백 모두 채워짐. 파괴적 동작이면 롤백 전략 명시 |

칸 하나라도 PASS 미달이면 **인터뷰 루프 진입**.

### 3. 인터뷰 루프 (이 단계가 핵심)

루프 1회당 다음을 수행:

#### 3-1. 질문 배치 작성
- 우선순위: **요구사항 → 완료조건 → 테스트 방법론 → deploy → human_decisions**
- 한 배치에 **3~5개 질문**. 너무 많으면 사용자가 지친다.
- 각 질문은 다음 형태 중 하나:
  - **선택지형**: "A/B/C 중 어느 쪽? 이유는?"
  - **수치형**: "응답시간 목표 몇 ms? p95 기준?"
  - **경계형**: "X도 포함? Y는 제외?"
  - **엣지형**: "데이터가 0건일 때 동작은? 중복 입력은? 권한 없는 사용자는? 네트워크 끊기면?"
  - **검증형**: "이게 됐다고 어떻게 증명? 어떤 명령/스크린샷/로그?"
  - **방법론형**: "단위 테스트 / 통합 / e2e 중 어디서 검증? 실데이터 vs 픽스처?"

#### 3-2. 출력 포맷
사용자에게 다음 형태로 출력:

```
[현재 spec 상태 — 3축 채점]
요구사항 축
  - goal: <현재값 or EMPTY/VAGUE>
  - in_scope: <...>
  - out_of_scope: <...>
  - human_decisions: <...>
완료조건 축
  - acceptance_criteria: <개수, mode 분포, 정/부/엣지 커버>
테스트 축
  - verify_commands: <개수, 약한 검증 N건, 산출물 검사 N건>
deploy
  - target/command/rollback: <...>

[궁금한 것 — 한 번에 답해주세요]
Q1. ...
Q2. ...
Q3. ...
Q4. (선택) ...
Q5. (선택) ...
```

#### 3-3. 답변 반영
- 사용자 답변을 받으면 `01.spec/harness-spec.json`을 직접 Edit으로 갱신.
- 답변이 또 모호하면 같은 칸을 더 좁혀 재질문 (예: "정확히 어느 페이지?", "에러 메시지는 어디에?").
- 사용자가 "몰라" / "정해줘" 라고 하면, 합리적 디폴트를 **명시적으로 제안**하고 동의를 받는다.
- acceptance_criterion 추가 시 가능하면 **Given / When / Then** 분해를 description에 포함.

#### 3-4. 종료 조건
다음 두 조건이 모두 충족될 때만 루프 종료:
- (a) 3축 채점 매트릭스 모든 칸 PASS
- (b) 사용자가 명시적으로 "이대로 가" / "ok" / "잠가" / "go" / "/solo로 가" 중 하나를 답함

조건이 안 차면 3-1로 돌아가 다음 배치 질문.

### 4. 최종 확인 (잠금 직전)
잠금 직전에 한 번만 다음을 출력:
```
[최종 spec]
<전체 spec JSON pretty-print>

[자체 검증]
- 요구사항 축 PASS: ✅/❌
- 완료조건 축 PASS (mode, 정/부/엣지): ✅/❌
- 테스트 축 PASS (약한 검증 0건): ✅/❌

이대로 잠그고 /solo로 바로 들어갈까요? (yes / 수정사항)
```
사용자가 yes/네/ok 류로 답해야 다음 단계.

### 5. 잠금
```bash
bash "$PLUGIN_LIB/solo-spec.sh" lock
```
`solo-spec.sh`의 게이트가 약한 검증과 mode 누락을 한 번 더 검사한다. 실패 시 어떤 칸이 문제인지 사용자에게 알리고 3-1로 복귀.

### 6. /solo 자동 인입 (사용자가 다시 명령 치게 하지 말 것)

잠금 성공 직후, **별도 명령 없이** 다음을 즉시 실행:

```bash
bash "$PLUGIN_LIB/solo-run.sh" start
```

그리고 `/solo`의 실행 절차(commands/solo.md 참조)를 그대로 이어서 수행:
1. `01.spec/harness-spec.json`과 `.harness/runs/{run_id}/PLAN.md`를 읽고 구현 계획을 짧게 세운다.
2. IMPLEMENT 단계 전환 → 구현 → `solo-verify.sh` → 실패 시 수정 반복(최대 3회) → Codex 리뷰(가능한 경우) → finish done.

사용자에게는 인입 시점에 다음 한 줄만 알린다:
```text
spec locked. entering /solo now — run_id: <run_id>
```

---

## 인터뷰 질문 카탈로그

### 축 1: 요구사항 (Requirements)

**goal 캐묻기**
- 누가 쓰는가? (사용자 페르소나, 1인 vs 다수)
- 이 기능이 없으면 지금 어떻게 처리되나? (현재 방식의 고통점)
- 이번 라운드에서 "성공"의 한 줄 정의는?
- 빈도와 규모: 하루 몇 회? 처리할 데이터 크기?
- 비기능 요구: 응답시간 / 신뢰성 / 보안 / 권한 / 감사 로그?

**in_scope / out_of_scope 캐묻기**
- 어떤 페이지/엔드포인트/스크립트/파일이 바뀌나?
- 어떤 외부 시스템(시트, DB, API)과 상호작용?
- 인접한 X도 같이 손대야 하나 아니면 다음으로 미루나?
- 리팩터링은 포함인가 분리인가?
- 데이터 마이그레이션 / 시드 / 기존 데이터 호환은?

**human_decisions 캐묻기**
- 사용자만 결정할 수 있는 트레이드오프 (예: 자동 백업 vs 사용자 수동 백업)?
- 외부 의존(API 키, OAuth 시크릿, 디자인 시안 등) 막혀 있는 부분?
- 위반 시 사용자가 직접 보고 결정해야 할 룰?
- 보안 결정 (어디에 보관, 누구에게 권한)?

### 축 2: 완료조건 (Acceptance Criteria)

각 acceptance_criterion 작성 시:

**mode 결정**
- `auto`: 자동 명령 1개 이상으로 통과 증명 가능
- `manual`: 사용자가 눈/손으로 확인 (OTP, 시각, 외부 인터랙션)
- `hybrid`: 자동 검증 + 사용자 ack 둘 다 필요

**시나리오 매트릭스 (in_scope 항목별 최소 3개 권장)**
- **정상 경로**: 기대 입력 → 기대 출력
- **비정상 경로**: 잘못된 입력 / 부족한 권한 / 외부 실패 → 안전한 거절
- **엣지**: 0건, 중복, 동시 요청, 네트워크 단절, 시간 경계, 데이터 최대치
- **회귀 금지**: 이 기능 추가로 이전에 통과하던 X가 깨지지 않는지

**Given / When / Then 권장**
```
Given: 시트 '센터제고' A3 이하에 100행 존재, ~/Desktop에 daiso_center_stock_2026-05-18.xlsx 존재
When:  python3 erp_upload.py --target=center 실행
Then:  (1) 센터제고!A3:ZZ가 비워졌다가 엑셀 B3 이후 데이터로 채워짐
       (2) 종료코드 0
       (3) 콘솔에 "센터제고 N행 업로드 완료" 출력
```

### 축 3: 테스트 방법론 (Verify Strategy)

**auto/hybrid criterion 전용 — verify_commands 캐묻기**
- **검증 레벨**: 단위 / 통합 / e2e / 산출물 검사 / 외부 응답 검사 중 어디?
- **데이터 전략**: 실데이터 vs 픽스처 vs 합성. 픽스처면 어디 보관?
- **무엇을 assert?**: 종료코드만? 산출 파일 내용? 외부 시스템 상태? 응답 JSON 필드?
- **약한 검증 금지**: `--help`·`--version`·`py_compile`·`test -x <file>` / 끝에 `|| true`·`|| :`·`; true` 마스킹은 lock 차단됨.
- **산출물 기반 검증 권장 예시**:
  - `test -s <output_file>` — 파일 생성 + 비어있지 않음
  - `grep -q "expected" <log>` — 로그에 기대 문구
  - `curl ... | jq -e '.status == "ok"'` — HTTP 응답 + JSON 필드
  - `wc -l <file>` 결과 임계치 비교
  - `git check-ignore -v <file>` — gitignore 적용 확인 (마스킹 없이)
- **임계치**: 커버리지 / 응답시간 / 에러율 등 숫자 기준?
- **타임아웃**: 명령 1회 실행이 5분(`SOLO_VERIFY_TIMEOUT_DEFAULT`)을 넘으면 fail.
- **manual mode**: 사용자가 직접 확인할 항목은 description에 "사용자 확인:" 으로 표기.

### 축 4: 배포 (Deploy)

- 대상 환경 (local / dev / stage / prod 중)
- 실행 명령
- 환경변수 변경 필요한가? `.env*` 추가/수정?
- 마이그레이션/시드 필요한가?
- **파괴적 동작(clear/delete/truncate/drop) 포함 시 롤백 전략 필수**:
  - 자동 백업 (스냅샷 탭, dump 파일)
  - 또는 staging 영역에 먼저 쓰고 swap
  - 수동 롤백만 가능하면 그 사실을 deploy.rollback에 명시 + human_decisions에 사용자 사전 백업 확인 항목 추가

---

## 입력

$ARGUMENTS
