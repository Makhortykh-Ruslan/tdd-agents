---
name: tdd
description: Drive a task with tests in one session — the test leads the code, one red-green-refactor cycle per behaviour, with the two-pile split and the real-payload rule. Also the rulebook the ticket skill follows for its test-led part. Use when the user says "TDD", "test-first", or types /tdd-agents:tdd. Not for writing tests against code that already exists.
---

# TDD workflow

A development method, not an exercise. The task is real work; the test is the tool it gets built with.

**The agent writes the tests. The engineer reads them and says yes or no.** Test syntax is not the engineer's job — judging whether the test describes the task is.

Core principle, and the only test of whether a test is worth anything:
**predictable input → predictable output.**

---

## Step 0. Split the task into two piles — before a single line of code

**This is the most important step and it cannot be skipped.** Most frontend tasks are only partly testable. If that is not said out loud at the start, what comes out is "TDD on 10% of the task" and code-first on the rest, with everyone surprised at the end.

Walk the task and sort it:

| Led by TDD | Checked by eyes / the compiler |
| --- | --- |
| pure functions: adapters, mappers, utils, validators, helpers | templates, markup, styles, spacing |
| sorting, filtering, grouping logic over a collection | rxjs chains on a component with DI |
| payload assembly in a form service | constant configs (table headers, routes) |
| pure functions over state (toggle, merge, reset) | transcribing a backend contract into a DTO |
| store reducers / actions | wiring an existing pipe or directive into a template |

The right column is not laziness — it is the boundary of the tool without a TestBed and DI mocks.

Then tell the engineer the **honest share**: "the adapter and the sorting go under TDD — roughly a third of the task; the component, template and styles go without tests." If the share comes out below half, say so plainly and ask whether the logic should be pulled into pure functions so there is something for tests to lead. That question *is* the real design pressure; without it TDD does nothing here.

**Count the share in files, not by feel.** "About a third" is a feeling and it is always inflated: in a real run "35%" turned into 1 tested file out of 21 changed. State the expected number — how many files will be created or changed in total, and how many of those a test leads. A number that can be checked at the end, not an adjective.

**Mirror check — per file in the left pile.** Find the artifact in the repo that does the same thing for a neighbouring entity. If the new file is its mirror image (the same form service against another endpoint, the same adapter for another table row), the design is already settled and there is nothing to push on: a test would only confirm the copy was made correctly. That is the compiler's and the reviewer's job, not TDD's. Drop that file from the left pile and say it out loud: "`x.form.ts` mirrors `y.form.ts`, not leading it with tests."

The left pile can end up empty. That is a legitimate, honest outcome: say TDD has nothing to grip here and build the task code-first under the project's rules. Running cycles for the sake of cycles is exactly the substitution this skill exists to prevent.

---

## Step 1. Description → list of behaviours

What is needed from the engineer is **examples with concrete values**, not a description of the feature:

- the real payload (JSON) — types and nullability are derived from it;
- input → expected output for each case;
- edges: empty, `null`, zero, duplicates, boundary.

Turn that into a numbered list of behaviours, one line per `it`. Show the list — the engineer confirms or cuts it. **Guess nothing:** if it is unclear what to show on `null`, ask one question here, not after the code is written.

### The real payload is a blocker, not a preference

**If the task touches an API, do not start the first cycle until you have seen a real response copied from Network.** Not the description in the ticket, not "go by what we send", not an analogy with a neighbouring endpoint. The JSON itself.

This is the most expensive gap in the method, and it is silent: **a test against an invented model is green.** In a real run the model was declared blind, 12 green tests were assembled on it, and then the model, the form and the component were rewritten three times as the real responses arrived — `name` instead of `serviceName`, a `ResponseModel<T>` wrapper instead of a bare model, an array of objects instead of an array of strings. Not one test failed at any point. The tests were verifying a fantasy about the backend, and doing it flawlessly.

So this step carries one blocking question: "give me a real response from the endpoint, otherwise I will guess the contract and we will be rewriting it."

**A Swagger schema is not a response.** An example where every field is `"string"` with `true`/`0` sitting in the bools and numbers is generated from C# types; it says nothing about what actually arrives in navigation fields or what is genuinely nullable. Given that instead of JSON, do not soften the requirement into an assumption and do not start the cycle.

