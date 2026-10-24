package world

import "lunaria/server/internal/protocol"

// Ferramentas de coleta (IDs 160 a 174). Funcionam na mochila ou na Mão Principal.
type ToolKind uint8

const (
	ToolNone ToolKind = iota
	ToolAxe
	ToolPickaxe
	ToolShears
)

type ToolDef struct {
	Kind ToolKind
	Tier uint8
}

const (
	ItemStoneAxe       ItemID = 160
	ItemIronAxe        ItemID = 161
	ItemTemperedAxe    ItemID = 162
	ItemMithrilAxe     ItemID = 163
	ItemOrichalcumAxe  ItemID = 164
	ItemAdamantineAxe  ItemID = 165
	ItemBlackSunAxe    ItemID = 166
	ItemStonePickaxe   ItemID = 167
	ItemIronPickaxe    ItemID = 168
	ItemTemperedPick   ItemID = 169
	ItemMithrilPickaxe ItemID = 170
	ItemOrichalcumPick ItemID = 171
	ItemAdamantinePick ItemID = 172
	ItemBlackSunPick   ItemID = 173
	ItemHerbalShears   ItemID = 174
)

// ToolsDB: tipo e tier de cada ferramenta. O tier precisa ser >= ao tier (raridade) do nó.
var ToolsDB = map[ItemID]ToolDef{
	ItemStoneAxe: {ToolAxe, 1}, ItemIronAxe: {ToolAxe, 2}, ItemTemperedAxe: {ToolAxe, 3}, ItemMithrilAxe: {ToolAxe, 4},
	ItemOrichalcumAxe: {ToolAxe, 5}, ItemAdamantineAxe: {ToolAxe, 7}, ItemBlackSunAxe: {ToolAxe, 8},
	ItemStonePickaxe: {ToolPickaxe, 1}, ItemIronPickaxe: {ToolPickaxe, 2}, ItemTemperedPick: {ToolPickaxe, 3}, ItemMithrilPickaxe: {ToolPickaxe, 4},
	ItemOrichalcumPick: {ToolPickaxe, 5}, ItemAdamantinePick: {ToolPickaxe, 7}, ItemBlackSunPick: {ToolPickaxe, 8},
	ItemHerbalShears: {ToolShears, 1},
}

var toolItems = map[ItemID]ItemInfo{
	ItemStoneAxe:       {Name: "Machado Velho", Weight: 3.0, Slot: NoSlot},
	ItemIronAxe:        {Name: "Machado de Ferro", Weight: 3.5, Slot: NoSlot},
	ItemTemperedAxe:    {Name: "Machado de Aço Temperado", Weight: 3.5, Slot: NoSlot},
	ItemMithrilAxe:     {Name: "Machado de Mithril", Weight: 2.0, Slot: NoSlot},
	ItemOrichalcumAxe:  {Name: "Machado de Oricalco", Weight: 3.8, Slot: NoSlot},
	ItemAdamantineAxe:  {Name: "Machado Adamantino", Weight: 4.5, Slot: NoSlot},
	ItemBlackSunAxe:    {Name: "Machado do Sol Negro", Weight: 4.0, Slot: NoSlot},
	ItemStonePickaxe:   {Name: "Picareta Desgastada", Weight: 3.5, Slot: NoSlot},
	ItemIronPickaxe:    {Name: "Picareta de Ferro", Weight: 4.0, Slot: NoSlot},
	ItemTemperedPick:   {Name: "Picareta de Aço Temperado", Weight: 4.0, Slot: NoSlot},
	ItemMithrilPickaxe: {Name: "Picareta de Mithril", Weight: 2.5, Slot: NoSlot},
	ItemOrichalcumPick: {Name: "Picareta de Oricalco", Weight: 4.2, Slot: NoSlot},
	ItemAdamantinePick: {Name: "Picareta Adamantina", Weight: 5.0, Slot: NoSlot},
	ItemBlackSunPick:   {Name: "Picareta do Sol Negro", Weight: 4.5, Slot: NoSlot},
	ItemHerbalShears:   {Name: "Tesoura de Herborista", Weight: 0.8, Slot: NoSlot},
}

// Armas cortantes que colhem vinhas e arbustos (1x) quando não há tesoura.
var cuttingWeapons = map[ItemID]bool{
	protocol.ItemIronLongsword: true, protocol.ItemSteelDagger: true, protocol.ItemOffhandDagger: true,
	protocol.ItemGiantCleaver: true, protocol.ItemColossalSword: true, protocol.ItemSteelNeedles: true,
	protocol.ItemInquisitorShadowScythe: true, protocol.ItemAutopsyDagger: true,
}

func init() {
	for id, info := range toolItems {
		ItemCatalog[id] = info
	}
}

// BestTool devolve o maior tier da ferramenta do tipo pedido (mochila ou Mão Principal); 0 = não tem.
func (p *Player) BestTool(kind ToolKind) uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	var best uint8
	check := func(id ItemID) {
		if t, ok := ToolsDB[id]; ok && t.Kind == kind && t.Tier > best {
			best = t.Tier
		}
	}
	for id, qty := range p.Inventory {
		if qty > 0 {
			check(id)
		}
	}
	check(p.EquippedSlots[protocol.SlotMainHand])
	if t := p.customToolTierLocked(kind); t > best {
		best = t // ferramentas forjadas por blueprint
	}
	return best
}

// HasCuttingWeapon: alguma arma cortante equipada ou na mochila.
func (p *Player) HasCuttingWeapon() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	for _, id := range []ItemID{p.EquippedSlots[protocol.SlotMainHand], p.EquippedSlots[protocol.SlotOffHand]} {
		if cuttingWeapons[id] {
			return true
		}
	}
	for id, qty := range p.Inventory {
		if qty > 0 && cuttingWeapons[id] {
			return true
		}
	}
	return false
}

// --- Materiais descobertos ---

// markDiscoveredLocked registra o material como visto; retorna true se é a primeira vez.
func (p *Player) markDiscoveredLocked(itemID ItemID) bool {
	if !IsMaterial(itemID) {
		return false
	}
	if p.DiscoveredMaterials == nil {
		p.DiscoveredMaterials = make(map[uint16]bool)
	}
	if p.DiscoveredMaterials[uint16(itemID)] {
		return false
	}
	p.DiscoveredMaterials[uint16(itemID)] = true
	p.newDiscoveries = append(p.newDiscoveries, uint16(itemID))
	return true
}

// TakeNewDiscoveries devolve (e limpa) os materiais descobertos desde a última sincronização.
func (p *Player) TakeNewDiscoveries() []uint16 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	out := p.newDiscoveries
	p.newDiscoveries = nil
	return out
}

// DiscoveredList devolve todos os materiais conhecidos, em ordem.
func (p *Player) DiscoveredList() []uint16 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	out := make([]uint16, 0, len(p.DiscoveredMaterials))
	for id := uint16(0); id < 256; id++ {
		if p.DiscoveredMaterials[id] {
			out = append(out, id)
		}
	}
	return out
}

// IsDiscovered informa se o jogador já viu o material.
func (p *Player) IsDiscovered(materialID uint16) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.DiscoveredMaterials[materialID]
}

func startingDiscoveries() map[uint16]bool {
	m := make(map[uint16]bool)
	for _, id := range StartingDiscoveredMaterials {
		m[id] = true
	}
	return m
}
