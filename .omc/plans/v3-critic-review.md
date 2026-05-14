# v4 Plan — Critic Review (2차 라운드 통합)

> **역할**: ralplan v3 합의 사이클 2차 라운드 Critic. Planner v4(`v3-global-tool-plan.md`, 802 lines)가 1차 라운드 6 BLOCKER + 9 MAJOR 해소를 시도. v4가 사용자 의도(prompt.md) + 실현 가능성을 만족하는지 결정.
> **작성자**: Critic (Claude Opus 4.7, read-only) | **작성일**: 2026-05-14
> **사용자 확정**: Q1=A, Q2=A, Q3 재정의, Q4=A, Q5, Q6=A — 뒤집기 금지.

---

## 종합 판정

**VERDICT: APPROVE (조건부)** — 1차 BLOCKER 3건 모두 [SOLVED] 또는 [PARTIALLY]. **신규 BLOCKER 0건**. 본질 도전 #2(미니멀 vs 야심)가 [MAJOR]로 남아 있으나, Phase 0.0 착수 가능. 합의 사이클은 본 라운드로 종결.

## 1차 BLOCKER 3건 해소

| BLOCKER | v4 해결 | 결과 |
|---------|---------|------|
| B-C1: Phase 0 git mv 회귀 | 0.A~0.E 5분할 + 각 bats 45/45 게이트 + paths.sh + Phase 5 검증 보고서 | **[SOLVED]** |
| B-C2: /merge-skill secret 유출 | confirm 기본 + 5종 정규식 + .env 차단 + 회사 PC 경고 + fork 추천 | **[PARTIALLY]** (Q-N 사용자 결정 필요) |
| B-C3: 자기 dogfood 회귀 | `.harness-active` 1행 `mode=source-repo` + SessionStart 분기 + /pjt-init no-op | **[SOLVED]** |

## 본질 도전 5건

1. **사용자 의도 정합성**: [PASS] — 2단 install이 사용자 deny 룰 정합. /pjt-init "공통 설치" 정의 박스로 모호성 해소. OMC 1채널 → §13에 마켓플레이스 v0.3.0+ 명시.
2. **미니멀 vs 야심**: [MAJOR] — v4는 16섹션 802줄. Phase 0~3 유인 의무로 무인 야간 빌드 약속과 갭. **수정 권고**: README에 "Phase 0~3 유인, 4~7 무인" 명시.
3. **시간 추정**: [PASS] — Phase별 추정 + 합계 15~18시간. Phase 0.B 60분이 빠듯할 수 있으나 ±30% 버퍼 수용.
4. **v0.1.0 자산 보존**: [PASS] — §10-bis 7항 매트릭스 + Phase 5 검증 보고서 + 점진 게이트(0.A→0.B→0.E).
5. **신규 우려**: [MINOR] — paths.sh, secret 정규식, --from-tar, source-repo 마커, Q-N. 모두 게이트로 차단되거나 사용자 confirm 필요.

## 추가 도전

- A. v0.1.0 KPI 5개 → v0.2.0 보존 [PASS]
- B. /pjt-init 후 첫 사용 [PASS] (--merge README 1순위)
- C. ralplan 합의 도달 [PASS] (3차 불필요)

## 결론

**VERDICT: APPROVE (조건부)**

**조건 (Phase 0.0 착수 전 사용자 1회 confirm)**:
1. **Q-N**: 회사 PC fork vs 동일 레포 push — fork [추천]
2. **Q-M**: 회사 PC 네트워크 환경 — 사용자 직접 확인

**Phase 0.0~0.E 후 자동 닫힘**: Q-O(`CLAUDE_PROJECT_DIR`) → Phase 0.0, Q-P(secret 정규식) → Phase 4, Q-K(/pjt-init 기본) → Phase 2.

**v0.2.0 출시 차단**:
- Phase 5 종료: `04.docs/v0.1.0-asset-preservation.md` 7항 PASS
- Phase 6.B: 본 레포 자체 dogfood 45/45 + /setup-both 5/5
- Phase 6.C: 사용자 실제 회사 PC install (opt-in)

### v0.1.0 자산 보존 보증

사용자가 v0.1.0에 투자한 시간(21커밋 + 45 bats + 13 skills + 9 commands)이 무의미해지지 않음. v4 게이트 메커니즘이 회귀 0건 강제.

### 합의 사이클 종결

본 라운드로 합의 도달. Planner v5 불필요. 사용자 Q-N + Q-M 회답 시 즉시 Phase 0.0 착수 가능.
