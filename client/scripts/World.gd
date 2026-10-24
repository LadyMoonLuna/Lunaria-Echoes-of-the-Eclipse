extends Node3D

const LunariaTerrain = preload("res://scripts/world/Terrain.gd")
const LunariaWorldBuilder = preload("res://scripts/world/WorldBuilder.gd")
const LunariaWorldData = preload("res://scripts/world/WorldData.gd")
const LunariaUI = preload("res://scripts/ui/LunariaUI.gd")

@export var local_player_scene: PackedScene = preload("res://scenes/LocalPlayer.tscn")
@export var remote_player_scene: PackedScene = preload("res://scenes/RemotePlayer.tscn")
@export var npc_scene: PackedScene = preload("res://scenes/NPC.tscn")
const MobEntityScript = preload("res://scripts/MobEntity.gd")
const LunariaTextures = preload("res://scripts/models/LunariaTextures.gd")
const CharacterSelectUIScript = preload("res://scripts/CharacterSelectUI.gd")
const AttributesUIScript = preload("res://scripts/AttributesUI.gd")
const InventoryUIScript = preload("res://scripts/InventoryUI.gd")
const EntityOfferUIScript = preload("res://scripts/EntityOfferUI.gd")
const SkillsUIScript = preload("res://scripts/SkillsUI.gd")
const ClassMasterUIScript = preload("res://scripts/ClassMasterUI.gd")
const DevDropRatesUIScript = preload("res://scripts/DevDropRatesUI.gd")
const AutopsyUIScript = preload("res://scripts/AutopsyUI.gd")
const CorpseEntityScript = preload("res://scripts/CorpseEntity.gd")
const NPCEntityScript = preload("res://scripts/NPCEntity.gd")

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
var npc_friendships: Dictionary = {}
var mobs: Dictionary = {}
var mobs_container: Node3D = null
var projectiles_container: Node3D = null
var active_projectiles: Dictionary = {}
var corpses: Dictionary = {}
var corpses_container: Node3D = null
var char_select_ui: CanvasLayer = null
var attributes_ui: CanvasLayer = null
var inventory_ui: CanvasLayer = null
var forge_ui: CanvasLayer = null
const ForgeUIScript = preload("res://scripts/forge/ForgeUI.gd")
const ForgeDataRef = preload("res://scripts/forge/ForgeData.gd")
const FORGE_ANVIL_REACH := 2.4
var entity_offer_ui: CanvasLayer = null
var skills_ui: CanvasLayer = null
var class_master_ui: CanvasLayer = null
var dev_drop_rates_ui: CanvasLayer = null
var dev_manager_ui: Control = null
var dev_manager_node = null
var dev_race_menu_ui = null
var dev_canvas_layer: CanvasLayer = null
var dev_manager_panel: PanelContainer = null
var dev_btn_top: Button = null
var dev_status_label: Label = null
var dev_selected_tier: int = 1
var dev_tier_buttons: Array[Button] = []
var dev_selected_path: int = 0 # Caminho Evolutivo enviado pelo Dev Manager (0 = manter)
var dev_path_buttons: Array[Button] = []
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
# Eventos do menu DEV (servidor: protocol.DevEvent*)
const DEV_WORLD_EVENTS := [
	[1, "🏜️ Secar a Fonte", Color(0.75, 0.55, 0.25)], [2, "💧 Encher a Fonte", Color(0.25, 0.5, 0.8)],
	[8, "🌵 Secar Poças", Color(0.7, 0.5, 0.2)], [9, "🌊 Encher Poças", Color(0.2, 0.55, 0.75)],
	[3, "🤧 Surto de Gripe da Bruma", Color(0.5, 0.65, 0.75)], [4, "🤢 Surto de Disenteria", Color(0.55, 0.6, 0.3)],
	[5, "☠️ Peste Cinzenta", Color(0.45, 0.45, 0.45)], [6, "✨ Curar Todas as Doenças", Color(0.9, 0.85, 0.4)],
	[7, "🧟 Zumbi ao Meu Lado", Color(0.4, 0.6, 0.3)], [10, "🍖 Saciar Fome e Aquecer", Color(0.85, 0.55, 0.25)],
	[11, "🍽️ Ficar Faminto", Color(0.6, 0.35, 0.2)], [12, "🥶 Quase Congelando", Color(0.4, 0.7, 0.95)],
]

const WEATHER_NAMES := ["Limpo", "Chuva", "Neblina Densa", "Névoa Carmesim", "Neve", "Nevasca",
	"Tempestade de Raios", "Garoa", "Granizo", "Tempestade de Areia", "Chuva de Cinzas",
	"Onda de Calor", "Vendaval", "Aurora Boreal", "Chuva de Meteoros", "Chuva Ácida",
	"Pétalas ao Vento", "Noite de Vaga-lumes", "Miasma Violeta", "Arco-Íris",
	"Nevoeiro de Esporos", "Tempestade Arcana", "Geada Cristalina", "Monção"]
const WEATHER_ICONS := ["☀️", "🌧️", "🌫️", "🩸", "❄️", "🌨️", "⛈️", "🌦️", "🧊", "🏜️", "🌋", "🔥",
	"🌬️", "🌌", "☄️", "☣️", "🌸", "✨", "🟣", "🌈", "🍄", "🔮", "💎", "🌊"]
# Efeitos visuais por clima: densidade/cor da névoa, multiplicador de luz do dia,
# tom do ambiente e do horizonte, chuva (intensidade 0..2) e partícula extra.
const WEATHER_FX := {
	0: {"fog": 0.0001, "fog_col": Color("#758596"), "light": 1.0},
	1: {"fog": 0.018, "fog_col": Color("#4a5868"), "light": 0.7, "amb": Color(0.3, 0.35, 0.4), "rain": 1.0},
	2: {"fog": 0.055, "fog_col": Color("#758596"), "light": 0.6, "amb": Color(0.4, 0.42, 0.46), "horiz": Color(0.45, 0.48, 0.52)},
	3: {"fog": 0.05, "fog_col": Color("#771515"), "light": 0.9, "amb": Color(0.5, 0.15, 0.15), "horiz": Color(0.8, 0.18, 0.18)},
	4: {"fog": 0.012, "fog_col": Color("#dfe7f2"), "light": 0.85, "amb": Color(0.75, 0.8, 0.9), "horiz": Color(0.85, 0.88, 0.95), "fx": "snow"},
	5: {"fog": 0.06, "fog_col": Color("#e8eef7"), "light": 0.55, "amb": Color(0.8, 0.85, 0.95), "horiz": Color(0.9, 0.92, 0.97), "fx": "blizzard"},
	6: {"fog": 0.025, "fog_col": Color("#2f3644"), "light": 0.4, "amb": Color(0.2, 0.22, 0.3), "horiz": Color(0.2, 0.22, 0.3), "rain": 2.0, "flash": true},
	7: {"fog": 0.008, "fog_col": Color("#7d8a99"), "light": 0.85, "amb": Color(0.45, 0.5, 0.55), "rain": 0.35},
	8: {"fog": 0.015, "fog_col": Color("#9aa7b5"), "light": 0.6, "amb": Color(0.5, 0.55, 0.62), "fx": "hail"},
	9: {"fog": 0.07, "fog_col": Color("#c49a5a"), "light": 0.6, "amb": Color(0.7, 0.55, 0.35), "horiz": Color(0.85, 0.65, 0.4), "fx": "sand"},
	10: {"fog": 0.035, "fog_col": Color("#4b4040"), "light": 0.5, "amb": Color(0.4, 0.3, 0.28), "horiz": Color(0.55, 0.3, 0.2), "fx": "ash"},
	11: {"fog": 0.01, "fog_col": Color("#e0b070"), "light": 1.3, "amb": Color(0.9, 0.7, 0.45), "horiz": Color(1.0, 0.75, 0.45)},
	12: {"fog": 0.006, "fog_col": Color("#9fb0b8"), "light": 0.9, "fx": "leaves"},
	13: {"fog": 0.002, "fog_col": Color("#2a6a5a"), "light": 1.0, "night_amb": Color(0.1, 0.35, 0.3), "night_horiz": Color(0.15, 0.6, 0.45)},
	14: {"fog": 0.001, "fog_col": Color("#202040"), "light": 1.0, "night_horiz": Color(0.3, 0.2, 0.45), "fx": "meteors"},
	15: {"fog": 0.02, "fog_col": Color("#6b7a2a"), "light": 0.65, "amb": Color(0.45, 0.5, 0.2), "horiz": Color(0.55, 0.6, 0.25), "rain": 1.0},
	16: {"fog": 0.004, "fog_col": Color("#f2c6d8"), "light": 1.05, "amb": Color(0.9, 0.75, 0.8), "fx": "petals"},
	17: {"fog": 0.004, "fog_col": Color("#1b2a1a"), "light": 1.0, "night_amb": Color(0.12, 0.16, 0.08), "fx": "fireflies"},
	18: {"fog": 0.04, "fog_col": Color("#5a2a6e"), "light": 0.6, "amb": Color(0.4, 0.2, 0.5), "horiz": Color(0.5, 0.25, 0.6), "fx": "miasma"},
	19: {"fog": 0.002, "fog_col": Color("#b0d0f0"), "light": 1.2, "amb": Color(0.75, 0.8, 0.9), "horiz": Color(0.7, 0.85, 1.0)},
	20: {"fog": 0.045, "fog_col": Color("#8a9a5a"), "light": 0.7, "amb": Color(0.5, 0.55, 0.35), "fx": "spores"},
	21: {"fog": 0.02, "fog_col": Color("#3a2a8a"), "light": 0.55, "amb": Color(0.3, 0.25, 0.7), "horiz": Color(0.45, 0.3, 0.9), "fx": "arcane", "flash": true},
	22: {"fog": 0.01, "fog_col": Color("#bfe6ff"), "light": 1.1, "amb": Color(0.7, 0.85, 1.0), "horiz": Color(0.75, 0.9, 1.0), "fx": "crystals"},
	23: {"fog": 0.04, "fog_col": Color("#38485a"), "light": 0.45, "amb": Color(0.25, 0.3, 0.38), "horiz": Color(0.3, 0.35, 0.42), "rain": 2.5},
}
# Partículas: cor, quantidade, velocidade de queda, tamanho e deriva horizontal (vento).
const WEATHER_PARTICLES := {
	"snow": {"col": Color(1, 1, 1), "amount": 900, "speed": 2.0, "size": 0.12, "drift": Vector3(0.6, 0, 0.2), "life": 6.0},
	"blizzard": {"col": Color(0.95, 0.97, 1), "amount": 2200, "speed": 6.0, "size": 0.1, "drift": Vector3(9, 0, 3), "life": 3.0},
	"hail": {"col": Color(0.85, 0.92, 1), "amount": 700, "speed": 20.0, "size": 0.15, "drift": Vector3.ZERO, "life": 1.0},
	"sand": {"col": Color(0.85, 0.65, 0.4), "amount": 2000, "speed": 0.5, "size": 0.08, "drift": Vector3(14, 0, 4), "life": 3.0, "low": true},
	"ash": {"col": Color(0.25, 0.22, 0.22), "amount": 1200, "speed": 1.5, "size": 0.1, "drift": Vector3(1, 0, 0.5), "life": 7.0, "glow": Color(1.0, 0.4, 0.1)},
	"leaves": {"col": Color(0.45, 0.6, 0.25), "amount": 500, "speed": 1.5, "size": 0.18, "drift": Vector3(12, 0, 2), "life": 4.0},
	"meteors": {"col": Color(1.0, 0.85, 0.5), "amount": 40, "speed": 45.0, "size": 0.35, "drift": Vector3(25, 0, 10), "life": 1.4, "emissive": true, "high": true},
	"petals": {"col": Color(1.0, 0.7, 0.82), "amount": 500, "speed": 1.0, "size": 0.14, "drift": Vector3(2.5, 0, 1), "life": 8.0},
	"fireflies": {"col": Color(0.85, 1.0, 0.35), "amount": 350, "speed": 0.0, "size": 0.1, "drift": Vector3.ZERO, "life": 5.0, "emissive": true, "low": true, "wander": true},
	"miasma": {"col": Color(0.6, 0.3, 0.8), "amount": 500, "speed": -0.3, "size": 0.35, "drift": Vector3(0.3, 0, 0.3), "life": 6.0, "low": true, "emissive": true, "wander": true},
	"spores": {"col": Color(0.85, 0.9, 0.55), "amount": 900, "speed": -0.2, "size": 0.09, "drift": Vector3(0.4, 0, 0.2), "life": 8.0, "low": true, "emissive": true, "wander": true},
	"arcane": {"col": Color(0.6, 0.45, 1.0), "amount": 600, "speed": 3.0, "size": 0.12, "drift": Vector3(0, 0, 0), "life": 3.0, "emissive": true, "wander": true},
	"crystals": {"col": Color(0.8, 0.95, 1.0), "amount": 600, "speed": 0.6, "size": 0.07, "drift": Vector3(0.3, 0, 0.3), "life": 6.0, "emissive": true},
}
const RACE_NAMES := [
	"",
	"Valeriano",
	"Noctari",
	"Kharad",
	"Varkai",
	"Sangrael",
	"Lupharion",
	"Cinerion",
	"Seraphel",
	"Umbryss",
	"Runaric",
	"Solvaren",
	"Aetheris",
	"Selenarca",
	"Nyxara",
	"Runakhar",
	"Pyrokhar",
	"Dravarkai",
	"Ferovar",
	"Sylvari",
	"Myconid",
	"Aracne",
	"Ignivarn",
	"Chimeryth",
	"Borealin",
	"Thalassiano",
	"Cambion",
	"Nephilim",
	"Cronari",
	"Aurelith",
	"Pyrael",
	"Jotunar",
	"Terravyrn",
	"Hydravyrn",
	"Fulgravyrn",
	"Arcavyrn",
	"Orkhan",
	"Dvergar",
	"Elarin",
	"Solarin (Azgher)",
	"Lunarin (Tenebra)",
	"Faelith",
	"Gnarlin",
	"Escarion",
	"Testudar",
	"Lilitara",
	"Ulvar"
]
const ClassPaths = preload("res://scripts/ClassPaths.gd")

const CLASS_NAMES: Array = ClassPaths.CLASS_NAMES
const TIER_NAMES := ["Sem Classe", "Comum", "Incomum", "Rara", "Épica", "Única", "Lendária"]

