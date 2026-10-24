package network

import (
	"math"
	"math/rand"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// IA da fauna (30 Hz): cada temperamento reage de um jeito e bichos d'água não saem da água.
const (
	faunaAttackEvery    = 1600 * time.Millisecond
	faunaWanderRadius   = 12
	faunaLeashAggro     = 40
	faunaLeashTerritory = 20
	faunaAmphibianLand  = 8 // anfíbios e répteis d'água se afastam até 8 m da margem
)

func (s *Server) updateFaunaAI(m *world.Mob, dt float32) {
	d, ok := world.FaunaByType(m.MobType)
	if !ok {
		return
	}
	now := time.Now()
	if now.Before(m.StunUntil) {
		return
	}
	m.Mu.RLock()
	mx, mz, zone := m.PosX, m.PosZ, m.ZoneID
	sx, sz, wx, wz := m.SpawnX, m.SpawnZ, m.WanderX, m.WanderZ
	lastHit := m.LastActionTime
	m.Mu.RUnlock()

	// Quem está por perto e quem já machucou o bicho
	dealers := m.GetDamageDealers()
	var near *world.Player
	nearD := float32(1e9)
	var provoker *world.Player
	provD := float32(1e9)
	s.mu.RLock()
	for _, p := range s.players {
		if p.GetZone() != zone || p.IsInAutopsy() {
			continue
		}
		p.Mu.RLock()
		px, pz, hp := p.PosX, p.PosZ, p.HP
		p.Mu.RUnlock()
		if hp == 0 {
			continue
		}
		dd := float32(math.Sqrt(float64(dist2(mx, mz, px, pz))))
		if !p.CanBeDetected(dd) {
			continue
		}
		if dd < nearD {
			near, nearD = p, dd
		}
		if dealers[p.ID] > 0 && dd < provD {
			provoker, provD = p, dd
		}
	}
	s.mu.RUnlock()

	fromSpawn := float32(math.Sqrt(float64(dist2(mx, mz, sx, sz))))
	var target *world.Player
	targetD := float32(0)
	flee := false
	switch d.Temper {
	case world.TemperPassive:
		if provoker != nil && provD < 25 {
			target, targetD, flee = provoker, provD, true
		} else if near != nil && nearD < 9*d.Scale+4 {
			target, targetD, flee = near, nearD, true
		}
	case world.TemperNeutral:
		if provoker != nil && provD < 30 {
			target, targetD = provoker, provD
		}
	case world.TemperAggressive:
		if provoker != nil && provD < 30 {
			target, targetD = provoker, provD
		} else if near != nil && nearD < 16 && fromSpawn < faunaLeashAggro {
			target, targetD = near, nearD
		}
	case world.TemperTerritorial:
		if provoker != nil && provD < 25 {
			target, targetD = provoker, provD
		} else if near != nil && nearD < 7*maxf(1, d.Scale) && fromSpawn < faunaLeashTerritory {
			target, targetD = near, nearD
		}
	}
	// Longe demais de casa: desiste e volta (fera ferida não persegue até o fim do mundo)
	if target != nil && !flee && fromSpawn > faunaLeashAggro {
		target = nil
	}

	speed := d.Speed
	if target == nil {
		m.SetState(protocol.MobStatePatrolIdle)
		if dist2(mx, mz, wx, wz) < 1 || rand.Float32() < 0.003 {
			nx, nz := s.faunaWanderPoint(d, zone, sx, sz)
			m.Mu.Lock()
			m.WanderX, m.WanderZ = nx, nz
			m.Mu.Unlock()
			return
		}
		s.faunaMove(m, d, zone, wx, wz, speed*0.45, dt)
		return
	}
	target.Mu.RLock()
	tx, tz := target.PosX, target.PosZ
	target.Mu.RUnlock()
	if flee {
		m.SetState(protocol.MobStateFleeing)
		ax, az := mx-tx, mz-tz
		l := float32(math.Sqrt(float64(ax*ax + az*az)))
		if l < 0.01 {
			ax, az, l = 1, 0, 1
		}
		s.faunaMove(m, d, zone, mx+ax/l*10, mz+az/l*10, speed*1.25, dt)
		return
	}
	reach := 1.2 + 1.0*d.Scale
	if targetD > reach {
		m.SetState(protocol.MobStateChasing)
		s.faunaMove(m, d, zone, tx, tz, speed, dt)
		return
	}
	m.SetState(protocol.MobStateAttacking)
	if d.Damage <= 0 || now.Sub(lastHit) < faunaAttackEvery {
		return
	}
	m.Mu.Lock()
	m.LastActionTime = now
	m.Mu.Unlock()
	newHP, dead := target.TakeDamage(uint16(d.Damage))
	s.BroadcastCombatEvent(m.ID, target.ID, protocol.ActionBasicAttack, uint16(d.Damage), 0, newHP, target.MaxHP)
	s.sendPlayerStats(target)
	if dead {
		s.RespawnPlayer(target)
	}
}

// faunaMove anda até o alvo respeitando o habitat: peixes só na água, anfíbios perto dela.
func (s *Server) faunaMove(m *world.Mob, d world.FaunaDef, zone uint8, tx, tz, speed, dt float32) {
	if d.Habitat == world.HabitatLand {
		m.MoveTowards(tx, tz, speed, dt)
		return
	}
	m.Mu.RLock()
	ox, oz := m.PosX, m.PosZ
	m.Mu.RUnlock()
	m.MoveTowards(tx, tz, speed, dt)
	m.Mu.RLock()
	nx, nz := m.PosX, m.PosZ
	m.Mu.RUnlock()
	if s.faunaCanStand(d, zone, nx, nz) {
		return
	}
	m.Mu.Lock() // bateu na margem: fica onde estava e escolhe outro rumo
	m.PosX, m.PosZ = ox, oz
	m.WanderX, m.WanderZ = ox, oz
	m.Mu.Unlock()
}

func (s *Server) faunaCanStand(d world.FaunaDef, zone uint8, x, z float32) bool {
	if world.InFaunaWater(d, zone, x, z) {
		return true
	}
	if d.Body == world.FaunaFish {
		return false
	}
	// Anfíbios, répteis e aves d'água: até alguns metros fora da água
	for _, off := range [][2]float32{{faunaAmphibianLand, 0}, {-faunaAmphibianLand, 0}, {0, faunaAmphibianLand}, {0, -faunaAmphibianLand}} {
		if world.InFaunaWater(d, zone, x+off[0], z+off[1]) {
			return true
		}
	}
	return false
}

// faunaWanderPoint: um passeio perto de casa (na água, para os aquáticos).
func (s *Server) faunaWanderPoint(d world.FaunaDef, zone uint8, sx, sz float32) (float32, float32) {
	for tries := 0; tries < 8; tries++ {
		x := sx + (rand.Float32()*2-1)*faunaWanderRadius
		z := sz + (rand.Float32()*2-1)*faunaWanderRadius
		if d.Habitat == world.HabitatLand || s.faunaCanStand(d, zone, x, z) {
			return x, z
		}
	}
	return sx, sz
}

func maxf(a, b float32) float32 {
	if a > b {
		return a
	}
	return b
}
