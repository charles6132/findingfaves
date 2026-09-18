#!/usr/bin/env python3
"""Check every URL in a ledger for liveness, in parallel, in one call.

    python3 check_urls.py <path to ledger.json>   [--timeout 10] [--workers 12]
    python3 check_urls.py <path to urls.txt>

Prints a compact report and writes nothing. Exit 0 even when links are dead —
dead links are a finding, not a failure of this script.

Replaces the PowerShell `checkurls.ps1`, which was never committed and would
not run on Linux anyway. Portable Python, standard library only.

Why this exists at all: **3–13% of citations in deep-research output are
fabricated URLs.** A liveness pass is the cheap fix, and it has to happen
before the report is written rather than after.

Why one call and not one per URL: this runs inside the orchestrator, whose
context is the largest in the run, so every extra turn is the most expensive
turn in the pipeline. Checking 57 URLs took ~7 seconds and one turn.

A dead link is not automatically a fabricated one — a 403 usually means a bot
wall and a 404 on a real domain may be a moved page. The status code is
reported so a human can tell those apart; this script does not guess.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import pathlib
import sys
import urllib.error
import urllib.request

UA = "Mozilla/5.0 (compatible; research-agent link check)"


def urls_from(path: pathlib.Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        data = json.loads(text)
        found: list[str] = []

        def walk(node):
            if isinstance(node, dict):
                for k, v in node.items():
                    if k == "url" and isinstance(v, str):
                        found.append(v)
                    else:
                        walk(v)
            elif isinstance(node, list):
                for item in node:
                    walk(item)

        walk(data)
        # Preserve first-seen order, drop duplicates.
        return list(dict.fromkeys(found))
    return list(dict.fromkeys(
        line.strip() for line in text.splitlines()
        if line.strip() and not line.strip().startswith("#")
    ))


def check(url: str, timeout: float) -> tuple[str, int | str]:
    """HEAD, then GET on failure. Many servers reject HEAD but serve GET."""
    for method in ("HEAD", "GET"):
        req = urllib.request.Request(url, method=method, headers={"User-Agent": UA})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return url, r.status
        except urllib.error.HTTPError as e:
            if method == "HEAD" and e.code in (403, 405, 501):
                continue          # server dislikes HEAD; try GET before judging
            return url, e.code
        except urllib.error.URLError as e:
            reason = getattr(e, "reason", e)
            if method == "HEAD":
                continue
            return url, f"{reason.__class__.__name__}: {reason}"
        except Exception as e:      # socket, ssl, decoding, redirect loops
            if method == "HEAD":
                continue
            return url, f"{e.__class__.__name__}: {e}"
    return url, "unreachable"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("path")
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("--workers", type=int, default=12)
    args = ap.parse_args(argv)

    path = pathlib.Path(args.path)
    if not path.is_file():
        raise SystemExit(f"no such file: {path}")

    urls = urls_from(path)
    if not urls:
        print("0 urls found")
        return 0

    results: list[tuple[str, int | str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for r in pool.map(lambda u: check(u, args.timeout), urls):
            results.append(r)

    dead = [(u, s) for u, s in results if not (isinstance(s, int) and 200 <= s < 400)]
    live = len(results) - len(dead)

    print(f"checked {len(results)}, live {live}, dead {len(dead)}")
    for u, s in dead:
        print(f"  DEAD {s}  {u}")
    if dead:
        print("\nDrop dead links from the ledger before the report is written. "
              "A 403 is usually a bot wall rather than a fabrication — check "
              "before deleting a source that may be real.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
