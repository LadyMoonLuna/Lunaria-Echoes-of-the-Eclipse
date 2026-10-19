extends CanvasLayer

signal identity_confirmed(race_id: int, class_id: int)

var selected_race: int = 1
var selected_class: int = 1
var is_open: bool = false

# Metadados de Raças
const RACES_DATA := {
	1: {
		"name": "Valeriano",
		"sub": "Humano — Cidadão do Reino",
		"hp_mod": 10,
		"stam_mod": 10,
		"passive": "Fôlego Real: +15% de regeneração contínua de Stamina.",
		"npc_reaction": "Garrick: 'Honrado cidadão de Valéria. As forjas do reino estão a seu serviço!'",
		"color": Color("#40c4ff")
	},
	2: {
		"name": "Noctari",
		"sub": "Elfo da Lua — Guardião Astral",
		"hp_mod": 0,
		"stam_mod": 20,
		"passive": "Passo Astral: +25% de dano e crítico sob o luar (dobrado na Lua Cheia).",
		"npc_reaction": "Garrick: 'Um Elfo da Lua... Suas lâminas e cajados brilham diferente sob o luar.'",
		"color": Color("#b388ff")
	},
	3: {
		"name": "Kharad",
		"sub": "Forjado das Cinzas — Artífice Pétreo",
		"hp_mod": 30,
		"stam_mod": 0,
		"passive": "Postura de Rocha: Reduz 20% de todo dano recebido de Mobs e bônus em golpes pesados.",
		"npc_reaction": "Garrick: 'Um irmão Kharad! Reconheço a fuligem das forjas ancestrais no seu sangue. Desconto em reparos!'",
		"color": Color("#ffb74d")
	},
	4: {
		"name": "Varkai",
		"sub": "Sangue-Feral — Caçador Primordial",
		"hp_mod": 15,
		"stam_mod": 10,
		"passive": "Sangue Fervilhante: +20% de dano feroz quando a vida cai abaixo de 35%.",
		"npc_reaction": "Garrick: 'Mantenha essas garras e esse sangue feroz longe dos cidadãos da vila, Varkai, e nos daremos bem.'",
		"color": Color("#ff5252")
	},
	5: {
		"name": "Dhampir [Secreta]",
		"sub": "Linhagem da Noite Eterna",
		"hp_mod": 10,
		"stam_mod": 15,
		"passive": "Sede de Sangue: Lifesteal (+8 HP por golpe/flecha/magia) e +40% dano na Lua de Sangue.",
		"npc_reaction": "Garrick: 'Pelos deuses... Você não tem pulso! Afaste essa sede de sangue da minha forja!'",
		"color": Color("#ff1744")
	}
}

# Metadados de Classes
const CLASSES_DATA := {
	1: {
		"name": "Espadachim",
		"style": "Corpo-a-Corpo | Espada Longa & Escudo",
		"hp_base": 140,
		"stam_base": 100,
		"range_desc": "Curta Distância (3.8m)",
		"skill_q": "Corte Crescente [Q]: Golpe em arco amplo com alta sobrevivência defensiva.",
		"evolutions": "Vanguarda Real ou Espadachim Mágico",
		"color": Color("#64b5f6")
	},
	2: {
		"name": "Batedor",
		"style": "Distância Física | Arco de Caça Rápido",
		"hp_base": 105,
		"stam_base": 135,
		"range_desc": "Longo Alcance (16.0m)",
		"skill_q": "Disparo Perfurante [Q]: Flecha perfurante veloz a 22m que atravessa múltiplos inimigos.",
		"evolutions": "Lâmina Sombria ou Franco-Atirador Rúnico",
		"color": Color("#69f0ae")
	},
	3: {
		"name": "Iniciado",
		"style": "Distância Mágica | Cajado Rúnico Arcano",
		"hp_base": 95,
		"stam_base": 110,
		"range_desc": "Médio/Longo Alcance (14.0m)",
		"skill_q": "Cometa Elemental [Q]: Esfera flamejante/arcana que explode em área de 2.8m ao atingir.",
		"evolutions": "Arcanista ou Mago de Batalha",
		"color": Color("#ea80fc")
	},
	4: {
		"name": "Acólito",
		"style": "Híbrido Sagrado | Maça Dourada & Talismã",
		"hp_base": 125,
		"stam_base": 105,
		"range_desc": "Médio Alcance (4.5m)",
		"skill_q": "Círculo de Luz [Q]: Golpe sagrado e oração que cura +40 HP em área para o grupo.",
		"evolutions": "Oráculo da Luz ou Paladino do Juramento",
		"color": Color("#ffd54f")
	}
}

