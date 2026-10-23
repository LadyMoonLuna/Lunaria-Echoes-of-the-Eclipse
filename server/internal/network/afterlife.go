package network

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Mundo Vivo (Fase 1, Parte 3): Coveiro e cemitério, corpos que voltam como zumbis, purificação,
// necromancia e os caçadores da Igreja.

const (
	riteRange        float32 = 4.0
	zombieAggroNPC   float32 = 18 // NPCs de combate vão atrás de zumbis a esta distância
	zombieFleeNPC    float32 = 8  // civis fogem de zumbis próximos
	clericHealRange  float32 = 8
	clericHealAmount         = 60
	clericHealEvery          = 3 * time.Second
	hunterRetireDist float32 = 3
)

// spawnGravedigger cria Mortimer, o Coveiro, ao lado do cemitério.
func spawnGravedigger(clock *world.WorldClock, say world.SayCallback) *world.NPC {
	n := world.NewNPC(world.GravediggerID, "Mortimer, o Coveiro", world.CemeteryOrigin[0]+4, 0, world.CemeteryOrigin[1]+4, "", clock, say)
	n.SetActive(true)
	return n
}

// updateAfterlife roda a 1 Hz: enterros, covas que se erguem e caçadores da Igreja.
func (s *Server) updateAfterlife() {
	s.conflict.mu.Lock()
	s.conflict.lazyInit()
	s.conflict.mu.Unlock()
	s.tickGravedigging()
	s.tickGraveRises()
	s.tickChurchHunters()
}

// --- Coveiro: leva os corpos ao cemitério ao lado da Igreja ---

func (s *Server) gravedigger() *world.NPC {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if g := s.npcs[world.GravediggerID]; g != nil && g.Targetable() && !g.LifeBusy() {
		return g
	}
	if g := s.npcs[world.GravediggerID]; g != nil && g.Alive() {
		return nil // o Coveiro está vivo, só ocupado: espera por ele
	}
	// Sem Coveiro: algum morador comum assume a tarefa
	for id, n := range s.npcs {
		if id != world.GravediggerID && !world.IsLawman(id) && n.Targetable() && !n.LifeBusy() && n.GetZone() == world.ZoneVillage {
			return n
		}
	}
	return nil
}

func (s *Server) tickGravedigging() {
	s.conflict.mu.Lock()
	var tomb *world.Tombstone
	buriedOrClaimed := 0
	for i := range s.conflict.tombstones {
		t := &s.conflict.tombstones[i]
		if t.Buried || s.conflict.tombClaims[t.NPCID] != 0 {
			buriedOrClaimed++
			continue
		}
		if tomb == nil && !t.Rose && world.RouteTo(world.ZoneVillage, t.Zone, t.X, t.Z, "") != nil {
			tomb = t
		}
	}
	var tombCopy world.Tombstone
	if tomb != nil {
		tombCopy = *tomb
	}
	s.conflict.mu.Unlock()
	if tomb == nil {
		return
	}
	digger := s.gravedigger()
	if digger == nil {
		return
	}
	slot := world.CemeterySlot(buriedOrClaimed)
	planned := false
	digger.WithLife(func(n *world.NPC) {
		plan := world.RouteTo(n.ZoneID, tombCopy.Zone, tombCopy.X, tombCopy.Z, "pickup_body")
		if plan == nil {
			return
		}
		plan[len(plan)-1].TombID = tombCopy.NPCID
		back := world.RouteTo(tombCopy.Zone, world.ZoneVillage, slot[0], slot[1], "bury")
		if back == nil {
			return
		}
		back[len(back)-1].TombID = tombCopy.NPCID
		plan = append(plan, back...)
		plan = append(plan, world.RouteTo(world.ZoneVillage, n.Life.HomeZone, n.Life.Home[0], n.Life.Home[1], "")...)
		if n.IsPatrolling {
			n.Life.WasPatrolling = true
			n.IsPatrolling = false
		}
		n.Life.Plan = plan
		planned = true
	})
	if !planned {
		return
	}
	s.conflict.mu.Lock()
	s.conflict.tombClaims[tombCopy.NPCID] = digger.ID
	for i := range s.conflict.tombstones {
		if s.conflict.tombstones[i].NPCID == tombCopy.NPCID {
			s.conflict.tombstones[i].Slot = buriedOrClaimed
		}
	}
	s.conflict.mu.Unlock()
	s.BroadcastNPCSay(digger.ID, fmt.Sprintf("Vou buscar o corpo de %s. Ninguém fica sem cova nesta vila.", tombCopy.Name))
}

