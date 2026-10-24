package world

import (
	"fmt"
	"math"
	"sort"
	"strings"

	"lunaria/server/internal/protocol"
)

// Forja — Etapa 2: Fornalha de Ligas (receitas fixas + fusão livre) e Forja por Blueprints
// (cada peça do equipamento escolhe o seu material). Ligas sintéticas e equipamentos forjados
// são peças únicas de cada jogador: ocupam os IDs 200 a 254 da mochila (CustomItems).

const (
	CustomItemFirstID uint8 = 200
	CustomItemLastID  uint8 = 254
	MaxCrucibleSlots        = 4
	ForgeTraitSep           = " • "
)

// Tipos de peça única
const (
	CustomAlloy uint8 = 1 // liga sintética (fusão livre) — usada como material
	CustomEquip uint8 = 2 // arma, ferramenta ou armadura forjada por blueprint
)

// AlloySpecial: característica especial que a liga passa para o equipamento forjado.
var AlloySpecial = map[uint16]string{
	MatVenomSteel:      "Envenena o alvo a cada corte",
	MatBloodSteel:      "12% de roubo de vida e reparo automático",
	MatLivingMithril:   "-50% de peso e enraíza o alvo",
	MatFlameOrichalcum: "Derrete 35% da armadura do alvo",
	MatDivineAdamant:   "Indestrutível e com todas as condutividades no máximo",
	MatBlessedSilver:   "Dano extra contra mortos-vivos",
	MatThunderSteel:    "Golpes com chance de atordoar por choque",
	MatGlacialTitanium: "Golpes com chance de congelar",
}

// AlloyRecipe: cada grupo é um ingrediente do cadinho (qualquer material da lista serve).
type AlloyRecipe struct {
	Output uint16
	Qty    uint8
	Groups [][]uint16
}

var bloods = []uint16{MatFreshBlood, MatVampireBlood, MatWolfBlood}
var fungi = []uint16{MatGlowMushroom, MatIronEaterFungi, MatParasiteMycel}

// AlloyRecipes: receitas fixas da Fornalha (a ordem dos ingredientes não importa).
var AlloyRecipes = []AlloyRecipe{
	{MatTemperedSteel, 2, [][]uint16{{MatIron}, {MatCharcoal}, {MatPureWater}}},
	{MatBronze, 2, [][]uint16{{MatCopper}, {MatTin}}},
	{MatRunicBronze, 1, [][]uint16{{MatCopper}, {MatTin}, {MatQuartz}}},
	{MatBrass, 2, [][]uint16{{MatCopper}, {MatZinc}}},
	{MatRoseGold, 2, [][]uint16{{MatGold}, {MatCopper}}},
	{MatBlessedSilver, 1, [][]uint16{{MatSilver}, {MatPureWater}, {MatHerbs}}},
	{MatDamascusSteel, 1, [][]uint16{{MatTemperedSteel}, {MatCharcoal}, {MatObsidianRock}}},
	{MatGlacialTitanium, 1, [][]uint16{{MatTitanium}, {MatZeroSapphire}, {MatPureWater}}},
	{MatThunderSteel, 1, [][]uint16{{MatTemperedSteel}, {MatCopper}, {MatManaCrystal}}},
	{MatVenomSteel, 1, [][]uint16{{MatTemperedSteel}, {MatVorpalSac}, fungi, {MatToxicWater}}},
	{MatLunarSilver, 1, [][]uint16{{MatSilver}, {MatLunarDew}, {MatManaCrystal}}},
	{MatBloodSteel, 1, [][]uint16{{MatTemperedSteel, MatTitanium}, bloods, {MatPulsingHeart}}},
	{MatLivingMithril, 1, [][]uint16{{MatLunarMithril}, fungi, {MatElasticGuts}, {MatLunarDew}}},
	{MatHeavyTungsten, 1, [][]uint16{{MatAbyssTungsten}, {MatCharcoal}, {MatBasalt}}},
	{MatFlameOrichalcum, 1, [][]uint16{{MatCrimsonOrich}, {MatSharpFangs, MatScorpionChitin}, {MatFireRuby}, {MatFilterLiver}}},
	{MatDivineAdamant, 1, [][]uint16{{MatAdamantine}, {MatBlackSunShard}, bloods, {MatYggdrasilRoot}}},
}

