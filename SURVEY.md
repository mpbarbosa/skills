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
| **Names assessed so far** | **66** |
| **Names not yet assessed — and yours** | **20** |

Four container conventions are in use: `.claude/skills/`, `.github/skills/`,
`.agents/skills/`, `.opencode/skills/`.

**The survey is incomplete, but less so than it first appeared.** It covered the
22 diverged names, the 16 in `agora_na_copa_2026`, and a later pass over what
remained. **20 first-party names have still not been read** — their absence from
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

**20 first-party names**, triaged by description but not read in full:

| Bucket | Names |
|---|---|
| Project-bound | `campanha-video`, `find-highlights`, `place-instagram-post`, `rodada-update` (portal_brasileirao) · `triagem-n8n` (linkedin) · `analytics` (tokentop) · `ship` (articles) |
| `ai_workflow.js` tooling | `ai-workflow-scaffold`, `fix-preflight-log-issues`, `next-roadmap-step` |
| Dependency-bump pattern | `update-ibira`, `update-olinda-sdk`, `update-olinda-utils`, `update-paraty-geocore` |
| Overlaps what is imported | `docker-test-fix` (→ `triage-test-failures`) · `check-prod-parity` (→ `verify-deploy-landed`, see below) |
| Thin | `update-submodules` |
| **Worth reading in full** | `validate-node-modules`, `copy-ts-to-project`, `place-external-link` |

### The dependency-bump pattern has nine instances

`update-bessa` · `update-guia` · `update-ibira` · `update-olinda-copilot-sdk` ·
`update-olinda-sdk` · `update-olinda-utils` · `update-pajussara` ·
`update-pajussara-tui-comp` · `update-paraty-geocore`

All nine bump a sibling library distributed outside the package registry — a
jsDelivr CDN URL or a GitHub tarball — hand-maintained separately in each repo.
Nine copies of one procedure is the strongest standing case in this survey for
writing a single general skill.

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
