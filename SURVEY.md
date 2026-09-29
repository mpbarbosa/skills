# Skill survey — what was imported, what was skipped, and why

A record of which skills in the sibling repositories under
`~/Documents/GitHub/` have been considered for this collection, so a later
sweep **re-confirms rather than re-litigates**. Skips are as much a result as
imports; an undocumented skip gets reassessed from scratch every time.

Last surveyed: **2026-09-28**.

---

## Scope and method

The corpus is every `SKILL.md` under a sibling repository, excluding
`node_modules/`, `third_party/`, `.worktrees/`, `archived_docs/` and `.git/`:

```sh
find . -maxdepth 6 -name SKILL.md \
  | grep -vE '/node_modules/|/third_party/|/archived_docs/|\.worktrees/|/\.git/'
```

| | Count |
|---|---|
| Files | 151 |
| Distinct skill names | 86 |
| Repositories holding them | 29 |
| Names with more than one copy | 27 |
| …of those, copies that have **diverged** | 22 |
| …of those, a **vendored third-party collection** (see below) | 29 |
| **Names assessed so far** | **74** |
| **Names not yet read in full — and yours** | **12** |

Four container conventions are in use: `.claude/skills/`, `.github/skills/`,
`.agents/skills/`, `.opencode/skills/`.

**The survey is incomplete, but less so than it first appeared.** It covered the
22 diverged names, the 16 in `agora_na_copa_2026`, and a later pass over what
remained. **12 first-party names have still not been read** — their absence from
the skip lists below is ignorance, not a decision.

Two corrections to an earlier count of 52 unread names, both of which inflated
it. Four (`session-pending`, `session-teardown`, `session-dropped`,
`verify-workflow-shell`) were **already imported here** — they appear in one
repository each, so they were neither diverged nor in `agora_na_copa_2026`, and
fell through a subtraction that never removed what this repo already holds. And
29 are not first-party at all (below). Derive "unassessed" by subtracting *both*
the imported set and the vendored set, or the same inflation returns.

---

## Imported

| Skill | Source | Note |
|---|---|---|
| `session-pending` | `portal_brasileirao/.claude/skills` | |
| `session-teardown` | `portal_brasileirao/.claude/skills` | |
| `session-dropped` | `portal_brasileirao/.claude/skills` | |
| `verify-workflow-shell` | `portal_brasileirao/.claude/skills` | |
| `import-adapt-guides` | `agora_na_copa_2026/.claude/skills` | 3 copies; see below |
| `triage-test-failures` | distilled from `agora_na_copa_2026` `test-commit-sync` | reshaped, not copied |
| `verify-deploy-landed` | distilled from `agora_na_copa_2026` `go-live-prod` | reshaped, not copied |
| `sync-version` | `olinda_copilot_sdk.ts/.github/skills` | 4 copies; see below |
| `update-url-dependency` | distilled from **9** `update-*` skills | replaces the whole family; see below |
| `verify-pasted-url` | distilled from **4** `place-*` skills | the verification half; see below |
| `mutation-test-guards` | distilled from `place-external-link` | the guard-proving half |

### Choosing among diverged copies

**Recency and size are the wrong signals.** `import-adapt-guides` has three
copies; the newest and longest (`catas_altas_speech`, 2026-06-23, 233 lines)
turned out to be an *adapted instance* rather than an improved template —
saturated with that project's own modules, so more of it would have to be
stripped. The base used (`agora_na_copa_2026`, 219 lines) was the right one
despite being older and shorter.

What worked instead: **count how often a copy names its own host repository.**
For `sync-version`, the four copies scored 0 (`olinda_copilot_sdk.ts`), 1
(`guia_js`), 1 (`bessa_patterns.ts`) and 3 (`ibira.js`). The zero-mention copy
was the cleanest base — and was not the newest.

Also worth knowing: divergence is mostly **real**, not formatting. Normalising
whitespace and table padding across all 22 diverged names collapsed exactly
one (`js-to-ts`). Do not assume a diff is cosmetic because one of them was.

---

## Skipped — persistent

These will not become candidates. Re-confirm in a sentence; do not reassess.

### Bound to the `ai_workflow.js` log pipeline (9)

`analyze-prompt-part` · `audit-and-fix` · `fix-log-issues` ·
`fix-prompt-response-issues` · `purge-workflow-logs` · `sync-workflow-config` ·
`validate-log-file` · `validate-logs` · `verify-workflow-efficacy`

