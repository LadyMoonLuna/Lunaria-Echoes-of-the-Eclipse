extends CanvasLayer

signal evolution_accepted(offer_type: int, chosen_option: int)

const ClassPaths = preload("res://scripts/ClassPaths.gd")
var is_open: bool = false
var current_offer_type: int = 1
var option_a_id: int = 0
var option_b_id: int = 0

# Dados das Entidades por Raça Base
const ENTITY_LORE := {
	1: { # Valeriano
		"title": "O Trono Solar & O Sussurro do Éter",
		"lore": "Mortal, seu sangue despertou. Você erguerá o Estandarte Dourado da Ordem como um Solvaren, ou rasgará o espaço como um Aetheris?",
		"opt_a": {
			"id": 11,
			"name": "Solvaren",
			"path": "Caminho da Ordem Solar",
			"color": Color("#ffd700"),
			"skill_z": "[Z] Estandarte Imperial: Onda de luz que cura +45 HP em aliados, restaura +50 Stamina e concede +30% de Dano por 12s.",
			"passive": "Liderança Real: +20% de Stamina máxima e regeneração contínua ininterrupta."
		},
		"opt_b": {
			"id": 12,
			"name": "Aetheris",
			"path": "Caminho do Caos & Espaço",
			"color": Color("#9c27b0"),
			"skill_z": "[Z] Fenda Dimensional: Rasga o espaço, teleportando 6m para frente com explosão de vácuo (dano etéreo puro).",
			"passive": "Corpo Etéreo: 15% de chance de ignorar completamente qualquer ataque físico ou mágico."
		}
	},
	2: { # Noctari
		"title": "O Chamado de Selene & O Véu de Nyx",
		"lore": "Filho das estrelas, a Lua aguarda seu juramento. Você brilhará na luz curativa do Selenarca, ou caminhará invisível como um Nyxara?",
		"opt_a": {
			"id": 21,
			"name": "Selenarca",
			"path": "Caminho da Ordem de Selene",
			"color": Color("#00e5ff"),
			"skill_z": "[Z] Luz Purificadora: Cascata lunar de 6.0m curando +60 HP e cegando inimigos com alto dano sagrado.",
			"passive": "Bênção da Lua: +35% de poder mágico e regeneração contínua sob qualquer fase lunar."
		},
		"opt_b": {
			"id": 22,
			"name": "Nyxara",
			"path": "Caminho do Caos de Nyx",
			"color": Color("#7c4dff"),
			"skill_z": "[Z] Manto das Sombras: Fica invisível por 4s; o próximo golpe desferido causa +100% de Dano Crítico garantido.",
			"passive": "Véu Noturno: +30% de velocidade de movimento e +20% de dano crítico permanente."
		}
	},
	3: { # Kharad
		"title": "O Pai da Forja & O Abismo de Obsidiana",
		"lore": "A bigorna ancestral ressoa! Você gravará sua pele com o aço sagrado do Runakhar, ou deixará o magma ferver como um Pyrokhar?",
		"opt_a": {
			"id": 31,
			"name": "Runakhar",
			"path": "Caminho da Ordem da Bigorna",
			"color": Color("#ffa726"),
			"skill_z": "[Z] Armadura Rúnica Impenetrável: Absorve 80% do dano recebido por 6s e reflete 40% do dano de volta aos agressores.",
			"passive": "Muralha Ancestral: Imune a repulsões e +350 HP Máximo."
		},
		"opt_b": {
			"id": 32,
			"name": "Pyrokhar",
			"path": "Caminho do Caos Magmático",
			"color": Color("#ff3d00"),
			"skill_z": "[Z] Erupção Cataclísmica: Libera uma geiser de magma de 5.5m que incendeia inimigos causando dano contínuo devastador.",
			"passive": "Sangue de Lava: Inimigos que golpearem você corpo-a-corpo sofrem queimaduras de magma."
		}
	},
	4: { # Varkai
		"title": "O Dragão Ancestral & A Fera Sangrenta",
		"lore": "Duas feras rugem em suas veias! Você despertará as chamas reais do Dravarkai, ou entregará sua mente à Ferovar?",
		"opt_a": {
			"id": 41,
			"name": "Dravarkai",
			"path": "Caminho da Ordem Dracônica",
			"color": Color("#e53935"),
			"skill_z": "[Z] Baforada Nobre do Dragão: Cone colossal de chamas dracônicas que derrete armaduras e concede lifesteal.",
			"passive": "Escamas Ancestrais: Reduz dano mágico em 30% e amplifica dano de fogo em 25%."
		},
		"opt_b": {
			"id": 42,
			"name": "Ferovar",
			"path": "Caminho do Caos Sangrento",
			"color": Color("#c2185b"),
			"skill_z": "[Z] Frenesi Lâmina Silente: Salto bestial rasgando o alvo; cura +25 HP por arranhão e aumenta velocidade em 40%.",
			"passive": "Fome Canibal: Abater inimigos restaura 15% do HP e 25% da Stamina instantaneamente."
		}
	},
	5: { # Raças Secretas (Sangrael, Cinerion, Lupharion, Umbryss)
		"title": "Pacto da Entidade Abissal",
		"lore": "Mortal tolo... A escuridão primordial estende a mão. Entregue-se à metamorfose proibida e reclame o poder do abismo!",
		"opt_a": {
			"id": 5,
			"name": "Senhor da Noite Eterna",
			"path": "Caminho do Sangue Puro",
			"color": Color("#b71c1c"),
			"skill_z": "[Z] Drenagem Sanguínea Absoluta: Suga 80 HP de todos os seres em 6.0m e ganha asas de sangue.",
			"passive": "Imortalidade Umbral: +50% de Lifesteal e regeneração permanente."
		},
		"opt_b": {
			"id": 6,
			"name": "Licantropo Alfa Primordial",
			"path": "Caminho da Fera Ancestral",
			"color": Color("#4a148c"),
			"skill_z": "[Z] Rugido Lunar Supremo: Atordoa todos os inimigos por 2s e entra em modo berserker invulnerável.",
			"passive": "Poder do Eclipse: Dobra atributos físicos sob o luar."
		}
	}
}

