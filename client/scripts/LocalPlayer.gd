extends CharacterBody3D

signal identity_changed(race_id: int, class_id: int)

const SPEED: float = 8.0
const DODGE_SPEED: float = 18.0
const JUMP_VELOCITY: float = 6.0
const MOUSE_SENSITIVITY: float = 0.003
const NETWORK_TICK_INTERVAL: float = 0.05 # 20 Hz (a cada 50ms)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var network_timer: float = 0.0

var current_race_id: int = 1   # 1=Valeriano, 2=Noctari, 3=Kharad, 4=Varkai, 5=Dhampir
var current_class_id: int = 1  # 1=Espadachim, 2=Batedor, 3=Iniciado, 4=Acólito

var is_attacking: bool = false
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var attack_cooldown: float = 0.0
var is_menu_open: bool = false

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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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

	_setup_crosshair()
	_apply_race_visuals()
	_apply_class_visuals()

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

	# Action Combat Inputs
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_perform_basic_attack()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_perform_special_skill()
			KEY_SHIFT:
				_perform_dodge_roll()
			KEY_1:
				_change_class(1)
			KEY_2:
				_change_class(2)
			KEY_3:
				_change_class(3)
			KEY_4:
				_change_class(4)
			KEY_F1:
				_change_race(1)
			KEY_F2:
				_change_race(2)
			KEY_F3:
				_change_race(3)
			KEY_F4:
				_change_race(4)
			KEY_F5:
				_change_race(5)

func _get_aim_direction() -> Vector3:
	if camera:
		var cam_forward: Vector3 = -camera.global_transform.basis.z
		var flat_dir := Vector3(cam_forward.x, 0.0, cam_forward.z).normalized()
		if flat_dir.length_squared() > 0.001:
			return flat_dir
	var cam_yaw: float = camera_pivot.global_rotation.y
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw)).normalized()

func _perform_basic_attack() -> void:
	if is_menu_open or is_attacking or is_dodging or attack_cooldown > 0.0:
		return

	is_attacking = true
	attack_cooldown = 0.35

	var aim_dir := _get_aim_direction()
	var target_yaw := atan2(-aim_dir.x, -aim_dir.z)
	rotation.y = target_yaw

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

	if NetworkManager and NetworkManager.my_player_id > 0:
		NetworkManager.send_player_action(3, aim_dir)

	_animate_attack_visual(3)

func _animate_attack_visual(action_type: int) -> void:
	if not weapon_pivot:
		is_attacking = false
		return

	match current_class_id:
		2: # Batedor: Puxada da corda do Arco e disparo veloz
			var tw := create_tween().set_parallel(false)
			if action_type == 3: # Skill Q: Disparo Perfurante concentrado
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
			if action_type == 3: # Skill Q: Cometa Elemental com giro e impulso
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
			if action_type == 3: # Skill Q: Oração/Cura em área
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

		_: # Espadachim: Corte em arco e giro de 360 no Q
			var tw := create_tween().set_parallel(false)
			if action_type == 3: # Skill Q: Corte Crescente giratório
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

	body_mesh.material_override = mat

func _apply_class_visuals() -> void:
	if not weapon_mesh:
		return

	# Limpa nós de armas anteriores
	for child in weapon_mesh.get_children():
		child.queue_free()

	if offhand_pivot:
		for child in offhand_pivot.get_children():
			child.queue_free()

	match current_class_id:
		1: # Espadachim: Espada Longa Prateada + Escudo na mão esquerda
			_build_sword_and_shield()
		2: # Batedor: Arco Curvo de Caça
			_build_bow()
		3: # Iniciado: Cajado Rúnico com Orbe Arcano
			_build_staff()
		4: # Acólito: Maça Dourada + Talismã Sagrado Luminoso
			_build_mace_and_talisman()

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

func _create_emissive_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m

func _physics_process(delta: float) -> void:
	camera_pivot.global_position = global_position + Vector3(0, 1.5, 0)

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

	network_timer += delta
	if network_timer >= NETWORK_TICK_INTERVAL:
		network_timer = 0.0
		if NetworkManager and NetworkManager.my_player_id > 0:
			NetworkManager.send_player_move(global_position, rotation.y)
