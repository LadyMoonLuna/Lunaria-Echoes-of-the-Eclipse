package world

import (
	"sort"

	"lunaria/server/internal/protocol"
)

// Qualidade: pseudo-atributo de 0 a 100 de CADA UNIDADE de item. Mede aspectos diferentes conforme
// o item (Frescor de órgãos, Integridade de peles, Veio da madeira, Pureza de metais e cristais,
// Potência de plantas e líquidos, Condição de equipamentos) e sobe com menos erros nos minigames
// de extração/criação. Abaixo de JunkQuality o item vira lixo.
//
// A mochila guarda a contagem em Inventory[item] e, em ItemUnits[item], a Qualidade de cada unidade
// (da melhor para a pior). Código antigo que mexe só na contagem continua funcionando: as unidades
// são reconciliadas na hora de ler — unidades novas entram com a Qualidade padrão do item e, quando
// a contagem cai, saem primeiro as de pior Qualidade.
const (
	DefaultItemQuality uint8 = 75 // drops, presentes e itens sem minigame
	JunkQuality        uint8 = 35 // abaixo disso a extração/criação arruína o item
	PerfectQuality     uint8 = 80
	AnyQuality         uint8 = 255 // "qualquer unidade": usa a melhor disponível
)

// DefaultQualityFor: equipamentos e ferramentas sem criação vêm em Condição perfeita (100);
// materiais, órgãos e consumíveis de drop/presente chegam com Qualidade 75.
func DefaultQualityFor(itemID uint8) uint8 {
	if IsEquippable(itemID) {
		return 100
	}
	if _, ok := ToolsDB[itemID]; ok {
		return 100
	}
	return DefaultItemQuality
}

// JunkFor devolve o lixo que um item vira quando a Qualidade fica abaixo do limite:
// Sucata Metálica para metais, ligas, pedras e cristais; Lixo Orgânico para o resto.
func JunkFor(itemID uint8) uint8 {
	if m, ok := GetMaterial(itemID); ok {
		switch m.Category {
		case MatMetal, MatAlloy, MatStone, MatCrystal:
			return protocol.ItemMetalScrap
		}
	}
	switch itemID {
	case protocol.ItemHeavySteelPlate, protocol.ItemSteelChestplate, protocol.ItemRunicWarhammer, protocol.ItemStarforgeCore:
		return protocol.ItemMetalScrap
	}
	return protocol.ItemOrganicTrash
}

// unitsLocked reconcilia e devolve as Qualidades das unidades do item (melhor -> pior).
func (p *Player) unitsLocked(itemID uint8) []uint8 {
	if p.ItemUnits == nil {
		p.ItemUnits = make(map[uint8][]uint8)
	}
	count := int(p.Inventory[itemID])
	units := p.ItemUnits[itemID]
	for len(units) < count {
		units = insertSortedDesc(units, DefaultQualityFor(itemID))
	}
	if len(units) > count {
		units = units[:count] // saem primeiro as piores
	}
	if count == 0 {
		delete(p.ItemUnits, itemID)
		return nil
	}
	p.ItemUnits[itemID] = units
	return units
}

func insertSortedDesc(units []uint8, q uint8) []uint8 {
	i := sort.Search(len(units), func(k int) bool { return units[k] < q })
	units = append(units, 0)
	copy(units[i+1:], units[i:])
	units[i] = q
	return units
}

// addUnitsLocked adiciona qty unidades com a Qualidade q.
func (p *Player) addUnitsLocked(itemID, qty, q uint8) uint8 {
	if q > 100 {
		q = 100
	}
	units := p.unitsLocked(itemID)
	room := 255 - int(p.Inventory[itemID])
	if int(qty) > room {
		qty = uint8(room)
	}
	for i := uint8(0); i < qty; i++ {
		units = insertSortedDesc(units, q)
	}
	p.ItemUnits[itemID] = units
	p.Inventory[itemID] += qty
	return qty
}

// takeUnitLocked tira UMA unidade: com a Qualidade pedida (ou a melhor, se AnyQuality/não existir).
func (p *Player) takeUnitLocked(itemID, quality uint8) (uint8, bool) {
	units := p.unitsLocked(itemID)
	if len(units) == 0 {
		return 0, false
	}
	idx := 0
	if quality != AnyQuality {
		for i, q := range units {
			if q == quality {
				idx = i
				break
			}
		}
	}
	q := units[idx]
	units = append(units[:idx], units[idx+1:]...)
	p.Inventory[itemID]--
	if p.Inventory[itemID] == 0 {
		delete(p.Inventory, itemID)
		delete(p.ItemUnits, itemID)
	} else {
		p.ItemUnits[itemID] = units
	}
	return q, true
}

// AddItemWithQuality adiciona itens com uma Qualidade específica (minigames, coleta).
func (p *Player) AddItemWithQuality(itemID, qty, quality uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.Inventory == nil {
		p.Inventory = make(map[uint8]uint8)
	}
	p.markDiscoveredLocked(itemID)
	p.addUnitsLocked(itemID, qty, quality)
}

// TakeItemUnits tira até qty unidades do item com exatamente a Qualidade pedida.
// Retorna quantas saíram.
func (p *Player) TakeItemUnits(itemID, quality, qty uint8) uint8 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	var taken uint8
	for taken < qty {
		units := p.unitsLocked(itemID)
		found := false
		for _, q := range units {
			if q == quality {
				found = true
				break
			}
		}
		if !found {
			break
		}
		p.takeUnitLocked(itemID, quality)
		taken++
	}
	return taken
}

// UnitQualities devolve uma cópia das Qualidades das unidades do item (melhor -> pior).
func (p *Player) UnitQualities(itemID uint8) []uint8 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	return append([]uint8(nil), p.unitsLocked(itemID)...)
}

// EquippedQualityOf devolve a Condição do item equipado no slot.
func (p *Player) EquippedQualityOf(slot uint8) uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	if int(slot) >= protocol.EquipSlotCount {
		return 0
	}
	return p.slotQualityLocked(slot)
}

// GetEquippedQualities devolve a Condição de cada um dos 14 slots.
func (p *Player) GetEquippedQualities() [protocol.EquipSlotCount]uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	var out [protocol.EquipSlotCount]uint8
	for i := range out {
		out[i] = p.slotQualityLocked(uint8(i))
	}
	return out
}

func (p *Player) slotQualityLocked(slot uint8) uint8 {
	id := p.EquippedSlots[slot]
	if id == 0 {
		return 0
	}
	if p.EquippedQualitySet[slot] {
		return p.EquippedQuality[slot]
	}
	return DefaultQualityFor(id)
}

func (p *Player) setSlotQualityLocked(slot, q uint8) {
	p.EquippedQuality[slot] = q
	p.EquippedQualitySet[slot] = true
}

// qualityStatMult: equipamentos rendem de 50% (Qualidade 0) a 100% (Qualidade 100) de ATK, DEF e Vida.
func qualityStatMult(q uint8) float32 {
	return 0.5 + float32(q)/200.0
}
