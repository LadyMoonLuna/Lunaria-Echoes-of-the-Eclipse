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

	ID        uint32
	Name      string
	MobType   uint8
	State     uint8
	PosX      float32
	PosY      float32
	PosZ      float32
	RotY      float32
	SpawnX    float32
	SpawnY    float32
	SpawnZ    float32
	HP        uint16
	MaxHP     uint16
	MoveSpeed float32
	BaseSpeed float32
	IsAlive   bool
	IsActive  bool // Ativo no mundo (controlado por eventos como Fases da Lua)
	DeadAt    time.Time

	// Rastreamento de causadores de dano (para evolução solo Varkai)
	DamageDealers map[uint32]int

	// Estado tático e temporizadores
	BlockedHits      int
	LastActionTime   time.Time
	LastCounterTime  time.Time
	LastHealTime     time.Time
	TelegraphActive  bool
	TelegraphUntil   time.Time
	TelegraphX       float32
	TelegraphZ       float32
	VulnerableUntil  time.Time
	TargetPlayerID   uint32

	// Efeitos de controle (Crowd Control: Lentidão e Congelamento/Atordoamento)
	SlowUntil time.Time
	StunUntil time.Time
}

// NewMob cria uma nova entidade de Mob inicializada no mapa.
func NewMob(id uint32, name string, mobType uint8, spawnX, spawnY, spawnZ float32, maxHP uint16, moveSpeed float32) *Mob {
	return &Mob{
		ID:            id,
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

// ApplySlow aplica redução de velocidade por um tempo determinado.
func (m *Mob) ApplySlow(duration time.Duration, factor float32) {
	m.Mu.Lock()
	defer m.Mu.Unlock()
	m.SlowUntil = time.Now().Add(duration)
	m.MoveSpeed = m.BaseSpeed * (1.0 - factor)
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

	// Saqueador Deserdado com escudo levantado reduz dano em 50%
	if m.MobType == protocol.MobTypeOutcastRaider && m.State == protocol.MobStateBlocking {
		finalDamage = rawDamage / 2
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
		protocol.MobTypeMalakorHeraldEclipse:
		return MobRespawnDelayBoss
	default:
		return MobRespawnDelayCommon
	}
}

// CheckRespawn verifica e executa o renascimento automático (75s comuns, 180s bosses).
func (m *Mob) CheckRespawn() bool {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if m.IsAlive {
		return false
	}

	if time.Since(m.DeadAt) >= m.GetRespawnDelay() {
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
		if m.MobType == protocol.MobTypeIronEnforcer || m.MobType == protocol.MobTypeLycanthropeAlpha {
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

	m.PosX, m.PosZ = ClampToMapBounds(nextX, nextZ)
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

// NewMobManager inicializa os 5 tipos de monstros nos locais definidos no Marco 4.
func NewMobManager() *MobManager {
	mm := &MobManager{
		Mobs: make(map[uint32]*Mob),
	}

	// 1. Bosque Sussurrante (Sudeste)
	mm.Mobs[201] = NewMob(201, "Lobo da Bruma", protocol.MobTypeMistWolf, 55.0, 0.0, -45.0, 220, 4.2)
	mm.Mobs[202] = NewMob(202, "Lobo da Bruma", protocol.MobTypeMistWolf, 65.0, 0.0, -52.0, 220, 4.2)

	// Lobo Alfa (ID 207) - Ativo na Lua Cheia
	mob207 := NewMob(207, "Lobo Alfa", protocol.MobTypeAlphaWolf, 75.0, 0.0, -60.0, 750, 4.6)
	mob207.IsActive = false
	mm.Mobs[207] = mob207

	// Licantropo Alfa (ID 208) - Boss de Raid Secreto (Desperta na Lua de Sangue)
	mob208 := NewMob(208, "Licantropo Alfa", protocol.MobTypeLycanthropeAlpha, 88.0, 0.0, -72.0, 2200, 4.4)
	mob208.IsActive = false
	mm.Mobs[208] = mob208

	// 2. Ruínas da Vigília (Norte: X: -25 a +25, Z: 65 a 95)
	mm.Mobs[203] = NewMob(203, "Saqueador Deserdado", protocol.MobTypeOutcastRaider, -15.0, 0.0, 70.0, 350, 3.2)
	mm.Mobs[204] = NewMob(204, "Besteiro da Vigília", protocol.MobTypeVigilCrossbowman, 15.0, 0.0, 72.0, 200, 3.5)
	mm.Mobs[205] = NewMob(205, "Acólito do Eclipse", protocol.MobTypeEclipseAcolyte, -8.0, 0.0, 80.0, 240, 3.0)
	mm.Mobs[206] = NewMob(206, "Executor de Ferro", protocol.MobTypeIronEnforcer, 8.0, 0.0, 82.0, 650, 2.4)
	mm.Mobs[213] = NewMob(213, "Comandante Vaelen", protocol.MobTypeCommanderVaelen, 0.0, 0.0, 90.0, 3200, 3.5)

	// 3. Santuário do Eclipse (Noroeste Distante — Centro em (-85.0, 85.0))
	mm.Mobs[209] = NewMob(209, "Cultista Sombrio", protocol.MobTypeDarkCultist, -75.0, 0.0, 75.0, 400, 3.2)
	mm.Mobs[210] = NewMob(210, "Cultista Sombrio", protocol.MobTypeDarkCultist, -80.0, 0.0, 72.0, 400, 3.2)
	mm.Mobs[211] = NewMob(211, "Gárgula de Pedra", protocol.MobTypeStoneGargoyle, -78.0, 0.0, 82.0, 580, 3.8)
	mm.Mobs[212] = NewMob(212, "Inquisidor Vex", protocol.MobTypeInquisitorVex, -85.0, 0.0, 80.0, 1400, 3.4)
	mm.Mobs[214] = NewMob(214, "Malakor, o Arauto do Eclipse", protocol.MobTypeMalakorHeraldEclipse, -88.0, 0.0, 88.0, 7500, 3.0)

	return mm
}

// GetMob busca um mob por ID thread-safe.
func (mm *MobManager) GetMob(id uint32) *Mob {
	mm.Mu.RLock()
	defer mm.Mu.RUnlock()
	return mm.Mobs[id]
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
