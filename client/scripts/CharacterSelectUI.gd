extends CanvasLayer

signal identity_confirmed(race_id: int, class_id: int)

var selected_race: int = 1
var is_open: bool = false

# Metadados Completos das Raças de Lunaria Online
const RACES_DATA := {
	1: {
		"name": "Valeriano",
		"title": "Humano — Nobreza da Coroa Solar",
		"lore": "Descendentes do império solar dourado de Valéria. Disciplinados, honrados e equilibrados em corpo e mente.",
		"color": Color("#4fc3f7"),
		"accent": Color("#ffd54f"),
		"stats": {
			"FOR": 6, "DES": 6, "CON": 6, "AGI": 6,
			"INT": 6, "ESP": 6, "PER": 7, "SOR": 7
		},
		"skill_z_name": "Ímpeto Valeriano",
		"skill_z_desc": "Restaura +40 Stamina, cura +25 HP e concede +25% de dano bônus por 10s (Recarga: 10s).",
		"passive_name": "Fôlego Real",
		"passive_desc": "+15% de regeneração contínua de Stamina em combate.",
		"order_evo": "Alto Valeriano (Ordem: Estandarte Dourado da Coroa, Liderança Imperial)",
		"chaos_evo": "Andarilho do Éter (Caos: Rasga fendas no espaço, distorção e dano etéreo)",
		"npc_reaction": "Garrick: 'Cidadão de Valéria! Nossas forjas forjaram o império. Venha aprender o aço comigo!'"
	},
	2: {
		"name": "Noctari",
		"title": "Elfo da Lua — Guardião Astral do Véu",
		"lore": "Filhos da Noite Eterna e das estrelas cadentes. Canalizadores naturais de energias astrais e magias lunares.",
		"color": Color("#b388ff"),
		"accent": Color("#ea80fc"),
		"stats": {
			"FOR": 4, "DES": 8, "CON": 4, "AGI": 9,
			"INT": 8, "ESP": 8, "PER": 8, "SOR": 5
		},
		"skill_z_name": "Explosão Lunar / Umbral",
		"skill_z_desc": "Onda estelar radial (5.5m) que causa dano mágico elevado e cura +30 HP (Recarga: 10s).",
		"passive_name": "Passo Astral",
		"passive_desc": "+25% de dano e chance crítica sob a noite (dobrado na Lua Cheia).",
		"order_evo": "Arconte Lunar (Ordem: Brilho sagrado de Selene, cura e purificação celestial)",
		"chaos_evo": "Espectro Umbral (Caos: Véu de Nyx, passos invisíveis e emboscada nas trevas)",
		"npc_reaction": "Lyra: 'Ah, sangue Noctari... O luar em suas veias ressoa perfeitamente com a Alquimia!'"
	},
	3: {
		"name": "Kharad",
		"title": "Forjado das Cinzas — Artífice Pétreo da Montanha",
		"lore": "Nascidos nas forjas profundas e fortalezas subterrâneas. Sua pele é dura como granito e seu coração arde como magma.",
		"color": Color("#ffb74d"),
		"accent": Color("#ff9800"),
		"stats": {
			"FOR": 9, "DES": 4, "CON": 9, "AGI": 4,
			"INT": 5, "ESP": 6, "PER": 5, "SOR": 8
		},
		"skill_z_name": "Baluarte Rúnico / Erupção",
		"skill_z_desc": "Onda de choque vulcânica (4.5m) de dano sísmico e escudo de 70% de redução por 5s (Recarga: 10s).",
		"passive_name": "Postura de Rocha",
		"passive_desc": "Reduz passivamente 20% de todo dano recebido e concede firmeza contra atordoamento.",
		"order_evo": "Guardião Rúnico (Ordem: Aço sagrado e runas defensivas intransponíveis)",
		"chaos_evo": "Titã de Obsidiana (Caos: Magma ardente das profundezas e cataclismos de fogo)",
		"npc_reaction": "Garrick: 'Irmão Kharad! O calor da bigorna queima no seu peito! A forja te aguarda!'"
	},
	4: {
		"name": "Varkai",
		"title": "Sangue-Feral — Predador Primordial das Selvas",
		"lore": "Descendentes de linhagens draconianas e lupinas ancestrais. Dotados de sentidos apurados e ferocidade selvagem.",
		"color": Color("#ff5252"),
		"accent": Color("#ff1744"),
		"stats": {
			"FOR": 8, "DES": 7, "CON": 8, "AGI": 8,
			"INT": 3, "ESP": 4, "PER": 7, "SOR": 5
		},
		"skill_z_name": "Sopro Dracônico / Rugido Predatório",
		"skill_z_desc": "Cone frontal feroz (5.5m) de alto impacto com roubo de vida por inimigo atingido (Recarga: 10s).",
		"passive_name": "Sangue Fervilhante",
		"passive_desc": "+20% de dano aumentado e tenacidade quando a vida cair abaixo de 35%.",
		"order_evo": "Soberano Dracônico (Ordem: Chamas reais ancestrais, nobreza e asas de dragão)",
		"chaos_evo": "Fera do Frenesi (Caos: Instinto sanguinário incontrolável e fúria devastadora)",
		"npc_reaction": "Capitão Randel: 'Controle seus instintos ferozes dentro das muralhas, Varkai, e você será um grande trunfo!'"
	},
	29: {
		"name": "Orc",
		"title": "Orc — Guerreiro das Estepes Cinzentas",
		"lore": "Clãs guerreiros das estepes cinzentas. Pele verde-musgo, presas e cicatrizes de honra.",
		"color": Color("#558b2f"),
		"accent": Color("#c5e1a5"),
		"stats": {
			"FOR": 10, "DES": 5, "CON": 9, "AGI": 5,
			"INT": 3, "ESP": 5, "PER": 7, "SOR": 6
		},
		"skill_z_name": "Fúria de Sangue",
		"skill_z_desc": "Cura 15% da Vida e ativa o buff de combate por 8s (Recarga: 25s).",
		"passive_name": "Pele Grossa",
		"passive_desc": "-8% de dano recebido e +12% de dano corpo a corpo.",
		"order_evo": "Sem evolução por enquanto",
		"chaos_evo": "Sem evolução por enquanto",
		"npc_reaction": "Garrick: 'Braços assim nasceram para o martelo, orc!'"
	},
	30: {
		"name": "Goblin",
		"title": "Goblin — Trapaceiro das Cavernas",
		"lore": "Pequenos, espertos e gananciosos. Mestres de armadilhas e fugas impossíveis.",
		"color": Color("#9ccc65"),
		"accent": Color("#ffee58"),
		"stats": {
			"FOR": 4, "DES": 10, "CON": 5, "AGI": 10,
			"INT": 4, "ESP": 4, "PER": 5, "SOR": 8
		},
		"skill_z_name": "Bomba de Fumaça",
		"skill_z_desc": "1s de invulnerabilidade, dano e lentidão em 3,5m (Recarga: 30s).",
		"passive_name": "Sorte do Trapaceiro",
		"passive_desc": "Alta Sorte e Agilidade, Stamina farta.",
		"order_evo": "Sem evolução por enquanto",
		"chaos_evo": "Sem evolução por enquanto",
		"npc_reaction": "Capitão Randel: 'Mantenha as mãos longe dos bolsos alheios, goblin.'"
	},
	31: {
		"name": "Elfo",
		"title": "Elfo — Guardião das Florestas Antigas",
		"lore": "Guardiões das florestas antigas. Olhos aguçados e longevidade de séculos.",
		"color": Color("#81c784"),
		"accent": Color("#ffca28"),
		"stats": {
			"FOR": 4, "DES": 9, "CON": 5, "AGI": 9,
			"INT": 8, "ESP": 6, "PER": 5, "SOR": 4
		},
		"skill_z_name": "Flecha Precisa",
		"skill_z_desc": "Disparo de longo alcance (12m) (Recarga: 12s).",
		"passive_name": "Graça Élfica",
		"passive_desc": "+8% de dano total.",
		"order_evo": "Elfo Solar (Ordem: bênção do sol, fogo radiante)",
		"chaos_evo": "Elfo Lunar (Caos: sombras prateadas da lua)",
		"npc_reaction": "Lyra: 'Um elfo da floresta! As ervas falam bem de você.'"
	}
}

