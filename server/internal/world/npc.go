package world

import (
	"math"
	"sync"
	"time"

	"github.com/yuin/gopher-lua"
	"lunaria/server/internal/protocol"
)

// SayCallback define a assinatura da função para difusão de falas do NPC aos jogadores conectados.
type SayCallback func(npcID uint32, message string)

// Waypoint define uma coordenada de patrulha no mapa.
type Waypoint struct {
	X float32
	Z float32
}

// NPC representa o modelo em memória de um NPC vivo no mundo de Lunaria.
type NPC struct {
	mu sync.RWMutex

	ID         uint32
	ZoneID     uint8 // Zona instanciada onde o NPC reside (0 a 8)
	Name       string
	PosX       float32
	PosY       float32
	PosZ       float32
	RotY       float32
	TargetX    float32
	TargetZ    float32
	MoveSpeed  float32
	State      uint8
	ScriptPath string
	IsActive   bool
	ShopOpen   bool

	// Sistema de Patrulha Contínua com Waypoints
	Waypoints          []Waypoint
	CurrentWaypointIdx int
	WaitTimer          float32
	WaitDuration       float32
	BaseMoveSpeed      float32
	IsPatrolling       bool

	LuaMu    sync.Mutex
	LuaState *lua.LState

	// --- Mundo Vivo: agente biológico e econômico ---
	HP              int
	MaxHP           int
	IsDead          bool    // Morte permanente: nunca renasce
	Hunger          float32 // 0 a 100 (100 = saciado); cai 0,5/min
	Thirst          float32 // 0 a 100 (100 = hidratado); cai 0,8/min
	Cold            float32 // 0 a 100 (0 = aquecido); sobe abaixo de 10 °C longe do fogo
	Heat            float32 // 0 a 100 (0 = fresco); sobe acima de 26 °C (insolação em 100)
	Temperature     float32 // temperatura sentida agora (°C)
	Personality     string  // Honrado, Ambicioso, Cauteloso, Implacavel
	Gold            uint32
	RawMaterials    map[uint16]int // matérias-primas em mãos
	ShopStock       map[uint16]int // itens prontos à venda (estoque real, nada infinito)
	CurrentActivity string
	Life            NPCLifeState
	Profession      uint32 // chave em NPCProfiles do ofício que exerce (0 = nenhum)
	ProfessionLevel int    // nível no ofício (aprendizes formados começam no 1)
	CraftCount      int

	approachCooldowns map[uint32]time.Time
	broadcastSay      SayCallback
	clock             *WorldClock
}

// NewNPC instancia um novo NPC com coordenadas iniciais e estado padrão.
func NewNPC(id uint32, name string, initX, initY, initZ float32, scriptPath string, clock *WorldClock, broadcastSay SayCallback) *NPC {
	return &NPC{
		ID:                id,
		ZoneID:            ZoneVillage,
		Name:              name,
		PosX:              initX,
		PosY:              initY,
		PosZ:              initZ,
		RotY:              0,
		TargetX:           initX,
		TargetZ:           initZ,
		MoveSpeed:         0,
		State:             0, // 0 = Parado
		ScriptPath:        scriptPath,
		IsActive:          true,
		ShopOpen:          true,
		Waypoints:         make([]Waypoint, 0),
		WaitDuration:      3.0,
		approachCooldowns: make(map[uint32]time.Time),
		HP:                600,
		MaxHP:             600,
		Hunger:            100,
		Thirst:            100,
		Personality:       PersonalityHonorable,
		RawMaterials:      make(map[uint16]int),
		ShopStock:         make(map[uint16]int),
		CurrentActivity:   ActivityWorking,
		broadcastSay:      broadcastSay,
		clock:             clock,
	}
}

// SetPatrolRoute configura a rota cíclica de patrulha contínua com waypoints e velocidade.
func (npc *NPC) SetPatrolRoute(waypoints []Waypoint, speed float32, waitDuration float32) {
	npc.mu.Lock()
	defer npc.mu.Unlock()

	npc.Waypoints = waypoints
	npc.BaseMoveSpeed = speed
	npc.WaitDuration = waitDuration
	npc.CurrentWaypointIdx = 0
	npc.WaitTimer = 0
	if len(waypoints) > 0 {
		npc.IsPatrolling = true
		npc.TargetX = waypoints[0].X
		npc.TargetZ = waypoints[0].Z
		npc.MoveSpeed = speed
		npc.State = 1 // Andando
	}
}

