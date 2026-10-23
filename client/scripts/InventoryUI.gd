extends CanvasLayer
## Inventário em estilo Livro Aberto: páginas de pergaminho numa moldura de madeira.
## Página esquerda: 14 slots em silhueta humanoide. Página direita: atributos sublinhados
## com a caixa preta de detalhamento. Coluna escura: inspetor do item selecionado.
## Rodapé: grade da mochila, carteira, barra de peso e lixeira.

const ItemData = preload("res://scripts/ItemData.gd")

# Paleta: pergaminho, madeira e tinta
const COL_PARCHMENT := Color(0.85, 0.78, 0.65)
const COL_PARCHMENT_DARK := Color(0.76, 0.68, 0.53)
const COL_WOOD := Color(0.32, 0.22, 0.14)
const COL_WOOD_LIGHT := Color(0.45, 0.32, 0.2)
const COL_INK := Color(0.2, 0.13, 0.08)
const COL_INK_SOFT := Color(0.38, 0.28, 0.18)
const COL_DARK_PANEL := Color(0.07, 0.06, 0.06, 0.97)
const COL_BONUS := Color(0.45, 0.9, 0.45)

var is_open: bool = false
var equipped_slots: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var equipped_armor_id: int = 0
var equipped_acc_id: int = 0
var inventory_items: Array = [] # Array de {"id": int, "quantity": int} na ordem do servidor

# Carteira e peso (0x38)
var gold: int = 0
var eclipse_coins: int = 0
var current_weight: float = 0.0
var max_weight: float = 1.0
var speed_mult: float = 1.0

# Atributos totais vindos do servidor (já com equipamentos)
var stat_totals := {"str": 0, "dex": 0, "con": 0, "agi": 0, "int": 0, "spi": 0, "mas": 0, "lck": 0}

# Seleção atual no inspetor: {"source": "equip"/"bag", "index": int, "id": int, "qty": int}
var selected: Dictionary = {}

const SLOT_COUNT := 14

const SLOT_NAMES := [
	"Elmo", "Peitoral", "Calças", "Botas", "Luvas", "Capa / Túnica", "Colar", "Brinco / Amuleto",
	"Anel 1", "Anel 2", "Anel 3", "Anel 4", "Mão Principal", "Mão Secundária"
]

const SLOT_ICONS := ["🪖", "🛡️", "👖", "👢", "🧤", "🧥", "📿", "💎", "💍", "💍", "💍", "💍", "⚔️", "🔰"]
# Rótulos curtos desenhados dentro dos slots (não dependem de fonte de emoji)
const SLOT_SHORT := ["ELMO", "PEITO", "CALÇA", "BOTAS", "LUVAS", "CAPA", "COLAR", "BRINCO", "ANEL", "ANEL", "ANEL", "ANEL", "ARMA", "ESCUDO"]
const SLOT_CAPTIONS := ["Elmo", "Peitoral", "Calças", "Botas", "Luvas", "Capa", "Colar", "Brinco", "Anel 1", "Anel 2", "Anel 3", "Anel 4", "Mão Princ.", "Mão Sec."]

# Silhueta humanoide: linhas de slots (índices do servidor)
const EQUIP_LAYOUT := [
	[6, 7, 0],
	[5, 1, 4],
	[12, 2, 13],
	[8, 9, 3, 10, 11],
]

# Linhas da página de status: [chave, rótulo]
const STATUS_ROWS := [
	["con", "Vitalidade (CON)"], ["str", "Força (FOR)"], ["agi", "Agilidade (AGI)"], ["dex", "Destreza (DES)"],
	["int", "Inteligência (INT)"], ["spi", "Espírito (ESP)"], ["mas", "Maestria (MAS)"], ["lck", "Sorte (LCK)"],
	["def", "Defesa Física"], ["mdef", "Resistência Mágica"],
]

