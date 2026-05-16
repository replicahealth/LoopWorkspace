#!/bin/bash
#
# Commit changes in every submodule with the supplied message, then commit
# the resulting submodule pointer updates here in the workspace.
#
# Usage:
#   ./commit-all.sh "your commit message"
#
# Notes:
# - Quote the message; only the first argument is used.
# - Each submodule is committed independently using `git add -A` in that
#   submodule, picking up modifications, deletions, and untracked files.
# - Submodules with no changes are skipped.
# - After all submodules commit, this workspace commits the updated submodule
#   pointers (and any other workspace-level changes).
# - Does not push. Run `git push --recurse-submodules=on-demand` afterwards
#   to publish, or push each submodule explicitly first then the workspace.

set -euo pipefail

MSG="${1:-}"
if [ -z "$MSG" ]; then
    echo "usage: $0 \"commit message\"" >&2
    exit 1
fi

cd "$(dirname "$0")"

# Make the commit message visible inside `git submodule foreach`'s subshell.
export MSG

git submodule foreach --quiet '
    if [ -n "$(git status --porcelain)" ]; then
        echo "→ $displaypath: committing"
        git add -A
        git commit -m "$MSG"
    fi
'

if [ -n "$(git status --porcelain)" ]; then
    echo "→ workspace: committing submodule pointer updates"
    git add -A
    git commit -m "$MSG"
else
    echo "→ workspace: nothing to commit"
fi
