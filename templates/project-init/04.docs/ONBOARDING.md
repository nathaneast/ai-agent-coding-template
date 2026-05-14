# Onboarding — Company Account Clone

본 하네스를 회사 계정으로 복제하여 시작하는 절차.

## 사전 조건
- 개인 계정으로 본 하네스가 운영 중 (personal harness)
- 회사 GitHub 계정에 신규 리포 생성 권한
- 로컬에 git, rsync (또는 cp), jq 설치

## 절차

### 1단계: 클론

```bash
cd /Users/yourname/Desktop/coding_project/ai-agent-coding-template
bash scripts/clone-to-company.sh ~/company-coding/my-new-project
```

자동 처리:
- 개인 git 히스토리 제거 후 새 git init
- `.env*`, `.claude/settings.local.json`, `.omc/state/`, `.omc/logs/`, `.omc/sessions/`, `_history.jsonl`, `_pending.jsonl` 제외
- `_metrics.json` counters 0 reset
- env-guard 자동 설치

### 2단계: 회사 GitHub 연결

```bash
cd ~/company-coding/my-new-project
gh repo create company-org/my-new-project --private --source=. --remote=origin
git push -u origin dev
```

### 3단계: 회사 환경변수 설정

```bash
# 회사 secrets는 본 하네스가 절대 알 수 없도록
cp .env.example .env
# 회사 도구로 직접 편집 (vault, secrets manager 등)
```

## 보안 체크리스트

- [ ] 개인 키/토큰이 어떤 파일에도 포함되지 않음
- [ ] `.gitignore`에 `.env*` 명시
- [ ] `.claude/settings.json` deny에 `Read/Edit/Write(.env*)`
- [ ] 글로벌 settings 인 `~/.claude/settings.json` 도 동일 보호 (`branch-guard.sh` 등)
- [ ] 회사 계정으로 첫 push 전 `git log` 검토하여 잔여 개인정보 없음 확인
