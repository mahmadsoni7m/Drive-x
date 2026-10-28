class_name Lang
extends RefCounted
## All player-visible text comes from res://content/locale/tg.json (Tajik, Cyrillic).
## Usage: Lang.t("menu.play"),  Lang.t("common.coins", [120]).  Missing keys show as "!key!".

const PATH := "res://content/locale/tg.json"

static var _tbl: Dictionary = {}
static var _loaded := false


static func _load() -> void:
    _loaded = true
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f == null:
        push_error("Lang: cannot open %s" % PATH)
        return
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if parsed is Dictionary:
        _tbl = parsed
    else:
        push_error("Lang: %s is not a valid JSON object" % PATH)


static func has(key: String) -> bool:
    if not _loaded:
        _load()
    return _tbl.has(key)


static func t(key: String, args: Array = []) -> String:
    if not _loaded:
        _load()
    if not _tbl.has(key):
        return "!%s!" % key
    var s := str(_tbl[key])
    if args.is_empty():
        return s
    return s % args