const EVOLVED_CLASS_NAMES := {
	1: ["", "Espadachim da Aurora", "Guardião", "Bastião de Ferro", "Vanguarda Real", "Vanguarda Real", "Vanguarda Real"],
	2: ["", "Arcanista", "Arcanista do Véu", "Arquimago", "Tecelão do Eclipse", "Tecelão do Eclipse", "Tecelão do Eclipse"],
	3: ["", "Sentinela dos Ventos", "Patrulheiro", "Franco-Atirador", "Mestre Rastreador", "Mestre Rastreador", "Mestre Rastreador"],
	4: ["", "Lâmina Silente", "Lâmina Oculta", "Sombra Letal", "Mestre das Sombras", "Mestre das Sombras", "Mestre das Sombras"],
	5: ["", "Punho Celeste", "Monge Marcial", "Mestre do Chi", "Campeão de Um Punho", "Campeão de Um Punho", "Campeão de Um Punho"],
	6: ["", "Guardião do Bastião", "Guarda Paladino", "Bastião Inabalável", "Fortaleza Eterna", "Fortaleza Eterna", "Fortaleza Eterna"],
	7: ["", "Forjador de Estrelas", "Armeiro de Guerra", "Mestre da Bigorna", "Grão-Mestre Forjador", "Grão-Mestre Forjador", "Grão-Mestre Forjador"],
	8: ["", "Transmutador", "Boticário Tóxico", "Grão-Mestre Químico", "Mestre da Transmutação", "Mestre da Transmutação", "Mestre da Transmutação"],
	9: ["", "Escultor de Almas", "Entalhador Arcano", "Mestre do Luar", "Grande Escultor de Almas Divino", "Grande Escultor de Almas Divino", "Grande Escultor de Almas Divino"],
	10: ["", "Senhor das Feras", "Senhor das Feras", "Alfa da Matilha", "Grão-Mestre da Selva", "Grão-Mestre da Selva", "Grão-Mestre da Selva"],
	11: ["", "Tecelão Carmesim", "Tecelão de Aço", "Mestre Marionetista", "Tecelão da Realidade", "Tecelão da Realidade", "Tecelão da Realidade"],
	12: ["", "Mestre do Banquete", "Açougueiro de Monstros", "Mestre Culinário Feral", "Grão-Chef Supremo", "Grão-Chef Supremo", "Grão-Chef Supremo"],
	13: ["", "Lâmina Rúnica", "Lâmina Rúnica", "Lâmina Rúnica", "Lâmina Rúnica", "Lâmina Rúnica", "Lâmina Rúnica"],
	14: ["", "Inquisidor de Prata", "Inquisidor de Prata", "Inquisidor de Prata", "Inquisidor de Prata", "Inquisidor de Prata", "Inquisidor de Prata"],
	15: ["", "Valquíria Celeste", "Valquíria Celeste", "Valquíria Celeste", "Valquíria Celeste", "Valquíria Celeste", "Valquíria Celeste"],
	16: ["", "Punho Fantasma", "Punho Fantasma", "Punho Fantasma", "Punho Fantasma", "Punho Fantasma", "Punho Fantasma"],
	17: ["", "Forjador Carmesim", "Forjador Carmesim", "Forjador Carmesim", "Forjador Carmesim", "Forjador Carmesim", "Forjador Carmesim"],
	18: ["", "Doutor Corvo", "Doutor Corvo", "Doutor Corvo", "Doutor Corvo", "Doutor Corvo", "Doutor Corvo"],
	27: ["", "Ceifador da Lua Negra", "Ceifador da Lua Negra", "Ceifador da Lua Negra", "Ceifador da Lua Negra", "Ceifador da Lua Negra", "Soberano da Meia-Noite"],
	35: ["", "Engenheiro Rúnico", "Engenheiro Rúnico", "Engenheiro Rúnico", "Engenheiro Rúnico", "Engenheiro Rúnico", "Engenheiro Arcano Supremo"],
	36: ["", "Demiurgo Alquímico", "Demiurgo Alquímico", "Demiurgo Alquímico", "Demiurgo Alquímico", "Demiurgo Alquímico", "Demiurgo da Vida Sintética"],
	28: ["", "Bailarino das Estrelas", "Bailarino das Estrelas", "Bailarino das Estrelas", "Bailarino das Estrelas", "Bailarino das Estrelas", "Soberano das Constelações"],
	29: ["", "Inquisidor da Chama Branca", "Inquisidor da Chama Branca", "Inquisidor da Chama Branca", "Inquisidor da Chama Branca", "Inquisidor da Chama Branca", "Grão-Inquisidor das Chamas"],
	30: ["", "Arauto do Ossuário", "Arauto do Ossuário", "Arauto do Ossuário", "Arauto do Ossuário", "Arauto do Ossuário", "Lorde do Ossuário Eterno"],
	37: ["", "Senhor da Selva Primordial", "Senhor da Selva Primordial", "Senhor da Selva Primordial", "Senhor da Selva Primordial", "Senhor da Selva Primordial", "Avatar da Fera Ancestral"],
	38: ["", "Cavaleiro do Vazio", "Cavaleiro do Vazio", "Cavaleiro do Vazio", "Cavaleiro do Vazio", "Cavaleiro do Vazio", "Guardião da Singularidade"],
	39: ["", "Arauto do Trovão", "Arauto do Trovão", "Arauto do Trovão", "Arauto do Trovão", "Arauto do Trovão", "Soberano dos Relâmpagos"]
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
	1: { # Espadachim da Aurora
		"basic": "Corte de Espada",
		"q": "Corte Duplo",
		"r": "Investida Imparável",
		"f": "Julgamento da Espada",
		"basic_desc": "Golpe veloz de espada com +15% Defesa Física e +10% Dano com Espadas.",
		"q_desc": "1.8x dano em arco frontal aplicando sangramento contínuo.",
		"r_desc": "Dash frontal de 6m que empurra inimigos e quebra postura.",
		"f_desc": "2.6x dano sísmico em área de 4.5m (+40% dano em alvos com <35% HP)."
	},
	2: { # Arcanista
		"basic": "Orbe Arcano",
		"q": "Orbe de Magma",
		"r": "Prisão Glacial",
		"f": "Chuva de Meteoros",
		"basic_desc": "Projétil arcano (+20% Dano Mágico e regeneração contínua de Mana).",
		"q_desc": "Projétil explosivo a 18m causando 1.9x dano de fogo em área.",
		"r_desc": "Congela e empurra inimigos em 5m por 2s.",
		"f_desc": "2.8x dano arcano/fogo devastador em raio de 6m."
	},
	3: { # Sentinela dos Ventos
		"basic": "Disparo Preciso",
		"q": "Tiro Perfurante",
		"r": "Salto Acrobático",
		"f": "Tempestade de Mil Flechas",
		"basic_desc": "Flecha balística com +20% Taxa Crítica à distância e +12% Velocidade.",
		"q_desc": "Flecha veloz a 24m que atravessa alvos causando 1.85x dano.",
		"r_desc": "Mortal para trás disparando flecha que prende o inimigo por 2s.",
		"f_desc": "2.6x dano em chuva de flechas numa área de 6m."
	},
	4: { # Lâmina Silente
		"basic": "Talho Duplo",
		"q": "Passo das Sombras",
		"r": "Cortina de Fumaça",
		"f": "Lótus de Sangue",
		"basic_desc": "Golpes letais com +35% Dano Crítico pelas costas e +15% Esquiva.",
		"q_desc": "Teleporta para as costas do alvo cortando com 1.9x dano + veneno.",
		"r_desc": "Fica furtivo/intangível por 2.5s e ganha +30% velocidade.",
		"f_desc": "Desfere 8 cortes letais em 4m causando 2.7x dano e hemorragia."
	},
	5: { # Punho Celeste
		"basic": "Golpe de Chi",
		"q": "Gancho Demolidor",
		"r": "Postura do Lótus Marcial",
		"f": "Meteoro de Um Punho",
		"basic_desc": "Punhos pesados que ignoram 25% da armadura e ganham escudo a cada 3 socos.",
		"q_desc": "Soco explosivo de Chi causando 1.85x dano e atordoamento curto.",
		"r_desc": "Purifica debuffs, cura +40 HP e reduz dano em 50% por 3s.",
		"f_desc": "Salta e soca o chão abrindo cratera de 5.5m com 2.75x dano."
	},
	6: { # Guardião do Bastião
		"basic": "Pancada de Bastião",
		"q": "Esmagamento de Bastião",
		"r": "Formação Impenetrável",
		"f": "Cidadela Inabalável",
		"basic_desc": "+35% Defesa Total, reflete 20% do dano e converte Defesa em Ataque.",
		"q_desc": "Golpe de escudo com 1.7x dano que provoca/Taunt monstros em 8m.",
		"r_desc": "Bloqueia 80% do dano por 4s e concede escudo aos aliados próximos.",
		"f_desc": "Crava o escudo no solo criando cúpula dourada que cura +70 HP e impede mortes por 4s."
	},
	7: { # Forjador de Estrelas
		"basic": "Martelada Pesada",
		"q": "Golpe da Bigorna Incandescente",
		"r": "Afiação & Têmpera em Campo",
		"f": "Dança do Arsenal Forjado",
		"basic_desc": "Equipamentos nunca quebram, +25% dano com armas forjadas e ignora restrição de armas.",
		"q_desc": "1.85x dano de fogo/físico que racha 30% da armadura.",
		"r_desc": "Repara armas e concede +25% Ataque e Defesa ao grupo por 10s.",
		"f_desc": "Invoca 4 armas espectrais forjadas que giram cortando tudo em 5.5m com 2.7x dano."
	},
	8: { # Transmutador
		"basic": "Frasco Cáustico",
		"q": "Frasco de Fogo Grego & Cura",
		"r": "Bomba de Ácido Corrosivo",
		"f": "Transmutação do Behemoth Químico",
		"basic_desc": "+35% potência de poções/frascos e ataques aplicam ácido cumulativo.",
		"q_desc": "Explode curando +45 HP nos aliados e queimando inimigos com 1.8x dano.",
		"r_desc": "Poça química que derrete 35% da defesa inimiga e desacelera.",
		"f_desc": "Detona megabomba de 2.6x dano e transmutação com +30% status por 8s."
	},
	9: { # Escultor de Almas
		"basic": "Entalhe Prateado",
		"q": "Entalhe em Velocidade",
		"r": "Estátua Explosiva / Pele de Mármore",
		"f": "Técnica Secreta: Escultura do Luar",
		"basic_desc": "+25% Dano Crítico enxergando falhas e mantém uma Estátua Guardiã ajudando.",
		"q_desc": "5 cortes precisos com 1.9x dano que reduzem a defesa do alvo.",
		"r_desc": "Deixa uma escultura que explode nos inimigos e ganha 50% redução de dano.",
		"f_desc": "Feixe de cortes prateados em 6m causando 2.8x Dano Verdadeiro."
	},
	10: { # Senhor das Feras
		"basic": "Estalo de Domínio",
		"q": "Estalo do Chicote: Investida!",
		"r": "Fusão & Uivo Bestial",
		"f": "Debandada das Feras Primordiais",
		"basic_desc": "Luta acompanhado permanentemente por uma Fera Domada que divide o dano.",
		"q_desc": "Chicoteia a 9m e ordena que a fera salte rasgando o alvo com 1.9x dano.",
		"r_desc": "Cura +50 HP seu e da fera, concedendo +30% velocidade e garras.",
		"f_desc": "Invoca manada de feras domadas que atropelam toda a área em 7m com 2.8x dano."
	},
	11: { # Tecelão Carmesim
		"basic": "Puntura Rúnica",
		"q": "Teia de Fios Retalhadores",
		"r": "Costurar Sombras / Marionete",
		"f": "Gaiola de Fios Carmesins",
		"basic_desc": "Ataques cortam a 10m de distância e roupas leves têm defesa de armadura pesada.",
		"q_desc": "Cruza os dedos fatiando todos os inimigos em cone de 8m com 1.85x dano.",
		"r_desc": "Prende os inimigos no chão por 2.5s com fios de aço e concede esquiva ao grupo.",
		"f_desc": "Fecha uma redoma de fios de aço que tritura todos os alvos em 6m causando 2.7x dano."
	},
	12: { # Mestre do Banquete
		"basic": "Corte de Açougue",
		"q": "Desossar a Vivo!",
		"r": "Banquete na Wok Flamejante",
		"f": "Trinchar o Behemoth",
		"basic_desc": "Zona Verde da Autópsia +50% maior; devorar carnes dá buffs especiais.",
		"q_desc": "Golpe pesado de cutelo com 1.9x dano que arranca bife curativo (+35 HP) do alvo.",
		"r_desc": "Bloqueia projéteis com a frigideira e serve prato que cura +55 HP e dá +25% Dano ao grupo.",
		"f_desc": "Salta com cutelo flamejante com 2.8x dano em 5.5m e reduz a defesa do Boss pela metade."
	},
	27: { # Ceifador da Lua Negra
		"basic": "Foice das Sombras",
		"q": "Colheita Noturna",
		"r": "Drenagem Abissal",
		"f": "Dança do Eclipse Total",
		"basic_desc": "Varredura ampla de 4.8m com lifesteal embutido (1.0x dano).",
		"q_desc": "Corte espiral sugando essência vital de todos os alvos no caminho (1.75x dano).",
		"r_desc": "Vórtice escuro que paralisa alvos e restaura +45 HP contínuos ao usuário.",
		"f_desc": "Giro fatal de foice cobrindo 6.0m com dano devastador e roubo de vida (2.4x dano)."
	},
	35: { # Engenheiro Rúnico
		"basic": "Canhonada Rúnica",
		"q": "Salva Rúnica",
		"r": "Sobrecarga Eletrostática",
		"f": "Bombardeio Titanomecânico",
		"basic_desc": "Pancada física e detonação de pólvora simultâneas (1.0x dano).",
		"q_desc": "Três cartuchos energizados disparados em rápida sucessão frontal (1.75x dano).",
		"r_desc": "Pulso elétrico que concede raios nas armas do grupo por 8s.",
		"f_desc": "Disparo orbital com estilhaços energizados de 6.5m (2.4x dano)."
	},
	36: { # Demiurgo Alquímico
		"basic": "Pulso Quimérico",
		"q": "Infusão Mutagênica",
		"r": "Névoa de Bioplasma",
		"f": "Frenesi do Chimeryth Supremo",
		"basic_desc": "Onda biótica disparada pelo homúnculo que causa dano e regenera o mestre.",
		"q_desc": "Elixir abissal corrosivo que dissolve resistências inimigas (1.75x dano).",
		"r_desc": "Nuvem esverdeada curando aliados continuamente e cegando monstros.",
		"f_desc": "O homúnculo cresce e desfere explosão de garras e ácido colossais (2.4x dano)."
	},
	28: { # Bailarino das Estrelas
		"basic": "Corte Astral",
		"q": "Corte Cadente",
		"r": "Valsa dos Espelhos",
		"f": "Constelação de Mil Lâminas",
		"basic_desc": "Corte rápido com +25% de chance crítica permanente e esquiva barata de 10 stamina.",
		"q_desc": "Salto veloz que corta o espaço desferindo dano massivo (2.0x dano).",
		"r_desc": "Janela de 1.5s de invulnerabilidade total (I-Frame) seguida de contra-ataque refletor.",
		"f_desc": "Dança de cortes omnidirecionais devastando inimigos em raio de 5.5m (3.0x dano)."
	},
	29: { # Inquisidor da Chama Branca
		"basic": "Chama Penitente",
		"q": "Chicote de Penitência",
		"r": "Selo de Excomunhão",
		"f": "Crucificação de Cinzas",
		"basic_desc": "Golpe ardente que ganha até +60% de dano conforme o HP diminui.",
		"q_desc": "Chicote de fogo sagrado de 8.0m que causa 2.2x dano e rouba vida.",
		"r_desc": "Purificação sagrada que regenera +35 HP e incendeia inimigos em raio de 5.0m.",
		"f_desc": "Pilares de cinzas incandescentes que incineram uma área de 6.0m (3.2x dano)."
	},
	30: { # Arauto do Ossuário
		"basic": "Toque do Sepulcro",
		"q": "Lança de Fêmur",
		"r": "Explosão Óssea & Escudo",
		"f": "Legião do Ossuário",
		"basic_desc": "Projétil de ossos fragmentados. Cada abate regenera +20 HP instantâneos.",
		"q_desc": "Dispara lança de fêmur calcificado que perfura a 16m causando 2.0x dano.",
		"r_desc": "Detona fragmentos ósseos em 5.0m e ergue barreira de ossos protetora.",
		"f_desc": "Ergue vórtice de ossatura profana cobrindo 6.0m com 3.0x de dano letal."
	},
	37: { # Senhor da Selva Primordial
		"basic": "Patada Selvagem",
		"q": "Investida do Alfa",
		"r": "Uivo da Alcateia",
		"f": "Fúria do Behemoth",
		"basic_desc": "Ataque corporal com ferocidade primal e dano aumentado em +25% permanentemente.",
		"q_desc": "Avanço bestial rompendo as linhas inimigas com impacto violento (2.1x dano).",
		"r_desc": "Uivo ressonante que cura +50 HP e concede buff de ataque crítico a todo o grupo.",
		"f_desc": "Impacto frontal titânico gerando onda de choque sísmica devastadora (3.0x dano)."
	},
	38: { # Cavaleiro do Vazio
		"basic": "Golpe de Fenda",
		"q": "Esmagamento Gravitacional",
		"r": "Singularidade Reversa",
		"f": "Colapso Estelar",
		"basic_desc": "Golpe pesado imbuído de gravidade e resistência passiva de -30% a danos.",
		"q_desc": "Atrai monstros em 5.0m para junto de si e esmaga o solo (1.9x dano).",
		"r_desc": "Postura de bloqueio que absorve 80% do dano e implode o espaço ao redor.",
		"f_desc": "Cria um buraco negro em 6.5m que atordoa inimigos e desintegra matéria (2.8x dano)."
	},
	39: { # Arauto do Trovão
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
	2: "Explosão Lunar",
	3: "Baluarte Rúnico",
	4: "Sopro Dracônico",
	5: "Sede de Sangue",
	6: "Uivo da Fera Ancestral",
	7: "Pacto das Cinzas",
	8: "Chama Sagrada",
	9: "Mergulho Abissal",
	10: "Sobrecarga Arcana",
	11: "Estandarte Real",
	12: "Fenda do Éter",
	13: "Luz de Selene",
	14: "Manto de Nyx",
	15: "Muralha Rúnica",
	16: "Erupção Magma",
	17: "Chamas Reais",
	18: "Frenesi Destruidor",
	19: "Raízes Vivas",
	20: "Nuvem de Esporos",
	21: "Teia Prateada",
	22: "Sopro de Cinzas",
	23: "Mutação Bioquímica",
	24: "Crio-Armadura",
	25: "Maré Abissal",
	26: "Correntes Infernais",
	27: "Julgamento Nephilim",
	28: "Reversão Temporal",
	29: "Asas de Luz",
	30: "Combustão",
	31: "Memória Molecular",
	32: "Insulto Sísmico",
	33: "Bênção de Netuno",
	34: "Descarga Elétrica",
	35: "Infusão Arcana",
	36: "Ataque Devastador",
	37: "Martelo Ancestral",
	38: "Disparo Élfico",
	39: "Espada Solar de Azgher",
	40: "Manto de Tenebra",
	41: "Pó de Fada Estelar",
	42: "Truque Sujo Gnarlin",
	43: "Aguilhão de Toxina Vorpal",
	44: "Lar Doce Casca",
	45: "Drenar Força Vital",
	46: "Despertar Forma Bestial",
	47: "Coração de Mana"
}

var current_world_hour: int = 16
var current_world_minute: int = 0
var current_moon_phase: int = 1
var current_weather_type: int = 0
var weather_particles: Dictionary = {} # fx -> CPUParticles3D
var weather_flash_timer: float = 4.0

var current_zone_id: int = 0
var current_map_root: Node3D = null
var portal_cooldown: float = 0.0
var screen_fade_rect: ColorRect = null

var my_race_id: int = 1
var my_class_id: int = 0
var my_class_tier: int = 0
var my_sub_path: int = 0 # Caminho Evolutivo (1 a 4; 0 = ainda não escolhido)
var my_mana: int = 0
var my_max_mana: int = 0
var mana_bar: ProgressBar = null
var mana_label: Label = null
var hunger_bar: ProgressBar = null
var survival_label: Label = null
var weight_warning_label: Label = null
var ground_items_nodes: Dictionary = {} # drop_id -> Node3D
var ground_items_data: Dictionary = {} # drop_id -> {"id", "quantity", "x", "z"}
const GROUND_PICKUP_RANGE := 3.5
const ItemDataScript = preload("res://scripts/ItemData.gd")

# Coleta e materiais
var discovered_materials: Dictionary = {} # material_id -> true (espelho do servidor)
var resource_nodes_nodes: Dictionary = {} # node_id -> Node3D
var resource_nodes_data: Dictionary = {} # node_id -> Dictionary
var discovery_banner: Label = null
var quest_label: Label = null
const QUEST_PARTS := {
	1: ["O Aprendiz do Ferreiro (1/3)", "Traga Pinho do Refúgio a Garrick — use o Machado Velho nos pinheiros da Vila"],
	2: ["O Aprendiz do Ferreiro (2/3)", "Traga Cobre a Garrick — use a Picareta Desgastada nos veios perto da Vila"],
	3: ["O Aprendiz do Ferreiro (3/3)", "Traga Couro de Javali a Garrick — cace e esfole Javalis no Bosque Sussurrante"],
}
var _discovery_queue: Array = []
const HARVEST_RANGE := 3.5
const NODE_KIND_NAMES := {1: "Árvore", 2: "Rocha", 3: "Veio de Metal", 4: "Cristal", 5: "Vinha / Arbusto", 6: "Fonte", 7: "Barreiro", 8: "Ossada"}
var my_level: int = 1
var my_buff_active: int = 0
var my_hp: int = 100
var my_max_hp: int = 100
var my_stamina: int = 100
var my_max_stamina: int = 100

var action_bar_container: HBoxContainer = null
var action_bar_slots: Array[PanelContainer] = []
var action_bar_name_labels: Array[Label] = []
var action_bar_cd_labels: Array[Label] = []
const ACTION_BAR_IDS := [1, 3, 4, 5, 6] # LMB, Q, R, F, Z

func _ready() -> void:
	for action_name in ["skill_racial", "skill_1", "skill_2", "skill_3", "dodge", "interact"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

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

	forge_ui = ForgeUIScript.new()
	add_child(forge_ui)

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
	NetworkManager.npc_friendship_received.connect(_on_npc_friendship_received)
	NetworkManager.npc_spoke.connect(_on_npc_spoke)
	NetworkManager.world_time_updated.connect(_on_world_time_updated)
	NetworkManager.combat_event_received.connect(_on_combat_event_received)
	NetworkManager.player_stats_received.connect(_on_player_stats_received)
	NetworkManager.player_stats_full_received.connect(_on_player_stats_full_received)
	NetworkManager.player_mana_received.connect(_on_player_mana_received)
	NetworkManager.wallet_weight_updated.connect(_on_wallet_weight_updated)
	NetworkManager.ground_items_received.connect(_on_ground_items_received)
	NetworkManager.resource_nodes_received.connect(_on_resource_nodes_received)
	NetworkManager.discovered_materials_received.connect(_on_discovered_materials_received)
	NetworkManager.quest_state_received.connect(_on_quest_state_received)
	NetworkManager.survival_received.connect(_on_survival_received)
	NetworkManager.corpse_drag_state_received.connect(_on_corpse_drag_state)
	for mid in ItemDataScript.STARTING_DISCOVERED:
		discovered_materials[mid] = true
	NetworkManager.player_attributes_received.connect(_on_player_attributes_received)
	NetworkManager.player_respawn_received.connect(_on_player_respawn_received)
	NetworkManager.mob_state_received.connect(_on_mob_state_received)
	NetworkManager.aoe_telegraph_received.connect(_on_aoe_telegraph_received)
	NetworkManager.projectile_spawned.connect(_on_projectile_spawned)
	NetworkManager.dev_drop_rates_received.connect(_on_dev_drop_rates_received)
	NetworkManager.corpse_snapshot_received.connect(_on_corpse_snapshot_received)
	NetworkManager.open_autopsy_ui_received.connect(_on_open_autopsy_ui_received)
	NetworkManager.zone_change_received.connect(_on_zone_change_received)

	var default_floor = get_node_or_null("Floor")
	if default_floor:
		default_floor.queue_free()
	var default_structures = get_node_or_null("Structures")
	if default_structures:
		default_structures.queue_free()

	_setup_burn_overlay()
	_setup_mana_bar()
	_setup_weight_warning()
	_setup_discovery_banner()
	_setup_action_bar()
	_setup_xp_hud()
	_setup_loot_toast()
	_load_zone_map(0)
	_spawn_local_player(Vector3(0, 1.5, 0))
	_update_hud()
	_update_clock_hud()

	_build_dev_manager_ui()

	var footer_lbl = get_node_or_null("HUD/FooterPanel/FooterLabel")
	if footer_lbl:
		footer_lbl.text = "[WASD] Mover | [LMB] Ataque | [Shift] Esquiva | [G] Pegar Item | [Q/R/F] Skills | [Z] Racial | [E] Interagir | [C] Linhagem | [K] Atributos | [I] Inventário | [H] Grimório | [F9/F10] Dev Manager"

func _process(delta: float) -> void:
	_update_action_bar_cooldowns()
	_keep_player_above_ground()
	if world_map_ui and local_player and is_instance_valid(local_player):
		world_map_ui.update_player(current_zone_id, local_player.global_position)
	if portal_cooldown > 0.0:
		portal_cooldown -= delta
	_update_drag_rope()

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
		if event.keycode == KEY_F9 or event.keycode == KEY_F10:
			print("[World] F9/F10: Alternando Dev Manager Unificado...")
			_toggle_dev_manager()
			get_viewport().set_input_as_handled()
		elif dev_manager_panel and dev_manager_panel.visible and event.keycode == KEY_ESCAPE:
			_toggle_dev_manager()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Clique (com o cursor livre) sobre uma bolsa no chão para pegá-la
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if _try_pickup_ground_item_at_screen(event.position):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_try_pickup_nearest_ground_item()
		elif event.keycode == KEY_T:
			_toggle_corpse_drag()
		elif event.keycode == KEY_E:
			if _try_interact_corpse():
				pass
			elif _try_harvest_nearest_node():
				pass
			elif _try_use_anvil():
				pass
			else:
				if not _try_interact_door():
					_try_interact_nearest_npc()
		elif event.keycode == KEY_U:
			open_forge(true)
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
		elif event.keycode == KEY_M:
			_toggle_world_map()
		elif event.keycode == KEY_H:
			if skills_ui:
				skills_ui.toggle_menu()
		elif event.keycode == KEY_F9 or event.keycode == KEY_F10:
			print("[World] F9/F10: Alternando Dev Manager Unificado...")
			_toggle_dev_manager()

func _toggle_dev_manager() -> void:
	if not dev_manager_panel:
		return
	dev_manager_panel.visible = not dev_manager_panel.visible

	if dev_manager_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if local_player and is_instance_valid(local_player):
			local_player.set("is_menu_open", true)
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

# ==============================================================================
# DEV MANAGER UNIFICADO (F9 / F10) — CONSTRUÇÃO EMBUTIDA (CANVASLAYER LAYER 120)
# ==============================================================================

const DEV_RACES := [
	# Originais Base (1..4)
	{"id": 1, "name": "Valeriano", "badge": "Base Solar", "col": Color("#ffd700"), "desc": "Linhagem Solar: +10% Regen Stamina e Bênção Solar [Z]"},
	{"id": 2, "name": "Noctari", "badge": "Base Lunar", "col": Color("#00e5ff"), "desc": "Sintonia Noturna: +15% Dano Mágico e Esquiva à noite"},
	{"id": 3, "name": "Kharad", "badge": "Base Forja", "col": Color("#ff9800"), "desc": "Pele Pétrea: -15% dano físico e Bastião Sísmico [Z]"},
	{"id": 4, "name": "Varkai", "badge": "Base Feral", "col": Color("#ff5722"), "desc": "Instinto Predador: +20% Velocidade e Salto Predatório [Z]"},
	# Secretas Clássicas (5..10)
	{"id": 5, "name": "Sangrael / Sanguis", "badge": "Vampírico", "col": Color("#e91e63"), "desc": "Vampirismo: +8% Roubo de Vida passivo e Dreno Sanguíneo"},
	{"id": 6, "name": "Lupharion", "badge": "Lupino Alfa", "col": Color("#ff6f00"), "desc": "Fúria da Matilha: +25% Dano na Lua Cheia / Sangue"},
	{"id": 7, "name": "Cinerion (Amaldiçoado)", "badge": "Cinzas", "col": Color("#a7ffeb"), "desc": "Tenacidade Fúnebre: Sobrevive 4s com 1 HP ao morrer"},
	{"id": 8, "name": "Seraphel / Natus Solaris", "badge": "Luz Solar", "col": Color("#fff176"), "desc": "Aura Radiante: Queima inimigos e feixe purificador"},
	{"id": 9, "name": "Umbryss", "badge": "Sombra Cósmica", "col": Color("#7c4dff"), "desc": "Corpo de Éter: 10% chance de desvio total e Vácuo [Z]"},
	{"id": 10, "name": "Runaric / Gélido", "badge": "Gélido", "col": Color("#80deea"), "desc": "Presença Glacial: Reduz velocidade de atacantes em 20%"},
	# Evoluções Ordem e Caos (11..18)
	{"id": 11, "name": "Solvaren", "badge": "Ordem Solar", "col": Color("#ffe082"), "desc": "Liderança Real: +20% Stamina Máxima e Estandarte Imperial"},
	{"id": 12, "name": "Aetheris", "badge": "Caos Cósmico", "col": Color("#ce93d8"), "desc": "Corpo Etéreo: 15% ignorar dano e Fenda Dimensional"},
	{"id": 13, "name": "Selenarca", "badge": "Ordem Selene", "col": Color("#80d8ff"), "desc": "Bênção da Lua: +35% poder mágico e Cascata Lunar"},
	{"id": 14, "name": "Nyxara", "badge": "Caos Nyx", "col": Color("#b388ff"), "desc": "Véu Noturno: +30% velocidade e Manto de Invisibilidade"},
	{"id": 15, "name": "Runakhar", "badge": "Ordem Forja", "col": Color("#ffcc80"), "desc": "Pele de Adamante: -25% dano físico e reflete 15%"},
	{"id": 16, "name": "Pyrokhar", "badge": "Caos Magma", "col": Color("#ffab91"), "desc": "Coração Vulcânico: Dano de fogo por segundo em golpes"},
	{"id": 17, "name": "Dravarkai / Predador Alfa", "badge": "Alcateia", "col": Color("#ff8a65"), "desc": "Espírito de Alcateia: +20% dano e velocidade em grupo"},
	{"id": 18, "name": "Ferovar", "badge": "Frenesi", "col": Color("#ff1744"), "desc": "Sede de Sangue: +5% velocidade de ataque cumulativa"},
	# Novas Raças Secretas (19..28)
	{"id": 19, "name": "Sylvari", "badge": "Nascido da Seiva", "col": Color("#81c784"), "desc": "Raízes Vivas: Regeneração acelerada e vínculo florestal"},
	{"id": 20, "name": "Myconid", "badge": "Véu Fúngico", "col": Color("#c8e6c9"), "desc": "Esporos Vivos: Nuvem de veneno e cegueira ao redor"},
	{"id": 21, "name": "Aracne", "badge": "Tecelão da Bruma", "col": Color("#a5d6a7"), "desc": "Pernas de Seda: Imune a lentidão e Teia Paralisante"},
	{"id": 22, "name": "Ignivarn", "badge": "Escama-Negra", "col": Color("#ff6e40"), "desc": "Bafo de Cinzas: Queimadura contínua e explosão de calor"},
	{"id": 23, "name": "Chimeryth", "badge": "Costurado", "col": Color("#ba68c8"), "desc": "Corpo Reativo: Adaptação física contra o último dano sofrido"},
	{"id": 24, "name": "Borealin", "badge": "Coração de Geada", "col": Color("#80deea"), "desc": "Armadura de Gelo: Absorve impactos físicos com espinhos glaciais"},
	{"id": 25, "name": "Thalassian", "badge": "Maré Negra", "col": Color("#4fc3f7"), "desc": "Filho da Maré: +25% poder na chuva e surto aquático"},
	{"id": 26, "name": "Cambion", "badge": "Sangue de Enxofre", "col": Color("#ff5252"), "desc": "Pacto Abissal: Transforma parte da vida em poder devastador"},
	{"id": 27, "name": "Nephilim", "badge": "Híbrido Crepúsculo", "col": Color("#ffe082"), "desc": "Luz e Trevas: Alterna bônus de dano sagrado e necrótico"},
	{"id": 28, "name": "Cronari", "badge": "Cronari", "col": Color("#b388ff"), "desc": "Fios do Tempo: Reduz cooldowns e rebobina a posição"},
	# 18 Novas Raças do RPG (29..46)
	{"id": 29, "name": "Aurelith", "badge": "RPG Divino", "col": Color("#fff59d"), "desc": "Asas de Luz [Z]: Cura +65 HP, restaura Stamina e pulso luminoso."},
	{"id": 30, "name": "Pyrael", "badge": "RPG Chamas", "col": Color("#ff3d00"), "desc": "Combustão [Z]: Explosão ígnea devastadora (2.8x) e renascimento em cinzas."},
	{"id": 31, "name": "Jotunar", "badge": "RPG Glacial (1.45x)", "col": Color("#80deea"), "desc": "Memória Molecular [Z]: Pancada de estalagmites e +350 HP Máx por 15s."},
	{"id": 32, "name": "Terravyrn", "badge": "RPG Carapaça", "col": Color("#8d6e63"), "desc": "Insulto Sísmico [Z]: Provoca monstros e -35% dano passivo permanente."},
	{"id": 33, "name": "Hydravyrn", "badge": "RPG Marés", "col": Color("#29b6f6"), "desc": "Bênção de Netuno [Z]: Vaga marítima em cone e regeneração sob chuva."},
	{"id": 34, "name": "Fulgravyrn", "badge": "RPG Fulgor", "col": Color("#ffd600"), "desc": "Descarga Elétrica [Z]: Feixe perfurante de choque rápido (1.85x)."},
	{"id": 35, "name": "Arcavyrn", "badge": "RPG Rúnico", "col": Color("#ab47bc"), "desc": "Infusão Arcana [Z]: Runas arcanas radiantes com amplificação mágica."},
	{"id": 36, "name": "Orkhan", "badge": "RPG Brutal", "col": Color("#558b2f"), "desc": "Ataque Devastador [Z]: Golpe brutal (3.2x dano) e digestão de carcaças orgânicas."},
	{"id": 37, "name": "Dvergar", "badge": "RPG Forja (0.82x)", "col": Color("#d7ccc8"), "desc": "Martelo Ancestral [Z]: Choque de bigorna com atordoamento em 5.5m."},
	{"id": 38, "name": "Elarin", "badge": "RPG Silvestre", "col": Color("#aed581"), "desc": "Disparo Élfico [Z]: Projétil luminoso perfurante e esquiva ágil."},
	{"id": 39, "name": "Solarin (Azgher)", "badge": "RPG Solar", "col": Color("#ffb300"), "desc": "Espada Solar de Azgher [Z]: Talho solar em fogo sagrado purificador."},
	{"id": 40, "name": "Lunarin (Tenebra)", "badge": "RPG Sombra", "col": Color("#5c6bc0"), "desc": "Manto de Tenebra [Z]: Véu sombrio de evasão total com ataque crítico."},
	{"id": 41, "name": "Faelith", "badge": "RPG Alado (0.55x)", "col": Color("#f48fb1"), "desc": "Pó de Fada Estelar [Z]: Nuvem reluzente de cura em aliados e cegueira em inimigos."},
	{"id": 42, "name": "Gnarlin", "badge": "RPG Trapaceiro (0.75x)", "col": Color("#7cb342"), "desc": "Truque Sujo Gnarlin [Z]: Bomba de fumaça cega, confunde e atordoa oponentes."},
	{"id": 43, "name": "Escarion", "badge": "RPG Peçonha", "col": Color("#6a1b9a"), "desc": "Aguilhão de Toxina Vorpal [Z]: Estocada venenosa de dano corrosivo contínuo."},
	{"id": 44, "name": "Testudar", "badge": "RPG Blindado (1.35x)", "col": Color("#33691e"), "desc": "Lar Doce Casca [Z]: Casulo impenetrável (-45% dano passivo e absorção 85%)."},
	{"id": 45, "name": "Lilitara", "badge": "RPG Vampírico", "col": Color("#c2185b"), "desc": "Drenar Força Vital [Z]: Sifão demoníaco com roubo de 55 HP e 25% evasão passiva."},
	{"id": 46, "name": "Ulvar", "badge": "RPG Feral", "col": Color("#78909c"), "desc": "Despertar Forma Bestial [Z]: Uivo lupino brutal com +35% velocidade e garras vorazes."},
	{"id": 47, "name": "Manamante", "badge": "Secreta Sangue Azul", "col": Color("#3d5afe"), "desc": "Coração de Mana [Z]: Queima 15% da Vida numa explosão arcana de 7m (+18% dano passivo)."}
]

const DEV_CLASSES := [
	{"id": 1, "name": "Espadachim da Aurora", "desc": "Combatente de espada. [Passiva] Sangue de Batalha (+15% Defesa, +10% Dano). [Q] Corte Duplo, [R] Investida Imparável, [F] Julgamento da Espada.", "col": Color("#4fc3f7")},
	{"id": 2, "name": "Arcanista", "desc": "Conjurador com cajado/orbe. [Passiva] Ressonância Arcana (+20% Mágico). [Q] Orbe de Magma, [R] Prisão Glacial, [F] Chuva de Meteoros.", "col": Color("#ba68c8")},
	{"id": 3, "name": "Sentinela dos Ventos", "desc": "Atirador ágil de arco. [Passiva] Olho de Falcão (+20% Crítico, +12% Vel). [Q] Tiro Perfurante, [R] Salto Acrobático, [F] Tempestade de Mil Flechas.", "col": Color("#81c784")},
	{"id": 4, "name": "Lâmina Silente", "desc": "Lâmina dupla veloz. [Passiva] Lâmina Silenciosa (+35% Crítico costas, +15% Esquiva). [Q] Passo das Sombras, [R] Cortina de Fumaça, [F] Lótus de Sangue.", "col": Color("#e57373")},
	{"id": 5, "name": "Punho Celeste", "desc": "Mestre do combate corpo a corpo. [Passiva] Punhos de Ferro & Chi (ignora 25% armadura). [Q] Gancho Demolidor, [R] Postura do Lótus Marcial, [F] Meteoro de Um Punho.", "col": Color("#ffb74d")},
	{"id": 6, "name": "Guardião do Bastião", "desc": "Defensor colossal com escudo e maça. [Passiva] Fortaleza Viva (+35% Defesa). [Q] Esmagamento de Bastião, [R] Formação Impenetrável, [F] Cidadela Inabalável.", "col": Color("#fff176")},
	{"id": 7, "name": "Forjador de Estrelas", "desc": "Combatente forjador com martelo. [Passiva] Orgulho do Criador (+25% Dano forjadas). [Q] Golpe da Bigorna Incandescente, [R] Afiação & Têmpera em Campo, [F] Dança do Arsenal Forjado.", "col": Color("#ff9800")},
	{"id": 8, "name": "Transmutador", "desc": "Mestre químico com catalisador e frascos. [Passiva] Reação Sintética (+35% frascos). [Q] Frasco de Fogo Grego & Cura, [R] Bomba de Ácido Corrosivo, [F] Transmutação do Behemoth.", "col": Color("#69f0ae")},
	{"id": 9, "name": "Escultor de Almas", "desc": "Artista do luar com cinzel e adaga. [Passiva] Olho da Escultura & Estátua Viva. [Q] Entalhe em Velocidade, [R] Estátua Explosiva / Pele de Mármore, [F] Escultura do Luar.", "col": Color("#80deea")},
	{"id": 10, "name": "Senhor das Feras", "desc": "Senhor da matilha com chicote bestial. [Passiva] Luta acompanhado por Fera Domada. [Q] Estalo do Chicote: Investida!, [R] Fusão & Uivo Bestial, [F] Debandada das Feras.", "col": Color("#ffd740")},
	{"id": 11, "name": "Tecelão Carmesim", "desc": "Tecelão com fios de aço e agulhas rúnicas. [Passiva] Fios Monofilamento & Seda Blindada. [Q] Teia de Fios Retalhadores, [R] Costurar Sombras, [F] Gaiola de Fios Carmesins.", "col": Color("#ce93d8")},
	{"id": 12, "name": "Mestre do Banquete", "desc": "Gourmet com cutelo gigante e wok de ferro. [Passiva] Células Gourmet. [Q] Desossar a Vivo! (+35 HP), [R] Banquete na Wok Flamejante, [F] Trinchar o Behemoth.", "col": Color("#ff7043")},
	{"id": 13, "name": "Lâmina Rúnica", "desc": "Variante Secreta (Espadachim da Aurora/Arcanista, nv. 25+, sem reset). Espada Rúnica + Orbe. [Passiva] Lâmina Elemental. [Q] Corte Flamígero/Glacial, [R] Escudo de Runas, [F] Cometa da Espada Arcana.", "col": Color("#40c4ff")},
	{"id": 14, "name": "Inquisidor de Prata", "desc": "Variante Secreta (Sentinela dos Ventos/Lâmina Silente, nv. 25+, sem reset). Besta de Prata + Estaca. [Passiva] Exterminador Noturno (+40% em criaturas sombrias). [Q] Virote de Prata, [R] Corrente de Exorcismo, [F] Julgamento da Cruz Solar.", "col": Color("#eceff1")},
	{"id": 15, "name": "Valquíria Celeste", "desc": "Variante Secreta (Guardião do Bastião/Espadachim da Aurora, nv. 25+, sem reset). Lança Dourada + Escudo Alado. [Passiva] Voo da Valquíria. [Q] Estocada do Trovão, [R] Salto da Valquíria, [F] Chuva de Lanças Douradas.", "col": Color("#fff59d")},
	{"id": 16, "name": "Punho Fantasma", "desc": "Variante Secreta (Punho Celeste/Lâmina Silente, nv. 25+, sem reset). Manoplas Sombrias. [Passiva] Golpe do Ponto Vital Furtivo. [Q] Palma das Sombras, [R] Passo Fantasma, [F] Toque da Morte de Cinco Passos.", "col": Color("#7e57c2")},
	{"id": 17, "name": "Forjador Carmesim", "desc": "Variante Secreta (Forjador de Estrelas, nv. 25+, sem reset). Martelo Carmesim + Espada Viva. [Passiva] Têmpera de Sangue (25% roubo de vida). [Q] Martelo Hemorrágico, [R] Sacrifício da Bigorna, [F] Despertar da Espada Demoníaca.", "col": Color("#c62828")},
	{"id": 18, "name": "Doutor Corvo", "desc": "Variante Secreta (Transmutador/Mestre do Banquete, nv. 25+, sem reset). Máscara de Corvo + Bisturi + Incensário. [Passiva] Imunidade & Cura Tóxica. [Q] Bisturi Cirúrgico, [R] Incenso Purificador, [F] Nuvem da Peste Negra.", "col": Color("#7cb342")},
	{"id": 19, "name": "Algoz Vorpal", "desc": "Única de Raça (Escarion). [Q] Ferrão Duplo Vorpal, [R] Ecdise Ácida, [F] Execução da Terceira Dose Letal (4.0x verdadeiro).", "col": Color("#76ff03")},
	{"id": 20, "name": "Senhor da Teia Escarlate", "desc": "Única de Raça (Aracne). [Q] Fios de Seda Cortante, [R] Casulo de Drenagem, [F] Domínio da Viúva Negra (3.5x).", "col": Color("#d50000")},
	{"id": 21, "name": "Rei-Lobo do Eclipse", "desc": "Única de Raça (Ulvar / Lupharion). [Q] Frenesi de Mordidas, [R] Uivo do Eclipse Lupino, [F] Caçada Selvagem (3.6x).", "col": Color("#b71c1c")},
	{"id": 22, "name": "Runomante Ancestral", "desc": "Única de Raça (Dvergar / Kharad). [Q] Martelo Trovão, [R] Bigorna Ancestral Viva, [F] Forja do Ragnarok (3.6x).", "col": Color("#ffab40")},
	{"id": 23, "name": "Colosso Abissal", "desc": "Única de Raça (Tartaruga). [Q] Giro de Carapaça, [R] Fortaleza Hidráulica, [F] Peso do Oceano Profundo (3.5x).", "col": Color("#2e7d32")},
	{"id": 24, "name": "Arquifada de Yggdra", "desc": "Única de Raça (Faelith). [Q] Rajada de Pó Estelar, [R] Anel de Cogumelos, [F] Despertar de Titânia (3.5x).", "col": Color("#f48fb1")},
	{"id": 25, "name": "Conde Escarlate", "desc": "Única de Raça (Sangrael). [Q] Lança de Sangue Congelado, [R] Enxame da Noite, [F] Trono de Sangue (3.6x).", "col": Color("#880e4f")},
	{"id": 26, "name": "Barão Engrenagem", "desc": "Única de Raça (Gnarlin). [Q] Canhão de Moedas, [R] Propulsor Turbo, [F] Autodestruição Nuclear (3.8x).", "col": Color("#ffd600")},
	{"id": 27, "name": "Ceifador da Lua Negra", "desc": "Classe Secreta (Tier 5). Foice colossal com colheita de almas. [Q] Colheita Noturna, [R] Drenagem Abissal, [F] Dança do Eclipse Total.", "col": Color("#d500f9")},
	{"id": 35, "name": "Engenheiro Rúnico", "desc": "Classe Secreta (Tier 5). Martelo-canhão estelar. [Q] Salva Rúnica, [R] Sobrecarga, [F] Bombardeio Titanomecânico.", "col": Color("#ff6d00")},
	{"id": 36, "name": "Demiurgo Alquímico", "desc": "Classe Secreta (Tier 5). Orbe alquímico e quimera regenerativa. [Q] Infusão Mutagênica, [R] Névoa Bioplasma, [F] Frenesi Quimérico.", "col": Color("#00b0ff")},
	{"id": 28, "name": "Bailarino das Estrelas", "desc": "Classe Secreta (Tier 5). Lâminas estelares finas. [Q] Corte Cadente, [R] Valsa dos Espelhos (I-Frame), [F] Mil Lâminas.", "col": Color("#80d8ff")},
	{"id": 29, "name": "Inquisidor da Chama Branca", "desc": "Classe Secreta (Tier 5). Correntes incandescentes. [Q] Chicote de Penitência, [R] Selo de Excomunhão, [F] Crucificação.", "col": Color("#ff5252")},
	{"id": 30, "name": "Arauto do Ossuário", "desc": "Classe Secreta (Tier 5). Manipulador profano de esqueletos. [Q] Lança de Fêmur, [R] Explosão Óssea, [F] Legião do Ossuário.", "col": Color("#ccff90")},
	{"id": 37, "name": "Senhor da Selva Primordial", "desc": "Classe Secreta (Tier 5). Lança selvagem e Lobo Espiritual Alfa. [Q] Investida do Alfa, [R] Uivo da Alcateia, [F] Fúria do Behemoth.", "col": Color("#ffd740")},
	{"id": 38, "name": "Cavaleiro do Vazio", "desc": "Classe Secreta (Tier 5). Colosso de gravidade e vazio. [Q] Esmagamento Gravitacional, [R] Singularidade Reversa, [F] Colapso Estelar.", "col": Color("#7c4dff")},
	{"id": 39, "name": "Arauto do Trovão", "desc": "Classe Secreta (Tier 5). Alabarda dourada de relâmpagos. [Q] Lança do Trovão, [R] Passo de Relâmpago, [F] Ira dos Céus.", "col": Color("#40c4ff")},
	{"id": 31, "name": "Herdeiro da Forja Divina", "desc": "LENDÁRIA (Tier 6). [Q] Dança da Espada: Onda, [R] Transcendência de 6 Espadas, [F] Queda do Deus da Forja (4.8x).", "col": Color("#ffd700")},
	{"id": 32, "name": "Mestre Escultor do Luar", "desc": "LENDÁRIA (Tier 6). [Q] Lâmina da Lua Radiante, [R] Destruição Escultural (+80% ATK), [F] Legião Imperial do Luar (4.6x).", "col": Color("#b3e5fc")},
	{"id": 33, "name": "Imperador Dracônico", "desc": "LENDÁRIA (Tier 6). [Q] Garra do Monarca, [R] Rugido de Subjugação, [F] Cataclismo do Rei Dragão (5.0x).", "col": Color("#ff6d00")},
	{"id": 34, "name": "Soberano do Sol Negro", "desc": "LENDÁRIA (Tier 6). [Q] Corte do Horizonte de Eventos, [R] Égide da Aurora e Abismo, [F] Apocalipse do Sol Negro (5.0x, céu em Eclipse).", "col": Color("#4a148c")}
]

# Lista de itens do Dev Manager montada a partir do catálogo real (ItemData), sempre com IDs corretos
func _dev_items_list() -> Array:
	var out: Array = []
	var ids: Array = ItemDataScript.ITEMS.keys()
	ids.sort()
	for iid in ids:
		var info: Dictionary = ItemDataScript.ITEMS[iid]
		var cat := "Item"
		var desc := "%.1f kg" % float(info["weight"])
		if ItemDataScript.is_material(iid):
			var m: Dictionary = ItemDataScript.material(iid)
			cat = "%s %s" % [ItemDataScript.CATEGORY_NAMES.get(m["category"], ""), ItemDataScript.rarity_name(int(m["rarity"]))]
			desc += " • " + m["trait"]
		elif info.has("tool"):
			cat = "Ferramenta Tier %d" % int(info["tool_tier"])
		elif int(info["slot"]) >= 0:
			cat = "Equipamento"
		if inventory_ui and inventory_ui.ITEM_CATALOG.has(iid):
			desc += " • " + str(inventory_ui.ITEM_CATALOG[iid].get("desc", ""))
		out.append({"id": iid, "name": info["name"], "cat": cat, "rate": "-", "desc": desc})
	return out

const DEV_BESTIARY := [
	# ZoneID 1 — Bosque Sussurrante (600x600m)
	{"name": "Javali Selvagem", "zone": "Bosque Sussurrante", "zone_id": 1, "hp": "140 HP", "spawn": "Vara de javalis perto da entrada do bosque", "drops": [2, 128, 142], "col": Color("#8d6e63")},
	{"name": "Lobo da Bruma", "zone": "Bosque Sussurrante", "zone_id": 1, "hp": "220 HP", "spawn": "Comum a qualquer hora no bosque", "drops": [5, 6, 7, 30], "col": Color("#90a4ae")},
	{"name": "Lobo Alfa (Chefe da Alcateia)", "zone": "Bosque Sussurrante", "zone_id": 1, "hp": "750 HP", "spawn": "🌕 Spawn na LUA CHEIA", "drops": [7, 8, 29, 30], "col": Color("#ffd54f")},
	{"name": "Licantropo Alfa (Raid Boss Feral)", "zone": "Bosque Sussurrante", "zone_id": 1, "hp": "2200 HP", "spawn": "🩸 Spawn na LUA DE SANGUE", "drops": [7, 8, 28, 30], "col": Color("#e53935")},
	{"name": "Aranha Tecelã da Bruma", "zone": "Bosque Sussurrante", "zone_id": 1, "hp": "380 HP", "spawn": "Espalhada pelas árvores da floresta", "drops": [42, 19], "col": Color("#ba68c8")},
	{"name": "★ Arachna, a Rainha Tecelã [RAID BOSS] ★", "zone": "Bosque Sussurrante", "zone_id": 1, "hp": "6800 HP", "spawn": "🕸️ Ninho de Teias em (120, -120)", "drops": [43, 45, 44], "col": Color("#e040fb")},

	# ZoneID 8 — Esgotos Antigos (600x600m)
	{"name": "Lodo Ácido Corrosivo", "zone": "Esgotos Antigos", "zone_id": 8, "hp": "320 HP", "spawn": "Canais e dutos lamacentos", "drops": [46, 28], "col": Color("#76ff03")},
	{"name": "Escorpião Abissal Gigante", "zone": "Esgotos Antigos", "zone_id": 8, "hp": "540 HP", "spawn": "Túneis alagados e galerias profundas", "drops": [48, 47], "col": Color("#26a69a")},
	{"name": "Mini-Boss Quimera Costurada Nº 0", "zone": "Esgotos Antigos", "zone_id": 8, "hp": "2800 HP", "spawn": "Túneis profundos do laboratório em (0, 110)", "drops": [49, 19, 10], "col": Color("#ff7043")},

	# ZoneID 2 — Ruínas da Vigília & Norte Gelado (600x600m)
	{"name": "Saqueador Deserdado", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "350 HP", "spawn": "Comum nos pátios das ruínas", "drops": [1, 4, 10, 29], "col": Color("#b0bec5")},
	{"name": "Besteiro da Vigília", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "200 HP", "spawn": "Nas torres de vigia das ruínas", "drops": [1, 4, 12, 29], "col": Color("#78909c")},
	{"name": "Acólito do Eclipse", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "240 HP", "spawn": "Altares e catacumbas subterrâneas", "drops": [3, 14, 17, 30], "col": Color("#ab47bc")},
	{"name": "Executor de Ferro", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "650 HP", "spawn": "Guarda dos portões da cidadela", "drops": [10, 16, 20, 21], "col": Color("#546e7a")},
	{"name": "Comandante Vaelen, o Traidor (Boss)", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "3200 HP", "spawn": "Trono da Cidadela nas Ruínas", "drops": [10, 15, 20, 28], "col": Color("#ff9800")},
	{"name": "Golem de Gelo Antigo", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "720 HP", "spawn": "Setor norte nevado da ZoneID 2", "drops": [50, 10], "col": Color("#4fc3f7")},
	{"name": "Draco de Geada Selvagem", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "950 HP", "spawn": "Penhascos e cumes gélidos", "drops": [51, 4], "col": Color("#29b6f6")},
	{"name": "★ Ymir, o Patriarca Jotunar [BOSS] ★", "zone": "Ruínas da Vigília", "zone_id": 2, "hp": "5200 HP", "spawn": "❄️ Trono de Gelo em (0, 150)", "drops": [50, 52], "col": Color("#00e5ff")},

	# ZoneID 3 — Santuário do Eclipse (600x600m)
	{"name": "Cultista Sombrio", "zone": "Santuário do Eclipse", "zone_id": 3, "hp": "400 HP", "spawn": "Círculos rituais do templo", "drops": [3, 14, 17, 28], "col": Color("#8e24aa")},
	{"name": "Gárgula de Pedra", "zone": "Santuário do Eclipse", "zone_id": 3, "hp": "580 HP", "spawn": "Empoleiradas nas colunatas", "drops": [9, 24, 26, 28], "col": Color("#607d8b")},
	{"name": "Inquisidor Vex (Mini-Boss)", "zone": "Santuário do Eclipse", "zone_id": 3, "hp": "1400 HP", "spawn": "Pátio dos Sacrifícios no Santuário", "drops": [10, 17, 20, 28], "col": Color("#d32f2f")},
	{"name": "★ Malakor, o Arauto do Eclipse [RAID BOSS] ★", "zone": "Santuário do Eclipse", "zone_id": 3, "hp": "7500 HP", "spawn": "Câmara Central do Santuário", "drops": [14, 17, 20, 28, 30], "col": Color("#d500f9")},
	{"name": "Guarda Sanguinário de Vesperian", "zone": "Santuário do Eclipse", "zone_id": 3, "hp": "680 HP", "spawn": "Entrada da Cripta Carmesim a Noroeste", "drops": [53, 10], "col": Color("#ef5350")},
	{"name": "★ LORDE VESPERIAN, O PROGENITOR VAMPIRO [RAID BOSS SECRETO] ★", "zone": "Santuário do Eclipse", "zone_id": 3, "hp": "8500 HP", "spawn": "🩸 Cripta Carmesim em (-140, 140) — Desperta à Noite, Lua de Sangue ou Eclipse!", "drops": [55, 17, 54], "col": Color("#b71c1c")}
]

# Viagem direta para cada zona (0x22 Cmd 14)
const DEV_ZONES := [[0, "🏛️ Vila do Refúgio"], [1, "🌲 Bosque Sussurrante"], [9, "🌳 Bosque Ralo"], [10, "🌾 Campos Rasteiros"],
	[11, "🦒 Savana Dourada"], [12, "🏜️ Deserto de Sal"], [13, "🌬️ Planalto dos Ventos"], [2, "❄️ Ruínas da Vigília"],
	[14, "🏔️ Picos Gelados"], [15, "🪨 Colinas de Basalto"], [4, "🌋 Fronteira das Cinzas"], [3, "🌑 Santuário do Eclipse"],
	[16, "🐸 Pântano das Brumas"], [8, "🐀 Esgotos Antigos"]]

const DEV_TELEPORTS := [
	{"name": "🏛️ Praça Central da Vila", "val": 0, "col": Color(0.2, 0.35, 0.55)},
	{"name": "⛪ Igreja da Luz", "val": 1, "col": Color(0.55, 0.5, 0.2)},
	{"name": "🔮 Torre do Arcanista", "val": 2, "col": Color(0.45, 0.25, 0.6)},
	{"name": "🐀 Entrada dos Esgotos", "val": 3, "col": Color(0.35, 0.4, 0.3)},
	{"name": "🌲 Floresta / Bosque", "val": 4, "col": Color(0.25, 0.5, 0.3)},
	{"name": "⚔️ Ruínas da Vigília", "val": 5, "col": Color(0.6, 0.35, 0.2)},
	{"name": "🌑 Santuário do Eclipse", "val": 6, "col": Color(0.65, 0.15, 0.35)},
	{"name": "🏴 Mercado Negro", "val": 7, "col": Color(0.4, 0.2, 0.5)}
]

func _build_dev_manager_ui() -> void:
	if dev_canvas_layer and is_instance_valid(dev_canvas_layer):
		return

	dev_canvas_layer = CanvasLayer.new()
	dev_canvas_layer.name = "DevCanvasLayer"
	dev_canvas_layer.layer = 120
	add_child(dev_canvas_layer)
	LunariaUI.watch(dev_canvas_layer) # mesmo estilo do inventário

	# 1. Botão fixo no topo direito [🛠️ DEV (F9)]
	dev_btn_top = Button.new()
	dev_btn_top.name = "DevBtnTop"
	dev_btn_top.text = "🛠️ DEV (F9)"
	dev_btn_top.focus_mode = Control.FOCUS_NONE
	dev_btn_top.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	dev_btn_top.custom_minimum_size = Vector2(105, 30)
	dev_btn_top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dev_btn_top.offset_left = -120
	dev_btn_top.offset_top = 10
	dev_btn_top.offset_right = -15
	dev_btn_top.offset_bottom = 40

	var top_btn_style := StyleBoxFlat.new()
	top_btn_style.bg_color = Color(0.12, 0.22, 0.38, 0.92)
	top_btn_style.border_width_left = 1
	top_btn_style.border_width_top = 1
	top_btn_style.border_width_right = 1
	top_btn_style.border_width_bottom = 1
	top_btn_style.border_color = Color(0.3, 0.65, 1.0, 0.8)
	top_btn_style.corner_radius_top_left = 6
	top_btn_style.corner_radius_top_right = 6
	top_btn_style.corner_radius_bottom_left = 6
	top_btn_style.corner_radius_bottom_right = 6
	dev_btn_top.add_theme_stylebox_override("normal", top_btn_style)
	dev_btn_top.add_theme_font_size_override("font_size", 12)
	dev_btn_top.pressed.connect(_toggle_dev_manager)
	dev_canvas_layer.add_child(dev_btn_top)

	# 2. Painel Principal de 920x600 centralizado
	dev_manager_panel = PanelContainer.new()
	dev_manager_panel.name = "DevManagerPanel"
	dev_manager_panel.set_anchors_preset(Control.PRESET_CENTER)
	dev_manager_panel.custom_minimum_size = Vector2(920, 600)
	dev_manager_panel.size = Vector2(920, 600)
	dev_manager_panel.offset_left = -460
	dev_manager_panel.offset_top = -300
	dev_manager_panel.offset_right = 460
	dev_manager_panel.offset_bottom = 300
	dev_manager_panel.visible = false

	var pnl_style := StyleBoxFlat.new()
	pnl_style.bg_color = Color(0.08, 0.09, 0.14, 0.96)
	pnl_style.border_width_left = 2
	pnl_style.border_width_top = 2
	pnl_style.border_width_right = 2
	pnl_style.border_width_bottom = 2
	pnl_style.border_color = Color(0.25, 0.45, 0.75, 0.8)
	pnl_style.corner_radius_top_left = 8
	pnl_style.corner_radius_top_right = 8
	pnl_style.corner_radius_bottom_left = 8
	pnl_style.corner_radius_bottom_right = 8
	pnl_style.content_margin_left = 14
	pnl_style.content_margin_top = 12
	pnl_style.content_margin_right = 14
	pnl_style.content_margin_bottom = 12
	dev_manager_panel.add_theme_stylebox_override("panel", pnl_style)
	dev_canvas_layer.add_child(dev_manager_panel)

	# 3. Layout vertical principal
	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 8)
	dev_manager_panel.add_child(main_vb)

	# Top Bar com Título e Botão Fechar
	var top_bar := HBoxContainer.new()
	main_vb.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "🛠️ PAINEL UNIFICADO DE DESENVOLVIMENTO (F9 / F10)"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	top_bar.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "✕ Fechar (F9)"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_toggle_dev_manager)
	top_bar.add_child(close_btn)

	# Barra de Status
	dev_status_label = Label.new()
	dev_status_label.text = "Status: Pronto | Pressione F9 ou F10 para alternar este menu."
	dev_status_label.add_theme_font_size_override("font_size", 11)
	dev_status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	main_vb.add_child(dev_status_label)

	# TabContainer com as 6 Abas
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vb.add_child(tabs)

	_build_dev_tab_races(tabs)
	_build_dev_tab_classes(tabs)
	_build_dev_tab_world(tabs)
	_build_dev_tab_items(tabs)
	_build_dev_tab_bestiary(tabs)
	_build_dev_tab_teleports(tabs)

	dev_manager_node = dev_manager_panel
	dev_manager_ui = dev_manager_panel
	dev_race_menu_ui = dev_manager_panel

