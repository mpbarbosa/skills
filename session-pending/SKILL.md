---
name: session-pending
description: Answer "is there anything pending in this session?" — a measured account of what this session still holds, so the user can decide whether to close it. Use this whenever someone asks whether a session can be dropped, closed, ended or killed, whether it is safe to stop, whether anything would be lost, or says things like "am I done here", "can I close this", "anything outstanding?", "wrapping up", "what's left". Sessions often share a checkout with other agents and with the user, so "pending" includes work others are waiting on — background monitors, promises, claimed tasks — not only uncommitted files. Where the finding is your own uncommitted work or your own unpushed commits, this skill clears it — commits and pushes — instead of handing back a command, and stops short of publishing when the push would carry another session's commits.
---

# Is there anything pending in this session?

The real question is **"can I close this window without losing work or stranding
someone?"** Answer that.

Two halves: what *you* would lose, and what *others* are still waiting on. A
session with a spotless tree can be holding up three people.

## Three rules that outrank the checks

**Measure, do not recall.** Report only what a command just told you. A wrong
"nothing pending" is the single answer that destroys work.

**The answer expires in seconds.** A shared checkout moves under you: servers
appear and vanish between commands, `origin/main` advances mid-decision, PRs get
merged by someone else while you are reading them. So re-measure *immediately
before* acting on any finding. A snapshot is evidence for a verdict, never a
licence to act later.

**Your own channel can be stale.** "Measure, do not recall" assumes the
measurement reaches the thing measured, and that assumption fails when anything
sits between your shell and the world: a command proxy, a caching wrapper, a
harness that replays the stored output of a command string it has seen before.
Measured in a session whose commands were routed through such a proxy:

    git ls-remote --heads origin feature   -> 41b7de0   read as published
    git push origin feature                -> dcf7476..41b7de0, 7 objects written
                                              the server had been a commit behind

The read-only query was served stale, and the verdict built on it — "confirmed
with the server" — was wrong. Note which way it failed: toward **safe**.

So treat one command's output as one witness, not as the fact, and
**corroborate with a signal that does not share the channel.** Prefer the ones a
cache cannot plausibly fake:

- a command that *changes* state and reports what it changed — `push` printing
  `old..new` with a byte count — over a query that only reads;
- two differently-shaped commands agreeing: `git ls-remote --heads origin <b>`
  and `gh api repos/{owner}/{repo}/git/refs/heads/<b> --jq .object.sha`, a
  different binary over a different protocol. Verified: both print the same sha;
  `gh` expands `{owner}/{repo}` from the remote, so it pastes as written;
- a content hash that must match the bytes it names — which is why a report
  carrying the md5 of its own input stays trustworthy when the channel is not.

And **say which signal you used.** "I confirmed with the server" is worth less
than "ls-remote and the push's own transfer report agree", and the gap between
those two sentences is exactly where the error above lived.

## Presence is not ownership

Every listing here shows the whole machine, not your share of it. Before check 1,
write down what is actually yours: **the branches and worktrees you created this
session, and the branches you added commits to.** Then read every listing against
that.

Those are two lists and the second is the one that gets forgotten. A branch that
existed before your first turn is not yours by creation — but a commit you put on
it is, and check 2 is about commits, not branches.

**Write it somewhere a peer can read, not somewhere only you can.** If the
project has a shared ledger, use it; if it does not, the conventional address is

    $(git rev-parse --show-toplevel)/.claude/worktrees/COORDINATION.md

Resolve that path **from the root checkout** and write it down as an absolute
path. Such a ledger is normally gitignored, so it exists only in the root
checkout and cannot be seen from inside a worktree — open it by absolute path or
you will conclude it was deleted, as sessions have.

Record a worktree when you **create** it and again when you **adopt** one,
because the entry is what tells the next session that a clean, quiet directory is
prepared rather than finished. A worktree with no entry and no commits is
indistinguishable from a merged one by any command, and worktrees have been swept
on exactly that reading. If the project's `CLAUDE.md` documents a coordination
convention, follow that instead — and note its address here, because it is
reachable from where you are working.

This matters most in check 1. Uncommitted files in a shared checkout are usually
*someone else's* — committing them is the exact accident the worktree convention
exists to prevent. Never widen a commit to something you did not write.

There are **three** owners, not two. Besides you and other sessions, **the user
works at the terminal too** — a dirty generated directory may be someone running
the generator by hand. Git cannot tell you which; mtimes and the producing
process can:

