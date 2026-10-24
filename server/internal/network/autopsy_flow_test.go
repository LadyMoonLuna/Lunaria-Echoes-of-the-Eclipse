package network

import (
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Várias autópsias seguidas: com as partes próprias de cada criatura a mochila tem dezenas de tipos de
// item, e todo órgão extraído precisa chegar a ela (antes um limite de 24 tipos fazia o órgão sumir).
func TestAutopsyOfManyCreaturesKeepsEveryPart(t *testing.T) {
	s := NewServer()
	p := world.NewPlayer(1, nil, 10, 0, 10)
	s.players[1] = p
	p.AddItem(protocol.ItemAutopsyDagger, 1)
	p.AddItem(protocol.ItemEmptyFlask, 10)
	want := 0
	for _, mt := range []uint8{protocol.MobTypeMistWolf, 102, 109, 110} {
		mob := world.NewMobWithZone(999, "x", mt, 0, 10, 0, 10, 100, 1)
		c := s.corpseManager.CreateCorpseFromMob(mob, 1, 0)
		for _, o := range c.Organs {
			s.handleSubmitAutopsyResult(protocol.SubmitAutopsyResultPacket{PlayerID: 1, CorpseID: c.CorpseID, OrganIndex: o.Index, ResultTier: 1, Quality: 90})
			want++
		}
	}
	got := 0
	for _, sl := range p.GetInventorySlots() {
		if sl.ItemID >= world.CreaturePartFirstID && sl.ItemID < world.WoodFirstID {
			got++
		}
	}
	if got < 30 {
		t.Fatalf("partes de criatura na mochila: %d (órgãos extraídos: %d)", got, want)
	}
}
