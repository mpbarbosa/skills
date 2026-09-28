---
name: verify-deploy-landed
description: >
  Confirm a deploy actually reached the running service, by querying the live
  system from outside rather than trusting the pipeline's exit code. Use after
  any deploy, release or publish step, whenever someone asks whether a change is
  live, when a deploy "succeeded" but the behaviour has not changed, or before
  telling anyone that something shipped. A pipeline reports the step it ran; only
  the live service reports what is serving.
---

# Did the deploy actually land?

A deploy pipeline tells you it finished. That is a claim about the commands it
ran, not about what is being served — and the gap between those is where
"deployed" becomes false without anything going red.

**Publish is not rollout.** A typical path has four stages that can each succeed
while the next never happens:

    build  ->  publish artifact  ->  roll out  ->  serve

A green pipeline usually proves the first two. The third is frequently
conditional, and the fourth involves a cache you do not control.

## The three silent no-ops

Each of these exits 0, prints success, and changes nothing.

**1. The stage that skips when it is not on the right host.** Deploy scripts
commonly detect whether they are running somewhere that has a live installation
and skip the rollout when they are not — correctly, since a dev box has nothing
to restart. The script then prints its completion banner anyway. Run from a
laptop, the whole pipeline is a publish, and reads as a deploy:

    ✓ Deployment complete.
    No live production install detected on this host. Skipping app-directory sync.

Those two lines have appeared in that order, and the second is the true one.

**2. The version guard that finds nothing to do.** Rollouts are often guarded on
the artifact version being strictly greater than what is live, so that re-running
does not restart a healthy service. The consequence: **forget the version bump
and the deploy becomes a no-op with a success message.** The guard is working as
designed; the release is simply not in it.

    Production already current — nothing to roll out.     # exit 0

**3. The cache in front of the origin.** The rollout succeeded, the origin serves
the new build, and a CDN, reverse proxy or service worker keeps handing the old
one to everybody who is not you. Verifying through the same edge that is caching
is how this survives a check.

## Verify from outside, against the running service

Nothing in the repository, the pipeline log, or the artifact directory can
answer this. Ask the thing that is serving:

```sh
curl -fsS --max-time 10 "$BASE/api/health" |
  python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('version'), d.get('status'))"
```

**A health endpoint returning `ok` is about the process, not the payload.** It
usually means "a server is up and answering" — which the *old* build also does,
perfectly, forever. `status: ok` is a precondition for success, never evidence of
it.

## Check the version *and* the content

Neither alone is sufficient, and they fail in opposite directions.

**Version alone** can be right while the content is wrong — a partial rollout, a
build that embedded the version but not the data, an asset bundle served from
cache while the server process restarted.

**Content alone** can be right by accident, if what you grepped for was already
there.

So do both, and make the content probe mean something:

```sh
# 1. the version now serving matches what you shipped
# 2. a string that is NEW in this release is present
curl -fsS "$BASE/<a real path this release changes>" | grep -c '<the new string>'
```

**Confirm the probe string was absent before you deployed**, or a match proves
nothing. The cheapest way is to capture it *before* the rollout — one request,
one line, and the check afterwards becomes a comparison instead of an assertion:

```sh
before=$(curl -fsS "$BASE/<path>" | grep -c '<the new string>')   # expect 0
# ...deploy...
after=$(curl -fsS "$BASE/<path>" | grep -c '<the new string>')    # expect >0
```

If you did not capture it before, say that your content check is weaker for it
rather than reporting it as though you had.

**Pick a probe that this release genuinely introduces** and that is reachable on
the path you are testing. A string can be absent from a response for reasons that
have nothing to do with the deploy — a record with no data behind it, a feature
behind a flag, a route that renders it only under conditions you are not meeting.
Choose a case you know renders it, or you will chase a rollout that already
happened.

**Establish that the probe is observable before you rely on it.** Some things a
release changes are simply not visible from outside: a version that lives in a
manifest and is never embedded in served output cannot be read off a page, no
matter how the deploy went. Confirm the probe appears in the *current* response
before the rollout — the before/after capture above does this for content, and
it does it for the version too. A probe that was never observable produces the
same "absent" as a deploy that never landed, and they are not the same finding.

