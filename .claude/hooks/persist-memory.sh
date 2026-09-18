#!/usr/bin/env bash
# SubagentStop hook: persist a subagent's memory block on its behalf.
#
# Why this exists: `memory: project` does not grant Write to an agent whose
# `tools` allowlist omits it — an explicit allowlist wins. The analyzer
# (Read, Grep, Glob) therefore had no way at all to write its own MEMORY.md,
# and its closing "update your agent memory" instruction was a guaranteed
# no-op. The debugger could only get there through Bash, which is a route its
# design never intended and which it may simply not think to take.
#
# So the harness does the writing. The agent decides WHAT is worth remembering
# by ending its report with a "## Memory" block; this hook decides WHERE it
# goes. No tool grant, no weakening of a read-only allowlist.
#
# Contract: exit 0 always. SubagentStop *can* block with exit 2, and we never
# want a failed memory append to hold a subagent's result hostage.

set -uo pipefail

payload=$(cat)

agent=$(printf '%s' "$payload" | jq -r '.agent_type // empty')
message=$(printf '%s' "$payload" | jq -r '.last_assistant_message // empty')

# Nothing to attribute or nothing to persist.
[ -z "$agent" ] && exit 0
[ -z "$message" ] && exit 0

# Only these agents route their memory through the hook. The implementer has
# real Write and manages its own file; adding it here would double-write.
case "$agent" in
  analyzer|debugger|scout|researcher) ;;
  *) exit 0 ;;
esac

# The agent's name arrives from the harness, but it lands in a path — refuse
# anything that could climb out of the memory directory.
case "$agent" in
  *[!a-zA-Z0-9_-]*) exit 0 ;;
esac

# Extract the "## Memory" block: everything from that heading to the next
# heading at the same level, or to end of message.
block=$(printf '%s' "$message" | awk '
  /^##[[:space:]]+[Mm]emory[[:space:]]*$/ { capture = 1; next }
  capture && /^##[[:space:]]/            { exit }
  capture                                 { print }
')

# Strip leading blank lines. Trailing ones need no handling — command
# substitution already eats them. Do NOT reach for `tac` here: the block is
# printed without a trailing newline, so reversing it joins the last two lines
# together and silently corrupts the entry.
block=$(printf '%s\n' "$block" | sed -e '/./,$!d')

# No block, or an empty one, means the agent had nothing durable to add. That
# is a legitimate outcome and not an error.
[ -z "$block" ] && exit 0

project="${CLAUDE_PROJECT_DIR:-$(pwd)}"
dir="$project/.claude/agent-memory/$agent"
file="$dir/MEMORY.md"

mkdir -p "$dir" || exit 0

header="# Memory — $agent

Written by .claude/hooks/persist-memory.sh from each run's \`## Memory\` block.
**Newest first**, deliberately: only the first 200 lines (or 25 KB) of this file
are injected into the agent's system prompt, so recent entries must stay at the
top to be seen at all. Edit or prune it by hand freely."

entry="## $(date -u '+%Y-%m-%d %H:%M UTC')

$block"

existing=""
if [ -f "$file" ]; then
  # Drop the managed header; keep the entries that follow it.
  existing=$(awk 'BEGIN { started = 0 }
    started { print }
    !started && /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ { started = 1; print }
  ' "$file")
fi

# Newest entry first, then prior entries, capped so the file cannot grow
# without bound. 400 lines is twice the injection window — enough history to
# be useful, not so much that it becomes a dumping ground.
# The trailing statement here must not be a bare test: under `pipefail` a false
# test makes the whole group exit 1, which trips the `|| exit 0` below and
# silently skips the mv. Keep it an `if`, which returns 0 when not taken.
{
  printf '%s\n\n' "$header"
  printf '%s\n' "$entry"
  if [ -n "$existing" ]; then printf '\n%s\n' "$existing"; fi
} | head -n 400 > "$file.tmp" 2>/dev/null || exit 0

mv "$file.tmp" "$file" 2>/dev/null || { rm -f "$file.tmp" 2>/dev/null; exit 0; }

exit 0
