extends Node3D

var player_id: int = 0
var target_position: Vector3 = Vector3.ZERO
var target_rotation_y: float = 0.0

var current_race_id: int = 1
var current_class_id: int = 1

const INTERPOLATION_SPEED: float = 15.0

@onready var label: Label3D = $NameTag
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var visor_mesh: MeshInstance3D = $BodyMesh/VisorIndicator

var weapon_pivot: Node3D = null
var weapon_mesh: Node3D = null
var offhand_pivot: Node3D = null
var homunculus_orbiter: MeshInstance3D = null
var homunculus_anim_time: float = 0.0

const RaceModel = preload("res://scripts/models/RaceModel.gd")
var race_model: RaceModel = null
var _capsule_mesh: Mesh = null

func _ready() -> void:
	target_position = global_position
	target_rotation_y = rotation.y
	update_label()

	if not has_node("BodyMesh/WeaponPivot"):
		weapon_pivot = Node3D.new()
		weapon_pivot.name = "WeaponPivot"
		weapon_pivot.position = Vector3(0.38, 0.1, -0.25)
		body_mesh.add_child(weapon_pivot)

		weapon_mesh = Node3D.new()
		weapon_mesh.name = "WeaponMesh"
		weapon_pivot.add_child(weapon_mesh)
	else:
		weapon_pivot = $BodyMesh/WeaponPivot
		weapon_mesh = $BodyMesh/WeaponPivot/WeaponMesh

	if not has_node("BodyMesh/OffhandPivot"):
		offhand_pivot = Node3D.new()
		offhand_pivot.name = "OffhandPivot"
		offhand_pivot.position = Vector3(-0.38, 0.1, -0.2)
		body_mesh.add_child(offhand_pivot)
	else:
		offhand_pivot = $BodyMesh/OffhandPivot

	_apply_race_visuals()
	_apply_class_visuals()

func set_player_id(id: int) -> void:
	player_id = id
	update_label()

func apply_identity(race_id: int, class_id: int) -> void:
	current_race_id = race_id
	current_class_id = class_id
	_apply_race_visuals()
	_apply_class_visuals()
	update_label()

func update_label() -> void:
	if label:
		var r_names: Array[String] = ["", "Valeriano", "Noctari", "Kharad", "Varkai", "Dhampir"]
		var c_names: Array[String] = [
			"", "Espadachim", "Batedor", "Iniciado", "Acólito",
			"Ferreiro", "Alquimista", "Ceifador do Eclipse", "Artífice Rúnico", "Criador de Homúnculos"
		]
		var r_str: String = r_names[current_race_id] if current_race_id < r_names.size() else "Valeriano"
		var c_str: String = c_names[current_class_id] if current_class_id < c_names.size() else "Espadachim"
		label.text = "Player #%d\n[%s - %s]" % [player_id, r_str, c_str]

func update_network_transform(new_pos: Vector3, new_rot_y: float) -> void:
	target_position = new_pos
	target_rotation_y = new_rot_y

func _process(delta: float) -> void:
	var prev_pos: Vector3 = global_position
	global_position = global_position.lerp(target_position, INTERPOLATION_SPEED * delta)
	if race_model and delta > 0.0:
		var step := global_position - prev_pos
		race_model.set_move_speed(Vector2(step.x, step.z).length() / delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, INTERPOLATION_SPEED * delta)

	if current_class_id == 9 and homunculus_orbiter and is_instance_valid(homunculus_orbiter):
		homunculus_anim_time += delta
		var orbit_r: float = 1.15
		var orbit_spd: float = 3.2
		homunculus_orbiter.position = Vector3(
			cos(homunculus_anim_time * orbit_spd) * orbit_r,
			1.35 + sin(homunculus_anim_time * 4.5) * 0.18,
			sin(homunculus_anim_time * orbit_spd) * orbit_r
		)

