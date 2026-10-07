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

# The repository root, for the one claim that reads a committed file. Overridable
# so a mutated copy of this script can be pointed at a mutated tree.
root=${CHECKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

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
elif ! gh auth status >/dev/null 2>&1; then
  # gh checks auth before it validates the field name, so an unauthenticated
  # run reports nothing and would fail this for the wrong reason.
  skip "gh repo view field name" "gh is not authenticated"
else
  # An unknown field makes gh print the valid ones. No network, no auth.
  eq "deleteBranchOnMerge is still a gh repo view --json field" \
     "$(gh repo view --json zzNoSuchField 2>&1 | grep -c '^  deleteBranchOnMerge$' | tr -d ' ')" "1"
fi

# ---------------------------------------------------------------------------
# git branch -d compares against the branch's upstream, not the default branch.
#   session-teardown, "Branches" — and the entry criterion in README.md.
# ---------------------------------------------------------------------------
echo
echo "what git branch -d actually checks"

b=$(mktemp -d) || halt "could not make a fixture directory"
keep "$b"
git init -q --bare "$b/origin.git" || halt "git init --bare failed"
git init -q -b main "$b/w"         || halt "git init failed"
cd "$b/w"                          || halt "could not enter the fixture"
git config user.email checks@example.invalid
git config user.name  checks
echo seed > seed; git add seed; git commit -q -m init
git remote add origin "$b/origin.git"
git push -q -u origin main || halt "push to the fixture remote failed"

# A branch that was pushed and merged nowhere: the state of every branch whose
# PR is still open.
git checkout -q -b pushed-only
echo work > work; git add work; git commit -q -m work
git push -q -u origin pushed-only || halt "push of pushed-only failed"
git checkout -q main

eq "control: the branch has landed nowhere" \
   "$(git rev-list --count origin/main..pushed-only)" "1"

out=$(git branch -d pushed-only 2>&1); rc=$?
eq "git branch -d deletes it anyway, exit 0" "$rc" "0"

eq "and says so in a warning rather than a refusal" \
   "$(printf '%s' "$out" | grep -c 'but not yet merged to HEAD' | tr -d ' ')" "1"

eq "the warning compares against the remote-tracking ref" \
   "$(printf '%s' "$out" | grep -c "refs/remotes/origin/pushed-only" | tr -d ' ')" "1"

eq "the branch really is gone" \
   "$(git branch --format='%(refname:short)' | grep -c '^pushed-only$' | tr -d ' ')" "0"

# The mirror image: fully merged into main, but ahead of its own upstream.
git checkout -q -b ahead
echo one > one; git add one; git commit -q -m one
git push -q -u origin ahead || halt "push of ahead failed"
echo two > two; git add two; git commit -q -m two
git checkout -q main
git merge -q ahead          || halt "merge of ahead failed"
git push -q origin main     || halt "push of main failed"

eq "control: this branch has fully landed" \
   "$(git rev-list --count origin/main..ahead)" "0"

out=$(git branch -d ahead 2>&1); rc=$?
eq "git branch -d refuses it anyway, exit 1" "$rc" "1"

eq "calling a landed branch not fully merged" \
   "$(printf '%s' "$out" | grep -c 'is not fully merged' | tr -d ' ')" "1"

# ---------------------------------------------------------------------------
# Landed, or never started? The ancestry test cannot tell.
#   session-teardown, "The asymmetry that governs every command here".
# ---------------------------------------------------------------------------
echo
echo "a branch that never held work answers like a merged one"

git worktree add -q -b prepared "$b/prepared" >/dev/null 2>&1 \
  || halt "git worktree add failed"
git checkout -q -b landed
echo real > real; git add real; git commit -q -m real
git checkout -q main
git merge -q landed     || halt "merge of landed failed"
git push -q origin main || halt "push of main failed"

for br in prepared landed; do
  git merge-base --is-ancestor "$br" origin/main
  eq "is-ancestor says landed for '$br'" "$?" "0"
  eq "rev-list counts 0 ahead for '$br'" \
     "$(git rev-list --count "origin/main..$br")" "0"
done

# The reflog is what separates them.
for pair in "prepared same" "landed different"; do
  br=${pair% *}; want=${pair#* }
  born=$(git reflog show "$br" --format='%H' | tail -1)
  tip=$(git rev-parse "$br")
  eq "reflog birth is $want from the tip for '$br'" \
     "$([ "$born" = "$tip" ] && echo same || echo different)" "$want"
done

git reflog expire --expire=now --expire-unreachable=now --all 2>/dev/null
eq "an expired reflog gives an empty birth, which is UNKNOWN" \
   "$(git reflog show prepared --format='%H' 2>/dev/null | tail -1 | wc -c | tr -d ' ')" "0"

# ---------------------------------------------------------------------------
# Two deletions, and the remote-tracking ref that lingers only sometimes.
#   session-teardown, "Local and remote are two deletions" and "Verify after".
# ---------------------------------------------------------------------------
echo
echo "the second deletion, and what it does to the cached ref"

git checkout -q -b doomed
git commit -q --allow-empty -m x
git push -q -u origin doomed || halt "push of doomed failed"
git checkout -q main
git branch -D doomed >/dev/null 2>&1

eq "after a local-only delete, branch -a still lists the remote ref" \
   "$(git branch -a | grep -c 'remotes/origin/doomed' | tr -d ' ')" "1"

git push -q origin --delete doomed 2>/dev/null
eq "but your own push --delete prunes it" \
   "$(git branch -a | grep -c 'remotes/origin/doomed' | tr -d ' ')" "0"

eq "so branch -dr then has nothing to clear" \
   "$(git branch -dr origin/doomed 2>&1 | grep -c 'not found' | tr -d ' ')" "1"

eq "control: the remote branch is gone" \
   "$(git ls-remote --heads origin doomed | wc -l | tr -d ' ')" "0"

# Deleting what is already deleted: two error lines for the state you wanted.
out=$(git push origin --delete doomed 2>&1); rc=$?
eq "a second push --delete exits non-zero" \
   "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero"

eq "saying the remote ref does not exist" \
   "$(printf '%s' "$out" | grep -c 'remote ref does not exist' | tr -d ' ')" "1"

eq "and failed to push some refs" \
   "$(printf '%s' "$out" | grep -c 'failed to push some refs' | tr -d ' ')" "1"

# The cache is wrong in the other direction too: a branch that IS on the server
# and was never fetched here.
git clone -q "$b/origin.git" "$b/fresh" 2>/dev/null || halt "fixture clone failed"
git checkout -q -b theirs
git commit -q --allow-empty -m theirs
git push -q -u origin theirs || halt "push of theirs failed"

eq "a never-fetched branch is missing from branch -a" \
   "$(git -C "$b/fresh" branch -a | grep -c 'remotes/origin/theirs' | tr -d ' ')" "0"

eq "while ls-remote finds it" \
   "$(git -C "$b/fresh" ls-remote --heads origin theirs | wc -l | tr -d ' ')" "1"

cd / || exit 1

# ---------------------------------------------------------------------------
# A cwd that no longer resolves. readlink marks it; the obvious glob does not.
#   session-teardown, "Scanning cwds to ask who is in a worktree".
# ---------------------------------------------------------------------------
echo
echo "readlink on a directory removed underneath a running process"

occupied=$(mktemp -d) || halt "could not make a probe directory"
keep "$occupied"
mkdir -p "$occupied/wt"
( cd "$occupied/wt" && exec sleep 30 ) & sitter=$!
sleep 1

before=$(readlink "/proc/$sitter/cwd" 2>/dev/null)
eq "control: readlink resolves the live directory" \
   "$([ "$before" = "$occupied/wt" ] && echo exact || echo "[$before]")" "exact"

rm -rf "$occupied/wt"
sleep 1
after=$(readlink "/proc/$sitter/cwd" 2>/dev/null)

eq "once removed, readlink appends the marker" \
   "$([ "$after" = "$occupied/wt (deleted)" ] && echo marked || echo "[$after]")" "marked"

eq "the trailing-glob form reports both states identically" \
   "$(naive() { case "$1" in *wt*) echo live ;; *) echo none ;; esac; }
     printf '%s/%s' "$(naive "$before")" "$(naive "$after")")" "live/live"

eq "giving the marker its own arm separates them" \
   "$(arms() { case "$1" in *"(deleted)") echo gone ;; *wt*) echo live ;; *) echo none ;; esac; }
     printf '%s/%s' "$(arms "$before")" "$(arms "$after")")" "live/gone"

