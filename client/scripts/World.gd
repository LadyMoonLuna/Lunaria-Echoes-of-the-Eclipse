extends Node3D

@export var local_player_scene: PackedScene = preload("res://scenes/LocalPlayer.tscn")
@export var remote_player_scene: PackedScene = preload("res://scenes/RemotePlayer.tscn")
@export var npc_scene: PackedScene = preload("res://scenes/NPC.tscn")
const MobEntityScript = preload("res://scripts/MobEntity.gd")
const CharacterSelectUIScript = preload("res://scripts/CharacterSelectUI.gd")

@onready var players_container: Node3D = $Players
@onready var npcs_container: Node3D = $NPCs
@onready var clock_label: Label = $HUD/ClockPanel/ClockLabel
@onready var identity_label: Label = $HUD/PlayerStatusPanel/VBox/IdentityLabel
@onready var hp_bar: ProgressBar = $HUD/PlayerStatusPanel/VBox/HPBar
@onready var hp_label: Label = $HUD/PlayerStatusPanel/VBox/HPLabel
@onready var stamina_bar: ProgressBar = $HUD/PlayerStatusPanel/VBox/StaminaBar
@onready var stamina_label: Label = $HUD/PlayerStatusPanel/VBox/StaminaLabel
@onready var dialogue_label: Label = $HUD/DialogueLabel
@onready var dialogue_clear_timer: Timer = $HUD/DialogueClearTimer
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var rain_particles: CPUParticles3D = get_node_or_null("RainParticles")
@onready var NetworkManager: Node = get_node_or_null("/root/NetworkManager")

var local_player: CharacterBody3D = null
var remote_players: Dictionary = {}
var npcs: Dictionary = {}
var mobs: Dictionary = {}
var mobs_container: Node3D = null
var projectiles_container: Node3D = null
var active_projectiles: Dictionary = {}
var char_select_ui: CanvasLayer = null

const MOON_NAMES := [
	"Lua Nova",
	"Lua Crescente",
	"Quarto Crescente",
	"Gibosa Crescente",
	"Lua Cheia",
	"Gibosa Minguante",
	"Quarto Minguante",
	"Lua Minguante",
	"LUA DE SANGUE",
	"ECLIPSE TOTAL"
]
const WEATHER_NAMES := ["Limpo", "Chuva", "Neblina Densa", "Névoa Carmesim"]
const RACE_NAMES := ["", "Valeriano", "Noctari", "Kharad", "Varkai", "Dhampir"]
const CLASS_NAMES := ["", "Espadachim", "Batedor", "Iniciado", "Acólito"]

var current_world_hour: int = 16
var current_world_minute: int = 0
var current_moon_phase: int = 1
var current_weather_type: int = 0

var my_race_id: int = 1
var my_class_id: int = 1
var my_hp: int = 100
var my_max_hp: int = 100
var my_stamina: int = 100
var my_max_stamina: int = 100

func _ready() -> void:
	mobs_container = Node3D.new()
	mobs_container.name = "Mobs"
	add_child(mobs_container)

	projectiles_container = Node3D.new()
	projectiles_container.name = "Projectiles"
	add_child(projectiles_container)

	char_select_ui = CharacterSelectUIScript.new()
	add_child(char_select_ui)
	char_select_ui.identity_confirmed.connect(_on_identity_confirmed)

	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.world_state_received.connect(_on_world_state_received)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.npc_state_received.connect(_on_npc_state_received)
	NetworkManager.npc_spoke.connect(_on_npc_spoke)
	NetworkManager.world_time_updated.connect(_on_world_time_updated)
	NetworkManager.combat_event_received.connect(_on_combat_event_received)
	NetworkManager.player_stats_received.connect(_on_player_stats_received)
	NetworkManager.mob_state_received.connect(_on_mob_state_received)
	NetworkManager.aoe_telegraph_received.connect(_on_aoe_telegraph_received)
	NetworkManager.projectile_spawned.connect(_on_projectile_spawned)

	_create_zone_landmarks()
	_spawn_local_player(Vector3(0, 1, 0))
	_update_hud()
	_update_clock_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_interact_nearest_npc()
		elif event.keycode == KEY_C or event.keycode == KEY_TAB:
			if char_select_ui:
				if char_select_ui.is_open:
					char_select_ui.close_menu()
				else:
					char_select_ui.open_menu()
		elif event.keycode == KEY_F6 or event.is_action_pressed("skip_time"):
			_on_skip_time_pressed()
		elif event.keycode == KEY_F7:
			_on_cycle_moon_pressed()
		elif event.keycode == KEY_F8:
			_on_cycle_weather_pressed()

