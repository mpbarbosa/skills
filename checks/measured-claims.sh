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
skips=0
junk=''

ok()   { checked=$((checked+1)); printf '  ok    %s\n' "$1"; }
bad()  { checked=$((checked+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 — expected [$3], got [$2]"; fi; }
skip() { skips=$((skips+1)); printf '  skip  %s — %s\n' "$1" "$2"; }
halt() { printf '  CANNOT DETERMINE  %s\n' "$1"; exit 2; }

sweep() { rm -rf $junk; }
trap sweep EXIT INT TERM
keep()  { junk="$junk $1"; }

printf '%s\n' "$(git --version)" "$(pgrep --version 2>&1 | head -1)" | sed 's/^/env   /'

# ---------------------------------------------------------------------------
# A remote-tracking ref is local state. Only the server knows the branch is gone.
#   session-pending check 2, session-teardown "git branch -a lists origin/<branch>
#   after both deletions succeeded", session-dropped check 3.
# ---------------------------------------------------------------------------
echo
echo "a branch deleted on origin, never pruned here"

tmp=$(mktemp -d) || halt "could not make a fixture directory"
keep "$tmp"

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
keep "$real"
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

# ---------------------------------------------------------------------------
# Removal reporting success while the thing survives.
#   session-dropped: "removal can partly fail and say nothing" — a branch
#   deleted locally whose remote copy survives, a worktree removed whose
#   registration lingers, a process that ignored a signal.
# ---------------------------------------------------------------------------
echo
echo "removal that reports success and leaves the thing behind"

d=$(mktemp -d) || halt "could not make a fixture directory"
keep "$d"

git init -q --bare "$d/origin.git" || halt "git init --bare failed"
git init -q -b main "$d/root"      || halt "git init failed"
cd "$d/root"                       || halt "could not enter the fixture"
git config user.email checks@example.invalid
git config user.name  checks
git commit -q --allow-empty -m init
git remote add origin "$d/origin.git"
git push -q -u origin main    || halt "push to the fixture remote failed"
git checkout -q -b feature
git commit -q --allow-empty -m feat
git push -q -u origin feature || halt "push of the feature branch failed"
git checkout -q main
git merge -q feature          || halt "merge of the fixture branch failed"

# A merged branch, so -d is the ordinary success path rather than a refusal.
git branch -d feature >/dev/null 2>&1
eq "git branch -d on a merged branch exits 0" "$?" "0"

eq "the local branch is gone" \
   "$(git branch --format='%(refname:short)' | grep -c '^feature$' | tr -d ' ')" "0"

eq "and the remote copy survives that deletion" \
   "$(git ls-remote --heads origin feature | wc -l | tr -d ' ')" "1"

git worktree add -q -b wt1 "$d/wt1" >/dev/null 2>&1 \
  || halt "git worktree add failed"

# Positive control: the listing names a worktree that is really there.
eq "control: git worktree list names a live worktree" \
   "$(git worktree list | grep -c "$d/wt1" | tr -d ' ')" "1"

rm -rf "$d/wt1"

eq "a worktree directory removed by hand stays registered" \
   "$(git worktree list | grep -c "$d/wt1" | tr -d ' ')" "1"

eq "and the listing flags it prunable" \
   "$(git worktree list --porcelain | grep -c '^prunable' | tr -d ' ')" "1"

git worktree add -q -b wt2 "$d/wt2" >/dev/null 2>&1 \
  || halt "second git worktree add failed"
echo stray > "$d/wt2/stray.txt"
git worktree remove "$d/wt2" >/dev/null 2>&1
eq "git worktree remove refuses a tree holding an untracked file" "$?" "128"

eq "and that worktree is still registered afterwards" \
   "$(git worktree list | grep -c "$d/wt2" | tr -d ' ')" "1"

# A clean worktree says nothing about the shared checkout.
git worktree add -q -b wt3 "$d/wt3" >/dev/null 2>&1 \
  || halt "third git worktree add failed"
echo left-behind > "$d/root/left-behind.txt"

eq "the shared root is dirty" \
   "$(git -C "$d/root" status --porcelain -uall | wc -l | tr -d ' ')" "1"

eq "while a clean worktree reports nothing at all" \
   "$(git -C "$d/wt3" status --porcelain -uall | wc -l | tr -d ' ')" "0"

cd / || exit 1

# A signal is a request. kill reports only that it sent one.
sh -c 'trap "" TERM; sleep 30' & deaf=$!
sleep 1
kill "$deaf" 2>/dev/null
eq "kill exits 0 against a process ignoring SIGTERM" "$?" "0"
sleep 1
eq "and the process is still running" \
   "$(kill -0 "$deaf" 2>/dev/null && echo alive || echo gone)" "alive"
kill -9 "$deaf" 2>/dev/null
sleep 1
eq "control: SIGKILL does end it" \
   "$(kill -0 "$deaf" 2>/dev/null && echo alive || echo gone)" "gone"
wait "$deaf" 2>/dev/null

# ---------------------------------------------------------------------------
# A listener scan cannot see a client, and cannot name an owner without -p.
#   session-dropped check 5, and "a port scan cannot see a client".
# ---------------------------------------------------------------------------
echo
echo "what a listener scan can and cannot see"

if ! command -v ss >/dev/null 2>&1; then
  skip "listener scan claims" "ss is not installed"
elif ! command -v python3 >/dev/null 2>&1; then
  skip "listener scan claims" "python3 is not installed, and the fixture needs a socket"
else
  sock=$(mktemp -d); keep "$sock"
  cat > "$sock/pair.py" <<'SOCKFIXTURE'
import socket, sys, time
srv = socket.socket(); srv.bind(("127.0.0.1", 0)); srv.listen(1)
listen_port = srv.getsockname()[1]
cli = socket.socket(); cli.connect(("127.0.0.1", listen_port))
accepted, _ = srv.accept()   # keep it: a dropped reference closes the connection
print(listen_port, cli.getsockname()[1], flush=True)
time.sleep(int(sys.argv[1]))
SOCKFIXTURE
  python3 "$sock/pair.py" 20 > "$sock/ports" 2>/dev/null & sockpid=$!
  sleep 2
  lport=''; cport=''
  read -r lport cport < "$sock/ports" 2>/dev/null || true

  if [ -z "$lport" ] || [ -z "$cport" ]; then
    skip "listener scan claims" "the socket fixture did not come up"
  else
    eq "control: the listening port appears in ss -ltn" \
       "$(ss -ltn | grep -c ":$lport\b" | tr -d ' ')" "1"

    eq "the client's own port does not" \
       "$(ss -ltn | grep -c ":$cport\b" | tr -d ' ')" "0"

    eq "control: an established-connection scan does see it" \
       "$([ "$(ss -tn state established | grep -c ":$cport\b")" -ge 1 ] && echo seen || echo missed)" "seen"

    eq "ss -ltn names no owner for your own listener" \
       "$(ss -ltn | grep ":$lport\b" | grep -c 'pid=' | tr -d ' ')" "0"

    eq "ss -ltnp names the pid, unprivileged, for your own process" \
       "$(ss -ltnp | grep ":$lport\b" | grep -c 'pid=' | tr -d ' ')" "1"
  fi
  kill "$sockpid" 2>/dev/null
  wait "$sockpid" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# The field session-dropped tells you to read is still the field gh offers.
# ---------------------------------------------------------------------------
echo
echo "the documented gh field"

if ! command -v gh >/dev/null 2>&1; then
  skip "gh repo view field name" "gh is not installed"
else
  # An unknown field makes gh print the valid ones. No network, no auth.
  eq "deleteBranchOnMerge is still a gh repo view --json field" \
     "$(gh repo view --json zzNoSuchField 2>&1 | grep -c '^  deleteBranchOnMerge$' | tr -d ' ')" "1"
fi

echo
[ "$skips" -gt 0 ] && printf '%s claims skipped for want of an optional tool\n' "$skips"
if [ "$fails" -eq 0 ]; then
  printf '%s claims re-measured, all hold\n' "$checked"
  exit 0
fi
printf '%s of %s claims no longer hold\n' "$fails" "$checked"
exit 1