const BONUS_LABELS := {
	"atk": "Ataque Físico", "def": "Defesa Física", "mdef": "Resistência Mágica", "hp": "Vida Máxima",
	"str": "Força", "dex": "Destreza", "con": "Vitalidade", "agi": "Agilidade",
	"int": "Inteligência", "spi": "Espírito", "mas": "Maestria", "lck": "Sorte",
}

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
		"desc": "Artefato sombrio funerário. Se você morrer durante a noite sob o luar carregando este cálice, sua alma renascerá como a Raça Secreta Cinerion!",
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
		"desc": "Sangue primordial extraído do Licantropo Alfa em frasco de vidro. Ao beber, desperta imediatamente a Linhagem Secreta Sangrael!",
		"color": Color("#d50000"),
		"usable": true,
		"btn_text": "[Beber (Despertar Sangrael)]"
	},
	17: {
		"name": "Tomo da Foice do Eclipse",
		"category": "Artefato Proibido",
		"desc": "Tomo místico selado com as runas da escuridão. Ao consumir, desperta a Classe Secreta 27 — Ceifador da Lua Negra!",
		"color": Color("#aa00ff"),
		"usable": true,
		"btn_text": "[Consumir (Despertar Ceifador)]"
	},
	18: {
		"name": "Núcleo de Forja Estelar",
		"category": "Artefato Arcano",
		"desc": "Fragmento de estrela pulsante com energia rúnica. Entregue ao ferreiro Garrick para despertar a Classe Secreta 14 — Engenheiro Rúnico!",
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
		"desc": "Ampulheta que verte areia cintilante contra o fluxo cósmico. Ao usar, desperta a Linhagem Secreta 28 — Cronari!",
		"color": Color("#ffd54f"),
		"usable": true,
		"btn_text": "[Usar (Despertar Cronari)]"
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
		"name": "Manoplas de Forjador de Estrelas",
		"category": "Luvas",
		"desc": "Luvas pesadas com rebites de latão da forja (+4 FOR, +3 MAS).",
		"color": Color("#ffb74d"),
		"usable": true,
		"btn_text": "[Equipar Luvas]"
	},
	36: {
		"name": "Cinto de Transmutador",
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
	},
	56: {
		"name": "Glândula Real do Escorpião",
		"category": "Relíquia de Classe Única",
		"desc": "Glândula pulsante do Escorpião Abissal (2%). Requisito do Algoz Vorpal (Escarion) — desperte-o num Mestre de Classe.",
		"color": Color("#76ff03"),
		"usable": false,
		"btn_text": ""
	},
	57: {
		"name": "Sangue Puro de Vesperian",
		"category": "Relíquia de Classe Única",
		"desc": "Sangue do Lorde Vesperian (25%). Requisito do Conde Escarlate (Sangrael) — desperte-o num Mestre de Classe.",
		"color": Color("#880e4f"),
		"usable": false,
		"btn_text": ""
	},
	58: {
		"name": "Diagrama do Mecha Gnarlin",
		"category": "Relíquia de Classe Única",
		"desc": "Projeto contrabandeado do Mercado Negro de Varis. Requisito do Barão Engrenagem (Gnarlin) — desperte-o num Mestre de Classe.",
		"color": Color("#ffd600"),
		"usable": false,
		"btn_text": ""
	},
	59: {"name": "Espada Longa de Aço", "category": "Arma — Mão Principal", "desc": "Lâmina equilibrada de aço temperado para uma mão. Golpes rápidos e firmes.", "color": Color("#b0bec5"), "usable": true, "btn_text": "[Equipar Arma]"},
	60: {"name": "Cajado Arcano", "category": "Arma — Mão Principal", "desc": "Cajado de carvalho com um cristal que canaliza a Mana do portador.", "color": Color("#9575cd"), "usable": true, "btn_text": "[Equipar Arma]"},
	61: {"name": "Arco de Caça", "category": "Arma — Mão Principal", "desc": "Arco recurvo de madeira flexível e corda de tripa trançada.", "color": Color("#a1887f"), "usable": true, "btn_text": "[Equipar Arma]"},
	62: {"name": "Adagas Gêmeas", "category": "Arma — Mão Principal", "desc": "Par de adagas leves para cortes rápidos e golpes críticos.", "color": Color("#90a4ae"), "usable": true, "btn_text": "[Equipar Arma]"},
	63: {"name": "Manoplas de Ferro", "category": "Arma — Mão Principal", "desc": "Manoplas reforçadas com nós de ferro para os punhos.", "color": Color("#78909c"), "usable": true, "btn_text": "[Equipar Arma]"},
	64: {"name": "Martelo de Forja", "category": "Arma — Mão Principal", "desc": "Pesado martelo de bigorna que esmaga armaduras.", "color": Color("#8d6e63"), "usable": true, "btn_text": "[Equipar Arma]"},
	65: {"name": "Cutelo Gourmet", "category": "Arma — Mão Principal", "desc": "Cutelo gigante de chef, afiado o bastante para desossar um javali num golpe.", "color": Color("#cfd8dc"), "usable": true, "btn_text": "[Equipar Arma]"},
	66: {"name": "Chicote Bestial", "category": "Arma — Mão Principal", "desc": "Couro trançado que estala como trovão e comanda feras.", "color": Color("#6d4c41"), "usable": true, "btn_text": "[Equipar Arma]"},
	67: {"name": "Agulhas de Aço Rúnicas", "category": "Arma — Mão Principal", "desc": "Agulhas finas com runas que guiam fios cortantes.", "color": Color("#e0e0e0"), "usable": true, "btn_text": "[Equipar Arma]"},
	68: {"name": "Espada Colossal", "category": "Arma — Mão Principal", "desc": "Lâmina gigantesca de duas mãos. Muito pesada, mas devastadora.", "color": Color("#607d8b"), "usable": true, "btn_text": "[Equipar Arma]"},
	69: {"name": "Escudo Bastião", "category": "Mão Secundária", "desc": "Escudo de torre de aço reforçado. Bloqueia quase tudo.", "color": Color("#546e7a"), "usable": true, "btn_text": "[Equipar Escudo]"},
	70: {"name": "Adaga Secundária", "category": "Mão Secundária", "desc": "Uma segunda adaga para a mão esquerda.", "color": Color("#90a4ae"), "usable": true, "btn_text": "[Equipar]"},
	71: {"name": "Orbe Arcano", "category": "Mão Secundária", "desc": "Esfera de cristal que amplifica feitiços e protege contra magia.", "color": Color("#7e57c2"), "usable": true, "btn_text": "[Equipar]"},
	72: {"name": "Catalisador Alquímico", "category": "Mão Secundária", "desc": "Aparelho de vidro e cobre que acelera reações químicas.", "color": Color("#4db6ac"), "usable": true, "btn_text": "[Equipar]"},
	73: {"name": "Wok de Ferro", "category": "Mão Secundária", "desc": "Frigideira de ferro preto que também serve de escudo.", "color": Color("#424242"), "usable": true, "btn_text": "[Equipar]"},
	74: {"name": "Aljava de Caçador", "category": "Mão Secundária", "desc": "Aljava de couro com flechas emplumadas.", "color": Color("#8d6e63"), "usable": true, "btn_text": "[Equipar]"},
	76: {"name": "Placa de Chumbo", "category": "Material de Teste", "desc": "Placa maciça de chumbo (25 kg). Ótima para testar a sobrecarga — e péssima para carregar.", "color": Color("#78909c"), "usable": false, "btn_text": ""},
	75: {"name": "Manopla Secundária", "category": "Mão Secundária", "desc": "Segunda manopla de ferro para combos com as duas mãos.", "color": Color("#78909c"), "usable": true, "btn_text": "[Equipar]"}
}

