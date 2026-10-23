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
var spirit_wolf_companion: Node3D = null
var spirit_wolf_anim_time: float = 0.0

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
		var r_names: Array[String] = [
			"",
			"Valeriano", "Noctari", "Kharad", "Varkai", "Dhampir",
			"Licantropo Primordial", "Revenant", "Celestino", "Abissal", "Autômato Rúnico",
			"Alto Valeriano", "Andarilho do Éter", "Arconte Lunar", "Espectro Umbral", "Guardião Rúnico",
			"Titã de Obsidiana", "Soberano Dracônico", "Fera do Frenesi", "Sylvari", "Esporiano",
			"Aracne", "Draconato de Cinzas", "Quimera", "Boreal", "Thalassiano",
			"Cambion", "Nephilim", "Errante Temporal",
			"Meio-Celestial", "Pyromante", "Gigante de Gelo", "Drago Terra", "Drago Água",
			"Drago Raio", "Drago Místico", "Orc", "Anão", "Elfo",
			"Elfo Solar", "Elfo Lunar", "Fadinha", "Goblin", "Demi-Humano Escorpião",
			"Demi-Humano Tartaruga", "Meio-Demônio", "Demi-Humano Lobo"
		]
		var c_names: Array[String] = [
			"", "Espadachim", "Batedor", "Iniciado", "Acólito",
			"Ferreiro", "Alquimista", "Ceifador do Eclipse", "Artífice Rúnico", "Criador de Homúnculos",
			"Dançarino Astral", "Inquisidor das Cinzas", "Necromante de Ossos", "Domador Primordial",
			"Cavaleiro da Ruptura", "Arauto da Tempestade"
		]
		var r_str: String = r_names[current_race_id] if current_race_id < r_names.size() else "Valeriano"
		var c_str: String = c_names[current_class_id] if current_class_id < c_names.size() else "Espadachim"
		label.text = "Player #%d\n[%s - %s]" % [player_id, r_str, c_str]

func update_network_transform(new_pos: Vector3, new_rot_y: float) -> void:
	target_position = new_pos
	target_rotation_y = new_rot_y

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, INTERPOLATION_SPEED * delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, INTERPOLATION_SPEED * delta)

	if (current_class_id == 9 or current_class_id == 15) and homunculus_orbiter and is_instance_valid(homunculus_orbiter):
		homunculus_anim_time += delta
		var orbit_r: float = 1.15
		var orbit_spd: float = 3.2
		homunculus_orbiter.position = Vector3(
			cos(homunculus_anim_time * orbit_spd) * orbit_r,
			1.35 + sin(homunculus_anim_time * 4.5) * 0.18,
			sin(homunculus_anim_time * orbit_spd) * orbit_r
		)

	if (current_class_id == 10 or current_class_id == 19) and spirit_wolf_companion and is_instance_valid(spirit_wolf_companion):
		spirit_wolf_anim_time += delta
		var wolf_bob: float = sin(spirit_wolf_anim_time * 3.2) * 0.12
		spirit_wolf_companion.position = Vector3(
			-1.15 + cos(spirit_wolf_anim_time * 1.4) * 0.1,
			0.5 + wolf_bob,
			0.35 + sin(spirit_wolf_anim_time * 1.4) * 0.12
		)
		spirit_wolf_companion.rotation.y = sin(spirit_wolf_anim_time * 1.8) * 0.12

func _get_race_scale() -> float:
	match current_race_id:
		31: return 1.45 # Gigante de Gelo (1.45x)
		37: return 0.82 # Anão (0.82x)
		41: return 0.55 # Fadinha (0.55x)
		42: return 0.75 # Goblin (0.75x)
		44: return 1.35 # Demi-Humano Tartaruga (1.35x)
		_: return 1.0

