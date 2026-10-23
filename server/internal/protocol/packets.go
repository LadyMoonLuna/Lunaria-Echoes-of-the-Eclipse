package protocol

import (
	"encoding/binary"
	"errors"
	"math"
)

// Opcodes dos pacotes dos Marcos 1 e 2
const (
	// Marco 1
	PacketTypeWelcome            uint8 = 0x01
	PacketTypePlayerDisconnected uint8 = 0x02
	PacketTypePlayerMove         uint8 = 0x10
	PacketTypeWorldSnapshot      uint8 = 0x11

	// Marco 2
	PacketTypeNPCSnapshot     uint8 = 0x12
	PacketTypeWorldTime       uint8 = 0x13
	PacketTypePlayerInteract  uint8 = 0x20
	PacketTypeNPCSay          uint8 = 0x21
	PacketTypeDevWorldControl uint8 = 0x22
	PacketTypeDevSkipTime     uint8 = 0x22 // Alias retrocompatível
	PacketTypePortalTravel    uint8 = 0x23 // Transição de Portal / Mudança de Zona
	PacketTypeZoneChange      uint8 = 0x23 // Alias retrocompatível
	PacketTypeFriendshipSync  uint8 = 0x24 // [Server -> Client] Sincronização de Afiança com NPC (8 bytes)

	// Marco 3
	PacketTypeSelectIdentity uint8 = 0x30
	PacketTypePlayerAction   uint8 = 0x31
	PacketTypeCombatEvent    uint8 = 0x32
	PacketTypePlayerStats    uint8 = 0x33

	// Marco 4
	PacketTypeMobSnapshot     uint8 = 0x14
	PacketTypeAOETelegraph    uint8 = 0x34
	PacketTypeProjectileSpawn uint8 = 0x35

	// Sistema de Respawn & Void
	PacketTypePlayerRespawn uint8 = 0x36

	// Sistema de Atributos & XP
	PacketTypeAllocateStat uint8 = 0x37

	// Sistema de Inventário & Extração Anatômica
	PacketTypeInventorySync  uint8 = 0x38
	PacketTypeUseOrEquipItem uint8 = 0x39

	// Sistema Dev de Taxas de Drop
	PacketTypeDevGetDropRates uint8 = 0x3A

	// Sistema de Cadáveres e Mini-Game de Autópsia
	PacketTypeInteractCorpse      uint8 = 0x3B // [Client -> Server] Interagir com Cadáver (9 bytes)
	PacketTypeOpenAutopsyUI       uint8 = 0x3C // [Server -> Client] Abrir Tela de Autópsia
	PacketTypeSubmitAutopsyResult uint8 = 0x3D // [Client -> Server] Enviar Resultado do Mini-Game (11 bytes)
	PacketTypeCorpseSnapshot      uint8 = 0x3E // [Server -> Client] Sincronização de Cadáveres no Chão

	// Tiers de Qualidade da Autópsia (0x3C e 0x3D)
	QualityPerfect   uint8 = 1 // Perfeito (Zona Verde)
	QualityCommon    uint8 = 2 // Comum (Zona Amarela)
	QualityDestroyed uint8 = 3 // Destruído (Zona Vermelha / Lixo Orgânico)

	// Evolução e Provação de RPG (Marco 5)
	PacketTypeEvolutionOffer uint8 = 0x40

	// Itens no chão (0x3A a 0x3C já pertencem a drop rates/autópsia, por isso 0x41 a 0x43)
	PacketTypeDropItemGround   uint8 = 0x41 // [Client -> Server] Descartar item da mochila no chão (7 bytes)
	PacketTypeGroundItemsSync  uint8 = 0x42 // [Server -> Client] Lista de itens no chão da zona
	PacketTypePickupGroundItem uint8 = 0x43 // [Client -> Server] Pegar item do chão (9 bytes)

	// Coleta e Materiais
	PacketTypeHarvestNode         uint8 = 0x44 // [Client -> Server] Coletar nó de recurso (9 bytes)
	PacketTypeResourceNodesSync   uint8 = 0x45 // [Server -> Client] Nós de recurso da zona
	PacketTypeDiscoveredMaterials uint8 = 0x46 // [Server -> Client] Materiais descobertos (lista completa ou novos)
	PacketTypeQuestState          uint8 = 0x47 // [Server -> Client] Estado de missão (5 bytes)
	PacketTypeShopRequest         uint8 = 0x48 // [Client -> Server] Abrir loja viva de um NPC (9 bytes)
	PacketTypeShopTrade           uint8 = 0x49 // [Client -> Server] Comprar/vender com o NPC (13 bytes)
	PacketTypeShopState           uint8 = 0x4A // [Server -> Client] Estado da loja viva (tamanho variável)
	PacketTypeSetPKMode           uint8 = 0x4B // [Client -> Server] Postura Hostil liga/desliga (2 bytes)
	PacketTypeNPCContract         uint8 = 0x4C // [Client -> Server] Contratar/treinar/assentar/dispensar NPC (6 bytes)
	PacketTypeTombstoneRequest    uint8 = 0x4D // [Client -> Server] Pedir lista de túmulos (1 byte)
	PacketTypeTombstoneState      uint8 = 0x4E // [Server -> Client] Túmulos permanentes (tamanho variável)
	PacketTypeCorpseRite          uint8 = 0x4F // [Client -> Server] Purificar / reviver corpo ou cova (7 bytes)
)

// Tipos de Projéteis 3D
const (
	ProjTypePhysicalArrow  uint8 = 1 // Flecha Física (Batedor - Ataque Básico)
	ProjTypePiercingArrow  uint8 = 2 // Flecha Perfurante / Estrepes (Batedor - Skill Q e R)
	ProjTypeArcaneOrb      uint8 = 3 // Orbe Arcano (Iniciado - Ataque Básico)
	ProjTypeElementalComet uint8 = 4 // Cometa Elemental (Iniciado - Skill Q / Artífice)
	ProjTypeHolySpear      uint8 = 5 // Lança do Julgamento (Acólito - Skill R)
	ProjTypeAcidFlask      uint8 = 6 // Frasco Químico / Bomba de Ácido (Transmutador)
	ProjTypeShadowBolt     uint8 = 7 // Projétil Sombrio (Cultista Sombrio / Malakor)
	ProjTypeBoneSpear      uint8 = 7 // Lança de Fêmur (Arauto do Ossuário - Skill Q)
	ProjTypeLightningSpear uint8 = 8 // Lança do Trovão (Arauto do Trovão - Skill Q)
)

// Tipos de Mobs do Marco 4 e Expansão
const (
	MobTypeMistWolf         uint8 = 1 // Lobo da Bruma
	MobTypeOutcastRaider    uint8 = 2 // Saqueador Deserdado
	MobTypeVigilCrossbowman uint8 = 3 // Besteiro da Vigília
	MobTypeEclipseAcolyte   uint8 = 4 // Acólito do Eclipse
	MobTypeIronEnforcer     uint8 = 5 // Executor de Ferro
	MobTypeAlphaWolf        uint8 = 6 // Lobo Alfa (Lua Cheia)
	MobTypeLycanthropeAlpha uint8 = 7 // Licantropo Alfa (Boss de Raid Secreto - Lua de Sangue)

	// Santuário do Eclipse (Dungeon & Raids)
	MobTypeDarkCultist          uint8 = 10 // Cultista Sombrio (HP 400)
	MobTypeStoneGargoyle        uint8 = 11 // Gárgula de Pedra (HP 580)
	MobTypeInquisitorVex        uint8 = 12 // Mini-Boss Inquisidor Vex (HP 1.400)
	MobTypeCommanderVaelen      uint8 = 13 // Boss Normal Comandante Vaelen, o Traidor (HP 3.200)
	MobTypeMalakorHeraldEclipse uint8 = 14 // Raid Boss Malakor, o Arauto do Eclipse (HP 7.500)

	// Quadrante 4: Novas Criaturas e Raid Bosses
	MobTypeMistWeaverSpider     uint8 = 15 // Aranha Tecelã da Bruma (HP 380)
	MobTypeArachnaQueen         uint8 = 16 // Arachna, a Rainha Tecelã (Raid Boss - HP 6.800)
	MobTypeAcidCorrosiveSlime   uint8 = 17 // Lodo Ácido Corrosivo / Slime Mutante (HP 320)
	MobTypeAbyssalScorpion      uint8 = 18 // Escorpião Abissal Gigante (HP 540)
	MobTypeStitchedChimeraZero  uint8 = 19 // Experimento Nº 0: A Quimera Costurada (Mini-Boss - HP 2.800)
	MobTypeAncientIceGolem      uint8 = 20 // Golem de Gelo Antigo (HP 720)
	MobTypeWildFrostDrake       uint8 = 21 // Draco de Geada Selvagem (HP 950)
	MobTypeYmirFrostPatriarch   uint8 = 22 // Ymir, o Patriarca Jotunar (Boss - HP 5.200)
	MobTypeVesperianBloodGuard  uint8 = 23 // Guarda Sanguinário de Vesperian (HP 680)
	MobTypeLordVesperianVampire uint8 = 24 // Lorde Vesperian, o Progenitor Vampiro (Raid Boss Secreto - HP 8.500)
	MobTypeWildBoar             uint8 = 25 // Javali Selvagem (Bosque Sussurrante - HP 140, mais fraco que o Lobo da Bruma)
	MobTypeZombie               uint8 = 26 // Zumbi (corpo não processado que voltou à vida; não renasce)
)

// Estados de Mobs do Marco 4
const (
	MobStatePatrolIdle     uint8 = 0 // Patrulha/Idle
	MobStateChasing        uint8 = 1 // Perseguindo
	MobStateAttacking      uint8 = 2 // Atacando/Carregando
	MobStateBlocking       uint8 = 3 // Bloqueando (Escudo)
	MobStateFleeing        uint8 = 4 // Fugindo/Atordoado
	MobStateFleeingStunned uint8 = 4 // Fugindo/Atordoado/Vulnerável
	MobStateDead           uint8 = 5 // Morto
)

// Identificadores das 28 Raças de Lunaria Online
const (
	// Raças Base (1 a 4)
	RaceValerian uint8 = 1 // Valeriano
	RaceNoctari  uint8 = 2 // Noctari
	RaceKharad   uint8 = 3 // Kharad
	RaceVarkai   uint8 = 4 // Varkai

	// 6 Raças Secretas Originais (5 a 10)
	RaceDhampir               uint8 = 5  // Sangrael
	RacePrimordialLycanthrope uint8 = 6  // Lupharion (Evolução Secreta Varkai)
	RaceRevenant              uint8 = 7  // Cinerion
	RaceCelestine             uint8 = 8  // Seraphel
	RaceCelestial             uint8 = 8  // Seraphel (Alias)
	RaceAbyssal               uint8 = 9  // Umbryss (Filho do Eclipse)
	RaceRunicAutomaton        uint8 = 10 // Runaric

	// Evoluções Raciais Ordem / Caos (11 a 18)
	RaceHighValerian      uint8 = 11 // Solvaren (Caminho A - Ordem)
	RaceAetherWalker      uint8 = 12 // Aetheris (Caminho B - Caos)
	RaceLunarArchon       uint8 = 13 // Selenarca (Caminho A - Ordem)
	RaceUmbralSpecter     uint8 = 14 // Nyxara (Caminho B - Caos)
	RaceRunicGuardian     uint8 = 15 // Runakhar (Caminho A - Ordem)
	RaceObsidianTitan     uint8 = 16 // Pyrokhar (Caminho B - Caos)
	RaceDraconicSovereign uint8 = 17 // Dravarkai (Caminho A - Ordem)
	RaceFrenzyBeast       uint8 = 18 // Ferovar (Caminho B - Caos)

	// 10 Novas Raças com Mecânicas Exclusivas (19 a 28)
	RaceSylvari       uint8 = 19 // Sylvari (Nascido da Seiva)
	RaceMyconid       uint8 = 20 // Myconid (Véu Fúngico)
	RaceArachne       uint8 = 21 // Aracne (Tecelão da Bruma)
	RaceAshDragonborn uint8 = 22 // Ignivarn (Escama-Negra)
	RaceChimera       uint8 = 23 // Chimeryth (O Experimento Costurado)
	RaceBoreal        uint8 = 24 // Borealin (Coração de Geada)
	RaceThalassian    uint8 = 25 // Thalassiano (Filho da Maré Negra)
	RaceCambion       uint8 = 26 // Cambion (Sangue-de-Enxofre)
	RaceNephilim      uint8 = 27 // Nephilim (Híbrido do Crepúsculo)
	RaceTimeWanderer  uint8 = 28 // Cronari

	// Quadrante 5: 18 Novas Raças do RPG (29 a 46)
	RaceHalfCelestial   uint8 = 29 // Aurelith (Ser de Luz)
	RacePyromancer      uint8 = 30 // Pyrael (Fulgor & Chama da Vida)
	RaceFrostGiant      uint8 = 31 // Jotunar (Pele Gélida - 1.45x)
	RaceDragonEarth     uint8 = 32 // Terravyrn (Couraça Ancestral)
	RaceDragonWater     uint8 = 33 // Hydravyrn (Lima da Água)
	RaceDragonLightning uint8 = 34 // Fulgravyrn (Para-Raios)
	RaceDragonMystic    uint8 = 35 // Arcavyrn (Sangue Místico)
	RaceOrc             uint8 = 36 // Orkhan (Barriga de Ferro & Músculos de Aço)
	RaceDwarf           uint8 = 37 // Dvergar (Ímpeto da Forja - 0.82x)
	RaceElf             uint8 = 38 // Elarin (Pés Velozes & Corpo Esguio)
	RaceSolarElf        uint8 = 39 // Solarin (Devoto de Azgher)
	RaceLunarElf        uint8 = 40 // Lunarin (Devoto de Tenebra)
	RaceFairy           uint8 = 41 // Faelith (Espírito da Natureza - 0.55x)
	RaceGoblin          uint8 = 42 // Gnarlin (Cleptomancia - 0.75x)
	RaceScorpionDemi    uint8 = 43 // Escarion (Sangue Ruim)
	RaceTurtleDemi      uint8 = 44 // Testudar (Armadura Orgânica - 1.35x)
	RaceHalfDemon       uint8 = 45 // Lilitara (Aparência Inofensiva)
	RaceWolfDemi        uint8 = 46 // Ulvar (Olfato & Instinto)
	RaceManamancer      uint8 = 47 // Manamante (Coração de Mana — conjura com a própria Vida)

	// RaceMaxID é o maior ID de raça válido.
	RaceMaxID uint8 = 47
)

