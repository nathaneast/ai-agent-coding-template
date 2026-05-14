# External AI Coding Agents: 무인 자율 빌드 패턴 리서치

**목적**: "1프롬프트 → 10시간 자동 빌드 → 완료조건 충족까지 무인 실행 + 보고서" 구현을 위한 외부 도구 패턴 분석

**날짜**: 2026-05-14

---

## 도구별 5가지 질문 답변

### 1. Devin (Cognition AI)

**완료조건 정의**: 사용자가 프롬프트에 명시적으로 정의해야 한다. "done looks like in 1-2 sentences" 형식 권장. CI 통과 / 테스트 그린 같은 검증 가능한 기준 필수. 자동 추출 없음 — 명시 의무.

**자기 검증**: 주로 CI/CD 실행 결과(테스트, 린트)로 검증. LLM-as-judge 방식은 없고, 도구 실행 출력을 관찰하여 판단. 복잡한 케이스는 human review 요구.

**종료 조건**: 명시적 종료 메커니즘 없음. 사용자가 세션을 수동 중단하거나, 에이전트가 스스로 "완료"라고 판단할 때 멈춤. "Going in circles" 감지 시 사용자가 직접 중단 권장.

**안전장치**: 스코프 명시로 scope creep 방지. CI/CD 통합으로 코드 품질 가드. 명시적 비용 제한 없음.

**보고서**: 비구조적. 세션 내 채팅 메시지 형식으로 진행 상황 공유. 표준화된 완료 보고서 형식 없음.

**Source**: https://docs.devin.ai/ / https://cognition.ai/blog/devin-annual-performance-review-2025

---

### 2. Cursor Agent Mode (Composer)

**완료조건 정의**: "Done when" 조건으로 태스크 정의. 훅 시스템(`StopHookInput`)에서 `loop_count`, `status` 필드 확인. 스크래치패드 파일에 "DONE" 마커 기록 방식으로 완료 감지.

**자기 검증**: `typecheck`, `lint`, `test` 실행 후 출력 분석. 에러 발생 시 자동 수정 후 재실행. TDD 패턴 지원 (failing tests → implement → green).

**종료 조건**: `MAX_ITERATIONS` 캡 (훅 코드에서 직접 설정). DONE 마커 감지. 사용자 수동 Stop 버튼. `StopHookInput.status: "completed" | "aborted" | "error"` 상태 전환.

**안전장치**: 파괴적 명령(rm -rf, DROP TABLE) approval gate. `--require-approval-for-destructive-commands` 설정. 백그라운드 에이전트는 클라우드 VM 샌드박스에서 실행.

**보고서**: 없음. diff view로 변경사항 실시간 확인 가능. 구조화된 완료 보고서 기능 없음.

**Source**: https://cursor.com/blog/agent-best-practices

---

### 3. Aider (architect/coder dual mode)

**완료조건 정의**: 사용자가 채팅 명령으로 태스크 정의. 별도 acceptance criteria 시스템 없음. TDD 패턴 사용 시 "테스트 그린 = 완료" 방식.

**자기 검증**: architect 모델이 계획, editor 모델이 구현 — 2단계 분리로 품질 향상. 테스트 실패 시 출력 캡처 → 원인 분석 → 수정 → 재실행 루프. `--auto-accept-architect` 플래그로 자동 적용.

**종료 조건**: 내장 루프 종료 조건 없음. 테스트 통과 = 완료로 간주. 사용자가 수동으로 중단하거나 태스크 완료 후 대기 상태로 전환.

**안전장치**: git 커밋 자동 생성으로 롤백 가능. 파일 편집 전 사용자 확인 옵션. `--no-auto-commits` 플래그.

**보고서**: 없음. 변경 파일 목록과 diff를 터미널에 출력하는 방식.

**Source**: https://aider.chat/docs/usage/modes.html

---

### 4. SWE-agent (Princeton)

**완료조건 정의**: GitHub 이슈를 입력으로 받아 이슈 해결 = 완료. 별도 acceptance criteria 입력 없음. 이슈 텍스트에서 자동 추출.

