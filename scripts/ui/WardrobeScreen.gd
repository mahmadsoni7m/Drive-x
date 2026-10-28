class_name WardrobeScreen
extends Control
## Clothes + skin tone. Items come from content/outfits/*.json (shop = true).

signal navigate(screen: String)
signal preview(app: Dictionary)

var _slot := "top"
var _panel: VBoxContainer
var _toast: Label


func _ready() -> void:
    UIKit.full(self)
    var scroll := ScrollContainer.new()
    scroll.anchor_bottom = 1.0
    scroll.offset_left = 30.0
    scroll.offset_top = 20.0
    scroll.offset_right = 560.0
    scroll.offset_bottom = -20.0
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    _panel = VBoxContainer.new()
    _panel.add_theme_constant_override("separation", 8)
    _panel.custom_minimum_size = Vector2(510, 0)
    scroll.add_child(_panel)
    _toast = UIKit.label("", 28, UIKit.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
    _toast.anchor_left = 0.5
    _toast.anchor_right = 0.5
    _toast.offset_right = 640.0
    _toast.offset_top = 24.0
    _toast.offset_bottom = 70.0
    add_child(_toast)
    refresh()


func _notify(key: String, color: Color) -> void:
    _toast.text = Lang.t(key)
    _toast.add_theme_color_override("font_color", color)


func refresh() -> void:
    for c in _panel.get_children():
        c.queue_free()
    preview.emit(HumanBuilder.resolve(GameData.skin(), GameData.equipped()))
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 12)
    top.add_child(UIKit.button(Lang.t("common.back"), func() -> void: navigate.emit("menu"), Vector2(170, 56), 24))
    var coins := UIKit.label(Lang.t("common.coins", [GameData.coins()]), 24, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT)
    coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(coins)
    _panel.add_child(top)
    _panel.add_child(UIKit.label(Lang.t("wardrobe.title"), 40, UIKit.ACCENT))
    # skin tones
    var skins := HBoxContainer.new()
    skins.add_theme_constant_override("separation", 10)
    skins.add_child(UIKit.label(Lang.t("wardrobe.skin"), 22, UIKit.DIM))
    for i in HumanBuilder.SKINS.size():
        var b := Button.new()
        b.custom_minimum_size = Vector2(60, 50)
        var col := Color.html(str(HumanBuilder.SKINS[i]))
        b.add_theme_stylebox_override("normal", UIKit.flat(col, 10, Color.WHITE if GameData.skin() == i else Color(0, 0, 0, 0.3), 3))
        b.add_theme_stylebox_override("hover", UIKit.flat(col.lightened(0.1), 10, UIKit.CYAN, 3))
        b.add_theme_stylebox_override("pressed", UIKit.flat(col, 10, UIKit.ACCENT, 3))
        b.pressed.connect(func() -> void:
            GameData.set_skin(i)
            refresh())
        skins.add_child(b)
    _panel.add_child(skins)
    # slot tabs
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    for slot: String in Content.SLOTS:
        var tb := UIKit.button(Lang.t("slot." + slot), _set_slot.bind(slot), Vector2(120, 52), 20)
        tb.disabled = slot == _slot
        tabs.add_child(tb)
    _panel.add_child(tabs)
    if _slot == "hat":
        var none_btn := UIKit.button(Lang.t("wardrobe.none"), _remove_hat, Vector2(420, 54), 22)
        none_btn.disabled = str(GameData.equipped().get("hat", "")) == ""
        _panel.add_child(none_btn)
    for o: Dictionary in Content.outfits_in(_slot):
        _panel.add_child(_item_row(o))


func _item_row(o: Dictionary) -> Control:
    var id := str(o["id"])
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 10)
    var sw := ColorRect.new()
    sw.custom_minimum_size = Vector2(36, 36)
    sw.color = Color.html(str(o["color"]))
    h.add_child(sw)
    var l := UIKit.label(str(o["name"]), 22, UIKit.TEXT)
    l.custom_minimum_size = Vector2(230, 0)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    h.add_child(l)
    if GameData.owns_outfit(id):
        var on := str(GameData.equipped().get(str(o["slot"]), "")) == id
        var b := UIKit.button(Lang.t("common.equipped") if on else Lang.t("common.equip"), func() -> void: _equip(o), Vector2(190, 52), 20)
        b.disabled = on
        h.add_child(b)
    else:
        var price := int(o["price"])
        var b := UIKit.button(Lang.t("common.buy", [price]), func() -> void: _buy(id), Vector2(190, 52), 20)
        b.disabled = GameData.coins() < price
        h.add_child(b)
    return h


func _set_slot(slot: String) -> void:
    _slot = slot
    refresh()


func _remove_hat() -> void:
    GameData.equip("hat", "")
    refresh()


func _equip(o: Dictionary) -> void:
    GameData.equip(str(o["slot"]), str(o["id"]))
    refresh()


func _buy(id: String) -> void:
    if GameData.buy_outfit(id):
        AudioManager.play("coin")
        _notify("common.bought", UIKit.GOOD)
    else:
        _notify("common.no_coins", UIKit.BAD)
    refresh()
