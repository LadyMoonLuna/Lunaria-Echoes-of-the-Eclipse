package world

import (
	"net"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
)

// Player representa o estado em memória de um jogador conectado na instância autoritativa.
type Player struct {
	Mu sync.RWMutex

	// LastStandAt marca o último Renascer das Cinzas / Último Fôlego (raças 38 e 34–37)
	LastStandAt time.Time

	ID       uint32
	TCPConn  net.Conn
	UDPAddr  *net.UDPAddr
	LastSeq  uint32
	PosX     float32
	PosY     float32
	PosZ     float32
	RotY     float32
	LastSeen time.Time

	// Marco 3 & Atualização: Identidade, Classes e Tiers
	RaceID      uint8
	ClassID     uint8
	ClassTier   uint8
	ClassPath   uint8 // 0=Base, 1=Caminho A, 2=Caminho B
	Level       uint8
	HP          uint16
	MaxHP       uint16
	Stamina     float32
	MaxStamina  uint16
	RaceEvolved bool // Se já realizou a evolução racial no Nível 10+

	// Provação Lendária (Tier 5 -> Tier 6 Nível 45+)
	LegendaryQuestActive bool  // Se a provação lendária está em andamento
	LegendaryQuestKills  uint8 // Contagem de abates de Elites/Bosses (meta 3)

	// Marco 4 & Expansão: XP Real e 8 Atributos Alocáveis
	XP          uint16
	NextLevelXP uint16
	StatPoints  uint8
	STR         uint8 // Força (Dano Melee)
	DEX         uint8 // Destreza (Dano Ranged e Crítico)
	CON         uint8 // Constituição (+18 MaxHP por ponto)
	AGI         uint8 // Agilidade (+8 MaxStamina por ponto)
	INT         uint8 // Inteligência (Dano Mágico / Alquímico)
	SPI         uint8 // Espírito (Cura)
	MAS         uint8 // Perícia (Multiplicador Crítico)
	LCK         uint8 // Sorte (Chance Crítica)

	// Pontos de Atributos Efetivamente Alocados pelo Jogador
	AllocSTR uint8
	AllocDEX uint8
	AllocCON uint8
	AllocAGI uint8
	AllocINT uint8
	AllocSPI uint8
	AllocMAS uint8
	AllocLCK uint8

	// Buffs e Defesas Especiais
	BuffActiveUntil  time.Time // Afiação de Combate (+25% de dano)
	ParryUntil       time.Time // Postura de Ferro (70% de redução de dano)
	IFrameUntil      time.Time // Invulnerabilidade de Esquiva e Pós-Respawn
	RespawnLockUntil time.Time // Trava de 1s para ignorar pacotes UDP residuais pós-respawn
	WolfPotionUntil  time.Time // Poção de Sangue Lupino (+20% velocidade e crítico por 20s)

	// Sistema de Inventário e 12 Slots de Equipamento Real
	Inventory           map[uint8]uint8 // ItemID -> Quantidade
	EquippedSlots       [12]uint8       // 12 Slots Reais [0..11]
	EquippedArmorID     uint8           // Alias Peitoral (EquippedSlots[1]) para retrocompatibilidade
	EquippedAccessoryID uint8           // Alias Acessório/Anel (EquippedSlots[7]) para retrocompatibilidade

	// Mini-game de Autópsia e Proteção contra Mobs
	InAutopsy           bool      // Flag de autópsia ativa
	AutopsyProtectUntil time.Time // Janela de imunidade contra aggro de mobs

	// Histórico Temporal para Errante Temporal (Cronomante - Raça 28)
	TimeHistory    []TimeHistorySnapshot
	LastRecordTime time.Time

	// Sistema Universal de Amizade com NPCs (0 a 100) e Receitas Secretas
	NPCFriendship   map[uint32]int // NPCID -> Pontos de Afiança (0 a 100)
	UnlockedRecipes map[uint8]bool // RecipeID -> Desbloqueada

	// Cooldowns das Habilidades
	LastActionTimes map[uint8]time.Time
}

// TimeHistorySnapshot armazena uma captura instantânea da posição e integridade do jogador para rebobinar.
type TimeHistorySnapshot struct {
	Timestamp time.Time
	PosX      float32
	PosY      float32
	PosZ      float32
	HP        uint16
	Stamina   float32
}

// GetBaseRaceAttributes retorna os 8 atributos iniciais autoritativos de cada uma das 28 raças.
func GetBaseRaceAttributes(raceID uint8) (str, dex, con, agi, intStat, spi, mas, lck uint8) {
	if d, ok := LookupNewRace(raceID); ok {
		a := d.Attrs
		return a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]
	}
	switch raceID {
	// Raças Base (1 a 4)
	case protocol.RaceValerian:
		return 6, 6, 6, 6, 6, 6, 7, 7
	case protocol.RaceNoctari:
		return 4, 8, 4, 8, 9, 7, 5, 5
	case protocol.RaceKharad:
		return 9, 4, 10, 3, 4, 6, 9, 5
	case protocol.RaceVarkai:
		return 8, 7, 7, 8, 3, 4, 6, 7

	// 6 Raças Secretas Originais (5 a 10)
	case protocol.RaceDhampir:
		return 8, 9, 6, 9, 8, 3, 6, 6
	case protocol.RacePrimordialLycanthrope:
		return 12, 9, 11, 10, 2, 3, 7, 6
	case protocol.RaceRevenant:
		return 7, 6, 9, 5, 9, 10, 6, 3
	case protocol.RaceCelestine:
		return 6, 6, 7, 7, 10, 12, 6, 8
	case protocol.RaceAbyssal:
		return 6, 7, 8, 6, 12, 8, 6, 5
	case protocol.RaceRunicAutomaton:
		return 10, 5, 12, 4, 8, 6, 10, 4

	// Evoluções Ordem / Caos (11 a 18)
	case protocol.RaceHighValerian:
		return 10, 8, 9, 8, 9, 9, 9, 9
	case protocol.RaceAetherWalker:
		return 8, 10, 7, 12, 10, 8, 10, 10
	case protocol.RaceLunarArchon:
		return 5, 11, 6, 11, 14, 11, 8, 8
	case protocol.RaceUmbralSpecter:
		return 6, 13, 5, 14, 12, 9, 11, 9
	case protocol.RaceRunicGuardian:
		return 13, 6, 15, 5, 7, 9, 12, 7
	case protocol.RaceObsidianTitan:
		return 15, 5, 17, 4, 6, 7, 10, 6
	case protocol.RaceDraconicSovereign:
		return 13, 10, 11, 11, 6, 7, 9, 10
	case protocol.RaceFrenzyBeast:
		return 14, 11, 10, 13, 4, 5, 10, 11

	// 10 Novas Raças com Mecânicas Exclusivas (19 a 28)
	case protocol.RaceSylvari:
		return 5, 7, 8, 6, 8, 10, 6, 5
	case protocol.RaceMyconid:
		return 4, 5, 10, 4, 10, 9, 8, 5
	case protocol.RaceArachne:
		return 6, 11, 5, 10, 7, 4, 12, 5
	case protocol.RaceAshDragonborn:
		return 12, 5, 12, 5, 8, 6, 6, 4
	case protocol.RaceChimera:
		return 9, 8, 9, 8, 6, 2, 10, 5
	case protocol.RaceBoreal:
		return 8, 6, 9, 5, 9, 8, 6, 4
	case protocol.RaceThalassian:
		return 7, 8, 7, 9, 9, 8, 5, 5
	case protocol.RaceCambion:
		return 11, 8, 8, 7, 9, 2, 5, 6
	case protocol.RaceNephilim:
		return 9, 9, 8, 8, 10, 10, 7, 7
	case protocol.RaceTimeWanderer:
		return 5, 10, 5, 12, 12, 9, 8, 9

	default:
		return 6, 6, 6, 6, 6, 6, 7, 7
	}
}

