package world

import (
	"time"

	"lunaria/server/internal/protocol"
)

// Mundo Vivo (Fase 1, Parte 1): NPCs com necessidades biológicas, ouro próprio, matérias-primas,
// estoque real de loja, produção a partir de receitas, ordens de compra e coleta autônoma.

// Atividades
const (
	ActivityWorking       = "Trabalhando"
	ActivityEating        = "Comendo"
	ActivityDrinking      = "Bebendo na Fonte"
	ActivityWarming       = "Aquecendo no Fogo"
	ActivityCooling       = "Refrescando na Fonte"
	ActivityDrinkingRiver = "Bebendo no Rio"
	ActivitySeekingCure   = "Procurando Cura"
	ActivityBurying       = "Levando o Corpo ao Cemitério"
	ActivityGathering     = "Coletando Recursos"
	ActivitySleeping      = "Dormindo"
	ActivityFleeing       = "Fugindo"
	ActivityDead          = "Morto"
)

// Personalidades
const (
	PersonalityHonorable = "Honrado"    // preços justos
	PersonalityAmbitious = "Ambicioso"  // vende 20% mais caro, paga 10% menos
	PersonalityCautious  = "Cauteloso"  // publica encomendas antes de ficar sem nada
	PersonalityRuthless  = "Implacavel" // paga 25% menos pelas matérias-primas
)

// Lugares da Vila do Refúgio (Zona 0)
var (
	PlaceFountain         = [2]float32{0, 0}      // Fonte Central
	PlaceTavern           = [2]float32{-33, 16.5} // Terraço da Taverna (mesas na frente da porta)
	PlaceFurnace          = [2]float32{35, 17}    // Braseiro do pátio da Forja do Garrick
	PlaceSouthGateVillage = [2]float32{0, -284}   // Portal Sul da Vila -> Bosque
	PlaceNorthGateForest  = [2]float32{0, 284}    // Saída Norte do Bosque -> Vila
)

// Ritmos (por minuto real)
const (
	HungerPerMinute       float32 = 0.5
	ThirstPerMinute       float32 = 0.8
	ColdRisePerMinute     float32 = 1.6
	ColdFallPerMinute     float32 = 4.0
	NeedThreshold         float32 = 35  // abaixo disso a necessidade vira prioridade
	ColdThreshold         float32 = 70  // acima disso o NPC procura calor
	HeatThreshold         float32 = 70  // acima disso o NPC procura a fonte para se refrescar
	StarvationHPPerMinute         = 30  // fome/sede/frio extremos ferem
	HeatRadius            float32 = 9.0 // distância da fornalha/fogueira que aquece
	BuyOrderPatience              = 5 * time.Minute
	CraftInterval                 = 45 * time.Second
	MaxStockPerItem               = 5
	TavernMealPrice       uint32  = 12
	TavernNPCID           uint32  = 115 // Chef Bartolomeu
	JewelerID             uint32  = 123 // Mestra Joalheira Selene
)

// ErrandStep é um passo de um plano: andar até (X,Z) na zona e, ao chegar, executar Action.
type ErrandStep struct {
	Zone      uint8
	X, Z      float32
	Action    string // "", "drink", "eat", "warm", "gather", "enter_zone"
	NodeID    uint32 // nó de recurso para "gather"
	TombID    uint32 // túmulo (ID do NPC morto) para "pickup_body"/"bury"
	EnterZone uint8  // zona de destino para "enter_zone"
	EnterX    float32
	EnterZ    float32
	WaitUntil time.Time
}

// NPCLifeState guarda o plano em andamento e os relógios da rotina.
type NPCLifeState struct {
	Enabled       bool // NPCs sem corpo (espíritos) não têm necessidades
	Plan          []ErrandStep
	Home          [2]float32 // posto de trabalho
	HomeZone      uint8
	LastCraft     time.Time
	OrderSince    map[uint16]time.Time // quando cada encomenda foi aberta
	BuyOrders     map[uint16]BuyOrder  // encomendas abertas (pagas com o ouro do NPC)
	WasPatrolling bool
	LastSpeech    time.Time

	// Parte 2: conflito, caçada, contratação e sucessão
	Aggressor       uint32 // jogador ou mob que o atacou (revide/fuga)
	AggressorIsMob  bool
	HuntTarget      uint32 // guarda caçando este jogador procurado
	PursuitHomeZone uint8  // onde o perseguidor estava ao começar a caçada
	PursuitHome     [2]float32
	LastStrike      time.Time
	Following       uint32 // jogador que contratou o NPC
	StudyingFor     uint32 // aprendiz: ID do mestre caído cuja oficina estuda
	StudyProgress   float32
}

