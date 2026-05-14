---
description: 현재 세션 컨텍스트 스냅샷 저장 → 다음 세션 자동 회수
---

# /ss-re — Session Save & Resume

현재 세션의 작업 컨텍스트를 `.omc/snapshot.md`에 저장. 다음 세션 시작 시 SessionStart 훅이 자동 회수.

## 사용 시점

- MCP/플러그인 권한 변경 후 Claude Code 재시작 필요
- 세팅 수정으로 세션 종료 필요
- 작업 중단하고 다른 일 한 뒤 정확히 같은 자리로 복귀하고 싶을 때
- Claude Code `--continue`로 못 잡는 2~3 세션 전 작업 보존

## 동작

1. 사용자 호출: `/ss-re`
2. Claude가 다음 정보 추출 + `<project>/.omc/snapshot.md`에 저장:
   - **현재 작업**: 1~2줄 요약
   - **진행 상황**: 어디까지 완료
   - **다음 즉시 단계**: 1~3개
   - **변경 파일**: `git status --short` 출력
   - **활성 모드**: ralph/일반
   - **블로커**: 사용자 결정 대기 항목 (있으면)
   - **세션 ID (backup)**: Claude Code `--resume <id>` 용 — 가능하면

3. 결과 출력:
   ```
   ✅ Snapshot 저장됨
   📍 ~/projects/A/.omc/snapshot.md

   요약:
   - 작업: ...
   - 진행: ...
   - 다음: ...
   ```

## 다음 세션 자동 회수

새 Claude Code 세션 시작 시 SessionStart 훅이 `<project>/.omc/snapshot.md` 존재 시 컨텍스트로 inject. Claude가 첫 메시지로:

```
📍 직전 세션 스냅샷 복원했습니다.
- 작업: ...
- 진행: ...
- 다음: ...

그대로 진행할까요? (yes / 변경 / 취소)
```

## 파일 정책

- 단일 파일 (`.omc/snapshot.md`) — 매 `/ss-re` 호출 시 덮어쓰기
- 작업 완료 후 사용자가 `rm .omc/snapshot.md` 직접 또는 다음 `/ss-re` 호출이 덮어씀
- archive 안 함 (단순성)

## 자연어 트리거도 가능

사용자가 "스냅샷 저장해" / "세션 저장하고 종료" 등 자연어로 말해도 Claude가 본 커맨드 동작 자동 수행.
