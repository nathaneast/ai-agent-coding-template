# Phase 5.0 — Claude Code --resume 실측 (보류)

- 사용자 부재 중 실측 불가
- 대안: 시나리오 B(archive 본문 SessionStart 주입) 우선 구현
- 사용자 복귀 후 `--resume <sessionId>` 임의 과거 세션 작동 여부 1회 검증 필요
- 작동 시: 시나리오 A 분기 (단순 안내)도 같이 사용 가능
- 미작동 시: 시나리오 B만 사용 (이미 구현됨)

## 검증 명령 (사용자 직접 실행)

```bash
# 1. 현재 세션의 sessionId 확인 (Claude Code 표시 영역 또는 .claude/projects/<repo>/<sessionId>.jsonl)
ls .claude/projects/-Users-nathaneast-Desktop-coding-project-ai-agent-coding-template/

# 2. 임의 과거 sessionId 선택 후 --resume
claude --resume <sessionId>

# 3. 정상 컨텍스트 복원되면 시나리오 A PASS
# 미작동/오류 시 시나리오 B만 사용 (자동 fallback)
```
