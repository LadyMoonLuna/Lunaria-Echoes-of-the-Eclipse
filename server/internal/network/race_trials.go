package network

import (
	"fmt"
	"log"
	"math"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Provações de Linhagem: desafios, missões secretas e enigmas que despertam as raças secretas.
// Três tipos de gatilho:
//   - trialKill:     derrotar monstros específicos (com contagem e condições);
//   - trialInteract: falar com um NPC sob certas condições (Afiança, item, hora, lua...);
//   - trialPlace:    enigma de lugar — permanecer num ponto exato do mapa durante N segundos
//                    enquanto as condições (hora, lua, clima) estiverem certas.
// Ao concluir, a raça é oferecida no modal de confirmação (o jogador mantém a classe).

type trialKind uint8

const (
	trialKill trialKind = iota
	trialInteract
	trialPlace
)

const anyHour = -1
const anyMoon = -1

type raceTrial struct {
	race      uint8
	kind      trialKind
	title     string
	mobType   uint8   // trialKill
	count     float32 // abates (trialKill) ou segundos parado (trialPlace)
	npcID     uint32  // trialInteract
	minFriend int     // trialInteract: Afiança mínima com o NPC
	zone      int     // -1 = qualquer zona
	x, z, r   float32 // trialPlace
	hourFrom  int     // intervalo de horas [hourFrom, hourTo] (pode cruzar a meia-noite)
	hourTo    int
	moon      int
	weathers  []uint8 // vazio = qualquer clima
	item      uint8   // item consumido ao concluir (0 = nenhum)
	minLevel  uint8
	reqRaces  []uint8 // raças de origem permitidas (vazio = qualquer)
	done      string  // fala ao concluir
}

var raceTrials = []raceTrial{
	{race: protocol.RacePrimordialLycanthrope, kind: trialKill, title: "Caçada da Lua de Sangue", mobType: protocol.MobTypeLycanthropeAlpha, count: 1, zone: -1, hourFrom: anyHour, moon: int(world.MoonPhaseBloodMoon), reqRaces: []uint8{protocol.RaceVarkai, protocol.RaceWolfDemi, protocol.RaceFrenzyBeast},
		done: "O sangue do Licantropo Alfa ferve em suas veias sob a Lua de Sangue... Você desperta como LUPHARION!"},
	{race: protocol.RaceCelestine, kind: trialPlace, title: "Vigília da Aurora", zone: int(world.ZoneChurch), x: 0, z: 0, r: 5, count: 30, hourFrom: 5, hourTo: 6, moon: anyMoon, item: protocol.ItemSacredTorch,
		done: "A Tocha Sagrada se acende sozinha com o primeiro raio da aurora. Asas de luz brotam de suas costas: SERAPHEL!"},
	{race: protocol.RaceAbyssal, kind: trialPlace, title: "Olhar o Eclipse", zone: int(world.ZoneSanctuary), x: 0, z: 0, r: 8, count: 20, hourFrom: anyHour, moon: int(world.MoonPhaseEclipse),
		done: "Você encarou o Eclipse sem desviar os olhos. O abismo encarou de volta... e o aceitou: UMBRYSS!"},
	{race: protocol.RaceRunicAutomaton, kind: trialInteract, title: "Coração de Runas", npcID: 100, minFriend: 70, zone: -1, hourFrom: anyHour, moon: anyMoon, item: protocol.ItemRunicWarhammer,
		done: "Garrick grava as runas do Malho no seu peito. Engrenagens e magia passam a bater no lugar do coração: RUNARIC!"},
	{race: protocol.RaceSylvari, kind: trialPlace, title: "Florescer no Bosque", zone: int(world.ZoneForest), x: 0, z: 240, r: 10, count: 30, hourFrom: 6, hourTo: 17, moon: anyMoon, weathers: []uint8{world.WeatherPetals, world.WeatherRainbow},
		done: "As pétalas pousam em você e criam raízes. A seiva do Bosque corre em suas veias: SYLVARI!"},
	{race: protocol.RaceMyconid, kind: trialPlace, title: "Comunhão dos Esporos", zone: int(world.ZoneAncientSewers), x: 0, z: 0, r: 15, count: 30, hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherSporeFog}, item: protocol.ItemOrganicTrash,
		done: "Você oferece restos à colônia e respira os esporos sem medo. O micélio te reconhece: MYCONID!"},
	{race: protocol.RaceAshDragonborn, kind: trialKill, title: "Batismo de Cinzas", mobType: protocol.MobTypeIronEnforcer, count: 5, zone: int(world.ZoneAshFrontier), hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherAshfall, world.WeatherHeatWave},
		done: "Cinco Executores caem sob a chuva de cinzas. Escamas negras cobrem sua pele: IGNIVARN!"},
	{race: protocol.RaceChimera, kind: trialKill, title: "O Experimento Nº 1", mobType: protocol.MobTypeStitchedChimeraZero, count: 1, zone: -1, hourFrom: anyHour, moon: anyMoon, item: protocol.ItemChimeraFleshPart,
		done: "O retalho quimérico se costura sozinho ao seu corpo quando a Quimera cai. Você é o próximo experimento: CHIMERYTH!"},
	{race: protocol.RaceThalassian, kind: trialPlace, title: "Abraço da Monção", zone: int(world.ZoneForest), x: 0, z: 200, r: 25, count: 40, hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherMonsoon},
		done: "A Monção não te derruba — ela te abraça. Guelras se abrem no seu pescoço: THALASSIANO!"},
	{race: protocol.RaceCambion, kind: trialPlace, title: "Pacto da Meia-Noite", zone: int(world.ZoneAshFrontier), x: 0, z: 0, r: 10, count: 20, hourFrom: 0, hourTo: 0, moon: anyMoon, item: protocol.ItemDarkPoisonGland,
		done: "Você bebe o veneno à meia-noite no coração das cinzas. O enxofre responde em seu sangue: CAMBION!"},
	{race: protocol.RaceNephilim, kind: trialPlace, title: "Crepúsculo da Lua Cheia", zone: int(world.ZoneSanctuary), x: 0, z: 0, r: 10, count: 30, hourFrom: 17, hourTo: 18, moon: int(world.MoonPhaseFull),
		done: "Entre o último sol e a primeira lua, luz e sombra se fundem em você: NEPHILIM!"},
	{race: protocol.RaceHalfCelestial, kind: trialInteract, title: "O Olho do Arauto", npcID: 107, minFriend: 40, zone: -1, hourFrom: 6, hourTo: 17, moon: anyMoon, item: protocol.ItemHeraldEclipseEye,
		done: "Irmã Seraphina purifica o Olho do Arauto e a luz que ele roubou volta... para você: AURELITH!"},
	{race: protocol.RacePyromancer, kind: trialPlace, title: "Dança na Chuva de Cinzas", zone: int(world.ZoneAshFrontier), x: 0, z: 0, r: 30, count: 45, hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherAshfall},
		done: "As brasas que caem não te queimam mais — elas te alimentam: PYRAEL!"},
	{race: protocol.RaceFrostGiant, kind: trialKill, title: "Herança de Ymir", mobType: protocol.MobTypeYmirFrostPatriarch, count: 1, zone: -1, hourFrom: anyHour, moon: anyMoon,
		done: "O Patriarca cai e seu gelo eterno escolhe um novo herdeiro: JOTUNAR!"},
	{race: protocol.RaceDragonEarth, kind: trialKill, title: "Pele de Pedra", mobType: protocol.MobTypeStoneGargoyle, count: 10, zone: -1, hourFrom: anyHour, moon: anyMoon, item: protocol.ItemPrimordialDragonScale,
		done: "Dez Gárgulas viram pó, e a Escama Primordial absorve a pedra delas: TERRAVYRN!"},
	{race: protocol.RaceDragonWater, kind: trialPlace, title: "Escama na Monção", zone: int(world.ZoneForest), x: 0, z: 200, r: 30, count: 30, hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherMonsoon, world.WeatherRain}, item: protocol.ItemPrimordialDragonScale,
		done: "A Escama Primordial bebe a chuva até brilhar como o mar: HYDRAVYRN!"},
	{race: protocol.RaceDragonLightning, kind: trialPlace, title: "Para-Raios Vivo", zone: int(world.ZoneRuins), x: 0, z: -235, r: 30, count: 30, hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherThunderstorm}, item: protocol.ItemPrimordialDragonScale,
		done: "Um raio atinge a Escama Primordial na sua mão. Você não cai — você ruge: FULGRAVYRN!"},
	{race: protocol.RaceDragonMystic, kind: trialPlace, title: "Olho da Tempestade Arcana", zone: int(world.ZoneSanctuary), x: 0, z: 0, r: 20, count: 30, hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherArcaneStorm}, item: protocol.ItemPrimordialDragonScale,
		done: "A Tempestade Arcana se dobra ao redor da Escama e entra em você: ARCAVYRN!"},
	{race: protocol.RaceOrc, kind: trialInteract, title: "Banquete do Guerreiro", npcID: NPCBartolomeu, minFriend: 50, zone: -1, hourFrom: anyHour, moon: anyMoon, item: protocol.ItemCookedNobleMeat, minLevel: 10,
		done: "Bartolomeu serve o Banquete do Guerreiro e brinda com você. Presas crescem no seu sorriso: ORKHAN!"},
	{race: protocol.RaceDwarf, kind: trialInteract, title: "Juramento da Bigorna", npcID: 100, minFriend: 100, zone: -1, hourFrom: anyHour, moon: anyMoon, item: protocol.ItemIronOre,
		done: "Garrick bate o Minério na bigorna e jura você como irmão de forja: DVERGAR!"},
	{race: protocol.RaceElf, kind: trialInteract, title: "Canção das Estátuas", npcID: NPCIolanthe, minFriend: 60, zone: -1, hourFrom: 18, hourTo: 5, moon: int(world.MoonPhaseFull),
		done: "Iolanthe canta com as estátuas na Lua Cheia e você entende cada palavra: ELARIN!"},
	{race: protocol.RaceSolarElf, kind: trialPlace, title: "Sol a Pino", zone: int(world.ZoneVillage), x: 0, z: 0, r: 8, count: 30, hourFrom: 12, hourTo: 12, moon: anyMoon, weathers: []uint8{world.WeatherClear, world.WeatherHeatWave}, minLevel: 15,
		done: "Ao meio-dia, sua sombra desaparece por completo. Azgher te marcou: SOLARIN!"},
	{race: protocol.RaceLunarElf, kind: trialPlace, title: "Lua a Pino", zone: int(world.ZoneVillage), x: 0, z: 0, r: 8, count: 30, hourFrom: 0, hourTo: 0, moon: int(world.MoonPhaseFull), minLevel: 15,
		done: "À meia-noite da Lua Cheia, a luz prateada se recusa a sair de você. Tenebra te marcou: LUNARIN!"},
	{race: protocol.RaceFairy, kind: trialPlace, title: "Ciranda dos Vaga-lumes", zone: int(world.ZoneForest), x: 0, z: 240, r: 15, count: 45, hourFrom: 18, hourTo: 5, moon: anyMoon, weathers: []uint8{world.WeatherFireflies},
		done: "Os vaga-lumes formam um círculo ao seu redor e você encolhe, leve como eles: FAELITH!"},
	{race: protocol.RaceGoblin, kind: trialInteract, title: "Sócio do Contrabando", npcID: 104, minFriend: 60, zone: -1, hourFrom: 18, hourTo: 5, moon: anyMoon,
		done: "Varis divide o lucro com você pela primeira vez. Seus dedos ficam ágeis... e suas orelhas, enormes: GNARLIN!"},
	{race: protocol.RaceTurtleDemi, kind: trialPlace, title: "Paciência da Chuva", zone: int(world.ZoneForest), x: 0, z: 240, r: 3, count: 60, hourFrom: anyHour, moon: anyMoon, weathers: []uint8{world.WeatherRain, world.WeatherDrizzle},
		done: "Um minuto inteiro parado na chuva sem se mexer. Uma carapaça cresce em suas costas: TESTUDAR!"},
	{race: protocol.RaceHalfDemon, kind: trialInteract, title: "Segredo de Nyx", npcID: NPCNyx, minFriend: 60, zone: -1, hourFrom: anyHour, moon: int(world.MoonPhaseBloodMoon),
		done: "Sob a Lua de Sangue, Nyx revela a marca demoníaca que esconde — e a passa para você: LILITARA!"},
	{race: protocol.RaceWolfDemi, kind: trialInteract, title: "Adotado pela Matilha", npcID: NPCThorne, minFriend: 80, zone: -1, hourFrom: 18, hourTo: 5, moon: int(world.MoonPhaseFull),
		done: "Cinza uiva para você e a matilha responde. Orelhas e instinto de lobo despertam: ULVAR!"},
	{race: protocol.RaceManamancer, kind: trialPlace, title: "Meditação na Torre Arcana", zone: int(world.ZoneMageTower), x: 0, z: 0, r: 6, count: 60, hourFrom: 0, hourTo: 3, moon: anyMoon, minLevel: 20,
		done: "Na madrugada da Torre, sua Mana transborda e se funde com sua vida: MANAMANTE!"},
}

