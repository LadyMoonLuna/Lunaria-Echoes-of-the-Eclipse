package world

import "fmt"

// PortalDef define a estrutura e regras autoritativas de travessia de um portal.
type PortalDef struct {
	ID           uint8
	Name         string
	FromZoneID   uint8
	TargetZoneID uint8
	TargetX      float32
	TargetY      float32
	TargetZ      float32
	NightOnly    bool // Restrito para a noite (18h às 06h)
}

// OfficialPortals contém os 32 portais de mão dupla entre zonas; as portas dos prédios da Vila
// (33 a 52) são acrescentadas em interiors.go.
var OfficialPortals = map[uint8]PortalDef{
	// 1 & 2: Vila do Refúgio <-> Bosque Sussurrante / Floresta
	1: {
		ID:           1,
		Name:         "Portal Sul da Vila -> Floresta",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneForest,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},
	2: {
		ID:           2,
		Name:         "Entrada Norte da Floresta -> Vila",
		FromZoneID:   ZoneForest,
		TargetZoneID: ZoneVillage,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},

	// 3 & 4: Vila do Refúgio <-> Ruínas da Vigília & Norte Gelado
	3: {
		ID:           3,
		Name:         "Portal Norte da Vila -> Planalto dos Ventos",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneWindPlateau,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},
	4: {
		ID:           4,
		Name:         "Entrada Sul do Planalto -> Vila",
		FromZoneID:   ZoneWindPlateau,
		TargetZoneID: ZoneVillage,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},

	// 5 & 6: Vila do Refúgio <-> Santuário do Eclipse
	5: {
		ID:           5,
		Name:         "Portal Oeste da Vila -> Santuário",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneSanctuary,
		TargetX:      275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},
	6: {
		ID:           6,
		Name:         "Entrada Leste do Santuário -> Vila",
		FromZoneID:   ZoneSanctuary,
		TargetZoneID: ZoneVillage,
		TargetX:      -275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},

	// 7 & 8: Vila do Refúgio <-> Fronteira das Cinzas (Zona Futura)
	7: {
		ID:           7,
		Name:         "Portal Leste da Vila -> Colinas de Basalto",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneBasaltHills,
		TargetX:      -275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},
	8: {
		ID:           8,
		Name:         "Entrada Oeste das Colinas -> Vila",
		FromZoneID:   ZoneBasaltHills,
		TargetZoneID: ZoneVillage,
		TargetX:      275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},

	// 9 & 10: Vila do Refúgio <-> Interior da Igreja da Luz (60x60m)
	9: {
		ID:           9,
		Name:         "Porta da Igreja -> Interior da Igreja",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneChurch,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -22.0,
	},
	10: {
		ID:           10,
		Name:         "Saída da Igreja -> Vila",
		FromZoneID:   ZoneChurch,
		TargetZoneID: ZoneVillage,
		TargetX:      -45.0,
		TargetY:      1.5,
		TargetZ:      -35.0,
	},

	// 11 & 12: Vila do Refúgio <-> Interior da Torre do Arcanista (60x60m)
	11: {
		ID:           11,
		Name:         "Porta da Torre do Arcanista -> Interior da Torre",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneMageTower,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -22.0,
	},
	12: {
		ID:           12,
		Name:         "Saída da Torre do Arcanista -> Vila",
		FromZoneID:   ZoneMageTower,
		TargetZoneID: ZoneVillage,
		TargetX:      45.0,
		TargetY:      1.5,
		TargetZ:      -35.0,
	},

	// 13 & 14: Vila do Refúgio <-> Mercado Negro do Beco (80x80m | Trava Noturna)
	13: {
		ID:           13,
		Name:         "Entrada do Beco Sombrio -> Mercado Negro",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneBlackMarket,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -30.0,
		NightOnly:    true,
	},
	14: {
		ID:           14,
		Name:         "Saída do Mercado Negro -> Vila",
		FromZoneID:   ZoneBlackMarket,
		TargetZoneID: ZoneVillage,
		TargetX:      -45.0,
		TargetY:      1.5,
		TargetZ:      35.0,
		NightOnly:    false,
	},

	// 15 & 16: Vila do Refúgio <-> Esgotos Antigos (600x600m)
	15: {
		ID:           15,
		Name:         "Bueiro dos Esgotos -> Esgotos Antigos",
		FromZoneID:   ZoneVillage,
		TargetZoneID: ZoneAncientSewers,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},
	16: {
		ID:           16,
		Name:         "Saída dos Esgotos Antigos -> Vila",
		FromZoneID:   ZoneAncientSewers,
		TargetZoneID: ZoneVillage,
		TargetX:      -55.0,
		TargetY:      1.5,
		TargetZ:      -50.0,
	},

	// 17 a 32: zonas de transição (o mundo muda aos poucos entre os biomas)
	17: {
		ID:           17,
		Name:         "Portal Norte do Planalto -> Ruínas",
		FromZoneID:   ZoneWindPlateau,
		TargetZoneID: ZoneRuins,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},
	18: {
		ID:           18,
		Name:         "Entrada Sul das Ruínas -> Planalto",
		FromZoneID:   ZoneRuins,
		TargetZoneID: ZoneWindPlateau,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},
	19: {
		ID:           19,
		Name:         "Portal Norte das Ruínas -> Picos Gelados",
		FromZoneID:   ZoneRuins,
		TargetZoneID: ZoneFrozenPeaks,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},
	20: {
		ID:           20,
		Name:         "Entrada Sul dos Picos -> Ruínas",
		FromZoneID:   ZoneFrozenPeaks,
		TargetZoneID: ZoneRuins,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},
	21: {
		ID:           21,
		Name:         "Portal Leste das Colinas -> Fronteira das Cinzas",
		FromZoneID:   ZoneBasaltHills,
		TargetZoneID: ZoneAshFrontier,
		TargetX:      -275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},
	22: {
		ID:           22,
		Name:         "Entrada Oeste das Cinzas -> Colinas",
		FromZoneID:   ZoneAshFrontier,
		TargetZoneID: ZoneBasaltHills,
		TargetX:      275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},
	23: {
		ID:           23,
		Name:         "Portal Sul do Bosque -> Bosque Ralo",
		FromZoneID:   ZoneForest,
		TargetZoneID: ZoneSparseWoods,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},
	24: {
		ID:           24,
		Name:         "Entrada Norte do Bosque Ralo -> Bosque",
		FromZoneID:   ZoneSparseWoods,
		TargetZoneID: ZoneForest,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},
	25: {
		ID:           25,
		Name:         "Portal Sul do Bosque Ralo -> Campos Rasteiros",
		FromZoneID:   ZoneSparseWoods,
		TargetZoneID: ZoneGrasslands,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},
	26: {
		ID:           26,
		Name:         "Entrada Norte dos Campos -> Bosque Ralo",
		FromZoneID:   ZoneGrasslands,
		TargetZoneID: ZoneSparseWoods,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},
	27: {
		ID:           27,
		Name:         "Portal Sul dos Campos -> Savana Dourada",
		FromZoneID:   ZoneGrasslands,
		TargetZoneID: ZoneSavanna,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},
	28: {
		ID:           28,
		Name:         "Entrada Norte da Savana -> Campos",
		FromZoneID:   ZoneSavanna,
		TargetZoneID: ZoneGrasslands,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},
	29: {
		ID:           29,
		Name:         "Portal Sul da Savana -> Deserto de Sal",
		FromZoneID:   ZoneSavanna,
		TargetZoneID: ZoneSaltDesert,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      275.0,
	},
	30: {
		ID:           30,
		Name:         "Entrada Norte do Deserto -> Savana",
		FromZoneID:   ZoneSaltDesert,
		TargetZoneID: ZoneSavanna,
		TargetX:      0.0,
		TargetY:      1.5,
		TargetZ:      -275.0,
	},
	31: {
		ID:           31,
		Name:         "Portal Oeste do Santuário -> Pântano das Brumas",
		FromZoneID:   ZoneSanctuary,
		TargetZoneID: ZoneMistMarsh,
		TargetX:      275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},
	32: {
		ID:           32,
		Name:         "Entrada Leste do Pântano -> Santuário",
		FromZoneID:   ZoneMistMarsh,
		TargetZoneID: ZoneSanctuary,
		TargetX:      -275.0,
		TargetY:      1.5,
		TargetZ:      0.0,
	},
}

