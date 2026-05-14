# Memory Routing Rules — v0.4

본 규칙은 사용자가 "저장해/기억해/참고해/이따 기억해" 같은 자연어로 메모를 요청할 때 Claude가 *어디에* 저장할지 결정하는 규칙이다.

## 메모리 3-계층 구조

### Tier 1 — 휘발 (이 PC만, 7일 자동 만료)
- 위치: Claude Code `<remember>` 태그 (내장)
- 용도: 디버깅 메모, "내일 X 확인", 시점성 짧은 메모
- 30일 운영 후 호출 빈도 측정 → 3회 미만이면 폐기 재검토

### Tier 2 — 프로젝트 영속 (이 프로젝트 git)
- 위치: `<project>/06.memory/`
  - `project.md` — 결정·사실·패턴
  - `feedback.md` — 시도·실패 교훈
  - `reference.md` — 외부 시스템 포인터
  - `CHANGELOG.md` — 정정 로그 (append-only)
  - `MEMORY.md` — 인덱스
- 용도: 이 프로젝트에서만 유효한 결정·사실
- 동기화: `/cm` 일상 흐름에 자동 포함 (모든 PC에서 git clone 시 동기화)

### Tier 3 — 사용자 글로벌 (본 하네스 git, 횡단)
- 위치: 본 하네스/`plugin/memory/user/`
  - `user.md` — 작업성향 (코드 스타일/PR 크기 등)
  - `comfort.md` — 쾌적한 작업 (페이스·환경)
  - `goals.md` — 작업관점·골 (장기 방향)
  - `dont.md` — 금기 (절대 금지 사항)
  - `CHANGELOG.md` — 정정 로그
  - `INDEX.md` — 인덱스
- 용도: 모든 프로젝트·모든 PC 횡단 보편 가치만 (사적 정보·시크릿 절대 금지)
- 동기화: `/push-global-memory` 명시 호출로만 git push (자동 push X)

## 라우팅 우선순위 (사용자 발화 처리)

### 1순위: 명시 prefix (사용자가 원할 때)
- `#g/<내용>` → Tier 3 (글로벌)
- `#p/<내용>` → Tier 2 (프로젝트)
- `#t/<내용>` → Tier 1 (휘발)

prefix가 있으면 자동 분류 건너뛰고 즉시 해당 tier로.

### 2순위: 자연어 자동 분류 (디폴트 — 사용자가 prefix 안 쓸 때)
사용자가 "저장해/기억해/참고해/이따 기억해" 등 자연어로 요청 시 Claude가 *내용*을 보고 분류:

| 발화 패턴 | 분류 결정 | 저장 위치 |
|---|---|---|
| "이따 X 할거니" / "내일" / "잠깐 적어둬" | 시점성 짧음 → Tier 1 | `<remember>` 태그 |
| "재훈씨가 X 요청" / "이 모듈은 W로 결정" / "이 프로젝트는 Y 패턴" | 프로젝트 사실/결정 | `06.memory/project.md` |
| "이전에 A 했더니 실패" / "B 방식 효과 좋았어" (프로젝트 한정) | 프로젝트 교훈 | `06.memory/feedback.md` |
| "C 링크 참고해" / "Linear ABC 프로젝트" | 외부 포인터 | `06.memory/reference.md` |
| "나는 typescript strict 선호" / "항상 PR 작게" / "shadcn 우선" | 횡단 작업성향 | `plugin/memory/user/user.md` |
| "토스트 3초 통일" / "컨텍스트 스위칭 시 /ss-re" | 횡단 쾌적 패턴 | `plugin/memory/user/comfort.md` |
| "AI 에이전트 인프라 자동화 골" / "1인 SaaS 핏" | 장기 골 | `plugin/memory/user/goals.md` |
| "절대 .env cat 금지" / "main 직접 push 금지" | 횡단 금기 | `plugin/memory/user/dont.md` |

### 3순위: 불확실 시 1줄 되묻기 (최대 1회)
- 분류 confidence 낮으면: "이 메모를 (a) 이 프로젝트만 / (b) 모든 프로젝트 횡단 중 어디에 저장할까요?"
- 답에 따라 분류. 사용자 부담 ≤ 1턴.

## 비협상 가드 (4종, 보안·정합)

### G1. 글로벌 진입 금지 키워드 (M5 글로벌 오염 저항)
다음을 포함한 메모는 **글로벌(Tier 3) 진입 자동 거부** + 프로젝트(Tier 2) 또는 사용자 재확인:
- 회사명·고객명·인명 (한국어 이름·영문 회사명 패턴)
- 금액·계약 조건·NDA·일정 (`5/20`, `1억`, `NDA`, `계약`, `납기`)
- API 토큰·키·이메일 정규식 매칭 (`sk-*`, `@.*\.com`, `[A-Z0-9]{32,}`)
- 프로젝트 고유명 (이 프로젝트 외부에서 의미 없는 코드명)

### G2. TTL 표기 (M9 stale 방지)
영구가 아닌 메모는 frontmatter에 `expires: YYYY-MM-DD` 추가 권장. 월 1회 prune 권장 (자동 스크립트는 PR 외 — 사용자가 수동 점검).

### G3. 정정 로그 (M6 rollback)
메모 항목 *수정/삭제/이동* 시 같은 디렉토리의 `CHANGELOG.md`에 한 줄 추가:
`YYYY-MM-DD HH:MM | <파일>:<라인> | <변경 전> → <변경 후> | <이유>`

기존 라인 수정 절대 금지 (append-only). `06.memory/CHANGELOG.md` / `plugin/memory/user/CHANGELOG.md` 각각 운영.

### G4. CLAUDE.md 헌법 보존 (Req#1, M3)
**Claude는 다음 경우에만 CLAUDE.md를 수정할 수 있다**:
- 사용자가 *명시*: "핵심 룰로 등록", "헌법에 추가", "강제 규칙 등록"
- 사용자 명시 + Y/N 1줄 확인 후

위 조건 외 *모든* "저장/기억" 발화는 06.memory/ 또는 plugin/memory/user/로만.

## SessionStart 자동 로드

`plugin/claude/hooks/session-start.sh`가 다음을 매 세션 시작 시 `<system-reminder>`로 자동 inject:
1. `<project>/06.memory/MEMORY.md` (있으면)
2. `<project>/06.memory/*.md` 본문 (있으면)
3. `~/.claude/plugins/nathaneast-aiacht/plugin/memory/user/*.md` 본문 (글로벌 횡단)

Claude는 매 세션에 이 내용을 참조하여 사용자 컨텍스트를 회수한다. 별도 호출 X.

## 다른 PC 동기화

| 시나리오 | 동작 |
|---|---|
| Tier 2 (프로젝트) | git 자체 (해당 프로젝트 push/pull) |
| Tier 3 (글로벌) | `/push-global-memory` (PR3 신설) 명시 호출 → 본 하네스 git push → 다른 PC `update.sh`로 pull |
| Tier 1 (휘발) | 동기화 X (이 PC만, 7일 만료) |

## 30일 운영 후 측정 재검토 (소수의견 트리거)

- `<remember>` 호출 <3회 → Tier 1 폐기 검토 (architect 소수의견)
- 자동 라우팅 정확도 <8/10 → prefix 강제로 전환 (critic 소수의견)
- `comfort.md` vs `user.md` 횡단 메모 5건 비겹침 입증 안 되면 → 단일 `user-global.md` 압축 (critic 소수의견)
