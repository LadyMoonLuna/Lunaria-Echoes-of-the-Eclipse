package world

import "fmt"

// Madeiras de Lunaria (catalog_woods_data.go, gerado por tools/gen_woods.py). Cada árvore rende Tronco
// (com o Machado), Galhos (sobras do corte), Folhas e Frutos (com a Tesoura de Herborista) e Seiva (com um
// Frasco Vazio). A Yggdrasil é Transcendente: não pode ser cortada, e seus subprodutos são Míticos.

const (
	WoodFirstID ItemID = 5000
	woodStride         = 5

	WoodTrunk    = 0
	WoodSap      = 1
	WoodBranches = 2
	WoodLeaves   = 3
	WoodFruit    = 4

	NodeYggdrasil uint8 = 9 // a Árvore do Mundo (gigante, não pode ser cortada)
)

// WoodDef: uma espécie de árvore.
type WoodDef struct {
	Index                    int
	Name                     string
	Rarity                   uint8
	Zones                    []uint8
	Fruit                    string
	LeafColor, BarkColor     string
	Thermal, Electric, Magic int
	SpawnWeight              int
}

// FruitInfo: o quanto um fruto alimenta e cura.
type FruitInfo struct {
	Hunger float32
	HP     uint16
}

var (
	// FruitFood: frutos comestíveis.
	FruitFood = map[ItemID]FruitInfo{}
	// woodOfItem: subproduto -> espécie.
	woodOfItem = map[ItemID]*WoodDef{}
	// YggdrasilWood: a Árvore do Mundo.
	YggdrasilWood *WoodDef
)

// WoodProductID: ID estável do produto da espécie.
func WoodProductID(index, product int) ItemID {
	return WoodFirstID + ItemID(index*woodStride+product)
}

// WoodOf: espécie do item (nil se não for subproduto de árvore).
func WoodOf(id ItemID) *WoodDef {
	return woodOfItem[id]
}

// HasProduct: a espécie tem esse subproduto?
func (w *WoodDef) HasProduct(product int) bool {
	if product == WoodFruit {
		return w.Fruit != ""
	}
	if product == WoodTrunk {
		return w.Rarity != RarityTranscendent // a Yggdrasil não se corta
	}
	return true
}

// YggdrasilPos: a Árvore do Mundo, no coração do Bosque Sussurrante.
var YggdrasilPos = [2]float32{-150, 140}

func registerWood(w *WoodDef) {
	byproductRarity := w.Rarity
	if w.Rarity == RarityTranscendent {
		byproductRarity = RarityMythic
	}
	trunkDur := 60 + int(w.Rarity)*45
	mk := func(product int, name, cat string, rarity uint8, dur int, weight float32, resist string) {
		if !w.HasProduct(product) {
			return
		}
		id := WoodProductID(w.Index, product)
		MaterialsDB[uint16(id)] = MaterialDef{ID: uint16(id), Name: name, Category: cat, Rarity: rarity, Durability: dur,
			Weight: weight, Resistances: resist, CondThermal: w.Thermal, CondElectric: w.Electric, CondMagic: w.Magic}
		woodOfItem[id] = w
	}
	mk(WoodTrunk, "Tronco de "+w.Name, MatWood, w.Rarity, trunkDur, 2.5+float32(w.Rarity)*0.3, "—")
	mk(WoodSap, "Seiva de "+w.Name, MatPlantLiquid, byproductRarity, 0, 0.4, "—")
	mk(WoodBranches, "Galhos de "+w.Name, MatWood, byproductRarity, trunkDur/3, 0.8, "—")
	mk(WoodLeaves, "Folhas de "+w.Name, MatPlantLiquid, byproductRarity, 0, 0.1, "—")
	fruitName := w.Fruit
	if w.Rarity == RarityTranscendent {
		fruitName = "Fruto de Yggdrasil"
	}
	mk(WoodFruit, fruitName, MatPlantLiquid, byproductRarity, 0, 0.3, "—")
	if w.Fruit != "" {
		r := float32(byproductRarity)
		FruitFood[WoodProductID(w.Index, WoodFruit)] = FruitInfo{Hunger: 8 + r*3, HP: uint16(10 + r*12)}
	}
	if w.Rarity == RarityTranscendent {
		YggdrasilWood = w
		return
	}
	for _, z := range w.Zones {
		zoneResourceTables[z] = append(zoneResourceTables[z], spawnEntry{uint16(WoodProductID(w.Index, WoodTrunk)), w.SpawnWeight})
	}
}

func init() {
	for i := range WoodCatalog {
		registerWood(&WoodCatalog[i])
	}
	if YggdrasilWood == nil {
		panic(fmt.Sprintf("catálogo de madeiras sem a Yggdrasil (%d espécies)", len(WoodCatalog)))
	}
}
