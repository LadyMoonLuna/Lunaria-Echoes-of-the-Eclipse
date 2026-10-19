extends Node

# Sinais de rede dos Marcos 1, 2 e 3
signal connected_to_server(player_id: int)
signal player_disconnected(player_id: int)
signal world_state_received(players_dict: Dictionary)
signal npc_state_received(npcs_dict: Dictionary)
signal npc_spoke(npc_id: int, message: String)
signal world_time_updated(hour: int, minute: int, moon_phase: int, weather_type: int)
signal combat_event_received(attacker_id: int, target_id: int, action_type: int, damage: int, is_crit: int, target_hp: int, target_max_hp: int)
signal player_stats_received(player_id: int, race_id: int, class_id: int, hp: int, max_hp: int, stamina: int, max_stamina: int)
signal player_stats_updated(player_id: int, race_id: int, class_id: int, hp: int, max_hp: int, stamina: int, max_stamina: int)
signal mob_state_received(mobs_dict: Dictionary)
signal aoe_telegraph_received(source_id: int, pos_x: float, pos_z: float, radius: float, duration_ms: int)
signal projectile_spawned(proj_id: int, owner_id: int, proj_type: int, start_pos: Vector3, dir_xz: Vector2, speed: float, max_range: float)

const SERVER_HOST: String = "127.0.0.1"
const TCP_PORT: int = 7000
const UDP_PORT: int = 7001

var tcp: StreamPeerTCP = StreamPeerTCP.new()
var udp: PacketPeerUDP = PacketPeerUDP.new()

var my_player_id: int = 0
var seq: int = 0
var is_connected: bool = false
var tcp_rx_buffer: PackedByteArray = PackedByteArray()

func _ready() -> void:
	tcp.big_endian = false
	connect_to_server()

func connect_to_server() -> void:
	print("[NetworkManager] Conectando ao servidor em %s:%d (TCP) e %d (UDP)..." % [SERVER_HOST, TCP_PORT, UDP_PORT])
	var tcp_err = tcp.connect_to_host(SERVER_HOST, TCP_PORT)
	if tcp_err != OK:
		push_error("[NetworkManager] Erro ao iniciar conexão TCP: %d" % tcp_err)

	var udp_err = udp.connect_to_host(SERVER_HOST, UDP_PORT)
	if udp_err != OK:
		push_error("[NetworkManager] Erro ao conectar canal UDP: %d" % udp_err)

func _process(_delta: float) -> void:
	_process_tcp()
	_process_udp()

func _process_tcp() -> void:
	tcp.poll()
	var status = tcp.get_status()

	if status == StreamPeerTCP.STATUS_CONNECTED:
		var avail = tcp.get_available_bytes()
		if avail > 0:
			var res = tcp.get_data(avail)
			if res[0] == OK:
				tcp_rx_buffer.append_array(res[1])

		# Despacha pacotes TCP com validação de enquadramento
		while tcp_rx_buffer.size() > 0:
			var opcode: int = tcp_rx_buffer[0]

			if opcode == 0x01: # WELCOME (5 bytes)
				if tcp_rx_buffer.size() < 5:
					break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, 5)
				my_player_id = b.get_u32()
				is_connected = true
				print("[NetworkManager] Autenticado pelo servidor! PlayerID atribuído: %d" % my_player_id)
				connected_to_server.emit(my_player_id)
				tcp_rx_buffer = tcp_rx_buffer.slice(5)

			elif opcode == 0x02: # PLAYER_DISCONNECTED (5 bytes)
				if tcp_rx_buffer.size() < 5:
					break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, 5)
				var disconnected_id = b.get_u32()
				print("[NetworkManager] Jogador desconectado do servidor: ID %d" % disconnected_id)
				player_disconnected.emit(disconnected_id)
				tcp_rx_buffer = tcp_rx_buffer.slice(5)

			elif opcode == 0x13: # WORLD_TIME (5 bytes: opcode + hour + min + moon + weather)
				if tcp_rx_buffer.size() < 5:
					break
				var hour: int = tcp_rx_buffer[1]
				var minute: int = tcp_rx_buffer[2]
				var moon: int = tcp_rx_buffer[3]
				var weather: int = tcp_rx_buffer[4]
				world_time_updated.emit(hour, minute, moon, weather)
				tcp_rx_buffer = tcp_rx_buffer.slice(5)

			elif opcode == 0x21: # NPC_SAY (7 bytes header + MessageBytes)
				if tcp_rx_buffer.size() < 7:
					break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, 7)
				var npc_id = b.get_u32()
				var msg_len = b.get_u16()
				var total_size = 7 + msg_len

				if tcp_rx_buffer.size() < total_size:
					break # Aguarda a mensagem completa chegar
				var msg_bytes = tcp_rx_buffer.slice(7, total_size)
				var text = msg_bytes.get_string_from_utf8()
				print("[NetworkManager] NPC #%d disse: \"%s\"" % [npc_id, text])
				npc_spoke.emit(npc_id, text)
				tcp_rx_buffer = tcp_rx_buffer.slice(total_size)

			elif opcode == 0x33: # PLAYER_STATS (15 bytes)
				if tcp_rx_buffer.size() < 15:
					break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, 15)
				var pid: int = b.get_u32()
				var race: int = b.get_u8()
				var cls: int = b.get_u8()
				var hp: int = b.get_u16()
				var max_hp: int = b.get_u16()
				var stam: int = b.get_u16()
				var max_stam: int = b.get_u16()
				player_stats_received.emit(pid, race, cls, hp, max_hp, stam, max_stam)
				player_stats_updated.emit(pid, race, cls, hp, max_hp, stam, max_stam)
				tcp_rx_buffer = tcp_rx_buffer.slice(15)

			else:
				push_warning("[NetworkManager] Opcode TCP desconhecido: 0x%02x" % opcode)
				tcp_rx_buffer = tcp_rx_buffer.slice(1)

	elif status == StreamPeerTCP.STATUS_ERROR:
		if is_connected:
			is_connected = false
			push_warning("[NetworkManager] Erro na conexão TCP com o servidor.")