func _build_race_accessories(parent: Node3D, race_id: int) -> void:
	match race_id:
		29: # Meio-Celestial: Asas solares douradas luminosas
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

		30: # Pyromante: Chamas e aura incandescente ao redor do peitoral/cabeça
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

		31: # Gigante de Gelo: Ombreiras pontiagudas de gelo
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

		32: # Drago (Terra): Carapaça rochosa e placas
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

		33: # Drago (Água): Cristas aquáticas dorsais
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

		34: # Drago (Raio): Espinhos condutores elétricos nas costas
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

		35: # Drago (Místico): Chifres arcanos espirais
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

		36: # Orc: Presas inferiores proeminentes
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

		37: # Anão: Barba trançada densa à frente do queixo
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

		38: # Elfo: Orelhas pontiagudas esguias
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

		39: # Elfo Solar (Azgher): Orelhas pontiagudas com diadema solar dourado
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

		40: # Elfo Lunar (Tenebra): Orelhas com diadema de lua prateada
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

		41: # Fadinha: Par de asas de borboleta reluzentes
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

		42: # Goblin: Orelhas compridas caídas e nariz pontiagudo
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

		43: # Demi-Humano Escorpião: Cauda articulada nas costas com ferrão
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

		44: # Demi-Humano Tartaruga: Casco pesado nas costas
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

		45: # Meio-Demônio (Succubus): Chifres elegantes e asas de morcego
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

		46: # Demi-Humano Lobo: Orelhas lupinas e cauda lupina
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
		# Quadrante 5: 18 Novas Raças (29 a 46)
		29: # Meio-Celestial - Luz Divina
			mat.albedo_color = Color("#fff9c4")
			mat.metallic = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd700"), 3.5)
		30: # Pyromante - Chamas e cinzas
			mat.albedo_color = Color("#ff3d00")
			mat.metallic = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ff6d00"), 3.5)
		31: # Gigante de Gelo - Cristal Glacial (1.45x)
			mat.albedo_color = Color("#80deea")
			mat.metallic = 0.75
			mat.roughness = 0.1
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#00e5ff"), 3.5)
		32: # Drago (Terra) - Rocha e Carapaça
			mat.albedo_color = Color("#6d4c41")
			mat.roughness = 0.85
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#8d6e63"), 2.5)
		33: # Drago (Água) - Maré Cristalina
			mat.albedo_color = Color("#0277bd")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#4fc3f7"), 3.0)
		34: # Drago (Raio) - Elétrico Dourado
			mat.albedo_color = Color("#fbc02d")
			mat.metallic = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffff00"), 3.5)
		35: # Drago (Místico) - Rúnico Violeta
			mat.albedo_color = Color("#7b1fa2")
			mat.metallic = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#e1bee7"), 3.2)
		36: # Orc - Verde de Guerra
			mat.albedo_color = Color("#33691e")
			mat.roughness = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#76ff03"), 2.8)
		37: # Anão - Bronze da Forja (0.82x)
			mat.albedo_color = Color("#4e342e")
			mat.metallic = 0.8
			mat.roughness = 0.4
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#d7ccc8"), 2.2)
		38: # Elfo - Silvestre Esguio
			mat.albedo_color = Color("#558b2f")
			mat.roughness = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#aed581"), 2.6)
		39: # Elfo Solar - Azgher Ouro
			mat.albedo_color = Color("#ff8f00")
			mat.metallic = 0.8
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ffd54f"), 3.5)
		40: # Elfo Lunar - Tenebra Sombra
			mat.albedo_color = Color("#283593")
			mat.metallic = 0.5
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#9fa8da"), 3.0)
		41: # Fadinha - Rosa Fada Borboleta (0.55x)
			mat.albedo_color = Color("#f06292")
			mat.metallic = 0.3
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#f8bbd0"), 3.5)
		42: # Goblin - Verde Astuto (0.75x)
			mat.albedo_color = Color("#689f38")
			mat.roughness = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#cddc39"), 2.5)
		43: # Demi-Humano Escorpião - Quitina Roxa
			mat.albedo_color = Color("#311b92")
			mat.metallic = 0.85
			mat.roughness = 0.2
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#ba68c8"), 3.2)
		44: # Demi-Humano Tartaruga - Carapaça (1.35x)
			mat.albedo_color = Color("#1b5e20")
			mat.roughness = 0.85
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#81c784"), 2.5)
		45: # Meio-Demônio - Succubus Carmesim
			mat.albedo_color = Color("#880e4f")
			mat.metallic = 0.6
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#f06292"), 3.2)
		46: # Demi-Humano Lobo - Cinza Feral Lupino
			mat.albedo_color = Color("#37474f")
			mat.roughness = 0.7
			if visor_mesh:
				visor_mesh.material_override = _create_emissive_mat(Color("#90a4ae"), 2.8)

	body_mesh.material_override = mat

