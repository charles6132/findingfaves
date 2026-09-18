# Archived skills

Retired, not deleted. Nothing here is live: skills are discovered one level below
the skills root, so a folder nested in here does not register and cannot be invoked.

## multi-search-research — retired 2026-09-17

Superseded by `research-agent`, which absorbed all of it: the engine fan-out, URL
dedup, cross-engine agreement ranking, the HIGH/MEDIUM/LOW credibility scale, the
bounded one-round gap-fill, and the report shape (numbered citations, per-engine
appendix including blocked engines, gaps section).

Its engine recipe table — the part with real operational value — was extracted to
`research-engines/ENGINES.md`, which is now the single source of truth shared by
`research-agent` and `research-compare-run`.

The one thing not carried over is its topology: it fanned out one subagent per
engine, where research-agent fans out one per sub-question. The local SearXNG
instance makes that mostly moot, since one query already hits every backend and
tags each result with the engines that found it.

## research-compare-run, -report, -add-items, -add-fields — retired 2026-09-17

Folded into `research-compare`, which is now one skill with phases (Phase 1 build,
Phase 2a/2b revise, Phase 3 run, Phase 4 report) rather than five separate commands.

Charles asked for one entry point instead of five. The capability the split gave
you — jumping straight to "just add a column" without walking the whole pipeline —
is preserved by Phase 0, which detects existing state on disk and routes to the
right phase, either from the request itself or by asking.

Everything load-bearing carried over: the two hard-constraint prompt templates,
batch_size / items_per_agent, resume-by-skipping-completed-JSONs, the
validate_json.py gate, and the full report-script spec (JSON shape compatibility,
category mapping, complex value formatting, extra-field collection, uncertain
skipping).

`validate_json.py` stays in `research-compare/` and is unchanged.