# Referências de Nós UI
var main_panel: PanelContainer = null
var race_cards: Dictionary = {}
var race_title_label: Label = null
var race_subtitle_label: Label = null
var race_lore_label: Label = null
var stats_grid: GridContainer = null
var stat_labels: Dictionary = {}
var skill_z_card: PanelContainer = null
var skill_z_label: Label = null
var passive_card: PanelContainer = null
var passive_label: Label = null
var evo_order_label: Label = null
var evo_chaos_label: Label = null
var npc_reaction_label: Label = null
var traveler_notice_panel: PanelContainer = null
var confirm_button: Button = null

func _ready() -> void:
	layer = 25
	_build_ui()
	_select_race(selected_race)
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
	scrim.color = Color(0.02, 0.03, 0.05, 0.85)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	# Container Central
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	# Painel Principal com Borda Dourada Imperial
	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(980, 620)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	panel_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.8)
	panel_style.shadow_size = 18
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	main_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(root_vbox)

	# Cabeçalho Cinematográfico
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	root_vbox.add_child(header_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "LUNARIA: DESPERTAR DAS LINHAGENS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	header_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "Escolha sua Raça Ancestral. Seu sangue ditará suas habilidades inatas e provações divinas."
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 12)
	subtitle_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	header_vbox.add_child(subtitle_lbl)

	# Seletor das 4 Raças Base (Botões/Cartões Horizontais Grandes)
	var races_hbox := HBoxContainer.new()
	races_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	races_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(races_hbox)

	for rid in [1, 2, 3, 4, 29, 30, 31]:
		var r_info: Dictionary = RACES_DATA[rid]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(170, 56)
		btn.text = "%s\n[%s]" % [r_info["name"].to_upper(), r_info["title"].split("—")[0].strip_edges()]
		btn.add_theme_font_size_override("font_size", 12)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): _select_race(rid))
		races_hbox.add_child(btn)
		race_cards[rid] = btn

	# Área de Detalhes da Linhagem (Dividida em 2 Colunas: Esquerda Atributos & Lore, Direita Habilidades & Evoluções)
	var details_hbox := HBoxContainer.new()
	details_hbox.add_theme_constant_override("separation", 18)
	details_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(details_hbox)

	# COLUNA ESQUERDA: Lore, Subtítulo e Atributos Iniciais
	var col_left := VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 8)
	details_hbox.add_child(col_left)

	var lore_panel := PanelContainer.new()
	var lore_style := StyleBoxFlat.new()
	lore_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	lore_style.border_color = Color(0.3, 0.42, 0.6, 0.5)
	lore_style.set_border_width_all(1)
	lore_style.set_corner_radius_all(6)
	lore_style.content_margin_left = 12
	lore_style.content_margin_right = 12
	lore_style.content_margin_top = 10
	lore_style.content_margin_bottom = 10
	lore_panel.add_theme_stylebox_override("panel", lore_style)
	col_left.add_child(lore_panel)

	var lore_vbox := VBoxContainer.new()
	lore_vbox.add_theme_constant_override("separation", 4)
	lore_panel.add_child(lore_vbox)

	race_title_label = Label.new()
	race_title_label.text = "Linhagem: Valeriano"
	race_title_label.add_theme_font_size_override("font_size", 16)
	race_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lore_vbox.add_child(race_title_label)

	race_subtitle_label = Label.new()
	race_subtitle_label.text = "Humano — Cidadão da Coroa"
	race_subtitle_label.add_theme_font_size_override("font_size", 11)
	race_subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	lore_vbox.add_child(race_subtitle_label)

	race_lore_label = Label.new()
	race_lore_label.text = "Lore da Raça..."
	race_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	race_lore_label.add_theme_font_size_override("font_size", 11)
	race_lore_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	lore_vbox.add_child(race_lore_label)

	# Grid de Atributos Base Iniciais (8 atributos)
	var stats_title := Label.new()
	stats_title.text = "ATRIBUTOS BASE INICIAIS DA RAÇA:"
	stats_title.add_theme_font_size_override("font_size", 11)
	stats_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	col_left.add_child(stats_title)

	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", lore_style)
	col_left.add_child(stats_panel)

	stats_grid = GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 6)
	stats_panel.add_child(stats_grid)

	stat_labels.clear()
	var stat_keys := ["FOR", "DES", "CON", "AGI", "INT", "ESP", "PER", "SOR"]
	for k in stat_keys:
		var slot := PanelContainer.new()
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.15, 0.22, 0.85)
		slot_style.border_color = Color(0.35, 0.45, 0.65, 0.4)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(4)
		slot_style.content_margin_left = 6
		slot_style.content_margin_right = 6
		slot_style.content_margin_top = 4
		slot_style.content_margin_bottom = 4
		slot.add_theme_stylebox_override("panel", slot_style)
		stats_grid.add_child(slot)

		var lbl := Label.new()
		lbl.text = "%s: 10" % k
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		slot.add_child(lbl)
		stat_labels[k] = lbl

	# COLUNA DIREITA: Skill [Z], Passiva Inata, Caminho da Ordem vs Caos, e Reação dos NPCs
	var col_right := VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 8)
	details_hbox.add_child(col_right)

	# Card Skill Z
	skill_z_card = PanelContainer.new()
	var skill_style := StyleBoxFlat.new()
	skill_style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	skill_style.border_color = Color(0.2, 0.7, 0.9, 0.6)
	skill_style.set_border_width_all(1)
	skill_style.set_corner_radius_all(6)
	skill_style.content_margin_left = 12
	skill_style.content_margin_right = 12
	skill_style.content_margin_top = 8
	skill_style.content_margin_bottom = 8
	skill_z_card.add_theme_stylebox_override("panel", skill_style)
	col_right.add_child(skill_z_card)

	var sz_vbox := VBoxContainer.new()
	sz_vbox.add_theme_constant_override("separation", 2)
	skill_z_card.add_child(sz_vbox)

	var sz_head := Label.new()
	sz_head.text = "⚡ HABILIDADE RACIAL ATIVA [TECLA Z]:"
	sz_head.add_theme_font_size_override("font_size", 11)
	sz_head.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	sz_vbox.add_child(sz_head)

	skill_z_label = Label.new()
	skill_z_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_z_label.add_theme_font_size_override("font_size", 11)
	sz_vbox.add_child(skill_z_label)

	# Card Passiva Inata
	passive_card = PanelContainer.new()
	var pass_style := skill_style.duplicate()
	pass_style.border_color = Color(0.4, 0.85, 0.4, 0.6)
	passive_card.add_theme_stylebox_override("panel", pass_style)
	col_right.add_child(passive_card)

	var pass_vbox := VBoxContainer.new()
	pass_vbox.add_theme_constant_override("separation", 2)
	passive_card.add_child(pass_vbox)

	var pass_head := Label.new()
	pass_head.text = "🛡️ PASSIVA DE LINHAGEM INATA:"
	pass_head.add_theme_font_size_override("font_size", 11)
	pass_head.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	pass_vbox.add_child(pass_head)

	passive_label = Label.new()
	passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_label.add_theme_font_size_override("font_size", 11)
	pass_vbox.add_child(passive_label)

	# Card Futuras Evoluções (Ordem vs Caos)
	var evo_card := PanelContainer.new()
	var evo_style := skill_style.duplicate()
	evo_style.border_color = Color(0.85, 0.65, 0.25, 0.6)
	evo_card.add_theme_stylebox_override("panel", evo_style)
	col_right.add_child(evo_card)

	var evo_vbox := VBoxContainer.new()
	evo_vbox.add_theme_constant_override("separation", 4)
	evo_card.add_child(evo_vbox)

	var evo_head := Label.new()
	evo_head.text = "🌌 EVOLUÇÕES CÓSMICAS FUTURAS (NÍVEL 10+):"
	evo_head.add_theme_font_size_override("font_size", 11)
	evo_head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	evo_vbox.add_child(evo_head)

	evo_order_label = Label.new()
	evo_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evo_order_label.add_theme_font_size_override("font_size", 11)
	evo_order_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	evo_vbox.add_child(evo_order_label)

	evo_chaos_label = Label.new()
	evo_chaos_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evo_chaos_label.add_theme_font_size_override("font_size", 11)
	evo_chaos_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.6))
	evo_vbox.add_child(evo_chaos_label)

	# Reação dos NPCs
	npc_reaction_label = Label.new()
	npc_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	npc_reaction_label.add_theme_font_size_override("font_size", 11)
	npc_reaction_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	col_right.add_child(npc_reaction_label)

	# Banner de Explicação Obrigatória do Viajante Sem Classe
	traveler_notice_panel = PanelContainer.new()
	var notice_style := StyleBoxFlat.new()
	notice_style.bg_color = Color(0.16, 0.11, 0.04, 0.95)
	notice_style.border_color = Color(0.95, 0.75, 0.25, 0.9)
	notice_style.set_border_width_all(1)
	notice_style.set_corner_radius_all(6)
	notice_style.content_margin_left = 12
	notice_style.content_margin_right = 12
	notice_style.content_margin_top = 8
	notice_style.content_margin_bottom = 8
	traveler_notice_panel.add_theme_stylebox_override("panel", notice_style)
	root_vbox.add_child(traveler_notice_panel)

	var notice_lbl := Label.new()
	notice_lbl.text = "⚔️ AVISO DE JORNADA: Você iniciará sua jornada como um Viajante (Sem Classe). Procure os Mestres na Vila do Refúgio (Garrick, Lyra, Randel) para aprender sua Classe Básica!"
	notice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_lbl.add_theme_font_size_override("font_size", 11)
	notice_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	traveler_notice_panel.add_child(notice_lbl)

	# Botão de Confirmação da Linhagem
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_hbox)

	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(400, 44)
	confirm_button.text = "DESPERTAR COMO VIAJANTE (CONFIRMAR RAÇA)"
	confirm_button.add_theme_font_size_override("font_size", 13)
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.45, 0.22, 0.95)
	btn_style.border_color = Color(0.4, 0.9, 0.45, 0.95)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	var btn_hov := btn_style.duplicate()
	btn_hov.bg_color = Color(0.25, 0.55, 0.28, 1.0)
	confirm_button.add_theme_stylebox_override("normal", btn_style)
	confirm_button.add_theme_stylebox_override("hover", btn_hov)
	confirm_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	confirm_button.pressed.connect(_on_confirm_pressed)
	footer_hbox.add_child(confirm_button)

