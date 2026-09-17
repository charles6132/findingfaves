# Claude Code Implementation Reference: Building Custom Debugging and Coding Agents (September 2026)

> **Method note:** Every schema below was read verbatim from the official Claude Code documentation fetched on 2026-09-17 from `https://docs.claude.com/en/docs/claude-code/<page>.md` (the Markdown source of the live docs, which now canonically live at `code.claude.com/docs`). Repository statistics were pulled live from the GitHub API on 2026-09-17. Where a field's existence or behavior was not confirmed in a primary source, it is listed under **Gaps** rather than asserted.

---

## Subagents: file format, frontmatter schema, delegation, isolation

### Takeaway
Subagents are Markdown files with YAML frontmatter in `.claude/agents/` (project) or `~/.claude/agents/` (user); only `name` and `description` are required, but the 2026 schema has grown to ~16 fields including `isolation: worktree` (temporary git worktree), `memory` (persistent cross-session memory), `omitClaudeMd`, `effort`, `maxTurns`, `skills`, `mcpServers` and per-subagent `hooks`. The `description` field is the sole driver of automatic delegation and is now budgeted: combined subagent descriptions over 15,000 tokens trigger a startup warning.

### Cited Findings

**Locations and precedence** — Subagent scope is decided by file location, with this precedence order (1 = highest): managed settings `.claude/agents/`; `--agents` CLI flag (session-only JSON); `.claude/agents/` (project); `~/.claude/agents/` (user); plugin `agents/` directory (lowest) — [Create custom subagents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Both project and user directories are scanned **recursively**, so `agents/review/` subfolders are allowed; identity comes only from the `name` frontmatter field, not the path — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- For plugin agents only, the subfolder *does* become part of the scoped identifier: `agents/review/security.md` in plugin `my-plugin` registers as `my-plugin:review:security` — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Project subagents are discovered by walking up from the cwd; as of v2.1.178, when nested directories define the same `name`, the definition closest to the working directory wins — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Claude Code watches `~/.claude/agents/` and `.claude/agents/` and picks up edits within seconds with no restart; exceptions needing restart are (a) a scope's first agent file in a newly created directory, (b) `.claude/agents/` inside `--add-dir` directories, (c) sessions started with `--disable-slash-commands` — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Complete frontmatter schema (verbatim field list; only `name` and `description` are required)** — [sub-agents §Supported frontmatter fields](https://docs.claude.com/en/docs/claude-code/sub-agents)

| Field | Required | Description (condensed from the official table) |
|---|---|---|
| `name` | Yes | Unique identifier, lowercase letters and hyphens. Hooks receive this as `agent_type`. Filename need not match. Cannot contain `:` (reserved for plugin-scoped ids); before v2.1.218 such names were accepted |
| `description` | Yes | When Claude should delegate to this subagent |
| `tools` | No | Tools the subagent can use. Inherits every tool available to subagents if omitted. To preload Skills, use `skills`, not `Skill` here |
| `disallowedTools` | No | Tools to deny, removed from the inherited or specified list. An entry with a specifier such as `Bash(git push *)` still removes the **whole** tool |
| `model` | No | `sonnet`, `opus`, `haiku`, `fable`, a full model ID such as `claude-opus-5`, or `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, or `manual` (alias for `default`, v2.1.200+). Ignored for plugin subagents |
| `maxTurns` | No | Max agentic turns before stopping; output is returned marked partial and can be resumed (partial marking requires v2.1.246+) |
| `skills` | No | Skills to **preload** into the subagent's context at startup; full skill content is injected, not just the description |
| `mcpServers` | No | MCP servers for this subagent: a string naming an already-configured server, or an inline definition using `.mcp.json` schema. Ignored for plugin subagents |
| `hooks` | No | Lifecycle hooks scoped to this subagent. Ignored for plugin subagents |
| `memory` | No | Persistent memory scope: `user`, `project`, or `local` |
| `background` | No | `true` keeps the subagent in the background even when Claude asks for the foreground |
| `omitClaudeMd` | No | `true` launches without user/project/local CLAUDE.md (managed policy files still load). **Requires v2.1.271 or later** |
| `effort` | No | `low`, `medium`, `high`, `xhigh`, `max`; overrides session effort |
| `isolation` | No | `worktree` runs the subagent in a temporary git worktree branched by default from your default branch (not the parent's HEAD); auto-cleaned if the subagent makes no changes |
| `color` | No | `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan` |
| `initialPrompt` | No | Auto-submitted first user turn when the agent runs as the **main** session agent (`--agent` or the `agent` setting) |
| `experimental` | No | Map of experimental options; `cacheTtl: 5m` or `1h` sets prompt cache lifetime. Requires v2.1.248+ |

- `experimental.cacheTtl` must be nested inside the `experimental` map, not at the top level — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**How `description` drives automatic delegation**
- "Claude automatically delegates tasks based on the task description in your request, the `description` field in subagent configurations, and current context. To encourage proactive delegation, include phrases like 'use proactively' in your subagent's description field." — [sub-agents §Understand automatic delegation](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Descriptions consume context on every turn: when combined non-built-in descriptions exceed **15,000 tokens**, Claude Code shows a startup warning with the total token count and still loads every subagent. Fix by trimming `description` and moving detail into the system prompt body, which loads only when the subagent runs — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Explicit invocation escalates in three steps: natural language ("Use the test-runner subagent…"), `@`-mention (`@"code-reviewer (agent)"` or typed `@agent-<name>`), and session-wide `claude --agent <name>` / `"agent": "code-reviewer"` in `.claude/settings.json` — [sub-agents §Invoke subagents explicitly](https://docs.claude.com/en/docs/claude-code/sub-agents)
- With `--agent`, the subagent's system prompt **replaces** the default Claude Code system prompt entirely, like `--system-prompt`; CLAUDE.md still loads through the normal message flow even when `omitClaudeMd` is set — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Tool inheritance semantics**
- Subagents inherit built-in and MCP tools from the main conversation, narrowed by two filters. Filter 1 removes from every subagent, even if listed in `tools`: `Agent` (at the depth limit), `AskUserQuestion`, `EndConversation`, `EnterPlanMode`, `ExitPlanMode` (unless `permissionMode: plan`), `ScheduleWakeup`, `TaskOutput`, `WaitForMcpServers`, `Workflow` — [sub-agents §Available tools](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Filter 2 applies to **background** subagents (the default in interactive sessions): they keep every MCP tool but only these built-ins — `Read`, `Grep`, `Glob`, `Bash`, `PowerShell`, `Edit`, `Write`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`, `ToolSearch`, `EnterWorktree`, `ExitWorktree`, `Monitor`, `TaskStop`, `SendMessage`, `Artifact`, plus `SubagentHandback`. "The same definition can resolve to different tools in the foreground and the background." — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- If both fields are set, `disallowedTools` is applied first, then `tools` resolves against the remainder; a tool in both is removed — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Both fields accept MCP server patterns: `mcp__<server>` or `mcp__<server>__*`; in `disallowedTools`, `mcp__*` removes every MCP tool — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- If nothing in `tools` resolves, Claude Code usually refuses to launch and the Agent tool errors naming the unresolved entries (before v2.1.208 it launched with no tools) — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- `Agent(worker, researcher)` allowlist syntax restricts which subagent types can be spawned, **but only for an agent running as the main thread with `claude --agent`**; inside a subagent definition the type list in parentheses is ignored — [sub-agents §Restrict which subagents can be spawned](https://docs.claude.com/en/docs/claude-code/sub-agents)
- In v2.1.63 the **Task tool was renamed to Agent**; existing `Task(...)` references still work as aliases — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Context isolation semantics** — a non-fork subagent's initial context contains exactly: its own system prompt plus environment details (not the Claude Code system prompt); the delegation task message Claude writes; every level of the CLAUDE.md hierarchy (skipped by built-in Explore/Plan, and reduced to managed policy files with `omitClaudeMd`); a git-status snapshot from parent session start; preloaded `skills` content; and a sibling roster when `SendMessage` is available (v2.1.206+) — [sub-agents §What loads at startup](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Never reaches a non-fork subagent: your output style, the main conversation's auto memory, and the parent's context-window size (a subagent's window is sized by its own model) — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Subagent transcripts live at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`, persist independently of main-conversation compaction, and are deleted after `cleanupPeriodDays` (default 30) — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Nesting: by default a subagent can spawn its own subagents **up to three layers** below the main conversation; change with `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (set `1` to disable nesting). v2.1.172–v2.1.216 allowed five fixed layers; v2.1.217–v2.1.218 defaulted to one — [sub-agents §Let subagents spawn their own subagents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Concurrency: 20 running subagents per session by default; `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` changes it (v2.1.217+) — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- **Subagent output scanning** (v2.1.210+): Claude Code scans each subagent's final report before Claude reads it, inserting backslashes into text imitating `<system-reminder>`/`Human:`/`Assistant:`, and prepending `[harness: subagent output matched instruction-shaped pattern(s):` when the report imitates such tags or mentions `bypassPermissions` / `--dangerously-skip-permissions` — [sub-agents §Subagent output scanning](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Built-in subagents (2026)** — `Explore` (read-only, Write/Edit denied; as of v2.1.198 inherits the main model, capped at Opus on the Claude API, instead of always Haiku), `Plan` (read-only, used in plan mode), `general-purpose` (every tool available to subagents), plus helpers `claude`, `statusline-setup` (Sonnet), `claude-code-guide` (Haiku). Explore and Plan skip CLAUDE.md and git status — [sub-agents §Built-in subagents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- A user/project subagent named `Explore` overrides the built-in and keeps its own `model` field — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Disable via `"permissions": {"deny": ["Agent(Explore)", "Agent(my-custom-agent)"]}`, or `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1` (v2.1.198+), or `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1` in headless/SDK — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Deprecated / changed in 2026 (flagged)**
- As of v2.1.198 `/agents` **no longer opens the interactive creation wizard**; it prints a reminder to ask Claude or edit `.claude/agents/` directly. File format and locations are unchanged — [sub-agents §Quickstart](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Model resolution order changed: per-invocation `model` → frontmatter `model` (with `inherit`) → `CLAUDE_CODE_SUBAGENT_MODEL` → main conversation model. **Before v2.1.251 the env var came first.** `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) forces one model onto every subagent/teammate/workflow agent — [sub-agents §Choose a model](https://docs.claude.com/en/docs/claude-code/sub-agents)
- As of v2.1.198 subagents inherit the main conversation's extended-thinking configuration; before that they always ran with thinking disabled — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Working example — a debugging subagent (copy-pasteable)**
Save as `.claude/agents/debugger.md`:

```markdown
---
name: debugger
description: Root-cause specialist for failing tests, stack traces, and runtime errors. Use proactively whenever a test fails, an exception is thrown, or the user reports a bug.
tools: Read, Grep, Glob, Bash, Edit, TodoWrite
disallowedTools: WebFetch
model: sonnet
effort: high
maxTurns: 40
memory: project
color: red
permissionMode: acceptEdits
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/verify-edit.sh"
          args: []
          timeout: 120
---

You are a debugging specialist. Your job is to find the root cause, not to
patch the symptom.

Process, in order:
1. Reproduce. Run the failing test or command and capture the exact error.
2. Localize. Use Grep/Glob to find the code on the failure path. Read it.
3. Form one hypothesis at a time and state it explicitly before testing it.
4. Add temporary instrumentation (logging/asserts) if the cause is unclear.
   Remove it before you finish.
5. Fix the root cause with the smallest change that is correct.
6. Re-run the failing test AND the surrounding test file. Report both results.

Report format:
- Root cause: one or two sentences, with file:line.
- Evidence: the specific observation that proves it.
- Fix: what you changed and why.
- Residual risk: anything you could not verify.

Update your agent memory with codepaths, recurring failure modes, and
project-specific gotchas you discover, so future debugging sessions start
ahead of where this one did.
```

**Memory directory locations** — `user` → `~/.claude/agent-memory/<name-of-agent>/`; `project` → `.claude/agent-memory/<name-of-agent>/`; `local` → `.claude/agent-memory-local/<name-of-agent>/`. When enabled, Read/Write/Edit are auto-enabled and the first 200 lines or 25KB of `MEMORY.md` is injected into the system prompt. Subagent memory is part of auto memory, so `autoMemoryEnabled: false` or `CLAUDE_CODE_DISABLE_AUTO_MEMORY` disables the `memory` field entirely. `project` is the documented recommended default — [sub-agents §Enable persistent memory](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Files Claude Code silently skips** (useful for debugging a subagent that "doesn't exist"): no `name`; opening `---` not on line 1; `name` starting with `-` or containing `:`; `name` present but no `description`; unparseable YAML. Run with `--debug` to see the reason, or `claude plugin validate .claude/agents` (v2.1.233+) — [sub-agents §Subagent files Claude Code skips](https://docs.claude.com/en/docs/claude-code/sub-agents)

### Inferences
- For a self-verifying coding agent, `isolation: worktree` + `permissionMode: acceptEdits` + frontmatter `PostToolUse` hooks is the highest-autonomy-per-unit-of-risk configuration available without touching global settings: edits land in a throwaway worktree, and verification is enforced by the harness rather than by prompt.
- Because background subagents lose most built-in tools, any subagent that depends on a tool outside the background allowlist must either be forced to the foreground or be redesigned; this is a common silent failure mode.
- The 15,000-token description budget effectively caps a practical library at roughly 100–200 subagents with terse descriptions, which is why the large community collections (100+ agents) are better used as a menu to copy from than installed wholesale.

### Gaps
- The docs describe `isolation: worktree` behavior but I did not verify the interaction between `isolation: worktree` and `memory: project` (whether memory writes land in the worktree copy or the main checkout).
- I did not find a documented maximum for `maxTurns`.

---

## Skills (Agent Skills): structure, discovery, progressive disclosure, and when to use which primitive

### Takeaway
Skills are directories containing `SKILL.md` plus optional supporting files; **custom slash commands have been merged into skills** — `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both produce `/deploy`. All frontmatter fields are optional (only `description` is recommended); the field set is much larger than the Agent Skills open standard, which permits only six fields. Progressive disclosure is explicit: descriptions are always in context (capped at 1,536 characters), bodies load on invocation, and supporting files load only when Claude reads them.

### Cited Findings

**Locations** — [Extend Claude with skills §Choose where skills load](https://docs.claude.com/en/docs/claude-code/skills)

| Location | Path | Loads in |
|---|---|---|
| Enterprise | `.claude/skills/<skill-name>/SKILL.md` in the managed settings directory | All users where deployed |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects on this machine, **not** Cowork or cloud sessions |
| Project | `.claude/skills/<skill-name>/SKILL.md` | Sessions in this repository |
| Nested | `<subdir>/.claude/skills/<skill-name>/SKILL.md` | Sessions started in or below `<subdir>` |
| Additional directory | `.claude/skills/…` in a `--add-dir` directory | That session |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Wherever the plugin is enabled, as `/plugin-name:skill-name` |
| claude.ai account | synced skills | Cowork/cloud/terminal sessions signed in with that account, as `/anthropic-skills:<name>` |

- Reserved name: **do not name a skill folder `synced`** in any capitalization; `~/.claude/skills/synced/` is used for claude.ai-synced skills — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- A skill folder becomes a plugin by adding `.claude-plugin/plugin.json`, loading as `<name>@skills-dir`, which lets it bundle agents, hooks and MCP servers — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- Skills in subdirectories below the launch directory don't load at startup; they load the first time Claude reads or edits a file there, or immediately if you run `/add-dir` (v2.1.257+) — [skills §Load skills in monorepos](https://docs.claude.com/en/docs/claude-code/skills)
- Name-conflict resolution: enterprise > personal > project; a local skill beats a same-named bundled skill (but not the bundled skill's aliases); a skill beats a `.claude/commands/` file of the same name; plugin skills always coexist because they are namespaced — [skills §Resolve skills that share a name](https://docs.claude.com/en/docs/claude-code/skills)

**Complete frontmatter reference (all fields optional; only `description` recommended)** — [skills §Frontmatter reference](https://docs.claude.com/en/docs/claude-code/skills)

| Field | Notes |
|---|---|
| `name` | Display name in listings; **defaults to the directory name**. For personal/project skills it does *not* change the command you type; for plugin skills it sets the last command segment |
| `description` | What it does and when to use it. If omitted, the first non-empty line of the body is used. Combined `description` + `when_to_use` is **truncated at 1,536 characters** in the skill listing |
| `when_to_use` | Extra trigger phrases; appended to `description` and counts toward the 1,536-char cap |
| `argument-hint` | Autocomplete hint, e.g. `[issue-number]` or `[filename] [format]` |
| `arguments` | Named positional arguments for `$name` substitution; space-separated string or YAML list |
| `disable-model-invocation` | `true` = only you can invoke it; also blocks preloading into subagents and (v2.1.196+) scheduled-task invocation |
| `user-invocable` | `false` = only Claude can invoke it; hidden from the `/` menu |
| `allowed-tools` | Tools pre-approved **for the turn that invokes the skill only**; grant clears on your next message. Space- or comma-separated string, or YAML list |
| `disallowed-tools` | Tools removed from Claude's pool while the skill is active; clears on next message |
| `model` | Model while the skill is active (or the forked subagent's model with `context: fork`) |
| `effort` | `low`/`medium`/`high`/`xhigh`/`max` |
| `context` | `fork` runs the skill in a forked subagent context |
| `agent` | Which subagent type to use when `context: fork` is set; defaults to `general-purpose` |
| `background` | Only with `context: fork`. `false` waits for the result in the invoking turn. Default `true`. Requires v2.1.218+ |
| `hooks` | Hooks registered when the skill is invoked, kept for the rest of the session (`once: true` removes after first success) |
| `paths` | Glob patterns limiting automatic activation to matching files |
| `shell` | `bash` (default) or `powershell` for `` !`command` `` blocks |
| `metadata` | Free-form YAML map; Claude Code does not act on it |
| `license` | Agent Skills spec field; accepted but not acted on |
| `compatibility` | Agent Skills spec field, string up to 500 chars; accepted but not acted on |

- Boolean fields accept `yes`, `no`, `on`, `off`, `1`, `0` in any case as well as `true`/`false` (v2.1.218+) — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- Frontmatter is read **only when the opening `---` is the file's first line**; otherwise the whole file including the markers is treated as content — [skills](https://docs.claude.com/en/docs/claude-code/skills)

**Portability constraint (important for anything you plan to upload to claude.ai or the Skills API):** outside Claude Code only six fields are legal — `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. Including any other field causes a **hard error**, verbatim: `Unexpected key(s) in SKILL.md frontmatter: argument-hint. Allowed properties are: allowed-tools, compatibility, description, license, metadata, name` — [skills §Using skill frontmatter outside Claude Code](https://docs.claude.com/en/docs/claude-code/skills)

**Progressive disclosure, size and token limits**
- Default: "skill descriptions are loaded into context so Claude knows what's available, but full skill content only loads when invoked." With `disable-model-invocation: true` the description is *not* in context at all — [skills §Control who invokes a skill](https://docs.claude.com/en/docs/claude-code/skills)
- Documented size guidance: **"Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files."** — [skills §Add supporting files](https://docs.claude.com/en/docs/claude-code/skills)
- Recommended layout, verbatim from the docs:
  ```
  my-skill/
  ├── SKILL.md (required - overview and navigation)
  ├── reference.md (detailed API docs - loaded when needed)
  ├── examples.md (usage examples - loaded when needed)
  └── scripts/
      └── helper.py (utility script - executed, not loaded)
  ```
  Reference them from SKILL.md with markdown links so Claude knows when to load each — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- **Skill content lifecycle:** once invoked, the rendered SKILL.md enters the conversation as a single message and **stays across later turns**; Claude Code does not re-read the file. Re-invoking with identical rendered content adds only a short "already loaded" note. On auto-compaction, the most recent invocation of each skill is re-attached after the summary, keeping the **first 5,000 tokens of each**, with a **combined 25,000-token budget** filled from the most recently invoked skill — [skills §Skill content lifecycle](https://docs.claude.com/en/docs/claude-code/skills)
- Hook/skill output strings (`additionalContext`, `systemMessage`, plain stdout) are capped at **10,000 characters**; longer output is written to a file and replaced with a preview plus path — [Hooks reference §JSON output](https://docs.claude.com/en/docs/claude-code/hooks)
- `/skill-doctor` (v2.1.252+) reports each skill's context cost and usage frequency and flags never-invoked skills — [skills §Find unused skills](https://docs.claude.com/en/docs/claude-code/skills)

**String substitutions available in skill bodies** — `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N` (shorthand for `$ARGUMENTS[N]`), `$name` (from `arguments`), `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}`, `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}` (v2.1.196+), `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}` — [skills §Available string substitutions](https://docs.claude.com/en/docs/claude-code/skills)
- **`$N` is 0-based**: the docs state "`$0` for the first argument or `$1` for the second." — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PROJECT_DIR}` are substituted in **two** places: the markdown body *and* Bash rules in `allowed-tools`, which is the supported pattern for running a bundled script without a prompt — [skills](https://docs.claude.com/en/docs/claude-code/skills)

**Dynamic context injection (`!` syntax)**
- `` !`<command>` `` runs the shell command *before* the skill content reaches Claude and substitutes the output. Multi-line form uses a fence opened with ` ```! ` — [skills §Inject dynamic context](https://docs.claude.com/en/docs/claude-code/skills)
- The inline form is recognized only when `!` starts a line or immediately follows whitespace; `` KEY=!`cmd` `` is left literal — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- **A failed injected command aborts the entire skill invocation** with `Shell command failed for pattern "..."`. With the default bash shell, any non-zero exit is a failure except exit code 1 from search/comparison commands. Append `|| true` to commands expected to exit non-zero — [skills §When an injected command fails](https://docs.claude.com/en/docs/claude-code/skills)
- Injected commands never prompt; a command whose permission check returns anything other than allow aborts the invocation (outside auto mode) — [skills §Permission checks on injected commands](https://docs.claude.com/en/docs/claude-code/skills)
- Disable globally with `"disableSkillShellExecution": true` in settings; each command is replaced with `[shell command execution disabled by policy]`. Bundled and managed skills are unaffected — [skills](https://docs.claude.com/en/docs/claude-code/skills)

**Skills vs subagents vs slash commands — official comparison**
- "Skills and subagents work together in two directions": a **skill with `context: fork`** takes its system prompt from the agent type and its task from SKILL.md; a **subagent with a `skills` field** takes its system prompt from its own markdown body and its task from Claude's delegation message, with the listed skills preloaded — [skills §Run skills in a subagent](https://docs.claude.com/en/docs/claude-code/skills)
- "Consider [Skills] instead when you want reusable prompts or workflows that run in the main conversation context rather than isolated subagent context." — [sub-agents §Choose between subagents and main conversation](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Use the main conversation (not a subagent) when the task needs iterative back-and-forth, when phases share context, for quick targeted changes, or when latency matters — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Use subagents when output is verbose and disposable, when you need tool restrictions, or when the work is self-contained and returns a summary — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Create a skill "when you keep pasting the same instructions, checklist, or multi-step procedure into chat, or when a section of CLAUDE.md has grown into a procedure rather than a fact" — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- Define a custom subagent "when you keep spawning the same kind of worker with the same instructions" — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Bundled skills relevant to a self-verifying coding agent (2026)** — `/doctor`, `/code-review`, `/batch`, `/debug`, `/loop`, `/claude-api`, plus the run-and-verify trio: `/run` (launch and drive your app), `/verify` (build and run to confirm a change, without falling back to tests or type checks), `/run-skill-generator` (records the launch recipe as a per-project skill at `.claude/skills/run-<name>/`). `/verify` can self-record its recipe to `.claude/skills/verify/SKILL.md` (v2.1.200+). `/verify` is user-invocation-only and therefore cannot be preloaded into subagents — [skills §Bundled skills, §Run and verify your app](https://docs.claude.com/en/docs/claude-code/skills)
- `/code-review` runs as a forked subagent from v2.1.218 (it ran inline and stacked on earlier versions) — [skills](https://docs.claude.com/en/docs/claude-code/skills)

**Working example — a skill (copy-pasteable)**
Save as `.claude/skills/triage-failure/SKILL.md`:

```markdown
---
name: triage-failure
description: Triage a failing test or CI job. Use when the user says a test fails, pastes a stack trace, mentions a red build, or asks why CI is broken.
when_to_use: "test failing, CI red, stack trace, flaky test, regression"
argument-hint: "[test-name-or-path]"
allowed-tools: Bash(npm test *) Bash(npx jest *) Bash(git log *) Bash(git diff *)
paths:
  - "src/**"
  - "tests/**"
effort: high
---

## Working tree

!`git status --short`

## Recent commits touching the failure area

!`git log --oneline -10`

## Instructions

Triage the failure in `$ARGUMENTS` (if empty, find the failing test yourself).

1. Run the narrowest failing test and capture the exact assertion and stack.
2. Decide the category before proposing a fix:
   - **Product bug** — the code is wrong.
   - **Test bug** — the assertion encodes the wrong expectation.
   - **Flake** — order-, time-, or network-dependent. Prove it by re-running.
   - **Environment** — missing dep, stale build, wrong env var.
3. Bisect with `git log`/`git diff` when the test used to pass.
4. Propose the minimal fix, state the category, and cite `file:line`.

See [reference.md](reference.md) for this repo's known flaky tests and the
retry policy. Only read it if you classify the failure as a flake.
```

### Inferences
- The 1,536-character description cap plus the always-loaded nature of descriptions means description text is the scarcest resource in a large skill library; `when_to_use` is not free headroom because it shares the cap.
- Because skill content persists across turns and is re-attached after compaction within a 25k budget, a 500-line SKILL.md is a permanent tax for the rest of the session. Splitting into `SKILL.md` + `references/` is not a style preference but the main lever on per-session token cost.
- `disable-model-invocation: true` is the correct default for any skill with side effects (deploy, commit, release) in an autonomous agent, because it is the only setting that removes the description from Claude's context entirely.

### Gaps
- The docs use both `references/` (common community convention) and a flat `reference.md` in the canonical example; I found **no** official statement that a directory must be named `references/` or `scripts/` — the example shows `scripts/` for executables and flat `.md` files for reference material. Treat `references/` as convention, not schema.
- I did not find a documented hard byte limit on total skill directory size, only the 500-line SKILL.md guidance and the 5,000/25,000-token compaction budgets.

---

## Hooks: full event list, settings schema, stdin payloads, exit-code and JSON control

### Takeaway
As of September 2026 there are **33 documented hook events** — far more than the 2025 set — and five handler types (`command`, `http`, `mcp_tool`, `prompt`, `agent`). The control model is: exit 2 blocks (on events that can block), exit 0 with a JSON object on stdout gives structured control, and `PostToolUse` is the event that makes a self-verifying coding agent possible because it fires after every successful `Edit`/`Write` and can push lint/test results back into Claude's context via `decision: "block"` + `reason` or `hookSpecificOutput.additionalContext`.

### Cited Findings

**Complete hook event list (verbatim from the lifecycle table)** — [Hooks reference §Hook lifecycle](https://docs.claude.com/en/docs/claude-code/hooks)

`SessionStart`, `Setup`, `UserPromptSubmit`, `UserPromptExpansion`, `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Notification`, `MessageDisplay`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `Stop`, `StopFailure`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `PreModelSwitch`, `PostModelSwitch`, `Elicitation`, `ElicitationResult`, `SessionEnd`.

Events added since the 2025 set (all documented in the same table): `Setup`, `UserPromptExpansion`, `PermissionRequest`, `PermissionDenied`, `PostToolUseFailure`, `PostToolBatch`, `MessageDisplay`, `SubagentStart`, `TaskCreated`, `TaskCompleted`, `StopFailure`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PostCompact`, `PreModelSwitch`, `PostModelSwitch`, `Elicitation`, `ElicitationResult` — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)

Cadences: per session (`SessionStart`, `SessionEnd`); per turn (`UserPromptSubmit`, `Stop`, `StopFailure`); per tool call (`PreToolUse`, `PostToolUse`, except `EndConversation` calls which skip both) — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)

**Configuration schema (three levels of nesting: event → matcher group → handler)** — [hooks §Configuration](https://docs.claude.com/en/docs/claude-code/hooks)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh",
            "args": []
          }
        ]
      }
    ]
  }
}
```

**Hook locations and scope** — `~/.claude/settings.json` (all projects), `.claude/settings.json` (project, committable), `.claude/settings.local.json` (project, gitignored), managed policy settings (org-wide), plugin `hooks/hooks.json`, skill frontmatter (rest of session after invocation), subagent frontmatter (while that subagent runs) — [hooks §Hook locations](https://docs.claude.com/en/docs/claude-code/hooks)
- Hook entries **merge** across settings levels rather than replacing each other; `disableAllHooks` cannot disable managed hooks from outside managed settings — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)
- All matching hooks run **in parallel**. The same handler defined in more than one settings file runs once; a plugin's or skill's copy stays separate — [hooks §Hook handler fields](https://docs.claude.com/en/docs/claude-code/hooks)

**Matcher evaluation rules (exact, and a frequent source of bugs)** — [hooks §Matcher patterns](https://docs.claude.com/en/docs/claude-code/hooks)
- `"*"`, `""`, or omitted → match all
- Only letters, digits, `_`, `-`, spaces, `,`, `|` → exact string, or `|`/`,`-separated list of exact strings
- Anything else → **unanchored JavaScript regular expression**, tested with `RegExp.prototype.test`. Therefore `Edit.*` matches `NotebookEdit`; use `^Edit$` for whole-string matching
- Hyphens joined the exact-match set in v2.1.195; before that `code-reviewer` was a regex that also matched `senior-code-reviewer`
- `FileChanged` and `StopFailure` use a narrower exact-match set (letters, digits, `_`, `|` only)
- MCP tools are matched as `mcp__<server>__<tool>`; `mcp__memory__.*` matches all tools from `memory`. **The `.*` is required** — a bare `mcp__memory` is treated as an exact string and matches nothing
- Plugin-bundled MCP servers use a scoped segment: `mcp__plugin_<plugin-name>_<server-name>__<tool>`

**Handler fields (common to all types)** — [hooks §Common fields](https://docs.claude.com/en/docs/claude-code/hooks)

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `"command"`, `"http"`, `"mcp_tool"`, `"prompt"`, `"agent"` |
| `if` | no | One permission rule, e.g. `"Bash(git *)"` or `"Edit(*.ts)"`. **Only evaluated on tool events**; on other events a hook with `if` never runs. No `&&`/`||`/list syntax |
| `timeout` | no | Seconds. Defaults: 600 for `command`/`http`/`mcp_tool`; 30 for `prompt`; 60 for `agent`. Lowered to 30 on `UserPromptSubmit`/`PreModelSwitch`/`PostModelSwitch`, 10 on `MessageDisplay`. `SessionEnd` hooks share a 1.5-second budget |
| `statusMessage` | no | Custom spinner message |
| `once` | no | Remove after first successful run; **only honored in skill frontmatter** |

Command-hook-specific fields: `command` (required), `args` (switches to exec form, no shell), `async`, `asyncRewake` (background + wake Claude on exit 2), `shell` (`"bash"` or `"powershell"`) — [hooks §Command hook fields](https://docs.claude.com/en/docs/claude-code/hooks)
- **Exec form vs shell form**: `args` present → `command` is resolved as an executable and spawned directly, no shell, no tokenization, placeholders substituted as plain strings. `args` absent → the string goes to `sh -c` (macOS/Linux), Git Bash, or PowerShell. "Set `args` whenever the hook references a path placeholder." — [hooks §Exec form and shell form](https://docs.claude.com/en/docs/claude-code/hooks)
- On Windows, exec form cannot spawn `.cmd`/`.bat` shims (npm, npx, eslint); invoke `node` with the script path instead — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)

**Path placeholders** — `${CLAUDE_PROJECT_DIR}` (project root where the session started), `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`. All three are also exported as environment variables on the spawned process. **Worktree caveat:** `${CLAUDE_PROJECT_DIR}` stays at the original project root, while the `cwd` field in the hook's input JSON follows Claude into the worktree — [hooks §Reference scripts by path](https://docs.claude.com/en/docs/claude-code/hooks)

**Common stdin input fields (every event)** — `session_id`, `prompt_id` (v2.1.196+, matches the OTel `prompt.id`), `transcript_path`, `cwd`, `scratchpad_dir` (v2.1.257+), `permission_mode` (`"default"`/`"plan"`/`"acceptEdits"`/`"auto"`/`"dontAsk"`/`"bypassPermissions"` — Manual arrives as `"default"`, never `"manual"`), `effort` (object with `level`), `hook_event_name`. Inside a subagent or `--agent` session, also `agent_id` and `agent_type` — [hooks §Common input fields](https://docs.claude.com/en/docs/claude-code/hooks)

Verbatim `PreToolUse` stdin example from the docs:
```json
{
  "session_id": "abc123",
  "prompt_id": "550e8400-e29b-41d4-a716-446655440000",
  "transcript_path": "/home/user/.claude/projects/.../transcript.jsonl",
  "cwd": "/home/user/my-project",
  "scratchpad_dir": "/tmp/claude-1000/-home-user-my-project/abc123/scratchpad",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm test",
    "description": "Run test suite",
    "timeout": 120000,
    "run_in_background": false
  },
  "tool_use_id": "toolu_01ABC123..."
}
```
— [hooks §Common input fields](https://docs.claude.com/en/docs/claude-code/hooks)

Verbatim `PostToolUse` stdin example:
```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../00893aaf-19fa-41d2-8238-13269b9b3ca0.jsonl",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": { "file_path": "/path/to/file.txt", "content": "file content" },
  "tool_response": { "filePath": "/path/to/file.txt", "type": "create" },
  "tool_use_id": "toolu_01ABC123...",
  "duration_ms": 12
}
```
`duration_ms` is optional and excludes time spent in permission prompts and PreToolUse hooks — [hooks §PostToolUse input](https://docs.claude.com/en/docs/claude-code/hooks)

**Exit-code semantics**
- **Exit 0**: success. For most events stdout goes to the debug log only. Exceptions where plain-text stdout is added to Claude's context: `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, `PostModelSwitch` — [hooks §Exit code 0](https://docs.claude.com/en/docs/claude-code/hooks)
- Stdout is parsed as JSON only if it **starts with `{` and ends with `}`** (ignoring surrounding whitespace); anything else, including a JSON array or quoted string, is plain text — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)
- **Exit 2**: blocking error. It blocks whether or not you print JSON — "even a JSON `permissionDecision` of `"allow"` can't override it." The blocking message is the JSON reason when present, otherwise stderr — [hooks §Exit code 2](https://docs.claude.com/en/docs/claude-code/hooks)
- **Any other exit code does not block on its own.** "Without valid JSON on stdout, Claude Code treats exit code 1 as a non-blocking error and proceeds with the action, even though 1 is the conventional Unix failure code. If your hook is meant to enforce a policy, use `exit 2`." Exception: any non-zero exit from `WorktreeCreate`/`WorktreeRemove` fails the operation — [hooks §Other exit codes](https://docs.claude.com/en/docs/claude-code/hooks)
- Per-event exit-2 behavior: blocks on `PreToolUse`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `SubagentStop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `ConfigChange`, `PostToolBatch`, `PreCompact`, `PreModelSwitch`, `Elicitation`, `ElicitationResult`, `WorktreeCreate`, `WorktreeRemove`. **Cannot block**: `PostToolUse` and `PostToolUseFailure` (but stderr is shown to Claude), `PermissionRequest`, `PermissionDenied`, `Notification`, `SubagentStart`, `SessionStart`, `Setup`, `SessionEnd`, `CwdChanged`, `DirectoryAdded`, `FileChanged`, `PostCompact`, `PostModelSwitch`, `StopFailure`, `InstructionsLoaded`, `MessageDisplay` — [hooks §Exit code 2 behavior per event](https://docs.claude.com/en/docs/claude-code/hooks)
- Timeout behavior: a timed-out `command`/`http`/`mcp_tool` hook renders no decision on most events and **does not block a `PreToolUse` tool call** — "don't count on a stalled hook to act as a gate." On `PreModelSwitch` a timeout *does* block — [hooks §Timeouts](https://docs.claude.com/en/docs/claude-code/hooks)

**Universal JSON output fields** — `continue` (default `true`; `false` stops Claude entirely and takes precedence over event-specific decisions), `stopReason`, `suppressOutput` (accepted but has no effect), `systemMessage`, `terminalSequence` (restricted to OSC 0/1/2/9/99/777 and BEL) — [hooks §JSON output](https://docs.claude.com/en/docs/claude-code/hooks)

**Blocking a tool call (`PreToolUse` decision control)** — decision goes in `hookSpecificOutput`, not top-level:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Database writes are not allowed"
  }
}
```
`permissionDecision` accepts `allow`, `deny`, `ask`, `defer`. Reason visibility: for `allow`/`ask` shown to the user but not Claude; for `deny` shown to Claude; for `defer` ignored. `updatedInput` replaces the entire tool input object (include unchanged fields). Multi-hook precedence is **`deny` > `defer` > `ask` > `allow`**. Deny and ask permission rules are still evaluated regardless of what the hook returns — [hooks §PreToolUse decision control](https://docs.claude.com/en/docs/claude-code/hooks)
- **Deprecation flag:** "PreToolUse previously used top-level `decision` and `reason` fields, but these are deprecated for this event… The deprecated values `"approve"` and `"block"` map to `"allow"` and `"deny"`." Other events like PostToolUse and Stop continue to use top-level `decision`/`reason` — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)
- `"defer"` is honored **only in non-interactive `-p` mode**; interactive sessions log a warning and ignore it — [hooks §Defer a tool call for later](https://docs.claude.com/en/docs/claude-code/hooks)

**Injecting context** — `hookSpecificOutput.additionalContext` is wrapped in a system reminder and inserted where the hook fired:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "This file is generated. Edit src/schema.ts and run `bun generate` instead."
  }
}
```
Placement by event: `SessionStart`/`SubagentStart` → start of conversation; `UserPromptSubmit`/`UserPromptExpansion` → alongside the prompt; `PreToolUse`/`PostToolUse`/`PostToolUseFailure`/`PostToolBatch` → next to the tool result; `Stop`/`SubagentStop` → end of turn (conversation continues); `PostModelSwitch` → next request. Values over 10,000 characters are written to a file and passed as a path plus preview. **Style guidance from the docs:** "Write the text as factual statements rather than imperative system instructions… Text framed as out-of-band system commands can trigger Claude's prompt-injection defenses." — [hooks §Add context for Claude](https://docs.claude.com/en/docs/claude-code/hooks)

**PostToolUse decision control** — fields: `decision: "block"` (adds `reason` next to the tool result; Claude still sees the original output), `reason`, `additionalContext`, `classifierContext` (note for the auto-mode classifier, v2.1.236+, capped at 2,000 chars per tool call), `updatedToolOutput` (must match the tool's output shape), `updatedMCPToolOutput` (legacy; prefer `updatedToolOutput`) — [hooks §PostToolUse decision control](https://docs.claude.com/en/docs/claude-code/hooks)

**Stop / SubagentStop decision control** — `decision: "block"` + required `reason` prevents stopping; `hookSpecificOutput.additionalContext` gives non-error feedback that also continues the conversation but is labeled `Stop hook feedback` instead of a hook error. Loop protection: `stop_hook_active` input field, and **Claude Code overrides the hook and ends the turn after 8 consecutive blocks** — [hooks §Stop decision control](https://docs.claude.com/en/docs/claude-code/hooks)
- Stop input also carries `last_assistant_message` (use this rather than reading `transcript_path`, which lags), plus `background_tasks[]` and `session_crons[]` arrays — [hooks §Stop input](https://docs.claude.com/en/docs/claude-code/hooks)

**SessionStart** — matchers `startup`, `resume`, `clear`, `compact`, `fork` (forked sessions reported `"resume"` before v2.1.214). Only `type: "command"` and `type: "mcp_tool"` handlers are supported. Decision control is context-only, with additional fields `initialUserMessage`, `watchPaths`, `sessionTitle`, `reloadSkills` — [hooks §SessionStart](https://docs.claude.com/en/docs/claude-code/hooks)

**Worked example — the self-verifying coding agent's core hook (copy-pasteable)**

`.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/verify-edit.sh",
            "args": [],
            "timeout": 180,
            "statusMessage": "Linting and testing the change..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/gate-stop.sh",
            "args": [],
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

`.claude/hooks/verify-edit.sh` (make executable with `chmod +x`):
```bash
#!/usr/bin/env bash
# PostToolUse hook: format, lint, and test the file Claude just edited.
# Contract: exit 0 + JSON on stdout. decision:"block" feeds the failure text
# back to Claude next to the tool result so it fixes it on the next turn.
set -uo pipefail

input=$(cat)
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[[ -z "$file" || ! -f "$file" ]] && exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;                      # not our language; stay silent
esac

cd "$CLAUDE_PROJECT_DIR" || exit 0

out=""
fail=0

# 1. Format in place (side effect, not reported unless it errors)
if ! fmt=$(npx --no-install prettier --write "$file" 2>&1); then
  out+="prettier failed:\n$fmt\n\n"; fail=1
fi

# 2. Lint just this file
if ! lint=$(npx --no-install eslint --max-warnings=0 "$file" 2>&1); then
  out+="eslint reported problems in $file:\n$lint\n\n"; fail=1
fi

# 3. Run only the tests related to this file (fast feedback)
if ! test=$(npx --no-install jest --findRelatedTests "$file" --passWithNoTests --silent 2>&1); then
  out+="Related tests failed for $file:\n$test\n"; fail=1
fi

if [[ $fail -eq 1 ]]; then
  jq -n --arg r "$out" '{decision:"block", reason:$r}'
  exit 0            # exit 0 + JSON: structured feedback, not a hook error
fi

jq -n '{hookSpecificOutput:{hookEventName:"PostToolUse",
        additionalContext:"Lint and related tests pass for this file."}}'
exit 0
```

`.claude/hooks/gate-stop.sh` — the "don't stop until the suite is green" gate:
```bash
#!/usr/bin/env bash
# Stop hook: refuse to end the turn while the full test suite is red.
set -uo pipefail
input=$(cat)

# Loop guard: Claude Code also caps this at 8 consecutive blocks.
if [[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || exit 0
if ! result=$(npm test --silent 2>&1); then
  jq -n --arg r "The test suite is failing. Fix it before finishing:
$result" '{decision:"block", reason:$r}'
  exit 0
fi
exit 0
```

**Debugging hooks** — `/hooks` opens a read-only browser showing every configured hook with its source (`User Settings`, `Project Settings`, `Local Settings`, `Plugin Hooks`, `Session Hooks`) and full command/prompt/URL. It cannot edit. `disableAllHooks: true` turns all non-managed hooks off; there is **no way to disable an individual hook** while keeping it in configuration — [hooks §The /hooks menu, §Disable or remove hooks](https://docs.claude.com/en/docs/claude-code/hooks)
- A hook whose script path is wrong exits 127 and produces `Failed with non-blocking status code: /bin/sh: /path/to/hook.sh: No such file or directory` — "a mistyped path in `settings.json` leaves the gate silently disabled." — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)
- Official reference implementation: [bash_command_validator_example.py](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py) — linked from [hooks](https://docs.claude.com/en/docs/claude-code/hooks)

### Inferences
- The correct pattern for a self-verifying agent is a **two-tier gate**: a fast per-file `PostToolUse` hook (format + lint + related tests only) plus a slow `Stop` hook running the full suite. Putting the full suite in `PostToolUse` multiplies its cost by the number of edits and will hit the 600s default timeout on large repos.
- `decision: "block"` on `PostToolUse` is preferable to exit 2 for verification feedback because exit 2 renders as a hook *error* while `block` renders as feedback, and because JSON lets you attach the full tool output as `reason` without stderr-length ambiguity.
- The `if` field is explicitly best-effort ("use the permission system rather than a hook to enforce a hard allow or deny"), so security gates belong in `permissions.deny`, and hooks should be used for verification and context injection.

### Gaps
- I did not read the full input schemas for the newer events (`PostToolBatch`, `FileChanged`, `WorktreeCreate`, `TaskCreated`, `MessageDisplay`, `PreModelSwitch`); the hooks reference documents each one in its own section at https://docs.claude.com/en/docs/claude-code/hooks if the report needs them.
- I did not verify the `prompt` and `agent` hook handler field schemas in detail (lines 608–617 of the hooks reference); the docs describe `agent` hooks as "experimental and may change."

---

## Slash commands: format, frontmatter, substitution, `!` and `@`

### Takeaway
The `slash-commands` docs page now **redirects to the skills page** — I verified byte-for-byte that `docs.claude.com/en/docs/claude-code/slash-commands.md` and `.../skills.md` return identical content. Custom slash commands are officially "merged into skills": `.claude/commands/*.md` still works and is described as "the older format," supporting the same frontmatter as skills **except `name` and `paths`**.

### Cited Findings
- "**Custom commands have been merged into skills.** A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way. Your existing `.claude/commands/` files keep working." — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- "A Markdown file in `.claude/commands/` is the older format and still works. It supports the same [frontmatter](#frontmatter-reference) except `name` and `paths`… Prefer a skill for new work, since skills also support supporting files." — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- Therefore the supported command frontmatter keys are: `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `background`, `hooks`, `shell`, `metadata`, `license`, `compatibility` — derived from the skills frontmatter table minus `name` and `paths` — [skills §Frontmatter reference](https://docs.claude.com/en/docs/claude-code/skills)
- Command naming: `.claude/commands/deploy.md` → `/deploy`; `.claude/commands/frontend/component.md` → `/frontend:component` (subdirectory path with each `/` replaced by `:`) — [skills §How a skill gets its command name](https://docs.claude.com/en/docs/claude-code/skills)
- Argument substitution: `$ARGUMENTS` (full string as typed), `$ARGUMENTS[N]`, `$N` shorthand (**0-based**: `$0` first, `$1` second), `$name` from the `arguments` frontmatter list. Indexed arguments use shell-style quoting, so `/my-skill "hello world" second` gives `$0` = `hello world` — [skills §Available string substitutions, §Pass arguments to skills](https://docs.claude.com/en/docs/claude-code/skills)
- Unmatched placeholders: an indexed placeholder with no argument stays as literal text; a named placeholder with no argument expands to an empty string. If arguments are passed but no placeholder receives one, Claude Code appends `ARGUMENTS: <your input>` to the content — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- Escaping a literal `$`: prefix with a single backslash, e.g. `\$1.00`. A doubled backslash does not escape. The escape covers only argument placeholders, not `${CLAUDE_*}` variables — [skills](https://docs.claude.com/en/docs/claude-code/skills)
- `!`bash`` execution and `@file` references work the same as in skills (see the Skills section above). Note the synced-skill restriction: in non-Cowork local sessions, `@` references in a claude.ai-synced skill are **not** attached and reach Claude as literal text — [skills §How Claude Code handles the body of a synced skill](https://docs.claude.com/en/docs/claude-code/skills)
- Skill/command stacking: `/write-tests /fix-issue 123` loads both and passes `123` to each; the first skill plus up to **five more** expand, and expansion stops at the first token that isn't an inline user-invocable skill (v2.1.199+) — [skills](https://docs.claude.com/en/docs/claude-code/skills)

**Working example — a slash command (copy-pasteable)**
Save as `.claude/commands/fix.md` (or as `.claude/skills/fix/SKILL.md`, dropping nothing):

```markdown
---
description: Reproduce, fix, and verify a bug from an issue number or description.
argument-hint: "[issue-number-or-description]"
allowed-tools: Bash(npm test *) Bash(npm run lint *) Bash(git diff *) Bash(gh issue view *)
model: inherit
effort: high
disable-model-invocation: true
---

## Repo state

- Branch: !`git rev-parse --abbrev-ref HEAD`
- Uncommitted: !`git status --short`

## Conventions

@CONTRIBUTING.md

## Task

Fix: $ARGUMENTS

Work in this order and do not skip a step:

1. **Reproduce.** Write or run a test that fails because of this bug. Paste
   the failing output. If you cannot make it fail, stop and say so.
2. **Diagnose.** Identify the root cause with a `file:line` citation.
3. **Fix.** Make the smallest correct change.
4. **Verify.** Re-run the new test, then `npm test` and `npm run lint`.
   Report the actual command output, not a summary of it.
5. **Summarize.** Root cause, fix, verification evidence, residual risk.
```

### Inferences
- Since commands and skills are now the same execution path, the only reason to author a `.claude/commands/*.md` file in 2026 is compatibility with existing tooling; new work should use skill directories to get supporting files and `paths`-scoped auto-activation.
- The 0-based `$N` indexing is a real footgun for anyone porting 2024–2025 command files that assumed `$1` was the first argument. Any ported command should be converted to `$ARGUMENTS[0]`-style explicit indexing or named `arguments` to avoid silent off-by-one.

### Gaps
- I could not locate a standalone slash-commands reference page with its own frontmatter table; everything is now documented on the skills page. If the report needs a canonical "slash command frontmatter" table, it must be derived (as above) from the skills table minus `name` and `paths`.

---

## Plugins and marketplaces

### Takeaway
A plugin is a directory with an **optional** `.claude-plugin/plugin.json` manifest (only `name` is required when present) that can bundle skills, commands, agents, workflows, hooks, MCP servers, LSP servers, output styles, themes, monitors, and `bin/` executables. A marketplace is a repo with `.claude-plugin/marketplace.json` listing plugin entries with `name` + `source`. Anthropic now runs several first-party marketplaces, and a set of marketplace names is **reserved** against impersonation.

### Cited Findings

**Plugin manifest — complete schema, verbatim** — [Plugins reference §Complete schema](https://docs.claude.com/en/docs/claude-code/plugins-reference)
```json
{
  "name": "plugin-name",
  "displayName": "Plugin Name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": { "name": "Author Name", "email": "author@example.com", "url": "https://github.com/author" },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "metadata": { "catalogId": "cat-123", "tier": "pro" },
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"],
  "agents": ["./custom/agents/reviewer.md"],
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "experimental": { "themes": "./themes/", "monitors": "./monitors.json", "evals": "quality/evals" },
  "dependencies": ["helper-lib", { "name": "secrets-vault", "version": "~2.1.0" }]
}
```
- "The manifest is optional. If omitted, Claude Code auto-discovers components in default locations and derives the plugin name from the directory name." `name` is the only required field when a manifest exists — [plugins-reference](https://docs.claude.com/en/docs/claude-code/plugins-reference)
- Unrecognized top-level fields are **ignored**, so one manifest can double as a VS Code/Cursor extension manifest, npm `package.json`, or MCPB/DXT manifest. `claude plugin validate --strict` turns warnings into errors — [plugins-reference §Unrecognized fields](https://docs.claude.com/en/docs/claude-code/plugins-reference)
- `defaultEnabled: false` ships a plugin that installs disabled — [plugins-reference §Default enablement](https://docs.claude.com/en/docs/claude-code/plugins-reference)
- Note the semantics difference: `skills` **adds to** the default `skills/` scan, while `commands`, `agents`, `workflows`, `outputStyles` **replace** their defaults — [plugins-reference §Component path fields](https://docs.claude.com/en/docs/claude-code/plugins-reference)

**Default file locations inside a plugin** — [plugins-reference §File locations reference](https://docs.claude.com/en/docs/claude-code/plugins-reference)

| Component | Default location |
|---|---|
| Manifest | `.claude-plugin/plugin.json` |
| Skills | `skills/<name>/SKILL.md` |
| Commands | `commands/` (flat `.md`; use `skills/` for new plugins) |
| Agents | `agents/` |
| Workflows | `workflows/` |
| Output styles | `output-styles/` |
| Themes | `themes/` |
| Hooks | `hooks/hooks.json` |
| MCP servers | `.mcp.json` |
| LSP servers | `.lsp.json` |
| Monitors | `monitors/monitors.json` |
| Executables | `bin/` (added to the Bash tool's `PATH`, invokable as bare commands) |
| Settings | `settings.json` (**only** `agent` and `subagentStatusLine` keys supported) |

- Warning from the docs: "The `.claude-plugin/` directory contains the `plugin.json` file. All other directories (commands/, agents/, skills/, workflows/, output-styles/, themes/, monitors/, hooks/) must be at the plugin root, not inside `.claude-plugin/`." — [plugins-reference](https://docs.claude.com/en/docs/claude-code/plugins-reference)
- "A `CLAUDE.md` file at the plugin root is not loaded as project context." — [plugins-reference](https://docs.claude.com/en/docs/claude-code/plugins-reference)

**Security restriction on plugin subagents** — "For security reasons, plugin subagents don't support the `hooks`, `mcpServers`, or `permissionMode` frontmatter fields. These fields are ignored when loading agents from a plugin." — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)

**Plugin hooks file** — `hooks/hooks.json` supports an optional top-level `description`:
```json
{
  "description": "Automatic code formatting",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh", "args": [], "timeout": 30 }] }
    ]
  }
}
```
— [hooks §Reference scripts by path](https://docs.claude.com/en/docs/claude-code/hooks)

**Marketplace schema** — `.claude-plugin/marketplace.json` at the repo root. Required: `name` (kebab-case), `owner` (object with required `name`, optional `email`/`url`), `plugins` (array). Optional: `$schema`, `description`, `version`, `metadata.pluginRoot` (v2.1.239+), `allowCrossMarketplaceDependenciesOn`, `renames` (v2.1.193+). Each plugin entry requires `name` and `source` and may carry any manifest field plus `source`, `category`, `tags`, `strict`, `relevance`, `headers`, `headersHelper`, `defaultEnabled` — [Create and distribute a plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)

Verbatim marketplace example:
```json
{
  "name": "company-tools",
  "owner": { "name": "DevTools Team", "email": "devtools@example.com" },
  "plugins": [
    { "name": "code-formatter", "source": "./plugins/formatter",
      "description": "Automatic code formatting on save", "version": "2.1.0",
      "author": { "name": "DevTools Team" } },
    { "name": "deployment-tools", "source": { "source": "github", "repo": "company/deploy-plugin" },
      "description": "Deployment automation tools" }
  ]
}
```
— [plugin-marketplaces §Create the marketplace file](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)

- Plugin source types documented: relative path (`"./my-plugin"`, must start with `./` unless using `metadata.pluginRoot`), GitHub repositories, git repositories, git subdirectories, npm packages, zip archives, and **command sources** (v2.1.229+) — [plugin-marketplaces §Plugin sources](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)
- **Reserved marketplace names** (blocked for third parties): `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `claude-plugins-community`, `claude-community`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `anthropic-agent-skills`, `knowledge-work-plugins`, `life-sciences`, `claude-for-legal`, `claude-for-financial-services`, `financial-services-plugins`, `first-party-plugins`, `claude-tag-plugins`, `healthcare`. Impersonating names such as `official-claude-plugins` are also blocked — [plugin-marketplaces §Marketplace schema](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)
- CLI surface: `claude plugin init` (scaffold), `install`, `uninstall`, `prune`, `enable`, `disable`, `update`, `list`, `details`, `validate`, `eval`; plus `claude plugin marketplace add|list|remove|update` — [plugins-reference §CLI commands reference](https://docs.claude.com/en/docs/claude-code/plugins-reference), [plugin-marketplaces §Manage marketplaces from the CLI](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)
- Install scopes exist for plugins: user (default), project (shared with team), local (not shared) — [plugins-reference §plugin install](https://docs.claude.com/en/docs/claude-code/plugins-reference)
- Example install flow from the docs: `/plugin marketplace add anthropics/claude-plugins-official` then `/plugin install skill-creator@claude-plugins-official`, followed by `/reload-plugins` (or `/reload-plugins --force`) — [skills §Run evals with skill-creator](https://docs.claude.com/en/docs/claude-code/skills)
- `claude plugin eval` runs each prompt in an isolated session with and without the plugin, scores with graders, and **exits non-zero below a threshold so you can gate CI on it** — [skills §Evaluate and iterate on a skill](https://docs.claude.com/en/docs/claude-code/skills)

**Notable marketplaces worth pulling from in 2026** (GitHub API data, 2026-09-17)
- `anthropics/claude-plugins-official` — "Official, Anthropic-managed directory of high quality Claude Code Plugins." Apache-2.0, 36,470 stars, last push 2026-09-17 — https://github.com/anthropics/claude-plugins-official
- `anthropics/claude-plugins-community` — "Community plugin marketplace for Claude Cowork and Claude Code. Read-only mirror." Apache-2.0, 4,184 stars, last push 2026-08-25 — https://github.com/anthropics/claude-plugins-community
- `anthropics/knowledge-work-plugins` — Apache-2.0, 24,492 stars, 2026-09-17 — https://github.com/anthropics/knowledge-work-plugins
- `wshobson/agents` — "Multi-harness agentic plugin marketplace for Claude Code, Codex, Cursor, OpenCode, GitHub Copilot…" MIT, 39,758 stars, 2026-09-14 — https://github.com/wshobson/agents
- `obra/superpowers-marketplace` — "Curated Claude Code plugin marketplace." MIT, 1,264 stars, 2026-09-08 — https://github.com/obra/superpowers-marketplace
- `trailofbits/skills-curated` — "Curated, community-vetted Claude Code plugin marketplace." CC-BY-SA-4.0, 503 stars, 2026-07-14 — https://github.com/trailofbits/skills-curated
- `Piebald-AI/claude-code-lsps` — "Claude Code Plugin Marketplace with LSP servers." No license detected, 519 stars, 2026-07-25 — https://github.com/Piebald-AI/claude-code-lsps
- `karanb192/claude-code-hooks` — "Claude Code hooks + an installable plugin marketplace: safety, cost, observability, productivity." MIT, 517 stars, 2026-09-17 — https://github.com/karanb192/claude-code-hooks
- `davepoon/buildwithclaude` — "A single hub to find Claude Skills, Agents, Commands, Hooks, Plugins, and Marketplace collections." MIT, 3,477 stars, 2026-09-17 — https://github.com/davepoon/buildwithclaude

### Inferences
- `Piebald-AI/claude-code-lsps` is the highest-leverage marketplace for a *debugging* agent specifically, because plugin `lspServers` give Claude go-to-definition/find-references/diagnostics without burning an MCP server's tool descriptions in context.
- Because plugin subagents silently drop `hooks`, `mcpServers`, and `permissionMode`, a debugging agent that depends on those fields must be shipped as project/user agent files (or its plugin must set the hooks in `hooks/hooks.json` instead), otherwise it will appear to work but run unhooked.

### Gaps
- I did not read the `plugin-dependencies`, `plugin-relevance`, or `plugin-evals` pages in full; they are referenced from plugins-reference if needed.
- I did not verify the exact `lspServers` / `.lsp.json` schema (plugins-reference §LSP servers, lines 199–289).

---

## MCP: adding servers, scopes, and the servers worth using for debugging in 2026

### Takeaway
`claude mcp add` with `--transport http|sse|stdio` plus `--scope local|project|user` is the canonical path; project scope writes a committable `.mcp.json`, and local/user scope write to `~/.claude.json`. For debugging work the highest-value servers in 2026 are Chrome DevTools MCP (official Google), Playwright MCP (official Microsoft), Serena and mcp-language-server (semantic code intelligence via LSP), mcp-debugger (DAP-style stepping), GitHub MCP, and Sentry MCP.

### Cited Findings

**Installation commands, verbatim** — [Connect Claude Code to tools via MCP](https://docs.claude.com/en/docs/claude-code/mcp)
```bash
# Remote HTTP (recommended)
claude mcp add --transport http <name> <url>
claude mcp add --transport http notion https://mcp.notion.com/mcp
claude mcp add --transport http secure-api https://api.example.com/mcp --header "Authorization: Bearer your-token"

# Local stdio
claude mcp add [options] <name> -- <command> [args...]
claude mcp add --env AIRTABLE_API_KEY=YOUR_KEY --transport stdio airtable -- npx -y airtable-mcp-server

# WebSocket (JSON only; --transport does not accept ws)
claude mcp add-json events-server '{"type":"ws","url":"wss://mcp.example.com/socket","headers":{"Authorization":"Bearer YOUR_TOKEN"}}'
```
- **SSE is deprecated**: "The SSE (Server-Sent Events) transport is deprecated. Use HTTP servers instead, where available." As of v2.1.265 Claude Code tries HTTP first and automatically switches to SSE — [mcp](https://docs.claude.com/en/docs/claude-code/mcp)
- The `--` separator is mandatory for stdio servers; everything after it is passed to the server untouched — [mcp](https://docs.claude.com/en/docs/claude-code/mcp)
- In JSON config, `type` accepts `streamable-http` as an alias for `http`. An entry with a `url` but no `type` is a configuration error: `MCP server "<name>" has a "url" but no "type"; add "type": "http" (or "sse" / "ws") to this entry` — [mcp](https://docs.claude.com/en/docs/claude-code/mcp)

**Scopes** — [mcp §MCP installation scopes](https://docs.claude.com/en/docs/claude-code/mcp)

| Scope | Loads in | Shared | Stored in |
|---|---|---|---|
| Local (default) | Current project only | No | `~/.claude.json` under the project path |
| Project | Current project only | Yes, via version control | `.mcp.json` in project root |
| User | All your projects | No | `~/.claude.json` |

`.mcp.json` format:
```json
{ "mcpServers": { "shared-server": { "type": "http", "url": "https://example.com/mcp" } } }
```
- Precedence, highest first: local → project → user → plugin-provided → claude.ai connectors; a server delivered through the `managedMcpServers` managed setting outranks all of these (v2.1.259+). The three scopes match duplicates by name; plugins and connectors match by endpoint — [mcp §Scope hierarchy and precedence](https://docs.claude.com/en/docs/claude-code/mcp)
- Project-scoped servers prompt for approval interactively; **in `claude -p`, Agent SDK, and cloud sessions Claude Code loads them without asking.** Block with `disabledMcpjsonServers`, `--setting-sources`, or `--strict-mcp-config`. Reset approvals with `claude mcp reset-project-choices` — [mcp §Project scope](https://docs.claude.com/en/docs/claude-code/mcp)
- `.mcp.json` supports `${VAR}` and `${VAR:-default}` expansion. `CLAUDE_PROJECT_DIR` is set in the *server's* environment, not Claude Code's, so referencing it in a project `.mcp.json` `command`/`args` needs `${CLAUDE_PROJECT_DIR:-.}` — [mcp](https://docs.claude.com/en/docs/claude-code/mcp)
- Claude Code answers the MCP `roots/list` request with the launch directory plus every additional working directory, and sends `notifications/roots/list_changed` when that set changes (v2.1.203+) — [mcp](https://docs.claude.com/en/docs/claude-code/mcp)
- Scoping an MCP server to a single subagent (keeping its tool descriptions out of the main conversation) uses subagent frontmatter `mcpServers` with inline definitions — see the Subagents section — [sub-agents §Scope MCP servers to a subagent](https://docs.claude.com/en/docs/claude-code/sub-agents)

**MCP servers most useful for debugging and coding work (GitHub API data, 2026-09-17)**

| Server | URL | Stars | License | Last push | Why it matters for debugging |
|---|---|---|---|---|---|
| Chrome DevTools MCP | https://github.com/ChromeDevTools/chrome-devtools-mcp | 52,192 | Apache-2.0 | 2026-09-17 | Official Google; "Chrome DevTools for coding agents"; topics include `debugging`, `devtools`, `puppeteer` |
| Playwright MCP | https://github.com/microsoft/playwright-mcp | 37,205 | Apache-2.0 | 2026-09-17 | Official Microsoft; browser automation for reproducing UI bugs and E2E verification |
| Serena | https://github.com/oraios/serena | 29,530 | (see repo) | 2026-09-17 | "A powerful MCP toolkit for coding, providing semantic retrieval and editing capabilities — the IDE for your agent"; topics include `language-server`, `claude-code` |
| Context7 | https://github.com/upstash/context7 | 62,120 | (see repo) | 2026-09-17 | "Up-to-date code documentation for LLMs and AI code editors" — the canonical docs-MCP for avoiding stale API knowledge |
| GitHub MCP Server | https://github.com/github/github-mcp-server | 33,001 | MIT | 2026-09-16 | GitHub's official server: issues, PRs, checks, Actions logs |
| mcp-language-server | https://github.com/isaacphi/mcp-language-server | 1,593 | (see repo) | 2026-09-16 | "gives MCP enabled clients access [to] semantic tools like get definition, references, rename, and diagnostics" — LSP bridge |
| mcp-debugger | https://github.com/debugmcp/mcp-debugger | 166 | (see repo) | 2026-09-17 | "A headless, agentic debugger over MCP — let your AI agents debug running programs in seven languages" (DAP-style) |
| devtools-debugger-mcp | https://github.com/ScriptedAlchemy/devtools-debugger-mcp | 347 | (see repo) | 2026-09-04 | "exposing full Chrome DevTools Protocol debugging: breakpoints, step/run, call stacks, eval, and source maps" |
| Sentry MCP | https://github.com/getsentry/sentry-mcp | 855 | (see repo) | 2026-09-17 | Official Sentry: pull real production errors and stack traces into the session |
| codebase-memory-mcp | https://github.com/DeusData/codebase-memory-mcp | 43,655 | MIT | 2026-09-16 | "High-performance code intelligence MCP server. Indexes codebases into a persistent knowledge graph" |
| MCP Toolbox for Databases | https://github.com/googleapis/mcp-toolbox | 16,549 | Apache-2.0 | 2026-09-17 | Google's open-source database MCP server |
| embedded-debugger-mcp | https://github.com/Adancurusul/embedded-debugger-mcp | 190 | (see repo) | 2026-09-16 | probe-rs/OpenOCD debugging for ARM Cortex-M, RISC-V, Xtensa; ships both an MCP server and a Claude skill |
| awesome-mcp-servers | https://github.com/punkpeye/awesome-mcp-servers | 95,149 | MIT | 2026-09-15 | The general discovery index for MCP servers |

- `workbackai/mcp-nodejs-debugger` (303 stars) is **archived** as of the 2026-09-17 API read — https://github.com/workbackai/mcp-nodejs-debugger — prefer `mcp-debugger` or `devtools-debugger-mcp`.

### Inferences
- The best context-economics for a debugging agent is: put LSP-style code intelligence in a plugin `lspServers` entry or in a `mcpServers`-scoped subagent, and keep browser/debugger MCPs out of the main conversation entirely (subagent-inline `mcpServers`), since browser MCPs have very large tool surfaces.
- Serena and mcp-language-server overlap heavily; Serena is the higher-adoption and more actively maintained of the two by an order of magnitude in stars, but mcp-language-server is the thinner, more predictable LSP bridge if you only want diagnostics/definitions.

### Gaps
- The GitHub API responses for several repos returned no SPDX license (Serena, Context7, mcp-language-server, sentry-mcp, mcp-debugger, devtools-debugger-mcp). I did not open each LICENSE file, so licenses for those are marked "(see repo)" rather than guessed.
- I did not verify whether any of these servers publish an official `claude mcp add` one-liner in their READMEs; the report should not claim specific install commands for them without checking.

---

## Permissions, settings, and safe autonomy

### Takeaway
Autonomy in 2026 does **not** require `--dangerously-skip-permissions`: the supported alternatives are **auto mode** (a background classifier reviews commands), the **sandboxed Bash tool** (OS-level filesystem and network isolation via Seatbelt on macOS and bubblewrap + socat on Linux/WSL2) with auto-allow, and `permissions.allow/ask/deny` rules. `bypassPermissions` remains documented as "only use in isolated environments like containers or VMs."

### Cited Findings

**Permission modes** — [Configure permissions §Permission modes](https://docs.claude.com/en/docs/claude-code/permissions)

| Mode | Behavior |
|---|---|
| `default` | Prompts on first use of each tool. Labeled **Manual** in the CLI/extensions/desktop (v2.1.200+); `manual` accepted as an alias |
| `acceptEdits` | Auto-accepts file edits and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`) for paths in the working directory or `additionalDirectories` |
| `plan` | Reads files and runs read-only shell commands; doesn't edit source |
| `auto` | "Auto-approves tool calls with background safety checks that verify actions align with your request" |
| `dontAsk` | Auto-denies every call that would otherwise prompt; pre-approved tools still work |
| `bypassPermissions` | Skips prompts except the actions no mode auto-approves |

- Set the starting mode with `permissions.defaultMode`. Block dangerous modes org-wide with `permissions.disableBypassPermissionsMode` or `permissions.disableAutoMode` set to `"disable"` — most useful in managed settings where they can't be overridden — [permissions](https://docs.claude.com/en/docs/claude-code/permissions)
- Warning, verbatim: "In `bypassPermissions` mode, Claude Code skips permission prompts, including for writes to protected paths such as `.git` and `.claude`… Only use this mode in isolated environments like containers or VMs where Claude Code can't cause damage." — [permissions](https://docs.claude.com/en/docs/claude-code/permissions)

**Permission rule syntax** — format is `Tool` or `Tool(specifier)`; parentheses inside the specifier are literal. `Bash(*)` ≡ `Bash`. As a deny rule, both forms remove the tool from Claude's context — [permissions §Permission rule syntax](https://docs.claude.com/en/docs/claude-code/permissions)
```json
{ "permissions": {
    "allow": ["Bash(npm run *)", "Bash(git commit *)"],
    "deny": ["Bash(git push *)"] } }
```
- Wildcard rules: put the `*` **after** the subcommand. `Bash(git log *)` allows only `git log`; `Bash(git *)` allows every git command. Claude Code warns at startup about an allow rule with a `*` before the subcommand. `Bash(ls *)` (with the space) matches `ls` and `ls -la` but not `lsof`; `Bash(ls*)` matches `lsof` too. `Bash(ls:*)` is an equivalent trailing-wildcard form — [permissions §Wildcard patterns](https://docs.claude.com/en/docs/claude-code/permissions)
- Compound-command awareness: recognized separators are `&&`, `||`, `;`, `|`, `|&`, `&`, and newlines; **a rule must match each subcommand independently** — [permissions §Compound commands](https://docs.claude.com/en/docs/claude-code/permissions)
- Parameter matching (deny/ask rules only): `Agent(model:opus)`, `Agent(isolation:worktree)`, `Bash(run_in_background:true)`. You cannot match a tool's primary content field this way (`command`, `file_path`, `path`, `notebook_path`, `url`) — `Bash(command:rm *)` is ignored with a startup warning — [permissions §Match by input parameter](https://docs.claude.com/en/docs/claude-code/permissions)
- Tool-name globs are allowed in deny/ask rules (`"*"`, `"mcp__*"`). Allow rules accept globs only after a literal `mcp__<server>__` prefix; an unanchored allow glob is skipped with a warning — [permissions §Tool name wildcards](https://docs.claude.com/en/docs/claude-code/permissions)
- Disable a subagent: `{"permissions": {"deny": ["Agent(Explore)", "Agent(my-custom-agent)"]}}` — [sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
- Skill permissions: `Skill(commit)` for exact match, `Skill(review-pr *)` for prefix match; deny the `Skill` tool to disable all skills — [skills §Restrict Claude's skill access](https://docs.claude.com/en/docs/claude-code/skills)

**Sandboxing (the 2026 answer to `--dangerously-skip-permissions`)** — [Configure the sandboxed Bash tool](https://docs.claude.com/en/docs/claude-code/sandboxing)
- Built into Claude Code; runs on macOS (Seatbelt, nothing to install), Linux and WSL2 (requires `bubblewrap` + `socat`). **Native Windows is not supported** — run inside WSL2
- Two modes: **auto-allow** (sandboxed commands run without prompting) and **regular permissions** (prompts even when sandboxed). Both enforce the same filesystem and network restrictions
- Even in auto-allow mode: explicit deny rules are always respected; `rm`/`rmdir` against a critical path still goes through the regular flow; content-scoped ask rules like `Bash(git push *)` still prompt
- Default writable set: the working directory, the session temp directory, and `--add-dir`/`additionalDirectories` directories. `$TMPDIR` is redirected to the session temp directory for sandboxed commands
- Configuration example, verbatim:
  ```json
  { "sandbox": { "enabled": true, "filesystem": { "allowWrite": ["~/.kube", "/tmp/build"] } } }
  ```
  and for read isolation:
  ```json
  { "sandbox": { "enabled": true, "filesystem": { "denyRead": ["~/"], "allowRead": ["."] } } }
  ```
  Filesystem arrays **merge** across settings scopes. Path prefixes: `/` absolute, `~/` home-relative, `./` or bare = project root for project settings or `~/.claude` for user settings — note this differs from Read/Edit permission rules, which use `//path` for absolute
- **Strict sandbox mode**: `"allowUnsandboxedCommands": false` disables the `dangerouslyDisableSandbox` escape hatch, so every command Claude runs must run sandboxed unless listed in `excludedCommands`
- One-session override without touching settings files: `claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false}}'`
- `"sandbox": {"failIfUnavailable": true}` turns a missing sandbox into a hard failure instead of a warning — "intended for managed deployments that require sandboxing as a security gate"
- To be prompted on every unsandboxed retry even in auto mode, add an ask rule for `Bash(dangerouslyDisableSandbox:true)`

**Settings files** — hooks and permissions live in `~/.claude/settings.json` (user), `.claude/settings.json` (project, committable), `.claude/settings.local.json` (project, gitignored when Claude Code writes to it), and managed policy settings (org). Settings lists **merge** rather than override across levels — [Settings files and precedence](https://docs.claude.com/en/docs/claude-code/settings), [hooks §Hook locations](https://docs.claude.com/en/docs/claude-code/hooks)
- Relevant settings keys confirmed in the settings reference index: `permissions` (`allow`, `ask`, `deny`, `additionalDirectories`, `blockReadsOutsideWorkingDirectories`, `defaultMode`, `disableBypassPermissionsMode`), `autoMode`, `autoMode.classifyAllShell`, `disableAutoMode`, `allowManagedPermissionRulesOnly`, `skipDangerousModePermissionPrompt`, `sandbox` (`enabled`, `failIfUnavailable`, `autoAllowBashIfSandboxed`), `disableAllHooks`, `allowedHttpHookUrls`, `httpHookAllowedEnvVars`, `disableSkillShellExecution`, `disableBundledSkills`, `skillOverrides`, `syncClaudeAiSkills`, `strictPluginOnlyCustomization`, `agent`, `env` — [All settings](https://docs.claude.com/en/docs/claude-code/settings-reference)
- `allowManagedHooksOnly` (enterprise) blocks user/project/local/plugin hooks and narrows `statusLine`, `fileSuggestion`, `subagentStatusLine` to managed settings — [hooks §Hook locations](https://docs.claude.com/en/docs/claude-code/hooks)

**Workspace trust rules that affect agent autonomy** — a project **subagent's** frontmatter hooks and inline `mcpServers` run only after you accept the workspace trust dialog for the folder the agent file came from; a `-p` session does not count as trusted, and trusting a parent folder is not enough. User-level agents in `~/.claude/agents/` and `--agents` JSON are exempt. By contrast, a project **skill's** `allowed-tools` and frontmatter hooks are applied without workspace trust, including in an untrusted `-p` run — "A skill can grant itself broad tool access, so review the `allowed-tools` of skills checked into a repository before you run Claude Code there." — [sub-agents §Hooks in subagent frontmatter](https://docs.claude.com/en/docs/claude-code/sub-agents), [skills §Pre-approve tools for a skill](https://docs.claude.com/en/docs/claude-code/skills)

**Recommended safe-autonomy stack (assembled from the above)**
```json
{
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": ["Bash(npm run *)", "Bash(npm test *)", "Bash(git add *)", "Bash(git commit *)", "Bash(git diff *)", "Bash(git log *)"],
    "ask":   ["Bash(dangerouslyDisableSandbox:true)"],
    "deny":  ["Bash(git push *)", "Bash(rm -rf *)", "Read(./.env)", "Read(./.env.*)", "Bash(curl *)", "WebFetch"]
  },
  "sandbox": {
    "enabled": true,
    "allowUnsandboxedCommands": false,
    "filesystem": { "denyRead": ["~/"], "allowRead": ["."] }
  },
  "disableSkillShellExecution": false,
  "env": { "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH": "2" }
}
```

### Inferences
- The strongest documented autonomy posture that is *not* `bypassPermissions` is: sandbox enabled + `allowUnsandboxedCommands: false` + `permissions.defaultMode: "acceptEdits"` + a narrow `allow` list + hard `deny` on push/secrets. This gives OS-level enforcement (which hooks explicitly cannot provide) while still letting the agent edit and test freely.
- Because project-scoped `.mcp.json` servers load **without approval** in `-p`, SDK and cloud sessions, any CI/autonomous deployment should either use `--strict-mcp-config` or pin `disabledMcpjsonServers`, otherwise a repository can inject MCP servers into an unattended run.
- The asymmetry in workspace trust — project *skills* can grant themselves `allowed-tools` in untrusted folders while project *subagents* cannot run frontmatter hooks there — makes a checked-in skill the larger supply-chain risk of the two and worth an explicit review step before running Claude Code in an unfamiliar repo.

### Gaps
- I read the settings-reference index and the permission/sandbox setting names but did not read each setting's full description; the full file is 6,037 lines at https://docs.claude.com/en/docs/claude-code/settings-reference.
- I did not confirm whether `--dangerously-skip-permissions` is still an accepted CLI flag in v2.1.27x or whether it has been renamed/aliased to `--permission-mode bypassPermissions`; the docs I read refer to `bypassPermissions` as a mode and mention the flag name only in the context of subagent output scanning.

---

## Existing open-source collections worth cloning

### Takeaway
The two most directly clonable agent collections are `wshobson/agents` (now a multi-harness plugin marketplace, MIT) and `VoltAgent/awesome-claude-code-subagents` (100+ subagents, MIT); `anthropics/skills` is the authoritative skills reference; `anthropics/claude-plugins-official` is the first-party plugin marketplace. All figures below were read from the GitHub API on 2026-09-17.

### Cited Findings

| Repository | URL | Stars | License | Last push | Scale / contents | Debugging or code-review agent? |
|---|---|---|---|---|---|---|
| `wshobson/agents` | https://github.com/wshobson/agents | 39,758 | MIT | 2026-09-14 | "Multi-harness agentic plugin marketplace for Claude Code, Codex, Cursor, OpenCode, GitHub Copilot, G…" — has evolved from a flat agents repo into a marketplace | Historically ships `debugger` and `code-reviewer` agents; **not re-verified in this pass** |
| `VoltAgent/awesome-claude-code-subagents` | https://github.com/VoltAgent/awesome-claude-code-subagents | 25,151 | MIT | 2026-09-14 | "A collection of 100+ specialized Claude Code subagents covering a wide range of development use cases" | Description implies broad dev coverage; **specific debugger/reviewer agents not individually verified** |
| `hesreallyhim/awesome-claude-code` | https://github.com/hesreallyhim/awesome-claude-code | 54,215 | NOASSERTION | 2026-09-17 | "A hand-picked collection of the finest of resources" — index, not a drop-in library | Index only |
| `anthropics/skills` | https://github.com/anthropics/skills | 176,857 | none detected by API | 2026-09-10 | "Public repository for Agent Skills"; ships `package_skill.py`, referenced by the official docs as the packaging path | Authoritative skill examples; debugging agent not its purpose |
| `anthropics/claude-code` | https://github.com/anthropics/claude-code | 145,893 | none detected by API | 2026-09-17 | The product repo; hosts `examples/hooks/bash_command_validator_example.py` cited by the hooks docs | Hook reference implementations |
| `anthropics/claude-plugins-official` | https://github.com/anthropics/claude-plugins-official | 36,470 | Apache-2.0 | 2026-09-17 | "Official, Anthropic-managed directory of high quality Claude Code Plugins"; hosts `skill-creator` | Contains `skill-creator` (eval harness), per [skills docs](https://docs.claude.com/en/docs/claude-code/skills) |
| `anthropics/claude-plugins-community` | https://github.com/anthropics/claude-plugins-community | 4,184 | Apache-2.0 | 2026-08-25 | Community marketplace, read-only mirror | Mixed |
| `anthropics/defending-code-reference-harness` | https://github.com/anthropics/defending-code-reference-harness | 7,493 | NOASSERTION | 2026-08-06 | "Skills for threat modeling, scanning, triage, patching, plus an autonomous scanning harness" | **Yes** — triage/patching skills, closest first-party analogue to a debugging harness |
| `anthropics/claude-code-security-review` | https://github.com/anthropics/claude-code-security-review | 6,235 | MIT | 2026-02-11 | AI-powered security review GitHub Action | **Yes** — security code review; note last push 2026-02-11, comparatively stale |
| `anthropics/claude-cookbooks` | https://github.com/anthropics/claude-cookbooks | 52,770 | MIT | 2026-09-16 | Notebooks/recipes | Reference patterns |
| `anthropics/claude-code-action` | https://github.com/anthropics/claude-code-action | 8,896 | MIT | 2026-09-17 | Official GitHub Action | CI integration |
| `ComposioHQ/awesome-claude-skills` | https://github.com/ComposioHQ/awesome-claude-skills | 75,277 | none detected | 2026-08-10 | Curated skills list | Index only |
| `VoltAgent/awesome-agent-skills` | https://github.com/VoltAgent/awesome-agent-skills | 34,508 | MIT | 2026-09-15 | "1000+ agent skills from official dev teams and the community" | Large; quality varies |
| `VoltAgent/awesome-openclaw-skills` | https://github.com/VoltAgent/awesome-openclaw-skills | 52,618 | MIT | 2026-09-14 | "5,400+ skills filtered and categorized" | Very large; quality varies |
| `obra/superpowers-marketplace` | https://github.com/obra/superpowers-marketplace | 1,264 | MIT | 2026-09-08 | Curated plugin marketplace | Curated, small |
| `trailofbits/skills-curated` | https://github.com/trailofbits/skills-curated | 503 | CC-BY-SA-4.0 | 2026-07-14 | "Curated, community-vetted Claude Code plugin marketplace" from a security firm | Security review focus; strongest vetting signal of the community marketplaces |
| `Piebald-AI/claude-code-lsps` | https://github.com/Piebald-AI/claude-code-lsps | 519 | none detected | 2026-07-25 | Plugin marketplace of LSP servers | **Directly relevant to debugging** (diagnostics, go-to-def) |
| `karanb192/claude-code-hooks` | https://github.com/karanb192/claude-code-hooks | 517 | MIT | 2026-09-17 | Hooks + installable marketplace: "safety, cost, observability, productivity" | Hook library for verification/observability |
| `mhattingpete/claude-skills-marketplace` | https://github.com/mhattingpete/claude-skills-marketplace | 673 | Apache-2.0 | 2026-07-25 | "Git automation, testing, and code review" skills | **Yes** — explicitly includes code review |
| `davepoon/buildwithclaude` | https://github.com/davepoon/buildwithclaude | 3,477 | MIT | 2026-09-17 | Hub for Skills, Agents, Commands, Hooks, Plugins, Marketplaces | Discovery index |
| `shanraisshan/claude-code-best-practice` | https://github.com/shanraisshan/claude-code-best-practice | 66,047 | MIT | 2026-09-17 | "from vibe coding to agentic engineering" | Practices, not components |
| `luongnv89/claude-howto` | https://github.com/luongnv89/claude-howto | 41,536 | MIT | 2026-09-06 | "visual, example-driven guide… with copy-pa[ste]" examples | Tutorial/examples |

**Quality assessment signals used:** license presence, last-push recency (all but `claude-code-security-review` and `ananddtyagi/cc-marketplace` were pushed within ~6 weeks of 2026-09-17), maintainer identity (Anthropic, Trail of Bits, Microsoft, Google carry institutional maintenance signal), and whether the repo is a curated index versus a directly installable component library.

### Inferences
- For a debugging/coding agent build, the pragmatic clone set is: `anthropics/claude-plugins-official` (install `skill-creator` for the eval loop), `anthropics/defending-code-reference-harness` (closest first-party triage/patch harness), `Piebald-AI/claude-code-lsps` (code intelligence), `karanb192/claude-code-hooks` (verification hooks), and `wshobson/agents` or `VoltAgent/awesome-claude-code-subagents` as a source of individual agent definitions to copy and edit rather than install wholesale.
- `trailofbits/skills-curated` is the only community marketplace with an explicit security-vetting claim from a recognized security firm, which matters because a checked-in skill's `allowed-tools` grant bypasses workspace trust.
- Repos that are "awesome lists" (hesreallyhim, ComposioHQ, VoltAgent/awesome-agent-skills, punkpeye) have very high star counts but are indexes; star count is not a quality signal for the components they link to.

### Gaps
- **I did not open the file trees of `wshobson/agents` or `VoltAgent/awesome-claude-code-subagents`**, so I cannot confirm from a primary source that they currently contain a `debugger.md` or `code-reviewer.md`, nor their current agent counts beyond what the repo descriptions state (VoltAgent: "100+"). The GitHub API in this session refused direct repo reads (`GitHub access to this repository is not enabled for this session`), so these should be verified by cloning before adoption.
- The GitHub API returned no SPDX license for `anthropics/skills` and `anthropics/claude-code`; both are Anthropic-published but I did not read their LICENSE files, so I have not asserted a license for them.
- Star counts as returned by the API on 2026-09-17 are unusually high for several repos (e.g. `anthropics/skills` at 176,857). I report them as retrieved; a report-writer should treat exact counts as API-reported rather than independently corroborated.

---

## Cross-cutting: CLAUDE.md and rules (supporting context)

### Takeaway
CLAUDE.md load order (broadest to most specific) is managed policy → user → project, with nested/subdirectory files loading on demand; the documented size target is **under 200 lines per file**, and `.claude/rules/` provides path-scoped rules that load only when Claude touches matching files.

### Cited Findings
- Locations: managed policy at `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS), `/etc/claude-code/CLAUDE.md` (Linux/WSL), `C:\Program Files\ClaudeCode\CLAUDE.md` (Windows); user at `~/.claude/CLAUDE.md`; project at `./CLAUDE.md` or `./.claude/CLAUDE.md` — [Memory](https://docs.claude.com/en/docs/claude-code/memory)
- "**Size**: target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence." Use path-scoped rules when instructions grow — [memory](https://docs.claude.com/en/docs/claude-code/memory)
- Imports use `@path/to/import`, resolve relative to the importing file, recurse to a **maximum depth of four hops**, and are skipped inside code spans and fences (so `` `@README` `` stays literal) — [memory](https://docs.claude.com/en/docs/claude-code/memory)
- `CLAUDE.local.md` at the project root loads alongside `CLAUDE.md` for private per-project preferences; gitignore it — [memory](https://docs.claude.com/en/docs/claude-code/memory)
- `/init` generates a starting CLAUDE.md; `CLAUDE_CODE_NEW_INIT=1` enables an interactive multi-phase flow that asks which artifacts to set up — CLAUDE.md files, **skills, and hooks** — explores with a subagent, and presents a reviewable proposal before writing — [memory](https://docs.claude.com/en/docs/claude-code/memory)
- `claudeMdExcludes` skips irrelevant CLAUDE.md files in monorepos — [memory](https://docs.claude.com/en/docs/claude-code/memory)
- The `InstructionsLoaded` hook event fires when a CLAUDE.md or `.claude/rules/*.md` file loads, with matchers `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` — [hooks](https://docs.claude.com/en/docs/claude-code/hooks)
- Hook docs guidance on the CLAUDE.md-vs-hook boundary: "For instructions that never change, prefer CLAUDE.md. It loads without running a script and is the standard place for static project conventions." — [hooks §Add context for Claude](https://docs.claude.com/en/docs/claude-code/hooks)

### Inferences
- The clean division of labor for a custom agent is: CLAUDE.md for static facts, `.claude/rules/` for path-scoped facts, skills for procedures, subagents for isolated workers, and hooks for anything that must happen deterministically regardless of what the model decides.

### Gaps
- I did not read the `.claude/rules/` section of the memory page in full (frontmatter/glob syntax for rule files); it is at https://docs.claude.com/en/docs/claude-code/memory under "Organize rules with .claude/rules/".
