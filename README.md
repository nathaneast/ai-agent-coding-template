# nathaneast-ai-agent-coding-template

> 개인 AI 코딩 하네스 — Claude Code (+ Codex CLI) 글로벌 도구 + 프로젝트 템플릿
>
> 한 번 설치하면 모든 컴퓨터에서 동일한 워크플로우로 작업 가능.

---

## 한눈에 보기

```
[설치 1회] curl install.sh → ~/.claude/plugins/nathaneast-aiacht/
            └─ 글로벌 SessionStart 훅 자동 등록
            └─ ~/.claude/CLAUDE.md에 메모리 룰 자동 append

[새 프로젝트] /pjt-init  →  6개 폴더 + CLAUDE.md + .claude/CLAUDE.local.md + .harness-active 마커 생성
                          ↓
              다음 세션부터 SessionStart 훅이 5 스킬 자동 컨텍스트 주입

[일상 작업] 16개 슬래시 커맨드 + 14 스킬 + native memory("저장해") + /ss-re 스냅샷 + /solo 자율 실행

[스킬 공유] /merge-skill <path> --push  →  글로벌 레포에 promote → 다른 PC update.sh로 동기화

[회사 ↔ 개인] yunjadong-team (메인) ←  /mirror-personal  →  nathaneast (백업)
```

---

## 1. 설치 (1회, 모든 컴퓨터)

```bash
curl -fsSL https://raw.githubusercontent.com/yunjadong-team/nathaneast-ai-agent-coding-template/main/install.sh -o /tmp/install.sh
bash /tmp/install.sh
```

- 설치 위치: `~/.claude/plugins/nathaneast-aiacht/`
- 글로벌 `~/.claude/settings.json`에 SessionStart 훅 자동 등록 (`.bak` 백업 포함)
- 글로벌 `~/.claude/CLAUDE.md`에 메모리 분기 룰 자동 append (idempotent)
- 권한 prompt 없이 작동하려면 글로벌 settings `"defaultMode": "bypassPermissions"` 권장

---

## 2. 새 프로젝트 시작

```bash
# 새 프로젝트 디렉토리 만들기
mkdir ~/projects/my-app && cd ~/projects/my-app

# Claude Code 시작
claude

# Claude Code 안에서 슬래시 커맨드 호출
/pjt-init
```

**`/pjt-init` 호출 후 로컬 프로젝트 최상위에 자동 생성**:

```
~/projects/my-app/
├── 01.spec/                    ← PRD, ADR, 유저 스토리
├── 02.workflow/                ← SOP
├── 03.archive/                 ← 완료 작업 아카이브
├── 04.docs/                    ← RUNBOOK, RELEASE_NOTES, HANDOFF
├── 05.tasks/                   ← todo.md, prompt.md, feedback.md
├── openspec/                   ← 명세 워크플로우
├── CLAUDE.md                   ← 프로젝트 메모리 (git 추적, "저장해" 트리거)
├── .claude/CLAUDE.local.md     ← 개인 메모리 (gitignore, "내 PC에만" 트리거)
├── .harness-active             ← SessionStart 훅 활성화 마커
└── .gitignore                  ← .env + CLAUDE.local.md + snapshot.md 제외
```

> **중요**: 폴더는 **로컬 프로젝트 최상위에 직접** 생성됩니다. 본 레포의 `templates/project-init/`은 *글로벌 도구가 보관하는 원본 위치*일 뿐, 사용자 프로젝트로 복사될 때는 최상위로 펼쳐집니다.

다음 세션부터 글로벌 SessionStart 훅이 `.harness-active` 감지하여 5 스킬 자동 주입.

---

## 3. 16개 슬래시 커맨드

### 환경 셋업 (4)
| 커맨드 | 설명 |
|--------|------|
| `/pjt-init` | 새 프로젝트에 6 폴더 + CLAUDE.md + .claude/CLAUDE.local.md + 마커 + .gitignore 생성 |
| `/setup-claude` | Claude Code 측 셋업 검증 (settings.json, hooks, 5 스킬 등) |
| `/setup-codex` | Codex CLI 측 셋업 검증 (config.toml, hooks.json) |
| `/setup-both` | 양쪽 동시 검증 + diff (identical 보장) |