// Slots de Equipamento (Array fixo de 14 slots)
const (
	SlotHelmet   uint8 = 0  // Elmo / Cabeça
	SlotChest    uint8 = 1  // Peitoral / Armadura
	SlotLegs     uint8 = 2  // Calças / Pernas
	SlotBoots    uint8 = 3  // Botas / Pés
	SlotGloves   uint8 = 4  // Luvas / Mãos
	SlotCloak    uint8 = 5  // Capa / Túnica
	SlotAmulet   uint8 = 6  // Colar / Relíquia
	SlotEarring  uint8 = 7  // Brinco / Amuleto (cintos também ocupam este acessório)
	SlotBelt     uint8 = 7  // Alias: cinto ocupa o slot de acessório (Brinco/Amuleto)
	SlotRing1    uint8 = 8  // Anel 1
	SlotRing2    uint8 = 9  // Anel 2
	SlotRing3    uint8 = 10 // Anel 3
	SlotRing4    uint8 = 11 // Anel 4
	SlotMainHand uint8 = 12 // Mão Principal / Arma Direita
	SlotOffHand  uint8 = 13 // Mão Secundária / Esquerda

	EquipSlotCount = 14
)

// Ações do pacote 0x39 USE_OR_EQUIP_ITEM
const (
	ItemActionUse     uint8 = 0 // Usar/equipar: SlotIndex leva a Qualidade da unidade escolhida (255 = a melhor)
	ItemActionUnequip uint8 = 1 // Desequipar o slot informado em SlotIndex
)

// Catálogo de Itens Realistas (ItemID uint8)
const (
	// Utilitários & Consumíveis
	ItemEmptyFlask      uint8 = 1 // Frasco de Vidro Vazio (Necessário para coletar sangues e venenos)
	ItemRawWolfMeat     uint8 = 2 // Carne Crua de Lobo (Consumível: Recupera +45 HP)
	ItemCookedNobleMeat uint8 = 3 // Carne Nobre Assada (Consumível: Recupera +90 HP e +40 Stamina)
	ItemWolfBloodPotion uint8 = 4 // Poção de Sangue Lupino (+20% Velocidade e Crítico por 20s)

	// Materiais Anatômicos de Criaturas
	ItemWolfGreyPelt      uint8 = 129 // Unificado: Couro de Lobo (material 129)
	ItemSharpWolfFang     uint8 = 142 // Unificado: Presas e Garras Afiadas (material 142)
	ItemBeastClaw         uint8 = 142 // Unificado: Presas e Garras Afiadas (material 142)
	ItemFreshWolfBlood    uint8 = 136 // Unificado: Sangue de Lobo (material 136)
	ItemAlphaWolfPelt     uint8 = 9   // Pele Intacta de Lobo Alfa (Armadura: +35 MaxHP, +3 FOR)
	ItemPureLunarBlood    uint8 = 10  // Sangue Lunar Puro (Coletado de Lobo Alfa com Frasco Vazio)
	ItemDarkPoisonGland   uint8 = 11  // Glândula de Veneno Sombrio (Coletado com Frasco Vazio)
	ItemHeavySteelPlate   uint8 = 12  // Placa de Aço Pesada (Armadura: +50 MaxHP, +4 CON)
	ItemAncestralFangRing uint8 = 13  // Anel de Presa Ancestral (Acessório/Anel 1: +3 DES, +3 AGI)

	// Itens de Eventos & Rituais Secretos
	ItemBrokenSoulChalice    uint8 = 14 // Cálice da Alma Partida (Morte à noite desperta Raça 7 Cinerion - Drop 0.1%)
	ItemLycanAlphaHeart      uint8 = 15 // Coração do Licantropo Alfa (Relíquia: +15% Roubo de Vida, +5 em todos status - Drop 0.1%)
	ItemBeastProgenitorBlood uint8 = 16 // Sangue do Progenitor Bestial (Desperta Sangrael - Drop 0.1%)
	ItemEclipseScytheTome    uint8 = 17 // Tomo da Foice do Eclipse (Desperta Classe Secreta 7 Ceifador da Lua Negra - Drop 0.1%)
	ItemStarforgeCore        uint8 = 18 // Núcleo de Forja Estelar (Desperta Classe Secreta 8 Engenheiro Rúnico - Drop 0.1%)
	ItemTitansHammerTome     uint8 = 18 // Alias: Tomo do Martelo Titânico / Núcleo de Forja Estelar

	// Itens do Santuário do Eclipse
	ItemShadowCultistRobe        uint8 = 19 // Túnica do Cultista Sombrio
	ItemGargoyleStoneHeart       uint8 = 20 // Coração Pétreo da Gárgula
	ItemInquisitorShadowScythe   uint8 = 21 // Foice de Sombras do Inquisidor
	ItemTraitorCommanderInsignia uint8 = 22 // Insígnia do Comandante Traidor
	ItemHeraldEclipseEye         uint8 = 23 // Olho do Arauto do Eclipse
	ItemSacredTorch              uint8 = 24 // Tocha Sagrada do Santuário

	// Minérios, Receitas e Forja
	ItemIronOre              uint8 = 116 // Unificado: Ferro (material 116) — presente compatível para Garrick
	ItemRunicWarhammerRecipe uint8 = 26  // Receita: Malho de Batalha Rúnico (Receita secreta do Ferreiro)
	ItemRunicWarhammer       uint8 = 27  // Malho de Batalha Rúnico (Arma Exclusiva Forjada: +45 Dano, +8 FOR, +6 CON, +4 MAS)
	ItemOrganicTrash         uint8 = 28  // Lixo Orgânico / Restos Estragados (Falha na autópsia / corte na Zona Vermelha)

	// Itens Secretos de Desbloqueio de Raças/Classes (Chance 0.1%)
	ItemRunicHourglass   uint8 = 29 // Ampulheta Rúnica (Desperta Raça 28 Cronari / Cronari - Drop 0.1%)
	ItemSilverSilkCocoon uint8 = 30 // Casulo de Seda Prateada (Desperta Raça 21 Aracne - Drop 0.1%)

	// Equipamentos para os 12 Slots Reais
	ItemVigilHelmet         uint8 = 31 // Elmo de Vigia (Capacete: +25 HP, +2 CON)
	ItemSteelChestplate     uint8 = 32 // Peitoral de Aço (Peitoral: +60 HP, +5 CON)
	ItemWolfLeatherPants    uint8 = 33 // Calças de Couro Lupino (Calças: +30 HP, +3 AGI)
	ItemMistwalkerBoots     uint8 = 34 // Botas Passo-da-Bruma (Botas: +25 HP, +4 AGI, +2 DES)
	ItemBlacksmithGauntlets uint8 = 35 // Manoplas de Forjador de Estrelas (Luvas: +4 FOR, +3 MAS)
	ItemAlchemistBelt       uint8 = 36 // Cinto de Transmutador (Cinto: +3 INT, +3 SPI)
	ItemSilverMoonAmulet    uint8 = 37 // Colar da Lua Prateada (Colar: +4 INT, +4 SPI, +3 LCK)
	ItemBloodRubyRing       uint8 = 38 // Anel de Rubi Sanguinário (Anel: +4 FOR, +3 CON)
	ItemObsidianRing        uint8 = 39 // Anel de Obsidiana (Anel: +4 CON, +3 MAS)
	ItemStarlightRing       uint8 = 40 // Anel Estelar (Anel: +3 INT, +4 LCK)
	ItemAlphaPeltCloak      uint8 = 41 // Capa de Pele Alfa (Capa: +35 HP, +3 FOR, +3 AGI)

	// Quadrante 4: Drops de Criaturas e Raid Bosses
	ItemPerfectSilkCocoon      uint8 = 132 // Unificado: Teias de Aranha (material 132)
	ItemSpiderQueenHeart       uint8 = 43  // Coração da Rainha Aranha (Relíquia: +12 INT, +8 SPI)
	ItemArachnaEye             uint8 = 44  // Olho Multifacetado de Arachna (0.1% - Desbloqueia Raça 21 Aracne)
	ItemImperialSilkCloak      uint8 = 45  // Manto de Seda Imperial (Capa: +45 HP, +6 INT, +5 SPI)
	ItemPureAcid               uint8 = 153 // Unificado: Seiva Ácida (material 153)
	ItemAbyssalScorpionStinger uint8 = 47  // Ferrão de Escorpião Abissal (0.1% - Desbloqueia Raça Escarion)
	ItemVorpalPoison           uint8 = 143 // Unificado: Bolsa de Veneno Vorpal (material 143)
	ItemChimeraFleshPart       uint8 = 49  // Retalho Quimérico Costurado (Mutagênico)
	ItemAncientIceCore         uint8 = 50  // Núcleo de Gelo Antigo (Gélido)
	ItemPrimordialDragonScale  uint8 = 51  // Escama Dracônica Primordial (Armadura Superior)
	ItemEternalFrostHeart      uint8 = 52  // Coração de Geada Eterna (0.1% - Desbloqueia Raça 24 Borealin / Jotunar)
	ItemCrimsonGuardInsignia   uint8 = 53  // Insígnia do Guarda Carmesim
	ItemProgenitorPureBlood    uint8 = 54  // Sangue Puro do Progenitor (0.1% - Desbloqueia Raça 5 Sangrael)
	ItemVesperianCrimsonRing   uint8 = 55  // Anel Carmesim de Vesperian (Anel: +6 FOR, +6 CON, +10% Lifesteal)
	ItemRoyalVenomGland        uint8 = 56  // Glândula Real do Escorpião (2% Escorpião Abissal - requisito do Algoz Vorpal)
	ItemVesperianPureBlood     uint8 = 57  // Sangue Puro de Vesperian (25% Lorde Vesperian - requisito do Conde Escarlate)
	ItemMechaBlueprint         uint8 = 58  // Diagrama do Mecha Gnarlin (Mercado Negro de Varis - requisito do Barão Engrenagem)

	// Armas de Mão Principal (Slot 12) e itens de Mão Secundária (Slot 13)
	ItemIronLongsword   uint8 = 59 // Espada Longa de Ferro (1 mão)
	ItemOakStaff        uint8 = 60 // Cajado de Carvalho Arcano
	ItemRecurveBow      uint8 = 61 // Arco Recurvo de Caça
	ItemSteelDagger     uint8 = 62 // Adaga de Aço
	ItemIronKnuckles    uint8 = 63 // Manoplas de Ferro
	ItemForgeHammer     uint8 = 64 // Martelo de Forja
	ItemGiantCleaver    uint8 = 65 // Cutelo Gigante
	ItemBeastWhip       uint8 = 66 // Chicote Bestial
	ItemSteelNeedles    uint8 = 67 // Agulhas de Aço Rúnicas
	ItemColossalSword   uint8 = 68 // Espada Colossal (2 mãos)
	ItemTowerShield     uint8 = 69 // Escudo de Torre (Mão Secundária)
	ItemOffhandDagger   uint8 = 70 // Adaga Secundária
	ItemArcaneOrb       uint8 = 71 // Orbe Arcano (Mão Secundária)
	ItemAlchemyCatalyst uint8 = 72 // Catalisador Alquímico (Mão Secundária)
	ItemIronWok         uint8 = 73 // Wok de Ferro (Mão Secundária)
	ItemHuntersQuiver   uint8 = 74 // Aljava de Caçador (Mão Secundária)
	ItemOffhandKnuckle  uint8 = 75 // Manopla Secundária
	ItemLeadPlate       uint8 = 76 // Placa de Chumbo (25 kg) — item de teste de sobrecarga
	ItemAutopsyDagger   uint8 = 77 // Adaga de Autópsia (presente de Garrick; arma cortante para dissecar)
	ItemMetalScrap      uint8 = 78 // Sucata Metálica (resultado de extração/criação metálica de baixa qualidade)
	ItemHealingPotion   uint8 = 79 // Poção de Cura (Lyra: Ervas + Água) — +90 HP
	ItemManaPotion      uint8 = 80 // Poção de Mana (Lyra: Cogumelo + Ervas + Água) — +80 Mana
	ItemBlueprintScroll uint8 = 81 // Pergaminho de Blueprint (forma um aprendiz no ofício do mestre caído)
	ItemHerbalRemedy    uint8 = 82 // Remédio de Ervas (Lyra) — cura doenças e infecções
)

