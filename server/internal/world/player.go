package world

import (
	"fmt"
	"math/rand"
	"net"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
)

// Player representa o estado em memória de um jogador conectado na instância autoritativa.
type Player struct {
	Mu sync.RWMutex

	ID       uint32
	ZoneID   uint8 // Zona instanciada atual (0 a 8)
	TCPConn  net.Conn
	UDPAddr  *net.UDPAddr
	LastSeq  uint32
	PosX     float32
	PosY     float32
	PosZ     float32
	RotY     float32
	LastSeen time.Time

	// Marco 3 & Atualização: Identidade, Classes e Tiers
	RaceID       uint8
	ClassID      uint8
	ClassTier    uint8
	ClassPath    uint8 // 0=Base, 1=Caminho A, 2=Caminho B
	SubPath      uint8 // 1, 2, 3 ou 4 (Caminhos Evolutivos das 12 classes básicas)
	PathTier     uint8 // Tier em que o Caminho atual foi escolhido (subir de Tier libera a troca)
	Level        uint8
	HP           uint16
	MaxHP        uint16
	Stamina      float32
	Mana         float32   // Mana atual (reserva das habilidades mágicas)
	MaxMana      uint16    // Mana máxima (raça, nível, INT, Tier e classe)
	lastSentMana uint16    // Mana enviada no último PLAYER_STATS
	LastCombatAt time.Time // último golpe dado ou recebido (regeneração de Mana fora de combate é maior)
	MaxStamina   uint16
	RaceEvolved  bool // Se já realizou a evolução racial no Nível 10+

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
	Inventory           map[uint8]uint8                // ItemID -> Quantidade
	EquippedSlots       [protocol.EquipSlotCount]uint8 // 14 Slots Reais [0..13] (12 = Mão Principal, 13 = Mão Secundária)
	DiscoveredMaterials map[uint16]bool                // Materiais já vistos pelo jogador (Forja)
	CustomItems         map[uint8]*CustomItem          // Ligas sintéticas e equipamentos forjados (IDs 200-254)
	KnownBlueprints     map[uint8]bool                 // Blueprints avançadas aprendidas (as básicas todos sabem)
	ExclusiveBlueprints []ExclusiveBlueprint           // Desenhos patenteados no Criador Quebra-Cabeça (Soulbound)
	DevForgeAccess      bool                           // Dev: forja e Quebra-Cabeça liberados em qualquer lugar
	ItemUnits           map[uint8][]uint8              // Qualidade de cada unidade da mochila (melhor -> pior)
	EquippedQuality     [protocol.EquipSlotCount]uint8 // Condição de cada item equipado
	EquippedQualitySet  [protocol.EquipSlotCount]bool  // slot com Condição registrada (senão vale a padrão do item)
	newDiscoveries      []uint16                       // Descobertas ainda não avisadas ao cliente
	Gold                uint32                         // Sollares de Ouro
	PKMode              bool                           // Postura Hostil: trava de segurança desligada (pode ferir NPCs)
	WantedTimer         float32                        // segundos restantes como PROCURADO pela Guarda
	BountyGold          uint32                         // recompensa pela cabeça do jogador
	JailUntil           time.Time                      // preso: não age até esta hora
	MurderCount         int                            // NPCs assassinados (para sempre)
	KillStreak          int                            // assassinatos seguidos enquanto procurado
	PermanentWanted     map[uint8]bool                 // cidade -> procurado para sempre

	// Sobrevivência: fome (100 = saciado) e temperatura corporal
	Hunger              float32
	Cold, Heat          float32
	BodyTemp            float32
	AmbientTemp         float32
	survivalInit        bool
	survivalDmg         float32
	EclipseCoins        uint32 // Moedas do Eclipse (Mercado Negro)
	EquippedArmorID     uint8  // Alias Peitoral (EquippedSlots[1]) para retrocompatibilidade
	EquippedAccessoryID uint8  // Alias Acessório/Anel (EquippedSlots[7]) para retrocompatibilidade

	// Mini-game de Autópsia e Proteção contra Mobs
	InAutopsy           bool      // Flag de autópsia ativa
	AutopsyProtectUntil time.Time // Janela de imunidade contra aggro de mobs

	// Histórico Temporal para Cronari (Cronari - Raça 28)
	TimeHistory    []TimeHistorySnapshot
	LastRecordTime time.Time

	// Sistema Universal de Amizade com NPCs (0 a 100) e Receitas Secretas
	NPCFriendship   map[uint32]int        // NPCID -> Pontos de Afiança (0 a 100)
	Social          map[uint32]*NPCSocial // conversas, presentes e favores com cada NPC
	UnlockedRecipes map[uint8]bool        // RecipeID -> Desbloqueada

	// Desafios de Obtenção das Classes Secretas (10 a 15)
	UntouchedKills         int               // Abates sem sofrer dano (Bailarino das Estrelas - Classe 10)
	LowHPKills             int               // Abates com HP <= 30% (Inquisidor da Chama Branca - Classe 11)
	PerfectAutopsiesStreak int               // Sequência de autópsias perfeitas na Zona Verde (Arauto do Ossuário - Classe 12)
	SoloAlphaWolfKilled    bool              // Lobo Alfa derrotado 100% Solo (Senhor da Selva Primordial - Classe 13)
	InvisibleUntil         time.Time         // Invisível: monstros não percebem
	StealthUntil           time.Time         // Furtivo: monstros só percebem de perto
	AmbushReady            bool              // Próximo golpe é de emboscada
	PunchCombo             int               // Socos seguidos do Punho Celeste
	TrialProgress          map[uint8]float32 // Progresso das Provações de Linhagem (raça -> abates/segundos)
	ThorneTrust            int               // Confiança de Thorne: só sobe com presas (+15) e peles de Alfa (+25)
	GarrickQuestStage      uint8             // Missão "O Aprendiz do Ferreiro": 0 = não iniciada, 1..3 = parte atual, 4 = concluída
	TamerUnlocked          bool              // Missão secreta de Thorne concluída: pode aprender Senhor das Feras (Classe 10)
	BlockedBossRupture     bool              // Bloqueou Boss/Executor com CON >= 20 durante Eclipse/Lua de Sangue (Cavaleiro do Vazio - Classe 14)
	PyromancerRevived      bool              // Passiva Chama da Vida (Pyrael - Raça 30)
	AristocratRevivedAt    time.Time         // Passiva Imortalidade do Sangue (Conde Escarlate - Classe 25)

	// Cooldowns das Habilidades
	LastActionTimes map[uint8]time.Time

	// PendingIdentity guarda uma troca de Classe/Raça oferecida pelo servidor (NPC Mestre, Altar,
	// desafio secreto) que só é aplicada depois que o jogador confirma no modal do cliente.
	PendingIdentity *PendingIdentityOffer
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

	// Quadrante 5: 18 Novas Raças do RPG (29 a 46)
	case protocol.RaceHalfCelestial: // 29: Aurelith
		return 8, 8, 8, 8, 9, 11, 7, 7
	case protocol.RacePyromancer: // 30: Pyrael
		return 6, 8, 7, 8, 12, 6, 7, 6
	case protocol.RaceFrostGiant: // 31: Jotunar
		return 14, 4, 15, 4, 6, 6, 9, 4
	case protocol.RaceDragonEarth: // 32: Terravyrn
		return 12, 5, 14, 4, 5, 6, 10, 5
	case protocol.RaceDragonWater: // 33: Hydravyrn
		return 8, 9, 9, 8, 9, 9, 7, 7
	case protocol.RaceDragonLightning: // 34: Fulgravyrn
		return 8, 11, 7, 12, 10, 5, 8, 7
	case protocol.RaceDragonMystic: // 35: Arcavyrn
		return 6, 8, 8, 7, 13, 10, 6, 6
	case protocol.RaceOrc: // 36: Orkhan
		return 13, 6, 13, 6, 3, 3, 9, 5
	case protocol.RaceDwarf: // 37: Dvergar
		return 11, 5, 13, 4, 6, 7, 12, 5
	case protocol.RaceElf: // 38: Elarin
		return 5, 11, 5, 12, 10, 8, 7, 6
	case protocol.RaceSolarElf: // 39: Solarin (Azgher)
		return 6, 10, 6, 10, 11, 10, 7, 7
	case protocol.RaceLunarElf: // 40: Lunarin (Tenebra)
		return 5, 11, 5, 12, 10, 8, 8, 8
	case protocol.RaceFairy: // 41: Faelith
		return 3, 10, 4, 13, 11, 11, 5, 10
	case protocol.RaceGoblin: // 42: Gnarlin
		return 6, 12, 5, 13, 6, 3, 10, 12
	case protocol.RaceScorpionDemi: // 43: Escarion
		return 9, 10, 8, 10, 7, 3, 11, 6
	case protocol.RaceTurtleDemi: // 44: Testudar
		return 9, 4, 16, 3, 6, 8, 9, 5
	case protocol.RaceHalfDemon: // 45: Lilitara
		return 8, 10, 7, 10, 11, 4, 8, 8
	case protocol.RaceWolfDemi: // 46: Ulvar
		return 12, 9, 10, 11, 3, 4, 8, 7
	case protocol.RaceManamancer: // 47: Manamante
		return 3, 6, 8, 6, 13, 11, 7, 4

	default:
		return 6, 6, 6, 6, 6, 6, 7, 7
	}
}