# Referências de Nós UI
var main_panel: PanelContainer = null
var race_buttons: Dictionary = {}
var class_buttons: Dictionary = {}
var summary_title: Label = null
var stats_breakdown_label: Label = null
var weapon_details_label: Label = null
var skill_details_label: Label = null
var npc_reaction_label: Label = null
var confirm_button: Button = null

func _ready() -> void:
	layer = 25
	_build_ui()
	_update_selection_states()
	_update_summary()
	open_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.keycode == KEY_TAB:
			if is_open:
				close_menu()
			else:
				open_menu()
			get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world_node := get_parent()
	if world_node and world_node.get("local_player") and is_instance_valid(world_node.local_player):
		world_node.local_player.set("is_menu_open", true)

func close_menu() -> void:
	is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var world_node := get_parent()
	if world_node and world_node.get("local_player") and is_instance_valid(world_node.local_player):
		world_node.local_player.set("is_menu_open", false)

func _build_ui() -> void:
	# Fundo Escurecido Scrim
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.78)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	# Container Central
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	# Painel Principal Estilizado com Borda Dourada Medieval
	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(980, 610)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	panel_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 14
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(root_vbox)

	# Cabeçalho
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	root_vbox.add_child(header_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "✦  LUNARIA: ESCOLHA SUA IDENTIDADE  ✦"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	header_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "Selecione sua Raça e Classe inicial para calibrar atributos, estilo de combate e a reação de Garrick e dos aldeões"
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 12)
	subtitle_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	header_vbox.add_child(subtitle_lbl)

	# Colunas de Seleção (Lado a Lado)
	var columns_hbox := HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 16)
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(columns_hbox)

	# Coluna 1: Raças
	var race_col := VBoxContainer.new()
	race_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race_col.add_theme_constant_override("separation", 6)
	columns_hbox.add_child(race_col)

	var race_col_title := Label.new()
	race_col_title.text = "LINHAGENS ANCESTRAIS (RAÇAS)"
	race_col_title.add_theme_font_size_override("font_size", 13)
	race_col_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	race_col.add_child(race_col_title)

	for r_id in [1, 2, 3, 4, 5]:
		var r_data: Dictionary = RACES_DATA[r_id]
		var btn := _create_card_button(r_id, r_data["name"], r_data["sub"], "HP %+d | Stamina %+d" % [r_data["hp_mod"], r_data["stam_mod"]], r_data["color"], true)
		race_col.add_child(btn)
		race_buttons[r_id] = btn

	# Coluna 2: Classes
	var class_col := VBoxContainer.new()
	class_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_col.add_theme_constant_override("separation", 6)
	columns_hbox.add_child(class_col)

	var class_col_title := Label.new()
	class_col_title.text = "VOCAÇÕES INICIAIS (CLASSES)"
	class_col_title.add_theme_font_size_override("font_size", 13)
	class_col_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	class_col.add_child(class_col_title)

	for c_id in [1, 2, 3, 4]:
		var c_data: Dictionary = CLASSES_DATA[c_id]
		var btn := _create_card_button(c_id, c_data["name"], c_data["style"], "HP Base: %d | Stamina: %d" % [c_data["hp_base"], c_data["stam_base"]], c_data["color"], false)
		class_col.add_child(btn)
		class_buttons[c_id] = btn

	# Painel Inferior: Resumo Detalhado Dinâmico
	var summary_panel := PanelContainer.new()
	var sum_style := StyleBoxFlat.new()
	sum_style.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	sum_style.border_color = Color(0.35, 0.45, 0.65, 0.5)
	sum_style.set_border_width_all(1)
	sum_style.set_corner_radius_all(6)
	sum_style.content_margin_left = 14
	sum_style.content_margin_right = 14
	sum_style.content_margin_top = 8
	sum_style.content_margin_bottom = 8
	summary_panel.add_theme_stylebox_override("panel", sum_style)
	root_vbox.add_child(summary_panel)

	var sum_vbox := VBoxContainer.new()
	sum_vbox.add_theme_constant_override("separation", 3)
	summary_panel.add_child(sum_vbox)

	summary_title = Label.new()
	summary_title.add_theme_font_size_override("font_size", 13)
	summary_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	sum_vbox.add_child(summary_title)

	stats_breakdown_label = Label.new()
	stats_breakdown_label.add_theme_font_size_override("font_size", 12)
	stats_breakdown_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	sum_vbox.add_child(stats_breakdown_label)

	weapon_details_label = Label.new()
	weapon_details_label.add_theme_font_size_override("font_size", 11)
	weapon_details_label.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))
	sum_vbox.add_child(weapon_details_label)

	skill_details_label = Label.new()
	skill_details_label.add_theme_font_size_override("font_size", 11)
	skill_details_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	sum_vbox.add_child(skill_details_label)

	npc_reaction_label = Label.new()
	npc_reaction_label.add_theme_font_size_override("font_size", 11)
	npc_reaction_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.6))
	sum_vbox.add_child(npc_reaction_label)

	# Botão de Confirmação Grande
	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(0, 42)
	confirm_button.text = "✦  Confirmar Identidade e Entrar em Lunaria [Enter]  ✦"
	confirm_button.add_theme_font_size_override("font_size", 14)
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.25, 0.42, 0.9)
	btn_normal.border_color = Color(0.9, 0.75, 0.3, 0.95)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.18, 0.35, 0.58, 0.95)
	btn_hover.border_color = Color(1.0, 0.9, 0.4, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)

	confirm_button.add_theme_stylebox_override("normal", btn_normal)
	confirm_button.add_theme_stylebox_override("hover", btn_hover)
	confirm_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	confirm_button.pressed.connect(_on_confirm_pressed)
	root_vbox.add_child(confirm_button)

