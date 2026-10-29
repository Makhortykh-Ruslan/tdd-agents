#!/bin/bash
# Appends one task row to ~/.claude/metrics/tasks.md, then resets the counters
# so the next task in the same session starts from zero.
# Usage: log-task.sh <session_id> <old|new> <task title>
set -euo pipefail
sid="$1"; mode="$2"; shift 2; task="${*//|//}"   # a "|" would break the table
case "$mode" in old|new) ;; *) echo "mode must be old or new" >&2; exit 1 ;; esac

m="$HOME/.claude/metrics"; s="$m/sessions"; log="$m/tasks.md"
costs="$HOME/.claude/session-costs/$sid.json"   # written by the statusline, see README
mkdir -p "$s"

start=$(cat "$s/$sid.start" 2>/dev/null || echo "")
prompts=$(cat "$s/$sid.count" 2>/dev/null || echo 0)

if [ -n "$start" ]; then minutes=$(( ($(date +%s) - start) / 60 )); else minutes="?"; fi
interventions=$(( prompts > 0 ? prompts - 1 : 0 ))   # the first prompt is the task itself

if [ -f "$costs" ]; then
  cost_now=$(jq -r '.cost_usd // 0' "$costs")
  cost_base=$(cat "$s/$sid.cost_base" 2>/dev/null || echo 0)   # cost at the previous row of this session
  cost=$(awk -v a="$cost_now" -v b="$cost_base" 'BEGIN { printf "%.2f", a - b }')
  echo "$cost_now" > "$s/$sid.cost_base"
else
  cost="?"
fi

if [ ! -f "$log" ]; then
  cat > "$log" <<'HEADER'
# Task metrics

One row = one task. Written by the tdd-agents plugin.

- `mode` — `old`: one agent did everything; `new`: the test-writer → implementer → reviewer chain.
- `min` — minutes from the task's first prompt to this row.
- `cost $` — API-price estimate, not the real bill. `?` = no statusline snapshot (see the plugin README).
- `interventions` — your prompts after the first one, gate answers included.
- `bugs after` — fill in by hand when a bug from this task turns up.

| date | project | task | mode | min | cost $ | interventions | bugs after |
|---|---|---|---|---|---|---|---|
HEADER
fi

printf '| %s | %s | %s | %s | %s | %s | %s | |\n' \
  "$(date +%Y-%m-%d)" "$(basename "$PWD")" "$task" "$mode" "$minutes" "$cost" "$interventions" >> "$log"

rm -f "$s/$sid.start" "$s/$sid.count"
tail -1 "$log"