```sh
ls -l --time-style=+%H:%M:%S <path>     # written seconds ago, or hours?
pgrep -af '<producing-command>'         # is it still running?
```

**`pgrep` can match the command line that is running it.** A tool-run command
sits in the process table as a `sh -c …` / `zsh -c …` line for as long as the
`pgrep` inside it runs, so a pattern that matches *its own text* finds that
wrapper and reports a process that does not exist. Being more specific does not
help: a longer pattern is still on your own command line. Measured with
**nothing** actually running:

    pgrep -cf 'generate.ts'      -> 1   the wrapper, not a generator
    pgrep -cf '[g]enerate\.ts'   -> 0   correct

Whether it self-matches **depends on the pattern**, which is why this is easy to
get wrong in both directions. Escaping the dot — `generate\.ts` — happens to
break the self-match, because the regex then wants a literal dot where your
command line has a backslash. That is luck, not a technique, and it fails the
moment the unescaped name appears anywhere else on the line. **Bracket one
character instead:** `[g]enerate\.ts` matches `generate.ts` and cannot match the
pattern as you typed it.

But bracketing protects the *pattern*, not the *line*. The plain name appearing
anywhere else in the same command — a second comparison `pgrep`, a path, an
`echo` of what you are hunting for — puts the literal text back on the line for
the bracketed pattern to find. Measured, with three real processes running and an
unbracketed copy of the name elsewhere in the same command:

    pgrep -cf '[m]easure_phonemes'   -> 4   three real, plus the wrapper
    pgrep -cf 'measure_phonemes'     -> 4   identical; the bracket bought nothing

So bracketing is necessary and not sufficient, which is one more reason for the
rule two paragraphs below.

Do not reach for `| grep -v ' -c '` to drop the wrapper. It drops every line
containing ` -c `, and a generator or dev server started *through* a shell — an
npm script, a preview launcher, `sh -c 'tsx scripts/generate.ts'` — has exactly
that on its command line. Measured with one of those genuinely running:

    pgrep -cf '[g]enerate\.ts'                -> 1   sees it
    pgrep -af 'generate.ts' | grep -v ' -c '   -> 0   hides it

A false negative is the dangerous direction here: it reports nobody running the
generator while someone is, which is the reading that gets a dirty tree swept.
**Read the matches; never gate an `if` on a count.**

For PRs, ownership often **cannot** be established: sessions frequently share one
forge account, so `--author` cannot separate you from anyone else. Say so rather
than claiming or disclaiming.

**Committed state cannot see work in progress.** `git show origin/main:<file>`
reads the commit; a capture, a sync or a generator writes the *working tree* and
commits at the end. Asking "has anyone started X?" of the committed state returns
"no" throughout the whole time someone is doing it. Read the tree — `git status`,
mtimes, running processes — when the question is about now.

## The checks

**1. Uncommitted — but only yours.**
```sh
git status --porcelain --untracked-files=all
```
Ignore paths you did not create. Ignore this skill's own file if you installed it
this session: a tracked `.claude/skills/` directory means installing a skill
leaves an untracked file that check 1 will report on its first run forever.

**And `git status` cannot see ignored data, irreplaceable or not.** Not with
`--untracked-files=all`, not with anything else in this check — so a directory
holding work that cost real effort to produce is simply absent from the answer.
Measured in a session holding eleven voice recordings in a gitignored folder:

    git status --porcelain --untracked-files=all | grep gravacoes  -> 0 lines
    git status --porcelain --ignored=matching    | grep gravacoes  -> gravacoes/

Sweep it, then judge by **what it would cost to produce again.** Build output,
caches and `node_modules` are noise. A *capture* is a finding: recordings, a
scraped or downloaded dataset with no script that re-fetches it, fixtures taken
from a system you no longer have access to. Closing the window does not delete
any of it, so this is a Mention rather than a blocker — but say it, because
nothing else here will, and "it is gitignored" is not the same as "it is safe".

**When check 1 finds work of your own, the commit is the hazard — not the dirt.**
This is a shared checkout, so `HEAD` and the index are process-global: a `git add`
can sweep in a file another session wrote between your two commands, and a
`git commit` can land on a branch they switched you to. Both exit 0 and print a
plausible summary. [`commit-in-shared-checkout`](../commit-in-shared-checkout/)
is that procedure, and this check is one of the places it is for.

**Measure whether it is installed; do not recall.** Which skills a session can
load is per session, and a skill that exists on disk is not necessarily one this
session was given:

```sh
ls -d ~/.claude/skills/commit-in-shared-checkout \
      "$(git rev-parse --show-toplevel)/.claude/skills/commit-in-shared-checkout" \
      2>/dev/null
```

**Read the lines; never gate an `if` on the exit status** — the same shape as the
`pgrep` count above, and it fails in the dangerous direction. With `2>/dev/null`,
`ls -d A B` exits **2** whenever *either* path is missing, and the usual case is
exactly that: installed globally, absent from the repo. Measured, with the skill
genuinely installed under `~/.claude/skills`:

    ls -d ~/.claude/skills/commit-in-shared-checkout /tmp/absent 2>/dev/null
      prints the symlink, and exits 2

An `if` on that status reports the skill missing while it is loaded and usable.

*Installed* — follow it, rather than improvising the commit here. *Not installed*
— say so in the answer, and still keep the two rules it exists to enforce:
**stage explicit pathspecs, never `-A` / `-u` / `.`**, and **read the branch back
*after* the commit** (`git log --oneline -1 <branch>`), because reading it
beforehand guards nothing — the switch can happen between the read and the write.

**2. Commits that exist on one disk only.** This check has two false negatives
and both fail toward "safe", so run it exactly as written.

**It must run per branch you own, not on `HEAD`.** Your HEAD is usually the
default branch, which has an upstream and is never the branch at risk. Checking
HEAD reports nothing while a feature branch is the thing that exists once.

**But "yours" here means committed to, not created** — the mirror of that case,
and it fails the same direction. A session handed a branch that already existed
creates nothing, so an ownership list built from creation is empty and the loop
below iterates over nothing while its own commits sit on one disk. Measured in a
session that inherited its branch and added two commits to it:

    git ls-remote --heads origin fase-2-pronuncia   -> 0 refs — never pushed

So include `HEAD` when you committed to it. The rule is not "skip HEAD", it is
"do not *only* check HEAD".

**And `@{upstream}` is not evidence the remote copy survives.** It resolves
against your *local* `refs/remotes/origin/<branch>`, which persists until you
prune. If anyone deleted the branch on the server — a merge, a cleanup, another
session tidying — every local check still says backed up:

    someone else deletes it on origin; you have not pruned
      rev-parse --abbrev-ref feature@{upstream}  -> origin/feature   resolves
      git log feature@{upstream}..feature        -> 0 ahead — reads SAFE
      git ls-remote --heads origin feature       -> 0 refs — it is gone

Only asking the server settles it — and even then it is one witness, because the
channel to the server can be stale too; see rule three. This is not hypothetical;
it has happened to branches a session was deliberately keeping.

`ls-remote` needs no `fetch` first — it queries the server, and the stale local
ref does not affect it. Verified: with `refs/remotes/origin/feature` still
present, `ls-remote` already reported 0.

```sh
for b in <the branches you created, plus any you committed to>; do
  if [ -z "$(git ls-remote --heads origin "$b")" ]; then
    echo "NO REMOTE COPY — $b exists only here:"
    git log --oneline origin/main.."$b"
  fi
done
```

`git ls-remote` asks the server. A configured upstream, a resolving
`@{upstream}`, and a remote-tracking ref are all local state and none of them
proves a copy exists anywhere else — but `ls-remote`'s answer is still one
witness, not the fact. Corroborate it per rule three before reporting a branch
as backed up.

**3. Open PRs.** `gh pr list --state open --json number,title,headRefName`
Yours are awaiting the user, not unfinished — see the weights below.

**4. Worktrees you hold.** `git worktree list`, minus the ones you did not
create. **Record each worktree and branch at the moment you create it**, not
here — at teardown you would be reconstructing from memory, which rule one
forbids, and peers' worktrees may already be gone so the listing cannot correct
you. This has failed inside a run of this skill: a session reported holding no
worktrees, then found one of its own on a later listing.

**And if you take over a worktree someone else created, rename it to match the
branch you put on it.** Adoption is what makes a directory unattributable — its
name still describes the previous occupant's work, so the creator cannot tell it
from one they forgot they re-pointed, and neither can you. Renaming keeps
`git worktree list` self-describing, which matters because that listing is the
thing everyone actually runs.

One worktree the record cannot cover: **the one the harness gave you**, which a
session can be started inside before its first turn. There was no moment of
creation to write down, so it is invisible to the rule above while still being
yours. The session's starting directory identifies it — no peer can start where
you started.

