# v4 Global Tool Plan — `nathaneast_ai-agent-coding-template`

> **문서 역할**: ralplan 합의 사이클 통합 라운드 산출물 (Planner v4). Architect+Critic v3 검토(6 BLOCKER + 9 MAJOR) 통합 반영.
> **이전 버전 관계**: v3 plan(글로벌 도구 + 템플릿 저장소 모델)을 본 문서가 덮어쓴다. v3는 git 히스토리(commit 직전 상태)로 보존. v2는 `harness-template-mvp-plan.md` 및 v0.1.0 태그로 보존.
> **표기 규칙**: `[확정]` = 사용자 6개 답변으로 닫힘(뒤집기 금지) · `[열림]` = 추가 결정 필요 · `[추천]` = Planner 의견(근거 동반) · `[리스크]` = 자기 진단 · `[BLOCKER-Bx]` / `[MAJOR-Cx]` = v3 검토 통합 추적자.
> **작성자**: Planner v4 | **작성일**: 2026-05-14
> **다음 단계**: Architect+Critic 2차 검토 → 통과 시 Phase 0.0 착수.

---

## 0. 변경 요약 (v3 → v4)

v3에서 발견된 6 BLOCKER + 9 MAJOR가 v4에서 어떻게 해소됐는지 한눈에:

| # | 분류 | 원본 영역 | v4 해소 위치 |
|---|------|----------|-------------|
| 1 | BLOCKER (Architect A1) | SessionStart 훅 cwd blindness | §5 + Phase 0.0 / 0.B |
| 2 | BLOCKER (Architect A2) | 사용자 자체 deny가 install path 차단 | §4 + Phase 1 |
| 3 | BLOCKER (Architect F + Critic 1) | Phase 0 단일 커밋 회귀 | §9 Phase 0.A~0.E 5분할 |
| 4 | BLOCKER (Critic 1+2+3) | 9개 하드코드 경로 + paths.sh + 본 레포 dogfood | §3 + §6 + §9 Phase 0.B / 0.E |
| 5 | BLOCKER (Critic 2) | /merge-skill --to-template secret 유출 | §7 + Phase 4 |
| 6 | BLOCKER (Critic 3) | 자기 dogfood 회귀 | §6 + §9 Phase 6 본 레포 dogfood sub-phase |
| 7 | MAJOR (Architect C + A-C) | /merge-skill git 안전성 | §7 + Phase 4 |
| 8 | MAJOR (Architect G) | install.sh 멱등성 + --uninstall | §4 + Phase 1 |
| 9 | MAJOR (Critic 1) | "공통 설치" 정의 모호 | §6.0 정의 박스 |
| 10 | MAJOR (Critic 2) | v0.1.0 자산 보존 | §10-bis 매트릭스 + Phase 5 게이트 |
| 11 | MAJOR (Critic 7) | v0.1.0 → v0.2.0 회귀 | Phase별 bats 게이트 |
| 12 | MAJOR (Critic 5.2) | OMC 훅 동시 실행 토큰 폭발 | §5.4 + Phase 3 bats |
| 13 | MAJOR (Critic 8.2) | 시간 추정 누락 | §9 각 Phase 시간 추정 |
| 14 | MAJOR (Critic B) | 미니멀 vs 야심 | §3.0 미니멀 원칙 박스 |
| 15 | MAJOR (Critic D) | v0.1.0 KPI/consensus/resume 보존 검증 | §10-bis + Phase 5 |

**사용자 6개 결정(Q1~Q6)은 v3 그대로 유지. 본 문서는 그 "구현 방식"만 안전하게 다듬는다.**

---

## 1. 비전 한 단락

`nathaneast_ai-agent-coding-template`은 사용자의 모든 컴퓨터(개인 맥 + 회사 PC)에 **2단 명령(`curl -o + bash`)**으로 설치되는 "글로벌 AI 코딩 하네스"이며, 동시에 OMC(`oh-my-claudecode`)와 공존하는 개인 레이어다. 글로벌 설치 위치(`~/.claude/plugins/nathaneast_aiacht/`)에 v0.1.0의 13 skills + 9 commands(기존) + `/pjt-init`(신규 1개, 합계 10) + 3 hooks + 2 sub-agents + 5 rules를 캐시하고, 로컬 프로젝트는 `/pjt-init` 한 번으로 컨텐츠 폴더 6종(`01.spec/`~`05.tasks/` + `openspec/`)만 받는다. **v0.1.0 자산은 새로 만들지 않고 `plugin/`과 `templates/project-init/` 두 폴더로 재배치만 한다.** v0.1.0의 45 bats / KPI 5개 / /consensus 3단 폴백 / /resume-session 시나리오 A·B는 **각 Phase 종료 게이트로 보존을 강제**한다. 학습한 스킬은 `/merge-skill --to-template`로 본 레포에 역전파(기본 confirm 후 commit, `--auto-commit` opt-in)되어 다른 PC와 git push/pull로 동기화된다.

---

## 2. 사용자 확정 결정 6개 (뒤집기 금지)

| # | 결정 | 사용자 답변 | 근거 |
|---|------|-------------|------|
| Q1 | 배포 채널 | **GitHub 템플릿 + curl install.sh (2단 패턴)** | 어떤 컴퓨터든 단일 절차로 셋업, npm 비의존 |
| Q2 | 진입 인터페이스 | **`/pjt-init` 슬래시 커맨드만** | 셸 CLI 추가 학습 비용 회피 |
| Q3 | 로컬 프로젝트 컨텐츠 | **컨텐츠 폴더만**(`01~05.*` + `openspec/`). 스킬/훅/커맨드/룰은 **전부 글로벌** | 로컬 가벼움, 동기화 비용 최소 |
| Q4 | 역전파 | **`/merge-skill --to-template <local-skill-path>`** | 기존 `/merge-skill` 자산 재활용 |
| Q5 | 레포 이름 | **`nathaneast_ai-agent-coding-template`** | 네임스페이스 prefix로 OMC 등과 충돌 회피 |
| Q6 | OMC와의 관계 | **OMC 위 사용자 개인 레이어, OMC 안 건드림** | OMC가 이미 `~/.claude/` 일부 관리. 격리 필수 |

---

## 3. 최종 디렉터리 구조

### 3.0 미니멀 원칙 박스 — `[확정]` (MAJOR-CriticB 반영)

> **본 레포는 "글로벌 도구의 소스 레포"다. 본 레포에 새로 만드는 것은 다음 4가지뿐.**
>
> 1. `plugin/` (v0.1.0의 `.claude/` + `.codex/` + `.claude-plugin/` + `.codex-plugin/`이 이리로 이동)
> 2. `templates/project-init/` (v0.1.0의 `01~05.*/` + `openspec/`이 이리로 이동)
> 3. `scripts/`에 신규 5개 (`pjt-init.sh`, `sync-up-skill.sh`, `update.sh`, `uninstall.sh`, `paths.sh` 공용 lib) 추가 — 기존 13개는 유지
> 4. 루트 `install.sh` (Phase 1)
>
> **본 레포에 신규 생성하지 않는 것**: 본 레포 자체용 `01~05.*/`, 본 레포 자체용 별도 `package.json`, README의 큰 재작성. CLAUDE.md/AGENTS.md는 slim 갱신만(작업용 룰은 `plugin/claude/rules/`에 위임).
>
> **본 레포 dogfood**: 본 레포 자체에서 `claude` 실행 시, 본 레포는 `templates/project-init/01.spec/` 등을 자기 컨텐츠로 사용한다 → `.harness-active`는 본 레포 루트에 둔다(아래 §3.5 참조).

