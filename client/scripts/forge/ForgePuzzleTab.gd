extends HBoxContainer
## Aba [🧩 Criar Equipamento Único (Quebra-Cabeça)] da Forja (Etapa 3): grade 7x7 onde os módulos
## geométricos são encaixados livremente; cada módulo recebe um material (só os já descobertos).
## O registro vai para o servidor (0x55), que confere a patente e forja a Obra-Prima (+20%).

const ItemData = preload("res://scripts/ItemData.gd")
const ForgeData = preload("res://scripts/forge/ForgeData.gd")

const CATEGORY_LABELS := {"lamina": "⚔ Lâmina / Ponta", "guarda": "🛡 Guarda", "nucleo": "💠 Núcleo", "cabo": "🪵 Eixo / Cabo / Conexão", "bainha": "🗡 Bainha"}
const PIECE_COLORS := [Color("#ef5350"), Color("#42a5f5"), Color("#66bb6a"), Color("#ffca28"), Color("#ab47bc"), Color("#26c6da"),
	Color("#ff7043"), Color("#8d6e63"), Color("#d4e157"), Color("#ec407a"), Color("#5c6bc0"), Color("#9ccc65")]

var forge: Node = null # ForgeUI (estoque, materiais conhecidos e fórmula)
var palette: ItemList
var rot := 0
var rot_btn: Button
var cells: Array = [] # 49 botões (índice = y * 7 + x)
var placements: Array = [] # {"module": id, "x", "y", "rot", "material"}
var selected_piece := -1
var pieces_box: VBoxContainer
var status_lbl: RichTextLabel
var preview: RichTextLabel
var name_edit: LineEdit
var register_btn: Button
var exclusive_pick: OptionButton
var lock_lbl: Label
var hint_lbl: Label

func _init() -> void:
	name = "🧩 Criar Equipamento Único (Quebra-Cabeça)"
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	_build()
	NetworkManager.puzzle_state_received.connect(func(_unlocked: bool, _list: Array): refresh())

func _module(id: int) -> Dictionary:
	for m in ForgeData.PUZZLE_MODULES:
		if int(m["id"]) == id:
			return m
	return {}

## Células do módulo girado (mesma regra do servidor: 90° por passo, normalizado em 0,0).
static func rotated_cells(m: Dictionary, r: int) -> Array:
	var out: Array = []
	var min_x := 99
	var min_y := 99
	for c in m["cells"]:
		var x: int = int(c[0])
		var y: int = int(c[1])
		for k in range(r % 4):
			var t := x
			x = -y
			y = t
		out.append(Vector2i(x, y))
		min_x = mini(min_x, x)
		min_y = mini(min_y, y)
	for i in range(out.size()):
		out[i] -= Vector2i(min_x, min_y)
	return out

