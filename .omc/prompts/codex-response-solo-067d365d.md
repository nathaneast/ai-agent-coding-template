---
provider: "codex"
agent_role: "critic"
model: "gpt-5.3-codex"
prompt_id: "067d365d"
timestamp: "2026-05-14T12:11:48.617Z"
---

목표 결과는 `/solo` 제안서의 설계 타당성을 7개 질문 기준으로 `REQUEST_CHANGES/APPROVE`까지 근거 있게 판정하는 것입니다. 먼저 저장소의 실제 규칙 파일(`.claude/rules`, 관련 스킬 문서)을 빠르게 확인해 제안서가 충돌 없이 적용 가능한지 검증하겠습니다.
설계 리뷰 정확도를 위해 실제 로컬 규칙 파일을 확인해 충돌 여부를 교차검증하겠습니다. 지금부터 `CLAUDE.md`가 참조하는 `.claude/rules`와 핵심 스킬 문서를 읽어 제안서의 강제 규칙 정합성을 점검합니다.
핵심 발견: 현재 저장소에는 `CLAUDE.md`가 가리키는 `.claude/rules`, `.claude/skills` 파일들이 실제로 없습니다. 다음으로 `policy/`와 `plugin/claude/`를 확인해 실질적인 규칙 대체 소스가 있는지 검증하겠습니다.
현재 제안서의 “자동 적용”이 실제 주입 메커니즘과 맞는지 확인하기 위해 `session-start` 훅과 규칙 주입 스크립트를 추가로 점검하겠습니다. 이걸 확인하면 자동 강제의 견고성/오작동 지점을 더 정확히 짚을 수 있습니다.
교차검증을 마쳤고, 핵심 리스크는 세 가지입니다: (1) 기존 강제 규칙과의 충돌(특히 합의 루프/브랜치), (2) 라우팅·학습 메커니즘의 정의 부족, (3) 장시간 자율 실행 운영 가드 누락입니다. 이제 Q1~Q7을 각각 근거와 수정 우선순위까지 포함해 정리해서 전달하겠습니다.
**주요 Findings (심각도 순)**
1. 합의 루프 규칙과 충돌합니다. 제안서는 `small`에서 PLAN/CONSENSUS를 스킵한다고 명시([solo-proposal-v1.md:30](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md:30), [solo-proposal-v1.md:102](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md:102))하지만, 현재 합의 규칙은 “모든 설계/개발/QA 합의 의무”입니다([consensus-loop/SKILL.md:3](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/consensus-loop/SKILL.md:3), [consensus-loop/SKILL.md:42](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/consensus-loop/SKILL.md:42)).
2. 브랜치 정책이 충돌합니다. 제안서는 `.harness-main-only`가 없으면 `feature/*`를 자동 생성한다고 했고([solo-proposal-v1.md:75](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md:75)), 현재 스킬은 `dev` 전용 규칙입니다([branch-strategy/SKILL.md:7](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/branch-strategy/SKILL.md:7)). 또한 이 저장소는 `main` 단일 예외를 명시합니다([CLAUDE.md:27](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/CLAUDE.md:27), [.harness-main-only:5](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.harness-main-only:5)).
3. Codex 호출 경로가 규칙과 충돌합니다. 제안서의 직접 MCP 호출 옵션([solo-proposal-v1.md:37](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md:37))은 “직접 `ask_codex` 호출 금지” 규칙과 충돌합니다([consensus-loop/SKILL.md:43](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/consensus-loop/SKILL.md:43)).
4. 상태 파일 경로가 불일치합니다. `--resume`는 `.omc/solo-state.json`([solo-proposal-v1.md:14](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md:14))인데, 상태 파일 섹션은 `.omc/state/solo-state.json`([solo-proposal-v1.md:115](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md:115))입니다.

### Q1. 차별화의 진정성
자동 라우팅 자체는 진짜 가치가 있습니다. 다만 “하드 라우팅”이면 오분류 비용이 커져 역효과가 납니다. 따라서 차별점으로 성립하려면 “추천 + 신뢰도 기반 fallback”이어야 합니다.  
히스토리 기반 가중치 조정은 현재 문서 상태로는 vaporware에 가깝습니다. “업데이트 식/표본 수/드리프트 제어”가 전혀 없습니다([solo-proposal-v1.md:85](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/research/solo-proposal-v1.md:85)).  
마케팅을 줄이려면 v1은 이렇게 단순화하는 게 맞습니다.
1. 정적 라우팅표 + 위험 신호 기반 강제 승격만 구현.
2. 학습은 “가중치 업데이트” 대신 “유사 실행 3건 in-context 주입”으로 시작.
3. 성능 지표(성공률/재시도/평균 소요)부터 먼저 수집.

### Q2. 사용자 규칙 자동 적용 — 안전한가?
방향은 맞습니다. 다만 “강제할 것”과 “기본값으로 둘 것”을 분리해야 안전합니다.
1. 절대 강제: `.env` 보안, 시크릿 출력 금지, 파괴적 git 금지, 커밋 전 품질게이트.
2. 기본 강제+해제 가능: TDD 강도, 합의 빈도, plan 상세도.
3. 해제는 `--break-glass`류 단일 플래그가 아니라 개별 플래그(`--no-consensus`, `--no-tdd`) + 이유 로깅 + 결과물에 표시가 낫습니다.

