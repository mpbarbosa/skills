---
name: session-teardown
description: Close a session down safely — release what others are waiting on, then remove your own worktrees, branches, servers and background tasks. Use this after session-pending has answered, or whenever someone says they are done, wants to wrap up, close, drop, end or kill a session, clean up after themselves, or asks what needs tidying before they stop. Sessions often share a checkout, so teardown destroys things and the listings do not say what is yours.
---

# Tearing a session down

Teardown is the dangerous phase. Everything you do here removes something, the
listings show the whole machine rather than your share of it, and the state you
measured a minute ago has already moved.

Almost every near-miss in a shared checkout happens during cleanup, not during
work: servers killed by pattern that belonged to other sessions, a worktree
removed that turned out to be mid-task, a branch deleted with `-D` where `-d`
would have refused, an untracked file removed that was the only copy of itself.

## Run `session-pending` first, and act on *that* answer

Teardown without the pending check is guessing about what you are destroying. If
the check says **NOT YET**, resolve it — do not tear down around it. If it says
**CANNOT DETERMINE**, stop and say so; an unknown is not a no.

And do not tear down on a stale answer. **Re-measure immediately before each
destructive command**, not once at the start. A shared checkout moves between
commands, and a worktree that was clean when you listed it may not be when you
remove it.

## The order is release, then destroy

Others cannot recover what you take with you, and you cannot recover what you
delete. So the outward-facing half goes first, while you still have everything.

**1. Report and hand off what anyone is waiting on.** Unfinished work you claimed,
a result you promised, a monitor someone relies on, an open PR nobody knows is
orphaned. Say what you did, what you did not, and what you know that is not
written down. **A session that vanishes silently is worse than one that leaves a
mess**, because a mess is visible.

**2. Push anything unpushed.** One command, and it converts "would be lost" into
"is a branch on the remote". Do this before removing anything, so every later
step is reversible.

**3. Then remove your own artefacts** — worktrees, branches, servers, background
tasks. This is the destructive half and everything in it is yours only.

## The asymmetry that governs every command here

The same command is routine cleanup or irreversible loss, depending on whether
the work has landed:

| Command | Before the work lands | After |
|---|---|---|
| `rm` an untracked file | destroys the only copy | restores on next checkout |
| `git worktree remove` | loses uncommitted work | frees a directory |
| `git branch -d` | **succeeds anyway**, once pushed | routine |
| stopping a server | breaks something mid-run | frees a port |

That third row is the one that surprises: `-d` is the only command here that
*looks* like it checks, and the check it runs is not the one you want. See
**Branches** below.

So establish landing *before* each one, not once at the top:

```sh
git log --oneline origin/main -- <path>           # has this file landed?
git merge-base --is-ancestor <branch> origin/main # has this branch landed?
born=$(git reflog show <branch> --format='%H' | tail -1)   # ...or never started?
```

**The ancestry test says "landed" for a branch that was never worked in**, which
is how a prepared worktree gets swept as a finished one. `git worktree add -b`
leaves the branch on the commit it was created from, so `--is-ancestor` succeeds
and `git rev-list --count origin/main..<branch>` is 0 — the answers a merged
branch gives. Four branches have stood in one checkout, two merged and two never
started, all four answering identically. The third line separates them: if
`$born` still equals `git rev-parse <branch>`, the branch has never held a
commit, so it did not land — it never left. An **empty** `$born` is a reflog that
expired, which is `UNKNOWN` and never "merged".

Read that as *has this branch ever held work that removing it would destroy*,
not as *is its session finished* — no command answers the second. It fails safe:
a worktree holding uncommitted work also reports "never held a commit", and that
is a reason to leave it alone rather than a reason to doubt the test.

## Only yours — and the listings will not tell you

`git worktree list`, `git branch -a`, `ss -ltnp` and the PR list all show the
whole machine. Nothing in them marks ownership. Remove only what you created,
and where you cannot establish that you created it, **leave it and say so.**

**Knowing what you created is a record, not a memory.** `session-pending` says to
write down each worktree and branch *at the moment you make it*; this is the step
that spends it. Without that record you are recalling branch names at the point
where being wrong deletes someone else's work — which is the one place the
measure-don't-recall rule matters most.

**The record is a shared file, and it needs an absolute address:**

    $(git rev-parse --show-toplevel)/.claude/worktrees/COORDINATION.md