kill "$sitter" 2>/dev/null
wait "$sitter" 2>/dev/null

# ---------------------------------------------------------------------------
# A failing run that reports success.
#   mutation-test-guards, "You have to be able to see red".
# ---------------------------------------------------------------------------
echo
echo "exit status through a pipe"

false
eq "false exits 1" "$?" "1"

false | tail -5
eq "false | tail -5 exits 0 — the pipeline reports the tail" "$?" "0"

# pipefail is not POSIX. The dash on GitHub's ubuntu-latest runners does not
# have it, so this is a skip rather than a verdict about the claim.
if ! ( set -o pipefail ) 2>/dev/null; then
  skip "set -o pipefail restores it" "this shell has no set -o pipefail"
else
  ( set -o pipefail; false | tail -5 )
  eq "set -o pipefail restores it" "$?" "1"
fi

if ! command -v bash >/dev/null 2>&1; then
  skip "PIPESTATUS claims" "bash is not installed"
else
  eq "PIPESTATUS[0] read immediately recovers the real status" \
     "$(bash -c 'false | tail -5
                 echo "${PIPESTATUS[0]}"')" "1"

  # Any simple command in between resets it, and an assignment is one.
  eq "one intervening command resets it to 0" \
     "$(bash -c 'false | tail -5
                 echo reading now >/dev/null
                 echo "${PIPESTATUS[0]}"')" "0"

  eq "even capturing \$? first resets it, which is the natural idiom" \
     "$(bash -c 'false | tail -5
                 st=$?
                 echo "${PIPESTATUS[0]}"')" "0"
