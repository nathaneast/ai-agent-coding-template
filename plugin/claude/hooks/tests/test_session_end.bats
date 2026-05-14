#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../../.."
  cd "$TEST_TMPDIR"
  mkdir -p plugin/claude/hooks .omc/learnings .omc/sessions
  cp "$REPO_ROOT_SRC/plugin/claude/hooks/session-end.sh" plugin/claude/hooks/
  chmod +x plugin/claude/hooks/session-end.sh
  echo '{"counters":{"learnings_recalled":0},"last_updated":"x"}' > .omc/learnings/_metrics.json
  echo '[]' > .omc/sessions/index.json
  git init -q
  git config user.email test@test.com
  git config user.name "test"
  echo x > a.txt && git add a.txt && git commit -q -m "init"
}

teardown() { rm -rf "$TEST_TMPDIR"; }

@test "session-end appends to index.json" {
  cd "$TEST_TMPDIR"
  echo '{"session_id":"test-123","summary":"test session"}' | bash plugin/claude/hooks/session-end.sh
  COUNT=$(jq 'length' .omc/sessions/index.json)
  [ "$COUNT" = "1" ]
}

@test "session-end creates archive dump" {
  cd "$TEST_TMPDIR"
  echo '{"session_id":"test-456","summary":"test"}' | bash plugin/claude/hooks/session-end.sh
  COUNT=$(ls .omc/sessions/archive/*-test-456.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$COUNT" = "1" ]
}

@test "session-end caps index at 50" {
  cd "$TEST_TMPDIR"
  for i in $(seq 1 55); do
    echo "{\"session_id\":\"s-$i\",\"summary\":\"s$i\"}" | bash plugin/claude/hooks/session-end.sh
  done
  COUNT=$(jq 'length' .omc/sessions/index.json)
  [ "$COUNT" = "50" ]
}

@test "session-end increments learnings_recalled" {
  cd "$TEST_TMPDIR"
  echo '{"session_id":"s","summary":"x"}' | bash plugin/claude/hooks/session-end.sh
  [ "$(jq -r '.counters.learnings_recalled' .omc/learnings/_metrics.json)" = "1" ]
}
