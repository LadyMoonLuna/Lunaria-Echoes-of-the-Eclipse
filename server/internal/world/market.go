package world

import (
	"math"
	"sync"

	"lunaria/server/internal/protocol"
)

// Mercado vivo de Lunaria: cada item tem um preço justo (BasePrice) que só os NPCs conhecem. O que o
// jogador vê é a oferta do NPC naquele momento, que muda com:
//   - região: o que nasce por perto é barato; o que vem de longe é caro (e vale mais para vender);
//   - oferta: cada unidade vendida aos NPCs de um mercado derruba o preço da próxima ("o mercado já
//     tem muito disso"); o mercado absorve o excesso aos poucos (meia-vida de 1 dia de jogo);
//   - procura: cada unidade comprada dos NPCs encarece a próxima (meia-vida de 12 h de jogo);
//   - personalidade do NPC, Qualidade do item e o ouro que o NPC tem no bolso.

const (
	marketSellHalfLife = 24.0 // horas de jogo para o excesso vendido cair pela metade
	marketBuyHalfLife  = 12.0 // horas de jogo para a procura cair pela metade
	marketSatSoft      = 6.0  // a cada ~6 unidades encalhadas o preço cai bastante
	marketFloor        = 0.12 // abaixo de 12% do preço justo o NPC recusa ("mercado cheio")
	npcBuyShare        = 0.5  // o NPC paga ~metade do preço justo (ele precisa lucrar)
	MerchantRestockGH  = 3.0  // a cada 3 h de jogo o NPC repõe 1 unidade de cada item do catálogo
)

// NonTradable: itens que NUNCA aparecem à venda nas lojas (mudança de raça/classe, tomos, receitas,
// troféus de chefes, blueprints). Alguns podem ser vendidos ao Mercado Negro (ver BlackMarketBuys).
var NonTradable = map[uint8]bool{
	protocol.ItemPureLunarBlood: true, protocol.ItemBrokenSoulChalice: true, protocol.ItemLycanAlphaHeart: true,
	protocol.ItemBeastProgenitorBlood: true, protocol.ItemEclipseScytheTome: true, protocol.ItemStarforgeCore: true,
	protocol.ItemRunicWarhammerRecipe: true, protocol.ItemRunicWarhammer: true,
	protocol.ItemRunicHourglass: true, protocol.ItemProgenitorPureBlood: true, protocol.ItemVesperianPureBlood: true,
	protocol.ItemMechaBlueprint: true, protocol.ItemBlueprintScroll: true, protocol.ItemSilverSilkCocoon: true,
	ItemBPScrollLongsword: true, ItemBPScrollScythe: true, ItemBPScrollHammer: true, ItemBPScrollBow: true,
	ItemBPScrollGauntlets: true, ItemBPScrollShield: true, ItemBPScrollPlate: true,
}

// Troféus de chefes: só o Mercado Negro compra (e paga bem), ninguém vende.
var bossTrophies = map[uint8]bool{
	protocol.ItemShadowCultistRobe: true, protocol.ItemGargoyleStoneHeart: true, protocol.ItemInquisitorShadowScythe: true,
	protocol.ItemTraitorCommanderInsignia: true, protocol.ItemHeraldEclipseEye: true, protocol.ItemSacredTorch: true,
	protocol.ItemSpiderQueenHeart: true, protocol.ItemArachnaEye: true, protocol.ItemImperialSilkCloak: true,
	protocol.ItemAbyssalScorpionStinger: true, protocol.ItemChimeraFleshPart: true, protocol.ItemAncientIceCore: true,
	protocol.ItemPrimordialDragonScale: true, protocol.ItemEternalFrostHeart: true, protocol.ItemCrimsonGuardInsignia: true,
	protocol.ItemVesperianCrimsonRing: true, protocol.ItemRoyalVenomGland: true, protocol.ItemAlphaWolfPelt: true,
}