// GetClassBaseAttributes retorna os atributos base concedidos pela classe escolhida.
func GetClassBaseAttributes(classID uint8) (str, dex, con, agi, intStat, spi, mas, lck uint8) {
	switch classID {
	case protocol.ClassSwordsman: // 1: Espadachim (+3 FOR, +1 DES, +3 CON, +1 AGI, +1 ESP, +1 PER)
		return 3, 1, 3, 1, 0, 1, 1, 0
	case protocol.ClassScout: // 2: Batedor (+1 FOR, +4 DES, +1 CON, +3 AGI, +1 PER)
		return 1, 4, 1, 3, 0, 0, 1, 0
	case protocol.ClassInitiate: // 3: Iniciado (+1 DES, +1 CON, +1 AGI, +4 INT, +2 ESP, +1 PER)
		return 0, 1, 1, 1, 4, 2, 1, 0
	case protocol.ClassAcolyte: // 4: Acólito (+1 FOR, +2 CON, +2 INT, +4 ESP, +1 PER)
		return 1, 0, 2, 0, 2, 4, 1, 0
	case protocol.ClassBlacksmith: // 5: Ferreiro (+4 FOR, +4 CON, +2 PER)
		return 4, 0, 4, 0, 0, 0, 2, 0
	case protocol.ClassAlchemist: // 6: Alquimista (+2 DES, +1 CON, +1 AGI, +3 INT, +1 ESP, +2 PER)
		return 0, 2, 1, 1, 3, 1, 2, 0
	case protocol.ClassEclipseReaper: // 7: Ceifador (Tier 5 Única: +5 FOR, +3 DES, +3 CON, +3 AGI, +2 INT, +3 PER, +1 SOR)
		return 5, 3, 3, 3, 2, 0, 3, 1
	case protocol.ClassRunicArtificer: // 8: Artífice (Tier 5 Única: +4 FOR, +1 DES, +4 CON, +1 AGI, +4 INT, +4 PER, +2 SOR)
		return 4, 1, 4, 1, 4, 0, 4, 2
	case protocol.ClassHomunculusCreator: // 9: Criador (Tier 5 Única: +1 FOR, +1 DES, +3 CON, +1 AGI, +5 INT, +3 ESP, +4 PER, +2 SOR)
		return 1, 1, 3, 1, 5, 3, 4, 2
	default: // 0: Viajante / Sem Classe
		return 0, 0, 0, 0, 0, 0, 0, 0
	}
}

// ApplyBaseRaceAttributes aplica os atributos iniciais da raça no jogador sem perder bônus de classe ou alocados.
func (p *Player) ApplyBaseRaceAttributes(raceID uint8) {
	p.RaceID = raceID
	p.recalculateStatsLocked()
}

// StatPointsPerLevel retorna os pontos de atributo concedidos por nível com base no Tier de Raridade da Classe (Tier 0 a Tier 6).
func StatPointsPerLevel(classTier uint8) uint8 {
	switch classTier {
	case protocol.TierTraveler: // Tier 0 (Viajante): +3
		return 3
	case protocol.TierCommon: // Tier 1 (Comum): +5
		return 5
	case protocol.TierUncommon: // Tier 2 (Incomum): +6
		return 6
	case protocol.TierRare: // Tier 3 (Rara): +7
		return 7
	case protocol.TierEpic: // Tier 4 (Épica): +8
		return 8
	case protocol.TierUnique: // Tier 5 (Única - Secreta): +10
		return 10
	case protocol.TierLegendary: // Tier 6 (Lendária): +12
		return 12
	default:
		return 5
	}
}

// CalculateStats calcula MaxHP e MaxStamina considerando Classe, Raça, Tier de Raridade e Nível.
func CalculateStats(classID, raceID, classTier, level uint8) (uint16, uint16) {
	if level < 1 {
		level = 1
	}

	var baseHP uint16 = 110
	var baseStamina uint16 = 90

	switch classID {
	case protocol.ClassNone: // 0: Viajante / Sem Classe
		baseHP = 110
		baseStamina = 90
	case protocol.ClassSwordsman: // 1
		baseHP = 140
		baseStamina = 100
	case protocol.ClassScout: // 2
		baseHP = 105
		baseStamina = 135
	case protocol.ClassInitiate: // 3
		baseHP = 95
		baseStamina = 110
	case protocol.ClassAcolyte: // 4
		baseHP = 125
		baseStamina = 105
	case protocol.ClassBlacksmith: // 5 (Ferreiro)
		baseHP = 155
		baseStamina = 100
	case protocol.ClassAlchemist: // 6 (Alquimista)
		baseHP = 110
		baseStamina = 120
	case protocol.ClassEclipseReaper: // 7 (Ceifador)
		baseHP = 160
		baseStamina = 110
	case protocol.ClassRunicArtificer: // 8 (Artífice Rúnico)
		baseHP = 150
		baseStamina = 115
	case protocol.ClassHomunculusCreator: // 9 (Criador de Homúnculos)
		baseHP = 130
		baseStamina = 125
	}

	var modHP uint16 = 10
	var modStamina uint16 = 10

	switch raceID {
	case protocol.RaceValerian: // 1
		modHP = 10
		modStamina = 10
	case protocol.RaceNoctari: // 2
		modHP = 0
		modStamina = 20
	case protocol.RaceKharad: // 3
		modHP = 30
		modStamina = 0
	case protocol.RaceVarkai: // 4
		modHP = 15
		modStamina = 10
	case protocol.RaceDhampir: // 5
		modHP = 10
		modStamina = 15
	case protocol.RacePrimordialLycanthrope: // 6 (Licantropo Primordial)
		modHP = 15 + 80      // +80 MaxHP da evolução Varkai
		modStamina = 10 + 30 // +30 MaxStamina da evolução Varkai
	case protocol.RaceRevenant: // 7 (Amaldiçoado das Cinzas / Revenant)
		modHP = 10 + 50 // +50 MaxHP do despertar sombrio
		modStamina = 10
	case protocol.RaceCelestine: // 8 (Celestino)
		modHP = 25
		modStamina = 25
	case protocol.RaceAbyssal: // 9 (Abissal)
		modHP = 10 + 40
		modStamina = 15 + 15
	case protocol.RaceRunicAutomaton: // 10 (Autômato Rúnico)
		modHP = 60
		modStamina = 15
	case protocol.RaceHighValerian: // 11
		modHP = 40
		modStamina = 30
	case protocol.RaceAetherWalker: // 12
		modHP = 30
		modStamina = 50
	case protocol.RaceLunarArchon: // 13
		modHP = 25
		modStamina = 45
	case protocol.RaceUmbralSpecter: // 14
		modHP = 35
		modStamina = 35
	case protocol.RaceRunicGuardian: // 15
		modHP = 70
		modStamina = 20
	case protocol.RaceObsidianTitan: // 16
		modHP = 90
		modStamina = 10
	case protocol.RaceDraconicSovereign: // 17
		modHP = 75
		modStamina = 35
	case protocol.RaceFrenzyBeast: // 18
		modHP = 60
		modStamina = 45
	case protocol.RaceSylvari: // 19 (Sylvari)
		modHP = 20
		modStamina = 20
	case protocol.RaceMyconid: // 20 (Esporiano / Myconid)
		modHP = 35
		modStamina = 10
	case protocol.RaceArachne: // 21 (Aracne)
		modHP = 15
		modStamina = 25
	case protocol.RaceAshDragonborn: // 22 (Draconato de Cinzas)
		modHP = 50
		modStamina = 15
	case protocol.RaceChimera: // 23 (Quimera)
		modHP = 30
		modStamina = 25
	case protocol.RaceBoreal: // 24 (Boreal)
		modHP = 30
		modStamina = 20
	case protocol.RaceThalassian: // 25 (Thalassiano)
		modHP = 25
		modStamina = 30
	case protocol.RaceCambion: // 26 (Cambion)
		modHP = 40
		modStamina = 20
	case protocol.RaceNephilim: // 27 (Nephilim)
		modHP = 35
		modStamina = 30
	case protocol.RaceTimeWanderer: // 28 (Errante Temporal)
		modHP = 20
		modStamina = 40
	}

	if d, ok := LookupNewRace(raceID); ok {
		modHP = d.ModHP
		modStamina = d.ModStamina
	}

	// Bônus por nível: +5 HP e +2 Stamina por nível acima do 1
	levelBonusHP := uint16(level-1) * 5
	levelBonusStam := uint16(level-1) * 2

	totalBaseHP := float32(baseHP + modHP + levelBonusHP)
	totalBaseStam := float32(baseStamina + modStamina + levelBonusStam)

	// Multiplicador por Tier de Raridade (0 a 6)
	var tierMult float32 = 1.0
	switch classTier {
	case protocol.TierTraveler: // 0 (Viajante)
		tierMult = 1.0
	case protocol.TierCommon: // 1
		tierMult = 1.0
	case protocol.TierUncommon: // 2
		tierMult = 1.20
	case protocol.TierRare: // 3
		tierMult = 1.45
	case protocol.TierEpic: // 4
		tierMult = 1.75
	case protocol.TierUnique: // 5
		tierMult = 2.15
	case protocol.TierLegendary: // 6
		tierMult = 2.60
	default:
		tierMult = 1.0
	}

	finalHP := uint16(totalBaseHP * tierMult)
	finalStam := uint16(totalBaseStam * tierMult)

	return finalHP, finalStam
}

