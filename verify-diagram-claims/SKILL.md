---
name: verify-diagram-claims
description: >
  Establish that a diagram is true of the code that actually runs — before
  drawing one, and before trusting one already in the repository. Use when
  asked what notation or diagram a project is missing, when drawing or
  reviewing a flowchart, sequence, class, ER, dataflow, topology or C4
  diagram, when a diagram is offered as evidence of how something works, or
  when choosing which notation to draw. A diagram read off the source
  describes the code that exists, not the code that is reached — and it
  renders, reviews and reads perfectly either way.
---

# Verifying what a diagram claims

A diagram is a set of assertions about a codebase, and it is the only artifact
in the repository that **nothing executes**. A test fails. A type annotation is
checked. A sentence of prose gets contradicted by the next reader. A diagram is
believed, cited in the next design discussion, and pasted into the onboarding
page.

The failure mode worth the whole skill:

> **Nothing about the diagram looks wrong.** Every node names a symbol that
> exists, every edge is a call that is really written somewhere, the Mermaid
> renders, and the reviewer recognises the picture. It is an accurate drawing of
> code that is never reached.

So the drawing cannot be the check, and neither can the prose it was drawn
from. The call graph has to be.

## 1. "It exists" is not "it is called", and importer counts get it wrong in both directions

Rebuilt here: seven modules, two entry points (`web`, `pipeline`), and a
`search` module holding a hybrid retrieval class that nothing in the product
imports.

The check everyone reaches for first — does this symbol exist? — passes:

    grep -rn --include='*.py' -E '^[[:space:]]*(class|def)[[:space:]]+HybridSearch\b' .
    ./src/search.py:7:class HybridSearch:

So does the next one, and this is where it gets expensive. Counting the modules
that import each module, inside the product tree only:

```sh
for m in bm25 search index generate guard web pipeline; do
  n=$(grep -rlE "from[[:space:]]+\.$m[[:space:]]+import" --include='*.py' src |
      grep -vx "src/$m.py" | wc -l)
  printf '%-9s %s\n' "$m" "$n"
done
```

| module | imported by *n* other product modules | reachable from an entry point |
|---|---|---|
| `bm25` | **1** | **no** |
| `search` | 0 | no |
| `index` | 2 | yes |
| `generate` | 2 | yes |
| `guard` | 2 | yes |
| `web` | **0** | **yes — it is an entry point** |
| `pipeline` | **0** | **yes — it is an entry point** |

**Two false readings, in opposite directions, in one table.** `bm25` has an
importer, so it reads as live; its only importer is the dead module. `web` and
`pipeline` have no importers at all, so they read as dead; they are the two doors
into the system. An importer count is a measure of one hop, and liveness is a
question about paths.

Ask the toolchain for reachability instead, from the entry points inward:

```sh
python3 - "$@" <<'PY'
import ast, os, sys
from collections import deque
root, pkg, entries = sys.argv[1], sys.argv[2], sys.argv[3:]
mods, edges = {}, {}
for dirpath, _, names in os.walk(os.path.join(root, pkg)):
    for n in sorted(n for n in names if n.endswith(".py")):
        p = os.path.join(dirpath, n)
        name = os.path.relpath(p, root)[:-3].replace(os.sep, ".")
        mods[name] = p
for name, p in mods.items():
    out = set()
    for node in ast.walk(ast.parse(open(p).read(), p)):
        if isinstance(node, ast.ImportFrom):
            base = name.rsplit(".", node.level)[0] if node.level else ""
            out.add((base + "." + node.module) if (node.level and node.module) else (node.module or base))
        elif isinstance(node, ast.Import):
            out.update(a.name for a in node.names)
    edges[name] = {m for m in out if m in mods}
seen, q = set(), deque(f"{pkg}.{e}" for e in entries)
while q:
    m = q.popleft()
    if m in seen or m not in mods:
        continue
    seen.add(m)
    q.extend(sorted(edges.get(m, ())))
print("modules     ", len(mods))
print("reachable   ", len(seen))
print("unreachable ", " ".join(sorted(set(mods) - seen)) or "(none)")
PY
```

