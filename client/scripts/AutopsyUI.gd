extends CanvasLayer

signal autopsy_completed(corpse_id: int)

var is_open: bool = false
var current_corpse_id: int = 0
var current_mob_type: int = 1
var difficulty_seed: int = 0
var organs_data: Array = []
var player_mas_stat: int = 10
var player_luck_stat: int = 10

var selected_organ_index: int = -1
var is_minigame_active: bool = false
var needle_ratio: float = 0.5
var needle_time: float = 0.0
var needle_speed: float = 2.4 # Oscilações harmônicas suaves

# Timers de feedback visual
var feedback_timer: float = 0.0
var feedback_text: String = ""
var feedback_color: Color = Color.WHITE

# Referências de nós da UI
var scrim: ColorRect = null
var main_card: PanelContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var organs_vbox: VBoxContainer = null
var legendary_box: PanelContainer = null
var legendary_btn: Button = null

var minigame_panel: PanelContainer = null
var organ_selected_label: Label = null
var pericia_bonus_label: Label = null
var precision_bar_control: Control = null
var cut_action_btn: Button = null
var feedback_label: Label = null

const MOB_NAMES := {
	1: "Lobo da Bruma",
	2: "Saqueador Deserdado",
	3: "Besteiro da Vigília",
	4: "Acólito do Eclipse",
	5: "Executor de Ferro",
	6: "Lobo Alfa",
	7: "Licantropo Alfa (Boss)",
	10: "Cultista Sombrio",
	11: "Gárgula de Pedra",
	12: "Inquisidor Vex",
	13: "Comandante Vaelen",
	14: "Malakor, o Arauto do Eclipse",
	15: "Aranha Tecelã da Bruma",
	16: "Arachna, a Rainha Tecelã",
	17: "Lodo Ácido Corrosivo",
	18: "Escorpião Abissal Gigante",
	19: "Quimera Costurada Nº 0",
	20: "Golem de Gelo Antigo",
	21: "Draco de Geada Selvagem",
	22: "Ymir, o Patriarca Jotunar",
	23: "Guarda Sanguinário de Vesperian",
	24: "Lorde Vesperian, o Progenitor Vampiro"
}

const ITEM_NAMES := {
	1: "Frasco de Vidro Vazio",
	2: "Carne Crua de Lobo",
	3: "Carne Nobre Assada",
	5: "Pelagem Cinzenta de Lobo",
	6: "Presa Lupina Afiada",
	7: "Garra de Fera",
	8: "Sangue Lupino Fresco",
	9: "Pele Intacta de Lobo Alfa",
	10: "Sangue Lunar Puro",
	11: "Glândula de Veneno Sombrio",
	12: "Placa de Aço Pesada",
	13: "Anel de Presa Ancestral",
	14: "Cálice da Alma Partida",
	15: "Coração do Licantropo Alfa",
	17: "Tomo da Foice do Eclipse",
	18: "Tomo do Martelo Titânico",
	19: "Túnica do Cultista Sombrio",
	20: "Coração Pétreo da Gárgula",
	21: "Foice de Sombras do Inquisidor",
	22: "Insígnia do Comandante Traidor",
	23: "Olho do Arauto do Eclipse",
	24: "Tocha Sagrada do Santuário",
	25: "Minério de Ferro",
	28: "Lixo Orgânico",
	42: "Casulo de Seda Perfeito",
	43: "Coração da Rainha Aranha",
	44: "Olho Multifacetado de Arachna",
	45: "Manto de Seda Imperial",
	46: "Ácido Puro",
	47: "Ferrão de Escorpião Abissal",
	48: "Veneno Vorpal",
	49: "Retalho Quimérico Costurado",
	50: "Núcleo de Gelo Antigo",
	51: "Escama Dracônica Primordial",
	52: "Coração de Geada Eterna",
	53: "Insígnia do Guarda Carmesim",
	54: "Sangue Puro do Progenitor",
	55: "Anel Carmesim de Vesperian"
}

func _ready() -> void:
	layer = 25
	visible = false
	_build_ui()

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.player_attributes_received.connect(_on_attributes_received)

