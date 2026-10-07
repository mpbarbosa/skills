---
name: mutation-test-guards
description: >
  Prove that a guard actually guards, by deleting it and watching a test named
  for it go red. Use when writing or reviewing anything that refuses — a parser
  that rejects bad input, a validator, a CI gate, a permission check, an
  assertion, a lint rule, an alert threshold — or when a test suite is green and
  you want to know whether that means anything. A passing test is evidence the
  test passes; it is not evidence the guard is doing the work.
---

# A guard you have only watched pass is not a guard

Guards are written to refuse, and refusals are hard to observe. The code that
runs when everything is fine is exercised constantly; the code that runs when
something is wrong may never have run at all — including during the test that
claims to cover it.

So the green tick answers a different question than the one you have. It says
*the assertion held*. You wanted *the guard caused it to hold*. Those come apart
more often than they sound like they would, and when they do, nothing tells you:
the suite is green, the review passed, and the refusal is decorative.

**The only proof is subtraction.** Remove the guard, run the test named for it,
and watch it fail. If it stays green, the test was never about the guard.

## The failure this prevents

A parser with two independent refusals — reject anything containing a colon,
reject a bare 17–20 digit id. Three test inputs, and the question is whether
deleting the *second* refusal breaks anything:

```
  rule B PRESENT:                    rule B DELETED:
    full URL  -> null                  full URL  -> null      <- unchanged
    trimmed   -> "channels"            trimmed   -> "channels" <- unchanged
    bare id   -> null                  bare id   -> "9560033571297…"
```

Reproduced runnably; the first two rows are identical in both columns. A test
built from the **full URL** — the form a person actually pastes, and so the
obvious thing to write a test from — is green with the guard and green without
it, because the colon rule rejected it long before rule B was reached. Three
such assertions once stood against a parser that had no second refusal in it at
all.

**Your test input has to reach the guard.** An input that an earlier rule
already rejects exercises nothing, and it is the natural input to choose,
because it is the realistic one.

The middle row carries a second lesson: `"channels"` is not a refusal, it is a
*wrong answer* — a plausible-looking string that would be stored and would
build a link to nothing. Asserting `!== null` would have passed. Assert the
value.

## The procedure

1. **Name each refusal in its own test.** A test covering three rules cannot
   tell you which one it depends on.
2. **Delete one refusal.** Comment it out, invert its condition, or make it
   return the permissive answer.
3. **Run the test named for it.** It must fail.
4. **Restore, and repeat for the next.**

Anything that stays green under deletion is either testing something else or
testing nothing. Fix the test, not the guard.

Do this when the guard is written, not later — the point at which you still know
which inputs were supposed to reach it.

## Mutate in both directions

Deletion proves the guard refuses what it should. It says nothing about whether
it also refuses what it should **not**, and that is the worse failure.

A checker for stored links once compared a community's name against the
organisation's name. It rejected the only correct entry in the file, because
communities do not name themselves the way institutions do. A rule strict enough
to be worth anything rejected it; a rule loose enough to accept it would accept
nearly anything. **That is a false negative reached by trying to be careful** —
a gate failing in the direction that blocks correct work, which is the direction
that gets the gate switched off.

So pin both bounds:

- **Feed it the known-good value and confirm it passes.** This is the test that
  stops someone later widening a refusal until it rejects real inputs.
- **Feed it the known-bad value and confirm it fails.**

For a checker that compares recorded state against live state, mutate **both
sides**: change the recorded value, and re-point the thing it describes. Each
should turn the gate red on its own.

## You have to be able to see red

Mutation testing is worthless if a failing run reports success. Check that your
harness can show you a failure before you trust it to show you one.

The common way this breaks is a pipe. Measured:

    false                      -> exit 1
    false | tail -5            -> exit 0        the pipeline reports the tail
    set -o pipefail; false|…   -> exit 1

And the output is as misleading as the status. A suite that fails on its third
spec, piped through `tail -3`, prints three `PASS` lines and exits 0 — it looks
exactly like a clean run, because the failure scrolled past:

    PASS spec/d
    PASS spec/e
    PASS spec/f
    (exit seen by caller: 0)

