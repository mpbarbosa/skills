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

and the harness discards its subprocess's `stderr` and does not check its exit
status, so a run that never happened is indistinguishable from a description
that never fires. The measured shape of that is now in
[`mutation-test-guards`](../../mutation-test-guards/).

**So before trusting any number out of this, run a control that must trigger.**
If the control reports zero, the harness is what you have measured. The result
to want from these files is not a score but a comparison: a query that triggers
two of the three skills is the finding.
