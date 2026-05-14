# Harness Template MVP — Planner v2 (합의 통합본)

> **문서 역할**: ralplan 합의 사이클 3단계 산출물. Architect+Critic 1차 검토 결과(BLOCKER 5건 + CONCERN 다수)를 통합한 v2.
> **표기 규칙**: `[확정]` = 사용자 6개 답변으로 닫힌 결정(뒤집기 금지). `[열림]` = 추가 검증/결정 필요. `[추천]` = Planner 의견(근거 동반). `[B#]` = Architect/Critic이 식별한 BLOCKER 해결 표식. `[P#]` = Architect 패치 표식. `[C#]` = Critic 영역 대응 표식.
> **작성자**: Planner v2 | **작성일**: 2026-05-13
> **v1 대비 변경 요약**: §0(신규 가치-메커니즘 매핑), §4-bis(신규 Non-Goals), §5-bis(신규 KPI), §7-bis(신규 부트스트랩 합의 규약), §7.6-bis(신규 /resume-session 실측 검증), §9 Phase 0 5분할 [B2], §10.3 `--skip-codex` 제거 [B1+B5], §11(신규 Dogfooding), §12(신규 부트스트랩 안정성), 7개 패치 P1~P7 인라인 반영.

---

## 0. 핵심 가치-메커니즘 매핑 (신규, C1 대응)

> v2 변경: §0 추가 — prompt.md의 3가지 핵심 가치가 어떤 메커니즘으로 충족되는지 명시. (Critic 영역 1 대응)

| 사용자 약속 (prompt.md) | 충족 메커니즘 | 측정 가능 KPI (§5-bis) | 1차 검증 시점 |
|---|---|---|---|
| **"사용할수록 영리해진다"** | (1) SessionEnd 훅이 `/learn`을 자동 트리거 → `.omc/learnings/{patterns,pitfalls,preferences,glossary}.md` append. (2) SessionStart 훅이 매 세션 자동 회수해 컨텍스트 주입. (3) `.omc/learnings/_metrics.json`에 (적용 학습 수, confirm 비율, 충돌 해결 수) 누적. | learnings 적중률(주간), 신규 학습 누적 속도, 사용자 confirm 비율 | Phase 2 종료 (P2 dogfood) |
| **"1번 프롬프트로 A-Z 미니멀하게"** | `/build "PRD 기반"` 한 줄 → ralph + wrapper 가드 셸이 iteration마다 `/openspec-propose` → TDD Red/Green (tdd-guide) → `/consensus` (codex-plugin-cc) → Task 단위 커밋 → `/openspec-apply-change`을 **자동 강제**. wrapper 책임 명시(`scripts/build-iteration-gate.sh`). | `/build` 1회 실행 시 사용자 개입 횟수, 자동 완료율, Codex 합의 1회 통과율 | Phase 9 종료 (P9 dogfood) |
| **"내일부터 쓸 수 있는 미니멀·파워풀"** | **MVP-A**(Phase 0~3): 셋업 + 학습 + 의도 분해 + 프롬프트 아카이브. **MVP-B**(Phase 0~5): + /consensus + /resume-session. **MVP-A는 "쓸 수 있다", MVP-B가 "파워풀하다".** | MVP-A 5개 사용자 시나리오 통과율(§11), MVP-B 자동 빌드 1회 성공 | MVP-A=Phase 3, MVP-B=Phase 5 |

**Trade-off**: 가치-메커니즘 매핑을 명시하면 "어디까지가 미니멀인가" 논쟁이 줄어들지만, 측정 KPI를 도입하면 `_metrics.json` 관리 부담이 추가됨. Phase 2에서 가장 단순한 카운터 3개만 우선 도입.

---

## 1. 비전 한 문단

**`ai-agent-coding-template`은 Claude Code와 Codex 두 CLI에서 동일하게 동작하는 "단일 진실의 개발 하네스(Single-Source Harness)"다.** 사용자의 모든 작업 규칙(브랜치/TDD/합의 루프/환경 분리)을 한 곳에서 선언하고, SessionStart 훅으로 매 세션 강제 주입하며, `/learn`으로 사용할수록 사용자에게 핏해지고, `/consensus` 한 줄로 Claude-Codex 합의 루프를 자동화하며, `/build` 한 줄로 PRD부터 배포까지 8~10시간 자동 빌드한다. ksbc 3종의 검증된 폴더 골격(`01.spec`~`05.tasks` + OpenSpec)을 기본 뼈대로 삼고, superpowers의 SessionStart 훅 + `.claude-plugin/`/`.codex-plugin/` 분리 패턴(5.0.7 검증)과 gstack의 `/learn` 영속성을 결합해 "미니멀하지만 파워풀하게" 만든다. **이 하네스 자체가 자신의 강제 규칙(TDD + 합의 루프 + Task 단위 즉시 커밋)을 따라 만들어진다 (dogfooding).**

---

## 2. 최종 폴더 구조

> v2 변경: 본문 동일. plugin.json 스키마는 §3.4에서 `entry` 필드 제거 (P5 반영).

### 2.1 루트 트리 (`[확정]` 굵게 표기)

```
ai-agent-coding-template/
├── .claude/                              # [확정] Claude Code 전용 런타임 디렉터리
│   ├── settings.json                     # 글로벌 권한/훅/env (커밋 대상)
│   ├── settings.local.json               # 개인 오버라이드 (gitignore)
│   ├── hooks/                            # [확정] 훅 스크립트
│   │   ├── session-start.sh              # 세션 시작 시 컨텍스트 자동 주입
│   │   ├── session-end.sh                # 세션 종료 시 /learn 트리거 + 인덱스 업데이트
│   │   ├── post-tool-prompt-archive.sh   # 프롬프트 자동 아카이빙
│   │   ├── run-hook.cmd                  # [신규 P4] superpowers 패턴: polyglot 진입점 (선택)
│   │   └── lib/                          # 공용 셸 유틸 (jq/지연감쇄/JSON 파서)
│   ├── commands/                         # [확정] 슬래시 커맨드 정의
│   │   ├── setup-claude.md
│   │   ├── setup-codex.md
│   │   ├── setup-both.md
│   │   ├── double-check.md
│   │   ├── merge-skill.md
│   │   ├── consensus.md
│   │   ├── resume-session.md
│   │   └── build.md
│   ├── skills/                           # [확정] 스킬 정의 (`{name}/SKILL.md` 형식)
│   │   ├── branch-strategy/SKILL.md
│   │   ├── tdd-loop/SKILL.md
│   │   ├── consensus-loop/SKILL.md
│   │   ├── env-security/SKILL.md
│   │   ├── prompt-archive/SKILL.md
│   │   ├── session-index/SKILL.md
│   │   ├── learn/SKILL.md
│   │   ├── openspec-propose/SKILL.md
│   │   ├── openspec-apply-change/SKILL.md
│   │   ├── openspec-archive-change/SKILL.md
│   │   └── openspec-explore/SKILL.md
│   ├── rules/                            # [확정] ksbc 표준 골격
│   │   ├── workflow.md
│   │   ├── branch-strategy.md
│   │   ├── security.md
│   │   ├── sdd-openspec.md
│   │   ├── tdd.md
│   │   └── browser-automation.md
│   └── projects/                         # Claude Code 내부 캐시 (gitignore)
│
├── .codex/                               # [확정] Codex CLI 전용 런타임 디렉터리
│   ├── config.toml                       # [P4] `[features] codex_hooks = true` 만
│   ├── hooks.json                        # [P4 신규] hooks는 별도 파일 (v0.124.0 TOML 버그 회피)
│   ├── hooks/                            # Codex 훅 스크립트 (Claude 본체 호출 래퍼)
│   │   ├── session-start.sh
│   │   └── lib/                          # → ../../.claude/hooks/lib 재사용
│   ├── prompts/                          # Codex 슬래시 커맨드 (Codex 포맷)
│   │   ├── setup-codex.md
│   │   ├── double-check.md
│   │   ├── consensus-replier.md
│   │   └── resume-session.md
│   └── skills/                           # 심볼릭 또는 codex-compatible 어댑터
│
├── .claude-plugin/                       # [확정] Claude Code 플러그인 마켓플레이스 메타
│   └── plugin.json                       # [P5] entry 필드 제거, 컨벤션 디렉터리 사용
│
├── .codex-plugin/                        # [확정] Codex 플러그인 마켓플레이스 메타
│   └── plugin.json                       # [P5] skills 경로 + interface 필드 추가
│
├── .omc/                                 # [확정] 통합 영속 메모리
│   ├── learnings/
│   │   ├── patterns.md
│   │   ├── pitfalls.md
│   │   ├── preferences.md
│   │   ├── glossary.md
│   │   ├── _metrics.json                 # [C1 신규] 영리해짐 KPI 카운터
│   │   ├── _pending.jsonl                # [C5 신규] 무인 빌드 시 보류 학습
│   │   └── _archive/                     # [P7 신규] 자동 트림된 항목
│   │       └── {YYYY-MM}.md
│   ├── sessions/                         # /resume-session N 지원
│   │   ├── index.json
│   │   └── archive/
│   │       └── {YYYY-MM-DD}-{sessionId}.md
│   ├── state/                            # OMC 모드 상태
│   │   └── USER_CONFIRM_NEEDED          # [B5 신규] 무인 빌드 Codex 장애 마커 (있을 때만)
│   ├── plans/                            # ralplan 산출물
│   ├── notepad.md
│   ├── project-memory.json
│   └── logs/
│
├── _dogfood/                             # [C-D 신규] Phase 3 종료 후 더미 프로젝트 검증용
│   └── (Phase 3 종료 시 생성, .gitignore에서 _dogfood/는 commit 대상)
│
├── 01.spec/                              # [확정] 기획/설계 산출물 (ksbc 패턴)
├── 02.workflow/                          # [확정] 워크플로우 SOP
├── 03.archive/                           # [확정] 완료 작업 + 자동 아카이브 프롬프트
├── 04.docs/                              # [확정] 운영 문서
├── 05.tasks/                             # [확정] 진행 중 작업
├── openspec/                             # [확정] OpenSpec 도입
├── policy/                               # [기존 유지, Phase 6에서 마이그레이션 후 DEPRECATED.md stub]
├── scripts/
│   ├── setup-claude.sh
│   ├── setup-codex.sh
│   ├── setup-both.sh
│   ├── clone-to-company.sh               # [P6 강화]
│   ├── merge-skill.sh
│   ├── sync-skills-to-codex.sh
│   ├── build-iteration-gate.sh           # [P3 신규] /build wrapper 가드
│   ├── install-env-guard.sh              # [C-A 신규] 회사계정 .env 가드 자동 설치
│   ├── trigram-jaccard.sh                # [P2 신규] fuzzy match (30줄)
│   └── consensus-cleanup.sh              # [§10 E] Ctrl+C 시 안전 종료
│
├── CLAUDE.md
├── AGENTS.md
├── README.md
├── .gitignore
└── package.json                          # bats-core 등 테스트 러너 의존성 명시 [C3]
```

