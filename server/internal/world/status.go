package world

import "time"

// Estados especiais de combate: invisibilidade, furtividade, emboscada, combo de socos e polimorfia.

// StealthDetectRange é a distância (m) em que um monstro ainda percebe um jogador furtivo.
const StealthDetectRange float32 = 2.5

// AmbushDamageMult é o dano extra do primeiro golpe saindo da invisibilidade com emboscada.
const AmbushDamageMult float32 = 2.2

// SetInvisible deixa o jogador invisível: monstros não o percebem até ele atacar ou o tempo acabar.
// Com ambush=true, o primeiro golpe depois causa dano de emboscada.
func (p *Player) SetInvisible(d time.Duration, ambush bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.InvisibleUntil = time.Now().Add(d)
	if ambush {
		p.AmbushReady = true
	}
}

// SetStealth deixa o jogador furtivo: monstros só o percebem a até StealthDetectRange metros.
func (p *Player) SetStealth(d time.Duration) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	until := time.Now().Add(d)
	if until.After(p.StealthUntil) {
		p.StealthUntil = until
	}
}

// IsInvisible informa se o jogador está invisível agora.
func (p *Player) IsInvisible() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Now().Before(p.InvisibleUntil)
}

// IsStealthed informa se o jogador está furtivo (ou invisível) agora.
func (p *Player) IsStealthed() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	now := time.Now()
	return now.Before(p.StealthUntil) || now.Before(p.InvisibleUntil)
}

// CanBeDetected diz se um monstro a dist metros percebe o jogador.
func (p *Player) CanBeDetected(dist float32) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	now := time.Now()
	if now.Before(p.InvisibleUntil) {
		return false
	}
	if now.Before(p.StealthUntil) {
		return dist <= StealthDetectRange
	}
	return true
}

// BreakStealth encerra invisibilidade e furtividade (atacar revela o jogador).
func (p *Player) BreakStealth() {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.InvisibleUntil = time.Time{}
	p.StealthUntil = time.Time{}
}

// ConsumeAmbushMult devolve o multiplicador do golpe de emboscada (uma única vez).
func (p *Player) ConsumeAmbushMult() float32 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if !p.AmbushReady {
		return 1.0
	}
	p.AmbushReady = false
	return AmbushDamageMult
}

// RegisterPunch conta socos do Punho Celeste; a cada 3 retorna true (gera o escudo de Punhos de Ferro).
func (p *Player) RegisterPunch() bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.PunchCombo++
	if p.PunchCombo >= 3 {
		p.PunchCombo = 0
		return true
	}
	return false
}

// ApplyPolymorph transforma o monstro numa criatura inofensiva: não ataca nem anda
// e fica vulnerável (+30% de dano recebido) durante d.
func (m *Mob) ApplyPolymorph(d time.Duration) {
	m.ApplyStun(d)
	m.ApplyArmorBreak(d, 0.30)
	m.Mu.Lock()
	m.PolymorphUntil = time.Now().Add(d)
	m.Mu.Unlock()
}

// IsPolymorphed informa se o monstro está polimorfado.
func (m *Mob) IsPolymorphed() bool {
	m.Mu.RLock()
	defer m.Mu.RUnlock()
	return time.Now().Before(m.PolymorphUntil)
}
