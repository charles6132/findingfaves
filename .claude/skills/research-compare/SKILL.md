---
name: research-compare
user-invocable: true
allowed-tools: Read, Write, Glob, Bash, WebSearch, WebFetch, Task, AskUserQuestion
description: Build a comparison table — a known set of things (items) researched across fixed dimensions (fields), one agent per row, validated for completeness, rendered into a report. Use for tool selection, vendor or framework comparison, prior-art tables, and benchmark studies. Produces a table, not an essay. For an open question answered as a cited narrative report, use research-agent instead.
---

# Research Compare

Builds a **grid**: a list of things to study (items, the rows) and a schema of
dimensions to fill in for each (fields, the columns). One research agent per row,
mechanical completeness checking, then a deterministic report.

For an open question answered as a cited narrative, use `research-agent` instead.
The tell: comparing a known set of things → here. Answering an open question → there.

## Trigger

`/research-compare <topic>` — or any comparison request: "compare X, Y and Z",
"which of these should I use", "build me a table of".

## Output layout

```
{topic_slug}/
  ├── outline.yaml        # items (rows) + execution config
  ├── fields.yaml         # field definitions (columns)
  ├── results/            # one JSON per item — this is the resume checkpoint
  │   └── {item_slug}.json
  ├── generate_report.py  # deterministic renderer, re-runnable
  └── report.md
```

---

## Phase 0 — Work out where you are

**Always run this first.** Glob for `*/outline.yaml` in the working directory.

**No outline found** → this is a new study. Go to Phase 1.

**An outline exists** → do not restart it. Read it, count the rows, count how many
JSONs are already in `results/`, then AskUserQuestion with the state as context:

- Add items (rows) → Phase 2a
- Add fields (columns) → Phase 2b
- Research the rows → Phase 3 (it skips completed ones)
- Render the report → Phase 4
- Start a different study → Phase 1

If the user's original request already says which they want ("add Cursor to the
table", "just write it up"), skip the question and go straight to that phase.

---

## Phase 1 — Build the outline

### Step 1.1: Generate initial framework from model knowledge

From the topic, generate:
- The main research objects/items in this domain
- A suggested field framework

Output `{step1_output}`, then AskUserQuestion to confirm:
- Need to add/remove items?
- Does the field framework meet requirements?

### Step 1.2: Web search supplement

AskUserQuestion for the time range (e.g. last 6 months, since 2024, unlimited).

**Parameters**:
- `{topic}`: user's research topic
- `{YYYY-MM-DD}`: current date
- `{step1_output}`: complete output from Step 1.1
- `{time_range}`: user-specified time range

**Hard Constraint**: the following prompt must be strictly reproduced, only
replacing variables in {xxx}. Do not modify structure or wording.

Launch 1 search agent in the background. (Note: the dedicated web-search-agent
type has been failing with zero output — use a general subagent with search tools.)

```python
prompt = f"""## Task
Research topic: {topic}
Current date: {YYYY-MM-DD}

Based on the following initial framework, supplement latest items and recommended research fields.

## Existing Framework
{step1_output}

## Goals
1. Verify if existing items are missing important objects
2. Supplement items based on missing objects
3. Continue searching for {topic} related items within {time_range} and supplement
4. Supplement new fields

## Search Method
Read ~/.claude/skills/research-engines/ENGINES.md and follow it.

## Output Requirements
Return structured results directly (do not write files):

### Supplementary Items
- item_name: Brief explanation (why it should be added)
...

### Recommended Supplementary Fields
- field_name: Field description (why this dimension is needed)
...

### Sources
- [Source1](url1)
- [Source2](url2)
"""
```

### Step 1.3: Ask about existing fields

AskUserQuestion whether the user has an existing field definition file. If so,
read and merge it.

### Step 1.4: Generate the two files

Merge `{step1_output}`, the search output, and any existing fields.

**outline.yaml** (items + config):
- `topic`: research topic
- `items`: research objects list
- `execution`:
  - `batch_size`: number of parallel agents (confirm with AskUserQuestion)
  - `items_per_agent`: items per agent (confirm with AskUserQuestion)
  - `output_dir`: results directory (default: `./results`)

**fields.yaml** (field definitions):
- Field categories and definitions
- Each field's `name`, `description`, `detail_level`
- `detail_level` hierarchy: brief → moderate → detailed
- `uncertain`: uncertain fields list (reserved, auto-filled in Phase 3)

The validator accepts exactly this shape:

```yaml
fields:
  <category>:
    - {name: ..., description: ..., detail_level: ...}
uncertain: []
```

### Step 1.5: Save and confirm

Create `./{topic_slug}/`, save both files, show the user for confirmation.

---

## Phase 2 — Revise the outline

Both revisions edit in place and require user confirmation before saving.

### Phase 2a — Add items (rows)

