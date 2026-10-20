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
	mu           sync.RWMutex
	players      map[uint32]*world.Player
	npcs         map[uint32]*world.NPC
	dummies      map[uint32]*world.TrainingDummy
	mobManager    *world.MobManager
	projManager   *world.ProjectileManager
	corpseManager *world.CorpseManager
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
	combatScript := filepath.Join(combatDir, "combat.lua")
	mobsScript := filepath.Join(mobsDir, "mobs_ai.lua")

	currentH := s.clock.GetCurrentHour()

	// 1. Garrick, o Ferreiro (ID 100)
	// Dia (06h-17h): Forja na Rua Nordeste (10.0, 9.0). Noite (18h-05h): Taverna na Rua Noroeste (-14.0, 9.5)
	garrickX, garrickZ := float32(10.0), float32(9.0)
	if currentH >= 18 || currentH < 6 {
		garrickX, garrickZ = -14.0, 9.5
	}
	garrick := world.NewNPC(
		100,
		"Garrick, o Ferreiro",
		garrickX, 0.0, garrickZ,
		garrickScript,
		s.clock,
		s.BroadcastNPCSay,
	)

	// 2. Lyra, a Alquimista (ID 103)
	// Dia (07h às 18h): Laboratório de Alquimia a Sudeste (10.0, 0.0, -6.5)
	// Noite (19h às 06h): Casa Residencial em (14.0, 0.0, -20.5)
	lyraX, lyraZ := float32(10.0), float32(-6.5)
	if currentH >= 19 || currentH < 7 {
		lyraX, lyraZ = 14.0, -20.5
	}
	lyra := world.NewNPC(
		103,
		"Lyra, a Alquimista",
		lyraX, 0.0, lyraZ,
		lyraScript,
		s.clock,
		s.BroadcastNPCSay,
	)

	// 3. Varis, o Contrabandista (ID 104)
	// Ativo à noite (18h às 05h): Beco Escuro / Entrada dos Esgotos atrás da Taverna em (-19.0, 0.0, 17.0).
	// De dia (06h às 17h): Escondido nos Esgotos em (-22.0, 0.0, -22.0), inativo.
	varisX, varisZ := float32(-19.0), float32(17.0)
	varis := world.NewNPC(
		104,
		"Varis, o Contrabandista",
		varisX, 0.0, varisZ,
		shadowMerchantScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	if currentH >= 6 && currentH < 18 {
		varis.Teleport(-22.0, 0.0, -22.0)
		varis.SetActive(false)
	}

	// 4. Capitão Randel (ID 105)
	// Patrulha contínua da Avenida Norte-Sul: Portão Norte (0.0, 24.0) <-> Praça Central (0.0, 3.0) <-> Portão Sul (0.0, -24.0) com MoveSpeed = 2.8
	guard1 := world.NewNPC(
		105,
		"Capitão Randel",
		0.0, 0.0, 24.0,
		guardScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	guard1.SetPatrolRoute([]world.Waypoint{
		{X: 0.0, Z: 24.0},  // Portão Norte
		{X: 0.0, Z: 3.0},   // Praça Central
		{X: 0.0, Z: -24.0}, // Portão Sul
		{X: 0.0, Z: 3.0},   // Praça Central
	}, 2.8, 3.0)

	// 5. Guarda Valen (ID 106)
	// Patrulha contínua da Avenida Leste-Oeste pelas calçadas e ruas (sem atravessar paredes)
	guard2 := world.NewNPC(
		106,
		"Guarda Valen",
		24.0, 0.0, 0.0,
		guardScript,
		s.clock,
		s.BroadcastNPCSay,
	)
	guard2.SetPatrolRoute([]world.Waypoint{
		{X: 24.0, Z: 0.0},  // Portão Leste
		{X: 6.0, Z: 6.0},   // Rua da Praça da Forja
		{X: -14.0, Z: 6.0}, // Calçada em frente à porta da Taverna
		{X: -24.0, Z: 0.0}, // Portão Oeste
		{X: -14.0, Z: 6.0}, // Calçada em frente à porta da Taverna
		{X: 6.0, Z: 6.0},   // Rua da Praça da Forja
	}, 2.8, 3.0)

	allLivingNPCs := []*world.NPC{garrick, lyra, varis, guard1, guard2}
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

	log.Println("[WORLD] NPCs (Garrick 100, Lyra 103, Varis 104, Guardas 105-106) e Bonecos de Treino (101, 102) carregados com sucesso!")

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

// BroadcastWorldTime transmite o pacote 0x13 (WORLD_TIME: 5 bytes) via TCP e UDP para os clientes.
func (s *Server) BroadcastWorldTime() {
	h, m, moon, weather := s.clock.GetTime()
	timePkt := protocol.SerializeWorldTime(h, m, moon, weather)

	s.mu.RLock()
	// Transmissão via TCP
	for _, p := range s.players {
		if p.TCPConn != nil {
			_ = p.TCPConn.SetWriteDeadline(time.Now().Add(200 * time.Millisecond))
			_, _ = p.TCPConn.Write(timePkt[:])
			_ = p.TCPConn.SetWriteDeadline(time.Time{})
		}
	}

	// Transmissão via UDP
	for _, p := range s.players {
		if addr := p.GetUDPAddr(); addr != nil {
			_, _ = s.udpConn.WriteToUDP(timePkt[:], addr)
		}
	}
	s.mu.RUnlock()
}

// BroadcastCombatEvent transmite o pacote 0x32 (COMBAT_EVENT: 17 bytes) via UDP para todos os clientes.
func (s *Server) BroadcastCombatEvent(attackerID, targetID uint32, actionType uint8, damage uint16, isCrit uint8, targetHP, targetMaxHP uint16) {
	pkt := protocol.SerializeCombatEvent(attackerID, targetID, actionType, damage, isCrit, targetHP, targetMaxHP)

	s.mu.RLock()
	for _, p := range s.players {
		if addr := p.GetUDPAddr(); addr != nil {
			_, _ = s.udpConn.WriteToUDP(pkt[:], addr)
		}
	}
	s.mu.RUnlock()
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
	data := protocol.SerializeInventorySync(equipped, slots)

	_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
	_, _ = p.TCPConn.Write(data)
	_ = p.TCPConn.SetWriteDeadline(time.Time{})
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

	// 5. Envia pacote 0x3E (CORPSE_SNAPSHOT) com cadáveres ativos no chão
	s.sendCorpseSnapshots(player)

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
					s.handleDevWorldControl(devPkt.CommandType, devPkt.Value)
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

			case protocol.PacketTypeAllocateStat:
				// Pacote 0x37: ALLOCATE_STAT (6 bytes total, 5 bytes payload)
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
				// Pacote 0x39: USE_OR_EQUIP_ITEM (6 bytes total, 5 bytes payload)
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

	if player.AllocateStat(pkt.StatID) {
		log.Printf("[ATRIBUTOS] Jogador #%d alocou 1 ponto no atributo ID %d. StatPoints restantes: %d\n",
			pkt.PlayerID, pkt.StatID, player.StatPoints)
		s.sendPlayerStats(player)
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

	itemID := pkt.ItemID
	switch itemID {
	// Consumíveis e Tomos Secretos (2, 3, 4, 16, 17, 18, 26, 28, 29, 30)
	case protocol.ItemRawWolfMeat, protocol.ItemCookedNobleMeat, protocol.ItemWolfBloodPotion,
		protocol.ItemBeastProgenitorBlood, protocol.ItemEclipseScytheTome, protocol.ItemStarforgeCore,
		protocol.ItemRunicWarhammerRecipe, protocol.ItemOrganicTrash, protocol.ItemRunicHourglass, protocol.ItemSilverSilkCocoon:
		ok, msg := player.UseConsumable(itemID)
		if ok {
			log.Printf("[ITEM] Jogador #%d usou item ID %d: %s\n", pkt.PlayerID, itemID, msg)
			s.sendInventorySync(player)
			s.sendPlayerStats(player)
			s.BroadcastNPCSay(0, msg)
		}

	// Equipamentos para os 12 Slots Reais
	case protocol.ItemAlphaWolfPelt, protocol.ItemHeavySteelPlate, protocol.ItemAncestralFangRing,
		protocol.ItemLycanAlphaHeart, protocol.ItemRunicWarhammer,
		protocol.ItemVigilHelmet, protocol.ItemSteelChestplate, protocol.ItemWolfLeatherPants,
		protocol.ItemMistwalkerBoots, protocol.ItemBlacksmithGauntlets, protocol.ItemAlchemistBelt,
		protocol.ItemSilverMoonAmulet, protocol.ItemBloodRubyRing, protocol.ItemObsidianRing,
		protocol.ItemStarlightRing, protocol.ItemAlphaPeltCloak:
		equipped := player.GetEquippedSlots()
		unequipped := false
		for slotIdx, eqID := range equipped {
			if eqID == itemID {
				if player.UnequipSlot(uint8(slotIdx)) {
					s.sendInventorySync(player)
					s.sendPlayerStats(player)
					s.BroadcastNPCSay(0, fmt.Sprintf("[Equipamento] Jogador #%d desequipou o item ID %d.", pkt.PlayerID, itemID))
					unequipped = true
					break
				}
			}
		}
		if unequipped {
			return
		}

		ok, msg := player.EquipItem(itemID)
		if ok {
			log.Printf("[EQUIPAMENTO] Jogador #%d equipou item ID %d: %s\n", pkt.PlayerID, itemID, msg)
			s.sendInventorySync(player)
			s.sendPlayerStats(player)
			s.BroadcastNPCSay(0, fmt.Sprintf("[Equipamento] Jogador #%d equipou o item ID %d.", pkt.PlayerID, itemID))
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

	player.SetIdentityMode(pkt.RaceID, pkt.ClassID, pkt.ActionMode)
	log.Printf("[IDENTIDADE] Jogador #%d aplicou Raça %d, Classe %d, Modo %d (Tier %d, Nível %d)\n",
		pkt.PlayerID, player.RaceID, player.ClassID, pkt.ActionMode, player.ClassTier, player.Level)
	s.sendPlayerStats(player)
}

// handleDevWorldControl processa comandos de desenvolvimento (F6, F7, F8).
func (s *Server) handleDevWorldControl(cmdType, val uint8) {
	switch cmdType {
	case 1:
		// CommandType 1: Avançar horas (F6)
		s.clock.AddHours(int(val))
		h, m, moon, weather := s.clock.GetTime()
		log.Printf("[DEV] Tempo avançado em +%d horas! Horário: %02d:%02d | Lua: %d | Clima: %d\n", val, h, m, moon, weather)

		// Dispara OnTick imediatamente nos NPCs para mudança de turno
		s.mu.RLock()
		for _, npc := range s.npcs {
			_ = luaengine.CallOnTick(npc, int(h))
		}
		s.mu.RUnlock()

		s.BroadcastWorldTime()

	case 2:
		// CommandType 2: Ciclar Fase da Lua (F7)
		newMoon := s.clock.CycleMoonPhase()
		log.Printf("[DEV] Fase da Lua alterada ciclicamente para: %d\n", newMoon)
		s.updateMoonPhaseCreatures(newMoon)
		s.BroadcastWorldTime()

	case 3:
		// CommandType 3: Ciclar Clima (F8)
		newWeather := s.clock.CycleWeather()
		log.Printf("[DEV] Clima alterado ciclicamente para: %d\n", newWeather)
		s.BroadcastWorldTime()

	case 4:
		// CommandType 4: Dev Level Up (+val Níveis)
		s.mu.RLock()
		for _, p := range s.players {
			for i := 0; i < int(val); i++ {
				needed := p.NextLevelXP - p.XP
				if needed == 0 {
					needed = 100
				}
				p.AddXP(needed)
			}
			s.checkProgressionMilestones(p)
			s.sendPlayerStats(p)
		}
		s.mu.RUnlock()
		s.BroadcastNPCSay(0, fmt.Sprintf("[DEV] Jogadores avançaram +%d Níveis para testes de marcos!", val))
	}
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

		// Entrega de Presentes Compatíveis:
		// Garrick (ID 100 ou 1): Aceita Minério de Ferro (+20 Afiança)
		if (pkt.TargetNPCID == 100 || pkt.TargetNPCID == 1) && player.HasItem(protocol.ItemIronOre) {
			player.RemoveItem(protocol.ItemIronOre, 1)
			newPts := player.AddFriendship(pkt.TargetNPCID, 20)
			s.sendInventorySync(player)
			s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Pelos deuses da bigorna! Um excelente pedaço de Minério de Ferro! Muito obrigado pelo presente, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
			log.Printf("[PRESENTE] Jogador #%d entregou Minério de Ferro para Garrick (+20 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
		}

		// Lyra (ID 103 ou 102): Aceita Frascos de Sangue compatíveis (+15 a +25 Afiança)
		if pkt.TargetNPCID == 103 || pkt.TargetNPCID == 102 {
			if player.HasItem(protocol.ItemPureLunarBlood) {
				player.RemoveItem(protocol.ItemPureLunarBlood, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 25)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Fascinante! Sangue Lunar Puro em um frasco! Que essência sublime para alquimia! Muito obrigada, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Sangue Lunar Puro para Lyra (+25 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			} else if player.HasItem(protocol.ItemFreshWolfBlood) && !player.HasItem(protocol.ItemEmptyFlask) {
				player.RemoveItem(protocol.ItemFreshWolfBlood, 1)
				newPts := player.AddFriendship(pkt.TargetNPCID, 15)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Um frasco com Sangue Lupino fresco! Excelente para minhas infusões! Muito obrigada, #%d! [Afiança: %d/100 - Nível %d]", pkt.PlayerID, newPts, player.GetFriendshipLevel(pkt.TargetNPCID)))
				log.Printf("[PRESENTE] Jogador #%d entregou Sangue Lupino para Lyra (+15 Afiança, Total: %d)\n", pkt.PlayerID, newPts)
			}
		}

		// 1. Mestres de Classes Básicas para Viajantes Sem Classe (ClassID == 0):
		// Capitão Randel (ID 105 ou 104): Ensina Espadachim (1)
		if pkt.TargetNPCID == 105 || pkt.TargetNPCID == 104 {
			if player.ClassID == protocol.ClassNone {
				player.SetIdentityMode(player.RaceID, protocol.ClassSwordsman, protocol.IdentityModeInitialChange)
				s.sendPlayerStats(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Bem-vindo à vanguarda, recruta #%d! Você agora é um Espadachim (Tier 1). Empunhe sua lâmina com honra!", pkt.PlayerID))
				log.Printf("[MESTRE] Capitão Randel ensinou a Classe Espadachim (1) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassSwordsman && player.Level >= 10 {
				s.checkProgressionMilestones(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Capitão Randel: Seu domínio da lâmina amadureceu, guerreiro #%d. Escolha entre a Vanguarda Real e o Espadachim Mágico!", pkt.PlayerID))
				return
			}
		}

		// Guarda Valen / Mestre Caçador (ID 106 ou 105): Ensina Batedor (2)
		if pkt.TargetNPCID == 106 {
			if player.ClassID == protocol.ClassNone {
				player.SetIdentityMode(player.RaceID, protocol.ClassScout, protocol.IdentityModeInitialChange)
				s.sendPlayerStats(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("Passos firmes e olhos na mata, aventureiro #%d! Você aprendeu as artes do Batedor (Tier 1)!", pkt.PlayerID))
				log.Printf("[MESTRE] Mestre Caçador ensinou a Classe Batedor (2) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if (player.ClassID == protocol.ClassScout || player.ClassID == protocol.ClassInitiate || player.ClassID == protocol.ClassAcolyte) && player.Level >= 10 {
				s.checkProgressionMilestones(player)
			}
		}

		// Garrick, o Ferreiro (ID 100 ou 1): Ensina Ferreiro (5)
		if pkt.TargetNPCID == 100 || pkt.TargetNPCID == 1 {
			// Regra de Exclusividade Rígida: Alquimistas são rejeitados
			if player.ClassID == protocol.ClassAlchemist {
				s.BroadcastNPCSay(pkt.TargetNPCID, "Minhas bigornas não servem para quem gasta o dia misturando fumacinhas em frascos. Vá ver a Lyra!")
				fLevel := player.GetFriendshipLevel(pkt.TargetNPCID)
				_ = luaengine.CallOnPlayerInteract(npc, pkt.PlayerID, s.clock.GetCurrentHour(), pRace, pClass, pMAS, fLevel)
				return
			}

			if player.ClassID == protocol.ClassNone {
				player.SetIdentityMode(player.RaceID, protocol.ClassBlacksmith, protocol.IdentityModeInitialChange)
				s.sendPlayerStats(player)
				s.BroadcastNPCSay(100, fmt.Sprintf("Pela bigorna sagrada! Você quer aprender a forjar e a esmagar aço? Você agora é um Ferreiro (Tier 1), #%d!", pkt.PlayerID))
				log.Printf("[MESTRE] Garrick ensinou a Classe Ferreiro (5) ao jogador #%d!\n", pkt.PlayerID)
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
				player.SetIdentityMode(player.RaceID, protocol.ClassAlchemist, protocol.IdentityModeInitialChange)
				s.sendPlayerStats(player)
				s.BroadcastNPCSay(pkt.TargetNPCID, fmt.Sprintf("O equilíbrio dos elementos é a maior das magias! Você agora é um Alquimista (Tier 1), #%d!", pkt.PlayerID))
				log.Printf("[MESTRE] Lyra ensinou a Classe Alquimista (6) ao jogador #%d!\n", pkt.PlayerID)
				return
			}
			if player.ClassID == protocol.ClassAlchemist && player.Level >= 10 {
				s.checkProgressionMilestones(player)
			}
		}

		// Gatilho Secreto Artífice Rúnico com Garrick (NPCID = 100 ou 1)
		if (pkt.TargetNPCID == 100 || pkt.TargetNPCID == 1) && player.Level >= 5 && player.HasItem(protocol.ItemHeavySteelPlate) {
			if !player.HasItem(protocol.ItemStarforgeCore) {
				player.RemoveItem(protocol.ItemHeavySteelPlate, 1)
				player.AddItem(protocol.ItemStarforgeCore, 1)
				s.sendInventorySync(player)
				s.BroadcastNPCSay(100, fmt.Sprintf("Pelos deuses da bigorna! Essa Placa de Aço do Executor é pura liga estelar... Tome este Núcleo de Forja Estelar, aventureiro #%d! Use-o em seu inventário para despertar como Artífice Rúnico!", pkt.PlayerID))
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
			// Iniciação do Ceifador do Eclipse com Tomo
			if player.HasItem(protocol.ItemEclipseScytheTome) && player.ClassID != protocol.ClassEclipseReaper {
				player.RemoveItem(protocol.ItemEclipseScytheTome, 1)
				player.SetIdentityMode(player.RaceID, protocol.ClassEclipseReaper, protocol.IdentityModeSecretReset)
				s.sendPlayerStats(player)
				s.BroadcastNPCSay(104, fmt.Sprintf("Pssiu... As sombras o acolhem, novo Ceifador do Eclipse #%d! Sua alma agora ceifará a escuridão!", pkt.PlayerID))
				log.Printf("[MESTRE] Varis iniciou o jogador #%d como Ceifador do Eclipse (Classe 7)!\n", pkt.PlayerID)
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

	// 1. Custo de Estamina por Tipo de Ação
	var staminaCost float32
	switch pkt.ActionType {
	case protocol.ActionBasicAttack: // 1: Ataque Básico (sem custo de stamina)
		staminaCost = 0.0
	case protocol.ActionDodgeRoll: // 2: Esquiva (20 stamina, 10 para Thalassiano)
		staminaCost = 20.0
		if player.RaceID == protocol.RaceThalassian {
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

	if staminaCost > 0 && !player.ConsumeStamina(staminaCost) {
		// Estamina insuficiente para executar a ação
		s.sendPlayerStats(player)
		return
	}

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

	// 3.1. Cura do Acólito (4) e Alquimista (6) no Q (ActionType == 3): cura +40 HP dos aliados em 6.0m
	if (classID == protocol.ClassAcolyte || classID == protocol.ClassAlchemist) && pkt.ActionType == protocol.ActionSkillQ {
		s.mu.RLock()
		for _, ally := range s.players {
			ally.Mu.RLock()
			ax, az := ally.PosX, ally.PosZ
			ally.Mu.RUnlock()
			adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
			if adist <= 6.0 {
				ally.Heal(40)
				s.sendPlayerStats(ally)
			}
		}
		s.mu.RUnlock()
		log.Printf("[CURA] Jogador #%d (Classe %d) curou aliados próximos em +40 HP com Skill Q!\n", player.ID, classID)
	}

	// 3.2. Acólito Habilidade 3 [F] - Égide da Fé: cura +65 HP de todo o grupo em 10.0m
	if classID == protocol.ClassAcolyte && pkt.ActionType == protocol.ActionSkillF {
		s.mu.RLock()
		for _, ally := range s.players {
			ally.Mu.RLock()
			ax, az := ally.PosX, ally.PosZ
			ally.Mu.RUnlock()
			adist := float32(math.Sqrt(float64((ax-px)*(ax-px) + (az-pz)*(az-pz))))
			if adist <= 10.0 {
				ally.Heal(65)
				s.sendPlayerStats(ally)
			}
		}
		s.mu.RUnlock()
		log.Printf("[CURA] Acólito #%d ativou Égide da Fé [F] curando aliados em +65 HP!\n", player.ID)
	}

	// 3.3. Ferreiro Habilidade 2 [R] - Afiação de Combate: aumenta dano dos aliados em +25% por 10s e choque ao redor
	if classID == protocol.ClassBlacksmith && pkt.ActionType == protocol.ActionSkillR {
		s.mu.RLock()
		for _, ally := range s.players {
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
		log.Printf("[BUFF] Ferreiro #%d ativou Afiação de Combate [R] para aliados (+25%% dano por 10s)!\n", player.ID)
	}

	// 3.4. Espadachim Habilidade 2 [R] - Postura de Ferro (Parry): reduz dano em 70% por 2.5s
	if classID == protocol.ClassSwordsman && pkt.ActionType == protocol.ActionSkillR {
		player.SetParry(2500 * time.Millisecond)
		log.Printf("[PARRY] Espadachim #%d ativou Postura de Ferro [R] (70%% de redução por 2.5s)!\n", player.ID)
	}

	// 3.5. Iniciado Habilidade 2 [R] - Nova de Gelo: congela e atordoa mobs em 5.0m por 1.5s
	if classID == protocol.ClassInitiate && pkt.ActionType == protocol.ActionSkillR {
		if s.mobManager != nil {
			for _, mob := range s.mobManager.GetAllMobs() {
				if !mob.IsAlive {
					continue
				}
				mob.Mu.RLock()
				mx, mz := mob.PosX, mob.PosZ
				mob.Mu.RUnlock()
				dist := float32(math.Sqrt(float64((mx-px)*(mx-px) + (mz-pz)*(mz-pz))))
				if dist <= 5.0 {
					mob.ApplyStun(1500 * time.Millisecond)
				}
			}
		}
		log.Printf("[NOVA DE GELO] Iniciado #%d congelou inimigos em raio de 5.0m por 1.5s!\n", player.ID)
	}

	// 3.6. Espadachim e Ferreiro Habilidade 3 [F] - Impacto Sísmico: telegrafa área rápida de 4.5m
	if (classID == protocol.ClassSwordsman || classID == protocol.ClassBlacksmith) && pkt.ActionType == protocol.ActionSkillF {
		s.BroadcastAOETelegraph(player.ID, px, pz, 4.5, 400)
	}

	// 3.7. Disparo de Projéteis 3D
	isProjectileAttack := false
	if classID == protocol.ClassScout || classID == protocol.ClassInitiate || classID == protocol.ClassAlchemist ||
		(classID == protocol.ClassAcolyte && pkt.ActionType == protocol.ActionSkillR) ||
		(classID == protocol.ClassRunicArtificer && pkt.ActionType >= protocol.ActionSkillQ) ||
		(classID == protocol.ClassHomunculusCreator) {
		isProjectileAttack = true
	}

	if isProjectileAttack {
		var projType uint8 = protocol.ProjTypePhysicalArrow
		var speed float32 = 24.0
		var maxRange float32 = 16.0
		var splashRadius float32 = 0.0

		switch classID {
		case protocol.ClassScout:
			if pkt.ActionType == protocol.ActionSkillQ {
				projType = protocol.ProjTypePiercingArrow
				speed = 30.0
				maxRange = 22.0
			} else if pkt.ActionType == protocol.ActionSkillR {
				projType = protocol.ProjTypePiercingArrow // Disparo de Estrepes (aplica slow)
				speed = 28.0
				maxRange = 18.0
			} else if pkt.ActionType == protocol.ActionSkillF {
				// Saraivada de 3 flechas simultâneas em cone
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
				speed = 24.0
				maxRange = 16.0
			}

		case protocol.ClassInitiate:
			if pkt.ActionType == protocol.ActionSkillQ {
				projType = protocol.ProjTypeElementalComet
				speed = 20.0
				maxRange = 16.0
				splashRadius = 2.8
			} else if pkt.ActionType == protocol.ActionSkillF {
				projType = protocol.ProjTypeElementalComet // Grande Explosão Elemental
				speed = 22.0
				maxRange = 18.0
				splashRadius = 5.0
			} else {
				projType = protocol.ProjTypeArcaneOrb
				speed = 18.0
				maxRange = 14.0
			}

		case protocol.ClassAcolyte:
			// Skill R: Lança do Julgamento (feixe sagrado à distância)
			projType = protocol.ProjTypeHolySpear
			speed = 25.0
			maxRange = 15.0

		case protocol.ClassAlchemist:
			projType = protocol.ProjTypeAcidFlask
			speed = 20.0
			maxRange = 13.0
			if pkt.ActionType == protocol.ActionSkillR {
				splashRadius = 3.5 // Bomba de Ácido Corrosivo
			} else if pkt.ActionType == protocol.ActionSkillF {
				splashRadius = 5.0 // Grande Explosão Química
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
		}

		proj := s.projManager.SpawnWithAction(player.ID, projType, pkt.ActionType, px, 1.2, pz, aimX, aimZ, speed, maxRange, splashRadius)
		s.BroadcastProjectileSpawn(proj)
		log.Printf("[PROJETIL] Jogador #%d (Classe %d) disparou Projétil #%d (Tipo %d, Ação %d, Vel: %.1f, Alcance: %.1f)\n",
			player.ID, classID, proj.ID, projType, pkt.ActionType, speed, maxRange)

		s.sendPlayerStats(player)
		return
	}

	// 4. Combate Melee / Corpo a Corpo
	attackRange := float32(3.8)
	if classID == protocol.ClassAcolyte {
		attackRange = 4.5
	} else if classID == protocol.ClassBlacksmith || classID == protocol.ClassRunicArtificer {
		attackRange = 4.0
	} else if classID == protocol.ClassEclipseReaper {
		attackRange = 4.8 // Foice Colossal
	}
	if pkt.ActionType == protocol.ActionSkillF {
		attackRange = 5.0 // Alcance ampliado no Ultimate
	}

	// Detecção de Alvos em Cone ou Área
	var targetDummy *world.TrainingDummy
	var targetMob *world.Mob
	minDist := attackRange + 1.0

	s.mu.RLock()
	// Verifica Bonecos de Treino
	for _, dummy := range s.dummies {
		dx, _, dz := dummy.GetPos()
		distX := dx - px
		distZ := dz - pz
		dist := float32(math.Sqrt(float64(distX*distX + distZ*distZ)))

		if dist <= attackRange && dist > 0.01 {
			dot := (distX/dist)*aimX + (distZ/dist)*aimZ
			isCircleAttack := (pkt.ActionType == protocol.ActionSkillF || (pkt.ActionType == protocol.ActionSkillR && (classID == protocol.ClassInitiate || classID == protocol.ClassBlacksmith)))
			if (isCircleAttack || dot >= 0.25) && dist < minDist {
				minDist = dist
				targetDummy = dummy
				targetMob = nil
			}
		}
	}

	// Verifica Mobs vivos
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive {
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
				isCircleAttack := (pkt.ActionType == protocol.ActionSkillF || (pkt.ActionType == protocol.ActionSkillR && (classID == protocol.ClassInitiate || classID == protocol.ClassBlacksmith)))
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
	h, _, moon, weather := s.clock.GetTime()
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

		finalDamage, wasBlocked, newHP, isDead := targetMob.TakeDamage(damage, player.ID)

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
		if player.HasLycanHeartEquipped() {
			ls := uint16(float32(finalDamage) * 0.15)
			if ls == 0 && finalDamage > 0 {
				ls = 1
			}
			player.Heal(ls)
		}
		// Passiva Boreal: ataques aplicam lentidão de gelo
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

	// Gatilho Secreto da Raça Revenant (RaceID = 7 - Amaldiçoado das Cinzas):
	// Morte à noite com Cálice da Alma Partida (Item 14) no inventário
	if isNight && player.HasItem(protocol.ItemBrokenSoulChalice) && player.RaceID != protocol.RaceRevenant {
		player.RemoveItem(protocol.ItemBrokenSoulChalice, 1)
		player.EvolveToRevenant()
		s.sendInventorySync(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[RITUAL SOMBRIO] As trevas da noite consomem a alma do Jogador #%d... Ao segurar o Cálice da Alma Partida, ele renasce como AMALDIÇOADO DAS CINZAS (Revenant)! (+50 MaxHP, +25%% Dano Noturno)", player.ID))
		log.Printf("[SEGREDO] Jogador #%d despertou como Raça Secreta 7 (Revenant) ao morrer à noite com o Cálice da Alma Partida!\n", player.ID)
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

// BroadcastAOETelegraph transmite o pacote UDP 0x34 para todos os clientes conectados.
func (s *Server) BroadcastAOETelegraph(sourceID uint32, posX, posZ, radius float32, durationMs uint16) {
	pkt := protocol.SerializeAOETelegraph(sourceID, posX, posZ, radius, durationMs)

	s.mu.RLock()
	targetAddrs := make([]*net.UDPAddr, 0, len(s.players))
	for _, p := range s.players {
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
					log.Printf("[EVOLUÇÃO] Jogador #%d completou a Evolução Solo Varkai para Licantropo Primordial (RaceID = 6)!\n", soloPID)
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
		case protocol.MobTypeMistWolf: // 1: Lobo da Bruma
			killer.AddItem(protocol.ItemRawWolfMeat, 1)
			killer.AddItem(protocol.ItemWolfGreyPelt, 1)
			drops = append(drops, "Carne Crua de Lobo x1", "Pelagem Cinzenta x1")

			if rand.Float64() < 0.25+luckBonus {
				killer.AddItem(protocol.ItemSharpWolfFang, 1)
				drops = append(drops, "Presa Lupina Afiada x1")
			}
			if rand.Float64() < 0.20+luckBonus {
				killer.AddItem(protocol.ItemBeastClaw, 1)
				drops = append(drops, "Garra de Fera x1")
			}
			if rand.Float64() < 0.03+luckBonus { // 3% Raro
				killer.AddItem(protocol.ItemAncestralFangRing, 1)
				drops = append(drops, "Anel de Presa Ancestral [RARO] x1")
			}
			if rand.Float64() < secretDropChance { // 0.1% Secreto
				killer.AddItem(protocol.ItemSilverSilkCocoon, 1)
				drops = append(drops, "Casulo de Seda Prateada [SECRETO 0.1%] x1")
			}

			if killer.GetItemCount(protocol.ItemEmptyFlask) > 0 {
				killer.RemoveItem(protocol.ItemEmptyFlask, 1)
				killer.AddItem(protocol.ItemFreshWolfBlood, 1)
				flaskMsg = " [Frasco Vazio preenchido com Sangue Lupino Fresco!]"
			}

		case protocol.MobTypeOutcastRaider, protocol.MobTypeVigilCrossbowman: // 2, 3: Saqueador / Besteiro
			killer.AddItem(protocol.ItemEmptyFlask, 1)
			killer.AddItem(protocol.ItemCookedNobleMeat, 1)
			drops = append(drops, "Frasco de Vidro Vazio x1", "Carne Nobre Assada x1")

			if rand.Float64() < 0.35+luckBonus { // 35% Minério de Ferro (Presente compatível para Garrick)
				killer.AddItem(protocol.ItemIronOre, 1)
				drops = append(drops, "Minério de Ferro x1")
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

			if killer.GetItemCount(protocol.ItemEmptyFlask) > 0 {
				killer.RemoveItem(protocol.ItemEmptyFlask, 1)
				killer.AddItem(protocol.ItemDarkPoisonGland, 1)
				flaskMsg = " [Frasco Vazio preenchido com Glândula de Veneno Sombrio!]"
			}

		case protocol.MobTypeIronEnforcer: // 5: Executor de Ferro
			killer.AddItem(protocol.ItemHeavySteelPlate, 1)
			killer.AddItem(protocol.ItemEmptyFlask, 1)
			killer.AddItem(protocol.ItemIronOre, 2)
			drops = append(drops, "Placa de Aço Pesada x1", "Frasco de Vidro Vazio x1", "Minério de Ferro x2")
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

			if killer.GetItemCount(protocol.ItemEmptyFlask) > 0 {
				killer.RemoveItem(protocol.ItemEmptyFlask, 1)
				killer.AddItem(protocol.ItemPureLunarBlood, 1)
				flaskMsg = " [Frasco Vazio preenchido com Sangue Lunar Puro!]"
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

			if killer.GetItemCount(protocol.ItemEmptyFlask) > 0 {
				killer.RemoveItem(protocol.ItemEmptyFlask, 1)
				if rand.Float64() < secretDropChance { // 0.1% Secreto
					killer.AddItem(protocol.ItemBeastProgenitorBlood, 1)
					flaskMsg = " [MILAGRE! Frasco Vazio preenchido com Sangue do Progenitor Bestial (0.1%)!]"
				} else {
					killer.AddItem(protocol.ItemPureLunarBlood, 1)
					flaskMsg = " [Frasco Vazio preenchido com Sangue Lunar Concentrado!]"
				}
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
			if killer.GetItemCount(protocol.ItemEmptyFlask) > 0 {
				killer.RemoveItem(protocol.ItemEmptyFlask, 1)
				killer.AddItem(protocol.ItemDarkPoisonGland, 1)
				flaskMsg = " [Frasco Vazio preenchido com Glândula de Veneno Sombrio!]"
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
			if killer.GetItemCount(protocol.ItemEmptyFlask) > 0 {
				killer.RemoveItem(protocol.ItemEmptyFlask, 1)
				killer.AddItem(protocol.ItemDarkPoisonGland, 1)
				flaskMsg = " [Frasco Vazio preenchido com Glândula de Veneno Sombrio!]"
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
			if killer.GetItemCount(protocol.ItemEmptyFlask) > 0 {
				killer.RemoveItem(protocol.ItemEmptyFlask, 1)
				killer.AddItem(protocol.ItemPureLunarBlood, 1)
				flaskMsg = " [Frasco Vazio preenchido com Sangue Lunar Puro!]"
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
	sb.WriteString("  - Item #2 (Pelagem Cinzenta): 100.0%\n")
	sb.WriteString("  - Item #3 (Presa Lupina Afiada): 25.0%\n")
	sb.WriteString("  - Item #4 (Garra de Fera): 20.0%\n")
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
	sb.WriteString("==================================================")
	return sb.String()
}

// sendCorpseSnapshots transmite o snapshot de todos os cadáveres ativos para um jogador específico via TCP.
func (s *Server) sendCorpseSnapshots(p *world.Player) {
	if s.corpseManager == nil || p == nil {
		return
	}
	snaps := s.corpseManager.GetSnapshots()
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
}

// broadcastCorpseSnapshots transmite o snapshot de cadáveres ativos para todos os clientes conectados.
func (s *Server) broadcastCorpseSnapshots() {
	if s.corpseManager == nil {
		return
	}
	snaps := s.corpseManager.GetSnapshots()
	pkt := protocol.SerializeCorpseSnapshot(snaps)

	s.mu.RLock()
	for _, p := range s.players {
		if p.TCPConn != nil {
			_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
			_, _ = p.TCPConn.Write(pkt)
			_ = p.TCPConn.SetWriteDeadline(time.Time{})
		}
		if addr := p.GetUDPAddr(); addr != nil {
			_, _ = s.udpConn.WriteToUDP(pkt, addr)
		}
	}
	s.mu.RUnlock()
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

	// 2. Extrai pontos vitais (órgãos) da criatura
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
		itemToGive = organ.ItemReward
		qty = organ.Quantity
		if qty == 0 {
			qty = 1
		}
		resultMsg = fmt.Sprintf("[AUTÓPSIA PERFEITA] Corte de precisão máxima na Zona Verde! Você extraiu: %s (Qualidade Perfeita x%d).", organ.Name, qty)

	case protocol.QualityCommon: // 2: Comum (Zona Amarela)
		itemToGive = organ.ItemReward
		qty = organ.Quantity
		if qty == 0 {
			qty = 1
		}
		resultMsg = fmt.Sprintf("[AUTÓPSIA COMUM] Corte na Zona Amarela. Você extraiu: %s (Qualidade Comum x%d).", organ.Name, qty)

	default: // 3: Destruído / Zona Vermelha ou Tempo Expirado
		itemToGive = protocol.ItemOrganicTrash // Item 28: Lixo Orgânico
		qty = 1
		resultMsg = fmt.Sprintf("[AUTÓPSIA FALHA] O bisturi atingiu a Zona Vermelha! O órgão foi dilacerado e virou Lixo Orgânico.")
	}

	// Consome Frasco Vazio se for Sangue ou Glândula extraída com sucesso (Aracne não precisa para glândulas venenosas)
	isArachneGland := player.RaceID == protocol.RaceArachne && organ.OrganType == world.OrganGland
	if (organ.OrganType == world.OrganBlood || organ.OrganType == world.OrganGland) && pkt.ResultTier != protocol.QualityDestroyed {
		if isArachneGland {
			resultMsg += " [Tecelão da Bruma: Veneno coletado organicamente sem frasco!]"
		} else if player.HasItem(protocol.ItemEmptyFlask) {
			player.RemoveItem(protocol.ItemEmptyFlask, 1)
			resultMsg += " [Frasco Vazio preenchido!]"
		}
	}

	// Verifica se a mochila está cheia (limite de 24 slots)
	slots := player.GetInventorySlots()
	inventoryFull := len(slots) >= 24 && !player.HasItem(itemToGive)

	if inventoryFull {
		log.Printf("[AUTOPSIA] Mochila do jogador #%d cheia! Item %d (%s) deixado no chão junto ao cadáver #%d.\n",
			player.ID, itemToGive, organ.Name, pkt.CorpseID)
		s.BroadcastNPCSay(0, fmt.Sprintf("[MOCHILA CHEIA] Sua mochila está lotada! O item (%s) ficou no chão junto ao cadáver.", organ.Name))
	} else {
		player.AddItem(itemToGive, qty)
		s.sendInventorySync(player)
		s.BroadcastNPCSay(0, resultMsg)
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

			if !isAlive {
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
				mx, mz = world.ClampToMapBounds(mx, mz)
			}
		}

		mob.PosX = mx
		mob.PosZ = mz
		mob.Mu.Unlock()
	}
}

// updateMoonPhaseCreatures ativa/desperta Lobo Alfa (Lua Cheia) e Licantropo Alfa (Lua de Sangue).
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

	h, _, moon, weather := s.clock.GetTime()

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
		oSTR, oDEX, _, _, oINT, oSPI, oMAS, oLCK := owner.GetAttributes()

		// 1. Colisão contra Bonecos de Treino (raio 1.1m)
		s.mu.RLock()
		for _, dummy := range s.dummies {
			if p.HitTargets[dummy.ID] {
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
				if !mob.IsAlive || p.HitTargets[mob.ID] {
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

					finalDamage, wasBlocked, newHP, isDead := mob.TakeDamage(damage, p.OwnerID)
					s.BroadcastCombatEvent(p.OwnerID, mob.ID, actionType, finalDamage, isCrit, newHP, mob.MaxHP)

					// Lifesteal
					if ownerRace == protocol.RaceDhampir {
						owner.Heal(8)
						s.sendPlayerStats(owner)
					}
					if ownerClass == protocol.ClassEclipseReaper {
						owner.Heal(12)
						s.sendPlayerStats(owner)
					}

					// Disparo de Estrepes (Batedor Skill R): reduz MoveSpeed em 40% por 3s
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
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive {
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

	// Buffers estáticos para zero alocações
	var playerSnapshotBuf [WorldSnapshotMaxBufferSize]byte
	var playerSnapshots [MaxPlayers]protocol.PlayerSnapshot
	var targetAddrs [MaxPlayers]*net.UDPAddr

	var npcSnapshotBuf [NPCSnapshotMaxBufferSize]byte
	var npcSnapshots [MaxNPCs]protocol.NPCSnapshot

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
				p.RegenerateStamina(dt, isNight, currentMoon)
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

			// 4. Coleta de dados dos jogadores e destinos UDP
			playerCount := 0
			targetCount := 0
			for _, p := range s.players {
				if playerCount < MaxPlayers {
					playerSnapshots[playerCount] = p.ToSnapshot()
					playerCount++
				}
				if addr := p.GetUDPAddr(); addr != nil {
					if targetCount < MaxPlayers {
						targetAddrs[targetCount] = addr
						targetCount++
					}
				}
			}

			// Coleta de NPCs e Bonecos de Treino para o snapshot
			npcCount := 0
			for _, npc := range s.npcs {
				if npcCount < MaxNPCs {
					npcSnapshots[npcCount] = npc.ToSnapshot()
					npcCount++
				}
			}
			for _, dummy := range s.dummies {
				if npcCount < MaxNPCs {
					npcSnapshots[npcCount] = dummy.ToSnapshot()
					npcCount++
				}
			}
			s.mu.RUnlock()

			// Envio dos snapshots via UDP
			if targetCount > 0 {
				if playerCount > 0 {
					written := protocol.SerializeWorldSnapshotInto(playerSnapshotBuf[:], s.serverTick, playerSnapshots[:playerCount])
					if written > 0 {
						payload := playerSnapshotBuf[:written]
						for i := 0; i < targetCount; i++ {
							_, _ = s.udpConn.WriteToUDP(payload, targetAddrs[i])
						}
					}
				}

				if npcCount > 0 {
					writtenNPC := protocol.SerializeNPCSnapshotInto(npcSnapshotBuf[:], npcSnapshots[:npcCount])
					if writtenNPC > 0 {
						npcPayload := npcSnapshotBuf[:writtenNPC]
						for i := 0; i < targetCount; i++ {
							_, _ = s.udpConn.WriteToUDP(npcPayload, targetAddrs[i])
						}
					}
				}

				// Resolução de colisão física cilindro-cilindro (Body Blocking) a 30 Hz
				s.resolveBodyBlocking()

				// Transmissão de Snapshots dos Monstros a 30 Hz (0x14: MOB_SNAPSHOT)
				if s.mobManager != nil {
					mobSnaps := s.mobManager.GetSnapshots()
					if len(mobSnaps) > 0 {
						mobPayload := protocol.SerializeMobSnapshot(mobSnaps)
						for i := 0; i < targetCount; i++ {
							_, _ = s.udpConn.WriteToUDP(mobPayload, targetAddrs[i])
						}
					}
				}
			}

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
					mob.Mu.RUnlock()

					var nearestPID uint32 = 0
					var minPlayerDist float32 = 999.0
					var targetPX, targetPZ float32

					s.mu.RLock()
					for _, p := range s.players {
						if p.IsInAutopsy() {
							continue
						}
						p.Mu.RLock()
						px, pz := p.PosX, p.PosZ
						pid := p.ID
						p.Mu.RUnlock()

						pdx := px - mx
						pdz := pz - mz
						dist := float32(math.Sqrt(float64(pdx*pdx + pdz*pdz)))
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

				// 6. Defesa da Vila pelo Garrick: Monstros a menos de 6.5m sofrem retaliação a cada 2s
				s.mu.RLock()
				garrick := s.npcs[100]
				s.mu.RUnlock()

				if garrick != nil {
					gx, _, gz := garrick.GetPos()
					for _, mob := range allMobs {
						if !mob.IsAlive {
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

				// Defesa perimetral dos Guardas da Patrulha Real (IDs 105 e 106)
				guards := []*world.NPC{s.npcs[105], s.npcs[106]}
				for _, guard := range guards {
					if guard == nil {
						continue
					}
					gx, _, gz := guard.GetPos()
					for _, mob := range allMobs {
						if !mob.IsAlive || !mob.IsActive {
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

// checkForgeFireHazard verifica se jogadores colidem com a Fornalha Incandescente do Garrick (14.0, 14.0)
// e aplica 15 de Dano de Fogo autoritativo a cada 0.8s.
func (s *Server) checkForgeFireHazard() {
	forgeX, forgeZ := float32(14.0), float32(14.0)
	radius := float32(2.3)
	radiusSq := radius * radius

	s.mu.RLock()
	players := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		players = append(players, p)
	}
	garrick := s.npcs[100] // Garrick, o Ferreiro (ID 100)
	s.mu.RUnlock()

	for _, p := range players {
		p.Mu.RLock()
		px, pz := p.PosX, p.PosZ
		isAlive := p.HP > 0
		p.Mu.RUnlock()

		if !isAlive {
			continue
		}

		dx := px - forgeX
		dz := pz - forgeZ
		if (dx*dx + dz*dz) <= radiusSq {
			p.Mu.RLock()
			raceID := p.RaceID
			p.Mu.RUnlock()

			if raceID == protocol.RaceAshDragonborn {
				// Coração de Fornalha: na fornalha do Garrick, cura +20 HP e +20 Stamina/s!
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
		// Valeriano / Alto Valeriano / Andarilho do Éter:
		// Restaura +40 Stamina, +25 HP e concede buff de ataque por 10s (+25% dano)
		player.RestoreStamina(40.0)
		player.Heal(25)
		player.SetBuff(10 * time.Second)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 25, 0, 0, 0)
		log.Printf("[RACIAL] Valeriano #%d ativou Ímpeto Valeriano (+40 Stamina, +25 HP, +25%% Dano)!\n", player.ID)

	case protocol.RaceNoctari, protocol.RaceLunarArchon, protocol.RaceUmbralSpecter:
		// Noctari / Arconte Lunar / Espectro Umbral:
		// Dispara explosão de luz estelar/sombra ao redor (5.5m), alto dano mágico e cura +30 HP
		player.Heal(30)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(45 + int(pINT)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 30, 0, 0, 0)
		log.Printf("[RACIAL] Noctari #%d ativou Explosão Lunar/Umbral (+30 HP, %d dano em 5.5m)!\n", player.ID, dmg)

	case protocol.RaceKharad, protocol.RaceRunicGuardian, protocol.RaceObsidianTitan:
		// Kharad / Guardião Rúnico / Titã de Obsidiana:
		// Ativa pele rúnica/erupção de magma causando dano em área de 4.5m e concedendo escudo redutor de dano por 5s
		player.SetParry(5 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 4.5, 400)
		dmg := uint16(50 + int(pSTR)*2 + int(player.CON)*2)
		s.applyRacialAoEDamage(player, px, pz, 4.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Kharad #%d ativou Baluarte Rúnico / Erupção de Magma (Escudo 5s, %d dano em 4.5m)!\n", player.ID, dmg)

	case protocol.RaceVarkai, protocol.RaceDraconicSovereign, protocol.RaceFrenzyBeast:
		// Varkai / Soberano Dracônico / Fera do Frenesi:
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
		// Dhampir: Roubo de vida e dreno em área (5m)
		player.Heal(60)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		dmg := uint16(55 + int(pINT)*2 + int(pDEX)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 60, 0, 0, 0)
		log.Printf("[RACIAL] Dhampir #%d ativou Dreno Vampírico (+60 HP, %d dano)!\n", player.ID, dmg)

	case protocol.RacePrimordialLycanthrope:
		// Licantropo Primordial: Rugido/Garras Alfas no Z (cone frontal, alto dano + lifesteal)
		dmg := uint16(75 + int(pSTR)*3 + int(player.CON)*2)
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.5, 300)
		hits := s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 6.5, 0.20, dmg)
		if hits > 0 {
			player.Heal(uint16(hits) * 35)
		}
		player.SetBuff(10 * time.Second)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Licantropo Primordial #%d ativou Garras Alfas (%d dano)!\n", player.ID, dmg)

	case protocol.RaceRevenant:
		// Revenant: Chama Fátua espiritual (5.5m), dano espiritual e cura +50 HP
		player.Heal(50)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.5, 300)
		dmg := uint16(50 + int(pINT)*2 + int(pSPI)*3)
		s.applyRacialAoEDamage(player, px, pz, 5.5, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 50, 0, 0, 0)
		log.Printf("[RACIAL] Revenant #%d ativou Chama Fátua (+50 HP, %d dano)!\n", player.ID, dmg)

	case protocol.RaceCelestial:
		// Celestino: Julgamento da Aurora: cura aliados + dano solar no Z (raio 6m)
		player.Heal(50)
		s.healNearbyAllies(player.ID, px, pz, 6.0, 50)
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 300)
		dmg := uint16(55 + int(pSPI)*3 + int(pINT)*2)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 50, 0, 0, 0)
		log.Printf("[RACIAL] Celestino #%d ativou Julgamento da Aurora (Cura aliados +50, %d dano solar)!\n", player.ID, dmg)

	case protocol.RaceAbyssal:
		// Abissal: Singularidade: puxa inimigos em 6m e causa dano de vazio no Z
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 400)
		s.pullMobsToward(px, pz, 6.0, 0.35)
		dmg := uint16(60 + int(pINT)*4)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Abissal #%d ativou Singularidade (Puxão 6m, %d dano de vazio)!\n", player.ID, dmg)

	case protocol.RaceRunicAutomaton:
		// Autômato Rúnico: Sobrecarga de Laser Rúnico no Z (feixe/cone 10m)
		dmg := uint16(70 + int(pSTR)*3 + int(pMAS)*3)
		s.BroadcastAOETelegraph(player.ID, px, pz, 10.0, 350)
		s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 10.0, 0.65, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Autômato Rúnico #%d ativou Laser Rúnico (%d dano)!\n", player.ID, dmg)

	case protocol.RaceSylvari:
		// 19 Sylvari: Prisão da Floresta: enraíza Mobs em 5m por 3s e cura +40 HP
		player.Heal(40)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		s.applyRacialCrowdControl(px, pz, 5.0, 3*time.Second, 0, 1.0)
		dmg := uint16(35 + int(pSPI)*2 + int(pINT)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 40, 0, 0, 0)
		log.Printf("[RACIAL] Sylvari #%d ativou Prisão da Floresta (Enraíza 3s em 5m, +40 HP)!\n", player.ID)

	case protocol.RaceMyconid:
		// 20 Esporiano / Myconid: Nuvem de Esporos: veneno em área de 6m e reduz velocidade dos Mobs em 50%
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 300)
		s.applyRacialCrowdControl(px, pz, 6.0, 0, 5*time.Second, 0.5)
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
		// 22 Draconato de Cinzas: Cataclismo Dracônico: cone de magma de 8m com dano massivo
		dmg := uint16(90 + int(pSTR)*4 + int(player.CON)*2)
		s.BroadcastAOETelegraph(player.ID, px, pz, 8.0, 400)
		s.applyRacialConeDamage(player, px, pz, aimX, aimZ, 8.0, 0.25, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Draconato #%d ativou Cataclismo Dracônico (Cone 8m, %d dano de magma)!\n", player.ID, dmg)

	case protocol.RaceChimera:
		// 23 Quimera: Sobrecarga Anatômica: cura +50 HP, ativa buff completo por 15s e causa explosão ácida em 5m
		player.Heal(50)
		player.SetBuff(15 * time.Second)
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		dmg := uint16(55 + int(pSTR)*2 + int(pDEX)*2 + int(player.CON)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 50, 0, 0, 0)
		log.Printf("[RACIAL] Quimera #%d ativou Sobrecarga Anatômica (+50 HP, Buff 15s, %d dano ácido)!\n", player.ID, dmg)

	case protocol.RaceBoreal:
		// 24 Boreal: Zero Absoluto: congela todos os Mobs em 5m por 2.5s e causa dano criogênico
		s.BroadcastAOETelegraph(player.ID, px, pz, 5.0, 300)
		s.applyRacialCrowdControl(px, pz, 5.0, 2500*time.Millisecond, 0, 1.0)
		dmg := uint16(50 + int(pINT)*3 + int(pSPI)*2)
		s.applyRacialAoEDamage(player, px, pz, 5.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 0, 0, 0, 0)
		log.Printf("[RACIAL] Boreal #%d ativou Zero Absoluto (Congela 2.5s em 5m, %d dano)!\n", player.ID, dmg)

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
		s.pullMobsToward(px, pz, 6.0, 0.4)
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
		// 28 Errante Temporal: Rebobinar o Destino: restaura HP/Stamina de 3s atrás (ou +80) e dispara onda temporal
		snap, restored := player.RewindTimeDestiny()
		s.BroadcastAOETelegraph(player.ID, px, pz, 6.0, 200)
		dmg := uint16(60 + int(pINT)*3 + int(pDEX)*2)
		s.applyRacialAoEDamage(player, px, pz, 6.0, dmg)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionRacialSkill, 80, 0, 0, 0)
		log.Printf("[RACIAL] Errante Temporal #%d ativou Rebobinar o Destino (Restaurado: %v, Pos: %.1f,%.1f, HP: %d, %d dano)!\n",
			player.ID, restored, snap.PosX, snap.PosZ, snap.HP, dmg)
	}
}

// pullMobsToward puxa mobs em volta para mais próximo do jogador.
func (s *Server) pullMobsToward(px, pz, radius, factor float32) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.mobManager == nil {
		return
	}
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive {
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

// applyRacialCrowdControl aplica atordoamento/lentidão em área para habilidades raciais.
func (s *Server) applyRacialCrowdControl(px, pz, radius float32, stunDuration, slowDuration time.Duration, slowFactor float32) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.mobManager == nil {
		return
	}
	for _, mob := range s.mobManager.GetAllMobs() {
		if !mob.IsAlive {
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

// healNearbyAllies cura aliados próximos dentro do raio informado.
func (s *Server) healNearbyAllies(playerID uint32, px, pz, radius float32, amount uint16) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, ally := range s.players {
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

// applyRacialSingleTargetSnipe dispara um projétil de longo alcance contra o mob mirado.
func (s *Server) applyRacialSingleTargetSnipe(player *world.Player, px, pz, aimX, aimZ, maxRange float32, damage uint16, stunDuration time.Duration) {
	s.mu.RLock()
	var hitMob *world.Mob
	var minDist float32 = maxRange + 1.0
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive {
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

// applyRacialAoEDamage aplica dano radial em alvos no raio especificado.
func (s *Server) applyRacialAoEDamage(player *world.Player, px, pz, radius float32, damage uint16) {
	s.mu.RLock()
	for _, dummy := range s.dummies {
		dx, _, dz := dummy.GetPos()
		dist := float32(math.Sqrt(float64((dx-px)*(dx-px) + (dz-pz)*(dz-pz))))
		if dist <= radius {
			dummy.TakeDamage(damage)
		}
	}
	var hitMobs []*world.Mob
	if s.mobManager != nil {
		for _, mob := range s.mobManager.GetAllMobs() {
			if !mob.IsAlive {
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

// applyRacialConeDamage aplica dano frontal cônico e retorna a quantidade de acertos para lifesteal.
func (s *Server) applyRacialConeDamage(player *world.Player, px, pz, aimX, aimZ, radius, minDot float32, damage uint16) int {
	s.mu.RLock()
	for _, dummy := range s.dummies {
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
			if !mob.IsAlive {
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

	// 2. Oferta de Especialização de Caminho de Classe Básica (Níveis 10, 25, 45)
	if classID >= 1 && classID <= 6 {
		// Nível 10 (Tier 2 Incomum)
		if lvl >= 10 && classTier < protocol.TierUncommon {
			s.sendEvolutionOffer(player, protocol.OfferTypeBasicClass, 1, 2)
			s.BroadcastNPCSay(0, fmt.Sprintf("[MESTRE DA GUILDA] Guerreiro #%d atingiu o Nível 10! Escolha seu Caminho de Especialização (Tier 2 Incomum)!", player.ID))
			return
		}
		// Nível 25 (Tier 3 Rara)
		if lvl >= 25 && classTier < protocol.TierRare {
			s.sendEvolutionOffer(player, protocol.OfferTypeBasicClass, 1, 2)
			s.BroadcastNPCSay(0, fmt.Sprintf("[MESTRE DA GUILDA] Guerreiro #%d atingiu o Nível 25! Evolua seu Caminho para Tier 3 (Rara)!", player.ID))
			return
		}
		// Nível 45 (Tier 4 Épica)
		if lvl >= 45 && classTier < protocol.TierEpic {
			s.sendEvolutionOffer(player, protocol.OfferTypeBasicClass, 1, 2)
			s.BroadcastNPCSay(0, fmt.Sprintf("[MESTRE DA GUILDA] Guerreiro #%d atingiu o Nível 45! Alcance o ápice como Classe Épica (Tier 4)!", player.ID))
			return
		}
	}

	// 3. Provação Lendária para Classes Únicas (Tier 5 no Nível 45+)
	if classID >= 7 && classID <= 9 && classTier == protocol.TierUnique && lvl >= 45 {
		if !questActive {
			player.Mu.Lock()
			player.LegendaryQuestActive = true
			player.LegendaryQuestKills = 0
			player.Mu.Unlock()
			s.BroadcastNPCSay(0, fmt.Sprintf("[PROVAÇÃO LENDÁRIA] O Campeão Único #%d atingiu o Nível 45! Para ascender ao Tier 6 Lendário, abata 3 Mobs de Elite/Boss sem morrer!", player.ID))
		} else if questKills >= 3 {
			s.sendEvolutionOffer(player, protocol.OfferTypeLegendaryTrial, protocol.TierLegendary, 0)
			s.BroadcastNPCSay(0, fmt.Sprintf("[DESPERTAR LENDÁRIO] O Campeão #%d concluiu a Provação Lendária! Pronto para ascender ao TIER 6 LENDÁRIO!", player.ID))
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

	case protocol.OfferTypeBasicClass: // 2: Especialização de Caminho de Classe Básica
		chosenPath := pkt.OptionAID
		if chosenPath == 0 {
			chosenPath = pkt.OptionBID
		}
		player.Mu.Lock()
		player.ClassPath = chosenPath
		if player.ClassTier < protocol.TierEpic {
			player.ClassTier++
		}
		player.Mu.Unlock()
		player.RecalculateStats()

		s.sendPlayerStats(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[EVOLUÇÃO DE CLASSE] O guerreiro #%d escolheu o Caminho %d e ascendeu ao Tier %d!", playerID, chosenPath, player.ClassTier))
		log.Printf("[EVOLUÇÃO DE CLASSE] Jogador #%d escolheu Caminho %d, ClassTier agora é %d!\n", playerID, chosenPath, player.ClassTier)

	case protocol.OfferTypeLegendaryTrial: // 3: Ascensão ao Tier 6 Lendário
		player.Mu.Lock()
		if player.ClassTier == protocol.TierUnique {
			player.ClassTier = protocol.TierLegendary
			player.LegendaryQuestActive = false
		}
		player.Mu.Unlock()
		player.RecalculateStats()

		s.sendPlayerStats(player)
		s.BroadcastNPCSay(0, fmt.Sprintf("[CATACLISMO] TREMEI MORTAIS! O jogador #%d superou a Provação e despertou a CLASSE LENDÁRIA (Tier 6)!", playerID))
		log.Printf("[PROVAÇÃO LENDÁRIA] Jogador #%d ascendeu ao Tier 6 Lendário!\n", playerID)
	}
}

