# Phase 5 Dogfood — MVP-B 게이트

## 결과: 5/5 PASS

### P5-1: session-end → index.json append
```bash
PRE=$(jq 'length' .omc/sessions/index.json 2>/dev/null || echo 0)
echo '{"session_id":"dogfood-P5-1","summary":"dogfood P5 scenario 1"}' | bash .claude/hooks/session-end.sh
POST=$(jq 'length' .omc/sessions/index.json)
[[ "$((POST - PRE))" -eq 1 ]] && echo "P5-1 PASS"
```
**결과**: PASS (index: 0 -> 1)

### P5-2: archive 본문 생성
```bash
ls .omc/sessions/archive/*-dogfood-P5-1.md && echo "P5-2 PASS"
```
**결과**: PASS (archive files: 1)

### P5-3: resume-session 1 가장 최근 회수
```bash
bash scripts/resume-session.sh 1 | grep -q "dogfood-P5-1" && echo "P5-3 PASS"
```
**결과**: PASS

### P5-4: resume-session N>length 안전 처리
```bash
bash scripts/resume-session.sh 999; [[ $? -eq 2 ]] && echo "P5-4 PASS"
```
**결과**: PASS (exit code 2, "Only 1 sessions available (requested N=999)")

### P5-5: 인덱스 50개 cap (55개 생성 → 50개로 capped)
```bash
for i in $(seq 1 55); do
  echo "{\"session_id\":\"P5-5-$i\",\"summary\":\"s$i\"}" | bash .claude/hooks/session-end.sh
done
POST=$(jq 'length' .omc/sessions/index.json)
[[ "$POST" -le 50 ]] && echo "P5-5 PASS ($POST entries)"
```
**결과**: PASS (50 entries)

## MVP-B 게이트 PASS

- problem.md "세션 종료 후 2~3개 전 세션 복원 어려움" 해결 완료
- 시나리오 B (archive 본문 inject) 기본 구현 완료
- 시나리오 A (--resume) 안내 포함, 사용자 직접 검증 후 활성화 가능
- bats 누적 38/38 통과
