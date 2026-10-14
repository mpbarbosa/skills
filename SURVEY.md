# Skill survey — what was imported, what was skipped, and why

A record of which skills in the sibling repositories under
`~/Documents/GitHub/` have been considered for this collection, so a later
sweep **re-confirms rather than re-litigates**. Skips are as much a result as
imports; an undocumented skip gets reassessed from scratch every time.

Last surveyed: **2026-10-14** — the three repositories named in that
sweep's "not yet assessed" list plus `trilhas_estudos`, which the earlier counts
had missed entirely.

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
| **Names assessed so far** | **75**, and as of 2026-10-14 every first-party name in the corpus |
| **Names not yet read in full — and yours** | **0** (was 11; see the two sweeps below) |

Re-measured on 2026-10-13 with the same command: **168** files, **97** distinct
names, **31** repositories. The table above is the 2026-09-28 snapshot and is
kept as written; see the hole in the exclusion list recorded in the
2026-10-13 sweep below before trusting either set of figures.

Four container conventions are in use: `.claude/skills/`, `.github/skills/`,
`.agents/skills/`, `.opencode/skills/`.

**The survey is incomplete, but less so than it first appeared.** It covered the
22 diverged names, the 16 in `agora_na_copa_2026`, and a later pass over what
remained. **11 first-party names have still not been read** — their absence from
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
| `resolve-npm-deprecations` | `guia_js/.github/skills/validate-node-modules` | renamed; **npm-specific** |
| `commit-in-shared-checkout` | distilled from `trilhas_estudos` `encerrar-branch` | sections 5–7 of it; the rest was already here |
| `enumerate-a-batch` | distilled from `linkedin` `triagem-n8n` | the enumeration discipline; the pipeline stayed behind |
| `verify-derived-figures` | distilled from `portal_brasileirao` `rodada-update` | one section of 428; the football stayed behind |

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

### Bound to one catalogue schema (1)

`autorar-catalogo` (trilhas_estudos) — a YAML schema, 11 numbered validations,
a `rev` table and four directory conventions. Its value is the paths and the
schema. Read in full on 2026-10-13; see the sweep section below for the two
habits noted but not imported.

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
| `rodar-app` | Two entrypoints, a port, a route list, a read-only snapshot — project-bound. Its one transferable finding (conflict markers inside a source file) is now in `triage-test-failures` | A general "drive this project's app" skill is wanted; the `/run` skill already covers much of it |
| `encerrar-branch` sections 1–3 | Already asserted here, in places more fully: `git branch -d` against the tracking ref, the three layers a branch lives in, `deleteBranchOnMerge`, the stash | Superseded by `session-teardown`, `session-dropped` and `commit-in-shared-checkout` |

---

## Not yet assessed

**None.** This list is empty as of 2026-10-14 — all ten were read in full and
their verdicts are in the 2026-10-14 sweep below. The buckets are kept because
the triage they record turned out to be **wrong about two of the ten**, which is
the argument for reading rather than triaging:

| Bucket | Names |
|---|---|
| Project-bound | `campanha-video`, `find-highlights`, `rodada-update` (portal_brasileirao) · `analytics` (tokentop) · `ship` (articles) |
| `ai_workflow.js` tooling | `ai-workflow-scaffold`, `fix-preflight-log-issues`, `next-roadmap-step` |
| Overlaps what is imported | `docker-test-fix` (→ `triage-test-failures`) |
| Thin | `update-submodules` |

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

Its third general lesson is now folded into `triage-test-failures`, with the
narrower case noted in `sync-version`: a command that reads "the change" must
name its refs, or it answers about wherever it is run. Nothing of
`place-external-link` remains unimported.

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

### `validate-node-modules` — imported as `resolve-npm-deprecations`

The open question is settled: **this collection accepts ecosystem-specific
skills**, and this is the first. Generalising it across package managers would
have removed the npm commands that are its substance.

Renamed because the original name misdescribes it — it does not validate
`node_modules`, it clears deprecation warnings — and every other skill here is
named for what it does. The source remains at
`guia_js/.github/skills/validate-node-modules`.

