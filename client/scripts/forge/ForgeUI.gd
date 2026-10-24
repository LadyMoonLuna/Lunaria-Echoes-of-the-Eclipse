extends CanvasLayer
## Forja do Garrick — Etapa 2: [🔥 Criar Ligas] (cadinho com até 4 ingredientes) e
## [📜 Forjar por Blueprint] (o material de cada peça é escolhido). Os cálculos do preview usam as
## mesmas regras do servidor (server/internal/world/forge.go, dados em ForgeData.gd).

const LunariaUI = preload("res://scripts/ui/LunariaUI.gd")
const ItemData = preload("res://scripts/ItemData.gd")
const ForgeData = preload("res://scripts/forge/ForgeData.gd")
const ForgePuzzleTab = preload("res://scripts/forge/ForgePuzzleTab.gd")

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
var puzzle_tab: Control
var quick_forge: CheckBox
# Alerta grande (patente negada em vermelho; obra-prima em dourado)
var alert_layer: CanvasLayer
var alert_panel: PanelContainer
var alert_label: Label

func _ready() -> void:
	layer = 24
	visible = false
	_build_ui()
	LunariaUI.watch(self) # mesmo estilo do inventário
	NetworkManager.forge_alert_received.connect(show_alert)
	NetworkManager.part_result_received.connect(_on_part_result)
	NetworkManager.forge_state_received.connect(func(_bps: Array): _check_forge_result())
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
	quick_forge = CheckBox.new()
	quick_forge.text = "⚡ Forja rápida (sem mini-games, atributos sem modificador)"
	quick_forge.add_theme_font_size_override("font_size", 12)
	root.add_child(quick_forge)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_build_alloy_tab())
	tabs.add_child(_build_blueprint_tab())
	puzzle_tab = ForgePuzzleTab.new()
	puzzle_tab.forge = self
	tabs.add_child(puzzle_tab)
	_build_alert()
	_build_minigame_modal()

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
	if puzzle_tab:
		puzzle_tab.refresh()

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
	if ids.size() < 2:
		return
	if quick_forge.button_pressed:
		NetworkManager.send_forge_alloy(ids)
		return
	var mats: Array = []
	for mid in ids:
		mats.append(ItemData.material(mid))
	# Liga: Derreter, Ponto de Fusão, Formas (lingote) e Escória
	start_forge_minigames(["melt", "fusion", "mold", "prep"], mats, func(sc: Dictionary):
		NetworkManager.send_forge_alloy_scored(ids, _score_list(sc))
	)

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
	var bp_id := int(current_bp["id"])
	var picks := _picks()
	if quick_forge.button_pressed:
		NetworkManager.send_forge_blueprint(bp_id, picks)
		return
	var parts: Array = []
	for i in range(picks.size()):
		if int(picks[i]) > 0:
			parts.append({"index": i, "name": String(current_bp["parts"][i]["name"]), "mat": int(picks[i])})
	var base := _compute(current_bp, picks)
	start_equipment_forge(parts, bp_id, int(base["rarity"]), func(sc: Dictionary):
		NetworkManager.send_forge_blueprint_scored(bp_id, picks, _score_list(sc))
	)

func _on_buy() -> void:
	if not current_bp.is_empty():
		NetworkManager.send_forge_action(1, int(current_bp["id"]))


# ---------------------------------------------------------------------------
# Alerta grande na tela (0x56)
# ---------------------------------------------------------------------------

func _build_alert() -> void:
	alert_layer = CanvasLayer.new()
	alert_layer.layer = 140
	add_child(alert_layer)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_layer.add_child(holder)
	alert_panel = PanelContainer.new()
	alert_panel.visible = false
	alert_panel.custom_minimum_size = Vector2(760, 0)
	holder.add_child(alert_panel)
	alert_label = Label.new()
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_label.add_theme_font_size_override("font_size", 34)
	alert_label.add_theme_constant_override("outline_size", 8)
	alert_label.add_theme_color_override("font_outline_color", Color.BLACK)
	alert_panel.add_child(alert_label)

func show_alert(kind: int, message: String) -> void:
	var denied := kind == 1
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.02, 0.02, 0.95) if denied else Color(0.18, 0.13, 0.03, 0.95)
	sb.border_color = Color(1.0, 0.15, 0.15) if denied else Color(1.0, 0.8, 0.3)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	alert_panel.add_theme_stylebox_override("panel", sb)
	alert_label.text = message
	alert_label.add_theme_font_size_override("font_size", 34 if denied else 24)
	alert_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if denied else Color(1.0, 0.88, 0.5))
	alert_panel.visible = true
	alert_panel.modulate.a = 1.0
	var tw := alert_panel.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(alert_panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): alert_panel.visible = false)


# =============================================================================
# MINI-GAMES DA FORJA (Parte 2: 1 a 4). As notas vão de 0.0 a 1.20 e seguem para o servidor,
# que calcula a Nota de Criação. Os mini-games 5 a 7 (Bigorna, Têmpera, Montagem) chegam na
# Parte 3; até lá eles entram com a nota neutra MG_PENDING_SCORE.
# =============================================================================
const MG_PENDING_SCORE := 0.85
const MG_TITLES := {
	"melt": "🔥 Mini-Game 1: Derreter os Metais",
	"fusion": "⚗️ Mini-Game 2: Ponto de Fusão da Liga",
	"mold": "🏺 Mini-Game 3: Colocar nas Formas",
	"prep": "🔨 Mini-Game 4: Preparar o Metal (Escória e Dobras)",
	"shape": "⚔️ Mini-Game 5: Preparar a Peça (Modelagem na Bigorna)",
	"temper": "💧 Mini-Game 6: Temperar a Peça (Choque Térmico)",
	"assembly": "🔩 Mini-Game 7: Montagem Final do Equipamento",
}
const MG_HINTS := {
	"melt": "Segure [💨 Soprar Fole] (ou Espaço) para esquentar. Mantenha a temperatura na faixa dourada até a fusão chegar a 100%. Não deixe chegar no vermelho!",
	"fusion": "As três ondas correm conforme a diferença de condutividade dos materiais. Trave cada uma no Ponto de Fusão central com [⚡ Travar Frequência] (ou Espaço).",
	"mold": "A pressão esfria e puxa para a esquerda. Segure [🏺 Inclinar Cadinho] (ou Espaço) para manter o jato na Zona de Fluxo Perfeito até o molde encher.",
	"prep": "Martele (clique) cada ponto de escória antes que ele esfrie e suma. Quanto maior o ponto na hora do golpe, melhor.",
	"shape": "O cursor do martelo corre pela barra de ritmo. Acerte 3 Golpes de Modelagem com [🔨 Martelar Peça!] (ou Espaço) quando ele cruzar o centro dourado.",
	"temper": "A peça esfria e muda de cor: Branco → Amarelo → Laranja → Vermelho-Cereja → Roxo. Mergulhe com [💧 Mergulhar na Têmpera!] (ou Espaço) na Zona de Cor Ideal.",
	"assembly": "Cada trilho tem um pino correndo. Crave cada encaixe no centro de alinhamento com [🔩 Cravar Encaixe!] (ou Espaço).",
}
const MG_TIME_LIMIT := {"melt": 14.0, "fusion": 16.0, "mold": 14.0, "prep": 0.0, "shape": 14.0, "temper": 0.0, "assembly": 20.0}
const PRESS_GAMES := ["fusion", "shape", "temper", "assembly"] # jogos de apertar no momento certo
const TEMPER_COLORS := [Color(1, 1, 1), Color(1.0, 0.92, 0.3), Color(1.0, 0.55, 0.12), Color(0.8, 0.08, 0.15), Color(0.45, 0.15, 0.6)]
const MAX_TEMP := 2500.0
const OVERHEAT_TEMP := 2300.0

