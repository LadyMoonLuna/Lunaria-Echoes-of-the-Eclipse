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
	moonPhase := uint8(4)   // Lua Cheia
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
	for cmdType := uint8(1); cmdType <= 9; cmdType++ {
		val := uint8(cmdType * 10)
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
}

func TestSelectIdentityPacket(t *testing.T) {
	playerID := uint32(99)
	raceID := RaceNoctari
	classID := ClassScout
	actionMode := IdentityModeEvolveClass
	subPath := uint8(2)

	data := SerializeSelectIdentity(playerID, raceID, classID, actionMode, subPath)
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
	if parsed.PlayerID != playerID || parsed.RaceID != raceID || parsed.ClassID != classID || parsed.ActionMode != actionMode || parsed.SubPath != subPath {
		t.Fatalf("dados divergentes em SELECT_IDENTITY: %+v", parsed)
	}

	// Teste de retrocompatibilidade com payload legado de 7 bytes
	legacy7 := data[:7]
	var parsedLegacy SelectIdentityPacket
	if err := DeserializeSelectIdentity(legacy7, &parsedLegacy); err != nil {
		t.Fatalf("erro ao decodificar SELECT_IDENTITY legado de 7 bytes: %v", err)
	}
	if parsedLegacy.ActionMode != IdentityModeInitialChange {
		t.Fatalf("esperava ActionMode default 0 no legado, obteve %d", parsedLegacy.ActionMode)
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
	classTier := TierRare // 3
	level := uint8(12)
	hp := uint16(180)
	maxHP := uint16(200)
	stamina := uint16(85)
	maxStamina := uint16(120)
	buffActive := uint8(1)
	xp := uint16(450)
	nextLevelXP := uint16(650)
	statPoints := uint8(10)
	str := uint8(15)
	dex := uint8(8)
	con := uint8(12)
	agi := uint8(10)
	intStat := uint8(5)
	spi := uint8(6)
	mas := uint8(7)
	lck := uint8(9)
	subPath := uint8(3)
	mana, maxMana := uint16(140), uint16(260)

	data := SerializePlayerStats(playerID, raceID, classID, classTier, level, hp, maxHP, stamina, maxStamina, buffActive, xp, nextLevelXP, statPoints, str, dex, con, agi, intStat, spi, mas, lck, subPath, mana, maxMana)
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
		parsed.ClassTier != classTier || parsed.Level != level ||
		parsed.HP != hp || parsed.MaxHP != maxHP || parsed.Stamina != stamina || parsed.MaxStamina != maxStamina ||
		parsed.BuffActive != buffActive || parsed.XP != xp || parsed.NextLevelXP != nextLevelXP ||
		parsed.StatPoints != statPoints || parsed.STR != str || parsed.DEX != dex || parsed.CON != con ||
		parsed.AGI != agi || parsed.INT != intStat || parsed.SPI != spi || parsed.MAS != mas || parsed.LCK != lck ||
		parsed.SubPath != subPath || parsed.Mana != mana || parsed.MaxMana != maxMana {
		t.Fatalf("dados divergentes em PLAYER_STATS: %+v", parsed)
	}
}

func TestAllocateStatPacket(t *testing.T) {
	playerID := uint32(101)
	statID := StatIDCON // 3

	data := SerializeAllocateStat(playerID, statID)
	if len(data) != AllocateStatPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", AllocateStatPacketSize, len(data))
	}
	if data[0] != PacketTypeAllocateStat {
		t.Fatalf("esperava opcode 0x37, obteve 0x%02x", data[0])
	}

	var parsed AllocateStatPacket
	if err := DeserializeAllocateStat(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar ALLOCATE_STAT: %v", err)
	}
	if parsed.PlayerID != playerID || parsed.StatID != statID {
		t.Fatalf("dados divergentes em ALLOCATE_STAT: %+v", parsed)
	}
}