func _process_udp() -> void:
	while udp.get_available_packet_count() > 0:
		var packet: PackedByteArray = udp.get_packet()
		if packet.size() < 2:
			continue

		var buffer := StreamPeerBuffer.new()
		buffer.big_endian = false
		buffer.data_array = packet

		var opcode: int = buffer.get_u8()
		if opcode == 0x11: # WORLD_SNAPSHOT (30 Hz)
			if packet.size() < 6:
				continue
			var _server_tick: int = buffer.get_u32()
			var player_count: int = buffer.get_u8()
			var players_dict: Dictionary = {}

			for i in range(player_count):
				if buffer.get_available_bytes() < 20:
					break
				var pid: int = buffer.get_u32()
				var px: float = buffer.get_float()
				var py: float = buffer.get_float()
				var pz: float = buffer.get_float()
				var ry: float = buffer.get_float()

				players_dict[pid] = {
					"id": pid,
					"position": Vector3(px, py, pz),
					"rotation_y": ry
				}

			world_state_received.emit(players_dict)

		elif opcode == 0x12: # NPC_SNAPSHOT (30 Hz)
			var npc_count: int = buffer.get_u8()
			var npcs_dict: Dictionary = {}

			for i in range(npc_count):
				if buffer.get_available_bytes() < 21:
					break
				var nid: int = buffer.get_u32()
				var px: float = buffer.get_float()
				var py: float = buffer.get_float()
				var pz: float = buffer.get_float()
				var ry: float = buffer.get_float()
				var state: int = buffer.get_u8()

				npcs_dict[nid] = {
					"id": nid,
					"position": Vector3(px, py, pz),
					"rotation_y": ry,
					"state": state
				}

			npc_state_received.emit(npcs_dict)

		elif opcode == 0x13: # WORLD_TIME (5 bytes)
			if packet.size() < 5:
				continue
			var hour: int = buffer.get_u8()
			var minute: int = buffer.get_u8()
			var moon: int = buffer.get_u8()
			var weather: int = buffer.get_u8()
			world_time_updated.emit(hour, minute, moon, weather)

		elif opcode == 0x32: # COMBAT_EVENT (17 bytes)
			if packet.size() < 17:
				continue
			var attacker_id: int = buffer.get_u32()
			var target_id: int = buffer.get_u32()
			var action_type: int = buffer.get_u8()
			var damage: int = buffer.get_u16()
			var is_crit: int = buffer.get_u8()
			var target_hp: int = buffer.get_u16()
			var target_max_hp: int = buffer.get_u16()
			combat_event_received.emit(attacker_id, target_id, action_type, damage, is_crit, target_hp, target_max_hp)

		elif opcode == 0x33: # PLAYER_STATS (15 bytes)
			if packet.size() < 15:
				continue
			var pid: int = buffer.get_u32()
			var race: int = buffer.get_u8()
			var cls: int = buffer.get_u8()
			var hp: int = buffer.get_u16()
			var max_hp: int = buffer.get_u16()
			var stam: int = buffer.get_u16()
			var max_stam: int = buffer.get_u16()
			player_stats_received.emit(pid, race, cls, hp, max_hp, stam, max_stam)
			player_stats_updated.emit(pid, race, cls, hp, max_hp, stam, max_stam)

		elif opcode == 0x14: # MOB_SNAPSHOT (30 Hz)
			if buffer.get_available_bytes() < 1:
				continue
			var mob_count: int = buffer.get_u8()
			var mobs_dict: Dictionary = {}

			for i in range(mob_count):
				if buffer.get_available_bytes() < 26:
					break
				var mid: int = buffer.get_u32()
				var mtype: int = buffer.get_u8()
				var state: int = buffer.get_u8()
				var px: float = buffer.get_float()
				var py: float = buffer.get_float()
				var pz: float = buffer.get_float()
				var ry: float = buffer.get_float()
				var hp: int = buffer.get_u16()
				var max_hp: int = buffer.get_u16()

				mobs_dict[mid] = {
					"id": mid,
					"type": mtype,
					"state": state,
					"position": Vector3(px, py, pz),
					"rotation_y": ry,
					"hp": hp,
					"max_hp": max_hp
				}

			mob_state_received.emit(mobs_dict)

		elif opcode == 0x34: # AOE_TELEGRAPH (19 bytes)
			if packet.size() < 19:
				continue
			var source_id: int = buffer.get_u32()
			var px: float = buffer.get_float()
			var pz: float = buffer.get_float()
			var radius: float = buffer.get_float()
			var duration_ms: int = buffer.get_u16()

			aoe_telegraph_received.emit(source_id, px, pz, radius, duration_ms)

		elif opcode == 0x35: # PROJECTILE_SPAWN (38 bytes)
			if packet.size() < 38:
				continue
			var proj_id: int = buffer.get_u32()
			var owner_id: int = buffer.get_u32()
			var proj_type: int = buffer.get_u8()
			var sx: float = buffer.get_float()
			var sy: float = buffer.get_float()
			var sz: float = buffer.get_float()
			var dir_x: float = buffer.get_float()
			var dir_z: float = buffer.get_float()
			var speed: float = buffer.get_float()
			var max_range: float = buffer.get_float()

			projectile_spawned.emit(proj_id, owner_id, proj_type, Vector3(sx, sy, sz), Vector2(dir_x, dir_z), speed, max_range)