// GetClassBaseAttributes retorna os atributos base concedidos pela classe escolhida.
func GetClassBaseAttributes(classID uint8) (str, dex, con, agi, intStat, spi, mas, lck uint8) {
	switch classID {
	// As 6 Classes Básicas de Combate (IDs 1 a 6)
	case protocol.ClassWarrior: // 1: Espadachim da Aurora (+3 FOR, +1 DES, +3 CON, +1 AGI, +1 ESP, +1 PER)
		return 3, 1, 3, 1, 0, 1, 1, 0
	case protocol.ClassMage: // 2: Arcanista (+1 DES, +1 CON, +1 AGI, +4 INT, +2 ESP, +1 PER)
		return 0, 1, 1, 1, 4, 2, 1, 0
	case protocol.ClassArcher: // 3: Sentinela dos Ventos (+1 FOR, +4 DES, +1 CON, +3 AGI, +1 PER)
		return 1, 4, 1, 3, 0, 0, 1, 0
	case protocol.ClassAssassin: // 4: Lâmina Silente (+2 FOR, +4 DES, +1 CON, +4 AGI, +2 PER, +1 SOR)
		return 2, 4, 1, 4, 0, 0, 2, 1
	case protocol.ClassFighter: // 5: Punho Celeste (+4 FOR, +2 DES, +3 CON, +2 AGI, +2 PER)
		return 4, 2, 3, 2, 0, 0, 2, 0
	case protocol.ClassShieldBearer: // 6: Guardião do Bastião (+3 FOR, +5 CON, +1 AGI, +2 ESP, +2 PER)
		return 3, 0, 5, 1, 0, 2, 2, 0

	// As 6 Classes Básicas de Produção Combatentes (IDs 7 a 12)
	case protocol.ClassBlacksmith: // 7: Forjador de Estrelas (+4 FOR, +4 CON, +2 PER, +1 MAS)
		return 4, 0, 4, 0, 0, 0, 2, 1
	case protocol.ClassAlchemist: // 8: Transmutador (+2 DES, +2 CON, +1 AGI, +3 INT, +1 ESP, +2 PER)
		return 0, 2, 2, 1, 3, 1, 2, 0
	case protocol.ClassSculptor: // 9: Escultor de Almas (+2 FOR, +3 DES, +2 CON, +2 AGI, +2 INT, +3 PER, +1 SOR)
		return 2, 3, 2, 2, 2, 0, 3, 1
	case protocol.ClassTamer: // 10: Senhor das Feras (+3 FOR, +2 DES, +3 CON, +2 AGI, +2 ESP, +2 PER)
		return 3, 2, 3, 2, 0, 2, 2, 0
	case protocol.ClassWarTailor: // 11: Tecelão Carmesim (+1 FOR, +4 DES, +2 CON, +3 AGI, +2 INT, +2 PER)
		return 1, 4, 2, 3, 2, 0, 2, 0
	case protocol.ClassHuntingChef: // 12: Mestre do Banquete (+3 FOR, +2 DES, +4 CON, +1 AGI, +1 INT, +2 PER, +1 SOR)
		return 3, 2, 4, 1, 1, 0, 2, 1

	// Classes Secretas Variantes (IDs 13 a 18 - Tier 3 Raro / Tier 4 Épico)
	case protocol.ClassRunicSpellblade: // 13: Lâmina Rúnica (+4 FOR, +2 DES, +3 CON, +2 AGI, +4 INT, +1 ESP, +3 PER, +1 SOR)
		return 4, 2, 3, 2, 4, 1, 3, 1
	case protocol.ClassVampireHunter: // 14: Inquisidor de Prata (+3 FOR, +5 DES, +2 CON, +4 AGI, +1 INT, +2 ESP, +4 PER, +2 SOR)
		return 3, 5, 2, 4, 1, 2, 4, 2
	case protocol.ClassAegisValkyrie: // 15: Valquíria Celeste (+4 FOR, +1 DES, +6 CON, +2 AGI, +1 INT, +3 ESP, +3 PER, +1 SOR)
		return 4, 1, 6, 2, 1, 3, 3, 1
	case protocol.ClassShadowMonk: // 16: Punho Fantasma (+4 FOR, +4 DES, +3 CON, +5 AGI, +1 INT, +1 ESP, +4 PER, +2 SOR)
		return 4, 4, 3, 5, 1, 1, 4, 2
	case protocol.ClassCursedSmith: // 17: Forjador Carmesim (+5 FOR, +1 DES, +5 CON, +1 AGI, +1 INT, +1 ESP, +4 PER, +3 SOR)
		return 5, 1, 5, 1, 1, 1, 4, 3
	case protocol.ClassPlagueDoctor: // 18: Doutor Corvo (+2 FOR, +3 DES, +4 CON, +2 AGI, +4 INT, +3 ESP, +3 PER, +2 SOR)
		return 2, 3, 4, 2, 4, 3, 3, 2

	// Classes Únicas Exclusivas de Raça (19 a 26)
	case protocol.ClassVorpalExecutioner: // 19: Algoz Vorpal
		return 3, 6, 3, 5, 2, 0, 3, 1
	case protocol.ClassCrimsonWebSovereign: // 20: Senhor da Teia Escarlate
		return 2, 6, 3, 4, 4, 1, 3, 1
	case protocol.ClassBloodPackKing: // 21: Rei-Lobo do Eclipse
		return 6, 3, 4, 5, 0, 2, 3, 1
	case protocol.ClassMountainRunemancer: // 22: Runomante Ancestral
		return 6, 1, 6, 1, 3, 2, 4, 1
	case protocol.ClassWorldBastion: // 23: Colosso Abissal
		return 5, 1, 8, 1, 1, 3, 3, 1
	case protocol.ClassWorldTreeArchfairy: // 24: Arquifada de Yggdra
		return 1, 3, 2, 4, 6, 6, 2, 2
	case protocol.ClassCrimsonAristocrat: // 25: Conde Escarlate
		return 3, 5, 3, 4, 5, 2, 3, 2
	case protocol.ClassScrapBaron: // 26: Barão Engrenagem
		return 3, 5, 4, 3, 3, 0, 3, 5
	// Classes Lendárias (31 a 34)
	case protocol.ClassPagmaDescendant: // 31: Herdeiro da Forja Divina
		return 8, 6, 6, 4, 2, 2, 6, 2
	case protocol.ClassMoonlightSculptor: // 32: Mestre Escultor do Luar
		return 4, 8, 4, 6, 6, 2, 6, 2
	case protocol.ClassDragonMonarch: // 33: Imperador Dracônico
		return 7, 3, 7, 4, 2, 6, 5, 2
	case protocol.ClassBlackSunEmperor: // 34: Soberano do Sol Negro
		return 7, 6, 4, 5, 7, 6, 3, 2
	// Classes Únicas Gerais (27 a 30 e 35 a 39)
	case protocol.ClassEclipseReaper: // 27: Ceifador (Tier 5 Única: +5 FOR, +3 DES, +3 CON, +3 AGI, +2 INT, +3 PER, +1 SOR)
		return 5, 3, 3, 3, 2, 0, 3, 1
	case protocol.ClassRunicArtificer: // 35: Artífice (Tier 5 Única: +4 FOR, +1 DES, +4 CON, +1 AGI, +4 INT, +4 PER, +2 SOR)
		return 4, 1, 4, 1, 4, 0, 4, 2
	case protocol.ClassHomunculusCreator: // 36: Criador (Tier 5 Única: +1 FOR, +1 DES, +3 CON, +1 AGI, +5 INT, +3 ESP, +4 PER, +2 SOR)
		return 1, 1, 3, 1, 5, 3, 4, 2
	case protocol.ClassAstralDancer: // 28: Bailarino das Estrelas (Tier 5 Única: +2 FOR, +6 DES, +2 CON, +6 AGI, +2 INT, +2 PER, +3 SOR)
		return 2, 6, 2, 6, 2, 0, 2, 3
	case protocol.ClassAshInquisitor: // 29: Inquisidor da Chama Branca (Tier 5 Única: +4 FOR, +2 DES, +4 CON, +2 AGI, +3 INT, +5 ESP, +2 PER, +1 SOR)
		return 4, 2, 4, 2, 3, 5, 2, 1
	case protocol.ClassBoneNecromancer: // 30: Arauto do Ossuário (Tier 5 Única: +1 FOR, +2 DES, +3 CON, +1 AGI, +6 INT, +5 ESP, +3 PER, +2 SOR)
		return 1, 2, 3, 1, 6, 5, 3, 2
	case protocol.ClassPrimordialTamer: // 37: Senhor da Selva Primordial (Tier 5 Única: +6 FOR, +3 DES, +5 CON, +4 AGI, +1 INT, +4 ESP, +3 PER, +1 SOR)
		return 6, 3, 5, 4, 1, 4, 3, 1
	case protocol.ClassRiftKnight: // 38: Cavaleiro do Vazio (Tier 5 Única: +5 FOR, +1 DES, +7 CON, +1 AGI, +3 INT, +2 ESP, +3 PER, +1 SOR)
		return 5, 1, 7, 1, 3, 2, 3, 1
	case protocol.ClassStormHerald: // 39: Arauto do Trovão (Tier 5 Única: +2 FOR, +3 DES, +2 CON, +4 AGI, +6 INT, +4 ESP, +3 PER, +3 SOR)
		return 2, 3, 2, 4, 6, 4, 3, 3
	default: // 0: Viajante / Sem Classe
		return 0, 0, 0, 0, 0, 0, 0, 0
	}
}

// ApplyBaseRaceAttributes aplica os atributos iniciais da raça no jogador sem perder bônus de classe ou alocados.
func (p *Player) ApplyBaseRaceAttributes(raceID uint8) {
	p.RaceID = raceID
	p.recalculateStatsLocked()
}

