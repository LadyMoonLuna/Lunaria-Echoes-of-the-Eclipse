package world

import (
	"math"
	"math/rand"
	"sync"
)

// Constantes de Fases da Lua (10 estados: 0 a 9)
const (
	MoonPhaseNew            uint8 = 0 // Lua Nova
	MoonPhaseWaxingCrescent uint8 = 1 // Lua Crescente
	MoonPhaseFirstQuarter   uint8 = 2 // Quarto Crescente
	MoonPhaseWaxingGibbous  uint8 = 3 // Gibosa Crescente
	MoonPhaseFull           uint8 = 4 // Lua Cheia
	MoonPhaseWaningGibbous  uint8 = 5 // Gibosa Minguante
	MoonPhaseLastQuarter    uint8 = 6 // Quarto Minguante
	MoonPhaseWaningCrescent uint8 = 7 // Lua Minguante
	MoonPhaseBloodMoon      uint8 = 8 // Lua de Sangue (Evento Especial)
	MoonPhaseEclipse        uint8 = 9 // Eclipse Total (Cataclismo)
)

// Constantes de Clima (24 estados: 0 a 23)
const (
	WeatherClear        uint8 = 0  // Limpo
	WeatherRain         uint8 = 1  // Chuva
	WeatherDenseFog     uint8 = 2  // Neblina Densa
	WeatherCrimsonMist  uint8 = 3  // Névoa Carmesim
	WeatherSnow         uint8 = 4  // Neve
	WeatherBlizzard     uint8 = 5  // Nevasca
	WeatherThunderstorm uint8 = 6  // Tempestade de Raios
	WeatherDrizzle      uint8 = 7  // Garoa
	WeatherHail         uint8 = 8  // Granizo
	WeatherSandstorm    uint8 = 9  // Tempestade de Areia
	WeatherAshfall      uint8 = 10 // Chuva de Cinzas
	WeatherHeatWave     uint8 = 11 // Onda de Calor
	WeatherGale         uint8 = 12 // Vendaval
	WeatherAurora       uint8 = 13 // Aurora Boreal
	WeatherMeteorShower uint8 = 14 // Chuva de Meteoros
	WeatherAcidRain     uint8 = 15 // Chuva Ácida
	WeatherPetals       uint8 = 16 // Pétalas ao Vento
	WeatherFireflies    uint8 = 17 // Noite de Vaga-lumes
	WeatherMiasma       uint8 = 18 // Miasma Violeta
	WeatherRainbow      uint8 = 19 // Arco-Íris
	WeatherSporeFog     uint8 = 20 // Nevoeiro de Esporos
	WeatherArcaneStorm  uint8 = 21 // Tempestade Arcana
	WeatherCrystalFrost uint8 = 22 // Geada Cristalina
	WeatherMonsoon      uint8 = 23 // Monção

	WeatherCount uint8 = 24
	zoneCount          = int(ZoneCount)
)

// WeatherNames lista os nomes exibidos de cada clima (índice = WeatherType).
var WeatherNames = []string{
	"Limpo", "Chuva", "Neblina Densa", "Névoa Carmesim", "Neve", "Nevasca",
	"Tempestade de Raios", "Garoa", "Granizo", "Tempestade de Areia", "Chuva de Cinzas",
	"Onda de Calor", "Vendaval", "Aurora Boreal", "Chuva de Meteoros", "Chuva Ácida",
	"Pétalas ao Vento", "Noite de Vaga-lumes", "Miasma Violeta", "Arco-Íris",
	"Nevoeiro de Esporos", "Tempestade Arcana", "Geada Cristalina", "Monção",
}

// WeatherName retorna o nome legível do clima.
func WeatherName(w uint8) string {
	if int(w) < len(WeatherNames) {
		return WeatherNames[w]
	}
	return "Desconhecido"
}

// IsRainy indica climas com água caindo do céu (contam como "chuva" para passivas).
func IsRainy(w uint8) bool {
	return w == WeatherRain || w == WeatherThunderstorm || w == WeatherDrizzle || w == WeatherMonsoon || w == WeatherAcidRain
}

// IsNightOnly / IsDayOnly restringem climas que só fazem sentido em certos horários.
func isNightOnly(w uint8) bool {
	return w == WeatherFireflies || w == WeatherAurora || w == WeatherMeteorShower
}

func isDayOnly(w uint8) bool {
	return w == WeatherRainbow || w == WeatherHeatWave
}

type weatherWeight struct {
	w      uint8
	weight int
}

