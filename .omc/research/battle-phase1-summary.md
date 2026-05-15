# Phase 1 Summary — Opening Statements

| 참가자 | Verdict | 핵심 주장 | 대안 |
|---|---|---|---|
| OMC architect | 전면교체 | tech-arch는 architect.md를 복제. 신규 가치 = "프론트 비유" 1개뿐. READ-ONLY 메인 + 6-fan-out은 OMC 직교분업 위반 | (A) 스킬만 신설, 에이전트 0 (B) architect.md에 `<Persona_Adaptation>` 섹션 추가 |
| OMC planner | 일부수정 | 90-180초/60-150k 토큰 예산 초과. READ-ONLY → executor 트리거 명세 누락. 그레이스풀 디그레이드 부재 | (A) 스킬 단독 + architect→planner 직렬 (B) ralplan에 프론트 비유 prompt extension |
| OMC critic | 전면교체 | ralplan이 이미 합의 루프 제공. 5단 출력 = 출력 템플릿. READ-ONLY 메인 = 영구 마찰 | (A) CLAUDE.md 한 단락 + ralplan alias (B) tech-arch를 라우팅 스킬로만 |
| OMC analyst | 전면교체 | 본질 요구 = "결정 파트너" ≠ 새 에이전트. 5단 출력에 불확실성/롤백비용/유예영향 누락. Hidden assumptions 7개 | (A) `/tech-decide` 스킬 + architect→critic 2-hop (B) Superpowers `/brainstorm` + `/plan --consensus` 조합 |
| Codex (critic) | 일부수정 | 솔루션 우선 사고. 디폴트 fan-out = orchestrator abandonment 위험. 30일 뒤 사용자가 직접 architect 호출로 우회 | (A) Tiered Router: T0=architect 단독, T1=+critic, T2=+Codex/Gemini 명시 트리거 (B) Skill-first agent-light |
| Gemini (designer) | 일부수정 | Latency Wall (daily-driver엔 60-90초 불가). 후속질문 3개 = Clippy noise. 비유는 mental model mapping이어야 함 | (A) Progressive Disclosure: 5초 fast-path + 백그라운드 verify (B) Complexity-Aware: Low/High stakes 토글 |

## 합의점 (6/6 공통)

1. **추천안 그대로 채택 반대** — 어떤 형태든 수정 필요
2. **6-engine fan-out은 과잉** — Daily-driver 사용 시 토큰·지연 비현실적
3. **READ-ONLY 메인 오케스트레이터는 마찰** — executor 핸드오프 명세 누락
4. **OMC 기존 자산 재활용 우선** — architect/analyst/planner/critic + ralplan 활용
5. **5단 출력 규약 자체는 가치 있음** — 단 정보 항목 보강 필요

## 핵심 의견 차이

- **에이전트 .md 파일 신설 여부**: architect/critic/analyst = 폐기, planner/Codex/Gemini = 조건부 유지
- **ralplan 대체 가능성**: critic = 즉시 대체 가능 / 나머지 = 별도 진입점 가치 있음
- **Tiered vs Progressive**: Codex = 명시 트리거 기반 / Gemini = 자동 fast-path 스트리밍

## 합의 수렴 방향

**Skill-first**, agent 신설 0개 또는 최소화, 기본 동작은 1-2 에이전트 직렬, 외부 엔진은 명시 트리거 or 백그라운드 verify, 5단 출력에 불확실성·롤백비용 추가.
