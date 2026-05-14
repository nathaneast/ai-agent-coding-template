# Open Questions — Planner 산출물 v2

> v2 변경: 합의 사이클 2차 라운드 (Architect+Critic 검토) 결과 반영. v1의 사용자 확인 6건 중 닫힌 항목은 [CLOSED] 마크 + 결정 결과 명시. v2 신규 사용자 확인 사항 별도 섹션 추가.

## harness-template-mvp-plan — 2026-05-13

### 사용자 6개 확정 결정 (뒤집기 금지) — 참조용

- **Q1** = B (Claude 메인 워커 + Codex 리뷰어 비대칭)
- **Q2** = A (SessionStart 훅 자동 주입) + 명시 호출 옵트인
- **Q3** = A (`.omc/learnings/` 영속성)
- **Q4** = A (OpenSpec 도입)
- **Q5** = ALL (7개 MVP 커맨드 모두)
- **Q6** = 개인계정 + 회사계정 복제 + Claude/Codex 플러그인 마켓플레이스 병행

---

### 1차 라운드 사용자 확인 6건 (v1) — 갱신

- [CLOSED 추천 채택] `.omc/learnings/_decay.json` 가중치 감쇄 도입 여부
  - **결정**: 미도입. 대신 카테고리별 자동 트림 임계 (P7): preferences/pitfalls 200줄, patterns/glossary 100줄.
  - **근거**: Architect §B 카테고리 트림 권고. Critic 영역 5 동의.
  - **v2 위치**: §5.4

- [CLOSED 추천 채택] 프롬프트 자동 아카이빙 빈도 임계값
  - **결정**: **3회** (Planner 추천 유지).
  - **근거**: 빠른 자동화 우선. fuzzy match는 trigram + Jaccard 0.7 (P2).
  - **v2 위치**: §7.3

- [ ] 세션 인덱스 보관 최대 개수 — 50개 vs 100개
  - **상태**: 미결정. v1 추천 50개 유지하나 사용자 명시 확인 필요.
  - **v2 위치**: §7.6 (v1 동일)

- [ ] `/build` 기본 max-hours — 8 vs 10 vs 무제한
  - **상태**: 미결정. Phase 9 셋업 시 결정 [열림].
  - **v2 위치**: §7.7

- [CLOSED 추천 채택] `.omc/` vs `.omx/` 명명
  - **결정**: `.omc/` 유지.
  - **근거**: OMC 표준 도구가 `.omc/` 경로 하드코딩 (`state_read`, `notepad_write_*`).
  - **v2 위치**: §2.3

- [ ] `policy/` 마이그레이션 후 잔존 방식 — 완전 삭제 vs `DEPRECATED.md` stub
  - **상태**: Architect 권고 = `DEPRECATED.md` stub 유지 (1.3 CONCERN). 사용자 외부 자동화 하드코딩 가능성 확인 필요.
  - **v2 위치**: §2.1 policy/ + Phase 6.3

### 1차 라운드 합의 종결 신호 — 갱신

- [CLOSED 추천 채택 + 폴백 추가] `/consensus` 종결 토큰 — 명시적 `VERDICT: APPROVE|REQUEST_CHANGES`
  - **결정**: 명시 토큰 의무화 + 3단 폴백 (C4 대응).
    1. 동의어 토큰 매칭 (`RECOMMENDATION:|FINAL:|결론:`)
    2. 본문 키워드 검색 + 사용자 1회 confirm
    3. REQUEST_CHANGES로 안전 처리
  - **v2 위치**: §3.2

### 1차 라운드 Architect 검증 — 갱신

- [CLOSED Architect §1.1 검증 완료] Codex CLI hooks 키 형식
  - **결정**: `.codex/hooks.json` 별도 파일 + `[features] codex_hooks = true` (P4, v0.124.0 버그 회피).
  - **v2 위치**: §4.2

- [CLOSED Architect §1.1 PASS] `.codex/hooks/session-start.sh` Claude 본체 래퍼 가능 여부
  - **결정**: 가능. superpowers 5.0.7 패턴 검증됨.
  - **v2 위치**: §3.3, §4.2