### 세션 보존 (1)
| 커맨드 | 설명 |
|--------|------|
| `/ss-re` | 현재 세션 컨텍스트 스냅샷 → `.omc/snapshot.md` 저장 → 다음 세션 자동 회수 |

### 일상 워크플로우 (1)
| 커맨드 | 설명 |
|--------|------|
| `/dbck <지시>` | 사용자 지시를 5요소(목표/범위/수용/제약/위험)로 분해 + 더블체크 |

### 자율 실행 (2) — v0.5 신규
| 커맨드 | 설명 |
|--------|------|
| `/solo "<작업>"` 또는 `/solo --spec <md>` | **1~10시간 무인 자율 실행**. planner가 완료조건 자동 도출 → Codex 합의 → 실행 루프 → 검증 → commit. critical 100% 의무 + 80% graceful exit + 비용 cap $20 자동 다운그레이드 |
| `/pg` | `/solo` 진행 상황 즉시 출력 (phase / criteria 통과율 / 비용 / 예상 종료) |

### 피드백 (1)
| 커맨드 | 설명 |
|--------|------|
| `/fdb <자유 텍스트>` | 자연어 피드백을 `03.archive/feedback.md`에 1줄 append (resolver가 후속 자동 해결 시도) |

### Git + 배포 (4) — 새 프로젝트에서 일상 사용
| 커맨드 | 설명 |
|--------|------|
| `/gi [name]` | git init + private GitHub 레포 생성 + `main`/`stage`/`dev` 브랜치 셋업 |
| `/cm` | **이 세션에서 변경한 파일만** 커밋 (메시지 자동 생성, 푸시 안 함) |
| `/cp` | `/cm` + 현재 브랜치 푸시 |
| `/cp-sm` | `/cp` + `dev → stage → main` 승격 병합 푸시 (배포 트리거) |

### 스킬 공유 — 역전파 (2)
| 커맨드 | 설명 |
|--------|------|
| `/merge-skill <path>` | 로컬 스킬을 글로벌 본 레포에 promote + 자동 commit |
| `/merge-skill <path> --push` | promote + commit + `git push origin main` 한번에 |
| `/mirror-personal` | yunjadong-team 레포 → nathaneast 레포 미러 푸시 |

### 메모리 동기화 (1)
| 커맨드 | 설명 |
|--------|------|
| `/push-global-memory` | `plugin/memory/user/` 글로벌 메모를 yunjadong-team(메인) + nathaneast(미러) 양쪽 push. 다른 PC는 `update.sh`로 동기화 |

---

## 4. 14개 스킬

### 자동 주입 (5개, 매 세션 SessionStart)
- `branch-strategy` — git 브랜치 룰
- `tdd-loop` — TDD 워크플로우
- `consensus-loop` — Codex 합의 루프 + 3단 폴백
- `env-security` — .env 보안 절대 규칙
- `ss-re` — 세션 스냅샷 저장/회수

### 명시 호출 (9개)
- `solo` (v0.5) — `/solo` 슬래시의 7 phase 자율 실행 본체 (분석→완료조건→합의→실행→검증→커밋→보고)
- `user-helper` — 사용자 비효율 자동 감지 후 1줄 제안
- `feedback-capture` — `/fdb` 자연어 피드백 적재 파이프라인
- `double-check`, `merge-skill`
- `openspec-propose`, `openspec-explore`, `openspec-apply`, `openspec-archive`

---

## 5. 회사 PC ↔ 개인 PC 동기화 흐름

