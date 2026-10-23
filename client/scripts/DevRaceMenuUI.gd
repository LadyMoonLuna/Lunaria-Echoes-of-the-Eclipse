extends CanvasLayer

var is_open: bool = false
var current_filter: String = "ALL" # ALL, NEW, SECRET, EVOLUTION, BASE
var cards_container: VBoxContainer = null
var status_label: Label = null

const NewRaces = preload("res://scripts/NewRaces.gd")

const RACES_DATA := [
	# Raças Base (1-4)
	{
		"id": 1,
		"group": "BASE",
		"name": "Valeriano",
		"badge": "Base Solar",
		"color": Color("#ffd700"),
		"lore": "Herdeiros da luz de Lunaria. Nobres e equilibrados, prosperam sob a luz do sol e honram códigos de lealdade.",
		"stats": "FOR: 6 | DES: 6 | CON: 6 | AGI: 6 | INT: 6 | ESP: 6 | PER: 7 | SOR: 7",
		"passive": "Linhagem Solar: +10% Regeneração de Stamina durante o dia sob céu limpo.",
		"skill_z": "Bênção Solar [Z]: Pulso radiante que purifica debuffs e concede +15% Velocidade por 6s."
	},
	{
		"id": 2,
		"group": "BASE",
		"name": "Noctari",
		"badge": "Base Lunar",
		"color": Color("#00e5ff"),
		"lore": "Filhos da meia-noite e das fases místicas. Possuem visão aguçada e afinidade mágica sob o luar prateado.",
		"stats": "FOR: 4 | DES: 8 | CON: 4 | AGI: 8 | INT: 9 | ESP: 7 | PER: 5 | SOR: 5",
		"passive": "Sintonia Noturna: +15% de Dano Mágico e Esquiva durante as horas da noite.",
		"skill_z": "Manto da Penumbra [Z]: Salto etéreo para as sombras com invisibilidade por 3s."
	},
	{
		"id": 3,
		"group": "BASE",
		"name": "Kharad",
		"badge": "Base Forja",
		"color": Color("#ff9800"),
		"lore": "Povo subterrâneo esculpido em rocha e metal. Seus corpos resistentes suportam impactos avassaladores.",
		"stats": "FOR: 9 | DES: 4 | CON: 10 | AGI: 3 | INT: 4 | ESP: 6 | PER: 9 | SOR: 5",
		"passive": "Pele Pétrea: Reduz em 15% todo dano físico recebido e imunidade a sangramentos leves.",
		"skill_z": "Bastião Sísmico [Z]: Bate no solo gerando escudo equivalente a 25% do HP Máximo por 5s."
	},
	{
		"id": 4,
		"group": "BASE",
		"name": "Varkai",
		"badge": "Base Feral",
		"color": Color("#ff1744"),
		"lore": "Guerreiros primais com instintos predatórios. Conectados aos espíritos das feras e à caça na floresta.",
		"stats": "FOR: 8 | DES: 7 | CON: 7 | AGI: 8 | INT: 3 | ESP: 4 | PER: 6 | SOR: 7",
		"passive": "Faro Predador: +10% de Chance de Crítico contra alvos com menos de 50% de HP.",
		"skill_z": "Uivo Feral [Z]: Aumenta o dano de ataque em +25% e roubo de vida em +8% por 8s."
	},

	# Secretas Clássicas (5-10)
	{
		"id": 5,
		"group": "SECRET",
		"name": "Dhampir",
		"badge": "Secreta Sangue",
		"color": Color("#d500f9"),
		"lore": "Híbrido de humano e vampiro. Despertado ao beber o Sangue do Progenitor Bestial (Item 16).",
		"stats": "FOR: 8 | DES: 9 | CON: 6 | AGI: 9 | INT: 8 | ESP: 3 | PER: 6 | SOR: 6",
		"passive": "Sede Sanguínea: Cura 10% do dano infligido em todos os golpes corpo a corpo.",
		"skill_z": "Voo Carmesim [Z]: Avanço em forma de névoa de sangue que drena 35 HP dos inimigos próximos."
	},
	{
		"id": 6,
		"group": "SECRET",
		"name": "Licantropo Primordial",
		"badge": "Secreta Feral",
		"color": Color("#ff6f00"),
		"lore": "Linhagem pura da primeira matilha. Desperta sob a Lua de Sangue com o Coração do Licantropo Alfa (Item 15).",
		"stats": "FOR: 12 | DES: 9 | CON: 11 | AGI: 10 | INT: 2 | ESP: 3 | PER: 7 | SOR: 6",
		"passive": "Frenesi Alfa: Cada golpe consecutivo concede +3% de Velocidade de Ataque (acumula até 30%).",
		"skill_z": "Transformação em Alfa [Z]: Metamorfose titânica que dobra o tamanho e concede +50 FOR por 10s."
	},
	{
		"id": 7,
		"group": "SECRET",
		"name": "Revenant",
		"badge": "Secreta Espectral",
		"color": Color("#69f0ae"),
		"lore": "Alma que recusou a morte ao morrer durante a noite carregando o Cálice da Alma Partida (Item 14).",
		"stats": "FOR: 7 | DES: 6 | CON: 9 | AGI: 5 | INT: 9 | ESP: 10 | PER: 6 | SOR: 3",
		"passive": "Imortalidade Residual: Ao receber dano letal, sobrevive com 1 HP e ganha 2s de invulnerabilidade.",
		"skill_z": "Lamento Fúnebre [Z]: Congela o espírito dos inimigos em área por 3s e drena mana/stamina."
	},
	{
		"id": 8,
		"group": "SECRET",
		"name": "Celestino",
		"badge": "Secreta Sagrada",
		"color": Color("#fff59d"),
		"lore": "Ser tocado pela aurora cósmica. Portador de auréola translúcida e purificação angelical.",
		"stats": "FOR: 6 | DES: 6 | CON: 7 | AGI: 7 | INT: 10 | ESP: 12 | PER: 6 | SOR: 8",
		"passive": "Graça Divina: Habilidades de cura são 25% mais potentes e custam metade da Stamina.",
		"skill_z": "Coluna Sagrada [Z]: Feixe de luz celestial do céu que queima demônios e cura aliados."
	},
	{
		"id": 9,
		"group": "SECRET",
		"name": "Abissal",
		"badge": "Secreta Trevas",
		"color": Color("#18ffff"),
		"lore": "Nascido das profundezas insondáveis onde a luz solar jamais alcança. Mestre da entropia escura.",
		"stats": "FOR: 6 | DES: 7 | CON: 8 | AGI: 6 | INT: 12 | ESP: 8 | PER: 6 | SOR: 5",
		"passive": "Abraço do Vazio: Dano sombrio ignora 30% da resistência mágica de todos os monstros.",
		"skill_z": "Buraco Negro Abissal [Z]: Vórtice gravitacional que puxa monstros em 6m e explode em trevas."
	},
	{
		"id": 10,
		"group": "SECRET",
		"name": "Autômato Rúnico",
		"badge": "Secreta Mecânica",
		"color": Color("#00e5ff"),
		"lore": "Constructo forjado pelos antigos arcanistas com núcleo estelar infinito e blindagem mágica.",
		"stats": "FOR: 10 | DES: 5 | CON: 12 | AGI: 4 | INT: 8 | ESP: 6 | PER: 10 | SOR: 4",
		"passive": "Chassi Titânico: Imunidade a atordoamentos, venenos e sangramentos mecânicos.",
		"skill_z": "Sobrecarga de Núcleo [Z]: Emite descarga elétrica em 360 graus causando dano elétrico massivo."
	},

	# Evoluções Ordem e Caos (11-18)
	{
		"id": 11,
		"group": "EVOLUTION",
		"name": "Alto Valeriano",
		"badge": "Evolução Ordem",
		"color": Color("#ffea00"),
		"lore": "Evolução solar pura do Valeriano. Coroado com a coroa de chamas dos reis do alvorecer.",
		"stats": "FOR: 10 | DES: 8 | CON: 9 | AGI: 8 | INT: 9 | ESP: 9 | PER: 9 | SOR: 9",
		"passive": "Soberania Radiante: Dano aumentado em 15% contra criaturas da noite e mortos-vivos.",
		"skill_z": "Julgamento do Alvorecer [Z]: Raio de luz concentrado que incinera o alvo em chamas sagradas."
	},
	{
		"id": 12,
		"group": "EVOLUTION",
		"name": "Andarilho do Éter",
		"badge": "Evolução Caos",
		"color": Color("#ba68c8"),
		"lore": "Evolução caótica do Valeriano que rasgou o véu do tempo-espaço para canalizar o éter.",
		"stats": "FOR: 8 | DES: 10 | CON: 7 | AGI: 12 | INT: 10 | ESP: 8 | PER: 10 | SOR: 10",
		"passive": "Distorção Astral: 20% de chance de esquiva completa através de teleporte microscópico.",
		"skill_z": "Ruptura Dimensional [Z]: Salta instantaneamente 8m para frente deixando rastro cortante."
	},
	{
		"id": 13,
		"group": "EVOLUTION",
		"name": "Arconte Lunar",
		"badge": "Evolução Ordem",
		"color": Color("#00e5ff"),
		"lore": "Evolução mística do Noctari. Canalizador do reflexo prateado das luas sagradas.",
		"stats": "FOR: 5 | DES: 11 | CON: 6 | AGI: 11 | INT: 14 | ESP: 11 | PER: 8 | SOR: 8",
		"passive": "Orbe da Maré: Projéteis mágicos ricocheteiam em um alvo secundário com 50% do dano.",
		"skill_z": "Prisão Lunar [Z]: Cúpula de gelo estelar que imobiliza o alvo por 4s."
	},
	{
		"id": 14,
		"group": "EVOLUTION",
		"name": "Espectro Umbral",
		"badge": "Evolução Caos",
		"color": Color("#7c4dff"),
		"lore": "Evolução sombria do Noctari. Entidade que se fundiu completamente à escuridão infinita.",
		"stats": "FOR: 6 | DES: 13 | CON: 5 | AGI: 14 | INT: 12 | ESP: 9 | PER: 11 | SOR: 9",
		"passive": "Furtividade Eterna: Inimigos demoram 50% a mais para detectar sua presença.",
		"skill_z": "Passo das Sombras [Z]: Aparece instantaneamente atrás do alvo com acerto crítico garantido."
	},
	{
		"id": 15,
		"group": "EVOLUTION",
		"name": "Guardião Rúnico",
		"badge": "Evolução Ordem",
		"color": Color("#ff9800"),
		"lore": "Evolução inabalável do Kharad. Entalhado com runas de contenção dos cataclismos antigos.",
		"stats": "FOR: 13 | DES: 6 | CON: 15 | AGI: 5 | INT: 7 | ESP: 9 | PER: 12 | SOR: 7",
		"passive": "Armadura Inquebrável: Absorve 25% do dano e o converte em ondas de choque defensivas.",
		"skill_z": "Fortaleza Viva [Z]: Imunidade a qualquer empurrão e +40% de Defesa por 8s."
	},
	{
		"id": 16,
		"group": "EVOLUTION",
		"name": "Titã de Obsidiana",
		"badge": "Evolução Caos",
		"color": Color("#ff3d00"),
		"lore": "Evolução vulcânica do Kharad. Sangue transformado em magma escaldante incontrolável.",
		"stats": "FOR: 15 | DES: 5 | CON: 17 | AGI: 4 | INT: 6 | ESP: 7 | PER: 10 | SOR: 6",
		"passive": "Espinhos Magmáticos: Devolve 20% do dano corpo a corpo recebido como dano de fogo.",
		"skill_z": "Terremoto de Magma [Z]: Fissura o chão expelindo jatos de lava em cone frontal."
	},
	{
		"id": 17,
		"group": "EVOLUTION",
		"name": "Soberano Dracônico",
		"badge": "Evolução Ordem",
		"color": Color("#ffd700"),
		"lore": "Evolução do Varkai que despertou o sopro ancestral dos dragões da tempestade.",
		"stats": "FOR: 13 | DES: 10 | CON: 11 | AGI: 11 | INT: 6 | ESP: 7 | PER: 9 | SOR: 10",
		"passive": "Presença Tirânica: Monstros comuns próximos têm sua armadura reduzida em 20%.",
		"skill_z": "Rugido do Dragão [Z]: Atordoa todos os inimigos ao redor por 2.5s e concede dano de fogo."
	},
	{
		"id": 18,
		"group": "EVOLUTION",
		"name": "Fera do Frenesi",
		"badge": "Evolução Caos",
		"color": Color("#ad1457"),
		"lore": "Evolução selvagem do Varkai. Abandonou a razão em troca de instintos destrutivos incomparáveis.",
		"stats": "FOR: 14 | DES: 11 | CON: 10 | AGI: 13 | INT: 4 | ESP: 5 | PER: 10 | SOR: 11",
		"passive": "Sede de Carnificina: Quanto menor o HP atual, maior o dano (+1% Dano para cada 1% HP perdido).",
		"skill_z": "Surto Berserker [Z]: +50% Velocidade de Movimento e Ataques ininterruptos por 6s."
	},

	# 10 Novas Raças com Mecânicas Exclusivas (19-28)
	{
		"id": 19,
		"group": "NEW",
		"name": "Sylvari (Nascido da Seiva)",
		"badge": "✨ Nova Raça 19",
		"color": Color("#4caf50"),
		"lore": "Humanoides vegetais brotados das raízes da Grande Árvore de Lunaria. Possuem clorofila mágica e seiva viva.",
		"stats": "FOR: 5 | DES: 7 | CON: 8 | AGI: 6 | INT: 8 | ESP: 10 | PER: 6 | SOR: 5",
		"passive": "Fotossíntese na Chuva: Regenera +4% Max HP e Stamina por segundo sempre que estiver chovendo no mundo!",
		"skill_z": "Prisão de Raízes [Z]: Faz brotar espinhos e raízes do solo que prendem e sangram inimigos em 5m."
	},
	{
		"id": 20,
		"group": "NEW",
		"name": "Esporiano / Myconid (Véu Fúngico)",
		"badge": "✨ Nova Raça 20",
		"color": Color("#9c27b0"),
		"lore": "Criaturas simbióticas de micélio ancestral. Seu organismo se alimenta de matéria orgânica decomposta.",
		"stats": "FOR: 4 | DES: 5 | CON: 10 | AGI: 4 | INT: 10 | ESP: 9 | PER: 8 | SOR: 5",
		"passive": "Decompositor Anatômico: Pode comer Lixo Orgânico (Item 28) da autópsia para recuperar +80 HP e +50 Stamina!",
		"skill_z": "Nuvem de Esporos [Z]: Libera nuvem tóxica violeta que cega inimigos e regenera a carapaça fúngica."
	},
	{
		"id": 21,
		"group": "NEW",
		"name": "Aracne (Tecelão da Bruma)",
		"badge": "✨ Nova Raça 21",
		"color": Color("#eceff1"),
		"lore": "Híbrido de aranha tecelã e tecelão espectral. Despertado com o Casulo de Seda Prateada (Item 30).",
		"stats": "FOR: 6 | DES: 11 | CON: 5 | AGI: 10 | INT: 7 | ESP: 4 | PER: 12 | SOR: 5",
		"passive": "Precisão de Seda: +35% de Zona Verde no mini-game de Autópsia/Desmantelamento Anatômico!",
		"skill_z": "Disparo de Seda [Z]: Dispara teia que puxa o monstro até seus pés e reduz sua velocidade em 60%."
	},
	{
		"id": 22,
		"group": "NEW",
		"name": "Draconato de Cinzas (Escama-Negra)",
		"badge": "✨ Nova Raça 22",
		"color": Color("#ff6d00"),
		"lore": "Descendentes de dragões que dormem no coração de vulcões de ferro. Escamas negras com veias de lava.",
		"stats": "FOR: 12 | DES: 5 | CON: 12 | AGI: 5 | INT: 8 | ESP: 6 | PER: 6 | SOR: 4",
		"passive": "Afinidade de Forja: Recupera +25 HP/s quando estiver perto do Fogo da Forja do Garrick!",
		"skill_z": "Sopro de Magma [Z]: Cone de chamas vulcânicas escaldantes que queima armaduras inimigas."
	},
	{
		"id": 23,
		"group": "NEW",
		"name": "Quimera (Experimento Costurado)",
		"badge": "✨ Nova Raça 23",
		"color": Color("#76ff03"),
		"lore": "Monstruosidade anatômica costurada por alquimistas heréticos. Absorve traços de tudo o que consome.",
		"stats": "FOR: 9 | DES: 8 | CON: 9 | AGI: 8 | INT: 6 | ESP: 2 | PER: 10 | SOR: 5",
		"passive": "Assimilação Biológica: Comer carnes e órgãos extraídos na autópsia concede buffs aleatórios de atributos!",
		"skill_z": "Sobrecarga Anatômica [Z]: Projeta espinhos ósseos mutantes em 360 graus com dano cáustico."
	},
	{
		"id": 24,
		"group": "NEW",
		"name": "Boreal (Coração de Geada)",
		"badge": "✨ Nova Raça 24",
		"color": Color("#80d8ff"),
		"lore": "Habitantes das geleiras eternas do polo norte de Lunaria. Seus corpos mantêm o zero absoluto.",
		"stats": "FOR: 8 | DES: 6 | CON: 9 | AGI: 5 | INT: 9 | ESP: 8 | PER: 6 | SOR: 4",
		"passive": "Metabolismo Criogênico: Fome e consumo de Stamina 60% mais lentos sob qualquer clima!",
		"skill_z": "Zero Absoluto Congelante [Z]: Congela o chão em anel, paralisando monstros por 3s com geada."
	},
	{
		"id": 25,
		"group": "NEW",
		"name": "Thalassiano (Filho da Maré Negra)",
		"badge": "✨ Nova Raça 25",
		"color": Color("#006064"),
		"lore": "Habitantes das fossas abissais do oceano de Lunaria. Místicos anfíbios em sintonia com tempestades.",
		"stats": "FOR: 7 | DES: 8 | CON: 7 | AGI: 9 | INT: 9 | ESP: 8 | PER: 5 | SOR: 5",
		"passive": "Senhor das Tempestades: +30% de Velocidade de Movimento e Dano elétrico/hídrico durante Tempestades!",
		"skill_z": "Gêiser Abissal [Z]: Irrupção de água de alta pressão que lança inimigos no ar e causa dano contundente."
	},
	{
		"id": 26,
		"group": "NEW",
		"name": "Cambion (Sangue-de-Enxofre)",
		"badge": "✨ Nova Raça 26",
		"color": Color("#c62828"),
		"lore": "Filho de humanos e demônios menores do submundo. Chifres curvos e cheiro de enxofre em brasa.",
		"stats": "FOR: 11 | DES: 8 | CON: 8 | AGI: 7 | INT: 9 | ESP: 2 | PER: 5 | SOR: 6",
		"passive": "Ímpeto do Abatedor: +5% Dano para cada mob próximo a menos de 6m (acumula até +25%).",
		"skill_z": "Correntes do Tártaro [Z]: Correntes incandescentes que laçam monstros e os puxam para o fogo."
	},
	{
		"id": 27,
		"group": "NEW",
		"name": "Nephilim (Híbrido do Crepúsculo)",
		"badge": "✨ Nova Raça 27",
		"color": Color("#ffd700"),
		"lore": "Linhagem mística híbrida de anjos caídos e espectros do vácuo. Portador de asas de luz dourada e trevas.",
		"stats": "FOR: 9 | DES: 9 | CON: 8 | AGI: 8 | INT: 10 | ESP: 10 | PER: 7 | SOR: 7",
		"passive": "Dualidade Cósmica: Alterna buffs entre Cura da Luz durante o dia e Penetração das Sombras à noite.",
		"skill_z": "Julgamento do Eclipse Solar [Z]: Explosão dual de luz e sombra causando dano sagrado e necrótico."
	},
	{
		"id": 28,
		"group": "NEW",
		"name": "Errante Temporal (Cronomante)",
		"badge": "✨ Nova Raça 28",
		"color": Color("#ffd54f"),
		"lore": "Viajante de linhas temporais fraturadas. Despertado através da lendária Ampulheta Rúnica (Item 29).",
		"stats": "FOR: 5 | DES: 10 | CON: 5 | AGI: 12 | INT: 12 | ESP: 9 | PER: 8 | SOR: 9",
		"passive": "Conservação Temporal: Seus equipamentos não perdem durabilidade e recarga de esquiva -25%!",
		"skill_z": "Rebobinar o Destino [Z]: Retorna instantaneamente à posição de 3s atrás recuperando 30% do dano sofrido."
	}
]