// Preços justos explícitos (Sollares). O resto sai da raridade/categoria (materiais) ou dos bônus (equipamentos).
var basePriceOverride = map[uint8]uint32{
	protocol.ItemEmptyFlask: 6, protocol.ItemRawWolfMeat: 8, protocol.ItemCookedNobleMeat: 22, protocol.ItemWolfBloodPotion: 70,
	protocol.ItemHealingPotion: 40, protocol.ItemManaPotion: 55, protocol.ItemHerbalRemedy: 50, protocol.ItemDarkPoisonGland: 65,
	protocol.ItemOrganicTrash: 1, protocol.ItemMetalScrap: 4, protocol.ItemAutopsyDagger: 35, protocol.ItemLeadPlate: 30,
	protocol.ItemAlphaWolfPelt: 260, protocol.ItemIronLongsword: 170, protocol.ItemSteelChestplate: 250,
	ItemStoneAxe: 18, ItemIronAxe: 85, ItemTemperedAxe: 210, ItemStonePickaxe: 18, ItemIronPickaxe: 90, ItemTemperedPick: 220,
	ItemHerbalShears: 45, protocol.ItemSilverMoonAmulet: 480, protocol.ItemBloodRubyRing: 400, protocol.ItemObsidianRing: 360,
	protocol.ItemStarlightRing: 430, protocol.ItemAncestralFangRing: 280, protocol.ItemQuartzCirclet: 450,
	protocol.ItemRubyLongsword: 620, protocol.ItemGemChestplate: 860,
	// troféus (valor para o Mercado Negro)
	protocol.ItemShadowCultistRobe: 160, protocol.ItemGargoyleStoneHeart: 420, protocol.ItemInquisitorShadowScythe: 900,
	protocol.ItemTraitorCommanderInsignia: 650, protocol.ItemHeraldEclipseEye: 1400, protocol.ItemSacredTorch: 300,
	protocol.ItemSpiderQueenHeart: 700, protocol.ItemArachnaEye: 1300, protocol.ItemImperialSilkCloak: 520,
	protocol.ItemAbyssalScorpionStinger: 480, protocol.ItemChimeraFleshPart: 380, protocol.ItemAncientIceCore: 750,
	protocol.ItemPrimordialDragonScale: 1500, protocol.ItemEternalFrostHeart: 1600, protocol.ItemCrimsonGuardInsignia: 340,
	protocol.ItemVesperianCrimsonRing: 1700, protocol.ItemRoyalVenomGland: 600,
}

var rarityBase = map[uint8]float32{RarityCommon: 6, RarityUncommon: 16, RarityRare: 42, RarityEpic: 110, RarityUnique: 220,
	RarityExotic: 380, RarityLegendary: 650, RarityMythic: 1200}

var categoryFactor = map[string]float32{MatWood: 0.8, MatStone: 0.6, MatMetal: 1.4, MatCrystal: 1.7, MatAlloy: 2.1,
	MatHideThread: 1.15, MatOrganBlood: 1.2, MatPlantLiquid: 0.9, MatBone: 0.7}

// BasePrice: preço justo do item (0 = sem valor de mercado).
func BasePrice(item uint8) uint32 {
	if item >= CustomItemFirstID {
		return 0
	}
	if v, ok := basePriceOverride[item]; ok {
		return v
	}
	if m, ok := MaterialsDB[uint16(item)]; ok {
		f := categoryFactor[m.Category]
		if f == 0 {
			f = 1
		}
		return uint32(math.Max(1, math.Round(float64(rarityBase[m.Rarity]*f))))
	}
	if info, ok := ItemCatalog[item]; ok && info.Slot != NoSlot {
		stats := int(info.BonusSTR) + int(info.BonusDEX) + int(info.BonusCON) + int(info.BonusAGI) + int(info.BonusINT) +
			int(info.BonusESP) + int(info.BonusMAS) + int(info.BonusLCK)
		v := 20 + stats*14 + int(info.BonusHP) + int(info.BonusDEF)*9 + int(info.BonusMDEF)*9 + int(info.BonusATK)*6
		return uint32(v)
	}
	if _, ok := ItemCatalog[item]; ok {
		return 10
	}
	return 0
}

// MarketOf: em que mercado o NPC negocia (interiores e prédios da Vila são o mercado da Vila).
func MarketOf(zone uint8) uint8 {
	switch {
	case zone == ZoneChurch || zone == ZoneMageTower || IsInteriorZone(zone):
		return ZoneVillage
	}
	return zone
}

var (
	nativeOnce sync.Once
	nativeMats map[uint8]map[uint16]bool // zona -> materiais que nascem/caçam ali
	anywhere   map[uint16]bool
)

