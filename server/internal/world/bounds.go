package world

// MapSize é a dimensão total do mapa expandido (180x180m, variando de -90.0 a +90.0 nos eixos X e Z).
const MapSize float32 = 180.0

// SafeMapMin e SafeMapMax definem o limite de segurança estrito [-86.0, +86.0] anti-abismo para Mobs e NPCs.
const (
	SafeMapMin float32 = -86.0
	SafeMapMax float32 = 86.0
)

// ClampToMapBounds restringe coordenadas X e Z estritamente dentro da zona segura [-70.0, +70.0].
func ClampToMapBounds(x, z float32) (float32, float32) {
	if x < SafeMapMin {
		x = SafeMapMin
	} else if x > SafeMapMax {
		x = SafeMapMax
	}

	if z < SafeMapMin {
		z = SafeMapMin
	} else if z > SafeMapMax {
		z = SafeMapMax
	}

	return x, z
}
