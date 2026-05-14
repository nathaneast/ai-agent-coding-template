#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../../.."
  cd "$TEST_TMPDIR"
  mkdir -p plugin/claude/skills plugin/claude-plugin .omc/learnings scripts
  cp "$REPO_ROOT_SRC/scripts/merge-skill.sh" scripts/
  chmod +x scripts/merge-skill.sh
  echo '{"skills":[]}' > plugin/claude-plugin/plugin.json
  touch .omc/learnings/_history.jsonl

  # Create a sample external skill (dir basename = skill name used by merge-skill)
  export EXT_PATH="$TEST_TMPDIR/external-test"
  mkdir -p "$EXT_PATH"
  cat > "$EXT_PATH/SKILL.md" <<'EOF'
# Skill: external-test

Test skill for merge-skill bats.

## Body
Hello.
EOF
}

teardown() {
  [[ -n "${TEST_TMPDIR:-}" ]] && rm -rf "$TEST_TMPDIR"
  [[ -n "${EXT_PATH:-}" ]] && rm -rf "$EXT_PATH"
}

@test "merge-skill from directory adds skill" {
  cd "$TEST_TMPDIR"
  run bash scripts/merge-skill.sh "$EXT_PATH"
  [ "$status" -eq 0 ]
  [ -f plugin/claude/skills/external-test/SKILL.md ]
}

@test "merge-skill updates plugin.json skills array" {
  cd "$TEST_TMPDIR"
  bash scripts/merge-skill.sh "$EXT_PATH"
  [ "$(jq -r '.skills[0]' plugin/claude-plugin/plugin.json)" = "external-test" ]
}

@test "merge-skill logs to _history.jsonl" {
  cd "$TEST_TMPDIR"
  bash scripts/merge-skill.sh "$EXT_PATH"
  grep -q "merge-skill" .omc/learnings/_history.jsonl
  grep -q "external-test" .omc/learnings/_history.jsonl
}

@test "merge-skill missing source returns error" {
  cd "$TEST_TMPDIR"
  run bash scripts/merge-skill.sh /nonexistent/path
  [ "$status" -eq 2 ]
}
