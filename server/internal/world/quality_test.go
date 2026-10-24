package world

import (
	"testing"

	"lunaria/server/internal/protocol"
)

func TestUnitQuality(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	heart := ItemID(MatPulsingHeart)
	p.AddItemWithQuality(heart, 1, 90)
	p.AddItemWithQuality(heart, 2, 50)
	p.AddItemWithQuality(heart, 1, 70)
	got := p.UnitQualities(heart)
	if len(got) != 4 || got[0] != 90 || got[1] != 70 || got[2] != 50 || got[3] != 50 {
		t.Fatalf("cada unidade deveria manter a sua Qualidade (melhor -> pior): %v", got)
	}
	// A mochila manda uma entrada por Qualidade
	groups := map[uint8]uint8{}
	for _, s := range p.GetInventorySlots() {
		if s.ItemID == heart {
			groups[s.Quality] = s.Quantity
		}
	}
	if len(groups) != 3 || groups[50] != 2 || groups[90] != 1 {
		t.Fatalf("grupos por Qualidade errados: %v", groups)
	}
	// Remoções genéricas (entregas de missão, consumo) tiram primeiro as piores
	p.RemoveItem(heart, 1)
	if got := p.UnitQualities(heart); len(got) != 3 || got[2] != 50 || got[0] != 90 {
		t.Fatalf("deveria sair uma unidade de pior Qualidade: %v", got)
	}
	// Largar no chão escolhe a Qualidade exata
	if n := p.TakeItemUnits(heart, 90, 1); n != 1 {
		t.Fatal("deveria largar a unidade 90")
	}
	if got := p.UnitQualities(heart); len(got) != 2 || got[0] != 70 {
		t.Fatalf("restaram %v", got)
	}
	if JunkFor(ItemID(MatIron)) != protocol.ItemMetalScrap || JunkFor(heart) != protocol.ItemOrganicTrash {
		t.Fatal("lixo errado: metal vira sucata, orgânico vira lixo orgânico")
	}
}

func TestEquipKeepsUnitCondition(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	sword := protocol.ItemIronLongsword
	p.AddItemWithQuality(sword, 1, 40)
	p.AddItemWithQuality(sword, 1, 100)
	p.EquipItemQuality(sword, 40)
	if p.EquippedQualityOf(protocol.SlotMainHand) != 40 {
		t.Fatal("a espada equipada deveria ter Condição 40")
	}
	if atk, _, _ := p.EquipBonuses(); atk != 8 { // 12 × (0,5 + 40/200) = 8,4
		t.Fatalf("ATK deveria cair com a Condição: %d", atk)
	}
	if got := p.UnitQualities(sword); len(got) != 1 || got[0] != 100 {
		t.Fatalf("a espada perfeita deveria continuar na mochila: %v", got)
	}
	// Trocar pela perfeita devolve a de Condição 40 para a mochila
	p.EquipItemQuality(sword, 100)
	if p.EquippedQualityOf(protocol.SlotMainHand) != 100 {
		t.Fatal("troca de espada falhou")
	}
	if got := p.UnitQualities(sword); len(got) != 1 || got[0] != 40 {
		t.Fatalf("a espada antiga deveria voltar com Condição 40: %v", got)
	}
	p.UnequipSlot(protocol.SlotMainHand)
	if got := p.UnitQualities(sword); len(got) != 2 || got[0] != 100 || got[1] != 40 {
		t.Fatalf("desequipar deveria devolver Condição 100: %v", got)
	}
}
