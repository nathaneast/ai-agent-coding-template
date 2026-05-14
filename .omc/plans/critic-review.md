# Critic Review — Harness Template MVP Plan

> **문서 역할**: ralplan 합의 사이클 2단계. Planner 초안(`harness-template-mvp-plan.md`)을 완전성·리스크·가정 취약성 관점에서 도전.
> **검토자**: Critic | **검토일**: 2026-05-13
> **결론 한 줄**: **Conditional Reject** — 폴더/표면 메커니즘은 견고. 그러나 "사용할수록 영리해진다" / "1번 프롬프트 A-Z" / problem.md 해결의 세 핵심 약속이 검증 가능한 메커니즘으로 끝까지 풀리지 않았다. 아래 BLOCKER 3개 반영 후 재검토 시 합의 가능.
> **사용자 6개 결정(Q1~Q6)은 뒤집지 않음**. 그 결정의 "실현 가능성"만 도전.

## 등급
- **[CRITICAL]** 수정 없으면 8~10시간 자동 빌드가 작동 못 하거나 "내일부터 쓸 수 있다"가 거짓.
- **[MAJOR]** 작동은 하나 핵심 가치 1개 약화. Phase 9 전 보강.
- **[MINOR]** 운영 품질 부담. 점진 개선.

---

## 영역별 도전

### 영역 1. 사용자 의도와 plan의 정합성 — **[CRITICAL]**

| 사용자 약속 | Plan의 답 | Critic 평가 |
|---|---|---|
| "사용할수록 영리해진다" | `/learn` + learnings 4파일 | 메커니즘 있음. **"영리해짐" 측정 지표 부재**. 누적 = 영리해짐이 아니다. |
| "1번 프롬프트로 A-Z" | `/build` (Phase 9) | **MVP 1차(Phase 0~3)에 없음**. Phase 3 끝나도 사용자는 여전히 프롬프트→답변 루프. prompt.md의 "루프 탈피"는 Phase 9까지 보류. |
| "내일부터 쓸 수 있는 미니멀·파워풀" | Phase 3 종료 | "파워풀"의 실체 약함. 진짜 약속은 `/build`가 작동하는 MVP-B. |

**수정 권고**:
1. "영리해짐" 측정 지표 명시. `.omc/learnings/_metrics.json`에 (적용 학습 수, confirm 비율, 충돌 해결 수) 누적. 매 SessionStart에 "지난 7일 너에 대해 X개 배웠다" 출력.
2. **MVP 정의 2단계화**: MVP-A(Phase 0~3, 도구 셋업 + 학습 시작) / MVP-B(Phase 0~5+9, A-Z 자동 빌드 가능). 진짜 약속은 MVP-B.
3. Phase 3 종료에 dogfooding 체크리스트(영역 D)를 게이트로.

### 영역 2. MVP 정의 과잉 — **[MAJOR]**

Phase 3 종료 시 사용자가 할 수 있는 것: `/setup-both`, `/double-check`, 자동 아카이브. 불가능: `/consensus`(P4), `/resume-session`(P5), `/merge-skill`(P7), `/build`(P9). **"도구가 설치된 상태"일 뿐 "파워풀"이 아니다.**

**수정 권고**: Phase 순서 재배치 → `0 → 1 → 2 → 4(/consensus) → 5(/resume) → 3(자동 아카이브 등) → 6~9`. `/consensus`와 `/resume-session`이 파워풀의 핵심.

### 영역 3. 자기 참조 위험 (Bootstrap) — **[CRITICAL]**

CLAUDE.md는 모든 작업에 TDD + `/codex:review --wait` + Task 단위 즉시 커밋 강제. 그런데 Phase 1~4 자체가 그 인프라를 만든다. 닭-달걀:
- Phase 1 SessionStart 훅 작성 시 `/consensus`가 없는데 합의는 어떻게?
- Phase 1 TDD 위한 `tests/hooks/lib.bats`의 러너는 Phase 0 `package.json`에 있어야 하는데 미명시.
- Phase 4 자체가 `/consensus` 구현인데 그 동안의 합의 루프는?

**수정 권고**:
1. Phase 0에 **부트스트랩 합의 규약** 추가: "Phase 0~4 동안 `codex-plugin-cc` 스킬을 **직접 호출**하여 합의 수동 수행. 자동화는 Phase 4 종료 후 작동." 우회가 아닌 명시적 부트스트랩.
2. Phase 0 `package.json`에 **테스트 러너 의존성 명시** (bats-core, vitest 등). Phase 1.1 TDD가 어떤 명령으로 작동하는지 검증 가능.
3. Phase 4 종료 후 **자기 적용 체크포인트**: "Phase 5부터 이 하네스 자체가 `/consensus`로 개발된다" 게이트.

### 영역 4. Codex 합의 루프 자동화의 함정 — **[MAJOR]**

