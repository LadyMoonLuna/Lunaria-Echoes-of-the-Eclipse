extends RefCounted
## Caminhos Evolutivos das 12 Classes Básicas e Classes Secretas Variantes (13 a 18).
## Os multiplicadores [HP, Stamina, Defesa, Velocidade, Dano] espelham GetSubPathMultipliers em
## server/internal/world/player.go (um teste do servidor confere que os dois continuam iguais).
## Caminho vale a partir do Tier 2: Tier 2-3 usa o primeiro título, Tier 4 Épico usa o título final.

const MULT_LABELS := ["Vida", "Stamina", "Defesa", "Velocidade", "Dano"]

## Nomes das classes por ID (iguais a server/internal/protocol/packets.go).
const CLASS_NAMES := [
	"Viajante (Sem Classe)",
	"Espadachim da Aurora", "Arcanista", "Sentinela dos Ventos", "Lâmina Silente", "Punho Celeste", "Guardião do Bastião",
	"Forjador de Estrelas", "Transmutador", "Escultor de Almas", "Senhor das Feras", "Tecelão Carmesim", "Mestre do Banquete",
	"Lâmina Rúnica", "Inquisidor de Prata", "Valquíria Celeste", "Punho Fantasma",
	"Forjador Carmesim", "Doutor Corvo",
	"Algoz Vorpal", "Senhor da Teia Escarlate", "Rei-Lobo do Eclipse",
	"Runomante Ancestral", "Colosso Abissal", "Arquifada de Yggdra",
	"Conde Escarlate", "Barão Engrenagem",
	"Ceifador da Lua Negra", "Bailarino das Estrelas", "Inquisidor da Chama Branca", "Arauto do Ossuário",
	"Herdeiro da Forja Divina", "Mestre Escultor do Luar", "Imperador Dracônico", "Soberano do Sol Negro",
	"Engenheiro Rúnico", "Demiurgo Alquímico", "Senhor da Selva Primordial", "Cavaleiro do Vazio",
	"Arauto do Trovão"
]