**Read the exit code of the command itself**, not of a pipeline ending in
`tail`, `head`, `grep` or a formatter. `set -o pipefail` makes the pipeline
report it, and in bash `${PIPESTATUS[0]}` recovers it — **but only as the very
next thing.** Any simple command in between resets the array, and a bare
assignment is a simple command, so the obvious idiom reads 0:

    false | tail -5; echo "${PIPESTATUS[0]}"         -> 1   correct
    false | tail -5; st=$?; echo "${PIPESTATUS[0]}"  -> 0   the capture reset it

The second line is what you write when you want both numbers, which makes
`PIPESTATUS` the more fragile of the two — and it fails toward green.

**And `pipefail` is not POSIX, so a CI step running under `sh` may not have it.**
Measured on GitHub's `ubuntu-latest`, whose `/bin/sh` is an older dash:
`set -o pipefail` is rejected, while a current dash, bash and zsh all accept it.
So in a workflow step the choice is to say `shell: bash` deliberately, or to
capture the status without a pipe at all:

    out=$(<the suite>); st=$?        # no pipe, so nothing to lose
    printf '%s\n' "$out" | tail -5  # summarise after you have the number

This is the same failure as summarising away the value you measured — the
evidence was produced and the presentation discarded it, which is why re-reading
the command shows nothing wrong.

**And a zero from a probe that never ran looks exactly like a zero from a probe
that found nothing.** This bit a run of this skill. A trigger-rate harness
launched `claude -p` per query with `stderr` discarded and the exit status
unchecked, then counted tool calls in the output. Every query scored `0.0`, which
reads as *this description never triggers*. The subprocess had been failing to
authenticate; no model ever ran. Measured, with the failure thrown away:

    probe fails, stderr discarded, count the matches  -> 0
    probe works, genuinely nothing to find           -> 0
    the exit status of each                          -> 1  vs  0

The zero is not the defect. Discarding the one signal that separates the two is.
So **pair every count with its probe's exit status, and give the probe a case it
must find.** A positive control is what turns an unobservable zero into a
measurement: if the control scores zero as well, you have learned about your
harness rather than about the thing you were testing.

## What counts as a guard

Anything whose job is to not happen:

| Guard | Mutation | Expected |
|---|---|---|
| A parser's refusal | delete the rule | the test named for it goes red |
| A validator / schema constraint | relax the constraint | a bad payload is accepted |
| A CI gate | make its condition always true | the gate stops blocking |
| A permission or auth check | return allow | the forbidden action succeeds |
| A rate limit or threshold | raise it past the test input | the alert stops firing |
| A test asserting an absence | introduce the thing | the assertion fails |

That last row is the one most often decorative. An assertion that something does
*not* appear passes trivially when the thing can never appear — a selector that
matches nothing, a log line whose producer was renamed, a file never written.
Introduce it once and watch the test fail, or it is measuring your typo.

## Report

```
GUARDED — each refusal is load-bearing.

  bare-id rule       deleted -> parser.test "refuses raw ids" FAILS ✓
  colon rule         deleted -> parser.test "refuses full URLs" FAILS ✓
  known-good         a real short code still accepted with both rules present ✓
```

```
DECORATIVE — one test proves nothing.

  "refuses raw ids"  stays GREEN with the rule deleted.
  Its input is a full URL, which the colon rule rejects first, so the
  assertion never reaches the rule it is named for.
  Rewrote it against the trimmed form; now red on deletion.
```

## Rules

- **Subtraction is the only proof.** A guard watched only passing is unproven.
- **Check the input reaches the guard.** The realistic input is often rejected
  earlier by something else.
- **Assert the value, not just non-null.** A wrong answer is not a refusal.
- **Pin both bounds.** A false negative — refusing correct input — is the worse
  direction and the one reached by being careful.
- **Confirm you can see a failure** before trusting a pass; never read an exit
  code through a pipe.
- **An absence assertion is decorative until the thing has appeared once.**
