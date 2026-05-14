#!/usr/bin/env bash
# plugin/claude/hooks/lib/inject.sh - compose context injection

inject_file() {
  # Print file content if exists, else nothing
  local file="$1"
  [[ -f "$file" ]] && cat "$file" || true
}

inject_section() {
  # inject_section <title> <file>
  local title="$1" file="$2"
  if [[ -f "$file" ]]; then
    printf '## %s\n\n' "$title"
    cat "$file"
    printf '\n'
  fi
}
