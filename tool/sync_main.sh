#!/usr/bin/env bash
# Fast-forwards the main checkout (~/dev/wargame, not a worktree) to
# origin/main. Sessions work in worktrees and push from there, so the
# checkout the user opens in the editor stayed behind and showed old files,
# such as the TestFlight text of the last release. Run by /ship after every
# push and by tool/finish_worktree.sh.
#
# Only a fast-forward on a clean `main`: another branch, local changes or
# local commits are the user's and stay untouched, with a note why.

set -uo pipefail

common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  echo "not inside a git checkout" >&2
  exit 2
}
main_dir=$(dirname "$common")

git -C "$main_dir" fetch -q origin main || { echo "sync: fetch failed, main checkout left as it is" >&2; exit 0; }

branch=$(git -C "$main_dir" branch --show-current)
if [ "$branch" != main ]; then
  echo "sync: main checkout is on '${branch:-detached HEAD}', left as it is"
  exit 0
fi
if [ -n "$(git -C "$main_dir" status --porcelain --untracked-files=no)" ]; then
  echo "sync: main checkout has local changes, left as it is"
  exit 0
fi
if ! git -C "$main_dir" merge-base --is-ancestor HEAD origin/main; then
  echo "sync: main checkout has commits not on origin/main, left as it is"
  exit 0
fi

before=$(git -C "$main_dir" rev-parse --short HEAD)
git -C "$main_dir" merge -q --ff-only origin/main || exit 1
after=$(git -C "$main_dir" rev-parse --short HEAD)
if [ "$before" = "$after" ]; then
  echo "sync: main checkout already at $after"
else
  echo "sync: main checkout $before -> $after"
fi
