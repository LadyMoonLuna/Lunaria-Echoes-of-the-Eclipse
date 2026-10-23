package luaengine

import (
	"os"
	"path/filepath"
	"strings"
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

func TestLivingNPCScripts(t *testing.T) {
	clock := world.NewWorldClock(12.0)
	engine := NewEngine(clock)
	defer engine.Close()

	scriptsDir := FindNPCScriptsDir()

	// 1. Lyra, a Alquimista (103)
	var lyraSaid string
	lyra := world.NewNPC(103, "Lyra, a Alquimista", 10.0, 0.0, -10.0, filepath.Join(scriptsDir, "lyra.lua"), clock, func(id uint32, msg string) {
		lyraSaid = msg
	})
	defer lyra.Close()

	if err := engine.BindNPC(lyra); err != nil {
		t.Fatalf("falha ao vincular lyra: %v", err)
	}

	// De dia (10h): Primeiro waypoint para o Laboratório respeitando o mapa expandido
	_ = CallOnTick(lyra, 10)
	if lyra.TargetX != -15.0 || lyra.TargetZ != 10.0 {
		t.Errorf("esperava primeiro waypoint do laboratorio (-15, 10), obteve (%f, %f)", lyra.TargetX, lyra.TargetZ)
	}

	// Interação com Transmutador (classe 6) ou alta perícia MAS (12)
	_ = CallOnPlayerInteract(lyra, 1, 10, 1, 6, 5)
	if lyraSaid == "" || !strings.Contains(lyraSaid, "Poção de Sangue Lupino") {
		t.Errorf("fala de alquimia inesperada: %s", lyraSaid)
	}

	// De noite (20h): Primeiro waypoint para Taverna/Descanso
	_ = CallOnTick(lyra, 20)
	if lyra.TargetX != 20.0 || lyra.TargetZ != -10.0 {
		t.Errorf("esperava primeiro waypoint da noite (20, -10), obteve (%f, %f)", lyra.TargetX, lyra.TargetZ)
	}

	// 2. Varis, o Contrabandista (104)
	var varisSaid string
	varis := world.NewNPC(104, "Varis, o Contrabandista", 0.0, 0.0, 10.0, filepath.Join(scriptsDir, "shadow_merchant.lua"), clock, func(id uint32, msg string) {
		varisSaid = msg
	})
	defer varis.Close()

	if err := engine.BindNPC(varis); err != nil {
		t.Fatalf("falha ao vincular varis: %v", err)
	}

	// De dia (12h): Deve ficar inativo e fora de serviço
	_ = CallOnTick(varis, 12)
	if varis.GetActive() {
		t.Errorf("esperava Varis inativo de dia")
	}
	snap := varis.ToSnapshot()
	if snap.State != 255 || snap.PosY != -100.0 {
		t.Errorf("esperava snapshot inativo (255, -100), obteve state=%d, y=%f", snap.State, snap.PosY)
	}

	// De noite (22h): Deve ficar ativo no Mercado Negro (Zone 7 em 0, 10)
	_ = CallOnTick(varis, 22)
	if !varis.GetActive() {
		t.Errorf("esperava Varis ativo de noite")
	}
	if varis.PosX != 0.0 || varis.PosZ != 10.0 {
		t.Errorf("esperava Varis no Mercado Negro em (0, 10) de noite, obteve (%f, %f)", varis.PosX, varis.PosZ)
	}
	// Reatividade com Sangrael (raça 5) e Cinerion (raça 7)
	_ = CallOnPlayerInteract(varis, 1, 22, 5, 1, 5)
	if !strings.Contains(varisSaid, "Sangrael") {
		t.Errorf("esperava reatividade com Sangrael, obteve: %s", varisSaid)
	}
	_ = CallOnPlayerInteract(varis, 1, 22, 7, 1, 5)
	if !strings.Contains(varisSaid, "Cinerion") {
		t.Errorf("esperava reatividade com Cinerion, obteve: %s", varisSaid)
	}

	// 3. Guarda da Patrulha Real (105)
	var guardSaid string
	guard := world.NewNPC(105, "Capitão Randel", 0.0, 0.0, 24.0, filepath.Join(scriptsDir, "guard.lua"), clock, func(id uint32, msg string) {
		guardSaid = msg
	})
	defer guard.Close()

	if err := engine.BindNPC(guard); err != nil {
		t.Fatalf("falha ao vincular guard: %v", err)
	}

	// Aproximação com arma em riste (is_armed = true)
	_ = CallOnPlayerApproach(guard, 1, 2.0, 1, true)
	if !strings.Contains(guardSaid, "Mantenha a linha, viajante. Sem problemas na nossa vila.") {
		t.Errorf("aviso de guarda inesperado para armado: %s", guardSaid)
	}

	// Aproximação de raça Varkai (raça 4)
	_ = CallOnPlayerApproach(guard, 1, 2.0, 4, false)
	if !strings.Contains(guardSaid, "Mantenha a linha, viajante. Sem problemas na nossa vila.") {
		t.Errorf("aviso de guarda inesperado para Varkai: %s", guardSaid)
	}

	// Aproximação de raça Sangrael (raça 5)
	_ = CallOnPlayerApproach(guard, 1, 2.0, 5, false)
	if !strings.Contains(guardSaid, "Mantenha a linha, viajante. Sem problemas na nossa vila.") {
		t.Errorf("aviso de guarda inesperado para Sangrael: %s", guardSaid)
	}
}

func TestNPCFriendshipAndClassRestrictionsLua(t *testing.T) {
	clock := world.NewWorldClock(12.0)
	engine := NewEngine(clock)
	defer engine.Close()

	scriptsDir := FindNPCScriptsDir()

	// 1. Garrick (100) - Regra de exclusividade e receita secreta
	var garrickSaid string
	garrick := world.NewNPC(100, "Garrick, o Ferreiro", 10.0, 0.0, 9.0, filepath.Join(scriptsDir, "garrick.lua"), clock, func(id uint32, msg string) {
		garrickSaid = msg
	})
	defer garrick.Close()

	if err := engine.BindNPC(garrick); err != nil {
		t.Fatalf("falha ao vincular garrick: %v", err)
	}

	// Transmutador (Classe 6) tentando interagir com Garrick: bloqueado com desprezo
	_ = CallOnPlayerInteract(garrick, 1, 12, 1, 6, 5, 0)
	if !strings.Contains(garrickSaid, "misturando fumacinhas em frascos") {
		t.Errorf("esperava recusa ao Transmutador por Garrick, obteve: %s", garrickSaid)
	}

	// Forjador de Estrelas (Classe 5) com Afiança Nível 1 (< 3): reconhecido como colega
	_ = CallOnPlayerInteract(garrick, 1, 12, 1, 5, 5, 1)
	if !strings.Contains(garrickSaid, "irmão da bigorna") {
		t.Errorf("esperava saudação de colega ferreiro, obteve: %s", garrickSaid)
	}

	// Forjador de Estrelas (Classe 5) com Afiança Nível 3+: ensina o Malho de Batalha Rúnico
	_ = CallOnPlayerInteract(garrick, 1, 12, 1, 5, 5, 3)
	if !strings.Contains(garrickSaid, "Malho de Batalha Rúnico") {
		t.Errorf("esperava ensinamento do Malho de Batalha Rúnico, obteve: %s", garrickSaid)
	}

	// 2. Lyra (103) - Restrição de Ferreiros e Segredo das 03:00 da manhã
	var lyraSaid string
	lyra := world.NewNPC(103, "Lyra, a Alquimista", 10.0, 0.0, -6.5, filepath.Join(scriptsDir, "lyra.lua"), clock, func(id uint32, msg string) {
		lyraSaid = msg
	})
	defer lyra.Close()

	if err := engine.BindNPC(lyra); err != nil {
		t.Fatalf("falha ao vincular lyra: %v", err)
	}

	// Forjador de Estrelas (Classe 5) com Afiança Nível 1 (<= 2): comércio fechado
	_ = CallOnPlayerInteract(lyra, 1, 12, 1, 5, 5, 1)
	if !strings.Contains(lyraSaid, "luvas sujas") {
		t.Errorf("esperava recusa ao ferreiro bruto por Lyra, obteve: %s", lyraSaid)
	}

	// Jogador com Afiança Nível 3+: Revela a história do mestre traído jogado nos esgotos às 03:00
	_ = CallOnPlayerInteract(lyra, 1, 12, 1, 1, 5, 3)
	if !strings.Contains(lyraSaid, "03:00 da manhã") || !strings.Contains(lyraSaid, "esgotos") {
		t.Errorf("esperava segredo do mestre traído às 03:00 da manhã, obteve: %s", lyraSaid)
	}
}
