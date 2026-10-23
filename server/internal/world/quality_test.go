package world

import (
	"testing"

	"lunaria/server/internal/protocol"
)

func TestItemQuality(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.AddItemWithQuality(uint8(MatPulsingHeart), 1, 90)
	p.AddItemWithQuality(uint8(MatPulsingHeart), 1, 50)
	if q := p.ItemQualityOf(uint8(MatPulsingHeart)); q != 70 {
		t.Fatalf("a pilha deveria ter a média 70, tem %d", q)
	}
	if JunkFor(uint8(MatIron)) != protocol.ItemMetalScrap || JunkFor(uint8(MatPulsingHeart)) != protocol.ItemOrganicTrash {
		t.Fatal("lixo errado: metal vira sucata, orgânico vira lixo orgânico")
	}
	// Equipamento perfeito rende 100%; com Qualidade 0 rende metade
	p.AddItem(protocol.ItemIronLongsword, 1)
	p.EquipItem(protocol.ItemIronLongsword)
	if atk, _, _ := p.EquipBonuses(); atk != 12 {
		t.Fatalf("espada nova (Condição 100) deveria dar 12 de ATK, deu %d", atk)
	}
	p.ItemQuality[protocol.ItemIronLongsword] = 0
	if atk, _, _ := p.EquipBonuses(); atk != 6 {
		t.Fatalf("espada arruinada deveria dar 6 de ATK, deu %d", atk)
	}
	for _, s := range p.GetInventorySlots() {
		if s.ItemID == uint8(MatPulsingHeart) && s.Quality != 70 {
			t.Fatal("a Qualidade deveria ir na sincronização da mochila")
		}
	}
}
