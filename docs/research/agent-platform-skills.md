# Agent Platform — Skills, and what the platform can actually run

Contributed from the **desktop Claude Code session** ("agent platform" work, 2026-09-17).
Complements `debug-coding-agent-findings.md` and `agent-spec.md`, which came from the
cloud session and cover *agents*. This covers *skills*, plus measured findings about
what the local model-routing layer can actually reach.

No overlap with the sibling branch: it has `.claude/agents/` and `.claude/hooks/`;
this adds `.claude/skills/`.

---

## 1. The structural decision: two research modes, not one

The single most load-bearing finding. A skill named `research-agent` (v2) had been built
in an earlier session and its own frontmatter claimed:

> Supersedes the research → research-deep → research-report family and the
> multi-search-research skill.

**That claim was false for five of the six skills.** Verified by reading all seven files
end to end and diffing capability by capability, not by comparing descriptions.

There are two genuinely different research shapes:

| Shape | Unit of work | Parallelism axis | Output | Verification axis |
|---|---|---|---|---|
| **Narrative** (`research-agent`) | a sub-question | one agent per sub-question | cited essay | are the citations real? |
| **Matrix** (`research-compare`) | an entity × field grid | one agent per row | filled table | are the columns filled? |

They share an engine layer and nothing else. The verification axes in particular are
orthogonal — one checks for fabricated URLs, the other checks schema completeness. Neither
substitutes for the other.

### What was genuinely superseded

`multi-search-research` → fully absorbed by `research-agent`. Every capability maps:
engine fan-out, URL dedup, cross-engine agreement ranking, HIGH/MEDIUM/LOW credibility,
bounded one-round gap-fill, and the report shape (numbered citations, per-engine appendix
including blocked engines, gaps section). Archived, not deleted.

One topology difference did not carry over: `multi-search-research` fanned out **one agent
per engine**; `research-agent` fans out **one per sub-question**. A local SearXNG instance
makes this largely moot, since a single query hits every backend and tags each result with
the engines that found it.

### What was NOT superseded

The matrix family. `research-agent` has no equivalent for: an entity/field schema at all,
incremental schema edits, mechanical field-coverage validation, batched execution with
approval between batches, per-row resume, or a deterministic re-runnable report generator.

**Why this matters beyond research**: the same trap applies to agents. A capability claim
written into a spec is not evidence. The claim here was written by the session that built
the thing, and it was wrong in the direction that flatters the new work.

---

## 2. Skill structure decisions

### One skill with phases, not N skills with one step each

The matrix family was originally five user-invocable commands (`research`, `-deep`,
`-report`, `-add-items`, `-add-fields`). They are now **one skill, `research-compare`,
with phases** — the same shape `research-agent` already used with six phases.

Charles chose this explicitly. The recommendation on record was to defer it (working code,
regression risk, benefit mostly tidiness); he overruled it with a clear reason — he does
not want to remember and type five command names. That is a legitimate reason and it is
his call. Recording both sides because the trade is real and may need revisiting.

