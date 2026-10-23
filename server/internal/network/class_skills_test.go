package network

import (
	"testing"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

func addTestMob(s *Server, id uint32, x, z float32, hp uint16) *world.Mob {
	m := &world.Mob{ID: id, PosX: x, PosZ: z, HP: hp, MaxHP: 1000, IsAlive: true, IsActive: true}
	s.mobManager.Mobs[id] = m
	return m
}

func TestBasicClassSkillAreaHitsEveryTargetInRange(t *testing.T) {
	s := setupMockServer()
	player := world.NewPlayer(1, nil, 0, 1.5, 0)
	near := addTestMob(s, 1, 3, 0, 1000)
	edge := addTestMob(s, 2, 0, -4.4, 1000)
	far := addTestMob(s, 3, 6, 0, 1000)

	// Guerreiro F (Julgamento da Espada): círculo de 4.5m
	shape, ok := basicClassSkillShape(protocol.ClassWarrior, protocol.ActionSkillF)
	if !ok {
		t.Fatal("Julgamento da Espada deveria ter área")
	}
	hits := s.applyBasicClassSkill(player, protocol.ClassWarrior, protocol.ActionSkillF, 0, 0, 0, 0, 0, -1, shape, 100, 0)
	if hits != 2 || near.HP != 900 || edge.HP != 900 || far.HP != 1000 {
		t.Fatalf("esperava 2 alvos atingidos (HP 900, 900, 1000), obteve %d (HP %d, %d, %d)", hits, near.HP, edge.HP, far.HP)
	}
}

func TestWarriorUltimateExecutesLowHPTargets(t *testing.T) {
	s := setupMockServer()
	player := world.NewPlayer(1, nil, 0, 1.5, 0)
	healthy := addTestMob(s, 1, 2, 0, 1000)
	wounded := addTestMob(s, 2, -2, 0, 300) // 30% de vida

	shape, _ := basicClassSkillShape(protocol.ClassWarrior, protocol.ActionSkillF)
	s.applyBasicClassSkill(player, protocol.ClassWarrior, protocol.ActionSkillF, 0, 0, 0, 0, 0, -1, shape, 100, 0)
	if healthy.HP != 900 {
		t.Fatalf("alvo saudável deveria levar 100, ficou com %d", healthy.HP)
	}
	if wounded.HP != 160 {
		t.Fatalf("alvo com <35%% de vida deveria levar 140 (+40%%), ficou com %d", wounded.HP)
	}
}

func TestBasicClassSkillConeAndSingleTarget(t *testing.T) {
	s := setupMockServer()
	player := world.NewPlayer(1, nil, 0, 1.5, 0)
	front := addTestMob(s, 1, 0, -5, 1000)
	front2 := addTestMob(s, 2, 0, -7, 1000)
	behind := addTestMob(s, 3, 0, 5, 1000)

	// Alfaiate Q (Teia de Fios): cone de 8m à frente, mirando para -Z
	shape, _ := basicClassSkillShape(protocol.ClassWarTailor, protocol.ActionSkillQ)
	s.applyBasicClassSkill(player, protocol.ClassWarTailor, protocol.ActionSkillQ, 0, 0, 0, 0, 0, -1, shape, 50, 0)
	if front.HP != 950 || front2.HP != 950 || behind.HP != 1000 {
		t.Fatalf("cone deveria atingir só os da frente: HP %d, %d, %d", front.HP, front2.HP, behind.HP)
	}

	// Domador Q (Estalo do Chicote): só o alvo mais próximo, a até 9m
	shape, _ = basicClassSkillShape(protocol.ClassTamer, protocol.ActionSkillQ)
	s.applyBasicClassSkill(player, protocol.ClassTamer, protocol.ActionSkillQ, 0, 0, 0, 0, 0, -1, shape, 50, 0)
	if front.HP != 900 || front2.HP != 950 {
		t.Fatalf("chicote deveria atingir só o mais próximo: HP %d, %d", front.HP, front2.HP)
	}
}

func TestBlacksmithAnvilCracksArmor(t *testing.T) {
	s := setupMockServer()
	player := world.NewPlayer(1, nil, 0, 1.5, 0)
	mob := addTestMob(s, 1, 0, -2, 1000)

	shape, _ := basicClassSkillShape(protocol.ClassBlacksmith, protocol.ActionSkillQ)
	s.applyBasicClassSkill(player, protocol.ClassBlacksmith, protocol.ActionSkillQ, 0, 0, 0, 0, 0, -1, shape, 100, 0)
	if dealt, _, _, _ := mob.TakeDamage(100); dealt != 130 {
		t.Fatalf("depois da Bigorna o alvo deveria receber +30%%: esperava 130, obteve %d", dealt)
	}
}

func TestShadowStepLandsBehindTarget(t *testing.T) {
	s := setupMockServer()
	player := world.NewPlayer(1, nil, 0, 1.5, 0)
	addTestMob(s, 1, 0, -6, 1000)

	bx, bz, ok := s.shadowStepTarget(player, 0, 0, 0, -1)
	if !ok || bx != 0 || bz != -7 {
		t.Fatalf("esperava teleporte para (0, -7) atrás do alvo, obteve (%.1f, %.1f) ok=%v", bx, bz, ok)
	}
	if _, _, ok := s.shadowStepTarget(player, 0, 0, 0, 1); ok {
		t.Fatal("não deveria achar alvo mirando para o lado oposto")
	}
}
