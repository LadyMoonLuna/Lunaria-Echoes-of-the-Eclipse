package world

import (
	"fmt"

	"lunaria/server/internal/protocol"
)

// TranscendentTier retorna o Tier fixo de uma Classe Única (5) ou Lendária (6).
func TranscendentTier(classID uint8) uint8 {
	if protocol.IsLegendaryClass(classID) {
		return protocol.TierLegendary
	}
	return protocol.TierUnique
}

// transcendBonusStats lista os atributos que recebem o Bônus Fixo de Transcendência
// (índices: 0 FOR, 1 DES, 2 CON, 3 AGI, 4 INT, 5 ESP, 6 PER/MAS, 7 SOR).
// Únicas: atributo principal e secundário (+25 cada). Lendárias: os 4 principais (+50 cada).
var transcendBonusStats = map[uint8][]int{
	protocol.ClassVorpalExecutioner:   {1, 3},
	protocol.ClassCrimsonWebSovereign: {1, 4},
	protocol.ClassBloodPackKing:       {0, 3},
	protocol.ClassMountainRunemancer:  {0, 2},
	protocol.ClassWorldBastion:        {2, 0},
	protocol.ClassWorldTreeArchfairy:  {4, 5},
	protocol.ClassCrimsonAristocrat:   {4, 1},
	protocol.ClassScrapBaron:          {1, 7},
	protocol.ClassEclipseReaper:       {0, 1},
	protocol.ClassAstralDancer:        {1, 3},
	protocol.ClassAshInquisitor:       {5, 0},
	protocol.ClassBoneNecromancer:     {4, 5},
	protocol.ClassRunicArtificer:      {0, 4},
	protocol.ClassHomunculusCreator:   {4, 5},
	protocol.ClassPrimordialTamer:     {0, 2},
	protocol.ClassRiftKnight:          {2, 0},
	protocol.ClassStormHerald:         {4, 3},
	protocol.ClassPagmaDescendant:     {0, 1, 2, 6},
	protocol.ClassMoonlightSculptor:   {1, 3, 4, 6},
	protocol.ClassDragonMonarch:       {0, 2, 5, 6},
	protocol.ClassBlackSunEmperor:     {0, 1, 4, 5},
}

// TranscendenceBonus retorna o Bônus Fixo de Transcendência da classe (+25 nas Únicas, +50 nas Lendárias).
func TranscendenceBonus(classID uint8) [8]uint8 {
	var out [8]uint8
	amount := uint8(25)
	if protocol.IsLegendaryClass(classID) {
		amount = 50
	} else if !protocol.IsUniqueClass(classID) {
		return out
	}
	for _, idx := range transcendBonusStats[classID] {
		out[idx] = amount
	}
	return out
}

// transcendLocked aplica o reset obrigatório das Classes Únicas/Lendárias: nível 1, XP zerada e
// atributos reconstruídos (raça + classe + Bônus de Transcendência, sem pontos distribuídos).
func (p *Player) transcendLocked() {
	p.Level = 1
	p.XP = 0
	p.NextLevelXP = 100
	p.StatPoints = 0
	p.ClassPath = 0
	p.AllocSTR, p.AllocDEX, p.AllocCON, p.AllocAGI = 0, 0, 0, 0
	p.AllocINT, p.AllocSPI, p.AllocMAS, p.AllocLCK = 0, 0, 0, 0
}

// UniqueRequirement descreve o que uma Classe Única Exclusiva de Raça exige.
type UniqueRequirement struct {
	Races    []uint8 // raça obrigatória (qualquer uma da lista)
	RaceName string  // nome mostrado no aviso de "Sangue Incompatível"
	Classes  []uint8 // classes atuais que cumprem o requisito (vazio = só o item serve)
	Item     uint8   // item que cumpre o requisito (0 = nenhum)
	ItemName string
}

// UniqueRequirements lista as 8 Classes Únicas Exclusivas de Raça (19 a 26).
// Com classes e item, basta um dos dois; só com item, o item é obrigatório; só com classes, a classe é obrigatória.
var UniqueRequirements = map[uint8]UniqueRequirement{
	protocol.ClassVorpalExecutioner: {Races: []uint8{protocol.RaceScorpionDemi}, RaceName: "Demi-Humano Escorpião",
		Classes: []uint8{protocol.ClassAssassin, protocol.ClassAlchemist}, Item: protocol.ItemRoyalVenomGland, ItemName: "Glândula Real"},
	protocol.ClassCrimsonWebSovereign: {Races: []uint8{protocol.RaceArachne}, RaceName: "Aracne",
		Classes: []uint8{protocol.ClassWarTailor, protocol.ClassAssassin}, Item: protocol.ItemArachnaEye, ItemName: "Olho de Arachna"},
	protocol.ClassBloodPackKing: {Races: []uint8{protocol.RaceWolfDemi, protocol.RacePrimordialLycanthrope}, RaceName: "Demi-Humano Lobo ou Licantropo",
		Classes: []uint8{protocol.ClassTamer, protocol.ClassFighter}},
	protocol.ClassMountainRunemancer: {Races: []uint8{protocol.RaceDwarf, protocol.RaceKharad}, RaceName: "Anão ou Kharad",
		Classes: []uint8{protocol.ClassBlacksmith}},
	protocol.ClassWorldBastion: {Races: []uint8{protocol.RaceTurtleDemi}, RaceName: "Demi-Humano Tartaruga",
		Classes: []uint8{protocol.ClassShieldBearer}},
	protocol.ClassWorldTreeArchfairy: {Races: []uint8{protocol.RaceFairy}, RaceName: "Fadinha",
		Classes: []uint8{protocol.ClassMage, protocol.ClassAlchemist}},
	protocol.ClassCrimsonAristocrat: {Races: []uint8{protocol.RaceDhampir}, RaceName: "Dhampir / Vampiro",
		Item: protocol.ItemVesperianPureBlood, ItemName: "Sangue Puro de Vesperian"},
	protocol.ClassScrapBaron: {Races: []uint8{protocol.RaceGoblin}, RaceName: "Goblin",
		Item: protocol.ItemMechaBlueprint, ItemName: "Diagrama do Mecha"},
}

