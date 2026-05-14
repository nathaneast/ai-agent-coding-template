# Dogfood P6 — Phase 6 Gate

- Date: 2026-05-14
- Branch: dev

## 시나리오

### P6-1: openspec/config.yaml 존재
- 명령: `test -f openspec/config.yaml`
- 결과: PASS

### P6-2: openspec 4개 스킬 SKILL.md 존재
- 명령: `for s in openspec-propose openspec-explore openspec-apply openspec-archive; do test -f .claude/skills/$s/SKILL.md; done`
- 결과: PASS

### P6-3: .claude/rules/*.md 5개 이상
- 명령: `[ "$(ls .claude/rules/*.md | wc -l | tr -d ' ')" -ge 5 ]`
- 실측: 5개 (coding, design, folder, project, user-interaction)
- 결과: PASS

### P6-4: openspec/changes/ 제안 파일 생성/확인/정리
- 명령: test-proposal/{proposal,design,tasks}.md 생성 → 확인 → rm -rf
- 결과: PASS

### P6-5: posttool-openspec-guard.sh → "OpenSpec Guard" 출력
- 명령: `echo '{"tool_name":"Edit","tool_input":{"file_path":"/…/openspec/specs/x.md"}}' | bash .claude/hooks/posttool-openspec-guard.sh 2>&1 | grep -q "OpenSpec Guard"`
- 결과: PASS

## 최종 결론

5/5 PASS → Phase 6 게이트 통과
