extends CanvasLayer

var is_open: bool = false
var equipped_slots: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var equipped_armor_id: int = 0
var equipped_acc_id: int = 0
var inventory_items: Array = [] # Array of {"id": int, "quantity": int}

var slot_nodes: Array = [] # Array of Dictionary {"name_label": Label, "item_label": Label, "icon": ColorRect}
var stats_bonus_label: Label = null
var items_container: VBoxContainer = null
var empty_label: Label = null

const SLOT_NAMES := [
	"Capacete",
	"Peitoral",
	"Calças",
	"Botas",
	"Luvas",
	"Cinto",
	"Colar",
	"Anel 1 (Esq)",
	"Anel 2 (Esq)",
	"Anel 3 (Dir)",
	"Anel 4 (Dir)",
	"Capa / Manto"
]

const SLOT_ICONS := [
	"🪖",
	"🛡️",
	"👖",
	"👢",
	"🧤",
	"🥋",
	"📿",
	"💍",
	"💍",
	"💍",
	"💍",
	"🧣"
]

const ITEM_CATALOG := {
	1: {
		"name": "Frasco de Vidro Vazio",
		"category": "Utilitário Anatômico",
		"desc": "Essencial na mochila: frasco hermético que coleta automaticamente Sangues, Venenos e Elixires ao abater feras.",
		"color": Color("#80deea"),
		"usable": false,
		"btn_text": ""
	},
	2: {
		"name": "Carne Crua de Lobo",
		"category": "Consumível",
		"desc": "Pedaço de carne fresca de predador. Recupera +45 HP instantaneamente.",
		"color": Color("#ef5350"),
		"usable": true,
		"btn_text": "[Consumir (+45 HP)]"
	},
	3: {
		"name": "Carne Nobre Assada",
		"category": "Consumível",
		"desc": "Banquete substancioso assado ao fogo. Recupera +90 HP e +40 Stamina.",
		"color": Color("#ff7043"),
		"usable": true,
		"btn_text": "[Consumir (+90 HP/Stam)]"
	},
	4: {
		"name": "Poção de Sangue Lupino",
		"category": "Elixir Alquímico",
		"desc": "Tônico da fúria das matas: concede +20% Velocidade de Movimento e Crítico por 20 segundos.",
		"color": Color("#d32f2f"),
		"usable": true,
		"btn_text": "[Beber Elixir (+20% Buff)]"
	},
	5: {
		"name": "Pelagem Cinzenta de Lobo",
		"category": "Material Anatômico",
		"desc": "Pelo denso e espesso de lobo da bruma. Matéria-prima nobre para reforço de couro e forjas.",
		"color": Color("#90a4ae"),
		"usable": false,
		"btn_text": ""
	},
	6: {
		"name": "Presa Lupina Afiada",
		"category": "Material Anatômico",
		"desc": "Presa de predador da floresta. Essencial para a confecção de pontas de flecha e adagas perfurantes.",
		"color": Color("#cfd8dc"),
		"usable": false,
		"btn_text": ""
	},
	7: {
		"name": "Garra de Fera",
		"category": "Material Anatômico",
		"desc": "Garra encurvada e afiada, extraída com perícia anatômica de monstros abatidos.",
		"color": Color("#b0bec5"),
		"usable": false,
		"btn_text": ""
	},
	8: {
		"name": "Sangue Lupino Fresco",
		"category": "Reagente Alquímico",
		"desc": "Coletado em frasco de vidro ao abater lobos. Reagente base para elixires e transmutação.",
		"color": Color("#c62828"),
		"usable": false,
		"btn_text": ""
	},
	9: {
		"name": "Pele Intacta de Lobo Alfa",
		"category": "Peitoral",
		"desc": "Couro magnífico do Lobo Alfa. Bônus quando equipado: +35 HP Máximo e +3 Força (FOR).",
		"color": Color("#42a5f5"),
		"usable": true,
		"btn_text": "[Equipar Peitoral]"
	},
	10: {
		"name": "Sangue Lunar Puro",
		"category": "Reagente Sagrado",
		"desc": "Fluido bioluminescente extraído de lobos alfa sob o luar. Matéria de encantamentos ancestrais.",
		"color": Color("#40c4ff"),
		"usable": false,
		"btn_text": ""
	},
	11: {
		"name": "Glândula de Veneno Sombrio",
		"category": "Reagente Tóxico",
		"desc": "Glândula peçonhenta concentrada. Utilizada em bombas cáusticas de alquimistas e flechas venenosas.",
		"color": Color("#00e676"),
		"usable": false,
		"btn_text": ""
	},
	12: {
		"name": "Placa de Aço Pesada",
		"category": "Peitoral",
		"desc": "Couraça forjada em aço temperado. Bônus quando equipado: +50 HP Máximo e +4 Constituição (CON).",
		"color": Color("#78909c"),
		"usable": true,
		"btn_text": "[Equipar Peitoral]"
	},
	13: {
		"name": "Anel de Presa Ancestral",
		"category": "Anel",
		"desc": "Relíquia entalhada em osso pré-histórico. Bônus quando equipado: +3 Destreza (DES) e +3 Agilidade (AGI).",
		"color": Color("#ffd54f"),
		"usable": true,
		"btn_text": "[Equipar Anel]"
	},
	14: {
		"name": "Cálice da Alma Partida",
		"category": "Relíquia do Abismo",
		"desc": "Artefato sombrio funerário. Se você morrer durante a noite sob o luar carregando este cálice, sua alma renascerá como a Raça Secreta Revenant!",
		"color": Color("#7e57c2"),
		"usable": true,
		"btn_text": "[Equipar / Ritual]"
	},
	15: {
		"name": "Coração do Licantropo Alfa",
		"category": "Colar / Relíquia",
		"desc": "Coração titânico que ainda pulsa com calor feral (+15% Roubo de Vida e +5 em Todos os 8 Atributos).",
		"color": Color("#e91e63"),
		"usable": true,
		"btn_text": "[Equipar Colar Lendário]"
	},
	16: {
		"name": "Sangue do Progenitor Bestial",
		"category": "Reagente Primordial",
		"desc": "Sangue primordial extraído do Licantropo Alfa em frasco de vidro. Ao beber, desperta imediatamente a Linhagem Secreta Dhampir!",
		"color": Color("#d50000"),
		"usable": true,
		"btn_text": "[Beber (Despertar Dhampir)]"
	},
	17: {
		"name": "Tomo da Foice do Eclipse",
		"category": "Artefato Proibido",
		"desc": "Tomo místico selado com as runas da escuridão. Ao consumir, desperta a Classe Secreta 13 — Ceifador do Eclipse!",
		"color": Color("#aa00ff"),
		"usable": true,
		"btn_text": "[Consumir (Despertar Ceifador)]"
	},
	18: {
		"name": "Núcleo de Forja Estelar",
		"category": "Artefato Arcano",
		"desc": "Fragmento de estrela pulsante com energia rúnica. Entregue ao ferreiro Garrick para despertar a Classe Secreta 14 — Artífice Rúnico!",
		"color": Color("#ffab00"),
		"usable": true,
		"btn_text": "[Ativar / Entregar a Garrick]"
	},
	25: {
		"name": "Minério de Ferro",
		"category": "Material de Forja",
		"desc": "Minério denso e puro extraído das rochas de Lunaria. Presente ideal para fortalecer laços com o mestre ferreiro Garrick!",
		"color": Color("#90a4ae"),
		"usable": false,
		"btn_text": ""
	},
	26: {
		"name": "Receita: Malho de Batalha Rúnico",
		"category": "Receita Secreta de Forja",
		"desc": "Diagrama sagrado entregue por Garrick a ferreiros leais. Ao usar, forja o lendário Malho de Batalha Rúnico!",
		"color": Color("#ffd54f"),
		"usable": true,
		"btn_text": "[Forjar Malho Rúnico]"
	},
	27: {
		"name": "Malho de Batalha Rúnico",
		"category": "Luvas / Arma Pesada",
		"desc": "Arma brutal gravada com runas estelares da forja de Garrick (+45 Dano Melee, +8 FOR, +6 CON, +4 MAS).",
		"color": Color("#ffb300"),
		"usable": true,
		"btn_text": "[Equipar Arma Rúnica]"
	},
	28: {
		"name": "Lixo Orgânico",
		"category": "Descarte / Restos",
		"desc": "Restos anatômicos dilacerados após falha crítica na dissecação. Pode ser descartado ou consumido por Myconids!",
		"color": Color("#5d4037"),
		"usable": true,
		"btn_text": "[Consumir (Myconid)]"
	},
	29: {
		"name": "Ampulheta Rúnica",
		"category": "Artefato Temporal Secreto",
		"desc": "Ampulheta que verte areia cintilante contra o fluxo cósmico. Ao usar, desperta a Linhagem Secreta 28 — Errante Temporal (Cronomante)!",
		"color": Color("#ffd54f"),
		"usable": true,
		"btn_text": "[Usar (Despertar Cronomante)]"
	},
	30: {
		"name": "Casulo de Seda Prateada",
		"category": "Artefato Aracnídeo Secreto",
		"desc": "Fio de seda milenar tecido no coração da bruma. Ao consumir, desperta a Linhagem Secreta 21 — Aracne (Tecelão da Bruma)!",
		"color": Color("#eceff1"),
		"usable": true,
		"btn_text": "[Usar (Despertar Aracne)]"
	},
	31: {
		"name": "Elmo de Vigia",
		"category": "Capacete",
		"desc": "Elmo de guarda patrulheiro de Lunaria (+25 Max HP, +2 CON).",
		"color": Color("#78909c"),
		"usable": true,
		"btn_text": "[Equipar Capacete]"
	},
	32: {
		"name": "Peitoral de Aço",
		"category": "Peitoral",
		"desc": "Couraça de placas de aço temperado (+60 Max HP, +5 CON).",
		"color": Color("#90a4ae"),
		"usable": true,
		"btn_text": "[Equipar Peitoral]"
	},
	33: {
		"name": "Calças de Couro Lupino",
		"category": "Calças",
		"desc": "Perneiras flexíveis reforçadas com couro de predador (+30 Max HP, +3 AGI).",
		"color": Color("#8d6e63"),
		"usable": true,
		"btn_text": "[Equipar Calças]"
	},
	34: {
		"name": "Botas Passo-da-Bruma",
		"category": "Botas",
		"desc": "Botas silenciosas impregnadas com essência do nevoeiro (+25 Max HP, +4 AGI, +2 DES).",
		"color": Color("#546e7a"),
		"usable": true,
		"btn_text": "[Equipar Botas]"
	},
	35: {
		"name": "Manoplas de Ferreiro",
		"category": "Luvas",
		"desc": "Luvas pesadas com rebites de latão da forja (+4 FOR, +3 MAS).",
		"color": Color("#ffb74d"),
		"usable": true,
		"btn_text": "[Equipar Luvas]"
	},
	36: {
		"name": "Cinto de Alquimista",
		"category": "Cinto",
		"desc": "Cinto com pequenos frascos e runas de transmutação (+3 INT, +3 SPI).",
		"color": Color("#66bb6a"),
		"usable": true,
		"btn_text": "[Equipar Cinto]"
	},
	37: {
		"name": "Colar da Lua Prateada",
		"category": "Colar",
		"desc": "Amuleto de prata que vibra em sincronia com o ciclo lunar (+4 INT, +4 SPI, +3 LCK).",
		"color": Color("#40c4ff"),
		"usable": true,
		"btn_text": "[Equipar Colar]"
	},
	38: {
		"name": "Anel de Rubi Sanguinário",
		"category": "Anel",
		"desc": "Gema incrustada com sangue coagulado de feras carnívoras (+4 FOR, +3 CON).",
		"color": Color("#e53935"),
		"usable": true,
		"btn_text": "[Equipar Anel]"
	},
	39: {
		"name": "Anel de Obsidiana",
		"category": "Anel",
		"desc": "Aro forjado com vidro vulcânico negro inquebrável (+4 CON, +3 MAS).",
		"color": Color("#424242"),
		"usable": true,
		"btn_text": "[Equipar Anel]"
	},
	40: {
		"name": "Anel Estelar",
		"category": "Anel",
		"desc": "Joia celestial banhada pela poeira das constelações (+3 INT, +4 LCK).",
		"color": Color("#ffd54f"),
		"usable": true,
		"btn_text": "[Equipar Anel]"
	},
	41: {
		"name": "Capa de Pele Alfa",
		"category": "Capa / Manto",
		"desc": "Manto magnífico felpudo extraído do predador alfa (+35 Max HP, +3 FOR, +3 AGI).",
		"color": Color("#5c6bc0"),
		"usable": true,
		"btn_text": "[Equipar Capa]"
	}
}