var mg_layer: CanvasLayer
var mg_panel: PanelContainer
var mg_title: Label
var mg_hint: Label
var mg_canvas: Control
var mg_info: Label
var mg_action: Button
var mg_next_btn: Button
var mg_queue: Array = []
var mg_game := ""
var mg_scores := {}
var mg_done_cb: Callable
var mg_running := false
var mg_finished_game := false
var mg_t := 0.0
var mg_rarity := 1
var mg_mats: Array = []
var mg_diff := {}
var mg_holding := false
var mg_space_was := false
var mg_state := {}
var mg_part_name := ""
var mg_assembly_parts: Array = [] # nomes dos trilhos do Mini-Game 7 # peça em trabalho (título dos mini-games 1, 3-6)

## Dificuldade pela raridade do material (1 Comum ... 8 Mítico) e pela Maestria (MAS) do jogador.
func _get_minigame_difficulty(material_rarity: int, player_mas: int) -> Dictionary:
	var sweet_spot_width: float = clampf(0.30 - (material_rarity * 0.03) + (player_mas * 0.003), 0.05, 0.32)
	var cursor_speed: float = (1.0 + (material_rarity * 0.28)) * maxf(0.6, 1.0 - (player_mas * 0.005))
	return {"sweet_spot_width": sweet_spot_width, "cursor_speed": cursor_speed}

func _player_mas() -> int:
	var world := get_parent()
	if world and world.get("inventory_ui") and world.inventory_ui.get("stat_totals") != null:
		return int(world.inventory_ui.stat_totals.get("mas", 0))
	return 0

func _mats_of(picks: Array) -> Array:
	var out: Array = []
	for mid in picks:
		if int(mid) > 0:
			out.append(ItemData.material(int(mid)))
	return out

## Notas na ordem do servidor; os mini-games ainda não jogados entram neutros.
func _score_list(sc: Dictionary) -> Array:
	var out: Array = []
	for key in ["melt", "fusion", "mold", "prep", "shape", "temper", "assembly"]:
		out.append(float(sc.get(key, 0.0 if key == "fusion" else MG_PENDING_SCORE)))
	return out