`.harness-main-only` 분기는 개념적으로는 견고합니다. 다만 현재 규칙세트와 충돌이 있으므로, 우선순위를 명확히 해야 합니다.
1. 저장소 루트 마커 검증.
2. `CLAUDE.md` 정책 파싱.
3. 없으면 보수적 기본값(`dev` 유지) 적용.  
지금 제안의 `feature/*` 기본값은 현 규칙과 어긋납니다.

### Q3. Phase 0 트리아지 휴리스틱
신뢰성 있게 하려면 “규칙 기반 1차 + LLM 2차” 하이브리드가 필요합니다.
1. 1차 규칙: 키워드, 예상 변경 파일수, 위험 패턴(auth/schema/.env), 테스트 필요성.
2. 2차 LLM: intent/scope 분류 + confidence(0~1) + 근거 3줄.
3. confidence 낮으면 자동 `strict` 승격.

오분류 안전망은 필수입니다.
1. execute 전 dry-run 계획 생성 후 재분류.
2. 첫 변경 1회 후 scope 재평가.
3. 검증 실패 1회만으로 라우팅 재선정.

`--strict`는 유효한 보완입니다. `--fast`는 위험합니다. `--fast`는 read-only/docs/test 수준에만 허용하고, auth/schema/security 변경이 감지되면 강제로 거부해야 합니다.

### Q4. 합의 루프 max 4 + 폴백
`max 4`는 합리적입니다. 실제로 현재 consensus 스킬도 동일값을 사용합니다([consensus-loop/SKILL.md:14](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/consensus-loop/SKILL.md:14), [consensus-loop/SKILL.md:44](/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/plugin/claude/skills/consensus-loop/SKILL.md:44)).  
하지만 OMC critic 단일 폴백은 “합의”가 아니라 “대체 리뷰”입니다. 의미는 있지만 이름을 분리해야 합니다.
1. 상태를 `DEGRADED_REVIEW`로 명시.
2. degraded 모드에서는 자동 커밋 금지.
3. 사용자 승인 후에만 진행.

더 나은 폴백 순서:
1. Codex 재시도(백오프/타임아웃 상향).
2. 독립 2중 리뷰(critic + security/code-reviewer) + 정적 게이트.
3. 그래도 실패면 USER_CONFIRM_NEEDED 마커 후 중단.

### Q5. Phase 6 “REFLECT” 학습 메커니즘
현재 문서는 작동 메커니즘이 없습니다. 최소 아래는 필요합니다.
1. 통계: `route_stats[intent][agent]={n, pass_rate, avg_loops, avg_duration, last_30d}`.
2. 보상식 예시: `reward = pass*1.0 - 0.2*loops - 0.1*retries - 0.1*duration_norm`.
3. 업데이트: `ema = (1-a)*ema + a*reward`, `a=0.2`.
4. 라우팅 점수: `score = base + beta*ema - risk_penalty`.
5. 안전장치: `n<5`면 학습치 미적용, 조정폭 ±20% clamp, 30일 decay.

질문하신 대로 v1에서는 “가중치 학습”보다 “history in-context 주입”이 더 낫습니다. 단순하고 디버그 가능하며 drift 위험이 낮습니다.

### Q6. 빠진 항목
누락/약한 항목이 맞습니다.
1. 비용/토큰 캡: 없음. `max_tokens`, `max_minutes`, `max_tool_calls` 하드캡 필요.
2. 사용자 알림: 없음. 장시간 작업 종료/중단 시 Discord/Telegram 훅 필요.
3. 동시 실행 락: 없음. `.omc/locks/solo.lock` + PID/TTL 체크 필요.
4. Worktree 격리: 없음. `--isolated` 옵션으로 worktree 생성/정리 필요.
5. 로그 보존 정책: 없음. 실행 로그를 `.omc/logs/solo/{run_id}`에 저장하고 30일 보존/요약 인덱스 필요.

### Q7. 최종 평가
VERDICT: **REQUEST_CHANGES**  
점수: **6/10**  
가장 큰 문제 1개: **기존 강제 규칙(합의 루프/브랜치/Codex 호출 경로)과의 충돌**  
가장 큰 강점 1개: **사용자 로컬 규칙을 오케스트레이션 레이어에 끌어올린 방향성 자체는 매우 좋음**  
제안하는 수정 우선순위 Top 3:
1. **정합성 먼저 고정**: 합의/브랜치/Codex 호출 규칙 충돌 제거 + 경로 불일치 수정.
2. **v1 단순화**: 라우팅은 정적+confidence fallback, 학습은 in-context retrieval로 축소.
3. **운영 가드 추가**: 비용 캡, 동시 실행 락, degraded 모드 정책, 로그/알림/격리(worktree) 도입.