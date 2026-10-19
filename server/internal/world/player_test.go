package world

import (
	"testing"

	"lunaria/server/internal/protocol"
)

func TestCalculateStatsByClassAndRace(t *testing.T) {
	// Espadachim (140, 100) + Valeriano (+10, +10) = (150, 110)
	hp, stam := CalculateStatsByClassAndRace(protocol.ClassSwordsman, protocol.RaceValerian)
	if hp != 150 || stam != 110 {
		t.Fatalf("Esperava (150, 110) para Espadachim Valeriano, obteve (%d, %d)", hp, stam)
	}

	// Batedor (105, 135) + Noctari (+0, +20) = (105, 155)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassScout, protocol.RaceNoctari)
	if hp != 105 || stam != 155 {
		t.Fatalf("Esperava (105, 155) para Batedor Noctari, obteve (%d, %d)", hp, stam)
	}

	// Iniciado (95, 110) + Kharad (+30, +0) = (125, 110)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassInitiate, protocol.RaceKharad)
	if hp != 125 || stam != 110 {
		t.Fatalf("Esperava (125, 110) para Iniciado Kharad, obteve (%d, %d)", hp, stam)
	}

	// Acólito (125, 105) + Dhampir (+10, +15) = (135, 120)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassAcolyte, protocol.RaceDhampir)
	if hp != 135 || stam != 120 {
		t.Fatalf("Esperava (135, 120) para Acólito Dhampir, obteve (%d, %d)", hp, stam)
	}

	// Espadachim (140, 100) + Varkai (+15, +10) = (155, 110)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassSwordsman, protocol.RaceVarkai)
	if hp != 155 || stam != 110 {
		t.Fatalf("Esperava (155, 110) para Espadachim Varkai, obteve (%d, %d)", hp, stam)
	}
}

func TestKharadDamageReduction(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.SetIdentity(protocol.RaceKharad, protocol.ClassSwordsman)

	initialHP := p.HP
	// Dano bruto de 100 deve ser reduzido em 20% para 80
	newHP, dead := p.TakeDamage(100)
	if dead {
		t.Fatalf("jogador nao deveria ter morrido")
	}
	expectedHP := initialHP - 80
	if newHP != expectedHP {
		t.Fatalf("esperava HP %d apos reducao de 20%%, obteve %d", expectedHP, newHP)
	}
}

func TestProjectileManager(t *testing.T) {
	pm := NewProjectileManager()
	proj := pm.Spawn(1, protocol.ProjTypePhysicalArrow, 0, 1.2, 0, 0, 2.0, 24.0, 16.0)

	if proj.ID < 1000 {
		t.Fatalf("ID do projetil invalido: %d", proj.ID)
	}
	if proj.DirZ != 1.0 || proj.DirX != 0.0 {
		t.Fatalf("direcao nao foi normalizada: (%.2f, %.2f)", proj.DirX, proj.DirZ)
	}

	active := pm.GetActiveProjectiles()
	if len(active) != 1 {
		t.Fatalf("esperava 1 projetil ativo, obteve %d", len(active))
	}

	// Marca como percorrido alem do MaxRange
	proj.Traveled = 17.0
	pm.Cleanup()

	active = pm.GetActiveProjectiles()
	if len(active) != 0 {
		t.Fatalf("projetil deveria ter sido limpo apos atingir MaxRange")
	}
}
