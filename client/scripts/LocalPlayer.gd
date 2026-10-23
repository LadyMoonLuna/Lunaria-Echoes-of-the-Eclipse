extends CharacterBody3D

signal identity_changed(race_id: int, class_id: int)
signal action_triggered(action_type: int)

const SPEED: float = 8.0
const DODGE_SPEED: float = 18.0
const JUMP_VELOCITY: float = 6.0
const MOUSE_SENSITIVITY: float = 0.003
const NETWORK_TICK_INTERVAL: float = 0.05 # 20 Hz (a cada 50ms)

const ClassPaths = preload("res://scripts/ClassPaths.gd")
var current_class_tier: int = 0
var current_sub_path: int = 0 # Caminho Evolutivo (1 a 4) — muda a velocidade de movimento

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var network_timer: float = 0.0

var current_race_id: int = 1   # 1=Valeriano, 2=Noctari, 3=Kharad, 4=Varkai, 5=Sangrael
var current_class_id: int = 1  # 1..15

var is_attacking: bool = false
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var attack_cooldown: float = 0.0
var is_menu_open: bool = false

# Peso carregado (atualizado pelo 0x38 via World.gd) e penalidade de velocidade
var current_weight: float = 0.0
var max_weight: float = 75.0
var weight_speed_mult: float = 1.0
var skill_slot_bindings: Dictionary = {
	"LMB": 1,
	"Q": 3,
	"R": 4,
	"F": 5,
	"Z": 6
}

var homunculus_orbiter: Node3D = null
var homunculus_anim_time: float = 0.0
var spirit_wolf_companion: Node3D = null
var spirit_wolf_anim_time: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var visor_mesh: MeshInstance3D = $BodyMesh/VisorIndicator
@onready var weapon_pivot: Node3D = $BodyMesh/WeaponPivot
@onready var weapon_mesh: Node3D = $BodyMesh/WeaponPivot/WeaponMesh
@onready var NetworkManager: Node = get_node_or_null("/root/NetworkManager")

var offhand_pivot: Node3D = null
var crosshair_layer: CanvasLayer = null

var default_weapon_rot: Vector3 = Vector3.ZERO
var default_weapon_pos: Vector3 = Vector3.ZERO
var default_weapon_scale: Vector3 = Vector3.ONE

const LunariaModel = preload("res://scripts/models/LunariaModel.gd")
var race_model: LunariaModel = null
var _capsule_mesh: Mesh = null

func _ready() -> void:
	for action_name in ["skill_racial", "skill_1", "skill_2", "skill_3", "dodge", "interact"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	_ensure_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	load_skill_keybinds()
	camera_pivot.top_level = true
	camera_pivot.global_position = global_position + Vector3(0, 1.5, 0)

	if weapon_pivot:
		default_weapon_rot = weapon_pivot.rotation
		default_weapon_pos = weapon_pivot.position
		default_weapon_scale = weapon_pivot.scale

	if not has_node("BodyMesh/OffhandPivot"):
		offhand_pivot = Node3D.new()
		offhand_pivot.name = "OffhandPivot"
		offhand_pivot.position = Vector3(-0.38, 0.1, -0.2)
		body_mesh.add_child(offhand_pivot)
	else:
		offhand_pivot = $BodyMesh/OffhandPivot

	if NetworkManager:
		NetworkManager.player_respawned.connect(_on_player_respawned)

	_setup_crosshair()
	_apply_race_visuals()
	_apply_class_visuals()

func _ensure_input_actions() -> void:
	var required_actions := {
		"attack_basic": MOUSE_BUTTON_LEFT,
		"dodge_roll": KEY_SHIFT,
		"dodge": KEY_SHIFT,
		"skill_1": KEY_Q,
		"skill_2": KEY_R,
		"skill_3": KEY_F,
		"skill_racial": KEY_Z,
		"interact": KEY_E,
		"ui_cancel": KEY_ESCAPE,
		"jump": KEY_SPACE,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_forward": KEY_W,
		"move_back": KEY_S
	}
	for action_name in required_actions.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key_val = required_actions[action_name]
			if key_val == MOUSE_BUTTON_LEFT:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT
				InputMap.action_add_event(action_name, mb)
			else:
				var k := InputEventKey.new()
				k.physical_keycode = key_val
				InputMap.action_add_event(action_name, k)

func _on_player_respawned(pid: int, px: float, py: float, pz: float) -> void:
	if NetworkManager and pid == NetworkManager.my_player_id:
		global_position = Vector3(px, py, pz)
		velocity = Vector3.ZERO
		is_attacking = false
		is_dodging = false
		attack_cooldown = 0.0

func _setup_crosshair() -> void:
	crosshair_layer = CanvasLayer.new()
	crosshair_layer.name = "CrosshairLayer"
	crosshair_layer.layer = 12
	add_child(crosshair_layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_layer.add_child(center)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.name = "CrosshairLabel"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 20)
	crosshair.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	crosshair.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	crosshair.add_theme_constant_override("shadow_offset_x", 1)
	crosshair.add_theme_constant_override("shadow_offset_y", 1)
	center.add_child(crosshair)

func _process(_delta: float) -> void:
	if crosshair_layer:
		crosshair_layer.visible = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_menu_open)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9 or event.keycode == KEY_F10:
			var world = get_parent()
			if world and world.has_method("_toggle_dev_manager"):
				world._toggle_dev_manager()
				get_viewport().set_input_as_handled()
				return

	if is_menu_open:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-70.0), deg_to_rad(55.0))

	if (InputMap.has_action("ui_cancel") and event.is_action_pressed("ui_cancel")) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Action Combat Inputs (quando o cursor está capturado e menu fechado)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if (InputMap.has_action("attack_basic") and event.is_action_pressed("attack_basic")) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			trigger_action_by_id(skill_slot_bindings.get("LMB", 1))
		elif (InputMap.has_action("dodge_roll") and event.is_action_pressed("dodge_roll")) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT):
			_perform_dodge_roll()
		elif (InputMap.has_action("skill_1") and event.is_action_pressed("skill_1")) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q):
			trigger_action_by_id(skill_slot_bindings.get("Q", 3))
		elif (InputMap.has_action("skill_2") and event.is_action_pressed("skill_2")) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R):
			trigger_action_by_id(skill_slot_bindings.get("R", 4))
		elif (InputMap.has_action("skill_3") and event.is_action_pressed("skill_3")) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F):
			trigger_action_by_id(skill_slot_bindings.get("F", 5))
		elif (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Z or event.physical_keycode == KEY_Z)) or (InputMap.has_action("skill_racial") and event.is_action_pressed("skill_racial")):
			trigger_action_by_id(skill_slot_bindings.get("Z", 6))


func _get_aim_direction() -> Vector3:
	if camera:
		var cam_forward: Vector3 = -camera.global_transform.basis.z
		var flat_dir := Vector3(cam_forward.x, 0.0, cam_forward.z).normalized()
		if flat_dir.length_squared() > 0.001:
			return flat_dir
	var cam_yaw: float = camera_pivot.global_rotation.y
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw)).normalized()

func _get_class_color() -> Color:
	match current_class_id:
		1: return Color("#64b5f6") # Espadachim da Aurora: Azul Aço
		2: return Color("#00e5ff") # Arcanista: Ciano Arcano
		3: return Color("#69f0ae") # Sentinela dos Ventos: Verde Falcão
		4: return Color("#7c4dff") # Lâmina Silente: Violeta Sombrio
		5: return Color("#ffab40") # Punho Celeste: Laranja Chi
		6: return Color("#ffd54f") # Guardião do Bastião: Dourado Bastião
		7: return Color("#ff6d00") # Forjador de Estrelas: Brasa da Forja
		8: return Color("#00e676") # Transmutador: Verde Ácido
		9: return Color("#e1f5fe") # Escultor de Almas: Prata do Luar
		10: return Color("#a1887f") # Senhor das Feras: Castanho Bestial
		11: return Color("#ff1744") # Tecelão Carmesim: Carmesim dos Fios
		12: return Color("#ff7043") # Mestre do Banquete: Chama da Wok
		13: return Color("#40c4ff") # Lâmina Rúnica
		14: return Color("#eceff1") # Inquisidor de Prata
		15: return Color("#fff59d") # Valquíria Celeste
		16: return Color("#4a148c") # Punho Fantasma
		17: return Color("#b71c1c") # Forjador Carmesim
		18: return Color("#558b2f") # Doutor Corvo
		27: return Color("#d500f9") # Ceifador da Lua Negra
		35: return Color("#ffb300") # Engenheiro Rúnico
		36: return Color("#ea80fc") # Demiurgo Alquímico
		28: return Color("#00e5ff") # Bailarino das Estrelas
		29: return Color("#ff1744") # Inquisidor da Chama Branca
		30: return Color("#00e676") # Arauto do Ossuário
		37: return Color("#80d8ff") # Senhor da Selva Primordial
		38: return Color("#7c4dff") # Cavaleiro do Vazio
		39: return Color("#00b0ff") # Arauto do Trovão
		_: return Color("#ffffff")

func _spawn_skill_q_flash() -> void:
	var col: Color = _get_class_color()
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = mat
	var forward := -global_transform.basis.z.normalized()
	flash.global_position = global_position + forward * 1.5 + Vector3(0, 1.1, 0)
	if get_parent():
		get_parent().add_child(flash)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 4.0
	light.omni_range = 4.5
	flash.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(2.5, 2.5, 2.5), 0.3)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(light, "light_energy", 0.0, 0.3)
	tw.chain().tween_callback(flash.queue_free)

func _spawn_skill_r_aura() -> void:
	var col: Color = _get_class_color()
	var aura := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.75
	aura.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.material_override = mat
	aura.global_position = global_position + Vector3(0, 0.35, 0)
	if get_parent():
		get_parent().add_child(aura)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 5.0
	light.omni_range = 6.5
	aura.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(aura, "scale", Vector3(6.5, 1.0, 6.5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_property(light, "light_energy", 0.0, 0.5)
	tw.chain().tween_callback(aura.queue_free)

func _spawn_skill_f_impact() -> void:
	var col: Color = _get_class_color()
	var tw_rot := create_tween()
	tw_rot.tween_property(self, "rotation:y", rotation.y + deg_to_rad(360.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var shockwave := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 0.08
	shockwave.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 5.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = mat
	shockwave.global_position = global_position + Vector3(0, 0.08, 0)
	if get_parent():
		get_parent().add_child(shockwave)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 6.5
	light.omni_range = 8.5
	shockwave.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(shockwave, "scale", Vector3(8.5, 1.0, 8.5), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.tween_property(light, "light_energy", 0.0, 0.55)
	tw.chain().tween_callback(shockwave.queue_free)

func load_skill_keybinds() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://skill_keybinds.cfg")
	if err == OK:
		skill_slot_bindings["LMB"] = cfg.get_value("Keybinds", "LMB", 1)
		skill_slot_bindings["Q"] = cfg.get_value("Keybinds", "Q", 3)
		skill_slot_bindings["R"] = cfg.get_value("Keybinds", "R", 4)
		skill_slot_bindings["F"] = cfg.get_value("Keybinds", "F", 5)
		skill_slot_bindings["Z"] = cfg.get_value("Keybinds", "Z", 6)

func apply_skill_keybinds(new_bindings: Dictionary) -> void:
	for k in new_bindings.keys():
		skill_slot_bindings[k] = new_bindings[k]
	var cfg := ConfigFile.new()
	for k in skill_slot_bindings.keys():
		cfg.set_value("Keybinds", k, skill_slot_bindings[k])
	cfg.save("user://skill_keybinds.cfg")

func trigger_action_by_id(action_id: int) -> void:
	match action_id:
		1: _perform_basic_attack()
		2: _perform_dodge_roll()
		3: _perform_special_skill()
		4: _perform_skill_r()
		5: _perform_skill_f()
		6: _perform_racial_skill()
		_: _perform_basic_attack()

func _perform_basic_attack() -> void:
	if is_menu_open or is_attacking or is_dodging or attack_cooldown > 0.0:
		return

	is_attacking = true
	attack_cooldown = 0.35

	var aim_dir := _get_aim_direction()
	var target_yaw := atan2(-aim_dir.x, -aim_dir.z)
	rotation.y = target_yaw

	action_triggered.emit(1)

	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_player_action(1, aim_dir)

	_animate_attack_visual(1)

func _perform_special_skill() -> void:
	if is_menu_open or is_attacking or is_dodging or attack_cooldown > 0.0:
		return

	is_attacking = true
	attack_cooldown = 0.65

	var aim_dir := _get_aim_direction()
	var target_yaw := atan2(-aim_dir.x, -aim_dir.z)
	rotation.y = target_yaw

	action_triggered.emit(3)

	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_player_action(3, aim_dir)

	_spawn_skill_q_flash()
	_animate_attack_visual(3)

func _perform_skill_r() -> void:
	if is_menu_open or is_attacking or is_dodging or attack_cooldown > 0.0:
		return

	is_attacking = true
	attack_cooldown = 0.5

	var aim_dir := _get_aim_direction()
	var target_yaw := atan2(-aim_dir.x, -aim_dir.z)
	rotation.y = target_yaw

	action_triggered.emit(4)

	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_player_action(4, aim_dir)

	_spawn_skill_r_aura()
	_animate_attack_visual(4)

func _perform_skill_f() -> void:
	if is_menu_open or is_attacking or is_dodging or attack_cooldown > 0.0:
		return

	is_attacking = true
	attack_cooldown = 0.65

	var aim_dir := _get_aim_direction()
	var target_yaw := atan2(-aim_dir.x, -aim_dir.z)
	rotation.y = target_yaw

	action_triggered.emit(5)

	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_player_action(5, aim_dir)

	_spawn_skill_f_impact()
	_animate_attack_visual(5)

func _perform_racial_skill() -> void:
	if is_menu_open or is_attacking or is_dodging or attack_cooldown > 0.0:
		return

	is_attacking = true
	attack_cooldown = 0.65

	var aim_dir := _get_aim_direction()
	var target_yaw := atan2(-aim_dir.x, -aim_dir.z)
	rotation.y = target_yaw

	action_triggered.emit(6)

	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_player_action(6, aim_dir)

	_spawn_racial_aura_burst()
	_animate_racial_skill_visual()

func _get_race_color() -> Color:
	match current_race_id:
		1, 11: return Color("#ffd700") # Valeriano / Solvaren: Ouro Solar
		12: return Color("#ba68c8") # Aetheris: Púrpura Etéreo
		2, 13: return Color("#00e5ff") # Noctari / Selenarca: Ciano Astral
		14: return Color("#7c4dff") # Nyxara: Roxo Umbral
		3, 15: return Color("#ff9800") # Kharad / Runakhar: Laranja Magma
		16: return Color("#ff3d00") # Pyrokhar: Vermelho Lava
		4, 17: return Color("#ff1744") # Varkai / Dravarkai: Carmesim Dracônico
		18: return Color("#ad1457") # Ferovar: Magenta Sangue
		5: return Color("#d500f9") # Sangrael: Sangue Vampírico
		6: return Color("#ff6f00") # Lupharion: Feral Âmbar
		7: return Color("#69f0ae") # Cinerion: Ectoplasma Espectral
		8: return Color("#fff59d") # Seraphel: Branco Solar
		9: return Color("#18ffff") # Umbryss: Azul Vazio
		10: return Color("#00e5ff") # Runaric: Ciano Elétrico
		19: return Color("#4caf50") # Sylvari: Verde Floresta
		20: return Color("#9c27b0") # Myconid: Violeta Fúngico
		21: return Color("#eceff1") # Aracne: Seda Prateada
		22: return Color("#ff6d00") # Ignivarn: Magma Laranja
		23: return Color("#76ff03") # Chimeryth: Verde Ácido Mutante
		24: return Color("#80d8ff") # Borealin: Cristal Azul Gelo
		25: return Color("#006064") # Thalassiano: Azul Abissal
		26: return Color("#c62828") # Cambion: Vermelho Enxofre
		27: return Color("#ffd700") # Nephilim: Ouro e Sombra
		28: return Color("#ffd54f") # Cronari: Areia Dourada
		# Quadrante 5: 18 Novas Raças (29 a 46)
		29: return Color("#fff59d") # Aurelith: Luz Solar Divina
		30: return Color("#ff3d00") # Pyrael: Fogo Vivo e Brasa
		31: return Color("#80deea") # Jotunar: Glacial Cristalino
		32: return Color("#8d6e63") # Terravyrn: Carapaça Telúrica
		33: return Color("#29b6f6") # Hydravyrn: Maré Aquática
		34: return Color("#ffd600") # Fulgravyrn: Eletricidade Áurea
		35: return Color("#ab47bc") # Arcavyrn: Runas Violetas
		36: return Color("#558b2f") # Orkhan: Fúria Verde Marcial
		37: return Color("#d7ccc8") # Dvergar: Aço e Forja Pétrea
		38: return Color("#aed581") # Elarin: Verde Élfico Esguio
		39: return Color("#ffb300") # Solarin: Ouro de Azgher
		40: return Color("#5c6bc0") # Lunarin: Véu de Tenebra
		41: return Color("#f48fb1") # Faelith: Pó Rosa Cintilante
		42: return Color("#7cb342") # Gnarlin: Verde Astuto
		43: return Color("#6a1b9a") # Escarion: Veneno Púrpura
		44: return Color("#33691e") # Testudar: Casco Blindado
		45: return Color("#c2185b") # Lilitara: Sombra Carmesim
		46: return Color("#78909c") # Ulvar: Cinza Feral Lupino
		47: return Color("#3d5afe") # Manamante: Azul de Mana
		_: return Color("#ffd700")

func _spawn_racial_aura_burst() -> void:
	var col: Color = _get_race_color()
	var aura := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 0.15
	aura.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.material_override = mat
	aura.global_position = global_position + Vector3(0, 0.1, 0)
	if get_parent():
		get_parent().add_child(aura)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 6.0
	light.omni_range = 8.0
	aura.add_child(light)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.7
	ring.mesh = torus
	var mat_ring := StandardMaterial3D.new()
	mat_ring.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	mat_ring.emission_enabled = true
	mat_ring.emission = col
	mat_ring.emission_energy_multiplier = 7.0
	mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat_ring
	aura.add_child(ring)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(aura, "scale", Vector3(7.5, 1.0, 7.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.tween_property(mat_ring, "albedo_color:a", 0.0, 0.55)
	tw.tween_property(light, "light_energy", 0.0, 0.55)
	tw.chain().tween_callback(aura.queue_free)

	# Efeitos Visuais 3D Específicos das Raças na Tecla Z
	match current_race_id:
		19: # Sylvari: Raízes brotando no chão
			_spawn_roots_fx(global_position)
		20: # Myconid: Nuvem de esporos roxos
			_spawn_spores_fx(global_position)
		21: # Aracne: Disparo de seda prateada
			_spawn_web_fx(global_position, _get_aim_direction())
		22: # Ignivarn: Cone de fogo vulcânico e magma
			_spawn_magma_cone_fx(global_position, _get_aim_direction())
		23: # Chimeryth: Onda de choque mutante bio-ácida
			_spawn_chimera_fx(global_position)
		24: # Borealin: Anel de congelamento de gelo absoluto
			_spawn_frost_ring_fx(global_position)
		25: # Thalassiano: Erupção de gêiser d'água abissal
			_spawn_geyser_fx(global_position)
		26: # Cambion: Correntes incandescentes do tártaro
			_spawn_chains_fx(global_position)
		27: # Nephilim: Asas de luz solar e sombra negra
			_spawn_nephilim_fx(global_position)
		28: # Cronari: Mostrador cronológico de areia dourada
			_spawn_chrono_dial_fx(global_position)
		# Quadrante 5: 18 Novas Raças
		29: # Aurelith: Asas de Luz radiantes
			_spawn_light_wings_burst_fx(global_position)
		30: # Pyrael: Combustão explosiva
			_spawn_fire_burst_fx(global_position)
		31: # Jotunar: Memória Molecular / Impacto criogênico
			_spawn_frost_slam_fx(global_position)
		32: # Terravyrn: Insulto Sísmico com taunt e poeira
			_spawn_seismic_taunt_fx(global_position)
		33: # Hydravyrn: Bênção de Netuno / Onda de pressão
			_spawn_aqua_wave_fx(global_position, _get_aim_direction())
		34: # Fulgravyrn: Descarga Elétrica fulminante
			_spawn_lightning_strike_fx(global_position)
		35: # Arcavyrn: Infusão Arcana e runas radiantes
			_spawn_mystic_runes_fx(global_position)
		36: # Orkhan: Ataque Devastador brutal
			_spawn_orc_smash_fx(global_position)
		37: # Dvergar: Martelo Ancestral com choque de bigorna
			_spawn_dwarf_hammer_fx(global_position)
		38: # Elarin: Disparo Élfico de mana luminoso
			_spawn_elf_shot_fx(global_position, _get_aim_direction())
		39: # Solarin: Espada Solar de Azgher
			_spawn_solar_blade_fx(global_position)
		40: # Lunarin: Manto de Tenebra
			_spawn_lunar_shroud_fx(global_position)
		41: # Faelith: Pó de Fada Estelar curativo
			_spawn_fairy_dust_fx(global_position)
		42: # Gnarlin: Truque Sujo Gnarlin / Bomba de fumaça
			_spawn_goblin_bomb_fx(global_position)
		43: # Escarion: Aguilhão de Toxina Vorpal
			_spawn_scorpion_sting_fx(global_position, _get_aim_direction())
		44: # Testudar: Lar Doce Casca / Carapaça protetora
			_spawn_turtle_shell_fx(global_position)
		45: # Lilitara: Drenar Força Vital
			_spawn_succubus_drain_fx(global_position)
		46: # Ulvar: Despertar Forma Bestial
			_spawn_wolf_awaken_fx(global_position)
		47: # Manamante: Coração de Mana
			_spawn_racial_aura_burst()

func _spawn_light_wings_burst_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var aura := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.5
	cyl.bottom_radius = 0.5
	cyl.height = 3.0
	aura.mesh = cyl
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.95, 0.6, 0.7)
	am.emission_enabled = true
	am.emission = Color("#ffd700")
	am.emission_energy_multiplier = 5.0
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.material_override = am
	aura.global_position = pos + Vector3(0, 1.5, 0)
	get_parent().add_child(aura)
	var tw := create_tween()
	tw.tween_property(aura, "scale", Vector3(1.8, 1.2, 1.8), 0.45)
	tw.chain().tween_callback(aura.queue_free)

func _spawn_fire_burst_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var blast := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.2
	sph.height = 2.4
	blast.mesh = sph
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.25, 0.05, 0.8)
	bm.emission_enabled = true
	bm.emission = Color("#ff3d00")
	bm.emission_energy_multiplier = 6.0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast.material_override = bm
	blast.global_position = pos + Vector3(0, 0.8, 0)
	get_parent().add_child(blast)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(blast, "scale", Vector3(4.5, 2.0, 4.5), 0.4)
	tw.tween_property(bm, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(blast.queue_free)

func _spawn_frost_slam_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var fgroup := Node3D.new()
	fgroup.global_position = pos + Vector3(0, 0.05, 0)
	get_parent().add_child(fgroup)
	for i in range(8):
		var ang := i * (TAU / 8.0)
		var spk := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.6, 1.8, 0.6)
		spk.mesh = prism
		var im := StandardMaterial3D.new()
		im.albedo_color = Color(0.6, 0.9, 1.0, 0.85)
		im.emission_enabled = true
		im.emission = Color("#80deea")
		im.emission_energy_multiplier = 4.0
		im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spk.material_override = im
		spk.position = Vector3(cos(ang) * 2.8, 0.9, sin(ang) * 2.8)
		spk.rotation = Vector3(randf_range(-0.2, 0.2), randf_range(0, TAU), randf_range(-0.2, 0.2))
		fgroup.add_child(spk)
	var tw := create_tween()
	tw.tween_property(fgroup, "scale", Vector3(1.4, 1.2, 1.4), 0.3)
	tw.tween_property(fgroup, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
	tw.chain().tween_callback(fgroup.queue_free)

func _spawn_seismic_taunt_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.5
	tor.outer_radius = 2.2
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.6, 0.45, 0.3, 0.8)
	rm.emission_enabled = true
	rm.emission = Color("#ffb74d")
	rm.emission_energy_multiplier = 4.0
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.global_position = pos + Vector3(0, 0.15, 0)
	get_parent().add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(8.0, 1.0, 8.0), 0.5)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_aqua_wave_fx(pos: Vector3, dir: Vector3) -> void:
	if not get_parent(): return
	var wave := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 0.4
	cyl.height = 4.5
	wave.mesh = cyl
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.1, 0.65, 0.95, 0.75)
	wm.emission_enabled = true
	wm.emission = Color("#00b0ff")
	wm.emission_energy_multiplier = 3.5
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = wm
	wave.global_position = pos + dir.normalized() * 2.2 + Vector3(0, 0.5, 0)
	wave.look_at(wave.global_position + dir, Vector3.UP)
	wave.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	get_parent().add_child(wave)
	var tw := create_tween()
	tw.tween_property(wave, "scale", Vector3(1.8, 1.0, 1.8), 0.4)
	tw.chain().tween_callback(wave.queue_free)

func _spawn_lightning_strike_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var bolt := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.25
	cyl.height = 10.0
	bolt.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 1.0, 0.5, 0.9)
	bm.emission_enabled = true
	bm.emission = Color("#ffd600")
	bm.emission_energy_multiplier = 7.0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt.material_override = bm
	bolt.global_position = pos + Vector3(0, 5.0, 0)
	get_parent().add_child(bolt)
	var tw := create_tween()
	tw.tween_property(bolt, "scale", Vector3(2.0, 1.0, 2.0), 0.15)
	tw.tween_property(bolt, "scale", Vector3(0.01, 1.0, 0.01), 0.2)
	tw.chain().tween_callback(bolt.queue_free)

func _spawn_mystic_runes_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var mcircle := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.2
	tor.outer_radius = 2.4
	mcircle.mesh = tor
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.7, 0.2, 0.85, 0.85)
	mm.emission_enabled = true
	mm.emission = Color("#ab47bc")
	mm.emission_energy_multiplier = 5.0
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mcircle.material_override = mm
	mcircle.global_position = pos + Vector3(0, 0.15, 0)
	get_parent().add_child(mcircle)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mcircle, "scale", Vector3(2.5, 1.0, 2.5), 0.55)
	tw.tween_property(mcircle, "rotation:y", deg_to_rad(360), 0.55)
	tw.chain().tween_callback(mcircle.queue_free)

