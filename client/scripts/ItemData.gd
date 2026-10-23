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
	43: {"name": "Coração da Rainha Aranha", "weight": 0.3, "slot": -1, "bonus": {}},
	44: {"name": "Olho Multifacetado de Arachna", "weight": 0.3, "slot": -1, "bonus": {}},
	45: {"name": "Manto de Seda Imperial", "weight": 1.5, "slot": -1, "bonus": {}},
	47: {"name": "Ferrão de Escorpião Abissal", "weight": 0.3, "slot": -1, "bonus": {}},
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
	77: {"name": "Adaga de Autópsia", "weight": 0.6, "slot": 12, "bonus": {"dex": 1, "atk": 4}},
	78: {"name": "Sucata Metálica", "weight": 1.0, "slot": -1, "bonus": {}},
	79: {"name": "Poção de Cura", "weight": 0.5, "slot": -1, "bonus": {}},
	80: {"name": "Poção de Mana", "weight": 0.5, "slot": -1, "bonus": {}},
	81: {"name": "Pergaminho de Blueprint", "weight": 0.2, "slot": -1, "bonus": {}},
	76: {"name": "Placa de Chumbo", "weight": 25.0, "slot": -1, "bonus": {}},
	75: {"name": "Manopla Secundária", "weight": 2.2, "slot": 13, "bonus": {"str": 1, "atk": 5, "def": 1}},
	160: {"name": "Machado Velho", "weight": 3.0, "slot": -1, "bonus": {}, "tool": "axe", "tool_tier": 1},
	161: {"name": "Machado de Ferro", "weight": 3.5, "slot": -1, "bonus": {}, "tool": "axe", "tool_tier": 2},
	162: {"name": "Machado de Aço Temperado", "weight": 3.5, "slot": -1, "bonus": {}, "tool": "axe", "tool_tier": 3},
	163: {"name": "Machado de Mithril", "weight": 2.0, "slot": -1, "bonus": {}, "tool": "axe", "tool_tier": 4},
	164: {"name": "Machado de Oricalco", "weight": 3.8, "slot": -1, "bonus": {}, "tool": "axe", "tool_tier": 5},
	165: {"name": "Machado Adamantino", "weight": 4.5, "slot": -1, "bonus": {}, "tool": "axe", "tool_tier": 7},
	166: {"name": "Machado do Sol Negro", "weight": 4.0, "slot": -1, "bonus": {}, "tool": "axe", "tool_tier": 8},
	167: {"name": "Picareta Desgastada", "weight": 3.5, "slot": -1, "bonus": {}, "tool": "pickaxe", "tool_tier": 1},
	168: {"name": "Picareta de Ferro", "weight": 4.0, "slot": -1, "bonus": {}, "tool": "pickaxe", "tool_tier": 2},
	169: {"name": "Picareta de Aço Temperado", "weight": 4.0, "slot": -1, "bonus": {}, "tool": "pickaxe", "tool_tier": 3},
	170: {"name": "Picareta de Mithril", "weight": 2.5, "slot": -1, "bonus": {}, "tool": "pickaxe", "tool_tier": 4},
	171: {"name": "Picareta de Oricalco", "weight": 4.2, "slot": -1, "bonus": {}, "tool": "pickaxe", "tool_tier": 5},
	172: {"name": "Picareta Adamantina", "weight": 5.0, "slot": -1, "bonus": {}, "tool": "pickaxe", "tool_tier": 7},
	173: {"name": "Picareta do Sol Negro", "weight": 4.5, "slot": -1, "bonus": {}, "tool": "pickaxe", "tool_tier": 8},
	174: {"name": "Tesoura de Herborista", "weight": 0.8, "slot": -1, "bonus": {}, "tool": "shears", "tool_tier": 1},
	100: {"name": "Pinho do Refúgio", "weight": 2.0, "slot": -1, "bonus": {}},
	101: {"name": "Carvalho Cinzento", "weight": 3.0, "slot": -1, "bonus": {}},
	102: {"name": "Cedro da Tempestade", "weight": 2.8, "slot": -1, "bonus": {}},
	103: {"name": "Ébano Sussurrante", "weight": 3.2, "slot": -1, "bonus": {}},
	104: {"name": "Salgueiro de Sangue", "weight": 2.6, "slot": -1, "bonus": {}},
	105: {"name": "Madeira-Ferro", "weight": 6.5, "slot": -1, "bonus": {}},
	106: {"name": "Freixo Solar", "weight": 2.4, "slot": -1, "bonus": {}},
	107: {"name": "Raiz de Yggdrasil", "weight": 3.0, "slot": -1, "bonus": {}},
	108: {"name": "Pedra Bruta", "weight": 4.0, "slot": -1, "bonus": {}},
	109: {"name": "Calcário", "weight": 3.5, "slot": -1, "bonus": {}},
	110: {"name": "Basalto", "weight": 5.0, "slot": -1, "bonus": {}},
	111: {"name": "Obsidiana", "weight": 2.5, "slot": -1, "bonus": {}},
	112: {"name": "Pedra-Vazio", "weight": 4.5, "slot": -1, "bonus": {}},
	113: {"name": "Rocha Estelar", "weight": 6.0, "slot": -1, "bonus": {}},
	114: {"name": "Cobre", "weight": 4.5, "slot": -1, "bonus": {}},
	115: {"name": "Estanho", "weight": 4.0, "slot": -1, "bonus": {}},
	116: {"name": "Ferro", "weight": 5.5, "slot": -1, "bonus": {}},
	117: {"name": "Prata", "weight": 5.0, "slot": -1, "bonus": {}},
	118: {"name": "Titânio", "weight": 3.5, "slot": -1, "bonus": {}},
	119: {"name": "Mithril Lunar", "weight": 2.0, "slot": -1, "bonus": {}},
	120: {"name": "Oricalco Rubro", "weight": 4.0, "slot": -1, "bonus": {}},
	121: {"name": "Tungstênio Abissal", "weight": 9.0, "slot": -1, "bonus": {}},
	122: {"name": "Adamantino", "weight": 7.0, "slot": -1, "bonus": {}},
	123: {"name": "Quartzo", "weight": 1.0, "slot": -1, "bonus": {}},
	124: {"name": "Cristal de Mana", "weight": 0.8, "slot": -1, "bonus": {}},
	125: {"name": "Rubi de Fogo", "weight": 0.6, "slot": -1, "bonus": {}},
	126: {"name": "Safira Zero Absoluto", "weight": 0.6, "slot": -1, "bonus": {}},
	127: {"name": "Fragmento do Sol Negro", "weight": 1.2, "slot": -1, "bonus": {}},
	128: {"name": "Couro de Javali", "weight": 2.0, "slot": -1, "bonus": {}},
	129: {"name": "Couro de Lobo", "weight": 1.8, "slot": -1, "bonus": {}},
	130: {"name": "Pelos Espessos", "weight": 1.0, "slot": -1, "bonus": {}},
	131: {"name": "Linhas Grossas", "weight": 0.3, "slot": -1, "bonus": {}},
	132: {"name": "Teias de Aranha", "weight": 0.2, "slot": -1, "bonus": {}},
	133: {"name": "Seda de Arachna", "weight": 0.3, "slot": -1, "bonus": {}},
	134: {"name": "Sangue Fresco", "weight": 0.6, "slot": -1, "bonus": {}},
	135: {"name": "Sangue de Vampiro", "weight": 0.6, "slot": -1, "bonus": {}},
	136: {"name": "Sangue de Lobo", "weight": 0.6, "slot": -1, "bonus": {}},
	137: {"name": "Coração Pulsante", "weight": 0.8, "slot": -1, "bonus": {}},
	138: {"name": "Fígado Filtrante", "weight": 0.7, "slot": -1, "bonus": {}},
	139: {"name": "Intestinos e Tendões Elásticos", "weight": 0.8, "slot": -1, "bonus": {}},
	140: {"name": "Pulmões", "weight": 0.7, "slot": -1, "bonus": {}},
	141: {"name": "Olhos Multifacetados", "weight": 0.4, "slot": -1, "bonus": {}},
	142: {"name": "Presas e Garras Afiadas", "weight": 0.3, "slot": -1, "bonus": {}},
	143: {"name": "Bolsa de Veneno Vorpal", "weight": 0.5, "slot": -1, "bonus": {}},
	144: {"name": "Quitina de Escorpião", "weight": 2.5, "slot": -1, "bonus": {}},
	145: {"name": "Água Pura", "weight": 0.5, "slot": -1, "bonus": {}},
	146: {"name": "Água Tóxica dos Esgotos", "weight": 0.5, "slot": -1, "bonus": {}},
	147: {"name": "Orvalho Lunar", "weight": 0.4, "slot": -1, "bonus": {}},
	148: {"name": "Vinha Espinhosa", "weight": 0.6, "slot": -1, "bonus": {}},
	149: {"name": "Cipó-de-Aço", "weight": 1.2, "slot": -1, "bonus": {}},
	150: {"name": "Cogumelo Bioluminescente", "weight": 0.4, "slot": -1, "bonus": {}},
	151: {"name": "Fungo Devorador de Ferro", "weight": 0.5, "slot": -1, "bonus": {}},
	152: {"name": "Micélio Parasita", "weight": 0.4, "slot": -1, "bonus": {}},
	153: {"name": "Seiva Ácida", "weight": 0.5, "slot": -1, "bonus": {}},
	154: {"name": "Carvão", "weight": 1.0, "slot": -1, "bonus": {}},
	155: {"name": "Ervas Medicinais", "weight": 0.2, "slot": -1, "bonus": {}},
}

