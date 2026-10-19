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

// NPC representa o modelo em memória de um NPC vivo no mundo de Lunaria.
type NPC struct {
	mu sync.RWMutex

	ID         uint32
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

	LuaMu    sync.Mutex
	LuaState *lua.LState

	approachCooldowns map[uint32]time.Time
	broadcastSay      SayCallback
	clock             *WorldClock
}

// NewNPC instancia um novo NPC com coordenadas iniciais e estado padrão.
func NewNPC(id uint32, name string, initX, initY, initZ float32, scriptPath string, clock *WorldClock, broadcastSay SayCallback) *NPC {
	return &NPC{
		ID:                id,
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
		approachCooldowns: make(map[uint32]time.Time),
		broadcastSay:      broadcastSay,
		clock:             clock,
	}
}

// UpdateMovement interpola suavemente as posições PosX e PosZ em direção ao alvo a cada tick (30 Hz).
func (npc *NPC) UpdateMovement(dt float32) {
	npc.mu.Lock()
	defer npc.mu.Unlock()

	dx := npc.TargetX - npc.PosX
	dz := npc.TargetZ - npc.PosZ
	distSq := dx*dx + dz*dz

	// Distância menor ou igual a 0.15m: alcançou o destino
	if distSq <= 0.0225 { // 0.15 * 0.15 = 0.0225
		npc.PosX = npc.TargetX
		npc.PosZ = npc.TargetZ
		npc.MoveSpeed = 0

		// Atribui o estado correspondente ao local de chegada
		if npc.TargetX > 0 {
			npc.State = 2                              // Trabalhando na Forja
			npc.RotY = float32(math.Atan2(-2.0, -2.0)) // Olhando em direção à Forja (8, 8)
		} else {
			npc.State = 3                            // Bebendo na Taverna
			npc.RotY = float32(math.Atan2(2.0, 2.0)) // Olhando em direção à Taverna (-8, -6)
		}
		return
	}

	dist := float32(math.Sqrt(float64(distSq)))
	step := npc.MoveSpeed * dt

	if step >= dist {
		npc.PosX = npc.TargetX
		npc.PosZ = npc.TargetZ
		npc.MoveSpeed = 0
		if npc.TargetX > 0 {
			npc.State = 2
			npc.RotY = float32(math.Atan2(-2.0, -2.0))
		} else {
			npc.State = 3
			npc.RotY = float32(math.Atan2(2.0, 2.0))
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
	return npc.DistanceTo(px, py, pz) <= 5.0
}

// ToSnapshot converte o estado atual do NPC no formato serializável NPCSnapshot.
func (npc *NPC) ToSnapshot() protocol.NPCSnapshot {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
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