const ITEM_BONUSES := {
	31: {"hp": 25, "con": 2},
	32: {"hp": 60, "con": 5},
	9:  {"hp": 35, "str": 3},
	12: {"hp": 50, "con": 4},
	33: {"hp": 30, "agi": 3},
	34: {"hp": 25, "agi": 4, "dex": 2},
	35: {"str": 4, "mas": 3},
	27: {"str": 8, "con": 6, "mas": 4},
	36: {"int": 3, "spi": 3},
	37: {"int": 4, "spi": 4, "lck": 3},
	15: {"str": 5, "dex": 5, "con": 5, "agi": 5, "int": 5, "spi": 5, "mas": 5, "lck": 5, "lifesteal": 15},
	13: {"dex": 3, "agi": 3},
	38: {"str": 4, "con": 3},
	39: {"con": 4, "mas": 3},
	40: {"int": 3, "lck": 4},
	41: {"hp": 35, "str": 3, "agi": 3}
}

func _ready() -> void:
	layer = 15
	visible = false
	_build_ui()

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.inventory_updated.connect(_on_inventory_updated)

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
		if world.get("char_select_ui") and world.char_select_ui.get("is_open"): any_other_open = true
		if world.get("attributes_ui") and world.attributes_ui.get("is_open"): any_other_open = true
		if world.get("skills_ui") and world.skills_ui.get("is_open"): any_other_open = true
		if world.get("dev_drop_rates_ui") and world.dev_drop_rates_ui.get("is_open"): any_other_open = true
		if world.get("dev_manager_ui") and world.dev_manager_ui.get("is_open"): any_other_open = true
		if world.get("dev_race_menu_ui") and world.dev_race_menu_ui.get("is_open"): any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func _on_inventory_updated(arg1, arg2 = null, arg3 = null) -> void:
	if arg1 is Array:
		equipped_slots = arg1.duplicate()
		while equipped_slots.size() < 12:
			equipped_slots.append(0)
		if arg2 is Array:
			inventory_items = arg2
	else:
		equipped_armor_id = int(arg1)
		equipped_acc_id = int(arg2) if arg2 != null else 0
		equipped_slots = [0, equipped_armor_id, 0, 0, 0, 0, 0, equipped_acc_id, 0, 0, 0, 0]
		if arg3 is Array:
			inventory_items = arg3
	_update_display()

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.65)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 680)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	p_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.8)
	p_style.shadow_size = 18
	p_style.content_margin_left = 20
	p_style.content_margin_right = 20
	p_style.content_margin_top = 16
	p_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# Cabeçalho com Título e Botão Fechar
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "✦  PAINEL DE PERSONAGEM & INVENTÁRIO (12 SLOTS) [I]  ✦"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	top_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " [X] Fechar (I) "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.35, 0.12, 0.12, 0.85)
	c_style.border_color = Color(0.75, 0.25, 0.25)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", c_style)
	close_btn.pressed.connect(close_menu)
	top_bar.add_child(close_btn)

	# SEÇÃO 1: Grade dos 12 Slots de Equipamento
	var eq_title := Label.new()
	eq_title.text = "EQUIPAMENTOS DO PERSONAGEM (12 SLOTS ATIVOS)"
	eq_title.add_theme_font_size_override("font_size", 12)
	eq_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	root_vbox.add_child(eq_title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	root_vbox.add_child(grid)

	slot_nodes.clear()
	for i in range(12):
		var slot_card := _create_slot_card(i)
		grid.add_child(slot_card["panel"])
		slot_nodes.append(slot_card)

	# BÔNUS SOMADOS DE EQUIPAMENTO
	var bonus_panel := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.10, 0.14, 0.20, 0.85)
	b_style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(6)
	b_style.content_margin_left = 12
	b_style.content_margin_right = 12
	b_style.content_margin_top = 6
	b_style.content_margin_bottom = 6
	bonus_panel.add_theme_stylebox_override("panel", b_style)
	root_vbox.add_child(bonus_panel)

	stats_bonus_label = Label.new()
	stats_bonus_label.text = "✦ BÔNUS SOMADOS DOS EQUIPAMENTOS: Nenhum bônus ativo."
	stats_bonus_label.add_theme_font_size_override("font_size", 12)
	stats_bonus_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	stats_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_panel.add_child(stats_bonus_label)

	# Divisor visual
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.3, 0.4, 0.55, 0.4)
	sep.add_theme_stylebox_override("separator", sep_style)
	root_vbox.add_child(sep)

	# SEÇÃO 2: Mochila e Drops Anatômicos
	var bag_title := Label.new()
	bag_title.text = "MOCHILA & RECURSOS ANATÔMICOS"
	bag_title.add_theme_font_size_override("font_size", 12)
	bag_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	root_vbox.add_child(bag_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	items_container = VBoxContainer.new()
	items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_container.add_theme_constant_override("separation", 6)
	scroll.add_child(items_container)

	empty_label = Label.new()
	empty_label.text = "Sua mochila está vazia. Abata monstros no mapa para coletar itens e equipamentos."
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_font_size_override("font_size", 12)
	empty_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	items_container.add_child(empty_label)

func _create_slot_card(idx: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	p_style.border_color = Color(0.25, 0.38, 0.55, 0.6)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 8
	p_style.content_margin_right = 8
	p_style.content_margin_top = 6
	p_style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(header_hbox)

	var icon_box := ColorRect.new()
	icon_box.custom_minimum_size = Vector2(20, 20)
	icon_box.color = Color(0.2, 0.25, 0.35, 0.8)
	header_hbox.add_child(icon_box)

	var slot_title := Label.new()
	slot_title.text = "%s %d. %s" % [SLOT_ICONS[idx], idx + 1, SLOT_NAMES[idx]]
	slot_title.add_theme_font_size_override("font_size", 11)
	slot_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	slot_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(slot_title)

	var item_lbl := Label.new()
	item_lbl.text = "[Vazio]"
	item_lbl.add_theme_font_size_override("font_size", 11)
	item_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(item_lbl)

	return {
		"panel": panel,
		"title_label": slot_title,
		"item_label": item_lbl,
		"icon": icon_box
	}

func _update_display() -> void:
	# 1. Atualiza os 12 slots visuais de equipamentos
	for i in range(12):
		if i >= slot_nodes.size():
			break
		var node_data: Dictionary = slot_nodes[i]
		var item_id: int = equipped_slots[i] if i < equipped_slots.size() else 0
		var item_lbl: Label = node_data["item_label"]
		var icon_rect: ColorRect = node_data["icon"]

		if item_id > 0 and ITEM_CATALOG.has(item_id):
			var data: Dictionary = ITEM_CATALOG[item_id]
			item_lbl.text = "%s" % data["name"]
			item_lbl.add_theme_color_override("font_color", data["color"])
			icon_rect.color = data["color"]
		else:
			item_lbl.text = "[Vazio]"
			item_lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))
			icon_rect.color = Color(0.18, 0.22, 0.28, 0.7)

	# 2. Calcula bônus somados concedidos pelos 12 equipamentos
	var sum_hp: int = 0
	var sum_str: int = 0
	var sum_dex: int = 0
	var sum_con: int = 0
	var sum_agi: int = 0
	var sum_int: int = 0
	var sum_spi: int = 0
	var sum_mas: int = 0
	var sum_lck: int = 0
	var sum_ls: int = 0

	for id in equipped_slots:
		if id > 0 and ITEM_BONUSES.has(id):
			var b: Dictionary = ITEM_BONUSES[id]
			sum_hp += b.get("hp", 0)
			sum_str += b.get("str", 0)
			sum_dex += b.get("dex", 0)
			sum_con += b.get("con", 0)
			sum_agi += b.get("agi", 0)
			sum_int += b.get("int", 0)
			sum_spi += b.get("spi", 0)
			sum_mas += b.get("mas", 0)
			sum_lck += b.get("lck", 0)
			sum_ls += b.get("lifesteal", 0)

	var bonus_parts: Array = []
	if sum_hp > 0: bonus_parts.append("+%d HP" % sum_hp)
	if sum_str > 0: bonus_parts.append("+%d FOR" % sum_str)
	if sum_dex > 0: bonus_parts.append("+%d DES" % sum_dex)
	if sum_con > 0: bonus_parts.append("+%d CON" % sum_con)
	if sum_agi > 0: bonus_parts.append("+%d AGI" % sum_agi)
	if sum_int > 0: bonus_parts.append("+%d INT" % sum_int)
	if sum_spi > 0: bonus_parts.append("+%d ESP" % sum_spi)
	if sum_mas > 0: bonus_parts.append("+%d PER" % sum_mas)
	if sum_lck > 0: bonus_parts.append("+%d SOR" % sum_lck)
	if sum_ls > 0: bonus_parts.append("+%d%% Roubo de Vida" % sum_ls)

	if stats_bonus_label:
		if bonus_parts.is_empty():
			stats_bonus_label.text = "✦ BÔNUS SOMADOS DE EQUIPAMENTO: Nenhum bônus ativo (Equipe itens da mochila abaixo)."
			stats_bonus_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
		else:
			stats_bonus_label.text = "✦ BÔNUS SOMADOS DE EQUIPAMENTO: " + " | ".join(bonus_parts)
			stats_bonus_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))

	# 3. Atualiza itens da mochila
	if not items_container:
		return

	for child in items_container.get_children():
		if child != empty_label:
			child.queue_free()

	if inventory_items.is_empty():
		if empty_label:
			empty_label.visible = true
		return

	if empty_label:
		empty_label.visible = false

	for slot_data in inventory_items:
		var item_id: int = slot_data.get("id", 0)
		var qty: int = slot_data.get("quantity", 0)
		if qty <= 0:
			continue

		var item_entry := _create_item_row(item_id, qty)
		items_container.add_child(item_entry)

