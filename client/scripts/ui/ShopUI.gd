extends CanvasLayer
## Loja viva dos NPCs: aba Comprar (estoque real e preço do momento) e aba Vender (quanto o NPC paga
## pelo que está na sua mochila e quantas unidades ele ainda aceita antes de o mercado encher).
## Os preços vêm do servidor (0x62); o preço justo de cada item nunca é mostrado.

const LunariaUI = preload("res://scripts/ui/LunariaUI.gd")
const ItemDataScript = preload("res://scripts/ItemData.gd")

var is_open: bool = false
var npc_id: int = 0
var npc_title: String = ""
var tab: String = "buy"
var state: Dictionary = {}

var title_label: Label = null
var gold_label: Label = null
var msg_label: Label = null
var list_box: VBoxContainer = null
var buy_tab_btn: Button = null
var sell_tab_btn: Button = null

func _ready() -> void:
	layer = 24
	visible = false
	_build_ui()
	LunariaUI.watch(self)
	NetworkManager.market_state_received.connect(_on_market_state)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_shop()
		get_viewport().set_input_as_handled()

func open_shop(p_npc_id: int, p_title: String) -> void:
	npc_id = p_npc_id
	npc_title = p_title
	tab = "buy"
	state = {}
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_menu_open(true)
	title_label.text = "🛒 Loja de %s" % npc_title
	msg_label.text = "Carregando o balcão..."
	_render()
	NetworkManager.send_shop_request(npc_id)

func close_shop() -> void:
	is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_menu_open(false)

func _set_menu_open(open: bool) -> void:
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", open)

func _on_market_state(st: Dictionary) -> void:
	if not is_open or int(st.get("npc", 0)) != npc_id:
		return
	state = st
	var m: String = str(st.get("msg", ""))
	msg_label.text = m if m != "" else "Os preços mudam com a oferta e a procura da região."
	_render()

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.7)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(760, 560)
	center.add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", LunariaUI.COL_TITLE)
	root.add_child(title_label)

	gold_label = Label.new()
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 13)
	root.add_child(gold_label)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	root.add_child(tabs)
	buy_tab_btn = Button.new()
	buy_tab_btn.text = "🛍️ Comprar"
	buy_tab_btn.custom_minimum_size = Vector2(180, 36)
	buy_tab_btn.toggle_mode = true
	buy_tab_btn.pressed.connect(func():
		tab = "buy"
		_render()
	)
	tabs.add_child(buy_tab_btn)
	sell_tab_btn = Button.new()
	sell_tab_btn.text = "💰 Vender"
	sell_tab_btn.custom_minimum_size = Vector2(180, 36)
	sell_tab_btn.toggle_mode = true
	sell_tab_btn.pressed.connect(func():
		tab = "sell"
		_render()
	)
	tabs.add_child(sell_tab_btn)

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
	msg_label.add_theme_font_size_override("font_size", 12)
	msg_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62))
	root.add_child(msg_label)

	var close_btn := Button.new()
	close_btn.text = "Fechar [ESC]"
	close_btn.pressed.connect(close_shop)
	root.add_child(close_btn)

func _item_name(item_id: int) -> String:
	return str(ItemDataScript.info(item_id).get("name", "Item #%d" % item_id))

func _render() -> void:
	buy_tab_btn.button_pressed = tab == "buy"
	sell_tab_btn.button_pressed = tab == "sell"
	gold_label.text = "Seus Sollares: %d   ·   Cofre de %s: %d" % [int(state.get("player_gold", 0)), npc_title, int(state.get("npc_gold", 0))]
	for c in list_box.get_children():
		c.queue_free()
	if state.is_empty():
		return
	if tab == "buy":
		_render_buy()
	else:
		_render_sell()

func _row(text: String, sub: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l1 := Label.new()
	l1.text = text
	l1.add_theme_font_size_override("font_size", 13)
	l1.add_theme_color_override("font_color", color)
	vb.add_child(l1)
	var l2 := Label.new()
	l2.text = sub
	l2.add_theme_font_size_override("font_size", 11)
	l2.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	vb.add_child(l2)
	row.add_child(vb)
	list_box.add_child(row)
	return row

func _qty_box(max_qty: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = 1
	sb.max_value = maxi(1, max_qty)
	sb.value = 1
	sb.custom_minimum_size = Vector2(80, 0)
	return sb

func _render_buy() -> void:
	var items: Array = state.get("buy", [])
	if items.is_empty():
		_row("Nada à venda no momento.", "O estoque acaba e é reposto com o tempo.", Color(0.8, 0.8, 0.8))
		return
	for e in items:
		var item_id: int = int(e["id"])
		var qty: int = int(e["qty"])
		var price: int = int(e["price"])
		var row := _row(_item_name(item_id), "Estoque: %d   ·   %d Sollares cada" % [qty, price], LunariaUI.COL_TITLE)
		var spin := _qty_box(qty)
		row.add_child(spin)
		var btn := Button.new()
		btn.text = "Comprar"
		btn.custom_minimum_size = Vector2(110, 32)
		btn.disabled = int(state.get("player_gold", 0)) < price
		btn.pressed.connect(func():
			NetworkManager.send_shop_trade(npc_id, 0, item_id, 0, int(spin.value))
		)
		row.add_child(btn)

func _render_sell() -> void:
	var orders: Array = state.get("orders", [])
	if not orders.is_empty():
		var hdr := Label.new()
		hdr.text = "📜 Encomendas abertas (também no quadro da Guilda dos Ofícios):"
		hdr.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		list_box.add_child(hdr)
		for o in orders:
			_row("  %s" % _item_name(int(o["id"])), "  Quer %d · paga %d cada (preço combinado)" % [int(o["wanted"]), int(o["price"])], Color(0.6, 0.9, 1.0))
		list_box.add_child(HSeparator.new())
	var items: Array = state.get("sell", [])
	if items.is_empty():
		_row("Nada na sua mochila interessa a este NPC.", "Cada NPC compra o que usa no ofício. Tente outro comerciante (ou outra região).", Color(0.8, 0.8, 0.8))
		return
	for e in items:
		var item_id: int = int(e["id"])
		var q: int = int(e["q"])
		var have: int = int(e["have"])
		var price: int = int(e["price"])
		var max_qty: int = int(e["max"])
		var sub := "Você tem %d   ·   Paga %d pela próxima" % [have, price]
		if max_qty <= 0:
			sub += "   ·   sem ouro para mais"
		elif max_qty < have:
			sub += "   ·   aceita só mais %d (o preço cai a cada unidade)" % max_qty
		var row := _row("%s  [Qualidade %d]" % [_item_name(item_id), q], sub, Color(0.85, 0.95, 0.75))
		var spin := _qty_box(maxi(1, max_qty))
		row.add_child(spin)
		var btn := Button.new()
		btn.text = "Vender"
		btn.custom_minimum_size = Vector2(110, 32)
		btn.disabled = max_qty <= 0
		btn.pressed.connect(func():
			NetworkManager.send_shop_trade(npc_id, 1, item_id, q, int(spin.value))
		)
		row.add_child(btn)
