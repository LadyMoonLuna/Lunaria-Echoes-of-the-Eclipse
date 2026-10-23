package world

import (
	"fmt"
	"time"
)

// Mundo Vivo (Fase 1, Parte 2): combate contra NPCs, crime, morte permanente, túmulos,
// sucessão de ofícios por aprendizes e contratação/migração de NPCs.

const (
	ActivityHunting  = "Caçando Criminoso"
	ActivityFighting = "Lutando"
	ActivityStudying = "Estudando Ofício do Mestre Caído"
	ActivityHired    = "Seguindo o Contratante"

	WantedDuration       float32 = 180 // segundos como PROCURADO
	BountyPerHit         uint32  = 100 // cada golpe num cidadão
	BountyPerKill        uint32  = 300 // cada assassinato
	BountyStreakBonus    uint32  = 200 // +200 por assassinato consecutivo (2º = +200, 3º = +400...)
	MurdersForPermanent          = 6   // 6+ assassinatos: procurado para sempre nas cidades vizinhas
	LawlessPursuitRadius float32 = 40  // Guardas entram nos Esgotos/Mercado Negro, mas não vão longe
	NecroUrgentBounty    uint32  = 1500
	JailGrace                    = 30 * time.Second // após a cela, a Guarda espera antes de voltar a caçar
	GuardHuntSpeedMult   float32 = 1.35
	GuardBaseSpeed       float32 = 3.2
	JailDuration                 = 60 * time.Second
	JailX, JailZ         float32 = -10, -14 // Pátio do Quartel

	NPCStrikeRange    float32 = 2.6
	NPCStrikeInterval         = 1500 * time.Millisecond

	StudySecondsToGraduate float32 = 600 // 10 min de estudo na Mesa de Blueprints
	ApprenticeTrainingFee  uint32  = 300
	HireFee                uint32  = 50000
	HireMinFriendship              = 60 // 3 corações
)

// NPCs que revidam e o dano de cada golpe.
var CombatNPCs = map[uint32]int{100: 55, 105: 70, 106: 65, 109: 60}

// Guardas Reais (caçam criminosos).
var GuardNPCs = []uint32{105, 106}

// NPCs que não são cidadãos da vila (atacá-los não é crime).
var nonCitizens = map[uint32]bool{104: true, 110: true}

// IsVillageCitizen: atacar este NPC é crime.
func IsVillageCitizen(npcID uint32) bool { return !nonCitizens[npcID] }

// Zonas sem lei: a Guarda só entra um pouco, perseguindo.
func IsLawlessZone(zone uint8) bool { return zone == ZoneAncientSewers || zone == ZoneBlackMarket }

// City: cidade com Guarda própria; Zones são suas áreas e Lawless as zonas sem lei coladas a ela.
type City struct {
	ID      uint8
	Name    string
	Zones   []uint8
	Lawless map[uint8][2]float32 // zona sem lei -> ponto de chegada pelo portal
	ExitTo  map[uint8][2]float32 // zona sem lei -> ponto de volta na cidade
}

var Cities = []City{
	{ID: 1, Name: "Vila do Refúgio", Zones: []uint8{ZoneVillage, ZoneChurch, ZoneMageTower},
		Lawless: map[uint8][2]float32{ZoneAncientSewers: {0, 0}, ZoneBlackMarket: {0, 30}},
		ExitTo:  map[uint8][2]float32{ZoneAncientSewers: {-55, -50}, ZoneBlackMarket: {-40, 40}}},
}

// CityOfZone devolve a cidade a que a zona pertence (0 = nenhuma).
func CityOfZone(zone uint8) uint8 {
	for _, c := range Cities {
		for _, z := range c.Zones {
			if z == zone {
				return c.ID
			}
		}
	}
	return 0
}

// CityByID busca a cidade.
func CityByID(id uint8) (City, bool) {
	for _, c := range Cities {
		if c.ID == id {
			return c, true
		}
	}
	return City{}, false
}

// CityName devolve o nome da cidade.
func CityName(id uint8) string {
	if c, ok := CityByID(id); ok {
		return c.Name
	}
	return "região"
}

// Professions: ofício exibido no anúncio de morte e no título do sucessor.
var Professions = map[uint32]string{
	100: "Ferreiro", 103: "Alquimista", 104: "Mercador das Sombras", 105: "Capitão da Guarda", 106: "Guarda Real",
	107: "Sacerdotisa", 108: "Arcanista", 109: "Batedor", 111: "Mestra das Lâminas", 112: "Mestre de Punhos",
	113: "Escultora", 114: "Tecelã", 115: "Cozinheiro", 116: "Domador",
	117: "Aprendiz da Forja", 118: "Aprendiz de Alquimia", 119: "Ajudante de Cozinha",
}

// Apprentice: jovem morador que pode herdar o ofício de um mestre caído.
type Apprentice struct {
	ID     uint32
	Name   string
	Master uint32
	X, Z   float32
	Title  string // título ao se formar
}

