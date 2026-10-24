package network

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"sort"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Guilda dos Ofícios: o quadro (no pavilhão da Vila) onde os NPCs penduram as encomendas de
// matéria-prima e de comida. Encomenda é contrato: o preço combinado não cai com a oferta.

// GuildBoardPos: quadro de encomendas no pavilhão da Guilda (sudoeste da praça).
var GuildBoardPos = [2]float32{-24, -46}

const guildBoardRange float32 = 5.0

type guildOrder struct {
	NPC     uint32 `json:"npc"`
	NPCName string `json:"npc_name"`
	ID      uint16 `json:"id"`
	Wanted  int    `json:"wanted"`
	Price   uint32 `json:"price"`
	Have    int    `json:"have"`
	Food    bool   `json:"food"`
}

type guildState struct {
	Orders []guildOrder `json:"orders"`
	Msg    string       `json:"msg"`
	Gold   uint32       `json:"player_gold"`
}

func nearGuildBoard(p *world.Player) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	dx, dz := p.PosX-GuildBoardPos[0], p.PosZ-GuildBoardPos[1]
	return p.ZoneID == world.ZoneVillage && dx*dx+dz*dz <= guildBoardRange*guildBoardRange
}

func (s *Server) sendGuildState(p *world.Player, msg string) {
	st := guildState{Msg: msg, Orders: []guildOrder{}}
	s.mu.RLock()
	npcs := make([]*world.NPC, 0, len(s.npcs))
	for _, n := range s.npcs {
		npcs = append(npcs, n)
	}
	s.mu.RUnlock()
	for _, npc := range npcs {
		npc.WithLife(func(n *world.NPC) {
			if n.IsDead {
				return
			}
			for _, o := range n.Life.BuyOrders {
				st.Orders = append(st.Orders, guildOrder{NPC: n.ID, NPCName: n.Name, ID: o.Material, Wanted: o.Wanted, Price: o.Price,
					Food: guildFood[o.Material]})
			}
		})
	}
	for i := range st.Orders {
		st.Orders[i].Have = int(p.GetItemCount(uint8(st.Orders[i].ID)))
	}
	sort.Slice(st.Orders, func(i, j int) bool {
		if st.Orders[i].Food != st.Orders[j].Food {
			return st.Orders[i].Food // comida primeiro: tem gente com fome
		}
		return st.Orders[i].NPCName < st.Orders[j].NPCName
	})
	p.Mu.RLock()
	st.Gold = p.Gold
	p.Mu.RUnlock()
	body, _ := json.Marshal(st)
	writeTCP(p, protocol.SerializeJSONPacket(protocol.PacketTypeGuildState, body))
}

// Comida que os NPCs pedem na Guilda quando não têm o que comer.
var guildFood = map[uint16]bool{world.MatGameMeat: true, uint16(protocol.ItemRawWolfMeat): true, uint16(protocol.ItemCookedNobleMeat): true}

func (s *Server) handleGuildAction(playerID uint32, data []byte) {
	if len(data) < protocol.GuildActionPacketSize {
		return
	}
	s.mu.RLock()
	p := s.players[playerID]
	s.mu.RUnlock()
	if p == nil {
		return
	}
	if !nearGuildBoard(p) {
		s.sendGuildState(p, "Vá até o quadro da Guilda dos Ofícios (pavilhão a sudoeste da praça).")
		return
	}
	action := data[1]
	npcID := binary.LittleEndian.Uint32(data[2:6])
	item, qty := data[6], data[7]
	msg := ""
	if action == protocol.GuildActionDeliver && qty > 0 {
		msg = s.guildDeliver(p, npcID, item, qty)
	}
	s.sendGuildState(p, msg)
}