// pathMultipliersLocked retorna os multiplicadores do Caminho Evolutivo ativo (HP, Stamina, Defesa,
// Velocidade, Dano). Valem só nas 12 Classes Básicas, a partir do Tier 2 e com um caminho escolhido.
func (p *Player) pathMultipliersLocked() (hp, stam, def, spd, dmg float32) {
	if p.ClassID < 1 || p.ClassID > 12 || p.ClassTier < protocol.TierUncommon {
		return 1.0, 1.0, 1.0, 1.0, 1.0
	}
	return GetSubPathMultipliers(p.ClassID, p.SubPath)
}

// PathDamageMult retorna o multiplicador de dano do Caminho Evolutivo ativo.
func (p *Player) PathDamageMult() float32 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	_, _, _, _, dmg := p.pathMultipliersLocked()
	return dmg
}

// VariantBaseClasses lista as Classes Básicas que podem despertar cada Variante Secreta (13 a 18).
var VariantBaseClasses = map[uint8][]uint8{
	protocol.ClassRunicSpellblade: {protocol.ClassWarrior, protocol.ClassMage},
	protocol.ClassVampireHunter:   {protocol.ClassArcher, protocol.ClassAssassin},
	protocol.ClassAegisValkyrie:   {protocol.ClassShieldBearer, protocol.ClassWarrior},
	protocol.ClassShadowMonk:      {protocol.ClassFighter, protocol.ClassAssassin},
	protocol.ClassCursedSmith:     {protocol.ClassBlacksmith},
	protocol.ClassPlagueDoctor:    {protocol.ClassAlchemist, protocol.ClassHuntingChef},
}

// VariantMinLevel é o nível mínimo (Tier 3 Raro) para despertar uma Variante Secreta.
const VariantMinLevel = 25

// CanAwakenVariant informa se o jogador pode despertar a Variante Secreta, com o motivo quando não pode.
func (p *Player) CanAwakenVariant(variantID uint8) (bool, string) {
	bases, ok := VariantBaseClasses[variantID]
	if !ok {
		return false, "classe não é uma Variante Secreta"
	}
	p.Mu.RLock()
	classID, level := p.ClassID, p.Level
	p.Mu.RUnlock()
	isBase := false
	for _, b := range bases {
		if b == classID {
			isBase = true
			break
		}
	}
	if !isBase {
		return false, "esta Variante exige outra classe básica de origem"
	}
	if level < VariantMinLevel {
		return false, fmt.Sprintf("é preciso chegar ao nível %d (Tier 3 Raro)", VariantMinLevel)
	}
	return true, ""
}

// NeedsPathChoice informa se o jogador já pode (e ainda não) escolheu o Caminho Evolutivo.
func (p *Player) NeedsPathChoice() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.ClassID >= 1 && p.ClassID <= 12 && p.ClassTier >= protocol.TierUncommon &&
		(p.SubPath == 0 || p.PathTier < p.ClassTier)
}

// ChoosePath define o Caminho Evolutivo (1 a 4) e registra o Tier da escolha.
func (p *Player) ChoosePath(path uint8) {
	p.Mu.Lock()
	p.SubPath = path
	p.ClassPath = path
	p.PathTier = p.ClassTier
	p.Mu.Unlock()
	p.RecalculateStats()
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
	case protocol.TierUnique: // Tier 5 (Única - Secreta): +11 (+11 a +15 pts/nível)
		return 11
	case protocol.TierLegendary: // Tier 6 (Lendária): +15
		return 15
	default:
		return 5
	}
}

// statPointsPerLevelLocked calcula pontos/nível considerando bônus especial das Variantes Secretas (+9 no Épico).
func (p *Player) statPointsPerLevelLocked() uint8 {
	if p.ClassID >= protocol.ClassRunicSpellblade && p.ClassID <= protocol.ClassPlagueDoctor && p.ClassTier == protocol.TierEpic {
		return 9
	}
	return StatPointsPerLevel(p.ClassTier)
}

// StatPointsPerLevel retorna os pontos de status por nível específicos para esta instância de jogador.
func (p *Player) StatPointsPerLevel() uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.statPointsPerLevelLocked()
}

// GetSubPathMultipliers retorna multiplicadores de status (hpMult, stamMult, defMult, spdMult, dmgMult) para o Caminho da Classe.
func GetSubPathMultipliers(classID, subPath uint8) (hpMult, stamMult, defMult, spdMult, dmgMult float32) {
	if classID < 1 || classID > 12 {
		return 1.0, 1.0, 1.0, 1.0, 1.0
	}
	if subPath < 1 || subPath > 4 {
		return 1.0, 1.0, 1.0, 1.0, 1.0 // Caminho ainda não escolhido
	}

	switch classID {
	case protocol.ClassWarrior: // 1: Espadachim da Aurora
		switch subPath {
		case 1: // Gladiador ➔ Senhor da Carnificina (Dano em Área)
			return 1.10, 1.00, 1.05, 0.95, 1.15
		case 2: // Mestre da Lâmina ➔ Santo da Espada (Velocidade/Parry)
			return 0.95, 1.15, 1.00, 1.15, 1.05
		case 3: // Comandante ➔ Lorde da Aurora (Buffs/Defesa)
			return 1.15, 1.00, 1.20, 1.00, 0.95
		case 4: // Berserker ➔ Tirano Carmesim (Roubo de Vida/Frenesi)
			return 0.95, 1.10, 0.90, 1.05, 1.20
		}
	case protocol.ClassMage: // 2: Arcanista
		switch subPath {
		case 1: // Piromante ➔ Arquimago Solar
			return 0.95, 0.90, 0.95, 1.00, 1.25
		case 2: // Criomante ➔ Soberano do Zero Absoluto
			return 1.15, 1.05, 1.20, 0.95, 1.00
		case 3: // Eletromante ➔ Senhor do Trovão
			return 0.90, 1.10, 0.95, 1.15, 1.15
		case 4: // Bruxo do Vazio ➔ Arconte Gravitacional
			return 1.05, 1.20, 1.05, 0.95, 1.10
		}
	case protocol.ClassArcher: // 3: Sentinela dos Ventos
		switch subPath {
		case 1: // Franco-Atirador ➔ Atirador Fantasma
			return 0.90, 1.00, 0.90, 0.95, 1.25
		case 2: // Dançarino do Vento ➔ Tempestade de Flechas
			return 0.95, 1.15, 0.95, 1.20, 1.05
		case 3: // Sentinela dos Ventos Arcano ➔ Sagitário Estelar
			return 0.95, 1.10, 1.00, 1.05, 1.20
		case 4: // Rastreador ➔ Predador de Armadilhas
			return 1.15, 1.10, 1.15, 0.95, 1.00
		}
	case protocol.ClassAssassin: // 4: Lâmina Silente
		switch subPath {
		case 1: // Lâmina da Noite ➔ Ceifador Silencioso
			return 0.90, 1.05, 0.90, 1.10, 1.30
		case 2: // Envenenador ➔ Senhor das Pragas
			return 1.00, 1.15, 1.00, 1.05, 1.15
		case 3: // Retalhador ➔ Turbilhão Carmesim
			return 0.95, 1.10, 0.90, 1.20, 1.20
		case 4: // Shinobi ➔ Espectro de Seis Sombras
			return 0.90, 1.25, 0.95, 1.15, 1.10
		}
	case protocol.ClassFighter: // 5: Punho Celeste
		switch subPath {
		case 1: // Pugilista ➔ Punho de Titã
			return 1.05, 1.10, 1.05, 0.95, 1.25
		case 2: // Monge ➔ Punho Iluminado
			return 1.00, 1.20, 1.10, 1.15, 1.00
		case 3: // Grappler ➔ Rei da Submissão
			return 1.20, 1.05, 1.15, 0.90, 1.05
		case 4: // Brawler Místico ➔ Avatar Marcial
			return 0.95, 1.10, 1.00, 1.10, 1.20
		}
	case protocol.ClassShieldBearer: // 6: Guardião do Bastião
		switch subPath {
		case 1: // Guardião ➔ Égide Imortal
			return 1.30, 1.05, 1.25, 0.90, 0.85
		case 2: // Cruzado de Espinhos ➔ Bastião Sangrento
			return 1.15, 1.00, 1.20, 0.90, 1.05
		case 3: // Juggernaut ➔ Colosso Imparável
			return 1.25, 0.90, 1.15, 0.95, 1.10
		case 4: // Templário ➔ Paladino da Catedral
			return 1.10, 1.10, 1.20, 0.95, 0.90
		}
	case protocol.ClassBlacksmith: // 7: Forjador de Estrelas
		switch subPath {
		case 1: // Mestre Armeiro ➔ Artesão Overgeared
			return 1.05, 1.05, 1.05, 0.95, 1.20
		case 2: // Mestre da Couraça ➔ Aço Inquebrável
			return 1.20, 1.00, 1.30, 0.90, 0.95
		case 3: // Senhor da Fornalha ➔ Titã Vulcânico
			return 1.15, 0.90, 1.10, 0.95, 1.25
		case 4: // Engenheiro Bélico ➔ Artilharia Rúnica
			return 0.95, 1.20, 1.05, 1.00, 1.20
		}
	case protocol.ClassAlchemist: // 8: Transmutador
		switch subPath {
		case 1: // Granadeiro ➔ Arquimago da Detonação
			return 0.90, 1.05, 0.95, 1.00, 1.30
		case 2: // Mestre dos Elixires ➔ Santo da Panaceia
			return 1.05, 1.20, 1.10, 1.05, 0.85
		case 3: // Mutante ➔ Behemoth Químico
			return 1.25, 1.05, 1.10, 0.90, 1.20
		case 4: // Criador de Golems ➔ Senhor das Quimeras
			return 1.10, 1.15, 1.20, 0.95, 0.95
		}
	case protocol.ClassSculptor: // 9: Escultor de Almas
		switch subPath {
		case 1: // Lâmina Escultora ➔ Escultor de Almas da Luz Lunar
			return 0.95, 1.10, 0.90, 1.20, 1.20
		case 2: // Animador ➔ Soberano das Estátuas Vivas
			return 1.15, 1.10, 1.25, 0.95, 0.95
		case 3: // Escultor de Almas Elemental ➔ Mestre da Catástrofe
			return 0.90, 1.10, 0.95, 1.00, 1.25
		case 4: // Monumentalista ➔ Criador de Maravilhas
			return 1.30, 1.00, 1.20, 0.85, 1.00
		}
	case protocol.ClassTamer: // 10: Senhor das Feras
		switch subPath {
		case 1: // Líder de Alcateia ➔ Imperador da Matilha
			return 0.95, 1.10, 1.00, 1.15, 1.25
		case 2: // Senhor das Feras de Gigantes ➔ Senhor das Feras de Titãs
			return 1.20, 1.00, 1.25, 0.90, 1.05
		case 3: // Espadachim da Aurora Simbiótico ➔ Chimeryth Humana
			return 1.25, 0.90, 1.10, 1.00, 1.25
		case 4: // Ginete Selvagem ➔ Cavalaria Mítica
			return 1.05, 1.15, 0.95, 1.25, 1.10
		}
	case protocol.ClassWarTailor: // 11: Tecelão Carmesim
		switch subPath {
		case 1: // Retalhador de Fios ➔ Mestre dos Fios Invisíveis
			return 0.90, 1.10, 0.95, 1.10, 1.25
		case 2: // Titereiro ➔ Arquimago das Marionetes
			return 1.00, 1.20, 0.90, 1.05, 1.15
		case 3: // Bordador Arcano ➔ Tecelão do Véu Celestial
			return 1.20, 1.10, 1.25, 0.95, 0.95
		case 4: // Agulha Fantasma ➔ Pontos de Pressão
			return 0.90, 1.15, 0.90, 1.15, 1.25
		}
	case protocol.ClassHuntingChef: // 12: Mestre do Banquete
		switch subPath {
		case 1: // Açougueiro ➔ Chef Carniceiro Abissal
			return 1.05, 1.05, 0.90, 1.05, 1.30
		case 2: // Mestre Cuca ➔ Deus da Gastronomia
			return 1.10, 1.25, 1.10, 1.00, 0.90
		case 3: // Glutonão ➔ Rei Gourmet Devorador
			return 1.35, 1.05, 1.15, 0.85, 1.00
		case 4: // Mestre da Wok ➔ Cozinha Infernal
			return 0.95, 1.10, 0.95, 1.15, 1.25
		}
	}

	return 1.0, 1.0, 1.0, 1.0, 1.0
}

