package protocol

import (
	"math"
	"testing"
)

func TestWelcomePacket(t *testing.T) {
	playerID := uint32(42)
	data := SerializeWelcome(playerID)

	if len(data) != WelcomePacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", WelcomePacketSize, len(data))
	}
	if data[0] != PacketTypeWelcome {
		t.Fatalf("esperava opcode 0x01, obteve 0x%02x", data[0])
	}

	decodedID, err := DeserializeWelcome(data[:])
	if err != nil {
		t.Fatalf("erro ao decodificar WELCOME: %v", err)
	}
	if decodedID != playerID {
		t.Fatalf("esperava playerID %d, obteve %d", playerID, decodedID)
	}
}

func TestPlayerDisconnectedPacket(t *testing.T) {
	playerID := uint32(7)
	data := SerializePlayerDisconnected(playerID)

	if len(data) != PlayerDisconnectedPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", PlayerDisconnectedPacketSize, len(data))
	}
	if data[0] != PacketTypePlayerDisconnected {
		t.Fatalf("esperava opcode 0x02, obteve 0x%02x", data[0])
	}

	decodedID, err := DeserializePlayerDisconnected(data[:])
	if err != nil {
		t.Fatalf("erro ao decodificar PLAYER_DISCONNECTED: %v", err)
	}
	if decodedID != playerID {
		t.Fatalf("esperava playerID %d, obteve %d", playerID, decodedID)
	}
}

func TestPlayerMovePacket(t *testing.T) {
	orig := PlayerMovePacket{
		PlayerID: 101,
		Seq:      55,
		PosX:     12.5,
		PosY:     1.0,
		PosZ:     -33.25,
		RotY:     180.0,
	}

	data := SerializePlayerMove(orig)
	if len(data) != PlayerMovePacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", PlayerMovePacketSize, len(data))
	}
	if data[0] != PacketTypePlayerMove {
		t.Fatalf("esperava opcode 0x10, obteve 0x%02x", data[0])
	}

	var parsed PlayerMovePacket
	if err := DeserializePlayerMove(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar PLAYER_MOVE: %v", err)
	}

	if parsed.PlayerID != orig.PlayerID || parsed.Seq != orig.Seq {
		t.Fatalf("IDs ou Seq divergentes: %+v vs %+v", parsed, orig)
	}
	if math.Abs(float64(parsed.PosX-orig.PosX)) > 0.0001 ||
		math.Abs(float64(parsed.PosY-orig.PosY)) > 0.0001 ||
		math.Abs(float64(parsed.PosZ-orig.PosZ)) > 0.0001 ||
		math.Abs(float64(parsed.RotY-orig.RotY)) > 0.0001 {
		t.Fatalf("posicoes/rotacoes divergentes: %+v vs %+v", parsed, orig)
	}
}

func TestWorldSnapshotPacket(t *testing.T) {
	serverTick := uint32(999)
	players := []PlayerSnapshot{
		{PlayerID: 1, PosX: 0.0, PosY: 1.0, PosZ: 0.0, RotY: 0.0},
		{PlayerID: 2, PosX: 10.5, PosY: 2.0, PosZ: -5.5, RotY: 45.0},
		{PlayerID: 3, PosX: -20.0, PosY: 0.5, PosZ: 30.0, RotY: 90.0},
	}

	expectedSize := WorldSnapshotHeaderSize + len(players)*PlayerSnapshotEntrySize
	buf := make([]byte, expectedSize)
	n := SerializeWorldSnapshotInto(buf, serverTick, players)
	if n != expectedSize {
		t.Fatalf("esperava %d bytes escritos, obteve %d", expectedSize, n)
	}

	var snapshot WorldSnapshotPacket
	if err := DeserializeWorldSnapshot(buf, &snapshot); err != nil {
		t.Fatalf("erro ao decodificar WORLD_SNAPSHOT: %v", err)
	}

	if snapshot.ServerTick != serverTick {
		t.Fatalf("esperava tick %d, obteve %d", serverTick, snapshot.ServerTick)
	}
	if snapshot.PlayerCount != uint8(len(players)) {
		t.Fatalf("esperava contagem %d, obteve %d", len(players), snapshot.PlayerCount)
	}
}

