package protocol

import "testing"

func TestForgeStateRoundTrip(t *testing.T) {
	in := []ForgeCustomEntry{{ID: 200, Kind: 2, Slot: SlotMainHand, Rarity: 4, Weight: 3.5, ATK: 40, Durability: 150,
		Thermal: 70, Electric: 50, Magic: 20, Name: "Espada Curta de Aço Temperado", Desc: "Lâmina de Aço\nDurabilidade 150", Resist: "Corte +25%"}}
	bps, out, err := DeserializeForgeState(SerializeForgeState([]uint8{1, 2, 6}, in))
	if err != nil || len(bps) != 3 || len(out) != 1 || out[0] != in[0] {
		t.Fatalf("ida e volta falhou: %v %v %+v", err, bps, out)
	}
}