fi

# A suite whose failure scrolls past the tail.
suite=$(mktemp -d) || halt "could not make a probe directory"
keep "$suite"
cat > "$suite/run" <<'FAKESUITE'
#!/bin/sh
echo "PASS spec/a"; echo "PASS spec/b"; echo "FAIL spec/c"
echo "PASS spec/d"; echo "PASS spec/e"; echo "PASS spec/f"
exit 1
FAKESUITE
chmod +x "$suite/run"

"$suite/run" >/dev/null 2>&1
eq "control: the suite itself exits 1" "$?" "1"

eq "control: and prints its failure" \
   "$("$suite/run" 2>/dev/null | grep -c '^FAIL' | tr -d ' ')" "1"

tailed=$("$suite/run" 2>/dev/null | tail -3); rc=$?
eq "piped through tail -3 it exits 0" "$rc" "0"

eq "and nothing in what you see says FAIL" \
   "$(printf '%s' "$tailed" | grep -c FAIL | tr -d ' ')" "0"

eq "it reads as three clean specs" \
   "$(printf '%s' "$tailed" | grep -c '^PASS' | tr -d ' ')" "3"

# ---------------------------------------------------------------------------
# An input that an earlier rule already rejects exercises nothing.
#   mutation-test-guards, "The failure this prevents" — the two-rule parser.
# ---------------------------------------------------------------------------
echo
echo "deleting the second of two refusals"

# Rule A rejects anything containing a colon. Rule B rejects a bare 17-20 digit
# id. $2 switches rule B on or off, which is the mutation.
extract() {
  case "$1" in *:*) echo null; return ;; esac
  if [ "$2" = on ]; then
    case "$1" in
      ''|*[!0-9]*) : ;;
      *) len=${#1}
         if [ "$len" -ge 17 ] && [ "$len" -le 20 ]; then echo null; return; fi ;;
    esac
  fi
  echo "${1##*/}"
}

url='https://example.com/channels/956003357129700000'
bare='956003357129700000'

eq "control: with rule B present the bare id is refused" \
   "$(extract "$bare" on)" "null"

eq "deleting rule B leaves the full URL unchanged" \
   "$(printf '%s/%s' "$(extract "$url" on)" "$(extract "$url" off)")" "null/null"

eq "and leaves the trimmed form unchanged" \
   "$(printf '%s/%s' "$(extract channels on)" "$(extract channels off)")" "channels/channels"

eq "only the bare id moves, which is the one input nobody writes a test from" \
   "$(printf '%s/%s' "$(extract "$bare" on)" "$(extract "$bare" off)")" "null/$bare"

# ---------------------------------------------------------------------------
# An absence assertion that can never fire.
#   mutation-test-guards, "A test asserting an absence".
# ---------------------------------------------------------------------------
echo
echo "asserting the absence of something you cannot match"

printf 'all fine\n' > "$suite/log"
eq "the typo'd pattern finds nothing while nothing is there" \
   "$(grep -c FORBIDEN "$suite/log" | tr -d ' ')" "0"

