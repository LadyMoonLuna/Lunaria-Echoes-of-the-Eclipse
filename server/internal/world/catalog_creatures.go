package world

import (
	"fmt"
	"math"

	"lunaria/server/internal/protocol"
)

// Partes de criatura: cada bicho tem os SEUS itens ("Coração de Lobo da Bruma", "Pata de Aranha Tecelã").
// Cada parte específica herda as propriedades da família genérica (Coração Pulsante, Couro de Lobo...),
// então receitas, forja, preços e encomendas continuam funcionando pela família (BaseOf).
// IDs estáveis: 1000 + vaga da criatura × 24 + índice da parte.

const (
	CreaturePartFirstID ItemID = 1000
	creaturePartStride         = 24
)

// Famílias novas (só servem de base para as partes específicas; nunca caem sozinhas)
const (
	MatPawFamily     uint16 = 900
	MatHeadFamily    uint16 = 901
	MatTailFamily    uint16 = 902
	MatWingFamily    uint16 = 903
	MatBeakFamily    uint16 = 904
	MatFinFamily     uint16 = 905
	MatPincerFamily  uint16 = 906
	MatAntennaFamily uint16 = 907
)

// Novos tipos de ponto de extração (partes do corpo)
const (
	OrganPaw     uint8 = 12
	OrganHead    uint8 = 13
	OrganTail    uint8 = 14
	OrganWing    uint8 = 15
	OrganBeak    uint8 = 16
	OrganFin     uint8 = 17
	OrganPincer  uint8 = 18
	OrganAntenna uint8 = 19
	OrganBones   uint8 = 20
)

// Índices de parte (vaga dentro da criatura)
const (
	partHide = iota
	partMeat
	partBlood
	partHeart
	partLiver
	partLungs
	partGuts
	partFangs
	partEyes
	partVenom
	partPaw
	partHead
	partTail
	partWing
	partBeak
	partFin
	partPincer
	partAntenna
	partBones
	partSilk
)

type partSpec struct {
	part  int
	base  uint16
	label string
	organ uint8
	qty   uint8
	diff  uint8
}

// Corpos dos monstros antigos (os da fauna vêm do catálogo)
const (
	bodyHumanoid uint8 = 20
	bodyUndead   uint8 = 21
)

var monsterBody = map[uint8]uint8{
	protocol.MobTypeMistWolf: FaunaQuadruped, protocol.MobTypeAlphaWolf: FaunaQuadruped, protocol.MobTypeLycanthropeAlpha: FaunaQuadruped,
	protocol.MobTypeWildBoar: FaunaQuadruped, protocol.MobTypeMistWeaverSpider: FaunaArachnid, protocol.MobTypeArachnaQueen: FaunaArachnid,
	protocol.MobTypeAbyssalScorpion: FaunaArachnid, protocol.MobTypeWildFrostDrake: FaunaReptile,
	protocol.MobTypeOutcastRaider: bodyHumanoid, protocol.MobTypeVigilCrossbowman: bodyHumanoid, protocol.MobTypeEclipseAcolyte: bodyHumanoid,
	protocol.MobTypeIronEnforcer: bodyHumanoid, protocol.MobTypeDarkCultist: bodyHumanoid, protocol.MobTypeInquisitorVex: bodyHumanoid,
	protocol.MobTypeCommanderVaelen: bodyHumanoid, protocol.MobTypeMalakorHeraldEclipse: bodyHumanoid, protocol.MobTypeStitchedChimeraZero: bodyHumanoid,
	protocol.MobTypeYmirFrostPatriarch: bodyHumanoid, protocol.MobTypeVesperianBloodGuard: bodyUndead, protocol.MobTypeLordVesperianVampire: bodyUndead,
	protocol.MobTypeZombie: bodyUndead,
}

