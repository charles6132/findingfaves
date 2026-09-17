# Debug and coding agent design

**Research date:** 2026-09-17
**Repo:** charles6132/findingfaves — empty at time of writing (no commits, no remote branches)
**Status of prior work:** No debug or coding agent exists in this repo or in this cloud environment. `~/.claude/agents/` does not exist; the only installed skills are the stock Anthropic pack. Any earlier agent was built in a local CLI session (most likely "Agent platform skills", 2026-09-17 17:23 UTC) and lives on the local machine, not here.

---

## 1. The headline finding

The Claude Code extensibility surface has expanded substantially, and most of what is written online about building Claude Code subagents is **out of date**. The subagent frontmatter schema alone now carries ~18 fields that did not exist in the widely-copied 2025 tutorials.

The three that change what is buildable:

| Field | What it unlocks |
|---|---|
| `memory: project` | The agent gets a **persistent memory directory** (`.claude/agent-memory/<name>/`) that survives across sessions. A debug agent can accumulate a bug-pattern library for your codebase over time. This is the single biggest upgrade. |
| `isolation: worktree` | The agent runs in a **temporary git worktree**, branched off, isolated from your working checkout. A coding agent can attempt a risky fix without touching your files. |
| `skills:` (preload list) | Full skill content is injected at subagent startup — so a debug agent can boot with your project's conventions already loaded, rather than discovering them. |

Plus: `effort` (per-agent reasoning budget), `mcpServers` (inline per-agent MCP definitions), `hooks` (agent-scoped lifecycle hooks), `disallowedTools`, `maxTurns`, `omitClaudeMd`, and `experimental.cacheTtl`.

**Recommendation in one line:** don't clone somebody's 2025 agent pack. The community collections are mostly prompt-only files written against the old schema; the leverage is in the new fields, and those you have to write yourself.

---

## 2. Verified current schemas (September 2026)

Source: <https://code.claude.com/docs/en/sub-agents>, <https://code.claude.com/docs/en/hooks>, <https://code.claude.com/docs/en/skills>
(Note: docs moved from `docs.claude.com/en/docs/claude-code/*` to `code.claude.com/docs/en/*` — old links 301.)

### 2.1 Subagent frontmatter — full field list

```yaml
---
name: <string>                # required. lowercase+hyphens. no ':'. this is the identity, not the filename
description: <string>         # required. drives AUTOMATIC delegation — this is the most important field
tools: <comma-separated>      # allowlist. omit = inherit everything. e.g. "Read, Grep, Glob, Bash"
disallowedTools: <list>       # denylist, applied to inherited pool. supports mcp__<server> patterns
model: sonnet|opus|haiku|fable|<full-id>|inherit
permissionMode: default|acceptEdits|auto|dontAsk|bypassPermissions|plan|manual
maxTurns: <number>            # agent marked partial + resumable when hit
skills: [<skill-name>, ...]   # full skill content preloaded at startup
mcpServers: [<name>|<inline>] # per-agent MCP servers
hooks: <object>               # agent-scoped PreToolUse / PostToolUse / Stop
memory: user|project|local    # PERSISTENT memory dir across sessions
background: <bool>
omitClaudeMd: <bool>
effort: low|medium|high|xhigh|max
isolation: worktree           # run in a throwaway git worktree
color: red|blue|green|yellow|purple|orange|pink|cyan
initialPrompt: <string>       # auto-submitted first turn when run via --agent
experimental:
  cacheTtl: 5m|1h
---
Markdown body = the system prompt.
```

**Locations, in priority order:** managed settings > `--agents` CLI flag > `.claude/agents/` (project) > `~/.claude/agents/` (user) > plugin `agents/`. Both agent dirs are scanned **recursively**, so you can organise into subfolders.

**Silent-skip traps** (file is ignored, no error shown in session):
- missing `name` or missing `description`
- opening `---` not on line 1
- `name` starting with `-` or containing `:`
- any YAML parse error