// Identificadores de Classes (Base 1-12 e Secretas 13-21)
const (
	ClassNone     uint8 = 0 // Viajante / Sem Classe (Tier 0)
	ClassTraveler uint8 = 0 // Alias

	// As 6 Classes Básicas de Combate (IDs 1 a 6)
	ClassWarrior      uint8 = 1 // Espadachim da Aurora (Arma: Espada)
	ClassSwordsman    uint8 = 1 // Alias retrocompatível
	ClassMage         uint8 = 2 // Arcanista (Arma: Cajado / Orbe Arcano)
	ClassInitiate     uint8 = 2 // Alias retrocompatível
	ClassArcher       uint8 = 3 // Sentinela dos Ventos (Arma: Arco)
	ClassScout        uint8 = 3 // Alias retrocompatível
	ClassAssassin     uint8 = 4 // Lâmina Silente (Arma: Duas Adagas)
	ClassAcolyte      uint8 = 4 // Alias retrocompatível
	ClassFighter      uint8 = 5 // Punho Celeste (Arma: Manoplas Pesadas)
	ClassShieldBearer uint8 = 6 // Guardião do Bastião (Arma: Escudo Colossal + Maça Curta)

	// As 6 Classes Básicas de Produção Combatentes (IDs 7 a 12)
	ClassBlacksmith  uint8 = 7  // Forjador de Estrelas (Arma: Martelo de Forja)
	ClassAlchemist   uint8 = 8  // Transmutador (Arma: Catalisador & Frascos Químicos)
	ClassSculptor    uint8 = 9  // Escultor de Almas (Arma: Cinzel & Adaga do Luar)
	ClassTamer       uint8 = 10 // Senhor das Feras (Arma: Chicote Bestial)
	ClassWarTailor   uint8 = 11 // Tecelão Carmesim (Arma: Fios de Aço & Agulhas Rúnicas)
	ClassHuntingChef uint8 = 12 // Mestre do Banquete (Arma: Cutelo Gigante & Wok de Ferro)

	// Classes Secretas Variantes (IDs 13 a 18 - Tier 3 Raro / Tier 4 Épico, SEM Reset de Nível)
	ClassRunicSpellblade uint8 = 13 // Lâmina Rúnica (Spellblade)
	ClassVampireHunter   uint8 = 14 // Inquisidor de Prata (Inquisidor de Prata)
	ClassAegisValkyrie   uint8 = 15 // Valquíria Celeste (Lanceiro Celeste)
	ClassShadowMonk      uint8 = 16 // Punho Fantasma (Punho Silencioso)
	ClassCursedSmith     uint8 = 17 // Forjador Carmesim
	ClassPlagueDoctor    uint8 = 18 // Doutor Corvo (Doutor Corvo)

	// Classes Secretas ÚNICAS Exclusivas de Raça (IDs 19 a 26 - Tier 5 travado, +11 pts/nível, Reset para o Nível 1)
	ClassVorpalExecutioner   uint8 = 19 // Algoz Vorpal (Escarion)
	ClassCrimsonWebSovereign uint8 = 20 // Senhor da Teia Escarlate (Aracne)
	ClassBloodPackKing       uint8 = 21 // Rei-Lobo do Eclipse (Ulvar / Lupharion)
	ClassMountainRunemancer  uint8 = 22 // Runomante Ancestral (Dvergar / Kharad)
	ClassWorldBastion        uint8 = 23 // Colosso Abissal (Testudar)
	ClassWorldTreeArchfairy  uint8 = 24 // Arquifada de Yggdra (Faelith)
	ClassCrimsonAristocrat   uint8 = 25 // Conde Escarlate / Nosferatu Real (Sangrael)
	ClassScrapBaron          uint8 = 26 // Barão Engrenagem (Gnarlin)

	// Classes Secretas ÚNICAS Gerais (IDs 27 a 30 e 35 a 39 - Tier 5 travado, +11 pts/nível, Reset para o Nível 1)
	ClassEclipseReaper     uint8 = 27 // Ceifador da Lua Negra (Melee Foice: HP 160, Stam 110, Lifesteal)
	ClassAstralDancer      uint8 = 28 // Bailarino das Estrelas (Crítico e Esquiva: HP 135, Stam 140)
	ClassAshInquisitor     uint8 = 29 // Inquisidor da Chama Branca (Dano com Vida Baixa: HP 145, Stam 115)
	ClassBoneNecromancer   uint8 = 30 // Arauto do Ossuário (Lança Óssea & Cura no Abate: HP 130, Stam 120)
	ClassRunicArtificer    uint8 = 35 // Engenheiro Rúnico (Híbrido Mecânico Martelo-Canhão: HP 150, Stam 115)
	ClassHomunculusCreator uint8 = 36 // Demiurgo Alquímico (Elixires e Regeneração: HP 130, Stam 125)
	ClassPrimordialTamer   uint8 = 37 // Senhor da Selva Primordial (Espírito Alfa & Behemoth: HP 165, Stam 120)
	ClassRiftKnight        uint8 = 38 // Cavaleiro do Vazio (Resistência e Gravidade: HP 180, Stam 100)
	ClassStormHerald       uint8 = 39 // Arauto do Trovão (Dano Elétrico & Relâmpagos: HP 125, Stam 130)

	// Classes Secretas LENDÁRIAS (IDs 31 a 34 - Tier 6 Mítico, +15 pts/nível, +50 status, Reset para o Nível 1)
	ClassPagmaDescendant   uint8 = 31 // Herdeiro da Forja Divina
	ClassMoonlightSculptor uint8 = 32 // Mestre Escultor do Luar
	ClassDragonMonarch     uint8 = 33 // Imperador Dracônico
	ClassBlackSunEmperor   uint8 = 34 // Soberano do Sol Negro

	// ClassMaxID é o maior ID de classe válido.
	ClassMaxID uint8 = 39
)

// Os 6 Tiers de Raridade de Classe
const (
	TierTraveler  uint8 = 0 // Tier 0 - Viajante (Sem Classe)
	TierNone      uint8 = 0 // Alias
	TierCommon    uint8 = 1 // Comum (1.0x)
	TierUncommon  uint8 = 2 // Incomum (1.20x)
	TierRare      uint8 = 3 // Rara (1.45x)
	TierEpic      uint8 = 4 // Épica (1.75x) - Teto das Classes Base
	TierUnique    uint8 = 5 // Única (2.15x) - Exclusivo das Secretas
	TierLegendary uint8 = 6 // Lendária (2.60x) - Despertar Final das Secretas
)

// Modos de Ação do Pacote 0x30 SELECT_IDENTITY
const (
	IdentityModeInitialChange uint8 = 0  // Troca Inicial (Tier 1 Comum)
	IdentityModeEvolveClass   uint8 = 1  // Evoluir Classe (+1 Tier mantendo Nível)
	IdentityModeSecretReset   uint8 = 2  // Trocar para Classe Secreta (Tier 5, Reset Level 1)
	IdentityModeTrainLevel5   uint8 = 3  // Treinar / +5 Níveis para Teste
	IdentityModeDevDirect     uint8 = 98 // Modo Dev Direto: define ClassID (1..15) e ClassTier (1..6)
)

// Identificadores de Ações de Combate (0x31 PLAYER_ACTION)
const (
	ActionBasicAttack  uint8 = 1 // Ataque Básico (Clique Esquerdo: 0 Stamina, cd 0.45s)
	ActionDodgeRoll    uint8 = 2 // Esquiva / Dodge Roll (Tecla Shift: 20 Stamina, 0.5s I-Frame)
	ActionSkillQ       uint8 = 3 // Habilidade 1 [Tecla Q] (15 Stamina, cd 2.0s, 1.75x dano)
	ActionSpecialSkill uint8 = 3 // Alias retrocompatível para Skill Q
	ActionSkillR       uint8 = 4 // Habilidade 2 [Tecla R] (20 Stamina, cd 4.0s)
	ActionSkillF       uint8 = 5 // Habilidade 3 [Tecla F] (25 Stamina, cd 6.0s, 2.4x dano - Ultimate)
	ActionRacialSkill  uint8 = 6 // Habilidade Racial Ativa [Tecla Z] (cd 10.0s)
)

// Identificadores de Atributos Alocáveis (0x37 ALLOCATE_STAT)
const (
	StatIDSTR uint8 = 1 // Força (Dano Melee)
	StatIDDEX uint8 = 2 // Destreza (Dano Ranged e Crítico)
	StatIDCON uint8 = 3 // Constituição (+18 MaxHP por ponto)
	StatIDAGI uint8 = 4 // Agilidade (+8 MaxStamina por ponto)
	StatIDINT uint8 = 5 // Inteligência (Dano Mágico e Alquímico)
	StatIDSPI uint8 = 6 // Espírito (Cura)
	StatIDMAS uint8 = 7 // Perícia / Maestria (Multiplicador Crítico)
	StatIDLCK uint8 = 8 // Sorte (Chance de Crítico)
)

// Constantes de tamanho dos pacotes (em bytes)
const (
	WelcomePacketSize            = 5
	PlayerDisconnectedPacketSize = 5
	PlayerMovePacketSize         = 25
	WorldSnapshotHeaderSize      = 6
	PlayerSnapshotEntrySize      = 20

	NPCSnapshotHeaderSize     = 2
	NPCSnapshotEntrySize      = 21 // uint32 (4) + 4x float32 (16) + uint8 (1) = 21 bytes
	WorldTimePacketSize       = 5  // uint8 (1) + uint8 (1) + uint8 (1) + uint8 (1) + uint8 (1) = 5 bytes
	PlayerInteractPacketSize  = 9  // uint8 (1) + uint32 (4) + uint32 (4) = 9 bytes
	NPCSayHeaderSize          = 7  // uint8 (1) + uint32 (4) + uint16 (2) = 7 bytes
	DevWorldControlPacketSize = 3  // uint8 (1) + uint8 (1) + uint8 (1) = 3 bytes
	DevSkipTimePacketSize     = 3  // Alias
	PortalTravelPacketSize    = 3  // uint8 (1) + uint8 (1) + uint8 (1) = 3 bytes

	SelectIdentityPacketSize = 9  // uint8 (1) + uint32 (4) + 4x uint8 (4) = 9 bytes
	PlayerActionPacketSize   = 14 // uint8 (1) + uint32 (4) + uint8 (1) + 2x float32 (8) = 14 bytes
	CombatEventPacketSize    = 17 // uint8 (1) + 2x uint32 (8) + uint8 (1) + uint16 (2) + uint8 (1) + 2x uint16 (4) = 17 bytes
	PlayerStatsPacketSize    = 36 // 32 bytes de status + Mana (uint16) + Mana Máxima (uint16)
	PlayerRespawnPacketSize  = 17 // uint8 (1) + uint32 (4) + 3x float32 (12) = 17 bytes
	AllocateStatPacketSize   = 8  // uint8 (1) + uint32 (4) + uint8 (1) + uint16 Amount (2) = 8 bytes

	InventorySyncHeaderSize  = 48 // op (1) + 14 slots + 14 Condições + Gold u32 + Eclipses u32 + Peso f32 + PesoMáx f32 + Velocidade% u8 + count u16
	InventorySlotEntrySize   = 3  // item (1) + quantidade (1) + Qualidade 0-100 (1) = 3 bytes
	UseOrEquipItemPacketSize = 8  // op (1) + playerID u32 (4) + itemID (1) + action (1) + slot (1) = 8 bytes

	DropItemGroundPacketSize   = 8  // op (1) + playerID u32 (4) + item (1) + Qualidade (1) + quantidade (1)
	PickupGroundItemPacketSize = 9  // op (1) + playerID u32 (4) + dropID u32 (4)
	GroundItemEntrySize        = 15 // dropID u32 (4) + itemID (1) + qty (1) + Qualidade (1) + X f32 (4) + Z f32 (4)

	MobSnapshotHeaderSize  = 2  // uint8 (1) + uint8 (1) = 2 bytes
	MobSnapshotEntrySize   = 26 // uint32 (4) + 2x uint8 (2) + 4x float32 (16) + 2x uint16 (4) = 26 bytes
	AOETelegraphPacketSize = 19 // uint8 (1) + uint32 (4) + 3x float32 (12) + uint16 (2) = 19 bytes

	// Cadáveres e Autópsia
	InteractCorpsePacketSize      = 9  // uint8 (1) + uint32 (4) + uint32 (4) = 9 bytes
	OpenAutopsyUIHeaderSize       = 11 // uint8 (1) + uint32 (4) + uint8 (1) + uint32 (4) + uint8 (1) = 11 bytes
	AutopsyOrganEntrySize         = 5  // uint8 (1) + uint8 (1) + uint8 (1) + uint8 (1) + uint8 (1) = 5 bytes
	SubmitAutopsyResultPacketSize = 12 // op (1) + playerID (4) + corpseID (4) + órgão (1) + tier (1) + Qualidade (1) = 12 bytes
	CorpseSnapshotHeaderSize      = 2  // uint8 (1) + uint8 (1) = 2 bytes
	CorpseSnapshotEntrySize       = 28 // uint32 (4) + uint32 (4) + uint8 (1) + 3x float32 (12) + float32 (4) + uint8 (1) + uint16 (2) = 28 bytes
)

var (
	ErrInvalidPacketSize = errors.New("tamanho de pacote binario invalido")
	ErrInvalidPacketType = errors.New("tipo de opcode de pacote invalido")
)

// --- 0x01: WELCOME (TCP: Server -> Client) ---

// SerializeWelcome cria o payload binário do pacote WELCOME (5 bytes) em Little Endian.
func SerializeWelcome(playerID uint32) [WelcomePacketSize]byte {
	var b [WelcomePacketSize]byte
	b[0] = PacketTypeWelcome
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	return b
}

// DeserializeWelcome decodifica um pacote WELCOME a partir de um buffer de bytes.
func DeserializeWelcome(data []byte) (uint32, error) {
	if len(data) < WelcomePacketSize {
		return 0, ErrInvalidPacketSize
	}
	if data[0] != PacketTypeWelcome {
		return 0, ErrInvalidPacketType
	}
	return binary.LittleEndian.Uint32(data[1:5]), nil
}

// --- 0x02: PLAYER_DISCONNECTED (TCP: Server -> Clients) ---

// SerializePlayerDisconnected cria o payload binário do pacote PLAYER_DISCONNECTED (5 bytes) em Little Endian.
func SerializePlayerDisconnected(playerID uint32) [PlayerDisconnectedPacketSize]byte {
	var b [PlayerDisconnectedPacketSize]byte
	b[0] = PacketTypePlayerDisconnected
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	return b
}

// DeserializePlayerDisconnected decodifica um pacote PLAYER_DISCONNECTED a partir de um buffer de bytes.
func DeserializePlayerDisconnected(data []byte) (uint32, error) {
	if len(data) < PlayerDisconnectedPacketSize {
		return 0, ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerDisconnected {
		return 0, ErrInvalidPacketType
	}
	return binary.LittleEndian.Uint32(data[1:5]), nil
}

// --- 0x10: PLAYER_MOVE (UDP: Client -> Server) ---

// PlayerMovePacket representa a intenção de movimento transmitida pelo cliente.
type PlayerMovePacket struct {
	PlayerID uint32
	Seq      uint32
	PosX     float32
	PosY     float32
	PosZ     float32
	RotY     float32
}

// SerializePlayerMove cria o payload de 25 bytes do pacote PLAYER_MOVE.
func SerializePlayerMove(pkt PlayerMovePacket) [PlayerMovePacketSize]byte {
	var b [PlayerMovePacketSize]byte
	b[0] = PacketTypePlayerMove
	binary.LittleEndian.PutUint32(b[1:5], pkt.PlayerID)
	binary.LittleEndian.PutUint32(b[5:9], pkt.Seq)
	binary.LittleEndian.PutUint32(b[9:13], math.Float32bits(pkt.PosX))
	binary.LittleEndian.PutUint32(b[13:17], math.Float32bits(pkt.PosY))
	binary.LittleEndian.PutUint32(b[17:21], math.Float32bits(pkt.PosZ))
	binary.LittleEndian.PutUint32(b[21:25], math.Float32bits(pkt.RotY))
	return b
}

// DeserializePlayerMove faz o parse in-place para out sem alocações adicionais na heap.
func DeserializePlayerMove(data []byte, out *PlayerMovePacket) error {
	if len(data) < PlayerMovePacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerMove {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.Seq = binary.LittleEndian.Uint32(data[5:9])
	out.PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[9:13]))
	out.PosY = math.Float32frombits(binary.LittleEndian.Uint32(data[13:17]))
	out.PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[17:21]))
	out.RotY = math.Float32frombits(binary.LittleEndian.Uint32(data[21:25]))
	return nil
}

// --- 0x11: WORLD_SNAPSHOT (UDP: Server -> Clients) ---

// PlayerSnapshot representa a posição e rotação autoritativa de um jogador no snapshot.
type PlayerSnapshot struct {
	PlayerID uint32
	PosX     float32
	PosY     float32
	PosZ     float32
	RotY     float32
}

// WorldSnapshotPacket representa o pacote completo de snapshot do mundo a 30 Hz.
type WorldSnapshotPacket struct {
	ServerTick  uint32
	PlayerCount uint8
	Players     []PlayerSnapshot
}

