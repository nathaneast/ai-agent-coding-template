# Architect Review — Harness Template MVP Plan

> **합의 사이클 2단계 산출물**: Planner가 작성한 plan을 기술 타당성 관점에서 검증.
> **검토 기준일**: 2026-05-13 | **검토 범위**: harness-template-mvp-plan.md 전체
> **닫힌 결정(Q1~Q6)은 절대 뒤집지 않음.** 그 구현 방식만 도전.
> **방법론**: Codex CLI 공식 문서 + superpowers 5.0.7 실제 코드 + OMC ralph 4.1.2 실제 코드 + 로컬 `.codex/hooks.json` 실측치 교차검증.

---

## 0. 종합 평가

| 영역 | 등급 | 한 줄 요약 |
|---|---|---|
| 듀얼 모델 어댑터 (§3) | **PASS** | superpowers 5.0.7이 동일 패턴(`.claude-plugin/` + `.codex-plugin/` 분리)을 이미 운영 중. 검증 완료. |
| SessionStart 훅 (§4) | **CONCERN** | Claude/Codex 훅 스키마는 거의 동일하나, **enable·신뢰 메커니즘이 다르며**, Codex 0.124.0 버그가 있음. 보완 필요. |
| `/learn` 영속성 (§5) | **PASS** | 단순 append + SessionEnd 트리거로 충분. 감쇄 미도입은 옳은 선택. |
| OpenSpec ↔ 01.spec (§6) | **CONCERN** | 경계 정의는 좋으나 단방향 강제 메커니즘이 문서 한 장(`spec-flow.md`)에만 의존. 자동 가드 필요. |
| 7개 MVP 커맨드 (§7) | **CONCERN** | `/build`가 ralph 단순 호출 가정인데, ralph 4.1.2는 TDD/consensus/openspec을 **자동으로 강제하지 않음**(실측). |
| 배포·복제 (§8) | **CONCERN** | 회사계정 복제 워크플로우가 `.git` 히스토리 + `.env`/secret 분리 안전장치를 명시하지 않음. |
| Phase 분해 (§9) | **CONCERN** | Phase 0의 0.8 "단일 커밋"이 사용자 강제 규칙 "Task 단위 즉시 커밋"과 충돌. |
| 리스크 매트릭스 (§10) | **PASS (with BLOCKER)** | 식별된 6개 리스크 모두 합리적. 다만 §10.3의 `--skip-codex` 옵션은 사용자 강제 규칙 위반. |
| **BLOCKER 총계** | **2건** | (1) Phase 0 단일 커밋 vs 즉시 커밋 규칙 충돌, (2) `--skip-codex` 비상 옵션이 CLAUDE.md 합의 루프 의무 위반. |

---

## 1. 핵심 5개 검증 (Planner §10.4 도전 요청)

### 1.1 `.codex/hooks/session-start.sh`를 Claude 본체의 단순 래퍼로 만들 수 있는가? — **PASS (with CONCERN)**

