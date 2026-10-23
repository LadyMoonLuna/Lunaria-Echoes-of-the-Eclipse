package world

import "math"

// Sistema de temperatura: cada zona tem uma temperatura ambiente (°C) que varia com a hora e o clima.
// O corpo dos NPCs acumula Frio abaixo da faixa de conforto e Calor acima dela; o calor acelera a sede
// e seca as pequenas águas (poças, orvalho, riachos rasos).

const (
	ComfortMinTemp float32 = 10 // abaixo disso o corpo esfria
	ComfortMaxTemp float32 = 26 // acima disso o corpo esquenta
	FireHeatBonus  float32 = 14 // fornalha/fogueira próxima

	ThirstHeatPerDegree float32 = 0.12 // +12% de sede por grau acima do conforto
	MaxThirstMult       float32 = 3.0

	WaterDryTemp               float32 = 30   // acima disso as águas rasas começam a secar
	WaterRefillTemp            float32 = 22   // abaixo disso (ou com chuva) voltam
	EvaporationChancePerDegree float32 = 0.01 // por grau acima de WaterDryTemp, a cada verificação
)

// Temperatura base (°C) de cada zona ao meio-dia de céu limpo.
var ZoneBaseTemp = map[uint8]float32{
	ZoneVillage:       18,
	ZoneForest:        15,
	ZoneRuins:         -4, // Norte Gelado
	ZoneSanctuary:     12,
	ZoneAshFrontier:   33, // Fronteira das Cinzas
	ZoneChurch:        19,
	ZoneMageTower:     20,
	ZoneBlackMarket:   21,
	ZoneAncientSewers: 13,
	ZoneSparseWoods:   16,
	ZoneGrasslands:    19,
	ZoneSavanna:       27,
	ZoneSaltDesert:    36, // o sal reflete o sol: o lugar mais quente do mundo
	ZoneWindPlateau:   10,
	ZoneFrozenPeaks:   -14,
	ZoneBasaltHills:   23,
	ZoneMistMarsh:     18,
}

// Ambientes fechados: o clima de fora não entra e a variação do dia é menor.
var indoorZones = map[uint8]bool{ZoneChurch: true, ZoneMageTower: true, ZoneBlackMarket: true, ZoneAncientSewers: true}

// WeatherTempOffset: quanto cada clima esquenta ou esfria (°C).
var WeatherTempOffset = map[uint8]float32{
	WeatherRain: -4, WeatherDrizzle: -2, WeatherDenseFog: -2, WeatherSnow: -10, WeatherBlizzard: -18,
	WeatherThunderstorm: -5, WeatherHail: -7, WeatherGale: -4, WeatherAcidRain: -3, WeatherAurora: -6,
	WeatherSandstorm: 6, WeatherAshfall: 4, WeatherHeatWave: 14, WeatherCrimsonMist: 2,
}

// IsRainyWeather: climas que molham o chão (reabastecem as poças).
func IsRainyWeather(w uint8) bool {
	switch w {
	case WeatherRain, WeatherDrizzle, WeatherThunderstorm, WeatherAcidRain, WeatherHail:
		return true
	}
	return false
}

// DailyTempOffset: curva do dia, mínima às 04h (-6 °C) e máxima às 16h (+6 °C).
func DailyTempOffset(hour int) float32 {
	return float32(-6 * math.Cos(2*math.Pi*float64(hour-4)/24))
}

// AmbientTemp devolve a temperatura (°C) da zona na hora e clima dados.
func AmbientTemp(zone uint8, hour int, weather uint8) float32 {
	t := ZoneBaseTemp[zone]
	if indoorZones[zone] {
		return t + DailyTempOffset(hour)*0.3
	}
	return t + DailyTempOffset(hour) + WeatherTempOffset[weather]
}

// ThirstMultiplier: o calor faz a sede cair mais rápido.
func ThirstMultiplier(tempC float32) float32 {
	if tempC <= ComfortMaxTemp {
		return 1
	}
	return min(1+(tempC-ComfortMaxTemp)*ThirstHeatPerDegree, MaxThirstMult)
}
