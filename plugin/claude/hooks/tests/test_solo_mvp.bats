#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"
  REPO_ROOT_SRC="${BATS_TEST_DIRNAME}/../../../.."
  cd "$TEST_TMPDIR"
  git init -q
  mkdir -p plugin/claude/hooks/lib
  cp "$REPO_ROOT_SRC"/plugin/claude/hooks/lib/solo-*.sh plugin/claude/hooks/lib/
  chmod +x plugin/claude/hooks/lib/solo-*.sh
  cat > package.json <<'JSON'
{"scripts":{"lint":"true","test":"true"}}
JSON
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "solo MVP creates locked spec, runs verify, and writes report" {
  run bash plugin/claude/hooks/lib/solo-spec.sh prepare "Build a verifiable harness feature"
  [ "$status" -eq 0 ]
  run bash plugin/claude/hooks/lib/solo-spec.sh lock
  [ "$status" -eq 0 ]
  run bash plugin/claude/hooks/lib/solo-run.sh start
  [ "$status" -eq 0 ]
  [[ "$output" == *"started run_id="* ]]

  run bash plugin/claude/hooks/lib/solo-verify.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"all commands passed"* ]]

  run bash plugin/claude/hooks/lib/solo-run.sh finish done
  [ "$status" -eq 0 ]
  [ -f .harness/reports/latest.md ]
  grep -q "outcome: done" .harness/reports/latest.md
}

@test "solo spec validation refuses unsafe verify commands" {
  mkdir -p 01.spec
  cat > 01.spec/harness-spec.json <<'JSON'
{
  "schema_version": "harness-spec/v1",
  "status": "locked",
  "goal": "Unsafe command should be rejected",
  "acceptance_criteria": [{"id":"A1","description":"Reject unsafe command","priority":"critical","mode":"auto","verify_commands":["git push origin main"]}],
  "verify_commands": ["git push origin main"]
}
JSON

  run bash plugin/claude/hooks/lib/solo-spec.sh validate --locked
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsafe command"* ]]
}

@test "solo spec validation refuses exit-code masking suffixes (|| true)" {
  mkdir -p 01.spec
  cat > 01.spec/harness-spec.json <<'JSON'
{
  "schema_version": "harness-spec/v1",
  "status": "locked",
  "goal": "Masking suffix must be rejected so failures cannot be hidden",
  "acceptance_criteria": [{"id":"A1","description":"credential ignore","priority":"critical","mode":"auto","verify_commands":["git check-ignore -v credentials.json token.json || true"]}],
  "verify_commands": ["git check-ignore -v credentials.json token.json || true"]
}
JSON

  run bash plugin/claude/hooks/lib/solo-spec.sh validate --locked
  [ "$status" -ne 0 ]
  [[ "$output" == *"weak"* || "$output" == *"tautological"* ]]
}

@test "solo spec validation refuses weak verify commands (--help / py_compile / test -f)" {
  mkdir -p 01.spec
  cat > 01.spec/harness-spec.json <<'JSON'
{
  "schema_version": "harness-spec/v1",
  "status": "locked",
  "goal": "Weak verify commands must be rejected at lock time",
  "acceptance_criteria": [{"id":"A1","description":"help only","priority":"critical","mode":"auto","verify_commands":["python3 erp_upload.py --help"]}],
  "verify_commands": ["python3 erp_upload.py --help"]
}
JSON

  run bash plugin/claude/hooks/lib/solo-spec.sh validate --locked
  [ "$status" -ne 0 ]
  [[ "$output" == *"weak"* || "$output" == *"tautological"* ]]
}