// zoneWeatherTable define quais climas podem surgir naturalmente em cada zona e seus pesos.
var zoneWeatherTable = [zoneCount][]weatherWeight{
	ZoneVillage: {{WeatherClear, 30}, {WeatherRain, 10}, {WeatherDrizzle, 10}, {WeatherDenseFog, 6},
		{WeatherThunderstorm, 4}, {WeatherGale, 5}, {WeatherPetals, 6}, {WeatherRainbow, 5},
		{WeatherFireflies, 6}, {WeatherMeteorShower, 3}, {WeatherHail, 2}, {WeatherSnow, 2}},
	ZoneForest: {{WeatherClear, 20}, {WeatherRain, 10}, {WeatherDrizzle, 8}, {WeatherDenseFog, 8},
		{WeatherMonsoon, 4}, {WeatherPetals, 8}, {WeatherFireflies, 10}, {WeatherSporeFog, 7},
		{WeatherRainbow, 5}, {WeatherThunderstorm, 4}, {WeatherMiasma, 2}},
	ZoneRuins: {{WeatherClear, 15}, {WeatherSnow, 15}, {WeatherBlizzard, 7}, {WeatherHail, 6},
		{WeatherCrystalFrost, 8}, {WeatherAurora, 10}, {WeatherGale, 8}, {WeatherDenseFog, 6},
		{WeatherThunderstorm, 3}},
	ZoneSanctuary: {{WeatherClear, 18}, {WeatherCrimsonMist, 12}, {WeatherArcaneStorm, 8},
		{WeatherMeteorShower, 7}, {WeatherAurora, 6}, {WeatherMiasma, 6}, {WeatherDenseFog, 6},
		{WeatherThunderstorm, 4}},
	ZoneAshFrontier: {{WeatherClear, 12}, {WeatherAshfall, 15}, {WeatherHeatWave, 12},
		{WeatherSandstorm, 10}, {WeatherAcidRain, 6}, {WeatherThunderstorm, 5}, {WeatherGale, 6},
		{WeatherCrimsonMist, 3}},
	ZoneChurch:      {{WeatherClear, 1}},
	ZoneMageTower:   {{WeatherClear, 1}},
	ZoneBlackMarket: {{WeatherClear, 1}},
	ZoneAncientSewers: {{WeatherClear, 20}, {WeatherDenseFog, 10}, {WeatherSporeFog, 10},
		{WeatherMiasma, 8}},
	ZoneSparseWoods: {{WeatherClear, 26}, {WeatherRain, 10}, {WeatherDrizzle, 8}, {WeatherDenseFog, 6},
		{WeatherPetals, 6}, {WeatherFireflies, 8}, {WeatherRainbow, 5}, {WeatherThunderstorm, 4}},
	ZoneGrasslands: {{WeatherClear, 32}, {WeatherRain, 8}, {WeatherDrizzle, 6}, {WeatherGale, 8},
		{WeatherThunderstorm, 6}, {WeatherRainbow, 6}, {WeatherPetals, 5}, {WeatherHail, 2}},
	ZoneSavanna: {{WeatherClear, 32}, {WeatherHeatWave, 12}, {WeatherGale, 8}, {WeatherThunderstorm, 6},
		{WeatherMonsoon, 5}, {WeatherSandstorm, 3}, {WeatherRainbow, 3}},
	ZoneSaltDesert: {{WeatherClear, 30}, {WeatherHeatWave, 16}, {WeatherSandstorm, 14}, {WeatherGale, 6},
		{WeatherMeteorShower, 3}},
	ZoneWindPlateau: {{WeatherClear, 24}, {WeatherGale, 14}, {WeatherDrizzle, 8}, {WeatherDenseFog, 8},
		{WeatherHail, 4}, {WeatherSnow, 4}, {WeatherAurora, 3}},
	ZoneFrozenPeaks: {{WeatherClear, 12}, {WeatherSnow, 18}, {WeatherBlizzard, 12}, {WeatherCrystalFrost, 10},
		{WeatherAurora, 10}, {WeatherGale, 8}, {WeatherHail, 5}},
	ZoneBasaltHills: {{WeatherClear, 28}, {WeatherGale, 10}, {WeatherHeatWave, 8}, {WeatherSandstorm, 5},
		{WeatherAshfall, 4}, {WeatherThunderstorm, 4}},
	ZoneMistMarsh: {{WeatherDenseFog, 18}, {WeatherDrizzle, 12}, {WeatherRain, 10}, {WeatherSporeFog, 10},
		{WeatherMiasma, 8}, {WeatherFireflies, 8}, {WeatherClear, 8}, {WeatherMonsoon, 4}},
}