func TestPlayerRespawnPacket(t *testing.T) {
	playerID := uint32(5)
	posX := float32(0.0)
	posY := float32(1.5)
	posZ := float32(0.0)

	data := SerializePlayerRespawn(playerID, posX, posY, posZ)
	if len(data) != PlayerRespawnPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", PlayerRespawnPacketSize, len(data))
	}
	if data[0] != PacketTypePlayerRespawn {
		t.Fatalf("esperava opcode 0x36, obteve 0x%02x", data[0])
	}

	var parsed PlayerRespawnPacket
	if err := DeserializePlayerRespawn(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar PLAYER_RESPAWN: %v", err)
	}
	if parsed.PlayerID != playerID ||
		math.Abs(float64(parsed.PosX-posX)) > 0.001 ||
		math.Abs(float64(parsed.PosY-posY)) > 0.001 ||
		math.Abs(float64(parsed.PosZ-posZ)) > 0.001 {
		t.Fatalf("dados divergentes em PLAYER_RESPAWN: %+v", parsed)
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

func TestInventorySyncPacket(t *testing.T) {
	var equippedSlots [EquipSlotCount]uint8
	equippedSlots[SlotHelmet] = ItemVigilHelmet
	equippedSlots[SlotChest] = ItemSteelChestplate
	equippedSlots[SlotLegs] = ItemWolfLeatherPants
	equippedSlots[SlotBoots] = ItemMistwalkerBoots
	equippedSlots[SlotGloves] = ItemBlacksmithGauntlets
	equippedSlots[SlotBelt] = ItemAlchemistBelt
	equippedSlots[SlotAmulet] = ItemSilverMoonAmulet
	equippedSlots[SlotRing1] = ItemAncestralFangRing
	equippedSlots[SlotRing2] = ItemBloodRubyRing
	equippedSlots[SlotRing3] = ItemObsidianRing
	equippedSlots[SlotRing4] = ItemStarlightRing
	equippedSlots[SlotCloak] = ItemAlphaPeltCloak
	equippedSlots[SlotMainHand] = ItemIronLongsword
	equippedSlots[SlotOffHand] = ItemTowerShield
	status := InventoryStatus{Gold: 250, EclipseCoins: 10, CurrentWeight: 42.5, MaxWeight: 105, SpeedPercent: 100}

	slots := []InventorySlot{
		{ItemID: ItemEmptyFlask, Quantity: 3},
		{ItemID: ItemRawWolfMeat, Quantity: 2},
		{ItemID: ItemFreshWolfBlood, Quantity: 1},
	}

	var qualities [EquipSlotCount]uint8
	qualities[SlotMainHand] = 64
	data := SerializeInventorySync(equippedSlots, qualities, status, slots)
	expectedLen := InventorySyncHeaderSize + len(slots)*InventorySlotEntrySize
	if len(data) != expectedLen {
		t.Fatalf("esperava tamanho %d, obteve %d", expectedLen, len(data))
	}
	if data[0] != PacketTypeInventorySync {
		t.Fatalf("esperava opcode 0x38, obteve 0x%02x", data[0])
	}

	var parsed InventorySyncPacket
	if err := DeserializeInventorySync(data, &parsed); err != nil {
		t.Fatalf("erro ao decodificar INVENTORY_SYNC: %v", err)
	}

	if parsed.EquippedQualities != qualities {
		t.Fatal("Condição dos slots divergente")
	}
	if parsed.Status != status {
		t.Fatalf("dinheiro/peso divergentes: %+v vs %+v", parsed.Status, status)
	}
	for i := 0; i < EquipSlotCount; i++ {
		if parsed.EquippedSlots[i] != equippedSlots[i] {
			t.Fatalf("slot de equipamento %d divergente: %d vs %d", i, parsed.EquippedSlots[i], equippedSlots[i])
		}
	}
	if parsed.EquippedArmorID != ItemSteelChestplate || parsed.EquippedAccessoryID != ItemAncestralFangRing {
		t.Fatalf("alias de armadura/acessorio divergente: armor=%d, acc=%d", parsed.EquippedArmorID, parsed.EquippedAccessoryID)
	}
	if parsed.SlotCount != uint16(len(slots)) {
		t.Fatalf("slot count divergente: %d vs %d", parsed.SlotCount, len(slots))
	}

	for i, s := range slots {
		if parsed.Slots[i].ItemID != s.ItemID || parsed.Slots[i].Quantity != s.Quantity {
			t.Fatalf("slot %d divergente: %+v vs %+v", i, parsed.Slots[i], s)
		}
	}

	// Testa também o serializador legado de 2 slots
	legacyData := SerializeInventorySyncLegacy(ItemAlphaWolfPelt, ItemAncestralFangRing, slots)
	var parsedLegacy InventorySyncPacket
	if err := DeserializeInventorySync(legacyData, &parsedLegacy); err != nil {
		t.Fatalf("erro ao decodificar legado: %v", err)
	}
	if parsedLegacy.EquippedArmorID != ItemAlphaWolfPelt || parsedLegacy.EquippedAccessoryID != ItemAncestralFangRing {
		t.Fatalf("legado divergente: %+v", parsedLegacy)
	}
}

func TestUseOrEquipItemPacket(t *testing.T) {
	playerID := uint32(42)
	itemID := ItemWolfBloodPotion

	data := SerializeUseOrEquipItem(playerID, itemID)
	if len(data) != UseOrEquipItemPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", UseOrEquipItemPacketSize, len(data))
	}
	if data[0] != PacketTypeUseOrEquipItem {
		t.Fatalf("esperava opcode 0x39, obteve 0x%02x", data[0])
	}

	var parsed UseOrEquipItemPacket
	if err := DeserializeUseOrEquipItem(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar USE_OR_EQUIP_ITEM: %v", err)
	}

	if parsed.PlayerID != playerID || parsed.ItemID != itemID {
		t.Fatalf("dados divergentes em USE_OR_EQUIP_ITEM: %+v", parsed)
	}
}

