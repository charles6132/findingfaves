# Agent Build Spec — debugger / implementer / analyzer / scout / researcher

**Status:** all five agents are **written and committed**. Hooks are written and **validated against a real project** — see §7, plus a third hook script added since (§7.1). Three bugs were found and fixed across those validations.
**Read first:** `docs/research/debug-coding-agent-findings.md` for the evidence behind these choices.

---

## 1. What this is meant to do

A set of Claude Code subagents that make a codebase debuggable and changeable with discipline enforced by the harness rather than by good intentions:

- **`debugger`** — finds and *proves* the root cause of a defect. Produces a diagnosis. Does not fix.
- **`implementer`** — makes a change that is already understood, and verifies it before claiming done.
- **`analyzer`** — read-only structural understanding of unfamiliar code: what it does, how it is organised, where the risk is.
- **`scout`** / **`researcher`** — the two staged research agents, carrying harness-enforced turn caps (§5.5).

### The one structural decision that matters

**Diagnosis and repair are separate agents, and the debugger has no edit tools.**

The dominant failure mode of debugging agents is shortcutting to a plausible patch before the cause is established. Removing `Edit`/`Write` from the debugger's tool allowlist makes that *much harder* rather than merely discouraged. Note the honest limit: the debugger still has `Bash`, and `sed -i` is an edit — so this is a strong speed bump, not an impossibility. Earlier drafts of this document claimed the latter. This is the same principle as §7's hooks: constraints beat instructions.

**Evidence, with a caveat.** General multi-agent decomposition is *not* a free win — measured cost multipliers of 4–220x over single-agent, and both architectures sit at the top of leaderboards. But for debugging specifically the evidence runs the other way: the strongest interactive-debugging results come from *delegating debugging to a subagent* rather than having the main agent step through interactively. So this split is justified for the debug case on its own merits, not as a general architectural preference. **Do not generalize it into splitting everything into subagents.**

## 2. File layout

```
.claude/
├── agents/
│   ├── debugger.md          ✅ built
│   ├── implementer.md       ✅ built
│   ├── analyzer.md          ✅ built
│   ├── scout.md             ✅ built   (maxTurns: 10)
│   └── researcher.md        ✅ built   (maxTurns: 20)
├── hooks/
│   ├── verify-edit.sh       ✅ built + validated
│   ├── verify-done.sh       ✅ built + validated
│   ├── check-frontmatter.py ✅ built + validated
│   └── persist-memory.sh    ✅ built + validated
├── skills/                  ← from the desktop session; see agent-platform-skills.md
└── settings.json            ✅ wires both hooks

CLAUDE.md                    ← project memory; read this before the research docs

docs/research/
├── debug-coding-agent-findings.md
├── agent-platform-skills.md
└── agent-spec.md            (this file)

research_notes/Debug and coding agent design/   ← 254 KB of sourced research
reports/                                        ← earlier synthesis, partly superseded
```

## 3. `debugger` — built

**Path:** `.claude/agents/debugger.md`

```yaml
name: debugger
description: Root-cause analysis for bugs, test failures, crashes, and unexpected
  behaviour. Produces a verified diagnosis with a reproduction and evidence — it does
  NOT fix code. Use whenever something is broken and the cause is not already obvious,
  and before writing any fix.
tools: Read, Grep, Glob, Bash      # NO Edit/Write — deliberate
model: opus
effort: high
memory: project
color: red
```

**Tool allowlist rationale:** `Bash` is present so it can run tests, reproductions and a real debugger. `Edit`/`Write` are absent so it cannot patch. That asymmetry is the whole design.

**Prompt shape** (full text in the file): a seven-stage loop — reproduce → minimise → localise → hypothesise → confirm, with explicit prohibitions and a fixed output contract (Summary / Reproduction / Root cause / Evidence / Proposed fix / Regression test / Confidence).

**Key prompt content, and why:**
- *"Work backwards from the observable failure until you find the boundary where good input goes in and bad output comes out."* The single most useful localisation heuristic found in the research.
- *"If you cannot reproduce it, say so explicitly."* Gating on a validated reproduction is the defining feature of 2026-era debugging pipelines vs. 2024 ones.
- *"If the failure is intermittent, characterise the rate. 'Failed 3 of 20 runs' is a finding. 'It's flaky' is not."*
- Explicit bans on symptom-patching, stopping at the first plausible explanation, claiming unobserved causes, and recommending test deletion. These map to documented failure modes — ~1 in 5 "solved" patches from top agents is semantically wrong.
- Memory read at start, memory update at end.

