#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../.."
  cd "$TEST_TMPDIR"
  mkdir -p scripts .omc/state .claude/hooks/tests
  cp "$REPO_ROOT_SRC/scripts/build-iteration-gate.sh" scripts/
  chmod +x scripts/build-iteration-gate.sh
  git init -q
  git config user.email t@t.com && git config user.name t
  git checkout -q -b dev
  echo x > a.txt && git add a.txt && git commit -q -m "feat: init"
}
teardown() { rm -rf "$TEST_TMPDIR"; }

@test "gate passes on dev with clean state + valid commit" {
  cd "$TEST_TMPDIR"
  run bash scripts/build-iteration-gate.sh 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: 3"* ]] || [[ "$output" == *"PASS: 2"* ]]
}

@test "gate fails on main branch" {
  cd "$TEST_TMPDIR"
  git checkout -q -b main
  run bash scripts/build-iteration-gate.sh 1
  [ "$status" -ne 0 ]
}

@test "gate fails on bad commit prefix" {
  cd "$TEST_TMPDIR"
  echo y > b.txt && git add b.txt && git commit -q -m "random change"
  run bash scripts/build-iteration-gate.sh 2
  [ "$status" -ne 0 ]
}