### 2.2 결정 트리 (v1 유지, 변경 없음)

루트 직접 배치(ksbc), 도구별 분리(.claude/.codex/), 도구 중립 위치(.omc/), 플러그인 분리(.claude-plugin/.codex-plugin/) — 모두 v1 동일.

### 2.3 `[열림]` 폴더 결정 (변경 없음)

`.omc/` vs `.omx/`, policy 일원화 시점, package.json 도입 — v1 동일하게 추천 유지.

---

## 3. 듀얼 모델 어댑터 (Q1=B 비대칭) 설계

> v2 변경: §3.4에서 plugin.json `entry` 필드 제거 (P5 반영). §3.2 합의 종결 신호에 VERDICT 폴백 추가 (C4 대응).

### 3.1 역할 분담 `[확정]`

- **Claude (메인 워커)**: 코드 작성, 리팩토링, 디버깅, 테스트 작성, 커밋. `SessionStart` 훅으로 모든 규칙·학습·세션 인덱스 컨텍스트 자동 주입.
- **Codex (리뷰어 전담)**: 작성된 디프/설계를 비판적으로 검토. **`codex-plugin-cc` 스킬 경유 의무** (`/codex:review --wait`, `/codex:adversarial-review --wait`). 단, **부트스트랩 기간(Phase 0~3)은 §7-bis 임시 우회 규약 적용**. [B4]

### 3.2 합의 루프 자동화 (`/consensus`) `[확정, 부분 수정]`

```
User: /consensus "유저 인증 페이지 구현"
   ↓
Step 1. Claude가 TDD Red(테스트 실패) 작성  → 커밋 후보 1
Step 2. Claude가 TDD Green(구현 통과)        → 커밋 후보 2
Step 3. /codex:review --wait (codex-plugin-cc 경유)  → Codex 피드백 보고서
Step 4. Claude가 피드백 반영                  → 커밋 후보 3
Step 5. /codex:review --wait (재리뷰)
Step 6. 합의 도달 시 Task 단위 커밋
        합의 실패 N=4회 누적 시 사용자 confirmation 요청
```

**합의 종결 신호 (C4 대응)**:
- 1차 시도: Codex 응답 마지막 줄에 `VERDICT: APPROVE|REQUEST_CHANGES` 토큰 명시 의무화 (prompt template에 삽입).
- VERDICT 추출 실패 시 폴백 (3단):
  1. `RECOMMENDATION:|FINAL:|결론:` 등 동의어 토큰 매칭
  2. 응답 본문에 "no further changes|approve|승인|합의" 키워드 존재 → APPROVE 추정 후 사용자 1회 confirm
  3. 위 둘 모두 실패 → REQUEST_CHANGES로 안전하게 처리 (다음 루프 진행)
- 호출 메커니즘은 [열림] 항목: `codex-plugin-cc` 스킬을 슬래시 chain으로 호출하는지, 셸 `claude -p "/codex:review --wait"`인지 Phase 4 초반 Architect 실측 (§7-bis 검증 대상).

**Trade-off**: VERDICT 토큰 강제는 Codex 응답 형식 강제 비용이 있지만, 자유 텍스트 파싱 실패 위험을 제거. 폴백 3단을 두면 안전하나 코드 복잡도 증가.

### 3.3 하나의 스킬 파일이 양쪽에서 작동하는 메커니즘 `[확정]`

- **단일 진실 소스**: `.claude/skills/{name}/SKILL.md` (마크다운, frontmatter 포함).
- **Codex 어댑터 레이어**: `scripts/sync-skills-to-codex.sh`가 변환·복제 (Phase 7).
- **공통 어댑터 인터페이스** (v1 동일):
  ```yaml
  ---
  name: consensus-loop
  description: Claude작업 → Codex리뷰 → 합의 루프
  triggers: ["consensus", "합의", "review"]
  inputs: { task: "string" }
  outputs: { commitHash: "string", consensusReached: "boolean" }
  ---
  ```

### 3.4 `.claude-plugin/` / `.codex-plugin/` 메타데이터 (P5 반영) `[확정]`

v1의 `entry.{commands,skills,hooks,rules}` 필드는 공식 스키마에 없음. **컨벤션 디렉터리만 사용**.

```json
// .claude-plugin/plugin.json
{
  "name": "ai-agent-harness",
  "version": "0.1.0",
  "description": "개인 맞춤형 개발 하네스 — Claude+Codex 양립",
  "author": { "name": "...", "email": "ceo@yunjadong.com" },
  "homepage": "https://github.com/{personal-account}/ai-agent-coding-template",
  "repository": "https://github.com/{personal-account}/ai-agent-coding-template",
  "license": "MIT",
  "keywords": ["harness", "tdd", "consensus", "claude-code", "codex"],
  "requires": {
    "claude-code": ">=2.0.0",
    "codex-plugin-cc": ">=0.1.0"
  }
}
```

`.codex-plugin/plugin.json`은 추가로 `"skills": "./skills/"`와 `"interface": {...}` 필드 (superpowers 5.0.7 패턴).

디렉터리는 plugin 루트 기준 자동 인식: `commands/`, `skills/`, `hooks/`, `agents/`.

**Trade-off**: entry 필드 제거 시 의도 명시성은 약해지나 공식 스키마 준수로 마켓플레이스 등록 PR 통과 확률 ↑.

---

## 4. SessionStart 훅 자동 주입 (Q2=A) 설계

> v2 변경: §4.2 Codex 등록 분기 명시 (P4 반영). 신뢰 모델·matcher 차이·v0.124.0 버그 회피 명시.