**`memory: project`** writes to `.claude/agent-memory/debugger/`, persisting a bug-pattern library for this codebase across sessions. Measured effect of memory in the literature: **+3.9 to +5.25 pp**.

### `mcp-debugger` — attached

```yaml
mcpServers:
  mcp-debugger:
    command: npx
    args: ["-y", "@debugmcp/mcp-debugger@0.24.2", "stdio"]
```

A DAP-over-MCP step-through debugger, MIT, 8 languages (Python, Ruby, JS/TS, Rust, Go, Java, .NET, C/C++), 28 tools. The prompt's stage-3 evidence ladder now puts it first and demotes print-instrumentation to the fallback it should always have been.

**Verify the package name, do not assume it.** Two packages answer to this name on npm. `mcp-debugger` (v1.0.0, node >=14) is *a Postman collection runner* whose repository field still reads `github.com/yourusername/…`. The researched project is **`@debugmcp/mcp-debugger`** (v0.24.2, node >=22, `github.com/debugmcp/mcp-debugger`, "Step-through debugging MCP server for LLMs"). Installing the bare name would have been silent and wrong.

**Verified by handshake, not by reading the README.** `initialize` returns `debug-mcp-server` on protocol 2024-11-05 and `tools/list` returns 28 tools — `create_debug_session`, `set_breakpoint`, `start_debugging`, `attach_to_process` and the rest — matching the notes exactly. Requires Node 22+; the version is pinned deliberately at 0.x.

**On the +11–15 pp.** That figure is debug-gym's, for real debugger access in general. The notes are explicit that **mcp-debugger itself publishes no quantitative benchmarks**, and that no public head-to-head of a DAP MCP server against print-debugging inside the same agent was found. So the expected gain is an extrapolation from a different system, not a measurement of this one. The mechanism is sound and the cost is a config block; the number is borrowed.

## 4. `implementer` — built

**Path:** `.claude/agents/implementer.md`

```yaml
name: implementer
description: Implements a change that is already understood — a diagnosed bug fix, a
  specified feature, a refactor. Verifies its own work by running tests and linters
  before reporting done. Use when the WHAT is settled and the work is to make it real.
  Not for diagnosis; delegate that to the debugger agent first.
tools: Read, Grep, Glob, Bash, Edit, Write
model: opus
effort: high
memory: project
color: green
```

**Prompt shape:** six stages — understand → find blast radius → write the failing test first → make the narrowest change → verify → re-read the diff adversarially. Fixed output contract (What changed / Verification / Risk / Left undone).

**Hard rules in the prompt**, each mapping to a documented failure mode:
- Never delete, skip, disable or weaken a test to go green
- Never hardcode to the test *(test-overfitting is the best-quantified failure mode in the literature)*
- Never claim a verification you did not run
- Never report partial work as complete
- Never leave the tree broken

Plus scope discipline — no opportunistic refactors, no unrequested renames, no speculative abstraction.

**Consider adding `isolation: worktree`** for risky changes: runs in a throwaway git worktree, leaving the main checkout untouched. Not enabled by default because it complicates inspecting the result.

## 5. `analyzer` — built

**Path:** `.claude/agents/analyzer.md`

For "explain this codebase / assess this subsystem" work, where the failure mode is *confident summary of code the agent never opened*.

```yaml
name: analyzer
description: Read-only structural analysis of unfamiliar code — what a subsystem does,
  how it is organised, where the complexity and risk concentrate. Use before planning a
  change in unfamiliar territory. Produces a written map, not edits.
tools: Read, Grep, Glob        # no Bash — analysis, not execution
model: sonnet                  # breadth-first reading; opus is not needed
effort: medium
memory: project
color: cyan
```

**Output contract:** Purpose / Structure (entry points, key modules, data flow) / Dependencies / Risk areas (complexity, missing tests, sharp edges) / Open questions / Coverage.

**Prompt rules, and why:**
- **Cite `file:line` for every structural claim.** A claim that cannot be anchored is one the agent should not make.
- **Distinguish what was read from what was inferred.** "Presumably" and "appears to" are honest words; the prompt requires them where they apply and forbids dressing inference up as observation.
- **Report what was not looked at.** Coverage is part of the finding — an analysis of 8 of 40 modules is useful if it says so and misleading if it implies otherwise.
- **No refactor proposals.** It reports what is there; someone else decides what to do about it.
- **Hand runtime questions to the debugger.** With no `Bash`, questions needing execution get named as such rather than guessed at.

