extends CanvasLayer

var is_open: bool = false
var stat_points: int = 0
var current_xp: int = 0
var next_level_xp: int = 100
var player_level: int = 1

var stat_values := {
	1: 10, # FOR
	2: 10, # DES
	3: 10, # CON
	4: 10, # AGI
	5: 10, # INT
	6: 10, # ESP
	7: 10, # PER
	8: 10  # SOR
}

var points_label: Label = null
var xp_label: Label = null
var stat_val_labels: Dictionary = {}
var stat_buttons: Dictionary = {}

const STAT_INFO := {
	1: {
		"code": "FOR",
		"name": "Força",
		"desc": "+Dano Físico Corpo-a-Corpo & Quebra de Postura",
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
		"desc": "+18 HP Máximo & Defesa Física",
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
		"desc": "+Dano Mágico/Alquímico & Área",
		"color": Color("#ab47bc")
	},
	6: {
		"code": "ESP",
		"name": "Espírito",
		"desc": "+Poder de Cura & Redução de Recarga",
		"color": Color("#ffd54f")
	},
	7: {
		"code": "PER",
		"name": "Perícia",
		"desc": "+Extração Anatômica de Monstros & Dano Crítico",
		"color": Color("#26a69a")
	},
	8: {
		"code": "SOR",
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
	stat_values[1] = str_val
	stat_values[2] = dex_val
	stat_values[3] = con_val
	stat_values[4] = agi_val
	stat_values[5] = int_val
	stat_values[6] = spi_val
	stat_values[7] = mas_val
	stat_values[8] = lck_val
	_update_display()

func _on_player_stats_full(_pid: int, _race: int, _cls: int, _tier: int, level: int, _hp: int, _max_hp: int, _stam: int, _max_stam: int, _buff: int) -> void:
	player_level = level
	_update_display()

func _build_ui() -> void:
	# Scrim escurecido de fundo
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.65)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 560)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	p_style.border_color = Color(0.9, 0.75, 0.28, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.7)
	p_style.shadow_size = 14
	p_style.content_margin_left = 22
	p_style.content_margin_right = 22
	p_style.content_margin_top = 18
	p_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# Cabeçalho com Título e Botão Fechar
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "✦  ATRIBUTOS & PROGRESSÃO ANATÔMICA [K]  ✦"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	top_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " [X] Fechar (K) "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.35, 0.12, 0.12, 0.85)
	c_style.border_color = Color(0.75, 0.25, 0.25)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", c_style)
	close_btn.pressed.connect(close_menu)
	top_bar.add_child(close_btn)

	# Painel de Resumo (Nível, XP, Pontos Livres)
	var summary_panel := PanelContainer.new()
	var s_style := StyleBoxFlat.new()
	s_style.bg_color = Color(0.1, 0.13, 0.18, 0.85)
	s_style.set_border_width_all(1)
	s_style.border_color = Color(0.3, 0.45, 0.65, 0.5)
	s_style.set_corner_radius_all(6)
	s_style.content_margin_left = 12
	s_style.content_margin_right = 12
	s_style.content_margin_top = 8
	s_style.content_margin_bottom = 8
	summary_panel.add_theme_stylebox_override("panel", s_style)
	root_vbox.add_child(summary_panel)

	var sum_hbox := HBoxContainer.new()
	summary_panel.add_child(sum_hbox)

	xp_label = Label.new()
	xp_label.text = "Nível Atual: 1  |  XP: 0 / 100"
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	sum_hbox.add_child(xp_label)

	points_label = Label.new()
	points_label.text = "Pontos de Atributo Livres: 0"
	points_label.add_theme_font_size_override("font_size", 14)
	points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	sum_hbox.add_child(points_label)

	# Lista de Atributos com rolagem suave
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var stat_list_vbox := VBoxContainer.new()
	stat_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(stat_list_vbox)

	for stat_id in [1, 2, 3, 4, 5, 6, 7, 8]:
		var s_data: Dictionary = STAT_INFO[stat_id]
		var row := _create_stat_row(stat_id, s_data["code"], s_data["name"], s_data["desc"], s_data["color"])
		stat_list_vbox.add_child(row)

	# Rodapé explicativo
	var footer_lbl := Label.new()
	footer_lbl.text = "Distribua seus pontos obtidos ao subir de nível para especializar seu estilo de combate corpo-a-corpo, alcance ou magia."
	footer_lbl.add_theme_font_size_override("font_size", 11)
	footer_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(footer_lbl)

func _create_stat_row(stat_id: int, code: String, s_name: String, desc: String, col: Color) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.10, 0.15, 0.88)
	row_style.border_color = Color(col.r, col.g, col.b, 0.35)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(6)
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	row_style.content_margin_top = 6
	row_style.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row_panel.add_child(hbox)

	# Sigla e Nome
	var name_vbox := VBoxContainer.new()
	name_vbox.custom_minimum_size = Vector2(170, 0)
	name_vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(name_vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s (%s)" % [s_name, code]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", col)
	name_vbox.add_child(name_lbl)

	# Descrição dos bônus
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	hbox.add_child(desc_lbl)

	# Valor Atual
	var val_lbl := Label.new()
	val_lbl.text = "10"
	val_lbl.custom_minimum_size = Vector2(45, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	hbox.add_child(val_lbl)
	stat_val_labels[stat_id] = val_lbl

	# Botão [+] Aumentar
	var add_btn := Button.new()
	add_btn.text = " [+] Aumentar "
	add_btn.custom_minimum_size = Vector2(110, 32)
	add_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.18, 0.28, 0.42, 0.9)
	b_style.border_color = Color(0.45, 0.65, 0.95, 0.8)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(5)
	add_btn.add_theme_stylebox_override("normal", b_style)
	add_btn.pressed.connect(func(): _on_allocate_pressed(stat_id))
	hbox.add_child(add_btn)
	stat_buttons[stat_id] = add_btn

	return row_panel

func _on_allocate_pressed(stat_id: int) -> void:
	if stat_points <= 0:
		return
	print("[AttributesUI] Alocando ponto no Atributo ID %d..." % stat_id)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_allocate_stat(stat_id)

func _update_display() -> void:
	if xp_label:
		xp_label.text = "Nível Atual: %d  |  XP: %d / %d" % [player_level, current_xp, next_level_xp]

	if points_label:
		if stat_points > 0:
			points_label.text = "✦ Pontos de Atributo Livres: +%d ✦" % stat_points
			points_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.15))
		else:
			points_label.text = "Pontos de Atributo Livres: 0"
			points_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))

	for sid in stat_val_labels.keys():
		var lbl: Label = stat_val_labels[sid]
		if is_instance_valid(lbl):
			lbl.text = str(stat_values.get(sid, 10))

	for sid in stat_buttons.keys():
		var btn: Button = stat_buttons[sid]
		if is_instance_valid(btn):
			btn.disabled = (stat_points <= 0)
			if stat_points > 0:
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