func _apply_race_visuals() -> void:
	if not body_mesh:
		return
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.35
	mat.metallic = 0.25

	match current_race_id:
		1: # Valeriano
			mat.albedo_color = Color("#2962ff")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 2.0)
		2: # Noctari
			mat.albedo_color = Color("#4a148c")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#b388ff"), 2.5)
		3: # Kharad
			mat.albedo_color = Color("#5d4037")
			mat.metallic = 0.7
			mat.roughness = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffb74d"), 1.8)
		4: # Varkai
			mat.albedo_color = Color("#b71c1c")
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff5252"), 2.2)
		5: # Dhampir
			mat.albedo_color = Color("#210408")
			mat.metallic = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff1744"), 3.0)
		6: # Licantropo Primordial
			mat.albedo_color = Color("#3e2723")
			mat.roughness = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffb74d"), 2.5)
		7: # Revenant
			mat.albedo_color = Color("#263238")
			mat.metallic = 0.1
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#69f0ae"), 2.5)
		8: # Celestino
			mat.albedo_color = Color("#fff9c4")
			mat.metallic = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 3.0)
		9: # Abissal
			mat.albedo_color = Color("#0d47a1")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#18ffff"), 2.8)
		10: # Autômato Rúnico
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
		19: # Sylvari
			mat.albedo_color = Color("#2e7d32")
			mat.roughness = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#4caf50"), 2.2)
		20: # Esporiano
			mat.albedo_color = Color("#4a148c")
			mat.roughness = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.0)
		21: # Aracne
			mat.albedo_color = Color("#eceff1")
			mat.metallic = 0.3
			mat.roughness = 0.2
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#b71c1c"), 3.0)
		22: # Draconato de Cinzas
			mat.albedo_color = Color("#212121")
			mat.metallic = 0.8
			mat.roughness = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff6d00"), 3.2)
		23: # Quimera
			mat.albedo_color = Color("#33691e")
			mat.roughness = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#76ff03"), 3.0)
		24: # Boreal
			mat.albedo_color = Color("#80d8ff")
			mat.metallic = 0.7
			mat.roughness = 0.1
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00b0ff"), 2.8)
		25: # Thalassiano
			mat.albedo_color = Color("#006064")
			mat.metallic = 0.5
			mat.roughness = 0.3
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.0)
		26: # Cambion
			mat.albedo_color = Color("#b71c1c")
			mat.metallic = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffea00"), 3.0)
		27: # Nephilim
			mat.albedo_color = Color("#1a237e")
			mat.metallic = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 3.2)
		28: # Errante Temporal
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

	for child in weapon_mesh.get_children():
		child.queue_free()

	if offhand_pivot:
		for child in offhand_pivot.get_children():
			child.queue_free()

	if homunculus_orbiter and is_instance_valid(homunculus_orbiter):
		homunculus_orbiter.queue_free()
		homunculus_orbiter = null

	match current_class_id:
		1: # Espadachim
			_build_sword_and_shield()
		2: # Batedor
			_build_bow()
		3: # Iniciado
			_build_staff()
		4: # Acólito
			_build_mace_and_talisman()
		5: # Ferreiro
			_build_blacksmith_hammer()
		6: # Alquimista
			_build_alchemist_flasks()
		7: # Ceifador do Eclipse
			_build_scythe()
		8: # Artífice Rúnico
			_build_hammer_cannon()
		9: # Criador de Homúnculos
			_build_homunculus_orb()

func _build_sword_and_shield() -> void:
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.08, 1.05, 0.04)
	blade.mesh = blade_box
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.9, 0.95, 1.0)
	blade_mat.metallic = 0.95
	blade_mat.emission_enabled = true
	blade_mat.emission = Color("#40c4ff")
	blade_mat.emission_energy_multiplier = 1.4
	blade.material_override = blade_mat
	blade.position = Vector3(0, 0.52, 0)
	weapon_mesh.add_child(blade)

	if offhand_pivot:
		var shield := MeshInstance3D.new()
		var shield_box := BoxMesh.new()
		shield_box.size = Vector3(0.48, 0.68, 0.07)
		shield.mesh = shield_box
		var shield_mat := StandardMaterial3D.new()
		shield_mat.albedo_color = Color("#1565c0")
		shield_mat.metallic = 0.6
		shield.material_override = shield_mat
		shield.position = Vector3(0, 0.1, 0)
		offhand_pivot.add_child(shield)

func _build_bow() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("#5d4037")

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

func _build_staff() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("#2e1c14")

	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.03
	shaft_cyl.height = 1.75
	shaft.mesh = shaft_cyl
	shaft.material_override = wood_mat
	shaft.position = Vector3(0, 0.45, 0)
	weapon_mesh.add_child(shaft)

	var orb := MeshInstance3D.new()
	var orb_sphere := SphereMesh.new()
	orb_sphere.radius = 0.16
	orb_sphere.height = 0.32
	orb.mesh = orb_sphere
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color("#00e5ff")
	orb_mat.emission_enabled = true
	orb_mat.emission = Color("#00e5ff")
	orb_mat.emission_energy_multiplier = 3.5
	orb.material_override = orb_mat
	orb.position = Vector3(0, 1.35, 0)
	weapon_mesh.add_child(orb)