**The cost, and the mitigation.** Five commands are also five entry points. The thing lost
by merging is walking straight up to the middle of the pipeline ("just add a column to the
table I already have"). That is preserved by **Phase 0**, which globs for existing state on
disk, reads how far along the study is, and routes to the right phase — either inferred
from the request or by asking.

> **Generalizable**: any multi-step skill collapsed behind one entry point needs a
> state-detection phase first, or the single entry point silently costs you re-entry.

### Shared reference files: a folder with no SKILL.md

Engine recipes were duplicated across two skills and had **already drifted once** — when a
local SearXNG instance was stood up, both copies had to be corrected by hand and
hash-compared.

They now live in `.claude/skills/research-engines/ENGINES.md`. That folder deliberately has
**no `SKILL.md`**, so it does not register as an invocable skill and does not clutter the
skill list. Skills reference it by path.

> **Generalizable**: shared knowledge between skills goes in a SKILL.md-less folder,
> referenced by path. Precedent already existed in this setup (`validate_json.py` is
> referenced across skills the same way).

### Archive, don't delete — two levels deep

Retired skills go to `.claude/skills/_archive/<name>/SKILL.md`. Skills are discovered one
level below the skills root, so a folder nested inside `_archive/` is not discoverable and
cannot be invoked, while the content stays readable. `_archive/README.md` records what was
retired, why, what was absorbed, and how to undo it.

---

## 3. The YAML frontmatter trap — a real failure, worth propagating

While rewriting five skill descriptions, this was written into the frontmatter:

```yaml
description: ... Part of the research-compare pipeline (matrix mode: a known set of ...
```

That bare `: ` inside an unquoted YAML scalar **broke the frontmatter parse on all five
skills simultaneously.**

The failure mode is what makes this worth recording:

- No error. No warning. Nothing reported a problem.
- The skills still appeared in the skill list.
- Their descriptions silently fell back to the H1 heading of the document body.
- Since routing is driven by the description, all five would have mis-routed —
  invisibly, and in a way that looks like model misbehaviour rather than a config bug.

It was caught only because the rendered skill list *changed shape* unexpectedly.

**Mitigation now in place**: a parse check over every `*/SKILL.md` frontmatter after any
description edit:

```python
import yaml, pathlib
for f in pathlib.Path('.').glob('*/SKILL.md'):
    yaml.safe_load(f.read_text(encoding='utf-8').split('---')[1])   # raises if broken
```

Descriptions were rewritten to avoid `: ` entirely rather than relying on quoting, because
quoting requires escaping any internal quotes and the surrounding files use unquoted style.

> **Generalizable, and it applies to `.claude/agents/*.md` too** — agent definitions use
> the same frontmatter convention and will fail the same silent way.

---

## 4. Naming drives routing more than names suggest

`research` vs `research-agent` gave no signal about which produced a table and which
produced an essay. Worse, `research-deep` read as "deep research", which is precisely what
`research-agent` does.

Renamed the whole family to a `research-compare*` prefix, and rewrote every description to
state the output shape explicitly ("Produces a table, not an essay") and to name the
sibling skill and when to prefer it.

> **Generalizable**: when two skills/agents are adjacent in purpose, each description
> should name the other and state the tell that distinguishes them. Here the tell is:
> *comparing a known set of things → matrix; answering an open question → narrative.*

---

## 5. Tool allowlists as shipped

| Skill | `allowed-tools` |
|---|---|
| `research-agent` | Read, Write, Glob, WebSearch, WebFetch, Task, Bash, AskUserQuestion |
| `research-compare` | Read, Write, Glob, Bash, WebSearch, WebFetch, Task, AskUserQuestion |
| `research-engines` | n/a — reference file, not a skill |

Both need `Task` (parallel sub-agents), `Bash` (`research-compare` shells out to the
validator), and `AskUserQuestion` (both checkpoint with the user between phases).

---

## 6. Platform capability findings — what can actually run agents, measured

Directly relevant to "which model does the heavy lifting". The local router
(OmniRoute 3.8.50, `localhost:20128`) advertises **74 models across ~10 providers**.

A prior session had already recorded a warning that its model list is *aspirational* and
must be smoke-tested. That warning was correct. Results from sending **real prompts**, not
connection checks — note that provider connection tests passed for providers whose models
then refused every request:

| Model | Result |
|---|---|
| `groq/openai/gpt-oss-120b` | **works** — 532 ms, real completion |
| `groq/openai/gpt-oss-20b` | **works** — 280 ms |
| `ollama-local/llama3.2:3b` | works; too small for coding work |
| `antigravity/*` (Gemini 3.1 Pro, Claude Opus 4.6 Thinking) | **429** — quota exhausted |
| `opencode/*-free` (DeepSeek V4, MiMo, North Mini Code) | **401 / 403** |
| `opencode/big-pickle` | exhausted |

**74 advertised, 2 answering.**

Details that matter for planning:

- **Antigravity** holds the strongest free models on the list. Its error says
  *"quota exhausted (reset after 5m)"* — this is misleading. Retried three times across
  roughly fifteen minutes; still refused. The real window is longer than the message
  claims. Worth re-testing on a fresh day before designing around it either way.
- **The OpenCode "free" tier returns 401/403.** It now sits behind the paid plan. Any plan
  premised on "OpenCode reaches a long list of free providers" does not hold today.
- **Live misconfiguration**: routing still sends **85% of traffic to `opencode/big-pickle`**
  (exhausted) and 15% to a model returning 403. Pointing at an empty tank. Confirmed via
  `omniroute simulate`.
- Three provider keys (`360ai`, `fastrouter`, `free-ai`) are **enabled but expose zero
  models**. Two `deepseek` keys are disabled.

**Working conclusion**: the only reliable free horsepower on this machine today is
GPT-OSS 120B via Groq. Capable and fast, but one model, not a stable. Any multi-agent
design that assumes cheap parallel fan-out across many free providers is not currently
supported by what the platform can reach.

Useful method note: real model IDs were recovered from the router's
`session_model_history` table (models actually invoked), because the catalog's display
names are not routing IDs and `--output json` truncates.

---

## 7. Skills-store architecture (context for the paths above)

- Master copy: `C:\Users\Charles\.agents\skills` — a git repo, vendor-neutral on purpose
  (`.claude` dies with the tool; `.agents` does not).
- `C:\Users\Charles\.claude\skills` and the Obsidian vault skills folder are **Windows
  directory junctions** to it — one real copy, not three. A prior incident had one skill
  existing in three places with three different contents.
- Backed up to a bare repo on Google Drive; verified by cloning clean, not by trusting the
  push.
- Executable content (scripts) stays outside the Obsidian vault by rule; the vault holds
  prose only.

---

## 8. UNRECOVERABLE

- **Full inventory of the other 12 skills in the store.** Only the research-related skills
  were examined this session. Names are known (`debug-agent`, `prior-art-search`,
  `repo-safety-check`, `skill-security-auditor`, `research-methods`, `vault-handoffs`,
  `openwork-mic-patch`, and others) but their contents were not read and are not
  reproduced here.
- **The pre-consolidation text of `research`, `research-deep`, `research-report`,
  `research-add-items`, `research-add-fields`.** Their *post-rename* text is preserved in
  `.claude/skills/_archive/`. The exact original wording before renaming lives only in the
  skills repo git history (commit `eee2bb6`), which is not in this repository.
- **Why the three enabled-but-empty provider keys expose no models.** Observed, not
  diagnosed.
- **Whether the Antigravity quota is daily, rolling, or account-wide.** Only established
  that it is longer than the five minutes the error claims.
- **Any measured benchmark of GPT-OSS 120B on real coding tasks.** Only liveness and
  latency were measured here. The sibling branch's cost evidence is the better source for
  agent-level performance.

---

## 9. Open work

1. **Repoint router defaults** off `opencode/big-pickle` onto `groq/openai/gpt-oss-120b`.
   Nothing works until this is done. Not yet actioned.
2. **Re-test Antigravity on a fresh day.** It is the difference between one usable free
   model and several, and the plan differs materially between those worlds.
3. **Diagnose the three empty provider keys** — potentially widens free capacity.
4. **Add the frontmatter parse check to a hook.** The sibling branch already has
   `verify-edit.sh` on `Edit|Write`; a YAML frontmatter check for `SKILL.md` and
   `.claude/agents/*.md` belongs there. Not done — deliberately not touching their
   `settings.json` or hooks from this branch to avoid a conflict.
5. **Neither research skill has been run end to end since consolidation.** The validator
   was smoke-tested directly (passes a complete file, fails an incomplete one naming the
   missing field) and all frontmatter parses, but no full study has been executed.
   Treat `research-compare` as untested at the workflow level.
