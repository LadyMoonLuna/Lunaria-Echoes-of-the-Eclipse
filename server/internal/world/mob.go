package world

import (
	"math"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
)

// Constantes de tempo de renascimento dos mobs (75s para comuns, 180s para mini-bosses/bosses)
const (
	MobRespawnDelayCommon = 75 * time.Second
	MobRespawnDelayBoss   = 180 * time.Second
	MobRespawnDelay       = 75 * time.Second // Alias retrocompatível
)

// Mob representa um monstro vivo ou em renascimento no ecossistema do servidor.
type Mob struct {
	Mu sync.RWMutex

	ID             uint32
	ZoneID         uint8 // Zona instanciada onde o monstro reside (0 a 8)
	Name           string
	MobType        uint8
	PolymorphUntil time.Time // Polimorfado: inofensivo e vulnerável
	State          uint8
	PosX           float32
	PosY           float32
	PosZ           float32
	RotY           float32
	SpawnX         float32
	SpawnY         float32
	SpawnZ         float32
	HP             uint16
	MaxHP          uint16
	MoveSpeed      float32
	BaseSpeed      float32
	IsAlive        bool
	IsActive       bool // Ativo no mundo (controlado por eventos como Fases da Lua)
	DeadAt         time.Time

	// Mundo Vivo: zumbis (não renascem) e quem matou a criatura
	Undead         bool
	ZombieOwner    uint32 // jogador Necromante a quem o zumbi serve (0 = selvagem)
	Level          uint8
	NoRespawn      bool
	KilledByZombie bool
	ZombieTargetID uint32 // alvo atual (jogador, NPC ou mob)
	ZombieTargetIs uint8  // 1 jogador, 2 NPC, 3 mob
	ZombieSeenAt   time.Time
	ZombieNextHit  time.Time
	WanderX        float32
	WanderZ        float32

	// Rastreamento de causadores de dano (para evolução solo Varkai)
	DamageDealers map[uint32]int

	// Estado tático e temporizadores
	BlockedHits     int
	LastActionTime  time.Time
	LastCounterTime time.Time
	LastHealTime    time.Time
	TelegraphActive bool
	TelegraphUntil  time.Time
	TelegraphX      float32
	TelegraphZ      float32
	VulnerableUntil time.Time
	TargetPlayerID  uint32

	// Efeitos de controle (Crowd Control: Lentidão e Congelamento/Atordoamento)
	SlowUntil time.Time
	StunUntil time.Time

	// Quebra de Armadura (Forjador de Estrelas, Transmutador, Escultor de Almas, Mestre do Banquete): +X% de dano recebido até ArmorBreakUntil
	ArmorBreakPct   float32
	ArmorBreakUntil time.Time

	// Envenenado (Algoz Vorpal, Soberano da Teia): a Terceira Dose Letal causa dano cheio
	PoisonedUntil time.Time
}

// NewMob cria uma nova entidade de Mob inicializada no mapa.
func NewMob(id uint32, name string, mobType uint8, spawnX, spawnY, spawnZ float32, maxHP uint16, moveSpeed float32) *Mob {
	return &Mob{
		ID:            id,
		ZoneID:        ZoneVillage,
		Name:          name,
		MobType:       mobType,
		State:         protocol.MobStatePatrolIdle,
		PosX:          spawnX,
		PosY:          spawnY,
		PosZ:          spawnZ,
		RotY:          0,
		SpawnX:        spawnX,
		SpawnY:        spawnY,
		SpawnZ:        spawnZ,
		HP:            maxHP,
		MaxHP:         maxHP,
		MoveSpeed:     moveSpeed,
		BaseSpeed:     moveSpeed,
		IsAlive:       true,
		IsActive:      true,
		DamageDealers: make(map[uint32]int),
	}
}

// NewMobWithZone cria uma nova entidade de Mob inicializada com sua ZoneID respectiva.
func NewMobWithZone(id uint32, name string, mobType uint8, zoneID uint8, spawnX, spawnY, spawnZ float32, maxHP uint16, moveSpeed float32) *Mob {
	m := NewMob(id, name, mobType, spawnX, spawnY, spawnZ, maxHP, moveSpeed)
	m.ZoneID = zoneID
	return m
}