func _ready() -> void:
	layer = 30
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
	_filter_races(current_filter)

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
		if world.get("dev_drop_rates_ui") and world.dev_drop_rates_ui.get("is_open"): any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.02, 0.05, 0.85)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	var main_panel := PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(980, 680)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	p_style.border_color = Color(0.9, 0.75, 0.25, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.85)
	p_style.shadow_size = 20
	p_style.content_margin_left = 20
	p_style.content_margin_right = 20
	p_style.content_margin_top = 16
	p_style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(vbox)

	# TOP BAR
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "👑 PAINEL DEV — TODAS AS 28 RAÇAS & SECRETAS [F10]"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	# Botão [Dev] Receber Kit dos 12 Equipamentos
	var kit_btn := Button.new()
	kit_btn.text = " 🎁 [Dev] Receber Kit dos 12 Equipamentos "
	kit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var k_style := StyleBoxFlat.new()
	k_style.bg_color = Color(0.18, 0.35, 0.22, 0.95)
	k_style.border_color = Color(0.35, 0.85, 0.45)
	k_style.set_border_width_all(1)
	k_style.set_corner_radius_all(6)
	kit_btn.add_theme_stylebox_override("normal", k_style)
	kit_btn.pressed.connect(_on_claim_12_slots_kit)
	top_bar.add_child(kit_btn)

	var close_btn := Button.new()
	close_btn.text = " [X] Fechar (F10) "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.35, 0.12, 0.12, 0.85)
	c_style.border_color = Color(0.75, 0.25, 0.25)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", c_style)
	close_btn.pressed.connect(close_menu)
	top_bar.add_child(close_btn)

	# Status feedback label
	status_label = Label.new()
	status_label.text = "Ambiente de Teste Dev: Escolha qualquer uma das 28 raças para trocar instantaneamente (ActionMode=99)!"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(status_label)

	# TAB / FILTER BAR
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(tab_bar)

	_add_filter_btn(tab_bar, "ALL", "✦ Todas (28)")
	_add_filter_btn(tab_bar, "NEW", "✨ 10 Novas Raças (19-28)")
	_add_filter_btn(tab_bar, "SECRET", "🔮 6 Secretas Clássicas (5-10)")
	_add_filter_btn(tab_bar, "EVOLUTION", "⚖️ Evoluções Ordem/Caos (11-18)")
	_add_filter_btn(tab_bar, "BASE", "🛡️ 4 Raças Base (1-4)")

	vbox.add_child(HSeparator.new())

	# SCROLL LIST OF RACES
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	cards_container = VBoxContainer.new()
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", 10)
	scroll.add_child(cards_container)

	_render_cards()

