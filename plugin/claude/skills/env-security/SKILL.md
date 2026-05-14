# Skill: env-security

매 세션에 자동 주입. .env 파일 보안 규칙. 한 번 노출 = 운영 재배포.

## 절대 금지

- `Read(.env*)`, `Edit(.env*)`, `Write(.env*)` 도구 호출 — `.claude/settings.json`에서 deny
- `cat .env*`, `head .env*`, `tail .env*`, `less .env*`, `more .env*` 등 본문 출력
- `grep ... .env*`, `awk ... .env*`, `sed ... .env*` (화이트리스트 외)
- `< .env*` 리다이렉션
- `echo $TOKEN`, `printf "$API_KEY"`, `env | grep TOKEN` 등 환경변수 본문 출력

## 허용 (정확한 형식만)

1. `awk -F= '{print $1}' .env`
2. `grep -oE '^[^=]+' .env` (`-oE` + `^[^=]+` 둘 다 필수)

## 실행 전 체크 (하나라도 NO면 중단)

- 화이트리스트 2개 중 정확한 형식인가?
- grep에 `-o` 플래그 있는가?
- 패턴이 `^[^=]+`처럼 `=` 앞만 매칭하는가?

## 사고 시 대응

(1) 명령·키·경로 보고 → (2) 노출 범위 평가 → (3) 토큰별 운영 충격 매트릭스 → (4) 사용자 결정 대기 → (5) 재발 방지 가드 추가

## 의심 시

화이트리스트 2개에 정확히 부합하지 않으면 **실행 중단 + 사용자 확인**.
