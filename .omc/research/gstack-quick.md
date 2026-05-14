# gstack Quick Research — 2026-05-14

Source: https://github.com/garrytan/gstack

---

## Q1. 자율 빌드: `/autoplan` 동작 — 사용자 개입 없이 끝까지 가는가?

`/autoplan` 은 CEO → Design → Eng 리뷰를 순차 자동 실행한다. "Surfaces only taste decisions for your approval" — 즉 객관적 판단은 자동 처리, **주관적 취향 결정만 사람에게 노출**한다. 완전 zero-개입은 아니고, 단계별 taste gate에서 confirm 요청이 발생한다. Think → Plan → Build → Review → Test → Ship → Reflect 스프린트 구조를 따른다.

## Q2. 완료조건/자기 검증: acceptance criteria 인터페이스?

명시적 합격 임계값(예: 커버리지 95%)은 없다. 대신 `/ship` 실행 시 커버리지 오딧 + 테스트 프레임워크 자동 생성, `/qa` 버그픽스마다 회귀 테스트 생성, `/review` 완성도 갭 탐지로 **결과 기반 검증**을 수행한다. `/context-save`는 WIP 체크포인트(crash recovery)이며 자기 검증 역할은 아니다.

## Q3. 안전장치: max-iterations / 비용 캡?

- `/investigate`: 3회 픽스 실패 시 자동 중단 ("stops after 3 failed fixes")
- `/careful`: 파괴적 명령 전 경고 (rm -rf, DROP TABLE, force-push)
- `/freeze`: 디버깅 중 편집 범위를 단일 디렉터리로 제한
- `/guard`: careful + freeze 결합
- `/browse`: ML 분류기(22MB) + Haiku transcript 검증 + canary token으로 프롬프트 인젝션 방어
- **비용 캡 / `/autoplan` 전용 iteration limit: 문서에 없음.** 안전은 human-in-loop gate에 의존.

## Q4. 보고서: `/context-save` 형식?

`/context-save` = "WIP: prefix + structured `[gstack-context]` body" 포맷의 체크포인트. 보고서 역할은 `/retro`가 담당 — 팀원별 breakdown, shipping streak, test health trend를 생성한다. `/document-release`는 배포 후 프로젝트 문서 전체를 자동 업데이트한다.

---

## 본 하네스 차용 가치 패턴 2가지

### 1. Role-Gated Sequential Review Pipeline
CEO → Design → Eng 순서로 각 역할의 전문 판단을 직렬 통과시키고, 주관적 결정만 사람에게 에스컬레이션하는 패턴. OMC `autoplan` / `team` 스킬에 role-specific gate를 명시적으로 삽입하면 계획 품질이 높아진다. 현재 OMC는 역할을 병렬로 띄우는데, gstack처럼 CEO(전략) → architect(설계) → executor(구현) 직렬 gate를 `/plan` 스킬에 추가할 수 있다.

### 2. Bounded Failure Loop with Auto-Freeze
"3회 실패 시 중단 + 범위 freeze" 조합은 무한 디버깅 루프를 방지하는 실용적 안전망이다. OMC `ralph` / `team-fix` 루프에 동일 패턴(fix_loop_count >= N → freeze scope → escalate to user)을 적용하면 비용 폭주와 scope drift를 동시에 막을 수 있다.

