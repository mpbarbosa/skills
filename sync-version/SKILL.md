---
name: sync-version
description: >
  Propagate a version bump from the project manifest to every file that
  carries a version string, without touching the ones that record history.
  Use after bumping a version, before a release, when a badge, CDN URL, docs
  header or runtime constant disagrees with the manifest, or when auditing
  whether the version a project reports about itself is the version it
  actually is.
---

# Syncing a version across a repository

The manifest — `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, a
`VERSION` file — holds the version. Everything else that names a version is a
copy, and copies fall behind: a README badge, a CDN URL, a runtime constant a
consumer reads back, a docs header, a JSDoc `@since`.

The work looks like find-and-replace. It is not, because of one distinction the
naive version gets wrong:

> **Every version string is either a claim about *now* or a record of the
> *past*.** Only the first kind should ever be updated.

A changelog entry, a migration note, a roadmap's shipped-releases table, a test
asserting what some old release returned — these are history. Rewriting them
does not fix an inconsistency, it destroys a record, and nothing downstream will
ever flag it.

## Step 1 — Read the canonical version

```sh
# pick the one that matches the project
node -p "require('./package.json').version"
python3 -c "import tomllib;print(tomllib.load(open('pyproject.toml','rb'))['project']['version'])"
grep -m1 '^version' Cargo.toml
```

If two manifests disagree, stop — you have found the real bug, and syncing
outward from the wrong one spreads it.

## Step 2 — Find the old version, but do not trust one source

The bump's own commit is the cheapest source:

```sh
git diff HEAD~1 -- package.json | grep '^-.*version'
```

**This fails in three ordinary ways**, so confirm what it gives you: the bump may
be several commits back; it may be uncommitted; and a regex written for one
version shape silently returns nothing for another. A pattern like
`\d+\.\d+\.\d+-\w+` requires a prerelease suffix — measured, it returns
`1.2.3-alpha` and returns **empty** for a plain `1.2.3`. An empty old-version
then flows into the replacement step, where GNU `sed` rejects the empty pattern
outright, but a `grep -qF ""` guard in front of it matches *every* file first.

So derive it, then check it is a version:

```sh
case "$OLD" in ''|*[!0-9.a-zA-Z+-]*) echo "refusing: OLD=[$OLD]"; exit 1 ;; esac
```

## Step 3 — Discover the occurrences; never work from a stored list

A hardcoded list of files to check is the part of this job that rots. It is
written once against the repo as it was, and a file that *gains* a version
string afterwards is never looked at again — the list keeps reporting all-clear
about a file it does not know exists.

Search instead:

```sh
git grep -nF "$OLD" -- . ':!*.lock' ':!package-lock.json' ':!node_modules'
```

Use `git grep` so tracked files are searched and ignored ones are not. Then read
**every hit** — this is the step that decides the whole job, and it is a
judgment, not a pattern.

## Step 4 — Classify every hit before changing any of it

| Kind | Examples | Action |
|---|---|---|
| **Claim about now** | badge, CDN URL, docs header, runtime constant, `@version` | **Update** |
| **Record of the past** | changelog entry, roadmap's shipped table, migration note, "since X" in prose | **Leave** |
| **Assertion** | a test comparing against the version constant | **Leave** — see below |
| **Tool-managed** | lockfiles, generated files, vendored directories | **Leave** — regenerate instead |

**A version in a test is an assertion, not a copy.** If it disagrees, the
source of truth is what is wrong; editing the test to match hides exactly the
bug the test exists to catch. Fix the constant and let the test pass on its own.

**One file often holds both kinds.** A roadmap with a `Current version:` header
above a table of past releases is the common case — the header is a claim, every
row below it is history. Scope the edit to the line, not the file:

```sh
perl -i -pe 's/(?<![0-9.])\Q'"$OLD"'\E(?!\d)(?!\.\d)/'"$NEW"'/g
             if /^> \*\*Current version:\*\*/' ROADMAP.md
