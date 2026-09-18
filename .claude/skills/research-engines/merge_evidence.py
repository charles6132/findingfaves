#!/usr/bin/env python3
"""Merge per-sub-question evidence files into one numbered ledger.

    python3 merge_evidence.py <topic_slug>

Reads  {topic}/evidence/*.json
Writes {topic}/ledger.json
Prints one summary line and nothing else.

**This is a fresh implementation against the documented contract, not the
desktop original.** That script was never committed — only ENGINES.md was — so
the research skills could not run outside one Windows machine. This is written
to the behaviour specified in `research-agent/SKILL.md` phase 2 and the
credibility rules in `ENGINES.md`. If the desktop copy resurfaces, diff the two
before trusting either; where they disagree, the one with tests wins until
someone checks.

Why a script and not instructions to the model: merging is deterministic, and
the orchestrator holding the largest context in the run is the worst possible
place to do deterministic work. It reads the summary line, not the evidence.

Contract:
  - dedup by normalized URL (tracking params stripped, fragment dropped)
  - union the engines that returned each source
  - keep the HIGHEST credibility any researcher assigned
  - agreement (how many distinct engines saw it) is recorded, and NEVER
    promotes credibility. A Reddit thread found by three engines is still a
    Reddit thread.
  - number the survivors 1..n; nothing outside the ledger may be cited
"""

from __future__ import annotations

import datetime as dt
import json
import pathlib
import sys
import urllib.parse

RANK = {"HIGH": 3, "MEDIUM": 2, "LOW": 1}

# Params that identify a campaign or a click, never a document.
TRACKING_PREFIXES = ("utm_",)
TRACKING_EXACT = {
    "fbclid", "gclid", "gbraid", "wbraid", "msclkid", "dclid", "yclid",
    "igshid", "mc_cid", "mc_eid", "ref", "ref_src", "referrer", "source",
    "spm", "scid", "si", "_hsenc", "_hsmi", "vero_id", "trk", "trkCampaign",
}


def normalize(url: str) -> str:
    """Collapse URLs that differ only in tracking or presentation.

    Deliberately conservative: it does NOT strip `www.`, because `www.x.com`
    and `x.com` are usually but not always the same host, and wrongly merging
    two sources corrupts the ledger in a way nobody would notice.
    """
    try:
        p = urllib.parse.urlsplit(url.strip())
    except ValueError:
        return url.strip()
    if not p.scheme and not p.netloc:
        return url.strip()

    host = p.hostname or ""
    if p.port and not ((p.scheme == "http" and p.port == 80) or (p.scheme == "https" and p.port == 443)):
        host = f"{host}:{p.port}"

    kept = [
        (k, v) for k, v in urllib.parse.parse_qsl(p.query, keep_blank_values=True)
        if not (k.lower() in TRACKING_EXACT or k.lower().startswith(TRACKING_PREFIXES))
    ]
    path = p.path.rstrip("/") or "/"
    return urllib.parse.urlunsplit((p.scheme.lower() or "https", host, path,
                                    urllib.parse.urlencode(kept), ""))


def merge(topic_dir: pathlib.Path) -> tuple[dict, str]:
    evidence_dir = topic_dir / "evidence"
    files = sorted(evidence_dir.glob("*.json"))
    if not files:
        raise SystemExit(f"no evidence files in {evidence_dir}")

    sources: dict[str, dict] = {}
    claims: list[dict] = []
    blocked: set[str] = set()
    queries: list[str] = []
    totals = {"searches_run": 0, "pages_fetched": 0, "turns_used": 0}
    unreadable: list[str] = []

    for f in files:
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            # A researcher killed mid-write leaves a truncated file. Report it
            # loudly and merge the rest; silently dropping a leg is how you end
            # up with a ledger that looks complete and is not.
            unreadable.append(f"{f.name} ({exc.__class__.__name__})")
            continue

        blocked.update(data.get("blocked_engines") or [])
        queries.extend(data.get("queries_used") or [])
        for k in totals:
            try:
                totals[k] += int(data.get(k) or 0)
            except (TypeError, ValueError):
                pass

        for finding in data.get("findings") or []:
            urls = [u for u in (finding.get("sources") or []) if str(u).strip()]
            cred = str(finding.get("credibility") or "LOW").upper()
            if cred not in RANK:
                cred = "LOW"
            engines = [str(e) for e in (finding.get("engines") or [])]

            keys = []
            for url in urls:
                key = normalize(str(url))
                keys.append(key)
                entry = sources.setdefault(key, {
                    # The NORMALIZED url is what gets cited. Storing the raw
                    # first-seen one would put tracking params and fragments
                    # into the report — normalizing for dedup and then citing
                    # the dirty URL defeats the point at the only moment it
                    # matters. The original is kept for provenance.
                    "url": key, "url_as_found": str(url).strip(),
                    "credibility": cred, "engines": set(), "claims": 0,
                })
                if RANK[cred] > RANK[entry["credibility"]]:
                    entry["credibility"] = cred
                entry["engines"].update(engines)
                entry["claims"] += 1

            claims.append({
                "sub_question": data.get("sub_question", f.stem),
                "claim": finding.get("claim", ""),
                "credibility": cred,
                "uncertain": bool(finding.get("uncertain")),
                "single_source": len(set(keys)) <= 1,
                "_keys": keys,
            })

    # Number by credibility, then by how many claims lean on it, then by URL —
    # deterministic, so re-running produces the same ledger.
    ordered = sorted(
        sources.items(),
        key=lambda kv: (-RANK[kv[1]["credibility"]], -kv[1]["claims"], kv[1]["url"]),
    )
    numbers = {key: i for i, (key, _) in enumerate(ordered, start=1)}

    ledger_sources = []
    for key, entry in ordered:
        engines = sorted(entry["engines"])
        row = {
            "n": numbers[key],
            "url": entry["url"],
            "credibility": entry["credibility"],
            "engines": engines,
            "agreement": len(engines),   # recorded, never promotes credibility
            "claims": entry["claims"],
        }
        if entry["url_as_found"] != entry["url"]:
            row["url_as_found"] = entry["url_as_found"]
        ledger_sources.append(row)

    for c in claims:
        c["sources"] = sorted({numbers[k] for k in c.pop("_keys") if k in numbers})

    ledger = {
        "topic": topic_dir.name,
        "generated": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "sources": ledger_sources,
        "claims": claims,
        "blocked_engines": sorted(blocked),
        "queries_used": queries,
        "totals": totals,
        "legs_merged": len(files) - len(unreadable),
        "legs_unreadable": unreadable,
    }

    counts = {c: 0 for c in RANK}
    for s in ledger_sources:
        counts[s["credibility"]] += 1
    single = sum(1 for s in ledger_sources if s["agreement"] <= 1)

    summary = (
        f"{len(ledger_sources)} sources "
        f"(HIGH {counts['HIGH']}, MEDIUM {counts['MEDIUM']}, LOW {counts['LOW']}); "
        f"{single} single-engine; {len(claims)} claims; "
        f"blocked: {', '.join(ledger['blocked_engines']) or 'none'}"
    )
    if unreadable:
        summary += f"; UNREADABLE: {', '.join(unreadable)}"
    return ledger, summary


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    topic_dir = pathlib.Path(argv[0])
    if not topic_dir.is_dir():
        raise SystemExit(f"no such topic directory: {topic_dir}")
    ledger, summary = merge(topic_dir)
    (topic_dir / "ledger.json").write_text(
        json.dumps(ledger, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
