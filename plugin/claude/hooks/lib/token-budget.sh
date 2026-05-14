#!/usr/bin/env bash
# plugin/claude/hooks/lib/token-budget.sh - approximate token budget (chars/4)

estimate_tokens() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return; }
  local chars
  chars=$(wc -c < "$file" | tr -d ' ')
  echo $(( chars / 4 ))
}

check_budget() {
  # check_budget <current_tokens> <limit>
  local current="$1" limit="$2"
  if [[ "$current" -gt "$limit" ]]; then
    return 1
  fi
  return 0
}
