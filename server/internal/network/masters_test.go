package network

import (
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func TestEveryBasicClassHasAMaster(t *testing.T) {
	for c := protocol.ClassWarrior; c <= protocol.ClassHuntingChef; c++ {
		if len(basicClassMasters[c]) == 0 {
			t.Fatalf("classe básica %d sem Mestre", c)
		}
		if basicClassHints[c] == "" {
			t.Fatalf("classe básica %d sem dica de localização", c)
		}
	}
}

func TestBasicClassRequiresMasterAndTamerIsSecret(t *testing.T) {
	s := &Server{players: map[uint32]*world.Player{}, npcs: map[uint32]*world.NPC{}, clock: world.NewWorldClock(12)}
	p := world.NewPlayer(1, nil, 0, 0, 0)
	if ok, _ := s.checkBasicClassRequest(p, protocol.ClassFighter); ok {
		t.Fatal("classe básica não deveria ser aprendida longe do Mestre")
	}
	tao := world.NewNPC(NPCTao, "Tao", 0, 0, 0, "", s.clock, nil)
	s.npcs[NPCTao] = tao
	if ok, _ := s.checkBasicClassRequest(p, protocol.ClassFighter); !ok {
		t.Fatal("ao lado do Mestre a classe deveria ser liberada")
	}
	thorne := world.NewNPC(NPCThorne, "Thorne", 0, 0, 0, "", s.clock, nil)
	s.npcs[NPCThorne] = thorne
	if ok, _ := s.checkBasicClassRequest(p, protocol.ClassTamer); ok {
		t.Fatal("Senhor das Feras exige a missão secreta de Thorne")
	}
	p.TamerUnlocked = true
	if ok, _ := s.checkBasicClassRequest(p, protocol.ClassTamer); !ok {
		t.Fatal("após a missão o Senhor das Feras deveria ser liberado")
	}
}
