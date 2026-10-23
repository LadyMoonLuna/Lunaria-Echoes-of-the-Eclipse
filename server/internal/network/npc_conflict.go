package network

import (
	"fmt"
	"log"
	"math"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Mundo Vivo (Fase 1, Parte 2): ataques a NPCs, crime e caçada da Guarda, morte permanente com túmulo,
// sucessão por aprendizes e contratação/migração de NPCs.

const (
	npcChaseGiveUp  float32 = 25  // revide: desiste se o agressor fugir para longe
	mobAggroOnNPC   float32 = 2.4 // mob ataca NPC a esta distância
	mobNPCInterval          = 1500 * time.Millisecond
	studyTableRange float32 = 3.0
	followDistance  float32 = 3.0
	civilianHelpMsg         = "Socorro! Guardas! Estou sendo atacado!"
)

type conflictState struct {
	mu          sync.Mutex
	tombstones  []world.Tombstone
	treasury    uint32               // tesouro da Vila (recompensas sem família viva)
	mobStrikes  map[uint32]time.Time // último golpe de cada mob em NPCs
	crimeVictim map[uint32]uint32    // jogador -> última vítima (a família recebe a recompensa)
	fountainDry bool
	tombClaims  map[uint32]uint32 // túmulo -> NPC que está levando o corpo
	lastHeal    map[uint32]time.Time
	epidemics   map[string]bool // doença -> epidemia declarada
}

func (c *conflictState) lazyInit() {
	if c.mobStrikes == nil {
		c.mobStrikes = map[uint32]time.Time{}
		c.crimeVictim = map[uint32]uint32{}
		c.tombClaims = map[uint32]uint32{}
		c.lastHeal = map[uint32]time.Time{}
	}
}

// spawnApprentices cria os jovens moradores que podem herdar os ofícios.
func spawnApprentices(clock *world.WorldClock, say world.SayCallback) []*world.NPC {
	out := make([]*world.NPC, 0, len(world.Apprentices))
	for _, a := range world.Apprentices {
		n := world.NewNPC(a.ID, fmt.Sprintf("%s, %s", a.Name, world.Professions[a.ID]), a.X, 0, a.Z, "", clock, say)
		n.SetActive(true)
		out = append(out, n)
	}
	return out
}

// --- Pacotes 0x4B / 0x4C / 0x4D ---

func (s *Server) handleConflictPacket(playerID uint32, data []byte) {
	s.mu.RLock()
	player := s.players[playerID]
	s.mu.RUnlock()
	if player == nil {
		return
	}
	switch data[0] {
	case protocol.PacketTypeSetPKMode:
		on := data[1] != 0
		player.SetPKMode(on)
		msg := "🕊️ Postura Pacífica: a trava de segurança está ligada."
		if on {
			msg = "⚔️ Postura Hostil: a trava de segurança está DESLIGADA. Ferir cidadãos é crime!"
		}
		s.sendPlayerNPCSay(player, 0, msg)
	case protocol.PacketTypeNPCContract:
		var pkt protocol.NPCContractPacket
		if protocol.DeserializeNPCContract(data, &pkt) == nil {
			s.handleNPCContract(player, pkt)
		}
	case protocol.PacketTypeTombstoneRequest:
		writeTCP(player, protocol.SerializeTombstones(s.tombstoneEntries()))
	case protocol.PacketTypeCorpseRite:
		var pkt protocol.CorpseRitePacket
		if protocol.DeserializeCorpseRite(data, &pkt) == nil {
			s.handleCorpseRite(player, pkt)
		}
	}
}

func (s *Server) tombstoneEntries() []protocol.TombstoneEntry {
	s.conflict.mu.Lock()
	defer s.conflict.mu.Unlock()
	out := make([]protocol.TombstoneEntry, 0, len(s.conflict.tombstones))
	for _, t := range s.conflict.tombstones {
		out = append(out, protocol.TombstoneEntry{NPCID: t.NPCID, Zone: t.Zone, X: t.X, Z: t.Z,
			Name: t.Name, Profession: t.Profession, Killer: t.Killer})
	}
	return out
}

// --- Ataques contra NPCs ---

func playerName(p *world.Player) string { return fmt.Sprintf("Jogador #%d", p.ID) }

// playerHitNPC aplica o golpe de um jogador em Postura Hostil a um NPC.
func (s *Server) playerHitNPC(player *world.Player, npc *world.NPC, damage uint16, isCrit uint8, action uint8) {
	hp, died := npc.TakeDamage(int(damage))
	s.BroadcastCombatEvent(player.ID, npc.ID, action, damage, isCrit, uint16(hp), uint16(npc.MaxHP))
	log.Printf("[CRIME] Jogador #%d feriu o NPC '%s' (#%d) com %d de dano | HP %d/%d\n", player.ID, npc.Name, npc.ID, damage, hp, npc.MaxHP)
	if world.IsVillageCitizen(npc.ID) {
		s.registerCrime(player, npc, died)
	}
	if died {
		s.handleNPCDeath(npc, playerName(player))
		return
	}
	s.onNPCAttacked(npc, player.ID, false)
}

// registerCrime: +100 por golpe, +300 por assassinato e +200 por assassinato consecutivo; a Guarda inicia a caçada.
func (s *Server) registerCrime(player *world.Player, victim *world.NPC, killed bool) {
	var r world.CrimeResult
	if killed {
		r = player.RegisterMurder()
	} else {
		r = player.RegisterHit()
	}
	s.conflict.mu.Lock()
	s.conflict.lazyInit()
	s.conflict.crimeVictim[player.ID] = victim.ID
	s.conflict.mu.Unlock()
	switch {
	case !r.WasWanted:
		s.BroadcastNPCSay(0, fmt.Sprintf("🚨 CRIME NA VILA! %s atacou %s! Os Guardas Reais iniciaram a caçada!", playerName(player), victim.Name))
	case killed:
		s.BroadcastNPCSay(0, fmt.Sprintf("🚨 ASSASSINATO! %s matou %s! Recompensa: %d Sollares (+%d).", playerName(player), victim.Name, r.Bounty, r.Added))
	}
	if r.BecamePermanent {
		s.BroadcastNPCSay(0, fmt.Sprintf("☠️ %s já assassinou %d cidadãos e agora é PROCURADO PARA SEMPRE em todas as cidades vizinhas!", playerName(player), r.Murders))
	}
	s.dispatchLawmen(player, victim)
}

// dispatchLawmen manda os Guardas (e caçadores da Igreja ativos) da cidade atrás do jogador.
func (s *Server) dispatchLawmen(player *world.Player, exclude *world.NPC) {
	zone := player.GetZone()
	city := world.CityOfZone(zone)
	if city == 0 {
		return
	}
	s.mu.RLock()
	lawmen := make([]*world.NPC, 0, 4)
	for id, n := range s.npcs {
		if world.IsLawman(id) && n != exclude && n.Targetable() && world.CityOfZone(n.GetZone()) == city {
			lawmen = append(lawmen, n)
		}
	}
	s.mu.RUnlock()
	for _, g := range lawmen {
		startHunt(g, player.ID)
	}
}

func startHunt(guard *world.NPC, playerID uint32) {
	guard.WithLife(func(g *world.NPC) {
		if g.Life.HuntTarget == 0 && g.IsPatrolling {
			g.Life.WasPatrolling = true
			g.IsPatrolling = false
		}
		if g.Life.HuntTarget == 0 {
			g.Life.PursuitHomeZone = g.ZoneID
			g.Life.PursuitHome = [2]float32{g.PosX, g.PosZ}
		}
		g.Life.HuntTarget = playerID
		g.Life.Plan = nil
		g.CurrentActivity = world.ActivityHunting
	})
}

// onNPCAttacked: NPCs de combate revidam; civis gritam por socorro e fogem até o Guarda mais próximo.
func (s *Server) onNPCAttacked(npc *world.NPC, attackerID uint32, isMob bool) {
	_, fighter := world.CombatNPCs[npc.ID]
	if npc.Profession != 0 && npc.Profession != npc.ID {
		_, fighter = world.CombatNPCs[npc.Profession] // o novo Ferreiro também empunha o martelo
	}
	if fighter {
		first := false
		npc.WithLife(func(n *world.NPC) {
			first = n.Life.Aggressor == 0
			n.Life.Aggressor, n.Life.AggressorIsMob = attackerID, isMob
			n.Life.Plan = nil
			if n.IsPatrolling {
				n.Life.WasPatrolling = true
				n.IsPatrolling = false
			}
			n.CurrentActivity = world.ActivityFighting
		})
		if first {
			s.BroadcastNPCSay(npc.ID, "Você escolheu o adversário errado!")
		}
		return
	}
	gx, gz, found := s.nearestGuardPos(npc)
	fleeing := false
	npc.WithLife(func(n *world.NPC) {
		if n.CurrentActivity == world.ActivityFleeing && len(n.Life.Plan) > 0 {
			return
		}
		fleeing = true
		n.CurrentActivity = world.ActivityFleeing
		if found {
			n.Life.Plan = []world.ErrandStep{{Zone: n.ZoneID, X: gx, Z: gz, Action: "flee"}}
		}
	})
	if fleeing {
		s.BroadcastNPCSay(npc.ID, civilianHelpMsg)
	}
}

func (s *Server) nearestGuardPos(npc *world.NPC) (float32, float32, bool) {
	nx, _, nz := npc.GetPos()
	zone := npc.GetZone()
	best := float32(-1)
	var bx, bz float32
	for _, id := range world.GuardNPCs {
		s.mu.RLock()
		g := s.npcs[id]
		s.mu.RUnlock()
		if g == nil || g == npc || !g.Targetable() || g.GetZone() != zone {
			continue
		}
		gx, _, gz := g.GetPos()
		d := (gx-nx)*(gx-nx) + (gz-nz)*(gz-nz)
		if best < 0 || d < best {
			best, bx, bz = d, gx, gz
		}
	}
	return bx, bz, best >= 0
}

// --- Morte permanente ---

// handleNPCDeath: túmulo, espólio no chão, anúncio solene. O NPC nunca renasce.
func (s *Server) handleNPCDeath(npc *world.NPC, killer string) {
	s.handleNPCDeathBy(npc, killer, false)
}

func (s *Server) handleNPCDeathBy(npc *world.NPC, killer string, byZombie bool) {
	x, _, z := npc.GetPos()
	zone := npc.GetZone()
	profession := npc.ProfessionName()
	npc.WithLife(func(n *world.NPC) {
		if !n.IsDead {
			n.HP = 0
			n.IsDead = true
		}
		n.IsActive, n.ShopOpen = false, false
	})
	s.conflict.mu.Lock()
	s.conflict.tombstones = append(s.conflict.tombstones, world.Tombstone{NPCID: npc.ID, Name: npc.Name,
		Profession: profession, Killer: killer, Zone: zone, X: x, Z: z, DiedAt: time.Now(),
		MaxHP: npc.MaxHP, KilledByZombie: byZombie, LastRoll: time.Now()})
	s.conflict.mu.Unlock()

	items, gold := npc.TakeEstate()
	for item, qty := range items {
		for qty > 0 {
			q := min(qty, 255)
			s.groundItems.Drop(uint8(item), uint8(q), 75, x, z, zone)
			qty -= q
		}
	}
	if gold > 0 {
		s.conflict.mu.Lock()
		s.conflict.treasury += gold // o ouro vai para o tesouro da Vila (herança)
		s.conflict.mu.Unlock()
	}
	if len(items) > 0 {
		s.broadcastGroundItems(zone)
	}
	log.Printf("[PERMADEATH] NPC '%s' (#%d, %s) morto por %s em zona %d (%.1f, %.1f)\n", npc.Name, npc.ID, profession, killer, zone, x, z)
	s.BroadcastNPCSay(0, fmt.Sprintf("⚰️ [MORTE PERMANENTE] O NPC %s (%s) foi morto por %s! Sua oficina está fechada até que alguém herde ou aprenda seu ofício.",
		npc.Name, profession, killer))
}

// --- Tick de conflito (1 Hz) ---

func (s *Server) updateNPCConflict(dt float32) {
	s.mu.RLock()
	players := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		players = append(players, p)
	}
	npcs := make([]*world.NPC, 0, len(s.npcs))
	for _, n := range s.npcs {
		npcs = append(npcs, n)
	}
	s.mu.RUnlock()

	for _, p := range players {
		p.TickWanted(dt)
	}
	hour := s.clock.GetCurrentHour()
	for _, n := range npcs {
		if !n.Targetable() {
			continue
		}
		s.tickGuardHunt(n)
		s.tickRetaliation(n)
		s.tickFollowing(n)
		s.tickZombieAwareness(n)
		s.tickApprentice(n, dt, hour)
		s.tickGraduateRoutine(n, hour)
	}
	s.tickMobsVersusNPCs(npcs)
}

