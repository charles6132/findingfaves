---
name: research-compare-run
user-invocable: true
description: Run a comparison study — read the outline and launch one research agent per item (row), each filling the full field schema, batched and resumable. Part of the research-compare pipeline — matrix mode, where a known set of things is compared across fixed dimensions to produce a table. For an open question answered as a cited narrative report, use research-agent instead.
allowed-tools: Bash, Read, Write, Glob, WebSearch, Task
---

# Research Compare Run - Research every row

## Trigger
`/research-compare-run`

## Workflow

### Step 1: Auto-locate Outline
Find `*/outline.yaml` file in current working directory, read items list, execution config (including items_per_agent).

### Step 2: Resume Check
- Check completed JSON files in output_dir
- Skip completed items

### Step 3: Batch Execution
- Batch by batch_size (need user approval before next batch)
- Each agent handles items_per_agent items
- Launch web-search-agent (background parallel, disable task output)

**Parameter Retrieval**:
- `{topic}`: topic field from outline.yaml
- `{item_name}`: item's name field
- `{item_related_info}`: item's complete yaml content (name + category + description etc.)
- `{output_dir}`: execution.output_dir from outline.yaml (default: ./results)
- `{fields_path}`: absolute path to {topic}/fields.yaml
- Engine recipes: `~/.claude/skills/research-engines/ENGINES.md` (shared with research-agent;
  fix broken recipes there, not in this file)
- `{output_path}`: absolute path to {output_dir}/{item_name_slug}.json (slugify item_name: replace spaces with _, remove special chars)

**Hard Constraint**: The following prompt must be strictly reproduced, only replacing variables in {xxx}, do not modify structure or wording.

**Prompt Template**:
```python
prompt = f"""## Task
Research {item_related_info}, output structured JSON to {output_path}

## Field Definitions
Read {fields_path} to get all field definitions

## Search Method
Read ~/.claude/skills/research-engines/ENGINES.md and follow it. Local SearXNG at
http://127.0.0.1:8888/search?q=<q>&format=json is the primary and returns results
from many backends at once, each tagged with the engines that found it; the file
lists the direct-fetch fallbacks, which engines are blocked, and the failure ladder.
Never invent a URL. If a page could not be fetched, do not cite it.

## Output Requirements
1. Output JSON according to fields defined in fields.yaml
2. Mark uncertain field values with [uncertain]
3. Add uncertain array at the end of JSON, listing all uncertain field names
4. All field values must be in English
5. Add a sources array: the URLs each non-obvious value came from, with a
   credibility tag (HIGH/MEDIUM/LOW) per the scale in ENGINES.md

## Output Path
{output_path}

## Validation
After completing JSON output, run validation script to ensure complete field coverage:
python ~/.claude/skills/research-compare/validate_json.py -f {fields_path} -j {output_path}
Task is complete only after validation passes.
"""
```

**One-shot Example** (assuming researching GitHub Copilot):
```
## Task
Research name: GitHub Copilot
category: International Product
description: Developed by Microsoft/GitHub, first mainstream AI coding assistant, ~40% market share, output structured JSON to {project_dir}/results/GitHub_Copilot.json

## Field Definitions
Read {project_dir}/fields.yaml to get all field definitions

## Search Method
Read ~/.claude/skills/research-engines/ENGINES.md and follow it. Local SearXNG at
http://127.0.0.1:8888/search?q=<q>&format=json is the primary and returns results
from many backends at once, each tagged with the engines that found it; the file
lists the direct-fetch fallbacks, which engines are blocked, and the failure ladder.
Never invent a URL. If a page could not be fetched, do not cite it.

## Output Requirements
1. Output JSON according to fields defined in fields.yaml
2. Mark uncertain field values with [uncertain]
3. Add uncertain array at the end of JSON, listing all uncertain field names
4. All field values must be in English
5. Add a sources array: the URLs each non-obvious value came from, with a
   credibility tag (HIGH/MEDIUM/LOW) per the scale in ENGINES.md

## Output Path
{project_dir}/results/GitHub_Copilot.json

## Validation
After completing JSON output, run validation script to ensure complete field coverage:
python ~/.claude/skills/research-compare/validate_json.py -f {project_dir}/fields.yaml -j {project_dir}/results/GitHub_Copilot.json
Task is complete only after validation passes.
```

### Step 4: Wait and Monitor
- Wait for current batch to complete
- Launch next batch
- Display progress

### Step 5: Summary Report
After all complete, output:
- Completion count
- Failed/uncertain marked items
- Output directory

## Agent Config
- Background execution: Yes
- Task Output: Disabled (agent has explicit output file when complete)
- Resume support: Yes
