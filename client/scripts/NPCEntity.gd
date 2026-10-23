# NPCEntity.gd — Entidade visual autoritativa de NPCs vivos em Lunaria Online
class_name NPCEntity
extends Node3D

var npc_id: int = 0
var npc_name: String = ""
var npc_script_path: String = ""
var target_position: Vector3 = Vector3.ZERO
var target_rotation_y: float = 0.0
var current_state: int = 0

static func get_default_npc_name(id: int) -> String:
	match id:
		100, 1:
			return "Garrick\n<Mestre Ferreiro> [E]"
		101, 102:
			return "Boneco de Treino"
		103:
			return "Lyra\n<Mestra Alquimista> [E]"
		104:
			return "Varis\n<Mercador do Beco Sombrio> [E]"
		105:
			return "Capitão Randel\n<Comandante da Guarda> [E]"
		106:
			return "Guarda Valen\n<Patrulheiro da Vila> [E]"
		107:
			return "Irmã Seraphina\n<Mestra Acólita> [E]"
		108:
			return "Mestre Aurelius\n<Arquimago> [E]"
		109:
			return "Kaelen\n<Mestre Batedor> [E]"
		110:
			return "Alquimista Esquecido\n<Espírito dos Esgotos> [E]"
		111:
			return "Nyx Sombraveloz\n<Mestra das Lâminas Silentes> [E]"
		112:
			return "Mestre Tao Ferroventre\n<Grão-Mestre do Punho Celeste> [E]"
		113:
			return "Iolanthe Mármore-Lunar\n<Escultora de Almas> [E]"
		114:
			return "Madame Fiorella\n<Tecelã Carmesim> [E]"
		115:
			return "Chef Bartolomeu\n<Mestre do Banquete> [E]"
		116:
			return "Thorne\n<Eremita das Feras> [E]"
		117:
			return "Bran\n<Aprendiz da Forja> [E]"
		118:
			return "Pip\n<Aprendiz de Alquimia> [E]"
		119:
			return "Tilda\n<Ajudante de Cozinha> [E]"
		120:
			return "Mortimer, o Coveiro\n<Guardião do Cemitério> [E]"
		123:
			return "Mestra Joalheira Selene\n<Joias e Equipamentos Cravejados> [E]"
		_:
			if id >= 400 and id < 410:
				return "Paladino da Luz\n<Caçador da Igreja>"
			if id >= 420 and id < 430:
				return "Clériga da Luz\n<Caçadora da Igreja>"
			return "NPC #%d" % id

var current_hp: int = 1000
var max_hp: int = 1000
var is_dummy: bool = false
var is_varis: bool = false
var time_accum: float = 0.0
var friendship_points: int = 0

static func get_hearts_string(points: int) -> String:
	if points >= 100:
		return "❤️❤️❤️❤️❤️"
	elif points >= 80:
		return "❤️❤️❤️❤️♡"
	elif points >= 60:
		return "❤️❤️❤️♡♡"
	elif points >= 40:
		return "❤️❤️♡♡♡"
	elif points >= 20:
		return "❤️♡♡♡♡"
	else:
		return "♡♡♡♡♡"

static func get_hearts_level_text(points: int) -> String:
	if points >= 100:
		return "❤️❤️❤️❤️❤️ (Nível Máximo: Alma Irmã — 20% Desconto + Receitas Secretas)"
	elif points >= 80:
		return "❤️❤️❤️❤️♡ (Nível 5: Leal — 15% Desconto)"
	elif points >= 60:
		return "❤️❤️❤️♡♡ (Nível 4: Confidente — 10% Desconto + Segredos)"
	elif points >= 40:
		return "❤️❤️♡♡♡ (Nível 3: Amigo — 5% Desconto)"
	elif points >= 20:
		return "❤️♡♡♡♡ (Nível 2: Conhecido)"
	else:
		return "♡♡♡♡♡ (Nível 1: Desconhecido)"

func set_friendship(points: int) -> void:
	friendship_points = clampi(points, 0, 100)
	_update_tags()

const INTERPOLATION_SPEED: float = 15.0
const LunariaModel = preload("res://scripts/models/LunariaModel.gd")

var npc_model: LunariaModel = null
var _npc_capsule: Mesh = null

@onready var body_mesh: MeshInstance3D = get_node_or_null("BodyMesh")
@onready var apron_mesh: MeshInstance3D = get_node_or_null("BodyMesh/ApronMesh")
@onready var visor_mesh: MeshInstance3D = get_node_or_null("BodyMesh/VisorIndicator")
@onready var name_tag: Label3D = get_node_or_null("NameTag")
@onready var dialogue_tag: Label3D = get_node_or_null("DialogueTag")
@onready var dialogue_timer: Timer = get_node_or_null("DialogueTimer")

var anim_body: AnimatableBody3D = null
var collision_shape: CollisionShape3D = null

# Elementos do Balão de Fala 3D
var balloon_root: Node3D = null
var balloon_bg: MeshInstance3D = null
var balloon_border: MeshInstance3D = null
var balloon_tween: Tween = null

func _ready() -> void:
	target_position = global_position
	target_rotation_y = rotation.y
	_ensure_node_refs()
	_setup_collision()
	_setup_dialogue_balloon()
	_setup_npc_visuals(npc_script_path)
	_update_tags()