func _build_minigame_modal() -> void:
	mg_layer = CanvasLayer.new()
	mg_layer.layer = 30
	mg_layer.visible = false
	add_child(mg_layer)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg_layer.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	mg_panel = PanelContainer.new()
	mg_panel.custom_minimum_size = Vector2(720, 520)
	center.add_child(mg_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	mg_panel.add_child(vb)
	mg_title = _label("", 18, Color(1.0, 0.85, 0.45))
	vb.add_child(mg_title)
	mg_hint = _label("", 12, Color(0.85, 0.82, 0.75))
	vb.add_child(mg_hint)
	mg_canvas = Control.new()
	mg_canvas.custom_minimum_size = Vector2(680, 320)
	mg_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	mg_canvas.draw.connect(_mg_draw)
	mg_canvas.gui_input.connect(_mg_canvas_input)
	vb.add_child(mg_canvas)
	mg_info = _label("", 13, Color(0.95, 0.92, 0.85))
	vb.add_child(mg_info)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	mg_action = Button.new()
	mg_action.custom_minimum_size = Vector2(320, 44)
	mg_action.button_down.connect(_mg_action_down)
	mg_action.button_up.connect(func(): mg_holding = false)
	hb.add_child(mg_action)
	mg_next_btn = Button.new()
	mg_next_btn.custom_minimum_size = Vector2(200, 44)
	mg_next_btn.pressed.connect(_mg_next)
	hb.add_child(mg_next_btn)
	var cancel := Button.new()
	cancel.text = "Cancelar forja"
	cancel.pressed.connect(func():
		mg_running = false
		mg_layer.visible = false
	)
	hb.add_child(cancel)

## Começa a sequência de mini-games; on_done recebe {"melt": nota, ...}.
func start_forge_minigames(games: Array, mats: Array, on_done: Callable) -> void:
	mg_mats = mats
	mg_rarity = 1
	for m in mats:
		mg_rarity = maxi(mg_rarity, int(m.get("rarity", 1)))
	mg_diff = _get_minigame_difficulty(mg_rarity, _player_mas())
	mg_queue = games.duplicate()
	mg_scores = {}
	mg_done_cb = on_done
	mg_layer.visible = true
	_mg_begin(mg_queue.pop_front())

func _mg_begin(game: String) -> void:
	mg_game = game
	mg_t = 0.0
	mg_running = true
	mg_finished_game = false
	mg_holding = false
	mg_title.text = "%s   (raridade %s)" % [MG_TITLES[game], ItemData.rarity_name(mg_rarity)]
	if mg_part_name != "" and game != "assembly":
		mg_title.text += "\nPeça: %s" % mg_part_name
	mg_hint.text = MG_HINTS[game]
	mg_next_btn.visible = false
	mg_action.visible = game != "prep"
	var sweet: float = mg_diff["sweet_spot_width"]
	match game:
		"melt":
			mg_action.text = "💨 Soprar Fole (Espaço / Clique)"
			mg_state = {"temp": 300.0, "progress": 0.0, "in_band": 0.0, "overheat": 0.0, "band_c": 1500.0, "band_w": sweet * MAX_TEMP}
		"fusion":
			mg_action.text = "⚡ Travar Frequência (Espaço)"
			var cd := _cond_diffs(mg_mats)
			var speed: float = mg_diff["cursor_speed"]
			mg_state = {"pos": [0.1, 0.45, 0.8], "dir": [1.0, -1.0, 1.0], "locked": [-1.0, -1.0, -1.0], "current": 0,
				"speed": [0.35 * speed * (1.0 + cd[0] / 45.0), 0.35 * speed * (1.0 + cd[1] / 45.0), 0.35 * speed * (1.0 + cd[2] / 45.0)],
				"diff": cd, "zone": sweet}
		"mold":
			mg_action.text = "🏺 Inclinar Cadinho (Espaço / Segurar)"
			mg_state = {"pressure": 0.5, "fill": 0.0, "in_zone": 0.0, "bubbles": 0.0, "zone": sweet, "noise_t": 0.0}
		"shape":
			mg_action.text = "🔨 Martelar Peça! (Espaço)"
			mg_state = {"pos": 0.0, "dir": 1.0, "hits": [], "zone": sweet * 0.7, "speed": 0.55 * float(mg_diff["cursor_speed"]), "flash": 0.0}
		"temper":
			mg_action.text = "💧 Mergulhar na Têmpera! (Espaço)"
			# Zona ideal no Vermelho-Cereja (perto de 0.30 na escala de calor que cai de 1.0 a 0.0)
			mg_state = {"heat": 1.0, "zone_c": 0.30, "zone": sweet * 0.8, "rate": 0.16 * float(mg_diff["cursor_speed"]), "dipped": -1.0, "steam": 0.0}
		"assembly":
			mg_action.text = "🔩 Cravar Encaixe! (Espaço)"
			var rails: Array = []
			for nm in mg_assembly_parts:
				rails.append({"name": nm, "pos": randf(), "dir": 1.0 if randf() < 0.5 else -1.0, "locked": -1.0})
			mg_state = {"rails": rails, "current": 0, "zone": sweet * 0.8, "speed": 0.6 * float(mg_diff["cursor_speed"])}
		"prep":
			var total := clampi(5 + (mg_rarity - 1) / 2, 5, 8)
			mg_state = {"spots": [], "spawned": 0, "total": total, "hits": 0.0, "misses": 0, "next_spawn": 0.4,
				"life": 1.9 / float(mg_diff["cursor_speed"]) * 1.4}
	mg_canvas.queue_redraw()

## Diferença média de condutividade (térmica, elétrica, mágica) entre os materiais escolhidos.
func _cond_diffs(mats: Array) -> Array:
	var sums := [0.0, 0.0, 0.0]
	var pairs := 0
	for i in range(mats.size()):
		for j in range(i + 1, mats.size()):
			sums[0] += absf(float(mats[i]["thermal"]) - float(mats[j]["thermal"]))
			sums[1] += absf(float(mats[i]["electric"]) - float(mats[j]["electric"]))
			sums[2] += absf(float(mats[i]["magic"]) - float(mats[j]["magic"]))
			pairs += 1
	if pairs == 0:
		return [0.0, 0.0, 0.0]
	return [sums[0] / pairs, sums[1] / pairs, sums[2] / pairs]

func _mg_action_down() -> void:
	mg_holding = true
	_mg_press()

## Apertar (botão ou Espaço) nos jogos de tempo certo.
func _mg_press() -> void:
	if mg_finished_game:
		return
	match mg_game:
		"fusion":
			_mg_lock_wave()
		"shape":
			_mg_strike()
		"temper":
			_mg_dip()
		"assembly":
			_mg_rivet()

func _mg_canvas_input(event: InputEvent) -> void:
	if not mg_running or mg_finished_game:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mg_game == "prep":
			_mg_hammer(event.position)

func _process(delta: float) -> void:
	if not mg_running or mg_finished_game or mg_layer == null or not mg_layer.visible:
		return
	# Espaço funciona como o botão de ação (segurar ou travar)
	var space := Input.is_key_pressed(KEY_SPACE)
	if PRESS_GAMES.has(mg_game) and space and not mg_space_was:
		_mg_press()
	mg_space_was = space
	var hold: bool = mg_holding or space
	mg_t += delta
	match mg_game:
		"melt":
			_mg_tick_melt(delta, hold)
		"fusion":
			_mg_tick_fusion(delta)
		"mold":
			_mg_tick_mold(delta, hold)
		"prep":
			_mg_tick_prep(delta)
		"shape":
			_mg_tick_shape(delta)
		"temper":
			_mg_tick_temper(delta)
		"assembly":
			_mg_tick_assembly(delta)
	var limit: float = MG_TIME_LIMIT[mg_game]
	if limit > 0.0 and mg_t >= limit and not mg_finished_game:
		_mg_finish()
	mg_canvas.queue_redraw()

# --- 1: Derreter os Metais ---
func _mg_tick_melt(delta: float, hold: bool) -> void:
	var st := mg_state
	var speed: float = mg_diff["cursor_speed"]
	# Faixa ideal oscila devagar (turbulência térmica maior em metais raros)
	st["band_c"] = 1500.0 + sin(mg_t * 0.9 * speed) * 380.0
	if hold:
		st["temp"] = minf(MAX_TEMP, float(st["temp"]) + 950.0 * speed * delta)
	else:
		st["temp"] = maxf(0.0, float(st["temp"]) - 620.0 * delta)
	var lo: float = float(st["band_c"]) - float(st["band_w"]) / 2.0
	var hi: float = float(st["band_c"]) + float(st["band_w"]) / 2.0
	if float(st["temp"]) >= lo and float(st["temp"]) <= hi:
		st["in_band"] = float(st["in_band"]) + delta
		st["progress"] = minf(1.0, float(st["progress"]) + delta / 4.0)
	if float(st["temp"]) >= OVERHEAT_TEMP:
		st["overheat"] = float(st["overheat"]) + delta
	mg_info.text = "🌡 %d °C   •   Faixa ideal: %d–%d °C   •   Progresso de Fusão: %d%%   •   %.0fs" % [
		int(st["temp"]), int(lo), int(hi), int(float(st["progress"]) * 100.0), maxf(0.0, MG_TIME_LIMIT["melt"] - mg_t)]
	if float(st["progress"]) >= 1.0:
		_mg_finish()

func _melt_score() -> float:
	var st := mg_state
	var precision: float = float(st["in_band"]) / maxf(mg_t, 0.01)
	return clampf(float(st["progress"]) * 0.9 + precision * 0.3 - float(st["overheat"]) * 0.25, 0.0, 1.2)

# --- 2: Ponto de Fusão ---
func _mg_tick_fusion(delta: float) -> void:
	var st := mg_state
	for k in range(3):
		if float(st["locked"][k]) >= 0.0:
			continue
		var p: float = float(st["pos"][k]) + float(st["dir"][k]) * float(st["speed"][k]) * delta
		if p > 1.0 or p < 0.0:
			st["dir"][k] = -float(st["dir"][k])
			p = clampf(p, 0.0, 1.0)
		st["pos"][k] = p
	var names := ["🔥 Térmica", "⚡ Elétrica", "✨ Mágica"]
	var cur: int = int(st["current"])
	mg_info.text = "Onda atual: %s   •   Diferença de condutividade: T %.0f / E %.0f / M %.0f   •   %.0fs" % [
		names[mini(cur, 2)], float(st["diff"][0]), float(st["diff"][1]), float(st["diff"][2]), maxf(0.0, MG_TIME_LIMIT["fusion"] - mg_t)]

func _mg_lock_wave() -> void:
	if mg_game != "fusion" or mg_finished_game:
		return
	var st := mg_state
	var cur: int = int(st["current"])
	if cur > 2:
		return
	st["locked"][cur] = float(st["pos"][cur])
	st["current"] = cur + 1
	if cur + 1 > 2:
		_mg_finish()

func _fusion_score() -> float:
	var st := mg_state
	var half: float = float(st["zone"]) / 2.0
	var total := 0.0
	for k in range(3):
		var p: float = float(st["locked"][k])
		if p < 0.0:
			continue
		var dist := absf(p - 0.5)
		if dist <= half:
			total += 1.2 - 0.35 * (dist / maxf(half, 0.001))
		else:
			total += maxf(0.0, 0.6 - (dist - half) * 2.0)
	return clampf(total / 3.0, 0.0, 1.2)

# --- 3: Colocar nas Formas ---
func _mg_tick_mold(delta: float, hold: bool) -> void:
	var st := mg_state
	var speed: float = mg_diff["cursor_speed"]
	st["noise_t"] = float(st["noise_t"]) + delta
	var drift: float = (0.30 + 0.12 * sin(float(st["noise_t"]) * 2.3 * speed)) * speed
	var p: float = float(st["pressure"]) - drift * delta
	if hold:
		p += 0.75 * speed * delta
	st["pressure"] = clampf(p, 0.0, 1.0)
	var half: float = float(st["zone"]) / 2.0
	var dist := absf(float(st["pressure"]) - 0.5)
	if dist <= half:
		st["in_zone"] = float(st["in_zone"]) + delta
		st["fill"] = minf(1.0, float(st["fill"]) + delta / 4.5)
	elif dist <= half * 2.0:
		st["fill"] = minf(1.0, float(st["fill"]) + delta / 12.0)
	if float(st["pressure"]) >= 0.92:
		st["bubbles"] = float(st["bubbles"]) + delta
	mg_info.text = "Molde: %d%% cheio   •   Bolhas: %.1fs   •   %.0fs" % [int(float(st["fill"]) * 100.0), float(st["bubbles"]), maxf(0.0, MG_TIME_LIMIT["mold"] - mg_t)]
	if float(st["fill"]) >= 1.0:
		_mg_finish()

func _mold_score() -> float:
	var st := mg_state
	var precision: float = float(st["in_zone"]) / maxf(mg_t, 0.01)
	return clampf(float(st["fill"]) * 0.85 + precision * 0.35 - float(st["bubbles"]) * 0.2, 0.0, 1.2)

# --- 4: Preparar o Metal ---
func _ingot_rect() -> Rect2:
	return Rect2(Vector2(130, 110), Vector2(420, 120))

func _mg_tick_prep(delta: float) -> void:
	var st := mg_state
	st["next_spawn"] = float(st["next_spawn"]) - delta
	var alive: Array = []
	for sp in st["spots"]:
		sp["age"] = float(sp["age"]) + delta
		if float(sp["age"]) < float(st["life"]):
			alive.append(sp)
	st["spots"] = alive
	if int(st["spawned"]) < int(st["total"]) and float(st["next_spawn"]) <= 0.0 and alive.size() < 2:
		var r := _ingot_rect()
		alive.append({"pos": Vector2(randf_range(r.position.x + 24, r.end.x - 24), randf_range(r.position.y + 20, r.end.y - 20)), "age": 0.0})
		st["spawned"] = int(st["spawned"]) + 1
		st["next_spawn"] = 0.55 / float(mg_diff["cursor_speed"]) + 0.25
	mg_info.text = "Escória purificada: %d de %d   •   Golpes errados: %d" % [_prep_hits(), int(st["total"]), int(st["misses"])]
	if int(st["spawned"]) >= int(st["total"]) and alive.is_empty():
		_mg_finish()

func _prep_hits() -> int:
	return int(mg_state.get("hit_count", 0))

func _mg_hammer(pos: Vector2) -> void:
	var st := mg_state
	for sp in st["spots"]:
		var ratio: float = 1.0 - float(sp["age"]) / float(st["life"])
		if pos.distance_to(sp["pos"]) <= 8.0 + 26.0 * ratio:
			st["hits"] = float(st["hits"]) + ratio
			st["hit_count"] = int(st.get("hit_count", 0)) + 1
			(st["spots"] as Array).erase(sp)
			return
	st["misses"] = int(st["misses"]) + 1

func _prep_score() -> float:
	var st := mg_state
	return clampf(float(st["hits"]) / float(st["total"]) * 1.25 - int(st["misses"]) * 0.04, 0.0, 1.2)

# --- Fim de cada mini-game ---
func _mg_finish() -> void:
	mg_finished_game = true
	mg_holding = false
	var score := 0.0
	match mg_game:
		"melt":
			score = _melt_score()
		"fusion":
			score = _fusion_score()
		"mold":
			score = _mold_score()
		"prep":
			score = _prep_score()
		"shape":
			score = _shape_score()
		"temper":
			score = _temper_score()
		"assembly":
			score = _assembly_score()
	mg_scores[mg_game] = score
	var verdict := "Defeituoso"
	if score >= 1.10:
		verdict = "Divino"
	elif score >= 0.95:
		verdict = "Obra-Prima"
	elif score >= 0.75:
		verdict = "Firme"
	elif score >= 0.50:
		verdict = "Imperfeito"
	var extra := ""
	if mg_game == "fusion" and score >= 0.95:
		extra = "   ✨ Harmonia Híbrida garantida!"
	mg_info.text = "Nota: %.2f / 1.20  (%s)%s" % [score, verdict, extra]
	mg_action.visible = false
	mg_next_btn.visible = true
	mg_next_btn.text = "Próximo mini-game ▶" if not mg_queue.is_empty() else "🔨 Concluir forja"
	mg_canvas.queue_redraw()

func _mg_next() -> void:
	if not mg_queue.is_empty():
		_mg_begin(mg_queue.pop_front())
		return
	mg_running = false
	mg_layer.visible = false
	if mg_done_cb.is_valid():
		mg_done_cb.call(mg_scores.duplicate())

# --- Desenho (60 FPS) ---
func _mg_draw() -> void:
	var c := mg_canvas
	var size := c.size
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.05))
	match mg_game:
		"melt":
			_draw_melt(c, size)
		"fusion":
			_draw_fusion(c, size)
		"mold":
			_draw_mold(c, size)
		"prep":
			_draw_prep(c, size)
		"shape":
			_draw_shape(c, size)
		"temper":
			_draw_temper(c, size)
		"assembly":
			_draw_assembly(c, size)