func TestEvolutionOfferPacket(t *testing.T) {
	offerType := OfferTypeRace
	optA := RaceHighValerian
	optB := RaceAetherWalker

	data := SerializeEvolutionOffer(offerType, optA, optB)
	if len(data) != EvolutionOfferPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", EvolutionOfferPacketSize, len(data))
	}
	if data[0] != PacketTypeEvolutionOffer {
		t.Fatalf("esperava opcode 0x40, obteve 0x%02x", data[0])
	}

	var parsed EvolutionOfferPacket
	if err := DeserializeEvolutionOffer(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar EVOLUTION_OFFER: %v", err)
	}

	if parsed.OfferType != offerType || parsed.OptionAID != optA || parsed.OptionBID != optB {
		t.Fatalf("dados divergentes em EVOLUTION_OFFER: %+v", parsed)
	}
}

func TestDevGetDropRatesPacket(t *testing.T) {
	playerID := uint32(99)
	req := SerializeDevGetDropRatesRequest(playerID)
	if len(req) != DevGetDropRatesPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", DevGetDropRatesPacketSize, len(req))
	}
	if req[0] != PacketTypeDevGetDropRates {
		t.Fatalf("esperava opcode 0x3A, obteve 0x%02x", req[0])
	}

	var parsedReq DevGetDropRatesPacket
	if err := DeserializeDevGetDropRatesRequest(req[:], &parsedReq); err != nil {
		t.Fatalf("erro ao decodificar DEV_GET_DROP_RATES request: %v", err)
	}
	if parsedReq.PlayerID != playerID {
		t.Fatalf("esperava playerID %d, obteve %d", playerID, parsedReq.PlayerID)
	}

	reportMsg := "[DEV] Item Drops: Mob 1 -> Meat (100%), Fang (25%)"
	resp := SerializeDevGetDropRatesResponse(reportMsg)
	if resp[0] != PacketTypeDevGetDropRates {
		t.Fatalf("esperava opcode 0x3A na resposta, obteve 0x%02x", resp[0])
	}

	parsedReport, err := DeserializeDevGetDropRatesResponse(resp)
	if err != nil {
		t.Fatalf("erro ao decodificar DEV_GET_DROP_RATES response: %v", err)
	}
	if parsedReport != reportMsg {
		t.Fatalf("esperava '%s', obteve '%s'", reportMsg, parsedReport)
	}
}