// RaceTrialHint devolve uma pista da provação de cada raça (usada pelos NPCs de rumores).
func raceTrialByRace(race uint8) *raceTrial {
	for i := range raceTrials {
		if raceTrials[i].race == race {
			return &raceTrials[i]
		}
	}
	return nil
}

func hourInRange(h, from, to int) bool {
	if from == anyHour {
		return true
	}
	if from <= to {
		return h >= from && h <= to
	}
	return h >= from || h <= to // cruza a meia-noite
}

// trialConditionsMet verifica as condições comuns de uma provação para o jogador agora.
func (s *Server) trialConditionsMet(p *world.Player, t *raceTrial) bool {
	p.Mu.RLock()
	race, level, zone := p.RaceID, p.Level, p.ZoneID
	p.Mu.RUnlock()
	if race == t.race || level < t.minLevel {
		return false
	}
	if t.zone >= 0 && uint8(t.zone) != zone {
		return false
	}
	if len(t.reqRaces) > 0 {
		ok := false
		for _, r := range t.reqRaces {
			if r == race {
				ok = true
			}
		}
		if !ok {
			return false
		}
	}
	h, _, moon, _ := s.clock.GetTime()
	if !hourInRange(int(h), t.hourFrom, t.hourTo) {
		return false
	}
	if t.moon != anyMoon && int(moon) != t.moon {
		return false
	}
	if len(t.weathers) > 0 {
		w := s.clock.GetZoneWeather(zone)
		ok := false
		for _, tw := range t.weathers {
			if tw == w {
				ok = true
			}
		}
		if !ok {
			return false
		}
	}
	if t.item != 0 && !p.HasItem(t.item) {
		return false
	}
	return true
}

