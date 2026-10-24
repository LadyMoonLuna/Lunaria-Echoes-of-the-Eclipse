package world

import (
	"strings"
	"testing"
)

func allScores(v float32) CraftScores {
	return CraftScores{Melt: v, FusionPt: v, Mold: v, PrepMetal: v, ShapePart: v, Temper: v, Assembly: v, FromClient: true}
}

func TestCraftQualityFormulaAndClamp(t *testing.T) {
	// Atributos preenchem parte do que falta até 1,20 (retorno decrescente)
	q := craftQualityFor(allScores(1.0), 10, 5, 5)
	if want := float32(1.0 + 0.07*0.2/1.2); q < want-0.001 || q > want+0.001 {
		t.Fatalf("nota %.4f, esperado %.4f", q, want)
	}
	if q := craftQualityFor(allScores(1.2), 255, 255, 255); q != MaxMiniGameScore {
		t.Fatalf("a nota nunca passa de 1,20: %.3f", q)
	}
	weak, strong := craftQualityFor(allScores(0.5), 0, 0, 0), craftQualityFor(allScores(0.5), 80, 60, 60)
	if strong <= weak || strong > MaxMiniGameScore {
		t.Fatalf("experiência deveria compensar erros sem passar do teto: %.3f vs %.3f", weak, strong)
	}
	if c := allScores(9).Clamp(); c.Melt != MaxMiniGameScore {
		t.Fatal("notas acima de 1.20 precisam ser cortadas")
	}
	if s := ScoresFromBytes([]byte{240, 190, 0, 100, 255, 200, 160}); s.Melt != 1.2 || s.FusionPt != 0.95 || s.ShapePart != 1.2 || s.Assembly != 0.8 {
		t.Fatalf("decodificação errada: %+v", s)
	}
}

func TestCraftTiersApplyToStats(t *testing.T) {
	base := ForgedStats{Name: "Espada", ATK: 100, DEF: 10, HP: 30, Durability: 200, Weight: 4.0, Rarity: RarityRare}
	cases := []struct {
		q        float32
		atk, dur int
		rarity   uint8
		prefix   bool
		lighter  bool
	}{
		{0.40, 60, 100, RarityUncommon, false, false},
		{0.60, 85, 200, RarityRare, false, false},
		{0.95, 135, 270, RarityEpic, false, true},
		{1.12, 165, 330, RarityEpic, true, false},
		{1.19, 165, 330, RarityUnique, true, false},
	}
	for _, c := range cases {
		st := ApplyCraftQuality(base, c.q)
		if st.ATK != c.atk || st.Durability != c.dur || st.Rarity != c.rarity || strings.HasPrefix(st.Name, DivinePrefix) != c.prefix {
			t.Fatalf("nota %.2f (%s): %+v", c.q, CraftTier(c.q), st)
		}
		if c.lighter && st.Weight != 3.4 {
			t.Fatalf("Obra-Prima deveria pesar 15%% menos: %.1f", st.Weight)
		}
	}
	if st := ApplyCraftQuality(base, 0.85); st.ATK <= 100 || st.ATK >= 115 {
		t.Fatalf("Firme deveria ficar entre 1,00 e 1,15: %d", st.ATK)
	}
	if st := ApplyCraftQuality(ForgedStats{Rarity: RarityCommon}, 0.1); st.Rarity != RarityCommon {
		t.Fatal("raridade mínima é Comum")
	}
	if st := ApplyCraftQuality(ForgedStats{Rarity: RarityMythic}, 1.2); st.Rarity != RarityMythic {
		t.Fatal("raridade máxima é Mítico")
	}
}

func TestConductivityDiffAndDifficulty(t *testing.T) {
	cu, herb := MaterialsDB[MatCopper], MaterialsDB[MatHerbs]
	want := float32((75.0 + 90.0 + 5.0) / 3.0) // |85-10| |95-5| |30-35|
	if d := ConductivityDiff([]MaterialDef{cu, herb}); d < want-0.01 || d > want+0.01 {
		t.Fatalf("diferença %.2f, esperado %.2f", d, want)
	}
	easy := FusionDifficulty([]MaterialDef{cu, MaterialsDB[MatTin]})
	hard := FusionDifficulty([]MaterialDef{MaterialsDB[MatAdamantine], MaterialsDB[MatBlackSunShard]})
	if easy >= hard {
		t.Fatalf("raridade e condutividades diferentes deveriam dificultar: %.2f vs %.2f", easy, hard)
	}
}

func TestHarmonyBonusOnAlloys(t *testing.T) {
	p := forgePlayer(t)
	for _, id := range []uint16{MatIron, MatCharcoal, MatPureWater} {
		p.AddItemWithQuality(ItemID(id), 2, 80)
	}
	ings := []ItemID{ItemID(MatIron), ItemID(MatCharcoal), ItemID(MatPureWater)}
	plain, err := p.SmeltAlloyScored(ings, allScores(0.80))
	if err != nil || plain.ItemID != ItemID(MatTemperedSteel) {
		t.Fatalf("sem harmonia deveria sair o Aço Temperado comum: %+v %v", plain, err)
	}
	h, err := p.SmeltAlloyScored(ings, allScores(1.0))
	if err != nil || h.ItemID < CustomItemFirstID {
		t.Fatalf("harmonia deveria criar a versão Harmônica: %+v %v", h, err)
	}
	m := p.CustomItems[h.ItemID].Material
	base := MaterialsDB[MatTemperedSteel]
	if m.Durability != 168 || m.CondThermal != 88 || !strings.Contains(m.Name, "Harmônico") {
		t.Fatalf("bônus de harmonia errado: %+v", m)
	}
	if base.Durability != 140 {
		t.Fatal("o catálogo não pode ser alterado")
	}
}

