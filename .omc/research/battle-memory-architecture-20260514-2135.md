# Battle Transcript — Memory Architecture v0.3 Proposal
**Started**: 2026-05-14 21:35
**Topic**: 4-Tier 메모리 아키텍처가 최적인가? 어느 부분을 수정해야 하나?
**Domain**: architecture
**Engines**: OMC architect, OMC planner, OMC critic, Codex(architect), Gemini(analyst)
**gstack**: ⚠ skipped (not installed)
**Superpowers**: ⚠ skipped (architecture domain, /brainstorm 미적합)

---

## Phase 0 — Framing (analyst)

```markdown
# Battle Frame — Memory Architecture v0.3 Proposal

## Topic (one sentence)
orchestrator가 제안한 4-Tier 메모리 아키텍처(휘발성 `<remember>` → 프로젝트 `06.memory/` → 사용자 글로벌 `plugin/memory/user/` → SessionStart 미러링 + 자동 라우팅 + `/push-global-memory`)가 사용자 8대 요구사항을 충족하는 최적해인지, 더 나은 대안 또는 부분 수정이 필요한지 판단한다.

## Decision Criteria

### Success metrics (측정 가능)
- **M1. 머신 독립성**: 새 PC zero-state에서 git clone + 단일 설치 후 동일 메모리 컨텍스트 로드까지 수동 단계 수. (목표 ≤1, 실패 ≥3)
- **M2. 라우팅 정확도**: 모호 트리거 10 샘플 대비 올바른 tier 안착 비율. (목표 ≥8/10, 되묻기 1회 허용)
- **M3. CLAUDE.md 순수성**: 1개월 가상 운영 시 헌법 외 라인 추가 수. (목표 0, 실패 ≥3)
- **M4. OMC 분리도**: OMC plugin 완전 제거 시 메모리 시스템 boolean 동작 + 손상 LOC. (목표 동작 + ≤10 LOC)
- **M5. 글로벌 오염 저항**: 프로젝트 고유 결정이 글로벌 tier 3에 흘러들 확률 가드. (목표 의미분류+자동거부+사용자확인 3중)

### Constraints
- C1. CLAUDE.md 헌법만
- C2. 06.memory/ top-level
- C3. 글로벌 = 4축만(작업성향/하지말것/쾌적/골)
- C4. 명시 호출만(/push-global-memory)
- C5. OMC 의존 최소

### Risks
- R1. 미러링 절대경로 폭발 (멀티 머신/OS)
- R2. 자동 라우팅 오분류 → 글로벌 오염
- R3. SessionStart 훅 결합 — Claude Code 업데이트 취약
- R4. /push-global-memory 머지 충돌 (이중 remote)
- R5. 프로젝트 간 학습 전파 부재 (#3 핏 요구 미충족)
- R6. <remember> 태그 실효성 미검증

## Domain: architecture

## Roster
| Engine | Role |
|---|---|
| OMC architect (opus) | 4계층 경계·결합도 |
| OMC planner (opus) | 마이그레이션·시퀀싱 |
| OMC critic (opus) | sacred cow 공격 |
| Codex (architect) | NIH 검출·외부시각 |
| Gemini (analyst) | 1M ctx 횡단 정합성 |

## Anchors
- A1. 본 레포 = harness 그 자체 (.harness-main-only 마커, main 단독)
- A2. plugin/ → ~/.claude/plugins/nathaneast-aiacht/, templates/project-init/ → 새 프로젝트 (글로벌 전파 허브 인프라 이미 존재)
- A3. native auto-memory 경로 비어있음 → green-field 도입
- A4. .omc/notepad.md 미생성 → OMC notepad 미사용 실증
- A5. 글로벌 레포 이중화 (yunjadong-team 메인 + nathaneast 백업)
- A6. 글로벌 4축은 횡단 보편 가치만, 프로젝트 결정 진입 금지
- A7. git이 이미 sync 백본
- A8. 사용자 한마디 모호 트리거 명시 — 분류는 시스템 책임, 최대 1회 되묻기
```
# Phase 1 — Opening Statement

## 주제 (Topic)
orchestrator가 사용자에게 제안한 **4-Tier 메모리 아키텍처 v0.3**가 사용자의 8대 요구사항(아래)을 충족하는 최적해인가? 더 나은 대안 또는 부분 수정이 필요한가?

## 사용자 요구사항 (확정, 비협상)
1. CLAUDE.md는 핵심 룰(헌법)만 — 자잘한 작업 메모리 적재 금지
2. "저장해/기억해/참고해/이따 할거니 기억해" 한마디 모호 트리거 → Claude가 자동 분류·라우팅
3. 데이터가 누적되며 Claude를 사용자에게 핏하게 만들어야 함
4. 머신 무관 — 어느 PC에서도 동일 메모리 접근
5. /push-global-memory 명시 호출로 글로벌 전파 (자동 push X)
6. OMC 의존 최소화 — 추후 OMC 교체 가능성 대비
7. 글로벌(횡단) 메모리는 "작업성향/하지말것/쾌적한 작업/작업관점·골" 4축만
8. `06.memory/` top-level 폴더 (중첩 X)

## 검토 대상 설계 (v0.3)

```
Tier 1: 진짜 휘발성 (이 PC만)
  → Claude Code <remember> 태그 (7일 자동 만료, 내장)
  → OMC notepad 안 씀

Tier 2: 프로젝트 영속 (이 프로젝트 git)
  → <project>/06.memory/  (top-level)
      ├─ project.md   (결정·사실)
      ├─ feedback.md  (시도·실패 교훈)
      ├─ reference.md (외부 포인터)
      └─ MEMORY.md    (인덱스)
  → /cm 일상 흐름에 자동 포함

Tier 3: 사용자 글로벌 (본 하네스 git, 횡단)
  → 본 하네스/plugin/memory/user/
      ├─ user.md      (작업성향/쾌적/골)
      ├─ feedback.md  (하지말것/횡단 교훈)
      └─ INDEX.md
  → /push-global-memory 명시 호출만
```