func TestNPCSnapshotPacket(t *testing.T) {
	npcs := []NPCSnapshot{
		{NPCID: 1, PosX: 8.0, PosY: 0.0, PosZ: 8.0, RotY: 1.57, State: 2},
		{NPCID: 2, PosX: -8.0, PosY: 0.0, PosZ: -6.0, RotY: 3.14, State: 3},
	}

	data := SerializeNPCSnapshot(npcs)
	expectedSize := NPCSnapshotHeaderSize + len(npcs)*NPCSnapshotEntrySize
	if len(data) != expectedSize {
		t.Fatalf("esperava %d bytes, obteve %d", expectedSize, len(data))
	}
	if data[0] != PacketTypeNPCSnapshot {
		t.Fatalf("esperava opcode 0x12, obteve 0x%02x", data[0])
	}
	if data[1] != uint8(len(npcs)) {
		t.Fatalf("esperava contagem %d, obteve %d", len(npcs), data[1])
	}

	var parsed NPCSnapshotPacket
	if err := DeserializeNPCSnapshot(data, &parsed); err != nil {
		t.Fatalf("erro ao decodificar NPC_SNAPSHOT: %v", err)
	}
	if parsed.NPCCount != uint8(len(npcs)) {
		t.Fatalf("contagem incorreta: %d", parsed.NPCCount)
	}
	for i, npc := range npcs {
		p := parsed.NPCs[i]
		if p.NPCID != npc.NPCID || p.State != npc.State {
			t.Fatalf("dados divergentes no NPC %d", i)
		}
		if math.Abs(float64(p.PosX-npc.PosX)) > 0.0001 || math.Abs(float64(p.PosZ-npc.PosZ)) > 0.0001 {
			t.Fatalf("coordenadas divergentes no NPC %d", i)
		}
	}
}

func TestPlayerInteractPacket(t *testing.T) {
	data := SerializePlayerInteract(5, 1)
	if len(data) != PlayerInteractPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", PlayerInteractPacketSize, len(data))
	}
	if data[0] != PacketTypePlayerInteract {
		t.Fatalf("esperava opcode 0x20, obteve 0x%02x", data[0])
	}

	var parsed PlayerInteractPacket
	if err := DeserializePlayerInteract(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar PLAYER_INTERACT: %v", err)
	}
	if parsed.PlayerID != 5 || parsed.TargetNPCID != 1 {
		t.Fatalf("valores divergentes: %+v", parsed)
	}
}

func TestNPCSayPacket(t *testing.T) {
	msg := "Pelo calor das brasas! Essa lâmina precisa de mais algumas marteladas..."
	data := SerializeNPCSay(1, msg)

	if data[0] != PacketTypeNPCSay {
		t.Fatalf("esperava opcode 0x21, obteve 0x%02x", data[0])
	}

	var parsed NPCSayPacket
	if err := DeserializeNPCSay(data, &parsed); err != nil {
		t.Fatalf("erro ao decodificar NPC_SAY: %v", err)
	}
	if parsed.NPCID != 1 {
		t.Fatalf("esperava NPCID 1, obteve %d", parsed.NPCID)
	}
	if parsed.Message != msg {
		t.Fatalf("mensagem divergente:\nEsperada: %s\nObtida:   %s", msg, parsed.Message)
	}
}

func TestWorldTimePacket(t *testing.T) {
	hour := uint8(16)
	minute := uint8(45)
	moonPhase := uint8(4) // Lua Cheia
	weatherType := uint8(2) // Neblina Densa

	data := SerializeWorldTime(hour, minute, moonPhase, weatherType)
	if len(data) != WorldTimePacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", WorldTimePacketSize, len(data))
	}
	if data[0] != PacketTypeWorldTime {
		t.Fatalf("esperava opcode 0x13, obteve 0x%02x", data[0])
	}
	if data[1] != hour || data[2] != minute || data[3] != moonPhase || data[4] != weatherType {
		t.Fatalf("campos divergentes: (%d, %d, %d, %d)", data[1], data[2], data[3], data[4])
	}

	var parsed WorldTimePacket
	if err := DeserializeWorldTime(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar WORLD_TIME: %v", err)
	}
	if parsed.WorldHour != hour || parsed.WorldMinute != minute || parsed.MoonPhase != moonPhase || parsed.WeatherType != weatherType {
		t.Fatalf("dados decodificados incorretos: %+v", parsed)
	}
}

func TestDevWorldControlPacket(t *testing.T) {
	cmdType := uint8(2) // Ciclar Lua
	val := uint8(1)

	data := SerializeDevWorldControl(cmdType, val)
	if len(data) != DevWorldControlPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", DevWorldControlPacketSize, len(data))
	}
	if data[0] != PacketTypeDevWorldControl {
		t.Fatalf("esperava opcode 0x22, obteve 0x%02x", data[0])
	}
	if data[1] != cmdType || data[2] != val {
		t.Fatalf("payload divergente: (%d, %d)", data[1], data[2])
	}

	var parsed DevWorldControlPacket
	if err := DeserializeDevWorldControl(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar DEV_WORLD_CONTROL: %v", err)
	}
	if parsed.CommandType != cmdType || parsed.Value != val {
		t.Fatalf("dados decodificados incorretos: %+v", parsed)
	}
}

