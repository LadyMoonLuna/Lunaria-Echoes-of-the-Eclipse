package world

import (
	"sync"
)

// Constantes de Fases da Lua (10 estados: 0 a 9)
const (
	MoonPhaseNew           uint8 = 0 // Lua Nova
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

// Constantes de Clima (4 estados: 0 a 3)
const (
	WeatherClear       uint8 = 0 // Limpo
	WeatherRain        uint8 = 1 // Chuva
	WeatherDenseFog    uint8 = 2 // Neblina Densa
	WeatherCrimsonMist uint8 = 3 // Névoa Carmesim
)

// WorldClock gerencia o relógio assimétrico oficial de Lunaria:
// - Dia (06:00 às 17:59): 80 minutos reais (1 hora diurna = 400s reais).
// - Noite (18:00 às 05:59): 40 minutos reais (1 hora noturna = 200s reais).
// Controla também as 10 Fases da Lua e 4 tipos de Clima Dinâmico.
type WorldClock struct {
	mu             sync.RWMutex
	currentHour    float64
	moonPhase      uint8
	weatherType    uint8
	lastLoggedHour int
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
		weatherType:    WeatherClear,           // Clima Limpo (0)
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
	if c.currentHour >= 24.0 {
		c.currentHour -= 24.0
	}

	newH := int(c.currentHour)
	// Se cruzar para as 18:00 (início da noite), avança a fase natural da lua (0 a 7)
	if oldH != 18 && newH == 18 {
		c.moonPhase = (c.moonPhase + 1) % 8
	}
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

// GetWeather retorna o tipo de clima atual (0 a 3).
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

// CycleWeather avança ciclicamente entre os 4 climas (Comando F8).
func (c *WorldClock) CycleWeather() uint8 {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.weatherType = (c.weatherType + 1) % 4
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
