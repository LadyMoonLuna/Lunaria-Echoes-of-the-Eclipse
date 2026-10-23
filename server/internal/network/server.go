package network

import (
	"context"
	"fmt"
	"io"
	"log"
	"math"
	"math/rand"
	"net"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"lunaria/server/internal/luaengine"
	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

const (
	TCPPort                    = ":7000"
	UDPPort                    = ":7001"
	MaxPlayers                 = 5
	MaxNPCs                    = 16
	GameTickRate               = 30
	WorldSnapshotMaxBufferSize = protocol.WorldSnapshotHeaderSize + (MaxPlayers * protocol.PlayerSnapshotEntrySize) // 106 bytes
	NPCSnapshotMaxBufferSize   = protocol.NPCSnapshotHeaderSize + (MaxNPCs * protocol.NPCSnapshotEntrySize)         // 338 bytes
)

// Server coordena conexões de rede, relógio do mundo, NPCs, Bonecos de Treino, Mobs, combate e Game Loop.
type Server struct {
	mu            sync.RWMutex
	players       map[uint32]*world.Player
	npcs          map[uint32]*world.NPC
	dummies       map[uint32]*world.TrainingDummy
	mobManager    *world.MobManager
	projManager   *world.ProjectileManager
	corpseManager *world.CorpseManager
	groundItems   *world.GroundItemManager
	resourceNodes *world.ResourceNodeManager
	nextPlayerID  uint32
	serverTick    uint32

	garrickLastDefend time.Time
	guardLastAttack   map[uint32]time.Time

	forgeWarningMu   sync.Mutex
	lastForgeWarning time.Time
	fireHazardTimer  float32

	clock     *world.WorldClock
	luaEngine *luaengine.Engine

	tcpListener *net.TCPListener
	udpConn     *net.UDPConn

	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

// NewServer inicializa a instância do servidor autoritativo de Lunaria.
func NewServer() *Server {
	ctx, cancel := context.WithCancel(context.Background())
	// Inicia às 16:00 (final da tarde) com o relógio assimétrico oficial
	clock := world.NewWorldClock(16.0)
	engine := luaengine.NewEngine(clock)

	return &Server{
		players:         make(map[uint32]*world.Player),
		npcs:            make(map[uint32]*world.NPC),
		dummies:         make(map[uint32]*world.TrainingDummy),
		mobManager:      world.NewMobManager(),
		projManager:     world.NewProjectileManager(),
		groundItems:     world.NewGroundItemManager(),
		resourceNodes:   world.NewResourceNodeManager(),
		corpseManager:   world.NewCorpseManager(),
		guardLastAttack: make(map[uint32]time.Time),
		clock:           clock,
		luaEngine:       engine,
		ctx:             ctx,
		cancel:          cancel,
	}
}

// Start inicializa listeners, NPCs, Bonecos de Treino, scripts Lua e Game Loop.
func (s *Server) Start() error {
	// 1. Inicializa o Listener TCP (:7000)
	tcpAddr, err := net.ResolveTCPAddr("tcp", TCPPort)
	if err != nil {
		return fmt.Errorf("falha ao resolver endereco TCP: %w", err)
	}

	tcpListener, err := net.ListenTCP("tcp", tcpAddr)
	if err != nil {
		return fmt.Errorf("falha ao iniciar listener TCP na porta %s: %w", TCPPort, err)
	}
	s.tcpListener = tcpListener
	log.Printf("[TCP] Listener ativo na porta %s (Limite: %d jogadores simultaneos)\n", TCPPort, MaxPlayers)

	// 2. Inicializa o Listener UDP (:7001)
	udpAddr, err := net.ResolveUDPAddr("udp", UDPPort)
	if err != nil {
		return fmt.Errorf("falha ao resolver endereco UDP: %w", err)
	}

	udpConn, err := net.ListenUDP("udp", udpAddr)
	if err != nil {
		return fmt.Errorf("falha ao iniciar listener UDP na porta %s: %w", UDPPort, err)
	}
	s.udpConn = udpConn
	log.Printf("[UDP] Listener ativo na porta %s para movimentacao, combate e snapshots\n", UDPPort)

	// 3. Inicializa NPCs, Bonecos de Treino e Mobs
	scriptsDir := luaengine.FindNPCScriptsDir()
	combatDir := luaengine.FindCombatScriptsDir()
	mobsDir := luaengine.FindMobsScriptsDir()
	garrickScript := filepath.Join(scriptsDir, "garrick.lua")
	lyraScript := filepath.Join(scriptsDir, "lyra.lua")
	shadowMerchantScript := filepath.Join(scriptsDir, "shadow_merchant.lua")
	guardScript := filepath.Join(scriptsDir, "guard.lua")
	seraphinaScript := filepath.Join(scriptsDir, "seraphina.lua")
	aureliusScript := filepath.Join(scriptsDir, "aurelius.lua")
	kaelenScript := filepath.Join(scriptsDir, "kaelen.lua")
	ghostAlchemistScript := filepath.Join(scriptsDir, "ghost_alchemist.lua")
	combatScript := filepath.Join(combatDir, "combat.lua")
	mobsScript := filepath.Join(mobsDir, "mobs_ai.lua")

	currentH := s.clock.GetCurrentHour()

	// 1. Garrick, o Ferreiro (ID 100)
	// Dia (06h-17h59): Forja do Garrick (30.0, 25.0) em ZoneVillage (0). ShopOpen = true
	// Noite (18h-23h59): Taverna do Javali Dourado (-30.0, 25.0). ShopOpen = false
	// Madrugada (00h-05h59): Casa residencial (20.0, 20.0). ShopOpen = false
	garrickX, garrickZ := float32(30.0), float32(25.0)
	garrickShop := true
	garrickState := uint8(2) // Trabalhando na Forja
	if currentH >= 18 && currentH < 24 {
		garrickX, garrickZ = -30.0, 25.0
		garrickShop = false
		garrickState = 3 // Na Taverna
	} else if currentH < 6 {
		garrickX, garrickZ = 20.0, 20.0
		garrickShop = false
		garrickState = 0 // Descansando
	}
	garrick := world.NewNPC(
		100,
		"Garrick, o Ferreiro",
		garrickX, 0.0, garrickZ,
		garrickScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	garrick.SetShopOpen(garrickShop)
	garrick.SetState(garrickState)

	// 2. Lyra, a Alquimista (ID 103)
	// Dia (06h às 17h59): Laboratório de Alquimia (30.0, 0.0, -20.0). ShopOpen = true
	// Noite (18h às 23h59): Taverna (-30.0, 0.0, 25.0). ShopOpen = false
	// Madrugada (00h às 05h59): Casa residencial (20.0, 0.0, -35.0). ShopOpen = false
	lyraX, lyraZ := float32(30.0), float32(-20.0)
	lyraShop := true
	lyraState := uint8(2)
	if currentH >= 18 && currentH < 24 {
		lyraX, lyraZ = -30.0, 25.0
		lyraShop = false
		lyraState = 3
	} else if currentH < 6 {
		lyraX, lyraZ = 20.0, -35.0
		lyraShop = false
		lyraState = 0
	}
	lyra := world.NewNPC(
		103,
		"Lyra, a Alquimista",
		lyraX, 0.0, lyraZ,
		lyraScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	lyra.SetShopOpen(lyraShop)
	lyra.SetState(lyraState)

	// 3. Varis, o Contrabandista (ID 104)
	// Ativo à noite (18h às 05h59): Mercado Negro (ZoneBlackMarket = 7) em (0.0, 0.0, 10.0). ShopOpen = true
	// De dia (06h às 17h59): Escondido na Vila (-50.0, 0.0, 48.0), fora de serviço. ShopOpen = false
	varisX, varisZ := float32(0.0), float32(10.0)
	varisZone := uint8(world.ZoneBlackMarket)
	varisShop := true
	varisActive := true
	if currentH >= 6 && currentH < 18 {
		varisX, varisZ = -50.0, 48.0
		varisZone = world.ZoneVillage
		varisShop = false
		varisActive = false
	}
	varis := world.NewNPC(
		104,
		"Varis, o Contrabandista",
		varisX, 0.0, varisZ,
		shadowMerchantScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	varis.SetZone(varisZone)
	varis.SetActive(varisActive)
	varis.SetShopOpen(varisShop)

	// 4. Capitão Randel (ID 105)
	// Quartel (0.0, 0.0, 48.0) na ZoneVillage (0). Patrulha contínua da praça e quartel.
	guard1 := world.NewNPC(
		105,
		"Capitão Randel",
		0.0, 0.0, 48.0,
		guardScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	guard1.SetPatrolRoute([]world.Waypoint{
		{X: 0.0, Z: 48.0},   // Quartel da Guarda
		{X: 15.0, Z: 48.0},  // Pátio Leste
		{X: 0.0, Z: 30.0},   // Avenida Norte
		{X: -15.0, Z: 48.0}, // Pátio Oeste
		{X: 0.0, Z: 48.0},   // Quartel da Guarda
	}, 2.8, 3.0)

	// 5. Guarda Valen (ID 106)
	// Patrulha contínua da Avenida Central
	guard2 := world.NewNPC(
		106,
		"Guarda Valen",
		35.0, 0.0, 0.0,
		guardScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	guard2.SetPatrolRoute([]world.Waypoint{
		{X: 35.0, Z: 0.0},
		{X: 0.0, Z: 10.0},
		{X: -35.0, Z: 0.0},
		{X: 0.0, Z: -10.0},
	}, 2.8, 3.0)

	// 6. Irmã Seraphina (ID 107)
	// Dia (06h às 17h59): Igreja da Luz Sagrada (ZoneChurch = 5) em (0.0, 0.0, 15.0)
	// Noite (18h às 05h59): Porta da Igreja na Vila (ZoneVillage = 0) em (-50.0, 0.0, -36.0)
	seraphinaX, seraphinaZ := float32(0.0), float32(15.0)
	seraphinaZone := uint8(world.ZoneChurch)
	if currentH >= 18 || currentH < 6 {
		seraphinaX, seraphinaZ = -50.0, -36.0
		seraphinaZone = world.ZoneVillage
	}
	seraphina := world.NewNPC(
		107,
		"Irmã Seraphina",
		seraphinaX, 0.0, seraphinaZ,
		seraphinaScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	seraphina.SetZone(seraphinaZone)

	// 7. Mestre Aurelius (ID 108)
	// Dia (06h às 17h59): Torre Arcana (ZoneMageTower = 6) em (0.0, 0.0, 15.0)
	// Noite (18h às 05h59): Pátio da Torre na Vila (ZoneVillage = 0) em (50.0, 0.0, -38.0)
	aureliusX, aureliusZ := float32(0.0), float32(15.0)
	aureliusZone := uint8(world.ZoneMageTower)
	if currentH >= 18 || currentH < 6 {
		aureliusX, aureliusZ = 50.0, -38.0
		aureliusZone = world.ZoneVillage
	}
	aurelius := world.NewNPC(
		108,
		"Mestre Aurelius",
		aureliusX, 0.0, aureliusZ,
		aureliusScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	aurelius.SetZone(aureliusZone)

	// 8. Kaelen, o Mestre Caçador (ID 109) — Posto do Caçador (25.0, 0.0, -95.0) na ZoneVillage (0)
	kaelen := world.NewNPC(
		109,
		"Kaelen, o Mestre Caçador",
		25.0, 0.0, -95.0,
		kaelenScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	kaelen.SetPatrolRoute([]world.Waypoint{
		{X: 25.0, Z: -95.0},
		{X: 10.0, Z: -160.0},
		{X: 0.0, Z: -260.0},
		{X: 10.0, Z: -160.0},
	}, 2.6, 4.0)

	// 9. O Alquimista Esquecido (ID 110) — Esgotos Antigos (ZoneSewers = 8) em (-110.0, 0.0, 110.0)
	// Ativo durante a madrugada (00h às 04h)
	ghostAlchemist := world.NewNPC(
		110,
		"O Alquimista Esquecido",
		-110.0, 0.0, 110.0,
		ghostAlchemistScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	ghostAlchemist.SetZone(world.ZoneSewers)
	if currentH < 0 || currentH > 4 {
		ghostAlchemist.SetActive(false)
	}

	allLivingNPCs := []*world.NPC{garrick, lyra, varis, guard1, guard2, seraphina, aurelius, kaelen, ghostAlchemist}
	allLivingNPCs = append(allLivingNPCs, s.spawnClassMasters(scriptsDir, currentH)...)
	for _, npc := range allLivingNPCs {
		if err := s.luaEngine.BindNPC(npc); err != nil {
			log.Printf("[AVISO] Nao foi possivel vincular script do NPC '%s' (ID %d): %v\n", npc.Name, npc.ID, err)
		}
	}
	s.luaEngine.SetNPCAttackCallback(s.handleNPCAttackMob)

	if err := s.luaEngine.LoadCombatScript(combatScript); err != nil {
		log.Printf("[AVISO] Nao foi possivel carregar script de combate: %v\n", err)
	}

	autopsyScript := filepath.Join(combatDir, "autopsy.lua")
	if err := s.luaEngine.LoadAutopsyScript(autopsyScript); err != nil {
		log.Printf("[AVISO] Nao foi possivel carregar script de autopsia: %v\n", err)
	}

	if err := s.luaEngine.LoadMobAIScript(mobsScript, s.mobManager, s.handleMobAttack, s.handleMobTelegraph, s.handleMobAOEDamage, s.handleMobSay); err != nil {
		log.Printf("[AVISO] Nao foi possivel carregar script de IA dos Mobs: %v\n", err)
	}

	if err := s.luaEngine.StartWatcher(scriptsDir, combatDir, mobsDir); err != nil {
		log.Printf("[AVISO] Nao foi possivel iniciar watcher de scripts: %v\n", err)
	}

	// Bonecos de Treino: IDs 101 e 102 no Pátio do Quartel a Sudoeste (-10.0, -10.0) e (-13.0, -10.0)
	dummy1 := world.NewTrainingDummy(101, "Boneco de Treino Alfa", -10.0, 0.0, -10.0, 0)
	dummy2 := world.NewTrainingDummy(102, "Boneco de Treino Beta", -13.0, 0.0, -10.0, 0)

	s.mu.Lock()
	for _, npc := range allLivingNPCs {
		s.npcs[npc.ID] = npc
	}
	s.dummies[dummy1.ID] = dummy1
	s.dummies[dummy2.ID] = dummy2
	s.mu.Unlock()
	s.initNPCLife(allLivingNPCs)

	log.Println("[WORLD] NPCs (Garrick 100, Lyra 103, Varis 104, Guardas 105-106, Seraphina 107, Aurelius 108, Kaelen 109, Fantasma 110) e Bonecos de Treino (101, 102) carregados com sucesso!")

	// Executa OnTick inicial em todos os NPCs vivos
	for _, npc := range allLivingNPCs {
		_ = luaengine.CallOnTick(npc, s.clock.GetCurrentHour())
	}

	// 4. Dispara as goroutines de rede e simulação
	s.wg.Add(3)
	go s.runTCPAcceptor()
	go s.runUDPListener()
	go s.runGameLoop()

	h, m, moon, weather := s.clock.GetTime()
	log.Printf("[WORLD] Relógio Assimétrico ativo. Hora: %02d:%02d | Fase da Lua: %d | Clima: %d (Dia: 80m / Noite: 40m)\n", h, m, moon, weather)
	return nil
}

// Stop encerra graciosamente todos os listeners, conexões e a engine Lua.
func (s *Server) Stop() {
	log.Println("[SERVER] Encerrando servidor autoritativo...")
	s.cancel()

	if s.luaEngine != nil {
		s.luaEngine.Close()
	}

	if s.tcpListener != nil {
		_ = s.tcpListener.Close()
	}

	if s.udpConn != nil {
		_ = s.udpConn.Close()
	}

	s.mu.Lock()
	for _, p := range s.players {
		if p.TCPConn != nil {
			_ = p.TCPConn.Close()
		}
	}
	for _, npc := range s.npcs {
		npc.Close()
	}
	s.mu.Unlock()

	s.wg.Wait()
	log.Println("[SERVER] Servidor finalizado com sucesso.")
}

// BroadcastNPCSay transmite o pacote TCP 0x21 (NPC_SAY) para todos os jogadores conectados.
func (s *Server) BroadcastNPCSay(npcID uint32, message string) {
	log.Printf("[NPC DIALOGO] NPC #%d: \"%s\"\n", npcID, message)

	sayPkt := protocol.SerializeNPCSay(npcID, message)

	s.mu.RLock()
	conns := make([]net.Conn, 0, len(s.players))
	for _, p := range s.players {
		if p.TCPConn != nil {
			conns = append(conns, p.TCPConn)
		}
	}
	s.mu.RUnlock()

	for _, conn := range conns {
		_ = conn.SetWriteDeadline(time.Now().Add(500 * time.Millisecond))
		_, _ = conn.Write(sayPkt)
		_ = conn.SetWriteDeadline(time.Time{})
	}
}

// sendPlayerNPCSay transmite o pacote TCP 0x21 (NPC_SAY) exclusivamente para um jogador específico.
func (s *Server) sendPlayerNPCSay(p *world.Player, npcID uint32, message string) {
	if p == nil {
		return
	}
	sayPkt := protocol.SerializeNPCSay(npcID, message)
	p.Mu.RLock()
	conn := p.TCPConn
	p.Mu.RUnlock()

	if conn != nil {
		_ = conn.SetWriteDeadline(time.Now().Add(500 * time.Millisecond))
		_, _ = conn.Write(sayPkt)
		_ = conn.SetWriteDeadline(time.Time{})
	}
}

// BroadcastWorldTime transmite o pacote 0x13 (WORLD_TIME: 5 bytes) via TCP e UDP para os clientes.
func (s *Server) BroadcastWorldTime() {
	h, m, moon, _ := s.clock.GetTime()

	s.mu.RLock()
	// Cada jogador recebe o clima da zona em que está
	for _, p := range s.players {
		timePkt := protocol.SerializeWorldTime(h, m, moon, s.clock.GetZoneWeather(p.GetZone()))
		if p.TCPConn != nil {
			_ = p.TCPConn.SetWriteDeadline(time.Now().Add(200 * time.Millisecond))
			_, _ = p.TCPConn.Write(timePkt[:])
			_ = p.TCPConn.SetWriteDeadline(time.Time{})
		}
		if addr := p.GetUDPAddr(); addr != nil {
			_, _ = s.udpConn.WriteToUDP(timePkt[:], addr)
		}
	}
	s.mu.RUnlock()
}

// BroadcastCombatEvent transmite o pacote 0x32 (COMBAT_EVENT: 17 bytes) via UDP para os clientes na mesma zona.
func (s *Server) BroadcastCombatEvent(attackerID, targetID uint32, actionType uint8, damage uint16, isCrit uint8, targetHP, targetMaxHP uint16) {
	pkt := protocol.SerializeCombatEvent(attackerID, targetID, actionType, damage, isCrit, targetHP, targetMaxHP)

	s.mu.RLock()
	defer s.mu.RUnlock()

	var eventZone uint8
	foundZone := false
	if p, ok := s.players[attackerID]; ok {
		eventZone = p.GetZone()
		foundZone = true
	} else if p, ok := s.players[targetID]; ok {
		eventZone = p.GetZone()
		foundZone = true
	} else if s.mobManager != nil {
		if m := s.mobManager.GetMob(attackerID); m != nil {
			eventZone = m.GetZone()
			foundZone = true
		} else if m := s.mobManager.GetMob(targetID); m != nil {
			eventZone = m.GetZone()
			foundZone = true
		}
	}
	if !foundZone && s.npcs != nil {
		if n, ok := s.npcs[attackerID]; ok {
			eventZone = n.GetZone()
			foundZone = true
		}
	}

	for _, p := range s.players {
		if foundZone && p.GetZone() != eventZone {
			continue
		}
		if addr := p.GetUDPAddr(); addr != nil {
			_, _ = s.udpConn.WriteToUDP(pkt[:], addr)
		}
	}
}

// sendPlayerStats envia 0x33 (PLAYER_STATS: 31 bytes) para o jogador especificado via UDP e TCP.
func (s *Server) sendPlayerStats(p *world.Player) {
	pStats := p.ToStatsPacket()
	b := protocol.SerializePlayerStatsPacket(pStats)

	if addr := p.GetUDPAddr(); addr != nil {
		_, _ = s.udpConn.WriteToUDP(b[:], addr)
	}
	if p.TCPConn != nil {
		_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
		_, _ = p.TCPConn.Write(b[:])
		_ = p.TCPConn.SetWriteDeadline(time.Time{})
	}
}

// sendInventorySync envia o pacote 0x38 (INVENTORY_SYNC) para o jogador especificado via TCP.
func (s *Server) sendInventorySync(p *world.Player) {
	if p.TCPConn == nil {
		return
	}
	equipped := p.GetEquippedSlots()
	slots := p.GetInventorySlots()
	data := protocol.SerializeInventorySync(equipped, p.GetEquippedQualities(), p.InventoryStatus(), slots)

	_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
	_, _ = p.TCPConn.Write(data)
	_ = p.TCPConn.SetWriteDeadline(time.Time{})
	s.sendDiscoveries(p, false) // aviso de materiais descobertos pela primeira vez
	if st := questStage(p); st > questStageNotStarted && st < questStageDone {
		s.sendQuestState(p) // progresso da coleta na missão
	}
}

// sendFriendshipSync envia o pacote 0x24 (FRIENDSHIP_SYNC) para o jogador especificado via TCP.
func (s *Server) sendFriendshipSync(p *world.Player, npcID uint32) {
	if p == nil || p.TCPConn == nil {
		return
	}
	pts := p.GetFriendship(npcID)
	lvl := p.GetFriendshipLevel(npcID)
	data := protocol.SerializeFriendshipSync(npcID, uint16(pts), lvl)

	_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
	_, _ = p.TCPConn.Write(data)
	_ = p.TCPConn.SetWriteDeadline(time.Time{})
}

// sendAllFriendships envia a afiança de todos os NPCs da vila para o jogador via TCP.
func (s *Server) sendAllFriendships(p *world.Player) {
	if p == nil || p.TCPConn == nil {
		return
	}
	npcIDs := []uint32{100, 103, 104, 105, 106, 107, 108, 109, 110}
	for _, nid := range npcIDs {
		s.sendFriendshipSync(p, nid)
	}
}

// runTCPAcceptor aceita novas conexões de clientes via TCP.
func (s *Server) runTCPAcceptor() {
	defer s.wg.Done()

	for {
		conn, err := s.tcpListener.AcceptTCP()
		if err != nil {
			select {
			case <-s.ctx.Done():
				return
			default:
				log.Printf("[TCP] Erro ao aceitar conexao: %v\n", err)
				continue
			}
		}

		s.handleNewTCPConnection(conn)
	}
}

// handleNewTCPConnection valida limite, atribui PlayerID, envia WELCOME + WORLD_TIME e processa pacotes TCP.
func (s *Server) handleNewTCPConnection(conn *net.TCPConn) {
	s.mu.Lock()
	if len(s.players) >= MaxPlayers {
		s.mu.Unlock()
		log.Printf("[TCP] Conexao recusada de %s: limite de %d jogadores alcancado\n", conn.RemoteAddr(), MaxPlayers)
		_ = conn.Close()
		return
	}

	playerID := atomic.AddUint32(&s.nextPlayerID, 1)
	player := world.NewPlayer(playerID, conn, 0.0, 1.5, 0.0) // Centro Oficial de Spawn (0.0, 1.5, 0.0)
	s.players[playerID] = player
	currentCount := len(s.players)
	s.mu.Unlock()

	log.Printf("[TCP] Novo jogador conectado: ID %d a partir de %s (Total: %d/%d)\n", playerID, conn.RemoteAddr(), currentCount, MaxPlayers)

	// 1. Envia pacote 0x01 (WELCOME: 5 bytes)
	welcomePkt := protocol.SerializeWelcome(playerID)
	_ = conn.SetWriteDeadline(time.Now().Add(3 * time.Second))
	if _, err := conn.Write(welcomePkt[:]); err != nil {
		log.Printf("[TCP] Falha ao enviar pacote WELCOME para jogador %d: %v\n", playerID, err)
		s.removePlayerAndNotify(playerID)
		return
	}

	// 2. Envia pacote 0x13 (WORLD_TIME: 5 bytes) imediatamente na conexão
	h, m, moon, weather := s.clock.GetTime()
	timePkt := protocol.SerializeWorldTime(h, m, moon, weather)
	_, _ = conn.Write(timePkt[:])
	_ = conn.SetWriteDeadline(time.Time{})

	// 3. Envia pacote 0x33 (PLAYER_STATS: 31 bytes) autoritativo na conexão inicial
	s.sendPlayerStats(player)

	// 4. Envia pacote 0x38 (INVENTORY_SYNC) autoritativo na conexão inicial
	s.sendInventorySync(player)
	s.sendGroundItems(player)
	s.sendResourceNodes(player)
	s.sendDiscoveries(player, true)
	s.sendQuestState(player)

	// 5. Envia pacote 0x3E (CORPSE_SNAPSHOT) com cadáveres ativos no chão
	s.sendCorpseSnapshots(player)

	// 6. Envia pacote 0x24 (FRIENDSHIP_SYNC) para os NPCs mestres da vila
	s.sendAllFriendships(player)

	// Loop de leitura de pacotes TCP do cliente
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		header := make([]byte, 1)

		for {
			_, err := io.ReadFull(conn, header)
			if err != nil {
				s.removePlayerAndNotify(playerID)
				return
			}

			switch header[0] {
			case protocol.PacketTypePlayerInteract:
				// Pacote 0x20: PLAYER_INTERACT (9 bytes total, 8 bytes payload)
				payload := make([]byte, protocol.PlayerInteractPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.PlayerInteractPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var interactPkt protocol.PlayerInteractPacket
				if err := protocol.DeserializePlayerInteract(fullPkt[:], &interactPkt); err == nil {
					s.handlePlayerInteract(interactPkt)
				}

			case protocol.PacketTypeDevWorldControl:
				// Pacote 0x22: DEV_WORLD_CONTROL (3 bytes total, 2 bytes payload)
				payload := make([]byte, protocol.DevWorldControlPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.DevWorldControlPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var devPkt protocol.DevWorldControlPacket
				if err := protocol.DeserializeDevWorldControl(fullPkt[:], &devPkt); err == nil {
					s.handleDevWorldControl(playerID, devPkt.CommandType, devPkt.Value)
				}

			case protocol.PacketTypePortalTravel:
				// Pacote 0x23: PORTAL_TRAVEL / ZONE_CHANGE (3 bytes total, 2 bytes payload)
				payload := make([]byte, protocol.PortalTravelPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.PortalTravelPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var portalPkt protocol.PortalTravelPacket
				if err := protocol.DeserializePortalTravel(fullPkt[:], &portalPkt); err == nil {
					s.handlePortalTravel(playerID, portalPkt.TargetZoneID, portalPkt.PortalID)
				}

			case protocol.PacketTypeSelectIdentity:
				// Pacote 0x30: SELECT_IDENTITY (7 bytes total, 6 bytes payload)
				payload := make([]byte, protocol.SelectIdentityPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.SelectIdentityPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var identityPkt protocol.SelectIdentityPacket
				if err := protocol.DeserializeSelectIdentity(fullPkt[:], &identityPkt); err == nil {
					s.handleSelectIdentity(identityPkt)
				}

			case protocol.PacketTypeDropItemGround:
				// Pacote 0x41: DROP_ITEM_GROUND (7 bytes total, 6 bytes payload)
				payload := make([]byte, protocol.DropItemGroundPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}
				full := append([]byte{header[0]}, payload...)
				var dropPkt protocol.DropItemGroundPacket
				if err := protocol.DeserializeDropItemGround(full, &dropPkt); err == nil {
					s.handleDropItemGround(playerID, dropPkt)
				}

			case protocol.PacketTypeHarvestNode:
				// Pacote 0x44: HARVEST_NODE (9 bytes total, 8 bytes payload)
				payload := make([]byte, protocol.HarvestNodePacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}
				full := append([]byte{header[0]}, payload...)
				var harvestPkt protocol.HarvestNodePacket
				if err := protocol.DeserializeHarvestNode(full, &harvestPkt); err == nil {
					s.handleHarvestNode(playerID, harvestPkt)
				}

			case protocol.PacketTypePickupGroundItem:
				// Pacote 0x43: PICKUP_GROUND_ITEM (9 bytes total, 8 bytes payload)
				payload := make([]byte, protocol.PickupGroundItemPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}
				full := append([]byte{header[0]}, payload...)
				var pickPkt protocol.PickupGroundItemPacket
				if err := protocol.DeserializePickupGroundItem(full, &pickPkt); err == nil {
					s.handlePickupGroundItem(playerID, pickPkt)
				}

			case protocol.PacketTypeAllocateStat:
				// Pacote 0x37: ALLOCATE_STAT (8 bytes total, 7 bytes payload: playerID, statID, Amount u16)
				payload := make([]byte, protocol.AllocateStatPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.AllocateStatPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var statPkt protocol.AllocateStatPacket
				if err := protocol.DeserializeAllocateStat(fullPkt[:], &statPkt); err == nil {
					s.handleAllocateStat(statPkt)
				}

			case protocol.PacketTypeUseOrEquipItem:
				// Pacote 0x39: USE_OR_EQUIP_ITEM (8 bytes total, 7 bytes payload: playerID, itemID, action, slot)
				payload := make([]byte, protocol.UseOrEquipItemPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.UseOrEquipItemPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var usePkt protocol.UseOrEquipItemPacket
				if err := protocol.DeserializeUseOrEquipItem(fullPkt[:], &usePkt); err == nil {
					s.handleUseOrEquipItem(usePkt)
				}

			case protocol.PacketTypeEvolutionOffer:
				// Pacote 0x40: EVOLUTION_OFFER (4 bytes total, 3 bytes payload)
				payload := make([]byte, protocol.EvolutionOfferPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.EvolutionOfferPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var evoPkt protocol.EvolutionOfferPacket
				if err := protocol.DeserializeEvolutionOffer(fullPkt[:], &evoPkt); err == nil {
					s.handleEvolutionChoice(playerID, evoPkt)
				}

			case protocol.PacketTypeDevGetDropRates:
				// Pacote 0x3A: DEV_GET_DROP_RATES (5 bytes total, 4 bytes payload: playerID uint32)
				payload := make([]byte, protocol.DevGetDropRatesPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.DevGetDropRatesPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var dropPkt protocol.DevGetDropRatesPacket
				if err := protocol.DeserializeDevGetDropRatesRequest(fullPkt[:], &dropPkt); err == nil {
					s.handleDevGetDropRates(playerID)
				}

			case protocol.PacketTypeInteractCorpse:
				// Pacote 0x3B: INTERACT_CORPSE (9 bytes total, 8 bytes payload)
				payload := make([]byte, protocol.InteractCorpsePacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.InteractCorpsePacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var interactPkt protocol.InteractCorpsePacket
				if err := protocol.DeserializeInteractCorpse(fullPkt[:], &interactPkt); err == nil {
					if interactPkt.PlayerID == 0 {
						interactPkt.PlayerID = playerID
					}
					s.handleInteractCorpse(interactPkt)
				}

			case protocol.PacketTypeSubmitAutopsyResult:
				// Pacote 0x3D: SUBMIT_AUTOPSY_RESULT (11 bytes total, 10 bytes payload)
				payload := make([]byte, protocol.SubmitAutopsyResultPacketSize-1)
				if _, err := io.ReadFull(conn, payload); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}

				var fullPkt [protocol.SubmitAutopsyResultPacketSize]byte
				fullPkt[0] = header[0]
				copy(fullPkt[1:], payload)

				var submitPkt protocol.SubmitAutopsyResultPacket
				if err := protocol.DeserializeSubmitAutopsyResult(fullPkt[:], &submitPkt); err == nil {
					if submitPkt.PlayerID == 0 {
						submitPkt.PlayerID = playerID
					}
					s.handleSubmitAutopsyResult(submitPkt)
				}

			case protocol.PacketTypeShopRequest, protocol.PacketTypeShopTrade:
				// Pacotes 0x48 / 0x49: loja viva dos NPCs (Mundo Vivo)
				size := protocol.ShopRequestPacketSize
				if header[0] == protocol.PacketTypeShopTrade {
					size = protocol.ShopTradePacketSize
				}
				full := make([]byte, size)
				full[0] = header[0]
				if _, err := io.ReadFull(conn, full[1:]); err != nil {
					s.removePlayerAndNotify(playerID)
					return
				}
				if header[0] == protocol.PacketTypeShopRequest {
					var req protocol.ShopRequestPacket
					if protocol.DeserializeShopRequest(full, &req) == nil {
						req.PlayerID = playerID
						s.handleShopRequest(req)
					}
				} else {
					var trade protocol.ShopTradePacket
					if protocol.DeserializeShopTrade(full, &trade) == nil {
						trade.PlayerID = playerID
						s.handleShopTrade(trade)
					}
				}

			default:
				log.Printf("[TCP] Opcode desconhecido de jogador %d: 0x%02x\n", playerID, header[0])
			}
		}
	}()
}

// handleAllocateStat consome 1 ponto de status do jogador no atributo selecionado e sincroniza status.
func (s *Server) handleAllocateStat(pkt protocol.AllocateStatPacket) {
	s.mu.RLock()
	player, exists := s.players[pkt.PlayerID]
	s.mu.RUnlock()

	if !exists {
		return
	}

	if applied := player.AllocateStats(pkt.StatID, pkt.Amount); applied > 0 {
		log.Printf("[ATRIBUTOS] Jogador #%d alocou %d ponto(s) no atributo ID %d. StatPoints restantes: %d\n",
			pkt.PlayerID, applied, pkt.StatID, player.StatPoints)
		s.sendPlayerStats(player)
		s.sendInventorySync(player) // FOR/CON mudam o peso máximo
	}
}

// handleUseOrEquipItem processa o uso de consumíveis, equipamentos ou tomos de classes secretas.
func (s *Server) handleUseOrEquipItem(pkt protocol.UseOrEquipItemPacket) {
	s.mu.RLock()
	player, exists := s.players[pkt.PlayerID]
	s.mu.RUnlock()

	if !exists {
		return
	}

	// Desequipar um slot (0..13): o item volta para a mochila
	if pkt.Action == protocol.ItemActionUnequip {
		if player.UnequipSlot(pkt.SlotIndex) {
			log.Printf("[EQUIPAMENTO] Jogador #%d desequipou o slot %d\n", pkt.PlayerID, pkt.SlotIndex)
			s.sendInventorySync(player)
			s.sendPlayerStats(player)
		}
		return
	}

	itemID := pkt.ItemID
	if world.IsEquippable(itemID) {
		s.toggleEquip(player, itemID, pkt.SlotIndex) // SlotIndex = Qualidade da unidade escolhida
		return
	}
	switch itemID {
	// Consumíveis e Tomos Secretos (2, 3, 4, 16, 17, 18, 26, 28, 29, 30)
	case protocol.ItemRawWolfMeat, protocol.ItemCookedNobleMeat, protocol.ItemWolfBloodPotion,
		protocol.ItemBeastProgenitorBlood, protocol.ItemEclipseScytheTome, protocol.ItemStarforgeCore,
		protocol.ItemRunicWarhammerRecipe, protocol.ItemOrganicTrash, protocol.ItemRunicHourglass, protocol.ItemSilverSilkCocoon,
		protocol.ItemHealingPotion, protocol.ItemManaPotion:
		ok, msg := player.UseConsumable(itemID)
		if ok {
			log.Printf("[ITEM] Jogador #%d usou item ID %d: %s\n", pkt.PlayerID, itemID, msg)
			s.sendInventorySync(player)
			s.sendPlayerStats(player)
			s.BroadcastNPCSay(0, msg)
		}

	}
}

// handleSelectIdentity define a Raça e Classe do jogador e sincroniza os status conforme o modo de ação.
func (s *Server) handleSelectIdentity(pkt protocol.SelectIdentityPacket) {
	s.mu.RLock()
	player, exists := s.players[pkt.PlayerID]
	s.mu.RUnlock()

	if !exists {
		return
	}

	if pkt.ActionMode == 99 {
		player.DevSetRaceAndKit(pkt.RaceID, pkt.ClassID)
		log.Printf("[DEV MODE 99] Jogador #%d assumiu Raça %d, Classe %d com Kit de 12 Slots completo!\n",
			pkt.PlayerID, player.RaceID, player.ClassID)
		s.sendPlayerStats(player)
		s.sendInventorySync(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[Dev Menu F10] Jogador #%d assumiu Raça %d com Kit de 12 Slots!", pkt.PlayerID, pkt.RaceID))
		return
	}

	if pkt.ActionMode == protocol.IdentityModeDevDirect { // 98
		if ok, reason := player.CheckUniqueRaceRequirement(pkt.ClassID); !ok {
			s.BroadcastNPCSay(0, fmt.Sprintf("[Dev Mode] Jogador #%d: %s", pkt.PlayerID, reason))
			return
		}
		player.SetIdentityMode(pkt.RaceID, pkt.ClassID, pkt.ActionMode, pkt.SubPath)
		log.Printf("[DEV DIRECT 98] Jogador #%d definiu Classe %d, Tier %d, Caminho %d!\n", pkt.PlayerID, player.ClassID, player.ClassTier, pkt.SubPath)
		s.sendPlayerStats(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[Dev Mode] Jogador #%d agora é Classe %d (Tier %d)!", pkt.PlayerID, player.ClassID, player.ClassTier))
		return
	}

	// Classes Únicas Exclusivas de Raça (19 a 26): raça obrigatória + classe básica e/ou item
	if req, isRaceUnique := world.UniqueRequirements[pkt.ClassID]; isRaceUnique && pkt.ClassID != player.ClassID {
		ok, reason, usedItem := player.CanAwakenUnique(pkt.ClassID)
		if !ok {
			s.BroadcastNPCSay(0, fmt.Sprintf("[CLASSE ÚNICA] Jogador #%d: %s", pkt.PlayerID, reason))
			log.Printf("[CLASSE ÚNICA] Jogador #%d não pode despertar a Classe %d: %s\n", pkt.PlayerID, pkt.ClassID, reason)
			return
		}
		if usedItem != 0 {
			player.RemoveItem(usedItem, 1)
			s.sendInventorySync(player)
			log.Printf("[CLASSE ÚNICA] Jogador #%d consumiu o item %s para despertar a Classe %d\n", pkt.PlayerID, req.ItemName, pkt.ClassID)
		}
	} else if protocol.IsTranscendentClass(pkt.ClassID) && pkt.ClassID != player.ClassID {
		// Únicas Gerais e Lendárias só chegam pelo desafio, pelo item ou pela Provação (ofertas do servidor)
		s.BroadcastNPCSay(0, fmt.Sprintf("[CLASSE SECRETA] Jogador #%d: esta classe só desperta pelo seu desafio secreto ou relíquia.", pkt.PlayerID))
		log.Printf("[CLASSE SECRETA] Jogador #%d pediu a Classe %d direto (0x30) — recusado\n", pkt.PlayerID, pkt.ClassID)
		return
	}

	// Raças secretas só despertam pelas Provações de Linhagem, itens ou evoluções (nunca direto pelo 0x30)
	if pkt.RaceID > protocol.RaceVarkai && pkt.RaceID != player.RaceID {
		s.BroadcastNPCSay(0, "[LINHAGEM] Esta raça só desperta pela sua Provação de Linhagem. Procure rumores com Mestre Aurelius.")
		log.Printf("[LINHAGEM] Jogador #%d pediu a Raça %d direto (0x30) — recusado\n", pkt.PlayerID, pkt.RaceID)
		s.sendPlayerStats(player)
		return
	}

	// Classes Básicas (1 a 12) só são aprendidas ao lado do Mestre de cada uma
	if ok, reason := s.checkBasicClassRequest(player, pkt.ClassID); !ok {
		s.BroadcastNPCSay(0, fmt.Sprintf("[CLASSE] %s", reason))
		log.Printf("[CLASSE] Jogador #%d pediu a Classe %d longe do Mestre — recusado\n", pkt.PlayerID, pkt.ClassID)
		s.sendPlayerStats(player)
		return
	}

	// Variantes Secretas (13 a 18) exigem a classe básica de origem e o nível Raro (25+)
	if pkt.ClassID >= protocol.ClassRunicSpellblade && pkt.ClassID <= protocol.ClassPlagueDoctor && pkt.ClassID != player.ClassID {
		if ok, reason := player.CanAwakenVariant(pkt.ClassID); !ok {
			s.BroadcastNPCSay(0, fmt.Sprintf("[VARIANTE SECRETA] Jogador #%d: %s", pkt.PlayerID, reason))
			log.Printf("[VARIANTE] Jogador #%d não pode despertar a Classe %d: %s\n", pkt.PlayerID, pkt.ClassID, reason)
			return
		}
	}

	player.SetIdentityMode(pkt.RaceID, pkt.ClassID, pkt.ActionMode, pkt.SubPath)
	log.Printf("[IDENTIDADE] Jogador #%d aplicou Raça %d, Classe %d, Modo %d (Tier %d, Nível %d)\n",
		pkt.PlayerID, player.RaceID, player.ClassID, pkt.ActionMode, player.ClassTier, player.Level)
	s.sendPlayerStats(player)
}

// handleDevWorldControl processa comandos de desenvolvimento do Dev Manager (Tecla F10 / Pacote 0x22).
func (s *Server) handleDevWorldControl(senderID uint32, cmdType, val uint8) {
	// Obtém o jogador remetente (ou fallback para o primeiro jogador conectado)
	s.mu.RLock()
	player, exists := s.players[senderID]
	if !exists && len(s.players) > 0 {
		for _, p := range s.players {
			player = p
			exists = true
			break
		}
	}
	s.mu.RUnlock()

	switch cmdType {
	case 1:
		// CommandType 1: Avançar +Value horas no relógio do mundo (F6)
		s.clock.AddHours(int(val))
		h, m, moon, weather := s.clock.GetTime()
		log.Printf("[DEV] Tempo avançado em +%d horas! Horário: %02d:%02d | Lua: %d | Clima: %d\n", val, h, m, moon, weather)

		s.mu.RLock()
		for _, npc := range s.npcs {
			_ = luaengine.CallOnTick(npc, int(h))
		}
		s.mu.RUnlock()

		s.BroadcastWorldTime()
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Relógio avançado em +%d horas! Horário: %02d:%02d.", val, h, m))

	case 2:
		// CommandType 2: Ciclar para a próxima Fase da Lua (MoonPhase + 1) % 10 (F7)
		newMoon := s.clock.CycleMoonPhase()
		log.Printf("[DEV] Fase da Lua alterada ciclicamente para: %d\n", newMoon)
		s.updateMoonPhaseCreatures(newMoon)
		s.BroadcastWorldTime()
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Fase da Lua ciclada para: %d!", newMoon))

	case 3:
		// CommandType 3: Ciclar para o próximo Clima (WeatherType + 1) % 4 (F8)
		newWeather := s.clock.CycleWeather()
		log.Printf("[DEV] Clima alterado ciclicamente para: %d\n", newWeather)
		s.BroadcastWorldTime()
		wName := world.WeatherName(newWeather)
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Clima ciclado para: %s (%d)!", wName, newWeather))

	case 4:
		// CommandType 4 (NOVO): Definir Hora Exata (WorldHour = Value % 24, WorldMinute = 0)
		exactHour := val % 24
		s.clock.SetHour(exactHour)
		h, m, moon, weather := s.clock.GetTime()
		log.Printf("[DEV] Horário definido diretamente para: %02d:%02d | Lua: %d | Clima: %d\n", h, m, moon, weather)

		s.mu.RLock()
		for _, npc := range s.npcs {
			_ = luaengine.CallOnTick(npc, int(h))
		}
		s.mu.RUnlock()

		s.BroadcastWorldTime()
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Horário definido diretamente para %02d:00!", exactHour))

	case 5:
		// CommandType 5 (NOVO): Definir Fase da Lua Exata (0 a 9)
		exactMoon := s.clock.SetMoonPhase(val)
		log.Printf("[DEV] Fase da Lua definida diretamente para: %d\n", exactMoon)
		s.updateMoonPhaseCreatures(exactMoon)
		s.BroadcastWorldTime()
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Fase da Lua definida diretamente para: %d!", exactMoon))

	case 6:
		// CommandType 6 (NOVO): Definir Clima Exato (0=Limpo, 1=Chuva, 2=Neblina Densa, 3=Névoa Carmesim)
		exactWeather := s.clock.SetWeather(val)
		log.Printf("[DEV] Clima definido diretamente para: %d\n", exactWeather)
		s.BroadcastWorldTime()
		wName := world.WeatherName(exactWeather)
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Clima definido diretamente para: %s (%d)!", wName, exactWeather))

	case 7:
		// CommandType 7 (NOVO): Dar Item / Drop Direto para o Inventário
		if player == nil {
			return
		}
		if val == 255 {
			// Entrega o Kit Completo dos 12 Equipamentos
			player.DevSetRaceAndKit(player.RaceID, player.ClassID)
			s.sendPlayerStats(player)
			s.sendInventorySync(player)
			log.Printf("[DEV] Jogador #%d recebeu o Kit Completo dos 12 Equipamentos!\n", player.ID)
			s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d recebeu o Kit Completo dos 12 Equipamentos!", player.ID))
		} else {
			// Adiciona +1 (ou +5 se for consumível/frasco) do item ItemID = val
			qty := uint8(1)
			if val == protocol.ItemEmptyFlask || val == protocol.ItemRawWolfMeat ||
				val == protocol.ItemCookedNobleMeat || val == protocol.ItemWolfBloodPotion ||
				val == protocol.ItemFreshWolfBlood || val == protocol.ItemPureLunarBlood ||
				val == protocol.ItemDarkPoisonGland || val == protocol.ItemBeastProgenitorBlood ||
				val == protocol.ItemOrganicTrash {
				qty = 5
			}
			player.AddItem(val, qty)
			s.sendInventorySync(player)
			log.Printf("[DEV] Adicionado item %d (+%d) ao inventário do Jogador #%d!\n", val, qty, player.ID)
			s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Item #%d (+%d) adicionado ao inventário do Jogador #%d!", val, qty, player.ID))
		}

	case protocol.DevCmdGiveMoney:
		if player == nil {
			return
		}
		g := player.AddGold(1000)
		e := player.AddEclipseCoins(50)
		s.sendInventorySync(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d recebeu +1.000 Sollares e +50 Eclipses (total: %d / %d).", player.ID, g, e))

	case protocol.DevCmdClearHeavy:
		if player == nil {
			return
		}
		n := player.RemoveHeavyItems()
		s.sendInventorySync(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] %d item(ns) pesado(s) removido(s) da mochila do Jogador #%d.", n, player.ID))

	case 8:
		// CommandType 8 (NOVO): Controle de Nível e Status Dev
		if player == nil {
			return
		}
		player.DevControlLevelAndStats(val)
		if val == 1 || val == 5 || val == 50 {
			s.checkProgressionMilestones(player)
		}
		s.sendPlayerStats(player)
		log.Printf("[DEV] Jogador #%d executou controle de nível/status (Comando %d)! Nível: %d, HP: %d/%d, StatPoints: %d\n",
			player.ID, val, player.Level, player.HP, player.MaxHP, player.StatPoints)

		switch val {
		case 1:
			s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d subiu +1 Nível! Nível atual: %d (StatPoints: %d)", player.ID, player.Level, player.StatPoints))
		case 5:
			s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d subiu +5 Níveis! Nível atual: %d (StatPoints: %d)", player.ID, player.Level, player.StatPoints))
		case 50:
			s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d avançou para o Nível 50 (Máximo)! StatPoints: %d", player.ID, player.StatPoints))
		case 99:
			s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d restaurou 100%% HP/Stamina e recebeu +20 StatPoints livres!", player.ID))
		case 0:
			s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d resetou para Nível 1 e atributos limpos!", player.ID))
		}

	case 9:
		// CommandType 9 (NOVO): Teleporte Rápido Dev
		if player == nil {
			return
		}
		var targetX, targetY, targetZ float32
		var locName string
		switch val {
		case 0:
			targetX, targetY, targetZ = 0.0, 1.5, 0.0
			locName = "Centro da Vila"
		case 1:
			targetX, targetY, targetZ = -20.0, 1.5, -15.0
			locName = "Igreja da Luz"
		case 2:
			targetX, targetY, targetZ = 20.0, 1.5, -15.0
			locName = "Torre do Arcanista"
		case 3:
			targetX, targetY, targetZ = -21.0, 1.5, -19.0
			locName = "Entrada dos Esgotos"
		case 4:
			targetX, targetY, targetZ = 52.0, 1.5, -42.0
			locName = "Bosque Sussurrante / Lobos"
		case 5:
			targetX, targetY, targetZ = 0.0, 1.5, 62.0
			locName = "Ruínas da Vigília / Vaelen"
		case 6:
			targetX, targetY, targetZ = -82.0, 1.5, 82.0
			locName = "Santuário do Eclipse / Malakor"
		case 7:
			targetX, targetY, targetZ = -25.0, 1.5, -25.0
			locName = "Mercado Negro"
		default:
			targetX, targetY, targetZ = 0.0, 1.5, 0.0
			locName = "Centro da Vila (Padrão)"
		}

		player.Respawn(targetX, targetY, targetZ)
		s.BroadcastPlayerRespawn(player.ID, targetX, targetY, targetZ)
		s.sendPlayerStats(player)
		log.Printf("[DEV TELEPORT] Jogador #%d teleportado para %s (%.1f, %.1f, %.1f)!\n", player.ID, locName, targetX, targetY, targetZ)
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogador #%d teleportado para %s!", player.ID, locName))

	case 10:
		// CommandType 10: Travessia de Portal / Mudança de Zona (Value = PortalID)
		if player == nil {
			return
		}
		s.handlePortalTravel(player.ID, 0, val)
	}
}

// handlePortalTravel processa a travessia de portais de mão dupla e mudança autoritativa de zona (Pacote 0x23 / Dev 0x22 Cmd 10).
func (s *Server) handlePortalTravel(playerID uint32, targetZoneID, portalID uint8) {
	s.mu.RLock()
	player, exists := s.players[playerID]
	s.mu.RUnlock()

	if !exists || player == nil {
		return
	}

	currentZone := player.GetZone()

	portal, ok := world.ResolvePortalTravel(currentZone, targetZoneID, portalID)
	if !ok {
		log.Printf("[PORTAL] Jogador #%d tentou travessia inválida: Zona Atual=%d, TargetZone=%d, PortalID=%d\n",
			playerID, currentZone, targetZoneID, portalID)
		return
	}

	// REGRA ESTRITA: Trava Noturna para o Mercado Negro (Zone 7)
	// Se tentar entrar na Zone 7 durante o Dia (06h às 17h59 / WorldHour >= 6 && WorldHour < 18), bloqueia!
	// Sair da Zone 7 de volta para a Vila (Zone 0) é sempre permitido!
	if portal.TargetZoneID == world.ZoneBlackMarket {
		worldHour, _, _, _ := s.clock.GetTime()
		if worldHour >= 6 && worldHour < 18 {
			msg := "O Beco está deserto à luz do sol. O Mercado Negro só abre suas portas à noite (18h às 06h)!"
			log.Printf("[PORTAL] Jogador #%d tentou entrar no Mercado Negro durante o dia (%02d:00). Acesso negado!\n", playerID, worldHour)
			s.sendPlayerNPCSay(player, 104, msg)
			s.BroadcastNPCSay(104, msg)
			return
		}
	}

	oldZone := player.GetZone()
	newZone := portal.TargetZoneID
	targetX, targetY, targetZ := portal.TargetX, portal.TargetY, portal.TargetZ

	// Garante que as coordenadas de chegada respeitem estritamente os limites da zona
	targetX, targetZ = world.ClampToZoneBounds(newZone, targetX, targetZ)

	player.SetZone(newZone)
	player.Respawn(targetX, targetY, targetZ)
	defer s.sendGroundItems(player) // itens no chão da nova zona
	defer s.sendResourceNodes(player)

	// Envia pacote 0x36 (PLAYER_RESPAWN) com a nova coordenada segura (5m do portal de retorno)
	respawnPkt := protocol.SerializePlayerRespawn(player.ID, targetX, targetY, targetZ)

	// Envia pacote 0x23 (PORTAL_TRAVEL / ZONE_CHANGE) informando a nova ZoneID
	portalPkt := protocol.SerializePortalTravel(newZone, portal.ID)

	// Envio prioritário via TCP para o jogador para que dê Unload do mapa antigo
	if player.TCPConn != nil {
		_ = player.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
		_, _ = player.TCPConn.Write(respawnPkt[:])
		_, _ = player.TCPConn.Write(portalPkt[:])
		_ = player.TCPConn.SetWriteDeadline(time.Time{})
	}

	// Envia também via UDP para o jogador
	if addr := player.GetUDPAddr(); addr != nil {
		_, _ = s.udpConn.WriteToUDP(respawnPkt[:], addr)
		_, _ = s.udpConn.WriteToUDP(portalPkt[:], addr)
	}

	// Sincroniza nova posição com os demais jogadores conectados
	s.BroadcastPlayerRespawn(player.ID, targetX, targetY, targetZ)

	// Envia status atualizados e snapshots de corpos da nova zona
	s.sendPlayerStats(player)
	s.sendCorpseSnapshots(player)

	zoneName := world.GetZoneName(newZone)
	log.Printf("[PORTAL] Jogador #%d viajou de '%s' (Zona %d) para '%s' (Zona %d) via %s em (%.1f, %.1f, %.1f)\n",
		player.ID, world.GetZoneName(oldZone), oldZone, zoneName, newZone, portal.Name, targetX, targetY, targetZ)
	s.BroadcastNPCSay(0, fmt.Sprintf("[Mundo] Jogador #%d viajou para a %s (Zona %d).", player.ID, zoneName, newZone))
}

// handlePlayerInteract valida distância e invoca a função OnPlayerInteract no Lua.
func (s *Server) handlePlayerInteract(pkt protocol.PlayerInteractPacket) {
	s.mu.RLock()
	player, playerExists := s.players[pkt.PlayerID]
	npc, npcExists := s.npcs[pkt.TargetNPCID]
	var px, py, pz float32
	var pRace, pClass, pMAS uint8
	if playerExists {
		player.Mu.RLock()
		px, py, pz = player.PosX, player.PosY, player.PosZ
		pRace, pClass, pMAS = player.RaceID, player.ClassID, player.MAS
		player.Mu.RUnlock()
	}
	s.mu.RUnlock()

	if !playerExists || !npcExists {
		return
	}

	if npc.CanInteract(px, py, pz) {
		log.Printf("[INTERACAO] Jogador %d (Raça: %d, Classe: %d, MAS: %d) interagindo com NPC '%s' (ID %d)\n", pkt.PlayerID, pRace, pClass, pMAS, npc.Name, npc.ID)

		// 0. Ganho Universal de Afiança por Interação / Conversa Diária (+5 pontos):
		player.AddFriendship(pkt.TargetNPCID, 5)
		s.sendFriendshipSync(player, pkt.TargetNPCID)

		// Entrega de Presentes Compatíveis:
		// Garrick (ID 100 ou 1): Aceita Ferro (+20 Afiança)
		if (pkt.TargetNPCID == 100 || pkt.TargetNPCID == 1) && player.HasItem(protocol.ItemIronOre) {
			player.RemoveItem(protocol.ItemIronOre, 1)
			newPts := player.AddFriendship(pkt.TargetNPCID, 20)
			s.sendFriendshipSync(player, pkt.TargetNPCID)
			s.sendInventorySync(player)
			s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Pelos deuses da bigorna! Um excelente lingote de Ferro! Muito obrigado pelo presente, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
			log.Printf("[PRESENTE] Jogador #%d entregou Ferro para Garrick (+20 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
		}

		// Lyra (ID 103 ou 102): Aceita Frascos de Sangue compatíveis (+15 a +25 Afiança)
		if pkt.TargetNPCID == 103 || pkt.TargetNPCID == 102 {
			if player.HasItem(protocol.ItemPureLunarBlood) {
				player.RemoveItem(protocol.ItemPureLunarBlood, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 25)
				s.sendFriendshipSync(player, pkt.TargetNPCID)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Fascinante! Sangue Lunar Puro em um frasco! Que essência sublime para alquimia! Muito obrigada, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Sangue Lunar Puro para Lyra (+25 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			} else if player.HasItem(protocol.ItemFreshWolfBlood) && !player.HasItem(protocol.ItemEmptyFlask) {
				player.RemoveItem(protocol.ItemFreshWolfBlood, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 15)
				s.sendFriendshipSync(player, pkt.TargetNPCID)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Um frasco com Sangue Lupino fresco! Excelente para minhas infusões! Muito obrigada, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Sangue Lupino para Lyra (+15 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			}
		}

		// Irmã Seraphina (ID 107): Aceita Amuletos de Prata ou Anéis Estelares (+20 Afiança)
		if pkt.TargetNPCID == 107 {
			if player.HasItem(protocol.ItemSilverMoonAmulet) {
				player.RemoveItem(protocol.ItemSilverMoonAmulet, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 20)
				s.sendFriendshipSync(player, pkt.TargetNPCID)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Que a Luz Sagrada abençoe sua generosidade com o santuário, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d doou Amuleto para Seraphina (+20 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			}
		}

		// Mestre Aurelius (ID 108): Aceita Anéis Estelares (+20 Afiança)
		if pkt.TargetNPCID == 108 {
			if player.HasItem(protocol.ItemStarlightRing) {
				player.RemoveItem(protocol.ItemStarlightRing, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 20)
				s.sendFriendshipSync(player, pkt.TargetNPCID)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Extraordinário! A ressonância deste anel estelar é inestimável para minhas pesquisas astronômicas, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Anel Estelar para Aurelius (+20 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			}
		}

		// Kaelen (ID 109): Aceita Presas Lupinas ou Peles de Lobo Alfa (+15 a +25 Afiança)
		if pkt.TargetNPCID == 109 {
			if player.HasItem(protocol.ItemAlphaWolfPelt) {
				player.RemoveItem(protocol.ItemAlphaWolfPelt, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 25)
				s.sendFriendshipSync(player, pkt.TargetNPCID)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Pelos rastros da mata! Uma pele intacta de Lobo Alfa! Você é um caçador de verdade, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Pele de Lobo Alfa para Kaelen (+25 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			} else if player.HasItem(protocol.ItemSharpWolfFang) {
				player.RemoveItem(protocol.ItemSharpWolfFang, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 15)
				s.sendFriendshipSync(player, pkt.TargetNPCID)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Uma bela presa afiada de lobo. Vou usá-la em pontas de flechas perfurantes. Valeu, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Presa Lupina para Kaelen (+15 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			}
		}

		// Alquimista Esquecido (ID 110): Aceita Glândulas de Veneno (+25 Afiança)
		if pkt.TargetNPCID == 110 {
			if player.HasItem(protocol.ItemDarkPoisonGland) {
				player.RemoveItem(protocol.ItemDarkPoisonGland, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 25)
				s.sendFriendshipSync(player, pkt.TargetNPCID)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Sssss... Um veneno primordial tão concentrado... Minha essência se alimenta deste néctar proibido, mortal #%d... [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Veneno ao Alquimista Esquecido (+25 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			}
		}

		// Missão "O Aprendiz do Ferreiro" com Garrick
		if (pkt.TargetNPCID == 100 || pkt.TargetNPCID == 1) && s.handleBlacksmithQuest(player, pkt.TargetNPCID) {
			return
		}

		// Provações de Linhagem que se concluem conversando com um NPC
		if s.checkRaceTrialsOnInteract(player, pkt.TargetNPCID) {
			return
		}

		// Novos Mestres de Classe (111 a 115) e o Eremita secreto (116)
		if s.handleClassMasterInteract(player, pkt.TargetNPCID) {
			return
		}

		// 1. Mestres de Classes Básicas para Viajantes Sem Classe (ClassID == 0):
		// Capitão Randel (ID 105 ou 104): Ensina Espadachim da Aurora (1) e Desperta Cavaleiro do Vazio (26)
		if pkt.TargetNPCID == 105 || pkt.TargetNPCID == 104 {
			// Desafio Secreto: Cavaleiro do Vazio (Classe 14)
			if player.BlockedBossRupture && player.ClassID != protocol.ClassRiftKnight {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassRiftKnight, protocol.IdentityModeSecretReset)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Pelos deuses da guerra! Seu escudo resistiu ao impacto titânico do monstro durante o cataclismo lunar! Uma fenda dimensional responde ao seu comando... Confirme, #%d, e eu o proclamarei um Cavaleiro do Vazio!", pkt.PlayerID))
				log.Printf("[CLASSE SECRETA] Capitão Randel iniciou o jogador #%d como Cavaleiro do Vazio (Classe 14)!\n", pkt.PlayerID)
				return
			}

			if player.ClassID == protocol.ClassNone {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassSwordsman, protocol.IdentityModeInitialChange)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Bem-vindo à vanguarda, recruta #%d! Confirme para se tornar um Espadachim da Aurora (Tier 1). Empunhe sua lâmina com honra!", pkt.PlayerID))
				log.Printf("[MESTRE] Capitão Randel ofereceu a Classe Espadachim da Aurora (1) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassSwordsman && player.Level >= 10 {
				s.checkProgressionMilestones(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Capitão Randel: Seu domínio da lâmina amadureceu, guerreiro #%d. Escolha entre a Vanguarda Real e o Espadachim Mágico!", pkt.PlayerID))
				return
			}
		}

		// Guarda Valen / Mestre Caçador (ID 106 ou 105): Ensina Sentinela dos Ventos (3)
		if pkt.TargetNPCID == 106 {
			if player.ClassID == protocol.ClassNone {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassScout, protocol.IdentityModeInitialChange)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Passos firmes e olhos na mata, aventureiro #%d! Confirme para aprender as artes do Sentinela dos Ventos (Tier 1)!", pkt.PlayerID))
				log.Printf("[MESTRE] Mestre Caçador ofereceu a Classe Sentinela dos Ventos (3) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if (player.ClassID == protocol.ClassScout || player.ClassID == protocol.ClassInitiate || player.ClassID == protocol.ClassAcolyte) && player.Level >= 10 {
				s.checkProgressionMilestones(player)
			}
		}

		// Garrick, o Ferreiro (ID 100 ou 1): Ensina Forjador de Estrelas (5)
		if pkt.TargetNPCID == 100 || pkt.TargetNPCID == 1 {
			// Regra de Exclusividade Rígida: Alquimistas são rejeitados
			if player.ClassID == protocol.ClassAlchemist {
				s.BroadcastNPCSay(pkt.TargetNPCID, "Minhas bigornas não servem para quem gasta o dia misturando fumacinhas em frascos. Vá ver a Lyra!")
				fLevel := player.GetFriendshipLevel(pkt.TargetNPCID)
				_ = luaengine.CallOnPlayerInteract(npc, pkt.PlayerID, s.clock.GetCurrentHour(), pRace, pClass, pMAS, fLevel)
				return
			}

			if player.ClassID == protocol.ClassNone {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassBlacksmith, protocol.IdentityModeInitialChange)
				s.BroadcastNPCSay(100, fmt.Sprintf("Pela bigorna sagrada! Você quer aprender a forjar e a esmagar aço? Confirme e eu te ensino a ser um Forjador de Estrelas (Tier 1), #%d!", pkt.PlayerID))
				log.Printf("[MESTRE] Garrick ensinou a Classe Forjador de Estrelas (5) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassBlacksmith {
				// Receita Secreta de Arma ao estreitar laços com Garrick (Afiança Nível 3+ / 70+ pontos)
				fPoints := player.GetFriendship(pkt.TargetNPCID)
				fLevel := player.GetFriendshipLevel(pkt.TargetNPCID)
				if (fLevel >= 3 || fPoints >= 70) && !player.HasUnlockedRecipe(protocol.ItemRunicWarhammerRecipe) {
					player.UnlockRecipe(protocol.ItemRunicWarhammerRecipe)
					player.AddItem(protocol.ItemRunicWarhammerRecipe, 1)
					s.sendInventorySync(player)
					s.BroadcastNPCSay(pkt.TargetNPCID, "Vejo que você tem talento com o martelo. Tome, vou te ensinar a forjar o Malho de Batalha Rúnico, uma arma que você não acha em nenhuma prateleira!")
					log.Printf("[RECEITA] Garrick ensinou a receita do Malho de Batalha Rúnico ao Ferreiro #%d!\n", pkt.PlayerID)
					return
				}
				if player.Level >= 10 {
					s.checkProgressionMilestones(player)
				}
			}
		}

		// Lyra, a Alquimista (ID 103 ou 102): Ensina Alquimista (6)
		if pkt.TargetNPCID == 103 || pkt.TargetNPCID == 102 {
			// Restrição Rígida: Ferreiros brutos sem afiança suficiente (Nível <= 2) têm comércio fechado
			if player.ClassID == protocol.ClassBlacksmith && player.GetFriendshipLevel(pkt.TargetNPCID) <= 2 {
				s.BroadcastNPCSay(pkt.TargetNPCID, "Tire essas luvas sujas de fuligem e ferro de perto dos meus frascos de vidro cristalino! Ferreiros brutos só sabem quebrar vidrarias finas. Não tenho nada para você até que aprenda a ter delicadeza!")
				fLevel := player.GetFriendshipLevel(pkt.TargetNPCID)
				_ = luaengine.CallOnPlayerInteract(npc, pkt.PlayerID, s.clock.GetCurrentHour(), pRace, pClass, pMAS, fLevel)
				return
			}

			if player.ClassID == protocol.ClassNone {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassAlchemist, protocol.IdentityModeInitialChange)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("O equilíbrio dos elementos é a maior das magias! Confirme e eu te ensino a arte do Transmutador (Tier 1), #%d!", pkt.PlayerID))
				log.Printf("[MESTRE] Lyra ensinou a Classe Transmutador (6) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassAlchemist && player.Level >= 10 {
				s.checkProgressionMilestones(player)
			}
		}

		// Gatilho Secreto Engenheiro Rúnico com Garrick (NPCID = 100 ou 1)
		if (pkt.TargetNPCID == 100 || pkt.TargetNPCID == 1) && player.Level >= 5 && player.HasItem(protocol.ItemHeavySteelPlate) {
			if !player.HasItem(protocol.ItemStarforgeCore) {
				player.RemoveItem(protocol.ItemHeavySteelPlate, 1)
				player.AddItem(protocol.ItemStarforgeCore, 1)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(100, fmt.Sprintf("Pelos deuses da bigorna! Essa Placa de Aço do Executor é pura liga estelar... Tome este Núcleo de Forja Estelar, aventureiro #%d! Use-o em seu inventário para despertar como Engenheiro Rúnico!", pkt.PlayerID))
				log.Printf("[SEGREDO] Garrick forjou o Núcleo de Forja Estelar (Item 18) para o jogador #%d!\n", pkt.PlayerID)
				return
			}
		}

		// Alquimia com Lyra (NPCID = 103 ou 102)
		if pkt.TargetNPCID == 103 || pkt.TargetNPCID == 102 {
			currentH := s.clock.GetCurrentHour()
			// Transmutação de Poção de Sangue Lupino
			if (player.ClassID == protocol.ClassAlchemist || pMAS >= 12) && player.HasItem(protocol.ItemFreshWolfBlood) && player.HasItem(protocol.ItemEmptyFlask) {
				player.RemoveItem(protocol.ItemFreshWolfBlood, 1)
				player.RemoveItem(protocol.ItemEmptyFlask, 1)
				player.AddItem(protocol.ItemWolfBloodPotion, 1)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(103, fmt.Sprintf("Maravilhoso! Transmutei seu Sangue Lupino e o Frasco Vazio em uma autêntica Poção de Sangue Lupino (+20%% Velocidade e Crítico), aventureiro #%d!", pkt.PlayerID))
				log.Printf("[ALQUIMIA] Lyra transmutou Poção de Sangue Lupino (Item 4) para jogador #%d!\n", pkt.PlayerID)
				return
			}
			// Fornecimento inicial de Frascos Vazios na Tenda (dia)
			if currentH >= 7 && currentH < 19 && !player.HasItem(protocol.ItemEmptyFlask) && !player.HasItem(protocol.ItemWolfBloodPotion) {
				player.AddItem(protocol.ItemEmptyFlask, 2)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(103, fmt.Sprintf("Pegue estes 2 Frascos Vazios de cortesia, aventureiro #%d. Use-os para extrair sangues e venenos das criaturas abatidas!", pkt.PlayerID))
				return
			}
		}

		// Mercador Sombrio Varis (NPCID = 104 ou 103)
		if pkt.TargetNPCID == 104 || pkt.TargetNPCID == 103 {
			currentH := s.clock.GetCurrentHour()
			if currentH >= 6 && currentH < 18 {
				return // De dia fica inativo/silencioso
			}
			// Mercado Negro: Goblins compram o Diagrama do Mecha (requisito do Barão Engrenagem, Classe Única 26)
			if player.RaceID == protocol.RaceGoblin && !player.HasItem(protocol.ItemMechaBlueprint) && player.ClassID != protocol.ClassScrapBaron {
				player.AddItem(protocol.ItemMechaBlueprint, 1)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(104, fmt.Sprintf("Pssiu... Um goblin de olho no Mercado Negro! Leve este Diagrama do Mecha, #%d. Com ele, a sucata vira um exoesqueleto de guerra...", pkt.PlayerID))
				return
			}
			// Iniciação do Ceifador da Lua Negra com Tomo (o Tomo só é consumido quando o jogador confirma)
			if player.HasItem(protocol.ItemEclipseScytheTome) && player.ClassID != protocol.ClassEclipseReaper {
				player.OfferIdentity(player.RaceID, protocol.ClassEclipseReaper, protocol.IdentityModeSecretReset, protocol.ItemEclipseScytheTome)
				s.sendEvolutionOffer(player, protocol.OfferTypeIdentityChange, protocol.ClassEclipseReaper, player.RaceID)
				s.BroadcastNPCSay(104, fmt.Sprintf("Pssiu... As sombras o acolhem, novo Ceifador da Lua Negra #%d! Sua alma agora ceifará a escuridão!", pkt.PlayerID))
				log.Printf("[MESTRE] Varis iniciou o jogador #%d como Ceifador da Lua Negra (Classe 7)!\n", pkt.PlayerID)
				return
			}
			// Troca sombria: Glândula de Veneno por Cálice da Alma Partida
			if player.HasItem(protocol.ItemDarkPoisonGland) && !player.HasItem(protocol.ItemBrokenSoulChalice) {
				player.RemoveItem(protocol.ItemDarkPoisonGland, 1)
				player.AddItem(protocol.ItemBrokenSoulChalice, 1)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(104, fmt.Sprintf("Pssiu... Um veneno tão letal merece uma recompensa à altura. Pegue este Cálice da Alma Partida, viajante #%d. Se a morte o encontrar à noite com ele em mãos, seu verdadeiro destino despertará...", pkt.PlayerID))
				log.Printf("[MERCADOR SOMBRIO] Varis entregou o Cálice da Alma Partida (Item 14) para o jogador #%d!\n", pkt.PlayerID)
				return
			}
		}

		// Irmã Seraphina (ID 107): Ensina Guardião do Bastião (6) e Desperta Inquisidor da Chama Branca (23)
		if pkt.TargetNPCID == 107 {
			// Desafio Secreto: Inquisidor da Chama Branca (Classe 11)
			// Com 3+ abates à beira da morte (LowHPKills >= 3), falar com Seraphina com < 30% HP
			if player.LowHPKills >= 3 && float32(player.HP) < float32(player.MaxHP)*0.30 && player.ClassID != protocol.ClassAshInquisitor {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassAshInquisitor, protocol.IdentityModeSecretReset)
				s.BroadcastNPCSay(107, fmt.Sprintf("Você sangrou no limiar da morte, mas sua penitência forjou uma fé inabalável... Erga-se das cinzas sagradas, Inquisidor da Chama Branca #%d!", pkt.PlayerID))
				log.Printf("[CLASSE SECRETA] Irmã Seraphina iniciou o jogador #%d como Inquisidor da Chama Branca (Classe 11)!\n", pkt.PlayerID)
				return
			}

			if player.ClassID == protocol.ClassNone {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassShieldBearer, protocol.IdentityModeInitialChange)
				s.BroadcastNPCSay(107, fmt.Sprintf("A Luz Sagrada ilumina seus passos, recruta #%d! Confirme para se tornar um Guardião do Bastião (Tier 1)!", pkt.PlayerID))
				log.Printf("[MESTRE] Irmã Seraphina ofereceu a Classe Guardião do Bastião (6) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassAcolyte && player.Level >= 10 {
				s.checkProgressionMilestones(player)
				s.BroadcastNPCSay(107, fmt.Sprintf("Irmã Seraphina: Sua devoção celestial amadureceu, guardião #%d. Escolha entre Clérigo da Luz e Inquisidor Solar!", pkt.PlayerID))
				return
			}
		}

		// Mestre Aurelius (ID 108): Ensina Arcanista (2) e Desperta Bailarino das Estrelas (22)
		if pkt.TargetNPCID == 108 {
			currentH := s.clock.GetCurrentHour()
			isNight := (currentH >= 18 || currentH < 6)
			// Desafio Secreto: Bailarino das Estrelas (Classe 10)
			// UntouchedKills >= 10 e falar com Mestre Aurelius à noite
			if isNight && player.UntouchedKills >= 10 && player.ClassID != protocol.ClassAstralDancer {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassAstralDancer, protocol.IdentityModeSecretReset)
				s.BroadcastNPCSay(108, fmt.Sprintf("Incrível! Você dançou através de dez combates sem sofrer um único golpe sequer sob o manto celestial! O cosmos escolheu você, Bailarino das Estrelas #%d!", pkt.PlayerID))
				log.Printf("[CLASSE SECRETA] Mestre Aurelius iniciou o jogador #%d como Bailarino das Estrelas (Classe 10)!\n", pkt.PlayerID)
				return
			}

			if player.ClassID == protocol.ClassNone {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassInitiate, protocol.IdentityModeInitialChange)
				s.BroadcastNPCSay(108, fmt.Sprintf("O cosmos revela seus segredos a você, sábio #%d! Confirme para se tornar um Arcanista (Tier 1)!", pkt.PlayerID))
				log.Printf("[MESTRE] Mestre Aurelius ofereceu a Classe Arcanista (2) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassInitiate && player.Level >= 10 {
				s.checkProgressionMilestones(player)
				s.BroadcastNPCSay(108, fmt.Sprintf("Mestre Aurelius: Seu domínio do éter e das luas atingiu o limiar superior, mago #%d. Escolha entre Feiticeiro Astral e Conjurador Elemental!", pkt.PlayerID))
				return
			}
		}

		// Kaelen, o Mestre Caçador (ID 109): Ensina Sentinela dos Ventos (3) e Desperta Senhor da Selva Primordial (25)
		if pkt.TargetNPCID == 109 {
			pSTR, _, _, _, _, pSPI, _, _ := player.GetAttributes()
			// Desafio Secreto: Senhor da Selva Primordial (Classe 13)
			// Derrotar o Lobo Alfa Solo e falar com Kaelen tendo FOR >= 15 e ESP >= 15
			if player.SoloAlphaWolfKilled && pSTR >= 15 && pSPI >= 15 && player.ClassID != protocol.ClassPrimordialTamer {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassPrimordialTamer, protocol.IdentityModeSecretReset)
				s.BroadcastNPCSay(109, fmt.Sprintf("Pelos rastros das feras ancestrais! Você derrotou o Lobo Alfa em duelo solitário e possui a têmpera de um verdadeiro alfa (FOR %d, ESP %d)! Desperte o Espírito Alfa, Senhor da Selva Primordial #%d!", pSTR, pSPI, pkt.PlayerID))
				log.Printf("[CLASSE SECRETA] Kaelen iniciou o jogador #%d como Senhor da Selva Primordial (Classe 13)!\n", pkt.PlayerID)
				return
			}

			if player.ClassID == protocol.ClassNone {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassScout, protocol.IdentityModeInitialChange)
				s.BroadcastNPCSay(109, fmt.Sprintf("Olhos afiados e passos nas folhas, parceiro #%d! Confirme para se tornar um Sentinela dos Ventos (Tier 1)!", pkt.PlayerID))
				log.Printf("[MESTRE] Kaelen ofereceu a Classe Sentinela dos Ventos (3) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassScout && player.Level >= 10 {
				s.checkProgressionMilestones(player)
				s.BroadcastNPCSay(109, fmt.Sprintf("Kaelen: Seu instinto de sobrevivência é digno dos maiores caçadores de Lunaria, #%d. Escolha entre Guarda Florestal e Atirador de Elite!", pkt.PlayerID))
				return
			}
		}

		// O Alquimista Esquecido (ID 110): Ativo na madrugada (00h às 04h) e Desperta Arauto do Ossuário (12)
		if pkt.TargetNPCID == 110 {
			currentH := s.clock.GetCurrentHour()
			if currentH > 4 {
				return
			}

			// Desafio Secreto: Arauto do Ossuário (Classe 12)
			// Com 5+ acertos perfeitos seguidos (PerfectAutopsiesStreak >= 5) na madrugada
			if player.PerfectAutopsiesStreak >= 5 && player.ClassID != protocol.ClassBoneNecromancer {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassBoneNecromancer, protocol.IdentityModeSecretReset)
				s.BroadcastNPCSay(110, fmt.Sprintf("Sssss... Cinco autópsias cirúrgicas perfeitas sem lacerar um único órgão vital... Você compreende a arquitetura dos ossos e da morte. Eu o consagro como Arauto do Ossuário #%d!", pkt.PlayerID))
				log.Printf("[CLASSE SECRETA] Alquimista Esquecido iniciou o jogador #%d como Arauto do Ossuário (Classe 12)!\n", pkt.PlayerID)
				return
			}
		}

		fLevel := player.GetFriendshipLevel(pkt.TargetNPCID)
		_ = luaengine.CallOnPlayerInteract(npc, pkt.PlayerID, s.clock.GetCurrentHour(), pRace, pClass, pMAS, fLevel)
	} else {
		dist := npc.DistanceTo(px, py, pz)
		log.Printf("[INTERACAO] Jogador %d tentou interagir com NPC %d fora do alcance (%.2fm > 5.0m)\n", pkt.PlayerID, npc.ID, dist)
	}
}

// handlePlayerAction processa ataques físicos, habilidades e esquivas via UDP.
func (s *Server) handlePlayerAction(pkt protocol.PlayerActionPacket) {
	s.mu.RLock()
	player, exists := s.players[pkt.PlayerID]
	s.mu.RUnlock()

	if !exists {
		return
	}

	// 0. Validação de Cooldown autoritativo
	if !player.CanPerformAction(pkt.ActionType) {
		return
	}

	// 0.1. Atacar revela quem está invisível/furtivo (a esquiva não revela)
	if pkt.ActionType != protocol.ActionDodgeRoll && player.IsStealthed() {
		player.BreakStealth()
	}

	// 0.2. Passiva Punhos de Ferro (Punho Celeste / Punho Fantasma): a cada 3 socos, escudo de 1.5s (-50% dano)
	if pkt.ActionType == protocol.ActionBasicAttack && (player.ClassID == protocol.ClassFighter || player.ClassID == protocol.ClassShadowMonk) {
		if player.RegisterPunch() {
			player.SetParry(1500 * time.Millisecond)
		}
	}

	// 1. Custo de Estamina por Tipo de Ação
	var staminaCost float32
	switch pkt.ActionType {
	case protocol.ActionBasicAttack: // 1: Ataque Básico (sem custo de stamina)
		staminaCost = 0.0
	case protocol.ActionDodgeRoll: // 2: Esquiva (20 stamina, 10 para Thalassiano e Bailarino das Estrelas)
		if !player.CanSprint() {
			return // acima de 100% do peso não há esquiva/dash
		}
		staminaCost = 20.0
		if player.RaceID == protocol.RaceThalassian || player.ClassID == protocol.ClassAstralDancer || player.ClassID == protocol.ClassAegisValkyrie {
			staminaCost = 10.0
		}
	case protocol.ActionSkillQ: // 3: Habilidade 1 [Q] (15 stamina)
		staminaCost = 15.0
	case protocol.ActionSkillR: // 4: Habilidade 2 [R] (20 stamina)
		staminaCost = 20.0
	case protocol.ActionSkillF: // 5: Habilidade 3 [F] - Ultimate (25 stamina)
		staminaCost = 25.0
	default:
		staminaCost = 0.0
	}

	// Habilidades Q/R/F: o recurso depende da classe (físicas: Stamina, mágicas: Mana, híbridas: as duas)
	if skillStam, skillMana := world.SkillCost(player.ClassID, pkt.ActionType); skillStam > 0 || skillMana > 0 {
		staminaCost = 0
		if !player.PaySkillCost(skillStam, skillMana) {
			s.sendPlayerStats(player) // recurso insuficiente
			return
		}
	}
	if staminaCost > 0 && !player.ConsumeStamina(staminaCost) {
		// Estamina insuficiente para executar a ação
		s.sendPlayerStats(player)
		return
	}
	player.MarkInCombat()

	player.RecordAction(pkt.ActionType)

	// 2. Esquiva (ActionType 2): concede 0.5s de I-Frames de invulnerabilidade e atualiza estamina
	if pkt.ActionType == protocol.ActionDodgeRoll {
		player.SetDodgeIFrame(500 * time.Millisecond)
		s.sendPlayerStats(player)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionDodgeRoll, 0, 0, 0, 0)
		return
	}

	// 3. Parâmetros do jogador
	player.Mu.RLock()
	px, py, pz := player.PosX, player.PosY, player.PosZ
	rotY := player.RotY
	raceID := player.RaceID
	classID := player.ClassID
	classTier := player.ClassTier
	level := player.Level
	hp := player.HP
	maxHP := player.MaxHP
	buffActive := player.IsBuffActive()
	player.Mu.RUnlock()

	pSTR, pDEX, _, _, pINT, pSPI, pMAS, pLCK := player.GetAttributes()

	var buffVal uint8 = 0
	if buffActive {
		buffVal = 1
	}

	// Normaliza vetor de mira
	aimX := pkt.AimDirX
	aimZ := pkt.AimDirZ
	aimLen := float32(math.Sqrt(float64(aimX*aimX + aimZ*aimZ)))
	if aimLen < 0.001 {
		aimX = -float32(math.Sin(float64(rotY)))
		aimZ = -float32(math.Cos(float64(rotY)))
	} else {
		aimX /= aimLen
		aimZ /= aimLen
	}

	// 2.1. Habilidade Racial Ativa (ActionType 6 - Tecla Z, cooldown 10s)
	if pkt.ActionType == protocol.ActionRacialSkill {
		s.handleRacialSkill(player, px, py, pz, aimX, aimZ, raceID, pSTR, pDEX, pINT, pSPI, pMAS, pLCK)
		s.sendPlayerStats(player)
		return
	}

	// 3.1. Espadachim da Aurora (1): R = Investida Imparável (Dash 6m + empurrão/atordoamento); F = Julgamento da Espada (AoE 4.5m)
	if classID == protocol.ClassWarrior {
		if pkt.ActionType == protocol.ActionSkillR {
			player.Mu.Lock()
			player.PosX += aimX * 6.0
			player.PosZ += aimZ * 6.0
			newPX, newPZ := player.PosX, player.PosZ
			player.Mu.Unlock()
			s.BroadcastPlayerRespawn(player.ID, player.PosX, player.PosY, player.PosZ)
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-newPX)*(mx-newPX) + (mz-newPZ)*(mz-newPZ))))
					if dist <= 4.0 {
						mob.ApplyStun(1500 * time.Millisecond)
					}
				}
			}
			log.Printf("[INVESTIDA IMPARÁVEL] Espadachim da Aurora #%d avançou 6m desferindo investida!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 4.5, 400)
		}
	}

	// 3.2. Arcanista (2): R = Prisão Glacial (Congela e empurra inimigos em 5m por 2s); F = Chuva de Meteoros (6m AoE)
	if classID == protocol.ClassMage {
		if pkt.ActionType == protocol.ActionSkillR {
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 5.0 {
						mob.ApplyStun(2000 * time.Millisecond)
					}
				}
			}
			log.Printf("[PRISÃO GLACIAL] Arcanista #%d congelou inimigos em 5m por 2s!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px+aimX*3.0, pz+aimZ*3.0, 6.0, 500)
		}
	}

	// 3.3. Sentinela dos Ventos (3): R = Salto Acrobático (recuo 4m + flecha imobiliza 2s); F = Tempestade de Mil Flechas (6m AoE)
	if classID == protocol.ClassArcher {
		if pkt.ActionType == protocol.ActionSkillR {
			player.Mu.Lock()
			player.PosX -= aimX * 4.0
			player.PosZ -= aimZ * 4.0
			player.Mu.Unlock()
			s.BroadcastPlayerRespawn(player.ID, player.PosX, player.PosY, player.PosZ)
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 8.0 {
						mob.ApplyStun(2000 * time.Millisecond)
					}
				}
			}
			log.Printf("[SALTO ACROBÁTICO] Sentinela dos Ventos #%d recuou prendendo inimigo!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px+aimX*4.0, pz+aimZ*4.0, 6.0, 450)
		}
	}

	// 3.4. Lâmina Silente (4): Q = Passo das Sombras (teleporta 5m cortando); R = Cortina de Fumaça (2.5s I-Frame + 30% vel); F = Lótus de Sangue (4m)
	if classID == protocol.ClassAssassin {
		if pkt.ActionType == protocol.ActionSkillQ {
			// Teleporta para as costas do alvo mais próximo à frente (até 8m); sem alvo, avança 5m
			bx, bz, found := s.shadowStepTarget(player, px, pz, aimX, aimZ)
			player.Mu.Lock()
			if found {
				player.PosX, player.PosZ = bx, bz
			} else {
				player.PosX += aimX * 5.0
				player.PosZ += aimZ * 5.0
			}
			player.Mu.Unlock()
			s.BroadcastPlayerRespawn(player.ID, player.PosX, player.PosY, player.PosZ)
			log.Printf("[PASSO DAS SOMBRAS] Lâmina Silente #%d teleportou cortando pelas costas!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillR {
			player.SetDodgeIFrame(2500 * time.Millisecond)
			player.SetBuff(2500 * time.Millisecond)
			player.SetInvisible(2500*time.Millisecond, true)
			log.Printf("[CORTINA DE FUMAÇA] Lâmina Silente #%d ativou invisibilidade e intangibilidade por 2.5s!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 4.0, 300)
		}
	}

	// 3.5. Punho Celeste (5): Q = Gancho Demolidor (atordoamento); R = Postura do Lótus Marcial (cura +40 HP, -50% dano 3s); F = Meteoro de Um Punho (5.5m)
	if classID == protocol.ClassFighter {
		if pkt.ActionType == protocol.ActionSkillQ {
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 3.5 {
						mob.ApplyStun(1000 * time.Millisecond)
					}
				}
			}
		} else if pkt.ActionType == protocol.ActionSkillR {
			player.Heal(40)
			player.SetParry(3000 * time.Millisecond)
			log.Printf("[LÓTUS MARCIAL] Punho Celeste #%d curou +40 HP e ativou 50%% redução de dano!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px+aimX*2.0, pz+aimZ*2.0, 5.5, 450)
		}
	}

	// 3.6. Guardião do Bastião (6): Q = Esmagamento de Bastião (Taunt 8m); R = Formação Impenetrável (80% bloqueio 4s + escudo aliados); F = Cidadela Inabalável (+70 HP grupo)
	if classID == protocol.ClassShieldBearer {
		if pkt.ActionType == protocol.ActionSkillQ {
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 8.0 {
						mob.Mu.Lock()
						mob.TargetPlayerID = player.ID
						mob.Mu.Unlock()
					}
				}
			}
			log.Printf("[BASTIÃO] Guardião do Bastião #%d provocou monstros em 8m!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillR {
			player.SetParry(4000 * time.Millisecond)
			s.mu.RLock()
			playerZone := player.GetZone()
			for _, ally := range s.players {
				if ally.GetZone() != playerZone {
					continue
				}
				ally.Mu.RLock()
				ax, az := ally.PosX, ally.PosZ
				ally.Mu.RUnlock()
				adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
				if adist <= 8.0 {
					ally.SetParry(4000 * time.Millisecond)
				}
			}
			s.mu.RUnlock()
			log.Printf("[FORMAÇÃO IMPENETRÁVEL] Guardião do Bastião #%d concedeu escudo de 80%% ao grupo por 4s!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 7.0, 400)
			s.mu.RLock()
			playerZone := player.GetZone()
			for _, ally := range s.players {
				if ally.GetZone() != playerZone {
					continue
				}
				ally.Mu.RLock()
				ax, az := ally.PosX, ally.PosZ
				ally.Mu.RUnlock()
				adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
				if adist <= 7.0 {
					ally.Heal(70)
					ally.SetParry(4000 * time.Millisecond)
					s.sendPlayerStats(ally)
				}
			}
			s.mu.RUnlock()
			log.Printf("[CIDADELA INABALÁVEL] Guardião do Bastião #%d ativou cúpula curando +70 HP no grupo!\n", player.ID)
		}
	}

	// 3.7. Forjador de Estrelas (7): R = Afiação & Têmpera (+25% Atq/Def grupo 10s); F = Dança do Arsenal Forjado (5.5m AoE)
	if classID == protocol.ClassBlacksmith {
		if pkt.ActionType == protocol.ActionSkillR {
			s.mu.RLock()
			playerZone := player.GetZone()
			for _, ally := range s.players {
				if ally.GetZone() != playerZone {
					continue
				}
				ally.Mu.RLock()
				ax, az := ally.PosX, ally.PosZ
				ally.Mu.RUnlock()
				adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
				if adist <= 8.0 {
					ally.SetBuff(10 * time.Second)
					s.sendPlayerStats(ally)
				}
			}
			s.mu.RUnlock()
			log.Printf("[BUFF] Forjador de Estrelas #%d ativou Afiação & Têmpera (+25%% Atq/Def grupo por 10s)!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 400)
		}
	}

	// 3.8. Transmutador (8): Q = Frasco de Fogo Grego & Cura (+45 HP aliados); R = Bomba de Ácido Corrosivo; F = Transmutação do Behemoth (+30% status 8s)
	if classID == protocol.ClassAlchemist {
		if pkt.ActionType == protocol.ActionSkillQ {
			s.mu.RLock()
			playerZone := player.GetZone()
			for _, ally := range s.players {
				if ally.GetZone() != playerZone {
					continue
				}
				ally.Mu.RLock()
				ax, az := ally.PosX, ally.PosZ
				ally.Mu.RUnlock()
				adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
				if adist <= 6.0 {
					ally.Heal(45)
					s.sendPlayerStats(ally)
				}
			}
			s.mu.RUnlock()
			log.Printf("[FOGO GREGO & CURA] Transmutador #%d curou aliados em +45 HP!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillR {
			s.BroadcastAOETelegraph(player.ID, px+aimX*3.0, pz+aimZ*3.0, 3.5, 300)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 400)
			player.SetBuff(8 * time.Second)
			log.Printf("[BEHEMOTH QUÍMICO] Transmutador #%d ativou Transmutação do Behemoth (+30%% status por 8s)!\n", player.ID)
		}
	}

	// 3.9. Escultor de Almas (9): R = Estátua Explosiva / Pele de Mármore (50% redução 3s + AoE 4.5m); F = Técnica Secreta: Escultura do Luar (6m)
	if classID == protocol.ClassSculptor {
		if pkt.ActionType == protocol.ActionSkillR {
			player.SetParry(3000 * time.Millisecond)
			s.BroadcastAOETelegraph(player.ID, px, pz, 4.5, 300)
			log.Printf("[PELE DE MÁRMORE] Escultor de Almas #%d ativou Pele de Mármore e Estátua Explosiva!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 450)
		}
	}

	// 3.10. Senhor das Feras (10): R = Fusão & Uivo Bestial (+50 HP + 30% vel 10s); F = Debandada das Feras Primordiais (7m)
	if classID == protocol.ClassTamer {
		if pkt.ActionType == protocol.ActionSkillR {
			player.Heal(50)
			player.SetBuff(10 * time.Second)
			log.Printf("[UIVO BESTIAL] Senhor das Feras #%d curou +50 HP e ativou velocidade bestial por 10s!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px+aimX*3.5, pz+aimZ*3.5, 7.0, 500)
		}
	}

	// 3.11. Tecelão Carmesim (11): R = Costurar Sombras (prende inimigos 2.5s); F = Gaiola de Fios Carmesins (6m)
	if classID == protocol.ClassWarTailor {
		if pkt.ActionType == protocol.ActionSkillR {
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 6.0 {
						mob.ApplyStun(2500 * time.Millisecond)
					}
				}
			}
			log.Printf("[COSTURAR SOMBRAS] Tecelão Carmesim #%d prendeu inimigos por 2.5s com fios de aço!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 400)
		}
	}

	// 3.12. Mestre do Banquete (12): Q = Desossar a Vivo! (+35 HP); R = Banquete na Wok Flamejante (+55 HP e +25% dano); F = Trinchar o Behemoth (5.5m)
	if classID == protocol.ClassHuntingChef {
		if pkt.ActionType == protocol.ActionSkillQ {
			player.Heal(35)
			log.Printf("[DESOSSAR A VIVO] Mestre do Banquete #%d extraiu corte nobre curando +35 HP!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillR {
			player.SetParry(3000 * time.Millisecond)
			s.mu.RLock()
			playerZone := player.GetZone()
			for _, ally := range s.players {
				if ally.GetZone() != playerZone {
					continue
				}
				ally.Mu.RLock()
				ax, az := ally.PosX, ally.PosZ
				ally.Mu.RUnlock()
				adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
				if adist <= 8.0 {
					ally.Heal(55)
					ally.SetBuff(10 * time.Second)
					s.sendPlayerStats(ally)
				}
			}
			s.mu.RUnlock()
			log.Printf("[BANQUETE NA WOK] Mestre do Banquete #%d serviu banquete curando +55 HP e +25%% dano no grupo!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px+aimX*2.5, pz+aimZ*2.5, 5.5, 450)
		}
	}

	// 3.7. Efeitos Distintos das Classes Secretas (10 a 15)
	// Classe 10 (Bailarino das Estrelas): R = Valsa dos Espelhos (1.5s I-Frame); F = Constelação de Mil Lâminas (5.5m AoE)
	if classID == protocol.ClassAstralDancer {
		if pkt.ActionType == protocol.ActionSkillR {
			player.SetDodgeIFrame(1500 * time.Millisecond)
			log.Printf("[VALSA DOS ESPELHOS] Bailarino das Estrelas #%d ativou Valsa dos Espelhos (1.5s I-Frame)!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 350)
		}
	}

	// Classe 11 (Inquisidor da Chama Branca): R = Selo de Excomunhão (cura +35 HP e queima 5m); F = Crucificação de Cinzas (6.0m AoE)
	if classID == protocol.ClassAshInquisitor {
		if pkt.ActionType == protocol.ActionSkillR {
			player.Heal(35)
			s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
			log.Printf("[SELO DE EXCOMUNHÃO] Inquisidor da Chama Branca #%d curou +35 HP e liberou chamas sagradas!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 450)
		}
	}

	// Classe 12 (Arauto do Ossuário): R = Explosão Óssea & Escudo (5.0m AoE + defesa); F = Legião do Ossuário (6.0m AoE)
	if classID == protocol.ClassBoneNecromancer {
		if pkt.ActionType == protocol.ActionSkillR {
			player.SetParry(2500 * time.Millisecond)
			s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 350)
			log.Printf("[EXPLOSÃO ÓSSEA] Arauto do Ossuário #%d ativou Escudo Ósseo e explosão radial!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 450)
		}
	}

	// Classe 13 (Senhor da Selva Primordial): R = Uivo da Alcateia (cura +50 HP e buffa grupo); F = Fúria do Behemoth (impacto frontal 4.5m)
	if classID == protocol.ClassPrimordialTamer {
		if pkt.ActionType == protocol.ActionSkillR {
			player.Heal(50)
			player.SetBuff(10 * time.Second)
			s.mu.RLock()
			playerZone := player.GetZone()
			for _, ally := range s.players {
				if ally.GetZone() != playerZone {
					continue
				}
				ally.Mu.RLock()
				ax, az := ally.PosX, ally.PosZ
				ally.Mu.RUnlock()
				adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
				if adist <= 10.0 {
					ally.Heal(50)
					ally.SetBuff(10 * time.Second)
					s.sendPlayerStats(ally)
				}
			}
			s.mu.RUnlock()
			log.Printf("[UIVO DA ALCATEIA] Senhor da Selva Primordial #%d curou o grupo em +50 HP e concedeu buff crítico por 10s!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px+aimX*2.5, pz+aimZ*2.5, 4.5, 400)
		}
	}

	// Classe 14 (Cavaleiro do Vazio): Q = Esmagamento Gravitacional (puxa 5m); R = Singularidade Reversa (reduz 80% dano); F = Colapso Estelar (6.5m AoE + atordoa)
	if classID == protocol.ClassRiftKnight {
		if pkt.ActionType == protocol.ActionSkillQ {
			s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 250)
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.Lock()
					mx, mz := mob.PosX, mob.PosZ
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 5.0 && dist > 0.1 {
						mob.PosX = px + (mx-px)*0.35
						mob.PosZ = pz + (mz-pz)*0.35
					}
					mob.Mu.Unlock()
				}
			}
			log.Printf("[ESMAGAMENTO GRAVITACIONAL] Cavaleiro do Vazio #%d puxou inimigos em 5m!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillR {
			player.SetParry(3000 * time.Millisecond)
			s.BroadcastAOETelegraph(player.ID, px, pz, 4.5, 300)
			log.Printf("[SINGULARIDADE REVERSA] Cavaleiro do Vazio #%d ativou escudo gravitacional e fenda espacial!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 6.5, 400)
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 6.5 {
						mob.ApplyStun(2000 * time.Millisecond)
					}
				}
			}
			log.Printf("[COLAPSO ESTELAR] Cavaleiro do Vazio #%d detonou colapso estelar atordoando inimigos!\n", player.ID)
		}
	}

	// Classe 15 (Arauto do Trovão): R = Passo de Relâmpago (choque + vel); F = Ira dos Céus (6.0m AoE)
	if classID == protocol.ClassStormHerald {
		if pkt.ActionType == protocol.ActionSkillR {
			player.SetBuff(8 * time.Second)
			if s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mob.Mu.RUnlock()
					dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
					if dist <= 4.0 {
						mob.ApplyStun(1000 * time.Millisecond)
					}
				}
			}
			log.Printf("[PASSO DE RELÂMPAGO] Arauto do Trovão #%d eletrificou a área e ganhou velocidade!\n", player.ID)
		} else if pkt.ActionType == protocol.ActionSkillF {
			s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 400)
		}
	}

	// Desafio Secreto: Cavaleiro do Vazio (Classe 14)
	// Usar bloqueio/skill R contra Boss/Executor tendo CON >= 20 durante Eclipse ou Lua de Sangue
	if pkt.ActionType == protocol.ActionSkillR {
		_, _, moon, _ := s.clock.GetTime()
		if moon == world.MoonPhaseBloodMoon || moon == world.MoonPhaseEclipse {
			_, _, pCON, _, _, _, _, _ := player.GetAttributes()
			if pCON >= 20 && s.mobManager != nil {
				playerZone := player.GetZone()
				for _, mob := range s.mobManager.GetAllMobs() {
					if !mob.IsAlive || mob.GetZone() != playerZone {
						continue
					}
					if mob.MobType == protocol.MobTypeIronEnforcer || mob.MobType == protocol.MobTypeLycanthropeAlpha ||
						mob.MobType == protocol.MobTypeInquisitorVex || mob.MobType == protocol.MobTypeCommanderVaelen ||
						mob.MobType == protocol.MobTypeMalakorHeraldEclipse {
						mob.Mu.RLock()
						mx, mz := mob.PosX, mob.PosZ
						mob.Mu.RUnlock()
						dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
						if dist <= 8.0 {
							player.Mu.Lock()
							player.BlockedBossRupture = true
							player.Mu.Unlock()
							log.Printf("[RUPTURA] Jogador #%d usou Postura/Skill R contra Boss/Executor #%d (%s) com CON %d durante Lua %d!\n", player.ID, mob.ID, mob.Name, pCON, moon)
							break
						}
					}
				}
			}
		}
	}

	// Desafio Secreto: Arauto do Trovão (Classe 15)
	// Usar a Ultimate (Tecla F) perto da Torre Arcana (20, -18) durante Chuva (Weather == 1)
	if pkt.ActionType == protocol.ActionSkillF {
		weather := s.clock.GetZoneWeather(player.GetZone())
		dx := px - 20.0
		dz := pz - (-18.0)
		distTower := float32(math.Sqrt(float64(dx*dx + dz*dz)))
		if distTower <= 12.0 && world.IsRainy(weather) {
			if player.ClassID != protocol.ClassStormHerald {
				s.offerIdentityChange(player, player.RaceID, protocol.ClassStormHerald, protocol.IdentityModeSecretReset)
				s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 300)
				s.BroadcastNPCSay(108, fmt.Sprintf("[RAIO CELESTIAL] Os céus rugem sobre a Torre Arcana! Um relâmpago divino atingiu o aventureiro #%d, despertando o lendário ARAUTO DA TEMPESTADE!", player.ID))
				log.Printf("[CLASSE SECRETA] Jogador #%d despertou como Arauto do Trovão (15) perto da Torre Arcana sob Chuva!\n", player.ID)
			}
		}
	}

	// 3.7. Únicas Exclusivas de Raça (19 a 26) e Lendárias (31 a 34): efeitos antes do dano
	if protocol.IsTranscendentClass(classID) {
		if s.handleTranscendentPreEffects(player, classID, pkt.ActionType, px, pz, aimX, aimZ) {
			s.sendPlayerStats(player)
			return
		}
	}

	// 3.75. Variantes Secretas (13 a 18): efeitos de R que vêm antes do dano (ou no lugar dele)
	if classID >= protocol.ClassRunicSpellblade && classID <= protocol.ClassPlagueDoctor {
		if s.handleVariantPreEffects(player, classID, pkt.ActionType, px, pz, aimX, aimZ) {
			s.sendPlayerStats(player)
			return
		}
	}

	// 3.8. Disparo de Projéteis 3D
	isProjectileAttack := false
	if classID == protocol.ClassArcher || classID == protocol.ClassAlchemist ||
		(classID == protocol.ClassMage && pkt.ActionType != protocol.ActionSkillR && pkt.ActionType != protocol.ActionSkillF) ||
		(classID == protocol.ClassRunicArtificer && pkt.ActionType >= protocol.ActionSkillQ) ||
		(classID == protocol.ClassHomunculusCreator) ||
		(classID == protocol.ClassBoneNecromancer && pkt.ActionType == protocol.ActionSkillQ) ||
		(classID == protocol.ClassStormHerald && pkt.ActionType == protocol.ActionSkillQ) ||
		(classID == protocol.ClassVampireHunter && (pkt.ActionType == protocol.ActionBasicAttack || pkt.ActionType == protocol.ActionSkillQ)) {
		isProjectileAttack = true
	}

	if isProjectileAttack {
		var projType uint8 = protocol.ProjTypePhysicalArrow
		var speed float32 = 24.0
		var maxRange float32 = 16.0
		var splashRadius float32 = 0.0

		switch classID {
		case protocol.ClassArcher:
			if pkt.ActionType == protocol.ActionSkillQ {
				projType = protocol.ProjTypePiercingArrow
				speed = 32.0
				maxRange = 24.0
			} else if pkt.ActionType == protocol.ActionSkillR {
				projType = protocol.ProjTypePiercingArrow // Salto Acrobático prendendo o alvo
				speed = 28.0
				maxRange = 18.0
			} else if pkt.ActionType == protocol.ActionSkillF {
				// Tempestade de Flechas: 3 flechas simultâneas em cone
				projType = protocol.ProjTypePhysicalArrow
				speed = 26.0
				maxRange = 18.0
				angles := []float64{-0.26, 0.0, 0.26} // -15°, 0°, +15°
				for _, a := range angles {
					cosA := float32(math.Cos(a))
					sinA := float32(math.Sin(a))
					dirX := aimX*cosA - aimZ*sinA
					dirZ := aimX*sinA + aimZ*cosA
					p := s.projManager.SpawnWithAction(player.ID, projType, pkt.ActionType, px, 1.2, pz, dirX, dirZ, speed, maxRange, 0.0)
					s.BroadcastProjectileSpawn(p)
				}
				s.sendPlayerStats(player)
				return
			} else {
				projType = protocol.ProjTypePhysicalArrow
				speed = 26.0
				maxRange = 18.0
			}

		case protocol.ClassMage:
			if pkt.ActionType == protocol.ActionSkillQ {
				projType = protocol.ProjTypeElementalComet // Orbe de Magma explosivo a 18m
				speed = 22.0
				maxRange = 18.0
				splashRadius = 3.5
			} else {
				projType = protocol.ProjTypeArcaneOrb
				speed = 20.0
				maxRange = 16.0
			}

		case protocol.ClassAlchemist:
			projType = protocol.ProjTypeAcidFlask
			speed = 20.0
			maxRange = 13.0
			if pkt.ActionType == protocol.ActionSkillQ {
				splashRadius = 3.5 // Frasco de Fogo Grego & Cura (+45 HP, já aplicado aos aliados em 6m acima)
			} else if pkt.ActionType == protocol.ActionSkillR {
				splashRadius = 4.0 // Bomba de Ácido Corrosivo
			} else {
				splashRadius = 2.2 // Básico químico
			}

		case protocol.ClassRunicArtificer:
			projType = protocol.ProjTypeElementalComet
			speed = 24.0
			maxRange = 16.0
			splashRadius = 3.0

		case protocol.ClassHomunculusCreator:
			projType = protocol.ProjTypeAcidFlask
			speed = 20.0
			maxRange = 14.0
			splashRadius = 2.5
			player.Heal(6) // Regeneração de HP contínua do Homúnculo

		case protocol.ClassBoneNecromancer:
			// Skill Q: Lança de Fêmur (ProjType = 7, 16m)
			projType = protocol.ProjTypeBoneSpear
			speed = 22.0
			maxRange = 16.0

		case protocol.ClassVampireHunter:
			// Besta de Prata: virotes perfurantes; Q = Virote de Prata (22m)
			projType = protocol.ProjTypePiercingArrow
			speed = 30.0
			maxRange = 18.0
			if pkt.ActionType == protocol.ActionSkillQ {
				speed = 36.0
				maxRange = 22.0
			}

		case protocol.ClassStormHerald:
			// Skill Q: Lança do Trovão (ProjType = 8, 18m)
			projType = protocol.ProjTypeLightningSpear
			speed = 32.0
			maxRange = 18.0
			splashRadius = 2.5
		}

		proj := s.projManager.SpawnWithAction(player.ID, projType, pkt.ActionType, px, 1.2, pz, aimX, aimZ, speed, maxRange, splashRadius)
		s.BroadcastProjectileSpawn(proj)
		log.Printf("[PROJETIL] Jogador #%d (Classe %d) disparou Projétil #%d (Tipo %d, Ação %d, Vel: %.1f, Alcance: %.1f)\n",
			player.ID, classID, proj.ID, projType, pkt.ActionType, speed, maxRange)

		s.sendPlayerStats(player)
		return
	}

	// 3.9. Classes Básicas (1 a 12): Q/R/F atingem todos os alvos da área descrita na habilidade
	if shape, ok := classSkillShape(classID, pkt.ActionType); ok {
		h, _, moon, _ := s.clock.GetTime()
		weather := s.clock.GetZoneWeather(player.GetZone())
		hpPct := float32(hp) / float32(maxHP) * 100.0
		damage, isCrit := s.luaEngine.CallCalculateDamage(raceID, classID, pkt.ActionType, hpPct, int(h), moon, weather,
			classTier, level, buffVal, pSTR, pDEX, pINT, pSPI, pMAS, pLCK)
		damage = applyPathDamage(damage, player) // Caminho Evolutivo (Dano)
		cx, cz := px+aimX*shape.offset, pz+aimZ*shape.offset
		originX, originZ := px, pz
		if shape.centerOnSelf {
			player.Mu.RLock()
			cx, cz = player.PosX, player.PosZ
			originX, originZ = cx, cz
			player.Mu.RUnlock()
		}
		s.applyBasicClassSkill(player, classID, pkt.ActionType, cx, cz, originX, originZ, aimX, aimZ, shape, damage, isCrit)
		s.sendPlayerStats(player)
		return
	}

	// 4. Combate Melee / Corpo a Corpo
	attackRange := float32(3.8)
	if classID == protocol.ClassAcolyte {
		attackRange = 4.5
	} else if classID == protocol.ClassBlacksmith || classID == protocol.ClassRunicArtificer {
		attackRange = 4.0
	} else if (classID == protocol.ClassWarTailor || classID == protocol.ClassCrimsonWebSovereign) && pkt.ActionType == protocol.ActionBasicAttack {
		attackRange = 10.0 // Passiva Fios Monofilamento: cortes a até 10m
	} else if classID == protocol.ClassEclipseReaper {
		attackRange = 4.8 // Foice Colossal
	} else if classID == protocol.ClassAshInquisitor && pkt.ActionType == protocol.ActionSkillQ {
		attackRange = 8.0 // Chicote de Penitência (8m)
	} else if classID == protocol.ClassAstralDancer && pkt.ActionType == protocol.ActionSkillF {
		attackRange = 5.5
	} else if (classID == protocol.ClassAshInquisitor || classID == protocol.ClassBoneNecromancer || classID == protocol.ClassStormHerald) && pkt.ActionType == protocol.ActionSkillF {
		attackRange = 6.0
	} else if classID == protocol.ClassRiftKnight && pkt.ActionType == protocol.ActionSkillF {
		attackRange = 6.5
	} else if pkt.ActionType == protocol.ActionSkillF {
		attackRange = 5.0 // Alcance ampliado no Ultimate
	}

	// Detecção de Alvos em Cone ou Área
	var targetDummy *world.TrainingDummy
	var targetMob *world.Mob
	minDist := attackRange + 1.0

	s.mu.RLock()
	playerZone := player.GetZone()
	// Verifica Bonecos de Treino na mesma zona
	for _, dummy := range s.dummies {
		if dummy.GetZone() != playerZone {
			continue
		}
		dx, _, dz := dummy.GetPos()
		distX := dx - px
		distZ := dz - pz
		dist := float32(math.Sqrt(float64(distX*distX + distZ*distZ)))

		if dist <= attackRange && dist > 0.01 {
			dot := (distX/dist)*aimX + (distZ/dist)*aimZ
			isCircleAttack := (pkt.ActionType == protocol.ActionSkillF ||
				(pkt.ActionType == protocol.ActionSkillR && (classID == protocol.ClassInitiate || classID == protocol.ClassBlacksmith || classID == protocol.ClassAshInquisitor || classID == protocol.ClassBoneNecromancer || classID == protocol.ClassRiftKnight || classID == protocol.ClassStormHerald)) ||
				(pkt.ActionType == protocol.ActionSkillQ && classID == protocol.ClassRiftKnight))
			if (isCircleAttack || dot >= 0.25) && dist < minDist {
				minDist = dist
				targetDummy = dummy
				targetMob = nil
			}
		}
	}

	// Verifica Mobs vivos na mesma zona
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive || mob.GetZone() != playerZone {
				continue
			}
			mob.Mu.RLock()
			mx, mz := mob.PosX, mob.PosZ
			mob.Mu.RUnlock()

			distX := mx - px
			distZ := mz - pz
			dist := float32(math.Sqrt(float64(distX*distX + distZ*distZ)))

			if dist <= attackRange && dist > 0.01 {
				dot := (distX/dist)*aimX + (distZ/dist)*aimZ
				isCircleAttack := (pkt.ActionType == protocol.ActionSkillF ||
					(pkt.ActionType == protocol.ActionSkillR && (classID == protocol.ClassInitiate || classID == protocol.ClassBlacksmith || classID == protocol.ClassAshInquisitor || classID == protocol.ClassBoneNecromancer || classID == protocol.ClassRiftKnight || classID == protocol.ClassStormHerald)) ||
					(pkt.ActionType == protocol.ActionSkillQ && classID == protocol.ClassRiftKnight))
				if (isCircleAttack || dot >= 0.25) && dist < minDist {
					minDist = dist
					targetMob = mob
					targetDummy = nil
				}
			}
		}
	}
	s.mu.RUnlock()

	// 5. Aplicação do Dano via Lua se acertou um Alvo
	h, _, moon, _ := s.clock.GetTime()
	weather := s.clock.GetZoneWeather(player.GetZone())
	hpPct := float32(hp) / float32(maxHP) * 100.0

	if targetDummy != nil {
		damage, isCrit := s.luaEngine.CallCalculateDamage(
			raceID,
			classID,
			pkt.ActionType,
			hpPct,
			int(h),
			moon,
			weather,
			classTier,
			level,
			buffVal,
			pSTR,
			pDEX,
			pINT,
			pSPI,
			pMAS,
			pLCK,
		)
		damage = applyPathDamage(damage, player) // Caminho Evolutivo (Dano)

		newHP, reset := targetDummy.TakeDamage(damage)
		_, maxDummyHP := targetDummy.GetHP()

		log.Printf("[COMBATE] Jogador #%d causou %d dano (Crítico: %d) no Boneco #%d | HP Alvo: %d/%d\n",
			player.ID, damage, isCrit, targetDummy.ID, newHP, maxDummyHP)

		if reset {
			log.Printf("[COMBATE] Boneco de Treino #%d foi destruído e restaurado para %d HP!\n", targetDummy.ID, maxDummyHP)
		}

		s.BroadcastCombatEvent(player.ID, targetDummy.ID, pkt.ActionType, damage, isCrit, newHP, maxDummyHP)

		// Lifesteal
		if raceID == protocol.RaceDhampir {
			player.Heal(8)
		}
		if classID == protocol.ClassEclipseReaper {
			player.Heal(12) // Lifesteal do Ceifador
		}
		if classID == protocol.ClassAshInquisitor && pkt.ActionType == protocol.ActionSkillQ {
			ls := uint16(float32(damage) * 0.35)
			if ls == 0 && damage > 0 {
				ls = 1
			}
			player.Heal(ls) // Roubo de vida do Chicote de Penitência
		}
		if player.HasLycanHeartEquipped() {
			ls := uint16(float32(damage) * 0.15)
			if ls == 0 && damage > 0 {
				ls = 1
			}
			player.Heal(ls)
		}
		s.sendPlayerStats(player)

	} else if targetMob != nil {
		damage, isCrit := s.luaEngine.CallCalculateDamage(
			raceID,
			classID,
			pkt.ActionType,
			hpPct,
			int(h),
			moon,
			weather,
			classTier,
			level,
			buffVal,
			pSTR,
			pDEX,
			pINT,
			pSPI,
			pMAS,
			pLCK,
		)
		damage = applyPathDamage(damage, player) // Caminho Evolutivo (Dano)

		damage = variantDamageAgainst(classID, targetMob, damage)

		finalDamage, wasBlocked, newHP, isDead := targetMob.TakeDamage(damage, player.ID)
		s.applyVariantOnHitPassives(player, classID, targetMob, finalDamage, isDead)

		log.Printf("[COMBATE] Jogador #%d causou %d dano (Crítico: %d, Bloqueado: %v) no Mob #%d (%s) | HP: %d/%d\n",
			player.ID, finalDamage, isCrit, wasBlocked, targetMob.ID, targetMob.Name, newHP, targetMob.MaxHP)

		if isDead {
			s.handleMobDeath(targetMob, player.ID)
		}

		s.BroadcastCombatEvent(player.ID, targetMob.ID, pkt.ActionType, finalDamage, isCrit, newHP, targetMob.MaxHP)

		// Lifesteal
		if raceID == protocol.RaceDhampir {
			player.Heal(8)
		}
		if classID == protocol.ClassEclipseReaper {
			player.Heal(12)
		}
		if classID == protocol.ClassAshInquisitor && pkt.ActionType == protocol.ActionSkillQ {
			ls := uint16(float32(finalDamage) * 0.35)
			if ls == 0 && finalDamage > 0 {
				ls = 1
			}
			player.Heal(ls) // Roubo de vida do Chicote de Penitência
		}
		if player.HasLycanHeartEquipped() {
			ls := uint16(float32(finalDamage) * 0.15)
			if ls == 0 && finalDamage > 0 {
				ls = 1
			}
			player.Heal(ls)
		}
		// Passiva Borealin: ataques aplicam lentidão de gelo
		if raceID == protocol.RaceBoreal {
			targetMob.ApplySlow(2*time.Second, 0.7)
		}
		// Passiva Nephilim: de Dia cura aliados ao atacar
		if raceID == protocol.RaceNephilim && (h >= 6 && h < 18) {
			s.healNearbyAllies(player.ID, px, pz, 6.0, 12)
		}
		s.sendPlayerStats(player)

	} else {
		// Golpe desferido sem acertar alvo (Swing no ar)
		s.BroadcastCombatEvent(player.ID, 0, pkt.ActionType, 0, 0, 0, 0)
	}

	// Sincroniza estamina atualizada com o jogador atacante
	s.sendPlayerStats(player)
}

// handleMobAttack aplica dano de um monstro a um jogador autoritativamente respeitando I-Frames.
func (s *Server) handleMobAttack(mobID, playerID uint32, damage uint16) {
	s.mu.RLock()
	player, exists := s.players[playerID]
	s.mu.RUnlock()

	if !exists || player.IsInAutopsy() {
		return
	}

	newHP, isDead := player.TakeDamage(damage)
	s.BroadcastCombatEvent(mobID, playerID, protocol.ActionBasicAttack, damage, 0, newHP, player.MaxHP)
	s.sendPlayerStats(player)

	// Passivas de reflexo: Guardião do Bastião (Fortaleza Viva, 20%) e Carrasco Vorpal (Sangue Corrosivo, 15%)
	if (player.ClassID == protocol.ClassShieldBearer || player.ClassID == protocol.ClassVorpalExecutioner) && damage > 0 && s.mobManager != nil {
		if mob := s.mobManager.GetMob(mobID); mob != nil && mob.IsAlive {
			reflected := damage / 5
			if player.ClassID == protocol.ClassVorpalExecutioner {
				reflected = damage * 15 / 100
			}
			if reflected == 0 {
				reflected = 1
			}
			_, _, mobHP, mobDead := mob.TakeDamage(reflected, playerID)
			if mobDead {
				s.handleMobDeath(mob, playerID)
			} else {
				s.BroadcastCombatEvent(playerID, mob.ID, protocol.ActionBasicAttack, reflected, 0, mobHP, mob.MaxHP)
			}
		}
	}

	if isDead {
		log.Printf("[MORTALIDADE] Jogador #%d foi derrotado pelo Mob #%d e renascera no Centro!\n", playerID, mobID)
		s.RespawnPlayer(player)
	}

	// Alerta os Guardas da Patrulha Real se o mob atacou próximo a eles
	s.checkGuardsReactToMob(mobID)
}

// handleMobAOEDamage aplica o impacto de dano do golpe telegrafado nos jogadores dentro do raio.
func (s *Server) handleMobAOEDamage(sourceID uint32, x, z, radius float32, damage uint16) {
	s.mu.RLock()
	var victims []*world.Player
	for _, p := range s.players {
		if p.IsInAutopsy() {
			continue
		}
		p.Mu.RLock()
		px, pz := p.PosX, p.PosZ
		p.Mu.RUnlock()

		dx := px - x
		dz := pz - z
		dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
		if dist <= radius {
			victims = append(victims, p)
		}
	}
	s.mu.RUnlock()

	for _, p := range victims {
		newHP, isDead := p.TakeDamage(damage)
		s.BroadcastCombatEvent(sourceID, p.ID, protocol.ActionSpecialSkill, damage, 1, newHP, p.MaxHP)
		s.sendPlayerStats(p)

		if isDead {
			log.Printf("[MORTALIDADE] Jogador #%d foi esmagado pelo ataque em área do Executor #%d e renascera no Centro!\n", p.ID, sourceID)
			s.RespawnPlayer(p)
		}
	}

	// Alerta os Guardas da Patrulha Real caso o mob use AOE próximo a eles
	s.checkGuardsReactToMob(sourceID)
}

// handleNPCAttackMob comanda o ataque físico de um NPC contra um monstro defendendo a vila.
func (s *Server) handleNPCAttackMob(npcID, mobID uint32, damage uint16) {
	if s.mobManager == nil {
		return
	}
	mob := s.mobManager.GetMob(mobID)
	if mob == nil {
		return
	}

	s.mu.RLock()
	npc, exists := s.npcs[npcID]
	s.mu.RUnlock()
	if !exists {
		return
	}

	finalDamage, wasBlocked, newHP, isDead := mob.TakeDamage(damage)
	s.BroadcastCombatEvent(npcID, mobID, protocol.ActionBasicAttack, finalDamage, 1, newHP, mob.MaxHP)

	log.Printf("[COMBATE] NPC '%s' (#%d) atacou o Mob #%d (%s) causando %d dano (Bloqueado: %v) | HP: %d/%d\n",
		npc.Name, npcID, mobID, mob.Name, finalDamage, wasBlocked, newHP, mob.MaxHP)

	if isDead {
		log.Printf("[COMBATE] NPC '%s' (#%d) eliminou o Mob #%d (%s) defendendo o perímetro!\n", npc.Name, npcID, mobID, mob.Name)
		s.handleMobDeath(mob, 0)
	}
}

// checkGuardsReactToMob alerta os guardas próximos quando um mob desfere um ataque.
func (s *Server) checkGuardsReactToMob(mobID uint32) {
	if s.mobManager == nil {
		return
	}
	mob := s.mobManager.GetMob(mobID)
	if mob == nil {
		return
	}

	mob.Mu.RLock()
	mx, mz := mob.PosX, mob.PosZ
	mType := mob.MobType
	isAlive := mob.IsAlive && mob.IsActive
	mob.Mu.RUnlock()

	if !isAlive {
		return
	}

	s.mu.RLock()
	guards := []*world.NPC{s.npcs[105], s.npcs[106]}
	s.mu.RUnlock()

	for _, g := range guards {
		if g == nil {
			continue
		}
		gx, _, gz := g.GetPos()
		dx := mx - gx
		dz := mz - gz
		dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
		if dist <= 12.0 {
			_ = luaengine.CallOnMobAttackNearby(g, mobID, mType, dist)
		}
	}
}

// handleMobTelegraph transmite o pacote 0x34 AOE_TELEGRAPH para todos os clientes.
func (s *Server) handleMobTelegraph(sourceID uint32, x, z, radius float32, durationMs uint16) {
	s.BroadcastAOETelegraph(sourceID, x, z, radius, durationMs)
}

// handleMobSay transmite a fala de um mob ou acólito.
func (s *Server) handleMobSay(mobID uint32, text string) {
	s.BroadcastNPCSay(mobID, text)
}

// RespawnPlayer redefine os atributos do jogador para o máximo e o teletransporta para o Centro do Mapa (0.0, 1.5, 0.0).
func (s *Server) RespawnPlayer(player *world.Player) {
	worldHour := s.clock.GetCurrentHour()
	isNight := (worldHour >= 18 || worldHour < 6)

	// Gatilho Secreto da Raça Cinerion (RaceID = 7 - Cinerion):
	// Morte à noite com Cálice da Alma Partida (Item 14) no inventário
	if isNight && player.HasItem(protocol.ItemBrokenSoulChalice) && player.RaceID != protocol.RaceRevenant {
		player.RemoveItem(protocol.ItemBrokenSoulChalice, 1)
		player.EvolveToRevenant()
		s.sendInventorySync(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[RITUAL SOMBRIO] As trevas da noite consomem a alma do Jogador #%d... Ao segurar o Cálice da Alma Partida, ele renasce como AMALDIÇOADO DAS CINZAS (Cinerion)! (+50 MaxHP, +25%% Dano Noturno)", player.ID))
		log.Printf("[SEGREDO] Jogador #%d despertou como Raça Secreta 7 (Cinerion) ao morrer à noite com o Cálice da Alma Partida!\n", player.ID)
	}

	player.Respawn(0.0, 1.5, 0.0)
	s.BroadcastPlayerRespawn(player.ID, 0.0, 1.5, 0.0)
	s.sendPlayerStats(player)
	log.Printf("[RESPAWN] Jogador #%d renasceu no Centro do Mapa (0.0, 1.5, 0.0) com vida cheia e 2s de I-Frame!\n", player.ID)
}

// BroadcastPlayerRespawn transmite o pacote 0x36 (PLAYER_RESPAWN: 17 bytes) para todos os clientes via TCP e UDP.
func (s *Server) BroadcastPlayerRespawn(playerID uint32, posX, posY, posZ float32) {
	pkt := protocol.SerializePlayerRespawn(playerID, posX, posY, posZ)

	s.mu.RLock()
	targetAddrs := make([]*net.UDPAddr, 0, len(s.players))
	targetConns := make([]net.Conn, 0, len(s.players))
	for _, p := range s.players {
		if addr := p.GetUDPAddr(); addr != nil {
			targetAddrs = append(targetAddrs, addr)
		}
		if p.TCPConn != nil {
			targetConns = append(targetConns, p.TCPConn)
		}
	}
	s.mu.RUnlock()

	for _, addr := range targetAddrs {
		_, _ = s.udpConn.WriteToUDP(pkt[:], addr)
	}
	for _, conn := range targetConns {
		_ = conn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
		_, _ = conn.Write(pkt[:])
		_ = conn.SetWriteDeadline(time.Time{})
	}
}

// BroadcastAOETelegraph transmite o pacote UDP 0x34 para clientes na mesma zona da fonte.
func (s *Server) BroadcastAOETelegraph(sourceID uint32, posX, posZ, radius float32, durationMs uint16) {
	pkt := protocol.SerializeAOETelegraph(sourceID, posX, posZ, radius, durationMs)

	s.mu.RLock()
	var sourceZone uint8
	foundZone := false
	if p, ok := s.players[sourceID]; ok {
		sourceZone = p.GetZone()
		foundZone = true
	} else if s.mobManager != nil {
		if m := s.mobManager.GetMob(sourceID); m != nil {
			sourceZone = m.GetZone()
			foundZone = true
		}
	}

	targetAddrs := make([]*net.UDPAddr, 0, len(s.players))
	for _, p := range s.players {
		if foundZone && p.GetZone() != sourceZone {
			continue
		}
		if addr := p.GetUDPAddr(); addr != nil {
			targetAddrs = append(targetAddrs, addr)
		}
	}
	s.mu.RUnlock()

	for _, addr := range targetAddrs {
		_, _ = s.udpConn.WriteToUDP(pkt[:], addr)
	}
}

// getMobKillXP retorna a quantidade de XP concedida pela eliminação de cada tipo de criatura.
func getMobKillXP(mobType uint8) uint16 {
	switch mobType {
	case protocol.MobTypeMistWolf: // 1: Lobo da Bruma (35 XP)
		return 35
	case protocol.MobTypeWildBoar: // 25: Javali Selvagem (20 XP)
		return 20
	case protocol.MobTypeOutcastRaider: // 2: Saqueador Deserdado (45 XP)
		return 45
	case protocol.MobTypeVigilCrossbowman: // 3: Besteiro da Vigília (40 XP)
		return 40
	case protocol.MobTypeEclipseAcolyte: // 4: Acólito do Eclipse (50 XP)
		return 50
	case protocol.MobTypeIronEnforcer: // 5: Executor de Ferro (90 XP)
		return 90
	case protocol.MobTypeAlphaWolf: // 6: Lobo Alfa (160 XP)
		return 160
	case protocol.MobTypeLycanthropeAlpha: // 7: Licantropo Alfa (500 XP)
		return 500
	case protocol.MobTypeDarkCultist: // 10: Cultista Sombrio (80 XP)
		return 80
	case protocol.MobTypeStoneGargoyle: // 11: Gárgula de Pedra (110 XP)
		return 110
	case protocol.MobTypeInquisitorVex: // 12: Inquisidor Vex (300 XP)
		return 300
	case protocol.MobTypeCommanderVaelen: // 13: Comandante Vaelen (650 XP)
		return 650
	case protocol.MobTypeMalakorHeraldEclipse: // 14: Malakor, o Arauto do Eclipse (1500 XP)
		return 1500
	case protocol.MobTypeMistWeaverSpider: // 15: Aranha Tecelã da Bruma (75 XP)
		return 75
	case protocol.MobTypeArachnaQueen: // 16: Arachna, a Rainha Tecelã (1400 XP)
		return 1400
	case protocol.MobTypeAcidCorrosiveSlime: // 17: Lodo Ácido Corrosivo (65 XP)
		return 65
	case protocol.MobTypeAbyssalScorpion: // 18: Escorpião Abissal Gigante (110 XP)
		return 110
	case protocol.MobTypeStitchedChimeraZero: // 19: Experimento Nº 0: A Quimera Costurada (600 XP)
		return 600
	case protocol.MobTypeAncientIceGolem: // 20: Golem de Gelo Antigo (140 XP)
		return 140
	case protocol.MobTypeWildFrostDrake: // 21: Draco de Geada Selvagem (220 XP)
		return 220
	case protocol.MobTypeYmirFrostPatriarch: // 22: Ymir, o Patriarca Jotunar (1200 XP)
		return 1200
	case protocol.MobTypeVesperianBloodGuard: // 23: Guarda Sanguinário de Vesperian (130 XP)
		return 130
	case protocol.MobTypeLordVesperianVampire: // 24: Lorde Vesperian, o Progenitor Vampiro (1800 XP)
		return 1800
	default:
		return 35
	}
}

// handleMobDeath distribui XP a todos os jogadores participantes ou próximos e valida a evolução secreta Varkai.
func (s *Server) handleMobDeath(mob *world.Mob, killerPlayerID uint32) {
	mob.Mu.RLock()
	mobID := mob.ID
	mobName := mob.Name
	mobType := mob.MobType
	mx, mz := mob.PosX, mob.PosZ
	mob.Mu.RUnlock()

	log.Printf("[COMBATE] Mob #%d (%s) foi derrotado!\n", mobID, mobName)

	xp := getMobKillXP(mobType)
	dealers := mob.GetDamageDealers()

	// Provações de Linhagem baseadas em abates
	s.mu.RLock()
	trialKiller := s.players[killerPlayerID]
	s.mu.RUnlock()
	if trialKiller != nil {
		s.checkRaceTrialsOnKill(trialKiller, mobType)
	}

	s.mu.RLock()
	var eligible []*world.Player
	for pid, p := range s.players {
		if dealers[pid] > 0 || (killerPlayerID > 0 && pid == killerPlayerID) {
			eligible = append(eligible, p)
			continue
		}
		p.Mu.RLock()
		px, pz := p.PosX, p.PosZ
		p.Mu.RUnlock()
		dist := float32(math.Sqrt(float64((px-mx)*(px-mx) + (pz-mz)*(pz-mz))))
		if dist <= 25.0 {
			eligible = append(eligible, p)
		}
	}
	s.mu.RUnlock()

	if trialKiller != nil {
		s.grantKillGold(trialKiller, mobType) // Sollares do abate vão para quem deu o golpe final
	}

	for _, p := range eligible {
		leveledUp := p.AddXP(xp)
		s.sendPlayerStats(p)
		if leveledUp {
			log.Printf("[PROGRESSÃO] Jogador #%d subiu para Nível %d! XP: %d/%d, StatPoints: %d\n",
				p.ID, p.Level, p.XP, p.NextLevelXP, p.StatPoints)
			s.checkProgressionMilestones(p)
		}
	}

	// Evolução Solo Varkai: derrota solitária do Licantropo Alfa (MobType 7)
	if mobType == protocol.MobTypeLycanthropeAlpha {
		if len(dealers) == 1 {
			var soloPID uint32
			for pid := range dealers {
				soloPID = pid
			}
			s.mu.RLock()
			soloPlayer := s.players[soloPID]
			s.mu.RUnlock()

			if soloPlayer != nil {
				soloPlayer.Mu.RLock()
				pRace := soloPlayer.RaceID
				soloPlayer.Mu.RUnlock()

				if pRace == protocol.RaceVarkai {
					soloPlayer.EvolveToPrimordialLycanthrope()
					s.sendPlayerStats(soloPlayer)
					s.BroadcastNPCSay(208, fmt.Sprintf("[LUA DE SANGUE] O guerreiro Varkai #%d bebeu o sangue do Licantropo Alfa em duelo solitário! Ele despertou como o lendário LICANTROPO PRIMORDIAL!", soloPID))
					log.Printf("[EVOLUÇÃO] Jogador #%d completou a Evolução Solo Varkai para Lupharion (RaceID = 6)!\n", soloPID)
				}
			}
		}
	}

	// Extração Anatômica Realista de Drops para o Jogador que abateu
	var killer *world.Player
	s.mu.RLock()
	if killerPlayerID > 0 {
		killer = s.players[killerPlayerID]
	}
	if killer == nil && len(eligible) > 0 {
		killer = eligible[0]
	}
	s.mu.RUnlock()

	if killer != nil {
		// Rastreio dos Desafios Secretos e Passivas no Abate
		killer.Mu.Lock()
		killer.UntouchedKills++
		if killer.HP <= uint16(float32(killer.MaxHP)*0.30) {
			killer.LowHPKills++
		}
		isBoneNecro := (killer.ClassID == protocol.ClassBoneNecromancer)
		killer.Mu.Unlock()

		if isBoneNecro {
			killer.Heal(20)
			s.sendPlayerStats(killer)
			log.Printf("[NECROMANTE DE OSSOS] Jogador #%d curou +20 HP pelo abate do Mob #%d!\n", killer.ID, mobID)
		}

		// Desafio Secreto: Senhor da Selva Primordial (Classe 13)
		// Derrotar o Lobo Alfa (MobType 6) 100% Solo na Lua Cheia sem peitoral equipado
		if mobType == protocol.MobTypeAlphaWolf && len(dealers) == 1 {
			_, _, moon, _ := s.clock.GetTime()
			if moon == world.MoonPhaseFull {
				killer.Mu.Lock()
				killer.SoloAlphaWolfKilled = true
				hasChest := (killer.EquippedSlots[protocol.SlotChest] > 0 || killer.EquippedArmorID > 0)
				killer.Mu.Unlock()

				if !hasChest && killer.ClassID != protocol.ClassPrimordialTamer {
					s.offerIdentityChange(killer, killer.RaceID, protocol.ClassPrimordialTamer, protocol.IdentityModeSecretReset)
					s.BroadcastNPCSay(109, fmt.Sprintf("[DOMADOR PRIMORDIAL] O guerreiro #%d subjugou o Lobo Alfa com o peito nu sob a Lua Cheia! O Espírito Alfa despertou!", killer.ID))
					log.Printf("[CLASSE SECRETA] Jogador #%d despertou Senhor da Selva Primordial (13) derrotando Lobo Alfa Solo sem peitoral sob Lua Cheia!\n", killer.ID)
				}
			}
		}

		// Validação da Provação Lendária (Classes Únicas Nível 45+)
		killer.Mu.RLock()
		isQuestActive := killer.LegendaryQuestActive
		killer.Mu.RUnlock()
		if isQuestActive && (mobType == protocol.MobTypeAlphaWolf || mobType == protocol.MobTypeLycanthropeAlpha || mobType == protocol.MobTypeIronEnforcer || mobType == protocol.MobTypeInquisitorVex || mobType == protocol.MobTypeCommanderVaelen || mobType == protocol.MobTypeMalakorHeraldEclipse) {
			killer.Mu.Lock()
			killer.LegendaryQuestKills++
			kills := killer.LegendaryQuestKills
			killer.Mu.Unlock()
			log.Printf("[PROVAÇÃO LENDÁRIA] Jogador #%d abateu mob de Elite/Boss (%d)! Progresso: %d/3\n", killer.ID, mobType, kills)
			if kills >= 3 {
				s.checkProgressionMilestones(killer)
			}
		}

		_, _, _, _, _, _, mas, lck := killer.GetAttributes()
		luckBonus := float64(lck-5)*0.015 + float64(mas-5)*0.010
		if luckBonus < 0 {
			luckBonus = 0
		}
		// Chance de 0.1% (0.001) para itens de Raças e Classes Secretas escalada apenas por LCK
		secretDropChance := 0.001 * (1.0 + float64(lck)*0.05)

		// 1. Persistência de Cadáveres no Chão (90 segundos de vida útil antes de decompor)
		if s.corpseManager != nil {
			corpse := s.corpseManager.CreateCorpseFromMob(mob, killer.ID, luckBonus)
			log.Printf("[CORPSE] Criado cadáver #%d para Mob #%d (%s) nas coordenadas (%.1f, %.1f, %.1f) com %d órgãos para autópsia (90s)\n",
				corpse.CorpseID, mobID, mobName, corpse.PosX, corpse.PosY, corpse.PosZ, len(corpse.Organs))
			s.broadcastCorpseSnapshots()
		}

		var drops []string
		var flaskMsg string

		switch mobType {
		case protocol.MobTypeWildBoar: // 25: Javali Selvagem
			killer.AddItem(protocol.ItemRawWolfMeat, 1)
			drops = append(drops, "Carne Crua x1")

		case protocol.MobTypeMistWolf: // 1: Lobo da Bruma
			killer.AddItem(protocol.ItemRawWolfMeat, 1)
			killer.AddItem(protocol.ItemWolfGreyPelt, 1)
			drops = append(drops, "Carne Crua de Lobo x1", "Couro de Lobo x1")

			if rand.Float64() < 0.25+luckBonus {
				killer.AddItem(protocol.ItemSharpWolfFang, 1)
				drops = append(drops, "Presas e Garras Afiadas x1")
			}
			if rand.Float64() < 0.20+luckBonus {
				killer.AddItem(protocol.ItemBeastClaw, 1)
				drops = append(drops, "Presas e Garras Afiadas x1 (garra)")
			}
			if rand.Float64() < 0.03+luckBonus { // 3% Raro
				killer.AddItem(protocol.ItemAncestralFangRing, 1)
				drops = append(drops, "Anel de Presa Ancestral [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemSilverSilkCocoon, 1)
				drops = append(drops, "Casulo de Seda Prateada [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeOutcastRaider, protocol.MobTypeVigilCrossbowman: // 2, 3: Saqueador / Besteiro
			killer.AddItem(protocol.ItemEmptyFlask, 1)
			killer.AddItem(protocol.ItemCookedNobleMeat, 1)
			drops = append(drops, "Frasco de Vidro Vazio x1", "Carne Nobre Assada x1")

			if rand.Float64() < 0.35+luckBonus { // 35% Minério de Ferro (Presente compatível para Garrick)
				killer.AddItem(protocol.ItemIronOre, 1)
				drops = append(drops, "Ferro x1")
			}

			if rand.Float64() < 0.04+luckBonus { // 4% Raro (reduzido para evitar excessos)
				killer.AddItem(protocol.ItemAncestralFangRing, 1)
				drops = append(drops, "Anel de Presa Ancestral [RARO] x1")
			}

		case protocol.MobTypeEclipseAcolyte: // 4: Acólito do Eclipse
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemBrokenSoulChalice, 1)
				drops = append(drops, "Cálice da Alma Partida [SECRETO 0.1%] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemEclipseScytheTome, 1)
				drops = append(drops, "Tomo da Foice do Eclipse [SECRETO 0.1%] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemSilverSilkCocoon, 1)
				drops = append(drops, "Casulo de Seda Prateada [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeIronEnforcer: // 5: Executor de Ferro
			killer.AddItem(protocol.ItemHeavySteelPlate, 1)
			killer.AddItem(protocol.ItemEmptyFlask, 1)
			killer.AddItem(protocol.ItemIronOre, 2)
			drops = append(drops, "Placa de Aço Pesada x1", "Frasco de Vidro Vazio x1", "Ferro x2")
			if rand.Float64() < 0.04+luckBonus { // 4% Raro
				killer.AddItem(protocol.ItemTitansHammerTome, 1)
				drops = append(drops, "Tomo do Martelo Titânico [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemStarforgeCore, 1)
				drops = append(drops, "Núcleo de Forja Estelar [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeAlphaWolf: // 6: Lobo Alfa
			killer.AddItem(protocol.ItemAlphaWolfPelt, 1)
			drops = append(drops, "Pele Intacta de Lobo Alfa x1")
			if rand.Float64() < 0.06+luckBonus { // 6% Raro
				killer.AddItem(protocol.ItemAncestralFangRing, 1)
				drops = append(drops, "Anel de Presa Ancestral [RARO] x1")
			}

		case protocol.MobTypeLycanthropeAlpha: // 7: Licantropo Alfa
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemLycanAlphaHeart, 1)
				drops = append(drops, "Coração do Licantropo Alfa [SECRETO 0.1%] x1")
			}
			if rand.Float64() < 0.07+luckBonus { // 7% Raro
				killer.AddItem(protocol.ItemTitansHammerTome, 1)
				drops = append(drops, "Tomo do Martelo Titânico [RARO] x1")
			}

		case protocol.MobTypeDarkCultist: // 10: Cultista Sombrio
			killer.AddItem(protocol.ItemEmptyFlask, 1)
			drops = append(drops, "Frasco de Vidro Vazio x1")
			if rand.Float64() < 0.05+luckBonus { // 5% Raro
				killer.AddItem(protocol.ItemShadowCultistRobe, 1)
				drops = append(drops, "Manto do Cultista Sombrio [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemEclipseScytheTome, 1)
				drops = append(drops, "Tomo da Foice do Eclipse [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeStoneGargoyle: // 11: Gárgula de Pedra
			killer.AddItem(protocol.ItemHeavySteelPlate, 1)
			drops = append(drops, "Placa de Aço Pesada x1")
			if rand.Float64() < 0.06+luckBonus { // 6% Raro
				killer.AddItem(protocol.ItemGargoyleStoneHeart, 1)
				drops = append(drops, "Coração Pétreo da Gárgula [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemRunicHourglass, 1)
				drops = append(drops, "Ampulheta Rúnica [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeInquisitorVex: // 12: Inquisidor Vex
			if rand.Float64() < 0.06+luckBonus { // 6% Raro
				killer.AddItem(protocol.ItemInquisitorShadowScythe, 1)
				drops = append(drops, "Foice Sombria do Inquisidor [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemBrokenSoulChalice, 1)
				drops = append(drops, "Cálice da Alma Partida [SECRETO 0.1%] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemRunicHourglass, 1)
				drops = append(drops, "Ampulheta Rúnica [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeCommanderVaelen: // 13: Comandante Vaelen
			killer.AddItem(protocol.ItemHeavySteelPlate, 1)
			drops = append(drops, "Placa de Aço Pesada x1")
			if rand.Float64() < 0.05+luckBonus { // 5% Raro
				killer.AddItem(protocol.ItemTraitorCommanderInsignia, 1)
				drops = append(drops, "Insígnia do Traidor Vaelen [RARO] x1")
			}
			if rand.Float64() < 0.04+luckBonus { // 4% Raro
				killer.AddItem(protocol.ItemTitansHammerTome, 1)
				drops = append(drops, "Tomo do Martelo Titânico [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemEclipseScytheTome, 1)
				drops = append(drops, "Tomo da Foice do Eclipse [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeMalakorHeraldEclipse: // 14: Malakor, o Arauto do Eclipse
			killer.AddItem(protocol.ItemSacredTorch, 1)
			drops = append(drops, "Tocha Sagrada do Santuário x1")
			if rand.Float64() < 0.08+luckBonus { // 8% Raro
				killer.AddItem(protocol.ItemHeraldEclipseEye, 1)
				drops = append(drops, "Olho do Arauto do Eclipse [RARO] x1")
			}
			if rand.Float64() < 0.06+luckBonus { // 6% Raro
				killer.AddItem(protocol.ItemInquisitorShadowScythe, 1)
				drops = append(drops, "Foice Sombria do Inquisidor [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemLycanAlphaHeart, 1)
				drops = append(drops, "Coração do Licantropo Alfa [SECRETO 0.1%] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemStarforgeCore, 1)
				drops = append(drops, "Núcleo de Forja Estelar [SECRETO 0.1%] x1")
			}

		case protocol.MobTypeMistWeaverSpider: // 15: Aranha Tecelã da Bruma
			killer.AddItem(protocol.ItemPerfectSilkCocoon, 1)
			drops = append(drops, "Teias de Aranha x1")
			if rand.Float64() < 0.25+luckBonus {
				killer.AddItem(protocol.ItemDarkPoisonGland, 1)
				drops = append(drops, "Glândula de Veneno x1")
			}

		case protocol.MobTypeArachnaQueen: // 16: Arachna, a Rainha Tecelã (Raid Boss)
			killer.AddItem(protocol.ItemSpiderQueenHeart, 1)
			killer.AddItem(protocol.ItemImperialSilkCloak, 1)
			drops = append(drops, "Coração da Rainha Aranha x1", "Manto de Seda Imperial x1")
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemArachnaEye, 1)
				drops = append(drops, "Olho Multifacetado de Arachna [SECRETO 0.1% - Desbloqueia Raça Aracne!] x1")
			}

		case protocol.MobTypeAcidCorrosiveSlime: // 17: Lodo Ácido Corrosivo
			killer.AddItem(protocol.ItemPureAcid, 1)
			killer.AddItem(protocol.ItemOrganicTrash, 1)
			drops = append(drops, "Seiva Ácida x1", "Lixo Orgânico x1")

		case protocol.MobTypeAbyssalScorpion: // 18: Escorpião Abissal Gigante
			killer.AddItem(protocol.ItemVorpalPoison, 1)
			drops = append(drops, "Bolsa de Veneno Vorpal x1")
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemAbyssalScorpionStinger, 1)
				drops = append(drops, "Ferrão de Escorpião Abissal [SECRETO 0.1% - Desbloqueia Raça Escarion!] x1")
			}
			if rand.Float64() < 0.02 { // 2%: requisito do Algoz Vorpal (Classe Única 19)
				killer.AddItem(protocol.ItemRoyalVenomGland, 1)
				drops = append(drops, "Glândula Real do Escorpião [RARO 2% - Classe Única Algoz Vorpal] x1")
			}

		case protocol.MobTypeStitchedChimeraZero: // 19: Experimento Nº 0: A Quimera Costurada (Mini-Boss)
			killer.AddItem(protocol.ItemChimeraFleshPart, 1)
			killer.AddItem(protocol.ItemDarkPoisonGland, 1)
			killer.AddItem(protocol.ItemHeavySteelPlate, 1)
			drops = append(drops, "Retalho Quimérico Costurado x1", "Glândula de Veneno Mutante x1", "Placa de Aço Deformada x1")

		case protocol.MobTypeAncientIceGolem: // 20: Golem de Gelo Antigo
			killer.AddItem(protocol.ItemAncientIceCore, 1)
			killer.AddItem(protocol.ItemHeavySteelPlate, 1)
			drops = append(drops, "Núcleo de Gelo Antigo x1", "Placa de Aço Pesada x1")

		case protocol.MobTypeWildFrostDrake: // 21: Draco de Geada Selvagem
			killer.AddItem(protocol.ItemPrimordialDragonScale, 1)
			killer.AddItem(protocol.ItemCookedNobleMeat, 1)
			drops = append(drops, "Escama Dracônica Primordial x1", "Carne Nobre Assada x1")

		case protocol.MobTypeYmirFrostPatriarch: // 22: Ymir, o Patriarca Jotunar (Boss)
			killer.AddItem(protocol.ItemAncientIceCore, 2)
			killer.AddItem(protocol.ItemHeavySteelPlate, 2)
			drops = append(drops, "Núcleo de Gelo Ancestral x2", "Placa Glacial Reforçada x2")
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemEternalFrostHeart, 1)
				drops = append(drops, "Coração de Geada Eterna [SECRETO 0.1% - Desbloqueia Jotunar!] x1")
			}

		case protocol.MobTypeVesperianBloodGuard: // 23: Guarda Sanguinário de Vesperian
			killer.AddItem(protocol.ItemCrimsonGuardInsignia, 1)
			drops = append(drops, "Insígnia do Guarda Carmesim x1")

		case protocol.MobTypeLordVesperianVampire: // 24: Lorde Vesperian, o Progenitor Vampiro (Raid Boss Secreto)
			killer.AddItem(protocol.ItemVesperianCrimsonRing, 1)
			killer.AddItem(protocol.ItemEclipseScytheTome, 1)
			drops = append(drops, "Anel Carmesim de Vesperian x1", "Tomo da Foice do Eclipse x1")
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemProgenitorPureBlood, 1)
				drops = append(drops, "Sangue Puro do Progenitor [SECRETO 0.1% - Desbloqueia Raça Sangrael!] x1")
			}
			if rand.Float64() < 0.25 { // 25%: requisito do Conde Escarlate (Classe Única 25)
				killer.AddItem(protocol.ItemVesperianPureBlood, 1)
				drops = append(drops, "Sangue Puro de Vesperian [RARO 25% - Classe Única Conde Escarlate] x1")
			}
		}

		s.sendInventorySync(killer)

		if len(drops) > 0 || flaskMsg != "" {
			lootLog := fmt.Sprintf("[Loot] Extraído de %s: %s.%s", mobName, strings.Join(drops, ", "), flaskMsg)
			s.BroadcastNPCSay(0, lootLog)
			log.Printf("[LOOT] %s -> Jogador #%d\n", lootLog, killer.ID)
		}
	}
}

// handleDevGetDropRates processa a solicitação 0x3A DEV_GET_DROP_RATES enviando o relatório completo.
func (s *Server) handleDevGetDropRates(playerID uint32) {
	report := s.generateDropRatesReport()

	// Envia pacote de resposta TCP 0x3A para o cliente
	respBytes := protocol.SerializeDevGetDropRatesResponse(report)
	s.mu.RLock()
	p, ok := s.players[playerID]
	s.mu.RUnlock()

	if ok && p != nil {
		p.Mu.RLock()
		tcpConn := p.TCPConn
		p.Mu.RUnlock()
		if tcpConn != nil {
			_, _ = tcpConn.Write(respBytes)
		}
	}

	// Registra no console e difunde notificação
	log.Printf("[DEV_GET_DROP_RATES] Relatório gerado para Jogador #%d:\n%s\n", playerID, report)
	s.BroadcastNPCSay(0, fmt.Sprintf("[DEV LOG] Taxas de Drop geradas com sucesso (Jogador #%d)!", playerID))
}

// generateDropRatesReport formata a tabela completa de itens e suas probabilidades atuais de drop.
func (s *Server) generateDropRatesReport() string {
	var sb strings.Builder
	sb.WriteString("==================================================\n")
	sb.WriteString("    LUNARIA ONLINE — TABELA DE TAXAS DE DROP (DEV)\n")
	sb.WriteString("==================================================\n")
	sb.WriteString("[Mob 1] Lobo da Bruma:\n")
	sb.WriteString("  - Item #1 (Carne Crua de Lobo): 100.0%\n")
	sb.WriteString("  - Item #129 (Couro de Lobo): 100.0%\n")
	sb.WriteString("  - Item #3 (Presa Lupina Afiada): 25.0%\n")
	sb.WriteString("  - Item #142 (Presas e Garras Afiadas): 20.0%\n")
	sb.WriteString("  - Item #9 (Anel de Presa Ancestral): 3.0% [RARO]\n")
	sb.WriteString("  - Item #30 (Casulo de Seda Prateada): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 2] Saqueador Deserdado:\n")
	sb.WriteString("  - Item #5 (Frasco de Vidro Vazio): 80.0%\n")
	sb.WriteString("  - Item #10 (Carne Nobre Assada): 70.0%\n")
	sb.WriteString("  - Item #9 (Anel de Presa Ancestral): 4.0% [RARO]\n")
	sb.WriteString("[Mob 3] Besteiro da Vigília:\n")
	sb.WriteString("  - Item #5 (Frasco de Vidro Vazio): 80.0%\n")
	sb.WriteString("  - Item #10 (Carne Nobre Assada): 70.0%\n")
	sb.WriteString("  - Item #9 (Anel de Presa Ancestral): 5.0% [RARO]\n")
	sb.WriteString("[Mob 4] Acólito do Eclipse:\n")
	sb.WriteString("  - Item #14 (Cálice da Alma Partida): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("  - Item #17 (Tomo da Foice do Eclipse): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("  - Item #30 (Casulo de Seda Prateada): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 5] Executor de Ferro:\n")
	sb.WriteString("  - Item #11 (Placa de Aço Pesada): 60.0%\n")
	sb.WriteString("  - Item #5 (Frasco de Vidro Vazio): 80.0%\n")
	sb.WriteString("  - Item #18 (Tomo do Martelo Titânico): 4.0% [RARO]\n")
	sb.WriteString("  - Item #18 (Núcleo de Forja Estelar): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 6] Lobo Alfa:\n")
	sb.WriteString("  - Item #12 (Pele Intacta de Lobo Alfa): 100.0%\n")
	sb.WriteString("  - Item #9 (Anel de Presa Ancestral): 6.0% [RARO]\n")
	sb.WriteString("[Mob 7] Licantropo Alfa:\n")
	sb.WriteString("  - Item #15 (Coração do Licantropo Alfa): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("  - Item #16 (Sangue do Progenitor Bestial): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("  - Item #18 (Tomo do Martelo Titânico): 7.0% [RARO]\n")
	sb.WriteString("[Mob 10] Cultista Sombrio:\n")
	sb.WriteString("  - Item #5 (Frasco de Vidro Vazio): 60.0%\n")
	sb.WriteString("  - Item #19 (Manto do Cultista Sombrio): 5.0% [RARO]\n")
	sb.WriteString("  - Item #17 (Tomo da Foice do Eclipse): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 11] Gárgula de Pedra:\n")
	sb.WriteString("  - Item #11 (Placa de Aço Pesada): 70.0%\n")
	sb.WriteString("  - Item #20 (Coração Pétreo da Gárgula): 6.0% [RARO]\n")
	sb.WriteString("  - Item #29 (Ampulheta Rúnica): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 12] Inquisidor Vex (Mini-Boss):\n")
	sb.WriteString("  - Item #21 (Foice Sombria do Inquisidor): 6.0% [RARO]\n")
	sb.WriteString("  - Item #14 (Cálice da Alma Partida): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("  - Item #29 (Ampulheta Rúnica): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 13] Comandante Vaelen (Boss Normal):\n")
	sb.WriteString("  - Item #22 (Insígnia do Traidor Vaelen): 5.0% [RARO]\n")
	sb.WriteString("  - Item #18 (Tomo do Martelo Titânico): 4.0% [RARO]\n")
	sb.WriteString("  - Item #17 (Tomo da Foice do Eclipse): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 14] Malakor, o Arauto do Eclipse (Raid Boss):\n")
	sb.WriteString("  - Item #23 (Olho do Arauto do Eclipse): 8.0% [RARO]\n")
	sb.WriteString("  - Item #24 (Tocha Sagrada do Santuário): 100.0%\n")
	sb.WriteString("  - Item #21 (Foice Sombria do Inquisidor): 6.0% [RARO]\n")
	sb.WriteString("  - Item #15 (Coração do Licantropo Alfa): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("  - Item #18 (Núcleo de Forja Estelar): 0.1% [SECRETO 1/1000]\n")
	sb.WriteString("[Mob 15] Aranha Tecelã da Bruma:\n")
	sb.WriteString("  - Item #132 (Teias de Aranha): 100.0%\n")
	sb.WriteString("  - Item #11 (Glândula de Veneno): 25.0%\n")
	sb.WriteString("[Mob 16] Arachna, a Rainha Tecelã (Raid Boss):\n")
	sb.WriteString("  - Item #43 (Coração da Rainha Aranha): 100.0%\n")
	sb.WriteString("  - Item #45 (Manto de Seda Imperial): 100.0%\n")
	sb.WriteString("  - Item #44 (Olho Multifacetado de Arachna): 0.1% [SECRETO 1/1000 - Desbloqueia Raça Aracne!]\n")
	sb.WriteString("[Mob 17] Lodo Ácido Corrosivo:\n")
	sb.WriteString("  - Item #153 (Seiva Ácida): 100.0%\n")
	sb.WriteString("  - Item #28 (Lixo Orgânico): 100.0%\n")
	sb.WriteString("[Mob 18] Escorpião Abissal Gigante:\n")
	sb.WriteString("  - Item #48 (Veneno Vorpal): 100.0%\n")
	sb.WriteString("  - Item #47 (Ferrão de Escorpião Abissal): 0.1% [SECRETO 1/1000 - Desbloqueia Raça Escarion!]\n")
	sb.WriteString("[Mob 19] Experimento Nº 0: A Quimera Costurada (Mini-Boss):\n")
	sb.WriteString("  - Item #49 (Retalho Quimérico Costurado): 100.0%\n")
	sb.WriteString("  - Item #11 (Glândula de Veneno Mutante): 100.0%\n")
	sb.WriteString("  - Item #12 (Placa de Aço Deformada): 100.0%\n")
	sb.WriteString("[Mob 20] Golem de Gelo Antigo:\n")
	sb.WriteString("  - Item #50 (Núcleo de Gelo Antigo): 100.0%\n")
	sb.WriteString("  - Item #12 (Placa de Aço Pesada): 100.0%\n")
	sb.WriteString("[Mob 21] Draco de Geada Selvagem:\n")
	sb.WriteString("  - Item #51 (Escama Dracônica Primordial): 100.0%\n")
	sb.WriteString("  - Item #3 (Carne Nobre Assada): 100.0%\n")
	sb.WriteString("[Mob 22] Ymir, o Patriarca Jotunar (Boss):\n")
	sb.WriteString("  - Item #50 (Núcleo de Gelo Ancestral): 100.0%\n")
	sb.WriteString("  - Item #12 (Placa Glacial Reforçada): 100.0%\n")
	sb.WriteString("  - Item #52 (Coração de Geada Eterna): 0.1% [SECRETO 1/1000 - Desbloqueia Jotunar!]\n")
	sb.WriteString("[Mob 23] Guarda Sanguinário de Vesperian:\n")
	sb.WriteString("  - Item #53 (Insígnia do Guarda Carmesim): 100.0%\n")
	sb.WriteString("  - Item #10 (Sangue Lunar Puro com Frasco Vazio): 100.0%\n")
	sb.WriteString("[Mob 24] Lorde Vesperian, o Progenitor Vampiro (Raid Boss Secreto):\n")
	sb.WriteString("  - Item #55 (Anel Carmesim de Vesperian): 100.0%\n")
	sb.WriteString("  - Item #17 (Tomo da Foice do Eclipse): 100.0%\n")
	sb.WriteString("  - Item #54 (Sangue Puro do Progenitor): 0.1% [SECRETO 1/1000 - Desbloqueia Raça Sangrael!]\n")
	sb.WriteString("==================================================")
	return sb.String()
}

// sendCorpseSnapshots transmite o snapshot de cadáveres ativos para um jogador específico filtrado por sua ZoneID via TCP e UDP.
func (s *Server) sendCorpseSnapshots(p *world.Player) {
	if s.corpseManager == nil || p == nil {
		return
	}
	snaps := s.corpseManager.GetSnapshotsByZone(p.GetZone())
	if len(snaps) == 0 {
		return
	}
	pkt := protocol.SerializeCorpseSnapshot(snaps)

	p.Mu.RLock()
	conn := p.TCPConn
	p.Mu.RUnlock()

	if conn != nil {
		_ = conn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
		_, _ = conn.Write(pkt)
		_ = conn.SetWriteDeadline(time.Time{})
	}
	if addr := p.GetUDPAddr(); addr != nil {
		_, _ = s.udpConn.WriteToUDP(pkt, addr)
	}
}

// broadcastCorpseSnapshots transmite o snapshot de cadáveres ativos filtrados pela ZoneID de cada jogador.
func (s *Server) broadcastCorpseSnapshots() {
	if s.corpseManager == nil {
		return
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, p := range s.players {
		snaps := s.corpseManager.GetSnapshotsByZone(p.GetZone())
		if len(snaps) == 0 {
			continue
		}
		pkt := protocol.SerializeCorpseSnapshot(snaps)
		if p.TCPConn != nil {
			_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
			_, _ = p.TCPConn.Write(pkt)
			_ = p.TCPConn.SetWriteDeadline(time.Time{})
		}
		if addr := p.GetUDPAddr(); addr != nil {
			_, _ = s.udpConn.WriteToUDP(pkt, addr)
		}
	}
}

// handleInteractCorpse processa o pacote TCP 0x3B INTERACT_CORPSE validando distância (<= 2.5m)
// e respondendo com o pacote 0x3C OPEN_AUTOPSY_UI com os pontos vitais e a semente de dificuldade.
func (s *Server) handleInteractCorpse(pkt protocol.InteractCorpsePacket) {
	if s.corpseManager == nil {
		return
	}

	s.mu.RLock()
	player, pExists := s.players[pkt.PlayerID]
	s.mu.RUnlock()
	if !pExists || player == nil {
		return
	}

	corpse, cExists := s.corpseManager.GetCorpse(pkt.CorpseID)
	if !cExists || corpse == nil {
		log.Printf("[CORPSE] Cadáver #%d não encontrado (Jogador #%d)\n", pkt.CorpseID, pkt.PlayerID)
		return
	}

	player.Mu.RLock()
	px, py, pz := player.PosX, player.PosY, player.PosZ
	tcpConn := player.TCPConn
	player.Mu.RUnlock()

	// 1. Validação de Distância (jogador deve estar a <= 2.5m do corpo)
	if !corpse.CanInteract(px, py, pz) {
		dist := corpse.DistanceTo(px, py, pz)
		log.Printf("[CORPSE] Jogador #%d longe demais do cadáver #%d (distância: %.2fm > 2.5m)\n", pkt.PlayerID, pkt.CorpseID, dist)
		s.BroadcastNPCSay(0, fmt.Sprintf("Aproxime-se mais para realizar a autópsia (Distância atual: %.1fm / Máx: 2.5m).", dist))
		return
	}

	if corpse.IsExpired() {
		log.Printf("[CORPSE] Cadáver #%d já expirou / se decompôs.\n", pkt.CorpseID)
		return
	}

	// 2. Sem uma lâmina não há autópsia
	if !player.HasCuttingWeapon() {
		s.sendPlayerNPCSay(player, 0, "🔪 Você precisa de uma arma cortante (adaga, espada, cutelo...) para abrir a carcaça. Garrick, o Ferreiro, pode ajudar.")
		return
	}

	// 3. Extrai pontos vitais (órgãos) da criatura
	player.SetInAutopsy(true)
	corpse.Mu.RLock()
	mobType := corpse.MobType
	seed := corpse.DifficultySeed
	entries := make([]protocol.AutopsyOrganEntry, len(corpse.Organs))
	for i, o := range corpse.Organs {
		entries[i] = protocol.AutopsyOrganEntry{
			OrganIndex:  o.Index,
			OrganType:   o.OrganType,
			ItemReward:  o.ItemReward,
			Difficulty:  o.Difficulty,
			QualityTier: o.QualityTier,
		}
	}
	corpse.Mu.RUnlock()

	// 3. Envia para o cliente o pacote TCP 0x3C OPEN_AUTOPSY_UI
	openPkt := protocol.SerializeOpenAutopsyUI(pkt.CorpseID, mobType, seed, entries)
	if tcpConn != nil {
		_ = tcpConn.SetWriteDeadline(time.Now().Add(300 * time.Millisecond))
		_, _ = tcpConn.Write(openPkt)
		_ = tcpConn.SetWriteDeadline(time.Time{})
		log.Printf("[CORPSE] Enviado pacote 0x3C OPEN_AUTOPSY_UI para Jogador #%d (Cadáver #%d, %d órgãos, seed %d)\n",
			pkt.PlayerID, pkt.CorpseID, len(entries), seed)
	}
}

// handleSubmitAutopsyResult processa o pacote TCP 0x3D SUBMIT_AUTOPSY_RESULT,
// concedendo o drop correspondente, adicionando ao inventário e atualizando o cadáver.
func (s *Server) handleSubmitAutopsyResult(pkt protocol.SubmitAutopsyResultPacket) {
	if s.corpseManager == nil {
		return
	}

	s.mu.RLock()
	player, pExists := s.players[pkt.PlayerID]
	s.mu.RUnlock()
	if !pExists || player == nil {
		return
	}

	corpse, cExists := s.corpseManager.GetCorpse(pkt.CorpseID)
	if !cExists || corpse == nil {
		log.Printf("[AUTOPSIA] Cadáver #%d não encontrado (Jogador #%d)\n", pkt.CorpseID, pkt.PlayerID)
		player.SetInAutopsy(false)
		return
	}

	player.Mu.RLock()
	px, py, pz := player.PosX, player.PosY, player.PosZ
	player.Mu.RUnlock()

	// Validação de Distância
	if !corpse.CanInteract(px, py, pz) {
		dist := corpse.DistanceTo(px, py, pz)
		log.Printf("[AUTOPSIA] Jogador #%d fora do alcance do cadáver #%d (dist: %.2fm)\n", pkt.PlayerID, pkt.CorpseID, dist)
		player.SetInAutopsy(false)
		return
	}

	if corpse.IsExpired() {
		log.Printf("[AUTOPSIA] Cadáver #%d expirou.\n", pkt.CorpseID)
		player.SetInAutopsy(false)
		return
	}

	// Drenar sangue/veneno é opcional e exige um Frasco Vazio (Aracne coleta veneno sem frasco)
	var pendingType uint8
	corpse.Mu.RLock()
	for _, o := range corpse.Organs {
		if o.Index == pkt.OrganIndex {
			pendingType = o.OrganType
		}
	}
	corpse.Mu.RUnlock()
	arachneVenom := player.RaceID == protocol.RaceArachne && (pendingType == world.OrganGland || pendingType == world.OrganVenomSac)
	if world.IsBloodOrgan(pendingType) && !arachneVenom && !player.HasItem(protocol.ItemEmptyFlask) {
		s.sendPlayerNPCSay(player, 0, "🧪 Você precisa de um Frasco de Vidro Vazio para drenar sangue ou veneno.")
		s.handleInteractCorpse(protocol.InteractCorpsePacket{PlayerID: pkt.PlayerID, CorpseID: pkt.CorpseID})
		return
	}

	// A Qualidade do minigame decide o resultado (o tier enviado é só informativo)
	if pkt.Quality > 100 {
		pkt.Quality = 100
	}
	switch {
	case pkt.Quality >= world.PerfectQuality:
		pkt.ResultTier = protocol.QualityPerfect
	case pkt.Quality >= world.JunkQuality:
		pkt.ResultTier = protocol.QualityCommon
	default:
		pkt.ResultTier = protocol.QualityDestroyed
	}

	// Atualiza o estado do órgão no cadáver
	organ, ok := corpse.MarkOrganExtracted(pkt.OrganIndex, pkt.ResultTier)
	if !ok {
		log.Printf("[AUTOPSIA] Ponto vital #%d do cadáver #%d já extraído ou inválido.\n", pkt.OrganIndex, pkt.CorpseID)
		return
	}

	var itemToGive uint8
	var qty uint8 = 1
	var resultMsg string

	switch pkt.ResultTier {
	case protocol.QualityPerfect: // 1: Perfeito (Zona Verde / Perícia MAS)
		player.Mu.Lock()
		player.PerfectAutopsiesStreak++
		streak := player.PerfectAutopsiesStreak
		player.Mu.Unlock()
		log.Printf("[NECROMANTE DE OSSOS] Jogador #%d atingiu sequência de %d autópsias perfeitas!\n", player.ID, streak)

		itemToGive = organ.ItemReward
		qty = organ.Quantity
		if qty == 0 {
			qty = 1
		}
		resultMsg = fmt.Sprintf("[AUTÓPSIA EXCELENTE] Você extraiu: %s x%d (Qualidade %d/100).", organ.Name, qty, pkt.Quality)

	case protocol.QualityCommon: // 2: Comum (Zona Amarela)
		player.Mu.Lock()
		player.PerfectAutopsiesStreak = 0
		player.Mu.Unlock()

		itemToGive = organ.ItemReward
		qty = organ.Quantity
		if qty == 0 {
			qty = 1
		}
		resultMsg = fmt.Sprintf("[AUTÓPSIA COMUM] Você extraiu: %s x%d (Qualidade %d/100).", organ.Name, qty, pkt.Quality)

	default: // 3: Destruído / Zona Vermelha ou Tempo Expirado
		player.Mu.Lock()
		player.PerfectAutopsiesStreak = 0
		player.Mu.Unlock()

		itemToGive = world.JunkFor(organ.ItemReward) // Lixo Orgânico ou Sucata Metálica
		qty = 1
		resultMsg = fmt.Sprintf("[AUTÓPSIA FALHA] Qualidade %d/100 (abaixo de %d): %s virou %s.", pkt.Quality, world.JunkQuality, organ.Name, world.GetItemInfo(itemToGive).Name)
	}

	// Consome o Frasco Vazio quando o fluido é drenado com sucesso
	if world.IsBloodOrgan(organ.OrganType) && pkt.ResultTier != protocol.QualityDestroyed {
		if arachneVenom {
			resultMsg += " [Tecelão da Bruma: Veneno coletado organicamente sem frasco!]"
		} else if player.RemoveItem(protocol.ItemEmptyFlask, 1) {
			resultMsg += " [Frasco Vazio preenchido!]"
		}
	}
	if m, isMat := world.GetMaterial(itemToGive); isMat && pkt.ResultTier != protocol.QualityDestroyed {
		resultMsg += fmt.Sprintf(" [%s • %s | Durab. %d | Resist.: %s]", m.Name, world.RarityNames[m.Rarity], m.Durability, m.Resistances)
	}

	// Verifica se a mochila está cheia (limite de 24 slots)
	slots := player.GetInventorySlots()
	inventoryFull := len(slots) >= 24 && !player.HasItem(itemToGive)

	if inventoryFull {
		log.Printf("[AUTOPSIA] Mochila do jogador #%d cheia! Item %d (%s) deixado no chão junto ao cadáver #%d.\n",
			player.ID, itemToGive, organ.Name, pkt.CorpseID)
		s.BroadcastNPCSay(0, fmt.Sprintf("[MOCHILA CHEIA] Sua mochila está lotada! O item (%s) ficou no chão junto ao cadáver.", organ.Name))
	} else {
		player.AddItemWithQuality(itemToGive, qty, pkt.Quality)
		s.sendInventorySync(player)
		s.sendPlayerNPCSay(player, 0, resultMsg)
		log.Printf("[AUTOPSIA] Jogador #%d extraiu órgão #%d do cadáver #%d (Tier %d) -> Item %d (x%d)\n",
			player.ID, pkt.OrganIndex, pkt.CorpseID, pkt.ResultTier, itemToGive, qty)
	}

	s.sendPlayerStats(player)
	s.broadcastCorpseSnapshots()

	corpse.Mu.RLock()
	allExtracted := true
	for _, o := range corpse.Organs {
		if !o.Extracted {
			allExtracted = false
			break
		}
	}
	corpse.Mu.RUnlock()

	if allExtracted {
		player.SetInAutopsy(false)
	} else {
		player.SetInAutopsy(true) // renova proteção de 15s para os próximos órgãos
	}

	// Notifica o cliente com o estado atualizado dos órgãos da criatura
	s.handleInteractCorpse(protocol.InteractCorpsePacket{
		PlayerID: pkt.PlayerID,
		CorpseID: pkt.CorpseID,
	})
}

// resolveBodyBlocking resolve colisão física cilindro-cilindro no tick de 30 Hz entre Jogadores e Mobs vivos.
// Se a distância for menor que 1.15m (comuns) ou 1.50m (Bosses), empurra o Mob suavemente para fora.
func (s *Server) resolveBodyBlocking() {
	if s.mobManager == nil {
		return
	}

	mobs := s.mobManager.GetAllMobs()

	s.mu.RLock()
	players := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		players = append(players, p)
	}
	s.mu.RUnlock()

	for _, mob := range mobs {
		mob.Mu.Lock()
		if !mob.IsAlive || !mob.IsActive {
			mob.Mu.Unlock()
			continue
		}

		var minRadius float32 = 1.15
		if mob.MobType == protocol.MobTypeIronEnforcer || mob.MobType == protocol.MobTypeLycanthropeAlpha {
			minRadius = 1.50
		}

		mx, mz := mob.PosX, mob.PosZ

		for _, player := range players {
			player.Mu.RLock()
			px, pz := player.PosX, player.PosZ
			isAlive := player.HP > 0
			player.Mu.RUnlock()

			if !isAlive || player.GetZone() != mob.ZoneID {
				continue
			}

			dx := mx - px
			dz := mz - pz
			dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))

			if dist < minRadius {
				overlap := minRadius - dist
				var dirX, dirZ float32
				if dist > 0.001 {
					dirX = dx / dist
					dirZ = dz / dist
				} else {
					dirX = 1.0
					dirZ = 0.0
				}

				mx += dirX * overlap
				mz += dirZ * overlap
				mx, mz = world.ClampToZoneBounds(mob.ZoneID, mx, mz)
			}
		}

		mob.PosX = mx
		mob.PosZ = mz
		mob.Mu.Unlock()
	}
}

// updateMoonPhaseCreatures ativa/desperta Lobo Alfa (Lua Cheia), Licantropo Alfa (Lua de Sangue) e Lorde Vesperian (Noite, Lua de Sangue ou Eclipse).
func (s *Server) updateMoonPhaseCreatures(moon uint8) {
	if s.mobManager == nil {
		return
	}

	// Lobo Alfa (ID 207, MobType 6): ativo apenas em Lua Cheia (MoonPhase == 4)
	wolfAlfa := s.mobManager.GetMob(207)
	if wolfAlfa != nil {
		if moon == 4 {
			if !wolfAlfa.IsMobActive() {
				wolfAlfa.SetActive(true)
				log.Println("[LUA CHEIA] O Lobo Alfa surgiu no Bosque Sussurrante!")
			}
		} else {
			if wolfAlfa.IsMobActive() {
				wolfAlfa.SetActive(false)
			}
		}
	}

	// Licantropo Alfa (ID 208, MobType 7): desperta durante a Lua de Sangue (MoonPhase == 8)
	lycanAlfa := s.mobManager.GetMob(208)
	if lycanAlfa != nil {
		if moon == 8 {
			if !lycanAlfa.IsMobActive() {
				lycanAlfa.SetActive(true)
				s.BroadcastNPCSay(208, "[LUA DE SANGUE] Um uivo aterrorizante ecoa pelo bosque... O Licantropo Alfa despertou!")
				log.Println("[LUA DE SANGUE] O Licantropo Alfa despertou no Bosque Sussurrante!")
			}
		} else {
			if lycanAlfa.IsMobActive() {
				lycanAlfa.SetActive(false)
			}
		}
	}

	// Lorde Vesperian, o Progenitor Vampiro (ID 229, MobType 24):
	// Desperta à Noite (18h às 05h59), Lua de Sangue (MoonPhase == 8) ou Eclipse (MoonPhase == 9)
	vesperian := s.mobManager.GetMob(229)
	if vesperian != nil {
		currentHour := s.clock.GetCurrentHour()
		isNight := currentHour >= 18 || currentHour < 6
		isBloodMoonOrEclipse := (moon == 8 || moon == 9)
		if isNight || isBloodMoonOrEclipse {
			if !vesperian.IsMobActive() {
				vesperian.SetActive(true)
				s.BroadcastNPCSay(229, "[SANTUÁRIO DO ECLIPSE] As brumas carmesins se condensam na Cripta... Lorde Vesperian despertou!")
				log.Println("[VESPERIAN] Lorde Vesperian despertou na Cripta Carmesim do Santuário do Eclipse!")
			}
		} else {
			if vesperian.IsMobActive() {
				vesperian.SetActive(false)
				log.Println("[VESPERIAN] Os raios de sol forçam Lorde Vesperian a retornar ao seu sarcófago de pedra.")
			}
		}
	}
}

// BroadcastProjectileSpawn transmite o pacote UDP 0x35 (PROJECTILE_SPAWN) para todos os clientes conectados.
func (s *Server) BroadcastProjectileSpawn(p *world.Projectile) {
	pkt := protocol.SerializeProjectileSpawn(p.ID, p.OwnerID, p.ProjType, p.PosX, p.PosY, p.PosZ, p.DirX, p.DirZ, p.Speed, p.MaxRange)

	s.mu.RLock()
	targetAddrs := make([]*net.UDPAddr, 0, len(s.players))
	for _, player := range s.players {
		if addr := player.GetUDPAddr(); addr != nil {
			targetAddrs = append(targetAddrs, addr)
		}
	}
	s.mu.RUnlock()

	for _, addr := range targetAddrs {
		_, _ = s.udpConn.WriteToUDP(pkt[:], addr)
	}
}

// updateProjectiles avança os projéteis ativos a 30 Hz e processa colisões com raio 1.1m contra bonecos e mobs.
func (s *Server) updateProjectiles(dt float32) {
	activeProjs := s.projManager.GetActiveProjectiles()
	if len(activeProjs) == 0 {
		return
	}

	h, _, moon, _ := s.clock.GetTime()

	for _, p := range activeProjs {
		if !p.IsActive {
			continue
		}

		step := p.Speed * dt
		p.PosX += p.DirX * step
		p.PosZ += p.DirZ * step
		p.Traveled += step

		if p.Traveled >= p.MaxRange {
			p.IsActive = false
			continue
		}

		s.mu.RLock()
		owner, ownerExists := s.players[p.OwnerID]
		var ownerRace, ownerClass uint8
		var ownerHP, ownerMaxHP uint16
		if ownerExists {
			owner.Mu.RLock()
			ownerRace = owner.RaceID
			ownerClass = owner.ClassID
			ownerHP = owner.HP
			ownerMaxHP = owner.MaxHP
			owner.Mu.RUnlock()
		}
		s.mu.RUnlock()

		if !ownerExists {
			p.IsActive = false
			continue
		}

		hpPct := float32(ownerHP) / float32(ownerMaxHP) * 100.0
		actionType := p.ActionType
		if actionType == 0 {
			actionType = protocol.ActionBasicAttack
			if p.ProjType == protocol.ProjTypePiercingArrow || p.ProjType == protocol.ProjTypeElementalComet {
				actionType = protocol.ActionSkillQ
			}
		}

		ownerTier := owner.ClassTier
		ownerLevel := owner.Level
		var ownerBuff uint8 = 0
		if owner.IsBuffActive() {
			ownerBuff = 1
		}
		ownerZone := owner.GetZone()
		weather := s.clock.GetZoneWeather(ownerZone)
		oSTR, oDEX, _, _, oINT, oSPI, oMAS, oLCK := owner.GetAttributes()

		// 1. Colisão contra Bonecos de Treino (raio 1.1m)
		s.mu.RLock()
		for _, dummy := range s.dummies {
			if p.HitTargets[dummy.ID] || dummy.GetZone() != ownerZone {
				continue
			}

			dx, _, dz := dummy.GetPos()
			distX := dx - p.PosX
			distZ := dz - p.PosZ
			dist := float32(math.Sqrt(float64(distX*distX + distZ*distZ)))

			if dist <= 1.1 {
				p.HitTargets[dummy.ID] = true

				damage, isCrit := s.luaEngine.CallCalculateDamage(
					ownerRace,
					ownerClass,
					actionType,
					hpPct,
					int(h),
					moon,
					weather,
					ownerTier,
					ownerLevel,
					ownerBuff,
					oSTR,
					oDEX,
					oINT,
					oSPI,
					oMAS,
					oLCK,
				)
				damage = applyPathDamage(damage, owner) // Caminho Evolutivo (Dano)

				newHP, reset := dummy.TakeDamage(damage)
				_, maxDummyHP := dummy.GetHP()
				s.BroadcastCombatEvent(p.OwnerID, dummy.ID, actionType, damage, isCrit, newHP, maxDummyHP)

				// Lifesteal
				if ownerRace == protocol.RaceDhampir {
					owner.Heal(8)
					s.sendPlayerStats(owner)
				}
				if ownerClass == protocol.ClassEclipseReaper {
					owner.Heal(12)
					s.sendPlayerStats(owner)
				}

				if reset {
					log.Printf("[COMBATE] Projétil #%d destruiu o Boneco #%d!\n", p.ID, dummy.ID)
				}

				// Explosão em área (Cometa Elemental, Frascos de Ácido, etc.)
				if p.SplashRadius > 0 {
					s.triggerAoEExplosion(p.OwnerID, p.PosX, p.PosZ, p.SplashRadius, damage/2, isCrit)
					if ownerClass == protocol.ClassAlchemist && actionType == protocol.ActionSkillR {
						s.applyAcidPool(p.OwnerID, p.PosX, p.PosZ, p.SplashRadius)
					}
				} else if p.ProjType == protocol.ProjTypeElementalComet {
					s.triggerAoEExplosion(p.OwnerID, p.PosX, p.PosZ, 2.8, damage/2, isCrit)
				} else if p.ProjType == protocol.ProjTypeAcidFlask {
					s.triggerAoEExplosion(p.OwnerID, p.PosX, p.PosZ, 2.2, damage/2, isCrit)
				}

				if p.ProjType != protocol.ProjTypePiercingArrow {
					p.IsActive = false
					break
				}
			}
		}
		s.mu.RUnlock()

		if !p.IsActive {
			continue
		}

		// 2. Colisão contra Mobs vivos (raio 1.1m)
		if s.mobManager != nil {
			for _, mob := range s.mobManager.GetAllMobs() {
				if !mob.IsAlive || p.HitTargets[mob.ID] || mob.GetZone() != ownerZone {
					continue
				}

				mob.Mu.RLock()
				mx, mz := mob.PosX, mob.PosZ
				mob.Mu.RUnlock()

				distX := mx - p.PosX
				distZ := mz - p.PosZ
				dist := float32(math.Sqrt(float64(distX*distX + distZ*distZ)))

				if dist <= 1.1 {
					p.HitTargets[mob.ID] = true

					damage, isCrit := s.luaEngine.CallCalculateDamage(
						ownerRace,
						ownerClass,
						actionType,
						hpPct,
						int(h),
						moon,
						weather,
						ownerTier,
						ownerLevel,
						ownerBuff,
						oSTR,
						oDEX,
						oINT,
						oSPI,
						oMAS,
						oLCK,
					)
					damage = applyPathDamage(damage, owner) // Caminho Evolutivo (Dano)
					damage = variantDamageAgainst(ownerClass, mob, damage)

					finalDamage, wasBlocked, newHP, isDead := mob.TakeDamage(damage, p.OwnerID)
					s.BroadcastCombatEvent(p.OwnerID, mob.ID, actionType, finalDamage, isCrit, newHP, mob.MaxHP)
					s.applyVariantOnHitPassives(owner, ownerClass, mob, finalDamage, isDead)

					// Lifesteal
					if ownerRace == protocol.RaceDhampir {
						owner.Heal(8)
						s.sendPlayerStats(owner)
					}
					if ownerClass == protocol.ClassEclipseReaper {
						owner.Heal(12)
						s.sendPlayerStats(owner)
					}

					// Disparo de Estrepes (Sentinela dos Ventos Skill R): reduz MoveSpeed em 40% por 3s
					if p.ProjType == protocol.ProjTypePiercingArrow && actionType == protocol.ActionSkillR {
						mob.ApplySlow(3*time.Second, 0.40)
						log.Printf("[LENTIDAO] Mob #%d atingido por Estrepes! Velocidade reduzida em 40%% por 3s.\n", mob.ID)
					}

					log.Printf("[COMBATE] Projétil #%d (Tipo %d) atingiu Mob #%d (%s) causando %d dano (Bloqueado: %v) | HP: %d/%d\n",
						p.ID, p.ProjType, mob.ID, mob.Name, finalDamage, wasBlocked, newHP, mob.MaxHP)

					if isDead {
						s.handleMobDeath(mob, p.OwnerID)
					}

					// Explosão em área
					if p.SplashRadius > 0 {
						s.triggerAoEExplosion(p.OwnerID, p.PosX, p.PosZ, p.SplashRadius, damage/2, isCrit)
						if ownerClass == protocol.ClassAlchemist && actionType == protocol.ActionSkillR {
							s.applyAcidPool(p.OwnerID, p.PosX, p.PosZ, p.SplashRadius)
						}
					} else if p.ProjType == protocol.ProjTypeElementalComet {
						s.triggerAoEExplosion(p.OwnerID, p.PosX, p.PosZ, 2.8, damage/2, isCrit)
					} else if p.ProjType == protocol.ProjTypeAcidFlask {
						s.triggerAoEExplosion(p.OwnerID, p.PosX, p.PosZ, 2.2, damage/2, isCrit)
					}

					if p.ProjType != protocol.ProjTypePiercingArrow {
						p.IsActive = false
						break
					}
				}
			}
		}
	}

	s.projManager.Cleanup()
}

// triggerAoEExplosion aplica dano em área na detonação de projéteis (Cometa, Frascos de Ácido, etc).
func (s *Server) triggerAoEExplosion(ownerID uint32, cx, cz, radius float32, splashDmg uint16, isCrit uint8) {
	if s.mobManager == nil {
		return
	}
	var ownerZone uint8
	s.mu.RLock()
	if owner, ok := s.players[ownerID]; ok {
		ownerZone = owner.GetZone()
	}
	s.mu.RUnlock()

	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive || mob.GetZone() != ownerZone {
			continue
		}
		mob.Mu.RLock()
		mx, mz := mob.PosX, mob.PosZ
		mob.Mu.RUnlock()

		dist := float32(math.Sqrt(float64((mx-cx)*(mx-cx) + (mz-cz)*(mz-cz))))
		if dist <= radius {
			finalDmg, _, newHP, isDead := mob.TakeDamage(splashDmg, ownerID)
			s.BroadcastCombatEvent(ownerID, mob.ID, protocol.ActionSkillQ, finalDmg, isCrit, newHP, mob.MaxHP)
			if isDead {
				s.handleMobDeath(mob, ownerID)
			}
		}
	}
}

// triggerCometExplosion mantém compatibilidade chamando triggerAoEExplosion.
func (s *Server) triggerCometExplosion(ownerID uint32, cx, cz, radius float32, splashDmg uint16, isCrit uint8) {
	s.triggerAoEExplosion(ownerID, cx, cz, radius, splashDmg, isCrit)
}

// removePlayerAndNotify remove o jogador e notifica os demais via TCP (0x02).
func (s *Server) removePlayerAndNotify(playerID uint32) {
	s.mu.Lock()
	p, exists := s.players[playerID]
	if !exists {
		s.mu.Unlock()
		return
	}

	delete(s.players, playerID)
	if p.TCPConn != nil {
		_ = p.TCPConn.Close()
	}

	remainingConns := make([]net.Conn, 0, len(s.players))
	for _, remaining := range s.players {
		if remaining.TCPConn != nil {
			remainingConns = append(remainingConns, remaining.TCPConn)
		}
	}
	remainingCount := len(s.players)
	s.mu.Unlock()

	log.Printf("[TCP] Jogador %d desconectado. Notificando %d jogadores restantes (Ativos: %d/%d)\n", playerID, len(remainingConns), remainingCount, MaxPlayers)

	disconnectPkt := protocol.SerializePlayerDisconnected(playerID)
	for _, clientConn := range remainingConns {
		_ = clientConn.SetWriteDeadline(time.Now().Add(500 * time.Millisecond))
		_, _ = clientConn.Write(disconnectPkt[:])
	}
}

// runUDPListener processa pacotes 0x10 (PLAYER_MOVE) e 0x31 (PLAYER_ACTION).
func (s *Server) runUDPListener() {
	defer s.wg.Done()

	buf := make([]byte, 1024)
	var movePkt protocol.PlayerMovePacket
	var actionPkt protocol.PlayerActionPacket

	for {
		select {
		case <-s.ctx.Done():
			return
		default:
		}

		n, clientAddr, err := s.udpConn.ReadFromUDP(buf)
		if err != nil {
			select {
			case <-s.ctx.Done():
				return
			default:
				continue
			}
		}

		if n < 1 {
			continue
		}

		switch buf[0] {
		case protocol.PacketTypePlayerMove:
			if n != protocol.PlayerMovePacketSize {
				continue
			}
			if err := protocol.DeserializePlayerMove(buf[:n], &movePkt); err != nil {
				continue
			}

			s.mu.RLock()
			player, exists := s.players[movePkt.PlayerID]
			s.mu.RUnlock()

			if exists {
				// 1. Trava de 1.0s pós-respawn para ignorar pacotes UDP residuais do cliente caindo no void
				if player.IsRespawnLocked() {
					continue
				}

				// 2. Queda no Abismo/Void: se PosY < -8.0, executa Respawn oficial no Centro (0, 1.5, 0)
				if movePkt.PosY < -8.0 {
					log.Printf("[VOID] Jogador #%d caiu no abismo (PosY=%.2f < -8.0)! Teleportando para o Centro (0, 1.5, 0)...\n", movePkt.PlayerID, movePkt.PosY)
					s.RespawnPlayer(player)
					continue
				}

				player.UpdateFromMove(movePkt.Seq, movePkt.PosX, movePkt.PosY, movePkt.PosZ, movePkt.RotY, clientAddr)
			}

		case protocol.PacketTypePlayerAction:
			if n != protocol.PlayerActionPacketSize {
				continue
			}
			if err := protocol.DeserializePlayerAction(buf[:n], &actionPkt); err != nil {
				continue
			}

			s.handlePlayerAction(actionPkt)
		}
	}
}

// runGameLoop executa a simulação autoritativa a 30 Hz (física, combate, stamina, snapshots) e 1 Hz para IA e Relógio.
func (s *Server) runGameLoop() {
	defer s.wg.Done()

	ticker := time.NewTicker(time.Second / GameTickRate)
	defer ticker.Stop()

	// Buffers estáticos para serialização de snapshots
	var playerSnapshotBuf [WorldSnapshotMaxBufferSize]byte
	var npcSnapshotBuf [NPCSnapshotMaxBufferSize]byte

	var aiTickCounter int
	dt := float32(1.0 / float32(GameTickRate))

	for {
		select {
		case <-s.ctx.Done():
			return
		case <-ticker.C:
			s.serverTick++

			// 1. Avanço contínuo do Relógio Assimétrico Oficial a 30 Hz
			s.clock.Advance(float64(dt))

			// 2. Regeneração de Estamina dos Jogadores a 30 Hz (+15% sob Lua Crescente à noite)
			currentH, _, currentMoon, _ := s.clock.GetTime()
			isNight := (currentH >= 18 || currentH < 6)

			s.mu.RLock()
			for _, p := range s.players {
				zw := s.clock.GetZoneWeather(p.GetZone())
				p.RegenerateStamina(dt*world.WeatherStaminaMult(zw), isNight, currentMoon)
				p.RegenerateMana(dt*world.WeatherManaMult(zw), p.OutOfCombat())
			}
			// Mana: envia o valor atualizado 2x por segundo (a regeneração é contínua)
			if s.serverTick%15 == 0 {
				for _, p := range s.players {
					if p.ManaChanged() {
						go s.sendPlayerStats(p)
					}
				}
			}

			// 3. Atualização física suave dos NPCs a 30 Hz
			for _, npc := range s.npcs {
				npc.UpdateMovement(dt)
			}

			// 3.1. Dano de Fogo da Fornalha do Garrick a cada 0.8s (Fire Hazard: 14.0, 14.0 - Raio 2.3m)
			s.fireHazardTimer += dt
			if s.fireHazardTimer >= 0.8 {
				s.fireHazardTimer = 0
				s.checkForgeFireHazard()
			}

			// 4. Coleta de dados dos jogadores e destinos UDP organizados por Zona
			zonePlayerSnaps := make(map[uint8][]protocol.PlayerSnapshot)
			zoneTargetAddrs := make(map[uint8][]*net.UDPAddr)

			for _, p := range s.players {
				z := p.GetZone()
				zonePlayerSnaps[z] = append(zonePlayerSnaps[z], p.ToSnapshot())
				if addr := p.GetUDPAddr(); addr != nil {
					zoneTargetAddrs[z] = append(zoneTargetAddrs[z], addr)
				}
			}

			// Coleta de NPCs e Bonecos de Treino por Zona
			zoneNPCSnaps := make(map[uint8][]protocol.NPCSnapshot)
			for _, npc := range s.npcs {
				z := npc.GetZone()
				zoneNPCSnaps[z] = append(zoneNPCSnaps[z], npc.ToSnapshot())
			}
			for _, dummy := range s.dummies {
				z := dummy.GetZone()
				zoneNPCSnaps[z] = append(zoneNPCSnaps[z], dummy.ToSnapshot())
			}
			s.mu.RUnlock()

			// Envio dos snapshots via UDP filtrados rigorosamente por Zona
			for z, addrs := range zoneTargetAddrs {
				if len(addrs) == 0 {
					continue
				}

				// 1. Jogadores da mesma zona (0x11: WORLD_SNAPSHOT)
				pSnaps := zonePlayerSnaps[z]
				if len(pSnaps) > 0 {
					written := protocol.SerializeWorldSnapshotInto(playerSnapshotBuf[:], s.serverTick, pSnaps)
					if written > 0 {
						payload := playerSnapshotBuf[:written]
						for _, addr := range addrs {
							_, _ = s.udpConn.WriteToUDP(payload, addr)
						}
					}
				}

				// 2. NPCs e Dummies da mesma zona (0x12: NPC_SNAPSHOT)
				nSnaps := zoneNPCSnaps[z]
				if len(nSnaps) > 0 {
					writtenNPC := protocol.SerializeNPCSnapshotInto(npcSnapshotBuf[:], nSnaps)
					if writtenNPC > 0 {
						npcPayload := npcSnapshotBuf[:writtenNPC]
						for _, addr := range addrs {
							_, _ = s.udpConn.WriteToUDP(npcPayload, addr)
						}
					}
				}

				// 3. Mobs da mesma zona (0x14: MOB_SNAPSHOT)
				if s.mobManager != nil {
					mobSnaps := s.mobManager.GetSnapshotsByZone(z)
					if len(mobSnaps) > 0 {
						mobPayload := protocol.SerializeMobSnapshot(mobSnaps)
						for _, addr := range addrs {
							_, _ = s.udpConn.WriteToUDP(mobPayload, addr)
						}
					}
				}
			}

			// Resolução de colisão física cilindro-cilindro (Body Blocking) a 30 Hz
			s.resolveBodyBlocking()

			// 4.5. Atualização física e colisões dos Projéteis 3D (30 Hz)
			if s.projManager != nil {
				s.updateProjectiles(dt)
			}

			// 5. Atualização tática da IA dos Monstros e Verificação de Renascimentos
			if s.mobManager != nil {
				respawned := s.mobManager.UpdateRespawns()
				for _, rId := range respawned {
					log.Printf("[WORLD] Mob #%d renasceu no seu ponto de spawn!\n", rId)
				}

				allMobs := s.mobManager.GetAllMobs()
				for _, mob := range allMobs {
					if !mob.IsAlive {
						continue
					}

					// Recuperação autoritativa de vulnerabilidade expirada (ex: Executor de Ferro)
					if mob.CheckVulnerabilityExpired() {
						log.Printf("[WORLD] Mob #%d (%s) recuperou-se da vulnerabilidade e voltou a agir!\n", mob.ID, mob.Name)
					}

					mob.Mu.RLock()
					mx, mz := mob.PosX, mob.PosZ
					mobZone := mob.ZoneID
					mob.Mu.RUnlock()

					var nearestPID uint32 = 0
					var minPlayerDist float32 = 999.0
					var targetPX, targetPZ float32

					s.mu.RLock()
					for _, p := range s.players {
						if p.IsInAutopsy() || p.GetZone() != mobZone {
							continue
						}
						p.Mu.RLock()
						px, pz := p.PosX, p.PosZ
						pid := p.ID
						p.Mu.RUnlock()

						pdx := px - mx
						pdz := pz - mz
						dist := float32(math.Sqrt(float64(pdx*pdx + pdz*pdz)))
						if !p.CanBeDetected(dist) {
							continue // Invisível ou furtivo longe demais: o monstro não o percebe
						}
						if dist < minPlayerDist {
							minPlayerDist = dist
							nearestPID = pid
							targetPX = px
							targetPZ = pz
						}
					}
					s.mu.RUnlock()

					s.luaEngine.UpdateMobAI(mob, nearestPID, minPlayerDist, targetPX, targetPZ, currentMoon, dt)
				}

				// Re-aplica resolução de colisão após deslocamento da IA
				s.resolveBodyBlocking()

				// 6. Defesa da Vila pelo Garrick: Monstros a menos de 6.5m na mesma zona sofrem retaliação a cada 2s
				s.mu.RLock()
				garrick := s.npcs[100]
				s.mu.RUnlock()

				if garrick != nil && !garrick.LifeBusy() {
					gx, _, gz := garrick.GetPos()
					garrickZone := garrick.GetZone()
					for _, mob := range allMobs {
						if !mob.IsAlive || mob.GetZone() != garrickZone {
							continue
						}
						mob.Mu.RLock()
						mx, mz := mob.PosX, mob.PosZ
						mob.Mu.RUnlock()

						distG := float32(math.Sqrt(float64((mx-gx)*(mx-gx) + (mz-gz)*(mz-gz))))
						if distG <= 6.5 {
							if time.Since(s.garrickLastDefend) >= 2*time.Second {
								s.garrickLastDefend = time.Now()
								s.BroadcastNPCSay(100, "Monstros perto da minha forja?! Provem do meu martelo!")
								finalDmg, _, newHP, isDead := mob.TakeDamage(80)
								s.BroadcastCombatEvent(100, mob.ID, protocol.ActionBasicAttack, finalDmg, 1, newHP, mob.MaxHP)
								if isDead {
									log.Printf("[WORLD] Garrick esmagou o Mob #%d com seu martelo!\n", mob.ID)
									s.handleMobDeath(mob, 0)
								}
							}
						}
					}
				}

				// Defesa perimetral dos Guardas da Patrulha Real (IDs 105 e 106) na mesma zona
				guards := []*world.NPC{s.npcs[105], s.npcs[106]}
				for _, guard := range guards {
					if guard == nil {
						continue
					}
					gx, _, gz := guard.GetPos()
					guardZone := guard.GetZone()
					for _, mob := range allMobs {
						if !mob.IsAlive || !mob.IsActive || mob.GetZone() != guardZone {
							continue
						}
						mob.Mu.RLock()
						mx, mz := mob.PosX, mob.PosZ
						mob.Mu.RUnlock()

						dx := mx - gx
						dz := mz - gz
						dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
						if dist <= 7.0 {
							lastAtk := s.guardLastAttack[guard.ID]
							if time.Since(lastAtk) >= 1500*time.Millisecond {
								s.guardLastAttack[guard.ID] = time.Now()
								s.BroadcastNPCSay(guard.ID, "Pela Guarda Real! Em guarda, monstro!")
								s.handleNPCAttackMob(guard.ID, mob.ID, 70)
							}
							break
						}
					}
				}
			}

			// 5. Loop de Relógio, IA, Status e Proximidade a 1 Hz (a cada 30 ticks)
			aiTickCounter++
			if aiTickCounter >= GameTickRate {
				aiTickCounter = 0

				h, _, moon, weather := s.clock.GetTime()
				s.updateNPCRoutines(int(h))
				s.updateNPCLife(1.0)
				if s.serverTick%(GameTickRate*10) < GameTickRate {
					s.updateWaterEvaporation(int(h))
				}
				s.updateClassMasterRoutines(int(h))
				s.updatePlaceTrials()
				s.expireGroundItems()
				s.respawnResourceNodes()
				if s.serverTick%(GameTickRate*2) < GameTickRate {
					s.updateCompanions() // Companheiros atacam sozinhos a cada 2s
				}
				s.updateMoonPhaseCreatures(moon)

				// Logging quando muda a hora cheia
				if changed, newH := s.clock.CheckHourChanged(); changed {
					log.Printf("[RELÓGIO] Hora do Mundo: %02d:00 | Fase da Lua: %d | Clima: %d\n", newH, moon, weather)
				}

				// Transmite o horário, fase da lua e clima atualizados (0x13: 5 bytes)
				s.BroadcastWorldTime()

				// Limpeza de Cadáveres Decompostos (120 segundos de persistência)
				if s.corpseManager != nil {
					expired := s.corpseManager.CleanupExpired()
					if len(expired) > 0 {
						log.Printf("[CORPSE] %d cadáver(es) se decompuseram no solo: %v\n", len(expired), expired)
						s.broadcastCorpseSnapshots()
					}
				}

				s.mu.RLock()
				// Sincroniza status autoritativos com os jogadores conectados (0x33: 15 bytes)
				for _, p := range s.players {
					s.sendPlayerStats(p)
				}

				// Dispara OnTick para cada NPC com a hora atual
				for _, npc := range s.npcs {
					_ = luaengine.CallOnTick(npc, int(h))
				}

				// Verificação de raio de aproximação (< 4.0m)
				for _, npc := range s.npcs {
					for _, player := range s.players {
						player.Mu.RLock()
						px, py, pz := player.PosX, player.PosY, player.PosZ
						pid := player.ID
						pRace := player.RaceID
						isArmed := player.IsArmed()
						player.Mu.RUnlock()

						if triggered, dist := npc.TryTriggerApproach(pid, px, py, pz); triggered {
							log.Printf("[APROXIMACAO] Jogador %d aproximou-se do NPC '%s' (dist: %.2fm)\n", pid, npc.Name, dist)
							_ = luaengine.CallOnPlayerApproach(npc, pid, dist, pRace, isArmed)
						}
					}
				}
				s.mu.RUnlock()
			}
		}
	}
}

// updateNPCRoutines sincroniza as rotinas autoritativas, zonas e lojas de todos os NPCs conforme a hora do mundo.
func (s *Server) updateNPCRoutines(worldHour int) {
	s.mu.RLock()
	garrick := s.npcs[100]
	lyra := s.npcs[103]
	varis := s.npcs[104]
	seraphina := s.npcs[107]
	aurelius := s.npcs[108]
	kaelen := s.npcs[109]
	ghost := s.npcs[110]
	s.mu.RUnlock()

	// 1. Garrick (100)
	if garrick != nil {
		if worldHour >= 6 && worldHour < 18 {
			garrick.SetZone(world.ZoneVillage)
			garrick.SetShopOpen(true)
			dx := garrick.PosX - 30.0
			dz := garrick.PosZ - 25.0
			if (dx*dx + dz*dz) > 4.0 {
				garrick.SetTarget(30.0, 25.0, 2.4)
			} else {
				garrick.SetState(2) // Trabalhando na Forja
			}
		} else if worldHour >= 18 && worldHour < 24 {
			garrick.SetZone(world.ZoneVillage)
			garrick.SetShopOpen(false)
			dx := garrick.PosX - (-30.0)
			dz := garrick.PosZ - 25.0
			if (dx*dx + dz*dz) > 4.0 {
				garrick.SetTarget(-30.0, 25.0, 2.4)
			} else {
				garrick.SetState(3) // Bebendo na Taverna
			}
		} else { // 00h às 05h59 (Dormir)
			garrick.SetZone(world.ZoneVillage)
			garrick.SetShopOpen(false)
			dx := garrick.PosX - 20.0
			dz := garrick.PosZ - 20.0
			if (dx*dx + dz*dz) > 4.0 {
				garrick.SetTarget(20.0, 20.0, 2.4)
			} else {
				garrick.SetState(0) // Dormindo
			}
		}
	}

	// 2. Lyra (103)
	if lyra != nil && !lyra.LifeBusy() {
		if worldHour >= 6 && worldHour < 18 {
			lyra.SetZone(world.ZoneVillage)
			lyra.SetShopOpen(true)
			dx := lyra.PosX - 30.0
			dz := lyra.PosZ - (-20.0)
			if (dx*dx + dz*dz) > 4.0 {
				lyra.SetTarget(30.0, -20.0, 2.3)
			} else {
				lyra.SetState(2) // No Laboratório
			}
		} else if worldHour >= 18 && worldHour < 24 {
			lyra.SetZone(world.ZoneVillage)
			lyra.SetShopOpen(false)
			dx := lyra.PosX - (-30.0)
			dz := lyra.PosZ - 25.0
			if (dx*dx + dz*dz) > 4.0 {
				lyra.SetTarget(-30.0, 25.0, 2.3)
			} else {
				lyra.SetState(3) // Na Taverna
			}
		} else { // 00h às 05h59 (Dormir)
			lyra.SetZone(world.ZoneVillage)
			lyra.SetShopOpen(false)
			dx := lyra.PosX - 20.0
			dz := lyra.PosZ - (-35.0)
			if (dx*dx + dz*dz) > 4.0 {
				lyra.SetTarget(20.0, -35.0, 2.3)
			} else {
				lyra.SetState(0) // Dormindo
			}
		}
	}

	// 3. Varis (104)
	if varis != nil && !varis.LifeBusy() {
		if worldHour >= 18 || worldHour < 6 {
			varis.SetZone(world.ZoneBlackMarket)
			varis.SetActive(true)
			varis.SetShopOpen(true)
			if varis.PosX != 0.0 || varis.PosZ != 10.0 {
				varis.Teleport(0.0, 0.0, 10.0)
			}
			varis.SetState(2) // Na loja do Mercado Negro
		} else {
			varis.SetZone(world.ZoneVillage)
			varis.SetActive(false)
			varis.SetShopOpen(false)
			varis.Teleport(-50.0, 0.0, 48.0)
			varis.SetState(255) // Oculto
		}
	}

	// 4. Irmã Seraphina (107)
	if seraphina != nil && !seraphina.LifeBusy() {
		if worldHour >= 6 && worldHour < 18 {
			if seraphina.GetZone() != world.ZoneChurch {
				seraphina.SetZone(world.ZoneChurch)
				seraphina.Teleport(0.0, 0.0, 15.0)
				seraphina.SetState(0)
			}
		} else {
			if seraphina.GetZone() != world.ZoneVillage {
				seraphina.SetZone(world.ZoneVillage)
				seraphina.Teleport(-50.0, 0.0, -36.0)
				seraphina.SetState(0)
			}
		}
	}

	// 5. Mestre Aurelius (108)
	if aurelius != nil && !aurelius.LifeBusy() {
		if worldHour >= 6 && worldHour < 18 {
			if aurelius.GetZone() != world.ZoneMageTower {
				aurelius.SetZone(world.ZoneMageTower)
				aurelius.Teleport(0.0, 0.0, 15.0)
				aurelius.SetState(0)
			}
		} else {
			if aurelius.GetZone() != world.ZoneVillage {
				aurelius.SetZone(world.ZoneVillage)
				aurelius.Teleport(50.0, 0.0, -38.0)
				aurelius.SetState(0)
			}
		}
	}

	// 6. Kaelen (109)
	if kaelen != nil && !kaelen.LifeBusy() {
		if !kaelen.IsPatrolling {
			kaelen.SetPatrolRoute([]world.Waypoint{
				{X: 25.0, Z: -95.0},
				{X: 10.0, Z: -160.0},
				{X: 0.0, Z: -260.0},
				{X: 10.0, Z: -160.0},
			}, 2.5, 4.0)
		}
	}

	// 7. Alquimista Esquecido (110)
	if ghost != nil {
		if worldHour >= 0 && worldHour < 4 {
			ghost.SetZone(world.ZoneSewers)
			ghost.SetActive(true)
			if ghost.PosX != -110.0 || ghost.PosZ != 110.0 {
				ghost.Teleport(-110.0, 0.0, 110.0)
			}
			ghost.SetState(0)
		} else {
			ghost.SetActive(false)
			ghost.SetState(255)
		}
	}
}

// checkForgeFireHazard verifica se jogadores colidem com a Fornalha Incandescente do Garrick (30.0, 25.0)
// e aplica 15 de Dano de Fogo autoritativo a cada 0.8s na Vila (ZoneVillage).
func (s *Server) checkForgeFireHazard() {
	forgeX, forgeZ := float32(30.0), float32(25.0)
	radius := float32(2.3)
	radiusSq := radius * radius

	s.mu.RLock()
	players := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		if p.GetZone() == world.ZoneVillage {
			players = append(players, p)
		}
	}
	garrick := s.npcs[100] // Garrick, o Ferreiro (ID 100)
	s.mu.RUnlock()

	for _, p := range players {
		p.Mu.RLock()
		px, pz := p.PosX, p.PosZ
		isAlive := p.HP > 0
		p.Mu.RUnlock()

		if !isAlive || p.GetZone() != world.ZoneVillage {
			continue
		}

		dx := px - forgeX
		dz := pz - forgeZ
		if (dx*dx + dz*dz) <= radiusSq {
			p.Mu.RLock()
			raceID := p.RaceID
			p.Mu.RUnlock()

			if raceID == protocol.RaceAshDragonborn || raceID == protocol.RacePyromancer {
				// Coração de Fornalha / Pyrael: na fornalha do Garrick, cura +20 HP e +20 Stamina/s!
				p.Heal(20)
				p.RestoreStamina(20.0)
				s.sendPlayerStats(p)
				s.BroadcastCombatEvent(p.ID, p.ID, protocol.ActionSpecialSkill, 20, 2, p.HP, p.MaxHP)
				continue
			}

			damageAmt := uint16(15)
			if raceID == protocol.RaceSylvari {
				// Sylvari recebe +35% de dano na fornalha
				damageAmt = uint16(math.Round(15.0 * 1.35))
			}

			newHP, isDead := p.TakeDamage(damageAmt)
			s.BroadcastCombatEvent(999, p.ID, protocol.ActionBasicAttack, damageAmt, 0, newHP, p.MaxHP)
			s.sendPlayerStats(p)

			// Se Garrick estiver perto (<= 20m), grita alerta com cooldown de 5s
			if garrick != nil && garrick.GetActive() {
				gx, _, gz := garrick.GetPos()
				gDistSq := (gx-forgeX)*(gx-forgeX) + (gz-forgeZ)*(gz-forgeZ)
				if gDistSq <= 400.0 {
					s.forgeWarningMu.Lock()
					if time.Since(s.lastForgeWarning) >= 5*time.Second {
						s.lastForgeWarning = time.Now()
						garrick.Say("Cuidado, viajante! Vai acabar se queimando nas brasas da minha forja!")
					}
					s.forgeWarningMu.Unlock()
				}
			}

			if isDead {
				log.Printf("[FOGO DA FORJA] Jogador #%d foi incinerado na fornalha do Garrick e renasce no Centro!\n", p.ID)
				s.RespawnPlayer(p)
			}
		}
	}
}

// handleRacialSkill executa a Habilidade Racial Ativa (ActionType 6 - Tecla Z, cooldown 10s).
func (s *Server) handleRacialSkill(player *world.Player, px, py, pz, aimX, aimZ float32, raceID, pSTR, pDEX, pINT, pSPI, pMAS, pLCK uint8) {
	switch raceID {
	case protocol.RaceValerian, protocol.RaceHighValerian, protocol.RaceAetherWalker:
		// Valeriano / Solvaren / Aetheris:
		// Restaura +40 Stamina, +25 HP e concede buff de ataque por 10s (+25% dano)
		player.RestoreStamina(40.0)
		player.Heal(25)
		player.SetBuff(10 * time.Second)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 25, 0, 0, 0)
		log.Printf("[RACIAL] Valeriano #%d ativou Ímpeto Valeriano (+40 Stamina, +25 HP, +25%% Dano)!\n", player.ID)

	case protocol.RaceUmbralSpecter:
		// Nyxara — Manto de Nyx: invisível por 4s; o primeiro golpe causa dano de emboscada (+120%)
		player.SetInvisible(4*time.Second, true)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Nyxara #%d ativou Manto de Nyx (invisível 4s, emboscada pronta)!\n", player.ID)

	case protocol.RaceNoctari, protocol.RaceLunarArchon:
		// Noctari / Selenarca / Nyxara:
		// Dispara explosão de luz estelar/sombra ao redor (5.5m), alto dano mágico e cura +30 HP
		player.Heal(30)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(45 + int(pINT)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 30, 0, 0, 0)
		log.Printf("[RACIAL] Noctari #%d ativou Explosão Lunar/Umbral (+30 HP, %d dano em 5.5m)!\n", player.ID, dmg)

	case protocol.RaceKharad, protocol.RaceRunicGuardian, protocol.RaceObsidianTitan:
		// Kharad / Runakhar / Pyrokhar:
		// Ativa pele rúnica/erupção de magma causando dano em área de 4.5m e concedendo escudo redutor de dano por 5s
		player.SetParry(5 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 4.5, 400)
		dmg := uint16(50 + int(pSTR)*2 + int(player.CON)*2)
		s.applyRacialAoEDamage(player, px, pz, 4.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Kharad #%d ativou Baluarte Rúnico / Erupção de Magma (Escudo 5s, %d dano em 4.5m)!\n", player.ID, dmg)

	case protocol.RaceVarkai, protocol.RaceDraconicSovereign, protocol.RaceFrenzyBeast:
		// Varkai / Dravarkai / Ferovar:
		// Desfere Sopro Dracônico / Rugido Predatório em área frontal causando dano elevado e ativando roubo de vida
		dmg := uint16(60 + int(pSTR)*3 + int(pDEX)*2)
		hits := s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 5.5, 0.25, dmg)
		if hits > 0 {
			lifesteal := uint16(hits) * 20
			player.Heal(lifesteal)
			log.Printf("[RACIAL] Varkai #%d acertou %d alvos e roubou +%d HP!\n", player.ID, hits, lifesteal)
		}
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Varkai #%d desferiu Sopro Dracônico/Rugido Predatório em cone (%d dano)!\n", player.ID, dmg)

	case protocol.RaceDhampir:
		// Sangrael: Roubo de vida e dreno em área (5m)
		player.Heal(60)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		dmg := uint16(55 + int(pINT)*2 + int(pDEX)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 60, 0, 0, 0)
		log.Printf("[RACIAL] Sangrael #%d ativou Dreno Vampírico (+60 HP, %d dano)!\n", player.ID, dmg)

	case protocol.RacePrimordialLycanthrope:
		// Lupharion: Rugido/Garras Alfas no Z (cone frontal, alto dano + lifesteal)
		dmg := uint16(75 + int(pSTR)*3 + int(player.CON)*2)
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.5, 300)
		hits := s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 6.5, 0.20, dmg)
		if hits > 0 {
			player.Heal(uint16(hits) * 35)
		}
		player.SetBuff(10 * time.Second)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Lupharion #%d ativou Garras Alfas (%d dano)!\n", player.ID, dmg)

	case protocol.RaceRevenant:
		// Cinerion: Chama Fátua espiritual (5.5m), dano espiritual e cura +50 HP
		player.Heal(50)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(50 + int(pINT)*2 + int(pSPI)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 50, 0, 0, 0)
		log.Printf("[RACIAL] Cinerion #%d ativou Chama Fátua (+50 HP, %d dano)!\n", player.ID, dmg)

	case protocol.RaceCelestial:
		// Seraphel: Julgamento da Aurora: cura aliados + dano solar no Z (raio 6m)
		player.Heal(50)
		s.healNearbyAllies(player.ID, px, pz, 6.0, 50)
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 300)
		dmg := uint16(55 + int(pSPI)*3 + int(pINT)*2)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 50, 0, 0, 0)
		log.Printf("[RACIAL] Seraphel #%d ativou Julgamento da Aurora (Cura aliados +50, %d dano solar)!\n", player.ID, dmg)

	case protocol.RaceAbyssal:
		// Umbryss: Singularidade: puxa inimigos em 6m e causa dano de vazio no Z
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 400)
		s.pullMobsToward(player.GetZone(), px, pz, 6.0, 0.35)
		dmg := uint16(60 + int(pINT)*4)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Umbryss #%d ativou Singularidade (Puxão 6m, %d dano de vazio)!\n", player.ID, dmg)

	case protocol.RaceRunicAutomaton:
		// Runaric: Sobrecarga de Laser Rúnico no Z (feixe/cone 10m)
		dmg := uint16(70 + int(pSTR)*3 + int(pMAS)*3)
		s.BroadcastAOETelegraph(player.ID, px, pz, 10.0, 350)
		s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 10.0, 0.65, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Runaric #%d ativou Laser Rúnico (%d dano)!\n", player.ID, dmg)

	case protocol.RaceSylvari:
		// 19 Sylvari: Prisão da Floresta: enraíza Mobs em 5m por 3s e cura +40 HP
		player.Heal(40)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		s.applyRacialCrowdControl(player.GetZone(), px, pz, 5.0, 3*time.Second, 0, 1.0)
		dmg := uint16(35 + int(pSPI)*2 + int(pINT)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 40, 0, 0, 0)
		log.Printf("[RACIAL] Sylvari #%d ativou Prisão da Floresta (Enraíza 3s em 5m, +40 HP)!\n", player.ID)

	case protocol.RaceMyconid:
		// 20 Myconid: Nuvem de Esporos: veneno em área de 6m e reduz velocidade dos Mobs em 50%
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 300)
		s.applyRacialCrowdControl(player.GetZone(), px, pz, 6.0, 0, 5*time.Second, 0.5)
		dmg := uint16(45 + int(pINT)*3)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Myconid #%d ativou Nuvem de Esporos (Veneno 6m, Lentidão 50%%)!\n", player.ID)

	case protocol.RaceArachne:
		// 21 Aracne: Disparo de Seda: alto dano crítico à distância (14m) e paralisa o alvo (3s)
		dmg := uint16(80 + int(pDEX)*4 + int(pMAS)*3)
		s.applyRacialSingleTargetSnipe(player, px, pz, aimX, aimZ, 14.0, dmg, 3*time.Second)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Aracne #%d ativou Disparo de Seda (Snipe 14m, Paralisia 3s, %d dano)!\n", player.ID, dmg)

	case protocol.RaceAshDragonborn:
		// 22 Ignivarn: Cataclismo Dracônico: cone de magma de 8m com dano massivo
		dmg := uint16(90 + int(pSTR)*4 + int(player.CON)*2)
		s.BroadcastAOETelegraph(player.ID, px, pz, 8.0, 400)
		s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 8.0, 0.25, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Ignivarn #%d ativou Cataclismo Dracônico (Cone 8m, %d dano de magma)!\n", player.ID, dmg)

	case protocol.RaceChimera:
		// 23 Chimeryth: Sobrecarga Anatômica: cura +50 HP, ativa buff completo por 15s e causa explosão ácida em 5m
		player.Heal(50)
		player.SetBuff(15 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		dmg := uint16(55 + int(pSTR)*2 + int(pDEX)*2 + int(player.CON)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 50, 0, 0, 0)
		log.Printf("[RACIAL] Chimeryth #%d ativou Sobrecarga Anatômica (+50 HP, Buff 15s, %d dano ácido)!\n", player.ID, dmg)

	case protocol.RaceBoreal:
		// 24 Borealin: Zero Absoluto: congela todos os Mobs em 5m por 2.5s e causa dano criogênico
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		s.applyRacialCrowdControl(player.GetZone(), px, pz, 5.0, 2500*time.Millisecond, 0, 1.0)
		dmg := uint16(50 + int(pINT)*3 + int(pSPI)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Borealin #%d ativou Zero Absoluto (Congela 2.5s em 5m, %d dano)!\n", player.ID, dmg)

	case protocol.RaceThalassian:
		// 25 Thalassiano: Gêiser Abissal: explosão de água pressurizada em área (5.5m)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(55 + int(pINT)*3 + int(pDEX)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Thalassiano #%d ativou Gêiser Abissal (%d dano em 5.5m)!\n", player.ID, dmg)

	case protocol.RaceCambion:
		// 26 Cambion: Correntes do Tártaro: puxa os Mobs em 6m para perto e explode fogo infernal
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 350)
		s.pullMobsToward(player.GetZone(), px, pz, 6.0, 0.4)
		dmg := uint16(65 + int(pSTR)*3 + int(pINT)*2)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Cambion #%d ativou Correntes do Tártaro (Puxão 6m, %d fogo infernal)!\n", player.ID, dmg)

	case protocol.RaceNephilim:
		// 27 Nephilim: Julgamento do Eclipse Solar: cura +60 HP de todos os aliados em 7m e causa alto dano nos inimigos
		player.Heal(60)
		s.healNearbyAllies(player.ID, px, pz, 7.0, 60)
		s.BroadcastAOETelegraph(player.ID, px, pz, 7.0, 350)
		dmg := uint16(65 + int(pINT)*3 + int(pSPI)*3)
		s.applyRacialAoEDamage(player, px, pz, 7.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 60, 0, 0, 0)
		log.Printf("[RACIAL] Nephilim #%d ativou Julgamento do Eclipse Solar (+60 cura grupo 7m, %d dano)!\n", player.ID, dmg)

	case protocol.RaceTimeWanderer:
		// 28 Cronari: Rebobinar o Destino: restaura HP/Stamina de 3s atrás (ou +80) e dispara onda temporal
		snap, restored := player.RewindTimeDestiny()
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 200)
		dmg := uint16(60 + int(pINT)*3 + int(pDEX)*2)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 80, 0, 0, 0)
		log.Printf("[RACIAL] Cronari #%d ativou Rebobinar o Destino (Restaurado: %v, Pos: %.1f,%.1f, HP: %d, %d dano)!\n",
			player.ID, restored, snap.PosX, snap.PosZ, snap.HP, dmg)

	// Quadrante 5: 18 Novas Raças do RPG (29 a 46)
	case protocol.RaceHalfCelestial: // 29 Aurelith
		// Asas de Luz: Voa a 1.5m do solo por 10s, curando +40 HP, restaurando stamina e +30% velocidade
		player.Heal(40)
		player.RestoreStamina(50.0)
		player.SetBuff(10 * time.Second)
		s.healNearbyAllies(player.ID, px, pz, 6.0, 40)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		dmg := uint16(55 + int(pSPI)*4 + int(pINT)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 40, 0, 0, 0)
		log.Printf("[RACIAL] Aurelith #%d ativou Asas de Luz (+40 HP, +50 Stamina, Buff 10s, %d dano solar)!\n", player.ID, dmg)

	case protocol.RacePyromancer: // 30 Pyrael
		// Combustão: Consome 25% do HP atual para dobrar o Dano Físico e Mágico por 10s!
		player.Mu.Lock()
		cost := player.HP / 4
		if cost < 1 {
			cost = 1
		}
		if player.HP > cost {
			player.HP -= cost
		} else {
			player.HP = 1
		}
		player.Mu.Unlock()
		player.SetBuff(10 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(70 + int(pINT)*4)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Pyrael #%d ativou Combustão (Consumiu %d HP, Buff Dano Dobrado 10s, %d dano de fogo)!\n", player.ID, cost, dmg)

	case protocol.RaceFrostGiant: // 31 Jotunar
		// Memória Molecular: Materializa arma de gelo gigante e golpeia em área congelando inimigos em 5.5m
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 350)
		s.applyRacialCrowdControl(player.GetZone(), px, pz, 5.5, 3*time.Second, 5*time.Second, 0.4)
		pCON := player.CON
		dmg := uint16(75 + int(pSTR)*3 + int(pCON)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Jotunar #%d ativou Memória Molecular (Congela 3s em 5.5m, %d dano glacial)!\n", player.ID, dmg)

	case protocol.RaceDragonEarth: // 32 Terravyrn
		// Insulto Sísmico: Provoca (Taunt) todos os Mobs em 18m e ganha escudo de +80 HP
		player.Heal(80)
		player.SetParry(6 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 18.0, 300)
		s.tauntMobsNearby(player.GetZone(), px, pz, 18.0, player.ID)
		pCON := player.CON
		dmg := uint16(50 + int(pSTR)*2 + int(pCON)*3)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 80, 0, 0, 0)
		log.Printf("[RACIAL] Terravyrn #%d ativou Insulto Sísmico (Taunt 18m, Escudo +80 HP, %d dano sísmico)!\n", player.ID, dmg)

	case protocol.RaceDragonWater: // 33 Hydravyrn
		// Bênção de Netuno: Cura +55 HP e dispara onda de pressão aquática
		player.Heal(55)
		player.RestoreStamina(40.0)
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.5, 300)
		dmg := uint16(60 + int(pINT)*3 + int(pDEX)*2)
		s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 7.5, 0.25, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 55, 0, 0, 0)
		log.Printf("[RACIAL] Hydravyrn #%d ativou Bênção de Netuno (+55 HP, Onda frontal 7.5m, %d dano)!\n", player.ID, dmg)

	case protocol.RaceDragonLightning: // 34 Fulgravyrn
		// Descarga Elétrica: Dispara raio a 14m causando alto dano (bônus contra alvos de ferro)
		dmg := uint16(85 + int(pINT)*4 + int(pDEX)*3)
		s.applyRacialSingleTargetSnipe(player, px, pz, aimX, aimZ, 14.0, dmg, 2*time.Second)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Fulgravyrn #%d ativou Descarga Elétrica (Raio 14m, %d dano de choque)!\n", player.ID, dmg)

	case protocol.RaceDragonMystic: // 35 Arcavyrn
		// Infusão Arcana: Pulso místico que restaura HP/Stamina e explode runas ao redor
		player.Heal(50)
		player.RestoreStamina(50.0)
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 300)
		dmg := uint16(65 + int(pINT)*4 + int(pSPI)*2)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 50, 0, 0, 0)
		log.Printf("[RACIAL] Arcavyrn #%d ativou Infusão Arcana (+50 HP/Stam, %d dano rúnico 6m)!\n", player.ID, dmg)

	case protocol.RaceOrc: // 36 Orkhan
		// Ataque Devastador: Golpe brutal que causa 2.4x dano corpo a corpo e regenera vida se ferido
		pCON := player.CON
		dmg := uint16(90 + int(pSTR)*4 + int(pCON)*2)
		hits := s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 5.0, 0.30, dmg)
		if hits > 0 && player.HP < player.MaxHP {
			player.Heal(40 * uint16(hits))
		}
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Orkhan #%d ativou Ataque Devastador (Cone 5m, %d dano brutal)!\n", player.ID, dmg)

	case protocol.RaceDwarf: // 37 Dvergar
		// Martelo Ancestral: Bate no chão fortalecendo a defesa e reparando equipamento
		player.SetParry(5 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 350)
		dmg := uint16(60 + int(pSTR)*3 + int(pMAS)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Dvergar #%d ativou Martelo Ancestral (Escudo 5s, %d dano de terra 5m)!\n", player.ID, dmg)

	case protocol.RaceElf: // 38 Elarin
		// Disparo/Feitiço Élfico: Dispara flecha de mana luminosa de longo alcance
		dmg := uint16(80 + int(pDEX)*4 + int(pINT)*3)
		s.applyRacialSingleTargetSnipe(player, px, pz, aimX, aimZ, 16.0, dmg, 1500*time.Millisecond)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Elarin #%d ativou Disparo Élfico (Flecha 16m, %d dano luminoso)!\n", player.ID, dmg)

	case protocol.RaceSolarElf: // 39 Solarin (Azgher)
		// Espada Solar de Azgher: Encanta a arma com fogo solar sagrado causando explosão ígnea e buff de ataque
		player.SetBuff(12 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(65 + int(pINT)*3 + int(pSPI)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Solarin #%d ativou Espada Solar de Azgher (Buff 12s, %d dano solar 5.5m)!\n", player.ID, dmg)

	case protocol.RaceLunarElf: // 40 Lunarin (Tenebra)
		// Manto de Tenebra: Envolve a área em escuridão lunar causando dano sombrio e ficando furtivo
		player.SetDodgeIFrame(2 * time.Second)
		player.SetStealth(4 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(60 + int(pINT)*3 + int(pDEX)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Lunarin #%d ativou Manto de Tenebra (Furtivo 2s, %d dano lunar 5.5m)!\n", player.ID, dmg)

	case protocol.RaceFairy: // 41 Faelith
		// Pó de Fada Estelar: Cura +60 HP dos aliados próximos e encanta inimigos
		player.Heal(60)
		player.RestoreStamina(40.0)
		s.healNearbyAllies(player.ID, px, pz, 7.5, 60)
		s.BroadcastAOETelegraph(player.ID, px, pz, 7.5, 300)
		s.applyRacialCrowdControl(player.GetZone(), px, pz, 7.5, 2*time.Second, 4*time.Second, 0.5)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 60, 0, 0, 0)
		log.Printf("[RACIAL] Faelith #%d ativou Pó de Fada Estelar (+60 HP grupo 7.5m, Encanto 2s)!\n", player.ID)

	case protocol.RaceGoblin: // 42 Gnarlin
		// Truque Sujo Gnarlin: Joga bomba de fumaça/explosivo recuando rapidamente
		player.SetDodgeIFrame(1500 * time.Millisecond)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 250)
		s.applyRacialCrowdControl(player.GetZone(), px, pz, 5.0, 1*time.Second, 4*time.Second, 0.3)
		dmg := uint16(55 + int(pDEX)*3 + int(pLCK)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Gnarlin #%d ativou Truque Sujo (Bomba 5m, %d dano, Lentidão 70%%)!\n", player.ID, dmg)

	case protocol.RaceScorpionDemi: // 43 Escarion
		// Aguilhão de Toxina Vorpal: Golpeia com a cauda aplicando veneno letal cumulativo e nuvem ácida
		dmg := uint16(80 + int(pDEX)*3 + int(pMAS)*4)
		s.BroadcastAOETelegraph(player.ID, px, pz, 4.5, 250)
		hits := s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 4.5, 0.35, dmg)
		s.applyRacialCrowdControl(player.GetZone(), px, pz, 4.5, 0, 5*time.Second, 0.6)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Escarion #%d ativou Aguilhão de Toxina Vorpal (%d acertos, %d dano tóxico)!\n", player.ID, hits, dmg)

	case protocol.RaceTurtleDemi: // 44 Testudar
		// Lar Doce Casca: Recolhe-se no casco por 4s, reduzindo o dano em 70% e curando +25 HP por segundo (total +100 HP)
		player.SetParry(4 * time.Second)
		player.Heal(100)
		s.BroadcastAOETelegraph(player.ID, px, pz, 4.0, 400)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 100, 0, 0, 0)
		log.Printf("[RACIAL] Testudar #%d ativou Lar Doce Casca (Escudo 70%% por 4s, +100 HP)!\n", player.ID)

	case protocol.RaceHalfDemon: // 45 Lilitara
		// Drenar Força Vital: Seduz o alvo a até 10m e rouba grande quantidade de HP e Stamina dele para você!
		dmg := uint16(75 + int(pINT)*4 + int(pDEX)*2)
		s.applyRacialSingleTargetSnipe(player, px, pz, aimX, aimZ, 10.0, dmg, 2*time.Second)
		player.Heal(60)
		player.RestoreStamina(50.0)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 60, 0, 0, 0)
		log.Printf("[RACIAL] Lilitara #%d ativou Drenar Força Vital (Roubou +60 HP e +50 Stamina, %d dano)!\n", player.ID, dmg)

	case protocol.RaceWolfDemi: // 46 Ulvar
		// Despertar Forma Bestial (Alfa/Beta/Ômega): Transforma-se na Forma Bestial Lupina ganhando +35% de Velocidade, Força e ataques duplos de mordida
		player.SetBuff(15 * time.Second)
		player.Heal(45)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		pAGI := player.AGI
		dmg := uint16(75 + int(pSTR)*3 + int(pAGI)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 45, 0, 0, 0)
		log.Printf("[RACIAL] Ulvar #%d ativou Despertar Forma Bestial (+45 HP, Buff 15s, %d dano)!\n", player.ID, dmg)

	case protocol.RaceManamancer: // 47 Manamante
		// Coração de Mana: queima 15% da Vida máxima numa explosão arcana de 7m (falha se a Vida não cobrir o custo)
		if !player.SpendHPPercent(0.15) {
			return
		}
		s.BroadcastAOETelegraph(player.ID, px, pz, 7.0, 400)
		dmg := uint16(90 + int(pINT)*6)
		s.applyRacialAoEDamage(player, px, pz, 7.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Manamante #%d ativou Coração de Mana (-15%% Vida, %d dano arcano em 7m)!\n", player.ID, dmg)
	}
}

// pullMobsToward puxa mobs em volta para mais próximo do jogador na mesma zona.
func (s *Server) pullMobsToward(playerZone uint8, px, pz, radius, factor float32) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.mobManager == nil {
		return
	}
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive || mob.GetZone() != playerZone {
			continue
		}
		mob.Mu.Lock()
		mx, mz := mob.PosX, mob.PosZ
		dx := mx - px
		dz := mz - pz
		dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
		if dist <= radius && dist > 0.05 {
			mob.PosX = px + dx*factor
			mob.PosZ = pz + dz*factor
		}
		mob.Mu.Unlock()
	}
}

// applyRacialCrowdControl aplica atordoamento/lentidão em área para habilidades raciais na mesma zona.
func (s *Server) applyRacialCrowdControl(playerZone uint8, px, pz, radius float32, stunDuration, slowDuration time.Duration, slowFactor float32) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.mobManager == nil {
		return
	}
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive || mob.GetZone() != playerZone {
			continue
		}
		mob.Mu.RLock()
		mx, mz := mob.PosX, mob.PosZ
		mob.Mu.RUnlock()
		dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
		if dist <= radius {
			if stunDuration > 0 {
				mob.ApplyStun(stunDuration)
			}
			if slowDuration > 0 {
				mob.ApplySlow(slowDuration, slowFactor)
			}
		}
	}
}

// tauntMobsNearby força todos os mobs no raio informado a focar o jogador atacante.
func (s *Server) tauntMobsNearby(playerZone uint8, px, pz, radius float32, playerID uint32) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.mobManager == nil {
		return
	}
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive || mob.GetZone() != playerZone {
			continue
		}
		mob.Mu.Lock()
		mx, mz := mob.PosX, mob.PosZ
		dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
		if dist <= radius {
			mob.TargetPlayerID = playerID
			mob.State = protocol.MobStateChasing
		}
		mob.Mu.Unlock()
	}
}

// healNearbyAllies cura aliados próximos dentro do raio informado na mesma zona.
func (s *Server) healNearbyAllies(playerID uint32, px, pz, radius float32, amount uint16) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var pZone uint8
	if p, ok := s.players[playerID]; ok {
		pZone = p.GetZone()
	}
	for _, ally := range s.players {
		if ally.GetZone() != pZone {
			continue
		}
		ally.Mu.RLock()
		ax, az := ally.PosX, ally.PosZ
		ally.Mu.RUnlock()
		dist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
		if dist <= radius {
			ally.Heal(amount)
			s.sendPlayerStats(ally)
		}
	}
}

// applyRacialSingleTargetSnipe dispara um projétil de longo alcance contra o mob mirado na mesma zona.
func (s *Server) applyRacialSingleTargetSnipe(player *world.Player, px, pz, aimX, aimZ, maxRange float32, damage uint16, stunDuration time.Duration) {
	s.mu.RLock()
	var hitMob *world.Mob
	var minDist float32 = maxRange + 1.0
	pZone := player.GetZone()
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive || mob.GetZone() != pZone {
				continue
			}
			mob.Mu.RLock()
			mx, mz := mob.PosX, mob.PosZ
			mob.Mu.RUnlock()
			dx := mx - px
			dz := mz - pz
			dist := float32(math.Sqrt(float64(dx*dx + dz*dz)))
			if dist <= maxRange && dist > 0.05 {
				dot := (dx/dist)*aimX + (dz/dist)*aimZ
				if dot >= 0.70 && dist < minDist {
					minDist = dist
					hitMob = mob
				}
			}
		}
	}
	s.mu.RUnlock()

	if hitMob != nil {
		hitMob.ApplyStun(stunDuration)
		_, _, newHP, dead := hitMob.TakeDamage(damage, player.ID)
		if dead {
			s.handleMobDeath(hitMob, player.ID)
		} else {
			s.BroadcastCombatEvent(player.ID, hitMob.ID, protocol.ActionRacialSkill, damage, 1, 0, newHP)
		}
	}
}

// applyRacialAoEDamage aplica dano radial em alvos no raio especificado na mesma zona.
func (s *Server) applyRacialAoEDamage(player *world.Player, px, pz, radius float32, damage uint16) {
	s.mu.RLock()
	pZone := player.GetZone()
	for _, dummy := range s.dummies {
		if dummy.GetZone() != pZone {
			continue
		}
		dx, _, dz := dummy.GetPos()
		dist := float32(math.Sqrt(float64((dx-px)*(dx-px) + (dz-pz)*(dz-pz))))
		if dist <= radius {
			dummy.TakeDamage(damage)
		}
	}
	var hitMobs []*world.Mob
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive || mob.GetZone() != pZone {
				continue
			}
			mob.Mu.RLock()
			mx, mz := mob.PosX, mob.PosZ
			mob.Mu.RUnlock()
			dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
			if dist <= radius {
				hitMobs = append(hitMobs, mob)
			}
		}
	}
	s.mu.RUnlock()

	for _, mob := range hitMobs {
		_, _, newHP, dead := mob.TakeDamage(damage, player.ID)
		if dead {
			s.handleMobDeath(mob, player.ID)
		} else {
			s.BroadcastCombatEvent(player.ID, mob.ID, protocol.ActionRacialSkill, damage, 0, 0, newHP)
		}
	}
}

// applyRacialConeDamage aplica dano frontal cônico e retorna a quantidade de acertos para lifesteal na mesma zona.
func (s *Server) applyRacialConeDamage(player *world.Player, px, pz, aimX, aimZ, radius, minDot float32, damage uint16) int {
	s.mu.RLock()
	pZone := player.GetZone()
	for _, dummy := range s.dummies {
		if dummy.GetZone() != pZone {
			continue
		}
		dx, _, dz := dummy.GetPos()
		distX := dx - px
		distZ := dz - pz
		dist := float32(math.Sqrt(float64(distX*distX + distZ*distZ)))
		if dist <= radius && dist > 0.01 {
			dot := (distX/dist)*aimX + (distZ/dist)*aimZ
			if dot >= minDot {
				dummy.TakeDamage(damage)
			}
		}
	}

	var hitMobs []*world.Mob
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive || mob.GetZone() != pZone {
				continue
			}
			mob.Mu.RLock()
			mx, mz := mob.PosX, mob.PosZ
			mob.Mu.RUnlock()
			distX := mx - px
			distZ := mz - pz
			dist := float32(math.Sqrt(float64(distX*distX + distZ*distZ)))
			if dist <= radius && dist > 0.01 {
				dot := (distX/dist)*aimX + (distZ/dist)*aimZ
				if dot >= minDot {
					hitMobs = append(hitMobs, mob)
				}
			}
		}
	}
	s.mu.RUnlock()

	hits := len(hitMobs)
	for _, mob := range hitMobs {
		_, _, newHP, dead := mob.TakeDamage(damage, player.ID)
		if dead {
			s.handleMobDeath(mob, player.ID)
		} else {
			s.BroadcastCombatEvent(player.ID, mob.ID, protocol.ActionRacialSkill, damage, 0, 0, newHP)
		}
	}
	return hits
}

// sendEvolutionOffer transmite o pacote 0x40 EVOLUTION_OFFER via TCP para o cliente.
// offerLegendaryClass oferece a Classe Lendária destinada à Classe Única do jogador (Provação concluída).
// A troca reseta o nível e só acontece quando o jogador confirma no modal.
func (s *Server) offerLegendaryClass(player *world.Player) {
	player.Mu.RLock()
	race, current := player.RaceID, player.ClassID
	player.Mu.RUnlock()
	legendary := world.LegendaryOffer(current)
	s.offerIdentityChange(player, race, legendary, protocol.IdentityModeSecretReset)
	s.BroadcastNPCSay(0, fmt.Sprintf("[DESPERTAR LENDÁRIO] O Campeão #%d concluiu a Provação Lendária! A Classe Lendária %d o aguarda (Tier 6)!", player.ID, legendary))
}

// offerIdentityChange oferece uma troca de Classe/Raça ao jogador. Nada muda até ele confirmar no modal
// do cliente (que responde com EVOLUTION_OFFER tipo 4); cancelar mantém tudo como está.
func (s *Server) offerIdentityChange(player *world.Player, raceID, classID, mode uint8) {
	player.OfferIdentity(raceID, classID, mode)
	s.sendEvolutionOffer(player, protocol.OfferTypeIdentityChange, classID, raceID)
	log.Printf("[IDENTIDADE] Oferecida ao jogador #%d: Raça %d, Classe %d (Modo %d) — aguardando confirmação\n", player.ID, raceID, classID, mode)
}

func (s *Server) sendEvolutionOffer(player *world.Player, offerType, optA, optB uint8) {
	player.Mu.RLock()
	conn := player.TCPConn
	pid := player.ID
	player.Mu.RUnlock()

	if conn == nil {
		return
	}

	pkt := protocol.SerializeEvolutionOffer(offerType, optA, optB)
	if _, err := conn.Write(pkt[:]); err != nil {
		log.Printf("[EVOLUCAO] Falha ao enviar EVOLUTION_OFFER (tipo %d) para jogador #%d: %v\n", offerType, pid, err)
	} else {
		log.Printf("[EVOLUCAO] EVOLUTION_OFFER enviado para jogador #%d: Tipo %d, OpA %d, OpB %d\n",
			pid, offerType, optA, optB)
	}
}

// checkProgressionMilestones avalia marcos de nível e missões para disparar ofertas de evolução (0x40).
func (s *Server) checkProgressionMilestones(player *world.Player) {
	player.Mu.RLock()
	lvl := player.Level
	raceID := player.RaceID
	classID := player.ClassID
	classTier := player.ClassTier
	raceEvolved := player.RaceEvolved
	questActive := player.LegendaryQuestActive
	questKills := player.LegendaryQuestKills
	player.Mu.RUnlock()

	// 1. Oferta de Evolução Racial (Nível 10+ e Raça Base 1, 2, 3, 4)
	if lvl >= 10 && !raceEvolved {
		var optA, optB uint8
		switch raceID {
		case protocol.RaceValerian:
			optA, optB = protocol.RaceHighValerian, protocol.RaceAetherWalker // 11 vs 12
		case protocol.RaceNoctari:
			optA, optB = protocol.RaceLunarArchon, protocol.RaceUmbralSpecter // 21 vs 22
		case protocol.RaceKharad:
			optA, optB = protocol.RaceRunicGuardian, protocol.RaceObsidianTitan // 31 vs 32
		case protocol.RaceVarkai:
			optA, optB = protocol.RaceDraconicSovereign, protocol.RaceFrenzyBeast // 41 vs 42
		}

		if optA > 0 {
			s.sendEvolutionOffer(player, protocol.OfferTypeRace, optA, optB)
			s.BroadcastNPCSay(0, fmt.Sprintf("[ENTIDADE CÓSMICA] Viajante #%d atingiu o Nível %d! A Oferta de Evolução Racial foi liberada!", player.ID, lvl))
			return
		}
	}

	// 2. Escolha do Caminho Evolutivo das Classes Básicas. O Tier sobe sozinho nos níveis 10, 25 e 45
	// (checkLevelMilestoneTierEvolutionLocked); a cada novo Tier o jogador escolhe (ou troca) 1 dos 4
	// Caminhos. A oferta (A=1, B=4) pede a escolha entre os Caminhos 1 a 4.
	if player.NeedsPathChoice() {
		s.sendEvolutionOffer(player, protocol.OfferTypeBasicClass, 1, 4)
		s.BroadcastNPCSay(0, fmt.Sprintf("[MESTRE DA GUILDA] O aventureiro #%d alcançou o Tier %d! Escolha 1 dos 4 Caminhos Evolutivos da sua classe.", player.ID, classTier))
		return
	}

	// 3. Provação Lendária para Classes Únicas (Tier 5 no Nível 45+): ao concluir, oferece a Classe Lendária
	if protocol.IsUniqueClass(classID) && lvl >= 45 {
		if !questActive {
			player.Mu.Lock()
			player.LegendaryQuestActive = true
			player.LegendaryQuestKills = 0
			player.Mu.Unlock()
			s.BroadcastNPCSay(0, fmt.Sprintf("[PROVAÇÃO LENDÁRIA] O Campeão Único #%d atingiu o Nível 45! Para ascender ao Tier 6 Lendário, abata 3 Mobs de Elite/Boss sem morrer!", player.ID))
		} else if questKills >= 3 {
			s.offerLegendaryClass(player)
		}
	}
}

// handleEvolutionChoice processa a decisão do jogador sobre ofertas de evolução de raça, classe ou provação lendária.
func (s *Server) handleEvolutionChoice(playerID uint32, pkt protocol.EvolutionOfferPacket) {
	s.mu.RLock()
	player, exists := s.players[playerID]
	s.mu.RUnlock()

	if !exists {
		return
	}

	switch pkt.OfferType {
	case protocol.OfferTypeRace: // 1: Evolução Racial
		chosenRace := pkt.OptionAID
		if chosenRace == 0 {
			chosenRace = pkt.OptionBID
		}
		if chosenRace >= 11 {
			player.Mu.Lock()
			player.RaceID = chosenRace
			player.RaceEvolved = true
			player.ApplyBaseRaceAttributes(chosenRace)
			player.Mu.Unlock()
			player.RecalculateStats()

			s.sendPlayerStats(player)
			s.BroadcastNPCSay(0, fmt.Sprintf("[EVOLUÇÃO RACIAL] O jogador #%d aceitou a oferenda e transcendeu para a Raça %d!", playerID, chosenRace))
			log.Printf("[EVOLUÇÃO RACIAL] Jogador #%d evoluiu para Raça %d!\n", playerID, chosenRace)
		}

	case protocol.OfferTypeBasicClass: // 2: Escolha do Caminho Evolutivo (1 a 4) das Classes Básicas
		chosenPath := pkt.OptionAID
		if chosenPath < 1 || chosenPath > 4 || !player.NeedsPathChoice() {
			log.Printf("[CAMINHO] Jogador #%d escolheu o Caminho %d sem poder escolher (ou inválido) — ignorado\n", playerID, chosenPath)
			return
		}
		player.ChoosePath(chosenPath)

		s.sendPlayerStats(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[CAMINHO EVOLUTIVO] O aventureiro #%d seguiu o Caminho %d (Tier %d)!", playerID, chosenPath, player.ClassTier))
		log.Printf("[CAMINHO] Jogador #%d escolheu o Caminho %d no Tier %d\n", playerID, chosenPath, player.ClassTier)

	case protocol.OfferTypeIdentityChange: // 4: Troca de Classe/Raça confirmada no modal do cliente
		if !player.AcceptIdentityOffer(pkt.OptionAID) { // consome o item de custo da oferta, se houver
			log.Printf("[IDENTIDADE] Jogador #%d confirmou %d sem oferta válida (expirada ou diferente) — ignorado\n", playerID, pkt.OptionAID)
			return
		}
		s.sendPlayerStats(player)
		s.sendInventorySync(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[IDENTIDADE] O jogador #%d confirmou a mudança: agora é Classe %d (Tier %d), Raça %d!", playerID, player.ClassID, player.ClassTier, player.RaceID))
		log.Printf("[IDENTIDADE] Jogador #%d confirmou a troca: Raça %d, Classe %d, Tier %d, Nível %d\n", playerID, player.RaceID, player.ClassID, player.ClassTier, player.Level)

	case protocol.OfferTypeLegendaryTrial: // 3: pedido de Ascensão Lendária (vale só com a Provação concluída)
		player.Mu.RLock()
		eligible := protocol.IsUniqueClass(player.ClassID) && player.Level >= 45 && player.LegendaryQuestActive && player.LegendaryQuestKills >= 3
		player.Mu.RUnlock()
		if !eligible {
			log.Printf("[PROVAÇÃO LENDÁRIA] Jogador #%d pediu a Ascensão sem concluir a Provação — ignorado\n", playerID)
			return
		}
		s.offerLegendaryClass(player)
	}
}
