package world

import (
	"math"
	"math/rand"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
)

// CorpseDecayDuration define o tempo que um corpo permanece no chão antes de se decompor (90 segundos).
const CorpseDecayDuration = 90 * time.Second

// Tipos de Órgãos Vitais
const (
	OrganPelt       uint8 = 1 // Pele / Couro
	OrganFangOrClaw uint8 = 2 // Presas / Garras
	OrganGland      uint8 = 3 // Glândula de Veneno (Delicado)
	OrganBlood      uint8 = 4 // Sangue / Fluidos Vitais
	OrganHeartRelic uint8 = 5 // Coração / Relíquia Arcana (Cirúrgico)

	// Anatomia Visceral (+18): extração manual e opcional
	OrganHeart    uint8 = 6  // Coração
	OrganLiver    uint8 = 7  // Fígado
	OrganGuts     uint8 = 8  // Intestinos & Tendões
	OrganLungs    uint8 = 9  // Pulmões
	OrganEyes     uint8 = 10 // Olhos
	OrganVenomSac uint8 = 11 // Bolsa de Veneno (alto risco)
)

// visceralOrgan descreve um órgão da anatomia de uma criatura.
type visceralOrgan struct {
	organType  uint8
	material   uint16
	name       string
	difficulty uint8
}

// mobAnatomy: órgãos viscerais de cada criatura (somados ao saque tradicional do cadáver).
var mobAnatomy = map[uint8][]visceralOrgan{
	protocol.MobTypeMistWolf: {
		{OrganBlood, MatWolfBlood, "Sangue de Lobo", 4}, {OrganPelt, MatWolfLeather, "Couro de Lobo", 3},
		{OrganHeart, MatPulsingHeart, "Coração do Lobo", 7}, {OrganLiver, MatFilterLiver, "Fígado do Lobo", 5},
		{OrganGuts, MatElasticGuts, "Intestinos e Tendões", 5}, {OrganLungs, MatLungs, "Pulmões do Lobo", 6},
		{OrganFangOrClaw, MatSharpFangs, "Presas Afiadas", 4},
	},
	protocol.MobTypeWildBoar: {
		{OrganBlood, MatFreshBlood, "Sangue de Javali", 3}, {OrganPelt, MatBoarLeather, "Couro de Javali", 3},
		{OrganHeart, MatPulsingHeart, "Coração do Javali", 6}, {OrganLiver, MatFilterLiver, "Fígado do Javali", 4},
		{OrganGuts, MatElasticGuts, "Intestinos e Tendões", 4}, {OrganLungs, MatLungs, "Pulmões do Javali", 5},
		{OrganFangOrClaw, MatSharpFangs, "Presas do Javali", 3},
	},
	protocol.MobTypeOutcastRaider: {
		{OrganBlood, MatFreshBlood, "Sangue Fresco", 4}, {OrganPelt, MatRoughThread, "Linhas da Armadura", 3},
		{OrganHeart, MatPulsingHeart, "Coração Humano", 7}, {OrganLiver, MatFilterLiver, "Fígado", 5},
		{OrganGuts, MatElasticGuts, "Tendões", 5}, {OrganLungs, MatLungs, "Pulmões", 6},
	},
	protocol.MobTypeVigilCrossbowman: {
		{OrganBlood, MatFreshBlood, "Sangue Fresco", 4}, {OrganPelt, MatRoughThread, "Linhas da Besta", 3},
		{OrganHeart, MatPulsingHeart, "Coração Humano", 7}, {OrganEyes, MatFacetedEyes, "Olhos de Atirador", 8},
		{OrganGuts, MatElasticGuts, "Tendões", 5},
	},
	protocol.MobTypeEclipseAcolyte: {
		{OrganBlood, MatFreshBlood, "Sangue Profano", 4}, {OrganHeart, MatPulsingHeart, "Coração Corrompido", 7},
		{OrganEyes, MatFacetedEyes, "Olhos do Eclipse", 8},
	},
	protocol.MobTypeIronEnforcer: {
		{OrganBlood, MatFreshBlood, "Sangue Fresco", 4}, {OrganHeart, MatPulsingHeart, "Coração de Ferro", 7},
		{OrganGuts, MatElasticGuts, "Tendões Reforçados", 5},
	},
	protocol.MobTypeAlphaWolf: {
		{OrganBlood, MatWolfBlood, "Sangue do Alfa", 4}, {OrganPelt, MatThickFur, "Pelos Espessos do Alfa", 3},
		{OrganHeart, MatPulsingHeart, "Coração do Alfa", 7}, {OrganLiver, MatFilterLiver, "Fígado do Alfa", 5},
		{OrganGuts, MatElasticGuts, "Intestinos e Tendões", 5}, {OrganLungs, MatLungs, "Pulmões do Alfa", 6},
		{OrganEyes, MatFacetedEyes, "Olhos do Alfa", 8}, {OrganFangOrClaw, MatSharpFangs, "Presas do Alfa", 4},
	},
	protocol.MobTypeLycanthropeAlpha: {
		{OrganBlood, MatWolfBlood, "Sangue Licantropo", 5}, {OrganPelt, MatThickFur, "Pelos Licantropos", 4},
		{OrganHeart, MatPulsingHeart, "Coração Licantropo", 8}, {OrganLiver, MatFilterLiver, "Fígado Licantropo", 6},
		{OrganGuts, MatElasticGuts, "Tendões Licantropos", 6}, {OrganLungs, MatLungs, "Pulmões Licantropos", 7},
		{OrganEyes, MatFacetedEyes, "Olhos Licantropos", 8}, {OrganFangOrClaw, MatSharpFangs, "Presas Licantropas", 5},
	},
	protocol.MobTypeDarkCultist: {
		{OrganBlood, MatFreshBlood, "Sangue Fresco", 4}, {OrganHeart, MatPulsingHeart, "Coração do Cultista", 7},
		{OrganLiver, MatFilterLiver, "Fígado", 5},
	},
	protocol.MobTypeInquisitorVex: {
		{OrganBlood, MatFreshBlood, "Sangue Fresco", 4}, {OrganHeart, MatPulsingHeart, "Coração do Inquisidor", 7},
		{OrganLungs, MatLungs, "Pulmões", 6},
	},
	protocol.MobTypeCommanderVaelen: {
		{OrganBlood, MatFreshBlood, "Sangue Fresco", 4}, {OrganHeart, MatPulsingHeart, "Coração do Traidor", 7},
		{OrganLungs, MatLungs, "Pulmões", 6},
	},
	protocol.MobTypeMalakorHeraldEclipse: {
		{OrganBlood, MatFreshBlood, "Sangue do Arauto", 5}, {OrganHeart, MatPulsingHeart, "Coração do Arauto", 8},
		{OrganEyes, MatFacetedEyes, "Olhos do Arauto", 9},
	},
	protocol.MobTypeMistWeaverSpider: {
		{OrganPelt, MatSpiderWeb, "Teias de Aranha", 3}, {OrganEyes, MatFacetedEyes, "Olhos Multifacetados", 8},
		{OrganGuts, MatElasticGuts, "Fiandeiras e Tendões", 5},
	},
	protocol.MobTypeArachnaQueen: {
		{OrganPelt, MatArachnaSilk, "Seda de Arachna", 6}, {OrganEyes, MatFacetedEyes, "Olhos da Rainha", 9},
		{OrganHeart, MatPulsingHeart, "Coração da Rainha", 8},
	},
	protocol.MobTypeAbyssalScorpion: {
		{OrganPelt, MatScorpionChitin, "Quitina de Escorpião", 6}, {OrganVenomSac, MatVorpalSac, "Bolsa de Veneno Vorpal", 9},
		{OrganGuts, MatElasticGuts, "Tendões do Ferrão", 5},
	},
	protocol.MobTypeStitchedChimeraZero: {
		{OrganBlood, MatFreshBlood, "Sangue Mutante", 4}, {OrganHeart, MatPulsingHeart, "Coração Costurado", 8},
		{OrganLungs, MatLungs, "Pulmões Costurados", 6}, {OrganEyes, MatFacetedEyes, "Olhos Enxertados", 8},
		{OrganGuts, MatElasticGuts, "Tendões Elásticos", 5},
	},
	protocol.MobTypeWildFrostDrake: {
		{OrganBlood, MatFreshBlood, "Sangue Dracônico", 5}, {OrganHeart, MatPulsingHeart, "Coração do Draco", 8},
		{OrganLungs, MatLungs, "Pulmões Gélidos", 7}, {OrganFangOrClaw, MatSharpFangs, "Presas do Draco", 5},
		{OrganEyes, MatFacetedEyes, "Olhos do Draco", 8},
	},
	protocol.MobTypeYmirFrostPatriarch: {
		{OrganBlood, MatFreshBlood, "Sangue de Gigante", 5}, {OrganHeart, MatPulsingHeart, "Coração de Ymir", 9},
		{OrganLungs, MatLungs, "Pulmões de Ymir", 7},
	},
	protocol.MobTypeVesperianBloodGuard: {
		{OrganBlood, MatVampireBlood, "Sangue de Vampiro", 6}, {OrganHeart, MatPulsingHeart, "Coração Morto-Vivo", 8},
	},
	protocol.MobTypeLordVesperianVampire: {
		{OrganBlood, MatVampireBlood, "Sangue do Progenitor Vampiro", 7}, {OrganHeart, MatPulsingHeart, "Coração de Vesperian", 9},
		{OrganEyes, MatFacetedEyes, "Olhos Rubros", 9}, {OrganFangOrClaw, MatSharpFangs, "Presas Vampíricas", 6},
	},
}

