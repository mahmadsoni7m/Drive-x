extends Node
## Persistent data: coins, garage, upgrades, wardrobe, settings, race records.
## Atomic saves (tmp -> rename) + rolling backup. Unknown keys are preserved; missing keys use defaults.

signal coins_changed(total: int)

const SAVE_PATH := "user://drivex2_save.json"
const BACKUP_PATH := "user://drivex2_save.bak.json"
const TMP_PATH := "user://drivex2_save.tmp.json"
const SAVE_VERSION := 2

var data: Dictionary = {}
var _dirty := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_game()


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        flush()


static func default_data() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "coins": 500,
        "owned": ["gt_rookie"],
        "selected": "gt_rookie",
        "upgrades": {},
        "owned_outfits": ["top_tshirt_white", "bottom_jeans_blue", "shoes_sneakers_white"],
        "equipped": {"top": "top_tshirt_white", "bottom": "bottom_jeans_blue", "shoes": "shoes_sneakers_white", "hat": ""},
        "skin": 1,
        "best_laps": {},
        "settings": {"music": 0.5, "sfx": 0.8, "quality": 1, "tilt": false, "tilt_invert": false, "camera": 0},
    }


func load_game() -> void:
    var loaded: Variant = _read_json(SAVE_PATH)
    if loaded == null:
        loaded = _read_json(BACKUP_PATH)
        if loaded != null:
            push_warning("DRIVE X: main save unreadable, restored from backup")
    data = default_data()
    if loaded is Dictionary:
        _merge(data, loaded)
    _sanitize()


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return null
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if parsed is Dictionary:
        return parsed
    return null


func _merge(base: Dictionary, src: Dictionary) -> void:
    for k in src:
        if base.has(k) and base[k] is Dictionary and src[k] is Dictionary:
            _merge(base[k], src[k])
        else:
            base[k] = src[k]


func _sanitize() -> void:
    data["coins"] = maxi(0, int(data.get("coins", 0)))
    var owned: Array = []
    if data.get("owned") is Array:
        for o in data["owned"]:
            if CarData.has_car(str(o)) and not owned.has(str(o)):
                owned.append(str(o))
    if owned.is_empty():
        owned.append(str(Content.cars()[0]["id"]) if not Content.cars().is_empty() else "gt_rookie")
    data["owned"] = owned
    if not owned.has(str(data.get("selected", ""))):
        data["selected"] = owned[0]
    var oo: Array = []
    if data.get("owned_outfits") is Array:
        for o in data["owned_outfits"]:
            if not Content.outfit(str(o)).is_empty() and not oo.has(str(o)):
                oo.append(str(o))
    data["owned_outfits"] = oo
    var eq: Dictionary = data["equipped"] if data.get("equipped") is Dictionary else {}
    for slot: String in Content.SLOTS:
        var id := str(eq.get(slot, ""))
        if id != "" and not oo.has(id):
            eq[slot] = ""
    data["equipped"] = eq
    data["skin"] = clampi(int(data.get("skin", 1)), 0, HumanBuilder.SKINS.size() - 1)
    if not (data.get("upgrades") is Dictionary):
        data["upgrades"] = {}
    if not (data.get("best_laps") is Dictionary):
        data["best_laps"] = {}
    var s: Dictionary = data["settings"]
    s["quality"] = clampi(int(s.get("quality", 1)), 0, 2)
    s["camera"] = clampi(int(s.get("camera", 0)), 0, 3)
    s["music"] = clampf(float(s.get("music", 0.5)), 0.0, 1.0)
    s["sfx"] = clampf(float(s.get("sfx", 0.8)), 0.0, 1.0)


