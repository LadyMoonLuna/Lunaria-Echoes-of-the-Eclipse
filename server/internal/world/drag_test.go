package world

import "testing"

func TestDragPullPushAndWear(t *testing.T) {
	c := NewCorpse(1, 1, 25, "Javali Selvagem", 0, 0, 0, 0, 1, 0) // 90 kg
	c.ZoneID = ZoneForest
	// Puxar: o jogador se afasta 10 m e o corpo vem atrás até a corda ficar frouxa
	moved, pushed := c.StepDrag(0, 10)
	if pushed || moved < 8.3 || moved > 8.5 || c.PosZ < 8.3 {
		t.Fatalf("puxar errado: andou %.2f (z=%.2f)", moved, c.PosZ)
	}
	pulled := 1 - c.HideIntegrity
	if pulled <= 0 {
		t.Fatal("arrastar deveria raspar o couro")
	}
	// Empurrar: o jogador encosta no corpo
	before := c.HideIntegrity
	_, pushed = c.StepDrag(c.PosX, c.PosZ-0.3)
	if !pushed || c.HideIntegrity >= before {
		t.Fatal("empurrar deveria mover e desgastar")
	}
	// Muito arrasto: o couro nunca some de vez
	for i := 0; i < 400; i++ {
		c.StepDrag(c.PosX, c.PosZ+5)
	}
	if c.HideIntegrity != DragMinIntegrity {
		t.Fatalf("integridade mínima: %.2f", c.HideIntegrity)
	}
	if f := c.IntegrityQualityFactor(OrganPelt); f != DragMinIntegrity {
		t.Fatal("o couro leva todo o desgaste")
	}
	if f := c.IntegrityQualityFactor(OrganHeart); f <= DragMinIntegrity || f >= 1 {
		t.Fatal("órgãos internos sofrem pouco")
	}
}

func TestDragWeightAndStrength(t *testing.T) {
	if err := CanDrag(5000, 300); err == nil {
		t.Fatal("ninguém arrasta um elefante sozinho")
	}
	light, heavy := DragSpeedMult(3, 300), DragSpeedMult(280, 300)
	if light < 0.94 || heavy > 0.35 {
		t.Fatalf("velocidade pelo peso: leve %.2f, pesado %.2f", light, heavy)
	}
	small := NewCorpse(2, 2, 25, "x", 0, 0, 0, 0, 1, 0)
	bigWear := NewCorpse(3, 3, 22, "y", 0, 0, 0, 0, 1, 0) // 3000 kg
	small.StepDrag(0, 6)
	bigWear.StepDrag(0, 6)
	if bigWear.HideIntegrity >= small.HideIntegrity {
		t.Fatal("corpos pesados raspam mais")
	}
}