# send_player_move empacota os 25 bytes do pacote 0x10 e transmite via UDP
func send_player_move(pos: Vector3, rot_y: float) -> void:
	if my_player_id == 0:
		return

	seq += 1
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x10) # Opcode PLAYER_MOVE
	buffer.put_u32(my_player_id)
	buffer.put_u32(seq)
	buffer.put_float(pos.x)
	buffer.put_float(pos.y)
	buffer.put_float(pos.z)
	buffer.put_float(rot_y)

	udp.put_packet(buffer.data_array)

# send_player_interact envia o pacote TCP 0x20 para interagir com um NPC alvo
func send_player_interact(target_npc_id: int) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x20) # PLAYER_INTERACT (9 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u32(target_npc_id)

	tcp.put_data(buffer.data_array)

# send_world_control envia o pacote TCP 0x22 (DEV_WORLD_CONTROL: 3 bytes)
func send_world_control(cmd_type: int, val: int) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x22) # DEV_WORLD_CONTROL (3 bytes)
	buffer.put_u8(cmd_type)
	buffer.put_u8(val)

	tcp.put_data(buffer.data_array)

# send_skip_time avança horas (F6) chamando send_world_control(1, hours)
func send_skip_time(hours: int = 6) -> void:
	send_world_control(1, hours)

# send_cycle_moon cicla as 10 fases da lua (F7) chamando send_world_control(2, 1)
func send_cycle_moon() -> void:
	send_world_control(2, 1)

# send_cycle_weather cicla os 4 climas (F8) chamando send_world_control(3, 1)
func send_cycle_weather() -> void:
	send_world_control(3, 1)

# send_select_identity envia o pacote TCP 0x30 para definir Raça e Classe
func send_select_identity(race_id: int, class_id: int) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x30) # SELECT_IDENTITY (7 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u8(race_id)
	buffer.put_u8(class_id)

	tcp.put_data(buffer.data_array)

# send_player_action transmite a intenção de combate via UDP (0x31: 14 bytes)
func send_player_action(action_type: int, aim_dir: Vector3) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x31) # PLAYER_ACTION (14 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u8(action_type)
	buffer.put_float(aim_dir.x)
	buffer.put_float(aim_dir.z)

	udp.put_packet(buffer.data_array)
