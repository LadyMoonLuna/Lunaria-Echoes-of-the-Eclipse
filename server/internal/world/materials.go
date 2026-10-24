package world

// Catálogo unificado de Materiais de coleta, autópsia e ligas (MaterialsDB).
// Os materiais vivem na mochila como itens comuns: os IDs (100 a 159) cabem no uint8 do inventário.

// Raridades dos materiais
const (
	RarityCommon       uint8 = 1 // Comum
	RarityUncommon     uint8 = 2 // Incomum
	RarityRare         uint8 = 3 // Raro
	RarityEpic         uint8 = 4 // Épico
	RarityUnique       uint8 = 5 // Único
	RarityExotic       uint8 = 6 // Exótico
	RarityLegendary    uint8 = 7 // Lendário
	RarityMythic       uint8 = 8 // Mítico
	RarityTranscendent uint8 = 9 // Transcendente (só a Yggdrasil)
)

// RarityNames: nome de cada raridade (índice = Rarity).
var RarityNames = []string{"", "Comum", "Incomum", "Raro", "Épico", "Único", "Exótico", "Lendário", "Mítico", "Transcendente"}

// Categorias de material
const (
	MatWood        = "Madeira"
	MatStone       = "Pedra"
	MatMetal       = "Metal"
	MatCrystal     = "Cristal"
	MatAlloy       = "Liga"
	MatHideThread  = "Pele_Fio"
	MatOrganBlood  = "Orgao_Sangue"
	MatPlantLiquid = "Planta_Liquido"
	MatBone        = "Osso"
)

// MaterialDef descreve um material e suas propriedades para Forja e Ligas.
type MaterialDef struct {
	ID           uint16
	Name         string
	Category     string
	Rarity       uint8
	Durability   int
	Weight       float32
	Resistances  string
	Trait        string
	CondThermal  int // 0 a 100%
	CondElectric int // 0 a 100%
	CondMagic    int // 0 a 100%
}

