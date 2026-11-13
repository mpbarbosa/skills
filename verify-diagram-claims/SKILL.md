---
name: verify-diagram-claims
description: >
  Establish that a diagram is true of the code that actually runs — before
  drawing one, and before trusting one already in the repository. Use when
  asked what notation or diagram a project is missing, when drawing or
  reviewing a flowchart, sequence, class, ER, dataflow, topology or C4
  diagram, when a diagram is offered as evidence of how something works, or
  when choosing which notation to draw. Also when checking the counts,
  citations or claims table a diagram document states about a codebase, and
  when the notation's primitive — a class, say — does not exist in the
  language being drawn. A diagram read off the source describes the code that
  exists, not the code that is reached — and it renders, reviews and reads
  perfectly either way.
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

## 11. The counts in the prose are claims, and they fail by scope

A wrong edge gets caught, because a reviewer who knows the code recognises a
wrong arrow. A wrong **number** does not: nobody holds "489" in their head, and
every reading of it is plausible.

Nine counts in the first draft of one class-diagram document were wrong. Not one
was an arithmetic slip. Each was an honest measurement of a slightly different
question from the sentence it was sitting in.

Asked of one repository at one instant — *how many Bash functions are defined
under `scripts/`?*

| probe | definition sites | files |
|---|---|---|
| `git grep HEAD -- 'scripts/**/*.sh'` | 458 | 54 |
| `git grep HEAD -- 'scripts/*.sh'` | 496 | 58 |
| `git grep HEAD -- ':(glob)scripts/**/*.sh'` | 496 | 58 |
| `git grep HEAD -- scripts/` | 497 | 59 |
| `grep -r scripts/ --include='*.sh'` | **502** | 58 |

A 10% spread, and every row is the right answer to its own question. The four
gaps, each measured rather than assumed:

- **git pathspec wildcards cross `/` unless you ask for glob magic.**
  `scripts/*.sh` matches `scripts/lib/app_managers.sh` — verified, it is the
  first hit — while the narrower-*looking* `scripts/**/*.sh` is the spelling
  that drops the four top-level scripts. Backwards from shell intuition, in the
  direction that silently shrinks a count.
- **`git grep <rev>` reads the commit; `grep -r` reads your working tree.** The
  6-site gap between the last two rows is four `.sh` files carrying uncommitted
  edits, some of them another session's. **A count taken from the filesystem of
  a dirty checkout is a count of nobody's commit**, and the reader cannot
  reproduce it.
- **A directory pathspec counts your documentation.** The extra file in row 4 is
  `scripts/REFACTORING_SUMMARY.md` — a stale design note whose prose matches the
  function-definition regex.
- **"across M files" is a second question you did not notice asking.** 60 `.sh`
  files exist under `scripts/`; 58 of them define a function. Both are true, and
  "N functions across M files" has quietly asked two things at once.

So **pin the count to a revision and quote the probe beside it.** The document
this came from survived re-measurement a day later for exactly that reason: it
claimed 495 sites / 489 names *at commit `f442b24`*, and
`git grep f442b24 -- ':(glob)scripts/**/*.sh'` still returns 495 and 489. At
`HEAD` the same probe returns 496 and 490, because one function landed in
between. An unpinned count would simply have gone wrong, with nothing to mark
the moment it did.

**Sites and names are different counts, and a dict silently picks one.** In that
tree, four names are defined at more than one site — `normalize_apt_version` (3),
`usage` (3), `set_alternative_if_available` (2), `verbose_enabled` (2). Ten sites,
four keys: any probe that indexes into a dict by name loses exactly the 6 that
separate 502 from 496. Say which of the two the sentence means.

**And do not quote a fraction you did not divide.** The same draft said one key
prefix accounted for *"roughly two thirds"* of call sites. Measured: 336 of 596,
which is 56%. Write `336 of 596` and let the reader check the division.

Measured against git 2.53.0 and GNU grep 3.12 on one repository of 60 shell
files. The spread is a property of the probes, not of that repository; its
magnitude is not.

## 12. Render is not parse, and the harness needs stubs before it needs your diagram

