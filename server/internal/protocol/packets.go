package protocol

import (
	"encoding/binary"
	"errors"
	"math"
)

// Opcodes dos pacotes dos Marcos 1 e 2
const (
	// Marco 1
	PacketTypeWelcome            uint8 = 0x01
	PacketTypePlayerDisconnected uint8 = 0x02
	PacketTypePlayerMove         uint8 = 0x10
	PacketTypeWorldSnapshot      uint8 = 0x11

	// Marco 2
	PacketTypeNPCSnapshot      uint8 = 0x12
	PacketTypeWorldTime        uint8 = 0x13
	PacketTypePlayerInteract   uint8 = 0x20
	PacketTypeNPCSay           uint8 = 0x21
	PacketTypeDevWorldControl  uint8 = 0x22
	PacketTypeDevSkipTime      uint8 = 0x22 // Alias retrocompatível

	// Marco 3
	PacketTypeSelectIdentity uint8 = 0x30
	PacketTypePlayerAction   uint8 = 0x31
	PacketTypeCombatEvent    uint8 = 0x32
	PacketTypePlayerStats    uint8 = 0x33

	// Marco 4
	PacketTypeMobSnapshot     uint8 = 0x14
	PacketTypeAOETelegraph    uint8 = 0x34
	PacketTypeProjectileSpawn uint8 = 0x35
)

// Tipos de Projéteis 3D
const (
	ProjTypePhysicalArrow uint8 = 1 // Flecha Física (Batedor - Ataque Básico)
	ProjTypePiercingArrow uint8 = 2 // Flecha Perfurante (Batedor - Skill Q)
	ProjTypeArcaneOrb     uint8 = 3 // Orbe Arcano (Iniciado - Ataque Básico)
	ProjTypeElementalComet uint8 = 4 // Cometa Elemental (Iniciado - Skill Q)
)

// Tipos de Mobs do Marco 4
const (
	MobTypeMistWolf         uint8 = 1 // Lobo da Bruma
	MobTypeOutcastRaider    uint8 = 2 // Saqueador Deserdado
	MobTypeVigilCrossbowman uint8 = 3 // Besteiro da Vigília
	MobTypeEclipseAcolyte   uint8 = 4 // Acólito do Eclipse
	MobTypeIronEnforcer     uint8 = 5 // Executor de Ferro
)

// Estados de Mobs do Marco 4
const (
	MobStatePatrolIdle uint8 = 0 // Patrulha/Idle
	MobStateChasing    uint8 = 1 // Perseguindo
	MobStateAttacking  uint8 = 2 // Atacando/Carregando
	MobStateBlocking       uint8 = 3 // Bloqueando (Escudo)
	MobStateFleeing        uint8 = 4 // Fugindo/Atordoado
	MobStateFleeingStunned uint8 = 4 // Fugindo/Atordoado/Vulnerável
	MobStateDead           uint8 = 5 // Morto
)

// Identificadores de Raças do Marco 3
const (
	RaceValerian uint8 = 1 // Valeriano
	RaceNoctari  uint8 = 2 // Noctari
	RaceKharad   uint8 = 3 // Kharad
	RaceVarkai   uint8 = 4 // Varkai
	RaceDhampir  uint8 = 5 // Dhampir (Secreta)
)

// Identificadores de Classes do Marco 3
const (
	ClassSwordsman uint8 = 1 // Espadachim
	ClassScout     uint8 = 2 // Batedor
	ClassInitiate  uint8 = 3 // Iniciado
	ClassAcolyte   uint8 = 4 // Acólito
)

// Identificadores de Ações de Combate do Marco 3
const (
	ActionBasicAttack   uint8 = 1 // Ataque Básico
	ActionDodgeRoll     uint8 = 2 // Esquiva (Dodge Roll)
	ActionSpecialSkill  uint8 = 3 // Habilidade Especial (Tecla Q)
)

