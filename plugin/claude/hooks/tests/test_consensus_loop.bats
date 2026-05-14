#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../../.."
  cd "$TEST_TMPDIR"
  mkdir -p plugin/claude/hooks/lib .omc/state .omc/learnings
  cp "$REPO_ROOT_SRC/plugin/claude/hooks/lib/consensus-loop.sh" plugin/claude/hooks/lib/
  chmod +x plugin/claude/hooks/lib/consensus-loop.sh
  echo '{"counters":{"consensus_first_pass":0,"consensus_loops_total":0},"last_updated":"x"}' > .omc/learnings/_metrics.json
}

teardown() { rm -rf "$TEST_TMPDIR"; }

@test "parse-verdict detects exact APPROVE" {
  cd "$TEST_TMPDIR"
  run bash plugin/claude/hooks/lib/consensus-loop.sh parse-verdict "Review done. VERDICT: APPROVE"
  [ "$status" -eq 0 ]
  [ "$output" = "APPROVE" ]
}

@test "parse-verdict detects exact REQUEST_CHANGES" {
  cd "$TEST_TMPDIR"
  run bash plugin/claude/hooks/lib/consensus-loop.sh parse-verdict "Some text. VERDICT: REQUEST_CHANGES"
  [ "$status" -eq 0 ]
  [ "$output" = "REQUEST_CHANGES" ]
}

@test "parse-verdict synonym RECOMMENDATION: APPROVE" {
  cd "$TEST_TMPDIR"
  run bash plugin/claude/hooks/lib/consensus-loop.sh parse-verdict "Body. RECOMMENDATION: APPROVE"
  [ "$status" -eq 0 ]
  [ "$output" = "APPROVE" ]
}

@test "parse-verdict empty input returns REQUEST_CHANGES" {
  cd "$TEST_TMPDIR"
  run bash plugin/claude/hooks/lib/consensus-loop.sh parse-verdict ""
  [ "$status" -eq 0 ]
  [ "$output" = "REQUEST_CHANGES" ]
}

@test "start creates session file" {
  cd "$TEST_TMPDIR"
  run bash plugin/claude/hooks/lib/consensus-loop.sh start "test task"
  [ "$status" -eq 0 ]
  [ -f "$output" ]
}

@test "iterate APPROVE on first loop -> approved + first_pass counter" {
  cd "$TEST_TMPDIR"
  SF=$(bash plugin/claude/hooks/lib/consensus-loop.sh start "task")
  run bash plugin/claude/hooks/lib/consensus-loop.sh iterate "$SF" APPROVE
  [ "$status" -eq 0 ]
  [[ "$output" == *"APPROVED"* ]]
  [ "$(jq -r '.counters.consensus_first_pass' .omc/learnings/_metrics.json)" = "1" ]
}

@test "iterate REQUEST_CHANGES 4 times -> max_loops_reached" {
  cd "$TEST_TMPDIR"
  SF=$(bash plugin/claude/hooks/lib/consensus-loop.sh start "task")
  bash plugin/claude/hooks/lib/consensus-loop.sh iterate "$SF" REQUEST_CHANGES || true
  bash plugin/claude/hooks/lib/consensus-loop.sh iterate "$SF" REQUEST_CHANGES || true
  bash plugin/claude/hooks/lib/consensus-loop.sh iterate "$SF" REQUEST_CHANGES || true
  run bash plugin/claude/hooks/lib/consensus-loop.sh iterate "$SF" REQUEST_CHANGES
  [ "$status" -eq 2 ]
  [[ "$output" == *"MAX_LOOPS_REACHED"* ]]
}

@test "fallback stage 3 creates USER_CONFIRM_NEEDED marker" {
  cd "$TEST_TMPDIR"
  SF=$(bash plugin/claude/hooks/lib/consensus-loop.sh start "task")
  run bash plugin/claude/hooks/lib/consensus-loop.sh fallback "$SF" 3
  [ "$status" -eq 0 ]
  [ "$output" = "pause-and-confirm" ]
  [ -f .omc/state/USER_CONFIRM_NEEDED ]
}
