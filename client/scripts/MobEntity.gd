class_name MobEntity
extends Node3D

const LunariaTextures = preload("res://scripts/models/LunariaTextures.gd")
const LunariaModel = preload("res://scripts/models/LunariaModel.gd")
## Textura do corpo principal de cada tipo de mob
const MOB_TEXTURES := {
	1: "fur", 2: "leather", 3: "cloth", 4: "cloth", 5: "metal_hammered", 6: "fur", 7: "fur",
	10: "cloth", 11: "stone", 12: "cloth", 13: "metal_hammered", 14: "obsidian",
}

var mob_id: int = 0
var mob_type: int = 1
var current_state: int = 0
var current_hp: int = 100
var max_hp: int = 100
var is_alive: bool = true

var target_position: Vector3 = Vector3.ZERO
var target_rotation_y: float = 0.0
const INTERPOLATION_SPEED: float = 15.0

var body_pivot: Node3D = null
var main_mesh: MeshInstance3D = null
var main_mat: StandardMaterial3D = null
var shield_mesh: MeshInstance3D = null
var shield_mat: StandardMaterial3D = null
var weapon_mesh: Node3D = null
var creature_model: LunariaModel = null
var name_tag: Label3D = null
var current_moon_phase: int = 1

var anim_body: AnimatableBody3D = null
var collision_shape: CollisionShape3D = null

const MOB_NAMES := {
	1: "Lobo da Bruma",
	2: "Saqueador Deserdado",
	3: "Besteiro da Vigília",
	4: "Acólito do Eclipse",
	5: "Executor de Ferro",
	6: "Lobo Alfa",
	7: "★ LICANTROPO ALFA [RAID BOSS] ★",
	10: "Cultista Sombrio",
	11: "Gárgula de Pedra",
	12: "Mini-Boss Inquisidor Vex",
	13: "Comandante Vaelen, o Traidor",
	14: "★ MALAKOR, O ARAUTO DO ECLIPSE [RAID BOSS] ★",
	15: "Aranha Tecelã da Bruma",
	16: "★ ARACHNA, A RAINHA TECELÃ [RAID BOSS] ★",
	17: "Lodo Ácido Corrosivo",
	18: "Escorpião Abissal Gigante",
	19: "Mini-Boss Quimera Costurada Nº 0",
	20: "Golem de Gelo Antigo",
	21: "Draco de Geada Selvagem",
	22: "★ YMIR, O PATRIARCA GIGANTE DE GELO [BOSS] ★",
	23: "Guarda Sanguinário de Vesperian",
	24: "★ LORDE VESPERIAN, O PROGENITOR VAMPIRO [RAID BOSS] ★"
}

func _ready() -> void:
	target_position = position
	target_rotation_y = rotation.y
	_setup_collision()
	_build_visuals()
	_update_tags()

func setup(id: int, mtype: int, initial_pos: Vector3, initial_rot_y: float, hp: int, p_max_hp: int) -> void:
	mob_id = id
	mob_type = mtype
	position = initial_pos
	target_position = initial_pos
	rotation.y = initial_rot_y
	target_rotation_y = initial_rot_y
	current_hp = hp
	max_hp = p_max_hp
	is_alive = (hp > 0)
	visible = is_alive

	if is_node_ready():
		_setup_collision()
		_build_visuals()
		_update_tags()

func _setup_collision() -> void:
	if anim_body != null:
		anim_body.queue_free()

	anim_body = AnimatableBody3D.new()
	anim_body.name = "MobBody"
	anim_body.collision_layer = 1
	anim_body.collision_mask = 0
	add_child(anim_body)

	collision_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if mob_type == 16: # Arachna, Rainha Tecelã (Colossal 2.8x)
		cap.radius = 1.8
		cap.height = 3.2
		collision_shape.position = Vector3(0, 1.6, 0)
	elif mob_type == 22: # Ymir, Patriarca Jotunar (Colossal 3.0x)
		cap.radius = 1.9
		cap.height = 4.4
		collision_shape.position = Vector3(0, 2.2, 0)
	elif mob_type == 24: # Lorde Vesperian (Colossal 2.5x)
		cap.radius = 1.4
		cap.height = 3.6
		collision_shape.position = Vector3(0, 1.8, 0)
	elif mob_type == 14: # Malakor, Arauto do Eclipse (Colossal 2.2x)
		cap.radius = 1.5
		cap.height = 3.6
		collision_shape.position = Vector3(0, 1.8, 0)
	elif mob_type == 19: # Quimera Costurada (Mini-Boss)
		cap.radius = 1.3
		cap.height = 2.6
		collision_shape.position = Vector3(0, 1.3, 0)
	elif mob_type == 20 or mob_type == 21: # Golem de Gelo / Draco
		cap.radius = 1.1
		cap.height = 2.4
		collision_shape.position = Vector3(0, 1.2, 0)
	elif mob_type == 5 or mob_type == 7 or mob_type == 13:
		cap.radius = 1.15
		cap.height = 2.6
		collision_shape.position = Vector3(0, 1.3, 0)
	elif mob_type == 12 or mob_type == 11 or mob_type == 23:
		cap.radius = 0.8
		cap.height = 2.0
		collision_shape.position = Vector3(0, 1.0, 0)
	elif mob_type == 18: # Escorpião Abissal
		cap.radius = 0.9
		cap.height = 1.5
		collision_shape.position = Vector3(0, 0.75, 0)
	elif mob_type == 1 or mob_type == 6 or mob_type == 15 or mob_type == 17:
		cap.radius = 0.6
		cap.height = 1.3
		collision_shape.position = Vector3(0, 0.65, 0)
	else:
		cap.radius = 0.6
		cap.height = 1.8
		collision_shape.position = Vector3(0, 0.9, 0)

	collision_shape.shape = cap
	anim_body.add_child(collision_shape)
	collision_shape.disabled = (not is_alive or current_hp <= 0 or current_state == 5)

