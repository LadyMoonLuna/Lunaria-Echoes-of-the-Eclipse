extends CanvasLayer

var is_open: bool = false
var report_text: String = ""

var main_panel: PanelContainer = null
var content_label: RichTextLabel = null
var status_label: Label = null

const MOB_DATA := [
	{
		"mob_id": 1,
		"name": "Lobo da Bruma",
		"location": "Bosque Sussurrante (50.0, -45.0)",
		"icon": "🐺",
		"drops": [
			{"item": "Carne Crua de Lobo", "rate": "100.0%", "rare": false},
			{"item": "Pelagem Cinzenta", "rate": "100.0%", "rare": false},
			{"item": "Presa Lupina Afiada", "rate": "25.0%", "rare": false},
			{"item": "Garra de Fera", "rate": "20.0%", "rare": false},
			{"item": "Anel de Presa Ancestral", "rate": "3.0%", "rare": true},
			{"item": "Casulo de Seda Prateada (Item 30 - Aracne)", "rate": "0.1%", "rare": true, "secret": true}
		]
	},
	{
		"mob_id": 2,
		"name": "Saqueador Deserdado",
		"location": "Ruínas da Vigília (-48.0, 42.0)",
		"icon": "🗡️",
		"drops": [
			{"item": "Frasco de Vidro Vazio", "rate": "80.0%", "rare": false},
			{"item": "Carne Nobre Assada", "rate": "70.0%", "rare": false},
			{"item": "Anel de Presa Ancestral", "rate": "4.0%", "rare": true}
		]
	},
	{
		"mob_id": 3,
		"name": "Besteiro da Vigília",
		"location": "Ruínas da Vigília (-48.0, 42.0)",
		"icon": "🏹",
		"drops": [
			{"item": "Frasco de Vidro Vazio", "rate": "80.0%", "rare": false},
			{"item": "Carne Nobre Assada", "rate": "70.0%", "rare": false},
			{"item": "Anel de Presa Ancestral", "rate": "5.0%", "rare": true}
		]
	},
	{
		"mob_id": 4,
		"name": "Acólito do Eclipse",
		"location": "Ruínas da Vigília (-48.0, 42.0)",
		"icon": "🕯️",
		"drops": [
			{"item": "Cálice da Alma Partida (Item 14 - Revenant)", "rate": "0.1%", "rare": true, "secret": true},
			{"item": "Tomo da Foice do Eclipse (Item 17 - Ceifador)", "rate": "0.1%", "rare": true, "secret": true},
			{"item": "Casulo de Seda Prateada (Item 30 - Aracne)", "rate": "0.1%", "rare": true, "secret": true}
		]
	},
	{
		"mob_id": 5,
		"name": "Executor de Ferro",
		"location": "Ruínas da Vigília (-48.0, 42.0)",
		"icon": "🛡️",
		"drops": [
			{"item": "Placa de Aço Pesada", "rate": "60.0%", "rare": false},
			{"item": "Frasco de Vidro Vazio", "rate": "80.0%", "rare": false},
			{"item": "Núcleo de Forja Estelar (Item 18 - Artífice)", "rate": "0.1%", "rare": true, "secret": true}
		]
	},
	{
		"mob_id": 6,
		"name": "Lobo Alfa",
		"location": "Bosque Sussurrante (Noite)",
		"icon": "🌕",
		"drops": [
			{"item": "Pele Intacta de Lobo Alfa", "rate": "100.0%", "rare": false},
			{"item": "Sangue Lunar Puro", "rate": "100.0% (Frasco)", "rare": false},
			{"item": "Anel de Presa Ancestral", "rate": "6.0%", "rare": true}
		]
	},
	{
		"mob_id": 7,
		"name": "Licantropo Alfa (Raid Boss Secreto)",
		"location": "Bosque Sussurrante (Lua de Sangue)",
		"icon": "🩸",
		"drops": [
			{"item": "Coração do Licantropo Alfa", "rate": "100.0%", "rare": false},
			{"item": "Sangue do Progenitor Bestial (Item 16 - Dhampir)", "rate": "0.1% (Frasco)", "rare": true, "secret": true},
			{"item": "Tomo do Martelo Titânico", "rate": "7.0%", "rare": true}
		]
	},
	{
		"mob_id": 10,
		"name": "Cultista Sombrio",
		"location": "Santuário do Eclipse (-72.0, 70.0)",
		"icon": "🔮",
		"drops": [
			{"item": "Frasco de Vidro Vazio", "rate": "60.0%", "rare": false},
			{"item": "Túnica do Cultista Sombrio", "rate": "5.0%", "rare": true},
			{"item": "Tomo da Foice do Eclipse (Item 17)", "rate": "0.1%", "rare": true, "secret": true},
			{"item": "Ampulheta Rúnica (Item 29 - Cronomante)", "rate": "0.1%", "rare": true, "secret": true}
		]
	},
	{
		"mob_id": 11,
		"name": "Gárgula de Pedra",
		"location": "Santuário do Eclipse (-72.0, 70.0)",
		"icon": "🗿",
		"drops": [
			{"item": "Placa de Aço Pesada", "rate": "70.0%", "rare": false},
			{"item": "Coração Pétreo da Gárgula", "rate": "6.0%", "rare": true}
		]
	},
	{
		"mob_id": 12,
		"name": "Inquisidor Vex (Mini-Boss)",
		"location": "Santuário do Eclipse (-72.0, 70.0)",
		"icon": "⛓️",
		"drops": [
			{"item": "Foice Sombria do Inquisidor", "rate": "6.0%", "rare": true},
			{"item": "Cálice da Alma Partida (Item 14)", "rate": "0.1%", "rare": true, "secret": true},
			{"item": "Glândula de Veneno Sombrio", "rate": "100.0% (Frasco)", "rare": false}
		]
	},
	{
		"mob_id": 13,
		"name": "Comandante Vaelen, o Traidor (Boss)",
		"location": "Santuário do Eclipse (-72.0, 70.0)",
		"icon": "⚔️",
		"drops": [
			{"item": "Placa de Aço Pesada", "rate": "100.0%", "rare": false},
			{"item": "Insígnia do Traidor Vaelen", "rate": "5.0%", "rare": true},
			{"item": "Tomo do Martelo Titânico", "rate": "4.0%", "rare": true},
			{"item": "Tomo da Foice do Eclipse (Item 17)", "rate": "0.1%", "rare": true, "secret": true}
		]
	},
	{
		"mob_id": 14,
		"name": "Malakor, o Arauto do Eclipse (Raid Boss 5P)",
		"location": "Santuário do Eclipse (Arena Central)",
		"icon": "🌑",
		"drops": [
			{"item": "Tocha Sagrada do Santuário", "rate": "100.0%", "rare": false},
			{"item": "Olho do Arauto do Eclipse", "rate": "5.0%", "rare": true},
			{"item": "Tomo da Foice do Eclipse (Item 17)", "rate": "0.1%", "rare": true, "secret": true},
			{"item": "Ampulheta Rúnica (Item 29)", "rate": "0.1%", "rare": true, "secret": true}
		]
	}
]

