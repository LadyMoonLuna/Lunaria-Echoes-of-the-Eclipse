package luaengine

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func avgDamage(e *Engine, race, class, tier uint8) float64 {
	total, n := 0.0, 0
	for h := 0; h < 24; h += 2 {
		for moon := uint8(0); moon < 8; moon++ {
			for _, act := range []uint8{protocol.ActionBasicAttack, protocol.ActionBasicAttack, protocol.ActionBasicAttack, protocol.ActionSkillQ, protocol.ActionSkillF} {
				for k := 0; k < 3; k++ {
					d, _ := e.CallCalculateDamage(race, class, act, 80, h, moon, world.WeatherClear, tier, 30, 0)
					total += float64(d)
					n++
				}
			}
		}
	}
	return total / float64(n)
}

// TestBalanceReport gera o relatório de dano médio por raça e classe: BALANCE=arquivo.txt go test -run BalanceReport ./internal/luaengine
func TestBalanceReport(t *testing.T) {
	if os.Getenv("BALANCE") == "" {
		t.Skip()
	}
	e := NewEngine(world.NewWorldClock(12))
	defer e.Close()
	if err := e.LoadCombatScript(filepath.Join(FindCombatScriptsDir(), "combat.lua")); err != nil {
		t.Fatal(err)
	}
	f, _ := os.Create(os.Getenv("BALANCE"))
	defer f.Close()
	fmt.Fprintln(f, "RACES (classe 1, tier 3)")
	for r := uint8(1); r <= 47; r++ {
		fmt.Fprintf(f, "R %d %.1f\n", r, avgDamage(e, r, 1, 3))
	}
	fmt.Fprintln(f, "CLASSES (raça 1)")
	for c := uint8(1); c <= 39; c++ {
		tier := uint8(3)
		if c >= 19 {
			tier = 5
		}
		if c >= 31 && c <= 34 {
			tier = 6
		}
		fmt.Fprintf(f, "C %d %.1f\n", c, avgDamage(e, 1, c, tier))
	}
}
