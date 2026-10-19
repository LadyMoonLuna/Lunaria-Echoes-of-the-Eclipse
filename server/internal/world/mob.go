package world

import (
	"math"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
)

// Constante de tempo de renascimento dos mobs (12 segundos)
const MobRespawnDelay = 12 * time.Second

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
	DeadAt    time.Time

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
}

// NewMob cria uma nova entidade de Mob inicializada no mapa.
func NewMob(id uint32, name string, mobType uint8, spawnX, spawnY, spawnZ float32, maxHP uint16, moveSpeed float32) *Mob {
	return &Mob{
		ID:        id,
		Name:      name,
		MobType:   mobType,
		State:     protocol.MobStatePatrolIdle,
		PosX:      spawnX,
		PosY:      spawnY,
		PosZ:      spawnZ,
		RotY:      0,
		SpawnX:    spawnX,
		SpawnY:    spawnY,
		SpawnZ:    spawnZ,
		HP:        maxHP,
		MaxHP:     maxHP,
		MoveSpeed: moveSpeed,
		BaseSpeed: moveSpeed,
		IsAlive:   true,
	}
}

// TakeDamage aplica dano com redução de 50% se for Saqueador em Bloqueio (State = 3).
// Retorna o dano final aplicado, se foi bloqueado, o HP restante e se morreu.
func (m *Mob) TakeDamage(rawDamage uint16) (uint16, bool, uint16, bool) {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if !m.IsAlive {
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

// CheckRespawn verifica e executa o renascimento automático após 12 segundos da morte.
func (m *Mob) CheckRespawn() bool {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if m.IsAlive {
		return false
	}

	if time.Since(m.DeadAt) >= MobRespawnDelay {
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
		m.MoveSpeed = m.BaseSpeed
		return true
	}

	return false
}

// MoveTowards desloca o mob suavemente em direção a uma coordenada alvo respeitando velocidade e dt.
func (m *Mob) MoveTowards(targetX, targetZ float32, speed float32, dt float32) {
	m.Mu.Lock()
	defer m.Mu.Unlock()

	if !m.IsAlive {
		return
	}

	dx := targetX - m.PosX
	dz := targetZ - m.PosZ
	dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))

	if dist < 0.05 {
		return
	}

	// Ajusta orientação Y
	m.RotY = float32(math.Atan2(float64(dx), float64(dz)))

	step := speed * dt
	if step > dist {
		m.PosX = targetX
		m.PosZ = targetZ
	} else {
		m.PosX += (dx / dist) * step
		m.PosZ += (dz / dist) * step
	}
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

	// 1. Lobo da Bruma (IDs 201 e 202) no Bosque Sussurrante
	mm.Mobs[201] = NewMob(201, "Lobo da Bruma", protocol.MobTypeMistWolf, 16.0, 0.0, -8.0, 220, 4.2)
	mm.Mobs[202] = NewMob(202, "Lobo da Bruma", protocol.MobTypeMistWolf, 19.0, 0.0, -6.0, 220, 4.2)

	// 2. Saqueador Deserdado (ID 203) na Estrada das Ruínas
	mm.Mobs[203] = NewMob(203, "Saqueador Deserdado", protocol.MobTypeOutcastRaider, -16.0, 0.0, 12.0, 350, 3.2)

	// 3. Besteiro da Vigília (ID 204)
	mm.Mobs[204] = NewMob(204, "Besteiro da Vigília", protocol.MobTypeVigilCrossbowman, -20.0, 0.0, 15.0, 200, 3.5)

	// 4. Acólito do Eclipse (ID 205)
	mm.Mobs[205] = NewMob(205, "Acólito do Eclipse", protocol.MobTypeEclipseAcolyte, -18.0, 0.0, 18.0, 240, 3.0)

	// 5. Executor de Ferro (ID 206) na Entrada das Ruínas
	mm.Mobs[206] = NewMob(206, "Executor de Ferro", protocol.MobTypeIronEnforcer, 0.0, 0.0, 22.0, 650, 2.4)

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
		// Inclui mobs vivos ou em animação recente de morte
		m.Mu.RLock()
		alive := m.IsAlive
		m.Mu.RUnlock()
		if alive || time.Since(m.DeadAt) < 2*time.Second {
			snapshots = append(snapshots, m.ToSnapshot())
		}
	}
	return snapshots
}