// CalculateStatsByClassAndRace calcula MaxHP e MaxStamina no Tier 1 e Nível 1 (para compatibilidade).
func CalculateStatsByClassAndRace(classID, raceID uint8) (uint16, uint16) {
	return CalculateStats(classID, raceID, protocol.TierCommon, 1)
}

// recalculateStatsLocked recalcula MaxHP, MaxStamina e Atributos Totais por Acumulação (Soma):
// TotalStat = BaseRaceStat + ClassBaseStat + AllocatedStatPoints + EquipmentBonus
func (p *Player) recalculateStatsLocked() {
	rSTR, rDEX, rCON, rAGI, rINT, rSPI, rMAS, rLCK := GetBaseRaceAttributes(p.RaceID)
	cSTR, cDEX, cCON, cAGI, cINT, cSPI, cMAS, cLCK := GetClassBaseAttributes(p.ClassID)

	p.STR = rSTR + cSTR + p.AllocSTR
	p.DEX = rDEX + cDEX + p.AllocDEX
	p.CON = rCON + cCON + p.AllocCON
	p.AGI = rAGI + cAGI + p.AllocAGI
	p.INT = rINT + cINT + p.AllocINT
	p.SPI = rSPI + cSPI + p.AllocSPI
	p.MAS = rMAS + cMAS + p.AllocMAS
	p.LCK = rLCK + cLCK + p.AllocLCK

	baseMaxHP, baseMaxStam := CalculateStats(p.ClassID, p.RaceID, p.ClassTier, p.Level)

	// Bônus de MaxHP e MaxStamina acumulados dos 12 slots de equipamento
	effCONBonus := p.AllocCON
	effAGIBonus := p.AllocAGI
	var directHPBonus uint16 = 0

	for _, itemID := range p.EquippedSlots {
		switch itemID {
		case protocol.ItemVigilHelmet:
			directHPBonus += 25
			effCONBonus += 2
		case protocol.ItemSteelChestplate:
			directHPBonus += 60
			effCONBonus += 5
		case protocol.ItemAlphaWolfPelt:
			directHPBonus += 35
		case protocol.ItemHeavySteelPlate:
			directHPBonus += 50
			effCONBonus += 4
		case protocol.ItemWolfLeatherPants:
			directHPBonus += 30
			effAGIBonus += 3
		case protocol.ItemMistwalkerBoots:
			directHPBonus += 25
			effAGIBonus += 4
		case protocol.ItemRunicWarhammer:
			effCONBonus += 6
		case protocol.ItemLycanAlphaHeart:
			effCONBonus += 5
			effAGIBonus += 5
		case protocol.ItemAncestralFangRing:
			effAGIBonus += 3
		case protocol.ItemBloodRubyRing:
			effCONBonus += 3
		case protocol.ItemObsidianRing:
			effCONBonus += 4
		case protocol.ItemAlphaPeltCloak:
			directHPBonus += 35
			effAGIBonus += 3
		}
	}

	hasAnySlots := false
	for _, id := range p.EquippedSlots {
		if id > 0 {
			hasAnySlots = true
			break
		}
	}

	// Suporte legado se EquippedArmorID ou EquippedAccessoryID foram setados diretamente sem EquippedSlots
	if !hasAnySlots {
		if p.EquippedArmorID > 0 {
			if p.EquippedArmorID == protocol.ItemAlphaWolfPelt {
				directHPBonus += 35
			} else if p.EquippedArmorID == protocol.ItemHeavySteelPlate {
				directHPBonus += 50
				effCONBonus += 4
			}
		}
		if p.EquippedAccessoryID > 0 {
			if p.EquippedAccessoryID == protocol.ItemLycanAlphaHeart {
				effCONBonus += 5
				effAGIBonus += 5
			} else if p.EquippedAccessoryID == protocol.ItemRunicWarhammer {
				effCONBonus += 6
			} else if p.EquippedAccessoryID == protocol.ItemAncestralFangRing {
				effAGIBonus += 3
			}
		}
	}

	baseMaxHP += uint16(effCONBonus)*18 + directHPBonus
	baseMaxStam += uint16(effAGIBonus) * 8

	p.MaxHP = baseMaxHP
	p.MaxStamina = baseMaxStam
}

// RecalculateStats expõe o recálculo thread-safe de status para outros pacotes.
func (p *Player) RecalculateStats() {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.recalculateStatsLocked()
}

// NewPlayer cria uma nova instância de Player com posição oficial inicial no Centro (0, 1.5, 0).
// Inicia apenas com a Raça Valeriano como Viajante Sem Classe (ClassID = 0, ClassTier = 0).
func NewPlayer(id uint32, tcpConn net.Conn, initX, initY, initZ float32) *Player {
	initRace := protocol.RaceValerian
	initClass := protocol.ClassNone   // 0 (Viajante / Sem Classe)
	initTier := protocol.TierTraveler // 0 (Tier 0)
	var initLevel uint8 = 1

	p := &Player{
		ID:              id,
		TCPConn:         tcpConn,
		PosX:            initX,
		PosY:            initY,
		PosZ:            initZ,
		RotY:            0,
		LastSeen:        time.Now(),
		RaceID:          initRace,
		ClassID:         initClass,
		ClassTier:       initTier,
		ClassPath:       0,
		Level:           initLevel,
		XP:              0,
		NextLevelXP:     100,
		StatPoints:      0,
		Inventory:       make(map[uint8]uint8),
		NPCFriendship:   make(map[uint32]int),
		UnlockedRecipes: make(map[uint8]bool),
		LastActionTimes: make(map[uint8]time.Time),
	}
	p.ApplyBaseRaceAttributes(initRace)
	// Todo jogador começa ao conectar com 3x Frasco de Vidro Vazio (ItemID=1) e 2x Carne Crua de Lobo (ItemID=2)
	p.Inventory[protocol.ItemEmptyFlask] = 3
	p.Inventory[protocol.ItemRawWolfMeat] = 2

	p.recalculateStatsLocked()
	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
	return p
}

// SetIdentityMode processa a seleção ou evolução de classe conforme o ActionMode (0, 1, 2, 3).
func (p *Player) SetIdentityMode(raceID, classID, actionMode uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	switch actionMode {
	case protocol.IdentityModeInitialChange: // 0: Troca Inicial / Escolha de Classe no Mestre
		if raceID > 0 {
			p.RaceID = raceID
			if p.Level == 1 && p.StatPoints == 0 {
				p.ApplyBaseRaceAttributes(raceID)
			}
		}
		if classID > 0 {
			p.ClassID = classID
			if p.ClassTier == protocol.TierTraveler {
				p.ClassTier = protocol.TierCommon
			}
		} else if classID == 0 {
			p.ClassID = protocol.ClassNone
			p.ClassTier = protocol.TierTraveler
		}
		if p.Level == 0 {
			p.Level = 1
		}

	case protocol.IdentityModeEvolveClass: // 1: Evoluir Classe
		// Se for Classe Base (1 a 6) e ClassTier < 4: sobe Tier mantendo nível
		if p.ClassID >= 1 && p.ClassID <= 6 {
			if p.ClassTier < protocol.TierEpic {
				p.ClassTier++
			}
		} else if p.ClassID >= 7 && p.ClassID <= 9 {
			// Se for Classe Secreta (7 a 9) e Tier 5: evolui para Lendária (Tier 6) mantendo nível
			if p.ClassTier == protocol.TierUnique {
				p.ClassTier = protocol.TierLegendary
			}
		}
		if raceID >= 11 {
			p.RaceID = raceID
			p.RaceEvolved = true
			p.ApplyBaseRaceAttributes(raceID)
		}

	case protocol.IdentityModeSecretReset: // 2: Trocar para Classe Secreta com Reset de Nível
		if classID >= protocol.ClassEclipseReaper && classID <= protocol.ClassHomunculusCreator {
			p.ClassID = classID
			if raceID > 0 {
				p.RaceID = raceID
			}
			p.ClassTier = protocol.TierUnique // Tier 5 Única
			p.ClassPath = 0
			p.Level = 1 // RESET DE NÍVEL
			p.XP = 0
			p.NextLevelXP = 100
			p.StatPoints = 0
			p.ApplyBaseRaceAttributes(p.RaceID)
		}

	case protocol.IdentityModeTrainLevel5: // 3: Treinar / +5 Níveis para Teste
		p.Level += 5
		p.StatPoints += StatPointsPerLevel(p.ClassTier) * 5
		p.NextLevelXP = 100 + uint16(p.Level-1)*50
	}

	p.recalculateStatsLocked()

	if p.HP > p.MaxHP || actionMode == protocol.IdentityModeInitialChange || actionMode == protocol.IdentityModeSecretReset || actionMode == protocol.IdentityModeTrainLevel5 {
		p.HP = p.MaxHP
	}
	if p.Stamina > float32(p.MaxStamina) || actionMode == protocol.IdentityModeInitialChange || actionMode == protocol.IdentityModeSecretReset || actionMode == protocol.IdentityModeTrainLevel5 {
		p.Stamina = float32(p.MaxStamina)
	}
}

