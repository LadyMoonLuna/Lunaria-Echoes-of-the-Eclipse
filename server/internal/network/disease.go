package network

import (
	"fmt"
	"log"
	"math/rand"
	"sort"
	"time"

	"lunaria/server/internal/world"
)

// Contágio e epidemias (a cada 10 s): doentes de doenças infecciosas passam a doença a quem está perto,
// inclusive durante a incubação, quando ainda nem sabem que estão doentes.

func (s *Server) updateContagion(dt time.Duration) {
	now := time.Now()
	dtMin := dt.Minutes()
	s.mu.RLock()
	npcs := make([]*world.NPC, 0, len(s.npcs))
	for _, n := range s.npcs {
		if n.Targetable() {
			npcs = append(npcs, n)
		}
	}
	s.mu.RUnlock()

	type carrier struct {
		zone    uint8
		x, z    float32
		disease string
	}
	var carriers []carrier
	for _, n := range npcs {
		if sick, disease, contagious := n.SickState(); sick && contagious {
			x, _, z := n.GetPos()
			carriers = append(carriers, carrier{n.GetZone(), x, z, disease})
		}
	}
	s.conflict.mu.Lock()
	epidemics := make(map[string]bool, len(s.conflict.epidemics))
	for k, v := range s.conflict.epidemics {
		epidemics[k] = v
	}
	s.conflict.mu.Unlock()

	var newCases []string
	for _, n := range npcs {
		x, _, z := n.GetPos()
		zone := n.GetZone()
		n.WithLife(func(h *world.NPC) {
			if h.Sick {
				return
			}
			// Frio intenso pode trazer a Gripe da Bruma
			if h.Cold > 80 && rand.Float64() < world.ColdFluChancePerMin*dtMin && h.InfectLocked(world.DiseaseMistFlu, now) {
				newCases = append(newCases, fmt.Sprintf("%s pegou %s no frio", h.Name, world.DiseaseMistFlu))
				return
			}
			for _, c := range carriers {
				d := world.Disease(c.disease)
				if c.zone != zone || dist2(c.x, c.z, x, z) > d.SpreadRadius*d.SpreadRadius {
					continue
				}
				if rand.Float64() < world.ContagionChance(d, dtMin, epidemics[c.disease]) && h.InfectLocked(c.disease, now) {
					log.Printf("[CONTÁGIO] %s (#%d) pegou %s\n", h.Name, h.ID, c.disease)
					return
				}
			}
		})
	}
	for _, msg := range newCases {
		log.Printf("[CONTÁGIO] %s\n", msg)
	}
	s.updateEpidemics(npcs)
}

// updateEpidemics declara (ou encerra) epidemias por cidade.
func (s *Server) updateEpidemics(npcs []*world.NPC) {
	cases := map[string]int{}
	living := 0
	for _, n := range npcs {
		if world.CityOfZone(n.GetZone()) == 0 {
			continue
		}
		living++
		if sick, disease, contagious := n.SickState(); sick && contagious {
			cases[disease]++
		}
	}
	var started, ended []string
	s.conflict.mu.Lock()
	if s.conflict.epidemics == nil {
		s.conflict.epidemics = map[string]bool{}
	}
	for name, d := range world.DiseaseDB {
		if !d.Contagious {
			continue
		}
		n := cases[name]
		isEpidemic := n >= world.EpidemicMinCases || (living > 0 && n >= 2 && float64(n) >= float64(living)*world.EpidemicFraction)
		switch {
		case isEpidemic && !s.conflict.epidemics[name]:
			s.conflict.epidemics[name] = true
			started = append(started, fmt.Sprintf("%s (%d doentes)", name, n))
		case n == 0 && s.conflict.epidemics[name]:
			delete(s.conflict.epidemics, name)
			ended = append(ended, name)
		}
	}
	s.conflict.mu.Unlock()
	sort.Strings(started)
	sort.Strings(ended)
	for _, e := range started {
		s.BroadcastNPCSay(0, fmt.Sprintf("☣️ EPIDEMIA na Vila do Refúgio: %s! O contágio acelera. Evitem aglomerações e procurem a Alquimista ou a Igreja.", e))
	}
	for _, e := range ended {
		s.BroadcastNPCSay(0, fmt.Sprintf("🕊️ A epidemia de %s chegou ao fim. A vila respira aliviada.", e))
	}
}

// ActiveEpidemics lista as epidemias em curso.
func (s *Server) ActiveEpidemics() []string {
	s.conflict.mu.Lock()
	defer s.conflict.mu.Unlock()
	out := make([]string, 0, len(s.conflict.epidemics))
	for k := range s.conflict.epidemics {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
