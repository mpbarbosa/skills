---
name: session-dropped
description: Confirm a teardown actually finished — an independent check that nothing of this session remains anywhere, run after session-teardown and before the window closes. Use whenever someone asks if it is now safe to drop, close or kill the session, whether cleanup worked, whether anything is left over, or says "did that work", "am I clear", "anything still hanging around". Removal can partly fail silently, so a teardown that reported success is not evidence that it succeeded.
---

# Did the teardown actually finish?

`session-teardown` reports what it *did*. This confirms what is *true*. Those
differ more often than they should, because removal can partly fail and say
nothing: a branch deleted locally whose remote copy survives, a worktree removed
whose registration lingers, a process that ignored a signal.

**The value here is entirely in re-deriving from scratch.** If you check by
recalling what teardown told you, you have confirmed a claim against itself and
learned nothing. Run the commands again, from the root checkout, and read the
listings.

## What "clear" means

Nothing of yours remains **in any of the five places state hides**, and each has
been the one that survived at least once:

```sh
git worktree list                       # 1. registrations, incl. stale ones
git branch --format='%(refname:short)'  # 2. local branches
git ls-remote --heads origin            # 3. REMOTE branches — the usual survivor
git status --porcelain -uall            # 4. the working tree
ss -ltnp 2>/dev/null | grep -E ':(3[0-9]{3}|[45][0-9]{3}|8[0-9]{3})'  # 5. servers
```

Narrow that port pattern to the range this project actually uses.

**`-ltnp`, not bare `-ltn`.** Without `p` you get a port and no owner, and this
check then asks you to decide whose it is. It needs no root to attribute what
*you* started. Measured on an unprivileged account:

    ss -ltn   ->  LISTEN 0 1 127.0.0.1:46129 0.0.0.0:*
    ss -ltnp  ->  LISTEN 0 1 127.0.0.1:46129 0.0.0.0:* users:(("python3",pid=249429,fd=3))

Local and remote are **separate deletions**. Whether a merge removes the remote
branch is a repository setting (`gh repo view --json deleteBranchOnMerge`), so
`git branch -d` succeeding tells you nothing about `origin`. That is the leftover
this check exists to catch, and it is the one that has actually happened.

Three other removals report success and leave the thing behind. Measured here:

    git branch -d <merged branch>   -> 0, and ls-remote still lists it on origin
    rm -rf <worktree directory>     -> registration stays, flagged prunable
    git worktree remove <untracked> -> 128, "contains modified or untracked files"
    kill <pid ignoring SIGTERM>     -> 0, and the process is still running

The first and the last are the pair to distrust, because both exit 0. `kill`
reports that it *sent* a signal, never that anything died. Re-read the listing
instead of the exit code, and ask `kill -0 <pid>` whether the process is still
there.

For anything still listed, decide which of three it is — **yours and leftover**,
**yours and deliberately kept**, or **not yours**. Only the first is a failure.
Say which for each, because a listing with no verdict makes the next reader
re-derive it.

## Things no listing shows

Confirm these by recall rather than command, since nothing else can:

- **Background tasks and monitors** — terminated, or still running?
- **Resources held through a tool rather than a port** — a browser pane, a
  preview server released only by its own `serverId`. A port scan cannot see a
  client: measured, a connected client's local port shows up in
  `ss -tn state established` and **never** in `ss -ltn`, whatever you grep for.
- **Promises** — did every handoff get acknowledged, or only sent? A message
  delivered to a session that never replied is not a completed handoff.
- **Anything you said you would do next.**

## The shared checkout is part of "clear"

You are done only if the root is as you found it: on its own branch, not moved,
and carrying no file you wrote. Check it explicitly — a session can be perfectly
clean in its own worktree and have left the shared one dirty.

## Answer

```
CLEAR — nothing of this session remains.
```

or

```
NOT CLEAR — <what survived>

  remote     fix-parser still on origin; local copy was deleted
  git push origin --delete fix-parser
```

or

```
CANNOT CONFIRM — <which check could not run>
```

List what remains that is **not** yours only if it might be mistaken for yours;
otherwise it is noise. And if something is deliberately left — an open PR
awaiting the user, a branch someone asked you to keep — say that it is deliberate,
or the next session will tidy it away.

## If it is not clear

Fix it and confirm again. Do not report "clear except for X": the phrase reads as
clear to anyone skimming, and X is exactly what they needed to see.
