# Learnings: Pitfalls

> 과거 경험한 함정 / 실패 패턴 / 재발 방지 메모.

## 예시
- 세션 종료 후 2~3개 전 세션 복원 어려움 (problem.md). _Why_: Claude Code `--continue`는 바로 전만. _When_: 장기 작업 중 세션 종료 시. _Fix_: Phase 5 `/resume-session` + `.omc/sessions/index.json`.