// CalculateStats calcula MaxHP e MaxStamina considerando Classe, Raça, Tier de Raridade, Nível e SubPath opcional.
func CalculateStats(classID, raceID, classTier, level uint8, subPathOpts ...uint8) (uint16, uint16) {
	if level < 1 {
		level = 1
	}

	var baseHP uint16 = 110
	var baseStamina uint16 = 90

	switch classID {
	case protocol.ClassNone: // 0: Viajante / Sem Classe
		baseHP = 110
		baseStamina = 90
	case protocol.ClassWarrior: // 1: Espadachim da Aurora
		baseHP = 140
		baseStamina = 100
	case protocol.ClassMage: // 2: Arcanista
		baseHP = 95
		baseStamina = 110
	case protocol.ClassArcher: // 3: Sentinela dos Ventos
		baseHP = 105
		baseStamina = 135
	case protocol.ClassAssassin: // 4: Lâmina Silente
		baseHP = 110
		baseStamina = 140
	case protocol.ClassFighter: // 5: Punho Celeste
		baseHP = 135
		baseStamina = 125
	case protocol.ClassShieldBearer: // 6: Guardião do Bastião
		baseHP = 160
		baseStamina = 100
	case protocol.ClassBlacksmith: // 7: Forjador de Estrelas
		baseHP = 155
		baseStamina = 100
	case protocol.ClassAlchemist: // 8: Transmutador
		baseHP = 110
		baseStamina = 120
	case protocol.ClassSculptor: // 9: Escultor de Almas
		baseHP = 120
		baseStamina = 125
	case protocol.ClassTamer: // 10: Senhor das Feras
		baseHP = 135
		baseStamina = 120
	case protocol.ClassWarTailor: // 11: Tecelão Carmesim
		baseHP = 115
		baseStamina = 130
	case protocol.ClassHuntingChef: // 12: Mestre do Banquete
		baseHP = 145
		baseStamina = 115

	// Classes Secretas Variantes (IDs 13 a 18 - Tier 3 Raro / Tier 4 Épico)
	case protocol.ClassRunicSpellblade: // 13: Lâmina Rúnica
		baseHP = 145
		baseStamina = 120
	case protocol.ClassVampireHunter: // 14: Inquisidor de Prata
		baseHP = 135
		baseStamina = 135
	case protocol.ClassAegisValkyrie: // 15: Valquíria Celeste
		baseHP = 165
		baseStamina = 115
	case protocol.ClassShadowMonk: // 16: Punho Fantasma
		baseHP = 140
		baseStamina = 130
	case protocol.ClassCursedSmith: // 17: Forjador Carmesim
		baseHP = 160
		baseStamina = 110
	case protocol.ClassPlagueDoctor: // 18: Doutor Corvo
		baseHP = 135
		baseStamina = 125

	// Classes Únicas Exclusivas de Raça (19 a 26)
	case protocol.ClassVorpalExecutioner: // 19: Algoz Vorpal
		baseHP = 135
		baseStamina = 140
	case protocol.ClassCrimsonWebSovereign: // 20: Senhor da Teia Escarlate
		baseHP = 140
		baseStamina = 130
	case protocol.ClassBloodPackKing: // 21: Rei-Lobo do Eclipse
		baseHP = 170
		baseStamina = 125
	case protocol.ClassMountainRunemancer: // 22: Runomante Ancestral
		baseHP = 185
		baseStamina = 100
	case protocol.ClassWorldBastion: // 23: Colosso Abissal
		baseHP = 210
		baseStamina = 90
	case protocol.ClassWorldTreeArchfairy: // 24: Arquifada de Yggdra
		baseHP = 115
		baseStamina = 150
	case protocol.ClassCrimsonAristocrat: // 25: Conde Escarlate
		baseHP = 150
		baseStamina = 130
	case protocol.ClassScrapBaron: // 26: Barão Engrenagem
		baseHP = 160
		baseStamina = 120
	// Classes Lendárias (31 a 34)
	case protocol.ClassPagmaDescendant: // 31: Herdeiro da Forja Divina
		baseHP = 220
		baseStamina = 160
	case protocol.ClassMoonlightSculptor: // 32: Mestre Escultor do Luar
		baseHP = 190
		baseStamina = 180
	case protocol.ClassDragonMonarch: // 33: Imperador Dracônico
		baseHP = 240
		baseStamina = 150
	case protocol.ClassBlackSunEmperor: // 34: Soberano do Sol Negro
		baseHP = 210
		baseStamina = 170
	// Classes Únicas Gerais (27 a 30 e 35 a 39)
	case protocol.ClassEclipseReaper: // 27: Ceifador
		baseHP = 160
		baseStamina = 110
	case protocol.ClassRunicArtificer: // 35: Engenheiro Rúnico
		baseHP = 150
		baseStamina = 115
	case protocol.ClassHomunculusCreator: // 36: Demiurgo Alquímico
		baseHP = 130
		baseStamina = 125
	case protocol.ClassAstralDancer: // 28: Bailarino das Estrelas
		baseHP = 135
		baseStamina = 140
	case protocol.ClassAshInquisitor: // 29: Inquisidor da Chama Branca
		baseHP = 145
		baseStamina = 115
	case protocol.ClassBoneNecromancer: // 30: Arauto do Ossuário
		baseHP = 130
		baseStamina = 120
	case protocol.ClassPrimordialTamer: // 37: Senhor da Selva Primordial
		baseHP = 165
		baseStamina = 120
	case protocol.ClassRiftKnight: // 38: Cavaleiro do Vazio
		baseHP = 180
		baseStamina = 100
	case protocol.ClassStormHerald: // 39: Arauto do Trovão
		baseHP = 125
		baseStamina = 130
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
	case protocol.RacePrimordialLycanthrope: // 6 (Lupharion)
		modHP = 15 + 80      // +80 MaxHP da evolução Varkai
		modStamina = 10 + 30 // +30 MaxStamina da evolução Varkai
	case protocol.RaceRevenant: // 7 (Cinerion)
		modHP = 10 + 50 // +50 MaxHP do despertar sombrio
		modStamina = 10
	case protocol.RaceCelestine: // 8 (Seraphel)
		modHP = 25
		modStamina = 25
	case protocol.RaceAbyssal: // 9 (Umbryss)
		modHP = 10 + 40
		modStamina = 15 + 15
	case protocol.RaceRunicAutomaton: // 10 (Runaric)
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
	case protocol.RaceMyconid: // 20 (Myconid)
		modHP = 35
		modStamina = 10
	case protocol.RaceArachne: // 21 (Aracne)
		modHP = 15
		modStamina = 25
	case protocol.RaceAshDragonborn: // 22 (Ignivarn)
		modHP = 50
		modStamina = 15
	case protocol.RaceChimera: // 23 (Chimeryth)
		modHP = 30
		modStamina = 25
	case protocol.RaceBoreal: // 24 (Borealin)
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
	case protocol.RaceTimeWanderer: // 28 (Cronari)
		modHP = 20
		modStamina = 40

	// Quadrante 5: 18 Novas Raças do RPG (29 a 46)
	case protocol.RaceHalfCelestial: // 29: Aurelith
		modHP = 35
		modStamina = 25
	case protocol.RacePyromancer: // 30: Pyrael
		modHP = 20
		modStamina = 30
	case protocol.RaceFrostGiant: // 31: Jotunar
		modHP = 85
		modStamina = 10
	case protocol.RaceDragonEarth: // 32: Terravyrn
		modHP = 75
		modStamina = 15
	case protocol.RaceDragonWater: // 33: Hydravyrn
		modHP = 35
		modStamina = 35
	case protocol.RaceDragonLightning: // 34: Fulgravyrn
		modHP = 30
		modStamina = 45
	case protocol.RaceDragonMystic: // 35: Arcavyrn
		modHP = 25
		modStamina = 40
	case protocol.RaceOrc: // 36: Orkhan
		modHP = 70
		modStamina = 20
	case protocol.RaceDwarf: // 37: Dvergar
		modHP = 65
		modStamina = 15
	case protocol.RaceElf: // 38: Elarin
		modHP = 15
		modStamina = 35
	case protocol.RaceSolarElf: // 39: Solarin (Azgher)
		modHP = 20
		modStamina = 35
	case protocol.RaceLunarElf: // 40: Lunarin (Tenebra)
		modHP = 20
		modStamina = 40
	case protocol.RaceFairy: // 41: Faelith
		modHP = 10
		modStamina = 50
	case protocol.RaceGoblin: // 42: Gnarlin
		modHP = 15
		modStamina = 45
	case protocol.RaceScorpionDemi: // 43: Escarion
		modHP = 35
		modStamina = 30
	case protocol.RaceTurtleDemi: // 44: Testudar
		modHP = 90
		modStamina = 10
	case protocol.RaceHalfDemon: // 45: Lilitara
		modHP = 30
		modStamina = 35
	case protocol.RaceWolfDemi: // 46: Ulvar
		modHP = 50
		modStamina = 35
	case protocol.RaceManamancer: // 47: Manamante (Sangue Azul: Vida e Mana são uma só reserva)
		modHP = 60
		modStamina = 10
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

	if classTier >= protocol.TierUncommon && len(subPathOpts) > 0 {
		hpM, stamM, _, _, _ := GetSubPathMultipliers(classID, subPathOpts[0])
		finalHP = uint16(float32(finalHP) * hpM)
		finalStam = uint16(float32(finalStam) * stamM)
	}

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

	tb := TranscendenceBonus(p.ClassID)
	cSTR += tb[0]
	cDEX += tb[1]
	cCON += tb[2]
	cAGI += tb[3]
	cINT += tb[4]
	cSPI += tb[5]
	cMAS += tb[6]
	cLCK += tb[7]
	p.STR = rSTR + cSTR + p.AllocSTR
	p.DEX = rDEX + cDEX + p.AllocDEX
	p.CON = rCON + cCON + p.AllocCON
	p.AGI = rAGI + cAGI + p.AllocAGI
	p.INT = rINT + cINT + p.AllocINT
	p.SPI = rSPI + cSPI + p.AllocSPI
	p.MAS = rMAS + cMAS + p.AllocMAS
	p.LCK = rLCK + cLCK + p.AllocLCK

	oldMaxMana := p.MaxMana
	_, _, _, _, totalINT, _, _, _ := p.getAttributesLocked() // INT com equipamentos
	p.MaxMana = CalculateMaxMana(p.RaceID, p.ClassID, p.ClassTier, p.Level, totalINT)
	if oldMaxMana == 0 || p.Mana > float32(p.MaxMana) {
		p.Mana = float32(p.MaxMana) // primeira vez (ou máximo menor): enche/limita
	}

	baseMaxHP, baseMaxStam := CalculateStats(p.ClassID, p.RaceID, p.ClassTier, p.Level, p.SubPath)

	// Bônus de MaxHP e MaxStamina acumulados dos 12 slots de equipamento
	effCONBonus := p.AllocCON
	effAGIBonus := p.AllocAGI
	var directHPBonus uint16 = 0

	for slotIdx, itemID := range p.EquippedSlots {
		if itemID == 0 {
			continue
		}
		info := p.itemInfoLocked(itemID)
		directHPBonus += uint16(float32(info.BonusHP)*qualityStatMult(p.slotQualityLocked(uint8(slotIdx))) + 0.5)
		effCONBonus += info.BonusCON
		effAGIBonus += info.BonusAGI
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
		ID:                  id,
		ZoneID:              ZoneVillage,
		TCPConn:             tcpConn,
		PosX:                initX,
		PosY:                initY,
		PosZ:                initZ,
		RotY:                0,
		LastSeen:            time.Now(),
		RaceID:              initRace,
		ClassID:             initClass,
		ClassTier:           initTier,
		ClassPath:           0,
		SubPath:             0, // Caminho escolhido no Tier 2 (0 = ainda não escolhido)
		Level:               initLevel,
		XP:                  0,
		NextLevelXP:         100,
		StatPoints:          0,
		Inventory:           make(map[uint8]uint8),
		Gold:                StartingGold,
		DiscoveredMaterials: startingDiscoveries(),
		EclipseCoins:        StartingEclipseCoins,
		NPCFriendship:       make(map[uint32]int),
		UnlockedRecipes:     make(map[uint8]bool),
		LastActionTimes:     make(map[uint8]time.Time),
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

// checkLevelMilestoneTierEvolutionLocked atualiza o Tier das 12 Classes Básicas (1 a 12) e Variantes (13 a 18) nos marcos de nível 10, 25 e 45 mantendo o nível.
func (p *Player) checkLevelMilestoneTierEvolutionLocked() {
	if p.ClassID >= 1 && p.ClassID <= 12 {
		if p.Level >= 45 && p.ClassTier < protocol.TierEpic {
			p.ClassTier = protocol.TierEpic
		} else if p.Level >= 25 && p.ClassTier < protocol.TierRare {
			p.ClassTier = protocol.TierRare
		} else if p.Level >= 10 && p.ClassTier < protocol.TierUncommon {
			p.ClassTier = protocol.TierUncommon
		} else if p.Level >= 1 && p.ClassTier == protocol.TierTraveler {
			p.ClassTier = protocol.TierCommon
		}
	} else if p.ClassID >= protocol.ClassRunicSpellblade && p.ClassID <= protocol.ClassPlagueDoctor {
		if p.Level >= 45 && p.ClassTier < protocol.TierEpic {
			p.ClassTier = protocol.TierEpic
		} else if p.ClassTier < protocol.TierRare {
			p.ClassTier = protocol.TierRare
		}
	}
}

// SetIdentityMode processa a seleção ou evolução de classe conforme o ActionMode (0, 1, 2, 3, 98) e SubPath opcional.
func (p *Player) SetIdentityMode(raceID, classID, actionMode uint8, subPathOpts ...uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	prevClass := p.ClassID

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
			if p.ClassID >= protocol.ClassRunicSpellblade && p.ClassID <= protocol.ClassPlagueDoctor {
				// Variante Secreta (13 a 18): NÃO reseta o nível, entra no Tier Raro se for menor
				if p.ClassTier < protocol.TierRare {
					p.ClassTier = protocol.TierRare
				}
			} else if p.ClassTier == protocol.TierTraveler {
				p.ClassTier = protocol.TierCommon
			}
			p.checkLevelMilestoneTierEvolutionLocked()
		} else if classID == 0 {
			p.ClassID = protocol.ClassNone
			p.ClassTier = protocol.TierTraveler
		}
		if p.Level == 0 {
			p.Level = 1
		}

	case protocol.IdentityModeEvolveClass: // 1: Evoluir Classe
		// Se for Classe Base (1 a 12) e ClassTier < 4: sobe Tier mantendo nível
		if p.ClassID >= 1 && p.ClassID <= 12 {
			if p.ClassTier < protocol.TierEpic {
				p.ClassTier++
			}
		} else if p.ClassID >= protocol.ClassRunicSpellblade && p.ClassID <= protocol.ClassPlagueDoctor {
			// Variantes Secretas (13 a 18): evolui até Tier 4 Épico mantendo nível
			if p.ClassTier < protocol.TierEpic {
				p.ClassTier = protocol.TierEpic
			}
		}
		// Classes Únicas (Tier 5) e Lendárias (Tier 6) não evoluem: o Tier é fixo
		if raceID >= 11 {
			p.RaceID = raceID
			p.RaceEvolved = true
			p.ApplyBaseRaceAttributes(raceID)
		}

	case protocol.IdentityModeSecretReset: // 2: Trocar para Classe Secreta (Únicas/Lendárias resetam o nível logo abaixo)
		if protocol.IsTranscendentClass(classID) {
			p.ClassID = classID
			if raceID > 0 {
				p.RaceID = raceID
			}
		} else if classID >= protocol.ClassRunicSpellblade && classID <= protocol.ClassPlagueDoctor {
			// Variantes Secretas (13 a 18): NÃO RESETAM O NÍVEL
			p.ClassID = classID
			if raceID > 0 {
				p.RaceID = raceID
			}
			if p.ClassTier < protocol.TierRare {
				p.ClassTier = protocol.TierRare
			}
			p.checkLevelMilestoneTierEvolutionLocked()
		}

	case protocol.IdentityModeTrainLevel5: // 3: Treinar / +5 Níveis para Teste
		for i := 0; i < 5; i++ {
			p.Level++
			p.checkLevelMilestoneTierEvolutionLocked()
			p.StatPoints += p.statPointsPerLevelLocked()
		}
		p.NextLevelXP = 100 + uint16(p.Level-1)*50

	case protocol.IdentityModeDevDirect: // 98: Ajuste Direto via Menu Dev (Classes 1..39, Tiers 1..6; Únicas/Lendárias têm Tier fixo)
		if classID >= 1 && classID <= protocol.ClassMaxID {
			p.ClassID = classID
			if raceID >= 1 && raceID <= 6 {
				p.ClassTier = raceID
			} else if p.ClassTier == 0 {
				p.ClassTier = protocol.TierCommon
			}
		}
	}

	// Regra autoritativa das Classes Únicas (Tier 5) e Lendárias (Tier 6): ao assumir uma delas,
	// em qualquer modo, o personagem volta ao nível 1 e reconstrói os atributos.
	if protocol.IsTranscendentClass(p.ClassID) {
		if p.ClassID != prevClass {
			p.transcendLocked()
		}
		p.ClassTier = TranscendentTier(p.ClassID)
	}

	// Caminho Evolutivo: só nas 12 Classes Básicas; trocar de classe exige escolher de novo.
	// SubPath 0 no pacote = manter o caminho atual.
	if p.ClassID != prevClass || p.ClassID < 1 || p.ClassID > 12 {
		p.SubPath = 0
		p.PathTier = 0
	}
	if len(subPathOpts) > 0 && subPathOpts[0] >= 1 && subPathOpts[0] <= 4 && p.ClassID >= 1 && p.ClassID <= 12 {
		p.SubPath = subPathOpts[0]
		p.PathTier = p.ClassTier
	}

	p.recalculateStatsLocked()

	if p.HP > p.MaxHP || actionMode == protocol.IdentityModeInitialChange || actionMode == protocol.IdentityModeSecretReset || actionMode == protocol.IdentityModeTrainLevel5 || actionMode == protocol.IdentityModeDevDirect {
		p.HP = p.MaxHP
	}
	if p.Stamina > float32(p.MaxStamina) || actionMode == protocol.IdentityModeInitialChange || actionMode == protocol.IdentityModeSecretReset || actionMode == protocol.IdentityModeTrainLevel5 || actionMode == protocol.IdentityModeDevDirect {
		p.Stamina = float32(p.MaxStamina)
	}
	if p.Mana > float32(p.MaxMana) || actionMode == protocol.IdentityModeInitialChange || actionMode == protocol.IdentityModeSecretReset || actionMode == protocol.IdentityModeTrainLevel5 || actionMode == protocol.IdentityModeDevDirect {
		p.Mana = float32(p.MaxMana)
	}
}

// PendingIdentityOffer é uma troca de identidade aguardando a confirmação do jogador.
type PendingIdentityOffer struct {
	RaceID   uint8
	ClassID  uint8
	Mode     uint8
	CostItem uint8 // item consumido só quando o jogador confirma (0 = nenhum)
	Expires  time.Time
}

// IdentityOfferTTL é quanto tempo uma oferta de troca de Classe/Raça espera pela confirmação.
const IdentityOfferTTL = 2 * time.Minute

// OfferIdentity registra uma troca de Classe/Raça pendente (substitui qualquer oferta anterior).
// costItem opcional: item que só é consumido quando o jogador confirma.
func (p *Player) OfferIdentity(raceID, classID, mode uint8, costItem ...uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	offer := &PendingIdentityOffer{RaceID: raceID, ClassID: classID, Mode: mode, Expires: time.Now().Add(IdentityOfferTTL)}
	if len(costItem) > 0 {
		offer.CostItem = costItem[0]
	}
	p.PendingIdentity = offer
}

// AcceptIdentityOffer aplica a oferta pendente se ela ainda vale e corresponde ao que o jogador confirmou.
// targetID é a Classe confirmada (ou a Raça, quando a oferta só troca a raça).
func (p *Player) AcceptIdentityOffer(targetID uint8) bool {
	p.Mu.Lock()
	offer := p.PendingIdentity
	p.PendingIdentity = nil
	p.Mu.Unlock()
	if offer == nil || time.Now().After(offer.Expires) {
		return false
	}
	if targetID != offer.ClassID && !(offer.ClassID == 0 && targetID == offer.RaceID) {
		return false
	}
	if offer.CostItem != 0 && !p.RemoveItem(offer.CostItem, 1) {
		return false // o item de custo não está mais na mochila
	}
	p.SetIdentityMode(offer.RaceID, offer.ClassID, offer.Mode)
	return true
}

// SetIdentity mantém compatibilidade chamando SetIdentityMode com ActionMode 0.
func (p *Player) SetIdentity(raceID, classID uint8) {
	p.SetIdentityMode(raceID, classID, protocol.IdentityModeInitialChange)
}

// AddLevel incrementa o nível do jogador e recalcula os atributos conforme o ClassTier.
func (p *Player) AddLevel(amount uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	for i := uint8(0); i < amount; i++ {
		p.Level++
		p.checkLevelMilestoneTierEvolutionLocked()
		p.StatPoints += p.statPointsPerLevelLocked()
	}
	p.NextLevelXP = 100 + uint16(p.Level-1)*50
	oldMaxHP := p.MaxHP
	oldMaxMana := p.MaxMana
	p.recalculateStatsLocked()
	if p.MaxHP > oldMaxHP {
		p.HP += (p.MaxHP - oldMaxHP)
	}
	if p.MaxMana > oldMaxMana {
		p.Mana += float32(p.MaxMana - oldMaxMana)
	}
	if p.HP > p.MaxHP {
		p.HP = p.MaxHP
	}
}

// DevControlLevelAndStats processa comandos de desenvolvimento para nível e atributos (CommandType 8).
// - Value 1: Sobe +1 Nível com os StatPoints do Tier atual.
// - Value 5: Sobe +5 Níveis com os StatPoints do Tier atual.
// - Value 50: Define Level = 50 (Nível Máximo).
// - Value 99: Restaura 100% de HP/Stamina e concede +20 StatPoints livres.
// - Value 0: Reseta Level = 1 e todos os atributos alocados.
func (p *Player) DevControlLevelAndStats(val uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	switch val {
	case 1:
		p.Level++
		p.checkLevelMilestoneTierEvolutionLocked()
		pts := StatPointsPerLevel(p.ClassTier)
		if uint16(p.StatPoints)+uint16(pts) > 255 {
			p.StatPoints = 255
		} else {
			p.StatPoints += pts
		}
		p.NextLevelXP = 100 + uint16(p.Level-1)*50
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)

	case 5:
		for i := 0; i < 5; i++ {
			p.Level++
			p.checkLevelMilestoneTierEvolutionLocked()
			pts := StatPointsPerLevel(p.ClassTier)
			if uint16(p.StatPoints)+uint16(pts) > 255 {
				p.StatPoints = 255
			} else {
				p.StatPoints += pts
			}
		}
		p.NextLevelXP = 100 + uint16(p.Level-1)*50
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)

	case 50:
		if p.Level < 50 {
			for p.Level < 50 {
				p.Level++
				p.checkLevelMilestoneTierEvolutionLocked()
				pts := uint16(StatPointsPerLevel(p.ClassTier))
				if uint16(p.StatPoints)+pts > 255 {
					p.StatPoints = 255
				} else {
					p.StatPoints += uint8(pts)
				}
			}
		} else {
			p.Level = 50
		}
		p.XP = 0
		p.NextLevelXP = 100 + uint16(50-1)*50
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)

	case 99:
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		if p.StatPoints > 235 {
			p.StatPoints = 255
		} else {
			p.StatPoints += 20
		}

	case 0:
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
		p.checkLevelMilestoneTierEvolutionLocked()
		p.StatPoints += p.statPointsPerLevelLocked()
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
	return p.AllocateStats(statID, 1) > 0
}

