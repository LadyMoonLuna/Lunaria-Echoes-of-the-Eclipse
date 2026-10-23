package world

import "lunaria/server/internal/protocol"

// Dinheiro inicial (para testes)
const (
	StartingGold         uint32 = 250
	StartingEclipseCoins uint32 = 10
)

// currentWeightLocked soma o peso da mochila e dos itens equipados.
func (p *Player) currentWeightLocked() float32 {
	var w float32
	for id, qty := range p.Inventory {
		if qty > 0 {
			w += GetItemInfo(id).Weight * float32(qty)
		}
	}
	for _, id := range p.EquippedSlots {
		if id > 0 {
			w += GetItemInfo(id).Weight
		}
	}
	return w
}

// maxWeightLocked usa FOR e CON do personagem (sem bônus de equipamento).
func (p *Player) maxWeightLocked() float32 {
	return CalculateMaxWeight(p.RaceID, p.STR, p.CON)
}

func (p *Player) weightSpeedLocked() float32 {
	return WeightSpeedMultiplier(p.currentWeightLocked(), p.maxWeightLocked())
}

// WeightStatus retorna peso atual, peso máximo e multiplicador de velocidade.
func (p *Player) WeightStatus() (current, max, speed float32) {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	current = p.currentWeightLocked()
	max = p.maxWeightLocked()
	return current, max, WeightSpeedMultiplier(current, max)
}

// IsOverloaded indica 130%+ do peso máximo (imóvel).
func (p *Player) IsOverloaded() bool {
	_, _, speed := p.WeightStatus()
	return speed <= 0
}

// CanSprint: acima de 100% do peso o personagem anda devagar e sem Sprint.
func (p *Player) CanSprint() bool {
	cur, max, _ := p.WeightStatus()
	return cur <= max
}

// InventoryStatus monta o bloco de dinheiro e peso do pacote 0x38.
func (p *Player) InventoryStatus() protocol.InventoryStatus {
	p.Mu.RLock()
	gold, eclipse := p.Gold, p.EclipseCoins
	p.Mu.RUnlock()
	cur, max, speed := p.WeightStatus()
	return protocol.InventoryStatus{
		Gold:          gold,
		EclipseCoins:  eclipse,
		CurrentWeight: cur,
		MaxWeight:     max,
		SpeedPercent:  uint8(speed*100 + 0.5),
	}
}

// AddGold soma Sollares (sem estourar o uint32) e retorna o novo saldo.
func (p *Player) AddGold(amount uint32) uint32 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.Gold > ^uint32(0)-amount {
		p.Gold = ^uint32(0)
	} else {
		p.Gold += amount
	}
	return p.Gold
}

// equipDEFLocked soma a defesa física dos itens equipados.
func (p *Player) equipDEFLocked() uint16 {
	var def uint16
	for _, id := range p.EquippedSlots {
		if id > 0 {
			def += GetItemInfo(id).BonusDEF
		}
	}
	return def
}

// EquipBonuses retorna ATK, DEF e MDEF somados dos itens equipados.
func (p *Player) EquipBonuses() (atk, def, mdef uint16) {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	for _, id := range p.EquippedSlots {
		if id > 0 {
			info := GetItemInfo(id)
			atk += info.BonusATK
			def += info.BonusDEF
			mdef += info.BonusMDEF
		}
	}
	return atk, def, mdef
}

// TakeInventorySlot remove até qty unidades do item na posição slotIndex da lista da mochila
// (mesma ordem enviada no 0x38). Retorna o item e a quantidade removida.
func (p *Player) TakeInventorySlot(slotIndex, qty uint8) (uint8, uint8) {
	slots := p.GetInventorySlots()
	if int(slotIndex) >= len(slots) || qty == 0 {
		return 0, 0
	}
	itemID := slots[slotIndex].ItemID
	p.Mu.Lock()
	defer p.Mu.Unlock()
	have := p.Inventory[itemID]
	if have == 0 {
		return 0, 0
	}
	if qty > have {
		qty = have
	}
	p.Inventory[itemID] = have - qty
	if p.Inventory[itemID] == 0 {
		delete(p.Inventory, itemID)
	}
	return itemID, qty
}
