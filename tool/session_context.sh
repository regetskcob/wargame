#!/usr/bin/env bash
# Prints a short orientation for a new Claude Code session: where this
# checkout stands against main, what landed recently and the newest
# migration. Run by the SessionStart hook in .claude/settings.json; it only
# reads, and stays quiet about anything it cannot find.

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
echo "## Panzergefecht – Sitzungskontext"
echo "Branch: $branch"

if git rev-parse --verify -q origin/main >/dev/null; then
  read -r behind ahead < <(git rev-list --left-right --count origin/main...HEAD)
  echo "Gegenüber origin/main: $ahead voraus, $behind zurück (Stand des letzten fetch)"
fi

dirty=$(git status --porcelain | wc -l | tr -d ' ')
[ "$dirty" != "0" ] && echo "Uncommittete Änderungen: $dirty Dateien"

echo
echo "Letzte Commits auf origin/main:"
git log --no-merges --format='- %h %ad %s' --date=short -8 origin/main 2>/dev/null

latest=$(ls supabase/migrations 2>/dev/null | sort | tail -1)
[ -n "$latest" ] && echo && echo "Neueste Migration: $latest"

version=$(grep -m1 '^version:' pubspec.yaml 2>/dev/null | cut -d' ' -f2)
[ -n "$version" ] && echo "App-Version: $version"

# Finished sessions are meant to remove their worktree (/ship, step 8);
# point out when too many are left over.
count=$(find .claude/worktrees -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -gt 8 ] && echo && echo "$count Worktrees liegen unter .claude/worktrees: tool/finish_worktree.sh --all --dry-run zeigt, welche weg können"

exit 0