func _spawn_orc_smash_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var smash := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 0.5
	cyl.height = 0.3
	smash.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#b71c1c")
	sm.emission_enabled = true
	sm.emission = Color("#d32f2f")
	sm.emission_energy_multiplier = 4.5
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smash.material_override = sm
	smash.global_position = pos + Vector3(0, 0.1, 0)
	get_parent().add_child(smash)
	var tw := create_tween()
	tw.tween_property(smash, "scale", Vector3(2.5, 1.0, 2.5), 0.35)
	tw.chain().tween_callback(smash.queue_free)

func _spawn_dwarf_hammer_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var anvil_shock := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.8
	tor.outer_radius = 1.8
	anvil_shock.mesh = tor
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.75, 0.2, 0.85)
	am.emission_enabled = true
	am.emission = Color("#ff9800")
	am.emission_energy_multiplier = 5.0
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	anvil_shock.material_override = am
	anvil_shock.global_position = pos + Vector3(0, 0.1, 0)
	get_parent().add_child(anvil_shock)
	var tw := create_tween()
	tw.tween_property(anvil_shock, "scale", Vector3(3.2, 1.0, 3.2), 0.4)
	tw.chain().tween_callback(anvil_shock.queue_free)

func _spawn_elf_shot_fx(pos: Vector3, dir: Vector3) -> void:
	if not get_parent(): return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 6.0
	beam.mesh = cyl
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.7, 1.0, 0.6, 0.9)
	em.emission_enabled = true
	em.emission = Color("#76ff03")
	em.emission_energy_multiplier = 5.0
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = em
	beam.global_position = pos + dir.normalized() * 3.0 + Vector3(0, 1.0, 0)
	beam.look_at(beam.global_position + dir, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	get_parent().add_child(beam)
	var tw := create_tween()
	tw.tween_property(beam, "scale", Vector3(1.5, 1.8, 1.5), 0.35)
	tw.chain().tween_callback(beam.queue_free)

func _spawn_solar_blade_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var sun := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sun.mesh = sph
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 0.85, 0.1, 0.85)
	sm.emission_enabled = true
	sm.emission = Color("#ffd54f")
	sm.emission_energy_multiplier = 6.0
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sun.material_override = sm
	sun.global_position = pos + Vector3(0, 1.8, 0)
	get_parent().add_child(sun)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "scale", Vector3(3.0, 3.0, 3.0), 0.4)
	tw.tween_property(sm, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(sun.queue_free)

func _spawn_lunar_shroud_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var shroud := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.4
	sph.height = 2.8
	shroud.mesh = sph
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.08, 0.05, 0.25, 0.85)
	lm.emission_enabled = true
	lm.emission = Color("#5c6bc0")
	lm.emission_energy_multiplier = 4.0
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shroud.material_override = lm
	shroud.global_position = pos + Vector3(0, 1.0, 0)
	get_parent().add_child(shroud)
	var tw := create_tween()
	tw.tween_property(shroud, "scale", Vector3(3.2, 1.5, 3.2), 0.45)
	tw.chain().tween_callback(shroud.queue_free)

func _spawn_fairy_dust_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var fgroup := Node3D.new()
	fgroup.global_position = pos + Vector3(0, 0.8, 0)
	get_parent().add_child(fgroup)
	for i in range(12):
		var sp := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.15
		s.height = 0.3
		sp.mesh = s
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(1.0, 0.6, 0.9, 0.85)
		sm.emission_enabled = true
		sm.emission = Color("#f48fb1")
		sm.emission_energy_multiplier = 5.0
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sp.material_override = sm
		sp.position = Vector3(randf_range(-1.8, 1.8), randf_range(-0.5, 1.5), randf_range(-1.8, 1.8))
		fgroup.add_child(sp)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(fgroup, "position:y", fgroup.position.y + 1.5, 0.6)
	tw.tween_property(fgroup, "scale", Vector3(2.0, 2.0, 2.0), 0.6)
	tw.chain().tween_callback(fgroup.queue_free)

func _spawn_goblin_bomb_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var smoke := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.3
	sph.height = 2.6
	smoke.mesh = sph
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.2, 0.25, 0.2, 0.85)
	sm.emission_enabled = true
	sm.emission = Color("#7cb342")
	sm.emission_energy_multiplier = 3.0
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = sm
	smoke.global_position = pos + Vector3(0, 0.5, 0)
	get_parent().add_child(smoke)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(smoke, "scale", Vector3(3.5, 2.0, 3.5), 0.45)
	tw.tween_property(sm, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(smoke.queue_free)

func _spawn_scorpion_sting_fx(pos: Vector3, dir: Vector3) -> void:
	if not get_parent(): return
	var spike := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.25
	cyl.height = 3.5
	spike.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#311b92")
	sm.emission_enabled = true
	sm.emission = Color("#ea80fc")
	sm.emission_energy_multiplier = 4.5
	spike.material_override = sm
	spike.global_position = pos + dir.normalized() * 1.8 + Vector3(0, 0.8, 0)
	spike.look_at(spike.global_position + dir, Vector3.UP)
	spike.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	get_parent().add_child(spike)
	var tw := create_tween()
	tw.tween_property(spike, "scale", Vector3(1.5, 1.2, 1.5), 0.3)
	tw.chain().tween_callback(spike.queue_free)

func _spawn_turtle_shell_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var dome := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.6
	sph.height = 3.2
	dome.mesh = sph
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.1, 0.5, 0.2, 0.65)
	dm.emission_enabled = true
	dm.emission = Color("#4caf50")
	dm.emission_energy_multiplier = 3.5
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome.material_override = dm
	dome.global_position = pos + Vector3(0, 0.6, 0)
	get_parent().add_child(dome)
	var tw := create_tween()
	tw.tween_property(dome, "scale", Vector3(1.4, 1.2, 1.4), 0.5)
	tw.chain().tween_callback(dome.queue_free)

func _spawn_succubus_drain_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var drain := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.8
	tor.outer_radius = 1.6
	drain.mesh = tor
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.8, 0.05, 0.3, 0.85)
	sm.emission_enabled = true
	sm.emission = Color("#e91e63")
	sm.emission_energy_multiplier = 5.0
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drain.material_override = sm
	drain.global_position = pos + Vector3(0, 0.9, 0)
	get_parent().add_child(drain)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(drain, "scale", Vector3(3.0, 1.5, 3.0), 0.45)
	tw.tween_property(drain, "rotation:y", deg_to_rad(360), 0.45)
	tw.chain().tween_callback(drain.queue_free)

func _spawn_wolf_awaken_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var wolf_aura := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.8
	cyl.bottom_radius = 0.5
	cyl.height = 2.5
	wolf_aura.mesh = cyl
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.4, 0.5, 0.6, 0.75)
	wm.emission_enabled = true
	wm.emission = Color("#b0bec5")
	wm.emission_energy_multiplier = 4.0
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wolf_aura.material_override = wm
	wolf_aura.global_position = pos + Vector3(0, 1.0, 0)
	get_parent().add_child(wolf_aura)
	var tw := create_tween()
	tw.tween_property(wolf_aura, "scale", Vector3(2.5, 1.5, 2.5), 0.4)
	tw.chain().tween_callback(wolf_aura.queue_free)

func _spawn_roots_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var root_group := Node3D.new()
	root_group.global_position = pos + Vector3(0, 0.05, 0)
	get_parent().add_child(root_group)
	for i in range(6):
		var ang := i * (TAU / 6.0)
		var offset := Vector3(cos(ang) * 2.2, 0, sin(ang) * 2.2)
		var spike := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.25
		cyl.height = 1.4
		spike.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#2e7d32")
		m.emission_enabled = true
		m.emission = Color("#4caf50")
		m.emission_energy_multiplier = 2.0
		spike.material_override = m
		spike.position = offset + Vector3(0, 0.7, 0)
		spike.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(0, TAU), randf_range(-0.3, 0.3))
		root_group.add_child(spike)
	var tw := create_tween()
	tw.tween_property(root_group, "scale", Vector3(1.2, 1.2, 1.2), 0.2)
	tw.tween_property(root_group, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.chain().tween_callback(root_group.queue_free)

func _spawn_spores_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var spore_group := Node3D.new()
	spore_group.global_position = pos + Vector3(0, 0.5, 0)
	get_parent().add_child(spore_group)
	for i in range(8):
		var sp := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.25
		s.height = 0.5
		sp.mesh = s
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color("#9c27b0") if i % 2 == 0 else Color("#00e5ff")
		sm.emission_enabled = true
		sm.emission = sm.albedo_color
		sm.emission_energy_multiplier = 4.0
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sp.material_override = sm
		sp.position = Vector3(randf_range(-1.5, 1.5), randf_range(0.2, 1.5), randf_range(-1.5, 1.5))
		spore_group.add_child(sp)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(spore_group, "position:y", spore_group.position.y + 1.2, 0.6)
	tw.tween_property(spore_group, "scale", Vector3(2.5, 2.5, 2.5), 0.6)
	tw.chain().tween_callback(spore_group.queue_free)

func _spawn_web_fx(pos: Vector3, dir: Vector3) -> void:
	if not get_parent(): return
	var web := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.1
	cyl.height = 5.0
	web.mesh = cyl
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.92, 0.95, 1.0, 0.8)
	wm.emission_enabled = true
	wm.emission = Color("#b71c1c")
	wm.emission_energy_multiplier = 2.5
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.material_override = wm
	web.global_position = pos + dir.normalized() * 2.5 + Vector3(0, 0.5, 0)
	web.look_at(web.global_position + dir, Vector3.UP)
	web.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	get_parent().add_child(web)
	var tw := create_tween()
	tw.tween_property(web, "scale", Vector3(1.8, 1.0, 1.8), 0.45)
	tw.chain().tween_callback(web.queue_free)