// Constantes de tamanho dos pacotes (em bytes)
const (
	WelcomePacketSize            = 5
	PlayerDisconnectedPacketSize = 5
	PlayerMovePacketSize         = 25
	WorldSnapshotHeaderSize      = 6
	PlayerSnapshotEntrySize      = 20

	NPCSnapshotHeaderSize    = 2
	NPCSnapshotEntrySize     = 21 // uint32 (4) + 4x float32 (16) + uint8 (1) = 21 bytes
	WorldTimePacketSize      = 5  // uint8 (1) + uint8 (1) + uint8 (1) + uint8 (1) + uint8 (1) = 5 bytes
	PlayerInteractPacketSize = 9  // uint8 (1) + uint32 (4) + uint32 (4) = 9 bytes
	NPCSayHeaderSize         = 7  // uint8 (1) + uint32 (4) + uint16 (2) = 7 bytes
	DevWorldControlPacketSize = 3 // uint8 (1) + uint8 (1) + uint8 (1) = 3 bytes
	DevSkipTimePacketSize     = 3 // Alias

	SelectIdentityPacketSize = 7  // uint8 (1) + uint32 (4) + uint8 (1) + uint8 (1) = 7 bytes
	PlayerActionPacketSize   = 14 // uint8 (1) + uint32 (4) + uint8 (1) + 2x float32 (8) = 14 bytes
	CombatEventPacketSize    = 17 // uint8 (1) + 2x uint32 (8) + uint8 (1) + uint16 (2) + uint8 (1) + 2x uint16 (4) = 17 bytes
	PlayerStatsPacketSize    = 15 // uint8 (1) + uint32 (4) + 2x uint8 (2) + 4x uint16 (8) = 15 bytes

	MobSnapshotHeaderSize  = 2  // uint8 (1) + uint8 (1) = 2 bytes
	MobSnapshotEntrySize   = 26 // uint32 (4) + 2x uint8 (2) + 4x float32 (16) + 2x uint16 (4) = 26 bytes
	AOETelegraphPacketSize = 19 // uint8 (1) + uint32 (4) + 3x float32 (12) + uint16 (2) = 19 bytes
)

var (
	ErrInvalidPacketSize = errors.New("tamanho de pacote binario invalido")
	ErrInvalidPacketType = errors.New("tipo de opcode de pacote invalido")
)

// --- 0x01: WELCOME (TCP: Server -> Client) ---

// SerializeWelcome cria o payload binário do pacote WELCOME (5 bytes) em Little Endian.
func SerializeWelcome(playerID uint32) [WelcomePacketSize]byte {
	var b [WelcomePacketSize]byte
	b[0] = PacketTypeWelcome
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	return b
}

// DeserializeWelcome decodifica um pacote WELCOME a partir de um buffer de bytes.
func DeserializeWelcome(data []byte) (uint32, error) {
	if len(data) < WelcomePacketSize {
		return 0, ErrInvalidPacketSize
	}
	if data[0] != PacketTypeWelcome {
		return 0, ErrInvalidPacketType
	}
	return binary.LittleEndian.Uint32(data[1:5]), nil
}

// --- 0x02: PLAYER_DISCONNECTED (TCP: Server -> Clients) ---

// SerializePlayerDisconnected cria o payload binário do pacote PLAYER_DISCONNECTED (5 bytes) em Little Endian.
func SerializePlayerDisconnected(playerID uint32) [PlayerDisconnectedPacketSize]byte {
	var b [PlayerDisconnectedPacketSize]byte
	b[0] = PacketTypePlayerDisconnected
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	return b
}

// DeserializePlayerDisconnected decodifica um pacote PLAYER_DISCONNECTED a partir de um buffer de bytes.
func DeserializePlayerDisconnected(data []byte) (uint32, error) {
	if len(data) < PlayerDisconnectedPacketSize {
		return 0, ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerDisconnected {
		return 0, ErrInvalidPacketType
	}
	return binary.LittleEndian.Uint32(data[1:5]), nil
}

// --- 0x10: PLAYER_MOVE (UDP: Client -> Server) ---

// PlayerMovePacket representa a intenção de movimento transmitida pelo cliente.
type PlayerMovePacket struct {
	PlayerID uint32
	Seq      uint32
	PosX     float32
	PosY     float32
	PosZ     float32
	RotY     float32
}

// SerializePlayerMove cria o payload de 25 bytes do pacote PLAYER_MOVE.
func SerializePlayerMove(pkt PlayerMovePacket) [PlayerMovePacketSize]byte {
	var b [PlayerMovePacketSize]byte
	b[0] = PacketTypePlayerMove
	binary.LittleEndian.PutUint32(b[1:5], pkt.PlayerID)
	binary.LittleEndian.PutUint32(b[5:9], pkt.Seq)
	binary.LittleEndian.PutUint32(b[9:13], math.Float32bits(pkt.PosX))
	binary.LittleEndian.PutUint32(b[13:17], math.Float32bits(pkt.PosY))
	binary.LittleEndian.PutUint32(b[17:21], math.Float32bits(pkt.PosZ))
	binary.LittleEndian.PutUint32(b[21:25], math.Float32bits(pkt.RotY))
	return b
}

// DeserializePlayerMove faz o parse in-place para out sem alocações adicionais na heap.
func DeserializePlayerMove(data []byte, out *PlayerMovePacket) error {
	if len(data) < PlayerMovePacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerMove {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.Seq = binary.LittleEndian.Uint32(data[5:9])
	out.PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[9:13]))
	out.PosY = math.Float32frombits(binary.LittleEndian.Uint32(data[13:17]))
	out.PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[17:21]))
	out.RotY = math.Float32frombits(binary.LittleEndian.Uint32(data[21:25]))
	return nil
}