// IsBloodOrgan: extrações de fluido que exigem um Frasco Vazio.
func IsBloodOrgan(organType uint8) bool {
	return organType == OrganBlood || organType == OrganGland || organType == OrganVenomSac
}

// appendAnatomy soma os órgãos viscerais da criatura à lista de pontos vitais.
func appendAnatomy(organs []CorpseOrgan, mobType uint8) []CorpseOrgan {
	next := uint8(len(organs))
	for _, o := range organs {
		if o.Index >= next {
			next = o.Index + 1
		}
	}
	have := map[uint8]bool{}
	for _, o := range organs {
		have[o.ItemReward] = true
	}
	for _, v := range mobAnatomy[mobType] {
		if have[uint8(v.material)] {
			continue // o saque tradicional já tem este material
		}
		have[uint8(v.material)] = true
		organs = append(organs, CorpseOrgan{
			Index: next, Name: v.name, OrganType: v.organType,
			ItemReward: uint8(v.material), Quantity: 1, Difficulty: v.difficulty,
		})
		next++
	}
	return organs
}

// Tiers de Qualidade
const (
	QualityPerfect   uint8 = 1 // Perfeito
	QualityCommon    uint8 = 2 // Comum
	QualityDestroyed uint8 = 3 // Destruído / Lixo Orgânico
)