printf 'all fine\nFORBIDDEN happened\n' > "$suite/log"
eq "and still finds nothing once the thing appears" \
   "$(grep -c FORBIDEN "$suite/log" | tr -d ' ')" "0"

eq "control: the correct pattern does find it" \
   "$(grep -c FORBIDDEN "$suite/log" | tr -d ' ')" "1"

# ---------------------------------------------------------------------------
# Deriving the old version, and replacing it without eating its neighbours.
#   sync-version, steps 2 and 5.
# ---------------------------------------------------------------------------
echo
echo "a version pattern that silently returns nothing"

sv=$(mktemp -d) || halt "could not make a fixture directory"
keep "$sv"

if ! printf 'x\n' | grep -qP 'x' 2>/dev/null; then
  skip "version pattern claims" "this grep has no -P"
else
  eq "control: a prerelease-shaped pattern finds a prerelease" \
     "$(printf '1.2.3-alpha\n' | grep -oP '\d+\.\d+\.\d+-\w+')" "1.2.3-alpha"

  eq "and returns nothing at all for a plain version" \
     "$(printf '1.2.3\n' | grep -oP '\d+\.\d+\.\d+-\w+' | wc -c | tr -d ' ')" "0"
fi

# What an empty OLD then does to the two commands downstream of it.
printf 'anything at all\n' > "$sv/any"
grep -qF "" "$sv/any"
eq "an empty -F pattern matches every file, so a guard in front passes" "$?" "0"

msg=$(sed -i "s||X|g" "$sv/any" 2>&1); rc=$?
eq "while sed refuses the empty pattern outright" "$rc" "1"
eq "saying it has no previous regular expression" \
   "$(printf '%s' "$msg" | grep -c 'no previous regular expression' | tr -d ' ')" "1"

echo
echo "replacing 0.4.2 with 0.5.0"

printf 'current: 0.4.2\nCDN: lib@0.4.20-alpha\nolder: 0.4.21\n' > "$sv/v"
sed -i "s|0.4.2|0.5.0|g" "$sv/v"

eq "an unanchored sed gets the plain one right" \
   "$(sed -n 1p "$sv/v")" "current: 0.5.0"
eq "corrupts the longer prerelease" \
   "$(sed -n 2p "$sv/v")" "CDN: lib@0.5.00-alpha"
eq "and corrupts the longer patch" \
   "$(sed -n 3p "$sv/v")" "older: 0.5.01"

if ! printf 'x\n' | grep -qP 'x' 2>/dev/null; then
  skip "anchoring claims" "this grep has no -P"
else
  eq "a word boundary refuses the longer version, correctly" \
     "$(printf '0.4.20\n' | grep -cP '\b0\.4\.2\b' | tr -d ' ')" "0"
  eq "but refuses a v-prefixed version too, which is the problem" \
     "$(printf 'v0.4.2\n' | grep -cP '\b0\.4\.2\b' | tr -d ' ')" "0"
  eq "control: it does match the bare version" \
     "$(printf '0.4.2\n' | grep -cP '\b0\.4\.2\b' | tr -d ' ')" "1"

  eq "a flat (?![0-9.]) matches the bare version" \
     "$(printf '0.4.2\n' | grep -cP '(?<![0-9.])0\.4\.2(?![0-9.])' | tr -d ' ')" "1"
  eq "and refuses a tag inside a tarball URL, where versions live" \
     "$(printf 'archive/refs/tags/v0.4.2.tar.gz\n' | grep -cP '(?<![0-9.])0\.4\.2(?![0-9.])' | tr -d ' ')" "0"
fi

if ! command -v perl >/dev/null 2>&1; then
  skip "the recommended replacement form" "perl is not installed"
else
  verdicts=''
  for case_ in '0.4.2' '0.4.2-alpha' 'v0.4.2,' 'lib@0.4.2/x' \
               'archive/refs/tags/v0.4.2.tar.gz' \
               '0.4.20' '0.4.21' '10.4.2' 'v0.4.20'; do
    got=$(printf '%s' "$case_" | perl -pe 's/(?<![0-9.])\Q0.4.2\E(?!\d)(?!\.\d)/0.5.0/g')
    if [ "$got" = "$case_" ]; then verdicts="$verdicts-"; else verdicts="$verdicts+"; fi
  done
  eq "the perl form replaces the first five cases and leaves the last four" \
     "$verdicts" "+++++----"

  # Scoping the edit to one line: a claim above a table of history.
  printf '# Roadmap\n\n> **Current version:** 0.4.2\n\n| 0.4.2 | shipped |\n| 0.4.1 | shipped |\n' \
    > "$sv/ROADMAP.md"
  perl -i -pe 's/(?<![0-9.])\Q0.4.2\E(?!\d)(?!\.\d)/0.5.0/g if /^> \*\*Current version:\*\*/' \
    "$sv/ROADMAP.md"

  eq "the header is updated" \
     "$(grep -c '^> \*\*Current version:\*\* 0\.5\.0$' "$sv/ROADMAP.md" | tr -d ' ')" "1"
  eq "and the shipped-releases rows keep their numbers" \
     "$(grep -c '^| 0\.4\.' "$sv/ROADMAP.md" | tr -d ' ')" "2"
