# findingfaves — working notes for Claude

This repository currently holds **no product code**. What it holds is an agent
platform: subagent definitions, verification hooks, research skills, and the
sourced research behind each of those choices. Read this file first; it exists
so you do not have to re-read 250 KB of notes to find out what was already
decided and why.

## Where things are

| Path | What it is |
|---|---|
| `.claude/agents/` | `debugger`, `implementer`, `analyzer`, plus `scout` and `researcher` for staged research — built, wired, unmeasured |
| `.claude/hooks/` | `verify-edit.sh` (PostToolUse), `verify-done.sh` (Stop), `check-frontmatter.py` |
| `.claude/skills/` | `research-agent` (narrative), `research-compare` (matrix), `research-engines/` (shared reference, no SKILL.md on purpose) |
| `.claude/skills/defrag/` + `wrap/` | weekly review and end-of-session card update; `registry.py` holds the mechanics |
| `.claude/skills/_archive/` | retired skills, nested two levels deep so they are not discoverable |
| `docs/projects/` | project registry — cards, `_archive/`, and `registry.py` mechanics; see its README |
| `docs/research/agent-spec.md` | **authoritative** on the agents and hooks |
| `docs/research/debug-coding-agent-findings.md` | **authoritative** on the evidence and the token-cost incident |
| `docs/research/agent-platform-skills.md` | **authoritative** on skills and on what the local model router can actually reach |
| `research_notes/` | 254 KB of sourced research with per-file provenance caveats |
| `reports/` | earlier synthesis, **partly superseded** — where it disagrees with `research_notes/`, the notes win |

## Projects

Generated — run `python3 .claude/skills/defrag/registry.py index --write`, do not
hand-edit. Cards live in `docs/projects/`; only these lines are loaded per turn.
The weekly `defrag` skill decides what belongs here.

<!-- projects:begin -->
- **agent-platform** — Subagents, verification hooks and research skills, plus the sourced research behind each choice. · `docs/projects/agent-platform.md`
- **calgary-permits** — Rank Calgary builders by permit volume to produce a B2B call list from delivery-route overlap. · `docs/projects/calgary-permits.md`
- **hermes** — Hermes agent — post-install configuration, OmniRoute integration, and session-notes sync to the vault. · `docs/projects/hermes.md`

**Archived** (1) — not loaded; each carries a reopen condition in `docs/projects/_archive/`: `claude-md-file`
<!-- projects:end -->

Three branches fed this line of work and were consolidated here: the cloud
sessions contributed agents and hooks, the desktop session contributed skills.
They were kept file-disjoint by design, so the merge was clean.

## The rules this repo learned the hard way

Each of these came from something that actually broke. They are worth more than
the artifacts they produced.

1. **A limit the model can reason past is not a limit.** A research skill carried
   a 15-tool-call budget in prose while handing out a scope that needed 40+.
   All five agents overran it, by 153–253%, and burned 26 M cache-read tokens in
   eight minutes. Budgets belong in `maxTurns`, verification belongs in hooks —
   not in sentences addressed to the model.
2. **A constraint you have not executed is not a constraint.** Both hooks passed
   `bash -n` and still carried two real bugs — `gofmt -l` exits 0 so its check
   could never fire, and `go vet` was handed a path that resolved nowhere and
   injected a phantom error into the agent's context on every Go edit. Reading
   found neither. Running found both.
3. **Broken YAML frontmatter fails silently and mis-routes everything.** A bare
   `: ` inside an unquoted description broke five skills at once with no error;
   descriptions fell back to the body H1, and routing is driven by descriptions.
   `check-frontmatter.py` now runs on every edit to a `SKILL.md` or an agent
   file. Do not remove it, and prefer rewording over quoting.
4. **A capability claim written by the thing that built it is not evidence.** A
   skill's frontmatter claimed to supersede five others. It had absorbed one.
   Verify by diffing capability against capability, never by comparing
   descriptions.
5. **Write incrementally, not at the end.** Agents that hold everything in
   context and serialize once as a final action lose all of it to any early
   termination. One research leg died exactly this way. Append per source.
6. **Cost is the area under the context curve, not its endpoint.** Every turn
   re-reads the whole accumulated context, so doubling tool calls roughly
   quadruples spend, and ~40 K of fixed overhead per turn dominated over half of
   that incident's burn. Turn count is the lever, not model choice.
7. **Do not diagnose from a directory listing while the writers are still
   running.** An earlier postmortem called the work a total loss. Four of five
   agents had in fact written their notes, after the failure notices arrived.

## Turn count is the budget

`scout` (10) and `researcher` (20) carry `maxTurns` in their frontmatter, where
the harness enforces it. Prose budgets in a skill body are advice; these are not.
If you change a cap, change it in both the agent file and the skill that
dispatches it — `.claude/skills/research-agent/SKILL.md` repeats them.

