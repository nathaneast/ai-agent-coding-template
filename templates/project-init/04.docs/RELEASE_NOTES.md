# Release Notes

## v0.1.0 — 2026-05-14

**MVP-A + MVP-B 완성**: "내일부터 쓸 수 있는 미니멀하지만 파워풀한" 개인 하네스.

### Phase 0~5 (MVP-B 게이트 통과)
- ksbc 골격 + 듀얼 플러그인 메타 (`.claude-plugin/`, `.codex-plugin/`)
- SessionStart 자동 주입 (5 스킬, 7K 토큰 budget)
- `/learn` 영속 학습 + KPI 카운터 5개
- `/setup-claude` / `/setup-codex` / `/setup-both`
- `/double-check` 5요소 분해
- 자동 프롬프트 아카이빙 (trigram + Jaccard 0.7)
- `/consensus` 합의 루프 + 3단 폴백
- `/resume-session N` (problem.md 해결)

### Phase 6~9
- OpenSpec 통합 (`/openspec:propose,explore,apply,archive`)
- policy/ → .claude/rules/ 마이그레이션 + DEPRECATED stub
- 듀얼 플러그인 메타 확장 (skills/commands/hooks 명시)
- `/merge-skill` 로컬 스킬 흡수
- 회사계정 복제 워크플로우 (`scripts/clone-to-company.sh` + env-guard)
- `/build` ralph 진입점 + iteration gate
- `02.workflow/`, `04.docs/RUNBOOK.md`, `04.docs/ONBOARDING.md`

### 테스트
- bats 45+ 통과 (5 핵심 모듈 + dogfood P1~P9)

### Non-Goals (의도적 미포함)
- 70+ 스킬 (gstack 수준)
- GBrain/Supabase 영속 DB
- 텔레메트리, 멀티워커, IDE 통합, 웹 UI
- Windows 1차 지원