// MatchAlloyRecipe procura a receita fixa cujos grupos casam exatamente com os ingredientes.
func MatchAlloyRecipe(ings []uint16) (AlloyRecipe, bool) {
	for _, r := range AlloyRecipes {
		if len(r.Groups) == len(ings) && assignGroups(r.Groups, ings, make([]bool, len(ings)), 0) {
			return r, true
		}
	}
	return AlloyRecipe{}, false
}

func assignGroups(groups [][]uint16, ings []uint16, used []bool, gi int) bool {
	if gi == len(groups) {
		return true
	}
	for i, id := range ings {
		if used[i] || !containsID(groups[gi], id) {
			continue
		}
		used[i] = true
		if assignGroups(groups, ings, used, gi+1) {
			return true
		}
		used[i] = false
	}
	return false
}

func containsID(list []uint16, id uint16) bool {
	for _, x := range list {
		if x == id {
			return true
		}
	}
	return false
}

// --- Blueprints ---

// Etiquetas de material aceitas pelas peças
const (
	TagMetal      = "metal"      // Metais e Ligas
	TagLightMetal = "metal_leve" // metais/ligas com até 4,5 kg
	TagStoneEdge  = "pedra"      // pedras cortantes
	TagFang       = "presa"      // presas e quitina
	TagBone       = "osso"
	TagCrystal    = "cristal"
	TagWood       = "madeira"
	TagHide       = "couro"
	TagCord       = "corda" // tendões, linhas, sedas e vinhas
	TagSilk       = "seda"
	TagEye        = "olho"
	TagHeart      = "coracao"
)

// TagNames: nome legível de cada etiqueta (interface).
var TagNames = map[string]string{
	TagMetal: "Metais e Ligas", TagLightMetal: "Metais Leves", TagStoneEdge: "Pedras Cortantes", TagFang: "Presas e Quitina",
	TagBone: "Ossos", TagCrystal: "Cristais", TagWood: "Madeiras", TagHide: "Couros e Peles", TagCord: "Tendões, Linhas e Vinhas",
	TagSilk: "Sedas", TagEye: "Olhos de Monstro", TagHeart: "Corações",
}

// Papel da peça no cálculo
const (
	RoleDamage  = "dano"
	RoleDefense = "defesa"
	RoleFrame   = "estrutura"
	RoleCore    = "nucleo"
)

type BlueprintPart struct {
	Name     string
	Tags     []string
	Role     string
	Share    float32 // peso da peça na média ponderada (as peças somam ~1)
	Optional bool
}

// Tipos de blueprint
const (
	BPWeapon uint8 = 1
	BPTool   uint8 = 2
	BPArmor  uint8 = 3
)

type BlueprintDef struct {
	ID        uint8
	Name      string
	Kind      uint8
	Slot      uint8    // slot de equipamento (NoSlot para ferramentas)
	Tool      ToolKind // ferramentas de coleta
	BaseATK   int
	BaseDEF   int
	MassScale float32 // kg do item = soma(peso do material × share) × MassScale
	DurScale  float32
	Basic     bool   // todo jogador já começa sabendo
	Price     uint32 // > 0: Garrick vende
	ScrollID  uint8  // item "Blueprint Antiga" que ensina esta blueprint (drops)
	Parts     []BlueprintPart
}

var (
	partBlade    = BlueprintPart{"Lâmina", []string{TagMetal, TagStoneEdge, TagFang}, RoleDamage, 0.40, false}
	partGuard    = BlueprintPart{"Guarda / Cruzeta", []string{TagMetal, TagBone, TagCrystal}, RoleFrame, 0.15, false}
	partGrip     = BlueprintPart{"Cabo / Empunhadura", []string{TagWood, TagBone}, RoleFrame, 0.20, false}
	partWrap     = BlueprintPart{"Revestimento do Cabo", []string{TagHide, TagCord, TagSilk}, RoleFrame, 0.10, false}
	partPommel   = BlueprintPart{"Pomo / Núcleo Engastado", []string{TagCrystal, TagEye, TagHeart}, RoleCore, 0.10, true}
	partScabbard = BlueprintPart{"Bainha", []string{TagHide, TagWood, TagLightMetal, TagSilk}, RoleFrame, 0.05, true}
	partToolGrip = BlueprintPart{"Cabo", []string{TagWood, TagBone}, RoleFrame, 0.35, false}
	partLashing  = BlueprintPart{"Amarração", []string{TagHide, TagCord}, RoleFrame, 0.15, false}
)