// pickupBody: o corpo ainda está lá? (se já se ergueu como zumbi, o enterro é cancelado)
func (s *Server) pickupBody(tombID uint32) bool {
	s.conflict.mu.Lock()
	defer s.conflict.mu.Unlock()
	for i := range s.conflict.tombstones {
		t := &s.conflict.tombstones[i]
		if t.NPCID == tombID {
			if t.Rose || t.Buried {
				delete(s.conflict.tombClaims, tombID)
				return false
			}
			t.Carried = true
			return true
		}
	}
	return false
}

// buryBody move o túmulo para a cova do cemitério.
func (s *Server) buryBody(digger *world.NPC, tombID uint32) {
	s.conflict.mu.Lock()
	var name string
	purified := false
	for i := range s.conflict.tombstones {
		t := &s.conflict.tombstones[i]
		if t.NPCID != tombID || !t.Carried || t.Rose {
			continue
		}
		slot := world.CemeterySlot(t.Slot)
		t.Buried, t.Zone, t.X, t.Z = true, world.ZoneVillage, slot[0], slot[1]
		name = t.Name
		purified = t.Purified
	}
	delete(s.conflict.tombClaims, tombID)
	s.conflict.mu.Unlock()
	if name != "" && !purified && rand.Float64() < world.BurialPlagueChance {
		digger.Infect(world.DiseaseGreyPlague) // mexer em corpo não purificado é arriscado
	}
	if name != "" {
		s.BroadcastNPCSay(digger.ID, fmt.Sprintf("⚰️ %s descansa agora no cemitério, ao lado da Igreja. Que a Luz guarde sua alma.", name))
	}
}

// --- Corpos que se erguem ---

// churchProtects: com o Coveiro ou a Irmã Seraphina vivos, as covas abençoadas não se erguem.
func (s *Server) churchProtects() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, id := range []uint32{world.GravediggerID, world.SeraphinaID} {
		if n := s.npcs[id]; n != nil && n.Alive() {
			return true
		}
	}
	return false
}

func (s *Server) tickGraveRises() {
	protected := s.churchProtects()
	now := time.Now()
	type riser struct {
		name      string
		zone      uint8
		x, z      float32
		maxHP     int
		fromGrave bool
		byZombie  bool
	}
	var rising []riser
	s.conflict.mu.Lock()
	for i := range s.conflict.tombstones {
		t := &s.conflict.tombstones[i]
		if t.Processed() || t.Carried && !t.Buried {
			continue
		}
		interval, chance := world.GraveCheckInterval, world.GraveRiseChanceUnburied
		if t.KilledByZombie {
			chance = world.GraveRiseChanceVictim
		}
		if t.Buried {
			if protected {
				continue
			}
			interval, chance = world.UnprotectedGraveCheck, world.UnprotectedGraveChance
		}
		if now.Sub(t.LastRoll) < interval {
			continue
		}
		t.LastRoll = now
		if rand.Float64() >= chance {
			continue
		}
		t.Rose = true
		delete(s.conflict.tombClaims, t.NPCID)
		rising = append(rising, riser{t.Name, t.Zone, t.X, t.Z, t.MaxHP, t.Buried, t.KilledByZombie})
	}
	s.conflict.mu.Unlock()
	for _, r := range rising {
		z := s.spawnZombie(world.ZombieName(r.name), r.zone, r.x, r.z, r.maxHP/2, world.LevelFromHP(r.maxHP), 0)
		where := "onde caiu"
		if r.fromGrave {
			where = "da própria cova"
		}
		s.BroadcastNPCSay(0, fmt.Sprintf("🧟 O corpo de %s se ergueu %s como ZUMBI! (%s)", r.name, where, z.Name))
	}
}

