---
description: 이 세션에서 작업한 파일만 커밋 + 현재 브랜치에 푸시
allowed-tools: Bash, Read
---

# /cp — Commit + Push (this session only)

**이 대화 세션에서 변경한 파일들만** 커밋하고 현재 브랜치에 푸시합니다.

## 실행 순서

### 1. 커밋 단계
**`/cm` 의 1~5단계 그대로 수행.** 세부 절차는 `~/.claude/commands/cm.md` 참조:
- 세션에서 Edit/Write/MultiEdit한 파일 목록 추출
- 세션 외 dirty 파일 분리 표시 (절대 자동 추가 금지)
- 사용자 확인 표시
- **커밋 메시지는 항상 대화 맥락에서 자동 생성** (인자 무시)
- 명시 파일만 `git add` 후 커밋

### 2. 현재 브랜치 확인
```bash
git rev-parse --abbrev-ref HEAD
```
- main / master 직접 푸시면 → **사용자에게 한번 확인** ("main에 직접 푸시하시겠어요?")
- 보통 `dev`에서 작업한다고 가정

### 3. 푸시
```bash
git push
```
- upstream 미설정 시 → `git push -u origin <branch>`
- 푸시 실패 (non-fast-forward 등) 시:
  - **자동 force push 절대 금지**
  - 사용자에게 원인 설명 후 `git pull --rebase` 시도할지 물어봄

### 4. 결과 보고
- 커밋 해시
- 푸시된 브랜치 (origin/<branch>)
- GitHub PR 링크가 메시지에 떴으면 그대로 표시
- 다음 단계 힌트:
  - dev에서 push한 경우 → "stage/main까지 올리려면 `/cp-sm`"
  - 다른 브랜치면 → "PR 만들려면 `gh pr create --base dev`"

## 주의사항

- `--force` / `--force-with-lease` **사용자 명시 요청 없으면 금지**.
- 푸시 전에 pre-push 훅이 있으면 그대로 실행. 실패하면 원인 보고 후 수정.
- 원격 미설정 (`origin` 없음) 시 → `/gi` 부터 실행하라고 안내.
- 인증 실패 시 → `gh auth status` / `git remote -v` 결과 보여주고 사용자가 처리하게.

## 사용 예

```
/cp    # 항상 자동 메시지로 커밋 + 푸시 (인자 받지 않음)
```