func _on_skip_time_pressed() -> void:
	print("[World] F6: Solicitando avanço de +6 horas ao servidor...")
	NetworkManager.send_world_control(1, 6)

func _on_cycle_moon_pressed() -> void:
	print("[World] F7: Ciclando fase da lua no servidor...")
	NetworkManager.send_world_control(2, 1)

func _on_cycle_weather_pressed() -> void:
	print("[World] F8: Ciclando clima no servidor...")
	NetworkManager.send_world_control(3, 1)

func _try_interact_nearest_npc() -> void:
	if not local_player:
		return

	var player_pos: Vector3 = local_player.global_position
	var nearest_id: int = 0
	var min_dist: float = 5.0 # Alcance de interação

	for nid in npcs.keys():
		var npc_node = npcs[nid]
		if is_instance_valid(npc_node):
			var dist = player_pos.distance_to(npc_node.global_position)
			if dist <= min_dist:
				min_dist = dist
				nearest_id = nid

	if nearest_id > 0:
		print("[World] Interagindo com NPC #%d (distância: %.2fm)" % [nearest_id, min_dist])
		NetworkManager.send_player_interact(nearest_id)

func _spawn_local_player(spawn_pos: Vector3) -> void:
	if local_player != null:
		return
	local_player = local_player_scene.instantiate()
	players_container.add_child(local_player)
	local_player.global_position = spawn_pos
	local_player.identity_changed.connect(_on_local_identity_changed)

func _on_local_identity_changed(race_id: int, class_id: int) -> void:
	my_race_id = race_id
	my_class_id = class_id
	_update_hud()

func _on_connected_to_server(_player_id: int) -> void:
	_update_hud()
	# Envia seleção de identidade inicial (Valeriano / Espadachim)
	NetworkManager.send_select_identity(my_race_id, my_class_id)

func _on_world_time_updated(hour: int, minute: int, moon_phase: int = 1, weather_type: int = 0) -> void:
	current_world_hour = hour
	current_world_minute = minute
	current_moon_phase = moon_phase
	current_weather_type = weather_type
	_update_clock_hud()

	for mob in mobs.values():
		if is_instance_valid(mob):
			mob.set_moon_phase(current_moon_phase)

func _update_clock_hud() -> void:
	if not clock_label:
		return

	var period_str: String = "Dia" if (current_world_hour >= 6 and current_world_hour < 18) else "Noite"
	var moon_str: String = MOON_NAMES[current_moon_phase] if current_moon_phase < MOON_NAMES.size() else "Lua"
	var weather_str: String = WEATHER_NAMES[current_weather_type] if current_weather_type < WEATHER_NAMES.size() else "Limpo"

	clock_label.text = "Horário: %02d:%02d (%s) | %s | %s | [F6] +6h [F7] Lua [F8] Clima" % [
		current_world_hour, current_world_minute, period_str, moon_str, weather_str
	]

func _on_combat_event_received(attacker_id: int, target_id: int, action_type: int, damage: int, is_crit: int, target_hp: int, target_max_hp: int) -> void:
	if damage > 0 and target_id > 0:
		var crit_str := " [CRÍTICO!]" if is_crit == 1 else ""
		print("[World] Combate: Atacante #%d atingiu Alvo #%d causando %d de dano%s (HP Alvo: %d/%d)" % [
			attacker_id, target_id, damage, crit_str, target_hp, target_max_hp
		])

		var target_pos: Vector3 = Vector3.ZERO

		# Se for Mob (ID >= 200)
		if target_id >= 200 and mobs.has(target_id):
			if is_instance_valid(mobs[target_id]):
				target_pos = mobs[target_id].global_position
				mobs[target_id].show_damage(damage, is_crit == 1, target_hp, target_max_hp)

		# Se for NPC / Dummy (1, 101, 102)
		elif npcs.has(target_id):
			if is_instance_valid(npcs[target_id]):
				target_pos = npcs[target_id].global_position
				npcs[target_id].show_damage(damage, is_crit == 1, target_hp, target_max_hp)

		# Se for Jogador (ID 1 a 5)
		elif target_id >= 1 and target_id <= 5:
			if target_id == NetworkManager.my_player_id and local_player:
				target_pos = local_player.global_position
				_spawn_player_floating_damage(local_player, damage)
			elif remote_players.has(target_id) and is_instance_valid(remote_players[target_id]):
				target_pos = remote_players[target_id].global_position
				_spawn_player_floating_damage(remote_players[target_id], damage)

		if target_pos != Vector3.ZERO:
			_check_projectile_impact(target_pos)

func _on_identity_confirmed(race_id: int, class_id: int) -> void:
	my_race_id = race_id
	my_class_id = class_id
	if local_player and is_instance_valid(local_player):
		local_player.apply_identity(race_id, class_id)
	_update_hud()

