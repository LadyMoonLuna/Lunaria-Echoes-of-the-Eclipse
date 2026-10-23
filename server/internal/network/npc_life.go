package network

import (
	"fmt"
	"log"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Mundo Vivo (Fase 1, Parte 1): tick biológico, produção real, encomendas e coleta autônoma dos NPCs.

const (
	npcErrandSpeed  float32 = 2.6
	npcArriveDist   float32 = 1.5
	npcGatherYield          = 2
	shopTradeRange  float32 = 6.0
	shopUnitQuality uint8   = 80
	npcSpeechGap            = 20 * time.Second
)

// initNPCLife dá a cada NPC vivo seus valores do Mundo Vivo (o posto de trabalho é a posição inicial).
func (s *Server) initNPCLife(npcs []*world.NPC) {
	for _, npc := range npcs {
		x, _, z := npc.GetPos()
		home := [2]float32{x, z}
		if npc.ID == 100 {
			home = world.PlaceFurnace // Garrick trabalha na Fornalha
		}
		npc.InitLife(home)
	}
}

// updateNPCLife roda a 1 Hz: necessidades, afazeres, produção e encomendas.
func (s *Server) updateNPCLife(dt float32) {
	hour := s.clock.GetCurrentHour()
	s.mu.RLock()
	npcs := make([]*world.NPC, 0, len(s.npcs))
	for _, n := range s.npcs {
		npcs = append(npcs, n)
	}
	s.mu.RUnlock()
	for _, npc := range npcs {
		s.tickNPCLife(npc, dt, hour, s.clock.GetZoneWeather(npc.GetZone()))
	}
}

// lifeEvents são efeitos colhidos com o NPC travado e aplicados depois (falas, refeição, nós).
type lifeEvents struct {
	says       []string
	died       bool
	buyMeal    bool
	depleted   []uint8
	zoneChange bool
}

func (s *Server) tickNPCLife(npc *world.NPC, dt float32, hour int, weather uint8) {
	var ev lifeEvents
	tavern := s.tavernHasMeal()
	villageNodes := s.resourceNodes.InZone(world.ZoneVillage)
	forestNodes := s.resourceNodes.InZone(world.ZoneForest)
	now := time.Now()

	npc.WithLife(func(n *world.NPC) {
		if !n.Life.Enabled || n.IsDead || !n.IsActive {
			return
		}
		if n.TickNeeds(dt, hour, weather) {
			ev.died = true
			return
		}
		if len(n.Life.Plan) == 0 {
			planNeeds(n, tavern, villageNodes, &ev)
		}
		if len(n.Life.Plan) == 0 {
			produceAndOrder(n, now, villageNodes, forestNodes, &ev)
		}
		if len(n.Life.Plan) > 0 {
			if n.IsPatrolling {
				n.Life.WasPatrolling = true
				n.IsPatrolling = false
			}
			s.advanceErrand(n, &ev)
			if len(n.Life.Plan) == 0 && n.Life.WasPatrolling {
				n.IsPatrolling = true
				n.Life.WasPatrolling = false
				n.CurrentActivity = world.ActivityWorking
			}
		} else if world.IsColdHour(hour) && hour < 6 {
			n.CurrentActivity = world.ActivitySleeping
		} else {
			n.CurrentActivity = world.ActivityWorking
		}
		if len(ev.says) > 0 {
			if now.Sub(n.Life.LastSpeech) < npcSpeechGap {
				ev.says = nil
			} else {
				n.Life.LastSpeech = now
			}
		}
	})

	if ev.died {
		log.Printf("[MUNDO VIVO] NPC #%d morreu de fome, sede ou frio (morte permanente)\n", npc.ID)
		s.BroadcastNPCSay(0, fmt.Sprintf("☠️ %s não resistiu à fome, à sede e ao frio... e jamais voltará.", npc.Name))
		return
	}
	if ev.buyMeal {
		s.serveTavernMeal(npc)
	}
	for _, z := range ev.depleted {
		s.broadcastResourceNodes(z)
	}
	for _, msg := range ev.says {
		s.BroadcastNPCSay(npc.ID, msg)
	}
}

// planNeeds escolhe o afazer biológico mais urgente: sede, fome, frio.
func planNeeds(n *world.NPC, tavern bool, villageNodes []world.ResourceNode, ev *lifeEvents) {
	switch {
	case n.Thirst < world.NeedThreshold:
		n.Life.Plan = world.RouteTo(n.ZoneID, world.ZoneVillage, world.PlaceFountain[0], world.PlaceFountain[1], "drink")
		ev.says = append(ev.says, "Estou com uma sede terrível... vou até a Fonte Central.")
	case n.Hunger < world.NeedThreshold:
		meal := uint16(protocol.ItemCookedNobleMeat)
		if n.ID == world.TavernNPCID && n.ShopStock[meal] > 0 {
			n.ShopStock[meal]--
			n.Hunger = 100
			return
		}
		if tavern && n.ID != world.TavernNPCID && n.Gold >= world.TavernMealPrice {
			n.Life.Plan = world.RouteTo(n.ZoneID, world.ZoneVillage, world.PlaceTavern[0], world.PlaceTavern[1], "eat")
			ev.says = append(ev.says, "Meu estômago ronca... hora de uma refeição na Taverna.")
			return
		}
		for _, food := range []uint16{meal, uint16(protocol.ItemRawWolfMeat), world.MatGlowMushroom} {
			if n.RawMaterials[food] > 0 {
				n.RawMaterials[food]--
				n.Hunger = 100
				return
			}
		}
		// Sem comida e sem ouro: vai coletar algo comestível
		if node, ok := nearestNode(n, villageNodes, world.MatHerbs, world.MatGlowMushroom); ok {
			n.Life.Plan = world.RouteTo(n.ZoneID, node.ZoneID, node.X, node.Z, "forage")
			n.Life.Plan[len(n.Life.Plan)-1].NodeID = node.ID
			ev.says = append(ev.says, "Sem comida e sem moedas... vou catar o que a terra der.")
		}
	case n.Cold > world.ColdThreshold:
		n.Life.Plan = world.RouteTo(n.ZoneID, world.ZoneVillage, world.PlaceFurnace[0], world.PlaceFurnace[1]+3, "warm")
		ev.says = append(ev.says, "Brrr... este frio corta os ossos. Vou me aquecer na Fornalha.")
	}
}

// produceAndOrder fabrica itens com as matérias-primas e abre/cumpre encomendas.
func produceAndOrder(n *world.NPC, now time.Time, villageNodes, forestNodes []world.ResourceNode, ev *lifeEvents) {
	prof, ok := world.NPCProfiles[n.ID]
	if !ok {
		return
	}
	if now.Sub(n.Life.LastCraft) >= world.CraftInterval {
		for _, r := range prof.Recipes {
			if n.ShopStock[uint16(r.Output)] >= world.MaxStockPerItem || !world.CanCraft(n.RawMaterials, r) {
				continue
			}
			world.ConsumeRecipe(n.RawMaterials, r)
			n.ShopStock[uint16(r.Output)]++
			n.Life.LastCraft = now
			ev.says = append(ev.says, fmt.Sprintf("🔨 Terminei mais um(a) %s para a loja!", world.ItemName(r.Output)))
			break
		}
	}
	for mat, want := range prof.Restock {
		have := n.RawMaterials[mat]
		trigger := want / 2
		if n.Personality == world.PersonalityCautious {
			trigger = want
		}
		order, open := n.Life.BuyOrders[mat]
		if have >= want {
			if open {
				delete(n.Life.BuyOrders, mat)
				delete(n.Life.OrderSince, mat)
			}
			continue
		}
		if !open {
			if have >= trigger {
				continue
			}
			price := uint32(float32(prof.BuyPrices[mat])*world.BuyPriceMult(n.Personality) + 0.5)
			n.Life.BuyOrders[mat] = world.BuyOrder{Material: mat, Wanted: want - have, Price: price}
			n.Life.OrderSince[mat] = now
			ev.says = append(ev.says, fmt.Sprintf("📜 Encomenda aberta: compro %d× %s por %d Sollares cada!", want-have, world.ItemName(uint8(mat)), price))
			continue
		}
		order.Wanted = want - have
		n.Life.BuyOrders[mat] = order
		if now.Sub(n.Life.OrderSince[mat]) < world.BuyOrderPatience {
			continue
		}
		// Ninguém vendeu a tempo: o próprio NPC vai coletar
		node, found := nearestNode(n, villageNodes, mat)
		if !found {
			node, found = nearestNode(n, forestNodes, mat)
		}
		n.Life.OrderSince[mat] = now
		if !found {
			continue
		}
		plan := world.RouteTo(n.ZoneID, node.ZoneID, node.X, node.Z, "gather")
		if plan == nil {
			continue
		}
		plan[len(plan)-1].NodeID = node.ID
		plan = append(plan, world.RouteTo(node.ZoneID, n.Life.HomeZone, n.Life.Home[0], n.Life.Home[1], "")...)
		n.Life.Plan = plan
		where := "aqui na vila"
		if node.ZoneID == world.ZoneForest {
			where = "no Bosque Sussurrante"
		}
		ev.says = append(ev.says, fmt.Sprintf("Ninguém me trouxe %s... eu mesmo vou buscar %s.", world.ItemName(uint8(mat)), where))
		return
	}
}

// nearestNode acha o nó disponível mais próximo de algum dos materiais.
func nearestNode(n *world.NPC, nodes []world.ResourceNode, mats ...uint16) (world.ResourceNode, bool) {
	var best world.ResourceNode
	bestD := float32(-1)
	for i := range nodes {
		nd := nodes[i]
		if !nd.Available() {
			continue
		}
		match := false
		for _, m := range mats {
			if nd.MaterialID == m {
				match = true
				break
			}
		}
		if !match {
			continue
		}
		dx, dz := nd.X-n.PosX, nd.Z-n.PosZ
		if nd.ZoneID != n.ZoneID {
			dx, dz = nd.X, nd.Z // em outra zona: distância desde a entrada
		}
		d := dx*dx + dz*dz
		if bestD < 0 || d < bestD {
			best, bestD = nd, d
		}
	}
	return best, bestD >= 0
}

// advanceErrand anda até o passo atual e o executa ao chegar.
func (s *Server) advanceErrand(n *world.NPC, ev *lifeEvents) {
	st := n.Life.Plan[0]
	if n.ZoneID != st.Zone {
		n.Life.Plan = nil // perdeu-se do plano (teleporte da rotina): desiste
		return
	}
	dx, dz := st.X-n.PosX, st.Z-n.PosZ
	if dx*dx+dz*dz > npcArriveDist*npcArriveDist {
		n.TargetX, n.TargetZ, n.MoveSpeed = st.X, st.Z, npcErrandSpeed
		n.State = 1
		n.CurrentActivity = world.ActivityFor(st.Action)
		return
	}
	n.Life.Plan = n.Life.Plan[1:]
	switch st.Action {
	case "drink":
		n.Thirst = 100
		n.RawMaterials[world.MatPureWater]++ // enche o cantil com Água Pura
	case "eat":
		ev.buyMeal = true
	case "warm":
		n.Cold = 0
	case "enter_zone":
		n.ZoneID = st.EnterZone
		n.PosX, n.PosZ = st.EnterX, st.EnterZ
		n.TargetX, n.TargetZ, n.MoveSpeed = st.EnterX, st.EnterZ, 0
	case "gather", "forage":
		node, ok := s.resourceNodes.Get(st.NodeID)
		if !ok || !node.Available() {
			return
		}
		s.resourceNodes.Deplete(node.ID)
		ev.depleted = append(ev.depleted, node.ZoneID)
		if st.Action == "forage" {
			n.Hunger = 70
		} else {
			n.RawMaterials[node.MaterialID] += npcGatherYield
		}
	}
}

// tavernHasMeal informa se a Taverna tem refeição pronta.
func (s *Server) tavernHasMeal() bool {
	s.mu.RLock()
	bart := s.npcs[world.TavernNPCID]
	s.mu.RUnlock()
	if bart == nil {
		return false
	}
	has := false
	bart.WithLife(func(b *world.NPC) {
		has = !b.IsDead && b.ShopStock[uint16(protocol.ItemCookedNobleMeat)] > 0
	})
	return has
}

// serveTavernMeal: o NPC paga a refeição ao Chef com seu próprio ouro (economia fechada).
func (s *Server) serveTavernMeal(npc *world.NPC) {
	s.mu.RLock()
	bart := s.npcs[world.TavernNPCID]
	s.mu.RUnlock()
	meal := uint16(protocol.ItemCookedNobleMeat)
	served := false
	if bart != nil && bart != npc {
		paid := false
		npc.WithLife(func(n *world.NPC) {
			if n.Gold >= world.TavernMealPrice {
				n.Gold -= world.TavernMealPrice
				paid = true
			}
		})
		if paid {
			bart.WithLife(func(b *world.NPC) {
				if !b.IsDead && b.ShopStock[meal] > 0 {
					b.ShopStock[meal]--
					b.Gold += world.TavernMealPrice
					served = true
				}
			})
			if !served {
				npc.WithLife(func(n *world.NPC) { n.Gold += world.TavernMealPrice }) // devolve
			}
		}
	}
	npc.WithLife(func(n *world.NPC) {
		if served {
			n.Hunger = 100
			n.CurrentActivity = world.ActivityEating
		}
	})
}

// --- Loja viva: 0x48 SHOP_REQUEST / 0x49 SHOP_TRADE / 0x4A SHOP_STATE ---

func (s *Server) shopParties(playerID, npcID uint32) (*world.Player, *world.NPC, bool) {
	s.mu.RLock()
	player, okP := s.players[playerID]
	npc, okN := s.npcs[npcID]
	s.mu.RUnlock()
	if !okP || !okN {
		return nil, nil, false
	}
	player.Mu.RLock()
	px, py, pz, zone := player.PosX, player.PosY, player.PosZ, player.ZoneID
	player.Mu.RUnlock()
	if !npc.GetActive() || npc.GetZone() != zone || npc.DistanceTo(px, py, pz) > shopTradeRange {
		return player, npc, false
	}
	return player, npc, true
}

func (s *Server) handleShopRequest(pkt protocol.ShopRequestPacket) {
	player, npc, ok := s.shopParties(pkt.PlayerID, pkt.NPCID)
	if !ok {
		return
	}
	s.sendShopState(player, npc)
}

func (s *Server) sendShopState(p *world.Player, npc *world.NPC) {
	writeTCP(p, protocol.SerializeShopState(shopStateOf(npc)))
}

func shopStateOf(npc *world.NPC) protocol.ShopState {
	var st protocol.ShopState
	npc.WithLife(func(n *world.NPC) {
		st = protocol.ShopState{NPCID: n.ID, Gold: n.Gold, HP: uint16(max(n.HP, 0)), MaxHP: uint16(n.MaxHP),
			Hunger: uint8(n.Hunger), Thirst: uint8(n.Thirst), Cold: uint8(n.Cold), Activity: n.CurrentActivity}
		mult := world.SellPriceMult(n.Personality)
		for item, qty := range n.ShopStock {
			price := world.ShopPrice(n.ID, uint8(item))
			if price == 0 {
				continue
			}
			st.Stock = append(st.Stock, protocol.ShopStockEntry{ItemID: uint8(item), Qty: uint8(min(qty, 255)),
				Price: uint32(float32(price)*mult + 0.5)})
		}
		for _, o := range n.Life.BuyOrders {
			st.Orders = append(st.Orders, protocol.ShopOrderEntry{Material: o.Material, Wanted: uint8(min(o.Wanted, 255)), Price: o.Price})
		}
	})
	return st
}

func (s *Server) handleShopTrade(pkt protocol.ShopTradePacket) {
	player, npc, ok := s.shopParties(pkt.PlayerID, pkt.NPCID)
	if !ok || pkt.Qty == 0 {
		return
	}
	var msg string
	switch pkt.Action {
	case protocol.ShopActionBuy:
		msg = s.shopBuy(player, npc, pkt.ItemID, pkt.Qty)
	case protocol.ShopActionSell:
		msg = s.shopSell(player, npc, pkt.ItemID, pkt.Quality, pkt.Qty)
	default:
		return
	}
	if msg != "" {
		s.sendPlayerNPCSay(player, npc.ID, msg)
	}
	s.sendInventorySync(player)
	s.sendShopState(player, npc)
}

// StockOutMessage: aviso de estoque esgotado.
const StockOutMessage = "📦 Estoque esgotado! Traga matérias-primas para o NPC fabricar novas unidades."

// shopBuy: o jogador compra do estoque real; o ouro vai para o NPC.
func (s *Server) shopBuy(p *world.Player, npc *world.NPC, item, qty uint8) string {
	base := world.ShopPrice(npc.ID, item)
	if base == 0 {
		return "Isso eu não vendo."
	}
	bought := uint8(0)
	var unit uint32
	outOfStock := false
	npc.WithLife(func(n *world.NPC) {
		if n.IsDead {
			return
		}
		unit = uint32(float32(base)*world.SellPriceMult(n.Personality) + 0.5)
		for bought < qty {
			if n.ShopStock[uint16(item)] <= 0 {
				outOfStock = true
				break
			}
			p.Mu.Lock()
			paid := p.Gold >= unit
			if paid {
				p.Gold -= unit
			}
			p.Mu.Unlock()
			if !paid {
				break
			}
			n.ShopStock[uint16(item)]--
			n.Gold += unit
			bought++
		}
	})
	if bought > 0 {
		p.AddItemWithQuality(item, bought, shopUnitQuality)
	}
	switch {
	case bought == 0 && outOfStock:
		return StockOutMessage
	case bought == 0:
		return fmt.Sprintf("Você não tem Sollares suficientes (%d cada).", unit)
	case outOfStock:
		return fmt.Sprintf("Vendi %d× %s por %d Sollares. %s", bought, world.ItemName(item), unit*uint32(bought), StockOutMessage)
	}
	return fmt.Sprintf("Vendi %d× %s por %d Sollares. Bom proveito!", bought, world.ItemName(item), unit*uint32(bought))
}

// shopSell: o jogador vende matérias-primas; o NPC paga com o próprio ouro e volta a produzir.
func (s *Server) shopSell(p *world.Player, npc *world.NPC, item, quality, qty uint8) string {
	prof, ok := world.NPCProfiles[npc.ID]
	if !ok {
		return "Não preciso disso."
	}
	base, wanted := prof.BuyPrices[uint16(item)]
	if !wanted {
		return "Não preciso disso."
	}
	qf := float32(quality) / 75
	if qf < 0.5 {
		qf = 0.5
	} else if qf > 1.5 {
		qf = 1.5
	}
	var unit uint32
	affordable := uint8(0)
	npc.WithLife(func(n *world.NPC) {
		if n.IsDead {
			return
		}
		unit = uint32(float32(base)*world.BuyPriceMult(n.Personality)*qf + 0.5)
		if unit == 0 {
			unit = 1
		}
		affordable = uint8(min(uint32(qty), n.Gold/unit))
	})
	if affordable == 0 {
		return "Não tenho ouro para pagar por isso agora..."
	}
	sold := p.TakeItemUnits(item, quality, affordable)
	if sold == 0 {
		return "Você não tem esse material nessa qualidade."
	}
	total := unit * uint32(sold)
	npc.WithLife(func(n *world.NPC) {
		n.Gold -= min(total, n.Gold)
		n.RawMaterials[uint16(item)] += int(sold)
		if o, open := n.Life.BuyOrders[uint16(item)]; open {
			o.Wanted -= int(sold)
			if o.Wanted <= 0 {
				delete(n.Life.BuyOrders, uint16(item))
				delete(n.Life.OrderSince, uint16(item))
			} else {
				n.Life.BuyOrders[uint16(item)] = o
			}
		}
		n.Life.LastCraft = time.Time{} // volta a produzir já no próximo tick
	})
	p.AddGold(total)
	return fmt.Sprintf("Negócio fechado: %d× %s por %d Sollares. Já vou trabalhar nisso!", sold, world.ItemName(item), total)
}
