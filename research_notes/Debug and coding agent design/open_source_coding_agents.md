# Open-Source Coding Agents and Agent Harnesses (state as of September 2026)

> **Data provenance note.** All star counts, licenses, primary languages, `created_at` / `pushed_at` dates and archive flags below were pulled directly from the **GitHub REST search API on 2026-09-17** unless otherwise stated. Those are primary-source facts. Narrative claims (architecture descriptions, benchmark numbers, acquisition/abandonment stories) come from the cited pages; several of those are SEO-style comparison blogs of variable quality and are flagged as such. Direct network access to arxiv.org, Wikipedia, and most vendor blogs was blocked from this environment, so paper contents are reported from search-engine summaries of those papers, not from the PDFs — treat quoted paper findings as second-hand.

---

## Q1. Which open-source coding agents are actively maintained and considered state-of-the-art in 2026?

### Takeaway
The 2026 landscape has been reordered: the projects that defined 2024–2025 (Aider, SWE-agent, Roo Code, Continue, Cody, Agentless, Moatless) are either archived, stalled, or explicitly superseded, while a new tier of TypeScript/Rust "harnesses" — OpenClaw, DeepSeek Harness, Hermes Agent, OpenCode, Pi — has absorbed most of the community. OpenHands, Codex CLI, Gemini CLI, Cline, Goose, Kilo Code and mini-SWE-agent remain the actively-developed, genuinely reusable middle of the market.

### Cited Findings — repository facts (GitHub API, 2026-09-17)

