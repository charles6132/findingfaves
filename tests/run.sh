#!/usr/bin/env bash
# The test suite for this repo's harness — hooks, the registry, and the
# invariants the docs claim.
#
# Everything here exists because something broke. Seven bugs have been found in
# these scripts so far and every one was invisible to reading: a gofmt check
# that could never fire, a go vet path that resolved nowhere, a pipefail group
# that skipped its own mv, a tac that reversed two lines into one, a sort that
# compared dicts, a blocker test that matched the wrong thing, and a frontmatter
# checker that flagged legal YAML. Reading found none of them. Running found all
# of them.
#
#     bash tests/run.sh
#
# Exits non-zero if anything fails. Skips are reported loudly, never silently —
# a check that did not run is not a check that passed.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0; skip=0
declare -a failed=()

ok()   { pass=$((pass + 1)); printf '    ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); failed+=("$1"); printf '    FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '          %s\n' "$2"; }
skipped() { skip=$((skip + 1)); printf '    SKIP  %s  (%s)\n' "$1" "$2"; }
group() { printf '\n%s\n' "$1"; }

# expect_code NAME EXPECTED -- cmd...
expect_code() {
  local name="$1" want="$2"; shift 3
  local out; out=$("$@" 2>&1); local got=$?
  [ "$got" = "$want" ] && ok "$name" || bad "$name" "exit $got, wanted $want: $(printf '%s' "$out" | head -n 2)"
}

# expect_match NAME PATTERN -- cmd...
expect_match() {
  local name="$1" pat="$2"; shift 3
  local out; out=$("$@" 2>&1)
  printf '%s' "$out" | grep -qF -- "$pat" && ok "$name" || bad "$name" "no match for '$pat' in: $(printf '%s' "$out" | head -n 2)"
}

# expect_no_match NAME PATTERN -- cmd...
expect_no_match() {
  local name="$1" pat="$2"; shift 3
  local out; out=$("$@" 2>&1)
  printf '%s' "$out" | grep -qF -- "$pat" && bad "$name" "unexpectedly matched '$pat'" || ok "$name"
}

# expect_empty NAME -- cmd...
expect_empty() {
  local name="$1"; shift 2
  local out; out=$("$@" 2>&1)
  [ -z "$out" ] && ok "$name" || bad "$name" "expected no output, got: $(printf '%s' "$out" | head -n 2)"
}

fire() { # hook payload... -> feeds JSON to a hook
  local hook="$1" project="$2" json="$3"
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$project" "$hook"
}

# ---------------------------------------------------------------- invariants
group "Repo invariants"

expect_code "every skill and agent frontmatter parses" 0 -- \
  python3 .claude/hooks/check-frontmatter.py --all
expect_code "every project card is valid" 0 -- \
  python3 .claude/skills/defrag/registry.py check

lines=$(wc -l < CLAUDE.md)
[ "$lines" -le 200 ] && ok "CLAUDE.md is within its 200-line cap ($lines)" \
                     || bad "CLAUDE.md is within its 200-line cap" "$lines lines"

cp CLAUDE.md "$WORK/claude.bak"
python3 .claude/skills/defrag/registry.py index --write >/dev/null 2>&1
if diff -q CLAUDE.md "$WORK/claude.bak" >/dev/null; then
  ok "the CLAUDE.md project index is in sync with the registry"
else
  bad "the CLAUDE.md project index is in sync with the registry" "run: registry.py index --write"
  cp "$WORK/claude.bak" CLAUDE.md
fi