// IDs dos materiais
const (
	// Madeiras
	MatPineRefuge    uint16 = 100
	MatGreyOak       uint16 = 101
	MatStormCedar    uint16 = 102
	MatWhisperEbony  uint16 = 103
	MatBloodWillow   uint16 = 104
	MatIronwood      uint16 = 105
	MatSolarAsh      uint16 = 106
	MatYggdrasilRoot uint16 = 107
	// Pedras
	MatRawStone     uint16 = 108
	MatLimestone    uint16 = 109
	MatBasalt       uint16 = 110
	MatObsidianRock uint16 = 111
	MatVoidStone    uint16 = 112
	MatStarRock     uint16 = 113
	// Metais
	MatCopper        uint16 = 114
	MatTin           uint16 = 115
	MatIron          uint16 = 116
	MatSilver        uint16 = 117
	MatTitanium      uint16 = 118
	MatLunarMithril  uint16 = 119
	MatCrimsonOrich  uint16 = 120
	MatAbyssTungsten uint16 = 121
	MatAdamantine    uint16 = 122
	// Cristais
	MatQuartz        uint16 = 123
	MatManaCrystal   uint16 = 124
	MatFireRuby      uint16 = 125
	MatZeroSapphire  uint16 = 126
	MatBlackSunShard uint16 = 127
	// Peles, fios e sedas
	MatBoarLeather uint16 = 128
	MatWolfLeather uint16 = 129
	MatThickFur    uint16 = 130
	MatRoughThread uint16 = 131
	MatSpiderWeb   uint16 = 132
	MatArachnaSilk uint16 = 133
	// Órgãos e sangue (+18)
	MatFreshBlood     uint16 = 134
	MatVampireBlood   uint16 = 135
	MatWolfBlood      uint16 = 136
	MatPulsingHeart   uint16 = 137
	MatFilterLiver    uint16 = 138
	MatElasticGuts    uint16 = 139
	MatLungs          uint16 = 140
	MatFacetedEyes    uint16 = 141
	MatSharpFangs     uint16 = 142
	MatVorpalSac      uint16 = 143
	MatScorpionChitin uint16 = 144
	// Botânicos e líquidos
	MatPureWater      uint16 = 145
	MatToxicWater     uint16 = 146
	MatLunarDew       uint16 = 147
	MatThornVine      uint16 = 148
	MatSteelLiana     uint16 = 149
	MatGlowMushroom   uint16 = 150
	MatIronEaterFungi uint16 = 151
	MatParasiteMycel  uint16 = 152
	MatAcidSap        uint16 = 153
	MatCharcoal       uint16 = 154 // Carvão (combustível da forja)
	MatHerbs          uint16 = 155 // Ervas Medicinais
	MatMud            uint16 = 156 // Barro (margens do rio)
	MatClay           uint16 = 157 // Argila (margens do rio)
	MatZinc           uint16 = 158 // Zinco (vira Latão com Cobre)
	MatGold           uint16 = 159 // Ouro
	MatBones          uint16 = 86  // Ossos de Fera (ossadas pelo mundo)

	// Fauna (fauna.go): o que os bichos rendem na autópsia
	MatScales   uint16 = 94 // Escamas (peixes, cobras, lagartos)
	MatFeathers uint16 = 95 // Penas
	MatRawHide  uint16 = 96 // Pele Crua (anfíbios, morcegos, vermes)
	MatGameMeat uint16 = 97 // Carne de Caça (come crua ou cozida)

	// Flora coletável
	MatMoonflower   uint16 = 98  // Flor-da-Lua
	MatRiverLily    uint16 = 99  // Lírio-do-Rio
	MatSilverMoss   uint16 = 191 // Musgo-Prateado
	MatBloodThistle uint16 = 192 // Cardo-Sangrento
	MatFirebloom    uint16 = 193 // Erva-de-Fogo
	MatFrostRoot    uint16 = 194 // Raiz-de-Gelo
	MatMarshOrchid  uint16 = 195 // Orquídea-do-Brejo
	MatSaltCactus   uint16 = 196 // Cacto-Salgado
	MatGiantFern    uint16 = 197 // Samambaia-Gigante
	MatGoldenClover uint16 = 198 // Trevo-Dourado

	// Ligas da Fornalha (forge.go): IDs 175 a 190
	MatTemperedSteel   uint16 = 175
	MatBronze          uint16 = 176
	MatRunicBronze     uint16 = 177
	MatBrass           uint16 = 178
	MatRoseGold        uint16 = 179
	MatBlessedSilver   uint16 = 180
	MatDamascusSteel   uint16 = 181
	MatGlacialTitanium uint16 = 182
	MatThunderSteel    uint16 = 183
	MatVenomSteel      uint16 = 184
	MatLunarSilver     uint16 = 185
	MatBloodSteel      uint16 = 186
	MatLivingMithril   uint16 = 187
	MatHeavyTungsten   uint16 = 188
	MatFlameOrichalcum uint16 = 189
	MatDivineAdamant   uint16 = 190
)