Its regression check was rebuilt rather than carried across. It took a test
count by grepping the human summary, which yields a number for Jest and nothing
for `node --test` or mocha; when both sides yield nothing the comparison reports
no regression having measured nothing.

## The 2026-10-13 sweep: `linkedin`, `trilhas_estudos`, `conversando_com_pessoa`

Four `SKILL.md` files across the three, found with the corpus command above
plus `--maxdepth 4` on each repository's `.claude/`:

| Repository | Skills | Outcome |
|---|---|---|
| `linkedin` | `triagem-n8n` | **distilled** → `enumerate-a-batch` |
| `trilhas_estudos` | `encerrar-branch` | **distilled** → `commit-in-shared-checkout` |
| | `autorar-catalogo` | skipped — persistent |
| | `rodar-app` | skipped; one finding folded into `triage-test-failures` |
| `conversando_com_pessoa` | none | `.claude/` holds only `settings.json` |

Two notes on the corpus itself, both re-measured on 2026-10-13.

**The exclusion list has a hole, and `-maxdepth 6` has been hiding it.**
`linkedin` holds a second copy of `triagem-n8n` at
`.claude/worktrees/worktree-envio-352-kodes/.claude/skills/`, which is **depth
8** — so the corpus command never descends to it. Drop the depth limit and
**46** files appear from under `.claude/worktrees/` across the repositories,
every one of them a duplicate of a skill already counted, because the pattern
`\.worktrees/` does not match `.claude/worktrees/`. Either keep the depth limit
knowing that is what is doing the work, or add the path:

```sh
grep -vE '/node_modules/|/third_party/|/archived_docs/|\.worktrees/|/\.claude/worktrees/|/\.git/'
```

Verified: with that pattern added, the count under `.claude/worktrees/` goes to
0 at any depth.

Related, and in the opposite direction: this repository now links a skill into
its own `.claude/skills/` for project scope. `find` does not follow symlinks, so
the command above counts it once — **`find -L` counts it twice.** Verified both
ways.

**`trilhas_estudos` was never in the corpus counts at all.** Its three names
are not among the 86, so the "11 not yet assessed" figure was short by three
rather than by the one (`triagem-n8n`) that was listed. Re-running the corpus
command today gives **168 files, 97 distinct names, 31 repositories** against
the 151/86/29 recorded above — the sweep's own numbers were a snapshot, and
repositories have been added since.

### `encerrar-branch` → `commit-in-shared-checkout`