Validate before you rely on it: `claude plugin validate .claude/agents`

**Tool inheritance:** subagents inherit the main conversation's tools minus a fixed blocklist (`AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode`, `ScheduleWakeup`, `TaskOutput`, `Workflow`, `EndConversation`, `WaitForMcpServers`, and `Agent` at depth limit). Background subagents are further restricted to a fixed built-in set plus all MCP tools. Resolution order: `disallowedTools` applied first, then `tools` resolved against what remains.

**What loads at subagent startup:** your markdown body as system prompt, the delegation task message, the full CLAUDE.md hierarchy (unless `omitClaudeMd: true`), a git status snapshot, and any preloaded `skills`. What does **not** load: conversation history, prior tool calls, output style. That context isolation is the whole point.

### 2.2 Hooks — the events that matter for self-verification

The hook event list is now ~33 events. The ones that matter for a self-verifying coding agent:

| Event | Use |
|---|---|
| `PostToolUse` | **Run the linter/tests after every edit.** This is the core self-verification mechanism. |
| `PostToolUseFailure` | Fires when a tool call *fails* — feed the error back as context. |
| `PostToolBatch` | Fires after a batch of parallel calls resolves — cheaper than per-call for formatting. |
| `PreToolUse` | Block dangerous commands before they run (exit 2 = block). |
| `Stop` | **Prevents the agent from stopping** (exit 2). This is how you stop "I think I'm done" when tests are still red. |
| `SubagentStart` / `SubagentStop` | Instrument delegation. |
| `SessionStart` | Boot the dev environment / install deps. |
| `TaskCompleted` | Gate task completion on a real check. |

Handler types are no longer just shell commands — `type` can be `command`, `http`, `mcp_tool`, `prompt`, or `agent`. A `prompt`/`agent` hook runs an LLM call on a fast model as the hook, which is a genuinely new capability (e.g. an LLM-judge gate on every Stop).

**Control semantics:**
- exit 0 = success; JSON on stdout parsed for decisions
- exit 2 = **blocking error**; blocks on `PreToolUse`, `UserPromptSubmit`, `Stop`, `PreModelSwitch`, `WorktreeCreate`/`Remove`
- anything else = non-blocking error, action proceeds

