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
)

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

	Organs []CorpseOrgan
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
			Index: 2, Name: "Sangue Lupino Fresco", OrganType: OrganBlood,
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
			Index: 1, Name: "Minério de Ferro Bruto", OrganType: OrganFangOrClaw,
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
			Index: 1, Name: "Minério de Ferro Puro", OrganType: OrganFangOrClaw,
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

	return organs
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
	x, y, z := mob.PosX, mob.PosY, mob.PosZ
	rotY := mob.RotY
	mob.Mu.RUnlock()

	c := NewCorpse(corpseID, mobID, mobType, mobName, x, y, z, rotY, killerID, luckBonus)
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
