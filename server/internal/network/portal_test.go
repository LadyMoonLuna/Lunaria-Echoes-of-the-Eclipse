package network

import (
	"net"
	"testing"

	"lunaria/server/internal/world"
)

// setupMockServer cria um servidor mínimo para testes de rede e portais.
func setupMockServer() *Server {
	clock := world.NewWorldClock(16.0)
	server := &Server{
		players:       make(map[uint32]*world.Player),
		npcs:          make(map[uint32]*world.NPC),
		dummies:       make(map[uint32]*world.TrainingDummy),
		mobManager:    world.NewMobManager(),
		corpseManager: world.NewCorpseManager(),
		clock:         clock,
	}
	return server
}

func TestPortalTravelCardinalZones(t *testing.T) {
	server := setupMockServer()

	// Cria conexão mock via net.Pipe
	clientConn, serverConn := net.Pipe()
	defer clientConn.Close()
	defer serverConn.Close()

	player := world.NewPlayer(1, serverConn, 0.0, 1.5, 0.0)
	server.players[1] = player

	// 1. Início na Vila do Refúgio (Zone 0)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria iniciar na Zona 0 (Vila), obteve %d", player.GetZone())
	}

	// 2. Viagem para Floresta (Portal 1: Vila -> Floresta)
	go func() {
		// Drena dados enviados na conexão mock para não travar
		buf := make([]byte, 1024)
		for {
			_, err := clientConn.Read(buf)
			if err != nil {
				return
			}
		}
	}()

	server.handlePortalTravel(1, 0, 1)
	if player.GetZone() != world.ZoneForest {
		t.Fatalf("jogador deveria estar na Zona 1 (Floresta), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz := player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != 275.0 {
		t.Fatalf("coordenada de chegada incorreta na Floresta: (%.1f, %.1f), esperado (0, 275)", px, pz)
	}

	// 3. Retorno da Floresta para a Vila (Portal 2: Floresta -> Vila)
	server.handlePortalTravel(1, 0, 2)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria ter retornado à Zona 0 (Vila), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != -275.0 {
		t.Fatalf("coordenada de retorno na Vila incorreta: (%.1f, %.1f), esperado (0, -275)", px, pz)
	}

	// 4. Viagem para o Planalto dos Ventos (Portal 3: Vila -> Planalto, a caminho das Ruínas)
	server.handlePortalTravel(1, 0, 3)
	if player.GetZone() != world.ZoneWindPlateau {
		t.Fatalf("jogador deveria estar na Zona 13 (Planalto), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != -275.0 {
		t.Fatalf("coordenada de chegada incorreta no Planalto: (%.1f, %.1f), esperado (0, -275)", px, pz)
	}

	// 5. Retorno do Planalto para a Vila (Portal 4: Planalto -> Vila)
	server.handlePortalTravel(1, 0, 4)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria ter retornado à Zona 0 (Vila), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != 275.0 {
		t.Fatalf("coordenada de retorno na Vila incorreta: (%.1f, %.1f), esperado (0, 275)", px, pz)
	}

	// 6. Viagem para Santuário do Eclipse (Portal 5: Vila -> Santuário)
	server.handlePortalTravel(1, 0, 5)
	if player.GetZone() != world.ZoneSanctuary {
		t.Fatalf("jogador deveria estar na Zona 3 (Santuário), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 275.0 || pz != 0.0 {
		t.Fatalf("coordenada de chegada no Santuário incorreta: (%.1f, %.1f), esperado (275, 0)", px, pz)
	}

	// 7. Retorno do Santuário para a Vila (Portal 6: Santuário -> Vila)
	server.handlePortalTravel(1, 0, 6)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria ter retornado à Zona 0 (Vila), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != -275.0 || pz != 0.0 {
		t.Fatalf("coordenada de retorno na Vila incorreta: (%.1f, %.1f), esperado (-275, 0)", px, pz)
	}

	// 8. Viagem para as Colinas de Basalto (Portal 7: Vila -> Colinas, a caminho das Cinzas)
	server.handlePortalTravel(1, 0, 7)
	if player.GetZone() != world.ZoneBasaltHills {
		t.Fatalf("jogador deveria estar na Zona 15 (Colinas de Basalto), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != -275.0 || pz != 0.0 {
		t.Fatalf("coordenada de chegada na Fronteira incorreta: (%.1f, %.1f), esperado (-275, 0)", px, pz)
	}

	// 9. Retorno da Fronteira para a Vila (Portal 8: Fronteira -> Vila)
	server.handlePortalTravel(1, 0, 8)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria ter retornado à Zona 0 (Vila), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 275.0 || pz != 0.0 {
		t.Fatalf("coordenada de retorno na Vila incorreta: (%.1f, %.1f), esperado (275, 0)", px, pz)
	}
}

func TestBlackMarketNightRestriction(t *testing.T) {
	server := setupMockServer()

	clientConn, serverConn := net.Pipe()
	defer clientConn.Close()
	defer serverConn.Close()

	player := world.NewPlayer(1, serverConn, -45.0, 1.5, 40.0)
	server.players[1] = player

	go func() {
		buf := make([]byte, 1024)
		for {
			_, err := clientConn.Read(buf)
			if err != nil {
				return
			}
		}
	}()

	// 1. Testa entrada no Mercado Negro DURANTE O DIA (ex: 12h) -> DEVE BLOQUEAR!
	server.clock.SetHour(12)
	server.handlePortalTravel(1, 0, 13)

	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("entrada no Mercado Negro às 12h deveria ser bloqueada! Zona obtida: %d", player.GetZone())
	}

	// 2. Testa entrada no Mercado Negro às 06h (Início do Dia) -> DEVE BLOQUEAR!
	server.clock.SetHour(6)
	server.handlePortalTravel(1, 0, 13)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("entrada no Mercado Negro às 06h deveria ser bloqueada! Zona obtida: %d", player.GetZone())
	}

	// 3. Testa entrada no Mercado Negro À NOITE (ex: 20h) -> DEVE PERMITIR!
	server.clock.SetHour(20)
	server.handlePortalTravel(1, 0, 13)

	if player.GetZone() != world.ZoneBlackMarket {
		t.Fatalf("entrada no Mercado Negro às 20h deveria ser permitida! Zona obtida: %d", player.GetZone())
	}

	player.Mu.RLock()
	px, pz := player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != -30.0 {
		t.Fatalf("coordenada de chegada no Mercado Negro incorreta: (%.1f, %.1f), esperado (0, -30)", px, pz)
	}

	// 4. Testa SAÍDA do Mercado Negro durante o DIA (ex: 10h da manhã) -> SEMPRE PERMITIDO!
	server.clock.SetHour(10)
	server.handlePortalTravel(1, 0, 14)

	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("saída do Mercado Negro para a Vila deve ser SEMPRE permitida! Zona obtida: %d", player.GetZone())
	}

	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != -45.0 || pz != 35.0 {
		t.Fatalf("coordenada de saída do Mercado Negro na Vila incorreta: (%.1f, %.1f), esperado (-45, 35)", px, pz)
	}
}