func _dev_get_card_style(border_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.9)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border_color
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	return sb

func _dev_create_btn(text: String, col: Color, on_click: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(on_click)

	var bsb := StyleBoxFlat.new()
	bsb.bg_color = col.darkened(0.5)
	bsb.border_width_left = 1
	bsb.border_width_top = 1
	bsb.border_width_right = 1
	bsb.border_width_bottom = 1
	bsb.border_color = col
	bsb.corner_radius_top_left = 5
	bsb.corner_radius_top_right = 5
	bsb.corner_radius_bottom_left = 5
	bsb.corner_radius_bottom_right = 5
	bsb.content_margin_left = 8
	bsb.content_margin_right = 8
	bsb.content_margin_top = 4
	bsb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", bsb)

	var hsb: StyleBoxFlat = bsb.duplicate()
	hsb.bg_color = col.darkened(0.2)
	btn.add_theme_stylebox_override("hover", hsb)

	var psb: StyleBoxFlat = bsb.duplicate()
	psb.bg_color = col
	btn.add_theme_stylebox_override("pressed", psb)

	btn.add_theme_font_size_override("font_size", 11)
	return btn

func _dev_update_tier_buttons() -> void:
	for idx in range(dev_tier_buttons.size()):
		var t_num: int = idx + 1
		var btn: Button = dev_tier_buttons[idx]
		if t_num == dev_selected_tier:
			btn.modulate = Color(1.0, 0.9, 0.3)
		else:
			btn.modulate = Color(0.8, 0.8, 0.8)

func _dev_update_path_buttons() -> void:
	for idx in range(dev_path_buttons.size()):
		var btn: Button = dev_path_buttons[idx]
		btn.modulate = Color(1.0, 0.9, 0.3) if idx == dev_selected_path else Color(0.8, 0.8, 0.8)

var _active_class_or_race_modal: PanelContainer = null

# Modal de Confirmação Obrigatória para Mudança de Classe ou Raça
func request_class_or_race_change(is_race: bool, target_id: int, target_tier: int, target_name: String, source_desc: String) -> void:
	# Classes Únicas Exclusivas de Raça: sem a raça certa, nem chega a abrir a confirmação
	if not is_race and not source_desc.begins_with("DEV_COMBO:"):
		var blood_warning: String = ClassPaths.race_block_message(target_id, my_race_id)
		if blood_warning != "":
			show_loot_toast(blood_warning)
			if dev_status_label:
				dev_status_label.text = blood_warning
			return
	if _active_class_or_race_modal and is_instance_valid(_active_class_or_race_modal):
		_active_class_or_race_modal.queue_free()
		_active_class_or_race_modal = null

	if not dev_canvas_layer or not is_instance_valid(dev_canvas_layer):
		dev_canvas_layer = CanvasLayer.new()
		dev_canvas_layer.name = "DevCanvasLayer"
		dev_canvas_layer.layer = 125
		add_child(dev_canvas_layer)
		LunariaUI.watch(dev_canvas_layer)

	var modal := PanelContainer.new()
	modal.name = "ClassOrRaceConfirmationModal"
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.custom_minimum_size = Vector2(580, 260)
	modal.offset_left = -290
	modal.offset_top = -130
	modal.offset_right = 290
	modal.offset_bottom = 130
	modal.z_index = 150

	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = Color(0.06, 0.07, 0.12, 0.98)
	modal_style.set_border_width_all(3)
	modal_style.set_corner_radius_all(10)
	modal_style.content_margin_left = 24
	modal_style.content_margin_top = 20
	modal_style.content_margin_right = 24
	modal_style.content_margin_bottom = 20

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	modal.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)

	var body_lbl := Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))

	var is_secret_class: bool = (not is_race and target_tier >= 5)

	if not is_secret_class:
		modal_style.border_color = Color(1.0, 0.85, 0.1, 0.95)
		title_lbl.text = "⚠️ ATENÇÃO: MUDANÇA DE CLASSE / RAÇA"
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		var category_name: String = "raça" if is_race else "classe"
		# Entre parênteses: o Tier da classe (Comum, Incomum, Rara, Épica) ou "Raça"
		var desc_tag: String = "Raça" if is_race else (TIER_NAMES[target_tier] if target_tier >= 1 and target_tier < TIER_NAMES.size() else "Comum")
		body_lbl.text = "Você está prestes a mudar sua %s atual para [%s] (%s).\nSuas habilidades atuais serão substituídas.\nVocê sabe o que está fazendo e deseja confirmar?" % [category_name, target_name, desc_tag]
	else:
		modal_style.border_color = Color(1.0, 0.2, 0.2, 0.98)
		var tier_title_str: String = "ÚNICA" if target_tier == 5 else "LENDÁRIA"
		title_lbl.text = "🩸 AVISO CRÍTICO: CLASSE %s (RESET PARA O NÍVEL 1!)" % tier_title_str
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		body_lbl.text = "Você está prestes a despertar a Classe Secreta [%s]!\n\n❗ CONSEQUÊNCIA PERMANENTE: Seu personagem VOLTARÁ PARA O NÍVEL 1 imediatamente para reconstruir seus atributos com o novo crescimento superior (+11 a +15 pts/nível).\n\nVocê tem plena consciência do que está fazendo?" % target_name

	modal.add_theme_stylebox_override("panel", modal_style)
	vb.add_child(title_lbl)
	vb.add_child(body_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 18)
	vb.add_child(btn_hb)

	var confirm_btn := Button.new()
	confirm_btn.text = "✅ Sim, sei o que estou fazendo (Confirmar)"
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm_btn.custom_minimum_size = Vector2(260, 36)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.12, 0.55, 0.25, 0.95)
	c_style.border_color = Color(0.35, 0.9, 0.45)
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("normal", c_style)
	var c_hover: StyleBoxFlat = c_style.duplicate()
	c_hover.bg_color = Color(0.18, 0.7, 0.32, 1.0)
	confirm_btn.add_theme_stylebox_override("hover", c_hover)

	confirm_btn.pressed.connect(func():
		_execute_class_or_race_change(is_race, target_id, target_tier, target_name, source_desc)
		modal.queue_free()
		_active_class_or_race_modal = null
	)
	btn_hb.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "❌ Cancelar"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.custom_minimum_size = Vector2(130, 36)
	var x_style := StyleBoxFlat.new()
	x_style.bg_color = Color(0.5, 0.15, 0.15, 0.9)
	x_style.border_color = Color(0.9, 0.3, 0.3)
	x_style.set_border_width_all(2)
	x_style.set_corner_radius_all(6)
	cancel_btn.add_theme_stylebox_override("normal", x_style)
	var x_hover: StyleBoxFlat = x_style.duplicate()
	x_hover.bg_color = Color(0.7, 0.2, 0.2, 1.0)
	cancel_btn.add_theme_stylebox_override("hover", x_hover)

	cancel_btn.pressed.connect(func():
		modal.queue_free()
		_active_class_or_race_modal = null
	)
	btn_hb.add_child(cancel_btn)

	dev_canvas_layer.add_child(modal)
	_active_class_or_race_modal = modal
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _execute_class_or_race_change(is_race: bool, target_id: int, target_tier: int, target_name: String, source_desc: String) -> void:
	# Oferta do servidor (NPC Mestre, Altar, desafio secreto ou evolução racial): o servidor só aplica
	# a troca quando recebe esta confirmação (0x40), então nada é enviado por 0x30 aqui.
	if source_desc.begins_with("OFFER:"):
		var offer_type: int = int(source_desc.replace("OFFER:", ""))
		if NetworkManager:
			NetworkManager.send_evolution_choice(offer_type, target_id)
		show_loot_toast("%s [%s] confirmada!" % ["Raça" if is_race else "Classe", target_name])
		return

	# Combo do Dev Manager: primeiro a raça exigida (modo 99), depois a classe no Tier fixo (modo 98)
	if source_desc.begins_with("DEV_COMBO:"):
		var combo_race: int = int(source_desc.replace("DEV_COMBO:", ""))
		if NetworkManager:
			NetworkManager.send_select_identity(combo_race, 0, 99)
			NetworkManager.send_select_identity(target_tier, target_id, 98)
		if dev_status_label:
			dev_status_label.text = "Combo confirmado: %s" % target_name
		show_loot_toast("Combo [%s] confirmado!" % target_name)
		return

	# Item da mochila: o servidor consome o item e aplica o efeito dele (troca de raça/classe incluída).
	# Mandar 0x30 junto mudaria a identidade mesmo que o servidor recusasse o item.
	if source_desc.begins_with("ITEM:"):
		var item_id_val: int = int(source_desc.replace("ITEM:", ""))
		if NetworkManager:
			NetworkManager.send_use_item(item_id_val)
		show_loot_toast("%s [%s] confirmada!" % ["Raça" if is_race else "Classe", target_name])
		return

	if is_race:
		var current_cid: int = 1
		if local_player and is_instance_valid(local_player) and local_player.get("current_class_id") != null:
			current_cid = local_player.current_class_id
		var act_mode: int = 99 if source_desc.begins_with("DEV") else 0
		if NetworkManager:
			NetworkManager.send_select_identity(target_id, current_cid, act_mode)
		if dev_status_label:
			dev_status_label.text = "Raça confirmada: #%d %s" % [target_id, target_name]
		show_loot_toast("Raça [%s] confirmada!" % target_name)
	else:
		var current_rid: int = 1
		if local_player and is_instance_valid(local_player) and local_player.get("current_race_id") != null:
			current_rid = local_player.current_race_id
		if NetworkManager:
			if source_desc.begins_with("DEV"):
				# Modo 98 (Dev Direto): o servidor lê o Tier no campo da raça; o 4º campo é o Caminho
				NetworkManager.send_select_identity(target_tier, target_id, 98, dev_selected_path)
			elif target_tier >= 5:
				NetworkManager.send_select_identity(current_rid, target_id, 2) # IdentityModeSecretReset
			else:
				NetworkManager.send_select_identity(current_rid, target_id, 0) # IdentityModeInitialChange
		if dev_status_label:
			dev_status_label.text = "Classe confirmada: #%d %s (Tier %d)" % [target_id, target_name, target_tier]
		show_loot_toast("Classe [%s] confirmada!" % target_name)

func _on_dev_activate_race(race_id: int, race_name: String) -> void:
	request_class_or_race_change(true, race_id, 1, race_name, "DEV F9")

## Combo do Dev Manager: assume a raça exigida e a Classe Única de Raça (com o modal de confirmação).
func _on_dev_activate_combo(class_id: int, target_class_name: String) -> void:
	var races: Array = ClassPaths.TRANSCENDENT[class_id]["races"]
	var race_id: int = races[0]
	var race_label: String = RACE_NAMES[race_id] if race_id < RACE_NAMES.size() else "#%d" % race_id
	request_class_or_race_change(false, class_id, ClassPaths.tier_for_class(class_id),
		"%s + Raça %s" % [target_class_name, race_label], "DEV_COMBO:%d" % race_id)

func _on_dev_activate_class(class_id: int, target_class_name: String) -> void:
	var shown_name: String = target_class_name
	var title: String = ClassPaths.path_title(class_id, dev_selected_tier, dev_selected_path)
	if title != "":
		shown_name = "%s — %s" % [target_class_name, title]
	request_class_or_race_change(false, class_id, dev_selected_tier, shown_name, "DEV F9")