279 lines, and **half of it was already here.** Its sections 1–2 — `git branch
-d` accepting a branch merged only to `origin/<branch>`, the three layers a
branch lives in, `git branch -r` against `git ls-remote`,
`deleteBranchOnMerge` making the second delete fail — are what
`session-teardown` and `session-dropped` already assert, in some places more
fully. Its section 3 (`git stash` taking another session's in-flight edit) meets
what `triage-test-failures` says about baselines from a different direction.

What was **not** anywhere here is its sections 5–7, and they are one subject:
in a shared checkout `HEAD` and the index are process-global, so a commit lands
where it finds itself and carries what it finds staged. Four measured failures,
each with a commit behind it in the source, all re-measured before import:

- `git branch --show-current &&` as a guard — it exits 0 printing the wrong
  branch, so the chain commits anyway
- `git commit` taking a path another session left staged, from a command line
  that named one path explicitly
- `git commit -- PATH` recording the **worktree** version and discarding the
  staged one, which makes it incompatible with the `git add -p` defence and so
  punishes the careful case
- `git add PATH` carrying another session's lines in that same file, invisibly
  to the whole-index check

Two things were added rather than carried over. The discarded staged version
survives as an **unreachable blob** and is recoverable until `git gc` — the
source said only that it is discarded. And the real fix is not a guard at all:
`git worktree add` gives a private `HEAD` *and* a private index, verified both
ways, so the guards are for when you are in the shared checkout anyway.

**Re-checked on 2026-10-13, section by section, after a second request to import
it.** Sections 1, 3 and 4 are covered: `git branch -d` against the tracking ref
and the three layers by `session-teardown` and `session-dropped`; the stash by
`commit-in-shared-checkout` section 6; "`git status` describes an instant" by
`session-pending`'s "the answer expires in seconds". Its closing three-way
classification of leftovers is `session-dropped`'s "yours and forgotten, yours
and deliberately kept, or not yours — only the first is a failure", including
the part about declaring a deliberate one.

Section 2 was **half covered, and the re-check found the other half.** That a
branch may have no remote copy, and what to run to see it, is `session-pending`
check 2. What was nowhere here is the limit on what you may then do: push it,
but **do not open the PR**, because describing someone else's commit means
inventing the intent behind it and the PR body is read as the author's own
account. Now in `session-teardown` step 2, with
`git log --format='%h %an %s' origin/main..<branch>` to name who wrote what. So
the first import was not complete, and only going back through the sections
against the text showed it.

Its closing section on how the skill itself went wrong four times in a day was
kept, condensed. It is the best statement of a hazard this collection runs on —
*"verified in an isolated repository" was in the text and was true; the axis
that was tested passed, and the axis that was not tested was never imagined* —
and two sessions in a row missed the same axis, which is an argument about the
shape of problems rather than about who was looking.

### `triagem-n8n` → `enumerate-a-batch`

191 lines, and the earlier sweep's triage of it as *project-bound* was right
about the bulk: a local n8n container, a webhook, two sibling repositories, five
files to update, an eight-digit id constraint from one node. None of that
transfers and none of it came.

Underneath it is a discipline that does: **a batch assembled by replaying a
query is not the batch you were asked about**, and it fails while looking
correct. Four measured traps, rebuilt against a loopback fixture before import:

- replaying the query that "produced" a digest can miss an id the digest
  carried — in the source's own case, one absent from all 200 positions the
  search returns, and the only hit in a batch of 51
- two live windows over a re-ranked source cover the right **count** with the
  wrong contents; the fixture gives union 40, zero duplicates, 10 foreign and
  10 missing
- a feed titled "new since last time" may be the whole board re-sent, with
  items five weeks old
- a sentinel-value health probe is rejected by the first stage and never
  reaches the broken one — the placeholder and a real item return the same `500`

Its measurement-integrity section came too, and is the part most likely to be
reinvented wrongly: reading an automated pass's own justification and finding it
convincing is **not** agreement with it, and must not be added to the same
series as verdicts recorded before the run.

### `autorar-catalogo` — skipped, persistent

111 lines, entirely bound to one catalogue: a YAML schema, 11 numbered
validations, `uv run trilhas validar`, a `rev` table, four directory
conventions. Its value is the paths and the schema, which is the stated
non-criterion. Two habits worth naming without importing: write a competence's
*verification* before its title, because one you cannot describe a test for is a
topic rather than a competence; and **never rename an id to correct it** —
create the replacement and deprecate the original, because history points at
ids. Both are domain modelling, not a measurement that goes wrong.

### `rodar-app` — skipped, one finding folded out

94 lines about two entrypoints, a port, a route list and a read-only snapshot.
Project-bound. Three general observations, of which one was worth keeping:

- **Kept**, in `triage-test-failures`: an unresolved merge in a shared checkout
  leaves conflict markers inside the source, and the parse error names a line
  you never touched. Correcting it on the way in was the point — the source
  called it a `SyntaxError` (it is an `IndentationError` here), and its two
  suggested probes, `git status` and `.git/MERGE_HEAD`, both read clean once the
  conflicted file has been committed, while the markers remain. Only a grep
  survives that case.
- Not kept: a dev server serves the code it loaded, so restart before concluding
  a change did not work. True and general, but widely known and carrying no
  measured failure.
- Not kept: composing an entity URL by hand yields a *handled* 404 that looks
  like "the entity is gone", so take the href rather than building it. This is
  the mirror of `verify-pasted-url` — a negative you cannot distinguish from
  evidence about the data — and is noted there in spirit already.

### `conversando_com_pessoa` — nothing to assess

`.claude/` contains `settings.json` only; there is no `skills/` directory and no
`SKILL.md` anywhere in the repository. Its practices live in `README.md` and
`ROADMAP.md`, which are not in this corpus. Re-confirm by looking for the
directory, not by searching for files.

## The 2026-10-14 sweep: the last 10 unassessed names

The "not yet assessed" list is now **empty**. All ten were read in full, and the
triage-by-description that stood in for reading them was **wrong about the two
that mattered** — the two largest, both filed as *project-bound* and therefore
uninteresting, carry more measured failures than the other eight together.

A cheap way to find that out, before reading 1 700 lines: count the markers a
measured failure leaves behind.

```sh
grep -ciE 'verificad|verified|measured|medido|armadilha|⚠️|exits? 0|silenc|silent' SKILL.md
```

| Skill | Repo | Lines | Markers | Verdict |
|---|---|---|---|---|
| `rodada-update` | portal_brasileirao | 428 | **13** | skip; **two findings**, one recommended for import |
| `campanha-video` | portal_brasileirao | 349 | **12** | skip; one finding folded out |
| `fix-preflight-log-issues` | olinda_copilot_sdk.ts | 239 | 3 | skip — persistent |
| `next-roadmap-step` | paraty_geoservices | 176 | 0 | skip — persistent |
| `update-submodules` | ai_workflow.js-revive-… | 134 | 0 | skip; **one finding folded out** |
| `find-highlights` | portal_brasileirao | 123 | 1 | skip — superseded |
| `ai-workflow-scaffold` | mapasp | 95 | 1 | skip — persistent |
| `docker-test-fix` | olinda_orchestrator | 52 | 0 | skip — superseded |
| `analytics` | tokentop | 44 | 0 | skip — persistent |
| `ship` | articles | 39 | 0 | skip — superseded |

**The marker count is a useful signal and not a sufficient one.**
`update-submodules` scored **0** and still carried the best single finding of the
ten, because it was written as a careful explanation rather than as a record of
being burned. Read the short ones anyway; it is cheap.

### Folded out, and asserted

- **`update-submodules` — a reversed commit range is a false-safe.** It guards a
  destructive submodule reset by listing commits that would be orphaned, and
  warns that the range must be `origin/main..HEAD`: reversed, it answers the
  opposite question and is **empty in exactly the case being checked for**.
  Verified with two unpushed commits — `2` the right way, `0` reversed, and a
  control showing the correct form is not merely always-stop. Now in
  `commit-in-shared-checkout` section 9, with assertions.
- **`campanha-video` — the shell's directory is shared mutable state too.**
  "Check `pwd` before a relative-path command, not once at the start." A shell
  whose directory had silently reset to the root checkout wrote two generated
  files into the wrong tree in one session, and **the tell was `git status` in
  the root showing edits nobody made there** — which is also what another
  session's work looks like, and the two have opposite remedies. Now
  `commit-in-shared-checkout` section 5; `cwd` joins the working tree, `HEAD`
  and the index in that skill's opening list.

### Taken, on 2026-10-14 — `verify-derived-figures`

The recommendation below was followed. What came across is the discipline; the
football, the scripts, the five files and the twenty-club palette stayed behind.
Ten sections, and **the numbers were rebuilt rather than copied**: a 20-unit
model with persistent strength plus noise, which is what makes the fault
invisible, and the arithmetic reproduces the project's real figure closely
enough to confirm the mechanism — mean inflation **4.1%** against their **4.4%**.

Rebuilding paid for itself twice. It turned the quoted percentage into a **law**:
the error is approximately **`1/N`**, so it is 4% over 24 periods, 1% over 100,
and 0.3% over a year of days — **the longer the series, the better the fault
hides, and the more trusted the number is because it has been stable for
months.** That is a stronger statement than any single percentage.

And the first attempt at the fixture **failed to reproduce the project's
observation**: with per-period values drawn independently, the ranking shuffled
11 of 20 places and the leaders changed, contradicting their "right-looking
ranks". The defect was the model, not the claim — real units have persistent
strength, so between-unit spread dominates within-unit noise. With that fixed:
ranks move **2 of 20** and the top five are identical. A fixture that does not
model the thing cannot test the claim, and the honest reading of the first run
was "my model is wrong", not "their observation is wrong".

The original recommendation, kept for the record:

**`rodada-update`: a rate whose numerator and denominator come from sources at
different vintages.** Its scouts sync divides one feed's counters by match
counts bounded by another feed's snapshot. When the snapshot lags by one round,
**every club's figure inflated 4.3–4.5%, mean 4.4% — and nothing about the
output looks wrong.** Twenty plausible rates, the right-looking ranks. Measured
by reproducing it one round early against data already on disk.

It carries its own two gates, which is what makes it skill-shaped rather than an
anecdote: the sync refuses when the numerator's round exceeds the snapshot's last
completed round, and the coverage denominator throws on the same fault from the
other side — two independent guards on one fault. **The gate then fired for real
on rodada 25**, caRtola at 25 against a seed at 24, and named both rounds.

This is on-criterion and nothing here covers it. It is left as a recommendation
rather than an import because it would be a new skill — a naming and scoping
decision — and the shape generalises well beyond football: any metric joining
two datasets that refresh independently. A second finding from the same skill
would come with it: **"check from" is a floor, not an appointment** — the
measured lag from a round's last kickoff to the publish that first carried it
was 1.6–1.7 days on five of six rounds, so poll daily from that date rather than
once on it.

**What reading it properly turned up, beyond the recommendation.** The skill held
more than the one finding, and the best of it was not the one that prompted the
import:

- **A number that moves in the flattering direction as a fault grows is not a
  gate against that fault.** An adjacent goals-reconciliation band was available
  as cover for the vintage fault, and under that exact fault it moves *further
  inside* its range — rebuilt here, `4.2` points inward. It would have been
  cited as reassurance. This is now the skill's central section, and it is
  `mutation-test-guards` applied to a number instead of a test.
- **The gate must be asymmetric.** A numerator *behind* the denominator is not a
  fault — it is the feed not having recorded something yet, honestly reported.
  Refusing both directions makes the gate fire in normal operation, and a gate
  that cries wolf gets removed.
- **Absent is not zero**, and the conflation runs both ways — the same shape as
  this repository's own `d4f3f4d`, "Record the zero that means the probe never
  ran".
- **A window derived from your own timestamps misses rows** when the upstream
  indexes by local date and you store UTC. Widen by one period each side — which
  is only safe because the write is a merge, so fix the write first.
- **Partial success is the interesting exit**, not a reason to re-run: output
  written plus a non-zero status means some records did not reconcile.
- **Throttling that happens at the socket** — no `429`, no `Retry-After` — is
  indistinguishable from the host being down, so the sleep is load-bearing.

The lesson for the method: this sweep was scoped to *record why these would be
skipped*. Two of the ten turned out to carry more than the eight others
combined, and the richest material was three quarters of the way down a
428-line file about football fixtures. **Triage by description is not reading.**

### Notes kept on the skips

- `ship` (articles) reaches **the same conclusion as
  `commit-in-shared-checkout` independently** — "prefer explicit paths over
  `git add -A` so nothing sneaks in" — and greps the diff for conflict markers,
  as `triage-test-failures` now does. But its push step is `git push`, falling
  back to `git push -u origin <branch>`, which is exactly the bare-push failure
  that skill's section 9 measures. Superseded rather than merely project-bound.
- `analytics` (tokentop) is procedure plus API facts, with one measurement
  caveat worth naming and not importing: Homebrew and Scoop install counts are
  **approximated from git clone counts** on the tap repositories, and the
  GitHub traffic API keeps only 14 days. A proxy presented in the same table as
  a direct count.
- `fix-preflight-log-issues` carries one habit worth having: **verify a logged
  issue still reproduces against the live repository before fixing it**, and
  treat one that does not as historical noise. It is bound to
  `.ai_workflow/logs/` and joins the nine already skipped for that.
- `docker-test-fix` is confirmed superseded: pure procedure, and the one general
  trap the earlier sweep attributed to `docker-test` is already in
  `triage-test-failures`.
- `find-highlights` is the `place-*` family again, one repository over.
  `verify-pasted-url` holds its transferable half.
- `next-roadmap-step` is `next-roadmap-phase` under another name, bound to the
  same `CHANGELOG.md` / backlog convention.
- `ai-workflow-scaffold` writes `.workflow-config.yaml` and the
  `ai_workflow.js` document set. The tenth member of that family.

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