// SetIdentity mantém compatibilidade chamando SetIdentityMode com ActionMode 0.
func (p *Player) SetIdentity(raceID, classID uint8) {
	p.SetIdentityMode(raceID, classID, protocol.IdentityModeInitialChange)
}

// AddLevel incrementa o nível do jogador e recalcula os atributos conforme o ClassTier.
func (p *Player) AddLevel(amount uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	p.Level += amount
	p.StatPoints += StatPointsPerLevel(p.ClassTier) * amount
	p.NextLevelXP = 100 + uint16(p.Level-1)*50
	oldMaxHP := p.MaxHP
	p.recalculateStatsLocked()
	if p.MaxHP > oldMaxHP {
		p.HP += (p.MaxHP - oldMaxHP)
	}
	if p.HP > p.MaxHP {
		p.HP = p.MaxHP
	}
}

// AddXP adiciona experiência ao jogador e processa subida de nível quando XP >= NextLevelXP.
// O ganho de StatPoints escala conforme a raridade da classe (Tier 0 a 6).
// Retorna true se o jogador subiu de nível pelo menos uma vez.
func (p *Player) AddXP(amount uint16) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	p.XP += amount
	leveledUp := false
	for p.NextLevelXP > 0 && p.XP >= p.NextLevelXP {
		p.XP -= p.NextLevelXP
		p.Level++
		p.StatPoints += StatPointsPerLevel(p.ClassTier)
		p.NextLevelXP = 100 + uint16(p.Level-1)*50
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		leveledUp = true
	}
	return leveledUp
}

// AllocateStat consome 1 ponto de status para incrementar o atributo especificado (1 a 8).
func (p *Player) AllocateStat(statID uint8) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.StatPoints == 0 {
		return false
	}

	switch statID {
	case protocol.StatIDSTR: // 1: Força
		p.AllocSTR++
	case protocol.StatIDDEX: // 2: Destreza
		p.AllocDEX++
	case protocol.StatIDCON: // 3: Constituição (+18 MaxHP)
		p.AllocCON++
	case protocol.StatIDAGI: // 4: Agilidade (+8 MaxStamina)
		p.AllocAGI++
	case protocol.StatIDINT: // 5: Inteligência
		p.AllocINT++
	case protocol.StatIDSPI: // 6: Espírito
		p.AllocSPI++
	case protocol.StatIDMAS: // 7: Perícia
		p.AllocMAS++
	case protocol.StatIDLCK: // 8: Sorte
		p.AllocLCK++
	default:
		return false
	}

	p.StatPoints--
	oldMaxHP := p.MaxHP
	p.recalculateStatsLocked()
	if p.MaxHP > oldMaxHP {
		p.HP += (p.MaxHP - oldMaxHP)
	}
	if p.HP > p.MaxHP {
		p.HP = p.MaxHP
	}
	if p.Stamina > float32(p.MaxStamina) {
		p.Stamina = float32(p.MaxStamina)
	}
	return true
}

func (p *Player) getAttributesLocked() (str, dex, con, agi, intStat, spi, mas, lck uint8) {
	str = p.STR
	dex = p.DEX
	con = p.CON
	agi = p.AGI
	intStat = p.INT
	spi = p.SPI
	mas = p.MAS
	lck = p.LCK

	// Bônus dos 12 Slots de Equipamento
	for _, itemID := range p.EquippedSlots {
		switch itemID {
		case protocol.ItemVigilHelmet:
			con += 2
		case protocol.ItemSteelChestplate:
			con += 5
		case protocol.ItemAlphaWolfPelt:
			str += 3
		case protocol.ItemHeavySteelPlate:
			con += 4
		case protocol.ItemWolfLeatherPants:
			agi += 3
		case protocol.ItemMistwalkerBoots:
			agi += 4
			dex += 2
		case protocol.ItemBlacksmithGauntlets:
			str += 4
			mas += 3
		case protocol.ItemRunicWarhammer:
			str += 8
			con += 6
			mas += 4
		case protocol.ItemAlchemistBelt:
			intStat += 3
			spi += 3
		case protocol.ItemSilverMoonAmulet:
			intStat += 4
			spi += 4
			lck += 3
		case protocol.ItemLycanAlphaHeart:
			str += 5
			dex += 5
			con += 5
			agi += 5
			intStat += 5
			spi += 5
			mas += 5
			lck += 5
		case protocol.ItemAncestralFangRing:
			dex += 3
			agi += 3
		case protocol.ItemBloodRubyRing:
			str += 4
			con += 3
		case protocol.ItemObsidianRing:
			con += 4
			mas += 3
		case protocol.ItemStarlightRing:
			intStat += 3
			lck += 4
		case protocol.ItemAlphaPeltCloak:
			str += 3
			agi += 3
		}
	}

	hasAnySlots := false
	for _, id := range p.EquippedSlots {
		if id > 0 {
			hasAnySlots = true
			break
		}
	}

	// Fallback legado se os 12 slots estiverem zerados mas campos legados preenchidos
	if !hasAnySlots {
		if p.EquippedArmorID > 0 {
			if p.EquippedArmorID == protocol.ItemAlphaWolfPelt {
				str += 3
			} else if p.EquippedArmorID == protocol.ItemHeavySteelPlate {
				con += 4
			}
		}
		if p.EquippedAccessoryID > 0 {
			if p.EquippedAccessoryID == protocol.ItemAncestralFangRing {
				dex += 3
				agi += 3
			} else if p.EquippedAccessoryID == protocol.ItemLycanAlphaHeart {
				str += 5
				dex += 5
				con += 5
				agi += 5
				intStat += 5
				spi += 5
				mas += 5
				lck += 5
			} else if p.EquippedAccessoryID == protocol.ItemRunicWarhammer {
				str += 8
				con += 6
				mas += 4
			}
		}
	}

	return str, dex, con, agi, intStat, spi, mas, lck
}

// GetAttributes retorna os 8 atributos atuais do jogador (incluindo bônus de equipamentos) de forma thread-safe.
func (p *Player) GetAttributes() (str, dex, con, agi, intStat, spi, mas, lck uint8) {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.getAttributesLocked()
}

// EvolveToPrimordialLycanthrope evolui a raça do jogador para Licantropo Primordial (RaceID = 6),
// concedendo +80 MaxHP, +30 MaxStamina e curando totalmente o jogador.
func (p *Player) EvolveToPrimordialLycanthrope() {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	p.RaceID = protocol.RacePrimordialLycanthrope
	p.recalculateStatsLocked()
	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
}