func _draw_melt(c: Control, size: Vector2) -> void:
	var st := mg_state
	var bar := Rect2(Vector2(size.x * 0.5 - 30, 20), Vector2(60, size.y - 40))
	c.draw_rect(bar, Color(0.15, 0.13, 0.12))
	var to_y := func(t: float) -> float: return bar.end.y - t / MAX_TEMP * bar.size.y
	# Topo vermelho (superaquecimento) e faixa ideal dourada
	var red_y: float = to_y.call(OVERHEAT_TEMP)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x, red_y - bar.position.y)), Color(0.75, 0.1, 0.08, 0.7))
	var band_top: float = to_y.call(float(st["band_c"]) + float(st["band_w"]) / 2.0)
	var band_bot: float = to_y.call(float(st["band_c"]) - float(st["band_w"]) / 2.0)
	c.draw_rect(Rect2(Vector2(bar.position.x, band_top), Vector2(bar.size.x, band_bot - band_top)), Color(1.0, 0.65, 0.15, 0.55))
	var ty: float = to_y.call(float(st["temp"]))
	c.draw_rect(Rect2(Vector2(bar.position.x + 18, ty), Vector2(24, bar.end.y - ty)), Color(1.0, 0.35 + float(st["temp"]) / MAX_TEMP * 0.4, 0.1))
	c.draw_line(Vector2(bar.position.x - 14, ty), Vector2(bar.end.x + 14, ty), Color.WHITE, 3.0)
	for t in [0, 500, 1000, 1500, 2000, 2500]:
		c.draw_string(c.get_theme_default_font(), Vector2(bar.end.x + 18, to_y.call(float(t)) + 4), "%d°C" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.78, 0.7))
	# Barra de progresso de fusão
	var pr := Rect2(Vector2(40, size.y - 50), Vector2(200, 22))
	c.draw_rect(pr, Color(0.15, 0.13, 0.12))
	c.draw_rect(Rect2(pr.position, Vector2(pr.size.x * float(st["progress"]), pr.size.y)), Color(1.0, 0.75, 0.25))
	c.draw_string(c.get_theme_default_font(), pr.position + Vector2(0, -6), "Progresso de Fusão", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5))

