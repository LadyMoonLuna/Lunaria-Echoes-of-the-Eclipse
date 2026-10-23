extends RefCounted
## Dados de itens compartilhados entre Inventário e Status.
## GERADO por tools/gen_item_data.py a partir de server/internal/world/items.go — não edite à mão.
## weight = kg por unidade | slot = 0..13 (-1 = não equipável) | bonus = atributos concedidos.

const SLOT_COUNT := 14
const RING_SLOTS := [8, 9, 10, 11]

const ITEMS := {
	1: {"name": "Frasco de Vidro Vazio", "weight": 0.4, "slot": -1, "bonus": {}},
	2: {"name": "Carne Crua de Lobo", "weight": 0.8, "slot": -1, "bonus": {}},
	3: {"name": "Carne Nobre Assada", "weight": 0.7, "slot": -1, "bonus": {}},
	4: {"name": "Poção de Sangue Lupino", "weight": 0.5, "slot": -1, "bonus": {}},
	5: {"name": "Pelagem Cinzenta de Lobo", "weight": 1.5, "slot": -1, "bonus": {}},
	6: {"name": "Presa Lupina Afiada", "weight": 0.2, "slot": -1, "bonus": {}},
	7: {"name": "Garra de Fera", "weight": 0.3, "slot": -1, "bonus": {}},
	8: {"name": "Sangue Lupino Fresco", "weight": 0.6, "slot": -1, "bonus": {}},
	9: {"name": "Pele Intacta de Lobo Alfa", "weight": 4.5, "slot": 1, "bonus": {"str": 3, "hp": 35, "def": 4}},
	10: {"name": "Sangue Lunar Puro", "weight": 0.6, "slot": -1, "bonus": {}},
	11: {"name": "Glândula de Veneno Sombrio", "weight": 0.5, "slot": -1, "bonus": {}},
	12: {"name": "Placa de Aço Pesada", "weight": 18.0, "slot": 1, "bonus": {"con": 4, "hp": 50, "def": 10}},
	13: {"name": "Anel de Presa Ancestral", "weight": 0.1, "slot": 8, "bonus": {"dex": 3, "agi": 3}},
	14: {"name": "Cálice da Alma Partida", "weight": 0.3, "slot": -1, "bonus": {}},
	15: {"name": "Coração do Licantropo Alfa", "weight": 0.3, "slot": 6, "bonus": {"str": 5, "dex": 5, "con": 5, "agi": 5, "int": 5, "spi": 5, "mas": 5, "lck": 5}},
	16: {"name": "Sangue do Progenitor Bestial", "weight": 0.5, "slot": -1, "bonus": {}},
	17: {"name": "Tomo da Foice do Eclipse", "weight": 1.2, "slot": -1, "bonus": {}},
	18: {"name": "Núcleo de Forja Estelar", "weight": 3.5, "slot": -1, "bonus": {}},
	19: {"name": "Túnica do Cultista Sombrio", "weight": 1.8, "slot": -1, "bonus": {}},
	20: {"name": "Coração Pétreo da Gárgula", "weight": 4.0, "slot": -1, "bonus": {}},
	21: {"name": "Foice de Sombras do Inquisidor", "weight": 14.0, "slot": -1, "bonus": {}},
	22: {"name": "Insígnia do Comandante Traidor", "weight": 0.2, "slot": -1, "bonus": {}},
	23: {"name": "Olho do Arauto do Eclipse", "weight": 0.3, "slot": -1, "bonus": {}},
	24: {"name": "Tocha Sagrada do Santuário", "weight": 1.5, "slot": -1, "bonus": {}},
	25: {"name": "Minério de Ferro", "weight": 4.0, "slot": -1, "bonus": {}},
	26: {"name": "Receita: Malho Rúnico", "weight": 0.1, "slot": -1, "bonus": {}},
	27: {"name": "Malho de Batalha Rúnico", "weight": 16.0, "slot": 12, "bonus": {"str": 8, "con": 6, "mas": 4, "atk": 45}},
	28: {"name": "Lixo Orgânico", "weight": 0.6, "slot": -1, "bonus": {}},
	29: {"name": "Ampulheta Rúnica", "weight": 0.3, "slot": -1, "bonus": {}},
	30: {"name": "Casulo de Seda Prateada", "weight": 0.4, "slot": -1, "bonus": {}},
	31: {"name": "Elmo de Vigia", "weight": 3.5, "slot": 0, "bonus": {"con": 2, "hp": 25, "def": 3}},
	32: {"name": "Peitoral de Aço", "weight": 14.0, "slot": 1, "bonus": {"con": 5, "hp": 60, "def": 8}},
	33: {"name": "Calças de Couro Lupino", "weight": 3.5, "slot": 2, "bonus": {"agi": 3, "hp": 30, "def": 2}},
	34: {"name": "Botas Passo-da-Bruma", "weight": 1.8, "slot": 3, "bonus": {"agi": 4, "dex": 2, "hp": 25, "def": 1}},
	35: {"name": "Manoplas de Forjador de Estrelas", "weight": 2.5, "slot": 4, "bonus": {"str": 4, "mas": 3, "def": 2}},
	36: {"name": "Cinto de Transmutador", "weight": 0.3, "slot": 7, "bonus": {"int": 3, "spi": 3, "mdef": 2}},
	37: {"name": "Colar da Lua Prateada", "weight": 0.2, "slot": 6, "bonus": {"int": 4, "spi": 4, "lck": 3, "mdef": 3}},
	38: {"name": "Anel de Rubi Sanguinário", "weight": 0.1, "slot": 8, "bonus": {"str": 4, "con": 3}},
	39: {"name": "Anel de Obsidiana", "weight": 0.1, "slot": 8, "bonus": {"con": 4, "mas": 3}},
	40: {"name": "Anel Estelar", "weight": 0.1, "slot": 8, "bonus": {"int": 3, "lck": 4}},
	41: {"name": "Capa de Pele Alfa", "weight": 2.5, "slot": 5, "bonus": {"str": 3, "agi": 3, "hp": 35, "def": 2}},
	42: {"name": "Casulo de Seda Perfeito", "weight": 0.4, "slot": -1, "bonus": {}},
	43: {"name": "Coração da Rainha Aranha", "weight": 0.3, "slot": -1, "bonus": {}},
	44: {"name": "Olho Multifacetado de Arachna", "weight": 0.3, "slot": -1, "bonus": {}},
	45: {"name": "Manto de Seda Imperial", "weight": 1.5, "slot": -1, "bonus": {}},
	46: {"name": "Ácido Puro", "weight": 0.5, "slot": -1, "bonus": {}},
	47: {"name": "Ferrão de Escorpião Abissal", "weight": 0.3, "slot": -1, "bonus": {}},
	48: {"name": "Veneno Vorpal", "weight": 0.4, "slot": -1, "bonus": {}},
	49: {"name": "Retalho Quimérico Costurado", "weight": 0.8, "slot": -1, "bonus": {}},
	50: {"name": "Núcleo de Gelo Antigo", "weight": 4.0, "slot": -1, "bonus": {}},
	51: {"name": "Escama Dracônica Primordial", "weight": 3.5, "slot": -1, "bonus": {}},
	52: {"name": "Coração de Geada Eterna", "weight": 0.3, "slot": -1, "bonus": {}},
	53: {"name": "Insígnia do Guarda Carmesim", "weight": 0.2, "slot": -1, "bonus": {}},
	54: {"name": "Sangue Puro do Progenitor", "weight": 0.5, "slot": -1, "bonus": {}},
	55: {"name": "Anel Carmesim de Vesperian", "weight": 0.1, "slot": -1, "bonus": {}},
	56: {"name": "Glândula Real do Escorpião", "weight": 0.5, "slot": -1, "bonus": {}},
	57: {"name": "Sangue Puro de Vesperian", "weight": 0.5, "slot": -1, "bonus": {}},
	58: {"name": "Diagrama do Mecha Gnarlin", "weight": 0.2, "slot": -1, "bonus": {}},
	59: {"name": "Espada Longa de Aço", "weight": 4.2, "slot": 12, "bonus": {"str": 2, "atk": 12}},
	60: {"name": "Cajado Arcano", "weight": 2.2, "slot": 12, "bonus": {"int": 4, "atk": 8, "mdef": 2}},
	61: {"name": "Arco de Caça", "weight": 3.6, "slot": 12, "bonus": {"dex": 3, "atk": 11}},
	62: {"name": "Adagas Gêmeas", "weight": 1.3, "slot": 12, "bonus": {"dex": 2, "lck": 1, "atk": 8}},
	63: {"name": "Manoplas de Ferro", "weight": 2.4, "slot": 12, "bonus": {"str": 2, "atk": 9, "def": 1}},
	64: {"name": "Martelo de Forja", "weight": 14.0, "slot": 12, "bonus": {"str": 4, "mas": 2, "atk": 18}},
	65: {"name": "Cutelo Gourmet", "weight": 12.5, "slot": 12, "bonus": {"str": 3, "mas": 2, "atk": 17}},
	66: {"name": "Chicote Bestial", "weight": 3.8, "slot": 12, "bonus": {"dex": 2, "spi": 1, "atk": 10}},
	67: {"name": "Agulhas de Aço Rúnicas", "weight": 1.2, "slot": 12, "bonus": {"dex": 2, "int": 2, "atk": 9}},
	68: {"name": "Espada Colossal", "weight": 20.0, "slot": 12, "bonus": {"str": 6, "atk": 26}},
	69: {"name": "Escudo Bastião", "weight": 16.0, "slot": 13, "bonus": {"con": 4, "hp": 40, "def": 12}},
	70: {"name": "Adaga Secundária", "weight": 1.2, "slot": 13, "bonus": {"dex": 1, "atk": 5}},
	71: {"name": "Orbe Arcano", "weight": 1.4, "slot": 13, "bonus": {"int": 3, "spi": 2, "mdef": 4}},
	72: {"name": "Catalisador Alquímico", "weight": 1.6, "slot": 13, "bonus": {"int": 2, "mas": 2, "atk": 4}},
	73: {"name": "Wok de Ferro", "weight": 4.0, "slot": 13, "bonus": {"con": 2, "def": 5}},
	74: {"name": "Aljava de Caçador", "weight": 1.5, "slot": 13, "bonus": {"dex": 2, "atk": 4}},
	75: {"name": "Manopla Secundária", "weight": 2.2, "slot": 13, "bonus": {"str": 1, "atk": 5, "def": 1}},
}

static func info(item_id: int) -> Dictionary:
	return ITEMS.get(item_id, {"name": "Item #%d" % item_id, "weight": 0.5, "slot": -1, "bonus": {}})

static func weight(item_id: int) -> float:
	return float(info(item_id).get("weight", 0.5))

static func slot_of(item_id: int) -> int:
	return int(info(item_id).get("slot", -1))

static func bonus(item_id: int) -> Dictionary:
	return info(item_id).get("bonus", {})

## Raridade estimada pela soma dos bônus (apenas visual).
static func rarity(item_id: int) -> Array:
	var total := 0
	var b: Dictionary = bonus(item_id)
	for k in b.keys():
		total += int(b[k])
	if total >= 60:
		return ["Lendário", Color("#ffb300")]
	if total >= 30:
		return ["Épico", Color("#ba68c8")]
	if total >= 12:
		return ["Raro", Color("#4fc3f7")]
	if total > 0:
		return ["Incomum", Color("#81c784")]
	return ["Comum", Color("#bdbdbd")]