**Design note:** `sonnet` and no `Bash` are deliberate. Analysis is breadth-first reading; the expensive model buys little, and execution is not needed. If you find yourself wanting `Bash` here, the task is probably a debugger task.

## 5.5 `scout` and `researcher` — built

The two agents that make findings §5's staged research design real, and the
place where this repo finally stops writing budgets as prose.

```yaml
name: scout                    name: researcher
tools: WebSearch, Read,        tools: Read, Write, Glob,
  Write, Glob                    WebSearch, WebFetch, Bash
model: haiku                   model: sonnet
effort: low                    effort: medium
maxTurns: 10                   maxTurns: 20
```

**`maxTurns` is the whole point.** The incident in findings §3 happened because a
15-tool-call budget lived in a sentence while the scope handed out needed 40+.
Every one of the five agents chose the scope. `maxTurns` is enforced by the
harness — the agent is stopped and its output returned marked partial — so there
is nothing to reason past. Confirmed against the official frontmatter schema:
camelCase, no documented maximum, partial-marking needs v2.1.246+.

**Why scout has no `WebFetch`.** Fetched pages are what fill context, and context
is re-read every turn. Scouting needs breadth; search snippets rank a candidate
well enough. This is the same asymmetry as the debugger's missing `Edit` — the
tool allowlist enforces the design rather than describing it.

**Why the models differ.** All five agents in the incident ran on `opus`,
including the search-triage legs where a smaller model loses almost nothing.
Scout is triage, so `haiku`; researchers read and reason over sources, so
`sonnet`; the writer stays `opus` because it is one bounded pass, not seventy
turns of accumulation. The expensive thing was never the model, it was the turn
count.

**Both write early and rewrite.** The `researcher` prompt requires an evidence
file after the first fetch batch, rewritten after gap-fill — same filename, same
schema. That is findings §3 Bug B, fixed at the point where it actually bit.

**Not changed: the evidence JSON schema.** It is consumed by `merge_evidence.py`,
which is not in this repository (see §5.6), so the contract was preserved exactly
rather than improved blind.

### 5.6 What the research skills still cannot do here

`.claude/skills/research-agent/` shells out to `search.ps1`, `merge_evidence.py`
and `checkurls.ps1`. **Only `ENGINES.md` was committed** — the scripts live in
the desktop skills store, and two of them are PowerShell. The skill therefore
cannot run end to end from a Linux checkout. The skill now resolves an
`$ENGINES` directory instead of hardcoding one machine's absolute paths, and
says to stop with a clear message rather than improvising replacements for a
merger whose behaviour nobody here can read.

## 6. Delegation flow

```
Something is broken
   └─> debugger        (diagnose, prove, propose — no edits)
          └─> implementer   (implement the proposed fix, verify)

Unfamiliar code, no defect
   └─> analyzer        (map it) ──> implementer (change it)

Change already understood
   └─> implementer directly
```

Automatic delegation is driven **entirely by the `description` field**. Keep descriptions specific and behavioural — "Use whenever X and before Y" beats "Helper agent." Combined subagent descriptions over 15,000 tokens trigger a startup warning, so do not install large third-party agent packs alongside these.

## 7. Hooks — validated

✅ **Both hooks were executed against a purpose-built project (failing pytest suite, lint violations, a Go package with formatting and vet errors) on 2026-09-18. 14 cases across both scripts. Two real bugs were found and fixed; everything else behaved as designed.**

`.claude/settings.json` wires:

| Hook | Event | Matcher | What it does |
|---|---|---|---|
| `verify-edit.sh` | `PostToolUse` | `Edit\|Write\|NotebookEdit` | Per-file lint/typecheck after every edit; feeds failures back via `hookSpecificOutput.additionalContext` |
| `verify-done.sh` | `Stop` | (all) | Runs the project test suite; **exit 2 refuses to let the turn end** on red |
| `check-frontmatter.py` | via `verify-edit.sh` | `.claude/agents/*.md`, `*/SKILL.md` | Fails a silently-broken YAML frontmatter loudly — see §7.1 |
| `persist-memory.sh` | `SubagentStop` | (all) | Writes an agent's `## Memory` block to its memory file — see §7.2 |