// rollZoneWeather sorteia um clima ponderado para a zona respeitando dia/noite.
func rollZoneWeather(zone int, hour int) uint8 {
	night := hour >= 18 || hour < 6
	table := zoneWeatherTable[zone]
	total := 0
	for _, e := range table {
		if (isNightOnly(e.w) && !night) || (isDayOnly(e.w) && night) {
			continue
		}
		total += e.weight
	}
	if total <= 0 {
		return WeatherClear
	}
	r := rand.Intn(total)
	for _, e := range table {
		if (isNightOnly(e.w) && !night) || (isDayOnly(e.w) && night) {
			continue
		}
		if r < e.weight {
			return e.w
		}
		r -= e.weight
	}
	return WeatherClear
}

// WorldClock gerencia o relógio assimétrico oficial de Lunaria:
// - Dia (06:00 às 17:59): 80 minutos reais (1 hora diurna = 400s reais).
// - Noite (18:00 às 05:59): 40 minutos reais (1 hora noturna = 200s reais).
// Controla também as 10 Fases da Lua e 4 tipos de Clima Dinâmico.
type WorldClock struct {
	mu             sync.RWMutex
	currentHour    float64
	moonPhase      uint8
	weatherType    uint8 // Clima da Vila (zona 0), mantido para compatibilidade
	zoneWeather    [zoneCount]uint8
	weatherLocked  bool // true quando o dev fixou o clima manualmente (desliga sorteio)
	lastLoggedHour int
	elapsedHours   float64 // horas de jogo desde que o servidor ligou (cooldowns, mercado)
}

// NewWorldClock cria o relógio oficial iniciando em 16:00 (final da tarde),
// com Lua Crescente (1) e Clima Limpo (0).
func NewWorldClock(startHour float64) *WorldClock {
	h := startHour
	if h < 0 || h >= 24 {
		h = 16.0
	}
	return &WorldClock{
		currentHour:    h,
		moonPhase:      MoonPhaseWaxingCrescent, // Inicia na Lua Crescente (1)
		weatherType:    WeatherClear,            // Clima Limpo (0)
		lastLoggedHour: int(h) % 24,
	}
}

// Advance avança o tempo com base em segundos reais decorridos, respeitando a assimetria:
// Dia: 400s reais por hora de jogo.
// Noite: 200s reais por hora de jogo.
func (c *WorldClock) Advance(dtSec float64) {
	c.mu.Lock()
	defer c.mu.Unlock()

	oldH := int(c.currentHour)
	var hourDelta float64
	if oldH >= 6 && oldH < 18 {
		hourDelta = dtSec / 400.0
	} else {
		hourDelta = dtSec / 200.0
	}

	c.currentHour += hourDelta
	c.elapsedHours += hourDelta
	if c.currentHour >= 24.0 {
		c.currentHour -= 24.0
	}

	newH := int(c.currentHour)
	// Se cruzar para as 18:00 (início da noite), avança a fase natural da lua (0 a 7)
	if oldH != 18 && newH == 18 {
		c.moonPhase = (c.moonPhase + 1) % 8
	}
	// A cada 3 horas de jogo, cada zona sorteia um novo clima
	if oldH != newH && newH%3 == 0 && !c.weatherLocked {
		c.rollAllLocked(newH)
	}
}

func (c *WorldClock) rollAllLocked(hour int) {
	for z := 0; z < zoneCount; z++ {
		c.zoneWeather[z] = rollZoneWeather(z, hour)
	}
	c.weatherType = c.zoneWeather[ZoneVillage]
}

func (c *WorldClock) setAllLocked(w uint8) {
	for z := 0; z < zoneCount; z++ {
		c.zoneWeather[z] = w
	}
	c.weatherType = w
}

// GetZoneWeather retorna o clima atual de uma zona específica.
func (c *WorldClock) GetZoneWeather(zone uint8) uint8 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if int(zone) >= zoneCount {
		return c.weatherType
	}
	return c.zoneWeather[zone]
}

// RollWeatherNow força um novo sorteio de clima em todas as zonas e libera o modo automático.
func (c *WorldClock) RollWeatherNow() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.weatherLocked = false
	c.rollAllLocked(int(c.currentHour))
}

