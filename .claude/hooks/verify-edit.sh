#!/usr/bin/env bash
# PostToolUse hook: fast per-file checks after every Edit/Write.
#
# Runs only the cheap, file-scoped checks (format + lint + typecheck), never the
# full test suite — this fires on every edit and must stay fast. Full-suite
# verification belongs in the Stop hook.
#
# Contract: exit 0 always. PostToolUse cannot block, so the useful channel is
# additionalContext, which feeds findings back to the agent as context.

set -uo pipefail

payload=$(cat)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')

# Nothing to check (e.g. a Write with no path, or a tool we don't care about)
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# Resolve the hook's own directory before changing away from it, so sibling
# scripts can be called regardless of how the hook was invoked.
hook_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || hook_dir=""

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" || exit 0

findings=""
note() { findings="${findings}$1"$'\n'; }

# Run a command if its tool exists; capture output only on failure.
try() {
  local label="$1"; shift
  command -v "$1" >/dev/null 2>&1 || return 0
  local out
  if ! out=$("$@" 2>&1); then
    note "[$label] $(printf '%s' "$out" | head -n 20)"
  fi
}

case "$file" in
  *.py)
    if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f ruff.toml ]; then
      try ruff ruff check --quiet "$file"
      try mypy mypy --no-error-summary "$file"
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    if [ -f package.json ]; then
      # Project-local eslint only; skip if not installed to avoid npx downloads.
      if [ -x node_modules/.bin/eslint ]; then
        out=$(node_modules/.bin/eslint "$file" 2>&1) || note "[eslint] $(printf '%s' "$out" | head -n 20)"
      fi
      if [ -x node_modules/.bin/tsc ] && [ -f tsconfig.json ]; then
        out=$(node_modules/.bin/tsc --noEmit 2>&1) || note "[tsc] $(printf '%s' "$out" | head -n 20)"
      fi
    fi
    ;;
  *.go)
    # gofmt -l exits 0 and LISTS unformatted files on stdout, so its exit code
    # carries no signal. Detect on non-empty output instead.
    if command -v gofmt >/dev/null 2>&1; then
      out=$(gofmt -l "$file" 2>&1)
      [ -n "$out" ] && note "[gofmt] not gofmt-formatted: $file"
    fi
    # Vet the package directory, passed absolute. file_path arrives absolute,
    # so "./$(dirname ...)" would build a nonsense path under the project dir.
    if command -v go >/dev/null 2>&1; then
      out=$(go vet "$(dirname "$file")" 2>&1) || note "[govet] $(printf '%s' "$out" | head -n 20)"
    fi
    ;;
  *.rs)
    [ -f Cargo.toml ] && try cargo cargo check --quiet
    ;;
  *.sh)
    try shellcheck shellcheck "$file"
    ;;
  *.md)
    # Skills and agents route on their frontmatter description. A broken parse
    # is silent — the description falls back to the body's H1 and every one of
    # them mis-routes invisibly. See docs/research/agent-platform-skills.md §3.
    case "$file" in
      */.claude/agents/*.md|*/.claude/skills/*/SKILL.md)
        if [ -n "$hook_dir" ] && [ -f "$hook_dir/check-frontmatter.py" ] &&
           command -v python3 >/dev/null 2>&1; then
          if ! out=$(python3 "$hook_dir/check-frontmatter.py" "$file" 2>&1); then
            note "[frontmatter] $(printf '%s' "$out" | head -n 20)"
          fi
        fi
        ;;
    esac
    ;;
esac

[ -z "$findings" ] && exit 0

jq -n --arg ctx "Automated checks on $file reported issues. Fix these before continuing:

$findings" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
exit 0