func _on_attributes_received(_pid: int, _xp: int, _nxp: int, _pts: int, _str: int, _dex: int, _con: int, _agi: int, _int: int, _spi: int, mas: int, lck: int) -> void:
	player_mas_stat = mas
	player_luck_stat = lck
	_update_pericia_display()

func open_autopsy(p_corpse_id: int, p_mob_type: int, p_seed: int, p_organs: Array) -> void:
	current_corpse_id = p_corpse_id
	current_mob_type = p_mob_type
	difficulty_seed = p_seed
	organs_data = p_organs

	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)

	_refresh_display()

	# Se nenhum órgão estava selecionado, seleciona o primeiro disponível
	if selected_organ_index < 0:
		for o in organs_data:
			if o.get("quality_tier", 0) == 0 and o.get("type", 1) != 5:
				_select_organ(o.get("index", 0))
				break

func close_menu() -> void:
	is_open = false
	visible = false
	is_minigame_active = false
	selected_organ_index = -1

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
		if world.get("class_master_ui") and world.class_master_ui.get("is_open"):
			any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func _process(delta: float) -> void:
	if not is_open:
		return

	# Animação do Pêndulo Oscilante na barra de precisão
	if is_minigame_active:
		needle_time += delta * needle_speed
		needle_ratio = 0.5 + 0.5 * sin(needle_time)
		if precision_bar_control:
			precision_bar_control.queue_redraw()

	# Fade out do feedback
	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0:
			feedback_text = ""
			if feedback_label:
				feedback_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close_menu()
		get_viewport().set_input_as_handled()
		return

	# Acionamento do corte pelo teclado (Espaço)
	if is_minigame_active and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_execute_cut()
			get_viewport().set_input_as_handled()

func _execute_cut() -> void:
	if not is_minigame_active or selected_organ_index < 0:
		return

	var organ: Dictionary = _get_organ_by_index(selected_organ_index)
	if organ.is_empty():
		return

	var otype: int = organ.get("type", 1)
	var base_green := 0.85
	var base_yellow := 0.50
	if otype == 3: # Glândula
		base_green = 0.88
		base_yellow = 0.55
	elif otype == 5: # Coração / Relíquia
		base_green = 0.90
		base_yellow = 0.60

	# Bônus de Perícia (MAS): +2.5% por ponto investido
	var mas_bonus: float = float(player_mas_stat) * 0.025
	# Passiva Células Gourmet (Mestre do Banquete / Doutor Corvo): Zona Verde 10% maior
	var world := get_parent()
	if world and world.get("my_class_id") != null and (world.my_class_id == 12 or world.my_class_id == 18):
		mas_bonus += 0.10
	var green_threshold: float = max(0.35, base_green - mas_bonus)
	var yellow_threshold: float = max(0.15, base_yellow - (float(player_mas_stat) * 0.015))

	# Precisão: 1.0 no centro (needle_ratio = 0.5), 0.0 nas bordas (needle_ratio = 0.0 ou 1.0)
	var dist_from_center: float = abs(needle_ratio - 0.5) * 2.0
	var accuracy: float = 1.0 - dist_from_center

	var tier: int = 3
	if accuracy >= green_threshold:
		tier = 1 # Perfeito
	elif accuracy >= yellow_threshold:
		# Sorte (LCK): Concede chance passiva de elevar comum para perfeito (+1.5%/ponto)
		var luck_chance: float = min(0.40, float(player_luck_stat) * 0.015)
		if randf() < luck_chance:
			tier = 1 # Elevado pela Sorte!
		else:
			tier = 2 # Comum
	else:
		tier = 3 # Destruído / Zona Vermelha

	# Feedback visual imediato
	var item_name: String = ITEM_NAMES.get(organ.get("item_reward", 0), "Material Anatômico")
	match tier:
		1:
			feedback_text = "★ [PERFEITO] Corte Impecável na Zona Verde!\nVocê obteve: %s (Qualidade Máxima)!" % item_name
			feedback_color = Color("#00e676")
		2:
			feedback_text = "[COMUM] Corte Aceitável na Zona Amarela.\nMaterial com leves rasgos: %s" % item_name
			feedback_color = Color("#ffb300")
		3:
			feedback_text = "✗ [DESTRUÍDO] O bisturi errou na Zona Vermelha!\nO tecido foi dilacerado e virou Lixo Orgânico!"
			feedback_color = Color("#ef5350")

	feedback_timer = 4.0
	if feedback_label:
		feedback_label.text = feedback_text
		feedback_label.modulate = feedback_color

	# Envia resultado autoritativo ao servidor (0x3D)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_submit_autopsy_result(current_corpse_id, selected_organ_index, tier)

	# Atualiza o órgão localmente
	organ["quality_tier"] = tier
	_refresh_display()

	# Verifica se todos os órgãos foram processados
	_check_all_organs_extracted()