### 3.1 본 레포 (글로벌 도구 소스) — `[확정]` 최종 구조

```
nathaneast_ai-agent-coding-template/        # GitHub 메인 레포 (v0.2.0+)
├── install.sh                              # 2단 패턴 진입점 (Phase 1)
├── install.sh.sha256                       # 무결성 검증(자동 생성, Phase 1)
├── README.md                               # 설치/사용 안내 (Phase 5)
├── CLAUDE.md                               # 본 레포 작업용 (slim)
├── AGENTS.md                               # Codex 미러 (slim)
├── .gitignore                              # .env 보호 + 빌드 산출물 제외
├── .harness-main-only                      # 본 레포 main 단독 운영 마커(기존)
├── .harness-active                         # 본 레포 자체 dogfood용(§3.5)
│
├── plugin/                                 # [신규] 글로벌 설치 대상
│   ├── .claude-plugin/plugin.json
│   ├── .codex-plugin/plugin.json
│   ├── claude/
│   │   ├── skills/                         # 13개 (v0.1.0 .claude/skills/ 이동)
│   │   ├── commands/                       # 10개 (기존 9 + /pjt-init)
│   │   ├── agents/                         # 2개
│   │   ├── rules/                          # 5개
│   │   ├── hooks/
│   │   │   ├── lib/
│   │   │   │   └── paths.sh                # [신규] 경로 추상화 (MAJOR-A1/Critic1)
│   │   │   ├── session-start.sh
│   │   │   ├── session-end.sh
│   │   │   ├── posttool-openspec-guard.sh
│   │   │   └── tests/                      # 45 bats
│   │   └── settings.template.json          # [신규] 글로벌 settings 머지 키 셋
│   └── codex/                              # --with-codex 활성
│       ├── config.toml
│       ├── hooks.json
│       ├── hooks/
│       ├── prompts/
│       └── skills/
│
├── templates/                              # [신규] /pjt-init이 로컬에 복사
│   └── project-init/
│       ├── 01.spec/                        # v0.1.0 01.spec/ 이동 (빈 골격)
│       ├── 02.workflow/
│       ├── 03.archive/
│       ├── 04.docs/
│       ├── 05.tasks/
│       └── openspec/
│
├── scripts/                                # 본 레포 유지보수 + install 백엔드
│   ├── lib/paths.sh                        # [신규] 셸 경로 추상화 (BLOCKER-Critic1)
│   ├── install.sh                          # 루트 install.sh와 동일/위임
│   ├── update.sh                           # [신규]
│   ├── uninstall.sh                        # [신규]
│   ├── sync-up-skill.sh                    # [신규] /merge-skill --to-template
│   ├── pjt-init.sh                         # [신규] /pjt-init 백엔드
│   ├── merge-skill.sh                      # 기존 (로컬→본 레포 흡수)
│   ├── build.sh                            # 기존
│   ├── clone-to-company.sh                 # [폐기 후보] Phase 7 검토
│   ├── archive-prompt.sh                   # 기존
│   ├── trigram-jaccard.sh                  # 기존
│   ├── setup-{claude,codex,both}.sh        # 기존
│   ├── install-env-guard.sh                # 기존
│   ├── resume-session.sh                   # 기존
│   └── build-iteration-gate.sh             # 기존
│
├── .omc/                                   # 본 레포 작업 메모
└── policy/                                 # 본 레포 정책
```

### 3.2 글로벌 설치 위치 — `[확정]`

```
~/.claude/plugins/nathaneast_aiacht/        # install.sh가 git clone
├── .git/                                   # update.sh가 pull
├── VERSION                                 # 설치 버전 (update 비교)
├── plugin/.claude-plugin/plugin.json
├── plugin/.codex-plugin/plugin.json        # --with-codex 시 활성
├── plugin/claude/{skills,commands,agents,rules,hooks}
├── plugin/codex/{config.toml,hooks.json,hooks,prompts,skills}
├── templates/project-init/
└── scripts/{pjt-init.sh, sync-up-skill.sh, update.sh, uninstall.sh, lib/paths.sh}
```

### 3.3 로컬 프로젝트 (`/pjt-init` 후) — `[확정]`

```
~/projects/my-app/
├── 01.spec/  02.workflow/  03.archive/  04.docs/  05.tasks/
├── openspec/config.yaml
├── .gitignore                              # .env 보호 표준
└── .harness-active                         # 마커 (글로벌 SessionStart 훅이 감지)
```

`.claude/settings.json` 로컬 신규 작성은 **하지 않음**. 글로벌 `~/.claude/settings.json`만 활성. (Critic §4.1 (e) 결정.)

### 3.4 마이그레이션 매핑 (v0.1.0 → v0.2.0)

| 기존 (v0.1.0) | 신규 (v0.2.0) | 이동 방식 | Phase |
|--------------|--------------|----------|-------|
| `.claude/` | `plugin/claude/` | `git mv` | 0.A |
| `.codex/` | `plugin/codex/` | `git mv` | 0.A |
| `.claude-plugin/` | `plugin/.claude-plugin/` | `git mv` | 0.A |
| `.codex-plugin/` | `plugin/.codex-plugin/` | `git mv` | 0.A |
| `01.spec/`~`05.tasks/` | `templates/project-init/0{1..5}.*/` | `git mv` | 0.D |
| `openspec/` | `templates/project-init/openspec/` | `git mv` | 0.D |
| 9개 스크립트 하드코드 경로 | `scripts/lib/paths.sh` 추상화 | 일괄 갱신 | 0.B |
| settings.json `command:".claude/hooks/..."` | `plugin/claude/hooks/...` | 직접 수정 | 0.C |
| CLAUDE.md/AGENTS.md | slim 갱신 (작업용) | 직접 수정 | 0.E |
| `.harness-main-only`, `.omc/`, `policy/` | 루트 유지 | 그대로 | — |

### 3.5 본 레포 자체 dogfood 모델 — `[확정]` (BLOCKER-Critic3 해소)

본 레포 루트에 `.harness-active` 마커를 둔다. 본 레포 dogfood 시 SessionStart 훅은 다음을 본다:
- `PROJECT_CWD=~/Desktop/coding_project/ai-agent-coding-template`
- `.harness-active` 있음, `01.spec/`/`openspec/` 있음? → **본 레포는 둘 다 `templates/project-init/` 하위로 이동했으므로 직접 없음**.
- 해결: SessionStart 훅의 마커 검사를 "either A: `.harness-active` + `01.spec/` + `openspec/` (사용자 프로젝트) OR B: `.harness-active` + `templates/project-init/01.spec/` + `templates/project-init/openspec/` (본 레포 dogfood)"로 분기.
- 또는 본 레포 `.harness-active` 1행에 `mode=source-repo`라 표기하고, 훅은 이 1행 키워드로 source-repo 모드 진입 → 컨텐츠 폴더는 `templates/project-init/` 하위에서 찾음.

**[추천]** 후자(마커 1행 표기). 검사 로직 단순 + 향후 다른 모드 추가 용이.

---

## 4. `install.sh` 설계 — `[확정]` (BLOCKER-A2 + MAJOR-G 반영)

