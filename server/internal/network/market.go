package network

import (
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Loja viva com mercado dinâmico (oferta e procura por região). O preço justo de cada item fica só no
// servidor; o jogador vê apenas o que o NPC cobra (aba Comprar) e o que ele paga (aba Vender).

// StockOutMessage: aviso de estoque esgotado.
const StockOutMessage = "📦 Estoque esgotado! Volte mais tarde (ou traga matéria-prima para o NPC fabricar)."

type marketBuyEntry struct {
	ID    world.ItemID `json:"id"`
	Qty   int          `json:"qty"`
	Price uint32       `json:"price"`
}

type marketSellEntry struct {
	ID    world.ItemID `json:"id"`
	Q     uint8        `json:"q"`
	Have  int          `json:"have"`
	Price uint32       `json:"price"`
	Max   int          `json:"max"`
}

type marketOrderEntry struct {
	ID     uint16 `json:"id"`
	Wanted int    `json:"wanted"`
	Price  uint32 `json:"price"`
}

type marketState struct {
	NPC        uint32             `json:"npc"`
	Name       string             `json:"name"`
	NPCGold    uint32             `json:"npc_gold"`
	PlayerGold uint32             `json:"player_gold"`
	Buy        []marketBuyEntry   `json:"buy"`
	Sell       []marketSellEntry  `json:"sell"`
	Orders     []marketOrderEntry `json:"orders"`
	Msg        string             `json:"msg"`
}

// sendMarketState manda a loja do NPC do ponto de vista deste jogador (0x62).
func (s *Server) sendMarketState(p *world.Player, npc *world.NPC, msg string) {
	if s.clock != nil {
		world.Market.Decay(s.clock.ElapsedHours())
	}
	st := marketState{NPC: npc.ID, Name: npc.Name, Msg: msg, Buy: []marketBuyEntry{}, Sell: []marketSellEntry{}, Orders: []marketOrderEntry{}}
	var personality string
	var market uint8
	npc.WithLife(func(n *world.NPC) {
		personality, market = n.Personality, world.MarketOf(n.ZoneID)
		st.NPCGold = n.Gold
		for item, qty := range n.ShopStock {
			if qty <= 0 || !world.SellsItem(n.ID, world.ItemID(item)) {
				continue
			}
			if price := world.NPCSellUnitPrice(personality, market, world.ItemID(item), qty); price > 0 {
				st.Buy = append(st.Buy, marketBuyEntry{ID: world.ItemID(item), Qty: qty, Price: price})
			}
		}
		for _, o := range n.Life.BuyOrders {
			st.Orders = append(st.Orders, marketOrderEntry{ID: o.Material, Wanted: o.Wanted, Price: o.Price})
		}
	})
	p.Mu.RLock()
	st.PlayerGold = p.Gold
	items := make([]world.ItemID, 0, len(p.Inventory))
	for id, n := range p.Inventory {
		if n > 0 {
			items = append(items, id)
		}
	}
	p.Mu.RUnlock()
	for _, item := range items {
		if p.IsSoulbound(item) {
			continue
		}
		counts := map[uint8]int{}
		for _, q := range p.UnitQualities(item) {
			counts[q]++
		}
		for q, have := range counts {
			price := world.NPCBuyUnitPrice(npc.ID, personality, market, item, q, 0)
			if price == 0 {
				continue
			}
			max := 0
			gold := st.NPCGold
			for max < have {
				unit := world.NPCBuyUnitPrice(npc.ID, personality, market, item, q, max)
				if unit == 0 || gold < unit {
					break
				}
				gold -= unit
				max++
			}
			st.Sell = append(st.Sell, marketSellEntry{ID: item, Q: q, Have: have, Price: price, Max: max})
		}
	}
	sort.Slice(st.Buy, func(i, j int) bool { return st.Buy[i].ID < st.Buy[j].ID })
	sort.Slice(st.Sell, func(i, j int) bool {
		if st.Sell[i].ID != st.Sell[j].ID {
			return st.Sell[i].ID < st.Sell[j].ID
		}
		return st.Sell[i].Q > st.Sell[j].Q
	})
	body, _ := json.Marshal(st)
	writeTCP(p, protocol.SerializeJSONPacket(protocol.PacketTypeMarketState, body))
}

// shopBuy: o jogador compra do estoque real; cada unidade comprada encarece a próxima.
func (s *Server) shopBuy(p *world.Player, npc *world.NPC, item world.ItemID, qty uint8) string {
	if !world.SellsItem(npc.ID, item) {
		return "Isso eu não vendo."
	}
	bought := uint8(0)
	var spent, lastUnit uint32
	outOfStock := false
	market := world.MarketOf(npc.GetZone())
	npc.WithLife(func(n *world.NPC) {
		if n.IsDead {
			return
		}
		for bought < qty {
			stock := n.ShopStock[uint16(item)]
			if stock <= 0 {
				outOfStock = true
				break
			}
			unit := world.NPCSellUnitPrice(n.Personality, market, item, stock)
			lastUnit = unit
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
			spent += unit
			bought++
			world.Market.AddBought(market, item, 1)
		}
	})
	if bought > 0 {
		p.AddItemWithQuality(item, bought, shopUnitQuality)
	}
	switch {
	case bought == 0 && outOfStock:
		return StockOutMessage
	case bought == 0:
		return fmt.Sprintf("Você não tem Sollares suficientes (%d cada).", lastUnit)
	case outOfStock:
		return fmt.Sprintf("Vendi %d× %s por %d Sollares. %s", bought, world.ItemName(item), spent, StockOutMessage)
	}
	return fmt.Sprintf("Vendi %d× %s por %d Sollares. Bom proveito!", bought, world.ItemName(item), spent)
}

// shopSell: o jogador vende ao NPC. Cada unidade vale um pouco menos que a anterior (o mercado enche);
// o NPC para quando o preço fica ridículo ou quando o ouro dele acaba.
func (s *Server) shopSell(p *world.Player, npc *world.NPC, item world.ItemID, quality, qty uint8) string {
	if p.IsSoulbound(item) {
		return "📘 Blueprint Exclusiva é Soulbound: não pode ser vendida."
	}
	if item >= world.CustomItemFirstID {
		return "Não compro peças forjadas únicas."
	}
	if _, ok := world.NPCBuyInterest(npc.ID, item); !ok {
		return "Não preciso disso."
	}
	market := world.MarketOf(npc.GetZone())
	var personality string
	var gold uint32
	npc.WithLife(func(n *world.NPC) { personality, gold = n.Personality, n.Gold })
	// Quantas unidades o NPC aceita e quanto paga no total (preço caindo a cada unidade)
	var units []uint32
	for len(units) < int(qty) {
		unit := world.NPCBuyUnitPrice(npc.ID, personality, market, item, quality, len(units))
		if unit == 0 || gold < unit {
			break
		}
		gold -= unit
		units = append(units, unit)
	}
	if len(units) == 0 {
		if world.NPCBuyUnitPrice(npc.ID, personality, market, item, quality, 0) == 0 {
			return "Já estou abarrotado disso... o mercado está cheio. Tente outra região ou volte daqui a uns dias."
		}
		return "Não tenho ouro para pagar por isso agora..."
	}
	sold := p.TakeItemUnits(item, quality, uint8(len(units)))
	if sold == 0 {
		return "Você não tem esse item nessa qualidade."
	}
	var total uint32
	for _, u := range units[:sold] {
		total += u
	}
	world.Market.AddSold(market, item, float32(sold))
	npc.WithLife(func(n *world.NPC) {
		n.Gold -= min(total, n.Gold)
		if world.SellsItem(n.ID, item) {
			n.ShopStock[uint16(item)] += int(sold) // revende
		} else {
			n.RawMaterials[uint16(world.BaseOf(item))] += int(sold)
		}
		fam := uint16(world.BaseOf(item))
		if o, open := n.Life.BuyOrders[fam]; open {
			o.Wanted -= int(sold)
			if o.Wanted <= 0 {
				delete(n.Life.BuyOrders, fam)
				delete(n.Life.OrderSince, fam)
			} else {
				n.Life.BuyOrders[fam] = o
			}
		}
		n.Life.LastCraft = time.Time{} // volta a produzir já no próximo tick
	})
	p.AddGold(total)
	if int(sold) < int(qty) {
		return fmt.Sprintf("Fico com %d× %s por %d Sollares. Mais que isso eu não consigo vender por aqui.", sold, world.ItemName(item), total)
	}
	return fmt.Sprintf("Negócio fechado: %d× %s por %d Sollares.", sold, world.ItemName(item), total)
}

// initMerchantStock enche o catálogo dos mercadores na abertura do servidor.
func (s *Server) initMerchantStock() {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for id, cat := range world.MerchantCatalog {
		npc := s.npcs[id]
		if npc == nil {
			continue
		}
		npc.WithLife(func(n *world.NPC) {
			for item, want := range cat {
				if n.ShopStock[uint16(item)] < want {
					n.ShopStock[uint16(item)] = want
				}
			}
		})
	}
}

// restockMerchants: a cada 3 h de jogo o mercador compra 1 unidade de cada item que está acabando
// (no atacado, 40% do preço justo, com o próprio ouro).
func (s *Server) restockMerchants() {
	now := s.clock.ElapsedHours()
	if now-s.lastRestockGH < world.MerchantRestockGH {
		return
	}
	s.lastRestockGH = now
	s.mu.RLock()
	defer s.mu.RUnlock()
	for id, cat := range world.MerchantCatalog {
		npc := s.npcs[id]
		if npc == nil {
			continue
		}
		npc.WithLife(func(n *world.NPC) {
			if n.IsDead {
				return
			}
			for item, want := range cat {
				if n.ShopStock[uint16(item)] >= want {
					continue
				}
				cost := world.BasePrice(item) * 2 / 5
				if n.Gold < cost {
					continue
				}
				n.Gold -= cost
				n.ShopStock[uint16(item)]++
			}
		})
	}
}
