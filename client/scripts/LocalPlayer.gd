extends CharacterBody3D

signal identity_changed(race_id: int, class_id: int)
signal action_triggered(action_type: int)

const SPEED: float = 8.0
const DODGE_SPEED: float = 18.0
const JUMP_VELOCITY: float = 6.0
const MOUSE_SENSITIVITY: float = 0.003
const NETWORK_TICK_INTERVAL: float = 0.05 # 20 Hz (a cada 50ms)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var network_timer: float = 0.0

var current_race_id: int = 1   # 1=Valeriano, 2=Noctari, 3=Kharad, 4=Varkai, 5=Dhampir
var current_class_id: int = 1  # 1..9

var is_attacking: bool = false
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var attack_cooldown: float = 0.0
var is_menu_open: bool = false
var skill_slot_bindings: Dictionary = {
	"LMB": 1,
	"Q": 3,
	"R": 4,
	"F": 5,
	"Z": 6
}

var homunculus_orbiter: Node3D = null
var homunculus_anim_time: float = 0.0

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

const RaceModel = preload("res://scripts/models/RaceModel.gd")
var race_model: RaceModel = null
var _capsule_mesh: Mesh = null

func _ready() -> void:
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
	if is_menu_open:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-70.0), deg_to_rad(55.0))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Action Combat Inputs (quando o cursor está capturado e menu fechado)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("attack_basic") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			trigger_action_by_id(skill_slot_bindings.get("LMB", 1))
		elif event.is_action_pressed("dodge_roll") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT):
			_perform_dodge_roll()
		elif event.is_action_pressed("skill_1") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q):
			trigger_action_by_id(skill_slot_bindings.get("Q", 3))
		elif event.is_action_pressed("skill_2") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R):
			trigger_action_by_id(skill_slot_bindings.get("R", 4))
		elif event.is_action_pressed("skill_3") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F):
			trigger_action_by_id(skill_slot_bindings.get("F", 5))
		elif event.is_action_pressed("skill_racial") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z):
			trigger_action_by_id(skill_slot_bindings.get("Z", 6))

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _change_class(1)
			KEY_2: _change_class(2)
			KEY_3: _change_class(3)
			KEY_4: _change_class(4)
			KEY_5: _change_class(5)
			KEY_6: _change_class(6)
			KEY_7: _change_class(7)
			KEY_8: _change_class(8)
			KEY_9: _change_class(9)
			KEY_F1: _change_race(1)
			KEY_F2: _change_race(2)
			KEY_F3: _change_race(3)
			KEY_F4: _change_race(4)
			KEY_F5: _change_race(5)

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
		1: return Color("#64b5f6") # Azul Espadachim
		2: return Color("#69f0ae") # Verde Batedor
		3: return Color("#00e5ff") # Ciano Arcano Iniciado
		4: return Color("#ffd54f") # Dourado Sagrado Acólito
		5: return Color("#ff6d00") # Laranja Brasa Ferreiro
		6: return Color("#00e676") # Verde Ácido Alquimista
		7: return Color("#d500f9") # Púrpura Abissal Ceifador
		8: return Color("#ffb300") # Dourado Mecânico Artífice
		9: return Color("#00b0ff") # Ciano Quimérico Homúnculo
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
		1, 11: return Color("#ffd700") # Valeriano / Alto Valeriano: Ouro Solar
		12: return Color("#ba68c8") # Andarilho do Éter: Púrpura Etéreo
		2, 13: return Color("#00e5ff") # Noctari / Arconte Lunar: Ciano Astral
		14: return Color("#7c4dff") # Espectro Umbral: Roxo Umbral
		3, 15: return Color("#ff9800") # Kharad / Guardião Rúnico: Laranja Magma
		16: return Color("#ff3d00") # Titã de Obsidiana: Vermelho Lava
		4, 17: return Color("#ff1744") # Varkai / Soberano Dracônico: Carmesim Dracônico
		18: return Color("#ad1457") # Fera do Frenesi: Magenta Sangue
		5: return Color("#d500f9") # Dhampir: Sangue Vampírico
		6: return Color("#ff6f00") # Licantropo Primordial: Feral Âmbar
		7: return Color("#69f0ae") # Revenant: Ectoplasma Espectral
		8: return Color("#fff59d") # Celestino: Branco Solar
		9: return Color("#18ffff") # Abissal: Azul Vazio
		10: return Color("#00e5ff") # Autômato Rúnico: Ciano Elétrico
		19: return Color("#4caf50") # Sylvari: Verde Floresta
		20: return Color("#9c27b0") # Esporiano / Myconid: Violeta Fúngico
		21: return Color("#eceff1") # Aracne: Seda Prateada
		22: return Color("#ff6d00") # Draconato de Cinzas: Magma Laranja
		23: return Color("#76ff03") # Quimera: Verde Ácido Mutante
		24: return Color("#80d8ff") # Boreal: Cristal Azul Gelo
		25: return Color("#006064") # Thalassiano: Azul Abissal
		26: return Color("#c62828") # Cambion: Vermelho Enxofre
		27: return Color("#ffd700") # Nephilim: Ouro e Sombra
		28: return Color("#ffd54f") # Errante Temporal: Areia Dourada
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

	# Efeitos Visuais 3D Específicos das 10 Novas Raças na Tecla Z
	match current_race_id:
		19: # Sylvari: Raízes brotando no chão
			_spawn_roots_fx(global_position)
		20: # Esporiano: Nuvem de esporos roxos
			_spawn_spores_fx(global_position)
		21: # Aracne: Disparo de seda prateada
			_spawn_web_fx(global_position, _get_aim_direction())
		22: # Draconato: Cone de fogo vulcânico e magma
			_spawn_magma_cone_fx(global_position, _get_aim_direction())
		23: # Quimera: Onda de choque mutante bio-ácida
			_spawn_chimera_fx(global_position)
		24: # Boreal: Anel de congelamento de gelo absoluto
			_spawn_frost_ring_fx(global_position)
		25: # Thalassiano: Erupção de gêiser d'água abissal
			_spawn_geyser_fx(global_position)
		26: # Cambion: Correntes incandescentes do tártaro
			_spawn_chains_fx(global_position)
		27: # Nephilim: Asas de luz solar e sombra negra
			_spawn_nephilim_fx(global_position)
		28: # Errante Temporal: Mostrador cronológico de areia dourada
			_spawn_chrono_dial_fx(global_position)

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
	var tw := create_tween().set_parallel(false)
	tw.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, 0.22)
	tw.finished.connect(func(): is_attacking = false)