### 4.1 호출 — **2단 패턴 의무** (BLOCKER-A2)

사용자 글로벌 `~/.claude/settings.json` deny 룰(`Bash(curl * | sh*)` / `Bash(curl * | bash*)`)을 본 plan이 위반하지 않도록 한 줄 파이프를 폐기하고 다음 2단 패턴을 사용한다:

```bash
# 첫 설치 (기본: Claude Only)
curl -fsSL https://raw.githubusercontent.com/nathaneast/nathaneast_ai-agent-coding-template/main/install.sh -o /tmp/install.sh
# (선택, 권장) 무결성 검증
curl -fsSL https://raw.githubusercontent.com/nathaneast/nathaneast_ai-agent-coding-template/main/install.sh.sha256 -o /tmp/install.sh.sha256
shasum -a 256 -c /tmp/install.sh.sha256
# 실행
bash /tmp/install.sh

# Claude + Codex 동시
bash /tmp/install.sh --with-codex

# 갱신
bash /tmp/install.sh --update

# 제거
bash /tmp/install.sh --uninstall
```

README + install.sh 첫 줄에 모두 명시: **"한 줄 파이프(`| sh`)는 deprecated. 항상 2단(download → bash)."**

### 4.2 옵션

| 옵션 | 기본값 | 동작 |
|------|--------|------|
| `--claude-only` | ✓ | Claude만 |
| `--with-codex` | | Claude + Codex |
| `--update` | | 멱등 재실행 (git pull + 머지 재적용) |
| `--uninstall` | | 글로벌 디렉터리 제거 + settings.json 백업 복원 |
| `--target <path>` | `~/.claude/plugins/nathaneast_aiacht/` | 설치 위치 오버라이드 |
| `--dry-run` | | 변경 사항만 출력 |
| `--from-tar <path>` | | air-gapped: 로컬 tar 추출 (Critic §3.1) |

### 4.3 동작 단계

1. **사전 점검**: `git`, `jq` 1.6+, `bash` 4.0+ 존재(없으면 fail-fast + brew/apt 안내). Claude Code 설치 여부(`~/.claude/`) 확인. 사용자 deny 룰 인지 안내 출력.
2. **소스 배치**: `git clone` 또는 `--from-tar` 추출. 이미 존재 시 `--update` 경로로 위임. dirty면 사용자 confirm.
3. **Claude Code 통합** (settings.json **셸 jq + atomic mv**로 머지 — `Edit/Write` 도구 비사용):
   ```bash
   SETTINGS=~/.claude/settings.json
   BACKUP=$SETTINGS.bak-$(date -u +%Y%m%dT%H%M%SZ)
   TMP=$(mktemp)
   exec 9>"$SETTINGS.lock"
   flock -n 9 || { echo "Another install.sh running; abort"; exit 1; }
   cp "$SETTINGS" "$BACKUP"
   jq -s '.[0] * .[1]' "$SETTINGS" plugin/claude/settings.template.json > "$TMP"
   jq empty < "$TMP" || { rm -f "$TMP"; exit 1; }
   mv "$TMP" "$SETTINGS"
   ```
   - 사용자 기존 deny 룰(`.env` 보호, curl|sh 차단, settings.json 보호)은 **deep merge로 보존**. 본 plan이 삭제하지 않음.
   - hooks: SessionStart/SessionEnd/PostToolUse에 본 하네스 훅 경로 **append만**. 기존 OMC 훅 보존.
   - env: `HARNESS_GLOBAL_ROOT=~/.claude/plugins/nathaneast_aiacht`.
4. **Codex 통합** (`--with-codex`): `~/.codex/config.toml` + `~/.codex/hooks.json` 머지. `~/.codex/` 미존재 시 자동 생성 (Q-H [추천]).
5. **검증**: `claude --version`(선택), 파일 카운트, 다음 단계 안내(`/pjt-init`).

### 4.4 멱등성 + Uninstall (MAJOR-G)

- `bash install.sh` 재실행 시 무해: 동일 결과(file checksum + settings.json digest 비교).
- `--update`: `git pull --ff-only` + settings.template.json 재머지(이미 있는 키 skip).
- `--uninstall`: 최신 `.bak-*` settings.json 복원 + 글로벌 디렉터리 제거(사용자 confirm 1회). VERSION 비교로 잘못된 백업 복원 방지.

### 4.5 안전장치 — `[확정]`

- `set -euo pipefail` + `trap ERR cleanup`.
- 머지 트랜잭션: flock + 백업 + tmp atomic mv + 실패 시 자동 복원.
- 사용자 deny 룰 **삭제 금지** (보존만).
- install.sh 자체는 **셸 직접 실행 명시**. Claude 세션 내부의 슬래시로 호출 시 사용자 deny에 막힘을 README가 안내.

### 4.6 트레이드오프 / [리스크]

- 2단 패턴은 한 줄 패턴보다 1단계 더 손이 가지만, 사용자 본인 보안 룰 + 무결성 검증을 동시에 보장.
- jq deep merge가 같은 키 충돌 시 patch 측 우선 — 사용자 기존 키 보존 검증을 bats 12개+로 강제(Phase 1).
- install.sh 셸 jq 리다이렉션이 향후 사용자가 `Bash(jq ... > ~/.claude/settings.json)` 패턴까지 deny할 가능성 → README "install.sh는 터미널 외부 셸에서만 실행" 명시.

---

## 5. SessionStart 훅 글로벌 동작 — `[확정]` (BLOCKER-A1 해소)

### 5.1 cwd 인식 메커니즘 (BLOCKER-A1)

```bash
# plugin/claude/hooks/session-start.sh (글로벌 버전)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_GLOBAL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"   # global plugin root
PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"                 # primary: env, fallback: PWD

# 마커 + 폴더 3중 검사는 PROJECT_CWD 기준
if [[ ! -f "$PROJECT_CWD/.harness-active" ]]; then exit 0; fi

# 본 레포 source-repo 모드 분기 (§3.5)
MODE=$(head -n1 "$PROJECT_CWD/.harness-active" 2>/dev/null | grep -oE 'mode=[a-z-]+' | cut -d= -f2)
if [[ "$MODE" == "source-repo" ]]; then
  CONTENT_BASE="$PROJECT_CWD/templates/project-init"
else
  CONTENT_BASE="$PROJECT_CWD"
fi

[[ -d "$CONTENT_BASE/01.spec" ]] || exit 0
[[ -d "$CONTENT_BASE/openspec" ]] || exit 0

# 자산 주입 소스
SKILLS_DIR="$HARNESS_GLOBAL_ROOT/plugin/claude/skills"
RULES_DIR="$HARNESS_GLOBAL_ROOT/plugin/claude/rules"
LEARNINGS_DIR="$PROJECT_CWD/.omc/learnings"   # learnings는 프로젝트 로컬 (§5.5 결정)
```

### 5.2 `CLAUDE_PROJECT_DIR` 실측 검증 의무 — Phase 0.0 (BLOCKER-A1)

v0.2.0 출시 전 다음 단계로 실측:
1. WebFetch `docs.anthropic.com` Claude Code hooks 페이지에서 `CLAUDE_PROJECT_DIR` 환경변수 보장 여부 확인.
2. 미보장 시: `$PWD` 폴백의 정확도 검증 — 임시 디렉터리 4개에서 `claude` 호출 시 hook 입장 PWD가 사용자 cwd와 일치하는지 bats 4개.
3. 보장 시: bats 케이스에 `CLAUDE_PROJECT_DIR` 주입/미주입 양쪽 검증.

