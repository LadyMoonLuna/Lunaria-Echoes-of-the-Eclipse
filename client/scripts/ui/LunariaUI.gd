extends RefCounted
## Pele única dos menus, no mesmo estilo do Grimório (inventário): moldura de madeira escura,
## painéis internos pretos chanfrados com borda dourada e botões de madeira.
## Uso: LunariaUI.watch(self) no _ready de qualquer CanvasLayer de menu — estiliza o que já
## existe e tudo que for criado depois (listas reconstruídas a cada abertura).

const COL_WOOD := Color(0.32, 0.22, 0.14)
const COL_WOOD_EDGE := Color(0.18, 0.12, 0.07)
const COL_WOOD_LIGHT := Color(0.45, 0.32, 0.2)
const COL_PANEL := Color(0.05, 0.045, 0.045, 0.97)
const COL_GOLD := Color(0.85, 0.68, 0.32)
const COL_TITLE := Color(0.98, 0.86, 0.55)

static func box(bg: Color, border: Color, width: int = 2, radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

static func frame_style() -> StyleBoxFlat:
	var sb := box(COL_WOOD, COL_WOOD_EDGE, 6, 12, 16)
	sb.shadow_color = Color(0, 0, 0, 0.8)
	sb.shadow_size = 18
	return sb

static func panel_style(accent: Color = COL_GOLD) -> StyleBoxFlat:
	var sb := box(COL_PANEL, accent, 2, 10, 12)
	sb.corner_detail = 1 # cantos chanfrados como no inspetor do inventário
	return sb

static func button_styles(accent: Color) -> Array:
	var normal := box(COL_WOOD.darkened(0.35), accent.lerp(COL_GOLD, 0.35), 1, 6, 8)
	var hover := box(COL_WOOD_LIGHT.darkened(0.1), accent.lightened(0.2), 2, 6, 8)
	var pressed := box(COL_WOOD_EDGE, accent, 2, 6, 8)
	var disabled := box(Color(0.12, 0.1, 0.09, 0.9), Color(0.3, 0.27, 0.24), 1, 6, 8)
	return [normal, hover, pressed, disabled]

## Estiliza a árvore inteira do menu agora e os nós criados depois.
static func watch(menu: Node) -> void:
	skin_tree(menu)
	var tree := menu.get_tree()
	if tree == null:
		return
	tree.node_added.connect(func(added: Node):
		if is_instance_valid(menu) and menu.is_ancestor_of(added):
			_skin_node.call_deferred(added, menu)
	)

static func skin_tree(menu: Node) -> void:
	for n in menu.find_children("*", "Control", true, false):
		_skin_node(n, menu)

static func _is_frame(c: Control, menu: Node) -> bool:
	# A moldura é o primeiro PanelContainer: nenhum outro PanelContainer acima dele no menu
	var p := c.get_parent()
	while p and p != menu:
		if p is PanelContainer:
			return false
		p = p.get_parent()
	return true

static func _skin_node(n: Node, menu: Node) -> void:
	if not is_instance_valid(n) or not (n is Control) or n.has_meta("lunaria_skin"):
		return
	n.set_meta("lunaria_skin", true)
	if n is PanelContainer or n.get_class() == "Panel":
		var old := (n as Control).get_theme_stylebox("panel") as StyleBoxFlat
		var accent := COL_GOLD
		if old and old.border_color.a > 0.2 and old.border_color.s > 0.25:
			accent = old.border_color.lerp(COL_GOLD, 0.5)
		if _is_frame(n, menu):
			(n as Control).add_theme_stylebox_override("panel", frame_style())
		else:
			(n as Control).add_theme_stylebox_override("panel", panel_style(accent))
	elif n is Button and not (n is CheckBox) and not (n is OptionButton and false):
		var b := n as Button
		var old_b := b.get_theme_stylebox("normal") as StyleBoxFlat
		var accent_b := COL_GOLD
		if old_b and old_b.border_color.a > 0.2 and old_b.border_color.s > 0.2:
			accent_b = old_b.border_color
		var st := button_styles(accent_b)
		b.add_theme_stylebox_override("normal", st[0])
		b.add_theme_stylebox_override("hover", st[1])
		b.add_theme_stylebox_override("pressed", st[2])
		b.add_theme_stylebox_override("disabled", st[3])
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if not b.has_theme_color_override("font_color"):
			b.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
		b.add_theme_color_override("font_hover_color", COL_TITLE)
	elif n is LineEdit:
		(n as LineEdit).add_theme_stylebox_override("normal", box(Color(0.85, 0.78, 0.65), COL_WOOD_EDGE, 2, 4, 6))
		(n as LineEdit).add_theme_color_override("font_color", Color(0.2, 0.13, 0.08))
