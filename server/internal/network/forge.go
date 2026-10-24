package network

import (
	"encoding/binary"
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
	if p.ClassID == smithClassID || p.DevForgeAccess {
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
	case protocol.PacketTypeFusionQuery:
		s.sendFusionInfo(player, data[1:protocol.FusionQueryPacketSize])
		return
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
		ings := protocol.ReadItemIDs(data[1:], 4, true)
		res, err = player.SmeltAlloy(ings)
	case protocol.PacketTypeForgeBlueprint:
		bp, ok := world.GetBlueprint(data[1])
		if !ok {
			return
		}
		picks := protocol.ReadItemIDs(data[2:], len(bp.Parts), false)
		res, err = player.ForgeBlueprint(bp.ID, picks)
	case protocol.PacketTypeForgeAlloyScored:
		ings := protocol.ReadItemIDs(data[1:9], 4, true)
		res, err = player.SmeltAlloyScored(ings, world.ScoresFromBytes(data[9:]))
	case protocol.PacketTypeForgeBlueprintScored:
		bp, ok := world.GetBlueprint(data[1])
		if !ok {
			return
		}
		picks := protocol.ReadItemIDs(data[2:], len(bp.Parts), false)
		res, err = player.ForgeBlueprintScored(bp.ID, picks, world.ScoresFromBytes(data[2+2*protocol.ForgeMaxParts:]))
	case protocol.PacketTypeReforgePart:
		wr, werr := player.WorkPart(data[1], int(data[2]), binary.LittleEndian.Uint16(data[3:5]), world.ScoresFromBytes(data[5:]))
		s.sendPartResult(player, data[1], data[2], wr, werr)
		return
	case protocol.PacketTypePuzzlePart:
		wr, werr := player.WorkPuzzlePart(int(data[1]), data[2], binary.LittleEndian.Uint16(data[3:5]), world.ScoresFromBytes(data[5:]))
		s.sendPartResult(player, 0, data[1], wr, werr)
		return
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
func (s *Server) useBlueprintScroll(p *world.Player, itemID world.ItemID, bp world.BlueprintDef) {
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
	s.sendPuzzleState(p)
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

// handleRegisterCustomWeapon (0x55): Criador Quebra-Cabeça — confere a patente e forja a Obra-Prima.
func (s *Server) handleRegisterCustomWeapon(playerID uint32, body []byte) {
	s.mu.RLock()
	player := s.players[playerID]
	s.mu.RUnlock()
	if player == nil {
		return
	}
	pkt, err := protocol.DeserializeRegisterCustomWeaponBody(body)
	if err != nil {
		return
	}
	if !canUseForge(player) {
		s.sendPlayerNPCSay(player, 0, "🔨 Use a bigorna dentro da Forja do Garrick (ou seja um Forjador de Estrelas).")
		return
	}
	pl := make([]world.PuzzlePlacement, len(pkt.Pieces))
	for i, pc := range pkt.Pieces {
		pl[i] = world.PuzzlePlacement{Module: pc.Module, X: pc.X, Y: pc.Y, Rot: pc.Rot, Material: pc.Material}
	}
	res, err, denied := player.ForgePuzzleScored(pkt.Name, pl, playerName(player), scoresOf(pkt))
	if denied {
		log.Printf("[PATENTE] Jogador #%d tentou forjar um desenho patenteado por %s\n", player.ID, world.PatentOwner(world.PatentKey(pl)))
		writeTCP(player, protocol.SerializeForgeAlert(protocol.ForgeAlertPatentDenied, world.PatentDeniedMessage))
		return
	}
	if err != nil {
		s.sendPlayerNPCSay(player, 0, "⚠️ "+err.Error()+".")
		return
	}
	log.Printf("[PATENTE] %s registrou/forjou \"%s\" (%s)\n", playerName(player), res.Name, world.ShapeSignature(pl))
	writeTCP(player, protocol.SerializeForgeAlert(protocol.ForgeAlertInfo, res.Message))
	s.sendPlayerNPCSay(player, 0, res.Message)
	s.sendForgeState(player)
	s.sendInventorySync(player)
}

// sendPuzzleState (0x57): se o Quebra-Cabeça está liberado e as Blueprints Exclusivas do jogador.
func (s *Server) sendPuzzleState(p *world.Player) {
	var list []protocol.ExclusiveEntry
	for _, b := range p.GetExclusiveBlueprints() {
		e := protocol.ExclusiveEntry{Name: b.Name}
		for _, pc := range b.Placements {
			e.Pieces = append(e.Pieces, protocol.PuzzlePiece{Module: pc.Module, X: pc.X, Y: pc.Y, Rot: pc.Rot, Material: pc.Material})
		}
		list = append(list, e)
	}
	writeTCP(p, protocol.SerializePuzzleState(p.CanUsePuzzleForge(), list))
}

// sendFusionInfo (0x5C): dificuldade do Mini-game 2 para os ingredientes do cadinho.
func (s *Server) sendFusionInfo(p *world.Player, raw []byte) {
	var mats []world.MaterialDef
	for _, id := range protocol.ReadItemIDs(raw, 4, true) {
		if m, ok := p.MaterialFor(id); ok {
			mats = append(mats, m)
		}
	}
	writeTCP(p, protocol.SerializeFusionInfo(world.FusionDifficulty(mats), world.ConductivityDiff(mats)))
}

// scoresOf: notas opcionais do 0x55 (sem notas = forja antiga).
func scoresOf(pkt protocol.RegisterCustomWeapon) world.CraftScores {
	if !pkt.HasScore {
		return world.CraftScores{}
	}
	return world.ScoresFromBytes(pkt.Scores[:])
}

// sendPartResult (0x5E): confirma (ou recusa) a nota que o servidor guardou para a peça.
func (s *Server) sendPartResult(p *world.Player, bpID, partIdx uint8, wr world.WorkResult, err error) {
	status := protocol.PartResultSaved
	msg := "🔨 Peça trabalhada: a nota foi guardada para a montagem final."
	switch {
	case err != nil:
		status = protocol.PartResultDenied
		msg = err.Error()
	case wr.Reforged:
		status = protocol.PartResultReforged
		msg = fmt.Sprintf("🔁 Reforja %d/%d concluída (-15 de Stamina). A nova fusão oxidou %.0f%% do metal.",
			wr.Reforges, world.MaxReforgesPerPart, wr.Oxidation*100)
		s.sendPlayerStats(p)
	}
	sc := wr.Scores
	scores := [protocol.MiniGameCount]uint8{protocol.ScoreToWire(sc.Melt), protocol.ScoreToWire(sc.FusionPt), protocol.ScoreToWire(sc.Mold),
		protocol.ScoreToWire(sc.PrepMetal), protocol.ScoreToWire(sc.ShapePart), protocol.ScoreToWire(sc.Temper), protocol.ScoreToWire(sc.Assembly)}
	writeTCP(p, protocol.SerializePartResult(protocol.PartResult{BlueprintID: bpID, Part: partIdx, Status: status,
		Reforges: uint8(wr.Reforges), MaxReforges: world.MaxReforgesPerPart, Scores: scores, Message: msg}))
}