func TestSelectIdentityPacket(t *testing.T) {
	playerID := uint32(99)
	raceID := RaceNoctari
	classID := ClassScout

	data := SerializeSelectIdentity(playerID, raceID, classID)
	if len(data) != SelectIdentityPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", SelectIdentityPacketSize, len(data))
	}
	if data[0] != PacketTypeSelectIdentity {
		t.Fatalf("esperava opcode 0x30, obteve 0x%02x", data[0])
	}

	var parsed SelectIdentityPacket
	if err := DeserializeSelectIdentity(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar SELECT_IDENTITY: %v", err)
	}
	if parsed.PlayerID != playerID || parsed.RaceID != raceID || parsed.ClassID != classID {
		t.Fatalf("dados divergentes em SELECT_IDENTITY: %+v", parsed)
	}
}

func TestPlayerActionPacket(t *testing.T) {
	playerID := uint32(42)
	actionType := ActionSpecialSkill
	aimX := float32(0.707)
	aimZ := float32(-0.707)

	data := SerializePlayerAction(playerID, actionType, aimX, aimZ)
	if len(data) != PlayerActionPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", PlayerActionPacketSize, len(data))
	}
	if data[0] != PacketTypePlayerAction {
		t.Fatalf("esperava opcode 0x31, obteve 0x%02x", data[0])
	}

	var parsed PlayerActionPacket
	if err := DeserializePlayerAction(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar PLAYER_ACTION: %v", err)
	}
	if parsed.PlayerID != playerID || parsed.ActionType != actionType {
		t.Fatalf("dados divergentes em PLAYER_ACTION: %+v", parsed)
	}
	if math.Abs(float64(parsed.AimDirX-aimX)) > 0.0001 || math.Abs(float64(parsed.AimDirZ-aimZ)) > 0.0001 {
		t.Fatalf("vetor de mira divergente: (%f, %f) vs (%f, %f)", parsed.AimDirX, parsed.AimDirZ, aimX, aimZ)
	}
}

func TestCombatEventPacket(t *testing.T) {
	attackerID := uint32(1)
	targetID := uint32(101)
	actionType := ActionBasicAttack
	damage := uint16(45)
	isCrit := uint8(1)
	targetHP := uint16(955)
	targetMaxHP := uint16(1000)

	data := SerializeCombatEvent(attackerID, targetID, actionType, damage, isCrit, targetHP, targetMaxHP)
	if len(data) != CombatEventPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", CombatEventPacketSize, len(data))
	}
	if data[0] != PacketTypeCombatEvent {
		t.Fatalf("esperava opcode 0x32, obteve 0x%02x", data[0])
	}

	var parsed CombatEventPacket
	if err := DeserializeCombatEvent(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar COMBAT_EVENT: %v", err)
	}
	if parsed.AttackerID != attackerID || parsed.TargetID != targetID || parsed.ActionType != actionType ||
		parsed.Damage != damage || parsed.IsCrit != isCrit || parsed.TargetHP != targetHP || parsed.TargetMaxHP != targetMaxHP {
		t.Fatalf("dados divergentes em COMBAT_EVENT: %+v", parsed)
	}
}

func TestPlayerStatsPacket(t *testing.T) {
	playerID := uint32(7)
	raceID := RaceValerian
	classID := ClassSwordsman
	hp := uint16(100)
	maxHP := uint16(100)
	stamina := uint16(85)
	maxStamina := uint16(100)

	data := SerializePlayerStats(playerID, raceID, classID, hp, maxHP, stamina, maxStamina)
	if len(data) != PlayerStatsPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", PlayerStatsPacketSize, len(data))
	}
	if data[0] != PacketTypePlayerStats {
		t.Fatalf("esperava opcode 0x33, obteve 0x%02x", data[0])
	}

	var parsed PlayerStatsPacket
	if err := DeserializePlayerStats(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar PLAYER_STATS: %v", err)
	}
	if parsed.PlayerID != playerID || parsed.RaceID != raceID || parsed.ClassID != classID ||
		parsed.HP != hp || parsed.MaxHP != maxHP || parsed.Stamina != stamina || parsed.MaxStamina != maxStamina {
		t.Fatalf("dados divergentes em PLAYER_STATS: %+v", parsed)
	}
}

