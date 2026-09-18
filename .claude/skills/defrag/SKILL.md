---
name: defrag
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Bash, AskUserQuestion
description: Weekly review of what you are actually working on — reconciles sessions against the project registry, decides what stays active, archives what does not with a condition for reopening it, and surfaces what is blocked on you. Produces decisions and an updated registry, not a report.
---

# Defrag

A recurring review that keeps the always-loaded context small and honest.

The thing being defragmented is not disk. It is **what gets loaded into every
session's context on every turn**. Left alone, that grows monotonically — every
project ever started stays in the index, and the cost is paid forever, on every
turn, whether or not anyone still cares about it.

## The cost rule this skill exists to obey

**Read the index, never the transcripts.** Session titles, statuses, timestamps
and `post_turn_summary` are already model-written compressions, generated for
free by the platform. One `list_sessions` call gives you the whole landscape for
a few thousand tokens. Reading conversations to find out what they were about
would cost more than the context this review saves — that is the failure this
whole repository is a reaction to.

Same shape as the `scout` agent: rank from cheap metadata, open only what the
ranking says is worth opening.

## It runs on a schedule

A Routine fires this weekly — **`trig_01P5waCo7QvzRTyQ6MfYT9dm`, "Friday defrag"**,
Fridays at 22:00 UTC (16:00 Mountain), fresh session each time, on `claude-opus-5`,
with push and email notification. Manage it with the `Claude_Code_Remote` trigger
tools; `update_trigger` changes it in place and keeps its run history.

**A fired session does not inherit this repo or this session's connector tools.**
Its stored `sources` are empty and connectors cannot be attached from a session
(the account has only Gmail, Calendar and Drive; the CCR meta-MCP is not a
connector). That is why the Routine's prompt opens with a REPO / TOOLS / MODE
preflight — the run must prove its own preconditions and say so in its first
three lines rather than half-running. If a scheduled run reports anything other
than "full review", the fix is the claude.ai Routines UI, not this file.

## Phase 0 — Sweep, cheaply

Run these three. Nothing else.

```bash
python3 .claude/skills/defrag/registry.py list
python3 .claude/skills/defrag/registry.py stale --days 21
```

and one `mcp__Claude_Code_Remote__list_sessions` call with `mine: true`.

Do **not** open project cards yet. Do not read any session. You are building a
candidate list, not forming opinions.

**If `list_sessions` is not available**, say so in your first line and stop
pretending this is a full review. A scheduled run may fire without connector
tools, and the session index is the whole input to Phases 1 and 4 — without it
you can validate the registry and nothing else. Report a registry-only pass,
name what is missing, and say the run needs re-firing from a session that has
the tool. Do not silently produce a half-review that looks like a whole one.

## Phase 1 — Reconcile

Put the two lists side by side and sort every item into exactly one bucket:

| Bucket | Test |
|---|---|
| **Live** | a card exists and a session touched it inside 21 days |
| **Untracked** | sessions exist, no card — the registry has drifted |
| **Stale** | a card exists, nothing has touched it in 21+ days |
| **Blocked** | any session whose `needs_action` is non-empty |
| **Noise** | one-off troubleshooting sessions that were never a project |

Cluster sessions by subject, not by title string. Several sessions usually make
up one project. Noise never becomes a card.

**Blocked is the most valuable bucket and the one nobody asks for.** A
non-empty `needs_action` is a thing waiting on the user that they have probably
forgotten. Surface it first, and check it is still real — a blocker from three
weeks ago may already be resolved.

## Phase 2 — Ask, in one batch

Use `AskUserQuestion`. Batch the questions; do not walk through projects one at
a time, and do not ask about anything in the Live bucket — the answer is yes.

Ask only these:

1. **Stale candidates** — keep active, or archive? For each archive, get the
   **reopen condition** in the user's own words. "Not now" is not a condition;
   "when the contractor dataset lands" is.
2. **Untracked clusters** — is this a real project worth a card, or noise?
3. **Archived shelf** — anything to pull back? Show archived names and their
   reopen conditions, and flag any whose condition now looks met.

Recommend rather than survey. If something has not moved in six weeks and its
blocker has not changed, say you would archive it and let the user disagree.

## Phase 3 — Apply

Every decision goes through the script. Do not hand-edit cards.

```bash
python3 .claude/skills/defrag/registry.py new SLUG --title "..." --summary "..."
python3 .claude/skills/defrag/registry.py archive SLUG --reason "..." --reopen-if "..."
python3 .claude/skills/defrag/registry.py reopen SLUG
python3 .claude/skills/defrag/registry.py index --write   # regenerates the CLAUDE.md block
python3 .claude/skills/defrag/registry.py check           # must pass before you finish
```

For each project that stayed active and moved this week, **rewrite its `##
State` section** — do not append to it. State is what is true now, capped at 20
lines. Anything historical goes below the log marker, which is never loaded.

> **A summary that grows is not a summary.** This is the whole reason a card has
> two halves. If you find yourself appending "and then we also…" to State, that
> sentence belongs in the log.

Then commit. An uncommitted registry does not survive an ephemeral container.

## Phase 4 — Look forward, briefly

Close with a short list, in chat, not in a file:

- What is blocked on the user, most-stale first
- What is genuinely next on the active projects
- Anything whose reopen condition now looks met

Keep it to a handful of lines. The point is to start the next week with less
context, not to generate more of it.

## Hard rules

- **Never read a conversation transcript.** Metadata only. If a decision
  genuinely needs more, ask the user rather than paying for the read.
- **Never archive without a reopen condition.** `check` enforces it; storage
  with no way back out is a graveyard.
- **Never delete a card.** Archive it. Same convention as
  `.claude/skills/_archive/`.
- **Never let the index grow unbounded.** It is loaded on every turn of every
  session. One line per active project, archived listed by name only.
- **Never invent state.** A card for a project you only know by title says
  "not yet reviewed" until the user says otherwise.
