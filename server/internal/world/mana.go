package world

import (
	"time"

	"lunaria/server/internal/protocol"
)

// Mana: reserva para habilidades mágicas.
//
//	Mana Máxima = (Base da Raça + Por Nível × (Nível − 1) + INT × ManaPerINT) × Tier × Classe
//	Regeneração/s = Regen da Raça + ESP × ManaRegenPerSPI (+50% fora de combate, aplicado no servidor)
//
// INT (Inteligência) aumenta a Mana máxima; ESP (Espírito) acelera a regeneração passiva.

// ManaPerINT é quanto cada ponto de INT soma à Mana máxima.
const ManaPerINT = 6

// ManaRegenPerSPI é quanto cada ponto de ESP soma à regeneração por segundo.
const ManaRegenPerSPI = 0.15

// RaceMana descreve a afinidade arcana de uma raça.
type RaceMana struct {
	Base     uint16  // Mana no nível 1 (antes de INT)
	PerLevel uint16  // Mana extra a cada nível
	Regen    float32 // Mana por segundo (antes de ESP)
}

// raceMana define a Mana de cada uma das 47 raças: magos natos (Faelith, Manamante, Noctari) têm muito,
// guerreiros de sangue e pedra (Kharad, Orkhan, Testudar) têm pouco.
var raceMana = map[uint8]RaceMana{
	protocol.RaceValerian: {80, 6, 1.6}, protocol.RaceNoctari: {130, 9, 2.8}, protocol.RaceKharad: {55, 4, 1.0},
	protocol.RaceVarkai: {50, 4, 1.1}, protocol.RaceDhampir: {100, 7, 2.0}, protocol.RacePrimordialLycanthrope: {45, 3, 0.9},
	protocol.RaceRevenant: {95, 7, 1.8}, protocol.RaceCelestine: {140, 10, 3.0}, protocol.RaceAbyssal: {135, 9, 2.8},
	protocol.RaceRunicAutomaton: {90, 7, 1.4}, protocol.RaceHighValerian: {110, 8, 2.0}, protocol.RaceAetherWalker: {130, 9, 2.6},
	protocol.RaceLunarArchon: {170, 12, 3.4}, protocol.RaceUmbralSpecter: {150, 10, 3.0}, protocol.RaceRunicGuardian: {95, 7, 1.6},
	protocol.RaceObsidianTitan: {70, 5, 1.2}, protocol.RaceDraconicSovereign: {90, 6, 1.6}, protocol.RaceFrenzyBeast: {50, 3, 0.9},
	protocol.RaceSylvari: {140, 10, 3.2}, protocol.RaceMyconid: {130, 9, 3.0}, protocol.RaceArachne: {110, 8, 2.2},
	protocol.RaceAshDragonborn: {90, 6, 1.6}, protocol.RaceChimera: {85, 6, 1.6}, protocol.RaceBoreal: {125, 9, 2.6},
	protocol.RaceThalassian: {135, 9, 3.0}, protocol.RaceCambion: {110, 8, 2.2}, protocol.RaceNephilim: {150, 11, 3.2},
	protocol.RaceTimeWanderer: {160, 11, 3.4}, protocol.RaceHalfCelestial: {150, 10, 3.2}, protocol.RacePyromancer: {145, 10, 2.8},
	protocol.RaceFrostGiant: {60, 4, 1.0}, protocol.RaceDragonEarth: {70, 5, 1.2}, protocol.RaceDragonWater: {120, 8, 2.6},
	protocol.RaceDragonLightning: {115, 8, 2.4}, protocol.RaceDragonMystic: {165, 12, 3.4}, protocol.RaceOrc: {45, 3, 0.8},
	protocol.RaceDwarf: {65, 5, 1.2}, protocol.RaceElf: {125, 9, 2.6}, protocol.RaceSolarElf: {135, 10, 2.8},
	protocol.RaceLunarElf: {140, 10, 3.0}, protocol.RaceFairy: {190, 13, 3.8}, protocol.RaceGoblin: {85, 6, 1.6},
	protocol.RaceScorpionDemi: {75, 5, 1.4}, protocol.RaceTurtleDemi: {80, 5, 1.6}, protocol.RaceHalfDemon: {140, 10, 2.8},
	protocol.RaceWolfDemi: {55, 4, 1.0}, protocol.RaceManamancer: {220, 15, 4.5},
}

// GetRaceMana retorna a afinidade arcana da raça (valores médios para raças desconhecidas).
func GetRaceMana(raceID uint8) RaceMana {
	if m, ok := raceMana[raceID]; ok {
		return m
	}
	return RaceMana{80, 6, 1.6}
}

// Perfil de recurso das classes: o que as habilidades Q/R/F consomem.
const (
	ResourceStamina = iota // físicas: só Stamina
	ResourceMana           // mágicas: só Mana
	ResourceHybrid         // híbridas: metade de cada
)