// processExpiredCorpses substitui a limpeza simples: corpos não aproveitados podem voltar como zumbis.
func (s *Server) processExpiredCorpses() {
	expired := s.corpseManager.ExpireCorpses()
	if len(expired) == 0 {
		return
	}
	for _, c := range expired {
		if c.Processed() {
			continue
		}
		c.Mu.RLock()
		byZombie, name, zone, x, z, maxHP, lvl := c.KilledByZombie, c.MobName, c.ZoneID, c.PosX, c.PosZ, int(c.MobMaxHP), c.MobLevel
		c.Mu.RUnlock()
		if !world.RiseRoll(byZombie, rand.Float64()) {
			continue
		}
		if lvl == 0 {
			lvl = world.LevelFromHP(maxHP)
		}
		zb := s.spawnZombie(world.ZombieName(name), zone, x, z, maxHP, lvl, 0)
		s.BroadcastNPCSay(0, fmt.Sprintf("🧟 Um cadáver esquecido de %s voltou a andar: %s!", name, zb.Name))
	}
	log.Printf("[CORPSE] %d cadáver(es) se decompuseram no solo\n", len(expired))
	s.broadcastCorpseSnapshots()
}

// spawnZombie registra um zumbi novo no mundo.
func (s *Server) spawnZombie(name string, zone uint8, x, z float32, maxHP int, level uint8, owner uint32) *world.Mob {
	zb := world.NewZombie(name, zone, x, z, maxHP, level, owner)
	id := s.mobManager.AddDynamicMob(zb)
	log.Printf("[ZUMBI] #%d '%s' (nível %d, dono %d) ergueu-se na zona %d (%.1f, %.1f)\n", id, name, level, owner, zone, x, z)
	return zb
}

// --- IA dos zumbis: lentos, enxergam pouco, esquecem rápido e atacam tudo o que vive ---

const (
	ztPlayer uint8 = 1
	ztNPC    uint8 = 2
	ztMob    uint8 = 3
)

func (s *Server) updateZombieAI(z *world.Mob, dt float32) {
	now := time.Now()
	z.Mu.RLock()
	zx, zz, zone, owner, level := z.PosX, z.PosZ, z.ZoneID, z.ZombieOwner, z.Level
	tid, tkind, seen, nextHit := z.ZombieTargetID, z.ZombieTargetIs, z.ZombieSeenAt, z.ZombieNextHit
	wx, wz := z.WanderX, z.WanderZ
	z.Mu.RUnlock()

	tx, tz, alive := s.zombieTargetPos(tkind, tid, zone)
	if alive {
		d := dist2(zx, zz, tx, tz)
		if d <= world.ZombiePerception*world.ZombiePerception {
			seen = now
		} else if now.Sub(seen) > world.ZombieForgetAfter {
			alive = false // perdeu o interesse
		}
	}
	if !alive {
		tid, tkind, tx, tz, alive = s.zombieAcquire(z.ID, zx, zz, zone, owner)
		seen = now
	}
	z.Mu.Lock()
	if alive {
		z.ZombieTargetID, z.ZombieTargetIs, z.ZombieSeenAt = tid, tkind, seen
		z.State = protocol.MobStateChasing
	} else {
		z.ZombieTargetID, z.ZombieTargetIs = 0, 0
	}
	z.Mu.Unlock()

	if !alive {
		if owner != 0 { // o servo segue o Necromante
			if p := s.findPlayer(owner); p != nil {
				p.Mu.RLock()
				px, pz, pzone := p.PosX, p.PosZ, p.ZoneID
				p.Mu.RUnlock()
				if pzone != zone {
					z.Mu.Lock()
					z.ZoneID, z.PosX, z.PosZ = pzone, px+1.5, pz+1.5
					z.Mu.Unlock()
					return
				}
				if dist2(zx, zz, px, pz) > world.ZombieFollowOwner*world.ZombieFollowOwner {
					z.MoveTowards(px, pz, world.ZombieSpeed*1.4, dt)
				}
				return
			}
			z.Mu.Lock()
			z.ZombieOwner = 0 // o mestre sumiu: volta a ser selvagem
			z.Mu.Unlock()
		}
		if dist2(zx, zz, wx, wz) < 0.5 || rand.Float32() < 0.004 {
			z.Mu.Lock()
			z.WanderX, z.WanderZ = zx+rand.Float32()*12-6, zz+rand.Float32()*12-6
			z.Mu.Unlock()
			return
		}
		z.MoveTowards(wx, wz, world.ZombieSpeed*0.6, dt)
		return
	}
	if dist2(zx, zz, tx, tz) > world.ZombieReach*world.ZombieReach {
		z.MoveTowards(tx, tz, world.ZombieSpeed, dt)
		return
	}
	if now.Before(nextHit) || now.Before(z.StunUntil) {
		return
	}
	z.Mu.Lock()
	z.ZombieNextHit = now.Add(world.ZombieHitInterval)
	z.Mu.Unlock()
	s.zombieStrike(z, tkind, tid, world.ZombieDamage(level))
}

