package world

import (
	"fmt"

	"lunaria/server/internal/protocol"
)

// ItemInfo descreve um item do catálogo: peso (kg), slot de equipamento e bônus concedidos.
type ItemInfo struct {
	Name      string
	Weight    float32 // kg por unidade
	Slot      uint8   // protocol.Slot*; NoSlot = não equipável
	BonusSTR  uint8
	BonusDEX  uint8
	BonusCON  uint8
	BonusAGI  uint8
	BonusINT  uint8
	BonusESP  uint8
	BonusMAS  uint8
	BonusLCK  uint8
	BonusHP   uint16 // Vida máxima direta
	BonusDEF  uint16 // Reduz dano físico recebido (fixo)
	BonusMDEF uint16 // Defesa mágica (reservado para danos mágicos)
	BonusATK  uint16 // Dano somado aos golpes
}

// NoSlot marca itens que não podem ser equipados.
const NoSlot uint8 = 255

// ItemCatalog é a tabela oficial de itens. Pesos seguem as faixas:
// joias/relíquias leves 0.1–0.3 | poções, frascos, órgãos e comidas 0.4–0.8 |
// adagas, agulhas, cajados, tecido e botas leves 1.2–2.5 | espadas de 1 mão, arcos, chicotes,
// couro e minérios 3.5–6.0 | armas colossais, martelos, cutelos, escudos e placas 12–22.
var ItemCatalog = map[uint8]ItemInfo{
	protocol.ItemEmptyFlask:      {Name: "Frasco de Vidro Vazio", Weight: 0.4, Slot: NoSlot},
	protocol.ItemRawWolfMeat:     {Name: "Carne Crua de Lobo", Weight: 0.8, Slot: NoSlot},
	protocol.ItemCookedNobleMeat: {Name: "Carne Nobre Assada", Weight: 0.7, Slot: NoSlot},
	protocol.ItemWolfBloodPotion: {Name: "Poção de Sangue Lupino", Weight: 0.5, Slot: NoSlot},

	protocol.ItemAlphaWolfPelt:     {Name: "Pele Intacta de Lobo Alfa", Weight: 4.5, Slot: protocol.SlotChest, BonusSTR: 3, BonusHP: 35, BonusDEF: 4},
	protocol.ItemPureLunarBlood:    {Name: "Sangue Lunar Puro", Weight: 0.6, Slot: NoSlot},
	protocol.ItemDarkPoisonGland:   {Name: "Glândula de Veneno Sombrio", Weight: 0.5, Slot: NoSlot},
	protocol.ItemHeavySteelPlate:   {Name: "Placa de Aço Pesada", Weight: 18.0, Slot: protocol.SlotChest, BonusCON: 4, BonusHP: 50, BonusDEF: 10},
	protocol.ItemAncestralFangRing: {Name: "Anel de Presa Ancestral", Weight: 0.1, Slot: protocol.SlotRing1, BonusDEX: 3, BonusAGI: 3},

	protocol.ItemBrokenSoulChalice:    {Name: "Cálice da Alma Partida", Weight: 0.3, Slot: NoSlot},
	protocol.ItemLycanAlphaHeart:      {Name: "Coração do Licantropo Alfa", Weight: 0.3, Slot: protocol.SlotAmulet, BonusSTR: 5, BonusDEX: 5, BonusCON: 5, BonusAGI: 5, BonusINT: 5, BonusESP: 5, BonusMAS: 5, BonusLCK: 5},
	protocol.ItemBeastProgenitorBlood: {Name: "Sangue do Progenitor Bestial", Weight: 0.5, Slot: NoSlot},
	protocol.ItemEclipseScytheTome:    {Name: "Tomo da Foice do Eclipse", Weight: 1.2, Slot: NoSlot},
	protocol.ItemStarforgeCore:        {Name: "Núcleo de Forja Estelar", Weight: 3.5, Slot: NoSlot},

	protocol.ItemShadowCultistRobe:        {Name: "Túnica do Cultista Sombrio", Weight: 1.8, Slot: NoSlot},
	protocol.ItemGargoyleStoneHeart:       {Name: "Coração Pétreo da Gárgula", Weight: 4.0, Slot: NoSlot},
	protocol.ItemInquisitorShadowScythe:   {Name: "Foice de Sombras do Inquisidor", Weight: 14.0, Slot: NoSlot},
	protocol.ItemTraitorCommanderInsignia: {Name: "Insígnia do Comandante Traidor", Weight: 0.2, Slot: NoSlot},
	protocol.ItemHeraldEclipseEye:         {Name: "Olho do Arauto do Eclipse", Weight: 0.3, Slot: NoSlot},
	protocol.ItemSacredTorch:              {Name: "Tocha Sagrada do Santuário", Weight: 1.5, Slot: NoSlot},

	protocol.ItemRunicWarhammerRecipe: {Name: "Receita: Malho Rúnico", Weight: 0.1, Slot: NoSlot},
	protocol.ItemRunicWarhammer:       {Name: "Malho de Batalha Rúnico", Weight: 16.0, Slot: protocol.SlotMainHand, BonusSTR: 8, BonusCON: 6, BonusMAS: 4, BonusATK: 45},
	protocol.ItemOrganicTrash:         {Name: "Lixo Orgânico", Weight: 0.6, Slot: NoSlot},
	protocol.ItemRunicHourglass:       {Name: "Ampulheta Rúnica", Weight: 0.3, Slot: NoSlot},
	protocol.ItemSilverSilkCocoon:     {Name: "Casulo de Seda Prateada", Weight: 0.4, Slot: NoSlot},

	protocol.ItemVigilHelmet:         {Name: "Elmo de Vigia", Weight: 3.5, Slot: protocol.SlotHelmet, BonusCON: 2, BonusHP: 25, BonusDEF: 3},
	protocol.ItemSteelChestplate:     {Name: "Peitoral de Aço", Weight: 14.0, Slot: protocol.SlotChest, BonusCON: 5, BonusHP: 60, BonusDEF: 8},
	protocol.ItemWolfLeatherPants:    {Name: "Calças de Couro Lupino", Weight: 3.5, Slot: protocol.SlotLegs, BonusAGI: 3, BonusHP: 30, BonusDEF: 2},
	protocol.ItemMistwalkerBoots:     {Name: "Botas Passo-da-Bruma", Weight: 1.8, Slot: protocol.SlotBoots, BonusAGI: 4, BonusDEX: 2, BonusHP: 25, BonusDEF: 1},
	protocol.ItemBlacksmithGauntlets: {Name: "Manoplas de Forjador de Estrelas", Weight: 2.5, Slot: protocol.SlotGloves, BonusSTR: 4, BonusMAS: 3, BonusDEF: 2},
	protocol.ItemAlchemistBelt:       {Name: "Cinto de Transmutador", Weight: 0.3, Slot: protocol.SlotBelt, BonusINT: 3, BonusESP: 3, BonusMDEF: 2},
	protocol.ItemSilverMoonAmulet:    {Name: "Colar da Lua Prateada", Weight: 0.2, Slot: protocol.SlotAmulet, BonusINT: 4, BonusESP: 4, BonusLCK: 3, BonusMDEF: 3},
	protocol.ItemBloodRubyRing:       {Name: "Anel de Rubi Sanguinário", Weight: 0.1, Slot: protocol.SlotRing1, BonusSTR: 4, BonusCON: 3},
	protocol.ItemObsidianRing:        {Name: "Anel de Obsidiana", Weight: 0.1, Slot: protocol.SlotRing1, BonusCON: 4, BonusMAS: 3},
	protocol.ItemStarlightRing:       {Name: "Anel Estelar", Weight: 0.1, Slot: protocol.SlotRing1, BonusINT: 3, BonusLCK: 4},
	protocol.ItemAlphaPeltCloak:      {Name: "Capa de Pele Alfa", Weight: 2.5, Slot: protocol.SlotCloak, BonusSTR: 3, BonusAGI: 3, BonusHP: 35, BonusDEF: 2},

	protocol.ItemSpiderQueenHeart:       {Name: "Coração da Rainha Aranha", Weight: 0.3, Slot: NoSlot},
	protocol.ItemArachnaEye:             {Name: "Olho Multifacetado de Arachna", Weight: 0.3, Slot: NoSlot},
	protocol.ItemImperialSilkCloak:      {Name: "Manto de Seda Imperial", Weight: 1.5, Slot: NoSlot},
	protocol.ItemAbyssalScorpionStinger: {Name: "Ferrão de Escorpião Abissal", Weight: 0.3, Slot: NoSlot},
	protocol.ItemChimeraFleshPart:       {Name: "Retalho Quimérico Costurado", Weight: 0.8, Slot: NoSlot},
	protocol.ItemAncientIceCore:         {Name: "Núcleo de Gelo Antigo", Weight: 4.0, Slot: NoSlot},
	protocol.ItemPrimordialDragonScale:  {Name: "Escama Dracônica Primordial", Weight: 3.5, Slot: NoSlot},
	protocol.ItemEternalFrostHeart:      {Name: "Coração de Geada Eterna", Weight: 0.3, Slot: NoSlot},
	protocol.ItemCrimsonGuardInsignia:   {Name: "Insígnia do Guarda Carmesim", Weight: 0.2, Slot: NoSlot},
	protocol.ItemProgenitorPureBlood:    {Name: "Sangue Puro do Progenitor", Weight: 0.5, Slot: NoSlot},
	protocol.ItemVesperianCrimsonRing:   {Name: "Anel Carmesim de Vesperian", Weight: 0.1, Slot: NoSlot},
	protocol.ItemRoyalVenomGland:        {Name: "Glândula Real do Escorpião", Weight: 0.5, Slot: NoSlot},
	protocol.ItemVesperianPureBlood:     {Name: "Sangue Puro de Vesperian", Weight: 0.5, Slot: NoSlot},
	protocol.ItemMechaBlueprint:         {Name: "Diagrama do Mecha Gnarlin", Weight: 0.2, Slot: NoSlot},

	// Mão Principal (12)
	protocol.ItemIronLongsword: {Name: "Espada Longa de Aço", Weight: 4.2, Slot: protocol.SlotMainHand, BonusSTR: 2, BonusATK: 12},
	protocol.ItemOakStaff:      {Name: "Cajado Arcano", Weight: 2.2, Slot: protocol.SlotMainHand, BonusINT: 4, BonusATK: 8, BonusMDEF: 2},
	protocol.ItemRecurveBow:    {Name: "Arco de Caça", Weight: 3.6, Slot: protocol.SlotMainHand, BonusDEX: 3, BonusATK: 11},
	protocol.ItemSteelDagger:   {Name: "Adagas Gêmeas", Weight: 1.3, Slot: protocol.SlotMainHand, BonusDEX: 2, BonusLCK: 1, BonusATK: 8},
	protocol.ItemIronKnuckles:  {Name: "Manoplas de Ferro", Weight: 2.4, Slot: protocol.SlotMainHand, BonusSTR: 2, BonusATK: 9, BonusDEF: 1},
	protocol.ItemForgeHammer:   {Name: "Martelo de Forja", Weight: 14.0, Slot: protocol.SlotMainHand, BonusSTR: 4, BonusMAS: 2, BonusATK: 18},
	protocol.ItemGiantCleaver:  {Name: "Cutelo Gourmet", Weight: 12.5, Slot: protocol.SlotMainHand, BonusSTR: 3, BonusMAS: 2, BonusATK: 17},
	protocol.ItemBeastWhip:     {Name: "Chicote Bestial", Weight: 3.8, Slot: protocol.SlotMainHand, BonusDEX: 2, BonusESP: 1, BonusATK: 10},
	protocol.ItemSteelNeedles:  {Name: "Agulhas de Aço Rúnicas", Weight: 1.2, Slot: protocol.SlotMainHand, BonusDEX: 2, BonusINT: 2, BonusATK: 9},
	protocol.ItemColossalSword: {Name: "Espada Colossal", Weight: 20.0, Slot: protocol.SlotMainHand, BonusSTR: 6, BonusATK: 26},

	// Mão Secundária (13)
	protocol.ItemTowerShield:     {Name: "Escudo Bastião", Weight: 16.0, Slot: protocol.SlotOffHand, BonusCON: 4, BonusHP: 40, BonusDEF: 12},
	protocol.ItemOffhandDagger:   {Name: "Adaga Secundária", Weight: 1.2, Slot: protocol.SlotOffHand, BonusDEX: 1, BonusATK: 5},
	protocol.ItemArcaneOrb:       {Name: "Orbe Arcano", Weight: 1.4, Slot: protocol.SlotOffHand, BonusINT: 3, BonusESP: 2, BonusMDEF: 4},
	protocol.ItemAlchemyCatalyst: {Name: "Catalisador Alquímico", Weight: 1.6, Slot: protocol.SlotOffHand, BonusINT: 2, BonusMAS: 2, BonusATK: 4},
	protocol.ItemIronWok:         {Name: "Wok de Ferro", Weight: 4.0, Slot: protocol.SlotOffHand, BonusCON: 2, BonusDEF: 5},
	protocol.ItemHuntersQuiver:   {Name: "Aljava de Caçador", Weight: 1.5, Slot: protocol.SlotOffHand, BonusDEX: 2, BonusATK: 4},
	protocol.ItemAutopsyDagger:   {Name: "Adaga de Autópsia", Weight: 0.6, Slot: protocol.SlotMainHand, BonusDEX: 1, BonusATK: 4},
	protocol.ItemMetalScrap:      {Name: "Sucata Metálica", Weight: 1.0, Slot: NoSlot},
	protocol.ItemHealingPotion:   {Name: "Poção de Cura", Weight: 0.5, Slot: NoSlot},
	protocol.ItemManaPotion:      {Name: "Poção de Mana", Weight: 0.5, Slot: NoSlot},
	protocol.ItemBlueprintScroll: {Name: "Pergaminho de Blueprint", Weight: 0.2, Slot: NoSlot},
	protocol.ItemHerbalRemedy:    {Name: "Remédio de Ervas", Weight: 0.3, Slot: NoSlot},
	protocol.ItemRubyLongsword:   {Name: "Espada Longa Cravejada de Rubis", Weight: 4.0, Slot: protocol.SlotMainHand, BonusSTR: 4, BonusLCK: 2, BonusATK: 18},
	protocol.ItemGemChestplate:   {Name: "Peitoral Cravejado de Safiras", Weight: 13.0, Slot: protocol.SlotChest, BonusCON: 6, BonusHP: 80, BonusDEF: 10, BonusMDEF: 6},
	protocol.ItemQuartzCirclet:   {Name: "Diadema de Quartzo", Weight: 0.6, Slot: protocol.SlotHelmet, BonusINT: 4, BonusESP: 3, BonusMDEF: 5},
	protocol.ItemLeadPlate:       {Name: "Placa de Chumbo", Weight: 25.0, Slot: NoSlot},
	protocol.ItemOffhandKnuckle:  {Name: "Manopla Secundária", Weight: 2.2, Slot: protocol.SlotOffHand, BonusSTR: 1, BonusATK: 5, BonusDEF: 1},
}