func (s *Server) findPlayer(id uint32) *world.Player {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.players[id]
}

// chaseAndStrike move o NPC até o jogador e golpeia quando perto. Retorna (alcançável, matou).
func (s *Server) chaseAndStrike(n *world.NPC, p *world.Player, speed float32, dmg int) (bool, bool) {
	p.Mu.RLock()
	px, pz, zone := p.PosX, p.PosZ, p.ZoneID
	p.Mu.RUnlock()
	strike := false
	ok := true
	n.WithLife(func(g *world.NPC) {
		if g.ZoneID != zone {
			ok = false
			return
		}
		dx, dz := px-g.PosX, pz-g.PosZ
		dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
		if dist > npcChaseGiveUp*2 {
			ok = false
			return
		}
		if dist > world.NPCStrikeRange {
			g.TargetX, g.TargetZ, g.MoveSpeed, g.State = px, pz, speed, 1
			return
		}
		g.MoveSpeed = 0
		if time.Since(g.Life.LastStrike) >= world.NPCStrikeInterval {
			g.Life.LastStrike = time.Now()
			strike = true
		}
	})
	if !ok || !strike {
		return ok, false
	}
	newHP, dead := p.TakeDamage(uint16(dmg))
	s.BroadcastCombatEvent(n.ID, p.ID, protocol.ActionBasicAttack, uint16(dmg), 0, newHP, p.MaxHP)
	s.sendPlayerStats(p)
	return true, dead
}