func _claim_legendary_direct(organ_index: int) -> void:
	var organ: Dictionary = _get_organ_by_index(organ_index)
	if organ.is_empty():
		return

	var item_name: String = ITEM_NAMES.get(organ.get("item_reward", 0), "Relíquia Lendária")
	feedback_text = "★ [RELÍQUIA COLETADA] Você recolheu a relíquia sagrada:\n%s (Qualidade Perfeita Garantida)!" % item_name
	feedback_color = Color("#ffd700")
	feedback_timer = 4.0
	if feedback_label:
		feedback_label.text = feedback_text
		feedback_label.modulate = feedback_color

	# Envia diretamente ao servidor com Tier 1 (sem mini-game)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_submit_autopsy_result(current_corpse_id, organ_index, 1)

	organ["quality_tier"] = 1
	_refresh_display()
	_check_all_organs_extracted()

func _check_all_organs_extracted() -> void:
	var all_done := true
	for o in organs_data:
		if o.get("quality_tier", 0) == 0:
			all_done = false
			break

	if all_done:
		feedback_text = "✓ [DISSECAÇÃO CONCLUÍDA] Todos os órgãos foram extraídos com sucesso!\nO corpo se decompõe completamente no solo."
		feedback_color = Color("#4fc3f7")
		feedback_timer = 5.0
		if feedback_label:
			feedback_label.text = feedback_text
			feedback_label.modulate = feedback_color

		is_minigame_active = false
		selected_organ_index = -1
		autopsy_completed.emit(current_corpse_id)

func _get_organ_by_index(idx: int) -> Dictionary:
	for o in organs_data:
		if o.get("index", -1) == idx:
			return o
	return {}

func _select_organ(idx: int) -> void:
	var organ := _get_organ_by_index(idx)
	if organ.is_empty() or organ.get("quality_tier", 0) > 0:
		return

	selected_organ_index = idx
	is_minigame_active = true

	# Ajusta velocidade com base na dificuldade do órgão
	var diff: int = organ.get("difficulty", 3)
	needle_speed = 1.8 + float(diff) * 0.15

	_update_minigame_panel()
	_refresh_display()

