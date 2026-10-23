package world

import (
	"sync"

	"lunaria/server/internal/protocol"
)

// TrainingDummy representa um Boneco de Treino para teste de combate e combos.
type TrainingDummy struct {
	mu     sync.RWMutex
	ID     uint32
	ZoneID uint8 // Zona instanciada (0 a 8)
	Name   string
	PosX   float32
	PosY   float32
	PosZ   float32
	RotY   float32
	HP     uint16
	MaxHP  uint16
}

// NewTrainingDummy cria uma instância de boneco de treino com 1000 HP na Vila (ZoneID = 0).
func NewTrainingDummy(id uint32, name string, x, y, z, rotY float32) *TrainingDummy {
	return &TrainingDummy{
		ID:     id,
		ZoneID: ZoneVillage,
		Name:   name,
		PosX:   x,
		PosY:   y,
		PosZ:   z,
		RotY:   rotY,
		HP:     1000,
		MaxHP:  1000,
	}
}

// TakeDamage subtrai dano do boneco de treino. Se zerar, restaura imediatamente para 1000 HP.
func (d *TrainingDummy) TakeDamage(amount uint16) (newHP uint16, reset bool) {
	d.mu.Lock()
	defer d.mu.Unlock()

	if amount >= d.HP {
		d.HP = d.MaxHP // Restaura o HP para 1000 quando zerar
		return d.HP, true
	}

	d.HP -= amount
	return d.HP, false
}

// GetHP retorna o HP e MaxHP thread-safe.
func (d *TrainingDummy) GetHP() (uint16, uint16) {
	d.mu.RLock()
	defer d.mu.RUnlock()
	return d.HP, d.MaxHP
}

// GetPos retorna as coordenadas do boneco de treino.
func (d *TrainingDummy) GetPos() (float32, float32, float32) {
	d.mu.RLock()
	defer d.mu.RUnlock()
	return d.PosX, d.PosY, d.PosZ
}

// ToSnapshot converte o boneco para formato NPCSnapshot para difusão na rede a 30 Hz.
func (d *TrainingDummy) ToSnapshot() protocol.NPCSnapshot {
	d.mu.RLock()
	defer d.mu.RUnlock()
	return protocol.NPCSnapshot{
		NPCID: d.ID,
		PosX:  d.PosX,
		PosY:  d.PosY,
		PosZ:  d.PosZ,
		RotY:  d.RotY,
		State: 0, // Parado
	}
}

// GetZone retorna a ZoneID do boneco de treino.
func (d *TrainingDummy) GetZone() uint8 {
	d.mu.RLock()
	defer d.mu.RUnlock()
	return d.ZoneID
}

// SetZone define a ZoneID do boneco de treino.
func (d *TrainingDummy) SetZone(zoneID uint8) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.ZoneID = zoneID
}