// CorpseOrgan representa um ponto vital passível de extração anatômica.
type CorpseOrgan struct {
	Index       uint8
	Name        string
	OrganType   uint8
	ItemReward  uint8
	Quantity    uint8
	Difficulty  uint8 // 1 a 10
	QualityTier uint8 // 0=Pendente, 1=Perfeito, 2=Comum, 3=Destruído
	Extracted   bool
}

// Corpse representa o corpo físico de uma criatura abatida persistindo no mundo por 120s.
type Corpse struct {
	Mu sync.RWMutex

	CorpseID       uint32
	ZoneID         uint8 // Zona onde o cadáver se encontra (0 a 8)
	MobID          uint32
	MobType        uint8
	MobName        string
	PosX           float32
	PosY           float32
	PosZ           float32
	RotY           float32
	CreatedAt      time.Time
	ExpiresAt      time.Time
	IsLooted       bool
	DifficultySeed uint32
	KillerPlayerID uint32

	// Mundo Vivo: risco de voltar como zumbi
	KilledByZombie bool
	ZombieRemains  bool // restos de zumbi nunca se reerguem
	Purified       bool
	NecroTried     bool
	MobLevel       uint8
	MobMaxHP       uint16

	Organs []CorpseOrgan
}

// Processed: corpo aproveitado (saqueado, autopsiado, purificado ou já tentado por um Necromante) não se ergue.
func (c *Corpse) Processed() bool {
	c.Mu.RLock()
	defer c.Mu.RUnlock()
	if c.IsLooted || c.Purified || c.NecroTried || c.ZombieRemains {
		return true
	}
	for _, o := range c.Organs {
		if o.Extracted {
			return true
		}
	}
	return false
}

// NewCorpse instancia uma nova entidade Corpse gerando sua anatomia e órgãos vitais.
func NewCorpse(corpseID, mobID uint32, mobType uint8, mobName string, x, y, z, rotY float32, killerID uint32, luckBonus float64) *Corpse {
	now := time.Now()
	seed := rand.Uint32()
	if seed == 0 {
		seed = 12345
	}

	c := &Corpse{
		CorpseID:       corpseID,
		ZoneID:         ZoneVillage,
		MobID:          mobID,
		MobType:        mobType,
		MobName:        mobName,
		PosX:           x,
		PosY:           y,
		PosZ:           z,
		RotY:           rotY,
		CreatedAt:      now,
		ExpiresAt:      now.Add(CorpseDecayDuration),
		IsLooted:       false,
		DifficultySeed: seed,
		KillerPlayerID: killerID,
		Organs:         generateCorpseOrgans(mobType, luckBonus),
	}
	return c
}

