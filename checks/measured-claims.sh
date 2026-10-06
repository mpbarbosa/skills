#!/bin/sh
# Re-measures the claims the session-* skills rest on, in a throwaway fixture.
#
# These are not tests of the prose. Each one rebuilds the situation a skill
# quotes and asserts the number the skill prints, so the check goes red when
# git, procps or the shell change behaviour under a documented claim — and not
# when a sentence is reworded.
#
# Positive controls are deliberate: a probe that cannot see a thing which IS
# there proves nothing by failing to see a thing which is not.

set -u
fails=0
checked=0

ok()   { checked=$((checked+1)); printf '  ok    %s\n' "$1"; }
bad()  { checked=$((checked+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 — expected [$3], got [$2]"; fi; }
halt() { printf '  CANNOT DETERMINE  %s\n' "$1"; exit 2; }

printf '%s\n' "$(git --version)" "$(pgrep --version 2>&1 | head -1)" | sed 's/^/env   /'

# ---------------------------------------------------------------------------
# A remote-tracking ref is local state. Only the server knows the branch is gone.
#   session-pending check 2, session-teardown "git branch -a lists origin/<branch>
#   after both deletions succeeded", session-dropped check 3.
# ---------------------------------------------------------------------------
echo
echo "a branch deleted on origin, never pruned here"

tmp=$(mktemp -d) || halt "could not make a fixture directory"
trap 'rm -rf "$tmp"' EXIT INT TERM

git init -q --bare "$tmp/origin.git"  || halt "git init --bare failed"
git init -q -b main "$tmp/work"       || halt "git init failed (does this git support -b?)"
cd "$tmp/work"                        || halt "could not enter the fixture"
git config user.email checks@example.invalid
git config user.name  checks
git commit -q --allow-empty -m init
git remote add origin "$tmp/origin.git"
git push -q -u origin main            || halt "push to the fixture remote failed"
git checkout -q -b feature
git commit -q --allow-empty -m feat
git push -q -u origin feature         || halt "push of the feature branch failed"

# Positive control: the probe can see the branch while it is there.
[ -n "$(git ls-remote --heads origin feature)" ] \
  && ok "control: ls-remote sees the branch while it exists" \
  || bad "control: ls-remote saw nothing for a branch that IS on origin"

# Someone else deletes it server-side. Pushing --delete from here would prune
# our own remote-tracking ref, which is the state we need to keep.
git -C "$tmp/origin.git" update-ref -d refs/heads/feature

eq "@{upstream} still resolves" \
   "$(git rev-parse --abbrev-ref 'feature@{upstream}' 2>/dev/null)" "origin/feature"

eq "log upstream..branch reads 0 ahead — the false negative" \
   "$(git log --oneline 'feature@{upstream}..feature' | wc -l | tr -d ' ')" "0"

eq "the stale remote-tracking ref is still present" \
   "$(git rev-parse --verify -q refs/remotes/origin/feature >/dev/null && echo yes || echo no)" "yes"

eq "git branch -a still lists origin/feature" \
   "$(git branch -a | grep -c 'remotes/origin/feature' | tr -d ' ')" "1"

eq "ls-remote asks the server and reports nothing — no fetch first" \
   "$(git ls-remote --heads origin feature | wc -l | tr -d ' ')" "0"

cd / || exit 1

# ---------------------------------------------------------------------------
# pgrep matching the shell that is running it.
#   session-pending, "the producing process".
# ---------------------------------------------------------------------------
echo
echo "pgrep against the command line that invoked it"

tok=zz_checks_probe.ts          # plain: a pattern that matches its own text
esc='zz_checks_probe\.ts'       # escaped dot: does not match its own text
brk='[z]z_checks_probe\.ts'     # bracketed: matches neither its own text nor itself

# A compound command keeps the wrapper in the process table; `sh -c <simple>`
# execs over itself and vanishes, which is why this needs the `; :`.
wrap() { sh -c "$1 ; :"; }

[ "$(wrap "pgrep -cf '$brk'" ; true)" = "0" ] \
  || halt "something matching the probe token is already running"

eq "a plain pattern counts its own wrapper with nothing running" \
   "$(wrap "pgrep -cf '$tok'" ; true)" "1"

eq "an escaped dot does not match its own text, so it counts 0" \
   "$(wrap "pgrep -cf '$esc'" ; true)" "0"

eq "a bracketed pattern counts 0" \
   "$(wrap "pgrep -cf '$brk'" ; true)" "0"

# Positive controls: a pattern that reports 0 for a process that IS running is
# the dangerous direction for this skill.
real=$(mktemp -d) || halt "could not make a probe directory"
printf 'sleep 30\n' > "$real/$tok"
sh "$real/$tok" & direct=$!
sleep 1

eq "control: bracketed form sees a directly exec'd process" \
   "$(wrap "pgrep -cf '$brk'" ; true)" "1"

kill "$direct" 2>/dev/null; wait "$direct" 2>/dev/null
sleep 1

sh -c "sleep 30 # $tok" & viashell=$!
sleep 1

eq "control: bracketed form sees a shell-launched process" \
   "$(wrap "pgrep -cf '$brk'" ; true)" "1"

eq "the ' -c ' filter hides that same running process" \
   "$(wrap "pgrep -af '$tok' | grep -vc ' -c '" ; true)" "0"

kill "$viashell" 2>/dev/null; wait "$viashell" 2>/dev/null
rm -rf "$real"

echo
if [ "$fails" -eq 0 ]; then
  printf '%s claims re-measured, all hold\n' "$checked"
  exit 0
fi
printf '%s of %s claims no longer hold\n' "$fails" "$checked"
exit 1
