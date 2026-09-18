---
name: research-agent
user-invocable: true
allowed-tools: Read, Write, Glob, WebSearch, WebFetch, Task, Bash, AskUserQuestion
description: Deep research on an open question — plan, parallel multi-engine research, evidence ledger, verification, and a cited narrative report. Use when answering a question or surveying a field, where a single search-and-summarize pass is not enough. Supersedes multi-search-research. NOT for comparing a known set of things across fixed dimensions — that is research-compare, which produces a table.
---

# Research Agent (v2)

A self-contained deep research agent. Built from the patterns the top open-source
research agents converged on (gpt-researcher, STORM, shandu, Feynman, LangChain
Open Deep Research, dzhng/deep-research): plan before searching, parallel
researchers with isolated contexts, an evidence ledger that every citation must
come from, a verification pass, and a writer that never searches.

## Trigger

`/research-agent <topic>` — or any substantial research request: "research X",
"compare Y and Z", "what is the state of the art in W".

## Output layout

```
{topic_slug}/
  ├── plan.md            # scope, sub-questions, budget (checkpoint)
  ├── evidence/          # one JSON per sub-question (checkpoint)
  │   └── {sub_question_slug}.json
  ├── ledger.json        # merged claims → numbered sources (checkpoint)
  ├── report.md          # final cited report
  └── run.json           # run record for memory (queries, visited URLs)
```

## Supporting scripts — resolve before you start

Phases 1–3 shell out to three scripts that live beside `ENGINES.md`. Resolve
`$ENGINES` once, in this order, and use it everywhere below:

1. `.claude/skills/research-engines/` in the current project, if present
2. `~/.claude/skills/research-engines/` otherwise (on the desktop this is a
   directory junction onto `~/.agents/skills`)

| Script | Used by | Purpose |
|---|---|---|
| `search.ps1` | researchers | the only sanctioned search path — trims results to four fields |
| `merge_evidence.py` | Phase 2 | dedup and number the ledger without reading evidence into context |
| `checkurls.ps1` | Phase 3 | parallel liveness check over every ledger URL |

⚠️ **Only `ENGINES.md` is present in this repository.** The three scripts exist
on the desktop skills store and were not committed, and two of them are
PowerShell, so this skill **cannot currently run end to end from a Linux
checkout**. Check that `$ENGINES` actually contains them before Phase 1 and stop
with a clear message if it does not. Do not improvise replacements mid-run: the
evidence and ledger formats are consumed by `merge_evidence.py`, and a
substitute that guesses at its behaviour will produce a ledger that looks right
and is not.

## Phase 0 — Scope and plan

1. **Depth defaults to quick.** Quick = 3 sub-questions, 1 round, no gap-fill.
   Standard = 5-6 sub-questions, 1 gap-fill round. Deep = up to 8 sub-questions,
   2 rounds.

   Run quick unless the user asked for more. Do **not** offer the three options
   as an open question — depth is the single biggest cost decision in the
   pipeline (each sub-question is another researcher, and researchers are ~86%
   of the cost), and "standard" is the easy thing to click. Say which depth you
   are using in one line and get on with it; the user can say "make it deep".

   Still AskUserQuestion for the time range if it is not obvious from the
   request.
2. **Draft provisional sub-questions** — 3-8 of them, each independently
   researchable and answerable from sources rather than opinion. Do this from
   what you already know. Do not search, and do not fetch anything: you are the
   most expensive context in the run and everything you pull in is re-read on
   every subsequent turn.
3. **Send the `scout` agent** (Task tool, `subagent_type: scout`) with the
   provisional sub-questions and the time range. It searches without fetching,
   capped at 10 turns by the harness, and writes `{topic_slug}/targets.json` —
   a ranked list of URLs per sub-question plus any question it thinks is
   ill-posed, already answered, or secretly two questions.

   This replaces reading overview sources yourself. Perspective mining (STORM)
   still happens, it just happens in a cheap context instead of yours.
4. **Finalize the sub-questions** from the scout's summary — reword what it
   flagged, drop what is already answered, split what is doubled.
5. Set the budget and write it into `plan.md`:
   - max iterations: 2 (standard) or 3 (deep)
   - max sources per sub-question: 6-8
   - max searches and max pages per researcher: 6 each
   - time cap: state it; stop when hit
6. Save `plan.md`. This is the first checkpoint — a crash here resumes from the
   plan, not from scratch. `targets.json` is the second.

## Phase 1 — Parallel research

Launch one **`researcher`** agent per sub-question with the Task tool
(`subagent_type: researcher`), all in a single message — parallel, output
disabled, each writing its own file.

Use that agent type rather than a general-purpose agent with a long prompt. Its
budget lives in `maxTurns: 20` in its frontmatter, where the harness enforces
it; the same budget written as a sentence is advice the model can reason past,
and did — five researchers once overran a 15-call prose budget by 153–253% and
burned 26 M tokens in eight minutes. The caps below are repeated in the agent
definition. **If you change one, change the other.**