// IDs dos itens "Blueprint Antiga" (drops de ruínas e chefes)
const (
	ItemBPScrollLongsword uint8 = 87
	ItemBPScrollScythe    uint8 = 88
	ItemBPScrollHammer    uint8 = 89
	ItemBPScrollBow       uint8 = 90
	ItemBPScrollGauntlets uint8 = 91
	ItemBPScrollShield    uint8 = 92
	ItemBPScrollPlate     uint8 = 93
)

// Blueprints: as 5 básicas e as 7 avançadas (compradas com o Garrick ou achadas como Blueprint Antiga).
var Blueprints = []BlueprintDef{
	{1, "Espada Curta", BPWeapon, protocol.SlotMainHand, ToolNone, 6, 0, 0.9, 1.0, true, 0, 0,
		[]BlueprintPart{partBlade, partGuard, partGrip, partWrap, partPommel, partScabbard}},
	{2, "Machado de Lenhador", BPTool, NoSlot, ToolAxe, 4, 0, 0.8, 1.0, true, 0, 0,
		[]BlueprintPart{{"Cabeça do Machado", []string{TagMetal, TagStoneEdge}, RoleDamage, 0.50, false}, partToolGrip, partLashing}},
	{3, "Picareta de Mineiro", BPTool, NoSlot, ToolPickaxe, 4, 0, 0.9, 1.0, true, 0, 0,
		[]BlueprintPart{{"Cabeça da Picareta", []string{TagMetal, TagStoneEdge}, RoleDamage, 0.50, false}, partToolGrip, partLashing}},
	{4, "Tesoura de Poda", BPTool, NoSlot, ToolShears, 1, 0, 0.35, 1.0, true, 0, 0,
		[]BlueprintPart{{"Lâminas", []string{TagMetal}, RoleDamage, 0.50, false},
			{"Eixo / Rebite", []string{TagMetal, TagBone}, RoleFrame, 0.15, false},
			{"Cabos", []string{TagWood, TagBone}, RoleFrame, 0.35, false}}},
	{5, "Adaga Simples", BPWeapon, protocol.SlotMainHand, ToolNone, 4, 0, 0.45, 0.9, true, 0, 0,
		[]BlueprintPart{{"Lâmina", partBlade.Tags, RoleDamage, 0.50, false}, {"Cabo", partGrip.Tags, RoleFrame, 0.30, false},
			{"Revestimento do Cabo", partWrap.Tags, RoleFrame, 0.10, false}, partPommel}},
	{6, "Espada Longa Imperial", BPWeapon, protocol.SlotMainHand, ToolNone, 14, 0, 1.2, 1.15, false, 600, ItemBPScrollLongsword,
		[]BlueprintPart{partBlade, partGuard, partGrip, partWrap, partPommel, partScabbard}},
	{7, "Foice de Guerra", BPWeapon, protocol.SlotMainHand, ToolNone, 18, 0, 1.6, 1.1, false, 0, ItemBPScrollScythe,
		[]BlueprintPart{{"Lâmina Curva", []string{TagMetal, TagFang}, RoleDamage, 0.40, false},
			{"Haste", []string{TagWood, TagBone}, RoleFrame, 0.30, false},
			{"Anel de Junção", []string{TagMetal}, RoleFrame, 0.10, false},
			{"Empunhadura", []string{TagHide, TagCord}, RoleFrame, 0.10, false},
			{"Contrapeso", []string{TagMetal, TagCrystal, TagStoneEdge}, RoleCore, 0.10, true}}},
	{8, "Martelo de Batalha", BPWeapon, protocol.SlotMainHand, ToolNone, 20, 0, 2.6, 1.2, false, 750, ItemBPScrollHammer,
		[]BlueprintPart{{"Cabeça do Martelo", []string{TagMetal, TagStoneEdge}, RoleDamage, 0.50, false},
			{"Haste", []string{TagWood, TagMetal}, RoleFrame, 0.30, false},
			{"Empunhadura", []string{TagHide, TagCord}, RoleFrame, 0.10, false},
			{"Núcleo", []string{TagCrystal, TagHeart}, RoleCore, 0.10, true}}},
	{9, "Arco Composto", BPWeapon, protocol.SlotMainHand, ToolNone, 12, 0, 0.7, 1.0, false, 0, ItemBPScrollBow,
		[]BlueprintPart{{"Braços do Arco", []string{TagWood, TagBone}, RoleDamage, 0.40, false},
			{"Reforço", []string{TagFang, TagBone, TagLightMetal}, RoleFrame, 0.15, false},
			{"Corda", []string{TagCord, TagSilk}, RoleDamage, 0.25, false},
			{"Empunhadura", []string{TagHide}, RoleFrame, 0.10, false},
			{"Mira", []string{TagEye, TagCrystal}, RoleCore, 0.10, true}}},
	{10, "Manoplas de Impacto", BPWeapon, protocol.SlotMainHand, ToolNone, 10, 2, 0.9, 1.0, false, 0, ItemBPScrollGauntlets,
		[]BlueprintPart{{"Placas dos Punhos", []string{TagMetal}, RoleDamage, 0.45, false},
			{"Forro", []string{TagHide}, RoleFrame, 0.20, false},
			{"Juntas", []string{TagMetal, TagBone}, RoleFrame, 0.15, false},
			{"Correias", []string{TagCord, TagHide}, RoleFrame, 0.10, false},
			{"Núcleo", []string{TagCrystal, TagHeart}, RoleCore, 0.10, true}}},
	{11, "Escudo Bastião", BPArmor, protocol.SlotOffHand, ToolNone, 0, 6, 2.4, 1.2, false, 650, ItemBPScrollShield,
		[]BlueprintPart{{"Face do Escudo", []string{TagMetal, TagWood}, RoleDefense, 0.50, false},
			{"Moldura", []string{TagMetal}, RoleDefense, 0.25, false},
			{"Alça", []string{TagHide, TagCord}, RoleFrame, 0.15, false},
			{"Emblema", []string{TagCrystal, TagEye}, RoleCore, 0.10, true}}},
	{12, "Peitoral de Placas", BPArmor, protocol.SlotChest, ToolNone, 0, 8, 2.8, 1.25, false, 900, ItemBPScrollPlate,
		[]BlueprintPart{{"Placas", []string{TagMetal}, RoleDefense, 0.45, false},
			{"Cota de Malha", []string{TagMetal, TagCord}, RoleDefense, 0.20, false},
			{"Forro", []string{TagHide}, RoleFrame, 0.15, false},
			{"Correias", []string{TagHide, TagCord}, RoleFrame, 0.10, false},
			{"Gema", []string{TagCrystal, TagHeart}, RoleCore, 0.10, true}}},
}

