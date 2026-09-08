---
name: import-adapt-guides
description: >
  Import reusable engineering guides from a shared template library into this
  repository — assess which guides suit the project, copy the selected ones into
  docs/guides/, rewrite each one against the actual codebase, and update the
  index with both the imports and the deliberate skips. Use when the user asks
  to import, refresh, adapt or sync engineering guides, coding standards or
  documentation templates from a shared library or sibling template repo.
---

## Overview

A guide template library is a repository of reusable Markdown guides —
architecture, testing, naming, error handling, framework practice — written
generically so any project can adopt them. This skill moves a selected subset
into **this** repository and rewrites each one so it describes *this* codebase.

**An unadapted copy is worse than no copy.** A guide that still says "your domain
model" reads as boilerplate, gets skimmed, and is never cited in a review. The
import is the cheap half; the adaptation is the whole point.

Two artefacts result:

- `docs/guides/<GUIDE_NAME>.md` — one adapted guide per import
- `docs/guides/README.md` — the index, recording **imports and skips alike**

If the project already keeps its guides somewhere else, use that location and
keep its conventions. Do not relocate an existing set to match this default.

---

## Step 0 — Locate the library, and confirm it

Resolve the library path in this order, stopping at the first that exists:

1. A path the user gave in the request.
2. `$DOC_TEMPLATE_LIB`, if set.
3. A sibling checkout — the common case:

```sh
ls -d "$(git rev-parse --show-toplevel)"/../*doc*template* \
      "$(git rev-parse --show-toplevel)"/../*guide* 2>/dev/null
```

4. Otherwise **ask.** Do not guess at a path and do not proceed from memory of
   where a library lived in another session.

Then confirm what you found is the library and not a stale clone of it:

```sh
git -C <library> log -1 --format='%h %ad %s' --date=short
git -C <library> status --porcelain | head
```

Note the commit you imported from — the README index should record it, because a
guide adapted from a two-year-old template is not obviously distinguishable from
a current one later.

---

## Step 1 — Read the catalog, do not assume it

**Discover the library's structure rather than hardcoding it.** Libraries grow
folders between imports, and a hardcoded table silently hides every guide added
since the skill was written.

```sh
find <library> -name '*.md' -not -path '*/.*' | sort
```

Then read the library's own `CLAUDE.md` or `README.md` for the guide table — it
usually gives each guide's path and a one-line description, which is what makes
the assessment in Step 4 possible without reading all of them.

**Separate templates from the library's own meta-docs.** A library documents
itself as well as offering templates, and its `CHANGELOG.md`, `CONTRIBUTING.md`,
`GETTING_STARTED.md`, and its own `docs/ARCHITECTURE.md` or `docs/API.md`
describe *the library*, not a reusable practice. They are out of scope. The
reliable signal is folder placement plus content: a template states a principle
for any project, a meta-doc explains this library.

---

## Step 2 — Read the existing index first

```sh
cat docs/guides/README.md
```

It is the baseline, and it carries two kinds of decision:

- guides already imported, with the rationale that justified each,
- guides **explicitly skipped**, with the reason.

Do not re-import what is present. Do not overturn a recorded skip without a
concrete new reason — the skip exists precisely so the question is not
relitigated every time this runs.

If no index exists, every guide is a candidate.

---

## Step 3 — Build a concrete picture of this repository

You cannot judge fit, and you certainly cannot adapt, from a directory listing.
Read enough to name real files later. What to read depends on the project, so
discover it rather than following a fixed list:

```sh
ls -1                                        # top-level shape
cat CLAUDE.md CONTEXT.md 2>/dev/null         # stated architecture and vocabulary
cat package.json 2>/dev/null | head -60      # or pyproject.toml, go.mod, Cargo.toml, pom.xml
git ls-files | sed 's:/[^/]*$::' | sort | uniq -c | sort -rn | head -30
```

That last command ranks directories by file count and is the fastest honest
answer to "what is this project mostly made of".

