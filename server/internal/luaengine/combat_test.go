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

	// 1. Dano Base: Espadachim (28) de dia, Tier 1, Level 1
	dmg, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassSwordsman,
		protocol.ActionBasicAttack,
		100.0,
		12, // 12h (Dia)
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
	)
	if dmg < 28 {
		t.Fatalf("esperava pelo menos 28 de dano para Espadachim, obteve %d", dmg)
	}

	// 2. Skill Especial Q (ActionType 3): 28 * 1.75 = 49
	dmgSkillQ, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassSwordsman,
		protocol.ActionSkillQ,
		100.0,
		12, // Dia
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
	)
	if dmgSkillQ < 49 {
		t.Fatalf("esperava pelo menos 49 de dano na Skill Q do Espadachim (28 * 1.75), obteve %d", dmgSkillQ)
	}

	// 3. Skill R (ActionType 4): 28 * 1.90 = 53
	dmgSkillR, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassSwordsman,
		protocol.ActionSkillR,
		100.0,
		12,
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
	)
	if dmgSkillR < 53 {
		t.Fatalf("esperava pelo menos 53 de dano na Skill R do Espadachim (28 * 1.90), obteve %d", dmgSkillR)
	}

	// 4. Skill F (ActionType 5 - Ultimate): 28 * 2.40 = 67
	dmgSkillF, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassSwordsman,
		protocol.ActionSkillF,
		100.0,
		12,
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
	)
	if dmgSkillF < 67 {
		t.Fatalf("esperava pelo menos 67 de dano na Skill F do Espadachim (28 * 2.40), obteve %d", dmgSkillF)
	}

	// 5. Novas Classes: Ferreiro (5: 32 base) e Alquimista (6: 26 base)
	dmgBlacksmith, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassBlacksmith,
		protocol.ActionBasicAttack,
		100.0,
		12,
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
	)
	if dmgBlacksmith < 32 {
		t.Fatalf("esperava pelo menos 32 de dano para Ferreiro, obteve %d", dmgBlacksmith)
	}

	// Ferreiro com Buff de Afiação de Combate (+25% dano): 32 * 1.25 = 40
	dmgBuffed, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassBlacksmith,
		protocol.ActionBasicAttack,
		100.0,
		12,
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		1, // Buff ativo!
	)
	if dmgBuffed < 40 {
		t.Fatalf("esperava pelo menos 40 de dano com Afiação de Combate, obteve %d", dmgBuffed)
	}

	// 6. Classes Secretas: Ceifador (7: 42 base) e Artífice (8: 38 base) no Tier 5 Única (2.15x)
	// 42 * 2.15 = 90
	dmgReaper, _ := engine.CallCalculateDamage(
		protocol.RaceDhampir,
		protocol.ClassEclipseReaper,
		protocol.ActionBasicAttack,
		100.0,
		12,
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierUnique,
		1,
		0,
	)
	if dmgReaper < 90 {
		t.Fatalf("esperava pelo menos 90 de dano para Ceifador no Tier 5 (42 * 2.15), obteve %d", dmgReaper)
	}

	// 7. Lua de Sangue (fase 8) à noite (22h) com Dhampir (5):
	// Espadachim = 28. +25% global e +40% Dhampir = 28 * (1 + 0.25 + 0.40) = 28 * 1.65 = 46.2 (~46)
	dmgBlood, _ := engine.CallCalculateDamage(
		protocol.RaceDhampir,
		protocol.ClassSwordsman,
		protocol.ActionBasicAttack,
		100.0,
		22, // Noite
		world.MoonPhaseBloodMoon,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
	)
	if dmgBlood < 46 {
		t.Fatalf("esperava dano amplificado para Dhampir sob Lua de Sangue (>= 46), obteve %d", dmgBlood)
	}

	// 8. Escala de Atributos: STR=15 (+10 acima de 5 -> +30% de dano melee para Espadachim)
	// Base 28 * 1.30 = 36.4 -> 36
	dmgSTR, _ := engine.CallCalculateDamage(
		protocol.RaceValerian,
		protocol.ClassSwordsman,
		protocol.ActionBasicAttack,
		100.0,
		12,
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
		15, 5, 5, 5, 5, 5, // STR=15, DEX=5, INT=5, SPI=5, MAS=5, LCK=5
	)
	if dmgSTR < 36 {
		t.Fatalf("esperava pelo menos 36 de dano para Espadachim com STR=15, obteve %d", dmgSTR)
	}

	// 9. Licantropo Primordial (RaceID = 6): +30% de dano físico permanente
	// Base 28 * 1.30 = 36.4 -> 36
	dmgLycan, _ := engine.CallCalculateDamage(
		protocol.RacePrimordialLycanthrope,
		protocol.ClassSwordsman,
		protocol.ActionBasicAttack,
		100.0,
		12,
		world.MoonPhaseWaxingCrescent,
		world.WeatherClear,
		protocol.TierCommon,
		1,
		0,
	)
	if dmgLycan < 36 {
		t.Fatalf("esperava pelo menos 36 de dano permanente para Licantropo Primordial, obteve %d", dmgLycan)
	}
}

