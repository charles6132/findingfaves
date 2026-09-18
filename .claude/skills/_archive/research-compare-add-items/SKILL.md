---
name: research-compare-add-items
user-invocable: true
description: Add items (rows) to an existing comparison outline. Part of the research-compare pipeline — matrix mode, where a known set of things is compared across fixed dimensions to produce a table. For an open question answered as a cited narrative report, use research-agent instead.
allowed-tools: Bash, Read, Write, Glob, WebSearch, Task, AskUserQuestion
---

# Research Compare Add Items - Add rows

## Trigger
`/research-compare-add-items`

## Workflow

### Step 1: Auto-locate Outline
Find `*/outline.yaml` file in current working directory, auto-read.

### Step 2: Get Supplement Sources in Parallel
Simultaneously:
- **A. Ask user**: What items to supplement? Any specific names?
- **B. Ask if Web Search needed**: Launch agent to search for more items?

### Step 3: Merge and Update
- Append new items to outline.yaml
- Display to user for confirmation
- Avoid duplicates
- Save updated outline

## Output
Updated `{topic}/outline.yaml` file (in-place modification)
