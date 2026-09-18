# Postmortem: why the deep-research fan-out burned the token budget

**Date:** 2026-09-17 · **Window:** 17:52–18:01 UTC (~8 minutes) · **Outcome:** session rate limit hit, all 5 agents killed; 4 of 5 notes files survived, 1 leg lost

## The numbers

| Metric | Value |
|---|---|
| Cache-read tokens | **26,036,649** |
| Cache-write tokens | 1,562,648 |
| **Output tokens** | **4,551** |
| Turns (5 agents) | 335 |
| Tool calls | 219 (75 WebSearch, 51 WebFetch, 48 Bash, 26 Read, 12 MCP, 7 ToolSearch) |
| Ratio | **5,720 tokens read per token written** |

Per agent, against the skill's own stated budget of "roughly 10 tool calls, avoid exceeding 15":

| Agent | Tool calls | Turns | Cache-read | Over budget |
|---|---|---|---|---|
| Claude Code impl | 42 | 66 | 8,794,710 | +180% |
| Prompts/process | 43 | 72 | 5,086,544 | +186% |
| Open-source agents | 53 | 78 | 5,223,946 | +253% |
| Debugging agents | 43 | 67 | 4,101,135 | +186% |
| Benchmarks | 38 | 52 | 2,830,314 | +153% |

## Root cause

**The cost is quadratic in turn count, and I tripled the turn count.**

Context growth for the worst agent:

```
turn  1:  40,828 tokens
turn 19: 117,443
turn 37: 170,021
turn 61: 213,965
```

Every turn re-reads the entire accumulated context. Tool results are appended and never dropped. So total cost is the *area under that curve*, not the final height. Double the tool calls and you roughly quadruple the spend.

Contributing factors, in order of weight:

1. **Over-specified prompts (primary).** I gave each researcher 7–9 key questions, an "at minimum cover these 17 projects" list, and instructions to be "dense", "comprehensive", and "generous with excerpts". The skill is tuned for ~10 tool calls; my scope required ~40. Every agent overran by 150–250%.
2. **Fixed overhead × turn count.** Baseline context was ~41K tokens before any work (system prompt + tool schemas + skill text). 41K × 335 turns ≈ **13.7M tokens — over half the total burn — spent re-reading the same boilerplate.**
3. **Five-way parallelism.** Didn't increase total tokens much, but compressed the entire burn into one 8-minute rate-limit window. Serialized, the same work might have stayed under the cap.
4. **Opus for all five.** Highest-cost model on the leg of the work (search triage) that needs it least.

## Second, independent bug: write-on-end fragility

**CORRECTED 2026-09-18.** This section originally claimed all work was lost. That was wrong, and the error is instructive.

Each agent accumulates findings in its context across dozens of tool calls, then serializes everything in a **single Write as its final action**. No incremental persistence. Any termination before that write — rate limit, timeout, crash, interrupt, `maxTurns` — loses everything, and the exposure window is the entire run.

**What actually happened:**

- All five agents returned `status: failed` with no result payload, and the notes directory was empty when checked at 18:00.
- That check was taken **while the writers were still running**. Four of the five completed their writes at 18:00:58, 18:02:55, 18:03:35 and 18:05:33 — after the failure notifications arrived. **254 KB / 1,830 lines of notes survived** and are committed at `research_notes/Debug and coding agent design/`.
- **One leg was lost outright:** `prompts_and_process_patterns.md` was never written. 43 tool calls, 72 turns, zero output.
- **All five return summaries were lost**, which is why the coordinator saw failures rather than findings and misjudged the loss.

**Corrected severity: 1 of 5 legs lost (20%), plus all hand-backs — not 100%.**

Two lessons rather than one. The fragility is real and worth fixing (append per source, don't write once at the end). But the misdiagnosis came from **inferring completion state from a directory listing taken mid-flight** — the same premature-conclusion error the debugger agent's prompt is written to prevent.

## Verdict on the skill

The skill is **not** the monster. `references/researcher.md` explicitly says *"Roughly 10 tool calls is typical; avoid exceeding 15."* That guidance is sound. The failure was in how it was invoked.

But there is a structural weakness: that budget is **prose, not a constraint**. Nothing enforces it. A researcher handed an ambitious scope will blow through a suggested limit every time — the same lesson as putting verification in hooks rather than instructions.

## Fixes

| # | Fix | Mechanism | Est. saving |
|---|---|---|---|
| 1 | Cap scope at 2–3 key questions per researcher | Prompt discipline | ~60% |
| 2 | Set `maxTurns: 20` on research subagents | **Hard enforcement** in the agent schema | Caps the tail |
| 3 | Run researchers on `sonnet`, not `opus` | `model:` field | Large, on the cheapest-to-degrade leg |
| 4 | Write notes incrementally, append-only | Prompt: "append after each source" | Removes the loss cliff |
| 5 | Stage the work (see below) instead of 5-way parallel | Coordinator change | Spreads across rate windows |
| 6 | Cap parallelism at 2–3 concurrent | Coordinator change | Avoids burst limit |

### Three-stage design

- **Stage 1 — Scout.** 1 cheap agent (haiku/sonnet), ~8 tool calls, no fetches. Produces a ranked source list and sharpens the questions. Output: a short target list.
- **Stage 2 — Deep dive.** 2–3 agents on `sonnet`, `maxTurns: 20`, each given the *specific URLs* from stage 1 and 2 questions. No open-ended searching. Notes appended per source.
- **Stage 3 — Synthesize.** 1 agent (opus is fine here — it's one pass over notes, not 70 turns) writes the report from the notes files.

Stage 2 is where the quadratic cost lives, so that's where the hard caps go. Estimated total: **2–4M tokens vs 26M — roughly an 85–90% reduction** for comparable output quality.

## Note on this session

The direct main-thread research that replaced the fan-out used **8 web calls** and produced the accompanying design report. That is the cost profile to aim for.
