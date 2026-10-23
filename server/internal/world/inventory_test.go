package world

import (
	"math"
	"testing"

	"lunaria/server/internal/protocol"
)

func near(a, b float32) bool { return math.Abs(float64(a-b)) < 0.001 }

func TestWeightSpeedCurve(t *testing.T) {
	cases := []struct{ ratio, want float32 }{
		{0.5, 1.0}, {0.70, 1.0}, {0.85, 0.80}, {1.00, 0.65},
		{1.0001, 0.60}, {1.15, 0.425}, {1.299, 0.2512}, {1.30, 0}, {2.0, 0},
	}
	for _, c := range cases {
		if got := WeightSpeedMultiplier(c.ratio*100, 100); !near(got, c.want) && math.Abs(float64(got-c.want)) > 0.01 {
			t.Fatalf("razão %.4f: esperado %.3f, obtido %.3f", c.ratio, c.want, got)
		}
	}
}

func TestMaxWeightFormula(t *testing.T) {
	if got := CalculateMaxWeight(protocol.RaceValerian, 6, 6); got != 40+30+15 {
		t.Fatalf("peso máximo errado: %v", got)
	}
	if got := CalculateMaxWeight(protocol.RaceDwarf, 6, 6); got != 125 {
		t.Fatalf("raça de carga deveria ganhar +40 kg: %v", got)
	}
}

func TestOverloadFreezesMovement(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	if p.Gold != StartingGold || p.EclipseCoins != StartingEclipseCoins {
		t.Fatal("dinheiro inicial incorreto")
	}
	p.UpdateFromMove(1, 5, 0, 5, 0, nil)
	if p.PosX != 5 {
		t.Fatal("sem peso o jogador deveria andar")
	}
	p.AddItem(protocol.ItemColossalSword, 20) // 400 kg
	if !p.IsOverloaded() || p.CanSprint() {
		t.Fatal("deveria estar sobrecarregado")
	}
	p.UpdateFromMove(2, 50, 0, 50, 0, nil)
	if p.PosX != 5 {
		t.Fatal("sobrecarregado deveria ficar imóvel")
	}
	qty := p.TakeItemUnits(protocol.ItemColossalSword, DefaultQualityFor(protocol.ItemColossalSword), 20)
	if qty != 20 || p.IsOverloaded() {
		t.Fatal("largar os itens deveria liberar o movimento")
	}
}

func TestBatchStatAllocation(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.StatPoints = 5
	_, maxBefore, _ := p.WeightStatus()
	if got := p.AllocateStats(protocol.StatIDSTR, 9); got != 5 {
		t.Fatalf("deveria limitar aos 5 pontos disponíveis, aplicou %d", got)
	}
	_, maxAfter, _ := p.WeightStatus()
	if p.StatPoints != 0 || maxAfter != maxBefore+25 {
		t.Fatalf("FOR deveria somar 5 kg por ponto: %v -> %v", maxBefore, maxAfter)
	}
}

func TestWeaponSlotsAndUnequip(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.AddItem(protocol.ItemIronLongsword, 1)
	p.AddItem(protocol.ItemTowerShield, 1)
	p.EquipItem(protocol.ItemIronLongsword)
	p.EquipItem(protocol.ItemTowerShield)
	eq := p.GetEquippedSlots()
	if eq[protocol.SlotMainHand] != protocol.ItemIronLongsword || eq[protocol.SlotOffHand] != protocol.ItemTowerShield {
		t.Fatalf("armas nos slots errados: %v", eq)
	}
	if atk, def, _ := p.EquipBonuses(); atk != 12 || def != 12 {
		t.Fatalf("bônus de ATK/DEF errados: %d/%d", atk, def)
	}
	if !p.UnequipSlot(protocol.SlotOffHand) || p.GetItemCount(protocol.ItemTowerShield) != 1 {
		t.Fatal("desequipar deveria devolver o escudo à mochila")
	}
}

func TestGroundItemPickupRange(t *testing.T) {
	g := NewGroundItemManager()
	d := g.Drop(protocol.ItemIronOre, 3, 82, 10, 10, ZoneVillage)
	if _, ok := g.TryPickup(d.DropID, 20, 20, ZoneVillage); ok {
		t.Fatal("longe demais para pegar")
	}
	if _, ok := g.TryPickup(d.DropID, 12, 12, ZoneForest); ok {
		t.Fatal("outra zona não pode pegar")
	}
	if it, ok := g.TryPickup(d.DropID, 12, 12, ZoneVillage); !ok || it.Quantity != 3 || it.Quality != 82 {
		t.Fatal("a 2.8m deveria pegar")
	}
	if _, ok := g.TryPickup(d.DropID, 12, 12, ZoneVillage); ok {
		t.Fatal("o item já foi pego")
	}
}
