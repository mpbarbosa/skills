# skills

Agent skills, generalised from the ones that grew inside working repositories.

Each skill here started as a procedure written for one project — a football
site, a TypeScript library, a documentation toolchain — and was rewritten to
drop that project's paths, commands and vocabulary while keeping the part worth
keeping: **the failure someone actually hit.**

That is the entry criterion. A skill belongs here if it teaches a way of
*establishing* something where the obvious method quietly gives the wrong
answer:

- `pgrep` matching its own wrapper, so a process check is a false positive every
  time
- `git branch -d` exiting 0 on a branch that merged nowhere
- `@{upstream}` resolving happily against a branch deleted on the server
- a deploy pipeline printing `✓ Deployment complete.` beside
  `Skipping app-directory sync`
- a host answering `200` for an identifier that does not exist
- a test asserting a refusal, green against a parser with no refusal in it
- `git branch --show-current` printing the wrong branch and exiting 0, so the
  `&&` after it commits anyway
- two pages of a search covering 40 results, 10 of which were not asked for

Skills that only list steps stayed where they were. So did skills whose value is
the set of file paths they know.

## Installing

Skills are discovered at `~/.claude/skills/<name>/SKILL.md` (all projects) or
`<repo>/.claude/skills/<name>/SKILL.md` (one project).

**Symlink rather than copy:**

```bash
for d in ~/Documents/GitHub/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue    # checks/ is not a skill
  ln -sfn "${d%/}" ~/.claude/skills/"$(basename "$d")"
done
```

Copies drift, and this collection exists partly because of that. A survey of 29
sibling repositories found 27 skill names duplicated across them and **22 of
those had diverged** — one name had six different versions. Symlinks make a
`git pull` here the whole update.