func _spawn_magma_cone_fx(pos: Vector3, dir: Vector3) -> void:
	if not get_parent(): return
	var cone := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 0.2
	cyl.height = 4.5
	cone.mesh = cyl
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color("#212121")
	mm.emission_enabled = true
	mm.emission = Color("#ff6d00")
	mm.emission_energy_multiplier = 5.0
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone.material_override = mm
	cone.global_position = pos + dir.normalized() * 2.5 + Vector3(0, 0.5, 0)
	cone.look_at(cone.global_position + dir, Vector3.UP)
	cone.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	get_parent().add_child(cone)
	var tw := create_tween()
	tw.tween_property(cone, "scale", Vector3(1.6, 1.0, 1.6), 0.4)
	tw.chain().tween_callback(cone.queue_free)

func _spawn_chimera_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var blast := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	blast.mesh = sph
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.46, 1.0, 0.01, 0.75)
	cm.emission_enabled = true
	cm.emission = Color("#76ff03")
	cm.emission_energy_multiplier = 4.0
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast.material_override = cm
	blast.global_position = pos + Vector3(0, 0.5, 0)
	get_parent().add_child(blast)
	var tw := create_tween()
	tw.tween_property(blast, "scale", Vector3(4.0, 1.5, 4.0), 0.35)
	tw.chain().tween_callback(blast.queue_free)

func _spawn_frost_ring_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.5
	tor.outer_radius = 3.0
	ring.mesh = tor
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.5, 0.85, 1.0, 0.8)
	fm.emission_enabled = true
	fm.emission = Color("#00b0ff")
	fm.emission_energy_multiplier = 4.5
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = fm
	ring.global_position = pos + Vector3(0, 0.08, 0)
	get_parent().add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(2.0, 0.3, 2.0), 0.5)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_geyser_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var geyser := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.9
	cyl.height = 3.5
	geyser.mesh = cyl
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.0, 0.7, 0.9, 0.8)
	gm.emission_enabled = true
	gm.emission = Color("#00e5ff")
	gm.emission_energy_multiplier = 5.0
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	geyser.material_override = gm
	geyser.global_position = pos + Vector3(0, 1.75, 0)
	get_parent().add_child(geyser)
	var tw := create_tween()
	tw.tween_property(geyser, "scale", Vector3(1.8, 1.4, 1.8), 0.45)
	tw.chain().tween_callback(geyser.queue_free)

func _spawn_chains_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var chain_ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.2
	tor.outer_radius = 1.6
	chain_ring.mesh = tor
	var chm := StandardMaterial3D.new()
	chm.albedo_color = Color("#c62828")
	chm.emission_enabled = true
	chm.emission = Color("#ffea00")
	chm.emission_energy_multiplier = 4.0
	chm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chain_ring.material_override = chm
	chain_ring.global_position = pos + Vector3(0, 0.8, 0)
	get_parent().add_child(chain_ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(chain_ring, "scale", Vector3(2.5, 1.0, 2.5), 0.5)
	tw.tween_property(chain_ring, "rotation:y", deg_to_rad(360.0), 0.5)
	tw.chain().tween_callback(chain_ring.queue_free)

func _spawn_nephilim_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var wing_left := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.6
	cyl.height = 2.5
	wing_left.mesh = cyl
	var gold_m := StandardMaterial3D.new()
	gold_m.albedo_color = Color("#ffd700")
	gold_m.emission_enabled = true
	gold_m.emission = Color("#fff59d")
	gold_m.emission_energy_multiplier = 5.0
	wing_left.material_override = gold_m
	wing_left.global_position = pos + Vector3(-1.2, 1.0, 0)
	wing_left.rotation = Vector3(0, 0, deg_to_rad(-45.0))
	get_parent().add_child(wing_left)

	var wing_right := MeshInstance3D.new()
	wing_right.mesh = cyl
	var dark_m := StandardMaterial3D.new()
	dark_m.albedo_color = Color("#1a237e")
	dark_m.emission_enabled = true
	dark_m.emission = Color("#7c4dff")
	dark_m.emission_energy_multiplier = 4.0
	wing_right.material_override = dark_m
	wing_right.global_position = pos + Vector3(1.2, 1.0, 0)
	wing_right.rotation = Vector3(0, 0, deg_to_rad(45.0))
	get_parent().add_child(wing_right)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(wing_left, "scale", Vector3(1.5, 1.5, 1.5), 0.5)
	tw.tween_property(wing_right, "scale", Vector3(1.5, 1.5, 1.5), 0.5)
	tw.chain().tween_callback(func():
		wing_left.queue_free()
		wing_right.queue_free()
	)

func _spawn_chrono_dial_fx(pos: Vector3) -> void:
	if not get_parent(): return
	var dial := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.0
	tor.outer_radius = 2.2
	dial.mesh = tor
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1.0, 0.85, 0.3, 0.85)
	dm.emission_enabled = true
	dm.emission = Color("#ffd54f")
	dm.emission_energy_multiplier = 6.0
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dial.material_override = dm
	dial.global_position = pos + Vector3(0, 0.1, 0)
	get_parent().add_child(dial)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dial, "scale", Vector3(2.2, 0.5, 2.2), 0.55)
	tw.tween_property(dial, "rotation:y", deg_to_rad(720.0), 0.55)
	tw.chain().tween_callback(dial.queue_free)

func _animate_racial_skill_visual() -> void:
	if race_model:
		race_model.play_action(6)
	var tw := create_tween().set_parallel(false)
	tw.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, 0.22)
	tw.finished.connect(func(): is_attacking = false)

func _animate_attack_visual(action_type: int) -> void:
	if race_model:
		race_model.play_action(action_type)
	if not weapon_pivot:
		is_attacking = false
		return

	match current_class_id:
		3, 14: # Sentinela dos Ventos / Inquisidor de Prata: Puxada da corda do Arco e disparo veloz
			var tw := create_tween().set_parallel(false)
			if action_type == 3 or action_type == 4 or action_type == 5: # Skills
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-15.0), deg_to_rad(-55.0), deg_to_rad(20.0)), 0.16)
				tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z + 0.12, 0.16)
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-5.0), deg_to_rad(15.0), 0.0), 0.08)
				tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z - 0.08, 0.08)
			else: # Básico: Disparo rápido
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-10.0), deg_to_rad(-45.0), deg_to_rad(15.0)), 0.09)
				tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z + 0.08, 0.09)
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-5.0), deg_to_rad(10.0), 0.0), 0.07)
				tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z - 0.05, 0.07)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.12)
			tw.tween_property(weapon_pivot, "position", default_weapon_pos, 0.12)
			tw.finished.connect(func(): is_attacking = false)

		2: # Arcanista: Canalização arcana / Impulso frontal do Cajado
			var tw := create_tween().set_parallel(false)
			if action_type == 3 or action_type == 4 or action_type == 5: # Skills Q/R/F
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-85.0), deg_to_rad(20.0), deg_to_rad(-25.0)), 0.15)
				tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z - 0.4, 0.12)
				tw.tween_property(weapon_pivot, "rotation:y", weapon_pivot.rotation.y + deg_to_rad(360.0), 0.22)
			else: # Básico: Estocada mágica para frente
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-65.0), deg_to_rad(-10.0), 0.0), 0.11)
				tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z - 0.35, 0.11)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.tween_property(weapon_pivot, "position", default_weapon_pos, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		6, 15: # Guardião do Bastião / Valquíria: Golpe descendente de Maça atrás do escudo
			var tw := create_tween().set_parallel(false)
			if action_type == 3 or action_type == 4 or action_type == 5: # Skills
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-80.0), 0.0, deg_to_rad(30.0)), 0.18)
				if offhand_pivot:
					var tw_off := create_tween()
					tw_off.tween_property(offhand_pivot, "position:y", 0.45, 0.18)
					tw_off.tween_property(offhand_pivot, "position:y", 0.1, 0.2)
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(70.0), 0.0, deg_to_rad(-15.0)), 0.12)
			else: # Básico: Martelo esmagador
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-70.0), deg_to_rad(-30.0), deg_to_rad(45.0)), 0.09)
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(75.0), deg_to_rad(25.0), deg_to_rad(-20.0)), 0.12)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		7, 17, 35: # Forjador de Estrelas / Forjador / Engenheiro Rúnico: Pancada de Martelo de Forja
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-85.0), deg_to_rad(20.0), 0.0), 0.12)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(75.0), 0.0, 0.0), 0.16)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.12)
			tw.finished.connect(func(): is_attacking = false)

		8, 18, 36: # Transmutador / Doutor Corvo / Homúnculo: Lançamento de Frascos
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-45.0), deg_to_rad(-35.0), 0.0), 0.1)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(45.0), deg_to_rad(25.0), 0.0), 0.12)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.12)
			tw.finished.connect(func(): is_attacking = false)

		27: # Ceifador da Lua Negra: Golpe Giratório de Foice Colossal
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-40.0), deg_to_rad(-80.0), deg_to_rad(70.0)), 0.08)
			tw.tween_property(weapon_pivot, "rotation:y", weapon_pivot.rotation.y + deg_to_rad(360.0), 0.28)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		4, 28: # Lâmina Silente / Bailarino das Estrelas: Sequência acrobática com lâminas estelares duplas
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-45.0), deg_to_rad(-80.0), deg_to_rad(60.0)), 0.08)
			if offhand_pivot:
				var tw_off := create_tween()
				tw_off.tween_property(offhand_pivot, "rotation", Vector3(deg_to_rad(-35.0), deg_to_rad(70.0), deg_to_rad(-50.0)), 0.08)
				tw_off.tween_property(offhand_pivot, "rotation", Vector3(deg_to_rad(65.0), deg_to_rad(-45.0), deg_to_rad(40.0)), 0.12)
				tw_off.tween_property(offhand_pivot, "rotation", Vector3.ZERO, 0.12)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(65.0), deg_to_rad(60.0), deg_to_rad(-50.0)), 0.12)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.12)
			tw.finished.connect(func(): is_attacking = false)

		10, 29: # Senhor das Feras (chicote) / Inquisidor da Chama Branca: Chicoteada / arremesso do mangual em chamas
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-80.0), deg_to_rad(15.0), deg_to_rad(-10.0)), 0.11)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(85.0), deg_to_rad(-25.0), 0.0), 0.13)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.13)
			tw.finished.connect(func(): is_attacking = false)

		30: # Arauto do Ossuário: Erguimento do Cajado com pulso necromântico
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-75.0), deg_to_rad(20.0), deg_to_rad(-20.0)), 0.14)
			tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z - 0.3, 0.12)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.tween_property(weapon_pivot, "position", default_weapon_pos, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		37: # Senhor da Selva Primordial: Estocada feroz de lança
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-85.0), 0.0, deg_to_rad(10.0)), 0.1)
			tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z - 0.45, 0.1)
			tw.tween_property(weapon_pivot, "position:z", default_weapon_pos.z, 0.14)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		38: # Cavaleiro do Vazio: Golpe com Espada Colossal e avanço de Escudo
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-90.0), deg_to_rad(15.0), deg_to_rad(-10.0)), 0.14)
			if offhand_pivot:
				var tw_off := create_tween()
				tw_off.tween_property(offhand_pivot, "position:z", -0.35, 0.14)
				tw_off.tween_property(offhand_pivot, "position:z", -0.2, 0.14)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(80.0), deg_to_rad(-10.0), 0.0), 0.15)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		39: # Arauto do Trovão: Corte descendente e descarga da Alabarda
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-70.0), deg_to_rad(-60.0), deg_to_rad(45.0)), 0.1)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(75.0), deg_to_rad(40.0), deg_to_rad(-30.0)), 0.14)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		_: # Espadachim da Aurora e demais (Punho Celeste, Escultor de Almas, Alfaiate, Chef): Corte em arco e giro de 360
			var tw := create_tween().set_parallel(false)
			if action_type == 3 or action_type == 4 or action_type == 5:
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-35.0), deg_to_rad(-80.0), deg_to_rad(75.0)), 0.08)
				tw.tween_property(weapon_pivot, "rotation:y", weapon_pivot.rotation.y + deg_to_rad(360.0), 0.28)
			else: # Básico: Golpe diagonal
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-45.0), deg_to_rad(-60.0), deg_to_rad(70.0)), 0.08)
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(65.0), deg_to_rad(50.0), deg_to_rad(-45.0)), 0.12)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

## Curva de peso: até 70% normal | 70%–100% de 0.95 a 0.65 | 100%–129.9% de 0.60 a 0.25 (sem esquiva)
## | 130%+ imóvel (SOBRECARREGADO).
func get_weight_ratio() -> float:
	return current_weight / max(1.0, max_weight)

func get_weight_speed_mult() -> float:
	var ratio: float = get_weight_ratio()
	if ratio <= 0.70:
		return 1.0
	if ratio < 1.00:
		return lerp(0.95, 0.65, (ratio - 0.70) / 0.30)
	if ratio < 1.30:
		return lerp(0.60, 0.25, (ratio - 1.00) / 0.30)
	return 0.0

func can_dash() -> bool:
	return get_weight_ratio() < 1.00

func _perform_dodge_roll() -> void:
	if is_menu_open or is_dodging:
		return
	if not can_dash():
		return # acima de 100% do peso a esquiva (Shift) fica bloqueada

	is_dodging = true
	dodge_timer = 0.35

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_yaw: float = camera_pivot.global_rotation.y
	var forward: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right: Vector3 = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var move_dir: Vector3 = (forward * -input_dir.y + right * input_dir.x).normalized()

	if move_dir == Vector3.ZERO:
		move_dir = forward

	dodge_direction = move_dir
	velocity.x = dodge_direction.x * DODGE_SPEED
	velocity.z = dodge_direction.z * DODGE_SPEED

	var target_yaw := atan2(-dodge_direction.x, -dodge_direction.z)
	rotation.y = target_yaw

	action_triggered.emit(2)

	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_player_action(2, dodge_direction)

	if race_model:
		# O clipe dodge_roll do modelo faz o rolamento; o timer só libera a esquiva
		race_model.play_action(2)
		var tw_dodge := create_tween()
		tw_dodge.tween_interval(0.35)
		tw_dodge.finished.connect(func(): is_dodging = false)
	elif body_mesh:
		var tw := create_tween()
		tw.tween_property(body_mesh, "rotation:x", deg_to_rad(360.0), 0.35)
		tw.finished.connect(func():
			body_mesh.rotation.x = 0.0
			is_dodging = false
		)

func apply_identity(race_id: int, class_id: int) -> void:
	current_race_id = race_id
	current_class_id = class_id
	_apply_race_visuals()
	_apply_class_visuals()
	identity_changed.emit(current_race_id, current_class_id)

## Tier e Caminho Evolutivo vindos do servidor (PLAYER_STATS).
func set_path_info(class_tier: int, sub_path: int) -> void:
	current_class_tier = class_tier
	current_sub_path = sub_path

## Multiplicador de velocidade do Caminho Evolutivo ativo (1.0 sem caminho).
func _path_speed_mult() -> float:
	return float(ClassPaths.active_mult(current_class_id, current_class_tier, current_sub_path)[3])

func _change_class(class_id: int) -> void:
	if current_class_id == class_id:
		return
	current_class_id = class_id
	_apply_class_visuals()
	identity_changed.emit(current_race_id, current_class_id)
	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_select_identity(current_race_id, current_class_id)

func _change_race(race_id: int) -> void:
	if current_race_id == race_id:
		return
	current_race_id = race_id
	_apply_race_visuals()
	identity_changed.emit(current_race_id, current_class_id)
	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_select_identity(current_race_id, current_class_id)

func _get_race_scale() -> float:
	match current_race_id:
		31: return 1.45 # Jotunar (1.45x)
		37: return 0.82 # Dvergar (0.82x)
		41: return 0.55 # Faelith (0.55x)
		42: return 0.75 # Gnarlin (0.75x)
		44: return 1.35 # Testudar (1.35x)
		_: return 1.0