func _on_player_stats_received(player_id: int, race_id: int, class_id: int, hp: int, max_hp: int, stamina: int, max_stamina: int) -> void:
	if player_id == NetworkManager.my_player_id:
		my_race_id = race_id
		my_class_id = class_id
		my_hp = hp
		my_max_hp = max_hp
		my_stamina = stamina
		my_max_stamina = max_stamina
		if local_player and is_instance_valid(local_player):
			local_player.apply_identity(race_id, class_id)
		_update_hud()
	elif remote_players.has(player_id) and is_instance_valid(remote_players[player_id]):
		remote_players[player_id].apply_identity(race_id, class_id)

func _update_hud() -> void:
	if identity_label:
		var r_name: String = RACE_NAMES[my_race_id] if my_race_id < RACE_NAMES.size() else "Valeriano"
		var c_name: String = CLASS_NAMES[my_class_id] if my_class_id < CLASS_NAMES.size() else "Espadachim"
		var pid_str: String = "#%d" % NetworkManager.my_player_id if NetworkManager.my_player_id > 0 else "..."
		identity_label.text = "[%s] %s (ID: %s)" % [r_name, c_name, pid_str]

	if hp_bar:
		hp_bar.max_value = my_max_hp
		hp_bar.value = my_hp
	if hp_label:
		hp_label.text = "HP: %d / %d" % [my_hp, my_max_hp]

	if stamina_bar:
		stamina_bar.max_value = my_max_stamina
		stamina_bar.value = my_stamina
	if stamina_label:
		stamina_label.text = "Stamina: %d / %d" % [my_stamina, my_max_stamina]

func _on_world_state_received(players_dict: Dictionary) -> void:
	for pid in players_dict.keys():
		var pdata: Dictionary = players_dict[pid]
		if pid == NetworkManager.my_player_id:
			continue

		if remote_players.has(pid):
			remote_players[pid].update_network_transform(pdata.position, pdata.rotation_y)
		else:
			_spawn_remote_player(pid, pdata.position, pdata.rotation_y)

func _spawn_remote_player(pid: int, initial_pos: Vector3, initial_rot_y: float) -> void:
	var rp = remote_player_scene.instantiate()
	players_container.add_child(rp)
	rp.global_position = initial_pos
	rp.rotation.y = initial_rot_y
	rp.set_player_id(pid)
	remote_players[pid] = rp
	print("[World] Jogador remoto adicionado: ID %d" % pid)

func _on_player_disconnected(pid: int) -> void:
	if remote_players.has(pid):
		var rp = remote_players[pid]
		remote_players.erase(pid)
		rp.queue_free()
		print("[World] Jogador remoto removido: ID %d" % pid)

func _on_npc_state_received(npcs_dict: Dictionary) -> void:
	for nid in npcs_dict.keys():
		var data: Dictionary = npcs_dict[nid]
		if npcs.has(nid):
			npcs[nid].update_network_transform(data.position, data.rotation_y, data.state)
		else:
			_spawn_npc(nid, data.position, data.rotation_y, data.state)

func _spawn_npc(nid: int, initial_pos: Vector3, initial_rot_y: float, state: int) -> void:
	var npc_inst = npc_scene.instantiate()
	npcs_container.add_child(npc_inst)
	npc_inst.global_position = initial_pos
	npc_inst.rotation.y = initial_rot_y
	var p_name = "Garrick, o Ferreiro" if nid == 1 else ("Boneco de Treino" if (nid == 101 or nid == 102) else "NPC #%d" % nid)
	npc_inst.set_npc_info(nid, p_name)
	npc_inst.update_network_transform(initial_pos, initial_rot_y, state)
	npcs[nid] = npc_inst
	print("[World] NPC instanciado na cena: %s (ID %d)" % [p_name, nid])

func _on_npc_spoke(npc_id: int, message: String) -> void:
	if npcs.has(npc_id):
		npcs[npc_id].show_dialogue(message)

	if dialogue_label and dialogue_clear_timer:
		var sender_name = "Garrick" if npc_id == 1 else "NPC #%d" % npc_id
		dialogue_label.text = "[%s]: %s" % [sender_name, message]
		dialogue_label.visible = true
		dialogue_clear_timer.start(8.0)

func _on_dialogue_clear_timeout() -> void:
	if dialogue_label:
		dialogue_label.visible = false