// ClassResource retorna o perfil de recurso da classe.
func ClassResource(classID uint8) int {
	switch classID {
	case protocol.ClassMage, protocol.ClassAlchemist, protocol.ClassWarTailor, protocol.ClassRunicSpellblade,
		protocol.ClassPlagueDoctor, protocol.ClassCrimsonWebSovereign, protocol.ClassWorldTreeArchfairy,
		protocol.ClassCrimsonAristocrat, protocol.ClassAshInquisitor, protocol.ClassBoneNecromancer,
		protocol.ClassHomunculusCreator, protocol.ClassStormHerald, protocol.ClassMoonlightSculptor,
		protocol.ClassBlackSunEmperor:
		return ResourceMana
	case protocol.ClassSculptor, protocol.ClassTamer, protocol.ClassVampireHunter, protocol.ClassAegisValkyrie,
		protocol.ClassMountainRunemancer, protocol.ClassEclipseReaper, protocol.ClassAstralDancer,
		protocol.ClassPagmaDescendant, protocol.ClassDragonMonarch, protocol.ClassRunicArtificer,
		protocol.ClassPrimordialTamer, protocol.ClassRiftKnight:
		return ResourceHybrid
	}
	return ResourceStamina
}

// classManaMult: classes mágicas têm mais Mana; físicas, menos.
func classManaMult(classID uint8) float32 {
	switch ClassResource(classID) {
	case ResourceMana:
		return 1.40
	case ResourceHybrid:
		return 1.15
	}
	if classID == protocol.ClassNone {
		return 1.0
	}
	return 0.85
}

// CalculateMaxMana calcula a Mana máxima.
func CalculateMaxMana(raceID, classID, classTier, level, intStat uint8) uint16 {
	rm := GetRaceMana(raceID)
	lvl := uint16(1)
	if level > 1 {
		lvl = uint16(level)
	}
	base := float32(rm.Base + rm.PerLevel*(lvl-1) + uint16(intStat)*ManaPerINT)
	return uint16(base * tierStatMult(classTier) * classManaMult(classID))
}

// ManaRegenPerSecond calcula a regeneração passiva de Mana por segundo.
func ManaRegenPerSecond(raceID, spi uint8) float32 {
	return GetRaceMana(raceID).Regen + float32(spi)*ManaRegenPerSPI
}

// SkillCost retorna quanto uma ação custa de Stamina e de Mana para a classe.
// Base: Q 15, R 20, F 25. Mágicas pagam 1.2x em Mana; híbridas dividem (60% Stamina, 60% Mana).
func SkillCost(classID, actionType uint8) (stamina, mana float32) {
	var base float32
	switch actionType {
	case protocol.ActionSkillQ:
		base = 15
	case protocol.ActionSkillR:
		base = 20
	case protocol.ActionSkillF:
		base = 25
	default:
		return 0, 0
	}
	switch ClassResource(classID) {
	case ResourceMana:
		return 0, base * 1.2
	case ResourceHybrid:
		return base * 0.6, base * 0.6
	}
	return base, 0
}

// tierStatMult é o multiplicador de Tier usado em Vida, Stamina e Mana.
func tierStatMult(tier uint8) float32 {
	switch tier {
	case protocol.TierUncommon:
		return 1.20
	case protocol.TierRare:
		return 1.45
	case protocol.TierEpic:
		return 1.75
	case protocol.TierUnique:
		return 2.15
	case protocol.TierLegendary:
		return 2.60
	}
	return 1.0
}

// RegenerateMana recupera Mana a cada tick (dt em segundos); fora de combate a regeneração é 50% maior.
func (p *Player) RegenerateMana(dt float32, outOfCombat bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	_, _, _, _, _, totalSPI, _, _ := p.getAttributesLocked() // ESP com equipamentos
	rate := ManaRegenPerSecond(p.RaceID, totalSPI)
	if outOfCombat {
		rate *= 1.5
	}
	p.Mana += rate * dt
	if p.Mana > float32(p.MaxMana) {
		p.Mana = float32(p.MaxMana)
	}
}

// PaySkillCost cobra Stamina e Mana de uma habilidade. Se faltar Mana ao Manamante (Sangue Azul),
// o restante sai da Vida, desde que sobre pelo menos 1 de Vida. Retorna false sem cobrar nada se não puder pagar.
func (p *Player) PaySkillCost(stamina, mana float32) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.Stamina < stamina {
		return false
	}
	hpCost := float32(0)
	if p.Mana < mana {
		if p.RaceID != protocol.RaceManamancer {
			return false
		}
		hpCost = mana - p.Mana
		if float32(p.HP) <= hpCost {
			return false
		}
	}
	p.Stamina -= stamina
	if hpCost > 0 {
		p.Mana = 0
		p.HP -= uint16(hpCost)
	} else {
		p.Mana -= mana
	}
	return true
}

// MarkInCombat registra que o jogador acabou de agir ou apanhar (pausa o bônus de regeneração).
func (p *Player) MarkInCombat() {
	p.Mu.Lock()
	p.LastCombatAt = time.Now()
	p.Mu.Unlock()
}

// OutOfCombat informa se o jogador está há mais de 5s sem combate.
func (p *Player) OutOfCombat() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Since(p.LastCombatAt) > 5*time.Second
}

// ManaChanged informa se a Mana inteira mudou desde o último aviso ao cliente.
func (p *Player) ManaChanged() bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	cur := uint16(p.Mana)
	if cur == p.lastSentMana {
		return false
	}
	p.lastSentMana = cur
	return true
}

// RestoreMana devolve Mana (poções, habilidades), sem passar do máximo.
func (p *Player) RestoreMana(amount float32) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.Mana += amount
	if p.Mana > float32(p.MaxMana) {
		p.Mana = float32(p.MaxMana)
	}
}