1. Locate and read `*/outline.yaml`.
2. Get supplements from both sources at once:
   - Ask the user what items to add, any specific names
   - Ask whether to launch a search agent to find more
3. Append to `outline.yaml`, avoiding duplicates. Show the user, then save.

New rows have no JSON in `results/` yet, so Phase 3 will pick them up
automatically and leave the finished rows alone.

### Phase 2b — Add fields (columns)

1. Locate and read `*/fields.yaml`.
2. Ask the user to choose a source:
   - Direct input — user provides field names and descriptions
   - Web search — launch an agent to find common fields in this domain
3. Show the suggested fields. User confirms which to add, and specifies each
   field's category and `detail_level`.
4. Append to `fields.yaml` and save.

**Important**: adding a column does not re-open rows already researched. Their
JSONs will now fail validation against the new schema. Tell the user this, and
offer to delete the affected JSONs so Phase 3 re-researches those rows with the
full column set.

---

## Phase 3 — Research every row

### Step 3.1: Locate the outline

Read `*/outline.yaml` — items list and execution config, including
`items_per_agent`.

### Step 3.2: Resume check

Check completed JSON files in `output_dir`. **Skip completed items.** This is the
resume mechanism — a crashed or interrupted run never restarts from scratch.

### Step 3.3: Batch execution

- Batch by `batch_size`; get user approval before each subsequent batch
- Each agent handles `items_per_agent` items
- Launch in the background, in parallel, with task output disabled

**Parameters**:
- `{topic}`: topic field from outline.yaml
- `{item_name}`: item's name field
- `{item_related_info}`: item's complete yaml content (name + category + description etc.)
- `{output_dir}`: `execution.output_dir` from outline.yaml (default: `./results`)
- `{fields_path}`: absolute path to `{topic}/fields.yaml`
- Engine recipes: `~/.claude/skills/research-engines/ENGINES.md` (shared with
  research-agent; fix broken recipes there, not in this file)
- `{output_path}`: absolute path to `{output_dir}/{item_name_slug}.json`
  (slugify: replace spaces with `_`, remove special chars)

**Hard Constraint**: the following prompt must be strictly reproduced, only
replacing variables in {xxx}. Do not modify structure or wording.

```python
prompt = f"""## Task
Research {item_related_info}, output structured JSON to {output_path}

## Field Definitions
Read {fields_path} to get all field definitions

## Search Method
Use only this command. Do not read any other file to find it, do not hit the
SearXNG endpoint directly, and never pipe raw format=json into the conversation:

powershell -NoProfile -File "C:\Users\Charles\.claude\skills\research-engines\search.ps1" "<query>"

It returns compact JSON: n (results available), shown, blocked (engines that
failed), r[] of {t:title, u:url, c:snippet, e:engines}. -Top defaults to 10.

Never invent a URL. If a page could not be fetched, do not cite it.

## Turn Budget
Work in EXACTLY 4 turns. The whole conversation is re-sent on every turn, so cost
scales with turns, not with how much you find:
1. Fire ALL your searches in ONE message as parallel calls. Write every query up
   front. Do not search, read, think, search again.
2. Pick the URLs worth reading from all results together, fetch them in ONE batch.
3. (Only if a real gap remains) one more batch.
4. Write the row JSON.

At most 6 searches and 6 pages for this row. Keep each fetched page under ~3000
tokens. Never re-fetch a page already in context.

## Output Requirements
1. Output JSON according to fields defined in fields.yaml
2. Mark uncertain field values with [uncertain]
3. Add uncertain array at the end of JSON, listing all uncertain field names
4. All field values must be in English
5. Add a sources array: the URLs each non-obvious value came from, with a
   credibility tag (HIGH/MEDIUM/LOW) per the scale in ENGINES.md. Credibility is
   about what the source IS, not how many engines found it.
6. Add searches_run, pages_fetched and turns_used with the real counts, reported
   honestly even if you exceeded the budget.

## Output Path
{output_path}

## Validation
After completing JSON output, run validation script to ensure complete field coverage:
python ~/.claude/skills/research-compare/validate_json.py -f {fields_path} -j {output_path}
Task is complete only after validation passes.
"""
```

### Step 3.4: Wait and monitor

Wait for the current batch, launch the next, display progress.

### Step 3.5: Summary

Report completion count, failed or uncertain-marked items, and the output directory.

### Step 3.6: Verify every cited URL

Check the whole study in ONE call:

```
powershell -NoProfile -File "C:\Users\Charles\.claude\skills\research-engines\checkurls.ps1" "{output_dir}"
```

It pulls every http(s) URL out of every result file, checks them in parallel, and
returns `checked`, `live` and a `dead` list with status codes.

For each dead URL: find the row that cites it, strike that URL, and mark the
field `[uncertain]` unless another live source in the same row supports the same
value. Re-run `validate_json.py` on any row you edit.

