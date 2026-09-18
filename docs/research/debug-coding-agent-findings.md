# Debug & Coding Agent Research — Findings

**Session:** 2026-09-17/18 · **Branch:** `claude/debug-coding-agent-research-boqnpx`
**Audience:** someone with zero prior context. Everything needed to act is in this file or in the files it points at.

---

## 1. What the research question was

Two questions, asked together:

1. **Substantive:** What is the state of the art (September 2026) in debugging agents and coding agents — which open-source repos are worth cloning, what architectures and process patterns work, what does the benchmark evidence actually support, and how do you build a best-in-class debug agent and coding agent on Claude Code specifically (subagents, skills, hooks, MCP)?
2. **Operational (arose mid-session):** The research process itself exhausted the account's token budget in ~8 minutes. Why, and how should it be restructured?

This document covers both. Question 2 is section 3 onward and is the more immediately actionable of the two.

## 2. What it drew on

**Method:** the `anthropic-skills:deep-research` skill spawned five parallel `general-purpose` subagents on `claude-opus-5`, each assigned one subtopic, each instructed to research via `WebSearch`/`WebFetch` and write notes to a file. A sixth "report writer" agent was planned but never ran.

**Primary evidence for the substantive findings** lives in this repo at `research_notes/Debug and coding agent design/` — **1,830 lines / 254 KB across 4 files**:

| File | Lines | Covers |
|---|---|---|
| `claude_code_implementation.md` | 960 | Claude Code schemas, read verbatim from official docs 2026-09-17 |
| `benchmarks_and_evidence.md` | 351 | Benchmarks, ablations, productivity studies |
| `open_source_coding_agents.md` | 293 | Repo inventory, GitHub API pulled live 2026-09-17 |
| `debugging_agents.md` | 226 | Debugging-specific research |

**Read those files for detail and citations.** This document is a synthesis; they hold the sourced findings, and each carries its own provenance caveat about which sources were fetched directly vs. summarized by the search tool.

**Primary evidence for the operational findings** is the subagent transcript telemetry, measured directly from the JSONL at
`~/.claude/projects/-home-user-findingfaves/<session>/subagents/agent-*.jsonl`. Those are ephemeral container files and are **not** in the repo; the numbers extracted from them are reproduced in section 4 and are the authoritative record.

## 3. The two bugs

### Bug A — the budget was prose, not a constraint

**Where it lived:** `references/researcher.md` in the `deep-research` skill, installed at
`~/.claude/skills/synced/<bundle-id>/deep-research/references/researcher.md`
(76 lines, ~1,055 tokens). Two passages carry the budget.

Under `## How to Research`, verbatim:

> `- Roughly 10 tool calls is typical; avoid exceeding 15 in order to provide timely responses and prevent timeouts`

And under `## When to stop`, verbatim:

> `- You're approaching or have hit 15 tool calls`

**Why it failed:** nothing enforces either sentence. It is advice addressed to a model that has simultaneously been handed a research scope it cannot satisfy in 15 calls. Given a conflict between "stay under 15 calls" and "answer these 9 key questions comprehensively," the model pursued the scope. Every one of the five agents overran:

| Agent | Tool calls | Turns | Over the stated 15-call budget |
|---|---|---|---|
| open-source coding agents | 53 | 78 | **+253%** |
| prompts / process patterns | 43 | 72 | +186% |
| debugging agents | 43 | 67 | +186% |
| Claude Code implementation | 42 | 66 | +180% |
| benchmarks and evidence | 38 | 52 | +153% |
| **total** | **219** | **335** | — |

**Root cause is shared, not solely the skill's.** The coordinator (this session) wrote research prompts with 7–9 key questions each, plus directives like *"cover at minimum"* followed by ~17 named projects, *"be generous with excerpts,"* *"dense,"* and *"comprehensive."* That scope is simply not a 10-tool-call task. The skill's guidance was sound; the invocation broke it.

**The fix is not a better sentence.** `maxTurns` exists in the subagent frontmatter schema and is enforced by the harness — the agent is stopped and marked resumable. Move the budget from prose into that field. This is the same principle as putting verification in hooks rather than in a system prompt: *a limit that the model can reason its way past is not a limit.*

### Bug B — write-on-end fragility

