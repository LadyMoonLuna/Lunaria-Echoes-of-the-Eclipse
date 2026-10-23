package network

import (
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func TestBlacksmithQuestFlow(t *testing.T) {
	s := &Server{players: map[uint32]*world.Player{}, npcs: map[uint32]*world.NPC{}, clock: world.NewWorldClock(12)}
	p := world.NewPlayer(1, nil, 0, 0, 0)
	s.players[1] = p
	if p.BestTool(world.ToolAxe) != 0 || p.HasCuttingWeapon() {
		t.Fatal("o jogador começa sem ferramentas nem lâmina")
	}
	// Parte 1: Machado Velho
	s.handleBlacksmithQuest(p, 100)
	if questStage(p) != 1 || p.BestTool(world.ToolAxe) != 1 {
		t.Fatal("Garrick deveria entregar o Machado Velho (T1)")
	}
	if s.handleBlacksmithQuest(p, 100) || questStage(p) != 1 {
		t.Fatal("sem os Pinhos a missão não avança")
	}
	p.AddItem(uint8(world.MatPineRefuge), 5)
	s.handleBlacksmithQuest(p, 100)
	if questStage(p) != 2 || p.BestTool(world.ToolPickaxe) != 1 || p.GetItemCount(uint8(world.MatPineRefuge)) != 0 {
		t.Fatal("parte 2 deveria começar com a Picareta Desgastada e consumir os Pinhos")
	}
	p.AddItem(uint8(world.MatCopper), 5)
	s.handleBlacksmithQuest(p, 100)
	if questStage(p) != 3 || !p.HasCuttingWeapon() || p.GetItemCount(protocol.ItemAutopsyDagger) != 1 {
		t.Fatal("parte 3 deveria entregar a Adaga de Autópsia")
	}
	p.AddItem(uint8(world.MatBoarLeather), 3)
	s.handleBlacksmithQuest(p, 100)
	if questStage(p) != questStageDone || p.GetItemCount(protocol.ItemIronLongsword) != 1 {
		t.Fatal("ao final Garrick forja a Espada Longa de Aço")
	}
	if p.Gold != world.StartingGold+40+60+100 {
		t.Fatalf("recompensas em ouro erradas: %d", p.Gold)
	}
}