- [CLOSED Architect §F PASS] `.claude-plugin/plugin.json` / `.codex-plugin/plugin.json` 실제 스키마
  - **결정**: `entry` 필드 제거 (P5). 컨벤션 디렉터리만 사용 + author/homepage/repository/license/keywords 추가.
  - **v2 위치**: §3.4, §8.3

- [CLOSED Architect §B 실측] SessionStart 훅 stdout 토큰 상한
  - **결정**: 7K 보수 상한 유지. 실측 ~5,700 토큰.
  - **v2 위치**: §4.5

- [CLOSED Architect §1.2 PASS] 프롬프트 자동 아카이빙 fuzzy match
  - **결정**: **trigram + Jaccard ≥ 0.7** (POSIX 셸 30줄). simhash는 Phase 9 RFC.
  - **v2 위치**: §7.3

- [CLOSED Architect §1.4 CONCERN] OMC `ralph` 스킬이 `/build` 요구 충족 여부
  - **결정**: ralph 4.1.2는 TDD/consensus/openspec **자동 강제 안 함**. wrapper 가드 셸 (`scripts/build-iteration-gate.sh`) 직접 강제 (P3).
  - **v2 위치**: §7.7, Phase 9.2

### 1차 라운드 Critic 도전 — 갱신

- [CLOSED Critic 영역 7 보강] Phase 분해 각 Task 30분~1시간 + TDD 가능성
  - **결정**: v1 30분~2시간 → v2 30분~1시간으로 조정. Phase 0 5분할 (0.A~0.E). Phase 5 +1시간 (5.0 실측).
  - **v2 위치**: §9

- [CLOSED Critic 영역 1 + D dogfood] Phase 3 종료 "내일부터 쓸 수 있다" 검증
  - **결정**: MVP-A 5개 사용자 시나리오 dogfood 게이트 (§11 P3). MVP 정의 2단계화 (MVP-A: Phase 3 / MVP-B: Phase 5).
  - **v2 위치**: §0, §11

- [CLOSED Architect §1.4 + Critic 영역 4 BLOCKER] 듀얼 어댑터 SPOF
  - **결정**: `--skip-codex` 비상 옵션 제거. 3단 폴백 (재시도 → critic 대체 → 일시정지 + USER_CONFIRM_NEEDED 마커).
  - **v2 위치**: §10.3

- [CLOSED Architect §D] `01.spec/` vs `openspec/specs/` 이중 진실 소스
  - **결정**: `02.workflow/spec-flow.md` + PostToolUse 훅 경고 (차단 안 함, 알림만).
  - **v2 위치**: §6.4, Phase 6.5

- [CLOSED Architect §B + P7] 컨텍스트 폭발 경계
  - **결정**: 토큰 상한 7K + 카테고리 자동 트림 임계 + ctx-budget 로깅.
  - **v2 위치**: §4.5, §5.4

---

### 2차 라운드 신규 사용자 확인 사항 (v2)

> v2 변경: Architect+Critic 검토 결과 신규 발생한 사용자 의사결정 사항.

- [ ] **learnings 자동 트림 정밀 임계** (P7 후속)
  - 현재 결정: preferences/pitfalls 200줄, patterns/glossary 100줄.
  - 추가 결정 필요: (a) 라인 수 단순 vs 토큰 수 정밀? (b) 일수 기반 추가 트림 (90일 미참조 시 archive)? (c) priority 가중치 감쇄 도입 시점 (Phase 9? v0.2.0?)
  - **v2 위치**: §5.4

- [ ] **Phase 5의 `/resume-session` 실측 실패 시 대체 메커니즘 우선순위** (B3)
  - 시나리오 B 대안 후보:
    1. archive 본문 → 새 세션 system prompt 자동 주입 (`claude -p "$(cat archive.md)"`)
    2. 워크트리 + branch 기반 체크포인트 (`scripts/checkpoint-branch.sh` 자동 branch 생성)
    3. `.omc/sessions/archive/` 본문 dump를 다음 Claude 세션 SessionStart 훅으로 주입
  - 우선순위 결정 필요. **추천**: 1번 (단순) → 실패 시 2번 (안정성).
  - **v2 위치**: §7.6-bis