const PATHS := {
	1: {
		1: {"rare": "Gladiador", "epic": "Senhor da Carnificina", "focus": "Dano em Área", "mult": [1.10, 1.00, 1.05, 0.95, 1.15]},
		2: {"rare": "Mestre da Lâmina", "epic": "Santo da Espada", "focus": "Velocidade/Parry", "mult": [0.95, 1.15, 1.00, 1.15, 1.05]},
		3: {"rare": "Comandante", "epic": "Lorde da Aurora", "focus": "Buffs/Defesa", "mult": [1.15, 1.00, 1.20, 1.00, 0.95]},
		4: {"rare": "Berserker", "epic": "Tirano Carmesim", "focus": "Roubo de Vida/Frenesi", "mult": [0.95, 1.10, 0.90, 1.05, 1.20]},
	},
	2: {
		1: {"rare": "Piromante", "epic": "Arquimago Solar", "focus": "Fogo em Área", "mult": [0.95, 0.90, 0.95, 1.00, 1.25]},
		2: {"rare": "Criomante", "epic": "Soberano do Zero Absoluto", "focus": "Gelo e Controle", "mult": [1.15, 1.05, 1.20, 0.95, 1.00]},
		3: {"rare": "Eletromante", "epic": "Senhor do Trovão", "focus": "Raios e Velocidade", "mult": [0.90, 1.10, 0.95, 1.15, 1.15]},
		4: {"rare": "Bruxo do Vazio", "epic": "Arconte Gravitacional", "focus": "Vazio e Gravidade", "mult": [1.05, 1.20, 1.05, 0.95, 1.10]},
	},
	3: {
		1: {"rare": "Franco-Atirador", "epic": "Atirador Fantasma", "focus": "Tiro Crítico Longo", "mult": [0.90, 1.00, 0.90, 0.95, 1.25]},
		2: {"rare": "Dançarino do Vento", "epic": "Tempestade de Flechas", "focus": "Rajadas Velozes", "mult": [0.95, 1.15, 0.95, 1.20, 1.05]},
		3: {"rare": "Sentinela dos Ventos Arcano", "epic": "Sagitário Estelar", "focus": "Flechas Arcanas", "mult": [0.95, 1.10, 1.00, 1.05, 1.20]},
		4: {"rare": "Rastreador", "epic": "Predador de Armadilhas", "focus": "Armadilhas e Controle", "mult": [1.15, 1.10, 1.15, 0.95, 1.00]},
	},
	4: {
		1: {"rare": "Lâmina da Noite", "epic": "Ceifador Silencioso", "focus": "Golpe Crítico Furtivo", "mult": [0.90, 1.05, 0.90, 1.10, 1.30]},
		2: {"rare": "Envenenador", "epic": "Senhor das Pragas", "focus": "Venenos", "mult": [1.00, 1.15, 1.00, 1.05, 1.15]},
		3: {"rare": "Retalhador", "epic": "Turbilhão Carmesim", "focus": "Cortes em Área", "mult": [0.95, 1.10, 0.90, 1.20, 1.20]},
		4: {"rare": "Shinobi", "epic": "Espectro de Seis Sombras", "focus": "Clones e Mobilidade", "mult": [0.90, 1.25, 0.95, 1.15, 1.10]},
	},
	5: {
		1: {"rare": "Pugilista", "epic": "Punho de Titã", "focus": "Socos Devastadores", "mult": [1.05, 1.10, 1.05, 0.95, 1.25]},
		2: {"rare": "Monge", "epic": "Punho Iluminado", "focus": "Chi e Equilíbrio", "mult": [1.00, 1.20, 1.10, 1.15, 1.00]},
		3: {"rare": "Grappler", "epic": "Rei da Submissão", "focus": "Agarrões e Controle", "mult": [1.20, 1.05, 1.15, 0.90, 1.05]},
		4: {"rare": "Brawler Místico", "epic": "Avatar Marcial", "focus": "Artes Marciais Místicas", "mult": [0.95, 1.10, 1.00, 1.10, 1.20]},
	},
	6: {
		1: {"rare": "Guardião", "epic": "Égide Imortal", "focus": "Proteção Absoluta", "mult": [1.30, 1.05, 1.25, 0.90, 0.85]},
		2: {"rare": "Cruzado de Espinhos", "epic": "Bastião Sangrento", "focus": "Reflexo de Dano", "mult": [1.15, 1.00, 1.20, 0.90, 1.05]},
		3: {"rare": "Juggernaut", "epic": "Colosso Imparável", "focus": "Investidas Pesadas", "mult": [1.25, 0.90, 1.15, 0.95, 1.10]},
		4: {"rare": "Templário", "epic": "Paladino da Catedral", "focus": "Luz Sagrada e Cura", "mult": [1.10, 1.10, 1.20, 0.95, 0.90]},
	},
	7: {
		1: {"rare": "Mestre Armeiro", "epic": "Artesão Overgeared", "focus": "Armas Forjadas", "mult": [1.05, 1.05, 1.05, 0.95, 1.20]},
		2: {"rare": "Mestre da Couraça", "epic": "Aço Inquebrável", "focus": "Armaduras e Defesa", "mult": [1.20, 1.00, 1.30, 0.90, 0.95]},
		3: {"rare": "Senhor da Fornalha", "epic": "Titã Vulcânico", "focus": "Fogo da Forja", "mult": [1.15, 0.90, 1.10, 0.95, 1.25]},
		4: {"rare": "Engenheiro Bélico", "epic": "Artilharia Rúnica", "focus": "Máquinas de Guerra", "mult": [0.95, 1.20, 1.05, 1.00, 1.20]},
	},
	8: {
		1: {"rare": "Granadeiro", "epic": "Arquimago da Detonação", "focus": "Explosivos", "mult": [0.90, 1.05, 0.95, 1.00, 1.30]},
		2: {"rare": "Mestre dos Elixires", "epic": "Santo da Panaceia", "focus": "Cura e Elixires", "mult": [1.05, 1.20, 1.10, 1.05, 0.85]},
		3: {"rare": "Mutante", "epic": "Behemoth Químico", "focus": "Mutação Corporal", "mult": [1.25, 1.05, 1.10, 0.90, 1.20]},
		4: {"rare": "Criador de Golems", "epic": "Senhor das Quimeras", "focus": "Golems e Quimeras", "mult": [1.10, 1.15, 1.20, 0.95, 0.95]},
	},
	9: {
		1: {"rare": "Lâmina Escultora", "epic": "Escultor de Almas da Luz Lunar", "focus": "Cortes de Luar", "mult": [0.95, 1.10, 0.90, 1.20, 1.20]},
		2: {"rare": "Animador", "epic": "Soberano das Estátuas Vivas", "focus": "Estátuas Vivas", "mult": [1.15, 1.10, 1.25, 0.95, 0.95]},
		3: {"rare": "Escultor de Almas Elemental", "epic": "Mestre da Catástrofe", "focus": "Esculturas Elementais", "mult": [0.90, 1.10, 0.95, 1.00, 1.25]},
		4: {"rare": "Monumentalista", "epic": "Criador de Maravilhas", "focus": "Monumentos Defensivos", "mult": [1.30, 1.00, 1.20, 0.85, 1.00]},
	},
	10: {
		1: {"rare": "Líder de Alcateia", "epic": "Imperador da Matilha", "focus": "Matilha de Lobos", "mult": [0.95, 1.10, 1.00, 1.15, 1.25]},
		2: {"rare": "Senhor das Feras de Gigantes", "epic": "Senhor das Feras de Titãs", "focus": "Feras Gigantes", "mult": [1.20, 1.00, 1.25, 0.90, 1.05]},
		3: {"rare": "Espadachim da Aurora Simbiótico", "epic": "Chimeryth Humana", "focus": "Fusão com a Fera", "mult": [1.25, 0.90, 1.10, 1.00, 1.25]},
		4: {"rare": "Ginete Selvagem", "epic": "Cavalaria Mítica", "focus": "Montaria Veloz", "mult": [1.05, 1.15, 0.95, 1.25, 1.10]},
	},
	11: {
		1: {"rare": "Retalhador de Fios", "epic": "Mestre dos Fios Invisíveis", "focus": "Fios Cortantes", "mult": [0.90, 1.10, 0.95, 1.10, 1.25]},
		2: {"rare": "Titereiro", "epic": "Arquimago das Marionetes", "focus": "Marionetes", "mult": [1.00, 1.20, 0.90, 1.05, 1.15]},
		3: {"rare": "Bordador Arcano", "epic": "Tecelão do Véu Celestial", "focus": "Bordados Protetores", "mult": [1.20, 1.10, 1.25, 0.95, 0.95]},
		4: {"rare": "Agulha Fantasma", "epic": "Pontos de Pressão", "focus": "Agulhas de Precisão", "mult": [0.90, 1.15, 0.90, 1.15, 1.25]},
	},
	12: {
		1: {"rare": "Açougueiro", "epic": "Chef Carniceiro Abissal", "focus": "Cortes Brutais", "mult": [1.05, 1.05, 0.90, 1.05, 1.30]},
		2: {"rare": "Mestre Cuca", "epic": "Deus da Gastronomia", "focus": "Banquetes de Suporte", "mult": [1.10, 1.25, 1.10, 1.00, 0.90]},
		3: {"rare": "Glutonão", "epic": "Rei Gourmet Devorador", "focus": "Devorar e Resistir", "mult": [1.35, 1.05, 1.15, 0.85, 1.00]},
		4: {"rare": "Mestre da Wok", "epic": "Cozinha Infernal", "focus": "Wok Flamejante", "mult": [0.95, 1.10, 0.95, 1.15, 1.25]},
	},
}

