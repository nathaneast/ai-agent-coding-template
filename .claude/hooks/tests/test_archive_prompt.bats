#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../.."
  cd "$TEST_TMPDIR"
  mkdir -p 05.tasks .omc/learnings scripts
  cp "$REPO_ROOT_SRC/scripts/archive-prompt.sh" scripts/
  cp "$REPO_ROOT_SRC/scripts/trigram-jaccard.sh" scripts/
  chmod +x scripts/*.sh
}

teardown() { rm -rf "$TEST_TMPDIR"; }

@test "trigram-jaccard returns 1.00 for identical text" {
  cd "$TEST_TMPDIR"
  run bash scripts/trigram-jaccard.sh "hello world test phrase" "hello world test phrase"
  [ "$status" -eq 0 ]
  [ "$output" = "1.00" ]
}

@test "trigram-jaccard returns lower for different text" {
  cd "$TEST_TMPDIR"
  run bash scripts/trigram-jaccard.sh "hello world" "foo bar baz"
  [ "$status" -eq 0 ]
  awk -v r="$output" 'BEGIN{ exit !(r<0.3) }'
}

@test "archive-prompt creates new entry" {
  cd "$TEST_TMPDIR"
  run bash scripts/archive-prompt.sh "make a todo list app please today"
  [ "$status" -eq 0 ]
  grep -q "make a todo list app please today" 05.tasks/prompt.md
}

@test "archive-prompt detects duplicate via Jaccard" {
  cd "$TEST_TMPDIR"
  bash scripts/archive-prompt.sh "make a todo list app please today okay"
  run bash scripts/archive-prompt.sh "make a todo list app please today okay"
  [ "$status" -eq 0 ]
  [[ "$output" == *"duplicate"* ]]
}