func _update_class_weapon() -> void:
	_apply_class_visuals()

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

	if spirit_wolf_companion and is_instance_valid(spirit_wolf_companion):
		spirit_wolf_companion.queue_free()
		spirit_wolf_companion = null

	match current_class_id:
		1: # Guerreiro: Espada Longa
			_build_sword_long()
		2: # Mago: Cajado Arcano
			_build_staff()
		3: # Arqueiro: Arco Longo
			_build_bow()
		4: # Assassino: Duas Adagas (nas duas mãos)
			_build_dual_daggers()
		5: # Lutador: Duas Manoplas Pesadas (nos dois punhos)
			_build_heavy_gauntlets()
		6: # Escudeiro: Grande Escudo + Maça Curta
			_build_shield_and_mace()
		7: # Ferreiro: Martelo de Forja
			_build_blacksmith_hammer()
		8: # Alquimista: Frasco Químico + Catalisador
			_build_alchemist_flasks()
		9: # Escultor: Adaga de Cinzel Prateada + Pequena Estátua Orbitando
			_build_sculptor_chisel_and_statue()
		10: # Domador: Chicote Enrolado + Fera Domada ao lado
			_build_tamer_whip_and_beast()
		11: # Alfaiate de Guerra: Agulhas Longas Douradas + Fios brilhantes nas mãos
			_build_war_tailor_needles()
		12: # Chef de Caça: Cutelo de Açougueiro Gigante na mão direita + Wok de Ferro
			_build_hunting_chef_cleaver_and_wok()
		13: # Ceifador do Eclipse
			_build_scythe()
		14: # Artífice Rúnico
			_build_hammer_cannon()
		15: # Criador de Homúnculos
			_build_homunculus_orb()
		16: # Dançarino Astral
			_build_astral_blades()
		17: # Inquisidor das Cinzas
			_build_ash_flail_and_chains()
		18: # Necromante de Ossos
			_build_bone_staff()
		19: # Domador Primordial
			_build_primordial_spear_and_wolf()
		20: # Cavaleiro da Ruptura
			_build_void_greatsword_and_shield()
		21: # Arauto da Tempestade
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

func _build_astral_blades() -> void:
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

func _build_ash_flail_and_chains() -> void:
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.12, 0.12, 0.14)
	iron_mat.metallic = 0.9
	iron_mat.roughness = 0.3

	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color("#d50000")
	ember_mat.emission_enabled = true
	ember_mat.emission = Color("#ff1744")
	ember_mat.emission_energy_multiplier = 4.5

	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.035
	shaft_cyl.height = 0.48
	shaft.mesh = shaft_cyl
	shaft.material_override = iron_mat
	shaft.position = Vector3(0, 0.1, 0)
	weapon_mesh.add_child(shaft)

	var cap := MeshInstance3D.new()
	var cap_ring := TorusMesh.new()
	cap_ring.inner_radius = 0.03
	cap_ring.outer_radius = 0.06
	cap.mesh = cap_ring
	cap.material_override = ember_mat
	cap.position = Vector3(0, 0.35, 0)
	weapon_mesh.add_child(cap)

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

	var flail_head := MeshInstance3D.new()
	var head_sphere := SphereMesh.new()
	head_sphere.radius = 0.13
	head_sphere.height = 0.26
	flail_head.mesh = head_sphere
	flail_head.material_override = ember_mat
	flail_head.position = Vector3(0, 0.04, -0.16)
	weapon_mesh.add_child(flail_head)

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

func _build_bone_staff() -> void:
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

	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.032
	shaft_cyl.bottom_radius = 0.042
	shaft_cyl.height = 1.55
	shaft.mesh = shaft_cyl
	shaft.material_override = bone_mat
	shaft.position = Vector3(0, 0.45, 0)
	weapon_mesh.add_child(shaft)

	for y_off in [0.0, 0.4, 0.8]:
		var vert := MeshInstance3D.new()
		var vert_torus := TorusMesh.new()
		vert_torus.inner_radius = 0.038
		vert_torus.outer_radius = 0.065
		vert.mesh = vert_torus
		vert.material_override = bone_mat
		vert.position = Vector3(0, y_off, 0)
		weapon_mesh.add_child(vert)

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

	if offhand_pivot:
		var off_relic := MeshInstance3D.new()
		var relic_box := BoxMesh.new()
		relic_box.size = Vector3(0.12, 0.18, 0.08)
		off_relic.mesh = relic_box
		off_relic.material_override = bone_mat
		off_relic.position = Vector3(0, 0.1, 0)
		offhand_pivot.add_child(off_relic)

