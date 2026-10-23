package world

import "lunaria/server/internal/protocol"

// Qualidade: pseudo-atributo de 0 a 100 presente em todos os itens. Mede aspectos diferentes
// conforme o item (Frescor de órgãos, Integridade de peles, Veio da madeira, Pureza de metais e
// cristais, Potência de plantas e líquidos, Condição de equipamentos) e sobe com menos erros nos
// minigames de extração/criação. Abaixo de JunkQuality o item vira lixo.
const (
	DefaultItemQuality uint8 = 75 // drops, presentes e itens sem minigame
	JunkQuality        uint8 = 35 // abaixo disso a extração/criação arruína o item
	PerfectQuality     uint8 = 80
)

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

func (p *Player) itemQualityLocked(itemID uint8) uint8 {
	if q, ok := p.ItemQuality[itemID]; ok {
		return q
	}
	return DefaultQualityFor(itemID)
}

// ItemQualityOf devolve a Qualidade do item (média da pilha).
func (p *Player) ItemQualityOf(itemID uint8) uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.itemQualityLocked(itemID)
}

// blendQualityLocked mistura a Qualidade de qty unidades novas na média da pilha existente.
func (p *Player) blendQualityLocked(itemID, qty, quality uint8) {
	if p.ItemQuality == nil {
		p.ItemQuality = make(map[uint8]uint8)
	}
	have := int(p.Inventory[itemID])
	for _, id := range p.EquippedSlots {
		if id == itemID {
			have++
		}
	}
	if have == 0 {
		p.ItemQuality[itemID] = quality
		return
	}
	old := int(p.itemQualityLocked(itemID))
	p.ItemQuality[itemID] = uint8((old*have + int(quality)*int(qty)) / (have + int(qty)))
}

// AddItemWithQuality adiciona itens com uma Qualidade específica (minigames, coleta).
func (p *Player) AddItemWithQuality(itemID, qty, quality uint8) {
	if quality > 100 {
		quality = 100
	}
	p.Mu.Lock()
	p.markDiscoveredLocked(itemID)
	p.blendQualityLocked(itemID, qty, quality)
	if int(p.Inventory[itemID])+int(qty) > 255 {
		p.Inventory[itemID] = 255
	} else {
		p.Inventory[itemID] += qty
	}
	p.Mu.Unlock()
}

// qualityStatMult: equipamentos rendem de 50% (Qualidade 0) a 100% (Qualidade 100) de ATK, DEF e Vida.
func qualityStatMult(q uint8) float32 {
	return 0.5 + float32(q)/200.0
}
