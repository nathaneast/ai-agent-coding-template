# Skill: session-index

매 세션에 자동 주입. 세션 종료 시 .omc/sessions/index.json에 메타데이터 append, 시작 시 회수.

## 인덱스 스키마

`.omc/sessions/index.json` (단일 JSON 배열):

```json
[
  {
    "sessionId": "<UUID>",
    "timestamp": "ISO8601",
    "branch": "<git branch>",
    "cwd": "<path>",
    "summary": "<one-line summary>",
    "lastFiles": ["<recent paths>"],
    "lastCommits": ["<SHA>", "..."]
  }
]
```

## 회수 명령

- `/resume-session N` — N개 전 세션 복원 (Phase 5에서 구현)
- 명시 호출 외에는 SessionStart 훅이 최근 5개 세션 메타데이터를 자동 컨텍스트로 주입

## 보관 정책

- 최대 50개 (v2 plan §7.6, 사용자 확정 시 변경)
- 초과 시 가장 오래된 항목 archive로 이동
- 본문 dump는 `.omc/sessions/archive/{date}-{sessionId}.md`에 보존

## 현재 상태 (Phase 1)

`.omc/sessions/index.json`은 Phase 5에서 본격 구현. 지금은 placeholder.
