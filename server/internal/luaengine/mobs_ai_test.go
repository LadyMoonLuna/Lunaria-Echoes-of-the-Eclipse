package luaengine

import (
	"path/filepath"
	"testing"

	"lunaria/server/internal/world"
)

func TestMobAIScriptExecution(t *testing.T) {
	clock := world.NewWorldClock(16.0)
	engine := NewEngine(clock)
	defer engine.Close()

	mobManager := world.NewMobManager()

	mobsDir := FindMobsScriptsDir()
	scriptPath := filepath.Join(mobsDir, "mobs_ai.lua")

	attackCalled := false
	var attackedPlayer uint32
	var attackDamage uint16

	telegraphCalled := false
	var telegraphRadius float32

	onAttack := func(mobID, playerID uint32, damage uint16) {
		attackCalled = true
		attackedPlayer = playerID
		attackDamage = damage
	}

	onTelegraph := func(sourceID uint32, x, z, radius float32, durationMs uint16) {
		telegraphCalled = true
		telegraphRadius = radius
	}

	onAOEDamage := func(sourceID uint32, x, z, radius float32, damage uint16) {
	}

	onSay := func(mobID uint32, text string) {
	}

	err := engine.LoadMobAIScript(scriptPath, mobManager, onAttack, onTelegraph, onAOEDamage, onSay)
	if err != nil {
		t.Fatalf("erro ao carregar script mobs_ai.lua: %v", err)
	}

	// 1. Testa Lobo da Bruma (201) mordendo jogador próximo
	wolf := mobManager.GetMob(201)
	wolf.PosX = 10.0
	wolf.PosZ = 10.0
	engine.UpdateMobAI(wolf, 1, 1.5, 10.5, 10.0, world.MoonPhaseWaxingCrescent, 0.05)

	if !attackCalled || attackedPlayer != 1 || attackDamage != 18 {
		t.Fatalf("esperava ataque do lobo: attackCalled=%v, player=%d, dmg=%d", attackCalled, attackedPlayer, attackDamage)
	}

	// 2. Testa Executor de Ferro (206) disparando telégrafo, entrando em vulnerabilidade e recuperando-se
	enforcer := mobManager.GetMob(206)
	enforcer.PosX = 0.0
	enforcer.PosZ = 22.0
	engine.UpdateMobAI(enforcer, 1, 4.0, 0.0, 20.0, world.MoonPhaseWaxingCrescent, 0.05)

	if !telegraphCalled || telegraphRadius != 4.0 {
		t.Fatalf("esperava telegrafo do executor: telegraphCalled=%v, radius=%.2f", telegraphCalled, telegraphRadius)
	}

	if enforcer.State != 2 {
		t.Fatalf("esperava Executor em State = 2 (Carregando), obteve %d", enforcer.State)
	}

	// 3. Simula avanço de 1.6s para detonar o impacto do AoE e entrar em vulnerabilidade (State = 4)
	engine.UpdateMobAI(enforcer, 1, 4.0, 0.0, 20.0, world.MoonPhaseWaxingCrescent, 1.6)
	if enforcer.State != 4 {
		t.Fatalf("esperava Executor em State = 4 (Vulneravel apos impacto), obteve %d", enforcer.State)
	}

	// 4. Durante os primeiros 1.0s de vulnerabilidade, deve permanecer em State = 4
	engine.UpdateMobAI(enforcer, 1, 4.0, 0.0, 20.0, world.MoonPhaseWaxingCrescent, 1.0)
	if enforcer.State != 4 {
		t.Fatalf("esperava Executor ainda em State = 4 apos 1.0s, obteve %d", enforcer.State)
	}

	// 5. Apos mais 1.1s (total 2.1s > 2.0s), a vulnerabilidade DEVE expirar e voltar para Perseguindo (State = 1)
	engine.UpdateMobAI(enforcer, 1, 4.0, 0.0, 20.0, world.MoonPhaseWaxingCrescent, 1.1)
	if enforcer.State != 1 {
		t.Fatalf("esperava Executor recuperado em State = 1 (Perseguindo), obteve %d", enforcer.State)
	}
}
