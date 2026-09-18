---
name: wrap
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Bash, AskUserQuestion
description: Close out a working session by updating its project card — rewrite what is true now, append what happened to the log, and commit. Run this before ending a session so the next one starts from current state instead of re-deriving it.
---

# Wrap

Run this **before ending a session**, while the work is still in context.

## Why it has to happen here

Compression needs a model, and a model is exactly what a `SessionEnd` hook does
not have — a shell script can dump a transcript but cannot tell you what mattered
in it. So the distillation has to happen while the session is still alive, by the
one participant who knows which parts were load-bearing.

This is cheap precisely because you are not researching anything. Everything
needed is already in your context. **Do not re-read files, re-run commands, or
re-derive what happened** to write this. If you cannot remember it, it was not
durable enough to record.

## What to do

1. **Pick the card.** Infer it from the work — `registry.py list` shows what
   exists. If the work does not fit any card, ask whether it is a new project or
   a detour; do not create one unasked. If it spans two, update both.

2. **Rewrite `## State`.** Not append — *rewrite*. State is what is true now, in
   20 lines or fewer. Someone reading only this section should be able to pick
   the work up.

   Write it for a reader with no memory of today. "Finished the hook" means
   nothing next week; "SubagentStop hook writes agent memory; validated, 11
   cases" survives.

3. **Set `## Next` to one action** — the actual next thing, not a list. And
   `## Blocked on` to what is genuinely stopping it, or `Nothing.`

4. **Append the session's own line below the log marker.** Two or three lines,
   dated. This is the part that may grow forever, because nothing loads it.

   ```markdown
   ### 2026-09-18
   Built the project registry and defrag skill. Two bugs found by running it,
   one a crash that would have killed the first scheduled run.
   ```

5. **Update `updated:`** in the frontmatter to today.

6. **Verify and commit.**
   ```bash
   python3 .claude/skills/defrag/registry.py check
   python3 .claude/skills/defrag/registry.py index --write   # only if summary changed
   ```
   Commit the card. An uncommitted card does not survive an ephemeral container,
   and this repo is worked from those.

## What belongs in State, and what does not

| Goes in State | Goes in the log |
|---|---|
| What is true and current | What happened today |
| The live blocker | A blocker that has since cleared |
| A decision still in force | The debate that produced it |
| Where things live now | Where they used to live |

If a State line would still be true in a month, it belongs there. If it is a
thing that happened, it belongs below the marker.

> **A summary that grows is not a summary.** The moment you catch yourself
> writing "and then we also…" into State, that sentence is a log entry.

## Hard rules

- **Never append to State.** Rewriting it is the whole point. If the new State
  is shorter than the old one, that is usually correct.
- **Never exceed 20 lines of State.** `check` enforces it. Hitting the cap
  repeatedly means the card is two projects.
- **Never record something you did not do.** A wrap that overstates progress is
  worse than no wrap — the next session starts from a false position and the
  error compounds silently.
- **Never invent a next action** to make the card look tidy. `_Unknown — set at
  the next defrag._` is an honest value.
