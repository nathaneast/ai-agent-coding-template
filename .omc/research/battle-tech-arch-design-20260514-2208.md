# Battle Transcript — tech-arch Agent Design (2026-05-14)

**Topic**: 위 결과(tech-arch 추천안)가 최선인가?
**Engines**: OMC analyst+architect+planner+critic, Codex (gpt-5.3-codex, critic role), Gemini (gemini-3-flash-preview, designer role)
**Skipped**: gstack (미설치), Superpowers /brainstorm (workflow type, deferred)
**Outcome**: γ (1 thin agent + skill backend) — Conditional Pass after 3 fixes

---

## Phase 0 — Framing
파일: `battle-frame.md`
- Domain: mixed (architecture-heavy)
- 6 criteria (C1–C6): 프론트 친화성, 중복 최소화, READ-ONLY 적정성, 오케스트레이션 깊이, 이중 표면, 마감
- Roster: 4 OMC + Codex + Gemini = 6명

## Phase 1 — Opening (6/6 parallel)
파일: `battle-phase1-summary.md`
- 전면교체 4 (architect/critic/analyst/OMC), 일부수정 2 (planner/Codex/Gemini)
- 만장일치: 추천안 그대로 채택 반대, 6-fan-out 과잉, READ-ONLY 마찰, OMC 자산 재활용 우선

## Phase 2 — Rebuttal (6/6 parallel)
파일: `battle-phase2-summary.md`
- 수렴: 에이전트 0개, 스킬 1개, Tiered router (T0/T1/T2), 6-7단 출력(불확실성·롤백비용 추가)
- 미합의: 진입점 명칭, 트리거 로직, ralplan 깊이, 결정 이력 저장

## Phase 3 — Stress Test (sequential)
파일: OMC critic stress + `p3-codex-response.md`
- OMC critic: H1-H6 hidden assumptions, S1-S4 second-order, E1-E3 edge cases, 사용자 "에이전트 만들고 싶어" 요구 50% 거부 정직한 격차
- Codex: NEEDS-GUARDS — Tiered Router는 Progressive Disclosure와 직교 결합. **Skill-only가 아니라 1 thin agent + skill이 더 낫다** (ownership intent 반영). 5 guards 필요.

## Phase 4 — Synthesis
파일: (Phase 4 analyst 출력)
- Decision matrix: α(원안)=3/18, β(skill-only)=13/18, γ(thin agent+skill)=13/18, δ(ralplan alias)=13/18
- Tiebreaker: 사용자 명시 요구 + C1 최고점 → γ

## Phase 5 — Decision (analyst → verifier)
파일: `phase5-recommendation-tech-arch.md`
- **Verdict**: γ, Conditional Pass
- **Verifier fixes 적용**: handoff-schema/decision-log = v2 deferred, telemetry-hook 제거, tier 임계값 = illustrative defaults
- **Ship guards 3 (v1)**: hand-off as code block / progressive escalation w/ notify / notepad append

---

## Engines on the Battlefield

| Engine | Role | Verdict | Output |
|---|---|---|---|
| OMC analyst | framing + synthesis | ✓ | Phase 0, 1, 4, 5 |
| OMC architect | system boundaries | ✓ | 전면교체 → γ 합의 |
| OMC planner | execution feasibility | ✓ | 일부수정 → γ 합의 |
| OMC critic | adversarial review | ✓ | 전면교체 → stress test |
| OMC verifier | recommendation verification | ✓ | Conditional Pass |
| Codex (gpt-5.3-codex) | external critic + stress | ✓ | Partial-modify → NEEDS-GUARDS → γ 추천 |
| Gemini (gemini-3-flash-preview) | UX designer | ✓ | Partial-modify, Progressive Disclosure |
| Superpowers /brainstorm | divergent ideation | ⚠ skipped | workflow type — single-shot opinion 불가 |
| gstack | product framing | ⚠ skipped | not installed |
