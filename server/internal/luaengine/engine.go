package luaengine

import (
	"fmt"
	"log"
	"math"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/yuin/gopher-lua"
	"lunaria/server/internal/world"
)

// Engine gerencia a inicialização das VMs Lua dos NPCs, combate e o sistema de Hot-Reload.
type Engine struct {
	mu          sync.RWMutex
	clock       *world.WorldClock
	watcher     *fsnotify.Watcher
	watchedDirs []string
	npcByScript map[string]*world.NPC
	lastReload  map[string]time.Time
	stopChan    chan struct{}

	combatMu         sync.RWMutex
	combatState      *lua.LState
	combatScriptPath string

	mobAIMu         sync.RWMutex
	mobAIState      *lua.LState
	mobAIScriptPath string
	mobManager      *world.MobManager
	onMobAttack     func(mobID, playerID uint32, damage uint16)
	onTelegraph     func(sourceID uint32, x, z, radius float32, durationMs uint16)
	onAOEDamage     func(sourceID uint32, x, z, radius float32, damage uint16)
	onMobSay        func(mobID uint32, text string)
	currentDelta    float32
}

// NewEngine cria uma nova instância do gerenciador de scripts Lua.
func NewEngine(clock *world.WorldClock) *Engine {
	return &Engine{
		clock:       clock,
		npcByScript: make(map[string]*world.NPC),
		lastReload:  make(map[string]time.Time),
		stopChan:    make(chan struct{}),
	}
}

// BindNPC inicializa a VM Lua dedicada do NPC e registra as funções da API Go.
func (e *Engine) BindNPC(npc *world.NPC) error {
	L := lua.NewState()

	// 1. Registro da API Go para dentro do Lua
	// npc_move_to(x, z, speed)
	L.SetGlobal("npc_move_to", L.NewFunction(func(L *lua.LState) int {
		x := float32(L.CheckNumber(1))
		z := float32(L.CheckNumber(2))
		speed := float32(L.CheckNumber(3))
		npc.SetTarget(x, z, speed)
		return 0
	}))

	// npc_say(text)
	L.SetGlobal("npc_say", L.NewFunction(func(L *lua.LState) int {
		text := L.CheckString(1)
		npc.Say(text)
		return 0
	}))

	// npc_set_state(state_int)
	L.SetGlobal("npc_set_state", L.NewFunction(func(L *lua.LState) int {
		state := uint8(L.CheckInt(1))
		npc.SetState(state)
		return 0
	}))

	// get_world_hour()
	L.SetGlobal("get_world_hour", L.NewFunction(func(L *lua.LState) int {
		hour := e.clock.GetCurrentHour()
		L.Push(lua.LNumber(hour))
		return 1
	}))

	// get_moon_phase()
	L.SetGlobal("get_moon_phase", L.NewFunction(func(L *lua.LState) int {
		phase := e.clock.GetMoonPhase()
		L.Push(lua.LNumber(phase))
		return 1
	}))

	// get_weather()
	L.SetGlobal("get_weather", L.NewFunction(func(L *lua.LState) int {
		weather := e.clock.GetWeather()
		L.Push(lua.LNumber(weather))
		return 1
	}))

	// 2. Carrega o script inicial do NPC
	if err := L.DoFile(npc.ScriptPath); err != nil {
		L.Close()
		return fmt.Errorf("falha ao carregar script lua '%s': %w", npc.ScriptPath, err)
	}

	npc.LuaMu.Lock()
	npc.LuaState = L
	npc.LuaMu.Unlock()

	// Registra para o watcher de Hot-Reload
	baseName := strings.ToLower(filepath.Base(npc.ScriptPath))
	e.mu.Lock()
	e.npcByScript[baseName] = npc
	e.mu.Unlock()

	log.Printf("[LUA] Script '%s' vinculado com sucesso ao NPC '%s' (ID %d)\n", filepath.Base(npc.ScriptPath), npc.Name, npc.ID)
	return nil
}

