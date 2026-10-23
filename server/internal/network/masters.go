package network

import (
	"fmt"
	"log"
	"path/filepath"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// IDs dos Mestres de Classe adicionados para cobrir todas as classes básicas.
const (
	NPCNyx        uint32 = 111 // Nyx Sombraveloz — Lâmina Silente (4)
	NPCTao        uint32 = 112 // Mestre Tao Ferroventre — Punho Celeste (5)
	NPCIolanthe   uint32 = 113 // Iolanthe Mármore-Lunar — Escultor de Almas (9)
	NPCFiorella   uint32 = 114 // Madame Fiorella Agulhadouro — Tecelão Carmesim (11)
	NPCBartolomeu uint32 = 115 // Chef Bartolomeu Brasa-Alta — Mestre do Banquete (12)
	NPCThorne     uint32 = 116 // Thorne, o Eremita das Feras — Senhor das Feras (10, secreta)
)

// masterInteractRange é a distância máxima (m) até um Mestre para aprender a classe dele.
const masterInteractRange = 8.0

// thorneFriendshipNeeded é a Confiança mínima de Thorne para a prova secreta do Domador.
const thorneFriendshipNeeded = 60

// basicClassMasters lista quais NPCs ensinam cada classe básica (1 a 12).
var basicClassMasters = map[uint8][]uint32{
	protocol.ClassWarrior:      {105},
	protocol.ClassMage:         {108},
	protocol.ClassArcher:       {106, 109},
	protocol.ClassAssassin:     {NPCNyx},
	protocol.ClassFighter:      {NPCTao},
	protocol.ClassShieldBearer: {107},
	protocol.ClassBlacksmith:   {100},
	protocol.ClassAlchemist:    {103},
	protocol.ClassSculptor:     {NPCIolanthe},
	protocol.ClassTamer:        {NPCThorne},
	protocol.ClassWarTailor:    {NPCFiorella},
	protocol.ClassHuntingChef:  {NPCBartolomeu},
}

// basicClassHints diz ao jogador onde procurar o Mestre de cada classe.
var basicClassHints = map[uint8]string{
	protocol.ClassWarrior:      "Capitão Randel, no Quartel da Vila",
	protocol.ClassMage:         "Mestre Aurelius, na Torre Arcana (à noite, no pátio da torre)",
	protocol.ClassArcher:       "Guarda Valen (Avenida Central) ou Kaelen (Posto do Caçador, ao sul)",
	protocol.ClassAssassin:     "Nyx Sombraveloz — dizem que ela só aparece à noite, no beco atrás do Mercado Negro",
	protocol.ClassFighter:      "Mestre Tao Ferroventre, que treina perto da entrada do Bosque Sussurrante",
	protocol.ClassShieldBearer: "Irmã Seraphina, na Igreja da Luz",
	protocol.ClassBlacksmith:   "Garrick, na Forja da Vila",
	protocol.ClassAlchemist:    "Lyra, no Laboratório de Alquimia",
	protocol.ClassSculptor:     "Iolanthe Mármore-Lunar, entre as estátuas das Ruínas da Vigília",
	protocol.ClassTamer:        "??? — ninguém na vila ensina esta arte. Talvez alguém que viva entre as feras...",
	protocol.ClassWarTailor:    "Madame Fiorella, no Ateliê Carmesim da Vila",
	protocol.ClassHuntingChef:  "Chef Bartolomeu, na cozinha da Taverna",
}

// spawnClassMasters cria os novos Mestres de Classe e o Eremita secreto.
func (s *Server) spawnClassMasters(scriptsDir string, currentH int) []*world.NPC {
	night := currentH >= 18 || currentH < 6

	nyx := world.NewNPC(NPCNyx, "Nyx Sombraveloz", -58.0, 0.0, 52.0,
		filepath.Join(scriptsDir, "nyx.lua"), s.clock, s.BroadcastNPCSay)
	nyx.SetActive(night)

	tao := world.NewNPC(NPCTao, "Mestre Tao Ferroventre", 25.0, 0.0, 240.0,
		filepath.Join(scriptsDir, "tao.lua"), s.clock, s.BroadcastNPCSay)
	tao.SetZone(world.ZoneForest)
	tao.SetPatrolRoute([]world.Waypoint{{X: 25.0, Z: 240.0}, {X: 35.0, Z: 232.0}, {X: 25.0, Z: 224.0}, {X: 15.0, Z: 232.0}}, 1.6, 6.0)

	iolanthe := world.NewNPC(NPCIolanthe, "Iolanthe Mármore-Lunar", -30.0, 0.0, -235.0,
		filepath.Join(scriptsDir, "iolanthe.lua"), s.clock, s.BroadcastNPCSay)
	iolanthe.SetZone(world.ZoneRuins)

	fiorella := world.NewNPC(NPCFiorella, "Madame Fiorella Agulhadouro", 40.0, 0.0, 35.0,
		filepath.Join(scriptsDir, "fiorella.lua"), s.clock, s.BroadcastNPCSay)

	bartolomeu := world.NewNPC(NPCBartolomeu, "Chef Bartolomeu Brasa-Alta", -38.0, 0.0, 22.0,
		filepath.Join(scriptsDir, "bartolomeu.lua"), s.clock, s.BroadcastNPCSay)

	thorne := world.NewNPC(NPCThorne, "Thorne, o Eremita das Feras", -120.0, 0.0, 60.0,
		filepath.Join(scriptsDir, "thorne.lua"), s.clock, s.BroadcastNPCSay)
	thorne.SetZone(world.ZoneForest)

	return []*world.NPC{nyx, tao, iolanthe, fiorella, bartolomeu, thorne}
}

// updateClassMasterRoutines aplica as rotinas de horário dos novos Mestres (1 Hz).
func (s *Server) updateClassMasterRoutines(worldHour int) {
	s.mu.RLock()
	nyx := s.npcs[NPCNyx]
	fiorella := s.npcs[NPCFiorella]
	bartolomeu := s.npcs[NPCBartolomeu]
	s.mu.RUnlock()

	night := worldHour >= 18 || worldHour < 6
	if nyx != nil && nyx.GetActive() != night {
		nyx.SetActive(night) // Nyx só sai das sombras à noite
	}
	if fiorella != nil {
		fiorella.SetShopOpen(worldHour >= 8 && worldHour < 20)
	}
	if bartolomeu != nil {
		bartolomeu.SetShopOpen(worldHour >= 10 || worldHour < 2) // Cozinha aberta até as 02h
	}
}

// nearClassMaster verifica se o jogador está ao lado de um Mestre ativo que ensina a classe.
func (s *Server) nearClassMaster(player *world.Player, classID uint8) bool {
	player.Mu.RLock()
	px, py, pz, zone := player.PosX, player.PosY, player.PosZ, player.ZoneID
	player.Mu.RUnlock()

	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, id := range basicClassMasters[classID] {
		npc, ok := s.npcs[id]
		if !ok || !npc.GetActive() || npc.GetZone() != zone {
			continue
		}
		if npc.DistanceTo(px, py, pz) <= masterInteractRange {
			return true
		}
	}
	return false
}

// checkBasicClassRequest valida um pedido 0x30 de classe básica: só se aprende com o Mestre.
func (s *Server) checkBasicClassRequest(player *world.Player, classID uint8) (bool, string) {
	if classID < protocol.ClassWarrior || classID > protocol.ClassHuntingChef || classID == player.ClassID {
		return true, ""
	}
	if classID == protocol.ClassTamer && !player.TamerUnlocked {
		return false, "A arte do Senhor das Feras é secreta. Nenhum mestre da vila a ensina..."
	}
	if !s.nearClassMaster(player, classID) {
		return false, fmt.Sprintf("Para aprender esta classe, procure %s.", basicClassHints[classID])
	}
	return true, ""
}

// handleClassMasterInteract trata a conversa com os novos Mestres. Retorna true se a conversa foi consumida.
func (s *Server) handleClassMasterInteract(player *world.Player, npcID uint32) bool {
	pid := player.ID
	switch npcID {
	case NPCNyx:
		if player.HasItem(protocol.ItemDarkPoisonGland) {
			player.RemoveItem(protocol.ItemDarkPoisonGland, 1)
			pts := player.AddFriendship(npcID, 20)
			s.sendFriendshipSync(player, npcID)
			s.sendInventorySync(player)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Veneno de aranha do esgoto... você sabe agradar uma dama, #%d. [Afiança: %d/100]", pid, pts))
		}
		if player.ClassID == protocol.ClassNone {
			s.offerIdentityChange(player, player.RaceID, protocol.ClassAssassin, protocol.IdentityModeInitialChange)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Você me encontrou nas sombras, #%d. Poucos conseguem. Se aceitar, eu lhe ensino a ser uma Lâmina Silente — confirme quando estiver pronto.", pid))
			return true
		}
	case NPCTao:
		if player.HasItem(protocol.ItemAlphaWolfPelt) {
			player.RemoveItem(protocol.ItemAlphaWolfPelt, 1)
			pts := player.AddFriendship(npcID, 25)
			s.sendFriendshipSync(player, npcID)
			s.sendInventorySync(player)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Derrubou o Alfa? Seu espírito é forte, #%d! Vou usar esta pele no meu tatame. [Afiança: %d/100]", pid, pts))
		}
		if player.ClassID == protocol.ClassNone {
			s.offerIdentityChange(player, player.RaceID, protocol.ClassFighter, protocol.IdentityModeInitialChange)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Respire fundo, #%d. O punho é só o fim do caminho; a força nasce dos pés. Confirme e eu lhe ensinarei o caminho do Punho Celeste.", pid))
			return true
		}
	case NPCIolanthe:
		if player.HasItem(protocol.ItemStarlightRing) {
			player.RemoveItem(protocol.ItemStarlightRing, 1)
			pts := player.AddFriendship(npcID, 20)
			s.sendFriendshipSync(player, npcID)
			s.sendInventorySync(player)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("A luz das estrelas presa num anel... Vou incrustá-lo nos olhos da minha próxima estátua. Obrigada, #%d. [Afiança: %d/100]", pid, pts))
		}
		if player.ClassID == protocol.ClassNone {
			s.offerIdentityChange(player, player.RaceID, protocol.ClassSculptor, protocol.IdentityModeInitialChange)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Toda pedra guarda uma alma esperando o cinzel certo, #%d. Confirme e eu lhe mostrarei como despertá-las — o ofício do Escultor de Almas.", pid))
			return true
		}
	case NPCFiorella:
		if player.HasItem(protocol.ItemSilverMoonAmulet) {
			player.RemoveItem(protocol.ItemSilverMoonAmulet, 1)
			pts := player.AddFriendship(npcID, 20)
			s.sendFriendshipSync(player, npcID)
			s.sendInventorySync(player)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Prata lunar! Darling, isto vai virar o fio mais bonito da minha coleção. [Afiança: %d/100]", pts))
		}
		if player.ClassID == protocol.ClassNone {
			s.offerIdentityChange(player, player.RaceID, protocol.ClassWarTailor, protocol.IdentityModeInitialChange)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Que postura, #%d! Com uma agulha e um carretel de aço eu faço de você uma obra de arte letal. Confirme e entre para o Ateliê como Tecelão Carmesim.", pid))
			return true
		}
	case NPCBartolomeu:
		if player.HasItem(protocol.ItemFreshWolfBlood) {
			player.RemoveItem(protocol.ItemFreshWolfBlood, 1)
			pts := player.AddFriendship(npcID, 15)
			s.sendFriendshipSync(player, npcID)
			s.sendInventorySync(player)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Sangue de lobo fresquinho! Hoje tem chouriço da casa, #%d! [Afiança: %d/100]", pid, pts))
		}
		if player.ClassID == protocol.ClassNone {
			s.offerIdentityChange(player, player.RaceID, protocol.ClassHuntingChef, protocol.IdentityModeInitialChange)
			s.BroadcastNPCSay(npcID, fmt.Sprintf("Fome de aventura, é? Na minha cozinha, quem caça é quem come! Confirme e vista o avental de Mestre do Banquete, #%d.", pid))
			return true
		}
	case NPCThorne:
		return s.handleThorneQuest(player)
	}
	return false
}

