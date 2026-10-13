---
name: commit-in-shared-checkout
description: Commit safely in a checkout that other agents and the user are editing at the same time, where HEAD and the index are shared mutable state — so a commit lands on a branch you did not choose, or carries files and lines you never added. Use before any `git add` or `git commit` in a shared or multi-agent checkout, when a commit turned out to contain someone else's work, when `git switch` is blocked by uncommitted files you did not write, before reaching for `git stash`, or when deciding whether a commit that went to the wrong branch should be moved.
---

# Committing in a checkout someone else is editing

In a checkout shared by several agents and a person, three things you would
normally treat as yours are not: **the working tree, `HEAD`, and the index.**
All three are process-global and all three move between any two commands you
run.

The consequence is specific, and it is not "merge conflicts". It is that
`git commit` succeeds, exits 0, prints a plausible summary, and records
something other than what you meant — on another branch, or with extra paths,
or with extra lines. Every commit failure below exits 0 and prints a summary
that looks like what you asked for.

> **The real fix is not to share.** `git worktree add` gives you your own `HEAD`
> and your own index, and nothing below can then happen to you. Verified: with
> `w.txt` staged inside the worktree, `git diff --cached --name-only` in the
> shared checkout prints nothing, and a `git switch` inside the worktree leaves
> the shared `HEAD` where it was. Everything that follows is for when you are
> committing in the shared checkout anyway.

For *whether* a reading is still true when you act on it, see
[`session-pending`](../session-pending/) — "measure, do not recall" and "the
answer expires in seconds" are the same discipline applied to the same
checkout. This skill is about the commands that quietly obey a reading that has
already expired.

## 1. `git branch --show-current &&` is not a guard

Another session can run `git switch` in this checkout. Your next `git commit`
then goes to *their* branch, stacked on work that is not yours — no error, no
warning.

The instinct is to print the branch first and chain. **It does not protect
anything:**

```sh
git branch --show-current && git add PATH && git commit -m "…"   # NO
```

`git branch --show-current` exits 0 whatever it prints. Verified, standing on
the wrong branch:

    git branch --show-current     -> other-session, exit 0
    chain continued, commit made  -> on other-session

It printed the wrong answer and `&&` carried on. A guard has to **compare** the
value, so that the test — not the human reading the output — is what fails:

```sh
[ "$(git branch --show-current)" = main ] && git add PATH && git commit -m "…"
```

Verified on the wrong branch: the chain exits 1, nothing is staged, **and
`HEAD` has not moved**. Replace `main` with the branch you intend to be on.

Both halves of that evidence are needed, and finding out why is a small instance
of this skill's closing section. "Nothing is staged" was the first thing checked
and it is **not** evidence that the guard worked: it is equally true of a chain
that aborted before `git add` and of one that ran all the way through, because
a successful `git commit` empties the index too. Only `HEAD` separates them:

```sh
before=$(git rev-parse HEAD)
[ "$(git branch --show-current)" = main ] && git add PATH && git commit -m "…"
[ "$(git rev-parse HEAD)" = "$before" ] && echo "nothing was committed"
```

**The guard narrows the window; it does not close it.** The check and the
commit are still two operations, and the other session is still running. So
read back what actually happened, from the commit rather than from your
intention:

```sh
git log -1 --format='%h %D'      # -> e8f5d94 HEAD -> feature
```

### If it already landed on someone else's branch

Prefer leaving it there. It reaches the base branch when that branch merges.
Moving it means `git cherry-pick` plus removing the commit from a branch
another session is actively working on, and rewriting the history of someone
who is mid-change costs more than waiting.

## 2. `git commit` commits the whole index, not what you just added

The index is shared. A `git add` from another session minutes ago is still
staged, and `git commit` with no pathspec takes all of it.

Verified — another session leaves `theirs.txt` staged, you stage only
`mine.txt`:

    git add mine.txt && git commit -m "Only mine, surely"
      -> commit contains: mine.txt  theirs.txt

Two defences. The first detects, the second prevents:

```sh
git diff --cached --name-only        # the WHOLE index, with no pathspec filter
git commit -m "…" -- PATH            # commits only this path
```

The filter matters. `git diff --cached -- PATH` confirms the path you already
know is there and tells you nothing about the rest of the index, which is the
part that surprises you.

Verified, same setup:

    git commit -m "mine only" -- mine.txt   -> commit contains: mine.txt
    git diff --cached --name-only  after    -> theirs.txt   (still staged, intact)

Their work is left exactly where they put it, which is the point — the next
bare `git commit` takes `theirs.txt` alone.

## 3. But the pathspec silently discards what was staged for that path

`git commit -- PATH` commits the **working-tree** version of that path, not the
staged one. Verified, with `version-A` staged and `version-B` in the tree:

    git commit -m "which one?" -- f.txt
      committed -> version-B
      index now -> version-B      (the staged version-A is gone from the index too)

