package world

import (
	"testing"

	"lunaria/server/internal/protocol"
)

func TestManaByRaceAttributesAndCosts(t *testing.T) {
	mage := NewPlayer(1, nil, 0, 0, 0)
	mage.SetIdentity(protocol.RaceFairy, protocol.ClassMage)
	orc := NewPlayer(2, nil, 0, 0, 0)
	orc.SetIdentity(protocol.RaceOrc, protocol.ClassMage)
	if mage.MaxMana <= orc.MaxMana*2 {
		t.Fatalf("Faelith Arcanista deveria ter muito mais Mana que Orkhan Arcanista: %d x %d", mage.MaxMana, orc.MaxMana)
	}
	if mage.Mana != float32(mage.MaxMana) {
		t.Fatalf("Mana deveria começar cheia: %.0f/%d", mage.Mana, mage.MaxMana)
	}

	// INT aumenta a Mana máxima (+6 por ponto, x Tier x Classe)
	before := mage.MaxMana
	mage.Mu.Lock()
	mage.AllocINT += 10
	mage.recalculateStatsLocked()
	mage.Mu.Unlock()
	if mage.MaxMana != before+uint16(float32(10*ManaPerINT)*1.40) {
		t.Fatalf("10 de INT deveria somar %d de Mana máxima, somou %d", uint16(float32(10*ManaPerINT)*1.40), mage.MaxMana-before)
	}

	// ESP acelera a regeneração
	if ManaRegenPerSecond(protocol.RaceFairy, 20) <= ManaRegenPerSecond(protocol.RaceFairy, 5) {
		t.Fatal("mais ESP deveria regenerar mais Mana")
	}

	// Arcanista paga a habilidade em Mana; Espadachim, em Stamina
	if st, mn := SkillCost(protocol.ClassMage, protocol.ActionSkillF); st != 0 || mn < 29.99 || mn > 30.01 {
		t.Fatalf("F do Arcanista deveria custar 30 de Mana, custou %.0f Stamina / %.0f Mana", st, mn)
	}
	if st, mn := SkillCost(protocol.ClassWarrior, protocol.ActionSkillF); st != 25 || mn != 0 {
		t.Fatalf("F do Espadachim deveria custar 25 de Stamina, custou %.0f / %.0f", st, mn)
	}
	mage.Mu.Lock()
	mage.Mana = 10
	mage.Mu.Unlock()
	if mage.PaySkillCost(0, 30) {
		t.Fatal("sem Mana suficiente a habilidade não deveria sair")
	}

	// Manamante (Sangue Azul): o que falta de Mana sai da Vida
	mm := NewPlayer(3, nil, 0, 0, 0)
	mm.SetIdentity(protocol.RaceManamancer, protocol.ClassMage)
	mm.Mu.Lock()
	mm.Mana = 10
	hp := mm.HP
	mm.Mu.Unlock()
	if !mm.PaySkillCost(0, 30) || mm.Mana != 0 || mm.HP != hp-20 {
		t.Fatalf("Manamante deveria pagar 10 de Mana e 20 de Vida: Mana %.0f, Vida %d->%d", mm.Mana, hp, mm.HP)
	}
}