func _draw_fusion(c: Control, size: Vector2) -> void:
	var st := mg_state
	var cols := [Color(1.0, 0.45, 0.2), Color(0.4, 0.75, 1.0), Color(0.8, 0.5, 1.0)]
	var names := ["🔥 Térmica", "⚡ Elétrica", "✨ Mágica"]
	var zone: float = float(st["zone"])
	for k in range(3):
		var y := 50.0 + k * 95.0
		var x0 := 60.0
		var w := size.x - 120.0
		# Onda decorativa: mais nervosa quanto maior a diferença de condutividade
		var pts := PackedVector2Array()
		for i in range(61):
			var fx := float(i) / 60.0
			pts.append(Vector2(x0 + fx * w, y + sin(fx * TAU * (2.0 + float(st["diff"][k]) / 20.0) + mg_t * 3.0) * 14.0))
		c.draw_polyline(pts, Color(cols[k], 0.5), 2.0)
		c.draw_rect(Rect2(Vector2(x0 + (0.5 - zone / 2.0) * w, y - 22), Vector2(zone * w, 44)), Color(0.3, 0.9, 0.4, 0.25))
		c.draw_line(Vector2(x0 + 0.5 * w, y - 26), Vector2(x0 + 0.5 * w, y + 26), Color(0.4, 1.0, 0.5), 2.0)
		var locked: float = float(st["locked"][k])
		var p: float = locked if locked >= 0.0 else float(st["pos"][k])
		var cx := x0 + p * w
		c.draw_circle(Vector2(cx, y), 9.0 if locked < 0.0 else 7.0, cols[k] if locked < 0.0 else Color.WHITE)
		var label: String = names[k] + ("  ✔ travada" if locked >= 0.0 else ("  ◀ agora" if int(st["current"]) == k else ""))
		c.draw_string(c.get_theme_default_font(), Vector2(x0, y - 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cols[k])

func _draw_mold(c: Control, size: Vector2) -> void:
	var st := mg_state
	# Cadinho despejando no molde
	var mold := Rect2(Vector2(size.x * 0.5 - 70, 150), Vector2(140, 130))
	c.draw_rect(mold, Color(0.25, 0.22, 0.2))
	var fill: float = float(st["fill"])
	c.draw_rect(Rect2(Vector2(mold.position.x, mold.end.y - mold.size.y * fill), Vector2(mold.size.x, mold.size.y * fill)), Color(1.0, 0.55, 0.1))
	var jet_x := mold.position.x + mold.size.x * float(st["pressure"])
	c.draw_line(Vector2(size.x * 0.5, 40), Vector2(jet_x, mold.end.y - mold.size.y * fill), Color(1.0, 0.7, 0.2), 6.0)
	c.draw_rect(Rect2(Vector2(size.x * 0.5 - 40, 20), Vector2(80, 30)), Color(0.45, 0.42, 0.4))
	if float(st["pressure"]) >= 0.92:
		for i in range(4):
			c.draw_circle(Vector2(mold.position.x + randf() * mold.size.x, mold.end.y - mold.size.y * fill - randf() * 10.0), 4.0, Color(1, 1, 1, 0.7))
	# Barra de pressão com a Zona de Fluxo Perfeito
	var bar := Rect2(Vector2(60, 100), Vector2(size.x - 120, 24))
	c.draw_rect(bar, Color(0.15, 0.13, 0.12))
	var zone: float = float(st["zone"])
	c.draw_rect(Rect2(Vector2(bar.position.x + (0.5 - zone / 2.0) * bar.size.x, bar.position.y), Vector2(zone * bar.size.x, bar.size.y)), Color(0.3, 0.9, 0.4, 0.45))
	c.draw_rect(Rect2(Vector2(bar.position.x + 0.92 * bar.size.x, bar.position.y), Vector2(0.08 * bar.size.x, bar.size.y)), Color(0.8, 0.15, 0.1, 0.6))
	var px := bar.position.x + float(st["pressure"]) * bar.size.x
	c.draw_line(Vector2(px, bar.position.y - 6), Vector2(px, bar.end.y + 6), Color.WHITE, 3.0)
	c.draw_string(c.get_theme_default_font(), bar.position + Vector2(0, -8), "Pressão de Vazamento  (esfriando ◀   ▶ inclinar)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5))

func _draw_prep(c: Control, _size: Vector2) -> void:
	var st := mg_state
	var anvil := Rect2(Vector2(160, 230), Vector2(360, 50))
	c.draw_rect(anvil, Color(0.25, 0.25, 0.28))
	var ing := _ingot_rect()
	c.draw_rect(ing, Color(0.95, 0.45, 0.12))
	c.draw_rect(Rect2(ing.position + Vector2(10, 10), ing.size - Vector2(20, 20)), Color(1.0, 0.65, 0.25))
	for sp in st["spots"]:
		var ratio: float = 1.0 - float(sp["age"]) / float(st["life"])
		var blink := 0.6 + 0.4 * sin(float(sp["age"]) * 18.0)
		c.draw_circle(sp["pos"], 8.0 + 26.0 * ratio, Color(0.2, 0.18, 0.15, blink))
		c.draw_arc(sp["pos"], 8.0 + 26.0 * ratio, 0.0, TAU, 24, Color(1, 1, 0.6, blink), 2.0)

# --- 5: Preparar a Peça (Modelagem) ---
func _mg_tick_shape(delta: float) -> void:
	var st := mg_state
	var p: float = float(st["pos"]) + float(st["dir"]) * float(st["speed"]) * delta
	if p > 1.0 or p < 0.0:
		st["dir"] = -float(st["dir"])
		p = clampf(p, 0.0, 1.0)
	st["pos"] = p
	st["flash"] = maxf(0.0, float(st["flash"]) - delta)
	mg_info.text = "Golpes de Modelagem: %d de 3   •   %.0fs" % [(st["hits"] as Array).size(), maxf(0.0, MG_TIME_LIMIT["shape"] - mg_t)]

func _mg_strike() -> void:
	var st := mg_state
	(st["hits"] as Array).append(absf(float(st["pos"]) - 0.5))
	st["flash"] = 0.25
	if (st["hits"] as Array).size() >= 3:
		_mg_finish()

## Nota de um golpe/trava: perfeito no centro (1.20), aceitável dentro da zona, ruim fora dela.
func _timing_score(dist: float, zone: float) -> float:
	var half := zone / 2.0
	if dist <= half:
		return 1.2 - 0.35 * (dist / maxf(half, 0.001))
	return maxf(0.0, 0.6 - (dist - half) * 2.0)

func _shape_score() -> float:
	var st := mg_state
	var total := 0.0
	for d in st["hits"]:
		total += _timing_score(float(d), float(st["zone"]))
	return clampf(total / 3.0, 0.0, 1.2) # golpes que faltaram contam zero

# --- 6: Temperar a Peça ---
func _temper_color(heat: float) -> Color:
	var x := clampf(1.0 - heat, 0.0, 1.0) * (TEMPER_COLORS.size() - 1)
	var i := mini(int(x), TEMPER_COLORS.size() - 2)
	return TEMPER_COLORS[i].lerp(TEMPER_COLORS[i + 1], x - i)

func _mg_tick_temper(delta: float) -> void:
	var st := mg_state
	if float(st["dipped"]) >= 0.0:
		st["steam"] = float(st["steam"]) + delta
		if float(st["steam"]) > 1.0:
			_mg_finish()
		return
	st["heat"] = maxf(0.0, float(st["heat"]) - float(st["rate"]) * delta)
	mg_info.text = "Calor da peça: %d%%   •   Zona ideal: Vermelho-Cereja" % int(float(st["heat"]) * 100.0)
	if float(st["heat"]) <= 0.0:
		st["dipped"] = 0.0 # esfriou demais sem mergulhar
		_mg_finish()

func _mg_dip() -> void:
	var st := mg_state
	if float(st["dipped"]) < 0.0:
		st["dipped"] = float(st["heat"])

func _temper_score() -> float:
	var st := mg_state
	if float(st["dipped"]) <= 0.0:
		return 0.15
	return clampf(_timing_score(absf(float(st["dipped"]) - float(st["zone_c"])), float(st["zone"])), 0.0, 1.2)

# --- 7: Montagem Final ---
func _mg_tick_assembly(delta: float) -> void:
	var st := mg_state
	var cur: int = int(st["current"])
	var rails: Array = st["rails"]
	if cur < rails.size():
		var r: Dictionary = rails[cur]
		var p: float = float(r["pos"]) + float(r["dir"]) * float(st["speed"]) * delta
		if p > 1.0 or p < 0.0:
			r["dir"] = -float(r["dir"])
			p = clampf(p, 0.0, 1.0)
		r["pos"] = p
		mg_info.text = "Encaixe atual: %s (%d de %d)   •   %.0fs" % [r["name"], cur + 1, rails.size(), maxf(0.0, MG_TIME_LIMIT["assembly"] - mg_t)]

func _mg_rivet() -> void:
	var st := mg_state
	var cur: int = int(st["current"])
	var rails: Array = st["rails"]
	if cur >= rails.size():
		return
	rails[cur]["locked"] = absf(float(rails[cur]["pos"]) - 0.5)
	st["current"] = cur + 1
	if cur + 1 >= rails.size():
		_mg_finish()

func _assembly_score() -> float:
	var st := mg_state
	var rails: Array = st["rails"]
	if rails.is_empty():
		return 0.85
	var total := 0.0
	for r in rails:
		if float(r["locked"]) >= 0.0:
			total += _timing_score(float(r["locked"]), float(st["zone"]))
	return clampf(total / rails.size(), 0.0, 1.2)

# --- Desenho 5, 6 e 7 ---
func _draw_part_outline(c: Control, center: Vector2, col: Color) -> void:
	var nm := mg_part_name.to_lower()
	if nm.contains("lâmina") or nm.contains("ponta") or nm.contains("gume") or nm.contains("cabeça") or nm.contains("braços"):
		c.draw_colored_polygon(PackedVector2Array([center + Vector2(-150, 14), center + Vector2(120, 14), center + Vector2(165, 0), center + Vector2(120, -14), center + Vector2(-150, -14)]), col)
	elif nm.contains("guarda") or nm.contains("anel") or nm.contains("moldura"):
		c.draw_rect(Rect2(center + Vector2(-90, -12), Vector2(180, 24)), col)
	elif nm.contains("pomo") or nm.contains("núcleo") or nm.contains("gema") or nm.contains("engaste") or nm.contains("emblema"):
		c.draw_circle(center, 30.0, col)
	else:
		c.draw_rect(Rect2(center + Vector2(-110, -10), Vector2(220, 20)), col)

func _draw_shape(c: Control, size: Vector2) -> void:
	var st := mg_state
	c.draw_rect(Rect2(Vector2(size.x * 0.5 - 200, 150), Vector2(400, 60)), Color(0.25, 0.25, 0.28)) # bigorna
	var glow := Color(1.0, 0.55 + float(st["flash"]) * 1.5, 0.15)
	_draw_part_outline(c, Vector2(size.x * 0.5, 130), glow)
	var bar := Rect2(Vector2(60, 250), Vector2(size.x - 120, 26))
	c.draw_rect(bar, Color(0.15, 0.13, 0.12))
	var zone: float = float(st["zone"])
	c.draw_rect(Rect2(Vector2(bar.position.x + (0.5 - zone / 2.0) * bar.size.x, bar.position.y), Vector2(zone * bar.size.x, bar.size.y)), Color(1.0, 0.8, 0.25, 0.6))
	var px := bar.position.x + float(st["pos"]) * bar.size.x
	c.draw_line(Vector2(px, bar.position.y - 10), Vector2(px, bar.end.y + 10), Color.WHITE, 4.0)
	c.draw_string(c.get_theme_default_font(), bar.position + Vector2(0, -8), "Barra de ritmo do martelo — centro dourado da bigorna", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5))
	for i in range((st["hits"] as Array).size()):
		c.draw_string(c.get_theme_default_font(), Vector2(60 + i * 90, 30), "🔨 %.2f" % _timing_score(float(st["hits"][i]), zone), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.6))

