# v3→v4 Architect Review (Round 2) — `nathaneast_ai-agent-coding-template`

> **합의 사이클 3단계 산출물 (Architect 2차)**. Planner v4가 1차 BLOCKER 6건을 해소했는지 + 새 BLOCKER 발생 여부 결정적 검증.
> **작성자**: Architect (Claude Opus 4.7) | **작성일**: 2026-05-14
> **검증 대상 결정**: Q1=A, Q2=A, Q3 재정의, Q4=A, Q5, Q6=A — 뒤집기 0건 확인.

---

## 0. 최종 판정

**VERDICT: APPROVE (조건부)** — BLOCKER 0, MAJOR 2 (Q-M/Q-N 사용자 회답 + Phase 0.0 실측). Phase 0.0 즉시 착수 권고.

| 영역 | 결과 |
|------|------|
| 1차 BLOCKER 6건 | 5 SOLVED + 1 PARTIALLY-SOLVED (V4-N3로 격하) |
| V4-N1~N5 | 4 PASS + 1 CONCERN (V4-N3) |
| 사용자 6개 결정 | 6/6 보존 |
| v0.1.0 자산 회귀 | 0건 (§10-bis + Phase별 bats 게이트) |

---

## 1. 1차 BLOCKER 검증

### B-A1 (SessionStart cwd) — **[SOLVED]**
§5.1 line 280 `PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"` + `HARNESS_GLOBAL_ROOT` 분리, 1차 권고 diff와 일치. Phase 0.0 line 505-513에서 WebFetch + bats 4개 실측 명시(1차 "Phase 1 0순위"보다 앞당김). 폴백 결정성 리스크 §5.6 명시. 실행으로 닫힘.

### B-A2 (사용자 deny 충돌) — **[SOLVED]**
§4.1 line 192-215: 2단(`curl -o + bash`) 의무. §4.3 line 232-244: 셸 jq + atomic mv → Edit/Write 도구 비사용으로 사용자 `Edit/Write(~/.claude/settings.json)` deny 자연 회피. §4.5 line 260 "deny 룰 삭제 금지(보존만)". §4.6 line 268 추후 `Bash(jq > settings)` deny 가능성 README 안내.

### B-A3/B-C1 (Phase 0 5분할) — **[SOLVED]**
§9 line 505-563: 0.0 + 0.A~0.E **6분할**(권고보다 세분). 게이트: 0.0 WebFetch+bats 4/4, 0.A 카운트 일치, 0.B~0.E bats 45/45, 0.E `/setup-both` 5/5 + v0.2.0-alpha tag. 합계 ~3.5시간. tag는 0.E 후로 명시되어 rollback 단위 안전.

### B-C1 (paths.sh + 9 스크립트) — **[SOLVED]**
§3.1 line 94/117: `scripts/lib/paths.sh` + `plugin/claude/hooks/lib/paths.sh` 분리. §9 Phase 0.B line 525-533: 9개 스크립트 파일/라인 구체 명시. 단일 commit이 적절(중간 hybrid면 bats 실패). 60분 추정 부합.

### B-C2 (/merge-skill secret) — **[PARTIALLY-SOLVED → V4-N3로 격하]**
§7.2 line 401 commit 기본 비자동, confirm 후, `--auto-commit` opt-in. 정규식 5종 + .env 차단(line 416-422). §7.4 회사 PC 경고 박스. §7.5 false-negative 인정. 다층 방어 5개 → BLOCKER 자격 상실. 정밀도 우려는 V4-N3.

### B-C3 (자기 dogfood 회귀) — **[SOLVED]**
§3.5 line 186 `.harness-active` 1행 `mode=source-repo`. §5.1 line 286-291 훅이 `head -n1 | grep mode=`로 분기 → `CONTENT_BASE` 다르게 설정. §6.4 line 380-384 `/pjt-init` source-repo 모드 시 no-op. Phase 0.D + 6.B 게이트(line 551, 636)에서 본 레포 source-repo SessionStart 정상 + bats 45/45 검증. 세 위치 일관 강제.

---

## 2. 신규 영역 V4-N1~N5

### V4-N1: paths.sh — **[PASS]**
함수 명명 명확(§9 line 527: `harness_global_root()`, `harness_skills_dir()` 등). v0.1.0 9개 스크립트가 Bash 3.2+ macOS 검증 → 단순 echo 함수면 안전. source 비용 ms 단위. bats 6개+ 명시. `_or_die` suffix는 fail-fast 패턴.

### V4-N2: jq atomic mv — **[PASS within bounds]**
flock + 백업 + jq -s + jq empty + atomic mv 시퀀스 정확. **잔존 우려**: jq `*` 연산자가 **배열에는 replace**(union 아님). 사용자 `deny:["A","B"]` + patch `deny:["C"]` → `["C"]` 손실 가능. §4.3 line 246 "deep merge로 보존"은 객체엔 맞으나 배열엔 부정확. **권고**: Phase 1 bats(line 575)가 jq 배열 동작 실측 의무 + settings.template.json `deny`는 빈 배열로 시작, 객체 키만 patch. BLOCKER 아님 — Phase 1 bats가 잡으면 즉시 수정 가능.