// SerializeWorldSnapshotInto grava o snapshot no buffer fornecido e retorna o número de bytes gravados.
func SerializeWorldSnapshotInto(buf []byte, serverTick uint32, players []PlayerSnapshot) int {
	count := len(players)
	if count > 255 {
		count = 255
	}
	totalSize := WorldSnapshotHeaderSize + (count * PlayerSnapshotEntrySize)
	if len(buf) < totalSize {
		return 0
	}

	buf[0] = PacketTypeWorldSnapshot
	binary.LittleEndian.PutUint32(buf[1:5], serverTick)
	buf[5] = uint8(count)

	offset := WorldSnapshotHeaderSize
	for i := 0; i < count; i++ {
		p := &players[i]
		binary.LittleEndian.PutUint32(buf[offset:offset+4], p.PlayerID)
		binary.LittleEndian.PutUint32(buf[offset+4:offset+8], math.Float32bits(p.PosX))
		binary.LittleEndian.PutUint32(buf[offset+8:offset+12], math.Float32bits(p.PosY))
		binary.LittleEndian.PutUint32(buf[offset+12:offset+16], math.Float32bits(p.PosZ))
		binary.LittleEndian.PutUint32(buf[offset+16:offset+20], math.Float32bits(p.RotY))
		offset += PlayerSnapshotEntrySize
	}
	return totalSize
}

// SerializeWorldSnapshot aloca e retorna o slice de bytes com o snapshot serializado.
func SerializeWorldSnapshot(serverTick uint32, players []PlayerSnapshot) []byte {
	size := WorldSnapshotHeaderSize + (len(players) * PlayerSnapshotEntrySize)
	buf := make([]byte, size)
	SerializeWorldSnapshotInto(buf, serverTick, players)
	return buf
}

// DeserializeWorldSnapshot decodifica o snapshot do mundo a partir de bytes.
func DeserializeWorldSnapshot(data []byte, out *WorldSnapshotPacket) error {
	if len(data) < WorldSnapshotHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeWorldSnapshot {
		return ErrInvalidPacketType
	}

	out.ServerTick = binary.LittleEndian.Uint32(data[1:5])
	out.PlayerCount = data[5]

	expectedSize := WorldSnapshotHeaderSize + int(out.PlayerCount)*PlayerSnapshotEntrySize
	if len(data) < expectedSize {
		return ErrInvalidPacketSize
	}

	if cap(out.Players) >= int(out.PlayerCount) {
		out.Players = out.Players[:out.PlayerCount]
	} else {
		out.Players = make([]PlayerSnapshot, out.PlayerCount)
	}

	offset := WorldSnapshotHeaderSize
	for i := 0; i < int(out.PlayerCount); i++ {
		out.Players[i].PlayerID = binary.LittleEndian.Uint32(data[offset : offset+4])
		out.Players[i].PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+4 : offset+8]))
		out.Players[i].PosY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+8 : offset+12]))
		out.Players[i].PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+12 : offset+16]))
		out.Players[i].RotY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+16 : offset+20]))
		offset += PlayerSnapshotEntrySize
	}
	return nil
}

// --- 0x12: NPC_SNAPSHOT (UDP: Server -> Clients) ---

// NPCSnapshot representa os dados de replicação autoritativa de um NPC no mundo.
type NPCSnapshot struct {
	NPCID uint32
	PosX  float32
	PosY  float32
	PosZ  float32
	RotY  float32
	State uint8
}

// NPCSnapshotPacket representa o pacote completo de snapshot dos NPCs ativos.
type NPCSnapshotPacket struct {
	NPCCount uint8
	NPCs     []NPCSnapshot
}

// SerializeNPCSnapshotInto grava o snapshot dos NPCs no buffer fornecido.
func SerializeNPCSnapshotInto(buf []byte, npcs []NPCSnapshot) int {
	count := len(npcs)
	if count > 255 {
		count = 255
	}
	totalSize := NPCSnapshotHeaderSize + (count * NPCSnapshotEntrySize)
	if len(buf) < totalSize {
		return 0
	}

	buf[0] = PacketTypeNPCSnapshot
	buf[1] = uint8(count)

	offset := NPCSnapshotHeaderSize
	for i := 0; i < count; i++ {
		npc := &npcs[i]
		binary.LittleEndian.PutUint32(buf[offset:offset+4], npc.NPCID)
		binary.LittleEndian.PutUint32(buf[offset+4:offset+8], math.Float32bits(npc.PosX))
		binary.LittleEndian.PutUint32(buf[offset+8:offset+12], math.Float32bits(npc.PosY))
		binary.LittleEndian.PutUint32(buf[offset+12:offset+16], math.Float32bits(npc.PosZ))
		binary.LittleEndian.PutUint32(buf[offset+16:offset+20], math.Float32bits(npc.RotY))
		buf[offset+20] = npc.State
		offset += NPCSnapshotEntrySize
	}
	return totalSize
}

// SerializeNPCSnapshot cria e aloca um slice com o snapshot de NPCs.
func SerializeNPCSnapshot(npcs []NPCSnapshot) []byte {
	size := NPCSnapshotHeaderSize + (len(npcs) * NPCSnapshotEntrySize)
	buf := make([]byte, size)
	SerializeNPCSnapshotInto(buf, npcs)
	return buf
}

// DeserializeNPCSnapshot decodifica os dados de NPC_SNAPSHOT do buffer.
func DeserializeNPCSnapshot(data []byte, out *NPCSnapshotPacket) error {
	if len(data) < NPCSnapshotHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeNPCSnapshot {
		return ErrInvalidPacketType
	}

	out.NPCCount = data[1]
	expectedSize := NPCSnapshotHeaderSize + int(out.NPCCount)*NPCSnapshotEntrySize
	if len(data) < expectedSize {
		return ErrInvalidPacketSize
	}

	if cap(out.NPCs) >= int(out.NPCCount) {
		out.NPCs = out.NPCs[:out.NPCCount]
	} else {
		out.NPCs = make([]NPCSnapshot, out.NPCCount)
	}

	offset := NPCSnapshotHeaderSize
	for i := 0; i < int(out.NPCCount); i++ {
		out.NPCs[i].NPCID = binary.LittleEndian.Uint32(data[offset : offset+4])
		out.NPCs[i].PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+4 : offset+8]))
		out.NPCs[i].PosY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+8 : offset+12]))
		out.NPCs[i].PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+12 : offset+16]))
		out.NPCs[i].RotY = math.Float32frombits(binary.LittleEndian.Uint32(data[offset+16 : offset+20]))
		out.NPCs[i].State = data[offset+20]
		offset += NPCSnapshotEntrySize
	}
	return nil
}

// --- 0x20: PLAYER_INTERACT (TCP: Client -> Server) ---

// PlayerInteractPacket representa o comando enviado quando o jogador interage com um NPC.
type PlayerInteractPacket struct {
	PlayerID    uint32
	TargetNPCID uint32
}

// SerializePlayerInteract cria o payload de 9 bytes de PLAYER_INTERACT.
func SerializePlayerInteract(playerID, targetNPCID uint32) [PlayerInteractPacketSize]byte {
	var b [PlayerInteractPacketSize]byte
	b[0] = PacketTypePlayerInteract
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	binary.LittleEndian.PutUint32(b[5:9], targetNPCID)
	return b
}