func _ready() -> void:
	layer = 25
	visible = false
	_build_ui()

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)
	_request_server_drop_rates()

func close_menu() -> void:
	is_open = false
	visible = false
	var world := get_parent()
	var any_other_open := false
	if world:
		if world.get("char_select_ui") and world.char_select_ui.get("is_open"): any_other_open = true
		if world.get("attributes_ui") and world.attributes_ui.get("is_open"): any_other_open = true
		if world.get("inventory_ui") and world.inventory_ui.get("is_open"): any_other_open = true
		if world.get("skills_ui") and world.skills_ui.get("is_open"): any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func set_report_text(txt: String) -> void:
	report_text = txt
	if status_label:
		status_label.text = "Status: Sincronizado com o Servidor (TCP 0x3A DEV_GET_DROP_RATES)"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

func _request_server_drop_rates() -> void:
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("send_dev_get_drop_rates"):
		nm.send_dev_get_drop_rates()
	if status_label:
		status_label.text = "Status: Requisitando taxas ao vivo do Servidor Go..."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.02, 0.04, 0.8)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(920, 620)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	p_style.border_color = Color(0.3, 0.7, 1.0, 0.9)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.85)
	p_style.shadow_size = 20
	p_style.content_margin_left = 22
	p_style.content_margin_right = 22
	p_style.content_margin_top = 18
	p_style.content_margin_bottom = 18
	main_panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(vbox)

	# Top Bar
	var top_bar := HBoxContainer.new()
	vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "🛠️ PAINEL DEV — TAXAS DE DROP DO SERVIDOR [TECLA F9]"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var refresh_btn := Button.new()
	refresh_btn.text = " 🔄 Sincronizar Servidor "
	refresh_btn.add_theme_font_size_override("font_size", 11)
	refresh_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	refresh_btn.pressed.connect(_request_server_drop_rates)
	top_bar.add_child(refresh_btn)

	var close_btn := Button.new()
	close_btn.text = " ✕ Fechar "
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	top_bar.add_child(close_btn)

	# Status info
	status_label = Label.new()
	status_label.text = "Status: Ambiente de Teste / Dev-Only (Itens Secretos de Raça/Classe: 0.1% — 1/1000 | Raros: 3% a 6%)"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(status_label)

	vbox.add_child(HSeparator.new())

	# Scroll Container para lista de mobs
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var mob_list_vbox := VBoxContainer.new()
	mob_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mob_list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(mob_list_vbox)

	for m in MOB_DATA:
		var mob_panel := PanelContainer.new()
		var m_style := StyleBoxFlat.new()
		m_style.bg_color = Color(0.09, 0.12, 0.18, 0.95)
		m_style.border_color = Color(0.25, 0.4, 0.6, 0.6)
		m_style.set_border_width_all(1)
		m_style.set_corner_radius_all(6)
		m_style.content_margin_left = 12
		m_style.content_margin_right = 12
		m_style.content_margin_top = 8
		m_style.content_margin_bottom = 8
		mob_panel.add_theme_stylebox_override("panel", m_style)
		mob_list_vbox.add_child(mob_panel)

		var mvbox := VBoxContainer.new()
		mvbox.add_theme_constant_override("separation", 6)
		mob_panel.add_child(mvbox)

		# Header do Mob
		var header_hbox := HBoxContainer.new()
		mvbox.add_child(header_hbox)

		var m_name := Label.new()
		m_name.text = "%s [Mob #%d] %s" % [m["icon"], m["mob_id"], m["name"]]
		m_name.add_theme_font_size_override("font_size", 13)
		m_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		m_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(m_name)

		var m_loc := Label.new()
		m_loc.text = "📍 %s" % m["location"]
		m_loc.add_theme_font_size_override("font_size", 10)
		m_loc.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		header_hbox.add_child(m_loc)

		# Tabela de Itens
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 4)
		mvbox.add_child(grid)

		for d in m["drops"]:
			var item_lbl := Label.new()
			item_lbl.text = "• %s" % d["item"]
			item_lbl.add_theme_font_size_override("font_size", 11)
			if d["rare"]:
				item_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
			else:
				item_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			grid.add_child(item_lbl)

			var rate_lbl := Label.new()
			rate_lbl.text = d["rate"]
			rate_lbl.add_theme_font_size_override("font_size", 11)
			if d["rare"]:
				rate_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
			else:
				rate_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
			grid.add_child(rate_lbl)

			var tag_lbl := Label.new()
			if d.get("secret", false) or d["rate"].begins_with("0.1%"):
				tag_lbl.text = "[SECRETO 0.1% — 1/1000]"
				tag_lbl.add_theme_font_size_override("font_size", 10)
				tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45))
			elif d["rare"]:
				tag_lbl.text = "[RARO / DEV-BALANCED]"
				tag_lbl.add_theme_font_size_override("font_size", 10)
				tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.9))
			else:
				tag_lbl.text = "[Comum / Coleta]"
				tag_lbl.add_theme_font_size_override("font_size", 10)
				tag_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
			grid.add_child(tag_lbl)
