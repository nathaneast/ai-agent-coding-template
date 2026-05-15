# Phase 5 Recommendation — tech-arch Battle

## Decision
**Option γ (1 thin agent + skill backend)** — 사용자 명시 요구 "에이전트 이름 tech-arch + 커맨드로도" 두 요구를 모두 충족하면서 Phase 1 6/6 합의(에이전트 .md 최소화)와 Phase 3 Codex 5 guards를 동시에 만족하는 유일한 옵션.

## Confidence
**High** — 사용자 발화는 일관(singular 에이전트 + singular 커맨드). β(에이전트 폐기)는 ownership 위반(Codex H3 ACCEPT). δ(ralplan alias)는 신규 가치 부재 + 중복 위반(C2). γ가 5 guards 흡수 가능한 유일 구조.

## Files to create (v1, mandatory)
- `~/.claude/agents/tech-arch.md` — 30-50줄 thin agent. Opus, READ-ONLY. 역할: identity + 5단 출력 규약 enforcement + skill 호출. 로직 없음.
- `~/.claude/skills/tech-arch/SKILL.md` — Tier router + 출력 템플릿 + hand-off 포맷.

## v2 (deferred, nice-to-have)
- `handoff-schema.json` — JSON 스키마 강제. v1은 output template의 hand-off 블록 명시(prose) 수준.
- `decision-log/` 디렉토리 — 결정 이력. v1은 notepad append로 시작, 운영 호출량 보면 결정.

## Output template

```
## Decision: <one-line>
**Confidence**: high/med/low | **Rollback cost**: low/med/high | **Defer impact**: <if you wait>

### Trade-offs
| Option | Pro | Con | Risk |

### Frontend analogy
<백엔드/인프라 → 프론트 mental model 매핑>

### Next actions
1. <step> → owner: <agent/user>

### Open questions (max 3)
1. ...

### Hand-off
{"artifact_id":"ta-YYYYMMDD-NNN","tier":"T0|T1|T2","next_agent":"planner|executor","payload":{...}}
```

## Tier rules (stakes-progressive, **illustrative defaults — tunable**)
- **T0** (architect 단독, ≤10s): 변경 범위 작음 + 보안/마이그레이션 키워드 없음 + 모호도 낮음
- **T1** (+critic, ≤60s): T0 미충족 OR 롤백 비용 중급↑
- **T2** (+Codex/Gemini, 명시): `--deep` 플래그 OR T1 confidence 낮음

구체 수치(file_count≤3, risk_score≥0.7 등)는 첫 10회 호출 후 telemetry로 튜닝. 초기 임계값은 정확도보다 escalation 보수성에 맞춰 설정.

## Ship guards (3 mandatory, v1)
1. Hand-off은 출력 마지막 코드블록으로 명시 (executor가 파싱 가능한 형태) — v2에서 JSON schema 검증
2. T0 후 confidence 낮으면 T1 자동 승격, 사용자에게 한 줄 notify
3. 결정 1줄 요약을 notepad에 append (v2에서 정식 artifact_id로 승격)

## Minority opinion preserved
**Runner-up**: β (skill-only, 0 agents)
**왜 옳을 수도 있나**: 6개월 후 사용자가 agent를 직접 호출하지 않고 항상 `/tech-arch` 스킬만 쓰면 agent stub은 vestigial.
**Migration trigger**: agent 직접 호출 <3/주 AND skill 호출 ≥10/주 → β로 마이그레이션. 또는 agent stub LOC >80 (로직 누수).

## Open questions
**None — defaults**: 위 spec 그대로 진행 가능.