// guildDeliver entrega itens de uma encomenda pelo preço combinado (a Guilda leva o pacote ao NPC).
func (s *Server) guildDeliver(p *world.Player, npcID uint32, item, qty uint8) string {
	s.mu.RLock()
	npc := s.npcs[npcID]
	s.mu.RUnlock()
	if npc == nil {
		return "Essa encomenda não existe mais."
	}
	var order world.BuyOrder
	var gold uint32
	open := false
	npc.WithLife(func(n *world.NPC) {
		order, open = n.Life.BuyOrders[uint16(item)]
		gold = n.Gold
	})
	if !open || order.Wanted <= 0 {
		return "Essa encomenda já foi atendida."
	}
	n := min(int(qty), order.Wanted)
	if order.Price > 0 {
		n = min(n, int(gold/order.Price))
	}
	if n <= 0 {
		return fmt.Sprintf("%s está sem ouro para pagar agora.", npc.Name)
	}
	taken := 0
	for _, q := range p.UnitQualities(item) {
		if taken >= n {
			break
		}
		taken += int(p.TakeItemUnits(item, q, 1))
	}
	if taken == 0 {
		return "Você não tem esse item."
	}
	total := order.Price * uint32(taken)
	npc.WithLife(func(nn *world.NPC) {
		nn.Gold -= min(total, nn.Gold)
		nn.RawMaterials[uint16(item)] += taken
		o := nn.Life.BuyOrders[uint16(item)]
		o.Wanted -= taken
		if o.Wanted <= 0 {
			delete(nn.Life.BuyOrders, uint16(item))
			delete(nn.Life.OrderSince, uint16(item))
		} else {
			nn.Life.BuyOrders[uint16(item)] = o
		}
	})
	p.AddGold(total)
	s.sendInventorySync(p)
	s.sendPlayerStats(p)
	s.BroadcastNPCSay(npcID, fmt.Sprintf("📜 A Guilda me entregou %d× %s. Muito obrigado, aventureiro!", taken, world.ItemName(item)))
	return fmt.Sprintf("Entregue: %d× %s para %s por %d Sollares.", taken, world.ItemName(item), npc.Name, total)
}

// --- Fonte de Água Purificada (centro da Vila) ---

const fountainUseRange float32 = 5.5

func (s *Server) handleFountainUse(playerID uint32, action uint8) {
	s.mu.RLock()
	p := s.players[playerID]
	s.mu.RUnlock()
	if p == nil {
		return
	}
	p.Mu.RLock()
	dx, dz := p.PosX-world.PurifiedFountainPos[0], p.PosZ-world.PurifiedFountainPos[1]
	zone := p.ZoneID
	p.Mu.RUnlock()
	if zone != world.ZoneVillage || dx*dx+dz*dz > fountainUseRange*fountainUseRange {
		return
	}
	s.conflict.mu.Lock()
	dry := s.conflict.fountainDry
	s.conflict.mu.Unlock()
	if dry {
		s.sendPlayerNPCSay(p, 0, "🏜️ A Fonte está seca por causa do calor. Só resta o Rio Prateado, a leste.")
		return
	}
	switch action {
	case 1: // beber
		p.DrinkFountain()
		s.sendPlayerStats(p)
		s.sendPlayerNPCSay(p, 0, "💧 Você bebe da Fonte Purificada. A água gelada refresca o corpo e alivia o cansaço.")
	case 2: // encher frascos
		n := p.GetItemCount(protocol.ItemEmptyFlask)
		if n == 0 {
			s.sendPlayerNPCSay(p, 0, "Você precisa de Frascos de Vidro Vazios (a Alquimista Lyra vende).")
			return
		}
		p.RemoveItem(protocol.ItemEmptyFlask, n)
		p.AddItemWithQuality(uint8(world.MatPureWater), n, 95)
		s.sendInventorySync(p)
		s.sendPlayerNPCSay(p, 0, fmt.Sprintf("🧪 Você encheu %d frasco(s) com Água Pura da Fonte (Qualidade 95).", n))
	case 3: // lavar-se
		cold := p.WashAtFountain(world.AmbientTemp(world.ZoneVillage, s.clock.GetCurrentHour(), s.clock.GetZoneWeather(world.ZoneVillage)))
		if cold {
			s.sendPlayerNPCSay(p, 0, "🫧 Você se lava na Fonte... a água está gelada e o vento frio arrepia!")
		} else {
			s.sendPlayerNPCSay(p, 0, "🫧 Você lava o rosto e os braços. O calor some e você se sente renovado.")
		}
	}
}