From it, establish and write down:

- **Language, runtime, framework** — and which of those are actually load-bearing.
- **Entry points** — the server, the CLI, the app root.
- **Where domain logic lives**, as distinct from I/O and presentation.
- **The real test commands**, read from the manifest's script block, not assumed.
  `npm test` may not exist; `make test` may be the truth.
- **What kinds of tests exist** — unit, integration, end-to-end, none.
- **Which documentation conventions the project already has.**

Anything you cannot establish here becomes an honest gap in Step 6, not an
invention.

---

## Step 4 — Assess each unimported guide

For every library guide not already imported, decide **import** or **skip**, and
record a reason either way.

**Import** when at least two hold:

1. The repo already contains the kind of code the guide governs.
2. The guide addresses a risk or recurring pressure actually visible in the code.
3. You would cite it in a review or when arguing a design choice here.

**Skip** when any hold:

1. The repo has no code in that domain — no ADRs, so no ADR guide.
2. An imported guide already covers the concern adequately.
3. The guide assumes a pattern that conflicts with the project's stated approach.
4. It was skipped before for a reason that still holds.

**Re-examine previous skips against current reality.** Most skips are conditional
— "import once there are integration tests" — and the condition is what changed
since the last run. Generic triggers worth checking:

| What appeared since last import | May unlock |
|---|---|
| A server, API routes, or a public interface | API design, module boundary guides |
| Error handling, retries, fallbacks around external calls | Error handling, resilience guides |
| Input validation at a trust boundary | Defensive coding guides |
| Structured logging, metrics, tracing | Observability guides |
| A new test tier (integration, contract, e2e) | The matching test guide |
| A written domain vocabulary (`CONTEXT.md`) | Naming, domain modelling guides |
| Growth in component or module count | SOLID, coupling, cohesion, interface-first |
| Agent-assisted development in regular use | LLM-context, agent-workflow guides |

Build the equivalent table for this project once, from the library's actual
contents, and keep it in the index — it is what makes the *next* run cheap.

**Bias toward fewer.** Ten adapted guides that get read beat thirty that get
skimmed, and every import is a file someone must keep true as the code moves.

---

## Step 5 — Read each selected guide in full

Read the complete source of every guide you are importing, before writing its
adapted version. Not the one-line description, not a recollection of the genre.
A guide adapted from its title is a guess wearing the library's structure.

---

## Step 6 — Adapt, one guide at a time

Write to `docs/guides/<GUIDE_NAME>.md`. Finish one before starting the next —
batching produces uniformly shallow adaptation, because the specifics of one
guide stop being in view while you write the others.

**Replace generic project language with this project's terminology.**

> Generic: "the business rules in your domain model"
> Adapted: "the pricing rules in `src/billing/rates.ts` and the eligibility
> checks in `src/billing/eligibility.ts`"

**Map every abstract layer to a concrete path.** Guides define layers, component
categories, or boundaries; each needs a real location here. Add a table if the
guide lacks one:

| Concept in the guide | Where it lives here |
|---|---|
| Domain types / contracts | *…* |
| Domain logic / pure functions | *…* |
| I/O or HTTP boundary | *…* |
| Orchestration / assembly | *…* |
| Presentation | *…* |
| Unit tests | *…* |
| End-to-end tests | *…* |

**Every path you write must exist.** Verify as you write, not at the end:

```sh
git ls-files --error-unmatch <path>    # non-zero => you invented it
```

If a row has no location — the project has no such layer — say that in the row.
An honest blank is information; a plausible-looking path is a trap for whoever
follows it.

**Replace generic commands with the ones that actually run.**

> Generic: "run your test suite against a real database"
> Adapted: "`npm run test:unit` for pure logic; `npm run test:e2e` for browser flows"

Take these from the manifest, and prefer commands you have seen succeed.