func TestInteractCorpsePacket(t *testing.T) {
	playerID := uint32(101)
	corpseID := uint32(5002)

	data := SerializeInteractCorpse(playerID, corpseID)
	if len(data) != InteractCorpsePacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", InteractCorpsePacketSize, len(data))
	}
	if data[0] != PacketTypeInteractCorpse {
		t.Fatalf("esperava opcode 0x3B, obteve 0x%02x", data[0])
	}

	var parsed InteractCorpsePacket
	if err := DeserializeInteractCorpse(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar INTERACT_CORPSE: %v", err)
	}
	if parsed.PlayerID != playerID || parsed.CorpseID != corpseID {
		t.Fatalf("dados divergentes em INTERACT_CORPSE: %+v vs (%d, %d)", parsed, playerID, corpseID)
	}
}

func TestOpenAutopsyUIPacket(t *testing.T) {
	corpseID := uint32(2048)
	mobType := MobTypeAlphaWolf
	seed := uint32(889911)

	organs := []AutopsyOrganEntry{
		{OrganIndex: 0, OrganType: 1, ItemReward: ItemAlphaWolfPelt, Difficulty: 6, QualityTier: 0},
		{OrganIndex: 1, OrganType: 4, ItemReward: ItemPureLunarBlood, Difficulty: 7, QualityTier: 1},
		{OrganIndex: 2, OrganType: 5, ItemReward: ItemAncestralFangRing, Difficulty: 8, QualityTier: 2},
	}

	data := SerializeOpenAutopsyUI(corpseID, mobType, seed, organs)
	expectedSize := OpenAutopsyUIHeaderSize + len(organs)*AutopsyOrganEntrySize
	if len(data) != expectedSize {
		t.Fatalf("esperava %d bytes, obteve %d", expectedSize, len(data))
	}
	if data[0] != PacketTypeOpenAutopsyUI {
		t.Fatalf("esperava opcode 0x3C, obteve 0x%02x", data[0])
	}

	var parsed OpenAutopsyUIPacket
	if err := DeserializeOpenAutopsyUI(data, &parsed); err != nil {
		t.Fatalf("erro ao decodificar OPEN_AUTOPSY_UI: %v", err)
	}

	if parsed.CorpseID != corpseID || parsed.MobType != mobType || parsed.DifficultySeed != seed || int(parsed.OrganCount) != len(organs) {
		t.Fatalf("cabeçalho divergente: %+v", parsed)
	}
	for i, o := range organs {
		po := parsed.Organs[i]
		if po.OrganIndex != o.OrganIndex || po.OrganType != o.OrganType || po.ItemReward != o.ItemReward || po.Difficulty != o.Difficulty || po.QualityTier != o.QualityTier {
			t.Fatalf("órgão #%d divergente: %+v vs %+v", i, po, o)
		}
	}
}

func TestSubmitAutopsyResultPacket(t *testing.T) {
	playerID := uint32(77)
	corpseID := uint32(3333)
	organIndex := uint8(2)
	resultTier := QualityPerfect // 1

	data := SerializeSubmitAutopsyResult(playerID, corpseID, organIndex, resultTier)
	if len(data) != SubmitAutopsyResultPacketSize {
		t.Fatalf("esperava %d bytes, obteve %d", SubmitAutopsyResultPacketSize, len(data))
	}
	if data[0] != PacketTypeSubmitAutopsyResult {
		t.Fatalf("esperava opcode 0x3D, obteve 0x%02x", data[0])
	}

	var parsed SubmitAutopsyResultPacket
	if err := DeserializeSubmitAutopsyResult(data[:], &parsed); err != nil {
		t.Fatalf("erro ao decodificar SUBMIT_AUTOPSY_RESULT: %v", err)
	}
	if parsed.PlayerID != playerID || parsed.CorpseID != corpseID || parsed.OrganIndex != organIndex || parsed.ResultTier != resultTier {
		t.Fatalf("dados divergentes: %+v", parsed)
	}
}

