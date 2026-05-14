# Dogfood P8 — Phase 8 게이트

- Date: 2026-05-14
- Branch: dev

## 시나리오

### P8-1: scripts 존재 및 실행 가능
- 명령: `test -x scripts/clone-to-company.sh && test -x scripts/install-env-guard.sh`
- 결과: PASS

### P8-2: dry-run 시뮬레이션 (실제 임시 디렉터리 클론)
- 명령: `bash scripts/clone-to-company.sh /tmp/harness-clone-test-$$`
- 검증: target 디렉터리 존재, .env 없음, git 히스토리 1커밋(스크럽), settings.json 존재
- 결과: PASS (commits=1)

### P8-3: env-guard 설치 후 deny 확인
- 명령: `jq -e '.permissions.deny | any(. == "Read(.env*)")' .claude/settings.json`
- 결과: PASS

### P8-4: _metrics.json reset 확인
- 명령: `jq -r '.counters.learnings_added' _metrics.json == "0"`
- 결과: PASS (learnings_added=0)

### P8-5: ONBOARDING.md 존재
- 명령: `test -f 04.docs/ONBOARDING.md && grep -q "Company Account" 04.docs/ONBOARDING.md`
- 결과: PASS

## 최종 결론

5/5 PASS → Phase 8 게이트 통과
