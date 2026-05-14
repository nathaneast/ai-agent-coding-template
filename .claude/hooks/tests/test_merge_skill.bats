#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../.."
  cd "$TEST_TMPDIR"
  mkdir -p .claude/skills .claude-plugin .omc/learnings scripts
  cp "$REPO_ROOT_SRC/scripts/merge-skill.sh" scripts/
  chmod +x scripts/merge-skill.sh
  echo '{"skills":[]}' > .claude-plugin/plugin.json
  touch .omc/learnings/_history.jsonl

  # Create a sample external skill
  mkdir -p /tmp/ext-skill-$$
  cat > /tmp/ext-skill-$$/SKILL.md <<'EOF'
# Skill: external-test

Test skill for merge-skill bats.

## Body
Hello.
EOF
  export EXT_PATH="/tmp/ext-skill-$$"
}

teardown() { rm -rf "$TEST_TMPDIR" "$EXT_PATH"; }

@test "merge-skill from directory adds skill" {
  cd "$TEST_TMPDIR"
  run bash scripts/merge-skill.sh "$EXT_PATH"
  [ "$status" -eq 0 ]
  [ -f .claude/skills/external-test/SKILL.md ]
}

@test "merge-skill updates plugin.json skills array" {
  cd "$TEST_TMPDIR"
  bash scripts/merge-skill.sh "$EXT_PATH"
  [ "$(jq -r '.skills[0]' .claude-plugin/plugin.json)" = "external-test" ]
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
