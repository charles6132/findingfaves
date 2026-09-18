---
project: agent-platform
title: Agent platform — agents, hooks, skills
status: active
updated: 2026-09-18
summary: Subagents, verification hooks and research skills, plus the sourced research behind each choice.
sessions:
  - session_01JB5f6A7HZEVnNDZarNK5nC
  - session_01B16CJwXjGMv6578CxurCPV
  - session_01VWuYrXyzfYKLm33fVPL619
  - session_012BUvkY2iQvyPZGS8LCvQ7q
---

## State

Five subagents and five hooks, all wired. `debugger`, `implementer`, `analyzer`,
plus `scout` and `researcher` carrying harness-enforced `maxTurns`. Hooks cover
per-edit lint, a Stop-gate on tests, a frontmatter parse check, and a
SubagentStop hook that writes memory the read-only agents cannot write
themselves. `mcp-debugger` attached over stdio, verified by handshake.

Added 2026-09-18: the project registry and the `defrag` skill — this file is a
product of it.

Three branches consolidated onto `claude/cowork-handoff-implementation-0fhik6`.

**Still unmeasured on this codebase.** Every hook was validated by execution and
every one carried a real bug that reading had missed — five so far. That is the
only claim this project can currently make.

## Next

Port or ship the three engine scripts; run the staged research design once and measure it.

## Blocked on

Nothing. The eval set is blocked on this repo having merged PRs, but nothing else is.

<!-- LOG BELOW — append only, never loaded. -->

### 2026-09-18
Registry, defrag skill and wrap skill built; first defrag run done by hand.
Test suite added (64 checks) and wired into the Stop hook, which had never
actually guarded this repo — no package.json, Cargo.toml, go.mod or pyproject
meant it exited 0 on every turn since it was written.

Friday defrag Routine created (trig_01P5waCo7QvzRTyQ6MfYT9dm), switched to
claude-opus-5 after a diagnostic fire came back on sonnet. Fired sessions carry
no git sources and no connector tools, so the prompt now opens with a
REPO/TOOLS/MODE preflight. Whether the first diagnostic run actually had the
repo is still unread — it finished review-ready at 112K tokens.
