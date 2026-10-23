extends CanvasLayer
## Mapa-múndi [M]: todas as zonas abertas lado a lado (gerado por tools/gen_world_map.gd),
## com o nome de cada região e a posição do jogador.

const Data = preload("res://scripts/world/WorldData.gd")
const MAP_PNG := "res://assets/world_map.png"
const MAP_META := "res://assets/world_map.json"

var panel: PanelContainer
var map_rect: TextureRect
var marker: Label
var labels: Array = []
var meta: Dictionary = {}
var is_open := false

func _ready() -> void:
	layer = 110
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.07, 0.94)
	panel.add_theme_stylebox_override("panel", bg)
	panel.visible = false
	add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := Label.new()
	title.text = "🗺️ Mapa de Lunaria — cada quadro é uma região de 600 x 600 m  |  🔵 portais  🔴 covis de criaturas  🟫 estradas  [M] fechar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	vb.add_child(title)
	map_rect = TextureRect.new()
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(map_rect)
	var img := Image.load_from_file(ProjectSettings.globalize_path(MAP_PNG))
	if img:
		map_rect.texture = ImageTexture.create_from_image(img)
	var f := FileAccess.open(MAP_META, FileAccess.READ)
	if f:
		meta = JSON.parse_string(f.get_as_text())
	marker = Label.new()
	marker.text = "📍"
	marker.add_theme_font_size_override("font_size", 22)
	marker.add_theme_color_override("font_outline_color", Color.BLACK)
	marker.add_theme_constant_override("outline_size", 6)
	map_rect.add_child(marker)
	for id in Data.ZONES:
		var l := Label.new()
		l.text = Data.ZONES[id]["name"]
		l.set_meta("zone", id)
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(1, 1, 1))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 5)
		map_rect.add_child(l)
		labels.append(l)

func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open

## Converte (zona, x, z) do mundo em pixel dentro do TextureRect (respeitando o encaixe).
func _to_screen(zone: int, x: float, z: float) -> Vector2:
	if meta.is_empty() or map_rect.texture == null or not Data.ZONES.has(zone):
		return Vector2(-100, -100)
	var tex_size := Vector2(float(meta["w"]), float(meta["h"]))
	var rect := map_rect.size
	var s := minf(rect.x / tex_size.x, rect.y / tex_size.y)
	var off := (rect - tex_size * s) * 0.5
	var px := float(meta["px"])
	var zi: Dictionary = Data.ZONES[zone]
	var tx := (float(zi["col"]) - float(meta["min_col"])) * px + (x + 300.0) / 600.0 * px
	var ty := (float(meta["max_row"]) - float(zi["row"])) * px + (300.0 - z) / 600.0 * px
	return off + Vector2(tx, ty) * s

func update_player(zone: int, pos: Vector3) -> void:
	if not is_open:
		return
	marker.visible = Data.ZONES.has(zone)
	marker.position = _to_screen(zone, pos.x, pos.z) - Vector2(10, 24)
	for l in labels:
		l.position = _to_screen(int(l.get_meta("zone")), -290.0, 290.0)