// ApplySlow aplica redução de velocidade por um tempo determinado.
func (m *Mob) ApplySlow(duration time.Duration, factor float32) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	m.SlowUntil = time.Now().Add(duration)
	m.MoveSpeed = m.BaseSpeed * (1.0 - factor)
}

// ApplyArmorBreak reduz a defesa do monstro: ele recebe +pct de dano por um tempo.
// Efeitos simultâneos não se somam; vale o mais forte, e a duração é renovada.
func (m *Mob) ApplyArmorBreak(duration time.Duration, pct float32) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	if !time.Now().Before(m.ArmorBreakUntil) || pct > m.ArmorBreakPct {
		m.ArmorBreakPct = pct
	}
	m.ArmorBreakUntil = time.Now().Add(duration)
}

// MarkPoisoned marca o monstro como envenenado por um tempo.
func (m *Mob) MarkPoisoned(d time.Duration) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	if until := time.Now().Add(d); until.After(m.PoisonedUntil) {
		m.PoisonedUntil = until
	}
}

// IsPoisoned informa se o monstro ainda está envenenado.
func (m *Mob) IsPoisoned() bool {
	m.Mu.RLock()
	defer m.Mu.RUnlock()
	return time.Now().Before(m.PoisonedUntil)
}

// HPFraction retorna a fração de vida atual do monstro (0.0 a 1.0).
func (m *Mob) HPFraction() float32 {
	m.Mu.RLock()
	defer m.Mu.RUnlock()
	if m.MaxHP == 0 {
		return 0
	}
	return float32(m.HP) / float32(m.MaxHP)
}

// ApplyStun aplica atordoamento/congelamento no monstro por um tempo determinado.
func (m *Mob) ApplyStun(duration time.Duration) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	m.StunUntil = time.Now().Add(duration)
	m.State = protocol.MobStateFleeingStunned
}

// TakeDamage aplica dano com redução de 50% se for Saqueador em Bloqueio (State = 3).
// Registra opcionalmente o ID do atacante no DamageDealers.
// Retorna o dano final aplicado, se foi bloqueado, o HP restante e se morreu.
func (m *Mob) TakeDamage(rawDamage uint16, attackerIDs ...uint32) (uint16, bool, uint16, bool) {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if !m.IsAlive || !m.IsActive {
		return 0, false, 0, false
	}

	finalDamage := rawDamage
	wasBlocked := false

	// Armadura rachada/derretida: o monstro recebe mais dano enquanto o efeito durar
	if m.ArmorBreakPct > 0 && time.Now().Before(m.ArmorBreakUntil) {
		finalDamage = uint16(float32(finalDamage) * (1.0 + m.ArmorBreakPct))
	}

	// Saqueador Deserdado com escudo levantado reduz dano em 50%
	if m.MobType == protocol.MobTypeOutcastRaider && m.State == protocol.MobStateBlocking {
		finalDamage = finalDamage / 2
		if finalDamage == 0 && rawDamage > 0 {
			finalDamage = 1
		}
		wasBlocked = true
		m.BlockedHits++
	}

	if len(attackerIDs) > 0 && attackerIDs[0] > 0 {
		if m.DamageDealers == nil {
			m.DamageDealers = make(map[uint32]int)
		}
		m.DamageDealers[attackerIDs[0]] += int(finalDamage)
	}

	if finalDamage >= m.HP {
		m.HP = 0
		m.IsAlive = false
		m.State = protocol.MobStateDead
		m.DeadAt = time.Now()
		return finalDamage, wasBlocked, 0, true
	}

	m.HP -= finalDamage
	return finalDamage, wasBlocked, m.HP, false
}

// Heal restaura HP do monstro até o limite de MaxHP.
func (m *Mob) Heal(amount uint16) uint16 {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if !m.IsAlive {
		return 0
	}

	m.HP += amount
	if m.HP > m.MaxHP {
		m.HP = m.MaxHP
	}
	return m.HP
}

// GetRespawnDelay retorna a duração autoritativa de renascimento da criatura.
func (m *Mob) GetRespawnDelay() time.Duration {
	switch m.MobType {
	case protocol.MobTypeAlphaWolf, protocol.MobTypeLycanthropeAlpha,
		protocol.MobTypeInquisitorVex, protocol.MobTypeCommanderVaelen,
		protocol.MobTypeMalakorHeraldEclipse, protocol.MobTypeArachnaQueen,
		protocol.MobTypeStitchedChimeraZero, protocol.MobTypeYmirFrostPatriarch,
		protocol.MobTypeLordVesperianVampire:
		return MobRespawnDelayBoss
	default:
		return MobRespawnDelayCommon
	}
}