func _ensure_node_refs() -> void:
	if body_mesh == null:
		body_mesh = get_node_or_null("BodyMesh")
	if body_mesh == null:
		body_mesh = MeshInstance3D.new()
		body_mesh.name = "BodyMesh"
		var cap := CapsuleMesh.new()
		cap.radius = 0.45
		cap.height = 1.85
		body_mesh.mesh = cap
		body_mesh.position = Vector3(0, 0.92, 0)
		add_child(body_mesh)

	if body_mesh != null:
		if apron_mesh == null:
			apron_mesh = body_mesh.get_node_or_null("ApronMesh")
		if visor_mesh == null:
			visor_mesh = body_mesh.get_node_or_null("VisorIndicator")
	if name_tag == null:
		name_tag = get_node_or_null("NameTag")
	if name_tag == null:
		name_tag = Label3D.new()
		name_tag.name = "NameTag"
		name_tag.position = Vector3(0, 2.2, 0)
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.font_size = 26
		name_tag.outline_size = 6
		name_tag.outline_modulate = Color(0, 0, 0, 1)
		add_child(name_tag)

	if dialogue_tag == null:
		dialogue_tag = get_node_or_null("DialogueTag")
	if dialogue_tag == null:
		dialogue_tag = Label3D.new()
		dialogue_tag.name = "DialogueTag"
		dialogue_tag.position = Vector3(0, 3.05, 0)
		dialogue_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dialogue_tag.no_depth_test = true
		dialogue_tag.font_size = 22
		dialogue_tag.outline_size = 8
		dialogue_tag.outline_modulate = Color(0, 0, 0, 1)
		dialogue_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialogue_tag.width = 380.0
		dialogue_tag.visible = false
		add_child(dialogue_tag)

	if dialogue_timer == null:
		dialogue_timer = get_node_or_null("DialogueTimer")
	if dialogue_timer == null:
		dialogue_timer = Timer.new()
		dialogue_timer.name = "DialogueTimer"
		dialogue_timer.one_shot = true
		dialogue_timer.timeout.connect(_on_dialogue_timer_timeout)
		add_child(dialogue_timer)

func _setup_collision() -> void:
	if anim_body != null:
		return
	anim_body = AnimatableBody3D.new()
	anim_body.name = "NPCBody"
	anim_body.collision_layer = 1
	anim_body.collision_mask = 0
	add_child(anim_body)

	collision_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 1.85
	collision_shape.shape = cap
	collision_shape.position = Vector3(0, 0.925, 0)
	anim_body.add_child(collision_shape)

func _setup_dialogue_balloon() -> void:
	_ensure_node_refs()
	if not dialogue_tag:
		return

	# Configurações do Label3D de diálogo
	dialogue_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dialogue_tag.no_depth_test = true
	dialogue_tag.outline_size = 8
	dialogue_tag.outline_modulate = Color(0, 0, 0, 1)
	dialogue_tag.font_size = 22
	dialogue_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_tag.width = 380.0
	dialogue_tag.position = Vector3(0, 3.05, 0)
	dialogue_tag.visible = false

	# Container principal do balão 3D
	if not has_node("DialogueBalloonRoot"):
		balloon_root = Node3D.new()
		balloon_root.name = "DialogueBalloonRoot"
		balloon_root.position = Vector3(0, 3.05, -0.01)
		balloon_root.visible = false
		add_child(balloon_root)

		# Painel de fundo do balão translúcido escuro
		balloon_bg = MeshInstance3D.new()
		balloon_bg.name = "BalloonBackground"
		var q_mesh := QuadMesh.new()
		q_mesh.size = Vector2(4.2, 1.15)
		balloon_bg.mesh = q_mesh

		var bg_mat := StandardMaterial3D.new()
		bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bg_mat.albedo_color = Color(0.04, 0.05, 0.09, 0.88)
		bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bg_mat.no_depth_test = true
		balloon_bg.material_override = bg_mat
		balloon_root.add_child(balloon_bg)

		# Moldura / Borda estilizada do balão
		balloon_border = MeshInstance3D.new()
		balloon_border.name = "BalloonBorder"
		var b_mesh := QuadMesh.new()
		b_mesh.size = Vector2(4.28, 1.22)
		balloon_border.mesh = b_mesh
		balloon_border.position = Vector3(0, 0, -0.005)

		var bd_mat := StandardMaterial3D.new()
		bd_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bd_mat.albedo_color = Color(0.9, 0.75, 0.2, 0.9)
		bd_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bd_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bd_mat.no_depth_test = true
		balloon_border.material_override = bd_mat
		balloon_root.add_child(balloon_border)

func _clear_props() -> void:
	for p_name in ["AlchemyFlaskProp", "ShadowHoodProp", "GuardHelmetProp", "GuardSwordProp", "GuardCapeProp", "GuardSpearProp", "GuardShieldProp", "HammerProp", "DummyArmsProp"]:
		var p = get_node_or_null(p_name)
		if p:
			p.queue_free()