func dist2(ax, az, bx, bz float32) float32 { return (ax-bx)*(ax-bx) + (az-bz)*(az-bz) }

// zombieTargetPos devolve a posição do alvo atual se ele ainda vive e está na mesma zona.
func (s *Server) zombieTargetPos(kind uint8, id uint32, zone uint8) (float32, float32, bool) {
	switch kind {
	case ztPlayer:
		p := s.findPlayer(id)
		if p == nil || p.GetZone() != zone || p.IsInAutopsy() {
			return 0, 0, false
		}
		p.Mu.RLock()
		defer p.Mu.RUnlock()
		return p.PosX, p.PosZ, p.HP > 0
	case ztNPC:
		s.mu.RLock()
		n := s.npcs[id]
		s.mu.RUnlock()
		if n == nil || !n.Targetable() || n.GetZone() != zone {
			return 0, 0, false
		}
		x, _, z := n.GetPos()
		return x, z, true
	case ztMob:
		m := s.mobManager.GetMob(id)
		if m == nil {
			return 0, 0, false
		}
		m.Mu.RLock()
		defer m.Mu.RUnlock()
		return m.PosX, m.PosZ, m.IsAlive && m.IsActive && m.ZoneID == zone
	}
	return 0, 0, false
}

// zombieAcquire escolhe o ser vivo mais próximo que o zumbi enxerga.
// Servos de Necromante só atacam criaturas e zumbis selvagens perto do mestre.
func (s *Server) zombieAcquire(selfID uint32, zx, zz float32, zone uint8, owner uint32) (uint32, uint8, float32, float32, bool) {
	best := world.ZombiePerception * world.ZombiePerception
	var bid uint32
	var bkind uint8
	var bx, bz float32
	consider := func(id uint32, kind uint8, x, z float32) {
		if d := dist2(zx, zz, x, z); d < best {
			best, bid, bkind, bx, bz = d, id, kind, x, z
		}
	}
	if owner == 0 {
		s.mu.RLock()
		for _, p := range s.players {
			if p.GetZone() != zone || p.IsInAutopsy() {
				continue
			}
			p.Mu.RLock()
			x, z, hp := p.PosX, p.PosZ, p.HP
			p.Mu.RUnlock()
			if hp > 0 {
				consider(p.ID, ztPlayer, x, z)
			}
		}
		for _, n := range s.npcs {
			if n.Targetable() && n.GetZone() == zone {
				x, _, z := n.GetPos()
				consider(n.ID, ztNPC, x, z)
			}
		}
		s.mu.RUnlock()
	}
	for _, m := range s.mobManager.GetAllMobsByZone(zone) {
		if m.ID == selfID {
			continue
		}
		m.Mu.RLock()
		ok := m.IsAlive && m.IsActive
		undead, mOwner, x, z := m.Undead, m.ZombieOwner, m.PosX, m.PosZ
		m.Mu.RUnlock()
		if !ok {
			continue
		}
		if owner == 0 && undead {
			continue // zumbis não atacam mortos-vivos
		}
		if owner != 0 && (mOwner == owner || (undead && mOwner != 0)) {
			continue
		}
		consider(m.ID, ztMob, x, z)
	}
	return bid, bkind, bx, bz, bid != 0
}