# Referências de Nós
var scrim: ColorRect = null
var main_panel: PanelContainer = null
var entity_title_label: Label = null
var entity_lore_label: Label = null
var card_a_container: PanelContainer = null
var card_b_container: PanelContainer = null
var card_c_container: PanelContainer = null # Caminhos Evolutivos 3 e 4 (só na escolha de Caminho)
var card_d_container: PanelContainer = null

func _ready() -> void:
	layer = 30
	visible = false
	_build_ui()

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.evolution_offer_received.connect(display_offer)

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
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func display_offer(offer_type: int, opt_a: int, opt_b: int) -> void:
	# Tipo 4: troca de Classe/Raça oferecida pelo servidor (NPC Mestre, Altar, desafio secreto).
	# Vai direto para o modal de confirmação obrigatória do World (A = Classe, B = Raça).
	if offer_type == 4:
		_request_identity_offer_confirmation(opt_a, opt_b)
		return
	current_offer_type = offer_type
	option_a_id = opt_a
	option_b_id = opt_b

	var world := get_parent()
	var player_race: int = 1
	if world and world.get("my_race_id"):
		player_race = world.my_race_id

	_update_offer_content(offer_type, player_race, opt_a, opt_b)
	open_menu()

func _build_ui() -> void:
	scrim = ColorRect.new()
	scrim.color = Color(0.01, 0.02, 0.04, 0.92)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(860, 560)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.06, 0.10, 0.98)
	p_style.border_color = Color(0.95, 0.82, 0.35, 0.95)
	p_style.set_border_width_all(3)
	p_style.set_corner_radius_all(12)
	p_style.shadow_color = Color(0.9, 0.6, 0.1, 0.3)
	p_style.shadow_size = 24
	p_style.content_margin_left = 24
	p_style.content_margin_right = 24
	p_style.content_margin_top = 20
	p_style.content_margin_bottom = 20
	main_panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(root_vbox)

	# Cabeçalho Poético
	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(top_vbox)

	entity_title_label = Label.new()
	entity_title_label.text = "O Trono Solar & O Sussurro do Éter"
	entity_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entity_title_label.add_theme_font_size_override("font_size", 22)
	entity_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	top_vbox.add_child(entity_title_label)

	entity_lore_label = Label.new()
	entity_lore_label.text = "Mortal, seu sangue despertou..."
	entity_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entity_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entity_lore_label.add_theme_font_size_override("font_size", 13)
	entity_lore_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	top_vbox.add_child(entity_lore_label)

	# Separador Místico
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Container dos 2 Caminhos / Cartões Lado a Lado
	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 20)
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cards_hbox)

	card_a_container = PanelContainer.new()
	card_a_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.add_child(card_a_container)

	card_b_container = PanelContainer.new()
	card_b_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.add_child(card_b_container)

	card_c_container = PanelContainer.new()
	card_c_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_c_container.visible = false
	cards_hbox.add_child(card_c_container)

	card_d_container = PanelContainer.new()
	card_d_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_d_container.visible = false
	cards_hbox.add_child(card_d_container)

