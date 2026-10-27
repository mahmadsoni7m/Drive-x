# DRIVE X

3D arcade racing for Android. Godot **4.3** (GL Compatibility) + GDScript. Blender script for optional car models. GitHub Actions builds the APK.

## Structure
```
project.godot  export_presets.cfg  icon.svg
.github/workflows/android.yml      CI: validate -> import -> self-test -> export -> verify APK
scenes/        Main.tscn (menus), Race.tscn (race)
scripts/
  autoload/    GameData (save/coins/upgrades/settings), AudioManager (synthesized audio)
  data/        CarData (5 cars, upgrades), TrackData (3 tracks, themes)
  car/         Vehicle (physics, drift, nitro, FX), CarBuilder (procedural or .glb)
  track/       TrackBuilder (road, curbs, walls, scenery, pickups, sky), TrackInfo
  race/        Race, AIDriver, CameraRig (4 modes), HUD, TouchButton, MiniMap
  ui/          Main, Menu/Track/Garage/Settings screens, Showroom, UIKit
tools/         self_test.gd, validate_repo.sh, safe_update.sh, blender/generate_cars.py
```

## Controls
Touch: left/right arrows, GAS, BRAKE, NITRO, DRIFT (handbrake), CAM, RST (reset), II (pause).
Keyboard: arrows/WASD, Shift nitro, Space drift, C camera, R reset, Esc pause.

## Build
Push to `main` (or run the workflow manually). Artifacts: `DRIVE-X-debug-apk` and `DRIVE-X-build-logs`.
Local: `godot --headless --path . --import && godot --headless --path . --script res://tools/self_test.gd`.

## Updating safely
Run `tools/safe_update.sh` first (status + non-destructive snapshot into `.backups/`). Add features as new files. Save data lives in `user://` on the device and is never touched by updates (atomic save + backup file).

## Recovery
- Import errors: open `logs/import.log` artifact; fix the named script.
- Export error: `logs/export.log`; typical causes are missing Android SDK/templates (the workflow prints which).
- Corrupt save: the game auto-restores `drivex_save.bak.json`.
- Bad commit: `git revert <sha>`; nothing in the workflow deletes files.

## Models
Procedural cars work out of the box. For Blender models: `blender -b -P tools/blender/generate_cars.py -- assets/models`; the game uses `assets/models/<id>.glb` automatically when present.

## Known limitations (not verified)
- The APK has NOT been built or run by the author's sandbox (no Godot/Blender there); the first CI run is the real test.
- Debug-signed APK only. Release signing needs your own keystore via GitHub secrets.
- Tilt steering axis/sign is untested on hardware (INVERT TILT setting provided).
- Physics are arcade-realistic, not a full simulation; no online play; audio is synthesized.
