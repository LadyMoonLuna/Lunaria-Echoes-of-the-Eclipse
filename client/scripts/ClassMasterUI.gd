extends CanvasLayer

var is_open: bool = false
var current_npc_id: int = 0
var current_npc_name: String = ""

# Metadados de Treinamento por Mestre NPC
const MASTER_DATA := {
	100: { # Garrick, o Ferreiro
		"title": "Garrick, o Mestre Ferreiro",
		"sub": "Forja da Bigorna Ancestral & Aço Temperado",
		"class_id": 5,
		"class_name": "Ferreiro",
		"greeting": "Pela bigorna sagrada! Você quer aprender a temperar o aço e esmagar crânios de monstros com martelos pesados? Aqui você se tornará um autêntico Ferreiro de Combate!",
		"color": Color("#ff9800")
	},
	103: { # Lyra, a Alquimista
		"title": "Lyra, a Mestra Alquimista",
		"sub": "Transmutação Elemental & Elixires da Vida",
		"class_id": 6,
		"class_name": "Alquimista",
		"greeting": "O equilíbrio dos elementos governa todo o universo! Quer aprender a manipular poções corrosivas de ácido e frascos curativos de éter? Junte-se à arte alquímica!",
		"color": Color("#00e676")
	},
	105: { # Capitão Randel
		"title": "Capitão Randel, Comandante da Guarda",
		"sub": "Mestre da Lâmina & Vanguarda Real",
		"class_id": 1,
		"class_name": "Espadachim",
		"greeting": "A vila precisa de escudos fortes e lâminas afiadas contra os monstros do eclipse! Venha recruta, jure lealdade à vanguarda e torne-se um nobre Espadachim!",
		"color": Color("#64b5f6")
	},
	106: { # Guarda Valen
		"title": "Guarda Valen, Patrulheiro da Vila",
		"sub": "Arquearia Silvana & Rastreamento Primordial",
		"class_id": 2,
		"class_name": "Batedor",
		"greeting": "Passos silenciosos na mata e olhos afiados nas trevas. Quer dominar o arco, flechas perfurantes e armadilhas táticas? Aprenda as artes do Batedor!",
		"color": Color("#69f0ae")
	},
	104: { # Varis, o Mercador Sombrio
		"title": "Varis, o Mercador do Beco Sombrio",
		"sub": "Ceifador do Eclipse & Pactos Proibidos",
		"class_id": 7,
		"class_name": "Ceifador do Eclipse",
		"greeting": "Pssiu... A luz da vila é fraca demais contra o que rasteja lá fora. Se você não tem medo de ceifar almas com uma foice colossal, as sombras o acolherão...",
		"color": Color("#d500f9")
	}
}

# Referências de Nós
var main_panel: PanelContainer = null
var master_title_label: Label = null
var master_sub_label: Label = null
var master_greeting_label: Label = null
var options_vbox: VBoxContainer = null

func _ready() -> void:
	layer = 22
	visible = false
	_build_ui()

func open_master_menu(npc_id: int) -> void:
	current_npc_id = npc_id
	var m_info: Dictionary = MASTER_DATA.get(npc_id, MASTER_DATA[105])
	current_npc_name = m_info["title"]

	_update_display()
	open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)