// CanPerformAction verifica se o cooldown da ação já expirou no servidor.
func (p *Player) CanPerformAction(actionType uint8) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()

	lastTime, exists := p.LastActionTimes[actionType]
	if !exists {
		return true
	}

	var cd time.Duration
	switch actionType {
	case protocol.ActionBasicAttack: // 1: Ataque Básico (cd 0.45s)
		cd = 450 * time.Millisecond
	case protocol.ActionDodgeRoll: // 2: Esquiva (cd 0.5s)
		cd = 500 * time.Millisecond
	case protocol.ActionSkillQ: // 3: Skill Q (cd 2.0s)
		cd = 2000 * time.Millisecond
	case protocol.ActionSkillR: // 4: Skill R (cd 4.0s)
		cd = 4000 * time.Millisecond
	case protocol.ActionSkillF: // 5: Skill F (cd 6.0s)
		cd = 6000 * time.Millisecond
	case protocol.ActionRacialSkill: // 6: Habilidade Racial Ativa [Tecla Z] (cd 10.0s)
		cd = 10000 * time.Millisecond
	default:
		cd = 300 * time.Millisecond
	}

	if p.RaceID == protocol.RaceTimeWanderer {
		cd = time.Duration(float64(cd) * 0.75)
	}
	if d, ok := LookupNewRace(p.RaceID); ok && actionType == protocol.ActionRacialSkill {
		cd = d.RacialCD
	}

	return time.Since(lastTime) >= cd
}

// RecordAction registra o timestamp da ação para controle de cooldown autoritativo.
func (p *Player) RecordAction(actionType uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.LastActionTimes[actionType] = time.Now()
}

// SetDodgeIFrame concede tempo de invulnerabilidade (0.5s) durante a esquiva.
func (p *Player) SetDodgeIFrame(duration time.Duration) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.IFrameUntil = time.Now().Add(duration)
}

// SetParry concede a Postura de Ferro do Espadachim reduzindo 70% de todo dano por 2.5s.
func (p *Player) SetParry(duration time.Duration) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.ParryUntil = time.Now().Add(duration)
}

// SetBuff concede a Afiação de Combate aumentando o dano em +25% por 10s.
func (p *Player) SetBuff(duration time.Duration) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.BuffActiveUntil = time.Now().Add(duration)
}

// IsBuffActive verifica se o jogador está sob efeito de buff ativo.
func (p *Player) IsBuffActive() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Now().Before(p.BuffActiveUntil)
}

// IsInvulnerable verifica se o jogador está em janela de invulnerabilidade (I-Frame).
func (p *Player) IsInvulnerable() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Now().Before(p.IFrameUntil)
}

// IsRespawnLocked verifica se a trava de 1.0s pós-respawn está ativa para ignorar pacotes UDP antigos.
func (p *Player) IsRespawnLocked() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Now().Before(p.RespawnLockUntil)
}

// Heal restaura vida até o limite de MaxHP e retorna o novo valor de HP.
func (p *Player) Heal(amount uint16) uint16 {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	p.HP += amount
	if p.HP > p.MaxHP {
		p.HP = p.MaxHP
	}
	return p.HP
}

// Respawn restaura HP e Stamina para o máximo, define posição segura, 2s de I-Frame e 1s de trava UDP.
func (p *Player) Respawn(safeX, safeY, safeZ float32) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
	p.PosX = safeX
	p.PosY = safeY
	p.PosZ = safeZ
	p.IFrameUntil = time.Now().Add(2 * time.Second)
	p.RespawnLockUntil = time.Now().Add(1 * time.Second)

	// Na Provação Lendária, a morte reseta a contagem de abates de elites (sem morrer)
	if p.LegendaryQuestActive {
		p.LegendaryQuestKills = 0
	}
}

// RestoreStamina recupera estamina instantaneamente até o limite MaxStamina.
func (p *Player) RestoreStamina(amount float32) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.Stamina += amount
	if p.Stamina > float32(p.MaxStamina) {
		p.Stamina = float32(p.MaxStamina)
	}
}

// RegenerateStamina recupera estamina a 30 Hz.
func (p *Player) RegenerateStamina(dt float32, isNight bool, moonPhase uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	baseRegenRate := float32(15.0) // 15 pontos de stamina por segundo
	if p.RaceID == protocol.RaceValerian {
		baseRegenRate *= 1.15 // +15% de regeneração de estamina para Valeriano
	}
	if isNight && moonPhase == MoonPhaseWaxingCrescent {
		baseRegenRate *= 1.15 // +15% de regeneração sob a Lua Crescente
	}

	p.Stamina += baseRegenRate * dt
	if p.Stamina > float32(p.MaxStamina) {
		p.Stamina = float32(p.MaxStamina)
	}
}

// ConsumeStamina verifica e consome estamina para uma ação de combate. Retorna true se houver estamina suficiente.
func (p *Player) ConsumeStamina(amount float32) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.Stamina < amount {
		return false
	}
	p.Stamina -= amount
	return true
}

// TakeDamage aplica dano ao jogador e retorna o HP atualizado.
// Respeita janelas de invulnerabilidade (I-Frames de Esquiva e Respawn), Parry de 70% e passivas.
func (p *Player) TakeDamage(amount uint16) (uint16, bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	// Se estiver invulnerável (Dodge Roll ou pós-respawn), ignora dano
	if time.Now().Before(p.IFrameUntil) {
		return p.HP, false
	}

	// Postura de Ferro (Parry do Espadachim): reduz todo dano em 70%
	if time.Now().Before(p.ParryUntil) && amount > 0 {
		amount = uint16(float32(amount) * 0.30)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Kharad (Postura de Rocha): reduz todo dano recebido em 20%
	if p.RaceID == protocol.RaceKharad && amount > 0 {
		amount = uint16(float32(amount) * 0.80)
		if amount == 0 {
			amount = 1
		}
	}

	// Raças 29–45: resistência/fragilidade racial (Orc, Drago da Terra, Tartaruga, Gigante de Gelo, Fadinha)
	if d, ok := LookupNewRace(p.RaceID); ok && amount > 0 && d.DamageTaken != 1.0 {
		amount = uint16(float32(amount) * d.DamageTaken)
		if amount == 0 {
			amount = 1
		}
	}

	if amount >= p.HP {
		// Renascer das Cinzas (Pyromante) / Último Fôlego (Drago): fica com 20% de vida, recarga longa
		if d, ok := LookupNewRace(p.RaceID); ok && d.LastStand && time.Since(p.LastStandAt) >= LastStandCooldown {
			p.LastStandAt = time.Now()
			p.HP = p.MaxHP / 5
			if p.HP == 0 {
				p.HP = 1
			}
			p.IFrameUntil = time.Now().Add(1500 * time.Millisecond)
			return p.HP, false
		}
		p.HP = 0
		return 0, true
	}
	p.HP -= amount
	return p.HP, false
}

// SpendHPPercent consome uma porcentagem da vida atual (Combustão, Sangue Tóxico, Manamante); nunca mata.
func (p *Player) SpendHPPercent(pct float32) uint16 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	cost := uint16(float32(p.HP) * pct)
	if cost >= p.HP {
		cost = p.HP - 1
	}
	p.HP -= cost
	return cost
}

// HPFraction retorna a vida atual como fração da máxima.
func (p *Player) HPFraction() float32 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	if p.MaxHP == 0 {
		return 0
	}
	return float32(p.HP) / float32(p.MaxHP)
}

// HealPercent cura uma porcentagem da vida máxima.
func (p *Player) HealPercent(pct float32) uint16 {
	p.Mu.RLock()
	amount := uint16(float32(p.MaxHP) * pct)
	p.Mu.RUnlock()
	return p.Heal(amount)
}

// GrantIFrame concede invulnerabilidade curta (fugas e carapaças).
func (p *Player) GrantIFrame(d time.Duration) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.IFrameUntil = time.Now().Add(d)
}

// GrantDamageReduction ativa a redução de dano da Postura (70%) por um tempo (Carapaça da Tartaruga).
func (p *Player) GrantDamageReduction(d time.Duration) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.ParryUntil = time.Now().Add(d)
}