for h in .claude/hooks/*.sh tests/run.sh; do
  expect_code "$h parses" 0 -- bash -n "$h"
done

# ------------------------------------------------------------- frontmatter
group "check-frontmatter.py"

FM="$WORK/fm"; mkdir -p "$FM/.claude/skills/demo" "$FM/.claude/agents"
CF="$ROOT/.claude/hooks/check-frontmatter.py"

printf -- '---\nname: demo\ndescription: Part of the pipeline (matrix mode: a known set).\n---\n# Demo\n' \
  > "$FM/.claude/skills/demo/SKILL.md"
printf -- '---\nname: unclosed\ndescription: No terminator.\n# body\n' \
  > "$FM/.claude/agents/unclosed.md"
printf -- '---\nname: wrongname\ntools: Read\n---\nBody.\n' \
  > "$FM/.claude/agents/mismatch.md"
printf -- '---\nname: tabby\ndescription: Fine.\ntools:\n\t- Read\n---\nBody.\n' \
  > "$FM/.claude/agents/tabby.md"
printf -- '---\nname: quoted\ndescription: "Handles the case: a quoted colon is legal."\ntools: Read\n---\nBody.\n' \
  > "$FM/.claude/agents/quoted.md"
printf -- '---\nname: blocky\ndescription: Block sequences are legal.\ntools:\n  - Read\n  - Grep\n---\nBody.\n' \
  > "$FM/.claude/agents/blocky.md"

expect_match "catches the historical bare-colon bug"   "bare ': '"              -- python3 "$CF" "$FM/.claude/skills/demo/SKILL.md"
expect_match "catches unterminated frontmatter"        "unterminated"           -- python3 "$CF" "$FM/.claude/agents/unclosed.md"
expect_match "catches a missing description"           "missing required key"   -- python3 "$CF" "$FM/.claude/agents/mismatch.md"
expect_match "catches a name that disagrees with path" "does not match its path" -- python3 "$CF" "$FM/.claude/agents/mismatch.md"
expect_match "catches a tab indent"                    "tab in indentation"     -- python3 "$CF" "$FM/.claude/agents/tabby.md"
expect_empty "does NOT flag a quoted colon"            -- python3 "$CF" "$FM/.claude/agents/quoted.md"
expect_empty "does NOT flag a block sequence"          -- python3 "$CF" "$FM/.claude/agents/blocky.md"
expect_code  "exits 0 when everything is clean" 0      -- python3 "$CF" "$FM/.claude/agents/quoted.md"

# -------------------------------------------------------------- verify-edit
group "verify-edit.sh"

VE="$ROOT/.claude/hooks/verify-edit.sh"
expect_match "surfaces a broken skill as additionalContext" "additionalContext" -- \
  fire "$VE" "$FM" "$(jq -n --arg f "$FM/.claude/skills/demo/SKILL.md" '{tool_input:{file_path:$f}}')"
expect_empty "stays silent on a clean agent" -- \
  fire "$VE" "$FM" "$(jq -n --arg f "$FM/.claude/agents/quoted.md" '{tool_input:{file_path:$f}}')"
echo "# readme" > "$FM/README.md"
expect_empty "ignores markdown that is not a skill or agent" -- \
  fire "$VE" "$FM" "$(jq -n --arg f "$FM/README.md" '{tool_input:{file_path:$f}}')"
expect_code "exits 0 on a nonexistent file" 0 -- \
  fire "$VE" "$FM" '{"tool_input":{"file_path":"/nope/gone.py"}}'
expect_code "exits 0 when file_path is absent" 0 -- fire "$VE" "$FM" '{"tool_input":{}}'
expect_code "exits 0 on an empty payload" 0 -- fire "$VE" "$FM" '{}'

# --------------------------------------- verify-edit TS/Rust (were untested)
group "verify-edit.sh — TypeScript and Rust branches"

# Stub the linters rather than installing them. What was never tested is the
# HOOK's branch logic, not eslint or cargo themselves.
TS="$WORK/ts"; mkdir -p "$TS/node_modules/.bin"
printf '{"name":"t"}\n' > "$TS/package.json"
printf '{}\n'           > "$TS/tsconfig.json"
printf '#!/usr/bin/env bash\necho "$1: 1:1  error  Unexpected var"\nexit 1\n' > "$TS/node_modules/.bin/eslint"
printf '#!/usr/bin/env bash\necho "a.ts(3,7): error TS2322: not assignable"\nexit 2\n' > "$TS/node_modules/.bin/tsc"
chmod +x "$TS/node_modules/.bin/eslint" "$TS/node_modules/.bin/tsc"
echo 'var x = 1' > "$TS/a.ts"; echo 'var y = 2' > "$TS/a.js"

expect_match "surfaces eslint findings on a .ts file" "eslint" -- \
  fire "$VE" "$TS" "$(jq -n --arg f "$TS/a.ts" '{tool_input:{file_path:$f}}')"
expect_match "surfaces tsc findings on a .ts file" "tsc" -- \
  fire "$VE" "$TS" "$(jq -n --arg f "$TS/a.ts" '{tool_input:{file_path:$f}}')"
expect_match "covers .js as well as .ts" "eslint" -- \
  fire "$VE" "$TS" "$(jq -n --arg f "$TS/a.js" '{tool_input:{file_path:$f}}')"

# A project with no local linters installed must degrade silently, not error.
TSBARE="$WORK/tsbare"; mkdir -p "$TSBARE"
printf '{"name":"t"}\n' > "$TSBARE/package.json"; echo 'var x = 1' > "$TSBARE/a.ts"
expect_empty "stays silent when no local linter is installed" -- \
  fire "$VE" "$TSBARE" "$(jq -n --arg f "$TSBARE/a.ts" '{tool_input:{file_path:$f}}')"

# tsc must not run without a tsconfig.
TSNOCFG="$WORK/tsnocfg"; mkdir -p "$TSNOCFG/node_modules/.bin"
printf '{"name":"t"}\n' > "$TSNOCFG/package.json"
cp "$TS/node_modules/.bin/tsc" "$TSNOCFG/node_modules/.bin/tsc"
echo 'var x = 1' > "$TSNOCFG/a.ts"
expect_no_match "does not run tsc without a tsconfig.json" "tsc" -- \
  fire "$VE" "$TSNOCFG" "$(jq -n --arg f "$TSNOCFG/a.ts" '{tool_input:{file_path:$f}}')"

RS="$WORK/rs"; mkdir -p "$RS/bin"
printf '[package]\nname = "t"\n' > "$RS/Cargo.toml"
printf '#!/usr/bin/env bash\necho "error[E0308]: mismatched types"\nexit 101\n' > "$RS/bin/cargo"
chmod +x "$RS/bin/cargo"; echo 'fn main() {}' > "$RS/a.rs"

rustfire() { printf '%s' "$(jq -n --arg f "$1" '{tool_input:{file_path:$f}}')" \
  | PATH="$RS/bin:$PATH" CLAUDE_PROJECT_DIR="$2" "$VE"; }
expect_match "surfaces cargo check findings on a .rs file" "cargo" -- rustfire "$RS/a.rs" "$RS"

RSBARE="$WORK/rsbare"; mkdir -p "$RSBARE"; echo 'fn main() {}' > "$RSBARE/a.rs"
expect_empty "stays silent on a .rs file with no Cargo.toml" -- rustfire "$RSBARE/a.rs" "$RSBARE"

# ------------------------------------------------------------ persist-memory
group "persist-memory.sh"

PM="$ROOT/.claude/hooks/persist-memory.sh"
MEM="$WORK/mem"; mkdir -p "$MEM"
mfile="$MEM/.claude/agent-memory/analyzer/MEMORY.md"
memfire() { fire "$PM" "$MEM" "$(jq -n --arg a "$1" --arg m "$2" '{agent_type:$a,last_assistant_message:$m}')"; }

memfire analyzer '## Coverage
Read 8 of 40.

## Memory
- FIRST fact.
- SECOND fact.

## Open questions
Does the cache invalidate?'
[ -f "$mfile" ] && ok "writes the Memory block to the agent memory file" \
                || bad "writes the Memory block to the agent memory file" "no file created"
grep -q "FIRST fact" "$mfile" 2>/dev/null && grep -q "SECOND fact" "$mfile" 2>/dev/null \
  && ok "keeps multi-line blocks intact and in order" \
  || bad "keeps multi-line blocks intact and in order"
grep -q "cache invalidate" "$mfile" 2>/dev/null \
  && bad "stops at the next heading" "swallowed the following section" \
  || ok "stops at the next heading"

memfire analyzer '## Memory
- NEWEST fact.'
if [ "$(grep -n 'NEWEST fact' "$mfile" | cut -d: -f1)" -lt "$(grep -n 'FIRST fact' "$mfile" | cut -d: -f1)" ]; then
  ok "puts the newest entry first, inside the injection window"
else
  bad "puts the newest entry first, inside the injection window"
fi

rm -rf "$MEM/.claude"; memfire analyzer '## Coverage
Nothing durable.'
[ -e "$MEM/.claude/agent-memory" ] && bad "writes nothing when there is no Memory block" || ok "writes nothing when there is no Memory block"
memfire analyzer '## Memory

'
[ -e "$MEM/.claude/agent-memory" ] && bad "writes nothing for an empty Memory block" || ok "writes nothing for an empty Memory block"
memfire implementer '## Memory
- implementer has real Write and manages its own file'
[ -e "$MEM/.claude/agent-memory/implementer" ] && bad "excludes implementer to avoid double-writing" || ok "excludes implementer to avoid double-writing"
memfire Explore '## Memory
- not one of ours'
[ -e "$MEM/.claude/agent-memory/Explore" ] && bad "ignores an unrecognised agent" || ok "ignores an unrecognised agent"
memfire '../../../etc/evil' '## Memory
- traversal attempt'
find "$WORK" -name 'evil*' 2>/dev/null | grep -q . && bad "refuses a traversing agent_type" || ok "refuses a traversing agent_type"
expect_code "exits 0 with no last_assistant_message" 0 -- fire "$PM" "$MEM" '{"agent_type":"analyzer"}'
expect_code "exits 0 on an empty payload" 0 -- fire "$PM" "$MEM" '{}'

rm -rf "$MEM/.claude"
big=$(printf '## Memory\n'; for i in $(seq 1 300); do echo "- fact $i"; done)
memfire analyzer "$big"; memfire analyzer '## Memory
- TOP entry.'
n=$(wc -l < "$mfile")
[ "$n" -le 400 ] && ok "caps the memory file at 400 lines ($n)" || bad "caps the memory file at 400 lines" "$n lines"
head -200 "$mfile" | grep -q "TOP entry" \
  && ok "keeps the newest entry inside the 200-line injection window" \
  || bad "keeps the newest entry inside the 200-line injection window"

# -------------------------------------------------------------- verify-done
group "verify-done.sh"

VD="$ROOT/.claude/hooks/verify-done.sh"
DONE="$WORK/done"; mkdir -p "$DONE"
donefire() { fire "$VD" "$DONE" "$(jq -n --arg p "$1" --arg s "$WORK" '{prompt_id:$p,scratchpad_dir:$s}')"; }

expect_code "exits 0 outside a git repo" 0 -- donefire p-nogit
git -C "$DONE" init -q 2>/dev/null
git -C "$DONE" config user.email t@t; git -C "$DONE" config user.name t
expect_code "exits 0 on a clean tree" 0 -- donefire p-clean

if command -v pytest >/dev/null 2>&1; then
  printf '[project]\nname = "t"\nversion = "0.1"\n' > "$DONE/pyproject.toml"
  printf 'def test_green():\n    assert True\n' > "$DONE/test_ok.py"
  expect_code "exits 0 on a green suite" 0 -- donefire p-green
  printf 'def test_red():\n    assert False, "deliberate"\n' > "$DONE/test_red.py"
  expect_code "exit 2 refuses the stop on a red suite" 2 -- donefire p-red1
  expect_match "puts the failure output on stderr" "Tests are failing" -- donefire p-red2
  # circuit breaker: p-red1 already blocked once, so the next Stop must permit
  expect_code "circuit breaker permits the second stop on the same prompt" 0 -- donefire p-red1
  expect_code "a new prompt_id blocks again" 2 -- donefire p-red3
else
  skipped "the whole verify-done red-suite path" "pytest not installed"
fi

# ---------------------------------------------------------------- registry
group "registry.py"

REG="$WORK/reg"; mkdir -p "$REG/.claude/skills/defrag" "$REG/docs/projects"
cp .claude/skills/defrag/registry.py "$REG/.claude/skills/defrag/"
printf 'x\n<!-- projects:begin -->\n<!-- projects:end -->\ny\n' > "$REG/CLAUDE.md"
R() { python3 "$REG/.claude/skills/defrag/registry.py" "$@"; }

expect_code "creates a card" 0 -- R new alpha --title Alpha --summary "A project."
expect_code "rejects a duplicate slug" 1 -- R new alpha --title A --summary B
expect_code "rejects an unknown slug" 1 -- R archive nope --reason r --reopen-if c
expect_code "archives with a reopen condition" 0 -- R archive alpha --reason done --reopen-if "it returns"
expect_code "rejects archiving something already archived" 1 -- R archive alpha --reason r --reopen-if c
expect_code "reopens" 0 -- R reopen alpha
expect_code "rejects reopening a live project" 1 -- R reopen alpha
expect_code "validates a clean registry" 0 -- R check

R new beta --title Beta --summary "Second." >/dev/null
expect_code "stale survives two cards sharing a date" 0 -- R stale --days 0
expect_match "stale lists both" "beta" -- R stale --days 0

# brief must read only the FIRST SENTENCE of Blocked on
python3 - "$REG/docs/projects/beta.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); t = p.read_text()
p.write_text(re.sub(r"(## Blocked on\n\n).*?(\n\n<!--)",
                    r"\1Nothing. A later clause mentions blocked, but nothing else is.\2", t, flags=re.S))
PY
# beta SHOULD appear, under NEXT. What must not appear is a BLOCKED section —
# that is what a mis-read "Nothing. ..." would produce.
expect_no_match "brief does not call 'Nothing. ...' a blocker" "BLOCKED" -- R brief
expect_match    "brief lists an unblocked project under NEXT"  "NEXT"    -- R brief

python3 - "$REG/docs/projects/alpha.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); t = p.read_text()
p.write_text(re.sub(r"^summary:.*$", "summary: " + "x" * 150, t, flags=re.M))
PY
expect_match "check rejects an over-cap summary" "cap is 120" -- R check

python3 - "$REG/docs/projects/beta.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); t = p.read_text()
t = t.replace("## State\n\n_Not yet reviewed._", "## State\n\n" + "\n".join(f"l{i}" for i in range(25)))
p.write_text(t)
PY
expect_match "check rejects an over-cap State" "cap is 20" -- R check

cp "$REG/docs/projects/beta.md" "$REG/docs/projects/gamma.md"
expect_match "check rejects a slug that disagrees with its filename" "does not match filename" -- R check
python3 - "$REG/docs/projects/gamma.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace(
    "<!-- LOG BELOW — append only, never loaded. -->", ""))
PY
expect_match "check rejects a card with no log marker" "not separated" -- R check
expect_code "check exits non-zero when anything is wrong" 1 -- R check

rm -f "$REG/docs/projects/gamma.md" "$REG/docs/projects/beta.md"
R new delta --title D --summary "Short." >/dev/null
R archive delta --reason r --reopen-if "a condition" >/dev/null
python3 - "$REG/docs/projects/_archive/delta.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); p.write_text(re.sub(r"^reopen-if:.*\n", "", p.read_text(), flags=re.M))
PY
expect_match "check rejects an archive with no way back out" "way back out" -- R check

rm -f "$REG/docs/projects/_archive/delta.md"
python3 - "$REG/docs/projects/alpha.md" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); p.write_text(re.sub(r"^summary:.*$", "summary: ok", p.read_text(), flags=re.M))
PY
expect_code "index --write regenerates the block" 0 -- R index --write
expect_match "the generated index names the project" "alpha" -- R index
: > "$REG/CLAUDE.md"
expect_code "index --write fails loudly with no markers" 1 -- R index --write
expect_code "piping output to head does not traceback" 0 -- bash -c "python3 '$REG/.claude/skills/defrag/registry.py' list | head -1"

# ------------------------------------------------- research engine scripts
group "merge_evidence.py and check_urls.py"

ME="$ROOT/.claude/skills/research-engines/merge_evidence.py"
CU="$ROOT/.claude/skills/research-engines/check_urls.py"
TOP="$WORK/topic"; mkdir -p "$TOP/evidence"

cat > "$TOP/evidence/q1.json" <<'JSON'
{"sub_question":"What is X?","findings":[
 {"claim":"X is a thing.","sources":["https://docs.example.com/x?utm_source=n&v=2#intro"],
  "credibility":"LOW","engines":["duckduckgo"],"uncertain":false},
 {"claim":"X has parts.","sources":["https://blog.example.org/p/","https://docs.example.com/x?v=2"],
  "credibility":"MEDIUM","engines":["bing"],"uncertain":false}],
 "blocked_engines":["yandex"],"queries_used":["x"],"searches_run":3,"pages_fetched":4,"turns_used":5}
JSON
cat > "$TOP/evidence/q2.json" <<'JSON'
{"sub_question":"Who made X?","findings":[
 {"claim":"Acme.","sources":["https://DOCS.example.com:443/x?v=2&fbclid=a"],
  "credibility":"HIGH","engines":["google","brave"],"uncertain":false},
 {"claim":"A forum says so.","sources":["https://forum.example.net/t/1"],
  "credibility":"LOW","engines":["google","brave","bing"],"uncertain":true}],
 "blocked_engines":[],"queries_used":["who"],"searches_run":2,"pages_fetched":3,"turns_used":4}
JSON
printf '{"truncated": [' > "$TOP/evidence/q3.json"

expect_code  "merges evidence into a ledger" 0 -- python3 "$ME" "$TOP"
expect_match "reports a truncated leg loudly" "UNREADABLE" -- python3 "$ME" "$TOP"

led="$TOP/ledger.json"
q() { python3 -c "import json,sys;d=json.load(open('$led'));print($1)"; }

[ "$(q "len(d['sources'])")" = "3" ] \
  && ok "dedups tracking params, fragments, case and default port into one source" \
  || bad "dedups tracking params, fragments, case and default port into one source" "got $(q "len(d['sources'])")"
[ "$(q "[s['credibility'] for s in d['sources'] if 'docs.example.com' in s['url']][0]")" = "HIGH" ] \
  && ok "keeps the highest credibility any researcher assigned" \
  || bad "keeps the highest credibility any researcher assigned"
[ "$(q "[s['agreement'] for s in d['sources'] if 'docs.example.com' in s['url']][0]")" = "4" ] \
  && ok "unions the engines that found a source" \
  || bad "unions the engines that found a source"
[ "$(q "[s['credibility'] for s in d['sources'] if 'forum' in s['url']][0]")" = "LOW" ] \
  && ok "engine agreement never promotes credibility" \
  || bad "engine agreement never promotes credibility" "a forum found by 3 engines is still a forum"
[ "$(q "[s['url'] for s in d['sources'] if 'docs.example' in s['url']][0]")" = "https://docs.example.com/x?v=2" ] \
  && ok "cites the normalized url, not the raw one" \
  || bad "cites the normalized url, not the raw one" "got $(q "[s['url'] for s in d['sources'] if 'docs.example' in s['url']][0]")"
[ "$(q "d['legs_merged']")" = "2" ] && ok "merges the readable legs and counts them" \
                                   || bad "merges the readable legs and counts them"

# Compare everything EXCEPT `generated`. That field is a wall-clock stamp, so
# a byte-for-byte diff fails whenever two runs straddle a second boundary —
# which made this test pass or fail depending on timing. The property under
# test is stable ORDERING and numbering, not a reproducible timestamp.
strip_ts() { python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); d.pop('generated',None)
print(json.dumps(d,sort_keys=True))" "$1"; }
strip_ts "$led" > "$WORK/ledger.first"; python3 "$ME" "$TOP" >/dev/null
strip_ts "$led" > "$WORK/ledger.second"
diff -q "$WORK/ledger.first" "$WORK/ledger.second" >/dev/null \
  && ok "is deterministic — same ordering and numbering on a re-run" \
  || bad "is deterministic — same ordering and numbering on a re-run"

expect_code "fails loudly with no evidence directory" 1 -- python3 "$ME" "$WORK/nothing-here"

expect_match "check_urls extracts urls from a ledger" "checked 3" -- python3 "$CU" "$led" --timeout 1
printf 'https://a.example\n# comment\nhttps://b.example\n' > "$WORK/urls.txt"
expect_match "check_urls reads a plain url list too" "checked 2" -- python3 "$CU" "$WORK/urls.txt" --timeout 1
expect_code  "check_urls fails loudly on a missing file" 1 -- python3 "$CU" "$WORK/nope.json"

# ------------------------------------------------------------------ summary
printf '\n%s\n' "----------------------------------------"
printf 'passed %d   failed %d   skipped %d\n' "$pass" "$fail" "$skip"
if [ "$fail" -gt 0 ]; then
  printf '\nFAILED:\n'
  for f in "${failed[@]}"; do printf '  - %s\n' "$f"; done
  exit 1
fi
[ "$skip" -gt 0 ] && printf '\n%d check(s) skipped — a check that did not run is not a check that passed.\n' "$skip"
exit 0
