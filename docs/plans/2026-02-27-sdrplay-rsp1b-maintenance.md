# SDRPlay RSP1B Maintenance Strategy

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the 9 RSP1B patches working across upstream updates, with a one-command update cycle and a personal GitHub fork as backup.

**Architecture:** A dedicated `sdrplay-rsp1b` branch holds all patches as commits. An `update-from-upstream.sh` script fetches upstream, rebases the patch branch, and pushes to the personal fork. `SDRPLAY_OVERLAY.md` documents each patch so future merge conflicts take minutes.

**Tech Stack:** Git (remotes, rebase), Bash script, GitHub fork (`a-tom-at/intercept`)

---

### Task 1: Rename folder + update settings ✅ DONE

Folder renamed from `intercept2.9` → `intercept`.
`.claude/settings.local.json` paths updated if needed.

---

### Task 2: Commit staged files + create patch branch

**Files:**
- Staged: `routes/adsb.py`, `routes/listening_post.py`, `static/js/modes/listening-post.js`, `templates/index.html`, `utils/sdr/__init__.py`, `utils/sdr/sdrplay.py`
- Untracked: `SDRPLAY_FIXES.md`

**Step 1: Stage SDRPLAY_FIXES.md**
```bash
git add SDRPLAY_FIXES.md
```

**Step 2: Commit everything**
```bash
git commit -m "feat: Add SDRPlay RSP1B support with 9 critical patches"
```

**Step 3: Create patch branch from this commit**
```bash
git checkout -b sdrplay-rsp1b
git checkout main
```

---

### Task 3: Create SDRPLAY_OVERLAY.md

**Files:**
- Create: `SDRPLAY_OVERLAY.md`

Document each of the 9 patches with: what file, what changed, why it's needed, what upstream conflict to watch for.

**The 9 patches:**
1. `utils/sdr/__init__.py` — SDRFactory registers `sdrplay` device type
2. `utils/sdr/sdrplay.py` — `SDRPlayCommandBuilder` with correct `--device sdrplay` flag
3. `utils/sdr/sdrplay.py` — IFGR gain inversion (`gain = 59 - value`)
4. `utils/sdr/sdrplay.py` — `--net-sbs-port=30003` flag for readsb ADS-B output
5. `utils/sdr/sdrplay.py` — WFM demodulation support via `--wfm` flag
6. `routes/listening_post.py` — SDRPlay scanner routing (device type check before spawning)
7. `routes/adsb.py` — SDRPlay path through readsb instead of dump1090
8. `static/js/modes/listening-post.js` — SDRPlay device option in UI dropdown
9. `templates/index.html` — SDRPlay entry in device selector

**Step 1: Write the file**

See content below — write `SDRPLAY_OVERLAY.md` with a section per patch.

**Step 2: Commit**
```bash
git add SDRPLAY_OVERLAY.md
git commit -m "docs: Add SDRPlay overlay guide for upstream merge conflicts"
```

---

### Task 4: Create update-from-upstream.sh

**Files:**
- Create: `update-from-upstream.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REMOTE="upstream"
FORK_REMOTE="origin"
PATCH_BRANCH="sdrplay-rsp1b"
MAIN_BRANCH="main"

echo "==> Fetching upstream..."
git fetch "$UPSTREAM_REMOTE"

echo "==> Merging upstream into $MAIN_BRANCH..."
git checkout "$MAIN_BRANCH"
git merge "$UPSTREAM_REMOTE/$MAIN_BRANCH" --no-edit

echo "==> Rebasing $PATCH_BRANCH on $MAIN_BRANCH..."
git checkout "$PATCH_BRANCH"
git rebase "$MAIN_BRANCH"

echo "==> Switching back to $MAIN_BRANCH and merging patches..."
git checkout "$MAIN_BRANCH"
git merge "$PATCH_BRANCH" --no-edit

echo "==> Pushing to fork..."
git push "$FORK_REMOTE" "$MAIN_BRANCH"
git push "$FORK_REMOTE" "$PATCH_BRANCH" --force-with-lease

echo ""
echo "✅ Done. Test with: sudo -E python intercept.py"
echo "   If conflicts occurred during rebase, see SDRPLAY_OVERLAY.md"
```

**Step 2: Make executable**
```bash
chmod +x update-from-upstream.sh
```

**Step 3: Commit**
```bash
git add update-from-upstream.sh
git commit -m "chore: Add upstream update script for SDRPlay maintenance"
```

---

### Task 5: Set up git remotes ✅ FORK EXISTS

Fork confirmed at: `https://github.com/a-tom-at/intercept.git`

**Step 1: Rename current origin → upstream**
```bash
git remote rename origin upstream
```

**Step 2: Add personal fork as origin**
```bash
git remote add origin https://github.com/a-tom-at/intercept.git
```

**Step 3: Verify**
```bash
git remote -v
# upstream  https://github.com/smittix/intercept.git
# origin    https://github.com/a-tom-at/intercept.git
```

**Step 4: Push main + patch branch to fork**
```bash
git push origin main
git push origin sdrplay-rsp1b
```

---

### Task 6: Dry-run verification

**Step 1: Run the update script in dry-run mode**
```bash
git fetch upstream
git log upstream/main..HEAD --oneline  # see what we're ahead by
```

**Step 2: Verify remotes**
```bash
git remote -v
git branch -a
```

**Step 3: Verify app starts**
```bash
sudo -E python intercept.py &
sleep 3
curl -s http://localhost:5000 | head -5
kill %1
```

---

## Future Update Cycle

```bash
./update-from-upstream.sh   # ~60 seconds
# If rebase conflict → check SDRPLAY_OVERLAY.md for the affected patch
sudo -E python intercept.py  # verify it works
```