### 4.1 형식 결정 `[확정]`

- **`hooks/session-start.sh`** (POSIX 셸). macOS 기본 도구(`jq`, `awk`, `sed`).
- 출력: stdout으로 마크다운 → Claude/Codex가 컨텍스트로 자동 흡수.

### 4.2 hooks 등록 — Claude vs Codex 분기 (P4 반영) `[확정]`

**Claude 등록** (`.claude/settings.json`):
```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|clear|compact|resume",
        "hooks": [{ "type": "command", "command": "bash .claude/hooks/session-start.sh" }] }
    ],
    "SessionEnd": [
      { "matcher": "*",
        "hooks": [{ "type": "command", "command": "bash .claude/hooks/session-end.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "UserPromptSubmit",
        "hooks": [{ "type": "command", "command": "bash .claude/hooks/post-tool-prompt-archive.sh" }] }
    ]
  }
}
```

**Codex 등록** [Architect 검증 완료]:
1. `.codex/hooks.json` **별도 파일**에 hooks 등록 (config.toml 내부 두면 v0.124.0 TOML 파싱 오류, issue #19199).
2. `.codex/config.toml`에 `[features] codex_hooks = true` 추가 (enable flag).
3. matcher는 **`startup|resume`로만 보수 등록** (Claude의 `clear|compact` 토큰은 Codex 미지원 추정).
4. `/setup-codex`가 `codex trust .` 안내 또는 자동 실행 (project-local hooks 신뢰 게이트).
5. hooks 진입점은 superpowers 패턴(`hooks/run-hook.cmd` 폴리글롯 단일 분기)을 선택 채용 — 단, macOS 단일 환경이면 POSIX `bash` 직접 호출도 충분 [열림].

**환경변수 차이** [열림]: `CLAUDE_PLUGIN_ROOT` vs `CODEX_PLUGIN_ROOT`. `hooks/lib/dispatch.sh`가 양쪽 감지하여 자기 위치 찾도록 구현.

**Trade-off**: Codex hooks.json 분리는 v0.124.0 버그 회피의 강제 비용이나, 다음 Codex 버전에서 통합되면 단순화 가능 (Phase 9 RFC).

### 4.3 자동 주입 핵심 스킬 목록 `[추천]`

v1 동일. 5개 한정: `branch-strategy`, `tdd-loop`, `consensus-loop`, `env-security`, `session-index`.

세션 시작 시 추가 주입 동적 컨텍스트 (P7 반영):
- `.omc/learnings/preferences.md` (전체, 200줄 상한)
- `.omc/learnings/pitfalls.md` (전체, 200줄 상한)
- `.omc/learnings/patterns.md` 최근 100줄
- `.omc/learnings/glossary.md` 최근 100줄
- `.omc/sessions/index.json` 최근 5개 세션 요약
- `05.tasks/todo.md` 현재 진행 항목
- `.omc/learnings/_metrics.json` 지난 7일 요약 (C1 신규)

### 4.4 명시 호출 전용 스킬 (Lazy load) `[추천]`

v1 동일: `openspec-*`, `browser-automation`, `prompt-archive`(자동 작동).

### 4.5 컨텍스트 폭발 방지 정책 (P7 반영) `[추천]`

- 자동 주입 총 토큰 상한: **7K 이내** (보수). 실측 ~5,700 토큰 (Architect §B).
- 카테고리별 자동 트림 임계 (SessionEnd 시):
  - preferences/pitfalls: 각 **200줄** 상한
  - patterns/glossary: 각 **100줄** 상한
  - 초과분 → `.omc/learnings/_archive/{YYYY-MM}.md`로 자동 이동 (append-only)
- SessionStart 출력 끝에 `[ctx-budget] approx ~XYZK tokens` 로깅 (사용자 모니터링용).

---

## 4-bis. Non-Goals (명시적 거부) (신규, C-C 대응)

> v2 변경: §4-bis 추가 — 미니멀이 되려면 "안 한다"를 명시. (Critic 영역 C 대응)

이 하네스가 **의도적으로 안 하는 것**:

1. **gstack 수준 70+ 스킬 패키지 안 함**. MVP는 11~12개 스킬만(자동 주입 5 + 명시 호출 6~7).
2. **GBrain DB 안 함**. learnings는 단순 마크다운 + JSON. SQLite/벡터DB 미도입.
3. **supabase 텔레메트리 안 함**. 모든 데이터 로컬 파일.
4. **멀티 워커(parallel multi-Claude) 안 함**. ralph 자동 빌드는 기본 직렬. `--parallel`은 사용자 명시 옵션.
5. **자동 PR 머지 안 함**. `/build` 결과는 PR 생성까지. 머지는 사용자 결정.
6. **IDE 통합 안 함** (VSCode extension, JetBrains 등). CLI 두 개만 지원.
7. **웹 UI 안 함**. 모든 상호작용 CLI.
8. **Windows 1차 지원 안 함**. macOS/Linux POSIX 단일. Windows는 WSL 권장.
9. **마켓플레이스 동시 등록 안 함** (Phase 9 한정). v0.1.0은 개인계정 GitHub 레포만. 마켓플레이스 등록은 v0.2.0+.
10. **Codex 외 외부 LLM 어댑터(Gemini, Claude API direct) 안 함**. Q1=B 비대칭 유지.
11. **자체 빌드 루프 구현 안 함** (ralph 통합). 단, wrapper 가드 셸은 직접 구현 (P3).
12. **OpenSpec 외 spec 도구 통합 안 함** (RFC 형식, Spec-First-AI 등).

**Trade-off**: Non-Goals 명시는 사용자 기대를 조정하나, 향후 확장 시 RFC 절차 필요 → Phase 9 이후 RFC 템플릿 `04.docs/RFC-TEMPLATE.md` 추가.

---

## 5. `/learn` + `.omc/learnings/` 영속성 (Q3=A) 설계

> v2 변경: §5.4 자동 트림 임계 명시 (P7), §5.5 무인 모드 _pending.jsonl 추가 (C5 대응).

### 5.1 학습 파일 형식 `[확정]` (v1 동일)

```markdown
<!-- .omc/learnings/preferences.md -->
## 2026-05-13 P:high
사용자는 `pnpm` 대신 `npm`을 선호. 의존성 추가 시 항상 `npm install`.
```

### 5.2 세션 종료 트리거 `[확정]` (v1 동일)

- `SessionEnd` 훅: 무인 자동 트리거.
- 명시 `/learn` 커맨드: 사용자 즉시 학습 저장.

### 5.3 세션 시작 시 회수 `[확정]` (v1 동일, §4.3 통합)

### 5.4 자동 트림 임계 (P7 반영) `[확정]`

가중치 감쇄는 Phase 2 미도입. 대신 카테고리별 자동 트림:
- preferences/pitfalls: 각 **200줄** 초과 시 오래된 항목 → `.omc/learnings/_archive/{YYYY-MM}.md` 이동
- patterns: **100줄** 초과 시 동일
- glossary: **100줄** 초과 시 동일
- LRU 우선순위: P:low 먼저, 다음 timestamp 오래된 순

[열림] 정확한 트림 알고리즘(라인 수 단순 vs 토큰 수 정밀): Phase 2 초반 사용자 확인.

### 5.5 충돌 시 사용자 승인 절차 + 무인 모드 (C5 대응) `[확정]`

**유인 모드** (사용자 세션 중 SessionEnd):
- 후보 diff 출력 → `(k)eep / (r)eplace / (m)erge / (s)kip` 즉시 confirm

**무인 모드** (ralph/`/build` 중 SessionEnd):
- `.omc/learnings/_pending.jsonl`에 후보를 보류로 append-only 저장 (timestamp + 카테고리 + 본문)
- **다음 인간 세션 시작 시 SessionStart 훅이 _pending.jsonl 검사** → "보류 학습 N건 있습니다. 일괄 검토하시겠습니까?" 알림
- 사용자가 일괄 confirm 또는 개별 처리 → 결정 즉시 `_history.jsonl` append-only 이력

**Trade-off**: _pending.jsonl 보류는 무인 빌드 안전성 ↑이나, 사용자 부담(검토 누적) ↑. 7일 미검토 시 자동 만료(`_archive/expired/`) 정책 추가.

---

## 5-bis. "영리해짐" KPI (신규, C1 대응)

> v2 변경: §5-bis 추가 — 측정 가능한 영리해짐 지표. (Critic 영역 1 대응)

`.omc/learnings/_metrics.json` 카운터 3~5개:

| KPI | 정의 | 목표(MVP-A 종료) | 목표(MVP-B 종료) |
|---|---|---|---|
| **learnings 적중률** | SessionStart 주입 learning 중 해당 세션에서 실제 참조된 비율 | ≥ 30% | ≥ 50% |
| **/double-check 회수율** | /double-check 호출 후 사용자가 의도 정정한 비율 | ≥ 20% (의도 분해 가치 입증) | 유지 |
| **/consensus 1회 통과율** | 첫 번째 review에서 APPROVE 도달 비율 | n/a (Phase 4 이후) | ≥ 40% |
| **신규 학습 누적 속도** | 주간 새 learnings 항목 수 | ≥ 3건/주 | ≥ 5건/주 |
| **무인 _pending 검토 처리 비율** | _pending.jsonl 항목 중 7일 내 처리 비율 | n/a | ≥ 80% |

매 SessionStart 시 "지난 7일 너에 대해 X개 배웠다, 적중률 Y%, /double-check Z회 사용" 출력.

**Trade-off**: KPI 도입은 영리해짐을 수치화하나, 카운터 갱신 로직이 SessionEnd 훅에 추가됨. 실패 시 영향 없도록 best-effort(에러 무시).

---

## 6. OpenSpec + 01.spec~05.tasks 통합 (Q4=A) 설계

> v2 변경: §6.4 단방향 강제 자동 가드 추가 (Architect §D CONCERN 대응).

### 6.1 폴더별 역할 `[확정]` (v1 동일)

### 6.2 `01.spec/` vs `openspec/specs/` 역할 분리 `[확정]` (v1 동일)

### 6.3 `task/`(folder.md) vs `05.tasks/`(ksbc) 충돌 해결 (v1 동일)

### 6.4 단방향 흐름 자동 가드 (D 대응) `[확정]`

`.claude/rules/sdd-openspec.md`에 **금지 규칙** 명시: "openspec/specs를 직접 편집 금지. 항상 openspec/changes 경유."

`PostToolUse` 훅에서 `openspec/specs/*.md` 직접 편집 감지 시 **경고 출력** (차단까지는 안 함, 알림만). 이유: 사용자가 의도적으로 specs 직접 편집할 합당한 경우(typo 등) 존재 가능. 1회 확인 후 진행.

**Trade-off**: 차단까지 안 함 → 가드 강도 약화. 그러나 차단 시 false positive 위험. 알림만으로 충분 (사용자가 인지하면 행동 변화).

---

## 7. 7개 MVP 커맨드 사양 (Q5=ALL)

> v2 변경: §7.7 `/build` ralph wrapper 명세 강화 (P3). 호출 메커니즘 [열림] 명시.

### 7.1 `/setup-claude`, `/setup-codex`, `/setup-both`

v1 동일. 추가:
- `/setup-codex`는 (a) `codex trust .` 안내 또는 자동 실행 (b) `[features] codex_hooks = true` 자동 추가 (c) `~/.claude/hooks/branch-guard.sh` 부재 시 `scripts/install-env-guard.sh` 실행 권장 (C-A).

### 7.2 `/double-check` (v1 동일)

### 7.3 자주 쓰는 프롬프트 자동 아카이빙

v1 동일, fuzzy match 알고리즘 확정:
- **trigram + Jaccard ≥ 0.7** (P2, Architect 검증 완료). simhash는 Phase 9 이후 RFC.
- 구현: `scripts/trigram-jaccard.sh` (POSIX 셸 ~30줄).
- 임계: 3회 (v1 추천 유지).
- 시크릿 마스킹: `.env` 값/API key 정규식 자동 마스킹 (`s/[A-Z0-9_]+_TOKEN=.*/[REDACTED]/g` 등).

### 7.4 `/merge-skill <path>` (v1 동일)

### 7.5 `/consensus "task description"` (§3.2 통합)

### 7.6 `/resume-session <n>` (problem.md 해결) — §7.6-bis 검증 단계 신설

§7.6-bis 참조. v1의 "안내 출력"이 problem.md를 진짜 해결하는지 Phase 5 첫 Task에서 실측 검증 후 대안 설계 분기.

### 7.7 `/build "PRD 기반 A-Z 자동화"` (P3 반영, [B1+B5] 통합)

- **트리거**: `/build "01.spec/prd.md 기반 전체 구현"`
- **입력**: task 설명, 선택적 `--hours N`
- **출력**: 자동 빌드 후 최종 보고서 + PR 링크
- **위치**: `.claude/commands/build.md` + 스킬
- **의존**: OMC `ralph` 스킬 + **wrapper 가드 셸** (`scripts/build-iteration-gate.sh`) + `consensus-loop` + `openspec-*`
- **알고리즘 (P3 wrapper 명세)**:
  ```
  /build:
    1. PRD 파싱 → 유저스토리 추출
    2. /ralph 호출 (TDD/consensus/openspec은 ralph가 자동 강제하지 않으므로 wrapper 책임)
       각 iteration:
         a. 다음 Task 선택 (05.tasks/todo.md 또는 openspec/changes 기반)
         a-1. scripts/build-iteration-gate.sh pre-task → /openspec-propose 자동
         b. TDD Red 작성
         b-1. tdd-guide 에이전트 확인 (Red 상태 검증)
         c. TDD Green 작성
         c-1. tdd-guide 에이전트 확인 (Green 상태 검증)
         d. /consensus 자동 호출 (내부 합의 루프 max 3)
         d-1. /codex:review --wait 자동 (consensus-loop SKILL 통해, codex-plugin-cc 경유)
         e. 커밋 + 03.archive로 task 이동
         e-1. /openspec-apply-change 자동 → openspec/specs 갱신
         f. SessionEnd 훅이 learnings 갱신 (무인 모드 → _pending.jsonl)
    3. 종료 조건: todo.md 비어있음 / 사용자 cancel / 최대 시간 도달 / Codex 장애 3단 폴백 도달 (§10.3)
    4. 최종 보고서
  ```
- **Codex 장애 무인 정책 (§10.3 [B1+B5])**: `--skip-codex` 제거. 3단 폴백.

**Trade-off**: wrapper 가드는 ralph 본체 미변경으로 OMC 호환성 유지. 단, wrapper 자체에 버그 시 자동 빌드 차단 위험 → `scripts/build-iteration-gate.sh`는 Phase 9에서 bats 단위 테스트 의무.

---

## 7-bis. 부트스트랩 합의 규약 (Phase 0~3) (신규, B4 대응)

> v2 변경: §7-bis 추가 — `/consensus` 인프라가 없는 동안의 임시 합의 절차. (Critic 영역 3 BLOCKER 대응)

CLAUDE.md는 모든 작업에 합의 루프 강제. 그런데 Phase 0~4가 그 합의 인프라(`/consensus` 스킬)를 만든다 → 닭-달걀.

**부트스트랩 임시 합의 규약 (Phase 0~3 한정)**:

1. **임시 우회 메커니즘**: Phase 0~3 동안 `/consensus` 스킬이 없으므로, 합의 루프는 다음 방식으로 **수동 수행**:
   - Claude가 Task 완료 시 사용자에게 "검토 요청합니다" 보고
   - 사용자가 `/codex:review --wait` 슬래시 커맨드를 **명시적으로 호출** (codex-plugin-cc 스킬 경유)
   - Codex 리뷰 결과 받고 Claude가 반영
   - 합의 도달까지 사용자 manual 반복

2. **CLAUDE.md "codex-plugin-cc 스킬 경유 의무" 충족 방식**:
   - **위반 아님**: codex-plugin-cc 스킬을 슬래시 커맨드(`/codex:review`)로 호출하는 것은 정상 경로
   - 금지된 것은 **MCP 직접 호출**(`mcp__x__ask_codex`)을 코드/자동화에서 우회 호출하는 것
   - 부트스트랩 기간 슬래시 커맨드 명시 호출은 사용자 의사결정 경로이므로 허용
   - **단 예외**: Architect 검증이 필요한 기술적 질의에 한해 `mcp__x__ask_codex` 직접 호출 허용 (사용자 명시 요청 시) — 이는 합의 루프가 아닌 정보 수집 용도

3. **부트스트랩 종료 게이트**: Phase 4 종료 시점에 **자기 적용 체크포인트**:
   - "Phase 5부터 이 하네스 자체가 `/consensus`로 개발된다" 명시
   - Phase 5 첫 Task부터 `/consensus` 자동 호출

4. **부트스트랩 기간 Task 단위 즉시 커밋 유지**: Phase 0~3도 CLAUDE.md "Task 단위 즉시 커밋" 규칙 100% 준수. 합의는 수동이지만 커밋은 자동.

**Trade-off**: 부트스트랩 우회는 명시적 규칙 일시 완화이나, 사용자 수동 개입을 요하므로 **자동 무인 빌드 금지**. Phase 0~3은 반드시 유인 세션. 무인 빌드(/build)는 Phase 9 이후만 가능.

---

## 7.6-bis. `/resume-session` 실효성 검증 단계 (신규, B3 대응)

> v2 변경: §7.6-bis 추가 — `--resume` 임의 과거 세션 실측 + 대체 메커니즘. (Critic 영역 6 BLOCKER 대응)

problem.md 원문: "resume에도 세션 찾기 어려움. --continue로 바로전만 가능. 2,3개 전은 아예 못찾아 새롭게 시작하여 세션 다 날림."

v1 §7.6의 "안내 출력 + 컨텍스트 dump"가 problem.md를 **진짜 해결하는지 미검증**.

### Phase 5 첫 Task: `--resume` 실측 검증 의무 [B3]

**검증 항목** (Phase 5.0으로 분리, Phase 5의 5.1보다 먼저):
1. `claude --resume <sessionId>`가 **임의 과거 sessionId**에서 작동하는가?
   - 실측 시나리오: 10개 세션 생성 → 5번째 sessionId로 `--resume` → 컨텍스트 정상 복원되는가?
2. Claude Code SessionEnd 훅 입력 JSON에 `sessionId` 필드가 노출되는가?
   - 실측: `.claude/hooks/session-end.sh`에 `cat > /tmp/hook-input.json` 추가 후 1회 세션 종료, 파일 검사
3. Codex CLI도 동일 `--resume` 메커니즘이 있는가?

**검증 결과별 분기**:

- **시나리오 A: 모두 PASS** → v1 §7.6 그대로 진행 ("안내 출력 + 사용자가 `--resume <id>` 수동 실행").
- **시나리오 B: `--resume` 임의 과거 작동 안 함 (최근 N개 한정)** → 대체 메커니즘 [추천]:
  - `.omc/sessions/archive/{date}-{sessionId}.md` 본문에 (요약 + 변경 파일 + 마지막 커밋 + cwd + 마지막 사용자/AI 메시지 N개) 풍부하게 저장
  - `/resume-session N`이 archive 본문을 **새 Claude Code 세션에 system prompt로 자동 주입**: `claude -p "$(cat archive.md)"` 패턴
  - 워크트리 + branch 기반 체크포인트 보조 (`scripts/checkpoint-branch.sh`로 세션 종료 시 자동 branch 생성)
- **시나리오 C: SessionEnd 입력에 sessionId 없음** → 대체:
  - SessionStart 입력에서 sessionId 캡처해 `.omc/sessions/_current_sessionId` 파일에 기록
  - SessionEnd가 해당 파일을 읽어 인덱스 갱신

### Phase 5 검증 시나리오 명시 [B3]

Phase 5 종료 게이트 (Critic 영역 D dogfood 통합):
- **시나리오**: 5개 전 세션 실제 재개 → 동일 컨텍스트 작업 재개 = 완료
- **실측**: 1) 5개 세션 시뮬레이션 (각 다른 작업) → 2) `/resume-session 4` → 3) 컨텍스트 정상 복원 + 작업 재개 가능

