#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/log.sh"
}

@test "log_info outputs INFO to stderr" {
  run bash -c 'source "'"${BATS_TEST_DIRNAME}/../lib/log.sh"'" && log_info "hello" 2>&1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"[INFO]"* ]]
  [[ "$output" == *"hello"* ]]
}

@test "log_warn outputs WARN to stderr" {
  run bash -c 'source "'"${BATS_TEST_DIRNAME}/../lib/log.sh"'" && log_warn "caution" 2>&1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN]"* ]]
  [[ "$output" == *"caution"* ]]
}

@test "log_error outputs ERROR to stderr" {
  run bash -c 'source "'"${BATS_TEST_DIRNAME}/../lib/log.sh"'" && log_error "failure" 2>&1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"[ERROR]"* ]]
  [[ "$output" == *"failure"* ]]
}

@test "log_info output has ISO8601 timestamp" {
  run bash -c 'source "'"${BATS_TEST_DIRNAME}/../lib/log.sh"'" && log_info "ts" 2>&1'
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}
