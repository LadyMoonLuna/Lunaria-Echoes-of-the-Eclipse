package network

import (
	"log"
	"math"
	"sort"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// basicSkillShape descreve a área atingida por uma habilidade Q/R/F de uma das 12 Classes Básicas.
type basicSkillShape struct {
	radius       float32 // alcance a partir do centro da habilidade
	minDot       float32 // cone frontal (produto escalar mínimo com a mira); -1 = círculo completo
	offset       float32 // desloca o centro na direção da mira (áreas lançadas à frente do jogador)
	maxTargets   int     // 0 = todos os alvos da área; senão, os N mais próximos
	centerOnSelf bool    // centro na posição ATUAL do jogador (depois de investidas e teleportes)
}

// basicClassSkillShape retorna a área das habilidades de dano das Classes Básicas (IDs 1 a 12).
// Habilidades que são projéteis (Arqueiro, Orbe de Magma do Mago, frascos do Alquimista) ou só
// buffs não têm área aqui e seguem o fluxo antigo.
func basicClassSkillShape(classID, actionType uint8) (basicSkillShape, bool) {
	q := actionType == protocol.ActionSkillQ
	r := actionType == protocol.ActionSkillR
	f := actionType == protocol.ActionSkillF

	switch classID {
	case protocol.ClassWarrior:
		switch {
		case q: // Corte Duplo: arco frontal + sangramento
			return basicSkillShape{radius: 3.8, minDot: 0.2}, true
		case r: // Investida Imparável: impacto ao fim do dash de 6m
			return basicSkillShape{radius: 3.0, minDot: -1, centerOnSelf: true}, true
		case f: // Julgamento da Espada: área sísmica de 4.5m
			return basicSkillShape{radius: 4.5, minDot: -1}, true
		}
	case protocol.ClassMage:
		switch {
		case r: // Prisão Glacial: 5m
			return basicSkillShape{radius: 5.0, minDot: -1}, true
		case f: // Chuva de Meteoros: 6m à frente
			return basicSkillShape{radius: 6.0, minDot: -1, offset: 3.0}, true
		}
	case protocol.ClassAssassin:
		switch {
		case q: // Passo das Sombras: corta o alvo depois do teleporte
			return basicSkillShape{radius: 2.2, minDot: -1, maxTargets: 1, centerOnSelf: true}, true
		case f: // Lótus de Sangue: 8 cortes em 4m
			return basicSkillShape{radius: 4.0, minDot: -1}, true
		}
	case protocol.ClassFighter:
		switch {
		case q: // Gancho Demolidor
			return basicSkillShape{radius: 3.5, minDot: 0.3}, true
		case f: // Meteoro de Um Punho: cratera de 5.5m
			return basicSkillShape{radius: 5.5, minDot: -1, offset: 2.0}, true
		}
	case protocol.ClassShieldBearer:
		switch {
		case q: // Esmagamento de Bastião (o Taunt de 8m é aplicado antes)
			return basicSkillShape{radius: 3.8, minDot: 0.3}, true
		case f: // Cidadela Inabalável
			return basicSkillShape{radius: 7.0, minDot: -1}, true
		}
	case protocol.ClassBlacksmith:
		switch {
		case q: // Golpe da Bigorna Incandescente: racha a armadura
			return basicSkillShape{radius: 4.0, minDot: 0.3}, true
		case f: // Dança do Arsenal Forjado: 5.5m
			return basicSkillShape{radius: 5.5, minDot: -1}, true
		}
	case protocol.ClassSculptor:
		switch {
		case q: // Entalhe em Velocidade: 5 cortes precisos num alvo
			return basicSkillShape{radius: 3.8, minDot: 0.5, maxTargets: 1}, true
		case r: // Estátua Explosiva
			return basicSkillShape{radius: 4.5, minDot: -1}, true
		case f: // Escultura do Luar: 6m
			return basicSkillShape{radius: 6.0, minDot: -1}, true
		}
	case protocol.ClassTamer:
		switch {
		case q: // Estalo do Chicote: alvo a até 9m
			return basicSkillShape{radius: 9.0, minDot: 0.85, maxTargets: 1}, true
		case f: // Debandada das Feras Primordiais: 7m à frente
			return basicSkillShape{radius: 7.0, minDot: -1, offset: 3.5}, true
		}
	case protocol.ClassWarTailor:
		switch {
		case q: // Teia de Fios Retalhadores: cone de 8m
			return basicSkillShape{radius: 8.0, minDot: 0.5}, true
		case r: // Costurar Sombras: 6m (a prisão de 2.5s é aplicada antes)
			return basicSkillShape{radius: 6.0, minDot: -1}, true
		case f: // Gaiola de Fios Carmesins: 6m
			return basicSkillShape{radius: 6.0, minDot: -1}, true
		}
	case protocol.ClassHuntingChef:
		switch {
		case q: // Desossar a Vivo!
			return basicSkillShape{radius: 3.8, minDot: 0.3, maxTargets: 1}, true
		case f: // Trinchar o Behemoth: 5.5m à frente
			return basicSkillShape{radius: 5.5, minDot: -1, offset: 2.5}, true
		}
	}
	return basicSkillShape{}, false
}

// isBossMob informa se o monstro é um Boss ou Executor (alvos das reduções de defesa mais fortes).
func isBossMob(mob *world.Mob) bool {
	switch mob.MobType {
	case protocol.MobTypeIronEnforcer, protocol.MobTypeLycanthropeAlpha, protocol.MobTypeInquisitorVex,
		protocol.MobTypeCommanderVaelen, protocol.MobTypeMalakorHeraldEclipse:
		return true
	}
	return false
}

// applyBasicClassSkill aplica o dano de uma habilidade de Classe Básica em todos os alvos da área
// (bonecos de treino e monstros da zona do jogador) e os efeitos extras de cada classe.
// Retorna quantos alvos foram atingidos.
func (s *Server) applyBasicClassSkill(player *world.Player, classID, actionType uint8, cx, cz, px, pz, aimX, aimZ float32,
	shape basicSkillShape, damage uint16, isCrit uint8) int {

	inShape := func(tx, tz float32) (float32, bool) {
		dist := float32(math.Sqrt(float64((tx-cx)*(tx-cx) + (tz-cz)*(tz-cz))))
		if dist > shape.radius {
			return dist, false
		}
		if shape.minDot <= -1 {
			return dist, true
		}
		fx, fz := tx-px, tz-pz
		fd := float32(math.Sqrt(float64(fx*fx + fz*fz)))
		if fd < 0.01 {
			return dist, true
		}
		return dist, (fx/fd)*aimX+(fz/fd)*aimZ >= shape.minDot
	}

	type hit struct {
		dist  float32
		dummy *world.TrainingDummy
		mob   *world.Mob
	}
	var hits []hit

	s.mu.RLock()
	zone := player.GetZone()
	for _, dummy := range s.dummies {
		if dummy.GetZone() != zone {
			continue
		}
		dx, _, dz := dummy.GetPos()
		if dist, ok := inShape(dx, dz); ok {
			hits = append(hits, hit{dist: dist, dummy: dummy})
		}
	}
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive || mob.GetZone() != zone {
				continue
			}
			mob.Mu.RLock()
			mx, mz := mob.PosX, mob.PosZ
			mob.Mu.RUnlock()
			if dist, ok := inShape(mx, mz); ok {
				hits = append(hits, hit{dist: dist, mob: mob})
			}
		}
	}
	s.mu.RUnlock()

	sort.Slice(hits, func(i, j int) bool { return hits[i].dist < hits[j].dist })
	if shape.maxTargets > 0 && len(hits) > shape.maxTargets {
		hits = hits[:shape.maxTargets]
	}

	for _, h := range hits {
		if h.dummy != nil {
			newHP, _ := h.dummy.TakeDamage(damage)
			_, maxHP := h.dummy.GetHP()
			s.BroadcastCombatEvent(player.ID, h.dummy.ID, actionType, damage, isCrit, newHP, maxHP)
			continue
		}

		mob := h.mob
		dmg := damage
		// Julgamento da Espada: +40% de dano em alvos com menos de 35% de vida
		if classID == protocol.ClassWarrior && actionType == protocol.ActionSkillF && mob.HPFraction() < 0.35 {
			dmg = uint16(float32(dmg) * 1.40)
		}

		finalDamage, _, newHP, dead := mob.TakeDamage(dmg, player.ID)
		s.BroadcastCombatEvent(player.ID, mob.ID, actionType, finalDamage, isCrit, newHP, mob.MaxHP)
		if dead {
			s.handleMobDeath(mob, player.ID)
			continue
		}
		s.applyBasicClassSkillEffects(player.ID, classID, actionType, mob, finalDamage)
	}

	if len(hits) == 0 {
		s.BroadcastCombatEvent(player.ID, 0, actionType, 0, 0, 0, 0)
	}
	return len(hits)
}