### 5.3 안전 원칙 — `[확정]`

- 마커 + 폴더 2개 3중 확인 + 마커 손상 5종 fail-safe(0 byte / 디렉터리 / broken symlink / 권한 없음 / 미래 mtime).
- 읽기 전용: stdout 컨텍스트 주입만, 파일 수정 금지.
- 토큰 budget: 본 하네스 단독 7K + OMC 별도 7K(아래 §5.4).

### 5.4 OMC 공존 + 토큰 폭발 방지 — `[확정]` (MAJOR-Critic5.2)

- OMC 훅 + 본 하네스 훅 동시 등록 시 둘 다 stdout. Claude Code가 합산 컨텍스트 수용.
- 본 하네스 훅은 PROJECT_CWD 기준 마커가 없으면 **0 byte** 즉시 종료(현재 v0.1.0이 6K 출력 → v0.2.0에서 비활성 시 0K).
- Phase 3 bats 추가: OMC 활성 디렉터리에서 본 하네스 훅 stdout이 0 byte인지 검증. 본 하네스 활성 디렉터리에서는 합산 컨텍스트 14K 이하 확인.
- Claude Code 훅 priority API 미존재 시 워크어라운드(stat lock file 등)는 v0.3.0+ RFC로 분리.

### 5.5 learnings 위치 — `[확정]`

`.omc/learnings/`는 **프로젝트 로컬**(cwd). 본 레포의 56회 회수 데이터는 본 레포 git에 그대로 남고, 회사 PC는 install 후 빈 learnings에서 시작(글로벌 자산이 아님). 사유: 학습은 프로젝트 컨텍스트와 결합(범용화 후 역전파는 `/merge-skill --to-template`로 명시 흐름).

### 5.6 트레이드오프 / [리스크]

- `CLAUDE_PROJECT_DIR` 공식 미보장 시 `$PWD` 폴백의 결정성 — Phase 0.0의 4개 bats로 검증.
- learnings 로컬 결정은 듀얼 PC에서 학습이 자동 동기화되지 않음을 의미. 사용자가 회사 PC에서 도움이 필요한 학습은 의식적으로 `/merge-skill --to-template`로 보내야 함.

---

## 6. `/pjt-init` 커맨드 설계 — `[확정]` (BLOCKER-Critic3 + MAJOR-C1 반영)

### 6.0 "공통 설치"의 정의 박스 — `[확정]` (MAJOR-Critic1)

> **`/pjt-init`이 만드는 것 = 다음 4가지가 전부**:
>
> 1. 6개 폴더 + openspec: `01.spec/`, `02.workflow/`, `03.archive/`, `04.docs/`, `05.tasks/`, `openspec/config.yaml`
> 2. 마커: `.harness-active` (1행: `v0.2.0 / pjt-init / <ISO8601>`, 본 레포 dogfood가 아닌 한 `mode=` 미표기)
> 3. `.gitignore`: 표준 셋(`.env*`, `node_modules/`, `.claude/projects/`, `.omc/state/`). 기존 .gitignore 있으면 append + dedupe.
> 4. (없음) — `/pjt-init`은 다음을 **만들지 않음**: `package.json`, `README.md`, `01.spec/prd.md` 스타터, `.claude/settings.json` 로컬, git 초기 commit. 사용자가 직접 또는 별도 도구로 처리.

### 6.1 호출

```bash
mkdir ~/projects/my-app && cd ~/projects/my-app
claude
# 세션 내
> /pjt-init
```

### 6.2 동작 단계 (`scripts/pjt-init.sh` 백엔드)

1. **사전 검증**: 글로벌 위치(`$HARNESS_GLOBAL_ROOT/templates/project-init/`) 존재. 없으면 안내 후 종료.
2. **모드 결정** (3단 모드, MAJOR-Critic4.2):
   - `strict` (기본): 빈 dir(또는 `.git/`만) 가정. 외 충돌 시 일괄 confirm(파일별 confirm 금지).
   - `--merge` (사용자가 명시 시 또는 v4 [추천] **점진 도입 기본 모드 후보**): 폴더 단위 존재 검사. 존재 폴더 스킵 + 사용자 안내. 미존재 폴더만 생성.
   - `--force`: 모든 충돌 덮어쓰기(사용자 confirm 1회 후).
3. **컨텐츠 복사**: `templates/project-init/` → cwd (cp -R). 6개 폴더 + openspec/config.yaml.
4. **마커 + .gitignore**:
   - `.harness-active` 생성 (1행).
   - `.gitignore`: 기존 있으면 append + dedupe, 없으면 신규 작성.
5. **git 초기화는 안 함** — 사용자 명시 의무. plan은 "이제 git init + 첫 커밋을 직접 하세요"라는 안내만.
6. **결과 출력**: "OK. 새 세션을 시작하면 SessionStart 훅이 자동 작동합니다. 다음: `/double-check`, `/openspec-propose`, `/build`."

### 6.3 옵션

| 옵션 | 동작 |
|------|------|
| `/pjt-init` (기본) | strict 모드, 6개 폴더 + openspec 복사 |
| `/pjt-init --merge` | 기존 파일 보존 + 누락 폴더만 생성 |
| `/pjt-init --force` | 모든 충돌 덮어쓰기 (confirm 1회) |
| `/pjt-init --minimal` | `01.spec/` + `openspec/`만 |
| `/pjt-init --with-codex` | 마커에 codex 의도 표기 |

[열림] Q-K (Architect/Critic 2차 검토에서 결정): 기본 모드를 `strict` vs `--merge` 중 어느 쪽으로 — Critic은 `--merge` 권고. Planner v4 [추천]: 기본 `strict` 유지 + `--merge`는 README에서 1순위 권장.

### 6.4 본 레포 자체 dogfood — `[확정]` (BLOCKER-Critic3.1)

본 레포에서 `/pjt-init` 실행 시:
- 현재 cwd = 본 레포 루트. `01.spec/` 등은 `templates/project-init/`로 이미 이동했으므로 **루트에 없음**.
- 마커 `.harness-active`는 §3.5에 따라 `mode=source-repo` 표기.
- pjt-init은 source-repo 모드일 때 **노옵(no-op)**으로 종료 + 안내: "본 레포는 이미 templates/project-init/이 마스터입니다. /pjt-init 불필요."

### 6.5 트레이드오프 / [리스크]

- strict 기본은 Next.js 등 기존 프로젝트 점진 도입을 막음. → `--merge` 옵션을 README 1순위로 노출.
- 자동 git init 안 함은 사용자 잊을 가능성 → 결과 출력에 명시.

---

## 7. `/merge-skill --to-template` 설계 (역전파) — `[확정]` (BLOCKER-Critic2 + MAJOR-A-C 해소)

### 7.1 호출

```bash
> /merge-skill --to-template .claude/skills/my-new-skill
```

### 7.2 동작 단계 (`scripts/sync-up-skill.sh` 백엔드) — **commit은 기본 비자동** (BLOCKER-Critic2)