func _build_race_accessories(parent: Node3D, race_id: int) -> void:
	match race_id:
		29: # Aurelith: Asas solares douradas luminosas
			for side in [-1, 1]:
				var wing := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.05
				cyl.bottom_radius = 0.35
				cyl.height = 1.6
				wing.mesh = cyl
				var wm := StandardMaterial3D.new()
				wm.albedo_color = Color(1.0, 0.95, 0.6, 0.85)
				wm.emission_enabled = true
				wm.emission = Color("#ffd700")
				wm.emission_energy_multiplier = 4.0
				wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wing.material_override = wm
				wing.position = Vector3(side * 0.35, 0.4, 0.25)
				wing.rotation = Vector3(deg_to_rad(15.0), deg_to_rad(side * 35.0), deg_to_rad(side * -55.0))
				parent.add_child(wing)

		30: # Pyrael: Chamas e aura incandescente ao redor do peitoral/cabeça
			var flame_torus := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.32
			tor.outer_radius = 0.42
			flame_torus.mesh = tor
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color("#ff3d00")
			fm.emission_enabled = true
			fm.emission = Color("#ff6d00")
			fm.emission_energy_multiplier = 5.0
			flame_torus.material_override = fm
			flame_torus.position = Vector3(0, 0.85, 0)
			parent.add_child(flame_torus)

		31: # Jotunar: Ombreiras pontiagudas de gelo
			for side in [-1, 1]:
				var ice_spike := MeshInstance3D.new()
				var prism := PrismMesh.new()
				prism.size = Vector3(0.3, 0.5, 0.3)
				ice_spike.mesh = prism
				var im := StandardMaterial3D.new()
				im.albedo_color = Color(0.5, 0.85, 1.0, 0.8)
				im.metallic = 0.7
				im.roughness = 0.1
				im.emission_enabled = true
				im.emission = Color("#80deea")
				im.emission_energy_multiplier = 2.5
				ice_spike.material_override = im
				ice_spike.position = Vector3(side * 0.45, 0.6, 0.0)
				ice_spike.rotation = Vector3(0, 0, deg_to_rad(side * -30.0))
				parent.add_child(ice_spike)

		32: # Terravyrn: Carapaça rochosa e placas
			var shell := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.55, 0.7, 0.2)
			shell.mesh = box
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color("#5d4037")
			sm.roughness = 0.9
			shell.material_override = sm
			shell.position = Vector3(0, 0.3, 0.22)
			parent.add_child(shell)

		33: # Hydravyrn: Cristas aquáticas dorsais
			var fin := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.08, 0.8, 0.35)
			fin.mesh = prism
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(0.1, 0.6, 0.9, 0.75)
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.emission_enabled = true
			fm.emission = Color("#00b0ff")
			fm.emission_energy_multiplier = 2.0
			fin.material_override = fm
			fin.position = Vector3(0, 0.35, 0.25)
			fin.rotation = Vector3(deg_to_rad(90), 0, 0)
			parent.add_child(fin)

		34: # Fulgravyrn: Espinhos condutores elétricos nas costas
			for i in range(3):
				var spk := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.08
				cyl.height = 0.45
				spk.mesh = cyl
				var em := StandardMaterial3D.new()
				em.albedo_color = Color("#ffd600")
				em.emission_enabled = true
				em.emission = Color("#ffff00")
				em.emission_energy_multiplier = 4.5
				spk.material_override = em
				spk.position = Vector3(0, 0.15 + i * 0.25, 0.25)
				spk.rotation = Vector3(deg_to_rad(45), 0, 0)
				parent.add_child(spk)

		35: # Arcavyrn: Chifres arcanos espirais
			for side in [-1, 1]:
				var horn := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.03
				cyl.bottom_radius = 0.09
				cyl.height = 0.5
				horn.mesh = cyl
				var hm := StandardMaterial3D.new()
				hm.albedo_color = Color("#ab47bc")
				hm.emission_enabled = true
				hm.emission = Color("#e1bee7")
				hm.emission_energy_multiplier = 3.0
				horn.material_override = hm
				horn.position = Vector3(side * 0.25, 0.85, -0.05)
				horn.rotation = Vector3(deg_to_rad(-25), 0, deg_to_rad(side * 35))
				parent.add_child(horn)

		36: # Orkhan: Presas inferiores proeminentes
			for side in [-1, 1]:
				var tusk := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.06
				cyl.height = 0.22
				tusk.mesh = cyl
				var tm := StandardMaterial3D.new()
				tm.albedo_color = Color("#f5f5f5")
				tm.roughness = 0.4
				tusk.material_override = tm
				tusk.position = Vector3(side * 0.14, 0.62, -0.25)
				tusk.rotation = Vector3(deg_to_rad(-20), 0, deg_to_rad(side * -15))
				parent.add_child(tusk)

		37: # Dvergar: Barba trançada densa à frente do queixo
			var beard := MeshInstance3D.new()
			var b_mesh := BoxMesh.new()
			b_mesh.size = Vector3(0.32, 0.45, 0.18)
			beard.mesh = b_mesh
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("#5d4037")
			bm.roughness = 0.8
			beard.material_override = bm
			beard.position = Vector3(0, 0.42, -0.22)
			parent.add_child(beard)

		38: # Elarin: Orelhas pontiagudas esguias
			for side in [-1, 1]:
				var ear := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.06
				cyl.height = 0.32
				ear.mesh = cyl
				var em := StandardMaterial3D.new()
				em.albedo_color = Color("#ffcc80")
				ear.material_override = em
				ear.position = Vector3(side * 0.32, 0.72, 0.0)
				ear.rotation = Vector3(deg_to_rad(15), 0, deg_to_rad(side * 65))
				parent.add_child(ear)

		39: # Solarin (Azgher): Orelhas pontiagudas com diadema solar dourado
			for side in [-1, 1]:
				var ear := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.06
				cyl.height = 0.35
				ear.mesh = cyl
				var em := StandardMaterial3D.new()
				em.albedo_color = Color("#ffd54f")
				ear.material_override = em
				ear.position = Vector3(side * 0.32, 0.72, 0.0)
				ear.rotation = Vector3(deg_to_rad(15), 0, deg_to_rad(side * 65))
				parent.add_child(ear)
			var circlet := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.28
			tor.outer_radius = 0.34
			circlet.mesh = tor
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Color("#ffd700")
			cm.emission_enabled = true
			cm.emission = Color("#ffea00")
			cm.emission_energy_multiplier = 3.5
			circlet.material_override = cm
			circlet.position = Vector3(0, 0.82, 0)
			parent.add_child(circlet)

		40: # Lunarin (Tenebra): Orelhas com diadema de lua prateada
			for side in [-1, 1]:
				var ear := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.06
				cyl.height = 0.35
				ear.mesh = cyl
				var em := StandardMaterial3D.new()
				em.albedo_color = Color("#9fa8da")
				ear.material_override = em
				ear.position = Vector3(side * 0.32, 0.72, 0.0)
				ear.rotation = Vector3(deg_to_rad(15), 0, deg_to_rad(side * 65))
				parent.add_child(ear)
			var crescent := MeshInstance3D.new()
			var c_mesh := BoxMesh.new()
			c_mesh.size = Vector3(0.18, 0.12, 0.04)
			crescent.mesh = c_mesh
			var cmm := StandardMaterial3D.new()
			cmm.albedo_color = Color("#e8eaf6")
			cmm.emission_enabled = true
			cmm.emission = Color("#b388ff")
			cmm.emission_energy_multiplier = 3.0
			crescent.material_override = cmm
			crescent.position = Vector3(0, 0.88, -0.28)
			parent.add_child(crescent)

		41: # Faelith: Par de asas de borboleta reluzentes
			for side in [-1, 1]:
				var wing := MeshInstance3D.new()
				var quad := BoxMesh.new()
				quad.size = Vector3(0.4, 0.6, 0.02)
				wing.mesh = quad
				var wm := StandardMaterial3D.new()
				wm.albedo_color = Color(1.0, 0.6, 0.85, 0.75)
				wm.emission_enabled = true
				wm.emission = Color("#f48fb1")
				wm.emission_energy_multiplier = 3.5
				wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wing.material_override = wm
				wing.position = Vector3(side * 0.28, 0.45, 0.22)
				wing.rotation = Vector3(deg_to_rad(10), deg_to_rad(side * 30), deg_to_rad(side * -25))
				parent.add_child(wing)

		42: # Gnarlin: Orelhas compridas caídas e nariz pontiagudo
			for side in [-1, 1]:
				var ear := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.07
				cyl.height = 0.38
				ear.mesh = cyl
				var gm := StandardMaterial3D.new()
				gm.albedo_color = Color("#689f38")
				ear.material_override = gm
				ear.position = Vector3(side * 0.32, 0.65, 0.0)
				ear.rotation = Vector3(deg_to_rad(20), 0, deg_to_rad(side * -55))
				parent.add_child(ear)
			var nose := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.12, 0.18, 0.22)
			nose.mesh = prism
			var nm := StandardMaterial3D.new()
			nm.albedo_color = Color("#558b2f")
			nose.material_override = nm
			nose.position = Vector3(0, 0.68, -0.32)
			nose.rotation = Vector3(deg_to_rad(-90), 0, 0)
			parent.add_child(nose)

		43: # Escarion: Cauda articulada nas costas com ferrão
			var tail_base := Node3D.new()
			tail_base.position = Vector3(0, 0.1, 0.22)
			parent.add_child(tail_base)
			var seg1 := MeshInstance3D.new()
			var c1 := CylinderMesh.new()
			c1.top_radius = 0.06; c1.bottom_radius = 0.08; c1.height = 0.45
			seg1.mesh = c1
			var sc_mat := StandardMaterial3D.new()
			sc_mat.albedo_color = Color("#311b92")
			sc_mat.metallic = 0.8
			seg1.material_override = sc_mat
			seg1.position = Vector3(0, 0.2, 0.1)
			seg1.rotation = Vector3(deg_to_rad(35), 0, 0)
			tail_base.add_child(seg1)

			var seg2 := MeshInstance3D.new()
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.04; c2.bottom_radius = 0.06; c2.height = 0.45
			seg2.mesh = c2
			seg2.material_override = sc_mat
			seg2.position = Vector3(0, 0.52, 0.18)
			seg2.rotation = Vector3(deg_to_rad(75), 0, 0)
			tail_base.add_child(seg2)

			var stinger := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.08, 0.25, 0.12)
			stinger.mesh = prism
			var stm := StandardMaterial3D.new()
			stm.albedo_color = Color("#7b1fa2")
			stm.emission_enabled = true
			stm.emission = Color("#ea80fc")
			stm.emission_energy_multiplier = 4.0
			stinger.material_override = stm
			stinger.position = Vector3(0, 0.65, 0.0)
			stinger.rotation = Vector3(deg_to_rad(-45), 0, 0)
			tail_base.add_child(stinger)

		44: # Testudar: Casco pesado nas costas
			var shell := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.42
			sph.height = 0.85
			shell.mesh = sph
			var shm := StandardMaterial3D.new()
			shm.albedo_color = Color("#2e7d32")
			shm.roughness = 0.8
			shell.material_override = shm
			shell.scale = Vector3(1.15, 1.25, 0.6)
			shell.position = Vector3(0, 0.35, 0.28)
			parent.add_child(shell)

		45: # Lilitara: Chifres elegantes e asas de morcego
			for side in [-1, 1]:
				var horn := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02; cyl.bottom_radius = 0.07; cyl.height = 0.4
				horn.mesh = cyl
				var hm := StandardMaterial3D.new()
				hm.albedo_color = Color("#212121")
				hm.metallic = 0.9
				horn.material_override = hm
				horn.position = Vector3(side * 0.24, 0.85, -0.05)
				horn.rotation = Vector3(deg_to_rad(-30), 0, deg_to_rad(side * 40))
				parent.add_child(horn)

				var wing := MeshInstance3D.new()
				var quad := BoxMesh.new()
				quad.size = Vector3(0.55, 0.4, 0.02)
				wing.mesh = quad
				var wm := StandardMaterial3D.new()
				wm.albedo_color = Color("#880e4f")
				wm.emission_enabled = true
				wm.emission = Color("#ad1457")
				wm.emission_energy_multiplier = 2.0
				wing.material_override = wm
				wing.position = Vector3(side * 0.42, 0.45, 0.24)
				wing.rotation = Vector3(deg_to_rad(15), deg_to_rad(side * 25), deg_to_rad(side * -15))
				parent.add_child(wing)

		46: # Ulvar: Orelhas lupinas e cauda lupina
			for side in [-1, 1]:
				var ear := MeshInstance3D.new()
				var prism := PrismMesh.new()
				prism.size = Vector3(0.14, 0.24, 0.12)
				ear.mesh = prism
				var em := StandardMaterial3D.new()
				em.albedo_color = Color("#455a64")
				ear.material_override = em
				ear.position = Vector3(side * 0.22, 0.88, 0.0)
				ear.rotation = Vector3(0, 0, deg_to_rad(side * -15))
				parent.add_child(ear)
			var tail := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.04; cyl.bottom_radius = 0.10; cyl.height = 0.65
			tail.mesh = cyl
			var tm := StandardMaterial3D.new()
			tm.albedo_color = Color("#37474f")
			tail.material_override = tm
			tail.position = Vector3(0, 0.0, 0.32)
			tail.rotation = Vector3(deg_to_rad(45), 0, 0)
			parent.add_child(tail)

func _apply_race_visuals() -> void:
	if not body_mesh:
		return

	var s: float = _get_race_scale()
	body_mesh.scale = Vector3(s, s, s)

	# Limpa acessórios raciais anteriores
	var old_acc := body_mesh.get_node_or_null("RaceAccessory")
	if old_acc and is_instance_valid(old_acc):
		old_acc.queue_free()
	var race_acc := Node3D.new()
	race_acc.name = "RaceAccessory"
	body_mesh.add_child(race_acc)
	_build_race_accessories(race_acc, current_race_id)

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.35
	mat.metallic = 0.25

	match current_race_id:
		1: # Valeriano - Azul nobre
			mat.albedo_color = Color("#2962ff")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 2.0)
		2: # Noctari - Roxo lunar
			mat.albedo_color = Color("#4a148c")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#b388ff"), 2.5)
		3: # Kharad - Bronze forjado
			mat.albedo_color = Color("#5d4037")
			mat.metallic = 0.7
			mat.roughness = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffb74d"), 1.8)
		4: # Varkai - Vermelho primal
			mat.albedo_color = Color("#b71c1c")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff5252"), 2.2)
		5: # Sangrael - Carmesim sombrio
			mat.albedo_color = Color("#210408")
			mat.metallic = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff1744"), 3.0)
		6: # Lupharion - Cinza feral
			mat.albedo_color = Color("#3e2723")
			mat.roughness = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffb74d"), 2.5)
		7: # Cinerion - Ectoplasma sombrio
			mat.albedo_color = Color("#263238")
			mat.metallic = 0.1
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#69f0ae"), 2.5)
		8: # Seraphel - Alvura sagrada
			mat.albedo_color = Color("#fff9c4")
			mat.metallic = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 3.0)
		9: # Umbryss - Profundeza insondável
			mat.albedo_color = Color("#0d47a1")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#18ffff"), 2.8)
		10: # Runaric - Placas de bronze e runas
			mat.albedo_color = Color("#3e2723")
			mat.metallic = 0.95
			mat.roughness = 0.2
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.2)
		11: # Solvaren
			mat.albedo_color = Color("#ffd700")
			mat.metallic = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffea00"), 3.0)
		12: # Aetheris
			mat.albedo_color = Color("#4a148c")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ba68c8"), 2.5)
		13: # Selenarca
			mat.albedo_color = Color("#006064")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 2.8)
		14: # Nyxara
			mat.albedo_color = Color("#12005e")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#7c4dff"), 2.8)
		15: # Runakhar
			mat.albedo_color = Color("#4e342e")
			mat.metallic = 0.85
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff9800"), 2.5)
		16: # Pyrokhar
			mat.albedo_color = Color("#212121")
			mat.metallic = 0.9
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff3d00"), 3.0)
		17: # Dravarkai
			mat.albedo_color = Color("#880e4f")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 2.6)
		18: # Ferovar
			mat.albedo_color = Color("#4a0007")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff1744"), 3.0)
		19: # Sylvari - Verde-floresta
			mat.albedo_color = Color("#2e7d32")
			mat.roughness = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#4caf50"), 2.2)
		20: # Myconid - Bioluminescente violeta/ciano
			mat.albedo_color = Color("#4a148c")
			mat.roughness = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.0)
		21: # Aracne - Palidez aracnídea com detalhes rubros
			mat.albedo_color = Color("#eceff1")
			mat.metallic = 0.3
			mat.roughness = 0.2
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#b71c1c"), 3.0)
		22: # Ignivarn - Escamas negras com veias de magma
			mat.albedo_color = Color("#212121")
			mat.metallic = 0.8
			mat.roughness = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff6d00"), 3.2)
		23: # Chimeryth - Mutante verde-ácido
			mat.albedo_color = Color("#33691e")
			mat.roughness = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#76ff03"), 3.0)
		24: # Borealin - Cristal azul-gelo
			mat.albedo_color = Color("#80d8ff")
			mat.metallic = 0.7
			mat.roughness = 0.1
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00b0ff"), 2.8)
		25: # Thalassiano - Azul-abissal profundo
			mat.albedo_color = Color("#006064")
			mat.metallic = 0.5
			mat.roughness = 0.3
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.0)
		26: # Cambion - Vermelho-enxofre
			mat.albedo_color = Color("#b71c1c")
			mat.metallic = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffea00"), 3.0)
		27: # Nephilim - Metade luz dourada e metade sombra negra
			mat.albedo_color = Color("#1a237e")
			mat.metallic = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 3.2)
		28: # Cronari - Areia dourada cronológica
			mat.albedo_color = Color("#b28704")
			mat.metallic = 0.85
			mat.roughness = 0.3
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd54f"), 3.0)
		# Quadrante 5: 18 Novas Raças (29 a 46)
		29: # Aurelith - Luz Divina
			mat.albedo_color = Color("#fff9c4")
			mat.metallic = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 3.5)
		30: # Pyrael - Chamas e cinzas
			mat.albedo_color = Color("#ff3d00")
			mat.metallic = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff6d00"), 3.5)
		31: # Jotunar - Cristal Glacial (1.45x)
			mat.albedo_color = Color("#80deea")
			mat.metallic = 0.75
			mat.roughness = 0.1
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.5)
		32: # Terravyrn - Rocha e Carapaça
			mat.albedo_color = Color("#6d4c41")
			mat.roughness = 0.85
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#8d6e63"), 2.5)
		33: # Hydravyrn - Maré Cristalina
			mat.albedo_color = Color("#0277bd")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#4fc3f7"), 3.0)
		34: # Fulgravyrn - Elétrico Dourado
			mat.albedo_color = Color("#fbc02d")
			mat.metallic = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffff00"), 3.5)
		35: # Arcavyrn - Rúnico Violeta
			mat.albedo_color = Color("#7b1fa2")
			mat.metallic = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#e1bee7"), 3.2)
		36: # Orkhan - Verde de Guerra
			mat.albedo_color = Color("#33691e")
			mat.roughness = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#76ff03"), 2.8)
		37: # Dvergar - Bronze da Forja (0.82x)
			mat.albedo_color = Color("#4e342e")
			mat.metallic = 0.8
			mat.roughness = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#d7ccc8"), 2.2)
		38: # Elarin - Silvestre Esguio
			mat.albedo_color = Color("#558b2f")
			mat.roughness = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#aed581"), 2.6)
		39: # Solarin - Azgher Ouro
			mat.albedo_color = Color("#ff8f00")
			mat.metallic = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd54f"), 3.5)
		40: # Lunarin - Tenebra Sombra
			mat.albedo_color = Color("#283593")
			mat.metallic = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#9fa8da"), 3.0)
		41: # Faelith - Rosa Fada Borboleta (0.55x)
			mat.albedo_color = Color("#f06292")
			mat.metallic = 0.3
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#f8bbd0"), 3.5)
		42: # Gnarlin - Verde Astuto (0.75x)
			mat.albedo_color = Color("#689f38")
			mat.roughness = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#cddc39"), 2.5)
		43: # Escarion - Quitina Roxa
			mat.albedo_color = Color("#311b92")
			mat.metallic = 0.85
			mat.roughness = 0.2
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ba68c8"), 3.2)
		44: # Testudar - Carapaça (1.35x)
			mat.albedo_color = Color("#1b5e20")
			mat.roughness = 0.85
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#81c784"), 2.5)
		45: # Lilitara - Carmesim
			mat.albedo_color = Color("#880e4f")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#f06292"), 3.2)
		46: # Ulvar - Cinza Feral Lupino
			mat.albedo_color = Color("#37474f")
			mat.roughness = 0.75
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#b0bec5"), 2.8)
		47: # Manamante - Robe cobalto e veias de mana
			mat.albedo_color = Color("#1a2a80")
			mat.roughness = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#2979ff"), 3.4)

	body_mesh.material_override = mat
	_update_race_model()

