package world

import (
	"math"
	"testing"
	"time"

	"lunaria/server/internal/protocol"
)

func TestMobCreationAndSpawns(t *testing.T) {
	mm := NewMobManager()
	if len(mm.Mobs) != 29 {
		t.Fatalf("esperava 29 mobs registrados, obteve %d", len(mm.Mobs))
	}

	wolf1 := mm.GetMob(201)
	if wolf1 == nil || wolf1.MobType != protocol.MobTypeMistWolf || wolf1.MaxHP != 220 || wolf1.GetZone() != ZoneForest {
		t.Fatalf("configuracao invalida para Lobo da Bruma 201: %+v", wolf1)
	}

	enforcer := mm.GetMob(206)
	if enforcer == nil || enforcer.MobType != protocol.MobTypeIronEnforcer || enforcer.MaxHP != 650 || enforcer.GetZone() != ZoneRuins {
		t.Fatalf("configuracao invalida para Executor de Ferro 206: %+v", enforcer)
	}

	alphaWolf := mm.GetMob(207)
	if alphaWolf == nil || alphaWolf.MobType != protocol.MobTypeAlphaWolf || alphaWolf.MaxHP != 750 || alphaWolf.IsActive || alphaWolf.GetZone() != ZoneForest {
		t.Fatalf("configuracao invalida para Lobo Alfa 207: %+v", alphaWolf)
	}

	lycanAlpha := mm.GetMob(208)
	if lycanAlpha == nil || lycanAlpha.MobType != protocol.MobTypeLycanthropeAlpha || lycanAlpha.MaxHP != 2200 || lycanAlpha.IsActive || lycanAlpha.GetZone() != ZoneForest {
		t.Fatalf("configuracao invalida para Licantropo Alfa 208: %+v", lycanAlpha)
	}

	arachna := mm.GetMob(217)
	if arachna == nil || arachna.MobType != protocol.MobTypeArachnaQueen || arachna.MaxHP != 6800 || arachna.GetZone() != ZoneForest {
		t.Fatalf("configuracao invalida para Arachna 217: %+v", arachna)
	}

	ymir := mm.GetMob(226)
	if ymir == nil || ymir.MobType != protocol.MobTypeYmirFrostPatriarch || ymir.MaxHP != 5200 || ymir.GetZone() != ZoneRuins {
		t.Fatalf("configuracao invalida para Ymir 226: %+v", ymir)
	}

	vesperian := mm.GetMob(229)
	if vesperian == nil || vesperian.MobType != protocol.MobTypeLordVesperianVampire || vesperian.MaxHP != 8500 || vesperian.IsActive || vesperian.GetZone() != ZoneSanctuary {
		t.Fatalf("configuracao invalida para Lorde Vesperian 229: %+v", vesperian)
	}

	chimera := mm.GetMob(222)
	if chimera == nil || chimera.MobType != protocol.MobTypeStitchedChimeraZero || chimera.MaxHP != 2800 || chimera.GetZone() != ZoneAncientSewers {
		t.Fatalf("configuracao invalida para Quimera Costurada 222: %+v", chimera)
	}

	cultist := mm.GetMob(209)
	if cultist == nil || cultist.MobType != protocol.MobTypeDarkCultist || cultist.MaxHP != 400 || cultist.GetZone() != ZoneSanctuary {
		t.Fatalf("configuracao invalida para Cultista Sombrio 209: %+v", cultist)
	}

	gargoyle := mm.GetMob(211)
	if gargoyle == nil || gargoyle.MobType != protocol.MobTypeStoneGargoyle || gargoyle.MaxHP != 580 || gargoyle.GetZone() != ZoneSanctuary {
		t.Fatalf("configuracao invalida para Gargula de Pedra 211: %+v", gargoyle)
	}

	vex := mm.GetMob(212)
	if vex == nil || vex.MobType != protocol.MobTypeInquisitorVex || vex.MaxHP != 1400 || vex.GetZone() != ZoneSanctuary {
		t.Fatalf("configuracao invalida para Inquisidor Vex 212: %+v", vex)
	}

	vaelen := mm.GetMob(213)
	if vaelen == nil || vaelen.MobType != protocol.MobTypeCommanderVaelen || vaelen.MaxHP != 3200 || vaelen.GetZone() != ZoneRuins {
		t.Fatalf("configuracao invalida para Comandante Vaelen 213: %+v", vaelen)
	}

	malakor := mm.GetMob(214)
	if malakor == nil || malakor.MobType != protocol.MobTypeMalakorHeraldEclipse || malakor.MaxHP != 7500 || malakor.GetZone() != ZoneSanctuary {
		t.Fatalf("configuracao invalida para Malakor 214: %+v", malakor)
	}

	spider := mm.GetMob(215)
	if spider == nil || spider.MobType != protocol.MobTypeMistWeaverSpider || spider.MaxHP != 380 || spider.GetZone() != ZoneForest {
		t.Fatalf("configuracao invalida para Aranha Tecela 215: %+v", spider)
	}

	slime := mm.GetMob(218)
	if slime == nil || slime.MobType != protocol.MobTypeAcidCorrosiveSlime || slime.MaxHP != 320 || slime.GetZone() != ZoneAncientSewers {
		t.Fatalf("configuracao invalida para Lodo Acido 218: %+v", slime)
	}

	scorpion := mm.GetMob(220)
	if scorpion == nil || scorpion.MobType != protocol.MobTypeAbyssalScorpion || scorpion.MaxHP != 540 || scorpion.GetZone() != ZoneAncientSewers {
		t.Fatalf("configuracao invalida para Escorpiao Abissal 220: %+v", scorpion)
	}

	iceGolem := mm.GetMob(223)
	if iceGolem == nil || iceGolem.MobType != protocol.MobTypeAncientIceGolem || iceGolem.MaxHP != 720 || iceGolem.GetZone() != ZoneRuins {
		t.Fatalf("configuracao invalida para Golem de Gelo 223: %+v", iceGolem)
	}

	frostDrake := mm.GetMob(225)
	if frostDrake == nil || frostDrake.MobType != protocol.MobTypeWildFrostDrake || frostDrake.MaxHP != 950 || frostDrake.GetZone() != ZoneRuins {
		t.Fatalf("configuracao invalida para Draco de Geada 225: %+v", frostDrake)
	}

	bloodGuard := mm.GetMob(227)
	if bloodGuard == nil || bloodGuard.MobType != protocol.MobTypeVesperianBloodGuard || bloodGuard.MaxHP != 680 || bloodGuard.GetZone() != ZoneSanctuary {
		t.Fatalf("configuracao invalida para Guarda Sanguinario 227: %+v", bloodGuard)
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

	// Mata o mob comum
	_, _, hp, dead := wolf.TakeDamage(250)
	if hp != 0 || !dead || wolf.IsAlive {
		t.Fatalf("mob deveria estar morto: hp=%d, dead=%v, alive=%v", hp, dead, wolf.IsAlive)
	}

	// Não deve renascer antes dos 75s (ex: aos 70s)
	wolf.DeadAt = time.Now().Add(-70 * time.Second)
	if wolf.CheckRespawn() {
		t.Fatalf("mob comum renasceu prematuramente antes de 75s")
	}

	// Deve renascer aos 76s
	wolf.DeadAt = time.Now().Add(-76 * time.Second)
	if !wolf.CheckRespawn() {
		t.Fatalf("mob comum deveria ter renascido apos 75s")
	}

	if !wolf.IsAlive || wolf.HP != 220 || wolf.PosX != 16.0 || wolf.PosZ != -8.0 {
		t.Fatalf("dados do mob renascido incorretos: %+v", wolf)
	}

	// Testa Mini-Boss / Boss (AlphaWolf) com timer de 180s
	boss := NewMob(206, "Lobo Alfa", protocol.MobTypeAlphaWolf, 0.0, 0.0, 0.0, 800, 3.5)
	boss.TakeDamage(999)

	boss.DeadAt = time.Now().Add(-170 * time.Second)
	if boss.CheckRespawn() {
		t.Fatalf("boss renasceu prematuramente antes de 180s")
	}

	boss.DeadAt = time.Now().Add(-181 * time.Second)
	if !boss.CheckRespawn() {
		t.Fatalf("boss deveria ter renascido apos 180s")
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

func TestMobStopDistanceAndBoundsClamping(t *testing.T) {
	// 1. Testa StopDistance (1.6m para comum, 2.2m para Boss) durante perseguição
	wolf := NewMob(201, "Lobo", protocol.MobTypeMistWolf, 0.0, 0.0, 0.0, 100, 10.0)
	wolf.SetState(protocol.MobStateChasing)

	// Move em direção ao jogador em (0.0, 1.0) - que está a 1.0m, menor que StopDistance (1.6m)
	wolf.MoveTowards(0.0, 1.0, 10.0, 0.1)
	if wolf.PosX != 0.0 || wolf.PosZ != 0.0 {
		t.Fatalf("mob comum não deveria ter andado mais perto que a StopDistance (1.6m): Pos=(%.2f, %.2f)", wolf.PosX, wolf.PosZ)
	}

	// Move em direção ao jogador em (0.0, 5.0) com velocidade alta
	wolf.MoveTowards(0.0, 5.0, 100.0, 1.0)
	// Deve parar a exatamente 1.6m de (0.0, 5.0), ou seja, em Z = 3.4m
	if math.Abs(float64(wolf.PosZ-3.4)) > 0.05 {
		t.Fatalf("mob deveria ter parado em Z=3.4m (StopDistance 1.6m), mas parou em Z=%.2f", wolf.PosZ)
	}

	// 2. Boss (Executor de Ferro) deve parar a 2.2m
	boss := NewMob(206, "Executor", protocol.MobTypeIronEnforcer, 0.0, 0.0, 0.0, 650, 100.0)
	boss.SetState(protocol.MobStateChasing)
	boss.MoveTowards(0.0, 10.0, 100.0, 1.0)
	// Deve parar a 2.2m de (0.0, 10.0), ou seja, em Z = 7.8m
	if math.Abs(float64(boss.PosZ-7.8)) > 0.05 {
		t.Fatalf("boss deveria ter parado em Z=7.8m (StopDistance 2.2m), mas parou em Z=%.2f", boss.PosZ)
	}

	// 3. Testa ClampToMapBounds / ClampToZoneBounds: não deve permitir coordenadas fora de [-295.0, +295.0]
	wolf.MoveTowards(500.0, 500.0, 800.0, 1.0)
	if wolf.PosX > 295.0 || wolf.PosZ > 295.0 {
		t.Fatalf("mob ultrapassou os limites seguros do mapa [-295, 295]: Pos=(%.2f, %.2f)", wolf.PosX, wolf.PosZ)
	}
}

func TestMobDamageDealers(t *testing.T) {
	mob := NewMob(201, "Lobo", protocol.MobTypeMistWolf, 0, 0, 0, 200, 4.0)
	mob.TakeDamage(50, 10)
	mob.TakeDamage(30, 20)
	mob.TakeDamage(20, 10)

	dealers := mob.GetDamageDealers()
	if len(dealers) != 2 || dealers[10] != 70 || dealers[20] != 30 {
		t.Fatalf("rastreamento de dano incorreto: %+v", dealers)
	}
}
