package luaengine

import (
	"path/filepath"
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func TestCombatLuaCalculations(t *testing.T) {
	clock := world.NewWorldClock(12.0)
	engine := NewEngine(clock)
	defer engine.Close()

	combatDir := FindCombatScriptsDir()
	combatScript := filepath.Join(combatDir, "combat.lua")

	if err := engine.LoadCombatScript(combatScript); err != nil {
		t.Fatalf("falha ao carregar combat.lua: %v", err)
	}

	// 1. Dano Base: Espadachim (28) de dia
	dmg, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassSwordsman,
		protocol.ActionBasicAttack,
		100.0,
		12, // 12h (Dia)
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
	)
	if dmg < 28 {
		t.Fatalf("esperava pelo menos 28 de dano para Espadachim, obteve %d", dmg)
	}

	// 2. Skill Especial (ActionType 3): 28 * 1.75 = 49
	dmgSkill, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassSwordsman,
		protocol.ActionSpecialSkill,
		100.0,
		12, // Dia
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
	)
	if dmgSkill < 49 {
		t.Fatalf("esperava pelo menos 49 de dano na Skill do Espadachim (28 * 1.75), obteve %d", dmgSkill)
	}

	// 3. Lua de Sangue (fase 8) à noite (22h) com Dhampir (5):
	// Espadachim = 28. +25% global e +40% Dhampir = 28 * (1 + 0.25 + 0.40) = 28 * 1.65 = 46.2 (~46)
	dmgBlood, _ := engine.CallCalculateDamage(
		protocol.RaceDhampir,
		protocol.ClassSwordsman,
		protocol.ActionBasicAttack,
		100.0,
		22, // Noite
		world.MoonPhaseBloodMoon,
		world.WeatherClear,
	)
	if dmgBlood < 46 {
		t.Fatalf("esperava dano amplificado para Dhampir sob Lua de Sangue (>= 46), obteve %d", dmgBlood)
	}
}