CLAUDE.md는 MCP 직접 호출 금지. Plan 3.2는 인용했지만 미명시:
- `/consensus`가 `/codex:review --wait`를 **어떻게 호출**하는가? 셸? 슬래시 chain?
- "Skill 호출이 `disable-model-invocation`으로 실패"하면 자동 루프는?
- `--skip-codex` 비상 옵션은 CLAUDE.md "임의 우회 금지" 정면충돌. **무인 야간 빌드에 사용자는 없다.**
- `VERDICT: APPROVE` 토큰은 Plan 자체 정의일 뿐 `codex-plugin-cc` 공식 출력 형식 아님. Architect 검증 필수.

**수정 권고**:
1. `/consensus` 알고리즘에 호출 메커니즘 명시(셸 `claude -p "/codex:review --wait"` vs slash chain). Architect 검증.
2. Codex 장애 무인 빌드 정책: 즉시 일시정지 + Slack/Telegram 알림 + 30분 backoff. `--skip-codex`는 **무인 환경에서 자동 활성화 차단**.
3. `VERDICT` 토큰은 codex-plugin-cc 실제 출력 확인 후 확정.

### 영역 5. `/learn` 영속성의 신호 대 잡음 — **[MAJOR]**

Plan 5.4는 가중치 감쇄 미도입 추천. 그러나 prompt.md는 8~10시간 야간 빌드 명시. 한 번의 야간 빌드만으로도 SessionEnd 수십 회 → 수백 학습 누적 → 한 달이면 거대 파일. 5.5의 confirm 절차는 야간 무인 빌드에 작동 불가(새벽 3시 누가 입력하나?).

**수정 권고**:
1. **무인 모드 `/learn` 정책**: ralph/`/build` 중 SessionEnd는 `.omc/learnings/_pending.jsonl`에 보류 → 다음 인간 세션 시작 시 일괄 confirm.
2. 자동 트림 기준 명시: priority(P:low) 우선 + LRU. 카테고리당 100줄 상한.
3. `_metrics.json`에 적용 vs 무시 ratio 누적. 7일 ratio < 20% 카테고리는 트림 강화.

### 영역 6. 세션 재개의 실제 작동 (problem.md) — **[CRITICAL]**

problem.md 원문: "resume에도 세션 찾기 어려움. --continue로 바로전만 가능. 2,3개 전은 아예 못찾아 새롭게 시작하여 세션 다 날림."

Plan 7.6은 "`--resume {sessionId}` 안내 출력 + 컨텍스트 dump". **이는 problem.md를 진짜 해결하지 않는다**:
1. Claude Code `--resume`이 임의 과거 세션에서 작동하는지 미검증(대부분 CLI는 최근 N개만).
2. SessionEnd 훅 입력에 `sessionId`가 실제 노출되는지 미검증.
3. "안내 출력"은 텍스트 보여줄 뿐 세션을 재시작 못 한다. 사용자가 결국 새 세션을 열고 dump를 붙여넣어야 한다 = 기존 불편 그대로.

**수정 권고**:
1. Architect Phase 0 초반 실측: SessionEnd 입력 스키마, `claude --resume <id>` 실제 동작, 임의 과거 세션 복원 가능 여부.
2. 작동 안 하면 **대안 설계 필수**: archive 본문 + 브랜치/cwd 복원 스크립트 → `claude -p "$(cat archive.md)"` 패턴으로 새 세션 자동 시작.
3. `/resume-session N`이 "안내"가 아닌 "복원 실행"이 되어야.
4. Phase 5 검증 시나리오 명시: "5개 전 세션 실제 재개 → 동일 컨텍스트 작업 재개 = 완료."

### 영역 7. Phase 의존성 사각지대 — **[MAJOR]**

Plan 9는 단일 작업자 직렬 vs Wave 병렬을 동시 가정. 충돌 시나리오:
- Wave A Phase 1(`.claude/settings.json`)과 Wave C Phase 7(`plugin.json`)이 동시 진행 시 충돌 가능.
- Phase 6.3 `policy/` → `.claude/rules/` 마이그레이션이 Phase 1과 동시 진행되면 Phase 1이 참조할 룰 경로 이동.

**수정 권고**:
1. 의존성 그래프를 **파일 단위 충돌 매트릭스**로 보강. 같은 파일 write Phase는 병렬 불가.
2. ralph 자동 빌드는 기본 **단일 작업자 직렬**. `--parallel`은 사용자 명시 옵션. 야간 무인 충돌은 복구 불가.
3. Phase 8을 Wave A에서 제외 → Phase 7 이후 직렬화(클론은 최종 구조 의존).

---

## 추가 도전

### A. `.env` 보안 자동 전파 — **[CRITICAL]**

사용자 글로벌 CLAUDE.md `.env` 절대 규칙(화이트리스트 2개 + `branch-guard.sh` 룰 7·8)이 회사계정 클론 후 자동 적용되어야 한다. Plan 8.2는 이를 미명시.

**수정 권고**:
1. Phase 8.2에 **환경 가드 자동 설치** 체크리스트: `~/.claude/hooks/branch-guard.sh` 부재 시 `scripts/install-env-guard.sh` 실행.
2. `.claude/settings.json`에 프로젝트 레벨 `Read/Edit/Write(.env*)` deny 룰 명시.

### B. 레퍼런스 패턴 무비판 차용 — **[MINOR]**