func _setup_npc_visuals(script_path: String = "") -> void:
	_ensure_node_refs()
	if not body_mesh:
		return

	_clear_props()

	var path_lower := script_path.to_lower()
	var is_lyra := (npc_id == 103 or "lyra" in path_lower)
	is_varis = (npc_id == 104 or "shadow" in path_lower or "varis" in path_lower)
	var is_randel := (npc_id == 105 or "randel" in path_lower)
	var is_valen := (npc_id == 106 or "valen" in path_lower)
	var is_seraphina := (npc_id == 107 or "seraphina" in path_lower)
	var is_aurelius := (npc_id == 108 or "aurelius" in path_lower)
	var is_kaelen := (npc_id == 109 or "kaelen" in path_lower)
	var is_ghost_alchemist := (npc_id == 110 or "ghost" in path_lower or "esquecido" in path_lower)
	var is_guard := (is_randel or is_valen or "guard" in path_lower)
	var is_dummy_check := (npc_id == 101 or npc_id == 102 or "dummy" in path_lower)

	if is_dummy_check:
		# 101 e 102: Boneco de Treino | Cor: Madeira/Palha no Quartel
		is_dummy = true
		if apron_mesh:
			apron_mesh.visible = false
		if visor_mesh:
			visor_mesh.visible = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.46, 0.28, 1.0) # Madeira/Palha
		mat.roughness = 0.9
		body_mesh.material_override = mat

		var d_arms := MeshInstance3D.new()
		d_arms.name = "DummyArmsProp"
		var arms_mesh := BoxMesh.new()
		arms_mesh.size = Vector3(1.2, 0.12, 0.12)
		d_arms.mesh = arms_mesh
		d_arms.position = Vector3(0, 1.1, 0)
		d_arms.material_override = mat
		add_child(d_arms)

	elif is_lyra:
		# Lyra (Transmutador - ID 102): Cápsula com tom roxo-claro e um frasco alquímico luminoso flutuante
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.52, 0.88, 1.0) # Tom roxo-claro místico
		mat.roughness = 0.45
		mat.metallic = 0.1
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.38, 0.20, 0.52, 1.0) # Violeta escuro
			amat.roughness = 0.65
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(0.88, 0.72, 1.0, 1.0)
			vmat.emission_enabled = true
			vmat.emission = Color(0.85, 0.65, 1.0, 1.0)
			vmat.emission_energy_multiplier = 2.0
			visor_mesh.material_override = vmat

		# Frasco alquímico luminoso flutuante acima de Lyra
		var f_root := Node3D.new()
		f_root.name = "AlchemyFlaskProp"
		f_root.position = Vector3(0, 2.35, 0)
		add_child(f_root)

		# Bojo esférico translúcido e luminoso
		var bulb := MeshInstance3D.new()
		var b_mesh := SphereMesh.new()
		b_mesh.radius = 0.16
		b_mesh.height = 0.32
		bulb.mesh = b_mesh
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.2, 0.95, 0.75, 0.9)
		b_mat.roughness = 0.15
		b_mat.emission_enabled = true
		b_mat.emission = Color(0.25, 0.95, 0.75, 1.0)
		b_mat.emission_energy_multiplier = 2.5
		bulb.material_override = b_mat
		f_root.add_child(bulb)

		# Gargalo do frasco
		var neck := MeshInstance3D.new()
		var n_mesh := CylinderMesh.new()
		n_mesh.top_radius = 0.05
		n_mesh.bottom_radius = 0.06
		n_mesh.height = 0.12
		neck.mesh = n_mesh
		neck.position = Vector3(0, 0.16, 0)
		neck.material_override = b_mat
		f_root.add_child(neck)

		# Rolha de cortiça
		var cork := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.06
		c_mesh.bottom_radius = 0.052
		c_mesh.height = 0.05
		cork.mesh = c_mesh
		cork.position = Vector3(0, 0.23, 0)
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color(0.55, 0.38, 0.22, 1.0)
		cork.material_override = c_mat
		f_root.add_child(cork)

		# Luz pontual mágica do frasco
		var light := OmniLight3D.new()
		light.light_color = Color(0.2, 1.0, 0.75)
		light.light_energy = 1.8
		light.omni_range = 3.5
		f_root.add_child(light)

	elif is_varis:
		# Varis (Mercador Sombrio - ID 103): Cápsula encapuzada preta com detalhes em vermelho escuro
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.06, 0.05, 0.08, 1.0) # Preto profundo / sombra
		mat.roughness = 0.35
		mat.metallic = 0.2
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.55, 0.06, 0.09, 1.0) # Vermelho escuro carmesim
			amat.roughness = 0.6
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(0.95, 0.08, 0.12, 1.0)
			vmat.emission_enabled = true
			vmat.emission = Color(0.95, 0.08, 0.12, 1.0)
			vmat.emission_energy_multiplier = 3.5
			visor_mesh.material_override = vmat

		# Capuz sombrio
		var h_mesh := MeshInstance3D.new()
		h_mesh.name = "ShadowHoodProp"
		var hood := CylinderMesh.new()
		hood.top_radius = 0.49
		hood.bottom_radius = 0.54
		hood.height = 0.55
		h_mesh.mesh = hood
		h_mesh.position = Vector3(0, 1.5, -0.04)
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = Color(0.05, 0.04, 0.07, 1.0)
		h_mat.roughness = 0.5
		h_mesh.material_override = h_mat
		add_child(h_mesh)

		# Borda de detalhe carmesim no capuz
		var rim := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.52, 0.05, 0.35)
		rim.mesh = r_box
		rim.position = Vector3(0, -0.22, -0.22)
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.65, 0.05, 0.1, 1.0)
		rim.material_override = r_mat
		h_mesh.add_child(rim)

	elif is_randel:
		# 105: Capitão Randel <Comandante da Guarda> | Armadura Prateada Real com capa azul e Espada Longa
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.88, 0.9, 0.96, 1.0) # Armadura Prateada Real
		mat.metallic = 0.95
		mat.roughness = 0.18
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.12, 0.3, 0.65, 1.0) # Tabardo Azul Real
			amat.metallic = 0.2
			amat.roughness = 0.4
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(0.1, 0.15, 0.22, 1.0) # Visor escuro do elmo
			vmat.emission_enabled = false
			visor_mesh.material_override = vmat

		# Elmo prateado com crista azul real
		var h_root := Node3D.new()
		h_root.name = "GuardHelmetProp"
		h_root.position = Vector3(0, 1.55, 0)
		add_child(h_root)

		var dome := MeshInstance3D.new()
		var d_mesh := CylinderMesh.new()
		d_mesh.top_radius = 0.44
		d_mesh.bottom_radius = 0.48
		d_mesh.height = 0.45
		dome.mesh = d_mesh
		var d_mat := StandardMaterial3D.new()
		d_mat.albedo_color = Color(0.88, 0.9, 0.95, 1.0)
		d_mat.metallic = 0.95
		d_mat.roughness = 0.2
		dome.material_override = d_mat
		h_root.add_child(dome)

		var crest := MeshInstance3D.new()
		var cr_mesh := BoxMesh.new()
		cr_mesh.size = Vector3(0.06, 0.28, 0.52)
		crest.mesh = cr_mesh
		crest.position = Vector3(0, 0.3, 0)
		var cr_mat := StandardMaterial3D.new()
		cr_mat.albedo_color = Color(0.12, 0.4, 0.9, 1.0) # Crista Azul Real
		crest.material_override = cr_mat
		h_root.add_child(crest)

		# Espada visível embainhada na cintura
		var sw_root := Node3D.new()
		sw_root.name = "GuardSwordProp"
		sw_root.position = Vector3(-0.46, 0.85, -0.05)
		sw_root.rotation = Vector3(0, 0, deg_to_rad(-25))
		add_child(sw_root)

		var blade := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.06, 0.95, 0.14)
		blade.mesh = b_box
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.78, 0.82, 0.88, 1.0)
		b_mat.metallic = 0.9
		b_mat.roughness = 0.25
		blade.material_override = b_mat
		sw_root.add_child(blade)

		var guard_bar := MeshInstance3D.new()
		var g_box := BoxMesh.new()
		g_box.size = Vector3(0.18, 0.04, 0.24)
		guard_bar.mesh = g_box
		guard_bar.position = Vector3(0, 0.47, 0)
		var g_mat := StandardMaterial3D.new()
		g_mat.albedo_color = Color(0.9, 0.75, 0.15, 1.0)
		g_mat.metallic = 0.8
		g_mat.roughness = 0.3
		guard_bar.material_override = g_mat
		sw_root.add_child(guard_bar)

		var hilt := MeshInstance3D.new()
		var h_mesh := CylinderMesh.new()
		h_mesh.top_radius = 0.035
		h_mesh.bottom_radius = 0.035
		h_mesh.height = 0.22
		hilt.mesh = h_mesh
		hilt.position = Vector3(0, 0.58, 0)
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = Color(0.25, 0.15, 0.08, 1.0)
		hilt.material_override = h_mat
		sw_root.add_child(hilt)

		var pommel := MeshInstance3D.new()
		var p_mesh := SphereMesh.new()
		p_mesh.radius = 0.05
		p_mesh.height = 0.1
		pommel.mesh = p_mesh
		pommel.position = Vector3(0, 0.7, 0)
		pommel.material_override = g_mat
		sw_root.add_child(pommel)

		# Capa Azul Real nas costas do Capitão Randel
		var cape_root := Node3D.new()
		cape_root.name = "GuardCapeProp"
		cape_root.position = Vector3(0, 1.05, 0.26)
		var cape_mesh := MeshInstance3D.new()
		var cp_box := BoxMesh.new()
		cp_box.size = Vector3(0.68, 1.25, 0.05)
		cape_mesh.mesh = cp_box
		var cp_mat := StandardMaterial3D.new()
		cp_mat.albedo_color = Color(0.1, 0.3, 0.78, 1.0)
		cp_mat.roughness = 0.75
		cape_mesh.material_override = cp_mat
		cape_root.add_child(cape_mesh)
		add_child(cape_root)

	elif is_valen or is_guard:
		# 106: Guarda Valen <Patrulheiro da Vila> | Armadura de Aço Prateado com Lança/Escudo
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.83, 0.88, 1.0) # Aço Prateado
		mat.metallic = 0.88
		mat.roughness = 0.28
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.18, 0.28, 0.5, 1.0) # Tabardo azul-aço
			amat.roughness = 0.5
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(0.1, 0.14, 0.2, 1.0)
			vmat.emission_enabled = false
			visor_mesh.material_override = vmat

		# Elmo de patrulheiro
		var h_root := Node3D.new()
		h_root.name = "GuardHelmetProp"
		h_root.position = Vector3(0, 1.55, 0)
		add_child(h_root)

		var dome := MeshInstance3D.new()
		var d_mesh := CylinderMesh.new()
		d_mesh.top_radius = 0.44
		d_mesh.bottom_radius = 0.48
		d_mesh.height = 0.45
		dome.mesh = d_mesh
		var d_mat := StandardMaterial3D.new()
		d_mat.albedo_color = Color(0.8, 0.83, 0.88, 1.0)
		d_mat.metallic = 0.9
		d_mat.roughness = 0.25
		dome.material_override = d_mat
		h_root.add_child(dome)

		# Lança de Patrulheiro na mão direita
		var spear_root := Node3D.new()
		spear_root.name = "GuardSpearProp"
		spear_root.position = Vector3(0.5, 0.9, -0.15)
		add_child(spear_root)

		var shaft := MeshInstance3D.new()
		var s_cyl := CylinderMesh.new()
		s_cyl.top_radius = 0.025
		s_cyl.bottom_radius = 0.025
		s_cyl.height = 2.4
		shaft.mesh = s_cyl
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.38, 0.24, 0.14, 1.0) # Madeira da lança
		shaft.material_override = s_mat
		spear_root.add_child(shaft)

		var tip := MeshInstance3D.new()
		var t_cyl := CylinderMesh.new()
		t_cyl.top_radius = 0.0
		t_cyl.bottom_radius = 0.06
		t_cyl.height = 0.35
		tip.mesh = t_cyl
		tip.position = Vector3(0, 1.3, 0)
		var t_mat := StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.85, 0.88, 0.92, 1.0)
		t_mat.metallic = 0.95
		t_mat.roughness = 0.2
		tip.material_override = t_mat
		spear_root.add_child(tip)

		# Escudo de Guarda no braço esquerdo
		var shield_root := Node3D.new()
		shield_root.name = "GuardShieldProp"
		shield_root.position = Vector3(-0.48, 0.9, -0.05)
		add_child(shield_root)

		var shield_mesh := MeshInstance3D.new()
		var sh_box := BoxMesh.new()
		sh_box.size = Vector3(0.12, 0.85, 0.55)
		shield_mesh.mesh = sh_box
		var sh_mat := StandardMaterial3D.new()
		sh_mat.albedo_color = Color(0.18, 0.32, 0.58, 1.0) # Escudo Azul-Aço
		sh_mat.metallic = 0.65
		sh_mat.roughness = 0.35
		shield_mesh.material_override = sh_mat
		shield_root.add_child(shield_mesh)

	elif is_seraphina:
		# 107: Irmã Seraphina <Mestra Acólita> | Túnica branca/dourada com aura luminosa e cajado sagrado
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.94, 0.90, 1.0) # Túnica branca/marfim
		mat.roughness = 0.55
		mat.metallic = 0.1
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.88, 0.74, 0.22, 1.0) # Estola sagrada dourada
			amat.metallic = 0.5
			amat.roughness = 0.35
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(1.0, 0.92, 0.4, 1.0)
			vmat.emission_enabled = true
			vmat.emission = Color(1.0, 0.92, 0.4)
			vmat.emission_energy_multiplier = 3.0
			visor_mesh.material_override = vmat

		# Aura luminosa sagrada
		var aura := OmniLight3D.new()
		aura.name = "SeraphinaAura"
		aura.light_color = Color(1.0, 0.95, 0.65)
		aura.light_energy = 2.4
		aura.omni_range = 5.0
		aura.position = Vector3(0, 1.5, 0)
		add_child(aura)

		# Cajado Sagrado na mão direita
		var staff_root := Node3D.new()
		staff_root.name = "HolyStaffProp"
		staff_root.position = Vector3(0.5, 0.9, -0.15)
		add_child(staff_root)

		var shaft := MeshInstance3D.new()
		var s_cyl := CylinderMesh.new()
		s_cyl.top_radius = 0.025
		s_cyl.bottom_radius = 0.025
		s_cyl.height = 2.2
		shaft.mesh = s_cyl
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.9, 0.85, 0.75, 1.0) # Madeira marfim
		shaft.material_override = s_mat
		staff_root.add_child(shaft)

		# Cruz Solar no topo do cajado
		var cross_v := MeshInstance3D.new()
		var cv_box := BoxMesh.new()
		cv_box.size = Vector3(0.08, 0.45, 0.08)
		cross_v.mesh = cv_box
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color(1.0, 0.88, 0.25, 1.0)
		c_mat.emission_enabled = true
		c_mat.emission = Color(1.0, 0.88, 0.25)
		c_mat.emission_energy_multiplier = 3.5
		cross_v.material_override = c_mat
		cross_v.position = Vector3(0, 1.25, 0)
		staff_root.add_child(cross_v)

		var cross_h := MeshInstance3D.new()
		var ch_box := BoxMesh.new()
		ch_box.size = Vector3(0.3, 0.08, 0.08)
		cross_h.mesh = ch_box
		cross_h.material_override = c_mat
		cross_h.position = Vector3(0, 1.35, 0)
		staff_root.add_child(cross_h)

	elif is_aurelius:
		# 108: Mestre Aurelius <Arquimago> | Manto azul-astral e dourado com orbe flutuante ciano
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.106, 0.149, 0.231, 1.0) # #1B263B Azul-escuro astral
		mat.roughness = 0.45
		mat.metallic = 0.2
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.85, 0.72, 0.18, 1.0) # Detalhes dourados celestiais
			amat.metallic = 0.6
			amat.roughness = 0.3
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(0.0, 0.95, 1.0, 1.0) # Ciano estelar
			vmat.emission_enabled = true
			vmat.emission = Color(0.0, 0.95, 1.0)
			vmat.emission_energy_multiplier = 3.5
			visor_mesh.material_override = vmat

		# Orbe Místico Flutuante Ciano
		var orb_root := Node3D.new()
		orb_root.name = "ArcaneOrbProp"
		orb_root.position = Vector3(0.48, 1.5, -0.2)
		add_child(orb_root)

		var orb := MeshInstance3D.new()
		var o_sphere := SphereMesh.new()
		o_sphere.radius = 0.18
		o_sphere.height = 0.36
		orb.mesh = o_sphere
		var o_mat := StandardMaterial3D.new()
		o_mat.albedo_color = Color(0.0, 0.95, 1.0, 1.0)
		o_mat.emission_enabled = true
		o_mat.emission = Color(0.0, 0.95, 1.0)
		o_mat.emission_energy_multiplier = 4.2
		orb.material_override = o_mat
		orb_root.add_child(orb)

		var orb_light := OmniLight3D.new()
		orb_light.light_color = Color(0.1, 0.92, 1.0)
		orb_light.light_energy = 2.6
		orb_light.omni_range = 4.5
		orb_root.add_child(orb_light)

	elif is_kaelen:
		# 109: Kaelen <Mestre Batedor> | Couro verde-floresta, capa de pele de lobo e Arco Longo
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.32, 0.15, 1.0) # Couro verde-floresta
		mat.roughness = 0.85
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.35, 0.22, 0.12, 1.0) # Couro reforçado de caça
			amat.roughness = 0.8
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(0.85, 0.7, 0.15, 1.0) # Visor âmbar
			vmat.emission_enabled = false
			visor_mesh.material_override = vmat

		# Capa de Pele de Lobo nos ombros
		var pelt := MeshInstance3D.new()
		pelt.name = "WolfPeltProp"
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.95, 0.3, 0.5)
		pelt.mesh = p_box
		pelt.position = Vector3(0, 1.62, 0.05)
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = Color(0.38, 0.36, 0.35, 1.0) # Pele cinza-lobo
		p_mat.roughness = 0.95
		pelt.material_override = p_mat
		add_child(pelt)

		# Arco Longo de Caça nas costas
		var bow_root := Node3D.new()
		bow_root.name = "LongbowProp"
		bow_root.position = Vector3(-0.35, 1.1, 0.25)
		bow_root.rotation = Vector3(deg_to_rad(15), 0, deg_to_rad(25))
		add_child(bow_root)

		var bow_shaft := MeshInstance3D.new()
		var b_cyl := CylinderMesh.new()
		b_cyl.top_radius = 0.02
		b_cyl.bottom_radius = 0.02
		b_cyl.height = 1.6
		bow_shaft.mesh = b_cyl
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.32, 0.18, 0.1, 1.0)
		bow_shaft.material_override = b_mat
		bow_root.add_child(bow_shaft)

	elif is_ghost_alchemist:
		# 110: Alquimista Esquecido <Espírito dos Esgotos> | Silhueta fantasmagórica verde-translúcida (transparency = TRANSPARENCY_ALPHA, emission verde)
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.2, 0.95, 0.45, 0.65)
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.9, 0.35, 1.0)
		mat.emission_energy_multiplier = 2.8
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = false

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(0.3, 1.0, 0.5, 1.0)
			vmat.emission_enabled = true
			vmat.emission = Color(0.3, 1.0, 0.5, 1.0)
			vmat.emission_energy_multiplier = 4.0
			visor_mesh.material_override = vmat

		# Brilho espectral fantasmagórico verde
		var g_light := OmniLight3D.new()
		g_light.name = "GhostSpectralLight"
		g_light.light_color = Color(0.2, 1.0, 0.4)
		g_light.light_energy = 3.0
		g_light.omni_range = 5.5
		g_light.position = Vector3(0, 1.2, 0)
		add_child(g_light)

	else:
		# 100: Garrick <Mestre Ferreiro> | Cor: Marrom-Bronze / Avental de Forja + Martelo na mão
		is_dummy = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.68, 0.45, 0.22, 1.0) # Marrom-Bronze
		mat.roughness = 0.5
		mat.metallic = 0.35
		body_mesh.material_override = mat

		if apron_mesh:
			apron_mesh.visible = true
			var amat := StandardMaterial3D.new()
			amat.albedo_color = Color(0.24, 0.14, 0.08, 1.0) # Avental de Forja em couro escuro
			amat.roughness = 0.85
			apron_mesh.material_override = amat

		if visor_mesh:
			visor_mesh.visible = true
			var vmat := StandardMaterial3D.new()
			vmat.albedo_color = Color(1.0, 0.75, 0.2, 1.0) # Âmbar incandescente
			vmat.emission_enabled = true
			vmat.emission = Color(1.0, 0.75, 0.2, 1.0)
			vmat.emission_energy_multiplier = 2.5
			visor_mesh.material_override = vmat

		# Martelo na mão
		var hammer_root := Node3D.new()
		hammer_root.name = "HammerProp"
		hammer_root.position = Vector3(0.48, 0.7, -0.15)
		hammer_root.rotation = Vector3(deg_to_rad(20), 0, deg_to_rad(-15))
		add_child(hammer_root)

		var handle := MeshInstance3D.new()
		var h_cyl := CylinderMesh.new()
		h_cyl.top_radius = 0.025
		h_cyl.bottom_radius = 0.025
		h_cyl.height = 0.55
		handle.mesh = h_cyl
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = Color(0.35, 0.2, 0.1, 1.0)
		handle.material_override = h_mat
		hammer_root.add_child(handle)

		var head := MeshInstance3D.new()
		var hd_box := BoxMesh.new()
		hd_box.size = Vector3(0.15, 0.14, 0.28)
		head.mesh = hd_box
		head.position = Vector3(0, 0.25, 0)
		var hd_mat := StandardMaterial3D.new()
		hd_mat.albedo_color = Color(0.22, 0.24, 0.28, 1.0)
		hd_mat.metallic = 0.9
		hd_mat.roughness = 0.3
		head.material_override = hd_mat
		hammer_root.add_child(head)

	var model_id := 100
	if is_dummy_check:
		model_id = -1
	elif is_lyra:
		model_id = 103
	elif is_varis:
		model_id = 104
	elif is_randel:
		model_id = 105
	elif is_valen:
		model_id = 106
	elif (npc_id >= 111 and npc_id <= 120) or npc_id == 123:
		model_id = npc_id
	elif npc_id >= 400 and npc_id < 410:
		model_id = 121 # Paladino da Luz
	elif npc_id >= 420 and npc_id < 430:
		model_id = 122 # Clériga da Luz
	_apply_npc_model(model_id)