func _build_dev_tab_races(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "🧬 Raças"
	tabs.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	for race in DEV_RACES:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _dev_get_card_style(race["col"]))
		vb.add_child(card)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info_vb)

		var name_lbl := Label.new()
		name_lbl.text = "#%d %s [%s]" % [race["id"], race["name"], race["badge"]]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", race["col"])
		info_vb.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = race["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		info_vb.add_child(desc_lbl)

		var rid: int = race["id"]
		var rname: String = race["name"]
		var btn := _dev_create_btn("Ativar Raça", race["col"], func():
			_on_dev_activate_race(rid, rname)
		)
		btn.custom_minimum_size = Vector2(110, 28)
		hb.add_child(btn)

func _build_dev_tab_classes(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "⚔️ Classes & Nível"
	tab.add_theme_constant_override("separation", 8)
	tabs.add_child(tab)

	# 1. Painel de Nível & Atributos (Cmd 8 via 0x22)
	var lvl_card := PanelContainer.new()
	lvl_card.add_theme_stylebox_override("panel", _dev_get_card_style(Color(0.2, 0.65, 0.4)))
	tab.add_child(lvl_card)

	var lvl_vb := VBoxContainer.new()
	lvl_vb.add_theme_constant_override("separation", 6)
	lvl_card.add_child(lvl_vb)

	var lvl_title := Label.new()
	lvl_title.text = "📈 1. CONTROLE DE NÍVEL & ATRIBUTOS (0x22 Cmd 8):"
	lvl_title.add_theme_font_size_override("font_size", 12)
	lvl_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	lvl_vb.add_child(lvl_title)

	var lvl_hb := HBoxContainer.new()
	lvl_hb.add_theme_constant_override("separation", 6)
	lvl_vb.add_child(lvl_hb)

	lvl_hb.add_child(_dev_create_btn("[+1 Nível]", Color(0.25, 0.6, 0.35), func():
		NetworkManager.send_dev_level_control(1)
		if dev_status_label: dev_status_label.text = "+1 Nível solicitado ao servidor!"
		show_loot_toast("+1 Nível!")
	))
	lvl_hb.add_child(_dev_create_btn("[+5 Níveis]", Color(0.25, 0.6, 0.35), func():
		NetworkManager.send_dev_level_control(5)
		if dev_status_label: dev_status_label.text = "+5 Níveis solicitados ao servidor!"
		show_loot_toast("+5 Níveis!")
	))
	lvl_hb.add_child(_dev_create_btn("[Nível 50 (Máx)]", Color(0.8, 0.65, 0.1), func():
		NetworkManager.send_dev_level_control(50)
		if dev_status_label: dev_status_label.text = "Nível 50 solicitado ao servidor!"
		show_loot_toast("Nível 50 (Máx)!")
	))
	lvl_hb.add_child(_dev_create_btn("[Resetar Nv.1]", Color(0.7, 0.25, 0.25), func():
		NetworkManager.send_dev_level_control(0)
		if dev_status_label: dev_status_label.text = "Reset para Nível 1 solicitado!"
		show_loot_toast("Resetado para Nível 1")
	))
	lvl_hb.add_child(_dev_create_btn("[Full HP/Mana + 20 Pts]", Color(0.2, 0.7, 0.8), func():
		NetworkManager.send_dev_level_control(99)
		if dev_status_label: dev_status_label.text = "Full HP/Mana e +20 Pontos solicitados!"
		show_loot_toast("Full HP + 20 Pontos!")
	))

	# 2. Seletor de Tier (1..6)
	var tier_card := PanelContainer.new()
	tier_card.add_theme_stylebox_override("panel", _dev_get_card_style(Color(0.3, 0.5, 0.7)))
	tab.add_child(tier_card)

	var tier_vb := VBoxContainer.new()
	tier_vb.add_theme_constant_override("separation", 4)
	tier_card.add_child(tier_vb)

	var tier_title := Label.new()
	tier_title.text = "⭐ 2. SELETOR DE TIER DE CLASSE (1 a 6):"
	tier_title.add_theme_font_size_override("font_size", 12)
	tier_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	tier_vb.add_child(tier_title)

	var tier_hb := HBoxContainer.new()
	tier_hb.add_theme_constant_override("separation", 6)
	tier_vb.add_child(tier_hb)

	dev_tier_buttons.clear()
	for t in range(1, 7):
		var t_idx: int = t
		var t_btn := Button.new()
		t_btn.text = "Tier %d (%s)" % [t, TIER_NAMES[t] if t < TIER_NAMES.size() else ""]
		t_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		t_btn.pressed.connect(func():
			dev_selected_tier = t_idx
			_dev_update_tier_buttons()
			if dev_status_label:
				dev_status_label.text = "Tier selecionado: Tier %d (%s)" % [t_idx, TIER_NAMES[t_idx]]
		)
		dev_tier_buttons.append(t_btn)
		tier_hb.add_child(t_btn)
	_dev_update_tier_buttons()

	# 2.1 Seletor de Caminho Evolutivo (Classes Básicas 1 a 12, vale a partir do Tier 2)
	var path_title := Label.new()
	path_title.text = "🧭 CAMINHO EVOLUTIVO (Classes 1 a 12, a partir do Tier 2 — 48 caminhos):"
	path_title.add_theme_font_size_override("font_size", 12)
	path_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	tier_vb.add_child(path_title)

	var path_hb := HBoxContainer.new()
	path_hb.add_theme_constant_override("separation", 6)
	tier_vb.add_child(path_hb)

	dev_path_buttons.clear()
	for p in range(0, 5):
		var p_idx: int = p
		var p_btn := Button.new()
		p_btn.text = "[Manter Caminho]" if p == 0 else "[Caminho %d]" % p
		p_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p_btn.pressed.connect(func():
			dev_selected_path = p_idx
			_dev_update_path_buttons()
			if dev_status_label:
				if p_idx == 0:
					dev_status_label.text = "Caminho: mantém o atual (ou nenhum)"
				else:
					dev_status_label.text = "Caminho %d selecionado — escolha a classe abaixo (Tier 2 a 4)" % p_idx
		)
		dev_path_buttons.append(p_btn)
		path_hb.add_child(p_btn)
	_dev_update_path_buttons()

	# 3. Lista das classes em 4 seções (Básicas, Variantes, Únicas, Lendárias)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	var sections := [
		{"title": "⚔️ Básicas de Combate & Produção (1 a 12)", "col": Color(0.45, 0.75, 1.0), "ids": range(1, 13)},
		{"title": "🔮 Secretas Variantes — Até Épico (13 a 18)", "col": Color(0.7, 0.55, 1.0), "ids": range(13, 19)},
		{"title": "🩸 Secretas ÚNICAS — Exclusivas de Raça & Gerais [Reset Nv.1] (19 a 30, 35 a 39)", "col": Color(1.0, 0.35, 0.35), "ids": range(19, 31) + range(35, 40)},
		{"title": "👑 Secretas LENDÁRIAS — Tier 6 Supremo [Reset Nv.1] (31 a 34)", "col": Color(1.0, 0.84, 0.3), "ids": range(31, 35)},
	]
	var by_id := {}
	for c in DEV_CLASSES:
		by_id[int(c["id"])] = c
	for section in sections:
		var sec_lbl := Label.new()
		sec_lbl.text = section["title"]
		sec_lbl.add_theme_font_size_override("font_size", 14)
		sec_lbl.add_theme_color_override("font_color", section["col"])
		vb.add_child(sec_lbl)
		vb.add_child(HSeparator.new())
		for class_key in section["ids"]:
			if by_id.has(class_key):
				_dev_add_class_card(vb, by_id[class_key])

func _dev_add_class_card(vb: VBoxContainer, c: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _dev_get_card_style(c["col"]))
	vb.add_child(card)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)

	var cid: int = c["id"]
	var cname: String = c["name"]
	var tier_tag: String = ""
	if cid >= 19:
		tier_tag = "  [Tier %d fixo — Reset Nv.1]" % ClassPaths.tier_for_class(cid)

	var name_lbl := Label.new()
	name_lbl.text = "#%d %s%s" % [cid, cname, tier_tag]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", c["col"])
	info_vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = c["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	info_vb.add_child(desc_lbl)

	var btn_vb := VBoxContainer.new()
	btn_vb.add_theme_constant_override("separation", 4)
	hb.add_child(btn_vb)

	var btn := _dev_create_btn("Ativar Classe", c["col"], func():
		_on_dev_activate_class(cid, cname)
	)
	btn.custom_minimum_size = Vector2(130, 28)
	btn_vb.add_child(btn)

	# Únicas Exclusivas de Raça: troca a raça e a classe de uma vez para testar direto
	if ClassPaths.TRANSCENDENT.has(cid) and not ClassPaths.TRANSCENDENT[cid]["races"].is_empty():
		var combo_btn := _dev_create_btn("[⚡ Ativar Combo Raça + Classe Única]", Color(1.0, 0.3, 0.3), func():
			_on_dev_activate_combo(cid, cname)
		)
		combo_btn.custom_minimum_size = Vector2(130, 28)
		btn_vb.add_child(combo_btn)

func _build_dev_tab_world(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "🌙 Mundo, Lua & Clima"
	tab.add_theme_constant_override("separation", 12)
	tabs.add_child(tab)

	# 1. Horários Diretos (Cmd 4 via 0x22)
	var time_card := PanelContainer.new()
	time_card.add_theme_stylebox_override("panel", _dev_get_card_style(Color(0.2, 0.5, 0.8)))
	tab.add_child(time_card)

	var time_vb := VBoxContainer.new()
	time_vb.add_theme_constant_override("separation", 6)
	time_card.add_child(time_vb)

	var time_title := Label.new()
	time_title.text = "⏰ 1. HORÁRIO DO MUNDO (0x22 Cmd 4):"
	time_title.add_theme_font_size_override("font_size", 12)
	time_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	time_vb.add_child(time_title)

	var time_hb := HBoxContainer.new()
	time_hb.add_theme_constant_override("separation", 6)
	time_vb.add_child(time_hb)

	var hours := [
		{"name": "03:00 Madrugada", "h": 3, "col": Color(0.2, 0.25, 0.45)},
		{"name": "06:00 Dia", "h": 6, "col": Color(0.6, 0.55, 0.2)},
		{"name": "12:00 Meio-Dia", "h": 12, "col": Color(0.7, 0.65, 0.25)},
		{"name": "18:00 Noite", "h": 18, "col": Color(0.5, 0.3, 0.55)},
		{"name": "00:00 Meia-Noite", "h": 0, "col": Color(0.25, 0.2, 0.4)}
	]
	for h_data in hours:
		var exact_h: int = h_data["h"]
		var h_name: String = h_data["name"]
		var btn := _dev_create_btn(h_name, h_data["col"], func():
			NetworkManager.send_set_hour(exact_h)
			if dev_status_label:
				dev_status_label.text = "Horário definido para %02d:00!" % exact_h
			show_loot_toast("Horário ajustado para %02d:00" % exact_h)
		)
		time_hb.add_child(btn)

	time_hb.add_child(_dev_create_btn("+1h", Color(0.3, 0.4, 0.5), func():
		NetworkManager.send_skip_time(1)
		if dev_status_label: dev_status_label.text = "Avançado +1 hora!"
	))
	time_hb.add_child(_dev_create_btn("+6h", Color(0.3, 0.4, 0.5), func():
		NetworkManager.send_skip_time(6)
		if dev_status_label: dev_status_label.text = "Avançado +6 horas!"
	))

	# 2. Fases da Lua (Cmd 5 via 0x22)
	var moon_card := PanelContainer.new()
	moon_card.add_theme_stylebox_override("panel", _dev_get_card_style(Color(0.4, 0.3, 0.7)))
	tab.add_child(moon_card)

	var moon_vb := VBoxContainer.new()
	moon_vb.add_theme_constant_override("separation", 6)
	moon_card.add_child(moon_vb)

	var moon_title := Label.new()
	moon_title.text = "🌙 2. FASES DA LUA (0x22 Cmd 5):"
	moon_title.add_theme_font_size_override("font_size", 12)
	moon_title.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
	moon_vb.add_child(moon_title)

	var moon_grid := GridContainer.new()
	moon_grid.columns = 5
	moon_grid.add_theme_constant_override("h_separation", 6)
	moon_grid.add_theme_constant_override("v_separation", 6)
	moon_vb.add_child(moon_grid)

	var moons := [
		"🌑 Lua Nova", "🌒 Lua Crescente", "🌓 Quarto Crescente", "🌔 Gibosa Crescente", "🌕 Lua Cheia",
		"🌖 Gibosa Minguante", "🌗 Quarto Minguante", "🌘 Lua Minguante", "🩸 LUA DE SANGUE", "🌑 ECLIPSE TOTAL"
	]
	for m_idx in range(moons.size()):
		var idx: int = m_idx
		var m_name: String = moons[m_idx]
		var col := Color(0.3, 0.25, 0.5)
		if idx == 8: col = Color(0.7, 0.15, 0.15)
		elif idx == 9: col = Color(0.6, 0.1, 0.6)
		var btn := _dev_create_btn(m_name, col, func():
			NetworkManager.send_set_moon(idx)
			if dev_status_label: dev_status_label.text = "Fase da Lua definida: %s (%d)" % [m_name, idx]
			show_loot_toast("Lua: %s" % m_name)
		)
		moon_grid.add_child(btn)

	var pass_moon_btn := _dev_create_btn("⏭ Passar Lua (+1)", Color(0.4, 0.35, 0.6), func():
		NetworkManager.send_cycle_moon()
		if dev_status_label: dev_status_label.text = "Fase da Lua ciclada!"
	)
	moon_grid.add_child(pass_moon_btn)

	# 3. Clima (Cmd 6 via 0x22)
	var weather_card := PanelContainer.new()
	weather_card.add_theme_stylebox_override("panel", _dev_get_card_style(Color(0.2, 0.6, 0.5)))
	tab.add_child(weather_card)

	var weather_vb := VBoxContainer.new()
	weather_vb.add_theme_constant_override("separation", 6)
	weather_card.add_child(weather_vb)

	var weather_title := Label.new()
	weather_title.text = "🌧️ 3. CLIMA (0x22 Cmd 6) — 24 climas, sorteados por zona a cada 3h:"
	weather_title.add_theme_font_size_override("font_size", 12)
	weather_title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.7))
	weather_vb.add_child(weather_title)

	var weather_hb := HBoxContainer.new()
	weather_hb.add_theme_constant_override("separation", 6)
	weather_vb.add_child(weather_hb)

	var weather_grid := GridContainer.new()
	weather_grid.columns = 4
	weather_grid.add_theme_constant_override("h_separation", 6)
	weather_grid.add_theme_constant_override("v_separation", 6)
	weather_vb.add_child(weather_grid)
	for w_idx in range(WEATHER_NAMES.size()):
		var w_name: String = "%s %s" % [WEATHER_ICONS[w_idx], WEATHER_NAMES[w_idx]]
		var w_fx: Dictionary = WEATHER_FX[w_idx]
		var w_col: Color = (w_fx["fog_col"] as Color).darkened(0.35)
		var btn := _dev_create_btn(w_name, w_col, func():
			NetworkManager.send_set_weather(w_idx)
			if dev_status_label: dev_status_label.text = "Clima definido: %s (%d)" % [w_name, w_idx]
			show_loot_toast("Clima: %s" % w_name)
		)
		weather_grid.add_child(btn)

	weather_hb.add_child(_dev_create_btn("🎲 Clima Automático", Color(0.3, 0.45, 0.3), func():
		NetworkManager.send_set_weather(255)
		if dev_status_label: dev_status_label.text = "Clima voltou ao sorteio automático por zona."
	))
	weather_hb.add_child(_dev_create_btn("⏭ Ciclar Clima", Color(0.25, 0.5, 0.4), func():
		NetworkManager.send_cycle_weather()
		if dev_status_label: dev_status_label.text = "Clima ciclado no servidor!"
	))

	# 4. Eventos climáticos e do Mundo Vivo (Cmd 13 via 0x22)
	var ev_card := PanelContainer.new()
	ev_card.add_theme_stylebox_override("panel", _dev_get_card_style(Color(0.75, 0.45, 0.2)))
	tab.add_child(ev_card)
	var ev_vb := VBoxContainer.new()
	ev_vb.add_theme_constant_override("separation", 6)
	ev_card.add_child(ev_vb)
	var ev_title := Label.new()
	ev_title.text = "🌋 4. EVENTOS CLIMÁTICOS E DO MUNDO VIVO (0x22 Cmd 13):"
	ev_title.add_theme_font_size_override("font_size", 12)
	ev_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	ev_vb.add_child(ev_title)
	var ev_grid := GridContainer.new()
	ev_grid.columns = 4
	ev_grid.add_theme_constant_override("h_separation", 6)
	ev_grid.add_theme_constant_override("v_separation", 6)
	ev_vb.add_child(ev_grid)
	for ev in DEV_WORLD_EVENTS:
		var ev_id: int = ev[0]
		var ev_name: String = ev[1]
		ev_grid.add_child(_dev_create_btn(ev_name, ev[2], func():
			NetworkManager.send_world_control(13, ev_id)
			if dev_status_label: dev_status_label.text = "Evento disparado: %s" % ev_name
			show_loot_toast(ev_name)
		))

func _build_dev_tab_items(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "🎒 Drops & Itens"
	tab.add_theme_constant_override("separation", 8)
	tabs.add_child(tab)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 10)
	tab.add_child(top_hb)

	var kit_btn := _dev_create_btn("📦 Kit Completo 12 Equipamentos (Cmd 7, Val 255)", Color(0.9, 0.6, 0.1), func():
		NetworkManager.send_world_control(7, 255)
		if dev_status_label: dev_status_label.text = "Kit Completo de 12 Equipamentos solicitado!"
		show_loot_toast("Kit 12 Equipamentos recebido!")
	)
	kit_btn.custom_minimum_size = Vector2(0, 32)
	kit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(kit_btn)

	# Testes de dinheiro e peso
	var test_hb := HBoxContainer.new()
	test_hb.add_theme_constant_override("separation", 8)
	tab.add_child(test_hb)
	test_hb.add_child(_dev_create_btn("🪙 +1.000 Sollares & +50 Eclipses", Color(0.85, 0.7, 0.15), func():
		NetworkManager.send_world_control(11, 0)
		show_loot_toast("+1.000 Sollares e +50 Eclipses!")
	))
	test_hb.add_child(_dev_create_btn("⚖️ Adicionar Placa de Chumbo (25 kg) - Testar Sobrecarga", Color(0.45, 0.45, 0.5), func():
		NetworkManager.send_world_control(7, 76)
		show_loot_toast("Placa de Chumbo (25 kg) adicionada à mochila.")
	))
	test_hb.add_child(_dev_create_btn("🧹 Esvaziar Itens Pesados", Color(0.3, 0.55, 0.35), func():
		NetworkManager.send_world_control(12, 0)
		show_loot_toast("Itens pesados (10 kg+) removidos da mochila.")
	))

	# Testes rápidos da Forja (Etapas 2 e 3)
	var forge_hb := HBoxContainer.new()
	forge_hb.add_theme_constant_override("separation", 8)
	tab.add_child(forge_hb)
	forge_hb.add_child(_dev_create_btn("⛏️ Kit de Ferramentas + 5 Materiais Básicos (Testar Coleta e Forja)", Color(0.55, 0.4, 0.2), func():
		NetworkManager.send_world_control(16, 0)
		show_loot_toast("Machado, Picareta, Tesoura e 5 unidades de 9 materiais básicos!")
	))
	forge_hb.add_child(_dev_create_btn("👁️ Revelar Todos os Materiais no Meu Personagem (Apenas Teste Dev)", Color(0.35, 0.45, 0.7), func():
		NetworkManager.send_world_control(17, 0)
		show_loot_toast("Todos os materiais revelados neste personagem (teste). O normal continua: só o que você viu/coletou.")
	))
	forge_hb.add_child(_dev_create_btn("🔨 Abrir Bancada de Forja & Criador Quebra-Cabeça", Color(0.8, 0.45, 0.15), func():
		NetworkManager.send_world_control(18, 0) # acesso Dev: forja e quebra-cabeça em qualquer lugar
		_toggle_dev_manager()
		if forge_ui and not forge_ui.is_open:
			forge_ui.open_menu()
			forge_ui.tabs.current_tab = 2
	))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	for item in _dev_items_list():
		var is_secret: bool = item["rate"].contains("SECRETO")
		var col := Color(0.85, 0.35, 0.9) if is_secret else Color(0.3, 0.6, 0.8)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _dev_get_card_style(col))
		vb.add_child(card)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info_vb)

		var name_lbl := Label.new()
		name_lbl.text = "#%d %s [%s — %s]" % [item["id"], item["name"], item["cat"], item["rate"]]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", col)
		info_vb.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = item["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		info_vb.add_child(desc_lbl)

		var item_id: int = item["id"]
		var item_name: String = item["name"]
		var btn := _dev_create_btn("+ Pegar Item", col, func():
			_dev_pick_quality(item_name, func(q: int):
				NetworkManager.send_give_item(item_id)
				if dev_status_label: dev_status_label.text = "Item adicionado: #%d %s (Qualidade %d)" % [item_id, item_name, q]
				show_loot_toast("+ %s" % item_name)
			)
		)
		btn.custom_minimum_size = Vector2(100, 26)
		hb.add_child(btn)

func _build_dev_tab_bestiary(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "🐉 Bestiário"
	tab.add_theme_constant_override("separation", 8)
	tabs.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	for mob in DEV_BESTIARY:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _dev_get_card_style(mob["col"]))
		vb.add_child(card)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info_vb)

		var title_lbl := Label.new()
		title_lbl.text = "%s — %s (%s)" % [mob["name"], mob["hp"], mob["zone"]]
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.add_theme_color_override("font_color", mob["col"])
		info_vb.add_child(title_lbl)

		var spawn_lbl := Label.new()
		spawn_lbl.text = "Condição: %s" % mob["spawn"]
		spawn_lbl.add_theme_font_size_override("font_size", 10)
		spawn_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		info_vb.add_child(spawn_lbl)

		var btn_vb := VBoxContainer.new()
		btn_vb.add_theme_constant_override("separation", 4)
		hb.add_child(btn_vb)

		var drops_arr: Array = mob["drops"]
		var mob_name: String = mob["name"]
		var drop_btn := _dev_create_btn("📦 Pegar Drops", Color(0.3, 0.7, 0.4), func():
			_dev_pick_quality("Drops de " + mob_name, func(q: int):
				for item_id in drops_arr:
					NetworkManager.send_give_item(item_id)
				if dev_status_label:
					dev_status_label.text = "Drops de %s adicionados (Qualidade %d)!" % [mob_name, q]
				show_loot_toast("Drops de %s coletados!" % mob_name)
			)
		)
		btn_vb.add_child(drop_btn)

		var zid: int = mob["zone_id"]
		var zname: String = mob["zone"]
		var tp_btn := _dev_create_btn("⚡ Ir para Zona", Color(0.3, 0.5, 0.8), func():
			NetworkManager.send_world_control(14, zid) # viagem de zona (o Cmd 9 é um local fixo)
			if dev_status_label:
				dev_status_label.text = "Teleportando para %s (Zona #%d)..." % [zname, zid]
			show_loot_toast("Teleportando para %s..." % zname)
		)
		btn_vb.add_child(tp_btn)

func _build_dev_tab_teleports(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "⚡ Teleportes & Zonas"
	tab.add_theme_constant_override("separation", 10)
	tabs.add_child(tab)

	var desc_lbl := Label.new()
	desc_lbl.text = "Teleporte instantâneo para locais conhecidos (troca de zona automática):"
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	tab.add_child(desc_lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	tab.add_child(grid)

	for tp in DEV_TELEPORTS:
		var tp_name: String = tp["name"]
		var tp_val: int = tp["val"]
		var btn := _dev_create_btn(tp_name, tp["col"], func():
			NetworkManager.send_dev_teleport(tp_val)
			if dev_status_label:
				dev_status_label.text = "Teleportando para %s..." % tp_name
			show_loot_toast("Teleportado para %s!" % tp_name)
		)
		btn.custom_minimum_size = Vector2(240, 36)
		grid.add_child(btn)

	var zones_lbl := Label.new()
	zones_lbl.text = "🗺️ Viajar para a zona (0x22 Cmd 14) — [M] abre o mapa-múndi:"
	zones_lbl.add_theme_font_size_override("font_size", 12)
	zones_lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	tab.add_child(zones_lbl)
	var zgrid := GridContainer.new()
	zgrid.columns = 4
	zgrid.add_theme_constant_override("h_separation", 8)
	zgrid.add_theme_constant_override("v_separation", 6)
	tab.add_child(zgrid)
	for zentry in DEV_ZONES:
		var zid2: int = zentry[0]
		var zlabel: String = zentry[1]
		zgrid.add_child(_dev_create_btn(zlabel, Color(0.25, 0.5, 0.4), func():
			NetworkManager.send_world_control(14, zid2)
			if dev_status_label:
				dev_status_label.text = "Viajando para %s..." % zlabel
		))

	var extra_card := PanelContainer.new()
	extra_card.add_theme_stylebox_override("panel", _dev_get_card_style(Color(0.85, 0.4, 0.2)))
	tab.add_child(extra_card)

	var extra_vb := VBoxContainer.new()
	extra_vb.add_theme_constant_override("separation", 6)
	extra_card.add_child(extra_vb)

	var extra_title := Label.new()
	extra_title.text = "🔬 SIMULAÇÃO DE AUTOPSIA & PUZZLE ANATÔMICO:"
	extra_title.add_theme_font_size_override("font_size", 12)
	extra_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	extra_vb.add_child(extra_title)

	var sim_btn := _dev_create_btn("🔬 Abrir Autópsia de Teste (Simular Cadáver #999)", Color(0.65, 0.25, 0.35), func():
		if autopsy_ui and autopsy_ui.has_method("open_autopsy"):
			autopsy_ui.open_autopsy(999, 1, 100)
			if dev_status_label:
				dev_status_label.text = "Simulação de Autópsia iniciada no cliente!"
	)
	sim_btn.custom_minimum_size = Vector2(0, 32)
	extra_vb.add_child(sim_btn)

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

# --- Arrastar corpos (T): o servidor decide peso, velocidade e o desgaste do couro ---
var dragging_corpse_id: int = 0
var drag_rope: MeshInstance3D = null
var drag_hud: Label = null

func _toggle_corpse_drag() -> void:
	if local_player == null or not is_instance_valid(local_player):
		return
	if dragging_corpse_id > 0:
		NetworkManager.send_corpse_drag(dragging_corpse_id, 0)
		return
	var player_pos: Vector3 = local_player.global_position
	var best_id: int = 0
	var best_dist: float = 2.8
	for cid in corpses.keys():
		var corpse_node = corpses[cid]
		if is_instance_valid(corpse_node) and not corpse_node.is_looted:
			var dist: float = player_pos.distance_to(corpse_node.global_position)
			if dist <= best_dist:
				best_dist = dist
				best_id = cid
	if best_id > 0:
		NetworkManager.send_corpse_drag(best_id, 1)
	else:
		show_loot_toast("Nenhum corpo ao alcance para arrastar.")

func _on_corpse_drag_state(corpse_id: int, pos: Vector3, rot_y: float, integrity: int, dragger_id: int, speed_pct: int, mass_kg: int) -> void:
	var corpse_node = corpses.get(corpse_id)
	if corpse_node != null and is_instance_valid(corpse_node):
		corpse_node.apply_drag_state(on_ground(pos), rot_y, integrity, dragger_id)
	var mine: bool = dragger_id != 0 and dragger_id == NetworkManager.my_player_id
	if mine:
		dragging_corpse_id = corpse_id
	elif dragging_corpse_id == corpse_id:
		dragging_corpse_id = 0
	if local_player and is_instance_valid(local_player) and "drag_speed_mult" in local_player:
		if mine:
			local_player.drag_speed_mult = clampf(speed_pct / 100.0, 0.1, 1.0)
		elif dragging_corpse_id == 0:
			local_player.drag_speed_mult = 1.0
	_update_drag_hud(mine, integrity, mass_kg, speed_pct)

func _update_drag_hud(mine: bool, integrity: int, mass_kg: int, speed_pct: int) -> void:
	if drag_hud == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		drag_hud = Label.new()
		drag_hud.add_theme_font_size_override("font_size", 18)
		drag_hud.add_theme_color_override("font_outline_color", Color.BLACK)
		drag_hud.add_theme_constant_override("outline_size", 6)
		drag_hud.anchor_left = 0.5
		drag_hud.anchor_right = 0.5
		drag_hud.offset_left = -220
		drag_hud.offset_right = 220
		drag_hud.offset_top = 90
		drag_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(drag_hud)
	drag_hud.visible = mine
	if mine:
		drag_hud.text = "🪢 Arrastando corpo: %d kg · Velocidade %d%%\nIntegridade do couro: %d%%  [T] soltar" % [mass_kg, speed_pct, integrity]
		drag_hud.modulate = Color(1, 1, 1) if integrity >= 80 else (Color(1, 0.85, 0.4) if integrity >= 55 else Color(1, 0.45, 0.35))

func _update_drag_rope() -> void:
	var active: bool = dragging_corpse_id > 0 and corpses.has(dragging_corpse_id) and is_instance_valid(corpses[dragging_corpse_id]) \
			and local_player != null and is_instance_valid(local_player)
	if not active:
		if drag_rope:
			drag_rope.visible = false
		if dragging_corpse_id > 0 and not corpses.has(dragging_corpse_id):
			dragging_corpse_id = 0
			if local_player and is_instance_valid(local_player) and "drag_speed_mult" in local_player:
				local_player.drag_speed_mult = 1.0
			if drag_hud:
				drag_hud.visible = false
		return
	if drag_rope == null:
		drag_rope = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 1.0
		cyl.radial_segments = 6
		drag_rope.mesh = cyl
		var rope_mat := StandardMaterial3D.new()
		rope_mat.albedo_color = Color(0.55, 0.42, 0.25)
		drag_rope.material_override = rope_mat
		add_child(drag_rope)
	var a: Vector3 = local_player.global_position + Vector3(0, 1.0, 0)
	var b: Vector3 = corpses[dragging_corpse_id].global_position + Vector3(0, 0.35, 0)
	var length: float = a.distance_to(b)
	if length < 0.05:
		drag_rope.visible = false
		return
	drag_rope.visible = true
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = (b - a) / length
	var basis_y: Vector3 = dir
	var basis_x: Vector3 = basis_y.cross(Vector3.FORWARD if absf(basis_y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var basis_z: Vector3 = basis_x.cross(basis_y).normalized()
	drag_rope.global_transform = Transform3D(Basis(basis_x, basis_y * length, basis_z), mid)

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
				corpse_node.update_data(on_ground(cdata.position), cdata.rotation_y, cdata.is_looted, cdata.remaining_sec)
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
	corpse.setup(cid, mid, mtype, on_ground(pos), rot_y, is_looted, remaining_sec)
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
		if nearest_id != 101 and nearest_id != 102: # todos falam, menos os bonecos de treino
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

var _legendary_flash_at: Dictionary = {} # attacker_id -> instante do último clarão (um por Ultimate)

## Efeito global da Ultimate Lendária: clarão na tela de todos os jogadores.
func _check_legendary_ultimate(attacker_id: int) -> void:
	var atk_class: int = 0
	if attacker_id == NetworkManager.my_player_id:
		atk_class = my_class_id
	elif remote_players.has(attacker_id) and is_instance_valid(remote_players[attacker_id]):
		atk_class = remote_players[attacker_id].current_class_id
	if not ClassPaths.is_legendary(atk_class):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_legendary_flash_at.get(attacker_id, -99.0)) < 2.0:
		return
	_legendary_flash_at[attacker_id] = now
	var flash_col: Color = Color(0.29, 0.08, 0.55, 0.7) if atk_class == 34 else Color(1.0, 0.84, 0.3, 0.6)
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = flash_col
	layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 1.2)
	tw.tween_callback(layer.queue_free)
	show_loot_toast("⚡ PODER LENDÁRIO: %s desencadeou sua Ultimate!" % ClassPaths.CLASS_NAMES[atk_class])

func _on_combat_event_received(attacker_id: int, target_id: int, action_type: int, damage: int, is_crit: int, target_hp: int, target_max_hp: int) -> void:
	if action_type == 5:
		_check_legendary_ultimate(attacker_id)
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
		my_sub_path = int(NetworkManager.player_sub_paths.get(player_id, 0))
		my_level = level
		my_hp = hp
		my_max_hp = max_hp
		my_stamina = stamina
		my_max_stamina = max_stamina
		my_buff_active = buff_active
		if local_player and is_instance_valid(local_player):
			local_player.apply_identity(race_id, class_id)
			local_player.set_path_info(class_tier, my_sub_path)
		_update_hud()

func _on_player_mana_received(player_id: int, mana: int, max_mana: int) -> void:
	if player_id != NetworkManager.my_player_id:
		return
	my_mana = mana
	my_max_mana = max_mana
	if mana_bar:
		mana_bar.max_value = max(1, my_max_mana)
		mana_bar.value = my_mana
	if mana_label:
		mana_label.text = "Mana: %d / %d" % [my_mana, my_max_mana]

## Barra de Mana (azul) logo abaixo da Stamina, no painel de status.
# ---------------------------------------------------------------------------
# Peso: HUD de carga e repasse para o LocalPlayer
# ---------------------------------------------------------------------------

func _setup_weight_warning() -> void:
	var vbox := get_node_or_null("HUD/PlayerStatusPanel/VBox")
	if not vbox:
		return
	weight_warning_label = Label.new()
	weight_warning_label.name = "WeightWarning"
	weight_warning_label.visible = false
	weight_warning_label.add_theme_font_size_override("font_size", 13)
	weight_warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	weight_warning_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(weight_warning_label)

func _on_wallet_weight_updated(_gold: int, _eclipse: int, cur_weight: float, p_max_weight: float, _speed: float) -> void:
	if local_player and is_instance_valid(local_player):
		local_player.set("current_weight", cur_weight)
		local_player.set("max_weight", p_max_weight)
	_update_weight_warning(cur_weight, p_max_weight)

func _update_weight_warning(cur_weight: float, p_max_weight: float) -> void:
	if weight_warning_label == null:
		return
	var ratio: float = cur_weight / max(1.0, p_max_weight)
	var pct: int = int(round(ratio * 100.0))
	if ratio < 0.70:
		weight_warning_label.visible = false
		return
	weight_warning_label.visible = true
	if ratio >= 1.30:
		weight_warning_label.text = "🛑 SOBRECARREGADO (%d%%) - Descarte itens para andar!" % pct
		weight_warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	elif ratio >= 1.00:
		weight_warning_label.text = "⚠️ Muito Pesado (%d%%) - sem esquiva" % pct
		weight_warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		weight_warning_label.text = "⚠️ Carga Pesada (%d%%)" % pct
		weight_warning_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))

# ---------------------------------------------------------------------------
# Itens no chão (0x42 GROUND_ITEMS_SYNC / 0x43 PICKUP_GROUND_ITEM)
# ---------------------------------------------------------------------------

func _ground_item_name(item_id: int) -> String:
	if inventory_ui and inventory_ui.get("ITEM_CATALOG") != null and inventory_ui.ITEM_CATALOG.has(item_id):
		return inventory_ui.ITEM_CATALOG[item_id]["name"]
	return ItemDataScript.info(item_id)["name"]

func _on_ground_items_received(items: Array) -> void:
	var seen: Dictionary = {}
	for it in items:
		var did: int = int(it["drop_id"])
		seen[did] = true
		ground_items_data[did] = it
		if not ground_items_nodes.has(did):
			var node := _create_ground_item_node(it)
			ground_items_nodes[did] = node
	for did in ground_items_nodes.keys():
		if not seen.has(did):
			var old = ground_items_nodes[did]
			if is_instance_valid(old):
				old.queue_free()
			ground_items_nodes.erase(did)
			ground_items_data.erase(did)