func TestInternalAndSubterraneanPortals(t *testing.T) {
	server := setupMockServer()

	clientConn, serverConn := net.Pipe()
	defer clientConn.Close()
	defer serverConn.Close()

	player := world.NewPlayer(1, serverConn, 0.0, 1.5, 0.0)
	server.players[1] = player

	go func() {
		buf := make([]byte, 1024)
		for {
			_, err := clientConn.Read(buf)
			if err != nil {
				return
			}
		}
	}()

	// 1. Igreja da Luz (Portal 9: Vila -> Igreja)
	server.handlePortalTravel(1, 0, 9)
	if player.GetZone() != world.ZoneChurch {
		t.Fatalf("jogador deveria estar na Igreja (Zona 5), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz := player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != -22.0 {
		t.Fatalf("coordenada de chegada na Igreja incorreta: (%.1f, %.1f)", px, pz)
	}

	// Saída da Igreja (Portal 10: Igreja -> Vila)
	server.handlePortalTravel(1, 0, 10)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria estar na Vila (Zona 0), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != -45.0 || pz != -35.0 {
		t.Fatalf("coordenada de retorno da Igreja incorreta: (%.1f, %.1f)", px, pz)
	}

	// 2. Torre do Arcanista (Portal 11: Vila -> Torre)
	server.handlePortalTravel(1, 0, 11)
	if player.GetZone() != world.ZoneMageTower {
		t.Fatalf("jogador deveria estar na Torre do Arcanista (Zona 6), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != -22.0 {
		t.Fatalf("coordenada de chegada na Torre incorreta: (%.1f, %.1f)", px, pz)
	}

	// Saída da Torre do Arcanista (Portal 12: Torre -> Vila)
	server.handlePortalTravel(1, 0, 12)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria estar na Vila (Zona 0), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 45.0 || pz != -35.0 {
		t.Fatalf("coordenada de retorno da Torre incorreta: (%.1f, %.1f)", px, pz)
	}

	// 3. Esgotos Antigos (Portal 15: Vila -> Esgotos)
	server.handlePortalTravel(1, 0, 15)
	if player.GetZone() != world.ZoneAncientSewers {
		t.Fatalf("jogador deveria estar nos Esgotos Antigos (Zona 8), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != 0.0 || pz != 0.0 {
		t.Fatalf("coordenada de chegada nos Esgotos incorreta: (%.1f, %.1f)", px, pz)
	}

	// Saída dos Esgotos (Portal 16: Esgotos -> Vila)
	server.handlePortalTravel(1, 0, 16)
	if player.GetZone() != world.ZoneVillage {
		t.Fatalf("jogador deveria estar na Vila (Zona 0), obteve %d", player.GetZone())
	}
	player.Mu.RLock()
	px, pz = player.PosX, player.PosZ
	player.Mu.RUnlock()
	if px != -55.0 || pz != -50.0 {
		t.Fatalf("coordenada de retorno dos Esgotos incorreta: (%.1f, %.1f)", px, pz)
	}
}

// Todas as zonas de transição são alcançáveis a pé e cada portal tem o seu par de volta.
func TestEveryPortalHasReturnAndZonesAreReachable(t *testing.T) {
	for id, p := range world.OfficialPortals {
		if _, ok := world.FindPortal(p.TargetZoneID, p.FromZoneID); !ok {
			t.Fatalf("portal %d (%d -> %d) não tem caminho de volta", id, p.FromZoneID, p.TargetZoneID)
		}
	}
	seen := map[uint8]bool{world.ZoneVillage: true}
	queue := []uint8{world.ZoneVillage}
	for len(queue) > 0 {
		z := queue[0]
		queue = queue[1:]
		for _, p := range world.OfficialPortals {
			if p.FromZoneID == z && !seen[p.TargetZoneID] {
				seen[p.TargetZoneID] = true
				queue = append(queue, p.TargetZoneID)
			}
		}
	}
	for z := uint8(0); z < world.ZoneCount; z++ {
		if !seen[z] {
			t.Fatalf("zona %d (%s) inalcançável", z, world.GetZoneName(z))
		}
	}
}