// GetPortal recupera a definição de um portal pelo seu PortalID.
func GetPortal(portalID uint8) (PortalDef, bool) {
	p, ok := OfficialPortals[portalID]
	return p, ok
}

// FindPortal procura uma transição de portal entre fromZone e toZone.
func FindPortal(fromZone, toZone uint8) (PortalDef, bool) {
	for _, p := range OfficialPortals {
		if p.FromZoneID == fromZone && p.TargetZoneID == toZone {
			return p, true
		}
	}
	return PortalDef{}, false
}

// GetDefaultSafeCoordinates retorna o ponto seguro de entrada para uma determinada zona.
func GetDefaultSafeCoordinates(zoneID uint8) (float32, float32, float32) {
	switch zoneID {
	case ZoneForest:
		return 0.0, 1.5, 275.0
	case ZoneRuins:
		return 0.0, 1.5, -275.0
	case ZoneSanctuary:
		return 275.0, 1.5, 0.0
	case ZoneAshFrontier:
		return -275.0, 1.5, 0.0
	case ZoneChurch:
		return 0.0, 1.5, -22.0
	case ZoneMageTower:
		return 0.0, 1.5, -22.0
	case ZoneBlackMarket:
		return 0.0, 1.5, -30.0
	case ZoneAncientSewers:
		return 0.0, 1.5, 0.0
	case ZoneSparseWoods, ZoneGrasslands, ZoneSavanna, ZoneSaltDesert:
		return 0.0, 1.5, 275.0
	case ZoneWindPlateau, ZoneFrozenPeaks:
		return 0.0, 1.5, -275.0
	case ZoneBasaltHills:
		return -275.0, 1.5, 0.0
	case ZoneMistMarsh:
		return 275.0, 1.5, 0.0
	default: // ZoneVillage (0)
		if IsInteriorZone(zoneID) {
			return 0.0, 1.5, InteriorArriveZ
		}
		return 0.0, 1.5, 0.0
	}
}