// CheckRespawn verifica e executa o renascimento automático (75s comuns, 180s bosses).
func (m *Mob) CheckRespawn() bool {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if m.IsAlive || m.NoRespawn {
		return false
	}

	if time.Since(m.DeadAt) >= m.GetRespawnDelay() {
		m.KilledByZombie = false
		m.HP = m.MaxHP
		m.PosX = m.SpawnX
		m.PosY = m.SpawnY
		m.PosZ = m.SpawnZ
		m.RotY = 0
		m.State = protocol.MobStatePatrolIdle
		m.IsAlive = true
		m.BlockedHits = 0
		m.TelegraphActive = false
		m.VulnerableUntil = time.Time{}
		m.SlowUntil = time.Time{}
		m.StunUntil = time.Time{}
		m.MoveSpeed = m.BaseSpeed
		m.DamageDealers = make(map[uint32]int)
		return true
	}

	return false
}

// GetDamageDealers retorna uma cópia do mapa de causadores de dano thread-safe.
func (m *Mob) GetDamageDealers() map[uint32]int {
	m.Mu.RLock()
	defer m.Mu.RUnlock()

	copyMap := make(map[uint32]int, len(m.DamageDealers))
	for k, v := range m.DamageDealers {
		copyMap[k] = v
	}
	return copyMap
}

// SetActive define se o mob está ativo no mundo thread-safe.
func (m *Mob) SetActive(active bool) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	m.IsActive = active
	if !active {
		m.DamageDealers = make(map[uint32]int)
	}
}

// IsMobActive retorna se o mob está ativo no mundo thread-safe.
func (m *Mob) IsMobActive() bool {
	m.Mu.RLock()
	defer m.Mu.RUnlock()
	return m.IsActive
}

// MoveTowards desloca o mob suavemente em direção a uma coordenada alvo respeitando velocidade, dt e distância de parada.
func (m *Mob) MoveTowards(targetX, targetZ float32, speed float32, dt float32) {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if !m.IsAlive || !m.IsActive {
		return
	}

	// Se estiver congelado ou atordoado (Nova de Gelo), não se desloca
	if time.Now().Before(m.StunUntil) {
		return
	}

	// Restaura velocidade original se o efeito de lentidão (Estrepes) expirou
	if !m.SlowUntil.IsZero() && time.Now().After(m.SlowUntil) && m.MoveSpeed < m.BaseSpeed {
		m.MoveSpeed = m.BaseSpeed
	}

	effectiveSpeed := m.MoveSpeed
	if speed > 0 && speed < effectiveSpeed {
		effectiveSpeed = speed
	}

	// Distância de parada durante perseguição para evitar sobreposição total (0.0m)
	var stopDist float32 = 0.0
	if m.State == protocol.MobStateChasing {
		if m.MobType == protocol.MobTypeArachnaQueen || m.MobType == protocol.MobTypeYmirFrostPatriarch ||
			m.MobType == protocol.MobTypeLordVesperianVampire || m.MobType == protocol.MobTypeStitchedChimeraZero {
			stopDist = 2.4
		} else if m.MobType == protocol.MobTypeIronEnforcer || m.MobType == protocol.MobTypeLycanthropeAlpha {
			stopDist = 2.2
		} else {
			stopDist = 1.6
		}
	}

	dx := targetX - m.PosX
	dz := targetZ - m.PosZ
	dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))

	if dist <= stopDist+0.05 {
		return
	}

	// Ajusta orientação Y
	m.RotY = float32(math.Atan2(float64(dx), float64(dz)))

	step := effectiveSpeed * dt
	var nextX, nextZ float32
	remainingDist := dist - stopDist
	if step >= remainingDist {
		ratio := remainingDist / dist
		nextX = m.PosX + dx*ratio
		nextZ = m.PosZ + dz*ratio
	} else {
		nextX = m.PosX + (dx/dist)*step
		nextZ = m.PosZ + (dz/dist)*step
	}

	m.PosX, m.PosZ = ClampToZoneBounds(m.ZoneID, nextX, nextZ)
}

