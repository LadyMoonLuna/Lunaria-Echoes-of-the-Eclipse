extends Node3D

@export var local_player_scene: PackedScene = preload("res://scenes/LocalPlayer.tscn")
@export var remote_player_scene: PackedScene = preload("res://scenes/RemotePlayer.tscn")
@export var npc_scene: PackedScene = preload("res://scenes/NPC.tscn")
const MobEntityScript = preload("res://scripts/MobEntity.gd")
const CharacterSelectUIScript = preload("res://scripts/CharacterSelectUI.gd")
const AttributesUIScript = preload("res://scripts/AttributesUI.gd")
const InventoryUIScript = preload("res://scripts/InventoryUI.gd")
const EntityOfferUIScript = preload("res://scripts/EntityOfferUI.gd")
const SkillsUIScript = preload("res://scripts/SkillsUI.gd")
const ClassMasterUIScript = preload("res://scripts/ClassMasterUI.gd")
const DevDropRatesUIScript = preload("res://scripts/DevDropRatesUI.gd")
# const DevManagerUI = preload("res://scripts/DevManagerUI.gd")
const AutopsyUIScript = preload("res://scripts/AutopsyUI.gd")
const CorpseEntityScript = preload("res://scripts/CorpseEntity.gd")

@onready var players_container: Node3D = $Players
@onready var npcs_container: Node3D = $NPCs
@onready var clock_label: Label = $HUD/ClockPanel/ClockLabel
@onready var identity_label: Label = $HUD/PlayerStatusPanel/VBox/IdentityLabel
@onready var hp_bar: ProgressBar = $HUD/PlayerStatusPanel/VBox/HPBar
@onready var hp_label: Label = $HUD/PlayerStatusPanel/VBox/HPLabel
@onready var stamina_bar: ProgressBar = $HUD/PlayerStatusPanel/VBox/StaminaBar
@onready var stamina_label: Label = $HUD/PlayerStatusPanel/VBox/StaminaLabel
@onready var dialogue_label: Label = $HUD/DialogueLabel
@onready var dialogue_clear_timer: Timer = $HUD/DialogueClearTimer
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var rain_particles: CPUParticles3D = get_node_or_null("RainParticles")
@onready var NetworkManager: Node = get_node_or_null("/root/NetworkManager")

var local_player: CharacterBody3D = null
var remote_players: Dictionary = {}
var npcs: Dictionary = {}
var mobs: Dictionary = {}
var mobs_container: Node3D = null
var projectiles_container: Node3D = null
var active_projectiles: Dictionary = {}
var corpses: Dictionary = {}
var corpses_container: Node3D = null
var char_select_ui: CanvasLayer = null
var attributes_ui: CanvasLayer = null
var inventory_ui: CanvasLayer = null
var entity_offer_ui: CanvasLayer = null
var skills_ui: CanvasLayer = null
var class_master_ui: CanvasLayer = null
var dev_drop_rates_ui: CanvasLayer = null
var dev_manager_ui: Control = null
var dev_manager_node = null
var dev_race_menu_ui = null
var autopsy_ui: CanvasLayer = null
var house_doors: Array = []
var zone_marker_nodes: Array = []
var _entity_anim_time: float = 0.0

var xp_bar: ProgressBar = null
var xp_label: Label = null
var stat_alert_label: Label = null
var my_xp: int = 0
var my_next_level_xp: int = 100
var my_stat_points: int = 0

var loot_toast_panel: PanelContainer = null
var loot_toast_label: Label = null
var loot_toast_timer: Timer = null

const MOON_NAMES := [
	"Lua Nova",
	"Lua Crescente",
	"Quarto Crescente",
	"Gibosa Crescente",
	"Lua Cheia",
	"Gibosa Minguante",
	"Quarto Minguante",
	"Lua Minguante",
	"LUA DE SANGUE",
	"ECLIPSE TOTAL"
]
const WEATHER_NAMES := ["Limpo", "Chuva", "Neblina Densa", "Névoa Carmesim"]
const RACE_NAMES := [
	"",
	"Valeriano",
	"Noctari",
	"Kharad",
	"Varkai",
	"Dhampir",
	"Licantropo Primordial (Varkai Alfa)",
	"Amaldiçoado das Cinzas (Revenant)"
]
const CLASS_NAMES := [
	"Viajante (Sem Classe)", "Espadachim", "Batedor", "Iniciado", "Acólito",
	"Ferreiro", "Alquimista", "Ceifador do Eclipse", "Artífice Rúnico", "Criador de Homúnculos",
	"Dançarino Astral", "Inquisidor das Cinzas", "Necromante de Ossos", "Domador Primordial",
	"Cavaleiro da Ruptura", "Arauto da Tempestade"
]
const TIER_NAMES := ["Sem Classe", "Comum", "Incomum", "Rara", "Épica", "Única", "Lendária"]

const EVOLVED_CLASS_NAMES := {
	1: ["", "Espadachim", "Guardião", "Bastião de Ferro", "Vanguarda Real", "Vanguarda Real", "Vanguarda Real"],
	2: ["", "Batedor", "Patrulheiro", "Franco-Atirador", "Mestre Rastreador", "Mestre Rastreador", "Mestre Rastreador"],
	3: ["", "Iniciado", "Mago do Véu", "Arquimago", "Tecelão do Eclipse", "Tecelão do Eclipse", "Tecelão do Eclipse"],
	4: ["", "Acólito", "Clérigo Solar", "Sacerdote da Luz", "Hierofante Sagrado", "Hierofante Sagrado", "Hierofante Sagrado"],
	5: ["", "Ferreiro", "Armeiro de Guerra", "Mestre da Bigorna", "Grão-Mestre Forjador", "Grão-Mestre Forjador", "Grão-Mestre Forjador"],
	6: ["", "Alquimista", "Boticário Tóxico", "Grão-Mestre Químico", "Mestre da Transmutação", "Mestre da Transmutação", "Mestre da Transmutação"],
	7: ["", "Ceifador do Eclipse", "Ceifador do Eclipse", "Ceifador do Eclipse", "Ceifador do Eclipse", "Ceifador do Eclipse", "Soberano da Meia-Noite"],
	8: ["", "Artífice Rúnico", "Artífice Rúnico", "Artífice Rúnico", "Artífice Rúnico", "Artífice Rúnico", "Engenheiro Arcano Supremo"],
	9: ["", "Criador de Homúnculos", "Criador de Homúnculos", "Criador de Homúnculos", "Criador de Homúnculos", "Criador de Homúnculos", "Demiurgo da Vida Sintética"],
	10: ["", "Dançarino Astral", "Dançarino Astral", "Dançarino Astral", "Dançarino Astral", "Dançarino Astral", "Soberano das Constelações"],
	11: ["", "Inquisidor das Cinzas", "Inquisidor das Cinzas", "Inquisidor das Cinzas", "Inquisidor das Cinzas", "Inquisidor das Cinzas", "Grão-Inquisidor das Chamas"],
	12: ["", "Necromante de Ossos", "Necromante de Ossos", "Necromante de Ossos", "Necromante de Ossos", "Necromante de Ossos", "Lorde do Ossuário Eterno"],
	13: ["", "Domador Primordial", "Domador Primordial", "Domador Primordial", "Domador Primordial", "Domador Primordial", "Avatar da Fera Ancestral"],
	14: ["", "Cavaleiro da Ruptura", "Cavaleiro da Ruptura", "Cavaleiro da Ruptura", "Cavaleiro da Ruptura", "Cavaleiro da Ruptura", "Guardião da Singularidade"],
	15: ["", "Arauto da Tempestade", "Arauto da Tempestade", "Arauto da Tempestade", "Arauto da Tempestade", "Arauto da Tempestade", "Soberano dos Relâmpagos"]
}

const TIER_COLORS := [
	Color("#ffffff"), # 0
	Color("#ffffff"), # 1 Comum
	Color("#2ecc71"), # 2 Incomum
	Color("#3498db"), # 3 Rara
	Color("#9b59b6"), # 4 Épica
	Color("#f1c40f"), # 5 Única
	Color("#e74c3c"), # 6 Lendária
]

const CLASS_SKILLS := {
	0: {
		"basic": "Golpe Simples",
		"q": "Investida",
		"r": "Respirar Fundo",
		"f": "Instinto",
		"basic_desc": "Golpe simples desarmado ou com arma improvisada (1.0x dano).",
		"q_desc": "Investida rápida à frente desferindo uma estocada simples (1.2x dano).",
		"r_desc": "Postura defensiva temporária que recupera +15 de Stamina.",
		"f_desc": "Salto para trás com foco aumentado reduzindo dano por 2s."
	},
	1: {
		"basic": "Corte da Lâmina",
		"q": "Corte Crescente",
		"r": "Postura de Ferro",
		"f": "Impacto Sísmico",
		"basic_desc": "Golpe rápido de espada em arco frontal (1.0x dano base).",
		"q_desc": "Talho ascendente poderoso cortando alvos em cone amplo (1.75x dano).",
		"r_desc": "Parry que reduz 70% de dano por 2.5s e causa choque nos inimigos.",
		"f_desc": "Salto esmagador cravando a lâmina no solo, liberando onda sísmica de 4.5m (2.4x dano)."
	},
	2: {
		"basic": "Disparo Rápido",
		"q": "Disparo Perfurante",
		"r": "Chuva de Estrepes",
		"f": "Saraivada Estelar",
		"basic_desc": "Flecha balística veloz de longo alcance (1.0x dano).",
		"q_desc": "Flecha pontiaguda de alta velocidade que atravessa múltiplos alvos (1.75x dano).",
		"r_desc": "Dispara estrepes que reduzem movimentação dos monstros em 40% por 3s.",
		"f_desc": "Dispara 3 flechas encantadas simultâneas em cone frontal aberto (2.4x dano total)."
	},
	3: {
		"basic": "Orbe Arcano",
		"q": "Cometa Elemental",
		"r": "Nova de Gelo",
		"f": "Maelstrom Cósmico",
		"basic_desc": "Projétil de energia cósmica concentrada com velocidade de 16m/s (1.0x dano).",
		"q_desc": "Grande esfera de fogo estelar que explode em raio de 2.8m (1.75x dano).",
		"r_desc": "Onda congelante de 5.0m radial que paralisa e desacelera monstros por 1.5s.",
		"f_desc": "Tempestade arcana colossal de devastação massiva em raio de 6.5m (2.4x dano)."
	},
	4: {
		"basic": "Golpe da Fé",
		"q": "Círculo de Luz",
		"r": "Lança do Julgamento",
		"f": "Égide Sagrada",
		"basic_desc": "Pancada de maça abençoada causando dano sagrado puro (1.0x dano).",
		"q_desc": "Impacto sagrado que causa dano e cura +40 HP em aliados em 6.0m.",
		"r_desc": "Feixe divino perfurante lançado a até 15m que purifica os alvos.",
		"f_desc": "Explosão celestial restaurando +65 HP no grupo e desferindo 2.4x dano sagrado."
	},
	5: {
		"basic": "Martelada Pesada",
		"q": "Golpe de Bigorna",
		"r": "Afiação de Combate",
		"f": "Fúria do Vulcão",
		"basic_desc": "Golpe esmagador contundente que atordoa armaduras leves (1.0x dano).",
		"q_desc": "Impacto pesado concentrado no topo do crânio do alvo (1.75x dano).",
		"r_desc": "Martela a bigorna conferindo buff de +25% de dano para o grupo por 10s.",
		"f_desc": "Impacto sísmico frontal telegrafado de 4.5m abrindo fendas incandescentes (2.4x dano)."
	},
	6: {
		"basic": "Frasco Cáustico",
		"q": "Frasco de Éter",
		"r": "Bomba de Ácido",
		"f": "Detonação Catalítica",
		"basic_desc": "Arremesso de ampola corrosiva com alcance médio (1.0x dano).",
		"q_desc": "Frasco que detona causando dano em área e curando +40 HP em aliados em 6.0m.",
		"r_desc": "Arremessa poça corrosiva de 3.5m que reduz armaduras dos inimigos por 4s.",
		"f_desc": "Reação química em cadeia explodindo violentamente em área de 5.5m (2.4x dano)."
	},
	7: {
		"basic": "Foice das Sombras",
		"q": "Colheita Noturna",
		"r": "Drenagem Abissal",
		"f": "Dança do Eclipse Total",
		"basic_desc": "Varredura ampla de longo alcance de 4.8m com lifesteal embutido (1.0x dano).",
		"q_desc": "Corte espiral sugando essência vital de todos os alvos no caminho (1.75x dano).",
		"r_desc": "Vórtice escuro que paralisa alvos e restaura +45 HP contínuos ao usuário.",
		"f_desc": "Giro fatal de foice cobrindo 6.0m com dano devastador e roubo de vida (2.4x dano)."
	},
	8: {
		"basic": "Canhonada Rúnica",
		"q": "Salva Rúnica",
		"r": "Sobrecarga Eletrostática",
		"f": "Bombardeio Titanomecânico",
		"basic_desc": "Pancada física e detonação de pólvora simultâneas (1.0x dano).",
		"q_desc": "Três cartuchos energizados disparados em rápida sucessão frontal (1.75x dano).",
		"r_desc": "Pulso elétrico que concede raios nas armas do grupo por 8s.",
		"f_desc": "Disparo orbital com estilhaços energizados de 6.5m (2.4x dano)."
	},
	9: {
		"basic": "Pulso Quimérico",
		"q": "Infusão Mutagênica",
		"r": "Névoa de Bioplasma",
		"f": "Frenesi do Quimera Supremo",
		"basic_desc": "Onda biótica disparada pelo homúnculo que causa dano e regenera o mestre (1.0x dano).",
		"q_desc": "Elixir abissal corrosivo que dissolve resistências inimigas (1.75x dano).",
		"r_desc": "Nuvem esverdeada curando aliados continuamente e cegando monstros.",
		"f_desc": "O homúnculo cresce e desfere explosão de garras e ácido colossais (2.4x dano)."
	},
	10: {
		"basic": "Corte Astral",
		"q": "Corte Cadente",
		"r": "Valsa dos Espelhos",
		"f": "Constelação de Mil Lâminas",
		"basic_desc": "Corte rápido com +25% de chance crítica permanente e esquiva barata de 10 stamina.",
		"q_desc": "Salto veloz que corta o espaço desferindo dano massivo (2.0x dano).",
		"r_desc": "Janela de 1.5s de invulnerabilidade total (I-Frame) seguida de contra-ataque refletor.",
		"f_desc": "Dança de cortes omnidirecionais devastando inimigos em raio de 5.5m (3.0x dano)."
	},
	11: {
		"basic": "Chama Penitente",
		"q": "Chicote de Penitência",
		"r": "Selo de Excomunhão",
		"f": "Crucificação de Cinzas",
		"basic_desc": "Golpe ardente que ganha até +60% de dano conforme o HP diminui.",
		"q_desc": "Chicote de fogo sagrado de 8.0m que causa 2.2x dano e rouba vida.",
		"r_desc": "Purificação sagrada que regenera +35 HP e incendeia inimigos em raio de 5.0m.",
		"f_desc": "Pilares de cinzas incandescentes que incineram uma área de 6.0m (3.2x dano)."
	},
	12: {
		"basic": "Toque do Sepulcro",
		"q": "Lança de Fêmur",
		"r": "Explosão Óssea & Escudo",
		"f": "Legião do Ossuário",
		"basic_desc": "Projétil de ossos fragmentados. Cada abate regenera +20 HP instantâneos.",
		"q_desc": "Dispara lança de fêmur calcificado que perfura a 16m causando 2.0x dano.",
		"r_desc": "Detona fragmentos ósseos em 5.0m e ergue barreira de ossos protetora.",
		"f_desc": "Ergue vórtice de ossatura profana cobrindo 6.0m com 3.0x de dano letal."
	},
	13: {
		"basic": "Patada Selvagem",
		"q": "Investida do Alfa",
		"r": "Uivo da Alcateia",
		"f": "Fúria do Behemoth",
		"basic_desc": "Ataque corporal com ferocidade primal e dano aumentado em +25% permanentemente.",
		"q_desc": "Avanço bestial rompendo as linhas inimigas com impacto violento (2.1x dano).",
		"r_desc": "Uivo ressonante que cura +50 HP e concede buff de ataque crítico a todo o grupo.",
		"f_desc": "Impacto frontal titânico gerando onda de choque sísmica devastadora (3.0x dano)."
	},
	14: {
		"basic": "Golpe de Fenda",
		"q": "Esmagamento Gravitacional",
		"r": "Singularidade Reversa",
		"f": "Colapso Estelar",
		"basic_desc": "Golpe pesado imbuído de gravidade e resistência passiva de -30% a danos.",
		"q_desc": "Atrai monstros em 5.0m para junto de si e esmaga o solo (1.9x dano).",
		"r_desc": "Postura de bloqueio que absorve 80% do dano e implode o espaço ao redor.",
		"f_desc": "Cria um buraco negro em 6.5m que atordoa inimigos e desintegra matéria (2.8x dano)."
	},
	15: {
		"basic": "Faísca Elétrica",
		"q": "Lança do Trovão",
		"r": "Passo de Relâmpago",
		"f": "Ira dos Céus",
		"basic_desc": "Dardos elétricos estáticos que causam +35% de dano durante climas chuvosos.",
		"q_desc": "Arremessa um raio concentrado a 18m que detona ao impacto (2.1x dano).",
		"r_desc": "Surto elétrico que concede velocidade e eletrocuta/atordoa monstros próximos.",
		"f_desc": "Tempestade cataclísmica de raios cobrindo 6.0m com devastação celestial (3.1x dano)."
	}
}

const RACIAL_SKILL_NAMES := {
	1: "Ímpeto Valeriano",
	11: "Estandarte Real",
	12: "Fenda do Éter",
	2: "Explosão Lunar",
	21: "Luz de Selene",
	22: "Manto de Nyx",
	3: "Baluarte Rúnico",
	31: "Muralha Rúnica",
	32: "Erupção Magma",
	4: "Sopro Dracônico",
	41: "Chamas Reais",
	42: "Frenesi Feral",
	5: "Sede de Sangue"
}

var current_world_hour: int = 16
var current_world_minute: int = 0
var current_moon_phase: int = 1
var current_weather_type: int = 0

var my_race_id: int = 1
var my_class_id: int = 0
var my_class_tier: int = 0
var my_level: int = 1
var my_buff_active: int = 0
var my_hp: int = 100
var my_max_hp: int = 100
var my_stamina: int = 100
var my_max_stamina: int = 100

var action_bar_container: HBoxContainer = null
var action_bar_slots: Array[PanelContainer] = []
var action_bar_name_labels: Array[Label] = []

func _ready() -> void:
	mobs_container = Node3D.new()
	mobs_container.name = "Mobs"
	add_child(mobs_container)

	projectiles_container = Node3D.new()
	projectiles_container.name = "Projectiles"
	add_child(projectiles_container)

	char_select_ui = CharacterSelectUIScript.new()
	add_child(char_select_ui)
	char_select_ui.identity_confirmed.connect(_on_identity_confirmed)

	attributes_ui = AttributesUIScript.new()
	add_child(attributes_ui)

	inventory_ui = InventoryUIScript.new()
	add_child(inventory_ui)

	entity_offer_ui = EntityOfferUIScript.new()
	add_child(entity_offer_ui)

	skills_ui = SkillsUIScript.new()
	add_child(skills_ui)

	class_master_ui = ClassMasterUIScript.new()
	add_child(class_master_ui)

	dev_drop_rates_ui = DevDropRatesUIScript.new()
	add_child(dev_drop_rates_ui)

	corpses_container = Node3D.new()
	corpses_container.name = "Corpses"
	add_child(corpses_container)

	autopsy_ui = AutopsyUIScript.new()
	add_child(autopsy_ui)
	autopsy_ui.autopsy_completed.connect(_on_autopsy_completed)

	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.world_state_received.connect(_on_world_state_received)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.npc_state_received.connect(_on_npc_state_received)
	NetworkManager.npc_spoke.connect(_on_npc_spoke)
	NetworkManager.world_time_updated.connect(_on_world_time_updated)
	NetworkManager.combat_event_received.connect(_on_combat_event_received)
	NetworkManager.player_stats_received.connect(_on_player_stats_received)
	NetworkManager.player_stats_full_received.connect(_on_player_stats_full_received)
	NetworkManager.player_attributes_received.connect(_on_player_attributes_received)
	NetworkManager.player_respawn_received.connect(_on_player_respawn_received)
	NetworkManager.mob_state_received.connect(_on_mob_state_received)
	NetworkManager.aoe_telegraph_received.connect(_on_aoe_telegraph_received)
	NetworkManager.projectile_spawned.connect(_on_projectile_spawned)
	NetworkManager.dev_drop_rates_received.connect(_on_dev_drop_rates_received)
	NetworkManager.corpse_snapshot_received.connect(_on_corpse_snapshot_received)
	NetworkManager.open_autopsy_ui_received.connect(_on_open_autopsy_ui_received)

	_create_perimeter_walls()
	_create_zone_landmarks()
	_create_rebirth_crystal()
	_build_symmetric_village()
	_build_new_landmarks()
	_setup_burn_overlay()
	_setup_action_bar()
	_setup_xp_hud()
	_setup_loot_toast()
	_spawn_local_player(Vector3(0, 1.5, 0))
	_update_hud()
	_update_clock_hud()

	var footer_lbl = get_node_or_null("HUD/FooterPanel/FooterLabel")
	if footer_lbl:
		footer_lbl.text = "[WASD] Mover | [LMB] Ataque | [Shift] Esquiva | [Q/R/F] Skills | [Z] Racial | [E] Interagir | [C] Linhagem | [K] Atributos | [I] Inventário | [H] Grimório | [F10] Dev Manager"

func _process(delta: float) -> void:
	# 1. Lógica de atualização de tempo, clima e iluminação do mundo
	_update_world_environment(delta)

	# 2. Atualização dos marcadores, NPCs e entidades visuais
	_update_entities_interpolation(delta)

	# 3. Verificações de proximidade (ex: portas das casas, forja e interações)
	_check_proximity_interactions()

