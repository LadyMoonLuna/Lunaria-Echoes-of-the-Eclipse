package network

import (
	"strings"
	"testing"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func lifeTestServer() *Server {
	return &Server{players: map[uint32]*world.Player{}, npcs: map[uint32]*world.NPC{},
		clock: world.NewWorldClock(12), resourceNodes: world.NewResourceNodeManager(), groundItems: world.NewGroundItemManager()}
}

func addLifeNPC(s *Server, id uint32, x, z float32) *world.NPC {
	n := world.NewNPC(id, "NPC", x, 0, z, "", s.clock, nil)
	n.SetActive(true)
	s.npcs[id] = n
	s.initNPCLife([]*world.NPC{n})
	return n
}

func TestNPCStartValues(t *testing.T) {
	s := lifeTestServer()
	g := addLifeNPC(s, 100, 30, 25)
	l := addLifeNPC(s, 103, 30, -20)
	if g.MaxHP != 1800 || g.Gold != 1500 || l.MaxHP != 1200 || l.Gold != 1200 {
		t.Fatalf("valores iniciais errados: garrick %d/%d lyra %d/%d", g.MaxHP, g.Gold, l.MaxHP, l.Gold)
	}
	if g.Hunger != 100 || g.Thirst != 100 || g.ShopStock[uint16(world.ItemIronAxe)] != 2 {
		t.Fatal("necessidades ou estoque inicial errados")
	}
}

func TestThirstSendsNPCToFountainAndRefills(t *testing.T) {
	s := lifeTestServer()
	g := addLifeNPC(s, 100, 30, 25)
	g.WithLife(func(n *world.NPC) { n.Thirst = 20 })
	s.updateNPCLife(1)
	if !g.LifeBusy() {
		t.Fatal("com sede o NPC deveria planejar ir à fonte")
	}
	g.Teleport(0, 0, 0)
	s.updateNPCLife(1)
	g.WithLife(func(n *world.NPC) {
		if n.Thirst != 100 || n.RawMaterials[world.MatPureWater] != 1 {
			t.Fatalf("na fonte deveria beber e coletar Água Pura: sede %.0f água %d", n.Thirst, n.RawMaterials[world.MatPureWater])
		}
	})
}

func TestNPCPaysTavernWithOwnGold(t *testing.T) {
	s := lifeTestServer()
	g := addLifeNPC(s, 100, world.PlaceTavern[0], world.PlaceTavern[1])
	b := addLifeNPC(s, world.TavernNPCID, -38, 22)
	g.WithLife(func(n *world.NPC) { n.Hunger = 10 })
	s.updateNPCLife(1) // planeja e já está na taverna -> come
	s.updateNPCLife(1)
	if g.Hunger < 90 || g.Gold != 1500-world.TavernMealPrice || b.Gold != 600+world.TavernMealPrice {
		t.Fatalf("refeição paga errada: fome %.0f ouro G %d ouro B %d", g.Hunger, g.Gold, b.Gold)
	}
}

func TestStarvationKillsPermanently(t *testing.T) {
	s := lifeTestServer()
	g := addLifeNPC(s, 100, 30, 25)
	g.WithLife(func(n *world.NPC) { n.Hunger, n.Thirst, n.HP = 0, 0, 1; n.Life.Enabled = true })
	s.updateNPCLife(1)
	if !g.IsDead || g.GetActive() {
		t.Fatal("NPC deveria morrer permanentemente")
	}
}

func TestProductionConsumesRawMaterials(t *testing.T) {
	s := lifeTestServer()
	g := addLifeNPC(s, 100, 30, 25)
	g.WithLife(func(n *world.NPC) { n.Life.LastCraft = time.Time{} })
	s.updateNPCLife(1)
	if g.ShopStock[uint16(protocol.ItemIronLongsword)] != 2 || g.RawMaterials[world.MatIron] != 3 {
		t.Fatalf("Garrick deveria forjar uma espada: estoque %d ferro %d",
			g.ShopStock[uint16(protocol.ItemIronLongsword)], g.RawMaterials[world.MatIron])
	}
	if _, open := g.Life.BuyOrders[world.MatIron]; !open {
		t.Fatal("com pouco ferro deveria abrir encomenda")
	}
}

func TestShopBuyAndSellMoveGold(t *testing.T) {
	world.Market = world.NewMarketBook()
	s := lifeTestServer()
	l := addLifeNPC(s, 103, 0, 0)
	p := world.NewPlayer(1, nil, 0, 0, 0)
	p.AddGold(1000)
	before := p.Gold
	l.WithLife(func(n *world.NPC) { n.ShopStock[uint16(protocol.ItemHealingPotion)] = 1 })
	price := world.NPCSellUnitPrice(l.Personality, world.ZoneVillage, protocol.ItemHealingPotion, 1)
	s.shopBuy(p, l, protocol.ItemHealingPotion, 1)
	if price == 0 || p.Gold != before-price || l.Gold != 1200+price || p.GetItemCount(protocol.ItemHealingPotion) != 1 {
		t.Fatalf("compra errada: preço %d jogador %d npc %d", price, p.Gold, l.Gold)
	}
	if msg := s.shopBuy(p, l, protocol.ItemHealingPotion, 1); !strings.Contains(msg, "Estoque esgotado") {
		t.Fatalf("sem estoque deveria avisar: %q", msg)
	}
	p.AddItemWithQuality(uint8(world.MatHerbs), 3, 75)
	npcGold := l.Gold
	var expect uint32
	for i := 0; i < 3; i++ {
		expect += world.NPCBuyUnitPrice(103, l.Personality, world.ZoneVillage, uint8(world.MatHerbs), 75, i)
	}
	s.shopSell(p, l, uint8(world.MatHerbs), 75, 3)
	if l.RawMaterials[world.MatHerbs] != 7 || l.Gold != npcGold-expect || expect == 0 {
		t.Fatalf("venda errada: ervas %d ouro %d (esperado -%d)", l.RawMaterials[world.MatHerbs], l.Gold, expect)
	}
}

func TestShopStatePacketLength(t *testing.T) {
	s := lifeTestServer()
	g := addLifeNPC(s, 100, 0, 0)
	b := protocol.SerializeShopState(shopStateOf(g))
	if b[0] != protocol.PacketTypeShopState || int(b[1])|int(b[2])<<8 != len(b) {
		t.Fatal("cabeçalho do SHOP_STATE inválido")
	}
}

func TestOverheatedNPCSeeksFountain(t *testing.T) {
	s := lifeTestServer()
	g := addLifeNPC(s, 100, 10, 10)
	g.WithLife(func(n *world.NPC) { n.Heat = 90 })
	s.updateNPCLife(1)
	g.Teleport(0, 0, 0)
	s.updateNPCLife(1)
	if g.Heat != 0 || g.Thirst != 100 {
		t.Fatalf("na fonte deveria se refrescar: calor %.0f sede %.0f", g.Heat, g.Thirst)
	}
}

func TestJewelerSellsJewelryPricierThanSmith(t *testing.T) {
	s := lifeTestServer()
	j := addLifeNPC(s, world.JewelerID, 46, 8)
	if j.ShopStock[uint16(protocol.ItemBloodRubyRing)] == 0 || j.Gold != 3000 {
		t.Fatal("a Joalheira deveria começar com anéis à venda e 3000 Sollares")
	}
	if world.ShopPrice(world.JewelerID, protocol.ItemRubyLongsword) <= world.ShopPrice(100, protocol.ItemIronLongsword) {
		t.Fatal("a espada cravejada deveria custar mais que a do ferreiro")
	}
	if world.GetItemInfo(protocol.ItemRubyLongsword).BonusATK <= world.GetItemInfo(protocol.ItemIronLongsword).BonusATK {
		t.Fatal("e ser melhor")
	}
}
