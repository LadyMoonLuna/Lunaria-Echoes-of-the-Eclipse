package world

import (
	"fmt"
	"math"
)

// Arrastar corpos: o jogador prende o corpo e o puxa (corda curta) ou empurra (encostando nele).
// O peso vem da massa da criatura e a força do jogador decide se ele consegue mover e a que
// velocidade. Arrastar raspa o couro no chão: a integridade cai a cada metro (empurrar raspa mais,
// e pela água quase não estraga), e isso derruba a qualidade na autópsia.
const (
	DragRopeLength      float32 = 1.6 // além disso o corpo é puxado
	DragPushDistance    float32 = 0.9 // mais perto que isso o corpo é empurrado
	DragGrabRange       float32 = 2.8 // alcance para agarrar
	DragSnapDistance    float32 = 6.0 // longe demais (teleporte, portal): solta
	DragCapacityMult    float32 = 3.0 // no chão arrasta-se até 3x o que se carrega nas costas
	DragPullWearPerM    float32 = 0.006
	DragPushWearPerM    float32 = 0.012
	DragWaterWearFactor float32 = 0.3 // a água leva o corpo: quase não raspa
	DragMinIntegrity    float32 = 0.35
)

// DragCapacityKg: quanto o jogador consegue arrastar.
func (p *Player) DragCapacityKg() float32 {
	_, maxW, _ := p.WeightStatus()
	return maxW * DragCapacityMult
}

// DragSpeedMult: velocidade do jogador arrastando um corpo desta massa (0.25 a 0.95).
func DragSpeedMult(massKg, capacityKg float32) float32 {
	if capacityKg <= 0 {
		return 0.25
	}
	return float32(math.Max(0.25, math.Min(0.95, float64(1-0.75*massKg/capacityKg))))
}

// CanDrag confere se o jogador tem força para mover o corpo.
func CanDrag(massKg, capacityKg float32) error {
	if massKg > capacityKg {
		return fmt.Errorf("pesado demais: o corpo tem %.0f kg e você só arrasta até %.0f kg", massKg, capacityKg)
	}
	return nil
}

// dragWearMassFactor: corpos pesados raspam mais (0.6x a 2.0x).
func dragWearMassFactor(massKg float32) float32 {
	return float32(math.Min(2.0, 0.6+float64(massKg)/250))
}

// StepDrag move o corpo seguindo o jogador (puxar ou empurrar) e desgasta o couro.
// Devolve quanto o corpo andou e se foi empurrado.
func (c *Corpse) StepDrag(px, pz float32) (moved float32, pushed bool) {
	c.Mu.Lock()
	defer c.Mu.Unlock()
	dx, dz := px-c.PosX, pz-c.PosZ
	d := float32(math.Sqrt(float64(dx*dx + dz*dz)))
	if d < 0.001 {
		return 0, false
	}
	ux, uz := dx/d, dz/d
	switch {
	case d > DragRopeLength: // puxar: o corpo vem atrás até a corda ficar frouxa
		moved = d - DragRopeLength
		c.PosX += ux * moved
		c.PosZ += uz * moved
	case d < DragPushDistance: // empurrar: o jogador encostou e o corpo desliza à frente
		moved = DragPushDistance - d
		c.PosX -= ux * moved
		c.PosZ -= uz * moved
		pushed = true
	default:
		return 0, false
	}
	c.RotY = float32(math.Atan2(float64(-ux), float64(-uz)))
	wear := DragPullWearPerM
	if pushed {
		wear = DragPushWearPerM
	}
	wear *= dragWearMassFactor(c.MassKg)
	if IsRiverWater(c.ZoneID, c.PosX, c.PosZ) {
		wear *= DragWaterWearFactor
	}
	c.HideIntegrity = float32(math.Max(float64(DragMinIntegrity), float64(c.HideIntegrity-wear*moved)))
	return moved, pushed
}

// IntegrityQualityFactor: o couro sofre todo o desgaste; os órgãos internos só se machucam um pouco.
func (c *Corpse) IntegrityQualityFactor(organType uint8) float32 {
	c.Mu.RLock()
	defer c.Mu.RUnlock()
	if organType == OrganPelt {
		return c.HideIntegrity
	}
	return 0.7 + 0.3*c.HideIntegrity
}
