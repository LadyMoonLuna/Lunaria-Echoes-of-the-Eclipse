class_name MobEntity
extends Node3D

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
	14: "★ MALAKOR, O ARAUTO DO ECLIPSE [RAID BOSS] ★"
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
	if mob_type == 5 or mob_type == 7 or mob_type == 13 or mob_type == 14:
		cap.radius = 1.15
		cap.height = 2.6
		collision_shape.position = Vector3(0, 1.3, 0)
	elif mob_type == 12 or mob_type == 11:
		cap.radius = 0.8
		cap.height = 2.0
		collision_shape.position = Vector3(0, 1.0, 0)
	elif mob_type == 1 or mob_type == 6:
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

		_:
			var c_mesh := CapsuleMesh.new()
			c_mesh.radius = 0.45
			c_mesh.height = 1.8
			main_mesh.mesh = c_mesh
			main_mesh.position = Vector3(0, 0.9, 0)
			main_mat.albedo_color = Color(0.4, 0.4, 0.4)

	# Label 3D Billboard para Nome e HP
	if name_tag == null:
		name_tag = Label3D.new()
		add_child(name_tag)
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.outline_size = 7
		name_tag.outline_modulate = Color(0, 0, 0, 1)
		name_tag.font_size = 22

	var tag_height := 2.3
	if mob_type == 1:
		tag_height = 1.4
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
	name_tag.position = Vector3(0, tag_height, 0)

	_apply_lunar_glow()

func update_network_data(new_pos: Vector3, new_rot_y: float, state: int, hp: int, p_max_hp: int) -> void:
	target_position = new_pos
	target_rotation_y = new_rot_y
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

func _update_state_visuals() -> void:
	# Saqueador Deserdado: Escudo brilha em azul quando bloqueando (State == 3)
	if mob_type == 2 and shield_mat != null:
		if current_state == 3:
			shield_mat.emission_enabled = true
			shield_mat.emission = Color(0.2, 0.75, 1.0) * 3.0
		else:
			shield_mat.emission_enabled = false

	# Executor de Ferro e Licantropo: se vulnerável (State == 4), inclina para frente
	if (mob_type == 5 or mob_type == 7) and body_pivot != null:
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

	if mob_type == 7:
		name_tag.outline_size = 9
		name_tag.font_size = 28
		if current_hp > 0 and current_state != 5:
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
	if mob_type == 1 or mob_type == 6:
		spawn_y = 1.2
	elif mob_type == 5:
		spawn_y = 2.8
	elif mob_type == 7:
		spawn_y = 3.8

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
	position = position.lerp(target_position, INTERPOLATION_SPEED * delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, INTERPOLATION_SPEED * delta)
