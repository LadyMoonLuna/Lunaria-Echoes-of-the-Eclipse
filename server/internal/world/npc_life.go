package world

import (
	"time"

	"lunaria/server/internal/protocol"
)

// Mundo Vivo (Fase 1, Parte 1): NPCs com necessidades biológicas, ouro próprio, matérias-primas,
// estoque real de loja, produção a partir de receitas, ordens de compra e coleta autônoma.

// Atividades
const (
	ActivityWorking   = "Trabalhando"
	ActivityEating    = "Comendo"
	ActivityDrinking  = "Bebendo na Fonte"
	ActivityWarming   = "Aquecendo no Fogo"
	ActivityGathering = "Coletando Recursos"
	ActivitySleeping  = "Dormindo"
	ActivityFleeing   = "Fugindo"
	ActivityDead      = "Morto"
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
	PlaceFountain         = [2]float32{0, 0}    // Fonte Central
	PlaceTavern           = [2]float32{-30, 25} // Taverna
	PlaceFurnace          = [2]float32{30, 25}  // Fornalha do Garrick
	PlaceSouthGateVillage = [2]float32{0, -284} // Portal Sul da Vila -> Bosque
	PlaceNorthGateForest  = [2]float32{0, 284}  // Saída Norte do Bosque -> Vila
)

// Ritmos (por minuto real)
const (
	HungerPerMinute       float32 = 0.5
	ThirstPerMinute       float32 = 0.8
	ColdRisePerMinute     float32 = 1.6
	ColdFallPerMinute     float32 = 4.0
	NeedThreshold         float32 = 35  // abaixo disso a necessidade vira prioridade
	ColdThreshold         float32 = 70  // acima disso o NPC procura calor
	StarvationHPPerMinute         = 30  // fome/sede/frio extremos ferem
	HeatRadius            float32 = 9.0 // distância da fornalha/fogueira que aquece
	BuyOrderPatience              = 5 * time.Minute
	CraftInterval                 = 45 * time.Second
	MaxStockPerItem               = 5
	TavernMealPrice       uint32  = 12
	TavernNPCID           uint32  = 115 // Chef Bartolomeu
)

// ErrandStep é um passo de um plano: andar até (X,Z) na zona e, ao chegar, executar Action.
type ErrandStep struct {
	Zone      uint8
	X, Z      float32
	Action    string // "", "drink", "eat", "warm", "gather", "enter_zone"
	NodeID    uint32 // nó de recurso para "gather"
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
	Price       uint32 // preço base de venda
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
			{Output: protocol.ItemIronLongsword, Ingredients: []Ingredient{{[]uint16{MatIron}, 3}, {fuel, 1}}, Price: 180},
			{Output: ItemIronAxe, Ingredients: []Ingredient{{[]uint16{MatIron}, 2}, {fuel, 2}}, Price: 90},
			{Output: ItemIronPickaxe, Ingredients: []Ingredient{{[]uint16{MatIron}, 2}, {fuel, 2}}, Price: 95},
			{Output: protocol.ItemSteelChestplate, Ingredients: []Ingredient{{[]uint16{MatIron}, 5}, {fuel, 2}}, Price: 260},
		},
		BuyPrices: map[uint16]uint32{MatIron: 25, MatCharcoal: 12, MatPineRefuge: 6, MatGreyOak: 9},
		Restock:   map[uint16]int{MatIron: 10, MatPineRefuge: 6},
	},
	103: { // Lyra, a Alquimista
		Recipes: []Recipe{
			{Output: protocol.ItemHealingPotion, Ingredients: []Ingredient{{[]uint16{MatHerbs}, 2}, {[]uint16{MatPureWater}, 1}}, Price: 45},
			{Output: protocol.ItemManaPotion, Ingredients: []Ingredient{{[]uint16{MatGlowMushroom}, 1}, {[]uint16{MatHerbs}, 1}, {[]uint16{MatPureWater}, 1}}, Price: 60},
			{Output: protocol.ItemWolfBloodPotion, Ingredients: []Ingredient{{[]uint16{MatWolfBlood}, 1}, {[]uint16{MatPureWater}, 1}}, Price: 70},
		},
		BuyPrices: map[uint16]uint32{MatHerbs: 10, MatPureWater: 5, MatGlowMushroom: 18, MatWolfBlood: 22},
		Restock:   map[uint16]int{MatHerbs: 8, MatPureWater: 6, MatGlowMushroom: 3},
	},
	TavernNPCID: { // Chef Bartolomeu: refeições
		Recipes: []Recipe{
			{Output: protocol.ItemCookedNobleMeat, Ingredients: []Ingredient{{[]uint16{uint16(protocol.ItemRawWolfMeat)}, 1}, {fuel, 1}}, Price: 25},
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
		map[uint16]int{uint16(protocol.ItemHealingPotion): 3, uint16(protocol.ItemManaPotion): 2}},
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
	npc.Life = NPCLifeState{Enabled: true, Home: home, HomeZone: npc.ZoneID,
		OrderSince: map[uint16]time.Time{}, BuyOrders: map[uint16]BuyOrder{}, LastCraft: time.Now()}
}

// LifeBusy: o NPC está num afazer próprio (beber, comer, aquecer, coletar) e a rotina de horário espera.
func (npc *NPC) LifeBusy() bool {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.IsDead || len(npc.Life.Plan) > 0
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
func ShopPrice(npcID uint32, item uint8) uint32 {
	prof, ok := NPCProfiles[npcID]
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

// IsColdWeather: climas que esfriam o corpo.
func IsColdWeather(w uint8) bool {
	switch w {
	case WeatherRain, WeatherDrizzle, WeatherSnow, WeatherBlizzard, WeatherThunderstorm, WeatherHail, WeatherGale, WeatherAcidRain:
		return true
	}
	return false
}

// IsColdHour: noite e madrugada.
func IsColdHour(hour int) bool { return hour >= 20 || hour < 6 }

func clampNeed(v float32) float32 {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}

// TickNeeds avança fome, sede e frio por dt segundos e aplica dano. Retorna true se o NPC morreu agora.
// Chamar com o NPC travado (dentro de WithLife).
func (npc *NPC) TickNeeds(dt float32, hour int, weather uint8) bool {
	m := dt / 60
	npc.Hunger = clampNeed(npc.Hunger - HungerPerMinute*m)
	npc.Thirst = clampNeed(npc.Thirst - ThirstPerMinute*m)
	dx, dz := npc.PosX-PlaceFurnace[0], npc.PosZ-PlaceFurnace[1]
	nearHeat := npc.ZoneID == ZoneVillage && dx*dx+dz*dz <= HeatRadius*HeatRadius
	switch {
	case nearHeat:
		npc.Cold = clampNeed(npc.Cold - ColdFallPerMinute*m)
	case IsColdWeather(weather) || IsColdHour(hour):
		mult := float32(1)
		if IsColdWeather(weather) && IsColdHour(hour) {
			mult = 2
		}
		npc.Cold = clampNeed(npc.Cold + ColdRisePerMinute*mult*m)
	default:
		npc.Cold = clampNeed(npc.Cold - ColdFallPerMinute*0.5*m)
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
	if hurts > 0 {
		dmg := int(float32(StarvationHPPerMinute*hurts) * m)
		if dmg < 1 {
			dmg = 1
		}
		npc.HP -= dmg
	}
	if npc.HP <= 0 && !npc.IsDead {
		npc.HP = 0
		npc.IsDead = true
		npc.IsActive = false
		npc.MoveSpeed = 0
		npc.Life.Plan = nil
		npc.CurrentActivity = ActivityDead
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
	}
	return ActivityGathering
}
