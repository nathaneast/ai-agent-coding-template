# Phase 5 — Decision (Pre-Verification)

## 권고안: Opt-D Hybrid 메모리 아키텍처

### 결정
**3-Tier + Inject + `#g/#p` 명시 prefix 우선 + Phase 3 비협상 가드 5종**

### 구조

```
Tier 1: 휘발 (이 PC만, 7일)
  → Claude Code <remember> 태그 (30일 운영 후 실측. 호출 <3회면 폐기 재검토)

Tier 2: 프로젝트 영속 (이 프로젝트 git)
  → <project>/06.memory/  (top-level, 사용자 Req#8)
      ├─ project.md     (결정·사실)
      ├─ feedback.md    (시도·실패 교훈)
      ├─ reference.md   (외부 포인터)
      ├─ CHANGELOG.md   (정정 로그, append-only, provenance)
      └─ MEMORY.md      (인덱스)
  
  → SessionStart 훅이 cat → <system-reminder>로 inject
    (NO 미러링 to ~/.claude/projects/<abs>/memory/ — R1 회피)
  → /cm 일상 흐름에 자연 포함

Tier 3: 사용자 글로벌 (본 하네스 git, 횡단)
  → 본 하네스/plugin/memory/user/
      ├─ user.md          (작업성향 — 무엇을 어떻게)
      ├─ comfort.md       (쾌적한 작업 — 작업 흐름·페이스)
      ├─ goals.md         (작업관점·골 — 무엇을 향해)
      ├─ dont.md          (하지말것·금기)
      └─ INDEX.md
  → /push-global-memory 명시 호출만 (3단계: stage+commit+dual push)
  → SessionStart inject (Tier 2와 동일 메커니즘)
```

### 라우팅 (사용자 Req#2)

**계층 1 (명시 prefix, 우선)**:
- `#g/<내용>` → Tier 3 (글로벌)
- `#p/<내용>` → Tier 2 (프로젝트)
- `#t/<내용>` → Tier 1 (휘발, `<remember>` 태그)

**계층 2 (자동 분류, fallback)**:
prefix 없으면 Claude가 의미 분류:
- "이따 할거니 기억해" / "내일" → Tier 1
- "재훈씨가 X 요청" / "이 모듈은 W 결정" → Tier 2 (project.md)
- "나는 X 선호" / "항상 Y" → Tier 3 (user.md)
- "Z 하지마라" → Tier 3 (dont.md)

**계층 3 (불확실 → 되묻기)**:
"글로벌(모든 프로젝트)인가 이 프로젝트만인가?" 1줄.

### Phase 3 비협상 가드 (5종)

| 가드 | 구현 위치 | 효과 |
|---|---|---|
| G1. 명시 prefix `#g/#p/#t` | `plugin/claude/rules/memory.md` 최상위 룰 | M2 라우팅 ≥9/10 |
| G2. TTL (`expires:` frontmatter) | `06.memory/*.md` + `plugin/memory/user/*.md` + 월 1회 prune | M9 stale 방지 |
| G3. CHANGELOG 정정 로그 | `06.memory/CHANGELOG.md` + `plugin/memory/user/CHANGELOG.md` append-only | M6 rollback ≤2 단계 |
| G4. 비밀 스캔 hook | `plugin/claude/hooks/memory-write-guard.sh` (PreToolUse Write) — NDA·고객명·금액·token 정규식 차단 | M7 누출 0건 |
| G5. 충돌 해결 정책 | `/push-global-memory` 파이프라인 — yunjadong-team = ground truth, nathaneast = `--force-with-lease`, 충돌 시 사용자 확인 | M5/R4 |

### /push-global-memory 파이프라인 (3단계 트랜잭션)

```
1. STAGE   : cd ~/.claude/plugins/nathaneast-aiacht 
             → pre-flight (memory/ 외 변경 abort) 
             → git fetch + pull --rebase --autostash
             → git add plugin/memory/user/
2. COMMIT  : git commit -m "memory: <auto summary>"
3. PUSH    : git push origin main (yunjadong-team, ground truth)
             → git push nathaneast main --force-with-lease (미러)
             → ls-remote 검증
             → 충돌 시 revert + 사용자 확인
```

### 다른 PC sync

기존 `scripts/update.sh` 그대로 사용 (`git pull --ff-only`). 다음 세션 SessionStart 훅이 자동 inject.

### 구현 변경 (9 파일)

| 파일 | 변경 |
|---|---|
| `templates/project-init/06.memory/` | 신규 5 파일 (project/feedback/reference/CHANGELOG/MEMORY.md) |
| `scripts/pjt-init.sh` | `06.memory/` 폴더 생성 추가 |
| `plugin/memory/user/` | 신규 5 파일 (user/comfort/goals/dont/INDEX.md + CHANGELOG.md) |
| `plugin/claude/rules/memory.md` | 전면 재작성 — prefix 룰 + 자동 분류 fallback + 가드 명세 |
| `plugin/claude/hooks/session-start.sh` | Tier 2+3 inject 로직 추가 (~10 LOC) |
| `plugin/claude/hooks/memory-write-guard.sh` | 신규 (~30 LOC, 정규식 차단) |
| `plugin/claude/commands/push-global-memory.md` | 신규 |
| `scripts/push-global-memory.sh` | 신규 (~35 LOC, mirror-personal.sh + merge-skill.sh 패턴 재사용) |
| `README.md` §6 | 4-계층 + Phase 3 가드 명시 / §3 표 13→14 |
| 글로벌 `~/.claude/CLAUDE.md` | memory.md 링크 추가 (1줄) |

### 운영 후 30일 재검토 트리거

- `<remember>` 호출 <3회 → Tier 1 폐기
- 자동 라우팅 정확도 <8/10 → prefix 강제
- `comfort.md` vs `user.md` 횡단 메모 5건 비겹침 안 보이면 → 1축 압축 (C 소수의견)