func _build_visuals() -> void:
	# Limpa nós visuais existentes caso reconfigurado
	if body_pivot != null:
		body_pivot.queue_free()

	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)

	main_mesh = MeshInstance3D.new()
	body_pivot.add_child(main_mesh)

	main_mat = StandardMaterial3D.new()
	main_mesh.material_override = main_mat
	LunariaTextures.apply(main_mat, MOB_TEXTURES.get(mob_type, ""))

	match mob_type:
		1: # Lobo da Bruma (Quadrúpede ágil, malha baixa e alongada)
			body_pivot.scale = Vector3(0.9, 0.7, 1.3)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.38
			c_mesh.height = 1.3
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.45, 0)
			main_mesh.rotation.x = deg_to_rad(90.0) # Alongado no eixo Z

			main_mat.albedo_color = Color(0.22, 0.24, 0.27, 1.0)
			main_mat.roughness = 0.85

			# Cabeça / Focinho
			var snout := MeshInstance3D.new()
			var s_mesh := BoxMesh.new()
			s_mesh.size = Vector3(0.32, 0.28, 0.45)
			snout.mesh = s_mesh
			snout.position = Vector3(0, 0.6, -0.65)
			snout.material_override = main_mat
			body_pivot.add_child(snout)

			# Olhos Luminescentes
			var eye_l := MeshInstance3D.new()
			var eye_r := MeshInstance3D.new()
			var e_mesh := SphereMesh.new()
			e_mesh.radius = 0.05
			e_mesh.height = 0.1
			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.2, 0.2)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.2, 0.1) * 2.0
			eye_l.mesh = e_mesh
			eye_l.material_override = eye_mat
			eye_l.position = Vector3(-0.11, 0.7, -0.75)
			eye_r.mesh = e_mesh
			eye_r.material_override = eye_mat
			eye_r.position = Vector3(0.11, 0.7, -0.75)
			body_pivot.add_child(eye_l)
			body_pivot.add_child(eye_r)

		2: # Saqueador Deserdado (Cápsula vermelho-ferrugem com escudo metálico)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.45
			c_mesh.height = 1.8
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.9, 0)
			main_mat.albedo_color = Color(0.58, 0.24, 0.18, 1.0) # Vermelho-ferrugem
			main_mat.roughness = 0.7

			# Escudo Lateral
			shield_mesh = MeshInstance3D.new()
			var sh_box := BoxMesh.new()
			sh_box.size = Vector3(0.12, 0.95, 0.6)
			shield_mesh.mesh = sh_box
			shield_mesh.position = Vector3(-0.55, 0.95, -0.15)
			shield_mat = StandardMaterial3D.new()
			shield_mat.albedo_color = Color(0.3, 0.35, 0.42, 1.0)
			shield_mat.metallic = 0.8
			shield_mat.roughness = 0.3
			shield_mesh.material_override = shield_mat
			body_pivot.add_child(shield_mesh)

			# Lâmina / Espada do Saqueador
			weapon_mesh = Node3D.new()
			var blade := MeshInstance3D.new()
			var bl_mesh := BoxMesh.new()
			bl_mesh.size = Vector3(0.08, 0.9, 0.15)
			blade.mesh = bl_mesh
			blade.position = Vector3(0.55, 0.85, -0.3)
			blade.rotation.x = deg_to_rad(30.0)
			var bl_mat := StandardMaterial3D.new()
			bl_mat.albedo_color = Color(0.4, 0.42, 0.45)
			bl_mat.metallic = 0.9
			blade.material_override = bl_mat
			body_pivot.add_child(blade)

		3: # Besteiro da Vigília (Cápsula verde-caçador com besta frontal)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.42
			c_mesh.height = 1.75
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.875, 0)
			main_mat.albedo_color = Color(0.18, 0.42, 0.25, 1.0) # Verde-caçador
			main_mat.roughness = 0.8

			# Besta Horizontal apontada para frente
			weapon_mesh = Node3D.new()
			weapon_mesh.position = Vector3(0.25, 0.9, -0.55)

			var stock := MeshInstance3D.new()
			var st_box := BoxMesh.new()
			st_box.size = Vector3(0.1, 0.1, 0.75)
			stock.mesh = st_box
			var st_mat := StandardMaterial3D.new()
			st_mat.albedo_color = Color(0.32, 0.2, 0.12)
			stock.material_override = st_mat
			weapon_mesh.add_child(stock)

			var bow_limbs := MeshInstance3D.new()
			var limb_box := BoxMesh.new()
			limb_box.size = Vector3(0.75, 0.08, 0.08)
			bow_limbs.mesh = limb_box
			bow_limbs.position = Vector3(0, 0, -0.3)
			var limb_mat := StandardMaterial3D.new()
			limb_mat.albedo_color = Color(0.2, 0.22, 0.25)
			limb_mat.metallic = 0.7
			bow_limbs.material_override = limb_mat
			weapon_mesh.add_child(bow_limbs)

			body_pivot.add_child(weapon_mesh)

		4: # Acólito do Eclipse (Cápsula roxo-escura com cajado e orbe sombrio)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.44
			c_mesh.height = 1.8
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.9, 0)
			main_mat.albedo_color = Color(0.25, 0.12, 0.38, 1.0) # Roxo-escuro místico
			main_mat.roughness = 0.65

			# Cajado
			weapon_mesh = Node3D.new()
			var staff := MeshInstance3D.new()
			var st_cyl := CylinderMesh.new()
			st_cyl.top_radius = 0.035
			st_cyl.bottom_radius = 0.035
			st_cyl.height = 2.1
			staff.mesh = st_cyl
			staff.position = Vector3(0.5, 1.05, -0.2)
			var staff_mat := StandardMaterial3D.new()
			staff_mat.albedo_color = Color(0.15, 0.1, 0.18)
			staff.material_override = staff_mat
			weapon_mesh.add_child(staff)

			# Orbe Sombrio no Topo
			var orb := MeshInstance3D.new()
			var orb_sph := SphereMesh.new()
			orb_sph.radius = 0.16
			orb_sph.height = 0.32
			orb.mesh = orb_sph
			orb.position = Vector3(0.5, 2.15, -0.2)
			var orb_mat := StandardMaterial3D.new()
			orb_mat.albedo_color = Color(0.75, 0.2, 0.95)
			orb_mat.emission_enabled = true
			orb_mat.emission = Color(0.7, 0.15, 0.9) * 3.0
			orb.material_override = orb_mat
			weapon_mesh.add_child(orb)

			body_pivot.add_child(weapon_mesh)

		5: # Executor de Ferro (Bruto grande 1.4x, ferro negro com maça pesada)
			body_pivot.scale = Vector3(1.4, 1.4, 1.4)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.55
			c_mesh.height = 2.0
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.0, 0)
			main_mat.albedo_color = Color(0.14, 0.15, 0.18, 1.0) # Ferro negro
			main_mat.metallic = 0.85
			main_mat.roughness = 0.35

			# Ombreiras Pesadas
			var p_mesh := BoxMesh.new()
			p_mesh.size = Vector3(0.45, 0.3, 0.45)
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.2, 0.22, 0.25)
			p_mat.metallic = 0.9

			var pauld_l := MeshInstance3D.new()
			pauld_l.mesh = p_mesh
			pauld_l.material_override = p_mat
			pauld_l.position = Vector3(-0.6, 1.7, 0)
			body_pivot.add_child(pauld_l)

			var pauld_r := MeshInstance3D.new()
			pauld_r.mesh = p_mesh
			pauld_r.material_override = p_mat
			pauld_r.position = Vector3(0.6, 1.7, 0)
			body_pivot.add_child(pauld_r)

			# Maça Pesada
			weapon_mesh = Node3D.new()
			var shaft := MeshInstance3D.new()
			var sh_cyl := CylinderMesh.new()
			sh_cyl.top_radius = 0.055
			sh_cyl.bottom_radius = 0.055
			sh_cyl.height = 1.6
			shaft.mesh = sh_cyl
			shaft.position = Vector3(0.75, 1.0, -0.3)
			shaft.rotation.x = deg_to_rad(20.0)
			var m_mat := StandardMaterial3D.new()
			m_mat.albedo_color = Color(0.1, 0.11, 0.12)
			m_mat.metallic = 0.9
			shaft.material_override = m_mat
			weapon_mesh.add_child(shaft)

			var head := MeshInstance3D.new()
			var hd_cyl := CylinderMesh.new()
			hd_cyl.top_radius = 0.26
			hd_cyl.bottom_radius = 0.26
			hd_cyl.height = 0.5
			head.mesh = hd_cyl
			head.position = Vector3(0.75, 1.75, -0.45)
			head.rotation.x = deg_to_rad(20.0)
			var hd_mat := StandardMaterial3D.new()
			hd_mat.albedo_color = Color(0.22, 0.24, 0.26)
			hd_mat.metallic = 0.95
			head.material_override = hd_mat
			weapon_mesh.add_child(head)

			body_pivot.add_child(weapon_mesh)

		6: # Lobo Alfa (Quadrúpede maior 1.45x, pelagem prateada brilhante, olhos dourados)
			body_pivot.scale = Vector3(1.3, 1.0, 1.9) # 1.45x do Lobo Comum
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.42
			c_mesh.height = 1.45
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.52, 0)
			main_mesh.rotation.x = deg_to_rad(90.0)

			main_mat.albedo_color = Color(0.82, 0.86, 0.94, 1.0) # Pelagem prateada
			main_mat.metallic = 0.25
			main_mat.roughness = 0.45
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.25, 0.55, 0.95) * 1.5 # Emissão azul-lunar suave

			# Focinho alfa pronunciado
			var snout := MeshInstance3D.new()
			var s_mesh := BoxMesh.new()
			s_mesh.size = Vector3(0.38, 0.32, 0.52)
			snout.mesh = s_mesh
			snout.position = Vector3(0, 0.68, -0.75)
			snout.material_override = main_mat
			body_pivot.add_child(snout)

			# Orelhas Lupinas
			var ear_mat := StandardMaterial3D.new()
			ear_mat.albedo_color = Color(0.7, 0.75, 0.85)
			ear_mat.roughness = 0.6
			var ear_l := MeshInstance3D.new()
			var ear_r := MeshInstance3D.new()
			var ear_box := BoxMesh.new()
			ear_box.size = Vector3(0.12, 0.25, 0.12)
			ear_l.mesh = ear_box
			ear_r.mesh = ear_box
			ear_l.material_override = ear_mat
			ear_r.material_override = ear_mat
			ear_l.position = Vector3(-0.2, 0.92, -0.45)
			ear_r.position = Vector3(0.2, 0.92, -0.45)
			body_pivot.add_child(ear_l)
			body_pivot.add_child(ear_r)

			# Olhos Dourados Luminescentes
			var eye_l := MeshInstance3D.new()
			var eye_r := MeshInstance3D.new()
			var e_mesh := SphereMesh.new()
			e_mesh.radius = 0.065
			e_mesh.height = 0.13
			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.85, 0.1)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.82, 0.05) * 3.5
			eye_l.mesh = e_mesh
			eye_l.material_override = eye_mat
			eye_l.position = Vector3(-0.14, 0.78, -0.85)
			eye_r.mesh = e_mesh
			eye_r.material_override = eye_mat
			eye_r.position = Vector3(0.14, 0.78, -0.85)
			body_pivot.add_child(eye_l)
			body_pivot.add_child(eye_r)

		7: # Licantropo Alfa (Criatura bípede colossal 1.8x, 2.2x, 1.8x, negro-carmesim, ombros largos, garras longas)
			body_pivot.scale = Vector3(1.8, 2.2, 1.8)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.58
			c_mesh.height = 2.1
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.05, 0)

			main_mat.albedo_color = Color(0.12, 0.04, 0.06, 1.0) # Pelagem negro-carmesim
			main_mat.metallic = 0.35
			main_mat.roughness = 0.6
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.85, 0.06, 0.12) * 1.2 # Brilho carmesim sinistro

			# Ombros Largos & Espinhos Musculares
			var sh_mesh := BoxMesh.new()
			sh_mesh.size = Vector3(0.65, 0.45, 0.55)
			var sh_mat := StandardMaterial3D.new()
			sh_mat.albedo_color = Color(0.18, 0.05, 0.08)
			sh_mat.metallic = 0.5
			sh_mat.roughness = 0.4

			var pauld_l := MeshInstance3D.new()
			pauld_l.mesh = sh_mesh
			pauld_l.material_override = sh_mat
			pauld_l.position = Vector3(-0.75, 1.75, 0.05)
			body_pivot.add_child(pauld_l)

			var pauld_r := MeshInstance3D.new()
			pauld_r.mesh = sh_mesh
			pauld_r.material_override = sh_mat
			pauld_r.position = Vector3(0.75, 1.75, 0.05)
			body_pivot.add_child(pauld_r)

			# Focinho Lupino Alongado
			var snout := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.42, 0.35, 0.65)
			snout.mesh = s_box
			snout.position = Vector3(0, 1.95, -0.6)
			snout.material_override = sh_mat
			body_pivot.add_child(snout)

			# Presas Afiadas
			var fang_mat := StandardMaterial3D.new()
			fang_mat.albedo_color = Color(0.95, 0.95, 0.9)
			fang_mat.roughness = 0.2
			fang_mat.metallic = 0.4
			var f_mesh := BoxMesh.new()
			f_mesh.size = Vector3(0.06, 0.2, 0.06)
			var fang_l := MeshInstance3D.new()
			var fang_r := MeshInstance3D.new()
			fang_l.mesh = f_mesh
			fang_r.mesh = f_mesh
			fang_l.material_override = fang_mat
			fang_r.material_override = fang_mat
			fang_l.position = Vector3(-0.13, 1.78, -0.85)
			fang_r.position = Vector3(0.13, 1.78, -0.85)
			body_pivot.add_child(fang_l)
			body_pivot.add_child(fang_r)

			# Olhos Vermelho-Sangue Brilhantes
			var eye_l := MeshInstance3D.new()
			var eye_r := MeshInstance3D.new()
			var e_mesh := SphereMesh.new()
			e_mesh.radius = 0.075
			e_mesh.height = 0.15
			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.05, 0.05)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.0, 0.05) * 5.0
			eye_l.mesh = e_mesh
			eye_l.material_override = eye_mat
			eye_l.position = Vector3(-0.16, 2.05, -0.7)
			eye_r.mesh = e_mesh
			eye_r.material_override = eye_mat
			eye_r.position = Vector3(0.16, 2.05, -0.7)
			body_pivot.add_child(eye_l)
			body_pivot.add_child(eye_r)

			# Garras Longas nas Duas Mãos
			var claw_mat := StandardMaterial3D.new()
			claw_mat.albedo_color = Color(0.25, 0.22, 0.24)
			claw_mat.metallic = 0.95
			claw_mat.roughness = 0.2
			claw_mat.emission_enabled = true
			claw_mat.emission = Color(0.8, 0.05, 0.05) * 0.9

			for hand_sign in [-1.0, 1.0]:
				var hand_arm := Node3D.new()
				hand_arm.position = Vector3(hand_sign * 0.85, 1.25, -0.3)
				body_pivot.add_child(hand_arm)
				for c_i in range(3):
					var claw := MeshInstance3D.new()
					var cl_mesh := BoxMesh.new()
					cl_mesh.size = Vector3(0.06, 0.06, 0.45)
					claw.mesh = cl_mesh
					claw.material_override = claw_mat
					claw.position = Vector3((c_i - 1) * 0.09, 0.0, -0.22)
					claw.rotation.x = deg_to_rad(25.0)
					hand_arm.add_child(claw)

		10: # Cultista Sombrio (Túnica de Trevas, Capuz e Orbe Sombrio Flutuante)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.42
			c_mesh.height = 1.8
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.9, 0)
			main_mat.albedo_color = Color(0.18, 0.12, 0.22, 1.0) # Púrpura escuro
			main_mat.roughness = 0.8
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.35, 0.12, 0.55) * 1.2

			# Capuz Sombrio
			var hood := MeshInstance3D.new()
			var h_mesh := BoxMesh.new()
			h_mesh.size = Vector3(0.48, 0.42, 0.48)
			hood.mesh = h_mesh
			hood.position = Vector3(0, 1.7, 0)
			hood.material_override = main_mat
			body_pivot.add_child(hood)

			# Orbe de Trevas flutuante
			var orb := MeshInstance3D.new()
			var orb_mesh := SphereMesh.new()
			orb_mesh.radius = 0.14
			orb_mesh.height = 0.28
			orb.mesh = orb_mesh
			orb.position = Vector3(0.55, 1.2, -0.3)
			var orb_mat := StandardMaterial3D.new()
			orb_mat.albedo_color = Color(0.2, 0.05, 0.35)
			orb_mat.emission_enabled = true
			orb_mat.emission = Color(0.65, 0.15, 0.9) * 3.5
			orb.material_override = orb_mat
			body_pivot.add_child(orb)

		11: # Gárgula de Pedra (Pétrea, Asas de Rocha e Alta Defesa)
			body_pivot.scale = Vector3(1.1, 1.1, 1.1)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.48
			c_mesh.height = 1.85
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.95, 0)
			main_mat.albedo_color = Color(0.38, 0.4, 0.42, 1.0) # Pedra cinzenta
			main_mat.roughness = 0.95
			main_mat.metallic = 0.25

			# Asas de Pedra nas Costas
			var wing_mat := StandardMaterial3D.new()
			wing_mat.albedo_color = Color(0.3, 0.32, 0.35)
			wing_mat.roughness = 0.9
			for wing_side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var w_box := BoxMesh.new()
				w_box.size = Vector3(0.8, 0.45, 0.12)
				wing.mesh = w_box
				wing.material_override = wing_mat
				wing.position = Vector3(wing_side * 0.6, 1.35, 0.35)
				wing.rotation.y = deg_to_rad(wing_side * 30.0)
				wing.rotation.z = deg_to_rad(wing_side * 20.0)
				body_pivot.add_child(wing)

			# Olhos de Âmbar
			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.6, 0.1)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.55, 0.05) * 3.0
			for side in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				var e_s := SphereMesh.new()
				e_s.radius = 0.05
				e_s.height = 0.1
				eye.mesh = e_s
				eye.material_override = eye_mat
				eye.position = Vector3(side * 0.15, 1.6, -0.45)
				body_pivot.add_child(eye)

		12: # Mini-Boss Inquisidor Vex (Foice Longa e Túnica Carmesim/Trevas)
			body_pivot.scale = Vector3(1.25, 1.25, 1.25)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.5
			c_mesh.height = 2.0
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.0, 0)
			main_mat.albedo_color = Color(0.12, 0.05, 0.12, 1.0)
			main_mat.metallic = 0.4
			main_mat.roughness = 0.6
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.7, 0.05, 0.2) * 1.5

			# Foice Sombria do Inquisidor
			weapon_mesh = Node3D.new()
			var shaft := MeshInstance3D.new()
			var sh_cyl := CylinderMesh.new()
			sh_cyl.top_radius = 0.04
			sh_cyl.bottom_radius = 0.04
			sh_cyl.height = 2.1
			shaft.mesh = sh_cyl
			shaft.position = Vector3(0.65, 1.1, -0.2)
			shaft.rotation.x = deg_to_rad(15.0)
			var w_mat := StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.15, 0.15, 0.18)
			w_mat.metallic = 0.9
			shaft.material_override = w_mat
			weapon_mesh.add_child(shaft)

			var blade := MeshInstance3D.new()
			var bl_box := BoxMesh.new()
			bl_box.size = Vector3(0.08, 0.8, 0.35)
			blade.mesh = bl_box
			blade.position = Vector3(0.65, 2.05, -0.4)
			blade.rotation.x = deg_to_rad(45.0)
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.85, 0.1, 0.25)
			b_mat.emission_enabled = true
			b_mat.emission = Color(0.9, 0.05, 0.2) * 2.8
			blade.material_override = b_mat
			weapon_mesh.add_child(blade)
			body_pivot.add_child(weapon_mesh)

		13: # Boss Normal Comandante Vaelen, o Traidor (Armadura de Placas, Espadão)
			body_pivot.scale = Vector3(1.35, 1.35, 1.35)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.54
			c_mesh.height = 2.15
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.08, 0)
			main_mat.albedo_color = Color(0.2, 0.22, 0.26, 1.0)
			main_mat.metallic = 0.9
			main_mat.roughness = 0.3

			# Ombreiras Douradas
			var p_mesh := BoxMesh.new()
			p_mesh.size = Vector3(0.5, 0.35, 0.5)
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.72, 0.58, 0.22)
			p_mat.metallic = 0.95
			for side in [-1.0, 1.0]:
				var pauld := MeshInstance3D.new()
				pauld.mesh = p_mesh
				pauld.material_override = p_mat
				pauld.position = Vector3(side * 0.65, 1.85, 0)
				body_pivot.add_child(pauld)

			# Espada Larga do Comandante
			weapon_mesh = Node3D.new()
			var sw_blade := MeshInstance3D.new()
			var sb_mesh := BoxMesh.new()
			sb_mesh.size = Vector3(0.12, 1.7, 0.25)
			sw_blade.mesh = sb_mesh
			sw_blade.position = Vector3(0.7, 1.15, -0.3)
			sw_blade.rotation.x = deg_to_rad(25.0)
			var sw_mat := StandardMaterial3D.new()
			sw_mat.albedo_color = Color(0.85, 0.88, 0.92)
			sw_mat.metallic = 0.95
			sw_blade.material_override = sw_mat
			weapon_mesh.add_child(sw_blade)
			body_pivot.add_child(weapon_mesh)

		14: # Raid Boss Malakor, o Arauto do Eclipse (Colossal 2.2x, Aura do Eclipse Total)
			body_pivot.scale = Vector3(2.2, 2.2, 2.2)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.62
			c_mesh.height = 2.4
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.2, 0)
			main_mat.albedo_color = Color(0.08, 0.04, 0.12, 1.0) # Vazio Abissal
			main_mat.metallic = 0.6
			main_mat.roughness = 0.4
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.7, 0.15, 0.95) * 2.8 # Aura Roxo-Eclipse Radiante

			# Asas de Sombra Primordiais
			var wing_mat := StandardMaterial3D.new()
			wing_mat.albedo_color = Color(0.12, 0.05, 0.2)
			wing_mat.emission_enabled = true
			wing_mat.emission = Color(0.6, 0.1, 0.8) * 2.0
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var w_box := BoxMesh.new()
				w_box.size = Vector3(1.3, 0.7, 0.15)
				wing.mesh = w_box
				wing.material_override = wing_mat
				wing.position = Vector3(side * 0.95, 1.6, 0.4)
				wing.rotation.y = deg_to_rad(side * 35.0)
				wing.rotation.z = deg_to_rad(side * 25.0)
				body_pivot.add_child(wing)

			# Foice Primordial do Eclipse
			weapon_mesh = Node3D.new()
			var m_shaft := MeshInstance3D.new()
			var ms_cyl := CylinderMesh.new()
			ms_cyl.top_radius = 0.05
			ms_cyl.bottom_radius = 0.05
			ms_cyl.height = 2.6
			m_shaft.mesh = ms_cyl
			m_shaft.position = Vector3(0.9, 1.3, -0.3)
			m_shaft.rotation.x = deg_to_rad(15.0)
			var ms_mat := StandardMaterial3D.new()
			ms_mat.albedo_color = Color(0.15, 0.08, 0.2)
			ms_mat.metallic = 0.95
			m_shaft.material_override = ms_mat
			weapon_mesh.add_child(m_shaft)

			var m_blade := MeshInstance3D.new()
			var mb_box := BoxMesh.new()
			mb_box.size = Vector3(0.12, 1.2, 0.5)
			m_blade.mesh = mb_box
			m_blade.position = Vector3(0.9, 2.4, -0.55)
			m_blade.rotation.x = deg_to_rad(45.0)
			var mb_mat := StandardMaterial3D.new()
			mb_mat.albedo_color = Color(0.8, 0.15, 1.0)
			mb_mat.emission_enabled = true
			mb_mat.emission = Color(0.9, 0.2, 1.0) * 4.5
			m_blade.material_override = mb_mat
			weapon_mesh.add_child(m_blade)
			body_pivot.add_child(weapon_mesh)

		15: # Aranha Tecelã da Bruma (Aracnídeo negro-púrpura com 8 patas e marcas rubras)
			body_pivot.scale = Vector3(1.0, 1.0, 1.0)
			var cf_mesh := SphereMesh.new()
			cf_mesh.radius = 0.32
			cf_mesh.height = 0.5
			main_mesh.mesh = cf_mesh
			main_mesh.position = Vector3(0, 0.35, -0.15)
			main_mat.albedo_color = Color(0.12, 0.08, 0.16, 1.0)
			main_mat.roughness = 0.6
			main_mat.metallic = 0.3

			var abdo := MeshInstance3D.new()
			var ab_mesh := SphereMesh.new()
			ab_mesh.radius = 0.48
			ab_mesh.height = 0.8
			abdo.mesh = ab_mesh
			abdo.position = Vector3(0, 0.48, 0.42)
			var ab_mat := StandardMaterial3D.new()
			ab_mat.albedo_color = Color(0.15, 0.06, 0.2, 1.0)
			ab_mat.roughness = 0.5
			abdo.material_override = ab_mat
			body_pivot.add_child(abdo)

			var mark := MeshInstance3D.new()
			var mk_mesh := BoxMesh.new()
			mk_mesh.size = Vector3(0.14, 0.14, 0.35)
			mark.mesh = mk_mesh
			mark.position = Vector3(0, 0.72, 0.45)
			mark.rotation.y = deg_to_rad(45.0)
			var mk_mat := StandardMaterial3D.new()
			mk_mat.albedo_color = Color(0.9, 0.05, 0.15)
			mk_mat.emission_enabled = true
			mk_mat.emission = Color(1.0, 0.1, 0.2) * 3.0
			mark.material_override = mk_mat
			body_pivot.add_child(mark)

			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.1, 0.1)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.05, 0.15) * 3.5
			var eye_offsets := [
				Vector3(-0.12, 0.45, -0.38), Vector3(0.12, 0.45, -0.38),
				Vector3(-0.06, 0.49, -0.4), Vector3(0.06, 0.49, -0.4),
				Vector3(-0.16, 0.39, -0.35), Vector3(0.16, 0.39, -0.35)
			]
			for e_pos in eye_offsets:
				var eye := MeshInstance3D.new()
				var e_s := SphereMesh.new()
				e_s.radius = 0.035
				e_s.height = 0.07
				eye.mesh = e_s
				eye.material_override = eye_mat
				eye.position = e_pos
				body_pivot.add_child(eye)

			var leg_mat := StandardMaterial3D.new()
			leg_mat.albedo_color = Color(0.1, 0.05, 0.12)
			leg_mat.metallic = 0.4
			for i in range(4):
				var z_offset := -0.25 + i * 0.18
				for side in [-1.0, 1.0]:
					var leg_upper := MeshInstance3D.new()
					var l_box := BoxMesh.new()
					l_box.size = Vector3(0.06, 0.45, 0.06)
					leg_upper.mesh = l_box
					leg_upper.material_override = leg_mat
					leg_upper.position = Vector3(side * 0.32, 0.42, z_offset)
					leg_upper.rotation.z = deg_to_rad(side * -50.0)
					leg_upper.rotation.y = deg_to_rad(side * (20.0 - i * 15.0))
					body_pivot.add_child(leg_upper)

					var leg_lower := MeshInstance3D.new()
					var ll_box := BoxMesh.new()
					ll_box.size = Vector3(0.05, 0.5, 0.05)
					leg_lower.mesh = ll_box
					leg_lower.material_override = leg_mat
					leg_lower.position = Vector3(side * 0.6, 0.2, z_offset)
					leg_lower.rotation.z = deg_to_rad(side * 40.0)
					body_pivot.add_child(leg_lower)

		16: # Arachna, a Rainha Tecelã (Raid Boss Colossal 2.8x, Coroa Cristalina, Patas Titânicas)
			body_pivot.scale = Vector3(2.8, 2.8, 2.8)
			var cf_mesh := SphereMesh.new()
			cf_mesh.radius = 0.55
			cf_mesh.height = 0.85
			main_mesh.mesh = cf_mesh
			main_mesh.position = Vector3(0, 0.6, -0.25)
			main_mat.albedo_color = Color(0.06, 0.02, 0.1, 1.0)
			main_mat.metallic = 0.8
			main_mat.roughness = 0.25

			var abdo := MeshInstance3D.new()
			var ab_mesh := SphereMesh.new()
			ab_mesh.radius = 0.95
			ab_mesh.height = 1.55
			abdo.mesh = ab_mesh
			abdo.position = Vector3(0, 0.85, 0.8)
			var ab_mat := StandardMaterial3D.new()
			ab_mat.albedo_color = Color(0.1, 0.03, 0.14, 1.0)
			ab_mat.metallic = 0.6
			ab_mat.roughness = 0.35
			abdo.material_override = ab_mat
			body_pivot.add_child(abdo)

			var crest := MeshInstance3D.new()
			var cr_mesh := BoxMesh.new()
			cr_mesh.size = Vector3(0.35, 0.2, 0.7)
			crest.mesh = cr_mesh
			crest.position = Vector3(0, 1.45, 0.85)
			var cr_mat := StandardMaterial3D.new()
			cr_mat.albedo_color = Color(1.0, 0.05, 0.2)
			cr_mat.emission_enabled = true
			cr_mat.emission = Color(1.0, 0.08, 0.25) * 4.5
			crest.material_override = cr_mat
			body_pivot.add_child(crest)

			var crown_mat := StandardMaterial3D.new()
			crown_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.9)
			crown_mat.metallic = 0.9
			crown_mat.roughness = 0.1
			crown_mat.emission_enabled = true
			crown_mat.emission = Color(0.65, 0.85, 1.0) * 3.0
			for sp_i in range(5):
				var spike := MeshInstance3D.new()
				var sp_mesh := CylinderMesh.new()
				sp_mesh.top_radius = 0.01
				sp_mesh.bottom_radius = 0.045
				sp_mesh.height = 0.45 + (0.15 if sp_i == 2 else 0.0)
				spike.mesh = sp_mesh
				spike.material_override = crown_mat
				var angle := deg_to_rad(-50.0 + sp_i * 25.0)
				spike.position = Vector3(sin(angle) * 0.3, 1.05, -0.25 + cos(angle) * 0.1)
				spike.rotation.z = -angle * 0.6
				body_pivot.add_child(spike)

			var r_eye_mat := StandardMaterial3D.new()
			r_eye_mat.albedo_color = Color(1.0, 0.05, 0.1)
			r_eye_mat.emission_enabled = true
			r_eye_mat.emission = Color(1.0, 0.05, 0.15) * 5.0
			var r_eye_pos := [
				Vector3(-0.2, 0.75, -0.65), Vector3(0.2, 0.75, -0.65),
				Vector3(-0.1, 0.82, -0.68), Vector3(0.1, 0.82, -0.68),
				Vector3(-0.28, 0.68, -0.6), Vector3(0.28, 0.68, -0.6)
			]
			for e_p in r_eye_pos:
				var eye := MeshInstance3D.new()
				var e_s := SphereMesh.new()
				e_s.radius = 0.065
				e_s.height = 0.13
				eye.mesh = e_s
				eye.material_override = r_eye_mat
				eye.position = e_p
				body_pivot.add_child(eye)

			var r_leg_mat := StandardMaterial3D.new()
			r_leg_mat.albedo_color = Color(0.08, 0.03, 0.1)
			r_leg_mat.metallic = 0.7
			for i in range(4):
				var z_offset := -0.4 + i * 0.32
				for side in [-1.0, 1.0]:
					var leg_u := MeshInstance3D.new()
					var lu_box := BoxMesh.new()
					lu_box.size = Vector3(0.11, 0.85, 0.11)
					leg_u.mesh = lu_box
					leg_u.material_override = r_leg_mat
					leg_u.position = Vector3(side * 0.6, 0.75, z_offset)
					leg_u.rotation.z = deg_to_rad(side * -55.0)
					leg_u.rotation.y = deg_to_rad(side * (30.0 - i * 20.0))
					body_pivot.add_child(leg_u)

					var leg_l := MeshInstance3D.new()
					var ll_box := BoxMesh.new()
					ll_box.size = Vector3(0.09, 1.05, 0.09)
					leg_l.mesh = ll_box
					leg_l.material_override = r_leg_mat
					leg_l.position = Vector3(side * 1.15, 0.4, z_offset)
					leg_l.rotation.z = deg_to_rad(side * 42.0)
					body_pivot.add_child(leg_l)

		17: # Lodo Ácido Corrosivo (Massa translúcida verde-fluorescente brilhante)
			body_pivot.scale = Vector3(1.15, 0.85, 1.15)
			var s_mesh := SphereMesh.new()
			s_mesh.radius = 0.55
			s_mesh.height = 0.8
			main_mesh.mesh = s_mesh
			main_mesh.position = Vector3(0, 0.38, 0)
			main_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			main_mat.albedo_color = Color(0.35, 0.95, 0.18, 0.78)
			main_mat.roughness = 0.1
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.4, 1.0, 0.1) * 2.5

			var core := MeshInstance3D.new()
			var c_mesh := SphereMesh.new()
			c_mesh.radius = 0.28
			c_mesh.height = 0.42
			core.mesh = c_mesh
			core.position = Vector3(0, 0.38, 0)
			var core_mat := StandardMaterial3D.new()
			core_mat.albedo_color = Color(0.85, 1.0, 0.25, 0.95)
			core_mat.emission_enabled = true
			core_mat.emission = Color(0.85, 1.0, 0.2) * 4.0
			core.material_override = core_mat
			body_pivot.add_child(core)

			for b_i in range(3):
				var bubble := MeshInstance3D.new()
				var b_sph := SphereMesh.new()
				b_sph.radius = 0.1
				b_sph.height = 0.18
				bubble.mesh = b_sph
				bubble.material_override = core_mat
				var angle := b_i * 2.1
				bubble.position = Vector3(sin(angle) * 0.28, 0.65, cos(angle) * 0.28)
				body_pivot.add_child(bubble)

		18: # Escorpião Abissal Gigante (Carapaça quitinosa negra, duas pinças e cauda arqueada com ferrão neon)
			body_pivot.scale = Vector3(1.2, 1.1, 1.3)
			var c_mesh := BoxMesh.new()
			c_mesh.size = Vector3(0.75, 0.35, 1.0)
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.32, 0)
			main_mat.albedo_color = Color(0.08, 0.08, 0.1, 1.0)
			main_mat.metallic = 0.85
			main_mat.roughness = 0.25

			var claw_mat := StandardMaterial3D.new()
			claw_mat.albedo_color = Color(0.12, 0.1, 0.14)
			claw_mat.metallic = 0.8
			for side in [-1.0, 1.0]:
				var arm := MeshInstance3D.new()
				var arm_b := BoxMesh.new()
				arm_b.size = Vector3(0.12, 0.12, 0.55)
				arm.mesh = arm_b
				arm.material_override = claw_mat
				arm.position = Vector3(side * 0.5, 0.35, -0.55)
				arm.rotation.y = deg_to_rad(side * -25.0)
				body_pivot.add_child(arm)

				var pincher := MeshInstance3D.new()
				var p_b := BoxMesh.new()
				p_b.size = Vector3(0.2, 0.1, 0.35)
				pincher.mesh = p_b
				pincher.material_override = claw_mat
				pincher.position = Vector3(side * 0.62, 0.35, -0.85)
				pincher.rotation.y = deg_to_rad(side * 35.0)
				body_pivot.add_child(pincher)

			var tail_mat := StandardMaterial3D.new()
			tail_mat.albedo_color = Color(0.1, 0.09, 0.12)
			tail_mat.metallic = 0.85
			var t_nodes := [
				Vector3(0, 0.42, 0.55),
				Vector3(0, 0.7, 0.65),
				Vector3(0, 1.0, 0.5),
				Vector3(0, 1.15, 0.2),
				Vector3(0, 1.1, -0.05)
			]
			for t_pos in t_nodes:
				var node := MeshInstance3D.new()
				var n_box := BoxMesh.new()
				n_box.size = Vector3(0.22, 0.2, 0.25)
				node.mesh = n_box
				node.material_override = tail_mat
				node.position = t_pos
				body_pivot.add_child(node)

			var stinger := MeshInstance3D.new()
			var st_cone := CylinderMesh.new()
			st_cone.top_radius = 0.01
			st_cone.bottom_radius = 0.09
			st_cone.height = 0.32
			stinger.mesh = st_cone
			stinger.position = Vector3(0, 0.95, -0.2)
			stinger.rotation.x = deg_to_rad(-70.0)
			var st_mat := StandardMaterial3D.new()
			st_mat.albedo_color = Color(0.1, 1.0, 0.3)
			st_mat.emission_enabled = true
			st_mat.emission = Color(0.15, 1.0, 0.35) * 4.5
			stinger.material_override = st_mat
			body_pivot.add_child(stinger)

		19: # Experimento Nº 0: A Quimera Costurada (Fera colossal assimétrica, cicatrizes brilhantes e chifres)
			body_pivot.scale = Vector3(1.7, 1.7, 1.7)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.58
			c_mesh.height = 2.0
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.0, 0)
			main_mat.albedo_color = Color(0.28, 0.2, 0.22, 1.0)
			main_mat.roughness = 0.7

			var drac_arm := MeshInstance3D.new()
			var da_box := BoxMesh.new()
			da_box.size = Vector3(0.38, 0.9, 0.4)
			drac_arm.mesh = da_box
			drac_arm.position = Vector3(-0.65, 1.05, 0.1)
			var da_mat := StandardMaterial3D.new()
			da_mat.albedo_color = Color(0.12, 0.28, 0.18)
			da_mat.metallic = 0.7
			drac_arm.material_override = da_mat
			body_pivot.add_child(drac_arm)

			var claw := MeshInstance3D.new()
			var cl_box := BoxMesh.new()
			cl_box.size = Vector3(0.32, 0.45, 0.3)
			claw.mesh = cl_box
			claw.position = Vector3(-0.68, 0.5, -0.2)
			claw.rotation.x = deg_to_rad(30.0)
			var cl_mat := StandardMaterial3D.new()
			cl_mat.albedo_color = Color(0.08, 0.08, 0.08)
			claw.material_override = cl_mat
			body_pivot.add_child(claw)

			var stitch_mat := StandardMaterial3D.new()
			stitch_mat.albedo_color = Color(0.1, 0.9, 0.8)
			stitch_mat.emission_enabled = true
			stitch_mat.emission = Color(0.2, 1.0, 0.85) * 3.8
			var st_offsets := [
				Vector3(0, 1.4, -0.55), Vector3(0.15, 1.1, -0.55),
				Vector3(-0.15, 0.8, -0.55), Vector3(0, 0.5, -0.55)
			]
			for s_pos in st_offsets:
				var stitch := MeshInstance3D.new()
				var st_b := BoxMesh.new()
				st_b.size = Vector3(0.25, 0.04, 0.05)
				stitch.mesh = st_b
				stitch.material_override = stitch_mat
				stitch.position = s_pos
				stitch.rotation.z = deg_to_rad(randf_range(-25.0, 25.0))
				body_pivot.add_child(stitch)

			var horn_mat := StandardMaterial3D.new()
			horn_mat.albedo_color = Color(0.15, 0.12, 0.1)
			for h_i in [-1.0, 1.0]:
				var horn := MeshInstance3D.new()
				var hn_c := CylinderMesh.new()
				hn_c.top_radius = 0.02
				hn_c.bottom_radius = 0.09
				hn_c.height = 0.55 if h_i > 0 else 0.35
				horn.mesh = hn_c
				horn.material_override = horn_mat
				horn.position = Vector3(h_i * 0.28, 2.05, -0.1)
				horn.rotation.z = deg_to_rad(h_i * -30.0)
				horn.rotation.x = deg_to_rad(-20.0)
				body_pivot.add_child(horn)

		20: # Golem de Gelo Antigo (Estrutura monolítica cristalina azul-gelo)
			body_pivot.scale = Vector3(1.4, 1.4, 1.4)
			var c_mesh := BoxMesh.new()
			c_mesh.size = Vector3(0.9, 1.3, 0.7)
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.1, 0)
			main_mat.albedo_color = Color(0.45, 0.75, 0.95, 1.0)
			main_mat.metallic = 0.35
			main_mat.roughness = 0.15
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.25, 0.65, 0.95) * 1.8

			var spike_mat := StandardMaterial3D.new()
			spike_mat.albedo_color = Color(0.7, 0.9, 1.0)
			spike_mat.emission_enabled = true
			spike_mat.emission = Color(0.4, 0.8, 1.0) * 2.8
			for side in [-1.0, 1.0]:
				var sh_spk := MeshInstance3D.new()
				var sp_c := CylinderMesh.new()
				sp_c.top_radius = 0.02
				sp_c.bottom_radius = 0.15
				sp_c.height = 0.6
				sh_spk.mesh = sp_c
				sh_spk.material_override = spike_mat
				sh_spk.position = Vector3(side * 0.65, 1.75, 0)
				sh_spk.rotation.z = deg_to_rad(side * -35.0)
				body_pivot.add_child(sh_spk)

			for side in [-1.0, 1.0]:
				var fist := MeshInstance3D.new()
				var f_box := BoxMesh.new()
				f_box.size = Vector3(0.4, 0.45, 0.4)
				fist.mesh = f_box
				fist.material_override = main_mat
				fist.position = Vector3(side * 0.72, 0.7, -0.2)
				body_pivot.add_child(fist)

			var visor := MeshInstance3D.new()
			var v_box := BoxMesh.new()
			v_box.size = Vector3(0.45, 0.1, 0.12)
			visor.mesh = v_box
			visor.position = Vector3(0, 1.6, -0.36)
			visor.material_override = spike_mat
			body_pivot.add_child(visor)

		21: # Draco de Geada Selvagem (Réptil dracônico com asas e espinhos glaciais)
			body_pivot.scale = Vector3(1.5, 1.3, 1.8)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.42
			c_mesh.height = 1.6
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.65, 0)
			main_mesh.rotation.x = deg_to_rad(90.0)
			main_mat.albedo_color = Color(0.35, 0.65, 0.88, 1.0)
			main_mat.roughness = 0.35
			main_mat.metallic = 0.4

			var head := MeshInstance3D.new()
			var h_box := BoxMesh.new()
			h_box.size = Vector3(0.35, 0.3, 0.55)
			head.mesh = h_box
			head.position = Vector3(0, 0.85, -0.85)
			head.material_override = main_mat
			body_pivot.add_child(head)

			var horn_mat := StandardMaterial3D.new()
			horn_mat.albedo_color = Color(0.75, 0.9, 1.0)
			horn_mat.emission_enabled = true
			horn_mat.emission = Color(0.4, 0.8, 1.0) * 3.0
			for side in [-1.0, 1.0]:
				var horn := MeshInstance3D.new()
				var hn_c := CylinderMesh.new()
				hn_c.top_radius = 0.02
				hn_c.bottom_radius = 0.07
				hn_c.height = 0.5
				horn.mesh = hn_c
				horn.material_override = horn_mat
				horn.position = Vector3(side * 0.18, 1.1, -0.75)
				horn.rotation.x = deg_to_rad(30.0)
				horn.rotation.z = deg_to_rad(side * -25.0)
				body_pivot.add_child(horn)

			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var w_box := BoxMesh.new()
				w_box.size = Vector3(1.1, 0.45, 0.08)
				wing.mesh = w_box
				wing.material_override = horn_mat
				wing.position = Vector3(side * 0.8, 1.0, 0.1)
				wing.rotation.y = deg_to_rad(side * 30.0)
				wing.rotation.z = deg_to_rad(side * 20.0)
				body_pivot.add_child(wing)

			var tail := MeshInstance3D.new()
			var t_box := BoxMesh.new()
			t_box.size = Vector3(0.18, 0.18, 0.9)
			tail.mesh = t_box
			tail.position = Vector3(0, 0.55, 1.15)
			tail.rotation.x = deg_to_rad(-15.0)
			tail.material_override = main_mat
			body_pivot.add_child(tail)

		22: # Ymir, o Patriarca Jotunar (Boss Colossal 3.0x, Barba de Estalactites e Clava Glacial)
			body_pivot.scale = Vector3(3.0, 3.0, 3.0)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.65
			c_mesh.height = 2.5
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.3, 0)
			main_mat.albedo_color = Color(0.4, 0.72, 0.92, 1.0)
			main_mat.metallic = 0.4
			main_mat.roughness = 0.2
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.2, 0.6, 0.95) * 2.2

			var crown_mat := StandardMaterial3D.new()
			crown_mat.albedo_color = Color(0.8, 0.95, 1.0)
			crown_mat.emission_enabled = true
			crown_mat.emission = Color(0.45, 0.85, 1.0) * 4.0
			for c_i in range(5):
				var peak := MeshInstance3D.new()
				var pk_c := CylinderMesh.new()
				pk_c.top_radius = 0.01
				pk_c.bottom_radius = 0.07
				pk_c.height = 0.55 + (0.2 if c_i == 2 else 0.0)
				peak.mesh = pk_c
				peak.material_override = crown_mat
				var angle := deg_to_rad(-50.0 + c_i * 25.0)
				peak.position = Vector3(sin(angle) * 0.35, 2.55, cos(angle) * 0.15)
				peak.rotation.z = -angle * 0.5
				body_pivot.add_child(peak)

			for b_i in range(4):
				var icicle := MeshInstance3D.new()
				var ic_c := CylinderMesh.new()
				ic_c.top_radius = 0.04
				ic_c.bottom_radius = 0.01
				ic_c.height = 0.45
				icicle.mesh = ic_c
				icicle.material_override = crown_mat
				icicle.position = Vector3(-0.15 + b_i * 0.1, 2.05, -0.32)
				body_pivot.add_child(icicle)

			for side in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				var e_s := SphereMesh.new()
				e_s.radius = 0.07
				e_s.height = 0.14
				eye.mesh = e_s
				eye.material_override = crown_mat
				eye.position = Vector3(side * 0.16, 2.28, -0.38)
				body_pivot.add_child(eye)

			weapon_mesh = Node3D.new()
			var club_shaft := MeshInstance3D.new()
			var cs_c := CylinderMesh.new()
			cs_c.top_radius = 0.06
			cs_c.bottom_radius = 0.06
			cs_c.height = 2.8
			club_shaft.mesh = cs_c
			club_shaft.position = Vector3(0.95, 1.4, -0.3)
			club_shaft.rotation.x = deg_to_rad(20.0)
			var w_mat := StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.2, 0.4, 0.6)
			w_mat.metallic = 0.8
			club_shaft.material_override = w_mat
			weapon_mesh.add_child(club_shaft)

			var club_head := MeshInstance3D.new()
			var ch_box := BoxMesh.new()
			ch_box.size = Vector3(0.45, 1.1, 0.45)
			club_head.mesh = ch_box
			club_head.position = Vector3(0.95, 2.5, -0.6)
			club_head.material_override = crown_mat
			weapon_mesh.add_child(club_head)
			body_pivot.add_child(weapon_mesh)

		23: # Guarda Sanguinário de Vesperian (Nobre em armadura negra/carmesim com alabarda de sangue)
			body_pivot.scale = Vector3(1.2, 1.25, 1.2)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.48
			c_mesh.height = 1.95
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.98, 0)
			main_mat.albedo_color = Color(0.1, 0.06, 0.08, 1.0)
			main_mat.metallic = 0.9
			main_mat.roughness = 0.35

			var cape := MeshInstance3D.new()
			var cp_box := BoxMesh.new()
			cp_box.size = Vector3(0.65, 1.4, 0.08)
			cape.mesh = cp_box
			cape.position = Vector3(0, 0.95, 0.32)
			cape.rotation.x = deg_to_rad(-12.0)
			var cp_mat := StandardMaterial3D.new()
			cp_mat.albedo_color = Color(0.65, 0.05, 0.12)
			cape.material_override = cp_mat
			body_pivot.add_child(cape)

			var sh_mat := StandardMaterial3D.new()
			sh_mat.albedo_color = Color(0.45, 0.08, 0.12)
			sh_mat.metallic = 0.8
			for side in [-1.0, 1.0]:
				var pauld := MeshInstance3D.new()
				var p_b := BoxMesh.new()
				p_b.size = Vector3(0.38, 0.25, 0.38)
				pauld.mesh = p_b
				pauld.material_override = sh_mat
				pauld.position = Vector3(side * 0.55, 1.65, 0)
				pauld.rotation.z = deg_to_rad(side * -25.0)
				body_pivot.add_child(pauld)

			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.05, 0.15)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.05, 0.2) * 3.5
			for side in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				var e_b := BoxMesh.new()
				e_b.size = Vector3(0.08, 0.04, 0.05)
				eye.mesh = e_b
				eye.material_override = eye_mat
				eye.position = Vector3(side * 0.12, 1.7, -0.32)
				body_pivot.add_child(eye)

			weapon_mesh = Node3D.new()
			var shaft := MeshInstance3D.new()
			var s_cyl := CylinderMesh.new()
			s_cyl.top_radius = 0.03
			s_cyl.bottom_radius = 0.03
			s_cyl.height = 2.4
			shaft.mesh = s_cyl
			shaft.position = Vector3(0.62, 1.1, -0.2)
			shaft.rotation.x = deg_to_rad(15.0)
			var w_mat := StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.12, 0.12, 0.15)
			w_mat.metallic = 0.95
			shaft.material_override = w_mat
			weapon_mesh.add_child(shaft)

			var spear_head := MeshInstance3D.new()
			var sh_b := BoxMesh.new()
			sh_b.size = Vector3(0.08, 0.65, 0.25)
			spear_head.mesh = sh_b
			spear_head.position = Vector3(0.62, 2.15, -0.45)
			spear_head.rotation.x = deg_to_rad(15.0)
			spear_head.material_override = eye_mat
			weapon_mesh.add_child(spear_head)
			body_pivot.add_child(weapon_mesh)

		24: # Lorde Vesperian, o Progenitor Vampiro (Raid Boss Secreto Colossal 2.5x, Capa Longa, Olhos Rubros e Aura)
			body_pivot.scale = Vector3(2.5, 2.5, 2.5)
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.52
			c_mesh.height = 2.2
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 1.1, 0)
			main_mat.albedo_color = Color(0.06, 0.03, 0.08, 1.0)
			main_mat.metallic = 0.85
			main_mat.roughness = 0.25

			var cape := MeshInstance3D.new()
			var cp_box := BoxMesh.new()
			cp_box.size = Vector3(1.1, 1.85, 0.08)
			cape.mesh = cp_box
			cape.position = Vector3(0, 1.05, 0.42)
			cape.rotation.x = deg_to_rad(-18.0)
			var cp_mat := StandardMaterial3D.new()
			cp_mat.albedo_color = Color(0.75, 0.02, 0.1)
			cp_mat.emission_enabled = true
			cp_mat.emission = Color(0.6, 0.02, 0.08) * 1.5
			cape.material_override = cp_mat
			body_pivot.add_child(cape)

			var col_mat := StandardMaterial3D.new()
			col_mat.albedo_color = Color(0.1, 0.04, 0.08)
			for side in [-1.0, 1.0]:
				var col := MeshInstance3D.new()
				var col_b := BoxMesh.new()
				col_b.size = Vector3(0.12, 0.5, 0.28)
				col.mesh = col_b
				col.material_override = col_mat
				col.position = Vector3(side * 0.35, 2.05, 0.12)
				col.rotation.z = deg_to_rad(side * -18.0)
				body_pivot.add_child(col)

			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.02, 0.1)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.02, 0.15) * 5.5
			for side in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				var e_s := SphereMesh.new()
				e_s.radius = 0.06
				e_s.height = 0.12
				eye.mesh = e_s
				eye.material_override = eye_mat
				eye.position = Vector3(side * 0.14, 1.95, -0.38)
				body_pivot.add_child(eye)

			var bat_mat := StandardMaterial3D.new()
			bat_mat.albedo_color = Color(0.85, 0.05, 0.15)
			bat_mat.emission_enabled = true
			bat_mat.emission = Color(0.9, 0.05, 0.2) * 3.5
			for b_i in range(4):
				var bat := MeshInstance3D.new()
				var bt_b := BoxMesh.new()
				bt_b.size = Vector3(0.24, 0.08, 0.15)
				bat.mesh = bt_b
				bat.material_override = bat_mat
				var angle := b_i * 1.57
				bat.position = Vector3(sin(angle) * 0.75, 1.5 + (0.3 if b_i % 2 == 0 else -0.2), cos(angle) * 0.75)
				bat.rotation.y = angle + deg_to_rad(45.0)
				body_pivot.add_child(bat)

			weapon_mesh = Node3D.new()
			var w_blade := MeshInstance3D.new()
			var wb_box := BoxMesh.new()
			wb_box.size = Vector3(0.12, 1.9, 0.28)
			w_blade.mesh = wb_box
			w_blade.position = Vector3(0.78, 1.25, -0.35)
			w_blade.rotation.x = deg_to_rad(22.0)
			w_blade.material_override = eye_mat
			weapon_mesh.add_child(w_blade)
			body_pivot.add_child(weapon_mesh)

		_:
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.45
			c_mesh.height = 1.8
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.9, 0)
			main_mat.albedo_color = Color(0.4, 0.4, 0.4)

	_apply_creature_model()

	# Label 3D Billboard para Nome e HP
	if name_tag == null:
		name_tag = Label3D.new()
		add_child(name_tag)
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.outline_size = 7
		name_tag.outline_modulate = Color(0, 0, 0, 1)
		name_tag.font_size = 22

	var tag_height := 2.3
	if mob_type == 1 or mob_type == 17:
		tag_height = 1.4
	elif mob_type == 15:
		tag_height = 1.6
	elif mob_type == 18:
		tag_height = 2.2
	elif mob_type == 5:
		tag_height = 3.3
	elif mob_type == 6:
		tag_height = 1.9
	elif mob_type == 7:
		tag_height = 4.3
	elif mob_type == 10:
		tag_height = 2.4
	elif mob_type == 11:
		tag_height = 2.6
	elif mob_type == 12:
		tag_height = 3.3
	elif mob_type == 13:
		tag_height = 3.6
	elif mob_type == 14:
		tag_height = 5.6
	elif mob_type == 16:
		tag_height = 5.5
	elif mob_type == 19:
		tag_height = 3.8
	elif mob_type == 20:
		tag_height = 3.5
	elif mob_type == 21:
		tag_height = 3.6
	elif mob_type == 22:
		tag_height = 6.8
	elif mob_type == 23:
		tag_height = 2.7
	elif mob_type == 24:
		tag_height = 5.2
	name_tag.position = Vector3(0, tag_height, 0)

	_apply_lunar_glow()