- [ ] **회사계정 복제 시 자동 제외 파일 목록 확정** (P6 + C-A)
  - 현재 제거 대상: `.git`, `.env*`, `.claude/settings.local.json`, `.omc/state`, `.omc/logs`
  - 추가 결정 필요: `.omc/sessions/`도 제거할지? (개인 세션 인덱스 누출 vs 회사 환경 학습 연속성 손실 trade-off)
  - **추천**: 제거 (사용자 동의 시). 사용자가 명시 선호하는 경우만 유지.
  - **v2 위치**: §8.2

- [ ] **Dogfood 더미 프로젝트 시나리오 선택** (C-D)
  - Phase 9.5에서 `/build` 자동 완료 검증할 더미 PRD 시나리오 결정.
  - 후보: (a) TODO REST API 3 endpoint (단순, 8시간 적정) (b) 간단 블로그 (CRUD + 인증, 10시간) (c) 사용자 정의 시나리오
  - **추천**: (a) TODO REST API — 측정 가능 + 검증 단순 + 시간 적정.
  - 사용자가 직접 선택 또는 AI 추천 수락?
  - **v2 위치**: §11 P9

- [ ] **§10.3 2단 critic 대체 리뷰 사전 승인** (B1 후속)
  - CLAUDE.md "임의 우회 금지" 해석:
    - 옵션 A: critic 대체 리뷰는 명시적 폴백 인프라이므로 허용. `/setup-build`에 옵션 노출.
    - 옵션 B: critic 대체도 우회로 간주, 3단(일시정지) 단독만 허용. 야간 빌드는 Codex 일시 장애에서 무조건 중단.
  - **추천**: 옵션 A (사용자 명시 confirm 후 활성화). 단 사용자 결정.
  - **v2 위치**: §10.3

- [ ] **§10.3 알림 채널 통합 시점** (B5)
  - Codex 장애 + USER_CONFIRM_NEEDED 마커 작성 시 Slack/Telegram/Discord 알림 통합.
  - 결정 필요: (a) Phase 9 MVP에 포함 (b) v0.2.0 RFC로 분리.
  - **추천**: (b) v0.2.0. MVP는 SessionStart 알림으로 충분.
  - **v2 위치**: §10.3

- [ ] **§7-bis 부트스트랩 기간 `mcp__x__ask_codex` 직접 호출 허용 범위**
  - 부트스트랩 기간(Phase 0~3) Architect 검증 등 정보 수집 용도에 한해 MCP 직접 호출 허용 명시.
  - CLAUDE.md "codex-plugin-cc 스킬 경유 의무"와의 정합성: 합의 루프(`/codex:review`)는 슬래시 경유, **정보 수집(`ask_codex`)은 MCP 허용** — 사용자 명시 확인.
  - **v2 위치**: §7-bis

- [ ] **Phase 0~3 부트스트랩 기간 무인 빌드 금지 정책 확인**
  - v2 §7-bis는 "Phase 0~3은 유인 세션, 무인 빌드(/build) 금지" 명시.
  - 사용자가 부트스트랩 기간 동안 무인 빌드를 시도할 가능성 → 명시적 금지 동의 확인.
  - **v2 위치**: §7-bis

- [ ] **Phase 4.0 Architect 실측 시간 추정 정확성**
  - `/codex:review --wait` 호출 메커니즘 실측 (슬래시 chain vs 셸 `claude -p`).
  - 1시간 추정이 정확한가? 실측 결과 정의 안 되면 Phase 4 일정 ↑.
  - **v2 위치**: §9 Phase 4.0

- [ ] **`_dogfood/` 디렉터리 .gitignore 처리**
  - `_dogfood/`를 git 커밋 대상으로 할지, .gitignore에 추가할지.
  - **추천**: 커밋 대상 (dogfood 결과를 plan 검증 증거로 보존). 단 빌드 산출물(node_modules 등)은 .gitignore.
  - **v2 위치**: §2.1 _dogfood/

---

### 영구 [열림] 항목 (Phase 9 RFC 후보)

