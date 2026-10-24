package world

import (
	"strings"
	"testing"

	"lunaria/server/internal/protocol"
)

func forgePlayer(t *testing.T) *Player {
	t.Helper()
	p := NewPlayer(1, nil, 0, 0, 0)
	p.Inventory = map[uint8]uint8{}
	return p
}

func TestFixedAlloyRecipeAnyOrder(t *testing.T) {
	p := forgePlayer(t)
	for _, id := range []uint16{MatIron, MatCharcoal, MatPureWater} {
		p.AddItemWithQuality(uint8(id), 1, 80)
	}
	res, err := p.SmeltAlloy([]uint8{uint8(MatPureWater), uint8(MatIron), uint8(MatCharcoal)})
	if err != nil || res.ItemID != uint8(MatTemperedSteel) || res.Qty != 2 {
		t.Fatalf("Aço Temperado esperado: %+v %v", res, err)
	}
	if p.Inventory[uint8(MatIron)] != 0 || p.Inventory[uint8(MatTemperedSteel)] != 2 || !p.DiscoveredMaterials[MatTemperedSteel] {
		t.Fatal("ingredientes não foram consumidos ou a liga não entrou na mochila")
	}
}

func TestEveryAlloyRecipeIsCraftable(t *testing.T) {
	for _, r := range AlloyRecipes {
		ings := make([]uint16, len(r.Groups))
		for i, g := range r.Groups {
			ings[i] = g[0]
		}
		if got, ok := MatchAlloyRecipe(ings); !ok || got.Output != r.Output {
			t.Fatalf("receita de %s não casa", MaterialsDB[r.Output].Name)
		}
		if _, ok := MaterialsDB[r.Output]; !ok {
			t.Fatalf("liga %d sem material", r.Output)
		}
	}
}

func TestFreeFusionMakesSyntheticAlloy(t *testing.T) {
	p := forgePlayer(t)
	for _, id := range []uint16{MatCopper, MatFacetedEyes, MatVorpalSac} {
		p.AddItemWithQuality(uint8(id), 2, 70)
	}
	ings := []uint8{uint8(MatCopper), uint8(MatFacetedEyes), uint8(MatVorpalSac)}
	res, err := p.SmeltAlloy(ings)
	if err != nil || res.ItemID < CustomItemFirstID {
		t.Fatalf("fusão livre falhou: %+v %v", res, err)
	}
	c := p.CustomItems[res.ItemID]
	if c == nil || c.Kind != CustomAlloy || !strings.Contains(c.Name, "Cobre") || c.Material.Durability <= 0 {
		t.Fatalf("liga sintética errada: %+v", c)
	}
	again, _ := p.SmeltAlloy(ings)
	if again.ItemID != res.ItemID || p.Inventory[res.ItemID] != 2 {
		t.Fatal("a mesma mistura deveria reaproveitar a mesma liga")
	}
	if _, err := p.SmeltAlloy([]uint8{uint8(MatHerbs), uint8(MatFreshBlood)}); err == nil {
		t.Fatal("mistura sem base mineral deveria falhar")
	}
}

func TestForgeBlueprintByParts(t *testing.T) {
	p := forgePlayer(t)
	picks := []uint8{uint8(MatTemperedSteel), uint8(MatCopper), uint8(MatStormCedar), uint8(MatBoarLeather), 0, 0}
	for _, id := range picks[:4] {
		p.AddItemWithQuality(id, 1, 90)
	}
	p.Mu.Lock()
	delete(p.DiscoveredMaterials, MatTemperedSteel)
	p.Mu.Unlock()
	if _, err := p.ForgeBlueprint(1, picks); err == nil {
		t.Fatal("material desconhecido deveria barrar")
	}
	p.Mu.Lock()
	p.DiscoveredMaterials[MatTemperedSteel] = true
	p.Mu.Unlock()
	if _, err := p.ForgeBlueprint(1, []uint8{uint8(MatBoarLeather), uint8(MatCopper), uint8(MatStormCedar), uint8(MatBoarLeather), 0, 0}); err == nil {
		t.Fatal("couro não serve de lâmina")
	}
	res, err := p.ForgeBlueprint(1, picks)
	if err != nil {
		t.Fatal(err)
	}
	c := p.CustomItems[res.ItemID]
	if c.Name != "Espada Curta de Aço Temperado" || c.Info.Slot != protocol.SlotMainHand || c.Info.BonusATK == 0 {
		t.Fatalf("espada forjada errada: %+v", c.Info)
	}
	if !strings.Contains(c.Desc, "Cabo / Empunhadura de Cedro da Tempestade") || p.Inventory[uint8(MatCopper)] != 0 {
		t.Fatalf("descrição/consumo errados: %s", c.Desc)
	}
	if ok, _ := p.EquipItemQuality(res.ItemID, AnyQuality); !ok || p.EquippedSlots[protocol.SlotMainHand] != res.ItemID {
		t.Fatal("a espada forjada deveria equipar na Mão Principal")
	}
	if _, err := p.ForgeBlueprint(6, picks); err == nil {
		t.Fatal("blueprint avançada não aprendida deveria barrar")
	}
}

func TestForgedToolCountsAsTool(t *testing.T) {
	p := forgePlayer(t)
	picks := []uint8{uint8(MatIron), uint8(MatPineRefuge), uint8(MatBoarLeather)}
	p.Mu.Lock()
	for _, id := range picks {
		p.DiscoveredMaterials[uint16(id)] = true
	}
	p.Mu.Unlock()
	for _, id := range picks {
		p.AddItemWithQuality(id, 1, 80)
	}
	if _, err := p.ForgeBlueprint(2, picks); err != nil {
		t.Fatal(err)
	}
	if p.BestTool(ToolAxe) == 0 {
		t.Fatal("o machado forjado deveria valer como Machado")
	}
}

func TestDivineAdamantSpecials(t *testing.T) {
	bp, _ := GetBlueprint(1)
	mats := []MaterialDef{MaterialsDB[MatDivineAdamant], MaterialsDB[MatCopper], MaterialsDB[MatPineRefuge], MaterialsDB[MatBoarLeather], {}, {}}
	st := ComputeForged(bp, mats, AlloySpecial)
	if len(st.Specials) == 0 || st.Rarity != RarityMythic || st.ATK > 200 {
		t.Fatalf("adamantino divino: %+v", st)
	}
}
