---
name: verify-pasted-url
description: >
  Establish what a pasted URL actually is — and whether a stranger can open it
  and a machine can confirm it — before storing it anywhere. Use whenever
  someone hands you a link to file, embed, publish or record: a video, a
  profile, a post, an invite, a document. Also when writing a checker for
  stored links, or deciding what shape of identifier to store. The label
  someone typed, the search result and the address bar are all hints; several
  hosts answer 200 for an identifier that does not exist.
---

# Verifying a URL before you store it

Someone pastes a link and says what it is. The description is a **hint**, not
evidence — and so is the search result it came from, the thumbnail, the
surrounding text, and the address bar it was copied from. Storing on that basis
produces a record that looks right and points at nothing, which is worse than
having no record, because nothing downstream will ever question it.

Two questions decide everything that follows, in this order:

1. **Can a stranger open it?** Not you — you are signed in, a member, on the
   right network.
2. **Can a machine confirm it?** If not, no checker you write later has anything
   to stand on.

Answer both *before* choosing what to store. The answers determine the stored
shape, and the stored shape determines everything downstream.

## 1. The address bar is the suspect form

The most common failure is a URL copied from inside the thing, which is a
pointer for people who are already inside it.

The measured case: `discord.com/channels/<guild>/@home` is what a member's
browser shows. A non-member following it gets **their own** Discord — no join
prompt, no error, no sign that anything was meant to happen. The shareable form
is an entirely different URL, reachable only from a menu a member has to go and
use.

Same disease, different hosts: a Drive or Dropbox link from a signed-in tab, a
Slack `archives/` permalink, anything under `/settings/` or `/admin/`, a share
URL carrying a token that identifies whoever copied it.

**Ask for the shareable form, and say why in one line.** Do not lift an
identifier out of a member-only URL and construct a link from it — you will
build something syntactically valid that no stranger can open.

## 2. Probe with a control case, always

**Verifiability is a property of the host, not of your diligence.** Some hosts
answer honestly about whether an identifier exists; many do not. Establish which
you have by asking the same question twice — once with the real identifier, once
with an invented one — and reading both answers together:

```sh
probe() { curl -s -o /dev/null -w "%{http_code} %{size_download}B  $1\n" --max-time 15 "$2"; }
probe "real    " "<url with the real id>"
probe "invented" "<same url, characters changed>"
```

Measured today against YouTube, which gives one of each:

    oEmbed endpoint       real 200   868B      invented 400    11B     discriminates
    plain watch page      real 200  1360267B   invented 200 793171B    does NOT

A checker built on the watch page's status code would pass for an identifier
that does not exist. Two more, measured in the skills this one generalises:
Discord guild pages answered **200 / 63681 B** real against **200 / 63657 B**
invented, both `<title>Discord</title>`; Instagram embeds answered **620681 B**
against **620686 B**, both the login shell.

**A difference in byte count is not discrimination.** The watch page above
differs by half a megabyte and still tells you nothing a program can rely on —
you cannot set a threshold on page weight. What counts is a response that
differs in a way you can key on: a **status code**, or a **distinct error body**.

    real      {"author_name":"Rick Astley","title":"Rick Astley - Never Gonna…"}
    invented  Bad Request                                              (HTTP 400)

Content can discriminate where the status code does not — the invented watch
page returns `<title> - YouTube</title>`, empty where the real one is not. That
is usable, but it is a weaker guarantee than an error code, and it must be
checked for *emptiness* rather than for a match, which is easy to get backwards.

## 3. The discriminating endpoint decides the stored shape

This is the design decision, and it belongs here rather than in the parser.

Prefer to store the identifier that a discriminating endpoint accepts, because
that is the one a checker can confirm later. In the Discord case the invite code
is both the form a stranger can open **and** the form the API resolves; the guild
id from the address bar is neither. One value satisfies both questions — store
that one.

Look for the host's own metadata endpoint before concluding none exists: oEmbed,
an unauthenticated API route, a `.json` suffix, an embed page that renders
rather than redirecting to a login.