**Trade-off**: 실측 검증은 Phase 5 일정 +1~2시간 추가. 그러나 problem.md 핵심 약속을 보장하지 못하면 plan 전체 가치 무너짐 → 필수.

---

## 8. 배포/복제 전략 (Q6) 설계

> v2 변경: §8.2 회사계정 복제 안전장치 강화 (P6), §8.3 plugin.json `entry` 필드 제거 (P5).

### 8.1 깃 개인계정 메인 레포 구조 `[확정]` (v1 동일)

### 8.2 회사계정 복제 워크플로우 (P6 강화) `[확정]`

`scripts/clone-to-company.sh` **3-step wizard**:
1. `git clone --depth 1 <personal-repo> <target-dir>` (shallow clone — 개인 git history 분리)
2. **자동 cleanup** (dry-run으로 먼저 보여주고 사용자 confirm 후 실행):
   - `rm -rf .git` (개인 git 히스토리 제거)
   - `rm -f .env*` (시크릿 동반 복제 방지)
   - `rm -f .claude/settings.local.json` (개인 설정 누출 방지)
   - `rm -rf .omc/state .omc/logs` (개인 OMC 상태 누출 방지)
   - `rm -rf .omc/sessions/` (개인 세션 인덱스 누출 방지) [열림: 사용자 확인 필요]