**자기 검증**: ACI(Agent-Computer Interface)를 통해 테스트 실행 및 출력 확인. 파일 편집 후 즉각적인 피드백 수신. 명시적 LLM-as-judge 없음 — 실행 결과로만 판단.

**종료 조건**: 이슈 해결 판단 시 `submit` 액션 실행. 최대 스텝 수(기본 50) 초과 시 강제 종료. 에이전트가 스스로 완료 선언.

**안전장치**: 소수의 단순 액션만 허용하는 제한된 action space. guardrail로 일반적인 실수 방지. 피드백이 간결하고 정보적으로 설계됨.

**보고서**: 패치 파일(diff) 자동 생성. SWE-bench 형식의 구조화된 출력. 성공/실패 여부와 적용된 변경사항 기록.

**Source**: https://arxiv.org/abs/2405.15793 / https://github.com/SWE-agent/SWE-agent

---

### 5. AutoGPT / BabyAGI

**완료조건 정의**: 자연어 목표로 정의. 완료 판단을 LLM에 의존 — "good enough" 개념 없어서 항상 추가 작업을 발견하는 Perfectionism Bias 문제. BabyAGI는 task queue 소진 = 완료.

**자기 검증**: LLM-as-judge 방식 — 결과를 LLM이 평가하여 완료 여부 판단. 실행 결과 검증 없음. 주관적이고 일관성 없는 평가.

**종료 조건**: `max_iterations` 파라미터 (필수 설정 — 미설정 시 무한 루프 + API 과금). BabyAGI: task queue 소진. 태스크 유사도 90% 이상이면 스킵하는 deduplication 로직.

**안전장치**: `max_iterations` 캡만 있음. 실질적인 비용 제한 없어 $80 하룻밤 과금 사례 존재. 2025년 개선에서 human-in-the-loop 체크포인트 추가.

**보고서**: 없음. 콘솔 로그 출력만 존재. 구조화된 완료 보고서 기능 없음.

**Source**: https://github.com/vectara/awesome-agent-failures/blob/main/docs/case-studies/autogpt-planning-failures.md

---

### 6. Claude Agent SDK (Anthropic)

**완료조건 정의**: 시스템 프롬프트와 스킬 정의에 포함. Managed Agents는 세션 단위로 에이전트 실행. 완료 체크리스트 자동 생성 기능 포함 (통합 테스트, 비용 재산정 등).

**자기 검증**: Stop hook으로 완료 차단 가능 (exit code 2 = 계속 실행 강제). LLM-as-judge + 실행 결과 조합. 체크리스트 기반 검증.

**종료 조건**: Stop hook exit code 0 = 종료 허용. `stop_hook_active` 필드로 무한 루프 방지. SSE 스트림의 세션 상태로 완료 감지.

**안전장치**: 기본값: 임시 디렉토리, 도구 없음, 파일 시스템 접근 불가. 버전 관리된 에이전트 설정으로 롤백 가능. 컨테이너 격리(Managed Agents).

**보고서**: 완료 시 수동 검증 필요 항목 체크리스트 자동 생성. 구조화된 이벤트 스트림으로 진행 상황 추적 가능.

**Source**: https://platform.claude.com/docs/en/managed-agents/overview / https://code.claude.com/docs/en/agent-sdk/overview

---

### 7. OpenAI Codex CLI

**완료조건 정의**: `/goal` 명령 + 자연어 설명. `plans.md` 파일에 마일스톤별 acceptance criteria 명시. "Done when" 체크리스트 형식. Stop-and-fix 규칙: 검증 실패 시 수정 후 진행.

**자기 검증**: 각 마일스톤에서 lint, typecheck, test, build, export 순차 실행. plan → implement → validate → repair 루프 강제. 마일스톤 기반 체크포인트 시스템.

**종료 조건**: 모든 마일스톤 완료 = 종료. 마일스톤별 acceptance criteria 충족 확인 후 진행. `plans.md` 가 source of truth — scope creep 방지.