fi

# ---------------------------------------------------------------------------
# "The change" answers about wherever you are standing, unless you name refs.
#   triage-test-failures, "Name what you are comparing against"; the same
#   measurement is what sync-version step 6 turns on.
# ---------------------------------------------------------------------------
echo
echo "one change, two diff forms, three states"

git init -q --bare "$sv/origin.git" || halt "git init --bare failed"
git init -q -b main "$sv/w"         || halt "git init failed"
cd "$sv/w"                          || halt "could not enter the fixture"
git config user.email checks@example.invalid
git config user.name  checks
mkdir src
echo committed > src/a.txt
git add src/a.txt; git commit -q -m init
git remote add origin "$sv/origin.git"
git push -q -u origin main || halt "push to the fixture remote failed"

echo modified  > src/a.txt
echo brand-new > src/new.txt

eq "uncommitted: the bare form sees it, the ref form does not" \
   "$(printf '%s/%s' "$([ -n "$(git diff --stat)" ] && echo sees || echo empty)" \
                     "$([ -n "$(git diff origin/main...HEAD)" ] && echo sees || echo empty)")" \
   "sees/empty"

# A detached baseline worktree, which is what this skill uses instead of stash.
base="$sv/base"
git worktree add -q --detach "$base" HEAD || halt "detached worktree add failed"

eq "the baseline holds the committed file, not your edit" \
   "$(cat "$base/src/a.txt")" "committed"

eq "and does not hold your untracked file" \
   "$([ -e "$base/src/new.txt" ] && echo present || echo absent)" "absent"

eq "control: your own tree still reports both" \
   "$(git status --porcelain -uall | wc -l | tr -d ' ')" "2"

git add -A && git commit -q -m change

eq "after committing: the bare form goes silent, the ref form answers" \
   "$(printf '%s/%s' "$([ -n "$(git diff --stat)" ] && echo sees || echo empty)" \
                     "$([ -n "$(git diff origin/main...HEAD)" ] && echo sees || echo empty)")" \
   "empty/sees"

git worktree add -q -b side "$sv/side" >/dev/null 2>&1 \
  || halt "git worktree add failed"

eq "from another worktree: the same, which is how a re-check reads agreement" \
   "$(printf '%s/%s' "$([ -n "$(git -C "$sv/side" diff --stat)" ] && echo sees || echo empty)" \
                     "$([ -n "$(git -C "$sv/side" diff origin/main...main)" ] && echo sees || echo empty)")" \
   "empty/sees"

# ---------------------------------------------------------------------------
# A plain grep over a diff counts context as though it were changed.
#   triage-test-failures, same section.
# ---------------------------------------------------------------------------
echo
echo "counting changed lines in a diff"

git checkout -q -b work
printf 'LINE one\nTARGET untouched\nLINE three\n' > f
git add f; git commit -q -m seed
git push -q -u origin work >/dev/null 2>&1 || halt "push of the work branch failed"

# An entry inserted directly above a line nobody touched.
printf 'LINE one\nINSERTED above\nTARGET untouched\nLINE three\n' > f
git add f; git commit -q -m insert

eq "a bare grep -c counts the untouched line as touched" \
   "$(git diff origin/work...HEAD -- f | grep -c TARGET | tr -d ' ')" "1"

eq "-U0 with a [^+-] guard reports it correctly as untouched" \
   "$(git diff -U0 origin/work...HEAD -- f | grep -E '^[+-][^+-]' | grep -c TARGET | tr -d ' ')" "0"

printf 'LINE one\nINSERTED above\nTARGET EDITED\nLINE three\n' > f
git add f; git commit -q -m edit