// UpdateFromMove atualiza posição, rotação e endereço UDP caso o Seq seja estritamente superior ao LastSeq.
func (p *Player) UpdateFromMove(seq uint32, posX, posY, posZ, rotY float32, addr *net.UDPAddr) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.LastSeq != 0 && seq <= p.LastSeq {
		return false
	}

	p.LastSeq = seq
	p.PosX = posX
	p.PosY = posY
	p.PosZ = posZ
	p.RotY = rotY
	p.UDPAddr = addr
	now := time.Now()
	p.LastSeen = now
	if now.Sub(p.LastRecordTime) >= 200*time.Millisecond {
		p.LastRecordTime = now
		snap := TimeHistorySnapshot{
			Timestamp: now,
			PosX:      posX,
			PosY:      posY,
			PosZ:      posZ,
			HP:        p.HP,
			Stamina:   p.Stamina,
		}
		p.TimeHistory = append(p.TimeHistory, snap)
		cutoff := now.Add(-4 * time.Second)
		idx := 0
		for idx < len(p.TimeHistory) && p.TimeHistory[idx].Timestamp.Before(cutoff) {
			idx++
		}
		if idx > 0 {
			p.TimeHistory = p.TimeHistory[idx:]
		}
	}
	return true
}

// GetUDPAddr retorna o endereço UDP thread-safe associado ao jogador.
func (p *Player) GetUDPAddr() *net.UDPAddr {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.UDPAddr
}

// ToSnapshot converte o estado atual do jogador em uma estrutura PlayerSnapshot thread-safe.
func (p *Player) ToSnapshot() protocol.PlayerSnapshot {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return protocol.PlayerSnapshot{
		PlayerID: p.ID,
		PosX:     p.PosX,
		PosY:     p.PosY,
		PosZ:     p.PosZ,
		RotY:     p.RotY,
	}
}

// ToStatsPacket converte os status de sobrevivência, progressão e atributos em PlayerStatsPacket (31 bytes).
func (p *Player) ToStatsPacket() protocol.PlayerStatsPacket {
	p.Mu.RLock()
	defer p.Mu.RUnlock()

	var buffActive uint8 = 0
	if time.Now().Before(p.BuffActiveUntil) || time.Now().Before(p.WolfPotionUntil) {
		buffActive = 1
	}

	str, dex, con, agi, intStat, spi, mas, lck := p.getAttributesLocked()

	return protocol.PlayerStatsPacket{
		PlayerID:    p.ID,
		RaceID:      p.RaceID,
		ClassID:     p.ClassID,
		ClassTier:   p.ClassTier,
		Level:       p.Level,
		HP:          p.HP,
		MaxHP:       p.MaxHP,
		Stamina:     uint16(p.Stamina),
		MaxStamina:  p.MaxStamina,
		BuffActive:  buffActive,
		XP:          p.XP,
		NextLevelXP: p.NextLevelXP,
		StatPoints:  p.StatPoints,
		STR:         str,
		DEX:         dex,
		CON:         con,
		AGI:         agi,
		INT:         intStat,
		SPI:         spi,
		MAS:         mas,
		LCK:         lck,
	}
}

// AddItem adiciona itens à mochila do jogador.
func (p *Player) AddItem(itemID, qty uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.Inventory == nil {
		p.Inventory = make(map[uint8]uint8)
	}
	p.Inventory[itemID] += qty
}

// RemoveItem remove itens da mochila do jogador se houver quantidade suficiente.
func (p *Player) RemoveItem(itemID, qty uint8) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.Inventory == nil {
		return false
	}
	curr := p.Inventory[itemID]
	if curr < qty {
		return false
	}
	if curr == qty {
		delete(p.Inventory, itemID)
	} else {
		p.Inventory[itemID] = curr - qty
	}
	return true
}

// HasItem verifica se o jogador possui o item no inventário.
func (p *Player) HasItem(itemID uint8) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.Inventory != nil && p.Inventory[itemID] > 0
}

// GetItemCount retorna a quantidade do item no inventário.
func (p *Player) GetItemCount(itemID uint8) uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	if p.Inventory == nil {
		return 0
	}
	return p.Inventory[itemID]
}

// GetInventorySlots retorna uma lista ordenada dos slots do inventário para sincronização em rede.
func (p *Player) GetInventorySlots() []protocol.InventorySlot {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	slots := make([]protocol.InventorySlot, 0, len(p.Inventory))
	for id := uint8(1); id <= 255; id++ {
		if qty, exists := p.Inventory[id]; exists && qty > 0 {
			slots = append(slots, protocol.InventorySlot{ItemID: id, Quantity: qty})
		}
		if id == 255 {
			break
		}
	}
	return slots
}

// GetEquipment retorna os IDs dos equipamentos equipados de forma thread-safe.
func (p *Player) GetEquipment() (armorID, accessoryID uint8) {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.EquippedSlots[protocol.SlotChest], p.EquippedSlots[protocol.SlotRing1]
}

// GetEquippedSlots retorna uma cópia dos 12 slots equipados thread-safe.
func (p *Player) GetEquippedSlots() [12]uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.EquippedSlots
}

// getSlotForItem retorna o slot padrão (0..11) para o itemID e se ele é equipável.
func getSlotForItem(itemID uint8) (uint8, bool) {
	switch itemID {
	case protocol.ItemVigilHelmet:
		return protocol.SlotHelmet, true // 0: Capacete
	case protocol.ItemSteelChestplate, protocol.ItemAlphaWolfPelt, protocol.ItemHeavySteelPlate:
		return protocol.SlotChest, true // 1: Peitoral
	case protocol.ItemWolfLeatherPants:
		return protocol.SlotLegs, true // 2: Calças
	case protocol.ItemMistwalkerBoots:
		return protocol.SlotBoots, true // 3: Botas
	case protocol.ItemBlacksmithGauntlets, protocol.ItemRunicWarhammer:
		return protocol.SlotGloves, true // 4: Luvas / Arma
	case protocol.ItemAlchemistBelt:
		return protocol.SlotBelt, true // 5: Cinto
	case protocol.ItemSilverMoonAmulet, protocol.ItemLycanAlphaHeart:
		return protocol.SlotAmulet, true // 6: Colar / Relíquia
	case protocol.ItemAncestralFangRing, protocol.ItemBloodRubyRing, protocol.ItemObsidianRing, protocol.ItemStarlightRing:
		return protocol.SlotRing1, true // 7: Anel 1 (gerenciado nos slots 7 a 10)
	case protocol.ItemAlphaPeltCloak:
		return protocol.SlotCloak, true // 11: Capa / Manto
	default:
		return 255, false
	}
}

// EquipItem vincula um item aos 12 slots de equipamento.
// Anéis preenchem os slots 7..10; se todos estiverem ocupados, rotacionam substituindo o mais antigo.
func (p *Player) EquipItem(itemID uint8) (bool, string) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.Inventory == nil || p.Inventory[itemID] == 0 {
		return false, "Item não encontrado no inventário."
	}

	slot, ok := getSlotForItem(itemID)
	if !ok {
		return false, "Este item não pode ser equipado."
	}

	// Caso especial: Anéis ocupam os slots 7, 8, 9 ou 10
	if slot == protocol.SlotRing1 {
		targetSlot := -1
		for _, s := range []int{7, 8, 9, 10} {
			if p.EquippedSlots[s] == 0 {
				targetSlot = s
				break
			}
		}
		if targetSlot != -1 {
			p.EquippedSlots[targetSlot] = itemID
		} else {
			// Rotação autoritativa: devolve [7] ao inventário e rotaciona os anéis
			oldRing := p.EquippedSlots[7]
			p.EquippedSlots[7] = p.EquippedSlots[8]
			p.EquippedSlots[8] = p.EquippedSlots[9]
			p.EquippedSlots[9] = p.EquippedSlots[10]
			p.EquippedSlots[10] = itemID
			if p.Inventory == nil {
				p.Inventory = make(map[uint8]uint8)
			}
			p.Inventory[oldRing]++
		}
		p.EquippedAccessoryID = itemID
		p.consumeOneItemLocked(itemID)
		p.recalculateStatsLocked()
		return true, "Anel equipado com sucesso."
	}

	// Demais slots fixos
	old := p.EquippedSlots[slot]
	if old > 0 {
		p.Inventory[old]++
	}
	p.EquippedSlots[slot] = itemID
	if slot == protocol.SlotChest {
		p.EquippedArmorID = itemID
	} else if slot == protocol.SlotAmulet || slot == protocol.SlotGloves {
		p.EquippedAccessoryID = itemID
	}
	p.consumeOneItemLocked(itemID)
	p.recalculateStatsLocked()
	return true, "Equipamento vinculado com sucesso."
}