Resolve it from the **root checkout** and use the absolute path thereafter.
Yours makes your own removals safe; *theirs* is what makes a peer's worktree
legible to you, and it is the only thing that can distinguish a prepared worktree
from a finished one before you delete it. Such a ledger is normally gitignored,
so it is invisible from inside a worktree — read it by absolute path, always. If
the project's `CLAUDE.md` documents a different coordination convention, that one
wins; it is also reachable from where you are.

**A report that a branch merged is not evidence that it merged**, whoever sent
it. Re-run the ancestry check in the same turn as the removal, not in the turn
that decided on it: a merge reported in one such handoff turned out to be the
neighbouring PR's, four minutes earlier, and that re-run is the only reason an
unmerged branch survived.

**If you adopted a worktree rather than creating it, rename it to match the
branch you put on it.** Otherwise its name still advertises the previous
occupant's work: the creator cannot tell it from one they forgot they
re-pointed, and neither can you.

**A worktree the harness gave you is still yours, and there is no moment of
creation to have recorded.** A session can start already inside one — provisioned
before the first turn, dependencies and local env absent, branch already named.
The record rule has nothing to say about it, and "remove only what you created"
read literally leaves it behind forever. **The session's starting directory is
the record** in that case, and it is as good as any you would have written: no
peer can start where you started.

**Subtract your record from the listing, never the reverse.** Deriving the
removal list *from* the listing cannot distinguish something you forgot you made
from something that arrived while you were working — and the arrival is the more
dangerous reading, because a worktree created a minute ago is the one most likely
to hold work nobody has pushed. This is not hypothetical: during one teardown a
peer's worktree appeared between two commands, clean and a minute old.

Re-measuring guards against *the thing you measured having changed*. It does not
guard against *something new having appeared*. Only the record does that.

"It looked abandoned" is not attribution. A worktree that is clean, stale and
quiet is equally a finished session, a live session reading files, and an
abandoned one — and it has been each of those.

**Branches:** `git branch -d`, never `-D` — but do not mistake `-d` for a guard.
It compares against the branch's **upstream**, not against the default branch,
and that cuts both ways:

- It **refuses** a branch fast-forwarded past its own upstream, while that branch
  is fully merged. A false alarm; annoying.
- It **accepts** a branch that has merged nowhere, whenever the branch still
  tracks its own identical pushed copy — exit **0**, with a warning rather than a
  refusal. A false all-clear; destructive.

The second is the one to hold on to, because the condition that triggers it is
*having pushed*, which is the state every branch is in while its PR sits open:

    warning: deleting branch 'feature' that has been merged to
             'refs/remotes/origin/feature', but not yet merged to HEAD
    Deleted branch feature

Branches have been deleted this way while their PR was open and unmerged; nothing
was lost only because the commit was already on the remote. So `-d`'s **refusal**
is worth respecting — find out why rather than overriding it — while `-d`'s
**success** says nothing at all. Run the property that answers, in the same turn
as the deletion:

```sh
git rev-list --count origin/main..<branch>    # 0 => landed
```

**Local and remote are two deletions, and the remote one may already be done.**
Whether merging removes the remote branch is a repository setting — check it
rather than assuming:

```sh
gh repo view --json deleteBranchOnMerge
```

Where it is **false**, merging does *not* remove the remote branch and the second
deletion is usually still yours to make. It may nonetheless already be gone,
because a person clicked the button on the merged PR or another session removed
it. In that case `git push origin --delete <branch>` reports a *failure* for the
case where you have nothing left to do:

    error: unable to delete '<branch>': remote ref does not exist
    error: failed to push some refs to '<remote>'

Two lines beginning `error`, a non-zero exit, and the end state you wanted
already holds. **Ask before deleting, and read that message as success:**

```sh
git ls-remote --heads origin <branch>    # empty => the remote is already gone
```

This matters more than it looks, because the section below primes you to read
any failure here as real: removal *can* partly fail, and telling the two apart
by exit code alone is not possible.

**Deleting a local branch does not prune its remote-tracking ref.** So
`origin/<branch>` keeps appearing in `git branch -a` after both deletions have
succeeded, which reads as a leftover and is not one. Clear it with
`git branch -dr origin/<branch>`, and see the verify step below for why that
listing is the wrong one to confirm against.

**Servers:** stop by **recorded PID**. `pkill -f <pattern>` matches every
session's process, and has. If you did not record the PID, attribute it first
with `readlink /proc/<PID>/cwd`.

