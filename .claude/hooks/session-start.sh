#!/usr/bin/env bash
# .claude/hooks/session-start.sh
# Auto-inject core workflow skills into Claude Code session context

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/inject.sh
source "$SCRIPT_DIR/lib/inject.sh"
# shellcheck source=lib/token-budget.sh
source "$SCRIPT_DIR/lib/token-budget.sh"

TOKEN_LIMIT=7000
SKILLS_DIR="$REPO_ROOT/.claude/skills"
CORE_SKILLS=(branch-strategy tdd-loop consensus-loop env-security session-index)

log_info "SessionStart: injecting core skills"

# 1. Header
printf '# ai-agent-coding-template — Session Context\n\n'
printf '> Auto-injected on every SessionStart. See `.claude/hooks/session-start.sh`.\n\n'

# 2. Core skills
total_tokens=0
for skill in "${CORE_SKILLS[@]}"; do
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    skill_tokens=$(estimate_tokens "$skill_file")
    if check_budget "$((total_tokens + skill_tokens))" "$TOKEN_LIMIT"; then
      inject_section "Skill: $skill" "$skill_file"
      total_tokens=$((total_tokens + skill_tokens))
    else
      log_warn "Skill $skill skipped — would exceed token budget ($total_tokens + $skill_tokens > $TOKEN_LIMIT)"
    fi
  else
    log_warn "Skill file missing: $skill_file"
  fi
done

# 3. learnings placeholder (Phase 2 will populate)
LEARNINGS_DIR="$REPO_ROOT/.omc/learnings"
if [[ -d "$LEARNINGS_DIR" ]]; then
  for category in preferences pitfalls patterns glossary; do
    inject_section "Learnings: $category" "$LEARNINGS_DIR/$category.md"
  done
fi

# 4. session-index placeholder (Phase 5 will populate)
SESSION_INDEX="$REPO_ROOT/.omc/sessions/index.json"
if [[ -f "$SESSION_INDEX" ]]; then
  printf '## Recent Sessions\n\n```json\n'
  tail -c 2000 "$SESSION_INDEX"
  printf '\n```\n\n'
fi

log_info "SessionStart: injected ~${total_tokens} tokens"

# USER_CONFIRM_NEEDED marker (Codex consensus fallback stage 3)
MARKER="$REPO_ROOT/.omc/state/USER_CONFIRM_NEEDED"
if [[ -f "$MARKER" ]]; then
  printf '\n---\n\n## ⚠️ USER CONFIRM NEEDED\n\n'
  printf 'Consensus fallback stage 3 was triggered in a previous session.\n\n'
  printf '```json\n'
  cat "$MARKER"
  printf '\n```\n\n'
  printf 'Resolve and remove the marker: `rm .omc/state/USER_CONFIRM_NEEDED`\n\n'
fi