func _draw_temper(c: Control, size: Vector2) -> void:
	var st := mg_state
	var heat: float = float(st["heat"]) if float(st["dipped"]) < 0.0 else float(st["dipped"])
	_draw_part_outline(c, Vector2(size.x * 0.5, 90), _temper_color(heat))
	# Tanque de têmpera
	c.draw_rect(Rect2(Vector2(size.x * 0.5 - 170, 150), Vector2(340, 70)), Color(0.15, 0.3, 0.45))
	if float(st["dipped"]) >= 0.0:
		for i in range(14):
			var sx := size.x * 0.5 - 150 + randf() * 300
			c.draw_circle(Vector2(sx, 140 - randf() * 60 * float(st["steam"])), 6 + randf() * 6, Color(1, 1, 1, 0.35))
	# Barra de cores (calor cai da esquerda para a direita)
	var bar := Rect2(Vector2(60, 250), Vector2(size.x - 120, 26))
	var steps := 60
	for i in range(steps):
		var h := 1.0 - float(i) / steps
		c.draw_rect(Rect2(Vector2(bar.position.x + bar.size.x * i / steps, bar.position.y), Vector2(bar.size.x / steps + 1, bar.size.y)), _temper_color(h))
	var zc: float = float(st["zone_c"])
	var zone: float = float(st["zone"])
	var zx := bar.position.x + (1.0 - zc - zone / 2.0) * bar.size.x
	c.draw_rect(Rect2(Vector2(zx, bar.position.y - 4), Vector2(zone * bar.size.x, bar.size.y + 8)), Color(0.3, 1.0, 0.4), false, 3.0)
	var px := bar.position.x + (1.0 - heat) * bar.size.x
	c.draw_line(Vector2(px, bar.position.y - 12), Vector2(px, bar.end.y + 12), Color.WHITE, 4.0)
	c.draw_string(c.get_theme_default_font(), bar.position + Vector2(0, -8), "Branco → Amarelo → Laranja → Vermelho-Cereja → Roxo", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5))

func _draw_assembly(c: Control, size: Vector2) -> void:
	var st := mg_state
	var rails: Array = st["rails"]
	var zone: float = float(st["zone"])
	var gap := minf(48.0, 280.0 / maxf(1.0, rails.size()))
	for k in range(rails.size()):
		var r: Dictionary = rails[k]
		var y := 30.0 + k * gap
		var x0 := 200.0
		var w := size.x - 260.0
		c.draw_string(c.get_theme_default_font(), Vector2(20, y + 5), String(r["name"]).substr(0, 22), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.7))
		c.draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(0.4, 0.38, 0.36), 6.0)
		c.draw_rect(Rect2(Vector2(x0 + (0.5 - zone / 2.0) * w, y - 10), Vector2(zone * w, 20)), Color(0.3, 0.9, 0.4, 0.35))
		var locked: float = float(r["locked"])
		var p: float = (0.5 + locked if locked >= 0.0 else float(r["pos"]))
		var col := Color.WHITE if locked >= 0.0 else (Color(1.0, 0.8, 0.3) if int(st["current"]) == k else Color(0.5, 0.5, 0.5))
		c.draw_circle(Vector2(x0 + clampf(p, 0.0, 1.0) * w, y), 8.0, col)

