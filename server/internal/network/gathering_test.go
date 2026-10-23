package network

import (
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func TestHarvestToolTierRules(t *testing.T) {
	p := world.NewPlayer(1, nil, 0, 0, 0)
	cedar := world.ResourceNode{Kind: world.NodeTree, MaterialID: world.MatStormCedar, Tier: 3}
	if qty, why := harvestYield(p, cedar); qty != 0 || why == "" {
		t.Fatal("Machado de Pedra não corta Cedro da Tempestade (Tier 3)")
	}
	p.AddItem(world.ItemTemperedAxe, 1)
	if qty, _ := harvestYield(p, cedar); qty != 2 {
		t.Fatalf("com Machado Tier 3 deveria coletar 2, coletou %d", qty)
	}
	vine := world.ResourceNode{Kind: world.NodeVine, MaterialID: world.MatThornVine, Tier: 1}
	if qty, _ := harvestYield(p, vine); qty != 0 {
		t.Fatal("sem arma cortante não colhe vinhas")
	}
	p.AddItem(protocol.ItemSteelDagger, 1)
	if qty, _ := harvestYield(p, vine); qty != 3 {
		t.Fatal("adaga colhe 1x")
	}
	p.AddItem(world.ItemHerbalShears, 1)
	if qty, _ := harvestYield(p, vine); qty != 6 {
		t.Fatal("tesoura dobra a colheita")
	}
	water := world.ResourceNode{Kind: world.NodeWater, MaterialID: world.MatPureWater, Tier: 1}
	if qty, _ := harvestYield(p, water); qty != 3 {
		t.Fatalf("3 frascos iniciais => 3 de água, obteve %d", qty)
	}
}

func TestGatheringPackets(t *testing.T) {
	h := protocol.SerializeHarvestNode(7, 42)
	var hp protocol.HarvestNodePacket
	if err := protocol.DeserializeHarvestNode(h[:], &hp); err != nil || hp.NodeID != 42 {
		t.Fatal("0x44 inválido")
	}
	nodes := []protocol.ResourceNodeEntry{{NodeID: 3, Kind: world.NodeOre, Material: 116, Tier: 1, Available: true, X: 10, Z: -5}}
	got, err := protocol.DeserializeResourceNodesSync(protocol.SerializeResourceNodesSync(nodes))
	if err != nil || len(got) != 1 || got[0] != nodes[0] {
		t.Fatalf("0x45 inválido: %+v", got)
	}
	mode, ids, err := protocol.DeserializeDiscoveredMaterials(protocol.SerializeDiscoveredMaterials(protocol.DiscoveredModeNew, []uint16{102, 133}))
	if err != nil || mode != protocol.DiscoveredModeNew || len(ids) != 2 || ids[1] != 133 {
		t.Fatal("0x46 inválido")
	}
}
