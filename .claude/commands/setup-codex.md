---
description: 이 하네스를 Codex CLI용으로 셋업
---

# /setup-codex

이 하네스의 Codex CLI 측 셋업을 검증/활성화한다.

## 실행 순서

1. `.codex/config.toml` 존재 + `codex_hooks = true` 확인
2. `.codex/hooks.json` jq 검증 + SessionStart/SessionEnd 매처 확인
3. `.codex/hooks/session-start.sh`, `session-end.sh` 실행 권한 + Claude 본체 래퍼 동작 확인
4. `.codex-plugin/plugin.json` jq 검증
5. AGENTS.md 진입점 파일 확인
6. SessionStart 래퍼 1회 시뮬레이션
7. 결과 요약

## 호출

`bash scripts/setup-codex.sh` 실행. 결과는 `04.docs/setup-codex.log`에 기록.