func _add_filter_btn(parent: HBoxContainer, filter_code: String, label_text: String) -> void:
	var btn := Button.new()
	btn.text = " " + label_text + " "
	btn.add_theme_font_size_override("font_size", 11)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): _filter_races(filter_code))
	parent.add_child(btn)

func _filter_races(filter_code: String) -> void:
	current_filter = filter_code
	_render_cards()

func _render_cards() -> void:
	if not cards_container:
		return

	for child in cards_container.get_children():
		child.queue_free()

	for race in RACES_DATA + NewRaces.dev_entries():
		if current_filter != "ALL" and race["group"] != current_filter:
			continue

		var card := _create_race_card(race)
		cards_container.add_child(card)

func _create_race_card(race: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	var col: Color = race["color"]
	p_style.border_color = Color(col.r, col.g, col.b, 0.5)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 14
	p_style.content_margin_right = 14
	p_style.content_margin_top = 10
	p_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", p_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# Cor da Raça (Swatch)
	var icon_box := ColorRect.new()
	icon_box.custom_minimum_size = Vector2(40, 40)
	icon_box.color = race["color"]
	hbox.add_child(icon_box)

	# Informações de Texto
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	# Linha 1: Nome + Badge + ID
	var line1 := HBoxContainer.new()
	line1.add_theme_constant_override("separation", 8)
	vbox.add_child(line1)

	var name_lbl := Label.new()
	name_lbl.text = "Raça #%d: %s" % [race["id"], race["name"]]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", race["color"])
	line1.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = "[%s]" % race["badge"]
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	line1.add_child(badge_lbl)

	# Linha 2: Lore
	var lore_lbl := Label.new()
	lore_lbl.text = "📖 História: %s" % race["lore"]
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.add_theme_font_size_override("font_size", 11)
	lore_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(lore_lbl)

	# Linha 3: Atributos Base
	var stats_lbl := Label.new()
	stats_lbl.text = "📊 Atributos: %s" % race["stats"]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(stats_lbl)

	# Linha 4: Passiva
	var pass_lbl := Label.new()
	pass_lbl.text = "🛡️ Passiva: %s" % race["passive"]
	pass_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pass_lbl.add_theme_font_size_override("font_size", 11)
	pass_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	vbox.add_child(pass_lbl)

	# Linha 5: Habilidade Racial Z
	var skill_lbl := Label.new()
	skill_lbl.text = "⚡ Habilidade Racial: %s" % race["skill_z"]
	skill_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_lbl.add_theme_font_size_override("font_size", 11)
	skill_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	vbox.add_child(skill_lbl)

	# BOTÃO [Testar Esta Raça (Dev)]
	var test_btn := Button.new()
	test_btn.text = " [Testar Esta Raça (Dev)] "
	test_btn.custom_minimum_size = Vector2(200, 36)
	test_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.18, 0.28, 0.44, 0.95)
	b_style.border_color = Color(0.4, 0.7, 1.0, 0.9)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(6)
	test_btn.add_theme_stylebox_override("normal", b_style)
	test_btn.pressed.connect(func(): _on_select_race_dev(race["id"], race["name"]))
	hbox.add_child(test_btn)

	return panel

func _on_select_race_dev(race_id: int, race_name: String) -> void:
	print("[DevRaceMenuUI] Ativando Raça Dev #%d (%s) com ActionMode=99..." % [race_id, race_name])
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_select_identity(race_id, 0, 99)
	if status_label:
		status_label.text = "Raça alterada com sucesso para: Raça #%d — %s! (Kit de 12 slots atualizado)" % [race_id, race_name]
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

func _on_claim_12_slots_kit() -> void:
	print("[DevRaceMenuUI] Requisitando Kit dos 12 Equipamentos (ActionMode=99)...")
	var world := get_parent()
	var current_race: int = 1
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		current_race = world.local_player.get("current_race_id", 1)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_select_identity(current_race, 0, 99)
	if status_label:
		status_label.text = "Kit dos 12 Equipamentos completo recebido do servidor com sucesso!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