// applyBasicClassSkillEffects aplica sangramentos, venenos e quebras de armadura das Classes Básicas.
func (s *Server) applyBasicClassSkillEffects(attackerID uint32, classID, actionType uint8, mob *world.Mob, dealt uint16) {
	tick := func(pct float32) uint16 {
		v := uint16(float32(dealt) * pct)
		if v == 0 {
			v = 1
		}
		return v
	}

	switch classID {
	case protocol.ClassWarrior:
		if actionType == protocol.ActionSkillQ { // Corte Duplo: sangramento
			s.applyDamageOverTime(attackerID, mob, tick(0.10), 3)
		}
	case protocol.ClassAssassin:
		if actionType == protocol.ActionSkillQ { // Passo das Sombras: veneno
			s.applyDamageOverTime(attackerID, mob, tick(0.08), 4)
		} else if actionType == protocol.ActionSkillF { // Lótus de Sangue: hemorragia
			s.applyDamageOverTime(attackerID, mob, tick(0.10), 3)
		}
	case protocol.ClassBlacksmith:
		if actionType == protocol.ActionSkillQ { // Bigorna Incandescente: racha 30% da armadura
			mob.ApplyArmorBreak(6*time.Second, 0.30)
		}
	case protocol.ClassSculptor:
		if actionType == protocol.ActionSkillQ { // Entalhe em Velocidade: reduz a defesa do alvo
			mob.ApplyArmorBreak(5*time.Second, 0.20)
		}
	case protocol.ClassHuntingChef:
		if actionType == protocol.ActionSkillF { // Trinchar o Behemoth: defesa do Boss pela metade
			if isBossMob(mob) {
				mob.ApplyArmorBreak(8*time.Second, 0.50)
			} else {
				mob.ApplyArmorBreak(8*time.Second, 0.25)
			}
		}
	}
}