var Apprentices = []Apprentice{
	{117, "Bran", 100, 26, 22, "Novo Ferreiro da Vila"},
	{118, "Pip", 103, 26, -18, "Nova Alquimista da Vila"},
	{119, "Tilda", 115, -34, 20, "Nova Cozinheira da Vila"},
}

func init() {
	for _, a := range Apprentices {
		NPCStarts[a.ID] = NPCStart{HP: 600, Gold: 60, Personality: PersonalityHonorable}
	}
}

// ProfessionName devolve o ofício do NPC.
func (npc *NPC) ProfessionName() string {
	if npc.Profession != 0 && npc.Profession != npc.ID {
		return Professions[npc.Profession]
	}
	if p := Professions[npc.ID]; p != "" {
		return p
	}
	return "Morador"
}

// Tombstone: memorial permanente onde um NPC morreu.
type Tombstone struct {
	NPCID      uint32
	Name       string
	Profession string
	Killer     string
	Zone       uint8
	X, Z       float32
	DiedAt     time.Time

	// Parte 3: o corpo é levado ao cemitério; sem cuidado pode voltar como zumbi
	MaxHP          int
	Buried         bool
	Slot           int
	Carried        bool // o Coveiro já recolheu o corpo
	KilledByZombie bool
	Purified       bool
	NecroTried     bool
	Rose           bool // ergueu-se como zumbi
	LastRoll       time.Time
}

// Processed: cova purificada, já tentada por um Necromante ou já erguida não volta mais.
func (t *Tombstone) Processed() bool { return t.Purified || t.NecroTried || t.Rose }

// TakeDamage fere o NPC. Retorna o HP restante e se morreu agora (morte permanente).
func (npc *NPC) TakeDamage(dmg int) (int, bool) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	if npc.IsDead || !npc.IsActive || dmg <= 0 {
		return npc.HP, false
	}
	npc.HP -= dmg
	if npc.HP > 0 {
		return npc.HP, false
	}
	npc.markDeadLocked()
	return 0, true
}

// markDeadLocked aplica a morte permanente (chamar com o NPC travado).
func (npc *NPC) markDeadLocked() {
	npc.HP = 0
	npc.IsDead = true
	npc.IsActive = false
	npc.ShopOpen = false
	npc.MoveSpeed = 0
	npc.Life.Plan = nil
	npc.Life.Following = 0
	npc.Life.HuntTarget = 0
	npc.CurrentActivity = ActivityDead
}

// TakeEstate esvazia estoque, matérias-primas e ouro do NPC morto (o espólio vai ao chão).
func (npc *NPC) TakeEstate() (items map[uint16]int, gold uint32) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	items = map[uint16]int{}
	for k, v := range npc.ShopStock {
		items[k] += v
	}
	for k, v := range npc.RawMaterials {
		items[k] += v
	}
	npc.ShopStock = map[uint16]int{}
	npc.RawMaterials = map[uint16]int{}
	gold, npc.Gold = npc.Gold, 0
	return items, gold
}

// Graduate transforma o aprendiz no novo mestre do ofício (nível 1).
func (npc *NPC) Graduate(master uint32, title string, home [2]float32, homeZone uint8) {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	npc.Profession = master
	npc.ProfessionLevel = 1
	npc.CraftCount = 0
	if i := indexOfComma(npc.Name); i >= 0 {
		npc.Name = npc.Name[:i]
	}
	npc.Name = fmt.Sprintf("%s, %s", npc.Name, title)
	npc.Life.StudyingFor = 0
	npc.Life.StudyProgress = 0
	npc.Life.Home = home
	npc.Life.HomeZone = homeZone
	npc.Life.BuyOrders = map[uint16]BuyOrder{}
	npc.Life.OrderSince = map[uint16]time.Time{}
	npc.ShopOpen = true
	npc.CurrentActivity = ActivityWorking
}

func indexOfComma(s string) int {
	for i := 0; i < len(s); i++ {
		if s[i] == ',' {
			return i
		}
	}
	return -1
}

// CraftIntervalFor: mestres experientes fabricam mais rápido (nível 1 = 1,5x mais lento, nível 10 = normal).
func CraftIntervalFor(level int) time.Duration {
	if level >= 10 {
		return CraftInterval
	}
	if level < 1 {
		level = 1
	}
	return time.Duration(float64(CraftInterval) * (1.5 - 0.05*float64(level)))
}

// RegisterCraft conta uma peça fabricada e sobe o nível do ofício a cada 5 peças (até 10).
func (npc *NPC) registerCraftLocked() bool {
	npc.CraftCount++
	if npc.ProfessionLevel < 10 && npc.CraftCount%5 == 0 {
		npc.ProfessionLevel++
		return true
	}
	return false
}

// RegisterCraft (chamar com o NPC travado): devolve true se subiu de nível.
func (npc *NPC) RegisterCraft() bool { return npc.registerCraftLocked() }

// --- Crime do jogador ---

