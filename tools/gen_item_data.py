"""Gera client/scripts/ItemData.gd a partir do catálogo do servidor (server/internal/world/items.go).

Uso: python3 tools/gen_item_data.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
go = (ROOT / "server/internal/world/items.go").read_text()
pk = (ROOT / "server/internal/protocol/packets.go").read_text()
ids = {m.group(1): int(m.group(2)) for m in re.finditer(r"\t(Item[A-Za-z]+)\s+uint8 = (\d+)", pk)}
slots = {m.group(1): int(m.group(2)) for m in re.finditer(r"\t(Slot[A-Za-z0-9]+)\s+uint8 = (\d+)", pk)}
keymap = {"BonusSTR": "str", "BonusDEX": "dex", "BonusCON": "con", "BonusAGI": "agi", "BonusINT": "int",
          "BonusESP": "spi", "BonusMAS": "mas", "BonusLCK": "lck", "BonusHP": "hp", "BonusDEF": "def",
          "BonusMDEF": "mdef", "BonusATK": "atk"}
rows = []
for m in re.finditer(r"protocol\.(Item\w+):\s*\{([^}]*)\}", go):
    body = m.group(2)
    name = re.search(r'Name:\s*"([^"]*)"', body).group(1)
    weight = float(re.search(r"Weight:\s*([\d.]+)", body).group(1))
    sm = re.search(r"Slot:\s*(protocol\.(\w+)|NoSlot)", body)
    slot = -1 if sm.group(1) == "NoSlot" else slots[sm.group(2)]
    bonus = ", ".join('"%s": %s' % (keymap[k], v) for k, v in re.findall(r"(Bonus\w+):\s*(\d+)", body))
    rows.append('\t%d: {"name": "%s", "weight": %s, "slot": %d, "bonus": {%s}},' % (ids[m.group(1)], name, weight, slot, bonus))

# Ferramentas (tools.go): constantes ItemX uint8 = N e entradas ItemX: {Name: ...}
tools_go = (ROOT / "server/internal/world/tools.go").read_text()
tool_ids = {m.group(1): int(m.group(2)) for m in re.finditer(r"\t(Item\w+)\s+uint8 = (\d+)", tools_go)}
tool_tiers = {m.group(1): (m.group(2), int(m.group(3))) for m in re.finditer(r"(Item\w+): \{(Tool\w+), (\d+)\}", tools_go)}
for m in re.finditer(r"\t(Item\w+):\s*\{Name: \"([^\"]*)\", Weight: ([\d.]+)", tools_go):
    kind, tier = tool_tiers.get(m.group(1), ("ToolNone", 0))
    rows.append('\t%d: {"name": "%s", "weight": %s, "slot": -1, "bonus": {}, "tool": "%s", "tool_tier": %d},' % (
        tool_ids[m.group(1)], m.group(2), float(m.group(3)), kind.replace("Tool", "").lower(), tier))

# Materiais (materials.go)
mat_go = (ROOT / "server/internal/world/materials.go").read_text()
mat_ids = {m.group(1): int(m.group(2)) for m in re.finditer(r"\t(Mat\w+)\s+uint16 = (\d+)", mat_go)}
cat_names = {m.group(1): m.group(2) for m in re.finditer(r"\t(Mat\w+)\s+= \"(\w+)\"", mat_go)}
rar = {m.group(1): int(m.group(2)) for m in re.finditer(r"\t(Rarity\w+)\s+uint8 = (\d+)", mat_go)}
mat_rows = []
entry = re.compile(r'\t(Mat\w+):\s*\{Mat\w+, "([^"]*)", (Mat\w+), (Rarity\w+), (-?\d+), ([\d.]+), "([^"]*)", "([^"]*)", (\d+), (\d+), (\d+)\}')
for m in entry.finditer(mat_go):
    mid = mat_ids[m.group(1)]
    mat_rows.append('\t%d: {"name": "%s", "category": "%s", "rarity": %d, "durability": %s, "weight": %s, "resist": "%s", "trait": "%s", "thermal": %s, "electric": %s, "magic": %s},' % (
        mid, m.group(2), cat_names[m.group(3)], rar[m.group(4)], m.group(5), float(m.group(6)), m.group(7), m.group(8), m.group(9), m.group(10), m.group(11)))
    rows.append('\t%d: {"name": "%s", "weight": %s, "slot": -1, "bonus": {}},' % (mid, m.group(2), float(m.group(6))))
# Blueprints Antigas (forge.go, via tools/world_dump.json)
import json
dump = json.loads((ROOT / "tools/world_dump.json").read_text())
for bp in dump["forge"]["blueprints"]:
    if bp.get("scroll"):
        rows.append('\t%d: {"name": "Blueprint Antiga: %s", "weight": 0.2, "slot": -1, "bonus": {}, "blueprint": %d},' % (bp["scroll"], bp["name"], bp["id"]))
starting = [mat_ids[n] for n in re.search(r"StartingDiscoveredMaterials = \[\]uint16\{([^}]*)\}", mat_go).group(1).replace(" ", "").split(",")]

out = '''extends RefCounted
## Dados de itens compartilhados entre Inventário e Status.
## GERADO por tools/gen_item_data.py a partir de server/internal/world/items.go — não edite à mão.
## weight = kg por unidade | slot = 0..14 (-1 = não equipável) | bonus = atributos concedidos.

const SLOT_COUNT := 15
const RING_SLOTS := [8, 9, 10, 11]

const ITEMS := {
%s
}

const RARITY_NAMES := ["", "Comum", "Incomum", "Raro", "Épico", "Único", "Exótico", "Lendário", "Mítico"]
const RARITY_COLORS := [Color("#9e9e9e"), Color("#bdbdbd"), Color("#81c784"), Color("#4fc3f7"), Color("#ba68c8"),
	Color("#ff8a65"), Color("#26c6da"), Color("#ffb300"), Color("#ff1744")]
const CATEGORY_NAMES := {"Madeira": "Madeira", "Pedra": "Pedra", "Metal": "Metal", "Cristal": "Cristal", "Liga": "Liga",
	"Pele_Fio": "Pele / Fio", "Orgao_Sangue": "Órgão / Sangue", "Planta_Liquido": "Planta / Líquido", "Osso": "Osso"}
const STARTING_DISCOVERED := %s

## Catálogo de Materiais (MaterialsDB) com propriedades de Forja e Ligas.
const MATERIALS := {
%s
}

## Peças únicas do jogador (ligas sintéticas e equipamentos forjados, IDs 200-254): preenchido
## pelo pacote 0x54 (FORGE_STATE). Têm prioridade sobre o catálogo fixo.
static var FORGED := {}

static func is_material(item_id: int) -> bool:
	return MATERIALS.has(item_id) or (FORGED.has(item_id) and int(FORGED[item_id]["kind"]) == 1)

static func material(item_id: int) -> Dictionary:
	if FORGED.has(item_id) and int(FORGED[item_id]["kind"]) == 1:
		return FORGED[item_id]["material"]
	return MATERIALS.get(item_id, {})

static func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, 8)]

static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 8)]

static func info(item_id: int) -> Dictionary:
	if FORGED.has(item_id):
		return FORGED[item_id]["info"]
	return ITEMS.get(item_id, {"name": "Item #%%d" %% item_id, "weight": 0.5, "slot": -1, "bonus": {}})

static func weight(item_id: int) -> float:
	return float(info(item_id).get("weight", 0.5))

static func slot_of(item_id: int) -> int:
	return int(info(item_id).get("slot", -1))

static func bonus(item_id: int) -> Dictionary:
	return info(item_id).get("bonus", {})

## Nome do aspecto que a Qualidade mede em cada tipo de item.
static func quality_aspect(item_id: int) -> String:
	if is_material(item_id):
		match String(material(item_id)["category"]):
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
	if is_material(item_id):
		var r: int = int(material(item_id)["rarity"])
		return [rarity_name(r), rarity_color(r)]
	if FORGED.has(item_id):
		var fr: int = int(FORGED[item_id]["rarity"])
		return [rarity_name(fr), rarity_color(fr)]
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
''' % ("\n".join(rows), str(starting), "\n".join(mat_rows))
(ROOT / "client/scripts/ItemData.gd").write_text(out)
print("ItemData.gd: %d itens, %d materiais" % (len(rows), len(mat_rows)))
