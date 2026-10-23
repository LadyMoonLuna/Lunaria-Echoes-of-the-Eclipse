package world

// Zonas Oficiais de Lunaria (0 a 8)
const (
	ZoneVillage       uint8 = 0 // Vila do Refúgio & Arredores (600x600m | [-295, +295])
	ZoneForest        uint8 = 1 // Bosque Sussurrante / Floresta (600x600m | [-295, +295])
	ZoneRuins         uint8 = 2 // Ruínas da Vigília & Norte Gelado (600x600m | [-295, +295])
	ZoneSanctuary     uint8 = 3 // Santuário do Eclipse (600x600m | [-295, +295])
	ZoneAshFrontier   uint8 = 4 // Fronteira das Cinzas (Zona Futura) (600x600m | [-295, +295])
	ZoneChurch        uint8 = 5 // Interior da Igreja da Luz (60x60m | [-28, +28])
	ZoneMageTower     uint8 = 6 // Interior da Torre do Mago (60x60m | [-28, +28])
	ZoneBlackMarket   uint8 = 7 // Mercado Negro do Beco (80x80m | [-38, +38])
	ZoneAncientSewers uint8 = 8 // Esgotos Antigos (600x600m | [-295, +295])
	ZoneSewers        uint8 = 8 // Alias retrocompatível
)

// MapSize é a dimensão padrão de mundo aberto expandido para 600x600 metros.
const MapSize float32 = 600.0

// SafeMapMin e SafeMapMax definem o limite de segurança padrão [-295.0, +295.0] anti-abismo para 600x600m.
const (
	SafeMapMin float32 = -295.0
	SafeMapMax float32 = 295.0

	// Limites específicos por dimensão de mapa
	Bounds600Min float32 = -295.0
	Bounds600Max float32 = 295.0
	Bounds80Min  float32 = -38.0
	Bounds80Max  float32 = 38.0
	Bounds60Min  float32 = -28.0
	Bounds60Max  float32 = 28.0
)

// GetZoneBounds retorna os limites mínimos e máximos da zona com base no seu ZoneID.
func GetZoneBounds(zoneID uint8) (float32, float32) {
	switch zoneID {
	case ZoneChurch, ZoneMageTower:
		return Bounds60Min, Bounds60Max
	case ZoneBlackMarket:
		return Bounds80Min, Bounds80Max
	default:
		// Zonas 0, 1, 2, 3, 4, 8 (600x600m)
		return Bounds600Min, Bounds600Max
	}
}

// ClampToZoneBounds restringe coordenadas X e Z estritamente dentro da zona correspondente.
func ClampToZoneBounds(zoneID uint8, x, z float32) (float32, float32) {
	minB, maxB := GetZoneBounds(zoneID)
	if x < minB {
		x = minB
	} else if x > maxB {
		x = maxB
	}

	if z < minB {
		z = minB
	} else if z > maxB {
		z = maxB
	}

	return x, z
}

// ClampToMapBounds restringe coordenadas X e Z na zona padrão da Vila (600x600m: [-295.0, +295.0]).
func ClampToMapBounds(x, z float32) (float32, float32) {
	return ClampToZoneBounds(ZoneVillage, x, z)
}

// GetZoneName retorna a nomenclatura oficial da zona.
func GetZoneName(zoneID uint8) string {
	switch zoneID {
	case ZoneVillage:
		return "Vila do Refúgio & Arredores"
	case ZoneForest:
		return "Bosque Sussurrante / Floresta"
	case ZoneRuins:
		return "Ruínas da Vigília & Norte Gelado"
	case ZoneSanctuary:
		return "Santuário do Eclipse"
	case ZoneAshFrontier:
		return "Fronteira das Cinzas"
	case ZoneChurch:
		return "Interior da Igreja da Luz"
	case ZoneMageTower:
		return "Interior da Torre do Mago"
	case ZoneBlackMarket:
		return "Mercado Negro do Beco"
	case ZoneAncientSewers:
		return "Esgotos Antigos"
	default:
		return "Zona Desconhecida"
	}
}
