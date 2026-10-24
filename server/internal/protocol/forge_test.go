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

func TestRegisterWeaponAndPuzzleStateRoundTrip(t *testing.T) {
	pkt := RegisterCustomWeapon{Name: "Eclipse Cortante", Pieces: []PuzzlePiece{{1, 3, 0, 0, 175}, {15, 3, 3, 0, 102}}}
	raw := SerializeRegisterCustomWeapon(pkt)
	got, err := DeserializeRegisterCustomWeaponBody(raw[3:])
	if err != nil || got.Name != pkt.Name || len(got.Pieces) != 2 || got.Pieces[1] != pkt.Pieces[1] {
		t.Fatalf("0x55: %v %+v", err, got)
	}
	u, list, err := DeserializePuzzleState(SerializePuzzleState(true, []ExclusiveEntry{{Name: pkt.Name, Pieces: pkt.Pieces}}))
	if err != nil || !u || len(list) != 1 || list[0].Pieces[0] != pkt.Pieces[0] {
		t.Fatalf("0x57: %v %v %+v", err, u, list)
	}
}
