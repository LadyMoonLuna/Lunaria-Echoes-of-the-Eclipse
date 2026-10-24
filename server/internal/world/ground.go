package world

import (
	"sync"
	"time"
)

// GroundItem é um item largado no chão que qualquer jogador pode pegar.
type GroundItem struct {
	DropID    uint32
	ItemID    ItemID
	Quantity  uint8
	Quality   uint8 // Qualidade de cada unidade da pilha largada
	X, Z      float32
	ZoneID    uint8
	DroppedAt time.Time
}

// GroundItemLifetime: itens somem do chão depois deste tempo.
const GroundItemLifetime = 5 * time.Minute

// PickupRange é a distância máxima (m) para pegar um item do chão.
const PickupRange float32 = 4.0

// GroundItemManager guarda os itens no chão de todas as zonas.
type GroundItemManager struct {
	mu     sync.Mutex
	nextID uint32
	items  map[uint32]*GroundItem
}

func NewGroundItemManager() *GroundItemManager {
	return &GroundItemManager{nextID: 1, items: make(map[uint32]*GroundItem)}
}

// Drop cria um item no chão e devolve uma cópia dele.
func (g *GroundItemManager) Drop(itemID ItemID, qty, quality uint8, x, z float32, zone uint8) GroundItem {
	g.mu.Lock()
	defer g.mu.Unlock()
	it := &GroundItem{DropID: g.nextID, ItemID: itemID, Quantity: qty, Quality: quality, X: x, Z: z, ZoneID: zone, DroppedAt: time.Now()}
	g.nextID++
	g.items[it.DropID] = it
	return *it
}

// TryPickup remove o item se o jogador estiver na mesma zona e a até PickupRange metros.
func (g *GroundItemManager) TryPickup(dropID uint32, px, pz float32, zone uint8) (GroundItem, bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	it, ok := g.items[dropID]
	if !ok || it.ZoneID != zone {
		return GroundItem{}, false
	}
	dx, dz := it.X-px, it.Z-pz
	if dx*dx+dz*dz > PickupRange*PickupRange {
		return GroundItem{}, false
	}
	delete(g.items, dropID)
	return *it, true
}

// InZone lista os itens no chão de uma zona.
func (g *GroundItemManager) InZone(zone uint8) []GroundItem {
	g.mu.Lock()
	defer g.mu.Unlock()
	out := make([]GroundItem, 0)
	for _, it := range g.items {
		if it.ZoneID == zone {
			out = append(out, *it)
		}
	}
	return out
}

// Expire remove itens antigos e devolve as zonas afetadas.
func (g *GroundItemManager) Expire() []uint8 {
	g.mu.Lock()
	defer g.mu.Unlock()
	zones := map[uint8]bool{}
	for id, it := range g.items {
		if time.Since(it.DroppedAt) > GroundItemLifetime {
			zones[it.ZoneID] = true
			delete(g.items, id)
		}
	}
	out := make([]uint8, 0, len(zones))
	for z := range zones {
		out = append(out, z)
	}
	return out
}