# Bolsa de couro rústica (ou arma brilhante, se for equipável) com anel dourado e rótulo flutuante
func _create_ground_item_node(it: Dictionary) -> Node3D:
	var item_id: int = int(it["id"])
	var qty: int = int(it["quantity"])
	var root := StaticBody3D.new()
	root.name = "GroundItem_%d" % int(it["drop_id"])
	root.collision_layer = 8
	root.collision_mask = 0
	root.set_meta("drop_id", int(it["drop_id"]))
	add_child(root)
	root.global_position = Vector3(float(it["x"]), ground_y(float(it["x"]), float(it["z"])), float(it["z"]))

	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.6
	shape.shape = sph
	shape.position = Vector3(0, 0.4, 0)
	root.add_child(shape)

	var is_gear: bool = ItemDataScript.slot_of(item_id) >= 0
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	if is_gear:
		# Arma/equipamento: lâmina deitada e brilhante
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.05, 1.0)
		blade.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.85, 0.88, 0.95)
		bmat.metallic = 0.9
		bmat.roughness = 0.2
		bmat.emission_enabled = true
		bmat.emission = Color(1.0, 0.85, 0.4)
		bmat.emission_energy_multiplier = 0.6
		blade.material_override = bmat
		blade.position = Vector3(0, 0.25, 0)
		blade.rotation_degrees = Vector3(0, 35, 0)
		model.add_child(blade)
		var hilt := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.4, 0.06, 0.08)
		hilt.mesh = hm
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.45, 0.3, 0.15)
		hilt.material_override = hmat
		hilt.position = Vector3(-0.2, 0.25, 0.28)
		hilt.rotation_degrees = Vector3(0, 35, 0)
		model.add_child(hilt)
	else:
		# Bolsa de couro amarrada
		var bag := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.5
		bag.mesh = sm
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.45, 0.3, 0.17)
		lmat.roughness = 0.85
		LunariaTextures.apply(lmat, "leather", 0.3, false)
		bag.material_override = lmat
		bag.position = Vector3(0, 0.25, 0)
		model.add_child(bag)
		var knot := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.12
		cm.height = 0.18
		knot.mesh = cm
		knot.material_override = lmat
		knot.position = Vector3(0, 0.55, 0)
		model.add_child(knot)

	# Anel de luz dourada no chão
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.68
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(1.0, 0.82, 0.3, 0.85)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.8, 0.3)
	ring.material_override = rmat
	ring.position = Vector3(0, 0.03, 0)
	root.add_child(ring)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.82, 0.4)
	glow.light_energy = 0.8
	glow.omni_range = 2.5
	glow.position = Vector3(0, 0.6, 0)
	root.add_child(glow)

	var lbl := Label3D.new()
	lbl.text = "🎒 %s x%d (%.1f kg) — %s %d\n[Aperte G ou Clique para Pegar]" % [_ground_item_name(item_id), qty, ItemDataScript.weight(item_id) * qty, ItemDataScript.quality_aspect(item_id), int(it.get("quality", 75))]
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.92, 0.65)
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 1.3, 0)
	root.add_child(lbl)

	# Flutua e gira devagar
	var tw := root.create_tween().set_loops()
	tw.tween_property(model, "position:y", 0.12, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(model, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	return root

# ---------------------------------------------------------------------------
# Materiais descobertos (0x46) e aviso dourado
# ---------------------------------------------------------------------------

func _setup_discovery_banner() -> void:
	var hud := get_node_or_null("HUD")
	if not hud:
		return
	discovery_banner = Label.new()
	discovery_banner.name = "DiscoveryBanner"
	discovery_banner.visible = false
	discovery_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discovery_banner.anchor_left = 0.0
	discovery_banner.anchor_right = 1.0
	discovery_banner.offset_top = 78
	discovery_banner.add_theme_font_size_override("font_size", 22)
	discovery_banner.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	discovery_banner.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.0))
	discovery_banner.add_theme_constant_override("outline_size", 8)
	hud.add_child(discovery_banner)

func _on_quest_state_received(_quest_id: int, stage: int, have: int, need: int) -> void:
	if quest_label == null:
		var vbox := get_node_or_null("HUD/PlayerStatusPanel/VBox")
		if not vbox:
			return
		quest_label = Label.new()
		quest_label.name = "QuestTracker"
		quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quest_label.custom_minimum_size = Vector2(320, 0)
		quest_label.add_theme_font_size_override("font_size", 12)
		quest_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
		vbox.add_child(quest_label)
	if stage == 0:
		quest_label.text = "📜 Missão disponível: fale com Garrick, o Ferreiro (E)"
	elif stage == 255:
		quest_label.text = "📜 O Aprendiz do Ferreiro — concluída!"
		var tw := create_tween()
		tw.tween_interval(6.0)
		tw.tween_callback(func(): quest_label.visible = false)
	elif QUEST_PARTS.has(stage):
		var part: Array = QUEST_PARTS[stage]
		var done_mark := " ✔ volte a Garrick!" if have >= need else ""
		quest_label.text = "📜 %s\n%s: %d/%d%s" % [part[0], part[1], have, need, done_mark]
	quest_label.visible = true

func _on_discovered_materials_received(mode: int, material_ids: Array) -> void:
	if mode == 0:
		discovered_materials.clear()
	for mid in material_ids:
		discovered_materials[int(mid)] = true
		if mode == 1:
			_discovery_queue.append(int(mid))
	if not _discovery_queue.is_empty() and discovery_banner and not discovery_banner.visible:
		_show_next_discovery()
	for nid in resource_nodes_nodes.keys():
		if resource_nodes_data.has(nid):
			_apply_node_state(resource_nodes_nodes[nid], resource_nodes_data[nid])

func _show_next_discovery() -> void:
	if _discovery_queue.is_empty() or discovery_banner == null:
		return
	var mid: int = _discovery_queue.pop_front()
	var mat: Dictionary = ItemDataScript.material(mid)
	var mat_name: String = mat.get("name", "Material #%d" % mid)
	discovery_banner.text = "✨ Novo Material Descoberto para Forja: %s! ✨\n%s • %s" % [
		mat_name, ItemDataScript.rarity_name(int(mat.get("rarity", 1))), mat.get("trait", "")]
	discovery_banner.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	discovery_banner.visible = true
	discovery_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(discovery_banner, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		discovery_banner.visible = false
		_show_next_discovery()
	)

func is_material_discovered(material_id: int) -> bool:
	return discovered_materials.has(material_id)

# ---------------------------------------------------------------------------
# Nós de coleta (0x45 RESOURCE_NODES_SYNC / 0x44 HARVEST_NODE)
# ---------------------------------------------------------------------------

func _node_requirement_text(data: Dictionary) -> String:
	var tier: int = int(data["tier"])
	match int(data["kind"]):
		1:
			return "[E] Cortar — Machado Tier %d+" % tier
		2, 3, 4:
			return "[E] Minerar — Picareta Tier %d+" % tier
		5:
			return "[E] Colher — arma cortante (Tesoura: x2)"
		6:
			return "[E] Coletar — Frasco Vazio"
		7:
			return "[E] Cavar barro/argila — às mãos (Picareta: +1)"
		8:
			return "[E] Recolher ossos — às mãos"
	return "[E] Coletar"

func _on_resource_nodes_received(nodes: Array) -> void:
	var seen: Dictionary = {}
	for nd in nodes:
		var nid: int = int(nd["node_id"])
		seen[nid] = true
		var changed: bool = not resource_nodes_data.has(nid) or bool(resource_nodes_data[nid]["available"]) != bool(nd["available"])
		resource_nodes_data[nid] = nd
		if not resource_nodes_nodes.has(nid):
			resource_nodes_nodes[nid] = _create_resource_node(nd)
		elif changed:
			_apply_node_state(resource_nodes_nodes[nid], nd)
	for nid in resource_nodes_nodes.keys():
		if not seen.has(nid):
			var old = resource_nodes_nodes[nid]
			if is_instance_valid(old):
				old.queue_free()
			resource_nodes_nodes.erase(nid)
			resource_nodes_data.erase(nid)

func _mat(col: Color, emissive: float = 0.0, rough: float = 0.85, tex: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emissive
	if tex != "":
		LunariaTextures.apply(m, tex, 0.8, false)
	return m

func _add_mesh(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.visibility_range_end = 140.0 # ~200 nós por zona: só desenha os próximos
	parent.add_child(mi)
	return mi

# Cor de cada material no mundo (madeira, metal, cristal, líquido...)
func _node_color(mat_id: int, kind: int) -> Color:
	var r: int = int(ItemDataScript.material(mat_id).get("rarity", 1))
	match kind:
		1:
			return [Color(0.25, 0.45, 0.2), Color(0.3, 0.42, 0.22), Color(0.35, 0.5, 0.65), Color(0.18, 0.12, 0.25), Color(0.6, 0.12, 0.12),
				Color(0.35, 0.35, 0.3), Color(1.0, 0.75, 0.25), Color(0.4, 1.0, 0.6)][clampi(r - 1, 0, 7)]
		3:
			var metal := {114: Color(0.85, 0.5, 0.3), 115: Color(0.75, 0.75, 0.72), 116: Color(0.45, 0.42, 0.4), 117: Color(0.9, 0.92, 0.95),
				118: Color(0.6, 0.65, 0.7), 119: Color(0.6, 0.8, 1.0), 120: Color(0.9, 0.25, 0.2), 121: Color(0.3, 0.3, 0.4), 122: Color(0.75, 1.0, 0.95),
				158: Color(0.62, 0.68, 0.75), 159: Color(1.0, 0.82, 0.25)}
			return metal.get(mat_id, Color(0.6, 0.6, 0.6))
		4:
			var crys := {123: Color(0.92, 0.92, 1.0), 124: Color(0.4, 0.6, 1.0), 125: Color(1.0, 0.2, 0.15), 126: Color(0.5, 0.85, 1.0), 127: Color(0.35, 0.1, 0.45)}
			return crys.get(mat_id, Color(0.8, 0.8, 1.0))
		6:
			var liq := {145: Color(0.35, 0.65, 1.0), 146: Color(0.4, 0.8, 0.2), 147: Color(0.85, 0.9, 1.0), 153: Color(0.9, 0.9, 0.2)}
			return liq.get(mat_id, Color(0.4, 0.6, 1.0))
		7:
			return Color(0.45, 0.32, 0.22) if mat_id == 156 else Color(0.72, 0.5, 0.36)
		8:
			return Color(0.88, 0.85, 0.76)
	return ItemDataScript.rarity_color(r)

## Flora coletável (materials.go): cor das flores de cada planta.
const FLORA_COLORS := {
	98: Color(0.85, 0.88, 1.0), 99: Color(1.0, 0.9, 0.95), 191: Color(0.75, 0.8, 0.82), 192: Color(0.7, 0.1, 0.2),
	193: Color(1.0, 0.45, 0.1), 194: Color(0.65, 0.85, 1.0), 195: Color(0.75, 0.4, 0.85), 196: Color(0.5, 0.7, 0.4),
	197: Color(0.25, 0.55, 0.2), 198: Color(1.0, 0.82, 0.2),
}

func _create_resource_node(nd: Dictionary) -> Node3D:
	var kind: int = int(nd["kind"])
	var mat_id: int = int(nd["material"])
	var col: Color = _node_color(mat_id, kind)
	var rarity: int = int(ItemDataScript.material(mat_id).get("rarity", 1))
	var glow: float = 0.0 if rarity < 3 else 0.25 + 0.15 * rarity
	var root := StaticBody3D.new()
	root.name = "ResourceNode_%d" % int(nd["node_id"])
	root.collision_layer = 1
	root.collision_mask = 0
	add_child(root)
	root.global_position = Vector3(float(nd["x"]), ground_y(float(nd["x"]), float(nd["z"])), float(nd["z"]))
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var shape := CollisionShape3D.new()

	match kind:
		1: # Árvore: tronco + copas
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.28
			trunk.bottom_radius = 0.4
			trunk.height = 3.6
			_add_mesh(model, trunk, _mat(Color(0.35, 0.24, 0.15), 0.0, 0.9, "bark"), Vector3(0, 1.8, 0))
			var crown := SphereMesh.new()
			crown.radius = 1.6
			crown.height = 2.6
			var leaf_mat := _mat(col, glow, 0.9, "leaf")
			_add_mesh(model, crown, leaf_mat, Vector3(0, 4.2, 0))
			_add_mesh(model, crown, leaf_mat, Vector3(0.7, 3.6, 0.4), Vector3.ZERO, Vector3(0.7, 0.7, 0.7))
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.45
			cyl.height = 3.6
			shape.shape = cyl
			shape.position = Vector3(0, 1.8, 0)
		2, 3, 4: # Rocha / veio / cristal
			var rock := SphereMesh.new()
			rock.radius = 0.9
			rock.height = 1.3
			var rock_col := Color(0.42, 0.4, 0.38) if kind != 2 else col.lerp(Color(0.5, 0.48, 0.45), 0.6)
			_add_mesh(model, rock, _mat(rock_col, 0.0, 0.95, "stone"), Vector3(0, 0.45, 0), Vector3(0, 20, 0), Vector3(1.3, 1.0, 1.1))
			if kind != 2:
				var shard := PrismMesh.new()
				shard.size = Vector3(0.25, 0.8, 0.25)
				var shard_mat := _mat(col, glow + (0.6 if kind == 4 else 0.1), 0.25)
				shard_mat.metallic = 0.9 if kind == 3 else 0.1
				for i in range(4 if kind == 4 else 3):
					var a: float = float(i) * 1.7
					_add_mesh(model, shard, shard_mat, Vector3(cos(a) * 0.55, 0.85, sin(a) * 0.45), Vector3(15 * cos(a), 0, 15 * sin(a)))
			var sph := SphereShape3D.new()
			sph.radius = 0.95
			shape.shape = sph
			shape.position = Vector3(0, 0.5, 0)
		5 when FLORA_COLORS.has(mat_id): # Flora coletável: tufo baixo com flores da cor da planta
			var leaf := SphereMesh.new()
			leaf.radius = 0.45
			leaf.height = 0.45
			_add_mesh(model, leaf, _mat(Color(0.22, 0.42, 0.18), 0.0, 0.9, "leaf"), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.2))
			var petal := SphereMesh.new()
			petal.radius = 0.12
			petal.height = 0.12
			var flower_mat := _mat(FLORA_COLORS[mat_id], glow + 0.15, 0.6)
			for i in range(6):
				var a3: float = float(i) * 1.05
				_add_mesh(model, petal, flower_mat, Vector3(cos(a3) * 0.32, 0.45 + 0.05 * (i % 2), sin(a3) * 0.32))
			var sph5 := SphereShape3D.new()
			sph5.radius = 0.45
			shape.shape = sph5
			shape.position = Vector3(0, 0.3, 0)
		5: # Vinha / arbusto / cogumelo
			var bush := SphereMesh.new()
			bush.radius = 0.7
			bush.height = 1.0
			_add_mesh(model, bush, _mat(Color(0.2, 0.4, 0.15), 0.0, 0.9, "leaf"), Vector3(0, 0.45, 0))
			var stem := CylinderMesh.new()
			stem.top_radius = 0.04
			stem.bottom_radius = 0.06
			stem.height = 1.6
			var vine_mat := _mat(col, glow + 0.2, 0.7)
			for i in range(5):
				var a2: float = float(i) * 1.25
				_add_mesh(model, stem, vine_mat, Vector3(cos(a2) * 0.35, 0.8, sin(a2) * 0.35), Vector3(25 * sin(a2), 0, 25 * cos(a2)))
			var sph2 := SphereShape3D.new()
			sph2.radius = 0.6
			shape.shape = sph2
			shape.position = Vector3(0, 0.5, 0)
		7: # Barreiro: montes de barro/argila molhada na margem do rio
			var mud_mat := _mat(col, 0.0, 0.35)
			for i in range(3):
				var lump := SphereMesh.new()
				lump.radius = 0.55 - i * 0.1
				lump.height = 0.5 - i * 0.08
				_add_mesh(model, lump, mud_mat, Vector3(cos(i * 2.1) * 0.45, 0.15, sin(i * 2.1) * 0.45))
			var sph7 := SphereShape3D.new()
			sph7.radius = 0.7
			shape.shape = sph7
			shape.position = Vector3(0, 0.3, 0)
		8: # Ossada: costelas e um crânio de fera semienterrados
			var bone_mat := _mat(col, 0.0, 0.7)
			for i in range(4):
				var rib := CylinderMesh.new()
				rib.top_radius = 0.05
				rib.bottom_radius = 0.07
				rib.height = 0.9
				_add_mesh(model, rib, bone_mat, Vector3(-0.45 + i * 0.3, 0.3, 0), Vector3(0, 0, 35))
			var skull := SphereMesh.new()
			skull.radius = 0.28
			skull.height = 0.45
			_add_mesh(model, skull, bone_mat, Vector3(0.75, 0.2, 0.2))
			var sph8 := SphereShape3D.new()
			sph8.radius = 0.6
			shape.shape = sph8
			shape.position = Vector3(0, 0.3, 0)
		_: # Fonte de água / ácido / orvalho
			var pool := CylinderMesh.new()
			pool.top_radius = 1.0
			pool.bottom_radius = 1.0
			pool.height = 0.06
			var liq_mat := _mat(col, 0.6, 0.05)
			liq_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			liq_mat.albedo_color.a = 0.75
			_add_mesh(model, pool, liq_mat, Vector3(0, 0.04, 0))
			var rim := TorusMesh.new()
			rim.inner_radius = 0.95
			rim.outer_radius = 1.2
			_add_mesh(model, rim, _mat(Color(0.45, 0.43, 0.4), 0.0, 0.95, "stone"), Vector3(0, 0.05, 0))
			var sph3 := SphereShape3D.new()
			sph3.radius = 0.3
			shape.shape = sph3
	root.add_child(shape)

	var lbl := Label3D.new()
	lbl.name = "Label"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 32
	lbl.pixel_size = 0.0045
	lbl.outline_size = 10
	lbl.visibility_range_end = 22.0
	lbl.position = Vector3(0, 5.6 if kind == 1 else 2.0, 0)
	root.add_child(lbl)
	root.set_meta("label", lbl)
	_apply_node_state(root, nd)
	return root

func _apply_node_state(root: Node3D, nd: Dictionary) -> void:
	if not is_instance_valid(root):
		return
	var mat_id: int = int(nd["material"])
	var mat: Dictionary = ItemDataScript.material(mat_id)
	var rarity: int = int(mat.get("rarity", 1))
	var available: bool = bool(nd["available"])
	var model: Node3D = root.get_node_or_null("Model")
	if model:
		model.scale = Vector3.ONE if available else Vector3(0.45, 0.45, 0.45)
	var lbl: Label3D = root.get_meta("label")
	if lbl:
		var mat_name: String = mat.get("name", "Recurso")
		# Material ainda não encontrado: nenhum texto; o nome aparece depois da primeira coleta
		lbl.visible = is_material_discovered(mat_id)
		if available:
			lbl.text = "%s [%s]\n%s" % [mat_name, ItemDataScript.rarity_name(rarity), _node_requirement_text(nd)]
			lbl.modulate = ItemDataScript.rarity_color(rarity).lightened(0.2)
		else:
			lbl.text = "%s\n(coletado — volta a crescer em breve)" % mat_name
			lbl.modulate = Color(0.6, 0.6, 0.6)

func _clear_resource_nodes() -> void:
	for nid in resource_nodes_nodes.keys():
		var n = resource_nodes_nodes[nid]
		if is_instance_valid(n):
			n.queue_free()
	resource_nodes_nodes.clear()
	resource_nodes_data.clear()

# Tecla E: coleta o nó disponível mais próximo (até 3,5 m)
func _try_harvest_nearest_node() -> bool:
	if not local_player or resource_nodes_nodes.is_empty():
		return false
	var best_id: int = -1
	var best_dist: float = HARVEST_RANGE
	for nid in resource_nodes_nodes.keys():
		var n = resource_nodes_nodes[nid]
		if not is_instance_valid(n):
			continue
		var p1: Vector3 = local_player.global_position
		var p2: Vector3 = n.global_position
		var d: float = Vector2(p1.x - p2.x, p1.z - p2.z).length()
		if d <= best_dist:
			best_dist = d
			best_id = nid
	if best_id < 0:
		return false
	NetworkManager.send_harvest_node(best_id)
	return true

func _clear_ground_items() -> void:
	for did in ground_items_nodes.keys():
		var n = ground_items_nodes[did]
		if is_instance_valid(n):
			n.queue_free()
	ground_items_nodes.clear()
	ground_items_data.clear()

# Tecla G: pega o item mais próximo a até 3,5 m
func _try_pickup_nearest_ground_item() -> bool:
	if not local_player or ground_items_nodes.is_empty():
		return false
	var best_id: int = -1
	var best_dist: float = GROUND_PICKUP_RANGE
	for did in ground_items_nodes.keys():
		var n = ground_items_nodes[did]
		if not is_instance_valid(n):
			continue
		var d: float = local_player.global_position.distance_to(n.global_position)
		if d <= best_dist:
			best_dist = d
			best_id = did
	if best_id < 0:
		return false
	NetworkManager.send_pickup_ground_item(best_id)
	return true

# Clique do mouse (cursor livre) sobre uma bolsa no chão
func _try_pickup_ground_item_at_screen(screen_pos: Vector2) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not local_player:
		return false
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit["collider"].has_meta("drop_id"):
		return false
	var node: Node3D = hit["collider"]
	if local_player.global_position.distance_to(node.global_position) > GROUND_PICKUP_RANGE:
		show_loot_toast("Chegue mais perto para pegar (até 3,5 m).")
		return true
	NetworkManager.send_pickup_ground_item(int(node.get_meta("drop_id")))
	return true

func _setup_mana_bar() -> void:
	var vbox := get_node_or_null("HUD/PlayerStatusPanel/VBox")
	var stam_label := get_node_or_null("HUD/PlayerStatusPanel/VBox/StaminaLabel")
	if not vbox or not stam_label:
		return
	mana_bar = ProgressBar.new()
	mana_bar.name = "ManaBar"
	mana_bar.custom_minimum_size = Vector2(0, 12)
	mana_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.12, 0.85)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.45, 1.0, 1.0)
	fill.set_corner_radius_all(3)
	mana_bar.add_theme_stylebox_override("background", bg)
	mana_bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(mana_bar)
	vbox.move_child(mana_bar, stam_label.get_index() + 1)
	mana_label = Label.new()
	mana_label.name = "ManaLabel"
	mana_label.text = "Mana: 0 / 0"
	mana_label.add_theme_font_size_override("font_size", 12)
	mana_label.add_theme_color_override("font_color", Color(0.7, 0.82, 1.0))
	vbox.add_child(mana_label)
	vbox.move_child(mana_label, mana_bar.get_index() + 1)

	# Sobrevivência (0x50): fome e temperatura corporal
	hunger_bar = ProgressBar.new()
	hunger_bar.name = "HungerBar"
	hunger_bar.custom_minimum_size = Vector2(220, 8)
	hunger_bar.show_percentage = false
	hunger_bar.max_value = 100
	hunger_bar.value = 100
	var h_bg := StyleBoxFlat.new()
	h_bg.bg_color = Color(0.12, 0.1, 0.06, 0.85)
	h_bg.set_corner_radius_all(3)
	var h_fill := StyleBoxFlat.new()
	h_fill.bg_color = Color(0.95, 0.6, 0.15)
	h_fill.set_corner_radius_all(3)
	hunger_bar.add_theme_stylebox_override("background", h_bg)
	hunger_bar.add_theme_stylebox_override("fill", h_fill)
	vbox.add_child(hunger_bar)
	vbox.move_child(hunger_bar, mana_label.get_index() + 1)
	survival_label = Label.new()
	survival_label.name = "SurvivalLabel"
	survival_label.text = "Fome: 100% | Temperatura: --"
	survival_label.add_theme_font_size_override("font_size", 12)
	survival_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	vbox.add_child(survival_label)
	vbox.move_child(survival_label, hunger_bar.get_index() + 1)

func _on_player_respawn_received(player_id: int, respawn_pos: Vector3) -> void:
	if player_id == NetworkManager.my_player_id:
		print("[World] Respawn autoritativo recebido! Posicionando no Centro: ", respawn_pos)
		if local_player and is_instance_valid(local_player):
			local_player.global_position = Vector3(respawn_pos.x, maxf(respawn_pos.y, ground_y(respawn_pos.x, respawn_pos.z) + 1.5), respawn_pos.z)
			local_player.velocity = Vector3.ZERO
		_update_hud()
	elif remote_players.has(player_id) and is_instance_valid(remote_players[player_id]):
		remote_players[player_id].global_position = respawn_pos

func _get_evolved_class_name(cid: int, tier: int) -> String:
	if cid == 0:
		return "Viajante (Sem Classe)"
	# Classes Básicas a partir do Tier 2: título do Caminho Evolutivo escolhido
	if ClassPaths.has_paths(cid) and tier >= 2 and cid < CLASS_NAMES.size():
		var path_name: String = ClassPaths.path_title(cid, tier, my_sub_path)
		if path_name != "":
			return "%s — %s" % [CLASS_NAMES[cid], path_name]
		return "%s (escolha seu Caminho)" % CLASS_NAMES[cid]
	if EVOLVED_CLASS_NAMES.has(cid):
		var names_list: Array = EVOLVED_CLASS_NAMES[cid]
		var safe_tier: int = clamp(tier, 1, names_list.size() - 1)
		return names_list[safe_tier]
	if cid >= 1 and cid < CLASS_NAMES.size():
		return CLASS_NAMES[cid]
	return "Classe #%d" % cid

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
	action_bar_cd_labels.clear()

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

		# Recarga: número grande por cima do slot, que escurece enquanto conta
		var cd_lbl := Label.new()
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 22)
		cd_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		cd_lbl.add_theme_constant_override("outline_size", 6)
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_lbl.visible = false
		slot.add_child(cd_lbl)
		action_bar_cd_labels.append(cd_lbl)

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

## Atualiza a recarga visível de cada slot (chamado a cada quadro).
func _update_action_bar_cooldowns() -> void:
	if action_bar_cd_labels.size() < ACTION_BAR_IDS.size() or local_player == null or not is_instance_valid(local_player):
		return
	if not local_player.has_method("action_cooldown_left"):
		return
	for i in range(ACTION_BAR_IDS.size()):
		var left: float = local_player.action_cooldown_left(ACTION_BAR_IDS[i])
		var lbl: Label = action_bar_cd_labels[i]
		var slot: PanelContainer = action_bar_slots[i]
		if left > 0.05 and ACTION_BAR_IDS[i] != 1:
			lbl.visible = true
			lbl.text = "%.1f" % left if left < 10.0 else "%d" % int(ceil(left))
			slot.self_modulate = Color(0.45, 0.45, 0.5, 1.0)
		else:
			lbl.visible = false
			slot.self_modulate = Color(1, 1, 1, 1)

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
				n.update_network_transform(on_ground(data.position), data.rotation_y, data.state)
		else:
			_spawn_npc(nid, on_ground(data.position), data.rotation_y, data.state)

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
	elif nid >= 111 and nid <= 116:
		p_name = NPCEntityScript.get_default_npc_name(nid)
		script_path = "scripts/npcs/%s.lua" % ["nyx", "tao", "iolanthe", "fiorella", "bartolomeu", "thorne"][nid - 111]
	else:
		p_name = NPCEntityScript.get_default_npc_name(nid) # aprendizes, Coveiro, Joalheira, caçadores

	if npc_inst.has_method("set_npc_info"):
		npc_inst.set_npc_info(nid, p_name, script_path)
	elif "npc_name" in npc_inst:
		npc_inst.npc_name = p_name
		npc_inst.npc_id = nid

	if npc_inst.has_method("set_friendship"):
		npc_inst.set_friendship(get_npc_friendship(nid))

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
		elif (npc_id >= 111 and npc_id <= 123) or (npc_id >= 400 and npc_id < 430):
			sender_name = NPCEntityScript.get_default_npc_name(npc_id).split("\n")[0]
		dialogue_label.text = "[%s]: %s" % [sender_name, message]
		dialogue_label.visible = true
		dialogue_clear_timer.start(8.0)

func _on_dialogue_clear_timeout() -> void:
	if dialogue_label:
		dialogue_label.visible = false

func get_npc_friendship(npc_id: int) -> int:
	return npc_friendships.get(npc_id, 0)

func set_npc_friendship(npc_id: int, points: int) -> void:
	var clamped_pts := clampi(points, 0, 100)
	npc_friendships[npc_id] = clamped_pts
	if npcs.has(npc_id) and is_instance_valid(npcs[npc_id]):
		if npcs[npc_id].has_method("set_friendship"):
			npcs[npc_id].set_friendship(clamped_pts)
	if class_master_ui and class_master_ui.has_method("update_friendship_display"):
		if class_master_ui.get("current_npc_id") == npc_id:
			class_master_ui.update_friendship_display()

func _on_npc_friendship_received(npc_id: int, points: int, _level: int) -> void:
	set_npc_friendship(npc_id, points)

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

	var fx: Dictionary = WEATHER_FX.get(current_weather_type, WEATHER_FX[0])
	target_fog_density = fx.get("fog", 0.0001)
	target_fog_color = fx.get("fog_col", target_fog_color)
	day_energy *= float(fx.get("light", 1.0))
	if fx.has("amb"):
		day_ambient = day_ambient.lerp(fx["amb"], 0.6)
	if fx.has("horiz"):
		day_sky_horiz = day_sky_horiz.lerp(fx["horiz"], 0.6)
	if fx.has("night_amb"):
		night_ambient = night_ambient.lerp(fx["night_amb"], 0.7)
	if fx.has("night_horiz"):
		night_sky_horiz = night_sky_horiz.lerp(fx["night_horiz"], 0.7)

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

	_update_weather_particles(delta)

# Liga/desliga as partículas de cada clima e as faz seguir o jogador.
func _update_weather_particles(delta: float) -> void:
	var fx: Dictionary = WEATHER_FX.get(current_weather_type, WEATHER_FX[0])
	if rain_particles:
		var rain_level: float = float(fx.get("rain", 0.0))
		var should_rain: bool = rain_level > 0.0
		if should_rain:
			rain_particles.amount_ratio = clampf(rain_level / 2.5, 0.15, 1.0)
			if current_weather_type == 15:
				rain_particles.color = Color(0.7, 0.9, 0.3)
			else:
				rain_particles.color = Color(1, 1, 1)
		if rain_particles.emitting != should_rain:
			rain_particles.emitting = should_rain

	var wanted: String = fx.get("fx", "")
	if wanted != "" and not weather_particles.has(wanted):
		weather_particles[wanted] = _create_weather_particles(wanted)
	for key in weather_particles.keys():
		var part: CPUParticles3D = weather_particles[key]
		if not is_instance_valid(part):
			continue
		var on: bool = (key == wanted)
		if part.emitting != on:
			part.emitting = on
		if on and local_player:
			var p_pos: Vector3 = local_player.global_position
			var conf: Dictionary = WEATHER_PARTICLES[key]
			var h := 14.0
			if conf.get("low", false):
				h = 2.0
			elif conf.get("high", false):
				h = 45.0
			part.global_position = Vector3(p_pos.x, p_pos.y + h, p_pos.z)

	# Relâmpagos (Tempestade de Raios e Tempestade Arcana)
	if fx.get("flash", false) and sun_light:
		weather_flash_timer -= delta
		if weather_flash_timer <= 0.0:
			weather_flash_timer = randf_range(3.0, 9.0)
			sun_light.light_energy += 2.5
			if current_weather_type == 21:
				sun_light.light_color = Color(0.7, 0.5, 1.0)

