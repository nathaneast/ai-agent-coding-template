---
description: 세션 컨텍스트 스냅샷 저장 → 다음 세션 자동 회수 (cc --continue 대안)
allowed-tools: Bash, Read, Write, Edit
---

# /ss-re — Session Save & Resume v2

`.omc/snapshot.md`에 현재 세션 컨텍스트 스냅샷 저장. 다음 세션 시작 시 SessionStart hook이 24h 이내면 자동 inject하고 Claude 첫 응답에서 `[yes / show / no]` 묻기로 복원.

## 자동 vs 수동
- **자동 (Stop hook)**: 5분 throttle로 frontmatter만 갱신, body 미작성. 응답 종료마다 백그라운드 동작.
- **수동 `/ss-re`**: body까지 4섹션 압축 작성. **세션 종료 직전 권장**.

## 실행 절차 (Claude main이 수행)

### Step 1 — frontmatter 작성 (객관 메타)
```bash
PLUGIN_LIB="$HOME/.claude/plugins/nathaneast-aiacht/plugin/claude/hooks/lib"
[[ -d "$PLUGIN_LIB" ]] || PLUGIN_LIB="plugin/claude/hooks/lib"
bash "$PLUGIN_LIB/snapshot-meta.sh" "$PWD" "$PWD/.omc/snapshot.md" "false"
```
ts, branch, last_commit, files_changed, active_mode 자동 기록.

### Step 2 — Read `.omc/snapshot.md`로 frontmatter 확인

### Step 3 — Edit으로 본문 4섹션 작성

본문 템플릿이 이미 들어 있음. 다음 4섹션을 실제 내용으로 채울 것:

```markdown
## 작업 (Now)
<현재 세션 작업 1~2줄. "X 기능 구현 중, Y 단계까지 완료" 식 구체.>

## 진행 (Done)
- <완료 항목 1>
- <완료 항목 2>
- <완료 항목 3>

## 다음 즉시 단계 (Next)
1. <즉시 실행 가능한 첫 단계 — 명령 또는 자연어>
2. <두 번째 단계>
3. <세 번째 단계>

## 블로커 (Blockers)
- <사용자 결정/외부 의존 대기 항목. 없으면 "없음">

## 다음 세션 권장 첫 명령
`<사용자가 "yes" 답 시 즉시 실행할 명령 또는 자연어 한 줄>`
```

### Step 4 — 사용자에게 결과 출력 (5~7줄)

```
✅ Snapshot 저장 완료
📍 .omc/snapshot.md (ts: <ISO ts>, branch: <branch>)
⏱ 24h 이내 다음 세션 시작 시 SessionStart hook이 자동 inject
📋 작업: <Now 1줄>
➡ 다음: <Next 1번 한 줄>
```

## 회수 동작 (참고)

SessionStart hook이 자동 처리:
1. `.omc/snapshot.md` 존재 + ts 24h 이내 → inject (헤더에 경과 시간 명시)
2. 24h 초과 → `.omc/snapshots/expired-{ts}.md`로 archive + inject 안 함
3. inject 시 본 SKILL 지시에 따라 Claude 첫 응답에서 `[yes / show / no]` 묻기

## 자연어 트리거

"스냅샷 저장", "세션 저장하고 종료", "ss-re" 등 자연어도 본 명령 자동 수행.

## 인자

`$ARGUMENTS` — (옵션) 사용자가 강조하고 싶은 컨텍스트 추가 메모. 본문 Now/Next 작성 시 참고.

---

User invoked `/ss-re`:

$ARGUMENTS