3. `git init && git add . && git commit -m "init from harness template"` (회사계정 fresh history)
4. 사용자 confirm: 새 remote URL, branch(dev/main), 환경변수 분리 안내, **환경 가드 자동 설치** (`scripts/install-env-guard.sh` 호출 → `~/.claude/hooks/branch-guard.sh` 부재 시 설치, `.claude/settings.json`에 `Read/Edit/Write(.env*)` deny 룰 명시) [C-A]
5. `04.docs/ONBOARDING.md` 가이드 출력

### 8.3 Claude Code 플러그인 마켓플레이스 등록 (P5 반영) `[확정]`

§3.4 plugin.json 스키마 참조.

등록 시점: **v0.2.0+** (v0.1.0은 GitHub 레포만, Non-Goals §4-bis 9번).

### 8.4 Codex 플러그인 마켓플레이스 등록 [열림]

superpowers 5.0.7 패턴 참조. 정확한 등록 절차는 Architect 검증 필요.

### 8.5 두 형태(클론형 + 플러그인형) 동기화 `[추천]` (v1 동일)

---

## 9. Phase 분해 (작업 순서) — v2 갱신

> v2 변경: Phase 0을 5개 Task(0.A~0.E)로 분할 [B2]. 각 30분~1시간 분량. Task 단위 즉시 커밋 의무.

> **원칙**: 각 Task는 TDD 가능, **30분~1시간 분량**(v1 30분~2시간에서 조정), Task 단위 즉시 커밋, 의존성 명시. 병렬 가능 Task는 ⚡로 표기. **부트스트랩 기간(Phase 0~3)은 §7-bis 임시 합의 규약, 무인 빌드 금지**. **Phase 별 dogfooding 게이트** (§11).

### Phase 0: 폴더 골격 + 메타 파일 (소요 약 2~3시간, 5개 Task 분할) [B2]

> v2 변경: v1의 단일 커밋(0.8)을 5개 독립 Task(0.A~0.E)로 분할. 각 Task 종료 시 즉시 커밋.

- **0.A** ksbc 골격 정리 (소요 ~30분)
  - 루트 폴더: `01.spec/`, `02.workflow/`, `03.archive/`, `04.docs/`, `05.tasks/`, `openspec/`, `scripts/`
  - 검증: `ls` 출력에 7개 폴더 존재
  - **커밋**: `chore: scaffold ksbc-style root folders`

- **0.B** `.claude/` 골격 생성 (소요 ~30분)
  - `settings.json` 스켈레톤, `hooks/`, `commands/`, `skills/`, `rules/`, `projects/` (빈 디렉터리 `.gitkeep`)
  - 검증: 디렉터리 + `.gitkeep` 6개 파일
  - **커밋**: `chore: scaffold .claude/ runtime dirs`

- **0.C** `.codex/` 골격 생성 (소요 ~30분)
  - `config.toml` (`[features] codex_hooks = true`만), `hooks.json` (빈 스켈레톤), `hooks/`, `prompts/`, `skills/`
  - 검증: `cat .codex/config.toml` 출력 정상
  - **커밋**: `chore: scaffold .codex/ runtime dirs`

