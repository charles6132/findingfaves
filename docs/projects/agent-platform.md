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

Five subagents built and wired — `debugger`, `implementer`, `analyzer`, plus
`scout` and `researcher` carrying harness-enforced `maxTurns`. Four hooks:
per-edit lint, a Stop-gate on tests, a frontmatter parse check, and a
SubagentStop hook that writes agent memory the read-only agents cannot write
themselves. `mcp-debugger` attached over stdio and verified by handshake.

Three parallel branches were consolidated onto
`claude/cowork-handoff-implementation-0fhik6`. CLAUDE.md exists and loads.

**Nothing here has been measured on this codebase.** Every hook was validated by
execution and every one of them had a real bug that reading missed — that is the
only claim this project can currently make.

## Next

Port or ship the three engine scripts; run the staged research design once and measure it.

## Blocked on

Nothing. The eval set is blocked on this repo having merged PRs, but nothing else is.

<!-- LOG BELOW — append only, never loaded. -->
