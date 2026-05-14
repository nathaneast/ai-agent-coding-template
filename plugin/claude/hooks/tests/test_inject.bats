#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/inject.sh"
  TMPFILE=$(mktemp)
}

teardown() {
  rm -f "$TMPFILE"
}

@test "inject_file outputs content of existing file" {
  printf 'hello content' > "$TMPFILE"
  run inject_file "$TMPFILE"
  [ "$status" -eq 0 ]
  [ "$output" = "hello content" ]
}

@test "inject_file outputs nothing for missing file" {
  run inject_file "/nonexistent/file.md"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "inject_section outputs title and content" {
  printf 'skill content here' > "$TMPFILE"
  run inject_section "My Skill" "$TMPFILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## My Skill"* ]]
  [[ "$output" == *"skill content here"* ]]
}

@test "inject_section outputs nothing for missing file" {
  run inject_section "Missing" "/nonexistent/file.md"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
