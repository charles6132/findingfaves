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

Five subagents and five hooks, all wired, plus a project registry, a weekly
`defrag` ritual and a `wrap` skill. `tests/run.sh` covers it — **84 checks**,
run by the Stop hook, which until today had never guarded this repo at all.

`merge_evidence.py` and `check_urls.py` are ported to portable Python and
tested, so the research pipeline can run on Linux; only `search.ps1` is
unportable and `WebSearch` is the documented fallback.

Friday defrag Routine live on `claude-opus-5` with a REPO/TOOLS/MODE preflight.

**Still unmeasured on this codebase, and the research pipeline has never run end
to end.** Nine bugs found so far, every one by execution and none by reading.

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

### 2026-09-18 (later)
Ported the two missing engine scripts and tested the TypeScript and Rust hook
branches, which turned out to be correct. Two more bugs: the ledger cited raw
URLs with tracking params still attached, and the determinism test was flaky on
a timestamp. Suite at 84, three consecutive clean runs.