```
[개인 PC A 프로젝트]
~/projects/A-app/.claude/skills/
├── Q/SKILL.md  ← 실험적으로 만듦
├── W/SKILL.md
└── E/SKILL.md
     │
     │ /merge-skill ~/projects/A-app/.claude/skills/Q --push
     │ /merge-skill ~/projects/A-app/.claude/skills/W --push
     │ /merge-skill ~/projects/A-app/.claude/skills/E --push
     ▼
[개인 PC 글로벌] ~/.claude/plugins/nathaneast-aiacht/plugin/claude/skills/
+ Q/W/E 복사 + 3 커밋 + git push origin main
     │
     ▼
[GitHub] yunjadong-team/nathaneast-ai-agent-coding-template (메인)
     │
     │ (선택) /mirror-personal
     │   → nathaneast/nathaneast-ai-agent-coding-template (백업)
     │
[회사 PC] bash ~/.claude/plugins/nathaneast-aiacht/scripts/update.sh
     │  ← git pull --ff-only
     ▼
[회사 PC 글로벌] Q/W/E 동기화됨
     │
     ▼
다음 Claude Code 세션 SessionStart 훅이 Q/W/E 자동 컨텍스트 주입
```

### 명령 요약
```bash
# 개인 PC: 새 스킬 promote + push
/merge-skill ~/projects/A-app/.claude/skills/awesome --push

# (선택) 개인 GitHub 미러
/mirror-personal

# 회사 PC: 동기화
bash ~/.claude/plugins/nathaneast-aiacht/scripts/update.sh
```

---

## 6. 메모리 + 세션 보존 (v0.4 — 3-Tier)

본 하네스는 다음 3-계층 메모리 + `/ss-re` 스냅샷으로 사용자 컨텍스트를 누적·동기화한다.

### 3-Tier 구조

| Tier | 위치 | 동기화 | 용도 |
|---|---|---|---|
| 1 휘발 | Claude Code `<remember>` 태그 | X (이 PC, 7일 만료) | 디버깅·임시 메모 |
| 2 프로젝트 | `<project>/06.memory/` | git (이 프로젝트) | 결정·사실·교훈 |
| 3 글로벌 | 본 하네스 `plugin/memory/user/` | `/push-global-memory` → `update.sh` | 횡단 작업성향·금기·골 |

### 자연어 트리거 → 자동 분류

"저장해/기억해놔/참고해/이따 기억해" 한마디 → Claude가 *내용*을 보고 분류 → 적절한 tier에 저장.

명시 prefix(옵션): `#g/...`(글로벌), `#p/...`(프로젝트), `#t/...`(휘발).

불확실 시 1줄 되묻기 (최대 1회).

### Tier별 사용 예

- "이따 보고서에 X 쓸거니 기억" → `<remember>` (Tier 1, 7일 후 자동 만료)
- "재훈씨가 supabase 도입 요청" → `06.memory/project.md` (Tier 2, git 공유)
- "이전에 raw tailwind 시도 → 폐기" → `06.memory/feedback.md`
- "Linear ABC-123 = 이 프로젝트 버그" → `06.memory/reference.md`
- "TypeScript strict 항상" → `plugin/memory/user/user.md` (Tier 3, 모든 프로젝트)
- "토스트 3초 통일" → `plugin/memory/user/comfort.md`
- "AI 인프라 자동화 골" → `plugin/memory/user/goals.md`
- "main 직접 push 금지" → `plugin/memory/user/dont.md`

### 보안 가드 (G4 비밀 스캔)

`memory-write-guard.sh` 훅이 PreToolUse Write/Edit에서 다음을 검사:
- API 토큰 패턴 → **차단**
- 이메일 → **차단**
- NDA·금액·계약 키워드 → **경고**

가드를 우회하려면 사용자가 명시 룰 변경 필요.

### 세션 자동 로드

SessionStart 훅이 매 세션 시작 시 다음을 `<system-reminder>`로 inject:
1. `<project>/06.memory/*.md`
2. `plugin/memory/user/*.md`

별도 호출 X. 회수는 자동.

### 동기화 흐름