func _build_primordial_spear_and_wolf() -> void:
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

	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.034
	shaft_cyl.height = 1.95
	shaft.mesh = shaft_cyl
	shaft.material_override = wood_mat
	shaft.position = Vector3(0, 0.65, 0)
	weapon_mesh.add_child(shaft)

	var grip := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius = 0.036
	grip_cyl.bottom_radius = 0.036
	grip_cyl.height = 0.36
	grip.mesh = grip_cyl
	grip.material_override = wrap_mat
	grip.position = Vector3(0, 0.15, 0)
	weapon_mesh.add_child(grip)

	var spearhead := MeshInstance3D.new()
	var spear_box := BoxMesh.new()
	spear_box.size = Vector3(0.12, 0.52, 0.025)
	spearhead.mesh = spear_box
	spearhead.material_override = spearhead_mat
	spearhead.position = Vector3(0, 1.7, 0)
	weapon_mesh.add_child(spearhead)

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

	spirit_wolf_companion = Node3D.new()
	spirit_wolf_companion.name = "SpiritWolfCompanion"

	var wolf_mat := StandardMaterial3D.new()
	wolf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wolf_mat.albedo_color = Color(0.72, 0.88, 1.0, 0.62)
	wolf_mat.emission_enabled = true
	wolf_mat.emission = Color("#80d8ff")
	wolf_mat.emission_energy_multiplier = 2.4
	wolf_mat.roughness = 0.2

	var body_node := MeshInstance3D.new()
	var body_capsule := CapsuleMesh.new()
	body_capsule.radius = 0.18
	body_capsule.height = 0.65
	body_node.mesh = body_capsule
	body_node.material_override = wolf_mat
	body_node.rotation.x = deg_to_rad(90.0)
	spirit_wolf_companion.add_child(body_node)

	var chest := MeshInstance3D.new()
	var chest_box := BoxMesh.new()
	chest_box.size = Vector3(0.32, 0.36, 0.32)
	chest.mesh = chest_box
	chest.material_override = wolf_mat
	chest.position = Vector3(0, 0.08, -0.22)
	spirit_wolf_companion.add_child(chest)

	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.22, 0.18, 0.26)
	head.mesh = head_box
	head.material_override = wolf_mat
	head.position = Vector3(0, 0.24, -0.42)
	spirit_wolf_companion.add_child(head)

	var snout := MeshInstance3D.new()
	var snout_box := BoxMesh.new()
	snout_box.size = Vector3(0.12, 0.1, 0.2)
	snout.mesh = snout_box
	snout.material_override = wolf_mat
	snout.position = Vector3(0, 0.19, -0.58)
	spirit_wolf_companion.add_child(snout)

	for ear_x in [-0.08, 0.08]:
		var ear := MeshInstance3D.new()
		var ear_prism := PrismMesh.new()
		ear_prism.size = Vector3(0.07, 0.12, 0.05)
		ear.mesh = ear_prism
		ear.material_override = wolf_mat
		ear.position = Vector3(ear_x, 0.38, -0.4)
		spirit_wolf_companion.add_child(ear)

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

	add_child(spirit_wolf_companion)

func _build_void_greatsword_and_shield() -> void:
	var void_black_mat := StandardMaterial3D.new()
	void_black_mat.albedo_color = Color(0.06, 0.06, 0.08)
	void_black_mat.metallic = 0.95
	void_black_mat.roughness = 0.2

	var gravity_purple_mat := StandardMaterial3D.new()
	gravity_purple_mat.albedo_color = Color("#7c4dff")
	gravity_purple_mat.emission_enabled = true
	gravity_purple_mat.emission = Color("#b388ff")
	gravity_purple_mat.emission_energy_multiplier = 3.8

	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.22, 1.68, 0.055)
	blade.mesh = blade_box
	blade.material_override = void_black_mat
	blade.position = Vector3(0, 0.88, 0)
	weapon_mesh.add_child(blade)

	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_box := BoxMesh.new()
		edge_box.size = Vector3(0.025, 1.7, 0.065)
		edge.mesh = edge_box
		edge.material_override = gravity_purple_mat
		edge.position = Vector3(side * 0.11, 0.88, 0)
		weapon_mesh.add_child(edge)

	var guard := MeshInstance3D.new()
	var guard_box := BoxMesh.new()
	guard_box.size = Vector3(0.48, 0.08, 0.12)
	guard.mesh = guard_box
	guard.material_override = void_black_mat
	guard.position = Vector3(0, 0.04, 0)
	weapon_mesh.add_child(guard)

	var core_orb := MeshInstance3D.new()
	var core_sph := SphereMesh.new()
	core_sph.radius = 0.05
	core_sph.height = 0.1
	core_orb.mesh = core_sph
	core_orb.material_override = gravity_purple_mat
	core_orb.position = Vector3(0, 0.04, 0)
	weapon_mesh.add_child(core_orb)

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

		var rift_orb := MeshInstance3D.new()
		var rift_sph := SphereMesh.new()
		rift_sph.radius = 0.14
		rift_sph.height = 0.08
		rift_orb.mesh = rift_sph
		rift_orb.material_override = gravity_purple_mat
		rift_orb.position = Vector3(0, 0.1, -0.06)
		offhand_pivot.add_child(rift_orb)