**안전장치**: 샌드박스 모드 3단계 (`suggest` / `auto-edit` / `danger-full-access`). 파괴적 명령 granular approval policy. git worktree로 실행 격리. `auto_review` 에이전트가 승인 요청 사전 검토.

**보고서**: 구조화된 완료 보고서 자동 생성 — 마일스톤 완료율, 의사결정 근거, 실행 방법, 알려진 이슈, 토큰 사용량 및 세션 시간 포함.

**Source**: https://developers.openai.com/blog/run-long-horizon-tasks-with-codex / https://developers.openai.com/codex/agent-approvals-security

---

### 8. OpenHands (OpenDevin)

**완료조건 정의**: 이벤트 스트림 기반 perception-action 루프. 태스크는 자연어로 정의. 내장 벤치마크(SWE-bench 등) 기준으로 완료 평가.

**자기 검증**: step function으로 shell 명령, Python 실행, 브라우저 인터랙션 후 결과 관찰. 멀티 에이전트 협업으로 상호 검증 가능.

**종료 조건**: 태스크 완료 판단 시 종료. human-in-the-loop 인터벤션 지원. 명시적 max_iterations 없음.

**안전장치**: Docker 기반 샌드박스 격리. LLM 기반 action-level 보안 분석. Invariant Labs와 파트너십으로 runtime safety 강화. guardrail 실험에서 100% 유해 행동 차단 달성.

**보고서**: 없음. 에이전트 로그와 실행 결과만 제공.

**Source**: https://arxiv.org/abs/2407.16741 / https://github.com/OpenHands/OpenHands

---

## 비교 표

| 도구 | 완료조건 정의 | 자기 검증 | 종료 조건 | 안전장치 | 보고서 |
|------|-------------|---------|---------|---------|-------|
| Devin | 사용자 명시 필수 (자동추출 없음) | CI/CD 실행 결과 | 수동 중단 or 에이전트 자기 선언 | scope 명시, CI 통합 | 없음 (채팅 업데이트만) |
| Cursor Agent | "Done when" 조건 + DONE 마커 | typecheck/lint/test 실행 | MAX_ITERATIONS + Stop 버튼 | destructive command approval | 없음 (diff view만) |
| Aider | 사용자 채팅 정의 (TDD 시 테스트 그린) | 2모델 분리 + 테스트 재실행 루프 | 수동 중단 or 테스트 통과 | git 자동 커밋으로 롤백 가능 | 없음 (터미널 출력만) |
| SWE-agent | GitHub 이슈 자동 추출 | ACI를 통한 테스트 실행 | submit 액션 or max steps(50) | 제한된 action space + guardrail | diff 패치 파일 자동 생성 |
| AutoGPT/BabyAGI | 자연어 목표 (Perfectionism Bias 문제) | LLM-as-judge (부정확) | max_iterations 캡 필수 | max_iterations만 (비용 위험) | 없음 (콘솔 로그만) |
| Claude Agent SDK | 시스템 프롬프트 + Stop hook | Stop hook (exit 2 강제 계속) | exit code 0 + stop_hook_active | 기본 도구 없음, 컨테이너 격리 | 완료 체크리스트 자동 생성 |
| Codex CLI | plans.md 마일스톤 체크리스트 | lint+typecheck+test+build 순차 | 전체 마일스톤 완료 | 3단계 샌드박스 + auto_review | 구조화된 보고서 (토큰/시간 포함) |
| OpenHands | 자연어 + 벤치마크 기준 | step function + 멀티에이전트 | 태스크 완료 판단 | Docker 격리 + LLM 보안 분석 | 없음 (에이전트 로그만) |

---

## 사용자 목적에 가장 가까운 도구 (추천 2~3개)

### 1순위: OpenAI Codex CLI
"plans.md 마일스톤 체크리스트 + validate-before-proceed + 구조화된 완료 보고서" 패턴이 사용자 목적과 가장 일치한다. 25시간 무인 실행 실증 사례가 있고, 토큰 사용량/세션 시간까지 포함한 보고서를 자동 생성한다. 3단계 샌드박스와 scope creep 방지 메커니즘도 완비되어 있다.