func _create_weather_particles(fx_name: String) -> CPUParticles3D:
	var conf: Dictionary = WEATHER_PARTICLES[fx_name]
	var part := CPUParticles3D.new()
	part.name = "Weather_" + fx_name
	part.emitting = false
	part.amount = int(conf["amount"])
	part.lifetime = float(conf["life"])
	part.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var low: bool = conf.get("low", false)
	part.emission_box_extents = Vector3(45, 2.5 if low else 1.0, 45)
	var speed: float = float(conf["speed"])
	var drift: Vector3 = conf["drift"]
	var dir := Vector3(drift.x, -speed, drift.z)
	if dir.length() < 0.01:
		dir = Vector3(0, 1, 0)
	part.direction = dir.normalized()
	part.spread = 25.0 if conf.get("wander", false) else 6.0
	part.initial_velocity_min = maxf(dir.length() * 0.8, 0.2)
	part.initial_velocity_max = maxf(dir.length() * 1.2, 0.5)
	part.gravity = Vector3.ZERO
	if conf.get("wander", false):
		part.orbit_velocity_min = -0.05
		part.orbit_velocity_max = 0.05
	var quad := QuadMesh.new()
	var sz: float = float(conf["size"])
	quad.size = Vector2(sz, sz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = conf["col"]
	if conf.get("emissive", false):
		mat.emission_enabled = true
		mat.emission = conf["col"]
		mat.emission_energy_multiplier = 2.0
	quad.material = mat
	part.mesh = quad
	var col: Color = conf["col"]
	if conf.has("glow"):
		var grad := Gradient.new()
		grad.set_color(0, conf["glow"])
		grad.set_color(1, col)
		part.color_ramp = grad
	else:
		var fade := Gradient.new()
		fade.set_color(0, Color(col.r, col.g, col.b, 0.0))
		fade.add_point(0.15, col)
		fade.add_point(0.85, col)
		fade.set_color(1, Color(col.r, col.g, col.b, 0.0))
		part.color_ramp = fade
	add_child(part)
	return part

func _on_mob_state_received(mobs_dict: Dictionary) -> void:
	for mid in mobs_dict.keys():
		var mdata: Dictionary = mobs_dict[mid]
		if mobs.has(mid):
			var mob_node = mobs[mid]
			if is_instance_valid(mob_node):
				mob_node.update_network_data(on_ground(mdata.position), mdata.rotation_y, mdata.state, mdata.hp, mdata.max_hp)
				mob_node.set_moon_phase(current_moon_phase)
		else:
			_spawn_mob(mid, mdata.type, on_ground(mdata.position), mdata.rotation_y, mdata.state, mdata.hp, mdata.max_hp)

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
	telegraph_root.position = Vector3(pos_x, ground_y(pos_x, pos_z) + 0.08, pos_z)
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

# =============================================================================
# SISTEMA DE GERENCIAMENTO DINÂMICO DE ZONAS & PORTAIS (PARTE 1B)
# =============================================================================

func _on_zone_change_received(target_zone_id: int, portal_id: int) -> void:
	print("[World] Confirmação de mudança de zona do servidor: Zona %d (Portal %d)" % [target_zone_id, portal_id])
	if target_zone_id != current_zone_id or current_map_root == null:
		_load_zone_map(target_zone_id)

func _trigger_zone_fade() -> void:
	if not screen_fade_rect or not is_instance_valid(screen_fade_rect):
		var canvas := CanvasLayer.new()
		canvas.layer = 120
		add_child(canvas)
		screen_fade_rect = ColorRect.new()
		screen_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_fade_rect.color = Color(0.04, 0.05, 0.08, 0.0)
		screen_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(screen_fade_rect)

	var tween := create_tween()
	tween.tween_property(screen_fade_rect, "color:a", 0.95, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.08)
	tween.tween_property(screen_fade_rect, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _cleanup_zone_entities(_target_zone_id: int) -> void:
	# 0. Itens no chão e nós de coleta da zona anterior (o servidor envia os da nova zona)
	_clear_ground_items()
	_clear_resource_nodes()

	# 1. Remove cadáveres da zona anterior
	for cid in corpses.keys():
		var c = corpses[cid]
		if is_instance_valid(c):
			c.queue_free()
	corpses.clear()

	# 2. Remove monstros da zona anterior
	for mid in mobs.keys():
		var m = mobs[mid]
		if is_instance_valid(m):
			m.queue_free()
	mobs.clear()

	# 3. Remove projéteis ativos
	for pid in active_projectiles.keys():
		var p_entry = active_projectiles[pid]
		if p_entry and is_instance_valid(p_entry.get("node")):
			p_entry["node"].queue_free()
	active_projectiles.clear()

	# 4. Remove jogadores remotos da zona anterior (o servidor reenviará apenas os da nova zona)
	for rpid in remote_players.keys():
		var rp = remote_players[rpid]
		if is_instance_valid(rp):
			rp.queue_free()
	remote_players.clear()

	# 5. Remove NPCs antigos (o servidor reenviará apenas os da nova zona via snapshot 30Hz)
	for nid in npcs.keys():
		var n = npcs[nid]
		if is_instance_valid(n):
			n.queue_free()
	npcs.clear()

func _load_zone_map(zone_id: int) -> void:
	print("[World] Carregando Zona %d com Unload total da zona anterior..." % zone_id)
	current_zone_id = zone_id

	# 1. Destruição do mapa anterior (Unload total de geometria, colisores e luzes)
	if current_map_root and is_instance_valid(current_map_root):
		current_map_root.queue_free()

	# 2. Criação do novo nó container limpo
	current_map_root = Node3D.new()
	current_map_root.name = "ZoneMapRoot_Zone%d" % zone_id
	add_child(current_map_root)

	# 3. Limpeza de entidades visuais da zona anterior
	_cleanup_zone_entities(zone_id)

	# 4. Efeito de fade cinematográfico rápido
	_trigger_zone_fade()

	# 5. Construção modular da geometria exclusiva da zona atual
	match zone_id:
		0:
			_build_zone_0_village(current_map_root)
		1:
			_build_zone_1_forest(current_map_root)
		2:
			_build_zone_2_ruins(current_map_root)
		3:
			_build_zone_3_sanctuary(current_map_root)
		4:
			_build_zone_4_ashlands(current_map_root)
		5:
			_build_zone_5_church(current_map_root)
		6:
			_build_zone_6_mage_tower(current_map_root)
		7:
			_build_zone_7_black_market(current_map_root)
		8:
			_build_zone_8_sewers(current_map_root)
		9, 10, 11, 12, 13, 14, 15, 16:
			_build_transition_zone(current_map_root, zone_id)
		17, 18, 19, 20, 21, 22, 23:
			_build_interior(current_map_root, zone_id)
		_:
			_build_zone_0_village(current_map_root)

	# 6. Texturas PBR em pisos, muros e estruturas da zona
	_texture_zone_map(current_map_root, zone_id)

	# 7. Mundo vivo: relevo, rio, estradas, vegetação, cavernas e fauna (zonas abertas)
	_build_living_landscape(zone_id)

# Piso de cada zona: [textura, metros por repetição]
const ZONE_FLOOR_TEXTURES := {
	0: ["ground", 3.0], 1: ["moss", 2.0], 2: ["stone_blocks", 2.4], 3: ["marble", 2.0],
	4: ["obsidian", 2.5], 5: ["marble", 1.6], 6: ["stone_blocks", 1.8], 7: ["planks", 1.4], 8: ["stone_blocks", 2.0],
	17: ["stone_blocks", 1.6], 18: ["planks", 1.4], 19: ["planks", 1.4], 20: ["stone_blocks", 1.6],
	21: ["planks", 1.4], 22: ["marble", 1.6], 23: ["planks", 1.4],
}

## Percorre a geometria da zona e aplica a biblioteca LunariaTextures a todo material liso,
## escolhendo a textura pela cor e forma (madeira, pedra, folhagem, telhado, mármore...).
## Brilhos, vidros e efeitos (emissivos/transparentes/sem sombreamento) ficam intocados.
func _texture_zone_map(root: Node3D, zone_id: int) -> void:
	var stack: Array = [root]
	var done: Dictionary = {}
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or done.has(mat):
			continue
		done[mat] = true
		if mat.albedo_texture != null or mat.emission_enabled or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			continue
		var tex_info: Array = _pick_zone_texture(mi, mat.albedo_color, zone_id)
		if tex_info.is_empty():
			continue
		LunariaTextures.apply(mat, tex_info[0], tex_info[1], tex_info[2])

func _pick_zone_texture(mi: MeshInstance3D, col: Color, zone_id: int) -> Array:
	if mi.get_parent() and mi.get_parent().name == "ZoneFloor":
		var f: Array = ZONE_FLOOR_TEXTURES.get(zone_id, ["ground", 3.0])
		return [f[0], f[1], true]
	var aabb := mi.mesh.get_aabb()
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var big: bool = longest > 4.0
	var h: float = col.h
	var sat: float = col.s
	var val: float = col.v
	var is_sphere: bool = mi.mesh is SphereMesh
	var is_prism: bool = mi.mesh is PrismMesh
	# Telhados
	if is_prism:
		return ["roof_tiles", 1.6, false]
	# Cinzas / pedras / metais neutros
	if sat < 0.22:
		if val < 0.16:
			return ["obsidian", 1.0, big]
		if val > 0.7 and (zone_id == 3 or zone_id == 5):
			return ["marble", 1.2, big]
		if big:
			return ["stone_blocks", 2.4, true]
		return ["stone", 0.9, false]
	# Verdes: folhagem e musgo
	if h > 0.18 and h < 0.48:
		if is_sphere:
			return ["leaf", 0.6, false]
		return ["moss", 1.0, big]
	# Marrons / laranjas: madeira, tábuas e reboco
	if h >= 0.04 and h <= 0.15:
		if val > 0.62 and sat < 0.45:
			return ["plaster", 1.5, big]
		if big:
			return ["planks", 1.2, true]
		return ["wood", 0.6, false]
	# Vermelhos fortes: tecidos e toldos
	if (h < 0.04 or h > 0.94) and sat > 0.4:
		return ["cloth", 0.6, big]
	# Roxos/azuis escuros: cristais e pedra mística
	if val < 0.35:
		return ["stone", 0.9, big]
	return ["stone_blocks", 1.6, big]

func _create_zone_floor(parent: Node3D, size: Vector3, col: Color, roughness: float = 0.85, uv_scale: Vector3 = Vector3(1, 1, 1)) -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.name = "ZoneFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	parent.add_child(floor_body)

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	col_shape.position = Vector3(0, -size.y / 2.0, 0)
	floor_body.add_child(col_shape)

	var mesh_inst := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = size
	mesh_inst.mesh = bmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = roughness
	mat.uv1_scale = uv_scale
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0, -size.y / 2.0, 0)
	floor_body.add_child(mesh_inst)

	return floor_body

func _create_portal_area(parent: Node3D, pos: Vector3, label_text: String, color: Color, target_zone: int, portal_id: int, night_only: bool = false) -> Area3D:
	var portal := Area3D.new()
	portal.name = "Portal_%d_to_%d" % [portal_id, target_zone]
	portal.position = pos
	portal.collision_layer = 0
	portal.collision_mask = 2 | 1
	parent.add_child(portal)

	var col := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 2.4
	cylinder.height = 3.2
	col.shape = cylinder
	col.position = Vector3(0, 1.6, 0)
	portal.add_child(col)

	# Portal discreto: sem disco, feixe ou luz — só uma plaquinha que aparece de perto
	# Placa flutuante Billboard
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.text = label_text
	lbl.font_size = 14
	lbl.outline_size = 5
	lbl.outline_modulate = Color.BLACK
	lbl.modulate = Color(color.lightened(0.4), 0.75)
	lbl.position = Vector3(0, 2.4, 0)
	lbl.visibility_range_end = 14.0
	portal.add_child(lbl)

	portal.body_entered.connect(func(body: Node3D):
		if body == local_player:
			_on_portal_body_entered(target_zone, portal_id, night_only)
	)

	return portal

func _on_portal_body_entered(target_zone: int, portal_id: int, night_only: bool) -> void:
	if portal_cooldown > 0.0:
		return

	if night_only:
		if current_world_hour >= 6 and current_world_hour < 18:
			var warning_msg := "O Beco está deserto à luz do sol. O Mercado Negro só abre suas portas à noite (18h às 06h)!"
			show_loot_toast(warning_msg)
			if dialogue_label and dialogue_clear_timer:
				dialogue_label.text = "[Mercado Negro] " + warning_msg
				dialogue_label.visible = true
				dialogue_clear_timer.start(4.0)
			return

	portal_cooldown = 2.5
	print("[World] Atravessando portal %d para Zona %d..." % [portal_id, target_zone])
	NetworkManager.send_portal_travel(target_zone, portal_id)

func _create_shop_counter_area(parent: Node3D, pos: Vector3, shop_name: String) -> Area3D:
	var area := Area3D.new()
	area.name = shop_name.replace(" ", "_") + "_CounterArea"
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2 | 1
	parent.add_child(area)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.5, 2.8, 3.5)
	col.shape = box
	col.position = Vector3(0, 1.4, 0)
	area.add_child(col)

	area.body_entered.connect(func(body: Node3D):
		if body == local_player:
			if current_world_hour < 6 or current_world_hour >= 18:
				var warning_text := "🔒 A Loja está fechada no momento! O Mestre saiu para a Taverna/Descanso (Horário de funcionamento: 06h às 18h)."
				show_loot_toast(warning_text)
				if dialogue_label and dialogue_clear_timer:
					dialogue_label.text = "[%s] %s" % [shop_name, warning_text]
					dialogue_label.visible = true
					dialogue_clear_timer.start(5.0)
	)
	return area

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

		6: # Frasco Químico (Transmutador - Skill Q)
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

		7: # Lança de Fêmur (Arauto do Ossuário - Skill Q): Projétil alongado branco-ósseo com rastro verde-fantasma
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

		8: # Lança do Trovão (Arauto do Trovão - Skill Q): Feixe elétrico ultrarrápido azul-claro
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
	puddle_root.position = Vector3(pos.x, ground_y(pos.x, pos.z) + 0.05, pos.z)
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

func _create_rebirth_crystal(parent: Node3D = null) -> void:
	var crystal_root := Node3D.new()
	crystal_root.name = "RebirthCrystalAltar"
	crystal_root.position = Vector3(0.0, 0.0, 0.0)
	if parent:
		parent.add_child(crystal_root)
	else:
		add_child(crystal_root)

	# Pedestal de Pedra / Obsidiana
	var base_pedestal := MeshInstance3D.new()
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 1.9
	base_cyl.bottom_radius = 2.2
	base_cyl.height = 0.4
	base_pedestal.mesh = base_cyl
	var dark_stone := StandardMaterial3D.new()
	LunariaTextures.apply(dark_stone, "stone", 0.9, false)
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

	# Animação flutuante do Cristal (o tween pertence ao cristal: some junto ao trocar de zona)
	var tw := crystal.create_tween().set_loops()
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

# =============================================================================
# ZONA 0: VILA DO REFÚGIO & ARREDORES (600x600m)
# =============================================================================
func _build_zone_0_village(root: Node3D) -> void:
	house_doors.clear()

	# 1. Chão Gigante de 600x600m
	_create_zone_floor(root, Vector3(600.0, 1.0, 600.0), Color(0.18, 0.22, 0.16), 0.85, Vector3(300, 300, 1))

	# Materiais medievais compartilhados
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.28, 0.3, 0.34, 1.0)
	stone_mat.roughness = 0.85
	stone_mat.metallic = 0.15

	var dark_cobble_mat := StandardMaterial3D.new()
	dark_cobble_mat.albedo_color = Color(0.24, 0.25, 0.28, 1.0)
	dark_cobble_mat.roughness = 0.85

	var wood_beam_mat := StandardMaterial3D.new()
	wood_beam_mat.albedo_color = Color(0.25, 0.16, 0.1, 1.0)
	wood_beam_mat.roughness = 0.75

	# 2. Perímetro da Vila Ampliado para 160x160m (de -80m a +80m em X e Z)
	# Muro Norte (Z = 80m)
	_create_wall_segment(root, Vector3(-43.0, 3.0, 80.0), Vector3(74.0, 6.0, 2.4), stone_mat)
	_create_wall_segment(root, Vector3(43.0, 3.0, 80.0), Vector3(74.0, 6.0, 2.4), stone_mat)
	_create_gate_portal(root, Vector3(0.0, 0.0, 80.0), true, "Portão Norte (Ruínas da Vigília)", Color(0.3, 0.7, 1.0), stone_mat)

	# Muro Sul (Z = -80m)
	_create_wall_segment(root, Vector3(-43.0, 3.0, -80.0), Vector3(74.0, 6.0, 2.4), stone_mat)
	_create_wall_segment(root, Vector3(43.0, 3.0, -80.0), Vector3(74.0, 6.0, 2.4), stone_mat)
	_create_gate_portal(root, Vector3(0.0, 0.0, -80.0), true, "Portão Sul (Bosque Sussurrante)", Color(0.2, 0.9, 0.4), stone_mat)

	# Muro Oeste (X = -80m)
	_create_wall_segment(root, Vector3(-80.0, 3.0, -43.0), Vector3(2.4, 6.0, 74.0), stone_mat)
	_create_wall_segment(root, Vector3(-80.0, 3.0, 43.0), Vector3(2.4, 6.0, 74.0), stone_mat)
	_create_gate_portal(root, Vector3(-80.0, 0.0, 0.0), false, "Portão Oeste (Santuário do Eclipse)", Color(0.9, 0.1, 0.2), stone_mat)

	# Muro Leste (X = +80m)
	_create_wall_segment(root, Vector3(80.0, 3.0, -43.0), Vector3(2.4, 6.0, 74.0), stone_mat)
	_create_wall_segment(root, Vector3(80.0, 3.0, 43.0), Vector3(2.4, 6.0, 74.0), stone_mat)
	_create_gate_portal(root, Vector3(80.0, 0.0, 0.0), false, "Portão Leste (Fronteira das Cinzas)", Color(1.0, 0.7, 0.1), stone_mat)

	# 3. Praça Central e Fonte Lunar / Cristal de Renascimento (0, 0, 0)
	var plaza_mesh := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(18.0, 0.04, 18.0)
	plaza_mesh.mesh = p_box
	plaza_mesh.material_override = dark_cobble_mat
	plaza_mesh.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(plaza_mesh)

	_create_rebirth_crystal(root)
	_build_purified_fountain(root)
	_build_cemetery_and_river(root)

	for cpos in [Vector3(-7.2, 0, -7.2), Vector3(7.2, 0, -7.2), Vector3(-7.2, 0, 7.2), Vector3(7.2, 0, 7.2)]:
		var lamp := Node3D.new()
		lamp.position = cpos
		root.add_child(lamp)

		var post := MeshInstance3D.new()
		var pmesh := CylinderMesh.new()
		pmesh.top_radius = 0.08
		pmesh.bottom_radius = 0.12
		pmesh.height = 3.2
		post.mesh = pmesh
		post.material_override = wood_beam_mat
		post.position = Vector3(0, 1.6, 0)
		lamp.add_child(post)

		var lantern := OmniLight3D.new()
		lantern.light_color = Color(1.0, 0.85, 0.55)
		lantern.light_energy = 2.4
		lantern.omni_range = 8.0
		lantern.position = Vector3(0, 3.0, 0)
		lamp.add_child(lantern)

	# 4. Construções da Vila Ampliada (Coordenadas bem espaçadas sem NENHUMA sobreposição)

	# A. Prédios organizados da Vila (Forja, Taverna, Laboratório, Quartel, Posto do Caçador, Ateliê e Casas):
	# fachada fechada com porta; encostar na porta leva ao interior (zona interna do servidor)
	for bdef in LunariaWorldData.BUILDINGS:
		_create_village_house(root, bdef)
	_create_forge_yard_brazier(root)

	# E. Igreja da Luz Sagrada (-50, 0, -45)
	var church_body := _create_solid_building(root, "HolyLightChurch", Vector3(-50.0, 0.0, -45.0), Vector3(12.0, 7.0, 16.0), Color(0.92, 0.90, 0.85), Color(0.85, 0.70, 0.22), "Igreja da Luz Sagrada", Color(1.0, 0.88, 0.25), "north")
	var church_tower := MeshInstance3D.new()
	var c_tmesh := BoxMesh.new()
	c_tmesh.size = Vector3(4.0, 14.0, 4.0)
	church_tower.mesh = c_tmesh
	church_tower.position = Vector3(0, 7.0, 9.0)
	church_body.add_child(church_tower)

	var cross_light := OmniLight3D.new()
	cross_light.light_color = Color(1.0, 0.9, 0.45)
	cross_light.light_energy = 4.0
	cross_light.omni_range = 15.0
	cross_light.position = Vector3(0, 14.5, 9.0)
	church_body.add_child(cross_light)

	# Portal Area3D dourado na porta da Igreja levando à Zona 5 (Portal ID 9)
	_create_portal_area(root, Vector3(-50.0, 0.0, -36.0), "⛪ Entrar na Igreja da Luz Sagrada", Color(1.0, 0.85, 0.2), 5, 9)

	# F. Torre do Arcanista / Torre Arcana (50, 0, -45)
	var tower_mesh := MeshInstance3D.new()
	var tm_cyl := CylinderMesh.new()
	tm_cyl.top_radius = 4.0
	tm_cyl.bottom_radius = 4.4
	tm_cyl.height = 16.0
	tower_mesh.mesh = tm_cyl
	var mage_mat := StandardMaterial3D.new()
	mage_mat.albedo_color = Color(0.11, 0.15, 0.24, 1.0)
	mage_mat.metallic = 0.3
	mage_mat.roughness = 0.6
	tower_mesh.material_override = mage_mat
	tower_mesh.position = Vector3(50.0, 8.0, -45.0)
	root.add_child(tower_mesh)

	var t_col_body := StaticBody3D.new()
	t_col_body.position = Vector3(50.0, 0.0, -45.0)
	t_col_body.collision_layer = 1
	t_col_body.collision_mask = 0
	root.add_child(t_col_body)
	var t_cshape := CollisionShape3D.new()
	var t_cyl_shape := CylinderShape3D.new()
	t_cyl_shape.radius = 4.2
	t_cyl_shape.height = 16.0
	t_cshape.shape = t_cyl_shape
	t_cshape.position = Vector3(0, 8.0, 0)
	t_col_body.add_child(t_cshape)

	var spire := MeshInstance3D.new()
	var sm_cone := CylinderMesh.new()
	sm_cone.top_radius = 0.1
	sm_cone.bottom_radius = 4.5
	sm_cone.height = 5.0
	spire.mesh = sm_cone
	spire.material_override = mage_mat
	spire.position = Vector3(50.0, 18.5, -45.0)
	root.add_child(spire)

	# Portal Area3D azul na porta da Torre levando à Zona 6 (Portal ID 11)
	_create_portal_area(root, Vector3(50.0, 0.0, -38.0), "🔮 Entrar na Torre Arcana", Color(0.1, 0.9, 1.0), 6, 11)

	# G. Entrada do Beco Sombrio (-50, 0, 48)
	_create_solid_building(root, "AlleyWallArch", Vector3(-50.0, 0.0, 48.0), Vector3(5.0, 4.5, 6.0), Color(0.2, 0.18, 0.22), Color(0.15, 0.12, 0.18), "Beco Sombrio", Color(0.7, 0.4, 0.9), "south")
	# Portal Area3D roxo levando ao Mercado Negro Zona 7 (Apenas entre 18h e 06h - Portal ID 13)
	_create_portal_area(root, Vector3(-50.0, 0.0, 54.0), "🗡️ Entrada do Mercado Negro (18h às 06h)", Color(0.7, 0.2, 0.9), 7, 13, true)

	# H. Entrada dos Esgotos Antigos (-65, 0, -65)
	var sewer_gate := MeshInstance3D.new()
	var sg_box := BoxMesh.new()
	sg_box.size = Vector3(4.0, 0.2, 4.0)
	sewer_gate.mesh = sg_box
	var sg_mat := StandardMaterial3D.new()
	sg_mat.albedo_color = Color(0.15, 0.16, 0.18)
	sg_mat.metallic = 0.8
	sewer_gate.material_override = sg_mat
	sewer_gate.position = Vector3(-65.0, 0.1, -65.0)
	root.add_child(sewer_gate)
	# Portal Area3D verde levando aos Esgotos Zona 8 (Portal ID 15)
	_create_portal_area(root, Vector3(-65.0, 0.0, -65.0), "🕳️ Descer para os Esgotos Antigos", Color(0.2, 0.9, 0.4), 8, 15)


	# 5. Novas Estruturas das Raças nos Arredores da Vila (Entre ±90m e ±220m)

	# B. Salão de Pedra dos Anões & Mina Rúnica (120, 0, 140)
	var dwarf_root := Node3D.new()
	dwarf_root.position = Vector3(120.0, 0.0, 140.0)
	root.add_child(dwarf_root)
	_create_solid_building(dwarf_root, "DwarfHall", Vector3.ZERO, Vector3(14.0, 6.0, 12.0), Color(0.25, 0.26, 0.28), Color(0.4, 0.35, 0.25), "Salão de Pedra dos Anões", Color(1.0, 0.75, 0.3), "north")
	var dwarf_lbl := Label3D.new()
	dwarf_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dwarf_lbl.text = "⛏️ Entrada da Mina Rúnica dos Anões"
	dwarf_lbl.font_size = 24
	dwarf_lbl.outline_size = 8
	dwarf_lbl.modulate = Color(1.0, 0.8, 0.3)
	dwarf_lbl.position = Vector3(0, 7.2, 0)
	dwarf_root.add_child(dwarf_lbl)

	# C. Santuário das Árvores Élficas & Clareira das Fadas (-130, 0, -120)
	var elf_root := Node3D.new()
	elf_root.position = Vector3(-130.0, 0.0, -120.0)
	root.add_child(elf_root)
	for ep_i in range(4):
		var ang := ep_i * (PI / 2.0)
		var tree_pos := Vector3(cos(ang) * 9.0, 0.0, sin(ang) * 9.0)
		var trunk := MeshInstance3D.new()
		var tr_cyl := CylinderMesh.new()
		tr_cyl.top_radius = 0.5
		tr_cyl.bottom_radius = 0.9
		tr_cyl.height = 7.0
		trunk.mesh = tr_cyl
		var t_mat := StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.85, 0.88, 0.92)
		trunk.material_override = t_mat
		trunk.position = tree_pos + Vector3(0, 3.5, 0)
		elf_root.add_child(trunk)

		var canopy := MeshInstance3D.new()
		var cn_sph := SphereMesh.new()
		cn_sph.radius = 2.8
		cn_sph.height = 4.2
		canopy.mesh = cn_sph
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color(0.4, 0.95, 0.8)
		c_mat.emission_enabled = true
		c_mat.emission = Color(0.3, 0.85, 0.7)
		c_mat.emission_energy_multiplier = 1.5
		canopy.material_override = c_mat
		canopy.position = tree_pos + Vector3(0, 7.0, 0)
		elf_root.add_child(canopy)

	var elf_light := OmniLight3D.new()
	elf_light.light_color = Color(0.4, 0.9, 0.95)
	elf_light.light_energy = 3.5
	elf_light.omni_range = 14.0
	elf_light.position = Vector3(0, 2.5, 0)
	elf_root.add_child(elf_light)

	var elf_lbl := Label3D.new()
	elf_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	elf_lbl.text = "🌿 Santuário das Árvores Élficas & Clareira das Fadas"
	elf_lbl.font_size = 24
	elf_lbl.outline_size = 8
	elf_lbl.modulate = Color(0.4, 0.95, 0.85)
	elf_lbl.position = Vector3(0, 4.0, 0)
	elf_root.add_child(elf_lbl)

	# E. Favela de Engrenagens Gnarlin (-120, 0, 90)
	var gob_root := Node3D.new()
	gob_root.position = Vector3(-120.0, 0.0, 90.0)
	root.add_child(gob_root)
	_create_solid_building(gob_root, "GoblinShack", Vector3.ZERO, Vector3(6.5, 3.2, 6.5), Color(0.3, 0.28, 0.22), Color(0.4, 0.35, 0.15), "Favela Gnarlin", Color(0.6, 0.9, 0.2), "south")
	var gob_lbl := Label3D.new()
	gob_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gob_lbl.text = "⚙️ Favela de Engrenagens Gnarlin"
	gob_lbl.font_size = 24
	gob_lbl.outline_size = 8
	gob_lbl.modulate = Color(0.65, 0.9, 0.25)
	gob_lbl.position = Vector3(0, 4.5, 0)
	gob_root.add_child(gob_lbl)

	# 6. 4 Portais Cardeais nas Bordas 600x600m da Zona 0
	# Sul (0, 0, -285) -> Bosque Sussurrante (Zona 1, Portal ID 1)
	_create_portal_area(root, Vector3(0.0, 0.0, -285.0), "🌲 Portal: Bosque Sussurrante (Sul)", Color(0.2, 0.9, 0.4), 1, 1)

	# Norte (0, 0, 285) -> Ruínas da Vigília & Norte Gelado (Zona 2, Portal ID 3)
	_create_portal_area(root, Vector3(0.0, 0.0, 285.0), "🌬️ Portal: Planalto dos Ventos (Norte)", Color(0.6, 0.85, 0.6), 13, 3)

	# Oeste (-285, 0, 0) -> Santuário do Eclipse (Zona 3, Portal ID 5)
	_create_portal_area(root, Vector3(-285.0, 0.0, 0.0), "🌑 Portal: Santuário do Eclipse (Oeste)", Color(0.9, 0.1, 0.2), 3, 5)

	# Leste (285, 0, 0) -> Fronteira das Cinzas (Zona 4, Portal ID 7)
	_create_portal_area(root, Vector3(285.0, 0.0, 0.0), "🪨 Portal: Colinas de Basalto (Leste)", Color(0.8, 0.6, 0.35), 15, 7)

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
	LunariaTextures.apply(wall_mat, "plaster", 1.5, true)
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
	LunariaTextures.apply(floor_mat, "planks", 1.2, false)
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
	LunariaTextures.apply(roof_mat, "roof_tiles", 1.6, false)
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
	LunariaTextures.apply(mat, "wood", 0.6, false)
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
	LunariaTextures.apply(frame_mat, "wood", 0.6, false)
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