// GetBlueprint devolve a blueprint pelo ID.
func GetBlueprint(id uint8) (BlueprintDef, bool) {
	for _, b := range Blueprints {
		if b.ID == id {
			return b, true
		}
	}
	return BlueprintDef{}, false
}

// BlueprintByScroll: blueprint ensinada pelo item "Blueprint Antiga".
func BlueprintByScroll(itemID uint8) (BlueprintDef, bool) {
	for _, b := range Blueprints {
		if b.ScrollID != 0 && b.ScrollID == itemID {
			return b, true
		}
	}
	return BlueprintDef{}, false
}

// MaterialTags: etiquetas que um material satisfaz.
func MaterialTags(m MaterialDef) []string {
	var t []string
	switch m.Category {
	case MatMetal, MatAlloy:
		t = append(t, TagMetal)
		if m.Weight <= 4.5 {
			t = append(t, TagLightMetal)
		}
	case MatStone:
		switch m.ID {
		case MatRawStone, MatBasalt, MatObsidianRock, MatVoidStone, MatStarRock:
			t = append(t, TagStoneEdge)
		}
	case MatCrystal:
		t = append(t, TagCrystal)
	case MatWood:
		t = append(t, TagWood)
	case MatBone:
		t = append(t, TagBone)
	}
	switch m.ID {
	case MatSharpFangs, MatScorpionChitin:
		t = append(t, TagFang)
	case MatBoarLeather, MatWolfLeather, MatThickFur:
		t = append(t, TagHide)
	case MatElasticGuts, MatRoughThread, MatThornVine, MatSteelLiana:
		t = append(t, TagCord)
	case MatSpiderWeb, MatArachnaSilk:
		t = append(t, TagCord, TagSilk)
	case MatFacetedEyes:
		t = append(t, TagEye)
	case MatPulsingHeart:
		t = append(t, TagHeart)
	}
	return t
}

// PartAccepts informa se o material serve para a peça.
func PartAccepts(part BlueprintPart, m MaterialDef) bool {
	for _, mt := range MaterialTags(m) {
		for _, pt := range part.Tags {
			if mt == pt {
				return true
			}
		}
	}
	return false
}