That is not a hypothetical. On 2026-10-13, seven of these skills were installed
at `~/.claude/skills/` as **copies**, and six had drifted: all six were the
pre-audit text, still carrying the `pgrep` form and the bare `ss -ltn` that
[the audit below](#what-the-audit-found) records as corrected. The installed
copy was the version with the defect in it. Re-run the loop above to replace a
copy with a link.

### Scoped to this repository

`commit-in-shared-checkout` is also linked at
[`.claude/skills/`](.claude/skills/), so a session working *here* gets it
without a global install. The link is relative (`../../commit-in-shared-checkout`)
and committed, so a clone has it too. Any skill can be scoped the same way:

```bash
ln -sfn ../../<name> .claude/skills/<name>
```

One thing to know if you add more: `find` does not follow symlinks, so the
corpus command in [`SURVEY.md`](SURVEY.md) counts these once — but `find -L`
counts them twice.

## The skills

### Closing a session down safely

Several agents and a person often share one checkout, and the listings do not
say which worktree, branch or server is yours.

| | |
|---|---|
| [`session-pending`](session-pending/) | What this session still holds — including what others are waiting on, not just uncommitted files |
| [`session-teardown`](session-teardown/) | Release what others need, then remove your own artefacts. The destructive phase |
| [`session-dropped`](session-dropped/) | Independently confirm the teardown finished. Removal fails partly and silently |

Run in that order. The third exists because the second reports what it *did*,
not what is *true*.

### Establishing that something is actually so

| | |
|---|---|
| [`verify-workflow-shell`](verify-workflow-shell/) | Drive a CI step's own `run:` block against stubs — for deploy and schedule jobs a pull request can never exercise |
| [`verify-deploy-landed`](verify-deploy-landed/) | Query the live service, not the pipeline's exit code. Publish is not rollout |
| [`verify-pasted-url`](verify-pasted-url/) | Can a stranger open it, and can a machine confirm it — before you store it |
| [`mutation-test-guards`](mutation-test-guards/) | Delete the guard and watch a test named for it go red. Otherwise it is decorative |

### Working on a change

| | |
|---|---|
| [`triage-test-failures`](triage-test-failures/) | Is this failure yours or was it already red? Re-run the same suite on a clean baseline |
| [`commit-in-shared-checkout`](commit-in-shared-checkout/) | `HEAD` and the index belong to every session. A commit records what it finds, not what you added |
| [`enumerate-a-batch`](enumerate-a-batch/) | Prove the batch is the batch, when the items come from a query replayed rather than a list handed over |
| [`sync-version`](sync-version/) | Propagate a version bump everywhere it is claimed, and nowhere it is recorded |
| [`update-url-dependency`](update-url-dependency/) | Bump a dependency the package manager cannot see — a tarball, a CDN import, a clone |
| [`resolve-npm-deprecations`](resolve-npm-deprecations/) | Trace each `npm warn deprecated` to its parent, and prove the override regressed nothing. **npm-specific** |

### Tooling

| | |
|---|---|
| [`import-adapt-guides`](import-adapt-guides/) | Pull engineering guides from a shared template library and rewrite each against this codebase |

## Provenance

[`SURVEY.md`](SURVEY.md) records the sweep these came from: what was imported,
what was skipped and why, and what has not been read. Skips are kept
deliberately — an undocumented skip gets relitigated every time.

Three imports replaced whole families rather than single skills:

- `update-url-dependency` ← **9** `update-*` skills, 23 files
- `verify-pasted-url` and `mutation-test-guards` ← **4** `place-*` skills, 1009 lines
- `triage-test-failures` and `verify-deploy-landed` ← the release skills of one project

The survey also records the method: **recency and size pick the wrong copy** of
a diverged skill — the newest and longest was an adapted instance, not a better
template. Counting how often a copy names its own host repository picks the
right one.

## Checks

```bash
sh checks/run
```

Two of them, neither testing the prose:

- [`checks/skill-structure.sh`](checks/skill-structure.sh) — frontmatter that
  parses, `name` matching the directory, a description that exists and fits,
  code fences that close.
- [`checks/measured-claims.sh`](checks/measured-claims.sh) — rebuilds the
  situations the skills quote and re-asserts the numbers they print. **135 of
  them**, over ten skills.

The second one is the point. Those claims are about git, procps, perl and the
shell, not about this repository, so they can stop being true without anything
here changing. The check goes red when the environment moves under a documented
number, and stays green when a sentence is reworded — which is the opposite of
what a test over the Markdown would do. Each section was mutation-tested: the
claim was broken deliberately and the check watched to go red on the right
line, because a check only ever seen passing is the thing
[`mutation-test-guards`](mutation-test-guards/) is about. It prints the `git` and `pgrep` versions it measured against, since that
is what the numbers belong to.

What is covered, and the measurement each section turns on:

| Skill | The claim the check rebuilds |
|---|---|
| `session-pending` | `@{upstream}` resolving against a branch deleted on the server; `pgrep` matching the command line that runs it |
| `session-dropped` | removals that exit 0 and leave the thing behind, from `git branch -d` to `kill` against a process ignoring `SIGTERM`; what a listener scan cannot see, including a client and an owner |
| `session-teardown` | what `git branch -d` really compares against, in both directions; a prepared branch answering every landing test like a merged one; `readlink` appending `" (deleted)"` |
| `mutation-test-guards` | the pipe that turns a failing suite into three `PASS` lines and an exit 0; deleting the second of two refusals and watching the first two rows not move |
| `sync-version` | an unanchored replacement eating longer versions that share a prefix, and the four anchoring forms that get it wrong before the one that does not |
| `triage-test-failures` | one change seen through two diff forms in three states; a `grep -c` over a diff counting context as changed |
| `resolve-npm-deprecations` | a count grepped from a human summary yielding nothing for two of three runners, and the two guards in front of comparing it |
| `verify-deploy-landed` | a converting fetch path dropping the marker while the text it drives still renders; the cache headers that say you are reading the edge |
| `verify-pasted-url` | a lenient host answering `200` for an invented id exactly as for a real one, against a strict one that does not |
| `update-url-dependency` | one release written two ways, and an early-exit guard reading one location of several |
| `verify-workflow-shell` | `git merge-base --is-ancestor X X` being true, so an ancestor guard refuses the redeploy it was asked for |
| `commit-in-shared-checkout` | `git branch --show-current` exiting 0 on the wrong branch; a bare commit taking a path another session staged; a pathspec commit recording the worktree version and discarding the staged one; `commit -a` taking a file nobody named |
| `enumerate-a-batch` | two live windows covering the right *count* and the wrong contents, against one snapshot sliced locally; a handed id absent from the whole query said to have produced it; a sentinel-value probe and a pipeline broken after stage 1 returning the same status |
| `commit-in-shared-checkout`, the push half | a bare `git push` publishing the branch `HEAD` is on while your own commit stays unpushed, against a named refspec that ignores `HEAD`; `git config --get` reporting the value you set while `push` acts on the global one; a rejected push leaving the remote-tracking ref untouched |
| `session-pending` | `ls -d` over one present and one absent path exiting **2** while still printing the one that is there |

Positive controls throughout, for one reason: a probe that cannot see a branch
which *is* on the remote proves nothing by failing to see one that is not. They
have earned it twice — once catching a defect, and once catching a broken
*fixture* rather than a broken claim, where a socket test had stopped holding
its connection open. Without the control that would have read as the claim
failing.

### What the audit found

Four of the seven skills were corrected, and three were confirmed exactly as
written:

- `session-pending` — its `pgrep` examples used `generate\.ts`, and the escaped
  dot is precisely the form that does *not* self-match, so the quoted `-> 1` and
  `-> 2` did not reproduce. The recommended `| grep -v ' -c '` filter turned out
  to hide genuine processes launched through a shell.
- `session-dropped` and `session-teardown` — both scanned listeners with bare
  `ss -ltn`, which prints a port and no owner, while the step right after asks
  you to say whose each one was. `session-teardown` already used `ss -ltnp`
  correctly 190 lines earlier, so it disagreed with itself.
- `session-teardown`, again — it said the remote-tracking ref survives "after
  both deletions have succeeded", but your own `git push origin --delete` prunes
  it and the `git branch -dr` it prescribes then fails. The stale ref belongs to
  the case where the remote branch went *without* you. That paragraph now also
  records that `git branch -a` is wrong in both directions: it lists a branch
  deleted on the server, and omits one pushed by someone else and never fetched.
- `mutation-test-guards` — an addition rather than a correction, of exactly the
  kind it exists to catch. `${PIPESTATUS[0]}` recovers a status from behind a
  pipe only when read as the very next thing; one intervening command resets the
  array, and `st=$?` is one. Following the skill as written produced the false
  green the skill is about.
- `mutation-test-guards`, a third time, from trying to close the behavioural gap
  below. A trigger-rate harness scored every query `0.0`, which reads as a
  description that never fires; it was a subprocess failing to authenticate with
  its `stderr` discarded and its exit status unchecked. A positive control
  quoting a skill's own opening line scored `0.0` too, which is the only reason
  that did not get written down as a finding about the descriptions.
- `mutation-test-guards`, again, and this one was found by CI on its first run.
  `set -o pipefail` is not POSIX: GitHub's `ubuntu-latest` has an older `/bin/sh`
  that rejects it, while a current dash, bash and zsh all accept it. A workflow
  step running under `sh` therefore has neither `pipefail` nor `PIPESTATUS`, so
  the skill now gives the form that needs no pipe at all.
- `triage-test-failures` gained a section during the `trilhas_estudos` import,
  and correcting the source's claim was the point of writing it. The source said
  conflict markers in a `.py` give a `SyntaxError`; the interpreter here raises
  `IndentationError`, and more usefully the source's two probes — `git status`
  and `.git/MERGE_HEAD` — both read **clean** once someone has `git add`ed the
  conflicted file and committed it, while the markers are still in the file.
  They answer "was a merge interrupted", not "are there conflict markers". Only
  the `git grep` survives that case, and it is now the one the skill tells you
  to run.
- `commit-in-shared-checkout` had an open question in it — `-c
  push.autoSetupRemote=false` not changing a push's behaviour, with "I did not
  establish why" written down as the honest state. **Resolved, and the answer is
  worse than a flag that does not work.** On git 2.53.0, with a global
  `autoSetupRemote = true`, `git config --get` reports the `false` you passed
  while `git push` creates the branch anyway; with the global file out of the
  way, the same `-c false` refuses. `GIT_CONFIG_COUNT` and
  `git config --local` behave identically, so a global `true` is not
  overridable from inside the repository at all — and the command you would use
  to check cannot tell you which case you are in. Both halves are now asserted,
  against a fixture global config rather than this machine's.
- The checks written for the two new skills were mutation-tested like the rest,
  and the exercise earned its keep twice. One assertion was **weak**: it
  established that the guarded chain left nothing staged, which is equally true
  of a chain that aborted before `git add` and of one that ran all the way
  through the commit — so replacing the guard with the non-guard left it green.
  It now also asserts `HEAD` did not move. And one *mutation* was wrong rather
  than one assertion: switching a single window to the stable endpoint left the
  numbers at `10` and `10` by coincidence, because the fixture's re-ranking
  still advanced for the other two requests. A mutation that does not go red is
  not evidence until you have checked which of the two it indicts.
- `sync-version`, `triage-test-failures` and `resolve-npm-deprecations` needed
  no correction to anything they already claimed. All nine anchoring cases, the
  six-cell diff table, the `1`/`0`/`2` diff-grep counts and the three-runner
  summary patterns reproduced exactly as printed. (The `triage-test-failures`
  section above is material added later, from an import, not a claim of its own
  that failed.)

### Not covered

The three fetch-based skills are now asserted against a server the check starts
on loopback, which is not third-party traffic and needs no network. What is
*not* asserted is the part that belongs to particular hosts: the byte counts in
`verify-pasted-url` are measurements of YouTube and Discord, and re-checking
them would mean sending traffic to them on every run. So the mechanism is
asserted and the host-specific numbers are not — a probe that cannot
discriminate a real id from an invented one is rebuilt here, while the specific
`200 / 63681 B` against `200 / 63657 B` stays a recorded observation.

`import-adapt-guides` is the only skill with nothing to re-check: it quotes no
measurement.

The two skills imported from `trilhas_estudos` and `linkedin` are asserted the
same two ways the collection already uses. The git claims in
`commit-in-shared-checkout` run against a throwaway repository, so they are
measurements of `git` itself. The claims in `enumerate-a-batch` run against a
server the check starts on loopback, and its re-ranking is taken from the
request rather than from a call counter — an earlier version derived it from how
many times the endpoint had been called, which made the check flaky: a retried
request shifted every number after it. What is *not* asserted there is the
observation that belongs to one host's API on one day (one carried id absent
from all 200 positions of its own search, and the only hit in a batch of 51);
that stays a recorded observation, as the byte counts in `verify-pasted-url` do.