func _build_ui() -> void:
	# Scrim escuro semi-transparente
	scrim = ColorRect.new()
	scrim.color = Color(0.01, 0.02, 0.04, 0.82)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	main_card = PanelContainer.new()
	main_card.custom_minimum_size = Vector2(980, 620)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.07, 0.10, 0.98)
	card_style.border_color = Color(0.2, 0.65, 0.85, 0.9)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 24
	card_style.content_margin_right = 24
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 20
	main_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(main_card)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	main_card.add_child(root_vbox)

	# --- 1. CABEÇALHO ---
	var header_hbox := HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)

	title_label = Label.new()
	title_label.text = "🔬 MESA ANATÔMICA — DISSECAÇÃO & AUTÓPSIA CIRÚRGICA"
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", Color("#00e5ff"))
	title_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Examine a anatomia da criatura e realize cortes de precisão para extrair peles, presas, sangues e relíquias intactas."
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color("#90a4ae"))
	title_vbox.add_child(subtitle_label)

	var close_btn := Button.new()
	close_btn.text = "  [X] Fechar  "
	close_btn.pressed.connect(close_menu)
	close_btn.custom_minimum_size = Vector2(90, 34)
	var btn_st := StyleBoxFlat.new()
	btn_st.bg_color = Color(0.15, 0.08, 0.10, 0.9)
	btn_st.border_color = Color(0.8, 0.2, 0.2, 0.8)
	btn_st.set_border_width_all(1)
	btn_st.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", btn_st)
	header_hbox.add_child(close_btn)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# --- 2. CORPO PRINCIPAL (2 COLUNAS) ---
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 24)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body_hbox)

	# --- COLUNA ESQUERDA: ANATOMIA E PONTOS VITAIS ---
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(440, 0)
	left_vbox.add_theme_constant_override("separation", 10)
	body_hbox.add_child(left_vbox)

	var left_head := Label.new()
	left_head.text = "PONTOS VITAIS DA CRIATURA"
	left_head.add_theme_font_size_override("font_size", 15)
	left_head.add_theme_color_override("font_color", Color("#ffca28"))
	left_vbox.add_child(left_head)

	# Painel de Item Lendário Garantido (se houver)
	legendary_box = PanelContainer.new()
	var leg_style := StyleBoxFlat.new()
	leg_style.bg_color = Color(0.18, 0.12, 0.04, 0.9)
	leg_style.border_color = Color(1.0, 0.8, 0.2, 0.95)
	leg_style.set_border_width_all(2)
	leg_style.set_corner_radius_all(8)
	leg_style.content_margin_left = 12
	leg_style.content_margin_right = 12
	leg_style.content_margin_top = 10
	leg_style.content_margin_bottom = 10
	legendary_box.add_theme_stylebox_override("panel", leg_style)
	left_vbox.add_child(legendary_box)
	legendary_box.visible = false

	var leg_vbox := VBoxContainer.new()
	leg_vbox.add_theme_constant_override("separation", 6)
	legendary_box.add_child(leg_vbox)

	var leg_title := Label.new()
	leg_title.text = "★ RELÍQUIA / ITEM LENDÁRIO GARANTIDO ★"
	leg_title.add_theme_font_size_override("font_size", 13)
	leg_title.add_theme_color_override("font_color", Color("#ffd54f"))
	leg_vbox.add_child(leg_title)

	legendary_btn = Button.new()
	legendary_btn.text = "Coletar Relíquia Diretamente"
	legendary_btn.custom_minimum_size = Vector2(0, 36)
	var leg_btn_st := StyleBoxFlat.new()
	leg_btn_st.bg_color = Color(0.8, 0.6, 0.1, 0.95)
	leg_btn_st.set_corner_radius_all(6)
	legendary_btn.add_theme_stylebox_override("normal", leg_btn_st)
	legendary_btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	leg_vbox.add_child(legendary_btn)

	# Container com Scroll para a lista dos 4 Pontos Vitais
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	organs_vbox = VBoxContainer.new()
	organs_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	organs_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(organs_vbox)

	# --- COLUNA DIREITA: MINI-GAME DO PÊNDULO / PRECISÃO ---
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 14)
	body_hbox.add_child(right_vbox)

	var right_head := Label.new()
	right_head.text = "DISSECAÇÃO CIRÚRGICA (PRECISÃO ANATÔMICA)"
	right_head.add_theme_font_size_override("font_size", 15)
	right_head.add_theme_color_override("font_color", Color("#4dd0e1"))
	right_vbox.add_child(right_head)

	minigame_panel = PanelContainer.new()
	var mg_style := StyleBoxFlat.new()
	mg_style.bg_color = Color(0.03, 0.04, 0.07, 0.95)
	mg_style.border_color = Color(0.18, 0.28, 0.4, 0.8)
	mg_style.set_border_width_all(1)
	mg_style.set_corner_radius_all(10)
	mg_style.content_margin_left = 18
	mg_style.content_margin_right = 18
	mg_style.content_margin_top = 16
	mg_style.content_margin_bottom = 16
	minigame_panel.add_theme_stylebox_override("panel", mg_style)
	right_vbox.add_child(minigame_panel)

	var mg_vbox := VBoxContainer.new()
	mg_vbox.add_theme_constant_override("separation", 12)
	minigame_panel.add_child(mg_vbox)

	organ_selected_label = Label.new()
	organ_selected_label.text = "Selecione um ponto vital na coluna à esquerda para iniciar o corte."
	organ_selected_label.add_theme_font_size_override("font_size", 14)
	organ_selected_label.add_theme_color_override("font_color", Color("#ffffff"))
	mg_vbox.add_child(organ_selected_label)

	pericia_bonus_label = Label.new()
	pericia_bonus_label.text = "Perícia (MAS 10): +25.0% de margem na Zona Verde!"
	pericia_bonus_label.add_theme_font_size_override("font_size", 12)
	pericia_bonus_label.add_theme_color_override("font_color", Color("#69f0ae"))
	mg_vbox.add_child(pericia_bonus_label)

	# Barra Customizada desenhada com _draw
	precision_bar_control = Control.new()
	precision_bar_control.custom_minimum_size = Vector2(420, 52)
	precision_bar_control.draw.connect(_on_draw_precision_bar)
	mg_vbox.add_child(precision_bar_control)

	# Legenda das Zonas
	var legend_hbox := HBoxContainer.new()
	legend_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg_vbox.add_child(legend_hbox)

	var l_red := Label.new()
	l_red.text = "Vermelha (Erro/Lixo)"
	l_red.add_theme_font_size_override("font_size", 11)
	l_red.add_theme_color_override("font_color", Color("#ef5350"))
	legend_hbox.add_child(l_red)

	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend_hbox.add_child(spacer1)

	var l_green := Label.new()
	l_green.text = "★ Verde (Perfeito) ★"
	l_green.add_theme_font_size_override("font_size", 11)
	l_green.add_theme_color_override("font_color", Color("#00e676"))
	legend_hbox.add_child(l_green)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend_hbox.add_child(spacer2)

	var l_yellow := Label.new()
	l_yellow.text = "Amarela (Comum)"
	l_yellow.add_theme_font_size_override("font_size", 11)
	l_yellow.add_theme_color_override("font_color", Color("#ffb300"))
	legend_hbox.add_child(l_yellow)

	# Botão de Ação / Corte
	cut_action_btn = Button.new()
	cut_action_btn.text = "⚡ CORTAR NO PONTO EXATO [ESPAÇO] ⚡"
	cut_action_btn.custom_minimum_size = Vector2(0, 44)
	cut_action_btn.pressed.connect(_execute_cut)
	var cut_style := StyleBoxFlat.new()
	cut_style.bg_color = Color(0.08, 0.35, 0.55, 0.95)
	cut_style.border_color = Color(0.2, 0.75, 1.0, 0.9)
	cut_style.set_border_width_all(2)
	cut_style.set_corner_radius_all(8)
	cut_action_btn.add_theme_stylebox_override("normal", cut_style)
	cut_action_btn.add_theme_font_size_override("font_size", 14)
	mg_vbox.add_child(cut_action_btn)

	# Caixa de Feedback de Resultado
	feedback_label = Label.new()
	feedback_label.text = ""
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 14)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(feedback_label)