Measured against the fixture, and against two controls:

    entry points: web, pipeline     7 modules, 5 reachable, unreachable: src.bm25 src.search
    pipeline made to import search  7 modules, 7 reachable, unreachable: (none)
    entry point web removed         7 modules, 4 reachable, unreachable: src.bm25 src.search src.web

The middle line is the one that licenses the probe: when the code changes to
match the drawing, the probe goes clean. The third says what the probe actually
depends on — **the entry-point list is the input you must get right.** Name the
doors deliberately: HTTP handlers, CLI entry points, scheduled jobs, test
fixtures excluded. Get them wrong and you will delete live code.

> **Recorded, from the project this came from.** The dataflow diagram in that
> repository said the pipeline *«retrieves densely and lexically, fuses by
> reciprocal rank»*. A module did exactly that, correctly, with a passing test.
> The AST import graph had **not one edge into it from any product module**, and
> its only importers were under `tests/`. The function that answers a real
> question did dense retrieval and an optional rerank, and no BM25 at all. The
> diagram was true of a file and false of the system — and it had been read,
> twice, by people who knew the code.

## 2. A picture not worth drawing can still be an extraction worth running

In that same repository a class diagram had been assessed and **rejected** —
42 classes, nearly all frozen dataclasses, two inheritance edges in the whole
tree, so the picture would be a list of records with no structure in it. The
assessment was right about the picture.

It was drawn anyway, by importing every module and asking `inspect`,
`dataclasses.fields` and `__bases__` rather than by reading the source. That
extraction is what found the dead retrieval module in section 1.

**Separate the two judgments.** "Would this diagram be worth looking at?" and
"would running the extraction tell us something we do not know?" have different
answers, and the second one is cheap. Run the extraction; then decide whether
the picture is worth keeping.

## 3. Resolve the nodes of the drawing, not the files of the repository

A clean repository-wide reachability report does not clear a *particular*
diagram. Go the other way: take the drawing apart and resolve each node.

```sh
# every bracketed node label of a mermaid flowchart
sed -n '/^```mermaid/,/^```/p' docs/diagrams.md |
  grep -o '\[[^]]*\]' | sed 's/^\[//; s/\]$//' | sort -u
```

Seven labels come out of the fixture's diagram. Now resolve each one — and
resolve it **through its qualifier**, because the obvious shortcut of taking the
trailing identifier is wrong here in a way worth seeing:

```sh
resolve() {   # label -> the file defining its qualifier, else its trailing name
  label=$1; pre=${label%%.*}; id=${label##*.}
  if [ "$pre" != "$label" ] && [ -f "src/$pre.py" ]; then echo "src/$pre.py"; return; fi
  if [ "$pre" != "$label" ]; then
    f=$(grep -rlE "^[[:space:]]*class[[:space:]]+$pre\b" --include='*.py' src | sort | head -1)
    [ -n "$f" ] && { echo "$f"; return; }
  fi
  grep -rlE "^[[:space:]]*(class|def)[[:space:]]+$id\b" --include='*.py' src | sort | head -1
}
```

    answer             src/pipeline.py
    bm25.score         src/bm25.py        <- unreachable module
    copied             src/guard.py
    DenseIndex.search  src/index.py
    generate           src/generate.py
    question           (nothing in src defines it)
    rrf                src/search.py      <- unreachable module

**Two of seven nodes sit in modules no entry point reaches**, and they are
exactly the two that make up the half of the picture that is a fiction. One
label resolves to nothing because it is an input, not code — expected noise, and
the reason this is a list to read rather than a gate to fail a build on.

**The shortcut that was tempting, and what it cost.** Resolving `${label##*.}`
alone — the trailing identifier — and taking the first match printed:

    DenseIndex.search  search     src/search.py      <- WRONG, and condemns a live node

Two modules define a `search`, the qualifier that distinguishes them was thrown
away, and `head -1` without `sort` picked by directory order. That row flags a
node that is live, so the probe accuses the diagram of the one thing it got
right while the two real findings sit in the same list, indistinguishable. Keep
the qualifier, sort before `head`, and resolve through the language's own AST
wherever there is one.

