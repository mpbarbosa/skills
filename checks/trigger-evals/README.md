# Trigger evals for the three session skills

`measured-claims.sh` asserts what the skills *say*. Nothing in it asks whether a
skill **triggers** on the right request. That is a different question and it
needs a different instrument.

These three files are one query set labelled three ways. Each of the 14 queries
has at most one correct owner, and `should_trigger` is set per skill — so running
all three and comparing is what measures *discrimination*, not just recall. The
three descriptions overlap by design: all of them say "close", and
`session-dropped` and `session-teardown` share "drop", "kill" and "teardown".
Whether that overlap costs anything is exactly what is unknown.

The negatives are deliberately near-misses rather than obvious misses — a
`close` that is a modal, a `kill` that is a stuck dev server, a "did it actually
work" that belongs to `verify-deploy-landed`. A negative that shares no
vocabulary tests nothing.

## Running them

With `skill-creator` available and an authenticated `claude`:

```sh
cd <skill-creator>
for s in session-pending session-teardown session-dropped; do
  python3 -m scripts.run_eval \
    --eval-set <this-dir>/$s.json \
    --skill-path <repo>/$s \
    --model <the model you actually use> \
    --runs-per-query 3
done
```

## These have never produced a measurement

Stated plainly because an unexercised artifact that looks exercised is worse
than none. Every run here returned `trigger_rate 0.0` for every query —
including a control that quoted a skill's own opening line verbatim. The cause
was not the descriptions: `claude -p` was failing with

    Failed to authenticate: OAuth session expired and could not be refreshed

and the harness does not check its subprocess's exit status, so a run that never
happened is indistinguishable from a description that never fires. The measured
shape of that is now in
[`mutation-test-guards`](../../mutation-test-guards/).

**Re-measured 2026-10-14, and the diagnosis above was wrong in the part that
decides the fix.** Auth is still expired, so the measurement still cannot be
taken — but the failure does not behave as described:

    claude -p 'Reply with exactly: AUTHOK'   -> exit 1
      stdout: Failed to authenticate: OAuth session expired and could not be refreshed
      stderr: Warning: no stdin data received in 3s, proceeding without it.

Three corrections. The auth failure goes to **stdout**, not `stderr`, so
"discards `stderr`" was never what hid it — the harness read the failure text as
the model's answer, found no skill invocation in it, and scored `0.0`. The exit
status **is** `1`, so checking it is a sufficient and cheap guard, rather than
the subtle problem the paragraph implied. And `stderr` carried an unrelated
warning: `claude -p` waits on stdin for 3s, so run it with `< /dev/null` or each
query pays that delay. Measured over 14 queries x 3 runs that is a little over
two minutes of pure waiting: the same call took **3s** with `< /dev/null` and
**6s** without.

Not asserted in `measured-claims.sh`, deliberately: it is a measurement of this
machine's expired credentials and would invert the day someone logs in.

**So before trusting any number out of this, run a control that must trigger.**
If the control reports zero, the harness is what you have measured. The result
to want from these files is not a score but a comparison: a query that triggers
two of the three skills is the finding.
