#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR=$(mktemp -d)
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../../.."
  cd "$TEST_TMPDIR"
  mkdir -p scripts .omc/sessions/archive
  cp "$REPO_ROOT_SRC/scripts/resume-session.sh" scripts/
  chmod +x scripts/resume-session.sh

  # Build a 3-entry index
  cat > .omc/sessions/index.json <<'EOF'
[
  {"sessionId":"old","timestamp":"2026-05-12T10:00:00Z","branch":"dev","cwd":".","summary":"oldest","lastFiles":[],"lastCommits":[],"archivePath":".omc/sessions/archive/old.md"},
  {"sessionId":"mid","timestamp":"2026-05-13T10:00:00Z","branch":"dev","cwd":".","summary":"middle","lastFiles":[],"lastCommits":[],"archivePath":".omc/sessions/archive/mid.md"},
  {"sessionId":"new","timestamp":"2026-05-14T10:00:00Z","branch":"dev","cwd":".","summary":"newest","lastFiles":[],"lastCommits":[],"archivePath":".omc/sessions/archive/new.md"}
]
EOF
  echo "# Newest archive" > .omc/sessions/archive/new.md
  echo "# Middle archive" > .omc/sessions/archive/mid.md
  echo "# Old archive" > .omc/sessions/archive/old.md
}

teardown() { rm -rf "$TEST_TMPDIR"; }

@test "resume-session 1 → newest" {
  cd "$TEST_TMPDIR"
  run bash scripts/resume-session.sh 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"sessionId: new"* ]]
  [[ "$output" == *"Newest archive"* ]]
}

@test "resume-session 3 → oldest" {
  cd "$TEST_TMPDIR"
  run bash scripts/resume-session.sh 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"sessionId: old"* ]]
}

@test "resume-session N>length fails" {
  cd "$TEST_TMPDIR"
  run bash scripts/resume-session.sh 99
  [ "$status" -eq 2 ]
}

@test "resume-session emits Scenario B archive body" {
  cd "$TEST_TMPDIR"
  run bash scripts/resume-session.sh 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Middle archive"* ]]
  [[ "$output" == *"Scenario B"* ]]
}