**What the pattern is.** Each research agent accumulates all of its findings **in its context window** across dozens of tool calls, then serializes everything to a notes file in a **single `Write` call as its final action**. There is no incremental persistence. For the entire run, all work product exists only as conversation context.

**What triggers it.** Any termination before that final write: a rate limit, an API error, a timeout, a crash, a user interrupt, or `maxTurns` being reached. The exposure window is the whole run — the agent is at maximum accumulated value and zero durable output right up until the last call.

**What gets lost.** On a kill before the write: *everything*. All searches, all fetched pages, all synthesis. There is no partial credit and nothing to resume from.

**What actually happened in this incident** — and this corrects an earlier, wrong assessment made in-session:

- All five agents were killed by the same `rate_limit` / HTTP 429 (`"You've hit your session limit · resets 10pm (UTC)"`), and all five returned `status: failed` with no result payload.
- The coordinator checked the notes directory at 18:00, found it empty, and concluded all work was lost. **That conclusion was incorrect.**
- Four of the five agents completed their writes, timestamped 18:00:58, 18:02:55, 18:03:35 and 18:05:33 — i.e. *after* the failure notifications were delivered. The 254 KB of notes described in section 2 survived and is in this repo.
- **One agent's output was lost entirely:** `prompts_and_process_patterns.md` was never written. That agent made 43 tool calls over 72 turns and produced nothing.
- **All five return summaries were lost.** The coordinator received failure notices rather than findings, which is why the loss was misjudged.

**So the accurate severity is: 1 of 5 legs lost outright (20%), plus all five hand-backs.** The fragility is real and the fix below still applies, but it is not the total-loss event it first appeared to be. The lesson is partly about the pattern and partly about **not diagnosing from a directory listing taken while the writers are still running.**

**Fix:** append notes per source rather than writing once at the end. `>>` after each fetch, not `>` at the finish. Cost is negligible; it converts a cliff into a gradient.

## 4. Measured cost evidence

All figures below are **measured**, summed from the `usage` records in the five subagent JSONL transcripts. They are not estimates.

| Metric | Value |
|---|---|
| Cache-read tokens | **26,036,649** |
| Cache-write tokens | 1,562,648 |
| Output tokens | **4,551** |
| Turns (5 agents) | 335 |
| Tool calls | 219 |
| Wall clock | ~8 min (17:52–18:01 UTC) |

**Read-to-write ratio: 5,720 : 1.**

Tool call breakdown: 75 `WebSearch`, 51 `WebFetch`, 48 `Bash`, 26 `Read`, 12 MCP (GitHub), 7 `ToolSearch`, 1 `Write`.

Per agent:

| Agent | Cache-read | Cache-write | Output |
|---|---|---|---|
| Claude Code implementation | 8,794,710 | 615,845 | 2,039 |
| open-source coding agents | 5,223,946 | 322,921 | 274 |
| prompts / process patterns | 5,086,544 | 227,143 | 1,004 |
| debugging agents | 4,101,135 | 167,592 | 1,054 |
| benchmarks and evidence | 2,830,314 | 229,147 | 180 |

### Why it is quadratic

Context size per turn, worst agent (`claude_code_implementation`):

```
turn  1:  40,828 tokens
turn  7:  45,441
turn 13:  48,858
turn 19: 117,443
turn 25: 136,438
turn 31: 154,770
turn 37: 170,021
turn 43: 193,360
turn 49: 202,819
turn 55: 205,773
turn 61: 213,965
```

Every turn re-reads the entire accumulated context. Tool results are appended and never evicted. **Total spend is the area under that curve, not its endpoint.** Roughly doubling the tool calls roughly quadruples the cost.

**The fixed-overhead term is the under-appreciated half.** Baseline context was ~40,828 tokens on turn 1 — system prompt, tool schemas, skill text — before any research happened. Multiply by 335 turns: **≈13.7M tokens, more than half the total burn, spent re-reading boilerplate.** Turn count is therefore the dominant cost lever, independent of how much each turn retrieves.

**Parallelism was not a token multiplier but was the proximate trigger.** Five concurrent agents compressed the whole burn into a single ~8-minute rate-limit window. The same work serialized might have stayed under the cap.

**Model choice compounded it.** All five ran on `claude-opus-5`, including the search-triage legs where a smaller model would lose little.