**5. Processes you started, attributed — not only servers.** A port number is not
an owner:
```sh
ss -ltnp 2>/dev/null | grep -E ':(3[0-9]{3}|[45][0-9]{3}|8[0-9]{3})'
readlink /proc/<PID>/cwd        # whose tree is it serving?
```
Narrow that port pattern to the range this project actually uses. The cwd also
tells you whether it serves **root** or your worktree — a preview launcher reads
its config (e.g. `.claude/launch.json`) from the session's primary directory, so
a session in a worktree can end up with a server running root's code. If you stop
one, stop it **by PID**. A broad `pkill -f` pattern matches every session's
server, and has.

**A port scan finds only listeners.** The process that matters may be a
foreground run waiting at a prompt, a test watcher, a long import or a recording
session — none of them listens on anything, and none is a "background task" for
check 7 either, so both checks miss it and nothing else looks. Sweep by working
directory instead:

```sh
raiz=$(git rev-parse --show-toplevel)
for d in /proc/[0-9]*; do
  cwd=$(readlink "$d/cwd" 2>/dev/null) || continue
  case "$cwd" in "$raiz"*) printf '%s  %s\n' "${d#/proc/}" \
      "$(tr '\0' ' ' < "$d/cmdline")";; esac
done | cut -c1-120
```

The `cut` is not cosmetic: your own agent process carries kilobytes of flags on
its command line and will bury every other match without it.

Measured in a session whose interactive recording run sat blocked on `input()`:
`ss` matched none of its three PIDs, and the sweep found all three. It also found
the session's own `claude`, two login shells and the `head` in its own pipe — the
apparatus-in-its-own-output hazard this skill names twice elsewhere. Read the
lines and discount what is you.

**A live process of yours blocks** when you promised its result, or when it is
part-way through work that would have to start over. One idling with nobody
waiting is a Mention, like a server.

**6. Distance behind the default branch.**
`git fetch origin && git log --oneline HEAD..origin/main` — informational only.

**7. Background tasks, monitors and session-held resources.** The largest gap:
none of this touches disk. Background commands, monitors, scheduled work — and
resources held through a tool rather than a port, like a browser pane, which
`ss` cannot see because a client is not a listener.

If the harness reports orphaned tasks, that notification is a signal worth
reading rather than dismissing — but read what it names. One such listing named
**its own output file**, present while the command ran and gone by the time it
was read. Same shape as this skill's own file tripping check 1: a measurement
that includes its own apparatus.

**Then classify, because a stopped task is not automatically a blocker.** The
question is not "did something die" but **"did I promise its result?"** A poll
loop that timed out with nobody waiting is noise; a monitor watching a deploy the
user asked to be told about is a promise, and belongs below.

**8. Promises.** Re-read your last several messages and ask the concrete
questions, not the general one — "did I promise anything?" is too easy to answer
no to from memory:
- did I say "I'll report back" / "I'll tell you when"?
- did I claim a task, or accept a handoff?
- did I tell another session I would do something, or ask them to wait?

## Weighing what you found

| Finding | Weight |
|---|---|
| Uncommitted work **you wrote** | **Blocks** — exists in one place only |
| Commits not pushed, or a branch with no upstream | **Blocks** — one disk, no copy |
| An armed monitor or background task someone relies on | **Blocks** — dies silently with the session |
| A live process you started, waiting or part-way through | **Blocks** — no port to find it by, and it dies with the shell |
| A promise, claim or accepted handoff | **Blocks** — nothing else will surface it |
| An open PR you opened | Mention — awaiting the user by design, not unfinished |
| A worktree you hold, clean and merged | Mention — costs only tidiness |
| A server you started | Mention — give the PID and what it serves |
| Irreplaceable captured data in an ignored path | Mention — closing does not delete it, but nothing protects it either |
| Uncommitted work **someone else wrote** | Mention — flag it, never commit it |
| Behind the default branch | Ignore |

## Clearing what you found

Two of the findings above are cleared here rather than handed back as a command
to paste: **your own uncommitted work**, and **your own commits that have never
left this disk**. In that order, because the second depends on the first.

Everything else in the weights table is reported and never executed. No command
discharges a promise; stopping someone's process, removing a worktree or killing
a server is a decision, not a cleanup. Clearing the two that *are* mechanical is
what buys the right to be strict about the rest.