func _update_entities_interpolation(delta: float) -> void:
	_entity_anim_time += delta

	# Animação suave e flutuante dos marcadores de zona e santuário
	for m in zone_marker_nodes:
		if is_instance_valid(m):
			for child in m.get_children():
				if child is Label3D:
					if not child.has_meta("base_y"):
						child.set_meta("base_y", child.position.y)
					var base_y: float = child.get_meta("base_y")
					child.position.y = base_y + sin(_entity_anim_time * 2.2) * 0.08
				elif child is MeshInstance3D and child.name == "SanctuaryGate":
					var mat = child.material_override as StandardMaterial3D
					if mat and mat.emission_enabled:
						mat.emission_energy_multiplier = 1.8 + sin(_entity_anim_time * 3.0) * 0.5

func _check_proximity_interactions() -> void:
	if not local_player:
		return

	var player_pos: Vector3 = local_player.global_position

	# 1. Proximidade de Cadáveres (atualiza destaque do Label3D em <= 2.5m)
	for cid in corpses.keys():
		var corpse_node = corpses[cid]
		if is_instance_valid(corpse_node):
			var dist: float = player_pos.distance_to(corpse_node.global_position)
			corpse_node.update_player_distance(dist)

	# 2. Proximidade de Portas e Interiores (Forja de Garrick, Taverna, Casa da Alquimista, Quartel)
	for d in house_doors:
		var lbl: Label3D = d.get("label_node")
		if is_instance_valid(lbl):
			var dist_out: float = player_pos.distance_to(d["door_outside"])
			var dist_in: float = player_pos.distance_to(d["door_inside"])
			var min_dist: float = minf(dist_out, dist_in)
			if min_dist <= 2.5:
				lbl.modulate = Color(1.0, 0.95, 0.25, 1.0)
				lbl.outline_modulate = Color(0.85, 0.45, 0.0, 1.0)
				lbl.scale = Vector3(1.15, 1.15, 1.15)
			else:
				lbl.modulate = Color(0.9, 0.82, 0.65, 0.75)
				lbl.outline_modulate = Color(0, 0, 0, 1.0)
				lbl.scale = Vector3.ONE

	# 3. Proximidade de NPCs (destaque visual do NPC mais próximo para interação [E])
	var nearest_npc_id: int = 0
	var min_npc_dist: float = 3.5
	for nid in npcs.keys():
		var npc_node = npcs[nid]
		if is_instance_valid(npc_node) and npc_node.visible:
			var dist: float = player_pos.distance_to(npc_node.global_position)
			if dist <= min_npc_dist:
				min_npc_dist = dist
				nearest_npc_id = nid

	for nid in npcs.keys():
		var npc_node = npcs[nid]
		if is_instance_valid(npc_node) and npc_node.visible:
			var ntag: Label3D = npc_node.get_node_or_null("NameTag")
			if ntag:
				if nid == nearest_npc_id:
					ntag.modulate = Color(1.0, 0.95, 0.35, 1.0)
					ntag.outline_size = 8
				else:
					ntag.modulate = Color(1.0, 1.0, 1.0, 0.9)
					ntag.outline_size = 6

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			print("[World] F9: Alternando Dev Manager Unificado...")
			_toggle_dev_manager()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if not _try_interact_corpse():
				if not _try_interact_door():
					_try_interact_nearest_npc()
		elif event.keycode == KEY_C or event.keycode == KEY_TAB:
			if char_select_ui:
				if char_select_ui.is_open:
					char_select_ui.close_menu()
				else:
					char_select_ui.open_menu()
		elif event.keycode == KEY_K:
			if attributes_ui:
				attributes_ui.toggle_menu()
		elif event.keycode == KEY_I:
			if inventory_ui:
				inventory_ui.toggle_menu()
		elif event.keycode == KEY_H:
			if skills_ui:
				skills_ui.toggle_menu()
		elif event.keycode == KEY_F9:
			print("[World] F9: Alternando Dev Manager Unificado...")
			_toggle_dev_manager()

func _toggle_dev_manager() -> void:
	if not dev_manager_node or not is_instance_valid(dev_manager_node):
		var script_res = load("res://scripts/DevManagerUI.gd")
		if script_res:
			# Cria um Control e atribui o script do DevManagerUI dinamicamente
			dev_manager_node = Control.new()
			dev_manager_node.set_script(script_res)
			dev_manager_node.set_anchors_preset(Control.PRESET_FULL_RECT)
			if has_node("HUD"):
				$HUD.add_child(dev_manager_node)
			else:
				add_child(dev_manager_node)
			dev_manager_ui = dev_manager_node
			dev_race_menu_ui = dev_manager_node

	if dev_manager_node:
		dev_manager_node.visible = not dev_manager_node.visible

		if dev_manager_node.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if local_player and is_instance_valid(local_player):
				local_player.set("is_menu_open", true)
			if dev_manager_node.has_method("_update_trials_label"):
				dev_manager_node._update_trials_label()
		else:
			var any_other_open := false
			if char_select_ui and char_select_ui.get("is_open"): any_other_open = true
			if attributes_ui and attributes_ui.get("is_open"): any_other_open = true
			if inventory_ui and inventory_ui.get("is_open"): any_other_open = true
			if skills_ui and skills_ui.get("is_open"): any_other_open = true
			if dev_drop_rates_ui and dev_drop_rates_ui.get("is_open"): any_other_open = true
			if not any_other_open:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				if local_player and is_instance_valid(local_player):
					local_player.set("is_menu_open", false)

func _on_skip_time_pressed() -> void:
	print("[World] F6: Solicitando avanço de +6 horas ao servidor...")
	NetworkManager.send_world_control(1, 6)

func _on_cycle_moon_pressed() -> void:
	print("[World] F7: Ciclando fase da lua no servidor...")
	NetworkManager.send_world_control(2, 1)

func _on_cycle_weather_pressed() -> void:
	print("[World] F8: Ciclando clima no servidor...")
	NetworkManager.send_world_control(3, 1)

func _on_dev_get_drop_rates_pressed() -> void:
	print("[World] F9: Alternando painel flutuante de taxas de drop...")
	if dev_drop_rates_ui:
		dev_drop_rates_ui.toggle_menu()

func _on_dev_races_menu_pressed() -> void:
	_toggle_dev_manager()

func _on_dev_drop_rates_received(report_text: String) -> void:
	print("[World DEV] Taxas de Drop recebidas do Servidor:\n%s" % report_text)
	if dev_drop_rates_ui:
		dev_drop_rates_ui.set_report_text(report_text)
	show_loot_toast("Taxas de Drop sincronizadas com o Servidor (F9)!")

func _try_interact_corpse() -> bool:
	if not local_player:
		return false

	var player_pos: Vector3 = local_player.global_position
	var nearest_corpse_id: int = 0
	var min_dist: float = 2.5 # Alcance de 2.5m

	for cid in corpses.keys():
		var corpse_node = corpses[cid]
		if is_instance_valid(corpse_node) and not corpse_node.is_looted:
			var dist: float = player_pos.distance_to(corpse_node.global_position)
			if dist <= min_dist:
				min_dist = dist
				nearest_corpse_id = cid

	if nearest_corpse_id > 0:
		print("[World] Interagindo com Cadáver #%d (distância: %.2fm <= 2.5m)" % [nearest_corpse_id, min_dist])
		NetworkManager.send_interact_corpse(nearest_corpse_id)
		return true

	return false

func _on_corpse_snapshot_received(corpses_dict: Dictionary) -> void:
	for cid in corpses_dict.keys():
		var cdata: Dictionary = corpses_dict[cid]
		if corpses.has(cid):
			var corpse_node = corpses[cid]
			if is_instance_valid(corpse_node):
				corpse_node.update_data(cdata.position, cdata.rotation_y, cdata.is_looted, cdata.remaining_sec)
				if cdata.is_looted:
					corpses.erase(cid)
					corpse_node.queue_free()
		else:
			if not cdata.is_looted:
				_spawn_corpse(cid, cdata.mob_id, cdata.mob_type, cdata.position, cdata.rotation_y, cdata.is_looted, cdata.remaining_sec)

	var to_remove := []
	for cid in corpses.keys():
		if not corpses_dict.has(cid):
			to_remove.append(cid)
	for cid in to_remove:
		if is_instance_valid(corpses[cid]):
			corpses[cid].queue_free()
		corpses.erase(cid)

func _spawn_corpse(cid: int, mid: int, mtype: int, pos: Vector3, rot_y: float, is_looted: bool, remaining_sec: int) -> void:
	var corpse = CorpseEntityScript.new()
	if corpses_container:
		corpses_container.add_child(corpse)
	else:
		add_child(corpse)
	corpse.setup(cid, mid, mtype, pos, rot_y, is_looted, remaining_sec)
	corpses[cid] = corpse
	print("[World] Cadáver instanciado no chão: ID %d (MobType %d) em %s (restante: %ds)" % [cid, mtype, pos, remaining_sec])

func _on_open_autopsy_ui_received(corpse_id: int, mob_type: int, difficulty_seed: int, organs: Array) -> void:
	if autopsy_ui:
		autopsy_ui.open_autopsy(corpse_id, mob_type, difficulty_seed, organs)

func _on_autopsy_completed(corpse_id: int) -> void:
	if corpses.has(corpse_id):
		var corpse_node = corpses[corpse_id]
		if is_instance_valid(corpse_node):
			corpse_node.queue_free()
		corpses.erase(corpse_id)

func _try_interact_door() -> bool:
	if not local_player:
		return false

	var player_pos: Vector3 = local_player.global_position
	for d in house_doors:
		var dist_out: float = player_pos.distance_to(d["door_outside"])
		var dist_in: float = player_pos.distance_to(d["door_inside"])

		if dist_out <= 2.2:
			local_player.global_position = d["door_inside"]
			show_loot_toast("Você entrou em: %s" % d["name"])
			print("[World] Entrou em %s" % d["name"])
			return true
		elif dist_in <= 2.2:
			local_player.global_position = d["door_outside"]
			show_loot_toast("Você saiu para a rua da vila.")
			print("[World] Saiu de %s para a rua" % d["name"])
			return true

	return false

func _try_interact_nearest_npc() -> void:
	if not local_player:
		return

	var player_pos: Vector3 = local_player.global_position
	var nearest_id: int = 0
	var min_dist: float = 5.0 # Alcance de interação

	for nid in npcs.keys():
		var npc_node = npcs[nid]
		if is_instance_valid(npc_node) and npc_node.visible:
			var dist = player_pos.distance_to(npc_node.global_position)
			if dist <= min_dist:
				min_dist = dist
				nearest_id = nid

	if nearest_id > 0:
		print("[World] Interagindo com NPC #%d (distância: %.2fm)" % [nearest_id, min_dist])
		NetworkManager.send_player_interact(nearest_id)
		if nearest_id in [100, 103, 104, 105, 106, 107, 108, 109, 110]:
			if class_master_ui:
				class_master_ui.open_master_menu(nearest_id)

func _spawn_local_player(spawn_pos: Vector3) -> void:
	if local_player != null:
		return
	local_player = local_player_scene.instantiate()
	players_container.add_child(local_player)
	local_player.global_position = spawn_pos
	local_player.identity_changed.connect(_on_local_identity_changed)
	local_player.action_triggered.connect(_on_local_action_triggered)

func _on_local_action_triggered(action_type: int) -> void:
	match action_type:
		1: flash_action_bar_slot(0) # LMB
		3: flash_action_bar_slot(1) # Q
		4: flash_action_bar_slot(2) # R
		5: flash_action_bar_slot(3) # F
		6: flash_action_bar_slot(4) # Z Racial

func _on_local_identity_changed(race_id: int, class_id: int) -> void:
	my_race_id = race_id
	my_class_id = class_id
	_update_hud()

func _on_connected_to_server(_player_id: int) -> void:
	_update_hud()
	# Envia seleção de identidade inicial (Valeriano / Espadachim)
	NetworkManager.send_select_identity(my_race_id, my_class_id)

func _on_world_time_updated(hour: int, minute: int, moon_phase: int = 1, weather_type: int = 0) -> void:
	current_world_hour = hour
	current_world_minute = minute
	current_moon_phase = moon_phase
	current_weather_type = weather_type
	_update_clock_hud()

	for mob in mobs.values():
		if is_instance_valid(mob):
			mob.set_moon_phase(current_moon_phase)

func _update_clock_hud() -> void:
	if not clock_label:
		return

	var period_str: String = "Dia" if (current_world_hour >= 6 and current_world_hour < 18) else "Noite"
	var moon_str: String = MOON_NAMES[current_moon_phase] if current_moon_phase < MOON_NAMES.size() else "Lua"
	var weather_str: String = WEATHER_NAMES[current_weather_type] if current_weather_type < WEATHER_NAMES.size() else "Limpo"

	clock_label.text = "Horário: %02d:%02d (%s) | %s | %s" % [
		current_world_hour, current_world_minute, period_str, moon_str, weather_str
	]

func _on_combat_event_received(attacker_id: int, target_id: int, action_type: int, damage: int, is_crit: int, target_hp: int, target_max_hp: int) -> void:
	if attacker_id != NetworkManager.my_player_id and remote_players.has(attacker_id):
		if is_instance_valid(remote_players[attacker_id]):
			remote_players[attacker_id].play_skill_animation(action_type)

	if damage > 0 and target_id > 0:
		var crit_str := " [CRÍTICO!]" if is_crit == 1 else ""
		print("[World] Combate: Atacante #%d atingiu Alvo #%d causando %d de dano%s (HP Alvo: %d/%d)" % [
			attacker_id, target_id, damage, crit_str, target_hp, target_max_hp
		])

		var target_pos: Vector3 = Vector3.ZERO

		# Se for Mob (ID >= 200)
		if target_id >= 200 and mobs.has(target_id):
			if is_instance_valid(mobs[target_id]):
				target_pos = mobs[target_id].global_position
				mobs[target_id].show_damage(damage, is_crit == 1, target_hp, target_max_hp)

		# Se for NPC / Dummy (1, 101, 102)
		elif npcs.has(target_id):
			if is_instance_valid(npcs[target_id]):
				target_pos = npcs[target_id].global_position
				npcs[target_id].show_damage(damage, is_crit == 1, target_hp, target_max_hp)

		# Se for Jogador (ID 1 a 5)
		elif target_id >= 1 and target_id <= 5:
			if target_id == NetworkManager.my_player_id and local_player:
				target_pos = local_player.global_position
				if attacker_id == 999:
					_show_fire_burn_damage(local_player, damage)
				else:
					_spawn_player_floating_damage(local_player, damage)
			elif remote_players.has(target_id) and is_instance_valid(remote_players[target_id]):
				target_pos = remote_players[target_id].global_position
				if attacker_id == 999:
					_show_fire_burn_damage(remote_players[target_id], damage)
				else:
					_spawn_player_floating_damage(remote_players[target_id], damage)

		if target_pos != Vector3.ZERO:
			_check_projectile_impact(target_pos)

func _on_identity_confirmed(race_id: int, class_id: int) -> void:
	my_race_id = race_id
	my_class_id = class_id
	if local_player and is_instance_valid(local_player):
		local_player.apply_identity(race_id, class_id)
	_update_hud()

func _on_player_stats_received(player_id: int, race_id: int, class_id: int, hp: int, max_hp: int, stamina: int, max_stamina: int) -> void:
	if player_id == NetworkManager.my_player_id:
		my_race_id = race_id
		my_class_id = class_id
		my_hp = hp
		my_max_hp = max_hp
		my_stamina = stamina
		my_max_stamina = max_stamina
		if local_player and is_instance_valid(local_player):
			local_player.apply_identity(race_id, class_id)
		_update_hud()
	elif remote_players.has(player_id) and is_instance_valid(remote_players[player_id]):
		remote_players[player_id].apply_identity(race_id, class_id)

func _on_player_stats_full_received(player_id: int, race_id: int, class_id: int, class_tier: int, level: int, hp: int, max_hp: int, stamina: int, max_stamina: int, buff_active: int) -> void:
	if player_id == NetworkManager.my_player_id:
		my_race_id = race_id
		my_class_id = class_id
		my_class_tier = class_tier
		my_level = level
		my_hp = hp
		my_max_hp = max_hp
		my_stamina = stamina
		my_max_stamina = max_stamina
		my_buff_active = buff_active
		if local_player and is_instance_valid(local_player):
			local_player.apply_identity(race_id, class_id)
		_update_hud()

func _on_player_respawn_received(player_id: int, respawn_pos: Vector3) -> void:
	if player_id == NetworkManager.my_player_id:
		print("[World] Respawn autoritativo recebido! Posicionando no Centro: ", respawn_pos)
		if local_player and is_instance_valid(local_player):
			local_player.global_position = respawn_pos
			local_player.velocity = Vector3.ZERO
		_update_hud()
	elif remote_players.has(player_id) and is_instance_valid(remote_players[player_id]):
		remote_players[player_id].global_position = respawn_pos

func _get_evolved_class_name(cid: int, tier: int) -> String:
	if cid == 0:
		return "Viajante (Sem Classe)"
	if EVOLVED_CLASS_NAMES.has(cid):
		var names_list: Array = EVOLVED_CLASS_NAMES[cid]
		var safe_tier: int = clamp(tier, 1, names_list.size() - 1)
		return names_list[safe_tier]
	if cid >= 1 and cid < CLASS_NAMES.size():
		return CLASS_NAMES[cid]
	return "Espadachim"

func _update_hud() -> void:
	if identity_label:
		var r_name: String = RACE_NAMES[my_race_id] if my_race_id < RACE_NAMES.size() else "Valeriano"
		var c_name: String = _get_evolved_class_name(my_class_id, my_class_tier)
		var t_name: String = TIER_NAMES[my_class_tier] if my_class_tier < TIER_NAMES.size() else "Comum"
		var t_color: Color = TIER_COLORS[my_class_tier] if (my_class_tier >= 0 and my_class_tier < TIER_COLORS.size()) else Color("#ffffff")
		var pid_str: String = "#%d" % NetworkManager.my_player_id if NetworkManager.my_player_id > 0 else "..."
		var buff_str: String = " [AFIAÇÃO +25%]" if my_buff_active == 1 else ""

		identity_label.text = "[Nv.%d %s] [%s] %s%s (ID: %s)" % [my_level, t_name, r_name, c_name, buff_str, pid_str]
		identity_label.add_theme_color_override("font_color", t_color)

	if hp_bar:
		hp_bar.max_value = my_max_hp
		hp_bar.value = my_hp
	if hp_label:
		hp_label.text = "HP: %d / %d" % [my_hp, my_max_hp]

	if stamina_bar:
		stamina_bar.max_value = my_max_stamina
		stamina_bar.value = my_stamina
	if stamina_label:
		stamina_label.text = "Stamina: %d / %d" % [my_stamina, my_max_stamina]

	if xp_bar:
		xp_bar.max_value = max(1, my_next_level_xp)
		xp_bar.value = my_xp
	if xp_label:
		xp_label.text = "XP: %d / %d (Nível %d)" % [my_xp, my_next_level_xp, my_level]
	if stat_alert_label:
		if my_stat_points > 0:
			stat_alert_label.text = "[K] +%d Pontos de Status Disponíveis!" % my_stat_points
			stat_alert_label.visible = true
		else:
			stat_alert_label.text = ""
			stat_alert_label.visible = false

	_update_action_bar_skills()

func _on_player_attributes_received(player_id: int, xp: int, next_xp: int, stat_pts: int, _str_s: int, _dex_s: int, _con_s: int, _agi_s: int, _int_s: int, _spi_s: int, _mas_s: int, _lck_s: int) -> void:
	if player_id == NetworkManager.my_player_id:
		my_xp = xp
		my_next_level_xp = next_xp
		my_stat_points = stat_pts
		_update_hud()

func _setup_action_bar() -> void:
	var hud_node: CanvasLayer = get_node_or_null("HUD")
	if not hud_node:
		return

	var existing = hud_node.get_node_or_null("ActionBarPanel")
	if existing:
		_update_action_bar_skills()
		return

	var bar_panel := PanelContainer.new()
	bar_panel.name = "ActionBarPanel"
	bar_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar_panel.offset_left = -410.0
	bar_panel.offset_top = -106.0
	bar_panel.offset_right = 410.0
	bar_panel.offset_bottom = -44.0

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.04, 0.06, 0.09, 0.92)
	bar_style.border_color = Color(0.28, 0.38, 0.58, 0.6)
	bar_style.set_border_width_all(1)
	bar_style.set_corner_radius_all(8)
	bar_style.content_margin_left = 8
	bar_style.content_margin_right = 8
	bar_style.content_margin_top = 4
	bar_style.content_margin_bottom = 4
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	hud_node.add_child(bar_panel)

	action_bar_container = HBoxContainer.new()
	action_bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar_container.add_theme_constant_override("separation", 8)
	bar_panel.add_child(action_bar_container)

	action_bar_slots.clear()
	action_bar_name_labels.clear()

	var keys := ["[LMB]", "[Q]", "[R]", "[F]", "[Z]"]
	var titles := ["Básico", "Skill 1", "Skill 2", "Ultimate", "Racial"]

	for i in range(5):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(150, 52)
		var s_style := StyleBoxFlat.new()
		s_style.bg_color = Color(0.1, 0.13, 0.19, 0.95)
		s_style.border_color = Color(0.4, 0.55, 0.8, 0.5)
		s_style.set_border_width_all(1)
		s_style.set_corner_radius_all(6)
		s_style.content_margin_left = 6
		s_style.content_margin_right = 6
		s_style.content_margin_top = 4
		s_style.content_margin_bottom = 4
		slot.add_theme_stylebox_override("panel", s_style)
		action_bar_container.add_child(slot)
		action_bar_slots.append(slot)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)
		slot.add_child(vbox)

		var key_lbl := Label.new()
		key_lbl.text = "%s %s" % [keys[i], titles[i]]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		vbox.add_child(key_lbl)

		var name_lbl := Label.new()
		name_lbl.text = "Habilidade"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
		vbox.add_child(name_lbl)
		action_bar_name_labels.append(name_lbl)

	_update_action_bar_skills()