// Nomes curtos dos monstros (para "Coração de ...")
var monsterShortName = map[uint8]string{
	protocol.MobTypeMistWolf: "Lobo da Bruma", protocol.MobTypeAlphaWolf: "Lobo Alfa", protocol.MobTypeLycanthropeAlpha: "Licantropo Alfa",
	protocol.MobTypeWildBoar: "Javali Selvagem", protocol.MobTypeMistWeaverSpider: "Aranha Tecelã", protocol.MobTypeArachnaQueen: "Arachna",
	protocol.MobTypeAbyssalScorpion: "Escorpião Abissal", protocol.MobTypeWildFrostDrake: "Draco de Geada",
	protocol.MobTypeOutcastRaider: "Saqueador", protocol.MobTypeVigilCrossbowman: "Besteiro", protocol.MobTypeEclipseAcolyte: "Acólito do Eclipse",
	protocol.MobTypeIronEnforcer: "Executor de Ferro", protocol.MobTypeDarkCultist: "Cultista", protocol.MobTypeInquisitorVex: "Inquisidor Vex",
	protocol.MobTypeCommanderVaelen: "Vaelen", protocol.MobTypeMalakorHeraldEclipse: "Malakor", protocol.MobTypeStitchedChimeraZero: "Quimera",
	protocol.MobTypeYmirFrostPatriarch: "Ymir", protocol.MobTypeVesperianBloodGuard: "Guarda Sanguinário", protocol.MobTypeLordVesperianVampire: "Vesperian",
	protocol.MobTypeZombie: "Zumbi",
}

var monsterHide = map[uint8]uint16{
	protocol.MobTypeMistWolf: MatWolfLeather, protocol.MobTypeAlphaWolf: MatThickFur, protocol.MobTypeLycanthropeAlpha: MatThickFur,
	protocol.MobTypeWildBoar: MatBoarLeather, protocol.MobTypeMistWeaverSpider: MatScorpionChitin, protocol.MobTypeArachnaQueen: MatScorpionChitin,
	protocol.MobTypeAbyssalScorpion: MatScorpionChitin, protocol.MobTypeWildFrostDrake: MatScales,
}

var monsterSilk = map[uint8]uint16{protocol.MobTypeMistWeaverSpider: MatSpiderWeb, protocol.MobTypeArachnaQueen: MatArachnaSilk}

// Chefes e elites: partes uma raridade acima.
var eliteCreatures = map[uint8]bool{
	protocol.MobTypeAlphaWolf: true, protocol.MobTypeLycanthropeAlpha: true, protocol.MobTypeInquisitorVex: true,
	protocol.MobTypeCommanderVaelen: true, protocol.MobTypeMalakorHeraldEclipse: true, protocol.MobTypeArachnaQueen: true,
	protocol.MobTypeStitchedChimeraZero: true, protocol.MobTypeYmirFrostPatriarch: true, protocol.MobTypeLordVesperianVampire: true,
}

var hideLabel = map[uint16]string{MatWolfLeather: "Couro", MatBoarLeather: "Couro", MatThickFur: "Pelagem", MatRawHide: "Pele",
	MatScales: "Escamas", MatFeathers: "Penas", MatScorpionChitin: "Carapaça", MatBones: "Carapaça", MatSpiderWeb: "Fiandeiras"}