func TestMobSnapshotPacket(t *testing.T) {
	mobs := []MobSnapshot{
		{
			MobID:   201,
			MobType: MobTypeMistWolf,
			State:   MobStateChasing,
			PosX:    16.0,
			PosY:    0.0,
			PosZ:    -8.0,
			RotY:    1.57,
			HP:      200,
			MaxHP:   220,
		},
		{
			MobID:   206,
			MobType: MobTypeIronEnforcer,
			State:   MobStateAttacking,
			PosX:    0.0,
			PosY:    0.0,
			PosZ:    22.0,
			RotY:    3.14,
			HP:      650,
			MaxHP:   650,
		},
	}

	data := SerializeMobSnapshot(mobs)
	expectedSize := MobSnapshotHeaderSize + len(mobs)*MobSnapshotEntrySize
	if len(data) != expectedSize {
		t.Fatalf("esperava %d bytes, obteve %d", expectedSize, len(data))
	}
	if data[0] != PacketTypeMobSnapshot {
		t.Fatalf("esperava opcode 0x14, obteve 0x%02x", data[0])
	}
	if data[1] != 2 {
		t.Fatalf("esperava MobCount 2, obteve %d", data[1])
	}

	decoded, err := DeserializeMobSnapshot(data)
	if err != nil {
		t.Fatalf("erro ao decodificar MOB_SNAPSHOT: %v", err)
	}
	if len(decoded) != len(mobs) {
		t.Fatalf("esperava %d mobs, obteve %d", len(mobs), len(decoded))
	}

	for i := range mobs {
		if decoded[i].MobID != mobs[i].MobID || decoded[i].MobType != mobs[i].MobType || decoded[i].State != mobs[i].State ||
			decoded[i].HP != mobs[i].HP || decoded[i].MaxHP != mobs[i].MaxHP {
			t.Fatalf("mob %d divergente: %+v vs %+v", i, decoded[i], mobs[i])
		}
		if math.Abs(float64(decoded[i].PosX-mobs[i].PosX)) > 0.001 ||
			math.Abs(float64(decoded[i].PosZ-mobs[i].PosZ)) > 0.001 ||
			math.Abs(float64(decoded[i].RotY-mobs[i].RotY)) > 0.001 {
			t.Fatalf("posicoes/rotacoes divergentes no mob %d: %+v vs %+v", i, decoded[i], mobs[i])
		}
	}
}

func TestAOETelegraphPacket(t *testing.T) {
	sourceID := uint32(206)
	posX := float32(2.5)
	posZ := float32(18.0)
	radius := float32(4.0)
	durationMs := uint16(1500)

	data := SerializeAOETelegraph(sourceID, posX, posZ, radius, durationMs)
	if len(data) != AOETelegraphPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", AOETelegraphPacketSize, len(data))
	}
	if data[0] != PacketTypeAOETelegraph {
		t.Fatalf("esperava opcode 0x34, obteve 0x%02x", data[0])
	}

	var parsed AOETelegraphPacket
	if err := DeserializeAOETelegraph(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar AOE_TELEGRAPH: %v", err)
	}
	if parsed.SourceID != sourceID || parsed.DurationMs != durationMs {
		t.Fatalf("dados divergentes em AOE_TELEGRAPH: %+v", parsed)
	}
	if math.Abs(float64(parsed.PosX-posX)) > 0.001 ||
		math.Abs(float64(parsed.PosZ-posZ)) > 0.001 ||
		math.Abs(float64(parsed.Radius-radius)) > 0.001 {
		t.Fatalf("coordenadas divergentes em AOE_TELEGRAPH: %+v", parsed)
	}
}

func TestProjectileSpawnPacket(t *testing.T) {
	projID := uint32(501)
	ownerID := uint32(1)
	projType := ProjTypePhysicalArrow
	startX := float32(10.5)
	startY := float32(1.2)
	startZ := float32(-5.0)
	dirX := float32(0.0)
	dirZ := float32(1.0)
	speed := float32(24.0)
	maxRange := float32(16.0)

	data := SerializeProjectileSpawn(projID, ownerID, projType, startX, startY, startZ, dirX, dirZ, speed, maxRange)
	if len(data) != ProjectileSpawnPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", ProjectileSpawnPacketSize, len(data))
	}
	if data[0] != PacketTypeProjectileSpawn {
		t.Fatalf("esperava opcode 0x35, obteve 0x%02x", data[0])
	}

	var parsed ProjectileSpawnPacket
	if err := DeserializeProjectileSpawn(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar PROJECTILE_SPAWN: %v", err)
	}

	if parsed.ProjectileID != projID || parsed.OwnerID != ownerID || parsed.ProjType != projType {
		t.Fatalf("IDs ou tipo divergentes: %+v", parsed)
	}
	if math.Abs(float64(parsed.StartX-startX)) > 0.001 ||
		math.Abs(float64(parsed.StartY-startY)) > 0.001 ||
		math.Abs(float64(parsed.StartZ-startZ)) > 0.001 ||
		math.Abs(float64(parsed.DirX-dirX)) > 0.001 ||
		math.Abs(float64(parsed.DirZ-dirZ)) > 0.001 ||
		math.Abs(float64(parsed.Speed-speed)) > 0.001 ||
		math.Abs(float64(parsed.MaxRange-maxRange)) > 0.001 {
		t.Fatalf("metricas de projetil divergentes: %+v", parsed)
	}
}


