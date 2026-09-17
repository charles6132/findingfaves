#!/usr/bin/env bash
# Stop hook: refuse to end the turn on a red test suite.
#
# exit 2 tells Claude Code NOT to stop, and feeds stderr back as the reason.
# That makes "run the tests" a constraint rather than a suggestion.
#
# CIRCUIT BREAKER: blocks at most once per prompt. Without this, a genuinely
# unfixable failure would loop forever. One block is enough to catch the
# "I think I'm done" reflex; beyond that, a human should look.

set -uo pipefail

payload=$(cat)
prompt_id=$(printf '%s' "$payload" | jq -r '.prompt_id // "none"')
scratch=$(printf '%s' "$payload" | jq -r '.scratchpad_dir // "/tmp"')
guard="${scratch}/.verify-done-${prompt_id}"

# Already blocked once this prompt — let it stop.
[ -f "$guard" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" || exit 0

# Only run if the tree has uncommitted changes; nothing edited, nothing to verify.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
[ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0

# Detect the project's own test command. No detection -> no opinion.
if   [ -f package.json ] && jq -e '.scripts.test' package.json >/dev/null 2>&1; then
  cmd="npm test --silent"
elif [ -f Cargo.toml ]; then
  cmd="cargo test --quiet"
elif [ -f go.mod ]; then
  cmd="go test ./..."
elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f tox.ini ]; then
  command -v pytest >/dev/null 2>&1 && cmd="pytest -q" || exit 0
else
  exit 0
fi

if ! out=$(timeout 300 bash -c "$cmd" 2>&1); then
  touch "$guard"
  {
    echo "Tests are failing, so the turn is not finished. Command: $cmd"
    echo
    printf '%s' "$out" | tail -n 40
    echo
    echo "Fix these, or if they are pre-existing failures unrelated to your change,"
    echo "say so explicitly and state that you are stopping with the suite red."
  } >&2
  exit 2
fi

exit 0