// UpdateMovement interpola suavemente as posições PosX e PosZ em direção ao alvo a cada tick (30 Hz).
func (npc *NPC) UpdateMovement(dt float32) {
	npc.mu.Lock()
	defer npc.mu.Unlock()

	if !npc.IsActive {
		return
	}

	// 1. Patrulha Contínua com Waypoints (Guardas 105 e 106)
	if npc.IsPatrolling && len(npc.Waypoints) > 0 {
		// Se estiver inspecionando no waypoint (State = 0)
		if npc.WaitTimer > 0 {
			npc.WaitTimer -= dt
			npc.MoveSpeed = 0
			npc.State = 0 // Inspecionando / Parado
			if npc.WaitTimer <= 0 {
				// Avança para o próximo waypoint da rota em loop infinito
				npc.CurrentWaypointIdx = (npc.CurrentWaypointIdx + 1) % len(npc.Waypoints)
				nextWp := npc.Waypoints[npc.CurrentWaypointIdx]
				npc.TargetX = nextWp.X
				npc.TargetZ = nextWp.Z
				npc.MoveSpeed = npc.BaseMoveSpeed
				npc.State = 1 // Andando para o próximo
			}
			return
		}

		dx := npc.TargetX - npc.PosX
		dz := npc.TargetZ - npc.PosZ
		distSq := dx*dx + dz*dz

		// Chegou a <= 0.4m do waypoint atual
		if distSq <= 0.16 { // 0.4 * 0.4 = 0.16
			npc.PosX = npc.TargetX
			npc.PosZ = npc.TargetZ
			npc.MoveSpeed = 0
			npc.State = 0                    // Inspecionando o local
			npc.WaitTimer = npc.WaitDuration // Aguarda 3.0 segundos
			return
		}

		dist := float32(math.Sqrt(float64(distSq)))
		step := npc.MoveSpeed * dt

		if step >= dist {
			npc.PosX = npc.TargetX
			npc.PosZ = npc.TargetZ
			npc.MoveSpeed = 0
			npc.State = 0
			npc.WaitTimer = npc.WaitDuration
		} else {
			npc.PosX += (dx / dist) * step
			npc.PosZ += (dz / dist) * step
			npc.State = 1 // Andando
			npc.RotY = float32(math.Atan2(float64(-dx), float64(-dz)))
		}
		return
	}

	// 2. Movimento manual padrão (ex: comandado por npc_move_to)
	dx := npc.TargetX - npc.PosX
	dz := npc.TargetZ - npc.PosZ
	distSq := dx*dx + dz*dz

	// Distância menor ou igual a 0.15m: alcançou o destino
	if distSq <= 0.0225 { // 0.15 * 0.15 = 0.0225
		npc.PosX = npc.TargetX
		npc.PosZ = npc.TargetZ
		npc.MoveSpeed = 0

		// Atribui o estado correspondente ao local de chegada
		if npc.ID == 100 { // Garrick, o Ferreiro
			if npc.TargetX > 0 {
				npc.State = 2                              // Trabalhando na Forja
				npc.RotY = float32(math.Atan2(-2.0, -2.0)) // Olhando em direção à Forja
			} else {
				npc.State = 3                            // Na Taverna
				npc.RotY = float32(math.Atan2(2.0, 2.0)) // Olhando em direção à Taverna
			}
		} else {
			npc.State = 0
		}
		return
	}

	dist := float32(math.Sqrt(float64(distSq)))
	step := npc.MoveSpeed * dt

	if step >= dist {
		npc.PosX = npc.TargetX
		npc.PosZ = npc.TargetZ
		npc.MoveSpeed = 0
		if npc.ID == 100 {
			if npc.TargetX > 0 {
				npc.State = 2
				npc.RotY = float32(math.Atan2(-2.0, -2.0))
			} else {
				npc.State = 3
				npc.RotY = float32(math.Atan2(2.0, 2.0))
			}
		} else {
			npc.State = 0
		}
	} else {
		npc.PosX += (dx / dist) * step
		npc.PosZ += (dz / dist) * step
		npc.State = 1 // Andando
		// Calcula orientação Yaw (RotY) olhando para a direção de movimento
		npc.RotY = float32(math.Atan2(float64(-dx), float64(-dz)))
	}
}

// SetTarget define o destino para onde o NPC se moverá.
func (npc *NPC) SetTarget(x, z, speed float32) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	npc.TargetX = x
	npc.TargetZ = z
	npc.MoveSpeed = speed
}

// Teleport posiciona o NPC instantaneamente em novas coordenadas.
func (npc *NPC) Teleport(x, y, z float32) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	npc.PosX = x
	npc.PosY = y
	npc.PosZ = z
	npc.TargetX = x
	npc.TargetZ = z
	npc.MoveSpeed = 0
}