func _apply_npc_model(model_id: int) -> void:
	# NPCs com modelo 3D (Art Bible) substituem a cápsula e os adereços simples
	if npc_model and is_instance_valid(npc_model):
		npc_model.queue_free()
	npc_model = null
	if _npc_capsule == null:
		_npc_capsule = body_mesh.mesh
	if model_id < 0 or not LunariaModel.has_model(LunariaModel.npc_uid(model_id)):
		body_mesh.mesh = _npc_capsule
		return
	_clear_props()
	body_mesh.mesh = null
	if apron_mesh:
		apron_mesh.visible = false
	if visor_mesh:
		visor_mesh.visible = false
	npc_model = LunariaModel.create_npc(model_id) as LunariaModel
	add_child(npc_model)

func set_npc_info(p_id: int, p_name: String = "", script_path: String = "") -> void:
	npc_id = p_id
	npc_script_path = script_path
	if p_name.strip_edges() == "" or p_name.begins_with("NPC #"):
		npc_name = get_default_npc_name(p_id)
	else:
		npc_name = p_name
	_ensure_node_refs()
	_setup_npc_visuals(script_path)
	_update_tags()

func update_network_transform(new_pos: Vector3, new_rot_y: float, state: int) -> void:
	target_position = new_pos
	target_rotation_y = new_rot_y

	# Estado 255: Oculto / Desativado (ex: Varis durante o dia)
	if state == 255:
		visible = false
		if collision_shape:
			collision_shape.disabled = true
	else:
		visible = true
		if collision_shape:
			collision_shape.disabled = false

	if current_state != state:
		current_state = state
		_update_tags()

