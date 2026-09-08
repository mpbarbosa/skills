---
name: verify-workflow-shell
description: Exercise the shell inside a CI workflow before merging it, by extracting the step's own `run:` block and driving every branch against stubs. Use whenever a change touches .github/workflows (or an equivalent CI definition) — a deploy step, a guard, a scheduled job, a release gate — or whenever someone says a workflow "should" behave some way, asks whether CI will do the right thing, or is about to merge a workflow change on the strength of a green tick. Especially where the job cannot run on a pull request at all (deploy jobs, schedules, manual dispatch), because there a green PR proves nothing about the code being changed.
---

# Verifying workflow shell before it can hurt you

Workflow steps are shell programs with production consequences and **no test
suite**. Worse, the ones that matter most are usually the ones CI cannot
exercise: a `deploy` job gated on `refs/heads/main` is skipped on every pull
request, a `schedule` never fires from a branch, and steps gated to
deploy-capable runs are skipped precisely where you would want to see them.

So a green pull request on a workflow change frequently means *"the parts that
did not change still pass"*. The fix is not to reason harder. It is to run the
shell.

## The technique

**Extract the shipped text, never a retyped copy.** Retyping is how the tested
script and the shipped script drift apart.

```bash
python3 - <<'PY'
import yaml, io
d = yaml.safe_load(io.open('.github/workflows/ci.yml', encoding='utf-8'))
step = [x for x in d['jobs']['deploy']['steps']
        if x.get('name','').startswith('Refuse a release')][0]
io.open('/tmp/step.sh','w',encoding='utf-8').write("#!/bin/bash\n" + step['run'])
PY
```

Adjust the file, job and step selector to the workflow at hand; the point is that
the bytes under test come out of the committed YAML.

**Stub what the step reaches for**, and nothing else:

- **HTTP** — a tiny `http.server` on localhost, with the step's base-URL variable
  pointed at it. This exercises the real `curl` and the real `jq`, not a mock of
  them.
- **CLIs that act (`gh`, `aws`, `kubectl`, `systemctl`)** — a script on `PATH`
  that logs its arguments and echoes a canned answer keyed by an environment
  variable. Logging the invocation is what lets you assert *that the dangerous
  thing did not happen*.
- **git** — do not stub it. Use real commits from the repository, and
  `git commit-tree` to manufacture a divergent history when you need one.

**Assert the effect, not the exit code.** For a step that decides whether to act,
the question is whether it acted:

```bash
got=no; grep -q "workflow run ci.yml" "$GH_LOG" && got=yes
```

**Drive every branch, and name the ones you expect to hold.** A table of
`name → expected` beats a happy-path check, because the value is in the refusals.

## What this actually catches

Every item below was found this way, in shell that had already been reviewed and
would otherwise have shipped:

- **`git merge-base --is-ancestor X X` is true.** A guard refusing to deploy an
  ancestor of what is live also refuses to redeploy the *current* commit, unless
  equality is short-circuited first.
- **`inputs` is empty on a `push`.** An override read as `${{ inputs.foo }}`
  evaluates to nothing on exactly the event that matters;
  `${{ github.event.inputs.foo }}` works on both.
- **Two workflows can fight.** A reconciler that deploys the default branch when
  production is behind it will undo a deliberate rollback within one tick,
  because a rollback and a dropped push event look identical from the outside.
- **A retry loop with no memory.** A job that re-dispatches on a gap will
  re-dispatch forever if the fix itself is what is failing.

## Rules worth keeping

- **A green pull request is evidence about the jobs that ran.** Before trusting
  it, check the job list for `skipped`. That is where the change you are shipping
  usually lives.
- **Prefer failing open or safe deliberately, and say which.** A guard on a
  release a person asked for should fail *open* — in an outage, deploying beats
  ordering. A job that starts a release nobody asked for should fail *safe*.
  Write the reason at the call site; the two look identical six months later.
- **Statelessness beats a flag.** A condition derived from run history clears
  itself; a flag or a disabled workflow is something a person must remember to
  undo, and forgetting is silent.
- **Where a step cannot be exercised even in principle, say so plainly** rather
  than letting a green tick imply coverage it does not have — then name the
  observable that *will* prove it on the next real run, and go and read it.

## After it merges

Verification is not finished at the merge. Read the run: quote the line that
proves the branch you intended was taken (`OK: <sha> is 5 commit(s) ahead of
live <sha>`), and for a fix whose evidence is an **absence** — a deprecation
warning that should no longer appear — check the log rather than the conclusion,
because a green tick cannot distinguish *fixed* from *still warning*.