func _update_pericia_display() -> void:
	if pericia_bonus_label == null:
		return
	var bonus: float = float(player_mas_stat) * 2.5
	pericia_bonus_label.text = "Perícia Cirúrgica (MAS %d): Zona Verde ampliada em +%.1f%% | Sorte (LCK %d)" % [player_mas_stat, bonus, player_luck_stat]

func _update_minigame_panel() -> void:
	if organ_selected_label == null:
		return

	if selected_organ_index < 0:
		organ_selected_label.text = "Nenhum órgão selecionado. Escolha um na lista à esquerda."
		cut_action_btn.disabled = true
		return

	var organ := _get_organ_by_index(selected_organ_index)
	var item_name: String = ITEM_NAMES.get(organ.get("item_reward", 0), "Item")
	var diff: int = organ.get("difficulty", 3)
	organ_selected_label.text = "Extraindo: %s (Recompensa: %s | Dificuldade: %d/10)" % [organ.get("name", "Órgão"), item_name, diff]
	cut_action_btn.disabled = false
	_update_pericia_display()

func _refresh_display() -> void:
	var m_name: String = MOB_NAMES.get(current_mob_type, "Criatura")
	if title_label:
		title_label.text = "🔬 MESA ANATÔMICA — %s" % m_name.to_upper()
	if subtitle_label:
		subtitle_label.text = "Cadáver #%d | Semente de Dificuldade: #%d | Perícia MAS: %d" % [current_corpse_id, difficulty_seed, player_mas_stat]

	_update_pericia_display()
	_update_minigame_panel()

	# Reconstrói os botões dos órgãos vitais na lista da esquerda
	if organs_vbox:
		for child in organs_vbox.get_children():
			child.queue_free()

		var has_legendary := false

		for o in organs_data:
			var idx: int = o.get("index", 0)
			var otype: int = o.get("type", 1)
			var item_id: int = o.get("item_reward", 0)
			var item_name: String = ITEM_NAMES.get(item_id, "Material")
			var qtier: int = o.get("quality_tier", 0)

			# Se for item lendário/relíquia (tipo 5), posiciona na caixa de destaque
			if otype == 5:
				has_legendary = true
				if legendary_box:
					legendary_box.visible = true
					if qtier > 0:
						legendary_btn.text = "✓ %s [JÁ COLETADO]" % item_name
						legendary_btn.disabled = true
					else:
						legendary_btn.text = "★ Coletar Diretamente: %s ★" % item_name
						legendary_btn.disabled = false
						legendary_btn.pressed.disconnect(_claim_legendary_direct) if legendary_btn.pressed.is_connected(_claim_legendary_direct) else null
						legendary_btn.pressed.connect(func(): _claim_legendary_direct(idx))
				continue

			# Card interativo de Ponto Vital
			var organ_btn := Button.new()
			organ_btn.custom_minimum_size = Vector2(0, 52)

			var o_style := StyleBoxFlat.new()
			o_style.set_corner_radius_all(8)
			o_style.set_border_width_all(1)

			var status_str := ""
			if qtier == 1:
				status_str = " [✓ PERFEITO]"
				o_style.bg_color = Color(0.04, 0.16, 0.08, 0.9)
				o_style.border_color = Color("#00e676")
				organ_btn.disabled = true
			elif qtier == 2:
				status_str = " [✓ COMUM]"
				o_style.bg_color = Color(0.18, 0.14, 0.04, 0.9)
				o_style.border_color = Color("#ffb300")
				organ_btn.disabled = true
			elif qtier == 3:
				status_str = " [✗ DESTRUÍDO]"
				o_style.bg_color = Color(0.18, 0.06, 0.06, 0.9)
				o_style.border_color = Color("#ef5350")
				organ_btn.disabled = true
			else:
				if idx == selected_organ_index:
					status_str = " ➔ [SELECIONADO]"
					o_style.bg_color = Color(0.08, 0.25, 0.40, 0.95)
					o_style.border_color = Color("#00e5ff")
				else:
					status_str = " [DISPONÍVEL]"
					o_style.bg_color = Color(0.06, 0.09, 0.14, 0.9)
					o_style.border_color = Color(0.2, 0.35, 0.5, 0.8)

			organ_btn.add_theme_stylebox_override("normal", o_style)
			organ_btn.add_theme_stylebox_override("hover", o_style)
			organ_btn.add_theme_stylebox_override("disabled", o_style)

			var organ_type_name := _get_organ_type_name(otype)
			organ_btn.text = "%s: %s%s" % [organ_type_name, item_name, status_str]
			organ_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

			if qtier == 0:
				organ_btn.pressed.connect(func(): _select_organ(idx))

			organs_vbox.add_child(organ_btn)

		if not has_legendary and legendary_box:
			legendary_box.visible = false

