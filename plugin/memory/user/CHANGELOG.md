# User Global Memory Changelog (append-only)

글로벌(cross-project) 사용자 메모 항목 수정/삭제/이동 시 본 파일에 한 줄 추가. 절대 기존 라인 수정 금지 (rollback 보장).

형식:
`YYYY-MM-DD HH:MM | file:line | <변경 전> → <변경 후> | reason`

스코프: 글로벌 (모든 프로젝트에 영향).

---

<!-- 이 라인 아래로만 추가. 예: 2026-MM-DD HH:MM | dont.md:5 | (추가) main 직접 push 금지 | 사고 재발 방지 -->
