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
| **Names assessed so far** | **34** |
| **Names not yet assessed** | **52** |

Four container conventions are in use: `.claude/skills/`, `.github/skills/`,
`.agents/skills/`, `.opencode/skills/`.

**The survey is incomplete.** It covered the 22 diverged names plus the 16 in
`agora_na_copa_2026`. The remaining 52 names have not been read at all — their
absence below is ignorance, not a decision.

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

### Not your work (1)

`grill-with-docs` — a fork of the skill in `third_party/skills/engineering/`,
already installed and available directly. Six diverged copies across your repos
are drift of someone else's skill. Candidate for deletion there, not import
here.

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

52 of the 86 names. They were excluded from the survey because they appear in
only one repository, so they raised no divergence question — **not** because
they were judged unsuitable. The largest unread pools are in `mpbarbosa.com`
(29 skills), `olinda_copilot_sdk.ts` (22), `guia_js` (14) and `ibira.js` (8).

To list them:

```sh
cd ~/Documents/GitHub
find . -maxdepth 6 -name SKILL.md \
  | grep -vE '/node_modules/|/third_party/|/archived_docs/|\.worktrees/|/\.git/' \
  | grep -vE '^\./skills/' \
  | sed 's:.*/\([^/]*\)/SKILL.md:\1:' | sort -u
```

---

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