**No real response → the mapping goes in the RIGHT column.** Not "the model is temporary, we'll rewrite the tests": transcribe the contract as ordinary code, mark it unverified, and write zero `it` against it. Tests on a guessed contract are worse than no tests — they cost cycles and buy false confidence, because they are green whether the model is right or wrong. A real run produced 11 green tests resting on the unconfirmed assumption that `keywords[].keyword` held the keyword text.

### Build the behaviour list by walking the ticket sentence by sentence

Not "based on" the ticket. Take its text and go sentence by sentence: every sentence that describes behaviour becomes a line in the list. Otherwise a detail buried mid-paragraph simply never makes it in — in a real run "a new input is added at the top" was lost that way, and only reached the tests because the ticket happened to get re-read mid-work.

---

## Step 2. The engineer's review — a blocking gate

**Written tests are shown to the engineer and work stops until they answer.** This is the engineer's only step in the whole cycle and the entire point of the exercise: it is where a misunderstood task gets caught, before any code exists. Do not run ahead into implementation because the tests "look obviously fine".

Present the specs and name the three checks explicitly:

1. **Does it read almost like plain text?** A test whose behaviour cannot be read off the `it` name and body in one pass is a bad test — rewrite it, do not defend it.
2. **Is there an `if` in the test?** Bad sign, and normally a defect in the test rather than a style issue: a test must run one predictable path. Same for loops, `try/catch`, and any branch on the result. Assert a concrete value instead.
3. **Does the engineer agree the test reproduces their task?** If they cannot tell — that is the signal, and it is the valuable one. It does not mean the test is bad; it means the task itself is not understood yet. Stop, go clarify the task, and do not heroically solve it.

Answer "no" or a correction on any of the three → fix the specs and show them again. Only "yes" opens Step 3.

### Writing rules that make the review possible

- One behaviour per `it`. No `if`, no loops, no `try/catch`, no branching on the result inside a test body.
- The `it` name is a sentence about behaviour ("shows a dash when a specialty has no keywords"), not a method name.
- Shared input goes into a factory with a `Partial<T>` override, so each `it` shows only what matters in it.
- Concrete literal values in assertions. Not a recomputation of the production formula — that test passes even when the formula is wrong.

---

## Step 3. The cycle — one behaviour at a time

1. **RED.** One `it` for one behaviour. Run the tests. It must fail — and fail **for the right reason**. Show the output. A missing module or an undeclared field is a legitimate first red (that is the compiler), but it only proves the name; the next red must be on a value.
2. **GREEN.** The minimal code that makes exactly this test pass. Nothing "for later": what no test demands does not get written.
3. **REFACTOR.** Clean up while green: names, duplication, types. The tests are not touched. Refactoring the spec itself (extracting a model factory instead of copy-paste) is allowed and encouraged — also only while green.
4. Next behaviour. Until the list is exhausted.

One cycle = one `it`. Do not write three tests "to go faster" — that removes the cycle, and with it the point.

**Write the minimal code literally minimally, even when it looks absurd.** `keywords: []` instead of the mapping right away is exactly right: the next cycle then produces a genuine red and proves the mapping test checks something. Writing the "proper" implementation one step ahead makes the next test be born green, proving nothing. This is precisely the place where cutting the corner is tempting.

**A test that is green immediately is not a cycle.** It happens: the behaviour is already covered by the previous cycle's code. Do not invent a fake red and do not rewrite the code to make it fail. Say it out loud — "this behaviour was green from the start, there was no cycle" — and do not count it in the cycle statistics. In a real run 2 of 12 tests were like this.

### Fixing a bug is the same cycle with a fixed first step

The first test **reproduces the bug**, and it is red because the bug is real — not because a file is missing. If it cannot be made to fail, the bug has not been reproduced, and there is nothing to fix yet: go find the actual conditions.

When the engineer reviews it, the question is not "is this test correct" but "is this my bug". They read the test code, not a plan or a description of the fix.

---

## Step 4. The right column

When the left pile is closed, the rest is written normally, code-first. **Say so out loud** at the transition: "the adapter is closed by tests, the component and template go without them." A silent transition is what makes a task look like TDD when it is not.