eq "control: and answers 2 when the line really is edited, one - and one +" \
   "$(git diff -U0 origin/work...HEAD -- f | grep -E '^[+-][^+-]' | grep -c TARGET | tr -d ' ')" "2"

cd / || exit 1

# ---------------------------------------------------------------------------
# Comparing failure sets rather than counts.
#   triage-test-failures, "Compare sets, never counts".
# ---------------------------------------------------------------------------
echo
echo "the three comm columns"

printf 'spec_a\nspec_b\nspec_c\n' > "$sv/baseline"
printf 'spec_b\nspec_c\nspec_d\n' > "$sv/current"

eq "comm -13 gives what fails only with your diff" \
   "$(comm -13 "$sv/baseline" "$sv/current" | tr '\n' ' ' | sed 's/ $//')" "spec_d"

eq "comm -12 gives what fails in both runs" \
   "$(comm -12 "$sv/baseline" "$sv/current" | tr '\n' ' ' | sed 's/ $//')" "spec_b spec_c"

eq "comm -23 gives what your diff fixed, the column nobody reads" \
   "$(comm -23 "$sv/baseline" "$sv/current" | tr '\n' ' ' | sed 's/ $//')" "spec_a"

eq "control: equal counts are not the same set" \
   "$(printf '%s/%s' "$(wc -l < "$sv/baseline" | tr -d ' ')" "$(wc -l < "$sv/current" | tr -d ' ')")" "3/3"

# ---------------------------------------------------------------------------
# A test count grepped from a human summary, and the two guards in front of it.
#   resolve-npm-deprecations, step 5.
# ---------------------------------------------------------------------------
echo
echo "taking a test count from printed output"

eq "the obvious pattern reads jest's summary" \
   "$(printf 'Tests:       3649 passed, 3649 total\n' | grep -oE '[0-9]+ passed')" \
   "3649 passed"

eq "and yields nothing for node --test" \
   "$(printf '# pass 3649\n' | grep -oE '[0-9]+ passed' | wc -c | tr -d ' ')" "0"

eq "and nothing for mocha, so both sides can measure nothing" \
   "$(printf '3649 passing (2s)\n' | grep -oE '[0-9]+ passed' | wc -c | tr -d ' ')" "0"

echo
echo "comparing the counts once you have them"

if [ 1000 \< 900 ]; then r=true; else r=false; fi
eq "a string comparison calls 1000 < 900 true" "$r" "true"

if [ 1000 -lt 900 ]; then r=true; else r=false; fi
eq "control: the numeric comparison does not" "$r" "false"

if ! command -v bash >/dev/null 2>&1; then
  skip "the empty-value coercion" "bash is not installed"
else
  eq "an empty count coerces to 0 and reports a regression from nothing" \
     "$(bash -c 'AFTER=""; BEFORE=3649; if (( AFTER < BEFORE )); then echo regression; else echo none; fi')" \
     "regression"
fi

for probe in "36493649 accepted" " refused" "36x9 refused"; do
  val=${probe% *}; want=${probe#* }
  case "$val" in ''|*[!0-9]*) got=refused ;; *) got=accepted ;; esac
  eq "the numeric guard: [$val] is $want" "$got" "$want"
done

# ---------------------------------------------------------------------------
# How a host answers, rebuilt on loopback.
#   verify-deploy-landed (a converting fetch path, cache headers) and
#   verify-pasted-url (a probe without a control case). The skills' own numbers
#   belong to third-party hosts and are not re-measured here; what is asserted
#   is the mechanism, against a server this check starts itself.
# ---------------------------------------------------------------------------
echo
echo "probing a server on loopback"

if ! command -v curl >/dev/null 2>&1; then
  skip "loopback probe claims" "curl is not installed"
elif ! command -v python3 >/dev/null 2>&1; then
  skip "loopback probe claims" "python3 is not installed, and the fixture is a server"
else
  http=$(mktemp -d) || halt "could not make a fixture directory"
  keep "$http"
  cat > "$http/server.py" <<'PYSERVER'
import sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer

# A marker carried only in attributes, beside the visible text it drives.
PAGE = (b'<!doctype html><html><body>'
        b'<form action="/submit-ZMARK"><input data-fs-success="ZMARK"></form>'
        b'<p>Your changes were saved.</p>'
        b'</body></html>')