func _build_storm_halberd() -> void:
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#ffd700")
	gold_mat.metallic = 0.95
	gold_mat.roughness = 0.18

	var lightning_mat := StandardMaterial3D.new()
	lightning_mat.albedo_color = Color("#00e5ff")
	lightning_mat.emission_enabled = true
	lightning_mat.emission = Color("#00b0ff")
	lightning_mat.emission_energy_multiplier = 4.8

	var shaft := MeshInstance3D.new()
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.03
	shaft_cyl.bottom_radius = 0.035
	shaft_cyl.height = 2.05
	shaft.mesh = shaft_cyl
	shaft.material_override = gold_mat
	shaft.position = Vector3(0, 0.72, 0)
	weapon_mesh.add_child(shaft)

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

	var rear_spike := MeshInstance3D.new()
	var spike_box := BoxMesh.new()
	spike_box.size = Vector3(0.2, 0.08, 0.03)
	rear_spike.mesh = spike_box
	rear_spike.material_override = gold_mat
	rear_spike.position = Vector3(-0.12, 1.55, 0)
	weapon_mesh.add_child(rear_spike)

	var spear_tip := MeshInstance3D.new()
	var tip_cone := CylinderMesh.new()
	tip_cone.top_radius = 0.0
	tip_cone.bottom_radius = 0.045
	tip_cone.height = 0.52
	spear_tip.mesh = tip_cone
	spear_tip.material_override = lightning_mat
	spear_tip.position = Vector3(0, 1.95, 0)
	weapon_mesh.add_child(spear_tip)

	for ring_y in [1.32, 1.42]:
		var coil := MeshInstance3D.new()
		var coil_torus := TorusMesh.new()
		coil_torus.inner_radius = 0.04
		coil_torus.outer_radius = 0.075
		coil.mesh = coil_torus
		coil.material_override = lightning_mat
		coil.position = Vector3(0, ring_y, 0)
		weapon_mesh.add_child(coil)

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
		# Quadrante 5: 18 Novas Raças (29 a 46)
		29: return Color("#fff59d") # Meio-Celestial
		30: return Color("#ff3d00") # Pyromante
		31: return Color("#80deea") # Gigante de Gelo
		32: return Color("#8d6e63") # Drago Terra
		33: return Color("#29b6f6") # Drago Água
		34: return Color("#ffd600") # Drago Raio
		35: return Color("#ab47bc") # Drago Místico
		36: return Color("#558b2f") # Orc
		37: return Color("#d7ccc8") # Anão
		38: return Color("#aed581") # Elfo
		39: return Color("#ffb300") # Elfo Solar
		40: return Color("#5c6bc0") # Elfo Lunar
		41: return Color("#f48fb1") # Fadinha
		42: return Color("#7cb342") # Goblin
		43: return Color("#6a1b9a") # Demi-Humano Escorpião
		44: return Color("#33691e") # Demi-Humano Tartaruga
		45: return Color("#c2185b") # Meio-Demônio (Succubus)
		46: return Color("#78909c") # Demi-Humano Lobo
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
		10: return Color("#00e5ff") # Dançarino Astral
		11: return Color("#ff1744") # Inquisidor das Cinzas
		12: return Color("#00e676") # Necromante de Ossos
		13: return Color("#80d8ff") # Domador Primordial
		14: return Color("#7c4dff") # Cavaleiro da Ruptura
		15: return Color("#00b0ff") # Arauto da Tempestade
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
