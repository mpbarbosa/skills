---
name: update-url-dependency
description: >
  Bump a dependency that is identified by a URL rather than by a registry name
  — a GitHub tarball, a jsDelivr or unpkg CDN import, a git clone — where the
  package manager cannot see that it is stale and the version string is spread
  across source, type declarations, test config and docs. Use when asked to
  bump, upgrade or refresh a sibling library, when a CDN import URL needs to
  move to a new release, or when a dependency has no registry entry to check.
---

# Bumping a dependency the package manager cannot see

A registry dependency has one version string, in one file, and `npm outdated`
will tell you it is behind. A **URL dependency** has neither property:

```json
"lib": "https://github.com/owner/lib/archive/refs/tags/v0.9.1.tar.gz"
```
```ts
import { thing } from "https://cdn.jsdelivr.net/gh/owner/lib@0.9.1/dist/esm/index.js";
```

Nothing watches these. No tooling reports them stale, no audit flags them, and
the version is written into however many files import it. That is the whole
reason this needs a procedure: **the update is a search-and-replace across an
unknown set of files, and the failure mode is missing one.**

## Step 1 — Inventory every occurrence before changing anything

Not the files you remember. The files that mention it:

```sh
git grep -nF "$DEP" -- . ':!package-lock.json' ':!*.lock'
```

Expect more categories than you planned for. Across real instances of this
pattern, the version has lived in all of these at once:

| Location | Why it is easy to miss |
|---|---|
| The manifest dependency URL | — the one everyone updates |
| Import URLs in source | often in *several* files, not one |
| An ambient type declaration (`.d.ts`) | type-checking breaks only later |
| A test-runner module mapper | and sometimes **mirrored** in two files |
| Docs and README | no build step fails on these |
| Tests asserting a version | |

**Mirrored config is the sharpest trap here.** A module mapper that exists both
in a standalone config file and inline in the manifest must move together —
update one and the pair silently disagrees, with no error at the point of the
mistake.

## Step 2 — Establish which version-string *forms* are in play

This is where a naive replacement fails, and it is not a corner case. The same
release is commonly written two ways in the same repository:

    git tag:     v0.13.1-alpha        (the GitHub release)
    CDN URL:     @0.13.1-alpha        (jsDelivr uses bare semver, no "v")

So replacing `v0.13.1-alpha` misses every CDN import, and replacing
`0.13.1-alpha` unanchored corrupts the tag into `vv…` or worse. Derive both,
explicitly:

```sh
TAG="v0.13.1-alpha"          # as published
BARE="${TAG#v}"              # as the CDN writes it
```

Then replace each **in its own locations**, anchored so a longer version
sharing the prefix is not eaten:

```sh
perl -i -pe 's/(?<![0-9.])\Q'"$OLD_BARE"'\E(?!\d)(?!\.\d)/'"$BARE"'/g' <cdn-carrying files>
```

That anchoring, and why word boundaries are not sufficient, is the subject of
`sync-version` — the same hazard, and this skill inherits all of it.

## Step 3 — The early-exit guard must read every location, not one

Every version of this procedure short-circuits when the dependency is already
current. That guard is correct and it is also where a partial update becomes
permanent.

The guard typically reads the current version from **one** place — the manifest,
or one source file — while the update writes **seven**. So if a previous run
half-finished, or a merge resolved one side of a conflict, the guard reads the
one location that is current, reports "already up to date", and skips the six
that are not. Nothing ever revisits them, because every future run reads the
same one location and reaches the same conclusion.

Check for *disagreement* first, and treat it as its own outcome:

```sh
git grep -ohE 'v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?' -- <the inventory> \
  | sed -E 's/^v//; s/(\.(tar|tgz|zip|gz))+$//' | sort -u
```

The `sed` matters: without it the pattern swallows an archive suffix into the
prerelease, so `v1.2.3-alpha.tar.gz` and `1.2.3-alpha` read as two versions and
a perfectly consistent repository reports a partial state. Dotted prereleases
(`1.2.3-alpha.1`) survive the normalisation intact.

More than one version present means a partial state, not a no-op. Report it as
such — it is a finding, and the fix is to complete the update rather than to
skip it.

## Step 4 — Resolve the target version from a source of record

```sh
gh api repos/OWNER/REPO/releases/latest --jq '.tag_name'      # published releases
gh api repos/OWNER/REPO/tags --jq '.[0].name'                 # fallback: no releases
git ls-remote --tags https://github.com/OWNER/REPO            # fallback: no gh
```