// generateCorpseOrgans gera a lista de órgãos vitais passíveis de corte na autópsia conforme o tipo de criatura.
func generateCorpseOrgans(mobType uint8, luckBonus float64) []CorpseOrgan {
	var organs []CorpseOrgan

	switch mobType {
	case protocol.MobTypeMistWolf: // Lobo da Bruma
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Pele de Lobo da Bruma", OrganType: OrganPelt,
			ItemReward: protocol.ItemWolfGreyPelt, Quantity: 1, Difficulty: 3,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Presas Lupinas Afiadas", OrganType: OrganFangOrClaw,
			ItemReward: protocol.ItemSharpWolfFang, Quantity: 1, Difficulty: 4,
		})
		organs = append(organs, CorpseOrgan{
			Index: 2, Name: "Sangue de Lobo", OrganType: OrganBlood,
			ItemReward: protocol.ItemFreshWolfBlood, Quantity: 1, Difficulty: 5,
		})
		if rand.Float64() < 0.20+luckBonus {
			organs = append(organs, CorpseOrgan{
				Index: 3, Name: "Garras Bestiais Intactas", OrganType: OrganFangOrClaw,
				ItemReward: protocol.ItemBeastClaw, Quantity: 1, Difficulty: 6,
			})
		}

	case protocol.MobTypeOutcastRaider, protocol.MobTypeVigilCrossbowman: // Saqueador / Besteiro
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Carne Nobre de Caça", OrganType: OrganPelt,
			ItemReward: protocol.ItemCookedNobleMeat, Quantity: 1, Difficulty: 2,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Ferro Bruto", OrganType: OrganFangOrClaw,
			ItemReward: protocol.ItemIronOre, Quantity: 1, Difficulty: 4,
		})
		if rand.Float64() < 0.15+luckBonus {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Anel de Presa Ancestral", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemAncestralFangRing, Quantity: 1, Difficulty: 7,
			})
		}

	case protocol.MobTypeEclipseAcolyte: // Acólito do Eclipse
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Glândula de Veneno Sombrio", OrganType: OrganGland,
			ItemReward: protocol.ItemDarkPoisonGland, Quantity: 1, Difficulty: 6,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 1, Name: "Cálice da Alma Partida", OrganType: OrganBlood,
				ItemReward: protocol.ItemBrokenSoulChalice, Quantity: 1, Difficulty: 7,
			})
		}
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Tomo da Foice do Eclipse", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemEclipseScytheTome, Quantity: 1, Difficulty: 9,
			})
		}
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 3, Name: "Casulo de Seda Prateada", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemSilverSilkCocoon, Quantity: 1, Difficulty: 8,
			})
		}

	case protocol.MobTypeIronEnforcer: // Executor de Ferro
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Placa de Aço Reforçada", OrganType: OrganPelt,
			ItemReward: protocol.ItemHeavySteelPlate, Quantity: 1, Difficulty: 5,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Ferro Puro", OrganType: OrganFangOrClaw,
			ItemReward: protocol.ItemIronOre, Quantity: 2, Difficulty: 4,
		})
		if rand.Float64() < 0.15+luckBonus {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Tomo do Martelo Titânico", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemTitansHammerTome, Quantity: 1, Difficulty: 8,
			})
		}
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 3, Name: "Núcleo de Forja Estelar", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemStarforgeCore, Quantity: 1, Difficulty: 10,
			})
		}

	case protocol.MobTypeAlphaWolf: // Lobo Alfa
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Pele Intacta de Lobo Alfa", OrganType: OrganPelt,
			ItemReward: protocol.ItemAlphaWolfPelt, Quantity: 1, Difficulty: 6,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Sangue Lunar Puro", OrganType: OrganBlood,
			ItemReward: protocol.ItemPureLunarBlood, Quantity: 1, Difficulty: 7,
		})
		organs = append(organs, CorpseOrgan{
			Index: 2, Name: "Anel de Presa Ancestral", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemAncestralFangRing, Quantity: 1, Difficulty: 8,
		})

	case protocol.MobTypeLycanthropeAlpha: // Licantropo Alfa (Boss)
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 0, Name: "Coração do Licantropo Alfa", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemLycanAlphaHeart, Quantity: 1, Difficulty: 10,
			})
		}
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Sangue Lunar Puro Concentrado", OrganType: OrganBlood,
			ItemReward: protocol.ItemPureLunarBlood, Quantity: 2, Difficulty: 8,
		})
		organs = append(organs, CorpseOrgan{
			Index: 2, Name: "Pele Imaculada de Predador Alfa", OrganType: OrganPelt,
			ItemReward: protocol.ItemAlphaWolfPelt, Quantity: 1, Difficulty: 7,
		})

	case protocol.MobTypeDarkCultist: // Cultista Sombrio
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Túnica do Cultista Sombrio", OrganType: OrganPelt,
			ItemReward: protocol.ItemShadowCultistRobe, Quantity: 1, Difficulty: 5,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 1, Name: "Tomo da Foice do Eclipse", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemEclipseScytheTome, Quantity: 1, Difficulty: 8,
			})
		}

	case protocol.MobTypeStoneGargoyle: // Gárgula de Pedra
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Coração Pétreo da Gárgula", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemGargoyleStoneHeart, Quantity: 1, Difficulty: 7,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Placa de Aço Pesada", OrganType: OrganPelt,
			ItemReward: protocol.ItemHeavySteelPlate, Quantity: 1, Difficulty: 6,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Ampulheta Rúnica", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemRunicHourglass, Quantity: 1, Difficulty: 9,
			})
		}

	case protocol.MobTypeInquisitorVex: // Inquisidor Vex
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Foice de Sombras do Inquisidor", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemInquisitorShadowScythe, Quantity: 1, Difficulty: 9,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 1, Name: "Cálice da Alma Partida", OrganType: OrganBlood,
				ItemReward: protocol.ItemBrokenSoulChalice, Quantity: 1, Difficulty: 8,
			})
		}
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Ampulheta Rúnica", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemRunicHourglass, Quantity: 1, Difficulty: 9,
			})
		}

	case protocol.MobTypeCommanderVaelen: // Comandante Vaelen
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Insígnia do Comandante Traidor", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemTraitorCommanderInsignia, Quantity: 1, Difficulty: 9,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Placa de Aço Pesada", OrganType: OrganPelt,
			ItemReward: protocol.ItemHeavySteelPlate, Quantity: 1, Difficulty: 7,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Tomo da Foice do Eclipse", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemEclipseScytheTome, Quantity: 1, Difficulty: 9,
			})
		}

	case protocol.MobTypeMalakorHeraldEclipse: // Malakor, o Arauto do Eclipse
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Olho do Arauto do Eclipse", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemHeraldEclipseEye, Quantity: 1, Difficulty: 10,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Tocha Sagrada do Santuário", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemSacredTorch, Quantity: 1, Difficulty: 9,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Coração do Licantropo Alfa", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemLycanAlphaHeart, Quantity: 1, Difficulty: 10,
			})
		}
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 3, Name: "Núcleo de Forja Estelar", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemStarforgeCore, Quantity: 1, Difficulty: 10,
			})
		}
		organs = append(organs, CorpseOrgan{
			Index: 4, Name: "Foice de Sombras do Inquisidor", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemInquisitorShadowScythe, Quantity: 1, Difficulty: 9,
		})

	case protocol.MobTypeMistWeaverSpider: // 15: Aranha Tecelã da Bruma
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Casulo de Seda Perfeito", OrganType: OrganPelt,
			ItemReward: protocol.ItemPerfectSilkCocoon, Quantity: 1, Difficulty: 6,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Glândula de Veneno", OrganType: OrganFangOrClaw,
			ItemReward: protocol.ItemDarkPoisonGland, Quantity: 1, Difficulty: 5,
		})

	case protocol.MobTypeArachnaQueen: // 16: Arachna, a Rainha Tecelã (Raid Boss)
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Coração da Rainha Aranha", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemSpiderQueenHeart, Quantity: 1, Difficulty: 10,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Manto de Seda Imperial", OrganType: OrganPelt,
			ItemReward: protocol.ItemImperialSilkCloak, Quantity: 1, Difficulty: 9,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Olho Multifacetado de Arachna", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemArachnaEye, Quantity: 1, Difficulty: 10,
			})
		}

	case protocol.MobTypeAcidCorrosiveSlime: // 17: Lodo Ácido Corrosivo
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Ácido Puro Concentrado", OrganType: OrganBlood,
			ItemReward: protocol.ItemPureAcid, Quantity: 1, Difficulty: 5,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Lixo Orgânico Decomposto", OrganType: OrganPelt,
			ItemReward: protocol.ItemOrganicTrash, Quantity: 1, Difficulty: 4,
		})

	case protocol.MobTypeAbyssalScorpion: // 18: Escorpião Abissal Gigante
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Veneno Vorpal Abissal", OrganType: OrganBlood,
			ItemReward: protocol.ItemVorpalPoison, Quantity: 1, Difficulty: 7,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 1, Name: "Ferrão de Escorpião Abissal", OrganType: OrganFangOrClaw,
				ItemReward: protocol.ItemAbyssalScorpionStinger, Quantity: 1, Difficulty: 9,
			})
		}

	case protocol.MobTypeStitchedChimeraZero: // 19: Experimento Nº 0: A Quimera Costurada (Mini-Boss)
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Retalho Quimérico Costurado", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemChimeraFleshPart, Quantity: 1, Difficulty: 9,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Glândula de Veneno Mutante", OrganType: OrganFangOrClaw,
			ItemReward: protocol.ItemDarkPoisonGland, Quantity: 2, Difficulty: 7,
		})
		organs = append(organs, CorpseOrgan{
			Index: 2, Name: "Placa de Aço Deformada", OrganType: OrganPelt,
			ItemReward: protocol.ItemHeavySteelPlate, Quantity: 1, Difficulty: 6,
		})

	case protocol.MobTypeAncientIceGolem: // 20: Golem de Gelo Antigo
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Núcleo de Gelo Antigo", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemAncientIceCore, Quantity: 1, Difficulty: 7,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Placa de Aço Congelada", OrganType: OrganPelt,
			ItemReward: protocol.ItemHeavySteelPlate, Quantity: 1, Difficulty: 6,
		})

	case protocol.MobTypeWildFrostDrake: // 21: Draco de Geada Selvagem
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Escama Dracônica Primordial", OrganType: OrganPelt,
			ItemReward: protocol.ItemPrimordialDragonScale, Quantity: 1, Difficulty: 8,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Carne Dracônica Nobre", OrganType: OrganFangOrClaw,
			ItemReward: protocol.ItemCookedNobleMeat, Quantity: 2, Difficulty: 5,
		})

	case protocol.MobTypeYmirFrostPatriarch: // 22: Ymir, o Patriarca Jotunar (Boss)
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Núcleo de Gelo Ancestral de Ymir", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemAncientIceCore, Quantity: 2, Difficulty: 9,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Placa Glacial Reforçada", OrganType: OrganPelt,
			ItemReward: protocol.ItemHeavySteelPlate, Quantity: 2, Difficulty: 8,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Coração de Geada Eterna", OrganType: OrganHeartRelic,
				ItemReward: protocol.ItemEternalFrostHeart, Quantity: 1, Difficulty: 10,
			})
		}

	case protocol.MobTypeVesperianBloodGuard: // 23: Guarda Sanguinário de Vesperian
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Insígnia do Guarda Carmesim", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemCrimsonGuardInsignia, Quantity: 1, Difficulty: 8,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Sangue Lunar Puro", OrganType: OrganBlood,
			ItemReward: protocol.ItemPureLunarBlood, Quantity: 1, Difficulty: 7,
		})

	case protocol.MobTypeLordVesperianVampire: // 24: Lorde Vesperian, o Progenitor Vampiro (Raid Boss Secreto)
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Anel Carmesim de Vesperian", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemVesperianCrimsonRing, Quantity: 1, Difficulty: 10,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Tomo da Foice do Eclipse", OrganType: OrganHeartRelic,
			ItemReward: protocol.ItemEclipseScytheTome, Quantity: 1, Difficulty: 9,
		})
		if rand.Float64() < 0.001*(1.0+luckBonus) {
			organs = append(organs, CorpseOrgan{
				Index: 2, Name: "Sangue Puro do Progenitor", OrganType: OrganBlood,
				ItemReward: protocol.ItemProgenitorPureBlood, Quantity: 1, Difficulty: 10,
			})
		}

	default:
		organs = append(organs, CorpseOrgan{
			Index: 0, Name: "Carne Crua de Caça", OrganType: OrganPelt,
			ItemReward: protocol.ItemRawWolfMeat, Quantity: 1, Difficulty: 3,
		})
		organs = append(organs, CorpseOrgan{
			Index: 1, Name: "Pele Selvagem", OrganType: OrganPelt,
			ItemReward: protocol.ItemWolfGreyPelt, Quantity: 1, Difficulty: 4,
		})
	}

	// O Sangue do Progenitor Bestial agora só sai drenando o Licantropo à mão (0,1%)
	if mobType == protocol.MobTypeLycanthropeAlpha && rand.Float64() < 0.001*(1.0+luckBonus) {
		for i := range organs {
			if organs[i].OrganType == OrganBlood {
				organs[i].Name = "Sangue do Progenitor Bestial"
				organs[i].ItemReward = protocol.ItemBeastProgenitorBlood
				break
			}
		}
	}

	return appendAnatomy(organs, mobType)
}

