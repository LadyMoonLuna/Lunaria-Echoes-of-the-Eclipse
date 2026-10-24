extends CanvasLayer
## Forja do Garrick — Etapa 2: [🔥 Criar Ligas] (cadinho com até 4 ingredientes) e
## [📜 Forjar por Blueprint] (o material de cada peça é escolhido). Os cálculos do preview usam as
## mesmas regras do servidor (server/internal/world/forge.go, dados em ForgeData.gd).

const LunariaUI = preload("res://scripts/ui/LunariaUI.gd")
const ItemData = preload("res://scripts/ItemData.gd")
const ForgeData = preload("res://scripts/forge/ForgeData.gd")

const SLOT_LABELS := {0: "Elmo", 1: "Peitoral", 4: "Luvas", 12: "Mão Principal", 13: "Mão Secundária"}
const TOOL_LABELS := {1: "Machado", 2: "Picareta", 3: "Tesoura"}

var is_open := false
var tabs: TabContainer
# Cadinho
var crucible: Array = [] # OptionButtons
var alloy_preview: RichTextLabel
# Blueprints
var bp_list: ItemList
var bp_title: Label
var parts_box: VBoxContainer
var part_pickers: Array = [] # OptionButtons (metadata = item id; 0 = vazio)
var bp_preview: RichTextLabel
var forge_btn: Button
var buy_btn: Button
var current_bp: Dictionary = {}

func _ready() -> void:
	layer = 24
	visible = false
	_build_ui()
	LunariaUI.watch(self) # mesmo estilo do inventário
	NetworkManager.forge_state_received.connect(func(_bps: Array): _refresh.call_deferred())
	NetworkManager.inventory_updated.connect(func(_slots: Array, _items: Array): _refresh.call_deferred())

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
	NetworkManager.send_forge_action(0) # pede blueprints e peças únicas atualizadas
	_refresh()

func close_menu() -> void:
	is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", false)

# ---------------------------------------------------------------------------
# Dados do jogador
# ---------------------------------------------------------------------------

## Quantidade de cada item na mochila.
func _bag() -> Dictionary:
	var counts := {}
	var world := get_parent()
	if world and world.get("inventory_ui"):
		for it in world.inventory_ui.inventory_items:
			counts[int(it["id"])] = int(counts.get(int(it["id"]), 0)) + int(it["quantity"])
	return counts

## Materiais conhecidos: descobertos no servidor + ligas sintéticas do próprio jogador.
func _known(mid: int) -> bool:
	var world := get_parent()
	if ItemData.FORGED.has(mid) and int(ItemData.FORGED[mid]["kind"]) == 1:
		return true
	return world != null and world.get("discovered_materials") != null and world.discovered_materials.has(mid)

func _tags(mid: int) -> Array:
	if ForgeData.TAGS.has(mid):
		return ForgeData.TAGS[mid]
	if ItemData.FORGED.has(mid) and int(ItemData.FORGED[mid]["kind"]) == 1:
		var t := ["metal"]
		if float(ItemData.FORGED[mid]["weight"]) <= 4.5:
			t.append("metal_leve")
		return t
	return []

func _accepts(part: Dictionary, mid: int) -> bool:
	for t in _tags(mid):
		if part["tags"].has(t):
			return true
	return false

# ---------------------------------------------------------------------------
# Interface
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.02, 0.03, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(980, 600)
	center.add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "🔨  Forja do Garrick — Bigorna e Fornalha"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.pressed.connect(close_menu)
	header.add_child(close_btn)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_build_alloy_tab())
	tabs.add_child(_build_blueprint_tab())