// UnequipSlot desequipa o item de um slot específico (0 a 11) e devolve à mochila.
func (p *Player) UnequipSlot(slotIdx uint8) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if slotIdx >= 12 || p.EquippedSlots[slotIdx] == 0 {
		return false
	}
	if p.Inventory == nil {
		p.Inventory = make(map[uint8]uint8)
	}
	old := p.EquippedSlots[slotIdx]
	p.Inventory[old]++
	p.EquippedSlots[slotIdx] = 0
	if slotIdx == protocol.SlotChest {
		p.EquippedArmorID = 0
	} else if slotIdx == protocol.SlotRing1 || slotIdx == protocol.SlotAmulet {
		p.EquippedAccessoryID = 0
	}
	p.recalculateStatsLocked()
	return true
}

// UnequipItem remove o item do slot ("armor" ou "accessory") mantendo compatibilidade retroativa.
func (p *Player) UnequipItem(slot string) bool {
	switch slot {
	case "armor":
		return p.UnequipSlot(protocol.SlotChest)
	case "accessory":
		for _, s := range []uint8{protocol.SlotRing1, protocol.SlotRing2, protocol.SlotRing3, protocol.SlotRing4, protocol.SlotAmulet, protocol.SlotGloves} {
			if p.EquippedSlots[s] > 0 {
				return p.UnequipSlot(s)
			}
		}
		return false
	default:
		return false
	}
}

// DevSetRaceAndKit define qualquer raça (1 a 45) e equipa um kit de teste com os 12 slots reais.
func (p *Player) DevSetRaceAndKit(raceID, classID uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if raceID >= 1 && raceID <= protocol.RaceMaxID {
		p.RaceID = raceID
		p.ApplyBaseRaceAttributes(raceID)
	}
	if classID > 0 {
		p.ClassID = classID
		p.ClassTier = protocol.TierCommon
	}

	// Equipa kit completo para os 12 slots reais
	p.EquippedSlots[protocol.SlotHelmet] = protocol.ItemVigilHelmet
	p.EquippedSlots[protocol.SlotChest] = protocol.ItemSteelChestplate
	p.EquippedSlots[protocol.SlotLegs] = protocol.ItemWolfLeatherPants
	p.EquippedSlots[protocol.SlotBoots] = protocol.ItemMistwalkerBoots
	p.EquippedSlots[protocol.SlotGloves] = protocol.ItemBlacksmithGauntlets
	p.EquippedSlots[protocol.SlotBelt] = protocol.ItemAlchemistBelt
	p.EquippedSlots[protocol.SlotAmulet] = protocol.ItemSilverMoonAmulet
	p.EquippedSlots[protocol.SlotRing1] = protocol.ItemAncestralFangRing
	p.EquippedSlots[protocol.SlotRing2] = protocol.ItemBloodRubyRing
	p.EquippedSlots[protocol.SlotRing3] = protocol.ItemObsidianRing
	p.EquippedSlots[protocol.SlotRing4] = protocol.ItemStarlightRing
	p.EquippedSlots[protocol.SlotCloak] = protocol.ItemAlphaPeltCloak

	p.EquippedArmorID = protocol.ItemSteelChestplate
	p.EquippedAccessoryID = protocol.ItemAncestralFangRing

	if p.Inventory == nil {
		p.Inventory = make(map[uint8]uint8)
	}
	p.Inventory[protocol.ItemWolfBloodPotion] = 5
	p.Inventory[protocol.ItemCookedNobleMeat] = 5
	p.Inventory[protocol.ItemOrganicTrash] = 3
	p.Inventory[protocol.ItemRunicHourglass] = 1
	p.Inventory[protocol.ItemSilverSilkCocoon] = 1

	p.recalculateStatsLocked()
	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
}

// SetInAutopsy define se o jogador está realizando o mini-game de autópsia.
func (p *Player) SetInAutopsy(in bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.InAutopsy = in
	if in {
		p.AutopsyProtectUntil = time.Now().Add(15 * time.Second)
	} else {
		p.AutopsyProtectUntil = time.Time{}
	}
}

// IsInAutopsy retorna se o jogador está protegido realizando autópsia (mobs ignoram).
func (p *Player) IsInAutopsy() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.InAutopsy || time.Now().Before(p.AutopsyProtectUntil)
}

// RecordTimeSnapshot grava um ponto histórico no buffer circular para rebobinar o tempo.
func (p *Player) RecordTimeSnapshot(x, y, z float32, hp uint16, stam float32) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	now := time.Now()
	p.LastRecordTime = now
	snap := TimeHistorySnapshot{
		Timestamp: now,
		PosX:      x,
		PosY:      y,
		PosZ:      z,
		HP:        hp,
		Stamina:   stam,
	}
	p.TimeHistory = append(p.TimeHistory, snap)
	cutoff := now.Add(-4 * time.Second)
	idx := 0
	for idx < len(p.TimeHistory) && p.TimeHistory[idx].Timestamp.Before(cutoff) {
		idx++
	}
	if idx > 0 {
		p.TimeHistory = p.TimeHistory[idx:]
	}
}

// RewindTimeDestiny restaura o jogador para 3 segundos atrás (Skill Z do Errante Temporal).
func (p *Player) RewindTimeDestiny() (TimeHistorySnapshot, bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	targetTime := time.Now().Add(-3 * time.Second)
	var bestSnap TimeHistorySnapshot
	found := false
	minDiff := time.Duration(1<<63 - 1)

	for _, s := range p.TimeHistory {
		diff := s.Timestamp.Sub(targetTime)
		if diff < 0 {
			diff = -diff
		}
		if diff < minDiff {
			minDiff = diff
			bestSnap = s
			found = true
		}
	}

	if found && minDiff < 1800*time.Millisecond {
		if bestSnap.HP > p.HP {
			p.HP = bestSnap.HP
		} else {
			p.HP += 80
			if p.HP > p.MaxHP {
				p.HP = p.MaxHP
			}
		}
		if bestSnap.Stamina > p.Stamina {
			p.Stamina = bestSnap.Stamina
		} else {
			p.Stamina += 80.0
			if p.Stamina > float32(p.MaxStamina) {
				p.Stamina = float32(p.MaxStamina)
			}
		}
		p.PosX = bestSnap.PosX
		p.PosY = bestSnap.PosY
		p.PosZ = bestSnap.PosZ
		return bestSnap, true
	}

	p.HP += 80
	if p.HP > p.MaxHP {
		p.HP = p.MaxHP
	}
	p.Stamina += 80.0
	if p.Stamina > float32(p.MaxStamina) {
		p.Stamina = float32(p.MaxStamina)
	}
	return TimeHistorySnapshot{PosX: p.PosX, PosY: p.PosY, PosZ: p.PosZ, HP: p.HP, Stamina: p.Stamina}, false
}

