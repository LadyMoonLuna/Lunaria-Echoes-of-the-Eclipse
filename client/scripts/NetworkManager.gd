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
signal player_stats_full_received(player_id: int, race_id: int, class_id: int, class_tier: int, level: int, hp: int, max_hp: int, stamina: int, max_stamina: int, buff_active: int)
signal player_attributes_received(player_id: int, xp: int, next_level_xp: int, stat_points: int, str_stat: int, dex_stat: int, con_stat: int, agi_stat: int, int_stat: int, spi_stat: int, mas_stat: int, lck_stat: int)
signal inventory_updated(equipped_slots_array: Array, items_array: Array)
signal player_respawn_received(player_id: int, respawn_pos: Vector3)
signal player_respawned(player_id: int, pos_x: float, pos_y: float, pos_z: float)
signal mob_state_received(mobs_dict: Dictionary)
signal aoe_telegraph_received(source_id: int, pos_x: float, pos_z: float, radius: float, duration_ms: int)
signal projectile_spawned(proj_id: int, owner_id: int, proj_type: int, start_pos: Vector3, dir_xz: Vector2, speed: float, max_range: float)
signal evolution_offer_received(offer_type: int, option_a: int, option_b: int)
signal dev_drop_rates_received(report_text: String)
signal corpse_snapshot_received(corpses_dict: Dictionary)
signal open_autopsy_ui_received(corpse_id: int, mob_type: int, difficulty_seed: int, organs: Array)

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

			elif opcode == 0x33: # PLAYER_STATS (31 bytes, 18 bytes ou 15 bytes)
				var expected_len: int = 31
				if tcp_rx_buffer.size() < 31:
					if tcp_rx_buffer.size() >= 18:
						expected_len = 18
					elif tcp_rx_buffer.size() >= 15:
						expected_len = 15
					else:
						break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, expected_len)
				var pid: int = b.get_u32()
				var race: int = b.get_u8()
				var cls: int = b.get_u8()
				var tier: int = 1
				var lvl: int = 1
				var hp: int = 0
				var max_hp: int = 0
				var stam: int = 0
				var max_stam: int = 0
				var buff: int = 0
				var xp: int = 0
				var next_xp: int = 100
				var stat_pts: int = 0
				var str_stat: int = 10
				var dex_stat: int = 10
				var con_stat: int = 10
				var agi_stat: int = 10
				var int_stat: int = 10
				var spi_stat: int = 10
				var mas_stat: int = 10
				var lck_stat: int = 10
				if expected_len >= 18:
					tier = b.get_u8()
					lvl = b.get_u8()
					hp = b.get_u16()
					max_hp = b.get_u16()
					stam = b.get_u16()
					max_stam = b.get_u16()
					buff = b.get_u8()
				else:
					hp = b.get_u16()
					max_hp = b.get_u16()
					stam = b.get_u16()
					max_stam = b.get_u16()
				if expected_len >= 31:
					xp = b.get_u16()
					next_xp = b.get_u16()
					stat_pts = b.get_u8()
					str_stat = b.get_u8()
					dex_stat = b.get_u8()
					con_stat = b.get_u8()
					agi_stat = b.get_u8()
					int_stat = b.get_u8()
					spi_stat = b.get_u8()
					mas_stat = b.get_u8()
					lck_stat = b.get_u8()
				player_stats_received.emit(pid, race, cls, hp, max_hp, stam, max_stam)
				player_stats_updated.emit(pid, race, cls, hp, max_hp, stam, max_stam)
				player_stats_full_received.emit(pid, race, cls, tier, lvl, hp, max_hp, stam, max_stam, buff)
				player_attributes_received.emit(pid, xp, next_xp, stat_pts, str_stat, dex_stat, con_stat, agi_stat, int_stat, spi_stat, mas_stat, lck_stat)
				tcp_rx_buffer = tcp_rx_buffer.slice(expected_len)

			elif opcode == 0x38: # INVENTORY_SYNC (Header 14 bytes: opcode + 12 equipped_slots + slot_count, then count * 2)
				if tcp_rx_buffer.size() < 14:
					break
				var equipped_slots: Array = []
				for i in range(12):
					equipped_slots.append(tcp_rx_buffer[1 + i])
				var slot_count: int = tcp_rx_buffer[13]
				var total_size: int = 14 + slot_count * 2
				if tcp_rx_buffer.size() < total_size:
					break
				var items_array: Array = []
				var offset: int = 14
				for i in range(slot_count):
					var item_id: int = tcp_rx_buffer[offset]
					var qty: int = tcp_rx_buffer[offset + 1]
					items_array.append({"id": item_id, "quantity": qty})
					offset += 2
				inventory_updated.emit(equipped_slots, items_array)
				tcp_rx_buffer = tcp_rx_buffer.slice(total_size)

			elif opcode == 0x36: # PLAYER_RESPAWN (17 bytes)
				if tcp_rx_buffer.size() < 17:
					break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, 17)
				var pid: int = b.get_u32()
				var px: float = b.get_float()
				var py: float = b.get_float()
				var pz: float = b.get_float()
				player_respawn_received.emit(pid, Vector3(px, py, pz))
				player_respawned.emit(pid, px, py, pz)
				tcp_rx_buffer = tcp_rx_buffer.slice(17)

			elif opcode == 0x3A: # DEV_GET_DROP_RATES (3 bytes header: opcode + len_u16 + report_string)
				if tcp_rx_buffer.size() < 3:
					break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, 3)
				var msg_len = b.get_u16()
				var total_size = 3 + msg_len
				if tcp_rx_buffer.size() < total_size:
					break
				var msg_bytes = tcp_rx_buffer.slice(3, total_size)
				var text = msg_bytes.get_string_from_utf8()
				print("[NetworkManager] DEV_GET_DROP_RATES:\n%s" % text)
				dev_drop_rates_received.emit(text)
				tcp_rx_buffer = tcp_rx_buffer.slice(total_size)

			elif opcode == 0x3C: # OPEN_AUTOPSY_UI (Header 11 bytes + organs * 5)
				if tcp_rx_buffer.size() < 11:
					break
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(1, 11)
				var corpse_id: int = b.get_u32()
				var mob_type: int = b.get_u8()
				var seed: int = b.get_u32()
				var organ_count: int = b.get_u8()
				var total_size: int = 11 + organ_count * 5
				if tcp_rx_buffer.size() < total_size:
					break
				var organs: Array = []
				var offset: int = 11
				for i in range(organ_count):
					var idx: int = tcp_rx_buffer[offset]
					var otype: int = tcp_rx_buffer[offset + 1]
					var item_reward: int = tcp_rx_buffer[offset + 2]
					var diff: int = tcp_rx_buffer[offset + 3]
					var qtier: int = tcp_rx_buffer[offset + 4]
					organs.append({
						"index": idx,
						"type": otype,
						"item_reward": item_reward,
						"difficulty": diff,
						"quality_tier": qtier
					})
					offset += 5
				print("[NetworkManager] 0x3C OPEN_AUTOPSY_UI recebido: Corpse #%d, MobType %d, %d órgãos" % [corpse_id, mob_type, organ_count])
				open_autopsy_ui_received.emit(corpse_id, mob_type, seed, organs)
				tcp_rx_buffer = tcp_rx_buffer.slice(total_size)

			elif opcode == 0x3E: # CORPSE_SNAPSHOT (Header 2 bytes + count * 28)
				if tcp_rx_buffer.size() < 2:
					break
				var corpse_count: int = tcp_rx_buffer[1]
				var total_size: int = 2 + corpse_count * 28
				if tcp_rx_buffer.size() < total_size:
					break
				var corpses_dict: Dictionary = {}
				var b := StreamPeerBuffer.new()
				b.big_endian = false
				b.data_array = tcp_rx_buffer.slice(2, total_size)
				for i in range(corpse_count):
					var cid: int = b.get_u32()
					var mid: int = b.get_u32()
					var mtype: int = b.get_u8()
					var px: float = b.get_float()
					var py: float = b.get_float()
					var pz: float = b.get_float()
					var ry: float = b.get_float()
					var is_looted: bool = (b.get_u8() != 0)
					var rem_sec: int = b.get_u16()
					corpses_dict[cid] = {
						"corpse_id": cid,
						"mob_id": mid,
						"mob_type": mtype,
						"position": Vector3(px, py, pz),
						"rotation_y": ry,
						"is_looted": is_looted,
						"remaining_sec": rem_sec
					}
				corpse_snapshot_received.emit(corpses_dict)
				tcp_rx_buffer = tcp_rx_buffer.slice(total_size)

			elif opcode == 0x40: # EVOLUTION_OFFER (4 bytes: opcode, offer_type, opt_a, opt_b)
				if tcp_rx_buffer.size() < 4:
					break
				var offer_type: int = tcp_rx_buffer[1]
				var opt_a: int = tcp_rx_buffer[2]
				var opt_b: int = tcp_rx_buffer[3]
				print("[NetworkManager] 0x40 EVOLUTION_OFFER recebido! Tipo: %d, Opção A: %d, Opção B: %d" % [offer_type, opt_a, opt_b])
				evolution_offer_received.emit(offer_type, opt_a, opt_b)
				tcp_rx_buffer = tcp_rx_buffer.slice(4)

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

		elif opcode == 0x33: # PLAYER_STATS (31 bytes, 18 bytes ou legado 15 bytes)
			if packet.size() < 15:
				continue
			var pid: int = buffer.get_u32()
			var race: int = buffer.get_u8()
			var cls: int = buffer.get_u8()
			var tier: int = 1
			var lvl: int = 1
			var hp: int = 0
			var max_hp: int = 0
			var stam: int = 0
			var max_stam: int = 0
			var buff: int = 0
			var xp: int = 0
			var next_xp: int = 100
			var stat_pts: int = 0
			var str_stat: int = 10
			var dex_stat: int = 10
			var con_stat: int = 10
			var agi_stat: int = 10
			var int_stat: int = 10
			var spi_stat: int = 10
			var mas_stat: int = 10
			var lck_stat: int = 10
			if packet.size() >= 18:
				tier = buffer.get_u8()
				lvl = buffer.get_u8()
				hp = buffer.get_u16()
				max_hp = buffer.get_u16()
				stam = buffer.get_u16()
				max_stam = buffer.get_u16()
				buff = buffer.get_u8()
			else:
				hp = buffer.get_u16()
				max_hp = buffer.get_u16()
				stam = buffer.get_u16()
				max_stam = buffer.get_u16()
			if packet.size() >= 31:
				xp = buffer.get_u16()
				next_xp = buffer.get_u16()
				stat_pts = buffer.get_u8()
				str_stat = buffer.get_u8()
				dex_stat = buffer.get_u8()
				con_stat = buffer.get_u8()
				agi_stat = buffer.get_u8()
				int_stat = buffer.get_u8()
				spi_stat = buffer.get_u8()
				mas_stat = buffer.get_u8()
				lck_stat = buffer.get_u8()
			player_stats_received.emit(pid, race, cls, hp, max_hp, stam, max_stam)
			player_stats_updated.emit(pid, race, cls, hp, max_hp, stam, max_stam)
			player_stats_full_received.emit(pid, race, cls, tier, lvl, hp, max_hp, stam, max_stam, buff)
			player_attributes_received.emit(pid, xp, next_xp, stat_pts, str_stat, dex_stat, con_stat, agi_stat, int_stat, spi_stat, mas_stat, lck_stat)

		elif opcode == 0x36: # PLAYER_RESPAWN (17 bytes)
			if packet.size() < 17:
				continue
			var pid: int = buffer.get_u32()
			var px: float = buffer.get_float()
			var py: float = buffer.get_float()
			var pz: float = buffer.get_float()
			player_respawn_received.emit(pid, Vector3(px, py, pz))
			player_respawned.emit(pid, px, py, pz)

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

		elif opcode == 0x3E: # CORPSE_SNAPSHOT (Header 2 bytes + count * 28)
			if buffer.get_available_bytes() < 1:
				continue
			var corpse_count: int = buffer.get_u8()
			var corpses_dict: Dictionary = {}
			for i in range(corpse_count):
				if buffer.get_available_bytes() < 28:
					break
				var cid: int = buffer.get_u32()
				var mid: int = buffer.get_u32()
				var mtype: int = buffer.get_u8()
				var px: float = buffer.get_float()
				var py: float = buffer.get_float()
				var pz: float = buffer.get_float()
				var ry: float = buffer.get_float()
				var is_looted: bool = (buffer.get_u8() != 0)
				var rem_sec: int = buffer.get_u16()
				corpses_dict[cid] = {
					"corpse_id": cid,
					"mob_id": mid,
					"mob_type": mtype,
					"position": Vector3(px, py, pz),
					"rotation_y": ry,
					"is_looted": is_looted,
					"remaining_sec": rem_sec
				}
			corpse_snapshot_received.emit(corpses_dict)

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