// zombieStrike aplica a mordida do zumbi. Quem morre pelas mãos de um zumbi tem mais chance de se erguer.
func (s *Server) zombieStrike(z *world.Mob, kind uint8, id uint32, dmg int) {
	z.Mu.RLock()
	zname, owner := z.Name, z.ZombieOwner
	z.Mu.RUnlock()
	switch kind {
	case ztPlayer:
		p := s.findPlayer(id)
		if p == nil {
			return
		}
		newHP, dead := p.TakeDamage(uint16(dmg))
		s.BroadcastCombatEvent(z.ID, p.ID, protocol.ActionBasicAttack, uint16(dmg), 0, newHP, p.MaxHP)
		s.sendPlayerStats(p)
		if dead {
			s.RespawnPlayer(p)
		}
	case ztNPC:
		s.mu.RLock()
		n := s.npcs[id]
		s.mu.RUnlock()
		if n == nil {
			return
		}
		hp, died := n.TakeDamage(dmg)
		s.BroadcastCombatEvent(z.ID, n.ID, protocol.ActionBasicAttack, uint16(dmg), 0, uint16(hp), uint16(n.MaxHP))
		if died {
			s.handleNPCDeathBy(n, zname, true)
		} else {
			if rand.Float64() < world.ZombieBitePlagueChance && n.Infect(world.DiseaseGreyPlague) {
				log.Printf("[CONTÁGIO] A mordida de %s passou a %s para %s\n", zname, world.DiseaseGreyPlague, n.Name)
			}
			s.onNPCAttacked(n, z.ID, true)
		}
	case ztMob:
		m := s.mobManager.GetMob(id)
		if m == nil {
			return
		}
		final, _, hp, dead := m.TakeDamage(uint16(dmg), owner)
		s.BroadcastCombatEvent(z.ID, m.ID, protocol.ActionBasicAttack, final, 0, hp, m.MaxHP)
		if dead {
			m.Mu.Lock()
			m.KilledByZombie = true
			m.Mu.Unlock()
			s.handleMobDeath(m, owner)
		}
	}
}

// zombiesNear lista os zumbis vivos de uma zona.
func (s *Server) zombiesInZone(zone uint8) []*world.Mob {
	var out []*world.Mob
	for _, m := range s.mobManager.GetAllMobsByZone(zone) {
		m.Mu.RLock()
		ok := m.Undead && m.IsAlive
		m.Mu.RUnlock()
		if ok {
			out = append(out, m)
		}
	}
	return out
}

// tickZombieAwareness: NPCs atacam zumbis sempre; civis fogem dos que chegam perto.
func (s *Server) tickZombieAwareness(n *world.NPC) {
	if s.mobManager == nil {
		return
	}
	busy := false
	n.WithLife(func(g *world.NPC) { busy = g.Life.Aggressor != 0 || g.Life.HuntTarget != 0 })
	if busy {
		return
	}
	nx, _, nz := n.GetPos()
	_, fighter := world.CombatNPCs[n.ID]
	limit := zombieFleeNPC
	if fighter {
		limit = zombieAggroNPC
	}
	var near *world.Mob
	best := limit * limit
	for _, m := range s.zombiesInZone(n.GetZone()) {
		m.Mu.RLock()
		d := dist2(nx, nz, m.PosX, m.PosZ)
		m.Mu.RUnlock()
		if d < best {
			best, near = d, m
		}
	}
	if near != nil {
		s.onNPCAttacked(n, near.ID, true)
	}
}