CSS = b'.banner { content: "ZMARK"; }\n'

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, extra=()):
        self.send_response(code)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        for k, v in extra: self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)
    def do_GET(self):
        p = self.path
        if   p == '/loose/real':      self._send(200, b'x' * 4000)
        elif p == '/loose/invented':  self._send(200, b'x' * 1200)
        elif p == '/strict/real':     self._send(200, b'{"title":"real"}')
        elif p == '/strict/invented': self._send(400, b'Bad Request')
        elif p == '/cached':          self._send(200, b'body',
                                          (('Age', '42'), ('X-Cache', 'HIT'), ('ETag', '"v2"')))
        elif p == '/fresh':           self._send(200, b'body')
        elif p == '/page.html':       self._send(200, PAGE)
        elif p == '/asset.css':       self._send(200, CSS)
        else:                         self._send(404, b'nope')

srv = HTTPServer(('127.0.0.1', 0), H)
print(srv.server_address[1], flush=True)
srv.timeout = 1
deadline = time.time() + int(sys.argv[1])
while time.time() < deadline:
    srv.handle_request()
PYSERVER
  python3 "$http/server.py" 30 > "$http/port" 2>/dev/null & httppid=$!
  sleep 2
  port=''
  read -r port < "$http/port" 2>/dev/null || true

  if [ -z "$port" ]; then
    skip "loopback probe claims" "the fixture server did not come up"
  else
    base="http://127.0.0.1:$port"
    probe() { curl -s -o /dev/null -w '%{http_code} %{size_download}B' --max-time 5 "$1"; }

    # A host that answers 200 for an identifier that does not exist.
    eq "a lenient host answers 200 for an invented id, same as a real one" \
       "$(printf '%s|%s' "$(probe "$base/loose/real" | cut -d' ' -f1)" \
                         "$(probe "$base/loose/invented" | cut -d' ' -f1)")" "200|200"

    eq "so the status alone cannot discriminate, though the sizes differ" \
       "$([ "$(probe "$base/loose/real" | cut -d' ' -f2)" \
            != "$(probe "$base/loose/invented" | cut -d' ' -f2)" ] && echo differ || echo same)" "differ"

    eq "control: a strict endpoint does discriminate" \
       "$(printf '%s|%s' "$(probe "$base/strict/real" | cut -d' ' -f1)" \
                         "$(probe "$base/strict/invented" | cut -d' ' -f1)")" "200|400"

    eq "control: and a genuinely absent path is a 404" \
       "$(probe "$base/no-such-path" | cut -d' ' -f1)" "404"

    # The cache headers the skill tells you to read.
    eq "the documented header grep finds Age, X-Cache and ETag" \
       "$(curl -fsS -H 'Cache-Control: no-cache' "$base/cached" -o /dev/null -D - 2>/dev/null \
          | grep -icE '^(age|x-cache|cf-cache-status|etag):' | tr -d ' ')" "3"

    eq "control: and finds nothing on a response carrying none" \
       "$(curl -fsS "$base/fresh" -o /dev/null -D - 2>/dev/null \
          | grep -icE '^(age|x-cache|cf-cache-status|etag):' | tr -d ' ')" "0"

    # A converting fetch path, which is what a reader mode or scraper does.
    eq "control: the marker really is in the raw response" \
       "$(curl -fsS "$base/page.html" 2>/dev/null | grep -c ZMARK | tr -d ' ')" "1"

    if ! command -v lynx >/dev/null 2>&1; then
      skip "the converting fetch path" "lynx is not installed"
    else
      eq "a converting fetch drops it, so the probe reports a deploy that landed" \
         "$(lynx -dump "$base/page.html" 2>/dev/null | grep -c ZMARK | tr -d ' ')" "0"

      eq "while the visible text it drives still renders — the ambiguity" \
         "$(lynx -dump "$base/page.html" 2>/dev/null | grep -c 'changes were saved' | tr -d ' ')" "1"

      eq "a plain-text asset survives the same round trip, which is why to prefer one" \
         "$(lynx -dump "$base/asset.css" 2>/dev/null | grep -c ZMARK | tr -d ' ')" "1"
    fi
  fi
  kill "$httppid" 2>/dev/null
  wait "$httppid" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# Two forms of one version, and a guard that reads one of seven locations.
#   update-url-dependency, steps 2 and 3.
# ---------------------------------------------------------------------------
echo
echo "the same release written two ways"

TAGFORM="v0.13.1-alpha"
eq "stripping the v gives the bare semver jsDelivr writes" "${TAGFORM#v}" "0.13.1-alpha"

uu=$(mktemp -d) || halt "could not make a fixture directory"
keep "$uu"

