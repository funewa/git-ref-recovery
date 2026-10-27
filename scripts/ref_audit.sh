#!/usr/bin/env bash
# Read-only Git ref audit. Never pushes, merges, resets, or runs GC.
#
# Usage: bash ref_audit.sh <refA> <refB>
#
# RefA is conventionally the remote tip, RefB the local candidate.
# Prints:
#   1. full ref snapshot
#   2. both directions of the ancestor test
#   3. commits RefB has that RefA lacks
#   4. files that differ between them, with a reverted-fix scan
#
# Exit codes: 0 ok, 2 usage error, 3 not in a repository.

set -u

if [ "$#" -ne 2 ]; then
  echo "usage: bash ref_audit.sh <refA> <refB>" >&2
  exit 2
fi

A="$1"
B="$2"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not inside a git repository" >&2
  exit 3
fi

echo "=============================================="
echo "1. REF SNAPSHOT"
echo "=============================================="
echo "HEAD            : $(git rev-parse HEAD 2>&1)"
echo "current branch  : $(git rev-parse --abbrev-ref HEAD 2>&1)"
echo "A ($A) resolves : $(git rev-parse --verify "${A}^{commit}" 2>&1 | tail -1)"
echo "B ($B) resolves : $(git rev-parse --verify "${B}^{commit}" 2>&1 | tail -1)"
echo
echo "--- local branches ---"
git for-each-ref --format='%(refname:short) %(objectname:short)' refs/heads
echo
echo "--- remote-tracking refs (may be a stale cache; run git fetch to refresh) ---"
git for-each-ref --format='%(refname:short) %(objectname:short)' refs/remotes/origin

echo
echo "=============================================="
echo "2. ANCESTOR TEST (both directions)"
echo "=============================================="
# Read as: "is the left commit contained in the right commit's history?"
if git merge-base --is-ancestor "$A" "$B" 2>/dev/null; then
  echo "A is ancestor of B      : YES"
  echo "  -> B already extends A. Pushing B to A's branch is a no-op."
else
  echo "A is ancestor of B      : NO"
fi

if git merge-base --is-ancestor "$B" "$A" 2>/dev/null; then
  echo "B is ancestor of A      : YES"
  echo "  -> A was rewound. Pushing B to A's branch is a FAST-FORWARD restoring history."
  echo "  -> Divergence verdict: NOT diverged; B is simply newer."
else
  echo "B is ancestor of A      : NO"
  echo "  -> Divergence verdict: GENUINE DIVERGENCE. A merge decision is required."
  echo "  -> Apply the reverted-fix check in section 4 before merging."
fi

echo
echo "merge base              : $(git merge-base "$A" "$B" 2>&1 | tail -1)"

echo
echo "=============================================="
echo "3. COMMITS B HAS THAT A LACKS"
echo "=============================================="
git log --oneline "${A}..${B}" 2>&1

echo
echo "--- reverse: commits A has that B lacks ---"
git log --oneline "${B}..${A}" 2>&1

echo
echo "=============================================="
echo "4. DIFFERING FILES + REVERTED-FIX SCAN"
echo "=============================================="
git diff "$A" "$B" --name-status 2>&1

echo
echo "--- reverted-fix scan (looking for removals of safety/version markers) ---"
# A removal of any of these on the B side means B is partly a rollback of A.
SUSPECT='^\-.*(no-store|Cache-Control|Authorization|X-AITOP-Key|rateLimit|Vary:)'
VERSIONY='^[-+].*"version"[[:space:]]*:'

FILES=$(git diff "$A" "$B" --name-only 2>/dev/null)
FOUND=0
for f in $FILES; do
  case "$f" in
    *.go|*.ts|*.tsx|*.js|*.jsx|*.py|*.json|*.yml|*.yaml|*.md|*.sql)
      HITS=$(git diff "$A" "$B" -- "$f" 2>/dev/null | grep -E "$SUSPECT" 2>/dev/null)
      if [ -n "$HITS" ]; then
        echo "  [removal] $f"
        echo "$HITS" | sed 's/^/      /'
        FOUND=1
      fi
      VHITS=$(git diff "$A" "$B" -- "$f" 2>/dev/null | grep -E "$VERSIONY" 2>/dev/null)
      if [ -n "$VHITS" ]; then
        echo "  [version] $f"
        echo "$VHITS" | sed 's/^/      /'
        FOUND=1
      fi
      ;;
  esac
done

if [ "$FOUND" -eq 0 ]; then
  echo "  none detected — but inspect any version-number and changelog diffs by hand"
fi

echo
echo "=============================================="
echo "DONE (read-only; nothing was modified)"
echo "=============================================="
