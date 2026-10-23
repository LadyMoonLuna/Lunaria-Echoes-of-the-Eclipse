package world

import "testing"

func TestZoneWeatherRollsRespectTables(t *testing.T) {
	c := NewWorldClock(10)
	for i := 0; i < 200; i++ {
		c.RollWeatherNow()
		for _, z := range []uint8{ZoneChurch, ZoneMageTower, ZoneBlackMarket} {
			if w := c.GetZoneWeather(z); w != WeatherClear {
				t.Fatalf("zona interna %d com clima %d", z, w)
			}
		}
		if w := c.GetZoneWeather(ZoneVillage); w == WeatherFireflies || w == WeatherAurora || w == WeatherMeteorShower {
			t.Fatalf("clima noturno %d sorteado de dia", w)
		}
	}
}

func TestSetWeatherLocksAllZones(t *testing.T) {
	c := NewWorldClock(10)
	c.SetWeather(WeatherBlizzard)
	for z := uint8(0); int(z) < zoneCount; z++ {
		if c.GetZoneWeather(z) != WeatherBlizzard {
			t.Fatalf("zona %d não recebeu o clima fixado", z)
		}
	}
	c.AddHours(3)
	c.Advance(400 * 3)
	if c.GetZoneWeather(ZoneForest) != WeatherBlizzard {
		t.Fatal("clima fixado pelo dev não deveria ser sorteado novamente")
	}
	if c.CycleWeather() != WeatherThunderstorm {
		t.Fatal("ciclo deveria avançar para o próximo clima")
	}
	if len(WeatherNames) != int(WeatherCount) {
		t.Fatal("nomes de clima incompletos")
	}
}
