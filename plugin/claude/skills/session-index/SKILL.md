# Skill: session-index

매 세션 자동 주입. 세션 종료 시 `.omc/sessions/index.json` append + archive 본문 dump. 시작 시 최근 5개 메타 회수.

## 인덱스 스키마

`.omc/sessions/index.json` (JSON 배열, 최대 50개):
```json
[
  {
    "sessionId": "UUID",
    "timestamp": "ISO8601",
    "branch": "dev",
    "cwd": "/path",
    "summary": "한 줄 요약",
    "lastFiles": ["변경 파일들"],
    "lastCommits": ["SHA"],
    "archivePath": ".omc/sessions/archive/2026-05-14-<sessionId>.md"
  }
]
```

상세 스키마: `.omc/sessions/SCHEMA.md` 참조.

## 회수 명령

- `/resume-session N` — N개 전 세션 복원 (Phase 5 구현 완료)
- 자동: SessionStart 훅이 최근 5개 메타데이터를 자동 컨텍스트로 주입 (Phase 1부터)

## /resume-session 분기 (problem.md 해결)

### 시나리오 A: Claude Code --resume 작동 (사용자 사전 검증 시)
```bash
SID=$(jq -r ".[-${N}].sessionId" .omc/sessions/index.json)
echo "Run: claude --resume $SID"
```

### 시나리오 B: archive 본문 system prompt 주입 (기본)
새 Claude 세션의 SessionStart 훅이 다음을 자동 inject:
- `.omc/sessions/archive/<date>-<sessionId>.md` 본문 전체
- "이 세션은 N개 전 세션의 컨텍스트를 복원했습니다" 헤더

## 보관 정책

- 최대 50개 인덱스 항목, 초과 시 가장 오래된 entry 삭제 (archive 본문은 보존)
- archive 본문: `_archive_compressed.md`로 365일 후 압축 (Phase 9+ RFC)

## 부트스트랩 후 동작

Phase 5 완료 후 본격 활성. 사용자는 `/resume-session 1`로 직전 세션, `/resume-session 5`로 5개 전 세션 복원.
