package world

import (
	"math"
	"testing"
	"time"

	"lunaria/server/internal/protocol"
)

func TestMobCreationAndSpawns(t *testing.T) {
	mm := NewMobManager()
	if len(mm.Mobs) != 6 {
		t.Fatalf("esperava 6 mobs registrados, obteve %d", len(mm.Mobs))
	}

	wolf1 := mm.GetMob(201)
	if wolf1 == nil || wolf1.MobType != protocol.MobTypeMistWolf || wolf1.MaxHP != 220 {
		t.Fatalf("configuracao invalida para Lobo da Bruma 201: %+v", wolf1)
	}

	enforcer := mm.GetMob(206)
	if enforcer == nil || enforcer.MobType != protocol.MobTypeIronEnforcer || enforcer.MaxHP != 650 {
		t.Fatalf("configuracao invalida para Executor de Ferro 206: %+v", enforcer)
	}
}

func TestMobDamageAndRaiderShield(t *testing.T) {
	raider := NewMob(203, "Saqueador Deserdado", protocol.MobTypeOutcastRaider, -16.0, 0.0, 12.0, 350, 3.2)

	// Dano normal fora de bloqueio
	dmg, blocked, hp, dead := raider.TakeDamage(50)
	if dmg != 50 || blocked || hp != 300 || dead {
		t.Fatalf("dano normal incorreto: dmg=%d, blocked=%v, hp=%d, dead=%v", dmg, blocked, hp, dead)
	}

	// Ativa bloqueio de escudo (State = 3)
	raider.SetState(protocol.MobStateBlocking)
	dmg, blocked, hp, dead = raider.TakeDamage(50)
	if dmg != 25 || !blocked || hp != 275 || dead {
		t.Fatalf("dano bloqueado com escudo incorreto: dmg=%d, blocked=%v, hp=%d, dead=%v", dmg, blocked, hp, dead)
	}
	if raider.BlockedHits != 1 {
		t.Fatalf("esperava 1 hit bloqueado, obteve %d", raider.BlockedHits)
	}
}

func TestMobRespawnTimer(t *testing.T) {
	wolf := NewMob(201, "Lobo da Bruma", protocol.MobTypeMistWolf, 16.0, 0.0, -8.0, 220, 4.2)

	// Mata o mob
	_, _, hp, dead := wolf.TakeDamage(250)
	if hp != 0 || !dead || wolf.IsAlive {
		t.Fatalf("mob deveria estar morto: hp=%d, dead=%v, alive=%v", hp, dead, wolf.IsAlive)
	}

	// Não deve renascer antes dos 12s
	if wolf.CheckRespawn() {
		t.Fatalf("mob renasceu prematuramente")
	}

	// Simula passagem de 12.5 segundos
	wolf.DeadAt = time.Now().Add(-13 * time.Second)
	if !wolf.CheckRespawn() {
		t.Fatalf("mob deveria ter renascido apos 12s")
	}

	if !wolf.IsAlive || wolf.HP != 220 || wolf.PosX != 16.0 || wolf.PosZ != -8.0 {
		t.Fatalf("dados do mob renascido incorretos: %+v", wolf)
	}
}

func TestMobMoveTowards(t *testing.T) {
	mob := NewMob(201, "Lobo", protocol.MobTypeMistWolf, 0.0, 0.0, 0.0, 100, 4.0)

	// Move em direção a (3.0, 4.0) com dt = 0.5s (desloca 2.0 metros)
	mob.MoveTowards(3.0, 4.0, 4.0, 0.5)

	mob.Mu.RLock()
	distFromOrigin := math.Sqrt(float64(mob.PosX*mob.PosX + mob.PosZ*mob.PosZ))
	mob.Mu.RUnlock()

	if math.Abs(distFromOrigin-2.0) > 0.05 {
		t.Fatalf("esperava deslocamento de ~2.0m, obteve %.2f", distFromOrigin)
	}
}

func TestMobVulnerabilityExpiration(t *testing.T) {
	enforcer := NewMob(206, "Executor de Ferro", protocol.MobTypeIronEnforcer, 0.0, 0.0, 22.0, 650, 2.4)

	// Entra em estado vulnerável (State = 4)
	enforcer.SetState(protocol.MobStateFleeingStunned)
	if enforcer.State != protocol.MobStateFleeingStunned || enforcer.VulnerableUntil.IsZero() {
		t.Fatalf("esperava estado vulneravel com timestamp ativo: state=%d", enforcer.State)
	}

	// Imediatamente não deve expirar
	if enforcer.CheckVulnerabilityExpired() {
		t.Fatalf("vulnerabilidade expirou prematuramente")
	}

	// Simula passagem de 2.1 segundos
	enforcer.Mu.Lock()
	enforcer.VulnerableUntil = time.Now().Add(-100 * time.Millisecond)
	enforcer.Mu.Unlock()

	if !enforcer.CheckVulnerabilityExpired() {
		t.Fatalf("esperava que a vulnerabilidade expirasse")
	}

	if enforcer.State != protocol.MobStatePatrolIdle || enforcer.MoveSpeed != 2.4 {
		t.Fatalf("estado ou velocidade incorretos apos recuperacao: state=%d, speed=%.2f", enforcer.State, enforcer.MoveSpeed)
	}
}
