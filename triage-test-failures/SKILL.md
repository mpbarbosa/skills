---
name: triage-test-failures
description: >
  Establish whether a failing test suite is failing because of your change or
  was already red, by re-running the same suite against a clean baseline and
  comparing the failing sets. Use whenever tests fail during a change, before
  committing on a red or partly-red suite, when someone says a failure is
  "unrelated", "flaky", "pre-existing" or "environmental", or when deciding
  whether a workaround for a failing test is worth keeping.
---

# Whose failure is this?

A red suite is not evidence about your diff. It is evidence about the suite.
Between those two sits the only question that matters here — **did my change
cause this?** — and it has exactly one honest answer: run the same suite without
your change and compare.

Both wrong answers cost something real. Calling your own regression
"pre-existing" ships it. Calling a pre-existing failure yours sends you hunting
through code that was never broken, and the hunt usually ends in a workaround
that makes the suite quieter and the codebase worse.

## Triage in order of what the failure proves

**Type errors, compile errors and unit failures are yours until shown
otherwise.** They are deterministic, hermetic and fast. If one is red, stop and
read it — the baseline run below is for suites that touch the world, and
spending it on a unit failure is a way of not reading the assertion.

**Integration and end-to-end failures prove nothing on their own.** They couple
to network, live data, timing, browser state, seeded randomness and each other.
This is where triage earns its keep.

## Run the baseline in a worktree, not a stash

The instinct is `git stash`, and it works, but it puts your uncommitted work
inside a command that can conflict on the way back out — while the tree you are
protecting is the only copy of it. A detached worktree at `HEAD` never touches
your tree at all:

```sh
base=$(mktemp -d)
git worktree add -q --detach "$base" HEAD
```

Verified: with `src/a.txt` modified and `src/new.txt` untracked, the worktree
holds the committed `a.txt` and no `new.txt`, and `git status` in the original
still reports both. Your work is never at risk, and you can run both suites
concurrently if the runner allows it.

Two costs, both worth paying. The worktree needs its own dependencies installed,
which is the slow part. And **`HEAD` is the baseline, so anything you already
committed this session is inside it** — if the change under suspicion is
committed, use the commit you started from, not `HEAD`.

Tear it down when you are done:

```sh
git worktree remove "$base"
```

## Make the two runs comparable, or the comparison is theatre

The baseline is only evidence if the *only* difference is your diff.

- **Same runner.** If the project has a containerized or otherwise hermetic
  runner, use it for both. A host run and a container run are not comparable, and
  the host is usually the one lying — unsupported OS, missing browser, different
  locale, no network.
- **Same suite and same selection.** Not a narrowed re-run.
- **Same seed and same ordering**, if the runner randomizes. An unpinned seed
  turns ordering flake into a fake verdict in either direction.
- **Rebuild between runs.** This is the trap that quietly invalidates the whole
  procedure: stale build output, a cached container layer, a `dist/` the runner
  does not regenerate, and the "baseline" run executes your new code. If the
  runner has a no-rebuild fast path, do not use it here — that flag is exactly
  what makes source changes invisible to the run.

## Compare sets, never counts

"Seven failures before, seven after" is not the same suite failing. Capture spec
names from both runs and diff them:

```sh
sort fail_baseline.txt > /tmp/a; sort fail_current.txt > /tmp/b
comm -13 /tmp/a /tmp/b   # fail only WITH your diff  -> YOURS
comm -12 /tmp/a /tmp/b   # fail BOTH runs            -> pre-existing
comm -23 /tmp/a /tmp/b   # failed only on baseline   -> your diff FIXED these
```

The third column is the one nobody looks at, and it is worth a sentence in your
report: a change that repairs something incidentally is worth knowing about, and
a change that repairs something *while you were expecting it to break something*
usually means the two runs were not comparable after all.

## The third verdict: flaky is not pre-existing

One run each cannot distinguish "fails without my diff" from "fails about half
the time". Both produce the same two lines, and the flaky reading is the one that
lets a real regression through — an intermittent spec that happened to pass on
your baseline run reads as **YOURS**, and one that happened to fail reads as
**pre-existing**.

When a disputed spec's result decides whether you commit, **repeat it**. Run the
spec alone, several times, on the baseline:

```sh
for i in 1 2 3 4 5; do <run one spec> >/dev/null 2>&1 && echo "$i pass" || echo "$i FAIL"; done
```

A spec that flips is flaky, which is a third finding and not a licence to
proceed. Say so by name. **A flaky spec cannot clear your diff** — its failure
carries no information either way, so if your change plausibly touches what it
exercises, you still owe an argument that it did not.

## Categorize what remains pre-existing

| Mode | Tell-tale | What to do |
|---|---|---|
| **Ordering or shared state** | Passes alone, fails in the suite (or vice versa) | Report it; fixing is separate work |
| **Environment-coupled** | Needs network, a live service, a real clock, credentials | Not fixable from here — say so, name what it needs |
| **Live-data coupled** | Asserts on data that changes upstream | Same; the fix is fixtures, and that is its own task |
| **Genuinely broken and known** | Reproduces cleanly on baseline, every time | Report; do not adopt it as your problem |

Report each with the mode, not just "pre-existing". A named mode is actionable
by whoever owns it; "unrelated" is a shrug that gets copied into the next report.

## Workarounds: keep only what demonstrably works

A suppression, a wait, a retry, a disabled assertion — keep it only if it flips
that spec green **in isolation**, proven, and revert it otherwise.

The failure this prevents is specific: you add a plausible workaround to a spec
that is failing for a *different* reason, the spec stays red, and the workaround
stays in the diff. It now looks like a fix, survives review as one, and silently
weakens a test that was never the problem. Test each one alone before keeping it,
and drop the ones that changed nothing.

## Do not launder red into green

A failed check means **not verified**. It does not mean "verified, with a
caveat". If the suite cannot go green here for reasons outside your change, say
exactly that and get an explicit decision before committing — do not decide on
the user's behalf that the reds are acceptable.

The phrasing matters, because "all green except some unrelated failures" reads as
green to anyone skimming, and the exception is the whole content of the sentence.

## Report

Lead with the verdict, then the evidence that supports it:

```
MINE — 2 specs fail only with this change.

  yours        checkout/payment.spec.ts, checkout/tax.spec.ts
  baseline     both pass on a clean HEAD worktree, same runner, 3/3 runs
```

```
NOT MINE — 4 e2e specs fail identically with and without this change.

  pre-existing search/*.spec.ts (4) — live-data coupled, same 4 on baseline
  green        type-check, unit (212), remaining e2e (38)
  note         cart/empty.spec.ts fails only on baseline — this change fixes it

  Not fully green. Commit anyway?
```

```
CANNOT DETERMINE — the deciding spec is flaky.

  flaky        upload/resume.spec.ts — 2 of 5 baseline runs fail
  bearing      this change touches the upload path, so it is not cleared
```

State how you established it — clean worktree, same runner, repeats — because
the claim is only worth what the method behind it is.
