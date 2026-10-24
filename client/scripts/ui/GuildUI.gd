extends CanvasLayer
## Quadro da Guilda dos Ofícios: todas as encomendas que os NPCs penduraram (comida primeiro).
## Encomenda é contrato: o preço combinado não cai com a oferta, e a Guilda leva o pacote ao NPC.

const LunariaUI = preload("res://scripts/ui/LunariaUI.gd")
const ItemDataScript = preload("res://scripts/ItemData.gd")

var is_open: bool = false
var list_box: VBoxContainer = null
var msg_label: Label = null
var gold_label: Label = null

func _ready() -> void:
	layer = 24
	visible = false
	_build_ui()
	LunariaUI.watch(self)
	NetworkManager.guild_state_received.connect(_on_guild_state)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_board()
		get_viewport().set_input_as_handled()

func open_board() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_menu_open(true)
	msg_label.text = "Lendo os pedidos pregados no quadro..."
	NetworkManager.send_guild_action(0)

func close_board() -> void:
	is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_menu_open(false)

func _set_menu_open(open: bool) -> void:
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", open)

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.7)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(720, 520)
	center.add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)
	var title := Label.new()
	title.text = "⚜️ Guilda dos Ofícios — Quadro de Encomendas"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", LunariaUI.COL_TITLE)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "Os moradores penduram aqui o que precisam: comida, minério, madeira, ervas... Entregue e receba na hora."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 11)
	root.add_child(sub)
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 12)
	root.add_child(gold_label)
	var inner := PanelContainer.new()
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(inner)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)
	msg_label = Label.new()
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62))
	root.add_child(msg_label)
	var close_btn := Button.new()
	close_btn.text = "Fechar [ESC]"
	close_btn.pressed.connect(close_board)
	root.add_child(close_btn)

func _on_guild_state(st: Dictionary) -> void:
	if not is_open:
		return
	var m: String = str(st.get("msg", ""))
	msg_label.text = m if m != "" else "Encomendas pagam o preço combinado, sem regatear."
	gold_label.text = "Seus Sollares: %d" % int(st.get("player_gold", 0))
	for c in list_box.get_children():
		c.queue_free()
	var orders: Array = st.get("orders", [])
	if orders.is_empty():
		var l := Label.new()
		l.text = "Nenhuma encomenda no momento. Todos estão abastecidos!"
		list_box.add_child(l)
		return
	for o in orders:
		var item_id: int = int(o["id"])
		var npc: int = int(o["npc"])
		var wanted: int = int(o["wanted"])
		var have: int = int(o["have"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l1 := Label.new()
		var icon := "🍖 " if bool(o.get("food", false)) else "📦 "
		l1.text = "%s%s — %s" % [icon, str(ItemDataScript.info(item_id).get("name", "Item")), str(o["npc_name"])]
		l1.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5) if bool(o.get("food", false)) else LunariaUI.COL_TITLE)
		vb.add_child(l1)
		var l2 := Label.new()
		l2.text = "Precisa de %d · paga %d Sollares cada · você tem %d" % [wanted, int(o["price"]), have]
		l2.add_theme_font_size_override("font_size", 11)
		vb.add_child(l2)
		row.add_child(vb)
		var btn := Button.new()
		btn.text = "Entregar %d" % mini(wanted, have)
		btn.custom_minimum_size = Vector2(130, 32)
		btn.disabled = have <= 0
		btn.pressed.connect(func():
			NetworkManager.send_guild_action(1, npc, item_id, mini(wanted, have))
		)
		row.add_child(btn)
		list_box.add_child(row)