// --- 0x11: WORLD_SNAPSHOT (UDP: Server -> Clients) ---

// PlayerSnapshot representa a posição e rotação autoritativa de um jogador no snapshot.
type PlayerSnapshot struct {
	PlayerID uint32
	PosX     float32
	PosY     float32
	PosZ     float32
	RotY     float32
}

// WorldSnapshotPacket representa o pacote completo de snapshot do mundo a 30 Hz.
type WorldSnapshotPacket struct {
	ServerTick  uint32
	PlayerCount uint8
	Players     []PlayerSnapshot
}

// SerializeWorldSnapshotInto grava o snapshot no buffer fornecido e retorna o número de bytes gravados.
func SerializeWorldSnapshotInto(buf []byte, serverTick uint32, players []PlayerSnapshot) int {
	count := len(players)
	if count > 255 {
		count = 255
	}
	totalSize := WorldSnapshotHeaderSize + (count * PlayerSnapshotEntrySize)
	if len(buf) < totalSize {
		return 0
	}

	buf[0] = PacketTypeWorldSnapshot
	binary.LittleEndian.PutUint32(buf[1:5], serverTick)
	buf[5] = uint8(count)

	offset := WorldSnapshotHeaderSize
	for i := 0; i < count; i++ {
		p := &players[i]
		binary.LittleEndian.PutUint32(buf[offset:offset+4], p.PlayerID)
		binary.LittleEndian.PutUint32(buf[offset+4:offset+8], math.Float32bits(p.PosX))
		binary.LittleEndian.PutUint32(buf[offset+8:offset+12], math.Float32bits(p.PosY))
		binary.LittleEndian.PutUint32(buf[offset+12:offset+16], math.Float32bits(p.PosZ))
		binary.LittleEndian.PutUint32(buf[offset+16:offset+20], math.Float32bits(p.RotY))
		offset += PlayerSnapshotEntrySize
	}
	return totalSize
}

// SerializeWorldSnapshot aloca e retorna o slice de bytes com o snapshot serializado.
func SerializeWorldSnapshot(serverTick uint32, players []PlayerSnapshot) []byte {
	size := WorldSnapshotHeaderSize + (len(players) * PlayerSnapshotEntrySize)
	buf := make([]byte, size)
	SerializeWorldSnapshotInto(buf, serverTick, players)
	return buf
}

// DeserializeWorldSnapshot decodifica o snapshot do mundo a partir de bytes.
func DeserializeWorldSnapshot(data []byte, out *WorldSnapshotPacket) error {
	if len(data) < WorldSnapshotHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeWorldSnapshot {
		return ErrInvalidPacketType
	}

	out.ServerTick = binary.LittleEndian.Uint32(data[1:5])
	out.PlayerCount = data[5]

	expectedSize := WorldSnapshotHeaderSize + int(out.PlayerCount)*PlayerSnapshotEntrySize
	if len(data) < expectedSize {
		return ErrInvalidPacketSize
	}

	if cap(out.Players) >= int(out.PlayerCount) {
		out.Players = out.Players[:out.PlayerCount]
	} else {
		out.Players = make([]PlayerSnapshot, out.PlayerCount)
	}

	offset := WorldSnapshotHeaderSize
	for i := 0; i < int(out.PlayerCount); i++ {
		out.Players[i].PlayerID = binary.LittleEndian.Uint32(data[offset : offset+4])
		out.Players[i].PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+4 : offset+8]))
		out.Players[i].PosY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+8 : offset+12]))
		out.Players[i].PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+12 : offset+16]))
		out.Players[i].RotY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+16 : offset+20]))
		offset += PlayerSnapshotEntrySize
	}
	return nil
}

// --- 0x12: NPC_SNAPSHOT (UDP: Server -> Clients) ---

// NPCSnapshot representa os dados de replicação autoritativa de um NPC no mundo.
type NPCSnapshot struct {
	NPCID uint32
	PosX  float32
	PosY  float32
	PosZ  float32
	RotY  float32
	State uint8
}

// NPCSnapshotPacket representa o pacote completo de snapshot dos NPCs ativos.
type NPCSnapshotPacket struct {
	NPCCount uint8
	NPCs     []NPCSnapshot
}

