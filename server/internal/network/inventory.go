package network

import (
	"fmt"
	"log"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// toggleEquip equipa a unidade com a Qualidade pedida (255 = a melhor). Sem a unidade na mochila
// e com o item equipado, desequipa (comportamento antigo do 0x39).
func (s *Server) toggleEquip(player *world.Player, itemID, quality uint8) {
	if player.GetItemCount(itemID) == 0 {
		for slotIdx, eqID := range player.GetEquippedSlots() {
			if eqID == itemID && player.UnequipSlot(uint8(slotIdx)) {
				s.sendInventorySync(player)
				s.sendPlayerStats(player)
				return
			}
		}
		return
	}
	ok, msg := player.EquipItemQuality(itemID, quality)
	if ok {
		log.Printf("[EQUIPAMENTO] Jogador #%d equipou item ID %d: %s\n", player.ID, itemID, msg)
		s.sendInventorySync(player)
		s.sendPlayerStats(player)
	}
}

// --- Dinheiro ---

// mobGoldReward: Sollares por abate, proporcional ao XP do monstro (chefes valem muito mais).
func mobGoldReward(mobType uint8) uint32 {
	g := uint32(getMobKillXP(mobType)) / 2
	if g < 3 {
		g = 3
	}
	return g
}

// grantKillGold dá os Sollares do abate ao jogador (+50% para Gnarlin, a raça goblin).
func (s *Server) grantKillGold(p *world.Player, mobType uint8) {
	gold := mobGoldReward(mobType)
	p.Mu.RLock()
	race := p.RaceID
	p.Mu.RUnlock()
	if race == protocol.RaceGoblin {
		gold = gold * 3 / 2
	}
	p.AddGold(gold)
	s.sendInventorySync(p)
}

// --- Itens no chão ---

func groundEntries(items []world.GroundItem) []protocol.GroundItemEntry {
	out := make([]protocol.GroundItemEntry, len(items))
	for i, it := range items {
		out[i] = protocol.GroundItemEntry{DropID: it.DropID, ItemID: it.ItemID, Quantity: it.Quantity, Quality: it.Quality, X: it.X, Z: it.Z}
	}
	return out
}

func writeTCP(p *world.Player, data []byte) {
	if p == nil || p.TCPConn == nil {
		return
	}
	_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
	_, _ = p.TCPConn.Write(data)
	_ = p.TCPConn.SetWriteDeadline(time.Time{})
}

// sendGroundItems envia ao jogador os itens no chão da zona dele (0x42).
func (s *Server) sendGroundItems(p *world.Player) {
	if s.groundItems == nil {
		return
	}
	writeTCP(p, protocol.SerializeGroundItemsSync(groundEntries(s.groundItems.InZone(p.GetZone()))))
}

// broadcastGroundItems envia a lista atualizada a todos os jogadores da zona.
func (s *Server) broadcastGroundItems(zone uint8) {
	data := protocol.SerializeGroundItemsSync(groundEntries(s.groundItems.InZone(zone)))
	s.mu.RLock()
	targets := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		if p.GetZone() == zone {
			targets = append(targets, p)
		}
	}
	s.mu.RUnlock()
	for _, p := range targets {
		writeTCP(p, data)
	}
}

// handleDropItemGround (0x41): tira o item da mochila e o deixa no chão aos pés do jogador.
func (s *Server) handleDropItemGround(connPlayerID uint32, pkt protocol.DropItemGroundPacket) {
	s.mu.RLock()
	player := s.players[connPlayerID]
	s.mu.RUnlock()
	if player == nil {
		return
	}
	qty := pkt.Quantity
	if qty == 0 {
		qty = 1
	}
	itemID := pkt.ItemID
	if player.IsSoulbound(itemID) {
		s.sendPlayerNPCSay(player, 0, "📘 Blueprint Exclusiva é Soulbound: não pode ser largada no chão, vendida nem trocada.")
		return
	}
	if itemID >= world.CustomItemFirstID {
		// Peças únicas só existem na mochila do dono: no chão outro jogador leria a peça dele
		s.sendPlayerNPCSay(player, 0, "Peças forjadas únicas não podem ser largadas no chão.")
		return
	}
	taken := player.TakeItemUnits(itemID, pkt.Quality, qty)
	if taken == 0 {
		return
	}
	player.Mu.RLock()
	x, z, zone := player.PosX, player.PosZ, player.ZoneID
	player.Mu.RUnlock()
	drop := s.groundItems.Drop(itemID, taken, pkt.Quality, x, z, zone)
	log.Printf("[CHÃO] Jogador #%d largou %dx item %d (drop #%d) na zona %d\n", connPlayerID, taken, itemID, drop.DropID, zone)
	s.sendInventorySync(player)
	s.broadcastGroundItems(zone)
}

// handlePickupGroundItem (0x43): qualquer jogador a até 4m pega o item do chão.
func (s *Server) handlePickupGroundItem(connPlayerID uint32, pkt protocol.PickupGroundItemPacket) {
	s.mu.RLock()
	player := s.players[connPlayerID]
	s.mu.RUnlock()
	if player == nil {
		return
	}
	player.Mu.RLock()
	x, z, zone := player.PosX, player.PosZ, player.ZoneID
	player.Mu.RUnlock()
	it, ok := s.groundItems.TryPickup(pkt.DropID, x, z, zone)
	if !ok {
		return
	}
	player.AddItemWithQuality(it.ItemID, it.Quantity, it.Quality) // cada unidade volta com a sua Qualidade
	log.Printf("[CHÃO] Jogador #%d pegou %dx item %d (drop #%d)\n", connPlayerID, it.Quantity, it.ItemID, it.DropID)
	s.sendInventorySync(player)
	s.broadcastGroundItems(zone)
	s.sendPlayerNPCSay(player, 0, fmt.Sprintf("Você pegou %dx %s.", it.Quantity, world.GetItemInfo(it.ItemID).Name))
}

// expireGroundItems remove itens velhos do chão (1 Hz) e atualiza as zonas afetadas.
func (s *Server) expireGroundItems() {
	for _, zone := range s.groundItems.Expire() {
		s.broadcastGroundItems(zone)
	}
}