func _apply_creature_model() -> void:
	# Criatura 3D detalhada (pelagem, asas, armas) substitui as formas simples
	if not LunariaModel.has_model(LunariaModel.mob_uid(mob_type)):
		return
	for c in body_pivot.get_children():
		c.queue_free()
	body_pivot.scale = Vector3.ONE
	creature_model = LunariaModel.create_mob(mob_type) as LunariaModel
	body_pivot.add_child(creature_model)
	var primary := creature_model.get_primary_material()
	if primary:
		main_mat = primary
	var shield := creature_model.get_shield_material()
	if shield:
		shield_mat = shield

func update_network_data(new_pos: Vector3, new_rot_y: float, state: int, hp: int, p_max_hp: int) -> void:
	target_position = new_pos
	target_rotation_y = new_rot_y
	if creature_model and state != current_state:
		if state == 2:
			creature_model.play_creature("attack")
		elif state == 3:
			creature_model.play_creature("block")
	current_state = state
	current_hp = hp
	max_hp = p_max_hp

	is_alive = (hp > 0 and state != 5)
	visible = is_alive

	if collision_shape:
		collision_shape.disabled = (not is_alive or current_hp <= 0 or current_state == 5)

	_update_tags()
	_update_state_visuals()

func set_moon_phase(phase: int) -> void:
	current_moon_phase = phase
	_apply_lunar_glow()