### 2순위: Claude Agent SDK (Stop Hook 패턴)
Stop hook의 exit code 2 메커니즘이 "완료조건 충족까지 강제 실행"을 구현하는 가장 명확한 API다. `stop_hook_active` 필드로 무한 루프를 방지하면서 검증 로직을 자유롭게 구성할 수 있다. 본 하네스(OMC)와 동일한 Claude Code 기반이라 통합 비용이 낮다.

### 3순위: Cursor Agent (Hook + MAX_ITERATIONS)
StopHookInput 인터페이스의 `loop_count + DONE 마커 + MAX_ITERATIONS` 조합이 무인 루프 설계의 실용적인 참고 구현체다. 훅 스크립트로 커스텀 완료 조건 주입이 가능하다.

---

## 본 하네스에 차용할 핵심 패턴 3가지

### 패턴 1: Milestone-Gated Progression (Codex CLI 기반)
각 태스크/페이즈에 명시적 acceptance criteria 체크리스트를 정의하고, 모든 항목 통과 전까지 다음 단계로 진행하지 않는다. lint → typecheck → test → build를 순차 실행하고 실패 시 repair 루프를 강제한다. 현재 ralph/ultrawork는 iteration 제한만 있고 milestone-level 검증 게이트가 없다.

**구현 포인트**: `plans.md` 형식의 마일스톤 파일을 ralph 실행 시 생성하고, verifier 에이전트가 각 마일스톤 완료를 체크포인트로 평가한다.

### 패턴 2: Stop Hook Exit Code Convention (Claude Agent SDK 기반)
"완료" 선언을 에이전트 자기 판단에 맡기지 않고 외부 검증 hook이 차단한다. exit code 2 = 계속 실행 / exit code 0 = 종료 허용. `stop_hook_active` 필드로 hook이 이미 활성화된 상태인지 확인하여 무한 루프 방지. 현재 OMC Stop hook에 이 패턴을 적용하면 ralph가 실제로 완료된 경우에만 멈추도록 강제할 수 있다.

**구현 포인트**: `.claude/hooks/` 에 acceptance criteria 체크 로직을 추가하고, 기준 미충족 시 exit 2로 에이전트 재실행 유도.

### 패턴 3: Structured Completion Report (Codex CLI 기반)
무인 실행 종료 후 자동으로 구조화된 보고서를 생성한다. 포함 항목: 마일스톤 완료율, 의사결정 근거, 실행 방법 안내, 알려진 이슈 및 후속 태스크, 토큰 사용량 및 세션 시간. 현재 ralph/ultrawork는 실행 로그만 존재하고 인계 보고서가 없다.

**구현 포인트**: ralph/ultrawork 종료 시 `.omc/reports/{timestamp}.md` 파일을 자동 생성하는 단계를 파이프라인 마지막에 추가. verifier 에이전트가 보고서 초안 작성.

---

## 참고 소스

- Devin Docs: https://docs.devin.ai/
- Cognition 2025 Review: https://cognition.ai/blog/devin-annual-performance-review-2025
- Cursor Agent Best Practices: https://cursor.com/blog/agent-best-practices
- Aider Chat Modes: https://aider.chat/docs/usage/modes.html
- SWE-agent Paper (NeurIPS 2024): https://arxiv.org/abs/2405.15793
- AutoGPT Failure Case Studies: https://github.com/vectara/awesome-agent-failures
- OpenHands Paper: https://arxiv.org/abs/2407.16741
- Claude Agent SDK: https://code.claude.com/docs/en/agent-sdk/overview
- Claude Managed Agents: https://platform.claude.com/docs/en/managed-agents/overview
- Codex Long-Horizon Tasks: https://developers.openai.com/blog/run-long-horizon-tasks-with-codex
- Codex Agent Approvals: https://developers.openai.com/codex/agent-approvals-security
