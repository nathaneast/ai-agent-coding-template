# Skill: feedback-capture

대화 중 사용자가 피드백 저장 의도를 표현하면 즉시 `03.archive/feedback.md`에 적재한다.

## 트리거 (자연어)

다음 표현 중 하나라도 감지되면 → feedback-add.sh 호출:

- "이거 피드백에 저장해"
- "피드백에 저장", "피드백에 추가", "피드백에 쌓아"
- "feedback에 저장", "feedback에 추가", "save to feedback"
- "fdk 저장", "fdk로 남겨"

명시 호출: `/fdk <자연어>` 슬래시 커맨드.

## 동작

1. 트리거 감지 시 **대상 텍스트 추출**:
   - "이거" / "위 내용" / "방금 그거" → 직전 대화 컨텍스트에서 명확한 1문장 추출
   - 트리거 뒤에 텍스트가 따라오면 (예: "피드백에 저장: X가 너무 빠름") → 그 텍스트 사용
   - 모호하면 사용자에게 "어떤 내용을 저장할까요? 한 문장으로 확인 부탁드립니다." 라고 묻고 대기
2. 추출된 텍스트로 다음 실행:
   ```bash
   bash $HOME/.claude/plugins/nathaneast-aiacht/plugin/claude/hooks/lib/feedback-add.sh "<텍스트>"
   ```
3. 결과(open 카운트, hash) 사용자에게 1줄 보고

## 형식 규약

각 entry는 1줄:
```
- [<ISO8601-UTC>] <text>. _hash_: <12-char> _status_: open
```

`status` 값: `open` (기본) / `resolved` / `dropped`

## resolver 연계 (추후)

`status: open` 항목을 읽어 자동 해결을 시도하는 도구(`/fdk-resolve` 가칭)가 추가될 예정. 이 스킬은 데이터 적재만 담당.

## 안전 규칙

- 빈 텍스트로 호출 금지
- 시크릿 의심 패턴(`sk-`, `xoxb-`, `ghp_`, `AKIA`, JWT 형식) 감지 시 적재 전 사용자 확인
- entry 형식 위반 금지 (1줄, 정해진 필드 순서)
