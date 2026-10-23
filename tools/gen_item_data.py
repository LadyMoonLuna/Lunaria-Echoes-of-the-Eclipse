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

out = '''extends RefCounted
## Dados de itens compartilhados entre Inventário e Status.
## GERADO por tools/gen_item_data.py a partir de server/internal/world/items.go — não edite à mão.
## weight = kg por unidade | slot = 0..13 (-1 = não equipável) | bonus = atributos concedidos.

const SLOT_COUNT := 14
const RING_SLOTS := [8, 9, 10, 11]

const ITEMS := {
%s
}

static func info(item_id: int) -> Dictionary:
	return ITEMS.get(item_id, {"name": "Item #%%d" %% item_id, "weight": 0.5, "slot": -1, "bonus": {}})

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
''' % "\n".join(rows)
(ROOT / "client/scripts/ItemData.gd").write_text(out)
print("ItemData.gd: %d itens" % len(rows))