```

Verified on a roadmap whose header and whose shipped-releases table both carried
`0.4.2`: the header became `0.5.0`, the table row kept `0.4.2`.

Getting this wrong is quiet: the file still parses, the diff looks plausible, and
the release history is gone.

## Step 5 — Replace with anchored matches

A plain substring replacement corrupts longer versions that share a prefix.
Measured, with `OLD=0.4.2` and `NEW=0.5.0`:

    sed -i "s|0.4.2|0.5.0|g"

    current: 0.4.2              -> 0.5.0           correct
    CDN: lib@0.4.20-alpha       -> lib@0.5.00-alpha   CORRUPTED
    older: 0.4.21               -> 0.5.01            CORRUPTED

Two separate defects: the dots are unescaped regex metacharacters, and there is
nothing stopping the match from ending mid-number.

**Word boundaries are not enough either.** `\b0\.4\.2\b` correctly refuses
`0.4.20`, but also refuses `v0.4.2` — `v` and `0` are both word characters, so
there is no boundary between them, and `v`-prefixed versions are everywhere in
tags, badges and CDN paths.

What works is a trailing guard that blocks only a *longer version* — a digit, or
a dot followed by a digit — while still allowing a version that is immediately
followed by a file extension. A flat `(?![0-9.])` looks right and is not: it
refuses to match `v1.2.3` in `archive/refs/tags/v1.2.3.tar.gz`, because the next
character is a dot. Tarball and CDN URLs are exactly where versions get
replaced, so that omission is silent and common:

```sh
perl -i -pe 's/(?<![0-9.])\Q'"$OLD"'\E(?!\d)(?!\.\d)/'"$NEW"'/g' <file>
```

`\Q…\E` escapes the version literally, so the dots cannot match anything else.
Verified against all nine cases:

    0.4.2  0.4.2-alpha  v0.4.2,  lib@0.4.2/x     -> replaced
    archive/refs/tags/v0.4.2.tar.gz              -> replaced
    0.4.20  0.4.21  10.4.2  v0.4.20              -> untouched

Structured files deserve a structured edit rather than a text one. A runtime
constant split into fields is a parse-and-write job, not a regex:

```js
src = src.replace(/(\bmajor:\s*)\d+/, `$1${maj}`);   // and minor, patch, prerelease
```

## Step 6 — Verify, and verify the right thing

```sh
git grep -nF "$OLD" -- . ':!CHANGELOG.md' ':!*.lock'   # should be only history
git diff --stat                                        # every file expected, nothing more
<the project's type-check / build / test command>
```

`git diff --stat` with no refs is right **here and only here** — before Step 7
commits, while the edits are still unstaged. The moment they are committed it
returns nothing, and so does any run of it from another worktree, so anyone
re-checking your "every file expected" claim afterwards gets silence and reads
it as agreement. For a check made after committing, name the refs:

```sh
git diff --stat origin/main...HEAD
```

`triage-test-failures` states the general rule and the measurements behind it.

The first command is the real check and it inverts the usual one: you are
confirming that what remains is **supposed** to remain. Read each surviving hit
and name why it stayed. "No output" is the wrong expectation here — a repo with
a changelog should still have hits.

Then confirm the new version is what the project *reports*, not just what its
files contain — if there is a runtime constant, a CLI `--version`, or a built
artifact, read it back:

```sh
node -p "require('./dist/index.js').VERSION"   # or: <cli> --version
```

A constant that was updated in source but not rebuilt still ships the old
number, and the source diff cannot see that.

## Step 7 — Commit the sync on its own

Keep it a separate commit from the bump and from any feature work. It touches
many files shallowly, which is exactly the diff nobody reads carefully — and the
one place a destroyed changelog entry would hide.

## Report

```
SYNCED to 1.4.0

  updated    README.md (badge, 2 CDN URLs), docs/API.md (header),
             src/version.ts (constant + @example), ROADMAP.md (header line only)
  left       CHANGELOG.md — 34 historical entries
             ROADMAP.md table — 11 shipped releases
             tests/version.test.ts — asserts against the constant
  verified   dist reports 1.4.0; type-check and tests pass
```

```
NOT SYNCED — the manifests disagree.

  package.json    1.4.0
  pyproject.toml  1.3.2

  Fix the source of truth first; syncing outward from either one spreads the
  wrong number.
```

## Rules

- **The manifest is the only source.** Never sync outward from a README.
- **History is not a copy.** Changelogs, shipped-release tables and migration
  notes keep their old numbers forever.
- **A failing version test means the constant is wrong**, not the test.
- **Never blanket-replace an unanchored version string** — it eats every longer
  version that shares its prefix.
- **A stored file list is a stale file list.** Search the repo each time.
- **Read back what the project reports**, not only what its files say.
