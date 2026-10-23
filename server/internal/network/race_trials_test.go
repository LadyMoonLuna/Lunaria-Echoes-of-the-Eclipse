package network

import (
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func TestEverySecretRaceHasAnUnlock(t *testing.T) {
	// Raças com despertar por item/morte já existente
	byItem := map[uint8]bool{
		protocol.RaceDhampir: true, protocol.RaceRevenant: true, protocol.RaceArachne: true,
		protocol.RaceBoreal: true, protocol.RaceTimeWanderer: true, protocol.RaceScorpionDemi: true,
	}
	for r := uint8(5); r <= protocol.RaceMaxID; r++ {
		if r >= 11 && r <= 18 { // evoluções de nível 10
			continue
		}
		if !byItem[r] && raceTrialByRace(r) == nil {
			t.Fatalf("raça %d sem provação de desbloqueio", r)
		}
	}
}

func TestHourRangeAcrossMidnight(t *testing.T) {
	if !hourInRange(23, 18, 5) || !hourInRange(3, 18, 5) || hourInRange(12, 18, 5) {
		t.Fatal("intervalo noturno incorreto")
	}
	if !hourInRange(7, anyHour, 0) {
		t.Fatal("anyHour deveria aceitar qualquer hora")
	}
}

func TestPlaceTrialCompletes(t *testing.T) {
	s := &Server{players: map[uint32]*world.Player{}, npcs: map[uint32]*world.NPC{}, clock: world.NewWorldClock(10)}
	p := world.NewPlayer(1, nil, 0, 0, 0)
	p.ZoneID = world.ZoneForest
	p.PosX, p.PosZ = 0, 240
	s.players[1] = p
	s.clock.SetWeather(world.WeatherPetals) // Florescer no Bosque (Sylvari), de dia
	for i := 0; i < 29; i++ {
		s.updatePlaceTrials()
	}
	if p.TrialProgress[protocol.RaceSylvari] != 29 {
		t.Fatalf("progresso esperado 29, obtido %v", p.TrialProgress[protocol.RaceSylvari])
	}
	p.PosX = 100 // saiu do ponto: o enigma reinicia
	s.updatePlaceTrials()
	if p.TrialProgress[protocol.RaceSylvari] != 0 {
		t.Fatal("sair do ponto deveria reiniciar o enigma")
	}
}