// SetActive ativa ou desativa a presença e interação do NPC no mundo.
func (npc *NPC) SetActive(active bool) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	if npc.IsDead && active {
		return // morte permanente: nenhuma rotina traz o NPC de volta
	}
	npc.IsActive = active
}

// GetActive retorna se o NPC está ativo no mundo thread-safe.
func (npc *NPC) GetActive() bool {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.IsActive
}

// SetState altera o estado visual do NPC.
func (npc *NPC) SetState(state uint8) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	npc.State = state
}

// Say dispara a mensagem do NPC para todos os clientes via callback de rede TCP.
func (npc *NPC) Say(text string) {
	if npc.broadcastSay != nil {
		npc.broadcastSay(npc.ID, text)
	}
}

// GetPos retorna as coordenadas X, Y, Z thread-safe do NPC.
func (npc *NPC) GetPos() (float32, float32, float32) {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.PosX, npc.PosY, npc.PosZ
}

// DistanceTo calcula a distância euclidiana tridimensional entre o NPC e uma coordenada.
func (npc *NPC) DistanceTo(px, py, pz float32) float32 {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	dx := px - npc.PosX
	dy := py - npc.PosY
	dz := pz - npc.PosZ
	return float32(math.Sqrt(float64(dx*dx + dy*dy + dz*dz)))
}

// TryTriggerApproach verifica se o jogador entrou no raio de 4m e se o cooldown de 15s expirou.
func (npc *NPC) TryTriggerApproach(playerID uint32, px, py, pz float32) (bool, float32) {
	npc.mu.RLock()
	if !npc.IsActive {
		npc.mu.RUnlock()
		return false, 999.0
	}
	npc.mu.RUnlock()

	dist := npc.DistanceTo(px, py, pz)
	if dist >= 4.0 {
		return false, dist
	}

	npc.mu.Lock()
	defer npc.mu.Unlock()

	last, exists := npc.approachCooldowns[playerID]
	now := time.Now()
	if exists && now.Sub(last) < 15*time.Second {
		return false, dist
	}

	npc.approachCooldowns[playerID] = now
	return true, dist
}

// CanInteract verifica se o jogador está a menos de 5.0 metros para interação.
func (npc *NPC) CanInteract(px, py, pz float32) bool {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	if !npc.IsActive {
		return false
	}
	dx := px - npc.PosX
	dy := py - npc.PosY
	dz := pz - npc.PosZ
	return (dx*dx + dy*dy + dz*dz) <= 25.0
}

// ToSnapshot converte o estado atual do NPC no formato serializável NPCSnapshot.
func (npc *NPC) ToSnapshot() protocol.NPCSnapshot {
	npc.mu.RLock()
	defer npc.mu.RUnlock()

	if !npc.IsActive {
		return protocol.NPCSnapshot{
			NPCID: npc.ID,
			PosX:  npc.PosX,
			PosY:  -100.0,
			PosZ:  npc.PosZ,
			RotY:  npc.RotY,
			State: 255, // 255 = Inativo / Oculto
		}
	}

	return protocol.NPCSnapshot{
		NPCID: npc.ID,
		PosX:  npc.PosX,
		PosY:  npc.PosY,
		PosZ:  npc.PosZ,
		RotY:  npc.RotY,
		State: npc.State,
	}
}

// Close finaliza o estado da máquina Lua do NPC.
func (npc *NPC) Close() {
	npc.LuaMu.Lock()
	defer npc.LuaMu.Unlock()
	if npc.LuaState != nil {
		npc.LuaState.Close()
		npc.LuaState = nil
	}
}

// AddFriendship incrementa ou decrementa a afiança do jogador com o NPC informado (0 a 100).
func AddFriendship(player *Player, npcID uint32, amount int) int {
	if player == nil {
		return 0
	}
	return player.AddFriendship(npcID, amount)
}

// GetFriendshipLevel retorna o nível de afiança (0 a 5) entre o jogador e o NPC.
func GetFriendshipLevel(player *Player, npcID uint32) uint8 {
	if player == nil {
		return 0
	}
	return player.GetFriendshipLevel(npcID)
}

// GetZone retorna o ZoneID onde o NPC está localizado.
func (npc *NPC) GetZone() uint8 {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.ZoneID
}

// SetZone define o ZoneID do NPC.
func (npc *NPC) SetZone(zoneID uint8) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	npc.ZoneID = zoneID
}

// IsShopOpen retorna se a loja/serviços do NPC estão abertos thread-safe.
func (npc *NPC) IsShopOpen() bool {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.ShopOpen
}

// SetShopOpen define se a loja/serviços do NPC estão abertos.
func (npc *NPC) SetShopOpen(open bool) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	npc.ShopOpen = open
}