func TestCorpseSnapshotPacket(t *testing.T) {
	snapshots := []CorpseSnapshot{
		{
			CorpseID:         1001,
			MobID:            5,
			MobType:          MobTypeMistWolf,
			PosX:             10.5,
			PosY:             0.0,
			PosZ:             -15.2,
			RotY:             45.0,
			IsLooted:         false,
			RemainingSeconds: 118,
		},
		{
			CorpseID:         1002,
			MobID:            9,
			MobType:          MobTypeAlphaWolf,
			PosX:             -22.0,
			PosY:             1.5,
			PosZ:             30.0,
			RotY:             90.0,
			IsLooted:         true,
			RemainingSeconds: 45,
		},
	}

	data := SerializeCorpseSnapshot(snapshots)
	expectedSize := CorpseSnapshotHeaderSize + len(snapshots)*CorpseSnapshotEntrySize
	if len(data) != expectedSize {
		t.Fatalf("esperava %d bytes, obteve %d", expectedSize, len(data))
	}
	if data[0] != PacketTypeCorpseSnapshot {
		t.Fatalf("esperava opcode 0x3E, obteve 0x%02x", data[0])
	}

	parsed, err := DeserializeCorpseSnapshot(data)
	if err != nil {
		t.Fatalf("erro ao decodificar CORPSE_SNAPSHOT: %v", err)
	}
	if len(parsed) != len(snapshots) {
		t.Fatalf("esperava %d snapshots, obteve %d", len(snapshots), len(parsed))
	}
	for i, s := range snapshots {
		p := parsed[i]
		if p.CorpseID != s.CorpseID || p.MobID != s.MobID || p.MobType != s.MobType ||
			math.Abs(float64(p.PosX-s.PosX)) > 0.001 ||
			math.Abs(float64(p.PosZ-s.PosZ)) > 0.001 ||
			p.IsLooted != s.IsLooted || p.RemainingSeconds != s.RemainingSeconds {
			t.Fatalf("snapshot #%d divergente: %+v vs %+v", i, p, s)
		}
	}
}

func TestFriendshipSyncPacket(t *testing.T) {
	npcID := uint32(100)
	points := uint16(65)
	level := uint8(4)

	data := SerializeFriendshipSync(npcID, points, level)
	if len(data) != 8 {
		t.Fatalf("esperava 8 bytes, obteve %d", len(data))
	}
	if data[0] != PacketTypeFriendshipSync {
		t.Fatalf("esperava opcode 0x24, obteve 0x%02x", data[0])
	}

	pkt, err := DeserializeFriendshipSync(data)
	if err != nil {
		t.Fatalf("falha ao deserializar: %v", err)
	}
	if pkt.NPCID != npcID || pkt.Points != points || pkt.Level != level {
		t.Fatalf("dados divergentes: %+v vs esperado (ID: %d, Pts: %d, Lvl: %d)", pkt, npcID, points, level)
	}
}

func TestNewInventoryPackets(t *testing.T) {
	a := SerializeAllocateStat(7, StatIDCON, 12)
	var ap AllocateStatPacket
	if err := DeserializeAllocateStat(a[:], &ap); err != nil || ap.Amount != 12 || ap.StatID != StatIDCON {
		t.Fatalf("0x37 com Amount: %+v %v", ap, err)
	}
	if err := DeserializeAllocateStat(a[:6], &ap); err != nil || ap.Amount != 1 {
		t.Fatal("0x37 legado deveria assumir Amount = 1")
	}
	u := SerializeUseOrEquipItem(7, 0, ItemActionUnequip, SlotOffHand)
	var up UseOrEquipItemPacket
	if err := DeserializeUseOrEquipItem(u[:], &up); err != nil || up.Action != ItemActionUnequip || up.SlotIndex != SlotOffHand {
		t.Fatalf("0x39 desequipar: %+v", up)
	}
	items := []GroundItemEntry{{DropID: 9, ItemID: ItemIronOre, Quantity: 2, X: 1.5, Z: -3}}
	got, err := DeserializeGroundItemsSync(SerializeGroundItemsSync(items))
	if err != nil || len(got) != 1 || got[0] != items[0] {
		t.Fatalf("0x42: %+v %v", got, err)
	}
}

func TestAutopsyQualityPacket(t *testing.T) {
	b := SerializeSubmitAutopsyResult(1, 2, 3, QualityCommon, 57)
	var p SubmitAutopsyResultPacket
	if err := DeserializeSubmitAutopsyResult(b[:], &p); err != nil || p.Quality != 57 || p.OrganIndex != 3 {
		t.Fatalf("0x3D com Qualidade: %+v", p)
	}
	if err := DeserializeSubmitAutopsyResult(b[:11], &p); err != nil || p.Quality != QualityFromTier(QualityCommon) {
		t.Fatal("0x3D antigo deveria converter o tier em Qualidade")
	}
}
