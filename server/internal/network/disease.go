package network

import (
	"fmt"
	"log"
	"math/rand"
	"sort"
	"time"

	"lunaria/server/internal/protocol"
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

// handleDevWorldEvent dispara eventos climáticos e do Mundo Vivo pelo menu DEV (0x22, comando 13).
func (s *Server) handleDevWorldEvent(player *world.Player, ev uint8) {
	infectNear := func(disease string, count int) int {
		if player == nil {
			return 0
		}
		player.Mu.RLock()
		zone, px, pz := player.ZoneID, player.PosX, player.PosZ
		player.Mu.RUnlock()
		s.mu.RLock()
		var list []*world.NPC
		for _, n := range s.npcs {
			if n.Targetable() && n.GetZone() == zone {
				list = append(list, n)
			}
		}
		s.mu.RUnlock()
		sort.Slice(list, func(i, j int) bool {
			ax, _, az := list[i].GetPos()
			bx, _, bz := list[j].GetPos()
			return dist2(ax, az, px, pz) < dist2(bx, bz, px, pz)
		})
		done := 0
		for _, n := range list {
			if done >= count {
				break
			}
			if n.Infect(disease) {
				done++
			}
		}
		return done
	}
	msg := ""
	switch ev {
	case protocol.DevEventDryFountain, protocol.DevEventFillFountain:
		s.conflict.mu.Lock()
		s.conflict.fountainDry = ev == protocol.DevEventDryFountain
		s.conflict.mu.Unlock()
		msg = map[bool]string{true: "🏜️ A Fonte Central SECOU (DEV). Os NPCs vão ao Rio Prateado.", false: "💧 A Fonte Central voltou a jorrar (DEV)."}[ev == protocol.DevEventDryFountain]
	case protocol.DevEventFluEpidemic:
		msg = fmt.Sprintf("☣️ %d moradores pegaram %s (DEV).", infectNear(world.DiseaseMistFlu, 5), world.DiseaseMistFlu)
	case protocol.DevEventDysentery:
		msg = fmt.Sprintf("☣️ %d moradores pegaram %s (DEV).", infectNear(world.DiseaseDysentery, 5), world.DiseaseDysentery)
	case protocol.DevEventGreyPlague:
		msg = fmt.Sprintf("☣️ %d moradores pegaram %s (DEV).", infectNear(world.DiseaseGreyPlague, 3), world.DiseaseGreyPlague)
	case protocol.DevEventCureAll:
		s.mu.RLock()
		for _, n := range s.npcs {
			n.WithLife(func(h *world.NPC) { h.CureLocked(time.Now()) })
		}
		s.mu.RUnlock()
		msg = "✨ Todas as doenças foram curadas (DEV)."
	case protocol.DevEventSpawnZombie:
		if player == nil {
			return
		}
		player.Mu.RLock()
		zone, px, pz := player.ZoneID, player.PosX, player.PosZ
		player.Mu.RUnlock()
		zb := s.spawnZombie(world.ZombieName("Viajante Esquecido"), zone, px+6, pz+6, 400, 6, 0)
		msg = fmt.Sprintf("🧟 %s surgiu ao seu lado (DEV).", zb.Name)
	case protocol.DevEventDryPuddles, protocol.DevEventFillPuddles:
		dry := ev == protocol.DevEventDryPuddles
		for _, z := range evaporationZones {
			s.resourceNodes.SetPuddles(z, dry)
			s.broadcastResourceNodes(z)
		}
		msg = map[bool]string{true: "🏜️ Poças, orvalho e águas rasas secaram (DEV).", false: "💧 Águas rasas reabastecidas (DEV)."}[dry]
	case protocol.DevEventFeedPlayer, protocol.DevEventStarvePlayer, protocol.DevEventFreezePlayer:
		if player == nil {
			return
		}
		switch ev {
		case protocol.DevEventFeedPlayer:
			player.DevSetSurvival(100, 0)
			msg = "🍖 Fome saciada e corpo aquecido (DEV)."
		case protocol.DevEventStarvePlayer:
			player.DevSetSurvival(5, 0)
			msg = "🍽️ Você está faminto (DEV)."
		default:
			player.DevSetSurvival(100, 95)
			msg = "🥶 Você está quase congelando (DEV)."
		}
	default:
		return
	}
	s.BroadcastNPCSay(0, "[DEV] "+msg)
}