func endPursuit(g *world.NPC) {
	g.Life.HuntTarget = 0
	g.Life.Aggressor = 0
	g.MoveSpeed = 0
	if g.Life.WasPatrolling {
		g.IsPatrolling = true
		g.Life.WasPatrolling = false
	}
	g.CurrentActivity = world.ActivityWorking
}

// tickGuardHunt: o Guarda persegue o criminoso (+35% de velocidade) pela cidade e um pouco além,
// para dentro dos Esgotos/Mercado Negro. Se ele escapar lá dentro, vira procurado permanente nesta cidade.
func (s *Server) tickGuardHunt(n *world.NPC) {
	var target uint32
	var homeZone uint8
	n.WithLife(func(g *world.NPC) { target, homeZone = g.Life.HuntTarget, g.Life.PursuitHomeZone })
	if target == 0 {
		s.spotWanted(n)
		return
	}
	city := world.CityOfZone(homeZone)
	p := s.findPlayer(target)
	if p == nil || !p.IsWantedIn(city) {
		s.returnFromPursuit(n)
		return
	}
	pzone := p.GetZone()
	nzone := n.GetZone()
	c, _ := world.CityByID(city)
	if pzone != nzone {
		switch {
		case world.CityOfZone(pzone) == city:
			// voltou para outra área da cidade: o Guarda vai atrás
			p.Mu.RLock()
			px, pz := p.PosX, p.PosZ
			p.Mu.RUnlock()
			n.WithLife(func(g *world.NPC) { g.ZoneID, g.PosX, g.PosZ, g.TargetX, g.TargetZ = pzone, px+2, pz+2, px+2, pz+2 })
		case world.IsLawlessZone(pzone) && c.Lawless != nil:
			if entry, ok := c.Lawless[pzone]; ok {
				n.WithLife(func(g *world.NPC) {
					g.ZoneID, g.PosX, g.PosZ, g.TargetX, g.TargetZ = pzone, entry[0], entry[1], entry[0], entry[1]
				})
				s.BroadcastNPCSay(n.ID, "Não vai escapar pelos túneis! Atrás dele!")
			}
		default:
			s.returnFromPursuit(n)
			return
		}
	}
	if world.IsLawlessZone(pzone) {
		entry := c.Lawless[pzone]
		p.Mu.RLock()
		dx, dz := p.PosX-entry[0], p.PosZ-entry[1]
		p.Mu.RUnlock()
		if dx*dx+dz*dz > world.LawlessPursuitRadius*world.LawlessPursuitRadius {
			if p.MarkPermanentWanted(city) {
				s.BroadcastNPCSay(0, fmt.Sprintf("📜 %s se escondeu nas sombras... A Guarda desistiu, mas ele agora é PROCURADO PERMANENTE em %s!",
					playerName(p), world.CityName(city)))
			}
			s.returnFromPursuit(n)
			return
		}
	}
	reach, killed := s.chaseAndStrike(n, p, world.GuardBaseSpeed*world.GuardHuntSpeedMult, world.CombatNPCs[n.ID])
	if !reach {
		s.returnFromPursuit(n)
		return
	}
	if killed {
		s.guardKilledCriminal(n, p)
	}
}

