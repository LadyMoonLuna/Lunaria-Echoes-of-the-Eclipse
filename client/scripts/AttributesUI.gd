extends CanvasLayer
## Status do personagem (Tecla C) em estilo livro de pergaminho.
## Alocação rápida: digite a quantidade (ou use 1/5/10/50/MAX) e clique em [+ Alocar];
## o servidor recebe tudo num único pacote 0x37 com Amount.

const COL_PARCHMENT := Color(0.85, 0.78, 0.65)
const COL_PARCHMENT_DARK := Color(0.76, 0.68, 0.53)
const COL_WOOD := Color(0.32, 0.22, 0.14)
const COL_INK := Color(0.2, 0.13, 0.08)
const COL_INK_SOFT := Color(0.38, 0.28, 0.18)

const CARRY_PER_STR := 5.0
const CARRY_PER_CON := 2.5

var is_open: bool = false
var stat_points: int = 0
var current_xp: int = 0
var next_level_xp: int = 100
var player_level: int = 1
var max_weight: float = 0.0
var current_weight: float = 0.0

var stat_values := {1: 10, 2: 10, 3: 10, 4: 10, 5: 10, 6: 10, 7: 10, 8: 10}

var points_label: Label = null
var xp_label: Label = null
var custom_amount_input: LineEdit = null
var carry_label: Label = null
var carry_preview_label: Label = null
var stat_val_labels: Dictionary = {}
var stat_buttons: Dictionary = {}

const STAT_INFO := {
	1: {
		"code": "FOR",
		"name": "Força",
		"desc": "+Dano Físico Corpo-a-Corpo, Quebra de Postura & +5 kg de carga",
		"color": Color("#ff7043")
	},
	2: {
		"code": "DES",
		"name": "Destreza",
		"desc": "+Dano à Distância & Chance Crítica",
		"color": Color("#66bb6a")
	},
	3: {
		"code": "CON",
		"name": "Constituição",
		"desc": "+18 HP Máximo, Defesa Física & +2.5 kg de carga",
		"color": Color("#ef5350")
	},
	4: {
		"code": "AGI",
		"name": "Agilidade",
		"desc": "+8 Stamina Máxima, Regen & Esquiva",
		"color": Color("#29b6f6")
	},
	5: {
		"code": "INT",
		"name": "Inteligência",
		"desc": "+Dano Mágico/Alquímico, Área & +6 Mana Máxima por ponto",
		"color": Color("#ab47bc")
	},
	6: {
		"code": "ESP",
		"name": "Espírito",
		"desc": "+Poder de Cura & +0.15 Regeneração de Mana/s por ponto",
		"color": Color("#ffd54f")
	},
	7: {
		"code": "MAS",
		"name": "Maestria",
		"desc": "+Extração Anatômica de Monstros & Dano Crítico",
		"color": Color("#26a69a")
	},
	8: {
		"code": "LCK",
		"name": "Sorte",
		"desc": "+Drops Raros & Anomalias Lunares",
		"color": Color("#ffa726")
	}
}


func _ready() -> void:
	layer = 15
	visible = false
	_build_ui()

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.player_attributes_received.connect(_on_player_attributes_received)
		nm.player_stats_full_received.connect(_on_player_stats_full)
		if nm.has_signal("wallet_weight_updated"):
			nm.wallet_weight_updated.connect(_on_wallet_weight_updated)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)
	_update_display()

func close_menu() -> void:
	is_open = false
	visible = false
	if custom_amount_input:
		custom_amount_input.release_focus()
	var world := get_parent()
	var any_other_open := false
	if world:
		if world.get("char_select_ui") and world.char_select_ui.get("is_open"):
			any_other_open = true
		if world.get("inventory_ui") and world.inventory_ui.get("is_open"):
			any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func _on_player_attributes_received(_pid: int, p_xp: int, p_next_xp: int, p_stat_points: int, str_val: int, dex_val: int, con_val: int, agi_val: int, int_val: int, spi_val: int, mas_val: int, lck_val: int) -> void:
	current_xp = p_xp
	next_level_xp = p_next_xp
	stat_points = p_stat_points
	stat_values = {1: str_val, 2: dex_val, 3: con_val, 4: agi_val, 5: int_val, 6: spi_val, 7: mas_val, 8: lck_val}
	_update_display()