func _update_action_bar_skills() -> void:
	if action_bar_name_labels.size() < 5:
		return
	var skills: Dictionary = CLASS_SKILLS.get(my_class_id, {
		"basic": "Ataque",
		"q": "Habilidade 1",
		"r": "Habilidade 2",
		"f": "Ultimate"
	})

	var get_action_name := func(act_id: int) -> String:
		match act_id:
			1: return skills.get("basic", "Básico")
			2: return "Esquiva / Salto"
			3: return skills.get("q", "Skill 1")
			4: return skills.get("r", "Skill 2")
			5: return skills.get("f", "Ultimate")
			6: return RACIAL_SKILL_NAMES.get(my_race_id, "Skill Racial")
			_: return "Habilidade"

	var get_action_desc := func(act_id: int) -> String:
		match act_id:
			1: return skills.get("basic_desc", "Ataque básico.")
			2: return "Esquiva rápida com invulnerabilidade temporária."
			3: return skills.get("q_desc", "Habilidade Ativa [Q].")
			4: return skills.get("r_desc", "Habilidade Ativa [R].")
			5: return skills.get("f_desc", "Habilidade Suprema [F].")
			6: return "Habilidade especial inata de linhagem racial [Z]."
			_: return "Habilidade de combate."

	action_bar_name_labels[0].text = get_action_name.call(1)
	action_bar_name_labels[1].text = get_action_name.call(3)
	action_bar_name_labels[2].text = get_action_name.call(4)
	action_bar_name_labels[3].text = get_action_name.call(5)
	action_bar_name_labels[4].text = get_action_name.call(6)

	if action_bar_slots.size() >= 5:
		action_bar_slots[0].tooltip_text = "%s [LMB]\n%s" % [get_action_name.call(1), get_action_desc.call(1)]
		action_bar_slots[1].tooltip_text = "%s [Q]\n%s" % [get_action_name.call(3), get_action_desc.call(3)]
		action_bar_slots[2].tooltip_text = "%s [R]\n%s" % [get_action_name.call(4), get_action_desc.call(4)]
		action_bar_slots[3].tooltip_text = "%s [F]\n%s" % [get_action_name.call(5), get_action_desc.call(5)]
		action_bar_slots[4].tooltip_text = "%s [Z]\n%s" % [get_action_name.call(6), get_action_desc.call(6)]

func flash_action_bar_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= action_bar_slots.size():
		return
	var slot: PanelContainer = action_bar_slots[slot_idx]
	if not slot:
		return
	var tw := create_tween()
	tw.tween_property(slot, "modulate", Color(2.6, 2.6, 1.8, 1.0), 0.08)
	tw.tween_property(slot, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)

func _on_world_state_received(players_dict: Dictionary) -> void:
	for pid in players_dict.keys():
		var pdata: Dictionary = players_dict[pid]
		if pid == NetworkManager.my_player_id:
			continue

		if remote_players.has(pid):
			remote_players[pid].update_network_transform(pdata.position, pdata.rotation_y)
		else:
			_spawn_remote_player(pid, pdata.position, pdata.rotation_y)

func _spawn_remote_player(pid: int, initial_pos: Vector3, initial_rot_y: float) -> void:
	var rp = remote_player_scene.instantiate()
	players_container.add_child(rp)
	rp.global_position = initial_pos
	rp.rotation.y = initial_rot_y
	rp.set_player_id(pid)
	remote_players[pid] = rp
	print("[World] Jogador remoto adicionado: ID %d" % pid)

func _on_player_disconnected(pid: int) -> void:
	if remote_players.has(pid):
		var rp = remote_players[pid]
		remote_players.erase(pid)
		rp.queue_free()
		print("[World] Jogador remoto removido: ID %d" % pid)

func _on_npc_state_received(npcs_dict: Dictionary) -> void:
	for nid in npcs_dict.keys():
		var data: Dictionary = npcs_dict[nid]
		if npcs.has(nid):
			var n = npcs[nid]
			if is_instance_valid(n) and n.has_method("update_network_transform"):
				n.update_network_transform(data.position, data.rotation_y, data.state)
		else:
			_spawn_npc(nid, data.position, data.rotation_y, data.state)

func _spawn_npc(nid: int, initial_pos: Vector3, initial_rot_y: float, state: int) -> void:
	var npc_inst = npc_scene.instantiate()
	var p_name := ""
	var script_path := ""
	if nid == 100 or nid == 1:
		p_name = "Garrick\n<Mestre Ferreiro> [E]"
		script_path = "scripts/npcs/garrick.lua"
	elif nid == 101 or nid == 102:
		p_name = "Boneco de Treino"
		script_path = "scripts/npcs/training_dummy.lua"
	elif nid == 103:
		p_name = "Lyra\n<Mestra Alquimista> [E]"
		script_path = "scripts/npcs/lyra.lua"
	elif nid == 104:
		p_name = "Varis\n<Mercador do Beco Sombrio> [E]"
		script_path = "scripts/npcs/shadow_merchant.lua"
	elif nid == 105:
		p_name = "Capitão Randel\n<Comandante da Guarda> [E]"
		script_path = "scripts/npcs/guard.lua"
	elif nid == 106:
		p_name = "Guarda Valen\n<Patrulheiro da Vila> [E]"
		script_path = "scripts/npcs/guard.lua"
	elif nid == 107:
		p_name = "Irmã Seraphina\n<Mestra Acólita> [E]"
		script_path = "scripts/npcs/seraphina.lua"
	elif nid == 108:
		p_name = "Mestre Aurelius\n<Arquimago> [E]"
		script_path = "scripts/npcs/aurelius.lua"
	elif nid == 109:
		p_name = "Kaelen\n<Mestre Batedor> [E]"
		script_path = "scripts/npcs/kaelen.lua"
	elif nid == 110:
		p_name = "Alquimista Esquecido\n<Espírito dos Esgotos> [E]"
		script_path = "scripts/npcs/ghost_alchemist.lua"
	else:
		p_name = "NPC #%d" % nid

	if npc_inst.has_method("set_npc_info"):
		npc_inst.set_npc_info(nid, p_name, script_path)
	elif "npc_name" in npc_inst:
		npc_inst.npc_name = p_name
		npc_inst.npc_id = nid

	if npcs_container:
		npcs_container.add_child(npc_inst)
	else:
		add_child(npc_inst)

	npc_inst.global_position = initial_pos
	npc_inst.rotation.y = initial_rot_y

	if npc_inst.has_method("update_network_transform"):
		npc_inst.update_network_transform(initial_pos, initial_rot_y, state)

	npcs[nid] = npc_inst
	print("[World] NPC instanciado na cena: %s (ID %d)" % [p_name.replace("\n", " "), nid])

func _on_npc_spoke(npc_id: int, message: String) -> void:
	if npc_id == 0:
		# Notificação de Loot / Evento Global Dourada
		show_loot_toast(message)
		return

	if npcs.has(npc_id):
		var n = npcs[npc_id]
		if is_instance_valid(n) and n.has_method("show_dialogue"):
			n.show_dialogue(message)

	if dialogue_label and dialogue_clear_timer:
		var sender_name := "NPC #%d" % npc_id
		if npc_id == 100 or npc_id == 1:
			sender_name = "Garrick"
		elif npc_id == 101 or npc_id == 102:
			sender_name = "Boneco de Treino"
		elif npc_id == 103:
			sender_name = "Lyra"
		elif npc_id == 104:
			sender_name = "Varis"
		elif npc_id == 105:
			sender_name = "Capitão Randel"
		elif npc_id == 106:
			sender_name = "Guarda Valen"
		elif npc_id == 107:
			sender_name = "Irmã Seraphina"
		elif npc_id == 108:
			sender_name = "Mestre Aurelius"
		elif npc_id == 109:
			sender_name = "Kaelen"
		elif npc_id == 110:
			sender_name = "Alquimista Esquecido"
		dialogue_label.text = "[%s]: %s" % [sender_name, message]
		dialogue_label.visible = true
		dialogue_clear_timer.start(8.0)

func _on_dialogue_clear_timeout() -> void:
	if dialogue_label:
		dialogue_label.visible = false

func _get_lighting_targets(time_val: float) -> Dictionary:
	# Parâmetros de iluminação por período:
	# Dia (06h - 16h): Luz solar clara e brilhante (energy = 1.2)
	var day_energy := 1.2
	var day_light_col := Color(1.0, 0.96, 0.88, 1.0)
	var day_ambient := Color(0.55, 0.60, 0.70, 1.0)
	var day_sky_top := Color(0.20, 0.35, 0.60, 1.0)
	var day_sky_horiz := Color(0.55, 0.65, 0.75, 1.0)

	# Entardecer (17h - 18h): Luz alaranjada de pôr do sol
	var dusk_energy := 0.7
	var dusk_light_col := Color(1.0, 0.55, 0.22, 1.0)
	var dusk_ambient := Color(0.42, 0.28, 0.24, 1.0)
	var dusk_sky_top := Color(0.22, 0.16, 0.35, 1.0)
	var dusk_sky_horiz := Color(0.90, 0.45, 0.18, 1.0)

	# Noite (18h às 05h): Ajuste conforme as 10 Fases da Lua
	var night_energy := 0.24
	var night_light_col := Color("#3b5998")
	var night_ambient := Color(0.10, 0.12, 0.18, 1.0)
	var night_sky_top := Color(0.04, 0.05, 0.10, 1.0)
	var night_sky_horiz := Color(0.08, 0.12, 0.20, 1.0)

	match current_moon_phase:
		0: # 0 (Lua Nova): Muito escuro (energy = 0.08, azul-profundo #1a243b)
			night_energy = 0.08
			night_light_col = Color("#1a243b")
			night_ambient = Color(0.03, 0.04, 0.06, 1.0)
			night_sky_top = Color(0.01, 0.02, 0.04, 1.0)
			night_sky_horiz = Color(0.04, 0.06, 0.10, 1.0)
		1, 7: # 1 e 7 (Crescente / Minguante): Luar fraco (energy = 0.16, azul-frio #2c3e66)
			night_energy = 0.16
			night_light_col = Color("#2c3e66")
			night_ambient = Color(0.06, 0.08, 0.12, 1.0)
			night_sky_top = Color(0.02, 0.03, 0.06, 1.0)
			night_sky_horiz = Color(0.06, 0.09, 0.15, 1.0)
		2, 6: # 2 e 6 (Quarto Crescente / Quarto Minguante): Luar médio (energy = 0.24, azul-prateado #3b5998)
			night_energy = 0.24
			night_light_col = Color("#3b5998")
			night_ambient = Color(0.09, 0.11, 0.16, 1.0)
			night_sky_top = Color(0.03, 0.05, 0.09, 1.0)
			night_sky_horiz = Color(0.08, 0.12, 0.20, 1.0)
		3, 5: # 3 e 5 (Gibosa Crescente / Gibosa Minguante): Luar claro (energy = 0.32, prata-azulado #5b7ec2)
			night_energy = 0.32
			night_light_col = Color("#5b7ec2")
			night_ambient = Color(0.12, 0.14, 0.22, 1.0)
			night_sky_top = Color(0.05, 0.07, 0.14, 1.0)
			night_sky_horiz = Color(0.12, 0.16, 0.26, 1.0)
		4: # 4 (Lua Cheia): Luar intenso e brilhante (energy = 0.45, prata-lunar brilhante #8ab4f8)
			night_energy = 0.45
			night_light_col = Color("#8ab4f8")
			night_ambient = Color(0.16, 0.19, 0.28, 1.0)
			night_sky_top = Color(0.07, 0.10, 0.18, 1.0)
			night_sky_horiz = Color(0.18, 0.22, 0.34, 1.0)
		8: # 8 (Lua de Sangue): Luz carmesim intensa (energy = 0.40, vermelho-sangue #e62626)
			night_energy = 0.40
			night_light_col = Color("#e62626")
			night_ambient = Color(0.25, 0.06, 0.06, 1.0)
			night_sky_top = Color(0.16, 0.02, 0.04, 1.0)
			night_sky_horiz = Color(0.65, 0.12, 0.15, 1.0)
		9: # 9 (Eclipse Total - dia e noite): Escurece o céu para roxo-abissal (energy = 0.15, cor #4a154b)
			night_energy = 0.15
			night_light_col = Color("#4a154b")
			night_ambient = Color(0.06, 0.03, 0.08, 1.0)
			night_sky_top = Color(0.02, 0.01, 0.04, 1.0)
			night_sky_horiz = Color(0.20, 0.06, 0.25, 1.0)

			day_energy = 0.15
			day_light_col = Color("#4a154b")
			day_ambient = Color(0.08, 0.04, 0.10, 1.0)
			day_sky_top = Color(0.03, 0.01, 0.05, 1.0)
			day_sky_horiz = Color(0.22, 0.08, 0.28, 1.0)

	# Modificadores de Clima no Environment:
	var target_fog_density := 0.0001
	var target_fog_color := Color("#758596")

	match current_weather_type:
		0: # Limpo
			target_fog_density = 0.0001
		1: # Chuva
			target_fog_density = 0.018
			target_fog_color = Color("#4a5868")
			day_energy *= 0.7
			day_ambient = day_ambient.lerp(Color(0.3, 0.35, 0.4, 1.0), 0.5)
		2: # Neblina Cinza-Azulada Densa
			target_fog_density = 0.055
			target_fog_color = Color("#758596")
			day_energy *= 0.6
			day_ambient = day_ambient.lerp(Color(0.4, 0.42, 0.46, 1.0), 0.7)
			day_sky_horiz = Color(0.45, 0.48, 0.52, 1.0)
		3: # Névoa Carmesim Densa
			target_fog_density = 0.05
			target_fog_color = Color("#771515")
			day_ambient = day_ambient.lerp(Color(0.5, 0.15, 0.15, 1.0), 0.6)
			day_sky_horiz = day_sky_horiz.lerp(Color(0.8, 0.18, 0.18, 1.0), 0.6)

	var res := {
		"fog_density": target_fog_density,
		"fog_color": target_fog_color
	}

	if time_val >= 6.0 and time_val < 16.5:
		# Dia
		res["energy"] = day_energy
		res["light_color"] = day_light_col
		res["ambient_color"] = day_ambient
		res["sky_top"] = day_sky_top
		res["sky_horiz"] = day_sky_horiz
		res["rot_x"] = deg_to_rad(-45.0)
		res["rot_y"] = deg_to_rad(-30.0)

	elif time_val >= 16.5 and time_val < 17.5:
		# Transição Dia -> Entardecer
		var t := (time_val - 16.5) / 1.0
		res["energy"] = lerpf(day_energy, dusk_energy, t)
		res["light_color"] = day_light_col.lerp(dusk_light_col, t)
		res["ambient_color"] = day_ambient.lerp(dusk_ambient, t)
		res["sky_top"] = day_sky_top.lerp(dusk_sky_top, t)
		res["sky_horiz"] = day_sky_horiz.lerp(dusk_sky_horiz, t)
		res["rot_x"] = lerp_angle(deg_to_rad(-45.0), deg_to_rad(-20.0), t)
		res["rot_y"] = lerp_angle(deg_to_rad(-30.0), deg_to_rad(-55.0), t)

	elif time_val >= 17.5 and time_val < 18.5:
		# Entardecer
		res["energy"] = dusk_energy
		res["light_color"] = dusk_light_col
		res["ambient_color"] = dusk_ambient
		res["sky_top"] = dusk_sky_top
		res["sky_horiz"] = dusk_sky_horiz
		res["rot_x"] = deg_to_rad(-20.0)
		res["rot_y"] = deg_to_rad(-55.0)

	elif time_val >= 18.5 and time_val < 19.5:
		# Transição Entardecer -> Noite
		var t := (time_val - 18.5) / 1.0
		res["energy"] = lerpf(dusk_energy, night_energy, t)
		res["light_color"] = dusk_light_col.lerp(night_light_col, t)
		res["ambient_color"] = dusk_ambient.lerp(night_ambient, t)
		res["sky_top"] = dusk_sky_top.lerp(night_sky_top, t)
		res["sky_horiz"] = dusk_sky_horiz.lerp(night_sky_horiz, t)
		res["rot_x"] = lerp_angle(deg_to_rad(-20.0), deg_to_rad(-55.0), t)
		res["rot_y"] = lerp_angle(deg_to_rad(-55.0), deg_to_rad(40.0), t)

	elif time_val >= 19.5 or time_val < 5.0:
		# Noite
		res["energy"] = night_energy
		res["light_color"] = night_light_col
		res["ambient_color"] = night_ambient
		res["sky_top"] = night_sky_top
		res["sky_horiz"] = night_sky_horiz
		res["rot_x"] = deg_to_rad(-55.0)
		res["rot_y"] = deg_to_rad(40.0)

	else: # 5.0 <= time_val < 6.0
		# Alvorecer (Noite -> Dia)
		var t := (time_val - 5.0) / 1.0
		res["energy"] = lerpf(night_energy, day_energy, t)
		res["light_color"] = night_light_col.lerp(day_light_col, t)
		res["ambient_color"] = night_ambient.lerp(day_ambient, t)
		res["sky_top"] = night_sky_top.lerp(day_sky_top, t)
		res["sky_horiz"] = night_sky_horiz.lerp(day_sky_horiz, t)
		res["rot_x"] = lerp_angle(deg_to_rad(-55.0), deg_to_rad(-45.0), t)
		res["rot_y"] = lerp_angle(deg_to_rad(40.0), deg_to_rad(-30.0), t)

	return res

func _update_world_environment(delta: float) -> void:
	_update_active_projectiles(delta)
	var time_f := float(current_world_hour) + float(current_world_minute) / 60.0
	var targets := _get_lighting_targets(time_f)

	if sun_light:
		sun_light.light_energy = lerpf(sun_light.light_energy, targets["energy"], 3.0 * delta)
		sun_light.light_color = sun_light.light_color.lerp(targets["light_color"], 3.0 * delta)
		sun_light.rotation.x = lerp_angle(sun_light.rotation.x, targets["rot_x"], 1.5 * delta)
		sun_light.rotation.y = lerp_angle(sun_light.rotation.y, targets["rot_y"], 1.5 * delta)

	if world_env and world_env.environment:
		world_env.environment.ambient_light_color = world_env.environment.ambient_light_color.lerp(targets["ambient_color"], 3.0 * delta)
		world_env.environment.fog_enabled = (current_weather_type > 0)
		world_env.environment.fog_density = lerpf(world_env.environment.fog_density, targets["fog_density"], 3.0 * delta)
		world_env.environment.fog_light_color = world_env.environment.fog_light_color.lerp(targets["fog_color"], 3.0 * delta)

		if world_env.environment.sky and world_env.environment.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := world_env.environment.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(targets["sky_top"], 3.0 * delta)
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(targets["sky_horiz"], 3.0 * delta)

	if rain_particles:
		var should_rain: bool = (current_weather_type == 1)
		if rain_particles.emitting != should_rain:
			rain_particles.emitting = should_rain

func _on_mob_state_received(mobs_dict: Dictionary) -> void:
	for mid in mobs_dict.keys():
		var mdata: Dictionary = mobs_dict[mid]
		if mobs.has(mid):
			var mob_node = mobs[mid]
			if is_instance_valid(mob_node):
				mob_node.update_network_data(mdata.position, mdata.rotation_y, mdata.state, mdata.hp, mdata.max_hp)
				mob_node.set_moon_phase(current_moon_phase)
		else:
			_spawn_mob(mid, mdata.type, mdata.position, mdata.rotation_y, mdata.state, mdata.hp, mdata.max_hp)

func _spawn_mob(mid: int, mtype: int, pos: Vector3, rot_y: float, state: int, hp: int, max_hp: int) -> void:
	var mob = MobEntityScript.new()
	if mobs_container:
		mobs_container.add_child(mob)
	else:
		add_child(mob)
	mob.setup(mid, mtype, pos, rot_y, hp, max_hp)

	mob.update_network_data(pos, rot_y, state, hp, max_hp)
	mob.set_moon_phase(current_moon_phase)
	mobs[mid] = mob
	print("[World] Mob instanciado no mundo: ID %d (Tipo %d) em %s" % [mid, mtype, pos])

func _on_aoe_telegraph_received(_source_id: int, pos_x: float, pos_z: float, radius: float, duration_ms: int) -> void:
	var dur_sec: float = float(duration_ms) / 1000.0
	var telegraph_root := Node3D.new()
	telegraph_root.position = Vector3(pos_x, 0.08, pos_z)
	add_child(telegraph_root)

	# Círculo base no chão (CylinderMesh achatado)
	var base_mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	base_mesh_inst.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_mesh_inst.material_override = mat
	telegraph_root.add_child(base_mesh_inst)

	# Anel/Preenchimento visual progressivo do perigo
	var fill_mesh_inst := MeshInstance3D.new()
	var fill_cyl := CylinderMesh.new()
	fill_cyl.top_radius = radius
	fill_cyl.bottom_radius = radius
	fill_cyl.height = 0.06
	fill_mesh_inst.mesh = fill_cyl

	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(1.0, 0.25, 0.1, 0.65)
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mesh_inst.material_override = fill_mat
	fill_mesh_inst.scale = Vector3(0.05, 1.0, 0.05)
	telegraph_root.add_child(fill_mesh_inst)

	# Tween preenchendo o círculo durante a duração telegrafada
	var tw := create_tween()
	tw.tween_property(fill_mesh_inst, "scale:x", 1.0, dur_sec)
	tw.parallel().tween_property(fill_mesh_inst, "scale:z", 1.0, dur_sec)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.75, dur_sec)

	# Flash de impacto e destruição ao término
	tw.chain().tween_callback(func():
		var impact_mesh := MeshInstance3D.new()
		var imp_cyl := CylinderMesh.new()
		imp_cyl.top_radius = radius * 1.08
		imp_cyl.bottom_radius = radius * 1.08
		imp_cyl.height = 0.25
		impact_mesh.mesh = imp_cyl

		var imp_mat := StandardMaterial3D.new()
		imp_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.95)
		imp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		imp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		impact_mesh.material_override = imp_mat
		telegraph_root.add_child(impact_mesh)

		var flash_tw := create_tween()
		flash_tw.tween_property(imp_mat, "albedo_color:a", 0.0, 0.25)
		flash_tw.parallel().tween_property(impact_mesh, "scale", Vector3(1.2, 2.0, 1.2), 0.25)
		flash_tw.chain().tween_callback(telegraph_root.queue_free)
	)

