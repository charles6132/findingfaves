# Agent Build Spec — debugger / implementer / analyzer

**Status:** debugger, implementer and analyzer are **written and committed**. Hooks are written and **validated against a real project** — see §7. Two bugs were found and fixed during that validation.
**Read first:** `docs/research/debug-coding-agent-findings.md` for the evidence behind these choices.

---

## 1. What this is meant to do

A set of Claude Code subagents that make a codebase debuggable and changeable with discipline enforced by the harness rather than by good intentions:

- **`debugger`** — finds and *proves* the root cause of a defect. Produces a diagnosis. Does not fix.
- **`implementer`** — makes a change that is already understood, and verifies it before claiming done.
- **`analyzer`** (not yet built) — read-only structural understanding of unfamiliar code: what it does, how it is organised, where the risk is.

### The one structural decision that matters

**Diagnosis and repair are separate agents, and the debugger has no edit tools.**

The dominant failure mode of debugging agents is shortcutting to a plausible patch before the cause is established. Removing `Edit`/`Write` from the debugger's tool allowlist makes that *structurally impossible* rather than merely discouraged. This is the same principle as §7's hooks: constraints beat instructions.

**Evidence, with a caveat.** General multi-agent decomposition is *not* a free win — measured cost multipliers of 4–220x over single-agent, and both architectures sit at the top of leaderboards. But for debugging specifically the evidence runs the other way: the strongest interactive-debugging results come from *delegating debugging to a subagent* rather than having the main agent step through interactively. So this split is justified for the debug case on its own merits, not as a general architectural preference. **Do not generalize it into splitting everything into subagents.**

## 2. File layout

```
.claude/
├── agents/
│   ├── debugger.md          ✅ built
│   ├── implementer.md       ✅ built
│   └── analyzer.md          ✅ built
├── hooks/
│   ├── verify-edit.sh       ✅ built + validated
│   └── verify-done.sh       ✅ built + validated
└── settings.json            ✅ wires both hooks

docs/research/
├── debug-coding-agent-findings.md
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

### Recommended addition — not yet done
Attach a **DAP/debugger MCP server** (`mcp-debugger`, MIT, 8 languages) via the `mcpServers` frontmatter field. Real debugger access is worth **+11–15 pp** on SWE-bench Lite. Without it the agent falls back to print-instrumentation, which the prompt already handles but which measures worse.

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

## 8. What is deliberately NOT here

- **No large third-party agent pack.** The value of an agent definition is mostly project-specific knowledge, which cannot be downloaded — and a pile of vague `description` fields degrades automatic delegation and eats the 15,000-token description budget. Mine `wshobson/agents` (MIT) and `VoltAgent/awesome-claude-code-subagents` (MIT) for phrasing; do not install wholesale.
- **No plan/architect agent.** Claude Code has a built-in `Plan` agent.
- **No test-writer agent.** Test-writing belongs inside `implementer`'s loop, where it can watch the test fail first.

## 9. Open work, in priority order

1. **Redo the lost research leg** — published production system prompts and process patterns (see findings §7, `UNRECOVERABLE`). Use the 3-stage design so it does not cost 26M tokens.
2. **Attach `mcp-debugger`** to `debugger` via `mcpServers` — the +11–15 pp lever, and the single highest-value upgrade left.
3. **Exercise the hooks under the live harness**, and cover the TypeScript and Rust branches (see §7).
4. **Restructure the deep-research skill** per findings §5 — `maxTurns` caps, incremental note-writing, staged execution.
5. **Build an eval set** — needs ~50 merged PRs as a golden set, oracle hidden, run weekly. **Blocked: this repo has no merged PRs yet.** This is how you find out whether any of the above actually helps.

~~Execute the hooks against a real project~~ — done, §7.
~~Build `analyzer`~~ — done, §5.

**Note on step 5:** nothing in this spec has been measured. The prompts encode findings from the literature, but whether *these* agents help *this* codebase is untested. The eval set is how that stops being a guess.