# =============================================================================
# ZONA 1: BOSQUE SUSSURRANTE / FLORESTA (600x600m)
# =============================================================================
func _build_zone_1_forest(root: Node3D) -> void:
	# Chão da floresta de 600x600m
	_create_zone_floor(root, Vector3(600.0, 1.0, 600.0), Color(0.12, 0.24, 0.14), 0.9, Vector3(300, 300, 1))

	# 1. Árvore-Mãe Sylvari no centro (0, 0, 0)
	var mother_tree := Node3D.new()
	mother_tree.position = Vector3(0, 0, 0)
	root.add_child(mother_tree)

	var trunk := MeshInstance3D.new()
	var tr_mesh := CylinderMesh.new()
	tr_mesh.top_radius = 5.0
	tr_mesh.bottom_radius = 6.5
	tr_mesh.height = 28.0
	trunk.mesh = tr_mesh
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.24, 0.18, 0.12)
	trunk.material_override = wood_mat
	trunk.position = Vector3(0, 14.0, 0)
	mother_tree.add_child(trunk)

	var canopy := MeshInstance3D.new()
	var can_mesh := SphereMesh.new()
	can_mesh.radius = 16.0
	can_mesh.height = 22.0
	canopy.mesh = can_mesh
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.15, 0.65, 0.35)
	leaf_mat.emission_enabled = true
	leaf_mat.emission = Color(0.1, 0.5, 0.25)
	leaf_mat.emission_energy_multiplier = 1.8
	canopy.material_override = leaf_mat
	canopy.position = Vector3(0, 30.0, 0)
	mother_tree.add_child(canopy)

	var tree_light := OmniLight3D.new()
	tree_light.light_color = Color(0.3, 0.9, 0.5)
	tree_light.light_energy = 4.0
	tree_light.omni_range = 25.0
	tree_light.position = Vector3(0, 10.0, 0)
	mother_tree.add_child(tree_light)

	var tree_lbl := Label3D.new()
	tree_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tree_lbl.text = "🌳 Árvore-Mãe Sylvari (Coração da Floresta)"
	tree_lbl.font_size = 28
	tree_lbl.outline_size = 8
	tree_lbl.modulate = Color(0.4, 1.0, 0.6)
	tree_lbl.position = Vector3(0, 16.0, 0)
	mother_tree.add_child(tree_lbl)

	# 2. Ninho da Rainha Aranha a Sudeste (120, 0, -120)
	var spider_root := Node3D.new()
	spider_root.position = Vector3(120.0, 0.0, -120.0)
	root.add_child(spider_root)

	for s_i in range(5):
		var ang := s_i * (2.0 * PI / 5.0)
		var sp_pillar := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.8
		p_mesh.bottom_radius = 1.4
		p_mesh.height = 8.0
		sp_pillar.mesh = p_mesh
		var web_mat := StandardMaterial3D.new()
		web_mat.albedo_color = Color(0.9, 0.92, 0.95, 0.75)
		web_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sp_pillar.material_override = web_mat
		sp_pillar.position = Vector3(cos(ang) * 12.0, 4.0, sin(ang) * 12.0)
		spider_root.add_child(sp_pillar)

	var spider_lbl := Label3D.new()
	spider_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spider_lbl.text = "🕷️ Ninho de Teias da Rainha Aranha"
	spider_lbl.font_size = 24
	spider_lbl.outline_size = 8
	spider_lbl.modulate = Color(0.9, 0.95, 1.0)
	spider_lbl.position = Vector3(0, 5.0, 0)
	spider_root.add_child(spider_lbl)

	# 3. Lago Profundo dos Dracos de Água a Oeste (-100, 0, 40)
	var lake_root := Node3D.new()
	lake_root.position = Vector3(-100.0, 0.0, 40.0)
	root.add_child(lake_root)

	var lake_mesh := MeshInstance3D.new()
	var l_cyl := CylinderMesh.new()
	l_cyl.top_radius = 20.0
	l_cyl.bottom_radius = 20.0
	l_cyl.height = 0.2
	lake_mesh.mesh = l_cyl
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.1, 0.45, 0.75, 0.85)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.1
	water_mat.metallic = 0.3
	lake_mesh.material_override = water_mat
	lake_mesh.position = Vector3(0, 0.1, 0)
	lake_root.add_child(lake_mesh)

	var lake_light := OmniLight3D.new()
	lake_light.light_color = Color(0.2, 0.7, 1.0)
	lake_light.light_energy = 3.0
	lake_light.omni_range = 16.0
	lake_light.position = Vector3(0, 2.0, 0)
	lake_root.add_child(lake_light)

	var lake_lbl := Label3D.new()
	lake_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lake_lbl.text = "🌊 Lago Profundo dos Dracos de Água"
	lake_lbl.font_size = 24
	lake_lbl.outline_size = 8
	lake_lbl.modulate = Color(0.3, 0.8, 1.0)
	lake_lbl.position = Vector3(0, 4.0, 0)
	lake_root.add_child(lake_lbl)

	# 4. Portal de Volta para a Vila ao Norte (0, 0, 285)
	_create_portal_area(root, Vector3(0.0, 0.0, 285.0), "🏛️ Portal: Retornar à Vila do Refúgio", Color(0.2, 0.9, 0.4), 0, 2)

# =============================================================================
# ZONA 2: RUÍNAS DA VIGÍLIA & PICOS GELADOS (600x600m)
# =============================================================================
func _build_zone_2_ruins(root: Node3D) -> void:
	# Chão de gelo e rocha nevada de 600x600m
	_create_zone_floor(root, Vector3(600.0, 1.0, 600.0), Color(0.76, 0.82, 0.88), 0.7, Vector3(300, 300, 1))

	var ice_stone_mat := StandardMaterial3D.new()
	ice_stone_mat.albedo_color = Color(0.4, 0.45, 0.52)
	ice_stone_mat.roughness = 0.8

	# 1. Fortaleza de Vaelen no centro (0, 0, 0)
	var fortress := Node3D.new()
	fortress.position = Vector3.ZERO
	root.add_child(fortress)

	_create_solid_building(fortress, "VaelenFortress", Vector3.ZERO, Vector3(22.0, 9.0, 22.0), Color(0.35, 0.4, 0.48), Color(0.2, 0.25, 0.35), "Fortaleza do Comandante Vaelen", Color(0.5, 0.85, 1.0), "south")

	var blue_fire := OmniLight3D.new()
	blue_fire.light_color = Color(0.3, 0.7, 1.0)
	blue_fire.light_energy = 4.5
	blue_fire.omni_range = 18.0
	blue_fire.position = Vector3(0, 4.0, 14.0)
	fortress.add_child(blue_fire)

	# 2. Trono de Gelo dos Gigantes de Gelo ao Norte (0, 0, 150)
	var throne_root := Node3D.new()
	throne_root.position = Vector3(0.0, 0.0, 150.0)
	root.add_child(throne_root)

	for t_i in range(6):
		var rad_t := t_i * (PI / 5.0) - (PI / 2.0)
		var shard := MeshInstance3D.new()
		var sh_cyl := CylinderMesh.new()
		sh_cyl.top_radius = 0.1
		sh_cyl.bottom_radius = 1.2
		sh_cyl.height = 10.0
		shard.mesh = sh_cyl
		var ice_mat := StandardMaterial3D.new()
		ice_mat.albedo_color = Color(0.65, 0.88, 1.0, 0.85)
		ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice_mat.roughness = 0.2
		ice_mat.emission_enabled = true
		ice_mat.emission = Color(0.3, 0.7, 1.0)
		ice_mat.emission_energy_multiplier = 1.5
		shard.material_override = ice_mat
		shard.position = Vector3(cos(rad_t) * 9.0, 5.0, sin(rad_t) * 9.0)
		throne_root.add_child(shard)

	var throne_lbl := Label3D.new()
	throne_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	throne_lbl.text = "👑 Trono Glacial dos Gigantes de Gelo"
	throne_lbl.font_size = 26
	throne_lbl.outline_size = 8
	throne_lbl.modulate = Color(0.5, 0.85, 1.0)
	throne_lbl.position = Vector3(0, 6.0, 0)
	throne_root.add_child(throne_lbl)

	# 3. Portal de Volta para a Vila ao Sul (0, 0, -285)
	_create_portal_area(root, Vector3(0.0, 0.0, -285.0), "🌬️ Portal: Planalto dos Ventos (Sul)", Color(0.6, 0.85, 0.6), 13, 18)

# =============================================================================
# ZONA 3: SANTUÁRIO DO ECLIPSE (600x600m)
# =============================================================================
func _build_zone_3_sanctuary(root: Node3D) -> void:
	# Chão vulcânico / obsidiana de 600x600m
	_create_zone_floor(root, Vector3(600.0, 1.0, 600.0), Color(0.08, 0.06, 0.09), 0.3, Vector3(300, 300, 1))

	var obs_mat := StandardMaterial3D.new()
	obs_mat.albedo_color = Color(0.08, 0.06, 0.10, 1.0)
	obs_mat.metallic = 0.85
	obs_mat.roughness = 0.25

	# 1. Sol Negro Eclipsado no céu (0, 32, 0)
	var black_sun := MeshInstance3D.new()
	var bs_sph := SphereMesh.new()
	bs_sph.radius = 6.0
	bs_sph.height = 12.0
	black_sun.mesh = bs_sph
	var bs_mat := StandardMaterial3D.new()
	bs_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bs_mat.albedo_color = Color(0.01, 0.01, 0.01)
	black_sun.material_override = bs_mat
	black_sun.position = Vector3(0, 32.0, 0)
	root.add_child(black_sun)

	var sun_halo := MeshInstance3D.new()
	var sh_cyl := CylinderMesh.new()
	sh_cyl.top_radius = 8.0
	sh_cyl.bottom_radius = 8.0
	sh_cyl.height = 0.3
	sun_halo.mesh = sh_cyl
	var sh_mat := StandardMaterial3D.new()
	sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh_mat.albedo_color = Color(1.0, 0.08, 0.15)
	sun_halo.material_override = sh_mat
	sun_halo.position = Vector3(0, 32.0, 0)
	root.add_child(sun_halo)

	var sky_red_light := OmniLight3D.new()
	sky_red_light.light_color = Color(1.0, 0.08, 0.15)
	sky_red_light.light_energy = 5.0
	sky_red_light.omni_range = 50.0
	sky_red_light.position = Vector3(0, 30.0, 0)
	root.add_child(sky_red_light)

	# 2. Catedral de Malakor no centro (0, 0, 0)
	var cathedral := Node3D.new()
	cathedral.position = Vector3.ZERO
	root.add_child(cathedral)

	var c_floor := MeshInstance3D.new()
	var cf_box := BoxMesh.new()
	cf_box.size = Vector3(32.0, 0.4, 32.0)
	c_floor.mesh = cf_box
	c_floor.material_override = obs_mat
	c_floor.position = Vector3(0, 0.2, 0)
	cathedral.add_child(c_floor)

	for p_i in range(8):
		var p_ang := p_i * (PI / 4.0)
		var pilar := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(1.8, 8.0, 1.8)
		pilar.mesh = p_box
		pilar.material_override = obs_mat
		pilar.position = Vector3(cos(p_ang) * 14.0, 4.0, sin(p_ang) * 14.0)
		cathedral.add_child(pilar)

	var malakor_lbl := Label3D.new()
	malakor_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	malakor_lbl.text = "🌑 Catedral do Eclipse Supremo (Raid de Malakor)"
	malakor_lbl.font_size = 28
	malakor_lbl.outline_size = 9
	malakor_lbl.modulate = Color(1.0, 0.15, 0.2)
	malakor_lbl.position = Vector3(0, 6.0, 0)
	cathedral.add_child(malakor_lbl)

	# 3. Cripta Carmesim do Rei Vampiro a Noroeste (-140, 0, 140)
	var crypt := Node3D.new()
	crypt.position = Vector3(-140.0, 0.0, 140.0)
	root.add_child(crypt)

	_create_solid_building(crypt, "VampireCrypt", Vector3.ZERO, Vector3(16.0, 7.0, 16.0), Color(0.12, 0.08, 0.12), Color(0.25, 0.05, 0.08), "Cripta Carmesim do Rei Vampiro", Color(1.0, 0.1, 0.2), "south")

	# 4. Portal de Volta para a Vila a Leste (285, 0, 0)
	_create_portal_area(root, Vector3(285.0, 0.0, 0.0), "🏛️ Portal: Retornar à Vila do Refúgio", Color(0.9, 0.1, 0.2), 0, 6)

# =============================================================================
# ZONA 4: FRONTEIRA DAS CINZAS / ZONA FUTURA (600x600m)
# =============================================================================
func _build_zone_4_ashlands(root: Node3D) -> void:
	# Chão de cinzas vulcânicas de 600x600m
	_create_zone_floor(root, Vector3(600.0, 1.0, 600.0), Color(0.14, 0.13, 0.15), 0.9, Vector3(300, 300, 1))

	var ash_lbl := Label3D.new()
	ash_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ash_lbl.text = "🔥 Fronteira das Cinzas — Terras Inexploradas\n[Próxima Grande Expansão de Lunaria]"
	ash_lbl.font_size = 30
	ash_lbl.outline_size = 9
	ash_lbl.modulate = Color(1.0, 0.65, 0.15)
	ash_lbl.position = Vector3(0, 5.0, 0)
	root.add_child(ash_lbl)

	var magma_light := OmniLight3D.new()
	magma_light.light_color = Color(1.0, 0.45, 0.1)
	magma_light.light_energy = 4.0
	magma_light.omni_range = 20.0
	magma_light.position = Vector3(0, 1.5, 0)
	root.add_child(magma_light)

	# Portal de Volta para a Vila a Oeste (-285, 0, 0)
	_create_portal_area(root, Vector3(-285.0, 0.0, 0.0), "🪨 Portal: Colinas de Basalto (Oeste)", Color(0.8, 0.6, 0.35), 15, 22)

# =============================================================================
# ZONA 5: INTERIOR DA IGREJA DA LUZ SAGRADA (60x60m)
# =============================================================================
func _build_zone_5_church(root: Node3D) -> void:
	# Chão de mármore polido 60x60m
	_create_zone_floor(root, Vector3(60.0, 1.0, 60.0), Color(0.88, 0.86, 0.82), 0.4, Vector3(30, 30, 1))

	var church_stone := StandardMaterial3D.new()
	church_stone.albedo_color = Color(0.92, 0.90, 0.85)

	# Paredes do Templo
	_create_wall_segment(root, Vector3(0, 5.0, 29.0), Vector3(58.0, 10.0, 1.5), church_stone)
	_create_wall_segment(root, Vector3(-29.0, 5.0, 0), Vector3(1.5, 10.0, 58.0), church_stone)
	_create_wall_segment(root, Vector3(29.0, 5.0, 0), Vector3(1.5, 10.0, 58.0), church_stone)
	_create_wall_segment(root, Vector3(-16.0, 5.0, -29.0), Vector3(26.0, 10.0, 1.5), church_stone)
	_create_wall_segment(root, Vector3(16.0, 5.0, -29.0), Vector3(26.0, 10.0, 1.5), church_stone)

	# Tapete central dourado
	var carpet := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(6.0, 0.02, 44.0)
	carpet.mesh = c_box
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.7, 0.15, 0.2)
	carpet.material_override = c_mat
	carpet.position = Vector3(0, 0.015, -2.0)
	root.add_child(carpet)

	# Grande Altar Dourado Solar no fundo (0, 0, 18)
	var altar := MeshInstance3D.new()
	var a_box := BoxMesh.new()
	a_box.size = Vector3(8.0, 1.8, 3.0)
	altar.mesh = a_box
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.9, 0.75, 0.25)
	gold_mat.metallic = 0.8
	gold_mat.roughness = 0.3
	altar.material_override = gold_mat
	altar.position = Vector3(0, 0.9, 18.0)
	root.add_child(altar)

	var solar_light := OmniLight3D.new()
	solar_light.light_color = Color(1.0, 0.9, 0.5)
	solar_light.light_energy = 4.5
	solar_light.omni_range = 22.0
	solar_light.position = Vector3(0, 4.0, 18.0)
	root.add_child(solar_light)

	var altar_lbl := Label3D.new()
	altar_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	altar_lbl.text = "☀️ Grande Altar da Luz Sagrada"
	altar_lbl.font_size = 28
	altar_lbl.outline_size = 8
	altar_lbl.modulate = Color(1.0, 0.88, 0.3)
	altar_lbl.position = Vector3(0, 3.5, 18.0)
	root.add_child(altar_lbl)

	# Portal Area3D de Saída na porta sul (0, 0, -26)
	_create_portal_area(root, Vector3(0.0, 0.0, -26.0), "🚪 Sair para a Vila do Refúgio", Color(1.0, 0.85, 0.2), 0, 10)

# =============================================================================
# ZONA 6: INTERIOR DA TORRE DO MAGO (60x60m)
# =============================================================================
func _build_zone_6_mage_tower(root: Node3D) -> void:
	# Chão arcano de 60x60m
	_create_zone_floor(root, Vector3(60.0, 1.0, 60.0), Color(0.09, 0.12, 0.18), 0.5, Vector3(30, 30, 1))

	var mage_stone := StandardMaterial3D.new()
	mage_stone.albedo_color = Color(0.12, 0.16, 0.25)

	# Paredes da Torre
	_create_wall_segment(root, Vector3(0, 5.0, 29.0), Vector3(58.0, 10.0, 1.5), mage_stone)
	_create_wall_segment(root, Vector3(-29.0, 5.0, 0), Vector3(1.5, 10.0, 58.0), mage_stone)
	_create_wall_segment(root, Vector3(29.0, 5.0, 0), Vector3(1.5, 10.0, 58.0), mage_stone)
	_create_wall_segment(root, Vector3(-16.0, 5.0, -29.0), Vector3(26.0, 10.0, 1.5), mage_stone)
	_create_wall_segment(root, Vector3(16.0, 5.0, -29.0), Vector3(26.0, 10.0, 1.5), mage_stone)

	# Orbe Cósmico Arcano Flutuante no centro (0, 3.0, 0)
	var cosmic_orb := MeshInstance3D.new()
	var orb_sph := SphereMesh.new()
	orb_sph.radius = 1.4
	orb_sph.height = 2.8
	cosmic_orb.mesh = orb_sph
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.1, 0.9, 1.0)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.1, 0.85, 1.0)
	orb_mat.emission_energy_multiplier = 4.0
	cosmic_orb.material_override = orb_mat
	cosmic_orb.position = Vector3(0, 3.0, 0)
	root.add_child(cosmic_orb)

	var orb_light := OmniLight3D.new()
	orb_light.light_color = Color(0.15, 0.85, 1.0)
	orb_light.light_energy = 4.5
	orb_light.omni_range = 20.0
	orb_light.position = Vector3(0, 3.5, 0)
	root.add_child(orb_light)

	var orb_lbl := Label3D.new()
	orb_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	orb_lbl.text = "🔮 Orbe Arcano Cósmico de Lunaria"
	orb_lbl.font_size = 28
	orb_lbl.outline_size = 8
	orb_lbl.modulate = Color(0.2, 0.9, 1.0)
	orb_lbl.position = Vector3(0, 5.2, 0)
	root.add_child(orb_lbl)

	# Portal Area3D de Saída na porta sul (0, 0, -26)
	_create_portal_area(root, Vector3(0.0, 0.0, -26.0), "🚪 Sair para a Vila do Refúgio", Color(0.1, 0.9, 1.0), 0, 12)

# =============================================================================
# ZONA 7: MERCADO NEGRO DO BECO (80x80m)
# =============================================================================
func _build_zone_7_black_market(root: Node3D) -> void:
	# Chão de paralelepípedos escuros 80x80m
	_create_zone_floor(root, Vector3(80.0, 1.0, 80.0), Color(0.14, 0.15, 0.17), 0.7, Vector3(40, 40, 1))

	var alley_brick := StandardMaterial3D.new()
	alley_brick.albedo_color = Color(0.18, 0.16, 0.2)

	_create_wall_segment(root, Vector3(0, 4.0, 39.0), Vector3(78.0, 8.0, 1.5), alley_brick)
	_create_wall_segment(root, Vector3(-39.0, 4.0, 0), Vector3(1.5, 8.0, 78.0), alley_brick)
	_create_wall_segment(root, Vector3(39.0, 4.0, 0), Vector3(1.5, 8.0, 78.0), alley_brick)
	_create_wall_segment(root, Vector3(-22.0, 4.0, -39.0), Vector3(34.0, 8.0, 1.5), alley_brick)
	_create_wall_segment(root, Vector3(22.0, 4.0, -39.0), Vector3(34.0, 8.0, 1.5), alley_brick)

	# Tochas roxas de contrabando
	for tpos in [Vector3(-14, 2.5, -10), Vector3(14, 2.5, -10), Vector3(-14, 2.5, 15), Vector3(14, 2.5, 15)]:
		var torch := OmniLight3D.new()
		torch.light_color = Color(0.75, 0.2, 0.95)
		torch.light_energy = 3.6
		torch.omni_range = 14.0
		torch.position = tpos
		root.add_child(torch)

	var market_lbl := Label3D.new()
	market_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	market_lbl.text = "🗡️ Mercado Negro do Beco Sombrio\n[Bazar Clandestino — Aberto Apenas das 18h às 06h]"
	market_lbl.font_size = 28
	market_lbl.outline_size = 9
	market_lbl.modulate = Color(0.85, 0.35, 1.0)
	market_lbl.position = Vector3(0, 4.5, 5.0)
	root.add_child(market_lbl)

	# Portal Area3D de Saída (0, 0, -35)
	_create_portal_area(root, Vector3(0.0, 0.0, -35.0), "🚪 Sair para a Vila do Refúgio", Color(0.7, 0.2, 0.9), 0, 14)

# =============================================================================
# ZONA 8: ESGOTOS ANTIGOS SUBTERRÂNEOS (600x600m)
# =============================================================================
func _build_zone_8_sewers(root: Node3D) -> void:
	# Chão de pedra úmida escura de 600x600m
	_create_zone_floor(root, Vector3(600.0, 1.0, 600.0), Color(0.12, 0.14, 0.13), 0.85, Vector3(300, 300, 1))

	# Teto abobadado subterrâneo em Y = 7.0m
	var roof_body := StaticBody3D.new()
	roof_body.collision_layer = 1
	roof_body.collision_mask = 0
	root.add_child(roof_body)

	var r_col := CollisionShape3D.new()
	var r_shape := BoxShape3D.new()
	r_shape.size = Vector3(600.0, 1.0, 600.0)
	r_col.shape = r_shape
	r_col.position = Vector3(0, 7.5, 0)
	roof_body.add_child(r_col)

	var r_mesh := MeshInstance3D.new()
	var rm_box := BoxMesh.new()
	rm_box.size = Vector3(600.0, 1.0, 600.0)
	r_mesh.mesh = rm_box
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.1, 0.11, 0.1)
	r_mesh.material_override = roof_mat
	r_mesh.position = Vector3(0, 7.5, 0)
	roof_body.add_child(r_mesh)

	# Canal de Lodo Tóxico Verde central
	var canal := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(10.0, 0.1, 580.0)
	canal.mesh = c_box
	var tox_mat := StandardMaterial3D.new()
	tox_mat.albedo_color = Color(0.15, 0.85, 0.35, 0.85)
	tox_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tox_mat.emission_enabled = true
	tox_mat.emission = Color(0.12, 0.75, 0.3)
	tox_mat.emission_energy_multiplier = 2.0
	canal.material_override = tox_mat
	canal.position = Vector3(0, 0.05, 0)
	root.add_child(canal)

	# Luzes verdes ao longo do esgoto
	for z_i in [-150.0, -75.0, 0.0, 75.0, 150.0]:
		var g_light := OmniLight3D.new()
		g_light.light_color = Color(0.2, 0.9, 0.35)
		g_light.light_energy = 2.8
		g_light.omni_range = 15.0
		g_light.position = Vector3(0, 3.0, z_i)
		root.add_child(g_light)

	# Ninho dos Escorpiões Abissais a Sudeste (100, 0, -100)
	var scorp_lbl := Label3D.new()
	scorp_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	scorp_lbl.text = "🦂 Ninho dos Escorpiões Abissais"
	scorp_lbl.font_size = 26
	scorp_lbl.outline_size = 8
	scorp_lbl.modulate = Color(0.3, 1.0, 0.5)
	scorp_lbl.position = Vector3(100.0, 3.5, -100.0)
	root.add_child(scorp_lbl)

	# Laboratório Secreto do Alquimista Fantasma a Noroeste (-110, 0, 110)
	var ghost_lbl := Label3D.new()
	ghost_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost_lbl.text = "🧪 Laboratório Clandestino do Alquimista Fantasma"
	ghost_lbl.font_size = 26
	ghost_lbl.outline_size = 8
	ghost_lbl.modulate = Color(0.4, 0.95, 0.7)
	ghost_lbl.position = Vector3(-110.0, 3.5, 110.0)
	root.add_child(ghost_lbl)

	# Escada / Portal Area3D de Volta para a Vila (0, 0, 0)
	_create_portal_area(root, Vector3(0.0, 0.0, 0.0), "🪜 Subir para a Vila do Refúgio", Color(0.2, 0.9, 0.4), 0, 16)


# =============================================================================
# Mundo Vivo: Cemitério da Luz (ao lado da Igreja). O Rio Prateado vem do relevo (scripts/world).
# Posições iguais às do servidor (world.CemeteryOrigin e world.PlaceRiver).
# =============================================================================
func _build_cemetery_and_river(root: Node3D) -> void:
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.22, 0.3, 0.2)
	grass_mat.roughness = 1.0
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = Color(0.16, 0.15, 0.16)
	fence_mat.metallic = 0.6
	fence_mat.roughness = 0.5

	# Cemitério: gramado escuro cercado, de (-82, -22) a (-58, -58)
	var cemetery := Node3D.new()
	cemetery.name = "Cemiterio"
	root.add_child(cemetery)
	var ground := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	g_box.size = Vector3(20.0, 0.05, 30.0)
	ground.mesh = g_box
	ground.material_override = grass_mat
	ground.position = Vector3(-69.0, 0.03, -40.0)
	cemetery.add_child(ground)
	for fence in [[Vector3(-69.0, 0.6, -25.0), Vector3(20.0, 1.2, 0.12)], [Vector3(-69.0, 0.6, -55.0), Vector3(20.0, 1.2, 0.12)],
			[Vector3(-59.0, 0.6, -40.0), Vector3(0.12, 1.2, 30.0)], [Vector3(-79.0, 0.6, -40.0), Vector3(0.12, 1.2, 30.0)]]:
		var bar := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = fence[1]
		bar.mesh = b_box
		bar.material_override = fence_mat
		bar.position = fence[0]
		cemetery.add_child(bar)
	var cem_sign := Label3D.new()
	cem_sign.text = "⚰️ Cemitério da Luz"
	cem_sign.font_size = 34
	cem_sign.outline_size = 8
	cem_sign.outline_modulate = Color(0, 0, 0, 1)
	cem_sign.modulate = Color(0.85, 0.85, 1.0)
	cem_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cem_sign.position = Vector3(-60.0, 2.4, -25.0)
	cemetery.add_child(cem_sign)



# HUD de sobrevivência (0x50): fome e temperatura sentida, com alertas de frio, calor e fome
func _on_survival_received(hunger: int, cold: int, heat: int, body_temp: int, ambient_temp: int) -> void:
	if hunger_bar:
		hunger_bar.value = hunger
	if not survival_label:
		return
	var state := "Confortável"
	var col := Color(1.0, 0.8, 0.5)
	if cold >= 100:
		state = "HIPOTERMIA!"
		col = Color(0.4, 0.75, 1.0)
	elif heat >= 100:
		state = "INSOLAÇÃO!"
		col = Color(1.0, 0.35, 0.2)
	elif cold > 70:
		state = "Congelando"
		col = Color(0.55, 0.8, 1.0)
	elif heat > 70:
		state = "Superaquecido"
		col = Color(1.0, 0.5, 0.3)
	elif cold > 30:
		state = "Com frio"
	elif heat > 30:
		state = "Com calor"
	var hunger_txt := "Faminto!" if hunger < 25 else "%d%%" % hunger
	if hunger <= 0:
		hunger_txt = "MORRENDO DE FOME!"
		col = Color(1.0, 0.3, 0.3)
	survival_label.text = "Fome: %s | %d°C (ar %d°C) — %s" % [hunger_txt, body_temp, ambient_temp, state]
	survival_label.add_theme_color_override("font_color", col)


# =============================================================================
# Mundo vivo: relevo, estradas, rio, vegetação e as zonas de transição (9 a 16)
# =============================================================================

var world_map_ui: CanvasLayer = null

func _toggle_world_map() -> void:
	if world_map_ui == null:
		world_map_ui = preload("res://scripts/world/WorldMapUI.gd").new()
		add_child(world_map_ui)
	world_map_ui.toggle()

## Altura do chão no ponto (0 nos interiores e nas praças).
func ground_y(x: float, z: float) -> float:
	return LunariaTerrain.height(current_zone_id, x, z)

## Mesma posição, apoiada no relevo (o servidor só conhece X/Z).
func on_ground(pos: Vector3) -> Vector3:
	return Vector3(pos.x, ground_y(pos.x, pos.z), pos.z)

## Rede de segurança: se o jogador cair por baixo do relevo (spawn, teleporte), volta para cima do chão.
func _keep_player_above_ground() -> void:
	if local_player == null or not is_instance_valid(local_player) or not LunariaTerrain.is_open_zone(current_zone_id):
		return
	var gp: Vector3 = local_player.global_position
	var g := ground_y(gp.x, gp.z)
	if gp.y < g - 2.5:
		local_player.global_position = Vector3(gp.x, g + 1.2, gp.z)
		local_player.velocity = Vector3.ZERO

func _build_living_landscape(zone_id: int) -> void:
	if not LunariaTerrain.is_open_zone(zone_id) or current_map_root == null:
		return
	# O piso plano antigo dá lugar ao relevo
	for child in current_map_root.get_children():
		if child.name == "ZoneFloor":
			child.queue_free()
	# Construções e marcos acompanham o terreno
	for child in current_map_root.get_children():
		if child is Node3D and child.name != "ZoneFloor" and not (child is Area3D):
			var n3 := child as Node3D
			n3.position.y += ground_y(n3.position.x, n3.position.z)
	LunariaWorldBuilder.build(zone_id, current_map_root)
	# Portais que o construtor da zona não criou (zonas de transição e novas ligações)
	var existing := {}
	for child in current_map_root.get_children():
		if child is Area3D and String(child.name).begins_with("Portal_"):
			existing[int(String(child.name).split("_")[1])] = true
	for p in LunariaWorldData.PORTALS:
		if int(p["from"]) != zone_id or existing.has(int(p["id"])):
			continue
		var to: int = p["to"]
		var target_name: String = LunariaWorldData.ZONES[to]["name"] if LunariaWorldData.ZONES.has(to) else "Zona %d" % to
		_create_portal_area(current_map_root, Vector3(float(p["x"]), 0.0, float(p["z"])), "🌀 Portal: %s" % target_name, Color(0.55, 0.85, 1.0), to, int(p["id"]))

