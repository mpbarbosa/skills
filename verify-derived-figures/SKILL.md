---
name: verify-derived-figures
description: Establish that a figure computed from two sources which refresh independently — a rate, average, percentage, per-unit or coverage number — is sound, when a lag in one of them corrupts every value by a margin small enough to look like data. Use when dividing one feed's counters by another's totals, when building or reviewing a gate on a sync or an ETL step, when numbers look slightly off but plausible, when deciding whether a reconciliation band is evidence, when a count of missing records is about to be reported as a count of zeros, or when choosing the date window for a pull.
---

# Verifying a figure derived from two sources

The shape: one source supplies the numerator — events, counters, incidents — and
another supplies the denominator — the periods, units or fixtures those events
are divided by. They are refreshed by separate jobs on separate schedules.

When they are at **different vintages**, every value you publish is wrong, and
this is the failure mode worth the whole skill:

> **Nothing about the output looks wrong.** The values sit in their usual range,
> the ranking is the ranking you expect, and no row stands out. There is no
> error, no warning and no outlier to notice.

So the output cannot be the check. The vintages have to be.

## 1. A denominator one period stale inflates everything by about 1/N

Rebuilt here: 20 units with persistent strength plus noise, counters summed
through period 25, denominator still bounded at 24.

    inflation across the 20       3.2% .. 4.8%
    mean inflation                4.1%          (1/N, for N=24, is 4.2%)
    correct range                 7.96 .. 18.67
    inflated range                8.29 .. 19.50

**The error is approximately `1/N`**, because you have added one period's worth
of numerator to a denominator that still counts N. That is the whole reason it
hides: 4% over 24 periods, 1% over 100, 0.3% over a year of days. **The longer
your series, the better the fault conceals itself** — and the more confident
everyone is in the number, because it has been stable for months.

> **Recorded observation, from the project this came from.** The same fault on
> real data inflated every club's figure **4.3–4.5%, mean 4.4%** — found by
> reproducing it one round early against data already on disk. The arithmetic
> above is what is re-asserted; that figure is theirs.

## 2. Why every sanity check you would reach for passes

From the same rebuild:

    rank positions changed        2 of 20
    top 5 identical               yes
    every value inside the healthy spread   yes

A spot-check on the leaders passes. An eyeball on the range passes. An outlier
test finds no outlier, because **the fault is multiplicative and nearly uniform**
— it moves everything by the same ~1/N, so it does not disturb the shape of the
distribution, only its scale. Checks that look for *strange* values are blind by
construction to a fault that makes every value proportionally wrong.

## 3. Gate on the vintages, not on the values

Both sources have to state the period they are complete through, and the gate
compares those two labels before anything is divided:

```sh
# refuse when the numerator reaches past the denominator
[ "$numerator_through" -le "$denominator_through" ] || {
  echo "numerator through $numerator_through, denominator through $denominator_through" >&2
  exit 2
}
```

Write the two labels into the generated output as well, so the next person can
read the vintages off the artefact instead of re-deriving them.

**The gate is asymmetric, and that asymmetry is the point.** Verified against
the same model:

    numerator 24, denominator 24   -> ok
    numerator 25, denominator 24   -> REFUSE
    numerator 23, denominator 24   -> ok

A numerator *behind* the denominator is not a fault. It is the feed not having
recorded something yet, and the figures are correctly reporting that — the
denominator is right and the rate is honestly low. Only a numerator reaching
past the denominator is corruption. Refusing both directions makes the gate fire
constantly during normal operation, and a gate that cries wolf gets removed.

> Recorded: this gate fired for real with the feed at round 25 against a
> snapshot at 24, named both rounds, and wrote nothing.

## 4. A guard that reads better as the fault worsens is not a guard

The most dangerous thing in this document. There is usually an adjacent
reconciliation check already in place — a band, a tolerance, a totals
comparison — and it is tempting to treat it as covering this fault too.

Verified, with a shortfall band of `-2% .. 15%` over a snapshot of 600 against
a feed that under-records by 10%:

    healthy: feed at period 24    shortfall  10.0%   inside the band
    FAULT:   feed at period 25    shortfall   5.8%   inside the band

