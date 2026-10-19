package network

import (
	"context"
	"fmt"
	"io"
	"log"
	"math"
	"net"
	"path/filepath"
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
	MaxNPCs                    = 10
	GameTickRate               = 30
	WorldSnapshotMaxBufferSize = protocol.WorldSnapshotHeaderSize + (MaxPlayers * protocol.PlayerSnapshotEntrySize) // 106 bytes
	NPCSnapshotMaxBufferSize   = protocol.NPCSnapshotHeaderSize + (MaxNPCs * protocol.NPCSnapshotEntrySize)         // 212 bytes
)

// Server coordena conexões de rede, relógio do mundo, NPCs, Bonecos de Treino, Mobs, combate e Game Loop.
type Server struct {
	mu           sync.RWMutex
	players      map[uint32]*world.Player
	npcs         map[uint32]*world.NPC
	dummies      map[uint32]*world.TrainingDummy
	mobManager   *world.MobManager
	projManager  *world.ProjectileManager
	nextPlayerID uint32
	serverTick   uint32

	garrickLastDefend time.Time

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
		players:    make(map[uint32]*world.Player),
		npcs:       make(map[uint32]*world.NPC),
		dummies:     make(map[uint32]*world.TrainingDummy),
		mobManager:  world.NewMobManager(),
		projManager: world.NewProjectileManager(),
		clock:       clock,
		luaEngine:   engine,
		ctx:         ctx,
		cancel:      cancel,
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
	combatScript := filepath.Join(combatDir, "combat.lua")
	mobsScript := filepath.Join(mobsDir, "mobs_ai.lua")

	garrick := world.NewNPC(
		1,
		"Garrick, o Ferreiro",
		6.0, 0.0, 6.0,
		garrickScript,
		s.clock,
		s.BroadcastNPCSay,
	)

	if err := s.luaEngine.BindNPC(garrick); err != nil {
		log.Printf("[AVISO] Nao foi possivel vincular script do Garrick de imediato: %v\n", err)
	}

	if err := s.luaEngine.LoadCombatScript(combatScript); err != nil {
		log.Printf("[AVISO] Nao foi possivel carregar script de combate: %v\n", err)
	}

	if err := s.luaEngine.LoadMobAIScript(mobsScript, s.mobManager, s.handleMobAttack, s.handleMobTelegraph, s.handleMobAOEDamage, s.handleMobSay); err != nil {
		log.Printf("[AVISO] Nao foi possivel carregar script de IA dos Mobs: %v\n", err)
	}

	if err := s.luaEngine.StartWatcher(scriptsDir, combatDir, mobsDir); err != nil {
		log.Printf("[AVISO] Nao foi possivel iniciar watcher de scripts: %v\n", err)
	}

	// Bonecos de Treino (Marco 3): IDs 101 e 102 nas posições (4.0, 0.0, 4.0) e (4.0, 0.0, 1.0)
	dummy1 := world.NewTrainingDummy(101, "Boneco de Treino Alfa", 4.0, 0.0, 4.0, 0)
	dummy2 := world.NewTrainingDummy(102, "Boneco de Treino Beta", 4.0, 0.0, 1.0, 0)

	s.mu.Lock()
	s.npcs[garrick.ID] = garrick
	s.dummies[dummy1.ID] = dummy1
	s.dummies[dummy2.ID] = dummy2
	s.mu.Unlock()

	log.Println("[WORLD] NPC Garrick, Bonecos de Treino (101, 102) e Mobs Táticos (201-206) carregados com sucesso!")

	// Executa OnTick inicial do Garrick
	_ = luaengine.CallOnTick(garrick, s.clock.GetCurrentHour())

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

// sendPlayerStats envia 0x33 (PLAYER_STATS: 15 bytes) para o jogador especificado via UDP e TCP.
func (s *Server) sendPlayerStats(p *world.Player) {
	pStats := p.ToStatsPacket()
	b := protocol.SerializePlayerStats(pStats.PlayerID, pStats.RaceID, pStats.ClassID, pStats.HP, pStats.MaxHP, pStats.Stamina, pStats.MaxStamina)

	if addr := p.GetUDPAddr(); addr != nil {
		_, _ = s.udpConn.WriteToUDP(b[:], addr)
	}
	if p.TCPConn != nil {
		_ = p.TCPConn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
		_, _ = p.TCPConn.Write(b[:])
		_ = p.TCPConn.SetWriteDeadline(time.Time{})
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
	player := world.NewPlayer(playerID, conn, 0.0, 1.0, 0.0)
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

			default:
				log.Printf("[TCP] Opcode desconhecido de jogador %d: 0x%02x\n", playerID, header[0])
			}
		}
	}()
}