// CheckUniqueRaceRequirement valida só a raça exigida por uma Classe Única Exclusiva de Raça.
func (p *Player) CheckUniqueRaceRequirement(classID uint8) (bool, string) {
	req, ok := UniqueRequirements[classID]
	if !ok {
		return true, ""
	}
	p.Mu.RLock()
	race := p.RaceID
	p.Mu.RUnlock()
	for _, r := range req.Races {
		if r == race {
			return true, ""
		}
	}
	return false, fmt.Sprintf("🔒 Sangue Incompatível! Apenas a raça [%s] possui a anatomia para suportar esta Classe Única!", req.RaceName)
}

// CanAwakenUnique valida raça e requisito (classe e/ou item) de uma Classe Única Exclusiva de Raça.
// usedItem é o item que cumpriu o requisito (para ser consumido), ou 0 se foi a classe.
func (p *Player) CanAwakenUnique(classID uint8) (ok bool, reason string, usedItem uint8) {
	if raceOK, why := p.CheckUniqueRaceRequirement(classID); !raceOK {
		return false, why, 0
	}
	req, found := UniqueRequirements[classID]
	if !found {
		return true, "", 0
	}
	p.Mu.RLock()
	current := p.ClassID
	p.Mu.RUnlock()
	hasClass := false
	for _, c := range req.Classes {
		if c == current {
			hasClass = true
			break
		}
	}
	hasItem := req.Item != 0 && p.HasItem(req.Item)
	switch {
	case len(req.Classes) == 0:
		if !hasItem {
			return false, fmt.Sprintf("é preciso possuir o item [%s]", req.ItemName), 0
		}
		return true, "", req.Item
	case req.Item == 0:
		if !hasClass {
			return false, "é preciso ser da classe básica exigida", 0
		}
	default:
		if !hasClass && !hasItem {
			return false, fmt.Sprintf("é preciso ser da classe básica exigida ou possuir o item [%s]", req.ItemName), 0
		}
		if !hasClass {
			return true, "", req.Item
		}
	}
	return true, "", 0
}

// LegendaryForUnique indica qual Classe Lendária a Provação Lendária oferece a cada Classe Única.
var LegendaryForUnique = map[uint8]uint8{
	protocol.ClassMountainRunemancer:  protocol.ClassPagmaDescendant,
	protocol.ClassRunicArtificer:      protocol.ClassPagmaDescendant,
	protocol.ClassScrapBaron:          protocol.ClassPagmaDescendant,
	protocol.ClassCrimsonWebSovereign: protocol.ClassMoonlightSculptor,
	protocol.ClassWorldBastion:        protocol.ClassMoonlightSculptor,
	protocol.ClassHomunculusCreator:   protocol.ClassMoonlightSculptor,
	protocol.ClassRiftKnight:          protocol.ClassMoonlightSculptor,
	protocol.ClassBloodPackKing:       protocol.ClassDragonMonarch,
	protocol.ClassPrimordialTamer:     protocol.ClassDragonMonarch,
	protocol.ClassVorpalExecutioner:   protocol.ClassDragonMonarch,
}

// LegendaryOffer retorna a Lendária destinada à Classe Única (Imperador do Sol Negro por padrão).
func LegendaryOffer(uniqueClass uint8) uint8 {
	if l, ok := LegendaryForUnique[uniqueClass]; ok {
		return l
	}
	return protocol.ClassBlackSunEmperor
}

// uniqueDamageTakenMult é o multiplicador de dano recebido das Classes Únicas defensivas.
func uniqueDamageTakenMult(classID uint8) float32 {
	switch classID {
	case protocol.ClassMountainRunemancer: // Pele de Adamante
		return 0.60
	case protocol.ClassWorldBastion: // Casco Continental (zera fraqueza)
		return 0.70
	case protocol.ClassScrapBaron: // Piloto de Exoesqueleto Mecânico
		return 0.80
	}
	return 1.0
}
