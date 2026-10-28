#!/usr/bin/env bash
# Safely retire the OLD v1 racing project files after copying v2 over the same repository.
# Nothing is deleted: old files are MOVED to legacy_v1/ (kept in git history) and hidden from
# Godot with a .gdignore file, so duplicate class names stop colliding. Safe to run repeatedly.
set -u
old=(
  scripts/data scripts/track scripts/race scripts/ui/TrackScreen.gd scenes/Race.tscn
  scripts/ui/TrackScreen.gd.uid scripts/car/Vehicle.gd.uid
)
moved=0
mkdir -p legacy_v1
for p in "${old[@]}"; do
  if [ -e "$p" ]; then
    mkdir -p "legacy_v1/$(dirname "$p")"
    if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then git mv -k "$p" "legacy_v1/$p" 2>/dev/null || mv "$p" "legacy_v1/$p"; else mv "$p" "legacy_v1/$p"; fi
    echo "moved $p -> legacy_v1/$p"; moved=$((moved+1))
  fi
done
touch legacy_v1/.gdignore
echo "migrate_from_v1: $moved item(s) moved (legacy_v1/ is ignored by Godot)"