func init() {
	// Blueprints Antigas (drops de ruínas e chefes): usar ensina a blueprint
	for _, b := range Blueprints {
		if b.ScrollID != 0 {
			ItemCatalog[b.ScrollID] = ItemInfo{Name: "Blueprint Antiga: " + b.Name, Weight: 0.2, Slot: NoSlot}
		}
	}
}

// GetItemInfo devolve os dados do item (itens desconhecidos pesam 0.5 kg e não equipam).
func GetItemInfo(itemID uint8) ItemInfo {
	if info, ok := ItemCatalog[itemID]; ok {
		return info
	}
	return ItemInfo{Name: "Item Desconhecido", Weight: 0.5, Slot: NoSlot}
}

// Capacidade de carga
const (
	BaseCarryWeight      float32 = 40.0
	CarryPerSTR          float32 = 5.0
	CarryPerCON          float32 = 2.5
	RacialCarryBonus     float32 = 40.0
	OverloadedWeightRate float32 = 1.30 // 130%: imóvel
)

// strongCarrierRaces ganham +40 kg de capacidade: Kharad, Dvergar (anão), Orkhan (orc),
// Terravyrn (dragão da terra), Jotunar (gigante de gelo) e Testudar (tartaruga).
var strongCarrierRaces = map[uint8]bool{
	protocol.RaceKharad: true, protocol.RaceDwarf: true, protocol.RaceOrc: true,
	protocol.RaceDragonEarth: true, protocol.RaceFrostGiant: true, protocol.RaceTurtleDemi: true,
}