# Replacing the tag form misses the CDN import.
printf 'tag: v0.13.1-alpha\ncdn: lib@0.13.1-alpha/x.js\n' > "$uu/f"
sed -i "s|v0.13.1-alpha|v0.14.0|g" "$uu/f"
eq "replacing the tag form leaves the CDN import behind" \
   "$(grep -c '0\.13\.1-alpha' "$uu/f" | tr -d ' ')" "1"

# Replacing the bare form with the tag form corrupts the tag.
printf 'tag: v0.13.1-alpha\ncdn: lib@0.13.1-alpha/x.js\n' > "$uu/f"
sed -i "s|0.13.1-alpha|v0.14.0|g" "$uu/f"
eq "and replacing the bare form with the tag form yields vv" \
   "$(grep -c 'vv0\.14\.0' "$uu/f" | tr -d ' ')" "1"

echo
echo "an early-exit guard reading one location of several"

git init -q -b main "$uu/repo" || halt "git init failed"
cd "$uu/repo"                  || halt "could not enter the fixture"
git config user.email checks@example.invalid
git config user.name  checks
# A half-finished update: the manifest is current, a second location is not.
printf '{"dep":"0.14.0"}\n'          > manifest.json
printf 'cdn: lib@0.13.1-alpha/x.js\n' > README.md
git add -A && git commit -q -m seed

eq "a guard reading only the manifest reports already up to date" \
   "$(grep -c '0\.14\.0' manifest.json | tr -d ' ')" "1"

eq "while a second location still carries the old version" \
   "$(grep -c '0\.13\.1-alpha' README.md | tr -d ' ')" "1"

eq "the disagreement check over the whole inventory finds two versions" \
   "$(git grep -ohE 'v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?' -- manifest.json README.md \
      | sed -E 's/^v//; s/(\.(tar|tgz|zip|gz))+$//' | sort -u | wc -l | tr -d ' ')" "2"

cd / || exit 1

# ---------------------------------------------------------------------------
# Workflow shell, and the guard that refuses the commit it is asked to redeploy.
#   verify-workflow-shell, "What this actually catches".
# ---------------------------------------------------------------------------
echo
echo "a deploy guard built on is-ancestor"

wf=$(mktemp -d) || halt "could not make a fixture directory"
keep "$wf"
git init -q -b main "$wf/r" || halt "git init failed"
cd "$wf/r"                  || halt "could not enter the fixture"
git config user.email checks@example.invalid
git config user.name  checks
git commit -q --allow-empty -m one; live=$(git rev-parse HEAD)
git commit -q --allow-empty -m two; ahead=$(git rev-parse HEAD)

git merge-base --is-ancestor "$live" "$live"
eq "is-ancestor X X is true, so a guard refusing ancestors refuses a redeploy" "$?" "0"

git merge-base --is-ancestor "$live" "$ahead"
eq "control: an older commit is an ancestor of a newer one" "$?" "0"

git merge-base --is-ancestor "$ahead" "$live"
eq "control: and a newer commit is not an ancestor of an older one" "$?" "1"

cd / || exit 1

# The extraction this skill insists on: the bytes under test come out of the
# committed YAML rather than a retyped copy. Run against this repository's own
# workflow, so renaming the script in one place and not the other is caught.
if ! command -v python3 >/dev/null 2>&1; then
  skip "the workflow extraction" "python3 is not installed"
elif ! python3 -c 'import yaml' 2>/dev/null; then
  skip "the workflow extraction" "PyYAML is not installed"
elif [ ! -f "$root/.github/workflows/checks.yml" ]; then
  skip "the workflow extraction" "no workflow file to extract from"
else
  eq "the shipped run: block is what invokes the checks" \
     "$(python3 - "$root/.github/workflows/checks.yml" <<'EXTRACT'
import io, sys, yaml
d = yaml.safe_load(io.open(sys.argv[1], encoding='utf-8'))
step = [x for x in d['jobs']['checks']['steps'] if 'run' in x][0]
print('yes' if 'checks/run' in step['run'] else 'no')
EXTRACT
)" "yes"
fi

echo
[ "$skips" -gt 0 ] && printf '%s claims skipped for want of an optional tool or shell feature\n' "$skips"
if [ "$fails" -eq 0 ]; then
  printf '%s claims re-measured, all hold\n' "$checked"
  exit 0
fi
printf '%s of %s claims no longer hold\n' "$fails" "$checked"
exit 1
