package network

import (
	"math"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// companionProfile define o companheiro de cada classe: dano base e alcance de ataque (m).
type companionProfile struct {
	name  string
	base  float32
	reach float32
}

var classCompanions = map[uint8]companionProfile{
	protocol.ClassSculptor:          {"Estátua Guardiã", 10, 6},
	protocol.ClassTamer:             {"Fera Domada", 12, 7},
	protocol.ClassBloodPackKing:     {"Lobos Espirituais Alfa", 18, 8},
	protocol.ClassPagmaDescendant:   {"Seis Espadas Flutuantes", 20, 7},
	protocol.ClassMoonlightSculptor: {"Estátuas Vivas do Luar", 22, 8},
	protocol.ClassDragonMonarch:     {"Dragão Ancião", 30, 10},
	protocol.ClassHomunculusCreator: {"Homúnculo", 14, 6},
	protocol.ClassPrimordialTamer:   {"Espírito Alfa", 22, 8},
}

// companionDamage escala com nível e Perícia (MAS) do dono.
func companionDamage(prof companionProfile, level, mas uint8) uint16 {
	return uint16(prof.base + float32(level)*1.2 + float32(mas)*1.5)
}

// updateCompanions faz cada companheiro atacar sozinho o monstro mais próximo do dono
// enquanto o dono estiver em combate. Chamado a cada 2 segundos.
func (s *Server) updateCompanions() {
	if s.mobManager == nil {
		return
	}
	s.mu.RLock()
	owners := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		owners = append(owners, p)
	}
	s.mu.RUnlock()

	for _, p := range owners {
		p.Mu.RLock()
		classID, level, mas := p.ClassID, p.Level, p.MAS
		px, pz, zone, hp := p.PosX, p.PosZ, p.ZoneID, p.HP
		p.Mu.RUnlock()
		prof, ok := classCompanions[classID]
		if !ok || hp == 0 || p.OutOfCombat() {
			continue
		}
		var target *world.Mob
		best := prof.reach
		for _, mob := range s.mobManager.GetAllMobsByZone(zone) {
			if !mob.IsAlive {
				continue
			}
			mob.Mu.RLock()
			mx, mz := mob.PosX, mob.PosZ
			mob.Mu.RUnlock()
			d := float32(math.Hypot(float64(mx-px), float64(mz-pz)))
			if d <= best {
				best = d
				target = mob
			}
		}
		if target == nil {
			continue
		}
		target.Mu.RLock()
		tx, tz := target.PosX, target.PosZ
		target.Mu.RUnlock()
		s.applyRacialAoEDamage(p, tx, tz, 1.0, companionDamage(prof, level, mas))
	}
}