// ForgedStats: resultado do cálculo de um equipamento forjado (mesma fórmula do preview do cliente).
type ForgedStats struct {
	Name        string
	Durability  int
	ATK, DEF    int
	HP          int
	Weight      float32
	Thermal     int
	Electric    int
	Magic       int
	Rarity      uint8
	ToolTier    uint8
	Resistances []string
	Specials    []string
	PartsText   []string
}

// statCap limita o quanto um material extremo (Adamantino Divino) conta no dano/defesa.
const statCap = 600

// ComputeForged calcula os atributos com os materiais escolhidos (mats[i] vazio = peça opcional sem material).
func ComputeForged(bp BlueprintDef, mats []MaterialDef, specials map[uint16]string) ForgedStats {
	var st ForgedStats
	var share, dur, th, el, mg, dmg, def, core float64
	var mainName string
	resSeen := map[string]bool{}
	for i, part := range bp.Parts {
		if i >= len(mats) || mats[i].Name == "" {
			continue
		}
		m := mats[i]
		w := float64(part.Share)
		share += w
		dur += float64(m.Durability) * w
		th += float64(m.CondThermal) * w
		el += float64(m.CondElectric) * w
		mg += float64(m.CondMagic) * w
		st.Weight += m.Weight * part.Share * bp.MassScale
		capped := math.Min(float64(m.Durability), statCap)
		switch part.Role {
		case RoleDamage:
			dmg += capped * w
			if mainName == "" {
				mainName = m.Name
				if bp.Tool != ToolNone {
					st.ToolTier = m.Rarity
				}
			}
		case RoleDefense:
			def += capped * w
			if mainName == "" {
				mainName = m.Name
			}
		case RoleCore:
			core += capped * w
		}
		if m.Rarity > st.Rarity {
			st.Rarity = m.Rarity
		}
		for _, r := range strings.Split(m.Resistances, ", ") {
			if r != "" && r != "—" && !resSeen[r] {
				resSeen[r] = true
				st.Resistances = append(st.Resistances, r)
			}
		}
		if sp, ok := specials[m.ID]; ok && sp != "" && !containsStr(st.Specials, sp) {
			st.Specials = append(st.Specials, sp)
		}
		st.PartsText = append(st.PartsText, fmt.Sprintf("%s de %s", part.Name, m.Name))
	}
	if share <= 0 {
		return st
	}
	st.Durability = int(math.Min(9999, math.Round(dur/share*float64(bp.DurScale))))
	st.Thermal = int(math.Round(th / share))
	st.Electric = int(math.Round(el / share))
	st.Magic = int(math.Round(mg / share))
	switch bp.Kind {
	case BPArmor:
		st.DEF = bp.BaseDEF + int(math.Round(def*0.06+core*0.03))
		st.HP = st.DEF * 3
	default:
		st.ATK = bp.BaseATK + int(math.Round(dmg*0.12+core*0.05))
		st.DEF = bp.BaseDEF
	}
	if containsStr(st.Specials, AlloySpecial[MatLivingMithril]) {
		st.Weight *= 0.5
	}
	st.Weight = float32(math.Round(float64(st.Weight)*10) / 10)
	if st.Weight < 0.2 {
		st.Weight = 0.2
	}
	if st.ToolTier == 0 && bp.Tool != ToolNone {
		st.ToolTier = 1
	}
	st.Name = bp.Name
	if mainName != "" {
		st.Name = fmt.Sprintf("%s de %s", bp.Name, mainName)
	}
	return st
}