func _spawn_player_floating_damage(target_node: Node3D, damage: int) -> void:
	if not is_instance_valid(target_node):
		return

	var dmg_label := Label3D.new()
	add_child(dmg_label)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.outline_size = 8
	dmg_label.outline_modulate = Color(0, 0, 0, 1)
	dmg_label.no_depth_test = true
	dmg_label.font_size = 40
	dmg_label.modulate = Color(1.0, 0.15, 0.15, 1.0) # Vermelho Vivo
	dmg_label.text = "-%d" % damage
	dmg_label.global_position = target_node.global_position + Vector3(randf_range(-0.3, 0.3), 2.2 + randf_range(0.0, 0.2), randf_range(-0.3, 0.3))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dmg_label, "position:y", dmg_label.position.y + 1.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dmg_label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dmg_label.queue_free)

func _create_zone_landmarks() -> void:
	zone_marker_nodes.clear()

	# 1. Bosque Sussurrante (55, 2, -45)
	var bosque_marker := Node3D.new()
	bosque_marker.position = Vector3(55.0, 0.0, -45.0)
	add_child(bosque_marker)
	zone_marker_nodes.append(bosque_marker)

	var b_pilar := MeshInstance3D.new()
	var bp_mesh := BoxMesh.new()
	bp_mesh.size = Vector3(1.0, 2.4, 1.0)
	b_pilar.mesh = bp_mesh
	var bp_mat := StandardMaterial3D.new()
	bp_mat.albedo_color = Color(0.2, 0.38, 0.22, 1.0)
	bp_mat.roughness = 0.85
	b_pilar.material_override = bp_mat
	b_pilar.position = Vector3(0, 1.2, 0)
	bosque_marker.add_child(b_pilar)

	var b_lbl := Label3D.new()
	b_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b_lbl.outline_size = 8
	b_lbl.outline_modulate = Color(0, 0, 0, 1)
	b_lbl.font_size = 24
	b_lbl.modulate = Color(0.65, 0.95, 0.7, 1.0)
	b_lbl.text = "🌲 Bosque Sussurrante\n[Área de Caça: Lobos da Bruma, Lobo Alfa & Licantropo Alfa]"
	b_lbl.position = Vector3(0, 2.0, 0)
	bosque_marker.add_child(b_lbl)

	# 2. Ruínas da Vigília (0, 2, 70)
	var ruinas_marker := Node3D.new()
	ruinas_marker.position = Vector3(0.0, 0.0, 70.0)
	add_child(ruinas_marker)
	zone_marker_nodes.append(ruinas_marker)

	var r_pilar := MeshInstance3D.new()
	var rp_mesh := BoxMesh.new()
	rp_mesh.size = Vector3(1.2, 2.6, 1.2)
	r_pilar.mesh = rp_mesh
	var rp_mat := StandardMaterial3D.new()
	rp_mat.albedo_color = Color(0.35, 0.28, 0.24, 1.0)
	rp_mat.roughness = 0.9
	r_pilar.material_override = rp_mat
	r_pilar.position = Vector3(0, 1.3, 0)
	ruinas_marker.add_child(r_pilar)

	var r_lbl := Label3D.new()
	r_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	r_lbl.outline_size = 8
	r_lbl.outline_modulate = Color(0, 0, 0, 1)
	r_lbl.font_size = 24
	r_lbl.modulate = Color(1.0, 0.75, 0.45, 1.0)
	r_lbl.text = "🏰 Ruínas da Vigília\n[Saqueadores, Besteiros, Acólitos, Executor & Comandante Vaelen]"
	r_lbl.position = Vector3(0, 2.0, 0)
	ruinas_marker.add_child(r_lbl)

	# 3. Santuário do Eclipse (-85, 2, 85)
	var sanctuary_root := Node3D.new()
	sanctuary_root.position = Vector3(-85.0, 0.0, 85.0)
	add_child(sanctuary_root)
	zone_marker_nodes.append(sanctuary_root)

	var s_lbl := Label3D.new()
	s_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s_lbl.outline_size = 9
	s_lbl.outline_modulate = Color(0, 0, 0, 1)
	s_lbl.font_size = 26
	s_lbl.modulate = Color(0.9, 0.45, 1.0, 1.0)
	s_lbl.text = "🌑 Santuário do Eclipse (Arena de Raid)\n[Cultistas, Gárgula, Inquisidor Vex & Raid Boss Malakor]"
	s_lbl.position = Vector3(0.0, 2.0, 0.0)
	sanctuary_root.add_child(s_lbl)

func _on_projectile_spawned(proj_id: int, owner_id: int, proj_type: int, start_pos: Vector3, dir_xz: Vector2, speed: float, max_range: float) -> void:
	if not projectiles_container:
		return
	if active_projectiles.has(proj_id) and is_instance_valid(active_projectiles[proj_id]["node"]):
		return

	var p_node := Node3D.new()
	p_node.name = "Proj_%d" % proj_id
	p_node.position = start_pos
	projectiles_container.add_child(p_node)

	var dir := Vector3(dir_xz.x, 0.0, dir_xz.y).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD

	p_node.look_at(start_pos + dir, Vector3.UP)

	match proj_type:
		1: # Flecha Física (Batedor - Ataque Básico)
			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.02
			shaft_mesh.bottom_radius = 0.02
			shaft_mesh.height = 0.85
			shaft.mesh = shaft_mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#8d6e63")
			mat.emission_enabled = true
			mat.emission = Color("#cddc39")
			mat.emission_energy_multiplier = 1.2
			shaft.material_override = mat
			shaft.rotation.x = deg_to_rad(90.0)
			p_node.add_child(shaft)

			var tip := MeshInstance3D.new()
			var tip_cone := CylinderMesh.new()
			tip_cone.top_radius = 0.0
			tip_cone.bottom_radius = 0.035
			tip_cone.height = 0.12
			tip.mesh = tip_cone
			var tip_mat := StandardMaterial3D.new()
			tip_mat.albedo_color = Color("#cfd8dc")
			tip_mat.metallic = 0.9
			tip.material_override = tip_mat
			tip.rotation.x = deg_to_rad(90.0)
			tip.position = Vector3(0, 0, -0.45)
			p_node.add_child(tip)

		2: # Flecha Perfurante (Batedor - Skill Q)
			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.04
			shaft_mesh.bottom_radius = 0.04
			shaft_mesh.height = 1.3
			shaft.mesh = shaft_mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#76ff03")
			mat.emission_enabled = true
			mat.emission = Color("#76ff03")
			mat.emission_energy_multiplier = 4.0
			shaft.material_override = mat
			shaft.rotation.x = deg_to_rad(90.0)
			p_node.add_child(shaft)

			var light := OmniLight3D.new()
			light.light_color = Color("#76ff03")
			light.light_energy = 2.5
			light.omni_range = 3.5
			p_node.add_child(light)

		3: # Orbe Arcano (Iniciado - Ataque Básico)
			var orb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.44
			orb.mesh = sphere
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#00e5ff")
			mat.emission_enabled = true
			mat.emission = Color("#00e5ff")
			mat.emission_energy_multiplier = 3.5
			orb.material_override = mat
			p_node.add_child(orb)

			var core := MeshInstance3D.new()
			var core_sphere := SphereMesh.new()
			core_sphere.radius = 0.11
			core_sphere.height = 0.22
			core.mesh = core_sphere
			var core_mat := StandardMaterial3D.new()
			core_mat.albedo_color = Color(1, 1, 1)
			core_mat.emission_enabled = true
			core_mat.emission = Color(1, 1, 1)
			core_mat.emission_energy_multiplier = 5.0
			core.material_override = core_mat
			p_node.add_child(core)

			var light := OmniLight3D.new()
			light.light_color = Color("#00e5ff")
			light.light_energy = 2.0
			light.omni_range = 3.0
			p_node.add_child(light)

		4: # Cometa Elemental (Iniciado - Skill Q)
			var orb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.42
			sphere.height = 0.84
			orb.mesh = sphere
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#ff3d00")
			mat.emission_enabled = true
			mat.emission = Color("#ff5722")
			mat.emission_energy_multiplier = 4.5
			orb.material_override = mat
			p_node.add_child(orb)

			var core := MeshInstance3D.new()
			var core_sphere := SphereMesh.new()
			core_sphere.radius = 0.22
			core_sphere.height = 0.44
			core.mesh = core_sphere
			var core_mat := StandardMaterial3D.new()
			core_mat.albedo_color = Color("#d500f9")
			core_mat.emission_enabled = true
			core_mat.emission = Color("#d500f9")
			core_mat.emission_energy_multiplier = 4.0
			core.material_override = core_mat
			p_node.add_child(core)

			var light := OmniLight3D.new()
			light.light_color = Color("#ff6e40")
			light.light_energy = 4.0
			light.omni_range = 5.0
			p_node.add_child(light)

		5: # Lança Sagrada (Acólito - Skill Q)
			var spear := MeshInstance3D.new()
			var spear_mesh := CylinderMesh.new()
			spear_mesh.top_radius = 0.035
			spear_mesh.bottom_radius = 0.035
			spear_mesh.height = 1.6
			spear.mesh = spear_mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#ffd700")
			mat.emission_enabled = true
			mat.emission = Color("#ffeb3b")
			mat.emission_energy_multiplier = 4.5
			spear.material_override = mat
			spear.rotation.x = deg_to_rad(90.0)
			p_node.add_child(spear)

			var tip := MeshInstance3D.new()
			var tip_cone := CylinderMesh.new()
			tip_cone.top_radius = 0.0
			tip_cone.bottom_radius = 0.07
			tip_cone.height = 0.3
			tip.mesh = tip_cone
			tip.material_override = mat
			tip.rotation.x = deg_to_rad(90.0)
			tip.position = Vector3(0, 0, -0.9)
			p_node.add_child(tip)

			var light := OmniLight3D.new()
			light.light_color = Color("#fff59d")
			light.light_energy = 3.5
			light.omni_range = 4.5
			p_node.add_child(light)

		6: # Frasco Químico (Alquimista - Skill Q)
			var flask := MeshInstance3D.new()
			var flask_sphere := SphereMesh.new()
			flask_sphere.radius = 0.22
			flask_sphere.height = 0.44
			flask.mesh = flask_sphere
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#00e676")
			mat.emission_enabled = true
			mat.emission = Color("#00e676")
			mat.emission_energy_multiplier = 3.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.88
			flask.material_override = mat
			p_node.add_child(flask)

			var core := MeshInstance3D.new()
			var core_sphere := SphereMesh.new()
			core_sphere.radius = 0.12
			core_sphere.height = 0.24
			core.mesh = core_sphere
			var core_mat := StandardMaterial3D.new()
			core_mat.albedo_color = Color("#ab47bc")
			core_mat.emission_enabled = true
			core_mat.emission = Color("#e040fb")
			core_mat.emission_energy_multiplier = 3.0
			core.material_override = core_mat
			p_node.add_child(core)

			var light := OmniLight3D.new()
			light.light_color = Color("#00e676")
			light.light_energy = 3.5
			light.omni_range = 4.5
			p_node.add_child(light)

		7: # Lança de Fêmur (Necromante de Ossos - Skill Q): Projétil alongado branco-ósseo com rastro verde-fantasma
			var bone_spear := MeshInstance3D.new()
			var bone_mesh := CylinderMesh.new()
			bone_mesh.top_radius = 0.035
			bone_mesh.bottom_radius = 0.045
			bone_mesh.height = 1.6
			bone_spear.mesh = bone_mesh
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = Color("#f5f5dc")
			b_mat.roughness = 0.6
			bone_spear.material_override = b_mat
			bone_spear.rotation.x = deg_to_rad(90.0)
			p_node.add_child(bone_spear)

			var b_tip := MeshInstance3D.new()
			var b_cone := CylinderMesh.new()
			b_cone.top_radius = 0.0
			b_cone.bottom_radius = 0.075
			b_cone.height = 0.38
			b_tip.mesh = b_cone
			b_tip.material_override = b_mat
			b_tip.rotation.x = deg_to_rad(90.0)
			b_tip.position = Vector3(0, 0, -0.95)
			p_node.add_child(b_tip)

			# Rastro verde fantasmagórico
			var ghost_mat := StandardMaterial3D.new()
			ghost_mat.albedo_color = Color("#00e676")
			ghost_mat.emission_enabled = true
			ghost_mat.emission = Color("#76ff03")
			ghost_mat.emission_energy_multiplier = 4.5
			ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost_mat.albedo_color.a = 0.65

			for i in range(4):
				var trail_ring := MeshInstance3D.new()
				var trail_mesh := TorusMesh.new()
				trail_mesh.inner_radius = 0.03 + i * 0.015
				trail_mesh.outer_radius = 0.07 + i * 0.03
				trail_ring.mesh = trail_mesh
				trail_ring.material_override = ghost_mat
				trail_ring.position = Vector3(0, 0, 0.4 + i * 0.28)
				p_node.add_child(trail_ring)

			var b_light := OmniLight3D.new()
			b_light.light_color = Color("#76ff03")
			b_light.light_energy = 3.8
			b_light.omni_range = 4.8
			p_node.add_child(b_light)

		8: # Lança do Trovão (Arauto da Tempestade - Skill Q): Feixe elétrico ultrarrápido azul-claro
			var bolt := MeshInstance3D.new()
			var bolt_mesh := CylinderMesh.new()
			bolt_mesh.top_radius = 0.025
			bolt_mesh.bottom_radius = 0.025
			bolt_mesh.height = 2.2
			bolt.mesh = bolt_mesh
			var core_mat := StandardMaterial3D.new()
			core_mat.albedo_color = Color(1.0, 1.0, 1.0)
			core_mat.emission_enabled = true
			core_mat.emission = Color("#e1f5fe")
			core_mat.emission_energy_multiplier = 6.0
			bolt.material_override = core_mat
			bolt.rotation.x = deg_to_rad(90.0)
			p_node.add_child(bolt)

			var aura := MeshInstance3D.new()
			var aura_mesh := CylinderMesh.new()
			aura_mesh.top_radius = 0.06
			aura_mesh.bottom_radius = 0.06
			aura_mesh.height = 2.4
			aura.mesh = aura_mesh
			var aura_mat := StandardMaterial3D.new()
			aura_mat.albedo_color = Color("#00e5ff")
			aura_mat.emission_enabled = true
			aura_mat.emission = Color("#00b0ff")
			aura_mat.emission_energy_multiplier = 5.0
			aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			aura_mat.albedo_color.a = 0.75
			aura.material_override = aura_mat
			aura.rotation.x = deg_to_rad(90.0)
			p_node.add_child(aura)

			for rot_deg in [0.0, 60.0, 120.0]:
				var spark := MeshInstance3D.new()
				var spark_box := BoxMesh.new()
				spark_box.size = Vector3(0.14, 1.6, 0.015)
				spark.mesh = spark_box
				spark.material_override = aura_mat
				spark.rotation.z = deg_to_rad(rot_deg)
				spark.rotation.x = deg_to_rad(90.0)
				p_node.add_child(spark)

			var bolt_light := OmniLight3D.new()
			bolt_light.light_color = Color("#00e5ff")
			bolt_light.light_energy = 5.5
			bolt_light.omni_range = 6.0
			p_node.add_child(bolt_light)

	active_projectiles[proj_id] = {
		"node": p_node,
		"dir": dir,
		"speed": speed,
		"max_range": max_range,
		"traveled": 0.0,
		"proj_type": proj_type
	}

func _update_active_projectiles(delta: float) -> void:
	var to_remove: Array = []
	for pid in active_projectiles.keys():
		var p_data: Dictionary = active_projectiles[pid]
		var node: Node3D = p_data["node"]
		if not is_instance_valid(node):
			to_remove.append(pid)
			continue

		var step: float = p_data["speed"] * delta
		node.global_position += p_data["dir"] * step
		p_data["traveled"] += step

		if p_data["traveled"] >= p_data["max_range"]:
			if p_data["proj_type"] == 4:
				_spawn_comet_explosion(node.global_position)
			elif p_data["proj_type"] == 6:
				_spawn_acid_puddle(node.global_position)
			elif p_data["proj_type"] == 7:
				_spawn_bone_impact(node.global_position)
			elif p_data["proj_type"] == 8:
				_spawn_lightning_impact(node.global_position)
			node.queue_free()
			to_remove.append(pid)

	for pid in to_remove:
		active_projectiles.erase(pid)

func _check_projectile_impact(target_pos: Vector3) -> void:
	var to_remove: Array = []
	for pid in active_projectiles.keys():
		var p_data: Dictionary = active_projectiles[pid]
		if p_data["proj_type"] == 2: # Flecha Perfurante atravessa alvos sem ser destruída
			continue
		var node: Node3D = p_data["node"]
		if is_instance_valid(node) and node.global_position.distance_to(target_pos) <= 2.5:
			if p_data["proj_type"] == 4:
				_spawn_comet_explosion(node.global_position)
			elif p_data["proj_type"] == 6:
				_spawn_acid_puddle(node.global_position)
			elif p_data["proj_type"] == 7:
				_spawn_bone_impact(node.global_position)
			elif p_data["proj_type"] == 8:
				_spawn_lightning_impact(node.global_position)
			node.queue_free()
			to_remove.append(pid)
			break

	for pid in to_remove:
		active_projectiles.erase(pid)

func _spawn_comet_explosion(pos: Vector3) -> void:
	var shockwave := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	shockwave.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color("#ff3d00")
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = mat
	shockwave.position = pos
	add_child(shockwave)

	var light := OmniLight3D.new()
	light.light_color = Color("#ff6e40")
	light.light_energy = 5.0
	light.omni_range = 6.0
	shockwave.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(shockwave, "scale", Vector3(9.3, 9.3, 9.3), 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.chain().tween_callback(shockwave.queue_free)

func _spawn_acid_puddle(pos: Vector3) -> void:
	var puddle_root := Node3D.new()
	puddle_root.position = Vector3(pos.x, 0.05, pos.z)
	add_child(puddle_root)

	var puddle_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.4
	cyl.height = 0.04
	puddle_mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.9, 0.45, 0.75)
	mat.emission_enabled = true
	mat.emission = Color("#00e676")
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle_mesh.material_override = mat
	puddle_root.add_child(puddle_mesh)

	var light := OmniLight3D.new()
	light.light_color = Color("#00e676")
	light.light_energy = 3.5
	light.omni_range = 5.5
	puddle_root.add_child(light)

	var tw := create_tween().set_parallel(true)
	puddle_mesh.scale = Vector3(0.2, 1.0, 0.2)
	tw.tween_property(puddle_mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.7)
	tw.chain().tween_callback(puddle_root.queue_free)