## 5. Recommended 3-stage architecture

Replace one-shot 5-way parallel fan-out with three staged phases. The design principle: **the quadratic cost lives in stage 2, so that is where the hard caps go.**

### Stage 1 — Scout
- **Count / model:** 1 agent, `haiku` or `sonnet`
- **Caps:** `maxTurns: 10`, `WebSearch` only, **no `WebFetch`**
- **Job:** map the territory, return a ranked list of specific URLs worth opening, and sharpen the research questions
- **Output:** a short target list (source URL + why + which question it serves), written incrementally
- **Why capped this way:** fetches are the expensive context-fillers. Scouting needs breadth, not depth, and search snippets are sufficient to rank candidates.

### Stage 2 — Deep dive
- **Count / model:** 2–3 agents, `sonnet`
- **Caps:** **`maxTurns: 20`**, max 2 key questions each, given the **specific URLs from stage 1** — no open-ended searching
- **Output:** notes **appended per source** (fixes Bug B)
- **Why capped this way:** this is where context accumulates fastest. `maxTurns: 20` is harness-enforced and caps the tail; handing over pre-selected URLs removes the search-flailing that produced most of the overrun.

### Stage 3 — Synthesize
- **Count / model:** 1 agent, `opus` is fine here
- **Caps:** `maxTurns: 10`, **no research tools** — reads the notes files only
- **Job:** write the report from stage-2 notes
- **Why opus is acceptable:** this is one pass over a bounded input, not 70 turns of accumulation. The expensive thing was never the model, it was the turn count.

### Supporting changes
- Cap concurrency at **2–3** agents, never 5.
- Scope each agent to **2–3 key questions**, never 7–9.
- Drop "comprehensive", "dense", "at minimum cover [long list]", "be generous" from prompts. Those phrases are what overrode the budget.
- Keep stage boundaries as real process boundaries so a rate limit costs one stage, not the run.

### How the 85–90% estimate was derived

**This is a modelled estimate, not a measurement.** The model:

Cost ≈ Σ(context size at each turn). After the flat opening, growth is roughly linear, so the sum approximates a triangle: `½ × turns × peak_context`.

*Observed:* ~67 turns avg, ~214K peak → `½ × 67 × 214K ≈ 7.2M` per agent × 5 ≈ 36M. Actual measured total was 27.6M (cache-read + cache-write), lower because the first ~15 turns stay flat near 41K rather than growing linearly. The model is therefore correct in shape and conservative by roughly 25%.

*Proposed:* stage 2 at `maxTurns: 20` with pre-selected URLs. Fewer turns and fewer accumulated fetches put peak context near ~90K → `½ × 20 × 90K ≈ 0.9M` per agent × 3 agents ≈ **2.7M**. Adding stages 1 and 3 (both small, capped, and cheap-model) adds a few hundred K.

`≈3M / 27.6M ≈ 11%` → **~89% reduction**, hence the 85–90% band.

**Caveats on the estimate:** the triangle model ignores prompt-cache pricing (cache reads are billed below input rate, so dollar savings and token savings differ), assumes peak context scales with turn count roughly linearly, and has not been validated by running the staged design. Treat 85–90% as a design target to verify, not a promise.

**Calibration datapoint:** after the fan-out died, the same research was redone directly on the coordinator thread using **8 web calls**, and produced the report at `reports/Debug and coding agent design.md`. That is the cost profile to aim for.

## 6. Substantive findings

Condensed from the notes files. **Each claim below is sourced in those files — go there before acting on any of it.** Several of these contradict widely-repeated assumptions, including some in this repo's earlier `reports/Debug and coding agent design.md`, which was written before the notes were recovered and is superseded where they disagree.

### Benchmarks