const VARIANTS := {
	13: {"name": "Lâmina Rúnica", "subtitle": "Spellblade", "bases": [1, 2], "color": Color("#40c4ff"),
		"weapon": "Espada Rúnica + Orbe Arcano",
		"passive": ["Lâmina Elemental", "+15% de dano; cada golpe gela o alvo (-20% de velocidade por 1.5s)."],
		"q": ["Corte Flamígero/Glacial", "Corte em arco de 4m (2.0x) que congela e desacelera os alvos.", "4m"],
		"r": ["Escudo de Runas", "Runas protetoras reduzem 70% do dano recebido por 4s.", "Pessoal"],
		"f": ["Cometa da Espada Arcana", "Arremessa a energia da espada num cometa de 5.5m à frente (2.8x).", "5.5m"]},
	14: {"name": "Inquisidor de Prata", "subtitle": "Inquisidor de Prata", "bases": [3, 4], "color": Color("#eceff1"),
		"weapon": "Besta de Prata + Estaca Sagrada",
		"passive": ["Exterminador Noturno", "+40% de dano em criaturas sombrias (Acólitos, Cultistas, Gárgulas, Licantropos, Vampiros e Malakor)."],
		"q": ["Virote de Prata", "Virote perfurante de 22m que atravessa os alvos (1.9x).", "22m"],
		"r": ["Corrente de Exorcismo", "Correntes sagradas prendem todos os inimigos em 6m por 2.5s (1.7x).", "6m"],
		"f": ["Julgamento da Cruz Solar", "Cruz de luz solar explode em 6m (2.8x).", "6m"]},
	15: {"name": "Valquíria Celeste", "subtitle": "Lanceira Celeste", "bases": [6, 1], "color": Color("#fff59d"),
		"weapon": "Lança Dourada + Escudo Alado",
		"passive": ["Voo da Valquíria", "+10% de dano e a esquiva custa metade da Stamina."],
		"q": ["Estocada do Trovão", "Estocada em linha de 6m que atravessa todos à frente (2.0x).", "6m"],
		"r": ["Salto da Valquíria", "Salta 6m (intangível no ar) e cai com impacto de 3.5m (1.8x).", "6m"],
		"f": ["Chuva de Lanças Douradas", "Lanças douradas caem numa área de 6m à frente (2.8x).", "6m"]},
	16: {"name": "Punho Fantasma", "subtitle": "Punho Silencioso", "bases": [5, 4], "color": Color("#7e57c2"),
		"weapon": "Manoplas Sombrias",
		"passive": ["Golpe do Ponto Vital Furtivo", "+20% de chance de crítico e +20% de dano crítico."],
		"q": ["Palma das Sombras", "Palma de energia sombria em cone de 3.5m que atordoa por 1s (2.0x).", "3.5m"],
		"r": ["Passo Fantasma", "Reaparece nas costas do alvo (intangível por 1s) e golpeia (1.6x).", "8m"],
		"f": ["Toque da Morte de Cinco Passos", "Golpe num alvo (3.0x) que explode de novo após cinco passos (5s).", "3.8m"]},
	17: {"name": "Forjador Carmesim", "subtitle": "Forjador de Estrelas Carmesim", "bases": [7], "color": Color("#c62828"),
		"weapon": "Martelo Carmesim + Espada Viva",
		"passive": ["Têmpera de Sangue", "+10% de dano e 25% de todo dano causado volta como Vida."],
		"q": ["Martelo Hemorrágico", "Martelada em cone de 4m (2.0x) que causa sangramento.", "4m"],
		"r": ["Sacrifício da Bigorna", "Sacrifica 15% da Vida para ganhar +25% de dano por 10s.", "Pessoal"],
		"f": ["Despertar da Espada Demoníaca", "A espada viva desperta e devora tudo em 5.5m (2.9x).", "5.5m"]},
	18: {"name": "Doutor Corvo", "subtitle": "Doutor Corvo", "bases": [8, 12], "color": Color("#7cb342"),
		"weapon": "Máscara de Corvo + Bisturi + Incensário",
		"passive": ["Imunidade & Cura Tóxica", "-15% de dano recebido e cada acerto regenera +4 de Vida."],
		"q": ["Bisturi Cirúrgico", "Incisão precisa num alvo (1.9x) que causa sangramento.", "3.8m"],
		"r": ["Incenso Purificador", "Incenso cura +45 de Vida de todos os aliados em 7m.", "7m"],
		"f": ["Nuvem da Peste Negra", "Nuvem de peste em 6m (2.6x) que continua corroendo por 5s.", "6m"]},
}