// CanInteract verifica se o jogador está no raio de alcance de interação (<= 2.5m).
func (c *Corpse) CanInteract(px, py, pz float32) bool {
	c.Mu.RLock()
	defer c.Mu.RUnlock()

	if time.Now().After(c.ExpiresAt) {
		return false
	}
	dx := px - c.PosX
	dy := py - c.PosY
	dz := pz - c.PosZ
	return (dx*dx + dy*dy + dz*dz) <= 6.25 // 2.5 * 2.5 = 6.25
}

// DistanceTo calcula a distância euclidiana do corpo até a posição dada.
func (c *Corpse) DistanceTo(px, py, pz float32) float32 {
	c.Mu.RLock()
	defer c.Mu.RUnlock()
	dx := px - c.PosX
	dy := py - c.PosY
	dz := pz - c.PosZ
	return float32(math.Sqrt(float64(dx*dx + dy*dy + dz*dz)))
}

// IsExpired verifica se o corpo já ultrapassou o tempo de decomposição de 120s.
func (c *Corpse) IsExpired() bool {
	c.Mu.RLock()
	defer c.Mu.RUnlock()
	return time.Now().After(c.ExpiresAt)
}

// RemainingSeconds retorna os segundos restantes antes da decomposição total.
func (c *Corpse) RemainingSeconds() uint16 {
	c.Mu.RLock()
	defer c.Mu.RUnlock()
	rem := time.Until(c.ExpiresAt).Seconds()
	if rem <= 0 {
		return 0
	}
	if rem > 65535 {
		return 65535
	}
	return uint16(rem)
}