// SerializeNPCSnapshotInto grava o snapshot dos NPCs no buffer fornecido.
func SerializeNPCSnapshotInto(buf []byte, npcs []NPCSnapshot) int {
	count := len(npcs)
	if count > 255 {
		count = 255
	}
	totalSize := NPCSnapshotHeaderSize + (count * NPCSnapshotEntrySize)
	if len(buf) < totalSize {
		return 0
	}

	buf[0] = PacketTypeNPCSnapshot
	buf[1] = uint8(count)

	offset := NPCSnapshotHeaderSize
	for i := 0; i < count; i++ {
		npc := &npcs[i]
		binary.LittleEndian.PutUint32(buf[offset:offset+4], npc.NPCID)
		binary.LittleEndian.PutUint32(buf[offset+4:offset+8], math.Float32bits(npc.PosX))
		binary.LittleEndian.PutUint32(buf[offset+8:offset+12], math.Float32bits(npc.PosY))
		binary.LittleEndian.PutUint32(buf[offset+12:offset+16], math.Float32bits(npc.PosZ))
		binary.LittleEndian.PutUint32(buf[offset+16:offset+20], math.Float32bits(npc.RotY))
		buf[offset+20] = npc.State
		offset += NPCSnapshotEntrySize
	}
	return totalSize
}

// SerializeNPCSnapshot cria e aloca um slice com o snapshot de NPCs.
func SerializeNPCSnapshot(npcs []NPCSnapshot) []byte {
	size := NPCSnapshotHeaderSize + (len(npcs) * NPCSnapshotEntrySize)
	buf := make([]byte, size)
	SerializeNPCSnapshotInto(buf, npcs)
	return buf
}

// DeserializeNPCSnapshot decodifica os dados de NPC_SNAPSHOT do buffer.
func DeserializeNPCSnapshot(data []byte, out *NPCSnapshotPacket) error {
	if len(data) < NPCSnapshotHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeNPCSnapshot {
		return ErrInvalidPacketType
	}

	out.NPCCount = data[1]
	expectedSize := NPCSnapshotHeaderSize + int(out.NPCCount)*NPCSnapshotEntrySize
	if len(data) < expectedSize {
		return ErrInvalidPacketSize
	}

	if cap(out.NPCs) >= int(out.NPCCount) {
		out.NPCs = out.NPCs[:out.NPCCount]
	} else {
		out.NPCs = make([]NPCSnapshot, out.NPCCount)
	}

	offset := NPCSnapshotHeaderSize
	for i := 0; i < int(out.NPCCount); i++ {
		out.NPCs[i].NPCID = binary.LittleEndian.Uint32(data[offset : offset+4])
		out.NPCs[i].PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+4 : offset+8]))
		out.NPCs[i].PosY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+8 : offset+12]))
		out.NPCs[i].PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+12 : offset+16]))
		out.NPCs[i].RotY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+16 : offset+20]))
		out.NPCs[i].State = data[offset+20]
		offset += NPCSnapshotEntrySize
	}
	return nil
}

// --- 0x20: PLAYER_INTERACT (TCP: Client -> Server) ---

// PlayerInteractPacket representa o comando enviado quando o jogador interage com um NPC.
type PlayerInteractPacket struct {
	PlayerID    uint32
	TargetNPCID uint32
}

// SerializePlayerInteract cria o payload de 9 bytes de PLAYER_INTERACT.
func SerializePlayerInteract(playerID, targetNPCID uint32) [PlayerInteractPacketSize]byte {
	var b [PlayerInteractPacketSize]byte
	b[0] = PacketTypePlayerInteract
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	binary.LittleEndian.PutUint32(b[5:9], targetNPCID)
	return b
}