// spotWanted: Guardas e caçadores ociosos reconhecem procurados na cidade e atacam à vista.
func (s *Server) spotWanted(n *world.NPC) {
	if !world.IsLawman(n.ID) {
		return
	}
	zone := n.GetZone()
	city := world.CityOfZone(zone)
	if city == 0 {
		return
	}
	nx, _, nz := n.GetPos()
	s.mu.RLock()
	var seen *world.Player
	for _, p := range s.players {
		if p.GetZone() != zone || !p.IsWantedIn(city) {
			continue
		}
		p.Mu.RLock()
		dx, dz := p.PosX-nx, p.PosZ-nz
		p.Mu.RUnlock()
		if dx*dx+dz*dz <= 30*30 {
			seen = p
			break
		}
	}
	s.mu.RUnlock()
	if seen != nil {
		startHunt(n, seen.ID)
		s.BroadcastNPCSay(n.ID, fmt.Sprintf("Alto lá, %s! Você é procurado em %s!", playerName(seen), world.CityName(city)))
	}
}

// returnFromPursuit encerra a caçada e devolve o perseguidor ao seu posto.
func (s *Server) returnFromPursuit(n *world.NPC) {
	n.WithLife(func(g *world.NPC) {
		if g.Life.HuntTarget != 0 && g.ZoneID != g.Life.PursuitHomeZone {
			g.ZoneID = g.Life.PursuitHomeZone
			g.PosX, g.PosZ = g.Life.PursuitHome[0], g.Life.PursuitHome[1]
			g.TargetX, g.TargetZ = g.PosX, g.PosZ
		}
		endPursuit(g)
	})
}