## Nível mínimo para despertar uma Variante Secreta (Tier 3 Raro).
const VARIANT_MIN_LEVEL := 25

static func has_paths(class_id: int) -> bool:
	return PATHS.has(class_id)

## Título do Caminho para o Tier (vazio se não houver caminho ativo).
static func path_title(class_id: int, tier: int, sub_path: int) -> String:
	if not PATHS.has(class_id) or not PATHS[class_id].has(sub_path) or tier < 2:
		return ""
	var p: Dictionary = PATHS[class_id][sub_path]
	return p["epic"] if tier >= 4 else p["rare"]

## "Gladiador ➔ Senhor da Carnificina".
static func path_full_name(class_id: int, sub_path: int) -> String:
	if not PATHS.has(class_id) or not PATHS[class_id].has(sub_path):
		return ""
	var p: Dictionary = PATHS[class_id][sub_path]
	return "%s ➔ %s" % [p["rare"], p["epic"]]

## Multiplicadores ativos [HP, Stamina, Defesa, Velocidade, Dano] (1.0 sem caminho ou abaixo do Tier 2).
static func active_mult(class_id: int, tier: int, sub_path: int) -> Array:
	if tier < 2 or not PATHS.has(class_id) or not PATHS[class_id].has(sub_path):
		return [1.0, 1.0, 1.0, 1.0, 1.0]
	return PATHS[class_id][sub_path]["mult"]