**`verify-edit.sh`** — detects project type from the edited file's extension and the presence of `pyproject.toml` / `package.json` / `go.mod` / `Cargo.toml`. Runs only fast file-scoped checks (ruff, mypy, eslint, tsc, gofmt, go vet, cargo check, shellcheck), never the full suite, because it fires on every edit. Exits 0 always — `PostToolUse` cannot block, so the useful channel is context injection.

**`verify-done.sh`** — the important one. `Stop` + exit 2 means the agent **cannot end its turn while tests fail**. This is what turns "always run the tests" from a suggestion into a constraint.

**It has a circuit breaker and you must not remove it.** It blocks at most once per `prompt_id`, guarded by a marker file in `scratchpad_dir`. Without that guard, a genuinely unfixable failure loops forever. One block catches the "I think I'm done" reflex; beyond that a human should look.

It also no-ops when: not a git repo, no uncommitted changes, or no test command can be detected. Detection order: `package.json` scripts.test → `Cargo.toml` → `go.mod` → `pyproject.toml`/`pytest.ini`/`tox.ini`. 300s timeout.

### What validation confirmed

`verify-edit.sh` — surfaces ruff findings as `additionalContext`, stays silent on clean files, and exits 0 on a missing `file_path`, a nonexistent file, and a missing linter (shellcheck absent degraded gracefully).

`verify-done.sh` — exits 2 with the pytest output on stderr when the suite is red; **the circuit breaker holds** (a second Stop on the same `prompt_id` exits 0 and permits the stop); a new `prompt_id` blocks again as intended; exits 0 on a green suite, a clean tree, and a non-git directory.

### The two bugs, both in the Go branch of `verify-edit.sh`

1. **`gofmt -l` never fired.** It lists unformatted files on stdout but **exits 0**, so the `try` helper's exit-code test meant the check could never report anything. It was dead code from the day it was written. Now detects on non-empty output.

2. **`go vet` was handed a corrupted path.** The script built `"./$(dirname "$file")"`, but `file_path` arrives **absolute**, producing `.//tmp/…` — which resolved under the project dir into a path that does not exist. This was worse than a silent no-op: it injected a bogus `directory not found` error into the agent's context on *every* Go edit. Now passes the package directory absolutely.

Both were invisible to `bash -n`, which is exactly why the scripts needed to be run rather than read. The Python, TypeScript, Rust and shell branches were unaffected.

**Still untested:** the TypeScript/Rust branches (no such project was built), and both hooks under the real Claude Code harness rather than by piping JSON to them directly. The payload shapes used are the documented ones, but a live-harness run is still worth doing.

### 7.1 `check-frontmatter.py` — added and validated

The desktop session found that a bare `: ` inside an unquoted description broke
the frontmatter of five skills at once. Silently — no error, the skills still
listed, descriptions falling back to the body's H1. Since routing runs on
descriptions, all five would have mis-routed invisibly, looking like model
misbehaviour rather than a config bug. It was caught only because the rendered
list changed shape. **The same convention, and the same trap, applies to
`.claude/agents/*.md`.**

That session could not fix it without touching this branch's `verify-edit.sh`,
so it left the item open. It is now done: `verify-edit.sh` gained an `*.md`
branch that fires only for `.claude/agents/*.md` and `.claude/skills/*/SKILL.md`.

The checker uses PyYAML as the authority where it is installed and falls back to
targeted structural checks where it is not, because the desktop may not have it.
Beyond parseability it reports what a parser error does not — which key broke and
what to do about it — and catches a missing `name`/`description` and a `name`
that disagrees with its own path, since invocation goes by path.

**Validated by execution, 8 cases.** Caught the historical bug verbatim, an
unterminated block, a missing description, a name/path mismatch and a tab
indent; stayed silent on a quoted colon and on a block sequence; the hook emitted
`additionalContext` for a broken file and exited 0 for clean files, non-skill
markdown, a real repo agent, and a missing checker. One false positive surfaced
during validation and was fixed — a bare `tools:` introducing a block value is
legal YAML and was briefly flagged. Which is the §7 lesson twice over: the bug
was in the checking code, and only running it found that too.

### 7.2 `persist-memory.sh` — the memory the agents could not write

**The defect.** All three memory-enabled agents ended their prompts with an
instruction to update their agent memory. Two of them could not.

The docs say that with `memory` enabled, "Read, Write, and Edit tools are
automatically enabled so the subagent can manage its memory files" — but an
explicit `tools:` allowlist takes precedence, so an agent that omits `Write`
does not get it back. Which means:

| Agent | Tools | Could write its memory? |
|---|---|---|
| `implementer` | …`Edit, Write` | yes |
| `debugger` | `Read, Grep, Glob, Bash` | only via `Bash` — a route the design never intended |
| `analyzer` | `Read, Grep, Glob` | **no. At all.** |

The analyzer's closing instruction was a guaranteed no-op — the same silent
shape as the dead `gofmt` check in §7. Reading memory was never affected; the
harness injects `MEMORY.md` into the system prompt with no tool involved.

**The fix.** The harness writes it. Agents close their report with a `## Memory`
block; a `SubagentStop` hook extracts that block and appends it. No tool grant,
so the analyzer's read-only allowlist — the thing that makes it trustworthy —
stays intact. The agent decides *what* is worth remembering; the hook decides
*where* it goes.

Uses `last_assistant_message` and `agent_type` from the hook payload. Notably
the docs warn **against** reading `transcript_path` for this, since the
transcript is written asynchronously and can lag the turn that just ended — the
obvious implementation would have been intermittently empty.

**Entries are newest-first, deliberately.** Only the first 200 lines or 25 KB of
`MEMORY.md` is injected, so appending at the bottom would push new knowledge out
of the window as the file grew. Capped at 400 lines. `implementer` is excluded
from the hook because it has real `Write` and manages its own file.

**Validated by execution — 11 cases, and it found two bugs in itself.**

1. `set -o pipefail` plus a group ending in a bare `[ -n "$existing" ] && …`
   test. When the file did not yet exist the test was false, so the group exited
   1, `pipefail` failed the whole pipeline, the `|| exit 0` fired, and the `mv`
   never ran. The hook wrote a temp file, abandoned it, and exited 0. **The
   first run of a brand-new memory file silently did nothing.**
2. Trimming blank lines with `tac`. The block is printed without a trailing
   newline, so reversing it joined the last two lines into one and reversed
   their order — corrupting the entry while still looking plausible.

Both passed `bash -n`. Neither was visible by reading. Passing cases: block
extracted in order, stopped at the next heading rather than swallowing it,
newest entry on top, growth capped, and no write at all for a missing block, an
empty block, the excluded `implementer`, an unrecognised agent, a payload with
no message, an empty payload, and an `agent_type` containing `../` (refused
rather than escaping the memory directory).

## 8. What is deliberately NOT here

- **No large third-party agent pack.** The value of an agent definition is mostly project-specific knowledge, which cannot be downloaded — and a pile of vague `description` fields degrades automatic delegation and eats the 15,000-token description budget. Mine `wshobson/agents` (MIT) and `VoltAgent/awesome-claude-code-subagents` (MIT) for phrasing; do not install wholesale.
- **No plan/architect agent.** Claude Code has a built-in `Plan` agent.
- **No test-writer agent.** Test-writing belongs inside `implementer`'s loop, where it can watch the test fail first.

## 9. Open work, in priority order

1. **Ship the three engine scripts**, or port them — until then the research skills cannot run outside the desktop (§5.6). `merge_evidence.py` matters most; the two PowerShell scripts need a portable equivalent.
2. **Run the staged research design once, end to end, and measure it.** The 85–90% cost reduction is modelled. Now that the caps are harness-enforced, one real run turns it into a number.
3. **Redo the lost research leg** — published production system prompts and process patterns (see findings §7, `UNRECOVERABLE`). Use the staged design so it does not cost 26M tokens again.
4. **Exercise the hooks under the live harness**, and cover the TypeScript and Rust branches (see §7).
5. **Build an eval set** — needs ~50 merged PRs as a golden set, oracle hidden, run weekly. **Blocked: this repo has no merged PRs yet.** This is how you find out whether any of the above actually helps.

~~Execute the hooks against a real project~~ — done, §7.
~~Build `analyzer`~~ — done, §5.
~~Attach `mcp-debugger`~~ — done, §3. Package identity and the MCP handshake were both verified; the expected gain was not, and is flagged as borrowed.
~~Restructure the deep-research skill per findings §5~~ — done, §5.5. `maxTurns` caps, staged scout→researcher execution, and write-early-rewrite are all in place; the measurement in step 3 is what remains.
~~Add the frontmatter parse check to a hook~~ — done, §7.1 (this was open work item 4 in `agent-platform-skills.md`, deliberately left until the branches merged).

**Note on step 5:** nothing in this spec has been measured. The prompts encode findings from the literature, but whether *these* agents help *this* codebase is untested. The eval set is how that stops being a guess.