# Nós da interface
var equip_buttons: Dictionary = {} # slot -> Button
var status_value_labels: Dictionary = {} # chave -> Label
var breakdown_title: Label = null
var breakdown_body: RichTextLabel = null
var inspector_name: Label = null
var inspector_rarity: Label = null
var inspector_body: RichTextLabel = null
var unequip_btn: Button = null
var use_btn: Button = null
var drop_btn: Button = null
var drop_qty: SpinBox = null
var bag_grid: GridContainer = null
var gold_label: Label = null
var eclipse_label: Label = null
var weight_bar: ProgressBar = null
var weight_label: Label = null
var _blink_time: float = 0.0

func _ready() -> void:
	layer = 15
	visible = false
	_build_ui()

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.inventory_updated.connect(_on_inventory_updated)
		if nm.has_signal("wallet_weight_updated"):
			nm.wallet_weight_updated.connect(_on_wallet_weight_updated)
		if nm.has_signal("player_attributes_received"):
			nm.player_attributes_received.connect(_on_player_attributes_received)

func _process(delta: float) -> void:
	if not is_open or weight_bar == null:
		return
	# Sobrecarregado: barra vermelha piscando
	if max_weight > 0.0 and current_weight / max_weight >= 1.3:
		_blink_time += delta * 6.0
		weight_bar.modulate.a = 0.55 + 0.45 * absf(sin(_blink_time))
	else:
		weight_bar.modulate.a = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()

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
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

# ---------------------------------------------------------------------------
# Rede
# ---------------------------------------------------------------------------

func _on_inventory_updated(arg1, arg2 = null, arg3 = null) -> void:
	if arg1 is Array:
		equipped_slots = arg1.duplicate()
		while equipped_slots.size() < SLOT_COUNT:
			equipped_slots.append(0)
		if arg2 is Array:
			inventory_items = arg2
	else:
		equipped_armor_id = int(arg1)
		equipped_acc_id = int(arg2) if arg2 != null else 0
		equipped_slots = [0, equipped_armor_id, 0, 0, 0, 0, 0, 0, equipped_acc_id, 0, 0, 0, 0, 0]
		if arg3 is Array:
			inventory_items = arg3
	_refresh_selection()
	_update_display()

func _on_wallet_weight_updated(p_gold: int, p_eclipse: int, p_cur: float, p_max: float, p_speed: float) -> void:
	gold = p_gold
	eclipse_coins = p_eclipse
	current_weight = p_cur
	max_weight = maxf(p_max, 0.01)
	speed_mult = p_speed
	_update_footer()

func _on_player_attributes_received(_pid: int, _xp: int, _next_xp: int, _pts: int, str_val: int, dex_val: int, con_val: int, agi_val: int, int_val: int, spi_val: int, mas_val: int, lck_val: int) -> void:
	stat_totals = {"str": str_val, "dex": dex_val, "con": con_val, "agi": agi_val, "int": int_val, "spi": spi_val, "mas": mas_val, "lck": lck_val}
	_update_status()