// UseConsumable usa um item consumível ou tomo/relíquia de raça/classe secreta.
func (p *Player) UseConsumable(itemID uint8) (bool, string) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.Inventory == nil || p.Inventory[itemID] == 0 {
		return false, "Item não encontrado no inventário."
	}

	switch itemID {
	case protocol.ItemRawWolfMeat: // 2: Carne Crua de Lobo (+45 HP / +90 HP Quimera)
		p.consumeOneItemLocked(itemID)
		healAmt := uint16(45)
		msg := "Você consumiu Carne Crua de Lobo e recuperou +45 HP."
		if p.RaceID == protocol.RaceChimera {
			healAmt = 90
			p.BuffActiveUntil = time.Now().Add(60 * time.Second)
			msg = "Digestão Quimérica! Você recuperou +90 HP e ganhou +15% de dano por 60s."
		}
		p.HP += healAmt
		if p.HP > p.MaxHP {
			p.HP = p.MaxHP
		}
		return true, msg

	case protocol.ItemCookedNobleMeat: // 3: Carne Nobre Assada (+90 HP, +40 Stamina / dobro Quimera)
		p.consumeOneItemLocked(itemID)
		healAmt := uint16(90)
		stamAmt := float32(40)
		msg := "Você saboreou Carne Nobre Assada (+90 HP, +40 Stamina)."
		if p.RaceID == protocol.RaceChimera {
			healAmt = 180
			stamAmt = 80
			p.BuffActiveUntil = time.Now().Add(60 * time.Second)
			msg = "Banquete Quimérico! Você recuperou +180 HP, +80 Stamina e ganhou +15% de dano por 60s."
		}
		p.HP += healAmt
		if p.HP > p.MaxHP {
			p.HP = p.MaxHP
		}
		p.Stamina += stamAmt
		if p.Stamina > float32(p.MaxStamina) {
			p.Stamina = float32(p.MaxStamina)
		}
		return true, msg

	case protocol.ItemWolfBloodPotion: // 4: Poção de Sangue Lupino (+20% Velocidade e Crítico por 20s)
		p.consumeOneItemLocked(itemID)
		p.WolfPotionUntil = time.Now().Add(20 * time.Second)
		return true, "Você bebeu a Poção de Sangue Lupino (+20% Velocidade e Crítico por 20s)!"

	case protocol.ItemBeastProgenitorBlood: // 16: Sangue do Progenitor Bestial (Desperta linhagem Dhampir)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceDhampir
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O Sangue do Progenitor Bestial ferve em suas veias! Você despertou como Dhampir!"

	case protocol.ItemEclipseScytheTome: // 17: Tomo da Foice do Eclipse (Ceifador do Eclipse, Tier 5 Única, Reset Nível 1)
		p.consumeOneItemLocked(itemID)
		p.ClassID = protocol.ClassEclipseReaper
		p.ClassTier = protocol.TierUnique
		p.Level = 1
		p.XP = 0
		p.NextLevelXP = 100
		p.StatPoints = 0
		p.AllocSTR = 0
		p.AllocDEX = 0
		p.AllocCON = 0
		p.AllocAGI = 0
		p.AllocINT = 0
		p.AllocSPI = 0
		p.AllocMAS = 0
		p.AllocLCK = 0
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "Você leu o Tomo da Foice do Eclipse e renasceu como Ceifador do Eclipse (Tier Única - Nível 1)!"

	case protocol.ItemStarforgeCore: // 18: Núcleo de Forja Estelar (Artífice Rúnico, Tier 5 Única, Reset Nível 1)
		p.consumeOneItemLocked(itemID)
		p.ClassID = protocol.ClassRunicArtificer
		p.ClassTier = protocol.TierUnique
		p.Level = 1
		p.XP = 0
		p.NextLevelXP = 100
		p.StatPoints = 0
		p.AllocSTR = 0
		p.AllocDEX = 0
		p.AllocCON = 0
		p.AllocAGI = 0
		p.AllocINT = 0
		p.AllocSPI = 0
		p.AllocMAS = 0
		p.AllocLCK = 0
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "A energia rúnica do Núcleo de Forja transborda! Você despertou como Artífice Rúnico (Tier Única - Nível 1)!"

	case protocol.ItemRunicWarhammerRecipe: // 26: Receita do Malho de Batalha Rúnico
		p.consumeOneItemLocked(itemID)
		p.unlockRecipeLocked(protocol.ItemRunicWarhammerRecipe)
		if p.Inventory == nil {
			p.Inventory = make(map[uint8]uint8)
		}
		p.Inventory[protocol.ItemRunicWarhammer]++
		return true, "Você aprendeu a receita secreta e forjou o lendário Malho de Batalha Rúnico (+45 Dano Melee, +8 FOR, +6 CON, +4 MAS)!"

	case protocol.ItemOrganicTrash: // 28: Lixo Orgânico (Alimento e Buff exclusivo Myconid)
		if p.RaceID == protocol.RaceMyconid {
			p.consumeOneItemLocked(itemID)
			p.HP += 50
			if p.HP > p.MaxHP {
				p.HP = p.MaxHP
			}
			p.Stamina = float32(p.MaxStamina)
			p.BuffActiveUntil = time.Now().Add(30 * time.Second)
			return true, "Digestão Fúngica! Você absorveu a matéria orgânica (+50 HP, Stamina cheia e +25% de dano por 30s)!"
		}
		return false, "Apenas os Esporianos / Myconids possuem flora intestinal para digerir lixo orgânico."

	case protocol.ItemRunicHourglass: // 29: Ampulheta Rúnica (Desperta Raça Secreta 28 Errante Temporal)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceTimeWanderer
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O tempo congela ao seu redor... Você despertou como Errante Temporal (Cronomante)!"

	case protocol.ItemSilverSilkCocoon: // 30: Casulo de Seda Prateada (Desperta Raça Secreta 21 Aracne)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceArachne
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "Fios de seda prateada envolvem seu corpo... Você despertou como Aracne (Tecelão da Bruma)!"
	}

	return false, "Este item não é consumível."
}

func (p *Player) consumeOneItemLocked(itemID uint8) {
	if p.Inventory[itemID] <= 1 {
		delete(p.Inventory, itemID)
	} else {
		p.Inventory[itemID]--
	}
}

// EvolveToRevenant desperta a Raça Secreta 7 (Amaldiçoado das Cinzas / Revenant).
func (p *Player) EvolveToRevenant() {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.RaceID = protocol.RaceRevenant
	p.recalculateStatsLocked()
	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
}

// EvolveToDhampir desperta a Raça Secreta 5 (Dhampir).
func (p *Player) EvolveToDhampir() {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.RaceID = protocol.RaceDhampir
	p.recalculateStatsLocked()
	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
}

// IsWolfPotionActive verifica se a poção de sangue lupino (+20% velocidade/crítico) está ativa.
func (p *Player) IsWolfPotionActive() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Now().Before(p.WolfPotionUntil)
}

// HasLycanHeartEquipped verifica se o jogador possui o Coração do Licantropo Alfa equipado.
func (p *Player) HasLycanHeartEquipped() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.EquippedAccessoryID == protocol.ItemLycanAlphaHeart
}

// IsArmed retorna se o jogador está em prontidão de combate ou realizou ações de ataque recentes.
func (p *Player) IsArmed() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()

	// Se realizou ataque recente (últimos 15 segundos)
	if p.LastActionTimes != nil {
		if lastAtk, ok := p.LastActionTimes[protocol.ActionBasicAttack]; ok && time.Since(lastAtk) < 15*time.Second {
			return true
		}
	}

	// Classes que portam armas ostensivas (Espadachim, Ceifador)
	if p.ClassID == protocol.ClassSwordsman || p.ClassID == protocol.ClassEclipseReaper {
		return true
	}

	return false
}

// AddFriendship incrementa ou decrementa a afiança do jogador com determinado NPC (0 a 100).
func (p *Player) AddFriendship(npcID uint32, amount int) int {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.NPCFriendship == nil {
		p.NPCFriendship = make(map[uint32]int)
	}

	pts := p.NPCFriendship[npcID] + amount
	if pts < 0 {
		pts = 0
	} else if pts > 100 {
		pts = 100
	}
	p.NPCFriendship[npcID] = pts
	return pts
}

// GetFriendship retorna os pontos de afiança com determinado NPC (0 a 100).
func (p *Player) GetFriendship(npcID uint32) int {
	p.Mu.RLock()
	defer p.Mu.RUnlock()

	if p.NPCFriendship == nil {
		return 0
	}
	return p.NPCFriendship[npcID]
}

// GetFriendshipLevel retorna o nível de afiança (0 a 5) com base nos pontos acumulados (0-100).
// 0..19: Nível 0 | 20..39: Nível 1 | 40..59: Nível 2 | 60..79: Nível 3 | 80..99: Nível 4 | 100: Nível 5
func (p *Player) GetFriendshipLevel(npcID uint32) uint8 {
	pts := p.GetFriendship(npcID)
	if pts >= 100 {
		return 5
	}
	if pts < 0 {
		return 0
	}
	return uint8(pts / 20)
}

func (p *Player) unlockRecipeLocked(recipeID uint8) {
	if p.UnlockedRecipes == nil {
		p.UnlockedRecipes = make(map[uint8]bool)
	}
	p.UnlockedRecipes[recipeID] = true
}

// UnlockRecipe registra a receita como desbloqueada pelo jogador.
func (p *Player) UnlockRecipe(recipeID uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.unlockRecipeLocked(recipeID)
}

// HasUnlockedRecipe verifica se o jogador possui a receita desbloqueada.
func (p *Player) HasUnlockedRecipe(recipeID uint8) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()

	if p.UnlockedRecipes == nil {
		return false
	}
	return p.UnlockedRecipes[recipeID]
}
