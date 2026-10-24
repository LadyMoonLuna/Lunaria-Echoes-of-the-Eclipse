package network

import (
	"fmt"
	"log"
	"math/rand"
	"strings"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// --- Materiais descobertos ---

// sendDiscoveries envia ao cliente as descobertas novas (aviso dourado) ou a lista completa.
func (s *Server) sendDiscoveries(p *world.Player, full bool) {
	if full {
		writeTCP(p, protocol.SerializeDiscoveredMaterials(protocol.DiscoveredModeFull, p.DiscoveredList()))
		return
	}
	fresh := p.TakeNewDiscoveries()
	if len(fresh) == 0 {
		return
	}
	writeTCP(p, protocol.SerializeDiscoveredMaterials(protocol.DiscoveredModeNew, fresh))
	for _, id := range fresh {
		log.Printf("[MATERIAIS] Jogador #%d descobriu o material %d (%s)\n", p.ID, id, world.MaterialsDB[id].Name)
	}
}

// --- Nós de coleta ---

func nodeEntries(nodes []world.ResourceNode) []protocol.ResourceNodeEntry {
	out := make([]protocol.ResourceNodeEntry, len(nodes))
	for i, n := range nodes {
		out[i] = protocol.ResourceNodeEntry{NodeID: n.ID, Kind: n.Kind, Material: world.ItemID(n.MaterialID), Tier: n.Tier, Available: n.Available(), X: n.X, Z: n.Z}
	}
	return out
}

// sendResourceNodes envia os nós de coleta da zona do jogador (0x45).
func (s *Server) sendResourceNodes(p *world.Player) {
	if s.resourceNodes == nil {
		return
	}
	writeTCP(p, protocol.SerializeResourceNodesSync(nodeEntries(s.resourceNodes.InZone(p.GetZone()))))
}

// broadcastResourceNodes atualiza os nós de uma zona para todos os jogadores nela.
func (s *Server) broadcastResourceNodes(zone uint8) {
	data := protocol.SerializeResourceNodesSync(nodeEntries(s.resourceNodes.InZone(zone)))
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

// respawnResourceNodes reabre os nós que voltaram a crescer (1 Hz).
func (s *Server) respawnResourceNodes() {
	if s.resourceNodes == nil {
		return
	}
	for _, zone := range s.resourceNodes.RespawnedZones() {
		s.broadcastResourceNodes(zone)
	}
}

func toolRarityName(tier uint8) string {
	if int(tier) < len(world.RarityNames) {
		return world.RarityNames[tier]
	}
	return "?"
}

// harvestYield valida a ferramenta exigida pelo nó e devolve quanto o jogador coleta (0 = bloqueado, com o motivo).
func harvestYield(p *world.Player, n world.ResourceNode) (uint8, string) {
	base := n.BaseYield()
	switch n.Kind {
	case world.NodeTree:
		tier := p.BestTool(world.ToolAxe)
		if tier == 0 {
			return 0, "🪓 Você precisa de um Machado para cortar esta árvore."
		}
		if tier < n.Tier {
			return 0, fmt.Sprintf("🪓 Seu Machado é fraco demais para esta madeira especial! (Requer Machado %s Tier %d+)", toolRarityName(n.Tier), n.Tier)
		}
		return base, ""
	case world.NodeRock, world.NodeOre, world.NodeCrystal:
		tier := p.BestTool(world.ToolPickaxe)
		if tier == 0 {
			return 0, "⛏️ Você precisa de uma Picareta para minerar aqui."
		}
		if tier < n.Tier {
			return 0, fmt.Sprintf("⛏️ Sua Picareta é fraca demais para este minério! (Requer Picareta %s Tier %d+)", toolRarityName(n.Tier), n.Tier)
		}
		return base, ""
	case world.NodeVine:
		if p.BestTool(world.ToolShears) > 0 {
			return base * 2, "" // Tesoura de Herborista: +100%
		}
		if p.HasCuttingWeapon() {
			return base, ""
		}
		return 0, "✂️ Use uma arma cortante (espada, adaga, cutelo) ou uma Tesoura de Herborista para colher."
	case world.NodeBones:
		return base, "" // ossadas: às mãos
	case world.NodeMud:
		if p.BestTool(world.ToolPickaxe) > 0 {
			return base + 1, "" // com a Picareta sai mais barro
		}
		return base, "" // às mãos
	case world.NodeWater:
		flasks := p.GetItemCount(protocol.ItemEmptyFlask)
		if flasks == 0 {
			return 0, "🧪 Você precisa de Frascos de Vidro Vazios para coletar este líquido."
		}
		if flasks < base {
			base = flasks
		}
		return base, ""
	}
	return 0, "Este recurso não pode ser coletado."
}

// harvestQuality: Qualidade da coleta — sorte do corte, melhorada por ferramentas acima do tier pedido
// (e pela Tesoura nas plantas). Coletas não produzem lixo: a pior ainda vale 40.
func harvestQuality(p *world.Player, n world.ResourceNode) uint8 {
	q := 55 + rand.Intn(36) // 55..90
	var tool uint8
	switch n.Kind {
	case world.NodeTree:
		tool = p.BestTool(world.ToolAxe)
	case world.NodeRock, world.NodeOre, world.NodeCrystal:
		tool = p.BestTool(world.ToolPickaxe)
	case world.NodeVine:
		if p.BestTool(world.ToolShears) > 0 {
			q += 10
		}
	case world.NodeMud:
		tool = p.BestTool(world.ToolPickaxe)
	}
	if tool > n.Tier {
		q += int(tool-n.Tier) * 4
	}
	if n.Purified {
		q = 90 + rand.Intn(11) // água abençoada da Fonte da praça
	}
	if q > 100 {
		q = 100
	}
	if q < 40 {
		q = 40
	}
	return uint8(q)
}

// handleHarvestNode (0x44): coleta um nó de recurso a até 4m.
func (s *Server) handleHarvestNode(connPlayerID uint32, pkt protocol.HarvestNodePacket) {
	s.mu.RLock()
	player := s.players[connPlayerID]
	s.mu.RUnlock()
	if player == nil || s.resourceNodes == nil {
		return
	}
	node, ok := s.resourceNodes.Get(pkt.NodeID)
	if !ok {
		return
	}
	player.Mu.RLock()
	px, pz, zone := player.PosX, player.PosZ, player.ZoneID
	player.Mu.RUnlock()
	if node.ZoneID != zone {
		return
	}
	dx, dz := node.X-px, node.Z-pz
	reach := world.HarvestRange
	if node.Kind == world.NodeYggdrasil {
		reach = YggdrasilReach // o tronco é gigantesco: colhe-se ao redor dele
	}
	if dx*dx+dz*dz > reach*reach {
		s.sendPlayerNPCSay(player, 0, "Chegue mais perto do recurso para coletar.")
		return
	}
	if node.Kind == world.NodeYggdrasil {
		s.harvestYggdrasil(player)
		return
	}
	if !node.Available() {
		s.sendPlayerNPCSay(player, 0, "Este recurso já foi coletado. Ele volta a crescer em breve.")
		return
	}
	qty, reason := harvestYield(player, node)
	if qty == 0 {
		s.sendPlayerNPCSay(player, 0, reason)
		return
	}
	if node.Kind == world.NodeWater {
		player.RemoveItem(protocol.ItemEmptyFlask, qty)
	}
	itemID := world.ItemID(node.MaterialID)
	quality := harvestQuality(player, node)
	player.AddItemWithQuality(itemID, qty, quality)
	s.resourceNodes.Deplete(node.ID)
	mat := world.MaterialsDB[node.MaterialID]
	extra := ""
	if w := world.WoodOf(itemID); w != nil && node.Kind == world.NodeTree {
		extra = woodByproducts(player, w, quality)
	}
	s.sendPlayerNPCSay(player, 0, fmt.Sprintf("Você coletou %dx %s — Qualidade %d/100.%s", qty, mat.Name, quality, extra))
	log.Printf("[COLETA] Jogador #%d coletou %dx %s do nó #%d\n", player.ID, qty, mat.Name, node.ID)
	s.sendInventorySync(player)
	s.broadcastResourceNodes(zone)
}

// woodByproducts: ao derrubar a árvore saem galhos; com a Tesoura, folhas (e frutos, se a espécie dá);
// com um Frasco Vazio, um pouco de seiva.
func woodByproducts(p *world.Player, w *world.WoodDef, quality uint8) string {
	var got []string
	give := func(product int, qty uint8) {
		id := world.WoodProductID(w.Index, product)
		p.AddItemWithQuality(id, qty, quality)
		got = append(got, fmt.Sprintf("%dx %s", qty, world.MaterialsDB[uint16(id)].Name))
	}
	give(world.WoodBranches, uint8(1+rand.Intn(3)))
	if p.BestTool(world.ToolShears) > 0 {
		give(world.WoodLeaves, uint8(1+rand.Intn(3)))
		if w.HasProduct(world.WoodFruit) && rand.Float64() < 0.6 {
			give(world.WoodFruit, uint8(1+rand.Intn(2)))
		}
	}
	if p.RemoveItem(protocol.ItemEmptyFlask, 1) {
		give(world.WoodSap, 1)
	}
	if len(got) == 0 {
		return ""
	}
	return " Também: " + strings.Join(got, ", ") + "."
}

// YggdrasilRestHours: a Árvore do Mundo deixa cada viajante colher uma vez por dia de jogo.
const YggdrasilRestHours = 24.0

// YggdrasilReach: distância do centro do tronco em que dá para colher.
const YggdrasilReach float32 = 14

// harvestYggdrasil: galhos (Machado Adamantino ou melhor), folhas e frutos (Tesoura) e seiva (Frasco).
func (s *Server) harvestYggdrasil(p *world.Player) {
	w := world.YggdrasilWood
	now := s.clock.ElapsedHours()
	p.Mu.Lock()
	wait := p.YggdrasilAt + YggdrasilRestHours - now
	if p.YggdrasilAt == 0 {
		wait = 0
	}
	p.Mu.Unlock()
	if wait > 0 {
		s.sendPlayerNPCSay(p, 0, fmt.Sprintf("🌳 A Yggdrasil já lhe deu seus presentes hoje. Volte daqui a %s.", gameHoursText(wait)))
		return
	}
	var got []string
	give := func(product int, qty uint8) {
		id := world.WoodProductID(w.Index, product)
		p.AddItemWithQuality(id, qty, uint8(80+rand.Intn(21)))
		got = append(got, fmt.Sprintf("%dx %s", qty, world.MaterialsDB[uint16(id)].Name))
	}
	if p.BestTool(world.ToolAxe) >= 7 {
		give(world.WoodBranches, 1)
	}
	if p.BestTool(world.ToolShears) > 0 {
		give(world.WoodLeaves, uint8(1+rand.Intn(2)))
		give(world.WoodFruit, 1)
	}
	if p.RemoveItem(protocol.ItemEmptyFlask, 1) {
		give(world.WoodSap, 1)
	}
	if len(got) == 0 {
		s.sendPlayerNPCSay(p, 0, "🌳 A Yggdrasil não pode ser cortada. Para colher dela: Machado Adamantino (galhos), Tesoura de Herborista (folhas e frutos) e Frasco Vazio (seiva).")
		return
	}
	p.Mu.Lock()
	p.YggdrasilAt = now
	p.Mu.Unlock()
	s.sendInventorySync(p)
	s.sendPlayerNPCSay(p, 0, "🌳 A Árvore do Mundo lhe concede: "+strings.Join(got, ", ")+".")
}