func save_game() -> bool:
    var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
    if f == null:
        push_error("DRIVE X: cannot write save (%s)" % error_string(FileAccess.get_open_error()))
        return false
    f.store_string(JSON.stringify(data, "  "))
    f.close()
    var dir := DirAccess.open("user://")
    if dir == null:
        return false
    var main_name := SAVE_PATH.get_file()
    if dir.file_exists(main_name):
        dir.copy(main_name, BACKUP_PATH.get_file())
    var err := dir.rename(TMP_PATH.get_file(), main_name)
    if err != OK:
        dir.remove(main_name)
        err = dir.rename(TMP_PATH.get_file(), main_name)
    if err != OK:
        push_error("DRIVE X: save rename failed (%s)" % error_string(err))
        return false
    _dirty = false
    return true


func flush() -> void:
    if _dirty:
        save_game()


# --- coins --------------------------------------------------------------------
func coins() -> int:
    return int(data.get("coins", 0))


func add_coins(amount: int) -> void:
    data["coins"] = maxi(0, coins() + amount)
    _dirty = true
    coins_changed.emit(coins())


func spend_coins(amount: int) -> bool:
    if amount < 0 or coins() < amount:
        return false
    add_coins(-amount)
    return true


# --- garage -------------------------------------------------------------------
func owns(id: String) -> bool:
    return (data["owned"] as Array).has(id)


func selected_id() -> String:
    return str(data.get("selected", "gt_rookie"))


func select_car(id: String) -> void:
    if owns(id):
        data["selected"] = id
        save_game()


func buy_car(id: String) -> bool:
    if not CarData.has_car(id) or owns(id):
        return false
    if not spend_coins(int(CarData.by_id(id)["price"])):
        return false
    (data["owned"] as Array).append(id)
    save_game()
    return true


func upgrades_of(id: String) -> Dictionary:
    var all: Dictionary = data["upgrades"]
    var d: Variant = all.get(id, {})
    if d is Dictionary:
        return d
    return {}


func upgrade_level(id: String, key: String) -> int:
    return clampi(int(upgrades_of(id).get(key, 0)), 0, CarData.MAX_UPGRADE)


func buy_upgrade(id: String, key: String) -> bool:
    if not owns(id) or not CarData.UPGRADE_KEYS.has(key):
        return false
    var lvl := upgrade_level(id, key)
    if lvl >= CarData.MAX_UPGRADE or not spend_coins(CarData.upgrade_cost(lvl)):
        return false
    var all: Dictionary = data["upgrades"]
    if not all.has(id) or not (all[id] is Dictionary):
        all[id] = {}
    all[id][key] = lvl + 1
    save_game()
    return true


# --- wardrobe -----------------------------------------------------------------
func owns_outfit(id: String) -> bool:
    return (data["owned_outfits"] as Array).has(id)


func equipped() -> Dictionary:
    return data["equipped"]


func skin() -> int:
    return int(data["skin"])


func set_skin(i: int) -> void:
    data["skin"] = clampi(i, 0, HumanBuilder.SKINS.size() - 1)
    save_game()


func buy_outfit(id: String) -> bool:
    var o := Content.outfit(id)
    if o.is_empty() or owns_outfit(id) or not spend_coins(int(o["price"])):
        return false
    (data["owned_outfits"] as Array).append(id)
    save_game()
    return true


## id = "" removes the item from that slot (only meaningful for hats).
func equip(slot: String, id: String) -> void:
    if id == "" or owns_outfit(id):
        (data["equipped"] as Dictionary)[slot] = id
        save_game()


# --- settings / records ---------------------------------------------------------
func setting(key: String) -> Variant:
    var s: Dictionary = data["settings"]
    if s.has(key):
        return s[key]
    return default_data()["settings"].get(key)


func set_setting(key: String, value: Variant) -> void:
    (data["settings"] as Dictionary)[key] = value
    _dirty = true


func best_lap(race_id: String) -> float:
    return float((data["best_laps"] as Dictionary).get(race_id, 0.0))


func record_lap(race_id: String, t: float) -> bool:
    var old := best_lap(race_id)
    if old <= 0.0 or t < old:
        (data["best_laps"] as Dictionary)[race_id] = t
        _dirty = true
        return true
    return false
