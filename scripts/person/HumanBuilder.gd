class_name HumanBuilder
extends RefCounted
## Procedural low-poly humans. Appearance comes from data (skin, hair, outfit JSON per slot),
## so new clothes / characters never need code. Facing = -Z, feet at y = 0, height ~1.8 m * scale.

const SKINS: Array = ["f1c8a5", "d9a066", "a56a3c", "6b4226"]

static var _mats: Dictionary = {}


static func _m(c: Color) -> StandardMaterial3D:
    var key := c.to_html()
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.85
    _mats[key] = m
    return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = _m(col)
    mi.position = pos
    parent.add_child(mi)
    return mi


static func _ball(parent: Node3D, radius: float, pos: Vector3, col: Color, squash: float = 1.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = radius
    sm.height = radius * 2.0 * squash
    sm.radial_segments = 10
    sm.rings = 5
    mi.mesh = sm
    mi.material_override = _m(col)
    mi.position = pos
    parent.add_child(mi)
    return mi


## Appearance for the player: skin index + equipped {slot: outfit_id}.
static func resolve(skin_idx: int, equipped: Dictionary) -> Dictionary:
    var app := {"skin": SKINS[clampi(skin_idx, 0, SKINS.size() - 1)], "hair": "1a120c", "hair_style": "short", "scale": 1.0}
    for slot: String in Content.SLOTS:
        app[slot] = Content.outfit(str(equipped.get(slot, "")))
    return app


## Appearance for an NPC / fighter preset from content/characters/*.json.
static func resolve_character(ch: Dictionary) -> Dictionary:
    var app := {"skin": str(ch.get("skin", "d9a066")), "hair": str(ch.get("hair", "1a120c")),
        "hair_style": str(ch.get("hair_style", "short")), "scale": float(ch.get("scale", 1.0))}
    var oc: Dictionary = ch.get("outfit", {})
    for slot: String in Content.SLOTS:
        app[slot] = Content.outfit(str(oc.get(slot, "")))
    return app


## Returns {"root": Node3D, "parts": {head, arm_l, arm_r, leg_l, leg_r}}.
static func build(app: Dictionary) -> Dictionary:
    var root := Node3D.new()
    var body := Node3D.new()
    root.add_child(body)
    var skin := Color.html(str(app.get("skin", "d9a066")))
    var hair := Color.html(str(app.get("hair", "1a120c")))
    var top: Dictionary = app.get("top", {})
    var bottom: Dictionary = app.get("bottom", {})
    var shoes: Dictionary = app.get("shoes", {})
    var hat: Dictionary = app.get("hat", {})
    var top_c := Color.html(str(top.get("color", "")) if top.has("color") else "8a8f99")
    var top_style := str(top.get("style", "tshirt"))
    var bot_c := Color.html(str(bottom.get("color", "")) if bottom.has("color") else "3a3f4a")
    var bot_style := str(bottom.get("style", "pants"))
    var shoe_c := Color.html(str(shoes.get("color", "")) if shoes.has("color") else "202020")

    var parts := {}
    # legs (pivot at hip)
    for side in [-1, 1]:
        var pivot := Node3D.new()
        pivot.position = Vector3(float(side) * 0.13, 0.9, 0.0)
        body.add_child(pivot)
        if bot_style == "shorts":
            _box(pivot, Vector3(0.2, 0.9, 0.22), Vector3(0, -0.45, 0), skin)
            _box(pivot, Vector3(0.23, 0.38, 0.25), Vector3(0, -0.19, 0), bot_c)
        elif bot_style == "skirt":
            _box(pivot, Vector3(0.2, 0.9, 0.22), Vector3(0, -0.45, 0), skin)
        else:
            _box(pivot, Vector3(0.2, 0.9, 0.22), Vector3(0, -0.45, 0), bot_c)
        _box(pivot, Vector3(0.22, 0.1, 0.34), Vector3(0, -0.85, -0.05), shoe_c)
        parts["leg_l" if side < 0 else "leg_r"] = pivot
    if bot_style == "skirt":
        _box(body, Vector3(0.56, 0.42, 0.34), Vector3(0, 0.78, 0), bot_c)
    # torso
    var torso_w := 0.54 if top_style == "jacket" or top_style == "robe" else 0.5
    _box(body, Vector3(torso_w, 0.6, 0.3), Vector3(0, 1.2, 0), top_c)
    if top_style == "robe":
        _box(body, Vector3(0.58, 0.5, 0.34), Vector3(0, 0.85, 0), top_c)
        _box(body, Vector3(0.09, 1.0, 0.02), Vector3(0, 1.0, -0.17), Color.html(str(top.get("accent", "ffffff"))))
    # arms (pivot at shoulder)
    for side in [-1, 1]:
        var pivot := Node3D.new()
        pivot.position = Vector3(float(side) * (torso_w * 0.5 + 0.08), 1.47, 0.0)
        body.add_child(pivot)
        if top_style == "tshirt":
            _box(pivot, Vector3(0.15, 0.6, 0.15), Vector3(0, -0.3, 0), skin)
            _box(pivot, Vector3(0.18, 0.24, 0.18), Vector3(0, -0.12, 0), top_c)
        else:
            _box(pivot, Vector3(0.16, 0.5, 0.16), Vector3(0, -0.25, 0), top_c)
            _box(pivot, Vector3(0.13, 0.12, 0.13), Vector3(0, -0.56, 0), skin)
        parts["arm_l" if side < 0 else "arm_r"] = pivot
    # head
    var head := Node3D.new()
    head.position = Vector3(0, 1.68, 0)
    body.add_child(head)
    _ball(head, 0.15, Vector3.ZERO, skin)
    for ex in [-0.055, 0.055]:
        _box(head, Vector3(0.035, 0.035, 0.02), Vector3(ex, 0.02, -0.14), Color(0.05, 0.05, 0.06))
    var hs := str(app.get("hair_style", "short"))
    if hs != "none":
        _ball(head, 0.16, Vector3(0, 0.05, 0.015), hair, 0.75)
    if hs == "long":
        _box(head, Vector3(0.3, 0.42, 0.1), Vector3(0, -0.12, 0.12), hair)
    parts["head"] = head
    # hat
    var hat_style := str(hat.get("style", ""))
    if hat_style == "cap":
        var hc := Color.html(str(hat.get("color", "202020")))
        _box(head, Vector3(0.34, 0.09, 0.34), Vector3(0, 0.13, 0), hc)
        _box(head, Vector3(0.3, 0.025, 0.16), Vector3(0, 0.1, -0.24), hc)
    elif hat_style == "toqi":
        var tc := Color.html(str(hat.get("color", "15151c")))
        var ac := Color.html(str(hat.get("accent", "ffffff")))
        _box(head, Vector3(0.3, 0.12, 0.3), Vector3(0, 0.15, 0), tc)
        _box(head, Vector3(0.32, 0.03, 0.32), Vector3(0, 0.1, 0), ac)
    root.scale = Vector3.ONE * float(app.get("scale", 1.0))
    return {"root": root, "body": body, "parts": parts}