func _get_lighting_targets(time_val: float) -> Dictionary:
	# Parâmetros de iluminação por período:
	# Dia (06h - 16h): Luz solar clara e brilhante (energy = 1.2)
	var day_energy := 1.2
	var day_light_col := Color(1.0, 0.96, 0.88, 1.0)
	var day_ambient := Color(0.55, 0.60, 0.70, 1.0)
	var day_sky_top := Color(0.20, 0.35, 0.60, 1.0)
	var day_sky_horiz := Color(0.55, 0.65, 0.75, 1.0)

	# Entardecer (17h - 18h): Luz alaranjada de pôr do sol
	var dusk_energy := 0.7
	var dusk_light_col := Color(1.0, 0.55, 0.22, 1.0)
	var dusk_ambient := Color(0.42, 0.28, 0.24, 1.0)
	var dusk_sky_top := Color(0.22, 0.16, 0.35, 1.0)
	var dusk_sky_horiz := Color(0.90, 0.45, 0.18, 1.0)

	# Noite (18h às 05h): Ajuste conforme as 10 Fases da Lua
	var night_energy := 0.24
	var night_light_col := Color("#3b5998")
	var night_ambient := Color(0.10, 0.12, 0.18, 1.0)
	var night_sky_top := Color(0.04, 0.05, 0.10, 1.0)
	var night_sky_horiz := Color(0.08, 0.12, 0.20, 1.0)

	match current_moon_phase:
		0: # 0 (Lua Nova): Muito escuro (energy = 0.08, azul-profundo #1a243b)
			night_energy = 0.08
			night_light_col = Color("#1a243b")
			night_ambient = Color(0.03, 0.04, 0.06, 1.0)
			night_sky_top = Color(0.01, 0.02, 0.04, 1.0)
			night_sky_horiz = Color(0.04, 0.06, 0.10, 1.0)
		1, 7: # 1 e 7 (Crescente / Minguante): Luar fraco (energy = 0.16, azul-frio #2c3e66)
			night_energy = 0.16
			night_light_col = Color("#2c3e66")
			night_ambient = Color(0.06, 0.08, 0.12, 1.0)
			night_sky_top = Color(0.02, 0.03, 0.06, 1.0)
			night_sky_horiz = Color(0.06, 0.09, 0.15, 1.0)
		2, 6: # 2 e 6 (Quarto Crescente / Quarto Minguante): Luar médio (energy = 0.24, azul-prateado #3b5998)
			night_energy = 0.24
			night_light_col = Color("#3b5998")
			night_ambient = Color(0.09, 0.11, 0.16, 1.0)
			night_sky_top = Color(0.03, 0.05, 0.09, 1.0)
			night_sky_horiz = Color(0.08, 0.12, 0.20, 1.0)
		3, 5: # 3 e 5 (Gibosa Crescente / Gibosa Minguante): Luar claro (energy = 0.32, prata-azulado #5b7ec2)
			night_energy = 0.32
			night_light_col = Color("#5b7ec2")
			night_ambient = Color(0.12, 0.14, 0.22, 1.0)
			night_sky_top = Color(0.05, 0.07, 0.14, 1.0)
			night_sky_horiz = Color(0.12, 0.16, 0.26, 1.0)
		4: # 4 (Lua Cheia): Luar intenso e brilhante (energy = 0.45, prata-lunar brilhante #8ab4f8)
			night_energy = 0.45
			night_light_col = Color("#8ab4f8")
			night_ambient = Color(0.16, 0.19, 0.28, 1.0)
			night_sky_top = Color(0.07, 0.10, 0.18, 1.0)
			night_sky_horiz = Color(0.18, 0.22, 0.34, 1.0)
		8: # 8 (Lua de Sangue): Luz carmesim intensa (energy = 0.40, vermelho-sangue #e62626)
			night_energy = 0.40
			night_light_col = Color("#e62626")
			night_ambient = Color(0.25, 0.06, 0.06, 1.0)
			night_sky_top = Color(0.16, 0.02, 0.04, 1.0)
			night_sky_horiz = Color(0.65, 0.12, 0.15, 1.0)
		9: # 9 (Eclipse Total - dia e noite): Escurece o céu para roxo-abissal (energy = 0.15, cor #4a154b)
			night_energy = 0.15
			night_light_col = Color("#4a154b")
			night_ambient = Color(0.06, 0.03, 0.08, 1.0)
			night_sky_top = Color(0.02, 0.01, 0.04, 1.0)
			night_sky_horiz = Color(0.20, 0.06, 0.25, 1.0)

			day_energy = 0.15
			day_light_col = Color("#4a154b")
			day_ambient = Color(0.08, 0.04, 0.10, 1.0)
			day_sky_top = Color(0.03, 0.01, 0.05, 1.0)
			day_sky_horiz = Color(0.22, 0.08, 0.28, 1.0)

	# Modificadores de Clima no Environment:
	var target_fog_density := 0.0001
	var target_fog_color := Color("#758596")

	match current_weather_type:
		0: # Limpo
			target_fog_density = 0.0001
		1: # Chuva
			target_fog_density = 0.018
			target_fog_color = Color("#4a5868")
			day_energy *= 0.7
			day_ambient = day_ambient.lerp(Color(0.3, 0.35, 0.4, 1.0), 0.5)
		2: # Neblina Cinza-Azulada Densa
			target_fog_density = 0.055
			target_fog_color = Color("#758596")
			day_energy *= 0.6
			day_ambient = day_ambient.lerp(Color(0.4, 0.42, 0.46, 1.0), 0.7)
			day_sky_horiz = Color(0.45, 0.48, 0.52, 1.0)
		3: # Névoa Carmesim Densa
			target_fog_density = 0.05
			target_fog_color = Color("#771515")
			day_ambient = day_ambient.lerp(Color(0.5, 0.15, 0.15, 1.0), 0.6)
			day_sky_horiz = day_sky_horiz.lerp(Color(0.8, 0.18, 0.18, 1.0), 0.6)

	var res := {
		"fog_density": target_fog_density,
		"fog_color": target_fog_color
	}

	if time_val >= 6.0 and time_val < 16.5:
		# Dia
		res["energy"] = day_energy
		res["light_color"] = day_light_col
		res["ambient_color"] = day_ambient
		res["sky_top"] = day_sky_top
		res["sky_horiz"] = day_sky_horiz
		res["rot_x"] = deg_to_rad(-45.0)
		res["rot_y"] = deg_to_rad(-30.0)

	elif time_val >= 16.5 and time_val < 17.5:
		# Transição Dia -> Entardecer
		var t := (time_val - 16.5) / 1.0
		res["energy"] = lerpf(day_energy, dusk_energy, t)
		res["light_color"] = day_light_col.lerp(dusk_light_col, t)
		res["ambient_color"] = day_ambient.lerp(dusk_ambient, t)
		res["sky_top"] = day_sky_top.lerp(dusk_sky_top, t)
		res["sky_horiz"] = day_sky_horiz.lerp(dusk_sky_horiz, t)
		res["rot_x"] = lerp_angle(deg_to_rad(-45.0), deg_to_rad(-20.0), t)
		res["rot_y"] = lerp_angle(deg_to_rad(-30.0), deg_to_rad(-55.0), t)

	elif time_val >= 17.5 and time_val < 18.5:
		# Entardecer
		res["energy"] = dusk_energy
		res["light_color"] = dusk_light_col
		res["ambient_color"] = dusk_ambient
		res["sky_top"] = dusk_sky_top
		res["sky_horiz"] = dusk_sky_horiz
		res["rot_x"] = deg_to_rad(-20.0)
		res["rot_y"] = deg_to_rad(-55.0)

	elif time_val >= 18.5 and time_val < 19.5:
		# Transição Entardecer -> Noite
		var t := (time_val - 18.5) / 1.0
		res["energy"] = lerpf(dusk_energy, night_energy, t)
		res["light_color"] = dusk_light_col.lerp(night_light_col, t)
		res["ambient_color"] = dusk_ambient.lerp(night_ambient, t)
		res["sky_top"] = dusk_sky_top.lerp(night_sky_top, t)
		res["sky_horiz"] = dusk_sky_horiz.lerp(night_sky_horiz, t)
		res["rot_x"] = lerp_angle(deg_to_rad(-20.0), deg_to_rad(-55.0), t)
		res["rot_y"] = lerp_angle(deg_to_rad(-55.0), deg_to_rad(40.0), t)

	elif time_val >= 19.5 or time_val < 5.0:
		# Noite
		res["energy"] = night_energy
		res["light_color"] = night_light_col
		res["ambient_color"] = night_ambient
		res["sky_top"] = night_sky_top
		res["sky_horiz"] = night_sky_horiz
		res["rot_x"] = deg_to_rad(-55.0)
		res["rot_y"] = deg_to_rad(40.0)

	else: # 5.0 <= time_val < 6.0
		# Alvorecer (Noite -> Dia)
		var t := (time_val - 5.0) / 1.0
		res["energy"] = lerpf(night_energy, day_energy, t)
		res["light_color"] = night_light_col.lerp(day_light_col, t)
		res["ambient_color"] = night_ambient.lerp(day_ambient, t)
		res["sky_top"] = night_sky_top.lerp(day_sky_top, t)
		res["sky_horiz"] = night_sky_horiz.lerp(day_sky_horiz, t)
		res["rot_x"] = lerp_angle(deg_to_rad(-55.0), deg_to_rad(-45.0), t)
		res["rot_y"] = lerp_angle(deg_to_rad(40.0), deg_to_rad(-30.0), t)

	return res