func _get_organ_type_name(otype: int) -> String:
	match otype:
		1: return "Pele Dorsal"
		2: return "Presas / Garras"
		3: return "Glândula de Veneno"
		4: return "Sangue / Fluidos"
		5: return "Coração / Relíquia"
		_: return "Ponto Vital"

# Desenho visual em tempo real da Barra Colorida e do Pêndulo
func _on_draw_precision_bar() -> void:
	if precision_bar_control == null:
		return

	var rect := Rect2(Vector2.ZERO, precision_bar_control.size)
	var w: float = rect.size.x
	var h: float = rect.size.y

	# Se nenhum órgão estiver selecionado, desenha barra apagada
	if selected_organ_index < 0 or not is_minigame_active:
		precision_bar_control.draw_rect(rect, Color(0.1, 0.12, 0.15, 0.8), true)
		return

	var organ := _get_organ_by_index(selected_organ_index)
	var otype: int = organ.get("type", 1)
	var base_green := 0.85
	var base_yellow := 0.50
	if otype == 3:
		base_green = 0.88
		base_yellow = 0.55
	elif otype == 5:
		base_green = 0.90
		base_yellow = 0.60

	# Perícia (MAS): amplia a Zona Verde em +2.5% por ponto
	var mas_bonus: float = float(player_mas_stat) * 0.025
	var green_threshold: float = max(0.35, base_green - mas_bonus)
	var yellow_threshold: float = max(0.15, base_yellow - (float(player_mas_stat) * 0.015))

	# Metade da largura visual das zonas (centradas em 0.5)
	var green_half_ratio: float = (1.0 - green_threshold) * 0.5
	var yellow_half_ratio: float = (1.0 - yellow_threshold) * 0.5

	var x_center: float = w * 0.5
	var green_w: float = green_half_ratio * 2.0 * w
	var green_x: float = x_center - (green_half_ratio * w)

	var yellow_left_w: float = (yellow_half_ratio - green_half_ratio) * w
	var yellow_left_x: float = x_center - (yellow_half_ratio * w)
	var yellow_right_x: float = green_x + green_w

	# 1. Zona Vermelha (Erro) em toda a extensão
	precision_bar_control.draw_rect(rect, Color("#d32f2f"), true) # Vermelho escuro

	# 2. Zona Amarela (Comum) intermediária
	if yellow_left_w > 0:
		precision_bar_control.draw_rect(Rect2(yellow_left_x, 0, yellow_left_w, h), Color("#ffb300"), true)
		precision_bar_control.draw_rect(Rect2(yellow_right_x, 0, yellow_left_w, h), Color("#ffb300"), true)

	# 3. Zona Verde (Perfeita) no centro
	precision_bar_control.draw_rect(Rect2(green_x, 0, green_w, h), Color("#00e676"), true)

	# Linhas divisórias elegantes
	precision_bar_control.draw_line(Vector2(green_x, 0), Vector2(green_x, h), Color(1, 1, 1, 0.6), 1.5)
	precision_bar_control.draw_line(Vector2(green_x + green_w, 0), Vector2(green_x + green_w, h), Color(1, 1, 1, 0.6), 1.5)

	# Borda externa da barra
	precision_bar_control.draw_rect(rect, Color(0.2, 0.7, 0.9, 0.8), false, 2.0)

	# 4. Agulha / Pêndulo Oscilante
	var needle_x: float = clamp(needle_ratio * w, 2.0, w - 2.0)
	# Traço brilhante da agulha
	precision_bar_control.draw_line(Vector2(needle_x, -4), Vector2(needle_x, h + 4), Color("#ffffff"), 3.5)
	precision_bar_control.draw_line(Vector2(needle_x, 0), Vector2(needle_x, h), Color("#00e5ff"), 2.0)

	# Marcador em seta na ponta da agulha
	var arrow_pts: PackedVector2Array = [
		Vector2(needle_x - 5, -5),
		Vector2(needle_x + 5, -5),
		Vector2(needle_x, 0)
	]
	precision_bar_control.draw_colored_polygon(arrow_pts, Color("#ffffff"))