func _apply_lunar_glow() -> void:
	if main_mat == null:
		return

	if mob_type == 1:
		# Lobo da Bruma: Brilho sob Lua Cheia (4) ou Lua de Sangue (8)
		if current_moon_phase == 4:
			main_mat.emission_enabled = true
			main_mat.emission = Color(0.4, 0.65, 1.0) * 1.5
		elif current_moon_phase == 8:
			main_mat.emission_enabled = true
			main_mat.emission = Color(1.0, 0.1, 0.15) * 2.0
		else:
			main_mat.emission_enabled = false
	elif mob_type == 6:
		# Lobo Alfa: Luar prateado brilhante contínuo, potencializado sob o luar
		main_mat.emission_enabled = true
		var mult: float = 2.4 if (current_moon_phase == 4 or current_moon_phase == 8) else 1.5
		main_mat.emission = Color(0.25, 0.55, 0.95) * mult
	elif mob_type == 7:
		# Licantropo Alfa: Aura carmesim colossal da Lua de Sangue
		main_mat.emission_enabled = true
		var mult: float = 2.8 if current_moon_phase == 8 else 1.4
		main_mat.emission = Color(0.85, 0.06, 0.12) * mult
	elif mob_type == 16:
		# Arachna: Pulsação de teias violetas
		main_mat.emission_enabled = true
		var mult: float = 2.5 if current_moon_phase == 8 else 1.2
		main_mat.emission = Color(0.7, 0.1, 0.8) * mult
	elif mob_type == 22:
		# Ymir: Resplendor de geada ártica
		main_mat.emission_enabled = true
		main_mat.emission = Color(0.3, 0.75, 1.0) * 2.2
	elif mob_type == 24:
		# Lorde Vesperian: Aura sangrenta furiosa sob Lua de Sangue ou Eclipse
		main_mat.emission_enabled = true
		var mult: float = 3.5 if (current_moon_phase == 8 or current_moon_phase == 9) else 1.6
		main_mat.emission = Color(0.9, 0.02, 0.1) * mult