# =============================================================================
# FORJA DE EQUIPAMENTO POR PEÇAS: mini-games de cada peça -> Inspeção (Reforja) -> Montagem -> Resultado
# =============================================================================
var eq_parts: Array = []      # {"index", "name", "mat", "scores": {...}}
var eq_index := 0
var eq_bp_id := 0             # 0 = Quebra-Cabeça (sem sessão de peças no servidor)
var eq_base_rarity := 1
var eq_final_cb: Callable
var eq_final_scores := {}
var eq_review_box: VBoxContainer
var eq_awaiting_result := false
var eq_known_before: Array = []
var eq_pending := {}        # peça esperando a confirmação do servidor (0x5E)
var eq_notice := ""         # aviso do servidor mostrado na inspeção

func _is_metal(mid: int) -> bool:
	return ["Metal", "Liga"].has(String(ItemData.material(mid).get("category", "")))

func _part_games(mid: int) -> Array:
	return ["melt", "mold", "prep", "shape", "temper"] if _is_metal(mid) else ["shape"]

## Começa a forja de um equipamento: cada peça passa pelos seus mini-games.
func start_equipment_forge(parts: Array, bp_id: int, base_rarity: int, on_final: Callable) -> void:
	eq_parts = []
	for pt in parts:
		var d: Dictionary = pt.duplicate()
		d["scores"] = {}
		eq_parts.append(d)
	eq_index = 0
	eq_bp_id = bp_id
	eq_base_rarity = base_rarity
	eq_final_cb = on_final
	_eq_next_part()

func _eq_next_part() -> void:
	if eq_index >= eq_parts.size():
		_show_inspection()
		return
	_eq_work_part(eq_index, false)

func _eq_work_part(idx: int, reforge: bool) -> void:
	var pt: Dictionary = eq_parts[idx]
	mg_part_name = "%s de %s%s" % [pt["name"], ItemData.material(int(pt["mat"]))["name"], "  (🔥 Reforja)" if reforge else ""]
	start_forge_minigames(_part_games(int(pt["mat"])), [ItemData.material(int(pt["mat"]))], func(sc: Dictionary):
		# A nota só vale quando o servidor confirma (ele pode recusar: Stamina, fadiga do metal...)
		eq_pending = {"idx": idx, "reforge": reforge, "local": sc}
		if eq_bp_id > 0:
			NetworkManager.send_reforge_part(eq_bp_id, int(pt["index"]), int(pt["mat"]), _part_score_list(sc))
		else:
			NetworkManager.send_puzzle_part(int(pt["index"]), int(pt.get("module", 0)), int(pt["mat"]), _part_score_list(sc))
		_show_waiting(pt)
	)

func _show_waiting(pt: Dictionary) -> void:
	mg_layer.visible = true
	mg_canvas.visible = false
	mg_action.visible = false
	mg_next_btn.visible = false
	mg_title.text = "⏳ O mestre ferreiro avalia a peça..."
	mg_hint.text = "%s de %s" % [pt["name"], ItemData.material(int(pt["mat"]))["name"]]
	mg_info.text = ""
	var token := Time.get_ticks_msec()
	eq_pending["token"] = token
	get_tree().create_timer(6.0).timeout.connect(func():
		if not eq_pending.is_empty() and int(eq_pending.get("token", 0)) == token:
			# Sem resposta (conexão caiu?): não inventa nota; volta para a inspeção com aviso
			eq_notice = "⚠️ O servidor não respondeu: a nota desta peça não foi confirmada."
			var was_reforge: bool = eq_pending["reforge"]
			eq_pending = {}
			mg_canvas.visible = true
			if was_reforge:
				_show_inspection()
			else:
				eq_index += 1
				_eq_next_part()
	)

## Resposta 0x5E: guarda exatamente a nota que o servidor confirmou (com a oxidação da Reforja).
func _on_part_result(_bp_id: int, part_idx: int, status: int, reforges: int, max_reforges: int, scores: Array, message: String) -> void:
	if eq_pending.is_empty():
		return
	var pt: Dictionary = eq_parts[int(eq_pending["idx"])]
	if int(pt["index"]) != part_idx:
		return
	var was_reforge: bool = eq_pending["reforge"]
	eq_pending = {}
	mg_canvas.visible = true
	pt["max_reforges"] = max_reforges
	if status == 2:
		eq_notice = "⛔ " + message
	else:
		pt["reforges"] = reforges
		var keys := ["melt", "fusion", "mold", "prep", "shape", "temper", "assembly"]
		var stored := {}
		for k in _part_games(int(pt["mat"])):
			stored[k] = float(scores[keys.find(k)])
		pt["scores"] = stored
		eq_notice = message
	if was_reforge:
		_show_inspection()
	else:
		eq_index += 1
		_eq_next_part()

## Peças não metálicas só passam pela Modelagem: ela vale para as outras etapas daquela peça.
func _part_score_list(sc: Dictionary) -> Array:
	var shape: float = float(sc.get("shape", MG_PENDING_SCORE))
	var out: Array = []
	for key in ["melt", "fusion", "mold", "prep", "shape", "temper", "assembly"]:
		out.append(float(sc.get(key, 0.0 if key == "fusion" else shape)))
	return out

func _part_quality(sc: Dictionary) -> float:
	if sc.is_empty():
		return 0.0
	var total := 0.0
	for k in sc:
		total += float(sc[k])
	return total / sc.size()

