# nathaneast-ai-agent-coding-template

> 개인 AI 코딩 하네스 — Claude Code (+ Codex) 글로벌 도구 + 프로젝트 템플릿

## 핵심

- **글로벌 SessionStart 훅**: 매 세션 5 스킬 자동 컨텍스트 주입 (마커 있는 프로젝트만)
- **`/pjt-init`**: 새 프로젝트에 01.spec ~ 05.tasks + openspec 폴더 생성
- **`/merge-skill <path>`**: 로컬 스킬을 글로벌 본 레포로 promote + 자동 commit
- **`/mirror-personal`**: 개인 GitHub 계정에 미러 푸시
- **9개 슬래시 커맨드 + 13 스킬 + 45 bats 테스트**

## 설치

```bash
curl -fsSL https://raw.githubusercontent.com/yunjadong-team/nathaneast-ai-agent-coding-template/main/install.sh -o /tmp/install.sh
bash /tmp/install.sh
```

설치 위치: `~/.claude/plugins/nathaneast-aiacht/`
글로벌 settings.json에 SessionStart 훅 자동 등록.

## 사용

```bash
# 새 프로젝트 시작
mkdir ~/projects/my-app && cd ~/projects/my-app
claude   # Claude Code 시작 → 안에서 /pjt-init 호출
# 01.spec/ ~ 05.tasks/ + openspec/ + .harness-active 마커 자동 생성

# 다음 세션부터 SessionStart 훅이 5 스킬 자동 주입
```

## 업데이트

```bash
bash ~/.claude/plugins/nathaneast-aiacht/scripts/update.sh
# git pull --ff-only로 글로벌 도구 최신화
```

## 스킬 공유 (역전파)

```bash
# A 프로젝트에서 만든 스킬을 글로벌 + 다른 PC와 공유
/merge-skill ~/projects/A-app/.claude/skills/awesome
# → 글로벌 promote + git commit
git -C ~/.claude/plugins/nathaneast-aiacht push origin main

# 또는 한번에:
/merge-skill ~/projects/A-app/.claude/skills/awesome --push
```

## 개인 GitHub 미러

```bash
/mirror-personal
# 회사 레포 → 개인 레포 동시 동기화
```

## 구조

- `plugin/` — 글로벌 설치 대상 (스킬/훅/커맨드/룰)
- `templates/project-init/` — `/pjt-init`이 새 프로젝트에 복사할 컨텐츠
- `scripts/` — install, update, pjt-init, merge-skill, mirror-personal 등
- `.omc/plans/` — v0.2.0 plan 보존

## License

MIT
