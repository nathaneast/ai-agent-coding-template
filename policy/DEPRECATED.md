# DEPRECATED: policy/ → .claude/rules/

이 디렉터리(`policy/`)는 v0.1.0+ 부터 deprecated 되었다. 모든 규칙 파일은 `.claude/rules/`로 이동했다.

## 마이그레이션 매핑

- `policy/coding.md` → `.claude/rules/coding.md`
- `policy/design.md` → `.claude/rules/design.md`
- `policy/folder.md` → `.claude/rules/folder.md`
- `policy/project.md` → `.claude/rules/project.md`
- `policy/user-interaction.md` → `.claude/rules/user-interaction.md`

## 호환성

외부 하드코딩 경로 보호를 위해 본 폴더는 stub으로 유지. 실제 룰 내용은 `.claude/rules/`에서 읽힌다.

## 제거 시점

v0.2.0+ 결정 (사용자 외부 자동화 의존도 확인 후).