// AllocateStats aplica Amount pontos de uma vez no atributo (limitado aos StatPoints disponíveis).
// Retorna quantos pontos foram realmente aplicados.
func (p *Player) AllocateStats(statID uint8, amount uint16) uint16 {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if amount == 0 {
		amount = 1
	}
	if amount > uint16(p.StatPoints) {
		amount = uint16(p.StatPoints)
	}
	if amount == 0 {
		return 0
	}

	var target *uint8
	switch statID {
	case protocol.StatIDSTR: // 1: Força (+5 kg de carga)
		target = &p.AllocSTR
	case protocol.StatIDDEX: // 2: Destreza
		target = &p.AllocDEX
	case protocol.StatIDCON: // 3: Constituição (+18 MaxHP, +2.5 kg de carga)
		target = &p.AllocCON
	case protocol.StatIDAGI: // 4: Agilidade (+8 MaxStamina)
		target = &p.AllocAGI
	case protocol.StatIDINT: // 5: Inteligência
		target = &p.AllocINT
	case protocol.StatIDSPI: // 6: Espírito
		target = &p.AllocSPI
	case protocol.StatIDMAS: // 7: Perícia
		target = &p.AllocMAS
	case protocol.StatIDLCK: // 8: Sorte
		target = &p.AllocLCK
	default:
		return 0
	}
	if room := uint16(255 - *target); amount > room {
		amount = room // atributos são uint8
	}
	if amount == 0 {
		return 0
	}
	*target += uint8(amount)

	p.StatPoints -= uint8(amount)
	oldMaxHP := p.MaxHP
	oldMaxMana := p.MaxMana
	p.recalculateStatsLocked()
	if p.MaxHP > oldMaxHP {
		p.HP += (p.MaxHP - oldMaxHP)
	}
	if p.MaxMana > oldMaxMana {
		p.Mana += float32(p.MaxMana - oldMaxMana)
	}
	if p.HP > p.MaxHP {
		p.HP = p.MaxHP
	}
	if p.Stamina > float32(p.MaxStamina) {
		p.Stamina = float32(p.MaxStamina)
	}
	return amount
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

	// Bônus dos 14 Slots de Equipamento (catálogo de itens)
	for _, itemID := range p.EquippedSlots {
		if itemID == 0 {
			continue
		}
		info := p.itemInfoLocked(itemID)
		str += info.BonusSTR
		dex += info.BonusDEX
		con += info.BonusCON
		agi += info.BonusAGI
		intStat += info.BonusINT
		spi += info.BonusESP
		mas += info.BonusMAS
		lck += info.BonusLCK
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

// EvolveToPrimordialLycanthrope evolui a raça do jogador para Lupharion (RaceID = 6),
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
	case protocol.ActionDodgeRoll: // 2: Esquiva (cd 0.9s: o rolamento dura 0,35s + recuperação)
		cd = 900 * time.Millisecond
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
	p.Mana = float32(p.MaxMana)
	p.PosX = safeX
	p.PosY = safeY
	p.PosZ = safeZ
	p.IFrameUntil = time.Now().Add(2 * time.Second)
	p.RespawnLockUntil = time.Now().Add(1 * time.Second)
	p.PyromancerRevived = false

	// Na Provação Lendária, a morte reseta a contagem de abates de elites (sem morrer)
	if p.LegendaryQuestActive {
		p.LegendaryQuestKills = 0
	}
}

// RestoreStamina recupera estamina instantaneamente até o limite MaxStamina.
// SpendHPPercent consome uma fração da Vida máxima como custo de habilidade (nunca mata: mínimo 1 HP).
// Retorna false, sem gastar nada, se a Vida atual não cobrir o custo.
func (p *Player) SpendHPPercent(pct float32) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	cost := uint16(float32(p.MaxHP) * pct)
	if cost == 0 || p.HP <= cost {
		return false
	}
	p.HP -= cost
	return true
}

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

	p.Stamina += baseRegenRate * p.staminaRegenMultLocked() * dt
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

	p.LastCombatAt = time.Now()

	// Se estiver invulnerável (Dodge Roll ou pós-respawn), ignora dano
	if time.Now().Before(p.IFrameUntil) {
		return p.HP, false
	}

	// Defesa dos equipamentos (DEF): reduz o dano de forma fixa, nunca abaixo de 1
	if def := p.equipDEFLocked(); def > 0 && amount > 0 {
		if amount > def {
			amount -= def
		} else {
			amount = 1
		}
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

	// Passiva Terravyrn (Couraça Ancestral): reduz dano em 35%
	if p.RaceID == protocol.RaceDragonEarth && amount > 0 {
		amount = uint16(float32(amount) * 0.65)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Orkhan (Músculos de Aço): reduz dano em 20%
	if p.RaceID == protocol.RaceOrc && amount > 0 {
		amount = uint16(float32(amount) * 0.80)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Testudar (Armadura Orgânica): reduz dano em 45%
	if p.RaceID == protocol.RaceTurtleDemi && amount > 0 {
		amount = uint16(float32(amount) * 0.55)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Lilitara (Aparência Inofensiva): 25% de chance de anular o ataque
	if p.RaceID == protocol.RaceHalfDemon && rand.Float32() < 0.25 {
		return p.HP, false
	}

	// Caminho Evolutivo: defesa maior reduz o dano recebido, menor aumenta (ex.: 1.25 -> dano / 1.25)
	if _, _, def, _, _ := p.pathMultipliersLocked(); def != 1.0 && amount > 0 {
		amount = uint16(float32(amount) / def)
		if amount == 0 {
			amount = 1
		}
	}

	// Passivas das Classes Únicas: Arquifada esquiva 35%; Runomante -40%, Bastião -30% e Barão -20% de dano
	if p.ClassID == protocol.ClassWorldTreeArchfairy && amount > 0 && rand.Float32() < 0.35 {
		return p.HP, false // Miragem Feérica
	}
	if reduction := uniqueDamageTakenMult(p.ClassID); reduction < 1.0 && amount > 0 {
		amount = uint16(float32(amount) * reduction)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Doutor Corvo (Imunidade & Cura Tóxica): -15% de dano recebido
	if p.ClassID == protocol.ClassPlagueDoctor && amount > 0 {
		amount = uint16(float32(amount) * 0.85)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Lâmina Silente (Lâmina Silenciosa): 15% de chance de esquivar do golpe
	if p.ClassID == protocol.ClassAssassin && amount > 0 && rand.Float32() < 0.15 {
		return p.HP, false
	}

	// Passiva Espadachim da Aurora (Sangue de Batalha): +15% de Defesa Física
	if p.ClassID == protocol.ClassWarrior && amount > 0 {
		amount = uint16(float32(amount) * 0.85)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Guardião do Bastião (Fortaleza Viva): +35% de Defesa Total (o reflexo de 20% é aplicado em handleMobAttack)
	if p.ClassID == protocol.ClassShieldBearer && amount > 0 {
		amount = uint16(float32(amount) * 0.65)
		if amount == 0 {
			amount = 1
		}
	}

	// Passiva Cavaleiro do Vazio (Classe 14): reduz todo dano recebido em 30%
	if p.ClassID == protocol.ClassRiftKnight && amount > 0 {
		amount = uint16(float32(amount) * 0.70)
		if amount == 0 {
			amount = 1
		}
	}

	if amount > 0 {
		// Ao sofrer qualquer dano, zera a sequência de abates intocados (Bailarino das Estrelas)
		p.UntouchedKills = 0
	}

	if amount >= p.HP {
		// Passiva Pyrael (Chama da Vida): revive 1x com 50% HP virando chama
		if p.RaceID == protocol.RacePyromancer && !p.PyromancerRevived {
			p.PyromancerRevived = true
			p.HP = p.MaxHP / 2
			p.IFrameUntil = time.Now().Add(2 * time.Second)
			p.BuffActiveUntil = time.Now().Add(10 * time.Second)
			return p.HP, false
		}
		// Passiva Conde Escarlate (Imortalidade do Sangue): volta com 30% de Vida, a cada 10 minutos
		if p.ClassID == protocol.ClassCrimsonAristocrat && time.Since(p.AristocratRevivedAt) >= AristocratReviveCooldown {
			p.AristocratRevivedAt = time.Now()
			p.HP = p.MaxHP * 30 / 100
			p.IFrameUntil = time.Now().Add(1500 * time.Millisecond)
			return p.HP, false
		}
		p.HP = 0
		return 0, true
	}
	p.HP -= amount
	return p.HP, false
}

// AristocratReviveCooldown é a recarga da Imortalidade do Sangue do Conde Escarlate.
const AristocratReviveCooldown = 10 * time.Minute

// UpdateFromMove atualiza posição, rotação e endereço UDP caso o Seq seja estritamente superior ao LastSeq.
func (p *Player) UpdateFromMove(seq uint32, posX, posY, posZ, rotY float32, addr *net.UDPAddr) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.LastSeq != 0 && seq <= p.LastSeq {
		return false
	}

	p.LastSeq = seq
	// Sobrecarregado (130%+ do peso máximo): imóvel no plano até soltar itens no chão
	if p.weightSpeedLocked() > 0 {
		p.PosX = posX
		p.PosZ = posZ
	}
	p.PosY = posY
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

// GetZone retorna o ZoneID atual do jogador de forma thread-safe.
func (p *Player) GetZone() uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.ZoneID
}

// SetZone define o ZoneID do jogador de forma thread-safe.
func (p *Player) SetZone(zoneID uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.ZoneID = zoneID
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
		SubPath:     p.SubPath,
		Mana:        uint16(p.Mana),
		MaxMana:     p.MaxMana,
	}
}

// AddItem adiciona itens à mochila do jogador.
func (p *Player) AddItem(itemID, qty uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.Inventory == nil {
		p.Inventory = make(map[uint8]uint8)
	}
	p.markDiscoveredLocked(itemID) // primeiro contato com um material
	if int(p.Inventory[itemID])+int(qty) > 255 {
		p.Inventory[itemID] = 255
		return
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
	p.Mu.Lock()
	defer p.Mu.Unlock()
	slots := make([]protocol.InventorySlot, 0, len(p.Inventory))
	for id := uint8(1); id <= 255; id++ {
		if qty, exists := p.Inventory[id]; exists && qty > 0 {
			// Uma entrada por Qualidade: cada unidade mantém a sua
			units := p.unitsLocked(id)
			for i := 0; i < len(units); {
				j := i
				for j < len(units) && units[j] == units[i] {
					j++
				}
				slots = append(slots, protocol.InventorySlot{ItemID: id, Quantity: uint8(j - i), Quality: units[i]})
				i = j
			}
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

// GetEquippedSlots retorna uma cópia dos 14 slots equipados thread-safe.
func (p *Player) GetEquippedSlots() [protocol.EquipSlotCount]uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.EquippedSlots
}

// getSlotForItem retorna o slot padrão (0..13) do catálogo e se o item é equipável.
func getSlotForItem(itemID uint8) (uint8, bool) {
	info, ok := ItemCatalog[itemID]
	if !ok || info.Slot == NoSlot {
		return 255, false
	}
	return info.Slot, true
}

// IsEquippable informa se o item ocupa algum dos 14 slots.
func IsEquippable(itemID uint8) bool {
	_, ok := getSlotForItem(itemID)
	return ok
}

// EquipItem vincula um item aos 12 slots de equipamento.
// Anéis preenchem os slots 7..10; se todos estiverem ocupados, rotacionam substituindo o mais antigo.
func (p *Player) EquipItem(itemID uint8) (bool, string) {
	return p.EquipItemQuality(itemID, AnyQuality)
}

// EquipItemQuality equipa a unidade do item com a Qualidade pedida (AnyQuality = a melhor).
// O item que sai do slot volta para a mochila com a Condição que tinha.
func (p *Player) EquipItemQuality(itemID, quality uint8) (bool, string) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.Inventory == nil || p.Inventory[itemID] == 0 {
		return false, "Item não encontrado no inventário."
	}

	slot, ok := p.slotForItemLocked(itemID)
	if !ok {
		return false, "Este item não pode ser equipado."
	}

	// Caso especial: Anéis ocupam os slots 8, 9, 10 ou 11
	if slot == protocol.SlotRing1 {
		targetSlot := -1
		for _, s := range []int{8, 9, 10, 11} {
			if p.EquippedSlots[s] == 0 {
				targetSlot = s
				break
			}
		}
		if targetSlot != -1 {
			p.EquippedSlots[targetSlot] = itemID
		} else {
			// Rotação autoritativa: devolve o anel mais antigo (slot 8) e rotaciona os anéis
			oldRing, oldQ := p.EquippedSlots[8], p.slotQualityLocked(8)
			for s := 8; s < 11; s++ {
				p.EquippedSlots[s] = p.EquippedSlots[s+1]
				p.EquippedQuality[s], p.EquippedQualitySet[s] = p.EquippedQuality[s+1], p.EquippedQualitySet[s+1]
			}
			p.EquippedSlots[11] = itemID
			targetSlot = 11
			p.addUnitsLocked(oldRing, 1, oldQ)
		}
		q, _ := p.takeUnitLocked(itemID, quality)
		p.setSlotQualityLocked(uint8(targetSlot), q)
		p.EquippedAccessoryID = itemID
		p.recalculateStatsLocked()
		return true, "Anel equipado com sucesso."
	}

	// Demais slots fixos
	old := p.EquippedSlots[slot]
	oldQ := p.slotQualityLocked(slot)
	q, _ := p.takeUnitLocked(itemID, quality)
	if old > 0 {
		p.addUnitsLocked(old, 1, oldQ)
	}
	p.EquippedSlots[slot] = itemID
	p.setSlotQualityLocked(slot, q)
	if slot == protocol.SlotChest {
		p.EquippedArmorID = itemID
	} else if slot == protocol.SlotAmulet || slot == protocol.SlotGloves {
		p.EquippedAccessoryID = itemID
	}
	p.recalculateStatsLocked()
	return true, "Equipamento vinculado com sucesso."
}

// UnequipSlot desequipa o item de um slot específico (0 a 13) e devolve à mochila.
func (p *Player) UnequipSlot(slotIdx uint8) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if int(slotIdx) >= protocol.EquipSlotCount || p.EquippedSlots[slotIdx] == 0 {
		return false
	}
	if p.Inventory == nil {
		p.Inventory = make(map[uint8]uint8)
	}
	old := p.EquippedSlots[slotIdx]
	p.addUnitsLocked(old, 1, p.slotQualityLocked(slotIdx)) // volta com a Condição que tinha
	p.EquippedSlots[slotIdx] = 0
	p.EquippedQualitySet[slotIdx] = false
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

// DevSetRaceAndKit define qualquer raça (1 a 28) e equipa um kit de teste com os 12 slots reais.
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
	p.EquippedQualitySet = [protocol.EquipSlotCount]bool{} // kit novo: Condição perfeita
	p.EquippedSlots[protocol.SlotMainHand] = protocol.ItemIronLongsword
	p.EquippedSlots[protocol.SlotOffHand] = protocol.ItemTowerShield

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

// RewindTimeDestiny restaura o jogador para 3 segundos atrás (Skill Z do Cronari).
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
	case uint8(MatGameMeat): // Carne de Caça crua: mata a fome e cura um pouco
		p.consumeOneItemLocked(itemID)
		p.feedLocked(itemID)
		p.HP = min(p.MaxHP, p.HP+25)
		return true, "Você comeu Carne de Caça crua (+25 HP, fome saciada)."
	case protocol.ItemRawWolfMeat: // 2: Carne Crua de Lobo (+45 HP / +90 HP Chimeryth)
		p.consumeOneItemLocked(itemID)
		p.feedLocked(itemID)
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

	case protocol.ItemCookedNobleMeat: // 3: Carne Nobre Assada (+90 HP, +40 Stamina / dobro Chimeryth)
		p.consumeOneItemLocked(itemID)
		p.feedLocked(itemID)
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

	case protocol.ItemHealingPotion: // 79: Poção de Cura (Lyra)
		p.consumeOneItemLocked(itemID)
		p.HP = uint16(min(uint32(p.HP)+90, uint32(p.MaxHP)))
		return true, "Você bebeu a Poção de Cura e recuperou +90 HP."

	case protocol.ItemManaPotion: // 80: Poção de Mana (Lyra)
		p.consumeOneItemLocked(itemID)
		p.Mana = min(p.Mana+80, float32(p.MaxMana))
		return true, "Você bebeu a Poção de Mana e recuperou +80 de Mana."

	case protocol.ItemWolfBloodPotion: // 4: Poção de Sangue Lupino (+20% Velocidade e Crítico por 20s)
		p.consumeOneItemLocked(itemID)
		p.WolfPotionUntil = time.Now().Add(20 * time.Second)
		return true, "Você bebeu a Poção de Sangue Lupino (+20% Velocidade e Crítico por 20s)!"

	case protocol.ItemBeastProgenitorBlood: // 16: Sangue do Progenitor Bestial (Desperta linhagem Sangrael)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceDhampir
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O Sangue do Progenitor Bestial ferve em suas veias! Você despertou como Sangrael!"

	case protocol.ItemEclipseScytheTome: // 17: Tomo da Foice do Eclipse (Ceifador da Lua Negra, Tier 5 Única, Reset Nível 1)
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
		return true, "Você leu o Tomo da Foice do Eclipse e renasceu como Ceifador da Lua Negra (Tier Única - Nível 1)!"

	case protocol.ItemStarforgeCore: // 18: Núcleo de Forja Estelar (Engenheiro Rúnico, Tier 5 Única, Reset Nível 1)
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
		return true, "A energia rúnica do Núcleo de Forja transborda! Você despertou como Engenheiro Rúnico (Tier Única - Nível 1)!"

	case protocol.ItemRunicWarhammerRecipe: // 26: Receita do Malho de Batalha Rúnico
		p.consumeOneItemLocked(itemID)
		p.unlockRecipeLocked(protocol.ItemRunicWarhammerRecipe)
		if p.Inventory == nil {
			p.Inventory = make(map[uint8]uint8)
		}
		p.Inventory[protocol.ItemRunicWarhammer]++
		return true, "Você aprendeu a receita secreta e forjou o lendário Malho de Batalha Rúnico (+45 Dano Melee, +8 FOR, +6 CON, +4 MAS)!"

	case protocol.ItemOrganicTrash: // 28: Lixo Orgânico (Alimento e Buff exclusivo Myconid e Orkhan)
		if p.RaceID == protocol.RaceMyconid || p.RaceID == protocol.RaceOrc {
			p.consumeOneItemLocked(itemID)
			p.HP += 50
			if p.HP > p.MaxHP {
				p.HP = p.MaxHP
			}
			p.Stamina = float32(p.MaxStamina)
			p.BuffActiveUntil = time.Now().Add(30 * time.Second)
			return true, "Digestão Fúngica & Estômago de Ferro! Você absorveu a matéria orgânica (+50 HP, Stamina cheia e +25% de dano por 30s)!"
		}
		return false, "Apenas os Esporianos / Myconids e Orcs possuem flora intestinal para digerir lixo orgânico."

	case protocol.ItemRunicHourglass: // 29: Ampulheta Rúnica (Desperta Raça Secreta 28 Cronari)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceTimeWanderer
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O tempo congela ao seu redor... Você despertou como Cronari!"

	case protocol.ItemSilverSilkCocoon, protocol.ItemArachnaEye: // 30, 44: Casulo / Olho Multifacetado de Arachna (Desperta Raça Secreta 21 Aracne)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceArachne
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O Olho de Arachna vibra com pura energia aracnídea... Você despertou como Aracne (Tecelão da Bruma)!"

	case protocol.ItemEternalFrostHeart: // 52: Coração de Geada Eterna (Desperta Raça Secreta 24 Borealin / Jotunar)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceBoreal
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O frio ancestral de Ymir congela suas veias e endurece seus ossos... Você despertou como Borealin (Jotunar)!"

	case protocol.ItemProgenitorPureBlood: // 54: Sangue Puro do Progenitor (Desperta Raça Secreta 5 Sangrael)
		p.consumeOneItemLocked(itemID)
		p.RaceID = protocol.RaceDhampir
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O sangue milenar de Lorde Vesperian queima em seu coração... Você despertou como Sangrael (Progenitor Vampírico)!"

	case protocol.ItemAbyssalScorpionStinger: // 47: Ferrão de Escorpião Abissal (Desperta Linhagem de Escorpião)
		p.consumeOneItemLocked(itemID)
		p.BuffActiveUntil = time.Now().Add(60 * time.Second)
		p.recalculateStatsLocked()
		p.HP = p.MaxHP
		p.Stamina = float32(p.MaxStamina)
		return true, "O veneno abissal do ferrão se funde à sua biologia! Dano e crítico aumentados com peçonha mortal!"
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

// EvolveToRevenant desperta a Raça Secreta 7 (Cinerion).
func (p *Player) EvolveToRevenant() {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.RaceID = protocol.RaceRevenant
	p.recalculateStatsLocked()
	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
}

// EvolveToDhampir desperta a Raça Secreta 5 (Sangrael).
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