**Hand the UI to the engineer's eyes at the first assembled state, not the finished one.** "First assembled" means the screen renders and can be looked at, even if half the buttons do nothing yet. Not "once I finish the rest." In a real run a fully finished feature was handed over — and drew four consecutive rounds of fixes, every one of them from the right column, every one cheaper had it arrived separately and earlier.

**Expect the right column to eat most of the iterations.** The left pile closes in one pass and does not come back; the right one is block order, button widths, whether to hide the input after Add, which class the icon takes. So do not hold out for "fully ready": as soon as the left pile is closed and the UI is first assembled, hand it over. Each round of fixes is cheaper than reworking three accumulated ones.

---

## Step 5. Cleanup — only after approval

**No spec is deleted until the engineer says so explicitly.** Not "before handover", not "because that's the project convention", not "because tests don't live here". The spec stays on disk until deletion is explicitly approved.

When handing the work over, name the spec files written and ask in one line whether to keep or delete them. Then stay quiet and wait. No answer → the files stay.

Approval given → delete by exact path (`rm <path>.spec.ts`) and run the typecheck again. At that point say once what was paid: a deleted test keeps the design pressure and the verification it gave at the moment of writing, but gives **zero** protection against regressions. One line, no sermon, and not repeated in every later reply.

---

## Retrospective at the end

When the task is closed — short, factual:

- how many cycles actually ran, and on what;
- how many files were changed against how many were tested (against the number predicted in Step 0);
- what the tests caught, and what the compiler, the linter and the engineer's eyes caught;
- where TDD produced design, and where the project's rules would have produced the same without it.

No excuses and no advertising for the method. If it went badly, say so.

---

## What is NOT TDD — the usual substitutions

- Writing code and then a test for it. That is just tests.
- Showing a "red" that is red only because the file does not exist yet, and stopping there.
- Running a cycle on one small pure function while 90% of the task is done code-first — and calling it TDD. If that is how it lands, it must be said at **Step 0**, not in the retrospective.
- Testing what the compiler or linter already checks. A test that "the field exists on the interface" catches nothing.
- Mocking everything in sight to "make the component testable". Either pull the logic into a pure function or honestly leave it in the right column.
- Skipping the engineer's review because the tests look fine. The review is the task check, not a code check.

---

## Gaps that have already cost — checklist before starting

Every line here is a mistake actually made in a live run. Walk it before the first `it`.

| Gap | How not to repeat it |
| --- | --- |
| API contract guessed, tests green on a fantasy | Real JSON from Network **before** the first cycle. A Swagger schema does not count. No JSON → the mapping goes in the right pile, zero tests on it |
| Tests written for a file that mirrors an existing neighbour | Mirror check per file in the left pile. A mirror is not test-led |
| Left pile padded artificially so there "is TDD" | An empty left pile is a legal result. Say it and build code-first |
| Share under TDD stated by feel and inflated | Count in files: how many change in total / how many a test leads |
| A behaviour from the ticket never made the list | Walk the ticket sentence by sentence, not "based on" it |
| Code written a step ahead — the next test was born green | Minimal literally, even when it looks absurd |
| A fake red invented so there "was a cycle" | Green from the start → say so, do not count it |
| Implementation started before the engineer reviewed the specs | Step 2 is a blocking gate. No "yes", no code |
| `if` or a loop inside a test | One predictable path per test, concrete literal expectations |
| Bug "fixed" without reproducing it first | The first red reproduces the bug, not a missing file |
| UI handed over only at the end | Show it at the first assembled state, before finishing the rest |
| A backend field read by its name rather than its meaning | Ask the engineer what a non-obvious field (a flag, a status, a service id) actually means — the code does not reveal it |
| Runner and globals worked out along the way | Check `package.json` and whether `describe/it/expect` need an explicit import — before the first spec |

---

## Technical

- Determine the runner from `package.json` (`test` / `unit` script), do not guess. Vitest, Jest, `ng test` — the command comes from there.
- The spec sits next to its file and repeats its name: `foo.util.ts` → `foo.util.spec.ts`.
- Project rules (typing, file placement, linting) apply in tests exactly as in production code.
- Running the tests is never "just to have a look". Every run either proves a red or confirms a green; no idle runs.