func _build_mace_and_talisman() -> void:
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#ffd700")
	gold_mat.metallic = 0.9

	var handle := MeshInstance3D.new()
	var handle_cyl := CylinderMesh.new()
	handle_cyl.top_radius = 0.032
	handle_cyl.bottom_radius = 0.032
	handle_cyl.height = 0.75
	handle.mesh = handle_cyl
	handle.position = Vector3(0, 0.25, 0)
	weapon_mesh.add_child(handle)

	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.2, 0.26, 0.2)
	head.mesh = head_box
	head.material_override = gold_mat
	head.position = Vector3(0, 0.65, 0)
	weapon_mesh.add_child(head)

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

func _build_blacksmith_hammer() -> void:
	var handle := MeshInstance3D.new()
	var handle_cyl := CylinderMesh.new()
	handle_cyl.top_radius = 0.038
	handle_cyl.bottom_radius = 0.038
	handle_cyl.height = 1.25
	handle.mesh = handle_cyl
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.16, 0.16, 0.18)
	dark_mat.metallic = 0.8
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
	head.material_override = iron_mat
	head.position = Vector3(0, 0.95, 0)
	weapon_mesh.add_child(head)

	var ember_band := MeshInstance3D.new()
	var ember_box := BoxMesh.new()
	ember_box.size = Vector3(0.35, 0.1, 0.53)
	ember_band.mesh = ember_box
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color("#ff3d00")
	ember_mat.emission_enabled = true
	ember_mat.emission = Color("#ff6d00")
	ember_mat.emission_energy_multiplier = 4.0
	ember_band.material_override = ember_mat
	ember_band.position = Vector3(0, 0.95, 0)
	weapon_mesh.add_child(ember_band)

func _build_alchemist_flasks() -> void:
	var flask := MeshInstance3D.new()
	var flask_sphere := SphereMesh.new()
	flask_sphere.radius = 0.16
	flask_sphere.height = 0.32
	flask.mesh = flask_sphere
	var acid_mat := StandardMaterial3D.new()
	acid_mat.albedo_color = Color("#00e676")
	acid_mat.emission_enabled = true
	acid_mat.emission = Color("#00e676")
	acid_mat.emission_energy_multiplier = 3.0
	flask.material_override = acid_mat
	flask.position = Vector3(0, 0.32, 0)
	weapon_mesh.add_child(flask)

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
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.032
	shaft_cyl.bottom_radius = 0.032
	shaft_cyl.height = 1.95
	shaft.mesh = shaft_cyl
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.1, 0.06, 0.12)
	shaft.material_override = dark_wood
	shaft.position = Vector3(0, 0.55, 0)
	weapon_mesh.add_child(shaft)

	var scythe_blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.06, 0.16, 0.72)
	scythe_blade.mesh = blade_box
	var dark_blade_mat := StandardMaterial3D.new()
	dark_blade_mat.albedo_color = Color("#120005")
	dark_blade_mat.metallic = 0.95
	scythe_blade.material_override = dark_blade_mat
	scythe_blade.rotation.x = deg_to_rad(25.0)
	scythe_blade.position = Vector3(0, 1.45, -0.28)
	weapon_mesh.add_child(scythe_blade)

	var edge := MeshInstance3D.new()
	var edge_box := BoxMesh.new()
	edge_box.size = Vector3(0.065, 0.04, 0.95)
	edge.mesh = edge_box
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color("#ff1744")
	edge_mat.emission_enabled = true
	edge_mat.emission = Color("#ff1744")
	edge_mat.emission_energy_multiplier = 4.0
	edge.material_override = edge_mat
	edge.rotation.x = deg_to_rad(12.0)
	edge.position = Vector3(0, 1.4, -0.42)
	weapon_mesh.add_child(edge)

func _build_hammer_cannon() -> void:
	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.036
	shaft_cyl.bottom_radius = 0.036
	shaft_cyl.height = 1.15
	shaft.mesh = shaft_cyl
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#d4af37")
	gold_mat.metallic = 0.9
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

	var rune_core := MeshInstance3D.new()
	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.08
	core_sphere.height = 0.16
	rune_core.mesh = core_sphere
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color("#00e5ff")
	rune_mat.emission_enabled = true
	rune_mat.emission = Color("#00e5ff")
	rune_mat.emission_energy_multiplier = 4.0
	rune_core.material_override = rune_mat
	rune_core.position = Vector3(0, 0.88, -0.38)
	weapon_mesh.add_child(rune_core)