// DeserializePlayerInteract decodifica o pacote PLAYER_INTERACT (9 bytes).
func DeserializePlayerInteract(data []byte, out *PlayerInteractPacket) error {
	if len(data) < PlayerInteractPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerInteract {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.TargetNPCID = binary.LittleEndian.Uint32(data[5:9])
	return nil
}

// --- 0x21: NPC_SAY (TCP: Server -> Clients) ---

// NPCSayPacket representa uma fala emitida por um NPC para os jogadores.
type NPCSayPacket struct {
	NPCID      uint32
	MessageLen uint16
	Message    string
}

// SerializeNPCSay cria o payload binário completo de NPC_SAY.
func SerializeNPCSay(npcID uint32, message string) []byte {
	msgBytes := []byte(message)
	msgLen := len(msgBytes)
	if msgLen > 65535 {
		msgLen = 65535
		msgBytes = msgBytes[:65535]
	}

	totalSize := NPCSayHeaderSize + msgLen
	buf := make([]byte, totalSize)
	buf[0] = PacketTypeNPCSay
	binary.LittleEndian.PutUint32(buf[1:5], npcID)
	binary.LittleEndian.PutUint16(buf[5:7], uint16(msgLen))
	copy(buf[7:], msgBytes)
	return buf
}

// DeserializeNPCSay decodifica o pacote NPC_SAY a partir de um buffer de bytes.
func DeserializeNPCSay(data []byte, out *NPCSayPacket) error {
	if len(data) < NPCSayHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeNPCSay {
		return ErrInvalidPacketType
	}

	out.NPCID = binary.LittleEndian.Uint32(data[1:5])
	out.MessageLen = binary.LittleEndian.Uint16(data[5:7])

	totalExpected := NPCSayHeaderSize + int(out.MessageLen)
	if len(data) < totalExpected {
		return ErrInvalidPacketSize
	}

	out.Message = string(data[7:totalExpected])
	return nil
}

// --- 0x13: WORLD_TIME (UDP/TCP: Server -> Clients, 5 bytes) ---

// WorldTimePacket representa a hora, o minuto, a fase lunar e o clima sincronizados do mundo.
type WorldTimePacket struct {
	WorldHour   uint8
	WorldMinute uint8
	MoonPhase   uint8
	WeatherType uint8
}

// SerializeWorldTime cria o payload de 5 bytes do pacote WORLD_TIME.
func SerializeWorldTime(hour, minute, moonPhase, weatherType uint8) [WorldTimePacketSize]byte {
	var b [WorldTimePacketSize]byte
	b[0] = PacketTypeWorldTime
	b[1] = hour
	b[2] = minute
	b[3] = moonPhase
	b[4] = weatherType
	return b
}

// DeserializeWorldTime decodifica o pacote WORLD_TIME (5 bytes).
func DeserializeWorldTime(data []byte, out *WorldTimePacket) error {
	if len(data) < WorldTimePacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeWorldTime {
		return ErrInvalidPacketType
	}
	out.WorldHour = data[1]
	out.WorldMinute = data[2]
	out.MoonPhase = data[3]
	out.WeatherType = data[4]
	return nil
}

// --- 0x22: DEV_WORLD_CONTROL (TCP: Client -> Server, 3 bytes) ---

const (
	DevCmdAdvanceHours uint8 = 1  // Avança +Value horas
	DevCmdCycleMoon    uint8 = 2  // Cicla para próxima fase da lua
	DevCmdCycleWeather uint8 = 3  // Cicla para próximo clima
	DevCmdSetHour      uint8 = 4  // Define hora exata (Value % 24)
	DevCmdSetMoon      uint8 = 5  // Define fase da lua exata (0 a 9)
	DevCmdSetWeather   uint8 = 6  // Define clima exato (0 a 3)
	DevCmdGiveItem     uint8 = 7  // Dá item (Value) ou kit 12 slots (255)
	DevCmdLevelStats   uint8 = 8  // Controle de nível/status dev (1=+1, 5=+5, 50=lvl 50, 99=full heal+20pts, 0=reset)
	DevCmdTeleport     uint8 = 9  // Teleporte rápido (0..6)
	DevCmdPortalTravel uint8 = 10 // Travessia de Portal / Mudança de Zona (Value = PortalID)
	DevCmdGiveMoney    uint8 = 11 // +1.000 Sollares e +50 Moedas do Eclipse
	DevCmdClearHeavy   uint8 = 12 // Remove da mochila os itens de 10 kg ou mais por unidade
)

// DevWorldControlPacket representa o comando de depuração para testes (F6=+Horas, F7=Fase Lua, F8=Clima, Dev Menu F10).
type DevWorldControlPacket struct {
	CommandType uint8 // DevCmd* (1 a 9)
	Value       uint8
}

// DevSkipTimePacket mantém compatibilidade com nomes legados
type DevSkipTimePacket = DevWorldControlPacket

// SerializeDevWorldControl cria o payload de 3 bytes do pacote DEV_WORLD_CONTROL.
func SerializeDevWorldControl(cmdType, value uint8) [DevWorldControlPacketSize]byte {
	var b [DevWorldControlPacketSize]byte
	b[0] = PacketTypeDevWorldControl
	b[1] = cmdType
	b[2] = value
	return b
}

// SerializeDevSkipTime cria payload de 3 bytes (CommandType 1 = Avançar horas).
func SerializeDevSkipTime(hoursToAdd uint8) [DevSkipTimePacketSize]byte {
	return SerializeDevWorldControl(1, hoursToAdd)
}

// DeserializeDevWorldControl decodifica o pacote DEV_WORLD_CONTROL (3 bytes).
func DeserializeDevWorldControl(data []byte, out *DevWorldControlPacket) error {
	if len(data) < DevWorldControlPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeDevWorldControl {
		return ErrInvalidPacketType
	}
	out.CommandType = data[1]
	out.Value = data[2]
	return nil
}

// DeserializeDevSkipTime é um wrapper compatível para DeserializeDevWorldControl.
func DeserializeDevSkipTime(data []byte, out *DevSkipTimePacket) error {
	return DeserializeDevWorldControl(data, out)
}

// --- 0x23: PORTAL_TRAVEL / ZONE_CHANGE (3 bytes) ---

// PortalTravelPacket representa o pacote 0x23 de transição de portal / mudança de zona de mão dupla.
type PortalTravelPacket struct {
	TargetZoneID uint8 // ZoneID de destino (0 a 8)
	PortalID     uint8 // ID do portal (1 a 16)
}

// ZoneChangePacket é um alias retrocompatível para PortalTravelPacket.
type ZoneChangePacket = PortalTravelPacket

// SerializePortalTravel serializa o pacote 0x23 PORTAL_TRAVEL (3 bytes).
func SerializePortalTravel(targetZoneID, portalID uint8) [PortalTravelPacketSize]byte {
	var b [PortalTravelPacketSize]byte
	b[0] = PacketTypePortalTravel
	b[1] = targetZoneID
	b[2] = portalID
	return b
}

// DeserializePortalTravel desserializa o pacote 0x23 PORTAL_TRAVEL (3 bytes).
func DeserializePortalTravel(data []byte, out *PortalTravelPacket) error {
	if len(data) < PortalTravelPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePortalTravel {
		return ErrInvalidPacketType
	}
	out.TargetZoneID = data[1]
	out.PortalID = data[2]
	return nil
}

// --- 0x30: SELECT_IDENTITY (TCP: Client -> Server, 8 bytes) ---

// SelectIdentityPacket representa a escolha de Raça e Classe do jogador, modo de ação e Caminho Evolutivo.
type SelectIdentityPacket struct {
	PlayerID   uint32
	RaceID     uint8
	ClassID    uint8
	ActionMode uint8
	SubPath    uint8
}

// SerializeSelectIdentity cria o payload de 9 bytes do pacote SELECT_IDENTITY.
func SerializeSelectIdentity(playerID uint32, raceID, classID, actionMode, subPath uint8) [SelectIdentityPacketSize]byte {
	var b [SelectIdentityPacketSize]byte
	b[0] = PacketTypeSelectIdentity
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = raceID
	b[6] = classID
	b[7] = actionMode
	if subPath == 0 {
		subPath = 1
	}
	b[8] = subPath
	return b
}

// DeserializeSelectIdentity decodifica o pacote SELECT_IDENTITY (9 bytes, compatível com 8 e 7 bytes legado).
func DeserializeSelectIdentity(data []byte, out *SelectIdentityPacket) error {
	if len(data) < 7 {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeSelectIdentity {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.RaceID = data[5]
	out.ClassID = data[6]
	if len(data) >= 8 {
		out.ActionMode = data[7]
	} else {
		out.ActionMode = IdentityModeInitialChange
	}
	// SubPath 0 = manter o Caminho atual (SetIdentityMode só troca com valores de 1 a 4)
	if len(data) >= SelectIdentityPacketSize {
		out.SubPath = data[8]
	} else {
		out.SubPath = 0
	}
	return nil
}

// --- 0x31: PLAYER_ACTION (UDP: Client -> Server, 14 bytes) ---

// PlayerActionPacket representa uma ação de combate físico disparada com mira.
type PlayerActionPacket struct {
	PlayerID   uint32
	ActionType uint8
	AimDirX    float32
	AimDirZ    float32
}

// SerializePlayerAction cria o payload de 14 bytes do pacote PLAYER_ACTION.
func SerializePlayerAction(playerID uint32, actionType uint8, aimX, aimZ float32) [PlayerActionPacketSize]byte {
	var b [PlayerActionPacketSize]byte
	b[0] = PacketTypePlayerAction
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = actionType
	binary.LittleEndian.PutUint32(b[6:10], math.Float32bits(aimX))
	binary.LittleEndian.PutUint32(b[10:14], math.Float32bits(aimZ))
	return b
}

// DeserializePlayerAction decodifica o pacote PLAYER_ACTION (14 bytes).
func DeserializePlayerAction(data []byte, out *PlayerActionPacket) error {
	if len(data) < PlayerActionPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerAction {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.ActionType = data[5]
	out.AimDirX = math.Float32frombits(binary.LittleEndian.Uint32(data[6:10]))
	out.AimDirZ = math.Float32frombits(binary.LittleEndian.Uint32(data[10:14]))
	return nil
}

// --- 0x32: COMBAT_EVENT (UDP: Server -> Clients, 17 bytes) ---

// CombatEventPacket representa o resultado autoritativo de um evento de dano ou habilidade.
type CombatEventPacket struct {
	AttackerID  uint32
	TargetID    uint32
	ActionType  uint8
	Damage      uint16
	IsCrit      uint8
	TargetHP    uint16
	TargetMaxHP uint16
}

// SerializeCombatEvent cria o payload de 17 bytes do pacote COMBAT_EVENT.
func SerializeCombatEvent(attackerID, targetID uint32, actionType uint8, damage uint16, isCrit uint8, targetHP, targetMaxHP uint16) [CombatEventPacketSize]byte {
	var b [CombatEventPacketSize]byte
	b[0] = PacketTypeCombatEvent
	binary.LittleEndian.PutUint32(b[1:5], attackerID)
	binary.LittleEndian.PutUint32(b[5:9], targetID)
	b[9] = actionType
	binary.LittleEndian.PutUint16(b[10:12], damage)
	b[12] = isCrit
	binary.LittleEndian.PutUint16(b[13:15], targetHP)
	binary.LittleEndian.PutUint16(b[15:17], targetMaxHP)
	return b
}

// DeserializeCombatEvent decodifica o pacote COMBAT_EVENT (17 bytes).
func DeserializeCombatEvent(data []byte, out *CombatEventPacket) error {
	if len(data) < CombatEventPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeCombatEvent {
		return ErrInvalidPacketType
	}
	out.AttackerID = binary.LittleEndian.Uint32(data[1:5])
	out.TargetID = binary.LittleEndian.Uint32(data[5:9])
	out.ActionType = data[9]
	out.Damage = binary.LittleEndian.Uint16(data[10:12])
	out.IsCrit = data[12]
	out.TargetHP = binary.LittleEndian.Uint16(data[13:15])
	out.TargetMaxHP = binary.LittleEndian.Uint16(data[15:17])
	return nil
}

// --- 0x33: PLAYER_STATS (UDP: Server -> Client, 31 bytes) ---

// PlayerStatsPacket representa a sincronização autoritativa dos status de sobrevivência, progressão e 8 atributos do jogador.
type PlayerStatsPacket struct {
	PlayerID    uint32
	RaceID      uint8
	ClassID     uint8
	ClassTier   uint8
	Level       uint8
	HP          uint16
	MaxHP       uint16
	Stamina     uint16
	MaxStamina  uint16
	BuffActive  uint8
	XP          uint16
	NextLevelXP uint16
	StatPoints  uint8
	STR         uint8
	DEX         uint8
	CON         uint8
	AGI         uint8
	INT         uint8
	SPI         uint8
	MAS         uint8
	LCK         uint8
	SubPath     uint8
	Mana        uint16
	MaxMana     uint16
}

// SerializePlayerStats cria o payload de 36 bytes do pacote PLAYER_STATS.
// SubPath 0 = Caminho ainda não escolhido.
func SerializePlayerStats(playerID uint32, raceID, classID, classTier, level uint8, hp, maxHP, stamina, maxStamina uint16, buffActive uint8, xp, nextLevelXP uint16, statPoints, str, dex, con, agi, intStat, spi, mas, lck, subPath uint8, mana, maxMana uint16) [PlayerStatsPacketSize]byte {
	var b [PlayerStatsPacketSize]byte
	b[0] = PacketTypePlayerStats
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = raceID
	b[6] = classID
	b[7] = classTier
	b[8] = level
	binary.LittleEndian.PutUint16(b[9:11], hp)
	binary.LittleEndian.PutUint16(b[11:13], maxHP)
	binary.LittleEndian.PutUint16(b[13:15], stamina)
	binary.LittleEndian.PutUint16(b[15:17], maxStamina)
	b[17] = buffActive
	binary.LittleEndian.PutUint16(b[18:20], xp)
	binary.LittleEndian.PutUint16(b[20:22], nextLevelXP)
	b[22] = statPoints
	b[23] = str
	b[24] = dex
	b[25] = con
	b[26] = agi
	b[27] = intStat
	b[28] = spi
	b[29] = mas
	b[30] = lck
	b[31] = subPath
	binary.LittleEndian.PutUint16(b[32:34], mana)
	binary.LittleEndian.PutUint16(b[34:36], maxMana)
	return b
}

// SerializePlayerStatsPacket serializa um PlayerStatsPacket diretamente.
func SerializePlayerStatsPacket(pkt PlayerStatsPacket) [PlayerStatsPacketSize]byte {
	return SerializePlayerStats(
		pkt.PlayerID, pkt.RaceID, pkt.ClassID, pkt.ClassTier, pkt.Level,
		pkt.HP, pkt.MaxHP, pkt.Stamina, pkt.MaxStamina, pkt.BuffActive,
		pkt.XP, pkt.NextLevelXP, pkt.StatPoints,
		pkt.STR, pkt.DEX, pkt.CON, pkt.AGI, pkt.INT, pkt.SPI, pkt.MAS, pkt.LCK,
		pkt.SubPath, pkt.Mana, pkt.MaxMana,
	)
}

// DeserializePlayerStats decodifica o pacote PLAYER_STATS (32 bytes, compatível com 31 bytes).
func DeserializePlayerStats(data []byte, out *PlayerStatsPacket) error {
	if len(data) < 31 {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerStats {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.RaceID = data[5]
	out.ClassID = data[6]
	out.ClassTier = data[7]
	out.Level = data[8]
	out.HP = binary.LittleEndian.Uint16(data[9:11])
	out.MaxHP = binary.LittleEndian.Uint16(data[11:13])
	out.Stamina = binary.LittleEndian.Uint16(data[13:15])
	out.MaxStamina = binary.LittleEndian.Uint16(data[15:17])
	out.BuffActive = data[17]
	out.XP = binary.LittleEndian.Uint16(data[18:20])
	out.NextLevelXP = binary.LittleEndian.Uint16(data[20:22])
	out.StatPoints = data[22]
	out.STR = data[23]
	out.DEX = data[24]
	out.CON = data[25]
	out.AGI = data[26]
	out.INT = data[27]
	out.SPI = data[28]
	out.MAS = data[29]
	out.LCK = data[30]
	if len(data) >= 32 {
		out.SubPath = data[31]
	}
	if len(data) >= PlayerStatsPacketSize {
		out.Mana = binary.LittleEndian.Uint16(data[32:34])
		out.MaxMana = binary.LittleEndian.Uint16(data[34:36])
	}
	return nil
}

// --- 0x37: ALLOCATE_STAT (TCP: Client -> Server, 6 bytes) ---

// AllocateStatPacket representa a requisição do cliente para alocar 1 ponto de status em um atributo (1..8).
type AllocateStatPacket struct {
	PlayerID uint32
	StatID   uint8
	Amount   uint16 // Quantidade de pontos (0 = 1)
}

// SerializeAllocateStat cria o payload de 8 bytes do pacote ALLOCATE_STAT.
func SerializeAllocateStat(playerID uint32, statID uint8, amount ...uint16) [AllocateStatPacketSize]byte {
	var b [AllocateStatPacketSize]byte
	b[0] = PacketTypeAllocateStat
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = statID
	amt := uint16(1)
	if len(amount) > 0 && amount[0] > 0 {
		amt = amount[0]
	}
	binary.LittleEndian.PutUint16(b[6:8], amt)
	return b
}

// DeserializeAllocateStat decodifica o pacote ALLOCATE_STAT (8 bytes; aceita o legado de 6 com Amount = 1).
func DeserializeAllocateStat(data []byte, out *AllocateStatPacket) error {
	if len(data) < 6 {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeAllocateStat {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.StatID = data[5]
	out.Amount = 1
	if len(data) >= AllocateStatPacketSize {
		if a := binary.LittleEndian.Uint16(data[6:8]); a > 0 {
			out.Amount = a
		}
	}
	return nil
}

// --- 0x36: PLAYER_RESPAWN (TCP/UDP: Server -> Client, 17 bytes) ---

// PlayerRespawnPacket representa o pacote autoritativo transmitido quando o jogador renasce no centro ou cai no void.
type PlayerRespawnPacket struct {
	PlayerID uint32
	PosX     float32
	PosY     float32
	PosZ     float32
}

// SerializePlayerRespawn cria o payload de 17 bytes do pacote PLAYER_RESPAWN.
func SerializePlayerRespawn(playerID uint32, posX, posY, posZ float32) [PlayerRespawnPacketSize]byte {
	var b [PlayerRespawnPacketSize]byte
	b[0] = PacketTypePlayerRespawn
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	binary.LittleEndian.PutUint32(b[5:9], math.Float32bits(posX))
	binary.LittleEndian.PutUint32(b[9:13], math.Float32bits(posY))
	binary.LittleEndian.PutUint32(b[13:17], math.Float32bits(posZ))
	return b
}

// DeserializePlayerRespawn decodifica o pacote PLAYER_RESPAWN (17 bytes).
func DeserializePlayerRespawn(data []byte, out *PlayerRespawnPacket) error {
	if len(data) < PlayerRespawnPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePlayerRespawn {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[5:9]))
	out.PosY = math.Float32frombits(binary.LittleEndian.Uint32(data[9:13]))
	out.PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[13:17]))
	return nil
}

// --- 0x14: MOB_SNAPSHOT (UDP: Server -> Clients) ---

// MobSnapshot representa o estado de um monstro na transmissão periódica a 30 Hz.
type MobSnapshot struct {
	MobID   uint32
	MobType uint8
	State   uint8
	PosX    float32
	PosY    float32
	PosZ    float32
	RotY    float32
	HP      uint16
	MaxHP   uint16
}

// SerializeMobSnapshot cria o buffer completo do pacote MOB_SNAPSHOT.
func SerializeMobSnapshot(mobs []MobSnapshot) []byte {
	size := MobSnapshotHeaderSize + len(mobs)*MobSnapshotEntrySize
	buf := make([]byte, size)
	SerializeMobSnapshotInto(buf, mobs)
	return buf
}

// SerializeMobSnapshotInto serializa os dados de mobs diretamente no buffer fornecido.
func SerializeMobSnapshotInto(buf []byte, mobs []MobSnapshot) int {
	buf[0] = PacketTypeMobSnapshot
	buf[1] = uint8(len(mobs))
	offset := MobSnapshotHeaderSize

	for _, m := range mobs {
		binary.LittleEndian.PutUint32(buf[offset:offset+4], m.MobID)
		buf[offset+4] = m.MobType
		buf[offset+5] = m.State
		binary.LittleEndian.PutUint32(buf[offset+6:offset+10], math.Float32bits(m.PosX))
		binary.LittleEndian.PutUint32(buf[offset+10:offset+14], math.Float32bits(m.PosY))
		binary.LittleEndian.PutUint32(buf[offset+14:offset+18], math.Float32bits(m.PosZ))
		binary.LittleEndian.PutUint32(buf[offset+18:offset+22], math.Float32bits(m.RotY))
		binary.LittleEndian.PutUint16(buf[offset+22:offset+24], m.HP)
		binary.LittleEndian.PutUint16(buf[offset+24:offset+26], m.MaxHP)
		offset += MobSnapshotEntrySize
	}
	return offset
}

// DeserializeMobSnapshot decodifica um pacote MOB_SNAPSHOT.
func DeserializeMobSnapshot(data []byte) ([]MobSnapshot, error) {
	if len(data) < MobSnapshotHeaderSize {
		return nil, ErrInvalidPacketSize
	}
	if data[0] != PacketTypeMobSnapshot {
		return nil, ErrInvalidPacketType
	}
	count := int(data[1])
	expectedSize := MobSnapshotHeaderSize + count*MobSnapshotEntrySize
	if len(data) < expectedSize {
		return nil, ErrInvalidPacketSize
	}

	mobs := make([]MobSnapshot, count)
	offset := MobSnapshotHeaderSize
	for i := 0; i < count; i++ {
		mobs[i] = MobSnapshot{
			MobID:   binary.LittleEndian.Uint32(data[offset : offset+4]),
			MobType: data[offset+4],
			State:   data[offset+5],
			PosX:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+6 : offset+10])),
			PosY:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+10 : offset+14])),
			PosZ:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+14 : offset+18])),
			RotY:    math.Float32frombits(binary.LittleEndian.Uint32(data[offset+18 : offset+22])),
			HP:      binary.LittleEndian.Uint16(data[offset+22 : offset+24]),
			MaxHP:   binary.LittleEndian.Uint16(data[offset+24 : offset+26]),
		}
		offset += MobSnapshotEntrySize
	}
	return mobs, nil
}