func _animate_attack_visual(action_type: int) -> void:
	if not weapon_pivot:
		is_attacking = false
		return

	match current_class_id:
		2: # Batedor: Puxada da corda do Arco e disparo veloz
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

		3: # Iniciado: Canalização arcana / Impulso frontal do Cajado
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

		4: # Acólito: Golpe descendente de Maça e pulso do Talismã
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

		5, 8: # Ferreiro / Artífice Rúnico: Pancada de Martelo de Forja
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-85.0), deg_to_rad(20.0), 0.0), 0.12)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(75.0), 0.0, 0.0), 0.16)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.12)
			tw.finished.connect(func(): is_attacking = false)

		6, 9: # Alquimista / Homúnculo: Lançamento de Frascos
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-45.0), deg_to_rad(-35.0), 0.0), 0.1)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(45.0), deg_to_rad(25.0), 0.0), 0.12)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.12)
			tw.finished.connect(func(): is_attacking = false)

		7: # Ceifador do Eclipse: Golpe Giratório de Foice Colossal
			var tw := create_tween().set_parallel(false)
			tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-40.0), deg_to_rad(-80.0), deg_to_rad(70.0)), 0.08)
			tw.tween_property(weapon_pivot, "rotation:y", weapon_pivot.rotation.y + deg_to_rad(360.0), 0.28)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

		_: # Espadachim: Corte em arco e giro de 360
			var tw := create_tween().set_parallel(false)
			if action_type == 3 or action_type == 4 or action_type == 5:
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-35.0), deg_to_rad(-80.0), deg_to_rad(75.0)), 0.08)
				tw.tween_property(weapon_pivot, "rotation:y", weapon_pivot.rotation.y + deg_to_rad(360.0), 0.28)
			else: # Básico: Golpe diagonal
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(-45.0), deg_to_rad(-60.0), deg_to_rad(70.0)), 0.08)
				tw.tween_property(weapon_pivot, "rotation", Vector3(deg_to_rad(65.0), deg_to_rad(50.0), deg_to_rad(-45.0)), 0.12)
			tw.tween_property(weapon_pivot, "rotation", default_weapon_rot, 0.14)
			tw.finished.connect(func(): is_attacking = false)

func _perform_dodge_roll() -> void:
	if is_menu_open or is_dodging:
		return

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

	if body_mesh:
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

