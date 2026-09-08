---
name: session-pending
description: Answer "is there anything pending in this session?" — a measured account of what this session still holds, so the user can decide whether to close it. Use this whenever someone asks whether a session can be dropped, closed, ended or killed, whether it is safe to stop, whether anything would be lost, or says things like "am I done here", "can I close this", "anything outstanding?", "wrapping up", "what's left". Sessions often share a checkout with other agents and with the user, so "pending" includes work others are waiting on — background monitors, promises, claimed tasks — not only uncommitted files.
---

# Is there anything pending in this session?

The real question is **"can I close this window without losing work or stranding
someone?"** Answer that.

Two halves: what *you* would lose, and what *others* are still waiting on. A
session with a spotless tree can be holding up three people.

## Two rules that outrank the checks

**Measure, do not recall.** Report only what a command just told you. A wrong
"nothing pending" is the single answer that destroys work.

**The answer expires in seconds.** A shared checkout moves under you: servers
appear and vanish between commands, `origin/main` advances mid-decision, PRs get
merged by someone else while you are reading them. So re-measure *immediately
before* acting on any finding. A snapshot is evidence for a verdict, never a
licence to act later.

## Presence is not ownership

Every listing here shows the whole machine, not your share of it. Before check 1,
write down what is actually yours: **the branches and worktrees you created this
session.** Then read every listing against that.

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

**`pgrep` will match your own command, always.** Every tool-run command sits in
the process table as a `sh -c …` / `zsh -c …` line containing the whole pattern
for as long as the `pgrep` inside it runs, so this is guaranteed rather than
incidental. Measured with **nothing** actually running:

    pgrep -cf 'generate\.ts'                 -> 1   the wrapper
    pgrep -cf 'tsx scripts/generate\.ts'     -> 2   also the wrapper
    pgrep -af 'generate\.ts' | grep -v ' -c ' -> 0  correct

Being more specific does not help — a longer pattern is still in your own command
line. **Read the matches, or exclude the wrapper; never count, and never gate an
`if` on it.** A count is a silent false positive every single time.

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

**2. Commits that exist on one disk only.** This check has two false negatives
and both fail toward "safe", so run it exactly as written.

**It must run per branch you own, not on `HEAD`.** Your HEAD is usually the
default branch, which has an upstream and is never the branch at risk. Checking
HEAD reports nothing while a feature branch is the thing that exists once.

**And `@{upstream}` is not evidence the remote copy survives.** It resolves
against your *local* `refs/remotes/origin/<branch>`, which persists until you
prune. If anyone deleted the branch on the server — a merge, a cleanup, another
session tidying — every local check still says backed up:

    someone else deletes it on origin; you have not pruned
      rev-parse --abbrev-ref feature@{upstream}  -> origin/feature   resolves
      git log feature@{upstream}..feature        -> 0 ahead — reads SAFE
      git ls-remote --heads origin feature       -> 0 refs — it is gone

Only asking the server settles it. This is not hypothetical; it has happened to
branches a session was deliberately keeping.

`ls-remote` needs no `fetch` first — it queries the server, and the stale local
ref does not affect it. Verified: with `refs/remotes/origin/feature` still
present, `ls-remote` already reported 0.

```sh
for b in <the branches you created>; do
  if [ -z "$(git ls-remote --heads origin "$b")" ]; then
    echo "NO REMOTE COPY — $b exists only here:"
    git log --oneline origin/main.."$b"
  fi
done
```

`git ls-remote` asks the server. A configured upstream, a resolving
`@{upstream}`, and a remote-tracking ref are all local state and none of them
proves a copy exists anywhere else.

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

**5. Servers you started, attributed.** A port number is not an owner:
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
| A promise, claim or accepted handoff | **Blocks** — nothing else will surface it |
| An open PR you opened | Mention — awaiting the user by design, not unfinished |
| A worktree you hold, clean and merged | Mention — costs only tidiness |
| A server you started | Mention — give the PID and what it serves |
| Uncommitted work **someone else wrote** | Mention — flag it, never commit it |
| Behind the default branch | Ignore |

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

If something blocks, give the command that clears it.

**Clear:**
```
SAFE TO DROP.

  holding    .claude/worktrees/parser — clean, merged, removable
  server     pid 2094463 on :3001, serving your worktree — yours to stop
  not yours  ?? src/core/cache.ts in root — another session's; left alone
```

**Not clear:**
```
NOT YET — two commits exist only on this disk, and a monitor is armed.

  no upstream  fix-parser: 97445f3, 3221126 have never been pushed
  monitor      watching the deploy pipeline; the user expects it to report
  promised     told the indexer session you would re-run the two failing cases

  git push -u origin fix-parser
```