func _build_homunculus_orb() -> void:
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

	homunculus_orbiter = MeshInstance3D.new()
	homunculus_orbiter.name = "HomunculusCompanion"
	var comp_mesh := SphereMesh.new()
	comp_mesh.radius = 0.17
	comp_mesh.height = 0.34
	homunculus_orbiter.mesh = comp_mesh
	var comp_mat := StandardMaterial3D.new()
	comp_mat.albedo_color = Color("#ba68c8")
	comp_mat.emission_enabled = true
	comp_mat.emission = Color("#e040fb")
	comp_mat.emission_energy_multiplier = 2.0
	homunculus_orbiter.material_override = comp_mat

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

	add_child(homunculus_orbiter)

func play_skill_animation(action_type: int) -> void:
	match action_type:
		1:
			_animate_attack()
		2:
			_animate_dodge()
		3:
			_spawn_skill_q_flash()
			_animate_attack()
		4:
			_spawn_skill_r_aura()
		5:
			_spawn_skill_f_impact()
		6:
			_spawn_racial_z_skill()

func _spawn_racial_z_skill() -> void:
	var col := _get_race_color()
	var aura := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.8
	tor.outer_radius = 1.4
	aura.mesh = tor
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 5.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.material_override = m
	aura.global_position = global_position + Vector3(0, 0.1, 0)
	if get_parent():
		get_parent().add_child(aura)
	var tw := create_tween()
	tw.tween_property(aura, "scale", Vector3(3.5, 1.0, 3.5), 0.5)
	tw.chain().tween_callback(aura.queue_free)

func _get_race_color() -> Color:
	match current_race_id:
		1, 11: return Color("#ffd700")
		12: return Color("#ba68c8")
		2, 13: return Color("#00e5ff")
		14: return Color("#7c4dff")
		3, 15: return Color("#ff9800")
		16: return Color("#ff3d00")
		4, 17: return Color("#ff1744")
		18: return Color("#ad1457")
		5: return Color("#d500f9")
		6: return Color("#ff6f00")
		7: return Color("#69f0ae")
		8: return Color("#fff59d")
		9: return Color("#18ffff")
		10: return Color("#00e5ff")
		19: return Color("#4caf50")
		20: return Color("#9c27b0")
		21: return Color("#eceff1")
		22: return Color("#ff6d00")
		23: return Color("#76ff03")
		24: return Color("#80d8ff")
		25: return Color("#006064")
		26: return Color("#c62828")
		27: return Color("#ffd700")
		28: return Color("#ffd54f")
		_: return Color("#ffd700")

func _get_class_color() -> Color:
	match current_class_id:
		1: return Color("#29b6f6") # Espadachim
		2: return Color("#66bb6a") # Batedor
		3: return Color("#ab47bc") # Iniciado
		4: return Color("#ffee58") # Acólito
		5: return Color("#ff7043") # Ferreiro
		6: return Color("#00e676") # Alquimista
		7: return Color("#d50000") # Ceifador do Eclipse
		8: return Color("#00e5ff") # Artífice Rúnico
		9: return Color("#ea80fc") # Criador de Homúnculos
		_: return Color("#ffffff")

func _animate_attack() -> void:
	if not weapon_pivot:
		return
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation:x", deg_to_rad(-60.0), 0.1)
	tw.tween_property(weapon_pivot, "rotation:x", deg_to_rad(60.0), 0.12)
	tw.tween_property(weapon_pivot, "rotation:x", 0.0, 0.1)

func _animate_dodge() -> void:
	if body_mesh:
		var tw := create_tween()
		tw.tween_property(body_mesh, "rotation:x", deg_to_rad(360.0), 0.35)
		tw.finished.connect(func(): if body_mesh: body_mesh.rotation.x = 0.0)

func _spawn_skill_q_flash() -> void:
	var col := _get_class_color()
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = mat
	flash.global_position = global_position + Vector3(0, 1.0, 0)
	if get_parent():
		get_parent().add_child(flash)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 4.0
	light.omni_range = 5.0
	flash.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(2.5, 2.5, 2.5), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(flash.queue_free)

func _spawn_skill_r_aura() -> void:
	var col := _get_class_color()
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
	light.light_energy = 4.5
	light.omni_range = 6.0
	aura.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(aura, "scale", Vector3(6.5, 1.0, 6.5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(aura.queue_free)

func _spawn_skill_f_impact() -> void:
	var col := _get_class_color()
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
	light.light_energy = 5.5
	light.omni_range = 7.5
	shockwave.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(shockwave, "scale", Vector3(8.5, 1.0, 8.5), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(shockwave.queue_free)

func _create_emissive_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
