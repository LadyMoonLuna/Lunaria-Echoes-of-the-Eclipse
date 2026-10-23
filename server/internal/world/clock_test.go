package world

import (
	"testing"
)

func TestWorldClockAsymmetryAndPhases(t *testing.T) {
	clock := NewWorldClock(16.0)

	h, m, moon, weather := clock.GetTime()
	if h != 16 || m != 0 || moon != MoonPhaseWaxingCrescent || weather != WeatherClear {
		t.Fatalf("estado inicial incorreto: h=%d, m=%d, moon=%d, weather=%d", h, m, moon, weather)
	}

	// 1. Testa avanço diurno: 400s reais = 1 hora no jogo
	clock.Advance(400.0)
	h, _, _, _ = clock.GetTime()
	if h != 17 {
		t.Fatalf("esperava hora 17 após 400s de dia, obteve %d", h)
	}

	// 2. Cruza para as 18:00 (noite) -> deve avançar a fase da lua para Quarto Crescente (2)
	clock.Advance(400.0)
	h, _, moon, _ = clock.GetTime()
	if h != 18 {
		t.Fatalf("esperava hora 18 após mais 400s, obteve %d", h)
	}
	if moon != MoonPhaseFirstQuarter {
		t.Fatalf("esperava MoonPhaseFirstQuarter (2), obteve %d", moon)
	}

	// 3. Testa avanço noturno: 200s reais = 1 hora no jogo
	clock.Advance(200.0)
	h, _, _, _ = clock.GetTime()
	if h != 19 {
		t.Fatalf("esperava hora 19 após 200s de noite, obteve %d", h)
	}

	// 4. Testa AddHours passando pelas 18:00
	// Hora atual: 19:00. Adicionando 23 horas -> 19 + 23 = 42 = 18:00 (passa pelas 18:00)
	oldMoon := clock.GetMoonPhase()
	clock.AddHours(23)
	h, _, moon, _ = clock.GetTime()
	if h != 18 {
		t.Fatalf("esperava hora 18 após +23h, obteve %d", h)
	}
	expectedMoon := (oldMoon + 1) % 8
	if moon != expectedMoon {
		t.Fatalf("esperava fase da lua %d, obteve %d", expectedMoon, moon)
	}

	// 5. Testa CycleMoonPhase (0 a 9)
	for i := 0; i < 15; i++ {
		cur := clock.CycleMoonPhase()
		if cur >= 10 {
			t.Fatalf("fase lunar inválida: %d", cur)
		}
	}

	// 6. Testa CycleWeather (0 a 3)
	for i := 0; i < 10; i++ {
		w := clock.CycleWeather()
		if w >= 4 {
			t.Fatalf("clima inválido: %d", w)
		}
	}
}

func TestWorldClockSetExact(t *testing.T) {
	clock := NewWorldClock(12.0)

	// Testa SetHour (03:00, 18:00, etc)
	clock.SetHour(3)
	h, m, _, _ := clock.GetTime()
	if h != 3 || m != 0 {
		t.Fatalf("esperava 03:00, obteve %02d:%02d", h, m)
	}

	clock.SetHour(18)
	h, m, _, _ = clock.GetTime()
	if h != 18 || m != 0 {
		t.Fatalf("esperava 18:00, obteve %02d:%02d", h, m)
	}

	// Testa SetMoonPhase (0 a 9)
	mPhase := clock.SetMoonPhase(4) // Lua Cheia
	if mPhase != 4 || clock.GetMoonPhase() != 4 {
		t.Fatalf("esperava MoonPhase 4 (Lua Cheia), obteve %d", mPhase)
	}

	mPhase = clock.SetMoonPhase(8) // Lua de Sangue
	if mPhase != 8 || clock.GetMoonPhase() != 8 {
		t.Fatalf("esperava MoonPhase 8 (Lua de Sangue), obteve %d", mPhase)
	}

	// Testa SetWeather (0 a 3)
	w := clock.SetWeather(1) // Chuva
	if w != 1 || clock.GetWeather() != 1 {
		t.Fatalf("esperava Clima 1 (Chuva), obteve %d", w)
	}

	w = clock.SetWeather(2) // Neblina Densa
	if w != 2 || clock.GetWeather() != 2 {
		t.Fatalf("esperava Clima 2 (Neblina Densa), obteve %d", w)
	}
}