// CalculateMaxWeight = 40 + FOR×5 + CON×2.5 (+40 kg para raças de carga).
func CalculateMaxWeight(raceID, str, con uint8) float32 {
	w := BaseCarryWeight + float32(str)*CarryPerSTR + float32(con)*CarryPerCON
	if strongCarrierRaces[raceID] {
		w += RacialCarryBonus
	}
	return w
}

// WeightSpeedMultiplier aplica a curva de penalidade de velocidade pelo peso carregado:
// até 70% → 1.0 | 70%–100% → 0.95 a 0.65 | 100%–129.9% → 0.60 a 0.25 (sem Sprint) | 130%+ → 0 (imóvel).
func WeightSpeedMultiplier(current, max float32) float32 {
	if max <= 0 {
		return 0
	}
	r := current / max
	switch {
	case r <= 0.70:
		return 1.0
	case r <= 1.00:
		return 0.95 - (r-0.70)/0.30*(0.95-0.65)
	case r < OverloadedWeightRate:
		return 0.60 - (r-1.00)/0.30*(0.60-0.25)
	default:
		return 0.0
	}
}

// ItemName devolve o nome legível de um item ou material.
func ItemName(itemID uint8) string {
	if n := GetItemInfo(itemID).Name; n != "" {
		return n
	}
	return fmt.Sprintf("item #%d", itemID)
}