// --- 0x34: AOE_TELEGRAPH (UDP: Server -> Clients) ---

// AOETelegraphPacket representa o aviso telegrafado de golpe em área no chão.
type AOETelegraphPacket struct {
	SourceID   uint32
	PosX       float32
	PosZ       float32
	Radius     float32
	DurationMs uint16
}

// SerializeAOETelegraph cria o payload de 19 bytes do pacote AOE_TELEGRAPH.
func SerializeAOETelegraph(sourceID uint32, posX, posZ, radius float32, durationMs uint16) [AOETelegraphPacketSize]byte {
	var b [AOETelegraphPacketSize]byte
	b[0] = PacketTypeAOETelegraph
	binary.LittleEndian.PutUint32(b[1:5], sourceID)
	binary.LittleEndian.PutUint32(b[5:9], math.Float32bits(posX))
	binary.LittleEndian.PutUint32(b[9:13], math.Float32bits(posZ))
	binary.LittleEndian.PutUint32(b[13:17], math.Float32bits(radius))
	binary.LittleEndian.PutUint16(b[17:19], durationMs)
	return b
}

// DeserializeAOETelegraph decodifica o pacote AOE_TELEGRAPH (19 bytes).
func DeserializeAOETelegraph(data []byte, out *AOETelegraphPacket) error {
	if len(data) < AOETelegraphPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeAOETelegraph {
		return ErrInvalidPacketType
	}
	out.SourceID = binary.LittleEndian.Uint32(data[1:5])
	out.PosX = math.Float32frombits(binary.LittleEndian.Uint32(data[5:9]))
	out.PosZ = math.Float32frombits(binary.LittleEndian.Uint32(data[9:13]))
	out.Radius = math.Float32frombits(binary.LittleEndian.Uint32(data[13:17]))
	out.DurationMs = binary.LittleEndian.Uint16(data[17:19])
	return nil
}

// Constante de tamanho do pacote PROJECTILE_SPAWN (38 bytes)
const ProjectileSpawnPacketSize = 38

// ProjectileSpawnPacket representa o pacote 0x35 disparado quando um projétil 3D é gerado no mundo.
type ProjectileSpawnPacket struct {
	ProjectileID uint32
	OwnerID      uint32
	ProjType     uint8
	StartX       float32
	StartY       float32
	StartZ       float32
	DirX         float32
	DirZ         float32
	Speed        float32
	MaxRange     float32
}

// SerializeProjectileSpawn empacota os 38 bytes do pacote 0x35 PROJECTILE_SPAWN.
func SerializeProjectileSpawn(projID, ownerID uint32, projType uint8, startX, startY, startZ, dirX, dirZ, speed, maxRange float32) [ProjectileSpawnPacketSize]byte {
	var buf [ProjectileSpawnPacketSize]byte
	buf[0] = PacketTypeProjectileSpawn
	binary.LittleEndian.PutUint32(buf[1:5], projID)
	binary.LittleEndian.PutUint32(buf[5:9], ownerID)
	buf[9] = projType
	binary.LittleEndian.PutUint32(buf[10:14], math.Float32bits(startX))
	binary.LittleEndian.PutUint32(buf[14:18], math.Float32bits(startY))
	binary.LittleEndian.PutUint32(buf[18:22], math.Float32bits(startZ))
	binary.LittleEndian.PutUint32(buf[22:26], math.Float32bits(dirX))
	binary.LittleEndian.PutUint32(buf[26:30], math.Float32bits(dirZ))
	binary.LittleEndian.PutUint32(buf[30:34], math.Float32bits(speed))
	binary.LittleEndian.PutUint32(buf[34:38], math.Float32bits(maxRange))
	return buf
}

// DeserializeProjectileSpawn desempacota os 38 bytes do pacote 0x35.
func DeserializeProjectileSpawn(data []byte, pkt *ProjectileSpawnPacket) error {
	if len(data) < ProjectileSpawnPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeProjectileSpawn {
		return ErrInvalidPacketType
	}
	pkt.ProjectileID = binary.LittleEndian.Uint32(data[1:5])
	pkt.OwnerID = binary.LittleEndian.Uint32(data[5:9])
	pkt.ProjType = data[9]
	pkt.StartX = math.Float32frombits(binary.LittleEndian.Uint32(data[10:14]))
	pkt.StartY = math.Float32frombits(binary.LittleEndian.Uint32(data[14:18]))
	pkt.StartZ = math.Float32frombits(binary.LittleEndian.Uint32(data[18:22]))
	pkt.DirX = math.Float32frombits(binary.LittleEndian.Uint32(data[22:26]))
	pkt.DirZ = math.Float32frombits(binary.LittleEndian.Uint32(data[26:30]))
	pkt.Speed = math.Float32frombits(binary.LittleEndian.Uint32(data[30:34]))
	pkt.MaxRange = math.Float32frombits(binary.LittleEndian.Uint32(data[34:38]))
	return nil
}

// --- 0x38: INVENTORY_SYNC (TCP: Server -> Client) ---

// InventorySlot representa um slot de item com seu identificador e quantidade.
type InventorySlot struct {
	ItemID   uint8
	Quantity uint8
	Quality  uint8 // Qualidade média da pilha (0 a 100)
}

// InventoryStatus traz dinheiro e peso enviados junto com a mochila.
type InventoryStatus struct {
	Gold          uint32
	EclipseCoins  uint32
	CurrentWeight float32
	MaxWeight     float32
	SpeedPercent  uint8 // Multiplicador de velocidade por peso × 100 (0 = sobrecarregado/imóvel)
}

// InventorySyncPacket representa a mochila (uma entrada por item+Qualidade), os 14 slots com a
// Condição de cada um, o dinheiro e o peso.
type InventorySyncPacket struct {
	EquippedSlots       [EquipSlotCount]uint8
	EquippedQualities   [EquipSlotCount]uint8
	EquippedArmorID     uint8 // Helper alias -> EquippedSlots[SlotChest]
	EquippedAccessoryID uint8 // Helper alias -> EquippedSlots[SlotRing1]
	Status              InventoryStatus
	SlotCount           uint16
	Slots               []InventorySlot
}

// SerializeInventorySync empacota o 0x38.
// Layout: op | 14 slots | 14 Condições | Gold u32 | Eclipses u32 | Peso f32 | PesoMáx f32 | Velocidade% u8 |
// count u16 | count × (item, quantidade, Qualidade)
func SerializeInventorySync(equippedSlots, equippedQualities [EquipSlotCount]uint8, status InventoryStatus, slots []InventorySlot) []byte {
	count := len(slots)
	if count > 65535 {
		count = 65535
	}
	buf := make([]byte, InventorySyncHeaderSize+count*InventorySlotEntrySize)
	buf[0] = PacketTypeInventorySync
	for i := 0; i < EquipSlotCount; i++ {
		buf[1+i] = equippedSlots[i]
		buf[15+i] = equippedQualities[i]
	}
	binary.LittleEndian.PutUint32(buf[29:33], status.Gold)
	binary.LittleEndian.PutUint32(buf[33:37], status.EclipseCoins)
	binary.LittleEndian.PutUint32(buf[37:41], math.Float32bits(status.CurrentWeight))
	binary.LittleEndian.PutUint32(buf[41:45], math.Float32bits(status.MaxWeight))
	buf[45] = status.SpeedPercent
	binary.LittleEndian.PutUint16(buf[46:48], uint16(count))
	offset := InventorySyncHeaderSize
	for i := 0; i < count; i++ {
		buf[offset] = slots[i].ItemID
		buf[offset+1] = slots[i].Quantity
		buf[offset+2] = slots[i].Quality
		offset += InventorySlotEntrySize
	}
	return buf
}

// SerializeInventorySyncLegacy serializa com apenas peitoral e anel preenchidos (testes/compatibilidade).
func SerializeInventorySyncLegacy(equippedArmorID, equippedAccessoryID uint8, slots []InventorySlot) []byte {
	var eq, q [EquipSlotCount]uint8
	eq[SlotChest] = equippedArmorID
	eq[SlotRing1] = equippedAccessoryID
	return SerializeInventorySync(eq, q, InventoryStatus{SpeedPercent: 100}, slots)
}

// DeserializeInventorySync desempacota o pacote 0x38 INVENTORY_SYNC.
func DeserializeInventorySync(data []byte, out *InventorySyncPacket) error {
	if len(data) < InventorySyncHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeInventorySync {
		return ErrInvalidPacketType
	}
	for i := 0; i < EquipSlotCount; i++ {
		out.EquippedSlots[i] = data[1+i]
		out.EquippedQualities[i] = data[15+i]
	}
	out.EquippedArmorID = out.EquippedSlots[SlotChest]
	out.EquippedAccessoryID = out.EquippedSlots[SlotRing1]
	out.Status.Gold = binary.LittleEndian.Uint32(data[29:33])
	out.Status.EclipseCoins = binary.LittleEndian.Uint32(data[33:37])
	out.Status.CurrentWeight = math.Float32frombits(binary.LittleEndian.Uint32(data[37:41]))
	out.Status.MaxWeight = math.Float32frombits(binary.LittleEndian.Uint32(data[41:45]))
	out.Status.SpeedPercent = data[45]
	out.SlotCount = binary.LittleEndian.Uint16(data[46:48])
	if len(data) < InventorySyncHeaderSize+int(out.SlotCount)*InventorySlotEntrySize {
		return ErrInvalidPacketSize
	}
	out.Slots = make([]InventorySlot, out.SlotCount)
	offset := InventorySyncHeaderSize
	for i := range out.Slots {
		out.Slots[i] = InventorySlot{ItemID: data[offset], Quantity: data[offset+1], Quality: data[offset+2]}
		offset += InventorySlotEntrySize
	}
	return nil
}

// --- 0x39: USE_OR_EQUIP_ITEM (TCP: Client -> Server, 6 bytes) ---

// UseOrEquipItemPacket representa a solicitação do cliente para usar consumível ou equipar armadura/acessório.
type UseOrEquipItemPacket struct {
	PlayerID  uint32
	ItemID    uint8
	Action    uint8 // ItemActionUse ou ItemActionUnequip
	SlotIndex uint8 // Slot (0..13) para ItemActionUnequip
}

// SerializeUseOrEquipItem cria o payload de 8 bytes do pacote USE_OR_EQUIP_ITEM.
func SerializeUseOrEquipItem(playerID uint32, itemID uint8, actionAndSlot ...uint8) [UseOrEquipItemPacketSize]byte {
	var b [UseOrEquipItemPacketSize]byte
	b[0] = PacketTypeUseOrEquipItem
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = itemID
	if len(actionAndSlot) > 0 {
		b[6] = actionAndSlot[0]
	}
	if len(actionAndSlot) > 1 {
		b[7] = actionAndSlot[1]
	}
	return b
}