func _update_race_model() -> void:
	# Todas as raças têm modelo 3D próprio; a cápsula fica só como reserva
	if race_model and is_instance_valid(race_model):
		race_model.queue_free()
	race_model = null
	if _capsule_mesh == null:
		_capsule_mesh = body_mesh.mesh
	if LunariaModel.has_model(LunariaModel.race_uid(current_race_id)):
		race_model = LunariaModel.create_race(current_race_id, current_class_id) as LunariaModel
		race_model.position = Vector3(0, -0.9, 0)
		# O modelo já tem a estatura da raça; desfaz a escala aplicada à cápsula
		var bs: float = maxf(body_mesh.scale.x, 0.01)
		race_model.scale = Vector3.ONE / bs
		body_mesh.add_child(race_model)
		body_mesh.mesh = null
		if visor_mesh:
			visor_mesh.visible = false
	else:
		body_mesh.mesh = _capsule_mesh
		if visor_mesh:
			visor_mesh.visible = true
	# Acessórios de cápsula (asas, chifres, caudas) só aparecem sem o modelo 3D
	for child in body_mesh.get_children():
		if String(child.name).begins_with("RaceAccessory") and not child.is_queued_for_deletion():
			child.visible = race_model == null

func _update_class_weapon() -> void:
	_apply_class_visuals()

## Aura exclusiva das Classes Lendárias (31 a 34): dourada, ou abissal no Soberano do Sol Negro.
func _update_legendary_aura() -> void:
	var old_aura := get_node_or_null("LegendaryAura")
	if old_aura:
		old_aura.queue_free()
	if not ClassPaths.is_legendary(current_class_id):
		return
	var abyssal: bool = current_class_id == 34
	var aura_col: Color = Color("#7c4dff") if abyssal else Color("#ffd54f")
	var aura := Node3D.new()
	aura.name = "LegendaryAura"
	add_child(aura)
	for ring_i in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55 + ring_i * 0.25
		torus.outer_radius = 0.6 + ring_i * 0.25
		ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(aura_col, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = aura_col
		mat.emission_energy_multiplier = 3.0
		ring.material_override = mat
		ring.position = Vector3(0, -0.85 + ring_i * 0.9, 0)
		aura.add_child(ring)
		var spin := create_tween().set_loops()
		spin.tween_property(ring, "rotation:y", TAU * (1 if ring_i == 0 else -1), 3.0 + ring_i).as_relative()
	var glow := OmniLight3D.new()
	glow.light_color = aura_col
	glow.light_energy = 1.4
	glow.omni_range = 3.5
	aura.add_child(glow)

func _apply_class_visuals() -> void:
	if not weapon_mesh:
		return

	# Limpa nós de armas anteriores
	for child in weapon_mesh.get_children():
		child.queue_free()

	if offhand_pivot:
		for child in offhand_pivot.get_children():
			child.queue_free()

	if homunculus_orbiter and is_instance_valid(homunculus_orbiter):
		homunculus_orbiter.queue_free()
		homunculus_orbiter = null

	if spirit_wolf_companion and is_instance_valid(spirit_wolf_companion):
		spirit_wolf_companion.queue_free()
		spirit_wolf_companion = null
	_update_legendary_aura()
	if race_model and is_instance_valid(race_model):
		race_model.set_class(current_class_id)
		return

	match current_class_id:
		19: # Algoz Vorpal: ferrões duplos
			_build_dual_daggers()
		20: # Senhor da Teia Escarlate: fios de seda
			_build_war_tailor_needles()
		21: # Rei-Fera da Alcateia: garras + lobos
			_build_tamer_whip_and_beast()
		22: # Runomante da Montanha: martelo rúnico
			_build_blacksmith_hammer()
		23: # Colosso Abissal: casco-escudo
			_build_shield_and_mace()
		24: # Arquifada: varinha da Árvore do Mundo
			_build_staff()
		25: # Conde Escarlate: lâminas de sangue
			_build_astral_blades()
		26: # Barão Engrenagem: canhão do mecha
			_build_hammer_cannon()
		31: # Herdeiro da Forja Divina: espada do Deus da Forja
			_build_sword_long()
		32: # Mestre Escultor do Luar
			_build_sculptor_chisel_and_statue()
		33: # Imperador Dracônico
			_build_tamer_whip_and_beast()
		34: # Soberano do Sol Negro
			_build_void_greatsword_and_shield()
		1: # Espadachim da Aurora: Espada Longa
			_build_sword_long()
		2: # Arcanista: Cajado Arcano
			_build_staff()
		3: # Sentinela dos Ventos: Arco Longo
			_build_bow()
		4: # Lâmina Silente: Duas Adagas (nas duas mãos)
			_build_dual_daggers()
		5: # Punho Celeste: Duas Manoplas Pesadas (nos dois punhos)
			_build_heavy_gauntlets()
		6: # Guardião do Bastião: Grande Escudo + Maça Curta
			_build_shield_and_mace()
		7: # Forjador de Estrelas: Martelo de Forja
			_build_blacksmith_hammer()
		8: # Transmutador: Frasco Químico + Catalisador
			_build_alchemist_flasks()
		9: # Escultor de Almas: Adaga de Cinzel Prateada + Pequena Estátua Orbitando
			_build_sculptor_chisel_and_statue()
		10: # Senhor das Feras: Chicote Enrolado + Fera Domada ao lado
			_build_tamer_whip_and_beast()
		11: # Tecelão Carmesim: Agulhas Longas Douradas + Fios brilhantes nas mãos
			_build_war_tailor_needles()
		12: # Mestre do Banquete: Cutelo de Açougueiro Gigante na mão direita + Wok de Ferro
			_build_hunting_chef_cleaver_and_wok()
		13: # Lâmina Rúnica (variante do Guerreiro)
			_build_sword_long()
		14: # Inquisidor de Prata (variante do Sentinela dos Ventos)
			_build_bow()
		15: # Valquíria Celeste (variante do Guardião do Bastião)
			_build_shield_and_mace()
		16: # Punho Fantasma (variante do Punho Celeste)
			_build_heavy_gauntlets()
		17: # Forjador Carmesim (variante do Ferreiro)
			_build_blacksmith_hammer()
		18: # Doutor Corvo (variante do Transmutador)
			_build_alchemist_flasks()
		27: # Ceifador da Lua Negra
			_build_scythe()
		35: # Engenheiro Rúnico
			_build_hammer_cannon()
		36: # Demiurgo Alquímico
			_build_homunculus_orb()
		28: # Bailarino das Estrelas
			_build_astral_blades()
		29: # Inquisidor da Chama Branca
			_build_ash_flail_and_chains()
		30: # Arauto do Ossuário
			_build_bone_staff()
		37: # Senhor da Selva Primordial
			_build_primordial_spear_and_wolf()
		38: # Cavaleiro do Vazio
			_build_void_greatsword_and_shield()
		39: # Arauto do Trovão
			_build_storm_halberd()

func _build_sword_long() -> void:
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.9, 0.95, 1.0)
	blade_mat.metallic = 0.95
	blade_mat.roughness = 0.15
	blade_mat.emission_enabled = true
	blade_mat.emission = Color("#40c4ff")
	blade_mat.emission_energy_multiplier = 1.4

	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.2, 0.22, 0.25)
	guard_mat.metallic = 0.9
	guard_mat.roughness = 0.3

	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.08, 1.15, 0.04)
	blade.mesh = blade_box
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0.58, 0)
	weapon_mesh.add_child(blade)

	var guard := MeshInstance3D.new()
	var guard_box := BoxMesh.new()
	guard_box.size = Vector3(0.34, 0.05, 0.08)
	guard.mesh = guard_box
	guard.material_override = guard_mat
	guard.position = Vector3(0, 0.03, 0)
	weapon_mesh.add_child(guard)

	var handle := MeshInstance3D.new()
	var handle_cyl := CylinderMesh.new()
	handle_cyl.top_radius = 0.025
	handle_cyl.bottom_radius = 0.025
	handle_cyl.height = 0.3
	handle.mesh = handle_cyl
	handle.material_override = guard_mat
	handle.position = Vector3(0, -0.15, 0)
	weapon_mesh.add_child(handle)

	var pommel := MeshInstance3D.new()
	var pommel_sphere := SphereMesh.new()
	pommel_sphere.radius = 0.04
	pommel_sphere.height = 0.08
	pommel.mesh = pommel_sphere
	pommel.material_override = guard_mat
	pommel.position = Vector3(0, -0.32, 0)
	weapon_mesh.add_child(pommel)

func _build_dual_daggers() -> void:
	var dagger_blade_mat := StandardMaterial3D.new()
	dagger_blade_mat.albedo_color = Color(0.85, 0.9, 0.95)
	dagger_blade_mat.metallic = 0.9
	dagger_blade_mat.roughness = 0.2
	dagger_blade_mat.emission_enabled = true
	dagger_blade_mat.emission = Color("#69f0ae")
	dagger_blade_mat.emission_energy_multiplier = 2.0

	var hilt_mat := StandardMaterial3D.new()
	hilt_mat.albedo_color = Color(0.15, 0.15, 0.18)
	hilt_mat.metallic = 0.8
	hilt_mat.roughness = 0.4

	# Adaga Direita
	var r_blade := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.05, 0.55, 0.025)
	r_blade.mesh = b_box
	r_blade.material_override = dagger_blade_mat
	r_blade.position = Vector3(0, 0.28, 0)
	weapon_mesh.add_child(r_blade)

	var r_guard := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	g_box.size = Vector3(0.18, 0.03, 0.05)
	r_guard.mesh = g_box
	r_guard.material_override = hilt_mat
	r_guard.position = Vector3(0, 0.02, 0)
	weapon_mesh.add_child(r_guard)

	var r_handle := MeshInstance3D.new()
	var h_cyl := CylinderMesh.new()
	h_cyl.top_radius = 0.02
	h_cyl.bottom_radius = 0.02
	h_cyl.height = 0.18
	r_handle.mesh = h_cyl
	r_handle.material_override = hilt_mat
	r_handle.position = Vector3(0, -0.09, 0)
	weapon_mesh.add_child(r_handle)

	# Adaga Esquerda (Offhand)
	if offhand_pivot:
		var l_blade := MeshInstance3D.new()
		l_blade.mesh = b_box
		l_blade.material_override = dagger_blade_mat
		l_blade.position = Vector3(0, 0.28, 0)
		offhand_pivot.add_child(l_blade)

		var l_guard := MeshInstance3D.new()
		l_guard.mesh = g_box
		l_guard.material_override = hilt_mat
		l_guard.position = Vector3(0, 0.02, 0)
		offhand_pivot.add_child(l_guard)

		var l_handle := MeshInstance3D.new()
		l_handle.mesh = h_cyl
		l_handle.material_override = hilt_mat
		l_handle.position = Vector3(0, -0.09, 0)
		offhand_pivot.add_child(l_handle)

func _build_heavy_gauntlets() -> void:
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.2, 0.22, 0.26)
	iron_mat.metallic = 0.95
	iron_mat.roughness = 0.25

	var chi_mat := StandardMaterial3D.new()
	chi_mat.albedo_color = Color("#ffb74d")
	chi_mat.emission_enabled = true
	chi_mat.emission = Color("#ffa726")
	chi_mat.emission_energy_multiplier = 3.5

	# Manopla Direita
	var r_fist := MeshInstance3D.new()
	var fist_box := BoxMesh.new()
	fist_box.size = Vector3(0.18, 0.24, 0.22)
	r_fist.mesh = fist_box
	r_fist.material_override = iron_mat
	r_fist.position = Vector3(0, 0.05, 0)
	weapon_mesh.add_child(r_fist)

	var r_plate := MeshInstance3D.new()
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(0.20, 0.06, 0.24)
	r_plate.mesh = plate_box
	r_plate.material_override = chi_mat
	r_plate.position = Vector3(0, 0.12, 0)
	weapon_mesh.add_child(r_plate)

	# Manopla Esquerda (Offhand)
	if offhand_pivot:
		var l_fist := MeshInstance3D.new()
		l_fist.mesh = fist_box
		l_fist.material_override = iron_mat
		l_fist.position = Vector3(0, 0.05, 0)
		offhand_pivot.add_child(l_fist)

		var l_plate := MeshInstance3D.new()
		l_plate.mesh = plate_box
		l_plate.material_override = chi_mat
		l_plate.position = Vector3(0, 0.12, 0)
		offhand_pivot.add_child(l_plate)

func _build_shield_and_mace() -> void:
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.22, 0.24, 0.28)
	dark_mat.metallic = 0.85
	dark_mat.roughness = 0.35

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#ffd700")
	gold_mat.metallic = 0.9
	gold_mat.roughness = 0.2

	var mace_shaft := MeshInstance3D.new()
	var m_cyl := CylinderMesh.new()
	m_cyl.top_radius = 0.03
	m_cyl.bottom_radius = 0.03
	m_cyl.height = 0.65
	mace_shaft.mesh = m_cyl
	mace_shaft.material_override = dark_mat
	mace_shaft.position = Vector3(0, 0.2, 0)
	weapon_mesh.add_child(mace_shaft)

	var mace_head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.2, 0.22, 0.2)
	mace_head.mesh = head_box
	mace_head.material_override = gold_mat
	mace_head.position = Vector3(0, 0.52, 0)
	weapon_mesh.add_child(mace_head)

	# Grande Escudo na mão esquerda (Offhand)
	if offhand_pivot:
		var tower_shield := MeshInstance3D.new()
		var shield_box := BoxMesh.new()
		shield_box.size = Vector3(0.55, 0.88, 0.08)
		tower_shield.mesh = shield_box
		var shield_mat := StandardMaterial3D.new()
		shield_mat.albedo_color = Color("#102a43")
		shield_mat.metallic = 0.7
		shield_mat.roughness = 0.3
		tower_shield.material_override = shield_mat
		tower_shield.position = Vector3(0, 0.1, 0)
		offhand_pivot.add_child(tower_shield)

		var border := MeshInstance3D.new()
		var border_box := BoxMesh.new()
		border_box.size = Vector3(0.59, 0.92, 0.06)
		border.mesh = border_box
		border.material_override = gold_mat
		border.position = Vector3(0, 0.1, -0.02)
		offhand_pivot.add_child(border)

func _build_sculptor_chisel_and_statue() -> void:
	var silver_mat := StandardMaterial3D.new()
	silver_mat.albedo_color = Color(0.92, 0.96, 1.0)
	silver_mat.metallic = 0.95
	silver_mat.roughness = 0.12
	silver_mat.emission_enabled = true
	silver_mat.emission = Color("#80deea")
	silver_mat.emission_energy_multiplier = 2.0

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.3, 0.2, 0.15)

	var chisel := MeshInstance3D.new()
	var chisel_box := BoxMesh.new()
	chisel_box.size = Vector3(0.045, 0.45, 0.02)
	chisel.mesh = chisel_box
	chisel.material_override = silver_mat
	chisel.position = Vector3(0, 0.24, 0)
	weapon_mesh.add_child(chisel)

	var handle := MeshInstance3D.new()
	var handle_cyl := CylinderMesh.new()
	handle_cyl.top_radius = 0.022
	handle_cyl.bottom_radius = 0.022
	handle_cyl.height = 0.18
	handle.mesh = handle_cyl
	handle.material_override = wood_mat
	handle.position = Vector3(0, -0.06, 0)
	weapon_mesh.add_child(handle)

	# Miniatura de Estátua Guardiã Orbitando
	homunculus_orbiter = MeshInstance3D.new()
	homunculus_orbiter.name = "SculptorStatueCompanion"
	var statue_mesh := BoxMesh.new()
	statue_mesh.size = Vector3(0.18, 0.32, 0.16)
	homunculus_orbiter.mesh = statue_mesh
	var marble_mat := StandardMaterial3D.new()
	marble_mat.albedo_color = Color("#f0f4f8")
	marble_mat.metallic = 0.3
	marble_mat.roughness = 0.4
	marble_mat.emission_enabled = true
	marble_mat.emission = Color("#80deea")
	marble_mat.emission_energy_multiplier = 1.8
	homunculus_orbiter.material_override = marble_mat

	var light := OmniLight3D.new()
	light.light_color = Color("#80deea")
	light.light_energy = 1.6
	light.omni_range = 2.2
	homunculus_orbiter.add_child(light)

	add_child(homunculus_orbiter)

func _build_tamer_whip_and_beast() -> void:
	var leather_mat := StandardMaterial3D.new()
	leather_mat.albedo_color = Color("#4e342e")
	leather_mat.roughness = 0.7

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color("#ffd740")
	brass_mat.metallic = 0.85
	brass_mat.roughness = 0.3

	var whip_handle := MeshInstance3D.new()
	var h_cyl := CylinderMesh.new()
	h_cyl.top_radius = 0.025
	h_cyl.bottom_radius = 0.025
	h_cyl.height = 0.28
	whip_handle.mesh = h_cyl
	whip_handle.material_override = brass_mat
	whip_handle.position = Vector3(0, 0.05, 0)
	weapon_mesh.add_child(whip_handle)

	var whip_coil := MeshInstance3D.new()
	var coil_torus := TorusMesh.new()
	coil_torus.inner_radius = 0.08
	coil_torus.outer_radius = 0.14
	whip_coil.mesh = coil_torus
	whip_coil.material_override = leather_mat
	whip_coil.rotation.x = deg_to_rad(90.0)
	whip_coil.position = Vector3(0, 0.2, 0)
	weapon_mesh.add_child(whip_coil)

	# Fera Domada Leal ao Lado
	spirit_wolf_companion = Node3D.new()
	spirit_wolf_companion.name = "TamerBeastCompanion"

	var beast_mat := StandardMaterial3D.new()
	beast_mat.albedo_color = Color("#6d4c41")
	beast_mat.roughness = 0.8

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color("#ffd740")
	eye_mat.emission_enabled = true
	eye_mat.emission = Color("#ffc107")
	eye_mat.emission_energy_multiplier = 3.5

	var body := MeshInstance3D.new()
	var b_capsule := CapsuleMesh.new()
	b_capsule.radius = 0.18
	b_capsule.height = 0.6
	body.mesh = b_capsule
	body.material_override = beast_mat
	body.rotation.x = deg_to_rad(90.0)
	spirit_wolf_companion.add_child(body)

	var head := MeshInstance3D.new()
	var h_box := BoxMesh.new()
	h_box.size = Vector3(0.2, 0.18, 0.24)
	head.mesh = h_box
	head.material_override = beast_mat
	head.position = Vector3(0, 0.2, -0.38)
	spirit_wolf_companion.add_child(head)

	for ex in [-0.05, 0.05]:
		var eye := MeshInstance3D.new()
		var e_sph := SphereMesh.new()
		e_sph.radius = 0.022
		e_sph.height = 0.044
		eye.mesh = e_sph
		eye.material_override = eye_mat
		eye.position = Vector3(ex, 0.24, -0.48)
		spirit_wolf_companion.add_child(eye)

	add_child(spirit_wolf_companion)

