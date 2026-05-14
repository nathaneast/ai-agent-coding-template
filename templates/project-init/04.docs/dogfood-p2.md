# Dogfood P2: /learn + .omc/learnings/ Gate

Date: 2026-05-14

## Gate Criteria

| # | Check | Command | Result |
|---|-------|---------|--------|
| 1 | learn-add exit 0 | `.claude/hooks/lib/learn-add.sh preferences "dogfood test entry P2"` | PASS (exit 0) |
| 2 | entry in preferences.md | `grep "dogfood test entry P2" .omc/learnings/preferences.md` | PASS |
| 3 | metrics counter incremented | `jq '.counters.learnings_added' .omc/learnings/_metrics.json` | PASS (1) |
| 4 | session-start recalls entry | `bash .claude/hooks/session-start.sh \| grep "dogfood test entry P2"` | PASS |
| 5 | bats 4/4 | `bats .claude/hooks/tests/test_learn_add.bats` | PASS (4/4) |

## Output Evidence

```
added to preferences (7 lines, limit 200)
- dogfood test entry P2 _(added 2026-05-14T01:03:32Z, 42cc7602afc31907)_
learnings_added: 1
```

session-start output size: **7005 bytes** (learnings injected)

## File Line Counts

| file | lines |
|------|-------|
| preferences.md | 7 |
| pitfalls.md | 6 |
| patterns.md | 6 |
| glossary.md | 9 |

## Status

**Phase 2 Gate: PASS** — /learn skill active, learnings persistence working, SessionStart recalls all 4 categories.