// handleZombieRemains: zumbis não renascem e somem do mundo depois de destruídos.
func (s *Server) handleZombieRemains(mob *world.Mob) {
	mob.Mu.RLock()
	undead, id, name := mob.Undead, mob.ID, mob.Name
	mob.Mu.RUnlock()
	if !undead {
		return
	}
	s.mobManager.RemoveMob(id)
	log.Printf("[ZUMBI] '%s' (#%d) foi destruído para sempre\n", name, id)
}

// --- Ritos: purificar (Acólitos) e reerguer (Necromante) ---

func (s *Server) handleCorpseRite(p *world.Player, pkt protocol.CorpseRitePacket) {
	p.Mu.RLock()
	px, py, pz, zone, classID, level := p.PosX, p.PosY, p.PosZ, p.ZoneID, p.ClassID, p.Level
	p.Mu.RUnlock()

	var name string
	var bx, bz float32
	var zLevel uint8
	var maxHP int
	var corpse *world.Corpse
	var tombIdx = -1
	switch pkt.Target {
	case protocol.RiteTargetCorpse:
		c, ok := s.corpseManager.GetCorpse(pkt.ID)
		if !ok || c.GetZone() != zone || c.DistanceTo(px, py, pz) > riteRange {
			s.sendPlayerNPCSay(p, 0, "Chegue mais perto do corpo.")
			return
		}
		if c.Processed() {
			s.sendPlayerNPCSay(p, 0, "Este corpo já não responde a nenhum rito.")
			return
		}
		corpse = c
		c.Mu.RLock()
		name, bx, bz, maxHP, zLevel = c.MobName, c.PosX, c.PosZ, int(c.MobMaxHP), c.MobLevel
		c.Mu.RUnlock()
		if zLevel == 0 {
			zLevel = world.LevelFromHP(maxHP)
		}
	case protocol.RiteTargetGrave:
		s.conflict.mu.Lock()
		for i, t := range s.conflict.tombstones {
			if t.NPCID == pkt.ID && t.Zone == zone && dist2(px, pz, t.X, t.Z) <= riteRange*riteRange {
				tombIdx = i
				name, bx, bz, maxHP = t.Name, t.X, t.Z, t.MaxHP
				if t.Processed() {
					tombIdx = -2
				}
			}
		}
		s.conflict.mu.Unlock()
		if tombIdx == -1 {
			s.sendPlayerNPCSay(p, 0, "Chegue mais perto da cova.")
			return
		}
		if tombIdx == -2 {
			s.sendPlayerNPCSay(p, 0, "Este corpo já não responde a nenhum rito.")
			return
		}
		zLevel = world.LevelFromHP(maxHP)
	default:
		return
	}

	mark := func(purify bool) {
		if corpse != nil {
			corpse.Mu.Lock()
			if purify {
				corpse.Purified = true
			} else {
				corpse.NecroTried = true
			}
			corpse.Mu.Unlock()
			return
		}
		s.conflict.mu.Lock()
		if tombIdx >= 0 && tombIdx < len(s.conflict.tombstones) {
			if purify {
				s.conflict.tombstones[tombIdx].Purified = true
			} else {
				s.conflict.tombstones[tombIdx].NecroTried = true
			}
		}
		s.conflict.mu.Unlock()
	}

	switch pkt.Rite {
	case protocol.RitePurify:
		if !world.HolyClasses[classID] {
			s.sendPlayerNPCSay(p, 0, "Só os servos da Luz (Acólitos e suas vertentes) sabem purificar os mortos.")
			return
		}
		mark(true)
		p.AddFriendship(world.SeraphinaID, 3)
		s.sendPlayerNPCSay(p, 0, fmt.Sprintf("✨ Você purificou o corpo de %s. Ele jamais voltará como zumbi.", name))
	case protocol.RiteRaise:
		if !world.IsNecromancer(classID) {
			s.sendPlayerNPCSay(p, 0, "Você não domina as artes proibidas da necromancia.")
			return
		}
		mark(false)
		chance := world.NecroChance(level, zLevel)
		witnesses := s.necromancyWitnesses(zone, bx, bz)
		if rand.Float64() < chance {
			if corpse != nil {
				s.corpseManager.RemoveCorpse(corpse.CorpseID)
				s.broadcastCorpseSnapshots()
			} else {
				s.markTombRisen(tombIdx)
			}
			zb := s.spawnZombie(world.ZombieName(name), zone, bx, bz, maxHP, zLevel, p.ID)
			s.sendPlayerNPCSay(p, 0, fmt.Sprintf("💀 %s se ergue e se curva diante de você! (nível %d, chance %.0f%%)", zb.Name, zLevel, chance*100))
		} else if rand.Float64() < world.NecroFailRiseChance {
			if corpse != nil {
				s.corpseManager.RemoveCorpse(corpse.CorpseID)
				s.broadcastCorpseSnapshots()
			} else {
				s.markTombRisen(tombIdx)
			}
			zb := s.spawnZombie(world.ZombieName(name), zone, bx, bz, maxHP, zLevel, 0)
			s.sendPlayerNPCSay(p, 0, fmt.Sprintf("💀 O ritual falhou e %s se ergueu FORA DE CONTROLE!", zb.Name))
		} else {
			s.sendPlayerNPCSay(p, 0, fmt.Sprintf("O corpo de %s estremece... e se desfaz. O ritual falhou (chance %.0f%%).", name, chance*100))
		}
		if len(witnesses) > 0 {
			s.reportNecromancy(p, witnesses[0], zone)
		}
	}
}

