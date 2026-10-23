package world

import (
	"testing"
)

func TestOfficialPortalsCountAndIntegrity(t *testing.T) {
	if len(OfficialPortals) != 32+2*len(VillageBuildings) {
		t.Fatalf("esperado %d portais oficiais, obteve %d", 32+2*len(VillageBuildings), len(OfficialPortals))
	}

	for id := uint8(1); id <= 32; id++ {
		portal, ok := GetPortal(id)
		if !ok {
			t.Fatalf("portal ID %d não encontrado no mapa oficial", id)
		}
		if portal.ID != id {
			t.Fatalf("inconsistência no portal ID %d (encontrado %d)", id, portal.ID)
		}

		// Valida se as coordenadas de chegada estão estritamente dentro dos limites da zona de destino
		minB, maxB := GetZoneBounds(portal.TargetZoneID)
		if portal.TargetX < minB || portal.TargetX > maxB {
			t.Fatalf("portal %d: TargetX (%.1f) fora dos limites [%.1f, %.1f] da zona %d",
				id, portal.TargetX, minB, maxB, portal.TargetZoneID)
		}
		if portal.TargetZ < minB || portal.TargetZ > maxB {
			t.Fatalf("portal %d: TargetZ (%.1f) fora dos limites [%.1f, %.1f] da zona %d",
				id, portal.TargetZ, minB, maxB, portal.TargetZoneID)
		}
	}
}

func TestBlackMarketNightLockFlag(t *testing.T) {
	// Portal 13 (Vila -> Mercado Negro) deve ter NightOnly = true
	p13, ok := GetPortal(13)
	if !ok || !p13.NightOnly {
		t.Fatalf("Portal 13 (Vila -> Mercado Negro) deve ter flag NightOnly = true")
	}

	// Portal 14 (Mercado Negro -> Vila) deve ter NightOnly = false (saída sempre permitida)
	p14, ok := GetPortal(14)
	if !ok || p14.NightOnly {
		t.Fatalf("Portal 14 (Mercado Negro -> Vila) deve ter flag NightOnly = false (saída permitida)")
	}
}

func TestResolvePortalTravel(t *testing.T) {
	// Resolução por PortalID
	p, ok := ResolvePortalTravel(ZoneVillage, 0, 1)
	if !ok || p.TargetZoneID != ZoneForest || p.TargetZ != 275.0 {
		t.Fatalf("falha ao resolver portal 1 por PortalID: %+v", p)
	}

	// Resolução por TargetZoneID (Vila -> Ruínas = Zona 2)
	p2, ok := ResolvePortalTravel(ZoneVillage, ZoneRuins, 0)
	if !ok || p2.TargetZoneID != ZoneRuins || p2.TargetZ != -275.0 {
		t.Fatalf("falha ao resolver portal por TargetZoneID: %+v", p2)
	}

	// Resolução de saída (Igreja -> Vila)
	pExit, ok := ResolvePortalTravel(ZoneChurch, ZoneVillage, 10)
	if !ok || pExit.TargetZoneID != ZoneVillage || pExit.TargetX != -45.0 || pExit.TargetZ != -35.0 {
		t.Fatalf("falha ao resolver saída da Igreja: %+v", pExit)
	}
}

func TestZoneBounds600x600(t *testing.T) {
	// Testa limites 600x600m [-295, 295]
	minB, maxB := GetZoneBounds(ZoneVillage)
	if minB != -295.0 || maxB != 295.0 {
		t.Fatalf("limites da Vila devem ser [-295, 295], obtido: [%.1f, %.1f]", minB, maxB)
	}

	// Testa clampeamento na Vila
	cx, cz := ClampToZoneBounds(ZoneVillage, 350.0, -400.0)
	if cx != 295.0 || cz != -295.0 {
		t.Fatalf("ClampToZoneBounds falhou: esperado (295, -295), obtido (%.1f, %.1f)", cx, cz)
	}

	// Testa limites pequenos (Igreja 60x60m [-28, 28])
	cxI, czI := ClampToZoneBounds(ZoneChurch, 50.0, -50.0)
	if cxI != 28.0 || czI != -28.0 {
		t.Fatalf("ClampToZoneBounds Igreja falhou: esperado (28, -28), obtido (%.1f, %.1f)", cxI, czI)
	}

	// Testa limites Mercado Negro (80x80m [-38, 38])
	cxM, czM := ClampToZoneBounds(ZoneBlackMarket, 100.0, -100.0)
	if cxM != 38.0 || czM != -38.0 {
		t.Fatalf("ClampToZoneBounds Mercado Negro falhou: esperado (38, -38), obtido (%.1f, %.1f)", cxM, czM)
	}
}
