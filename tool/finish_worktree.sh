#!/usr/bin/env bash
# Removes finished app-made worktrees under .claude/worktrees, so shipped
# sessions stop holding gigabytes of Flutter, Xcode and Gradle builds.
#
#   tool/finish_worktree.sh            the worktree this is run from
#   tool/finish_worktree.sh --all      every finished one (from anywhere)
#   tool/finish_worktree.sh --dry-run  [--all] only list what would go
#
# A worktree counts as finished when nothing would be lost: no uncommitted
# or untracked files, HEAD contained in origin/main, the branch moved at
# least once (a fresh session's branch has not, and looks merged too) and,
# with --all, it was not used within the last 12 hours. Its merged branch,
# its Xcode DerivedData and the Claude scratchpad of its session go with
# it. Run by /ship and /release as their last step; the session's working
# directory and scratchpad are gone afterwards.

set -uo pipefail

all=false
dry=false
for arg in "$@"; do
  case "$arg" in
    --all) all=true ;;
    --dry-run) dry=true ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  echo "not inside a git checkout" >&2
  exit 2
}
main_dir=$(dirname "$common")
worktrees_dir="$main_dir/.claude/worktrees"
derived="$HOME/Library/Developer/Xcode/DerivedData"
# Claude Code keeps a scratchpad per working directory, named after the path
# with "/" and "." turned into "-".
scratch_root="/private/tmp/claude-$(id -u)"

git -C "$main_dir" fetch -q origin main || echo "fetch failed, using the last known origin/main" >&2

# Why a worktree must stay, or nothing when it may go.
blocker() {
  local w=$1
  local branch
  branch=$(git -C "$w" branch --show-current)
  [ -n "$(git -C "$w" status --porcelain)" ] && { echo "uncommitted changes"; return; }
  [ "$(git -C "$w" rev-list --count origin/main..HEAD)" != 0 ] && { echo "commits not on origin/main"; return; }
  if [ -n "$branch" ] && [ "$(git -C "$main_dir" reflog show --format=%h "refs/heads/$branch" 2>/dev/null | wc -l)" -le 1 ]; then
    echo "branch never moved (fresh session?)"
    return
  fi
  # A session between two commands leaves no process behind, so --all
  # goes by the last git activity (status, commit, merge touch the index
  # or HEAD log) and spares anything used within the last 12 hours.
  if $all; then
    local gitdir newest=0 t
    gitdir=$(git -C "$w" rev-parse --absolute-git-dir)
    for f in "$gitdir/index" "$gitdir/logs/HEAD" "$gitdir/HEAD"; do
      t=$(stat -f %m "$f" 2>/dev/null || echo 0)
      [ "$t" -gt "$newest" ] && newest=$t
    done
    [ $(($(date +%s) - newest)) -lt $((12 * 3600)) ] && { echo "used within the last 12 hours"; return; }
  fi
}

finish() {
  local w=$1
  local branch reason size
  branch=$(git -C "$w" branch --show-current)
  reason=$(blocker "$w")
  if [ -n "$reason" ]; then
    echo "keep  $(basename "$w"): $reason"
    return 1
  fi
  size=$(du -sh "$w" 2>/dev/null | cut -f1)
  if $dry; then
    echo "would remove $(basename "$w") ($size)"
    return 0
  fi
  # Xcode keeps its builds outside the worktree, keyed by workspace path.
  for d in "$derived"/*/; do
    p=$(/usr/libexec/PlistBuddy -c 'Print :WorkspacePath' "$d/info.plist" 2>/dev/null) || continue
    case "$p" in "$w"/*) rm -rf "$d" ;; esac
  done
  rm -rf "$scratch_root/$(printf '%s' "$w" | tr '/.' '--')"
  # Ignored build output does not block a removal, untracked files were
  # ruled out above, so no --force is needed.
  git -C "$main_dir" worktree remove "$w" || return 1
  [ -n "$branch" ] && git -C "$main_dir" branch -D "$branch" >/dev/null 2>&1
  echo "removed $(basename "$w") ($size)"
}

if $all; then
  [ -d "$worktrees_dir" ] || exit 0
  for w in "$worktrees_dir"/*/; do
    w=${w%/}
    git -C "$w" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    finish "$w"
  done
  git -C "$main_dir" worktree prune
  exit 0
fi

here=$(git rev-parse --show-toplevel)
case "$here" in
  "$worktrees_dir"/*) ;;
  *) echo "not in an app-made worktree ($here), nothing to remove"; exit 0 ;;
esac
cd "$main_dir" || exit 1
finish "$here"