// BuyOrder: o NPC compra Wanted unidades do material por Price cada.
type BuyOrder struct {
	Material uint16
	Wanted   int
	Price    uint32
}

// Ingredient: qualquer um dos materiais em Any serve (ex.: combustível = carvão ou madeira).
type Ingredient struct {
	Any []uint16
	Qty int
}

// Recipe transforma matérias-primas em um item de loja.
type Recipe struct {
	Output      uint8
	Ingredients []Ingredient
	Price       uint32  // preço base de venda
	Difficulty  float64 // 0..1: chance-base de um aprendiz falhar
}

// NPCProfile: profissão do NPC (receitas, preços de compra, onde coletar).
type NPCProfile struct {
	Recipes   []Recipe
	BuyPrices map[uint16]uint32 // quanto paga por cada matéria-prima
	Restock   map[uint16]int    // quanto quer ter de cada matéria-prima
	SellExtra map[uint8]uint32  // preço de itens que vende sem fabricar (ex.: refeições da taverna)
}

var fuel = []uint16{MatCharcoal, MatPineRefuge, MatGreyOak}

// NPCProfiles por ID de NPC.
var NPCProfiles = map[uint32]NPCProfile{
	100: { // Garrick, o Ferreiro
		Recipes: []Recipe{
			{Output: protocol.ItemIronLongsword, Ingredients: []Ingredient{{[]uint16{MatIron}, 3}, {fuel, 1}}, Price: 180, Difficulty: 0.35},
			{Output: ItemIronAxe, Ingredients: []Ingredient{{[]uint16{MatIron}, 2}, {fuel, 2}}, Price: 90, Difficulty: 0.15},
			{Output: ItemIronPickaxe, Ingredients: []Ingredient{{[]uint16{MatIron}, 2}, {fuel, 2}}, Price: 95, Difficulty: 0.15},
			{Output: protocol.ItemSteelChestplate, Ingredients: []Ingredient{{[]uint16{MatIron}, 5}, {fuel, 2}}, Price: 260, Difficulty: 0.5},
		},
		BuyPrices: map[uint16]uint32{MatIron: 25, MatCharcoal: 12, MatPineRefuge: 6, MatGreyOak: 9},
		Restock:   map[uint16]int{MatIron: 10, MatPineRefuge: 6},
	},
	103: { // Lyra, a Alquimista
		Recipes: []Recipe{
			{Output: protocol.ItemHealingPotion, Ingredients: []Ingredient{{[]uint16{MatHerbs}, 2}, {[]uint16{MatPureWater}, 1}}, Price: 45, Difficulty: 0.2},
			{Output: protocol.ItemManaPotion, Ingredients: []Ingredient{{[]uint16{MatGlowMushroom}, 1}, {[]uint16{MatHerbs}, 1}, {[]uint16{MatPureWater}, 1}}, Price: 60, Difficulty: 0.3},
			{Output: protocol.ItemHerbalRemedy, Ingredients: []Ingredient{{[]uint16{MatHerbs}, 2}, {[]uint16{MatGlowMushroom}, 1}, {[]uint16{MatPureWater}, 1}}, Price: 55, Difficulty: 0.25},
			{Output: protocol.ItemWolfBloodPotion, Ingredients: []Ingredient{{[]uint16{MatWolfBlood}, 1}, {[]uint16{MatPureWater}, 1}}, Price: 70, Difficulty: 0.4},
		},
		BuyPrices: map[uint16]uint32{MatHerbs: 10, MatPureWater: 5, MatGlowMushroom: 18, MatWolfBlood: 22},
		Restock:   map[uint16]int{MatHerbs: 8, MatPureWater: 6, MatGlowMushroom: 3},
	},
	JewelerID: { // Mestra Joalheira Selene: joias e equipamentos cravejados (melhores e mais caros que os do ferreiro)
		Recipes: []Recipe{
			{Output: protocol.ItemBloodRubyRing, Ingredients: []Ingredient{{[]uint16{MatFireRuby}, 1}, {[]uint16{MatSilver}, 2}}, Price: 420, Difficulty: 0.35},
			{Output: protocol.ItemObsidianRing, Ingredients: []Ingredient{{[]uint16{MatObsidianRock}, 2}, {[]uint16{MatSilver}, 1}}, Price: 380, Difficulty: 0.3},
			{Output: protocol.ItemStarlightRing, Ingredients: []Ingredient{{[]uint16{MatStarRock}, 1}, {[]uint16{MatQuartz}, 2}, {[]uint16{MatSilver}, 1}}, Price: 450, Difficulty: 0.4},
			{Output: protocol.ItemSilverMoonAmulet, Ingredients: []Ingredient{{[]uint16{MatSilver}, 3}, {[]uint16{MatManaCrystal}, 1}}, Price: 520, Difficulty: 0.4},
			{Output: protocol.ItemAncestralFangRing, Ingredients: []Ingredient{{[]uint16{MatSharpFangs}, 2}, {[]uint16{MatSilver}, 1}}, Price: 300, Difficulty: 0.25},
			{Output: protocol.ItemQuartzCirclet, Ingredients: []Ingredient{{[]uint16{MatQuartz}, 3}, {[]uint16{MatSilver}, 2}}, Price: 480, Difficulty: 0.35},
			{Output: protocol.ItemRubyLongsword, Ingredients: []Ingredient{{[]uint16{MatIron}, 3}, {[]uint16{MatFireRuby}, 2}, {[]uint16{MatSilver}, 1}}, Price: 650, Difficulty: 0.5},
			{Output: protocol.ItemGemChestplate, Ingredients: []Ingredient{{[]uint16{MatIron}, 5}, {[]uint16{MatZeroSapphire}, 1}, {[]uint16{MatSilver}, 2}}, Price: 900, Difficulty: 0.55},
		},
		BuyPrices: map[uint16]uint32{MatSilver: 40, MatQuartz: 30, MatFireRuby: 120, MatObsidianRock: 25, MatStarRock: 60,
			MatManaCrystal: 80, MatSharpFangs: 15, MatIron: 25, MatZeroSapphire: 140},
		Restock: map[uint16]int{MatSilver: 8, MatQuartz: 4},
	},
	TavernNPCID: { // Chef Bartolomeu: refeições
		Recipes: []Recipe{
			{Output: protocol.ItemCookedNobleMeat, Ingredients: []Ingredient{{[]uint16{uint16(protocol.ItemRawWolfMeat)}, 1}, {fuel, 1}}, Price: 25, Difficulty: 0.1},
		},
		BuyPrices: map[uint16]uint32{uint16(protocol.ItemRawWolfMeat): 8, MatPineRefuge: 6},
		Restock:   map[uint16]int{uint16(protocol.ItemRawWolfMeat): 8, MatPineRefuge: 6},
	},
}

