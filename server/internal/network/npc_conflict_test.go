package network

import (
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func conflictPlayer(s *Server, x, z float32) *world.Player {
	p := world.NewPlayer(1, nil, x, 0, z)
	s.players[1] = p
	return p
}

func TestAttackingCitizenMakesWantedAndGuardsHunt(t *testing.T) {
	s := lifeTestServer()
	lyra := addLifeNPC(s, 103, 0, 0)
	guard := addLifeNPC(s, 105, 20, 0)
	p := conflictPlayer(s, 1, 0)
	s.playerHitNPC(p, lyra, 100, 0, protocol.ActionBasicAttack)
	if !p.IsWanted() || p.BountyGold != world.BountyPerCrime {
		t.Fatalf("jogador deveria ficar procurado com recompensa %d, tem %d", world.BountyPerCrime, p.BountyGold)
	}
	if guard.Life.HuntTarget != p.ID || guard.CurrentActivity != world.ActivityHunting {
		t.Fatal("o Guarda deveria iniciar a caçada")
	}
	if lyra.CurrentActivity != world.ActivityFleeing {
		t.Fatal("Lyra (civil) deveria fugir até o Guarda")
	}
	s.playerHitNPC(p, lyra, 10, 0, protocol.ActionBasicAttack)
	if p.BountyGold != world.BountyPerCrime {
		t.Fatal("golpes repetidos não deveriam acumular recompensa sem novo crime grave")
	}
}

func TestCombatNPCRetaliates(t *testing.T) {
	s := lifeTestServer()
	garrick := addLifeNPC(s, 100, 0, 0)
	p := conflictPlayer(s, 1, 0)
	s.playerHitNPC(p, garrick, 50, 0, protocol.ActionBasicAttack)
	if garrick.Life.Aggressor != p.ID {
		t.Fatal("Garrick deveria revidar")
	}
	hp := p.HP
	s.updateNPCConflict(1)
	if p.HP >= hp {
		t.Fatal("Garrick deveria golpear o agressor ao lado")
	}
}

func TestLawlessZoneEndsHunt(t *testing.T) {
	s := lifeTestServer()
	lyra := addLifeNPC(s, 103, 0, 0)
	guard := addLifeNPC(s, 105, 20, 0)
	p := conflictPlayer(s, 1, 0)
	s.playerHitNPC(p, lyra, 10, 0, protocol.ActionBasicAttack)
	p.Mu.Lock()
	p.ZoneID = world.ZoneAncientSewers
	p.Mu.Unlock()
	s.updateNPCConflict(1)
	if guard.Life.HuntTarget != 0 {
		t.Fatal("a caçada deveria parar nos Esgotos")
	}
}

func TestGuardKillJailsAndPaysBounty(t *testing.T) {
	s := lifeTestServer()
	lyra := addLifeNPC(s, 103, 0, 0)
	guard := addLifeNPC(s, 105, 1, 0)
	p := conflictPlayer(s, 1, 0)
	p.AddGold(1000)
	s.playerHitNPC(p, lyra, 10, 0, protocol.ActionBasicAttack)
	gold := p.Gold
	lyraGold := lyra.Gold
	s.guardKilledCriminal(guard, p)
	if p.Gold != gold-world.BountyPerCrime || lyra.Gold != lyraGold+world.BountyPerCrime || !p.IsJailed() || p.IsWanted() {
		t.Fatal("o criminoso abatido deveria pagar a recompensa à vítima e ir preso")
	}
}

func TestPermadeathTombstoneAndEstate(t *testing.T) {
	s := lifeTestServer()
	garrick := addLifeNPC(s, 100, 5, 5)
	p := conflictPlayer(s, 6, 5)
	s.playerHitNPC(p, garrick, 5000, 0, protocol.ActionBasicAttack)
	if !garrick.IsDead || garrick.GetActive() || garrick.ShopOpen {
		t.Fatal("Garrick deveria estar morto, inativo e com a loja fechada")
	}
	garrick.SetActive(true)
	if garrick.GetActive() {
		t.Fatal("rotinas não podem ressuscitar um NPC morto")
	}
	if len(s.tombstoneEntries()) != 1 || s.tombstoneEntries()[0].Killer != "Jogador #1" {
		t.Fatal("túmulo com o assassino deveria ser criado")
	}
	if len(s.groundItems.InZone(world.ZoneVillage)) == 0 {
		t.Fatal("o espólio deveria cair no chão")
	}
}

func TestApprenticeInheritsWorkshop(t *testing.T) {
	s := lifeTestServer()
	garrick := addLifeNPC(s, 100, 30, 25)
	for _, n := range spawnApprentices(s.clock, nil) {
		s.npcs[n.ID] = n
		s.initNPCLife([]*world.NPC{n})
	}
	bran := s.npcs[117]
	s.handleNPCDeath(garrick, "teste")
	s.updateNPCConflict(1)
	if bran.Life.StudyingFor != 100 {
		t.Fatal("Bran deveria começar a estudar o ofício do Garrick")
	}
	p := conflictPlayer(s, 26, 22)
	p.AddItemWithQuality(protocol.ItemBlueprintScroll, 1, 100)
	s.trainApprentice(p, bran)
	s.updateNPCConflict(1)
	if bran.Profession != 100 || bran.ProfessionLevel != 1 {
		t.Fatalf("Bran deveria virar o Novo Ferreiro nível 1 (ofício %d, nível %d)", bran.Profession, bran.ProfessionLevel)
	}
	if world.ShopPrice(bran.Profession, protocol.ItemIronLongsword) == 0 {
		t.Fatal("o novo Ferreiro deveria vender as peças do ofício")
	}
}

func TestHireRequiresFriendshipAndGold(t *testing.T) {
	s := lifeTestServer()
	lyra := addLifeNPC(s, 103, 0, 0)
	p := conflictPlayer(s, 1, 0)
	p.AddGold(1000)
	s.hireNPC(p, lyra)
	if lyra.Life.Following != 0 {
		t.Fatal("sem 3 corações não deveria aceitar")
	}
	p.AddFriendship(103, 60)
	s.hireNPC(p, lyra)
	if lyra.Life.Following != p.ID {
		t.Fatal("com amizade e ouro deveria seguir o jogador")
	}
	p.Mu.Lock()
	p.ZoneID, p.PosX, p.PosZ = world.ZoneForest, 10, 10
	p.Mu.Unlock()
	s.updateNPCConflict(1)
	if lyra.GetZone() != world.ZoneForest {
		t.Fatal("a contratada deveria migrar com o jogador")
	}
	s.handleNPCContract(p, protocol.NPCContractPacket{NPCID: 103, Action: protocol.ContractSettle})
	if lyra.Life.HomeZone != world.ZoneForest || lyra.Life.Following != 0 {
		t.Fatal("ao assentar deveria mudar de lar")
	}
}