- **0.D** 듀얼 플러그인 메타데이터 스켈레톤 (소요 ~30분)
  - `.claude-plugin/plugin.json` (P5 스키마: name/version/description/author/homepage/repository/license/keywords/requires)
  - `.codex-plugin/plugin.json` (skills + interface 추가)
  - 검증: `jq . .claude-plugin/plugin.json` 통과
  - **커밋**: `chore: add dual plugin manifests`

- **0.E** 베이스라인 메타 파일 (소요 ~30분)
  - `.gitignore` 갱신: `.env*`, `.claude/projects/`, `.omc/state/`, `.omc/logs/`, `.omc/sessions/archive/*.md` (선택)
  - `AGENTS.md` 생성 (Codex 호환 진입점, CLAUDE.md include)
  - `package.json` 생성 (`scripts.setup`, `scripts.test`, `scripts.lint`, `devDependencies.bats-core` [C3])
  - 검증: `cat AGENTS.md`, `npm run --help` 정상
  - **커밋**: `chore: add agents.md, gitignore, and package.json baseline`

- **의존성**: 0.A~0.E 사실상 독립, 모두 ⚡. 각 Task 종료 즉시 커밋(CLAUDE.md 규칙).

### Phase 1: SessionStart 훅 + 기본 자동 주입 (소요 약 2~3시간)

v1 동일, 단 부트스트랩 합의 규약 적용 (§7-bis):
- **1.1** `.claude/hooks/lib/` 유틸 셸 함수 작성 (TDD: bats-core 사용)
- **1.2** `.claude/hooks/session-start.sh` 작성
- **1.3** `.claude/settings.json`에 SessionStart 훅 등록
- **1.4** ⚡ 5개 자동 주입 스킬 SKILL.md 작성
- **1.5** `.codex/hooks/session-start.sh` 래퍼 작성 + `.codex/hooks.json`에 등록 (P4)
- **1.6** **dogfood 체크포인트 P1** (§11): SessionStart 훅 실제 컨텍스트 주입 검증
- **1.7** 커밋: `feat: add SessionStart hook with skill auto-injection`
- **의존성**: 1.1 → 1.2 → 1.3, 1.4 ⚡, 1.5는 1.2 이후, 1.6은 마지막

### Phase 2: /learn + learnings 영속성 (소요 약 2~3시간)

v1 + KPI 카운터 + _pending.jsonl (C5):
- **2.1** `.omc/learnings/{patterns,pitfalls,preferences,glossary}.md` 빈 파일 + 예시
- **2.2** `.claude/skills/learn/SKILL.md`
- **2.3** `.claude/commands/learn.md`
- **2.4** `.claude/hooks/session-end.sh` 작성 + _metrics.json 카운터 (C1) + _pending.jsonl 분기 (C5)
- **2.5** 충돌 감지·confirm 로직 (`_history.jsonl`)
- **2.6** 자동 트림 임계 적용 (P7): 200/100/100/100줄 → `_archive/{YYYY-MM}.md`
- **2.7** SessionStart 훅 learnings 회수 통합 테스트
- **2.8** **dogfood 체크포인트 P2** (§11): `/learn "X"` → 다음 세션 회수 확인
- **2.9** 커밋: `feat: add /learn skill and learnings persistence with KPI metrics`
- **의존성**: Phase 1 완료 후

### Phase 3: 우선순위 3개 커맨드 (5a/5b/5c) (소요 약 2~3시간)

- **3.1** `/setup-claude`, `/setup-codex`, `/setup-both` (codex trust + features flag + env-guard 자동 설치)
- **3.2** `/double-check`
- **3.3** 프롬프트 자동 아카이빙 (`scripts/trigram-jaccard.sh` P2, 임계 3회)
- **3.4** **dogfood 체크포인트 P3** (§11): MVP-A 5개 시나리오 통과 → **MVP-A 완성 게이트**
- **3.5** 커밋 3~4개 (커맨드별 + dogfood)
- **의존성**: Phase 0~2 완료. 3.1/3.2/3.3 서로 ⚡.

> **🎯 MVP-A 완성 지점 (Phase 3 종료)**: "내일부터 쓸 수 있다" 충족. **단 "파워풀"은 MVP-B에서 (§0 매핑).**

### Phase 4: /consensus 합의 루프 (소요 약 2~3시간)

v1 + 호출 메커니즘 [열림] 결정:
- **4.0** [신규] Architect 실측: `/codex:review --wait` 호출 메커니즘 (슬래시 chain vs 셸 `claude -p`) — Critic 영역 4 대응
- **4.1** `.claude/skills/consensus-loop/SKILL.md` 본문 확정
- **4.2** `.claude/commands/consensus.md`
- **4.3** VERDICT 토큰 파싱 + 3단 폴백 (C4)
- **4.4** 루프 제어 max-loops 4 + 사용자 confirm
- **4.5** Task 단위 커밋 통합
- **4.6** Codex 장애 3단 폴백 구현 (§10.3 [B1+B5])
- **4.7** **dogfood 체크포인트 P4** (§11): `/consensus "변수 X→Y"` → 실제 Codex 합의 도달
- **4.8** 커밋: `feat: add /consensus skill with Codex review loop and failure policy`

### Phase 5: /resume-session + 실측 검증 (problem.md 해결) (소요 약 3~4시간) [B3]

> v2 변경: Phase 5.0 실측 검증 단계 추가. Phase 5 분량 +1시간.

- **5.0** **[신규 B3]** `--resume` 임의 과거 세션 실측 (§7.6-bis):
  - Claude `--resume` 임의 sessionId 작동 검증
  - SessionEnd 훅 입력 스키마 검증
  - 결과별 분기 결정 (시나리오 A/B/C)
- **5.1** `.omc/sessions/index.json` 스키마 확정
- **5.2** `.claude/hooks/session-end.sh`에 세션 인덱스 append 로직 추가
- **5.3** `.omc/sessions/archive/{date}-{sessionId}.md` 본문 저장 (시나리오 B 대비 풍부하게)
- **5.4** `.claude/skills/session-index/SKILL.md`
- **5.5** `.claude/commands/resume-session.md` (시나리오별 분기 알고리즘)
- **5.6** 시나리오 B 대안 구현 (필요 시): archive 본문 → 새 세션 system prompt 주입
- **5.7** **dogfood 체크포인트 P5** (§11): 5개 전 세션 실제 재개 → 동일 컨텍스트 작업 재개 = 완료 → **MVP-B 완성 게이트**
- **5.8** 커밋: `feat: add /resume-session (fixes problem.md)`

> **🎯 MVP-B 완성 지점 (Phase 5 종료)**: §0 매핑의 "파워풀" 약속 + problem.md 핵심 약속 충족.

### Phase 6: OpenSpec 통합 + policy 일원화 (v1 동일)

v1 §9 Phase 6 그대로. 추가:
- **6.5** [신규] PostToolUse 훅에서 `openspec/specs/*.md` 직접 편집 감지 시 경고 출력 (§6.4)
- **6.6** **dogfood 체크포인트 P6**: openspec propose → apply → archive 1회 사이클

### Phase 7: 듀얼 플러그인 메타데이터 + /merge-skill (v1 동일)

### Phase 8: 회사계정 복제 워크플로우 (P6 강화)

- **8.1** `scripts/clone-to-company.sh` 3-step wizard 구현
- **8.2** `scripts/install-env-guard.sh` (C-A 환경 가드 자동 설치)
- **8.3** `.claude/settings.json` 프로젝트 레벨 `Read/Edit/Write(.env*)` deny 룰 명시
- **8.4** `04.docs/ONBOARDING.md` 회사계정 복제 절차 + 환경변수 분리 가이드
- **8.5** 시뮬레이션 테스트 (dry-run + 실제 임시 디렉터리 clone)
- **8.6** 커밋: `feat: add company-account clone workflow with env-guard`

### Phase 9: /build + 셀프 테스트 + 문서 (v1 + P3 wrapper)