func _process(delta: float) -> void:
	_update_active_projectiles(delta)
	var time_f := float(current_world_hour) + float(current_world_minute) / 60.0
	var targets := _get_lighting_targets(time_f)

	if sun_light:
		sun_light.light_energy = lerpf(sun_light.light_energy, targets["energy"], 3.0 * delta)
		sun_light.light_color = sun_light.light_color.lerp(targets["light_color"], 3.0 * delta)
		sun_light.rotation.x = lerp_angle(sun_light.rotation.x, targets["rot_x"], 1.5 * delta)
		sun_light.rotation.y = lerp_angle(sun_light.rotation.y, targets["rot_y"], 1.5 * delta)

	if world_env and world_env.environment:
		world_env.environment.ambient_light_color = world_env.environment.ambient_light_color.lerp(targets["ambient_color"], 3.0 * delta)
		world_env.environment.fog_enabled = (current_weather_type > 0)
		world_env.environment.fog_density = lerpf(world_env.environment.fog_density, targets["fog_density"], 3.0 * delta)
		world_env.environment.fog_light_color = world_env.environment.fog_light_color.lerp(targets["fog_color"], 3.0 * delta)

		if world_env.environment.sky and world_env.environment.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := world_env.environment.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(targets["sky_top"], 3.0 * delta)
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(targets["sky_horiz"], 3.0 * delta)

	if rain_particles:
		var should_rain: bool = (current_weather_type == 1)
		if rain_particles.emitting != should_rain:
			rain_particles.emitting = should_rain