# A seleção acompanha o item depois de um sync (pilha mudou de posição ou sumiu)
func _refresh_selection() -> void:
	if selected.is_empty():
		return
	if selected["source"] == "equip":
		var sid: int = selected["index"]
		if int(equipped_slots[sid]) != int(selected["id"]):
			selected = {}
		return
	for i in range(inventory_items.size()):
		if int(inventory_items[i]["id"]) == int(selected["id"]):
			selected = {"source": "bag", "index": i, "id": int(inventory_items[i]["id"]), "qty": int(inventory_items[i]["quantity"])}
			return
	selected = {}

# ---------------------------------------------------------------------------
# Estilos
# ---------------------------------------------------------------------------

func _box(bg: Color, border: Color, width: int = 2, radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

# Caixa preta chanfrada: cantos cortados (corner_detail = 1) e borda dourada
func _chamfer_box(accent: Color) -> StyleBoxFlat:
	var sb := _box(Color(0.03, 0.03, 0.04, 0.97), accent, 2, 10, 12)
	sb.corner_detail = 1
	return sb

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _page_title(text: String) -> Label:
	var l := _label(text, 15, COL_INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _item_icon(item_id: int) -> String:
	var slot: int = ItemData.slot_of(item_id)
	if slot >= 0:
		return SLOT_ICONS[slot]
	var cat: String = ITEM_CATALOG.get(item_id, {}).get("category", "")
	if "Consum" in cat:
		return "🍖"
	if "Relíquia" in cat or "Desperta" in cat:
		return "✨"
	if "Utilit" in cat:
		return "🧪"
	return "📦"

# Monograma do item (iniciais das duas primeiras palavras significativas)
func _monogram(item_id: int) -> String:
	var words: PackedStringArray = _item_name(item_id).split(" ", false)
	var letters := ""
	for w in words:
		if w.length() > 2 and letters.length() < 2:
			letters += w.substr(0, 1).to_upper()
	return letters if letters != "" else "?"

func _item_color(item_id: int) -> Color:
	return ITEM_CATALOG.get(item_id, {}).get("color", Color(0.6, 0.6, 0.6))

func _item_name(item_id: int) -> String:
	if ITEM_CATALOG.has(item_id):
		return ITEM_CATALOG[item_id]["name"]
	return ItemData.info(item_id)["name"]

# ---------------------------------------------------------------------------
# Construção da interface
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.02, 0.03, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	# Moldura de madeira
	var frame := PanelContainer.new()
	var frame_style := _box(COL_WOOD, Color(0.18, 0.12, 0.07), 6, 12, 14)
	frame_style.shadow_color = Color(0, 0, 0, 0.8)
	frame_style.shadow_size = 18
	frame.add_theme_stylebox_override("panel", frame_style)
	center.add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	frame.add_child(root)

	# Cabeçalho com título entalhado e botão de fechar
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label("📖  Grimório de Viagem — Inventário", 20, Color(0.98, 0.86, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_menu)
	header.add_child(close_btn)

	# Livro aberto: página esquerda | lombada | página direita | inspetor
	var book := HBoxContainer.new()
	book.add_theme_constant_override("separation", 0)
	root.add_child(book)

	book.add_child(_build_equipment_page())
	var spine := ColorRect.new()
	spine.color = COL_WOOD_LIGHT
	spine.custom_minimum_size = Vector2(8, 0)
	book.add_child(spine)
	book.add_child(_build_status_page())

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	book.add_child(gap)
	book.add_child(_build_inspector())

	root.add_child(_build_bag_section())
	root.add_child(_build_footer())

func _build_equipment_page() -> Control:
	var page := PanelContainer.new()
	page.custom_minimum_size = Vector2(330, 340)
	page.add_theme_stylebox_override("panel", _box(COL_PARCHMENT, COL_PARCHMENT_DARK, 2, 4, 14))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	page.add_child(vb)
	vb.add_child(_page_title("⚜ Equipamentos ⚜"))

	for row in EQUIP_LAYOUT:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 10)
		vb.add_child(hb)
		for slot_idx in row:
			hb.add_child(_create_equip_slot(slot_idx))

	var hint := _label("Clique num slot para inspecionar e desequipar.", 11, COL_INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	return page

func _create_equip_slot(slot_idx: int) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(52, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = SLOT_NAMES[slot_idx]
	btn.pressed.connect(func(): _select_equipped(slot_idx))
	vb.add_child(btn)
	var cap := _label(SLOT_CAPTIONS[slot_idx], 9, COL_INK_SOFT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.custom_minimum_size = Vector2(56, 0)
	vb.add_child(cap)
	equip_buttons[slot_idx] = btn
	return vb

func _build_status_page() -> Control:
	var page := PanelContainer.new()
	page.custom_minimum_size = Vector2(300, 340)
	page.add_theme_stylebox_override("panel", _box(COL_PARCHMENT, COL_PARCHMENT_DARK, 2, 4, 14))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	page.add_child(vb)
	vb.add_child(_page_title("✒ Atributos ✒"))

	for row in STATUS_ROWS:
		var key: String = row[0]
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 20)
		btn.mouse_entered.connect(func(): _show_breakdown(key))
		btn.pressed.connect(func(): _show_breakdown(key))
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hb)
		var name_l := _label(row[1], 13, COL_INK)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(name_l)
		var val_l := _label("0", 13, COL_INK)
		val_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(val_l)
		status_value_labels[key] = val_l
		vb.add_child(btn)
		# Linha sublinhada estilo livro
		var line := ColorRect.new()
		line.color = Color(COL_INK_SOFT.r, COL_INK_SOFT.g, COL_INK_SOFT.b, 0.45)
		line.custom_minimum_size = Vector2(0, 1)
		vb.add_child(line)

	# Caixa preta chanfrada de detalhamento
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _chamfer_box(Color(0.95, 0.75, 0.3)))
	box.custom_minimum_size = Vector2(0, 92)
	vb.add_child(box)
	var bvb := VBoxContainer.new()
	box.add_child(bvb)
	breakdown_title = _label("Passe o mouse num atributo", 13, Color(1.0, 0.85, 0.45))
	bvb.add_child(breakdown_title)
	breakdown_body = RichTextLabel.new()
	breakdown_body.bbcode_enabled = true
	breakdown_body.fit_content = true
	breakdown_body.scroll_active = false
	breakdown_body.add_theme_font_size_override("normal_font_size", 12)
	bvb.add_child(breakdown_body)
	return page

func _build_inspector() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 340)
	panel.add_theme_stylebox_override("panel", _box(COL_DARK_PANEL, Color(0.55, 0.42, 0.25), 2, 8, 12))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_label("🔍 Inspetor de Item", 13, Color(0.8, 0.72, 0.55)))

	inspector_name = _label("Nenhum item selecionado", 16, Color(1, 1, 1))
	inspector_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(inspector_name)
	inspector_rarity = _label("", 12, Color(0.7, 0.7, 0.7))
	vb.add_child(inspector_rarity)

	inspector_body = RichTextLabel.new()
	inspector_body.bbcode_enabled = true
	inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_body.add_theme_font_size_override("normal_font_size", 12)
	inspector_body.text = "Clique num item equipado ou da mochila para ver os detalhes."
	vb.add_child(inspector_body)

	unequip_btn = Button.new()
	unequip_btn.text = "⬇️ Desequipar Item"
	unequip_btn.custom_minimum_size = Vector2(0, 40)
	unequip_btn.focus_mode = Control.FOCUS_NONE
	unequip_btn.add_theme_stylebox_override("normal", _box(Color(0.35, 0.18, 0.12), Color(0.9, 0.55, 0.3), 1, 6, 6))
	unequip_btn.pressed.connect(_on_unequip_pressed)
	vb.add_child(unequip_btn)

	use_btn = Button.new()
	use_btn.text = "⬆️ Equipar / Usar"
	use_btn.custom_minimum_size = Vector2(0, 36)
	use_btn.focus_mode = Control.FOCUS_NONE
	use_btn.add_theme_stylebox_override("normal", _box(Color(0.14, 0.3, 0.16), Color(0.45, 0.85, 0.45), 1, 6, 6))
	use_btn.pressed.connect(_on_use_pressed)
	vb.add_child(use_btn)

	var drop_row := HBoxContainer.new()
	vb.add_child(drop_row)
	drop_qty = SpinBox.new()
	drop_qty.min_value = 1
	drop_qty.max_value = 1
	drop_qty.value = 1
	drop_qty.custom_minimum_size = Vector2(80, 0)
	drop_row.add_child(drop_qty)
	drop_btn = Button.new()
	drop_btn.text = "🗑️ Descartar no Chão"
	drop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_btn.focus_mode = Control.FOCUS_NONE
	drop_btn.add_theme_stylebox_override("normal", _box(Color(0.3, 0.1, 0.1), Color(0.85, 0.35, 0.35), 1, 6, 6))
	drop_btn.pressed.connect(_on_drop_pressed)
	drop_row.add_child(drop_btn)
	return panel