// guardKilledCriminal: o criminoso paga a recompensa à família da vítima (ou ao tesouro) e renasce preso.
func (s *Server) guardKilledCriminal(guard *world.NPC, p *world.Player) {
	paid := p.PayBountyAndJail()
	s.conflict.mu.Lock()
	s.conflict.lazyInit()
	victimID := s.conflict.crimeVictim[p.ID]
	delete(s.conflict.crimeVictim, p.ID)
	s.conflict.mu.Unlock()
	s.mu.RLock()
	victim := s.npcs[victimID]
	s.mu.RUnlock()
	beneficiary := "o tesouro da Vila"
	if victim != nil && victim.Alive() {
		victim.WithLife(func(v *world.NPC) { v.Gold += paid })
		beneficiary = victim.Name
	} else {
		s.conflict.mu.Lock()
		s.conflict.treasury += paid
		s.conflict.mu.Unlock()
	}
	p.Respawn(world.JailX, 1.5, world.JailZ)
	s.BroadcastPlayerRespawn(p.ID, world.JailX, 1.5, world.JailZ)
	s.sendPlayerStats(p)
	s.sendInventorySync(p)
	s.mu.RLock()
	hunters := make([]*world.NPC, 0, 4)
	for _, g := range s.npcs {
		hunters = append(hunters, g)
	}
	s.mu.RUnlock()
	for _, g := range hunters {
		hunting := false
		g.WithLife(func(gg *world.NPC) { hunting = gg.Life.HuntTarget == p.ID })
		if hunting {
			s.returnFromPursuit(g)
		}
	}
	s.BroadcastNPCSay(guard.ID, fmt.Sprintf("⛓️ Justiça feita! %s foi abatido e levado à cela. %d Sollares de recompensa foram para %s.",
		playerName(p), paid, beneficiary))
}