- **SWE-bench Verified is saturated and no longer a frontier signal** — 95–96% band (Claude Opus 5 at 96%), and formally abandoned by OpenAI as a frontier measure. Successors: SWE-bench Pro, SWE-bench-Live, SWE-rebench V2, Terminal-Bench 2.x.
- **The dominant criticism is now test insufficiency, not contamination** — benchmark test suites pass incorrect patches at double-digit rates.
- **Vendor-aggregate vs. standardized-harness numbers diverge by ~19 pp on the same benchmark** (SWE-bench Pro: ~80–81% vendor-aggregate vs **61.5%** on Scale's standardized public run, **51.5%** private split). Treat any single reported score as meaningless without its harness.
- **Harness ≈ model in importance.** Claw-SWE-Bench measures model choice at **29.4 pp** and harness choice at **27.4 pp** on the same benchmark. Report model+harness as one tested solver.

### Scaffold techniques, by measured effect

- Context management strategy: **up to +21 pp** — but compaction can *hurt* by ~15 pp vs. truncation in some regimes
- Tool/adapter interface design: **+54.3 pp** in one extreme case
- Retrieval / localization quality: **+4.7 to +6.2 pp**
- Memory: **+3.9 to +5.25 pp**
- Best-of-N with a verifier: **+2.1 pp** over mean pass@1 (59% best@16 vs 71% pass@16 — the selector leaves a lot on the table)
- **More reasoning budget lowered accuracy in 21 of 36 tested settings.** Test-time compute is not monotonically good.

### Sub-agents — a caution that cuts against the obvious design

**Multi-agent does not beat single-agent on cost-adjusted issue resolution.** Measured cost multiplier is **4–220x** (realistic ~15x, optimized 2–12x), and both architectures appear at the top of leaderboards. The reported differentiator is context quality, not agent count. Sub-agents are defensible where sub-tasks are genuinely parallel and need no coordination.

**However** — for debugging specifically, the evidence points the other way: the strongest interactive-debugging results come from *delegating debugging to a subagent* rather than letting the main agent step interactively. So the split proposed in `agent-spec.md` is supported for the debug case, and should be justified case-by-case rather than adopted as a general principle.

### Debugging

- **Canonical 2026 pipeline:** reproduce → **validate the reproduction** → localize (static + runtime evidence) → hypothesize → instrument at runtime → patch → verify against both the reproduction and the pre-existing suite. The 2026 distinguishing feature is that **patching is gated on a validated reproduction**.
- **Real debugger access is worth +11–15 pp** on SWE-bench Lite (debug-gym), **>20% relative** on GitBug-Java/SWE-Bench-Live (Debug2Fix). Structured execution-trace access (ADI) took a *basic* agent to 63.8% on SWE-bench Verified at $1.28/task. Naive debugger access alone is not enough.
- **Reproduction-test generation is its own discipline** (SWT-bench), best systems ~89% on SWT-bench Lite in reproduction-script mode.
- **~1 in 5 "solved" SWE-bench patches from top agents is semantically wrong**, inflating leaderboards by ~6 pp. Mitigations: differential patch testing (PatchDiff), explicit anti-test-tampering prompt rules, risk-aware metrics.
- Pure SBFL is no longer competitive standalone but survives as a retrieval/pruning prior.
- **Bisection/delta-debugging is the least mature area** — no source found showing a leading agentic system measurably improving root-cause accuracy via automated bisection on a standard benchmark.

### Open-source landscape

- **The 2024–25 canon has been reordered.** Aider, SWE-agent, Roo Code, Continue, Cody, Agentless, Moatless are archived, stalled, or superseded. A new tier of TypeScript/Rust harnesses — **OpenClaw, DeepSeek Harness, Hermes Agent, OpenCode, Pi** — has absorbed the community. Still actively developed and reusable: OpenHands, Codex CLI, Gemini CLI, Cline, Goose, Kilo Code, mini-SWE-agent.
- **Two architectural camps:** "bash is the only tool" minimalism (mini-SWE-agent) vs. large typed tool registries with compaction agents (opencode, Codex, Cline, OpenHands). The live disagreement is context compaction and state management, not tool sets.
- **The transferable ideas are about *constraining* the model,** not adding capability: Agentless's fixed pipeline, SWE-agent's ACI, Aider's repo map, Codex's process-tree sandbox, opencode's read-only plan agent, OpenHands's event sourcing.
- Licensing is mostly MIT/Apache-2.0 so lifting is straightforward. Exceptions: **OpenClaw has no recognized SPDX license**; prompt-aggregation repos are often GPL-3.0.
- Highest-value debugging repos: **debug-gym** (MIT), **swt-bench** (MIT), **mcp-debugger** (DAP-over-MCP, 8 languages, MIT), Delve's **mcp-dap-server**, **ChatDBG**.

### Claude Code platform (verified against official docs 2026-09-17)

- Subagent frontmatter has grown to ~16–18 fields. The ones that change what is buildable: **`memory`** (persistent cross-session), **`isolation: worktree`**, **`maxTurns`**, **`skills`** (preload), **`effort`**, per-agent **`hooks`** and **`mcpServers`**.
- **Custom slash commands have been merged into skills.** `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both produce `/deploy`; the docs page for slash-commands now redirects to the skills page (verified byte-for-byte identical). `.claude/commands/*.md` still works, described as "the older format," supporting the same frontmatter **except `name` and `paths`**.
- **33 documented hook events** and five handler types (`command`, `http`, `mcp_tool`, `prompt`, `agent`). `PostToolUse` is what makes a self-verifying coding agent possible.
- **Autonomy no longer requires `--dangerously-skip-permissions`:** auto mode (background classifier), the sandboxed Bash tool (Seatbelt on macOS, bubblewrap+socat on Linux/WSL2), and `permissions.allow/ask/deny`.
- Highest-value debugging MCP servers: Chrome DevTools MCP (official Google), Playwright MCP (official Microsoft), Serena and mcp-language-server (LSP), mcp-debugger (DAP), GitHub MCP, Sentry MCP.
- CLAUDE.md target is **under 200 lines per file**; `.claude/rules/` gives path-scoped rules that load on demand.
- Most clonable collections: `wshobson/agents` (MIT, now a multi-harness plugin marketplace), `VoltAgent/awesome-claude-code-subagents` (100+ subagents, MIT), `anthropics/skills` (authoritative), `anthropics/claude-plugins-official`.

### Productivity — the uncomfortable result

- **METR's RCT found a 19% slowdown** for experienced open-source developers (early 2025); the 2026 follow-up found **18% slowdown** for 10 returning developers. METR then **abandoned the design** because developers would no longer work without AI, making a control group impossible.
- **DORA 2026:** near-universal adoption, gains in productivity and satisfaction, but **negative effects on delivery throughput and stability**.
- **Stack Overflow 2026:** adoption rising, trust collapsing — **3% "highly trust" AI code**.

### Evals

Replay **your own last ~50 merged PRs** as a golden set. Score on multiple dimensions, not pass/fail. Run weekly in CI. **Hide the oracle** — the "Building to the Test" result makes oracle-hiding the single most important design decision, because agents that can see the tests will satisfy the tests without delivering the feature.

## 7. Dead ends, gaps and caveats

- **`prompts_and_process_patterns.md` is UNRECOVERABLE.** That research leg (published production system prompts, Anthropic's own agent-building guidance, spec-driven development, context-engineering practice, prompting anti-patterns) produced 43 tool calls of work and wrote nothing. It is the one genuinely lost deliverable and the most obvious thing to redo first.
- **Network egress was heavily restricted in the research environment.** `arxiv.org`, `openreview.net`, `huggingface.co`, `metr.org`, `swtbench.com`, `openai.com`, `tbench.ai` and most vendor blogs were blocked by the proxy. A large share of the numbers in section 6 come from **search-engine summaries of blocked pages rather than direct reads**. The notes files mark these `[via search summary]`. **Re-verify any number before relying on it externally.**
- **Benchmark figures are aggregator-reported** (benchlm.ai, llm-stats.com, morphllm.com, codesota.com, steel.dev) and weaker than official leaderboards.
- **Vendor accuracy claims for observability debugging agents are self-reported marketing numbers.**
- **The 85–90% cost-reduction figure is modelled, not measured.** See section 5 for the derivation and its assumptions.
- **`reports/Debug and coding agent design.md` is partly superseded.** It was written from the coordinator's own limited research after the fan-out died and before the notes were found. Where it disagrees with the notes files, the notes win — notably on SWE-bench saturation, on the cost-effectiveness of sub-agent architectures, and on the value of the community agent collections (it is more dismissive of `wshobson/agents` and VoltAgent than the evidence supports).
- **The earlier `reports/Research agent postmortem.md` overstated the work loss** as total. Section 3 of this document is the corrected account.
- **Nothing here has been validated by running it.** The staged research design, the cost estimate, and the agent definitions in `.claude/agents/` are all untested.