func _create_card_button(id: int, title: String, sub: String, stat_tag: String, accent_col: Color, is_race: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 1)
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_top = 4
	vbox.offset_bottom = -4
	btn.add_child(vbox)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", accent_col)
	row.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var tag_lbl := Label.new()
	tag_lbl.text = stat_tag
	tag_lbl.add_theme_font_size_override("font_size", 11)
	tag_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.9))
	row.add_child(tag_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = sub
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	vbox.add_child(sub_lbl)

	if is_race:
		btn.pressed.connect(func(): _select_race(id))
	else:
		btn.pressed.connect(func(): _select_class(id))

	return btn

func _select_race(race_id: int) -> void:
	selected_race = race_id
	_update_selection_states()
	_update_summary()

func _select_class(class_id: int) -> void:
	selected_class = class_id
	_update_selection_states()
	_update_summary()

func _update_selection_states() -> void:
	for r_id in race_buttons.keys():
		var btn: Button = race_buttons[r_id]
		var is_sel: bool = (r_id == selected_race)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(5)
		if is_sel:
			style.bg_color = Color(0.15, 0.22, 0.35, 0.95)
			style.border_color = Color(0.95, 0.82, 0.35, 1.0)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.08, 0.1, 0.14, 0.8)
			style.border_color = Color(0.25, 0.32, 0.45, 0.4)
			style.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

	for c_id in class_buttons.keys():
		var btn: Button = class_buttons[c_id]
		var is_sel: bool = (c_id == selected_class)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(5)
		if is_sel:
			style.bg_color = Color(0.15, 0.22, 0.35, 0.95)
			style.border_color = Color(0.95, 0.82, 0.35, 1.0)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.08, 0.1, 0.14, 0.8)
			style.border_color = Color(0.25, 0.32, 0.45, 0.4)
			style.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _update_summary() -> void:
	var r_data: Dictionary = RACES_DATA.get(selected_race, RACES_DATA[1])
	var c_data: Dictionary = CLASSES_DATA.get(selected_class, CLASSES_DATA[1])

	var total_hp: int = c_data["hp_base"] + r_data["hp_mod"]
	var total_stam: int = c_data["stam_base"] + r_data["stam_mod"]

	if summary_title:
		summary_title.text = "Identidade Selecionada: [%s] %s" % [r_data["name"], c_data["name"]]

	if stats_breakdown_label:
		stats_breakdown_label.text = "Atributos: Max HP: %d (Base %d %+d Raça)  |  Max Stamina: %d (Base %d %+d Raça)  |  Alcance: %s" % [
			total_hp, c_data["hp_base"], r_data["hp_mod"],
			total_stam, c_data["stam_base"], r_data["stam_mod"],
			c_data["range_desc"]
		]

	if weapon_details_label:
		weapon_details_label.text = "Armamento: %s  |  Passiva Racial: %s" % [c_data["style"], r_data["passive"]]

	if skill_details_label:
		skill_details_label.text = "Habilidade [Q]: %s (Evoluções: %s)" % [c_data["skill_q"], c_data["evolutions"]]

	if npc_reaction_label:
		npc_reaction_label.text = "Reação de Garrick (Ferreiro): %s" % r_data["npc_reaction"]

func _on_confirm_pressed() -> void:
	print("[CharacterSelectUI] Identidade confirmada: Raça %d, Classe %d" % [selected_race, selected_class])
	identity_confirmed.emit(selected_race, selected_class)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.get("my_player_id") and nm.my_player_id > 0:
		nm.send_select_identity(selected_race, selected_class)
	close_menu()