// tickRetaliation: NPCs de combate revidam contra o agressor (jogador ou monstro).
func (s *Server) tickRetaliation(n *world.NPC) {
	var aggr uint32
	var isMob bool
	n.WithLife(func(g *world.NPC) { aggr, isMob = g.Life.Aggressor, g.Life.AggressorIsMob })
	if aggr == 0 {
		return
	}
	dmg := world.CombatNPCs[n.ID]
	if dmg == 0 {
		dmg = 45
	}
	if isMob {
		var mob *world.Mob
		if s.mobManager != nil {
			mob = s.mobManager.GetMob(aggr)
		}
		if mob == nil || !mob.IsAlive || mob.GetZone() != n.GetZone() {
			n.WithLife(endPursuit)
			return
		}
		mob.Mu.RLock()
		mx, mz := mob.PosX, mob.PosZ
		mob.Mu.RUnlock()
		strike := false
		n.WithLife(func(g *world.NPC) {
			dx, dz := mx-g.PosX, mz-g.PosZ
			if dx*dx+dz*dz > world.NPCStrikeRange*world.NPCStrikeRange {
				g.TargetX, g.TargetZ, g.MoveSpeed, g.State = mx, mz, world.GuardBaseSpeed, 1
			} else if time.Since(g.Life.LastStrike) >= world.NPCStrikeInterval {
				g.Life.LastStrike = time.Now()
				strike = true
			}
		})
		if strike {
			s.handleNPCAttackMob(n.ID, mob.ID, uint16(dmg))
		}
		return
	}
	p := s.findPlayer(aggr)
	if p == nil {
		n.WithLife(endPursuit)
		return
	}
	reach, killed := s.chaseAndStrike(n, p, world.GuardBaseSpeed, dmg)
	if !reach || killed {
		n.WithLife(endPursuit)
	}
	if killed {
		if p.IsWanted() {
			s.guardKilledCriminal(n, p)
		} else {
			s.RespawnPlayer(p)
		}
	}
}

// tickMobsVersusNPCs: monstros que alcançam um NPC (invasão da vila ou coleta fora dos muros) o atacam.
func (s *Server) tickMobsVersusNPCs(npcs []*world.NPC) {
	if s.mobManager == nil {
		return
	}
	now := time.Now()
	for _, mob := range s.mobManager.GetAllMobs() {
		mob.Mu.RLock()
		alive := mob.IsAlive && mob.IsActive && now.After(mob.PolymorphUntil) && !mob.Undead // zumbis têm IA própria
		mx, mz, zone, maxHP, name := mob.PosX, mob.PosZ, mob.ZoneID, mob.MaxHP, mob.Name
		mob.Mu.RUnlock()
		if !alive {
			continue
		}
		s.conflict.mu.Lock()
		s.conflict.lazyInit()
		recent := now.Sub(s.conflict.mobStrikes[mob.ID]) < mobNPCInterval
		s.conflict.mu.Unlock()
		if recent {
			continue
		}
		for _, n := range npcs {
			if !n.Targetable() || n.GetZone() != zone {
				continue
			}
			nx, _, nz := n.GetPos()
			if (nx-mx)*(nx-mx)+(nz-mz)*(nz-mz) > mobAggroOnNPC*mobAggroOnNPC {
				continue
			}
			s.conflict.mu.Lock()
			s.conflict.mobStrikes[mob.ID] = now
			s.conflict.mu.Unlock()
			dmg := 20 + int(maxHP)/50
			hp, died := n.TakeDamage(dmg)
			s.BroadcastCombatEvent(mob.ID, n.ID, protocol.ActionBasicAttack, uint16(dmg), 0, uint16(hp), uint16(n.MaxHP))
			if died {
				s.handleNPCDeath(n, name)
			} else {
				s.onNPCAttacked(n, mob.ID, true)
			}
			break
		}
	}
}

// --- Contratação e migração ---

func (s *Server) handleNPCContract(p *world.Player, pkt protocol.NPCContractPacket) {
	s.mu.RLock()
	npc := s.npcs[pkt.NPCID]
	s.mu.RUnlock()
	if npc == nil || !npc.Targetable() {
		s.sendPlayerNPCSay(p, 0, "Esse NPC não pode atender ninguém.")
		return
	}
	p.Mu.RLock()
	px, py, pz, zone := p.PosX, p.PosY, p.PosZ, p.ZoneID
	p.Mu.RUnlock()
	if npc.GetZone() != zone || npc.DistanceTo(px, py, pz) > shopTradeRange {
		s.sendPlayerNPCSay(p, 0, "Chegue mais perto para conversar sobre isso.")
		return
	}
	switch pkt.Action {
	case protocol.ContractHire:
		s.hireNPC(p, npc)
	case protocol.ContractTrain:
		s.trainApprentice(p, npc)
	case protocol.ContractSettle, protocol.ContractDismiss:
		ok := false
		npc.WithLife(func(n *world.NPC) {
			if n.Life.Following != p.ID {
				return
			}
			ok = true
			n.Life.Following = 0
			n.CurrentActivity = world.ActivityWorking
			if pkt.Action == protocol.ContractSettle {
				n.Life.Home = [2]float32{px, pz}
				n.Life.HomeZone = zone
				n.ShopOpen = n.Profession != 0
			}
		})
		if !ok {
			s.sendPlayerNPCSay(p, npc.ID, "Eu não trabalho para você.")
		} else if pkt.Action == protocol.ContractSettle {
			s.BroadcastNPCSay(npc.ID, fmt.Sprintf("Este será meu novo lar: %s. Mãos à obra!", world.GetZoneName(zone)))
		} else {
			s.sendPlayerNPCSay(p, npc.ID, "Foi uma honra. Vou voltar para casa.")
		}
	}
}