func _build_bag_section() -> Control:
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", _box(COL_PARCHMENT, COL_PARCHMENT_DARK, 2, 4, 10))
	var vb := VBoxContainer.new()
	page.add_child(vb)
	vb.add_child(_label("🎒 Mochila", 14, COL_INK))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 114)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	bag_grid = GridContainer.new()
	bag_grid.columns = 14
	bag_grid.add_theme_constant_override("h_separation", 6)
	bag_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(bag_grid)
	return page

func _build_footer() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)

	gold_label = _label("🪙 Sollares: 0", 14, Color(1.0, 0.85, 0.35))
	hb.add_child(gold_label)
	eclipse_label = _label("🌑 Moedas do Eclipse: 0", 14, Color(0.78, 0.6, 1.0))
	hb.add_child(eclipse_label)

	var wvb := VBoxContainer.new()
	wvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(wvb)
	weight_label = _label("⚖️ Peso: 0.0 / 0.0 kg", 13, Color(0.95, 0.9, 0.8))
	wvb.add_child(weight_label)
	weight_bar = ProgressBar.new()
	weight_bar.custom_minimum_size = Vector2(0, 14)
	weight_bar.show_percentage = false
	weight_bar.max_value = 130.0
	wvb.add_child(weight_bar)

	# Lixeira no canto inferior direito: descarta o item selecionado da mochila
	var trash := Button.new()
	trash.text = "🗑️"
	trash.tooltip_text = "Descartar o item selecionado da mochila no chão"
	trash.custom_minimum_size = Vector2(46, 40)
	trash.focus_mode = Control.FOCUS_NONE
	trash.add_theme_font_size_override("font_size", 20)
	trash.add_theme_stylebox_override("normal", _box(Color(0.3, 0.1, 0.1), Color(0.85, 0.35, 0.35), 2, 6, 4))
	trash.pressed.connect(_on_drop_pressed)
	hb.add_child(trash)
	return hb