func containsStr(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

// --- Peças únicas do jogador ---

// CustomItem é uma liga sintética ou um equipamento forjado deste jogador.
type CustomItem struct {
	ID        uint8
	Kind      uint8
	Name      string
	Desc      string
	Material  MaterialDef // ligas sintéticas: propriedades como material
	Info      ItemInfo    // equipamentos: peso, slot e bônus
	Tool      ToolDef
	Stats     ForgedStats
	Signature string // ligas: ingredientes ordenados (a mesma mistura reaproveita a peça)
}

// itemInfoLocked: catálogo com as peças únicas do jogador por cima (chamar com p.Mu travado).
func (p *Player) itemInfoLocked(id uint8) ItemInfo {
	if c, ok := p.CustomItems[id]; ok {
		if c.Kind == CustomAlloy {
			return ItemInfo{Name: c.Name, Weight: c.Material.Weight, Slot: NoSlot}
		}
		return c.Info
	}
	return GetItemInfo(id)
}

// materialLocked: material do catálogo ou liga sintética do jogador.
func (p *Player) materialLocked(id uint8) (MaterialDef, bool) {
	if c, ok := p.CustomItems[id]; ok && c.Kind == CustomAlloy {
		return c.Material, true
	}
	return GetMaterial(id)
}

// slotForItemLocked: slot de equipamento, considerando as peças forjadas.
func (p *Player) slotForItemLocked(id uint8) (uint8, bool) {
	if c, ok := p.CustomItems[id]; ok {
		if c.Kind == CustomEquip && c.Info.Slot != NoSlot {
			return c.Info.Slot, true
		}
		return 255, false
	}
	return getSlotForItem(id)
}

// IsEquippableFor: como IsEquippable, mas conhece as peças forjadas do jogador.
func (p *Player) IsEquippableFor(id uint8) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	_, ok := p.slotForItemLocked(id)
	return ok
}

// customToolTierLocked: maior tier entre as ferramentas forjadas do tipo pedido na mochila/mão.
func (p *Player) customToolTierLocked(kind ToolKind) uint8 {
	var best uint8
	for id, c := range p.CustomItems {
		if c.Kind != CustomEquip || c.Tool.Kind != kind {
			continue
		}
		if p.Inventory[id] > 0 || p.EquippedSlots[protocol.SlotMainHand] == id {
			if c.Tool.Tier > best {
				best = c.Tool.Tier
			}
		}
	}
	return best
}

// allocCustomLocked: primeiro ID livre (nem na mochila nem equipado); peças sumidas são reaproveitadas.
func (p *Player) allocCustomLocked() (uint8, bool) {
	if p.CustomItems == nil {
		p.CustomItems = make(map[uint8]*CustomItem)
	}
	for id := CustomItemFirstID; ; id++ {
		inUse := p.Inventory[id] > 0
		for _, eq := range p.EquippedSlots {
			if eq == id {
				inUse = true
			}
		}
		if !inUse {
			delete(p.CustomItems, id)
			return id, true
		}
		if id == CustomItemLastID {
			return 0, false
		}
	}
}