The same move catches the drawn-but-absent subsystem. An `erDiagram` names
entities; ask what would have to be imported for them to be persisted at all:

    grep -rl --include='*.py' -E 'sqlite3|psycopg|sqlalchemy|pymongo' src | wc -l
    0

> **Recorded.** The one entity-level diagram in that repository described five
> tables in a database file that **does not exist** — nothing under `src/`
> imported a driver for it, and the feature was unbuilt. It was also the only
> diagram anyone could point to when asked what the project's data model was.
> An unbuilt subsystem is the easiest thing in a codebase to draw, because
> nothing contradicts you.

## 4. Choose the notation by its primitive, before drawing anything

The sharpest diagram failure is not an edge that is wrong. It is a notation
whose primitive cannot carry the claim — so every edge is correct and the thing
the reader takes away is false. Redrawing it more carefully cannot fix it.

| If the claim is about | the primitive you need | so the notation is |
|---|---|---|
| what depends on what | data dependency | dataflow / pipeline graph |
| what happens before what, and what has already left | **ordering** | sequence diagram, with lifelines |
| where something sits, and what it can reach from there | placement, adjacency | deployment / topology / C4 container |
| what may cross which line | a boundary | DFD with trust boundaries |
| which combination produces which outcome | conditions | decision table |
| what the thing can be, and what moves it | states and transitions | statechart |
| what records exist and how they relate | entities | ER / class diagram |

Write the claim down as a sentence first, then pick the row. If no row fits the
sentence, you have found something worth more than the diagram.

> **Recorded.** A dataflow graph showed `generate → check → emit`. That was true
> of one call path and false of the other: the service streams, so on the wire
> the fragments of a *rejected* attempt had already left the process before the
> check could reject them — measured, six of eight verses. A dataflow graph's
> edges are data dependencies and it has no lifelines, so it **structurally
> cannot** express "has already left". The fix was a sequence diagram, and the
> bug had been described three times in three prose files before anyone drew it.

A cheap mechanical tell for that case — the step the diagram starts from is
reached by more paths than the diagram knows:

    grep -rl --include='*.py' -w generate src | grep -vx src/generate.py
    src/pipeline.py
    src/web.py

**Two callers, one picture.** Whenever that count is greater than one, say in
the document which path you drew, or draw the other one.

## 5. Drawing is a probe. A drawing that found nothing is a drawing to distrust

If extracting a diagram from a codebase turns up no surprise at all, the usual
explanation is not that the codebase is tidy — it is that you drew the
documentation rather than the code.

> **Recorded.** Of six diagrams drawn into one repository in a day, **two found
> a defect while being drawn.** A decision table found a manifest shape where
> two implementations of the same five checks disagree, which the parity test
> that licensed the duplication did not parametrise — and it fails in the
> optimistic direction, reporting a healthy index that is about to cost the user
> the longest wait in the system. An egress diagram found a door already open.
> Neither was found by reasoning about the code; both came out of filling in a
> cell and not being able to.

When drawing does produce a finding, **measure it before you change anything**,
and keep the order visible in the document: the divergence above was probed on
the branch that drew the table, and fixed in the commit after it. A finding
recorded after the fix is indistinguishable from a finding invented to justify
the fix.

## 6. Every claim in the diagram cites what holds it

Give each diagram document a section that maps its assertions to the thing that
would break if they stopped being true — a test name, a file and symbol, a
command and its output. Two sentences of table beats a page of prose:

| Claim | Held by |
|---|---|
| no route returns a body in an approved answer | `test_no_route_returns_body` |
| the rejected attempt still reaches the wire | `test_rejected_attempt_still_ships` |
| the sweep covers every route the app registers | `test_sweep_covers_all_routes` |

Then apply [`mutation-test-guards`](../mutation-test-guards/) to the row, not
only to the code: **the instrument behind a diagram can be the defect.**