// MarkOrganExtracted marca o órgão informado como extraído e atualiza o estado de saque do cadáver.
func (c *Corpse) MarkOrganExtracted(organIndex uint8, qualityTier uint8) (CorpseOrgan, bool) {
	c.Mu.Lock()
	defer c.Mu.Unlock()

	if int(organIndex) >= len(c.Organs) {
		return CorpseOrgan{}, false
	}

	organ := &c.Organs[organIndex]
	if organ.Extracted {
		return *organ, false
	}

	organ.Extracted = true
	organ.QualityTier = qualityTier

	// Verifica se todos os órgãos foram extraídos
	allExtracted := true
	for i := range c.Organs {
		if !c.Organs[i].Extracted {
			allExtracted = false
			break
		}
	}
	if allExtracted {
		c.IsLooted = true
	}

	return *organ, true
}

// ToSnapshot converte o cadáver para o formato serializável CorpseSnapshot.
func (c *Corpse) ToSnapshot() protocol.CorpseSnapshot {
	c.Mu.RLock()
	defer c.Mu.RUnlock()

	remSec := uint16(0)
	rem := time.Until(c.ExpiresAt).Seconds()
	if rem > 0 {
		remSec = uint16(rem)
	}

	return protocol.CorpseSnapshot{
		CorpseID:         c.CorpseID,
		MobID:            c.MobID,
		MobType:          c.MobType,
		PosX:             c.PosX,
		PosY:             c.PosY,
		PosZ:             c.PosZ,
		RotY:             c.RotY,
		IsLooted:         c.IsLooted,
		RemainingSeconds: remSec,
	}
}

