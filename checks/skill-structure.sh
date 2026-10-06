#!/bin/sh
# Enforces the conventions in README.md across every skill directory:
# frontmatter that parses, a name matching the directory, a description that
# exists and fits, and code fences that close.
#
# Directories without a SKILL.md are not skills and are skipped — the install
# loop in README.md skips them on the same test.

set -u
cd "$(dirname "$0")/.." || exit 1

NAME_MAX=64
DESC_MAX=1024

fails=0
skills=0
skipped=''

bad() { fails=$((fails+1)); printf '  %-26s %s\n' "$1" "$2"; }

for d in */; do
  n=${d%/}
  if [ ! -f "$n/SKILL.md" ]; then
    skipped="$skipped $n"
    continue
  fi
  skills=$((skills+1))
  f="$n/SKILL.md"

  # Parse the frontmatter block, folding YAML block scalars into one line.
  parsed=$(awk '
    NR == 1 { if ($0 != "---") { print "ERR\tno opening --- on line 1"; exit } ; next }
    !closed && /^---[[:space:]]*$/ { closed = 1; next }
    !closed {
      if (/^[A-Za-z0-9_-]+:/) {
        k = $0; sub(/:.*/, "", k); cur = k
        v = $0; sub(/^[A-Za-z0-9_-]+:[[:space:]]*/, "", v)
        if (v == ">" || v == "|" || v == ">-" || v == "|-") v = ""
        val[cur] = v
        seen[cur]++
      } else if (cur != "" && $0 ~ /[^[:space:]]/) {
        line = $0; sub(/^[[:space:]]+/, "", line)
        val[cur] = val[cur] (val[cur] == "" ? "" : " ") line
      }
    }
    END {
      if (!closed) { print "ERR\tfrontmatter is never closed"; exit }
      printf "NAME\t%s\n", val["name"]
      printf "DESC\t%s\n", val["description"]
      printf "DUP\t%d %d\n", seen["name"], seen["description"]
    }
  ' "$f")

  case $parsed in
    ERR*) bad "$n" "$(printf '%s' "$parsed" | cut -f2-)"; continue ;;
  esac

  name=$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="NAME"{print $2}')
  desc=$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="DESC"{print $2}')
  dup=$(printf  '%s\n' "$parsed" | awk -F'\t' '$1=="DUP"{print $2}')

  # Only an outright repeat is reported here; a missing key gets its own line.
  for pair in "name ${dup% *}" "description ${dup#* }"; do
    k=${pair% *}; c=${pair#* }
    [ "$c" -gt 1 ] && bad "$n" "$k appears $c times in the frontmatter"
  done

  if [ -z "$name" ]; then
    bad "$n" "no name in the frontmatter"
  elif [ "$name" != "$n" ]; then
    bad "$n" "name is '$name' but the directory is '$n'"
  elif [ "${#name}" -gt "$NAME_MAX" ]; then
    bad "$n" "name is ${#name} chars, over $NAME_MAX"
  fi

  if [ -z "$desc" ]; then
    bad "$n" "no description in the frontmatter"
  elif [ "${#desc}" -gt "$DESC_MAX" ]; then
    bad "$n" "description is ${#desc} chars, over $DESC_MAX"
  fi

  fences=$(grep -c '^```' "$f")
  [ $((fences % 2)) -eq 0 ] || bad "$n" "$fences code-fence lines — one does not close"
done

echo
if [ "$fails" -eq 0 ]; then
  printf '%s skills, all well-formed\n' "$skills"
else
  printf '%s problems across %s skills\n' "$fails" "$skills"
fi
[ -n "$skipped" ] && printf 'not skills, skipped:%s\n' "$skipped"
[ "$fails" -eq 0 ] || exit 1
exit 0