// NPCStart: ouro, matérias-primas, estoque, HP e personalidade iniciais.
type NPCStart struct {
	HP          int
	Gold        uint32
	Personality string
	Raw         map[uint16]int
	Stock       map[uint16]int
}

var NPCStarts = map[uint32]NPCStart{
	100: {1800, 1500, PersonalityHonorable, map[uint16]int{MatIron: 6, MatPineRefuge: 4},
		map[uint16]int{uint16(protocol.ItemIronLongsword): 1, uint16(ItemIronAxe): 2, uint16(ItemIronPickaxe): 2}},
	103: {1200, 1200, PersonalityAmbitious, map[uint16]int{MatHerbs: 4, MatPureWater: 3, MatGlowMushroom: 1},
		map[uint16]int{uint16(protocol.ItemHealingPotion): 3, uint16(protocol.ItemManaPotion): 2, uint16(protocol.ItemHerbalRemedy): 2}},
	104: {900, 2500, PersonalityRuthless, nil, nil},  // Varis
	105: {2500, 400, PersonalityHonorable, nil, nil}, // Capitão Randel
	106: {2500, 250, PersonalityCautious, nil, nil},  // Guarda Valen
	107: {1000, 300, PersonalityHonorable, nil, nil}, // Irmã Seraphina
	108: {1100, 900, PersonalityCautious, nil, nil},  // Mestre Aurelius
	109: {1500, 350, PersonalityCautious, nil, nil},  // Kaelen
	111: {1000, 700, PersonalityRuthless, nil, nil},  // Nyx
	112: {1600, 150, PersonalityHonorable, nil, nil}, // Mestre Tao
	113: {800, 300, PersonalityCautious, nil, nil},   // Iolanthe
	114: {800, 1100, PersonalityAmbitious, nil, nil}, // Madame Fiorella
	115: {1300, 600, PersonalityHonorable, map[uint16]int{uint16(protocol.ItemRawWolfMeat): 8, MatPineRefuge: 6},
		map[uint16]int{uint16(protocol.ItemCookedNobleMeat): 6}}, // Chef Bartolomeu
	116: {1400, 80, PersonalityCautious, nil, nil}, // Thorne
	JewelerID: {900, 3000, PersonalityAmbitious, map[uint16]int{MatSilver: 6, MatQuartz: 4, MatFireRuby: 1, MatObsidianRock: 2},
		map[uint16]int{uint16(protocol.ItemBloodRubyRing): 1, uint16(protocol.ItemObsidianRing): 1, uint16(protocol.ItemSilverMoonAmulet): 1}}, // Selene
}

