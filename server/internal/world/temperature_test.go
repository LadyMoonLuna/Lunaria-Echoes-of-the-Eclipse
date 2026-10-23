package world

import "testing"

func TestAmbientTempFollowsDayAndWeather(t *testing.T) {
	noon, dawn := AmbientTemp(ZoneVillage, 16, WeatherClear), AmbientTemp(ZoneVillage, 4, WeatherClear)
	if noon-dawn < 11 {
		t.Fatalf("a tarde deveria ser bem mais quente que a madrugada: %.1f vs %.1f", noon, dawn)
	}
	if AmbientTemp(ZoneVillage, 12, WeatherBlizzard) >= ComfortMinTemp {
		t.Fatal("nevasca deveria gelar a vila")
	}
	if AmbientTemp(ZoneAshFrontier, 14, WeatherHeatWave) <= WaterDryTemp {
		t.Fatal("onda de calor nas Cinzas deveria passar do ponto de secar a água")
	}
	if AmbientTemp(ZoneChurch, 12, WeatherBlizzard) < 15 {
		t.Fatal("interiores não sofrem o clima de fora")
	}
}

func TestHeatSpeedsThirst(t *testing.T) {
	if ThirstMultiplier(20) != 1 || ThirstMultiplier(36) <= 2 {
		t.Fatalf("multiplicador de sede errado: %.2f / %.2f", ThirstMultiplier(20), ThirstMultiplier(36))
	}
	hot := NewNPC(1, "a", 0, 0, 0, "", nil, nil)
	mild := NewNPC(2, "b", 0, 0, 0, "", nil, nil)
	hot.TickNeeds(60, 40)
	mild.TickNeeds(60, 18)
	if hot.Thirst >= mild.Thirst || hot.Heat <= 0 || mild.Heat != 0 {
		t.Fatalf("calor deveria acelerar sede e acumular calor: %.2f vs %.2f, calor %.1f", hot.Thirst, mild.Thirst, hot.Heat)
	}
}

func TestPuddlesDryInHeatAndRefillWithRain(t *testing.T) {
	m := NewResourceNodeManager()
	always := func() float32 { return 0 }
	if !m.UpdateEvaporation(ZoneVillage, 45, false, always) {
		t.Fatal("no calor extremo alguma poça da vila deveria secar")
	}
	for _, n := range m.InZone(ZoneVillage) {
		if IsEvaporable(n.MaterialID) && n.Available() {
			t.Fatal("poça seca não pode ser coletada")
		}
	}
	m.UpdateEvaporation(ZoneVillage, 35, true, always)
	for _, n := range m.InZone(ZoneVillage) {
		if n.DriedUp {
			t.Fatal("a chuva deveria reabastecer as poças")
		}
	}
}