// bodyTemplate: as partes que cada tipo de corpo tem.
func bodyTemplate(body uint8, hide, silk uint16) []partSpec {
	h := partSpec{partHide, hide, hideLabel[hide], OrganPelt, 1, 3}
	meat := partSpec{partMeat, MatGameMeat, "Carne", OrganGuts, 1, 2}
	blood := partSpec{partBlood, MatFreshBlood, "Sangue", OrganBlood, 1, 3}
	heart := partSpec{partHeart, MatPulsingHeart, "Coração", OrganHeart, 1, 6}
	liver := partSpec{partLiver, MatFilterLiver, "Fígado", OrganLiver, 1, 5}
	lungs := partSpec{partLungs, MatLungs, "Pulmões", OrganLungs, 1, 6}
	guts := partSpec{partGuts, MatElasticGuts, "Tendões", OrganGuts, 1, 4}
	eyes := partSpec{partEyes, MatFacetedEyes, "Olhos", OrganEyes, 2, 7}
	venom := partSpec{partVenom, MatVorpalSac, "Bolsa de Veneno", OrganVenomSac, 1, 9}
	head := partSpec{partHead, MatHeadFamily, "Cabeça", OrganHead, 1, 6}
	tail := partSpec{partTail, MatTailFamily, "Cauda", OrganTail, 1, 3}
	bones := partSpec{partBones, MatBones, "Ossos", OrganBones, 1, 4}
	switch body {
	case FaunaQuadruped:
		return []partSpec{h, meat, blood, heart, liver, lungs, guts, {partFangs, MatSharpFangs, "Presas", OrganFangOrClaw, 1, 4}, eyes,
			{partPaw, MatPawFamily, "Pata", OrganPaw, 4, 3}, head, tail, bones}
	case FaunaBird:
		return []partSpec{h, meat, blood, heart, eyes, {partWing, MatWingFamily, "Asa", OrganWing, 2, 4},
			{partBeak, MatBeakFamily, "Bico", OrganBeak, 1, 4}, {partPaw, MatPawFamily, "Garras", OrganPaw, 2, 3}, head}
	case FaunaSerpent:
		return []partSpec{h, meat, blood, heart, {partFangs, MatSharpFangs, "Presas", OrganFangOrClaw, 1, 4}, venom, head, tail}
	case FaunaInsect:
		return []partSpec{h, guts, eyes, venom, {partPaw, MatPawFamily, "Pata", OrganPaw, 6, 3},
			{partAntenna, MatAntennaFamily, "Antena", OrganAntenna, 2, 7}, head}
	case FaunaArachnid:
		s := []partSpec{h, guts, eyes, venom, {partPaw, MatPawFamily, "Pata", OrganPaw, 8, 3}, head}
		if silk != 0 {
			s = append(s, partSpec{partSilk, silk, hideLabel[MatSpiderWeb], OrganPelt, 1, 4})
		}
		return s
	case FaunaFish:
		return []partSpec{h, meat, heart, eyes, {partFin, MatFinFamily, "Barbatana", OrganFin, 2, 3}, head, tail}
	case FaunaAmphibian:
		return []partSpec{h, meat, blood, heart, liver, lungs, {partPaw, MatPawFamily, "Pata", OrganPaw, 4, 3}, head, tail}
	case FaunaReptile:
		return []partSpec{h, meat, blood, heart, liver, lungs, {partFangs, MatSharpFangs, "Garras", OrganFangOrClaw, 1, 4},
			{partPaw, MatPawFamily, "Pata", OrganPaw, 4, 3}, head, tail, bones}
	case FaunaCrab:
		return []partSpec{h, meat, eyes, {partPincer, MatPincerFamily, "Pinça", OrganPincer, 2, 4}, {partPaw, MatPawFamily, "Pata", OrganPaw, 6, 3}}
	case bodyHumanoid:
		return []partSpec{blood, heart, liver, lungs, guts, eyes}
	case bodyUndead:
		return []partSpec{blood, heart, eyes, {partFangs, MatSharpFangs, "Presas", OrganFangOrClaw, 1, 5}}
	}
	return nil
}

// Família genérica -> índice de parte (para especializar o saque antigo e a anatomia).
var familyPart = map[uint16]int{
	MatWolfLeather: partHide, MatBoarLeather: partHide, MatThickFur: partHide, MatRawHide: partHide, MatScales: partHide,
	MatFeathers: partHide, MatScorpionChitin: partHide, MatSpiderWeb: partSilk, MatArachnaSilk: partSilk,
	MatGameMeat: partMeat, uint16(protocol.ItemRawWolfMeat): partMeat,
	MatFreshBlood: partBlood, MatWolfBlood: partBlood, MatVampireBlood: partBlood,
	MatPulsingHeart: partHeart, MatFilterLiver: partLiver, MatLungs: partLungs, MatElasticGuts: partGuts,
	MatSharpFangs: partFangs, MatFacetedEyes: partEyes, MatVorpalSac: partVenom, MatBones: partBones,
}

type creatureInfo struct {
	name  string
	body  uint8
	mass  float32
	elite bool
	parts map[int]partSpec
}

var (
	creatures    = map[uint8]*creatureInfo{}
	specificBase = map[ItemID]ItemID{} // parte específica -> família genérica
	partOrgans   = map[ItemID]partSpec{}
)

func creatureSlot(mobType uint8) int {
	if mobType >= FaunaFirstType {
		return int(mobType - FaunaFirstType)
	}
	return 140 + int(mobType)
}

// CreaturePartID: ID estável da parte `part` da criatura.
func CreaturePartID(mobType uint8, part int) ItemID {
	return CreaturePartFirstID + ItemID(creatureSlot(mobType)*creaturePartStride+part)
}

// BaseOf: família genérica do item (ele mesmo se não for uma parte específica).
func BaseOf(id ItemID) ItemID {
	if b, ok := specificBase[id]; ok {
		return b
	}
	return id
}

// SpecializeDrop troca a família genérica pela parte específica da criatura (se ela tiver essa parte).
func SpecializeDrop(mobType uint8, generic ItemID) (ItemID, bool) {
	c := creatures[mobType]
	if c == nil {
		return generic, false
	}
	part, ok := familyPart[uint16(generic)]
	if !ok {
		return generic, false
	}
	if _, has := c.parts[part]; !has {
		return generic, false
	}
	return CreaturePartID(mobType, part), true
}

