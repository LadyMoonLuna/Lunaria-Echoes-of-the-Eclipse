package luaengine

import (
	"os"
	"path/filepath"
	"testing"

	"lunaria/server/internal/world"
)

func TestLuaEngineAndGarrickScript(t *testing.T) {
	// Cria arquivo temporário de script para teste
	tmpDir := t.TempDir()
	scriptPath := filepath.Join(tmpDir, "test_garrick.lua")

	luaCode := `
local current_routine = "none"

function OnTick(delta_time, world_hour)
    if world_hour >= 6 and world_hour <= 17 then
        current_routine = "forge"
        npc_set_state(2)
        npc_move_to(8.0, 8.0, 3.0)
        npc_say("Forja ativa!")
    else
        current_routine = "tavern"
        npc_set_state(3)
        npc_move_to(-8.0, -6.0, 2.2)
        npc_say("Taverna ativa!")
    end
end

function OnPlayerApproach(player_id, distance)
    npc_say("Ola aproximou: " .. tostring(player_id))
end

function OnPlayerInteract(player_id, world_hour)
    npc_say("Interagiu: " .. tostring(player_id))
end
`
	if err := os.WriteFile(scriptPath, []byte(luaCode), 0644); err != nil {
		t.Fatalf("falha ao escrever script de teste: %v", err)
	}

	clock := world.NewWorldClock(10.0) // 10h da manhã (diurno)
	engine := NewEngine(clock)
	defer engine.Close()

	var lastSaid string
	sayCallback := func(npcID uint32, message string) {
		lastSaid = message
	}

	npc := world.NewNPC(1, "Garrick", 0, 0, 0, scriptPath, clock, sayCallback)
	defer npc.Close()

	if err := engine.BindNPC(npc); err != nil {
		t.Fatalf("erro ao vincular NPC com Lua: %v", err)
	}

	// 1. Testa OnTick no horário diurno (10h)
	if err := CallOnTick(npc, clock.GetCurrentHour()); err != nil {
		t.Fatalf("erro ao chamar OnTick: %v", err)
	}
	if npc.State != 2 {
		t.Fatalf("esperava estado 2 (Forja), obteve %d", npc.State)
	}
	if npc.TargetX != 8.0 || npc.TargetZ != 8.0 || npc.MoveSpeed != 3.0 {
		t.Fatalf("alvo de movimento incorreto: (%f, %f) a %f m/s", npc.TargetX, npc.TargetZ, npc.MoveSpeed)
	}
	if lastSaid != "Forja ativa!" {
		t.Fatalf("fala incorreta: %s", lastSaid)
	}

	// 2. Testa OnPlayerApproach
	if err := CallOnPlayerApproach(npc, 42, 3.5, 1); err != nil {
		t.Fatalf("erro ao chamar OnPlayerApproach: %v", err)
	}
	if lastSaid != "Ola aproximou: 42" {
		t.Fatalf("fala de aproximação incorreta: %s", lastSaid)
	}

	// 3. Testa OnPlayerInteract
	if err := CallOnPlayerInteract(npc, 42, 10, 1, 1); err != nil {
		t.Fatalf("erro ao chamar OnPlayerInteract: %v", err)
	}
	if lastSaid != "Interagiu: 42" {
		t.Fatalf("fala de interação incorreta: %s", lastSaid)
	}

	// 4. Testa OnTick no horário noturno (22h)
	if err := CallOnTick(npc, 22); err != nil {
		t.Fatalf("erro ao chamar OnTick noturno: %v", err)
	}
	if npc.State != 3 {
		t.Fatalf("esperava estado 3 (Taverna), obteve %d", npc.State)
	}
	if npc.TargetX != -8.0 || npc.TargetZ != -6.0 || npc.MoveSpeed != 2.2 {
		t.Fatalf("alvo de taverna incorreto: (%f, %f) a %f m/s", npc.TargetX, npc.TargetZ, npc.MoveSpeed)
	}
}
