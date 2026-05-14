---
description: 깃 이닛 + 프라이빗 GitHub 레포 생성 + dev/stage/main 브랜치 셋업
allowed-tools: Bash, Read, Write
---

# /gi — Git Init + Private Repo + Branches

현재 디렉토리를 git 저장소로 초기화하고, **프라이빗** GitHub 레포로 만들고, `main` / `stage` / `dev` 세 브랜치를 모두 생성합니다.

## 실행 순서

### 0. 사전 점검
1. 현재 디렉토리가 이미 git 레포인지 확인 (`git rev-parse --is-inside-work-tree`)
   - 이미 레포면 → 사용자에게 알리고 **확인 받은 뒤** 진행 (강제 init 금지)
2. `gh` CLI 인증 상태 확인 (`gh auth status`)
   - 미인증 시 → 사용자에게 `gh auth login` 안내 후 중단
3. 레포 이름 결정:
   - 인자 `$ARGUMENTS`가 있으면 그걸 사용
   - 없으면 현재 디렉토리 이름 (`basename`) 사용
   - **사용자에게 한번 확인** ("`<이름>` 으로 프라이빗 레포 만들까요?")

### 1. Git 초기화
```bash
git init -b main
```
이미 init되어 있으면 스킵.

### 2. 첫 커밋 준비
- `.gitignore` 없으면 OS/언어에 맞는 기본 템플릿 생성
- `README.md` 없으면 한 줄짜리 (`# <repo-name>`) 생성
- `git add .gitignore README.md` (다른 파일은 사용자가 의도하지 않게 같이 올라가지 않도록 명시 추가만)
- `git commit -m "chore: initial commit"`

### 3. 프라이빗 GitHub 레포 생성 + 연결 + 푸시
```bash
gh repo create <name> --private --source=. --remote=origin --push
```
실패 시 (이미 같은 이름의 레포 존재 등) 사용자에게 메시지 그대로 전달.

### 4. 브랜치 생성 (main → stage → dev 순)
```bash
git checkout -b stage
git push -u origin stage

git checkout -b dev
git push -u origin dev
```

### 5. 기본 작업 브랜치는 dev
- `dev` 브랜치에 머문 상태로 종료
- 원격 default branch는 main 그대로 유지 (배포용)

### 6. 완료 보고
- 생성된 레포 URL (`gh repo view --web --json url -q .url` 또는 `gh repo view`)
- 현재 브랜치 (`dev`)
- "이제 작업하고 `/cp`로 커밋푸시하시면 됩니다" 안내

## 주의사항

- **프라이빗 필수** — `--private` 플래그 절대 빠뜨리지 말 것.
- **사용자 확인 없이 force-push 금지**, 이미 있는 origin 덮어쓰기 금지.
- 인증 실패/네트워크 실패 시 명확한 에러 메시지로 중단. 자동 재시도하지 말 것.
- 사용자가 이미 다른 origin을 셋업한 상태면 덮어쓰지 말고 알려준다.

## 사용 예

```
/gi                    # 디렉토리 이름으로 레포 생성
/gi my-project         # "my-project" 이름으로 레포 생성
```