func _on_mob_state_received(mobs_dict: Dictionary) -> void:
	for mid in mobs_dict.keys():
		var mdata: Dictionary = mobs_dict[mid]
		if mobs.has(mid):
			var mob_node = mobs[mid]
			if is_instance_valid(mob_node):
				mob_node.update_network_data(mdata.position, mdata.rotation_y, mdata.state, mdata.hp, mdata.max_hp)
				mob_node.set_moon_phase(current_moon_phase)
		else:
			_spawn_mob(mid, mdata.type, mdata.position, mdata.rotation_y, mdata.state, mdata.hp, mdata.max_hp)

func _spawn_mob(mid: int, mtype: int, pos: Vector3, rot_y: float, state: int, hp: int, max_hp: int) -> void:
	var mob = MobEntityScript.new()
	mob.setup(mid, mtype, pos, rot_y, hp, max_hp)
	if mobs_container:
		mobs_container.add_child(mob)
	else:
		add_child(mob)

	mob.update_network_data(pos, rot_y, state, hp, max_hp)
	mob.set_moon_phase(current_moon_phase)
	mobs[mid] = mob
	print("[World] Mob instanciado no mundo: ID %d (Tipo %d) em %s" % [mid, mtype, pos])

func _on_aoe_telegraph_received(_source_id: int, pos_x: float, pos_z: float, radius: float, duration_ms: int) -> void:
	var dur_sec: float = float(duration_ms) / 1000.0
	var telegraph_root := Node3D.new()
	telegraph_root.position = Vector3(pos_x, 0.08, pos_z)
	add_child(telegraph_root)

	# Círculo base no chão (CylinderMesh achatado)
	var base_mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	base_mesh_inst.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_mesh_inst.material_override = mat
	telegraph_root.add_child(base_mesh_inst)

	# Anel/Preenchimento visual progressivo do perigo
	var fill_mesh_inst := MeshInstance3D.new()
	var fill_cyl := CylinderMesh.new()
	fill_cyl.top_radius = radius
	fill_cyl.bottom_radius = radius
	fill_cyl.height = 0.06
	fill_mesh_inst.mesh = fill_cyl

	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(1.0, 0.25, 0.1, 0.65)
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mesh_inst.material_override = fill_mat
	fill_mesh_inst.scale = Vector3(0.05, 1.0, 0.05)
	telegraph_root.add_child(fill_mesh_inst)

	# Tween preenchendo o círculo durante a duração telegrafada
	var tw := create_tween()
	tw.tween_property(fill_mesh_inst, "scale:x", 1.0, dur_sec)
	tw.parallel().tween_property(fill_mesh_inst, "scale:z", 1.0, dur_sec)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.75, dur_sec)

	# Flash de impacto e destruição ao término
	tw.chain().tween_callback(func():
		var impact_mesh := MeshInstance3D.new()
		var imp_cyl := CylinderMesh.new()
		imp_cyl.top_radius = radius * 1.08
		imp_cyl.bottom_radius = radius * 1.08
		imp_cyl.height = 0.25
		impact_mesh.mesh = imp_cyl

		var imp_mat := StandardMaterial3D.new()
		imp_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.95)
		imp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		imp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		impact_mesh.material_override = imp_mat
		telegraph_root.add_child(impact_mesh)

		var flash_tw := create_tween()
		flash_tw.tween_property(imp_mat, "albedo_color:a", 0.0, 0.25)
		flash_tw.parallel().tween_property(impact_mesh, "scale", Vector3(1.2, 2.0, 1.2), 0.25)
		flash_tw.chain().tween_callback(telegraph_root.queue_free)
	)