### V4-N3: secret 정규식 — **[CONCERN]**
5종(OpenAI/api_key/password/PEM/AWS) + .env 차단. **누락**: GitHub PAT(`ghp_`,`github_pat_`), Slack(`xoxb-`), Stripe(`sk_live_`), GCP SA JSON, JWT, OAuth refresh. **FP**: `api_key=$(cat ~/secrets)`. **FN**: base64, 환경변수 참조. §10.1 R8 line 683 trufflehog v0.3.0+ RFC + §7.5 사용자 책임 명시. Phase 4 bats(line 619) FP/FN 측정 → Q-R(open-questions.md:216) 실측 후 차단 여부 결정. **권고**: Phase 4에 `ghp_[A-Za-z0-9]{36}` + `xox[baprs]-` 2종 저비용 추가. BLOCKER 아닌 이유: 다층 방어(confirm/정규식/.env차단/README경고/Q-N fork) + Phase 4 실측.

### V4-N4: --from-tar — **[PASS]**
§4.2 line 227 옵션 + §8.5 line 488-495 4등급 매트릭스. **잔존**: tarball 생성/sha256 미명세. **권고**: Phase 7 RELEASE_NOTES + gh CLI(line 649)에 tarball 자동 첨부 + `tarball.sha256`. v0.2.0 1순위는 curl, air-gapped는 secondary.

### V4-N5: Phase 0.0 — **[PASS]**
WebFetch `docs.anthropic.com` + bats 4개 + `jq '.permissions.deny[]'` 인벤토리. `04.docs/CLAUDE_PROJECT_DIR-verification.md` 커밋. 게이트 WebFetch+bats 4/4. 실패 시 §5 재검토 명시. 30분 추정 충분.

---

## 3. 회귀 / 결정 보존

§10-bis line 709-721 매트릭스 7항(13 skills/9 commands/45 bats/7 KPI/consensus 3단/resume-session A·B/env-security 5단)이 Phase 0.A→0.E→5 게이트로 강제. Phase 5 line 628 검증 보고서 의무. **회귀 위험 0건**.

| Q | 결정 | 보존 위치 |
|---|------|---------|
| Q1=A | GitHub+curl | §4(한 줄→2단, 결정 보존) |
| Q2=A | /pjt-init | §6 |
| Q3 재정의 | 컨텐츠 로컬/자산 글로벌 | §3.3, §5.5 |
| Q4=A | /merge-skill --to-template | §7(confirm 안전화) |
| Q5 | 레포명 | §3.1 line 74 |
| Q6=A | OMC 위 개인 레이어 | §5.4 |

**뒤집기 0건**. 구현 방식만 안전성 강화.

---

## 4. Open Item

| # | 항목 | 차단도 |
|---|------|--------|
| Q-M | 회사 PC 네트워크 | MAJOR (--from-tar 폴백 존재) |
| Q-N | 회사 PC fork vs 동일 | MAJOR (secret 영향 범위) |
| V4-N3 잔여 | GitHub PAT/Slack 추가 | MINOR |
| V4-N2 잔여 | jq 배열 실측 | MINOR |
| Q-O | CLAUDE_PROJECT_DIR 실측 | MUST (착수가 해소) |

---

## 5. 권고

1. **Phase 0.0 즉시 착수**(30분). Q-O 닫힘.
2. **Q-M, Q-N 사용자 회답**을 Phase 4/5 진입 전 수령. Q-N=fork 시 secret 영향 단일 fork로 제한.
3. **Phase 4 정규식 2종 추가** (`ghp_`, `xox[baprs]-`).
4. **Phase 1 bats 보강**: jq `*` 배열 동작 실측 + settings.template.json `deny` 빈 배열 시작.
5. **Critic 2차 검토**: APPROVE 상태로 전달.

---

## 6. References

- `/Users/nathaneast/Desktop/coding_project/ai-agent-coding-template/.omc/plans/v3-global-tool-plan.md:280` — PROJECT_CWD
- `v3-global-tool-plan.md:192-215` — 2단 install
- `v3-global-tool-plan.md:232-244` — jq atomic mv 시퀀스
- `v3-global-tool-plan.md:416-422` — secret 정규식 5종
- `v3-global-tool-plan.md:505-563` — Phase 0.0~0.E 6분할
- `v3-global-tool-plan.md:709-721` — v0.1.0 자산 보존 매트릭스
- `v3-global-tool-plan.md:286-291` — source-repo 모드 분기
- `.omc/plans/open-questions.md:198,215,216` — Q-M, Q-N, Q-R

---

**VERDICT: APPROVE.** BLOCKER 0, MAJOR 2(사용자 회답), CONCERN 2(정규식 정밀도, jq 배열). Critic 2차 입력 가능.

**문서 끝.**