func _on_player_stats_full(_pid: int, _race: int, _cls: int, _tier: int, level: int, _hp: int, _max_hp: int, _stam: int, _max_stam: int, _buff: int) -> void:
	player_level = level
	_update_display()

func _on_wallet_weight_updated(_gold: int, _eclipse: int, p_cur: float, p_max: float, _speed: float) -> void:
	current_weight = p_cur
	max_weight = p_max
	_update_carry()

# ---------------------------------------------------------------------------
# Estilo
# ---------------------------------------------------------------------------

func _box(bg: Color, border: Color, width: int = 2, radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _small_btn(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(42, 30)
	b.add_theme_color_override("font_color", Color(0.98, 0.9, 0.7))
	b.add_theme_stylebox_override("normal", _box(COL_WOOD, Color(0.18, 0.12, 0.07), 1, 4, 4))
	b.pressed.connect(on_press)
	return b

# ---------------------------------------------------------------------------
# Interface
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.02, 0.03, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	var frame := PanelContainer.new()
	var fs := _box(COL_WOOD, Color(0.18, 0.12, 0.07), 6, 12, 12)
	fs.shadow_color = Color(0, 0, 0, 0.8)
	fs.shadow_size = 18
	frame.add_theme_stylebox_override("panel", fs)
	center.add_child(frame)

	var page := PanelContainer.new()
	page.custom_minimum_size = Vector2(640, 0)
	page.add_theme_stylebox_override("panel", _box(COL_PARCHMENT, COL_PARCHMENT_DARK, 2, 4, 18))
	frame.add_child(page)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	page.add_child(vb)

	var header := HBoxContainer.new()
	vb.add_child(header)
	var title := _label("📜 Pergaminho de Atributos", 20, COL_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_small_btn("✖", close_menu))

	xp_label = _label("Nível 1  |  XP: 0 / 100", 12, COL_INK_SOFT)
	vb.add_child(xp_label)

	# Barra de Alocação Rápida
	var quick := PanelContainer.new()
	quick.add_theme_stylebox_override("panel", _box(COL_PARCHMENT_DARK, COL_WOOD, 1, 6, 8))
	vb.add_child(quick)
	var qhb := HBoxContainer.new()
	qhb.add_theme_constant_override("separation", 6)
	quick.add_child(qhb)
	points_label = _label("Pontos Disponíveis: 0", 14, COL_INK)
	points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qhb.add_child(points_label)
	qhb.add_child(_label("Quantidade:", 12, COL_INK_SOFT))
	custom_amount_input = LineEdit.new()
	custom_amount_input.text = "1"
	custom_amount_input.custom_minimum_size = Vector2(64, 30)
	custom_amount_input.max_length = 5
	custom_amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_amount_input.text_changed.connect(_on_amount_text_changed)
	qhb.add_child(custom_amount_input)
	for preset in [1, 5, 10, 50]:
		var n: int = preset
		qhb.add_child(_small_btn(str(n), func(): _set_amount(n)))
	qhb.add_child(_small_btn("MAX", func(): _set_amount(max(1, stat_points))))

	# Capacidade de carga ao vivo
	carry_label = _label("⚖️ Capacidade de Carga: — kg", 13, COL_INK)
	vb.add_child(carry_label)
	carry_preview_label = _label("", 11, COL_INK_SOFT)
	vb.add_child(carry_preview_label)

	var sep := ColorRect.new()
	sep.color = COL_WOOD
	sep.custom_minimum_size = Vector2(0, 2)
	vb.add_child(sep)

	for sid in [1, 2, 3, 4, 5, 6, 7, 8]:
		vb.add_child(_create_stat_row(sid))

func _create_stat_row(stat_id: int) -> Control:
	var info: Dictionary = STAT_INFO[stat_id]
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)

	var code_l := _label(info["code"], 14, info["color"].darkened(0.35))
	code_l.custom_minimum_size = Vector2(44, 0)
	hb.add_child(code_l)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	hb.add_child(names)
	names.add_child(_label(info["name"], 14, COL_INK))
	var desc := _label(info["desc"], 10, COL_INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(desc)

	var val_l := _label("10", 18, COL_INK)
	val_l.custom_minimum_size = Vector2(44, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(val_l)
	stat_val_labels[stat_id] = val_l

	var add_btn := Button.new()
	add_btn.text = "+ Alocar"
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.custom_minimum_size = Vector2(86, 32)
	add_btn.add_theme_color_override("font_color", Color(0.98, 0.92, 0.75))
	add_btn.add_theme_stylebox_override("normal", _box(Color(0.24, 0.36, 0.18), Color(0.15, 0.22, 0.1), 1, 5, 4))
	add_btn.add_theme_stylebox_override("hover", _box(Color(0.3, 0.46, 0.22), Color(0.15, 0.22, 0.1), 1, 5, 4))
	add_btn.pressed.connect(func(): _on_allocate_pressed(stat_id))
	hb.add_child(add_btn)
	stat_buttons[stat_id] = add_btn

	# Linha sublinhada estilo livro
	var line := ColorRect.new()
	line.color = Color(COL_INK_SOFT.r, COL_INK_SOFT.g, COL_INK_SOFT.b, 0.45)
	line.custom_minimum_size = Vector2(0, 1)
	row.add_child(line)
	return row

# ---------------------------------------------------------------------------
# Quantidade digitada (somente inteiros positivos)
# ---------------------------------------------------------------------------

func _on_amount_text_changed(new_text: String) -> void:
	var digits := ""
	for ch in new_text:
		if ch >= "0" and ch <= "9":
			digits += ch
	digits = digits.lstrip("0")
	if digits != new_text:
		custom_amount_input.text = digits
		custom_amount_input.caret_column = digits.length()
	_update_carry()

func _set_amount(value: int) -> void:
	custom_amount_input.text = str(max(1, value))
	_update_carry()

func _get_amount() -> int:
	var v: int = int(custom_amount_input.text) if custom_amount_input and custom_amount_input.text.is_valid_int() else 1
	return clampi(v, 1, max(1, stat_points))

func _on_allocate_pressed(stat_id: int) -> void:
	if stat_points <= 0:
		return
	var amount: int = _get_amount()
	print("[AttributesUI] Alocando %d ponto(s) no Atributo ID %d..." % [amount, stat_id])
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_allocate_stat(stat_id, amount)

# ---------------------------------------------------------------------------
# Atualização
# ---------------------------------------------------------------------------

func _update_carry() -> void:
	if carry_label == null:
		return
	if max_weight <= 0.0:
		carry_label.text = "⚖️ Capacidade de Carga: — kg"
	else:
		carry_label.text = "⚖️ Capacidade de Carga: %.1f kg  (carregando %.1f kg)" % [max_weight, current_weight]
	var amount: int = _get_amount()
	carry_preview_label.text = "Com %d ponto(s): FOR → %.1f kg (+%.1f)  •  CON → %.1f kg (+%.1f)" % [
		amount, max_weight + amount * CARRY_PER_STR, amount * CARRY_PER_STR,
		max_weight + amount * CARRY_PER_CON, amount * CARRY_PER_CON]

func _update_display() -> void:
	if xp_label:
		xp_label.text = "Nível %d  |  XP: %d / %d" % [player_level, current_xp, next_level_xp]

	if points_label:
		points_label.text = "✦ Pontos Disponíveis: %d" % stat_points
		points_label.add_theme_color_override("font_color", Color(0.55, 0.3, 0.05) if stat_points > 0 else COL_INK_SOFT)

	for sid in stat_val_labels.keys():
		var lbl: Label = stat_val_labels[sid]
		if is_instance_valid(lbl):
			lbl.text = str(stat_values.get(sid, 10))

	for sid in stat_buttons.keys():
		var btn: Button = stat_buttons[sid]
		if is_instance_valid(btn):
			btn.disabled = (stat_points <= 0)
			btn.modulate = Color(1, 1, 1, 1) if stat_points > 0 else Color(0.6, 0.6, 0.6, 0.7)
	_update_carry()
