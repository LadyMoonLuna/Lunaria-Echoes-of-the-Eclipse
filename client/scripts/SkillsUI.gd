extends CanvasLayer

var is_open: bool = false
var active_tab_index: int = 0

# Dados Raciais para Tab 1
const RACIAL_DETAILS := {
	1: {
		"name": "Valeriano (Humano Solar)",
		"skill_z_name": "Ímpeto Valeriano [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "O sangue solar ferve em suas veias! Restaura imediatamente +40 de Stamina, cura +25 de Vida e concede um bônus de +25% de dano em todos os ataques e habilidades por 10 segundos.",
		"passive_name": "Fôlego Real (Passiva Inata)",
		"passive_desc": "+15% de regeneração contínua de Stamina mesmo durante a execução de ataques e esquivas.",
		"color": Color("#ffd700"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	2: {
		"name": "Noctari (Elfo da Lua)",
		"skill_z_name": "Explosão Lunar / Umbral [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Libera uma detonação mágica estelar em um raio de 5.5m ao redor do jogador, causando dano arcano massivo baseado em Inteligência e curando +30 de Vida instantaneamente.",
		"passive_name": "Passo Astral (Passiva Inata)",
		"passive_desc": "+25% de dano mágico e físico sob o luar noturno. Durante a Lua Cheia, o bônus é dobrado (+50%).",
		"color": Color("#b388ff"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	3: {
		"name": "Kharad (Anão de Pedra & Magma)",
		"skill_z_name": "Baluarte Rúnico / Erupção [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Bate com força telúrica no chão, desferindo uma erupção de magma em raio de 4.5m e ativando um escudo que reduz 70% de todo dano recebido durante 5 segundos.",
		"passive_name": "Postura de Rocha (Passiva Inata)",
		"passive_desc": "Reduz passivamente 20% de todo dano recebido de Monstros e concede imunidade a perda de equilíbrio por golpes pesados.",
		"color": Color("#ff9800"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	4: {
		"name": "Varkai (Sangue Dracônico / Lupino)",
		"skill_z_name": "Sopro Dracônico / Rugido Predatório [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Expele um cone devastador de fogo e garras frontais (5.5m) que despedaça as armaduras inimigas e rouba +20 de Vida para cada alvo atingido pelo ataque.",
		"passive_name": "Sangue Fervilhante (Passiva Inata)",
		"passive_desc": "Quando sua vida cai abaixo de 35%, seus sentidos primordiais entram em hiperatividade, concedendo +20% de dano aumentado e 30% de velocidade de movimento.",
		"color": Color("#ff1744"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	11: {
		"name": "Alto Valeriano (Ordem Solar)",
		"skill_z_name": "Estandarte Dourado da Coroa [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Ergue o estandarte sagrado imperial, curando +50 HP em aliados, restaurando +60 Stamina e energizando armas com dano solar divino (+35% de dano por 12s).",
		"passive_name": "Soberania da Coroa (Passiva Ascendida)",
		"passive_desc": "+30% de Stamina máxima e regeneração ininterrupta.",
		"color": Color("#ffd700"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	12: {
		"name": "Andarilho do Éter (Caos Espacial)",
		"skill_z_name": "Fenda Dimensional [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Rasga a tapeçaria da realidade, teleportando 6 metros para a direção de movimento e gerando uma explosão de vácuo etéreo que ignora armaduras físicas.",
		"passive_name": "Forma Etérea (Passiva Ascendida)",
		"passive_desc": "18% de chance constante de desviar totalmente de qualquer ataque recebido.",
		"color": Color("#ba68c8"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	},
	21: {
		"name": "Arconte Lunar (Ordem de Selene)",
		"skill_z_name": "Luz Purificadora de Selene [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Invoca um pilar de luz lunar concentrada (6.0m) que purifica aliados curando +70 HP e cega monstros desferindo dano sagrado estelar.",
		"passive_name": "Coração Estelar (Passiva Ascendida)",
		"passive_desc": "+40% de poder mágico sob qualquer fase da lua.",
		"color": Color("#00e5ff"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	22: {
		"name": "Espectro Umbral (Caos de Nyx)",
		"skill_z_name": "Manto de Nyx [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Dissolve seu corpo nas sombras tornando-se invisível por 4 segundos. O próximo ataque desferido após a quebra do manto causa +120% de Dano Crítico garantido.",
		"passive_name": "Assassino das Trevas (Passiva Ascendida)",
		"passive_desc": "+35% de velocidade de movimento e +30% de dano crítico permanente.",
		"color": Color("#7c4dff"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	},
	31: {
		"name": "Guardião Rúnico (Ordem da Bigorna)",
		"skill_z_name": "Muralha Rúnica Ancestral [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Grava runas sagradas de proteção na pele, absorvendo 85% de dano por 6s e refletindo 50% de volta aos atacantes.",
		"passive_name": "Baluarte Inabalável (Passiva Ascendida)",
		"passive_desc": "Imune a qualquer efeito de controle de grupo e bônus de +400 HP Máximo.",
		"color": Color("#ffb74d"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	32: {
		"name": "Titã de Obsidiana (Caos de Magma)",
		"skill_z_name": "Geiser de Magma Profundo [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Racha o solo liberando uma geiser vulcânica de 5.5m que incendeia inimigos causando dano de queimação contínua e repulsão violenta.",
		"passive_name": "Corpo Magmático (Passiva Ascendida)",
		"passive_desc": "Atacantes corpo-a-corpo sofrem retaliação de dano de fogo constante.",
		"color": Color("#ff3d00"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	},
	41: {
		"name": "Soberano Dracônico (Ordem Dracônica)",
		"skill_z_name": "Sopro Real do Dragão Ancestral [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Dispara um sopro colunar de chamas ancestrais de 7.0m que incinera tudo em seu caminho e rouba vida em massa.",
		"passive_name": "Escamas do Soberano (Passiva Ascendida)",
		"passive_desc": "Reduz 35% do dano mágico recebido e amplifica dano elemental em 30%.",
		"color": Color("#e53935"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	42: {
		"name": "Fera do Frenesi (Caos Sangrento)",
		"skill_z_name": "Frenesi Voraz Sangrento [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Dispara um salto devastador desferindo 4 garras cortantes rápidas; cada golpe restaura +20 HP e aumenta sua velocidade em 50%.",
		"passive_name": "Carnificina Feral (Passiva Ascendida)",
		"passive_desc": "Abates concedem +20% de cura total instantânea.",
		"color": Color("#ad1457"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	}
}

# Dados de Classes e Habilidades Ativas
const CLASS_ACTIVE_SKILLS := {
	0: { # Viajante
		"name": "Viajante (Sem Classe)",
		"tier_name": "Tier 0 — Aventureiro Iniciante",
		"desc": "Você ainda não escolheu um caminho marcial. Visite os Mestres Garrick, Lyra ou Capitão Randel na Vila do Refúgio para aprender uma Classe Básica!",
		"color": Color("#cfd8dc"),
		"basic": {"name": "Golpe Simples [LMB]", "desc": "Pancada inicial desarmada ou com arma improvisada (1.0x dano).", "range": "2.5m", "cost": "0 Stamina", "cd": "0.35s"},
		"q": {"name": "Investida Cautelosa [Q]", "desc": "Passo rápido à frente desferindo uma estocada simples (1.2x dano).", "range": "3.5m", "cost": "15 Stamina", "cd": "2.5s"},
		"r": {"name": "Respirar Fundo [R]", "desc": "Postura defensiva temporária que recupera +15 de Stamina.", "range": "Pessoal", "cost": "0 Stamina", "cd": "6.0s"},
		"f": {"name": "Instinto de Sobrevivência [F]", "desc": "Salto para trás e foco aumentado reduzindo dano recebido por 2s.", "range": "Pessoal", "cost": "20 Stamina", "cd": "12.0s"}
	},
	1: { # Espadachim
		"name": "Espadachim",
		"tier_name": "Tier 1 a Tier 4 (Vanguarda Real)",
		"desc": "Combatente corpo a corpo balanceado, mestre de espada e escudo com foco em cortes rápidos, defesas perfeitas e impactos sísmicos.",
		"color": Color("#64b5f6"),
		"basic": {"name": "Corte da Lâmina [LMB]", "desc": "Golpe rápido de espada em arco frontal (1.0x dano base).", "range": "3.8m", "cost": "0 Stamina", "cd": "0.35s"},
		"q": {"name": "Corte Crescente [Q]", "desc": "Talho ascendente poderoso que corta alvos em cone amplo (1.75x dano).", "range": "4.2m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Postura de Ferro [R]", "desc": "Parry impenetrável que reduz 70% de dano por 2.5s e causa choque nos inimigos.", "range": "Pessoal", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Impacto Sísmico [F]", "desc": "Salto esmagador cravando a lâmina no solo, liberando onda sísmica de 4.5m (2.4x dano).", "range": "4.5m Radial", "cost": "25 Stamina", "cd": "12.0s"}
	},
	2: { # Batedor
		"name": "Batedor",
		"tier_name": "Tier 1 a Tier 4 (Franco-Atirador Real)",
		"desc": "Atirador veloz de longo alcance armado com arco composto e flechas táticas de controle e perfuração.",
		"color": Color("#69f0ae"),
		"basic": {"name": "Disparo Rápido [LMB]", "desc": "Flecha balística veloz de longo alcance (1.0x dano).", "range": "16.0m", "cost": "0 Stamina", "cd": "0.30s"},
		"q": {"name": "Disparo Perfurante [Q]", "desc": "Flecha pontiaguda de alta velocidade que atravessa múltiplos alvos (1.75x dano).", "range": "22.0m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Chuva de Estrepes [R]", "desc": "Dispara armadilhas de espinhos que reduzem a movimentação dos monstros em 40% por 3s.", "range": "14.0m", "cost": "20 Stamina", "cd": "6.0s"},
		"f": {"name": "Saraivada Estelar [F]", "desc": "Dispara 3 flechas encantadas simultâneas em cone frontal aberto (2.4x dano total).", "range": "18.0m", "cost": "25 Stamina", "cd": "12.0s"}
	},
	3: { # Iniciado
		"name": "Iniciado Arcano",
		"tier_name": "Tier 1 a Tier 4 (Arquimago Celestial)",
		"desc": "Conjurador de magias elementais do cosmos, capaz de explodir esferas arcanas e congelar inimigos em área.",
		"color": Color("#ea80fc"),
		"basic": {"name": "Orbe Arcano [LMB]", "desc": "Projétil de energia cósmica concentrada com velocidade de 16m/s (1.0x dano).", "range": "14.0m", "cost": "0 Stamina", "cd": "0.38s"},
		"q": {"name": "Cometa Elemental [Q]", "desc": "Grande esfera de fogo estelar que explode em um raio de 2.8m (1.75x dano).", "range": "18.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Nova de Gelo [R]", "desc": "Onda congelante de 5.0m radial que paralisa e desacelera monstros por 1.5s.", "range": "5.0m Radial", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Maelstrom Cósmico [F]", "desc": "Tempestade arcana colossal de devastação massiva em raio de 6.5m (2.4x dano).", "range": "6.5m Radial", "cost": "25 Stamina", "cd": "14.0s"}
	},
	4: { # Acólito
		"name": "Acólito da Aurora",
		"tier_name": "Tier 1 a Tier 4 (Bispo Templário)",
		"desc": "Guerreiro sagrado empunhando maça e talismã, alternando entre ataques de contusão divina e orações curativas.",
		"color": Color("#ffd54f"),
		"basic": {"name": "Golpe da Fé [LMB]", "desc": "Pancada de maça abençoada causando dano sagrado puro (1.0x dano).", "range": "4.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Círculo de Luz [Q]", "desc": "Impacto sagrado que causa dano aos monstros e cura +40 HP em aliados em 6.0m.", "range": "6.0m", "cost": "15 Stamina", "cd": "3.5s"},
		"r": {"name": "Lança do Julgamento [R]", "desc": "Feixe divino perfurante lançado a até 15m que purifica os alvos.", "range": "15.0m", "cost": "20 Stamina", "cd": "6.5s"},
		"f": {"name": "Égide Sagrada [F]", "desc": "Explosão celestial restaurando +65 HP no grupo e desferindo 2.4x dano sagrado.", "range": "7.0m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	},
	5: { # Ferreiro
		"name": "Ferreiro Combatente",
		"tier_name": "Tier 1 a Tier 4 (Grão-Mestre Forjador)",
		"desc": "Força bruta com martelo colossal de forja, capaz de forjar armas de guerra e esmagar couraças.",
		"color": Color("#ff9800"),
		"basic": {"name": "Martelada Pesada [LMB]", "desc": "Golpe esmagador contundente que atordoa armaduras leves (1.0x dano).", "range": "4.0m", "cost": "0 Stamina", "cd": "0.40s"},
		"q": {"name": "Golpe de Bigorna [Q]", "desc": "Impacto pesado concentrado no topo do crânio do alvo (1.75x dano).", "range": "4.2m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Afiação de Combate [R]", "desc": "Martela a bigorna conferindo um buff de +25% de dano para o grupo por 10s.", "range": "Grupo 12m", "cost": "20 Stamina", "cd": "10.0s"},
		"f": {"name": "Fúria do Vulcão [F]", "desc": "Impacto sísmico frontal telegrafado de 4.5m abrindo fendas incandescentes (2.4x dano).", "range": "4.5m Frontal", "cost": "25 Stamina", "cd": "13.0s"}
	},
	6: { # Alquimista
		"name": "Alquimista",
		"tier_name": "Tier 1 a Tier 4 (Quimicista Real)",
		"desc": "Manipulador de frascos químicos, elixires curativos e bombas cáusticas de ácido.",
		"color": Color("#00e676"),
		"basic": {"name": "Frasco Cáustico [LMB]", "desc": "Arremesso de ampola corrosiva com alcance médio (1.0x dano).", "range": "13.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Frasco de Éter [Q]", "desc": "Frasco que detona causando dano em área e curando +40 HP em aliados em 6.0m.", "range": "14.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Bomba de Ácido [R]", "desc": "Arremessa poça corrosiva de 3.5m que reduz armaduras dos inimigos por 4s.", "range": "12.0m", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Detonação Catalítica [F]", "desc": "Reação química em cadeia que explode violentamente em área de 5.5m (2.4x dano).", "range": "5.5m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	},
	7: { # Ceifador do Eclipse (Classe Secreta / Única Tier 5)
		"name": "Ceifador do Eclipse",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Soberano da Meia-Noite)",
		"desc": "Espírito das sombras portando uma foice colossal. Cada golpe ceifa as almas e o sangue dos inimigos.",
		"color": Color("#d500f9"),
		"basic": {"name": "Foice das Sombras [LMB]", "desc": "Varredura ampla de longo melee de 4.8m com lifesteal embutido (1.0x dano).", "range": "4.8m", "cost": "0 Stamina", "cd": "0.38s"},
		"q": {"name": "Colheita Noturna [Q]", "desc": "Corte espiral que suga essência vital de todos os alvos no caminho (1.75x dano).", "range": "5.0m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Drenagem Abissal [R]", "desc": "Vórtice escuro que paralisa alvos e restaura +45 HP contínuos ao usuário.", "range": "Pessoal 5m", "cost": "20 Stamina", "cd": "6.5s"},
		"f": {"name": "Dança do Eclipse Total [F]", "desc": "Giro fatal de foice cobrindo 6.0m com dano devastador e roubo de vida pleno (2.4x dano).", "range": "6.0m Radial", "cost": "25 Stamina", "cd": "12.0s"}
	},
	8: { # Artífice Rúnico (Tier 5)
		"name": "Artífice Rúnico",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Engenheiro Arcano Supremo)",
		"desc": "Híbrido mecânico armado com martelo-canhão movido a núcleos de forja estelar.",
		"color": Color("#ff6d00"),
		"basic": {"name": "Canhonada Rúnica [LMB]", "desc": "Pancada física e detonação de pólvora simultâneas (1.0x dano).", "range": "15.0m", "cost": "0 Stamina", "cd": "0.38s"},
		"q": {"name": "Salva Rúnica [Q]", "desc": "Três cartuchos energizados disparados em rápida sucessão frontal (1.75x dano).", "range": "16.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Sobrecarga Eletrostática [R]", "desc": "Pulso elétrico que concede raios nas armas do grupo por 8s.", "range": "Grupo 10m", "cost": "20 Stamina", "cd": "8.0s"},
		"f": {"name": "Bombardeio Titanomecânico [F]", "desc": "Disparo orbital com estilhaços energizados de 6.5m (2.4x dano).", "range": "6.5m Radial", "cost": "25 Stamina", "cd": "14.0s"}
	},
	9: { # Criador de Homúnculos (Tier 5)
		"name": "Criador de Homúnculos",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Demiurgo da Vida Sintética)",
		"desc": "Mestre da vida sintética acompanhado por uma quimera flutuante transmissora de elixires.",
		"color": Color("#00b0ff"),
		"basic": {"name": "Pulso Quimérico [LMB]", "desc": "Onda biótica disparada pelo homúnculo que causa dano e regenera o mestre (1.0x dano).", "range": "14.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Infusão Mutagênica [Q]", "desc": "Elixir abissal corrosivo que dissolve resistências inimigas (1.75x dano).", "range": "15.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Névoa de Bioplasma [R]", "desc": "Nuvem esverdeada curando aliados continuamente e cegando monstros.", "range": "4.5m Área", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Frenesi do Quimera Supremo [F]", "desc": "O homúnculo cresce e desfere uma explosão de garras e ácido colossais (2.4x dano).", "range": "6.0m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	}
}

# Referências de Nós
var main_panel: PanelContainer = null
var tab_buttons: Array[Button] = []
var tab_containers: Array[Control] = []
var selected_custom_slot: String = "LMB"
var pending_keybinds: Dictionary = {
	"LMB": 1,
	"Q": 3,
	"R": 4,
	"F": 5,
	"Z": 6
}

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	_switch_tab(0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_open:
			close_menu()
			get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)
	_refresh_current_tab()

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

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

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
	main_panel.custom_minimum_size = Vector2(960, 600)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	p_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.8)
	p_style.shadow_size = 18
	p_style.content_margin_left = 20
	p_style.content_margin_right = 20
	p_style.content_margin_top = 16
	p_style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(root_vbox)

	# Barra de Título e Fechar
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "LUNARIA — COMPÊNDIO DE HABILIDADES & PASSIVAS [TECLA H]"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " ✕ Fechar "
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	top_bar.add_child(close_btn)

	# Barra de Abas (4 Abas)
	var tabs_bar := HBoxContainer.new()
	tabs_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tabs_bar)

	tab_buttons.clear()
	var tab_names := [
		"⚡ 1. Raciais [Tecla Z]",
		"⚔️ 2. Ativas [LMB, Q, R, F]",
		"🌌 3. Passivas & Provação",
		"🎯 4. Customizar Slots de Ação"
	]
	for i in range(4):
		var t_btn := Button.new()
		t_btn.text = tab_names[i]
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size = Vector2(0, 36)
		t_btn.add_theme_font_size_override("font_size", 11)
		t_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx: int = i
		t_btn.pressed.connect(func(): _switch_tab(idx))
		tabs_bar.add_child(t_btn)
		tab_buttons.append(t_btn)

	# Separador
	root_vbox.add_child(HSeparator.new())

	# Containers das 4 Abas
	tab_containers.clear()
	for i in range(4):
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(scroll)
		tab_containers.append(scroll)

func _switch_tab(idx: int) -> void:
	active_tab_index = idx
	for i in range(tab_buttons.size()):
		var btn: Button = tab_buttons[i]
		var is_sel: bool = (i == idx)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4

		if is_sel:
			style.bg_color = Color(0.2, 0.32, 0.5, 0.95)
			style.border_color = Color(0.9, 0.8, 0.3, 0.95)
			style.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		else:
			style.bg_color = Color(0.08, 0.1, 0.15, 0.8)
			style.border_color = Color(0.25, 0.35, 0.5, 0.4)
			style.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

		tab_containers[i].visible = is_sel

	_refresh_current_tab()

func _refresh_current_tab() -> void:
	var world := get_parent()
	var my_race: int = 1
	var my_class: int = 0
	var my_tier: int = 1
	var my_level: int = 1
	if world:
		if world.get("my_race_id"): my_race = world.my_race_id
		if world.get("my_class_id"): my_class = world.my_class_id
		if world.get("my_class_tier"): my_tier = world.my_class_tier
		if world.get("my_level"): my_level = world.my_level

	match active_tab_index:
		0: _build_tab_1_racial(my_race)
		1: _build_tab_2_class_actives(my_class, my_tier, my_level)
		2: _build_tab_3_passives_and_trials(my_class, my_tier, my_level)
		3: _build_tab_4_customize_slots(my_race, my_class)

# ABA 1: Habilidades & Passivas Raciais
func _build_tab_1_racial(race_id: int) -> void:
	var container: ScrollContainer = tab_containers[0]
	for ch in container.get_children():
		ch.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	var r_info: Dictionary = RACIAL_DETAILS.get(race_id, RACIAL_DETAILS[1])

	# Banner da Raça Atual
	var banner := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.08, 0.11, 0.17, 0.95)
	b_style.border_color = r_info["color"]
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(8)
	b_style.content_margin_left = 16
	b_style.content_margin_right = 16
	b_style.content_margin_top = 12
	b_style.content_margin_bottom = 12
	banner.add_theme_stylebox_override("panel", b_style)
	vbox.add_child(banner)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 4)
	banner.add_child(bvbox)

	var r_name_lbl := Label.new()
	r_name_lbl.text = "Linhagem Sanguínea: %s" % r_info["name"]
	r_name_lbl.add_theme_font_size_override("font_size", 16)
	r_name_lbl.add_theme_color_override("font_color", r_info["color"])
	bvbox.add_child(r_name_lbl)

	var r_status_lbl := Label.new()
	r_status_lbl.text = "[ %s ]" % r_info["status"]
	r_status_lbl.add_theme_font_size_override("font_size", 11)
	r_status_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	bvbox.add_child(r_status_lbl)

	# Card da Habilidade Ativa [Tecla Z]
	var card_z := PanelContainer.new()
	var z_style := StyleBoxFlat.new()
	z_style.bg_color = Color(0.07, 0.1, 0.15, 0.9)
	z_style.border_color = Color(0.3, 0.85, 1.0, 0.7)
	z_style.set_border_width_all(1)
	z_style.set_corner_radius_all(6)
	z_style.content_margin_left = 14
	z_style.content_margin_right = 14
	z_style.content_margin_top = 10
	z_style.content_margin_bottom = 10
	card_z.add_theme_stylebox_override("panel", z_style)
	vbox.add_child(card_z)

	var zvbox := VBoxContainer.new()
	zvbox.add_theme_constant_override("separation", 4)
	card_z.add_child(zvbox)

	var z_head := Label.new()
	z_head.text = "⚡ HABILIDADE RACIAL ATIVA: %s" % r_info["skill_z_name"]
	z_head.add_theme_font_size_override("font_size", 13)
	z_head.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	zvbox.add_child(z_head)

	var z_cost := Label.new()
	z_cost.text = r_info["skill_z_cost"]
	z_cost.add_theme_font_size_override("font_size", 10)
	z_cost.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	zvbox.add_child(z_cost)

	var z_desc := Label.new()
	z_desc.text = r_info["skill_z_desc"]
	z_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	z_desc.add_theme_font_size_override("font_size", 11)
	z_desc.add_theme_color_override("font_color", Color(0.9, 0.94, 0.98))
	zvbox.add_child(z_desc)

	# Card da Passiva Inata de Linhagem
	var card_pass := PanelContainer.new()
	var pass_style := z_style.duplicate()
	pass_style.border_color = Color(0.4, 0.95, 0.45, 0.7)
	card_pass.add_theme_stylebox_override("panel", pass_style)
	vbox.add_child(card_pass)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 4)
	card_pass.add_child(pvbox)

	var pass_head := Label.new()
	pass_head.text = "🛡️ PASSIVA DE LINHAGEM: %s" % r_info["passive_name"]
	pass_head.add_theme_font_size_override("font_size", 13)
	pass_head.add_theme_color_override("font_color", Color(0.4, 0.95, 0.45))
	pvbox.add_child(pass_head)

	var pass_desc := Label.new()
	pass_desc.text = r_info["passive_desc"]
	pass_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pass_desc.add_theme_font_size_override("font_size", 11)
	pass_desc.add_theme_color_override("font_color", Color(0.9, 0.94, 0.98))
	pvbox.add_child(pass_desc)

# ABA 2: Habilidades Ativas de Classe (LMB, Q, R, F)
func _build_tab_2_class_actives(class_id: int, class_tier: int, level: int) -> void:
	var container: ScrollContainer = tab_containers[1]
	for ch in container.get_children():
		ch.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	var c_info: Dictionary = CLASS_ACTIVE_SKILLS.get(class_id, CLASS_ACTIVE_SKILLS[0])

	# Banner da Classe
	var banner := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.08, 0.11, 0.17, 0.95)
	b_style.border_color = c_info["color"]
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(8)
	b_style.content_margin_left = 16
	b_style.content_margin_right = 16
	b_style.content_margin_top = 10
	b_style.content_margin_bottom = 10
	banner.add_theme_stylebox_override("panel", b_style)
	vbox.add_child(banner)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 3)
	banner.add_child(bvbox)

	var c_title := Label.new()
	c_title.text = "Classe Atual: %s — %s (Nível %d)" % [c_info["name"], c_info["tier_name"], level]
	c_title.add_theme_font_size_override("font_size", 15)
	c_title.add_theme_color_override("font_color", c_info["color"])
	bvbox.add_child(c_title)

	var c_desc := Label.new()
	c_desc.text = c_info["desc"]
	c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_desc.add_theme_font_size_override("font_size", 11)
	c_desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	bvbox.add_child(c_desc)

	# 4 Slots de Habilidades Ativas
	var skills_list := [
		{"slot": "[LMB] Ataque Básico", "data": c_info["basic"], "color": Color("#ffffff")},
		{"slot": "[Q] Habilidade 1", "data": c_info["q"], "color": Color("#64b5f6")},
		{"slot": "[R] Habilidade 2", "data": c_info["r"], "color": Color("#ffd54f")},
		{"slot": "[F] Habilidade Suprema", "data": c_info["f"], "color": Color("#ff5252")}
	]

	for item in skills_list:
		var s_data: Dictionary = item["data"]
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.09, 0.14, 0.9)
		card_style.border_color = Color(0.3, 0.42, 0.6, 0.5)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		vbox.add_child(card)

		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 2)
		card.add_child(cvbox)

		var s_head := Label.new()
		s_head.text = "%s: %s" % [item["slot"], s_data["name"]]
		s_head.add_theme_font_size_override("font_size", 12)
		s_head.add_theme_color_override("font_color", item["color"])
		cvbox.add_child(s_head)

		var s_meta := Label.new()
		s_meta.text = "Alcance: %s  |  Custo: %s  |  Recarga: %s" % [s_data["range"], s_data["cost"], s_data["cd"]]
		s_meta.add_theme_font_size_override("font_size", 10)
		s_meta.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
		cvbox.add_child(s_meta)

		var s_body := Label.new()
		s_body.text = s_data["desc"]
		s_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_body.add_theme_font_size_override("font_size", 11)
		s_body.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96))
		cvbox.add_child(s_body)

# ABA 3: Passivas de Classe & Provação Lendária
func _build_tab_3_passives_and_trials(class_id: int, class_tier: int, level: int) -> void:
	var container: ScrollContainer = tab_containers[2]
	for ch in container.get_children():
		ch.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	# Seção de Passivas de Especialização
	var pass_panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.11, 0.17, 0.95)
	p_style.border_color = Color(0.4, 0.6, 0.85, 0.7)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(8)
	p_style.content_margin_left = 16
	p_style.content_margin_right = 16
	p_style.content_margin_top = 12
	p_style.content_margin_bottom = 12
	pass_panel.add_theme_stylebox_override("panel", p_style)
	vbox.add_child(pass_panel)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 4)
	pass_panel.add_child(pvbox)

	var p_title := Label.new()
	p_title.text = "🛡️ PASSIVAS DO CAMINHO DE ESPECIALIZAÇÃO:"
	p_title.add_theme_font_size_override("font_size", 14)
	p_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	pvbox.add_child(p_title)

	var p_desc := Label.new()
	if class_id == 0:
		p_desc.text = "Viajantes não possuem especialização marcial ativa. Visite os Mestres na Vila do Refúgio para aprender uma Classe Básica."
	elif class_tier < 2:
		p_desc.text = "Seu Caminho de Especialização despertará ao atingir o Nível 10 com o Mestre da sua Guilda."
	else:
		p_desc.text = "Especialização Ativa (Tier %d): +%d%% de amplificação de combate, bônus de dano de atributos e resistência a atordoamentos." % [class_tier, class_tier * 10]
	p_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_desc.add_theme_font_size_override("font_size", 11)
	p_desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	pvbox.add_child(p_desc)

	# Se for Classe Única (Tier 5): Exibe a Provação Especial Lendária!
	if class_tier >= 5 or class_id in [7, 8, 9]:
		var trial_panel := PanelContainer.new()
		var t_style := StyleBoxFlat.new()
		t_style.bg_color = Color(0.12, 0.06, 0.16, 0.98)
		t_style.border_color = Color(0.95, 0.82, 0.35, 0.95)
		t_style.set_border_width_all(2)
		t_style.set_corner_radius_all(10)
		t_style.shadow_color = Color(0.8, 0.2, 0.9, 0.4)
		t_style.shadow_size = 14
		t_style.content_margin_left = 18
		t_style.content_margin_right = 18
		t_style.content_margin_top = 14
		t_style.content_margin_bottom = 14
		trial_panel.add_theme_stylebox_override("panel", t_style)
		vbox.add_child(trial_panel)

		var tvbox := VBoxContainer.new()
		tvbox.add_theme_constant_override("separation", 8)
		trial_panel.add_child(tvbox)

		var quest_name: String = "As Três Colheitas sob o Sol Negro"
		var quest_lore: String = "Abata 3 Criaturas de Elite ou Chefes (Lobo Alfa, Licantropo Alfa, Executor) sem tombar em batalha para provar seu valor perante o cosmos e ascender ao TIER 6 LENDÁRIO."
		if class_id == 8:
			quest_name = "O Metal que Caiu do Céu"
			quest_lore = "Colete a liga divina do cosmos abatendo 3 Monstros de Elite sem morrer para ascender a Engenheiro Arcano Supremo (Tier 6)."
		elif class_id == 9:
			quest_name = "Magnum Opus Transmutacional"
			quest_lore = "Transmute a centelha da vida sintética definitiva com a essência de 3 Criaturas de Elite para despertar como Demiurgo (Tier 6)."

		var t_head := Label.new()
		t_head.text = "👑 PROVAÇÃO ESPECIAL LENDÁRIA (TIER 5 -> TIER 6): %s" % quest_name
		t_head.add_theme_font_size_override("font_size", 14)
		t_head.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		tvbox.add_child(t_head)

		var t_desc := Label.new()
		t_desc.text = quest_lore
		t_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_desc.add_theme_font_size_override("font_size", 11)
		t_desc.add_theme_color_override("font_color", Color(0.9, 0.85, 0.95))
		tvbox.add_child(t_desc)

		var progress_bar := ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 24)
		progress_bar.max_value = 3
		progress_bar.value = 3 if class_tier == 6 else 0
		tvbox.add_child(progress_bar)

		var t_status := Label.new()
		if class_tier == 6:
			t_status.text = "STATUS: PROVAÇÃO CONCLUÍDA! VOCÊ DESPERTOU A CLASSE LENDÁRIA (TIER 6)!"
			t_status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		else:
			t_status.text = "PROGRESSO: 0 / 3 Colheitas Cósmicas Concluídas (Requer Nível 45+)"
			t_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		t_status.add_theme_font_size_override("font_size", 11)
		tvbox.add_child(t_status)
	else:
		var hint_panel := PanelContainer.new()
		var h_style := StyleBoxFlat.new()
		h_style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		h_style.border_color = Color(0.3, 0.4, 0.55, 0.4)
		h_style.set_border_width_all(1)
		h_style.set_corner_radius_all(6)
		h_style.content_margin_left = 14
		h_style.content_margin_right = 14
		h_style.content_margin_top = 10
		h_style.content_margin_bottom = 10
		hint_panel.add_theme_stylebox_override("panel", h_style)
		vbox.add_child(hint_panel)

		var hint_lbl := Label.new()
		hint_lbl.text = "ℹ️ DICA DE ASCENSÃO: Classes Básicas evoluem nos marcos de Nível 10 (Tier 2 Incomum), Nível 25 (Tier 3 Rara) e Nível 45 (Tier 4 Épica). Tomos e itens secretos desbloqueiam as Classes Únicas (Tier 5)."
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
		hint_panel.add_child(hint_lbl)

# ABA 4: Customizar Slots de Ação
func _build_tab_4_customize_slots(race_id: int, class_id: int) -> void:
	var container: ScrollContainer = tab_containers[3]
	for ch in container.get_children():
		ch.queue_free()

	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		var p_bindings: Dictionary = world.local_player.get("skill_slot_bindings")
		if p_bindings and p_bindings.size() > 0:
			for k in p_bindings.keys():
				pending_keybinds[k] = p_bindings[k]

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	# Cabeçalho Informativo
	var header_panel := PanelContainer.new()
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	hp_style.border_color = Color(0.35, 0.75, 1.0, 0.8)
	hp_style.set_border_width_all(1)
	hp_style.set_corner_radius_all(8)
	hp_style.content_margin_left = 16
	hp_style.content_margin_right = 16
	hp_style.content_margin_top = 10
	hp_style.content_margin_bottom = 10
	header_panel.add_theme_stylebox_override("panel", hp_style)
	vbox.add_child(header_panel)

	var h_vbox := VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 4)
	header_panel.add_child(h_vbox)

	var h_title := Label.new()
	h_title.text = "🎯 CUSTOMIZAÇÃO DA BARRA DE AÇÃO & KEYBINDS"
	h_title.add_theme_font_size_override("font_size", 14)
	h_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	h_vbox.add_child(h_title)

	var h_sub := Label.new()
	h_sub.text = "Clique em um dos 5 Slots abaixo para selecioná-lo e, em seguida, escolha uma habilidade da sua gaveta para equipar!"
	h_sub.add_theme_font_size_override("font_size", 11)
	h_sub.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	h_vbox.add_child(h_sub)

	# Catálogo de Habilidades disponíveis para o jogador
	var class_info: Dictionary = CLASS_ACTIVE_SKILLS.get(class_id, CLASS_ACTIVE_SKILLS[0])
	var race_info: Dictionary = RACIAL_DETAILS.get(race_id, RACIAL_DETAILS[1])

	var available_skills := [
		{
			"action_id": 1,
			"name": class_info["basic"]["name"],
			"type": "Ataque Básico",
			"cost": class_info["basic"]["cost"],
			"cd": class_info["basic"]["cd"],
			"range": class_info["basic"]["range"],
			"desc": class_info["basic"]["desc"],
			"color": Color("#64b5f6")
		},
		{
			"action_id": 3,
			"name": class_info["q"]["name"],
			"type": "Habilidade Tática 1",
			"cost": class_info["q"]["cost"],
			"cd": class_info["q"]["cd"],
			"range": class_info["q"]["range"],
			"desc": class_info["q"]["desc"],
			"color": Color("#4fc3f7")
		},
		{
			"action_id": 4,
			"name": class_info["r"]["name"],
			"type": "Habilidade Tática 2",
			"cost": class_info["r"]["cost"],
			"cd": class_info["r"]["cd"],
			"range": class_info["r"]["range"],
			"desc": class_info["r"]["desc"],
			"color": Color("#81c784")
		},
		{
			"action_id": 5,
			"name": class_info["f"]["name"],
			"type": "Habilidade Suprema",
			"cost": class_info["f"]["cost"],
			"cd": class_info["f"]["cd"],
			"range": class_info["f"]["range"],
			"desc": class_info["f"]["desc"],
			"color": Color("#ffb74d")
		},
		{
			"action_id": 6,
			"name": race_info["skill_z_name"],
			"type": "Poder Racial Sagrado/Umbral",
			"cost": race_info["skill_z_cost"],
			"cd": "10.0s",
			"range": "5.5m Área / Cone",
			"desc": race_info["skill_z_desc"],
			"color": race_info["color"]
		},
		{
			"action_id": 2,
			"name": "Rolamento Tático [Shift]",
			"type": "Mobilidade / Esquiva",
			"cost": "20 Stamina",
			"cd": "1.2s",
			"range": "6.0m Salto",
			"desc": "Salto veloz com quadros de invulnerabilidade contra ataques de mobs e projéteis.",
			"color": Color("#e0e0e0")
		}
	]

	var get_skill_by_action := func(act_id: int) -> Dictionary:
		for s in available_skills:
			if s["action_id"] == act_id:
				return s
		return available_skills[0]

	# 1. Os 5 Slots da Barra
	var slots_title := Label.new()
	slots_title.text = "1. SELECIONE O SLOT DA BARRA DE AÇÃO:"
	slots_title.add_theme_font_size_override("font_size", 12)
	slots_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(slots_title)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(slots_hbox)

	var slot_defs := [
		{"key": "LMB", "label": "Clique Esq (LMB)"},
		{"key": "Q", "label": "Tecla Q"},
		{"key": "R", "label": "Tecla R"},
		{"key": "F", "label": "Tecla F"},
		{"key": "Z", "label": "Tecla Z"}
	]

	for s_def in slot_defs:
		var skey: String = s_def["key"]
		var assigned_act: int = pending_keybinds.get(skey, 1)
		var current_skill: Dictionary = get_skill_by_action.call(assigned_act)
		var is_selected: bool = (selected_custom_slot == skey)

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(170, 95)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var s_style := StyleBoxFlat.new()
		s_style.set_corner_radius_all(8)
		s_style.content_margin_left = 10
		s_style.content_margin_right = 10
		s_style.content_margin_top = 8
		s_style.content_margin_bottom = 8

		if is_selected:
			s_style.bg_color = Color(0.18, 0.28, 0.45, 0.98)
			s_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
			s_style.set_border_width_all(3)
		else:
			s_style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
			s_style.border_color = Color(0.25, 0.35, 0.5, 0.5)
			s_style.set_border_width_all(1)

		slot_btn.add_theme_stylebox_override("normal", s_style)
		slot_btn.add_theme_stylebox_override("hover", s_style)
		slot_btn.add_theme_stylebox_override("pressed", s_style)

		var sel_key := skey
		slot_btn.pressed.connect(func():
			selected_custom_slot = sel_key
			_build_tab_4_customize_slots(race_id, class_id)
		)

		var s_inner_vbox := VBoxContainer.new()
		s_inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		s_inner_vbox.add_theme_constant_override("separation", 4)
		s_inner_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(s_inner_vbox)

		var badge := Label.new()
		badge.text = "[ %s ]" % s_def["label"]
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if is_selected else Color(0.65, 0.8, 1.0))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_inner_vbox.add_child(badge)

		var sk_name := Label.new()
		sk_name.text = current_skill["name"]
		sk_name.add_theme_font_size_override("font_size", 11)
		sk_name.add_theme_color_override("font_color", current_skill["color"])
		sk_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sk_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_inner_vbox.add_child(sk_name)

		var sk_type := Label.new()
		sk_type.text = current_skill["type"]
		sk_type.add_theme_font_size_override("font_size", 9)
		sk_type.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		sk_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_inner_vbox.add_child(sk_type)

		slots_hbox.add_child(slot_btn)

	vbox.add_child(HSeparator.new())

	# 2. Gaveta de Habilidades Desbloqueadas
	var drawer_title := Label.new()
	drawer_title.text = "2. GAVETA DE HABILIDADES DESBLOQUEADAS (Atribuir ao Slot '%s'):" % selected_custom_slot
	drawer_title.add_theme_font_size_override("font_size", 12)
	drawer_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	vbox.add_child(drawer_title)

	var skills_vbox := VBoxContainer.new()
	skills_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(skills_vbox)

	for sk in available_skills:
		var card := PanelContainer.new()
		var c_style := StyleBoxFlat.new()
		c_style.bg_color = Color(0.07, 0.09, 0.14, 0.9)
		c_style.border_color = Color(0.2, 0.3, 0.45, 0.5)
		c_style.set_border_width_all(1)
		c_style.set_corner_radius_all(6)
		c_style.content_margin_left = 12
		c_style.content_margin_right = 12
		c_style.content_margin_top = 8
		c_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", c_style)
		skills_vbox.add_child(card)

		var chbox := HBoxContainer.new()
		chbox.add_theme_constant_override("separation", 14)
		card.add_child(chbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		chbox.add_child(info_vbox)

		var row1 := HBoxContainer.new()
		row1.add_theme_constant_override("separation", 10)
		info_vbox.add_child(row1)

		var name_l := Label.new()
		name_l.text = sk["name"]
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.add_theme_color_override("font_color", sk["color"])
		row1.add_child(name_l)

		var type_l := Label.new()
		type_l.text = "• %s" % sk["type"]
		type_l.add_theme_font_size_override("font_size", 10)
		type_l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		row1.add_child(type_l)

		var stats_l := Label.new()
		stats_l.text = "Custo: %s | Recarga: %s | Alcance: %s" % [sk["cost"], sk["cd"], sk["range"]]
		stats_l.add_theme_font_size_override("font_size", 10)
		stats_l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5))
		info_vbox.add_child(stats_l)

		var desc_l := Label.new()
		desc_l.text = sk["desc"]
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.add_theme_font_size_override("font_size", 10)
		desc_l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		info_vbox.add_child(desc_l)

		var assign_btn := Button.new()
		assign_btn.text = " Equipar em [%s] " % selected_custom_slot
		assign_btn.custom_minimum_size = Vector2(140, 36)
		assign_btn.add_theme_font_size_override("font_size", 11)
		assign_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var act_id: int = sk["action_id"]
		assign_btn.pressed.connect(func():
			pending_keybinds[selected_custom_slot] = act_id
			_save_and_apply_keybinds()
			_build_tab_4_customize_slots(race_id, class_id)
		)
		chbox.add_child(assign_btn)

	vbox.add_child(HSeparator.new())

	# 3. Rodapé com Salvar e Restaurar
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(footer_hbox)

	var save_btn := Button.new()
	save_btn.text = " 💾 Salvar & Aplicar Slots de Ação "
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.custom_minimum_size = Vector2(0, 38)
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	save_btn.pressed.connect(func():
		_save_and_apply_keybinds()
		close_menu()
	)
	footer_hbox.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = " 🔄 Restaurar Padrão "
	reset_btn.custom_minimum_size = Vector2(180, 38)
	reset_btn.add_theme_font_size_override("font_size", 12)
	reset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset_btn.pressed.connect(func():
		pending_keybinds = {"LMB": 1, "Q": 3, "R": 4, "F": 5, "Z": 6}
		_save_and_apply_keybinds()
		_build_tab_4_customize_slots(race_id, class_id)
	)
	footer_hbox.add_child(reset_btn)

func _save_and_apply_keybinds() -> void:
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.apply_skill_keybinds(pending_keybinds)
	if world and world.has_method("_setup_action_bar"):
		world._setup_action_bar()
	if world and world.has_method("show_loot_toast"):
		world.show_loot_toast("Slots de Ação salvos e sincronizados com sucesso!")