func (s *Server) hireNPC(p *world.Player, npc *world.NPC) {
	if p.GetFriendship(npc.ID) < world.HireMinFriendship {
		s.sendPlayerNPCSay(p, npc.ID, "Mal nos conhecemos... volte quando formos amigos de verdade (❤️❤️❤️♡♡).")
		return
	}
	taken := false
	npc.WithLife(func(n *world.NPC) { taken = n.Life.Following != 0 })
	if taken {
		s.sendPlayerNPCSay(p, npc.ID, "Já sirvo a outra pessoa.")
		return
	}
	p.Mu.Lock()
	paid := p.Gold >= world.HireFee
	if paid {
		p.Gold -= world.HireFee
	}
	p.Mu.Unlock()
	if !paid {
		s.sendPlayerNPCSay(p, npc.ID, fmt.Sprintf("Meu trabalho custa %d Sollares.", world.HireFee))
		return
	}
	npc.WithLife(func(n *world.NPC) {
		n.Gold += world.HireFee
		n.Life.Following = p.ID
		n.Life.Plan = nil
		if n.IsPatrolling {
			n.Life.WasPatrolling = true
			n.IsPatrolling = false
		}
		n.ShopOpen = false
		n.CurrentActivity = world.ActivityHired
	})
	s.sendInventorySync(p)
	s.BroadcastNPCSay(npc.ID, fmt.Sprintf("Fechado! Sigo %s para onde for preciso.", playerName(p)))
}

// tickFollowing: o contratado segue o jogador e migra junto pelos portais.
func (s *Server) tickFollowing(n *world.NPC) {
	var owner uint32
	n.WithLife(func(g *world.NPC) { owner = g.Life.Following })
	if owner == 0 {
		return
	}
	p := s.findPlayer(owner)
	if p == nil {
		n.WithLife(func(g *world.NPC) { g.Life.Following = 0; g.CurrentActivity = world.ActivityWorking })
		return
	}
	p.Mu.RLock()
	px, pz, zone := p.PosX, p.PosZ, p.ZoneID
	p.Mu.RUnlock()
	n.WithLife(func(g *world.NPC) {
		if g.ZoneID != zone { // atravessou o portal com o contratante
			g.ZoneID = zone
			g.PosX, g.PosZ = px+1.5, pz+1.5
			g.TargetX, g.TargetZ, g.MoveSpeed = g.PosX, g.PosZ, 0
			return
		}
		dx, dz := px-g.PosX, pz-g.PosZ
		if dx*dx+dz*dz > followDistance*followDistance {
			g.TargetX, g.TargetZ, g.MoveSpeed, g.State = px, pz, 3.0, 1
		} else {
			g.MoveSpeed = 0
		}
	})
}

// --- Sucessão de ofícios ---

func (s *Server) professionHeld(master uint32) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, n := range s.npcs {
		if n.Alive() && n.Profession == master {
			return true
		}
	}
	return false
}

func apprenticeOf(id uint32) (world.Apprentice, bool) {
	for _, a := range world.Apprentices {
		if a.ID == id {
			return a, true
		}
	}
	return world.Apprentice{}, false
}