func (s *Server) markTombRisen(idx int) {
	s.conflict.mu.Lock()
	if idx >= 0 && idx < len(s.conflict.tombstones) {
		s.conflict.tombstones[idx].Rose = true
	}
	s.conflict.mu.Unlock()
}

// necromancyWitnesses: NPCs vivos que viram o ritual.
func (s *Server) necromancyWitnesses(zone uint8, x, z float32) []*world.NPC {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var out []*world.NPC
	for _, n := range s.npcs {
		if !n.Targetable() || n.GetZone() != zone {
			continue
		}
		nx, _, nz := n.GetPos()
		if dist2(nx, nz, x, z) <= world.WitnessRange*world.WitnessRange {
			out = append(out, n)
		}
	}
	return out
}

// cityForZone: a cidade da zona ou a cidade colada à zona sem lei.
func cityForZone(zone uint8) uint8 {
	if c := world.CityOfZone(zone); c != 0 {
		return c
	}
	for _, c := range world.Cities {
		if _, ok := c.Lawless[zone]; ok {
			return c.ID
		}
	}
	return 0
}

// reportNecromancy: recompensa URGENTE, hostil na cidade e a Igreja envia Paladinos e Clérigas.
func (s *Server) reportNecromancy(p *world.Player, witness *world.NPC, zone uint8) {
	city := cityForZone(zone)
	p.AddBounty(world.NecroUrgentBounty)
	if city != 0 {
		p.MarkPermanentWanted(city)
	}
	s.BroadcastNPCSay(witness.ID, "NECROMANCIA! Ele está erguendo os mortos! Chamem a Igreja!")
	s.BroadcastNPCSay(0, fmt.Sprintf("⛪ URGENTE! %s foi visto praticando necromancia! Recompensa de +%d Sollares. A Igreja da Luz enviou Paladinos e Clérigas para caçá-lo — ele é HOSTIL em %s!",
		playerName(p), world.NecroUrgentBounty, world.CityName(city)))
	if city == 0 {
		return
	}
	s.dispatchChurchHunters(p)
	s.dispatchLawmen(p, nil)
}

// --- Caçadores da Igreja ---