// completeRaceTrial consome o item e oferece a raça no modal de confirmação.
func (s *Server) completeRaceTrial(p *world.Player, t *raceTrial) {
	if t.item != 0 {
		p.RemoveItem(t.item, 1)
		s.sendInventorySync(p)
	}
	p.Mu.Lock()
	delete(p.TrialProgress, t.race)
	classID := p.ClassID
	p.Mu.Unlock()
	s.offerIdentityChange(p, t.race, classID, protocol.IdentityModeInitialChange)
	s.BroadcastNPCSay(0, fmt.Sprintf("[PROVAÇÃO DE LINHAGEM: %s] Jogador #%d — %s Confirme no modal para despertar.", t.title, p.ID, t.done))
	log.Printf("[PROVAÇÃO] Jogador #%d concluiu '%s' (Raça %d)\n", p.ID, t.title, t.race)
}

func addTrialProgress(p *world.Player, race uint8, amount float32) float32 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.TrialProgress == nil {
		p.TrialProgress = make(map[uint8]float32)
	}
	p.TrialProgress[race] += amount
	return p.TrialProgress[race]
}

func resetTrialProgress(p *world.Player, race uint8) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.TrialProgress != nil {
		delete(p.TrialProgress, race)
	}
}

// checkRaceTrialsOnKill é chamado quando um jogador derrota um monstro.
func (s *Server) checkRaceTrialsOnKill(p *world.Player, mobType uint8) {
	for i := range raceTrials {
		t := &raceTrials[i]
		if t.kind != trialKill || t.mobType != mobType || !s.trialConditionsMet(p, t) {
			continue
		}
		if addTrialProgress(p, t.race, 1) >= t.count {
			s.completeRaceTrial(p, t)
			return
		}
	}
}