**근거(실측)**:
- 로컬 `/Users/nathaneast/.codex/hooks.json`이 Claude `settings.json`과 **거의 동일한 스키마**(`hooks.SessionStart[].matcher`, `hooks[].type="command"`, `hooks[].command`)를 사용 중. (출처: 사용자의 oh-my-codex 설치)
- superpowers 5.0.7도 같은 패턴: `.claude-plugin/plugin.json`과 `.codex-plugin/plugin.json`을 분리하되 `hooks/run-hook.cmd`로 단일 분기 진입점을 공유.
- Codex 공식 문서: "Hook events include PreToolUse, PostToolUse, PermissionRequest, **SessionStart**, UserPromptSubmit, Stop." (https://developers.openai.com/codex/hooks)
- stdout 흡수: Codex도 "Plain text on stdout is added as extra developer context" — Claude와 의미론 동일.

**CONCERN (검증 필요 플래그)**:
- **차이점 1 — matcher 토큰**: Claude는 `startup|clear|compact|resume`(superpowers 실측), Codex 공식 예제는 `startup|resume`만 명시. → **권고**: Codex 측 matcher는 `startup|resume`로만 보수 등록.
- **차이점 2 — 신뢰 모델**: Codex는 "Project-local hooks load only when the project `.codex/` layer is trusted." → Claude는 신뢰 모델 없음. **권고**: `/setup-codex`에 `codex trust .` 안내 또는 자동 실행.
- **차이점 3 — 알려진 버그**: Codex 0.124.0에서 `[features].codex_hooks = true`로 enable해야 작동하며, hooks를 `config.toml` 내부에 두면 TOML 파싱 오류 발생(issue #19199). → **권고**: `.codex/hooks.json` 별도 파일로만 등록, `config.toml`에는 `[features] codex_hooks = true`만 추가.

**최종 평가**: Planner의 "Codex 측 래퍼" 설계는 기술적으로 **가능**. 단, 위 3가지 차이를 코드/문서에 명시해야 함.

### 1.2 프롬프트 자동 아카이빙 fuzzy match 알고리즘 — **PASS (권고: trigram + Jaccard)**

**비교**:
| 알고리즘 | 셸 구현 난이도 | False Positive 위험 | 의존성 |
|---|---|---|---|
| simhash | 어려움(64-bit 해싱 셸 구현 비현실적) | 낮음 | python3 필요 |
| **trigram + Jaccard ≥ 0.7** | **쉬움(awk+sort+uniq)** | **중간(임계로 제어)** | **POSIX 표준만** |
| LSH | 매우 어려움 | 낮음 | 외부 라이브러리 |

**권고**: **trigram + Jaccard 0.7 임계**. 이유:
1. macOS 기본 도구로 30줄 셸로 구현 가능
2. 사용자 프롬프트가 보통 짧음(50~500자) → trigram 효율적
3. False positive 위험은 "사용자 1회 confirm" 단계로 완화 가능

**Planner 결정과의 충돌**: §7.3에서 "simhash 또는 단순 trigram" — **trigram 우위**. simhash는 Phase 9 이후 RFC로 이동.

### 1.3 `policy/` → `.claude/rules/` 마이그레이션 시 외부 하드코딩 영향 — **CONCERN**

**조사 결과**:
- 현재 `policy/`를 참조하는 파일: `prompt.md`, `problem.md`, policy 내부 상호참조만.
- 사용자 글로벌 `~/.claude/rules/`에는 별개 룰 존재(omc-orchestration.md). 충돌 없음.
- ksbc 3종은 `policy/` 미사용. ksbc-status-to-monday는 `01.spec`~`05.tasks`를 사용하지만 `policy/` 참조 없음.

**CONCERN**:
- Phase 6에서 `policy/` 삭제 시 git history에는 남음 → **권고**: `policy/DEPRECATED.md` stub 유지(파일 1개, ~10줄). 완전 삭제 금지.
- 사용자가 외부 자동화(예: 다른 프로젝트의 SessionStart 훅이 `policy/`를 절대경로로 참조)에서 하드코딩했을 가능성이 있으나, **이는 사용자에게 직접 확인해야 함**(Critic이 도전).

**Planner 결정과의 충돌 없음**. Planner의 §10.4(3)에 이미 명시됨.

### 1.4 `/build`가 ralph 단순 호출 vs 자체 구현 — **CONCERN (BLOCKER 잠재)**

**결정적 실측 (출처: `/Users/nathaneast/.claude/plugins/cache/omc/oh-my-claudecode/4.1.2/commands/ralph.md:1-124`)**:

ralph 4.1.2 명령의 **실제 책임**:
- ✅ Architect 검증 의무 (line 92-105)
- ✅ Executor 위임 + 모델 라우팅 (line 22-26)
- ✅ 병렬 실행 + 백그라운드 (line 30-34)
- ✅ "Zero tolerance"(스코프 축소·부분완료 금지) (line 107-112)

ralph 4.1.2가 **갖고 있지 않은 것**:
- ❌ TDD Red-Green 자동 강제 (tdd-guide 에이전트는 있으나 명령은 호출 안 함)
- ❌ Codex `/codex:review` 자동 호출
- ❌ OpenSpec propose/apply/archive 자동 호출
- ❌ Task 단위 즉시 커밋 자동 호출

**판정**: Planner §7.7의 "ralph 통합" 가정은 **부분적으로만 성립**. ralph는 위임/검증 골격만 제공하고, TDD+consensus+openspec은 `/build` **wrapper에서 직접 강제**해야 함.

**권고**:
- `/build`는 ralph를 **호출은 하되**, ralph 내부 iteration마다 다음을 강제하는 **외부 가드 셸 스크립트**(`scripts/build-iteration-gate.sh`)를 둠:
  1. iteration 시작: `/openspec-propose` 자동 호출
  2. executor 작업 후: `tdd-guide` 에이전트로 Red/Green 확인
  3. 검증 단계: `/codex:review --wait` 자동 호출
  4. 합의 도달 시: Task 커밋 + `/openspec-apply-change`
- 또는 Phase 9에서 ralph가 아닌 **자체 빌드 루프 구현**으로 결정. **[추천: ralph + 외부 가드 셸]** (자체 구현은 OMC 호환성 손실 비용 큼).

**Planner 결정과의 충돌**: §7.7 "OMC ralph 스킬 (자체 구현 대신 통합)" — **부분 도전**. ralph는 통합하되, TDD/consensus/openspec 강제는 wrapper 책임이라고 명시 변경 필요.

### 1.5 이 템플릿 자체가 사용자 강제 규칙을 따라야 하는가 — **PASS (Planner 추천 지지)**

**근거**: CLAUDE.md(이 프로젝트 루트)는 "이 파일에 명시된 규칙은 어떤 상황에서도 스킵 금지"라고 명시. 템플릿 자체도 같은 규칙을 따라야 함 — 그래야 dogfooding이 됨.

**Planner 결정 지지**: §10.4(5)의 "추천: 따른다" — **PASS**.

**단, 추가 BLOCKER 발견** (§9 Phase 0 충돌):
- Phase 0의 7개 Task(0.1~0.7)를 **단일 커밋 0.8**로 묶음 → CLAUDE.md "Task 단위 즉시 커밋"의 명시적 위반.
- **권고(BLOCKER 해소)**: Phase 0을 5개 Task로 재분할, 각 Task마다 커밋. 예: `0.A 폴더골격`, `0.B .claude/skeleton`, `0.C .codex/skeleton`, `0.D plugin metadata`, `0.E gitignore+AGENTS.md`.

---

## 2. 추가 검증 영역 (A~G)

### A. 훅 호환성 — **PASS (with CONCERN)**

세부 사항은 §1.1 참조. 핵심: 스키마는 동일, **enable 메커니즘과 신뢰 모델이 다름**.

| 항목 | Claude Code | Codex CLI |
|---|---|---|
| 등록 위치 | `.claude/settings.json` | `~/.codex/hooks.json` 또는 `.codex/hooks.json` |
| Enable | 자동 | `[features] codex_hooks = true` 필요 (v0.124.0+) |
| 신뢰 게이트 | 없음 | `codex trust <path>` 필요 |
| matcher 토큰 | `startup\|clear\|compact\|resume` | `startup\|resume` 안전 |
| 환경변수 | `CLAUDE_PLUGIN_ROOT` | `CODEX_PLUGIN_ROOT` (검증 필요 플래그) |
| stdout 흡수 | 시스템 리마인더로 자동 흡수 | "extra developer context"로 흡수 |

**권고**: `hooks/lib/dispatch.sh`가 환경변수(`CLAUDE_PLUGIN_ROOT` vs `CODEX_PLUGIN_ROOT`)를 동적으로 감지하여 자기 위치를 찾도록 함. superpowers `run-hook.cmd`(폴리글롯 wrapper) 패턴을 참조.

### B. 컨텍스트 폭발 위험 — **CONCERN**

**보수적 토큰 예산 (실측 기반)**:
- 5개 핵심 스킬 SKILL.md (frontmatter+본문 평균 ~80줄, ~600토큰/개) = ~3,000 토큰
- learnings 4종 (preferences/pitfalls 전체 + patterns 100줄 + glossary 50줄) ≈ ~2,000 토큰
- session-index 최근 5개 (200자 요약 × 5) ≈ ~500 토큰
- 메타 헤더/구분자 ≈ ~200 토큰
- **합계 ≈ 5,700 토큰** — Planner의 7K 상한 안에 들어옴.

**위험**:
- learnings는 시간이 갈수록 단조 증가. 6개월 후 5,000줄 가능.
- patterns "최근 100줄"은 자동 트림이지만, preferences/pitfalls는 **자동 트림 없음**(Planner §5.4).

**권고**:
- 카테고리별 자동 트림 임계 명시: preferences/pitfalls 각 200줄, patterns/glossary 각 100줄.
- 초과 항목은 `.omc/learnings/_archive/{YYYY-MM}.md`로 자동 이동(append-only).
- SessionStart 출력 끝에 토큰 카운트 보고 (`echo "[ctx-budget] ~XYZK tokens"`) — 사용자 모니터링용.

**Planner 결정과 충돌 없음**, 보강만 필요.

### C. 상태 저장소 SSOT — **CONCERN**

현재 상태 저장 위치가 **3곳**:
1. `.omc/` — OMC 표준 (notepad, project-memory, state)
2. `.claude/projects/` — Claude Code 내부 캐시 (sessionId, 트랜스크립트)
3. `.codex/` (있다면 캐시) — Codex 내부

**문제**: Claude와 Codex가 같은 `.omc/`를 읽도록 보장하는 명시적 규약 없음.

**권고**:
- **SSOT 원칙 명시 (`02.workflow/state-ssot.md` 신규)**:
  - 영속 사용자 자산: `.omc/learnings/`, `.omc/sessions/index.json`, `.omc/sessions/archive/`, `policy/*` 또는 `.claude/rules/*` — **읽기는 양쪽, 쓰기는 한쪽이 마스터**.
  - 도구 내부 캐시: `.claude/projects/`, `.codex/` — **상대 모델은 절대 읽거나 쓰지 않음**.
- SessionEnd 훅이 양쪽에서 동작할 때 동시 쓰기 경쟁 방지: `flock .omc/sessions/index.json.lock` 사용 (POSIX 표준).

### D. OpenSpec ↔ 01.spec/ 경계 — **CONCERN**

**위험**: 둘 다 사양을 다룸 → 사용자/Claude가 어디에 무엇을 쓸지 헷갈림.

**Planner §6.2 정의 (좋음)**:
- 01.spec/ = 인간 PRD
- openspec/specs/ = 기계 명세

**부족한 점**: 단방향 흐름(01.spec → openspec/changes → openspec/specs)을 강제하는 자동 가드 없음.

**권고**:
- `.claude/rules/sdd-openspec.md`에 **금지 규칙** 명시: "openspec/specs를 직접 편집 금지. 항상 openspec/changes 경유."
- `PostToolUse` 훅에서 `openspec/specs/*.md` 직접 편집 감지 시 경고 출력(차단까지는 안 함, 알림만).

### E. `/consensus` 무한 루프 방지 — **PASS**

Planner §3.2의 max=4 외에, **권고 추가**:
- 시간 상한: 단일 `/consensus` 호출 max 60분 (셸 `timeout 3600` 활용)
- 토큰 상한: 누적 컨텍스트 N토큰 초과 시 사용자 confirm — 이건 Claude Code가 자체적으로 처리하므로 명시 불필요.
- 사용자 인터럽트: Ctrl+C 시 마지막 합의 결과로 폴백 (`scripts/consensus-cleanup.sh trap`).

### F. `.claude-plugin/` / `.codex-plugin/` 메타데이터 — **PASS (with CONCERN)**

**Claude Code plugin.json 필수 필드** (공식 docs.code.claude.com 기준):
- `name` (필수), `version`, `description`, `author`, `homepage`, `repository`, `license`

Planner §8.3의 plugin.json은 `entry.commands`, `entry.skills`, `entry.hooks`, `entry.rules`, `requires`를 포함하나, **공식 스키마에는 `entry` 필드 없음**. 디렉터리는 관례(`commands/`, `skills/`, `hooks/`, `agents/`) 위치만 사용.

**superpowers 5.0.7 실측 plugin.json**:
```json
{ "name": "superpowers", "description": "...", "version": "5.0.7", "author": {...}, "homepage", "repository", "license", "keywords" }
```
— **`entry` 필드 없음**. 모든 컴포넌트는 디렉터리 위치 컨벤션으로 자동 인식.

**Codex plugin.json (superpowers `.codex-plugin/`)**: 추가로 `"skills": "./skills/"`와 `"interface": {...}` 필드 존재.

**권고**:
- Planner §8.3의 `entry.{commands,skills,hooks,rules}` **제거**. 컨벤션 디렉터리만 사용.
- 대신 `keywords` 배열 추가 (superpowers 패턴).
- Codex plugin.json만 `skills` 경로와 `interface` 필드 추가.

### G. 회사계정 복제 워크플로우 — **CONCERN (BLOCKER 잠재)**

**위험 매트릭스**:
| 항목 | 위험 | 완화책 |
|---|---|---|
| `.git` 히스토리 전체 복제 | 개인계정의 다른 커밋이 회사 환경 누출 | `--depth 1` shallow clone, 또는 `git clone` 후 `rm -rf .git && git init` |
| `.env*` 동반 복제 | 시크릿 누출 (한 번이면 끝) | clone 후 자동 `git check-ignore .env* && rm -f .env*` |
| `~/.codex/auth.json` 의존 | 회사계정 토큰과 개인 토큰 혼선 | `clone-to-company.sh`가 `CODEX_AUTH_DIR` 분리 안내 출력 |
| `settings.local.json` 복제 | 개인 설정이 회사 환경 누출 | `.gitignore`에 이미 포함 가정, 단 ksbc 패턴 검증 필요 |

**권고 (BLOCKER 해소)**: `scripts/clone-to-company.sh`는 **3-step wizard**로 구현:
1. `git clone --depth 1` → 개인 git history 분리
2. `.env*`, `settings.local.json`, `.omc/state/`, `.omc/logs/` 자동 제거 확인
3. 새 origin 설정 + 사용자 confirm

---

## 3. CLAUDE.md 강제 규칙 충돌 점검

| Planner 결정 | CLAUDE.md 규칙 | 판정 |
|---|---|---|
| §9 Phase 0.8 "Task 단위 커밋 1개" | "Task 단위 즉시 커밋, 다음 Task 전 커밋 완료 필수" | **BLOCKER** — Phase 0을 5개 Task로 재분할 |
| §10.3 `--skip-codex` 비상 옵션 | "Codex 리뷰는 반드시 codex-plugin-cc 통해서만, 임의로 우회하지 않는다" | **BLOCKER** — `--skip-codex` 제거. 대안: Codex 장애 시 사용자에게 명시적 confirm 후 일시 중지 |
| §3.2 max-loops 4 후 사용자 confirm | "합의 없이 구현을 확정하지 않는다" | **PASS** — 사용자 confirm은 명시적 의사결정 |
| §7.7 `/build` ralph 통합 | "TDD 필수 + 합의 루프 필수" | **CONCERN** — ralph 4.1.2가 TDD/consensus를 자동 강제하지 않음 (§1.4 참조) |
| §4.5 자동 주입 토큰 7K 상한 | (해당 규칙 없음) | **PASS** |
| §5.5 충돌 시 사용자 confirm | "임의 판단 금지" | **PASS** |

---

## 4. Plan 수정 권고 패치 (구체 diff)

### 패치 P1 — §9 Phase 0 재분할 (BLOCKER 해소)

```diff
 ### Phase 0: 폴더 골격 + 메타 파일 (소요 약 1~2시간)

-- **0.1** ⚡ 루트 폴더 생성: ...
-- **0.2** ⚡ `.claude/` 골격 생성: ...
-- (중략)
-- **0.8** Task 단위 커밋 1개: `feat: bootstrap harness skeleton (phase 0)`
-- **의존성**: 없음. 모두 병렬 가능(0.1~0.7)
+- **0.A** ksbc 골격(01.spec~05.tasks, openspec/, scripts/, policy/) 정리 → 커밋 `chore: scaffold ksbc-style root folders`
+- **0.B** `.claude/` 골격 + 빈 `.gitkeep` → 커밋 `chore: scaffold .claude/ runtime dirs`
+- **0.C** `.codex/` 골격 + config.toml 스켈레톤 → 커밋 `chore: scaffold .codex/ runtime dirs`
+- **0.D** `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` 스켈레톤 → 커밋 `chore: add dual plugin manifests`
+- **0.E** `.gitignore` + `AGENTS.md` + `package.json` → 커밋 `chore: add agents.md and package.json baseline`
+- **의존성**: 0.A~0.E 사실상 독립, 모두 ⚡. 각 Task 종료 시점에 즉시 커밋(CLAUDE.md 규칙 준수).
```

### 패치 P2 — §10.3 `--skip-codex` 제거 (BLOCKER 해소)

```diff
-- **메인 워커 Claude 단일 의존(Q1=B)**: Codex 장애 시 합의 루프 마비. **완화**: `/consensus`에 `--skip-codex` 비상 옵션(단 CLAUDE.md 규칙 위반 명시 + 사용자 confirm).
+- **메인 워커 Claude 단일 의존(Q1=B)**: Codex 장애 시 합의 루프 마비. **완화**: Codex 호출 실패 감지 시 `/consensus`를 일시 중지하고 사용자에게 (a) 재시도 (b) Codex 환경 점검(`/codex:setup`) (c) 작업 보류 중 선택 요청. **`--skip-codex` 비상 옵션은 도입하지 않음** — CLAUDE.md "합의 없이 구현 확정 금지" 위반.
```

### 패치 P3 — §7.7 `/build` ralph wrapper 명시 (CONCERN 해소)

```diff
 - **알고리즘 (의사)**:
   ```
   /build:
     1. PRD 파싱 → 유저스토리 추출
-    2. /ralph --prd <path> --max-iterations 200 시작
+    2. /ralph 호출 (TDD/consensus/openspec은 ralph가 자동 강제하지 않으므로 wrapper 책임)
        각 iteration:
          a. 다음 Task 선택 (05.tasks/todo.md 또는 openspec/changes 기반)
+         a-1. `scripts/build-iteration-gate.sh pre-task` → /openspec-propose 자동
          b. TDD Red 작성
+         b-1. tdd-guide 에이전트 확인(Red 상태 검증)
          c. TDD Green 작성
+         c-1. tdd-guide 에이전트 확인(Green 상태 검증)
          d. /consensus 자동 호출 (내부 합의 루프 max 3)
+         d-1. /codex:review --wait 자동(consensus-loop SKILL 통해)
          e. 커밋 + 03.archive로 task 이동
+         e-1. /openspec-apply-change 자동 → openspec/specs 갱신
          f. SessionEnd 훅이 learnings 갱신
   ```
```

### 패치 P4 — §4 SessionStart 훅 Codex 분기 명시

```diff
-Codex 등록: `.codex/config.toml`에 동일 셸 스크립트 경로 지정 `[열림]` Codex CLI의 정확한 hooks 키는 Architect가 검증.
+Codex 등록 [Architect 검증 완료, 2026-05-13]:
+1. `.codex/hooks.json` 별도 파일에 hooks 등록 (config.toml 내부 두면 v0.124.0 TOML 오류).
+2. `.codex/config.toml`에 `[features] codex_hooks = true` 추가.
+3. matcher는 `startup|resume`로 보수 등록 (Claude의 `clear|compact` 토큰은 Codex 미지원 추정).
+4. `/setup-codex`가 `codex trust .` 안내 또는 자동 실행 (project-local hooks 신뢰 게이트).
+5. hooks 진입점은 superpowers 패턴(`hooks/run-hook.cmd` 단일 분기)을 따라 양쪽 공유.
```

### 패치 P5 — §8.3 plugin.json `entry` 필드 제거

```diff
   ```json
   {
     "name": "ai-agent-harness",
     "version": "0.1.0",
     "description": "개인 맞춤형 개발 하네스 — Claude+Codex 양립",
-    "entry": {
-      "commands": ".claude/commands",
-      "skills": ".claude/skills",
-      "hooks": ".claude/hooks",
-      "rules": ".claude/rules"
-    },
+    "author": { "name": "...", "email": "ceo@yunjadong.com" },
+    "homepage": "https://github.com/{personal-account}/ai-agent-coding-template",
+    "repository": "https://github.com/{personal-account}/ai-agent-coding-template",
+    "license": "MIT",
+    "keywords": ["harness", "tdd", "consensus", "claude-code", "codex"],
     "requires": {
       "claude-code": ">=2.0.0",
       "codex-plugin-cc": ">=0.1.0"
     }
   }
   ```
+ 디렉터리 컨벤션: commands/, skills/, hooks/, agents/는 plugin 루트 기준 자동 인식 (entry 필드 불필요).
```

### 패치 P6 — §8.2 회사계정 복제 안전장치 추가

```diff
 - **알고리즘**:
-   1. 개인 레포의 stable 태그(또는 main HEAD)를 clone
-   2. `.git`은 초기화하지 않고 새 origin 추가 옵션 제공(개인계정 fetch, 회사계정 push)
-   3. `04.docs/ONBOARDING.md` 가이드 출력
+   1. `git clone --depth 1 <personal-repo> <target-dir>` (shallow clone — 개인 git history 분리)
+   2. 자동 cleanup: `rm -rf .git .env* .claude/settings.local.json .omc/state .omc/logs`
+   3. `git init && git add . && git commit -m "init from harness template"` (회사계정 fresh history)
+   4. 사용자 confirm: 새 remote URL, branch(dev/main), 환경변수 분리 안내
+   5. `04.docs/ONBOARDING.md` 가이드 출력
+ - 안전장치: 2번 단계는 dry-run으로 먼저 보여주고 사용자 confirm 후 실행.
```

### 패치 P7 — §5.4 learnings 자동 트림 임계 명시

```diff
-- **[추천]** Phase 2에서는 도입하지 않음. 이유: ...
+- **[추천]** 가중치 감쇄는 Phase 2 미도입. 대신 카테고리별 자동 트림 임계 적용:
+  - preferences/pitfalls: 각 200줄 초과 시 오래된 항목을 `.omc/learnings/_archive/{YYYY-MM}.md`로 자동 이동
+  - patterns: 100줄 초과 시 동일 archive 이동
+  - glossary: 100줄 초과 시 동일 archive
+  - SessionStart 출력 끝에 `[ctx-budget] approx ~XYZK tokens` 로깅 (사용자 모니터링)
```

---

## 5. Critic이 추가 검토해야 할 영역 (추천 3가지)

1. **MVP 1차(Phase 0~3) 종료 후 사용자 워크스루**: "내일부터 쓸 수 있다"의 정의가 구체적인가? 사용자가 다음 5개 시나리오를 막힘 없이 수행 가능한지 시뮬레이션 필요:
   - (a) 새 프로젝트에 `/setup-both` → 양쪽 CLI 셋업 완료
   - (b) `/double-check` 한 번 호출 → 의도 분해 + 질문 출력
   - (c) `/learn` 한 번 호출 → preferences.md에 항목 append
   - (d) 같은 프롬프트 3회 입력 → `03.archive/prompts/`에 자동 생성 확인
   - (e) 세션 종료 후 재시작 → SessionStart 훅이 (c)의 학습을 자동 주입

2. **Phase 4(/consensus)와 Phase 9(/build)의 Task 분할 정밀도**: 30분~2시간 단위 TDD 가능성이 약함. Phase 4를 (4.1 SKILL 본문, 4.2 명령 정의, 4.3 파싱, 4.4 루프 제어, 4.5 통합 테스트)로 5분할했으나, **각 항목이 실제 TDD 가능한 단위인지** 셸 스크립트 단위 테스트(bats)로 검증 가능한지 확인 필요.

3. **듀얼 어댑터 SPOF 정밀 시뮬레이션**: Codex CLI가 (a) 미설치, (b) 인증 만료, (c) 모델 응답 timeout, (d) 잘못된 형식 응답(`VERDICT` 토큰 누락) 4가지 시나리오에서 `/consensus`가 어떻게 동작하는지 — `--skip-codex`를 도입하지 않기로 했으므로, **각 시나리오에서의 사용자 confirm UX 정의 필요**.

---

## 6. 검증 필요 플래그 (Architect 단독으로 확정 불가)

- [ ] Codex의 `CODEX_PLUGIN_ROOT` 환경변수 실측 (공식 문서 미확인, superpowers는 사용 안 함). 사용자가 `oh-my-codex` 환경에서 `env | grep -i codex` 출력 공유 필요.
- [ ] Codex `.codex-plugin/plugin.json`의 마켓플레이스 등록 절차 (공식 페이지 미공개). superpowers 5.0.7가 등록 중인지 확인 필요.
- [ ] `~/.claude/plugins/cache/omc/oh-my-claudecode/4.1.2/`의 `codex-plugin-cc` 스킬 의존성 — Planner §10.2 리스크 매트릭스의 "codex-plugin-cc 미설치 시 /consensus 작동 불가" 보완책 검증.
- [ ] superpowers의 `hooks/run-hook.cmd`처럼 polyglot wrapper를 채택할지, POSIX 셸 단일로 갈지 (Windows 사용자 미사용이면 POSIX 단일 충분).

---

## 7. 결론

**Planner 초안의 전반적 품질**: 우수. 6개 닫힌 결정을 정확히 반영했고, 7개 MVP 커맨드의 알고리즘 명세가 구체적이며, Phase 분해가 합리적임.

**Architect 부분 도전 사항 (요약)**:
- **BLOCKER 2건**: Phase 0 단일 커밋 → Task별 즉시 커밋 분할 / `--skip-codex` 비상 옵션 → 사용자 confirm 폴백.
- **CONCERN 5건**: `/build` ralph wrapper 명세 / 회사계정 복제 안전장치 / plugin.json `entry` 제거 / Codex 훅 enable·신뢰 명시 / learnings 자동 트림.
- **PASS 3건**: 듀얼 어댑터 골격 (superpowers로 입증), trigram fuzzy match 선택, 이 템플릿이 자체 강제 규칙 준수.

**합의 권고**: 위 7개 패치(P1~P7)를 plan에 반영한 뒤 Critic 단계로 이행. Critic은 §5의 3가지 영역(MVP 워크스루, Task 분할 정밀도, SPOF 시뮬레이션)을 도전.

---

## 부록 — 출처 (cite as file:line / URL)

- Codex CLI hooks 공식: https://developers.openai.com/codex/hooks
- Codex CLI config: https://developers.openai.com/codex/config-reference
- Codex hooks v0.124.0 버그: https://github.com/openai/codex/issues/19199
- Codex hooks repo-local config 버그: https://github.com/openai/codex/issues/17532
- Claude Code plugin docs: https://code.claude.com/docs/en/plugins
- superpowers 5.0.7 plugin.json: `/Users/nathaneast/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/.claude-plugin/plugin.json:1-20`
- superpowers 5.0.7 codex plugin.json: 같은 경로 `.codex-plugin/plugin.json:1-44`
- superpowers 5.0.7 hooks.json: 같은 경로 `hooks/hooks.json:1-16`
- superpowers polyglot wrapper: 같은 경로 `hooks/run-hook.cmd:1-40`
- OMC ralph 명령 (TDD/consensus 미강제 증거): `/Users/nathaneast/.claude/plugins/cache/omc/oh-my-claudecode/4.1.2/commands/ralph.md:1-124`
- 로컬 Codex hooks.json 실측: `/Users/nathaneast/.codex/hooks.json` (전체)
- 로컬 Codex config.toml 실측: `/Users/nathaneast/.codex/config.toml:1-15` (features 비활성 확인)
- CLAUDE.md 강제 규칙: `/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/CLAUDE.md:14-15, 41, 42-48`
- Planner 초안: `/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/plans/harness-template-mvp-plan.md` (전체)
- Open Questions: `/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/plans/open-questions.md` (전체)