func _create_item_row(item_id: int, qty: int) -> PanelContainer:
	var item_data: Dictionary = ITEM_CATALOG.get(item_id, {
		"name": "Item Desconhecido (#%d)" % item_id,
		"category": "Desconhecido",
		"desc": "Artefato não identificado dos ermos.",
		"color": Color("#ffffff"),
		"usable": false,
		"btn_text": ""
	})

	var row := PanelContainer.new()
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.08, 0.10, 0.15, 0.88)
	var col: Color = item_data["color"]
	r_style.border_color = Color(col.r, col.g, col.b, 0.35)
	r_style.set_border_width_all(1)
	r_style.set_corner_radius_all(6)
	r_style.content_margin_left = 10
	r_style.content_margin_right = 10
	r_style.content_margin_top = 6
	r_style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", r_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var icon_box := ColorRect.new()
	icon_box.custom_minimum_size = Vector2(32, 32)
	icon_box.color = item_data["color"]
	hbox.add_child(icon_box)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "%s  (Qtd: %d)" % [item_data["name"], qty]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", item_data["color"])
	info_vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "[%s] %s" % [item_data["category"], item_data["desc"]]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	info_vbox.add_child(desc_lbl)

	if item_data.get("usable", false):
		var btn := Button.new()
		btn.text = " " + item_data.get("btn_text", "[Usar / Equipar]") + " "
		btn.custom_minimum_size = Vector2(165, 32)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(0.18, 0.28, 0.42, 0.95)
		b_style.border_color = Color(0.45, 0.65, 0.95, 0.85)
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(5)
		btn.add_theme_stylebox_override("normal", b_style)
		btn.pressed.connect(func(): _on_item_used(item_id))
		hbox.add_child(btn)

	return row

