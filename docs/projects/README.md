# Project registry

One card per project. The point is not filing — it is keeping the **always-loaded**
context small while leaving everything else retrievable.

## Three tiers, by load cost

| Tier | Where | Cost |
|---|---|---|
| Index | the `projects:begin`/`end` block in `CLAUDE.md` | **every turn of every session** — one line per active project |
| Card | `docs/projects/<slug>.md` | nothing until someone opens it |
| Storage | `docs/projects/_archive/<slug>.md` | nothing — listed by name only |

Active vs. archived is the visible distinction. The one that actually matters is
**loaded every turn vs. fetched on demand**, and that is what the tiers encode.

## Card shape, and why it has two halves

```markdown
---
project: slug            # must match the filename
title: Human title
status: active           # or archived
updated: 2026-09-18
summary: One line. This is what lands in the always-loaded index.
reopen-if: "..."         # archived only, and required
sessions: []
---

## State        ← REWRITTEN every review. Capped at 20 lines.
## Next         ← the single next action
## Blocked on   ← what is stopping it, or "Nothing."

<!-- LOG BELOW — append only, never loaded. -->
```

**A summary that grows is not a summary.** Most memory schemes fail by appending
a paragraph per session until the summary is as long as the thing it summarised.
So State is *rewritten* and capped; history is *appended* below a marker nothing
reads unless asked. That split is the whole design.

## Rules

- **Archiving requires a reopen condition**, in the user's own words. `registry.py
  check` fails without one. "Not right now" is not a condition; "when the
  contractor dataset lands" is — it turns storage into a watchlist instead of a
  graveyard.
- **Archive, never delete.** Same convention as `.claude/skills/_archive/`.
- **Never invent state.** A card for a project known only by its session title
  says `_Not yet reviewed._` until someone confirms otherwise.
- **The index is generated**, not hand-edited — `registry.py index --write`.

## Use it

```bash
python3 .claude/skills/defrag/registry.py list
python3 .claude/skills/defrag/registry.py stale --days 21
python3 .claude/skills/defrag/registry.py check
```

The weekly review that drives all of this is the `defrag` skill.
