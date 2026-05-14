# /solo v3 리뷰 요청

## 컨텍스트
- v2는 두 리뷰어에서 REQUEST_CHANGES (OMC 5/10, Codex 6/10) 받음
- v3는 사용자 직접 인터뷰 답변 9개 항목 반영
- 핵심 변경: 80% rule, `/pg` 진행 명령, criteria 머신 검증 형식, 일탈 감지, commit-only, solo-result/ 폴더

## 사용 시나리오 (확정됨)
1~10시간 장시간 자율 실행. 사용자는 설계/기획만 티키타카(Stage A) → spec md 작성 → `/solo`로 자율 실행(Stage B) → 결과물 보고서 확인.

## 리뷰 대상
`.omc/research/solo-spec-v3.md`

## 답할 질문 (각각)

### Q1. v2 합의 항목 모두 유지됐는가?
v2에서 합의한 9개 변경(합의 의무, 브랜치 dev 기본값, Codex 슬래시 경유, 트리아지 휴리스틱, Reflexion 폐기→in-context, Gemini 폴백, 운영 가드 6종, 상태 파일 통일, --fast 합의 우회 제거)이 v3에 모두 살아있는가? 누락된 게 있는가?

### Q2. Phase 1 criteria 도출 방식 — 견고한가?
- planner가 LLM으로 criteria를 뽑는데, "머신 검증 가능한 verify_cmd"를 정확히 작성할 수 있는가?
- type=visual/manual은 결국 사람이나 playwright agent에 의존 — 자율 루프 안에서 어떻게 객관적으로 통과 판정?
- criteria 도출이 너무 많거나 너무 적게 나올 때 안전망?

### Q3. 80% rule — 위험 신호?
- 10h 도달 시 80% pass면 graceful exit. 그런데 통과 안 한 20%가 가장 중요한 criterion일 수 있음.
- must_pass 중에서 우선순위가 있어야 하나? (예: security/data-loss는 100% 의무)
- "80%면 OK"가 사용자 룰 위반 가능성?

### Q4. `/pg` 명령 — 실용성?
- 별도 slash command로 분리한 게 맞나, 아니면 `/solo --status`로 통합?
- 출력 형식이 사용자가 5시간 후 깨어나서 "지금 잘 되고 있나" 즉답 가능한가?

### Q5. 일탈 감지 — 가능한가?
- "사용자 명시 키워드가 직전 5 iteration 산출물에 0회" — 휴리스틱이 너무 단순한가?
- 잘못 감지로 멀쩡한 작업 멈춤 위험?

### Q6. Phase 5 — push/PR 없이 commit만?
- 사용자가 commit만 원했음. PR은 본인이 만든다는 의미.
- 그런데 10시간 자율 실행 후 자고 일어났을 때 commit이 main에 쌓여 있다? `.harness-main-only`가 아닌 프로젝트에서는 feature 브랜치 + push 없음 = 사용자가 직접 push해야 함 → 합리적인가?

### Q7. 실용성 — 진짜 1~10시간 돌 수 있는가?
- iteration 100회, 각 30초~5분 = 50min~500min = ~8h. 가능?
- Claude API 비용 $20 cap — Opus 다수 호출 시 한도 가능성?
- 24h soft timeout — 너무 길다? Anthropic API rate limit 우려?

### Q8. 최종 평가
**VERDICT**: APPROVE / REQUEST_CHANGES
**점수**: 1-10
**v2 대비 개선도**: ?
**가장 큰 남은 위험 1개**: ?
**구현 우선순위 Top 3**: ?