**로딩**: SessionStart 훅이 Tier 2 + Tier 3 → `~/.claude/projects/<절대경로>/memory/`로 미러링 → Claude Code native auto-memory 자동 로드.

**라우팅**: 사용자 메모 발화 → Claude가 의미 분류 → 해당 tier 파일에 직접 쓰기. 불확실 시 1줄 되묻기.

**/push-global-memory 파이프라인**: pre-flight → fetch → pull --rebase --autostash → stage → commit → push → ls-remote 검증 → mirror.

## 결정 기준 (Phase 0 framing 산출)

### Success metrics (측정 가능)
- M1. 머신 독립성: 새 PC zero-state에서 git clone + 단일 설치 후 동일 메모리 컨텍스트 로드까지 수동 단계 (≤1 목표)
- M2. 라우팅 정확도: 모호 트리거 10 샘플 대비 올바른 tier 안착 ≥8/10
- M3. CLAUDE.md 순수성: 1개월 운영 시 헌법 외 추가 라인 = 0
- M4. OMC 분리도: OMC plugin 제거 시 메모리 시스템 동작 + 손상 ≤10 LOC
- M5. 글로벌 오염 저항: 의미분류+자동거부+사용자확인 3중 가드

### Risks (Phase 0 식별)
- R1. 미러링 절대경로 폭발 (멀티 머신/OS)
- R2. 자동 라우팅 오분류 → 글로벌 오염
- R3. SessionStart 훅 결합 — Claude Code 업데이트 취약
- R4. /push-global-memory 머지 충돌 (이중 remote)
- R5. 프로젝트 간 학습 전파 부재 (#3 핏 요구 미충족)
- R6. `<remember>` 태그 실효성 미검증

## Anchors (불변 사실)
- A1. 본 레포 = harness 그 자체, main 단독
- A2. plugin/ → ~/.claude/plugins/nathaneast-aiacht/, templates/project-init/ → 새 프로젝트 (글로벌 전파 허브 이미 존재)
- A3. native auto-memory 경로 비어있음 (green-field)
- A4. .omc/notepad.md 미생성 (OMC notepad 미사용 실증)
- A5. 글로벌 레포 이중화 (yunjadong-team 메인 + nathaneast 백업)
- A6. 글로벌 4축은 횡단 보편 가치만
- A7. git이 sync 백본
- A8. 사용자 한마디 모호 트리거 — 분류는 시스템 책임, 최대 1회 되묻기

## 너의 답변 형식 (필수, 4-section)

### 1) Position (1문장)
4-Tier 설계 v0.3에 대한 결론: 수락 / 부분 수정 / 거부 + 한 줄 이유.

### 2) Reasoning (3-5 bullet)
각 bullet마다 명확한 근거(파일·라인·anchor·외부 문서·데이터 또는 가정 명시) 부착.

### 3) Strongest counter-argument you anticipate
너의 입장의 가장 약한 지점을 *자진* 노출. 다른 엔진이 공격할 만한 곳.

### 4) What would change your mind
어떤 반증·증거가 나오면 입장을 바꾸겠는가?

## 너의 역할별 강조점

(역할별 강조점은 호출 시 individually 지정됨)

---

분량: 한국어, 600자 이내. 근거 없는 의견은 자동 배제됨. 추상적 표현("좋다/나쁘다") 금지, 구체적 트레이드오프와 측정 가능한 기준만.
# Phase 2 — Rebuttal

## 컨텍스트
Phase 1에서 5 엔진이 단독으로 입장을 냈다. 이제 다른 엔진들의 입장을 읽고 반박/방어/수정한다.

## Phase 1 전체 발언

---

### [A] OMC architect — 부분 수정 (Tier 1 폐기 + 3-Tier 축소)

**Position**: Tier 1(`<remember>`) 폐기, 미러링은 cron/명시 호출로 분리하여 SessionStart 결합도 제거.

**Reasoning**:
- Tier 1 책임 누락/중복: `<remember>` 7일 만료는 `.claude/CLAUDE.local.md`와 책임 충돌. A4(notepad 미사용 실증) 패턴 반복 위험.
- SessionStart 이중 결합(R3): session-start.sh:15 마커 체크 + :55 snapshot 주입. 여기에 미러링 추가 시 (a)훅 spec 변경, (b)git fetch 실패, (c)R1 경로 hash 충돌 3중 실패면이 세션 시작을 막음. 미러링은 별도 cron + /push-global-memory 산출 시점에만 트리거.
- M4 손상 LOC: v0.3 미러링 ~50 LOC + tier 라우팅 ~30 LOC가 plugin/에 박혀 ≤10 LOC 위반.
- 3-Tier 충분성: #7(글로벌 4축)·#8(top-level)·A2(plugin/+templates/ 허브) → ① `06.memory/` ② `plugin/memory/user/` ③ session 휘발(native auto) 매핑.

**Anticipated counter**: 7일 자동 만료 휘발은 실재 가치 — 임시 디버깅 메모를 영구 파일에 적재하면 M3 오염.

**Change mind**: 30일 운영 후 `<remember>` ≥10회 + 자동 만료 실측 도움 입증 시 Tier 1 유지.

---

### [B] OMC planner — 부분 수정 (파이프라인 3단계 축소 + 이중 remote 단방향)

**Position**: 골격 수락, /push-global-memory 7단계 → 3단계 트랜잭션 축소, 이중 remote는 yunjadong-team(ground truth) → nathaneast(미러) 단방향 강제.

**Reasoning**:
- M1 미달: PC A push(1) → PC B update.sh(2) → SessionStart 미러링(3, 자동). 사용자 수동 2단계 → M1 ≤1 위반. update.sh를 SessionStart에 옵션 통합하면 1단계.
- 롤백 절차: fetch~pull 실패→stash pop, commit→reset HEAD~1, push→재시도, 검증→revert.
- R4 이중 remote: mirror-personal.sh:20 `git push personal`은 `--force` 없으니 거부됨. 규약: yunjadong-team = ground truth, nathaneast = `--force-with-lease`.
- 슬래시 커맨드 인지 부담: README §3 13개 → 14번째 한계점. 대안: `/merge-skill`을 `/merge --type=skill|memory`로 확장.
- green-field 단순성: native 비어있음 = 마이그 0건. 단계 3: `06.memory/` 폴더 + SessionStart 훅 5줄 + `/push-global-memory`.

**Anticipated counter**: M1 ≤1 위반이지만 update.sh 자동화는 R3 결합 증가 — 트레이드오프 미해결.

**Change mind**: mirror 통합 후 충돌률 >5%면 단방향 폐기. update.sh 자동이 Claude Code 업데이트로 깨진 사례 1건이면 수동 2단계 수용.

---

### [C] OMC critic — **거부** (1-tier minimalist 재출발)

**Position**: 4-tier 자체 폐기. 1-tier minimalist 재출발 권고.

**Reasoning**:
- Tier 1 무의미(R6): `<remember>` 휘발성 미검증. native auto-memory에 영구 누적될 가능성 → Tier 2와 같은 storage → 분리 환상. 검증법: 빈 native에서 1회 사용 후 7일 후 디스크 확인.
- 미러링 anti-pattern: 두 출처 동기화 부담 + R1. 대안: SessionStart 훅이 `cat 06.memory/*.md`를 `<system-reminder>`로 inject → native 의존 0, M4 자동 충족. 미러링은 50+ LOC.
- 자동 라우팅 측정 데이터 0: "이거 내일 보고서에 쓸거야" → ?. M2 8/10은 가설. 검증법: 50샘플 사전 라벨링.
- 글로벌 4축 모호: "작업성향" vs "쾌적한 작업"은 같은 파일 동거 → 사실상 1축. 단일 user-global.md 1개로 압축 가능.
- 이중 remote 정당성: GitHub 99.95% SLA. 백업이면 `git remote add backup` + nightly cron 1줄. 8단계 파이프라인 과대.

**Anticipated counter**: 1-tier 축소 시 #3 누적 핏 약화. 단일 파일 grow 시 토큰 비용. #7 4축 무시는 사용자 의도 충돌.

**Change mind**: (a) `<remember>` 휘발성 실증. (b) 50샘플 라우팅 ≥9/10 실측. (c) "쾌적 vs 성향" 횡단 메모 5건 비겹침 입증.

---

### [D] Codex (architect) — 부분 수정 (현재 구현 갭 지적)

**Position**: Tier 분리는 타당, v0.3 원안은 요구 1·4·5·8을 동시에 못 맞춤.

**Reasoning**:
- `install.sh:41-54`, `plugin/claude/rules/memory.md:9-11`: 기본 저장이 CLAUDE.md 계열 → 요구1 충돌. **현재 메모리 룰 이미 존재**.
- `scripts/pjt-init.sh:32,52-63` + templates/project-init: `06.memory/` 미생성 → 요구8 미충족.
- `session-start.sh:15,54-56`: 현행은 파일 inject. v0.3 절대경로 mirror는 R1 경로폭발 위험.
- `rg` 기준 `/push-global-memory` 부재, `update.sh:19`는 pull-only → 요구5 미충족 (현 상태).
- `memory.md:3-11`은 키워드 분기만 → "참고해/이따 기억해" 자동분류 M2 근거 부족.

**Anticipated counter**: mirror 줄이고 inject 중심이면 native `/memory` 편집 UX 일관성 약화.

**Change mind**: 3 PC·3 OS에서 mirror 원안 `M1≤1`, `M2≥8/10`, 30일 충돌·오염 0건 실측이면 수락.

---

### [E] Gemini (analyst) — 부분 수정 후 수락 (R1/R3 대응만 강화)

**Position**: v0.3 설계는 8대 요구를 구조적으로 완벽 충족. `06.memory/` 격리와 글로벌 4축 제한이 명확.

**Reasoning**:
- [A7/M1/Req#8] Git 기반 Tier 2/3 물리 분리 = 머신 독립성 + CLAUDE.md 헌법 순수성 100% 보존.
- [Req#2/A8] Claude가 분류 주체, `<remember>` 우선 활용으로 R2 글로벌 오염 차단.
- [Req#6/M4] OMC notepad 배제 + SessionStart 미러링 = 도구 교체 시 마이그 비용 거의 0.
- [Req#7/A6] 글로벌 4축 제한 = 지식 파편화 방지 + R5 횡단 학습 밀도 극대화.

**Anticipated counter**: R1(절대경로 폭발) + R3(훅 결합)이 가장 취약. Claude Code 내부 프로젝트 ID 생성 로직 불투명 시 미러링 경로 불일치 → M1 실패 + 컨텍스트 단절.

**Change mind**: SessionStart 훅 실행 시점이 native memory 로딩 이후로 고정되어 미러 데이터가 당해 세션 미반영, 또는 Claude Code 공식 외부 메모리 주입 API 출시로 미러링 방식이 기술부채화.

---

## 너의 답변 형식 (필수)

다른 4 엔진의 입장을 모두 읽었다. 다음을 답하라:

### 1) 각 상대의 가장 약한 지점 (참가자별 1줄)
- A (architect): 
- B (planner): 
- C (critic): 
- D (Codex): 
- E (Gemini): 

(너 자신은 제외)

### 2) 나의 입장 방어
Phase 1에서 다른 엔진이 너에게 예상치 못한 공격을 했다면 어떻게 막을 것인가? 구체적 근거로.

### 3) 나의 입장 수정 (있다면)
다른 엔진의 주장이 일리 있다면 어디서 수정할 것인가? 수정 없다면 "수정 없음" + 이유.

### 4) 새로운 증거/근거 (Phase 1에서 빠뜨린 것)
1차에서 못 말한 것 1-2개. 새 anchor·새 측정 가능 기준·새 실패 시나리오.

한국어 700자 이내. 정치적 표현 금지. 근거(파일/라인/측정값) 부착 필수.
# Phase 3 — Stress Test (Adversarial)

## 너의 역할
너는 Phase 0~2 전체를 본 *외부 관찰자*다. 5 엔진이 합의 분위기에 빠져 놓친 것을 찾아라.

## Phase 0~2 요약

### Frame
- **주제**: 4-Tier 메모리 아키텍처 v0.3 적정성 판단.
- **사용자 요구사항(비협상)**: 8개 — CLAUDE.md 헌법 보존, 모호 트리거 자동 분류, 데이터 누적 핏, 머신 무관, 명시 push, OMC 분리, 글로벌 4축, 06.memory/ top-level.
- **Success metrics**: M1(머신 독립 ≤1 단계), M2(라우팅 ≥8/10), M3(CLAUDE.md 오염 0), M4(OMC 분리 ≤10 LOC 손상), M5(글로벌 오염 3중 가드).
- **Risks**: R1 절대경로 폭발, R2 라우팅 오분류, R3 SessionStart 결합, R4 머지 충돌, R5 횡단 학습 부재, R6 `<remember>` 미검증.

### Phase 1 입장
- A architect: 부분 수정 (Tier 1 폐기 + 3-Tier + 미러링 cron 분리)
- B planner: 부분 수정 (3단계 트랜잭션 + 단방향 미러)
- C critic: **거부** (1-tier minimalist)
- D Codex: 부분 수정 (현재 구현 갭 지적: memory.md:9-11 키워드 분기만, /push-global-memory 부재, 06.memory/ 미생성)
- E Gemini: 부분 수정 후 수락 (R1/R3 대응만 강화)

### Phase 2 이동
- A: **미러링 폐기** → "Git 저장 + SessionStart `cat 06.memory/*.md` inject"로 수정. critic 수용.
- B: 신규 LOC 35-45 측정 (mirror-personal.sh 21 + merge-skill.sh git ops 22 재사용). D 갭 발견 반영.
- C: **1축 + Inject 명시**. 라우팅 충돌 표 제시:

| 발화 | Claude 분류 후보 | 충돌 |
|---|---|---|
| "기억해놔" | 영구 글로벌 / 영구 프로젝트 | scope 모호 → 50% 오분류 |
| "참고해" | session-only / 영구 | TTL 모호 → 만료 후 손실 |
| "이따 기억해" | 휘발/영구 | "이따"=시점 vs 단기 → 100% 분기 충돌 |

명시 prefix(`#g/`, `#p/`) 제안.

- D: A/B 일부 수용 (미러링 SessionStart 분리, 3단계). 새 실패 시나리오: install.sh:5 upstream clone vs mirror-personal.sh:20 personal push 드리프트.
- E: D 지적 수용 (pjt-init.sh + memory.md 명세 전면 교체). C의 1-tier 거부 (4축 구조 파괴 + 토큰 낭비). 비동기 git fetch(`&`) 또는 1초 타임아웃 제안.

### 진짜 수렴 (4+/5)
1. 미러링 SessionStart 결합은 위험 → 분리 또는 폐기
2. 현재 구현 갭 명시 (memory.md, /push-global-memory, 06.memory/, pjt-init.sh)
3. /push-global-memory 3단계 트랜잭션
4. 자동 라우팅 정확도 측정 필요
5. 라우팅 충돌 risk 인정 (C의 표 무시 불가)

### 진짜 불일치
- **Axis 1**: Tier 1(`<remember>`) 유지(E, 가정) vs 폐기(A, C)
- **Axis 2**: 미러링(E) vs Inject(A, C) — D는 분리/cron
- **Axis 3**: 글로벌 4축 분할(E, B 암시) vs 단일 파일(C)
- **Axis 4**: 자동 라우팅(A,B,D,E) vs 명시 prefix(C)

## 너의 임무 (stress test, adversarial)

다음을 모두 발굴하라:

### 1) 숨은 가정 (hidden assumptions)
5 엔진이 "당연한 전제"로 깔고 토론한 것 — 한 발 떨어져 보면 무너지는 것. 예:
- "사용자가 일관된 작업 스타일을 갖는다"가 1년 후에도 사실?
- "글로벌 메모리가 한 번 쓰면 영구"라는 가정 — 무효화 메커니즘?

### 2) 2차 효과 (second-order consequences)
설계가 통한다고 가정할 때 6개월 후·1년 후 무슨 일이 벌어지는가?
- 글로벌 user.md가 500줄이 되면?
- 사용자가 PC 3대를 6개월 안 쓰다가 돌아오면?
- `06.memory/`가 프로젝트 git에 같이 push되면서 PR 리뷰어가 모든 메모를 보게 된다 (private 정보)
- 메모리가 너무 똑똑해져서 사용자가 시스템에 의존하게 되고, 휴대 가능성을 잃는다

### 3) 엣지 케이스
- 같은 프로젝트 worktree 여러 개 (psm 모드) → 06.memory/ 동시 쓰기 충돌?
- pull request로 다른 사람이 본 레포에 기여 → 그들의 메모리가 섞임?
- 회사 PC vs 개인 PC vs 노트북 동시 작업 → 어느 push가 이김?
- 메모리에 잘못된 정보 적재 (예: "supabase 쓴다" 했는데 사실 firebase) → 수정/롤백 메커니즘?

### 4) 측정 불가능한 트레이드오프
- "Claude가 똑똑해진다"는 측정 불가. 어떻게 검증하나?
- "느낌상 핏하다"는 사용자 만족도 — A/B 테스트?
- "토큰 비용 증가"는 측정 가능하지만 사용자가 신경 쓰는 임계점은?

### 5) "이 결정이 잘못이라면, 왜 잘못이 되는가" 시나리오 3개
구체적으로 묘사. 1년 후 회고록 형식.

### 6) 결정 기준 자체에 대한 의심
M1~M5가 정말 본 결정을 평가하는 옳은 기준인가? 측정 어려운 진짜 가치(예: "사용자가 메모리에 대해 *덜* 생각하게 됨")가 빠지지 않았나?

## 답변 형식

```markdown
## Stress Test Findings — <critic 이름>

### 숨은 가정 (Top 3)
1. ...
2. ...
3. ...

### 2차 효과
| 시점 | 시나리오 | 영향 |
|---|---|---|
| 6개월 | ... | ... |
| 1년 | ... | ... |
| 2년 | ... | ... |

### 엣지 케이스 (Top 5)
1. ...
...

### 측정 불가능 트레이드오프
- ...

### 실패 시나리오 (1년 후 회고록)
**Scenario 1**: ...
**Scenario 2**: ...
**Scenario 3**: ...

### 결정 기준 의심
- M1~M5 중 빠진 것 또는 잘못된 것:
- 새 기준 제안 (있다면):

### 종합 권고
설계를 **그대로 수락 / 부분 수정 / 거부**? 핵심 1문장.
```

한국어 1000자 이내. 다수 합의에 휩쓸리지 마라. 너는 마지막 방어선이다.
# Phase 4 — Synthesis

## 너의 임무 (analyst)
Phase 0~3 전체를 통합하여 다음을 산출하라:
1. **진짜 합의** (5/5 또는 4/5 일치)
2. **진짜 불일치** (왜 다른지 + 어느 게 맞는지)
3. **Phase 3 stress test 산출 신규 요구사항** 통합
4. **결정 매트릭스** (옵션 × 기준 점수 + 정성 코멘트)
5. **최종 권고안 1개** (단일 결정)

분류 기준에 휩쓸리지 말고 *측정 가능한 근거*만 인정.

## Phase 1 입장 (요약)
- A architect: Tier 1 폐기 + 3-Tier + 미러링 cron 분리 → Phase 2에서 **미러링 폐기 + inject 수용** (critic 안 흡수)
- B planner: 3단계 트랜잭션 + 단방향 미러 → Phase 2에서 신규 LOC 35-45 측정
- C critic: 1-tier minimalist → Phase 2에서 1축 user-global.md + inject + **라우팅 충돌 표 + 명시 prefix `#g/#p`**
- D Codex: 현재 구현 갭 (memory.md 키워드 분기, /push-global-memory 부재, 06.memory/ 미생성) → Phase 2에서 미러링 SessionStart 분리 + 3단계 수락
- E Gemini: 부분 수정 후 수락 (R1/R3 비동기 git fetch로 완화) → Phase 2에서 D 지적 수용

## Phase 3 stress test 신규 발견 (양 critic 합치)

### 숨은 가정
- 모호한 발화 자동 분류 안정성 미검증
- 메모는 사실이고 오래 유효 (정정/롤백 zero)
- Git이 보안·소유권·충돌까지 해결한다는 환상
- 단일 사용자/단일 두뇌 (모델 업그레이드 시 메모리 호환성)

### 2차 효과
- 6개월: global 500줄+ 토큰 낭비
- 1년: 3대 기기 silent overwrite 신뢰 하락
- 2년: 개인정보 PR 노출, 평판 리스크

### 엣지 케이스 (Top 5)
1. 다중 worktree race condition
2. 외부 PR 기여 시 메모 혼입
3. 회사/개인 PC 동시 push (last-writer-wins)
4. 오기억 정정 시 provenance/rollback 부재
5. SessionStart 부분 로드 실패로 상태 불일치

### 빠진 결정 기준 (M6~M9)
- M6 메모리 1건 삭제까지 평균 단계 ≤2 (수정 가능성)
- M7 private 키워드(NDA/고객명/금액) 적재 시 경고 hook (프라이버시)
- M8 모델 업그레이드 시 메모리 호환성 검증
- M9 cognitive offload (사용자 메모리에 *덜* 생각하게 됨)

### 신규 비협상 가드
1. 명시 prefix `#g/#p` 우선, 자동 라우팅은 fallback
2. TTL 메커니즘
3. 정정 로그
4. 비밀 스캔 hook
5. 충돌 해결 정책

## 결정 매트릭스 — 옵션 × 기준 (너가 채우라)

**옵션 후보** (Phase 2 이동 후):
- **Opt-A**: 4-Tier v0.3 원안 (E가 옹호하던 것)
- **Opt-B**: 3-Tier + Inject (architect 수정안, no mirroring)
- **Opt-C**: 1-Tier minimalist (critic 원안)
- **Opt-D**: Hybrid — 3-Tier + Inject + 명시 prefix 우선 + Phase 3 가드 5종

**기준** (M1~M9, +사용자 8 요구사항 충족도, +구현 비용 LOC, +cognitive cost):

각 옵션에 대해 다음 항목을 0~10점 + 1줄 코멘트:
- M1 머신 독립성
- M2 라우팅 정확도
- M3 CLAUDE.md 순수성
- M4 OMC 분리도
- M5 글로벌 오염 저항
- M6 수정 가능성
- M7 프라이버시
- M8 모델 호환성
- M9 cognitive offload
- 사용자 8 요구사항 충족 (단순 boolean × 8)
- 구현 LOC 추정
- 인지부담 (1=직관, 10=복잡)

## 답변 형식

```markdown
## Phase 4 — Synthesis

### 진짜 합의 (5/5 또는 4/5)
1. ...
2. ...
3. ...

### 진짜 불일치 (남은 axis)
| Axis | A | B | C | D | E | 평가 |
|---|---|---|---|---|---|---|
| ... | ... | ... | ... | ... | ... | 어느 게 맞나·왜 |

### Phase 3 가드 통합
- 비협상 신규 가드 5개를 Opt-D에 어떻게 매핑:
  1. ...

### 결정 매트릭스
| 기준 | Opt-A | Opt-B | Opt-C | Opt-D |
|---|---|---|---|---|
| M1 | 6 | 8 | 9 | 9 |
| ... | ... | ... | ... | ... |
| **TOTAL** | ... | ... | ... | ... |

### 최종 권고
**Opt-?** — 1문장 결론 + 주요 근거 3개.

### 진짜 의견 불일치 (소수의견 보존)
- ...
```

한국어 1200자 이내. 측정 가능한 근거만. 합의는 표면적 합의일 수 있으니 의심하라.
# Phase 5 — Decision (Pre-Verification)

## 권고안: Opt-D Hybrid 메모리 아키텍처

### 결정
**3-Tier + Inject + `#g/#p` 명시 prefix 우선 + Phase 3 비협상 가드 5종**

### 구조

```
Tier 1: 휘발 (이 PC만, 7일)
  → Claude Code <remember> 태그 (30일 운영 후 실측. 호출 <3회면 폐기 재검토)

Tier 2: 프로젝트 영속 (이 프로젝트 git)
  → <project>/06.memory/  (top-level, 사용자 Req#8)
      ├─ project.md     (결정·사실)
      ├─ feedback.md    (시도·실패 교훈)
      ├─ reference.md   (외부 포인터)
      ├─ CHANGELOG.md   (정정 로그, append-only, provenance)
      └─ MEMORY.md      (인덱스)
  
  → SessionStart 훅이 cat → <system-reminder>로 inject
    (NO 미러링 to ~/.claude/projects/<abs>/memory/ — R1 회피)
  → /cm 일상 흐름에 자연 포함

Tier 3: 사용자 글로벌 (본 하네스 git, 횡단)
  → 본 하네스/plugin/memory/user/
      ├─ user.md          (작업성향 — 무엇을 어떻게)
      ├─ comfort.md       (쾌적한 작업 — 작업 흐름·페이스)
      ├─ goals.md         (작업관점·골 — 무엇을 향해)
      ├─ dont.md          (하지말것·금기)
      └─ INDEX.md
  → /push-global-memory 명시 호출만 (3단계: stage+commit+dual push)
  → SessionStart inject (Tier 2와 동일 메커니즘)
```

### 라우팅 (사용자 Req#2)

**계층 1 (명시 prefix, 우선)**:
- `#g/<내용>` → Tier 3 (글로벌)
- `#p/<내용>` → Tier 2 (프로젝트)
- `#t/<내용>` → Tier 1 (휘발, `<remember>` 태그)

**계층 2 (자동 분류, fallback)**:
prefix 없으면 Claude가 의미 분류:
- "이따 할거니 기억해" / "내일" → Tier 1
- "재훈씨가 X 요청" / "이 모듈은 W 결정" → Tier 2 (project.md)
- "나는 X 선호" / "항상 Y" → Tier 3 (user.md)
- "Z 하지마라" → Tier 3 (dont.md)

**계층 3 (불확실 → 되묻기)**:
"글로벌(모든 프로젝트)인가 이 프로젝트만인가?" 1줄.

### Phase 3 비협상 가드 (5종)

| 가드 | 구현 위치 | 효과 |
|---|---|---|
| G1. 명시 prefix `#g/#p/#t` | `plugin/claude/rules/memory.md` 최상위 룰 | M2 라우팅 ≥9/10 |
| G2. TTL (`expires:` frontmatter) | `06.memory/*.md` + `plugin/memory/user/*.md` + 월 1회 prune | M9 stale 방지 |
| G3. CHANGELOG 정정 로그 | `06.memory/CHANGELOG.md` + `plugin/memory/user/CHANGELOG.md` append-only | M6 rollback ≤2 단계 |
| G4. 비밀 스캔 hook | `plugin/claude/hooks/memory-write-guard.sh` (PreToolUse Write) — NDA·고객명·금액·token 정규식 차단 | M7 누출 0건 |
| G5. 충돌 해결 정책 | `/push-global-memory` 파이프라인 — yunjadong-team = ground truth, nathaneast = `--force-with-lease`, 충돌 시 사용자 확인 | M5/R4 |

### /push-global-memory 파이프라인 (3단계 트랜잭션)

```
1. STAGE   : cd ~/.claude/plugins/nathaneast-aiacht 
             → pre-flight (memory/ 외 변경 abort) 
             → git fetch + pull --rebase --autostash
             → git add plugin/memory/user/
2. COMMIT  : git commit -m "memory: <auto summary>"
3. PUSH    : git push origin main (yunjadong-team, ground truth)
             → git push nathaneast main --force-with-lease (미러)
             → ls-remote 검증
             → 충돌 시 revert + 사용자 확인
```

### 다른 PC sync

기존 `scripts/update.sh` 그대로 사용 (`git pull --ff-only`). 다음 세션 SessionStart 훅이 자동 inject.

### 구현 변경 (9 파일)

| 파일 | 변경 |
|---|---|
| `templates/project-init/06.memory/` | 신규 5 파일 (project/feedback/reference/CHANGELOG/MEMORY.md) |
| `scripts/pjt-init.sh` | `06.memory/` 폴더 생성 추가 |
| `plugin/memory/user/` | 신규 5 파일 (user/comfort/goals/dont/INDEX.md + CHANGELOG.md) |
| `plugin/claude/rules/memory.md` | 전면 재작성 — prefix 룰 + 자동 분류 fallback + 가드 명세 |
| `plugin/claude/hooks/session-start.sh` | Tier 2+3 inject 로직 추가 (~10 LOC) |
| `plugin/claude/hooks/memory-write-guard.sh` | 신규 (~30 LOC, 정규식 차단) |
| `plugin/claude/commands/push-global-memory.md` | 신규 |
| `scripts/push-global-memory.sh` | 신규 (~35 LOC, mirror-personal.sh + merge-skill.sh 패턴 재사용) |
| `README.md` §6 | 4-계층 + Phase 3 가드 명시 / §3 표 13→14 |
| 글로벌 `~/.claude/CLAUDE.md` | memory.md 링크 추가 (1줄) |

### 운영 후 30일 재검토 트리거

- `<remember>` 호출 <3회 → Tier 1 폐기
- 자동 라우팅 정확도 <8/10 → prefix 강제
- `comfort.md` vs `user.md` 횡단 메모 5건 비겹침 안 보이면 → 1축 압축 (C 소수의견)
---
provider: "codex"
agent_role: "architect"
model: "gpt-5.3-codex"
prompt_id: "a97eb477"
timestamp: "2026-05-14T12:42:46.808Z"
---

목표는 v0.3 메모리 설계가 8개 비협상 요구를 충족하는지 판정하는 것입니다. 먼저 근거 고정을 위해 제시된 파일들의 정확한 라인과 현재 훅/동기화 동작을 확인한 뒤, 요구사항별 적합도와 수정안을 600자 이내 4섹션으로 압축해 제시하겠습니다.
현재 근거는 충분하지만, 요구사항 8번(`06.memory/`)과의 충돌 가능성을 확인하려고 템플릿/초기화 스크립트에서 실제 생성 구조를 추가 점검하겠습니다. 이 결과로 “부분 수정” 범위를 정량화하겠습니다.
초기화 스크립트에서 `06.memory` 미생성·기존 메모리 경로(`CLAUDE.md`, `.claude/CLAUDE.local.md`)를 확인했습니다. 이제 설치 스크립트의 글로벌 메모리 append 규칙까지 확인해, v0.3가 요구사항 1·4·5·8을 동시에 만족하는지 판정하겠습니다.
메모리 룰 파일까지 확인했고, 현재 설계와 요구사항 간 갭의 핵심은 `CLAUDE.md` 오염 가능성·글로벌 push 통제·`06.memory` 부재입니다. 마지막으로 `/push-global-memory`의 실제 구현 유무를 확인해 위험도를 확정하겠습니다.
`/push-global-memory`가 아직 없기 때문에, 현재 존재하는 글로벌 반영 스크립트(`/merge-skill`, `/mirror-personal`)의 충돌 처리 패턴을 확인해 v0.3 파이프라인의 실현 가능성과 취약점(R4)을 근거화하겠습니다.
### 1) Position
부분 수정. Tier 분리는 타당하지만, v0.3 원안은 요구 1·4·5·8을 동시에 못 맞춥니다.

### 2) Reasoning
- `install.sh:41-54`, `plugin/claude/rules/memory.md:9-11`: 기본 저장이 `CLAUDE.md` 계열이라 요구1 충돌.
- `scripts/pjt-init.sh:32,52-63` + `templates/project-init`: `06.memory/` 미생성으로 요구8 미충족.
- `plugin/claude/hooks/session-start.sh:15,54-56`: 현행은 파일 inject. v0.3의 절대경로 mirror(`~/.claude/projects/<abs>`)는 A3·R1 경로폭발 위험.
- `rg` 기준 `/push-global-memory` 부재, `scripts/update.sh:19`는 pull-only라 요구5 미충족.
- `memory.md:3-11`은 키워드 분기만 있어 “참고해/이따 기억해” 자동분류(M2) 근거 부족.

### 3) Strongest counter-argument you anticipate
mirror를 줄이고 inject 중심으로 가면 native `/memory` 편집 UX 일관성이 약해질 수 있습니다.

### 4) What would change your mind
3대 PC·3 OS에서 원안 mirror로 `M1≤1`, `M2≥8/10`, 30일 충돌·글로벌 오염 0건 실측이 나오면 원안 수락으로 변경합니다.---
provider: "gemini"
agent_role: "analyst"
model: "gemini-3-flash-preview"
prompt_id: "556e86d1"
used_fallback: true
fallback_model: "gemini-3-flash-preview"
timestamp: "2026-05-14T12:47:50.055Z"
---

MCP issues detected. Run /mcp list for status.### 1) Position
**부분 수정 후 수락 (R1/R3 대응 로직 강화 필수).** v0.3 설계는 8대 요구사항을 구조적으로 완벽히 충족하며, 특히 `06.memory/` 격리와 글로벌 4축 제한이 아키텍처적 명확성을 제공함.

### 2) Reasoning
- **[A7/M1/Req#8]** Git 기반의 Tier 2/3 물리 분리는 머신 독립성을 보장하며, `06.memory/` 사용으로 `CLAUDE.md`의 헌법적 순수성(Req#1)을 100% 보존함.
- **[Req#2/A8]** Claude가 분류 주체가 되어 `<remember>` 태그(Tier 1)를 우선 활용함으로써 모호한 트리거에 의한 글로벌 메모리 오염(R2)을 원천 차단함.
- **[Req#6/M4]** OMC notepad를 배제하고 `SessionStart` 기반 native memory 미러링을 채택하여 향후 도구 교체 시에도 데이터 마이그레이션 비용(M4)이 거의 없음.
- **[Req#7/A6]** 글로벌 4축(성향/금지/쾌적/목표) 제한은 지식 파편화를 막고 프로젝트 횡단 학습(R5)의 밀도를 극대화함.

### 3) Strongest counter-argument
가장 취약한 지점은 **R1(절대경로 폭발)과 R3(훅 결합도)**임. Claude Code의 내부 프로젝트 ID 생성 로직(절대경로 해시 등)이 불투명할 경우, 하네스가 예측한 미러링 경로와 실제 로드 경로가 불일치하여 메모리 회수(M1)에 실패하고 컨텍스트 단절이 발생할 위험이 큼.

### 4) What would change my mind
`SessionStart` 훅의 실행 시점이 native memory 로딩 이후로 고정되어 미러링 데이터가 당해 세션에 즉시 반영되지 않거나, Claude Code가 공식적으로 외부 메모리 폴더 주입 API를 제공하여 현재의 미러링 방식이 유지보수 불가능한 기술 부채로 전락할 경우.---
provider: "codex"
agent_role: "architect"
model: "gpt-5.3-codex"
prompt_id: "0ef53184"
timestamp: "2026-05-14T12:53:01.124Z"
---

목표 결과는 Phase 2 반박문을 700자 이내로 완성하는 것이고, 제약은 지정 형식·근거 첨부·파일라인 명시입니다. 먼저 `CLAUDE.md`와 현재 스크립트 라인 번호를 확인해 인용 근거를 고정한 뒤, 참가자별 약점/방어/수정/신규증거를 압축해 작성하겠습니다.
현재 근거 고정 상태: 기본 메모리 라우팅은 `CLAUDE.md` 계열이고(`memory.md:9-11`, `install.sh:49-53`), SessionStart는 이미 마커+스냅샷 결합입니다(`session-start.sh:15,55-56`). 이제 반박문을 700자 내로 압축하면서 각 엔진 약점과 수정안을 수치 기준으로 정리하겠습니다.
근거 라인과 수치(검색 0건, 템플릿 항목 수)를 확정했습니다. 이제 형식 고정(1~4)으로 700자 이내 반박문을 바로 제출합니다.
### 1) 각 상대의 가장 약한 지점
- A (architect): 폐기 근거가 가정치 중심이고 임시메모 대체/정리 규칙이 비어 있음(`memory.md:31`).
- B (planner): SessionStart+`update.sh` 결합은 네트워크 실패를 startup 실패로 전파(`session-start.sh:15-16`, `update.sh:19`).
- C (critic): 1-tier는 요구#7/#8 위반, `06.memory` 경로 자체가 빠짐(`pjt-init.sh:32`).
- D (Codex): 자기 자신 제외.
- E (Gemini): “완벽 충족”은 반증됨: `push-global-memory` 검색 0건, 템플릿 `06.memory` 0건(`rg`, `ls templates/project-init`).

### 2) 나의 입장 방어
내 입장은 “설계 선호보다 구현 갭 폐쇄 우선”이다. 기본 저장은 아직 CLAUDE 계열(`memory.md:9-11`, `install.sh:49-53`), 동기화는 pull-only(`update.sh:19`)라 요구1/5/8 동시 충족 주장은 현재 코드 기준 성립하지 않는다.

### 3) 나의 입장 수정
A/B 일부 수용: 미러링은 SessionStart에서 분리(수동/cron), `/push-global-memory`는 3단계(fetch→commit→push)로 축소. 수용 기준: 30일 `M1<=1`, 충돌률 `<5%`.

### 4) 새로운 증거/근거
새 실패 시나리오: 원격 드리프트(`install.sh:5` upstream clone vs `mirror-personal.sh:20` personal push). 새 지표: 두 remote `HEAD` 불일치율 `<1%/월`.---
provider: "gemini"
agent_role: "analyst"
model: "gemini-3-flash-preview"
prompt_id: "41600b0c"
used_fallback: true
fallback_model: "gemini-3-flash-preview"
timestamp: "2026-05-14T12:57:58.124Z"
---

MCP issues detected. Run /mcp list for status.### 1) 각 상대의 가장 약한 지점
- **A (Architect)**: Tier 1 폐기 시 임시 디버깅 메모가 영구 파일에 적재되어 M3(오염 방지) 비용과 정리 부채 급증.
- **B (Planner)**: 단방향 미러 강제는 R4(데이터 주권) 위반—오프라인 작업 후 상호 push 시의 유연성 상실.
- **C (Critic)**: 1-tier(단순 inject)는 Req#7(글로벌 4축) 구조를 파괴하며 매 턴 시스템 프롬프트 토큰을 낭비함.
- **D (Codex)**: 현 구현 갭 지적은 타당하나, '30일 무사고 실측' 조건은 MVP 도입을 막는 지나친 검증 지연.

### 2) 나의 입장 방어
C의 '1-tier inject'는 `/memory` 네이티브 편집 UX를 포기하는 퇴보임. v0.3은 `plugin/memory/user/` 미러링을 통해 **(1) 네이티브 커맨드 호환성**과 **(2) 머신 간 Git 동기화**를 동시 확보함. R3 결합도는 훅 내 `git fetch`를 비동기(`&`) 또는 타임아웃 1초 제한으로 설정해 세션 시작 지연을 차단 가능.

### 3) 나의 입장 수정
D의 지적을 수용하여 설계를 구체화함. `scripts/pjt-init.sh`에 `06.memory/` 폴더 및 기본 가이드 생성 로직을 추가하고, `plugin/claude/rules/memory.md`의 기존 3분기 로직을 v0.3의 3-Tier(Native/Project/Global) 명세로 전면 교체.

### 4) 새로운 증거/근거
- **Context Swap Latency**: 외부 문서(노션 등) 조회(~15초) 대비 CLI 내 미러링 조회(<1초). 작업 몰입도 유지의 핵심 지표.
- **Scale-out 시나리오**: 프로젝트 50개 돌파 시 단일 글로벌 파일은 검색 효율이 급감함. Req#7(4축) 기반 파일 분할만이 장기적 지식 파편화의 유일한 해법.---
provider: "codex"
agent_role: "critic"
model: "gpt-5.3-codex"
prompt_id: "9caca2ba"
timestamp: "2026-05-14T13:02:07.547Z"
---

## Stress Test Findings — Red Team

### 숨은 가정 (Top 3)
1. 모호한 발화도 자동 분류가 안정적이다.  
2. 메모는 대체로 사실이고 오래 유효하다.  
3. Git 동기화가 보안·소유권·충돌까지 해결한다.

### 2차 효과
| 시점 | 시나리오 | 영향 |
|---|---|---|
| 6개월 | global 메모 500줄+ 주입 | 토큰/지연 증가, 핵심 맥락 희석 |
| 1년 | 3대 기기 오프라인 후 재접속 | silent overwrite, 신뢰 하락 |
| 2년 | `06.memory/` 히스토리 누적 | 개인정보 노출, PR 마찰 |

### 엣지 케이스 (Top 5)
1. 다중 worktree 동시 쓰기 race.  
2. 외부 PR 기여 시 메모 혼입.  
3. 회사/개인 PC 동시 push(`last-writer-wins`).  
4. 오기억 정정 시 provenance/rollback 부재.  
5. SessionStart 부분 로드 실패로 상태 불일치.

### 측정 불가능 트레이드오프
- 생산성 상승 vs 기억근육·휴대성 저하.  
- “핏” 체감 상승 vs 통제가능성 하락.

### 실패 시나리오 (1년 후 회고록)
**Scenario 1**: “기억해놔” 오분류로 글로벌 유출, 팀이 메모 사용을 회피.  
**Scenario 2**: 동기화 충돌 누적으로 최신 규칙이 소실.  
**Scenario 3**: 메모 관리 작업이 개발 시간을 잠식.

### 결정 기준 의심
- M1~M5 중 빠진 것 또는 잘못된 것: 신뢰, 정정성, 운영비용 지표가 없음.  
- 새 기준 제안 (있다면): 오분류율, 정정 리드타임, 비밀유출 0건, 메모관리 시간/주, 충돌복구율.

### 종합 권고
설계를 **부분 수정**: 자동 라우팅은 유지하되 `#g/#p` 명시 우선, TTL·정정로그·비밀스캔·충돌해결 정책을 선행하라.