- **9.1** `.claude/commands/build.md` + 스킬 (ralph 통합)
- **9.2** `scripts/build-iteration-gate.sh` 작성 (P3 wrapper 가드) + bats 단위 테스트
- **9.3** ralph 스킬과 consensus-loop 연결, openspec-propose 자동 호출 (wrapper 책임)
- **9.4** `02.workflow/ralph-build.md` SOP 문서
- **9.5** **dogfood 체크포인트 P9** (§11): 작은 더미 프로젝트 (TODO API 등)로 `/build` 1회 자동 완료
- **9.6** `README.md` 작성
- **9.7** `04.docs/RUNBOOK.md`, `04.docs/RELEASE_NOTES.md` 초안
- **9.8** v0.1.0 태그 (마켓플레이스 등록은 v0.2.0+, §4-bis Non-Goals)

### 의존성 그래프 (요약)

```
Phase 0 (0.A~0.E ⚡) ──┬─→ Phase 1 ──┬─→ Phase 2 ──┬─→ Phase 3 (MVP-A) ┐
                       │             │             │                     │
                       ├─→ Phase 6   │             ├─→ Phase 5(B3) (MVP-B)
                       │             │             │                     │
                       └─→ Phase 8   └─→ Phase 4   └─→ Phase 7 ────────┴─→ Phase 9
```

병렬 가능 구간 (Critic 영역 7 보강):
- **Wave A** (Phase 0 후): Phase 1, Phase 6 일부, Phase 8 일부 ⚡ — **단 같은 파일 write 충돌 매트릭스 준수**
- **Wave B** (Phase 2 후): Phase 4, Phase 5 ⚡ — Phase 5 분량 증가로 Wave B는 직렬 권장
- **Wave C**: Phase 7 (Phase 1 이후)
- **최종 직렬**: Phase 9
- **무인 빌드 (/build) 사용**: Phase 9 이후만. Phase 0~5는 유인 세션. **부트스트랩 합의 규약 §7-bis 적용**.

