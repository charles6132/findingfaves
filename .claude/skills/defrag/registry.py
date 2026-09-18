#!/usr/bin/env python3
"""Project registry mechanics for the defrag skill.

The registry has two tiers and the distinction that matters is not active vs.
archived — it is **loaded every turn** vs. **fetched on demand**:

  CLAUDE.md          one line per active project. Loaded on every single turn.
  docs/projects/     the full card. Costs nothing until someone opens it.
  docs/projects/_archive/   storage. Listed by name only, never read unsolicited.

Each card separates STATE from LOG, because a summary that grows is not a
summary. State is rewritten every review and hard-capped; the log is appended
and never loaded unless asked for.

This is a script rather than instructions to the model for the same reason
merge_evidence.py is: the mechanics are deterministic, and the reviewing
context is the most expensive one in the run.

Commands:
    registry.py list [--status active|archived]   one line per project
    registry.py index [--write]                   render the CLAUDE.md block
    registry.py new SLUG --title T --summary S    create a card
    registry.py archive SLUG --reason R --reopen-if C
    registry.py reopen SLUG
    registry.py check                             validate every card
    registry.py stale [--days N]                  cards untouched for N+ days
    registry.py brief                             start-of-day glance — blockers, then next actions
"""

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import shutil
import sys

try:
    import yaml
except ImportError:
    print("registry.py needs PyYAML", file=sys.stderr)
    raise SystemExit(2)

ROOT = pathlib.Path(__file__).resolve().parents[3]
PROJECTS = ROOT / "docs" / "projects"
ARCHIVE = PROJECTS / "_archive"
CLAUDE_MD = ROOT / "CLAUDE.md"

LOG_MARKER = "<!-- LOG BELOW — append only, never loaded. -->"
BEGIN = "<!-- projects:begin -->"
END = "<!-- projects:end -->"

# Caps. These exist so the registry cannot quietly become a second CLAUDE.md.
MAX_SUMMARY = 120      # characters, because this lands in the always-loaded index
MAX_STATE_LINES = 20   # the bounded, rewritten part
MAX_HEAD_LINES = 50    # everything above the log marker

TEMPLATE = """---
project: {slug}
title: {title}
status: {status}
updated: {today}
summary: {summary}
sessions: []
---

## State

{state}

## Next

{next_action}

## Blocked on

{blocked}

{marker}
"""


def today() -> str:
    return dt.date.today().isoformat()


def cards(status: str | None = None) -> list[pathlib.Path]:
    found = sorted(PROJECTS.glob("*.md")) + sorted(ARCHIVE.glob("*.md"))
    found = [f for f in found if f.name != "README.md"]
    if status is None:
        return found
    return [f for f in found if front(f).get("status") == status]