The other gap is behavioural. Nothing here checks whether a skill *triggers* on
the right request, or whether an agent following it reaches the right verdict.
That needs evals, not assertions.
[`checks/trigger-evals/`](checks/trigger-evals/) holds a labelled query set for
the first half of that — one set of 14 queries labelled three ways, so running
all three measures whether the overlapping session-* descriptions discriminate.
It has never produced a measurement here, and its README says why: `claude -p`
was unauthenticated, and the harness reports a failed run and a description that
never fires as the same `0.0`.

They run in CI on every push and pull request
([`.github/workflows/checks.yml`](.github/workflows/checks.yml)), because a
check nobody runs guards nothing.

Everything these scripts strictly need is `git`, `pgrep` and a POSIX shell.
Claims that need `ss`, `curl`, `lynx`, `python3`, PyYAML, `perl`, `bash` or an
authenticated `gh` are skipped rather than failed when those are absent — `gh`
validates auth before it validates a `--json` field name, so an unauthenticated
run would otherwise fail that check for the wrong reason. There is no package
manager in this repository and nothing to install.

## Conventions

- One directory per skill, at the repository root, containing `SKILL.md`.
- Frontmatter `name` matches the directory name.
- Every shell snippet is exercised before it ships. Where a skill quotes
  measured output — byte counts, exit codes, HTTP statuses — those numbers came
  from running it.
- A quoted number that depends on the environment rather than on this
  repository gets an assertion in `checks/measured-claims.sh`, with a positive
  control.