// MaterialsDB é o catálogo oficial de materiais.
var MaterialsDB = map[uint16]MaterialDef{
	MatPineRefuge:    {MatPineRefuge, "Pinho do Refúgio", MatWood, RarityCommon, 40, 2.0, "Corte +5%", "Madeira macia e perfumada, fácil de trabalhar.", 30, 5, 10},
	MatGreyOak:       {MatGreyOak, "Carvalho Cinzento", MatWood, RarityUncommon, 70, 3.0, "Impacto +15%", "Fibras densas que absorvem pancadas.", 25, 5, 15},
	MatStormCedar:    {MatStormCedar, "Cedro da Tempestade", MatWood, RarityRare, 95, 2.8, "Raio +30%, Corte +10%", "Cresce onde os raios caem; guarda estática na seiva.", 20, 70, 35},
	MatWhisperEbony:  {MatWhisperEbony, "Ébano Sussurrante", MatWood, RarityEpic, 130, 3.2, "Sombra +35%, Mente +20%", "Sussurra segredos a quem o esculpe à noite.", 15, 10, 75},
	MatBloodWillow:   {MatBloodWillow, "Salgueiro de Sangue", MatWood, RarityUnique, 150, 2.6, "Necrose +40%", "A seiva vermelha regenera o cabo de armas que bebem sangue.", 20, 15, 80},
	MatIronwood:      {MatIronwood, "Madeira-Ferro", MatWood, RarityExotic, 220, 6.5, "Corte +45%, Impacto +35%", "Tão dura quanto aço, mas não enferruja.", 35, 20, 20},
	MatSolarAsh:      {MatSolarAsh, "Freixo Solar", MatWood, RarityLegendary, 260, 2.4, "Fogo +60%, Trevas +40%", "Brilha ao amanhecer e queima criaturas da noite.", 80, 30, 85},
	MatYggdrasilRoot: {MatYggdrasilRoot, "Raiz de Yggdrasil", MatWood, RarityMythic, 400, 3.0, "Todas +40%", "Fragmento da Árvore do Mundo; liga quaisquer outros materiais.", 50, 50, 100},

	MatRawStone:     {MatRawStone, "Pedra Bruta", MatStone, RarityCommon, 50, 4.0, "Impacto +5%", "Pedra comum, base de ferramentas simples.", 20, 0, 5},
	MatLimestone:    {MatLimestone, "Calcário", MatStone, RarityCommon, 45, 3.5, "Ácido -10%", "Pedra clara que vira cal e argamassa.", 25, 0, 5},
	MatBasalt:       {MatBasalt, "Basalto", MatStone, RarityRare, 120, 5.0, "Fogo +30%, Impacto +20%", "Lava resfriada que suporta calor extremo.", 60, 5, 15},
	MatObsidianRock: {MatObsidianRock, "Obsidiana", MatStone, RarityEpic, 90, 2.5, "Corte +50%", "Vidro vulcânico de gume perfeito, porém frágil.", 40, 0, 45},
	MatVoidStone:    {MatVoidStone, "Pedra-Vazio", MatStone, RarityExotic, 200, 4.5, "Magia +50%", "Absorve feitiços que a tocam.", 5, 0, 5},
	MatStarRock:     {MatStarRock, "Rocha Estelar", MatStone, RarityLegendary, 280, 6.0, "Luz +60%, Gravidade", "Caiu do céu; é mais pesada do que parece.", 45, 40, 90},

	MatCopper:        {MatCopper, "Cobre", MatMetal, RarityCommon, 60, 4.5, "Raio +10%", "Excelente condutor; base do bronze.", 85, 95, 30},
	MatTin:           {MatTin, "Estanho", MatMetal, RarityCommon, 40, 4.0, "Ácido +10%", "Metal macio que endurece ligas.", 60, 70, 20},
	MatIron:          {MatIron, "Ferro", MatMetal, RarityCommon, 100, 5.5, "Corte +15%, Impacto +10%", "O metal de todo ferreiro; vira aço com carvão.", 70, 60, 10},
	MatSilver:        {MatSilver, "Prata", MatMetal, RarityRare, 90, 5.0, "Trevas +40%, Mortos-vivos +50%", "Queima vampiros e lobisomens.", 90, 90, 60},
	MatTitanium:      {MatTitanium, "Titânio", MatMetal, RarityRare, 180, 3.5, "Corte +25%, Ácido +30%", "Leve e quase indestrutível.", 30, 20, 15},
	MatLunarMithril:  {MatLunarMithril, "Mithril Lunar", MatMetal, RarityEpic, 220, 2.0, "Magia +45%, Corte +30%", "Brilha sob a lua e pesa como uma pena.", 50, 60, 90},
	MatCrimsonOrich:  {MatCrimsonOrich, "Oricalco Rubro", MatMetal, RarityUnique, 250, 4.0, "Fogo +55%, Sangue +30%", "Metal lendário dos reis antigos, quente ao toque.", 95, 50, 70},
	MatAbyssTungsten: {MatAbyssTungsten, "Tungstênio Abissal", MatMetal, RarityExotic, 320, 9.0, "Impacto +60%, Fogo +40%", "Forjado na pressão das profundezas.", 40, 30, 25},
	MatAdamantine:    {MatAdamantine, "Adamantino", MatMetal, RarityLegendary, 450, 7.0, "Todas físicas +60%", "Nada o arranha; nada o quebra.", 35, 25, 40},

	MatQuartz:        {MatQuartz, "Quartzo", MatCrystal, RarityCommon, 30, 1.0, "Magia +5%", "Cristal comum que vibra levemente com mana.", 10, 30, 40},
	MatManaCrystal:   {MatManaCrystal, "Cristal de Mana", MatCrystal, RarityRare, 60, 0.8, "Magia +40%", "Reserva de mana pura em forma sólida.", 10, 40, 95},
	MatFireRuby:      {MatFireRuby, "Rubi de Fogo", MatCrystal, RarityEpic, 80, 0.6, "Fogo +60%", "Uma chama aprisionada dentro da pedra.", 100, 20, 70},
	MatZeroSapphire:  {MatZeroSapphire, "Safira Zero Absoluto", MatCrystal, RarityUnique, 90, 0.6, "Gelo +70%", "Congela o ar ao redor; nunca derrete.", 0, 10, 80},
	MatBlackSunShard: {MatBlackSunShard, "Fragmento do Sol Negro", MatCrystal, RarityMythic, 300, 1.2, "Trevas +80%, Fogo +60%", "Pedaço do sol que morreu no primeiro Eclipse.", 100, 80, 100},

	MatBoarLeather: {MatBoarLeather, "Couro de Javali", MatHideThread, RarityCommon, 50, 2.0, "Corte +10%", "Couro grosso e resistente para armaduras leves.", 20, 0, 5},
	MatWolfLeather: {MatWolfLeather, "Couro de Lobo", MatHideThread, RarityCommon, 45, 1.8, "Frio +15%", "Couro cinzento e flexível que mantém o calor.", 15, 0, 10},
	MatThickFur:    {MatThickFur, "Pelos Espessos", MatHideThread, RarityUncommon, 30, 1.0, "Frio +30%", "Isolante perfeito para mantos de inverno.", 5, 0, 10},
	MatRoughThread: {MatRoughThread, "Linhas Grossas", MatHideThread, RarityCommon, 20, 0.3, "—", "Fios de tendão seco para costura.", 10, 5, 10},
	MatSpiderWeb:   {MatSpiderWeb, "Teias de Aranha", MatHideThread, RarityUncommon, 35, 0.2, "Corte +15%", "Pegajosa e surpreendentemente resistente.", 5, 5, 30},
	MatArachnaSilk: {MatArachnaSilk, "Seda de Arachna", MatHideThread, RarityEpic, 160, 0.3, "Corte +45%, Veneno +40%", "Seda da Rainha Tecelã; mais forte que aço.", 10, 10, 70},

	MatFreshBlood:     {MatFreshBlood, "Sangue Fresco", MatOrganBlood, RarityCommon, 0, 0.6, "—", "Base de poções de vida e rituais simples.", 40, 50, 30},
	MatVampireBlood:   {MatVampireBlood, "Sangue de Vampiro", MatOrganBlood, RarityEpic, 0, 0.6, "Necrose +40%", "Escuro e frio; concede roubo de vida às lâminas temperadas nele.", 10, 30, 85},
	MatWolfBlood:      {MatWolfBlood, "Sangue de Lobo", MatOrganBlood, RarityUncommon, 0, 0.6, "Fúria +20%", "Ferve sob a lua cheia.", 60, 40, 45},
	MatPulsingHeart:   {MatPulsingHeart, "Coração Pulsante", MatOrganBlood, RarityRare, 0, 0.8, "Vida +30%", "Continua batendo fora do corpo por dias.", 50, 60, 70},
	MatFilterLiver:    {MatFilterLiver, "Fígado Filtrante", MatOrganBlood, RarityUncommon, 0, 0.7, "Veneno +35%", "Purifica toxinas; base de antídotos.", 30, 20, 40},
	MatElasticGuts:    {MatElasticGuts, "Intestinos e Tendões Elásticos", MatOrganBlood, RarityUncommon, 60, 0.8, "Tração +30%", "Viram cordas de arco e molas de besta.", 20, 10, 20},
	MatLungs:          {MatLungs, "Pulmões", MatOrganBlood, RarityUncommon, 0, 0.7, "Vento +25%", "Guardam o fôlego da criatura; usados em foles mágicos.", 25, 15, 45},
	MatFacetedEyes:    {MatFacetedEyes, "Olhos Multifacetados", MatOrganBlood, RarityRare, 0, 0.4, "Precisão +30%", "Lentes naturais para lunetas e amuletos de visão.", 10, 25, 75},
	MatSharpFangs:     {MatSharpFangs, "Presas e Garras Afiadas", MatOrganBlood, RarityCommon, 40, 0.3, "Perfuração +20%", "Pontas de flecha e serrilhados de lâmina.", 15, 5, 15},
	MatVorpalSac:      {MatVorpalSac, "Bolsa de Veneno Vorpal", MatOrganBlood, RarityEpic, 0, 0.5, "Veneno +60%", "Uma gota derruba um touro. Corte com MUITO cuidado.", 20, 30, 60},
	MatScorpionChitin: {MatScorpionChitin, "Quitina de Escorpião", MatHideThread, RarityUnique, 200, 2.5, "Corte +40%, Veneno +50%", "Carapaça abissal leve e quase impenetrável.", 15, 5, 35},

	MatPureWater:      {MatPureWater, "Água Pura", MatPlantLiquid, RarityCommon, 0, 0.5, "—", "Base de toda poção e da têmpera do aço.", 60, 40, 30},
	MatToxicWater:     {MatToxicWater, "Água Tóxica dos Esgotos", MatPlantLiquid, RarityUncommon, 0, 0.5, "Veneno +25%", "Verde e borbulhante; corrói o que toca.", 50, 50, 25},
	MatLunarDew:       {MatLunarDew, "Orvalho Lunar", MatPlantLiquid, RarityRare, 0, 0.4, "Magia +35%", "Só se forma em noites de lua cheia.", 20, 30, 90},
	MatThornVine:      {MatThornVine, "Vinha Espinhosa", MatPlantLiquid, RarityCommon, 25, 0.6, "Sangramento +15%", "Cordas espinhosas para armadilhas.", 15, 5, 20},
	MatSteelLiana:     {MatSteelLiana, "Cipó-de-Aço", MatPlantLiquid, RarityRare, 120, 1.2, "Tração +40%", "Cipó metálico que não arrebenta.", 40, 45, 20},
	MatGlowMushroom:   {MatGlowMushroom, "Cogumelo Bioluminescente", MatPlantLiquid, RarityUncommon, 0, 0.4, "Luz +20%", "Ilumina cavernas e alquimias noturnas.", 10, 20, 55},
	MatIronEaterFungi: {MatIronEaterFungi, "Fungo Devorador de Ferro", MatPlantLiquid, RarityEpic, 0, 0.5, "Corrosão +50%", "Come metal; usado para gravar runas em armas.", 30, 40, 50},
	MatParasiteMycel:  {MatParasiteMycel, "Micélio Parasita", MatPlantLiquid, RarityUnique, 0, 0.4, "Necrose +45%", "Fios vivos que se espalham por qualquer ferida.", 20, 20, 80},
	MatAcidSap:        {MatAcidSap, "Seiva Ácida", MatPlantLiquid, RarityRare, 0, 0.5, "Ácido +45%", "Brota de fendas ácidas da Fronteira das Cinzas.", 45, 55, 35},
	MatCharcoal:       {MatCharcoal, "Carvão", MatStone, RarityCommon, 10, 1.0, "Fogo +10%", "Combustível da forja; queima mais quente que a madeira.", 90, 30, 5},
	MatMud:            {MatMud, "Barro", MatStone, RarityCommon, 10, 1.2, "Vedação +10%", "Lama grossa das margens do Rio Prateado; tapa frestas e molda tijolos.", 20, 10, 5},
	MatClay:           {MatClay, "Argila", MatStone, RarityUncommon, 25, 1.0, "Cerâmica +20%", "Argila fina e plástica que vira cerâmica, moldes de fundição e cadinhos.", 45, 15, 10},
	MatScales:         {MatScales, "Escamas", MatHideThread, RarityCommon, 45, 0.4, "Corte +10%, Água +15%", "Escamas sobrepostas e leves; viram couraças flexíveis.", 15, 5, 20},
	MatFeathers:       {MatFeathers, "Penas", MatHideThread, RarityCommon, 10, 0.1, "Vento +15%", "Penas firmes para emplumar flechas e forrar mantos.", 5, 5, 25},
	MatRawHide:        {MatRawHide, "Pele Crua", MatHideThread, RarityCommon, 30, 0.8, "Água +10%", "Pele fina e úmida; precisa curtir antes de virar couro bom.", 10, 5, 15},
	MatGameMeat:       {MatGameMeat, "Carne de Caça", MatOrganBlood, RarityCommon, 0, 0.8, "—", "Carne fresca de caça; mata a fome e estraga se demorar.", 30, 20, 10},

	MatMoonflower:   {MatMoonflower, "Flor-da-Lua", MatPlantLiquid, RarityRare, 0, 0.1, "Magia +30%", "Só abre as pétalas prateadas à noite.", 10, 20, 85},
	MatRiverLily:    {MatRiverLily, "Lírio-do-Rio", MatPlantLiquid, RarityUncommon, 0, 0.1, "Cura +20%", "Cresce na beira d'água; acalma febres.", 15, 10, 45},
	MatSilverMoss:   {MatSilverMoss, "Musgo-Prateado", MatPlantLiquid, RarityCommon, 0, 0.1, "Cura +10%", "Musgo das pedras úmidas; estanca sangramentos.", 10, 10, 30},
	MatBloodThistle: {MatBloodThistle, "Cardo-Sangrento", MatPlantLiquid, RarityUncommon, 15, 0.2, "Sangramento +25%", "Espinhos vermelhos; seu suco engrossa o sangue.", 20, 10, 40},
	MatFirebloom:    {MatFirebloom, "Erva-de-Fogo", MatPlantLiquid, RarityRare, 0, 0.1, "Fogo +35%", "Folhas quentes ao toque; nasce nas cinzas.", 90, 20, 50},
	MatFrostRoot:    {MatFrostRoot, "Raiz-de-Gelo", MatPlantLiquid, RarityRare, 0, 0.3, "Gelo +35%", "Raiz azulada que nunca degela.", 5, 15, 55},
	MatMarshOrchid:  {MatMarshOrchid, "Orquídea-do-Brejo", MatPlantLiquid, RarityEpic, 0, 0.1, "Veneno +30%, Magia +20%", "Linda e traiçoeira: o néctar é tóxico.", 15, 20, 70},
	MatSaltCactus:   {MatSaltCactus, "Cacto-Salgado", MatPlantLiquid, RarityUncommon, 0, 0.6, "Água +20%", "Guarda água salobra; salva viajantes no deserto.", 40, 15, 20},
	MatGiantFern:    {MatGiantFern, "Samambaia-Gigante", MatPlantLiquid, RarityCommon, 10, 0.3, "Natureza +15%", "Folhas enormes; boas para forrar e embrulhar.", 15, 5, 25},
	MatGoldenClover: {MatGoldenClover, "Trevo-Dourado", MatPlantLiquid, RarityEpic, 0, 0.05, "Sorte +25%", "Raríssimo trevo de quatro folhas que brilha ao sol.", 10, 30, 80},
	MatZinc:         {MatZinc, "Zinco", MatMetal, RarityCommon, 50, 4.2, "Ácido +10%", "Metal azulado e quebradiço; com Cobre vira Latão.", 65, 75, 15},
	MatGold:         {MatGold, "Ouro", MatMetal, RarityRare, 60, 7.0, "Magia +20%, Sorte +10%", "Macio e pesado; conduz mana melhor que qualquer metal comum.", 75, 95, 80},
	MatBones:        {MatBones, "Ossos de Fera", MatBone, RarityCommon, 55, 1.5, "Impacto +10%", "Ossos grandes e secos; cabos, guardas e reforços de arco.", 15, 5, 35},

	MatTemperedSteel:   {MatTemperedSteel, "Aço Temperado", MatAlloy, RarityUncommon, 140, 5.0, "Corte +25%, Impacto +15%", "Ferro e carvão temperados na água pura: o aço de todo ferreiro.", 70, 55, 15},
	MatBronze:          {MatBronze, "Bronze", MatAlloy, RarityCommon, 90, 4.6, "Impacto +15%", "Cobre endurecido com estanho; não enferruja.", 80, 80, 25},
	MatRunicBronze:     {MatRunicBronze, "Bronze Rúnico", MatAlloy, RarityRare, 110, 4.3, "Raio +35%, Magia +15%", "Bronze com pó de quartzo: conduz eletricidade como nenhum outro.", 75, 92, 55},
	MatBrass:           {MatBrass, "Latão", MatAlloy, RarityCommon, 80, 4.4, "Ácido +15%", "Dourado e fácil de moldar; bom para guardas e pomos.", 75, 85, 20},
	MatRoseGold:        {MatRoseGold, "Ouro Rosé", MatAlloy, RarityUncommon, 85, 6.2, "Magia +25%, Sorte +10%", "Ouro com cobre: bonito e ótimo condutor de mana.", 70, 90, 75},
	MatBlessedSilver:   {MatBlessedSilver, "Prata Consagrada", MatAlloy, RarityRare, 120, 5.0, "Trevas +50%, Mortos-vivos +60%", "Prata fundida com água pura e ervas sob oração.", 85, 85, 75},
	MatDamascusSteel:   {MatDamascusSteel, "Aço de Damasco", MatAlloy, RarityRare, 170, 5.0, "Corte +45%", "Camadas de aço e obsidiana dobradas cem vezes.", 65, 50, 20},
	MatGlacialTitanium: {MatGlacialTitanium, "Titânio Glacial", MatAlloy, RarityEpic, 210, 3.6, "Gelo +55%, Corte +25%", "Titânio resfriado com safira: sempre gelado ao toque.", 10, 20, 50},
	MatThunderSteel:    {MatThunderSteel, "Aço Trovejante", MatAlloy, RarityEpic, 180, 4.8, "Raio +60%", "Aço com cobre e cristal de mana; faísca a cada golpe.", 60, 98, 55},
	MatVenomSteel:      {MatVenomSteel, "Aço Venenoso", MatAlloy, RarityEpic, 190, 5.0, "Veneno +60%", "Aço temperado em veneno, fungos e água tóxica.", 55, 50, 40},
	MatLunarSilver:     {MatLunarSilver, "Prata Lunar", MatAlloy, RarityEpic, 200, 4.0, "Magia +55%, Trevas +40%", "Prata banhada em orvalho lunar; brilha à noite.", 70, 80, 95},
	MatBloodSteel:      {MatBloodSteel, "Aço Sanguíneo", MatAlloy, RarityUnique, 280, 5.2, "Necrose +40%, Vida +30%", "Aço que bebeu sangue e um coração ainda pulsante.", 50, 60, 80},
	MatLivingMithril:   {MatLivingMithril, "Mithril Vivo", MatAlloy, RarityExotic, 320, 1.0, "Magia +50%, Natureza +40%", "Mithril atravessado por micélio vivo; cresce e se fecha sozinho.", 40, 55, 95},
	MatHeavyTungsten:   {MatHeavyTungsten, "Tungstênio Reforçado", MatAlloy, RarityExotic, 360, 8.5, "Impacto +70%, Fogo +40%", "Tungstênio com carvão e basalto: quase impossível de entortar.", 45, 30, 25},
	MatFlameOrichalcum: {MatFlameOrichalcum, "Oricalco Flamejante", MatAlloy, RarityLegendary, 480, 4.0, "Fogo +80%, Corte +40%", "Oricalco fundido com rubi e presas de fera: arde por dentro.", 100, 60, 80},
	MatDivineAdamant:   {MatDivineAdamant, "Adamantino Divino", MatAlloy, RarityMythic, 9999, 6.0, "Todas +80%", "Adamantino com o Sol Negro e a Raiz da Árvore do Mundo. Não se quebra.", 100, 100, 100},
	MatHerbs:           {MatHerbs, "Ervas Medicinais", MatPlantLiquid, RarityCommon, 0, 0.2, "Cura +15%", "Folhas amargas que fecham feridas; base das poções de Lyra.", 10, 5, 35},
}

// StartingDiscoveredMaterials: o que todo jogador já conhece ao começar.
var StartingDiscoveredMaterials = []uint16{MatPineRefuge, MatRawStone, MatCopper, MatIron}

// GetMaterial devolve o material pelo ID de item (ok = false se não for material).
func GetMaterial(itemID ItemID) (MaterialDef, bool) {
	m, ok := MaterialsDB[uint16(itemID)]
	return m, ok
}

// IsMaterial informa se o item é um material do catálogo.
func IsMaterial(itemID ItemID) bool {
	_, ok := MaterialsDB[uint16(itemID)]
	return ok
}

func init() {
	// Todo material também é um item comum da mochila (peso para a carga)
	for id, m := range MaterialsDB {
		ItemCatalog[ItemID(id)] = ItemInfo{Name: m.Name, Weight: m.Weight, Slot: NoSlot}
	}
}