> **Recorded.** The sweep that enforced the control drawn in one of those
> diagrams split the wire on newlines and compared whole lines — correct for a
> file, wrong for NDJSON, where a line break inside a JSON string is two
> characters. **With the control switched off in the application, all eight
> assertions stayed green.** The diagram was only ever as good as the sweep, and
> finding the sweep wrong took deliberately breaking the thing it watched.

So a diagram that rests on a test is resting on an assumption until someone has
watched that test go red.

## 7. Say what you deliberately did not draw

End the assessment with the candidates you rejected and the reason for each —
"42 frozen dataclasses, no structure to show", "the serializer *is* that map and
has a test that fails when a field is added", "one user, one machine, the box
would contain the whole repository".

An undocumented skip gets relitigated every time someone new looks at the
repository, and the second person to propose a C4 context diagram has no way to
know the first one was talked out of it.

## 8. An assessment of what is missing expires the day someone acts on it

A document arguing that three notations are missing stops being true as soon as
they are drawn — often hours later, by the person who read it.

Do not edit the claim away. **Record the expiry inside the document**, with a
table of what was drawn and where, and leave the reasoning standing: the
argument for *how* each one got drawn is the part worth keeping, and deleting
the claim hides that the gap was ever there. A title that says *is missing*
over a note that says *all three are now drawn, here* is honest. A quietly
updated title is a document nobody can date.

## 9. Make the artifact self-identifying

A diagram travels. It gets pasted into a ticket, a chat, a slide, a review
comment — and arrives with no repository, no path and no idea what it is of.
Put the identification *inside* the drawing, as a box in the diagram or a
bordered block at the head of the file, carrying four things:

    ┌──────────────────────────────┐
    │ Name        retrieval-path   │
    │ Type        flowchart        │
    │ Project     demo             │
    │ Description what runs        │
    └──────────────────────────────┘

Which is grep-able, so it can be checked:

```sh
for f in docs/*.md; do
  miss=''
  for k in Name Type Project Description; do
    grep -qE "^.?.? *$k[[:space:]]" "$f" || miss="$miss $k"
  done
  [ -n "$miss" ] && printf '%-12s missing:%s\n' "$f" "$miss"
done
```

Measured against three fixtures — a complete block, one with a field dropped,
and a bare diagram:

    docs/missing.md missing: Project
    docs/none.md missing: Name Type Project Description

`docs/good.md` prints nothing, which is the whole contract: the check is silent
when the four fields are there and names the ones that are not.

Also render before committing. A Mermaid block with a syntax error is a
diagram-shaped hole in the documentation, and the error is invisible in the
diff. Record the renderer version next to the diagram; the dialect moves.

## 10. Traps in the probes themselves

**An exclusion that excludes nothing.** Every probe here greps for a symbol and
then removes the file that defines it. The removal is where it goes wrong:

    grep -rl --include='*.py' -w HybridSearch .     ->  ./src/search.py
                                                        ./tests/test_search.py
    grep -rl --include='*.py' -w HybridSearch src   ->  src/search.py
                                                        tests/test_search.py

GNU grep 3.12 prefixes `./` when rooted at `.` and does not when given explicit
directories. A `| grep -v '/src/search\.py$'` written against one form silently
excludes nothing in the other — leaving the definition in the list, so a count
of "callers" reads 1 for a symbol with no callers at all, **in the direction
that hides the finding.** Root the search at explicit directories, and remove
the definer with `grep -vx` against the path as the same command printed it.

**A grep that is not grep.** Where a wrapper, alias or hook has put a modern
search tool behind the name `grep`, it will not print `./`, it may not order its
output, and it will skip ignored files. All three change the numbers above. If
the result of a probe is going into a document, run it through a path you
control — `/usr/bin/grep`, or whatever `command -v` says it really is — and say
in the document which.

**A symbol name that is also a word.** `-w` is not enough for names like
`search`, `index` or `generate`; they appear in comments, strings and unrelated
modules. Resolve through the AST where the language has one, and treat grep
counts as a list to read rather than a number to quote.

Measured here against GNU grep 3.12, GNU sed 4.9 and Python 3.14.4.
