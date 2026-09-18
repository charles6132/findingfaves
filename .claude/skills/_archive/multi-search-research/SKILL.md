---
name: multi-search-research
user-invocable: true
allowed-tools: Read, Write, Glob, WebSearch, WebFetch, Task, Bash
description: Deep research across multiple search engines in parallel — one subagent per engine (DuckDuckGo, Bing, Brave, Yandex, Marginalia, SearXNG, Startpage), then synthesis with dedup and cross-engine agreement. Use for topics where a single engine's view is not enough, or when Charles asks for multi-engine research.
---

# Multi-Search-Engine Deep Research

## Trigger
`/multi-search <topic>` — or any request for research "across engines", "from different search engines", or "not all one style".

## Why
Different engines index and rank differently. DuckDuckGo, Bing and Brave cover the mainstream; Yandex surfaces things Western engines down-rank; Marginalia covers the small/independent web; SearXNG aggregates many backends at once. Running all of them in parallel and merging gives a wider, less filtered picture.

## Workflow

### Step 1: Prepare
- Topic + optional time range (default: unlimited)
- Build the query string (URL-encoded, quoted if multi-word)

### Step 2: Spawn subagents in parallel (one per engine)
Each subagent gets: the topic, the query, its engine's fetch recipe, and the output contract. Launch all with the Task tool in a single message.

**Engine recipes (tested 2026-09-17):**

| Engine | Recipe | Status |
|---|---|---|
| **Local SearXNG** | `http://127.0.0.1:8888/search?q=<query>&format=json` | **PRIMARY — one query, many backends.** JSON results from google cse, bing, brave, duckduckgo, qwant, yandex, yahoo, yep, baidu, naver, mwmbl and more; each result carries an `engines` list (cross-engine agreement for free). Parse `results[].url/.title/.content/.engines/.score`. Instance: `C:\Users\Charles\repos\portable-searxng` (start.bat) or the system-Python instance at `C:\Users\Charles\repos\searxng`. If down, fall back to the rows below |
| DuckDuckGo | `https://html.duckduckgo.com/html/?q=<query>` | direct fetch works |
| Bing | `https://www.bing.com/search?q=<query>&count=10` | direct fetch works |
| Brave | `https://search.brave.com/search?q=<query>` | direct fetch works |
| Mwmbl | `https://mwmbl.org/search?q=<query>` | direct fetch works (indie, community index) |
| Baidu | `https://www.baidu.com/s?wd=<query>` | direct fetch works (Chinese web) |
| Naver | `https://search.naver.com/search.naver?query=<query>` | direct fetch works (Korean web) |
| Yandex | `https://yandex.com/search/?text=<query>` | direct fetch blocked; use the browser tool to pass the JS check, or the local SearXNG (has a Yandex backend) |
| Marginalia | `https://search.marginalia.nu/search?query=<query>` | may show "wait 3 seconds"; retry once after a delay |
| SearXNG | `https://searx.tiekoetter.com/search?q=<query>` (fallback: `https://priv.au/search?q=<query>`) | public instances; results may be JS-rendered |
| Startpage | `https://www.startpage.com/sp/search?query=<query>` | often blocked (Anubis); skip gracefully and report "blocked" |

Blocked in direct-fetch testing (do not waste a subagent on them — use the local SearXNG instead): Google, Ecosia, Yahoo, Yep, Stract, Petal, Mojeek, MetaGer (now paid).

**Subagent output contract** (each returns structured text, no files):
```
ENGINE: <name>
STATUS: ok | blocked | partial
RESULTS:
1. <title> | <url> | <snippet>
... (top 5-8)
DETAIL: 1-2 sentences on the most promising result, from fetching its page
```

### Step 3: Synthesize
Merge all 7 outputs:
- **Dedup** by normalized URL (strip tracking params)
- **Cross-engine agreement**: results appearing in 2+ engines get flagged and ranked higher
- **Engine-specific findings**: anything only one engine surfaced — keep it, note which engine
- **Blocked engines**: note them in the report; do not silently drop

### Step 3.5: Credibility scoring (adopted from shandu / Grok DeepSearch)
Score every source that makes it into the report:
- **HIGH** — official/primary sources (docs, papers, vendor sites, gov/edu), or verified by 2+ engines
- **MEDIUM** — reputable secondary (established media, well-known blogs), single-engine
- **LOW** — unknown domains, forums, personal blogs, single-engine-only
Verify key claims against at least 2 independent sources when possible. Flag any claim that could only be confirmed by one source.

### Step 3.6: Gap-fill pass (adopted from shandu's iterative loop)
After synthesis, list what is still missing or weakly sourced. If gaps are material, launch a targeted second round: one subagent per gap, using the best-performing engines from round 1. Max one extra round — do not loop forever.

### Step 4: Report
Markdown report:
- Summary answer with **numbered citations** (citation ledger — every claim maps to a numbered source)
- Per-engine appendix: what each engine returned, including blocked ones
- Sources list with URLs, each tagged with its credibility score (HIGH/MEDIUM/LOW)
- Gaps section: what could not be verified, and which claims rest on a single source

## Notes
- Engines change their bot behavior; if a recipe stops working, try the browser tool, then another SearXNG instance, then skip gracefully.
- Yandex is included deliberately — it indexes differently from Western engines. Treat its results as one more signal, not as truth.
- Never claim a blocked engine returned results. Report honestly.