// GetCustomItems devolve uma cópia das peças únicas que ainda existem (mochila ou equipadas).
func (p *Player) GetCustomItems() []CustomItem {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	var out []CustomItem
	for id, c := range p.CustomItems {
		alive := p.Inventory[id] > 0
		for _, eq := range p.EquippedSlots {
			if eq == id {
				alive = true
			}
		}
		if alive {
			out = append(out, *c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// KnowsBlueprint informa se o jogador já aprendeu a blueprint (as básicas todos sabem).
func (p *Player) KnowsBlueprint(id uint8) bool {
	if bp, ok := GetBlueprint(id); ok && bp.Basic {
		return true
	}
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.KnownBlueprints[id]
}

// LearnBlueprint ensina uma blueprint; false se já sabia.
func (p *Player) LearnBlueprint(id uint8) bool {
	if p.KnowsBlueprint(id) {
		return false
	}
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.KnownBlueprints == nil {
		p.KnownBlueprints = make(map[uint8]bool)
	}
	p.KnownBlueprints[id] = true
	return true
}

// KnownBlueprintIDs: todas as blueprints que o jogador pode usar.
func (p *Player) KnownBlueprintIDs() []uint8 {
	var ids []uint8
	for _, b := range Blueprints {
		if p.KnowsBlueprint(b.ID) {
			ids = append(ids, b.ID)
		}
	}
	return ids
}

// ForgeResult: o que saiu do cadinho ou da bigorna.
type ForgeResult struct {
	ItemID  uint8
	Qty     uint8
	Quality uint8
	Name    string
	Message string
}

// takeIngredientsLocked retira 1 unidade de cada item (a melhor) e devolve a média das Qualidades.
func (p *Player) takeIngredientsLocked(ids []uint8) uint8 {
	total := 0
	for _, id := range ids {
		q, _ := p.takeUnitLocked(id, AnyQuality)
		total += int(q)
	}
	return uint8(total / len(ids))
}

func (p *Player) hasEachLocked(ids []uint8) bool {
	need := map[uint8]uint8{}
	for _, id := range ids {
		need[id]++
	}
	for id, n := range need {
		if p.Inventory[id] < n {
			return false
		}
	}
	return true
}

// SmeltAlloy funde até 4 ingredientes no cadinho: receita fixa ou Liga Sintética Customizada.
func (p *Player) SmeltAlloy(ings []uint8) (ForgeResult, error) {
	if len(ings) < 2 || len(ings) > MaxCrucibleSlots {
		return ForgeResult{}, fmt.Errorf("coloque de 2 a 4 ingredientes no cadinho")
	}
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if !p.hasEachLocked(ings) {
		return ForgeResult{}, fmt.Errorf("faltam ingredientes na mochila")
	}
	mats := make([]MaterialDef, len(ings))
	ids16 := make([]uint16, len(ings))
	hasBase := false
	for i, id := range ings {
		m, ok := p.materialLocked(id)
		if !ok {
			return ForgeResult{}, fmt.Errorf("%s não derrete no cadinho", p.itemInfoLocked(id).Name)
		}
		mats[i], ids16[i] = m, m.ID
		switch m.Category {
		case MatMetal, MatAlloy, MatCrystal, MatStone:
			hasBase = true
		}
	}
	if r, ok := MatchAlloyRecipe(ids16); ok {
		q := p.takeIngredientsLocked(ings)
		out := uint8(r.Output)
		p.markDiscoveredLocked(out)
		p.addUnitsLocked(out, r.Qty, q)
		name := MaterialsDB[r.Output].Name
		return ForgeResult{ItemID: out, Qty: r.Qty, Quality: q, Name: name,
			Message: fmt.Sprintf("🔥 A Fornalha rugiu: %dx %s (Qualidade %d)!", r.Qty, name, q)}, nil
	}
	if !hasBase {
		return ForgeResult{}, fmt.Errorf("a mistura precisa de uma base mineral (metal, liga, pedra ou cristal)")
	}
	syn := SyntheticAlloy(mats)
	sig := alloySignature(ids16)
	id := uint8(0)
	for cid, c := range p.CustomItems {
		if c.Kind == CustomAlloy && c.Signature == sig && (p.Inventory[cid] > 0) {
			id = cid
		}
	}
	if id == 0 {
		var ok bool
		if id, ok = p.allocCustomLocked(); !ok {
			return ForgeResult{}, fmt.Errorf("você já guarda peças únicas demais (máx. 55)")
		}
		syn.ID = uint16(id)
		p.CustomItems[id] = &CustomItem{ID: id, Kind: CustomAlloy, Name: syn.Name, Desc: syn.Trait, Material: syn, Signature: sig}
	}
	q := p.takeIngredientsLocked(ings)
	if p.DiscoveredMaterials == nil {
		p.DiscoveredMaterials = make(map[uint16]bool)
	}
	p.DiscoveredMaterials[uint16(id)] = true
	p.addUnitsLocked(id, 1, q)
	return ForgeResult{ItemID: id, Qty: 1, Quality: q, Name: syn.Name,
		Message: fmt.Sprintf("⚗️ Fusão livre: nasceu a %s (Qualidade %d)!", syn.Name, q)}, nil
}

func alloySignature(ids []uint16) string {
	s := append([]uint16(nil), ids...)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	return fmt.Sprint(s)
}

// SyntheticAlloy soma as propriedades dos ingredientes (fusão livre).
func SyntheticAlloy(mats []MaterialDef) MaterialDef {
	out := MaterialDef{Category: MatAlloy}
	var base MaterialDef
	var parts []string
	resSeen := map[string]bool{}
	var res []string
	for _, m := range mats {
		out.Durability += m.Durability
		out.Weight += m.Weight
		out.CondThermal += m.CondThermal
		out.CondElectric += m.CondElectric
		out.CondMagic += m.CondMagic
		if m.Rarity > out.Rarity {
			out.Rarity = m.Rarity
		}
		if base.Name == "" && (m.Category == MatMetal || m.Category == MatAlloy) {
			base = m
		}
		for _, r := range strings.Split(m.Resistances, ", ") {
			if r != "" && r != "—" && !resSeen[r] {
				resSeen[r] = true
				res = append(res, r)
			}
		}
		parts = append(parts, m.Name)
	}
	if base.Name == "" {
		base = mats[0]
	}
	n := len(mats)
	out.Durability = int(float64(out.Durability) * 0.75) // a fusão livre perde um pouco da dureza
	if out.Durability < 20 {
		out.Durability = 20
	}
	out.Weight = float32(math.Round(float64(out.Weight)/float64(n)*10) / 10)
	out.CondThermal = min(100, out.CondThermal/n+10)
	out.CondElectric = min(100, out.CondElectric/n+10)
	out.CondMagic = min(100, out.CondMagic/n+10)
	if len(res) == 0 {
		res = []string{"—"}
	}
	out.Resistances = strings.Join(res, ", ")
	out.Name = fmt.Sprintf("Liga de %s", strings.TrimPrefix(base.Name, "Liga de "))
	if len(mats) > 2 {
		out.Name += " Composta"
	}
	out.Trait = "Liga sintética: " + strings.Join(parts, " + ") + "."
	return out
}

// ForgeBlueprint monta o equipamento: picks[i] = item usado na peça i (0 = peça opcional vazia).
func (p *Player) ForgeBlueprint(bpID uint8, picks []uint8) (ForgeResult, error) {
	bp, ok := GetBlueprint(bpID)
	if !ok {
		return ForgeResult{}, fmt.Errorf("blueprint desconhecida")
	}
	if !p.KnowsBlueprint(bpID) {
		return ForgeResult{}, fmt.Errorf("você ainda não aprendeu a blueprint %s", bp.Name)
	}
	if len(picks) != len(bp.Parts) {
		return ForgeResult{}, fmt.Errorf("escolha o material de cada peça")
	}
	p.Mu.Lock()
	defer p.Mu.Unlock()
	mats := make([]MaterialDef, len(picks))
	specials := map[uint16]string{}
	var used []uint8
	for i, id := range picks {
		part := bp.Parts[i]
		if id == 0 {
			if !part.Optional {
				return ForgeResult{}, fmt.Errorf("falta o material da peça %s", part.Name)
			}
			continue
		}
		m, ok := p.materialLocked(id)
		if !ok || !PartAccepts(part, m) {
			return ForgeResult{}, fmt.Errorf("%s não serve para a peça %s", p.itemInfoLocked(id).Name, part.Name)
		}
		if !p.DiscoveredMaterials[uint16(id)] {
			return ForgeResult{}, fmt.Errorf("você ainda não conhece %s", m.Name)
		}
		mats[i] = m
		if sp, ok := AlloySpecial[m.ID]; ok {
			specials[m.ID] = sp
		}
		used = append(used, id)
	}
	if !p.hasEachLocked(used) {
		return ForgeResult{}, fmt.Errorf("faltam materiais na mochila")
	}
	st := ComputeForged(bp, mats, specials)
	id, ok := p.allocCustomLocked()
	if !ok {
		return ForgeResult{}, fmt.Errorf("você já guarda peças únicas demais (máx. 55)")
	}
	q := p.takeIngredientsLocked(used)
	info := ItemInfo{Name: st.Name, Weight: st.Weight, Slot: bp.Slot, BonusATK: uint16(st.ATK), BonusDEF: uint16(st.DEF), BonusHP: uint16(st.HP)}
	c := &CustomItem{ID: id, Kind: CustomEquip, Name: st.Name, Info: info, Stats: st, Desc: ForgedDescription(st)}
	if bp.Tool != ToolNone {
		c.Tool = ToolDef{Kind: bp.Tool, Tier: st.ToolTier}
	}
	p.CustomItems[id] = c
	p.addUnitsLocked(id, 1, q)
	return ForgeResult{ItemID: id, Qty: 1, Quality: q, Name: st.Name,
		Message: fmt.Sprintf("🔨 Você forjou: %s (Qualidade %d)!", st.Name, q)}, nil
}

// ForgedDescription: texto completo das peças e atributos (inventário).
func ForgedDescription(st ForgedStats) string {
	lines := []string{strings.Join(st.PartsText, " + ")}
	lines = append(lines, fmt.Sprintf("Durabilidade %d | Peso %.1f kg | Condutividade: Térmica %d%%, Elétrica %d%%, Mágica %d%%",
		st.Durability, st.Weight, st.Thermal, st.Electric, st.Magic))
	if len(st.Resistances) > 0 {
		lines = append(lines, "Resistências: "+strings.Join(st.Resistances, ", "))
	}
	if len(st.Specials) > 0 {
		lines = append(lines, "Características: "+strings.Join(st.Specials, ForgeTraitSep))
	}
	return strings.Join(lines, "\n")
}
