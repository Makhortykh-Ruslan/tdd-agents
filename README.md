# TDD Agents

A test-first workflow for Claude Code where **tests, code and review are written
by different agents** — so no agent can fit the check to its own code.

One agent doing everything has a quiet failure mode: when a test is red, the
cheapest path to green is to change the test. TDD Agents splits authorship from
verification and enforces the split with hooks, not with polite instructions:
the implementer cannot edit a test, cannot add `eslint-disable`, `@ts-ignore`
or `as any`, and the test-writer cannot touch production code.

Every task also leaves a row of numbers — minutes, cost, how many times you had
to step in — so you can tell whether the workflow is worth its overhead on your
tasks instead of guessing.

## What is inside

| Part | Name | What it does |
|---|---|---|
| Skill | `/tdd-agents:ticket` | Takes a ticket from pasted text to a reviewable diff: understand → plan → tests → code → review → handover, with a stop for you at every decision |
| Skill | `/tdd-agents:tdd` | Single-session TDD: one red-green-refactor cycle per behaviour. Also the rulebook `ticket` uses for its test-led part |
| Skill | `/tdd-agents:log-task` | Writes the metrics row by hand, for a task done without `ticket` |
| Subagent | `test-writer` | Writes failing tests for the behaviour list you approved and proves they are red |
| Subagent | `implementer` | Makes the red tests green with minimal code; runs lint, typecheck and tests |
| Subagent | `reviewer` | Clean context, read-only: checks the diff against the plan and its acceptance criteria |
| Hook | `guard.sh` | Blocks the edits each subagent is not allowed to make |
| Hook | `count-prompt.sh` | Counts your prompts per task — the "interventions" metric |

## The flow

```
task
  │
  ▼
1. understand ───► main session: the task in one line, behaviours, questions ──► YOU: "yes"
  ▼
2. plan ─────────► files, acceptance criteria, what tests lead ──► YOU: ok / not ok per point
  ▼
3. behaviours ───► the list tests will lead; a real API response if the task calls an API ──► YOU
  ▼
4. test-writer ──► tests, run, all red ──► YOU: read the tests
  ▼
5. implementer ──► code until green (cannot touch tests)
  ▼
6. reviewer ─────► diff against the plan and acceptance criteria
  ▼
7. handover ─────► what changed, what the review found, a metrics row
  ▼
8. YOU ──────────► read the diff, commit yourself
```

Planning stays in the main session on purpose: a subagent cannot stop and ask
you a question mid-task, and the plan is a conversation.

## Install

```bash
claude plugin marketplace add Makhortykh-Ruslan/tdd-agents
claude plugin install tdd-agents@tdd-agents --scope user
```

`--scope user` installs it for every project on the machine. The plugin loads
the next time Claude Code starts, or after `/reload-plugins` in an open session.
See [discover plugins](https://code.claude.com/docs/en/discover-plugins).

## Setup

### 1. `jq` — required

The hooks read JSON with `jq`.

```bash
brew install jq        # macOS
sudo apt install jq    # Debian / Ubuntu
```

### 2. Three scripts in every project — required

The subagents never guess how a project is checked. They run three scripts with
fixed names, so the same plugin works in any project:

```json
{
  "scripts": {
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  }
}
```

What is behind each name is up to the project (Jest, Karma, `ng lint`…). The
names are the contract.

Strict TypeScript makes the typecheck worth running:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true
  }
}
```

### 3. Checks that run by themselves — recommended

Without this, "done" is the agent's opinion. With it, Claude Code runs lint
after every edit and the full set when the agent tries to finish, and the agent
cannot stop until they pass. Per project, committed to git.

`.claude/settings.json`:

```json
{
  "permissions": {
    "deny": ["Read(./.env)", "Read(./.env.*)", "Bash(git push --force *)"]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/lint-file.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}\"/.claude/hooks/gates.sh" }
        ]
      }
    ]
  }
}
```

`.claude/hooks/lint-file.sh` — lints the file that was just changed:

```bash
#!/bin/bash
FILE=$(jq -r '.tool_input.file_path')
case "$FILE" in
  *.ts|*.tsx) npx eslint --fix "$FILE" >&2 || exit 2 ;;
esac
exit 0
```

`.claude/hooks/gates.sh` — lint, typecheck and tests before the agent may stop:

```bash
#!/bin/bash
cd "$CLAUDE_PROJECT_DIR" || exit 0
# no code changes — nothing to check (the agent only answered a question)
git diff --quiet && git diff --cached --quiet && exit 0

OUT=$(npm run -s lint 2>&1 && npm run -s typecheck 2>&1 && npm run -s test 2>&1)
if [ $? -ne 0 ]; then
  echo "$OUT" | tail -40 >&2
  exit 2