# send_select_identity envia o pacote TCP 0x30 para definir Raça, Classe e Modo de Ação
func send_select_identity(race_id: int, class_id: int, action_mode: int = 0) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x30) # SELECT_IDENTITY (8 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u8(race_id)
	buffer.put_u8(class_id)
	buffer.put_u8(action_mode)

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

# send_allocate_stat envia o pacote TCP 0x37 para alocar 1 ponto no atributo (1..8)
func send_allocate_stat(stat_id: int) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x37) # ALLOCATE_STAT (6 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u8(stat_id)

	tcp.put_data(buffer.data_array)

# send_use_item envia o pacote TCP 0x39 para usar consumível ou equipar armadura/acessório
func send_use_item(item_id: int) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x39) # USE_OR_EQUIP_ITEM (6 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u8(item_id)

	tcp.put_data(buffer.data_array)

# send_evolution_choice envia a decisão de evolução (0x40: 4 bytes)
func send_evolution_choice(offer_type: int, chosen_id: int) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x40) # EVOLUTION_OFFER (4 bytes)
	buffer.put_u8(offer_type)
	buffer.put_u8(chosen_id)
	buffer.put_u8(0)

	tcp.put_data(buffer.data_array)

# send_dev_level_up comanda avanço de níveis no servidor (F8/Dev)
func send_dev_level_up(levels: int = 10) -> void:
	send_world_control(4, levels)

