#!/usr/bin/env bash
# Run BEFORE applying any update. Inspects the repo and takes a non-destructive snapshot.
# Never deletes or rewrites project files.
set -eu
echo "== Repository status =="
git status --short || true
echo "== Branch =="; git rev-parse --abbrev-ref HEAD || true
if git status --porcelain | grep -q '^UU'; then echo "Unresolved merge conflicts - stop."; exit 1; fi
mkdir -p .backups
stamp="$(date +%Y%m%d-%H%M%S)"
tar --exclude=.git --exclude=.godot --exclude=.backups --exclude=build -czf ".backups/pre-update-$stamp.tar.gz" .
echo "Snapshot: .backups/pre-update-$stamp.tar.gz"
echo "Tip: apply changes as NEW files/modules; use 'git diff' to review minimal edits to existing ones."
echo "Player save data lives in user:// on the device and is never touched by project updates."