func close_menu() -> void:
	is_open = false
	visible = false
	var world := get_parent()
	var any_other_open := false
	if world:
		if world.get("char_select_ui") and world.char_select_ui.get("is_open"):
			any_other_open = true
		if world.get("attributes_ui") and world.attributes_ui.get("is_open"):
			any_other_open = true
		if world.get("inventory_ui") and world.inventory_ui.get("is_open"):
			any_other_open = true
		if world.get("skills_ui") and world.skills_ui.get("is_open"):
			any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(720, 500)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	p_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.8)
	p_style.shadow_size = 18
	p_style.content_margin_left = 22
	p_style.content_margin_right = 22
	p_style.content_margin_top = 18
	p_style.content_margin_bottom = 18
	main_panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(root_vbox)

	# Cabeçalho do Mestre
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	root_vbox.add_child(header_vbox)

	master_title_label = Label.new()
	master_title_label.text = "Mestre de Classe"
	master_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	master_title_label.add_theme_font_size_override("font_size", 18)
	master_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	header_vbox.add_child(master_title_label)

	master_sub_label = Label.new()
	master_sub_label.text = "Subtítulo da Profissão"
	master_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	master_sub_label.add_theme_font_size_override("font_size", 11)
	master_sub_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	header_vbox.add_child(master_sub_label)

	root_vbox.add_child(HSeparator.new())

	# Diálogo do Mestre
	var speech_panel := PanelContainer.new()
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	sp_style.border_color = Color(0.3, 0.42, 0.6, 0.5)
	sp_style.set_border_width_all(1)
	sp_style.set_corner_radius_all(6)
	sp_style.content_margin_left = 14
	sp_style.content_margin_right = 14
	sp_style.content_margin_top = 10
	sp_style.content_margin_bottom = 10
	speech_panel.add_theme_stylebox_override("panel", sp_style)
	root_vbox.add_child(speech_panel)

	master_greeting_label = Label.new()
	master_greeting_label.text = "Fala do mestre..."
	master_greeting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	master_greeting_label.add_theme_font_size_override("font_size", 12)
	master_greeting_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	speech_panel.add_child(master_greeting_label)

	# Container de Ações Dinâmicas
	options_vbox = VBoxContainer.new()
	options_vbox.add_theme_constant_override("separation", 10)
	options_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(options_vbox)

	# Rodapé com Atalho de DEV e Fechar
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(footer_hbox)

	var dev_btn := Button.new()
	dev_btn.text = "⚡ [DEV: +10 Níveis Instantâneos]"
	dev_btn.add_theme_font_size_override("font_size", 11)
	dev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var dev_style := StyleBoxFlat.new()
	dev_style.bg_color = Color(0.3, 0.18, 0.45, 0.9)
	dev_style.border_color = Color(0.7, 0.4, 0.9, 0.9)
	dev_style.set_border_width_all(1)
	dev_style.set_corner_radius_all(4)
	dev_btn.add_theme_stylebox_override("normal", dev_style)
	dev_btn.pressed.connect(_on_dev_level_up)
	footer_hbox.add_child(dev_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Despedir-se [Fechar]"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	footer_hbox.add_child(close_btn)

func _update_display() -> void:
	var m_info: Dictionary = MASTER_DATA.get(current_npc_id, MASTER_DATA[105])

	if master_title_label:
		master_title_label.text = m_info["title"]
		master_title_label.add_theme_color_override("font_color", m_info["color"])

	if master_sub_label:
		master_sub_label.text = m_info["sub"]

	if master_greeting_label:
		master_greeting_label.text = "\"%s\"" % m_info["greeting"]

	for ch in options_vbox.get_children():
		ch.queue_free()

	var world := get_parent()
	var my_class: int = 0
	var my_tier: int = 1
	var my_level: int = 1
	var my_race: int = 1
	if world:
		if world.get("my_class_id"): my_class = world.my_class_id
		if world.get("my_class_tier"): my_tier = world.my_class_tier
		if world.get("my_level"): my_level = world.my_level
		if world.get("my_race_id"): my_race = world.my_race_id

	var target_class_id: int = m_info["class_id"]
	var target_class_name: String = m_info["class_name"]

	# Caso 1: Jogador é Viajante Sem Classe (ClassID == 0) -> Aprender Classe Básica
	if my_class == 0:
		var learn_btn := Button.new()
		learn_btn.custom_minimum_size = Vector2(0, 46)
		learn_btn.text = "⚔️ APRENDER CLASSE BÁSICA: %s (TIER 1)" % target_class_name.to_upper()
		learn_btn.add_theme_font_size_override("font_size", 13)
		learn_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = m_info["color"].darkened(0.6)
		bstyle.border_color = m_info["color"]
		bstyle.set_border_width_all(2)
		bstyle.set_corner_radius_all(6)
		learn_btn.add_theme_stylebox_override("normal", bstyle)
		learn_btn.pressed.connect(func(): _learn_class(my_race, target_class_id))
		options_vbox.add_child(learn_btn)

	# Caso 2: Jogador já possui esta classe e pode evoluir caminho
	elif my_class == target_class_id:
		var status_lbl := Label.new()
		status_lbl.text = "Status de Aluno: Você é um %s (Tier %d, Nível %d)." % [target_class_name, my_tier, my_level]
		status_lbl.add_theme_font_size_override("font_size", 12)
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		options_vbox.add_child(status_lbl)

		if my_level >= 10 and my_tier < 4:
			var evo_prompt := Label.new()
			evo_prompt.text = "Seu domínio avançou! Escolha a especialização do seu Caminho:"
			evo_prompt.add_theme_font_size_override("font_size", 11)
			evo_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			options_vbox.add_child(evo_prompt)

			var path_a_btn := Button.new()
			path_a_btn.custom_minimum_size = Vector2(0, 38)
			path_a_btn.text = "⚖️ Evoluir: Caminho da Ordem (Caminho A — Defesa & Liderança)"
			path_a_btn.add_theme_font_size_override("font_size", 11)
			path_a_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			path_a_btn.pressed.connect(func(): _choose_path(1))
			options_vbox.add_child(path_a_btn)

			var path_b_btn := Button.new()
			path_b_btn.custom_minimum_size = Vector2(0, 38)
			path_b_btn.text = "🔥 Evoluir: Caminho do Caos (Caminho B — Dano Ofensivo & Crítico)"
			path_b_btn.add_theme_font_size_override("font_size", 11)
			path_b_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			path_b_btn.pressed.connect(func(): _choose_path(2))
			options_vbox.add_child(path_b_btn)

		if my_tier == 5 and my_level >= 45:
			var leg_btn := Button.new()
			leg_btn.custom_minimum_size = Vector2(0, 42)
			leg_btn.text = "👑 Iniciar / Validar Provação Lendária (Ascensão Tier 6)"
			leg_btn.add_theme_font_size_override("font_size", 12)
			leg_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var leg_style := StyleBoxFlat.new()
			leg_style.bg_color = Color(0.45, 0.28, 0.05, 0.95)
			leg_style.border_color = Color(1.0, 0.85, 0.35, 1.0)
			leg_style.set_border_width_all(2)
			leg_style.set_corner_radius_all(6)
			leg_btn.add_theme_stylebox_override("normal", leg_style)
			leg_btn.pressed.connect(func(): _start_legendary_trial())
			options_vbox.add_child(leg_btn)

	# Caso 3: Jogador possui outra classe básica
	else:
		var other_lbl := Label.new()
		other_lbl.text = "Você já segue a senda marcial de outra classe. Mestres de outras guildas não podem alterar sua classe básica sem um Tomo Secreto de Transmutação."
		other_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		other_lbl.add_theme_font_size_override("font_size", 11)
		other_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
		options_vbox.add_child(other_lbl)

func _learn_class(race_id: int, new_class_id: int) -> void:
	print("[ClassMasterUI] Aprendendo Classe %d com Mestre #%d!" % [new_class_id, current_npc_id])
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.get("my_player_id") and nm.my_player_id > 0:
		nm.send_select_identity(race_id, new_class_id, 0)
	close_menu()

func _choose_path(path_id: int) -> void:
	print("[ClassMasterUI] Caminho %d escolhido no Mestre!" % path_id)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_evolution_choice(2, path_id)
	close_menu()

func _start_legendary_trial() -> void:
	print("[ClassMasterUI] Provação Lendária acionada!")
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_evolution_choice(3, 6)
	close_menu()

func _on_dev_level_up() -> void:
	print("[ClassMasterUI] Botão DEV: Solicitando +10 Níveis ao servidor...")
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_dev_level_up(10)
	# Recarrega opções após 0.2s
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(_update_display)