func _apply_race_visuals() -> void:
	if not body_mesh:
		return
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
		5: # Dhampir - Carmesim sombrio
			mat.albedo_color = Color("#210408")
			mat.metallic = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff1744"), 3.0)
		6: # Licantropo Primordial - Cinza feral
			mat.albedo_color = Color("#3e2723")
			mat.roughness = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffb74d"), 2.5)
		7: # Revenant - Ectoplasma sombrio
			mat.albedo_color = Color("#263238")
			mat.metallic = 0.1
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#69f0ae"), 2.5)
		8: # Celestino - Alvura sagrada
			mat.albedo_color = Color("#fff9c4")
			mat.metallic = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 3.0)
		9: # Abissal - Profundeza insondável
			mat.albedo_color = Color("#0d47a1")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#18ffff"), 2.8)
		10: # Autômato Rúnico - Placas de bronze e runas
			mat.albedo_color = Color("#3e2723")
			mat.metallic = 0.95
			mat.roughness = 0.2
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.2)
		11: # Alto Valeriano
			mat.albedo_color = Color("#ffd700")
			mat.metallic = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffea00"), 3.0)
		12: # Andarilho do Éter
			mat.albedo_color = Color("#4a148c")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ba68c8"), 2.5)
		13: # Arconte Lunar
			mat.albedo_color = Color("#006064")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 2.8)
		14: # Espectro Umbral
			mat.albedo_color = Color("#12005e")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#7c4dff"), 2.8)
		15: # Guardião Rúnico
			mat.albedo_color = Color("#4e342e")
			mat.metallic = 0.85
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff9800"), 2.5)
		16: # Titã de Obsidiana
			mat.albedo_color = Color("#212121")
			mat.metallic = 0.9
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff3d00"), 3.0)
		17: # Soberano Dracônico
			mat.albedo_color = Color("#880e4f")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 2.6)
		18: # Fera do Frenesi
			mat.albedo_color = Color("#4a0007")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff1744"), 3.0)
		19: # Sylvari - Verde-floresta
			mat.albedo_color = Color("#2e7d32")
			mat.roughness = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#4caf50"), 2.2)
		20: # Esporiano - Bioluminescente violeta/ciano
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
		22: # Draconato de Cinzas - Escamas negras com veias de magma
			mat.albedo_color = Color("#212121")
			mat.metallic = 0.8
			mat.roughness = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff6d00"), 3.2)
		23: # Quimera - Mutante verde-ácido
			mat.albedo_color = Color("#33691e")
			mat.roughness = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#76ff03"), 3.0)
		24: # Boreal - Cristal azul-gelo
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
		28: # Errante Temporal - Areia dourada cronológica
			mat.albedo_color = Color("#b28704")
			mat.metallic = 0.85
			mat.roughness = 0.3
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd54f"), 3.0)

	body_mesh.material_override = mat
	_update_race_model()

func _update_race_model() -> void:
	# Raças com modelo 3D próprio (19-28) substituem a cápsula padrão
	if race_model and is_instance_valid(race_model):
		race_model.queue_free()
	race_model = null
	if _capsule_mesh == null:
		_capsule_mesh = body_mesh.mesh
	if RaceModel.has_model(current_race_id):
		race_model = RaceModel.create(current_race_id) as RaceModel
		race_model.position = Vector3(0, -0.9, 0)
		body_mesh.add_child(race_model)
		body_mesh.mesh = null
		if visor_mesh:
			visor_mesh.visible = false
	else:
		body_mesh.mesh = _capsule_mesh
		if visor_mesh:
			visor_mesh.visible = true

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

	match current_class_id:
		1: # Espadachim: Espada Longa Prateada + Escudo na mão esquerda
			_build_sword_and_shield()
		2: # Batedor: Arco Curvo de Caça
			_build_bow()
		3: # Iniciado: Cajado Rúnico com Orbe Arcano
			_build_staff()
		4: # Acólito: Maça Dourada + Talismã Sagrado Luminoso
			_build_mace_and_talisman()
		5: # Ferreiro: Martelo de Forja Pesado com detalhes em brasa laranja incandescente
			_build_blacksmith_hammer()
		6: # Alquimista: Frasco Químico Verde Brilhante
			_build_alchemist_flasks()
		7: # Ceifador do Eclipse: Foice Colossal
			_build_scythe()
		8: # Artífice Rúnico: Martelo-Canhão Dourado/Azul Rúnico
			_build_hammer_cannon()
		9: # Criador de Homúnculos: Orbe Alquímico Carmesim + Mini-Homúnculo orbitando
			_build_homunculus_orb()

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

func _create_emissive_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m

func _physics_process(delta: float) -> void:
	# Proteção contra o Abismo / Void
	if global_position.y < -10.0:
		global_position = Vector3(0.0, 1.5, 0.0)
		velocity = Vector3.ZERO
		if NetworkManager and NetworkManager.my_player_id > 0:
			NetworkManager.send_player_move(global_position, rotation.y)

	camera_pivot.global_position = global_position + Vector3(0, 1.5, 0)

	# Atualiza órbita do mini-homúnculo (Classe 9)
	if current_class_id == 9 and homunculus_orbiter and is_instance_valid(homunculus_orbiter):
		homunculus_anim_time += delta
		var orbit_r: float = 1.15
		var orbit_spd: float = 3.2
		homunculus_orbiter.position = Vector3(
			cos(homunculus_anim_time * orbit_spd) * orbit_r,
			1.35 + sin(homunculus_anim_time * 4.5) * 0.18,
			sin(homunculus_anim_time * orbit_spd) * orbit_r
		)

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
				velocity.x = move_dir.x * SPEED
				velocity.z = move_dir.z * SPEED
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