// CorpseManager gerencia o ciclo de vida dos cadáveres no mundo do servidor.
type CorpseManager struct {
	mu           sync.RWMutex
	corpses      map[uint32]*Corpse
	nextCorpseID uint32
}

// NewCorpseManager instancia um gerenciador de cadáveres.
func NewCorpseManager() *CorpseManager {
	return &CorpseManager{
		corpses:      make(map[uint32]*Corpse),
		nextCorpseID: 1000,
	}
}

// CreateCorpseFromMob cria e registra um novo cadáver a partir de um Mob recém-abatido.
func (cm *CorpseManager) CreateCorpseFromMob(mob *Mob, killerID uint32, luckBonus float64) *Corpse {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	cm.nextCorpseID++
	corpseID := cm.nextCorpseID

	mob.Mu.RLock()
	mobID := mob.ID
	mobType := mob.MobType
	mobName := mob.Name
	mobZone := mob.ZoneID
	x, y, z := mob.PosX, mob.PosY, mob.PosZ
	rotY := mob.RotY
	mob.Mu.RUnlock()

	mob.Mu.RLock()
	byZombie, undead, lvl, maxHP := mob.KilledByZombie, mob.Undead, mob.Level, mob.MaxHP
	mob.Mu.RUnlock()
	c := NewCorpse(corpseID, mobID, mobType, mobName, x, y, z, rotY, killerID, luckBonus)
	c.ZoneID = mobZone
	c.KilledByZombie, c.ZombieRemains, c.MobLevel, c.MobMaxHP = byZombie, undead, lvl, maxHP
	cm.corpses[corpseID] = c
	return c
}

