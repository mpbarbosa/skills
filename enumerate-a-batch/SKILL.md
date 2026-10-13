---
name: enumerate-a-batch
description: Establish that the batch you are about to process is the batch you were asked about, when the items come from a source that is re-queried rather than handed over as a fixed list — a search URL, an alert digest, a notification feed, "the next 50". Use when turning a digest, alert, feed or search link into a list of ids, when paging through results to build a work queue, before spending money or API calls on a batch, when a batch came back the right size but the wrong contents, or when reporting how often an automated pass agreed with a human.
---

# Enumerating a batch from a source that is re-queried

You are handed something that looks like a list — an alert e-mail, a digest, a
search URL, a feed, "do the next 50" — and the first job is to turn it into
ids. The obvious method is to replay the query and page through the results.

That method produces a batch of **exactly the size you asked for, whose
contents are not the set you were asked about**, and nothing in the output says
so. The count is right, so nothing looks wrong. Every claim below was rebuilt
against a fixture server on loopback; the numbers are that fixture's.

## 1. Replaying the query does not reproduce the list

A digest arrives with a link to the search that supposedly produced it. The
link is not a closed list — it is a *query*, and the set it returns now is not
the set that generated the message.

Verified on loopback, with three ids handed over and a search of 60 positions
replayed in full:

    handed ids                                     3
    present in the replayed search                 2    <- the control
    absent from ALL 60 positions of the search     1

The control is the load-bearing half. A probe that cannot find the two ids that
*are* there proves nothing by failing to find the third — so always report both
numbers, never just the misses.

> **Recorded observation, from the source this came from.** Processing a
> real alert: one id appeared in the message's own parameters and in **none of
> the 200 positions** the linked search returns — and it was the **only**
> candidate in a batch of 51. Hit rate **1 of 6** on the ids the message
> carried, against **1 of 50** on the window taken from the search.
>
> Not re-asserted here: that number belongs to one host's API on one day. What
> is asserted above is the mechanism — that a handed id can be absent from the
> whole of the query said to have produced it.

So: **the ids the message carried are members of the batch in their own
right.** Pass the whole reference through without pruning its parameters, add
every carried id the query's window did not return, and label each one with
which of three states it is in, because they support different conclusions:

| State | What you may say |
|---|---|
| In the query, outside the window you took | "at position N, beyond the window" |
| Not in the window | "absent from the window; may lie further along" |
| Not in a **complete** enumeration of the query | "absent from the query" — only from a full snapshot |

The third sentence is the only one that is a finding, and it is unsayable
without a complete snapshot. Do not write it from a partial window.

## 2. Two live windows are not a partition

"Now the next 50" invites a second request with a later offset. If the source
re-ranks between calls — any relevance-ordered search does — consecutive
windows neither tile nor stay disjoint.

Verified on loopback. The same fixture, asked for positions 1–20 and then
21–40, against one snapshot of positions 1–40:

    two live windows:  union 40    duplicated 0     <- looks perfect
      of those 40, absent from the intended range   10
      of the intended range, returned by neither    10

    one snapshot of 40, sliced locally into 20 + 20:
      union 40   duplicated 0   covering exactly the 40

    control, the same paging code over a stable ordering:
      union 40   duplicated 0   covering exactly the 40

Read the first block again: **union 40, zero duplicates.** Every integrity
check you would naturally run on a work queue passes. A quarter of it is
material you were not asked about, and a quarter of what you were asked about
is missing. The control establishes that the defect is the re-ranking and not
the paging code, which is the thing you would otherwise go and debug.

So **snapshot once, slice locally**:

```sh
# Sketch — substitute your own fetch and your own id extraction. Take a window
# larger than you intend to work, ONCE, and name it for the day and the range.
snap=2026-10-13_alert_1-200
curl -s "$base/search?start=1&count=200" > "$snap.json"
jq -r '.ids[]'                           < "$snap.json" > "$snap.ids"

# Every later batch is a slice of that file, never a second request.
sed -n  '1,50p'  "$snap.ids" > batch_1-50.ids
sed -n '51,100p' "$snap.ids" > batch_51-100.ids
```

Name the snapshot with the date and the range it covers, and take later batches
from the file. The moment a second batch comes from a second request, the two
batches have an unknown relationship to each other.

## 3. Ask whether "new" means new

A feed titled *new since you last looked* may be the whole board re-sent. Two
cheap tests before spending anything:

- Query the source with **no filter**. If it returns the same items, the feed is
  a board, not a delta.
- Check the oldest item's own timestamp against the period claimed. One such
  feed, titled as recent postings, carried items five weeks old.

If it is a board, diff against the previous batch and process only what is new.
Otherwise every run pays for the whole board again, and the second run's
"results" are the first run's.

## 4. A sentinel-value probe only exercises the first stage

Before spending, you check that the pipeline is up by posting a cheap
placeholder — `{"id": "0"}`, an empty string, a zero. What comes back is a
rejection, which you read as *reached it, so it works*.

Verified on loopback, against a pipeline whose **second** stage is broken:

    POST /run   {"id":"0"}          -> 500   rejected by stage 1 (id length)
    POST /run   {"id":"40000021"}   -> 500   a REAL id: stage 2 is broken
    POST /gone  {"id":"0"}          -> 404   route absent: nothing is deployed

The sentinel and the broken pipeline return the **same status**. "500 is what an
invalid id should give, so the flow is healthy" is a sentence that stays true
while every real request fails — because the placeholder was thrown out by the
validator in front of the part that is broken.

`404` does carry information: it separates *not deployed* from *deployed and
refusing*, and a 404 means nothing was spent. But to learn that the pipeline
works, **probe with one real item** and look at the body, not the status.

A uniform failure across every id, valid ones included, is a broken stage
rather than a batch of absent items. A single failure on one id among many that
succeed is usually transient: retry that id by hand before recording it as a
property of the item.

## 5. Do not inflate the agreement number

The reason to run a batch at all is usually to find out how often the automated
pass agrees with a human. That number is easy to overstate by one move, and
once overstated it is what everyone quotes.

| What you did | What it measures |
|---|---|
| Compared the verdict against a human verdict recorded **before** the run | agreement — countable, independent |
| Read the pass's own reasoning and found it convincing | **not** agreement — you checked the argument, not the answer |

The second is worth doing and worth reporting; it is not the same series as the
first and must not be added to it. Report it in its own words — *"n items
reviewed by reasoning, no disagreement found"* — and keep the agreement count
to items that had a verdict the pass could not see.

Two corollaries:

- A disagreement is a finding about **one of two things**, and you have to say
  which: the automated pass, or the record it was compared against. The record
  being wrong is a real and common outcome.
- An item the pass declines to decide, and hands back for a human, is not a
  decision. Count and list those separately rather than folding them into
  either column.

## 6. Say the cost before you spend it

A batch has a per-item cost in money and in wall-clock. Multiply before running,
and state it when the total is material rather than after the fact. Two things
that move the per-item figure, both measured on the source this came from:

- **Items that terminate early are nearly free.** Where a class of item is
  rejected up front — already closed, already recorded, out of scope — it
  returns in under a second at no cost, and an average over the whole batch
  understates what the rest costs. Quote the cost per *processed* item and the
  count of the rest separately.
- **Concurrency can multiply a fixed startup cost.** Where a run has a
  first-call setup that later calls reuse — a warmed cache, a compiled plan, a
  negotiated session — launching N workers at once pays for it N times. Send the
  first item alone, then open the parallelism.

Make the runner skip items that already have a result on disk. Then a crash
costs only the remainder, and a retry after a transient failure does only what
is missing.