func _spawn_player_floating_damage(target_node: Node3D, damage: int) -> void:
	if not is_instance_valid(target_node):
		return

	var dmg_label := Label3D.new()
	add_child(dmg_label)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.outline_size = 8
	dmg_label.outline_modulate = Color(0, 0, 0, 1)
	dmg_label.no_depth_test = true
	dmg_label.font_size = 40
	dmg_label.modulate = Color(1.0, 0.15, 0.15, 1.0) # Vermelho Vivo
	dmg_label.text = "-%d" % damage
	dmg_label.global_position = target_node.global_position + Vector3(randf_range(-0.3, 0.3), 2.2 + randf_range(0.0, 0.2), randf_range(-0.3, 0.3))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dmg_label, "position:y", dmg_label.position.y + 1.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dmg_label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dmg_label.queue_free)

func _create_zone_landmarks() -> void:
	var zones := [
		{
			"pos": Vector3(16.0, 0.0, -8.0),
			"text": "Bosque Sussurrante\n[Área de Caça: Lobos da Bruma]",
			"color": Color(0.65, 0.95, 0.7, 1.0),
			"pillar_color": Color(0.2, 0.35, 0.22, 1.0)
		},
		{
			"pos": Vector3(-16.0, 0.0, 14.0),
			"text": "Ruínas da Vigília\n[Saqueadores e Besteiros]",
			"color": Color(1.0, 0.75, 0.45, 1.0),
			"pillar_color": Color(0.35, 0.28, 0.24, 1.0)
		},
		{
			"pos": Vector3(0.0, 0.0, 22.0),
			"text": "Entrada das Ruínas\n[Perigo: Executor de Ferro]",
			"color": Color(1.0, 0.35, 0.35, 1.0),
			"pillar_color": Color(0.22, 0.22, 0.26, 1.0)
		}
	]

	for z in zones:
		var marker := Node3D.new()
		marker.position = z.pos
		add_child(marker)

		# Marco de pedra / pilar
		var pilar := MeshInstance3D.new()
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.6, 1.8, 0.6)
		pilar.mesh = p_mesh
		pilar.position = Vector3(0, 0.9, 0)
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = z.pillar_color
		p_mat.roughness = 0.85
		pilar.material_override = p_mat
		marker.add_child(pilar)

		# Placa / Sinalizador 3D
		var lbl := Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.outline_size = 7
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.font_size = 24
		lbl.modulate = z.color
		lbl.text = z.text
		lbl.position = Vector3(0, 2.7, 0)
		marker.add_child(lbl)

