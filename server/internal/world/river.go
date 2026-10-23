package world

import "math"

// Rio Prateado: nasce num lago glacial nos Picos Gelados e desce pelas Ruínas, Planalto, Vila,
// Bosque, Bosque Ralo e Campos até desaguar no Grande Lago da Savana. O traçado é uma soma de
// senoides em coordenadas GLOBAIS (cada zona é uma célula de 600 m da grade do mundo), então o
// rio continua sem emendas de uma zona para a outra. O cliente (Terrain.gd) usa a mesma fórmula.

// ZoneGrid: posição de cada zona aberta na grade do mundo (coluna = leste, linha = norte).
var ZoneGrid = map[uint8][2]int{
	ZoneVillage: {0, 0}, ZoneForest: {0, -1}, ZoneSparseWoods: {0, -2}, ZoneGrasslands: {0, -3},
	ZoneSavanna: {0, -4}, ZoneSaltDesert: {0, -5}, ZoneWindPlateau: {0, 1}, ZoneRuins: {0, 2},
	ZoneFrozenPeaks: {0, 3}, ZoneBasaltHills: {1, 0}, ZoneAshFrontier: {2, 0}, ZoneSanctuary: {-1, 0},
	ZoneMistMarsh: {-2, 0},
}

const (
	ZoneSpan        float64 = 600
	RiverSourceGZ   float64 = 3*ZoneSpan + 150 // lago glacial nos Picos
	RiverMouthGZ    float64 = -4*ZoneSpan + 30 // Grande Lago da Savana
	RiverMouthLakeR float64 = 75
)

// GlobalZ converte o Z local de uma zona no Z global do mundo.
func GlobalZ(zone uint8, z float32) (float64, bool) {
	g, ok := ZoneGrid[zone]
	if !ok || g[0] != 0 {
		return 0, false // o rio só corre pela coluna central do mundo
	}
	return float64(g[1])*ZoneSpan + float64(z), true
}

// RiverX: centro do rio (X local) na altura gz.
func RiverX(gz float64) float64 {
	return 116 + 14*math.Sin(gz/83.0) + 7*math.Sin(gz/31.0+1.7) + 3*math.Sin(gz/13.0+0.4)
}

// RiverWidth: o rio alarga rio abaixo (≈7 m na nascente, ≈14 m na foz).
func RiverWidth(gz float64) float64 {
	return 7 + (RiverSourceGZ-gz)/600
}

// RiverAt informa se a zona tem rio na altura z e devolve centro e largura.
func RiverAt(zone uint8, z float32) (cx, width float64, ok bool) {
	gz, inCol := GlobalZ(zone, z)
	if !inCol || gz > RiverSourceGZ || gz < RiverMouthGZ {
		return 0, 0, false
	}
	return RiverX(gz), RiverWidth(gz), true
}

// IsRiverWater: o ponto cai dentro do leito do rio.
func IsRiverWater(zone uint8, x, z float32) bool {
	cx, w, ok := RiverAt(zone, z)
	return ok && math.Abs(float64(x)-cx) < w/2+1.5
}

// RiverBank devolve um ponto na margem oeste do rio (para os NPCs beberem).
func RiverBank(zone uint8, z float32) [2]float32 {
	cx, w, ok := RiverAt(zone, z)
	if !ok {
		return [2]float32{0, z}
	}
	return [2]float32{float32(cx - w/2 - 2), z}
}

func init() {
	PlaceRiver = RiverBank(ZoneVillage, 18)
}