# ---------------------------------------------------------------------------
# Atualização
# ---------------------------------------------------------------------------

func _update_display() -> void:
	_update_equipment()
	_update_bag()
	_update_status()
	_update_inspector()
	_update_footer()

func _slot_style(item_id: int, is_selected: bool) -> StyleBoxFlat:
	var border := COL_WOOD
	var bg := COL_PARCHMENT_DARK
	if item_id > 0:
		var rar: Array = ItemData.rarity(item_id)
		border = rar[1]
		bg = _item_color(item_id).darkened(0.55)
	if is_selected:
		border = Color(1.0, 0.95, 0.4)
	return _box(bg, border, 3 if is_selected else 2, 4, 2)

func _update_equipment() -> void:
	for slot_idx in equip_buttons.keys():
		var btn: Button = equip_buttons[slot_idx]
		var item_id: int = int(equipped_slots[slot_idx]) if slot_idx < equipped_slots.size() else 0
		var is_sel: bool = not selected.is_empty() and selected["source"] == "equip" and selected["index"] == slot_idx
		btn.text = _monogram(item_id) if item_id > 0 else SLOT_SHORT[slot_idx]
		btn.add_theme_font_size_override("font_size", 18 if item_id > 0 else 9)
		btn.add_theme_color_override("font_color", Color(1, 0.97, 0.88) if item_id > 0 else Color(COL_INK_SOFT.r, COL_INK_SOFT.g, COL_INK_SOFT.b, 0.6)) # silhueta apagada
		btn.tooltip_text = "%s: %s" % [SLOT_NAMES[slot_idx], _item_name(item_id) if item_id > 0 else "(vazio)"]
		var st := _slot_style(item_id, is_sel)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st)
		btn.add_theme_stylebox_override("pressed", st)

func _update_bag() -> void:
	if bag_grid == null:
		return
	for c in bag_grid.get_children():
		c.queue_free()
	for i in range(inventory_items.size()):
		var entry: Dictionary = inventory_items[i]
		bag_grid.add_child(_create_bag_slot(i, int(entry["id"]), int(entry["quantity"])))
	# Completa a grade com espaços vazios para manter o visual de pergaminho
	var empty_count: int = max(0, 28 - inventory_items.size())
	for _i in range(empty_count):
		var blank := Panel.new()
		blank.custom_minimum_size = Vector2(52, 52)
		blank.add_theme_stylebox_override("panel", _box(COL_PARCHMENT_DARK, Color(COL_WOOD.r, COL_WOOD.g, COL_WOOD.b, 0.4), 1, 4, 0))
		bag_grid.add_child(blank)