superpowers의 핵심 가치는 스킬 디스커버리인데 Plan은 5개 고정 자동 주입으로 단순 컨텍스트 prepend화. gstack `/learn`은 70 스킬 + GBrain DB 맥락의 가치인데 Plan은 마크다운 append. **수정 권고**: 부록에 "가져온 것 vs 의도적으로 안 가져온 것" 매트릭스.

### C. 명시적 거부 항목 부재 — **[MAJOR]**

미니멀이 되려면 "안 한다"가 모여 보여야 한다. **수정 권고**: Plan 끝에 Non-Goals 섹션 — 70개 스킬 안 함, GBrain DB 안 함, supabase 텔레메트리 안 함, 멀티 워커 안 함, 자동 PR 머지 안 함, IDE 통합 안 함, 웹 UI 안 함.

### D. Dogfooding 부재 — **[CRITICAL]**

Phase 9에서 처음 셀프 테스트. 8 phase 끝에서 처음 작동시키면 격리 불가. **수정 권고**: Phase별 미니 dogfooding 체크포인트 + 통과 못 하면 다음 Phase 차단(Task 단위 즉시 커밋 규칙 정합).
- P1 종료: SessionStart 훅 실제 컨텍스트 주입.
- P2 종료: `/learn "X"` → 다음 세션 회수 확인.
- P3 종료: 빈 디렉터리에서 `/setup-both` → 5개 자동 주입 작동. **여기가 "내일부터 쓸 수 있다"의 진짜 검증**.
- P4 종료: `/consensus "변수 X→Y"` → 실제 Codex 합의 도달.
- P5 종료: 3개 전 세션 실제 복원.

---

## 가장 위험한 BLOCKER 3개

### BLOCKER 1. `/resume-session`이 problem.md를 실제로 해결 못 함 (영역 6)
"안내 출력"은 사용자 호소("세션 다 날리는") 해결 못 함. Architect Phase 0에서 `--resume` 임의 과거 세션 실측 필수. 작동 안 하면 archive 본문 기반 새 세션 자동 시작 대안 필수. 안 풀리면 plan 핵심 약속 1개 무너짐.

### BLOCKER 2. 부트스트랩 합의 규약 없음 (영역 3)
`/consensus`를 만드는 Phase 1~4의 합의 루프 미정의. CLAUDE.md가 모든 작업에 합의 강제 → plan이 자기 규칙 위반. Phase 0에 "부트스트랩 동안 `codex-plugin-cc` 수동 직접 호출" 규약 추가 필수.

### BLOCKER 3. 무인 야간 빌드 시 Codex 장애 정책 부재 (영역 4)
무인 빌드 중 Codex 무응답 시 `--skip-codex`는 CLAUDE.md 정면 위반. 무인 환경에서 자동 활성화 차단 + 일시정지 + Slack/Telegram 알림이 plan에 명시되어야 8~10시간 무인 빌드 가능.

---

## Architect가 추가 검증할 영역 3개

### 검증 1. Claude Code SessionEnd 훅 입력 스키마 + `--resume` 호환성
- SessionEnd 훅 JSON 입력에 `sessionId` 노출 여부.
- `claude --resume <id>`가 임의 과거 세션에서 작동하는가, 최근 N개 제한이 있는가.
- 작동 안 하면 archive 본문 기반 새 세션 자동 시작 패턴 가능성.
- 결론: `/resume-session N` 실제 알고리즘 확정.

### 검증 2. `codex-plugin-cc` 실제 출력 + 셸 호출 메커니즘
- `/codex:review --wait`의 stdout 형식. `VERDICT: APPROVE` 토큰 강제 가능성.
- 슬래시 커맨드 간 chain 가능성 vs 셸 레벨 `claude -p "/codex:review"` 필요성.
- `disable-model-invocation` 실패 시 자동 일시정지 메커니즘.
- 결론: `/consensus` 내부 호출 메커니즘 확정.

### 검증 3. `.claude-plugin/`, `.codex-plugin/` 공식 스키마 + `.codex/config.toml` hooks 키
- 마켓플레이스 plugin.json 필수 필드 검증 규칙(Plan 8.3 스키마가 통과 가능한가).
- Codex CLI hooks 등록 정확한 키 형식.
- `.codex/hooks/session-start.sh` Claude 래퍼 stdout 컨텍스트 흡수 호환성.
- 결론: Phase 1.5 + Phase 7 스키마 확정.

---

**Critic 최종 결론**: 표면 설계와 ksbc/OMC/superpowers/gstack 통합 의도는 견고. 그러나 (1) problem.md 진짜 해결 불확실, (2) 부트스트랩 자기 모순, (3) 무인 빌드 장애 정책 부재의 BLOCKER 3개는 합의 전 반드시 풀려야 한다. 사용자 6개 결정은 존중하되 그 위 자동화 메커니즘이 실측 검증을 거쳐야 "8~10시간 후 작동하는 결과물"이 보장된다. Planner는 BLOCKER 3 + Major 5를 반영한 v2를 제시하고, Architect는 위 검증 3건의 실측 결과를 첨부해 다음 라운드를 진행하기를 권고한다.