func _update_offer_content(offer_type: int, player_race: int, opt_a: int, opt_b: int) -> void:
	card_c_container.visible = false
	card_d_container.visible = false
	if offer_type == 1: # Evolução de Raça
		var safe_race: int = player_race
		if not ENTITY_LORE.has(safe_race):
			safe_race = 1
		var lore_data: Dictionary = ENTITY_LORE[safe_race]

		entity_title_label.text = lore_data["title"]
		entity_lore_label.text = "\"%s\"" % lore_data["lore"]

		_build_choice_card(card_a_container, lore_data["opt_a"], true, opt_a if opt_a > 0 else lore_data["opt_a"]["id"])
		_build_choice_card(card_b_container, lore_data["opt_b"], false, opt_b if opt_b > 0 else lore_data["opt_b"]["id"])

	elif offer_type == 2: # Escolha de 1 dos 4 Caminhos Evolutivos da Classe Básica
		var world := get_parent()
		var my_class: int = 1
		if world and world.get("my_class_id"):
			my_class = world.my_class_id
		entity_title_label.text = "Os 4 Caminhos Evolutivos da Guilda"
		entity_lore_label.text = "\"Seu domínio de combate atingiu um novo ápice. Escolha o Caminho deste Tier — a cada novo Tier (níveis 10, 25 e 45) você poderá trocar!\""
		var cards: Array = [card_a_container, card_b_container, card_c_container, card_d_container]
		var path_colors: Array = [Color("#ff7043"), Color("#4fc3f7"), Color("#ffd54f"), Color("#ab47bc")]
		for sub_path in range(1, 5):
			var p_info: Dictionary = ClassPaths.PATHS.get(my_class, {}).get(sub_path, {})
			if p_info.is_empty():
				cards[sub_path - 1].visible = false
				continue
			_build_choice_card(cards[sub_path - 1], {
				"name": "Caminho %d: %s" % [sub_path, p_info["rare"]],
				"path": "%s ➔ %s" % [p_info["rare"], p_info["epic"]],
				"color": path_colors[sub_path - 1],
				"skill_z": "Foco: %s" % p_info["focus"],
				"passive": ClassPaths.pros_cons(my_class, sub_path),
			}, sub_path % 2 == 1, sub_path)

	elif offer_type == 3: # Provação Lendária (Tier 6)
		entity_title_label.text = "Ascensão ao Cataclismo Cósmico (Tier 6)"
		entity_lore_label.text = "\"Você superou a Provação dos Deuses e provou seu valor frente aos horrores do eclipse. O cosmos curva-se diante da sua ascensão!\""

		var opt_leg_info := {
			"name": "Ascensão Lendária Suprema",
			"path": "Despertar do Tier 6 Lendário",
			"color": Color("#ffd700"),
			"skill_z": "Poder Supremo dos Deuses: Todas as habilidades são energizadas com poder cósmico puro.",
			"passive": "+12 Pontos de Status por nível e domínio absoluto dos elementos."
		}
		_build_choice_card(card_a_container, opt_leg_info, true, 6)
		card_b_container.visible = false

