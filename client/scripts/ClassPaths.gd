extends RefCounted
## Caminhos Evolutivos das 12 Classes Básicas e Classes Secretas Variantes (13 a 18).
## Os multiplicadores [HP, Stamina, Defesa, Velocidade, Dano] espelham GetSubPathMultipliers em
## server/internal/world/player.go (um teste do servidor confere que os dois continuam iguais).
## Caminho vale a partir do Tier 2: Tier 2-3 usa o primeiro título, Tier 4 Épico usa o título final.

const MULT_LABELS := ["Vida", "Stamina", "Defesa", "Velocidade", "Dano"]

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
		3: {"rare": "Arqueiro Arcano", "epic": "Sagitário Estelar", "focus": "Flechas Arcanas", "mult": [0.95, 1.10, 1.00, 1.05, 1.20]},
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
		1: {"rare": "Lâmina Escultora", "epic": "Escultor da Luz Lunar", "focus": "Cortes de Luar", "mult": [0.95, 1.10, 0.90, 1.20, 1.20]},
		2: {"rare": "Animador", "epic": "Soberano das Estátuas Vivas", "focus": "Estátuas Vivas", "mult": [1.15, 1.10, 1.25, 0.95, 0.95]},
		3: {"rare": "Escultor Elemental", "epic": "Mestre da Catástrofe", "focus": "Esculturas Elementais", "mult": [0.90, 1.10, 0.95, 1.00, 1.25]},
		4: {"rare": "Monumentalista", "epic": "Criador de Maravilhas", "focus": "Monumentos Defensivos", "mult": [1.30, 1.00, 1.20, 0.85, 1.00]},
	},
	10: {
		1: {"rare": "Líder de Alcateia", "epic": "Imperador da Matilha", "focus": "Matilha de Lobos", "mult": [0.95, 1.10, 1.00, 1.15, 1.25]},
		2: {"rare": "Domador de Gigantes", "epic": "Domador de Titãs", "focus": "Feras Gigantes", "mult": [1.20, 1.00, 1.25, 0.90, 1.05]},
		3: {"rare": "Guerreiro Simbiótico", "epic": "Quimera Humana", "focus": "Fusão com a Fera", "mult": [1.25, 0.90, 1.10, 1.00, 1.25]},
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
	13: {"name": "Espadachim Rúnico", "subtitle": "Spellblade", "bases": [1, 2], "color": Color("#40c4ff"),
		"weapon": "Espada Rúnica + Orbe Arcano",
		"passive": ["Lâmina Elemental", "+15% de dano; cada golpe gela o alvo (-20% de velocidade por 1.5s)."],
		"q": ["Corte Flamígero/Glacial", "Corte em arco de 4m (2.0x) que congela e desacelera os alvos.", "4m"],
		"r": ["Escudo de Runas", "Runas protetoras reduzem 70% do dano recebido por 4s.", "Pessoal"],
		"f": ["Cometa da Espada Arcana", "Arremessa a energia da espada num cometa de 5.5m à frente (2.8x).", "5.5m"]},
	14: {"name": "Caçador de Vampiros", "subtitle": "Inquisidor de Prata", "bases": [3, 4], "color": Color("#eceff1"),
		"weapon": "Besta de Prata + Estaca Sagrada",
		"passive": ["Exterminador Noturno", "+40% de dano em criaturas sombrias (Acólitos, Cultistas, Gárgulas, Licantropos, Vampiros e Malakor)."],
		"q": ["Virote de Prata", "Virote perfurante de 22m que atravessa os alvos (1.9x).", "22m"],
		"r": ["Corrente de Exorcismo", "Correntes sagradas prendem todos os inimigos em 6m por 2.5s (1.7x).", "6m"],
		"f": ["Julgamento da Cruz Solar", "Cruz de luz solar explode em 6m (2.8x).", "6m"]},
	15: {"name": "Valquíria da Égide", "subtitle": "Lanceira Celeste", "bases": [6, 1], "color": Color("#fff59d"),
		"weapon": "Lança Dourada + Escudo Alado",
		"passive": ["Voo da Valquíria", "+10% de dano e a esquiva custa metade da Stamina."],
		"q": ["Estocada do Trovão", "Estocada em linha de 6m que atravessa todos à frente (2.0x).", "6m"],
		"r": ["Salto da Valquíria", "Salta 6m (intangível no ar) e cai com impacto de 3.5m (1.8x).", "6m"],
		"f": ["Chuva de Lanças Douradas", "Lanças douradas caem numa área de 6m à frente (2.8x).", "6m"]},
	16: {"name": "Monge das Sombras", "subtitle": "Punho Silencioso", "bases": [5, 4], "color": Color("#7e57c2"),
		"weapon": "Manoplas Sombrias",
		"passive": ["Golpe do Ponto Vital Furtivo", "+30% de chance de crítico e +20% de dano crítico."],
		"q": ["Palma das Sombras", "Palma de energia sombria em cone de 3.5m que atordoa por 1s (2.0x).", "3.5m"],
		"r": ["Passo Fantasma", "Reaparece nas costas do alvo (intangível por 1s) e golpeia (1.6x).", "8m"],
		"f": ["Toque da Morte de Cinco Passos", "Golpe num alvo (3.0x) que explode de novo após cinco passos (5s).", "3.8m"]},
	17: {"name": "Forjador de Armas Amaldiçoadas", "subtitle": "Ferreiro Carmesim", "bases": [7], "color": Color("#c62828"),
		"weapon": "Martelo Carmesim + Espada Viva",
		"passive": ["Têmpera de Sangue", "+10% de dano e 25% de todo dano causado volta como Vida."],
		"q": ["Martelo Hemorrágico", "Martelada em cone de 4m (2.0x) que causa sangramento.", "4m"],
		"r": ["Sacrifício da Bigorna", "Sacrifica 15% da Vida para ganhar +25% de dano por 10s.", "Pessoal"],
		"f": ["Despertar da Espada Demoníaca", "A espada viva desperta e devora tudo em 5.5m (2.9x).", "5.5m"]},
	18: {"name": "Médico da Peste", "subtitle": "Doutor Corvo", "bases": [8, 12], "color": Color("#7cb342"),
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