func _spawn_bone_impact(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	flash.mesh = sphere
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color("#00e676")
	f_mat.emission_enabled = true
	f_mat.emission = Color("#76ff03")
	f_mat.emission_energy_multiplier = 4.5
	f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = f_mat
	root.add_child(flash)

	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color("#ecebe4")
	bone_mat.roughness = 0.5
	var shards: Array[MeshInstance3D] = []
	for i in range(5):
		var shard := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(0.06, 0.18, 0.05)
		shard.mesh = s_box
		shard.material_override = bone_mat
		shard.rotation = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
		root.add_child(shard)
		shards.append(shard)

	var light := OmniLight3D.new()
	light.light_color = Color("#76ff03")
	light.light_energy = 5.0
	light.omni_range = 5.5
	root.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(5.0, 5.0, 5.0), 0.32)
	tw.tween_property(f_mat, "albedo_color:a", 0.0, 0.32)
	tw.tween_property(light, "light_energy", 0.0, 0.32)
	for i in range(shards.size()):
		var angle: float = i * (PI * 2.0 / shards.size())
		var target_offset := Vector3(cos(angle) * 1.8, randf_range(0.2, 1.2), sin(angle) * 1.8)
		tw.tween_property(shards[i], "position", target_offset, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(root.queue_free)

func _spawn_lightning_impact(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var bolt := MeshInstance3D.new()
	var bolt_cyl := CylinderMesh.new()
	bolt_cyl.top_radius = 0.14
	bolt_cyl.bottom_radius = 0.18
	bolt_cyl.height = 14.0
	bolt.mesh = bolt_cyl
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(1.0, 1.0, 1.0)
	b_mat.emission_enabled = true
	b_mat.emission = Color("#00e5ff")
	b_mat.emission_energy_multiplier = 7.0
	bolt.material_override = b_mat
	bolt.position = Vector3(0, 7.0, 0)
	root.add_child(bolt)

	var shockwave := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4
	ring.outer_radius = 0.85
	shockwave.mesh = ring
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color("#00b0ff")
	s_mat.emission_enabled = true
	s_mat.emission = Color("#00e5ff")
	s_mat.emission_energy_multiplier = 5.5
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = s_mat
	shockwave.position = Vector3(0, 0.1, 0)
	root.add_child(shockwave)

	var light := OmniLight3D.new()
	light.light_color = Color("#e1f5fe")
	light.light_energy = 8.5
	light.omni_range = 7.5
	light.position = Vector3(0, 1.5, 0)
	root.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(bolt, "scale:x", 0.05, 0.22)
	tw.tween_property(bolt, "scale:z", 0.05, 0.22)
	tw.tween_property(shockwave, "scale", Vector3(6.5, 1.0, 6.5), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s_mat, "albedo_color:a", 0.0, 0.28)
	tw.tween_property(light, "light_energy", 0.0, 0.28)
	tw.chain().tween_callback(root.queue_free)

func _create_rebirth_crystal() -> void:
	var crystal_root := Node3D.new()
	crystal_root.name = "RebirthCrystalAltar"
	crystal_root.position = Vector3(0.0, 0.0, 0.0)
	add_child(crystal_root)

	# Pedestal de Pedra / Obsidiana
	var base_pedestal := MeshInstance3D.new()
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 1.9
	base_cyl.bottom_radius = 2.2
	base_cyl.height = 0.4
	base_pedestal.mesh = base_cyl
	var dark_stone := StandardMaterial3D.new()
	dark_stone.albedo_color = Color("#1a1e24")
	dark_stone.roughness = 0.5
	dark_stone.metallic = 0.4
	base_pedestal.material_override = dark_stone
	base_pedestal.position = Vector3(0, 0.2, 0)
	crystal_root.add_child(base_pedestal)

	# Pilar central do cristal
	var pillar := MeshInstance3D.new()
	var pillar_cyl := CylinderMesh.new()
	pillar_cyl.top_radius = 0.55
	pillar_cyl.bottom_radius = 0.8
	pillar_cyl.height = 0.9
	pillar.mesh = pillar_cyl
	pillar.material_override = dark_stone
	pillar.position = Vector3(0, 0.75, 0)
	crystal_root.add_child(pillar)

	# Cristal Azul-Celeste Flutuante e Iluminado
	var crystal := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 0.48
	prism.height = 1.1
	crystal.mesh = prism
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color("#00e5ff")
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color("#00e5ff")
	crystal_mat.emission_energy_multiplier = 4.5
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_mat.albedo_color.a = 0.85
	crystal.material_override = crystal_mat
	crystal.position = Vector3(0, 1.85, 0)
	crystal_root.add_child(crystal)

	# Luz do Cristal
	var light := OmniLight3D.new()
	light.light_color = Color("#00e5ff")
	light.light_energy = 4.5
	light.omni_range = 9.5
	crystal.add_child(light)

	# Animação flutuante do Cristal
	var tw := create_tween().set_loops()
	tw.tween_property(crystal, "position:y", 2.15, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(crystal, "position:y", 1.65, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Label 3D do Altar
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0, 0, 0, 1)
	lbl.font_size = 28
	lbl.modulate = Color("#00e5ff")
	lbl.text = "Cristal de Renascimento (Zona Segura)"
	lbl.position = Vector3(0, 2.9, 0)
	crystal_root.add_child(lbl)

func _create_perimeter_walls() -> void:
	var walls_node := Node3D.new()
	walls_node.name = "PerimeterWalls"
	add_child(walls_node)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.16, 0.18, 0.21, 1.0) # Rocha escura
	stone_mat.roughness = 0.9
	stone_mat.metallic = 0.15

	var wall_height: float = 6.0
	var wall_thick: float = 3.0
	var map_limit: float = 122.0

	# 1. Muralha Norte (Z = -122)
	var north_wall := StaticBody3D.new()
	north_wall.name = "NorthWall"
	north_wall.position = Vector3(0.0, wall_height / 2.0, -map_limit)
	walls_node.add_child(north_wall)

	var n_col := CollisionShape3D.new()
	var n_box := BoxShape3D.new()
	n_box.size = Vector3(250.0, wall_height, wall_thick)
	n_col.shape = n_box
	north_wall.add_child(n_col)

	var n_mesh := MeshInstance3D.new()
	var n_bmesh := BoxMesh.new()
	n_bmesh.size = Vector3(250.0, wall_height, wall_thick)
	n_mesh.mesh = n_bmesh
	n_mesh.material_override = stone_mat
	north_wall.add_child(n_mesh)

	# 2. Muralha Sul (Z = +122)
	var south_wall := StaticBody3D.new()
	south_wall.name = "SouthWall"
	south_wall.position = Vector3(0.0, wall_height / 2.0, map_limit)
	walls_node.add_child(south_wall)

	var s_col := CollisionShape3D.new()
	var s_box := BoxShape3D.new()
	s_box.size = Vector3(250.0, wall_height, wall_thick)
	s_col.shape = s_box
	south_wall.add_child(s_col)

	var s_mesh := MeshInstance3D.new()
	var s_bmesh := BoxMesh.new()
	s_bmesh.size = Vector3(250.0, wall_height, wall_thick)
	s_mesh.mesh = s_bmesh
	s_mesh.material_override = stone_mat
	south_wall.add_child(s_mesh)

	# 3. Muralha Oeste (X = -122)
	var west_wall := StaticBody3D.new()
	west_wall.name = "WestWall"
	west_wall.position = Vector3(-map_limit, wall_height / 2.0, 0.0)
	walls_node.add_child(west_wall)

	var w_col := CollisionShape3D.new()
	var w_box := BoxShape3D.new()
	w_box.size = Vector3(wall_thick, wall_height, 250.0)
	w_col.shape = w_box
	west_wall.add_child(w_col)

	var w_mesh := MeshInstance3D.new()
	var w_bmesh := BoxMesh.new()
	w_bmesh.size = Vector3(wall_thick, wall_height, 250.0)
	w_mesh.mesh = w_bmesh
	w_mesh.material_override = stone_mat
	west_wall.add_child(w_mesh)

	# 4. Muralha Leste (X = +122) dividida em 2 seções com Fenda do Abismo no centro (Z = 0)
	# Seção Norte do Leste: de Z = -122 a Z = -5 (comprimento 117m, centro Z = -63.5)
	var east_n := StaticBody3D.new()
	east_n.name = "EastWall_North"
	east_n.position = Vector3(map_limit, wall_height / 2.0, -63.5)
	walls_node.add_child(east_n)

	var en_col := CollisionShape3D.new()
	var en_box := BoxShape3D.new()
	en_box.size = Vector3(wall_thick, wall_height, 117.0)
	en_col.shape = en_box
	east_n.add_child(en_col)

	var en_mesh := MeshInstance3D.new()
	var en_bmesh := BoxMesh.new()
	en_bmesh.size = Vector3(wall_thick, wall_height, 117.0)
	en_mesh.mesh = en_bmesh
	en_mesh.material_override = stone_mat
	east_n.add_child(en_mesh)

	# Seção Sul do Leste: de Z = +5 a Z = +122 (comprimento 117m, centro Z = +63.5)
	var east_s := StaticBody3D.new()
	east_s.name = "EastWall_South"
	east_s.position = Vector3(map_limit, wall_height / 2.0, 63.5)
	walls_node.add_child(east_s)

	var es_col := CollisionShape3D.new()
	var es_box := BoxShape3D.new()
	es_box.size = Vector3(wall_thick, wall_height, 117.0)
	es_col.shape = es_box
	east_s.add_child(es_col)

	var es_mesh := MeshInstance3D.new()
	var es_bmesh := BoxMesh.new()
	es_bmesh.size = Vector3(wall_thick, wall_height, 117.0)
	es_mesh.mesh = es_bmesh
	es_mesh.material_override = stone_mat
	east_s.add_child(es_mesh)

	# Marcadores e Placa da Fenda do Void (Z = 0 em X = 122)
	var gap_marker := Node3D.new()
	gap_marker.position = Vector3(map_limit, 0.0, 0.0)
	walls_node.add_child(gap_marker)

	for z_off in [-5.0, 5.0]:
		var obelisk := MeshInstance3D.new()
		var ob_box := BoxMesh.new()
		ob_box.size = Vector3(1.2, 4.0, 1.2)
		obelisk.mesh = ob_box
		obelisk.material_override = stone_mat
		obelisk.position = Vector3(0.0, 2.0, z_off)
		gap_marker.add_child(obelisk)

		var fire := OmniLight3D.new()
		fire.light_color = Color(1.0, 0.35, 0.1)
		fire.light_energy = 3.5
		fire.omni_range = 7.0
		fire.position = Vector3(-0.6, 3.8, z_off)
		gap_marker.add_child(fire)

	var gap_lbl := Label3D.new()
	gap_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gap_lbl.outline_size = 8
	gap_lbl.outline_modulate = Color(0, 0, 0, 1)
	gap_lbl.font_size = 26
	gap_lbl.modulate = Color(1.0, 0.75, 0.2)
	gap_lbl.text = "⚠️ FENDA DO ABISMO / VOID ⚠️\n[Salto de Teste: Queda no Abismo & Respawn no Centro]"
	gap_lbl.position = Vector3(-1.5, 3.2, 0.0)
	gap_marker.add_child(gap_lbl)


func _setup_xp_hud() -> void:
	var hud_node: CanvasLayer = get_node_or_null("HUD")
	if not hud_node:
		return

	var xp_panel := PanelContainer.new()
	xp_panel.name = "XPHUDPanel"
	xp_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	xp_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	xp_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	xp_panel.offset_left = -330.0
	xp_panel.offset_top = -140.0
	xp_panel.offset_right = 330.0
	xp_panel.offset_bottom = -112.0

	var xp_panel_style := StyleBoxFlat.new()
	xp_panel_style.bg_color = Color(0.05, 0.07, 0.11, 0.9)
	xp_panel_style.border_color = Color(0.7, 0.55, 0.2, 0.5)
	xp_panel_style.set_border_width_all(1)
	xp_panel_style.set_corner_radius_all(6)
	xp_panel_style.content_margin_left = 6
	xp_panel_style.content_margin_right = 6
	xp_panel_style.content_margin_top = 2
	xp_panel_style.content_margin_bottom = 2
	xp_panel.add_theme_stylebox_override("panel", xp_panel_style)
	hud_node.add_child(xp_panel)

	var xp_vbox := VBoxContainer.new()
	xp_vbox.add_theme_constant_override("separation", 2)
	xp_panel.add_child(xp_vbox)

	var xp_bar_fill := StyleBoxFlat.new()
	xp_bar_fill.bg_color = Color(0.85, 0.68, 0.18, 1.0)
	xp_bar_fill.set_corner_radius_all(4)

	var xp_bar_bg := StyleBoxFlat.new()
	xp_bar_bg.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	xp_bar_bg.set_corner_radius_all(4)

	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 10)
	xp_bar.add_theme_stylebox_override("background", xp_bar_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_bar_fill)
	xp_bar.show_percentage = false
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_vbox.add_child(xp_bar)

	var xp_info_hbox := HBoxContainer.new()
	xp_vbox.add_child(xp_info_hbox)

	xp_label = Label.new()
	xp_label.text = "XP: 0 / 100 (Nível 1)"
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_label.add_theme_font_size_override("font_size", 11)
	xp_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	xp_info_hbox.add_child(xp_label)

	stat_alert_label = Label.new()
	stat_alert_label.text = ""
	stat_alert_label.add_theme_font_size_override("font_size", 11)
	stat_alert_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	xp_info_hbox.add_child(stat_alert_label)

	var tw := create_tween().set_loops()
	tw.tween_property(stat_alert_label, "modulate:a", 0.3, 0.65).set_trans(Tween.TRANS_SINE)
	tw.tween_property(stat_alert_label, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE)

func _setup_loot_toast() -> void:
	var hud_node: CanvasLayer = get_node_or_null("HUD")
	if not hud_node:
		return

	loot_toast_panel = PanelContainer.new()
	loot_toast_panel.name = "LootToastPanel"
	loot_toast_panel.visible = false
	loot_toast_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	loot_toast_panel.offset_left = -460.0
	loot_toast_panel.offset_top = 70.0
	loot_toast_panel.offset_right = -20.0
	loot_toast_panel.offset_bottom = 145.0

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.07, 0.09, 0.14, 0.95)
	toast_style.border_color = Color(1.0, 0.82, 0.25, 0.9)
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(8)
	toast_style.shadow_color = Color(0, 0, 0, 0.6)
	toast_style.shadow_size = 10
	toast_style.content_margin_left = 14
	toast_style.content_margin_right = 14
	toast_style.content_margin_top = 10
	toast_style.content_margin_bottom = 10
	loot_toast_panel.add_theme_stylebox_override("panel", toast_style)
	hud_node.add_child(loot_toast_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	loot_toast_panel.add_child(vbox)

	var header_lbl := Label.new()
	header_lbl.text = "✦ NOTIFICAÇÃO DE LOOT / EVENTO GLOBAL ✦"
	header_lbl.add_theme_font_size_override("font_size", 12)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	vbox.add_child(header_lbl)

	loot_toast_label = Label.new()
	loot_toast_label.text = ""
	loot_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loot_toast_label.add_theme_font_size_override("font_size", 13)
	loot_toast_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	vbox.add_child(loot_toast_label)

	loot_toast_timer = Timer.new()
	loot_toast_timer.one_shot = true
	loot_toast_timer.timeout.connect(func():
		var tw := create_tween()
		tw.tween_property(loot_toast_panel, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(func(): loot_toast_panel.visible = false)
	)
	add_child(loot_toast_timer)

func show_loot_toast(msg: String) -> void:
	if not loot_toast_panel or not loot_toast_label:
		return
	loot_toast_label.text = msg
	loot_toast_panel.modulate.a = 1.0
	loot_toast_panel.visible = true
	if loot_toast_timer:
		loot_toast_timer.start(6.5)

# ==============================================================================
# CONSTRUÇÃO PROCEDURAL DA VILA DO REFÚGIO SIMÉTRICA (COM COLISÃO FÍSICA REAL)
# ==============================================================================

var burn_overlay: ColorRect = null

func _setup_burn_overlay() -> void:
	if has_node("HUD/BurnOverlay"):
		burn_overlay = get_node("HUD/BurnOverlay")
		return
	var hud := get_node_or_null("HUD")
	if not hud:
		return
	burn_overlay = ColorRect.new()
	burn_overlay.name = "BurnOverlay"
	burn_overlay.anchor_right = 1.0
	burn_overlay.anchor_bottom = 1.0
	burn_overlay.color = Color(1.0, 0.1, 0.0, 0.0)
	burn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(burn_overlay)

func _flash_screen_red() -> void:
	if not burn_overlay:
		_setup_burn_overlay()
	if not burn_overlay:
		return
	var tw := create_tween()
	tw.tween_property(burn_overlay, "color:a", 0.45, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(burn_overlay, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _flash_character_red(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var mesh_inst: MeshInstance3D = null
	if node.has_node("BodyMesh"):
		mesh_inst = node.get_node("BodyMesh")
	elif node.has_node("MeshInstance3D"):
		mesh_inst = node.get_node("MeshInstance3D")
	if mesh_inst:
		var orig_mat = mesh_inst.material_override
		var red_mat := StandardMaterial3D.new()
		red_mat.albedo_color = Color(1.0, 0.2, 0.1, 1.0)
		red_mat.emission_enabled = true
		red_mat.emission = Color(1.0, 0.25, 0.05, 1.0)
		red_mat.emission_energy_multiplier = 2.0
		mesh_inst.material_override = red_mat
		get_tree().create_timer(0.25).timeout.connect(func():
			if is_instance_valid(mesh_inst):
				mesh_inst.material_override = orig_mat
		)

func _show_fire_burn_damage(target_node: Node3D, damage: int) -> void:
	if not is_instance_valid(target_node):
		return

	var dmg_label := Label3D.new()
	add_child(dmg_label)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.outline_size = 9
	dmg_label.outline_modulate = Color(0, 0, 0, 1)
	dmg_label.no_depth_test = true
	dmg_label.font_size = 46
	dmg_label.modulate = Color(1.0, 0.45, 0.0, 1.0) # Laranja vivo
	dmg_label.text = "🔥 -%d QUEIMADURA!" % damage
	dmg_label.global_position = target_node.global_position + Vector3(randf_range(-0.3, 0.3), 2.3 + randf_range(0.0, 0.2), randf_range(-0.3, 0.3))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dmg_label, "position:y", dmg_label.position.y + 1.5, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dmg_label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dmg_label.queue_free)

	if target_node == local_player:
		_flash_screen_red()

	_flash_character_red(target_node)

func _build_symmetric_village() -> void:
	house_doors.clear()
	# Limpa ou cria o container Structures para a Vila Simétrica
	var village_root := get_node_or_null("Structures") as Node3D
	if not village_root:
		village_root = Node3D.new()
		village_root.name = "Structures"
		add_child(village_root)
	else:
		for c in village_root.get_children():
			c.queue_free()

	# Materiais medievais compartilhados
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.28, 0.3, 0.34, 1.0) # Pedra medieval
	stone_mat.roughness = 0.85
	stone_mat.metallic = 0.15

	var cobblestone_mat := StandardMaterial3D.new()
	cobblestone_mat.albedo_color = Color(0.42, 0.44, 0.48, 1.0) # Calçamento cinza-claro
	cobblestone_mat.roughness = 0.8

	var dark_cobble_mat := StandardMaterial3D.new()
	dark_cobble_mat.albedo_color = Color(0.24, 0.25, 0.28, 1.0) # Pedra da praça central
	dark_cobble_mat.roughness = 0.85

	var wood_beam_mat := StandardMaterial3D.new()
	wood_beam_mat.albedo_color = Color(0.25, 0.16, 0.1, 1.0) # Vigas de madeira
	wood_beam_mat.roughness = 0.75

	# -------------------------------------------------------------
	# 1. CENTRO DA VILA (0, 0, 0) — PRAÇA PAVIMENTADA & CRISTAL DE RENASCIMENTO
	# -------------------------------------------------------------
	var plaza_mesh := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(14.0, 0.02, 14.0)
	plaza_mesh.mesh = p_box
	plaza_mesh.material_override = dark_cobble_mat
	plaza_mesh.position = Vector3(0.0, 0.015, 0.0)
	village_root.add_child(plaza_mesh)

	# 4 Postes de Luz ornamentais nos cantos da Praça Central
	for corner_pos in [Vector3(-6.2, 0, -6.2), Vector3(6.2, 0, -6.2), Vector3(-6.2, 0, 6.2), Vector3(6.2, 0, 6.2)]:
		var lamp := Node3D.new()
		lamp.position = corner_pos
		village_root.add_child(lamp)

		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.08
		post_mesh.bottom_radius = 0.12
		post_mesh.height = 3.2
		post.mesh = post_mesh
		post.material_override = wood_beam_mat
		post.position = Vector3(0, 1.6, 0)
		lamp.add_child(post)

		var lantern := OmniLight3D.new()
		lantern.light_color = Color(1.0, 0.85, 0.55)
		lantern.light_energy = 2.4
		lantern.omni_range = 7.5
		lantern.position = Vector3(0, 3.2, 0)
		lamp.add_child(lantern)

	# -------------------------------------------------------------
	# 2. RUAS PRINCIPAIS SIMÉTRICAS (AVENIDAS NORTE-SUL E LESTE-OESTE)
	# -------------------------------------------------------------
	# Avenida Norte-Sul: X = 0, de Z = -26 a +26 (largura 6m, y = 0.02, sem colisão para não travar o passo)
	var ave_ns := MeshInstance3D.new()
	var ns_box := BoxMesh.new()
	ns_box.size = Vector3(6.0, 0.02, 52.0)
	ave_ns.mesh = ns_box
	ave_ns.material_override = cobblestone_mat
	ave_ns.position = Vector3(0.0, 0.01, 0.0)
	village_root.add_child(ave_ns)

	# Avenida Leste-Oeste: Z = 0, de X = -26 a +26 (largura 6m, y = 0.02)
	var ave_ew := MeshInstance3D.new()
	var ew_box := BoxMesh.new()
	ew_box.size = Vector3(52.0, 0.02, 6.0)
	ave_ew.mesh = ew_box
	ave_ew.material_override = cobblestone_mat
	ave_ew.position = Vector3(0.0, 0.01, 0.0)
	village_root.add_child(ave_ew)

	# -------------------------------------------------------------
	# 3. MURALHA SIMÉTRICA DA VILA (±26m) COM 4 PORTÕES ABERTOS DE 8m
	# -------------------------------------------------------------
	var wall_h: float = 4.5
	var wall_t: float = 1.6
	var w_flank_len: float = 22.0 # (52m - 8m abertura) / 2 = 22m por flanco

	# Muralha Norte (Z = -26): Flanco Oeste (-15) e Flanco Leste (+15)
	_create_wall_segment(village_root, Vector3(-15.0, wall_h / 2.0, -26.0), Vector3(w_flank_len, wall_h, wall_t), stone_mat)
	_create_wall_segment(village_root, Vector3(15.0, wall_h / 2.0, -26.0), Vector3(w_flank_len, wall_h, wall_t), stone_mat)

	# Muralha Sul (Z = +26): Flanco Oeste (-15) e Flanco Leste (+15)
	_create_wall_segment(village_root, Vector3(-15.0, wall_h / 2.0, 26.0), Vector3(w_flank_len, wall_h, wall_t), stone_mat)
	_create_wall_segment(village_root, Vector3(15.0, wall_h / 2.0, 26.0), Vector3(w_flank_len, wall_h, wall_t), stone_mat)

	# Muralha Oeste (X = -26): Flanco Norte (-15) e Flanco Sul (+15)
	_create_wall_segment(village_root, Vector3(-26.0, wall_h / 2.0, -15.0), Vector3(wall_t, wall_h, w_flank_len), stone_mat)
	_create_wall_segment(village_root, Vector3(-26.0, wall_h / 2.0, 15.0), Vector3(wall_t, wall_h, w_flank_len), stone_mat)

	# Muralha Leste (X = +26): Flanco Norte (-15) e Flanco Sul (+15)
	_create_wall_segment(village_root, Vector3(26.0, wall_h / 2.0, -15.0), Vector3(wall_t, wall_h, w_flank_len), stone_mat)
	_create_wall_segment(village_root, Vector3(26.0, wall_h / 2.0, 15.0), Vector3(wall_t, wall_h, w_flank_len), stone_mat)

	# Torres de vigia e arcos dos 4 Portões abertos (8m)
	_create_gate_portal(village_root, Vector3(0.0, 0.0, -26.0), true, "Portão Norte\n[Ao Norte: Ruínas da Vigília]", Color(1.0, 0.85, 0.45), stone_mat)
	_create_gate_portal(village_root, Vector3(0.0, 0.0, 26.0), true, "Portão Sul\n[A Sudeste: Bosque Sussurrante]", Color(0.65, 0.95, 0.7), stone_mat)
	_create_gate_portal(village_root, Vector3(-26.0, 0.0, 0.0), false, "Portão Oeste\n[A Noroeste: Acampamento Desertor]", Color(1.0, 0.75, 0.5), stone_mat)
	_create_gate_portal(village_root, Vector3(26.0, 0.0, 0.0), false, "Portão Leste\n[Terras Selvagens]", Color(0.85, 0.9, 1.0), stone_mat)

	# -------------------------------------------------------------
	# 4. OS 4 QUADRANTES SIMÉTRICOS, CASAS, BECOS E SEGREDOS COM StaticBody3D
	# -------------------------------------------------------------

	# --- QUADRANTE NORDESTE (14, 0, 14) — A FORJA DO GARRICK & FORNALHA DE FOGO ---
	# Prédio da Oficina de Forja
	_create_solid_building(village_root, "GarrickForgeBuilding", Vector3(16.0, 0, 9.5), Vector3(8.0, 4.2, 5.5), Color(0.35, 0.32, 0.3), Color(0.38, 0.2, 0.12), "A Forja de Garrick", Color(1.0, 0.85, 0.4), "south")
	_create_interactive_door(village_root, "forge", "A Forja e Residência de Garrick", Vector3(16.0, 0.0, 6.75), Vector3(16.0, 0.0, 5.8), Vector3(16.0, 0.0, 8.0), true)

	# Móveis e Interior da Forja
	_create_furniture_piece(village_root, Vector3(18.5, 0.55, 10.5), Vector3(1.2, 1.1, 2.4), Color(0.28, 0.18, 0.12))
	_create_furniture_piece(village_root, Vector3(18.8, 1.2, 8.2), Vector3(0.6, 2.4, 1.8), Color(0.22, 0.15, 0.1))
	_create_furniture_piece(village_root, Vector3(13.2, 0.35, 10.8), Vector3(1.4, 0.7, 2.2), Color(0.35, 0.28, 0.22))
	_create_furniture_piece(village_root, Vector3(16.0, 1.0, 11.8), Vector3(2.0, 2.0, 0.8), Color(0.2, 0.2, 0.22))

	var forge_int_light := OmniLight3D.new()
	forge_int_light.light_color = Color(1.0, 0.75, 0.4)
	forge_int_light.light_energy = 2.4
	forge_int_light.omni_range = 8.0
	forge_int_light.position = Vector3(16.0, 2.6, 9.5)
	village_root.add_child(forge_int_light)

	# Bigorna Sólida de Aço
	var anvil_body := StaticBody3D.new()
	anvil_body.name = "ForgeAnvil"
	anvil_body.position = Vector3(11.5, 0.4, 11.5)
	anvil_body.collision_layer = 1
	village_root.add_child(anvil_body)

	var anvil_col := CollisionShape3D.new()
	var av_shape := BoxShape3D.new()
	av_shape.size = Vector3(0.9, 0.8, 0.6)
	anvil_col.shape = av_shape
	anvil_body.add_child(anvil_col)

	var anvil_mesh := MeshInstance3D.new()
	var av_mesh := BoxMesh.new()
	av_mesh.size = Vector3(0.9, 0.8, 0.6)
	anvil_mesh.mesh = av_mesh
	var av_mat := StandardMaterial3D.new()
	av_mat.albedo_color = Color(0.18, 0.19, 0.22, 1.0)
	av_mat.metallic = 0.92
	av_mat.roughness = 0.22
	anvil_mesh.material_override = av_mat
	anvil_body.add_child(anvil_mesh)

	# A FORNALHA INCANDESCENTE EM (14, 0, 14) — Cuidado: Queima!
	var furnace_body := StaticBody3D.new()
	furnace_body.name = "IncandescentFurnace"
	furnace_body.position = Vector3(14.0, 0.0, 14.0)
	furnace_body.collision_layer = 1
	village_root.add_child(furnace_body)

	# Colisão física sólida da Fornalha (jogador bate e não atravessa)
	var fn_col := CollisionShape3D.new()
	var fn_shape := BoxShape3D.new()
	fn_shape.size = Vector3(2.6, 3.4, 2.6)
	fn_col.shape = fn_shape
	fn_col.position = Vector3(0, 1.7, 0)
	furnace_body.add_child(fn_col)

	# Chaminé / Estrutura de Pedra Refratária
	var fn_mesh := MeshInstance3D.new()
	var fn_bmesh := BoxMesh.new()
	fn_bmesh.size = Vector3(2.6, 3.4, 2.6)
	fn_mesh.mesh = fn_bmesh
	fn_mesh.position = Vector3(0, 1.7, 0)
	var fn_mat := StandardMaterial3D.new()
	fn_mat.albedo_color = Color(0.2, 0.18, 0.19, 1.0)
	fn_mat.roughness = 0.9
	fn_mesh.material_override = fn_mat
	furnace_body.add_child(fn_mesh)

	# Abertura incandescente de brasas ardentes
	var ember_mesh := MeshInstance3D.new()
	var em_box := BoxMesh.new()
	em_box.size = Vector3(1.8, 1.2, 1.8)
	ember_mesh.mesh = em_box
	ember_mesh.position = Vector3(0, 0.9, 0)
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(1.0, 0.45, 0.05, 1.0)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.45, 0.05, 1.0)
	ember_mat.emission_energy_multiplier = 4.8
	ember_mesh.material_override = ember_mat
	furnace_body.add_child(ember_mesh)

	# Partículas de Fogo ardente
	var fire_cpu := CPUParticles3D.new()
	fire_cpu.name = "FireParticles"
	fire_cpu.position = Vector3(0, 1.5, 0)
	fire_cpu.amount = 50
	fire_cpu.lifetime = 0.9
	fire_cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire_cpu.emission_box_extents = Vector3(0.7, 0.2, 0.7)
	fire_cpu.direction = Vector3(0, 1, 0)
	fire_cpu.spread = 15.0
	fire_cpu.initial_velocity_min = 2.2
	fire_cpu.initial_velocity_max = 4.0
	fire_cpu.scale_amount_min = 0.15
	fire_cpu.scale_amount_max = 0.35
	fire_cpu.color = Color(1.0, 0.55, 0.1, 0.95)
	var fire_pmat := StandardMaterial3D.new()
	fire_pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_pmat.albedo_color = Color(1.0, 0.5, 0.08, 1.0)
	fire_pmat.emission_enabled = true
	fire_pmat.emission = Color(1.0, 0.45, 0.05, 1.0)
	fire_pmat.emission_energy_multiplier = 4.0
	var f_smesh := SphereMesh.new()
	f_smesh.radius = 0.14
	f_smesh.height = 0.28
	f_smesh.material = fire_pmat
	fire_cpu.mesh = f_smesh
	furnace_body.add_child(fire_cpu)

	# Luz intensa da fornalha
	var fn_light := OmniLight3D.new()
	fn_light.light_color = Color(1.0, 0.5, 0.1)
	fn_light.light_energy = 4.5
	fn_light.omni_range = 10.0
	fn_light.position = Vector3(0, 2.0, 0)
	furnace_body.add_child(fn_light)

	# Label3D de Alerta da Fornalha
	var fn_lbl := Label3D.new()
	fn_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fn_lbl.outline_size = 9
	fn_lbl.outline_modulate = Color(0, 0, 0, 1)
	fn_lbl.font_size = 28
	fn_lbl.modulate = Color(1.0, 0.45, 0.05)
	fn_lbl.text = "🔥 Fornalha Ardente (Cuidado: Queima!)"
	fn_lbl.position = Vector3(0, 3.8, 0)
	furnace_body.add_child(fn_lbl)

	# --- QUADRANTE NOROESTE (-14, 0, 14) — TAVERNA & BECO DO CONTRABANDISTA ---
	# Prédio grande da Taverna em (-14, 0, 12)
	_create_solid_building(village_root, "TavernBuilding", Vector3(-14.0, 0, 12.0), Vector3(9.0, 5.0, 7.0), Color(0.32, 0.24, 0.18), Color(0.45, 0.22, 0.14), "Taverna do Crepúsculo", Color(1.0, 0.85, 0.5), "south")
	_create_interactive_door(village_root, "tavern", "Taverna do Crepúsculo", Vector3(-14.0, 0.0, 8.5), Vector3(-14.0, 0.0, 7.5), Vector3(-14.0, 0.0, 9.8), true)

	# Móveis e Interior da Taverna
	_create_furniture_piece(village_root, Vector3(-15.2, 0.55, 13.5), Vector3(4.4, 1.1, 0.8), Color(0.26, 0.16, 0.1))
	_create_furniture_piece(village_root, Vector3(-13.0, 0.55, 14.2), Vector3(0.8, 1.1, 2.0), Color(0.26, 0.16, 0.1))
	_create_furniture_piece(village_root, Vector3(-16.8, 0.65, 14.5), Vector3(1.8, 1.3, 1.0), Color(0.35, 0.22, 0.12))
	_create_furniture_piece(village_root, Vector3(-17.8, 1.2, 11.5), Vector3(0.8, 2.4, 2.2), Color(0.22, 0.22, 0.24))
	_create_furniture_piece(village_root, Vector3(-11.5, 0.45, 11.2), Vector3(1.6, 0.9, 1.6), Color(0.3, 0.2, 0.14))
	_create_furniture_piece(village_root, Vector3(-15.2, 0.45, 10.0), Vector3(1.8, 0.9, 1.4), Color(0.3, 0.2, 0.14))

	var tavern_int_light := OmniLight3D.new()
	tavern_int_light.light_color = Color(1.0, 0.8, 0.45)
	tavern_int_light.light_energy = 3.2
	tavern_int_light.omni_range = 9.5
	tavern_int_light.position = Vector3(-14.0, 3.2, 12.0)
	village_root.add_child(tavern_int_light)

	# Casa Medieval ao lado em (-21, 0, 14)
	_create_solid_building(village_root, "AlleyHouse", Vector3(-21.0, 0, 14.0), Vector3(6.0, 4.2, 6.0), Color(0.35, 0.3, 0.25), Color(0.28, 0.18, 0.12), "Residência dos Fundos", Color(0.85, 0.85, 0.85), "south")

	# Beco Estreito e Escuro em (-19, 0, 17) onde Varis se esconde
	var alley_crates := StaticBody3D.new()
	alley_crates.name = "AlleyCrates"
	alley_crates.position = Vector3(-17.5, 0.6, 17.5)
	alley_crates.collision_layer = 1
	village_root.add_child(alley_crates)

	var ac_col := CollisionShape3D.new()
	var ac_shape := BoxShape3D.new()
	ac_shape.size = Vector3(1.4, 1.2, 1.4)
	ac_col.shape = ac_shape
	alley_crates.add_child(ac_col)

	var ac_mesh := MeshInstance3D.new()
	var ac_mesh_res := BoxMesh.new()
	ac_mesh_res.size = Vector3(1.4, 1.2, 1.4)
	ac_mesh.mesh = ac_mesh_res
	ac_mesh.material_override = wood_beam_mat
	alley_crates.add_child(ac_mesh)

	var alley_light := OmniLight3D.new()
	alley_light.light_color = Color(0.9, 0.2, 0.25)
	alley_light.light_energy = 1.4
	alley_light.omni_range = 5.5
	alley_light.position = Vector3(-19.0, 1.8, 17.0)
	village_root.add_child(alley_light)

	var alley_lbl := Label3D.new()
	alley_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alley_lbl.outline_size = 8
	alley_lbl.outline_modulate = Color(0, 0, 0, 1)
	alley_lbl.font_size = 24
	alley_lbl.modulate = Color(1.0, 0.35, 0.35)
	alley_lbl.text = "Beco Sombrio\n[Esconderijo de Varis]"
	alley_lbl.position = Vector3(-19.0, 2.6, 17.0)
	village_root.add_child(alley_lbl)

	# --- QUADRANTE SUDESTE (14, 0, -14) — ALQUIMIA DA LYRA & CASAS SIMÉTRICAS ---
	# Laboratório da Lyra em (14, 0, -10)
	_create_solid_building(village_root, "LyraAlchemyLab", Vector3(14.0, 0, -10.0), Vector3(7.5, 4.2, 6.0), Color(0.32, 0.28, 0.36), Color(0.4, 0.2, 0.45), "Laboratório Alquímico da Lyra", Color(0.85, 0.7, 1.0), "north")

	# Duas Casas Residenciais simétricas formando vielas
	_create_solid_building(village_root, "HouseSE_East", Vector3(20.0, 0, -8.0), Vector3(6.0, 4.0, 5.5), Color(0.33, 0.32, 0.3), Color(0.35, 0.18, 0.12), "Casa Residencial Leste", Color(0.85, 0.85, 0.85), "west")
	_create_solid_building(village_root, "HouseSE_LyraHome", Vector3(14.0, 0, -21.0), Vector3(6.5, 4.2, 6.0), Color(0.34, 0.3, 0.35), Color(0.38, 0.18, 0.35), "Casa da Lyra", Color(0.85, 0.7, 1.0), "north")
	_create_interactive_door(village_root, "lyra_home", "Casa da Alquimista Lyra", Vector3(14.0, 0.0, -18.0), Vector3(14.0, 0.0, -17.0), Vector3(14.0, 0.0, -19.2), true)

	# Móveis e Interior da Casa da Lyra
	_create_furniture_piece(village_root, Vector3(15.8, 0.55, -22.5), Vector3(1.8, 1.1, 1.2), Color(0.24, 0.18, 0.28))
	_create_furniture_piece(village_root, Vector3(12.0, 1.3, -22.5), Vector3(1.8, 2.6, 0.8), Color(0.22, 0.16, 0.12))
	_create_furniture_piece(village_root, Vector3(12.0, 0.4, -19.5), Vector3(1.6, 0.8, 2.2), Color(0.38, 0.2, 0.4))
	_create_furniture_piece(village_root, Vector3(15.8, 0.35, -19.5), Vector3(1.2, 0.7, 1.0), Color(0.28, 0.2, 0.15))

	var lyra_int_light := OmniLight3D.new()
	lyra_int_light.light_color = Color(0.85, 0.5, 1.0)
	lyra_int_light.light_energy = 2.6
	lyra_int_light.omni_range = 7.5
	lyra_int_light.position = Vector3(14.0, 2.5, -21.0)
	village_root.add_child(lyra_int_light)

	# Lanterna mística na viela de Lyra
	var lyra_light := OmniLight3D.new()
	lyra_light.light_color = Color(0.75, 0.45, 1.0)
	lyra_light.light_energy = 2.2
	lyra_light.omni_range = 6.5
	lyra_light.position = Vector3(14.0, 2.0, -15.5)
	village_root.add_child(lyra_light)

	# --- QUADRANTE SUDOESTE (-14, 0, -14) — QUARTEL DA GUARDA & ENTRADA DOS ESGOTOS ---
	# Quartel em (-14, 0, -12) próximo aos Bonecos de Treino 101 e 102
	_create_solid_building(village_root, "GuardBarracks", Vector3(-14.0, 0, -12.0), Vector3(9.0, 4.8, 7.0), Color(0.28, 0.3, 0.35), Color(0.15, 0.25, 0.45), "Quartel da Guarda Real", Color(0.85, 0.95, 1.0), "north")
	_create_interactive_door(village_root, "barracks", "Quartel da Guarda Real", Vector3(-14.0, 0.0, -8.5), Vector3(-14.0, 0.0, -7.5), Vector3(-14.0, 0.0, -9.8), true)

	# Móveis e Interior do Quartel
	_create_furniture_piece(village_root, Vector3(-14.0, 0.5, -12.0), Vector3(2.6, 1.0, 2.0), Color(0.22, 0.16, 0.12))
	_create_furniture_piece(village_root, Vector3(-17.5, 1.2, -11.0), Vector3(0.7, 2.4, 2.2), Color(0.18, 0.19, 0.22), 0.3)
	_create_furniture_piece(village_root, Vector3(-11.5, 1.0, -13.5), Vector3(1.4, 2.0, 2.4), Color(0.25, 0.18, 0.12))
	_create_furniture_piece(village_root, Vector3(-11.5, 1.0, -10.5), Vector3(1.4, 2.0, 2.4), Color(0.25, 0.18, 0.12))
	_create_furniture_piece(village_root, Vector3(-16.8, 0.4, -14.2), Vector3(1.8, 0.8, 1.0), Color(0.16, 0.18, 0.2), 0.25)

	var barracks_int_light := OmniLight3D.new()
	barracks_int_light.light_color = Color(1.0, 0.82, 0.5)
	barracks_int_light.light_energy = 2.6
	barracks_int_light.omni_range = 8.5
	barracks_int_light.position = Vector3(-14.0, 3.0, -12.0)
	village_root.add_child(barracks_int_light)

	# ENTRADA SECRETA DOS ESGOTOS no canto escuro em (-21, 0, -21)
	var sewer_pit := StaticBody3D.new()
	sewer_pit.name = "SecretSewerEntrance"
	sewer_pit.position = Vector3(-21.0, 0.2, -21.0)
	sewer_pit.collision_layer = 1
	village_root.add_child(sewer_pit)

	var sp_col := CollisionShape3D.new()
	var sp_shape := BoxShape3D.new()
	sp_shape.size = Vector3(2.8, 0.4, 2.8)
	sp_col.shape = sp_shape
	sewer_pit.add_child(sp_col)

	# Bocal de pedra escura do bueiro
	var sp_mesh := MeshInstance3D.new()
	var sp_bmesh := BoxMesh.new()
	sp_bmesh.size = Vector3(2.8, 0.4, 2.8)
	sp_mesh.mesh = sp_bmesh
	var sp_mat := StandardMaterial3D.new()
	sp_mat.albedo_color = Color(0.12, 0.14, 0.16, 1.0)
	sp_mat.roughness = 0.95
	sp_mesh.material_override = sp_mat
	sewer_pit.add_child(sp_mesh)

	# Grades de ferro do bueiro
	var grate := MeshInstance3D.new()
	var gr_box := BoxMesh.new()
	gr_box.size = Vector3(2.4, 0.05, 2.4)
	grate.mesh = gr_box
	grate.position = Vector3(0, 0.21, 0)
	var gr_mat := StandardMaterial3D.new()
	gr_mat.albedo_color = Color(0.08, 0.09, 0.11, 1.0)
	gr_mat.metallic = 0.95
	gr_mat.roughness = 0.3
	grate.material_override = gr_mat
	sewer_pit.add_child(grate)

	# Névoa verde misteriosa subindo dos esgotos
	var mist_cpu := CPUParticles3D.new()
	mist_cpu.name = "SewerMist"
	mist_cpu.position = Vector3(0, 0.3, 0)
	mist_cpu.amount = 35
	mist_cpu.lifetime = 2.0
	mist_cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist_cpu.emission_box_extents = Vector3(1.1, 0.1, 1.1)
	mist_cpu.direction = Vector3(0, 1, 0)
	mist_cpu.spread = 20.0
	mist_cpu.initial_velocity_min = 0.4
	mist_cpu.initial_velocity_max = 0.9
	mist_cpu.scale_amount_min = 0.2
	mist_cpu.scale_amount_max = 0.5
	var mist_mat := StandardMaterial3D.new()
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.albedo_color = Color(0.15, 0.85, 0.35, 0.4)
	var m_smesh := SphereMesh.new()
	m_smesh.radius = 0.22
	m_smesh.height = 0.44
	m_smesh.material = mist_mat
	mist_cpu.mesh = m_smesh
	sewer_pit.add_child(mist_cpu)

	# Brilho verde subterrâneo
	var sewer_light := OmniLight3D.new()
	sewer_light.light_color = Color(0.2, 0.9, 0.35)
	sewer_light.light_energy = 2.4
	sewer_light.omni_range = 6.0
	sewer_light.position = Vector3(0, 0.8, 0)
	sewer_pit.add_child(sewer_light)

	# Label Secreto 3D
	var sewer_lbl := Label3D.new()
	sewer_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sewer_lbl.outline_size = 8
	sewer_lbl.outline_modulate = Color(0, 0, 0, 1)
	sewer_lbl.font_size = 26
	sewer_lbl.modulate = Color(0.3, 1.0, 0.5)
	sewer_lbl.text = "Entrada dos Esgotos Antigos (Segredo)"
	sewer_lbl.position = Vector3(0, 2.0, 0)
	sewer_pit.add_child(sewer_lbl)

func _create_wall_segment(parent: Node3D, pos: Vector3, size: Vector3, stone_mat: Material) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = pos
	wall.collision_layer = 1
	wall.collision_mask = 0
	parent.add_child(wall)

	var col := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = size
	col.shape = bshape
	wall.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = size
	mesh_inst.mesh = bmesh
	mesh_inst.material_override = stone_mat
	wall.add_child(mesh_inst)

	return wall

func _create_gate_portal(parent: Node3D, center_pos: Vector3, is_north_south: bool, sign_text: String, sign_col: Color, stone_mat: Material) -> void:
	var gate_root := Node3D.new()
	gate_root.position = center_pos
	parent.add_child(gate_root)

	var tower_size := Vector3(2.2, 6.2, 2.2)
	var tower_offset := 4.8

	var pos_a := Vector3(-tower_offset, 3.1, 0) if is_north_south else Vector3(0, 3.1, -tower_offset)
	var pos_b := Vector3(tower_offset, 3.1, 0) if is_north_south else Vector3(0, 3.1, tower_offset)

	# Duas torres de vigia sólidas nos pilares do portão
	for p in [pos_a, pos_b]:
		var tower := StaticBody3D.new()
		tower.position = p
		tower.collision_layer = 1
		tower.collision_mask = 0
		gate_root.add_child(tower)

		var tcol := CollisionShape3D.new()
		var tbshape := BoxShape3D.new()
		tbshape.size = tower_size
		tcol.shape = tbshape
		tower.add_child(tcol)

		var tmesh := MeshInstance3D.new()
		var tbmesh := BoxMesh.new()
		tbmesh.size = tower_size
		tmesh.mesh = tbmesh
		tmesh.material_override = stone_mat
		tower.add_child(tmesh)

	# Viga de arco do topo do portão
	var arch := MeshInstance3D.new()
	var abmesh := BoxMesh.new()
	if is_north_south:
		abmesh.size = Vector3(8.4, 1.2, 1.8)
	else:
		abmesh.size = Vector3(1.8, 1.2, 8.4)
	arch.mesh = abmesh
	arch.position = Vector3(0, 5.2, 0)
	arch.material_override = stone_mat
	gate_root.add_child(arch)

	# Placa do Portão
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0, 0, 0, 1)
	lbl.font_size = 28
	lbl.modulate = sign_col
	lbl.text = sign_text
	lbl.position = Vector3(0, 6.2, 0)
	gate_root.add_child(lbl)

func _add_wall_piece(body: StaticBody3D, piece_pos: Vector3, piece_size: Vector3, mat: Material) -> void:
	var col := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = piece_size
	col.shape = bshape
	col.position = piece_pos
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = piece_size
	mesh_inst.mesh = bmesh
	mesh_inst.position = piece_pos
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

func _create_solid_building(parent: Node3D, b_name: String, pos: Vector3, size: Vector3, wall_col: Color, roof_col: Color, sign_text: String = "", sign_color: Color = Color.WHITE, door_side: String = "south") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = b_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = wall_col
	wall_mat.roughness = 0.8

	var wall_t := 0.45
	var door_w := 2.2
	var door_h := 2.7

	# Piso Interno de Madeira
	var floor_inst := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(size.x - 0.2, 0.02, size.z - 0.2)
	floor_inst.mesh = fmesh
	floor_inst.position = Vector3(0, 0.015, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.25, 0.18, 0.12, 1.0)
	floor_mat.roughness = 0.7
	floor_inst.material_override = floor_mat
	body.add_child(floor_inst)

	# Paredes perimetrais com abertura de porta real
	if door_side == "south":
		# Parede Norte (Fundos - Sólida)
		_add_wall_piece(body, Vector3(0, size.y / 2.0, size.z / 2.0 - wall_t / 2.0), Vector3(size.x, size.y, wall_t), wall_mat)
		# Parede Oeste (Lateral Esquerda - Sólida)
		_add_wall_piece(body, Vector3(-size.x / 2.0 + wall_t / 2.0, size.y / 2.0, 0), Vector3(wall_t, size.y, size.z), wall_mat)
		# Parede Leste (Lateral Direita - Sólida)
		_add_wall_piece(body, Vector3(size.x / 2.0 - wall_t / 2.0, size.y / 2.0, 0), Vector3(wall_t, size.y, size.z), wall_mat)
		# Parede Sul (Frente com Porta de 2.2m)
		var side_w := (size.x - door_w) / 2.0
		_add_wall_piece(body, Vector3(-(size.x + door_w) / 4.0, size.y / 2.0, -size.z / 2.0 + wall_t / 2.0), Vector3(side_w, size.y, wall_t), wall_mat)
		_add_wall_piece(body, Vector3((size.x + door_w) / 4.0, size.y / 2.0, -size.z / 2.0 + wall_t / 2.0), Vector3(side_w, size.y, wall_t), wall_mat)
		var lintel_h := size.y - door_h
		if lintel_h > 0.1:
			_add_wall_piece(body, Vector3(0, door_h + lintel_h / 2.0, -size.z / 2.0 + wall_t / 2.0), Vector3(door_w, lintel_h, wall_t), wall_mat)
	elif door_side == "north":
		# Parede Sul (Fundos - Sólida)
		_add_wall_piece(body, Vector3(0, size.y / 2.0, -size.z / 2.0 + wall_t / 2.0), Vector3(size.x, size.y, wall_t), wall_mat)
		# Parede Oeste (Lateral - Sólida)
		_add_wall_piece(body, Vector3(-size.x / 2.0 + wall_t / 2.0, size.y / 2.0, 0), Vector3(wall_t, size.y, size.z), wall_mat)
		# Parede Leste (Lateral - Sólida)
		_add_wall_piece(body, Vector3(size.x / 2.0 - wall_t / 2.0, size.y / 2.0, 0), Vector3(wall_t, size.y, size.z), wall_mat)
		# Parede Norte (Frente com Porta de 2.2m)
		var side_w := (size.x - door_w) / 2.0
		_add_wall_piece(body, Vector3(-(size.x + door_w) / 4.0, size.y / 2.0, size.z / 2.0 - wall_t / 2.0), Vector3(side_w, size.y, wall_t), wall_mat)
		_add_wall_piece(body, Vector3((size.x + door_w) / 4.0, size.y / 2.0, size.z / 2.0 - wall_t / 2.0), Vector3(side_w, size.y, wall_t), wall_mat)
		var lintel_h := size.y - door_h
		if lintel_h > 0.1:
			_add_wall_piece(body, Vector3(0, door_h + lintel_h / 2.0, size.z / 2.0 - wall_t / 2.0), Vector3(door_w, lintel_h, wall_t), wall_mat)
	elif door_side == "west":
		# Parede Norte (Sólida)
		_add_wall_piece(body, Vector3(0, size.y / 2.0, size.z / 2.0 - wall_t / 2.0), Vector3(size.x, size.y, wall_t), wall_mat)
		# Parede Sul (Sólida)
		_add_wall_piece(body, Vector3(0, size.y / 2.0, -size.z / 2.0 + wall_t / 2.0), Vector3(size.x, size.y, wall_t), wall_mat)
		# Parede Leste (Fundos - Sólida)
		_add_wall_piece(body, Vector3(size.x / 2.0 - wall_t / 2.0, size.y / 2.0, 0), Vector3(wall_t, size.y, size.z), wall_mat)
		# Parede Oeste (Frente com Porta de 2.2m)
		var side_d := (size.z - door_w) / 2.0
		_add_wall_piece(body, Vector3(-size.x / 2.0 + wall_t / 2.0, size.y / 2.0, -(size.z + door_w) / 4.0), Vector3(wall_t, size.y, side_d), wall_mat)
		_add_wall_piece(body, Vector3(-size.x / 2.0 + wall_t / 2.0, size.y / 2.0, (size.z + door_w) / 4.0), Vector3(wall_t, size.y, side_d), wall_mat)
		var lintel_h := size.y - door_h
		if lintel_h > 0.1:
			_add_wall_piece(body, Vector3(-size.x / 2.0 + wall_t / 2.0, door_h + lintel_h / 2.0, 0), Vector3(wall_t, lintel_h, door_w), wall_mat)
	else:
		_add_wall_piece(body, Vector3(0, size.y / 2.0, 0), size, wall_mat)

	# Telhado
	var roof := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(size.x + 0.6, 1.2, size.z + 0.6)
	roof.mesh = rmesh
	roof.position = Vector3(0, size.y + 0.5, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_col
	roof_mat.roughness = 0.75
	roof.material_override = roof_mat
	body.add_child(roof)

	if sign_text != "":
		var lbl := Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.outline_size = 7
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.font_size = 26
		lbl.modulate = sign_color
		lbl.text = sign_text
		lbl.position = Vector3(0, size.y + 1.6, 0)
		body.add_child(lbl)

	return body

func _create_furniture_piece(parent: Node3D, pos: Vector3, size: Vector3, col: Color, roughness: float = 0.8) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var col_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col_shape.shape = shape
	body.add_child(col_shape)

	var mesh_inst := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = size
	mesh_inst.mesh = bmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = roughness
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	return body

func _create_interactive_door(parent: Node3D, house_id: String, house_name: String, door_pos: Vector3, outside_pos: Vector3, inside_pos: Vector3, is_north_south: bool) -> void:
	var door_root := Node3D.new()
	door_root.name = "Door_" + house_id
	door_root.position = door_pos
	parent.add_child(door_root)

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.22, 0.14, 0.09, 1.0)
	frame_mat.roughness = 0.85

	# Batente / moldura da porta
	var frame_left := MeshInstance3D.new()
	var fl_mesh := BoxMesh.new()
	if is_north_south:
		fl_mesh.size = Vector3(0.15, 2.6, 0.3)
		frame_left.position = Vector3(-1.05, 1.3, 0.0)
	else:
		fl_mesh.size = Vector3(0.3, 2.6, 0.15)
		frame_left.position = Vector3(0.0, 1.3, -1.05)
	frame_left.mesh = fl_mesh
	frame_left.material_override = frame_mat
	door_root.add_child(frame_left)

	var frame_right := MeshInstance3D.new()
	var fr_mesh := BoxMesh.new()
	if is_north_south:
		fr_mesh.size = Vector3(0.15, 2.6, 0.3)
		frame_right.position = Vector3(1.05, 1.3, 0.0)
	else:
		fr_mesh.size = Vector3(0.3, 2.6, 0.15)
		frame_right.position = Vector3(0.0, 1.3, 1.05)
	frame_right.mesh = fr_mesh
	frame_right.material_override = frame_mat
	door_root.add_child(frame_right)

	# Folha da porta de madeira entreaberta (para permitir visualização interna e passagem)
	var door_leaf := MeshInstance3D.new()
	var d_mesh := BoxMesh.new()
	if is_north_south:
		d_mesh.size = Vector3(0.95, 2.45, 0.08)
		door_leaf.position = Vector3(-0.5, 1.25, 0.2)
		door_leaf.rotation.y = deg_to_rad(55.0)
	else:
		d_mesh.size = Vector3(0.08, 2.45, 0.95)
		door_leaf.position = Vector3(0.2, 1.25, -0.5)
		door_leaf.rotation.y = deg_to_rad(55.0)
	door_leaf.mesh = d_mesh
	door_leaf.material_override = frame_mat
	door_root.add_child(door_leaf)

	# Label 3D Interativo
	var door_lbl := Label3D.new()
	door_lbl.name = "DoorLabel"
	door_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	door_lbl.outline_size = 8
	door_lbl.outline_modulate = Color(0, 0, 0, 1)
	door_lbl.font_size = 22
	door_lbl.modulate = Color(1.0, 0.9, 0.5)
	door_lbl.text = "🚪 [E] Entrar / Sair\n%s" % house_name
	door_lbl.position = Vector3(0, 2.9, 0)
	door_root.add_child(door_lbl)

	house_doors.append({
		"id": house_id,
		"name": house_name,
		"door_outside": outside_pos,
		"door_inside": inside_pos,
		"label_node": door_lbl
	})

func _build_new_landmarks() -> void:
	var landmarks_root := Node3D.new()
	landmarks_root.name = "NewLandmarks"
	add_child(landmarks_root)

	# =========================================================================
	# 1. ⛪ IGREJA DA LUZ SAGRADA EM (-20, 0, -18)
	# =========================================================================
	var church_root := Node3D.new()
	church_root.name = "HolyLightChurch"
	church_root.position = Vector3(-20.0, 0.0, -18.0)
	landmarks_root.add_child(church_root)

	var church_stone_mat := StandardMaterial3D.new()
	church_stone_mat.albedo_color = Color(0.92, 0.90, 0.85, 1.0) # Pedra marfim / branca
	church_stone_mat.roughness = 0.85

	var church_gold_mat := StandardMaterial3D.new()
	church_gold_mat.albedo_color = Color(0.85, 0.70, 0.22, 1.0) # Telhado dourado
	church_gold_mat.metallic = 0.6
	church_gold_mat.roughness = 0.35

	var church_solar_mat := StandardMaterial3D.new()
	church_solar_mat.albedo_color = Color(1.0, 0.88, 0.25, 1.0)
	church_solar_mat.emission_enabled = true
	church_solar_mat.emission = Color(1.0, 0.88, 0.25)
	church_solar_mat.emission_energy_multiplier = 4.5

	# Nave Principal (Templo de Pedra Marfim 10m x 6m x 14m)
	var church_body := StaticBody3D.new()
	church_body.name = "ChurchStructure"
	church_body.collision_layer = 1
	church_body.collision_mask = 0
	church_root.add_child(church_body)

	var c_wall_t := 0.5
	var c_size := Vector3(10.0, 6.0, 14.0)
	var c_door_w := 2.4
	var c_door_h := 3.0

	# Piso de mármore interno
	var c_floor := MeshInstance3D.new()
	var c_fmesh := BoxMesh.new()
	c_fmesh.size = Vector3(c_size.x - 0.2, 0.02, c_size.z - 0.2)
	c_floor.mesh = c_fmesh
	var c_fmat := StandardMaterial3D.new()
	c_fmat.albedo_color = Color(0.82, 0.82, 0.85, 1.0)
	c_fmat.roughness = 0.5
	c_floor.material_override = c_fmat
	c_floor.position = Vector3(0, 0.015, 0)
	church_body.add_child(c_floor)

	# Parede Norte (Fundos / Atrás do Altar - Sólida em Z = -7.0)
	_add_wall_piece(church_body, Vector3(0, c_size.y / 2.0, -c_size.z / 2.0 + c_wall_t / 2.0), Vector3(c_size.x, c_size.y, c_wall_t), church_stone_mat)
	# Parede Oeste (Lateral Esquerda em X = -5.0)
	_add_wall_piece(church_body, Vector3(-c_size.x / 2.0 + c_wall_t / 2.0, c_size.y / 2.0, 0), Vector3(c_wall_t, c_size.y, c_size.z), church_stone_mat)
	# Parede Leste (Lateral Direita em X = +5.0)
	_add_wall_piece(church_body, Vector3(c_size.x / 2.0 - c_wall_t / 2.0, c_size.y / 2.0, 0), Vector3(c_wall_t, c_size.y, c_size.z), church_stone_mat)
	# Parede Sul (Frente com abertura de porta voltada para Z = +7.0)
	var c_side_w := (c_size.x - c_door_w) / 2.0
	_add_wall_piece(church_body, Vector3(-(c_size.x + c_door_w) / 4.0, c_size.y / 2.0, c_size.z / 2.0 - c_wall_t / 2.0), Vector3(c_side_w, c_size.y, c_wall_t), church_stone_mat)
	_add_wall_piece(church_body, Vector3((c_size.x + c_door_w) / 4.0, c_size.y / 2.0, c_size.z / 2.0 - c_wall_t / 2.0), Vector3(c_side_w, c_size.y, c_wall_t), church_stone_mat)
	var c_lintel_h := c_size.y - c_door_h
	if c_lintel_h > 0.1:
		_add_wall_piece(church_body, Vector3(0, c_door_h + c_lintel_h / 2.0, c_size.z / 2.0 - c_wall_t / 2.0), Vector3(c_door_w, c_lintel_h, c_wall_t), church_stone_mat)

	# Telhado Dourado
	var church_roof := MeshInstance3D.new()
	var cr_mesh := BoxMesh.new()
	cr_mesh.size = Vector3(c_size.x + 0.8, 1.4, c_size.z + 0.8)
	church_roof.mesh = cr_mesh
	church_roof.position = Vector3(0, c_size.y + 0.6, 0)
	church_roof.material_override = church_gold_mat
	church_body.add_child(church_roof)

	# Vitrais Laterais Coloridos nas paredes Leste e Oeste
	for side_x in [-c_size.x / 2.0 - 0.05, c_size.x / 2.0 + 0.05]:
		for z_offset in [-3.5, 0.0, 3.5]:
			var glass := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.12, 2.6, 1.4)
			glass.mesh = gm
			var glass_mat := StandardMaterial3D.new()
			if z_offset < -1.0:
				glass_mat.albedo_color = Color(0.15, 0.55, 1.0, 0.9)
				glass_mat.emission = Color(0.15, 0.55, 1.0)
			elif z_offset > 1.0:
				glass_mat.albedo_color = Color(0.95, 0.2, 0.3, 0.9)
				glass_mat.emission = Color(0.95, 0.2, 0.3)
			else:
				glass_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
				glass_mat.emission = Color(1.0, 0.85, 0.2)
			glass_mat.emission_enabled = true
			glass_mat.emission_energy_multiplier = 2.4
			glass.material_override = glass_mat
			glass.position = Vector3(side_x, 3.2, z_offset)
			church_root.add_child(glass)

	# Torre de Sino Alta (Frente da Igreja, altura 12m)
	var tower_body := StaticBody3D.new()
	tower_body.name = "ChurchBellTower"
	tower_body.position = Vector3(0.0, 0.0, c_size.z / 2.0 + 1.2)
	tower_body.collision_layer = 1
	tower_body.collision_mask = 0
	church_root.add_child(tower_body)

	var t_col := CollisionShape3D.new()
	var t_box := BoxShape3D.new()
	t_box.size = Vector3(3.6, 12.0, 3.6)
	t_col.shape = t_box
	t_col.position = Vector3(0, 6.0, 0)
	tower_body.add_child(t_col)

	var t_mesh := MeshInstance3D.new()
	var t_bmesh := BoxMesh.new()
	t_bmesh.size = Vector3(3.6, 12.0, 3.6)
	t_mesh.mesh = t_bmesh
	t_mesh.position = Vector3(0, 6.0, 0)
	t_mesh.material_override = church_stone_mat
	tower_body.add_child(t_mesh)

	# Topo da Torre com Sino de Bronze e Telhado Dourado
	var bell_roof := MeshInstance3D.new()
	var br_mesh := BoxMesh.new()
	br_mesh.size = Vector3(4.2, 1.2, 4.2)
	bell_roof.mesh = br_mesh
	bell_roof.position = Vector3(0, 12.6, 0)
	bell_roof.material_override = church_gold_mat
	tower_body.add_child(bell_roof)

	var bell := MeshInstance3D.new()
	var b_mesh := CylinderMesh.new()
	b_mesh.top_radius = 0.3
	b_mesh.bottom_radius = 0.75
	b_mesh.height = 1.1
	bell.mesh = b_mesh
	var bell_mat := StandardMaterial3D.new()
	bell_mat.albedo_color = Color(0.8, 0.6, 0.2, 1.0)
	bell_mat.metallic = 0.9
	bell_mat.roughness = 0.3
	bell.material_override = bell_mat
	bell.position = Vector3(0, 11.2, 0)
	tower_body.add_child(bell)

	# Cruz Solar Brilhante no topo da Torre
	var cross_v := MeshInstance3D.new()
	var cv_mesh := BoxMesh.new()
	cv_mesh.size = Vector3(0.35, 2.6, 0.35)
	cross_v.mesh = cv_mesh
	cross_v.material_override = church_solar_mat
	cross_v.position = Vector3(0, 14.5, 0)
	tower_body.add_child(cross_v)

	var cross_h := MeshInstance3D.new()
	var ch_mesh := BoxMesh.new()
	ch_mesh.size = Vector3(1.7, 0.35, 0.35)
	cross_h.mesh = ch_mesh
	cross_h.material_override = church_solar_mat
	cross_h.position = Vector3(0, 15.0, 0)
	tower_body.add_child(cross_h)

	var cross_light := OmniLight3D.new()
	cross_light.light_color = Color(1.0, 0.9, 0.45)
	cross_light.light_energy = 3.6
	cross_light.omni_range = 14.0
	cross_light.position = Vector3(0, 15.0, 0)
	tower_body.add_child(cross_light)

	# Altar Dourado no Interior da Igreja
	var altar_body := StaticBody3D.new()
	altar_body.name = "ChurchGoldenAltar"
	altar_body.position = Vector3(0.0, 0.0, -c_size.z / 2.0 + 2.2)
	altar_body.collision_layer = 1
	altar_body.collision_mask = 0
	church_root.add_child(altar_body)

	var a_col := CollisionShape3D.new()
	var a_box := BoxShape3D.new()
	a_box.size = Vector3(3.4, 1.2, 1.6)
	a_col.shape = a_box
	a_col.position = Vector3(0, 0.6, 0)
	altar_body.add_child(a_col)

	var a_mesh := MeshInstance3D.new()
	var a_bmesh := BoxMesh.new()
	a_bmesh.size = Vector3(3.4, 1.2, 1.6)
	a_mesh.mesh = a_bmesh
	a_mesh.position = Vector3(0, 0.6, 0)
	a_mesh.material_override = church_gold_mat
	altar_body.add_child(a_mesh)

	# Relíquia Solar Sagrada sobre o Altar
	var sacred_relic := MeshInstance3D.new()
	var sr_mesh := SphereMesh.new()
	sr_mesh.radius = 0.32
	sr_mesh.height = 0.64
	sacred_relic.mesh = sr_mesh
	sacred_relic.material_override = church_solar_mat
	sacred_relic.position = Vector3(0, 1.5, 0)
	altar_body.add_child(sacred_relic)

	var altar_light := OmniLight3D.new()
	altar_light.light_color = Color(1.0, 0.85, 0.35)
	altar_light.light_energy = 3.2
	altar_light.omni_range = 9.0
	altar_light.position = Vector3(0, 2.2, 0)
	altar_body.add_child(altar_light)

	# Bancos de Oração de Madeira
	for b_z in [-1.5, 1.2, 3.8]:
		_create_furniture_piece(church_root, Vector3(-2.4, 0.45, b_z), Vector3(2.4, 0.8, 0.7), Color(0.3, 0.2, 0.12))
		_create_furniture_piece(church_root, Vector3(2.4, 0.45, b_z), Vector3(2.4, 0.8, 0.7), Color(0.3, 0.2, 0.12))

	# Porta Interativa da Igreja (Tecla E)
	_create_interactive_door(landmarks_root, "holy_light_church", "Igreja da Luz Sagrada", Vector3(-20.0, 0.0, -11.0), Vector3(-20.0, 0.0, -8.8), Vector3(-20.0, 0.0, -13.5), true)

	# =========================================================================
	# 2. 🔮 TORRE ARCANA (TORRE DO MAGO) EM (20, 0, -18)
	# =========================================================================
	var tower_root := Node3D.new()
	tower_root.name = "ArcaneMageTower"
	tower_root.position = Vector3(20.0, 0.0, -18.0)
	landmarks_root.add_child(tower_root)

	var mage_stone_mat := StandardMaterial3D.new()
	mage_stone_mat.albedo_color = Color(0.106, 0.149, 0.231, 1.0) # #1B263B Azul-escuro
	mage_stone_mat.roughness = 0.65
	mage_stone_mat.metallic = 0.25

	var mage_gold_mat := StandardMaterial3D.new()
	mage_gold_mat.albedo_color = Color(1.0, 0.84, 0.1, 1.0) # Anéis mágicos dourados
	mage_gold_mat.emission_enabled = true
	mage_gold_mat.emission = Color(1.0, 0.84, 0.1)
	mage_gold_mat.emission_energy_multiplier = 3.5

	var mage_cyan_mat := StandardMaterial3D.new()
	mage_cyan_mat.albedo_color = Color(0.0, 0.94, 1.0, 1.0) # Cristais ciano luminosos
	mage_cyan_mat.emission_enabled = true
	mage_cyan_mat.emission = Color(0.0, 0.94, 1.0)
	mage_cyan_mat.emission_energy_multiplier = 4.2

	# Corpo Cilíndrico Alto (14 metros de altura)
	var tower_mesh := MeshInstance3D.new()
	var tm_cyl := CylinderMesh.new()
	tm_cyl.top_radius = 3.6
	tm_cyl.bottom_radius = 4.0
	tm_cyl.height = 14.0
	tower_mesh.mesh = tm_cyl
	tower_mesh.material_override = mage_stone_mat
	tower_mesh.position = Vector3(0, 7.0, 0)
	tower_root.add_child(tower_mesh)

	# Colisão Sólida Perimetral (StaticBody3D com BoxShape3D em formato octogonal)
	var tower_col_body := StaticBody3D.new()
	tower_col_body.name = "MageTowerCollision"
	tower_col_body.collision_layer = 1
	tower_col_body.collision_mask = 0
	tower_root.add_child(tower_col_body)

	for angle_deg in [45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		var rad := deg_to_rad(angle_deg)
		var c_col := CollisionShape3D.new()
		var c_box := BoxShape3D.new()
		c_box.size = Vector3(3.0, 14.0, 1.0)
		c_col.shape = c_box
		c_col.position = Vector3(sin(rad) * 3.7, 7.0, cos(rad) * 3.7)
		c_col.rotation.y = rad
		tower_col_body.add_child(c_col)

	# Telhado Cônico / Pináculo Arcano no topo (Y = 14m a 18.5m)
	var spire_mesh := MeshInstance3D.new()
	var sm_cone := CylinderMesh.new()
	sm_cone.top_radius = 0.1
	sm_cone.bottom_radius = 4.1
	sm_cone.height = 4.5
	spire_mesh.mesh = sm_cone
	spire_mesh.material_override = mage_stone_mat
	spire_mesh.position = Vector3(0, 16.25, 0)
	tower_root.add_child(spire_mesh)

	# 2 Anéis Dourados Mágicos flutuando no topo
	# Anel 1 em Y = 15.0m
	var ring_1 := MeshInstance3D.new()
	var r1_mesh := CylinderMesh.new()
	r1_mesh.top_radius = 4.4
	r1_mesh.bottom_radius = 4.4
	r1_mesh.height = 0.22
	ring_1.mesh = r1_mesh
	ring_1.material_override = mage_gold_mat
	ring_1.position = Vector3(0, 15.0, 0)
	ring_1.rotation.x = deg_to_rad(12.0)
	tower_root.add_child(ring_1)

	# Anel 2 em Y = 16.5m
	var ring_2 := MeshInstance3D.new()
	var r2_mesh := CylinderMesh.new()
	r2_mesh.top_radius = 3.6
	r2_mesh.bottom_radius = 3.6
	r2_mesh.height = 0.22
	ring_2.mesh = r2_mesh
	ring_2.material_override = mage_gold_mat
	ring_2.position = Vector3(0, 16.5, 0)
	ring_2.rotation.z = deg_to_rad(-14.0)
	tower_root.add_child(ring_2)

	# Cristais Ciano Luminosos (4 cristais orbitando a torre em Y = 7.0m)
	for c_angle in [0.0, 90.0, 180.0, 270.0]:
		var cr_rad := deg_to_rad(c_angle)
		var c_pos := Vector3(sin(cr_rad) * 4.9, 7.0, cos(cr_rad) * 4.9)

		var crystal := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.42
		cm.height = 1.9
		crystal.mesh = cm
		crystal.material_override = mage_cyan_mat
		crystal.position = c_pos
		tower_root.add_child(crystal)

		var c_light := OmniLight3D.new()
		c_light.light_color = Color(0.1, 0.95, 1.0)
		c_light.light_energy = 2.6
		c_light.omni_range = 8.0
		c_light.position = c_pos
		tower_root.add_child(c_light)

	# Interior Arcano: Bancada de Poções, Estante de Livros e Orbe Místico
	_create_furniture_piece(tower_root, Vector3(-1.8, 0.8, -1.5), Vector3(1.2, 1.6, 2.4), Color(0.2, 0.15, 0.25))
	_create_furniture_piece(tower_root, Vector3(1.8, 0.8, -1.5), Vector3(1.2, 1.6, 2.4), Color(0.15, 0.2, 0.3))

	var orb := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.4
	om.height = 0.8
	orb.mesh = om
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.8, 0.2, 1.0, 1.0)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.8, 0.2, 1.0)
	orb_mat.emission_energy_multiplier = 4.0
	orb.material_override = orb_mat
	orb.position = Vector3(0, 1.6, 0)
	tower_root.add_child(orb)

	var orb_light := OmniLight3D.new()
	orb_light.light_color = Color(0.7, 0.3, 1.0)
	orb_light.light_energy = 3.2
	orb_light.omni_range = 7.5
	orb_light.position = Vector3(0, 2.0, 0)
	tower_root.add_child(orb_light)

	# Porta Interativa da Torre do Mago (Tecla E)
	_create_interactive_door(landmarks_root, "mage_tower", "Torre Arcana do Mago", Vector3(20.0, 0.0, -14.2), Vector3(20.0, 0.0, -12.4), Vector3(20.0, 0.0, -16.2), true)

	# =========================================================================
	# 3. 🏹 POSTO DO CAÇADOR EM (34, 0, -30)
	# =========================================================================
	var hunter_root := Node3D.new()
	hunter_root.name = "HunterPost"
	hunter_root.position = Vector3(34.0, 0.0, -30.0)
	landmarks_root.add_child(hunter_root)

	var wood_cabin_mat := StandardMaterial3D.new()
	wood_cabin_mat.albedo_color = Color(0.32, 0.20, 0.12, 1.0) # Madeira rústica
	wood_cabin_mat.roughness = 0.85

	var roof_bark_mat := StandardMaterial3D.new()
	roof_bark_mat.albedo_color = Color(0.20, 0.14, 0.08, 1.0) # Telhado rústico
	roof_bark_mat.roughness = 0.9

	# Cabana Rústica de Madeira (7.4m x 3.8m x 6.4m)
	_create_solid_building(hunter_root, "HunterCabin", Vector3.ZERO, Vector3(7.4, 3.8, 6.4), wood_cabin_mat.albedo_color, roof_bark_mat.albedo_color, "Posto do Caçador", Color(0.9, 0.8, 0.4), "north")

	# Alvos de Treino de Tiro com Arco em (38, 0, -28) e (38, 0, -32)
	for t_offset_z in [2.0, -2.0]:
		var target_body := StaticBody3D.new()
		target_body.position = Vector3(5.2, 0.0, t_offset_z)
		target_body.collision_layer = 1
		target_body.collision_mask = 0
		hunter_root.add_child(target_body)

		var tgt_col := CollisionShape3D.new()
		var tgt_box := BoxShape3D.new()
		tgt_box.size = Vector3(0.6, 2.2, 1.6)
		tgt_col.shape = tgt_box
		tgt_col.position = Vector3(0, 1.1, 0)
		target_body.add_child(tgt_col)

		# Cavalete de Madeira
		var stand := MeshInstance3D.new()
		var st_mesh := BoxMesh.new()
		st_mesh.size = Vector3(0.4, 2.0, 0.15)
		stand.mesh = st_mesh
		stand.material_override = wood_cabin_mat
		stand.position = Vector3(0, 1.0, 0)
		target_body.add_child(stand)

		# Alvo Circular com círculos concêntricos
		var disc := MeshInstance3D.new()
		var dc_mesh := CylinderMesh.new()
		dc_mesh.top_radius = 0.75
		dc_mesh.bottom_radius = 0.75
		dc_mesh.height = 0.12
		disc.mesh = dc_mesh
		var disc_mat := StandardMaterial3D.new()
		disc_mat.albedo_color = Color(0.9, 0.85, 0.7, 1.0) # Palha clara
		disc.material_override = disc_mat
		disc.position = Vector3(0, 1.4, 0)
		disc.rotation.z = deg_to_rad(90.0)
		target_body.add_child(disc)

		# Bullseye Vermelho
		var bullseye := MeshInstance3D.new()
		var be_mesh := CylinderMesh.new()
		be_mesh.top_radius = 0.3
		be_mesh.bottom_radius = 0.3
		be_mesh.height = 0.14
		bullseye.mesh = be_mesh
		var be_mat := StandardMaterial3D.new()
		be_mat.albedo_color = Color(0.85, 0.15, 0.15, 1.0)
		bullseye.material_override = be_mat
		bullseye.position = Vector3(-0.02, 1.4, 0)
		bullseye.rotation.z = deg_to_rad(90.0)
		target_body.add_child(bullseye)

	# Fogueira Acesa em frente ao Posto (Z = +4.2m relativo à cabana)
	var campfire_body := StaticBody3D.new()
	campfire_body.name = "HunterCampfire"
	campfire_body.position = Vector3(-3.2, 0.0, 4.2)
	campfire_body.collision_layer = 1
	campfire_body.collision_mask = 0
	hunter_root.add_child(campfire_body)

	var cf_col := CollisionShape3D.new()
	var cf_box := BoxShape3D.new()
	cf_box.size = Vector3(1.6, 0.5, 1.6)
	cf_col.shape = cf_box
	cf_col.position = Vector3(0, 0.25, 0)
	campfire_body.add_child(cf_col)

	# Anel de Pedras da Fogueira
	var stones_mesh := MeshInstance3D.new()
	var st_cyl := CylinderMesh.new()
	st_cyl.top_radius = 0.85
	st_cyl.bottom_radius = 0.95
	st_cyl.height = 0.3
	stones_mesh.mesh = st_cyl
	var st_mat := StandardMaterial3D.new()
	st_mat.albedo_color = Color(0.3, 0.3, 0.32, 1.0)
	stones_mesh.material_override = st_mat
	stones_mesh.position = Vector3(0, 0.15, 0)
	campfire_body.add_child(stones_mesh)

	# Brasas e Madeira Ardente
	var embers_mesh := MeshInstance3D.new()
	var emb_box := BoxMesh.new()
	emb_box.size = Vector3(0.9, 0.25, 0.9)
	embers_mesh.mesh = emb_box
	var emb_mat := StandardMaterial3D.new()
	emb_mat.albedo_color = Color(1.0, 0.45, 0.05, 1.0)
	emb_mat.emission_enabled = true
	emb_mat.emission = Color(1.0, 0.45, 0.05)
	emb_mat.emission_energy_multiplier = 4.0
	embers_mesh.material_override = emb_mat
	embers_mesh.position = Vector3(0, 0.2, 0)
	campfire_body.add_child(embers_mesh)

	# Partículas de Fogo
	var fire_cpu := CPUParticles3D.new()
	fire_cpu.position = Vector3(0, 0.35, 0)
	fire_cpu.amount = 25
	fire_cpu.lifetime = 0.8
	fire_cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire_cpu.emission_box_extents = Vector3(0.3, 0.1, 0.3)
	fire_cpu.direction = Vector3(0, 1, 0)
	fire_cpu.spread = 15.0
	fire_cpu.initial_velocity_min = 1.4
	fire_cpu.initial_velocity_max = 2.4
	fire_cpu.scale_amount_min = 0.1
	fire_cpu.scale_amount_max = 0.25
	fire_cpu.color = Color(1.0, 0.6, 0.1, 0.9)
	var cf_pmat := StandardMaterial3D.new()
	cf_pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cf_pmat.albedo_color = Color(1.0, 0.5, 0.1, 1.0)
	var cf_smesh := SphereMesh.new()
	cf_smesh.radius = 0.1
	cf_smesh.height = 0.2
	cf_smesh.material = cf_pmat
	fire_cpu.mesh = cf_smesh
	campfire_body.add_child(fire_cpu)

	var cf_light := OmniLight3D.new()
	cf_light.light_color = Color(1.0, 0.58, 0.15)
	cf_light.light_energy = 3.5
	cf_light.omni_range = 8.5
	cf_light.position = Vector3(0, 0.9, 0)
	campfire_body.add_child(cf_light)

	# Porta Interativa da Cabana do Caçador (Tecla E)
	_create_interactive_door(landmarks_root, "hunter_post", "Posto do Caçador", Vector3(34.0, 0.0, -26.8), Vector3(34.0, 0.0, -25.2), Vector3(34.0, 0.0, -28.8), true)

	# =========================================================================
	# 4. 🌑 SANTUÁRIO DO ECLIPSE EM (-85, 0, 85)
	# =========================================================================
	var sanctuary_root := Node3D.new()
	sanctuary_root.name = "EclipseSanctuaryLandmark"
	sanctuary_root.position = Vector3(-85.0, 0.0, 85.0)
	landmarks_root.add_child(sanctuary_root)

	var obs_mat := StandardMaterial3D.new()
	obs_mat.albedo_color = Color(0.08, 0.06, 0.10, 1.0) # Obsidiana negra
	obs_mat.metallic = 0.88
	obs_mat.roughness = 0.22

	var crimson_rune_mat := StandardMaterial3D.new()
	crimson_rune_mat.albedo_color = Color(1.0, 0.05, 0.12, 1.0) # Runas vermelhas brilhantes
	crimson_rune_mat.emission_enabled = true
	crimson_rune_mat.emission = Color(1.0, 0.05, 0.12)
	crimson_rune_mat.emission_energy_multiplier = 4.8

	var black_void_mat := StandardMaterial3D.new()
	black_void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black_void_mat.albedo_color = Color(0.01, 0.01, 0.01, 1.0) # Sol Negro Absoluto

	var halo_crimson_mat := StandardMaterial3D.new()
	halo_crimson_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_crimson_mat.albedo_color = Color(1.0, 0.08, 0.15, 1.0) # Halo Carmesim do Eclipse
	halo_crimson_mat.emission_enabled = true
	halo_crimson_mat.emission = Color(1.0, 0.08, 0.15)
	halo_crimson_mat.emission_energy_multiplier = 5.5

	# Arena Gótica de Obsidiana Negra (28x28m)
	var arena_floor_body := StaticBody3D.new()
	arena_floor_body.name = "SanctuaryArenaFloor"
	arena_floor_body.collision_layer = 1
	arena_floor_body.collision_mask = 0
	sanctuary_root.add_child(arena_floor_body)

	var af_col := CollisionShape3D.new()
	var af_box := BoxShape3D.new()
	af_box.size = Vector3(28.0, 0.4, 28.0)
	af_col.shape = af_box
	af_col.position = Vector3(0, 0.2, 0)
	arena_floor_body.add_child(af_col)

	var af_mesh := MeshInstance3D.new()
	var af_bmesh := BoxMesh.new()
	af_bmesh.size = Vector3(28.0, 0.4, 28.0)
	af_mesh.mesh = af_bmesh
	af_mesh.material_override = obs_mat
	af_mesh.position = Vector3(0, 0.2, 0)
	arena_floor_body.add_child(af_mesh)

	# Muretas góticas de borda da Arena (28x28m) com entrada aberta de 6m em Z = -14.0
	# Mureta Leste (X = +14.0)
	_add_wall_piece(arena_floor_body, Vector3(14.0, 1.0, 0.0), Vector3(1.0, 1.6, 28.0), obs_mat)
	# Mureta Oeste (X = -14.0)
	_add_wall_piece(arena_floor_body, Vector3(-14.0, 1.0, 0.0), Vector3(1.0, 1.6, 28.0), obs_mat)
	# Mureta Sul (Z = +14.0)
	_add_wall_piece(arena_floor_body, Vector3(0.0, 1.0, 14.0), Vector3(28.0, 1.6, 1.0), obs_mat)
	# Mureta Norte (Z = -14.0) com abertura de 6m
	_add_wall_piece(arena_floor_body, Vector3(-8.5, 1.0, -14.0), Vector3(11.0, 1.6, 1.0), obs_mat)
	_add_wall_piece(arena_floor_body, Vector3(8.5, 1.0, -14.0), Vector3(11.0, 1.6, 1.0), obs_mat)

	# 8 Pilares Monolíticos com Runas Vermelhas Brilhantes (Raio de 11.5m em volta do centro)
	for p_idx in range(8):
		var p_angle := p_idx * (PI / 4.0)
		var p_pos := Vector3(cos(p_angle) * 11.5, 0.0, sin(p_angle) * 11.5)

		var pillar_body := StaticBody3D.new()
		pillar_body.name = "EclipsePillar_%d" % p_idx
		pillar_body.position = p_pos
		pillar_body.collision_layer = 1
		pillar_body.collision_mask = 0
		sanctuary_root.add_child(pillar_body)

		var p_col := CollisionShape3D.new()
		var p_shape := BoxShape3D.new()
		p_shape.size = Vector3(1.6, 7.5, 1.6)
		p_col.shape = p_shape
		p_col.position = Vector3(0, 3.75, 0)
		pillar_body.add_child(p_col)

		var p_mesh := MeshInstance3D.new()
		var p_bmesh := BoxMesh.new()
		p_bmesh.size = Vector3(1.6, 7.5, 1.6)
		p_mesh.mesh = p_bmesh
		p_mesh.material_override = obs_mat
		p_mesh.position = Vector3(0, 3.75, 0)
		pillar_body.add_child(p_mesh)

		# Runas Vermelhas Brilhantes gravadas no pilar
		var rune_1 := MeshInstance3D.new()
		var r1_b := BoxMesh.new()
		r1_b.size = Vector3(0.3, 5.2, 1.64)
		rune_1.mesh = r1_b
		rune_1.material_override = crimson_rune_mat
		rune_1.position = Vector3(0, 3.75, 0)
		pillar_body.add_child(rune_1)

		var rune_2 := MeshInstance3D.new()
		var r2_b := BoxMesh.new()
		r2_b.size = Vector3(1.64, 5.2, 0.3)
		rune_2.mesh = r2_b
		rune_2.material_override = crimson_rune_mat
		rune_2.position = Vector3(0, 3.75, 0)
		pillar_body.add_child(rune_2)

		var p_light := OmniLight3D.new()
		p_light.light_color = Color(1.0, 0.1, 0.15)
		p_light.light_energy = 2.4
		p_light.omni_range = 6.5
		p_light.position = Vector3(0, 7.6, 0)
		pillar_body.add_child(p_light)

	# Altar do Sacrifício em (-88, 0, 88) -> Relativo ao centro (-85, 0, 85) é (-3.0, 0, 3.0)
	var sac_altar := StaticBody3D.new()
	sac_altar.name = "SacrificialAltar"
	sac_altar.position = Vector3(-3.0, 0.0, 3.0)
	sac_altar.collision_layer = 1
	sac_altar.collision_mask = 0
	sanctuary_root.add_child(sac_altar)

	var sa_col := CollisionShape3D.new()
	var sa_box := BoxShape3D.new()
	sa_box.size = Vector3(3.2, 1.2, 2.0)
	sa_col.shape = sa_box
	sa_col.position = Vector3(0, 0.6, 0)
	sac_altar.add_child(sa_col)

	var sa_mesh := MeshInstance3D.new()
	var sa_bmesh := BoxMesh.new()
	sa_bmesh.size = Vector3(3.2, 1.2, 2.0)
	sa_mesh.mesh = sa_bmesh
	sa_mesh.material_override = obs_mat
	sa_mesh.position = Vector3(0, 0.6, 0)
	sac_altar.add_child(sa_mesh)

	# Inlay de sangue rúnico no topo do altar
	var blood_rune := MeshInstance3D.new()
	var br_box := BoxMesh.new()
	br_box.size = Vector3(2.6, 0.05, 1.4)
	blood_rune.mesh = br_box
	blood_rune.material_override = crimson_rune_mat
	blood_rune.position = Vector3(0, 1.23, 0)
	sac_altar.add_child(blood_rune)

	var sa_light := OmniLight3D.new()
	sa_light.light_color = Color(1.0, 0.05, 0.1)
	sa_light.light_energy = 3.6
	sa_light.omni_range = 7.5
	sa_light.position = Vector3(0, 1.8, 0)
	sac_altar.add_child(sa_light)

	# Sol Negro Eclipsado flutuando no céu em (-85, 18, 85) -> Relativo: (0, 18, 0)
	# SphereMesh negra de raio 3.5m (altura 7.0m)
	var black_sun := MeshInstance3D.new()
	black_sun.name = "BlackSunEclipsed"
	var bs_sphere := SphereMesh.new()
	bs_sphere.radius = 3.5
	bs_sphere.height = 7.0
	black_sun.mesh = bs_sphere
	black_sun.material_override = black_void_mat
	black_sun.position = Vector3(0, 18.0, 0)
	sanctuary_root.add_child(black_sun)

	# Halo Vermelho-Carmesim Brilhante em volta do Sol Negro
	var sun_halo := MeshInstance3D.new()
	sun_halo.name = "SunCrimsonHalo"
	var sh_cyl := CylinderMesh.new()
	sh_cyl.top_radius = 4.4
	sh_cyl.bottom_radius = 4.4
	sh_cyl.height = 0.25
	sun_halo.mesh = sh_cyl
	sun_halo.material_override = halo_crimson_mat
	sun_halo.position = Vector3(0, 18.0, 0)
	sanctuary_root.add_child(sun_halo)

	# Halo Externo Difuso Carmesim
	var sun_halo_outer := MeshInstance3D.new()
	var sho_cyl := CylinderMesh.new()
	sho_cyl.top_radius = 5.2
	sho_cyl.bottom_radius = 5.2
	sho_cyl.height = 0.15
	sun_halo_outer.mesh = sho_cyl
	var sho_mat := StandardMaterial3D.new()
	sho_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sho_mat.albedo_color = Color(0.8, 0.05, 0.15, 0.6)
	sho_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sun_halo_outer.material_override = sho_mat
	sun_halo_outer.position = Vector3(0, 18.0, 0)
	sanctuary_root.add_child(sun_halo_outer)

	# Luz imensa carmesim do eclipse sobre toda a arena
	var sun_light := OmniLight3D.new()
	sun_light.light_color = Color(1.0, 0.08, 0.12)
	sun_light.light_energy = 5.0
	sun_light.omni_range = 38.0
	sun_light.position = Vector3(0, 18.0, 0)
	sanctuary_root.add_child(sun_light)

	# Portal e Entrada Interativa do Santuário (Tecla E)
	_create_interactive_door(landmarks_root, "eclipse_sanctuary", "Santuário do Eclipse (Arena de Raid)", Vector3(-85.0, 0.0, 71.0), Vector3(-85.0, 0.0, 68.0), Vector3(-85.0, 0.0, 74.0), true)