- 가중치 감쇄 도입 시점 + 알고리즘 (5%/주 vs 다른 패턴)
- 마켓플레이스 동시 등록 (Claude + Codex) 시 버전 동기화 자동화
- IDE 통합 (VSCode extension 등) — 현재 Non-Goals (§4-bis)
- Windows 1차 지원 — 현재 Non-Goals (§4-bis)
- Codex 외 외부 LLM 어댑터 — 현재 Non-Goals (§4-bis)

---

## v3-global-tool-plan — 2026-05-14

> Planner v3 (글로벌 도구 + 템플릿 저장소 모델) 산출물. 사용자 컨셉 전환 후 첫 작성. v2와 무관한 새 결정 트리.

### 사용자 6개 확정 결정 (뒤집기 금지) — 참조용

- **Q1** = A (GitHub 템플릿 + curl 한 줄 install.sh)
- **Q2** = A (`/pjt-init` 슬래시 커맨드만, 셸 CLI 불필요)
- **Q3** = 컨텐츠 폴더만 로컬 (`01.spec/`~`05.tasks/` + `openspec/`), 스킬/훅/커맨드/룰은 전부 글로벌
- **Q4** = A (`/merge-skill --to-template <local-skill-path>`)
- **Q5** = A + prefix (레포명 `nathaneast_ai-agent-coding-template`)
- **Q6** = A (OMC 위 사용자 개인 레이어, OMC 안 건드림)

### Architect/Critic 검토 입력용 미확정 항목 (`[열림]`) — v4 갱신

- [CLOSED v4] Q-A: 글로벌 디렉터리 경로 — **`~/.claude/plugins/nathaneast_aiacht/`** (Architect 동의, OMC 패턴 일치).
- [CLOSED v4] Q-B (= v4 Q-K): `/pjt-init` 기본 동작 — **strict 기본 + `--merge` README 1순위 노출**. Architect/Critic 2차에서 재확인.
- [열림] Q-C (= v4 Q-M): 회사 PC GitHub 네트워크 환경 — **사용자가 직접 회사 PC에서 확인 후 회답**.
- [CLOSED v4] Q-D: v0.1.0 → v0.2.0 전환 — **B (본 레포 git mv + v0.2.0)**. Phase 0.A~0.E 5분할로 안전성 확보.
- [열림] Q-E: `/learn`, `/consensus` 짧은 이름 vs `/aiacht:learn` prefix — Critic 권고: 짧은 이름 + alias 양쪽 등록. v0.3.0+ RFC 후보.
- [CLOSED v4] Q-F (= v4 Q-L): install.sh hash 검증 — **v0.2.0 안내, v0.3.0+ 의무화**.
- [CLOSED v4] Q-G: 자동 commit/push 정책 — **기본 confirm 후 commit, push 안 함. `--auto-commit` opt-in**. (BLOCKER-Critic2)
- [CLOSED v4] Q-H: `--with-codex` 시 `~/.codex/` 자동 생성.
- [CLOSED v4] R1: SessionStart 훅 미사용 프로젝트 영향 — 본 하네스 비활성 시 0 byte 종료 + Phase 3 bats 10개.
- [CLOSED v4] R2: settings.json 머지 안전성 — flock + 백업 + jq deep merge + atomic mv + bats 12개 (Phase 1).
- [CLOSED v4] R3: /merge-skill --to-template 자동 commit — **기본 confirm 후 commit으로 역전**.
- [CLOSED v4] R4: curl|sh 보안 — **2단 패턴 의무 + sha256 옵션 + 사용자 deny 룰 준수** (BLOCKER-A2).
- [열림] R5: 회사 PC `~/.claude/` MDM 차단 — `--target` 옵션 + Non-Goal 명시. 실측은 Q-M과 연결.
- [열림] R6: OMC SessionStart 훅 우선순위 — 본 하네스 비활성 시 0 byte로 토큰 폭발 회피. 우선순위 API 워크어라운드는 v0.3.0+ RFC.

### v4 신규 미결정 항목

