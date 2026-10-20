package world

import (
	"testing"
)

func TestNPCWaypointPatrol(t *testing.T) {
	clock := NewWorldClock(12.0)
	guard := NewNPC(105, "Capitão Randel", 0.0, 0.0, 24.0, "", clock, nil)

	waypoints := []Waypoint{
		{X: 0.0, Z: 24.0},
		{X: 0.0, Z: 3.0},
		{X: 0.0, Z: -24.0},
	}

	guard.SetPatrolRoute(waypoints, 2.8, 3.0)

	if !guard.IsPatrolling {
		t.Fatalf("esperava guarda em modo de patrulha")
	}

	// Como o guarda já inicia em (0, 24) e o waypoint 0 é (0, 24), a distância é 0 <= 0.4m
	guard.UpdateMovement(0.033) // 1 tick a 30 Hz
	if guard.State != 0 {
		t.Fatalf("esperava guarda no estado 0 (inspecionando), obteve %d", guard.State)
	}
	if guard.WaitTimer <= 0 {
		t.Fatalf("esperava WaitTimer ativo para inspeção")
	}

	// Simula avanço do tempo de inspeção (3.0 segundos)
	for i := 0; i < 95; i++ {
		guard.UpdateMovement(0.033)
	}

	// Agora o guarda deve ter finalizado a inspeção e avançado para o waypoint 1 (0, 3)
	if guard.CurrentWaypointIdx != 1 {
		t.Fatalf("esperava avanço para waypoint 1, obteve índice %d", guard.CurrentWaypointIdx)
	}
	if guard.TargetZ != 3.0 {
		t.Fatalf("esperava TargetZ = 3.0, obteve %f", guard.TargetZ)
	}
	if guard.State != 1 {
		t.Fatalf("esperava guarda andando (State = 1), obteve %d", guard.State)
	}
}