// DeserializePlayerInteract decodifica o pacote PLAYER_INTERACT (9 bytes).
func DeserializePlayerInteract(data []byte, out *PlayerInteractPacket) error {
	if len(data) < PlayerInteractPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerInteract {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.TargetNPCID = binary.LittleEndian.Uint32(data[5:9])
	return nil
}

// --- 0x21: NPC_SAY (TCP: Server -> Clients) ---

// NPCSayPacket representa uma fala emitida por um NPC para os jogadores.
type NPCSayPacket struct {
	NPCID      uint32
	MessageLen uint16
	Message    string
}

// SerializeNPCSay cria o payload binário completo de NPC_SAY.
func SerializeNPCSay(npcID uint32, message string) []byte {
	msgBytes := []byte(message)
	msgLen := len(msgBytes)
	if msgLen > 65535 {
		msgLen = 65535
		msgBytes = msgBytes[:65535]
	}

	totalSize := NPCSayHeaderSize + msgLen
	buf := make([]byte, totalSize)
	buf[0] = PacketTypeNPCSay
	binary.LittleEndian.PutUint32(buf[1:5], npcID)
	binary.LittleEndian.PutUint16(buf[5:7], uint16(msgLen))
	copy(buf[7:], msgBytes)
	return buf
}

// DeserializeNPCSay decodifica o pacote NPC_SAY a partir de um buffer de bytes.
func DeserializeNPCSay(data []byte, out *NPCSayPacket) error {
	if len(data) < NPCSayHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeNPCSay {
		return ErrInvalidPacketType
	}

	out.NPCID = binary.LittleEndian.Uint32(data[1:5])
	out.MessageLen = binary.LittleEndian.Uint16(data[5:7])

	totalExpected := NPCSayHeaderSize + int(out.MessageLen)
	if len(data) < totalExpected {
		return ErrInvalidPacketSize
	}

	out.Message = string(data[7:totalExpected])
	return nil
}

// --- 0x13: WORLD_TIME (UDP/TCP: Server -> Clients, 5 bytes) ---

// WorldTimePacket representa a hora, o minuto, a fase lunar e o clima sincronizados do mundo.
type WorldTimePacket struct {
	WorldHour   uint8
	WorldMinute uint8
	MoonPhase   uint8
	WeatherType uint8
}

// SerializeWorldTime cria o payload de 5 bytes do pacote WORLD_TIME.
func SerializeWorldTime(hour, minute, moonPhase, weatherType uint8) [WorldTimePacketSize]byte {
	var b [WorldTimePacketSize]byte
	b[0] = PacketTypeWorldTime
	b[1] = hour
	b[2] = minute
	b[3] = moonPhase
	b[4] = weatherType
	return b
}

// DeserializeWorldTime decodifica o pacote WORLD_TIME (5 bytes).
func DeserializeWorldTime(data []byte, out *WorldTimePacket) error {
	if len(data) < WorldTimePacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeWorldTime {
		return ErrInvalidPacketType
	}
	out.WorldHour = data[1]
	out.WorldMinute = data[2]
	out.MoonPhase = data[3]
	out.WeatherType = data[4]
	return nil
}

// --- 0x22: DEV_WORLD_CONTROL (TCP: Client -> Server, 3 bytes) ---

// DevWorldControlPacket representa o comando de depuração para testes (F6=+Horas, F7=Fase Lua, F8=Clima).
type DevWorldControlPacket struct {
	CommandType uint8 // 1 = +Horas, 2 = Ciclar Fase Lua, 3 = Ciclar Clima
	Value       uint8
}

// DevSkipTimePacket mantém compatibilidade com nomes legados
type DevSkipTimePacket = DevWorldControlPacket

// SerializeDevWorldControl cria o payload de 3 bytes do pacote DEV_WORLD_CONTROL.
func SerializeDevWorldControl(cmdType, value uint8) [DevWorldControlPacketSize]byte {
	var b [DevWorldControlPacketSize]byte
	b[0] = PacketTypeDevWorldControl
	b[1] = cmdType
	b[2] = value
	return b
}

// SerializeDevSkipTime cria payload de 3 bytes (CommandType 1 = Avançar horas).
func SerializeDevSkipTime(hoursToAdd uint8) [DevSkipTimePacketSize]byte {
	return SerializeDevWorldControl(1, hoursToAdd)
}

// DeserializeDevWorldControl decodifica o pacote DEV_WORLD_CONTROL (3 bytes).
func DeserializeDevWorldControl(data []byte, out *DevWorldControlPacket) error {
	if len(data) < DevWorldControlPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeDevWorldControl {
		return ErrInvalidPacketType
	}
	out.CommandType = data[1]
	out.Value = data[2]
	return nil
}

// DeserializeDevSkipTime é um wrapper compatível para DeserializeDevWorldControl.
func DeserializeDevSkipTime(data []byte, out *DevSkipTimePacket) error {
	return DeserializeDevWorldControl(data, out)
}

// --- 0x30: SELECT_IDENTITY (TCP: Client -> Server, 7 bytes) ---

// SelectIdentityPacket representa a escolha de Raça e Classe do jogador.
type SelectIdentityPacket struct {
	PlayerID uint32
	RaceID   uint8
	ClassID  uint8
}

// SerializeSelectIdentity cria o payload de 7 bytes do pacote SELECT_IDENTITY.
func SerializeSelectIdentity(playerID uint32, raceID, classID uint8) [SelectIdentityPacketSize]byte {
	var b [SelectIdentityPacketSize]byte
	b[0] = PacketTypeSelectIdentity
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = raceID
	b[6] = classID
	return b
}

// DeserializeSelectIdentity decodifica o pacote SELECT_IDENTITY (7 bytes).
func DeserializeSelectIdentity(data []byte, out *SelectIdentityPacket) error {
	if len(data) < SelectIdentityPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeSelectIdentity {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.RaceID = data[5]
	out.ClassID = data[6]
	return nil
}

// --- 0x31: PLAYER_ACTION (UDP: Client -> Server, 14 bytes) ---

// PlayerActionPacket representa uma ação de combate físico disparada com mira.
type PlayerActionPacket struct {
	PlayerID   uint32
	ActionType uint8
	AimDirX    float32
	AimDirZ    float32
}

// SerializePlayerAction cria o payload de 14 bytes do pacote PLAYER_ACTION.
func SerializePlayerAction(playerID uint32, actionType uint8, aimX, aimZ float32) [PlayerActionPacketSize]byte {
	var b [PlayerActionPacketSize]byte
	b[0] = PacketTypePlayerAction
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = actionType
	binary.LittleEndian.PutUint32(b[6:10], math.Float32bits(aimX))
	binary.LittleEndian.PutUint32(b[10:14], math.Float32bits(aimZ))
	return b
}

// DeserializePlayerAction decodifica o pacote PLAYER_ACTION (14 bytes).
func DeserializePlayerAction(data []byte, out *PlayerActionPacket) error {
	if len(data) < PlayerActionPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerAction {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.ActionType = data[5]
	out.AimDirX = math.Float32frombits(binary.LittleEndian.Uint32(data[6:10]))
	out.AimDirZ = math.Float32frombits(binary.LittleEndian.Uint32(data[10:14]))
	return nil
}

// --- 0x32: COMBAT_EVENT (UDP: Server -> Clients, 17 bytes) ---

// CombatEventPacket representa o resultado autoritativo de um evento de dano ou habilidade.
type CombatEventPacket struct {
	AttackerID  uint32
	TargetID    uint32
	ActionType  uint8
	Damage      uint16
	IsCrit      uint8
	TargetHP    uint16
	TargetMaxHP uint16
}

// SerializeCombatEvent cria o payload de 17 bytes do pacote COMBAT_EVENT.
func SerializeCombatEvent(attackerID, targetID uint32, actionType uint8, damage uint16, isCrit uint8, targetHP, targetMaxHP uint16) [CombatEventPacketSize]byte {
	var b [CombatEventPacketSize]byte
	b[0] = PacketTypeCombatEvent
	binary.LittleEndian.PutUint32(b[1:5], attackerID)
	binary.LittleEndian.PutUint32(b[5:9], targetID)
	b[9] = actionType
	binary.LittleEndian.PutUint16(b[10:12], damage)
	b[12] = isCrit
	binary.LittleEndian.PutUint16(b[13:15], targetHP)
	binary.LittleEndian.PutUint16(b[15:17], targetMaxHP)
	return b
}

// DeserializeCombatEvent decodifica o pacote COMBAT_EVENT (17 bytes).
func DeserializeCombatEvent(data []byte, out *CombatEventPacket) error {
	if len(data) < CombatEventPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeCombatEvent {
		return ErrInvalidPacketType
	}
	out.AttackerID = binary.LittleEndian.Uint32(data[1:5])
	out.TargetID = binary.LittleEndian.Uint32(data[5:9])
	out.ActionType = data[9]
	out.Damage = binary.LittleEndian.Uint16(data[10:12])
	out.IsCrit = data[12]
	out.TargetHP = binary.LittleEndian.Uint16(data[13:15])
	out.TargetMaxHP = binary.LittleEndian.Uint16(data[15:17])
	return nil
}

// --- 0x33: PLAYER_STATS (UDP: Server -> Client, 15 bytes) ---

// PlayerStatsPacket representa a sincronização autoritativa dos status de sobrevivência do jogador.
type PlayerStatsPacket struct {
	PlayerID   uint32
	RaceID     uint8
	ClassID    uint8
	HP         uint16
	MaxHP      uint16
	Stamina    uint16
	MaxStamina uint16
}

// SerializePlayerStats cria o payload de 15 bytes do pacote PLAYER_STATS.
func SerializePlayerStats(playerID uint32, raceID, classID uint8, hp, maxHP, stamina, maxStamina uint16) [PlayerStatsPacketSize]byte {
	var b [PlayerStatsPacketSize]byte
	b[0] = PacketTypePlayerStats
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = raceID
	b[6] = classID
	binary.LittleEndian.PutUint16(b[7:9], hp)
	binary.LittleEndian.PutUint16(b[9:11], maxHP)
	binary.LittleEndian.PutUint16(b[11:13], stamina)
	binary.LittleEndian.PutUint16(b[13:15], maxStamina)
	return b
}

// DeserializePlayerStats decodifica o pacote PLAYER_STATS (15 bytes).
func DeserializePlayerStats(data []byte, out *PlayerStatsPacket) error {
	if len(data) < PlayerStatsPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerStats {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.RaceID = data[5]
	out.ClassID = data[6]
	out.HP = binary.LittleEndian.Uint16(data[7:9])
	out.MaxHP = binary.LittleEndian.Uint16(data[9:11])
	out.Stamina = binary.LittleEndian.Uint16(data[11:13])
	out.MaxStamina = binary.LittleEndian.Uint16(data[13:15])
	return nil
}

// --- 0x14: MOB_SNAPSHOT (UDP: Server -> Clients) ---

// MobSnapshot representa o estado de um monstro na transmissão periódica a 30 Hz.
type MobSnapshot struct {
	MobID   uint32
	MobType uint8
	State   uint8
	PosX    float32
	PosY    float32
	PosZ    float32
	RotY    float32
	HP      uint16
	MaxHP   uint16
}

// SerializeMobSnapshot cria o buffer completo do pacote MOB_SNAPSHOT.
func SerializeMobSnapshot(mobs []MobSnapshot) []byte {
	size := MobSnapshotHeaderSize + len(mobs)*MobSnapshotEntrySize
	buf := make([]byte, size)
	SerializeMobSnapshotInto(buf, mobs)
	return buf
}

// SerializeMobSnapshotInto serializa os dados de mobs diretamente no buffer fornecido.
func SerializeMobSnapshotInto(buf []byte, mobs []MobSnapshot) int {
	buf[0] = PacketTypeMobSnapshot
	buf[1] = uint8(len(mobs))
	offset := MobSnapshotHeaderSize

	for _, m := range mobs {
		binary.LittleEndian.PutUint32(buf[offset:offset+4], m.MobID)
		buf[offset+4] = m.MobType
		buf[offset+5] = m.State
		binary.LittleEndian.PutUint32(buf[offset+6:offset+10], math.Float32bits(m.PosX))
		binary.LittleEndian.PutUint32(buf[offset+10:offset+14], math.Float32bits(m.PosY))
		binary.LittleEndian.PutUint32(buf[offset+14:offset+18], math.Float32bits(m.PosZ))
		binary.LittleEndian.PutUint32(buf[offset+18:offset+22], math.Float32bits(m.RotY))
		binary.LittleEndian.PutUint16(buf[offset+22:offset+24], m.HP)
		binary.LittleEndian.PutUint16(buf[offset+24:offset+26], m.MaxHP)
		offset += MobSnapshotEntrySize
	}
	return offset
}

// DeserializeMobSnapshot decodifica um pacote MOB_SNAPSHOT.
func DeserializeMobSnapshot(data []byte) ([]MobSnapshot, error) {
	if len(data) < MobSnapshotHeaderSize {
		return nil, ErrInvalidPacketSize
	}
	if data[0] != PacketTypeMobSnapshot {
		return nil, ErrInvalidPacketType
	}
	count := int(data[1])
	expectedSize := MobSnapshotHeaderSize + count*MobSnapshotEntrySize
	if len(data) < expectedSize {
		return nil, ErrInvalidPacketSize
	}

	mobs := make([]MobSnapshot, count)
	offset := MobSnapshotHeaderSize
	for i := 0; i < count; i++ {
		mobs[i] = MobSnapshot{
			MobID:   binary.LittleEndian.Uint32(data[offset : offset+4]),
			MobType: data[offset+4],
			State:   data[offset+5],
			PosX:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+6 : offset+10])),
			PosY:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+10 : offset+14])),
			PosZ:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+14 : offset+18])),
			RotY:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+18 : offset+22])),
			HP:      binary.LittleEndian.Uint16(data[offset+22 : offset+24]),
			MaxHP:   binary.LittleEndian.Uint16(data[offset+24 : offset+26]),
		}
		offset += MobSnapshotEntrySize
	}
	return mobs, nil
}