func _build_war_tailor_needles() -> void:
	var needle_mat := StandardMaterial3D.new()
	needle_mat.albedo_color = Color("#ffd700")
	needle_mat.metallic = 0.95
	needle_mat.roughness = 0.15
	needle_mat.emission_enabled = true
	needle_mat.emission = Color("#ffe082")
	needle_mat.emission_energy_multiplier = 2.0

	var thread_mat := StandardMaterial3D.new()
	thread_mat.albedo_color = Color("#ce93d8")
	thread_mat.emission_enabled = true
	thread_mat.emission = Color("#ba68c8")
	thread_mat.emission_energy_multiplier = 3.5

	# 3 Agulhas na mão direita
	for off_x in [-0.04, 0.0, 0.04]:
		var needle := MeshInstance3D.new()
		var n_cyl := CylinderMesh.new()
		n_cyl.top_radius = 0.003
		n_cyl.bottom_radius = 0.012
		n_cyl.height = 0.42
		needle.mesh = n_cyl
		needle.material_override = needle_mat
		needle.position = Vector3(off_x, 0.22, 0)
		weapon_mesh.add_child(needle)

	# Fios brilhantes de aço
	var thread_ring := MeshInstance3D.new()
	var t_torus := TorusMesh.new()
	t_torus.inner_radius = 0.035
	t_torus.outer_radius = 0.055
	thread_ring.mesh = t_torus
	thread_ring.material_override = thread_mat
	thread_ring.rotation.x = deg_to_rad(90.0)
	thread_ring.position = Vector3(0, 0.05, 0)
	weapon_mesh.add_child(thread_ring)

	# Mão esquerda (Offhand) com agulha e fio
	if offhand_pivot:
		var off_needle := MeshInstance3D.new()
		var on_cyl := CylinderMesh.new()
		on_cyl.top_radius = 0.003
		on_cyl.bottom_radius = 0.012
		on_cyl.height = 0.42
		off_needle.mesh = on_cyl
		off_needle.material_override = needle_mat
		off_needle.position = Vector3(0, 0.22, 0)
		offhand_pivot.add_child(off_needle)

		var off_thread := MeshInstance3D.new()
		off_thread.mesh = t_torus
		off_thread.material_override = thread_mat
		off_thread.rotation.x = deg_to_rad(90.0)
		off_thread.position = Vector3(0, 0.05, 0)
		offhand_pivot.add_child(off_thread)

func _build_hunting_chef_cleaver_and_wok() -> void:
	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.25, 0.27, 0.3)
	steel_mat.metallic = 0.95
	steel_mat.roughness = 0.25

	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.9, 0.95, 1.0)
	edge_mat.metallic = 0.95
	edge_mat.emission_enabled = true
	edge_mat.emission = Color("#ff7043")
	edge_mat.emission_energy_multiplier = 2.2

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.35, 0.22, 0.15)
	wood_mat.roughness = 0.8

	var blade := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.04, 0.65, 0.28)
	blade.mesh = b_box
	blade.material_override = steel_mat
	blade.position = Vector3(0, 0.38, -0.06)
	weapon_mesh.add_child(blade)

	var edge := MeshInstance3D.new()
	var e_box := BoxMesh.new()
	e_box.size = Vector3(0.045, 0.66, 0.04)
	edge.mesh = e_box
	edge.material_override = edge_mat
	edge.position = Vector3(0, 0.38, -0.2)
	weapon_mesh.add_child(edge)

	var handle := MeshInstance3D.new()
	var h_cyl := CylinderMesh.new()
	h_cyl.top_radius = 0.028
	h_cyl.bottom_radius = 0.028
	h_cyl.height = 0.26
	handle.mesh = h_cyl
	handle.material_override = wood_mat
	handle.position = Vector3(0, -0.08, 0)
	weapon_mesh.add_child(handle)

	# Wok de Ferro na mão esquerda / costas (Offhand)
	if offhand_pivot:
		var wok := MeshInstance3D.new()
		var w_cyl := CylinderMesh.new()
		w_cyl.top_radius = 0.26
		w_cyl.bottom_radius = 0.18
		w_cyl.height = 0.08
		wok.mesh = w_cyl
		var iron_mat := StandardMaterial3D.new()
		iron_mat.albedo_color = Color("#212121")
		iron_mat.metallic = 0.9
		iron_mat.roughness = 0.4
		wok.material_override = iron_mat
		wok.rotation.x = deg_to_rad(75.0)
		wok.position = Vector3(0, 0.15, 0)
		offhand_pivot.add_child(wok)

		var handle_w := MeshInstance3D.new()
		var hw_box := BoxMesh.new()
		hw_box.size = Vector3(0.05, 0.18, 0.04)
		handle_w.mesh = hw_box
		handle_w.material_override = wood_mat
		handle_w.position = Vector3(0, 0.15, 0.24)
		offhand_pivot.add_child(handle_w)

func _build_sword_and_shield() -> void:
	# Espada Longa
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.9, 0.95, 1.0)
	blade_mat.metallic = 0.95
	blade_mat.roughness = 0.15
	blade_mat.emission_enabled = true
	blade_mat.emission = Color("#40c4ff")
	blade_mat.emission_energy_multiplier = 1.4

	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.2, 0.22, 0.25)
	guard_mat.metallic = 0.9
	guard_mat.roughness = 0.3

	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.08, 1.05, 0.04)
	blade.mesh = blade_box
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0.52, 0)
	weapon_mesh.add_child(blade)

	var guard := MeshInstance3D.new()
	var guard_box := BoxMesh.new()
	guard_box.size = Vector3(0.32, 0.05, 0.08)
	guard.mesh = guard_box
	guard.material_override = guard_mat
	guard.position = Vector3(0, 0.03, 0)
	weapon_mesh.add_child(guard)

	var handle := MeshInstance3D.new()
	var handle_cyl := CylinderMesh.new()
	handle_cyl.top_radius = 0.025
	handle_cyl.bottom_radius = 0.025
	handle_cyl.height = 0.28
	handle.mesh = handle_cyl
	handle.material_override = guard_mat
	handle.position = Vector3(0, -0.14, 0)
	weapon_mesh.add_child(handle)

	# Escudo na mão esquerda (Offhand)
	if offhand_pivot:
		var shield := MeshInstance3D.new()
		var shield_box := BoxMesh.new()
		shield_box.size = Vector3(0.48, 0.68, 0.07)
		shield.mesh = shield_box
		var shield_mat := StandardMaterial3D.new()
		shield_mat.albedo_color = Color("#1565c0")
		shield_mat.metallic = 0.6
		shield_mat.roughness = 0.3
		shield.material_override = shield_mat
		shield.position = Vector3(0, 0.1, 0)
		offhand_pivot.add_child(shield)

		# Borda metálica do escudo
		var rim := MeshInstance3D.new()
		var rim_box := BoxMesh.new()
		rim_box.size = Vector3(0.52, 0.72, 0.05)
		rim.mesh = rim_box
		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = Color("#ffd700")
		rim_mat.metallic = 0.9
		rim_mat.roughness = 0.2
		rim.material_override = rim_mat
		rim.position = Vector3(0, 0.1, -0.02)
		offhand_pivot.add_child(rim)

func _build_bow() -> void:
	# Arco Curvo de Caça
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("#5d4037")
	wood_mat.roughness = 0.6

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#ffd700")
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.25

	# Grip central
	var grip := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius = 0.025
	grip_cyl.bottom_radius = 0.025
	grip_cyl.height = 0.2
	grip.mesh = grip_cyl
	grip.material_override = gold_mat
	weapon_mesh.add_child(grip)

	# Membro superior do arco
	var upper := MeshInstance3D.new()
	var upper_cyl := CylinderMesh.new()
	upper_cyl.top_radius = 0.015
	upper_cyl.bottom_radius = 0.022
	upper_cyl.height = 0.55
	upper.mesh = upper_cyl
	upper.material_override = wood_mat
	upper.position = Vector3(0, 0.32, 0.08)
	upper.rotation.x = deg_to_rad(-25.0)
	weapon_mesh.add_child(upper)

	# Membro inferior do arco
	var lower := MeshInstance3D.new()
	var lower_cyl := CylinderMesh.new()
	lower_cyl.top_radius = 0.022
	lower_cyl.bottom_radius = 0.015
	lower_cyl.height = 0.55
	lower.mesh = lower_cyl
	lower.material_override = wood_mat
	lower.position = Vector3(0, -0.32, 0.08)
	lower.rotation.x = deg_to_rad(25.0)
	weapon_mesh.add_child(lower)

	# Corda do arco
	var string := MeshInstance3D.new()
	var string_cyl := CylinderMesh.new()
	string_cyl.top_radius = 0.005
	string_cyl.bottom_radius = 0.005
	string_cyl.height = 1.05
	string.mesh = string_cyl
	var string_mat := StandardMaterial3D.new()
	string_mat.albedo_color = Color(0.9, 0.95, 1.0)
	string_mat.emission_enabled = true
	string_mat.emission = Color("#80d8ff")
	string_mat.emission_energy_multiplier = 1.2
	string.material_override = string_mat
	string.position = Vector3(0, 0, 0.18)
	weapon_mesh.add_child(string)

	# Flecha engatada no arco
	var arrow := MeshInstance3D.new()
	var arrow_cyl := CylinderMesh.new()
	arrow_cyl.top_radius = 0.012
	arrow_cyl.bottom_radius = 0.012
	arrow_cyl.height = 0.8
	arrow.mesh = arrow_cyl
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color("#8d6e63")
	arrow.material_override = arrow_mat
	arrow.rotation.x = deg_to_rad(90.0)
	arrow.position = Vector3(0, 0, 0.1)
	weapon_mesh.add_child(arrow)

	# Ponta dourada da flecha
	var tip := MeshInstance3D.new()
	var tip_cone := CylinderMesh.new()
	tip_cone.top_radius = 0.0
	tip_cone.bottom_radius = 0.025
	tip_cone.height = 0.12
	tip.mesh = tip_cone
	tip.material_override = gold_mat
	tip.rotation.x = deg_to_rad(90.0)
	tip.position = Vector3(0, 0, -0.32)
	weapon_mesh.add_child(tip)

func _build_staff() -> void:
	# Cajado Rúnico Longo
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("#2e1c14")
	wood_mat.roughness = 0.7

	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.03
	shaft_cyl.height = 1.75
	shaft.mesh = shaft_cyl
	shaft.material_override = wood_mat
	shaft.position = Vector3(0, 0.45, 0)
	weapon_mesh.add_child(shaft)

	# Anéis rúnicos ao longo do cajado
	for y_pos in [0.1, 0.5, 0.9]:
		var ring := MeshInstance3D.new()
		var ring_cyl := CylinderMesh.new()
		ring_cyl.top_radius = 0.036
		ring_cyl.bottom_radius = 0.036
		ring_cyl.height = 0.05
		ring.mesh = ring_cyl
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color("#b0bec5")
		ring_mat.metallic = 0.9
		ring.material_override = ring_mat
		ring.position = Vector3(0, y_pos, 0)
		weapon_mesh.add_child(ring)

	# Orbe Arcano no topo
	var orb := MeshInstance3D.new()
	var orb_sphere := SphereMesh.new()
	orb_sphere.radius = 0.16
	orb_sphere.height = 0.32
	orb.mesh = orb_sphere
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color("#00e5ff")
	orb_mat.emission_enabled = true
	orb_mat.emission = Color("#00e5ff")
	orb_mat.emission_energy_multiplier = 3.8
	orb.material_override = orb_mat
	orb.position = Vector3(0, 1.35, 0)
	weapon_mesh.add_child(orb)

	var light := OmniLight3D.new()
	light.light_color = Color("#00e5ff")
	light.light_energy = 1.8
	light.omni_range = 2.5
	orb.add_child(light)

func _build_mace_and_talisman() -> void:
	# Maça Dourada Flangeada
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#ffd700")
	gold_mat.metallic = 0.92
	gold_mat.roughness = 0.2
	gold_mat.emission_enabled = true
	gold_mat.emission = Color("#ffb300")
	gold_mat.emission_energy_multiplier = 1.5

	var handle := MeshInstance3D.new()
	var handle_cyl := CylinderMesh.new()
	handle_cyl.top_radius = 0.032
	handle_cyl.bottom_radius = 0.032
	handle_cyl.height = 0.75
	handle.mesh = handle_cyl
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.2, 0.18, 0.15)
	dark_mat.roughness = 0.8
	handle.material_override = dark_mat
	handle.position = Vector3(0, 0.25, 0)
	weapon_mesh.add_child(handle)

	# Cabeça da maça
	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.2, 0.26, 0.2)
	head.mesh = head_box
	head.material_override = gold_mat
	head.position = Vector3(0, 0.65, 0)
	weapon_mesh.add_child(head)

	var cross_flange := MeshInstance3D.new()
	var cross_box := BoxMesh.new()
	cross_box.size = Vector3(0.28, 0.2, 0.1)
	cross_flange.mesh = cross_box
	cross_flange.material_override = gold_mat
	cross_flange.position = Vector3(0, 0.65, 0)
	weapon_mesh.add_child(cross_flange)

	# Talismã Sagrado Luminoso na mão esquerda
	if offhand_pivot:
		var talisman := MeshInstance3D.new()
		var talisman_box := BoxMesh.new()
		talisman_box.size = Vector3(0.18, 0.26, 0.08)
		talisman.mesh = talisman_box
		var tal_mat := StandardMaterial3D.new()
		tal_mat.albedo_color = Color("#fff9c4")
		tal_mat.emission_enabled = true
		tal_mat.emission = Color("#ffd54f")
		tal_mat.emission_energy_multiplier = 3.0
		talisman.material_override = tal_mat
		talisman.position = Vector3(0, 0.15, 0)
		offhand_pivot.add_child(talisman)

		var tal_light := OmniLight3D.new()
		tal_light.light_color = Color("#ffe082")
		tal_light.light_energy = 1.5
		tal_light.omni_range = 2.0
		talisman.add_child(tal_light)

func _build_blacksmith_hammer() -> void:
	# Martelo de Forja de Duas Mãos cinza-escuro com detalhes em brasa laranja incandescente
	var handle := MeshInstance3D.new()
	var handle_cyl := CylinderMesh.new()
	handle_cyl.top_radius = 0.038
	handle_cyl.bottom_radius = 0.038
	handle_cyl.height = 1.25
	handle.mesh = handle_cyl
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.16, 0.16, 0.18)
	dark_mat.metallic = 0.8
	dark_mat.roughness = 0.4
	handle.material_override = dark_mat
	handle.position = Vector3(0, 0.42, 0)
	weapon_mesh.add_child(handle)

	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.34, 0.36, 0.52)
	head.mesh = head_box
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.22, 0.24, 0.26)
	iron_mat.metallic = 0.95
	iron_mat.roughness = 0.28
	head.material_override = iron_mat
	head.position = Vector3(0, 0.95, 0)
	weapon_mesh.add_child(head)

	# Fissuras e runas em brasa incandescente
	var ember_band := MeshInstance3D.new()
	var ember_box := BoxMesh.new()
	ember_box.size = Vector3(0.35, 0.1, 0.53)
	ember_band.mesh = ember_box
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color("#ff3d00")
	ember_mat.emission_enabled = true
	ember_mat.emission = Color("#ff6d00")
	ember_mat.emission_energy_multiplier = 4.5
	ember_band.material_override = ember_mat
	ember_band.position = Vector3(0, 0.95, 0)
	weapon_mesh.add_child(ember_band)

	var hammer_light := OmniLight3D.new()
	hammer_light.light_color = Color("#ff6d00")
	hammer_light.light_energy = 2.2
	hammer_light.omni_range = 3.2
	head.add_child(hammer_light)

func _build_alchemist_flasks() -> void:
	# Frasco Químico Verde Brilhante na mão
	var flask := MeshInstance3D.new()
	var flask_sphere := SphereMesh.new()
	flask_sphere.radius = 0.16
	flask_sphere.height = 0.32
	flask.mesh = flask_sphere
	var acid_mat := StandardMaterial3D.new()
	acid_mat.albedo_color = Color("#00e676")
	acid_mat.emission_enabled = true
	acid_mat.emission = Color("#00e676")
	acid_mat.emission_energy_multiplier = 3.2
	acid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	acid_mat.albedo_color.a = 0.9
	flask.material_override = acid_mat
	flask.position = Vector3(0, 0.32, 0)
	weapon_mesh.add_child(flask)

	var neck := MeshInstance3D.new()
	var neck_cyl := CylinderMesh.new()
	neck_cyl.top_radius = 0.06
	neck_cyl.bottom_radius = 0.06
	neck_cyl.height = 0.12
	neck.mesh = neck_cyl
	neck.material_override = acid_mat
	neck.position = Vector3(0, 0.46, 0)
	weapon_mesh.add_child(neck)

	var cork := MeshInstance3D.new()
	var cork_cyl := CylinderMesh.new()
	cork_cyl.top_radius = 0.05
	cork_cyl.bottom_radius = 0.05
	cork_cyl.height = 0.06
	cork.mesh = cork_cyl
	var cork_mat := StandardMaterial3D.new()
	cork_mat.albedo_color = Color("#8d6e63")
	cork.material_override = cork_mat
	cork.position = Vector3(0, 0.54, 0)
	weapon_mesh.add_child(cork)

	var chem_light := OmniLight3D.new()
	chem_light.light_color = Color("#00e676")
	chem_light.light_energy = 2.4
	chem_light.omni_range = 3.0
	flask.add_child(chem_light)

	if offhand_pivot:
		var off_flask := MeshInstance3D.new()
		var off_sphere := SphereMesh.new()
		off_sphere.radius = 0.13
		off_sphere.height = 0.26
		off_flask.mesh = off_sphere
		var elixir_mat := StandardMaterial3D.new()
		elixir_mat.albedo_color = Color("#ab47bc")
		elixir_mat.emission_enabled = true
		elixir_mat.emission = Color("#ba68c8")
		elixir_mat.emission_energy_multiplier = 2.4
		off_flask.material_override = elixir_mat
		off_flask.position = Vector3(0, 0.22, 0)
		offhand_pivot.add_child(off_flask)