The `debugger` agent has `mcp-debugger` attached over stdio for real
step-through debugging. It is `@debugmcp/mcp-debugger` — **not** the bare
`mcp-debugger` on npm, which is an unrelated Postman runner. Requires Node 22+.

## Agent memory — and why it must be committed

`debugger`, `implementer` and `analyzer` all declare `memory: project`, which
persists to `.claude/agent-memory/<agent>/` across sessions. Measured value of
memory in the literature is +3.9 to +5.25 pp.

**Enabling memory does not grant an agent the tools to write it.** The docs say
Read/Write/Edit are auto-enabled for memory files, but an explicit `tools:`
allowlist wins — omit Write and it stays omitted. So the analyzer (`Read, Grep,
Glob`) could not write its memory at all, and the debugger could only reach it
through `Bash`, a route its design never intended. Both prompts said to update
memory anyway; for the analyzer that was a guaranteed no-op.

**So the harness writes it.** Agents end their report with a `## Memory` block
and `.claude/hooks/persist-memory.sh` (SubagentStop) appends it to their file —
no tool grant, read-only allowlists intact. Entries go **newest first** on
purpose: only the first 200 lines are injected into the agent's prompt, so old
entries at the top would push new ones out of sight. The file is capped at 400
lines. `implementer` is deliberately excluded — it has real `Write` and manages
its own file, so including it would double-write.

Reading memory needs no tool at all; the harness injects `MEMORY.md` directly.

This repository is worked from **ephemeral cloud containers** as well as from a
desktop. A container is reclaimed after the session ends. **Agent memory that is
not committed does not survive the session that wrote it** — so commit it, the
same as any other source file. Do not add it to `.gitignore`.

## Delegation

```
Something is broken        → debugger (diagnose, prove; no Edit/Write — but it
                             has Bash, so "cannot patch" is a speed bump, not a
                             guarantee. Do not restate it as one.)
                                └→ implementer (apply the proposed fix, verify)
Unfamiliar code, no defect → analyzer (map it, cite file:line) → implementer
Change already understood  → implementer directly
```

Delegation is driven entirely by the `description` field, which is why rule 3
matters. Keep descriptions behavioural — "Use whenever X, and before Y" — and
have adjacent agents name each other and state the tell that distinguishes them.

Two research shapes, not one: **narrative** (`research-agent`, one agent per
sub-question, cited essay, verified against fabricated URLs) and **matrix**
(`research-compare`, one agent per row, filled table, verified for schema
completeness). The verification axes are orthogonal; neither substitutes for the
other.

## Conventions

- **Hooks are bash, called with an absolute path resolved from `$0`,** and must
  exit 0 on every degradation — a missing linter, a missing file, an absent
  interpreter. `PostToolUse` cannot block, so its channel is
  `hookSpecificOutput.additionalContext`. `Stop` can block, with exit 2.
- **`verify-done.sh` has a per-`prompt_id` circuit breaker. Do not remove it.**
  One block catches the "I think I'm done" reflex; looping forever on a
  genuinely unfixable failure helps nobody.
- **Retire by archiving, not deleting** — `.claude/skills/_archive/<name>/`,
  with `_archive/README.md` recording what went and why.
- **Shared knowledge between skills lives in a folder with no `SKILL.md`**, so it
  does not register as invocable. Referenced by path.
- **Run `/wrap` before ending a session** that moved a project, while the work
  is still in context. A `SessionEnd` hook cannot do this — compression needs a
  model and a shell script does not have one.
- **`registry.py brief`** is the start-of-day glance — blockers first, then next
  actions. Deliberately a command and not a skill, so it costs no description
  budget and nothing is loaded to run it.
- **The Projects index above is generated.** Run `registry.py index --write`;
  never hand-edit between the markers. Project state belongs in a card, and a
  card's `## State` is *rewritten* and capped while its log is appended — a
  summary that grows is not a summary.
- **Keep this file under 200 lines.** Path-scoped detail belongs in
  `.claude/rules/`, which loads on demand.
- Every claim added to `docs/research/` carries its provenance, and anything
  reached through a search summary rather than a direct fetch says so.

## Before you trust any number in here

Network egress was heavily restricted when the research ran — arxiv,
openreview, huggingface, metr.org and most vendor blogs were blocked — so a
share of the benchmark figures come from search-engine summaries of pages that
were never opened. Those are marked `[via search summary]` in the notes.
Re-verify before relying on one externally.

And nothing in this platform has been **measured on this codebase**. The prompts
encode findings from the literature. Whether these agents help *here* is still a
guess, and stays one until there is an eval set — which needs merged PRs this
repo does not have yet.

## Open work

`docs/research/agent-spec.md` §9 and `docs/research/agent-platform-skills.md` §9
carry the live lists. The highest-value items outstanding: port or ship the three
engine scripts, without which the research skills cannot run outside the desktop;
run the staged research design once end to end so its 85–90% cost saving becomes
a measurement rather than a model; repoint the local router off an exhausted
provider; and exercise the hooks under the live harness rather than by piping
JSON at them.
