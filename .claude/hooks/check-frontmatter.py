#!/usr/bin/env python3
"""Validate the YAML frontmatter of skill and agent definition files.

Why this exists: on 2026-09-17 a bare ": " inside an unquoted description broke
the frontmatter of five skills at once. Nothing reported it. The skills still
appeared in the list, but their descriptions silently fell back to the H1 of the
document body — and since routing is driven by the description, all five would
have mis-routed invisibly, in a way that looks like model misbehaviour rather
than a config bug. It was caught only because the rendered list changed shape.

The same convention, and therefore the same trap, applies to .claude/agents/*.md.

Usage:
    check-frontmatter.py FILE [FILE ...]      # check the named files
    check-frontmatter.py --all               # check every skill and agent in the project

Exit 0 and print nothing when everything parses. Exit 1 and print one finding
per line otherwise. Designed to be called from a hook, from CI, or by hand.
"""

from __future__ import annotations

import pathlib
import re
import sys

try:
    import yaml  # authoritative when available
except ImportError:  # pragma: no cover - depends on the host
    yaml = None

REQUIRED_KEYS = ("name", "description")
KEY_ONLY = re.compile(r"^[A-Za-z0-9_.-]+:$")


def split_frontmatter(text: str) -> tuple[str | None, str]:
    """Return (frontmatter_body, error). Exactly one of them is meaningful."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, "no YAML frontmatter: file does not open with '---'"
    for i in range(1, len(lines)):
        if lines[i].strip() in ("---", "..."):
            return "\n".join(lines[1:i]), ""
    return None, "unterminated frontmatter: no closing '---'"


def plain_scalar_findings(body: str) -> list[str]:
    """Catch the failure modes a strict YAML parser would reject.

    Used as the whole check when PyYAML is absent, and always as the source of
    the human-readable explanation — a parser error message names a line and a
    column, which does not tell you what to do about it.
    """
    findings = []
    for n, raw in enumerate(body.splitlines(), start=2):  # +1 for the opening ---
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "\t" in line[: len(line) - len(line.lstrip())]:
            findings.append(f"line {n}: tab in indentation — YAML forbids tabs there")
        # Everything after the key's own ": " is a plain scalar unless quoted.
        key, sep, value = line.partition(": ")
        if sep:
            stripped = value.strip()
        else:
            stripped = line.strip()
            # "key:" with a block or empty value underneath is legal YAML.
            if KEY_ONLY.match(stripped) or KEY_ONLY.match(stripped.lstrip("- ")):
                continue
        if stripped[:1] in ("'", '"', "|", ">", "[", "{"):
            continue
        if ": " in stripped or stripped.endswith(":"):
            where = f"line {n}"
            if sep and not key.startswith(" "):
                where += f" (key '{key.strip()}')"
            findings.append(
                f"{where}: bare ': ' inside an unquoted value — this breaks the "
                f"parse silently. Reword to avoid the colon, or quote the value."
            )
    return findings


def check(path: pathlib.Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [f"unreadable: {exc}"]

    body, error = split_frontmatter(text)
    if error:
        return [error]

    findings = plain_scalar_findings(body or "")

    if yaml is not None:
        try:
            data = yaml.safe_load(body)
        except yaml.YAMLError as exc:
            mark = getattr(exc, "problem_mark", None)
            where = f"line {mark.line + 2}" if mark else "frontmatter"
            detail = getattr(exc, "problem", str(exc))
            findings.append(f"{where}: YAML will not parse — {detail}")
            return findings
        if not isinstance(data, dict):
            return findings + ["frontmatter is not a key/value mapping"]
        for key in REQUIRED_KEYS:
            if not str(data.get(key, "")).strip():
                findings.append(f"missing required key '{key}'")
        name = str(data.get("name", "")).strip()
        expected = path.parent.name if path.name == "SKILL.md" else path.stem
        if name and name != expected:
            findings.append(
                f"name '{name}' does not match its path ('{expected}') — "
                f"invocation uses the path, so these must agree"
            )
    elif findings:
        findings.append("(PyYAML not installed — structural checks only)")

    return findings


def targets(root: pathlib.Path) -> list[pathlib.Path]:
    found = sorted(root.glob(".claude/skills/**/SKILL.md"))
    found += sorted(root.glob(".claude/agents/*.md"))
    return found


def main(argv: list[str]) -> int:
    if argv[:1] == ["--all"]:
        paths = targets(pathlib.Path.cwd())
    else:
        paths = [pathlib.Path(a) for a in argv]

    broken = 0
    for path in paths:
        if not path.is_file():
            continue
        for finding in check(path):
            print(f"{path}: {finding}")
            broken += 1
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