```
[PC A] "TypeScript strict 항상" → Claude → plugin/memory/user/user.md 업데이트
       /push-global-memory → 본 하네스 git push (yunjadong-team + nathaneast 미러)

[PC B] bash ~/.claude/plugins/nathaneast-aiacht/scripts/update.sh
       → 다음 세션 SessionStart 자동 inject
       → Claude가 typescript 작업 시 자발적으로 strict 적용
```

### 스냅샷 — `/ss-re` (세션 손실 방지)

Claude Code의 `--continue` / `--resume`이 불안정한 문제 해결.

**언제 쓰나**:
- MCP/플러그인 권한 변경 후 Claude Code 재시작
- 세팅 수정으로 강제 종료
- 정확히 같은 자리로 복귀하고 싶을 때

**사용**:
```
[작업 중]
사용자: /ss-re

Claude: ✅ Snapshot 저장됨
       📍 ~/projects/A/.omc/snapshot.md
       - 작업: ...
       - 다음: ...

[사용자가 Claude Code 종료 → 재시작]

[새 세션] cd ~/projects/A && claude

Claude: 📍 직전 세션 스냅샷 복원했습니다.
       - 작업: ...
       - 다음: ...
       그대로 진행할까요? (yes / 변경 / 취소)
```

**파일**:
- `<project>/.omc/snapshot.md` — 단일 파일 (덮어쓰기)
- `.gitignore`에 자동 포함
- 작업 완료 후 사용자가 직접 `rm` 또는 다음 `/ss-re` 호출이 덮어씀

---

## 7. 업데이트

### 글로벌 도구 최신화
```bash
bash ~/.claude/plugins/nathaneast-aiacht/scripts/update.sh
```
- `git pull --ff-only` (충돌 시 사용자가 직접 해결)
- 변경된 파일 목록 출력
- 다음 Claude Code 세션부터 새 스킬/룰/훅 자동 적용

### 충돌 발생 시
```bash
cd ~/.claude/plugins/nathaneast-aiacht
git status
git pull --rebase  # 또는 git pull --no-ff
# 충돌 해결 후 git push origin main
```

---

## 8. 폴더 구조

> 본 섹션은 **본 레포(글로벌 도구 소스)** 의 구조다. 로컬 프로젝트는 §2 참조 (최상위 6 폴더).

```
nathaneast-ai-agent-coding-template/        ← 본 레포 (글로벌 도구 소스)
├── install.sh              ← 글로벌 설치 진입점
├── README.md               ← 이 파일
├── CLAUDE.md               ← 본 레포 작업 시 적용 규칙 (링크만)
├── AGENTS.md               ← Codex CLI 진입점
├── .harness-main-only      ← 본 레포 = main 단독 운영 마커
│
├── plugin/                 ← 글로벌 설치 대상 (install.sh가 ~/.claude/plugins/nathaneast-aiacht/로 복사)
│   ├── claude/
│   │   ├── settings.json   ← SessionStart/PostToolUse 훅 정의 (SessionEnd 제거됨)
│   │   ├── hooks/          ← session-start.sh, posttool-openspec-guard.sh
│   │   ├── skills/         ← 11 스킬 SKILL.md
│   │   ├── commands/       ← 15개 슬래시 커맨드 .md
│   │   ├── rules/          ← 6 규칙 (coding, design, folder, project, user-interaction, memory)
│   │   └── agents/         ← team-guide, advisor
│   ├── codex/              ← Codex CLI 미러 (hooks/config.toml/hooks.json)
│   ├── claude-plugin/      ← .claude-plugin/plugin.json (마켓플레이스 메타)
│   └── codex-plugin/       ← .codex-plugin/plugin.json
│
├── templates/project-init/ ← /pjt-init이 새 프로젝트에 복사
│   ├── 01.spec/            ← PRD, ADR, 유저 스토리
│   ├── 02.workflow/        ← SOP
│   ├── 03.archive/         ← 완료 작업 아카이브
│   ├── 04.docs/            ← RUNBOOK, RELEASE_NOTES, HANDOFF, ONBOARDING
│   ├── 05.tasks/           ← todo.md, prompt.md, feedback.md
│   ├── openspec/           ← 명세 워크플로우 (changes/, specs/, config.yaml)
│   ├── CLAUDE.md           ← 프로젝트 메모리 시작 파일
│   └── .claude/
│       └── CLAUDE.local.md ← 개인 메모리 시작 파일 (gitignore)
│
├── scripts/                ← 보조 스크립트
│   ├── pjt-init.sh
│   ├── merge-skill.sh
│   ├── mirror-personal.sh
│   ├── update.sh
│   ├── setup-claude.sh / setup-codex.sh / setup-both.sh
│   ├── build.sh / build-iteration-gate.sh
│   ├── archive-prompt.sh / trigram-jaccard.sh
│   └── clone-to-company.sh / install-env-guard.sh
│
└── .omc/                   ← 본 레포 작업 메모리
    ├── plans/              ← Planner/Architect/Critic 합의 산출물
    └── snapshot.md         ← 직전 세션 스냅샷 (/ss-re)
```

