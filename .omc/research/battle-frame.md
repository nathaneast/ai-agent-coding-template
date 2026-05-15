# Frame: tech-arch 에이전트 설계안 평가

## 검증 대상 (추천안)

- **위치**: `~/.claude/agents/tech-arch.md` (Opus, READ-ONLY) + `~/.claude/skills/tech-arch.md` (`/tech-arch` 커맨드)
- **정체성**: 사용자의 메인 오케스트레이터. 제품 니즈/목적 파악 → 기술 의사결정·설계 → 프론트 개발자 눈높이 설명 → 후속 질문 응대
- **협업 라우팅**:
  - 내부 병렬: OMC `architect` + `analyst` + `planner` + `critic`
  - 외부: Codex `mcp__x__ask_codex` (architecture/critic 강점), Gemini `mcp__g__ask_gemini` (designer/문서/1M context 강점)
  - Superpowers 플러그인 스킬 필요 시
- **출력 5단 규약**:
  1. 한 줄 결론
  2. 트레이드오프 표
  3. 프론트 비유로 백엔드/인프라 설명
  4. 단계별 다음 액션
  5. 후속 질문 3개

## 사용자 컨텍스트

- 프론트엔드 개발자 (백엔드/인프라 약함)
- 메인 환경: ai-agent-coding-template 프로젝트 (셋업/하네스 템플릿)
- 글로벌 OMC 에이전트 30개 설치됨 (architect, planner, critic, analyst, executor, debugger, verifier, deep-executor, code-reviewer, security-reviewer, quality-reviewer, designer, document-specialist, build-fixer, test-engineer, qa-tester, scientist, writer, explore 등)
- Codex MCP + Gemini MCP 활성
- Superpowers 플러그인 설치됨 (`/brainstorm`, `/plan` 등)
- gstack 스킬 미설치 → 보고서에서 스킵

## 결정 기준 (6개)

| # | 기준 | 임계값 |
|---|---|---|
| C1 | 프론트 개발자 친화성 | 출력 5단 규약이 백엔드 용어 추측 없이 의사결정 가능한가 |
| C2 | 기존 자산과 중복 최소화 | OMC architect/planner/critic/analyst·Superpowers와 역할 겹치면 감점. 단순 래퍼인가 신규 가치인가 |
| C3 | READ-ONLY 권한 모델 적정성 | 메인 오케스트레이터가 편집 불가일 때 매번 수동 executor 호출 마찰 vs 안전성 |
| C4 | 오케스트레이션 깊이 vs 단순성 | 내부 4 + 외부 2 + Superpowers 동시 호출이 응답 지연·토큰 비용을 정당화하는가 |
| C5 | 에이전트 ↔ 스킬 이중 표면 | `.md` 에이전트 정의 + `/tech-arch` 스킬 동시 운영이 OMC 패턴과 일관적인가, 진입점 명확한가 |
| C6 | 의사결정 마감 기한 | 본 세션 내 단일 라운드 합의, 실패 시 사용자가 직접 결정 |

## 도메인

**mixed (architecture-heavy)** — 표면적으로 에이전트 시스템 설계지만 본질은 (a) 프론트 개발자 페르소나 product UX + (b) 30+ 에이전트 생태계 경계 설계 동시 결정.