func buildNativeMats() {
	nativeMats = map[uint8]map[uint16]bool{}
	anywhere = map[uint16]bool{}
	for zone, table := range zoneResourceTables {
		set := map[uint16]bool{}
		for _, e := range table {
			set[e.material] = true
			anywhere[e.material] = true
		}
		nativeMats[zone] = set
	}
	for _, d := range FaunaCatalog {
		set := nativeMats[d.Zone]
		if set == nil {
			set = map[uint16]bool{}
			nativeMats[d.Zone] = set
		}
		for _, o := range faunaOrgans(d) {
			set[uint16(o.ItemReward)] = true
			anywhere[uint16(o.ItemReward)] = true
		}
	}
}

// RegionalFactor: o quanto o item vale neste mercado (abundante aqui < 1 < raro aqui).
func RegionalFactor(item uint8, market uint8) float32 {
	nativeOnce.Do(buildNativeMats)
	if _, isMat := MaterialsDB[uint16(item)]; !isMat {
		return 1
	}
	if nativeMats[market][uint16(item)] {
		return 0.8
	}
	if !anywhere[uint16(item)] {
		return 1.15 // só sai de chefes/forja: raro em todo lugar
	}
	return 1.35 // vem de outra região
}

// MarketBook guarda a oferta e a procura recentes de cada mercado.
type MarketBook struct {
	mu       sync.Mutex
	sold     map[[2]uint8]float32 // unidades vendidas aos NPCs (excesso)
	bought   map[[2]uint8]float32 // unidades compradas dos NPCs (procura)
	lastTick float64
}

// NewMarketBook cria um livro de ofertas vazio.
func NewMarketBook() *MarketBook {
	return &MarketBook{sold: map[[2]uint8]float32{}, bought: map[[2]uint8]float32{}}
}

// Market é o livro de ofertas de Lunaria.
var Market = NewMarketBook()

// Decay faz o excesso e a procura voltarem ao normal com o tempo de jogo.
func (b *MarketBook) Decay(nowGH float64) {
	b.mu.Lock()
	defer b.mu.Unlock()
	dt := nowGH - b.lastTick
	if dt <= 0 {
		b.lastTick = nowGH
		return
	}
	b.lastTick = nowGH
	ks := float32(math.Pow(0.5, dt/marketSellHalfLife))
	kb := float32(math.Pow(0.5, dt/marketBuyHalfLife))
	for k, v := range b.sold {
		if v *= ks; v < 0.05 {
			delete(b.sold, k)
		} else {
			b.sold[k] = v
		}
	}
	for k, v := range b.bought {
		if v *= kb; v < 0.05 {
			delete(b.bought, k)
		} else {
			b.bought[k] = v
		}
	}
}

func (b *MarketBook) Sold(market, item uint8) float32 {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.sold[[2]uint8{market, item}]
}

func (b *MarketBook) Bought(market, item uint8) float32 {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.bought[[2]uint8{market, item}]
}

func (b *MarketBook) AddSold(market, item uint8, n float32) {
	b.mu.Lock()
	b.sold[[2]uint8{market, item}] += n
	b.mu.Unlock()
}

func (b *MarketBook) AddBought(market, item uint8, n float32) {
	b.mu.Lock()
	b.bought[[2]uint8{market, item}] += n
	b.mu.Unlock()
}

// qualityFactor: Qualidade 75 = preço cheio; 25 vale metade; 100 vale 1,33x.
func qualityFactor(q uint8) float32 {
	return float32(math.Max(0.5, math.Min(1.5, float64(q)/75)))
}

// NPCBuyUnitPrice: quanto o NPC paga pela PRÓXIMA unidade, já com `extra` unidades vendidas nesta
// negociação. 0 = não compra mais (mercado cheio ou o item não lhe interessa).
func NPCBuyUnitPrice(npcID uint32, personality string, market, item, quality uint8, extra int) uint32 {
	mult, ok := NPCBuyInterest(npcID, item)
	if !ok {
		return 0
	}
	base := float32(BasePrice(item))
	if base == 0 {
		return 0
	}
	sat := Market.Sold(market, item) + float32(extra)
	demand := RegionalFactor(item, market) * mult / (1 + sat/marketSatSoft)
	if demand < marketFloor {
		return 0
	}
	v := base * npcBuyShare * demand * BuyPriceMult(personality) * qualityFactor(quality)
	return uint32(math.Max(1, math.Round(float64(v))))
}