The fault moved the figure **4.2 points further inside its band.** The feed's
total rose while the snapshot's did not, so the gap it measures narrowed — the
check reads *more comfortably* exactly as the thing it is offered to catch gets
worse.

> **A number that moves in the flattering direction as a fault grows is not a
> gate against that fault.** It is an indicator pointing the wrong way, and it
> will be cited as reassurance.

Before trusting any existing check as cover, work out which way it moves under
the fault. If it improves, it is worse than nothing. This is
[`mutation-test-guards`](../mutation-test-guards/) applied to a number rather
than a test: break the thing deliberately and watch which way the needle goes.

## 5. Two gates, one from each side

One gate is a single point of failure in the thing whose whole problem is that
it is invisible. Put a second one where the figure is *consumed*, not where it is
produced:

| Gate | Sits at | Fires when |
|---|---|---|
| vintage comparison | the sync, before writing | the numerator reaches past the denominator |
| coverage denominator | the computation | the units divided by exceed the units the snapshot knows |

They catch the same fault from opposite sides, so a change that defeats one
rarely defeats the other. Neither is decorative: both have fired.

## 6. Absent is not zero

A record missing from the output means *not yet synced, or did not reconcile*.
It does not mean the quantity was zero. These are routinely conflated, and the
conflation runs both ways:

- If a genuine zero is **stored** as an empty record, it is indistinguishable
  from an unsynced one, and your coverage number is wrong.
- If a genuine zero is **omitted**, as it often is to keep that distinction,
  then the count of absent records is *not* the count of gaps — you must
  subtract the real zeros before calling it one.

Decide which convention you are in, write it down beside the data, and never
report a count of missing records as a count of failures without saying which.

This is the same discipline as recording the zero that means a probe never ran:
a zero with two possible meanings needs a third state, not a comment.

## 7. The publish lag is a distribution, not a time

Vintages diverge because the upstream publishes when it publishes. Treat the
date you expect data as a **floor, not an appointment**.

> Recorded: the lag from a period's last event to the publish that first carried
> it was **1.6–1.7 days on five of six periods** — so the script adds two days
> and the instruction is to poll daily from that date rather than once on it.

A single check on the nominal day is the worst of both: too early most times,
and when it is early you either get nothing or — if a gate is missing — you get
the fault in section 1.

Give the poller **exit codes as a contract**, so a caller can act without
parsing prose:

    0   nothing due, or the run succeeded
    1   a sync is due
    2   something a person must look at

Reserve a distinct status for *needs a human*. Folding it into the generic
failure code is how a credential problem gets retried for a week.

## 8. A window derived from your own timestamps will miss rows

When you pull a range from a source you do not control, its index may be keyed
in a different timezone from your records.

> Recorded: the upstream listing is keyed by **local** date while the stored
> timestamps are UTC, so a `00:30Z` fixture is filed under the previous day. A
> window aimed exactly at the derived dates silently misses it.

Two rules follow, and the second licenses the first:

1. **Widen the window by one period on each side** of whatever your own data
   implies.
2. **Make the write a merge, never a replace.** Then a wide window costs only
   time, and widening is free. If the write replaces, widening is dangerous and
   you are stuck choosing between two bad options — so fix the write first.

## 9. Partial success is the interesting exit, not a reason to re-run

A run that writes its output *and* exits non-zero is reporting that some records
did not reconcile. The output is trustworthy; the report says what is missing.

Re-running blindly repeats whatever did not work. Read which records failed and
why, because the causes need different actions — a missing identifier mapping, a
rule change, or an upstream that has not published a consistent version yet.

Related, and worth copying: where a record is assembled from two upstream views
that disagree, **refuse the whole record rather than storing a partial one**. A
partially-populated record is indistinguishable from a complete one later, which
puts you back in section 6.

## 10. Throttling may not announce itself

> Recorded: the upstream throttles **at the socket** — no `429`, no
> `Retry-After`. A run that goes too fast makes plain `curl` fail for minutes
> afterwards, which is indistinguishable from the host being down.

So a deliberate sleep between requests is load-bearing, and "optimising" it away
produces an outage you will diagnose as someone else's. If you must know whether
the host is really down, wait out the penalty and probe once — a failing request
during a throttle is not evidence about the host.
