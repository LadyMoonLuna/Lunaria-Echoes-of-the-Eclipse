package network

import (
	"fmt"
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

// classSkillShape retorna a área das habilidades de dano das Classes Básicas (1 a 12) e das Variantes Secretas (13 a 18).
// Habilidades que são projéteis (Sentinela dos Ventos, Orbe de Magma do Arcanista, frascos do Transmutador) ou só
// buffs não têm área aqui e seguem o fluxo antigo.
func classSkillShape(classID, actionType uint8) (basicSkillShape, bool) {
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

	// --- Classes Únicas Exclusivas de Raça (19 a 26) ---
	case protocol.ClassVorpalExecutioner:
		switch {
		case q: // Ferrão Duplo Vorpal: um alvo + 3 doses de toxina
			return basicSkillShape{radius: 3.8, minDot: 0.5, maxTargets: 1}, true
		case r: // Ecdise Ácida: a casca deixada para trás explode
			return basicSkillShape{radius: 4.0, minDot: -1}, true
		case f: // Execução da Terceira Dose Letal
			return basicSkillShape{radius: 4.0, minDot: -1}, true
		}
	case protocol.ClassCrimsonWebSovereign:
		switch {
		case q: // Fios de Seda Cortante: cone de 8m
			return basicSkillShape{radius: 8.0, minDot: 0.5}, true
		case r: // Casulo de Drenagem
			return basicSkillShape{radius: 4.0, minDot: -1}, true
		case f: // Domínio da Viúva Negra: 10m
			return basicSkillShape{radius: 10.0, minDot: -1}, true
		}
	case protocol.ClassBloodPackKing:
		switch {
		case q: // Frenesi de Mordidas Sincronizadas
			return basicSkillShape{radius: 4.0, minDot: 0.3}, true
		case f: // Caçada Selvagem da Alcateia: 7m à frente
			return basicSkillShape{radius: 7.0, minDot: -1, offset: 3.0}, true
		}
	case protocol.ClassMountainRunemancer:
		switch {
		case q: // Martelo Trovão da Montanha
			return basicSkillShape{radius: 4.5, minDot: 0.3}, true
		case f: // Forja do Ragnarok: magma em 6m
			return basicSkillShape{radius: 6.0, minDot: -1}, true
		}
	case protocol.ClassWorldBastion:
		switch {
		case q: // Giro de Carapaça Demolidora
			return basicSkillShape{radius: 4.0, minDot: -1}, true
		case f: // Peso do Oceano Profundo
			return basicSkillShape{radius: 7.0, minDot: -1}, true
		}
	case protocol.ClassWorldTreeArchfairy:
		switch {
		case q: // Rajada de Pó Estelar
			return basicSkillShape{radius: 8.0, minDot: 0.6}, true
		case r: // Anel de Cogumelos Mágicos: polimorfia em 5m
			return basicSkillShape{radius: 5.0, minDot: -1}, true
		case f: // Despertar de Titânia
			return basicSkillShape{radius: 7.0, minDot: -1}, true
		}
	case protocol.ClassCrimsonAristocrat:
		switch {
		case q: // Lança de Sangue Congelado: um alvo a até 10m
			return basicSkillShape{radius: 10.0, minDot: 0.9, maxTargets: 1}, true
		case r: // Enxame da Noite: drena em volta
			return basicSkillShape{radius: 4.0, minDot: -1, centerOnSelf: true}, true
		case f: // Trono de Sangue: 9m
			return basicSkillShape{radius: 9.0, minDot: -1}, true
		}
	case protocol.ClassScrapBaron:
		switch {
		case q: // Canhão de Moedas & Metralha
			return basicSkillShape{radius: 7.0, minDot: 0.6}, true
		case f: // Autodestruição Nuclear Gnarlin
			return basicSkillShape{radius: 8.0, minDot: -1}, true
		}

	// --- Classes Lendárias (31 a 34) ---
	case protocol.ClassPagmaDescendant:
		switch {
		case q: // Dança da Espada: Onda
			return basicSkillShape{radius: 9.0, minDot: 0.4}, true
		case r: // Transcendência de 6 Espadas: as espadas varrem 5m
			return basicSkillShape{radius: 5.0, minDot: -1}, true
		case f: // Queda do Deus da Forja
			return basicSkillShape{radius: 8.0, minDot: -1}, true
		}
	case protocol.ClassMoonlightSculptor:
		switch {
		case q: // Lâmina da Lua Radiante
			return basicSkillShape{radius: 6.0, minDot: 0.5}, true
		case f: // Legião Imperial do Luar
			return basicSkillShape{radius: 9.0, minDot: -1}, true
		}
	case protocol.ClassDragonMonarch:
		switch {
		case q: // Garra do Monarca
			return basicSkillShape{radius: 5.0, minDot: 0.3}, true
		case r: // Rugido de Subjugação: 8m
			return basicSkillShape{radius: 8.0, minDot: -1}, true
		case f: // Cataclismo do Rei Dragão: 10m à frente
			return basicSkillShape{radius: 10.0, minDot: -1, offset: 4.0}, true
		}
	case protocol.ClassBlackSunEmperor:
		switch {
		case q: // Corte do Horizonte de Eventos
			return basicSkillShape{radius: 10.0, minDot: 0.7}, true
		case f: // Apocalipse do Sol Negro: 12m
			return basicSkillShape{radius: 12.0, minDot: -1}, true
		}

	// --- Classes Secretas Variantes (13 a 18) ---
	case protocol.ClassRunicSpellblade:
		switch {
		case q: // Corte Flamígero/Glacial
			return basicSkillShape{radius: 4.0, minDot: 0.3}, true
		case f: // Cometa da Espada Arcana: 5.5m à frente
			return basicSkillShape{radius: 5.5, minDot: -1, offset: 3.0}, true
		}
	case protocol.ClassVampireHunter:
		switch {
		case r: // Corrente de Exorcismo: prende em 6m
			return basicSkillShape{radius: 6.0, minDot: -1}, true
		case f: // Julgamento da Cruz Solar: 6m
			return basicSkillShape{radius: 6.0, minDot: -1}, true
		}
	case protocol.ClassAegisValkyrie:
		switch {
		case q: // Estocada do Trovão: lança em linha de 6m
			return basicSkillShape{radius: 6.0, minDot: 0.85}, true
		case r: // Salto da Valquíria: impacto na aterrissagem
			return basicSkillShape{radius: 3.5, minDot: -1, centerOnSelf: true}, true
		case f: // Chuva de Lanças Douradas: 6m à frente
			return basicSkillShape{radius: 6.0, minDot: -1, offset: 3.5}, true
		}
	case protocol.ClassShadowMonk:
		switch {
		case q: // Palma das Sombras
			return basicSkillShape{radius: 3.5, minDot: 0.3}, true
		case r: // Passo Fantasma: golpe ao reaparecer nas costas do alvo
			return basicSkillShape{radius: 2.2, minDot: -1, maxTargets: 1, centerOnSelf: true}, true
		case f: // Toque da Morte de Cinco Passos: um alvo
			return basicSkillShape{radius: 3.8, minDot: 0.5, maxTargets: 1}, true
		}
	case protocol.ClassCursedSmith:
		switch {
		case q: // Martelo Hemorrágico
			return basicSkillShape{radius: 4.0, minDot: 0.3}, true
		case f: // Despertar da Espada Demoníaca: 5.5m
			return basicSkillShape{radius: 5.5, minDot: -1}, true
		}
	case protocol.ClassPlagueDoctor:
		switch {
		case q: // Bisturi Cirúrgico: um alvo
			return basicSkillShape{radius: 3.8, minDot: 0.5, maxTargets: 1}, true
		case f: // Nuvem da Peste Negra: 6m
			return basicSkillShape{radius: 6.0, minDot: -1}, true
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

		dmg = variantDamageAgainst(classID, mob, dmg)
		dmg = transcendentDamageAgainst(classID, actionType, mob, dmg)

		finalDamage, _, newHP, dead := mob.TakeDamage(dmg, player.ID)
		s.BroadcastCombatEvent(player.ID, mob.ID, actionType, finalDamage, isCrit, newHP, mob.MaxHP)
		s.applyVariantOnHitPassives(player, classID, mob, finalDamage, dead)
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
	case protocol.ClassRunicSpellblade:
		if actionType == protocol.ActionSkillQ { // Corte Glacial: lentidão
			mob.ApplySlow(2*time.Second, 0.30)
		}
	case protocol.ClassVampireHunter:
		if actionType == protocol.ActionSkillR { // Corrente de Exorcismo: prende o alvo
			mob.ApplyStun(2500 * time.Millisecond)
		}
	case protocol.ClassShadowMonk:
		if actionType == protocol.ActionSkillQ { // Palma das Sombras: atordoa
			mob.ApplyStun(time.Second)
		} else if actionType == protocol.ActionSkillF { // Toque da Morte: explode depois de cinco passos (5s)
			s.applyDamageOverTimeDelayed(attackerID, mob, dealt, 5*time.Second)
		}
	case protocol.ClassCursedSmith:
		if actionType == protocol.ActionSkillQ { // Martelo Hemorrágico: sangramento
			s.applyDamageOverTime(attackerID, mob, tick(0.10), 3)
		}
	case protocol.ClassPlagueDoctor:
		if actionType == protocol.ActionSkillQ { // Bisturi Cirúrgico: sangramento
			s.applyDamageOverTime(attackerID, mob, tick(0.10), 3)
		} else if actionType == protocol.ActionSkillF { // Nuvem da Peste Negra: peste
			s.applyDamageOverTime(attackerID, mob, tick(0.08), 5)
		}
	case protocol.ClassVorpalExecutioner:
		if actionType == protocol.ActionSkillQ { // Ferrão Duplo Vorpal: 3 doses de toxina
			mob.MarkPoisoned(6 * time.Second)
			s.applyDamageOverTime(attackerID, mob, tick(0.10), 3)
		}
	case protocol.ClassCrimsonWebSovereign:
		if actionType == protocol.ActionSkillQ {
			mob.ApplySlow(2*time.Second, 0.30)
		} else if actionType == protocol.ActionSkillF { // Domínio da Viúva Negra: teias venenosas
			mob.ApplySlow(3*time.Second, 0.50)
			mob.MarkPoisoned(5 * time.Second)
			s.applyDamageOverTime(attackerID, mob, tick(0.08), 5)
		}
	case protocol.ClassBloodPackKing:
		if actionType == protocol.ActionSkillQ { // Frenesi de Mordidas: sangramento
			s.applyDamageOverTime(attackerID, mob, tick(0.10), 3)
		}
	case protocol.ClassMountainRunemancer:
		if actionType == protocol.ActionSkillQ {
			mob.ApplyStun(time.Second)
		} else if actionType == protocol.ActionSkillF { // Forja do Ragnarok: magma
			s.applyDamageOverTime(attackerID, mob, tick(0.08), 4)
		}
	case protocol.ClassWorldTreeArchfairy:
		if actionType == protocol.ActionSkillR { // Anel de Cogumelos: polimorfia (3s)
			mob.ApplyPolymorph(3 * time.Second)
		}
	case protocol.ClassCrimsonAristocrat:
		if actionType == protocol.ActionSkillQ { // Lança de Sangue Congelado
			mob.ApplySlow(3*time.Second, 0.50)
		}
	case protocol.ClassDragonMonarch:
		if actionType == protocol.ActionSkillR { // Rugido de Subjugação
			mob.ApplyStun(3 * time.Second)
		} else if actionType == protocol.ActionSkillF { // Cataclismo do Rei Dragão: chamas
			s.applyDamageOverTime(attackerID, mob, tick(0.10), 5)
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

// applyAcidPool aplica a Bomba de Ácido Corrosivo do Transmutador: derrete 35% da defesa e desacelera.
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

// shadowStepTarget procura o monstro mais próximo à frente (até 8m) para o Passo das Sombras do Lâmina Silente.
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

// applyPathDamage aplica o multiplicador de dano do Caminho Evolutivo do atacante.
func applyPathDamage(damage uint16, attacker *world.Player) uint16 {
	if attacker == nil {
		return damage
	}
	if atk, _, _ := attacker.EquipBonuses(); atk > 0 {
		damage += atk // ATK das armas equipadas
	}
	m := attacker.PathDamageMult() * attacker.ConsumeAmbushMult() // Caminho Evolutivo e Emboscada
	if m != 1.0 {
		return uint16(float32(damage) * m)
	}
	return damage
}

// isDarkCreature informa se o monstro é uma criatura sombria (alvo do Exterminador Noturno).
func isDarkCreature(mob *world.Mob) bool {
	switch mob.MobType {
	case protocol.MobTypeEclipseAcolyte, protocol.MobTypeLycanthropeAlpha, protocol.MobTypeDarkCultist,
		protocol.MobTypeStoneGargoyle, protocol.MobTypeMalakorHeraldEclipse, protocol.MobTypeVesperianBloodGuard,
		protocol.MobTypeLordVesperianVampire:
		return true
	}
	return false
}

// variantDamageAgainst aplica bônus de dano das Variantes que dependem do alvo.
func variantDamageAgainst(classID uint8, mob *world.Mob, damage uint16) uint16 {
	// Inquisidor de Prata (Exterminador Noturno): +40% de dano em criaturas sombrias
	if classID == protocol.ClassVampireHunter && isDarkCreature(mob) {
		return uint16(float32(damage) * 1.40)
	}
	return damage
}

// applyVariantOnHitPassives aplica as passivas das Variantes que reagem a cada acerto.
func (s *Server) applyVariantOnHitPassives(attacker *world.Player, classID uint8, mob *world.Mob, dealt uint16, dead bool) {
	switch classID {
	case protocol.ClassRunicSpellblade: // Lâmina Elemental: cada golpe gela o alvo
		if !dead {
			mob.ApplySlow(1500*time.Millisecond, 0.20)
		}
	case protocol.ClassCursedSmith: // Têmpera de Sangue: 25% de roubo de vida
		if heal := uint16(float32(dealt) * 0.25); heal > 0 {
			attacker.Heal(heal)
		}
	case protocol.ClassPlagueDoctor: // Cura Tóxica: cada acerto regenera o médico
		attacker.Heal(4)
	case protocol.ClassCrimsonAristocrat: // Sede de sangue: 15% de roubo de vida (30% no Trono de Sangue)
		if heal := uint16(float32(dealt) * 0.15); heal > 0 {
			attacker.Heal(heal)
		}
	}
	// Companheiros que golpeiam junto (Oito Lâminas, Lobos Alfa, Espadas, Estátuas, Dragão e Behemoth)
	if extra := companionStrikePct(classID); extra > 0 && !dead && dealt > 0 {
		bonus := uint16(float32(dealt) * extra)
		if bonus == 0 {
			bonus = 1
		}
		_, _, newHP, killed := mob.TakeDamage(bonus, attacker.ID)
		if killed {
			s.handleMobDeath(mob, attacker.ID)
		} else if newHP > 0 {
			s.BroadcastCombatEvent(attacker.ID, mob.ID, protocol.ActionBasicAttack, bonus, 0, newHP, mob.MaxHP)
		}
	}
}

// companionStrikePct é o dano extra (fração do golpe) dos companheiros que atacam junto.
func companionStrikePct(classID uint8) float32 {
	switch classID {
	case protocol.ClassCrimsonWebSovereign: // Oito Lâminas Dorsais
		return 0.15
	case protocol.ClassBloodPackKing: // 2 Lobos Espirituais Alfa
		return 0.20
	case protocol.ClassPagmaDescendant: // 6 espadas lendárias flutuantes
		return 0.30
	case protocol.ClassMoonlightSculptor: // Estátuas Vivas
		return 0.20
	case protocol.ClassDragonMonarch: // Dragão Ancião + Behemoth
		return 0.25
	}
	return 0
}

// transcendentDamageAgainst aplica regras de dano das Únicas/Lendárias que dependem do alvo.
func transcendentDamageAgainst(classID, actionType uint8, mob *world.Mob, damage uint16) uint16 {
	// Execução da Terceira Dose Letal: 4.0x cheio só em alvos envenenados (os demais levam 60%)
	if classID == protocol.ClassVorpalExecutioner && actionType == protocol.ActionSkillF && !mob.IsPoisoned() {
		return uint16(float32(damage) * 0.60)
	}
	return damage
}

// handleTranscendentPreEffects aplica os efeitos das Únicas/Lendárias que vêm antes (ou no lugar) do dano.
// Retorna true quando a habilidade não causa dano e o processamento da ação termina aqui.
func (s *Server) handleTranscendentPreEffects(player *world.Player, classID, actionType uint8, px, pz, aimX, aimZ float32) bool {
	r := actionType == protocol.ActionSkillR
	f := actionType == protocol.ActionSkillF
	switch classID {
	case protocol.ClassVorpalExecutioner:
		if r { // Ecdise Ácida: invisível por 2s e cura 30% (a casca explode no lugar antigo)
			player.SetDodgeIFrame(2 * time.Second)
			player.SetInvisible(2*time.Second, false)
			player.Heal(player.MaxHP * 30 / 100)
		}
	case protocol.ClassCrimsonWebSovereign:
		if r { // Casulo de Drenagem: +60 HP
			player.Heal(60)
		}
	case protocol.ClassBloodPackKing:
		if r { // Uivo do Eclipse Lupino: buff 12s, +40 HP e lentidão em 6m
			player.SetBuff(12 * time.Second)
			player.Heal(40)
			s.slowMobsAround(player, px, pz, 6.0, 4*time.Second, 0.40)
			return true
		}
	case protocol.ClassMountainRunemancer:
		if r { // Bigorna Ancestral Viva: +25% Atq/Def para todos em 8m e escudo para o runomante
			s.buffNearbyAllies(player, px, pz, 8.0, 10*time.Second)
			player.SetParry(3 * time.Second)
			return true
		}
	case protocol.ClassWorldBastion:
		if r { // Fortaleza Hidráulica: +75 HP e -70% de dano por 4s
			player.Heal(75)
			player.SetParry(4 * time.Second)
			return true
		}
		if f { // Peso do Oceano Profundo: escudo de raid para todos em 8m
			s.parryNearbyAllies(player, px, pz, 8.0, 4*time.Second)
		}
	case protocol.ClassWorldTreeArchfairy:
		if r { // Anel de Cogumelos Mágicos: cura +70 HP de todos em 7m
			s.healNearbyAllies(player.ID, px, pz, 7.0, 70)
		}
		if f { // Despertar de Titânia: cura em área
			s.healNearbyAllies(player.ID, px, pz, 7.0, 50)
		}
	case protocol.ClassCrimsonAristocrat:
		if r { // Enxame da Noite: intangível por 2s
			player.SetDodgeIFrame(2 * time.Second)
		}
	case protocol.ClassScrapBaron:
		if r { // Propulsor Turbo: dash de 8m intangível
			player.Mu.Lock()
			player.PosX += aimX * 8.0
			player.PosZ += aimZ * 8.0
			player.Mu.Unlock()
			player.SetDodgeIFrame(500 * time.Millisecond)
			s.BroadcastPlayerRespawn(player.ID, player.PosX, player.PosY, player.PosZ)
			return true
		}
		if f { // Autodestruição Nuclear: o mecha cobra 10% da Vida do piloto
			player.SpendHPPercent(0.10)
		}
	case protocol.ClassPagmaDescendant:
		if r { // Transcendência de 6 Espadas: buff de 15s e escudo de 3s
			player.SetBuff(15 * time.Second)
			player.SetParry(3 * time.Second)
		}
	case protocol.ClassMoonlightSculptor:
		if r { // Destruição Escultural: +80% de ATK por 20s
			player.SetBuff(20 * time.Second)
			return true
		}
	case protocol.ClassDragonMonarch:
		if r { // Rugido de Subjugação: buff de 10s (o atordoamento sai no acerto)
			player.SetBuff(10 * time.Second)
		}
	case protocol.ClassBlackSunEmperor:
		if r { // Égide da Aurora e Abismo: escudo de 5s, intangível 1s e +80 HP no grupo
			player.SetParry(5 * time.Second)
			player.SetDodgeIFrame(time.Second)
			s.healNearbyAllies(player.ID, px, pz, 8.0, 80)
			return true
		}
	}
	if f && protocol.IsLegendaryClass(classID) {
		s.triggerLegendaryUltimate(player, classID)
	}
	return false
}

// triggerLegendaryUltimate é o efeito global da Ultimate (F) das Classes Lendárias:
// anúncio para o mundo inteiro e, no Soberano do Sol Negro, o céu vira Eclipse por 60s.
func (s *Server) triggerLegendaryUltimate(player *world.Player, classID uint8) {
	names := map[uint8]string{
		protocol.ClassPagmaDescendant:   "QUEDA DO DEUS DA FORJA",
		protocol.ClassMoonlightSculptor: "LEGIÃO IMPERIAL DO LUAR",
		protocol.ClassDragonMonarch:     "CATACLISMO DO REI DRAGÃO",
		protocol.ClassBlackSunEmperor:   "APOCALIPSE DO SOL NEGRO",
	}
	s.BroadcastNPCSay(0, fmt.Sprintf("[PODER LENDÁRIO] O céu treme! O jogador #%d desencadeou %s!", player.ID, names[classID]))
	if classID != protocol.ClassBlackSunEmperor || s.clock == nil {
		return
	}
	previous := s.clock.GetMoonPhase()
	s.clock.SetMoonPhase(world.MoonPhaseEclipse)
	s.BroadcastWorldTime()
	time.AfterFunc(60*time.Second, func() {
		if s.clock.GetMoonPhase() == world.MoonPhaseEclipse {
			s.clock.SetMoonPhase(previous)
			s.BroadcastWorldTime()
		}
	})
}

// slowMobsAround desacelera os monstros em volta do jogador (mesma zona).
func (s *Server) slowMobsAround(player *world.Player, px, pz, radius float32, d time.Duration, factor float32) {
	if s.mobManager == nil {
		return
	}
	zone := player.GetZone()
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive || mob.GetZone() != zone {
			continue
		}
		mob.Mu.RLock()
		mx, mz := mob.PosX, mob.PosZ
		mob.Mu.RUnlock()
		if float32(math.Sqrt(float64((mx-px)*(mx-px)+(mz-pz)*(mz-pz)))) <= radius {
			mob.ApplySlow(d, factor)
		}
	}
}

// buffNearbyAllies concede o buff de combate (+25% Atq/Def) a todos os jogadores em volta.
func (s *Server) buffNearbyAllies(player *world.Player, px, pz, radius float32, d time.Duration) {
	for _, ally := range s.alliesAround(player, px, pz, radius) {
		ally.SetBuff(d)
		s.sendPlayerStats(ally)
	}
}

// parryNearbyAllies concede -70% de dano recebido a todos os jogadores em volta.
func (s *Server) parryNearbyAllies(player *world.Player, px, pz, radius float32, d time.Duration) {
	for _, ally := range s.alliesAround(player, px, pz, radius) {
		ally.SetParry(d)
	}
}

// alliesAround lista os jogadores da mesma zona dentro do raio (inclui o próprio jogador).
func (s *Server) alliesAround(player *world.Player, px, pz, radius float32) []*world.Player {
	s.mu.RLock()
	defer s.mu.RUnlock()
	zone := player.GetZone()
	var out []*world.Player
	for _, ally := range s.players {
		if ally.GetZone() != zone {
			continue
		}
		ally.Mu.RLock()
		ax, az := ally.PosX, ally.PosZ
		ally.Mu.RUnlock()
		if float32(math.Sqrt(float64((ax-px)*(ax-px)+(az-pz)*(az-pz)))) <= radius {
			out = append(out, ally)
		}
	}
	return out
}

// applyDamageOverTimeDelayed causa um único dano extra depois de `delay` (Toque da Morte de Cinco Passos).
func (s *Server) applyDamageOverTimeDelayed(attackerID uint32, mob *world.Mob, damage uint16, delay time.Duration) {
	time.AfterFunc(delay, func() {
		_, _, newHP, dead := mob.TakeDamage(damage, attackerID)
		if dead {
			s.handleMobDeath(mob, attackerID)
			return
		}
		if newHP > 0 {
			s.BroadcastCombatEvent(attackerID, mob.ID, protocol.ActionSkillF, damage, 1, newHP, mob.MaxHP)
		}
	})
}

// handleVariantPreEffects aplica os efeitos das Variantes que vêm antes (ou no lugar) do dano.
// Retorna true quando a habilidade não causa dano e o processamento da ação termina aqui.
func (s *Server) handleVariantPreEffects(player *world.Player, classID, actionType uint8, px, pz, aimX, aimZ float32) bool {
	if actionType != protocol.ActionSkillR {
		return false
	}
	switch classID {
	case protocol.ClassRunicSpellblade: // Escudo de Runas: -70% de dano por 4s
		player.SetParry(4 * time.Second)
		s.BroadcastCombatEvent(player.ID, 0, actionType, 0, 0, 0, 0)
		return true
	case protocol.ClassAegisValkyrie: // Salto da Valquíria: 6m à frente, intangível no ar
		player.Mu.Lock()
		player.PosX += aimX * 6.0
		player.PosZ += aimZ * 6.0
		player.Mu.Unlock()
		player.SetDodgeIFrame(600 * time.Millisecond)
		s.BroadcastPlayerRespawn(player.ID, player.PosX, player.PosY, player.PosZ)
	case protocol.ClassShadowMonk: // Passo Fantasma: reaparece nas costas do alvo, intangível por 1s
		bx, bz, found := s.shadowStepTarget(player, px, pz, aimX, aimZ)
		player.Mu.Lock()
		if found {
			player.PosX, player.PosZ = bx, bz
		} else {
			player.PosX += aimX * 5.0
			player.PosZ += aimZ * 5.0
		}
		player.Mu.Unlock()
		player.SetDodgeIFrame(time.Second)
		s.BroadcastPlayerRespawn(player.ID, player.PosX, player.PosY, player.PosZ)
	case protocol.ClassCursedSmith: // Sacrifício da Bigorna: 15% da Vida por +25% de dano (buff) por 10s
		if player.SpendHPPercent(0.15) {
			player.SetBuff(10 * time.Second)
		}
		s.BroadcastCombatEvent(player.ID, 0, actionType, 0, 0, 0, 0)
		return true
	case protocol.ClassPlagueDoctor: // Incenso Purificador: cura +45 HP de todos em 7m (inclui o médico)
		s.healNearbyAllies(player.ID, px, pz, 7.0, 45)
		s.BroadcastAOETelegraph(player.ID, px, pz, 7.0, 300)
		s.BroadcastCombatEvent(player.ID, 0, actionType, 45, 0, 0, 0)
		return true
	}
	return false
}