func _build_scythe() -> void:
	# Foice Negra e Carmesim grande em formato de meia-lua
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.032
	shaft_cyl.bottom_radius = 0.032
	shaft_cyl.height = 1.95
	shaft.mesh = shaft_cyl
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.1, 0.06, 0.12)
	dark_wood.metallic = 0.3
	shaft.material_override = dark_wood
	shaft.position = Vector3(0, 0.55, 0)
	weapon_mesh.add_child(shaft)

	# Lâmina Curva Principal em Meia-Lua (Segmento Base)
	var scythe_blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.06, 0.16, 0.72)
	scythe_blade.mesh = blade_box
	var dark_blade_mat := StandardMaterial3D.new()
	dark_blade_mat.albedo_color = Color("#120005")
	dark_blade_mat.metallic = 0.95
	dark_blade_mat.roughness = 0.12
	scythe_blade.material_override = dark_blade_mat
	scythe_blade.rotation.x = deg_to_rad(25.0)
	scythe_blade.position = Vector3(0, 1.45, -0.28)
	weapon_mesh.add_child(scythe_blade)

	# Ponta Curva da Meia-Lua
	var tip := MeshInstance3D.new()
	var tip_box := BoxMesh.new()
	tip_box.size = Vector3(0.05, 0.12, 0.45)
	tip.mesh = tip_box
	tip.material_override = dark_blade_mat
	tip.rotation.x = deg_to_rad(-28.0)
	tip.position = Vector3(0, 1.32, -0.68)
	weapon_mesh.add_child(tip)

	# Gume Carmesim Incandescente
	var edge := MeshInstance3D.new()
	var edge_box := BoxMesh.new()
	edge_box.size = Vector3(0.065, 0.04, 0.95)
	edge.mesh = edge_box
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color("#ff1744")
	edge_mat.emission_enabled = true
	edge_mat.emission = Color("#ff1744")
	edge_mat.emission_energy_multiplier = 4.2
	edge.material_override = edge_mat
	edge.rotation.x = deg_to_rad(12.0)
	edge.position = Vector3(0, 1.4, -0.42)
	weapon_mesh.add_child(edge)

	var scythe_light := OmniLight3D.new()
	scythe_light.light_color = Color("#ff1744")
	scythe_light.light_energy = 2.2
	scythe_light.omni_range = 3.0
	scythe_blade.add_child(scythe_light)

func _build_hammer_cannon() -> void:
	# Martelo-Canhão Dourado/Azul Rúnico
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.036
	shaft_cyl.bottom_radius = 0.036
	shaft_cyl.height = 1.15
	shaft.mesh = shaft_cyl
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#d4af37")
	gold_mat.metallic = 0.9
	gold_mat.roughness = 0.25
	shaft.material_override = gold_mat
	shaft.position = Vector3(0, 0.4, 0)
	weapon_mesh.add_child(shaft)

	var hammer_back := MeshInstance3D.new()
	var back_box := BoxMesh.new()
	back_box.size = Vector3(0.28, 0.32, 0.26)
	hammer_back.mesh = back_box
	hammer_back.material_override = gold_mat
	hammer_back.position = Vector3(0, 0.88, 0.13)
	weapon_mesh.add_child(hammer_back)

	# Cano do Canhão frontal
	var barrel := MeshInstance3D.new()
	var barrel_cyl := CylinderMesh.new()
	barrel_cyl.top_radius = 0.11
	barrel_cyl.bottom_radius = 0.11
	barrel_cyl.height = 0.42
	barrel.mesh = barrel_cyl
	barrel.material_override = gold_mat
	barrel.rotation.x = deg_to_rad(90.0)
	barrel.position = Vector3(0, 0.88, -0.18)
	weapon_mesh.add_child(barrel)

	# Núcleo de Energia Rúnica Azul Celeste no cano
	var rune_core := MeshInstance3D.new()
	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.08
	core_sphere.height = 0.16
	rune_core.mesh = core_sphere
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color("#00e5ff")
	rune_mat.emission_enabled = true
	rune_mat.emission = Color("#00e5ff")
	rune_mat.emission_energy_multiplier = 4.5
	rune_core.material_override = rune_mat
	rune_core.position = Vector3(0, 0.88, -0.38)
	weapon_mesh.add_child(rune_core)

	var rune_light := OmniLight3D.new()
	rune_light.light_color = Color("#00e5ff")
	rune_light.light_energy = 2.6
	rune_light.omni_range = 3.6
	rune_core.add_child(rune_light)

func _build_homunculus_orb() -> void:
	# Orbe Alquímico Carmesim na mão
	var hand_orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.15
	orb_mesh.height = 0.3
	hand_orb.mesh = orb_mesh
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color("#d50000")
	orb_mat.emission_enabled = true
	orb_mat.emission = Color("#ff1744")
	orb_mat.emission_energy_multiplier = 3.8
	hand_orb.material_override = orb_mat
	hand_orb.position = Vector3(0, 0.35, 0)
	weapon_mesh.add_child(hand_orb)

	var hand_light := OmniLight3D.new()
	hand_light.light_color = Color("#ff1744")
	hand_light.light_energy = 2.2
	hand_light.omni_range = 2.8
	hand_orb.add_child(hand_light)

	# Mini-homúnculo flutuante orbitando o jogador
	homunculus_orbiter = MeshInstance3D.new()
	homunculus_orbiter.name = "HomunculusCompanion"
	var comp_mesh := SphereMesh.new()
	comp_mesh.radius = 0.17
	comp_mesh.height = 0.34
	homunculus_orbiter.mesh = comp_mesh
	var comp_mat := StandardMaterial3D.new()
	comp_mat.albedo_color = Color("#ba68c8")
	comp_mat.metallic = 0.2
	comp_mat.roughness = 0.3
	comp_mat.emission_enabled = true
	comp_mat.emission = Color("#e040fb")
	comp_mat.emission_energy_multiplier = 2.2
	homunculus_orbiter.material_override = comp_mat

	# Olhos cintilantes do Homúnculo
	for eye_x in [-0.06, 0.06]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color("#00e5ff")
		eye_mat.emission_enabled = true
		eye_mat.emission = Color("#00e5ff")
		eye_mat.emission_energy_multiplier = 4.0
		eye.material_override = eye_mat
		eye.position = Vector3(eye_x, 0.04, 0.14)
		homunculus_orbiter.add_child(eye)

	var comp_light := OmniLight3D.new()
	comp_light.light_color = Color("#e040fb")
	comp_light.light_energy = 1.8
	comp_light.omni_range = 2.4
	homunculus_orbiter.add_child(comp_light)

	add_child(homunculus_orbiter)

func _build_astral_blades() -> void:
	# Lâmina Estelar Principal (Mão Direita)
	var silver_mat := StandardMaterial3D.new()
	silver_mat.albedo_color = Color(0.92, 0.96, 1.0)
	silver_mat.metallic = 0.95
	silver_mat.roughness = 0.1
	silver_mat.emission_enabled = true
	silver_mat.emission = Color("#00e5ff")
	silver_mat.emission_energy_multiplier = 2.4

	var cyan_edge_mat := StandardMaterial3D.new()
	cyan_edge_mat.albedo_color = Color("#18ffff")
	cyan_edge_mat.emission_enabled = true
	cyan_edge_mat.emission = Color("#00e5ff")
	cyan_edge_mat.emission_energy_multiplier = 4.2

	var dark_hilt_mat := StandardMaterial3D.new()
	dark_hilt_mat.albedo_color = Color(0.18, 0.22, 0.28)
	dark_hilt_mat.metallic = 0.9
	dark_hilt_mat.roughness = 0.25

	# Lâmina 1 (Mão Direita)
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.04, 1.05, 0.015)
	blade.mesh = blade_box
	blade.material_override = silver_mat
	blade.position = Vector3(0, 0.52, 0)
	weapon_mesh.add_child(blade)

	var edge_glow := MeshInstance3D.new()
	var edge_box := BoxMesh.new()
	edge_box.size = Vector3(0.05, 1.06, 0.005)
	edge_glow.mesh = edge_box
	edge_glow.material_override = cyan_edge_mat
	edge_glow.position = Vector3(0, 0.52, 0)
	weapon_mesh.add_child(edge_glow)

	var guard := MeshInstance3D.new()
	var guard_torus := TorusMesh.new()
	guard_torus.inner_radius = 0.04
	guard_torus.outer_radius = 0.09
	guard.mesh = guard_torus
	guard.material_override = cyan_edge_mat
	guard.rotation.x = deg_to_rad(90.0)
	guard.position = Vector3(0, 0.02, 0)
	weapon_mesh.add_child(guard)

	var hilt := MeshInstance3D.new()
	var hilt_cyl := CylinderMesh.new()
	hilt_cyl.top_radius = 0.02
	hilt_cyl.bottom_radius = 0.02
	hilt_cyl.height = 0.24
	hilt.mesh = hilt_cyl
	hilt.material_override = dark_hilt_mat
	hilt.position = Vector3(0, -0.12, 0)
	weapon_mesh.add_child(hilt)

	var light_main := OmniLight3D.new()
	light_main.light_color = Color("#00e5ff")
	light_main.light_energy = 1.8
	light_main.omni_range = 2.4
	weapon_mesh.add_child(light_main)

	# Lâmina Estelar Secundária (Mão Esquerda / Offhand)
	if offhand_pivot:
		var off_blade := MeshInstance3D.new()
		off_blade.mesh = blade_box
		off_blade.material_override = silver_mat
		off_blade.position = Vector3(0, 0.52, 0)
		offhand_pivot.add_child(off_blade)

		var off_edge := MeshInstance3D.new()
		off_edge.mesh = edge_box
		off_edge.material_override = cyan_edge_mat
		off_edge.position = Vector3(0, 0.52, 0)
		offhand_pivot.add_child(off_edge)

		var off_guard := MeshInstance3D.new()
		off_guard.mesh = guard_torus
		off_guard.material_override = cyan_edge_mat
		off_guard.rotation.x = deg_to_rad(90.0)
		off_guard.position = Vector3(0, 0.02, 0)
		offhand_pivot.add_child(off_guard)

		var off_hilt := MeshInstance3D.new()
		off_hilt.mesh = hilt_cyl
		off_hilt.material_override = dark_hilt_mat
		off_hilt.position = Vector3(0, -0.12, 0)
		offhand_pivot.add_child(off_hilt)

		var light_off := OmniLight3D.new()
		light_off.light_color = Color("#00e5ff")
		light_off.light_energy = 1.8
		light_off.omni_range = 2.4
		offhand_pivot.add_child(light_off)

func _build_ash_flail_and_chains() -> void:
	# Empunhadura de ferro negro das cinzas
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.12, 0.12, 0.14)
	iron_mat.metallic = 0.9
	iron_mat.roughness = 0.3

	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color("#d50000")
	ember_mat.emission_enabled = true
	ember_mat.emission = Color("#ff1744")
	ember_mat.emission_energy_multiplier = 4.5

	# Cabo do Mangual
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.035
	shaft_cyl.height = 0.48
	shaft.mesh = shaft_cyl
	shaft.material_override = iron_mat
	shaft.position = Vector3(0, 0.1, 0)
	weapon_mesh.add_child(shaft)

	# Anéis e garras do topo
	var cap := MeshInstance3D.new()
	var cap_ring := TorusMesh.new()
	cap_ring.inner_radius = 0.03
	cap_ring.outer_radius = 0.06
	cap.mesh = cap_ring
	cap.material_override = ember_mat
	cap.position = Vector3(0, 0.35, 0)
	weapon_mesh.add_child(cap)

	# Elos da corrente incandescente pendendo
	for i in range(3):
		var link := MeshInstance3D.new()
		var link_torus := TorusMesh.new()
		link_torus.inner_radius = 0.025
		link_torus.outer_radius = 0.05
		link.mesh = link_torus
		link.material_override = ember_mat
		if i % 2 == 1:
			link.rotation.y = deg_to_rad(90.0)
		link.position = Vector3(0, 0.35 - (i + 1) * 0.09, -i * 0.05)
		weapon_mesh.add_child(link)

	# Cabeça espinhosa do Mangual (Incandescente carmesim)
	var flail_head := MeshInstance3D.new()
	var head_sphere := SphereMesh.new()
	head_sphere.radius = 0.13
	head_sphere.height = 0.26
	flail_head.mesh = head_sphere
	flail_head.material_override = ember_mat
	flail_head.position = Vector3(0, 0.04, -0.16)
	weapon_mesh.add_child(flail_head)

	# Espinhos pontiagudos ao redor da cabeça
	for angle in [0, 60, 120, 180, 240, 300]:
		var spike := MeshInstance3D.new()
		var spike_cone := CylinderMesh.new()
		spike_cone.top_radius = 0.0
		spike_cone.bottom_radius = 0.03
		spike_cone.height = 0.12
		spike.mesh = spike_cone
		spike.material_override = iron_mat
		spike.rotation.z = deg_to_rad(angle)
		spike.position = flail_head.position + Vector3(sin(deg_to_rad(angle)) * 0.13, cos(deg_to_rad(angle)) * 0.13, 0)
		weapon_mesh.add_child(spike)

	var flame_light := OmniLight3D.new()
	flame_light.light_color = Color("#ff1744")
	flame_light.light_energy = 2.6
	flame_light.omni_range = 2.8
	weapon_mesh.add_child(flame_light)

	# Correntes incandescentes no braço esquerdo (Offhand)
	if offhand_pivot:
		var off_chain := MeshInstance3D.new()
		var off_torus := TorusMesh.new()
		off_torus.inner_radius = 0.07
		off_torus.outer_radius = 0.11
		off_chain.mesh = off_torus
		off_chain.material_override = ember_mat
		off_chain.rotation.x = deg_to_rad(90.0)
		off_chain.position = Vector3(0, 0.05, 0)
		offhand_pivot.add_child(off_chain)

		var brand := MeshInstance3D.new()
		var brand_box := BoxMesh.new()
		brand_box.size = Vector3(0.12, 0.12, 0.03)
		brand.mesh = brand_box
		brand.material_override = ember_mat
		brand.position = Vector3(0, 0.05, -0.1)
		offhand_pivot.add_child(brand)

func _build_bone_staff() -> void:
	# Cajado de osso pálido
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.91, 0.9, 0.84)
	bone_mat.roughness = 0.65

	var emerald_mat := StandardMaterial3D.new()
	emerald_mat.albedo_color = Color("#00e676")
	emerald_mat.emission_enabled = true
	emerald_mat.emission = Color("#00e676")
	emerald_mat.emission_energy_multiplier = 4.2
	emerald_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emerald_mat.albedo_color.a = 0.9

	# Haste de osso
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.032
	shaft_cyl.bottom_radius = 0.042
	shaft_cyl.height = 1.55
	shaft.mesh = shaft_cyl
	shaft.material_override = bone_mat
	shaft.position = Vector3(0, 0.45, 0)
	weapon_mesh.add_child(shaft)

	# Anéis de vértebras ao longo do cajado
	for y_off in [0.0, 0.4, 0.8]:
		var vert := MeshInstance3D.new()
		var vert_torus := TorusMesh.new()
		vert_torus.inner_radius = 0.038
		vert_torus.outer_radius = 0.065
		vert.mesh = vert_torus
		vert.material_override = bone_mat
		vert.position = Vector3(0, y_off, 0)
		weapon_mesh.add_child(vert)

	# Crânio de cristal verde-esmeralda no topo
	var cranium := MeshInstance3D.new()
	var cranium_sphere := SphereMesh.new()
	cranium_sphere.radius = 0.13
	cranium_sphere.height = 0.22
	cranium.mesh = cranium_sphere
	cranium.material_override = emerald_mat
	cranium.position = Vector3(0, 1.25, 0)
	weapon_mesh.add_child(cranium)

	var jaw := MeshInstance3D.new()
	var jaw_box := BoxMesh.new()
	jaw_box.size = Vector3(0.11, 0.08, 0.12)
	jaw.mesh = jaw_box
	jaw.material_override = emerald_mat
	jaw.position = Vector3(0, 1.15, -0.04)
	weapon_mesh.add_child(jaw)

	# Olhos do crânio com luz concentrada
	for eye_x in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		var eye_sphere := SphereMesh.new()
		eye_sphere.radius = 0.025
		eye_sphere.height = 0.05
		eye.mesh = eye_sphere
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color("#b9f6ca")
		eye_mat.emission_enabled = true
		eye_mat.emission = Color("#69f0ae")
		eye_mat.emission_energy_multiplier = 5.0
		eye.material_override = eye_mat
		eye.position = Vector3(eye_x, 1.26, -0.1)
		weapon_mesh.add_child(eye)

	# Chifres/costelas de osso coroando o crânio
	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var horn_cone := CylinderMesh.new()
		horn_cone.top_radius = 0.0
		horn_cone.bottom_radius = 0.025
		horn_cone.height = 0.28
		horn.mesh = horn_cone
		horn.material_override = bone_mat
		horn.rotation.z = deg_to_rad(35.0 * side)
		horn.position = Vector3(side * 0.12, 1.35, 0)
		weapon_mesh.add_child(horn)

	var staff_light := OmniLight3D.new()
	staff_light.light_color = Color("#00e676")
	staff_light.light_energy = 2.8
	staff_light.omni_range = 3.2
	cranium.add_child(staff_light)

	# Relicário de osso na mão esquerda
	if offhand_pivot:
		var off_relic := MeshInstance3D.new()
		var relic_box := BoxMesh.new()
		relic_box.size = Vector3(0.12, 0.18, 0.08)
		off_relic.mesh = relic_box
		off_relic.material_override = bone_mat
		off_relic.position = Vector3(0, 0.1, 0)
		offhand_pivot.add_child(off_relic)

		var rune_core := MeshInstance3D.new()
		var rune_sph := SphereMesh.new()
		rune_sph.radius = 0.04
		rune_sph.height = 0.08
		rune_core.mesh = rune_sph
		rune_core.material_override = emerald_mat
		rune_core.position = Vector3(0, 0.1, -0.05)
		offhand_pivot.add_child(rune_core)