// SetState define o estado atual do monstro thread-safe.
func (m *Mob) SetState(state uint8) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	m.State = state

	// Se for Executor de Ferro entrando em vulnerabilidade (State = 4)
	if state == protocol.MobStateFleeingStunned && m.MobType == protocol.MobTypeIronEnforcer {
		if m.VulnerableUntil.IsZero() || time.Now().After(m.VulnerableUntil) {
			m.VulnerableUntil = time.Now().Add(2 * time.Second)
		}
	} else if state != protocol.MobStateFleeingStunned && m.MobType == protocol.MobTypeIronEnforcer {
		m.VulnerableUntil = time.Time{}
		m.MoveSpeed = m.BaseSpeed
	}
}

// CheckVulnerabilityExpired verifica se o tempo de vulnerabilidade expirou e restaura o mob.
func (m *Mob) CheckVulnerabilityExpired() bool {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if !m.IsAlive {
		return false
	}

	if m.State == protocol.MobStateFleeingStunned && !m.VulnerableUntil.IsZero() && time.Now().After(m.VulnerableUntil) {
		m.State = protocol.MobStatePatrolIdle
		m.VulnerableUntil = time.Time{}
		m.MoveSpeed = m.BaseSpeed
		return true
	}

	return false
}

// GetSnapshot retorna os dados do mob para serialização no pacote 0x14 MOB_SNAPSHOT.
func (m *Mob) ToSnapshot() protocol.MobSnapshot {
	m.Mu.RLock()
	defer m.Mu.RUnlock()

	return protocol.MobSnapshot{
		MobID:   m.ID,
		MobType: m.MobType,
		State:   m.State,
		PosX:    m.PosX,
		PosY:    m.PosY,
		PosZ:    m.PosZ,
		RotY:    m.RotY,
		HP:      m.HP,
		MaxHP:   m.MaxHP,
	}
}

// MobManager gerencia todos os monstros ativos no mundo e seus renascimentos.
type MobManager struct {
	Mu   sync.RWMutex
	Mobs map[uint32]*Mob
}