// NPCSellUnitPrice: quanto o NPC cobra do jogador pela próxima unidade (estoque baixo encarece).
func NPCSellUnitPrice(personality string, market, item uint8, stock int) uint32 {
	base := float32(BasePrice(item))
	if base == 0 {
		return 0
	}
	reg := RegionalFactor(item, market)
	scarcity := float32(1)
	if stock <= 1 {
		scarcity = 1.15
	}
	v := base * (0.55 + 0.45*reg) * (1 + Market.Bought(market, item)/8) * scarcity * SellPriceMult(personality)
	return uint32(math.Max(1, math.Round(float64(v))))
}

// --- O que cada NPC vende e o que ele compra ---

// MerchantCatalog: itens que o NPC tem à venda (além do que ele fabrica) e quantos gosta de manter.
var MerchantCatalog = map[uint32]map[uint8]int{
	100: {ItemStoneAxe: 3, ItemStonePickaxe: 3, protocol.ItemForgeHammer: 1, protocol.ItemVigilHelmet: 2, protocol.ItemIronKnuckles: 2, uint8(MatCharcoal): 10},
	103: {protocol.ItemEmptyFlask: 12, ItemHerbalShears: 2, protocol.ItemAlchemyCatalyst: 1, uint8(MatPureWater): 8},
	104: {protocol.ItemDarkPoisonGland: 3, protocol.ItemSteelDagger: 2, protocol.ItemOffhandDagger: 2, protocol.ItemObsidianRing: 1,
		uint8(MatVorpalSac): 2, uint8(MatAcidSap): 4, uint8(MatVampireBlood): 2, uint8(MatParasiteMycel): 3},
	105: {protocol.ItemCookedNobleMeat: 6, protocol.ItemHealingPotion: 4, protocol.ItemVigilHelmet: 2, protocol.ItemTowerShield: 1, protocol.ItemIronLongsword: 1},
	106: {protocol.ItemRecurveBow: 2, protocol.ItemHuntersQuiver: 2, protocol.ItemMistwalkerBoots: 1, protocol.ItemWolfLeatherPants: 1},
	107: {protocol.ItemHealingPotion: 5, protocol.ItemHerbalRemedy: 4, protocol.ItemSilverMoonAmulet: 1, uint8(MatLunarDew): 4},
	108: {protocol.ItemManaPotion: 5, protocol.ItemOakStaff: 1, protocol.ItemArcaneOrb: 1, uint8(MatQuartz): 4},
	109: {protocol.ItemRecurveBow: 1, protocol.ItemHuntersQuiver: 2, protocol.ItemAutopsyDagger: 3, ItemHerbalShears: 1, protocol.ItemRawWolfMeat: 6},
	111: {protocol.ItemSteelDagger: 2, protocol.ItemOffhandDagger: 2, uint8(MatVorpalSac): 2},
	112: {protocol.ItemIronKnuckles: 2, protocol.ItemOffhandKnuckle: 2, protocol.ItemHerbalRemedy: 3},
	113: {uint8(MatLimestone): 10, uint8(MatBasalt): 6, uint8(MatClay): 8},
	114: {protocol.ItemSteelNeedles: 2, protocol.ItemWolfLeatherPants: 2, protocol.ItemMistwalkerBoots: 1, protocol.ItemAlchemistBelt: 1, uint8(MatRoughThread): 10},
	115: {protocol.ItemIronWok: 1, protocol.ItemGiantCleaver: 1},
	116: {protocol.ItemBeastWhip: 1, uint8(MatHerbs): 6, protocol.ItemRawWolfMeat: 4},
}

// Categorias de material que cada NPC compra (multiplicador de interesse: >1 paga melhor).
var npcBuyCategories = map[uint32]map[string]float32{
	100:       {MatMetal: 1.1, MatAlloy: 1.1, MatWood: 0.8, MatStone: 0.7},
	103:       {MatPlantLiquid: 1.1, MatOrganBlood: 1.0},
	104:       {MatOrganBlood: 1.2, MatCrystal: 0.9, MatAlloy: 0.8, MatMetal: 0.7, MatHideThread: 0.7},
	105:       {MatMetal: 0.7},
	106:       {MatWood: 0.9, MatHideThread: 0.8},
	107:       {MatPlantLiquid: 0.9},
	108:       {MatCrystal: 1.1},
	109:       {MatHideThread: 1.0, MatBone: 1.0, MatOrganBlood: 0.8},
	111:       {MatOrganBlood: 0.9},
	112:       {MatPlantLiquid: 0.8},
	113:       {MatStone: 1.2, MatCrystal: 0.9},
	114:       {MatHideThread: 1.25},
	115:       {MatPlantLiquid: 0.8},
	116:       {MatBone: 1.0, MatHideThread: 0.8},
	JewelerID: {MatCrystal: 1.25, MatMetal: 0.9},
}

