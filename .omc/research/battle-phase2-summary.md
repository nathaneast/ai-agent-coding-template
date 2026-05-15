# Phase 2 Summary — Rebuttal Convergence

## 수렴된 단일안 (6/6 합의)

1. **신규 에이전트 .md = 0개**
2. **스킬 1개 신설** (명칭 미정: `/tech-decide` / `/tech-arch` / ralplan alias)
3. **Stakes-based Tiered Router** (T0=architect 단독 5-10초 / T1=+critic 30-60초 / T2=+외부 엔진 명시 트리거)
4. **출력 항목 6-7개**: 핵심결정 / 트레이드오프 / 프론트 비유 / 다음 액션 / **불확실성·확신도** / **롤백비용** / **결정유예 영향**
5. **OMC architect→critic 2-hop 기본**, ralplan은 T2 시 호출
6. **Implicit hand-off**: Planner가 받을 Proposed Action 출력 하단 포함

## 남은 미합의 (Phase 3에서 stress)

- 진입점 명칭 결정 권한: 사용자 자유 vs 가이드라인
- 자동 승격 트리거: stakes(Gemini) / file-count·keyword(planner) / risk-score(Codex) — 3안 통합 가능?
- "architect.md에 Persona_Adaptation 섹션 추가"는 사실상 에이전트 파일 변경 — 0개 합의에 위배?
- 사용자가 명시한 "에이전트 만들고 싶어" 요구 vs 6/6 권고 "에이전트 신설 0" 불일치 해소 방법
- Fast-path 응답과 백그라운드 verify 결과 충돌 시 UX 미정의 (Gemini 자기 시인)
- Output 항목 6-7개가 daily-driver마다 5-10초 안에 정직하게 채워질 수 있는가