// NewMobManager inicializa todas as criaturas e raid bosses nas suas respectivas zonas (600x600m).
func NewMobManager() *MobManager {
	mm := &MobManager{
		Mobs: make(map[uint32]*Mob),
	}

	// =========================================================================
	// 1. ZONE 1: BOSQUE SUSSURRANTE (ZoneForest = 1, 600x600m)
	// =========================================================================
	mm.Mobs[201] = NewMobWithZone(201, "Lobo da Bruma", protocol.MobTypeMistWolf, ZoneForest, 55.0, 0.0, -45.0, 220, 4.2)
	mm.Mobs[202] = NewMobWithZone(202, "Lobo da Bruma", protocol.MobTypeMistWolf, ZoneForest, 65.0, 0.0, -52.0, 220, 4.2)

	// Lobo Alfa (ID 207) — Ativo na Lua Cheia
	mob207 := NewMobWithZone(207, "Lobo Alfa", protocol.MobTypeAlphaWolf, ZoneForest, 75.0, 0.0, -60.0, 750, 4.6)
	mob207.IsActive = false
	mm.Mobs[207] = mob207

	// Licantropo Alfa (ID 208) — Raid Boss Secreto (Desperta na Lua de Sangue)
	mob208 := NewMobWithZone(208, "Licantropo Alfa", protocol.MobTypeLycanthropeAlpha, ZoneForest, 88.0, 0.0, -72.0, 2200, 4.4)
	mob208.IsActive = false
	mm.Mobs[208] = mob208

	// MobType 25: Javali Selvagem (140 HP) — vara de javalis perto da entrada do Bosque
	boarSpawns := [][2]float32{{20, 230}, {-25, 215}, {38, 205}, {-42, 248}, {8, 185}, {-15, 192}, {55, 175}, {-60, 200}}
	for i, sp := range boarSpawns {
		id := uint32(230 + i)
		mm.Mobs[id] = NewMobWithZone(id, "Javali Selvagem", protocol.MobTypeWildBoar, ZoneForest, sp[0], 0.0, sp[1], 140, 3.6)
	}

	// MobType 15: Aranha Tecelã da Bruma (380 HP)
	mm.Mobs[215] = NewMobWithZone(215, "Aranha Tecelã da Bruma", protocol.MobTypeMistWeaverSpider, ZoneForest, 105.0, 0.0, -100.0, 380, 3.8)
	mm.Mobs[216] = NewMobWithZone(216, "Aranha Tecelã da Bruma", protocol.MobTypeMistWeaverSpider, ZoneForest, 115.0, 0.0, -110.0, 380, 3.8)

	// MobType 16: Arachna, a Rainha Tecelã (Raid Boss - 6800 HP em (120, -120))
	mm.Mobs[217] = NewMobWithZone(217, "Arachna, a Rainha Tecelã", protocol.MobTypeArachnaQueen, ZoneForest, 120.0, 0.0, -120.0, 6800, 3.4)

	// =========================================================================
	// 2. ZONE 2: RUÍNAS DA VIGÍLIA & NORTE GELADO (ZoneRuins = 2, 600x600m)
	// =========================================================================
	mm.Mobs[203] = NewMobWithZone(203, "Saqueador Deserdado", protocol.MobTypeOutcastRaider, ZoneRuins, -15.0, 0.0, 70.0, 350, 3.2)
	mm.Mobs[204] = NewMobWithZone(204, "Besteiro da Vigília", protocol.MobTypeVigilCrossbowman, ZoneRuins, 15.0, 0.0, 72.0, 200, 3.5)
	mm.Mobs[205] = NewMobWithZone(205, "Acólito do Eclipse", protocol.MobTypeEclipseAcolyte, ZoneRuins, -8.0, 0.0, 80.0, 240, 3.0)
	mm.Mobs[206] = NewMobWithZone(206, "Executor de Ferro", protocol.MobTypeIronEnforcer, ZoneRuins, 8.0, 0.0, 82.0, 650, 2.4)
	mm.Mobs[213] = NewMobWithZone(213, "Comandante Vaelen", protocol.MobTypeCommanderVaelen, ZoneRuins, 0.0, 0.0, 90.0, 3200, 3.5)

	// MobType 20: Golem de Gelo Antigo (720 HP - Norte Nevado)
	mm.Mobs[223] = NewMobWithZone(223, "Golem de Gelo Antigo", protocol.MobTypeAncientIceGolem, ZoneRuins, -40.0, 0.0, 130.0, 720, 2.2)
	mm.Mobs[224] = NewMobWithZone(224, "Golem de Gelo Antigo", protocol.MobTypeAncientIceGolem, ZoneRuins, 40.0, 0.0, 130.0, 720, 2.2)

	// MobType 21: Draco de Geada Selvagem (950 HP)
	mm.Mobs[225] = NewMobWithZone(225, "Draco de Geada Selvagem", protocol.MobTypeWildFrostDrake, ZoneRuins, 0.0, 0.0, 175.0, 950, 4.0)

	// MobType 22: Ymir, o Patriarca Jotunar (Boss - 5200 HP em (0, 150))
	mm.Mobs[226] = NewMobWithZone(226, "Ymir, o Patriarca Jotunar", protocol.MobTypeYmirFrostPatriarch, ZoneRuins, 0.0, 0.0, 150.0, 5200, 2.8)

	// =========================================================================
	// 3. ZONE 3: SANTUÁRIO DO ECLIPSE (ZoneSanctuary = 3, 600x600m)
	// =========================================================================
	mm.Mobs[209] = NewMobWithZone(209, "Cultista Sombrio", protocol.MobTypeDarkCultist, ZoneSanctuary, -75.0, 0.0, 75.0, 400, 3.2)
	mm.Mobs[210] = NewMobWithZone(210, "Cultista Sombrio", protocol.MobTypeDarkCultist, ZoneSanctuary, -80.0, 0.0, 72.0, 400, 3.2)
	mm.Mobs[211] = NewMobWithZone(211, "Gárgula de Pedra", protocol.MobTypeStoneGargoyle, ZoneSanctuary, -78.0, 0.0, 82.0, 580, 3.8)
	mm.Mobs[212] = NewMobWithZone(212, "Inquisidor Vex", protocol.MobTypeInquisitorVex, ZoneSanctuary, -85.0, 0.0, 80.0, 1400, 3.4)
	mm.Mobs[214] = NewMobWithZone(214, "Malakor, o Arauto do Eclipse", protocol.MobTypeMalakorHeraldEclipse, ZoneSanctuary, -88.0, 0.0, 88.0, 7500, 3.0)

	// MobType 23: Guarda Sanguinário de Vesperian (680 HP - Noroeste Cripta)
	mm.Mobs[227] = NewMobWithZone(227, "Guarda Sanguinário de Vesperian", protocol.MobTypeVesperianBloodGuard, ZoneSanctuary, -125.0, 0.0, 125.0, 680, 3.6)
	mm.Mobs[228] = NewMobWithZone(228, "Guarda Sanguinário de Vesperian", protocol.MobTypeVesperianBloodGuard, ZoneSanctuary, -135.0, 0.0, 135.0, 680, 3.6)

	// MobType 24: Lorde Vesperian, o Progenitor Vampiro (Raid Boss Secreto - 8500 HP em (-140, 140) — Desperta à Noite/Sangue/Eclipse)
	mob229 := NewMobWithZone(229, "Lorde Vesperian, o Progenitor Vampiro", protocol.MobTypeLordVesperianVampire, ZoneSanctuary, -140.0, 0.0, 140.0, 8500, 4.2)
	mob229.IsActive = false
	mm.Mobs[229] = mob229

	// =========================================================================
	// 4. ZONE 8: ESGOTOS ANTIGOS (ZoneAncientSewers = 8, 600x600m)
	// =========================================================================
	// MobType 17: Lodo Ácido Corrosivo (320 HP)
	mm.Mobs[218] = NewMobWithZone(218, "Lodo Ácido Corrosivo", protocol.MobTypeAcidCorrosiveSlime, ZoneAncientSewers, -30.0, 0.0, 40.0, 320, 2.5)
	mm.Mobs[219] = NewMobWithZone(219, "Lodo Ácido Corrosivo", protocol.MobTypeAcidCorrosiveSlime, ZoneAncientSewers, 20.0, 0.0, -40.0, 320, 2.5)

	// MobType 18: Escorpião Abissal Gigante (540 HP)
	mm.Mobs[220] = NewMobWithZone(220, "Escorpião Abissal Gigante", protocol.MobTypeAbyssalScorpion, ZoneAncientSewers, 60.0, 0.0, 60.0, 540, 3.4)
	mm.Mobs[221] = NewMobWithZone(221, "Escorpião Abissal Gigante", protocol.MobTypeAbyssalScorpion, ZoneAncientSewers, -70.0, 0.0, -50.0, 540, 3.4)

	// MobType 19: Experimento Nº 0: A Quimera Costurada (Mini-Boss - 2800 HP)
	mm.Mobs[222] = NewMobWithZone(222, "Experimento Nº 0: A Quimera Costurada", protocol.MobTypeStitchedChimeraZero, ZoneAncientSewers, 0.0, 0.0, 110.0, 2800, 3.6)

	// =========================================================================
	// 5. ZONAS DE TRANSIÇÃO (9 a 16): criaturas coerentes com cada bioma, em covis afastados das estradas
	// =========================================================================
	type spawn struct {
		name  string
		kind  uint8
		zone  uint8
		x, z  float32
		hp    uint16
		speed float32
	}
	transition := []spawn{
		// Bosque Ralo: matilhas e varas de javalis nas clareiras
		{"Lobo da Bruma", protocol.MobTypeMistWolf, ZoneSparseWoods, -150, 90, 220, 4.2},
		{"Lobo da Bruma", protocol.MobTypeMistWolf, ZoneSparseWoods, -162, 102, 220, 4.2},
		{"Lobo da Bruma", protocol.MobTypeMistWolf, ZoneSparseWoods, 190, -150, 220, 4.2},
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneSparseWoods, -90, -160, 140, 3.6},
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneSparseWoods, -102, -170, 140, 3.6},
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneSparseWoods, 60, 180, 140, 3.6},
		// Campos Rasteiros: javalis no capim e saqueadores errantes
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneGrasslands, -170, 40, 140, 3.6},
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneGrasslands, -182, 52, 140, 3.6},
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneGrasslands, 200, -60, 140, 3.6},
		{"Saqueador Deserdado", protocol.MobTypeOutcastRaider, ZoneGrasslands, -200, -200, 350, 3.2},
		{"Saqueador Deserdado", protocol.MobTypeOutcastRaider, ZoneGrasslands, -212, -190, 350, 3.2},
		// Savana Dourada: alcateia com Lobo Alfa e javalis
		{"Lobo Alfa", protocol.MobTypeAlphaWolf, ZoneSavanna, -190, -120, 900, 4.6},
		{"Lobo da Bruma", protocol.MobTypeMistWolf, ZoneSavanna, -178, -110, 220, 4.2},
		{"Lobo da Bruma", protocol.MobTypeMistWolf, ZoneSavanna, -200, -132, 220, 4.2},
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneSavanna, 220, 160, 140, 3.6},
		{"Javali Selvagem", protocol.MobTypeWildBoar, ZoneSavanna, 232, 150, 140, 3.6},
		// Deserto de Sal: escorpiões nas dunas e lodo ácido nas poças de sal
		{"Escorpião Abissal Gigante", protocol.MobTypeAbyssalScorpion, ZoneSaltDesert, -160, -60, 540, 3.4},
		{"Escorpião Abissal Gigante", protocol.MobTypeAbyssalScorpion, ZoneSaltDesert, 170, 90, 540, 3.4},
		{"Escorpião Abissal Gigante", protocol.MobTypeAbyssalScorpion, ZoneSaltDesert, 140, -190, 540, 3.4},
		{"Lodo Ácido Corrosivo", protocol.MobTypeAcidCorrosiveSlime, ZoneSaltDesert, -210, 170, 320, 2.5},
		// Planalto dos Ventos: bandidos e besteiros nas pedras
		{"Saqueador Deserdado", protocol.MobTypeOutcastRaider, ZoneWindPlateau, -180, 120, 350, 3.2},
		{"Saqueador Deserdado", protocol.MobTypeOutcastRaider, ZoneWindPlateau, -168, 132, 350, 3.2},
		{"Besteiro da Vigília", protocol.MobTypeVigilCrossbowman, ZoneWindPlateau, -192, 140, 200, 3.5},
		{"Besteiro da Vigília", protocol.MobTypeVigilCrossbowman, ZoneWindPlateau, 210, -150, 200, 3.5},
		// Picos Gelados: golens e dracos de geada
		{"Golem de Gelo Antigo", protocol.MobTypeAncientIceGolem, ZoneFrozenPeaks, -150, 60, 720, 2.2},
		{"Golem de Gelo Antigo", protocol.MobTypeAncientIceGolem, ZoneFrozenPeaks, 200, -40, 720, 2.2},
		{"Draco de Geada Selvagem", protocol.MobTypeWildFrostDrake, ZoneFrozenPeaks, -60, 230, 950, 4.0},
		// Colinas de Basalto: gárgulas e executores nas pedreiras
		{"Gárgula de Pedra", protocol.MobTypeStoneGargoyle, ZoneBasaltHills, 60, 190, 580, 3.8},
		{"Gárgula de Pedra", protocol.MobTypeStoneGargoyle, ZoneBasaltHills, -40, -200, 580, 3.8},
		{"Executor de Ferro", protocol.MobTypeIronEnforcer, ZoneBasaltHills, 180, -170, 650, 2.4},
		// Pântano das Brumas: lodos e aranhas no brejo
		{"Lodo Ácido Corrosivo", protocol.MobTypeAcidCorrosiveSlime, ZoneMistMarsh, 80, 150, 320, 2.5},
		{"Lodo Ácido Corrosivo", protocol.MobTypeAcidCorrosiveSlime, ZoneMistMarsh, -120, -60, 320, 2.5},
		{"Aranha Tecelã da Bruma", protocol.MobTypeMistWeaverSpider, ZoneMistMarsh, -190, 170, 380, 3.8},
		{"Aranha Tecelã da Bruma", protocol.MobTypeMistWeaverSpider, ZoneMistMarsh, -178, 182, 380, 3.8},
		{"Aranha Tecelã da Bruma", protocol.MobTypeMistWeaverSpider, ZoneMistMarsh, 150, -180, 380, 3.8},
	}
	for i, sp := range transition {
		id := uint32(300 + i)
		mm.Mobs[id] = NewMobWithZone(id, sp.name, sp.kind, sp.zone, sp.x, 0.0, sp.z, sp.hp, sp.speed)
	}

	// 6. Fauna: 10 espécies por região (bichos de terra, aves e criaturas d'água)
	mm.spawnFauna()

	return mm
}