func TestAutopsyLuaPrecisionAndPericia(t *testing.T) {
	clock := world.NewWorldClock(12.0)
	engine := NewEngine(clock)
	defer engine.Close()

	combatDir := FindCombatScriptsDir()
	autopsyScript := filepath.Join(combatDir, "autopsy.lua")

	if err := engine.LoadAutopsyScript(autopsyScript); err != nil {
		t.Fatalf("falha ao carregar autopsy.lua: %v", err)
	}

	// 1. Zona Verde Natural: Precisão 0.92, MAS=0, LCK=0 -> Tier 1 (Perfeito)
	tierGreen := engine.CallCalculateAutopsyResult(0, 0, 1, 0.92)
	if tierGreen != 1 {
		t.Fatalf("esperava Tier 1 (Perfeito) para precisão 0.92, obteve %d", tierGreen)
	}

	// 2. Zona Amarela sem MAS: Precisão 0.70, MAS=0, LCK=0 -> Tier 2 (Comum)
	tierYellow := engine.CallCalculateAutopsyResult(0, 0, 1, 0.70)
	if tierYellow != 2 {
		t.Fatalf("esperava Tier 2 (Comum) para precisão 0.70 com MAS=0, obteve %d", tierYellow)
	}

	// 3. Efeito da Perícia (MAS): MAS=10 amplia a margem de erro da Zona Verde em +25% (0.025 * 10)
	// Limiar verde de 0.85 cai para 0.60. Logo, precisão 0.70 agora deve ser Zona Verde (Tier 1)!
	tierMAS := engine.CallCalculateAutopsyResult(10, 0, 1, 0.70)
	if tierMAS != 1 {
		t.Fatalf("esperava Tier 1 (Perfeito) para precisão 0.70 com MAS=10 (Margem +25%%), obteve %d", tierMAS)
	}

	// 4. Zona Vermelha: Precisão 0.20, MAS=0, LCK=0 -> Tier 3 (Destruído / Lixo Orgânico)
	tierRed := engine.CallCalculateAutopsyResult(0, 0, 1, 0.20)
	if tierRed != 3 {
		t.Fatalf("esperava Tier 3 (Destruído) para precisão 0.20, obteve %d", tierRed)
	}

	// 5. Tempo Expirado / Erro de clique: Precisão 0.0 -> Tier 3 (Destruído)
	tierTimeout := engine.CallCalculateAutopsyResult(10, 10, 1, 0.0)
	if tierTimeout != 3 {
		t.Fatalf("esperava Tier 3 (Destruído) para precisão 0.0 (Timeout), obteve %d", tierTimeout)
	}
}