func _lbl(text: String, size: int = 12, col: Color = Color(0.92, 0.88, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _build() -> void:
	# Catálogo de módulos
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(210, 0)
	add_child(left)
	left.add_child(_lbl("Módulos (escolha e clique na grade)", 12, Color(1.0, 0.85, 0.5)))
	palette = ItemList.new()
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ForgeData.PUZZLE_MODULES:
		palette.add_item("%s — %s (%d)" % [CATEGORY_LABELS.get(m["category"], "").split(" ")[0], m["name"], (m["cells"] as Array).size()])
		palette.set_item_metadata(palette.item_count - 1, int(m["id"]))
		palette.set_item_tooltip(palette.item_count - 1, "%s\nAceita: %s" % [CATEGORY_LABELS.get(m["category"], ""), _tag_text(m["tags"])])
	palette.select(0)
	left.add_child(palette)
	rot_btn = Button.new()
	rot_btn.text = "↻ Girar peça (0°)"
	rot_btn.pressed.connect(func():
		rot = (rot + 1) % 4
		rot_btn.text = "↻ Girar peça (%d°)" % (rot * 90)
	)
	left.add_child(rot_btn)
	var clear_btn := Button.new()
	clear_btn.text = "🧹 Limpar grade"
	clear_btn.pressed.connect(func():
		placements.clear()
		selected_piece = -1
		_redraw()
	)
	left.add_child(clear_btn)
	left.add_child(_lbl("📘 Minhas Blueprints Exclusivas", 12, Color(0.6, 0.8, 1.0)))
	exclusive_pick = OptionButton.new()
	left.add_child(exclusive_pick)
	var load_btn := Button.new()
	load_btn.text = "Carregar desenho"
	load_btn.pressed.connect(_load_exclusive)
	left.add_child(load_btn)

	# Grade 7x7
	var mid := VBoxContainer.new()
	add_child(mid)
	lock_lbl = _lbl("", 13, Color(1.0, 0.45, 0.4))
	lock_lbl.custom_minimum_size = Vector2(350, 0)
	mid.add_child(lock_lbl)
	var grid := GridContainer.new()
	grid.columns = ForgeData.PUZZLE_GRID
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	mid.add_child(grid)
	for i in range(ForgeData.PUZZLE_GRID * ForgeData.PUZZLE_GRID):
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.focus_mode = Control.FOCUS_NONE
		var cell_idx := i
		b.pressed.connect(func(): _on_cell(cell_idx))
		grid.add_child(b)
		cells.append(b)
	hint_lbl = _lbl("Clique numa célula vazia para encaixar o módulo (o canto de cima à esquerda fica na célula). Clique numa peça para selecioná-la.", 11, Color(0.75, 0.72, 0.65))
	hint_lbl.custom_minimum_size = Vector2(350, 0)
	mid.add_child(hint_lbl)
	status_lbl = RichTextLabel.new()
	status_lbl.bbcode_enabled = true
	status_lbl.fit_content = true
	status_lbl.custom_minimum_size = Vector2(350, 0)
	mid.add_child(status_lbl)

	# Peças, materiais, prévia e registro
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	right.add_child(_lbl("Material de cada peça (só os que você já viu)", 12, Color(1.0, 0.85, 0.5)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	pieces_box = VBoxContainer.new()
	pieces_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pieces_box)
	preview = RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.custom_minimum_size = Vector2(0, 150)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nome da Arma (ex.: Eclipse Cortante)"
	name_edit.max_length = ForgeData.PUZZLE_MAX_NAME
	name_edit.text_changed.connect(func(_t: String): _update_preview())
	right.add_child(name_edit)
	register_btn = Button.new()
	register_btn.text = "📜 Registrar Blueprint & Forjar Obra-Prima"
	register_btn.custom_minimum_size = Vector2(0, 42)
	register_btn.pressed.connect(_on_register)
	right.add_child(register_btn)

func _tag_text(tags: Array) -> String:
	var names: Array = []
	for t in tags:
		names.append(ForgeData.TAG_NAMES.get(t, t))
	return ", ".join(names)

# ---------------------------------------------------------------------------
# Grade
# ---------------------------------------------------------------------------

func _occupancy() -> Array:
	var occ: Array = []
	occ.resize(ForgeData.PUZZLE_GRID * ForgeData.PUZZLE_GRID)
	occ.fill(-1)
	for pi in range(placements.size()):
		var p: Dictionary = placements[pi]
		for c in rotated_cells(_module(int(p["module"])), int(p["rot"])):
			var x: int = int(p["x"]) + c.x
			var y: int = int(p["y"]) + c.y
			if x >= 0 and y >= 0 and x < ForgeData.PUZZLE_GRID and y < ForgeData.PUZZLE_GRID:
				occ[y * ForgeData.PUZZLE_GRID + x] = pi
	return occ

func _on_cell(idx: int) -> void:
	if not NetworkManager.puzzle_unlocked:
		return
	var occ := _occupancy()
	if int(occ[idx]) >= 0:
		selected_piece = int(occ[idx])
		_redraw()
		return
	if palette.get_selected_items().is_empty() or placements.size() >= ForgeData.PUZZLE_MAX_PIECES:
		return
	var mid: int = int(palette.get_item_metadata(palette.get_selected_items()[0]))
	var ax: int = idx % ForgeData.PUZZLE_GRID
	var ay: int = idx / ForgeData.PUZZLE_GRID
	for c in rotated_cells(_module(mid), rot):
		var x: int = ax + c.x
		var y: int = ay + c.y
		if x >= ForgeData.PUZZLE_GRID or y >= ForgeData.PUZZLE_GRID or int(occ[y * ForgeData.PUZZLE_GRID + x]) >= 0:
			hint_lbl.text = "⚠️ Essa peça não cabe aí (sai da grade ou cobre outra peça). Tente girar ou outra célula."
			return
	placements.append({"module": mid, "x": ax, "y": ay, "rot": rot, "material": 0})
	selected_piece = placements.size() - 1
	hint_lbl.text = "Peça encaixada. Escolha o material dela à direita."
	_redraw()

func _redraw() -> void:
	var occ := _occupancy()
	for i in range(cells.size()):
		var b: Button = cells[i]
		var pi: int = int(occ[i])
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(4)
		if pi < 0:
			st.bg_color = Color(0.12, 0.1, 0.09)
			st.border_color = Color(0.35, 0.28, 0.2)
			b.text = ""
		else:
			var col: Color = PIECE_COLORS[pi % PIECE_COLORS.size()]
			st.bg_color = col.darkened(0.35) if int(placements[pi]["material"]) > 0 else col.darkened(0.7)
			st.border_color = Color.WHITE if pi == selected_piece else col
			b.text = str(pi + 1)
		st.set_border_width_all(2 if pi == selected_piece and pi >= 0 else 1)
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, st)
	_rebuild_piece_rows()
	_update_preview()

func _rebuild_piece_rows() -> void:
	for c in pieces_box.get_children():
		c.queue_free()
	var bag: Dictionary = forge._bag()
	for pi in range(placements.size()):
		var p: Dictionary = placements[pi]
		var m := _module(int(p["module"]))
		var row := HBoxContainer.new()
		pieces_box.add_child(row)
		var tag := _lbl("%d. %s" % [pi + 1, m["name"]], 12, PIECE_COLORS[pi % PIECE_COLORS.size()].lightened(0.3))
		tag.custom_minimum_size = Vector2(170, 0)
		row.add_child(tag)
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_item("— escolha o material —")
		ob.set_item_metadata(0, 0)
		var part := {"tags": m["tags"]}
		var cands: Array = []
		for mid in ItemData.MATERIALS.keys() + ItemData.FORGED.keys():
			if forge._known(int(mid)) and forge._accepts(part, int(mid)) and not cands.has(int(mid)):
				cands.append(int(mid))
		cands.sort_custom(func(a: int, b: int): return int(bag.get(a, 0)) > int(bag.get(b, 0)) or (int(bag.get(a, 0)) == int(bag.get(b, 0)) and a < b))
		for mid in cands:
			ob.add_item("%s (x%d)" % [ItemData.material(mid)["name"], int(bag.get(mid, 0))])
			ob.set_item_metadata(ob.item_count - 1, mid)
			if mid == int(p["material"]):
				ob.select(ob.item_count - 1)
		var piece_idx := pi
		ob.item_selected.connect(func(sel: int):
			var meta = ob.get_item_metadata(sel)
			placements[piece_idx]["material"] = int(meta) if meta != null else 0
			_redraw()
		)
		row.add_child(ob)
		var del := Button.new()
		del.text = "✖"
		del.pressed.connect(func():
			placements.remove_at(piece_idx)
			selected_piece = -1
			_redraw()
		)
		row.add_child(del)

# ---------------------------------------------------------------------------
# Validação, prévia e registro
# ---------------------------------------------------------------------------

## Mesmas checagens do servidor (ValidatePuzzle): componentes obrigatórios e peças encaixadas.
func _validation() -> Array:
	var problems: Array = []
	var has := {}
	var grip := false
	for p in placements:
		var m := _module(int(p["module"]))
		has[m["category"]] = true
		if ForgeData.PUZZLE_GRIP_MODULES.has(int(p["module"])):
			grip = true
		if int(p["material"]) == 0:
			problems.append("Falta o material de %s" % m["name"])
	if not has.has("lamina"):
		problems.append("Falta a Lâmina / Cabeça de impacto")
	if not has.has("guarda"):
		problems.append("Falta a Guarda")
	if not grip:
		problems.append("Falta o Cabo")
	if not has.has("bainha"):
		problems.append("Falta a Bainha")
	if placements.size() > 1 and not _connected():
		problems.append("Todas as peças precisam estar encaixadas umas nas outras")
	return problems

func _connected() -> bool:
	var occ := _occupancy()
	var g: int = ForgeData.PUZZLE_GRID
	var start := -1
	for i in range(occ.size()):
		if int(occ[i]) >= 0:
			start = i
			break
	if start < 0:
		return true
	var seen := {}
	var pieces := {}
	var stack: Array = [start]
	while not stack.is_empty():
		var c: int = stack.pop_back()
		if seen.has(c):
			continue
		seen[c] = true
		pieces[int(occ[c])] = true
		var cx: int = c % g
		var cy: int = c / g
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx >= 0 and ny >= 0 and nx < g and ny < g and int(occ[ny * g + nx]) >= 0 and not seen.has(ny * g + nx):
				stack.append(ny * g + nx)
	return pieces.size() == placements.size()

func _bp_dict() -> Dictionary:
	var total := 0
	for p in placements:
		total += (_module(int(p["module"]))["cells"] as Array).size()
	var parts: Array = []
	for p in placements:
		var m := _module(int(p["module"]))
		parts.append({"name": m["name"], "tags": m["tags"], "role": m["role"], "share": float((m["cells"] as Array).size()) / float(maxi(total, 1)), "optional": false})
	return {"id": 0, "name": name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Arma Autoral", "kind": 1, "slot": 12, "tool": 0,
		"base_atk": ForgeData.PUZZLE_BASE_ATK, "base_def": 0, "mass_scale": total * ForgeData.PUZZLE_MASS_PER_CELL,
		"dur_scale": ForgeData.PUZZLE_DUR_SCALE, "parts": parts}

func _update_preview() -> void:
	var problems := _validation()
	var lines: Array = []
	for pr in problems:
		lines.append("[color=#ef5350]✘ %s[/color]" % pr)
	if problems.is_empty() and not placements.is_empty():
		lines.append("[color=#73e673]✔ Formato completo: Lâmina, Guarda, Cabo e Bainha encaixados.[/color]")
	status_lbl.text = "\n".join(lines)
	register_btn.disabled = not problems.is_empty() or placements.is_empty() or name_edit.text.strip_edges() == "" or not NetworkManager.puzzle_unlocked
	if placements.is_empty():
		preview.text = "[color=#ffd54f]Prévia da Obra-Prima[/color]\nMonte o formato da arma na grade."
		return
	var picks: Array = []
	for p in placements:
		picks.append(int(p["material"]))
	var bp := _bp_dict()
	var st: Dictionary = forge._compute(bp, picks)
	var bonus: float = ForgeData.MASTERPIECE_BONUS
	var atk := int(float(st["atk"]) * bonus + 0.5)
	var dur := mini(9999, int(float(st["durability"]) * bonus + 0.5))
	var out := ["[color=#ffd54f]Prévia da Obra-Prima[/color] — [color=#ffb74d]+20% de Obra-Prima Autoral[/color]"]
	out.append("[color=%s][b]%s[/b][/color]  (%s)" % [ItemData.rarity_color(int(st["rarity"])).to_html(false), bp["name"], ItemData.rarity_name(int(st["rarity"]))])
	out.append("⚔ Dano: [color=#73e673]+%d[/color]   🛠 Durabilidade: %d   ⚖ Peso: %.1f kg" % [atk, dur, float(st["weight"])])
	out.append("Condutividade — Térmica %d%% • Elétrica %d%% • Mágica %d%%" % [int(st["thermal"]), int(st["electric"]), int(st["magic"])])
	if not (st["resist"] as Array).is_empty():
		out.append("Resistências: [color=#73e673]%s[/color]" % ", ".join(st["resist"]))
	if not (st["specials"] as Array).is_empty():
		out.append("Características: [color=#ffb74d]%s[/color]" % " • ".join(st["specials"]))
	out.append("[i]%s[/i]" % " + ".join(st["parts"]))
	preview.text = "\n".join(out)

func _on_register() -> void:
	if not _validation().is_empty() or name_edit.text.strip_edges() == "":
		return
	var pieces: Array = []
	for p in placements:
		pieces.append([int(p["module"]), int(p["x"]), int(p["y"]), int(p["rot"]), int(p["material"])])
	var weapon_name := name_edit.text.strip_edges()
	if forge.quick_forge.button_pressed:
		NetworkManager.send_register_custom_weapon(weapon_name, pieces)
		return
	var picks: Array = []
	for p in placements:
		picks.append(int(p["material"]))
	var parts: Array = []
	for i in range(placements.size()):
		parts.append({"index": i, "module": int(placements[i]["module"]), "name": String(_module(int(placements[i]["module"]))["name"]), "mat": int(placements[i]["material"])})
	var base: Dictionary = forge._compute(_bp_dict(), picks)
	# Quebra-Cabeça: cada peça é confirmada no servidor (0x5D) e a obra-prima sai no 0x55
	forge.start_equipment_forge(parts, 0, int(base["rarity"]), func(sc: Dictionary):
		NetworkManager.send_register_custom_weapon_scored(weapon_name, pieces, forge._score_list(sc))
	)

func _load_exclusive() -> void:
	if exclusive_pick.selected < 0 or exclusive_pick.item_count == 0:
		return
	var e: Dictionary = NetworkManager.exclusive_blueprints[exclusive_pick.selected]
	placements.clear()
	for pc in e["pieces"]:
		placements.append({"module": int(pc[0]), "x": int(pc[1]), "y": int(pc[2]), "rot": int(pc[3]), "material": int(pc[4])})
	name_edit.text = String(e["name"])
	selected_piece = -1
	_redraw()

## Chamado pela ForgeUI quando abre ou quando chegam estado/inventário novos.
func refresh() -> void:
	var unlocked: bool = NetworkManager.puzzle_unlocked
	lock_lbl.text = "" if unlocked else "🔒 Exclusivo para Ferreiros Avançados, Únicos ou Lendários: Artesão Overgeared, Forjador Carmesim (17), Runomante Ancestral (22) ou Herdeiro da Forja Divina (31)."
	palette.mouse_filter = Control.MOUSE_FILTER_STOP if unlocked else Control.MOUSE_FILTER_IGNORE
	exclusive_pick.clear()
	for e in NetworkManager.exclusive_blueprints:
		exclusive_pick.add_item("📘 " + String(e["name"]))
	_redraw()
