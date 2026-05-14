#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  export REPO_ROOT="$TEST_TMPDIR"
  mkdir -p "$TEST_TMPDIR/.omc/learnings/_archive"
  for c in preferences pitfalls patterns glossary; do
    echo "# Learnings: $c" > "$TEST_TMPDIR/.omc/learnings/$c.md"
  done
  echo '{"counters":{"learnings_added":0},"last_updated":"x"}' > "$TEST_TMPDIR/.omc/learnings/_metrics.json"

  # Copy script to test location with modified REPO_ROOT
  mkdir -p "$TEST_TMPDIR/plugin/claude/hooks/lib"
  cp "${BATS_TEST_DIRNAME}/../lib/learn-add.sh" "$TEST_TMPDIR/plugin/claude/hooks/lib/learn-add.sh"
  chmod +x "$TEST_TMPDIR/plugin/claude/hooks/lib/learn-add.sh"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "learn-add appends to preferences" {
  cd "$TEST_TMPDIR"
  run plugin/claude/hooks/lib/learn-add.sh preferences "minimal setup wins"
  [ "$status" -eq 0 ]
  grep -q "minimal setup wins" .omc/learnings/preferences.md
}

@test "learn-add rejects invalid category" {
  cd "$TEST_TMPDIR"
  run plugin/claude/hooks/lib/learn-add.sh invalid "x"
  [ "$status" -eq 2 ]
}

@test "learn-add updates _history.jsonl" {
  cd "$TEST_TMPDIR"
  run plugin/claude/hooks/lib/learn-add.sh patterns "ksbc skeleton works"
  [ "$status" -eq 0 ]
  [ -s .omc/learnings/_history.jsonl ]
  grep -q "patterns" .omc/learnings/_history.jsonl
}

@test "learn-add increments metrics counter" {
  cd "$TEST_TMPDIR"
  plugin/claude/hooks/lib/learn-add.sh glossary "term: definition"
  [ "$(jq -r '.counters.learnings_added' .omc/learnings/_metrics.json)" = "1" ]
}
