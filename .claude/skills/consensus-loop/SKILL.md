# Skill: consensus-loop

매 세션에 자동 주입. 모든 설계/개발/QA 작업은 Codex와 합의 루프를 따른다.

## 합의 루프 절차

1. Claude가 작업(설계/코드/테스트 등) 수행
2. `/codex:review --wait` 또는 `/codex:adversarial-review --wait`로 Codex 비판적 리뷰
3. Claude가 리뷰 피드백을 반영하여 수정
4. `/codex:review --wait`로 재리뷰
5. 2~4 반복하여 **둘의 합의가 일치할 때까지** 계속
6. 합의 도달 시 작업 확정 후 다음 단계

## 강제 규칙

- 합의 없이 구현 확정 금지
- Codex 리뷰는 **`codex-plugin-cc` (Skill 도구) 경유**만 허용. MCP 직접 호출 금지.
- `/codex:rescue`(막힌 문제), `/codex:status`, `/codex:result`도 동일 경유

## 부트스트랩 예외 (Phase 0~3)

본격 `/consensus` 인프라가 없는 동안: 슬래시 명시 호출(`/codex:review --wait`)이 임시 합의 경로. 무인 빌드는 금지(사용자 부재 중 합의 누락).

## 커맨드 빠른 참조

- `/codex:review` — 표준 코드 리뷰
- `/codex:adversarial-review` — 설계/접근방식 도전 리뷰
- `/codex:rescue` — 막힌 문제 Codex 위임
- `/codex:status` — 백그라운드 리뷰 진행 상태
- `/codex:result` — 리뷰 결과 확인