1. **글로벌 위치 git 사전 안전 검사 5항** (MAJOR-A-C):
   ```bash
   cd "$HARNESS_GLOBAL_ROOT"
   git symbolic-ref -q HEAD > /dev/null || die "detached HEAD: cd && git checkout main"
   git diff-index --quiet HEAD -- || die "dirty: git status를 확인하세요"
   BR=$(git symbolic-ref --short HEAD); [[ "$BR" == "main" ]] || die "main이 아님: $BR"
   git config user.email > /dev/null || die "git config user.email 미설정"
   git fetch origin main && git rebase origin/main || die "rebase 실패: 수동 해결"
   ```
2. **포맷 검증**: 로컬 스킬에 `SKILL.md` 존재 + frontmatter 유효성.
3. **secret 자동 스캔** (BLOCKER-Critic2):
   ```bash
   # 정규식 패턴 (positive)
   PATTERNS='(sk-[A-Za-z0-9]{20,})|(api[_-]?key\s*[:=]\s*["'"'"'][^"'"'"']{16,})|(password\s*[:=]\s*["'"'"'][^"'"'"']{6,})|(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)|(AKIA[0-9A-Z]{16})'
   if grep -rIEn "$PATTERNS" "$LOCAL_SKILL_PATH"; then
     die "secret 의심 발견. 위 라인을 검토 후 제거 또는 .env로 분리하세요."
   fi
   # .env 파일 자체 포함 검사
   find "$LOCAL_SKILL_PATH" -name '.env*' -print -exec false {} +
   ```
4. **복사**: `cp -R` 로컬 → `plugin/claude/skills/<skill>/`.
5. **메타 갱신**: `plugin/.claude-plugin/plugin.json` skills[] append (idempotent). `plugin/.codex-plugin/plugin.json` 동기.
6. **stage + status 출력**:
   ```bash
   git add plugin/claude/skills/"$SKILL" plugin/.claude-plugin/plugin.json plugin/.codex-plugin/plugin.json
   git status --short
   ```
7. **사용자 confirm 후에만 commit** (기본 동작):
   - `--auto-commit` 명시 opt-in 시에만 자동 commit.
   - commit 메시지: `feat(skills): add <skill> via /merge-skill --to-template` + 본문에 source path, ISO date.
8. **push는 자동 안 함**: 안내만(`cd $HARNESS_GLOBAL_ROOT && git push origin main`).

### 7.3 옵션

| 옵션 | 동작 |
|------|------|
| 기본 | stage + status 출력 + confirm 후 commit |
| `--auto-commit` | confirm 없이 commit (회사 PC 비권장) |
| `--no-commit` | stage만, commit 안 함 |
| `--push` | commit 후 push까지 (`--auto-commit`와 조합 필요) |
| `--dry-run` | 변경 없이 검사만 |

### 7.4 README + ONBOARDING 명시 — `[확정]`

`README.md` + `04.docs/ONBOARDING.md`에 다음 박스 의무:
- "**회사 PC에서 사용 주의**: `/merge-skill --to-template`은 본 레포(public)에 변경을 추가합니다. 사내 정보 누출 위험. 회사 PC에서는 (a) `--dry-run`으로 사전 검토 후 (b) 별도 fork(`nathaneast_ai-agent-coding-template-company`) 운영을 권장."
- "secret 자동 스캔은 false-negative 가능. 사용자 최종 책임."

### 7.5 트레이드오프 / [리스크]

- 기본 비자동은 한 단계 더 들지만 secret 사고 비용(public 노출)이 훨씬 큼.
- secret 정규식의 정밀도 한계 → trufflehog 같은 외부 도구는 v0.3.0+ RFC.
- 회사 PC fork 운영은 동기화 복잡도 ↑ → [열림] Q-N(사용자 결정).

---

## 8. 다른 PC로 동기화 — `[확정 + 부분 열림]`

### 8.1 첫 설치 (회사 PC)

```bash
curl -fsSL .../install.sh -o /tmp/install.sh
shasum -a 256 -c /tmp/install.sh.sha256
bash /tmp/install.sh
```

### 8.2 변경 후 동기화 (개인 맥 → 회사 PC)

**개인 맥**: `/merge-skill --to-template ...` → confirm → commit → `cd $HARNESS_GLOBAL_ROOT && git push`.

**회사 PC**: `bash ~/.claude/plugins/nathaneast_aiacht/scripts/update.sh`.

### 8.3 update.sh

1. `cd $HARNESS_GLOBAL_ROOT && git fetch && git status`.
2. clean: `git pull --ff-only`.
3. dirty: 안내(자동 stash 금지).
4. settings.json 재머지(새 키만).
5. VERSION 비교 + 결과.

### 8.4 충돌 해결 — `[추천]`

- sync-up-skill.sh가 commit 전 `git fetch + rebase origin/main` 자동 시도. 실패 시 명확한 안내.
- 동일 스킬명 충돌 시 `--auto-suffix .company` 옵션 제공.

### 8.5 지원 환경 매트릭스 (MAJOR-Critic3.1)

| 등급 | 환경 | 처리 |
|------|------|------|
| 1차 | 인터넷 + Claude Code 정상 | curl 2단 (기본) |
| 2차 | GitHub raw 차단 | `--from-tar <path>` (수동 tar 다운로드) |
| 3차/Non-Goal | air-gapped 완전 격리 | USB 전달 + `--from-tar` |
| Non-Goal | 회사 PC `~/.claude/` MDM 차단 | `--target` 옵션 안내, 미보장 |

[열림] Q-M: 회사 PC 실제 네트워크 환경 — 사용자가 직접 확인 후 회답.

[열림] Q-N: 회사 PC fork 운영 vs 동일 레포 push — 사용자 결정.

---

## 9. v0.1.0 → v0.2.0 Phase 분해 (시간 추정 포함)

### Phase 0.0: 환경 사전 검증 (30분) — [BLOCKER-A1 해소 의무]

- WebFetch로 `CLAUDE_PROJECT_DIR` 환경변수 공식 지원 여부 확인.
- `$PWD` 폴백 정확도 검증 (bats 4개): 임시 dir 4개에서 `claude` 호출 시 cwd 결정성.
- 결과 → `04.docs/CLAUDE_PROJECT_DIR-verification.md` (커밋).
- 사용자 deny 룰 인벤토리 작성: `grep -oE '^[^=]+' ~/.claude/settings.json`이 아니라 `jq '.permissions.deny[]' ~/.claude/settings.json` → `04.docs/user-deny-rules-inventory.md`.

**게이트**: WebFetch 결과 + bats 4/4 PASS. 실패 시 §5 설계 재검토.
**커밋**: `chore(verify): CLAUDE_PROJECT_DIR + user deny rules inventory`.

### Phase 0.A: git mv 디렉터리 재배치 (45분) — [BLOCKER-Critic1 분할 1/5]

- `git mv .claude/ plugin/claude/`
- `git mv .codex/ plugin/codex/`
- `git mv .claude-plugin/ plugin/.claude-plugin/`
- `git mv .codex-plugin/ plugin/.codex-plugin/`

**게이트**: `find plugin/ -type f | wc -l`이 v0.1.0 자산 카운트와 일치. (bats는 아직 실패 — 0.B에서 복원.)
**커밋**: `refactor(structure): move .claude/.codex/.claude-plugin/.codex-plugin/ to plugin/`.

### Phase 0.B: paths.sh 도입 + 9개 스크립트 일괄 갱신 (60분) — [BLOCKER-Critic1 분할 2/5]