**파일 단위 충돌 매트릭스** (Critic 영역 7 보강):
- `.claude/settings.json`: Phase 0.B, 1.3, 8.3 — **직렬 필수**
- `.claude/hooks/session-end.sh`: Phase 2.4, 5.2 — **직렬 필수**
- `.gitignore`: Phase 0.E, 8.3 — **직렬 필수**
- 그 외 SKILL.md, commands/*.md는 독립 → ⚡ 가능

---

## 10. 리스크 & 미확정 사항

> v2 변경: §10.3 `--skip-codex` 제거 (B1+B5). 무인 빌드 Codex 장애 3단 폴백 신설.

### 10.1 사용자 추가 확인 필요 (`/learn` 첫 세션 시 자동 질문 후보)

→ `.omc/plans/open-questions.md`로 이관. v1의 6건 + v2 신규 사항.

### 10.2 기술적 리스크 (v1 + Architect 추가)

| 리스크 | 영향 | 완화책 |
|---|---|---|
| Codex CLI 0.124.0 hooks 버그 | hooks 미작동 | `.codex/hooks.json` 별도 파일 + `[features] codex_hooks = true` (P4) |
| Codex 신뢰 모델 미설정 | hooks 미로드 | `/setup-codex`가 `codex trust .` 안내·자동 실행 |
| `codex-plugin-cc` 스킬 미설치 | `/consensus` 작동 불가 | `/setup-codex`에 의존성 자동 검사·설치 안내 |
| SessionStart 토큰 초과 | learnings 손실 | 토큰 상한 7K 보수, 카테고리별 트림 임계 (P7) |
| 프롬프트 자동 아카이빙 시크릿 포함 | 보안 사고 | `.env` 정규식 마스킹 + `branch-guard.sh` 통합 (C-A) |
| 세션 sessionId 충돌 | `/resume-session` 오복원 | timestamp 복합 키, 중복 시 최신 우선 |
| OpenSpec ↔ 01.spec/ 이중 진실 | 사양 불일치 | `02.workflow/spec-flow.md` + PostToolUse 경고 (§6.4) |
| `.claude/projects/`, `.codex/` 상태 충돌 | 도구 내부 캐시 혼선 | SSOT 원칙 (Architect §C): `.omc/`만 공유, `.claude/projects/`/`.codex/`는 상호 미참조. `flock` 사용 |
| ralph 4.1.2 TDD/consensus 미강제 | `/build` 약속 위반 | wrapper 가드 셸 (P3) 직접 강제 |
| `--resume` 임의 과거 세션 미작동 | problem.md 해결 실패 | Phase 5.0 실측 후 시나리오 B 대안 (§7.6-bis) |

### 10.3 무인 빌드 Codex 장애 정책 (신규, [B1+B5]) `[확정]`

> v2 변경: §10.3 `--skip-codex` 제거. 3단 폴백 신설.

**v1 §10.3의 `--skip-codex` 비상 옵션을 완전 제거**. 이유: CLAUDE.md "합의 없이 구현 확정 금지" + "임의 우회 금지" 정면 위반.

**대체: Codex 장애 3단 폴백** (`/build` 무인 빌드 중 적용):

1. **1단: Codex 재시도** (자동, ~3분):
   - Codex 호출 실패 감지 시 30초 backoff 후 재시도 (max 3회)
   - 실패 사유 캡처 (네트워크/auth/timeout/형식 오류)

2. **2단: Critic agent 대체 리뷰** (자동, ~5분):
   - 1단 모두 실패 시 OMC `critic` agent (opus)로 대체 리뷰 호출
   - critic은 Codex 형식(`VERDICT: APPROVE|REQUEST_CHANGES`) 동일 출력 의무
   - 결과를 `.omc/state/fallback-review-log.jsonl`에 기록 (사용자 사후 확인용)
   - **단 이는 "임의 우회"가 아닌 명시적 합의 인프라 대체** — CLAUDE.md 규칙 충족 여부 [열림] (사용자 사전 승인 필요)

3. **3단: 일시 정지 + 사용자 confirm 마커** (마지막 안전망):
   - 2단도 실패 시 ralph가 일시정지 + `.omc/state/USER_CONFIRM_NEEDED` 마커 파일 작성
   - 마커 내용: 실패 Task 정보 + Codex 오류 + 사후 처리 옵션 (재시도 / 작업 보류 / 사용자 직접 리뷰)
   - **다음 사용자 세션 시작 시 SessionStart 훅이 마커 감지 → 알림 출력** (Architect agent 보고)
   - 알림 예: "지난 무인 빌드 중 Codex 장애로 Task X 보류. (a) 재시도 (b) 환경 점검 (c) 수동 리뷰 후 합의 (d) 작업 폐기 중 선택"

**알림 채널 [열림]**: Slack/Telegram/Discord 자동 알림 통합 여부 (Phase 9 RFC).

**Trade-off**: 3단 폴백은 무인 빌드 안정성 ↑이나, 2단 critic 대체 리뷰가 CLAUDE.md 규칙 해석에 따라 사용자 사전 승인 필요. 가장 안전한 경로는 3단(일시정지) 단독이나, 그러면 모든 Codex 일시 장애에서 야간 빌드 중단 → 효용 ↓. **권고: 2단 critic 대체 리뷰는 사용자 명시 confirm 후 활성화** (Phase 9 셋업 시 `/setup-build`에 옵션 노출).

### 10.4 트레이드오프 명시 (v1 + 갱신)

- **자동 주입(Q2=A) vs 컨텍스트 폭발**: 7K 상한, 트림 임계 (P7). 모니터링 로깅 의무.
- **`/learn` 자동 추출 vs confirm 부담**: 무인 모드 _pending.jsonl 보류 (C5). 7일 만료.
- **`/consensus` max-loops 4 vs 무제한**: 기본 4, 사용자 `--max-loops 8` 옵션.
- **메인 워커 Claude 단일 의존(Q1=B)**: §10.3 3단 폴백으로 완화 (`--skip-codex` 제거).
- **부트스트랩 자동화 부재 (B4 §7-bis)**: Phase 0~3은 유인만, 무인 빌드 금지. 사용자 부담 ↑이나 안전.
- **dogfood 게이트** (§11): 각 Phase 종료 시 검증 시간 +30분~1시간. 총 +3~4시간이나 격리 실패 위험 ↓.

### 10.5 Architect/Critic 2차 검토 권고 영역

이 v2가 BLOCKER 0건, MAJOR 2건 이하 통과를 목표로 다음 영역을 집중 검토받기 권고:
1. **§10.3 2단 critic 대체 리뷰**: CLAUDE.md "임의 우회 금지" 해석 — 명시적 폴백 메커니즘이 우회로 간주되는가?
2. **§7-bis 부트스트랩 합의 규약**: 슬래시 커맨드 명시 호출이 "codex-plugin-cc 스킬 경유 의무"를 충족하는가? Architect 단언 필요.
3. **§7.6-bis Phase 5.0 실측**: 실측 시간 추정(1~2시간)이 정확한가? 시나리오 B 대안 구현 비용 추가 평가.
4. **§11 dogfood 시나리오 선택**: 5개 MVP-A 시나리오가 "내일부터 쓸 수 있다"를 충분히 검증하는가?

---

## 11. Dogfooding 체크포인트 (신규, C-D 대응)

> v2 변경: §11 추가 — Phase별 미니 dogfooding 게이트. (Critic 영역 D BLOCKER 대응)

각 Phase 종료 시 통과 못 하면 다음 Phase 차단. Task 단위 즉시 커밋 규칙 정합.

### P1 종료: SessionStart 훅 실제 컨텍스트 주입 검증
- **시나리오**: Claude 세션 재시작 → hook output이 컨텍스트에 실제로 포함되는가?
- **검증**: SessionStart 출력에 5개 자동 주입 스킬 + learnings + session-index 확인
- **PASS 조건**: 5개 스킬 모두 hook output에 존재 + Claude가 이를 인지 (테스트 프롬프트로 확인)

### P2 종료: /learn 누적 + 회수 검증
- **시나리오**: `/learn "사용자는 npm 선호"` → 세션 종료 → 새 세션 시작 → SessionStart에 해당 학습 회수 확인
- **검증**: 새 세션의 컨텍스트에 "사용자는 npm 선호" 문구 포함
- **PASS 조건**: 회수 성공 + `_metrics.json`에 항목 카운터 +1

### P3 종료: MVP-A 5개 사용자 시나리오 (Critic 영역 1 정의)
**"내일부터 쓸 수 있다"의 진짜 검증**:
- (a) 빈 디렉터리에서 `/setup-both` → 양쪽 CLI 셋업 완료 + 5개 자동 주입 작동
- (b) `/double-check "결제 페이지 만들어줘"` → 의도 분해 + 질문 3개 출력
- (c) `/learn "사용자는 한글 커밋 메시지 선호"` → preferences.md에 항목 append
- (d) "이거 TDD로 만들어줘" 3회 입력 → `03.archive/prompts/2026-05/tdd-request.md` 자동 생성
- (e) 세션 종료 후 재시작 → SessionStart 훅이 (c)의 학습을 자동 주입
- **PASS 조건**: 5개 시나리오 모두 막힘 없이 통과 → **MVP-A 완성 인증**

### P4 종료: /consensus 실제 Codex 합의 도달
- **시나리오**: `/consensus "변수명 user_id → userId 변경"` → 실제 Codex 합의 도달
- **검증**: VERDICT: APPROVE 수신 + Task 단위 커밋 자동 + 합의 로그 저장
- **PASS 조건**: 합의 도달 + Codex 장애 폴백 1단 작동 (네트워크 끊고 재시도)

### P5 종료: /resume-session 5개 전 세션 실제 재개
- **시나리오**: 5개 세션 시뮬레이션 → `/resume-session 4` → 5번째 전 세션 실제 컨텍스트 복원
- **검증**: archive 본문 dump + 작업 재개 가능
- **PASS 조건**: problem.md "2,3개 전 못 찾음" 해결됨

### P9 종료 (최종): _dogfood/ 더미 프로젝트로 `/build` 자동 완료
- **시나리오**: `_dogfood/todo-api/` 더미 프로젝트(간단 PRD: TODO REST API 3 endpoint) → `/build "PRD 기반 구현"` 1회 실행
- **검증**: 자동 빌드 종료 + PR 생성 + 모든 테스트 통과 + Codex 합의 로그 저장
- **PASS 조건**: 8시간 이내 자동 완료 + 사용자 개입 0~2회 이하

**Dogfood 더미 프로젝트 시나리오 [열림]**: TODO REST API vs 다른 시나리오? 사용자 확인 필요.

**Trade-off**: dogfood 게이트는 각 Phase에 +30분~1시간 검증 시간 추가. 총 5시간 추가이나, Phase 9에서 처음 통합 실패 시 디버깅 비용(수일)보다 훨씬 저렴.

---

## 12. 부트스트랩 안정성 보강 (신규)

> v2 변경: §12 추가 — ralph 자동 빌드 시 운영 인프라 단절 대비 체크포인트.

`/build` 무인 야간 빌드 중 인프라 단절 시나리오 대비:

### 12.1 git push 권한 단절
- **시나리오**: 토큰 만료/네트워크 차단으로 push 실패
- **체크포인트**: 매 커밋 후 `git push --dry-run` 검증, 실패 시 `.omc/state/PUSH_FAILED` 마커 + 로컬 커밋은 유지 (작업 손실 없음)
- **사용자 사후 처리**: 다음 세션 시작 시 SessionStart 알림 → `git push` 수동 또는 `gh auth refresh`

### 12.2 네트워크 단절 (Codex 도달 불가)
- **시나리오**: 인터넷 일시 단절
- **체크포인트**: §10.3 3단 폴백 자동 적용

### 12.3 디스크 풀
- **시나리오**: `.omc/sessions/archive/` 누적으로 디스크 풀
- **체크포인트**: SessionEnd 시 `df -h .` 검사, 90% 초과 시 경고 + `_archive/` 6개월 이상 항목 자동 압축

### 12.4 hooks 자체 실패
- **시나리오**: `session-end.sh`가 jq 오류로 실패
- **체크포인트**: 모든 hook 스크립트는 `set -e` 미사용 + 에러 시 stderr 로그 + 정상 종료 코드 반환 (hook 실패가 세션 중단 유발하지 않도록)
- **검증**: Phase 1.1 hooks/lib/ 단위 테스트에 실패 시나리오 포함

### 12.5 ralph iteration 진행 정체
- **시나리오**: 같은 Task에서 무한 루프
- **체크포인트**: iteration별 timeout (단일 Task max 30분), `.omc/state/ralph-progress.json`에 진행도 기록, 진행 없으면 자동 일시정지

**Trade-off**: 체크포인트 추가는 운영 안정성 ↑이나, hook/script 복잡도 ↑. Phase 9에서 통합 적용, Phase 1~8은 핵심만(`set -e` 미사용, 에러 로깅).

---

## 부록 A. 핵심 결정 5개 요약 (v2 갱신)

1. **루트 직접 폴더 구조**: ksbc + OMC + 도구별 분리. v1 동일.
2. **SessionStart 훅 = 단일 진실 주입점**: 5개 핵심 스킬 + learnings + session-index + KPI 요약. 토큰 상한 7K + 자동 트림 (P7).
3. **/consensus = Claude(메인) → Codex(리뷰) 자동 루프**: VERDICT 토큰 + 3단 폴백 (C4). 호출 메커니즘 Phase 4.0 실측 [열림].
4. **/resume-session = problem.md 해결 with 실측 검증**: Phase 5.0에서 `--resume` 임의 과거 작동 실측 → 시나리오 A/B/C 분기 (§7.6-bis).
5. **Phase 0~3 = MVP-A "내일부터 쓸 수 있다"**, **Phase 0~5 = MVP-B "파워풀"**. 부트스트랩 합의 규약 (§7-bis), Phase별 dogfood 게이트 (§11), 무인 빌드 Codex 장애 3단 폴백 (§10.3).

---

## 부록 B. 다음 단계 (Architect/Critic 2차 검토 입력)

이 v2를 Architect/Critic 2차 검토에 전달하여 다음 영역 집중 검토:
- §10.3 2단 critic 대체 리뷰가 CLAUDE.md "임의 우회 금지" 충족 여부
- §7-bis 부트스트랩 합의 규약의 슬래시 커맨드 명시 호출 정합성
- §7.6-bis Phase 5.0 실측 단계의 시간 추정 및 시나리오 B 대안 비용
- §11 dogfood 시나리오의 "쓸 수 있다" 검증 충분성
- §10.3 알림 채널([열림]) 결정 시점 (Phase 9 RFC vs MVP-B 종료)

목표: BLOCKER 0건, MAJOR 2건 이하 통과 → 사용자 최종 confirm → Phase 0 실행 시작.