// tickApprentice: com o mestre morto, o aprendiz estuda de dia na Mesa de Blueprints da oficina vazia.
func (s *Server) tickApprentice(n *world.NPC, dt float32, hour int) {
	a, ok := apprenticeOf(n.ID)
	if !ok || n.Profession != 0 {
		return
	}
	s.mu.RLock()
	master := s.npcs[a.Master]
	s.mu.RUnlock()
	if master == nil || master.Alive() || s.professionHeld(a.Master) {
		return
	}
	var table [2]float32
	var tableZone uint8
	master.WithLife(func(m *world.NPC) { table, tableZone = m.Life.Home, m.Life.HomeZone })
	graduate := false
	announce := false
	n.WithLife(func(g *world.NPC) {
		if g.Life.Following != 0 || g.Life.Aggressor != 0 || len(g.Life.Plan) > 0 {
			return
		}
		if g.Life.StudyingFor == 0 {
			g.Life.StudyingFor = a.Master
			announce = true
		}
		if g.Life.StudyProgress >= world.StudySecondsToGraduate {
			graduate = true
			return
		}
		if hour < 6 || hour >= 18 || g.ZoneID != tableZone {
			return
		}
		dx, dz := table[0]-g.PosX, table[1]-g.PosZ
		if dx*dx+dz*dz > studyTableRange*studyTableRange {
			g.TargetX, g.TargetZ, g.MoveSpeed, g.State = table[0], table[1]+1.5, 2.4, 1
			return
		}
		g.MoveSpeed = 0
		g.CurrentActivity = world.ActivityStudying
		g.Life.StudyProgress += dt
	})
	if announce {
		s.BroadcastNPCSay(n.ID, fmt.Sprintf("O(a) %s se foi... vou estudar os projetos da oficina e manter o ofício vivo.", world.Professions[a.Master]))
	}
	if graduate {
		n.Graduate(a.Master, a.Title, table, tableZone)
		s.BroadcastNPCSay(0, fmt.Sprintf("🎓 %s concluiu o aprendizado e reabriu a oficina como %s (Nível 1)!", a.Name, a.Title))
	}
}

// trainApprentice: o jogador acelera a formação com um Pergaminho de Blueprint ou pagando o treinamento.
func (s *Server) trainApprentice(p *world.Player, npc *world.NPC) {
	a, ok := apprenticeOf(npc.ID)
	studying := false
	npc.WithLife(func(n *world.NPC) { studying = n.Life.StudyingFor != 0 && n.Profession == 0 })
	if !ok || !studying {
		s.sendPlayerNPCSay(p, npc.ID, "Ainda não há uma oficina sem mestre para eu assumir.")
		return
	}
	how := ""
	if p.GetItemCount(protocol.ItemBlueprintScroll) > 0 {
		p.RemoveItem(protocol.ItemBlueprintScroll, 1)
		how = "com o Pergaminho de Blueprint"
	} else {
		p.Mu.Lock()
		if p.Gold >= world.ApprenticeTrainingFee {
			p.Gold -= world.ApprenticeTrainingFee
			how = fmt.Sprintf("com %d Sollares de treinamento", world.ApprenticeTrainingFee)
		}
		p.Mu.Unlock()
	}
	if how == "" {
		s.sendPlayerNPCSay(p, npc.ID, fmt.Sprintf("Preciso de um Pergaminho de Blueprint ou de %d Sollares para pagar um mestre de fora.", world.ApprenticeTrainingFee))
		return
	}
	npc.WithLife(func(n *world.NPC) { n.Life.StudyProgress = world.StudySecondsToGraduate })
	s.sendInventorySync(p)
	s.sendPlayerNPCSay(p, npc.ID, fmt.Sprintf("Obrigado! %s, termino meus estudos agora mesmo.", how))
	_ = a
}

// tickGraduateRoutine: o novo mestre trabalha na oficina de dia e fecha a loja à noite.
func (s *Server) tickGraduateRoutine(n *world.NPC, hour int) {
	n.WithLife(func(g *world.NPC) {
		if g.Profession == 0 || g.Profession == g.ID || g.Life.Following != 0 || g.Life.Aggressor != 0 || len(g.Life.Plan) > 0 {
			return
		}
		day := hour >= 6 && hour < 18
		g.ShopOpen = day && g.ZoneID == g.Life.HomeZone
		if day && g.ZoneID == g.Life.HomeZone {
			dx, dz := g.Life.Home[0]-g.PosX, g.Life.Home[1]-g.PosZ
			if dx*dx+dz*dz > 4 {
				g.TargetX, g.TargetZ, g.MoveSpeed, g.State = g.Life.Home[0], g.Life.Home[1], 2.4, 1
			} else {
				g.State = 2
			}
		}
	})
}

// projectileNPCHit devolve o NPC atingido pelo projétil (raio 1,1 m), se houver.
func (s *Server) projectileNPCHit(p *world.Projectile, zone uint8) *world.NPC {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, npc := range s.npcs {
		if p.HitTargets[npc.ID] || npc.GetZone() != zone || !npc.Targetable() {
			continue
		}
		nx, _, nz := npc.GetPos()
		if (nx-p.PosX)*(nx-p.PosX)+(nz-p.PosZ)*(nz-p.PosZ) <= 1.1*1.1 {
			return npc
		}
	}
	return nil
}