func _update_state_visuals() -> void:
	# Saqueador Deserdado: Escudo brilha em azul quando bloqueando (State == 3)
	if mob_type == 2 and shield_mat != null:
		if current_state == 3:
			shield_mat.emission_enabled = true
			shield_mat.emission = Color(0.2, 0.75, 1.0) * 3.0
		else:
			shield_mat.emission_enabled = false

	# Executor de Ferro, Licantropo, Bosses: se vulnerável (State == 4), inclina para frente
	if (mob_type == 5 or mob_type == 7 or mob_type == 14 or mob_type == 16 or mob_type == 22 or mob_type == 24) and body_pivot != null:
		if current_state == 4:
			body_pivot.rotation.x = deg_to_rad(20.0)
		elif current_state == 2:
			body_pivot.rotation.x = deg_to_rad(-15.0)
		else:
			body_pivot.rotation.x = 0.0

func _update_tags() -> void:
	if name_tag == null:
		return

	var m_name: String = MOB_NAMES.get(mob_type, "Monstro")
	var status_suffix := ""
	var tag_color := Color(1.0, 0.9, 0.9, 1.0)

	if current_state == 3: # Bloqueando
		status_suffix = " [ESCUDO]"
		tag_color = Color(0.35, 0.8, 1.0, 1.0) # Azul-ciano
	elif current_state == 4: # Vulnerável / Fuga
		status_suffix = " [VULNERÁVEL]"
		tag_color = Color(1.0, 0.85, 0.2, 1.0) # Ouro / Amarelo
	elif current_state == 5 or current_hp == 0:
		status_suffix = " [MORTO]"
		tag_color = Color(0.5, 0.5, 0.5, 0.8)

	if mob_type == 7 or mob_type == 14 or mob_type == 16 or mob_type == 22 or mob_type == 24:
		name_tag.outline_size = 9
		name_tag.font_size = 28
		if current_hp > 0 and current_state != 5:
			if mob_type == 22:
				tag_color = Color(0.4, 0.85, 1.0, 1.0)
			elif mob_type == 16:
				tag_color = Color(0.95, 0.35, 1.0, 1.0)
			else:
				tag_color = Color(1.0, 0.18, 0.18, 1.0) # Destaque vermelho raid boss

	name_tag.text = "%s%s\n[HP: %d/%d]" % [m_name, status_suffix, current_hp, max_hp]
	name_tag.modulate = tag_color