// GetMob busca um mob por ID thread-safe.
func (mm *MobManager) GetMob(id uint32) *Mob {
	mm.Mu.RLock()
	defer mm.Mu.RUnlock()
	return mm.Mobs[id]
}

// AddDynamicMob registra uma criatura criada em tempo de jogo (ex.: zumbis) com um ID livre a partir de 5000.
func (mm *MobManager) AddDynamicMob(m *Mob) uint32 {
	mm.Mu.Lock()
	defer mm.Mu.Unlock()
	id := uint32(5000)
	for {
		if _, used := mm.Mobs[id]; !used {
			break
		}
		id++
	}
	m.ID = id
	mm.Mobs[id] = m
	return id
}

// RemoveMob tira a criatura do mundo para sempre.
func (mm *MobManager) RemoveMob(id uint32) {
	mm.Mu.Lock()
	defer mm.Mu.Unlock()
	delete(mm.Mobs, id)
}

// GetAllMobs retorna a lista de todos os mobs.
func (mm *MobManager) GetAllMobs() []*Mob {
	mm.Mu.RLock()
	defer mm.Mu.RUnlock()

	list := make([]*Mob, 0, len(mm.Mobs))
	for _, m := range mm.Mobs {
		list = append(list, m)
	}
	return list
}

// GetAllMobsByZone retorna todos os monstros pertencentes a uma zona específica.
func (mm *MobManager) GetAllMobsByZone(zoneID uint8) []*Mob {
	mm.Mu.RLock()
	defer mm.Mu.RUnlock()

	var list []*Mob
	for _, m := range mm.Mobs {
		if m.GetZone() == zoneID {
			list = append(list, m)
		}
	}
	return list
}