// checkRaceTrialsOnInteract é chamado ao falar com um NPC. Retorna true se uma provação foi concluída.
func (s *Server) checkRaceTrialsOnInteract(p *world.Player, npcID uint32) bool {
	for i := range raceTrials {
		t := &raceTrials[i]
		if t.kind != trialInteract || t.npcID != npcID || p.GetFriendship(npcID) < t.minFriend || !s.trialConditionsMet(p, t) {
			continue
		}
		s.completeRaceTrial(p, t)
		return true
	}
	return false
}

// updatePlaceTrials avança os enigmas de lugar (1 Hz): quem está no ponto certo, na hora certa, acumula segundos.
func (s *Server) updatePlaceTrials() {
	s.mu.RLock()
	players := make([]*world.Player, 0, len(s.players))
	for _, p := range s.players {
		players = append(players, p)
	}
	s.mu.RUnlock()

	for _, p := range players {
		p.Mu.RLock()
		px, pz := p.PosX, p.PosZ
		p.Mu.RUnlock()
		for i := range raceTrials {
			t := &raceTrials[i]
			if t.kind != trialPlace {
				continue
			}
			inside := float32(math.Hypot(float64(px-t.x), float64(pz-t.z))) <= t.r
			if !inside || !s.trialConditionsMet(p, t) {
				resetTrialProgress(p, t.race)
				continue
			}
			prog := addTrialProgress(p, t.race, 1)
			if prog == 1 {
				s.BroadcastNPCSay(0, fmt.Sprintf("[PROVAÇÃO] Jogador #%d sente algo antigo despertar... (%s) — permaneça aqui.", p.ID, t.title))
			}
			if prog >= t.count {
				s.completeRaceTrial(p, t)
				break
			}
		}
	}
}
