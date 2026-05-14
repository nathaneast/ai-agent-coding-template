# Autonomous Agent Patterns — Research Synthesis

**Date**: 2026-05-14  
**Scope**: 자율 에이전트 패턴 이론 + 본 하네스(/auto) 적용 권장안

---

## 1. 9개 패턴 간략 정리

### 1.1 ReAct (Reasoning + Acting)
**핵심 알고리즘**: `Thought → Action → Observation` 루프를 반복. LLM이 각 스텝에서 추론(thought)을 생성하고, 외부 도구를 호출(action)하며, 그 결과를 관찰(observation)해 다음 스텝에 반영한다.

```
while not done:
  thought = llm.think(goal, history)
  action  = llm.select_action(thought)
  obs     = env.execute(action)
  history.append(thought, action, obs)
  done    = llm.check_terminal(obs)
```

**완료 조건**: LLM이 "Final Answer" 토큰 또는 종료 의도를 생성할 때.  
**무한루프 방지**: `max_iterations` 캡 (보통 10–30), 동일 action-observation 쌍 반복 감지.  
**채택 사례**: LangChain Agent, LlamaIndex ReAct, Claude tool_use 루프.  
**출처**: [arXiv:2210.03629](https://arxiv.org/abs/2210.03629)

---

### 1.2 Reflexion
**핵심 알고리즘**: 실패한 trajectory를 LLM이 자기비평(verbal critique)하고, 그 교훈을 episodic memory에 저장 후 다음 시도에 in-context로 주입한다.

```
for attempt in range(max_attempts):
  result = run_episode(task, memory)
  if success(result): break
  reflection = llm.critique(task, result)
  memory.append(reflection)          # 최대 3개 유지
```

**완료 조건**: 성공 신호(binary reward) 또는 max_attempts 도달.  
**무한루프 방지**: 동일 action을 3회 이상 반복하거나 step 수 30 초과 시 강제 reflection 트리거.  
**채택 사례**: LangGraph Reflexion 노드, SWE-bench 에이전트.  
**출처**: [arXiv:2303.11366](https://arxiv.org/abs/2303.11366)

---

### 1.3 CRITIC (Self-Correction with Tools)
**핵심 알고리즘**: 초기 출력물을 생성한 뒤, 외부 도구(코드 실행기, 검색 API)로 검증하고, 도구 피드백을 기반으로 수정을 반복한다.

```
output = llm.generate(task)
while not verified:
  critique = tool.verify(output)       # 외부 도구로 검증
  if critique.ok: break
  output = llm.revise(output, critique)
```

**완료 조건**: 도구 검증 통과(테스트 pass, 검색 결과 일치).  
**무한루프 방지**: 최대 수정 횟수 캡; 도구 오류 시 fallback.  
**채택 사례**: ICLR 2024 채택, 수학 QA 및 코드 생성 벤치마크.  
**출처**: [arXiv:2305.11738](https://arxiv.org/abs/2305.11738)

---

### 1.4 Plan-and-Execute
**핵심 알고리즘**: 전략적 계획(planner LLM)과 전술적 실행(executor agent)을 분리. Joiner/Re-planner가 실행 결과를 평가해 계속/재계획/종료를 결정한다.

```
plan = planner.create(goal)            # 단계 목록 생성
for step in plan:
  result = executor.run(step)
  plan, done = replanner.assess(goal, plan, result)
  if done: break
```

**완료 조건**: Re-planner LLM이 "목표 달성" 판단 시.  
**무한루프 방지**: 재계획 횟수 상한(max_replan), DAG 기반 단계 추적으로 순환 차단.  
**채택 사례**: LangChain Plan-and-Execute, BabyAGI, GPT-Engineer.  
**출처**: [LangChain Planning Agents](https://blog.langchain.com/planning-agents/)

---

### 1.5 Tree of Thoughts (ToT)
**핵심 알고리즘**: 각 추론 단계에서 여러 "thought" 후보를 생성하고, LLM 자체 평가로 유망한 가지를 선택하며 BFS/DFS/MCTS로 탐색한다.

```
root = State(goal)
frontier = [root]
while frontier:
  node = select(frontier)             # BFS/DFS/MCTS
  thoughts = llm.generate_k(node, k=5)
  scores = llm.evaluate(thoughts)
  frontier.extend(prune(thoughts, scores))
  if terminal(node): return solution
```

**완료 조건**: 터미널 상태 도달 또는 탐색 예산 소진.  
**무한루프 방지**: 탐색 깊이/너비 제한, beam 크기 고정.  
**채택 사례**: 복잡한 수학 퍼즐, 코드 생성 탐색; 비용 과다로 실서비스 제한적.  
**출처**: [promptingguide.ai/techniques/tot](https://www.promptingguide.ai/techniques/tot)

---

### 1.6 Self-RAG
**핵심 알고리즘**: LLM이 생성 중 reflection token(Retrieve/IsRel/IsSup/IsUse)을 삽입해 검색 필요성을 자체 판단하고, 검색 결과를 in-line으로 비판·통합한다.

```
for token_pos in generation:
  if llm.needs_retrieval(context):    # [Retrieve] 토큰
    docs = retriever.fetch(query)
    for doc in docs:
      score = llm.critique(doc)       # [IsRel][IsSup] 토큰
    output = llm.integrate(best_doc)
```

**완료 조건**: [IsUse] 토큰이 "유용함" 판단 시 생성 종료.  
**무한루프 방지**: 검색 횟수 상한, 관련성 임계값 미달 시 검색 스킵.  
**채택 사례**: ICLR 2024 Oral (top 1%), 오픈 도메인 QA, 팩트 검증.  
**출처**: [arXiv:2310.11511](https://arxiv.org/abs/2310.11511)

---

### 1.7 AlphaCodium / CodeAct
**핵심 알고리즘 (AlphaCodium)**: 문제 자기성찰 → AI 테스트 생성 → 공개 테스트 반복 실행 → 실패 시 코드 수정 루프. Flow Engineering 방식으로 훈련 없이 GPT-4 pass@1을 19%→44%로 향상.

**핵심 알고리즘 (CodeAct)**: JSON 액션 대신 실행 가능한 Python 코드를 action space로 사용. 코드 실행 결과를 observation으로 받아 멀티턴으로 자기수정.

**완료 조건 (AlphaCodium)**: 모든 공개+AI 생성 테스트 통과.  
**무한루프 방지**: 최대 반복 횟수 캡; 동일 실패 반복 시 다른 접근법 시도.  
**채택 사례**: Qodo (구 CodiumAI), SWE-bench, HumanEval.  
**출처**: [Qodo AlphaCodium](https://www.qodo.ai/blog/qodoflow-state-of-the-art-code-generation-for-code-contests/) | [CodeAct ICML 2024](https://machinelearning.apple.com/research/codeact)

---

### 1.8 LLM-as-Judge
**핵심 알고리즘**: 별도 Judge LLM이 에이전트 출력(또는 전체 trajectory)을 평가 기준(rubric)에 따라 채점. Auto-Eval Judge는 체크리스트 질문을 자동 생성해 완료 조건을 동적으로 정의한다.

```
criteria = judge.generate_checklist(task)  # 자동 체크리스트
score = judge.evaluate(trajectory, criteria)
done = all(criteria_met(score))
```

**완료 조건**: 모든 체크리스트 항목 충족 시.  
**무한루프 방지**: Judge가 "충분히 좋음" 임계값 설정; 점수 개선이 없으면 종료.  
**채택 사례**: MT-Bench, GAIA 벤치마크, Magentic-One 평가.  
**출처**: [Auto-Eval Judge arXiv:2508.05508](https://arxiv.org/html/2508.05508v1) | [Arize LLM-as-Judge](https://arize.com/llm-as-a-judge/)

---

### 1.9 Constitutional AI (CAI) Feedback Loop
**핵심 알고리즘**: 헌법(원칙 목록) 기준으로 자기비평 → 수정 → RLAIF(AI 피드백 강화학습) 2단계 루프. 외부 human label 없이 자기일관성을 학습한다.

```
# Phase 1: SL with self-critique
for prompt in dataset:
  response = model.generate(prompt)
  critique = model.critique(response, constitution)
  revision = model.revise(response, critique)
  supervised_data.append(revision)

# Phase 2: RLAIF
pref_labels = model.compare(response_A, response_B, constitution)
reward_model.train(pref_labels)
model.rl_finetune(reward_model)
```

**완료 조건**: 원칙 준수 점수가 임계값 초과 시.  
**무한루프 방지**: 고정 revision 횟수; RLAIF 학습 수렴 기준(KL divergence).  
**채택 사례**: Claude 모델 학습 파이프라인 핵심 기법.  
**출처**: [Anthropic CAI](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback)

---

## 2. 본 하네스(/auto) 권장 패턴 조합 3가지

### 조합 A: ReAct + LLM-as-Judge + Reflexion (권장 기본값)

**적합 시나리오**: 코드 구현 + 테스트 + 커밋 자동화 (본 하네스의 주요 워크플로우)

```
PROCEDURE auto_run(user_prompt):
  # Step 1: 완료조건 추출 (LLM-as-Judge 체크리스트)
  completion_criteria = judge.generate_checklist(user_prompt)
  
  # Step 2: 계획 (Plan-and-Execute 영향)
  phases = planner.decompose(user_prompt)
  
  # Step 3: ReAct 실행 루프
  memory = []
  for phase in phases:
    for attempt in range(MAX_ATTEMPTS=3):   # Reflexion 횟수 캡
      thought = llm.think(phase, memory)
      action  = executor.run(thought)       # 코드 변경, 테스트, 커밋
      obs     = env.observe(action)         # 테스트 결과, Codex 리뷰
      
      # Step 4: 자기검증
      score = judge.evaluate(obs, completion_criteria)
      if score.all_pass: break
      
      # Step 5: Reflexion - 실패 시 자기비평 후 재시도
      reflection = llm.reflect(phase, obs, score.failures)
      memory.append(reflection)
  
  # Step 6: 완료조건 100% → 종료 + 보고서
  return judge.final_report(completion_criteria, history)
```

**장점**: ReAct의 도구 활용 + LLM-as-Judge의 객관적 완료 판단 + Reflexion의 실패 학습 조합. 세 패턴 모두 fine-tuning 불필요.

---

### 조합 B: Plan-and-Execute + CRITIC + LLM-as-Judge (복잡한 멀티파일 작업)

**적합 시나리오**: 대규모 리팩토링, 멀티 컴포넌트 신규 기능 개발

```
PROCEDURE complex_auto(user_prompt):
  plan = planner.create_dag(user_prompt)   # DAG 기반 병렬 계획
  
  for step in topological_sort(plan):
    output = executor.run(step)
    
    # CRITIC: 외부 도구(테스트러너, 타입체커)로 검증
    while not critic.tool_verified(output):
      feedback = critic.run_tools(output)  # lint, typecheck, test
      output = executor.fix(output, feedback)
      if fix_count > MAX_FIX=5: escalate()
    
    plan, done = replanner.assess(user_prompt, plan, output)
    if done: break
  
  return judge.final_report(completion_criteria, history)
```

**장점**: 단계 계획이 명확해 병렬 실행(3.6x 속도) 가능. CRITIC이 테스트 결과 기반 객관적 검증 담당.

---

### 조합 C: AlphaCodium Flow + ReAct + LLM-as-Judge (코드 품질 최우선)

**적합 시나리오**: 핵심 비즈니스 로직, 복잡한 알고리즘 구현

```
PROCEDURE code_quality_auto(task):
  # AlphaCodium: 테스트 먼저 생성 (TDD와 일치)
  tests = llm.generate_tests(task)          # AI 테스트 자동 생성
  
  # CodeAct: Python 코드를 액션으로 실행
  code = executor.generate(task)
  while not all_tests_pass(code, tests):
    exec_result = python_interpreter.run(code)
    code = executor.fix(code, exec_result)  # 실행 결과로 자기수정
    if iteration > MAX_ITER=10: break
  
  # LLM-as-Judge: Codex 리뷰 대체 또는 보조
  verdict = judge.code_review(code, task)
  if not verdict.approved:
    code = executor.revise(code, verdict.feedback)
  
  return code
```

**장점**: 테스트 주도(TDD 규칙 준수) + 실행 결과 기반 수정(hallucination 최소화) + 최종 Judge 검증.

---

## 3. 안전장치 매트릭스

| 위험 | 패턴 기반 대응 | 구체적 구현 |
|------|--------------|------------|
| **비용 폭주** | ToT 제외, ReAct 우선 사용 | `max_iterations=20`, `max_llm_calls=100` 하드 캡; 비용 미터 모니터링 |
| **무한 루프** | Reflexion 동일액션 감지 + Plan-and-Execute max_replan | 동일 (action, obs) 쌍 3회 반복 시 강제 중단; step 카운터 30 초과 시 fallback |
| **잘못된 방향** | LLM-as-Judge 체크리스트 + Reflexion 목표 재확인 | 매 phase 시작 전 `judge.check_alignment(current_state, original_goal)` 실행 |
| **외부 의존성 장애** | CRITIC fallback 전략 | Codex API 실패 시 → 내부 LLM 자기리뷰로 대체; GitHub 장애 시 로컬 커밋만 수행; 3회 재시도 후 human escalation |

**추가 안전장치**:
- **타임아웃**: 전체 실행 10시간 하드 리밋; 단일 phase 30분 제한
- **비용 게이트**: $10/session 초과 시 일시 정지 + 사용자 확인 요청
- **Human escalation**: 연속 3회 실패 phase는 자동 중단 후 보고서 생성
- **Checkpoint 저장**: 매 성공 phase 후 상태 저장 (재시작 시 resume 가능)
- **AgentSpec/정책 가드**: 파괴적 액션(파일 삭제, main 직접 push)은 실행 전 확인 필수

---

## 4. 패턴 선택 가이드

```
작업 단순도:   단순(1-2파일)    → ReAct + LLM-as-Judge (조합 A)
작업 복잡도:   복잡(멀티파일)   → Plan-and-Execute + CRITIC (조합 B)
코드 품질 우선: TDD 필수        → AlphaCodium + ReAct (조합 C)
비용 제약:     토큰 최소화      → Plan-and-Execute (계획 1회, 실행 분리)
탐색 필요:     불확실한 접근법  → ToT (비용 감수하고 분기 탐색)
```

---

## 참고 문헌

- ReAct: [arXiv:2210.03629](https://arxiv.org/abs/2210.03629) | [Google Research Blog](https://research.google/blog/react-synergizing-reasoning-and-acting-in-language-models/)
- Reflexion: [arXiv:2303.11366](https://arxiv.org/abs/2303.11366) | [Lilian Weng Agent Survey](https://lilianweng.github.io/posts/2023-06-23-agent/)
- CRITIC: [arXiv:2305.11738](https://arxiv.org/abs/2305.11738)
- Plan-and-Execute: [LangChain Blog](https://blog.langchain.com/planning-agents/)
- Tree of Thoughts: [promptingguide.ai](https://www.promptingguide.ai/techniques/tot)
- Self-RAG: [arXiv:2310.11511](https://arxiv.org/abs/2310.11511) | [selfrag.github.io](https://selfrag.github.io/)
- AlphaCodium: [Qodo Blog](https://www.qodo.ai/blog/qodoflow-state-of-the-art-code-generation-for-code-contests/)
- CodeAct: [Apple ML Research](https://machinelearning.apple.com/research/codeact) | [ICML 2024](https://dl.acm.org/doi/10.5555/3692070.3694124)
- LLM-as-Judge: [Auto-Eval Judge arXiv:2508.05508](https://arxiv.org/html/2508.05508v1) | [Arize Guide](https://arize.com/llm-as-a-judge/)
- Constitutional AI: [Anthropic Research](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback)
- Guardrails 2025: [AgentSpec arXiv:2503.18666](https://arxiv.org/pdf/2503.18666) | [LlamaFirewall Meta](https://ai.meta.com/research/publications/llamafirewall-an-open-source-guardrail-system-for-building-secure-ai-agents/)