const RARITY_NAMES := ["", "Comum", "Incomum", "Raro", "Épico", "Único", "Exótico", "Lendário", "Mítico"]
const RARITY_COLORS := [Color("#9e9e9e"), Color("#bdbdbd"), Color("#81c784"), Color("#4fc3f7"), Color("#ba68c8"),
	Color("#ff8a65"), Color("#26c6da"), Color("#ffb300"), Color("#ff1744")]
const CATEGORY_NAMES := {"Madeira": "Madeira", "Pedra": "Pedra", "Metal": "Metal", "Cristal": "Cristal", "Liga": "Liga",
	"Pele_Fio": "Pele / Fio", "Orgao_Sangue": "Órgão / Sangue", "Planta_Liquido": "Planta / Líquido"}
const STARTING_DISCOVERED := [100, 108, 114, 116]

## Catálogo de Materiais (MaterialsDB) com propriedades de Forja e Ligas.
const MATERIALS := {
	100: {"name": "Pinho do Refúgio", "category": "Madeira", "rarity": 1, "durability": 40, "weight": 2.0, "resist": "Corte +5%", "trait": "Madeira macia e perfumada, fácil de trabalhar.", "thermal": 30, "electric": 5, "magic": 10},
	101: {"name": "Carvalho Cinzento", "category": "Madeira", "rarity": 2, "durability": 70, "weight": 3.0, "resist": "Impacto +15%", "trait": "Fibras densas que absorvem pancadas.", "thermal": 25, "electric": 5, "magic": 15},
	102: {"name": "Cedro da Tempestade", "category": "Madeira", "rarity": 3, "durability": 95, "weight": 2.8, "resist": "Raio +30%, Corte +10%", "trait": "Cresce onde os raios caem; guarda estática na seiva.", "thermal": 20, "electric": 70, "magic": 35},
	103: {"name": "Ébano Sussurrante", "category": "Madeira", "rarity": 4, "durability": 130, "weight": 3.2, "resist": "Sombra +35%, Mente +20%", "trait": "Sussurra segredos a quem o esculpe à noite.", "thermal": 15, "electric": 10, "magic": 75},
	104: {"name": "Salgueiro de Sangue", "category": "Madeira", "rarity": 5, "durability": 150, "weight": 2.6, "resist": "Necrose +40%", "trait": "A seiva vermelha regenera o cabo de armas que bebem sangue.", "thermal": 20, "electric": 15, "magic": 80},
	105: {"name": "Madeira-Ferro", "category": "Madeira", "rarity": 6, "durability": 220, "weight": 6.5, "resist": "Corte +45%, Impacto +35%", "trait": "Tão dura quanto aço, mas não enferruja.", "thermal": 35, "electric": 20, "magic": 20},
	106: {"name": "Freixo Solar", "category": "Madeira", "rarity": 7, "durability": 260, "weight": 2.4, "resist": "Fogo +60%, Trevas +40%", "trait": "Brilha ao amanhecer e queima criaturas da noite.", "thermal": 80, "electric": 30, "magic": 85},
	107: {"name": "Raiz de Yggdrasil", "category": "Madeira", "rarity": 8, "durability": 400, "weight": 3.0, "resist": "Todas +40%", "trait": "Fragmento da Árvore do Mundo; liga quaisquer outros materiais.", "thermal": 50, "electric": 50, "magic": 100},
	108: {"name": "Pedra Bruta", "category": "Pedra", "rarity": 1, "durability": 50, "weight": 4.0, "resist": "Impacto +5%", "trait": "Pedra comum, base de ferramentas simples.", "thermal": 20, "electric": 0, "magic": 5},
	109: {"name": "Calcário", "category": "Pedra", "rarity": 1, "durability": 45, "weight": 3.5, "resist": "Ácido -10%", "trait": "Pedra clara que vira cal e argamassa.", "thermal": 25, "electric": 0, "magic": 5},
	110: {"name": "Basalto", "category": "Pedra", "rarity": 3, "durability": 120, "weight": 5.0, "resist": "Fogo +30%, Impacto +20%", "trait": "Lava resfriada que suporta calor extremo.", "thermal": 60, "electric": 5, "magic": 15},
	111: {"name": "Obsidiana", "category": "Pedra", "rarity": 4, "durability": 90, "weight": 2.5, "resist": "Corte +50%", "trait": "Vidro vulcânico de gume perfeito, porém frágil.", "thermal": 40, "electric": 0, "magic": 45},
	112: {"name": "Pedra-Vazio", "category": "Pedra", "rarity": 6, "durability": 200, "weight": 4.5, "resist": "Magia +50%", "trait": "Absorve feitiços que a tocam.", "thermal": 5, "electric": 0, "magic": 5},
	113: {"name": "Rocha Estelar", "category": "Pedra", "rarity": 7, "durability": 280, "weight": 6.0, "resist": "Luz +60%, Gravidade", "trait": "Caiu do céu; é mais pesada do que parece.", "thermal": 45, "electric": 40, "magic": 90},
	114: {"name": "Cobre", "category": "Metal", "rarity": 1, "durability": 60, "weight": 4.5, "resist": "Raio +10%", "trait": "Excelente condutor; base do bronze.", "thermal": 85, "electric": 95, "magic": 30},
	115: {"name": "Estanho", "category": "Metal", "rarity": 1, "durability": 40, "weight": 4.0, "resist": "Ácido +10%", "trait": "Metal macio que endurece ligas.", "thermal": 60, "electric": 70, "magic": 20},
	116: {"name": "Ferro", "category": "Metal", "rarity": 1, "durability": 100, "weight": 5.5, "resist": "Corte +15%, Impacto +10%", "trait": "O metal de todo ferreiro; vira aço com carvão.", "thermal": 70, "electric": 60, "magic": 10},
	117: {"name": "Prata", "category": "Metal", "rarity": 3, "durability": 90, "weight": 5.0, "resist": "Trevas +40%, Mortos-vivos +50%", "trait": "Queima vampiros e lobisomens.", "thermal": 90, "electric": 90, "magic": 60},
	118: {"name": "Titânio", "category": "Metal", "rarity": 3, "durability": 180, "weight": 3.5, "resist": "Corte +25%, Ácido +30%", "trait": "Leve e quase indestrutível.", "thermal": 30, "electric": 20, "magic": 15},
	119: {"name": "Mithril Lunar", "category": "Metal", "rarity": 4, "durability": 220, "weight": 2.0, "resist": "Magia +45%, Corte +30%", "trait": "Brilha sob a lua e pesa como uma pena.", "thermal": 50, "electric": 60, "magic": 90},
	120: {"name": "Oricalco Rubro", "category": "Metal", "rarity": 5, "durability": 250, "weight": 4.0, "resist": "Fogo +55%, Sangue +30%", "trait": "Metal lendário dos reis antigos, quente ao toque.", "thermal": 95, "electric": 50, "magic": 70},
	121: {"name": "Tungstênio Abissal", "category": "Metal", "rarity": 6, "durability": 320, "weight": 9.0, "resist": "Impacto +60%, Fogo +40%", "trait": "Forjado na pressão das profundezas.", "thermal": 40, "electric": 30, "magic": 25},
	122: {"name": "Adamantino", "category": "Metal", "rarity": 7, "durability": 450, "weight": 7.0, "resist": "Todas físicas +60%", "trait": "Nada o arranha; nada o quebra.", "thermal": 35, "electric": 25, "magic": 40},
	123: {"name": "Quartzo", "category": "Cristal", "rarity": 1, "durability": 30, "weight": 1.0, "resist": "Magia +5%", "trait": "Cristal comum que vibra levemente com mana.", "thermal": 10, "electric": 30, "magic": 40},
	124: {"name": "Cristal de Mana", "category": "Cristal", "rarity": 3, "durability": 60, "weight": 0.8, "resist": "Magia +40%", "trait": "Reserva de mana pura em forma sólida.", "thermal": 10, "electric": 40, "magic": 95},
	125: {"name": "Rubi de Fogo", "category": "Cristal", "rarity": 4, "durability": 80, "weight": 0.6, "resist": "Fogo +60%", "trait": "Uma chama aprisionada dentro da pedra.", "thermal": 100, "electric": 20, "magic": 70},
	126: {"name": "Safira Zero Absoluto", "category": "Cristal", "rarity": 5, "durability": 90, "weight": 0.6, "resist": "Gelo +70%", "trait": "Congela o ar ao redor; nunca derrete.", "thermal": 0, "electric": 10, "magic": 80},
	127: {"name": "Fragmento do Sol Negro", "category": "Cristal", "rarity": 8, "durability": 300, "weight": 1.2, "resist": "Trevas +80%, Fogo +60%", "trait": "Pedaço do sol que morreu no primeiro Eclipse.", "thermal": 100, "electric": 80, "magic": 100},
	128: {"name": "Couro de Javali", "category": "Pele_Fio", "rarity": 1, "durability": 50, "weight": 2.0, "resist": "Corte +10%", "trait": "Couro grosso e resistente para armaduras leves.", "thermal": 20, "electric": 0, "magic": 5},
	129: {"name": "Couro de Lobo", "category": "Pele_Fio", "rarity": 1, "durability": 45, "weight": 1.8, "resist": "Frio +15%", "trait": "Couro cinzento e flexível que mantém o calor.", "thermal": 15, "electric": 0, "magic": 10},
	130: {"name": "Pelos Espessos", "category": "Pele_Fio", "rarity": 2, "durability": 30, "weight": 1.0, "resist": "Frio +30%", "trait": "Isolante perfeito para mantos de inverno.", "thermal": 5, "electric": 0, "magic": 10},
	131: {"name": "Linhas Grossas", "category": "Pele_Fio", "rarity": 1, "durability": 20, "weight": 0.3, "resist": "—", "trait": "Fios de tendão seco para costura.", "thermal": 10, "electric": 5, "magic": 10},
	132: {"name": "Teias de Aranha", "category": "Pele_Fio", "rarity": 2, "durability": 35, "weight": 0.2, "resist": "Corte +15%", "trait": "Pegajosa e surpreendentemente resistente.", "thermal": 5, "electric": 5, "magic": 30},
	133: {"name": "Seda de Arachna", "category": "Pele_Fio", "rarity": 4, "durability": 160, "weight": 0.3, "resist": "Corte +45%, Veneno +40%", "trait": "Seda da Rainha Tecelã; mais forte que aço.", "thermal": 10, "electric": 10, "magic": 70},
	134: {"name": "Sangue Fresco", "category": "Orgao_Sangue", "rarity": 1, "durability": 0, "weight": 0.6, "resist": "—", "trait": "Base de poções de vida e rituais simples.", "thermal": 40, "electric": 50, "magic": 30},
	135: {"name": "Sangue de Vampiro", "category": "Orgao_Sangue", "rarity": 4, "durability": 0, "weight": 0.6, "resist": "Necrose +40%", "trait": "Escuro e frio; concede roubo de vida às lâminas temperadas nele.", "thermal": 10, "electric": 30, "magic": 85},
	136: {"name": "Sangue de Lobo", "category": "Orgao_Sangue", "rarity": 2, "durability": 0, "weight": 0.6, "resist": "Fúria +20%", "trait": "Ferve sob a lua cheia.", "thermal": 60, "electric": 40, "magic": 45},
	137: {"name": "Coração Pulsante", "category": "Orgao_Sangue", "rarity": 3, "durability": 0, "weight": 0.8, "resist": "Vida +30%", "trait": "Continua batendo fora do corpo por dias.", "thermal": 50, "electric": 60, "magic": 70},
	138: {"name": "Fígado Filtrante", "category": "Orgao_Sangue", "rarity": 2, "durability": 0, "weight": 0.7, "resist": "Veneno +35%", "trait": "Purifica toxinas; base de antídotos.", "thermal": 30, "electric": 20, "magic": 40},
	139: {"name": "Intestinos e Tendões Elásticos", "category": "Orgao_Sangue", "rarity": 2, "durability": 60, "weight": 0.8, "resist": "Tração +30%", "trait": "Viram cordas de arco e molas de besta.", "thermal": 20, "electric": 10, "magic": 20},
	140: {"name": "Pulmões", "category": "Orgao_Sangue", "rarity": 2, "durability": 0, "weight": 0.7, "resist": "Vento +25%", "trait": "Guardam o fôlego da criatura; usados em foles mágicos.", "thermal": 25, "electric": 15, "magic": 45},
	141: {"name": "Olhos Multifacetados", "category": "Orgao_Sangue", "rarity": 3, "durability": 0, "weight": 0.4, "resist": "Precisão +30%", "trait": "Lentes naturais para lunetas e amuletos de visão.", "thermal": 10, "electric": 25, "magic": 75},
	142: {"name": "Presas e Garras Afiadas", "category": "Orgao_Sangue", "rarity": 1, "durability": 40, "weight": 0.3, "resist": "Perfuração +20%", "trait": "Pontas de flecha e serrilhados de lâmina.", "thermal": 15, "electric": 5, "magic": 15},
	143: {"name": "Bolsa de Veneno Vorpal", "category": "Orgao_Sangue", "rarity": 4, "durability": 0, "weight": 0.5, "resist": "Veneno +60%", "trait": "Uma gota derruba um touro. Corte com MUITO cuidado.", "thermal": 20, "electric": 30, "magic": 60},
	144: {"name": "Quitina de Escorpião", "category": "Pele_Fio", "rarity": 5, "durability": 200, "weight": 2.5, "resist": "Corte +40%, Veneno +50%", "trait": "Carapaça abissal leve e quase impenetrável.", "thermal": 15, "electric": 5, "magic": 35},
	145: {"name": "Água Pura", "category": "Planta_Liquido", "rarity": 1, "durability": 0, "weight": 0.5, "resist": "—", "trait": "Base de toda poção e da têmpera do aço.", "thermal": 60, "electric": 40, "magic": 30},
	146: {"name": "Água Tóxica dos Esgotos", "category": "Planta_Liquido", "rarity": 2, "durability": 0, "weight": 0.5, "resist": "Veneno +25%", "trait": "Verde e borbulhante; corrói o que toca.", "thermal": 50, "electric": 50, "magic": 25},
	147: {"name": "Orvalho Lunar", "category": "Planta_Liquido", "rarity": 3, "durability": 0, "weight": 0.4, "resist": "Magia +35%", "trait": "Só se forma em noites de lua cheia.", "thermal": 20, "electric": 30, "magic": 90},
	148: {"name": "Vinha Espinhosa", "category": "Planta_Liquido", "rarity": 1, "durability": 25, "weight": 0.6, "resist": "Sangramento +15%", "trait": "Cordas espinhosas para armadilhas.", "thermal": 15, "electric": 5, "magic": 20},
	149: {"name": "Cipó-de-Aço", "category": "Planta_Liquido", "rarity": 3, "durability": 120, "weight": 1.2, "resist": "Tração +40%", "trait": "Cipó metálico que não arrebenta.", "thermal": 40, "electric": 45, "magic": 20},
	150: {"name": "Cogumelo Bioluminescente", "category": "Planta_Liquido", "rarity": 2, "durability": 0, "weight": 0.4, "resist": "Luz +20%", "trait": "Ilumina cavernas e alquimias noturnas.", "thermal": 10, "electric": 20, "magic": 55},
	151: {"name": "Fungo Devorador de Ferro", "category": "Planta_Liquido", "rarity": 4, "durability": 0, "weight": 0.5, "resist": "Corrosão +50%", "trait": "Come metal; usado para gravar runas em armas.", "thermal": 30, "electric": 40, "magic": 50},
	152: {"name": "Micélio Parasita", "category": "Planta_Liquido", "rarity": 5, "durability": 0, "weight": 0.4, "resist": "Necrose +45%", "trait": "Fios vivos que se espalham por qualquer ferida.", "thermal": 20, "electric": 20, "magic": 80},
	153: {"name": "Seiva Ácida", "category": "Planta_Liquido", "rarity": 3, "durability": 0, "weight": 0.5, "resist": "Ácido +45%", "trait": "Brota de fendas ácidas da Fronteira das Cinzas.", "thermal": 45, "electric": 55, "magic": 35},
	154: {"name": "Carvão", "category": "Pedra", "rarity": 1, "durability": 10, "weight": 1.0, "resist": "Fogo +10%", "trait": "Combustível da forja; queima mais quente que a madeira.", "thermal": 90, "electric": 30, "magic": 5},
	155: {"name": "Ervas Medicinais", "category": "Planta_Liquido", "rarity": 1, "durability": 0, "weight": 0.2, "resist": "Cura +15%", "trait": "Folhas amargas que fecham feridas; base das poções de Lyra.", "thermal": 10, "electric": 5, "magic": 35},
}