// InitLife prepara o NPC para o Mundo Vivo com seus valores iniciais.
func (npc *NPC) InitLife(home [2]float32) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	st, ok := NPCStarts[npc.ID]
	if !ok {
		return
	}
	npc.HP, npc.MaxHP = st.HP, st.HP
	npc.Gold = st.Gold
	npc.Personality = st.Personality
	for k, v := range st.Raw {
		npc.RawMaterials[k] = v
	}
	for k, v := range st.Stock {
		npc.ShopStock[k] = v
	}
	if _, ok := NPCProfiles[npc.ID]; ok {
		npc.Profession = npc.ID
		npc.ProfessionLevel = 10
	}
	npc.Life = NPCLifeState{Enabled: true, Home: home, HomeZone: npc.ZoneID,
		OrderSince: map[uint16]time.Time{}, BuyOrders: map[uint16]BuyOrder{}, LastCraft: time.Now()}
}

// LifeBusy: o NPC está num afazer próprio (beber, comer, aquecer, coletar) e a rotina de horário espera.
func (npc *NPC) LifeBusy() bool {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.IsDead || len(npc.Life.Plan) > 0 || npc.Life.Following != 0 || npc.Life.Aggressor != 0 || npc.Life.HuntTarget != 0
}

// SellPriceMult / BuyPriceMult aplicam a personalidade aos preços.
func SellPriceMult(personality string) float32 {
	if personality == PersonalityAmbitious {
		return 1.2
	}
	return 1.0
}

func BuyPriceMult(personality string) float32 {
	switch personality {
	case PersonalityAmbitious:
		return 0.9
	case PersonalityRuthless:
		return 0.75
	}
	return 1.0
}

// CanCraft informa se as matérias-primas cobrem a receita.
func CanCraft(raw map[uint16]int, r Recipe) bool {
	for _, ing := range r.Ingredients {
		have := 0
		for _, m := range ing.Any {
			have += raw[m]
		}
		if have < ing.Qty {
			return false
		}
	}
	return true
}

// ConsumeRecipe tira as matérias-primas da receita (prefere a primeira opção de cada ingrediente).
func ConsumeRecipe(raw map[uint16]int, r Recipe) {
	for _, ing := range r.Ingredients {
		need := ing.Qty
		for _, m := range ing.Any {
			take := raw[m]
			if take > need {
				take = need
			}
			raw[m] -= take
			if raw[m] <= 0 {
				delete(raw, m)
			}
			need -= take
			if need == 0 {
				break
			}
		}
	}
}

// WithLife executa fn com o NPC travado. fn não deve chamar métodos do NPC que travam de novo.
func (npc *NPC) WithLife(fn func(n *NPC)) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	fn(npc)
}

// ShopPrice: preço base de venda de um item no NPC (receita ou extra); 0 = não vende.
func ShopPrice(profession uint32, item uint8) uint32 {
	prof, ok := NPCProfiles[profession]
	if !ok {
		return 0
	}
	for _, r := range prof.Recipes {
		if r.Output == item {
			return r.Price
		}
	}
	return prof.SellExtra[item]
}

func clampNeed(v float32) float32 {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}

// NearFire informa se o NPC está ao lado da Fornalha (chamar com o NPC travado).
func (npc *NPC) NearFire() bool {
	dx, dz := npc.PosX-PlaceFurnace[0], npc.PosZ-PlaceFurnace[1]
	return npc.ZoneID == ZoneVillage && dx*dx+dz*dz <= HeatRadius*HeatRadius
}

