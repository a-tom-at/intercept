#!/usr/bin/env bash
# update-from-upstream.sh
# Syncs intercept with smittix/intercept upstream while preserving SDRPlay RSP1B patches.
#
# Usage: ./update-from-upstream.sh
# If a rebase conflict occurs, see SDRPLAY_OVERLAY.md for what to preserve.

set -euo pipefail

UPSTREAM_REMOTE="upstream"
FORK_REMOTE="origin"
PATCH_BRANCH="sdrplay-rsp1b"
MAIN_BRANCH="main"

echo "==> Fetching upstream (smittix/intercept)..."
git fetch "$UPSTREAM_REMOTE"

UPSTREAM_NEW=$(git log HEAD..${UPSTREAM_REMOTE}/${MAIN_BRANCH} --oneline | wc -l | tr -d ' ')
if [ "$UPSTREAM_NEW" -eq 0 ]; then
    echo "    Already up to date with upstream. Nothing to merge."
else
    echo "    ${UPSTREAM_NEW} new commit(s) from upstream:"
    git log HEAD..${UPSTREAM_REMOTE}/${MAIN_BRANCH} --oneline
fi

echo ""
echo "==> Merging upstream into $MAIN_BRANCH..."
git checkout "$MAIN_BRANCH"
git merge "$UPSTREAM_REMOTE/$MAIN_BRANCH" --no-edit

echo ""
echo "==> Rebasing $PATCH_BRANCH on updated $MAIN_BRANCH..."
echo "    (If conflicts appear, see SDRPLAY_OVERLAY.md for what to preserve)"
git checkout "$PATCH_BRANCH"
git rebase "$MAIN_BRANCH"

echo ""
echo "==> Merging patches back into $MAIN_BRANCH..."
git checkout "$MAIN_BRANCH"
git merge "$PATCH_BRANCH" --no-edit

echo ""
echo "==> Pushing to fork (origin = a-tom-at/intercept)..."
git push "$FORK_REMOTE" "$MAIN_BRANCH"
git push "$FORK_REMOTE" "$PATCH_BRANCH" --force-with-lease

echo ""
echo "✅ Done."
echo ""
echo "   Test with: sudo -E python intercept.py"
echo "   If any patch broke:  see SDRPLAY_OVERLAY.md for the checklist"
