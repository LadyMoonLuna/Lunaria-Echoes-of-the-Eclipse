package world

import (
	"strings"
	"testing"

	"lunaria/server/internal/protocol"
)

// Espada simples: Ponta Reta em cima, Guarda Cruzada, Cabo Curto e Bainha ao lado.
func sampleSword() []PuzzlePlacement {
	return []PuzzlePlacement{
		{Module: 1, X: 3, Y: 0, Material: ItemID(MatTemperedSteel)},
		{Module: 10, X: 2, Y: 2, Material: ItemID(MatCopper)}, // células (3,2),(2,3),(3,3),(4,3)
		{Module: 15, X: 3, Y: 4, Material: ItemID(MatStormCedar)},
		{Module: 19, X: 4, Y: 4, Material: ItemID(MatBoarLeather)},
	}
}

func puzzleSmith(id uint32) *Player {
	p := NewPlayer(id, nil, 0, 0, 0)
	p.ClassID = protocol.ClassPagmaDescendant
	for _, pc := range sampleSword() {
		p.AddItemWithQuality(pc.Material, 3, 90)
	}
	return p
}

func resetPatents(t *testing.T) {
	t.Helper()
	SetPatentsFile("")
	patentsMu.Lock()
	RegisteredWeaponPatents = map[string]string{}
	patentsMu.Unlock()
}

func TestPuzzleValidation(t *testing.T) {
	if err := ValidatePuzzle(sampleSword()); err != nil {
		t.Fatal(err)
	}
	noSheath := sampleSword()[:3]
	if err := ValidatePuzzle(noSheath); err == nil || !strings.Contains(err.Error(), "Bainha") {
		t.Fatalf("sem bainha deveria falhar: %v", err)
	}
	loose := append(sampleSword(), PuzzlePlacement{Module: 11, X: 0, Y: 6, Material: ItemID(MatCopper)})
	if err := ValidatePuzzle(loose); err == nil {
		t.Fatal("peça solta deveria falhar")
	}
	out := append(sampleSword()[:3:3], PuzzlePlacement{Module: 16, X: 6, Y: 5, Material: ItemID(MatPineRefuge)})
	if err := ValidatePuzzle(out); err == nil {
		t.Fatal("peça fora da grade deveria falhar")
	}
}

func TestPatentBlocksOtherPlayerButNotCreator(t *testing.T) {
	resetPatents(t)
	a, b := puzzleSmith(1), puzzleSmith(2)
	res, err, denied := a.ForgePuzzle("Eclipse Cortante", sampleSword(), "Jogador #1")
	if err != nil || denied {
		t.Fatalf("criação inédita falhou: %v", err)
	}
	w := a.CustomItems[res.ItemID]
	if w.Info.Slot != protocol.SlotMainHand || w.Name != "Eclipse Cortante" || !strings.Contains(w.Desc, "Obra-Prima") {
		t.Fatalf("obra-prima errada: %+v", w)
	}
	soul := 0
	for id, c := range a.CustomItems {
		if c.Kind == CustomBlueprintKind && c.Soulbound && a.Inventory[id] == 1 {
			soul++
		}
	}
	if soul != 1 || len(a.ExclusiveBlueprints) != 1 {
		t.Fatal("deveria ganhar 1 Blueprint Exclusiva Soulbound")
	}
	if _, err, denied := b.ForgePuzzle("Cópia", sampleSword(), "Jogador #2"); !denied || err == nil || err.Error() != PatentDeniedMessage {
		t.Fatalf("outro jogador deveria ser barrado: %v", err)
	}
	if b.Inventory[ItemID(MatCopper)] != 3 {
		t.Fatal("o bloqueio não pode consumir materiais")
	}
	if _, err, _ := a.ForgePuzzle("Eclipse Cortante II", sampleSword(), "Jogador #1"); err != nil {
		t.Fatalf("o criador pode forjar de novo: %v", err)
	}
	if len(a.ExclusiveBlueprints) != 1 {
		t.Fatal("não deveria duplicar a blueprint exclusiva")
	}
	other := sampleSword()
	other[2].Material = ItemID(MatPineRefuge)
	b.AddItemWithQuality(ItemID(MatPineRefuge), 1, 80)
	if _, err, denied := b.ForgePuzzle("Minha", other, "Jogador #2"); err != nil || denied {
		t.Fatalf("material diferente é outra patente: %v", err)
	}
}

func TestMasterpieceBonusAndClassGate(t *testing.T) {
	resetPatents(t)
	st := ApplyMasterpiece(ForgedStats{ATK: 50, Durability: 100})
	if st.ATK != 60 || st.Durability != 120 {
		t.Fatalf("+20%% errado: %+v", st)
	}
	p := puzzleSmith(3)
	p.ClassID = protocol.ClassBlacksmith
	if _, err, _ := p.ForgePuzzle("X", sampleSword(), "Jogador #3"); err == nil {
		t.Fatal("Forjador básico não deveria usar o Quebra-Cabeça")
	}
	p.SubPath, p.ClassTier = 1, protocol.TierEpic
	if !p.CanUsePuzzleForge() {
		t.Fatal("Artesão Overgeared deveria usar o Quebra-Cabeça")
	}
}