// Itens (não materiais) que o NPC também compra.
var npcBuyItems = map[uint32]map[uint8]float32{
	100: {protocol.ItemMetalScrap: 1, protocol.ItemIronOre: 1, protocol.ItemIronLongsword: 0.8, protocol.ItemSteelChestplate: 0.8,
		protocol.ItemHeavySteelPlate: 0.8, ItemIronAxe: 0.8, ItemIronPickaxe: 0.8, protocol.ItemTowerShield: 0.8},
	103:       {protocol.ItemFreshWolfBlood: 1.2, protocol.ItemEmptyFlask: 0.6, protocol.ItemDarkPoisonGland: 0.9},
	105:       {protocol.ItemIronLongsword: 0.7, protocol.ItemVigilHelmet: 0.7, protocol.ItemTowerShield: 0.7},
	106:       {protocol.ItemRecurveBow: 0.7, protocol.ItemHuntersQuiver: 0.7},
	109:       {protocol.ItemSharpWolfFang: 1.1, protocol.ItemWolfGreyPelt: 1.1, protocol.ItemRawWolfMeat: 0.9, protocol.ItemAlphaWolfPelt: 1.0},
	111:       {protocol.ItemDarkPoisonGland: 1.2},
	114:       {protocol.ItemWolfGreyPelt: 1.2, protocol.ItemAlphaWolfPelt: 1.1},
	115:       {protocol.ItemRawWolfMeat: 1.2},
	116:       {protocol.ItemSharpWolfFang: 1.0, protocol.ItemWolfGreyPelt: 0.9},
	JewelerID: {protocol.ItemSilverMoonAmulet: 0.7, protocol.ItemBloodRubyRing: 0.7, protocol.ItemObsidianRing: 0.7, protocol.ItemStarlightRing: 0.7},
}

// Comida que o Chef compra (flores e ervas comestíveis entram pela categoria de plantas).
var foodMaterials = map[uint16]bool{MatGameMeat: true, MatHerbs: true, MatGlowMushroom: true, MatGoldenClover: true}

// NPCBuyInterest: o NPC compra este item? (e com que interesse)
func NPCBuyInterest(npcID uint32, item uint8) (float32, bool) {
	if item >= CustomItemFirstID || NonTradable[item] {
		return 0, false
	}
	if npcID == 104 { // Mercado Negro: compra quase tudo, troféus com ágio
		if bossTrophies[item] {
			return 1.5, true
		}
	} else if bossTrophies[item] && npcBuyItems[npcID][item] == 0 {
		return 0, false
	}
	if v, ok := npcBuyItems[npcID][item]; ok {
		return v, true
	}
	if npcID == 115 && foodMaterials[uint16(item)] {
		return 1.2, true
	}
	if prof, ok := NPCProfiles[npcID]; ok {
		if _, wants := prof.BuyPrices[uint16(item)]; wants {
			return 1.15, true // matéria-prima do próprio ofício
		}
	}
	if m, ok := MaterialsDB[uint16(item)]; ok {
		if v, ok := npcBuyCategories[npcID][m.Category]; ok {
			return v, true
		}
	}
	if npcID == 104 && BasePrice(item) > 0 {
		return 0.6, true // receptador: paga pouco, mas paga
	}
	return 0, false
}

// SellsItem: o NPC tem este item no catálogo (fabricado ou revendido)?
func SellsItem(npcID uint32, item uint8) bool {
	if NonTradable[item] || bossTrophies[item] {
		return false
	}
	if _, ok := MerchantCatalog[npcID][item]; ok {
		return true
	}
	if prof, ok := NPCProfiles[npcID]; ok {
		for _, r := range prof.Recipes {
			if r.Output == item {
				return true
			}
		}
		if _, ok := prof.SellExtra[item]; ok {
			return true
		}
	}
	return false
}

// IsMerchant: o NPC tem loja (catálogo, ofício ou compra alguma coisa).
func IsMerchant(npcID uint32) bool {
	if _, ok := MerchantCatalog[npcID]; ok {
		return true
	}
	if _, ok := NPCProfiles[npcID]; ok {
		return true
	}
	_, ok := npcBuyCategories[npcID]
	return ok
}