fi
exit 0
```

```bash
chmod +x .claude/hooks/*.sh
```

`exit 2` on `Stop` means "do not stop yet": the agent sees the failing output
and keeps working. See the [hooks docs](https://code.claude.com/docs/en/hooks).

### 4. Cost in the metrics — optional

Claude Code gives the session cost only to the status line, and a plugin cannot
set your status line. Add these lines to your status line script so the metrics
can read the cost. Without them the `cost $` column shows `?`.

`~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
```

`~/.claude/statusline-command.sh`:

```bash
#!/bin/bash
input=$(cat)

# cost snapshot for tdd-agents metrics (API-price estimate, not the real bill)
session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$session_id" ]; then
  mkdir -p ~/.claude/session-costs
  echo "$input" | jq -c '{session_id, cost_usd: .cost.total_cost_usd}' \
    > ~/.claude/session-costs/"$session_id".json
fi

# what the status line shows — replace with your own
echo "$input" | jq -r '.model.display_name'
```

See the [status line docs](https://code.claude.com/docs/en/statusline).

### 5. Check that it works

| Do this | Expected |
|---|---|
| Ask for the `implementer` subagent to edit a `.spec.ts` file | blocked by the hook |
| Ask for the `implementer` subagent to add `// eslint-disable` | blocked by the hook |
| Ask for the `test-writer` subagent to edit a non-test file | blocked by the hook |
| Break a type by hand, then tell the agent "finish" | it sees the typecheck error by itself (needs step 3) |
| Send any prompt, then `ls ~/.claude/metrics/sessions/` | `<session-id>.start` and `<session-id>.count` exist |
| Run `/tdd-agents:ticket` on a small task | four stops for you; a new row in `~/.claude/metrics/tasks.md` at the end |

## How to use it

### A task the new way

1. **A new session** in the project folder. One task, one session: time and
   interventions count from the session's first prompt.
2. **A clean `git status`** — the point you can roll back to.
3. Type `/tdd-agents:ticket` and paste the ticket text.
4. **Stop 1 — understanding.** The task in one line, the list of behaviours,
   questions. Answer them. No "yes", no plan.
5. **Stop 2 — the plan.** Files, acceptance criteria, what tests lead and what
   you check by eye. Mark each point ok or not ok. A large plan is saved to a
   file and you are offered a fresh session: `execute plan <path>`.
6. **Stop 3 — behaviours for the tests.** If the task calls an API, give a real
   response copied from the browser's Network tab. Not a Swagger schema — the
   JSON itself. Tests against a guessed contract are green and wrong.
7. **`test-writer`** writes the tests and shows why each one is red.
8. **Stop 4 — read the tests.** Three questions: does it read like plain text?
   Is there an `if` inside a test? Is this your task? A "no" sends the tests back.
9. **`implementer`** writes the code. The main session runs the tests once more
   itself — a subagent's "all green" is a claim, not a result.
10. **`reviewer`** checks the diff. Only what breaks correctness or an
    acceptance criterion gets fixed; the rest is listed for you as optional.
11. **Handover:** what changed, what the review found, what is open, and the
    metrics row — written automatically.
12. **You** read the diff and commit. The plugin never commits.

### A task the old way — for comparison

Work as you always do: one agent, no plugin skill. When the task is done:

```
/tdd-agents:log-task old Add required fields and validation
```

Without this row there is nothing to compare against.

### When to use the full chain

Logic where a mistake is expensive: money, data, permissions, complex state.
For a small low-risk change a prompt, the checks from setup step 3 and a look at
the diff are enough.

## Metrics

Every task adds a row to `~/.claude/metrics/tasks.md`:

| Column | Where it comes from |
|---|---|
| `date`, `project`, `task` | the date, the project folder name, the title you gave |
| `mode` | `new` — the agent chain; `old` — one agent did everything |
| `min` | minutes from the task's first prompt to the row |
| `cost $` | the session cost from the status line snapshot; with two tasks in one session, the difference since the previous row |
| `interventions` | your prompts after the first one, gate answers included |
| `bugs after` | **you**, by hand, when a bug from this task turns up — in QA, in production, in the next task |

`bugs after` is the number that decides. A fast way that ships bugs loses to a
slower way that does not.

### Comparing old and new

1. **Write the decision rule before you start.** For example: "keep the new way
   if it takes at most 1.5× the time and has fewer bugs after". Without a rule
   set in advance, any number looks like an argument for what you already like.
2. Three tasks the old way, three the new way, of similar size and kind.
3. A week or two later, when `bugs after` has filled in, compare the averages.

Six tasks is not statistics. It shows whether a difference is visible at all.

## Known limits

- **The guard watches `Edit` and `Write` only.** The implementer has Bash to run
  tests, so it could still change a test with `sed`. The reviewer checks for
  weakened or deleted tests and closes that gap.
- **The reviewer is the same model family.** It runs on a stronger model than the
  implementer, but a model from another vendor would make different mistakes.
  Worth adding if you have one.
- **`interventions` counts every prompt**, including the planned "yes" at each
  stop. Compare old against new by the same rule, not against zero.
- **Test file detection is by name:** `*.test.*`, `*.spec.*`, `__tests__/`,
  `e2e/`. Other conventions need a change in `scripts/guard.sh`.

## Uninstall

```bash
claude plugin uninstall tdd-agents@tdd-agents
```

The metrics stay in `~/.claude/metrics/` until you delete them.

## License

MIT