func _select_race(rid: int) -> void:
	selected_race = rid
	_update_race_button_states()
	_update_race_details()

func _update_race_button_states() -> void:
	for rid in race_cards.keys():
		var btn: Button = race_cards[rid]
		var r_data: Dictionary = RACES_DATA[rid]
		var is_sel: bool = (rid == selected_race)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4

		if is_sel:
			style.bg_color = r_data["color"].darkened(0.65)
			style.border_color = r_data["accent"]
			style.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		else:
			style.bg_color = Color(0.08, 0.1, 0.15, 0.75)
			style.border_color = Color(0.25, 0.32, 0.45, 0.4)
			style.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _update_race_details() -> void:
	var r_data: Dictionary = RACES_DATA.get(selected_race, RACES_DATA[1])

	if race_title_label:
		race_title_label.text = "Linhagem Ancestral: %s" % r_data["name"]
		race_title_label.add_theme_color_override("font_color", r_data["accent"])

	if race_subtitle_label:
		race_subtitle_label.text = r_data["title"]

	if race_lore_label:
		race_lore_label.text = r_data["lore"]

	if stats_grid:
		var st: Dictionary = r_data["stats"]
		for k in st.keys():
			if stat_labels.has(k):
				stat_labels[k].text = "%s: %d" % [k, st[k]]

	if skill_z_label:
		skill_z_label.text = "%s\n%s" % [r_data["skill_z_name"], r_data["skill_z_desc"]]

	if passive_label:
		passive_label.text = "%s\n%s" % [r_data["passive_name"], r_data["passive_desc"]]

	if evo_order_label:
		evo_order_label.text = "⚖️ Ordem: %s" % r_data["order_evo"]

	if evo_chaos_label:
		evo_chaos_label.text = "🔥 Caos: %s" % r_data["chaos_evo"]

	if npc_reaction_label:
		npc_reaction_label.text = "🗣️ %s" % r_data["npc_reaction"]

	if confirm_button:
		confirm_button.text = "DESPERTAR COMO VIAJANTE (%s)" % r_data["name"].to_upper()

func _on_confirm_pressed() -> void:
	print("[CharacterSelectUI] Linhagem confirmada: Raça %d (Iniciando como Viajante / Sem Classe 0)" % selected_race)
	identity_confirmed.emit(selected_race, 0)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.get("my_player_id") and nm.my_player_id > 0:
		nm.send_select_identity(selected_race, 0, 0)
	close_menu()
