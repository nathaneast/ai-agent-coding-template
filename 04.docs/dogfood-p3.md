# Dogfood P3 — MVP-A 완성 게이트

- Date: 2026-05-14
- Branch: dev
- Phase: 3 종료 (MVP-A 게이트)
- Commits: a38aeb1 ~ cfd3491

## 5개 사용자 시나리오

### 시나리오 1: SessionStart 자동 주입
- 명령: `bash .claude/hooks/session-start.sh | wc -c`
- 출력: 7005 bytes (목표 5000~8000)
- 결과: ✅ PASS

### 시나리오 2: /learn → 회수
- 절차: learn-add.sh patterns "MVP-A-dogfood-S2-<ts>" → SessionStart 회수
- 출력: added to patterns (7 lines) → grep found marker
- 결과: ✅ PASS

### 시나리오 3: /setup-both 양쪽 어댑터 일치
- 명령: `bash scripts/setup-both.sh`
- 출력: setup-claude PASS (19/0), setup-codex PASS (11/0), Identical output
- 결과: ✅ PASS

### 시나리오 4: /double-check KPI 카운터
- 절차: double-check-incr.sh 호출 → _metrics.json counters.double_check_invoked +1
- 출력: 1 -> 2
- 결과: ✅ PASS

### 시나리오 5: 프롬프트 중복 감지
- 절차: archive-prompt.sh 2회 → 두 번째 호출 "duplicate" 출력
- 출력: duplicate detected (Jaccard 1.00, occurrences 1)
- 결과: ✅ PASS

## 결론

- PASS x 5 / FAIL x 0
- **MVP-A 게이트: PASS** (5/5)

## 누적 bats 테스트 현황

| 파일 | 테스트 수 |
|------|----------|
| test_inject.bats | 4 |
| test_learn_add.bats | 4 |
| test_log.bats | 3 |
| test_token_budget.bats | 3 |
| test_archive_prompt.bats | 4 |
| **합계** | **18** |

## 다음 단계

- Phase 4 (/consensus) 진입 → MVP-B 향함
- 합의 루프 자동화 구현
