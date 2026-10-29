#!/bin/bash
# UserPromptSubmit hook: counts the engineer's prompts per task for log-task.sh.
# The first prompt of a task stores its start time.
# Prints nothing: stdout of this hook goes into Claude's context.
input=$(cat)
sid=$(jq -r '.session_id' <<<"$input")
prompt=$(jq -r '.prompt // ""' <<<"$input")

# the log command itself is not an intervention
case "$prompt" in /log-task*|/tdd-agents:log-task*) exit 0 ;; esac

dir="$HOME/.claude/metrics/sessions"
mkdir -p "$dir"
[ -f "$dir/$sid.start" ] || date +%s > "$dir/$sid.start"
echo $(( $(cat "$dir/$sid.count" 2>/dev/null || echo 0) + 1 )) > "$dir/$sid.count"
exit 0
