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

func TestSecretClasses10to15CombatMultipliers(t *testing.T) {
	clock := world.NewWorldClock(12.0)
	engine := NewEngine(clock)
	defer engine.Close()

	combatDir := FindCombatScriptsDir()
	combatScript := filepath.Join(combatDir, "combat.lua")

	if err := engine.LoadCombatScript(combatScript); err != nil {
		t.Fatalf("falha ao carregar combat.lua: %v", err)
	}

	// 1. Testa os 6 Tiers de Raridade no Dançarino Astral (Base 40)
	tierMults := map[uint8]float64{
		protocol.TierCommon:    1.0,
		protocol.TierUncommon:  1.20,
		protocol.TierRare:      1.45,
		protocol.TierEpic:      1.75,
		protocol.TierUnique:    2.15,
		protocol.TierLegendary: 2.60,
	}

	for tier, mult := range tierMults {
		dmg, isCrit := engine.CallCalculateDamage(
			protocol.RaceValerian,
			protocol.ClassAstralDancer,
			protocol.ActionBasicAttack,
			100.0,
			12, // Dia
			world.MoonPhaseWaxingCrescent,
			world.WeatherClear,
			tier,
			1,
			0,
		)
		expected := int(40.0 * mult)
		if isCrit == 1 {
			expected = int(float64(expected) * 1.50)
		}
		if int(dmg) < expected-3 || int(dmg) > expected+3 {
			t.Fatalf("Dançarino Astral no Tier %d deveria causar ~%d de dano (crit: %d), obteve %d", tier, expected, isCrit, dmg)
		}
	}

	// 2. Testa Multiplicadores de Skills Q, R, F para as Classes 10 a 15 no Tier 1
	// Classe 10 (Dançarino Astral, Base 40): Q=2.0x (80), R=1.8x (72), F=3.0x (120)
	dmg10Q, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassAstralDancer, protocol.ActionSkillQ, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg10Q < 80 {
		t.Fatalf("Dançarino Astral Q deveria causar >= 80, obteve %d", dmg10Q)
	}
	dmg10F, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassAstralDancer, protocol.ActionSkillF, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg10F < 120 {
		t.Fatalf("Dançarino Astral F deveria causar >= 120, obteve %d", dmg10F)
	}

	// Classe 11 (Inquisidor das Cinzas, Base 38): Q=2.2x (~83.6), F=3.2x (~121.6)
	dmg11Q, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassAshInquisitor, protocol.ActionSkillQ, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg11Q < 83 {
		t.Fatalf("Inquisidor das Cinzas Q deveria causar >= 83, obteve %d", dmg11Q)
	}
	dmg11F, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassAshInquisitor, protocol.ActionSkillF, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg11F < 121 {
		t.Fatalf("Inquisidor das Cinzas F deveria causar >= 121, obteve %d", dmg11F)
	}

	// Passiva Inquisidor com 20% de HP (faltando 80% HP -> +48% dano bônus)
	dmg11LowHP, critLow := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassAshInquisitor, protocol.ActionBasicAttack, 20.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	dmg11FullHP, critFull := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassAshInquisitor, protocol.ActionBasicAttack, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	baseLow := float64(dmg11LowHP)
	if critLow == 1 {
		baseLow /= 1.5
	}
	baseFull := float64(dmg11FullHP)
	if critFull == 1 {
		baseFull /= 1.5
	}
	if baseLow <= baseFull {
		t.Fatalf("Inquisidor das Cinzas com 20%% HP deveria causar mais dano base que com 100%% HP (LowBase: %.1f, FullBase: %.1f)", baseLow, baseFull)
	}

	// Classe 12 (Necromante de Ossos, Base 34): Q=2.0x (68), F=3.0x (102)
	dmg12Q, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassBoneNecromancer, protocol.ActionSkillQ, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg12Q < 68 {
		t.Fatalf("Necromante de Ossos Q deveria causar >= 68, obteve %d", dmg12Q)
	}
	dmg12F, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassBoneNecromancer, protocol.ActionSkillF, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg12F < 102 {
		t.Fatalf("Necromante de Ossos F deveria causar >= 102, obteve %d", dmg12F)
	}

	// Classe 13 (Domador Primordial, Base 39): Passiva Espírito Alfa (+25% dano base: 39 * 1.25 = 48.75)
	dmg13Basic, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassPrimordialTamer, protocol.ActionBasicAttack, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg13Basic < 48 {
		t.Fatalf("Domador Primordial básico com Espírito Alfa deveria causar >= 48, obteve %d", dmg13Basic)
	}

	// Classe 14 (Cavaleiro da Ruptura, Base 44): Q=1.9x (~83.6), F=2.8x (~123.2)
	dmg14Q, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassRiftKnight, protocol.ActionSkillQ, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg14Q < 83 {
		t.Fatalf("Cavaleiro da Ruptura Q deveria causar >= 83, obteve %d", dmg14Q)
	}
	dmg14F, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassRiftKnight, protocol.ActionSkillF, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	if dmg14F < 123 {
		t.Fatalf("Cavaleiro da Ruptura F deveria causar >= 123, obteve %d", dmg14F)
	}

	// Classe 15 (Arauto da Tempestade, Base 36): Q=2.1x (~75.6), F=3.1x (~111.6)
	dmg15Clear, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassStormHerald, protocol.ActionBasicAttack, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierCommon, 1, 0)
	dmg15Rain, _ := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassStormHerald, protocol.ActionBasicAttack, 100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherRain, protocol.TierCommon, 1, 0)
	if dmg15Rain <= dmg15Clear {
		t.Fatalf("Arauto da Tempestade na chuva (+35%%) deveria causar mais dano que em clima limpo (Chuva: %d, Limpo: %d)", dmg15Rain, dmg15Clear)
	}
}

func TestSecretVariantSkillMultipliers(t *testing.T) {
	clock := world.NewWorldClock(12.0)
	engine := NewEngine(clock)
	defer engine.Close()
	if err := engine.LoadCombatScript(filepath.Join(FindCombatScriptsDir(), "combat.lua")); err != nil {
		t.Fatalf("falha ao carregar combat.lua: %v", err)
	}
	// Espadachim Rúnico (base 34, +15% Lâmina Elemental): F = 2.8x. Compara só resultados sem crítico.
	nonCrit := func(action uint8) uint16 {
		for i := 0; i < 200; i++ {
			dmg, crit := engine.CallCalculateDamage(protocol.RaceValerian, protocol.ClassRunicSpellblade, action,
				100.0, 12, world.MoonPhaseWaxingCrescent, world.WeatherClear, protocol.TierRare, 1, 0)
			if crit == 0 {
				return dmg
			}
		}
		t.Fatal("nenhum resultado sem crítico em 200 tentativas")
		return 0
	}
	basic, ult := nonCrit(protocol.ActionBasicAttack), nonCrit(protocol.ActionSkillF)
	if basic == 0 || float64(ult) < float64(basic)*2.6 || float64(ult) > float64(basic)*3.0 {
		t.Fatalf("o Cometa da Espada Arcana deveria causar ~2.8x o básico: básico %d, F %d", basic, ult)
	}
}
