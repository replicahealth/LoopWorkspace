#!/bin/bash
#
# Commit and push changes in every submodule with the supplied message,
# then commit and push the resulting submodule pointer updates in this
# workspace.
#
# Safety: only pushes to remotes owned by ReplicaHealth (origin URL
# contains `/replicahealth/` or `:replicahealth/`, case-insensitive).
# Submodules pointing at upstream community forks are committed locally
# but their commits are NOT pushed.
#
# Usage:
#   ./commit-all.sh "your commit message"
#
# Notes:
# - Quote the message; only the first argument is used.
# - Each submodule is committed independently with `git add -A`, picking
#   up modifications, deletions, and untracked files.
# - Submodules with no changes are skipped silently.
# - After committing, each submodule on a named branch is pushed (with
#   automatic upstream setup via `git push -u` on first push) — but only
#   if its origin is owned by ReplicaHealth.
# - Submodules in a detached-HEAD state are still skipped on push (no
#   branch to push to).

set -euo pipefail

MSG="${1:-}"
if [ -z "$MSG" ]; then
    echo "usage: $0 \"commit message\"" >&2
    exit 1
fi

cd "$(dirname "$0")"

# Pattern that identifies a ReplicaHealth-owned origin URL. Examples that
# match:  git@github.com:replicahealth/Loop.git
#         https://github.com/replicahealth/LoopKit.git
# Examples that don't match:  https://github.com/LoopKit/LoopKit.git
ALLOWED_OWNER_PATTERN='[/:]replicahealth/'

# Make these visible inside `git submodule foreach`'s subshell.
export MSG
export ALLOWED_OWNER_PATTERN

# ─── 1. Commit changes in every dirty submodule ───────────────────────────
git submodule foreach --quiet '
    if [ -n "$(git status --porcelain)" ]; then
        echo "→ $displaypath: committing"
        git add -A
        git commit -m "$MSG"
    fi
'

# ─── 2. Commit workspace-level changes (incl. submodule pointer updates) ──
if [ -n "$(git status --porcelain)" ]; then
    echo "→ workspace: committing"
    git add -A
    git commit -m "$MSG"
else
    echo "→ workspace: nothing to commit"
fi

# ─── 3. Push each submodule whose origin is owned by ReplicaHealth ────────
# If the current branch has no upstream yet, push with `-u` to create one
# (e.g. first push of a freshly-created feature branch).
git submodule foreach --quiet '
    url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if ! echo "$url" | grep -iqE "$ALLOWED_OWNER_PATTERN"; then
        echo "⚠ $displaypath: skipping push (origin not owned by ReplicaHealth: $url)"
    else
        branch=$(git branch --show-current)
        if [ -z "$branch" ]; then
            echo "⚠ $displaypath: detached HEAD — skipping push"
        elif git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
            if [ -n "$(git log "@{u}.." --oneline 2>/dev/null)" ]; then
                echo "→ $displaypath: pushing $branch to $url"
                git push
            fi
        else
            echo "→ $displaypath: first push of $branch to $url (setting upstream)"
            git push -u origin "$branch"
        fi
    fi
'

# ─── 4. Push the workspace if its origin is owned by ReplicaHealth ────────
workspace_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
if ! echo "$workspace_url" | grep -iqE "$ALLOWED_OWNER_PATTERN"; then
    echo "⚠ workspace: skipping push (origin not owned by ReplicaHealth: $workspace_url)"
else
    workspace_branch=$(git branch --show-current)
    if [ -z "$workspace_branch" ]; then
        echo "⚠ workspace: detached HEAD — skipping push"
    elif git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
        if [ -n "$(git log "@{u}.." --oneline 2>/dev/null)" ]; then
            echo "→ workspace: pushing $workspace_branch to $workspace_url"
            git push
        else
            echo "→ workspace: nothing to push"
        fi
    else
        echo "→ workspace: first push of $workspace_branch to $workspace_url (setting upstream)"
        git push -u origin "$workspace_branch"
    fi
fi
