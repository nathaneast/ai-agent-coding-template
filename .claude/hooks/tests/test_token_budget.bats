#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/token-budget.sh"
  TMPFILE=$(mktemp)
}

teardown() {
  rm -f "$TMPFILE"
}

@test "estimate_tokens returns 0 for missing file" {
  run estimate_tokens "/nonexistent"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "estimate_tokens estimates ~chars/4" {
  printf 'hello world' > "$TMPFILE"  # 11 chars
  run estimate_tokens "$TMPFILE"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "estimate_tokens returns 0 for empty file" {
  : > "$TMPFILE"
  run estimate_tokens "$TMPFILE"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "check_budget returns 0 within limit" {
  run check_budget 100 1000
  [ "$status" -eq 0 ]
}

@test "check_budget returns 1 over limit" {
  run check_budget 1001 1000
  [ "$status" -eq 1 ]
}

@test "check_budget returns 0 at exact limit" {
  run check_budget 1000 1000
  [ "$status" -eq 0 ]
}