// GetCorpse recupera um cadáver pelo seu CorpseID.
func (cm *CorpseManager) GetCorpse(corpseID uint32) (*Corpse, bool) {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	c, ok := cm.corpses[corpseID]
	return c, ok
}

// RemoveCorpse remove o cadáver do mundo.
func (cm *CorpseManager) RemoveCorpse(corpseID uint32) {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	delete(cm.corpses, corpseID)
}

// ExpireCorpses remove e devolve os cadáveres decompostos (para o teste de reerguimento).
func (cm *CorpseManager) ExpireCorpses() []*Corpse {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	var out []*Corpse
	now := time.Now()
	for id, c := range cm.corpses {
		c.Mu.RLock()
		isExp := now.After(c.ExpiresAt)
		c.Mu.RUnlock()
		if isExp {
			out = append(out, c)
			delete(cm.corpses, id)
		}
	}
	return out
}

// CleanupExpired remove cadáveres que já expiraram o tempo de vida útil de 120s.
func (cm *CorpseManager) CleanupExpired() []uint32 {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	var expired []uint32
	now := time.Now()
	for id, c := range cm.corpses {
		c.Mu.RLock()
		isExp := now.After(c.ExpiresAt)
		c.Mu.RUnlock()
		if isExp {
			expired = append(expired, id)
			delete(cm.corpses, id)
		}
	}
	return expired
}

// GetSnapshots retorna a lista de todos os cadáveres ativos para envio aos clientes.
func (cm *CorpseManager) GetSnapshots() []protocol.CorpseSnapshot {
	cm.mu.RLock()
	defer cm.mu.RUnlock()

	snapshots := make([]protocol.CorpseSnapshot, 0, len(cm.corpses))
	now := time.Now()
	for _, c := range cm.corpses {
		c.Mu.RLock()
		if !now.After(c.ExpiresAt) {
			snapshots = append(snapshots, c.ToSnapshot())
		}
		c.Mu.RUnlock()
	}
	return snapshots
}

// Count retorna o número de cadáveres ativos.
func (cm *CorpseManager) Count() int {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	return len(cm.corpses)
}

// GetSnapshotsByZone retorna a lista de cadáveres ativos filtrados por ZoneID.
func (cm *CorpseManager) GetSnapshotsByZone(zoneID uint8) []protocol.CorpseSnapshot {
	cm.mu.RLock()
	defer cm.mu.RUnlock()

	snapshots := make([]protocol.CorpseSnapshot, 0, len(cm.corpses))
	now := time.Now()
	for _, c := range cm.corpses {
		c.Mu.RLock()
		if c.ZoneID == zoneID && !now.After(c.ExpiresAt) {
			snapshots = append(snapshots, c.ToSnapshot())
		}
		c.Mu.RUnlock()
	}
	return snapshots
}

// GetZone retorna a ZoneID do cadáver.
func (c *Corpse) GetZone() uint8 {
	c.Mu.RLock()
	defer c.Mu.RUnlock()
	return c.ZoneID
}

// SetZone define a ZoneID do cadáver.
func (c *Corpse) SetZone(zoneID uint8) {
	c.Mu.Lock()
	defer c.Mu.Unlock()
	c.ZoneID = zoneID
}