// dispatchChurchHunters ativa 2 Paladinos e 1 Clériga na porta da Igreja e os põe na caçada.
func (s *Server) dispatchChurchHunters(p *world.Player) {
	want := []uint32{world.PaladinFirstID, world.PaladinFirstID, world.ClericFirstID}
	used := map[uint32]bool{}
	for _, base := range want {
		var hunter *world.NPC
		for i := uint32(0); i < world.ChurchHunterMax && hunter == nil; i++ {
			id := base + i
			if used[id] {
				continue
			}
			s.mu.RLock()
			n := s.npcs[id]
			s.mu.RUnlock()
			switch {
			case n == nil:
				name := fmt.Sprintf("Paladino da Luz %s", romanNumeral(int(i)+1))
				if world.IsCleric(id) {
					name = fmt.Sprintf("Clériga da Luz %s", romanNumeral(int(i)+1))
				}
				n = world.NewNPC(id, name, world.ChurchDoor[0], 0, world.ChurchDoor[1], "", s.clock, s.BroadcastNPCSay)
				n.InitLife(world.ChurchDoor)
				s.mu.Lock()
				s.npcs[id] = n
				s.mu.Unlock()
				hunter = n
			case n.Alive() && !n.GetActive():
				n.Teleport(world.ChurchDoor[0], 0, world.ChurchDoor[1])
				n.SetZone(world.ZoneVillage)
				hunter = n
			}
			if hunter != nil {
				used[id] = true
			}
		}
		if hunter == nil {
			continue // todos os caçadores já estão na rua (ou morreram)
		}
		hunter.SetActive(true)
		startHunt(hunter, p.ID)
		s.BroadcastNPCSay(hunter.ID, "Pela Luz! O profanador de túmulos não escapará!")
	}
}

func romanNumeral(n int) string {
	nums := []string{"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"}
	if n >= 1 && n <= len(nums) {
		return nums[n-1]
	}
	return fmt.Sprint(n)
}

// tickChurchHunters: Clérigas curam aliados; caçadores ociosos voltam à Igreja e se recolhem.
func (s *Server) tickChurchHunters() {
	s.mu.RLock()
	var hunters []*world.NPC
	for id, n := range s.npcs {
		if world.IsChurchHunter(id) && n.Targetable() {
			hunters = append(hunters, n)
		}
	}
	s.mu.RUnlock()
	now := time.Now()
	for _, h := range hunters {
		var hunting bool
		h.WithLife(func(g *world.NPC) { hunting = g.Life.HuntTarget != 0 || g.Life.Aggressor != 0 })
		if world.IsCleric(h.ID) {
			s.clericHeal(h, now)
		}
		if hunting {
			continue
		}
		x, _, z := h.GetPos()
		if h.GetZone() == world.ZoneVillage && dist2(x, z, world.ChurchDoor[0], world.ChurchDoor[1]) <= hunterRetireDist*hunterRetireDist {
			h.SetActive(false) // entrou na Igreja
			continue
		}
		if h.GetZone() != world.ZoneVillage {
			h.SetZone(world.ZoneVillage)
			h.Teleport(world.ChurchDoor[0]+2, 0, world.ChurchDoor[1])
			continue
		}
		h.SetTarget(world.ChurchDoor[0], world.ChurchDoor[1], 3.0)
	}
}

// clericHeal: a cada 3 s a Clériga cura +60 HP dos aliados da lei próximos.
func (s *Server) clericHeal(cleric *world.NPC, now time.Time) {
	s.conflict.mu.Lock()
	recent := now.Sub(s.conflict.lastHeal[cleric.ID]) < clericHealEvery
	if !recent {
		s.conflict.lastHeal[cleric.ID] = now
	}
	s.conflict.mu.Unlock()
	if recent {
		return
	}
	cx, _, cz := cleric.GetPos()
	zone := cleric.GetZone()
	s.mu.RLock()
	var allies []*world.NPC
	for id, n := range s.npcs {
		if world.IsLawman(id) && n.Targetable() && n.GetZone() == zone {
			x, _, z := n.GetPos()
			if dist2(cx, cz, x, z) <= clericHealRange*clericHealRange {
				allies = append(allies, n)
			}
		}
	}
	s.mu.RUnlock()
	for _, a := range allies {
		if a.HP < a.MaxHP {
			a.Heal(clericHealAmount)
		}
	}
}
