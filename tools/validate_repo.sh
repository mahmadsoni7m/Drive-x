#!/usr/bin/env bash
# Non-destructive repository sanity check. Exits non-zero if something required is missing.
set -u
fail=0
need() { if [ ! -e "$1" ]; then echo "MISSING: $1"; fail=1; fi; }
for f in project.godot export_presets.cfg icon.svg scenes/Main.tscn scenes/Game.tscn \
  content/index.json content/locale/tg.json \
  scripts/autoload/GameData.gd scripts/autoload/AudioManager.gd scripts/core/Content.gd scripts/core/Lang.gd \
  scripts/car/Vehicle.gd scripts/person/Person.gd scripts/person/HumanBuilder.gd scripts/world/WorldBuilder.gd \
  scripts/game/Game.gd scripts/game/HUD.gd scripts/ui/Main.gd tools/self_test.gd; do need "$f"; done
grep -q 'config/features=PackedStringArray("4.3"' project.godot || { echo "project.godot is not pinned to Godot 4.3"; fail=1; }
grep -q 'name="Android Debug"' export_presets.cfg || { echo "preset 'Android Debug' missing"; fail=1; }
grep -q 'include_filter="content/\*"' export_presets.cfg || { echo "export preset must include content/* (JSON data)"; fail=1; }
# every id listed in content/index.json must have its JSON file
for kind in cars outfits characters races; do
  ids=$(tr -d '\n ' < content/index.json | sed -n "s/.*\"$kind\":\[\([^]]*\)\].*/\1/p" | tr -d '"' | tr ',' ' ')
  for id in $ids; do need "content/$kind/$id.json"; done
done
if grep -rIl -P "\t" scripts tools/self_test.gd >/dev/null 2>&1; then echo "WARNING: tab characters in GDScript (spaces expected)"; fi
# duplicate global class names (typical after copying v2 over the old v1 project)
dups=$(grep -rHE "^class_name " --include=*.gd scripts 2>/dev/null | sed -E 's/^([^:]+):class_name ([A-Za-z0-9_]+).*/\2 \1/' | sort | awk '{c[$1]++; f[$1]=f[$1]" "$2} END {for (k in c) if (c[k]>1) print k":"f[k]}')
if [ -n "$dups" ]; then echo "DUPLICATE class_name found (run: bash tools/migrate_from_v1.sh):"; echo "$dups"; fail=1; fi
[ "$fail" -eq 0 ] && echo "validate_repo: OK"
exit "$fail"