// UpdateRespawns verifica se algum mob morto deve renascer (após 12s).
func (mm *MobManager) UpdateRespawns() []uint32 {
	mm.Mu.RLock()
	defer mm.Mu.RUnlock()

	var respawned []uint32
	for id, m := range mm.Mobs {
		if m.CheckRespawn() {
			respawned = append(respawned, id)
		}
	}
	return respawned
}

// GetSnapshots extrai os snapshots de todos os mobs vivos para o pacote 0x14.
func (mm *MobManager) GetSnapshots() []protocol.MobSnapshot {
	mm.Mu.RLock()
	defer mm.Mu.RUnlock()

	snapshots := make([]protocol.MobSnapshot, 0, len(mm.Mobs))
	for _, m := range mm.Mobs {
		// Inclui apenas mobs ativos que estejam vivos ou em animação recente de morte
		m.Mu.RLock()
		alive := m.IsAlive
		active := m.IsActive
		deadAt := m.DeadAt
		m.Mu.RUnlock()
		if active && (alive || time.Since(deadAt) < 2*time.Second) {
			snapshots = append(snapshots, m.ToSnapshot())
		}
	}
	return snapshots
}

// GetSnapshotsByZone extrai os snapshots de mobs vivos pertencentes a uma ZoneID específica.
func (mm *MobManager) GetSnapshotsByZone(zoneID uint8) []protocol.MobSnapshot {
	mm.Mu.RLock()
	defer mm.Mu.RUnlock()

	snapshots := make([]protocol.MobSnapshot, 0, len(mm.Mobs))
	for _, m := range mm.Mobs {
		m.Mu.RLock()
		alive := m.IsAlive
		active := m.IsActive
		deadAt := m.DeadAt
		mZone := m.ZoneID
		m.Mu.RUnlock()
		if mZone == zoneID && active && (alive || time.Since(deadAt) < 2*time.Second) {
			snapshots = append(snapshots, m.ToSnapshot())
		}
	}
	return snapshots
}

// GetZone retorna o ZoneID onde o mob está localizado.
func (m *Mob) GetZone() uint8 {
	m.Mu.RLock()
	defer m.Mu.RUnlock()
	return m.ZoneID
}

// SetZone define o ZoneID do mob.
func (m *Mob) SetZone(zoneID uint8) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	m.ZoneID = zoneID
}