// handleSelectIdentity define a Raça e Classe do jogador e sincroniza os status.
func (s *Server) handleSelectIdentity(pkt protocol.SelectIdentityPacket) {
	s.mu.RLock()
	player, exists := s.players[pkt.PlayerID]
	s.mu.RUnlock()

	if !exists {
		return
	}

	player.SetIdentity(pkt.RaceID, pkt.ClassID)
	log.Printf("[IDENTIDADE] Jogador #%d selecionou Raça %d e Classe %d\n", pkt.PlayerID, pkt.RaceID, pkt.ClassID)
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
		s.BroadcastWorldTime()

	case 3:
		// CommandType 3: Ciclar Clima (F8)
		newWeather := s.clock.CycleWeather()
		log.Printf("[DEV] Clima alterado ciclicamente para: %d\n", newWeather)
		s.BroadcastWorldTime()
	}
}

// handlePlayerInteract valida distância e invoca a função OnPlayerInteract no Lua.
func (s *Server) handlePlayerInteract(pkt protocol.PlayerInteractPacket) {
	s.mu.RLock()
	player, playerExists := s.players[pkt.PlayerID]
	npc, npcExists := s.npcs[pkt.TargetNPCID]
	var px, py, pz float32
	var pRace, pClass uint8
	if playerExists {
		player.Mu.RLock()
		px, py, pz = player.PosX, player.PosY, player.PosZ
		pRace, pClass = player.RaceID, player.ClassID
		player.Mu.RUnlock()
	}
	s.mu.RUnlock()

	if !playerExists || !npcExists {
		return
	}

	if npc.CanInteract(px, py, pz) {
		log.Printf("[INTERACAO] Jogador %d (Raça: %d, Classe: %d) interagindo com NPC '%s' (ID %d)\n", pkt.PlayerID, pRace, pClass, npc.Name, npc.ID)
		_ = luaengine.CallOnPlayerInteract(npc, pkt.PlayerID, s.clock.GetCurrentHour(), pRace, pClass)
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

	// 1. Custo de Estamina por Tipo de Ação
	var staminaCost float32
	switch pkt.ActionType {
	case protocol.ActionBasicAttack:
		staminaCost = 15.0
	case protocol.ActionDodgeRoll:
		staminaCost = 25.0
	case protocol.ActionSpecialSkill:
		staminaCost = 30.0
	default:
		staminaCost = 10.0
	}

	if !player.ConsumeStamina(staminaCost) {
		// Estamina insuficiente para executar a ação
		s.sendPlayerStats(player)
		return
	}

	// 2. Esquiva (ActionType 2): concede 0.45s de I-Frames de invulnerabilidade e atualiza estamina
	if pkt.ActionType == protocol.ActionDodgeRoll {
		player.SetDodgeIFrame(450 * time.Millisecond)
		s.sendPlayerStats(player)
		s.BroadcastCombatEvent(player.ID, 0, protocol.ActionDodgeRoll, 0, 0, 0, 0)
		return
	}

	// 3. Ataque Básico (1) ou Habilidade Especial (3)
	player.Mu.RLock()
	px, _, pz := player.PosX, player.PosY, player.PosZ
	rotY := player.RotY
	raceID := player.RaceID
	classID := player.ClassID
	hp := player.HP
	maxHP := player.MaxHP
	player.Mu.RUnlock()

	// Cura do Acólito (ClassID == 4) ao usar Habilidade Especial (ActionType == 3, Tecla Q):
	// Cura +40 HP do próprio jogador e de aliados em um raio de 6.0m
	if classID == protocol.ClassAcolyte && pkt.ActionType == protocol.ActionSpecialSkill {
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
		log.Printf("[CURA] Acólito #%d curou aliados próximos em +40 HP!\n", player.ID)
	}

	// Normaliza vetor de mira
	aimX := pkt.AimDirX
	aimZ := pkt.AimDirZ
	aimLen := float32(math.Sqrt(float64(aimX*aimX + aimZ*aimZ)))
	if aimLen < 0.001 {
		// Se não fornecido, mira para a direção em que o jogador está virado (RotY)
		aimX = -float32(math.Sin(float64(rotY)))
		aimZ = -float32(math.Cos(float64(rotY)))
	} else {
		aimX /= aimLen
		aimZ /= aimLen
	}

	// 3.5. Disparo de Projéteis 3D para Batedor (2) e Iniciado (3)
	if classID == protocol.ClassScout || classID == protocol.ClassInitiate {
		var projType uint8 = protocol.ProjTypePhysicalArrow
		var speed float32 = 24.0
		var maxRange float32 = 16.0

		if classID == protocol.ClassScout {
			if pkt.ActionType == protocol.ActionSpecialSkill {
				projType = protocol.ProjTypePiercingArrow
				speed = 30.0
				maxRange = 22.0
			} else {
				projType = protocol.ProjTypePhysicalArrow
				speed = 24.0
				maxRange = 16.0
			}
		} else { // Iniciado
			if pkt.ActionType == protocol.ActionSpecialSkill {
				projType = protocol.ProjTypeElementalComet
				speed = 20.0
				maxRange = 16.0
			} else {
				projType = protocol.ProjTypeArcaneOrb
				speed = 18.0
				maxRange = 14.0
			}
		}

		proj := s.projManager.Spawn(player.ID, projType, px, 1.2, pz, aimX, aimZ, speed, maxRange)
		s.BroadcastProjectileSpawn(proj)
		log.Printf("[PROJETIL] Jogador #%d (Classe %d) disparou Projétil #%d (Tipo %d, Vel: %.1f, Alcance: %.1f)\n",
			player.ID, classID, proj.ID, projType, speed, maxRange)

		s.sendPlayerStats(player)
		return
	}

	// Alcance para armas corpo-a-corpo / toque sagrado: Espadachim (3.8m) e Acólito (4.5m)
	attackRange := float32(3.8)
	if classID == protocol.ClassAcolyte {
		attackRange = 4.5
	}

	// 4. Detecção de Alvo: verifica Bonecos de Treino e Mobs no cone de ataque (dot >= 0.25)
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
			if dot >= 0.25 && dist < minDist {
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
				if dot >= 0.25 && dist < minDist {
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
		)

		newHP, reset := targetDummy.TakeDamage(damage)
		_, maxDummyHP := targetDummy.GetHP()

		log.Printf("[COMBATE] Jogador #%d causou %d dano (Crítico: %d) no Boneco #%d | HP Alvo: %d/%d\n",
			player.ID, damage, isCrit, targetDummy.ID, newHP, maxDummyHP)

		if reset {
			log.Printf("[COMBATE] Boneco de Treino #%d foi destruído e restaurado para %d HP!\n", targetDummy.ID, maxDummyHP)
		}

		s.BroadcastCombatEvent(player.ID, targetDummy.ID, pkt.ActionType, damage, isCrit, newHP, maxDummyHP)

		// Lifesteal do Dhampir (+8 HP)
		if raceID == protocol.RaceDhampir {
			player.Heal(8)
			s.sendPlayerStats(player)
		}

	} else if targetMob != nil {
		damage, isCrit := s.luaEngine.CallCalculateDamage(
			raceID,
			classID,
			pkt.ActionType,
			hpPct,
			int(h),
			moon,
			weather,
		)

		finalDamage, wasBlocked, newHP, isDead := targetMob.TakeDamage(damage)

		log.Printf("[COMBATE] Jogador #%d causou %d dano (Crítico: %d, Bloqueado: %v) no Mob #%d (%s) | HP: %d/%d\n",
			player.ID, finalDamage, isCrit, wasBlocked, targetMob.ID, targetMob.Name, newHP, targetMob.MaxHP)

		if isDead {
			log.Printf("[COMBATE] Mob #%d (%s) foi derrotado! Renascerá em 12 segundos.\n", targetMob.ID, targetMob.Name)
		}

		s.BroadcastCombatEvent(player.ID, targetMob.ID, pkt.ActionType, finalDamage, isCrit, newHP, targetMob.MaxHP)

		// Lifesteal do Dhampir (+8 HP)
		if raceID == protocol.RaceDhampir {
			player.Heal(8)
			s.sendPlayerStats(player)
		}

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

	if !exists {
		return
	}

	newHP, isDead := player.TakeDamage(damage)
	s.BroadcastCombatEvent(mobID, playerID, protocol.ActionBasicAttack, damage, 0, newHP, player.MaxHP)
	s.sendPlayerStats(player)

	if isDead {
		log.Printf("[MORTALIDADE] Jogador #%d foi derrotado pelo Mob #%d e renasceu na Vila!\n", playerID, mobID)
		s.respawnPlayer(player)
	}
}

// handleMobAOEDamage aplica o impacto de dano do golpe telegrafado nos jogadores dentro do raio.
func (s *Server) handleMobAOEDamage(sourceID uint32, x, z, radius float32, damage uint16) {
	s.mu.RLock()
	var victims []*world.Player
	for _, p := range s.players {
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
			log.Printf("[MORTALIDADE] Jogador #%d foi esmagado pelo ataque em área do Executor #%d e renasceu na Vila!\n", p.ID, sourceID)
			s.respawnPlayer(p)
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

// respawnPlayer redefine os atributos do jogador para o máximo e o teletransporta para a Vila.
func (s *Server) respawnPlayer(player *world.Player) {
	player.Respawn(0.0, 1.0, 0.0)
	s.sendPlayerStats(player)
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
		actionType := protocol.ActionBasicAttack
		if p.ProjType == protocol.ProjTypePiercingArrow || p.ProjType == protocol.ProjTypeElementalComet {
			actionType = protocol.ActionSpecialSkill
		}

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
				)

				newHP, reset := dummy.TakeDamage(damage)
				_, maxDummyHP := dummy.GetHP()
				s.BroadcastCombatEvent(p.OwnerID, dummy.ID, actionType, damage, isCrit, newHP, maxDummyHP)

				// Lifesteal do Dhampir (+8 HP)
				if ownerRace == protocol.RaceDhampir {
					owner.Heal(8)
					s.sendPlayerStats(owner)
				}

				if reset {
					log.Printf("[COMBATE] Projétil #%d destruiu o Boneco #%d!\n", p.ID, dummy.ID)
				}

				// Cometa Elemental: explosão em área de 2.8m
				if p.ProjType == protocol.ProjTypeElementalComet {
					s.triggerCometExplosion(p.OwnerID, p.PosX, p.PosZ, 2.8, damage/2, isCrit)
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
					)

					finalDamage, wasBlocked, newHP, isDead := mob.TakeDamage(damage)
					s.BroadcastCombatEvent(p.OwnerID, mob.ID, actionType, finalDamage, isCrit, newHP, mob.MaxHP)

					// Lifesteal do Dhampir (+8 HP)
					if ownerRace == protocol.RaceDhampir {
						owner.Heal(8)
						s.sendPlayerStats(owner)
					}

					log.Printf("[COMBATE] Projétil #%d (Tipo %d) atingiu Mob #%d (%s) causando %d dano (Bloqueado: %v) | HP: %d/%d\n",
						p.ID, p.ProjType, mob.ID, mob.Name, finalDamage, wasBlocked, newHP, mob.MaxHP)

					if isDead {
						log.Printf("[COMBATE] Mob #%d (%s) abatido por projétil!\n", mob.ID, mob.Name)
					}

					// Cometa Elemental: explosão em área de 2.8m
					if p.ProjType == protocol.ProjTypeElementalComet {
						s.triggerCometExplosion(p.OwnerID, p.PosX, p.PosZ, 2.8, damage/2, isCrit)
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

// triggerCometExplosion aplica dano em área (2.8m) na detonação do Cometa Elemental.
func (s *Server) triggerCometExplosion(ownerID uint32, cx, cz, radius float32, splashDmg uint16, isCrit uint8) {
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
			finalDmg, _, newHP, _ := mob.TakeDamage(splashDmg)
			s.BroadcastCombatEvent(ownerID, mob.ID, protocol.ActionSpecialSkill, finalDmg, isCrit, newHP, mob.MaxHP)
		}
	}
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

				// 6. Defesa da Vila pelo Garrick: Monstros a menos de 6.5m sofrem retaliação a cada 2s
				s.mu.RLock()
				garrick := s.npcs[1]
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
								s.BroadcastNPCSay(1, "Monstros perto da minha forja?! Provem do meu martelo!")
								finalDmg, _, newHP, isDead := mob.TakeDamage(80)
								s.BroadcastCombatEvent(1, mob.ID, protocol.ActionBasicAttack, finalDmg, 1, newHP, mob.MaxHP)
								if isDead {
									log.Printf("[WORLD] Garrick esmagou o Mob #%d com seu martelo!\n", mob.ID)
								}
							}
						}
					}
				}
			}

			// 5. Loop de Relógio, IA, Status e Proximidade a 1 Hz (a cada 30 ticks)
			aiTickCounter++
			if aiTickCounter >= GameTickRate {
				aiTickCounter = 0

				h, _, moon, weather := s.clock.GetTime()

				// Logging quando muda a hora cheia
				if changed, newH := s.clock.CheckHourChanged(); changed {
					log.Printf("[RELÓGIO] Hora do Mundo: %02d:00 | Fase da Lua: %d | Clima: %d\n", newH, moon, weather)
				}

				// Transmite o horário, fase da lua e clima atualizados (0x13: 5 bytes)
				s.BroadcastWorldTime()

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
						player.Mu.RUnlock()

						if triggered, dist := npc.TryTriggerApproach(pid, px, py, pz); triggered {
							log.Printf("[APROXIMACAO] Jogador %d aproximou-se do NPC '%s' (dist: %.2fm)\n", pid, npc.Name, dist)
							_ = luaengine.CallOnPlayerApproach(npc, pid, dist, pRace)
						}
					}
				}
				s.mu.RUnlock()
			}
		}
	}
}