**Scanning cwds to ask who is in a worktree: `readlink` appends `" (deleted)"`,
and the obvious pattern swallows it.** The reverse scan — sweeping every pid to
find out whether a directory is occupied — is the one used before a destructive
step, and written the natural way it cannot answer:

```sh
case "$t" in *<name>*) echo "live worktree" ;; esac   # matches BOTH states
```

A process whose worktree was removed underneath it keeps running with a cwd that
no longer resolves, and `" (deleted)"` is the only trace — so a trailing-`*` glob
reports "live session in a live worktree" and "live session, worktree already
gone" identically. Those are different answers with opposite consequences: leave
it standing, versus there is nothing to leave. Give the marker its own arm:

```sh
for p in /proc/[0-9]*; do
  t=$(readlink "$p/cwd" 2>/dev/null) || continue
  case "$t" in
    *"(deleted)")  case "$t" in *<name>*) echo "${p##*/}: live process, worktree GONE -> $t";; esac ;;
    *<name>*)      echo "${p##*/}: live process, live worktree -> $t" ;;
  esac
done
```

and corroborate with `ls -d` and `git worktree list`. Three sources agreeing is
what separates the two states; any one alone misleads.

Both arms were exercised rather than reasoned about — a `sleep` was started in a
throwaway directory, the directory removed underneath it, and the scan re-run:
before removal it reported the live form, after removal the `GONE` form, and the
naive glob above called the same dead process "live worktree". A guard that has
only ever been watched passing is not a guard yet.

**And print the value you matched on, not a summary of it.** This was diagnosed
by the session it bit, and the diagnosis is worth more than the glob: their first
scan printed `cwd=$t` and carried the marker, the second printed only `cmd=` for
brevity — so `readlink` had returned the evidence and the *formatting* discarded
it before anyone could read it. They then reasoned from what was left and told a
peer not to sweep a worktree that had already been torn down.

That is the same failure as piping a ledger search through `| tail -40`: the
answer was retrieved and thrown away by presentation rather than by the command,
which is why re-reading the command shows nothing wrong.

**Servers and panes held through a tool are invisible to `ss`.** A browser pane
opened by a preview launcher is a client, not a listener, so no port scan will
find it, and the dev server behind it is released by the launcher's own stop call
(e.g. `preview_stop <serverId>`) — not by port and not by PID. Record the
`serverId` when you start it; that is the only handle you get.

**Background tasks and monitors:** these have no on-disk trace and die silently
with the session. Terminate them deliberately, and if anyone was waiting on a
result, that belongs in step 1 rather than here.

## Leave the shared checkout as you found it

Do not move the root checkout's HEAD, do not switch its branch, and do not
commit or restore files there that you did not write. A branch switch in a shared
root drags other sessions' uncommitted work across — that is the origin of the
worktree convention, and it has cost several sessions an hour.

## Verify after, not only before

Removal can partly fail, and a push can be rejected. Re-run the checks and report
what is actually gone:

```sh
git worktree list
git branch --format='%(refname:short)'       # local only
git ls-remote --heads origin                 # asks the remote, not a cached ref
ss -ltn 2>/dev/null | grep -E ':(3[0-9]{3}|[45][0-9]{3}|8[0-9]{3})'
git status --porcelain -uall
```

**Not `git branch -a` — it answers from a cache.** Remote-tracking refs are
whatever the last fetch left behind, and deleting a branch does not prune its
own, so `git branch -a` lists `origin/<branch>` after both deletions succeeded.
Confirming a *deletion* against it is the mistake this document spends its first
half warning about: reading a signal for what it resembles rather than what it
measures. `git ls-remote` asks the remote.

## An empty teardown is the good outcome

If you tidied as you went, the destructive half is a no-op and there is nothing
to remove. **Say so and stop.** This document is almost entirely about removal,
which creates a mild pull toward finding something to remove — resist it. A
session that arrives at teardown holding nothing did the work correctly earlier,
and the shortest honest report is the best one.

## The closing report

End with what you left behind, because the next session inherits it:

```
TORN DOWN

  merged     #67, #68 — both deployed
  left       .claude/worktrees/indexer — not mine, untouched
  handed off the failing-case re-run to <session>; they acknowledged
  nothing    no branches, worktrees, servers or tasks of mine remain
             (destructive half was a no-op — nothing was left to remove)
```

If something could not be cleaned up, name it and why. An honest leftover someone
can find beats a tidy report that is wrong.