func _label(text: String, size: int = 13, col: Color = Color(0.92, 0.88, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _build_alloy_tab() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "🔥 Criar Ligas (Bio-Metalurgia)"
	tab.add_theme_constant_override("separation", 14)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 8)
	tab.add_child(left)
	left.add_child(_label("⚗️ Cadinho — até 4 ingredientes: metais, sangues, venenos, ácidos, cristais, fungos e órgãos.", 13, Color(1.0, 0.85, 0.5)))
	for k in range(4):
		var row := HBoxContainer.new()
		left.add_child(row)
		var ing_lbl := _label("Ingrediente %d" % (k + 1), 12)
		ing_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		ing_lbl.custom_minimum_size = Vector2(96, 0)
		row.add_child(ing_lbl)
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ob.item_selected.connect(func(_idx: int): _update_alloy_preview())
		row.add_child(ob)
		crucible.append(ob)
	var smelt := Button.new()
	smelt.text = "🔥 Fundir no Cadinho"
	smelt.custom_minimum_size = Vector2(0, 40)
	smelt.pressed.connect(_on_smelt)
	left.add_child(smelt)
	var recipes := RichTextLabel.new()
	recipes.bbcode_enabled = true
	recipes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipes.text = _recipe_book()
	left.add_child(recipes)
	alloy_preview = RichTextLabel.new()
	alloy_preview.bbcode_enabled = true
	alloy_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alloy_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(alloy_preview)
	return tab

func _recipe_book() -> String:
	var lines := ["[color=#ffd54f]📖 Receitas conhecidas da Fornalha[/color] (fora delas, o cadinho cria uma Liga Sintética)"]
	for r in ForgeData.RECIPES:
		var parts: Array = []
		for g in r["groups"]:
			var names: Array = []
			for mid in g:
				names.append(String(ItemData.material(int(mid)).get("name", "?")))
			parts.append(" / ".join(names))
		var out: Dictionary = ItemData.material(int(r["output"]))
		lines.append("• %s → [color=%s]%dx %s[/color]" % [" + ".join(parts), ItemData.rarity_color(int(out["rarity"])).to_html(false), int(r["qty"]), out["name"]])
	return "\n".join(lines)

func _build_blueprint_tab() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "📜 Forjar por Blueprint (Por Partes)"
	tab.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	tab.add_child(left)
	left.add_child(_label("Blueprints", 14, Color(1.0, 0.85, 0.5)))
	bp_list = ItemList.new()
	bp_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bp_list.item_selected.connect(_on_bp_selected)
	left.add_child(bp_list)
	buy_btn = Button.new()
	buy_btn.visible = false
	buy_btn.pressed.connect(_on_buy)
	left.add_child(buy_btn)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(380, 0)
	mid.add_theme_constant_override("separation", 6)
	tab.add_child(mid)
	bp_title = _label("Escolha uma blueprint", 15, Color(1.0, 0.9, 0.6))
	mid.add_child(bp_title)
	mid.add_child(_label("Só aparecem materiais que você já descobriu. (x0) = conhecido, mas não está na mochila.", 11, Color(0.75, 0.72, 0.65)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(scroll)
	parts_box = VBoxContainer.new()
	parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(parts_box)
	forge_btn = Button.new()
	forge_btn.text = "🔨 Forjar Equipamento"
	forge_btn.custom_minimum_size = Vector2(0, 42)
	forge_btn.pressed.connect(_on_forge)
	mid.add_child(forge_btn)
	bp_preview = RichTextLabel.new()
	bp_preview.bbcode_enabled = true
	bp_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(bp_preview)
	return tab

# ---------------------------------------------------------------------------
# Atualização
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if not is_open:
		return
	_fill_crucible()
	_fill_blueprints()
	_update_alloy_preview()
	_update_bp_preview()

func _fill_crucible() -> void:
	var bag := _bag()
	for ob in crucible:
		var keep_meta = ob.get_selected_metadata() if ob.selected >= 0 else null
		var keep: int = int(keep_meta) if keep_meta != null else 0
		ob.clear()
		ob.add_item("— vazio —")
		ob.set_item_metadata(0, 0)
		var ids: Array = bag.keys()
		ids.sort()
		for mid in ids:
			if not ItemData.is_material(mid):
				continue
			ob.add_item("%s (x%d)" % [ItemData.material(mid)["name"], int(bag[mid])])
			ob.set_item_metadata(ob.item_count - 1, mid)
			if mid == keep:
				ob.select(ob.item_count - 1)

func _crucible_ids() -> Array:
	var ids: Array = []
	for ob in crucible:
		var m = ob.get_selected_metadata() if ob.selected >= 0 else 0
		if m != null and int(m) > 0:
			ids.append(int(m))
	return ids

## Receita fixa que casa com os ingredientes (mesma busca do servidor).
func _match_recipe(ids: Array) -> Dictionary:
	for r in ForgeData.RECIPES:
		if r["groups"].size() == ids.size() and _assign(r["groups"], ids, [], 0):
			return r
	return {}

func _assign(groups: Array, ids: Array, used: Array, gi: int) -> bool:
	if gi == groups.size():
		return true
	for i in range(ids.size()):
		if used.has(i) or not groups[gi].has(ids[i]):
			continue
		if _assign(groups, ids, used + [i], gi + 1):
			return true
	return false

func _update_alloy_preview() -> void:
	var ids := _crucible_ids()
	if ids.size() < 2:
		alloy_preview.text = "[color=#ffd54f]Resultado[/color]\nColoque de 2 a 4 ingredientes no cadinho."
		return
	var bag := _bag()
	var need := {}
	for mid in ids:
		need[mid] = int(need.get(mid, 0)) + 1
	var missing := ""
	for mid in need:
		if int(bag.get(mid, 0)) < int(need[mid]):
			missing = "\n[color=#ef5350]Faltam unidades de %s na mochila.[/color]" % ItemData.material(mid)["name"]
	var r := _match_recipe(ids)
	if not r.is_empty():
		var m: Dictionary = ItemData.material(int(r["output"]))
		alloy_preview.text = "[color=#73e673]✔ Receita conhecida![/color]\n" + _material_card(m, int(r["qty"]), int(r["output"])) + missing
		return
	var base := false
	var mats: Array = []
	for mid in ids:
		var m2: Dictionary = ItemData.material(mid)
		mats.append(m2)
		if ["Metal", "Liga", "Cristal", "Pedra"].has(String(m2["category"])):
			base = true
	if not base:
		alloy_preview.text = "[color=#ef5350]A mistura precisa de uma base mineral (metal, liga, pedra ou cristal).[/color]"
		return
	alloy_preview.text = "[color=#4fc3f7]⚗️ Fusão livre — Liga Sintética Customizada[/color]\n" + _material_card(_synthetic(mats), 1, 0) + missing

## Mesma soma do servidor (SyntheticAlloy).
func _synthetic(mats: Array) -> Dictionary:
	var out := {"durability": 0, "weight": 0.0, "thermal": 0, "electric": 0, "magic": 0, "rarity": 0, "category": "Liga"}
	var base_name := ""
	var res: Array = []
	var names: Array = []
	for m in mats:
		out["durability"] += int(m["durability"])
		out["weight"] += float(m["weight"])
		out["thermal"] += int(m["thermal"])
		out["electric"] += int(m["electric"])
		out["magic"] += int(m["magic"])
		out["rarity"] = maxi(int(out["rarity"]), int(m["rarity"]))
		if base_name == "" and ["Metal", "Liga"].has(String(m["category"])):
			base_name = String(m["name"])
		for rr in String(m["resist"]).split(", "):
			if rr != "" and rr != "—" and not res.has(rr):
				res.append(rr)
		names.append(m["name"])
	if base_name == "":
		base_name = String(mats[0]["name"])
	var n := mats.size()
	out["durability"] = maxi(20, int(float(out["durability"]) * 0.75))
	out["weight"] = snappedf(float(out["weight"]) / n, 0.1)
	for k in ["thermal", "electric", "magic"]:
		out[k] = mini(100, int(out[k]) / n + 10)
	out["resist"] = ", ".join(res) if not res.is_empty() else "—"
	out["name"] = "Liga de %s%s" % [base_name.trim_prefix("Liga de "), " Composta" if n > 2 else ""]
	out["trait"] = "Liga sintética: %s." % " + ".join(names)
	return out

func _material_card(m: Dictionary, qty: int, mid: int) -> String:
	var lines := ["[color=%s][b]%dx %s[/b][/color]  (%s)" % [ItemData.rarity_color(int(m["rarity"])).to_html(false), qty, m["name"], ItemData.rarity_name(int(m["rarity"]))]]
	lines.append("Durabilidade: %d   •   Peso: %.1f kg" % [int(m["durability"]), float(m["weight"])])
	lines.append("Condutividade — Térmica %d%% • Elétrica %d%% • Mágica %d%%" % [int(m["thermal"]), int(m["electric"]), int(m["magic"])])
	lines.append("Resistências: [color=#73e673]%s[/color]" % m["resist"])
	if ForgeData.SPECIALS.has(mid):
		lines.append("Característica: [color=#ffb74d]%s[/color]" % ForgeData.SPECIALS[mid])
	lines.append("[i]%s[/i]" % m["trait"])
	return "\n".join(lines)

func _on_smelt() -> void:
	var ids := _crucible_ids()
	if ids.size() >= 2:
		NetworkManager.send_forge_alloy(ids)

# --- Blueprints ---

func _fill_blueprints() -> void:
	var keep: int = int(current_bp.get("id", 0))
	bp_list.clear()
	for bp in ForgeData.BLUEPRINTS:
		var known: bool = NetworkManager.known_blueprints.has(int(bp["id"]))
		var label := ("📜 " if known else "🔒 ") + String(bp["name"])
		if not known and int(bp["price"]) > 0:
			label += "  (Garrick: %d 🪙)" % int(bp["price"])
		elif not known:
			label += "  (Blueprint Antiga)"
		bp_list.add_item(label)
		bp_list.set_item_metadata(bp_list.item_count - 1, int(bp["id"]))
		if not known:
			bp_list.set_item_custom_fg_color(bp_list.item_count - 1, Color(0.6, 0.56, 0.5))
		if int(bp["id"]) == keep:
			bp_list.select(bp_list.item_count - 1)
	if keep > 0:
		_show_blueprint(keep, true)

func _on_bp_selected(idx: int) -> void:
	var meta = bp_list.get_item_metadata(idx)
	if meta != null:
		_show_blueprint(int(meta), false)

func _show_blueprint(bp_id: int, keep_picks: bool) -> void:
	var old_picks := _picks() if keep_picks else []
	for bp in ForgeData.BLUEPRINTS:
		if int(bp["id"]) == bp_id:
			current_bp = bp
	var known: bool = NetworkManager.known_blueprints.has(bp_id)
	var kind_txt := ""
	if int(current_bp["tool"]) > 0:
		kind_txt = "Ferramenta (%s)" % TOOL_LABELS.get(int(current_bp["tool"]), "")
	else:
		kind_txt = SLOT_LABELS.get(int(current_bp["slot"]), "Equipamento")
	bp_title.text = "%s — %s" % [current_bp["name"], kind_txt]
	buy_btn.visible = not known and int(current_bp["price"]) > 0
	buy_btn.text = "🪙 Comprar com o Garrick (%d Sollares)" % int(current_bp["price"])
	forge_btn.disabled = not known
	for c in parts_box.get_children():
		c.queue_free()
	part_pickers.clear()
	var bag := _bag()
	var pi := 0
	for part in current_bp["parts"]:
		var box := VBoxContainer.new()
		parts_box.add_child(box)
		var tag_names: Array = []
		for t in part["tags"]:
			tag_names.append(ForgeData.TAG_NAMES.get(t, t))
		box.add_child(_label("%d. %s%s  — aceita: %s" % [pi + 1, part["name"], " (opcional)" if part["optional"] else "", ", ".join(tag_names)], 12, Color(1.0, 0.9, 0.65)))
		var ob := OptionButton.new()
		ob.add_item("— vazio —" if part["optional"] else "— escolha o material —")
		ob.set_item_metadata(0, 0)
		var cands: Array = []
		for mid in ItemData.MATERIALS.keys() + ItemData.FORGED.keys():
			if _known(int(mid)) and _accepts(part, int(mid)) and not cands.has(int(mid)):
				cands.append(int(mid))
		cands.sort_custom(func(a: int, b: int): return int(bag.get(a, 0)) > int(bag.get(b, 0)) or (int(bag.get(a, 0)) == int(bag.get(b, 0)) and a < b))
		for mid in cands:
			ob.add_item("%s (x%d)" % [ItemData.material(mid)["name"], int(bag.get(mid, 0))])
			ob.set_item_metadata(ob.item_count - 1, mid)
			if pi < old_picks.size() and int(old_picks[pi]) == mid:
				ob.select(ob.item_count - 1)
		ob.item_selected.connect(func(_idx: int): _update_bp_preview())
		box.add_child(ob)
		part_pickers.append(ob)
		pi += 1
	_update_bp_preview()

func _picks() -> Array:
	var out: Array = []
	for ob in part_pickers:
		if not is_instance_valid(ob):
			continue
		var m = ob.get_selected_metadata() if ob.selected >= 0 else 0
		out.append(int(m) if m != null else 0)
	return out

## Mesma fórmula do servidor (ComputeForged).
func _compute(bp: Dictionary, picks: Array) -> Dictionary:
	var st := {"durability": 0, "atk": 0, "def": 0, "hp": 0, "weight": 0.0, "thermal": 0, "electric": 0, "magic": 0,
		"rarity": 0, "tool_tier": 0, "resist": [], "specials": [], "parts": [], "name": bp["name"]}
	var share := 0.0
	var dur := 0.0
	var th := 0.0
	var el := 0.0
	var mg := 0.0
	var dmg := 0.0
	var dfn := 0.0
	var core := 0.0
	var main_name := ""
	for i in range(bp["parts"].size()):
		if i >= picks.size() or int(picks[i]) == 0:
			continue
		var part: Dictionary = bp["parts"][i]
		var mid := int(picks[i])
		var m: Dictionary = ItemData.material(mid)
		var w := float(part["share"])
		share += w
		dur += float(m["durability"]) * w
		th += float(m["thermal"]) * w
		el += float(m["electric"]) * w
		mg += float(m["magic"]) * w
		st["weight"] += float(m["weight"]) * w * float(bp["mass_scale"])
		var capped := minf(float(m["durability"]), float(ForgeData.STAT_CAP))
		match String(part["role"]):
			"dano":
				dmg += capped * w
				if main_name == "":
					main_name = String(m["name"])
					if int(bp["tool"]) > 0:
						st["tool_tier"] = int(m["rarity"])
			"defesa":
				dfn += capped * w
				if main_name == "":
					main_name = String(m["name"])
			"nucleo":
				core += capped * w
		st["rarity"] = maxi(int(st["rarity"]), int(m["rarity"]))
		for rr in String(m["resist"]).split(", "):
			if rr != "" and rr != "—" and not st["resist"].has(rr):
				st["resist"].append(rr)
		if ForgeData.SPECIALS.has(mid) and not st["specials"].has(ForgeData.SPECIALS[mid]):
			st["specials"].append(ForgeData.SPECIALS[mid])
		st["parts"].append("%s de %s" % [part["name"], m["name"]])
	if share <= 0.0:
		return st
	st["durability"] = int(minf(9999.0, roundf(dur / share * float(bp["dur_scale"]))))
	st["thermal"] = int(roundf(th / share))
	st["electric"] = int(roundf(el / share))
	st["magic"] = int(roundf(mg / share))
	if int(bp["kind"]) == 3:
		st["def"] = int(bp["base_def"]) + int(roundf(dfn * 0.06 + core * 0.03))
		st["hp"] = int(st["def"]) * 3
	else:
		st["atk"] = int(bp["base_atk"]) + int(roundf(dmg * 0.12 + core * 0.05))
		st["def"] = int(bp["base_def"])
	if ForgeData.SPECIALS.has(187) and st["specials"].has(ForgeData.SPECIALS[187]):
		st["weight"] = float(st["weight"]) * 0.5
	st["weight"] = maxf(0.2, snappedf(float(st["weight"]), 0.1))
	if int(st["tool_tier"]) == 0 and int(bp["tool"]) > 0:
		st["tool_tier"] = 1
	if main_name != "":
		st["name"] = "%s de %s" % [bp["name"], main_name]
	return st

func _update_bp_preview() -> void:
	if current_bp.is_empty():
		bp_preview.text = "[color=#ffd54f]Prévia do equipamento[/color]\nEscolha uma blueprint à esquerda."
		return
	var picks := _picks()
	var st := _compute(current_bp, picks)
	var lines := ["[color=#ffd54f]Prévia do equipamento[/color]"]
	if (st["parts"] as Array).is_empty():
		lines.append("Escolha o material de cada peça.")
		bp_preview.text = "\n".join(lines)
		return
	lines.append("[color=%s][b]%s[/b][/color]  (%s)" % [ItemData.rarity_color(int(st["rarity"])).to_html(false), st["name"], ItemData.rarity_name(int(st["rarity"]))])
	lines.append("[i]%s[/i]" % " + ".join(st["parts"]))
	lines.append("")
	if int(current_bp["kind"]) == 3:
		lines.append("🛡 Defesa: [color=#73e673]+%d[/color]   ❤ Vida: [color=#73e673]+%d[/color]" % [int(st["def"]), int(st["hp"])])
	else:
		lines.append("⚔ Dano: [color=#73e673]+%d[/color]" % int(st["atk"]))
		if int(st["def"]) > 0:
			lines.append("🛡 Defesa: +%d" % int(st["def"]))
	if int(current_bp["tool"]) > 0:
		lines.append("⛏ Tier de coleta: %d" % int(st["tool_tier"]))
	lines.append("🛠 Durabilidade: %d" % int(st["durability"]))
	lines.append("⚖ Peso total: %.1f kg" % float(st["weight"]))
	lines.append("Condutividade — Térmica %d%% • Elétrica %d%% • Mágica %d%%" % [int(st["thermal"]), int(st["electric"]), int(st["magic"])])
	if not (st["resist"] as Array).is_empty():
		lines.append("Resistências: [color=#73e673]%s[/color]" % ", ".join(st["resist"]))
	if not (st["specials"] as Array).is_empty():
		lines.append("Características: [color=#ffb74d]%s[/color]" % " • ".join(st["specials"]))
	# Avisos: peças obrigatórias vazias e materiais que faltam
	var bag := _bag()
	var need := {}
	for i in range(picks.size()):
		var part: Dictionary = current_bp["parts"][i]
		if int(picks[i]) == 0 and not part["optional"]:
			lines.append("[color=#ef5350]Falta escolher: %s[/color]" % part["name"])
		elif int(picks[i]) > 0:
			need[int(picks[i])] = int(need.get(int(picks[i]), 0)) + 1
	for mid in need:
		if int(bag.get(mid, 0)) < int(need[mid]):
			lines.append("[color=#ef5350]Sem %s suficiente na mochila.[/color]" % ItemData.material(mid)["name"])
	bp_preview.text = "\n".join(lines)

func _on_forge() -> void:
	if current_bp.is_empty():
		return
	NetworkManager.send_forge_blueprint(int(current_bp["id"]), _picks())

func _on_buy() -> void:
	if not current_bp.is_empty():
		NetworkManager.send_forge_action(1, int(current_bp["id"]))
