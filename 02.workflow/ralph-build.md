# Ralph Build SOP

`/build "<PRD>"` 호출 시:

1. PRD가 01.spec/prd-*.md 로 기록
2. ralph 무인 모드 시작 (사용자 부재 OK)
3. 매 iteration 후 scripts/build-iteration-gate.sh 실행:
   - dev 브랜치 확인
   - Task 단위 커밋 (<=5 uncommitted)
   - 테스트 존재 + 통과
   - 커밋 메시지 prefix 표준
4. 게이트 통과 시 다음 Task 진행
5. /consensus 합의 도달 시 확정 + 커밋
6. 모든 Task 완료 + Architect 검증 → /oh-my-claudecode:cancel

## 무인 모드 안전장치
- Codex 장애 시 3단 폴백 (critic 대체 → pause + USER_CONFIRM_NEEDED 마커)
- max-hours 옵션
- ralph stop hook의 자동 재시작 의존