func _create_bag_slot(bag_index: int, item_id: int, qty: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(52, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = _monogram(item_id)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	btn.tooltip_text = "%s x%d (%.1f kg)" % [_item_name(item_id), qty, ItemData.weight(item_id) * qty]
	var is_sel: bool = not selected.is_empty() and selected["source"] == "bag" and selected["index"] == bag_index
	var st := _slot_style(item_id, is_sel)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.pressed.connect(func(): _select_bag(bag_index))
	# Quantidade no canto inferior direito
	var q := _label(str(qty), 11, Color(1, 1, 1))
	q.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	q.add_theme_constant_override("outline_size", 4)
	q.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	q.position = Vector2(-18, -16)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(q)
	return btn

# Soma dos bônus de equipamento por atributo e a lista de itens que o concedem
func _equip_bonus(key: String) -> Array:
	var total := 0
	var sources: Array = []
	for slot_idx in range(min(SLOT_COUNT, equipped_slots.size())):
		var item_id: int = int(equipped_slots[slot_idx])
		if item_id <= 0:
			continue
		var v: int = int(ItemData.bonus(item_id).get(key, 0))
		if v > 0:
			total += v
			sources.append([_item_name(item_id), v])
	return [total, sources]

func _update_status() -> void:
	for row in STATUS_ROWS:
		var key: String = row[0]
		var lbl: Label = status_value_labels.get(key)
		if lbl == null:
			continue
		if key == "def" or key == "mdef":
			lbl.text = str(_equip_bonus(key)[0])
		else:
			lbl.text = str(stat_totals.get(key, 0))

func _show_breakdown(key: String) -> void:
	var label_text: String = ""
	for row in STATUS_ROWS:
		if row[0] == key:
			label_text = row[1]
	var eb: Array = _equip_bonus(key)
	var equip_total: int = eb[0]
	var sources: Array = eb[1]
	if key == "def" or key == "mdef":
		breakdown_title.text = "%s: %d (Equipamentos)" % [label_text, equip_total]
	else:
		var total: int = int(stat_totals.get(key, 0))
		breakdown_title.text = "%s: %d (%d Base + %d Equipamentos)" % [label_text.split(" (")[0], total, total - equip_total, equip_total]
	var lines: Array = []
	for src in sources:
		lines.append("[color=#73e673]+%d %s[/color]" % [src[1], src[0]])
	if lines.is_empty():
		lines.append("[color=#9e9e9e]Nenhum item equipado concede este atributo.[/color]")
	breakdown_body.text = "\n".join(lines)

func _select_equipped(slot_idx: int) -> void:
	var item_id: int = int(equipped_slots[slot_idx])
	if item_id <= 0:
		selected = {}
	else:
		selected = {"source": "equip", "index": slot_idx, "id": item_id, "qty": 1}
	_update_display()

func _select_bag(bag_index: int) -> void:
	var entry: Dictionary = inventory_items[bag_index]
	selected = {"source": "bag", "index": bag_index, "id": int(entry["id"]), "qty": int(entry["quantity"])}
	_update_display()

func _update_inspector() -> void:
	if inspector_name == null:
		return
	if selected.is_empty():
		inspector_name.text = "Nenhum item selecionado"
		inspector_rarity.text = ""
		inspector_body.text = "Clique num item equipado ou da mochila para ver os detalhes."
		unequip_btn.visible = false
		use_btn.visible = false
		drop_btn.get_parent().visible = false
		return

	var item_id: int = selected["id"]
	var qty: int = selected["qty"]
	var data: Dictionary = ITEM_CATALOG.get(item_id, {})
	var rar: Array = ItemData.rarity(item_id)
	inspector_name.text = _item_name(item_id)
	inspector_name.add_theme_color_override("font_color", data.get("color", Color(1, 1, 1)))
	var cat_text: String = data.get("category", "Item")
	if ItemData.is_material(item_id):
		cat_text = "Material de Forja — %s" % ItemData.CATEGORY_NAMES.get(ItemData.material(item_id)["category"], "")
	elif ItemData.info(item_id).has("tool"):
		cat_text = "Ferramenta de Coleta — Tier %d" % int(ItemData.info(item_id)["tool_tier"])
	inspector_rarity.text = "%s  •  %s" % [rar[0], cat_text]
	inspector_rarity.add_theme_color_override("font_color", rar[1])

	var lines: Array = []
	var b: Dictionary = ItemData.bonus(item_id)
	for key in ["atk", "def", "mdef", "hp", "str", "dex", "con", "agi", "int", "spi", "mas", "lck"]:
		if b.has(key):
			lines.append("[color=#73e673]+%d %s[/color]" % [int(b[key]), BONUS_LABELS[key]])
	if item_id == 15:
		lines.append("[color=#73e673]+15% Roubo de Vida[/color]")
	if ItemData.is_material(item_id):
		var m: Dictionary = ItemData.material(item_id)
		lines.append("[color=#ffd54f]⚒ Propriedades de Forja / Ligas[/color]")
		lines.append("Durabilidade: %d" % int(m["durability"]))
		lines.append("Resistências: [color=#73e673]%s[/color]" % m["resist"])
		lines.append("Condutividade — Térmica %d%% • Elétrica %d%% • Mágica %d%%" % [int(m["thermal"]), int(m["electric"]), int(m["magic"])])
		lines.append("[i]%s[/i]" % m["trait"])
	if not lines.is_empty():
		lines.append("")
	var desc: String = data.get("desc", "")
	if desc != "":
		lines.append("[i]%s[/i]" % desc)
		lines.append("")
	var unit_w: float = ItemData.weight(item_id)
	if qty > 1:
		lines.append("⚖️ Peso: %.1f kg cada  •  %.1f kg na pilha (x%d)" % [unit_w, unit_w * qty, qty])
	else:
		lines.append("⚖️ Peso: %.1f kg" % unit_w)
	if ItemData.slot_of(item_id) >= 0:
		lines.append("🛠 Durabilidade: 100/100")
		lines.append("📍 Slot: %s" % SLOT_NAMES[ItemData.slot_of(item_id)])
	inspector_body.text = "\n".join(lines)

	var is_equipped: bool = selected["source"] == "equip"
	unequip_btn.visible = is_equipped
	use_btn.visible = not is_equipped and (data.get("usable", false) or ItemData.slot_of(item_id) >= 0)
	use_btn.text = "⬆️ Equipar" if ItemData.slot_of(item_id) >= 0 else "⬆️ Usar"
	drop_btn.get_parent().visible = not is_equipped
	drop_qty.max_value = max(1, qty)
	drop_qty.value = clampi(int(drop_qty.value), 1, max(1, qty))
	drop_qty.editable = qty > 1

func _update_footer() -> void:
	if gold_label == null:
		return
	gold_label.text = "🪙 Sollares: %d" % gold
	eclipse_label.text = "🌑 Moedas do Eclipse: %d" % eclipse_coins
	var ratio: float = current_weight / max_weight if max_weight > 0.0 else 0.0
	var pct: int = int(round(ratio * 100.0))
	var status_text := "Normal"
	var col := Color(0.35, 0.8, 0.35)
	if ratio >= 1.3:
		status_text = "🛑 SOBRECARREGADO — IMÓVEL!"
		col = Color(0.95, 0.15, 0.15)
	elif ratio >= 1.0:
		status_text = "Muito Pesado — Lento"
		col = Color(1.0, 0.55, 0.15)
	elif ratio >= 0.7:
		status_text = "Pesado"
		col = Color(0.95, 0.85, 0.2)
	weight_label.text = "⚖️ Peso: %.1f / %.1f kg (%d%% - %s)" % [current_weight, max_weight, pct, status_text]
	weight_label.add_theme_color_override("font_color", col.lightened(0.3))
	weight_bar.value = minf(ratio * 100.0, 130.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	weight_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.08, 0.05)
	bg.set_corner_radius_all(3)
	weight_bar.add_theme_stylebox_override("background", bg)

# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

func _on_unequip_pressed() -> void:
	if selected.is_empty() or selected["source"] != "equip":
		return
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("send_unequip_slot"):
		nm.send_unequip_slot(int(selected["index"]))
	selected = {}
	_update_display()

func _on_use_pressed() -> void:
	if selected.is_empty() or selected["source"] != "bag":
		return
	_on_item_used(int(selected["id"]))

func _on_drop_pressed() -> void:
	if selected.is_empty() or selected["source"] != "bag":
		var world := get_parent()
		if world and world.has_method("show_loot_toast"):
			world.show_loot_toast("Selecione um item da mochila para descartar.")
		return
	var amount: int = clampi(int(drop_qty.value), 1, int(selected["qty"]))
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("send_drop_item_ground"):
		nm.send_drop_item_ground(int(selected["index"]), amount)
	var w := get_parent()
	if w and w.has_method("show_loot_toast"):
		w.show_loot_toast("🗑️ %dx %s descartado(s) no chão." % [amount, _item_name(int(selected["id"]))])

func _on_item_used(item_id: int) -> void:
	print("[InventoryUI] Utilizando/equipando Item ID %d..." % item_id)
	var world := get_parent()
	if world and world.has_method("request_class_or_race_change"):
		match item_id:
			16: # Sangue do Progenitor Bestial -> Raça 5 Sangrael
				world.request_class_or_race_change(true, 5, 1, "Sangrael", "ITEM:16")
				return
			17: # Tomo da Foice do Eclipse -> Classe 27 Ceifador da Lua Negra (Tier 5)
				world.request_class_or_race_change(false, 27, 5, "Ceifador da Lua Negra", "ITEM:17")
				return
			18: # Núcleo de Forja Estelar -> Classe 14 Engenheiro Rúnico (Tier 5)
				world.request_class_or_race_change(false, 35, 5, "Engenheiro Rúnico", "ITEM:18")
				return
			29: # Ampulheta Rúnica -> Raça 28 Cronari
				world.request_class_or_race_change(true, 28, 1, "Cronari", "ITEM:29")
				return
			30: # Casulo de Seda Prateada -> Raça 21 Aracne
				world.request_class_or_race_change(true, 21, 1, "Aracne", "ITEM:30")
				return
			44: # Olho Multifacetado de Arachna -> Raça 21 Aracne
				world.request_class_or_race_change(true, 21, 1, "Aracne", "ITEM:44")
				return
			47: # Ferrão de Escorpião Abissal -> Raça 43 Escarion
				world.request_class_or_race_change(true, 43, 1, "Escarion", "ITEM:47")
				return
			52: # Coração de Geada Eterna -> Raça 31 Jotunar
				world.request_class_or_race_change(true, 31, 1, "Jotunar", "ITEM:52")
				return
			54: # Sangue Puro do Progenitor -> Raça 5 Sangrael
				world.request_class_or_race_change(true, 5, 1, "Sangrael", "ITEM:54")
				return

	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_use_item(item_id)