// applyDamageOverTime causa dano por segundo (sangramento/veneno) durante `ticks` segundos.
func (s *Server) applyDamageOverTime(attackerID uint32, mob *world.Mob, perTick uint16, ticks int) {
	for i := 1; i <= ticks; i++ {
		time.AfterFunc(time.Duration(i)*time.Second, func() {
			_, _, newHP, dead := mob.TakeDamage(perTick, attackerID)
			if dead {
				s.handleMobDeath(mob, attackerID)
				return
			}
			if newHP > 0 {
				s.BroadcastCombatEvent(attackerID, mob.ID, protocol.ActionBasicAttack, perTick, 0, newHP, mob.MaxHP)
			}
		})
	}
}

// applyAcidPool aplica a Bomba de Ácido Corrosivo do Alquimista: derrete 35% da defesa e desacelera.
func (s *Server) applyAcidPool(ownerID uint32, cx, cz, radius float32) {
	if s.mobManager == nil {
		return
	}
	var zone uint8
	s.mu.RLock()
	if owner, ok := s.players[ownerID]; ok {
		zone = owner.GetZone()
	}
	s.mu.RUnlock()

	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive || mob.GetZone() != zone {
			continue
		}
		mob.Mu.RLock()
		mx, mz := mob.PosX, mob.PosZ
		mob.Mu.RUnlock()
		if float32(math.Sqrt(float64((mx-cx)*(mx-cx)+(mz-cz)*(mz-cz)))) <= radius {
			mob.ApplyArmorBreak(6*time.Second, 0.35)
			mob.ApplySlow(3*time.Second, 0.40)
		}
	}
}

// shadowStepTarget procura o monstro mais próximo à frente (até 8m) para o Passo das Sombras do Assassino.
// Retorna a posição logo atrás dele, ou ok=false se não houver alvo.
func (s *Server) shadowStepTarget(player *world.Player, px, pz, aimX, aimZ float32) (float32, float32, bool) {
	if s.mobManager == nil {
		return 0, 0, false
	}
	zone := player.GetZone()
	best := float32(8.0)
	var bx, bz float32
	found := false
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive || mob.GetZone() != zone {
			continue
		}
		mob.Mu.RLock()
		mx, mz := mob.PosX, mob.PosZ
		mob.Mu.RUnlock()
		dx, dz := mx-px, mz-pz
		dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
		if dist < 0.01 || dist > best || (dx/dist)*aimX+(dz/dist)*aimZ < 0.5 {
			continue
		}
		best = dist
		// Para as costas do alvo: 1m além dele, na mesma direção
		bx, bz = mx+dx/dist, mz+dz/dist
		found = true
	}
	if found {
		log.Printf("[PASSO DAS SOMBRAS] Jogador #%d encontrou alvo a %.1fm\n", player.ID, best)
	}
	return bx, bz, found
}