func _show_inspection() -> void:
	mg_part_name = ""
	mg_layer.visible = true
	mg_running = false
	mg_title.text = "🔍 Inspeção das Peças Antes da Montagem Final"
	mg_hint.text = "Peças de Metal ou Liga podem voltar ao fogo: a Reforja repete os mini-games 1, 3, 4, 5 e 6 daquela peça (custa 15 de Stamina, sem perder o metal)."
	mg_canvas.visible = false
	mg_action.visible = false
	if eq_review_box == null:
		eq_review_box = VBoxContainer.new()
		eq_review_box.add_theme_constant_override("separation", 6)
		mg_canvas.get_parent().add_child(eq_review_box)
		mg_canvas.get_parent().move_child(eq_review_box, mg_canvas.get_index() + 1)
	eq_review_box.visible = true
	for ch in eq_review_box.get_children():
		ch.queue_free()
	for i in range(eq_parts.size()):
		var pt: Dictionary = eq_parts[i]
		var q := _part_quality(pt["scores"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		eq_review_box.add_child(row)
		var col := Color(0.45, 0.9, 0.45) if q >= 0.95 else (Color(1.0, 0.85, 0.3) if q >= 0.75 else Color(1.0, 0.45, 0.4))
		var lbl := _label("%d. %s de %s: Qualidade %d%%" % [i + 1, pt["name"], ItemData.material(int(pt["mat"]))["name"], int(round(q * 100.0))], 13, col)
		lbl.custom_minimum_size = Vector2(380, 0)
		row.add_child(lbl)
		var b := Button.new()
		var refs: int = int(pt.get("reforges", 0))
		var max_refs: int = int(pt.get("max_reforges", 3))
		if refs > 0:
			lbl.text += "  •  Reforjas %d/%d (última fusão oxidou %d%%)" % [refs, max_refs, refs * 3]
		if _is_metal(int(pt["mat"])) and refs >= max_refs:
			b.text = "🧱 Fadiga do metal (não aguenta outra fusão)"
			b.disabled = true
		elif _is_metal(int(pt["mat"])):
			b.text = "🔥 Derreter & Reforjar Peça (15 Stamina)"
			b.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			var part_idx := i
			b.pressed.connect(func(): _eq_reforge(part_idx))
		else:
			b.text = "🔒 Material Não-Metálico (Não pode ser derretido)"
			b.disabled = true
		row.add_child(b)
	mg_info.text = (eq_notice + "\n" if eq_notice != "" else "") + "Quando estiver satisfeito com as notas, prossiga para a montagem."
	eq_notice = ""
	mg_next_btn.visible = true
	mg_next_btn.text = "🔩 Prosseguir para Montagem Final"
	for conn in mg_next_btn.pressed.get_connections():
		mg_next_btn.pressed.disconnect(conn["callable"])
	mg_next_btn.pressed.connect(_eq_assemble)

func _eq_leave_inspection() -> void:
	if eq_review_box:
		eq_review_box.visible = false
	mg_canvas.visible = true
	for conn in mg_next_btn.pressed.get_connections():
		mg_next_btn.pressed.disconnect(conn["callable"])
	mg_next_btn.pressed.connect(_mg_next)

func _eq_reforge(idx: int) -> void:
	_eq_leave_inspection()
	_eq_work_part(idx, true)

func _eq_assemble() -> void:
	_eq_leave_inspection()
	mg_assembly_parts = []
	var mats: Array = []
	for pt in eq_parts:
		mg_assembly_parts.append(String(pt["name"]))
		mats.append(ItemData.material(int(pt["mat"])))
	start_forge_minigames(["assembly"], mats, func(sc: Dictionary):
		eq_final_scores = _combine_part_scores(float(sc.get("assembly", 0.0)))
		eq_known_before = ItemData.FORGED.keys()
		eq_awaiting_result = true
		eq_final_cb.call(eq_final_scores)
	)

## Notas globais: média de cada etapa entre as peças (as não metálicas entram só na Modelagem).
func _combine_part_scores(assembly: float) -> Dictionary:
	var sums := {"melt": 0.0, "mold": 0.0, "prep": 0.0, "shape": 0.0, "temper": 0.0}
	var counts := {"melt": 0, "mold": 0, "prep": 0, "shape": 0, "temper": 0}
	for pt in eq_parts:
		for k in sums:
			if (pt["scores"] as Dictionary).has(k):
				sums[k] += float(pt["scores"][k])
				counts[k] += 1
	var out := {"fusion": 0.0, "assembly": assembly}
	for k in sums:
		out[k] = sums[k] / counts[k] if int(counts[k]) > 0 else float(sums["shape"]) / maxi(1, int(counts["shape"]))
	return out

## Nota de Criação (mesma fórmula do servidor) com Maestria, Força e Destreza.
func _client_craft_quality(sc: Dictionary) -> float:
	var stats := {}
	var world := get_parent()
	if world and world.get("inventory_ui"):
		stats = world.inventory_ui.stat_totals
	var base: float = float(sc.get("melt", 0.0)) * 0.14 + float(sc.get("mold", 0.0)) * 0.12 + float(sc.get("prep", 0.0)) * 0.14 + \
		float(sc.get("shape", 0.0)) * 0.18 + float(sc.get("temper", 0.0)) * 0.18 + float(sc.get("assembly", 0.0)) * 0.24
	var raw: float = int(stats.get("mas", 0)) * 0.005 + (int(stats.get("str", 0)) + int(stats.get("dex", 0))) * 0.002
	# A experiência compensa erros, mas não passa da perfeição (mesma regra do servidor)
	return minf(1.2, base + raw * maxf(0.0, 1.2 - base) / 1.2)

## Quando o servidor devolve a peça nova (0x54), mostra a celebração.
func _check_forge_result() -> void:
	if not eq_awaiting_result:
		return
	for id in ItemData.FORGED:
		if not eq_known_before.has(id) and int(ItemData.FORGED[id]["kind"]) == 2:
			eq_awaiting_result = false
			_show_result(ItemData.FORGED[id])
			return

func _show_result(item: Dictionary) -> void:
	var q := _client_craft_quality(eq_final_scores)
	var tier := "Defeituoso"
	if q >= 1.10:
		tier = "★ Divino"
	elif q >= 0.95:
		tier = "Obra-Prima"
	elif q >= 0.75:
		tier = "Firme"
	elif q >= 0.50:
		tier = "Imperfeito"
	var rar := int(item["rarity"])
	var rar_txt := ItemData.rarity_name(rar)
	if rar > eq_base_rarity:
		rar_txt += "  ⬆ subiu de %s!" % ItemData.rarity_name(eq_base_rarity)
	elif rar < eq_base_rarity:
		rar_txt += "  ⬇ caiu de %s" % ItemData.rarity_name(eq_base_rarity)
	var lines := ["%s" % item["name"],
		"Raridade final: %s" % rar_txt,
		"Qualidade Final Ponderada: %d%%  (%s)" % [int(round(q * 100.0)), tier], "",
		"Derretimento %.2f • Vazamento %.2f • Pureza %.2f • Modelagem %.2f • Têmpera %.2f • Montagem %.2f" % [
			float(eq_final_scores["melt"]), float(eq_final_scores["mold"]), float(eq_final_scores["prep"]),
			float(eq_final_scores["shape"]), float(eq_final_scores["temper"]), float(eq_final_scores["assembly"])], ""]
	if int(item["atk"]) > 0:
		lines.append("⚔ Dano: +%d" % int(item["atk"]))
	if int(item["def"]) > 0:
		lines.append("🛡 Defesa: +%d" % int(item["def"]))
	if int(item["hp"]) > 0:
		lines.append("❤ Vida: +%d" % int(item["hp"]))
	lines.append("🛠 Durabilidade: %d   ⚖ Peso: %.1f kg" % [int(item["durability"]), float(item["weight"])])
	lines.append("Condutividade — Térmica %d%% • Elétrica %d%% • Mágica %d%%" % [int(item["thermal"]), int(item["electric"]), int(item["magic"])])
	mg_layer.visible = true
	mg_canvas.visible = false
	mg_action.visible = false
	if eq_review_box:
		eq_review_box.visible = false
	mg_title.text = "🎉 Forja Concluída!"
	mg_hint.text = "\n".join(lines)
	mg_info.text = ""
	mg_next_btn.visible = true
	mg_next_btn.text = "Fechar"
	for conn in mg_next_btn.pressed.get_connections():
		mg_next_btn.pressed.disconnect(conn["callable"])
	mg_next_btn.pressed.connect(func():
		mg_layer.visible = false
		mg_canvas.visible = true
		for conn2 in mg_next_btn.pressed.get_connections():
			mg_next_btn.pressed.disconnect(conn2["callable"])
		mg_next_btn.pressed.connect(_mg_next)
	)