func _build_choice_card(container: PanelContainer, info: Dictionary, is_order: bool, return_id: int) -> void:
	container.visible = true
	for ch in container.get_children():
		ch.queue_free()

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.09, 0.14, 0.95)
	card_style.border_color = info["color"]
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	container.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	container.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = info["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", info["color"])
	vbox.add_child(name_lbl)

	var path_lbl := Label.new()
	path_lbl.text = "[ %s ]" % info["path"]
	path_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_lbl.add_theme_font_size_override("font_size", 11)
	path_lbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	vbox.add_child(path_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Skill Z Nova
	var sz_head := Label.new()
	sz_head.text = "⚡ Nova Skill Racial [Tecla Z]:"
	sz_head.add_theme_font_size_override("font_size", 11)
	sz_head.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(sz_head)

	var sz_desc := Label.new()
	sz_desc.text = info["skill_z"]
	sz_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sz_desc.add_theme_font_size_override("font_size", 11)
	sz_desc.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	vbox.add_child(sz_desc)

	# Passiva Nova
	var pass_head := Label.new()
	pass_head.text = "🛡️ Nova Passiva de Linhagem:"
	pass_head.add_theme_font_size_override("font_size", 11)
	pass_head.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	vbox.add_child(pass_head)

	var pass_desc := Label.new()
	pass_desc.text = info["passive"]
	pass_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pass_desc.add_theme_font_size_override("font_size", 11)
	pass_desc.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	vbox.add_child(pass_desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Botão de Aceitação
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.text = "ABRAÇAR A ORDEM" if is_order else "SUCUMBIR AO CAOS"
	btn.add_theme_font_size_override("font_size", 12)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = info["color"].darkened(0.65)
	btn_style.border_color = info["color"]
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)

	var btn_hov := btn_style.duplicate()
	btn_hov.bg_color = info["color"].darkened(0.45)

	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_hov)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	btn.pressed.connect(func(): _on_accept_choice(return_id))
	vbox.add_child(btn)

func _on_accept_choice(chosen_id: int) -> void:
	print("[EntityOfferUI] Escolha confirmada! OfferType: %d, ID Escolhido: %d" % [current_offer_type, chosen_id])
	evolution_accepted.emit(current_offer_type, chosen_id)

	# Evolução de Raça (tipo 1) troca a raça: passa pelo modal de confirmação obrigatória
	var world := get_parent()
	if current_offer_type == 1 and world and world.has_method("request_class_or_race_change"):
		var race_name: String = "Raça #%d" % chosen_id
		var race_names: Array = _world_const(world, "RACE_NAMES")
		if chosen_id < race_names.size():
			race_name = race_names[chosen_id]
		world.request_class_or_race_change(true, chosen_id, 1, race_name, "OFFER:1")
		close_menu()
		return

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_evolution_choice(current_offer_type, chosen_id)

	close_menu()

func _request_identity_offer_confirmation(offered_class_id: int, offered_race_id: int) -> void:
	var world := get_parent()
	if not world or not world.has_method("request_class_or_race_change"):
		return
	var is_race_offer: bool = offered_class_id == 0
	var target_id: int = offered_race_id if is_race_offer else offered_class_id
	var target_tier: int = 1
	if not is_race_offer:
		target_tier = ClassPaths.tier_for_class(offered_class_id) # Única 5 / Lendária 6 (reset de nível)
	var target_name: String = "#%d" % target_id
	var names: Array = _world_const(world, "RACE_NAMES" if is_race_offer else "CLASS_NAMES")
	if target_id < names.size():
		target_name = names[target_id]
	world.request_class_or_race_change(is_race_offer, target_id, target_tier, target_name, "OFFER:4")

# Lê uma lista constante do script do World (RACE_NAMES, CLASS_NAMES); vazia se não existir.
func _world_const(world: Node, const_name: String) -> Array:
	var scr = world.get_script()
	if scr == null:
		return []
	var consts: Dictionary = scr.get_script_constant_map()
	return consts.get(const_name, [])