Section 9 closes with one sentence — *also render before committing*. **That
sentence is not enough, and this corrects it.** The obvious way to act on it is
`mermaid.parse()`, which is a syntax check: it answers whether the text is
well-formed, not whether the diagram draws. A parse-only check was shipped as
"the diagrams render" in the document this came from, and it had established no
such thing.

Rendering headlessly is a dozen lines, and all the difficulty is in the DOM, not
in your diagram:

```js
const dom = new JSDOM('<!doctype html><html><body><div id="c"></div></body></html>',
                      { pretendToBeVisual: true });
for (const k of ['window','document','SVGElement','Element','HTMLElement','Node',
                 'DOMParser','CSSStyleDeclaration','getComputedStyle'])
  globalThis[k] = dom.window[k] ?? dom.window;
globalThis.CSSStyleSheet = dom.window.CSSStyleSheet
  ?? class { replaceSync(){} insertRule(){} get cssRules(){ return []; } };
globalThis.MutationObserver = dom.window.MutationObserver
  ?? class { observe(){} disconnect(){} };
globalThis.requestAnimationFrame = (cb) => setTimeout(cb, 0);

// jsdom has no SVG layout; mermaid's dagre pass calls these and gets undefined
const proto = dom.window.SVGElement.prototype;
proto.getBBox = function () {
  const n = (this.textContent || '').length;
  return { x: 0, y: 0, width: Math.max(10, n * 7), height: 18 };
};
proto.getComputedTextLength = function () { return (this.textContent || '').length * 7; };
proto.getScreenCTM = function () {
  return { a:1,b:0,c:0,d:1,e:0,f:0, inverse(){ return this; }, multiply(){ return this; } };
};
proto.createSVGMatrix = function () { return { a:1,b:0,c:0,d:1,e:0,f:0 }; };

const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false, securityLevel: 'loose' });
const { svg } = await mermaid.render(id, block, dom.window.document.getElementById('c'));
```

**The first run of this failed on all six blocks with `CSSStyleSheet is not
defined`, which reads exactly like six broken diagrams and was one missing
global.** Expect that, and diagnose the environment before touching the diagram:
a harness that cannot render *anything* yet tells you nothing about what you
drew.

Which is why it needs both controls, and they are cheap:

    a deliberately broken block   -> RENDER FAILED  Parse error on line 3
    a trivial two-class block     -> rendered  svg=15869B

Without the first, "rendered" is unfalsifiable. Also assert on the SVG, not just
on the absence of a throw — mermaid renders a *syntax-error graph* rather than
throwing in some cases, so test the output for `aria-roledescription="error"`,
and grep it for the labels your prose depends on. Six blocks in that document
produced 408 KB of SVG and each label the surrounding paragraphs cite was found
in it.

**State the limit in the document.** `getBBox` is a stub returning a guess from
text length, so this establishes that the blocks compile to SVG carrying the
right labels. It establishes nothing about layout, overlap or legibility in a
real browser.

Install the harness outside the repository — a scratch directory with its own
`package.json` — so a one-off check does not land as a devDependency in a
project that will never run it. Record the renderer version next to the diagram;
the dialect moves. Measured with mermaid 11.17.2, jsdom 31.0.0, Node 26.13.0.

## 13. A claims table can cite an instrument that was never run

Section 6 gets you the table. This is the failure that lives *inside* it, and it
is invisible to every reader: the row is well-formed, the claim is true, and the
thing in the "Held by" column does not exist.

> **Recorded.** A class-diagram document asserted that two modules have no
> dependency on each other "as the probe in §7 confirms". Section 7 contained no
> such probe. One had never been written — a reachability probe had, answering a
> different question, and the citation had drifted onto it while the sentence was
> being edited. The claim turned out to be true when a dependency probe was
> finally built and controlled, which is the uncomfortable part: **the table had
> been right about the code and wrong about itself**, and nothing in the document
> could have told you.

So resolve the citations mechanically, the way section 3 resolves the nodes.
Extract every quoted test name from the document and look it up in the suites:

```python
flat = re.sub(r'\s+', ' ', open(doc).read())          # see below — do not skip this
quoted = re.findall(r'[*`]"([^"]+)"[*`]', flat)
names  = set(re.findall(r'^@test\s+"([^"]+)"', suite, re.M))
```

**Flatten the whitespace first, or the checker lies about why it failed.** A
claims table wraps, so a cited name spans a line break; `[^"]+` happily captures
the newline and the next line's indentation, the lookup then fails, and the
failure prints only up to the break. Measured on the same document, 21 citations:

    without flattening   2 unresolved
    with flattening      0 unresolved

and the two read as

    FAIL  each summary carries its own
    FAIL  a filtered run tags the summary with the

Both are real test names, truncated mid-sentence by the report that was supposed
to be checking them — so they look precisely like tests somebody renamed. Two
hours of chasing renames that never happened is the cost of the missing `re.sub`.

Running that checker on a document whose wrapping had just changed also surfaced
two genuine defects of a kind nothing else would catch: a sentence-ending period
sitting *inside* the quotation marks of a quoted test name, so the cited name was
not the test's name. Cheap to fix, impossible to see.

Then, per row, ask the question the table does not: **when did the cited
instrument last run, and have you watched it fail?** A test name in that column
is an assumption until someone has seen it go red — which is section 6's pointer
to [`mutation-test-guards`](../mutation-test-guards/), and it applies to the
probes you wrote for the document just as much as to the project's own suite.

## 14. Drawing a class diagram of a language that has no classes

Asked for a class diagram, the first probe is not "what are the classes" but
"are there any", and it needs its control in the same breath:

    bash                                0
    web/src + web/backend  (ts/tsx/js)   0
    quickshell             (qml)         0
    ----
    control: the same probe over node_modules/   717

**Zero in the product and 717 in the dependencies** is a finding, not an
obstacle: the probe works, and the notation's primitive is simply absent from
the codebase. A Bash project has one global namespace and `source` as its only
composition mechanism; a React and Node project written in hooks and modules has
no more classes than the Bash does.

Two bad options and one good one. Inventing classes to fill the diagram makes it
fiction. Refusing to draw discards the extraction, which section 2 says is worth
running whatever happens to the picture. Instead **draw the units the language
actually has, and put the absence in the document's opening paragraph rather than
in a caveat at the bottom** — stereotyped modules (`«module»`, `«orchestrator»`,
`«plugin»`, `«event»`, `«config schema»`, `«react component»`), with a
declaration-count table immediately under the title showing what the extraction
found. A reader who disagrees with the framing then disagrees on line 20, not
after six diagrams.

The reachability probe in section 1 needs replacing too, because `ast` has no
Bash equivalent. What worked: collect every function name defined anywhere, scan
each function's body for occurrences of the others to build the call graph, root
the walk at the top-level statements of the entry point, and **control it by
injecting one call into a scratch copy** — the probe must report exactly that new
edge and nothing else. Section 5's warning is sharper here than in a language
with an AST: a hand-rolled graph that finds no surprise is far more likely to be
a broken graph than a tidy codebase.

## When editing this skill: verified does not license the generalisation

Every correction to this file goes in the table below, with **how it got in** —
the cause is the reusable part, not the fix.

| What was wrong | How it got there |
|---|---|
| Section 9's *"also render before committing"*, left as one sentence, which §12 now corrects | the rule was right and too short to act on: its obvious reading is `mermaid.parse()`, which checks syntax and draws nothing, and a parse-only check shipped as "the diagrams render" |
| *"the probe in §7 confirms there is no cross-module edge"*, in a document written with this skill open | a citation drifted onto a probe answering a different question while the sentence around it was edited; §13 is the check that catches it, and it did not exist yet |
| *"486 of 489 names, because the probe skips a nested definition"* — drafted for §11 and cut before publishing | the mechanism could not be reproduced: the tree has no indented function definitions at all. Replaced with the dict-collapse gap, which measures exactly |

Two of the three were written while this skill was loaded and being followed,
which is the point worth keeping: **the author of a probe is the worst-placed
person to notice the question it does not ask.** The first row is the sharpest,
because the sentence it corrects was not false — it was true, and too compressed
to be executed correctly.

Hence, as elsewhere in this corpus: **write the rule at the scope of the test.**
If you measured a spread across five pathspecs in one repository, write that —
not "counts are unreliable".
