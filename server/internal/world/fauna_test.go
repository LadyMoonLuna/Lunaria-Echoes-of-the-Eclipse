package world

import "testing"

func TestTenSpeciesPerOpenRegion(t *testing.T) {
	per := map[uint8]map[uint8]bool{}
	for _, d := range FaunaCatalog {
		if per[d.Zone] == nil {
			per[d.Zone] = map[uint8]bool{}
		}
		per[d.Zone][d.Type] = true
		if d.Type < FaunaFirstType || d.Type > FaunaLastType {
			t.Fatalf("%s fora da faixa de tipos: %d", d.Name, d.Type)
		}
	}
	for zone := range ZoneGrid {
		if len(per[zone]) < 10 {
			t.Fatalf("região %s tem só %d espécies", GetZoneName(zone), len(per[zone]))
		}
	}
	if len(per[ZoneAncientSewers]) < 10 {
		t.Fatal("os Esgotos também precisam de 10 espécies")
	}
}

func TestAquaticFaunaSpawnsInWater(t *testing.T) {
	mm := NewMobManager()
	fish := 0
	for _, m := range mm.Mobs {
		d, ok := FaunaByType(m.MobType)
		if !ok || d.Habitat == HabitatLand {
			continue
		}
		fish++
		if !InFaunaWater(d, m.ZoneID, m.SpawnX, m.SpawnZ) {
			t.Fatalf("%s nasceu em seco (%.0f, %.0f) na zona %d", d.Name, m.SpawnX, m.SpawnZ, m.ZoneID)
		}
	}
	if fish < 20 {
		t.Fatalf("poucos bichos d'água: %d", fish)
	}
}

func TestFaunaCorpseHasRealAnatomy(t *testing.T) {
	var bear, trout FaunaDef
	for _, d := range FaunaCatalog {
		switch d.Name {
		case "Urso-Pardo do Bosque":
			bear = d
		case "Truta Prateada":
			trout = d
		}
	}
	b := generateCorpseOrgans(bear.Type, 0)
	if len(b) < 6 || BaseOf(b[0].ItemReward) != ItemID(MatThickFur) || b[0].Quantity < 3 {
		t.Fatalf("urso deveria render muita pelagem e órgãos: %+v", b)
	}
	tr := generateCorpseOrgans(trout.Type, 0)
	if BaseOf(tr[0].ItemReward) != ItemID(MatScales) {
		t.Fatalf("truta deveria render escamas: %+v", tr)
	}
	for _, o := range tr {
		if o.OrganType == OrganBlood {
			t.Fatal("peixe não rende frasco de sangue")
		}
	}
	if CorpseMassKg(bear.Type) != 320 || CorpseMassKg(25) != 90 {
		t.Fatal("massa do corpo errada")
	}
}