func show_damage(damage: int, is_crit: bool, hp: int, p_max_hp: int) -> void:
	current_hp = hp
	max_hp = p_max_hp
	_update_tags()

	# Efeito de balanço físico ao tomar hit
	if is_dummy and body_mesh:
		var hit_tw := create_tween()
		var tilt_dir := 1.0 if randf() > 0.5 else -1.0
		hit_tw.tween_property(body_mesh, "rotation:z", deg_to_rad(22.0 * tilt_dir), 0.05)
		hit_tw.tween_property(body_mesh, "rotation:z", deg_to_rad(-14.0 * tilt_dir), 0.07)
		hit_tw.tween_property(body_mesh, "rotation:z", 0.0, 0.09)

	_spawn_floating_damage(damage, is_crit)

func _spawn_floating_damage(damage: int, is_crit: bool) -> void:
	var dmg_label := Label3D.new()
	add_child(dmg_label)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.outline_size = 8
	dmg_label.outline_modulate = Color(0, 0, 0, 1)
	dmg_label.no_depth_test = true
	dmg_label.position = Vector3(randf_range(-0.35, 0.35), 2.2 + randf_range(0.0, 0.3), randf_range(-0.35, 0.35))

	if is_crit:
		dmg_label.text = "-%d!" % damage
		dmg_label.font_size = 46
		dmg_label.modulate = Color(1.0, 0.92, 0.1, 1.0)
	else:
		dmg_label.text = "-%d" % damage
		dmg_label.font_size = 32
		dmg_label.modulate = Color(1.0, 0.45, 0.2, 1.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dmg_label, "position:y", dmg_label.position.y + 1.3, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dmg_label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dmg_label.queue_free)