// LoadCombatScript carrega o script autoritativo de combate (combat.lua).
func (e *Engine) LoadCombatScript(scriptPath string) error {
	L := lua.NewState()

	L.SetGlobal("get_world_hour", L.NewFunction(func(L *lua.LState) int {
		L.Push(lua.LNumber(e.clock.GetCurrentHour()))
		return 1
	}))
	L.SetGlobal("get_moon_phase", L.NewFunction(func(L *lua.LState) int {
		L.Push(lua.LNumber(e.clock.GetMoonPhase()))
		return 1
	}))
	L.SetGlobal("get_weather", L.NewFunction(func(L *lua.LState) int {
		L.Push(lua.LNumber(e.clock.GetWeather()))
		return 1
	}))

	if err := L.DoFile(scriptPath); err != nil {
		L.Close()
		return fmt.Errorf("falha ao carregar script de combate '%s': %w", scriptPath, err)
	}

	e.combatMu.Lock()
	if e.combatState != nil {
		e.combatState.Close()
	}
	e.combatState = L
	e.combatScriptPath = scriptPath
	e.combatMu.Unlock()

	log.Printf("[COMBATE] Script de combate carregado com sucesso: %s\n", filepath.Base(scriptPath))
	return nil
}

// ReloadCombatScript recarrega o script de combate após alteração no disco.
func (e *Engine) ReloadCombatScript(fullPath string) {
	e.combatMu.Lock()
	defer e.combatMu.Unlock()

	if e.combatState == nil {
		return
	}

	if err := e.combatState.DoFile(e.combatScriptPath); err != nil {
		log.Printf("[HOT-RELOAD] Erro ao recarregar script de combate %s: %v\n", filepath.Base(fullPath), err)
		return
	}

	log.Printf("[HOT-RELOAD] Script de combate recarregado com sucesso: %s\n", filepath.Base(fullPath))
}

// CallCalculateDamage executa CalculateDamage no script combat.lua e retorna (damage, isCrit).
func (e *Engine) CallCalculateDamage(raceID, classID, actionType uint8, hpPct float32, worldHour int, moonPhase, weatherType uint8) (uint16, uint8) {
	e.combatMu.Lock()
	defer e.combatMu.Unlock()

	if e.combatState == nil {
		return 20, 0
	}

	fn := e.combatState.GetGlobal("CalculateDamage")
	if fn.Type() != lua.LTFunction {
		return 20, 0
	}

	err := e.combatState.CallByParam(lua.P{
		Fn:      fn,
		NRet:    2,
		Protect: true,
	},
		lua.LNumber(raceID),
		lua.LNumber(classID),
		lua.LNumber(actionType),
		lua.LNumber(hpPct),
		lua.LNumber(worldHour),
		lua.LNumber(moonPhase),
		lua.LNumber(weatherType),
	)

	if err != nil {
		log.Printf("[COMBATE] Erro ao executar CalculateDamage no Lua: %v\n", err)
		return 20, 0
	}

	dmgRet := e.combatState.Get(-2)
	critRet := e.combatState.Get(-1)
	e.combatState.Pop(2)

	damage := uint16(lua.LVAsNumber(dmgRet))
	isCrit := uint8(lua.LVAsNumber(critRet))

	return damage, isCrit
}

// StartWatcher inicia o monitoramento fsnotify para recarregamento automático dos scripts.
func (e *Engine) StartWatcher(dirs ...string) error {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return fmt.Errorf("erro ao inicializar fsnotify: %w", err)
	}
	e.watcher = watcher
	e.watchedDirs = dirs

	for _, d := range dirs {
		if err := watcher.Add(d); err != nil {
			log.Printf("[AVISO] Nao foi possivel monitorar pasta '%s': %v\n", d, err)
		} else {
			log.Printf("[HOT-RELOAD] Monitorando alteracoes em scripts Lua na pasta: %s\n", d)
		}
	}

	go e.runWatcherLoop()
	return nil
}

// runWatcherLoop processa eventos de modificação de arquivo e recarrega a VM correspondente.
func (e *Engine) runWatcherLoop() {
	for {
		select {
		case <-e.stopChan:
			return
		case event, ok := <-e.watcher.Events:
			if !ok {
				return
			}

			// Filtra eventos de escrita/criação em arquivos .lua
			if event.Op&(fsnotify.Write|fsnotify.Create) != 0 && strings.HasSuffix(strings.ToLower(event.Name), ".lua") {
				baseName := strings.ToLower(filepath.Base(event.Name))

				e.mu.Lock()
				lastTime, existsRecent := e.lastReload[baseName]
				now := time.Now()
				// Debounce de 150ms para evitar disparos duplicados do Windows
				if existsRecent && now.Sub(lastTime) < 150*time.Millisecond {
					e.mu.Unlock()
					continue
				}
				e.lastReload[baseName] = now
				npc, found := e.npcByScript[baseName]
				e.mu.Unlock()

				if baseName == "combat.lua" {
					e.ReloadCombatScript(event.Name)
				} else if baseName == "mobs_ai.lua" {
					e.ReloadMobAIScript(event.Name)
				} else if found && npc != nil {
					e.reloadNPCScript(npc, event.Name)
				}
			}
		case err, ok := <-e.watcher.Errors:
			if !ok {
				return
			}
			log.Printf("[HOT-RELOAD] Erro no watcher: %v\n", err)
		}
	}
}