**Ask for exact substring presence, not for an interpretation.** If a tool or an
agent is doing the fetching, the question is "does this byte sequence appear,
yes or no", never "is the new version live". The second invites a judgment, and
a judgment about a deploy is the thing you came here to replace.

**A fetch path that transforms the payload can hide a present marker.** Anything
that converts HTML before you search it — a markdown-converting fetch tool, a
reader mode, a scraper — drops attributes: form `action`, `data-*`, and similar.
The marker is in the response and absent from what you searched, so the probe
reports a failed deploy that succeeded. Three consequences:

- **Prefer assets served as plain text** — CSS, JS, JSON, a text endpoint. They
  survive the round trip intact, so a probe against them means what it says.
- **Use a raw fetch** (`curl`) rather than a converting one when you can.
- **An absent marker whose visible side-effect is present is ambiguous, and the
  ambiguity is the finding.** If the `data-fs-success` attribute is missing but
  the success message it drives renders, you have learned about your fetcher,
  not about the deploy. Say so rather than picking a side.

**Defeat the cache deliberately.** Verify against the origin where you can, and
otherwise bypass the edge rather than hoping:

```sh
curl -fsS -H 'Cache-Control: no-cache' "$BASE/<path>" -o /dev/null -D - | grep -iE '^(age|x-cache|cf-cache-status|etag):'
```

An `age:` header above zero on the response you are calling proof means you are
reading the cache, not the deploy.

## Wait, then re-read — but bound it

A restart is not instantaneous, and querying into the gap gives you the old
version, the new one, or a connection error depending on timing. Poll to a
deadline instead of sleeping once and concluding:

```sh
for i in $(seq 1 20); do
  v=$(curl -fsS --max-time 5 "$BASE/api/health" 2>/dev/null |
      python3 -c "import sys,json;print(json.load(sys.stdin).get('version',''))" 2>/dev/null)
  [ "$v" = "$EXPECTED" ] && { echo "live at $v after ${i}0s"; break; }
  sleep 10
done
[ "$v" = "$EXPECTED" ] || echo "TIMED OUT — live is $v, expected $EXPECTED"
```

A timeout is a real finding, not a reason to check once more and call it done.

## Build where you can afford to

Where the pipeline splits publish from rollout, that split is usually deliberate:
build on a machine with the memory for it, ship the artifact, and have the target
consume a prebuilt payload. **Do not "simplify" by building on the target.** A
small production host with no swap does not fail the build cleanly — it OOMs
partway, and what it takes down with it is the service that was running fine.

## Report what you verified, and from where

```
LIVE — 2.4.1 serving, content confirmed.

  version    /api/health reports 2.4.1 (was 2.4.0), status ok
  content    "quarterly summary" present on /reports (0 occurrences before, 3 after)
  cache      checked with no-cache; x-cache MISS
```

```
NOT LIVE — the pipeline published, but nothing rolled out.

  pipeline   exit 0, "✓ Deployment complete."
  but        "No live production install detected on this host"
  live       /api/health still reports 2.4.0
  cause      publish ran from a dev box; rollout happens on the target host
```

```
NOT LIVE — the version guard skipped the rollout.

  live       2.4.0; artifact 2.4.0 — not strictly greater, so the guard no-opped
  fix        bump, republish, roll out again
```

Say which host you queried and whether you went through a cache. "It's deployed"
without those is the claim this skill exists to stop being made.

## Rules

- **Never report a deploy from the pipeline's exit code.** Query the service.
- **`status: ok` is not "the new code".** The old build says `ok` too.
- **A missing bump is the most common cause of a successful no-op deploy.** Check
  the served version against the artifact version before looking anywhere else.
- **Do not reach for a force flag to paper over a skipped rollout.** A force
  redeploy at the same version is legitimate for a config change and is not a
  substitute for the bump you forgot — using it that way leaves the version
  wrong everywhere it is reported.
- **An absent probe is not automatically a failed deploy.** It is equally a probe
  that was never observable, or a fetch path that dropped it. Rule those out
  before reporting a deploy as not landed.
- **If you cannot verify from outside, say so plainly** and name what would prove
  it — then go and read that. An unverified deploy reported as done is worse than
  one reported as unverified, because only the second one gets checked.
