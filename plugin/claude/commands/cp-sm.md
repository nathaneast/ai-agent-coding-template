---
description: 커밋푸시 후 stage/main 브랜치로 병합하고 모두 푸시 (배포 승격)
allowed-tools: Bash, Read
---

# /cp-sm — Commit + Push + Stage/Main 병합 푸시

`/cp` 를 실행한 뒤, 현재 브랜치(보통 `dev`)를 `stage` 와 `main` 으로 차례로 병합하고 각각 푸시합니다. **배포 승격(promotion) 워크플로우.**

## 실행 순서

### 1. /cp 실행 (커밋 + 현재 브랜치 푸시)
- `~/.claude/commands/cp.md` 절차 그대로 따라 커밋 + 푸시
- **커밋 메시지는 항상 대화 맥락에서 자동 생성** (인자 무시)
- 커밋할 변경사항이 없으면 → 메시지만 출력하고 다음 단계로 넘어감 (병합은 진행)

### 2. 시작 브랜치 기억
```bash
START_BRANCH=$(git rev-parse --abbrev-ref HEAD)
```
- 보통 `dev` 가정. main/master면 **에러로 중단** ("이미 main입니다. /cp-sm 은 dev → stage → main 승격용입니다.")

### 3. 사용자 확인 (중요)
다음 메시지로 명시적 컨펌 받는다:
```
🚀 배포 승격 진행:
  dev → stage → main

다음 동작을 수행합니다:
  1. stage 체크아웃, dev 병합, 푸시
  2. main 체크아웃, stage 병합, 푸시
  3. dev 로 복귀

진행할까요? (yes/no)
```
- yes 아니면 중단

### 4. stage 로 승격
```bash
git fetch origin
git checkout stage
git pull --ff-only origin stage          # 원격 최신 상태 동기화
git merge --ff-only $START_BRANCH        # fast-forward only — 한 줄 그래프 유지
git push origin stage
```
- merge conflict 발생 시:
  - **자동 해결 시도 금지**
  - 사용자에게 충돌 파일 보여주고 해결 요청
  - 해결 전까지 main 단계로 진행 안 함
- **ff-only 실패 시** (stage 에 dev 가 ancestor 가 아닌 별도 commit 존재):
  - branch-strategy 위반 (stage 에 직접 commit 금지)
  - 자동 폴백 X — 사용자에게 알리고 중단

### 5. main 으로 승격
```bash
git checkout main
git pull --ff-only origin main
git merge --ff-only stage                # fast-forward only
git push origin main
```
- 동일하게 충돌/ff-only 실패 시 사용자 개입 필요.

### 6. 시작 브랜치로 복귀
```bash
git checkout $START_BRANCH
```

### 7. 결과 보고
```
✅ 승격 완료
  dev:   <커밋해시> 푸시됨
  stage: <병합커밋해시> 푸시됨
  main:  <병합커밋해시> 푸시됨

현재 브랜치: dev
```
- main에 머지된 시점의 GitHub URL 표시 (`gh browse`)

## 주의사항

- **stage 또는 main 브랜치가 없으면** → 에러 메시지 + `/gi` 실행 안내. 자동 생성하지 말 것 (의도하지 않은 배포 위험).
- **--ff-only 풀** — 원격에 다른 사람 커밋이 있으면 일반 pull로 추가 머지 커밋 만들지 말고, 사용자에게 알린다.
- **--ff-only 머지** — main/stage 히스토리가 한 줄로 유지되도록 fast-forward 만 허용. branch-strategy.md 가 stage/main 에 직접 commit 금지하므로 정상 운영에선 항상 ff 가능. ff 불가 시 정책 위반 신호이므로 fail-loud (자동 --no-ff 폴백 금지).
- **force push 절대 금지.** (단 사용자가 명시 요청 시 `--force-with-lease` 만 사용)
- **CI/CD 트리거** — main 푸시는 보통 프로덕션 배포 트리거. 사용자가 yes 입력해도 한번 더 "정말 main까지 가도 되나요?" 묻고 싶으면 묻는다 (시간대가 야간/주말이면 특히).
- 충돌 해결 후 재시도는 `/cp-sm` 다시 실행하지 말고, 사용자가 수동으로 충돌 해결 → `git add` → `git commit` → 남은 단계만 이어서.

## 사용 예

```
/cp-sm    # 항상 자동 메시지로 dev 커밋푸시 + stage/main 승격 (인자 받지 않음)
```