func _build_primordial_spear_and_wolf() -> void:
	# Lança de caça selvagem
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("#3e2723")
	wood_mat.roughness = 0.75

	var wrap_mat := StandardMaterial3D.new()
	wrap_mat.albedo_color = Color("#795548")
	wrap_mat.roughness = 0.6

	var spearhead_mat := StandardMaterial3D.new()
	spearhead_mat.albedo_color = Color("#cfd8dc")
	spearhead_mat.metallic = 0.8
	spearhead_mat.roughness = 0.2
	spearhead_mat.emission_enabled = true
	spearhead_mat.emission = Color("#80d8ff")
	spearhead_mat.emission_energy_multiplier = 2.0

	var bone_accent_mat := StandardMaterial3D.new()
	bone_accent_mat.albedo_color = Color("#e8e5d8")
	bone_accent_mat.roughness = 0.5

	# Haste longa de madeira ancestral
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.034
	shaft_cyl.height = 1.95
	shaft.mesh = shaft_cyl
	shaft.material_override = wood_mat
	shaft.position = Vector3(0, 0.65, 0)
	weapon_mesh.add_child(shaft)

	# Faixas de couro de pegada
	var grip := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius = 0.036
	grip_cyl.bottom_radius = 0.036
	grip_cyl.height = 0.36
	grip.mesh = grip_cyl
	grip.material_override = wrap_mat
	grip.position = Vector3(0, 0.15, 0)
	weapon_mesh.add_child(grip)

	# Ponta serrada da lança
	var spearhead := MeshInstance3D.new()
	var spear_box := BoxMesh.new()
	spear_box.size = Vector3(0.12, 0.52, 0.025)
	spearhead.mesh = spear_box
	spearhead.material_override = spearhead_mat
	spearhead.position = Vector3(0, 1.7, 0)
	weapon_mesh.add_child(spearhead)

	# Presas de besta penduradas na base da ponta
	for side in [-1.0, 1.0]:
		var fang := MeshInstance3D.new()
		var fang_cone := CylinderMesh.new()
		fang_cone.top_radius = 0.0
		fang_cone.bottom_radius = 0.02
		fang_cone.height = 0.12
		fang.mesh = fang_cone
		fang.material_override = bone_accent_mat
		fang.rotation.x = deg_to_rad(180.0)
		fang.rotation.z = deg_to_rad(side * 20.0)
		fang.position = Vector3(side * 0.06, 1.42, 0)
		weapon_mesh.add_child(fang)

	# Lobo Espiritual Prateado Translúcido Acompanhante
	spirit_wolf_companion = Node3D.new()
	spirit_wolf_companion.name = "SpiritWolfCompanion"

	var wolf_mat := StandardMaterial3D.new()
	wolf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wolf_mat.albedo_color = Color(0.72, 0.88, 1.0, 0.62)
	wolf_mat.emission_enabled = true
	wolf_mat.emission = Color("#80d8ff")
	wolf_mat.emission_energy_multiplier = 2.4
	wolf_mat.roughness = 0.2

	# Corpo/Tronco do Lobo
	var body_node := MeshInstance3D.new()
	var body_capsule := CapsuleMesh.new()
	body_capsule.radius = 0.18
	body_capsule.height = 0.65
	body_node.mesh = body_capsule
	body_node.material_override = wolf_mat
	body_node.rotation.x = deg_to_rad(90.0)
	spirit_wolf_companion.add_child(body_node)

	# Peitoral e cernelha
	var chest := MeshInstance3D.new()
	var chest_box := BoxMesh.new()
	chest_box.size = Vector3(0.32, 0.36, 0.32)
	chest.mesh = chest_box
	chest.material_override = wolf_mat
	chest.position = Vector3(0, 0.08, -0.22)
	spirit_wolf_companion.add_child(chest)

	# Cabeça do Lobo
	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.22, 0.18, 0.26)
	head.mesh = head_box
	head.material_override = wolf_mat
	head.position = Vector3(0, 0.24, -0.42)
	spirit_wolf_companion.add_child(head)

	# Focinho alongado
	var snout := MeshInstance3D.new()
	var snout_box := BoxMesh.new()
	snout_box.size = Vector3(0.12, 0.1, 0.2)
	snout.mesh = snout_box
	snout.material_override = wolf_mat
	snout.position = Vector3(0, 0.19, -0.58)
	spirit_wolf_companion.add_child(snout)

	# Orelhas pontudas
	for ear_x in [-0.08, 0.08]:
		var ear := MeshInstance3D.new()
		var ear_prism := PrismMesh.new()
		ear_prism.size = Vector3(0.07, 0.12, 0.05)
		ear.mesh = ear_prism
		ear.material_override = wolf_mat
		ear.position = Vector3(ear_x, 0.38, -0.4)
		spirit_wolf_companion.add_child(ear)

	# Olhos espectrais cintilantes
	for eye_x in [-0.05, 0.05]:
		var eye := MeshInstance3D.new()
		var eye_sph := SphereMesh.new()
		eye_sph.radius = 0.025
		eye_sph.height = 0.05
		eye.mesh = eye_sph
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color("#00e5ff")
		eye_mat.emission_enabled = true
		eye_mat.emission = Color("#00e5ff")
		eye_mat.emission_energy_multiplier = 4.5
		eye.material_override = eye_mat
		eye.position = Vector3(eye_x, 0.26, -0.54)
		spirit_wolf_companion.add_child(eye)

	# Cauda espectral arqueada
	var tail := MeshInstance3D.new()
	var tail_cyl := CylinderMesh.new()
	tail_cyl.top_radius = 0.02
	tail_cyl.bottom_radius = 0.06
	tail_cyl.height = 0.42
	tail.mesh = tail_cyl
	tail.material_override = wolf_mat
	tail.rotation.x = deg_to_rad(-45.0)
	tail.position = Vector3(0, 0.12, 0.42)
	spirit_wolf_companion.add_child(tail)

	# 4 Patas espectrais
	for pos in [Vector3(-0.12, -0.2, -0.2), Vector3(0.12, -0.2, -0.2), Vector3(-0.12, -0.2, 0.2), Vector3(0.12, -0.2, 0.2)]:
		var paw := MeshInstance3D.new()
		var paw_cyl := CylinderMesh.new()
		paw_cyl.top_radius = 0.045
		paw_cyl.bottom_radius = 0.03
		paw_cyl.height = 0.28
		paw.mesh = paw_cyl
		paw.material_override = wolf_mat
		paw.position = pos
		spirit_wolf_companion.add_child(paw)

	var wolf_light := OmniLight3D.new()
	wolf_light.light_color = Color("#80d8ff")
	wolf_light.light_energy = 1.8
	wolf_light.omni_range = 3.0
	spirit_wolf_companion.add_child(wolf_light)

	add_child(spirit_wolf_companion)

func _build_void_greatsword_and_shield() -> void:
	# Espada colossal negra com borda roxa gravitacional
	var void_black_mat := StandardMaterial3D.new()
	void_black_mat.albedo_color = Color(0.06, 0.06, 0.08)
	void_black_mat.metallic = 0.95
	void_black_mat.roughness = 0.2

	var gravity_purple_mat := StandardMaterial3D.new()
	gravity_purple_mat.albedo_color = Color("#7c4dff")
	gravity_purple_mat.emission_enabled = true
	gravity_purple_mat.emission = Color("#b388ff")
	gravity_purple_mat.emission_energy_multiplier = 3.8

	# Lâmina Colossal Negra
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.22, 1.68, 0.055)
	blade.mesh = blade_box
	blade.material_override = void_black_mat
	blade.position = Vector3(0, 0.88, 0)
	weapon_mesh.add_child(blade)

	# Bordas gravitacionais roxas (Esquerda e Direita)
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_box := BoxMesh.new()
		edge_box.size = Vector3(0.025, 1.7, 0.065)
		edge.mesh = edge_box
		edge.material_override = gravity_purple_mat
		edge.position = Vector3(side * 0.11, 0.88, 0)
		weapon_mesh.add_child(edge)

	# Guarda do Vazio Angular
	var guard := MeshInstance3D.new()
	var guard_box := BoxMesh.new()
	guard_box.size = Vector3(0.48, 0.08, 0.12)
	guard.mesh = guard_box
	guard.material_override = void_black_mat
	guard.position = Vector3(0, 0.04, 0)
	weapon_mesh.add_child(guard)

	# Orbe de Singularidade Gravitacional no centro da guarda
	var core_orb := MeshInstance3D.new()
	var core_sph := SphereMesh.new()
	core_sph.radius = 0.05
	core_sph.height = 0.1
	core_orb.mesh = core_sph
	core_orb.material_override = gravity_purple_mat
	core_orb.position = Vector3(0, 0.04, 0)
	weapon_mesh.add_child(core_orb)

	# Empunhadura de duas mãos
	var hilt := MeshInstance3D.new()
	var hilt_cyl := CylinderMesh.new()
	hilt_cyl.top_radius = 0.028
	hilt_cyl.bottom_radius = 0.028
	hilt_cyl.height = 0.42
	hilt.mesh = hilt_cyl
	hilt.material_override = void_black_mat
	hilt.position = Vector3(0, -0.21, 0)
	weapon_mesh.add_child(hilt)

	var pommel := MeshInstance3D.new()
	var pommel_box := BoxMesh.new()
	pommel_box.size = Vector3(0.08, 0.08, 0.08)
	pommel.mesh = pommel_box
	pommel.material_override = gravity_purple_mat
	pommel.position = Vector3(0, -0.44, 0)
	weapon_mesh.add_child(pommel)

	# Escudo Pesado do Vazio (Offhand)
	if offhand_pivot:
		var shield := MeshInstance3D.new()
		var shield_box := BoxMesh.new()
		shield_box.size = Vector3(0.62, 0.96, 0.08)
		shield.mesh = shield_box
		shield.material_override = void_black_mat
		shield.position = Vector3(0, 0.1, 0)
		offhand_pivot.add_child(shield)

		var rim := MeshInstance3D.new()
		var rim_box := BoxMesh.new()
		rim_box.size = Vector3(0.66, 1.0, 0.05)
		rim.mesh = rim_box
		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = Color("#263238")
		rim_mat.metallic = 0.9
		rim.material_override = rim_mat
		rim.position = Vector3(0, 0.1, -0.02)
		offhand_pivot.add_child(rim)

		# Fenda do Vazio central
		var rift_orb := MeshInstance3D.new()
		var rift_sph := SphereMesh.new()
		rift_sph.radius = 0.14
		rift_sph.height = 0.08
		rift_orb.mesh = rift_sph
		rift_orb.material_override = gravity_purple_mat
		rift_orb.position = Vector3(0, 0.1, -0.06)
		offhand_pivot.add_child(rift_orb)

		var rift_ring := MeshInstance3D.new()
		var ring_torus := TorusMesh.new()
		ring_torus.inner_radius = 0.15
		ring_torus.outer_radius = 0.22
		rift_ring.mesh = ring_torus
		rift_ring.material_override = gravity_purple_mat
		rift_ring.rotation.x = deg_to_rad(90.0)
		rift_ring.position = Vector3(0, 0.1, -0.06)
		offhand_pivot.add_child(rift_ring)

		var shield_light := OmniLight3D.new()
		shield_light.light_color = Color("#7c4dff")
		shield_light.light_energy = 2.4
		shield_light.omni_range = 2.8
		offhand_pivot.add_child(shield_light)

func _build_storm_halberd() -> void:
	# Alabarda longa dourada crepitando com eletricidade azul
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#ffd700")
	gold_mat.metallic = 0.95
	gold_mat.roughness = 0.18

	var lightning_mat := StandardMaterial3D.new()
	lightning_mat.albedo_color = Color("#00e5ff")
	lightning_mat.emission_enabled = true
	lightning_mat.emission = Color("#00b0ff")
	lightning_mat.emission_energy_multiplier = 4.8

	# Haste Dourada Longa
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.035
	shaft_cyl.height = 2.05
	shaft.mesh = shaft_cyl
	shaft.material_override = gold_mat
	shaft.position = Vector3(0, 0.72, 0)
	weapon_mesh.add_child(shaft)

	# Lâmina de Machado da Alabarda (Lateral direita)
	var axe_blade := MeshInstance3D.new()
	var axe_box := BoxMesh.new()
	axe_box.size = Vector3(0.34, 0.45, 0.035)
	axe_blade.mesh = axe_box
	axe_blade.material_override = gold_mat
	axe_blade.position = Vector3(0.18, 1.55, 0)
	weapon_mesh.add_child(axe_blade)

	var axe_edge := MeshInstance3D.new()
	var edge_box := BoxMesh.new()
	edge_box.size = Vector3(0.04, 0.48, 0.04)
	axe_edge.mesh = edge_box
	axe_edge.material_override = lightning_mat
	axe_edge.position = Vector3(0.35, 1.55, 0)
	weapon_mesh.add_child(axe_edge)

	# Gancho/Pico perfurante traseiro (Lateral esquerda)
	var rear_spike := MeshInstance3D.new()
	var spike_box := BoxMesh.new()
	spike_box.size = Vector3(0.2, 0.08, 0.03)
	rear_spike.mesh = spike_box
	rear_spike.material_override = gold_mat
	rear_spike.position = Vector3(-0.12, 1.55, 0)
	weapon_mesh.add_child(rear_spike)

	# Ponta de Lança Superior
	var spear_tip := MeshInstance3D.new()
	var tip_cone := CylinderMesh.new()
	tip_cone.top_radius = 0.0
	tip_cone.bottom_radius = 0.045
	tip_cone.height = 0.52
	spear_tip.mesh = tip_cone
	spear_tip.material_override = lightning_mat
	spear_tip.position = Vector3(0, 1.95, 0)
	weapon_mesh.add_child(spear_tip)

	# Bobinas/Anéis condutores de eletricidade
	for ring_y in [1.32, 1.42]:
		var coil := MeshInstance3D.new()
		var coil_torus := TorusMesh.new()
		coil_torus.inner_radius = 0.04
		coil_torus.outer_radius = 0.075
		coil.mesh = coil_torus
		coil.material_override = lightning_mat
		coil.position = Vector3(0, ring_y, 0)
		weapon_mesh.add_child(coil)

	var storm_light := OmniLight3D.new()
	storm_light.light_color = Color("#00e5ff")
	storm_light.light_energy = 3.0
	storm_light.omni_range = 3.6
	spear_tip.add_child(storm_light)

	# Manopla do Trovão na mão esquerda (Offhand)
	if offhand_pivot:
		var bracer := MeshInstance3D.new()
		var bracer_cyl := CylinderMesh.new()
		bracer_cyl.top_radius = 0.075
		bracer_cyl.bottom_radius = 0.065
		bracer_cyl.height = 0.28
		bracer.mesh = bracer_cyl
		bracer.material_override = gold_mat
		bracer.position = Vector3(0, 0.08, 0)
		offhand_pivot.add_child(bracer)

		var bracer_coil := MeshInstance3D.new()
		var b_torus := TorusMesh.new()
		b_torus.inner_radius = 0.078
		b_torus.outer_radius = 0.095
		bracer_coil.mesh = b_torus
		bracer_coil.material_override = lightning_mat
		bracer_coil.position = Vector3(0, 0.08, 0)
		offhand_pivot.add_child(bracer_coil)

func _create_emissive_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m

func _physics_process(delta: float) -> void:
	weight_speed_mult = get_weight_speed_mult()

	# Proteção contra o Abismo / Void
	if global_position.y < -10.0:
		global_position = Vector3(0.0, 1.5, 0.0)
		velocity = Vector3.ZERO
		if NetworkManager and NetworkManager.my_player_id > 0:
			NetworkManager.send_player_move(global_position, rotation.y)

	camera_pivot.global_position = global_position + Vector3(0, 1.5, 0)

	# Atualiza órbita da estátua viva / mini-homúnculo (Classes 9 e 15)
	if current_class_id == 36 and homunculus_orbiter and is_instance_valid(homunculus_orbiter):
		homunculus_anim_time += delta
		var orbit_r: float = 1.15
		var orbit_spd: float = 3.2
		homunculus_orbiter.position = Vector3(
			cos(homunculus_anim_time * orbit_spd) * orbit_r,
			1.35 + sin(homunculus_anim_time * 4.5) * 0.18,
			sin(homunculus_anim_time * orbit_spd) * orbit_r
		)

	# Atualiza companheiro Fera Domada / Lobo Espiritual (Classes 10 e 19)
	if (current_class_id == 10 or current_class_id == 21 or current_class_id == 37) and spirit_wolf_companion and is_instance_valid(spirit_wolf_companion):
		spirit_wolf_anim_time += delta
		var wolf_bob: float = sin(spirit_wolf_anim_time * 3.2) * 0.12
		spirit_wolf_companion.position = Vector3(
			-1.15 + cos(spirit_wolf_anim_time * 1.4) * 0.1,
			0.5 + wolf_bob,
			0.35 + sin(spirit_wolf_anim_time * 1.4) * 0.12
		)
		spirit_wolf_companion.rotation.y = sin(spirit_wolf_anim_time * 1.8) * 0.12

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_dodging:
		dodge_timer -= delta
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		if dodge_timer <= 0.0:
			is_dodging = false
	else:
		if is_menu_open:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * 2.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, SPEED * 2.0 * delta)
		else:
			if Input.is_action_just_pressed("jump") and is_on_floor():
				velocity.y = JUMP_VELOCITY

			var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			var cam_yaw: float = camera_pivot.global_rotation.y
			var forward: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
			var right: Vector3 = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
			var move_dir: Vector3 = (forward * -input_dir.y + right * input_dir.x).normalized()

			if move_dir != Vector3.ZERO:
				var move_speed: float = SPEED * _path_speed_mult() * weight_speed_mult
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
				if not is_attacking:
					var target_yaw := atan2(-move_dir.x, -move_dir.z)
					rotation.y = lerp_angle(rotation.y, target_yaw, 15.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, SPEED * 2.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, SPEED * 2.0 * delta)

	move_and_slide()
	if race_model:
		race_model.set_move_speed(Vector2(velocity.x, velocity.z).length())

	network_timer += delta
	if network_timer >= NETWORK_TICK_INTERVAL:
		network_timer = 0.0
		if NetworkManager and NetworkManager.my_player_id > 0:
			NetworkManager.send_player_move(global_position, rotation.y)
