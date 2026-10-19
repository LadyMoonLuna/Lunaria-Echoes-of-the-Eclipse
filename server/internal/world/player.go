package world

import (
	"net"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
)

// Player representa o estado em memória de um jogador conectado na instância autoritativa.
type Player struct {
	Mu sync.RWMutex

	ID       uint32
	TCPConn  net.Conn
	UDPAddr  *net.UDPAddr
	LastSeq  uint32
	PosX     float32
	PosY     float32
	PosZ     float32
	RotY     float32
	LastSeen time.Time

	// Marco 3: Identidade e Combate
	RaceID     uint8
	ClassID    uint8
	HP         uint16
	MaxHP      uint16
	Stamina    float32
	MaxStamina uint16

	// Marco 4: I-Frames de Esquiva e Sobrevivência
	IFrameUntil time.Time
}

// CalculateStatsByClassAndRace calcula MaxHP e MaxStamina baseado na combinação de classe e raça.
func CalculateStatsByClassAndRace(classID, raceID uint8) (uint16, uint16) {
	var baseHP uint16 = 140
	var baseStamina uint16 = 100

	switch classID {
	case protocol.ClassSwordsman: // 1
		baseHP = 140
		baseStamina = 100
	case protocol.ClassScout: // 2
		baseHP = 105
		baseStamina = 135
	case protocol.ClassInitiate: // 3
		baseHP = 95
		baseStamina = 110
	case protocol.ClassAcolyte: // 4
		baseHP = 125
		baseStamina = 105
	}

	var modHP uint16 = 10
	var modStamina uint16 = 10

	switch raceID {
	case protocol.RaceValerian: // 1
		modHP = 10
		modStamina = 10
	case protocol.RaceNoctari: // 2
		modHP = 0
		modStamina = 20
	case protocol.RaceKharad: // 3
		modHP = 30
		modStamina = 0
	case protocol.RaceVarkai: // 4
		modHP = 15
		modStamina = 10
	case protocol.RaceDhampir: // 5
		modHP = 10
		modStamina = 15
	}

	return baseHP + modHP, baseStamina + modStamina
}

// NewPlayer cria uma nova instância de Player com posição inicial e status calculados por Raça e Classe.
func NewPlayer(id uint32, tcpConn net.Conn, initX, initY, initZ float32) *Player {
	initRace := protocol.RaceValerian
	initClass := protocol.ClassSwordsman
	maxHP, maxStam := CalculateStatsByClassAndRace(initClass, initRace)

	return &Player{
		ID:         id,
		TCPConn:    tcpConn,
		PosX:       initX,
		PosY:       initY,
		PosZ:       initZ,
		RotY:       0,
		LastSeen:   time.Now(),
		RaceID:     initRace,
		ClassID:    initClass,
		HP:         maxHP,
		MaxHP:      maxHP,
		Stamina:    float32(maxStam),
		MaxStamina: maxStam,
	}
}

// SetIdentity define a Raça e Classe do jogador (recebido via 0x30 SELECT_IDENTITY) e recalcula os atributos.
func (p *Player) SetIdentity(raceID, classID uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.RaceID = raceID
	p.ClassID = classID

	newMaxHP, newMaxStamina := CalculateStatsByClassAndRace(classID, raceID)
	if p.HP > newMaxHP || p.HP == p.MaxHP {
		p.HP = newMaxHP
	}
	p.MaxHP = newMaxHP
	p.MaxStamina = newMaxStamina
	if p.Stamina > float32(newMaxStamina) {
		p.Stamina = float32(newMaxStamina)
	}
}

// SetDodgeIFrame concede tempo de invulnerabilidade (0.45s) durante a esquiva.
func (p *Player) SetDodgeIFrame(duration time.Duration) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.IFrameUntil = time.Now().Add(duration)
}

// IsInvulnerable verifica se o jogador está em janela de invulnerabilidade (I-Frame).
func (p *Player) IsInvulnerable() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Now().Before(p.IFrameUntil)
}

