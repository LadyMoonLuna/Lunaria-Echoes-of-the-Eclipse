extends Node3D
## Vitrine dos modelos 3D de Lunaria (abra scenes/RacePreview.tscn e aperte F6).
##   ←/→  troca o modelo            ↑/↓  troca a categoria (Raças, NPCs, Armas)
##   C    troca a classe (traje + armas) das raças
##   A    toca o próximo clipe de animação      Espaço  liga/desliga a caminhada
##   R    alterna andar/correr      Tab  desfile da categoria
##   Arraste com o mouse para girar · roda do mouse aproxima

const LunariaModel = preload("res://scripts/models/LunariaModel.gd")
const CATEGORIES: Array = [["race", "Raças"], ["npc", "NPCs"], ["mob", "Criaturas"], ["weapon", "Armas"]]
const LINEUP_GAP: float = 1.6

var category: int = 0
var uids: Array = []
var models: Array = []
var index: int = 0
var class_id: int = 1
var clip_names: Array = []
var clip_index: int = -1
var walking: bool = false
var running: bool = false
var lineup: bool = false
var yaw: float = PI
var pitch: float = -0.12
var dragging: bool = false

var camera: Camera3D
var title_label: Label
var lore_label: Label
var status_label: Label


func _ready() -> void:
	_build_environment()
	_build_ui()
	clip_names = LunariaModel.get_clip_names()
	_load_category(0)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b0a14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8c88c8")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
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
	plane.size = Vector2(60, 60)
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
	title_label.add_theme_font_size_override("font_size", 32)
	layer.add_child(title_label)
	lore_label = Label.new()
	lore_label.position = Vector2(24, 70)
	lore_label.size = Vector2(520, 300)
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.add_theme_color_override("font_color", Color("#c9c4e0"))
	layer.add_child(lore_label)
	status_label = Label.new()
	status_label.position = Vector2(24, 640)
	status_label.add_theme_color_override("font_color", Color("#ffd54f"))
	layer.add_child(status_label)
	var help := Label.new()
	help.text = "←/→ modelo · ↑/↓ categoria · C classe · A animação · Espaço andar · R correr · Tab desfile"
	help.position = Vector2(24, 680)
	help.add_theme_color_override("font_color", Color("#6e6889"))
	layer.add_child(help)


func _load_category(c: int) -> void:
	category = wrapi(c, 0, CATEGORIES.size())
	for m in models:
		m.queue_free()
	models.clear()
	uids = LunariaModel.get_uids(CATEGORIES[category][0])
	uids.sort_custom(func(a, b): return LunariaModel.get_info(a)["id"] < LunariaModel.get_info(b)["id"] or (LunariaModel.get_info(a)["id"] == LunariaModel.get_info(b)["id"] and a < b))
	for u in uids:
		var m: LunariaModel = LunariaModel.create(u) as LunariaModel
		if CATEGORIES[category][0] == "race":
			m.set_class(class_id)
		add_child(m)
		models.append(m)
	_select(0)


func _select(i: int) -> void:
	index = wrapi(i, 0, models.size())
	var info := LunariaModel.get_info(uids[index])
	var prefix := "#%d  " % info["id"] if info["kind"] != "weapon" else ""
	title_label.text = "%s%s — %s" % [prefix, info["name"], info["title"]]
	title_label.add_theme_color_override("font_color", info["color"])
	lore_label.text = info["lore"]
	_layout()
	_update_status()


func _update_status() -> void:
	var parts: Array = [CATEGORIES[category][1]]
	if CATEGORIES[category][0] == "race":
		parts.append("Classe %d" % class_id)
	if clip_index >= 0:
		parts.append("Clipe: %s" % clip_names[clip_index])
	parts.append("Correndo" if walking and running else ("Andando" if walking else "Parado"))
	status_label.text = "  ·  ".join(parts)


func _layout() -> void:
	var cols := 7
	for j in models.size():
		var m: Node3D = models[j]
		if lineup:
			m.visible = true
			var row := j / cols
			var col := j % cols
			var count_in_row := mini(cols, models.size() - row * cols)
			var gap: float = LINEUP_GAP * (1.8 if CATEGORIES[category][0] == "mob" else 1.0)
			m.position = Vector3((col - (count_in_row - 1) / 2.0) * gap, 0, row * 2.2 * (1.5 if CATEGORIES[category][0] == "mob" else 1.0))
		else:
			m.visible = j == index
			m.position = Vector3.ZERO
		if CATEGORIES[category][0] == "weapon":
			m.position.y += 0.9


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT: _select(index + 1)
			KEY_LEFT: _select(index - 1)
			KEY_UP: _load_category(category + 1)
			KEY_DOWN: _load_category(category - 1)
			KEY_SPACE:
				walking = not walking
				_update_status()
			KEY_R:
				running = not running
				_update_status()
			KEY_C:
				class_id = wrapi(class_id + 1, 0, 10)
				for m in models:
					if (m as LunariaModel).kind == "race":
						m.set_class(class_id)
				_update_status()
			KEY_A:
				clip_index = wrapi(clip_index + 1, 0, clip_names.size())
				for m in models:
					(m as LunariaModel).stop_override()
					(m as LunariaModel).play(clip_names[clip_index], clip_names[clip_index] == "death_fall")
				_update_status()
			KEY_TAB:
				lineup = not lineup
				_layout()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = maxf(10.0, camera.fov - 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = minf(70.0, camera.fov + 2.0)
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.01
		pitch = clampf(pitch - event.relative.y * 0.005, -0.8, 0.2)


func _process(delta: float) -> void:
	var speed := 0.0
	if walking:
		speed = 7.0 if running else 1.8
	for m in models:
		(m as LunariaModel).set_move_speed(speed)
	if not dragging and not lineup:
		yaw += delta * 0.4
	var is_weapon: bool = CATEGORIES[category][0] == "weapon"
	var dist := (9.0 if is_weapon else 16.0) if lineup else (2.6 if is_weapon else 4.2)
	var target := Vector3(0, 1.1 if is_weapon else 1.0, 1.1 if lineup and models.size() > 7 else 0.0)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	if lineup:
		dir = Vector3(0, 0.3, -1).normalized()
	camera.position = target + dir * dist
	camera.look_at(target, Vector3.UP)
