package network

import (
	"testing"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func afterlifeServer() *Server {
	s := lifeTestServer()
	s.corpseManager = world.NewCorpseManager()
	s.mobManager = &world.MobManager{Mobs: map[uint32]*world.Mob{}}
	return s
}

func TestGravediggerBuriesBodyInCemetery(t *testing.T) {
	s := afterlifeServer()
	digger := addLifeNPC(s, world.GravediggerID, -66, -22)
	victim := addLifeNPC(s, 103, 10, 10)
	s.handleNPCDeath(victim, "teste")
	s.updateAfterlife()
	if !digger.LifeBusy() {
		t.Fatal("o Coveiro deveria sair para buscar o corpo")
	}
	for i := 0; i < 400 && digger.LifeBusy(); i++ {
		digger.WithLife(func(n *world.NPC) {
			if len(n.Life.Plan) > 0 {
				n.PosX, n.PosZ = n.Life.Plan[0].X, n.Life.Plan[0].Z
			}
		})
		s.updateNPCLife(1)
	}
	tomb := s.conflict.tombstones[0]
	slot := world.CemeterySlot(0)
	if !tomb.Buried || tomb.X != slot[0] || tomb.Z != slot[1] {
		t.Fatalf("o túmulo deveria estar no cemitério: %+v", tomb)
	}
}

func TestUnprocessedCorpseCanRiseAndPurifiedCannot(t *testing.T) {
	s := afterlifeServer()
	mob := world.NewMobWithZone(1, "Lobo", protocol.MobTypeMistWolf, 0, 5, 0, 5, 300, 3)
	mob.KilledByZombie = true
	rose := 0
	for i := 0; i < 200; i++ {
		c := s.corpseManager.CreateCorpseFromMob(mob, 0, 0)
		c.ExpiresAt = time.Now().Add(-time.Second)
		if i%2 == 0 {
			c.Purified = true
		}
	}
	s.processExpiredCorpses()
	for _, m := range s.mobManager.GetAllMobs() {
		if m.Undead {
			rose++
		}
	}
	if rose == 0 || rose > 60 {
		t.Fatalf("com 100 corpos não purificados mortos por zumbi, cerca de 30 deveriam se erguer (ergueram %d)", rose)
	}
}

func TestPurifyRequiresHolyClass(t *testing.T) {
	s := afterlifeServer()
	mob := world.NewMobWithZone(1, "Lobo", protocol.MobTypeMistWolf, 0, 1, 0, 1, 300, 3)
	c := s.corpseManager.CreateCorpseFromMob(mob, 0, 0)
	p := conflictPlayer(s, 1, 1)
	s.handleCorpseRite(p, protocol.CorpseRitePacket{Target: protocol.RiteTargetCorpse, ID: c.CorpseID, Rite: protocol.RitePurify})
	if c.Purified {
		t.Fatal("só Acólitos e vertentes purificam")
	}
	p.ClassID = protocol.ClassShieldBearer
	s.handleCorpseRite(p, protocol.CorpseRitePacket{Target: protocol.RiteTargetCorpse, ID: c.CorpseID, Rite: protocol.RitePurify})
	if !c.Purified || !c.Processed() {
		t.Fatal("o Acólito deveria purificar o corpo")
	}
}

func TestNecromancerRaiseOnceWitnessedSendsChurch(t *testing.T) {
	s := afterlifeServer()
	addLifeNPC(s, 103, 5, 5) // testemunha
	mob := world.NewMobWithZone(1, "Lobo", protocol.MobTypeMistWolf, 0, 1, 0, 1, 120, 3)
	c := s.corpseManager.CreateCorpseFromMob(mob, 0, 0)
	p := conflictPlayer(s, 1, 1)
	p.ClassID, p.Level = protocol.ClassBoneNecromancer, 60
	s.handleCorpseRite(p, protocol.CorpseRitePacket{Target: protocol.RiteTargetCorpse, ID: c.CorpseID, Rite: protocol.RiteRaise})
	servants := 0
	for _, m := range s.mobManager.GetAllMobs() {
		if m.Undead && m.ZombieOwner == p.ID {
			servants++
		}
	}
	if servants != 1 {
		t.Fatalf("um Necromante muito mais forte deveria reerguer o zumbi servo (servos: %d)", servants)
	}
	if !p.IsPermanentWanted(1) || p.BountyGold < world.NecroUrgentBounty {
		t.Fatal("a testemunha deveria pôr recompensa urgente e torná-lo hostil na cidade")
	}
	paladins := 0
	for id, n := range s.npcs {
		if world.IsChurchHunter(id) && n.GetActive() && n.Life.HuntTarget == p.ID {
			paladins++
		}
	}
	if paladins != 3 {
		t.Fatalf("a Igreja deveria enviar 2 Paladinos e 1 Clériga (enviou %d)", paladins)
	}
}

func TestNecroChanceFallsWithZombieLevel(t *testing.T) {
	if world.NecroChance(10, 30) >= world.NecroChance(10, 5) {
		t.Fatal("zumbi de nível maior que o Necromante deveria falhar mais")
	}
}

func TestZombieBitesNPCAndNPCFightsBack(t *testing.T) {
	s := afterlifeServer()
	randel := addLifeNPC(s, 105, 0, 0)
	zb := s.spawnZombie("Zumbi de Teste", 0, 1, 0, 400, 5, 0)
	hp := randel.HP
	s.updateZombieAI(zb, 0.1)
	if randel.HP >= hp {
		t.Fatal("o zumbi deveria morder o NPC ao lado")
	}
	if randel.Life.Aggressor != zb.ID {
		t.Fatal("o Capitão deveria revidar contra o zumbi")
	}
}

func TestRiverWaterCanMakeNPCSickAndAlchemistCures(t *testing.T) {
	s := afterlifeServer()
	lyra := addLifeNPC(s, 103, 30, -20)
	g := addLifeNPC(s, 100, 30, 25)
	g.WithLife(func(n *world.NPC) { n.Sick, n.Disease = true, "Febre do Rio" })
	s.updateNPCLife(1)
	if !g.LifeBusy() {
		t.Fatal("doente deveria ir comprar remédio")
	}
	g.Teleport(30, 0, -18.5)
	stock := lyra.ShopStock[uint16(protocol.ItemHerbalRemedy)]
	s.updateNPCLife(1)
	if g.Sick || lyra.ShopStock[uint16(protocol.ItemHerbalRemedy)] != stock-1 {
		t.Fatal("o remédio da Alquimista deveria curar a doença")
	}
}

func TestDryFountainSendsNPCToRiver(t *testing.T) {
	s := afterlifeServer()
	g := addLifeNPC(s, 100, 30, 25)
	s.conflict.fountainDry = true
	g.WithLife(func(n *world.NPC) { n.Thirst = 10 })
	s.updateNPCLife(1)
	if len(g.Life.Plan) == 0 || g.Life.Plan[len(g.Life.Plan)-1].Action != "drink_river" {
		t.Fatal("com a Fonte seca o NPC deveria beber no rio")
	}
}

func TestOnlyApprenticesFailCrafting(t *testing.T) {
	r := world.NPCProfiles[100].Recipes[0]
	master := world.NewNPC(100, "Garrick", 0, 0, 0, "", nil, nil)
	master.Profession, master.ProfessionLevel = 100, 10
	appr := world.NewNPC(117, "Bran", 0, 0, 0, "", nil, nil)
	appr.Profession, appr.ProfessionLevel = 100, 1
	if world.CraftFailChance(master, r) != 0 || world.CraftFailChance(appr, r) <= 0 {
		t.Fatal("só o aprendiz formado pode falhar")
	}
	appr.ProfessionLevel = 9
	if world.CraftFailChance(appr, r) >= world.CraftFailChance(&world.NPC{ID: 117, Profession: 100, ProfessionLevel: 1}, r) {
		t.Fatal("a chance de falha cai com o nível")
	}
}