// FeltTemp: temperatura que o corpo do NPC sente (ambiente + fogo próximo).
func (npc *NPC) FeltTemp(ambient float32) float32 {
	if npc.NearFire() {
		return ambient + FireHeatBonus
	}
	return ambient
}

// TickNeeds avança fome, sede, frio e calor por dt segundos com a temperatura ambiente (°C) e aplica dano.
// Retorna true se o NPC morreu agora. Chamar com o NPC travado (dentro de WithLife).
func (npc *NPC) TickNeeds(dt float32, ambient float32) bool {
	m := dt / 60
	t := npc.FeltTemp(ambient)
	npc.Temperature = t
	sickMult := float32(1)
	if npc.SymptomaticLocked(time.Now()) {
		d := Disease(npc.Disease)
		sickMult = d.NeedsMult
		npc.sickAccum += d.HPPerMinute * m
		if npc.sickAccum >= 1 {
			npc.HP -= int(npc.sickAccum)
			npc.sickAccum -= float32(int(npc.sickAccum))
		}
	}
	npc.Hunger = clampNeed(npc.Hunger - HungerPerMinute*sickMult*m)
	npc.Thirst = clampNeed(npc.Thirst - ThirstPerMinute*ThirstMultiplier(t)*sickMult*m)
	switch {
	case t < ComfortMinTemp: // esfria proporcional ao quanto está abaixo do conforto
		npc.Cold = clampNeed(npc.Cold + ColdRisePerMinute*(ComfortMinTemp-t)/5*m)
		npc.Heat = clampNeed(npc.Heat - ColdFallPerMinute*m)
	case t > ComfortMaxTemp: // esquenta proporcional ao quanto está acima
		npc.Heat = clampNeed(npc.Heat + ColdRisePerMinute*(t-ComfortMaxTemp)/5*m)
		npc.Cold = clampNeed(npc.Cold - ColdFallPerMinute*m)
	default:
		npc.Cold = clampNeed(npc.Cold - ColdFallPerMinute*m)
		npc.Heat = clampNeed(npc.Heat - ColdFallPerMinute*m)
	}
	hurts := 0
	if npc.Hunger <= 0 {
		hurts++
	}
	if npc.Thirst <= 0 {
		hurts++
	}
	if npc.Cold >= 100 {
		hurts++ // hipotermia
	}
	if npc.Heat >= 100 {
		hurts++ // insolação
	}
	if hurts > 0 {
		dmg := int(float32(StarvationHPPerMinute*hurts) * m)
		if dmg < 1 {
			dmg = 1
		}
		npc.HP -= dmg
	}
	if npc.HP <= 0 && !npc.IsDead {
		npc.markDeadLocked()
		return true
	}
	return false
}

// RouteTo monta os passos para ir de fromZone até (x,z) na zona alvo, cruzando o portal Vila <-> Bosque.
func RouteTo(fromZone, zone uint8, x, z float32, action string) []ErrandStep {
	final := ErrandStep{Zone: zone, X: x, Z: z, Action: action}
	switch {
	case fromZone == zone:
		return []ErrandStep{final}
	case fromZone == ZoneVillage && zone == ZoneForest:
		return []ErrandStep{{Zone: ZoneVillage, X: PlaceSouthGateVillage[0], Z: PlaceSouthGateVillage[1], Action: "enter_zone",
			EnterZone: ZoneForest, EnterX: 0, EnterZ: 275}, final}
	case fromZone == ZoneForest && zone == ZoneVillage:
		return []ErrandStep{{Zone: ZoneForest, X: PlaceNorthGateForest[0], Z: PlaceNorthGateForest[1], Action: "enter_zone",
			EnterZone: ZoneVillage, EnterX: 0, EnterZ: -275}, final}
	}
	return nil
}

// ActivityFor traduz a ação do passo em atividade visível.
func ActivityFor(action string) string {
	switch action {
	case "drink":
		return ActivityDrinking
	case "eat":
		return ActivityEating
	case "warm":
		return ActivityWarming
	case "cool":
		return ActivityCooling
	case "flee":
		return ActivityFleeing
	case "drink_river":
		return ActivityDrinkingRiver
	case "buy_remedy", "buy_potion", "church_cure", "church_heal":
		return ActivitySeekingCure
	case "pickup_body", "bury":
		return ActivityBurying
	}
	return ActivityGathering
}
