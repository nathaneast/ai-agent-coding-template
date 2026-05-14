# Session Index Schema

`.omc/sessions/index.json` — JSON 배열 (최대 50개 항목, 초과 시 가장 오래된 항목 archive 이동)

## 항목 스키마

```json
{
  "sessionId": "UUID 또는 timestamp 기반 ID",
  "timestamp": "ISO8601 종료 시각",
  "branch": "dev",
  "cwd": "/repo/path",
  "summary": "이 세션의 핵심 작업 1줄 요약",
  "lastFiles": ["변경/생성된 마지막 5개 파일 경로"],
  "lastCommits": ["SHA1", "SHA2", "..."],
  "archivePath": ".omc/sessions/archive/2026-05-14-<sessionId>.md",
  "promptCount": 0,
  "toolUseCount": 0
}
```

## archive 본문

`.omc/sessions/archive/<YYYY-MM-DD>-<sessionId>.md` — 풍부한 본문 dump:
- 세션 시작 시각
- 사용자 프롬프트 첫 줄 + 마지막 줄
- 변경 파일 전체 목록
- 커밋 본문
- 결정 요약
- (선택) 마지막 사용자 메시지 발췌

## /resume-session N 알고리즘

1. `.omc/sessions/index.json` 마지막 N번째 항목 추출 (N=1이면 가장 최근)
2. 시나리오 A (사용자 사전 검증 시): `archivePath`의 sessionId로 `claude --resume <id>` 안내
3. 시나리오 B (기본): `archivePath` 본문을 새 Claude 세션 SessionStart 훅에 inject_section으로 자동 주입

## 보관 정책

- 최대 50개 항목 (사용자 결정 시 변경)
- 초과 시 가장 오래된 항목의 인덱스 entry만 삭제. archive 본문은 보존.
- archive 본문은 365일 후 압축 (Phase 9+ RFC)
