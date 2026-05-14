# /push-global-memory

본 하네스의 `plugin/memory/user/` 글로벌 메모리를 git push로 전파. 다른 PC는 `update.sh`로 동기화.

## 실행

`bash ~/.claude/plugins/nathaneast-aiacht/scripts/push-global-memory.sh`

또는 본 레포 직접 작업 중이면:
`bash scripts/push-global-memory.sh`

## 파이프라인 (3단계 트랜잭션)

1. **STAGE**: pre-flight 검사 (memory/ 외 변경 abort), fetch + pull --rebase, `git add plugin/memory/user/`
2. **COMMIT**: auto-generated 메시지로 commit
3. **PUSH**: yunjadong-team (ground truth) → nathaneast (--force-with-lease 미러) → ls-remote 검증

## 결과

성공: "X개 메모 push됨, Y개 변경. 다른 PC: bash update.sh"
실패: 단계별 롤백 안내.

## 비고

- 사적 정보·시크릿 절대 금지 (memory-write-guard.sh가 1차 차단)
- 충돌 시 yunjadong-team이 ground truth, nathaneast는 강제 덮어쓰기
- 자동 push X — 명시 호출만