// addThorneTrust soma confiança com Thorne (separada da Afiança comum, que sobe só de conversar).
func addThorneTrust(player *world.Player, amount int) int {
	player.Mu.Lock()
	defer player.Mu.Unlock()
	player.ThorneTrust += amount
	if player.ThorneTrust > 100 {
		player.ThorneTrust = 100
	}
	return player.ThorneTrust
}

// handleThorneQuest implementa a missão secreta do Senhor das Feras:
// 1) Encontrar Thorne no fundo do Bosque; 2) ganhar a confiança dele com presas e peles de lobo
// (Afiança 60+); 3) voltar numa noite de Lua Cheia ou sob a Noite de Vaga-lumes no Bosque.
func (s *Server) handleThorneQuest(player *world.Player) bool {
	pid := player.ID
	npcID := NPCThorne
	if player.HasItem(protocol.ItemAlphaWolfPelt) {
		player.RemoveItem(protocol.ItemAlphaWolfPelt, 1)
		pts := addThorneTrust(player, 25)
		player.AddFriendship(npcID, 25)
		s.sendFriendshipSync(player, npcID)
		s.sendInventorySync(player)
		s.BroadcastNPCSay(npcID, fmt.Sprintf("A pele do Alfa... Você o enfrentou de frente. Os lobos respeitam isso, e eu também. [Confiança: %d/%d]", pts, thorneFriendshipNeeded))
		return true
	}
	if player.HasItem(protocol.ItemSharpWolfFang) {
		player.RemoveItem(protocol.ItemSharpWolfFang, 1)
		pts := addThorneTrust(player, 15)
		player.AddFriendship(npcID, 15)
		s.sendFriendshipSync(player, npcID)
		s.sendInventorySync(player)
		s.BroadcastNPCSay(npcID, fmt.Sprintf("Uma presa... Vou devolvê-la à terra onde a matilha descansa. [Confiança: %d/%d]", pts, thorneFriendshipNeeded))
		return true
	}

	if player.ClassID == protocol.ClassTamer {
		s.BroadcastNPCSay(npcID, "A fera ao seu lado está saudável e feliz. Continue assim, irmão da matilha.")
		return true
	}

	player.Mu.RLock()
	trust := player.ThorneTrust
	player.Mu.RUnlock()
	if trust < thorneFriendshipNeeded {
		s.BroadcastNPCSay(npcID, fmt.Sprintf("Hm. Mais um caçador. As feras não confiam em quem só sabe matar... Traga-me o que restou dos lobos que você abateu — presas, peles — e talvez eu converse. [Confiança: %d/%d]", trust, thorneFriendshipNeeded))
		return true
	}

	_, _, moon, _ := s.clock.GetTime()
	weather := s.clock.GetZoneWeather(world.ZoneForest)
	hour := s.clock.GetCurrentHour()
	night := hour >= 18 || hour < 6
	if !(night && (moon == world.MoonPhaseFull || weather == world.WeatherFireflies)) {
		s.BroadcastNPCSay(npcID, "Você tem meu respeito. Volte numa noite de Lua Cheia, ou quando os vaga-lumes dançarem no Bosque. Só então a matilha virá ouvir seu chamado.")
		return true
	}

	player.Mu.Lock()
	player.TamerUnlocked = true
	player.Mu.Unlock()
	s.offerIdentityChange(player, player.RaceID, protocol.ClassTamer, protocol.IdentityModeInitialChange)
	s.BroadcastNPCSay(npcID, fmt.Sprintf("Ouça... os uivos estão respondendo a você, #%d. Uma fera escolheu caminhar ao seu lado. Se aceitar o vínculo, confirme — e torne-se um Senhor das Feras.", pid))
	log.Printf("[CLASSE SECRETA] Jogador #%d completou a prova de Thorne (Senhor das Feras)\n", pid)
	return true
}