They read and write `$project_root/.ai_workflow/` artifacts — `plan.md`,
`logs/`, `backlog/`, `.workflow-config.yaml`. A pipeline for one tool, not a
practice that transfers.

### Project-content skills in `agora_na_copa_2026` (10)

`analyze-match` · `find-missing-match-analyses` · `update-group-analysis` ·
`update-stale-team-analyses` · `mark-star-players` · `refresh-stale-star-notes` ·
`place-youtube-video` · `place-instagram-highlight` ·
`find-missing-match-videos` · `find-missing-highlight-videos`

Bound to specific data files and a live upstream API. The two `place-*` skills
carry one transferable idea — verify a pasted URL against the live source
before filing it, never trusting the search label — which is noted here rather
than imported, since the routing tables around it are the bulk of the skill.

### Not your work — a vendored third-party collection (29)

`mpbarbosa.com`'s skills directory is a checkout of the collection vendored at
`third_party/skills/` (Matt Pocock's, judging by `setup-matt-pocock-skills`).
All 28 of its names were checked against that directory and **all 28 are
present**, with no originals mixed in:

`caveman` · `design-an-interface` · `diagnose` · `edit-article` ·
`git-guardrails-claude-code` · `grill-me` · `handoff` ·
`improve-codebase-architecture` · `migrate-to-shoehorn` · `obsidian-vault` ·
`prototype` · `qa` · `request-refactor-plan` · `review` · `scaffold-exercises` ·
`setup-matt-pocock-skills` · `setup-pre-commit` · `tdd` · `teach` · `to-issues` ·
`to-prd` · `triage` · `ubiquitous-language` · `write-a-skill` · `writing-beats` ·
`writing-fragments` · `writing-shape` · `zoom-out`

Plus `grill-with-docs`, which is the same story — a fork of
`third_party/skills/engineering/grill-with-docs`, already installed and
available directly, with six diverged copies scattered across your repos.

Nothing here is a candidate. Several are already installed; the rest are
upstream's to maintain. Re-check the overlap with:

```sh
find third_party/skills -name SKILL.md | sed 's:.*/\([^/]*\)/SKILL.md:\1:' | sort -u
```

---

## Skipped — conditional

Worth revisiting if the stated condition changes.

| Skill | Why skipped | Revisit when |
|---|---|---|
| `docker-test` | Infrastructure — `Dockerfile.test`, browser path resolution, project fixtures | — its one general trap (a no-rebuild flag makes source changes invisible to the container) is already noted in `triage-test-failures` |
| `test-bump-deploy` | A project pipeline; its general content is one line ("abort at the first failing gate") and its triage half is weaker than what `triage-test-failures` took | Never, unless the pipeline shape itself becomes the subject |
| `bump-version-stage-commit-push` | Mostly worktree role-routing. One nugget kept elsewhere: the only safe-to-amend case is a local commit the remote never accepted | A general commit-flow skill is wanted |
| `test-commit-sync` | Its triage half became `triage-test-failures`; the commit-and-sync half is project-bound | Superseded |
| `go-live-prod` | Its verification half became `verify-deploy-landed`; the SSH/host specifics are project-bound | Superseded |
| The 5 dependency-bump skills | `update-bessa`, `update-guia`, `update-olinda-copilot-sdk`, `update-pajussara`, `update-pajussara-tui-comp` are five instances of one pattern: bump a sibling library delivered by CDN with a tarball fallback | A general "update a dependency distributed outside the package registry" skill is wanted — the pattern is real but narrow |
| `js-to-ts` | Narrower than the practice-shaped skills here — converts one file rather than teaching a method. Only one real version (its 2 copies differ cosmetically), so no canonical-copy decision to make | A JS→TS migration is actually planned |
| `next-roadmap-phase` | Bound to a documentation convention (`ARCHITECTURE.md`, `FUNCTIONAL_REQUIREMENTS.md`, `CHANGELOG.md`) rather than to a general practice | That convention becomes standard across the repos |

---

## Not yet assessed

**12 first-party names**, triaged by description but not read in full:

| Bucket | Names |
|---|---|
| Project-bound | `campanha-video`, `find-highlights`, `rodada-update` (portal_brasileirao) · `triagem-n8n` (linkedin) · `analytics` (tokentop) · `ship` (articles) |
| `ai_workflow.js` tooling | `ai-workflow-scaffold`, `fix-preflight-log-issues`, `next-roadmap-step` |
| Overlaps what is imported | `docker-test-fix` (→ `triage-test-failures`) |
| Thin | `update-submodules` |
| **Worth reading in full** | `validate-node-modules` — see the open question below |

### The dependency-bump family — resolved

`update-bessa` · `update-guia` · `update-ibira` · `update-olinda-copilot-sdk` ·
`update-olinda-sdk` · `update-olinda-utils` · `update-pajussara` ·
`update-pajussara-tui-comp` · `update-paraty-geocore`

Nine names, 23 files, all bumping a sibling library distributed outside the
package registry — a jsDelivr CDN URL, a GitHub tarball, a git clone — and each
hand-maintained in its own repo. **Replaced by `update-url-dependency`.** None
of the nine is a candidate any more.

Three hazards from reading them are recorded in that skill and are worth knowing
independently: the same release is written two ways (`v`-prefixed as a git tag,
bare as a CDN path), so one blanket replacement always misses half the
occurrences; the early-exit guard reads one location while the update writes
many, so a half-finished run is permanent and version *disagreement* is a
finding rather than a no-op; and a tag existing is not the artifact being
servable, which the test suite structurally cannot catch because tests resolve
`https://` imports through a local mapper and never fetch what users load.

### The place-* family — resolved

`place-external-link` (334) · `place-instagram-post` (314) ·
`place-youtube-video` (213) · `place-instagram-highlight` (148)

Four skills, 1009 lines, across two repositories. Each routes a pasted URL into
a curated file, and each is built on the same discipline with a different
routing table bolted on. **The discipline became `verify-pasted-url`; the
routing stayed behind**, being inherently per-project.

`place-external-link` carried more than one skill's worth. Its guard-proving
half became `mutation-test-guards` — three refusal assertions standing green
against a parser with no second refusal in it, because the realistic test input
was rejected by an earlier rule and never reached the guard.

Its third general lesson is **not yet folded in anywhere**: a command in a
skill that reads "the change" must name its refs. `git diff -- <path>` compares
the working tree to `HEAD`, so it answers about wherever you are standing —
returning 0 from a shared root, and 0 in the correct worktree the moment you
commit. It fails toward *you owe nothing*. The three-dot `origin/main...HEAD`
form is correct from anywhere at any commit state. Related: a plain `grep -c`
over a diff counts **context** lines, so an entry inserted beside the one you
are testing for reads as touched — `-U0` and a `^[+-]` filter are required.

### `copy-ts-to-project` was read, not imported

405 lines, well-organised, and almost entirely procedure — locate, propose,
confirm, copy, adapt, test, export, document, commit. Three habits worth
keeping: propose placement and wait rather than deciding; flag blocking
dependencies before starting rather than on failure; smoke-test through the
public entry point, which is what catches a module that compiles but was never
exported.

Skipped because it carries **no measured failure**, unlike every skill imported
here, and because it is bound to a specific docs convention (`ARCHITECTURE.md`,
`API.md`, `*-FRS.md`). Generalising it would leave a generic outline.

### `check-prod-parity` was read, not imported

Its marker list is specific to one site, but it documented three measurement
traps that were holes in `verify-deploy-landed`, and those have been folded in
there: ask a fetch for exact substring presence rather than an interpretation; a
converting fetch path drops HTML attributes so an absent marker may be a fetcher
artifact; and establish that a probe is observable at all before treating its
absence as evidence.

### `validate-node-modules` — open question

Solid and well-structured, but its value is its npm command sequences. It would
have to be imported as an ecosystem-specific skill; generalizing it across
package managers would gut it. **Undecided** — this collection is otherwise
ecosystem-agnostic.

## What makes a skill worth importing

From the eight taken so far, the ones that transferred shared a shape: **they
teach a way of establishing something, and the hard part is a measurement that
is easy to get wrong.** `session-pending` is about proving a branch has a
remote copy; `triage-test-failures` about proving a failure predates your diff;
`verify-deploy-landed` about proving a deploy reached the service.

What did not transfer: skills that run a specific pipeline, that read a
specific file format, or whose value is the list of paths they know.

A useful signal when reading a candidate — **does it contain a measured
failure?** The imported ones nearly all carry one: `pgrep` matching its own
wrapper, `@{upstream}` resolving against a deleted branch, `git branch -d`
succeeding on an unmerged branch, an unanchored version replacement corrupting
`0.4.20`. A skill that records what actually went wrong is one someone learned
from; a skill that only lists steps is usually a procedure for one repo.