// ResolvePortalTravel resolve o portal de destino a partir do portalID ou do targetZoneID.
func ResolvePortalTravel(currentZone, targetZoneID, portalID uint8) (PortalDef, bool) {
	// 1. Busca por PortalID direto
	if portalID > 0 {
		if p, ok := GetPortal(portalID); ok {
			return p, true
		}
	}

	// 2. Busca pela transição de zona (currentZone -> targetZoneID)
	if targetZoneID < ZoneCount && targetZoneID != currentZone {
		if p, ok := FindPortal(currentZone, targetZoneID); ok {
			return p, true
		}
	}

	// 3. Se portalID foi enviado com o targetZoneID (ex: via dev command com valor de zona)
	if portalID > 0 && portalID < ZoneCount && portalID != currentZone {
		if p, ok := FindPortal(currentZone, portalID); ok {
			return p, true
		}
	}

	// 4. Fallback: gera um PortalDef virtual com coordenadas seguras para a zona de destino
	if targetZoneID < ZoneCount && targetZoneID != currentZone {
		defX, defY, defZ := GetDefaultSafeCoordinates(targetZoneID)
		return PortalDef{
			ID:           portalID,
			Name:         fmt.Sprintf("Viagem para %s", GetZoneName(targetZoneID)),
			FromZoneID:   currentZone,
			TargetZoneID: targetZoneID,
			TargetX:      defX,
			TargetY:      defY,
			TargetZ:      defZ,
			NightOnly:    targetZoneID == ZoneBlackMarket,
		}, true
	}

	return PortalDef{}, false
}