## 4. When nothing discriminates, render it — and record why

Some hosts genuinely cannot be checked without a browser. Then open it and look:
an embed URL is usually the renderable form, and it is the only honest
verification available.

**Write down why there is no checker, next to the data.** Otherwise the next
person adds one built on a 200 — which passes for everything, including entries
that are wrong — and the file now carries a gate that certifies nothing.

## 5. Existence is not the only question

A link can be real and still wrong to store. Verification should also answer
**what kind of thing it is** and **who published it**:

- The uploader, not the title. A fan re-upload, a reaction channel or a mirror
  is real, resolves fine, and is still a fail — it disappears, gets taken down,
  or was never authoritative.
- The kind, from the URL's own path, before calling any parser. `/p/`, `/reel/`,
  `/tv/`, `/stories/` are different things that look alike.

> **A real-but-unofficial source is a fail, not a pass with a caveat.**

If the metadata is inconclusive about who or what it is, stop and ask. Guessing
here produces the failure this whole skill exists to prevent, one step later.

## 6. Know what your parser actually returns

Run the parser the application itself uses, on the real string, and read the
output — do not reason about it and do not hand-strip the query.

The trap worth stating: a "get the handle" helper that returns the **first path
segment** returns `p` for a post URL and `reel` for a reel. Neither is a handle,
both are strings, and a handle of `p` type-checks, passes every unit test, and
links to nothing. **Decide the kind from the path first, then call the parser
that matches that kind.**

And check that the parser you are importing still lives where the skill says it
does. A module can move without anything going red — no type-checker reads a
skill file — so a command in a document can name the wrong import for weeks.

## 7. Store the identifier, never the URL

Derive the address at render time from a stored id. This makes tracking
parameters unstorable by construction rather than by remembering to strip them:

    ?utm_source=ig_web_copy_link&stkn=…     ?si=…     &t=…     ?rdt=…     &list=RD…

`stkn` and its equivalents are **share tokens identifying whoever copied the
link**. They do not belong in a committed file.

**Store identity separately when it can drift from the address.** Ask: *could
this string one day open something else, with nothing about the string
changing?* A vanity code is the clear case — hosts reclaim them when a tier
lapses, and whoever claims it next inherits your link. When the answer is yes,
record both: the address a reader follows, and the id that says what it is.

## 8. "There is nowhere to put this" is a real answer

Often the likeliest correct one, and the easiest to get wrong under pressure to
file something.

If a link is valid but the project has no destination that renders it, say so
and stop. Creating the destination is not a data edit — it is a type, a
component, a place on a page, a test, and a decision about whether that surface
should exist. That is a feature, and it deserves to be proposed as one.

## Report

```
VERIFIED — official, resolves, shareable.

  source     oEmbed: author "<the official channel>", title matches the fixture
  control    invented id -> 400; the endpoint discriminates
  stored     id only; tracking params dropped by construction
```

```
NOT STORED — cannot be confirmed, and not shareable anyway.

  given      discord.com/channels/<guild>/@home  (a member's address bar)
  stranger   opens their own Discord; no join prompt
  control    real and invented ids both 200, same page
  asked      for the invite link instead
```

```
VERIFIED, BUT NOWHERE TO PUT IT.

  real, official, and about the club rather than a player.
  This project renders posts only on the player card.
  A club surface would be a type, a component and a test — a feature, not
  a data edit. Not filing it.
```

## Rules

- **The label is a hint.** So is the search result, the thumbnail and the
  address bar.
- **Never probe without a control case.** A single 200 tells you nothing until
  an invented identifier has answered too.
- **Byte counts do not discriminate.** Status codes and distinct error bodies
  do.
- **Store the identifier, not the URL**, and store identity separately when it
  can drift from the address.
- **A real-but-unofficial source is a fail.**
- **Record why a checker is absent**, or someone will write one built on a 200.
- **"Nowhere to put it" is an answer**, and creating a destination is a feature.