// --- 0x34: AOE_TELEGRAPH (UDP: Server -> Clients) ---

// AOETelegraphPacket representa o aviso telegrafado de golpe em área no chão.
type AOETelegraphPacket struct {
	SourceID   uint32
	PosX       float32
	PosZ       float32
	Radius     float32
	DurationMs uint16
}

// SerializeAOETelegraph cria o payload de 19 bytes do pacote AOE_TELEGRAPH.
func SerializeAOETelegraph(sourceID uint32, posX, posZ, radius float32, durationMs uint16) [AOETelegraphPacketSize]byte {
	var b [AOETelegraphPacketSize]byte
	b[0] = PacketTypeAOETelegraph
	binary.LittleEndian.PutUint32(b[1:5], sourceID)
	binary.LittleEndian.PutUint32(b[5:9], math.Float32bits(posX))
	binary.LittleEndian.PutUint32(b[9:13], math.Float32bits(posZ))
	binary.LittleEndian.PutUint32(b[13:17], math.Float32bits(radius))
	binary.LittleEndian.PutUint16(b[17:19], durationMs)
	return b
}

// DeserializeAOETelegraph decodifica o pacote AOE_TELEGRAPH (19 bytes).
func DeserializeAOETelegraph(data []byte, out *AOETelegraphPacket) error {
	if len(data) < AOETelegraphPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeAOETelegraph {
		return ErrInvalidPacketType
	}
	out.SourceID = binary.LittleEndian.Uint32(data[1:5])
	out.PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[5:9]))
	out.PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[9:13]))
	out.Radius = math.Float32frombits(binary.LittleEndian.Uint32(data[13:17]))
	out.DurationMs = binary.LittleEndian.Uint16(data[17:19])
	return nil
}