func TestSelectiveReforge(t *testing.T) {
	p := forgePlayer(t)
	picks := []ItemID{ItemID(MatIron), ItemID(MatCopper), ItemID(MatPineRefuge), ItemID(MatBoarLeather), 0, 0}
	for _, id := range picks[:4] {
		p.AddItemWithQuality(id, 1, 80)
	}
	p.Stamina = 100
	if wr, err := p.WorkPart(1, 0, ItemID(MatIron), allScores(0.3)); err != nil || wr.Reforged {
		t.Fatalf("primeiro trabalho da lâmina: %v", err)
	}
	wr, err := p.WorkPart(1, 0, ItemID(MatIron), allScores(1.0))
	if err != nil || !wr.Reforged || p.Stamina != 85 {
		t.Fatalf("reforja da lâmina de ferro deveria custar 15 de Stamina: %v (stamina %.0f)", err, p.Stamina)
	}
	if wr.Scores.Melt < 0.969 || wr.Scores.Melt > 0.971 {
		t.Fatalf("1ª Reforja deveria oxidar 3%%: %.3f", wr.Scores.Melt)
	}
	p.WorkPart(1, 0, ItemID(MatIron), allScores(1.0))
	p.WorkPart(1, 0, ItemID(MatIron), allScores(1.0))
	if wr, err := p.WorkPart(1, 0, ItemID(MatIron), allScores(1.0)); err == nil || wr.Reforges != MaxReforgesPerPart {
		t.Fatalf("a 4ª Reforja deveria falhar por fadiga do metal: %v", err)
	}
	p.Stamina = 5
	if _, err := p.WorkPart(1, 1, ItemID(MatCopper), allScores(0.6)); err != nil {
		t.Fatal(err)
	}
	if wr, err := p.WorkPart(1, 1, ItemID(MatCopper), allScores(1.2)); err == nil || wr.Scores.Melt != 0.6 {
		t.Fatalf("sem Stamina a Reforja é recusada e a nota antiga fica: %v %+v", err, wr.Scores)
	}
	p.Stamina = 100
	if p.Inventory[ItemID(MatIron)] != 1 {
		t.Fatal("a reforja não pode destruir o metal")
	}
	p.WorkPart(1, 2, ItemID(MatPineRefuge), allScores(0.5))
	if wr, err := p.WorkPart(1, 2, ItemID(MatPineRefuge), allScores(1.0)); err == nil || err.Error() != ReforgeDeniedMsg || wr.Scores.Melt != 0.5 {
		t.Fatalf("madeira não pode ser reforjada: %v", err)
	}
	res, err := p.ForgeBlueprintScored(1, picks, allScores(1.0))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(p.CustomItems[res.ItemID].Desc, "nota") {
		t.Fatal("a descrição deveria trazer a nota da forja")
	}
	if _, ok := forgeSessions.byPlayer[p.ID]; ok {
		t.Fatal("a sessão deveria terminar depois da montagem")
	}
}

func TestLegacyForgeUnchanged(t *testing.T) {
	bp, _ := GetBlueprint(1)
	mats := []MaterialDef{MaterialsDB[MatIron], MaterialsDB[MatCopper], MaterialsDB[MatPineRefuge], MaterialsDB[MatBoarLeather], {}, {}}
	p := forgePlayer(t)
	picks := []ItemID{ItemID(MatIron), ItemID(MatCopper), ItemID(MatPineRefuge), ItemID(MatBoarLeather), 0, 0}
	for _, id := range picks[:4] {
		p.AddItemWithQuality(id, 1, 80)
	}
	res, err := p.ForgeBlueprint(1, picks)
	if err != nil || p.CustomItems[res.ItemID].Stats.ATK != ComputeForged(bp, mats, AlloySpecial).ATK {
		t.Fatalf("forja sem mini-games não pode mudar: %v", err)
	}
}

func TestPuzzlePartReforgeAndSession(t *testing.T) {
	resetPatents(t)
	p := puzzleSmith(9)
	p.Stamina = 100
	pl := sampleSword()
	for i, pc := range pl {
		if _, err := p.WorkPuzzlePart(i, pc.Module, pc.Material, allScores(0.4)); err != nil {
			t.Fatal(err)
		}
	}
	if wr, err := p.WorkPuzzlePart(0, pl[0].Module, pl[0].Material, allScores(1.2)); err != nil || !wr.Reforged || p.Stamina != 85 {
		t.Fatalf("Reforja da lâmina do Quebra-Cabeça deveria custar Stamina: %v", err)
	}
	if _, err := p.WorkPuzzlePart(2, pl[2].Module, pl[2].Material, allScores(1.2)); err == nil {
		t.Fatal("cabo de madeira não pode ser reforjado")
	}
	final := p.PuzzleSessionScores(pl, allScores(0.85))
	if final.Melt <= 0.4 || final.Melt >= 0.85 {
		t.Fatalf("a nota final deveria vir das peças trabalhadas: %.3f", final.Melt)
	}
	if _, err, _ := p.ForgePuzzleScored("Lâmina Reforjada", pl, "Jogador #9", allScores(0.85)); err != nil {
		t.Fatal(err)
	}
	if _, ok := forgeSessions.byPlayer[p.ID]; ok {
		t.Fatal("a sessão do Quebra-Cabeça deveria terminar depois da forja")
	}
}
