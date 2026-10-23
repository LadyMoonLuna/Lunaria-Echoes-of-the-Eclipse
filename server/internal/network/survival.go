package network

import (
	"log"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// updatePlayerSurvival (1 Hz): fome e temperatura dos jogadores, dano por exposição e envio do 0x50 ao HUD.
func (s *Server) updatePlayerSurvival(dt float32) {
	hour := s.clock.GetCurrentHour()
	s.mu.RLock()
	players := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		players = append(players, p)
	}
	s.mu.RUnlock()
	for _, p := range players {
		if p.IsInAutopsy() {
			continue
		}
		p.Mu.RLock()
		zone, x, z := p.ZoneID, p.PosX, p.PosZ
		p.Mu.RUnlock()
		ambient := world.AmbientTemp(zone, hour, s.clock.GetZoneWeather(zone))
		dx, dz := x-world.PlaceFurnace[0], z-world.PlaceFurnace[1]
		nearFire := zone == world.ZoneVillage && dx*dx+dz*dz <= world.HeatRadius*world.HeatRadius
		if dmg := p.TickSurvival(dt, ambient, nearFire); dmg > 0 {
			newHP, dead := p.TakeDamage(dmg)
			s.sendPlayerStats(p)
			if dead {
				log.Printf("[SOBREVIVÊNCIA] Jogador #%d morreu de fome ou exposição ao clima (HP %d)\n", p.ID, newHP)
				s.sendPlayerNPCSay(p, 0, "☠️ Você sucumbiu à fome ou ao clima. Coma, aqueça-se ou refresque-se para sobreviver.")
				s.RespawnPlayer(p)
			}
		}
		st := p.SurvivalSnapshot()
		pkt := protocol.SerializePlayerSurvival(st.Hunger, st.Cold, st.Heat, st.BodyTemp, st.Ambient)
		writeTCP(p, pkt[:])
	}
}
