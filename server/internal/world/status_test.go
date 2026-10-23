package world

import (
	"testing"
	"time"
)

func TestStealthAndInvisibility(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	if !p.CanBeDetected(8) {
		t.Fatal("jogador normal deve ser percebido")
	}
	p.SetStealth(time.Second)
	if p.CanBeDetected(5) || !p.CanBeDetected(2) {
		t.Fatal("furtivo só deve ser percebido de perto")
	}
	p.SetInvisible(time.Second, true)
	if p.CanBeDetected(1) {
		t.Fatal("invisível nunca deve ser percebido")
	}
	p.BreakStealth()
	if !p.CanBeDetected(8) {
		t.Fatal("atacar revela o jogador")
	}
	if p.ConsumeAmbushMult() != AmbushDamageMult || p.ConsumeAmbushMult() != 1.0 {
		t.Fatal("emboscada vale para um único golpe")
	}
}

func TestPunchComboAndPolymorph(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	if p.RegisterPunch() || p.RegisterPunch() || !p.RegisterPunch() {
		t.Fatal("o escudo nasce no terceiro soco")
	}
	m := NewMob(1, "Lobo", 1, 0, 0, 0, 100, 3)
	m.ApplyPolymorph(time.Second)
	if !m.IsPolymorphed() {
		t.Fatal("monstro deveria estar polimorfado")
	}
}