**Tier 1 — the mass-adoption harnesses (all new since late 2025):**
- `openclaw/openclaw` — **389,977 stars**, license reported by GitHub as **NOASSERTION** (no recognized SPDX identifier), TypeScript, created 2025-11-24, last push 2026-09-17. Description: "The AI that really does things. Any OS. Any Platform. The lobster way." — [GitHub API search, 2026-09-17](https://github.com/openclaw/openclaw)
- `deepseek-ai/deepseek-harness` — **227,770 stars**, **MIT**, TypeScript, created **2026-08-13**, last push 2026-09-17, 27,180 forks, 0 open issues. — [GitHub API search, 2026-09-17](https://github.com/deepseek-ai/deepseek-harness)
- `NousResearch/hermes-agent` — **246,464 stars**, **MIT**, Python, created 2025-07-22, last push 2026-09-17. Description: "The agent that grows with you." — [GitHub API search, 2026-09-17](https://github.com/NousResearch/hermes-agent)
- `anomalyco/opencode` — **208,124 stars**, **MIT**, TypeScript, created 2025-04-30, last push 2026-09-17, 27,347 forks, 5,863 open issues, 15,738 commits on `dev`. — [GitHub API search, 2026-09-17](https://github.com/anomalyco/opencode); [opencode repo page](https://github.com/anomalyco/opencode)
- `ultraworkers/claw-code` — **195,253 stars**, **MIT**, **Rust**, created 2026-03-31, last push 2026-08-16. Current description reads "An agent-managed museum exhibit, built in Rust with Gajae-Code / LazyCodex" — i.e. the repo appears to have been repurposed/frozen; a sibling `ultraworkers/claw-code-parity` (6,638 stars, Rust) is **archived** as of 2026-04-05. — [GitHub API search, 2026-09-17](https://github.com/ultraworkers/claw-code)
- `earendil-works/pi` — **106,635 stars**, **MIT**, TypeScript, created 2025-08-09, last push 2026-09-17, 13.4k forks, 6,381 commits. Self-described: "AI agent toolkit: unified LLM API, agent loop, TUI, coding agent CLI." — [GitHub API search + repo page, 2026-09-17](https://github.com/earendil-works/pi)

**Tier 2 — vendor CLIs and IDE agents, all actively developed:**
- `openai/codex` — **124,940 stars**, **Apache-2.0**, **Rust**, created 2025-04-13, last push 2026-09-17. Related first-party repos: `openai/codex-plugin-cc` (33,261 stars, Apache-2.0) and `openai/codex-security` (10,749 stars, Apache-2.0, created 2026-07-13). — [GitHub API search, 2026-09-17](https://github.com/openai/codex)
- `google-gemini/gemini-cli` — **107,035 stars**, **Apache-2.0**, TypeScript, created 2025-04-17, last push 2026-09-17. — [GitHub API search, 2026-09-17](https://github.com/google-gemini/gemini-cli)
- `OpenHands/OpenHands` — **88,307 stars**, **MIT**, TypeScript, created 2024-03-13, last push 2026-09-17; repo page shows **v1.20.0**. Org renamed from `All-Hands-AI` to `OpenHands`. — [GitHub API search + repo page, 2026-09-17](https://github.com/OpenHands/OpenHands)
- `OpenHands/software-agent-sdk` — **1,130 stars**, **MIT**, Python, created 2025-08-23, last push 2026-09-17. "A clean, modular SDK for building AI agents with OpenHands V1." This is now the Python backend; the flagship repo is the frontend/orchestrator ("Agent Canvas"). — [GitHub API search](https://github.com/OpenHands/software-agent-sdk)
- `cline/cline` — **68,647 stars**, **Apache-2.0** (© 2026 Cline Bot Inc.), TypeScript/Bun, created 2024-07-06, last push 2026-09-17, 7,336 commits, 774 open issues. — [GitHub API search + repo page](https://github.com/cline/cline)
- `aaif-goose/goose` — **54,387 stars**, **Apache-2.0**, **Rust**, created 2024-08-23, last push 2026-09-17, 5,695 commits. **Governance moved out of Block**: the repo now states it is maintained under the "Agentic AI Foundation (AAIF) at the Linux Foundation". — [GitHub API search + repo page](https://github.com/aaif-goose/goose)
- `QwenLM/qwen-code` — **27,926 stars**, **Apache-2.0**, TypeScript, created 2025-06-26, last push 2026-09-17. — [GitHub API search](https://github.com/QwenLM/qwen-code)
- `Kilo-Org/kilocode` — **27,343 stars**, **MIT**, TypeScript, created 2025-03-10, last push 2026-09-17. — [GitHub API search](https://github.com/Kilo-Org/kilocode)
- `SWE-agent/SWE-agent` — **20,344 stars**, **MIT**, Python, created 2024-04-02, last push 2026-09-14, 2,182 commits. Repo README states: "Most of our current development effort is on mini-swe-agent, which has superseded SWE-agent." — [repo page](https://github.com/SWE-agent/SWE-agent)
- `SWE-agent/mini-swe-agent` — **7,717 stars**, **MIT**, Python, created 2025-06-28, last push 2026-09-14, 1,022 commits; now at **v2** (a v1→v2 migration guide exists). — [repo page](https://github.com/SWE-agent/mini-swe-agent)

**Tier 3 — stalled, archived, acquired, or superseded (mark as historical):**
- **Aider — stalled.** `Aider-AI/aider`: 49,023 stars, Apache-2.0, Python, **last push 2026-05-22** (≈4 months of no commits at time of writing), 13,138 commits, 1,875 open issues. Reporting says the last release was **0.86.2 on 2026-02-12**, with **493 open PRs and no PRs merged since May 2026** as of 2026-09-15; maintainer Paul Gauthier replied in Oct 2025 "Unfortunately I've been occupied with other projects recently." A community fork, **`cecli` (formerly aider-ce, Apache-2.0)**, shipped **v1.5.1 on 2026-09-12** and adds MCP configuration and subagents. — [GitHub API search](https://github.com/Aider-AI/aider); [Aider future-direction issue #4751](https://github.com/Aider-AI/aider/issues/4751); [Aider Review 2026](https://swarm.beetlix.com/reviews/aider-review-2026)
- **Roo Code — archived.** `RooCodeInc/Roo-Code`: **archived = true**, 24,300 stars, Apache-2.0, last push **2026-05-15**, 3,419 forks. Shutdown announced **2026-04-21**; extension had 3M+ VS Code installs; team pivoted to "Roomote." — [GitHub API search](https://github.com/RooCodeInc/Roo-Code); [Roo Code shutdown / migration coverage](https://theaiagentindex.com/compare/roo-code-vs-kilo-code)
- **Kilo Code — acquired but still open-source.** Forked from Roo Code in 2025 (shares git history); **acquired by Anaconda in July 2026**, continues as open source; ~3M users. — [Kilo Code review 2026](https://theaiagentindex.com/agents/kilo-code)
- **Continue.dev — status contested.** `continuedev/continue`: 35,944 stars, Apache-2.0, TypeScript, **last push 2026-09-16** per the GitHub API. However, one 2026 review states Continue was **acquired by Cursor in 2026, the OSS repo is read-only, and v2.0.0 is the final release**, with the last tagged release `v1.2.22-vscode` on 2026-03-27. **These two data points conflict** — the live `pushed_at` timestamp argues against a frozen repo. Do not assert the acquisition as fact without a primary source. — [GitHub API search](https://github.com/continuedev/continue); [Continue.dev Review 2026](https://aicoderscope.com/blog/continue-dev-review-2026/)
- **Sourcegraph / Amp — no longer an open-source option.** `sourcegraph/cody-public-snapshot` (3,806 stars, Apache-2.0) is **archived**, last push 2025-08-01; `sourcegraph/sourcegraph-public-snapshot` is **archived** since 2024-09-02. Reporting states that in **December 2025 Sourcegraph spun its agent out as the independent Amp Inc.**; Amp itself has no public source repository. — [GitHub API search](https://github.com/sourcegraph/cody-public-snapshot); [State of CLI coding agents mid-2026](https://blog.arcbjorn.com/state-of-cli-coding-agents-2026)
- **Agentless — frozen research artifact.** `OpenAutoCoder/Agentless`: 2,111 stars, MIT, Python, **last push 2024-12-22**. The same lab's successor, `OpenAutoCoder/live-swe-agent` ("live, runtime self-evolving software engineering agent", 460 stars, MIT), was created 2025-11-13 and last pushed 2026-01-19. — [GitHub API search](https://github.com/OpenAutoCoder/Agentless); [Live-SWE-agent](https://github.com/OpenAutoCoder/live-swe-agent)
- **Moatless Tools — stale.** `aorwall/moatless-tools`: 643 stars, MIT, Python, **last push 2025-09-01** (a full year stale). Still cited in 2026 academic comparisons as having the largest action space in the corpus (**37 action classes**). — [GitHub API search](https://github.com/aorwall/moatless-tools); [Inside the Scaffold](https://arxiv.org/abs/2604.03515)
- **Devstral / Mistral agents — model + CLI, not a scaffold library.** Devstral was built by **Mistral AI in collaboration with All Hands AI** (the OpenHands team). **Devstral 2** is a 123B dense model, 256K context, **72.2% on SWE-bench Verified**, under a **modified MIT license**; **Devstral Small 2** scores **68.0%** and is **Apache-2.0**. Mistral shipped its own **Vibe CLI** alongside them. — [Mistral: Devstral 2 and Mistral Vibe CLI](https://mistral.ai/news/devstral-2-vibe-cli/); [Devstral launch coverage](https://venturebeat.com/ai/mistral-ai-launches-devstral-powerful-new-open-source-swe-agent-model-that-runs-on-laptops)

**Newer 2026 entrants not in the original brief:**
- **Confucius Code Agent (CCA)** — Meta/Harvard production agent, `github.com/facebookresearch/cca-swebench`, built on the "Confucius SDK", notable for **persistent note-taking for cross-session learning** and meta-agent automation. Paper: "Confucius Code Agent: Scalable Agent Scaffolding for Real-World Codebases" (arXiv 2512.10398). — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering); [arXiv 2512.10398](https://arxiv.org/pdf/2512.10398)
- **headroom** (`headroomlabs-ai/headroom`, 72,715 stars, **Apache-2.0**, Python, created 2026-01-07) — not an agent but a **context-compression layer**: "Compress tool outputs, logs, files, and RAG chunks before they reach the LLM." Listed elsewhere as cutting active tokens 60–95%. — [GitHub API search](https://github.com/headroomlabs-ai/headroom)
- **gondolin** (`earendil-works/gondolin`, 2,167 stars, Apache-2.0) — "Experimental Linux microvm setup with a TypeScript Control Plane as Agent Sandbox"; the sandbox companion to Pi. — [GitHub API search](https://github.com/earendil-works/gondolin)
- **block/berd** (920 stars, Apache-2.0, TS, created 2026-08-11) and **block/buzz** (33,667 stars, Apache-2.0, Rust) — Block's post-Goose projects.
- **deepclaude** (`aattaran/deepclaude`) — ports Claude Code's full agent loop to other backends; cited as evidence that "loop architecture — not model identity — determines agent behavior." — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)

### Cited Findings — benchmark standing
- **mini-SWE-agent scores >74% on SWE-bench Verified** and "beats Claude Code and Codex on DeepSWE"; it powers the Ramp SWE-Bench evaluation platform. Its README also records the original claim that it "achieves 65% on SWE-bench verified in 100 lines of python." — [mini-swe-agent repo](https://github.com/SWE-agent/mini-swe-agent)
- As of **December 2025**, OpenHands was reported as the strongest open-source agent on SWE-bench Verified at **72.8% with Claude 4 Sonnet**. — [SWE-bench scores and leaderboard explained (2026)](https://dev.to/rahulxsingh/swe-bench-scores-and-leaderboard-explained-2026-54of)
- Historical baseline: **OpenHands + CodeAct v2.1 (claude-3-5-sonnet-20241022) = 53.0%**, the highest checked open-source entry as of **April 2025**. — [Modal: best open-source models for SWE-bench-style agents](https://modal.com/resources/best-open-source-models-swe-bench-coding-agents)
- **April 2026 frontier reference points:** Claude Opus 4.6 at **80.8%** and Gemini 3.1 Pro at **80.6%** on SWE-bench Verified; best open-*weights* model **Qwen3-Coder-Next at 70.6%** (80B MoE, 3B active). — [Modal](https://modal.com/resources/best-open-source-models-swe-bench-coding-agents)
- The SWE-bench Verified **reference scaffold was significantly upgraded in February 2026**, which breaks comparability with pre-2026 numbers. — [SWE-bench in 2026: benchmarks vs scaffolding reality](https://www.digitalapplied.com/blog/swe-bench-verified-june-2026-benchmark-vs-scaffolding-analysis)

### Inferences
- Star counts above ~200k are no longer a useful quality signal — `deepseek-harness` went from creation (2026-08-13) to 227k stars in ~5 weeks, and OpenClaw reportedly beat React's 10-year record. Treat these as adoption/hype signals, not engineering-maturity signals. `deepseek-harness` reporting 0 open issues alongside 27k forks strongly suggests issues are disabled, which is itself a maintenance-posture signal.
- The projects worth *cloning to learn from* are not the same as the projects with the most stars. For scaffold study, the highest signal-to-noise repos are `mini-swe-agent` (minimal), `OpenHands/software-agent-sdk` (well-factored, paper-backed), `anomalyco/opencode` (documented prompt assembly), `openai/codex` (Rust, sandboxing), and `Agentless` (frozen but canonical pipeline).
- Aider's four-month commit gap plus 493 unmerged PRs means anyone depending on it should plan to move to `cecli` or vendor the repo-map code rather than the whole tool.

### Gaps
- `nus-apr/auto-code-rover` and `OpenBMB/RepoAgent` did not surface in any GitHub search run here (both fell below the star thresholds used, or were renamed). **Their 2026 star counts, licenses and last-commit dates are unverified.** AutoCodeRover is still referenced in 2026 papers as usable on live GitHub issues, but I could not confirm its repo is maintained.
- `ultraworkers/claw-code`'s current description does not match a coding agent; whether it is the canonical Rust OpenClaw port, a squatted/repurposed repo, or something else is **unresolved**.
- OpenClaw's actual license text is unknown — GitHub reports NOASSERTION, which means it is *not* a recognized OSI license file. This must be checked in-repo before lifting any code.
- No primary-source confirmation of the Continue.dev/Cursor acquisition, the Kilo/Anaconda acquisition, or the Sourcegraph→Amp Inc. spinout; all three come from secondary review sites.

---

## Q2. What is the actual agent architecture of each? (action space, context management, sub-agents, plan/execute, verification)

### Takeaway
Two architectural camps dominate: **"bash is the only tool"** minimalism (mini-SWE-agent) versus **large typed tool registries with provider-specific prompts and explicit compaction agents** (opencode, Codex, Cline, OpenHands). Nearly every 2026 harness has converged on the same seven subsystems, and the live disagreement is concentrated in context compaction and state management, not in the tool set.

### Cited Findings

**mini-SWE-agent (SWE-agent/mini-swe-agent, MIT, Python)**
- **Action space: bash only.** "Does not have any tools other than bash — it doesn't even need to use the tool-calling interface of the LMs."
- **Stateless execution:** each action runs via `subprocess.run` rather than a persistent shell session.
- **Context management: none.** "A completely linear history" — every step simply appends to the message list. The stated benefit is that the trajectory and the prompt are identical, which makes debugging and fine-tuning trivial.
- Config is YAML; MIT; currently v2 with a v1 migration guide. — [mini-swe-agent repo](https://github.com/SWE-agent/mini-swe-agent)

**SWE-agent (MIT, Python)**
- Positioned as "free-flowing & generalizable: leaves maximal agency to the LM" and "configurable & fully documented: governed by a single yaml file." v1.0 released Feb 13 (2025); the README's most recent headline result is "SWE-agent 1.0 + Claude 3.7 is SoTA on SWE-bench full" (Feb 2025 — **historical**). — [SWE-agent repo](https://github.com/SWE-agent/SWE-agent)

**OpenHands V1 (MIT; frontend TS, SDK Python)**
- Architecture is now **multi-repo**: `OpenHands/OpenHands` is the **Agent Canvas** (frontend control center + local-stack orchestration); `software-agent-sdk` is the Python backend (agents, tools, conversations, server API); plus a TypeScript client and an automation service (scheduling, webhooks, task dispatch). — [OpenHands repo page, v1.20.0](https://github.com/OpenHands/OpenHands)
- **Event-sourced state model with deterministic replay.** "Agent, Tool, LLM, and Condenser are immutable Pydantic models, with the only mutable thing in the entire system being `ConversationState`." "State changes happen by appending events — never by mutating objects." — [OpenHands Software Agent SDK paper, arXiv 2511.03690](https://arxiv.org/abs/2511.03690)
- **Condenser** is the named context-management component, a first-class immutable model in the SDK. Concrete file path: `openhands-sdk/openhands/sdk/context/condenser/no_op_condenser.py`; agent base at `openhands-sdk/openhands/sdk/agent/base.py`. — [software-agent-sdk condenser source](https://github.com/OpenHands/software-agent-sdk/blob/main/openhands-sdk/openhands/sdk/context/condenser/no_op_condenser.py)
- **V1 vs V0 (historical contrast):** "V0's monolithic, sandbox-centric design tightly coupled components and required duplicated local implementations; V1 refactors this into a modular SDK with clear boundaries, opt-in sandboxing, and reusable agent, tool, and workspace packages." Typed tool system with MCP integration. — [arXiv 2511.03690](https://arxiv.org/abs/2511.03690)
- **Multi-backend:** can drive OpenHands, Claude Code, Codex, or Gemini as the agent backend, and is **Agent-Client Protocol (ACP)** compatible. Workflow automation integrates Slack, GitHub, Linear, Notion. — [OpenHands repo page](https://github.com/OpenHands/OpenHands)

**opencode (anomalyco/opencode, MIT, TypeScript)** — the best-documented prompt/tool assembly in the corpus
- **Plan/build split as separate agents, tab-switchable.** "build" = full access, default; "plan" = read-only exploration that must request permission before running bash. — [opencode repo page](https://github.com/anomalyco/opencode)
- **Sub-agent:** a third `general` subagent handles complex searches and multi-step operations, invoked with `@general`. — [opencode repo page](https://github.com/anomalyco/opencode)
- **Compaction:** logic lives in `packages/opencode/src/session/compaction.ts`; when approaching token limits it "uses the compaction agent (no tools, its own prompt) to summarize the conversation." — [OpenCode prompt-construction gist](https://gist.github.com/rmk40/cde7a98c1c90614a27478216cc01551f)
- **Instruction discovery:** walks from cwd up to the worktree root looking for `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, plus global config dirs and `~/.claude/CLAUDE.md`. — [gist](https://gist.github.com/rmk40/cde7a98c1c90614a27478216cc01551f)
- **LSP integration** and 75+ providers; ships as terminal TUI, desktop app (macOS ARM64/Intel, Windows, Linux) and IDE extension. Reported **1.68M weekly npm downloads as of June 2026**. — [opencode repo page](https://github.com/anomalyco/opencode); [OpenCode overview](https://xcloud.host/deepseek-harness-vs-opencode/)

**OpenAI Codex CLI (openai/codex, Apache-2.0, Rust)**
- **codex-rs is a Cargo workspace of 60+ crates**, layered: user-facing entry points (interactive TUI, non-interactive `exec` mode, IDE-facing app server) over a shared core engine over platform/protocol layers. — [The codex-rs architecture](https://codex.danielvaughan.com/2026/03/28/codex-rs-rust-rewrite-architecture/)
- **Sandbox: three modes** — read-only, `workspace-write` (default), `danger-full-access` — and critically "the sandbox profile is applied to the entire process tree spawned by a tool call — not just the direct child process, which prevents tool calls from launching background workers that escape the policy." — [Codex CLI internals: queue-pair, Guardian, 3-OS sandbox](https://codex.danielvaughan.com/2026/04/10/codex-cli-internals-queue-pair-guardian-sandbox/)
- **Compaction:** "The `ContextManager` in `codex-core` tracks token counts per turn and triggers compaction automatically when the session approaches the model's context limit, spawning a `CompactTask` that replaces older messages with a structured summary, preserving recent history intact." **GPT-5.2-Codex introduced native compaction support (January 2026)** — the model itself participates in summarizing prior context rather than relying on external truncation. — [codex.danielvaughan.com](https://codex.danielvaughan.com/2026/03/28/codex-rs-rust-rewrite-architecture/)
- **Edit primitive is `apply_patch`**, split between the `codex-apply-patch` crate (parsing + validation) and an `ApplyPatchHandler` in `codex-core`. — [Apply Patch System, DeepWiki](https://deepwiki.com/openai/codex/5.4-apply-patch-system)

**Gemini CLI (Apache-2.0, TypeScript)**
- **Control loop is explicitly ReAct** — "reason about the next step, take an action by calling a tool, observe what the tool returns, then reason again."
- **Tool set:** file read/write/edit, shell commands (tests, package installs, git), web fetch, Google Search grounding, plus MCP.
- React-based TUI with "strict layout guards and PTY lifecycle management." Originally launched June 2025 on Gemini 2.5 Pro with a 1M-token context window (**historical**). — [What is Gemini CLI](https://techjacksolutions.com/ai-tools/gemini-cli/what-is-gemini-cli/); [Gemini CLI for coding in 2026](https://pickuma.com/for-dev/gemini-cli-for-coding-2026-review/)

**Qwen Code (Apache-2.0, TypeScript)**
- **Adapted from Gemini CLI**, re-optimized for Qwen3-Coder models with parser-level changes. Emphasis on local execution, **containerized subagents**, and platform-specific signed binaries (macOS notarization, ARM64). — [Qwen Code CLI](https://medium.com/@vignarajj/qwen-code-cli-the-ai-terminal-wizard-taking-on-claude-code-and-gemini-cli-0f76058a8b36); [AI CLI tools digest 2026-09](https://github.com/845421145-lang/agents-radar/issues/40)

**Cline (Apache-2.0, TypeScript/Bun)**
- **Plan mode / Act mode toggle**: "In Plan mode, Cline explores your codebase, asks clarifying questions, and lays out a strategy."
- **Tools:** file editing with diff review, bash with real-time output monitoring, web browsing, MCP servers, and custom plugins via an SDK with tools + lifecycle hooks.
- **Multi-agent teams**: a coordinator delegates subtasks to specialist agents with persistent state across sessions.
- **Checkpoints**: "All changes are tracked with checkpoints, so you can easily undo the agent's work." JetBrains plugin is closed-source. — [Cline repo page](https://github.com/cline/cline)

**Kilo Code (MIT, TypeScript)**
- Moving **from "modes" to "agents"**: four core agents — **Code, Ask, Plan, Debug**. The dedicated **Orchestrator agent is being retired** because Code/Plan/Debug can each delegate isolated work to subagents directly.
- Historical orchestrator design (**2025–early 2026**): split a task across planner → coder → debugger sub-agents. — [Kilo Code orchestrator](https://openclawdatabase.com/kilocode/orchestrator/); [Kilo Code review 2026](https://diyai.io/ai-tools/code-generation/reviews/kilo-code-review/)

**Goose (Apache-2.0, Rust)**
- General-purpose local agent across desktop/CLI/API; 15+ LLM providers; **"Connect to 70+ extensions via the Model Context Protocol."** A `workflow_recipes/` directory exists in the repo. — [Goose repo page](https://github.com/aaif-goose/goose)

**Aider (Apache-2.0, Python) — historical but still the reference for repo maps**
- **Repo map**: "Aider makes a map of your entire codebase, which helps it work well in larger projects," across 100+ languages.
- **Git-native**: auto-commits with generated messages, easy diff/undo.
- **Verification loop**: "Automatically lint and test your code every time aider makes changes." — [Aider repo page](https://github.com/Aider-AI/aider)

**Pi (earendil-works/pi, MIT, TypeScript)**
- Modular packages: `pi-ai` (multi-provider LLM abstraction), `pi-agent-core` (tool invocation + state runtime), `pi-coding-agent` (CLI), `chord` (app composition runtime for services/RPC), `pi-tui` (terminal rendering). Sandboxing via Docker or the Gondolin microVM extension. — [Pi repo page](https://github.com/earendil-works/pi)

**DeepSeek Harness (MIT, TypeScript)**
- **"Everything-is-a-plugin" architecture built on Cordis**, described as implementing "spatiotemporal composability." Explicitly in **developer preview** with "ongoing compatibility-breaking changes expected." Repo contains `.claude` and `.agents` directories, `AGENTS.md`, `BENCHMARK.md`, and benchmark vitest configs. — [deepseek-harness repo page](https://github.com/deepseek-ai/deepseek-harness)

**Research scaffolds (all historical/frozen but architecturally canonical)**
- **Agentless**: "a simplified two-phase approach for solving software development problems focused on localization and repair without relying on LLMs to make decisions."
- **AutoCodeRover**: "incorporated advanced code tools such as abstract syntax trees and spectrum-based fault localization"; runnable on live GitHub issues.
- **Moatless Tools**: "a library with support for a tree structure, the ability to revert to earlier versions of the codebase, and the capability to run tests."
- **Cost framing from 2026 literature**: "AutoCodeRover, Agentless, and RepairAgent operate in fixed phases, which makes them more cost-effective." — [Inside the Scaffold, arXiv 2604.03515](https://arxiv.org/html/2604.03515v2); [USEagent, ICSE26](https://abhikrc.com/pdf/ICSE26-USEagent.pdf)

### Cross-cutting architectural findings from the 2026 literature
- **"Inside the Scaffold: A Source-Code Taxonomy of Coding Agent Architectures"** (Benjamin Rombaut, April 2026, arXiv 2604.03515): analyses **13 open-source coding agent scaffolds at pinned commit hashes** across **12 dimensions in three layers** — control architecture, tool/environment interface, resource management. Key results:
  - **Five loop primitives** — ReAct, generate-test-repair, plan-execute, multi-attempt retry, tree search — "function as composable building blocks that **11 of 13 agents compose in different combinations** rather than relying on a single control structure."
  - **Context compaction spans seven distinct strategies**, split into "Cure" (summarize history once a token threshold is reached) and "Prevention" (structurally limit what is sent to the model each turn).
  - **Action-space size ranges from 0 (Aider) to 37 action classes (Moatless Tools).**
  - "Dimensions converge where external constraints dominate (tool capability categories, edit formats, execution isolation) and diverge where open design questions remain (context compaction, state management, multi-model routing)."
  - Every taxonomic claim is grounded in **file paths and line numbers** from cloned repos — this paper is itself the single best reusable artifact for this research question. — [arXiv 2604.03515](https://arxiv.org/abs/2604.03515)
- **"Harness Engineering: Anatomy, Architecture, and Evolution of Coding Agents — A Source-Code Study of Eleven Systems"** (arXiv 2609.00006, September 2026): source-code anatomy of **Claude Code, Codex CLI, Gemini CLI, Mistral Vibe, OpenHands, Aider, Mini-SWE-Agent, Hermes, Pi, OpenCode, and OpenClaw**, plus **Omnigent, "the first meta-harness,"** as a contrast point. Findings:
  - "An agent is a model plus a harness — the runtime that couples an LLM to the world through a **loop, tools, context management, safety controls, orchestration, and extension surfaces**." Harness engineering was "named as a discipline in early 2026."
  - "Every system in the corpus must take a position on the same **seven subsystems** — even when that position is deliberate absence."
  - **"Across roughly four million lines of Python, TypeScript, and Rust, no agent runtime imports a general-purpose agentic framework, and none retrieves code with vector embeddings; the field runs on hand-rolled async loops and deterministic retrieval."**
  - "In the first half of 2026 the coding harness completed a turn from tool to platform."
  - The paper closes with **18 design recommendations and a 90-line minimum-viable-harness scaffold** implementing ten of them. — [arXiv 2609.00006](https://arxiv.org/abs/2609.00006)

### Inferences
- The "no vector embeddings anywhere in production harnesses" finding is the single most actionable architectural datum here: it invalidates the 2023–2024 RAG-over-codebase orthodoxy and validates grep/LSP/tree-sitter/deterministic retrieval as the production default.
- The convergence on `AGENTS.md`-style filesystem-walked instruction discovery (opencode, Codex, DeepSeek Harness all ship `AGENTS.md`) makes it a de facto standard worth implementing in any new harness.
- Compaction is the genuine frontier: opencode uses a dedicated tool-less compaction *agent*, Codex uses a `ContextManager` + `CompactTask` with model-native compaction, OpenHands uses a swappable `Condenser` abstraction, and mini-SWE-agent deliberately does nothing. Those four represent the full design space and are all readable in ~a day each.

### Gaps
- I could not read the full text of either taxonomy paper (arxiv.org blocked from this environment), so the **per-agent classification tables** — which agent uses which of the seven compaction strategies, exact action-space counts per agent — are unretrieved. Anyone continuing this should pull arXiv 2604.03515 and 2609.00006 directly; both explicitly contain file-path-level tables.
- OpenClaw's and Hermes Agent's internal architectures are only characterized at a high level (OpenClaw = multi-channel gateway/control plane; Hermes = memory-first with skill self-evolution). No source-level detail retrieved.
- DeepSeek Harness's benchmark numbers exist in-repo (`BENCHMARK.md`) but were not retrievable through the page fetch.

---

## Q3. Notable scaffold innovations worth stealing

### Takeaway
The durable, transferable ideas are mostly about *constraining* the model — Agentless's fixed pipeline, SWE-agent's ACI, Aider's repo map, Codex's process-tree sandbox, opencode's read-only plan agent, OpenHands's event sourcing — rather than about adding capability.

### Cited Findings
- **Agentless: localize → repair → validate as a fixed pipeline.** "A simplified two-phase approach ... focused on localization and repair **without relying on LLMs to make decisions**." 2026 literature confirms fixed-phase agents (AutoCodeRover, Agentless, RepairAgent) are materially more cost-effective than free-flowing loops. — [Inside the Scaffold](https://arxiv.org/html/2604.03515v2); [USEagent](https://abhikrc.com/pdf/ICSE26-USEagent.pdf)
- **SWE-agent's ACI philosophy** survives as the stated design goal: "Free-flowing & generalizable: leaves maximal agency to the LM" and "Configurable & fully documented: governed by a single yaml file" — the innovation being that the entire interface is declarative config, not code. — [SWE-agent repo](https://github.com/SWE-agent/SWE-agent)
- **mini-SWE-agent's radical subtraction**: bash-only action space, stateless `subprocess.run` per action, perfectly linear history. The payoff is explicitly stated as trajectory/prompt equivalence for debugging and fine-tuning — i.e. the scaffold is designed to be an RL/SFT data generator, not just a product. — [mini-swe-agent repo](https://github.com/SWE-agent/mini-swe-agent)
- **OpenHands: event stream + deterministic replay.** Immutable Agent/Tool/LLM/Condenser Pydantic models, single mutable `ConversationState`, state advanced only by appending events. This is what makes execution "deterministic and recoverable." — [arXiv 2511.03690](https://arxiv.org/abs/2511.03690)
- **Aider's repo map**: whole-codebase map across 100+ languages plus automatic lint-and-test after every edit, plus git auto-commit as the undo primitive. — [Aider repo](https://github.com/Aider-AI/aider)
- **Cline's plan/act + checkpoints**; **opencode's plan agent is read-only and must ask permission before bash** — a stronger version of the same idea, enforced by capability rather than by prompt. — [Cline repo](https://github.com/cline/cline); [opencode repo](https://github.com/anomalyco/opencode)
- **Codex's process-tree sandbox inheritance** (policy applies to the whole spawned tree, closing the background-worker escape) and its three-tier permission model. — [Codex CLI internals](https://codex.danielvaughan.com/2026/04/10/codex-cli-internals-queue-pair-guardian-sandbox/)
- **Model-native compaction** (GPT-5.2-Codex, January 2026): the model participates in summarizing its own prior context instead of external truncation. — [codex-rs architecture](https://codex.danielvaughan.com/2026/03/28/codex-rs-rust-rewrite-architecture/)
- **Confucius Code Agent's persistent note-taking for cross-session learning** — a memory pattern distinct from both summarization and RAG. — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)
- **Tool-output compression as a separate layer**: `headroom` compresses tool outputs/logs/files before they enter the context window (claimed 60–95% active-token reduction); `context-mode` sandboxes bulky tool output *outside* the context window entirely using a "think in code" paradigm; `Token Savior` indexes by symbol via tree-sitter AST (claimed 77% token cut); `semble` replaces grep+read cycles with natural-language retrieval (claimed ~98% cut). Treat the percentages as vendor claims. — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)
- **Playwright MCP uses accessibility-tree snapshots rather than screenshots**, "dramatically reducing token cost" — the canonical example of designing a tool's *return format* for the context budget. — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)
- **State-machine guardrails**: `statewright` constrains which tools an agent may call in each workflow phase; reported to take local models "from 2/10 to 10/10" on a task. — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)
- **Meta-harnesses / self-evolution are a real 2026 category**: `Omnigent` ("the first meta-harness"), `OpenAutoCoder/live-swe-agent` (runtime self-evolving), `NousResearch/hermes-agent-self-evolution` ("Evolutionary self-improvement for Hermes Agent — optimize skills, prompts, and ..."), and papers on "Agentic Harness Engineering: Observability-Driven Automatic Evolution of Coding-Agent Harnesses" (arXiv 2604.25850) and "Harness Updating Is Not Harness Benefit: Disentangling Evolution Capabilities in Self-Evolving LLM Agents" (arXiv 2605.30621) — the latter title is a caution, not an endorsement. — [arXiv 2609.00006](https://arxiv.org/abs/2609.00006); [GitHub API search](https://github.com/NousResearch/hermes-agent-self-evolution)

### Inferences
- The highest-leverage "steal" for a debug-oriented agent is the Agentless pipeline shape plus Aider's verification loop: fixed localize→repair→validate phases with mandatory lint+test after every edit, and git commits as checkpoints. All three components are readable in permissively-licensed repos.
- The second-highest is tool-return-format engineering (accessibility trees over screenshots; symbol indexes over file dumps; compressed tool output). This is where token budgets are actually won, not in prompt wording.

### Gaps
- No primary confirmation of the specific compression percentages claimed by headroom, Token Savior, semble, or dirac — these come from a curated awesome-list's own summaries.

---

## Q4. Which projects publish their system prompts openly, and exactly where?

### Takeaway
opencode has the most completely documented prompt-assembly pipeline, with named per-provider prompt text files; Codex, Gemini CLI, Qwen Code, Cline, OpenHands and the SWE-agent family all ship prompts in-repo; and there is a large third-party corpus that aggregates extracted prompts from closed tools.

### Cited Findings — exact file paths
**opencode** (verified paths, quoted from a source-reading write-up):
- Orchestrator / agentic loop: `packages/opencode/src/session/prompt.ts`
- Environment block + provider prompt selection: `packages/opencode/src/session/system.ts`
- Instruction-file discovery (`AGENTS.md` / `CLAUDE.md` / `CONTEXT.md`, URL-based instructions): `packages/opencode/src/session/instruction.ts`
- Final assembly: `packages/opencode/src/session/llm.ts`
- **Provider-specific prompt text files in `packages/opencode/src/session/prompt/`**, selected by model-ID string match: Claude → `anthropic.txt`; GPT/o1/o3 → `beast.txt`; Gemini → `gemini.txt`; GPT-5 → `codex_header.txt`; Trinity → `trinity.txt`; default fallback → `qwen.txt`
- Agent definitions: `packages/opencode/src/agent/agent.ts`; tool framework: `packages/opencode/src/tool/tool.ts`; registry: `packages/opencode/src/tool/registry.ts`; custom tools scanned from `.opencode/tool/`
- Tool descriptions are "mostly static `.txt` files," except bash which interpolates `${directory}`, `${maxLines}`, `${maxBytes}`
- Compaction prompt/agent: `packages/opencode/src/session/compaction.ts` — [OpenCode prompt construction gist](https://gist.github.com/rmk40/cde7a98c1c90614a27478216cc01551f)

**OpenHands SDK** (verified paths):
- `openhands-sdk/openhands/sdk/context/condenser/no_op_condenser.py` (condenser family)
- `openhands-sdk/openhands/sdk/agent/base.py` (agent base class) — [software-agent-sdk](https://github.com/OpenHands/software-agent-sdk/blob/main/openhands-sdk/openhands/sdk/agent/base.py)

**Codex CLI**: user-level custom prompts live in `~/.codex/prompts/` (Codex scans only top-level Markdown files there). Repo-side, the prompt/patch machinery is in the `codex-core` and `codex-apply-patch` crates under `codex-rs/`. — [Codex CLI docs](https://developers.openai.com/codex/cli); [Apply Patch System](https://deepwiki.com/openai/codex/5.4-apply-patch-system)

**SWE-agent / mini-SWE-agent**: both are "governed by a single yaml file" / YAML config files that contain the prompt templates inline — the prompts *are* the config. — [SWE-agent repo](https://github.com/SWE-agent/SWE-agent); [mini-swe-agent repo](https://github.com/SWE-agent/mini-swe-agent)

**Third-party prompt corpora (useful, but license-encumbered):**
- `x1xhlol/system-prompts-and-models-of-ai-tools` — **143,692 stars, GPL-3.0**, last push 2026-08-11. Large aggregation of extracted system prompts from AI coding tools. **GPL-3.0 makes this unsafe to copy into permissively-licensed or proprietary code.** — [GitHub API search, 2026-09-17](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools)
- `trry-hub/opencode-cline-mode` — reimplements "the complete official Cline prompt structure" in `system-prompt/index.ts` for OpenCode. — [repo](https://github.com/trry-hub/opencode-cline-mode)
- `shareAI-lab/learn-claude-code` — 77,047 stars, MIT, last push 2026-08-26. — [GitHub API search](https://github.com/shareAI-lab/learn-claude-code)
- `ai-boost/awesome-harness-engineering` — curated index of harness patterns, context tooling, evals, permissions and orchestration with direct repo links. — [repo](https://github.com/ai-boost/awesome-harness-engineering)

### Inferences
- opencode's per-provider prompt files are the most directly liftable prompt artifacts in the ecosystem: MIT-licensed, plain `.txt`, and explicitly separated from code. The model-ID→prompt-file dispatch pattern is itself worth copying.
- Prompt-extraction repos should be treated as reference reading only. The GPL-3.0 on the largest one is a genuine contamination risk for anyone who copies text into a product.

### Gaps
- Exact in-repo prompt paths for **Cline**, **Gemini CLI**, **Qwen Code**, **Goose**, **Kilo Code**, **Pi**, **Hermes Agent** and **DeepSeek Harness** were **not verified** — repository file-listing access was unavailable from this environment, and the rendered GitHub landing pages do not expose them. These need a `git clone` + `find . -iname '*prompt*'` pass to confirm.
- The gist documenting opencode's prompt pipeline is a third-party source-reading exercise, not official docs; paths should be re-verified against the current `dev` branch (opencode has 15,738 commits and moves fast).

---

## Q5. Which projects have permissive licenses that allow lifting code and prompts?

### Takeaway
Almost the entire usable corpus is MIT or Apache-2.0, so lifting code and prompts is legally straightforward for most of it; the meaningful exceptions are OpenClaw (no recognized SPDX license), the GPL-3.0 prompt-aggregation repos, and the model weights for Devstral 2.

### Cited Findings (all license fields from the GitHub API, 2026-09-17)
**MIT (most permissive, safe to lift):** `openhands/OpenHands`, `OpenHands/software-agent-sdk`, `SWE-agent/SWE-agent`, `SWE-agent/mini-swe-agent`, `anomalyco/opencode`, `deepseek-ai/deepseek-harness`, `NousResearch/hermes-agent`, `earendil-works/pi`, `Kilo-Org/kilocode`, `OpenAutoCoder/Agentless`, `OpenAutoCoder/live-swe-agent`, `aorwall/moatless-tools`, `ultraworkers/claw-code`, `openclaw/clawhub`, `openclaw/acpx`, `openclaw/mcporter`, `shareAI-lab/learn-claude-code`.

**Apache-2.0 (permissive, patent grant, requires notice):** `openai/codex`, `openai/codex-plugin-cc`, `openai/codex-security`, `google-gemini/gemini-cli`, `QwenLM/qwen-code`, `cline/cline`, `aaif-goose/goose`, `Aider-AI/aider`, `continuedev/continue`, `RooCodeInc/Roo-Code` (archived), `headroomlabs-ai/headroom`, `earendil-works/gondolin`, `block/berd`, `block/buzz`, `ChromeDevTools/chrome-devtools-mcp`, `sourcegraph/cody-public-snapshot` (archived).

**Restrictive / unclear — do not lift without checking:**
- `openclaw/openclaw` — **NOASSERTION**: GitHub's licensing API cannot map the repo's license to a recognized SPDX identifier despite it being the most-starred project in the corpus (389,977 stars). Read `LICENSE` in-repo before any reuse.
- `x1xhlol/system-prompts-and-models-of-ai-tools` — **GPL-3.0**.
- `calesthio/OpenMontage` — AGPL-3.0 (adjacent, for completeness).
- `JuliusBrussee/caveman`, `hesreallyhim/awesome-claude-code`, `0xNyk/awesome-hermes-agent` — NOASSERTION.
- **Devstral 2 model weights ship under a "modified MIT license"** (not plain MIT); **Devstral Small 2 is Apache-2.0**. — [Mistral](https://mistral.ai/news/devstral-2-vibe-cli/)
- **Amp (Sourcegraph/Amp Inc.) has no open-source repository at all**; Cody's public snapshot is archived. — [GitHub API search](https://github.com/sourcegraph/cody-public-snapshot)
- Cline's **JetBrains plugin is closed-source** even though the core repo is Apache-2.0. — [Cline repo](https://github.com/cline/cline)

### Inferences
- For a project that wants to lift both scaffolding code and prompt text with minimal friction, the MIT cluster (mini-SWE-agent, opencode, OpenHands SDK, Agentless) is the clean set. Apache-2.0 projects (Codex, Gemini CLI, Cline, Goose) are fine too but carry NOTICE obligations.
- The single biggest legal trap in this space is copying prompts out of the GPL-3.0 aggregation repos rather than out of the original MIT/Apache repos, when the original is available anyway.

### Gaps
- Actual license *text* was not read for any repo; SPDX identifiers come from GitHub's automated detection, which is occasionally wrong (and is exactly why OpenClaw reads NOASSERTION).

---

## Q6. What do practitioners in 2026 say differentiates a good harness from a bad one?

### Takeaway
The consensus claim of 2026 is that the harness, not the model, dominates outcomes — with a widely-cited ~34-point swing on the same model — and that the differentiators are context *structure*, a small tool set, explicit error recovery, separation of plan/execute/verify, and vendor neutrality for cost.

### Cited Findings
- **Harness > model.** "The same Claude model on the same coding benchmark produced vastly different results depending on harness design — **46% with one design versus 80% with another, a 34-percentage-point swing** based entirely on the wrapper around the AI." — [Agent Harness Engineering: why your wrapper matters more than the model, MindStudio](https://www.mindstudio.ai/blog/agent-harness-engineering-wrapper-matters-more-than-model)
- **Tool count is a failure mode.** "At **107 tools**, the agent functionally fails at tasks it would ace with **10 tools**, because attention fragmentation causes the model to spend cognitive budget on tool selection rather than reasoning about the task itself." — [MindStudio](https://www.mindstudio.ai/blog/agent-harness-engineering-wrapper-matters-more-than-model)
- **Context structure beats prompt wording.** "Most practitioners spend hours on prompt wording and minutes on context structure, when context structure should take priority. A well-architected system prompt separates who the agent is, what it should do, how it should handle edge cases, and what tools it has — mixing these together into a wall of text produces inconsistent results." — [MindStudio](https://www.mindstudio.ai/blog/agent-harness-engineering-wrapper-matters-more-than-model)
- **Token cost is a harness property, not a model property.** "Two harnesses running the identical model on the identical task can differ by **4x in total tokens**, because the loop, the scaffolding, and the retry behavior are all tokens." Vendor neutrality is framed as "the single biggest cost lever available, because most enterprise tasks do not need a frontier model." — [Best open source agent harness 2026, TrueFoundry](https://www.truefoundry.com/blog/best-open-source-agent-harness)
- **Separate the grader from the doer.** "Separating planning (planner agent expands prompts into specs), execution (generator implements), and evaluation (evaluator tests and grades) creates honest feedback, **since agents rate their own work too generously**." — [MindStudio](https://www.mindstudio.ai/blog/agent-harness-engineering-wrapper-matters-more-than-model)
- **Explicit recovery strategies.** "Agents that can't handle errors gracefully are fragile, and a good harness anticipates failures and has explicit recovery strategies." — [MindStudio](https://www.mindstudio.ai/blog/agent-harness-engineering-wrapper-matters-more-than-model)
- **Multi-agent is a distributed-systems problem.** GitHub's "Multi-Agent Workflows Often Fail" (2026-02-24) argues multi-agent systems require "typed schemas, constrained action schemas, and explicit boundary validation." LangChain's decision framework reports that **"subagents process 67% fewer tokens than skills" in multi-domain scenarios.** — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)
- **Evals must be behavioral.** Anthropic's "Demystifying Evals for AI Agents" argues "unit-test-style evals fail for agents," requiring behavioral measurement instead. — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)
- **Permissions should be structured, not prose.** Anthropic's "Beyond Permission Prompts" advocates "structured permission and authorization systems into agent harnesses" rather than natural-language text. — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering)
- **Benchmarks are scaffold-confounded.** "Different submissions use different scaffolding ... and scores vary significantly based on the scaffolding and tooling around the model, not just the model itself." — [SWE-bench scores and leaderboard explained (2026)](https://dev.to/rahulxsingh/swe-bench-scores-and-leaderboard-explained-2026-54of)
- **Academic corroboration**: "Choices in control loops and context compaction critically influence agent reliability, cost profiles, and overall robustness." — [Inside the Scaffold, arXiv 2604.03515](https://arxiv.org/abs/2604.03515)
- Other named 2026 practitioner sources on this topic, not directly retrievable from this environment: Addy Osmani, "Agent Harness Engineering" (addyosmani.com/blog/agent-harness-engineering/); LangChain, "The Anatomy of an Agent Harness"; Wikipedia now has an "Agent harness" article; "Building Effective AI Coding Agents for the Terminal: Scaffolding, Harness, Context Engineering, and Lessons Learned" (arXiv 2603.05344).

### Inferences
- The "46% vs 80%" and "4x token" figures are the two numbers practitioners keep reaching for; both come from vendor-adjacent blogs rather than peer-reviewed work, so they should be cited as *claims made by practitioners*, not as measured results. The peer-reviewed version of the same claim is weaker and safer: control-loop and compaction choices dominate reliability and cost (arXiv 2604.03515).
- The practitioner consensus and the source-code evidence agree on one non-obvious point: **restraint is the differentiator.** Small tool sets, deterministic retrieval, no general-purpose agent framework, no embeddings, fixed phases where possible, and a verifier that is not the same agent as the implementer.

### Gaps
- Most of the "what practitioners say" material available through search is SEO-optimized comparison content from vendors (TrueFoundry, MindStudio, Kilo, morphllm, xcloud) with strong commercial incentives. I found **no independent, methodologically-described benchmark of harness-vs-harness on a fixed model** to substantiate the 34-point and 4x claims. Treat both as unverified.
- Several high-value primary sources (Addy Osmani's blog, LangChain's blog, openhands.dev's own blog, Wikipedia's "Agent harness" article, all arXiv PDFs) were **blocked by the network egress proxy** in this environment and could not be read directly.