func _on_projectile_spawned(proj_id: int, owner_id: int, proj_type: int, start_pos: Vector3, dir_xz: Vector2, speed: float, max_range: float) -> void:
	if not projectiles_container:
		return
	if active_projectiles.has(proj_id) and is_instance_valid(active_projectiles[proj_id]["node"]):
		return

	var p_node := Node3D.new()
	p_node.name = "Proj_%d" % proj_id
	p_node.position = start_pos
	projectiles_container.add_child(p_node)

	var dir := Vector3(dir_xz.x, 0.0, dir_xz.y).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD

	p_node.look_at(start_pos + dir, Vector3.UP)

	match proj_type:
		1: # Flecha Física (Batedor - Ataque Básico)
			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.02
			shaft_mesh.bottom_radius = 0.02
			shaft_mesh.height = 0.85
			shaft.mesh = shaft_mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#8d6e63")
			mat.emission_enabled = true
			mat.emission = Color("#cddc39")
			mat.emission_energy_multiplier = 1.2
			shaft.material_override = mat
			shaft.rotation.x = deg_to_rad(90.0)
			p_node.add_child(shaft)

			var tip := MeshInstance3D.new()
			var tip_cone := CylinderMesh.new()
			tip_cone.top_radius = 0.0
			tip_cone.bottom_radius = 0.035
			tip_cone.height = 0.12
			tip.mesh = tip_cone
			var tip_mat := StandardMaterial3D.new()
			tip_mat.albedo_color = Color("#cfd8dc")
			tip_mat.metallic = 0.9
			tip.material_override = tip_mat
			tip.rotation.x = deg_to_rad(90.0)
			tip.position = Vector3(0, 0, -0.45)
			p_node.add_child(tip)

		2: # Flecha Perfurante (Batedor - Skill Q)
			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.04
			shaft_mesh.bottom_radius = 0.04
			shaft_mesh.height = 1.3
			shaft.mesh = shaft_mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#76ff03")
			mat.emission_enabled = true
			mat.emission = Color("#76ff03")
			mat.emission_energy_multiplier = 4.0
			shaft.material_override = mat
			shaft.rotation.x = deg_to_rad(90.0)
			p_node.add_child(shaft)

			var light := OmniLight3D.new()
			light.light_color = Color("#76ff03")
			light.light_energy = 2.5
			light.omni_range = 3.5
			p_node.add_child(light)

		3: # Orbe Arcano (Iniciado - Ataque Básico)
			var orb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.44
			orb.mesh = sphere
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#00e5ff")
			mat.emission_enabled = true
			mat.emission = Color("#00e5ff")
			mat.emission_energy_multiplier = 3.5
			orb.material_override = mat
			p_node.add_child(orb)

			var core := MeshInstance3D.new()
			var core_sphere := SphereMesh.new()
			core_sphere.radius = 0.11
			core_sphere.height = 0.22
			core.mesh = core_sphere
			var core_mat := StandardMaterial3D.new()
			core_mat.albedo_color = Color(1, 1, 1)
			core_mat.emission_enabled = true
			core_mat.emission = Color(1, 1, 1)
			core_mat.emission_energy_multiplier = 5.0
			core.material_override = core_mat
			p_node.add_child(core)

			var light := OmniLight3D.new()
			light.light_color = Color("#00e5ff")
			light.light_energy = 2.0
			light.omni_range = 3.0
			p_node.add_child(light)

		4: # Cometa Elemental (Iniciado - Skill Q)
			var orb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.42
			sphere.height = 0.84
			orb.mesh = sphere
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#ff3d00")
			mat.emission_enabled = true
			mat.emission = Color("#ff5722")
			mat.emission_energy_multiplier = 4.5
			orb.material_override = mat
			p_node.add_child(orb)

			var core := MeshInstance3D.new()
			var core_sphere := SphereMesh.new()
			core_sphere.radius = 0.22
			core_sphere.height = 0.44
			core.mesh = core_sphere
			var core_mat := StandardMaterial3D.new()
			core_mat.albedo_color = Color("#d500f9")
			core_mat.emission_enabled = true
			core_mat.emission = Color("#d500f9")
			core_mat.emission_energy_multiplier = 4.0
			core.material_override = core_mat
			p_node.add_child(core)

			var light := OmniLight3D.new()
			light.light_color = Color("#ff6e40")
			light.light_energy = 4.0
			light.omni_range = 5.0
			p_node.add_child(light)

	active_projectiles[proj_id] = {
		"node": p_node,
		"dir": dir,
		"speed": speed,
		"max_range": max_range,
		"traveled": 0.0,
		"proj_type": proj_type
	}

func _update_active_projectiles(delta: float) -> void:
	var to_remove: Array = []
	for pid in active_projectiles.keys():
		var p_data: Dictionary = active_projectiles[pid]
		var node: Node3D = p_data["node"]
		if not is_instance_valid(node):
			to_remove.append(pid)
			continue

		var step: float = p_data["speed"] * delta
		node.global_position += p_data["dir"] * step
		p_data["traveled"] += step

		if p_data["traveled"] >= p_data["max_range"]:
			if p_data["proj_type"] == 4:
				_spawn_comet_explosion(node.global_position)
			node.queue_free()
			to_remove.append(pid)

	for pid in to_remove:
		active_projectiles.erase(pid)

func _check_projectile_impact(target_pos: Vector3) -> void:
	var to_remove: Array = []
	for pid in active_projectiles.keys():
		var p_data: Dictionary = active_projectiles[pid]
		if p_data["proj_type"] == 2: # Flecha Perfurante atravessa alvos sem ser destruída
			continue
		var node: Node3D = p_data["node"]
		if is_instance_valid(node) and node.global_position.distance_to(target_pos) <= 2.5:
			if p_data["proj_type"] == 4:
				_spawn_comet_explosion(node.global_position)
			node.queue_free()
			to_remove.append(pid)
			break

	for pid in to_remove:
		active_projectiles.erase(pid)

func _spawn_comet_explosion(pos: Vector3) -> void:
	var shockwave := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	shockwave.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color("#ff3d00")
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = mat
	shockwave.position = pos
	add_child(shockwave)

	var light := OmniLight3D.new()
	light.light_color = Color("#ff6e40")
	light.light_energy = 5.0
	light.omni_range = 6.0
	shockwave.add_child(light)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(shockwave, "scale", Vector3(9.3, 9.3, 9.3), 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.chain().tween_callback(shockwave.queue_free)
