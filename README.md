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
  situations the skills quote and re-asserts the numbers they print. 31 of them:
  a branch deleted on origin and never pruned here, so `@{upstream}` still
  resolves while `ls-remote` reports nothing; `pgrep` matching the command line
  that runs it; the removals that exit 0 and leave the thing behind, from
  `git branch -d` to `kill` against a process ignoring `SIGTERM`; and what a
  listener scan cannot see, including a client and an owner.

The point is the second one. Those claims are about git, procps and the shell,
not about this repository, so they can stop being true without anything here
changing. The check goes red when the environment moves under a documented
number, and stays green when a sentence is reworded — which is the opposite of
what a test over the Markdown would do.

It carries positive controls for the same reason: a probe that cannot see a
branch which *is* on the remote proves nothing by failing to see one that is
not. They have earned it twice. One caught a defect in `session-pending` — its
`pgrep` examples used `generate\.ts`, and the escaped dot is precisely the form
that does *not* self-match, so the quoted `-> 1` and `-> 2` did not reproduce;
the recommended `| grep -v ' -c '` filter turned out to hide genuine processes
launched through a shell. Another caught a broken *fixture* rather than a broken
claim: a socket test that had stopped holding its connection open, so the thing
it measured was no longer established. Without the control it would have read as
the claim failing.

`session-dropped` was audited the same way and corrected the same way: its
listener scan used bare `ss -ltn`, which prints a port and no owner, while the
check two paragraphs later asks you to say whose it is. `ss -ltnp` attributes
your own processes without root.

Everything these scripts strictly need is `git`, `pgrep` and a POSIX shell.
Claims that need `ss`, `python3` or `gh` are skipped rather than failed when
those are absent. There is no package manager in this repository and nothing to
install.

## Conventions

- One directory per skill, at the repository root, containing `SKILL.md`.
- Frontmatter `name` matches the directory name.
- Every shell snippet is exercised before it ships. Where a skill quotes
  measured output — byte counts, exit codes, HTTP statuses — those numbers came
  from running it.
- A quoted number that depends on the environment rather than on this
  repository gets an assertion in `checks/measured-claims.sh`, with a positive
  control.