// specializeOrgans troca o saque genérico pelas partes da criatura e soma as partes do corpo que faltam.
func specializeOrgans(mobType uint8, organs []CorpseOrgan) []CorpseOrgan {
	c := creatures[mobType]
	if c == nil {
		return organs
	}
	have := map[int]bool{}
	for i := range organs {
		if id, ok := SpecializeDrop(mobType, organs[i].ItemReward); ok {
			organs[i].ItemReward = id
			organs[i].Name = MaterialsDB[uint16(id)].Name
			have[familyPart[uint16(BaseOf(id))]] = true
		}
	}
	for _, part := range []int{partPaw, partHead, partTail, partWing, partBeak, partFin, partPincer, partAntenna, partBones} {
		spec, ok := c.parts[part]
		if !ok || have[part] {
			continue
		}
		if part == partBones && c.mass < 5 {
			continue
		}
		id := CreaturePartID(mobType, part)
		qty := spec.qty
		if part == partBones {
			qty = uint8(min(4, 1+int(c.mass/120)))
		}
		organs = append(organs, CorpseOrgan{Index: uint8(len(organs)), Name: MaterialsDB[uint16(id)].Name, OrganType: spec.organ,
			ItemReward: id, Quantity: qty, Difficulty: spec.diff})
	}
	for i := range organs {
		organs[i].Index = uint8(i)
	}
	return organs
}

func registerCreature(mobType uint8, name string, body uint8, mass float32, hide, silk uint16) {
	c := &creatureInfo{name: name, body: body, mass: mass, elite: eliteCreatures[mobType], parts: map[int]partSpec{}}
	size := float32(math.Max(0.25, math.Min(5, math.Cbrt(float64(mass)/30))))
	for _, spec := range bodyTemplate(body, hide, silk) {
		if spec.base == 0 || spec.label == "" {
			continue
		}
		base, ok := MaterialsDB[spec.base]
		if !ok {
			continue
		}
		id := CreaturePartID(mobType, spec.part)
		m := base
		m.ID = uint16(id)
		m.Name = fmt.Sprintf("%s de %s", spec.label, name)
		switch spec.part {
		case partBlood, partEyes, partVenom:
		default:
			m.Weight = float32(math.Round(float64(base.Weight*size)*100) / 100)
			if m.Weight < 0.05 {
				m.Weight = 0.05
			}
		}
		if c.elite && m.Rarity < RarityMythic {
			m.Rarity++
		}
		MaterialsDB[m.ID] = m
		specificBase[id] = ItemID(spec.base)
		partOrgans[id] = spec
		c.parts[spec.part] = spec
	}
	creatures[mobType] = c
}

// CreatureName: nome curto da criatura (fauna ou monstro).
func CreatureName(mobType uint8) string {
	if c := creatures[mobType]; c != nil {
		return c.name
	}
	return ""
}

func init() {
	fam := []MaterialDef{
		{MatPawFamily, "Pata", MatBone, RarityCommon, 30, 0.5, "—", "", 10, 5, 15},
		{MatHeadFamily, "Cabeça", MatBone, RarityUncommon, 40, 2.0, "—", "", 10, 5, 25},
		{MatTailFamily, "Cauda", MatHideThread, RarityCommon, 20, 0.6, "—", "", 10, 5, 15},
		{MatWingFamily, "Asa", MatHideThread, RarityUncommon, 15, 0.4, "—", "", 5, 5, 30},
		{MatBeakFamily, "Bico", MatBone, RarityCommon, 35, 0.1, "—", "", 10, 5, 15},
		{MatFinFamily, "Barbatana", MatHideThread, RarityCommon, 15, 0.2, "—", "", 10, 10, 20},
		{MatPincerFamily, "Pinça", MatBone, RarityUncommon, 50, 0.4, "—", "", 15, 5, 15},
		{MatAntennaFamily, "Antena", MatOrganBlood, RarityUncommon, 5, 0.05, "—", "", 5, 30, 40},
	}
	for _, m := range fam {
		MaterialsDB[m.ID] = m
	}
	for _, d := range FaunaCatalog {
		registerCreature(d.Type, d.Name, d.Body, d.MassKg, d.Hide, 0)
	}
	for t, body := range monsterBody {
		registerCreature(t, monsterShortName[t], body, CorpseMassKg(t), monsterHide[t], monsterSilk[t])
	}
}