**Do not improvise the commit.** `commit-in-shared-checkout` is the procedure and
this is the place it is for — measure that it is installed, as check 1 says, and
follow it. Its two rules are the ones to keep if you ever have to improvise:
stage explicit pathspecs, never `-A` / `-u` / `.`, and read the branch back
*after* the commit, because reading it beforehand guards nothing.

Then push. The push is where this section earns its keep, because it is the one
step here that publishes **other people's** work.

**Read what the push would carry before running it.** A push ships the branch,
not your commit:

```sh
git log --format='%h %an | %s' origin/<branch>..<branch>
git rev-list --count origin/<branch>..<branch>   # must match the lines printed
```

The order of the refs is not cosmetic — reversed, the range is empty in exactly
the case you are checking for. And the two numbers are worth more than either
alone: a wrapper between you and `git` has dropped a merge commit from the
`--format` output while `rev-list --count` still counted it, and a merge is
precisely the commit that carries someone else's work.

**If that range holds a commit you did not make, stop. Report, do not push.**
Publishing another session's commit is not yours to authorize, however ordinary
your own commit is — the session that made it may be waiting to be asked, or
waiting for a review, or holding it back deliberately. This is the only stop in
this section, and it is not a formality:

    measured in a shared checkout, 09/11/2026 — a session committed 756c3fa to
    main, the user said "not yet", and within the hour another session landed
    e1c91ad on top. From that moment `git push origin main` would have published
    two commits from two sessions, under one authorisation that named neither.
    Nothing in the command says so; only the range does.

If every commit in the range is yours:

```sh
git push origin <branch>        # name the refspec: a bare push follows HEAD,
                                # which another session can switch under you
```

**Then read the result back from the server, not from `origin/<branch>`** — the
local remote-tracking ref is exactly what a failed push leaves untouched:

```sh
git ls-remote --heads origin <branch>
git rev-list --count origin/<branch>..<branch>    # expect 0
```

Per rule three, prefer two signals that do not share a channel: the push's own
`old..new` transfer line reports a *change* and is the stronger witness;
`ls-remote` reads. Say which ones you used.

**A rejected push is the check working**, not an obstacle: the server moved while
you worked. `git fetch origin && git merge origin/<branch>`, then **read the
range again** — the merge has just pulled in commits that were not in your first
read, and the stop above applies to them too — and push once more. **Never
`--force`**: it is the one action in this document that no later command undoes.

**Report what you ran, with the shas.** A session that cleared something and did
not say so reads exactly like one that found nothing.

## The answer

Lead with the verdict. Three are available, and the third is not a hedge:

```
SAFE TO DROP
NOT YET — <the one thing>
CANNOT DETERMINE — <which check failed, and why it matters>
```

Reach for the third when a check could not run or returned contradictory
answers. That is not rare: a forge API has reported one run as `queued` with zero
jobs, then refused to cancel it as `completed`, then refused again as "not been
queued yet" — three mutually exclusive states for one object. Forced into a
binary you would pick one and be wrong; "I could not establish X" is a true
answer and a useful one.

Then one line per check that **found** something, and silence for the rest. The
reader is deciding, not auditing.

If something blocked and you cleared it, say so with the shas and the signals you
read — see the section above. If something blocks and you did **not** clear it,
give the command, and in a shared checkout that command has to be safe to paste:
`git add -A && git commit` is not, because by the time it runs the tree may hold
someone else's file. Name the paths.

The commonest case of "blocks and was not cleared" is the stop: your commit is
ready to go and the range carries someone else's. Name **their** commits, not
just yours, so the reader is deciding about what would actually be published.

**Clear:**
```
SAFE TO DROP.

  holding    .claude/worktrees/parser — clean, merged, removable
  server     pid 2094463 on :3001, serving your worktree — yours to stop
  not yours  ?? src/core/cache.ts in root — another session's; left alone
```

**Cleared:**
```
SAFE TO DROP — committed and pushed.

  committed  4b1e007 docs/api.md, docs/auth.md — mine only; index was empty
  pushed     git push origin fix-parser -> 97445f3..4b1e007, 6 objects
  confirmed  ls-remote and the transfer line agree; origin/..HEAD now 0
```

**Not clear:**
```
NOT YET — two commits exist only on this disk, and a monitor is armed.

  no upstream  fix-parser: 97445f3, 3221126 have never been pushed
  monitor      watching the deploy pipeline; the user expects it to report
  promised     told the indexer session you would re-run the two failing cases

  git push -u origin fix-parser
```