- [열림] **Q-O: CLAUDE_PROJECT_DIR 실측 결과** — Phase 0.0에서 WebFetch + bats 4개로 검증. BLOCKER-A1 해소 후 닫힘 예정.
- [열림] **Q-P: 자동 secret 스캔 정규식 정밀도** — Phase 4 후 precision/recall 측정. 목표: precision ≥ 0.9. 미달 시 trufflehog v0.3.0+ 이관 결정.
- [열림] **Q-N: 회사 PC fork 운영 vs 동일 레포 push** — secret 사고 방지를 위해 fork [추천]. 사용자 최종 결정 필요.
- [열림] **Q-R: v0.2.0 출시 차단 기준** — Phase 4 secret 스캔 false-negative 발견 시 출시 차단 vs v0.3.0+ 이관 — 사용자 결정.
- [CLOSED v4] **Q-Q: learnings 위치** — 프로젝트 로컬 (`.omc/learnings/`). 듀얼 PC 자동 동기화 없음(의도적).

### v3 → v4 통합 라운드 [CLOSED] 결정 (BLOCKER 6 + MAJOR 9)

- [CLOSED] B-A1: SessionStart 훅 PROJECT_CWD 도입 + Phase 0.0 실측.
- [CLOSED] B-A2: install.sh 2단 패턴(`curl -o + bash`) 의무.
- [CLOSED] B-A3/B-C1 (Phase 0): Phase 0을 0.0 + 0.A~0.E 6분할 + 각 게이트 bats 45/45.
- [CLOSED] B-C1 (paths.sh): `scripts/lib/paths.sh` + `plugin/claude/hooks/lib/paths.sh` 도입, 9개 스크립트 일괄 갱신.
- [CLOSED] B-C2: /merge-skill --to-template 기본 confirm 후 commit + secret 스캔 + 회사 PC 경고.
- [CLOSED] B-C3: 본 레포 `.harness-active`에 `mode=source-repo` 표기 + SessionStart 분기.
- [CLOSED] A-C: 글로벌 git 사전 안전 검사 5항 + 자동 rebase 시도.
- [CLOSED] A-G: install.sh 멱등성 + --uninstall 백업 복원 + --from-tar fallback.
- [CLOSED] C-1: "공통 설치"의 정의 박스(§6.0) — 6폴더 + 마커 + .gitignore만.
- [CLOSED] C-2/D: v0.1.0 자산 보존 매트릭스 7항(§10-bis) + Phase 5 검증 보고서.
- [CLOSED] C-7: 각 Phase 종료 시 bats 게이트 강제.
- [CLOSED] Critic 5.2: OMC 토큰 폭발 — 본 하네스 비활성 시 0 byte + 합산 14K 측정.
- [CLOSED] Critic 8.2: Phase별 시간 추정 명시 (합계 15~18시간).
- [CLOSED] Critic B: 미니멀 원칙 박스(§3.0) — 본 레포에 추가하는 것 4가지만.

### v4 트레이드오프 (정직한 자기 진단 — Architect/Critic 2차 입력)

- 2단 install vs 한 줄: 1단계 손 vs 사용자 deny 준수 + 무결성.
- Phase 0 5분할 게이트 vs 단일 commit: 작업 분량 ↑ vs rollback 단위 작음.
- /merge-skill confirm 기본 vs --auto-commit 기본: 자동화 후퇴 vs secret 사고 방지.
- learnings 로컬 vs 글로벌: 듀얼 PC 자동 동기화 없음 vs 컨텍스트 정합.
- 본 레포 source-repo 마커 키워드 vs 별도 마커 파일: 포맷 복잡도 ↑ vs self-dogfood 회귀 0.
- jq deep merge vs 수동 key add: jq 버전 의존 vs OMC/사용자 deny 무손실.

### v3 Non-Goals (v4 그대로 계승)

- npm 글로벌 배포
- 셸 CLI 명령 추가
- OMC 자산 직접 수정/대체
- Windows 1차 지원
- 자동 push 또는 자동 PR 생성
- 마켓플레이스 자동 동기화 RFC (v0.3.0+ 검토)
- 훅 priority API 워크어라운드 (v0.3.0+ RFC)
- trufflehog secret 스캔 통합 (Q-P 결과에 따라 v0.3.0+)