func _update_tags() -> void:
	_ensure_node_refs()
	if not name_tag:
		return

	if is_dummy:
		name_tag.text = "%s\n[HP: %d/%d]" % [npc_name, current_hp, max_hp]
		name_tag.modulate = Color(1.0, 0.9, 0.7)
		return

	var state_text := ""
	match current_state:
		0:
			state_text = "[Parado]"
		1:
			state_text = "[Patrulhando]" if (npc_id == 105 or npc_id == 106) else "[Caminhando]"
		2:
			state_text = "[Na Forja]" if (npc_id == 100 or npc_id == 1) else "[Trabalhando]"
		3:
			state_text = "[Na Taverna]" if (npc_id == 100 or npc_id == 1) else "[Descansando]"
		255:
			state_text = "[Oculto]"
		_:
			state_text = ""

	match npc_id:
		103: # Lyra
			name_tag.modulate = Color(0.85, 0.7, 1.0)
		104: # Varis
			name_tag.modulate = Color(1.0, 0.35, 0.35)
		105: # Capitão Randel
			name_tag.modulate = Color(0.85, 0.95, 1.0)
		106: # Guarda Valen
			name_tag.modulate = Color(0.8, 0.9, 1.0)
		107: # Irmã Seraphina
			name_tag.modulate = Color(1.0, 0.92, 0.45)
		108: # Mestre Aurelius
			name_tag.modulate = Color(0.35, 0.88, 1.0)
		109: # Kaelen
			name_tag.modulate = Color(0.65, 0.95, 0.65)
		110: # Alquimista Esquecido
			name_tag.modulate = Color(0.4, 1.0, 0.6)
		_: # Garrick
			name_tag.modulate = Color(1.0, 0.85, 0.4)

	if not is_dummy:
		var hearts_str := get_hearts_string(friendship_points)
		if state_text != "":
			name_tag.text = "%s\n%s\n%s" % [npc_name, state_text, hearts_str]
		else:
			name_tag.text = "%s\n%s" % [npc_name, hearts_str]
	else:
		if state_text != "":
			name_tag.text = "%s\n%s" % [npc_name, state_text]
		else:
			name_tag.text = npc_name