// Constante de tamanho do pacote PROJECTILE_SPAWN (38 bytes)
const ProjectileSpawnPacketSize = 38

// ProjectileSpawnPacket representa o pacote 0x35 disparado quando um projétil 3D é gerado no mundo.
type ProjectileSpawnPacket struct {
	ProjectileID uint32
	OwnerID      uint32
	ProjType     uint8
	StartX       float32
	StartY       float32
	StartZ       float32
	DirX         float32
	DirZ         float32
	Speed        float32
	MaxRange     float32
}

// SerializeProjectileSpawn empacota os 38 bytes do pacote 0x35 PROJECTILE_SPAWN.
func SerializeProjectileSpawn(projID, ownerID uint32, projType uint8, startX, startY, startZ, dirX, dirZ, speed, maxRange float32) [ProjectileSpawnPacketSize]byte {
	var buf [ProjectileSpawnPacketSize]byte
	buf[0] = PacketTypeProjectileSpawn
	binary.LittleEndian.PutUint32(buf[1:5], projID)
	binary.LittleEndian.PutUint32(buf[5:9], ownerID)
	buf[9] = projType
	binary.LittleEndian.PutUint32(buf[10:14], math.Float32bits(startX))
	binary.LittleEndian.PutUint32(buf[14:18], math.Float32bits(startY))
	binary.LittleEndian.PutUint32(buf[18:22], math.Float32bits(startZ))
	binary.LittleEndian.PutUint32(buf[22:26], math.Float32bits(dirX))
	binary.LittleEndian.PutUint32(buf[26:30], math.Float32bits(dirZ))
	binary.LittleEndian.PutUint32(buf[30:34], math.Float32bits(speed))
	binary.LittleEndian.PutUint32(buf[34:38], math.Float32bits(maxRange))
	return buf
}

// DeserializeProjectileSpawn desempacota os 38 bytes do pacote 0x35.
func DeserializeProjectileSpawn(data []byte, pkt *ProjectileSpawnPacket) error {
	if len(data) < ProjectileSpawnPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeProjectileSpawn {
		return ErrInvalidPacketType
	}
	pkt.ProjectileID = binary.LittleEndian.Uint32(data[1:5])
	pkt.OwnerID = binary.LittleEndian.Uint32(data[5:9])
	pkt.ProjType = data[9]
	pkt.StartX = math.Float32frombits(binary.LittleEndian.Uint32(data[10:14]))
	pkt.StartY = math.Float32frombits(binary.LittleEndian.Uint32(data[14:18]))
	pkt.StartZ = math.Float32frombits(binary.LittleEndian.Uint32(data[18:22]))
	pkt.DirX = math.Float32frombits(binary.LittleEndian.Uint32(data[22:26]))
	pkt.DirZ = math.Float32frombits(binary.LittleEndian.Uint32(data[26:30]))
	pkt.Speed = math.Float32frombits(binary.LittleEndian.Uint32(data[30:34]))
	pkt.MaxRange = math.Float32frombits(binary.LittleEndian.Uint32(data[34:38]))
	return nil
}