## Prós e contras do caminho, ex.: "+30% Vida, +25% Defesa, -15% Dano".
static func pros_cons(class_id: int, sub_path: int) -> String:
	if not PATHS.has(class_id) or not PATHS[class_id].has(sub_path):
		return ""
	var parts: Array[String] = []
	var m: Array = PATHS[class_id][sub_path]["mult"]
	for i in m.size():
		var pct: int = roundi((float(m[i]) - 1.0) * 100.0)
		if pct != 0:
			parts.append("%+d%% %s" % [pct, MULT_LABELS[i]])
	return ", ".join(parts) if not parts.is_empty() else "Equilibrado"

static func is_variant(class_id: int) -> bool:
	return VARIANTS.has(class_id)

## Variantes que esta classe básica pode despertar.
static func variants_for_base(base_class_id: int) -> Array:
	var out: Array = []
	for vid in VARIANTS.keys():
		if base_class_id in VARIANTS[vid]["bases"]:
			out.append(vid)
	return out

## Dados de uma Variante no formato do Grimório (SkillsUI.CLASS_ACTIVE_SKILLS); vazio se não for Variante.
static func variant_skill_info(class_id: int) -> Dictionary:
	if not VARIANTS.has(class_id):
		return {}
	var v: Dictionary = VARIANTS[class_id]
	var titles := {}
	for t in range(0, 7):
		titles[t] = "%s (%s)" % [v["name"], v["subtitle"]]
	return {
		"name": v["name"],
		"tier_name": "Variante Secreta — Tier 3 Raro a Tier 4 Épico (sem reset de nível)",
		"desc": "%s. [Passiva: %s] %s" % [v["weapon"], v["passive"][0], v["passive"][1]],
		"color": v["color"],
		"evolved_titles": titles,
		"passive": {"name": v["passive"][0], "desc": v["passive"][1], "tier_scaling": "+9 pontos de atributo por nível no Tier 4 Épico."},
		"basic": {"name": "Ataque Básico [LMB]", "desc": "Golpe com %s (1.0x dano)." % v["weapon"], "range": "3.8m", "cost": "0 Stamina", "cd": "0.45s"},
		"q": {"name": "%s [Q]" % v["q"][0], "desc": v["q"][1], "range": v["q"][2], "cost": "15 Stamina", "cd": "2.0s"},
		"r": {"name": "%s [R]" % v["r"][0], "desc": v["r"][1], "range": v["r"][2], "cost": "20 Stamina", "cd": "4.0s"},
		"f": {"name": "%s [F]" % v["f"][0], "desc": v["f"][1], "range": v["f"][2], "cost": "25 Stamina", "cd": "6.0s"},
	}