func show_dialogue(text: String) -> void:
	_ensure_node_refs()
	if not dialogue_tag or not dialogue_timer:
		return

	# Personaliza cores do balão de fala conforme a identidade do NPC
	var text_color := Color(1.0, 0.95, 0.6, 1.0)
	var border_color := Color(0.9, 0.75, 0.2, 0.9)

	match npc_id:
		103: # Lyra
			text_color = Color(0.88, 0.75, 1.0, 1.0) # Lilás encantado
			border_color = Color(0.72, 0.45, 0.95, 0.95)
		104: # Varis
			text_color = Color(1.0, 0.45, 0.45, 1.0) # Vermelho carmesim
			border_color = Color(0.85, 0.15, 0.2, 0.95)
		105: # Capitão Randel
			text_color = Color(0.9, 0.96, 1.0, 1.0) # Azul real
			border_color = Color(0.2, 0.5, 0.95, 0.95)
		106: # Guarda Valen
			text_color = Color(0.85, 0.92, 1.0, 1.0) # Azul prateado
			border_color = Color(0.35, 0.65, 0.95, 0.95)
		107: # Irmã Seraphina
			text_color = Color(1.0, 0.95, 0.7, 1.0) # Luz sagrada
			border_color = Color(1.0, 0.85, 0.3, 0.95)
		108: # Mestre Aurelius
			text_color = Color(0.6, 0.92, 1.0, 1.0) # Azul astral
			border_color = Color(0.2, 0.7, 1.0, 0.95)
		109: # Kaelen
			text_color = Color(0.75, 1.0, 0.75, 1.0) # Verde caçador
			border_color = Color(0.3, 0.75, 0.35, 0.95)
		110: # Alquimista Esquecido
			text_color = Color(0.55, 1.0, 0.7, 1.0) # Ectoplasma esmeralda
			border_color = Color(0.1, 0.85, 0.4, 0.95)
		_: # Garrick
			text_color = Color(1.0, 0.92, 0.5, 1.0) # Âmbar da forja
			border_color = Color(0.95, 0.75, 0.2, 0.9)

	dialogue_tag.modulate = text_color
	dialogue_tag.text = "“%s”" % text
	dialogue_tag.visible = true

	if balloon_border and balloon_border.material_override:
		(balloon_border.material_override as StandardMaterial3D).albedo_color = border_color

	if balloon_root:
		balloon_root.visible = true
		if balloon_tween and balloon_tween.is_valid():
			balloon_tween.kill()
		balloon_tween = create_tween().set_parallel(true)
		balloon_root.scale = Vector3(0.1, 0.1, 0.1)
		dialogue_tag.scale = Vector3(0.1, 0.1, 0.1)
		balloon_tween.tween_property(balloon_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		balloon_tween.tween_property(dialogue_tag, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	dialogue_timer.start(7.5)

func _on_dialogue_timer_timeout() -> void:
	if balloon_tween and balloon_tween.is_valid():
		balloon_tween.kill()

	balloon_tween = create_tween().set_parallel(true)
	if balloon_root:
		balloon_tween.tween_property(balloon_root, "scale", Vector3(0.1, 0.1, 0.1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if dialogue_tag:
		balloon_tween.tween_property(dialogue_tag, "scale", Vector3(0.1, 0.1, 0.1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	balloon_tween.chain().tween_callback(func():
		if dialogue_tag:
			dialogue_tag.visible = false
			dialogue_tag.scale = Vector3.ONE
		if balloon_root:
			balloon_root.visible = false
			balloon_root.scale = Vector3.ONE
	)

func _process(delta: float) -> void:
	time_accum += delta
	var prev_pos: Vector3 = global_position
	global_position = global_position.lerp(target_position, INTERPOLATION_SPEED * delta)
	if npc_model and is_instance_valid(npc_model) and delta > 0.0:
		var step := global_position - prev_pos
		npc_model.set_move_speed(Vector2(step.x, step.z).length() / delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, INTERPOLATION_SPEED * delta)

	# Animação suave do frasco luminoso de Lyra
	var flask := get_node_or_null("AlchemyFlaskProp") as Node3D
	if flask:
		flask.rotation.y += delta * 1.8
		flask.position.y = 2.35 + sin(time_accum * 3.0) * 0.08
