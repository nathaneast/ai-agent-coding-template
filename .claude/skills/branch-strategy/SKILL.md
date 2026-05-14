# Skill: branch-strategy

매 세션에 자동 주입. 이 프로젝트의 git 브랜치 규칙을 기억한다.

## 강제 규칙

- **dev 브랜치만 사용**: 모든 작업, 커밋, 푸시는 `dev` 브랜치에서만.
- **main 직접 커밋 금지**: `main`은 dev → main 승격 병합으로만 갱신.
- **Task 단위 즉시 커밋**: Task 완료 직후 즉시 커밋. 여러 Task 변경 누적 금지.
- **품질 게이트**: dev → main 승격 전 `lint`, `typecheck`, 핵심 테스트 통과 필수.

## 위반 시

- `git commit` 또는 `git push` 실행 전 `git branch --show-current` 확인
- `main` 브랜치라면 `git checkout dev` 후 진행
- 의심스러우면 사용자에게 확인

## 환경 분리

- 환경: `dev`(개발), `prod`(운영)
- Vercel/Supabase 모두 dev/prod 2개 프로젝트로 분리
- local/dev 환경 실행 시 좌상단 환경 뱃지 UI 노출