static func is_material(item_id: int) -> bool:
	return MATERIALS.has(item_id)

static func material(item_id: int) -> Dictionary:
	return MATERIALS.get(item_id, {})

static func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, 8)]

static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 8)]

static func info(item_id: int) -> Dictionary:
	return ITEMS.get(item_id, {"name": "Item #%d" % item_id, "weight": 0.5, "slot": -1, "bonus": {}})

static func weight(item_id: int) -> float:
	return float(info(item_id).get("weight", 0.5))

static func slot_of(item_id: int) -> int:
	return int(info(item_id).get("slot", -1))

static func bonus(item_id: int) -> Dictionary:
	return info(item_id).get("bonus", {})

## Nome do aspecto que a Qualidade mede em cada tipo de item.
static func quality_aspect(item_id: int) -> String:
	if MATERIALS.has(item_id):
		match String(MATERIALS[item_id]["category"]):
			"Orgao_Sangue":
				return "Frescor"
			"Pele_Fio":
				return "Integridade"
			"Madeira":
				return "Veio"
			"Metal", "Liga", "Pedra", "Cristal":
				return "Pureza"
			"Planta_Liquido":
				return "Potência"
	if int(info(item_id).get("slot", -1)) >= 0 or info(item_id).has("tool"):
		return "Condição"
	return "Qualidade"

## Lixo gerado quando a Qualidade fica abaixo do limite: Sucata para metais/pedras/cristais, Lixo Orgânico no resto.
static func junk_name(item_id: int) -> String:
	if MATERIALS.has(item_id) and ["Metal", "Liga", "Pedra", "Cristal"].has(String(MATERIALS[item_id]["category"])):
		return "Sucata Metálica"
	return "Lixo Orgânico"

## Raridade: a do catálogo para materiais; para equipamentos, estimada pela soma dos bônus.
static func rarity(item_id: int) -> Array:
	if MATERIALS.has(item_id):
		var r: int = int(MATERIALS[item_id]["rarity"])
		return [rarity_name(r), rarity_color(r)]
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
