---
description: 피드백을 03.archive/feedback.md에 1줄 append (자연어 인자)
allowed-tools: Bash
---

# /fdb — Feedback Capture

사용자가 입력한 자연어를 `03.archive/feedback.md`에 1줄 entry로 적재합니다. 추후 resolver 도구가 `status: open` 항목을 읽어 자동 해결을 시도합니다.

## 인자

- `$ARGUMENTS` — 자유 텍스트 (한국어/영어 무관). 예:
  - `/fdb 토스트가 너무 빨리 사라진다`
  - `/fdb sidebar의 다크모드 색감 어색함, 좀 더 채도 낮춰야 함`

## 실행

```bash
PLUGIN_LIB="$HOME/.claude/plugins/nathaneast-aiacht/plugin/claude/hooks/lib"
[[ -d "$PLUGIN_LIB" ]] || PLUGIN_LIB=".claude/hooks/lib"  # 로컬 폴백
bash "$PLUGIN_LIB/feedback-add.sh" "$ARGUMENTS"
```

## 결과 보고

다음을 출력:
1. 적재 완료 메시지 (`added → 03.archive/feedback.md (open: N, hash: ...)`)
2. 현재 open 항목 수
3. 한 줄 안내: "resolver는 추후 `/fdb-resolve`로 호출"

## 주의

- `$ARGUMENTS`가 비어있으면 사용자에게 "어떤 피드백을 저장할지" 물어본다 (절대 빈 entry 추가 금지).
- 줄바꿈은 자동으로 공백으로 정규화됨 (entry는 항상 1줄).
- 시크릿/토큰 의심 문자열(`sk-`, `xoxb-`, `ghp_` 등) 감지 시 저장 전 사용자 확인.
