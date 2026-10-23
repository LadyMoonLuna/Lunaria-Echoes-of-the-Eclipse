package world

import (
	"testing"

	"lunaria/server/internal/protocol"
)

func TestMaterialsCatalogAndDiscovery(t *testing.T) {
	if len(MaterialsDB) < 50 {
		t.Fatalf("catálogo de materiais incompleto: %d", len(MaterialsDB))
	}
	for id, m := range MaterialsDB {
		if id > 255 || m.Rarity < RarityCommon || m.Rarity > RarityMythic || m.Name == "" {
			t.Fatalf("material inválido %d: %+v", id, m)
		}
		if _, ok := ItemCatalog[uint8(id)]; !ok {
			t.Fatalf("material %d não virou item da mochila", id)
		}
	}
	p := NewPlayer(1, nil, 0, 0, 0)
	for _, id := range StartingDiscoveredMaterials {
		if !p.IsDiscovered(id) {
			t.Fatalf("material inicial %d deveria ser conhecido", id)
		}
	}
	p.AddItem(uint8(MatStormCedar), 1)
	p.AddItem(uint8(MatStormCedar), 1)
	if got := p.TakeNewDiscoveries(); len(got) != 1 || got[0] != MatStormCedar {
		t.Fatalf("descoberta nova esperada uma única vez: %v", got)
	}
	p.AddItem(uint8(MatIron), 1)
	if got := p.TakeNewDiscoveries(); len(got) != 0 {
		t.Fatal("Ferro já era conhecido")
	}
}

func TestResourceNodesAndTools(t *testing.T) {
	m := NewResourceNodeManager()
	if len(m.InZone(ZoneForest)) < 40 || len(m.InZone(ZoneChurch)) != 0 {
		t.Fatal("distribuição de nós por zona incorreta")
	}
	if NodeKindForMaterial(MatStormCedar) != NodeTree || NodeKindForMaterial(MatIron) != NodeOre ||
		NodeKindForMaterial(MatPureWater) != NodeWater || NodeKindForMaterial(MatThornVine) != NodeVine {
		t.Fatal("tipo de nó errado")
	}
	p := NewPlayer(1, nil, 0, 0, 0)
	if p.BestTool(ToolAxe) != 0 || p.BestTool(ToolPickaxe) != 0 || p.BestTool(ToolShears) != 0 {
		t.Fatal("o jogador começa sem ferramentas")
	}
	p.AddItem(ItemMithrilAxe, 1)
	if p.BestTool(ToolAxe) != 4 {
		t.Fatal("o melhor machado deveria valer")
	}
	if p.HasCuttingWeapon() {
		t.Fatal("jogador novo não tem arma cortante")
	}
	p.AddItem(protocol.ItemSteelDagger, 1)
	if !p.HasCuttingWeapon() {
		t.Fatal("adaga deveria cortar vinhas")
	}
	n := m.InZone(ZoneVillage)[0]
	m.Deplete(n.ID)
	if got, _ := m.Get(n.ID); got.Available() {
		t.Fatal("nó coletado deveria ficar indisponível")
	}
}

func TestCorpseAnatomy(t *testing.T) {
	organs := generateCorpseOrgans(protocol.MobTypeAlphaWolf, 0)
	seen := map[uint8]bool{}
	idx := map[uint8]bool{}
	for _, o := range organs {
		seen[o.OrganType] = true
		if idx[o.Index] {
			t.Fatalf("índice de órgão repetido: %d", o.Index)
		}
		idx[o.Index] = true
	}
	for _, need := range []uint8{OrganBlood, OrganHeart, OrganLiver, OrganGuts, OrganLungs, OrganEyes, OrganFangOrClaw, OrganPelt} {
		if !seen[need] {
			t.Fatalf("Lobo Alfa sem órgão do tipo %d", need)
		}
	}
	if !IsBloodOrgan(OrganVenomSac) || IsBloodOrgan(OrganHeart) {
		t.Fatal("classificação de fluidos errada")
	}
}
