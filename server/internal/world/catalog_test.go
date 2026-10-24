package world

import (
	"strings"
	"testing"

	"lunaria/server/internal/protocol"
)

func TestCreatureSpecificDrops(t *testing.T) {
	wolf := generateCorpseOrgans(protocol.MobTypeMistWolf, 0)
	names := map[string]bool{}
	for _, o := range wolf {
		names[o.Name] = true
		if MaterialsDB[uint16(o.ItemReward)].Name != o.Name && BaseOf(o.ItemReward) != o.ItemReward {
			t.Errorf("nome do órgão difere do item: %q vs %q", o.Name, MaterialsDB[uint16(o.ItemReward)].Name)
		}
	}
	for _, want := range []string{"Coração de Lobo da Bruma", "Pata de Lobo da Bruma", "Cabeça de Lobo da Bruma", "Cauda de Lobo da Bruma"} {
		if !names[want] {
			t.Errorf("lobo deveria render %q: %v", want, names)
		}
	}
	alpha := generateCorpseOrgans(protocol.MobTypeAlphaWolf, 0)
	for _, o := range alpha {
		if strings.HasPrefix(o.Name, "Coração de") && o.Name != "Coração de Lobo Alfa" {
			t.Errorf("coração do alfa deveria ser próprio: %q", o.Name)
		}
	}
	spider := generateCorpseOrgans(protocol.MobTypeMistWeaverSpider, 0)
	found := false
	for _, o := range spider {
		if o.Name == "Pata de Aranha Tecelã" && o.Quantity == 8 {
			found = true
		}
	}
	if !found {
		t.Errorf("aranha deveria render 8 Patas de Aranha Tecelã: %+v", spider)
	}
}

func TestDifferentBirdsGiveDifferentFeathers(t *testing.T) {
	seen := map[ItemID]bool{}
	for _, d := range FaunaCatalog {
		if d.Body != FaunaBird || d.Hide != MatFeathers {
			continue
		}
		id, ok := SpecializeDrop(d.Type, ItemID(MatFeathers))
		if !ok || seen[id] || BaseOf(id) != ItemID(MatFeathers) {
			t.Fatalf("cada ave precisa da sua pena: %s -> %d", d.Name, id)
		}
		seen[id] = true
	}
	if len(seen) < 10 {
		t.Fatalf("poucas aves com pena própria: %d", len(seen))
	}
}

func TestWoodCatalog(t *testing.T) {
	count := map[uint8]int{}
	for i := range WoodCatalog {
		w := &WoodCatalog[i]
		count[w.Rarity]++
		for _, p := range []int{WoodTrunk, WoodSap, WoodBranches, WoodLeaves, WoodFruit} {
			_, has := MaterialsDB[uint16(WoodProductID(w.Index, p))]
			if has != w.HasProduct(p) {
				t.Errorf("%s produto %d: cadastrado=%v esperado=%v", w.Name, p, has, w.HasProduct(p))
			}
		}
	}
	want := map[uint8]int{RarityCommon: 20, RarityUncommon: 15, RarityRare: 10, RarityEpic: 5, RarityUnique: 3, RarityTranscendent: 1}
	for r, n := range want {
		if count[r] != n {
			t.Errorf("raridade %d: %d madeiras, esperado %d", r, count[r], n)
		}
	}
	y := YggdrasilWood
	if y.HasProduct(WoodTrunk) {
		t.Fatal("a Yggdrasil não pode ser cortada")
	}
	if MaterialsDB[uint16(WoodProductID(y.Index, WoodFruit))].Rarity != RarityMythic {
		t.Fatal("subprodutos da Yggdrasil são Míticos")
	}
	if _, ok := FruitFood[WoodProductID(y.Index, WoodFruit)]; !ok {
		t.Fatal("o fruto da Yggdrasil deveria ser comestível")
	}
}