// DeserializeUseOrEquipItem decodifica o pacote USE_OR_EQUIP_ITEM (8 bytes; aceita o legado de 6).
func DeserializeUseOrEquipItem(data []byte, out *UseOrEquipItemPacket) error {
	if len(data) < 6 {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeUseOrEquipItem {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.ItemID = data[5]
	out.Action, out.SlotIndex = ItemActionUse, 0
	if len(data) >= UseOrEquipItemPacketSize {
		out.Action = data[6]
		out.SlotIndex = data[7]
	}
	return nil
}

// --- 0x41: DROP_ITEM_GROUND / 0x42: GROUND_ITEMS_SYNC / 0x43: PICKUP_GROUND_ITEM ---

// DropItemGroundPacket: o cliente descarta Quantity unidades do item com a Qualidade indicada.
type DropItemGroundPacket struct {
	PlayerID uint32
	ItemID   uint8
	Quality  uint8
	Quantity uint8
}

func SerializeDropItemGround(playerID uint32, itemID, quality, quantity uint8) [DropItemGroundPacketSize]byte {
	var b [DropItemGroundPacketSize]byte
	b[0] = PacketTypeDropItemGround
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	b[5] = itemID
	b[6] = quality
	b[7] = quantity
	return b
}

func DeserializeDropItemGround(data []byte, out *DropItemGroundPacket) error {
	if len(data) < DropItemGroundPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeDropItemGround {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.ItemID = data[5]
	out.Quality = data[6]
	out.Quantity = data[7]
	return nil
}

// PickupGroundItemPacket: o cliente pede para pegar o item DropID do chão.
type PickupGroundItemPacket struct {
	PlayerID uint32
	DropID   uint32
}

func SerializePickupGroundItem(playerID, dropID uint32) [PickupGroundItemPacketSize]byte {
	var b [PickupGroundItemPacketSize]byte
	b[0] = PacketTypePickupGroundItem
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	binary.LittleEndian.PutUint32(b[5:9], dropID)
	return b
}

func DeserializePickupGroundItem(data []byte, out *PickupGroundItemPacket) error {
	if len(data) < PickupGroundItemPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypePickupGroundItem {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.DropID = binary.LittleEndian.Uint32(data[5:9])
	return nil
}

// GroundItemEntry é um item visível no chão (0x42).
type GroundItemEntry struct {
	DropID   uint32
	ItemID   uint8
	Quantity uint8
	Quality  uint8
	X, Z     float32
}

// SerializeGroundItemsSync: op | count u16 | count × (dropID u32, item, qtd, X f32, Z f32)
func SerializeGroundItemsSync(items []GroundItemEntry) []byte {
	count := len(items)
	if count > 65535 {
		count = 65535
	}
	buf := make([]byte, 3+count*GroundItemEntrySize)
	buf[0] = PacketTypeGroundItemsSync
	binary.LittleEndian.PutUint16(buf[1:3], uint16(count))
	off := 3
	for i := 0; i < count; i++ {
		it := items[i]
		binary.LittleEndian.PutUint32(buf[off:off+4], it.DropID)
		buf[off+4] = it.ItemID
		buf[off+5] = it.Quantity
		buf[off+6] = it.Quality
		binary.LittleEndian.PutUint32(buf[off+7:off+11], math.Float32bits(it.X))
		binary.LittleEndian.PutUint32(buf[off+11:off+15], math.Float32bits(it.Z))
		off += GroundItemEntrySize
	}
	return buf
}

// DeserializeGroundItemsSync decodifica o 0x42.
func DeserializeGroundItemsSync(data []byte) ([]GroundItemEntry, error) {
	if len(data) < 3 {
		return nil, ErrInvalidPacketSize
	}
	if data[0] != PacketTypeGroundItemsSync {
		return nil, ErrInvalidPacketType
	}
	count := int(binary.LittleEndian.Uint16(data[1:3]))
	if len(data) < 3+count*GroundItemEntrySize {
		return nil, ErrInvalidPacketSize
	}
	items := make([]GroundItemEntry, count)
	off := 3
	for i := range items {
		items[i].DropID = binary.LittleEndian.Uint32(data[off : off+4])
		items[i].ItemID = data[off+4]
		items[i].Quantity = data[off+5]
		items[i].Quality = data[off+6]
		items[i].X = math.Float32frombits(binary.LittleEndian.Uint32(data[off+7 : off+11]))
		items[i].Z = math.Float32frombits(binary.LittleEndian.Uint32(data[off+11 : off+15]))
		off += GroundItemEntrySize
	}
	return items, nil
}

// --- 0x40: EVOLUTION_OFFER (TCP: Server -> Client / Client -> Server, 4 bytes) ---

// Tipos de Oferta do Pacote 0x40 EVOLUTION_OFFER
const (
	OfferTypeRace           uint8 = 1 // Evolução de Raça (Nível 10+)
	OfferTypeBasicClass     uint8 = 2 // Evolução de Classe Básica (Nível 10, 25, 45)
	OfferTypeLegendaryTrial uint8 = 3 // Provação Lendária (Tier 5 -> Tier 6 Nível 45+)
	OfferTypeIdentityChange uint8 = 4 // Troca de Classe/Raça oferecida pelo servidor (A = ClassID, B = RaceID); o cliente confirma no modal
)

const EvolutionOfferPacketSize = 4

// EvolutionOfferPacket representa a proposta da entidade divina/maligna ou avanço de classe.
type EvolutionOfferPacket struct {
	OfferType uint8
	OptionAID uint8
	OptionBID uint8
}

// SerializeEvolutionOffer serializa o pacote 0x40 EVOLUTION_OFFER (4 bytes).
func SerializeEvolutionOffer(offerType, optA, optB uint8) [EvolutionOfferPacketSize]byte {
	return [EvolutionOfferPacketSize]byte{
		PacketTypeEvolutionOffer,
		offerType,
		optA,
		optB,
	}
}

// DeserializeEvolutionOffer decodifica o pacote 0x40 EVOLUTION_OFFER.
func DeserializeEvolutionOffer(data []byte, out *EvolutionOfferPacket) error {
	if len(data) < EvolutionOfferPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeEvolutionOffer {
		return ErrInvalidPacketType
	}
	out.OfferType = data[1]
	out.OptionAID = data[2]
	out.OptionBID = data[3]
	return nil
}

// --- 0x3A: DEV_GET_DROP_RATES (TCP: Client -> Server / Server -> Client) ---

const DevGetDropRatesPacketSize = 5

// DevGetDropRatesPacket representa a solicitação do desenvolvedor para obter a tabela de taxas de drop.
type DevGetDropRatesPacket struct {
	PlayerID uint32
}

// SerializeDevGetDropRatesRequest cria a requisição de 5 bytes do cliente.
func SerializeDevGetDropRatesRequest(playerID uint32) [DevGetDropRatesPacketSize]byte {
	var b [DevGetDropRatesPacketSize]byte
	b[0] = PacketTypeDevGetDropRates
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	return b
}

// DeserializeDevGetDropRatesRequest decodifica a requisição 0x3A.
func DeserializeDevGetDropRatesRequest(data []byte, out *DevGetDropRatesPacket) error {
	if len(data) < DevGetDropRatesPacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeDevGetDropRates {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	return nil
}

// SerializeDevGetDropRatesResponse cria a resposta serializada contendo o relatório em string.
func SerializeDevGetDropRatesResponse(report string) []byte {
	b := []byte(report)
	l := len(b)
	if l > 65535 {
		l = 65535
		b = b[:65535]
	}
	buf := make([]byte, 3+l)
	buf[0] = PacketTypeDevGetDropRates
	binary.LittleEndian.PutUint16(buf[1:3], uint16(l))
	copy(buf[3:], b)
	return buf
}

// DeserializeDevGetDropRatesResponse decodifica o relatório recebido.
func DeserializeDevGetDropRatesResponse(data []byte) (string, error) {
	if len(data) < 3 {
		return "", ErrInvalidPacketSize
	}
	if data[0] != PacketTypeDevGetDropRates {
		return "", ErrInvalidPacketType
	}
	l := binary.LittleEndian.Uint16(data[1:3])
	if len(data) < 3+int(l) {
		return "", ErrInvalidPacketSize
	}
	return string(data[3 : 3+l]), nil
}

// --- 0x3B: INTERACT_CORPSE (TCP: Client -> Server) ---

// InteractCorpsePacket representa a solicitação para inspecionar um cadáver no chão.
type InteractCorpsePacket struct {
	PlayerID uint32
	CorpseID uint32
}

// SerializeInteractCorpse empacota o pacote 0x3B INTERACT_CORPSE (9 bytes).
func SerializeInteractCorpse(playerID, corpseID uint32) [InteractCorpsePacketSize]byte {
	var b [InteractCorpsePacketSize]byte
	b[0] = PacketTypeInteractCorpse
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	binary.LittleEndian.PutUint32(b[5:9], corpseID)
	return b
}

// DeserializeInteractCorpse decodifica o pacote 0x3B INTERACT_CORPSE.
func DeserializeInteractCorpse(data []byte, out *InteractCorpsePacket) error {
	if len(data) < InteractCorpsePacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeInteractCorpse {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.CorpseID = binary.LittleEndian.Uint32(data[5:9])
	return nil
}

// --- 0x3C: OPEN_AUTOPSY_UI (TCP: Server -> Client) ---

// AutopsyOrganEntry representa um ponto vital passível de extração no mini-game de autópsia.
type AutopsyOrganEntry struct {
	OrganIndex  uint8
	OrganType   uint8
	ItemReward  uint8
	Difficulty  uint8
	QualityTier uint8
}

// OpenAutopsyUIPacket instrui o cliente a abrir a interface do mini-game anatômico.
type OpenAutopsyUIPacket struct {
	CorpseID       uint32
	MobType        uint8
	DifficultySeed uint32
	OrganCount     uint8
	Organs         []AutopsyOrganEntry
}

// SerializeOpenAutopsyUI empacota o pacote 0x3C OPEN_AUTOPSY_UI.
func SerializeOpenAutopsyUI(corpseID uint32, mobType uint8, difficultySeed uint32, organs []AutopsyOrganEntry) []byte {
	count := len(organs)
	if count > 255 {
		count = 255
	}
	totalSize := OpenAutopsyUIHeaderSize + count*AutopsyOrganEntrySize
	buf := make([]byte, totalSize)
	buf[0] = PacketTypeOpenAutopsyUI
	binary.LittleEndian.PutUint32(buf[1:5], corpseID)
	buf[5] = mobType
	binary.LittleEndian.PutUint32(buf[6:10], difficultySeed)
	buf[10] = uint8(count)

	offset := OpenAutopsyUIHeaderSize
	for i := 0; i < count; i++ {
		buf[offset] = organs[i].OrganIndex
		buf[offset+1] = organs[i].OrganType
		buf[offset+2] = organs[i].ItemReward
		buf[offset+3] = organs[i].Difficulty
		buf[offset+4] = organs[i].QualityTier
		offset += AutopsyOrganEntrySize
	}
	return buf
}

// DeserializeOpenAutopsyUI decodifica o pacote 0x3C OPEN_AUTOPSY_UI.
func DeserializeOpenAutopsyUI(data []byte, out *OpenAutopsyUIPacket) error {
	if len(data) < OpenAutopsyUIHeaderSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeOpenAutopsyUI {
		return ErrInvalidPacketType
	}
	out.CorpseID = binary.LittleEndian.Uint32(data[1:5])
	out.MobType = data[5]
	out.DifficultySeed = binary.LittleEndian.Uint32(data[6:10])
	out.OrganCount = data[10]

	expectedSize := OpenAutopsyUIHeaderSize + int(out.OrganCount)*AutopsyOrganEntrySize
	if len(data) < expectedSize {
		return ErrInvalidPacketSize
	}

	out.Organs = make([]AutopsyOrganEntry, out.OrganCount)
	offset := OpenAutopsyUIHeaderSize
	for i := 0; i < int(out.OrganCount); i++ {
		out.Organs[i] = AutopsyOrganEntry{
			OrganIndex:  data[offset],
			OrganType:   data[offset+1],
			ItemReward:  data[offset+2],
			Difficulty:  data[offset+3],
			QualityTier: data[offset+4],
		}
		offset += AutopsyOrganEntrySize
	}
	return nil
}

// --- 0x3D: SUBMIT_AUTOPSY_RESULT (TCP: Client -> Server) ---

// SubmitAutopsyResultPacket representa o envio do resultado do corte do mini-game.
type SubmitAutopsyResultPacket struct {
	PlayerID   uint32
	CorpseID   uint32
	OrganIndex uint8
	ResultTier uint8
	Quality    uint8 // Qualidade 0-100 medida no minigame
}

// SerializeSubmitAutopsyResult empacota o pacote 0x3D SUBMIT_AUTOPSY_RESULT.
func SerializeSubmitAutopsyResult(playerID, corpseID uint32, organIndex, resultTier uint8, quality ...uint8) [SubmitAutopsyResultPacketSize]byte {
	var b [SubmitAutopsyResultPacketSize]byte
	b[0] = PacketTypeSubmitAutopsyResult
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	binary.LittleEndian.PutUint32(b[5:9], corpseID)
	b[9] = organIndex
	b[10] = resultTier
	if len(quality) > 0 {
		b[11] = quality[0]
	} else {
		b[11] = QualityFromTier(resultTier)
	}
	return b
}

// QualityFromTier converte o tier antigo em Qualidade (compatibilidade com clientes sem minigame novo).
func QualityFromTier(tier uint8) uint8 {
	switch tier {
	case QualityPerfect:
		return 90
	case QualityCommon:
		return 60
	}
	return 10
}

// DeserializeSubmitAutopsyResult decodifica o pacote 0x3D SUBMIT_AUTOPSY_RESULT.
func DeserializeSubmitAutopsyResult(data []byte, out *SubmitAutopsyResultPacket) error {
	if len(data) < 6 {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeSubmitAutopsyResult {
		return ErrInvalidPacketType
	}
	if len(data) >= 11 {
		out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
		out.CorpseID = binary.LittleEndian.Uint32(data[5:9])
		out.OrganIndex = data[9]
		out.ResultTier = data[10]
		out.Quality = QualityFromTier(out.ResultTier)
		if len(data) >= SubmitAutopsyResultPacketSize {
			out.Quality = data[11]
		}
	} else {
		// Compatibilidade com payload compacto
		out.CorpseID = binary.LittleEndian.Uint32(data[1:5])
		out.ResultTier = data[5]
		out.OrganIndex = 0
	}
	return nil
}

// --- 0x3E: CORPSE_SNAPSHOT (TCP: Server -> Client) ---

// CorpseSnapshot representa a posição e status de um cadáver no mapa.
type CorpseSnapshot struct {
	CorpseID         uint32
	MobID            uint32
	MobType          uint8
	PosX             float32
	PosY             float32
	PosZ             float32
	RotY             float32
	IsLooted         bool
	RemainingSeconds uint16
}

// SerializeCorpseSnapshot empacota a lista de cadáveres visíveis no pacote 0x3E CORPSE_SNAPSHOT.
func SerializeCorpseSnapshot(corpses []CorpseSnapshot) []byte {
	count := len(corpses)
	if count > 255 {
		count = 255
	}
	size := CorpseSnapshotHeaderSize + count*CorpseSnapshotEntrySize
	buf := make([]byte, size)
	buf[0] = PacketTypeCorpseSnapshot
	buf[1] = uint8(count)
	offset := CorpseSnapshotHeaderSize
	for i := 0; i < count; i++ {
		c := corpses[i]
		binary.LittleEndian.PutUint32(buf[offset:offset+4], c.CorpseID)
		binary.LittleEndian.PutUint32(buf[offset+4:offset+8], c.MobID)
		buf[offset+8] = c.MobType
		binary.LittleEndian.PutUint32(buf[offset+9:offset+13], math.Float32bits(c.PosX))
		binary.LittleEndian.PutUint32(buf[offset+13:offset+17], math.Float32bits(c.PosY))
		binary.LittleEndian.PutUint32(buf[offset+17:offset+21], math.Float32bits(c.PosZ))
		binary.LittleEndian.PutUint32(buf[offset+21:offset+25], math.Float32bits(c.RotY))
		if c.IsLooted {
			buf[offset+25] = 1
		} else {
			buf[offset+25] = 0
		}
		binary.LittleEndian.PutUint16(buf[offset+26:offset+28], c.RemainingSeconds)
		offset += CorpseSnapshotEntrySize
	}
	return buf
}

// DeserializeCorpseSnapshot decodifica o pacote 0x3E CORPSE_SNAPSHOT.
func DeserializeCorpseSnapshot(data []byte) ([]CorpseSnapshot, error) {
	if len(data) < CorpseSnapshotHeaderSize {
		return nil, ErrInvalidPacketSize
	}
	if data[0] != PacketTypeCorpseSnapshot {
		return nil, ErrInvalidPacketType
	}
	count := int(data[1])
	expectedSize := CorpseSnapshotHeaderSize + count*CorpseSnapshotEntrySize
	if len(data) < expectedSize {
		return nil, ErrInvalidPacketSize
	}
	res := make([]CorpseSnapshot, count)
	offset := CorpseSnapshotHeaderSize
	for i := 0; i < count; i++ {
		res[i] = CorpseSnapshot{
			CorpseID:         binary.LittleEndian.Uint32(data[offset : offset+4]),
			MobID:            binary.LittleEndian.Uint32(data[offset+4 : offset+8]),
			MobType:          data[offset+8],
			PosX:             math.Float32frombits(binary.LittleEndian.Uint32(data[offset+9 : offset+13])),
			PosY:             math.Float32frombits(binary.LittleEndian.Uint32(data[offset+13 : offset+17])),
			PosZ:             math.Float32frombits(binary.LittleEndian.Uint32(data[offset+17 : offset+21])),
			RotY:             math.Float32frombits(binary.LittleEndian.Uint32(data[offset+21 : offset+25])),
			IsLooted:         data[offset+25] != 0,
			RemainingSeconds: binary.LittleEndian.Uint16(data[offset+26 : offset+28]),
		}
		offset += CorpseSnapshotEntrySize
	}
	return res, nil
}

// FriendshipSyncPacket transporta pontos e nível de afiança entre jogador e NPC.
type FriendshipSyncPacket struct {
	NPCID  uint32
	Points uint16
	Level  uint8
}

// SerializeFriendshipSync empacota os dados de afiança para envio ao cliente (8 bytes).
func SerializeFriendshipSync(npcID uint32, points uint16, level uint8) []byte {
	buf := make([]byte, 8)
	buf[0] = PacketTypeFriendshipSync
	binary.BigEndian.PutUint32(buf[1:5], npcID)
	binary.BigEndian.PutUint16(buf[5:7], points)
	buf[7] = level
	return buf
}

// DeserializeFriendshipSync decodifica os dados de afiança do payload (8 bytes).
func DeserializeFriendshipSync(data []byte) (FriendshipSyncPacket, error) {
	if len(data) < 8 {
		return FriendshipSyncPacket{}, errors.New("tamanho insuficiente para FriendshipSyncPacket (esperado 8 bytes)")
	}
	if data[0] != PacketTypeFriendshipSync {
		return FriendshipSyncPacket{}, errors.New("opcode invalido para FriendshipSyncPacket")
	}
	return FriendshipSyncPacket{
		NPCID:  binary.BigEndian.Uint32(data[1:5]),
		Points: binary.BigEndian.Uint16(data[5:7]),
		Level:  data[7],
	}, nil
}

// IsUniqueClass informa se a classe é Única (Tier 5): exclusivas de raça (19-26) e gerais (27-30, 35-39).
func IsUniqueClass(classID uint8) bool {
	return (classID >= ClassVorpalExecutioner && classID <= ClassBoneNecromancer) ||
		(classID >= ClassRunicArtificer && classID <= ClassStormHerald)
}

// IsLegendaryClass informa se a classe é Lendária (Tier 6, IDs 31 a 34).
func IsLegendaryClass(classID uint8) bool {
	return classID >= ClassPagmaDescendant && classID <= ClassBlackSunEmperor
}

// IsTranscendentClass informa se a classe reseta o nível ao ser assumida (Únicas e Lendárias, ID >= 19).
func IsTranscendentClass(classID uint8) bool {
	return IsUniqueClass(classID) || IsLegendaryClass(classID)
}

// --- 0x44: HARVEST_NODE / 0x45: RESOURCE_NODES_SYNC / 0x46: DISCOVERED_MATERIALS ---

const (
	HarvestNodePacketSize = 9  // op (1) + playerID u32 (4) + nodeID u32 (4)
	ResourceNodeEntrySize = 16 // nodeID u32 + kind u8 + material u8 + tier u8 + available u8 + X f32 + Z f32
)

// HarvestNodePacket: o cliente pede para coletar o nó NodeID.
type HarvestNodePacket struct {
	PlayerID uint32
	NodeID   uint32
}

func SerializeHarvestNode(playerID, nodeID uint32) [HarvestNodePacketSize]byte {
	var b [HarvestNodePacketSize]byte
	b[0] = PacketTypeHarvestNode
	binary.LittleEndian.PutUint32(b[1:5], playerID)
	binary.LittleEndian.PutUint32(b[5:9], nodeID)
	return b
}

func DeserializeHarvestNode(data []byte, out *HarvestNodePacket) error {
	if len(data) < HarvestNodePacketSize {
		return ErrInvalidPacketSize
	}
	if data[0] != PacketTypeHarvestNode {
		return ErrInvalidPacketType
	}
	out.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	out.NodeID = binary.LittleEndian.Uint32(data[5:9])
	return nil
}

// ResourceNodeEntry é um nó de coleta visível na zona.
type ResourceNodeEntry struct {
	NodeID    uint32
	Kind      uint8
	Material  uint8
	Tier      uint8
	Available bool
	X, Z      float32
}

// SerializeResourceNodesSync: op | count u16 | count × entrada (16 bytes)
func SerializeResourceNodesSync(nodes []ResourceNodeEntry) []byte {
	count := len(nodes)
	if count > 65535 {
		count = 65535
	}
	buf := make([]byte, 3+count*ResourceNodeEntrySize)
	buf[0] = PacketTypeResourceNodesSync
	binary.LittleEndian.PutUint16(buf[1:3], uint16(count))
	off := 3
	for i := 0; i < count; i++ {
		n := nodes[i]
		binary.LittleEndian.PutUint32(buf[off:off+4], n.NodeID)
		buf[off+4] = n.Kind
		buf[off+5] = n.Material
		buf[off+6] = n.Tier
		if n.Available {
			buf[off+7] = 1
		}
		binary.LittleEndian.PutUint32(buf[off+8:off+12], math.Float32bits(n.X))
		binary.LittleEndian.PutUint32(buf[off+12:off+16], math.Float32bits(n.Z))
		off += ResourceNodeEntrySize
	}
	return buf
}

func DeserializeResourceNodesSync(data []byte) ([]ResourceNodeEntry, error) {
	if len(data) < 3 || data[0] != PacketTypeResourceNodesSync {
		return nil, ErrInvalidPacketSize
	}
	count := int(binary.LittleEndian.Uint16(data[1:3]))
	if len(data) < 3+count*ResourceNodeEntrySize {
		return nil, ErrInvalidPacketSize
	}
	out := make([]ResourceNodeEntry, count)
	off := 3
	for i := range out {
		out[i].NodeID = binary.LittleEndian.Uint32(data[off : off+4])
		out[i].Kind = data[off+4]
		out[i].Material = data[off+5]
		out[i].Tier = data[off+6]
		out[i].Available = data[off+7] == 1
		out[i].X = math.Float32frombits(binary.LittleEndian.Uint32(data[off+8 : off+12]))
		out[i].Z = math.Float32frombits(binary.LittleEndian.Uint32(data[off+12 : off+16]))
		off += ResourceNodeEntrySize
	}
	return out, nil
}

// Modos do 0x46
const (
	DiscoveredModeFull uint8 = 0 // lista completa (login)
	DiscoveredModeNew  uint8 = 1 // apenas as descobertas novas (mostra o aviso dourado)
)

// SerializeDiscoveredMaterials: op | modo u8 | count u16 | count × materialID u16
func SerializeDiscoveredMaterials(mode uint8, ids []uint16) []byte {
	count := len(ids)
	buf := make([]byte, 4+count*2)
	buf[0] = PacketTypeDiscoveredMaterials
	buf[1] = mode
	binary.LittleEndian.PutUint16(buf[2:4], uint16(count))
	for i, id := range ids {
		binary.LittleEndian.PutUint16(buf[4+i*2:6+i*2], id)
	}
	return buf
}

func DeserializeDiscoveredMaterials(data []byte) (uint8, []uint16, error) {
	if len(data) < 4 || data[0] != PacketTypeDiscoveredMaterials {
		return 0, nil, ErrInvalidPacketSize
	}
	count := int(binary.LittleEndian.Uint16(data[2:4]))
	if len(data) < 4+count*2 {
		return 0, nil, ErrInvalidPacketSize
	}
	ids := make([]uint16, count)
	for i := range ids {
		ids[i] = binary.LittleEndian.Uint16(data[4+i*2 : 6+i*2])
	}
	return data[1], ids, nil
}

// --- 0x47: QUEST_STATE (TCP: Server -> Client, 5 bytes) ---
// op | questID | etapa (0 = não iniciada, 1..N = em andamento, 255 = concluída) | tem | precisa

const QuestStatePacketSize = 5

func SerializeQuestState(questID, stage, have, need uint8) [QuestStatePacketSize]byte {
	return [QuestStatePacketSize]byte{PacketTypeQuestState, questID, stage, have, need}
}

// --- 0x48: SHOP_REQUEST / 0x49: SHOP_TRADE / 0x4A: SHOP_STATE (Mundo Vivo) ---

const (
	ShopRequestPacketSize       = 9  // op | playerID u32 | npcID u32
	ShopTradePacketSize         = 13 // op | playerID u32 | npcID u32 | ação | item | qualidade | qtd
	ShopActionBuy         uint8 = 0
	ShopActionSell        uint8 = 1
)

type ShopRequestPacket struct {
	PlayerID uint32
	NPCID    uint32
}

type ShopTradePacket struct {
	PlayerID uint32
	NPCID    uint32
	Action   uint8
	ItemID   uint8
	Quality  uint8
	Qty      uint8
}

func DeserializeShopRequest(data []byte, pkt *ShopRequestPacket) error {
	if len(data) < ShopRequestPacketSize || data[0] != PacketTypeShopRequest {
		return ErrInvalidPacketSize
	}
	pkt.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	pkt.NPCID = binary.LittleEndian.Uint32(data[5:9])
	return nil
}

func DeserializeShopTrade(data []byte, pkt *ShopTradePacket) error {
	if len(data) < ShopTradePacketSize || data[0] != PacketTypeShopTrade {
		return ErrInvalidPacketSize
	}
	pkt.PlayerID = binary.LittleEndian.Uint32(data[1:5])
	pkt.NPCID = binary.LittleEndian.Uint32(data[5:9])
	pkt.Action, pkt.ItemID, pkt.Quality, pkt.Qty = data[9], data[10], data[11], data[12]
	return nil
}

type ShopStockEntry struct {
	ItemID uint8
	Qty    uint8
	Price  uint32
}

type ShopOrderEntry struct {
	Material uint16
	Wanted   uint8
	Price    uint32
}

type ShopState struct {
	NPCID                uint32
	Gold                 uint32
	HP, MaxHP            uint16
	Hunger, Thirst, Cold uint8
	Heat                 uint8
	Temperature          int8 // °C sentidos
	Activity             string
	Stock                []ShopStockEntry
	Orders               []ShopOrderEntry
}

// SerializeShopState: op | tamanho u16 | npc u32 | ouro u32 | hp u16 | maxhp u16 | fome | sede | frio | calor | temp °C i8 |
// lenAtividade u8 + texto | nEstoque u8 + (item u8, qtd u8, preço u32)* | nEncomendas u8 + (mat u16, qtd u8, preço u32)*
func SerializeShopState(st ShopState) []byte {
	act := []byte(st.Activity)
	if len(act) > 255 {
		act = act[:255]
	}
	if len(st.Stock) > 255 {
		st.Stock = st.Stock[:255]
	}
	if len(st.Orders) > 255 {
		st.Orders = st.Orders[:255]
	}
	b := make([]byte, 3, 32+len(act)+6*len(st.Stock)+7*len(st.Orders))
	b[0] = PacketTypeShopState
	b = binary.LittleEndian.AppendUint32(b, st.NPCID)
	b = binary.LittleEndian.AppendUint32(b, st.Gold)
	b = binary.LittleEndian.AppendUint16(b, st.HP)
	b = binary.LittleEndian.AppendUint16(b, st.MaxHP)
	b = append(b, st.Hunger, st.Thirst, st.Cold, st.Heat, uint8(st.Temperature), uint8(len(act)))
	b = append(b, act...)
	b = append(b, uint8(len(st.Stock)))
	for _, e := range st.Stock {
		b = append(b, e.ItemID, e.Qty)
		b = binary.LittleEndian.AppendUint32(b, e.Price)
	}
	b = append(b, uint8(len(st.Orders)))
	for _, o := range st.Orders {
		b = binary.LittleEndian.AppendUint16(b, o.Material)
		b = append(b, o.Wanted)
		b = binary.LittleEndian.AppendUint32(b, o.Price)
	}
	binary.LittleEndian.PutUint16(b[1:3], uint16(len(b)))
	return b
}

// --- 0x4B: SET_PK_MODE / 0x4C: NPC_CONTRACT / 0x4D-0x4E: TÚMULOS (Mundo Vivo, Parte 2) ---

const (
	SetPKModePacketSize   = 2 // op | 0 = pacífico, 1 = hostil
	NPCContractPacketSize = 6 // op | npcID u32 | ação
	TombstoneRequestSize  = 1

	ContractHire    uint8 = 0 // contratar (500 Sollares + 3 corações): passa a seguir o jogador
	ContractTrain   uint8 = 1 // treinar aprendiz (300 Sollares ou Pergaminho de Blueprint)
	ContractSettle  uint8 = 2 // assentar o contratado aqui (nova casa e território)
	ContractDismiss uint8 = 3 // dispensar (volta para a casa que tinha)
)

type NPCContractPacket struct {
	NPCID  uint32
	Action uint8
}

func DeserializeNPCContract(data []byte, pkt *NPCContractPacket) error {
	if len(data) < NPCContractPacketSize || data[0] != PacketTypeNPCContract {
		return ErrInvalidPacketSize
	}
	pkt.NPCID = binary.LittleEndian.Uint32(data[1:5])
	pkt.Action = data[5]
	return nil
}

type TombstoneEntry struct {
	NPCID                    uint32
	Zone                     uint8
	X, Z                     float32
	Name, Profession, Killer string
}

func appendShortString(b []byte, s string) []byte {
	if len(s) > 255 {
		s = s[:255]
	}
	b = append(b, uint8(len(s)))
	return append(b, s...)
}

// SerializeTombstones: op | tamanho u16 | n u8 | (npc u32, zona u8, x f32, z f32, nome, ofício, assassino)*
// (textos: len u8 + bytes)
func SerializeTombstones(list []TombstoneEntry) []byte {
	if len(list) > 255 {
		list = list[len(list)-255:]
	}
	b := []byte{PacketTypeTombstoneState, 0, 0, uint8(len(list))}
	for _, t := range list {
		b = binary.LittleEndian.AppendUint32(b, t.NPCID)
		b = append(b, t.Zone)
		b = binary.LittleEndian.AppendUint32(b, math.Float32bits(t.X))
		b = binary.LittleEndian.AppendUint32(b, math.Float32bits(t.Z))
		b = appendShortString(b, t.Name)
		b = appendShortString(b, t.Profession)
		b = appendShortString(b, t.Killer)
	}
	binary.LittleEndian.PutUint16(b[1:3], uint16(len(b)))
	return b
}

// --- 0x4F: CORPSE_RITE (Client -> Server, 7 bytes) ---
// op | alvo (0 = cadáver de criatura, 1 = corpo/cova de NPC) | id u32 | rito (0 = purificar, 1 = reviver como zumbi)

const (
	CorpseRitePacketSize       = 7
	RiteTargetCorpse     uint8 = 0
	RiteTargetGrave      uint8 = 1
	RitePurify           uint8 = 0
	RiteRaise            uint8 = 1
)

type CorpseRitePacket struct {
	Target uint8
	ID     uint32
	Rite   uint8
}

func DeserializeCorpseRite(data []byte, pkt *CorpseRitePacket) error {
	if len(data) < CorpseRitePacketSize || data[0] != PacketTypeCorpseRite {
		return ErrInvalidPacketSize
	}
	pkt.Target = data[1]
	pkt.ID = binary.LittleEndian.Uint32(data[2:6])
	pkt.Rite = data[6]
	return nil
}