**Trim what does not apply.** Cut sections whose technology has no presence here
— message queues, blue/green deploys, an ORM the project does not use. Cut the
*examples*, keep the *principle*: a guide reduced to only what is currently
practised stops being able to argue for anything better.

**Add a "Current reality" section wherever the principle is only partly met.**
State the present baseline and the gap plainly. This is the section teams
actually act on, and the one most often softened into uselessness.

**Preserve the structural skeleton.** Keep the heading hierarchy the library uses
(Goal → What it means → Why it matters → Rules / Signals / Checklist).
Predictable shape is most of what makes a set of guides usable.

**Cross-reference siblings that exist here** — link `./OTHER_GUIDE.md`, never
back into the library.

### How deep to adapt

| Guide type | Depth |
|---|---|
| Architecture (clean, coupling, cohesion) | High — map every layer to real paths |
| Testing | High — real commands, real fixtures, real seams |
| API design | High — map to actual routes and their error shape |
| Language or framework practice | Medium — scope to the directories that use it |
| Cross-cutting principles (DRY, naming, errors) | Medium — repo examples, general rules kept |
| Process and agent-assisted development | Low–medium — project file and budget notes |

---

## Step 7 — Rewrite the index

`docs/guides/README.md` must reflect the whole current state, not just this run:

1. **Imported** — each guide with a one-sentence rationale *specific to this
   repo*. "Covers testing" is not a rationale.
2. **Not imported** — every skip with its reason, updated where status changed.
3. **How to use these guides** — where a newcomer starts.
4. **Provenance** — the library and the commit imported from (Step 0).
5. **Links resolve.**

---

## Step 8 — Verify mechanically

Do not confirm this by re-reading your own work. Run it:

```sh
# every intra-guide link points at a file that exists
grep -oh '](\./[^)]*\.md)' docs/guides/*.md | sed 's:^](\./::; s:)$::' | sort -u \
  | while read -r f; do [ -e "docs/guides/$f" ] || echo "BROKEN LINK: $f"; done

# generic placeholder text that survived adaptation
grep -rniE 'your (project|domain|stack|team|database|service|application)|<[a-z-]+>|TODO|FIXME|placeholder' docs/guides/

# every code-fenced path still resolves
grep -ohE '`[a-zA-Z0-9_./-]+\.(ts|tsx|js|py|go|rs|java|json|yml|yaml)`' docs/guides/*.md \
  | tr -d '`' | sort -u \
  | while read -r p; do git ls-files --error-unmatch "$p" >/dev/null 2>&1 || echo "MISSING: $p"; done
```

The second command is the one that catches unadapted imports, and it should
return nothing but deliberate generic prose. Read each hit rather than counting
them.

Then confirm the index lists every new file, and that any guide moving from
"Not imported" to "Imported" was removed from the first table rather than
appearing in both.

---

## Quality bar

An adapted guide passes when:

- [ ] Someone working on this repo can follow it without knowing the library.
- [ ] Every path mentioned exists — verified, not eyeballed.
- [ ] Every command shown actually runs here.
- [ ] The core principle survived; only generic scaffolding was replaced.
- [ ] **It is shorter than the source.** Adaptation removes.
- [ ] The "Current reality" section is honest about what is not done yet.

---

## What not to do

- **Do not import unadapted.** A guide still saying "your database" was copied,
  not imported, and the index will claim otherwise.
- **Do not invent code examples.** Quote the repo or write none.
- **Do not import for concerns the project does not have.** Strategic DDD
  patterns on a small static site are noise that makes the real guides cheaper
  to ignore.
- **Do not drop the "Not imported" section.** Recorded skips are worth as much
  as imports: they are the only thing stopping the same debate next quarter.
- **Do not reference a guide from `CLAUDE.md` before the file exists.** Update
  `CLAUDE.md` last, after the guides are written.
- **Do not modify the library.** This is a one-way import. If a template needs
  fixing, say so — do not fix it inside a run that is meant to consume it.