`version-A` is not destroyed immediately — it survives as an unreachable blob:

```sh
git fsck --unreachable          # -> unreachable blob 7f9639a…
git cat-file -p 7f9639a         # -> version-A
```

and `git gc --prune=now` then removes it for good (`git cat-file -t` on it
afterwards: `fatal: could not get object info`). So recovery is possible and
time-limited, which is worth knowing but is not a licence to rely on it.

**This makes the two defences incompatible**, and in the direction that
punishes care. If you used `git add -p` to isolate only your own lines in a
file another session also edited, a `git commit -- PATH` afterwards throws that
isolation away and commits the whole file — their lines included. Choose by the
*file*, not by the state of the index:

| The file you are committing | Defence |
|---|---|
| Only **you** touched it, index dirty with other people's paths | `git commit -m "…" -- PATH` — the tree version is yours, there is nothing staged worth preserving |
| Another session **also** touched it | `git add -p`, then `git diff --cached --name-only`, then `git commit` with **no** pathspec |

## 4. `git add PATH` takes their lines in that same file

Section 2 is about an extra *path*. This is an extra *change inside the path
you named*, and the check from section 2 cannot see it.

Verified — they edit line 1 of `shared.md`, you edit line 3:

    git add shared.md
    git diff --cached -- shared.md   -> 2 added lines, one of which is yours
    git diff --cached --name-only    -> shared.md        (nothing looks wrong)

The two checks are orthogonal, and neither covers the other:

| What slipped in | Caught by |
|---|---|
| A path you never added | `git diff --cached --name-only` — unfiltered |
| Their lines in a path you did add | `git diff --cached -- PATH` — read it, do not just run it |

For a file several sessions edit at once — a root `CLAUDE.md`, a `README.md`, a
shared ledger — read the staged diff before committing. If it contains lines
that are not yours, `git restore --staged PATH` and split with `git add -p`.

Where `git add -p` is unavailable, the honest options are to ask the other
session to commit first, or to commit the whole file **and name in the message
what came with it and whose it is**. Silently shipping their lines under your
message is the failure; shipping them with attribution is merely untidy.

`git commit -a` is this trap over every file at once: verified, it added
`unrelated.txt` — a file no one had staged and you never named — alongside
`shared.md`. In a shared checkout, do not use it.

## 5. A loaded index is itself the hazard

Every failure above lives in the window between `git add` and `git commit`, and
that window belongs to every session in the checkout. So stage and commit in
one command rather than leaving the index loaded.

That shortens the window but **does not replace the table in section 3**: the
choice between the two defences is made by the file, not by how clean the index
is. In a file another session also edited, `git commit -- PATH` against an empty
index still commits that whole file from the tree, their lines included.

## 6. Do not reach for `git stash`

When `git switch` is blocked by uncommitted files, `git stash` is the obvious
move and it is the wrong one here: those files may be another session's
in-flight edit, and stashing takes them out of the tree it is working in. From
that session's side, the file reverts by itself.

Ask it to commit instead. If the stash already happened, `git stash pop`
returns the content — then confirm *both* halves, because they can disagree:

```sh
git stash list && git status --porcelain -uall
```

Recorded in the checkout this came from: an empty `git stash list` was followed
seconds later by a `git stash pop` that found content. Read both immediately
before acting, not earlier.

For running a test baseline without disturbing the tree — the other common
reason to reach for `stash` — use a detached worktree instead; see
[`triage-test-failures`](../triage-test-failures/).

## 7. After the fact

If the mixed commit is still local, fix it. If it has been pushed in a checkout
other sessions pull from, **do not rewrite it** — published history that others
have is worth more than correct attribution. Tell the session whose work you
carried, so it does not commit the same lines a second time.

## When editing this skill: verified does not license the generalisation

The source this came from was corrected four times in a day, always by whoever
wrote it. Three of the four had distinct causes worth repeating; the fourth was
the same lesson being overstated as law:

| What was wrong | How it got there |
|---|---|
| `git branch --show-current &&` recommended as a guard | written without ever being run |
| `git commit -- PATH` called "the defence" for section 2 | two axes tested, the third not imagined |
| "section 5 makes the section 3 table unnecessary" | generalising a defence that worked |

The middle one is the instructive one, because the sentence *"verified in an
isolated repository"* was already in the text and was **true** — the axis that
was tested passed. The axis that was not tested was never imagined, and
verifying what you imagined while publishing what you did not is one movement,
not two. It cannot be felt from the inside. Two sessions in a row missed the
same axis, so peer review lowers the chance of a blind spot without removing
it: the blind spot can belong to the shape of the problem rather than to the
person looking.

Hence: **write the rule at the scope of the test.** If you tested that a command
isolates one path, write that — not "this is the defence".
