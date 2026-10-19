extends Node3D

var npc_id: int = 1
var npc_name: String = "Garrick, o Ferreiro"
var target_position: Vector3 = Vector3.ZERO
var target_rotation_y: float = 0.0
var current_state: int = 0

var current_hp: int = 1000
var max_hp: int = 1000
var is_dummy: bool = false

const INTERPOLATION_SPEED: float = 15.0

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var apron_mesh: MeshInstance3D = get_node_or_null("BodyMesh/ApronMesh")
@onready var visor_mesh: MeshInstance3D = get_node_or_null("BodyMesh/VisorIndicator")
@onready var name_tag: Label3D = $NameTag
@onready var dialogue_tag: Label3D = $DialogueTag
@onready var dialogue_timer: Timer = $DialogueTimer

func _ready() -> void:
	target_position = global_position
	target_rotation_y = rotation.y
	_check_dummy()
	_update_tags()

func _check_dummy() -> void:
	if npc_id == 101 or npc_id == 102:
		is_dummy = true
		if apron_mesh:
			apron_mesh.visible = false
		if visor_mesh:
			visor_mesh.visible = false
		# Madeira do Boneco de Treino
		if body_mesh:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0.42, 0.25, 1.0)
			mat.roughness = 0.85
			body_mesh.material_override = mat

func set_npc_info(id: int, p_name: String) -> void:
	npc_id = id
	npc_name = p_name
	_check_dummy()
	_update_tags()

func update_network_transform(new_pos: Vector3, new_rot_y: float, state: int) -> void:
	target_position = new_pos
	target_rotation_y = new_rot_y
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

	# Número de dano 3D flutuante
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
		dmg_label.modulate = Color(1.0, 0.92, 0.1, 1.0) # Amarelo Grande com "!"
	else:
		dmg_label.text = "-%d" % damage
		dmg_label.font_size = 32
		dmg_label.modulate = Color(1.0, 0.45, 0.2, 1.0) # Laranja vibrante

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dmg_label, "position:y", dmg_label.position.y + 1.3, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dmg_label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dmg_label.queue_free)

func _update_tags() -> void:
	if not name_tag:
		return

	if is_dummy:
		name_tag.text = "%s\n[HP: %d/%d]" % [npc_name, current_hp, max_hp]
		return

	var state_text := ""
	match current_state:
		0:
			state_text = "[Parado]"
		1:
			state_text = "[Caminhando]"
		2:
			state_text = "[Na Forja]"
		3:
			state_text = "[Na Taverna]"
		_:
			state_text = ""

	name_tag.text = "%s\n%s" % [npc_name, state_text]

func show_dialogue(text: String) -> void:
	if not dialogue_tag or not dialogue_timer:
		return

	dialogue_tag.modulate = Color(1, 0.95, 0.6, 1)
	dialogue_tag.text = "\"%s\"" % text
	dialogue_tag.visible = true
	dialogue_timer.start(7.0)

func _on_dialogue_timer_timeout() -> void:
	if dialogue_tag:
		dialogue_tag.visible = false

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, INTERPOLATION_SPEED * delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, INTERPOLATION_SPEED * delta)
