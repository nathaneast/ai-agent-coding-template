# Feedback Log

> 사용자가 작업 중 누적시키는 피드백 / 불만 / 개선 요청.
> 추후 resolver 도구(예: `/fdb-resolve`)가 이 로그를 읽어 미해결 항목을 자동 해소 시도한다.

## 형식

각 entry 1줄:

```
- [<ISO8601-UTC>] <free text>. _hash_: <short> _status_: open
```

- `status: open` → 미해결 (resolver 대상)
- `status: resolved` → 해결 완료
- `status: dropped` → 폐기 (적용 불필요로 판단)

## 적재 방법

1. 자연어: 대화 중 "이거 피드백에 저장해", "피드백에 추가", "feedback에 저장" 등 표현 → Claude가 자동 캡처
2. 슬래시 커맨드: `/fdb <자연어>` → 즉시 append
3. 직접 편집도 허용 (위 형식 준수)

## Entries

<!-- entries are appended below by feedback-add.sh -->
