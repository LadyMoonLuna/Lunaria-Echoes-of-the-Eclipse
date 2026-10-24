package network

import (
	"fmt"
	"log"
	"math/rand"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Forja — Etapa 2: Fornalha de Ligas e Forja por Blueprints.

const (
	forgeAnvilRange float32 = 6.0 // distância da bigorna (dentro da Forja do Garrick)
	smithClassID    uint8   = 7   // Forjador de Estrelas: forja em qualquer lugar
)

// canUseForge: na Forja do Garrick (perto da bigorna) ou sendo Ferreiro.
func canUseForge(p *world.Player) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	if p.ClassID == smithClassID {
		return true
	}
	if p.ZoneID != world.ZoneForgeInterior {
		return false
	}
	dx, dz := p.PosX-world.ForgeAnvilPos[0], p.PosZ-world.ForgeAnvilPos[1]
	return dx*dx+dz*dz <= forgeAnvilRange*forgeAnvilRange
}

func (s *Server) handleForgePacket(playerID uint32, data []byte) {
	s.mu.RLock()
	player := s.players[playerID]
	s.mu.RUnlock()
	if player == nil {
		return
	}
	switch data[0] {
	case protocol.PacketTypeForgeAction:
		switch data[1] {
		case protocol.ForgeActionBuyBlueprint:
			s.buyBlueprint(player, data[2])
		}
		s.sendForgeState(player)
		return
	}
	if !canUseForge(player) {
		s.sendPlayerNPCSay(player, 0, "🔨 Use a bigorna dentro da Forja do Garrick (ou seja um Forjador de Estrelas).")
		return
	}
	var res world.ForgeResult
	var err error
	switch data[0] {
	case protocol.PacketTypeForgeAlloy:
		var ings []uint8
		for _, id := range data[1:protocol.ForgeAlloyPacketSize] {
			if id != 0 {
				ings = append(ings, id)
			}
		}
		res, err = player.SmeltAlloy(ings)
	case protocol.PacketTypeForgeBlueprint:
		bp, ok := world.GetBlueprint(data[1])
		if !ok {
			return
		}
		picks := append([]uint8(nil), data[2:2+len(bp.Parts)]...)
		res, err = player.ForgeBlueprint(bp.ID, picks)
	default:
		return
	}
	if err != nil {
		s.sendPlayerNPCSay(player, 0, "⚠️ "+err.Error()+".")
		return
	}
	log.Printf("[FORJA] Jogador #%d: %s\n", player.ID, res.Message)
	s.sendPlayerNPCSay(player, 0, res.Message)
	s.sendForgeState(player)
	s.sendInventorySync(player)
	s.sendDiscoveries(player, false)
}

// buyBlueprint: Garrick vende as blueprints com preço.
func (s *Server) buyBlueprint(p *world.Player, id uint8) {
	bp, ok := world.GetBlueprint(id)
	if !ok || bp.Price == 0 {
		s.sendPlayerNPCSay(p, 100, "Essa blueprint eu não vendo. Dizem que só existe em ruínas antigas...")
		return
	}
	if p.KnowsBlueprint(id) {
		s.sendPlayerNPCSay(p, 100, "Você já conhece essa blueprint, aprendiz.")
		return
	}
	p.Mu.Lock()
	paid := p.Gold >= bp.Price
	if paid {
		p.Gold -= bp.Price
	}
	p.Mu.Unlock()
	if !paid {
		s.sendPlayerNPCSay(p, 100, fmt.Sprintf("A blueprint %s custa %d Sollares.", bp.Name, bp.Price))
		return
	}
	p.LearnBlueprint(id)
	s.sendInventorySync(p)
	s.sendPlayerNPCSay(p, 100, fmt.Sprintf("📜 Aqui está a blueprint %s. Cuide bem dela!", bp.Name))
}

// useBlueprintScroll: ler uma Blueprint Antiga ensina a blueprint e consome o pergaminho.
func (s *Server) useBlueprintScroll(p *world.Player, itemID uint8, bp world.BlueprintDef) {
	if !p.LearnBlueprint(bp.ID) {
		s.sendPlayerNPCSay(p, 0, fmt.Sprintf("Você já conhece a blueprint %s.", bp.Name))
		return
	}
	p.RemoveItem(itemID, 1)
	s.sendPlayerNPCSay(p, 0, fmt.Sprintf("📜 Você decifrou a Blueprint Antiga: %s! Ela já aparece na Forja.", bp.Name))
	s.sendInventorySync(p)
	s.sendForgeState(p)
}

// sendForgeState (0x54): blueprints conhecidas + peças únicas do jogador.
func (s *Server) sendForgeState(p *world.Player) {
	var entries []protocol.ForgeCustomEntry
	for _, c := range p.GetCustomItems() {
		e := protocol.ForgeCustomEntry{ID: c.ID, Kind: c.Kind, Slot: world.NoSlot, Name: c.Name, Desc: c.Desc}
		if c.Kind == world.CustomAlloy {
			m := c.Material
			e.Rarity, e.Weight, e.Durability = m.Rarity, m.Weight, uint16(min(m.Durability, 65535))
			e.Thermal, e.Electric, e.Magic = uint8(m.CondThermal), uint8(m.CondElectric), uint8(m.CondMagic)
			e.Resist = m.Resistances
		} else {
			st := c.Stats
			e.Slot, e.Rarity, e.Weight = c.Info.Slot, st.Rarity, c.Info.Weight
			e.ATK, e.DEF, e.HP, e.Durability = c.Info.BonusATK, c.Info.BonusDEF, c.Info.BonusHP, uint16(st.Durability)
			e.Thermal, e.Electric, e.Magic = uint8(st.Thermal), uint8(st.Electric), uint8(st.Magic)
			e.ToolKind, e.ToolTier = uint8(c.Tool.Kind), c.Tool.Tier
		}
		entries = append(entries, e)
	}
	writeTCP(p, protocol.SerializeForgeState(p.KnownBlueprintIDs(), entries))
}

// Chances de Blueprint Antiga: chefes (900+ de vida) e criaturas das Ruínas da Vigília
const (
	bossScrollChance  = 0.35
	ruinsScrollChance = 0.04
)

// rollBlueprintScroll: chefes e ruínas podem deixar uma Blueprint Antiga que o jogador ainda não conhece.
func (s *Server) rollBlueprintScroll(p *world.Player, mob *world.Mob) {
	mob.Mu.RLock()
	maxHP, zone := mob.MaxHP, mob.ZoneID
	mob.Mu.RUnlock()
	chance := 0.0
	switch {
	case maxHP >= 900:
		chance = bossScrollChance
	case zone == world.ZoneRuins:
		chance = ruinsScrollChance
	}
	if chance == 0 || rand.Float64() >= chance {
		return
	}
	var pool []world.BlueprintDef
	for _, b := range world.Blueprints {
		if b.ScrollID != 0 && !p.KnowsBlueprint(b.ID) {
			pool = append(pool, b)
		}
	}
	if len(pool) == 0 {
		return
	}
	b := pool[rand.Intn(len(pool))]
	p.AddItem(b.ScrollID, 1)
	s.sendInventorySync(p)
	s.sendPlayerNPCSay(p, 0, fmt.Sprintf("📜 Entre os restos você encontrou uma Blueprint Antiga: %s! (use-a no inventário)", b.Name))
}