func _on_item_used(item_id: int) -> void:
	print("[InventoryUI] Utilizando/equipando Item ID %d..." % item_id)
	var world := get_parent()
	if world and world.has_method("request_class_or_race_change"):
		match item_id:
			16: # Sangue do Progenitor Bestial -> Raça 5 Dhampir
				world.request_class_or_race_change(true, 5, 1, "Dhampir", "ITEM:16")
				return
			17: # Tomo da Foice do Eclipse -> Classe 13 Ceifador do Eclipse (Tier 5)
				world.request_class_or_race_change(false, 13, 5, "Ceifador do Eclipse", "ITEM:17")
				return
			18: # Núcleo de Forja Estelar -> Classe 14 Artífice Rúnico (Tier 5)
				world.request_class_or_race_change(false, 14, 5, "Artífice Rúnico", "ITEM:18")
				return
			29: # Ampulheta Rúnica -> Raça 28 Errante Temporal
				world.request_class_or_race_change(true, 28, 1, "Errante Temporal", "ITEM:29")
				return
			30: # Casulo de Seda Prateada -> Raça 21 Aracne
				world.request_class_or_race_change(true, 21, 1, "Aracne", "ITEM:30")
				return
			44: # Olho Multifacetado de Arachna -> Raça 21 Aracne
				world.request_class_or_race_change(true, 21, 1, "Aracne", "ITEM:44")
				return
			47: # Ferrão de Escorpião Abissal -> Raça 43 Demi-Humano Escorpião
				world.request_class_or_race_change(true, 43, 1, "Demi-Humano Escorpião", "ITEM:47")
				return
			52: # Coração de Geada Eterna -> Raça 31 Gigante de Gelo
				world.request_class_or_race_change(true, 31, 1, "Gigante de Gelo", "ITEM:52")
				return
			54: # Sangue Puro do Progenitor -> Raça 5 Dhampir / Vampiro
				world.request_class_or_race_change(true, 5, 1, "Dhampir / Vampiro", "ITEM:54")
				return

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_use_item(item_id)
