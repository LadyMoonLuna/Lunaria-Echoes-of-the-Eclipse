extends Node3D
## Vitrine das raças com modelo 3D (abra scenes/RacePreview.tscn e aperte F6).
## Setas ←/→ trocam a raça · Espaço liga/desliga a caminhada ·
## Tab alterna entre vitrine individual e desfile · arraste com o mouse para girar.

const RaceModel = preload("res://scripts/models/RaceModel.gd")
const LINEUP_GAP: float = 1.6

var ids: Array = []
var models: Array = []
var index: int = 0
var walking: bool = false
var lineup: bool = false
var yaw: float = PI
var pitch: float = -0.12
var dragging: bool = false

var camera: Camera3D
var title_label: Label
var lore_label: Label


func _ready() -> void:
	_build_environment()
	ids = RaceModel.get_model_ids()
	for id in ids:
		var m: RaceModel = RaceModel.create(id) as RaceModel
		add_child(m)
		models.append(m)
	_build_ui()
	_select(0)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b0a14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8c88c8")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#dcd8ff")
	moon.light_energy = 1.2
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-50, 150, 0)
	add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#fff1e0")
	fill.light_energy = 0.6
	fill.rotation_degrees = Vector3(-25, 15, 0)
	add_child(fill)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#15131f")
	fm.roughness = 0.95
	floor_mesh.material_override = fm
	add_child(floor_mesh)

	camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title_label = Label.new()
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_size_override("font_size", 34)
	layer.add_child(title_label)
	lore_label = Label.new()
	lore_label.position = Vector2(24, 76)
	lore_label.size = Vector2(520, 300)
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.add_theme_color_override("font_color", Color("#c9c4e0"))
	layer.add_child(lore_label)
	var help := Label.new()
	help.text = "←/→ raça · Espaço andar · Tab desfile · arraste para girar · roda do mouse aproxima"
	help.position = Vector2(24, 680)
	help.add_theme_color_override("font_color", Color("#6e6889"))
	layer.add_child(help)


func _select(i: int) -> void:
	index = wrapi(i, 0, models.size())
	var info := RaceModel.get_info(ids[index])
	title_label.text = "#%d  %s — %s" % [info["id"], info["name"], info["title"]]
	title_label.add_theme_color_override("font_color", info["color"])
	lore_label.text = info["lore"]
	_layout()


func _layout() -> void:
	for j in models.size():
		var m: RaceModel = models[j]
		if lineup:
			m.visible = true
			m.position = Vector3((j - (models.size() - 1) / 2.0) * LINEUP_GAP, 0, -0.4 if j == index else 0.0)
			m.rotation.y = 0.0
		else:
			m.visible = j == index
			m.position = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT: _select(index + 1)
			KEY_LEFT: _select(index - 1)
			KEY_SPACE: walking = not walking
			KEY_TAB:
				lineup = not lineup
				_layout()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = maxf(15.0, camera.fov - 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = minf(70.0, camera.fov + 2.0)
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.01
		pitch = clampf(pitch - event.relative.y * 0.005, -0.8, 0.2)


func _process(delta: float) -> void:
	for m in models:
		(m as RaceModel).set_move_speed(5.0 if walking else 0.0)
	if not dragging and not lineup:
		yaw += delta * 0.4
	var dist := 14.0 if lineup else 4.2
	var target := Vector3(0, 1.0, 0)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	if lineup:
		dir = Vector3(0, 0.18, -1).normalized()
	camera.position = target + dir * dist
	camera.look_at(target, Vector3.UP)