---

## 9. 트러블슈팅

### `/pjt-init` 호출했는데 다음 세션에서 스킬 자동 주입 안 됨
1. `.harness-active` 마커 존재 확인: `ls .harness-active`
2. 글로벌 훅 등록 확인: `jq '.hooks.SessionStart' ~/.claude/settings.json`
3. 수동 실행 확인: `bash ~/.claude/plugins/nathaneast-aiacht/plugin/claude/hooks/session-start.sh | wc -c` (~7000 bytes 기대)

### 회사 PC에서 `git push` 막힘
- yunjadong-team 조직 접근 권한 확인: `gh auth status`
- 권한 부족 시: `gh auth refresh -s admin:org`

### mkdir/touch 등 권한 prompt 반복
- 글로벌 `~/.claude/settings.json`에 `"defaultMode": "bypassPermissions"` 추가
- 또는 `claude --dangerously-skip-permissions`로 세션 시작

### bats 테스트 실패
```bash
cd ~/.claude/plugins/nathaneast-aiacht
bats plugin/claude/hooks/tests/  # ~36 PASS 기대
```

---

## 10. 본 레포 직접 작업 (개발자 모드)

본 하네스 자체를 개선하려면 본 레포를 clone:

```bash
git clone https://github.com/yunjadong-team/nathaneast-ai-agent-coding-template
cd nathaneast-ai-agent-coding-template

# 변경 후 검증
bats plugin/claude/hooks/tests/
bash scripts/setup-both.sh

# 커밋 + 푸시 (main 단독 운영 — .harness-main-only 마커로 글로벌 branch-guard 예외)
git add -A
git commit -m "..."
git push origin main
```

다음 사용자가 `bash update.sh` 실행하면 변경사항 즉시 동기화.

---

## 11. 버전

- **v0.1.0** (2026-05-14): 초기 v0.1.0 — 본 레포 단일 프로젝트 모델
- **v0.2.0** (2026-05-14): 글로벌 도구 + /pjt-init + /merge-skill 단순화 + /mirror-personal
- **v0.2.1** (2026-05-14): native memory 활용 + /ss-re 스냅샷 신규 + /learn /resume-session 폐기
- **v0.4** (2026-05-14): 메모리 3-Tier + 자연어 자동 분류 + /push-global-memory
- **v0.5** (2026-05-15): `/solo` 자율 빌드 에이전트 — 1~10시간 무인 실행 (planner 분석 → criteria 자동 도출 → Codex 합의 → 실행 루프 → 검증 → commit). critical priority 자동 라벨링 + 80% rule + 비용 다운그레이드($15/$18) + DEGRADED_REVIEW 폴백 + 마커 충돌 검사 등 9개 안전장치. `/pg`로 즉시 진행 출력. `solo-result/{run_id}/report.md` 상세 보고서. (관련: `user-helper`, `feedback-capture` 스킬 추가, `/fdb` 커맨드)
- 변경 이력: `git log --oneline`

---

## License

MIT

---

**문제/제안**: https://github.com/yunjadong-team/nathaneast-ai-agent-coding-template/issues
