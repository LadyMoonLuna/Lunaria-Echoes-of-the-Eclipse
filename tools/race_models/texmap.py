"""Escolhe a textura de cada material pelo nome (com exceções explícitas).

Materiais de efeito (brilho forte, sem sombreamento ou quase invisíveis) ficam lisos:
olhos luminosos, runas, fogo, magia e partículas não recebem textura.
"""

# (palavras-chave, textura) — a primeira regra que casar vence
RULES = [
    (("chainmail", "mail"), "chainmail"),
    (("feather",), "feather"),
    (("scale",), "scales"),
    (("bark",), "bark"),
    (("moss",), "moss"),
    (("leaf", "herb"), "leaf"),
    (("cap_", "gill", "mycel", "flesh_dark", "fung"), "fungal"),
    (("fur", "beard", "muzzle"), "fur"),
    (("hair", "lavender"), "hair"),
    (("marble",), "marble"),
    (("obsidian", "chitin", "void"), "obsidian"),
    (("coral",), "bone"),
    (("mud",), "ground"),
    (("coin",), "metal_hammered"),
    (("crystal", "glass", "lens", "pearl", "tank_glass"), "crystal"),
    (("basalt", "rock", "stone", "censer"), "stone"),
    (("bone", "skull", "claw", "fang", "nail", "horn", "beak", "rib"), "bone"),
    (("steel_boots",), "metal_hammered"),
    (("leather", "boots", "glove", "belt", "strap", "apron", "bandolier", "grip", "wrap", "pouch",
      "suede", "kilt", "steel_toe", "hilt", "cork"), "leather"),
    (("linen", "rope", "cord", "rag", "page", "pants", "padded", "string"), "linen"),
    (("gold", "brass", "bronze", "silver", "rivet", "ring", "chain", "band", "guard", "ridge", "emblem",
      "rim", "buckle", "metal"), "metal_brushed"),
    (("robe", "cloth", "tunic", "cape", "cloak", "mantle", "coat", "tabard", "stole", "silk", "mask",
      "velvet", "sash", "gambeson", "navy", "royal", "crimson", "embroidery", "hood", "rags",
      "grimoire", "recipe_book", "book", "forest_green", "night_robe", "cleric"), "cloth"),
    (("wood", "shaft", "haft", "handle", "ash_handle", "bow_wood", "branch"), "wood"),
    (("steel", "iron", "plate", "armor", "blade", "bore", "arrowhead", "lantern"), "metal_hammered"),
    (("skin", "flesh", "porcelain", "dry_skin", "scar", "stitch", "soot", "mutant"), "skin"),
]

# Exceções por (uid do modelo, material)
OVERRIDES = {
    ("race_8", "marble"): "marble",
    ("race_10", "aged_bronze"): "metal_hammered",
    ("race_9", "void_matte"): "obsidian",
    ("race_22", "belly"): "scales",
    ("race_25", "belly"): "scales",
    ("race_25", "fin"): None,
    ("race_19", "sap"): None,
    ("race_23", "fur"): "fur",
    ("race_20", "flesh"): "fungal",
    ("race_20", "mantle"): "fungal",
    ("race_21", "silk_black"): "cloth",
    ("npc_100", "bison_apron"): "leather",
    ("npc_100", "dark_linen"): "linen",
    ("npc_105", "polished_steel"): "metal_brushed",
}

# Tamanho do ladrilho em metros (quanto da superfície uma repetição cobre)
TILE_METERS = {
    "chainmail": 0.22, "cloth": 0.35, "linen": 0.35, "leather": 0.45, "scales": 0.35, "feather": 0.3,
    "skin": 0.5, "fur": 0.4, "hair": 0.35, "bone": 0.3, "metal_brushed": 0.5, "metal_hammered": 0.5,
    "wood": 0.6, "planks": 1.2, "bark": 0.6, "stone": 0.9, "cobblestone": 1.8, "stone_blocks": 2.4,
    "roof_tiles": 1.6, "marble": 0.8, "crystal": 0.4, "obsidian": 0.5, "fungal": 0.4, "moss": 0.4,
    "leaf": 0.25, "plaster": 1.5, "ground": 3.0,
}


def texture_for(uid, name, spec):
    if (uid, name) in OVERRIDES:
        return OVERRIDES[(uid, name)]
    if spec.get("unshaded"):
        return None
    if spec.get("emit") and spec.get("energy", 1.0) >= 1.5:
        return None
    if spec.get("alpha", 1.0) < 0.6:
        return None
    low = name.lower()
    for keys, tex in RULES:
        if any(k in low for k in keys):
            return tex
    return None


def assign(models):
    """Adiciona 'tex' e 'tile' aos materiais. Retorna a lista de materiais que ficaram lisos."""
    plain = []
    for m in models:
        for name, spec in m["materials"].items():
            tex = texture_for(m["uid"], name, spec)
            if tex:
                spec["tex"] = tex
                spec["tile"] = TILE_METERS[tex]
            else:
                plain.append((m["uid"], name))
    return plain