## Marcos centrais das zonas de transição (o relevo, a vegetação e os portais vêm do construtor).
func _build_transition_zone(root: Node3D, zone_id: int) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#8a857c")
	LunariaTextures.apply(stone, "stone_blocks", 1.6)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#7a5a3a")
	LunariaTextures.apply(wood, "planks", 1.2)
	var mark := Node3D.new()
	mark.name = "MarcoCentral"
	root.add_child(mark)
	var title := ""
	match zone_id:
		9: # Carvalho Ancião e poço de pedra
			title = "🌳 Carvalho Ancião do Bosque Ralo"
			_landmark_mesh(mark, _cyl_mesh(1.6, 2.2, 12.0), _plain_mat(Color("#5b4330")), Vector3(0, 6, 0))
			_landmark_mesh(mark, _sphere_mesh(8.0), _plain_mat(Color("#4f8a3a")), Vector3(0, 15, 0), Vector3(1.2, 0.8, 1.2))
			_landmark_mesh(mark, _cyl_mesh(1.4, 1.4, 1.0), stone, Vector3(10, 0.5, 6))
		10: # Moinho de vento
			title = "🌾 Moinho dos Campos Rasteiros"
			_landmark_mesh(mark, _cyl_mesh(2.2, 3.4, 11.0), stone, Vector3(0, 5.5, 0))
			_landmark_mesh(mark, _cyl_mesh(0.0, 3.6, 3.0), wood, Vector3(0, 12.5, 0))
			var blades := Node3D.new()
			blades.position = Vector3(0, 10.5, -3.6)
			mark.add_child(blades)
			for k in range(4):
				var bl := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(1.2, 7.5, 0.15)
				bl.mesh = bm
				bl.material_override = wood
				bl.rotation.z = k * PI / 2.0
				bl.position = Vector3(cos(k * PI / 2.0 + PI / 2.0) * 3.6, sin(k * PI / 2.0 + PI / 2.0) * 3.6, 0)
				blades.add_child(bl)
			var spin := blades.create_tween().set_loops()
			spin.tween_property(blades, "rotation:z", TAU, 9.0).as_relative()
		11: # Baobá
			title = "🌳 Baobá Solitário da Savana"
			_landmark_mesh(mark, _cyl_mesh(3.0, 4.2, 14.0), _plain_mat(Color("#8b6e55")), Vector3(0, 7, 0))
			for k in range(6):
				var ang := k * TAU / 6.0
				_landmark_mesh(mark, _cyl_mesh(0.4, 0.7, 6.0), _plain_mat(Color("#8b6e55")), Vector3(cos(ang) * 2.5, 15.5, sin(ang) * 2.5), Vector3.ONE, Vector3(sin(ang) * 35, 0, -cos(ang) * 35))
			_landmark_mesh(mark, _sphere_mesh(5.0), _plain_mat(Color("#7d8f3c")), Vector3(0, 18.5, 0), Vector3(1.6, 0.35, 1.6))
		12: # Obelisco de sal
			title = "🧂 Obelisco de Sal Escaldante"
			var salt := _plain_mat(Color("#f1ece0"))
			salt.emission_enabled = true
			salt.emission = Color("#fff4d6")
			salt.emission_energy_multiplier = 0.3
			_landmark_mesh(mark, _cyl_mesh(0.6, 2.4, 16.0, 4), salt, Vector3(0, 8, 0))
		13: # Torre de vigia
			title = "🌬️ Torre de Vigia dos Ventos"
			_landmark_mesh(mark, _cyl_mesh(3.0, 3.6, 16.0), stone, Vector3(0, 8, 0))
			_landmark_mesh(mark, _cyl_mesh(4.2, 3.2, 1.2), stone, Vector3(0, 16.6, 0))
			var flag := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.05, 1.6, 2.6)
			flag.mesh = fm
			flag.material_override = _plain_mat(Color("#2e7dc8"))
			flag.position = Vector3(0, 20.0, 1.4)
			mark.add_child(flag)
			_landmark_mesh(mark, _cyl_mesh(0.08, 0.08, 4.5), wood, Vector3(0, 19.4, 0))
			var wave := flag.create_tween().set_loops()
			wave.tween_property(flag, "rotation:y", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
			wave.tween_property(flag, "rotation:y", -0.35, 1.1).set_trans(Tween.TRANS_SINE)
		14: # Mirante do glaciar (marco de pedras)
			title = "🏔️ Mirante do Glaciar"
			var ice := _plain_mat(Color("#b9e3f5"))
			ice.emission_enabled = true
			ice.emission = Color("#a6dcff")
			ice.emission_energy_multiplier = 0.4
			for k in range(5):
				_landmark_mesh(mark, _sphere_mesh(1.4 - k * 0.2), stone, Vector3(0, 0.9 + k * 1.9, 0), Vector3(1.2, 0.7, 1.0))
			_landmark_mesh(mark, _cyl_mesh(0.0, 1.2, 3.5, 6), ice, Vector3(4, 1.7, 3))
		15: # Arco de basalto
			title = "🪨 Arco de Basalto da Pedreira Velha"
			var basalt := _plain_mat(Color("#3c3a3b"))
			_landmark_mesh(mark, _cyl_mesh(1.4, 1.6, 10.0, 6), basalt, Vector3(-5, 5, 0))
			_landmark_mesh(mark, _cyl_mesh(1.4, 1.6, 10.0, 6), basalt, Vector3(5, 5, 0))
			_landmark_mesh(mark, _box_mesh(Vector3(13.0, 2.2, 3.0)), basalt, Vector3(0, 10.6, 0))
		16: # Palafita do barqueiro
			title = "🛶 Palafita do Barqueiro"
			for px in [-3.0, 3.0]:
				for pz in [-3.0, 3.0]:
					_landmark_mesh(mark, _cyl_mesh(0.25, 0.3, 4.0), wood, Vector3(px, 1.5, pz))
			_landmark_mesh(mark, _box_mesh(Vector3(8.0, 0.3, 8.0)), wood, Vector3(0, 3.4, 0))
			_landmark_mesh(mark, _box_mesh(Vector3(6.0, 3.0, 6.0)), wood, Vector3(0, 5.0, 0))
			_landmark_mesh(mark, _cyl_mesh(0.0, 5.2, 2.6, 4), _plain_mat(Color("#6d5a3a")), Vector3(0, 7.8, 0))
	var lbl := Label3D.new()
	lbl.text = "%s\n%s" % [title, LunariaWorldData.ZONES[zone_id]["name"]]
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 30
	lbl.outline_size = 8
	lbl.modulate = Color(1.0, 0.95, 0.75)
	lbl.position = Vector3(0, 24.0, 0)
	mark.add_child(lbl)

func _plain_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	return m

func _cyl_mesh(top: float, bottom: float, h: float, segs: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	return m

func _sphere_mesh(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m

func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _landmark_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Fonte de Água Purificada: bacia de pedra em volta do Cristal do Renascimento, com água
## luminosa e quatro jorros. O nó de coleta (servidor) fica na borda sul da bacia.
func _build_purified_fountain(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "PurifiedFountain"
	parent.add_child(root)
	var stone := StandardMaterial3D.new()
	LunariaTextures.apply(stone, "stone", 0.9, false)
	stone.albedo_color = Color("#c9c3b4")
	stone.roughness = 0.8
	# Mureta da bacia (anel de 16 blocos)
	var seg := 16
	for i in range(seg):
		var ang := TAU * float(i) / float(seg)
		var block := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.38, 0.62, 0.42)
		block.mesh = bm
		block.material_override = stone
		block.position = Vector3(cos(ang) * 3.2, 0.31, sin(ang) * 3.2)
		block.rotation.y = -ang + PI * 0.5
		root.add_child(block)
	var floor_mesh := MeshInstance3D.new()
	var fc := CylinderMesh.new()
	fc.top_radius = 3.05
	fc.bottom_radius = 3.05
	fc.height = 0.1
	floor_mesh.mesh = fc
	floor_mesh.material_override = stone
	floor_mesh.position = Vector3(0, 0.05, 0)
	root.add_child(floor_mesh)
	# Água purificada: azul-celeste levemente luminosa
	var water := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = 3.0
	wc.bottom_radius = 3.0
	wc.height = 0.04
	water.mesh = wc
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.18, 0.5, 0.78, 0.78)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.3
	wm.roughness = 0.05
	wm.emission_enabled = true
	wm.emission = Color(0.2, 0.55, 0.9)
	wm.emission_energy_multiplier = 0.25
	water.material_override = wm
	water.position = Vector3(0, 0.45, 0)
	root.add_child(water)
	var shimmer := water.create_tween().set_loops()
	shimmer.tween_property(wm, "emission_energy_multiplier", 0.45, 2.2).set_trans(Tween.TRANS_SINE)
	shimmer.tween_property(wm, "emission_energy_multiplier", 0.2, 2.2).set_trans(Tween.TRANS_SINE)
	# Quatro jorros saindo do pedestal do cristal
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var jet := GPUParticles3D.new()
		jet.amount = 40
		jet.lifetime = 0.9
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(cos(ang), 1.6, sin(ang)).normalized()
		pm.spread = 6.0
		pm.initial_velocity_min = 3.0
		pm.initial_velocity_max = 3.6
		pm.gravity = Vector3(0, -9.8, 0)
		pm.scale_min = 0.6
		pm.scale_max = 1.0
		pm.color = Color(0.75, 0.93, 1.0, 0.85)
		jet.process_material = pm
		var drop := SphereMesh.new()
		drop.radius = 0.05
		drop.height = 0.1
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.albedo_color = Color(0.8, 0.95, 1.0, 0.85)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.vertex_color_use_as_albedo = true
		drop.material = dm
		jet.draw_pass_1 = drop
		jet.position = Vector3(cos(ang) * 1.6, 0.6, sin(ang) * 1.6)
		root.add_child(jet)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.55, 0.85, 1.0)
	glow.light_energy = 1.2
	glow.omni_range = 7.0
	glow.position = Vector3(0, 1.0, 0)
	root.add_child(glow)
	var sign := Label3D.new()
	sign.text = "💧 Fonte de Água Purificada"
	sign.font_size = 34
	sign.outline_size = 8
	sign.modulate = Color(0.7, 0.92, 1.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 0.9, 3.6)
	root.add_child(sign)


# Qualidades rápidas do menu de drops do Dev (0 = qualidade padrão do jogo)
const DEV_QUALITY_PRESETS := [[0, "🎲 Padrão"], [25, "🟫 Ruim (25)"], [50, "⬜ Comum (50)"], [70, "🟩 Boa (70)"], [90, "🟦 Excelente (90)"], [100, "🟨 Perfeita (100)"]]
var _dev_quality_popup: Control = null

## Pequeno menu para escolher a Qualidade do material antes de colocá-lo no inventário.
func _dev_pick_quality(what: String, on_pick: Callable) -> void:
	if _dev_quality_popup and is_instance_valid(_dev_quality_popup):
		_dev_quality_popup.queue_free()
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dev_canvas_layer.add_child(holder)
	var pop := PanelContainer.new()
	_dev_quality_popup = holder
	pop.custom_minimum_size = Vector2(340, 0)
	holder.add_child(pop)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pop.add_child(vb)
	var title := Label.new()
	title.text = "⚖️ Qualidade — %s" % what
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
	vb.add_child(title)
	var choose := func(q: int):
		NetworkManager.send_world_control(15, q)
		on_pick.call(q)
		holder.queue_free()
	for preset in DEV_QUALITY_PRESETS:
		var qv: int = preset[0]
		var b := Button.new()
		b.text = preset[1]
		b.pressed.connect(func(): choose.call(qv))
		vb.add_child(b)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = 100
	slider.value = 80
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(slider)
	var custom := Button.new()
	custom.text = "Pegar com 80"
	slider.value_changed.connect(func(v: float): custom.text = "Pegar com %d" % int(v))
	custom.pressed.connect(func(): choose.call(int(slider.value)))
	hb.add_child(custom)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(func(): holder.queue_free())
	vb.add_child(cancel)


# =============================================================================
# PRÉDIOS DA VILA E INTERIORES (dados em WorldData.BUILDINGS, gerados do servidor)
# =============================================================================
const HOUSE_STYLES := {
	"forge": {"wall": Color(0.42, 0.38, 0.34), "roof": Color(0.32, 0.18, 0.12), "trim": Color(0.25, 0.16, 0.1), "chimney": true},
	"tavern": {"wall": Color(0.78, 0.68, 0.52), "roof": Color(0.5, 0.24, 0.14), "trim": Color(0.3, 0.19, 0.11), "chimney": true},
	"lab": {"wall": Color(0.62, 0.58, 0.7), "roof": Color(0.33, 0.2, 0.42), "trim": Color(0.26, 0.18, 0.3), "chimney": true},
	"barracks": {"wall": Color(0.55, 0.57, 0.6), "roof": Color(0.16, 0.25, 0.45), "trim": Color(0.22, 0.24, 0.3), "chimney": false},
	"hunter": {"wall": Color(0.45, 0.32, 0.2), "roof": Color(0.24, 0.17, 0.1), "trim": Color(0.22, 0.14, 0.08), "chimney": true},
	"atelier": {"wall": Color(0.85, 0.83, 0.8), "roof": Color(0.2, 0.45, 0.5), "trim": Color(0.3, 0.3, 0.36), "chimney": false},
	"house": {"wall": Color(0.82, 0.76, 0.64), "roof": Color(0.55, 0.28, 0.18), "trim": Color(0.32, 0.21, 0.13), "chimney": true},
}

func _house_mat(tex: String, col: Color, scale: float = 1.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	LunariaTextures.apply(m, tex, scale, false)
	m.albedo_color = col
	m.roughness = 0.85
	return m

func _house_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## Casa enxaimel de fachada fechada: fundação de pedra, paredes rebocadas com vigas, telhado de duas
## águas, porta, janelas iluminadas e placa. A porta tem um Area3D invisível que leva ao interior.
func _create_village_house(parent: Node3D, b: Dictionary) -> void:
	var key: String = b["key"]
	var style: Dictionary = HOUSE_STYLES.get("house" if key.begins_with("house") else key, HOUSE_STYLES["house"])
	var door: String = b["door"]
	var w: float = b["w"]
	var d: float = b["d"]
	var h: float = b["h"]
	# Moldura local: porta sempre em -z; gira o prédio para a porta olhar para o lado certo
	var lw := w
	var ld := d
	var yaw := 0.0
	match door:
		"north": yaw = PI
		"east":
			yaw = -PI * 0.5
			lw = d
			ld = w
		"west":
			yaw = PI * 0.5
			lw = d
			ld = w
	var body := StaticBody3D.new()
	body.name = "House_" + key
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(b["x"], ground_y(b["x"], b["z"]), b["z"])
	body.rotation.y = yaw
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(lw, h, ld)
	cs.shape = shape
	cs.position = Vector3(0, h * 0.5, 0)
	body.add_child(cs)

	var stone := _house_mat("stone_blocks", Color(0.55, 0.53, 0.5))
	var plaster := _house_mat("plaster", style["wall"], 1.5)
	var beam := _house_mat("wood", style["trim"], 0.6)
	var roof_mat := _house_mat("roof_tiles", style["roof"], 1.6)
	_house_box(body, Vector3(0, 0.25, 0), Vector3(lw + 0.4, 0.5, ld + 0.4), stone)
	_house_box(body, Vector3(0, 0.5 + (h - 0.5) * 0.5, 0), Vector3(lw, h - 0.5, ld), plaster)
	# Vigas aparentes (cantos e cinta no meio da altura)
	for cx in [-lw * 0.5, lw * 0.5]:
		for cz in [-ld * 0.5, ld * 0.5]:
			_house_box(body, Vector3(cx, h * 0.5, cz), Vector3(0.32, h, 0.32), beam)
	_house_box(body, Vector3(0, h * 0.55, -ld * 0.5 - 0.02), Vector3(lw, 0.22, 0.12), beam)
	_house_box(body, Vector3(0, h * 0.55, ld * 0.5 + 0.02), Vector3(lw, 0.22, 0.12), beam)
	_house_box(body, Vector3(0, h - 0.1, 0), Vector3(lw + 0.3, 0.22, ld + 0.3), beam)
	# Telhado de duas águas (cumeeira ao longo da fachada)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(ld + 1.0, 2.4, lw + 0.9)
	roof.mesh = prism
	roof.material_override = roof_mat
	roof.position = Vector3(0, h + 1.2, 0)
	roof.rotation.y = PI * 0.5
	body.add_child(roof)
	if style["chimney"]:
		_house_box(body, Vector3(lw * 0.3, h + 1.8, ld * 0.15), Vector3(0.8, 2.6, 0.8), stone)
	# Porta de madeira com batente e lampião
	var front := -ld * 0.5 - 0.06
	_house_box(body, Vector3(0, 1.3, front), Vector3(1.7, 2.6, 0.1), _house_mat("planks", Color(0.36, 0.22, 0.12), 0.8))
	_house_box(body, Vector3(-0.95, 1.35, front - 0.03), Vector3(0.2, 2.8, 0.16), beam)
	_house_box(body, Vector3(0.95, 1.35, front - 0.03), Vector3(0.2, 2.8, 0.16), beam)
	_house_box(body, Vector3(0, 2.8, front - 0.03), Vector3(2.1, 0.2, 0.16), beam)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.45)
	lamp.light_energy = 1.2
	lamp.omni_range = 5.0
	lamp.position = Vector3(1.4, 2.6, front - 0.4)
	body.add_child(lamp)
	# Janelas com luz quente
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.85, 0.55)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.75, 0.4)
	glass.emission_energy_multiplier = 0.8
	for wx in [-lw * 0.3, lw * 0.3]:
		_house_box(body, Vector3(wx, h * 0.38 + 0.6, front), Vector3(1.0, 0.9, 0.08), glass)
		_house_box(body, Vector3(wx, h * 0.38 + 0.12, front - 0.05), Vector3(1.2, 0.12, 0.2), beam)
	# Placa pendurada sobre a porta (pequena, sem brilho)
	var sign := Label3D.new()
	sign.text = b["name"]
	sign.font_size = 18
	sign.outline_size = 5
	sign.modulate = Color(1.0, 0.9, 0.7)
	sign.position = Vector3(0, 3.25, front - 0.12)
	sign.rotation.y = PI
	sign.visibility_range_end = 30.0
	body.add_child(sign)
	# Área da porta (invisível): ao tentar entrar, o jogador já é levado para dentro
	var area := Area3D.new()
	area.name = "Door_%s" % key
	area.collision_layer = 0
	area.collision_mask = 2 | 1
	area.position = Vector3(0, 1.3, front - 0.55)
	body.add_child(area)
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(1.8, 2.6, 1.0)
	acs.shape = abox
	area.add_child(acs)
	var interior: int = b["interior"]
	var in_portal: int = b["in_portal"]
	area.body_entered.connect(func(entered: Node3D):
		if entered == local_player:
			_on_portal_body_entered(interior, in_portal, false)
	)

## Braseiro do pátio da Forja: onde os moradores se aquecem (PlaceFurnace no servidor).
func _create_forge_yard_brazier(parent: Node3D) -> void:
	var root := Node3D.new()
	root.position = Vector3(35.0, ground_y(35.0, 17.0), 17.0)
	parent.add_child(root)
	var bowl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.35
	cm.height = 0.8
	bowl.mesh = cm
	bowl.material_override = _house_mat("metal_hammered", Color(0.25, 0.23, 0.22), 0.5)
	bowl.position = Vector3(0, 0.6, 0)
	root.add_child(bowl)
	_add_fire(root, Vector3(0, 1.05, 0), 0.5)

func _add_fire(parent: Node3D, pos: Vector3, size: float) -> void:
	var fire := GPUParticles3D.new()
	fire.amount = 36
	fire.lifetime = 0.8
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.6, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	fire.process_material = pm
	var q := SphereMesh.new()
	q.radius = size * 0.35
	q.height = size * 0.7
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = fm
	fire.draw_pass_1 = q
	fire.position = pos
	parent.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.5
	light.omni_range = 6.0 + size * 4.0
	light.position = pos + Vector3(0, 0.4, 0)
	parent.add_child(light)
	var flick := light.create_tween().set_loops()
	flick.tween_property(light, "light_energy", 3.1, 0.18)
	flick.tween_property(light, "light_energy", 2.2, 0.23)

## Interior de um prédio da Vila: sala de 24 x 21,5 m com porta na parede sul.
func _build_interior(root: Node3D, zone_id: int) -> void:
	var bdef: Dictionary = {}
	for b in LunariaWorldData.BUILDINGS:
		if int(b["interior"]) == zone_id:
			bdef = b
			break
	var key: String = String(bdef.get("key", "house"))
	if key.begins_with("house"):
		key = "house"
	var style: Dictionary = HOUSE_STYLES.get(key, HOUSE_STYLES["house"])
	var floor_tex: String = "stone_blocks" if key in ["forge", "barracks"] else ("marble" if key == "atelier" else "planks")
	_create_zone_floor(root, Vector3(26.0, 1.0, 26.0), Color(0.5, 0.42, 0.34), 0.8, Vector3(8, 8, 1))
	var floor_top := _house_mat(floor_tex, Color(0.55, 0.45, 0.35) if floor_tex == "planks" else Color(0.6, 0.58, 0.55), 1.4)
	_house_box(root, Vector3(0, 0.01, 1.25), Vector3(24.0, 0.02, 21.5), floor_top)
	var wall_mat := _house_mat("plaster", style["wall"].lightened(0.1), 1.5)
	var beam := _house_mat("wood", style["trim"], 0.6)
	var dz: float = -LunariaWorldData.INTERIOR_DOOR_Z - 0.5
	var wh := 6.0
	_create_wall_segment(root, Vector3(0, wh * 0.5, 12.25), Vector3(24.5, wh, 0.5), wall_mat)
	_create_wall_segment(root, Vector3(-12.25, wh * 0.5, 1.25), Vector3(0.5, wh, 21.5), wall_mat)
	_create_wall_segment(root, Vector3(12.25, wh * 0.5, 1.25), Vector3(0.5, wh, 21.5), wall_mat)
	_create_wall_segment(root, Vector3(-6.35, wh * 0.5, dz), Vector3(11.8, wh, 0.5), wall_mat)
	_create_wall_segment(root, Vector3(6.35, wh * 0.5, dz), Vector3(11.8, wh, 0.5), wall_mat)
	_create_wall_segment(root, Vector3(0, 4.4, dz), Vector3(0.9, 3.2, 0.5), wall_mat)
	for bx in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		_house_box(root, Vector3(bx, wh - 0.2, 1.25), Vector3(0.35, 0.35, 21.5), beam)
	# Porta de saída (Area3D invisível na soleira) e plaquinha
	_house_box(root, Vector3(0, 1.4, dz - 0.3), Vector3(1.7, 2.8, 0.1), _house_mat("planks", Color(0.36, 0.22, 0.12), 0.8))
	var exit_lbl := Label3D.new()
	exit_lbl.text = "🚪 Saída"
	exit_lbl.font_size = 16
	exit_lbl.outline_size = 5
	exit_lbl.position = Vector3(0, 3.2, dz + 0.3)
	exit_lbl.visibility_range_end = 12.0
	root.add_child(exit_lbl)
	var exit_area := Area3D.new()
	exit_area.collision_layer = 0
	exit_area.collision_mask = 2 | 1
	exit_area.position = Vector3(0, 1.3, dz + 0.55)
	root.add_child(exit_area)
	var ecs := CollisionShape3D.new()
	var ebox := BoxShape3D.new()
	ebox.size = Vector3(2.2, 2.6, 0.7)
	ecs.shape = ebox
	exit_area.add_child(ecs)
	var out_portal: int = int(bdef.get("out_portal", 0))
	exit_area.body_entered.connect(func(entered: Node3D):
		if entered == local_player:
			_on_portal_body_entered(0, out_portal, false)
	)
	# Iluminação quente
	for lp in [Vector3(-6, 4.5, 3), Vector3(6, 4.5, 3), Vector3(0, 4.5, -4)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.6)
		l.light_energy = 1.6
		l.omni_range = 11.0
		l.position = lp
		root.add_child(l)
	var title := Label3D.new()
	title.text = String(bdef.get("name", "Interior"))
	title.font_size = 30
	title.outline_size = 8
	title.modulate = Color(1.0, 0.88, 0.6)
	title.position = Vector3(0, 5.2, 12.0)
	root.add_child(title)
	var wood := Color(0.42, 0.28, 0.16)
	match key:
		"forge":
			# Fornalha acesa: as brasas (servidor: ForgeFirePos) são o único ponto que queima
			var ff: Vector3 = LunariaWorldData.FORGE_FIRE
			var furnace := _create_furniture_piece(root, Vector3(ff.x - 1.6, 1.4, ff.z + 1.4), Vector3(2.6, 2.8, 2.2), Color(0.35, 0.32, 0.3))
			furnace.name = "ForjaFornalha"
			_house_box(root, Vector3(ff.x - 1.6, 4.4, ff.z + 1.6), Vector3(1.2, 3.2, 1.2), _house_mat("stone_blocks", Color(0.4, 0.38, 0.36)))
			var embers := StandardMaterial3D.new()
			embers.albedo_color = Color(1.0, 0.4, 0.1)
			embers.emission_enabled = true
			embers.emission = Color(1.0, 0.35, 0.05)
			embers.emission_energy_multiplier = 2.5
			var pit := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = LunariaWorldData.FORGE_FIRE_RADIUS
			pc.bottom_radius = LunariaWorldData.FORGE_FIRE_RADIUS
			pc.height = 0.12
			pit.mesh = pc
			pit.material_override = embers
			pit.position = Vector3(ff.x, 0.08, ff.z)
			root.add_child(pit)
			_add_fire(root, Vector3(ff.x, 0.3, ff.z), 0.9)
			var warn := Label3D.new()
			warn.text = "🔥 Brasas da Fornalha"
			warn.font_size = 14
			warn.modulate = Color(1.0, 0.6, 0.3)
			warn.position = Vector3(ff.x, 1.8, ff.z)
			warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			warn.visibility_range_end = 10.0
			root.add_child(warn)
			# Bigorna (Garrick trabalha atrás dela) e barril de têmpera
			_create_furniture_piece(root, Vector3(0, 0.45, 1.6), Vector3(0.7, 0.9, 0.7), Color(0.3, 0.28, 0.27))
			_create_furniture_piece(root, Vector3(0, 1.0, 1.6), Vector3(1.5, 0.3, 0.6), Color(0.22, 0.22, 0.24))
			_create_furniture_piece(root, Vector3(-3.5, 0.55, 8.5), Vector3(1.1, 1.1, 1.1), Color(0.35, 0.24, 0.14))
			_create_furniture_piece(root, Vector3(6.0, 0.5, 10.8), Vector3(5.0, 1.0, 1.2), wood)
			_create_furniture_piece(root, Vector3(11.5, 1.6, 3.0), Vector3(0.3, 2.4, 5.0), wood)
			# Espaço livre reservado para as futuras bancadas de criação do ferreiro
			for i in range(3):
				var pad := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(3.0, 0.02, 2.4)
				pad.mesh = pm
				var padm := StandardMaterial3D.new()
				padm.albedo_color = Color(0.3, 0.26, 0.22)
				pad.material_override = padm
				pad.position = Vector3(6.5, 0.025, -3.5 + i * 3.6)
				pad.name = "CraftingSlot_%d" % i
				root.add_child(pad)
		"tavern":
			_create_furniture_piece(root, Vector3(0, 0.6, 9.5), Vector3(10.0, 1.2, 1.2), wood)
			for bx in [-4.0, 0.0, 4.0]:
				_create_furniture_piece(root, Vector3(bx, 0.7, 11.5), Vector3(1.0, 1.4, 1.0), Color(0.36, 0.22, 0.12))
			for tp in [Vector3(-6, 0, 1), Vector3(6, 0, 1), Vector3(-6, 0, -4), Vector3(6, 0, -4)]:
				_create_furniture_piece(root, tp + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 1.4), wood)
			_create_furniture_piece(root, Vector3(-11.3, 1.2, 4), Vector3(1.2, 2.4, 3.0), Color(0.45, 0.42, 0.4))
			_add_fire(root, Vector3(-10.6, 0.5, 4), 0.6)
		"lab":
			_create_furniture_piece(root, Vector3(0, 0.5, 6.5), Vector3(6.0, 1.0, 1.4), wood)
			_create_furniture_piece(root, Vector3(-11.4, 1.6, 2), Vector3(1.0, 3.2, 6.0), wood)
			_create_furniture_piece(root, Vector3(7.0, 0.45, 2.0), Vector3(1.6, 0.9, 1.6), Color(0.2, 0.2, 0.22))
			_add_fire(root, Vector3(7.0, 0.2, 2.0), 0.35)
			for i in range(6):
				var fl := MeshInstance3D.new()
				var fc := CylinderMesh.new()
				fc.top_radius = 0.08
				fc.bottom_radius = 0.14
				fc.height = 0.35
				fl.mesh = fc
				var fmat := StandardMaterial3D.new()
				fmat.albedo_color = [Color(0.4, 1, 0.5), Color(0.5, 0.6, 1), Color(1, 0.4, 0.8)][i % 3]
				fmat.emission_enabled = true
				fmat.emission = fmat.albedo_color
				fmat.emission_energy_multiplier = 1.2
				fl.material_override = fmat
				fl.position = Vector3(-2.2 + i * 0.9, 1.18, 6.5)
				root.add_child(fl)
		"barracks":
			for bz in [-3.0, 1.0, 5.0, 9.0]:
				_create_furniture_piece(root, Vector3(-9.5, 0.4, bz), Vector3(3.6, 0.8, 1.6), Color(0.4, 0.35, 0.3))
			_create_furniture_piece(root, Vector3(9.5, 1.2, 4), Vector3(0.6, 2.4, 6.0), Color(0.3, 0.3, 0.32))
			_create_furniture_piece(root, Vector3(0, 0.45, 5), Vector3(4.0, 0.9, 2.0), wood)
		"hunter":
			_create_furniture_piece(root, Vector3(-8, 0.4, 8), Vector3(3.6, 0.8, 2.0), Color(0.45, 0.35, 0.25))
			_create_furniture_piece(root, Vector3(0, 0.45, 4), Vector3(3.0, 0.9, 1.6), wood)
			_create_furniture_piece(root, Vector3(11.5, 1.8, 2), Vector3(0.2, 1.8, 3.0), Color(0.55, 0.45, 0.35))
			_create_furniture_piece(root, Vector3(-11.3, 1.2, -1), Vector3(1.2, 2.4, 3.0), Color(0.45, 0.42, 0.4))
			_add_fire(root, Vector3(-10.6, 0.5, -1), 0.5)
		"atelier":
			for i in range(3):
				_create_furniture_piece(root, Vector3(-6 + i * 6, 0.55, 6), Vector3(3.0, 1.1, 1.2), Color(0.3, 0.3, 0.36))
				var gem := MeshInstance3D.new()
				var gs := SphereMesh.new()
				gs.radius = 0.18
				gs.height = 0.36
				gem.mesh = gs
				var gm := StandardMaterial3D.new()
				gm.albedo_color = [Color(1, 0.2, 0.25), Color(0.3, 0.5, 1), Color(0.7, 1, 0.9)][i]
				gm.emission_enabled = true
				gm.emission = gm.albedo_color
				gm.emission_energy_multiplier = 1.5
				gem.material_override = gm
				gem.position = Vector3(-6 + i * 6, 1.3, 6)
				root.add_child(gem)
		_: # Casa dos Moradores
			for bx in [-5.0, 5.0]:
				_create_furniture_piece(root, Vector3(bx, 0.35, 8.5), Vector3(2.2, 0.7, 3.2), Color(0.55, 0.4, 0.3))
			_create_furniture_piece(root, Vector3(0, 0.45, 1), Vector3(2.4, 0.9, 1.6), wood)
			_create_furniture_piece(root, Vector3(11.3, 1.2, 2), Vector3(1.2, 2.4, 3.0), Color(0.45, 0.42, 0.4))
			_add_fire(root, Vector3(10.6, 0.5, 2), 0.5)


# =============================================================================
# FORJA (Etapa 2): bigorna da Forja do Garrick [E] ou tecla [U] para Forjadores de Estrelas
# =============================================================================
func _try_use_anvil() -> bool:
	if current_zone_id != 17 or local_player == null:
		return false
	var p := local_player.global_position
	if Vector2(p.x - ForgeDataRef.ANVIL.x, p.z - ForgeDataRef.ANVIL.z).length() > FORGE_ANVIL_REACH:
		return false
	open_forge(false)
	return true

## Abre a Forja: na sala da Forja do Garrick qualquer um; fora dela só o Forjador de Estrelas (classe 7).
func open_forge(from_hotkey: bool) -> void:
	if forge_ui == null:
		return
	if forge_ui.is_open:
		forge_ui.close_menu()
		return
	if current_zone_id != 17 and my_class_id != 7:
		if from_hotkey:
			show_loot_toast("🔨 A Forja fica na Forja do Garrick (bigorna). Só o Forjador de Estrelas forja em qualquer lugar.")
		return
	forge_ui.open_menu()