Cap concurrency at **2-3 researchers**, never 5. Parallelism does not multiply
tokens, but it compresses the whole burn into one rate-limit window — that is
what actually killed the 2026-09-17 run.

Each researcher prompt must contain:

- The sub-question and its perspective.
- **Its targets from `{topic_slug}/targets.json`** — the specific URLs the scout
  ranked for this sub-question. Handing over pre-selected URLs is what removes
  the open-ended search flailing that produced most of the overrun.
- The time range.
- **Engine recipes**: read `$ENGINES/ENGINES.md`
  and follow it. Search **only** through `$ENGINES/search.ps1` — never
  hit the SearXNG endpoint directly, and never pipe raw `format=json` into the
  conversation. The script returns the same results trimmed to four fields; the
  raw reply is ~15x larger and gets re-read every turn by every researcher.
  ENGINES.md lists the direct-fetch fallbacks, which engines are blocked, the
  failure ladder, and the credibility scale. That file is the single source of
  truth — if a recipe is wrong, fix it there, not here.
- The output contract: write `{topic_slug}/evidence/{sub_question_slug}.json`
  with this exact shape:
  ```json
  {
    "sub_question": "...",
    "findings": [
      {
        "claim": "one assertion, stated precisely",
        "sources": ["https://...", "https://..."],
        "credibility": "HIGH|MEDIUM|LOW",
        "engines": ["duckduckgo", "bing"],
        "uncertain": false
      }
    ],
    "blocked_engines": ["yandex"],
    "queries_used": ["..."],
    "searches_run": 6,
    "pages_fetched": 9,
    "turns_used": 4
  }
  ```
- Rules for the researcher:
  - Every claim must have at least one real source URL it was actually read from.
  - Credibility: use the HIGH/MEDIUM/LOW scale in ENGINES.md.
  - Record which engines returned each source (cross-engine agreement).
  - Never invent a URL. If a page could not be fetched, do not cite it.
  - Mark anything guessed or unverifiable `uncertain: true`.
  - Hard cap: stop at the max sources; do not keep searching past the cap.

- **Work in batches, not one call at a time.** This is the single biggest cost
  lever, bigger than everything else combined. The model has no memory between
  turns: the whole conversation is re-sent on every turn, so a researcher that
  takes 17 turns pays for its context 17 times. Measured 2026-09-17, one
  researcher held at most 127k tokens but was billed 1.56M — the same pile paid
  for eleven times over. Cost scales with turns, not with how much you find.

  Work in four turns, not seventeen:

  1. **Fetch the targets — all at once.** The scout already did the searching,
     so start from `targets.json` and fetch in one parallel batch. Search only
     to fill a gap the targets leave, and batch those too. Five queries in one
     turn cost one context read; five queries in five turns cost five.
  2. **Write the evidence JSON now**, from the first batch, before anything
     else.
  3. **One gap-fill batch, only if a real gap remains.** Searches and fetches
     together, still batched. Skip it if the evidence is already sufficient.
  4. **Rewrite the evidence JSON** — same filename, same schema — and stop.

  **Never write once at the end.** An agent that accumulates everything in
  context and serializes as its final action has an exposure window covering its
  entire run, at maximum accumulated value and zero durable output. On
  2026-09-17 a rate limit hit five researchers in exactly that state; four got
  their writes out on timing alone, and one produced nothing after 43 tool calls
  over 72 turns. That leg is unrecoverable. Writing twice costs almost nothing
  and converts the cliff into a gradient.

  Budget for the whole run: at most 6 searches and 6 pages. Use `-Top 10` (the
  default); raise it only for a sub-question genuinely starved of results. Keep
  each fetched page under ~3,000 tokens — fetch the section you need, not the
  whole document. Never re-fetch a page already in context, and never paste a
  fetched page back out; cite it by URL.

  **Treat `turns_used` as a floor, not a measurement.** The researcher writes its
  file before its last turns happen, so the recorded number is systematically
  lower than the truth — measured 2026-09-17, three of four row agents recorded
  fewer turns in the file than they reported in their own closing message (3 vs
  5, 5 vs 7, 4 vs 6). It is a useful smell, not evidence. The trustworthy counts
  are the ones the harness reports per subagent.

  Report actuals in the evidence JSON (`turns_used`, `searches_run`,
  `pages_fetched`) so a run that blew its budget is visible afterwards.

## Phase 2 — Evidence ledger

Run the merger. Do **not** read the evidence files into context and merge by hand:

```
python "$ENGINES/merge_evidence.py" "{topic_slug}"
```

