#!/usr/bin/env bash
# Non-destructive repository sanity check. Exits non-zero if required files are missing.
set -u
fail=0
need() { if [ ! -e "$1" ]; then echo "MISSING: $1"; fail=1; fi; }
for f in project.godot export_presets.cfg icon.svg scenes/Main.tscn scenes/Race.tscn \
  scripts/autoload/GameData.gd scripts/autoload/AudioManager.gd scripts/data/CarData.gd \
  scripts/data/TrackData.gd scripts/car/Vehicle.gd scripts/car/CarBuilder.gd \
  scripts/track/TrackBuilder.gd scripts/track/TrackInfo.gd scripts/race/Race.gd \
  scripts/race/HUD.gd scripts/ui/Main.gd tools/self_test.gd; do need "$f"; done
grep -q 'config/features=PackedStringArray("4.3"' project.godot || { echo "project.godot is not pinned to Godot 4.3"; fail=1; }
grep -q 'platform="Android"' export_presets.cfg || { echo "export_presets.cfg has no Android preset"; fail=1; }
grep -q 'name="Android Debug"' export_presets.cfg || { echo "preset 'Android Debug' missing"; fail=1; }
if grep -rIl -P "\t" scripts tools/self_test.gd >/dev/null 2>&1; then echo "WARNING: tab characters found in GDScript (spaces expected)"; fi
[ "$fail" -eq 0 ] && echo "validate_repo: OK"
exit "$fail"