// Heal restaura vida até o limite de MaxHP e retorna o novo valor de HP.
func (p *Player) Heal(amount uint16) uint16 {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	p.HP += amount
	if p.HP > p.MaxHP {
		p.HP = p.MaxHP
	}
	return p.HP
}

// Respawn restaura HP e Stamina para o máximo e redefine a posição segura do jogador.
func (p *Player) Respawn(safeX, safeY, safeZ float32) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	p.HP = p.MaxHP
	p.Stamina = float32(p.MaxStamina)
	p.PosX = safeX
	p.PosY = safeY
	p.PosZ = safeZ
	p.IFrameUntil = time.Time{}
}

// RegenerateStamina recupera estamina a 30 Hz.
// Bônus do Marco 3: Se for Noite e Lua Crescente (1), ganha +15% de regeneração de estamina.
func (p *Player) RegenerateStamina(dt float32, isNight bool, moonPhase uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	baseRegenRate := float32(15.0) // 15 pontos de stamina por segundo
	if p.RaceID == protocol.RaceValerian {
		baseRegenRate *= 1.15 // +15% de regeneração de estamina para Valeriano
	}
	if isNight && moonPhase == MoonPhaseWaxingCrescent {
		baseRegenRate *= 1.15 // +15% de regeneração sob a Lua Crescente
	}

	p.Stamina += baseRegenRate * dt
	if p.Stamina > float32(p.MaxStamina) {
		p.Stamina = float32(p.MaxStamina)
	}
}

// ConsumeStamina verifica e consome estamina para uma ação de combate. Retorna true se houver estamina suficiente.
func (p *Player) ConsumeStamina(amount float32) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.Stamina < amount {
		return false
	}
	p.Stamina -= amount
	return true
}

// TakeDamage aplica dano ao jogador e retorna o HP atualizado.
// Respeita janelas de invulnerabilidade (I-Frames de Esquiva).
func (p *Player) TakeDamage(amount uint16) (uint16, bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	// Se estiver invulnerável (Dodge Roll), ignora dano
	if time.Now().Before(p.IFrameUntil) {
		return p.HP, false
	}

	// Passiva Kharad (Postura de Rocha): reduz todo dano recebido em 20%
	if p.RaceID == protocol.RaceKharad && amount > 0 {
		amount = uint16(float32(amount) * 0.80)
		if amount == 0 {
			amount = 1
		}
	}

	if amount >= p.HP {
		p.HP = 0
		return 0, true
	}
	p.HP -= amount
	return p.HP, false
}

// UpdateFromMove atualiza posição, rotação e endereço UDP caso o Seq seja estritamente superior ao LastSeq.
func (p *Player) UpdateFromMove(seq uint32, posX, posY, posZ, rotY float32, addr *net.UDPAddr) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()

	if p.LastSeq != 0 && seq <= p.LastSeq {
		return false
	}

	p.LastSeq = seq
	p.PosX = posX
	p.PosY = posY
	p.PosZ = posZ
	p.RotY = rotY
	p.UDPAddr = addr
	p.LastSeen = time.Now()
	return true
}

// GetUDPAddr retorna o endereço UDP thread-safe associado ao jogador.
func (p *Player) GetUDPAddr() *net.UDPAddr {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.UDPAddr
}

// ToSnapshot converte o estado atual do jogador em uma estrutura PlayerSnapshot thread-safe.
func (p *Player) ToSnapshot() protocol.PlayerSnapshot {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return protocol.PlayerSnapshot{
		PlayerID: p.ID,
		PosX:     p.PosX,
		PosY:     p.PosY,
		PosZ:     p.PosZ,
		RotY:     p.RotY,
	}
}

// ToStatsPacket converte os status de sobrevivência em PlayerStatsPacket.
func (p *Player) ToStatsPacket() protocol.PlayerStatsPacket {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return protocol.PlayerStatsPacket{
		PlayerID:   p.ID,
		RaceID:     p.RaceID,
		ClassID:    p.ClassID,
		HP:         p.HP,
		MaxHP:      p.MaxHP,
		Stamina:    uint16(p.Stamina),
		MaxStamina: p.MaxStamina,
	}
}
