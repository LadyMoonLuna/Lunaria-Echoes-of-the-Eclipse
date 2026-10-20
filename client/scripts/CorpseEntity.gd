class_name CorpseEntity
extends Node3D

var corpse_id: int = 0
var mob_id: int = 0
var mob_type: int = 1
var is_looted: bool = false
var remaining_seconds: int = 120
var is_player_in_range: bool = false

var body_pivot: Node3D = null
var main_mesh: MeshInstance3D = null
var main_mat: StandardMaterial3D = null
var label_3d: Label3D = null

const MOB_NAMES := {
	1: "Lobo da Bruma",
	2: "Saqueador Deserdado",
	3: "Besteiro da Vigília",
	4: "Acólito do Eclipse",
	5: "Executor de Ferro",
	6: "Lobo Alfa",
	7: "Licantropo Alfa",
	10: "Cultista Sombrio",
	11: "Gárgula de Pedra",
	12: "Inquisidor Vex",
	13: "Comandante Vaelen",
	14: "Malakor, o Arauto do Eclipse"
}

func _ready() -> void:
	_build_visuals()
	_update_label()

func setup(p_corpse_id: int, p_mob_id: int, p_mob_type: int, p_pos: Vector3, p_rot_y: float, p_is_looted: bool, p_rem_sec: int) -> void:
	corpse_id = p_corpse_id
	mob_id = p_mob_id
	mob_type = p_mob_type
	position = Vector3(p_pos.x, 0.1, p_pos.z) # Deitado no chão em Y = 0.1
	rotation.y = p_rot_y
	is_looted = p_is_looted
	remaining_seconds = p_rem_sec

	if is_node_ready():
		_build_visuals()
		_update_label()

func update_data(p_pos: Vector3, p_rot_y: float, p_is_looted: bool, p_rem_sec: int) -> void:
	position = Vector3(p_pos.x, 0.1, p_pos.z)
	rotation.y = p_rot_y
	is_looted = p_is_looted
	remaining_seconds = p_rem_sec
	_update_label()

func update_player_distance(dist: float) -> void:
	var in_range := (dist <= 2.5)
	if in_range != is_player_in_range:
		is_player_in_range = in_range
		_update_label()

func _build_visuals() -> void:
	if body_pivot != null:
		body_pivot.queue_free()

	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)

	main_mesh = MeshInstance3D.new()
	main_mesh.name = "CorpseMesh"
	main_mat = StandardMaterial3D.new()
	main_mesh.material_override = main_mat
	body_pivot.add_child(main_mesh)

	# Deita a malha horizontalmente no solo (Y = 0.1 com rotação horizontal)
	body_pivot.rotation.z = deg_to_rad(85.0) # Tombado lateralmente
	body_pivot.position = Vector3(0, 0.1, 0)

	var m_name: String = MOB_NAMES.get(mob_type, "Criatura")

	match mob_type:
		1, 6: # Lobo da Bruma / Lobo Alfa (Corpo lupino caído)
			var scale_mult := 1.0 if mob_type == 1 else 1.35
			body_pivot.scale = Vector3(scale_mult, scale_mult, scale_mult)
			var b_box := BoxMesh.new()
			b_box.size = Vector3(0.55, 0.45, 1.25)
			main_mesh.mesh = b_box
			main_mesh.position = Vector3(0, 0.2, 0)

			# Tom escurecido e frio de cadáver
			if mob_type == 1:
				main_mat.albedo_color = Color(0.22, 0.24, 0.28, 1.0) # Cinza gélido escuro
			else:
				main_mat.albedo_color = Color(0.18, 0.20, 0.25, 1.0) # Lobo alfa escurecido
			main_mat.roughness = 0.9

			# Focinho tombado
			var snout := MeshInstance3D.new()
			var sn_box := BoxMesh.new()
			sn_box.size = Vector3(0.25, 0.2, 0.4)
			snout.mesh = sn_box
			snout.position = Vector3(0, 0.2, -0.7)
			snout.material_override = main_mat
			body_pivot.add_child(snout)

		5: # Executor de Ferro (Armadura pesada escura caída)
			body_pivot.scale = Vector3(1.3, 1.3, 1.3)
			var cap := CapsuleMesh.new()
			cap.radius = 0.5
			cap.height = 1.9
			main_mesh.mesh = cap
			main_mesh.position = Vector3(0, 0.25, 0)
			main_mat.albedo_color = Color(0.1, 0.1, 0.12, 1.0) # Ferro escuro/apagado
			main_mat.metallic = 0.8
			main_mat.roughness = 0.6

		7, 14: # Bosses Colossais: Licantropo Alfa / Malakor (Corpo colossal)
			var b_scale := 1.8 if mob_type == 7 else 2.1
			body_pivot.scale = Vector3(b_scale, b_scale, b_scale)
			var cap := CapsuleMesh.new()
			cap.radius = 0.65
			cap.height = 2.4
			main_mesh.mesh = cap
			main_mesh.position = Vector3(0, 0.35, 0)
			main_mat.albedo_color = Color(0.14, 0.05, 0.16, 1.0) # Púrpura/carmesim escurecido
			main_mat.roughness = 0.8

		11: # Gárgula de Pedra (Rocha rachada tombada)
			body_pivot.scale = Vector3(1.1, 1.1, 1.1)
			var cap := CapsuleMesh.new()
			cap.radius = 0.45
			cap.height = 1.8
			main_mesh.mesh = cap
			main_mesh.position = Vector3(0, 0.2, 0)
			main_mat.albedo_color = Color(0.25, 0.26, 0.28, 1.0) # Pedra cinza escura
			main_mat.roughness = 0.95

		_: # Humanoides (Saqueador, Besteiro, Acólito, Cultista, Inquisidor, Vaelen)
			var cap := CapsuleMesh.new()
			cap.radius = 0.4
			cap.height = 1.7
			main_mesh.mesh = cap
			main_mesh.position = Vector3(0, 0.2, 0)
			main_mat.albedo_color = Color(0.2, 0.18, 0.18, 1.0) # Tecido/couro escurecido
			main_mat.roughness = 0.85

	# Label 3D Flutuante no topo do corpo
	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.name = "CorpseLabel"
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.outline_size = 8
		label_3d.outline_modulate = Color(0, 0, 0, 1.0)
		label_3d.font_size = 20
		add_child(label_3d)

	var label_height := 1.1
	if mob_type in [5, 7, 13, 14]:
		label_height = 1.6
	label_3d.position = Vector3(0, label_height, 0)

func _update_label() -> void:
	if label_3d == null:
		return

	var m_name: String = MOB_NAMES.get(mob_type, "Criatura")

	if is_looted:
		label_3d.text = "Cadáver de %s\n[Completamente Desmantelado]" % m_name
		label_3d.modulate = Color(0.5, 0.5, 0.5, 0.8)
	elif is_player_in_range:
		# Destacado em verde/dourado brilhante quando próximo (<= 2.5m)
		label_3d.text = "Cadáver de %s\n★ [Aperte E para Autópsia] ★" % m_name
		label_3d.modulate = Color("#ffd700") # Dourado reluzente
	else:
		label_3d.text = "Cadáver de %s\n[Aperte E para Autópsia] (%ds)" % [m_name, remaining_seconds]
		label_3d.modulate = Color("#cfd8dc") # Cinza claro padrão
