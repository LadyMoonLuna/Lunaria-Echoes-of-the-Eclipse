package world

import (
	"time"

	"lunaria/server/internal/protocol"
)

// NewRaceData concentra os números das raças 29 a 45 (docs/design/racas_propostas.md).
// Atributos na ordem FOR, DES, CON, AGI, INT, ESP, PER, SOR.
// Enquanto a barra de Mana não existe, o bônus de Mana da proposta soma na Stamina.
type NewRaceData struct {
	Attrs       [8]uint8
	ModHP       uint16
	ModStamina  uint16
	DamageTaken float32       // multiplicador de dano recebido (1.0 = normal)
	RacialCD    time.Duration // recarga da habilidade racial [Z]
	LastStand   bool          // revive uma vez com 20% de vida (recarga longa)
}

var newRaces = map[uint8]NewRaceData{
	protocol.RaceOrc:            {[8]uint8{10, 5, 9, 5, 3, 5, 7, 6}, 25, 15, 0.92, 25 * time.Second, false},
	protocol.RaceGoblin:         {[8]uint8{4, 10, 5, 10, 4, 4, 5, 8}, 5, 35, 1.0, 30 * time.Second, false},
	protocol.RaceElf:            {[8]uint8{4, 9, 5, 9, 8, 6, 5, 4}, 5, 35, 1.0, 12 * time.Second, false},
	protocol.RaceSolarElf:       {[8]uint8{11, 10, 8, 10, 7, 9, 8, 7}, 45, 55, 1.0, 40 * time.Second, false},
	protocol.RaceLunarElf:       {[8]uint8{8, 13, 6, 13, 9, 7, 8, 6}, 30, 70, 1.0, 35 * time.Second, false},
	protocol.RaceEarthDrago:     {[8]uint8{11, 4, 13, 4, 3, 6, 9, 8}, 55, 15, 0.80, 30 * time.Second, true},
	protocol.RaceWaterDrago:     {[8]uint8{8, 10, 9, 8, 6, 7, 6, 4}, 30, 40, 1.0, 8 * time.Second, true},
	protocol.RaceLightningDrago: {[8]uint8{5, 11, 6, 11, 9, 6, 5, 5}, 20, 50, 1.0, 20 * time.Second, true},
	protocol.RaceMysticDrago:    {[8]uint8{3, 5, 5, 6, 13, 12, 8, 6}, 5, 65, 1.0, 40 * time.Second, true},
	protocol.RacePyromancer:     {[8]uint8{6, 7, 6, 7, 11, 9, 6, 6}, 10, 60, 1.0, 60 * time.Second, true},
	protocol.RaceScorpionkin:    {[8]uint8{7, 11, 8, 10, 4, 4, 9, 5}, 25, 45, 1.0, 45 * time.Second, false},
	protocol.RaceTortoisekin:    {[8]uint8{8, 3, 15, 3, 5, 8, 10, 6}, 65, 5, 0.85, 20 * time.Second, false},
	protocol.RaceFairy:          {[8]uint8{2, 9, 3, 11, 13, 11, 4, 5}, 0, 80, 1.10, 30 * time.Second, false},
	protocol.RaceHalfCelestial:  {[8]uint8{6, 6, 7, 7, 8, 12, 6, 6}, 20, 50, 1.0, 60 * time.Second, false},
	protocol.RaceFrostGiant:     {[8]uint8{14, 5, 16, 4, 5, 8, 10, 8}, 80, 20, 0.88, 45 * time.Second, false},
	protocol.RaceSuccubus:       {[8]uint8{6, 11, 7, 11, 11, 7, 6, 11}, 25, 75, 1.0, 45 * time.Second, false},
	// Manamante: a reserva única de Vida+Mana fica toda na Vida
	protocol.RaceManamancer: {[8]uint8{3, 6, 8, 6, 13, 11, 7, 4}, 60, 10, 1.0, 20 * time.Second, false},
}

// LookupNewRace retorna os dados de uma raça 29–45.
func LookupNewRace(raceID uint8) (NewRaceData, bool) {
	d, ok := newRaces[raceID]
	return d, ok
}

// IsNewRace informa se o ID pertence às raças 29–45.
func IsNewRace(raceID uint8) bool {
	_, ok := newRaces[raceID]
	return ok
}

// LastStandCooldown é a recarga do Renascer das Cinzas (Pyromante) e do Último Fôlego (Drago).
const LastStandCooldown = 20 * time.Minute