- `scripts/lib/paths.sh` 신규: `harness_global_root()`, `harness_local_root_or_die()`, `harness_skills_dir()`, `harness_hooks_dir()`, `harness_templates_dir()`, `harness_learnings_dir(project_cwd)`.
- 9개 스크립트(`setup-claude.sh:31-49`, `setup-codex.sh:5-21`, `setup-both.sh:17-18`, `build-iteration-gate.sh:31-34`, `build.sh:10-11`, `archive-prompt.sh:12-14`, `merge-skill.sh:24`, `setup-codex.sh:5-6`, `setup-claude.sh:8`) 일괄 갱신 → paths.sh 함수 호출.
- bats 테스트도 동일 갱신.
- `plugin/claude/hooks/lib/paths.sh` 신규: SessionStart 훅이 사용. PROJECT_CWD + HARNESS_GLOBAL_ROOT 분리.

**게이트**: `bats plugin/claude/hooks/tests/` 45/45 PASS. paths.sh 단위 테스트 bats 6개+ PASS.
**커밋**: `refactor(paths): introduce lib/paths.sh and update 9 scripts + hooks`.

### Phase 0.C: settings.json 갱신 + session-start.sh PROJECT_CWD 도입 (30분) — [BLOCKER-A1 + Critic2.2 해소]

- `.claude/settings.json`의 `command`를 `plugin/claude/hooks/session-start.sh`로 갱신(본 레포 작업용).
- `plugin/claude/hooks/session-start.sh`에 PROJECT_CWD 분기 + source-repo 모드 분기 적용.
- 마커 손상 5종 fail-safe.

**게이트**: 본 레포 자체에서 `bash plugin/claude/hooks/session-start.sh` 실행 정상 종료. bats 45/45 PASS.
**커밋**: `feat(hooks): adopt CLAUDE_PROJECT_DIR + source-repo mode in session-start`.

### Phase 0.D: 컨텐츠 폴더 → templates/project-init/ 이동 (30분) — [BLOCKER-Critic1 분할 4/5]

