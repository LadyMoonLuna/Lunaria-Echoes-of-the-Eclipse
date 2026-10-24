package world

import "lunaria/server/internal/protocol"

// Sobrevivência dos jogadores: fome e temperatura corporal, no mesmo modelo dos NPCs do Mundo Vivo.

const (
	PlayerHungerPerMinute   float32 = 0.8 // um pouco mais rápido que os NPCs (aventureiros gastam mais)
	PlayerStarvingThreshold float32 = 25  // abaixo disso a estamina regenera pela metade
	PlayerStarveHPPerMinute float32 = 12  // de barriga vazia (0) perde vida
	PlayerColdPenalty       float32 = 70  // Frio/Calor acima disso: estamina regenera pela metade
	PlayerExposureHPPerMin  float32 = 15  // hipotermia ou insolação (100)
	CloakColdProtection     float32 = 6   // uma capa equipada protege 6 °C do frio
)

// Raças adaptadas ao frio ou ao calor (°C de tolerância a mais).
var raceColdTolerance = map[uint8]float32{
	protocol.RaceBoreal: 15, protocol.RaceFrostGiant: 18, protocol.RaceDwarf: 6, protocol.RaceWolfDemi: 8,
}
var raceHeatTolerance = map[uint8]float32{
	protocol.RaceAshDragonborn: 15, protocol.RacePyromancer: 18, protocol.RaceObsidianTitan: 10, protocol.RaceScorpionDemi: 10,
}

// Valor de cada comida para a fome.
var FoodValue = map[uint8]float32{
	protocol.ItemRawWolfMeat:     20,
	protocol.ItemCookedNobleMeat: 50,
	uint8(MatGameMeat):           30,
}

// SurvivalState é o que o HUD mostra (0x50).
type SurvivalState struct {
	Hunger, Cold, Heat uint8
	BodyTemp, Ambient  int8
}

// TickSurvival avança fome e temperatura do jogador por dt segundos sob a temperatura ambiente (°C)
// e devolve o dano que ele deve sofrer (fome extrema, hipotermia, insolação).
func (p *Player) TickSurvival(dt float32, ambient float32, nearFire bool) uint16 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	m := dt / 60
	if !p.survivalInit {
		p.Hunger, p.survivalInit = 100, true
	}
	p.Hunger = clampNeed(p.Hunger - PlayerHungerPerMinute*m)

	felt := ambient
	if nearFire {
		felt += FireHeatBonus
	}
	if p.EquippedSlots[protocol.SlotCloak] != 0 && felt < ComfortMinTemp {
		felt += CloakColdProtection
	}
	p.BodyTemp, p.AmbientTemp = felt, ambient
	coldLimit := ComfortMinTemp - raceColdTolerance[p.RaceID]
	heatLimit := ComfortMaxTemp + raceHeatTolerance[p.RaceID]
	switch {
	case felt < coldLimit:
		p.Cold = clampNeed(p.Cold + ColdRisePerMinute*(coldLimit-felt)/5*m)
		p.Heat = clampNeed(p.Heat - ColdFallPerMinute*m)
	case felt > heatLimit:
		p.Heat = clampNeed(p.Heat + ColdRisePerMinute*(felt-heatLimit)/5*m)
		p.Cold = clampNeed(p.Cold - ColdFallPerMinute*m)
	default:
		p.Cold = clampNeed(p.Cold - ColdFallPerMinute*m)
		p.Heat = clampNeed(p.Heat - ColdFallPerMinute*m)
	}

	hurt := float32(0)
	if p.Hunger <= 0 {
		hurt += PlayerStarveHPPerMinute
	}
	if p.Cold >= 100 {
		hurt += PlayerExposureHPPerMin
	}
	if p.Heat >= 100 {
		hurt += PlayerExposureHPPerMin
	}
	p.survivalDmg += hurt * m
	dmg := uint16(p.survivalDmg)
	p.survivalDmg -= float32(dmg)
	return dmg
}

// SurvivalSnapshot devolve os valores para o HUD.
func (p *Player) SurvivalSnapshot() SurvivalState {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return SurvivalState{Hunger: uint8(p.Hunger), Cold: uint8(p.Cold), Heat: uint8(p.Heat),
		BodyTemp: clampI8(p.BodyTemp), Ambient: clampI8(p.AmbientTemp)}
}

// staminaRegenMultLocked: fome, frio ou calor fortes cortam a regeneração de estamina pela metade.
func (p *Player) staminaRegenMultLocked() float32 {
	if !p.survivalInit {
		return 1
	}
	mult := float32(1)
	if p.Hunger < PlayerStarvingThreshold {
		mult *= 0.5
	}
	if p.Cold > PlayerColdPenalty || p.Heat > PlayerColdPenalty {
		mult *= 0.5
	}
	return mult
}

// feedLocked sacia a fome com a comida consumida.
func (p *Player) feedLocked(itemID uint8) {
	if v, ok := FoodValue[itemID]; ok {
		if !p.survivalInit {
			p.Hunger, p.survivalInit = 100, true
		}
		p.Hunger = clampNeed(p.Hunger + v)
	}
}

func clampI8(v float32) int8 {
	return int8(max(-128, min(127, v)))
}

// DevSetSurvival força fome/frio (comando DEV).
func (p *Player) DevSetSurvival(hunger, cold float32) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.survivalInit = true
	p.Hunger, p.Cold, p.Heat = hunger, cold, 0
}