def front(path: pathlib.Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    _, _, rest = text.partition("---\n")
    body, _, _ = rest.partition("\n---")
    try:
        data = yaml.safe_load(body)
    except yaml.YAMLError:
        return {}
    return data if isinstance(data, dict) else {}


def section(path: pathlib.Path, heading: str) -> list[str]:
    """Lines of one '## heading' section, stopping at the next heading or log."""
    out, capture = [], False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip() == LOG_MARKER:
            break
        if re.match(rf"^##\s+{re.escape(heading)}\s*$", line):
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture:
            out.append(line)
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return out


def find(slug: str) -> pathlib.Path:
    for base in (PROJECTS, ARCHIVE):
        p = base / f"{slug}.md"
        if p.is_file():
            return p
    raise SystemExit(f"no project card for '{slug}'")


def cmd_list(args) -> int:
    rows = cards(args.status)
    if not rows:
        print("(no projects)")
        return 0
    for p in rows:
        f = front(p)
        mark = "A" if f.get("status") == "active" else "-"
        print(f"{mark} {f.get('project', p.stem):<28} {f.get('updated', '?')}  {f.get('summary', '')}")
    return 0


def render_index() -> str:
    active = [front(p) for p in cards("active")]
    archived = [front(p) for p in cards("archived")]
    lines = []
    if active:
        for f in sorted(active, key=lambda d: d.get("project", "")):
            lines.append(f"- **{f.get('project')}** — {f.get('summary', '')} · `docs/projects/{f.get('project')}.md`")
    else:
        lines.append("- _(none active)_")
    if archived:
        names = ", ".join(f"`{f.get('project')}`" for f in sorted(archived, key=lambda d: d.get("project", "")))
        lines.append("")
        lines.append(
            f"**Archived** ({len(archived)}) — not loaded; each carries a reopen "
            f"condition in `docs/projects/_archive/`: {names}"
        )
    return "\n".join(lines)


def cmd_index(args) -> int:
    block = render_index()
    if not args.write:
        print(block)
        return 0
    text = CLAUDE_MD.read_text(encoding="utf-8")
    if BEGIN not in text or END not in text:
        raise SystemExit(f"CLAUDE.md is missing the {BEGIN} / {END} markers")
    head, _, rest = text.partition(BEGIN)
    _, _, tail = rest.partition(END)
    CLAUDE_MD.write_text(f"{head}{BEGIN}\n{block}\n{END}{tail}", encoding="utf-8")
    n = len(CLAUDE_MD.read_text(encoding="utf-8").splitlines())
    print(f"CLAUDE.md index updated ({n} lines total)")
    return 0


def cmd_new(args) -> int:
    PROJECTS.mkdir(parents=True, exist_ok=True)
    path = PROJECTS / f"{args.slug}.md"
    if path.exists():
        raise SystemExit(f"{path} already exists")
    path.write_text(
        TEMPLATE.format(
            slug=args.slug, title=args.title, status="active", today=today(),
            summary=args.summary, state=args.state or "_Not yet reviewed._",
            next_action=args.next or "_Unknown — set at the next defrag._",
            blocked=args.blocked or "Nothing.", marker=LOG_MARKER,
        ),
        encoding="utf-8",
    )
    print(f"created {path.relative_to(ROOT)}")
    return 0


def stamp_log(path: pathlib.Path, note: str) -> None:
    text = path.read_text(encoding="utf-8")
    if LOG_MARKER not in text:
        text = text.rstrip() + f"\n\n{LOG_MARKER}\n"
    text = text.rstrip() + f"\n\n### {today()}\n{note}\n"
    path.write_text(text, encoding="utf-8")


def set_field(path: pathlib.Path, key: str, value: str) -> None:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(rf"^{re.escape(key)}:.*$", re.MULTILINE)
    line = f"{key}: {value}"
    if pattern.search(text.split("\n---", 1)[0]):
        text = pattern.sub(line, text, count=1)
    else:
        text = text.replace("\n---\n", f"\n{line}\n---\n", 1)
    path.write_text(text, encoding="utf-8")


def cmd_archive(args) -> int:
    path = find(args.slug)
    if path.parent == ARCHIVE:
        raise SystemExit(f"'{args.slug}' is already archived")
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    set_field(path, "status", "archived")
    set_field(path, "updated", today())
    set_field(path, "reopen-if", args.reopen_if)
    stamp_log(path, f"Archived. {args.reason}\nReopen if: {args.reopen_if}")
    shutil.move(str(path), str(ARCHIVE / path.name))
    print(f"archived {args.slug} -> docs/projects/_archive/{path.name}")
    return 0


def cmd_reopen(args) -> int:
    path = find(args.slug)
    if path.parent != ARCHIVE:
        raise SystemExit(f"'{args.slug}' is not archived")
    set_field(path, "status", "active")
    set_field(path, "updated", today())
    stamp_log(path, "Reopened.")
    shutil.move(str(path), str(PROJECTS / path.name))
    print(f"reopened {args.slug}")
    return 0


def cmd_check(args) -> int:
    problems = 0
    for p in cards():
        rel = p.relative_to(ROOT)
        f = front(p)
        text = p.read_text(encoding="utf-8")

        def bad(msg):
            nonlocal problems
            problems += 1
            print(f"{rel}: {msg}")

        if not f:
            bad("frontmatter missing or will not parse")
            continue
        for key in ("project", "title", "status", "updated", "summary"):
            if not str(f.get(key, "")).strip():
                bad(f"missing required key '{key}'")
        if f.get("project") != p.stem:
            bad(f"project '{f.get('project')}' does not match filename '{p.stem}'")
        if f.get("status") not in ("active", "archived"):
            bad(f"status '{f.get('status')}' is not active or archived")
        if len(str(f.get("summary", ""))) > MAX_SUMMARY:
            bad(f"summary is {len(str(f.get('summary')))} chars, cap is {MAX_SUMMARY} — it lands in the always-loaded index")
        if f.get("status") == "archived" and not str(f.get("reopen-if", "")).strip():
            bad("archived without a 'reopen-if' condition — storage needs a way back out")
        if (p.parent == ARCHIVE) != (f.get("status") == "archived"):
            bad("status and directory disagree")
        if LOG_MARKER not in text:
            bad("missing the log marker; state and history are not separated")
        else:
            head = text.split(LOG_MARKER)[0].splitlines()
            if len(head) > MAX_HEAD_LINES:
                bad(f"{len(head)} lines above the log marker, cap is {MAX_HEAD_LINES}")
        state = section(p, "State")
        if len(state) > MAX_STATE_LINES:
            bad(f"State is {len(state)} lines, cap is {MAX_STATE_LINES} — move detail below the log marker")
        if not state:
            bad("State section is empty")

    total = len(cards())
    if problems:
        print(f"\n{problems} problem(s) across {total} card(s)")
        return 1
    print(f"{total} card(s), all valid")
    return 0


def cmd_stale(args) -> int:
    cutoff = dt.date.today() - dt.timedelta(days=args.days)
    hits = []
    for p in cards("active"):
        f = front(p)
        try:
            when = dt.date.fromisoformat(str(f.get("updated")))
        except ValueError:
            continue
        if when <= cutoff:
            hits.append((when, f))
    if not hits:
        print(f"(nothing active untouched for {args.days}+ days)")
        return 0
    print(f"Active, untouched for {args.days}+ days — archive candidates:")
    # Sort on the date alone. Tuple comparison falls through to the dicts when
    # two dates match, which they always do on a freshly seeded registry.
    for when, f in sorted(hits, key=lambda pair: pair[0]):
        print(f"  {f.get('project'):<28} last touched {when}  {f.get('summary', '')}")
    return 0


def cmd_brief(args) -> int:
    """The start-of-day glance. Deliberately not a skill.

    A daily brief of a registry that moves weekly would print the same lines
    every morning. What changes day to day is the next action and the blocker,
    so that is all this shows.

    It cannot see sessions — blockers recorded by the harness live in
    `needs_action` on the session index, which needs the CCR tool. This is the
    registry's half; the defrag run is where the two get reconciled.
    """
    active = [(p, front(p)) for p in cards("active")]
    if not active:
        print("No active projects.")
        return 0

    blocked, clear = [], []
    for path, f in sorted(active, key=lambda pair: pair[1].get("project", "")):
        text = "\n".join(section(path, "Blocked on")).strip()
        # Match the FIRST SENTENCE, not the whole block. "Nothing. The eval set
        # is blocked on X, but nothing else is." is not a blocker, and comparing
        # the whole string reported it as one.
        first = text.split(".")[0].strip().lower()
        (clear if first in ("nothing", "none", "n/a", "") else blocked).append((f, text))

    if blocked:
        print("BLOCKED")
        for f, why in blocked:
            print(f"  {f.get('project')}")
            print(f"    {why.splitlines()[0]}")
    if clear:
        print("\nNEXT" if blocked else "NEXT")
        for f, _ in clear:
            nxt = "\n".join(section(find(str(f.get("project"))), "Next")).strip()
            print(f"  {f.get('project'):<20} {nxt.splitlines()[0] if nxt else '(no next action set)'}")

    n = len(cards("archived"))
    if n:
        print(f"\n{n} archived. `registry.py list --status archived` to see the shelf.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("list"); p.add_argument("--status", choices=["active", "archived"]); p.set_defaults(fn=cmd_list)
    p = sub.add_parser("index"); p.add_argument("--write", action="store_true"); p.set_defaults(fn=cmd_index)
    p = sub.add_parser("new")
    p.add_argument("slug"); p.add_argument("--title", required=True); p.add_argument("--summary", required=True)
    p.add_argument("--state"); p.add_argument("--next"); p.add_argument("--blocked"); p.set_defaults(fn=cmd_new)
    p = sub.add_parser("archive")
    p.add_argument("slug"); p.add_argument("--reason", required=True); p.add_argument("--reopen-if", required=True, dest="reopen_if")
    p.set_defaults(fn=cmd_archive)
    p = sub.add_parser("reopen"); p.add_argument("slug"); p.set_defaults(fn=cmd_reopen)
    p = sub.add_parser("check"); p.set_defaults(fn=cmd_check)
    p = sub.add_parser("brief"); p.set_defaults(fn=cmd_brief)
    p = sub.add_parser("stale"); p.add_argument("--days", type=int, default=21); p.set_defaults(fn=cmd_stale)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # Output piped into head/grep -q. Not an error worth a traceback.
        try:
            sys.stdout.close()
        finally:
            sys.exit(0)