## Classes Únicas Exclusivas de Raça (19 a 26, Tier 5) e Lendárias (31 a 34, Tier 6).
## As Únicas Gerais (27 a 30, 35 a 39) já têm página própria no Grimório.
const TRANSCENDENT := {
	19: {"name": "Algoz Vorpal", "kind": "Única de Raça", "color": Color("#76ff03"), "races": [43], "race_name": "Escarion", "requirement": "Lâmina Silente ou Transmutador, ou a Glândula Real", "weapon": "Ferrões duplos venenosos",
		"passive": ["Neurotoxina Absoluta & Sangue Corrosivo", "Venenos causam dano verdadeiro; quem o fere leva 15% do dano de volta em ácido."],
		"q": ["Ferrão Duplo Vorpal", "Dois golpes num alvo (2.5x) que aplicam 3 doses de toxina.", "3.8m"],
		"r": ["Ecdise Ácida", "Fica invisível por 2s, cura 30% da Vida e deixa uma casca que explode em 4m (2.4x).", "4m"],
		"f": ["Execução da Terceira Dose Letal", "4.0x de dano verdadeiro em 4m nos alvos envenenados (os demais levam 60%).", "4m"]},
	20: {"name": "Senhor da Teia Escarlate", "kind": "Única de Raça", "color": Color("#d50000"), "races": [21], "race_name": "Aracne", "requirement": "Tecelão Carmesim ou Lâmina Silente, ou o Olho de Arachna", "weapon": "Fios de seda + oito patas-lâmina",
		"passive": ["Ninho de Seda Viva & Oito Lâminas Dorsais", "As patas de aranha golpeiam junto com cada habilidade (+15% de dano)."],
		"q": ["Fios de Seda Cortante", "Cone de fios de 8m (2.4x) que desacelera.", "8m"],
		"r": ["Casulo de Drenagem", "Casulo que drena em 4m (2.4x) e cura +60 de Vida.", "4m"],
		"f": ["Domínio da Viúva Negra", "Teias venenosas em 10m (3.5x) com veneno e lentidão.", "10m"]},
	21: {"name": "Rei-Lobo do Eclipse", "kind": "Única de Raça", "color": Color("#b71c1c"), "races": [46, 6], "race_name": "Ulvar ou Lupharion", "requirement": "Senhor das Feras ou Punho Celeste", "weapon": "Garras + 2 Lobos Espirituais Alfa",
		"passive": ["Comando Alfa Supremo & Presas de Prata Negra", "2 Lobos Alfa permanentes atacam sozinhos e +10% de dano."],
		"q": ["Frenesi de Mordidas Sincronizadas", "Mordidas em cone de 4m (2.5x) com sangramento.", "4m"],
		"r": ["Uivo do Eclipse Lupino", "Buff de 12s, +40 de Vida e lentidão em 6m.", "6m"],
		"f": ["Caçada Selvagem da Alcateia", "A alcateia avança numa área de 7m à frente (3.6x).", "7m"]},
	22: {"name": "Runomante Ancestral", "kind": "Única de Raça", "color": Color("#ffab40"), "races": [37, 3], "race_name": "Dvergar ou Kharad", "requirement": "Forjador de Estrelas", "weapon": "Martelo rúnico",
		"passive": ["Segredo dos Titãs & Pele de Adamante", "-40% de dano recebido; runas reforçam o equipamento."],
		"q": ["Martelo Trovão da Montanha", "Martelada em cone de 4.5m (2.5x) que atordoa por 1s.", "4.5m"],
		"r": ["Bigorna Ancestral Viva", "+25% de Ataque/Defesa para todos em 8m por 10s e escudo de 3s.", "8m"],
		"f": ["Forja do Ragnarok", "Magma em 6m (3.6x) que continua queimando.", "6m"]},
	23: {"name": "Colosso Abissal", "kind": "Única de Raça", "color": Color("#2e7d32"), "races": [44], "race_name": "Testudar", "requirement": "Guardião do Bastião", "weapon": "Casco colossal",
		"passive": ["Casco Continental & Santuário Móvel", "Converte 50% da Defesa em Ataque (+25% de dano) e -30% de dano recebido."],
		"q": ["Giro de Carapaça Demolidora", "Gira em 4m (2.4x).", "4m"],
		"r": ["Fortaleza Hidráulica", "+75 de Vida e -70% de dano por 4s.", "Pessoal"],
		"f": ["Peso do Oceano Profundo", "Impacto sísmico em 7m (3.5x) e escudo de raid para o grupo.", "7m"]},
	24: {"name": "Arquifada de Yggdra", "kind": "Única de Raça", "color": Color("#f48fb1"), "races": [41], "race_name": "Faelith", "requirement": "Arcanista ou Transmutador", "weapon": "Varinha da Árvore do Mundo",
		"passive": ["Asas de Éter Puro & Miragem Feérica", "35% de chance de esquivar de qualquer dano."],
		"q": ["Rajada de Pó Estelar", "Pó estelar em cone de 8m (2.5x).", "8m"],
		"r": ["Anel de Cogumelos Mágicos", "Cura +70 de Vida do grupo e transforma inimigos em 5m (polimorfia de 3s).", "5m"],
		"f": ["Despertar de Titânia", "Explosão astral em 7m (3.5x) e cura em área.", "7m"]},
	25: {"name": "Conde Escarlate", "kind": "Única de Raça", "color": Color("#880e4f"), "races": [5], "race_name": "Sangrael", "requirement": "o Sangue Puro de Vesperian", "weapon": "Lança de sangue",
		"passive": ["Imortalidade do Sangue & Domínio da Noite", "Volta com 30% de Vida uma vez a cada 10 min; +30% de dano à noite; 15% de roubo de vida."],
		"q": ["Lança de Sangue Congelado", "Lança num alvo a até 10m (2.5x) que desacelera.", "10m"],
		"r": ["Enxame da Noite", "Vira morcegos (intangível 2s) e drena vida em 4m (2.5x).", "4m"],
		"f": ["Trono de Sangue", "Trono de sangue em 9m (3.6x) com roubo de vida.", "9m"]},
	26: {"name": "Barão Engrenagem", "kind": "Única de Raça", "color": Color("#ffd600"), "races": [42], "race_name": "Gnarlin", "requirement": "o Diagrama do Mecha", "weapon": "Mecha de sucata com canhão de moedas",
		"passive": ["Piloto de Exoesqueleto & Ganância Explosiva", "-20% de dano recebido e +15% de chance crítica."],
		"q": ["Canhão de Moedas & Metralha", "Metralha em cone de 7m (2.4x).", "7m"],
		"r": ["Propulsor Turbo", "Dash de 8m intangível.", "8m"],
		"f": ["Autodestruição Nuclear Gnarlin", "Explosão massiva em 8m (3.8x); custa 10% da Vida do piloto.", "8m"]},
	31: {"name": "Herdeiro da Forja Divina", "kind": "Lendária", "color": Color("#ffd700"), "races": [], "race_name": "", "requirement": "", "weapon": "6 espadas lendárias flutuantes",
		"passive": ["Deus da Forja & Espada", "Equipa qualquer arma; 6 espadas lendárias golpeiam junto (+30% de dano)."],
		"q": ["Dança da Espada: Onda", "Onda de espadas em cone de 9m (3.8x).", "9m"],
		"r": ["Transcendência de 6 Espadas", "As 6 espadas varrem 5m (3.6x); buff de 15s e escudo de 3s.", "5m"],
		"f": ["Queda do Deus da Forja", "As espadas caem do céu em 8m (4.8x) — efeito global.", "8m"]},
	32: {"name": "Mestre Escultor do Luar", "kind": "Lendária", "color": Color("#b3e5fc"), "races": [], "race_name": "", "requirement": "", "weapon": "Cinzel do Luar + Estátuas Vivas",
		"passive": ["Estátuas Vivas", "Estátuas vivas lutam junto (+20% de dano)."],
		"q": ["Lâmina da Lua Radiante", "Corte de luar em cone de 6m (3.8x).", "6m"],
		"r": ["Destruição Escultural", "+80% de Ataque por 20s.", "Pessoal"],
		"f": ["Legião Imperial do Luar", "A legião de estátuas varre 9m (4.6x) — efeito global.", "9m"]},
	33: {"name": "Imperador Dracônico", "kind": "Lendária", "color": Color("#ff6d00"), "races": [], "race_name": "", "requirement": "", "weapon": "Chicote do Monarca + Dragão Ancião e Behemoth",
		"passive": ["Monarca das Feras Primordiais", "Dragão Ancião e Behemoth golpeiam junto (+25% de dano)."],
		"q": ["Garra do Monarca", "Garra em cone de 5m (3.9x).", "5m"],
		"r": ["Rugido de Subjugação", "Atordoa todos em 8m por 3s (3.7x) e buff de 10s.", "8m"],
		"f": ["Cataclismo do Rei Dragão", "Fogo de dragão em 10m à frente (5.0x) — efeito global.", "10m"]},
	34: {"name": "Soberano do Sol Negro", "kind": "Lendária", "color": Color("#4a148c"), "races": [], "race_name": "", "requirement": "", "weapon": "Lâmina do Sol Negro",
		"passive": ["Monarca do Eclipse", "Domina Luz e Vazio; a Ultimate transforma o céu em Eclipse por 60s."],
		"q": ["Corte do Horizonte de Eventos", "Corte em cone de 10m (4.0x).", "10m"],
		"r": ["Égide da Aurora e Abismo", "Escudo de 5s, intangível 1s e +80 de Vida para o grupo em 8m.", "8m"],
		"f": ["Apocalipse do Sol Negro", "Dano verdadeiro em 12m (5.0x) e o céu vira Eclipse — efeito global.", "12m"]},
}