**This step is not optional.** Agents do fabricate URLs — a research-agent run on
2026-09-17 cited a domain that does not resolve at all, caught here in under a
second. Without this step a made-up citation reaches the final table carrying a
credibility tag, which is worse than a visible gap.

Never check URLs one at a time. This runs in the orchestrator, whose context is
the largest in the study, so each extra turn is the most expensive turn there is.

---

## Phase 4 — Render the report

### Step 4.1: Locate results

Read `*/outline.yaml` for topic and `output_dir`.

### Step 4.2: Choose summary fields

Survey the results with the script. Do **not** read every result JSON into
context to find the field names:

```
python "C:\Users\Charles\.claude\skills\research-compare\survey_fields.py" "{output_dir}"
```

It returns `rows`, `toc_candidates` (fields that are short and numeric enough for
a table of contents), `all_fields` with coverage and a sample value each, and
`budget_totals` rolling up `searches_run`, `pages_fetched` and `turns_used`
across every row.

AskUserQuestion which of the `toc_candidates` to show in the TOC beside each item
name. Build the options from what the survey actually reports, not from a guess.

Report the budget totals in the summary. A study that blew its turn budget should
be visible afterwards rather than silently expensive.

Treat `turns_used` as a floor, not a measurement. A row agent writes its file
before its last turns happen, so the recorded number runs low — measured
2026-09-17, three of four rows recorded fewer turns in the file than they
reported in their own closing message. It is a smell, not evidence.

If `toc_candidates` is empty the survey says so and offers `near_candidates`.
A study whose fields are all prose has no good summary column; omit them rather
than forcing a 500-character cell into a table of contents.

### Step 4.3: Generate the conversion script

Write `generate_report.py` into `{topic}/`. It must:

- Read all JSON from `output_dir`
- Read `fields.yaml` for field structure
- Cover every field value from every JSON
- Skip values containing `[uncertain]`
- Skip fields listed in the `uncertain` array
- Emit markdown: TOC (anchor links + the chosen summary fields) + detailed
  content by field category
- Save to `{topic}/report.md`

**TOC format**: every item, each showing number, name as an anchor link, and the
chosen summary fields. Example:
`1. [GitHub Copilot](#github-copilot) - Stars: 10k | Score: 85%`

#### Script technical requirements (must follow)

**1. JSON structure compatibility.** Support both:
- Flat: fields at top level — `{"name": "xxx", "release_date": "xxx"}`
- Nested: fields in category sub-dicts — `{"basic_info": {"name": "xxx"}, ...}`

Field lookup order: top level → category mapping key → traverse all nested dicts.

**2. Category multi-language mapping.** fields.yaml category names and JSON keys
can be any combination of languages. Establish bidirectional mapping:

```python
CATEGORY_MAPPING = {
    "Basic Info": ["basic_info", "Basic Info"],
    "Technical Features": ["technical_features", "technical_characteristics", "Technical Features"],
    "Performance Metrics": ["performance_metrics", "performance", "Performance Metrics"],
    "Milestone Significance": ["milestone_significance", "milestones", "Milestone Significance"],
    "Business Info": ["business_info", "commercial_info", "Business Info"],
    "Competition & Ecosystem": ["competition_ecosystem", "competition", "Competition & Ecosystem"],
    "History": ["history", "History"],
    "Market Positioning": ["market_positioning", "market", "Market Positioning"],
}
```

**3. Complex value formatting.**
- List of dicts (e.g. `key_events`, `funding_history`): each dict on one line,
  key/value separated with ` | `
- Normal list: short lists comma-joined; long lists with line breaks
- Nested dict: recursive formatting, semicolons or line breaks
- Long strings (over 100 chars): add `<br>` or use blockquote format

**4. Extra field collection.** Fields present in JSON but not defined in
fields.yaml go into an "Other Info" category. Filter out:
- Internal fields: `_source_file`, `uncertain`
- Nested-structure top-level keys: `basic_info`, `technical_features`, etc.
- The `uncertain` array: one field name per line, not compressed onto one line

**5. Uncertain value skipping.** Skip when:
- Value contains the `[uncertain]` string
- Field name is in the `uncertain` array
- Value is None or an empty string

### Step 4.4: Run it

`python {topic}/generate_report.py`

The script is saved alongside the results, so re-rendering after adding rows is
free — re-run it rather than regenerating the report by hand.

---

## Hard rules

- Never restart a study that already has an outline. Phase 0 exists to prevent this.
- Never re-research a row that already has a JSON, unless the schema changed.
- A row is not done until `validate_json.py` passes on it.
- Never invent a URL or a field value. Mark it `[uncertain]` instead.
- A study is not done until `checkurls.ps1` has run over `output_dir` and every
  dead URL has been struck. Fabricated citations are a measured failure mode, not
  a hypothetical one.
- Search only through `search.ps1`, and work in batches. Cost scales with turns,
  not with how much you find.
- Report what stayed uncertain. A table with silent gaps is worse than one with
  visible ones.
