---
name: log-task
description: Log the finished task's metrics (time, cost, interventions) as one row in ~/.claude/metrics/tasks.md. Run by hand after a task done the old way, or invoke from another workflow skill at its handover step. Never invoke on your own for a task that is not finished.
argument-hint: "old|new [task title]"
---

Arguments: `$ARGUMENTS`. The first word is the mode: `old` — one agent did everything; `new` — the test-writer → implementer → reviewer chain. The rest is the task title.

The mode or the title is missing → ask for it in one line. Do not guess.

Run exactly once:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/log-task.sh" "${CLAUDE_SESSION_ID}" "<mode>" "<task title>"
```

Show the printed row and stop.