// CrimeResult descreve o efeito de um crime na ficha do jogador.
type CrimeResult struct {
	WasWanted       bool
	Bounty          uint32 // recompensa total depois do crime
	Added           uint32
	Murders         int
	BecamePermanent bool
}

// RegisterHit soma +100 por golpe num cidadão e renova o tempo de procurado.
func (p *Player) RegisterHit() CrimeResult {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	r := CrimeResult{WasWanted: p.isWantedLocked()}
	p.WantedTimer = WantedDuration
	p.BountyGold += BountyPerHit
	r.Added, r.Bounty, r.Murders = BountyPerHit, p.BountyGold, p.MurderCount
	return r
}

// RegisterMurder soma +300 e +200 por assassinato consecutivo; no 6º, procurado para sempre nas cidades.
func (p *Player) RegisterMurder() CrimeResult {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	r := CrimeResult{WasWanted: p.isWantedLocked()}
	add := BountyPerKill + BountyStreakBonus*uint32(p.KillStreak)
	p.KillStreak++
	p.MurderCount++
	p.WantedTimer = WantedDuration
	p.BountyGold += add
	if p.MurderCount >= MurdersForPermanent && !p.everyCityPermanentLocked() {
		for _, c := range Cities {
			p.markPermanentLocked(c.ID)
		}
		r.BecamePermanent = true
	}
	r.Added, r.Bounty, r.Murders = add, p.BountyGold, p.MurderCount
	return r
}

func (p *Player) markPermanentLocked(city uint8) {
	if p.PermanentWanted == nil {
		p.PermanentWanted = map[uint8]bool{}
	}
	p.PermanentWanted[city] = true
}

func (p *Player) everyCityPermanentLocked() bool {
	for _, c := range Cities {
		if !p.PermanentWanted[c.ID] {
			return false
		}
	}
	return true
}

// MarkPermanentWanted: procurado para sempre na cidade (fuga para zona sem lei, necromancia testemunhada).
func (p *Player) MarkPermanentWanted(city uint8) bool {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.PermanentWanted[city] {
		return false
	}
	p.markPermanentLocked(city)
	return true
}

// AddBounty soma uma recompensa extra (ex.: urgência da Igreja).
func (p *Player) AddBounty(v uint32) {
	p.Mu.Lock()
	p.BountyGold += v
	p.WantedTimer = WantedDuration
	p.Mu.Unlock()
}

func (p *Player) isWantedLocked() bool {
	if p.WantedTimer > 0 {
		return true
	}
	for _, v := range p.PermanentWanted {
		if v {
			return true
		}
	}
	return false
}

// IsWanted informa se alguma Guarda o caça.
func (p *Player) IsWanted() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.isWantedLocked()
}

// IsWantedIn informa se a Guarda daquela cidade o caça (respeitando a pena recém-cumprida).
func (p *Player) IsWantedIn(city uint8) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	if time.Now().Before(p.JailUntil.Add(JailGrace)) {
		return false
	}
	return p.WantedTimer > 0 || p.PermanentWanted[city]
}

// IsPermanentWanted informa se é procurado para sempre na cidade.
func (p *Player) IsPermanentWanted(city uint8) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.PermanentWanted[city]
}

// TickWanted desconta o tempo de procurado; ao zerar, a sequência de assassinatos zera e,
// se não houver procura permanente, a recompensa expira.
func (p *Player) TickWanted(dt float32) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.WantedTimer <= 0 {
		return
	}
	p.WantedTimer -= dt
	if p.WantedTimer <= 0 {
		p.WantedTimer = 0
		p.KillStreak = 0
		if !p.isWantedLocked() {
			p.BountyGold = 0
		}
	}
}

// PayBountyAndJail: abatido pela Guarda, perde a recompensa (até o ouro que tem) e vai preso.
// A procura permanente continua valendo.
func (p *Player) PayBountyAndJail() uint32 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	paid := min(p.BountyGold, p.Gold)
	p.Gold -= paid
	p.BountyGold = 0
	p.WantedTimer = 0
	p.KillStreak = 0
	p.PKMode = false
	p.JailUntil = time.Now().Add(JailDuration)
	return paid
}

// IsJailed informa se o jogador ainda cumpre pena.
func (p *Player) IsJailed() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return time.Now().Before(p.JailUntil)
}

// SetPKMode liga/desliga a Postura Hostil.
func (p *Player) SetPKMode(on bool) {
	p.Mu.Lock()
	p.PKMode = on
	p.Mu.Unlock()
}

// IsPKMode informa se a trava de segurança está desligada.
func (p *Player) IsPKMode() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.PKMode
}

// Targetable: NPC vivo, presente e com corpo (pode ser ferido).
func (npc *NPC) Targetable() bool {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.IsActive && !npc.IsDead && npc.Life.Enabled
}

// Alive informa se o NPC não sofreu a morte permanente.
func (npc *NPC) Alive() bool {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return !npc.IsDead
}