- `git mv 01.spec/ templates/project-init/01.spec/` 5개.
- `git mv openspec/ templates/project-init/openspec/`.
- 본 레포 루트에 `.harness-active` 작성(1행: `v0.2.0 / source-repo / mode=source-repo / <ISO>`).
- SKILL.md / commands/*.md 내 경로 참조 갱신(예: `learn` 스킬의 `.omc/learnings`는 PROJECT_CWD 기준 그대로, 단 source-repo 모드일 때는 `templates/project-init/` 미러 없음 — learnings는 본 레포 `.omc/`).

**게이트**: bats 45/45 PASS. 본 레포에서 `/pjt-init` 호출 시 source-repo 모드 no-op 종료 검증.
**커밋**: `refactor(structure): move 01-05.* and openspec/ to templates/project-init/`.

### Phase 0.E: CLAUDE.md/AGENTS.md slim 갱신 + 본 레포 dogfood (30분) — [BLOCKER-Critic1 분할 5/5]

- CLAUDE.md: 본 레포 작업용 규칙만 남기고 글로벌 룰은 `plugin/claude/rules/`로 참조.
- AGENTS.md: 동상.
- 본 레포 `/setup-both` 자기 검증 PASS.
- v0.2.0-alpha tag 발급 (rollback 안전망).

**게이트**: bats 45/45 + `/setup-both` 5/5 PASS.
**커밋**: `docs(structure): slim CLAUDE.md/AGENTS.md for global-tool repo + v0.2.0-alpha`.

### Phase 1: install.sh + update.sh + uninstall.sh (2~3시간)

- `install.sh` (2단 패턴 + `set -euo pipefail` + flock 머지 + 셸 jq atomic mv).
- `install.sh.sha256` CI/Release 자동 생성 워크플로.
- `scripts/update.sh`, `scripts/uninstall.sh`.
- `plugin/claude/settings.template.json` 작성.
- bats 12개+:
  - 첫 설치 (claude-only) / (--with-codex)
  - 재설치 / --update / --uninstall
  - settings.json 머지가 사용자 deny 룰 보존
  - 머지가 OMC 등록 hook 보존
  - 머지 실패 시 백업 자동 복원
  - flock 동시 실행 차단
  - dry-run / --from-tar / --target
  - 멱등 재실행 무해
- README의 한 줄 파이프 deprecate 명시.

**게이트**: bats 12/12 + 임시 dir E2E install → uninstall PASS.
**커밋**: `feat(install): 2-stage install/update/uninstall with flock+atomic merge`.

### Phase 2: `/pjt-init` (1.5~2시간)

- `plugin/claude/commands/pjt-init.md`.
- `scripts/pjt-init.sh` (strict/--merge/--force 3단 모드).
- `plugin/.claude-plugin/plugin.json` commands[] 갱신.
- bats 8개+:
  - 빈 디렉터리 strict / `.git/`만 / 충돌 strict fail / --merge / --force / --minimal / --with-codex / source-repo 모드 no-op.

**게이트**: bats 8/8 PASS. 임시 dir에서 `/pjt-init` → SessionStart 활성 E2E.
**커밋**: `feat(commands): add /pjt-init with 3-mode conflict handling`.

### Phase 3: 글로벌 SessionStart 훅 마커 분기 + OMC 공존 (1~1.5시간)

- session-start.sh PROJECT_CWD + source-repo 모드 마무리(이미 0.C에서 도입; 여기서는 강화).
- bats 10개+:
  - 마커+폴더 모두 있음 → 정상 컨텍스트
  - 마커만 / 폴더만 / 둘 다 없음 → 0 byte
  - 마커 손상 5종 → fail-safe
  - OMC 활성 디렉터리에서 본 하네스 0 byte
  - 합산 토큰 14K 이하
  - `CLAUDE_PROJECT_DIR` 주입 vs `$PWD` 폴백.

**게이트**: bats 10/10 PASS + 토큰 budget 측정 보고서.
**커밋**: `feat(hooks): finalize PROJECT_CWD branching + OMC token coexistence`.

### Phase 4: `/merge-skill --to-template` 보강 (2시간) — [BLOCKER-Critic2 + MAJOR-A-C]

- `plugin/claude/skills/merge-skill/SKILL.md`에 `--to-template` 옵션 보강.
- `scripts/sync-up-skill.sh` (5항 git 안전 검사 + secret 스캔 + confirm flow).
- bats 10개+:
  - 정상 역전파 (commit 안 함, stage만)
  - 사용자 confirm 후 commit
  - --auto-commit / --no-commit / --push / --dry-run
  - HEAD detached / dirty / main 아님 / identity 미설정 각각 fail-fast
  - secret 정규식 감지 4종 (api-key / private-key / AWS key / .env 파일)
  - secret false-positive 케이스(허용 패턴) 확인.

**게이트**: bats 10/10 PASS + secret 스캔 precision/recall 측정.
**커밋**: `feat(skills): add --to-template with secret scan + git safety + confirm flow`.

### Phase 5: 문서화 + v0.1.0 자산 보존 검증 보고서 (2~3시간)

- `README.md` 전면 재작성 (2단 패턴, /pjt-init, OMC 관계, 회사 PC 주의).
- `04.docs/INSTALL.md`, `MIGRATION-FROM-V0.1.md`, `MULTI-PC-SYNC.md`, `OMC-COEXISTENCE.md`, `ONBOARDING.md`.
- `04.docs/v0.1.0-asset-preservation.md` (§10-bis 매트릭스 검증 결과 7항).

**게이트**: §10-bis 매트릭스 7항 모두 PASS.
**커밋**: `docs: v0.2.0 install/migration/multi-pc/omc/onboarding + v0.1.0 asset preservation report`.

### Phase 6: 듀얼 PC 동기화 + 본 레포 dogfood (2시간)

- **Phase 6.A** (임시 dir 시뮬): install → /pjt-init → 로컬 스킬 → /merge-skill --to-template → push → 두 번째 임시 dir에서 update.sh → 일치.
- **Phase 6.B** (본 레포 자체 dogfood): `bats plugin/claude/hooks/tests/` 45/45 + `/setup-both` 5/5 + 본 레포 source-repo 모드 SessionStart 정상.
- **Phase 6.C** (사용자 실측, opt-in): 사용자가 실제 회사 PC에서 install 시도 1회 — 실패 시 v0.2.0 태그 보류.

**게이트**: 6.A + 6.B 모두 PASS. 6.C는 v0.2.0-rc 후 사용자 confirm.
**커밋**: `test(e2e): dual-pc + self-dogfood scenarios pass`.

### Phase 7: v0.2.0 태그 + RELEASE_NOTES + Cleanup (1시간)

- `04.docs/RELEASE_NOTES.md` (v0.2.0 변경 요약 + 마이그레이션 안내).
- 폐기 후보 정리(`scripts/clone-to-company.sh` → install.sh로 대체 결정).
- `package.json` version bump.
- `.harness-main-only` 유지.
- `git tag v0.2.0 && git push --tags`.
- GitHub Release 생성 (gh CLI).

**게이트**: 전체 Phase 0~6 게이트 통과 + 사용자 confirm.
**커밋**: `chore(release): v0.2.0 global tool model`.

### Phase 합계 시간 추정

- Phase 0.0~0.E: ~3.5시간 (0.0 30분 + 0.A 45분 + 0.B 60분 + 0.C 30분 + 0.D 30분 + 0.E 30분).
- Phase 1: 2~3시간.
- Phase 2: 1.5~2시간.
- Phase 3: 1~1.5시간.
- Phase 4: 2시간.
- Phase 5: 2~3시간.
- Phase 6: 2시간.
- Phase 7: 1시간.
- **합계 약 15~18시간** (Phase 0 5분할 + 각 게이트 + 부트스트랩 합의 루프 포함).

부트스트랩 합의 규약(v2 §7-bis): Phase 0~3은 유인 세션, 무인 `/build` 금지. Phase 4 이후 무인 가능.

---

## 10. 리스크 & 미확정 [열림]

### 10.1 기술 리스크

| # | 리스크 | 영향 | 완화 |
|---|--------|------|------|
| R1 | 글로벌 SessionStart 훅이 미사용 프로젝트 활성 | 컨텍스트 오염 | Phase 3 bats 10개 + 0 byte 종료 |
| R2 | settings.json 머지가 OMC/사용자 룰 손상 | OMC/보안 깨짐 | flock + 백업 + jq deep merge + bats 12개 |
| R3 | /merge-skill --to-template secret 노출 | 회사 자산 public 누출 | 기본 비자동 + 정규식 스캔 + README 경고 + fork 옵션 |
| R4 | 2단 install의 무결성 | MITM/변조 | sha256 옵션 + v0.3.0+ 의무화 |
| R5 | 회사 PC ~/.claude/ MDM 차단 | 설치 실패 | --target + Non-Goal 명시 |
| R6 | OMC 훅 동시 실행 토큰 폭발 | 7K budget 초과 | 본 하네스 비활성 시 0 byte + Phase 3 합산 측정 |
| R7 | CLAUDE_PROJECT_DIR 공식 미보장 시 PWD 결정성 | 마커 분기 불안정 | Phase 0.0 실측 + bats 4개 |
| R8 | secret 정규식 false-negative | 누출 사고 | trufflehog v0.3.0+ RFC + 사용자 책임 명시 |

### 10.2 사용자 확인 필요 [열림]

| # | 질문 | 옵션 | 추천 |
|---|------|------|------|
| Q-A | 글로벌 디렉터리 경로 | `~/.claude/plugins/nathaneast_aiacht/` (A) vs `~/.aiacht/` (B) | A (OMC 패턴 일치, Architect 동의) |
| Q-K | /pjt-init 기본 모드 | strict vs --merge | strict 유지 + --merge README 1순위 노출 |
| Q-L | install.sh sha256 의무화 시점 | v0.2.0 안내 / v0.3.0+ 의무 | v0.2.0 안내 |
| Q-M | 회사 PC 네트워크 환경 | 사용자 직접 확인 | 사용자 답변 대기 |
| Q-N | 회사 PC fork 운영 | 동일 레포 vs fork | fork [추천] (secret 사고 방지) |
| Q-O | CLAUDE_PROJECT_DIR 실측 결과 | Phase 0.0 후 닫힘 | BLOCKER 해결 후 닫힘 |
| Q-P | secret 스캔 정규식 정밀도 | Phase 4 후 측정 닫힘 | precision ≥ 0.9 목표 |
| Q-Q | learnings 위치 | 로컬 (확정) | — |

### 10.3 v3 → v4 [CLOSED] 결정

- [CLOSED] Q-A: A (OMC 패턴 일치).
- [CLOSED] Q-B (v3): /pjt-init 6개 폴더 전부 (strict 기본).
- [CLOSED] Q-D: B (본 레포 git mv).
- [CLOSED] Q-G: commit은 사용자 confirm 후, push는 안 함. `--auto-commit` opt-in.
- [CLOSED] Q-H: --with-codex 시 ~/.codex/ 자동 생성.
- [CLOSED] R6: 본 하네스 비활성 시 0 byte. 우선순위 API 워크어라운드는 v0.3.0+ RFC.

---

## 10-bis. v0.1.0 자산 보존 매트릭스 — `[확정]` (MAJOR-Critic9, Critic D)

| # | 자산 | 보존 위치 | 보존 검증 Phase | 게이트 |
|---|------|----------|---------------|--------|
| 1 | 13 skills | `plugin/claude/skills/` | Phase 0.A → 0.B → 0.E | bats 45/45 |
| 2 | 9 commands | `plugin/claude/commands/` | Phase 0.A → 0.E | bats 45/45 + commands count = 9(+1 신규 /pjt-init) |
| 3 | 45 bats tests | `plugin/claude/hooks/tests/` | Phase 0.B → 모든 Phase 게이트 | 매 Phase 종료 시 45/45 PASS |
| 4 | 7 KPI counters | `learn` 스킬 + `.omc/learnings/_history.jsonl` | Phase 0.B + Phase 5 | learn 스킬이 새 경로에서 동작 + counter 증분 검증 |
| 5 | /consensus 3단 폴백 | `plugin/claude/skills/consensus-loop/` | Phase 0.A + Phase 5 | SKILL.md 3단 폴백 절차 유효 + dogfood E2E |
| 6 | /resume-session 시나리오 A·B | `plugin/claude/skills/resume-session/` | Phase 0.A + Phase 5 | 시나리오 A(50 entries cap) + B(archive 본문 주입) 동작 |
| 7 | env-security 5단 화이트리스트 | `plugin/claude/skills/env-security/` + `plugin/claude/settings.template.json` deny | Phase 1 + Phase 5 | install 후 사용자 deny 룰 무손실 + env-security skill 발동 |

**Phase 5 종료 시 `04.docs/v0.1.0-asset-preservation.md` 검증 보고서 의무**.

---

## 11. KPI

### 11.1 v0.1.0 KPI 유지

| 영역 | 측정 지표 | 기준 |
|------|----------|------|
| 학습 회수 | learnings_recalled | ≥ 56회 (v0.1.0 실측치 보존) |
| 합의 첫 통과 | consensus_first_pass | ≥ 1 |
| 합의 루프 | consensus_loops_total | 추적 지속 |
| 더블체크 발동 | double_check_invoked | 추적 지속 |
| 미해결 | pending_unresolved | 추적 지속 |

### 11.2 v0.2.0 신규 KPI

| 영역 | 측정 지표 | 기준 |
|------|----------|------|
| 설치 성공률 | install bats 통과 | 12/12 = 100% |
| /pjt-init 성공률 | pjt-init bats 통과 | 8/8 = 100% |
| /merge-skill --to-template 성공률 | sync-up-skill bats 통과 | 10/10 = 100% |
| 듀얼 PC 동기화 latency | push 제외 update.sh 적용 | < 30초 |
| **회사 PC 변경 → 개인 맥 반영 push 누락 지연** | push 누락 사고 카운트 | 0건 (사용자 confirm 흐름 의무) |
| OMC 공존 토큰 합산 | SessionStart 합산 | < 14K |
| install 멱등 검증 | 동일 결과 checksum | 일치 |
| 본 레포 자체 dogfood | /setup-both 본 레포 | 5/5 PASS |

---

## 12. 트레이드오프 (정직한 자기 진단)

| 트레이드오프 | 선택 | 비용 | 이득 |
|------------|------|------|------|
| 한 줄 파이프 vs 2단 | 2단 | 1단계 추가 손 | 사용자 deny 룰 준수 + 무결성 검증 |
| Phase 0 단일 vs 5분할 | 5분할 | 작업 분량 증가 | rollback 단위 작음, bats 게이트 강제 |
| /merge-skill 자동 commit vs confirm | confirm 기본 | 자동화 한 단계 후퇴 | secret 사고 방지 (BLOCKER) |
| learnings 글로벌 vs 로컬 | 로컬 | 듀얼 PC 자동 동기화 없음 | 프로젝트 컨텍스트 정합, 회사/개인 자산 격리 |
| 본 레포 source-repo 모드 | 마커 1행 키워드 | 마커 포맷 복잡도 ↑ | self-dogfood 회귀 0 |
| jq deep merge vs 수동 키 add | deep merge | jq 버전 의존 | OMC/사용자 deny 무손실 |
| strict vs --merge 기본 | strict 기본 | 점진 도입 어려움 | 의도 외 덮어쓰기 0 |
| `~/.claude/plugins/...` vs `~/.aiacht/` | OMC 패턴 일치 | 경로 길음 | 사용자 익숙도 + 충돌 0 |

---

## 13. 다음 단계

1. **Architect 2차 검토** (`/codex:adversarial-review --wait` 또는 Claude opus): BLOCKER 0건, MAJOR 2건 이하 통과 목표.
2. **Critic 2차 검토** (codex adversarial-review): 6 BLOCKER 모두 해소 확인, 회귀 0건 검증.
3. **사용자 confirm**: Q-M (회사 PC 네트워크), Q-N (회사 PC fork) 두 항목만.
4. **Planner v5**(필요 시): 2차 검토 통과 시 생략, 미통과 시 추가 통합.
5. **Phase 0.0 착수**: `CLAUDE_PROJECT_DIR` 실측 + deny 룰 인벤토리.

### Architect+Critic 2차 집중 검토 영역 권고

1. **§5 cwd 인식 + source-repo 마커 모드** — paths.sh 추상화 lib + Phase 0.0 실측이 BLOCKER-A1을 충분히 해소했는가? 본 레포 dogfood가 source-repo 모드 키워드 한 줄로 충분한가?
2. **§4 2단 install + flock 머지** — jq deep merge가 OMC + 사용자 deny 룰을 정확히 보존하는지 Phase 1 bats 12개로 검증 충분한가? `--from-tar` air-gapped fallback이 실효성 있는가?
3. **§7 secret 스캔 정규식 5종** — false-positive(legit한 `api_key=$(cat ...)` 변수 할당) / false-negative(base64 인코딩된 키) 경계 어디? trufflehog 즉시 도입 vs v0.3.0+ RFC?
4. **§9 Phase 0 5분할 게이트** — 각 sub-phase 종료 시 bats 45/45 강제가 너무 엄격해 0.B 60분이 실제로는 2시간 이상 되지 않는가? paths.sh 추상화의 9개 스크립트 갱신이 한 commit에 묶이는 게 적절한가, 더 잘게 쪼개야 하는가?
5. **§10-bis 자산 보존 매트릭스 7항** — 7개 자산 모두 Phase 0.E 종료 시점에서 새 경로에서 동작 검증이 가능한가? 검증 누락 가능성?
6. **R8 secret false-negative** — Phase 4 정규식이 충분치 않다면 v0.2.0 출시 차단 vs trufflehog v0.3.0+ 이관 — 사용자 결정?
7. **Q-N 회사 PC fork** — fork 운영 시 개인 맥과의 동기화 복잡도 vs secret 사고 방지 trade-off를 사용자에게 어떻게 제시할 것인가?

---

## 14. 핵심 변경 10개 (v3 → v4 한눈 요약)

1. **§5 PROJECT_CWD 도입 + Phase 0.0 CLAUDE_PROJECT_DIR 실측** (BLOCKER-A1).
2. **§4 한 줄 파이프 폐기, 2단(`curl -o + bash`) 의무 + 사용자 deny 룰 준수** (BLOCKER-A2).
3. **§9 Phase 0을 0.0 + 0.A~0.E 6분할 + 각 sub-phase bats 45/45 게이트** (BLOCKER-Architect F / Critic 1).
4. **§3 + §9 `scripts/lib/paths.sh` + `plugin/claude/hooks/lib/paths.sh` 경로 추상화 도입** (BLOCKER-Critic1).
5. **§7 /merge-skill --to-template 기본 confirm 후 commit + secret 정규식 스캔 + 회사 PC 경고 + `--auto-commit` opt-in** (BLOCKER-Critic2).
6. **§3.5 + §6.4 본 레포 `.harness-active`에 `mode=source-repo` 표기 + SessionStart 훅이 source-repo 모드 분기 + /pjt-init no-op** (BLOCKER-Critic3).
7. **§7.2 글로벌 git 사전 안전 검사 5항(detached/dirty/branch/identity/rebase) + 8.4 자동 rebase 시도** (MAJOR-A-C).
8. **§4.4 install.sh 멱등성 + --uninstall 백업 복원 + --from-tar air-gapped fallback** (MAJOR-Architect G + Critic 3.1).
9. **§10-bis v0.1.0 자산 보존 매트릭스 7항 + Phase 5 종료 검증 보고서 의무** (MAJOR-Critic9 / D).
10. **§9 각 Phase 시간 추정 명시 + 합계 15~18시간 + 부트스트랩 합의 규약(0~3은 유인) 계승** (MAJOR-Critic8.2).

---

**문서 끝. Architect+Critic 2차 검토 후 BLOCKER 0건 / MAJOR ≤ 2건 통과 시 Phase 0.0 착수.**