// reloadNPCScript recarrega o arquivo Lua na VM do NPC sem reiniciar o servidor.
func (e *Engine) reloadNPCScript(npc *world.NPC, fullPath string) {
	npc.LuaMu.Lock()
	defer npc.LuaMu.Unlock()

	if npc.LuaState == nil {
		return
	}

	if err := npc.LuaState.DoFile(npc.ScriptPath); err != nil {
		log.Printf("[HOT-RELOAD] Erro ao recarregar script %s: %v\n", filepath.Base(fullPath), err)
		return
	}

	log.Printf("[HOT-RELOAD] Script recarregado com sucesso: %s\n", filepath.Base(fullPath))
}

// CallOnTick invoca a função Lua OnTick(world_hour) do NPC.
func CallOnTick(npc *world.NPC, worldHour int) error {
	npc.LuaMu.Lock()
	defer npc.LuaMu.Unlock()

	if npc.LuaState == nil {
		return nil
	}

	fn := npc.LuaState.GetGlobal("OnTick")
	if fn.Type() != lua.LTFunction {
		return nil
	}

	return npc.LuaState.CallByParam(lua.P{
		Fn:      fn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(worldHour), lua.LNumber(worldHour))
}

// CallOnPlayerApproach invoca a função Lua OnPlayerApproach(player_id, distance, player_race) do NPC.
func CallOnPlayerApproach(npc *world.NPC, playerID uint32, distance float32, playerRace uint8) error {
	npc.LuaMu.Lock()
	defer npc.LuaMu.Unlock()

	if npc.LuaState == nil {
		return nil
	}

	fn := npc.LuaState.GetGlobal("OnPlayerApproach")
	if fn.Type() != lua.LTFunction {
		return nil
	}

	return npc.LuaState.CallByParam(lua.P{
		Fn:      fn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(playerID), lua.LNumber(distance), lua.LNumber(playerRace))
}

// CallOnPlayerInteract invoca a função Lua OnPlayerInteract(player_id, world_hour, player_race, player_class) do NPC.
func CallOnPlayerInteract(npc *world.NPC, playerID uint32, worldHour int, playerRace, playerClass uint8) error {
	npc.LuaMu.Lock()
	defer npc.LuaMu.Unlock()

	if npc.LuaState == nil {
		return nil
	}

	fn := npc.LuaState.GetGlobal("OnPlayerInteract")
	if fn.Type() != lua.LTFunction {
		return nil
	}

	return npc.LuaState.CallByParam(lua.P{
		Fn:      fn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(playerID), lua.LNumber(worldHour), lua.LNumber(playerRace), lua.LNumber(playerClass))
}

// Close finaliza o watcher e as VMs Lua.
func (e *Engine) Close() {
	close(e.stopChan)
	if e.watcher != nil {
		_ = e.watcher.Close()
	}

	e.combatMu.Lock()
	if e.combatState != nil {
		e.combatState.Close()
		e.combatState = nil
	}
	e.combatMu.Unlock()

	e.mobAIMu.Lock()
	if e.mobAIState != nil {
		e.mobAIState.Close()
		e.mobAIState = nil
	}
	e.mobAIMu.Unlock()
}

// LoadMobAIScript carrega e inicializa o script de IA tática dos Mobs (mobs_ai.lua).
func (e *Engine) LoadMobAIScript(scriptPath string, mobManager *world.MobManager,
	onMobAttack func(mobID, playerID uint32, damage uint16),
	onTelegraph func(sourceID uint32, x, z, radius float32, durationMs uint16),
	onAOEDamage func(sourceID uint32, x, z, radius float32, damage uint16),
	onMobSay func(mobID uint32, text string),
) error {
	L := lua.NewState()

	e.mobManager = mobManager
	e.onMobAttack = onMobAttack
	e.onTelegraph = onTelegraph
	e.onAOEDamage = onAOEDamage
	e.onMobSay = onMobSay

	// mob_move_to(mob_id, target_x, target_z, speed)
	L.SetGlobal("mob_move_to", L.NewFunction(func(L *lua.LState) int {
		mobID := uint32(L.CheckInt(1))
		tx := float32(L.CheckNumber(2))
		tz := float32(L.CheckNumber(3))
		speed := float32(L.CheckNumber(4))
		if e.mobManager != nil {
			mob := e.mobManager.GetMob(mobID)
			if mob != nil {
				dt := e.currentDelta
				if dt <= 0 {
					dt = 0.033
				}
				mob.MoveTowards(tx, tz, speed, dt)
			}
		}
		return 0
	}))

	// mob_set_state(mob_id, state)
	L.SetGlobal("mob_set_state", L.NewFunction(func(L *lua.LState) int {
		mobID := uint32(L.CheckInt(1))
		state := uint8(L.CheckInt(2))
		if e.mobManager != nil {
			mob := e.mobManager.GetMob(mobID)
			if mob != nil {
				mob.SetState(state)
			}
		}
		return 0
	}))

	// mob_attack_player(mob_id, player_id, damage)
	L.SetGlobal("mob_attack_player", L.NewFunction(func(L *lua.LState) int {
		mobID := uint32(L.CheckInt(1))
		playerID := uint32(L.CheckInt(2))
		damage := uint16(L.CheckInt(3))
		if e.onMobAttack != nil {
			e.onMobAttack(mobID, playerID, damage)
		}
		return 0
	}))

	// mob_spawn_telegraph(source_id, x, z, radius, duration_ms)
	L.SetGlobal("mob_spawn_telegraph", L.NewFunction(func(L *lua.LState) int {
		sourceID := uint32(L.CheckInt(1))
		x := float32(L.CheckNumber(2))
		z := float32(L.CheckNumber(3))
		radius := float32(L.CheckNumber(4))
		durationMs := uint16(L.CheckInt(5))
		if e.onTelegraph != nil {
			e.onTelegraph(sourceID, x, z, radius, durationMs)
		}
		return 0
	}))

	// mob_trigger_slam_damage(mob_id, x, z, radius, damage)
	L.SetGlobal("mob_trigger_slam_damage", L.NewFunction(func(L *lua.LState) int {
		sourceID := uint32(L.CheckInt(1))
		x := float32(L.CheckNumber(2))
		z := float32(L.CheckNumber(3))
		radius := float32(L.CheckNumber(4))
		damage := uint16(L.CheckInt(5))
		if e.onAOEDamage != nil {
			e.onAOEDamage(sourceID, x, z, radius, damage)
		}
		return 0
	}))

	// mob_heal_ally(source_mob_id, target_mob_id, amount)
	L.SetGlobal("mob_heal_ally", L.NewFunction(func(L *lua.LState) int {
		sourceMobID := uint32(L.CheckInt(1))
		targetMobID := uint32(L.CheckInt(2))
		amount := uint16(L.CheckInt(3))
		if e.mobManager == nil {
			L.Push(lua.LFalse)
			return 1
		}
		sourceMob := e.mobManager.GetMob(sourceMobID)
		if sourceMob == nil {
			L.Push(lua.LFalse)
			return 1
		}

		var target *world.Mob
		if targetMobID > 0 {
			target = e.mobManager.GetMob(targetMobID)
		} else {
			var mostWounded *world.Mob
			var maxMissing uint16 = 0
			for _, ally := range e.mobManager.GetAllMobs() {
				if !ally.IsAlive {
					continue
				}
				ally.Mu.RLock()
				missing := ally.MaxHP - ally.HP
				dx := ally.PosX - sourceMob.PosX
				dz := ally.PosZ - sourceMob.PosZ
				dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
				ally.Mu.RUnlock()

				if dist <= 10.0 && missing > maxMissing {
					maxMissing = missing
					mostWounded = ally
				}
			}
			target = mostWounded
		}

		if target != nil {
			target.Heal(amount)
			L.Push(lua.LTrue)
			return 1
		}
		L.Push(lua.LFalse)
		return 1
	}))

	// mob_say(mob_id, text)
	L.SetGlobal("mob_say", L.NewFunction(func(L *lua.LState) int {
		mobID := uint32(L.CheckInt(1))
		text := L.CheckString(2)
		if e.onMobSay != nil {
			e.onMobSay(mobID, text)
		}
		return 0
	}))

	if err := L.DoFile(scriptPath); err != nil {
		L.Close()
		return fmt.Errorf("falha ao carregar script de IA dos mobs '%s': %w", scriptPath, err)
	}

	e.mobAIMu.Lock()
	if e.mobAIState != nil {
		e.mobAIState.Close()
	}
	e.mobAIState = L
	e.mobAIScriptPath = scriptPath
	e.mobAIMu.Unlock()

	log.Printf("[MOBS-AI] Script de IA dos Mobs carregado com sucesso: %s\n", filepath.Base(scriptPath))
	return nil
}

// ReloadMobAIScript recarrega o script mobs_ai.lua a quente.
func (e *Engine) ReloadMobAIScript(fullPath string) {
	e.mobAIMu.Lock()
	defer e.mobAIMu.Unlock()

	if e.mobAIState == nil {
		return
	}

	if err := e.mobAIState.DoFile(e.mobAIScriptPath); err != nil {
		log.Printf("[HOT-RELOAD] Erro ao recarregar script de IA dos mobs %s: %v\n", filepath.Base(fullPath), err)
		return
	}

	log.Printf("[HOT-RELOAD] Script de IA dos Mobs recarregado com sucesso: %s\n", filepath.Base(fullPath))
}

// UpdateMobAI executa a lógica de IA tática no script mobs_ai.lua.
func (e *Engine) UpdateMobAI(mob *world.Mob, nearestPlayerID uint32, playerDist, playerX, playerZ float32, moonPhase uint8, dt float32) {
	e.mobAIMu.Lock()
	defer e.mobAIMu.Unlock()

	if e.mobAIState == nil {
		return
	}
	e.currentDelta = dt

	fn := e.mobAIState.GetGlobal("UpdateMob")
	if fn.Type() != lua.LTFunction {
		return
	}

	mob.Mu.RLock()
	mobID := mob.ID
	mobType := mob.MobType
	mobX := mob.PosX
	mobZ := mob.PosZ
	mobHP := mob.HP
	mobMaxHP := mob.MaxHP
	mobState := mob.State
	spawnX := mob.SpawnX
	spawnZ := mob.SpawnZ
	mob.Mu.RUnlock()

	_ = e.mobAIState.CallByParam(lua.P{
		Fn:      fn,
		NRet:    0,
		Protect: true,
	},
		lua.LNumber(mobID),
		lua.LNumber(mobType),
		lua.LNumber(mobX),
		lua.LNumber(mobZ),
		lua.LNumber(mobHP),
		lua.LNumber(mobMaxHP),
		lua.LNumber(mobState),
		lua.LNumber(spawnX),
		lua.LNumber(spawnZ),
		lua.LNumber(nearestPlayerID),
		lua.LNumber(playerDist),
		lua.LNumber(playerX),
		lua.LNumber(playerZ),
		lua.LNumber(moonPhase),
		lua.LNumber(dt),
	)
}

// FindNPCScriptsDir descobre o caminho correto para a pasta /scripts/npcs a partir de qualquer CWD.
func FindNPCScriptsDir() string {
	return findDirCandidates("npcs")
}

// FindCombatScriptsDir descobre o caminho correto para a pasta /scripts/combat a partir de qualquer CWD.
func FindCombatScriptsDir() string {
	return findDirCandidates("combat")
}

// FindMobsScriptsDir descobre o caminho correto para a pasta /scripts/mobs a partir de qualquer CWD.
func FindMobsScriptsDir() string {
	return findDirCandidates("mobs")
}

func findDirCandidates(subName string) string {
	candidates := []string{
		fmt.Sprintf("../../../scripts/%s", subName),
		fmt.Sprintf("../../scripts/%s", subName),
		fmt.Sprintf("../scripts/%s", subName),
		fmt.Sprintf("./scripts/%s", subName),
		fmt.Sprintf("scripts/%s", subName),
	}

	if exePath, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exePath)
		candidates = append(candidates,
			filepath.Join(exeDir, fmt.Sprintf("../scripts/%s", subName)),
			filepath.Join(exeDir, fmt.Sprintf("scripts/%s", subName)),
			filepath.Join(exeDir, fmt.Sprintf("../../scripts/%s", subName)),
		)
	}

	for _, cand := range candidates {
		info, err := os.Stat(cand)
		if err == nil && info.IsDir() {
			abs, err := filepath.Abs(cand)
			if err == nil {
				return abs
			}
			return cand
		}
	}

	dir := fmt.Sprintf("../scripts/%s", subName)
	_ = os.MkdirAll(dir, 0755)
	abs, err := filepath.Abs(dir)
	if err == nil {
		return abs
	}
	return dir
}
