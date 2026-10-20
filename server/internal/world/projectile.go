package world

import (
	"math"
	"sync"
	"sync/atomic"

	"lunaria/server/internal/protocol"
)

// Projectile representa um projétil físico ativo simulado no servidor.
type Projectile struct {
	ID           uint32
	OwnerID      uint32
	ProjType     uint8
	ActionType   uint8
	PosX         float32
	PosY         float32
	PosZ         float32
	DirX         float32
	DirZ         float32
	Speed        float32
	MaxRange     float32
	Traveled     float32
	SplashRadius float32
	IsActive     bool
	HitTargets   map[uint32]bool // Guarda alvos já atingidos (para projéteis perfurantes)
}

// ProjectileManager controla a criação, atualização física e ciclo de vida de projéteis 3D.
type ProjectileManager struct {
	mu          sync.RWMutex
	nextID      atomic.Uint32
	projectiles []*Projectile
}

// NewProjectileManager inicializa o gerenciador de projéteis com IDs únicos a partir de 1000.
func NewProjectileManager() *ProjectileManager {
	pm := &ProjectileManager{
		projectiles: make([]*Projectile, 0, 64),
	}
	pm.nextID.Store(1000)
	return pm
}

// SpawnWithAction cria e registra um novo projétil com tipo de ação e raio de detonação em área.
func (pm *ProjectileManager) SpawnWithAction(ownerID uint32, projType, actionType uint8, startX, startY, startZ, dirX, dirZ, speed, maxRange, splashRadius float32) *Projectile {
	lenDir := float32(math.Sqrt(float64(dirX*dirX + dirZ*dirZ)))
	if lenDir < 0.001 {
		dirX = 0.0
		dirZ = 1.0
	} else {
		dirX /= lenDir
		dirZ /= lenDir
	}

	p := &Projectile{
		ID:           pm.nextID.Add(1),
		OwnerID:      ownerID,
		ProjType:     projType,
		ActionType:   actionType,
		PosX:         startX,
		PosY:         startY,
		PosZ:         startZ,
		DirX:         dirX,
		DirZ:         dirZ,
		Speed:        speed,
		MaxRange:     maxRange,
		Traveled:     0,
		SplashRadius: splashRadius,
		IsActive:     true,
		HitTargets:   make(map[uint32]bool),
	}

	pm.mu.Lock()
	pm.projectiles = append(pm.projectiles, p)
	pm.mu.Unlock()

	return p
}

// Spawn cria e registra um novo projétil no mundo com direção normalizada (retrocompatível).
func (pm *ProjectileManager) Spawn(ownerID uint32, projType uint8, startX, startY, startZ, dirX, dirZ, speed, maxRange float32) *Projectile {
	return pm.SpawnWithAction(ownerID, projType, protocol.ActionBasicAttack, startX, startY, startZ, dirX, dirZ, speed, maxRange, 0.0)
}

// GetActiveProjectiles retorna uma cópia rasa da lista de projéteis ativos para iteração.
func (pm *ProjectileManager) GetActiveProjectiles() []*Projectile {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	active := make([]*Projectile, len(pm.projectiles))
	copy(active, pm.projectiles)
	return active
}

// Cleanup remove projéteis inativos ou que atingiram o alcance máximo.
func (pm *ProjectileManager) Cleanup() {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	filtered := pm.projectiles[:0]
	for _, p := range pm.projectiles {
		if p.IsActive && p.Traveled < p.MaxRange {
			filtered = append(filtered, p)
		}
	}
	pm.projectiles = filtered
}
