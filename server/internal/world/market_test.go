package world

import (
	"testing"

	"lunaria/server/internal/protocol"
)

func TestEveryTradableItemHasPrice(t *testing.T) {
	for id := range ItemCatalog {
		if BasePrice(id) == 0 && id < CustomItemFirstID {
			t.Errorf("item %d (%s) sem preço justo", id, ItemCatalog[id].Name)
		}
	}
	for id := range MaterialsDB {
		if BasePrice(uint8(id)) == 0 {
			t.Errorf("material %d sem preço", id)
		}
	}
}

func TestNoShopSellsClassOrRaceUnlocks(t *testing.T) {
	for npc := range MerchantCatalog {
		for item := range MerchantCatalog[npc] {
			if NonTradable[item] || bossTrophies[item] {
				t.Errorf("NPC %d vende item proibido %d", npc, item)
			}
		}
	}
	for _, it := range []uint8{protocol.ItemEclipseScytheTome, protocol.ItemBrokenSoulChalice, protocol.ItemBeastProgenitorBlood, protocol.ItemPureLunarBlood} {
		if SellsItem(104, it) {
			t.Errorf("Mercado Negro não pode vender %d", it)
		}
	}
}

func TestMarketSaturationLowersPriceAndRefuses(t *testing.T) {
	Market = NewMarketBook()
	leather := uint8(MatWolfLeather)
	first := NPCBuyUnitPrice(114, PersonalityHonorable, ZoneVillage, leather, 75, 0)
	tenth := NPCBuyUnitPrice(114, PersonalityHonorable, ZoneVillage, leather, 75, 10)
	if first == 0 || tenth >= first {
		t.Fatalf("o preço deveria cair com a oferta: 1ª %d, 11ª %d", first, tenth)
	}
	if NPCBuyUnitPrice(114, PersonalityHonorable, ZoneVillage, leather, 75, 10000) != 0 {
		t.Fatal("com 10000 peles o mercado deveria recusar")
	}
	Market.AddSold(ZoneVillage, leather, 30)
	Market.Decay(0)
	Market.Decay(24 * 6) // seis dias de jogo depois
	if Market.Sold(ZoneVillage, leather) > 1 {
		t.Fatalf("o mercado deveria absorver o excesso com o tempo: %.1f", Market.Sold(ZoneVillage, leather))
	}
}

func TestRegionalScarcityPaysMore(t *testing.T) {
	Market = NewMarketBook()
	// Pinho do Refúgio nasce na Vila: lá vale menos do que num mercado onde ele não existe
	pine := uint8(MatPineRefuge)
	if RegionalFactor(pine, ZoneVillage) >= RegionalFactor(pine, ZoneSaltDesert) {
		t.Fatal("madeira da Vila deveria valer mais no deserto")
	}
}

func TestFriendshipTalkLimits(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	r := p.Talk(100, 0)
	if !r.OK || r.Gained != FriendTalkPoints {
		t.Fatalf("primeira conversa deveria render %d: %+v", FriendTalkPoints, r)
	}
	if r2 := p.Talk(100, 1); r2.OK {
		t.Fatal("conversar de novo antes de 8 h não pode")
	}
	for i := 1; i < 40; i++ {
		p.Talk(100, float64(i)*FriendTalkCDHours)
	}
	if got := p.GetFriendship(100); got != FriendTalkCap {
		t.Fatalf("conversa sozinha só leva a 2 corações (%d), ficou %d", FriendTalkCap, got)
	}
}

func TestGiftTastes(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	if r := p.Gift(107, uint8(MatMoonflower), 75, 0); r.OK {
		t.Fatal("presente antes de 2 corações não pode")
	}
	p.AddFriendship(107, 60)
	r := p.Gift(107, protocol.ItemDarkPoisonGland, 75, 0)
	if !r.OK || r.Delta >= 0 {
		t.Fatalf("Seraphina detesta veneno: %+v", r)
	}
	if r := p.Gift(107, uint8(MatMoonflower), 75, 1); r.OK {
		t.Fatal("só um presente por dia")
	}
	if r := p.Gift(107, uint8(MatMoonflower), 75, 25); !r.OK || r.Delta <= 0 {
		t.Fatalf("Seraphina ama Flor-da-Lua: %+v", r)
	}
}

func TestHuntQuestProgress(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.SetQuest(105, &ActiveQuest{DefID: 30}, 0, false)
	for i := 0; i < 4; i++ {
		p.CreditKill(protocol.MobTypeMistWolf)
	}
	_, aq, ok := p.SocialSnapshot(105)
	if !ok || aq.Step != 1 {
		t.Fatalf("4 lobos deveriam concluir o passo de caça: %+v", aq)
	}
}