func show_damage(damage: int, is_crit: bool, hp: int, p_max_hp: int) -> void:
	current_hp = hp
	max_hp = p_max_hp
	_update_tags()

	# Balanço físico do corpo ao tomar golpe
	if body_pivot != null:
		var hit_tw := create_tween()
		var tilt_dir := 1.0 if randf() > 0.5 else -1.0
		hit_tw.tween_property(body_pivot, "rotation:z", deg_to_rad(18.0 * tilt_dir), 0.04)
		hit_tw.tween_property(body_pivot, "rotation:z", deg_to_rad(-10.0 * tilt_dir), 0.06)
		hit_tw.tween_property(body_pivot, "rotation:z", 0.0, 0.08)

	_spawn_floating_damage(damage, is_crit)

func _spawn_floating_damage(damage: int, is_crit: bool) -> void:
	var dmg_label := Label3D.new()
	add_child(dmg_label)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.outline_size = 8
	dmg_label.outline_modulate = Color(0, 0, 0, 1)
	dmg_label.no_depth_test = true

	var spawn_y := 1.8
	if mob_type == 1 or mob_type == 6 or mob_type == 15 or mob_type == 17:
		spawn_y = 1.2
	elif mob_type == 18:
		spawn_y = 1.5
	elif mob_type == 5 or mob_type == 20 or mob_type == 21:
		spawn_y = 2.8
	elif mob_type == 7 or mob_type == 19 or mob_type == 23:
		spawn_y = 3.2
	elif mob_type == 14 or mob_type == 16 or mob_type == 24:
		spawn_y = 4.5
	elif mob_type == 22:
		spawn_y = 5.8

	dmg_label.position = Vector3(randf_range(-0.35, 0.35), spawn_y + randf_range(0.0, 0.3), randf_range(-0.35, 0.35))

	if is_crit:
		dmg_label.text = "-%d!" % damage
		dmg_label.font_size = 46
		dmg_label.modulate = Color(1.0, 0.92, 0.1, 1.0) # Amarelo Grande Crítico
	else:
		dmg_label.text = "-%d" % damage
		dmg_label.font_size = 32
		dmg_label.modulate = Color(1.0, 0.45, 0.2, 1.0) # Laranja vibrante

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dmg_label, "position:y", dmg_label.position.y + 1.3, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dmg_label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dmg_label.queue_free)

func _process(delta: float) -> void:
	if not is_alive:
		return
	var prev_pos := position
	position = position.lerp(target_position, INTERPOLATION_SPEED * delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, INTERPOLATION_SPEED * delta)
	if creature_model and delta > 0.0:
		var step := position - prev_pos
		creature_model.set_move_speed(Vector2(step.x, step.z).length() / delta)
