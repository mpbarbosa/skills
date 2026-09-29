---
name: resolve-npm-deprecations
description: >
  Clear `npm warn deprecated` lines from an install by tracing each warning to
  the dependency that pulls it in, deciding whether the fix belongs here or
  upstream, applying overrides one at a time, and proving no tests regressed.
  Use when `npm install` prints deprecation warnings, when auditing a
  dependency tree before a release, or when someone asks to clean up, fix or
  silence npm warnings. npm-specific.
---

# Clearing npm deprecation warnings

A healthy install prints no `npm warn deprecated` lines. Getting there is an
audit loop — capture, trace, classify, fix one thing, prove nothing broke — and
most of the work is in the classification, because **a large share of these
cannot be fixed from this repository at all.**

**A deprecation is not a vulnerability.** `npm audit` answers a different
question, and conflating them leads to forcing a risky override for a package
that is merely unmaintained. If a warning is also a CVE, that is a separate,
higher-priority job with different acceptable risk.

## Step 1 — Capture, and stop early if there is nothing

```sh
npm install 2>&1 | grep -E "^npm warn (deprecated|gitignore-fallback)" | sort -u
```

No output means no work. Say so and stop rather than hunting.

## Step 2 — Trace each to its root cause before touching anything

The warning names the deprecated package. It does not name what pulls it in,
and that is what you actually fix:

```sh
npm ls <deprecated-pkg> --depth=10
```

Record the **full chain** and the **direct parent**, because the direct parent
is the thing you will override:

    ts-jest → @jest/transform → babel-plugin-istanbul → test-exclude → glob

Overriding the deprecated package itself is the blunt instinct and usually the
wrong move — it forces a major version on a consumer that asked for an older
API. Overriding its parent is what removes the dependency.

## Step 3 — Classify: four outcomes, and two of them are "not here"

**A — A newer parent no longer depends on it.** The common fixable case.
Confirm it, do not assume:

```sh
npm show <parent> versions --json | tail -5
npm show <parent>@latest dependencies | grep <deprecated-pkg>   # want: no match
```

**Never add an override without that confirmation.** An override for a version
that still carries the dependency changes the tree, breaks the lockfile's
stability, and fixes nothing.

**B — It is a direct dependency.** Upgrade it normally, no override needed.

**C — Fixable in principle, but it regresses.** Some overrides jump a major
version and change an API that a transitive consumer relies on. Record it as
unsafe **with the evidence** — which suites failed, and with what error — so
nobody retries it in six months and rediscovers the same breakage.

**D — The fix lives upstream.** `npm warn gitignore-fallback` fires when a
git-sourced dependency ships no `.npmignore`; the change belongs in that
repository, not this one. Same for a package that must adopt a newer dependency
before its own transitive warning can clear. Name the upstream repo or issue and
what would unblock it.

C and D are **results**, not failures. A run that resolves two warnings and
documents three as upstream has done the job.

## Step 4 — One override at a time

```json
"overrides": { "<parent>": "^7.0.2" }
```

Apply one, install, test, and only then move to the next. Batching makes a
regression unattributable, and you will end up bisecting overrides by hand.

**Understand what an override is.** It forces a version across the whole tree,
including on packages whose own manifest declares an incompatible range — and
npm does not warn that it has done so. A parent declaring `^6.0.0` will silently
receive your `^7.0.2`. That can be completely fine, but "API-compatible" is then
a claim **you** established by running the tests, not something npm checked. Say
so in the commit, because the next person will read the override as sanctioned.

## Step 5 — Prove no regression, with a check that cannot lie

Capture a baseline **before** the first override, and compare after each one.
Two things count as a regression, and the second is the one that surprises:

- new failures, and
- **a drop in the number of tests that ran**, with no failures at all.

The second happens when an override breaks a loader, transform or environment:
the suite does not fail, it simply stops collecting tests, and the runner
cheerfully reports a smaller green number.

**Take the count from machine-readable output, not from the human summary:**

```sh
npx jest --json 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c)
  .on("end",()=>{const j=JSON.parse(d);console.log(j.numPassedTests)})'
# vitest: --reporter=json   ·   node --test: --test-reporter=tap
```

Grepping the printed summary is fragile in a way that fails toward "all clear".
Measured, the obvious pattern against three runners' output:

    Tests:       3649 passed, 3649 total   ->  "3649 passed"
    # pass 3649                            ->  ""            (node --test)
    3649 passing (2s)                      ->  ""            (mocha)

Two of three yield nothing — and when *both* sides yield nothing, the comparison
reports no regression having measured nothing at all. So guard the values before
trusting them, and compare numerically:

```sh
case "$BEFORE$AFTER" in ''|*[!0-9]*) echo "REFUSING: counts not numeric"; exit 1 ;; esac
(( AFTER < BEFORE )) && echo "REGRESSION: $BEFORE -> $AFTER"
```

Both guards earn their place. A string comparison calls `1000 < 900` **true**
and reports a regression that did not happen; and in an arithmetic test an empty
value is coerced to `0`, so a failed capture reports a regression from nothing.
Measured both ways.

If a regression appears: revert that single override, `npm install` to restore
the lockfile, and re-run to confirm the baseline is back. A restored
`package.json` with a rewritten lockfile is neither state.

## Step 6 — Commit with both lists

```sh
git add package.json package-lock.json
```

Record what was fixed **and what was not**, with the reason:

```
fix(deps): resolve npm deprecation warnings

Fixed via overrides:
- glob@7.2.3 — override test-exclude@^7.0.2 (drops glob@7 and inflight).
  test-exclude@7 is forced past babel-plugin-istanbul's declared ^6.0.0;
  API compatibility established by the suite, not by npm.

Not fixed:
- whatwg-encoding@3.1.1 — jsdom@26 has it as a direct dependency. Overriding
  jsdom to ^28 fails 17 suites (jest-mock: cannot assign to read only
  property). Blocked on jest-environment-jsdom adopting jsdom@^28.
- gitignore-fallback x2 — the git-sourced deps ship no .npmignore. Fix is a
  release in those repos.
```

The "not fixed" half is the more valuable one. It is what stops the next run
re-deriving the same dead ends, and it carries the condition that would make
each one actionable.

## Report

```
RESOLVED 3 of 5 warnings.

  fixed      glob@7.2.3, inflight@1.0.6   override test-exclude@^7.0.2
             whatwg-encoding@2.0.0        override html-encoding-sniffer@^6.0.0
  upstream   whatwg-encoding@3.1.1        blocked on jest-environment-jsdom
             gitignore-fallback x2        needs .npmignore in two repos
  tests      3649 -> 3649 passing, taken from --json; no suites lost
```

```
NO CHANGES — every warning is upstream.

  2 warnings, both from git-sourced deps with no .npmignore.
  Nothing in this repository can resolve them.
```

## Rules

- **Deprecated is not insecure.** Different question, different urgency.
- **Trace before overriding**, and override the parent, not the deprecated
  package.
- **Confirm with `npm show` that the target version actually drops it.**
- **One override at a time**, or a regression cannot be attributed.
- **An override forces a version past a declared range, silently.** Compatibility
  is your claim; record that you tested it.
- **A dropped test count with no failures is a regression.**
- **Never take the count from a human summary**, and guard it before comparing —
  an unparsed count reads as "no regression".
- **Upstream is an answer.** Record what would unblock it.
