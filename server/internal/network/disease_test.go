package network

import (
	"testing"
	"time"

	"lunaria/server/internal/world"
)

func TestContagiousDiseaseSpreadsToNeighbours(t *testing.T) {
	s := afterlifeServer()
	sick := addLifeNPC(s, 100, 0, 0)
	near := addLifeNPC(s, 103, 1, 0)
	far := addLifeNPC(s, 107, 60, 60)
	sick.Infect(world.DiseaseMistFlu)
	for i := 0; i < 200 && !near.Sick; i++ {
		s.updateContagion(time.Minute)
	}
	if !near.Sick || near.Disease != world.DiseaseMistFlu {
		t.Fatal("quem está ao lado do gripado deveria pegar a Gripe da Bruma")
	}
	if far.Sick {
		t.Fatal("quem está longe não pega")
	}
}

func TestNonContagiousDoesNotSpread(t *testing.T) {
	s := afterlifeServer()
	sick := addLifeNPC(s, 100, 0, 0)
	near := addLifeNPC(s, 103, 1, 0)
	sick.Infect(world.DiseaseRiverFever)
	for i := 0; i < 100; i++ {
		s.updateContagion(time.Minute)
	}
	if near.Sick {
		t.Fatal("Febre do Rio não é contagiosa")
	}
}

func TestIncubationHidesSymptomsAndImmunityAfterCure(t *testing.T) {
	n := world.NewNPC(1, "a", 0, 0, 0, "", nil, nil)
	now := time.Now()
	n.WithLife(func(h *world.NPC) {
		h.InfectLocked(world.DiseaseGreyPlague, now)
		if h.SymptomaticLocked(now) {
			t.Fatal("durante a incubação ainda não há sintomas")
		}
		if !h.SymptomaticLocked(now.Add(4 * time.Minute)) {
			t.Fatal("depois da incubação os sintomas aparecem")
		}
		h.CureLocked(now)
		if h.InfectLocked(world.DiseaseGreyPlague, now.Add(time.Minute)) {
			t.Fatal("quem se curou fica imune por um tempo")
		}
	})
}

func TestEpidemicDeclaredAndEnded(t *testing.T) {
	s := afterlifeServer()
	var all []*world.NPC
	for i, id := range []uint32{100, 103, 105, 107, 108} {
		n := addLifeNPC(s, id, float32(i*50), 0)
		all = append(all, n)
	}
	for _, n := range all[:4] {
		n.Infect(world.DiseaseDysentery)
	}
	s.updateEpidemics(all)
	if ep := s.ActiveEpidemics(); len(ep) != 1 || ep[0] != world.DiseaseDysentery {
		t.Fatalf("4 doentes de Disenteria deveriam declarar epidemia: %v", ep)
	}
	for _, n := range all {
		n.WithLife(func(h *world.NPC) { h.CureLocked(time.Now()) })
	}
	s.updateEpidemics(all)
	if len(s.ActiveEpidemics()) != 0 {
		t.Fatal("sem doentes a epidemia termina")
	}
}

func TestPlagueOnlyChurchCures(t *testing.T) {
	s := afterlifeServer()
	addLifeNPC(s, 103, 30, -20)
	addLifeNPC(s, world.SeraphinaID, -50, -36)
	g := addLifeNPC(s, 100, 30, 25)
	g.WithLife(func(h *world.NPC) {
		h.InfectLocked(world.DiseaseGreyPlague, time.Now().Add(-time.Hour))
	})
	s.updateNPCLife(1)
	if len(g.Life.Plan) == 0 || g.Life.Plan[len(g.Life.Plan)-1].Action != "church_cure" {
		t.Fatal("a Peste Cinzenta exige a cura da Igreja")
	}
}
