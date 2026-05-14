#!/usr/bin/env bash
# plugin/claude/hooks/session-start.sh
# Auto-inject core workflow skills into Claude Code session context

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PLUGIN_ROOT = the installed plugin directory (where plugin/claude/hooks/ lives, 3 levels up)
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# PROJECT_CWD = the project being worked in (where .harness-active / .harness-main-only lives)
PROJECT_CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# Marker check: only inject for active harness projects
if [[ ! -f "$PROJECT_CWD/.harness-active" && ! -f "$PROJECT_CWD/.harness-main-only" ]]; then
  exit 0
fi

# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/inject.sh
source "$SCRIPT_DIR/lib/inject.sh"
# shellcheck source=lib/token-budget.sh
source "$SCRIPT_DIR/lib/token-budget.sh"

TOKEN_LIMIT=7000
# Skills live in the plugin (not the project)
SKILLS_DIR="$PLUGIN_ROOT/claude/skills"
CORE_SKILLS=(branch-strategy tdd-loop consensus-loop env-security ss-re)

log_info "SessionStart: injecting core skills"

# 1. Header
printf '# ai-agent-coding-template — Session Context\n\n'
printf '> Auto-injected on every SessionStart. See `plugin/claude/hooks/session-start.sh`.\n\n'

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

# 3. Snapshot 회수 (직전 세션 컨텍스트)
SNAPSHOT="$PROJECT_CWD/.omc/snapshot.md"
inject_section "Previous Session Snapshot (from /ss-re)" "$SNAPSHOT"

log_info "SessionStart: injected ~${total_tokens} tokens"

# === Memory v0.4 — 06.memory/ + plugin/memory/user/ inject ===

# Tier 2: 프로젝트 메모리 (현재 worktree)
PROJECT_MEMORY_DIR="$PROJECT_CWD/06.memory"
if [[ -d "$PROJECT_MEMORY_DIR" ]]; then
  echo ""
  echo "<system-reminder>"
  echo "프로젝트 메모리 (Tier 2 — 이 프로젝트 한정):"
  echo ""
  for f in MEMORY.md project.md feedback.md reference.md CHANGELOG.md; do
    if [[ -f "$PROJECT_MEMORY_DIR/$f" ]]; then
      echo "## 06.memory/$f"
      cat "$PROJECT_MEMORY_DIR/$f"
      echo ""
    fi
  done
  echo "</system-reminder>"
fi

# Tier 3: 사용자 글로벌 메모리 (본 하네스 plugin)
# 1차: 설치된 플러그인 경로, 2차 fallback: 본 레포 개발 모드 (PLUGIN_ROOT 기준)
GLOBAL_MEMORY_DIR="$HOME/.claude/plugins/nathaneast-aiacht/plugin/memory/user"
if [[ ! -d "$GLOBAL_MEMORY_DIR" && -d "$PLUGIN_ROOT/memory/user" ]]; then
  GLOBAL_MEMORY_DIR="$PLUGIN_ROOT/memory/user"
fi
if [[ -d "$GLOBAL_MEMORY_DIR" ]]; then
  echo ""
  echo "<system-reminder>"
  echo "사용자 글로벌 메모리 (Tier 3 — 모든 프로젝트 횡단):"
  echo ""
  for f in INDEX.md user.md comfort.md goals.md dont.md CHANGELOG.md; do
    if [[ -f "$GLOBAL_MEMORY_DIR/$f" ]]; then
      echo "## plugin/memory/user/$f"
      cat "$GLOBAL_MEMORY_DIR/$f"
      echo ""
    fi
  done
  echo "</system-reminder>"
fi

# === End Memory v0.4 ===

# USER_CONFIRM_NEEDED marker (Codex consensus fallback stage 3)
MARKER="$PROJECT_CWD/.omc/state/USER_CONFIRM_NEEDED"
if [[ -f "$MARKER" ]]; then
  printf '\n---\n\n## ⚠️ USER CONFIRM NEEDED\n\n'
  printf 'Consensus fallback stage 3 was triggered in a previous session.\n\n'
  printf '```json\n'
  cat "$MARKER"
  printf '\n```\n\n'
  printf 'Resolve and remove the marker: `rm .omc/state/USER_CONFIRM_NEEDED`\n\n'
fi