// GetTime retorna (WorldHour, WorldMinute, MoonPhase, WeatherType) de forma thread-safe.
func (c *WorldClock) GetTime() (uint8, uint8, uint8, uint8) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	h := int(c.currentHour)
	m := int((c.currentHour - float64(h)) * 60.0)
	if m >= 60 {
		m = 59
	}
	return uint8(h), uint8(m), c.moonPhase, c.weatherType
}

// GetCurrentHour retorna a hora inteira atual do jogo (0 a 23).
// ElapsedHours: horas de jogo corridas desde o início do servidor (nunca volta a zero).
func (c *WorldClock) ElapsedHours() float64 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.elapsedHours
}

func (c *WorldClock) GetCurrentHour() int {
	h, _, _, _ := c.GetTime()
	return int(h)
}

// GetMoonPhase retorna a fase atual da lua (0 a 9).
func (c *WorldClock) GetMoonPhase() uint8 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.moonPhase
}

// GetWeather retorna o tipo de clima da Vila (0 a 23).
func (c *WorldClock) GetWeather() uint8 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.weatherType
}

// AddHours soma horas instantaneamente ao relógio (Comando F6).
// Se passar pelas 18:00, avança a fase natural da lua (% 8).
func (c *WorldClock) AddHours(hours int) {
	c.mu.Lock()
	defer c.mu.Unlock()

	for i := 0; i < hours; i++ {
		oldH := int(c.currentHour)
		c.currentHour += 1.0
		if c.currentHour >= 24.0 {
			c.currentHour -= 24.0
		}
		newH := int(c.currentHour)
		if oldH != 18 && newH == 18 {
			c.moonPhase = (c.moonPhase + 1) % 8
		}
	}
}

// CycleMoonPhase avança ciclicamente entre todas as 10 fases da lua (Comando F7).
func (c *WorldClock) CycleMoonPhase() uint8 {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.moonPhase = (c.moonPhase + 1) % 10
	return c.moonPhase
}

// CycleWeather avança ciclicamente entre todos os climas em todas as zonas (Comando F8).
func (c *WorldClock) CycleWeather() uint8 {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.weatherLocked = true
	c.setAllLocked((c.weatherType + 1) % WeatherCount)
	return c.weatherType
}

// CheckHourChanged verifica se a hora cheia mudou desde a última checagem para logging.
func (c *WorldClock) CheckHourChanged() (bool, int) {
	c.mu.Lock()
	defer c.mu.Unlock()

	currentH := int(c.currentHour)
	if currentH != c.lastLoggedHour {
		c.lastLoggedHour = currentH
		return true, currentH
	}
	return false, currentH
}

// SetHour define diretamente a hora do relógio (0 a 23), zerando os minutos.
func (c *WorldClock) SetHour(hour uint8) {
	c.mu.Lock()
	defer c.mu.Unlock()
	// Pular o relógio adiante (Dev) também conta para cooldowns e para o mercado
	c.elapsedHours += math.Mod(float64(hour%24)-c.currentHour+24, 24)
	c.currentHour = float64(hour % 24)
}

// SetMoonPhase define diretamente a fase da lua (0 a 9).
func (c *WorldClock) SetMoonPhase(phase uint8) uint8 {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.moonPhase = phase % 10
	return c.moonPhase
}

// SetWeather define diretamente o clima de todas as zonas (0 a 23) e trava o sorteio.
// O valor 255 volta ao modo automático.
func (c *WorldClock) SetWeather(weather uint8) uint8 {
	c.mu.Lock()
	defer c.mu.Unlock()
	if weather == 255 {
		c.weatherLocked = false
		c.rollAllLocked(int(c.currentHour))
		return c.weatherType
	}
	c.weatherLocked = true
	c.setAllLocked(weather % WeatherCount)
	return c.weatherType
}

// WeatherManaMult altera a regeneração passiva de Mana conforme o clima da zona.
func WeatherManaMult(w uint8) float32 {
	switch w {
	case WeatherArcaneStorm:
		return 2.0
	case WeatherAurora:
		return 1.5
	case WeatherMeteorShower, WeatherFireflies:
		return 1.2
	case WeatherMiasma, WeatherAcidRain:
		return 0.7
	}
	return 1.0
}

// WeatherStaminaMult altera a regeneração de Estamina conforme o clima da zona.
func WeatherStaminaMult(w uint8) float32 {
	switch w {
	case WeatherHeatWave, WeatherBlizzard:
		return 0.7
	case WeatherSandstorm, WeatherMonsoon:
		return 0.85
	case WeatherRainbow, WeatherPetals:
		return 1.2
	}
	return 1.0
}