**Decision JSON:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|block",
    "permissionDecisionReason": "why",
    "updatedInput": { "command": "modified" },
    "additionalContext": "injected into Claude's context",
    "systemMessage": "shown to Claude"
  }
}
```

`updatedInput` is worth noting — a hook can **rewrite** a tool call rather than just block it.

### 2.3 Skills — when to use instead of a subagent

Skills now support `context: fork`, which runs the skill in an isolated subagent — blurring the old skill/subagent line. Current guidance:

| Need | Use |
|---|---|
| Inline knowledge, conventions, API details | Skill, no fork (stays in context) |
| Multi-step task with side effects (`/deploy`) | Skill + `disable-model-invocation: true` |
| Isolated research or code review | Skill + `context: fork` + `agent: Explore` |
| Background knowledge Claude pulls when relevant | Skill + `user-invocable: false` |
| Task needing the full conversation history | Subagent via `/fork` |
| Reusable specialist with its own memory + tool limits | **Subagent** |

Keep `SKILL.md` under 500 lines; put the rest in sibling files and link them (progressive disclosure). Only six frontmatter fields are portable to the agentskills.io open standard: `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`.


---

## 3. What the research says actually makes a debug agent good

### 3.1 Interactive debugging beats print statements

Microsoft Research's **debug-gym** (<https://github.com/microsoft/debug-gym>, **MIT licence**) is the reference implementation here. It gives an LLM agent a real interactive debugger rather than making it reason from stack traces alone. Tool set: `pdb` (with persistent breakpoints), `bash`, `eval` (run pytest), `view`, `edit`, `grep`, `listdir`, `submit`.

Why it matters: the core insight is that post-mortem debugging is **coarse-grained** — the agent sees a stack trace and guesses. An interactive debugger gives **fine-grained, dynamic program state**: actual variable values at the actual moment of failure. Related line of work: **ChatDBG**, which has an LLM agent autonomously drive `gdb`/`pdb` to answer a developer's high-level questions.

debug-gym also now supports **registering tools from external MCP servers** — it merges an external tool's action space into its own. That is directly relevant to us: it means the debug-gym pattern is portable to a Claude Code agent with a debugger MCP server attached.

**Reusable from it:** the modular tool architecture, the Jinja prompt templates, the Docker/Kubernetes sandbox backends, and the `RepoEnv` Gymnasium environment if you ever want to *evaluate* your own agent. MIT, so lift freely.

### 3.2 The canonical debugging loop

Converging across the research and practitioner sources, the disciplined loop is:

1. **Reproduce** — get a deterministic failing case first. No repro, no fix.
2. **Minimise** — shrink to the smallest input that still fails (delta debugging, `git bisect`).
3. **Localise** — find the first point where valid input produced wrong output. *Work backwards from the failure until you find the first span that received good input and still emitted bad output.* That framing is the most useful single heuristic I found.
4. **Hypothesise** — state a falsifiable cause before touching code.
5. **Instrument** — breakpoint or log to confirm or kill the hypothesis. Do not skip to the fix.
6. **Fix** — narrowest change that addresses the cause, not the symptom.
7. **Regression-test** — *convert the failure into a permanent test case.* A debugging workflow is incomplete without this step; every fixed bug should become a test that prevents recurrence.

Step 7 is the one that's most often dropped and most valuable — it's what turns debugging from firefighting into a ratchet.

### 3.3 Known failure modes to prompt against

These are the documented ways debugging agents go wrong, and each needs an explicit counter-instruction in the system prompt:

- **Symptom-patching** — fixing the assertion rather than the cause
- **Test-overfitting / reward hacking** — special-casing the exact test input, hardcoding expected values
- **Test deletion or skipping** — making red go green by removing the check
- **Hallucinated fixes** — plausible patch, never actually verified against a run
- **Premature completion** — declaring success without executing anything
- **Non-determinism confusion** — agentic/LLM systems fail non-reproducibly, so "it passed once" is not evidence

### 3.4 Benchmarks — context, with a large caveat

Top **SWE-bench Verified** scores as of Sept 2026 are in the 90s (one tracked run of Claude Opus 5 at ~97%, dated 2026-09-04; Fable 5 ~95% as of 2026-08-02). Treat these numbers as **directional only** — the benchmark is mature, heavily represented in training data, and recent audits argue top-end scores carry serious contamination and test-design caveats. There is an active 2026 literature arguing coding benchmarks are outright misaligned with real agentic software engineering.

**Practical implication:** do not tune your agent against SWE-bench. Build a small internal eval set from *your own* historical bugs — that is the advice that survives the criticism. Each bug you fix becomes both a regression test and an eval case.

---

## 4. Recommended architecture

Two agents, deliberately different in shape:

### Agent A — `debugger` (diagnosis, not repair)

The key design decision: **make it read-mostly.** Its job is to produce a verified root-cause diagnosis, not to fix things. This is the highest-leverage choice available, because the dominant failure mode of debugging agents is jumping to a plausible patch. Removing `Edit`/`Write` from the tool list makes that structurally impossible rather than merely discouraged.

- `tools: Read, Grep, Glob, Bash` — Bash for running tests/repros/debugger, no edit tools
- `memory: project` — accumulates a bug-pattern library for this codebase across sessions
- `effort: high` — root-causing is exactly where reasoning budget pays
- `model: opus`
- Output contract: a written diagnosis (repro, evidence, root cause, proposed minimal fix, proposed regression test) handed back to the main thread

### Agent B — `implementer` (repair, with verification)

- Full edit tools, plus `isolation: worktree` when the change is risky
- Backed by a **`PostToolUse` hook** that runs the linter/tests on every edit — verification enforced by the harness, not by the agent's good intentions
- Backed by a **`Stop` hook** that exits 2 if tests are red — the agent physically cannot end its turn on a broken build
- `memory: project` — accumulates project conventions

### The critical structural insight

Separating these two is not organisational tidiness — it's the mechanism. A single agent that can both diagnose and edit will, under pressure, shortcut to editing. Splitting diagnosis into a tool-restricted agent enforces the discipline that the research says matters most.

And the hooks matter more than the prompts. A prompt saying "always run the tests" is a suggestion; a `Stop` hook returning exit 2 is a constraint. **Put your verification in hooks, not prose.**

---

## 5. What's worth cloning (and what isn't)

### Worth it

| Repo | Licence | Why |
|---|---|---|
| [microsoft/debug-gym](https://github.com/microsoft/debug-gym) | MIT | The interactive-debugging tool design, the prompt templates, and the eval environment. The single most directly relevant repo. |
| [anthropics/skills](https://github.com/anthropics/skills) | — | Official skill examples; correct against the current schema. |
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | — | Best-curated index for finding specific things. Use as a directory, not a dependency. |

### Treat with caution

The large community collections — [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) (~388 skills, 5.2k stars), [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) (1000+ skills), and the various `*/agents` collections (~28-50 subagents each) — are **volume plays**. They are largely prompt-only markdown written against the older, simpler schema. None of the ones surveyed exploit `memory`, `isolation`, agent-scoped `hooks`, or `skills` preloading.

Blunt assessment: **a 388-skill collection is not 388 times better than 3 skills you wrote for your own codebase.** The value of an agent definition is mostly in the project-specific knowledge inside it, which by definition cannot be downloaded. Mine these for phrasing ideas; do not install them wholesale — a large pile of vague `description` fields actively degrades automatic delegation, and the docs warn that combined descriptions over 15,000 tokens trigger a startup warning.

### MCP servers worth attaching to a debug agent

- A **debugger/DAP** MCP server — gives the agent real breakpoints and variable inspection (the debug-gym capability, in Claude Code)
- **Playwright MCP** (`npx -y @playwright/mcp@latest`) — for anything browser-facing; can be declared inline in agent frontmatter
- **Sentry / observability MCP** — production stack traces as first-class input
- **GitHub MCP** — already available in this environment
- A **language-server/LSP** MCP — real go-to-definition and find-references beats grep for localisation

---

## 6. Recommendations

1. **Write your own two agents rather than installing a pack.** The schema features that matter are new enough that the packs don't use them.
2. **Split diagnosis from repair.** Tool restriction is the enforcement mechanism.
3. **Put verification in hooks.** `PostToolUse` to lint/test on edit; `Stop` with exit 2 to prevent finishing on red. Prose instructions are not constraints.
4. **Turn on `memory: project` for both.** This compounds — it's the difference between an agent that's equally naive every session and one that learns your codebase's failure patterns.
5. **Build an eval set from your own bugs, not from SWE-bench.** Every bug fixed becomes a regression test and an eval case.
6. **Don't tune on public benchmark scores.** The 2026 literature is clear that they're contaminated and misaligned with real work.

## 7. Caveats on this research

- The five-way parallel research fan-out for this report was killed by a session rate limit before any agent wrote its notes. What's above was reconstructed on the main thread from direct primary sources — the official docs (fetched and verified) and targeted searches.
- The Claude Code schema sections are **high confidence**: fetched verbatim from current official docs.
- The benchmark figures are **low confidence as absolute numbers** — reported via aggregator summaries, not verified against primary leaderboards, and contaminated in any case. They're included for context, not for decisions.
- Not covered for lack of budget: a deep survey of open-source coding-agent harness internals (SWE-agent, OpenHands, Aider, Cline architectures), published production system prompts, and controlled ablations on scaffold techniques. These were the four killed research legs and remain open.