It dedups by normalized URL (strips tracking params, drops fragments), unions
the engines per source, keeps the highest credibility any researcher assigned,
numbers the survivors `[1]`, `[2]`, ... and writes `ledger.json`. It prints a
one-line summary — sources, credibility counts, single-engine count, blocked
engines — and nothing else. That summary is all the orchestrator needs.

This is pure mechanics and the orchestrator is the most expensive context in the
run. Verified 2026-09-17 against a hand-merged ledger: identical, 57/57 sources,
same credibility on every one.

`agreement` (how many engines returned a source) is recorded per source but
never overwrites credibility — see the credibility scale in ENGINES.md.

Nothing outside the ledger may be cited in the report.

## Phase 3 — Verification

Before writing anything:

1. **URL liveness**: check every URL in the ledger in ONE call —

   ```
   powershell -NoProfile -File "$ENGINES/checkurls.ps1" "{topic_slug}/ledger.json"
   ```

   It pulls the URLs out of the ledger itself, checks them in parallel, and
   returns `checked`, `live`, and a `dead` list with status codes. Drop the dead
   links. Research shows 3-13% of citations in deep-research output are
   fabricated URLs — this pass is the cheap fix.

   **Never check URLs one at a time.** This runs inside the orchestrator, whose
   context is already the largest in the run, so each extra turn is the most
   expensive turn in the whole pipeline. Measured 2026-09-17: 57 URLs, 6.9
   seconds, one turn, ~780 tokens of output.
2. **Single-source flag**: any claim resting on one source is marked
   `single_source: true` and must be flagged in the report.
3. **Triangulation**: for the 3-5 most important claims, confirm against a
   second independent source if one exists; if not, mark `[uncertain]`.
4. Write the verified ledger back to `ledger.json` (checkpoint).

## Phase 4 — Gap-fill (bounded)

List sub-questions whose findings are thin (fewer than 3 sources, or mostly LOW
credibility). Launch ONE targeted round: one researcher per gap, using the
best-performing engines from round 1. Max one extra round — never loop forever.

## Phase 5 — Report

The writer step is a **separate subagent**, not a continuation of the
orchestrator. Launch it with the Task tool. It starts with a clean context and
reads only `ledger.json` and the evidence files — it does not inherit the
planning, the tool calls, or anything else the orchestrator accumulated.

This matters: by Phase 5 the orchestrator is the largest context in the run, and
writing a report is many turns of drafting. Doing it in the orchestrator pays
that whole context on every drafting turn. A fresh subagent starts near zero.

It does not search. It reads only `ledger.json` and writes `report.md`:

- Summary answer with **numbered citations** `[1]` mapping to the ledger.
- Table of contents with anchor links.
- Per-sub-question findings, each claim tied to its numbered sources.
- Sources appendix: every numbered URL with its credibility tag
  (HIGH/MEDIUM/LOW) and engine agreement.
- Per-engine appendix: what each engine returned, including blocked ones.
- Gaps section: single-source claims, `[uncertain]` values, what could not be
  verified.
- Budget line: sub-questions, sources, iterations, engines used.

Hard rule: the writer may cite ONLY URLs present in the ledger. If a fact is not
in the ledger, it is either re-researched or omitted — never invented.

## Phase 6 — Memory

Append a run record to `run.json`: topic, sub-questions, queries used, visited
URLs, report path. Keep a rolling copy at `~/.research-agent/memory.json`
(create the directory if missing). On future runs of the same or related topic,
**skip URLs already visited** (the `--fresh` pattern from ferhatyurdakul's
deep-research) and note in the plan what was already covered. This prevents
re-scraping rate-limited engines and gives cross-run recall.

## Hard rules

- Never cite a URL that is not in the ledger.
- Never claim a blocked engine returned results — report it as blocked.
- Never loop past the budget. Iterations, sources, and fetches all have caps.
- Checkpoint after every phase (plan.md, evidence/, ledger.json). A crashed run
  resumes from the last checkpoint — never restart from scratch.
- Report what failed or stayed uncertain. A report that only lists wins is not
  worth writing.

## Relationship to the other research skills

There are **two research modes**, and they are not interchangeable:

| You want | Use | You get |
|---|---|---|
| To answer an open question, or survey a field | **this skill** | a cited narrative report |
| To compare a known set of things across fixed dimensions | **research-compare** | a filled table, one row per thing |

The tell: *are you comparing a known set of things, or answering an open question?*
Known set → `research-compare`. Open question → this skill.

This skill supersedes `multi-search-research` only — that skill's engine fan-out,
dedup, cross-engine ranking, credibility scoring and gap-fill are all absorbed
here, and its recipes now live in `research-engines/ENGINES.md`.

It does **not** supersede `research-compare` and its pipeline. That mode has an
entity/field schema, mechanical field-coverage validation, per-row resume,
batched execution and a deterministic report generator — none of which exist
here. Sending a comparison task to this skill gets you prose where you wanted a
grid.