## Tier em que a classe é assumida: Lendária 6, Única 5, Variante 3, Básica 1.
static func tier_for_class(class_id: int) -> int:
	if class_id >= 31 and class_id <= 34:
		return 6
	if class_id >= 19:
		return 5
	if class_id >= 13:
		return 3
	return 1

static func is_legendary(class_id: int) -> bool:
	return class_id >= 31 and class_id <= 34

## Aviso de "Sangue Incompatível" (vazio se a raça pode assumir a classe).
static func race_block_message(class_id: int, race_id: int) -> String:
	if not TRANSCENDENT.has(class_id):
		return ""
	var races: Array = TRANSCENDENT[class_id]["races"]
	if races.is_empty() or race_id in races:
		return ""
	return "🔒 Sangue Incompatível! Apenas a raça [%s] possui a anatomia para suportar esta Classe Única!" % TRANSCENDENT[class_id]["race_name"]

## Classes Únicas Exclusivas da raça informada.
static func uniques_for_race(race_id: int) -> Array:
	var out: Array = []
	for cid in TRANSCENDENT.keys():
		if race_id in TRANSCENDENT[cid]["races"]:
			out.append(cid)
	return out

## Dados de uma Única de Raça ou Lendária no formato do Grimório; vazio se não for uma delas.
static func transcendent_skill_info(class_id: int) -> Dictionary:
	if not TRANSCENDENT.has(class_id):
		return {}
	var t: Dictionary = TRANSCENDENT[class_id]
	var legendary: bool = is_legendary(class_id)
	var tier_label: String = "Tier 6 Lendária (+15 pts/nível, +50 nos atributos principais)" if legendary else "Tier 5 Única (+11 pts/nível, +25 no atributo principal e secundário)"
	var titles := {}
	for i in range(0, 7):
		titles[i] = t["name"]
	var req_text: String = ""
	if not t["races"].is_empty():
		req_text = " Exige a raça %s e %s." % [t["race_name"], t["requirement"]]
	return {
		"name": t["name"],
		"tier_name": "%s — reseta para o nível 1" % tier_label,
		"desc": "%s. [Passiva: %s] %s%s" % [t["weapon"], t["passive"][0], t["passive"][1], req_text],
		"color": t["color"],
		"evolved_titles": titles,
		"passive": {"name": t["passive"][0], "desc": t["passive"][1], "tier_scaling": tier_label},
		"basic": {"name": "Ataque Básico [LMB]", "desc": "Golpe com %s (1.0x dano)." % t["weapon"], "range": "3.8m", "cost": "0 Stamina", "cd": "0.45s"},
		"q": {"name": "%s [Q]" % t["q"][0], "desc": t["q"][1], "range": t["q"][2], "cost": "15 Stamina", "cd": "2.0s"},
		"r": {"name": "%s [R]" % t["r"][0], "desc": t["r"][1], "range": t["r"][2], "cost": "20 Stamina", "cd": "4.0s"},
		"f": {"name": "%s [F]" % t["f"][0], "desc": t["f"][1], "range": t["f"][2], "cost": "25 Stamina", "cd": "6.0s"},
	}