# send_dev_get_drop_rates solicita a tabela de taxas de drop completa ao servidor (0x3A: 5 bytes)
func send_dev_get_drop_rates() -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x3A) # DEV_GET_DROP_RATES (5 bytes)
	buffer.put_u32(my_player_id)

	tcp.put_data(buffer.data_array)
	print("[NetworkManager] 0x3A DEV_GET_DROP_RATES solicitado ao servidor.")

# send_interact_corpse envia o pacote TCP 0x3B para inspecionar um cadáver no chão (9 bytes)
func send_interact_corpse(corpse_id: int) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x3B) # INTERACT_CORPSE (9 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u32(corpse_id)

	tcp.put_data(buffer.data_array)
	print("[NetworkManager] 0x3B INTERACT_CORPSE enviado para cadáver #%d" % corpse_id)

# send_submit_autopsy_result envia o pacote TCP 0x3D com o resultado do mini-game (11 bytes)
func send_submit_autopsy_result(corpse_id: int, organ_index: int, result_tier: int) -> void:
	if my_player_id == 0:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u8(0x3D) # SUBMIT_AUTOPSY_RESULT (11 bytes)
	buffer.put_u32(my_player_id)
	buffer.put_u32(corpse_id)
	buffer.put_u8(organ_index)
	buffer.put_u8(result_tier)

	tcp.put_data(buffer.data_array)
	print("[NetworkManager] 0x3D SUBMIT_AUTOPSY_RESULT enviado: Corpse #%d, Órgão #%d, Tier %d" % [corpse_id, organ_index, result_tier])