The first fails on a repository that tags but never publishes releases, which is
common — hence the fallback chain. Note that `.[0]` from the tags API is *most
recent by the API's ordering*, not necessarily the highest semver; check it
against what you expected rather than accepting it.

## Step 5 — A tag existing is not the artifact being servable

The most consequential difference from a registry bump. When a CDN is the
delivery path, the release and its availability are **separate events**:
jsDelivr caches on demand, so a tag can exist on GitHub, be written into your
import URLs, pass every local check, and still 404 for the first consumer who
loads the page.

So verify the URL you are about to ship, against the CDN, before finishing:

```sh
curl -fsS -o /dev/null -w '%{http_code}\n' \
  "https://cdn.jsdelivr.net/gh/OWNER/REPO@${BARE}/dist/esm/index.js"
```

A non-200 here is not a reason to abandon the update — propagation catches up —
but it is a reason to **say so explicitly in the report** rather than to declare
success. This is the same shape as a deploy that published without rolling out:
the pipeline is green and the thing users load is the old one.

## Step 6 — Know that your tests may not exercise the real path

Node and most test runners cannot resolve `https://` imports at runtime, so
projects using CDN imports map them to a local clone or a checked-out sibling in
test config. That mapping is what lets the suite run, and it means:

> **A green suite proves the new code works. It does not prove the URL your
> users load is correct.**

The test path resolves through the mapper; production resolves through the CDN.
A wrong CDN URL, a tag that does not exist, an entry-point path that changed
between releases — none of these can fail a test that never fetches the URL.
Step 5 is the only check that covers it, which is why it is not optional.

## Step 7 — Install, verify, and restore on failure

```sh
npm install
npm run verify        # or the project's real gate: lint + types + build + tests
```

**Restoring the manifest is not enough on failure — reinstall too.** The
lockfile was rewritten by the failed install and still resolves the new URL, so
a restored manifest with a stale lockfile is a third state that is neither
before nor after:

```sh
git checkout -- package.json package-lock.json && npm install
```

Refuse to start from a dirty tree, for the same reason: on failure you cannot
tell your changes from the ones that were already there.

## Step 8 — Commit the bump alone

```sh
git add <the inventory>
git commit -m "chore(deps): update <dep> from <old> to <new>"
```

Do not push, and do not bundle other work — this diff touches many files
shallowly across source, config and docs, which is exactly the shape that gets
skimmed.

## Report

```
UPDATED  lib  v0.9.1 -> v0.13.1-alpha

  manifest   package.json (tarball URL)
  source     src/index.ts, src/geo.ts, src/types/lib.d.ts  (CDN URL, bare semver)
  test cfg   jest.config.unit.js AND package.json inline mapper — both
  docs       README.md, docs/API.md
  verified   npm run verify passed; CDN URL returns 200
```

```
PARTIAL STATE — not a no-op.

  package.json      v0.13.1-alpha   (current)
  src/geo.ts        0.12.6-alpha    (stale — a previous run stopped here)
  jest.config.unit  0.12.6-alpha    (stale)

  The early-exit guard reads package.json, so every future run will report
  "already up to date" and skip these. Completing the update now.
```

```
UPDATED, BUT NOT YET SERVABLE.

  CDN https://cdn.jsdelivr.net/gh/owner/lib@0.13.1-alpha/... returns 404
  The tag exists on GitHub; jsDelivr has not cached it yet.
  Local checks all pass — they resolve through the test mapper, not the CDN.
  Re-check before anyone depends on this.
```

## Rules

- **Inventory first.** A remembered file list is the failure mode this skill
  exists to prevent.
- **Two forms of the same version.** The `v`-prefixed tag and the bare semver
  are both in play; replace each only where it belongs.
- **An early-exit guard reading one location is how a partial update becomes
  permanent.** Check for disagreement, and treat it as a finding.
- **A tag is not a servable artifact.** Verify the URL, not the release.
- **A green suite does not validate the URL** when tests resolve through a
  mapper. Nothing but an actual fetch does.
- **Restore *and* reinstall on failure** — a rolled-back manifest with a
  rewritten lockfile is a third state.
- **Never force a tag to move.** A URL dependency pinned to a tag has no
  integrity check to notice; consumers silently get different content under the
  same version.
