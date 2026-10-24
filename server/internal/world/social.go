package world

import (
	"fmt"
	"math/rand"

	"lunaria/server/internal/protocol"
)

// Amizade com os NPCs (Afiança, 0 a 100 = 0 a 5 corações; 20 pontos por coração):
//   - Conversar dá pouquíssima afiança (+3) e só leva até 2 corações. Uma conversa a cada 8 h de jogo
//     (no máximo 3 por dia, nunca seguidas).
//   - A partir de 2 corações abrem-se "Presente" (1 por dia; o NPC tem gostos: o que ele detesta TIRA
//     afiança) e "Missões" (favores simples ou complexos que dão afiança, ouro e itens).

const (
	FriendTalkPoints  = 3
	FriendTalkCap     = 40 // 2 corações
	FriendTalkCDHours = 8.0
	FriendGiftCDHours = 24.0
	FriendHeartPoints = 20
	QuestCooldownGH   = 6.0 // depois de entregar um favor, o NPC espera um pouco para pedir outro
)

// NPCSocial é o que o jogador viveu com um NPC.
type NPCSocial struct {
	LastTalk  float64 // hora de jogo (ElapsedHours) da última conversa
	LastGift  float64
	Quest     *ActiveQuest
	QuestEnd  float64 // quando o último favor terminou
	QuestDone int
	LastQuest uint16
	Talked    bool
	Gifted    bool
}

// ActiveQuest: favor em andamento.
type ActiveQuest struct {
	DefID    uint16
	Step     int
	Progress int // abates do passo de caça
}

// socialLocked devolve (criando) o registro do jogador com o NPC. Chamar com p.Mu travado.
func (p *Player) socialLocked(npcID uint32) *NPCSocial {
	if p.Social == nil {
		p.Social = map[uint32]*NPCSocial{}
	}
	s := p.Social[npcID]
	if s == nil {
		s = &NPCSocial{}
		p.Social[npcID] = s
	}
	return s
}

// Hearts: corações inteiros com o NPC.
func Hearts(points int) int {
	return min(5, max(0, points)/FriendHeartPoints)
}

// TalkResult é o que uma conversa rendeu.
type TalkResult struct {
	OK        bool
	Gained    int
	WaitHours float64 // falta para poder conversar de novo
	Capped    bool    // já está nos 2 corações: conversar não sobe mais
}

// Talk registra uma conversa (agora = ElapsedHours do relógio).
func (p *Player) Talk(npcID uint32, now float64) TalkResult {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	s := p.socialLocked(npcID)
	if s.Talked && now-s.LastTalk < FriendTalkCDHours {
		return TalkResult{WaitHours: FriendTalkCDHours - (now - s.LastTalk)}
	}
	s.Talked, s.LastTalk = true, now
	if p.NPCFriendship == nil {
		p.NPCFriendship = map[uint32]int{}
	}
	pts := p.NPCFriendship[npcID]
	if pts >= FriendTalkCap {
		return TalkResult{OK: true, Capped: true}
	}
	gain := min(FriendTalkPoints, FriendTalkCap-pts)
	p.NPCFriendship[npcID] = pts + gain
	return TalkResult{OK: true, Gained: gain}
}

// TalkWait: horas de jogo até a próxima conversa (0 = já pode).
func (p *Player) TalkWait(npcID uint32, now float64) float64 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	s := p.socialLocked(npcID)
	if !s.Talked {
		return 0
	}
	return max(0, FriendTalkCDHours-(now-s.LastTalk))
}

// GiftWait: horas de jogo até poder presentear de novo.
func (p *Player) GiftWait(npcID uint32, now float64) float64 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	s := p.socialLocked(npcID)
	if !s.Gifted {
		return 0
	}
	return max(0, FriendGiftCDHours-(now-s.LastGift))
}

// --- Gostos de cada NPC ---

// GiftTaste: 2 = ama, 1 = gosta, 0 = neutro, -1 = não gosta, -2 = detesta.
type giftPrefs struct {
	items map[uint8]int
	cats  map[string]int
}

var npcGiftPrefs = map[uint32]giftPrefs{
	100: {map[uint8]int{uint8(MatIron): 2, uint8(MatTemperedSteel): 2, uint8(MatCharcoal): 1, protocol.ItemCookedNobleMeat: 1,
		uint8(MatMoonflower): -1, protocol.ItemOrganicTrash: -2, uint8(MatToxicWater): -2}, map[string]int{MatMetal: 1, MatAlloy: 2, MatPlantLiquid: -1}},
	103: {map[uint8]int{protocol.ItemPureLunarBlood: 2, uint8(MatMoonflower): 2, uint8(MatLunarDew): 2, protocol.ItemFreshWolfBlood: 1, uint8(MatGlowMushroom): 1,
		protocol.ItemRawWolfMeat: -1, protocol.ItemOrganicTrash: -2, uint8(MatMud): -2}, map[string]int{MatPlantLiquid: 1, MatStone: -1}},
	104: {map[uint8]int{protocol.ItemDarkPoisonGland: 2, uint8(MatVorpalSac): 2, uint8(MatGold): 2, uint8(MatVampireBlood): 1,
		protocol.ItemHealingPotion: -1, uint8(MatMoonflower): -2, protocol.ItemSilverMoonAmulet: -2}, map[string]int{MatCrystal: 1, MatOrganBlood: 1}},
	105: {map[uint8]int{protocol.ItemCookedNobleMeat: 2, protocol.ItemIronLongsword: 2, protocol.ItemHealingPotion: 1,
		protocol.ItemDarkPoisonGland: -2, uint8(MatVorpalSac): -2, uint8(MatParasiteMycel): -1}, map[string]int{MatMetal: 1}},
	106: {map[uint8]int{protocol.ItemCookedNobleMeat: 2, uint8(MatFeathers): 1, protocol.ItemRecurveBow: 2,
		protocol.ItemOrganicTrash: -2, uint8(MatToxicWater): -1}, map[string]int{MatWood: 1}},
	107: {map[uint8]int{uint8(MatMoonflower): 2, uint8(MatRiverLily): 2, protocol.ItemSilverMoonAmulet: 2, uint8(MatLunarDew): 1, protocol.ItemHerbalRemedy: 1,
		protocol.ItemDarkPoisonGland: -2, uint8(MatVampireBlood): -2, uint8(MatParasiteMycel): -2}, map[string]int{MatOrganBlood: -1}},
	108: {map[uint8]int{protocol.ItemStarlightRing: 2, uint8(MatStarRock): 2, uint8(MatManaCrystal): 2, uint8(MatLunarDew): 1, protocol.ItemManaPotion: 1,
		protocol.ItemRawWolfMeat: -1, uint8(MatMud): -2}, map[string]int{MatCrystal: 1, MatHideThread: -1}},
	109: {map[uint8]int{protocol.ItemAlphaWolfPelt: 2, protocol.ItemSharpWolfFang: 2, uint8(MatGameMeat): 1, protocol.ItemRawWolfMeat: 1,
		protocol.ItemOrganicTrash: -1, protocol.ItemManaPotion: -1}, map[string]int{MatHideThread: 1, MatBone: 1, MatCrystal: -1}},
	111: {map[uint8]int{protocol.ItemDarkPoisonGland: 2, uint8(MatVorpalSac): 2, protocol.ItemSteelDagger: 1,
		uint8(MatMoonflower): -1, protocol.ItemCookedNobleMeat: -1}, map[string]int{MatOrganBlood: 1}},
	112: {map[uint8]int{uint8(MatHerbs): 2, protocol.ItemHerbalRemedy: 2, protocol.ItemAlphaWolfPelt: 1,
		uint8(MatVampireBlood): -2, protocol.ItemDarkPoisonGland: -1}, map[string]int{MatPlantLiquid: 1, MatAlloy: -1}},
	113: {map[uint8]int{uint8(MatStarRock): 2, protocol.ItemStarlightRing: 2, uint8(MatLimestone): 1, uint8(MatQuartz): 1,
		protocol.ItemRawWolfMeat: -1, uint8(MatGameMeat): -1}, map[string]int{MatStone: 1, MatCrystal: 1, MatOrganBlood: -2}},
	114: {map[uint8]int{uint8(MatArachnaSilk): 2, protocol.ItemSilverMoonAmulet: 2, uint8(MatSpiderWeb): 1, uint8(MatThickFur): 1,
		uint8(MatMud): -2, protocol.ItemOrganicTrash: -2}, map[string]int{MatHideThread: 1, MatStone: -1}},
	115: {map[uint8]int{uint8(MatGameMeat): 2, protocol.ItemFreshWolfBlood: 2, protocol.ItemRawWolfMeat: 1, uint8(MatHerbs): 1, uint8(MatGoldenClover): 1,
		uint8(MatToxicWater): -2, uint8(MatParasiteMycel): -2}, map[string]int{MatPlantLiquid: 1, MatMetal: -1}},
	116: {map[uint8]int{protocol.ItemSharpWolfFang: 2, protocol.ItemAlphaWolfPelt: 2, uint8(MatHerbs): 1,
		protocol.ItemWolfGreyPelt: -2, protocol.ItemCookedNobleMeat: -1}, map[string]int{MatBone: 1, MatAlloy: -1, MatMetal: -1}},
	JewelerID: {map[uint8]int{uint8(MatFireRuby): 2, uint8(MatZeroSapphire): 2, uint8(MatGold): 2, uint8(MatSilver): 1, uint8(MatQuartz): 1,
		uint8(MatMud): -2, protocol.ItemRawWolfMeat: -2}, map[string]int{MatCrystal: 1, MatOrganBlood: -1}},
}

// GiftTaste: o quanto o NPC gosta do item (2 ama .. -2 detesta).
func GiftTaste(npcID uint32, item uint8) int {
	prefs, ok := npcGiftPrefs[npcID]
	if !ok {
		if item == protocol.ItemOrganicTrash {
			return -2
		}
		return 0
	}
	if v, ok := prefs.items[item]; ok {
		return v
	}
	if m, ok := MaterialsDB[uint16(item)]; ok {
		return prefs.cats[m.Category]
	}
	return 0
}

var giftPoints = map[int]int{2: 10, 1: 5, 0: 1, -1: -6, -2: -12}

// GiftResult é o efeito de um presente.
type GiftResult struct {
	OK        bool
	Taste     int
	Delta     int
	Points    int
	WaitHours float64
	Reason    string
}

// Gift entrega um presente (o item já foi validado/retirado pelo chamador).
func (p *Player) Gift(npcID uint32, item, quality uint8, now float64) GiftResult {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	pts := p.NPCFriendship[npcID]
	if Hearts(pts) < 2 {
		return GiftResult{Reason: "Ainda não temos intimidade para presentes (precisa de 2 corações)."}
	}
	s := p.socialLocked(npcID)
	if s.Gifted && now-s.LastGift < FriendGiftCDHours {
		return GiftResult{WaitHours: FriendGiftCDHours - (now - s.LastGift), Reason: "Já recebi um presente seu hoje."}
	}
	taste := GiftTaste(npcID, item)
	delta := giftPoints[taste]
	if delta > 0 && quality >= 90 {
		delta += 2 // capricho na qualidade
	}
	s.Gifted, s.LastGift = true, now
	if p.NPCFriendship == nil {
		p.NPCFriendship = map[uint32]int{}
	}
	np := min(100, max(0, pts+delta))
	p.NPCFriendship[npcID] = np
	return GiftResult{OK: true, Taste: taste, Delta: np - pts, Points: np}
}

// --- Missões (favores) ---

// QuestStep: um passo do favor.
type QuestStep struct {
	Kind       string // "deliver" (entregar itens) ou "hunt" (abater criaturas)
	Item       uint8
	Qty        int
	MinQuality uint8
	Mobs       []uint8
	Count      int
	Label      string
}

// QuestDef: um favor que o NPC pode pedir.
type QuestDef struct {
	ID         uint16
	NPC        uint32
	Title      string
	Intro      string
	Steps      []QuestStep
	MinHearts  int
	Gold       uint32
	Friendship int
	RewardItem uint8
	RewardQty  uint8
	Thanks     string
}

func deliver(item uint8, qty int, minQ uint8) QuestStep {
	return QuestStep{Kind: "deliver", Item: item, Qty: qty, MinQuality: minQ}
}

func hunt(label string, count int, mobs ...uint8) QuestStep {
	return QuestStep{Kind: "hunt", Mobs: mobs, Count: count, Label: label}
}

// QuestDefs: favores de cada NPC (os de 2 corações são simples; os de 3+ são complexos, em etapas).
var QuestDefs = []QuestDef{
	{1, 100, "Lenha para a Forja", "A fornalha come lenha como um dragão. Me traz 6 toras de Pinho do Refúgio?",
		[]QuestStep{deliver(uint8(MatPineRefuge), 6, 0)}, 2, 60, 6, 0, 0, "Isso mantém o fogo aceso por dias. Obrigado!"},
	{2, 100, "Ferro de Primeira", "Estou com uma encomenda grande e o ferro acabou. Preciso de 5 Ferros com Qualidade 60 ou mais.",
		[]QuestStep{deliver(uint8(MatIron), 5, 60)}, 2, 140, 8, uint8(MatCharcoal), 4, "Ferro bom faz espada boa. Leva esse carvão pra você."},
	{3, 100, "A Ameaça dos Saqueadores", "Saqueadores roubaram minhas ferramentas a caminho das Ruínas. Derrube 4 deles e me traga 3 Sucatas Metálicas que eles carregam.",
		[]QuestStep{hunt("Saqueadores Deserdados", 4, protocol.MobTypeOutcastRaider), deliver(protocol.ItemMetalScrap, 3, 0)}, 3, 320, 12, ItemIronPickaxe, 1, "Você é dos meus. Essa picareta é por minha conta."},
	{10, 103, "Ervas Frescas", "Meu estoque de ervas medicinais está no fim. Pode colher 6 para mim?",
		[]QuestStep{deliver(uint8(MatHerbs), 6, 0)}, 2, 55, 6, protocol.ItemHealingPotion, 1, "Perfeitas! Uma poção pelo seu trabalho."},
	{11, 103, "Pétalas da Lua", "Uma cliente pediu um elixir raro. Preciso de 3 Flores-da-Lua com Qualidade 70+.",
		[]QuestStep{deliver(uint8(MatMoonflower), 3, 70)}, 2, 120, 8, protocol.ItemManaPotion, 2, "Que perfume! Vou destilar agora mesmo."},
	{12, 103, "Sangue para a Pesquisa", "Estudo o sangue das feras do Bosque. Abata 3 Lobos da Bruma e me traga 2 frascos de Sangue de Lobo.",
		[]QuestStep{hunt("Lobos da Bruma", 3, protocol.MobTypeMistWolf), deliver(uint8(MatWolfBlood), 2, 0)}, 3, 260, 12, protocol.ItemWolfBloodPotion, 1, "Isso vai render um tratado inteiro. Obrigada!"},
	{20, 104, "Entrega Discreta", "Pssiu... preciso de 2 Glândulas de Veneno Sombrio. Não pergunte para quê.",
		[]QuestStep{deliver(protocol.ItemDarkPoisonGland, 2, 0)}, 2, 150, 7, 0, 0, "Ninguém viu nada. Aqui está o combinado."},
	{21, 104, "Limpeza no Beco", "Uns cultistas andam xeretando meus negócios. Some com 3 deles no Santuário e me traga uma Bolsa de Veneno Vorpal como prova.",
		[]QuestStep{hunt("Cultistas Sombrios", 3, protocol.MobTypeDarkCultist), deliver(uint8(MatVorpalSac), 1, 0)}, 3, 380, 12, protocol.ItemObsidianRing, 1, "Você tem talento para as sombras. Fique com isto."},
	{30, 105, "Patrulha do Bosque", "Lobos atacaram uma carroça na estrada sul. Abata 4 Lobos da Bruma.",
		[]QuestStep{hunt("Lobos da Bruma", 4, protocol.MobTypeMistWolf)}, 2, 110, 7, protocol.ItemHealingPotion, 2, "A estrada está segura de novo. Bom trabalho, recruta."},
	{31, 105, "Rações para a Guarda", "Meus homens estão famintos. Traga 4 Carnes Nobres Assadas.",
		[]QuestStep{deliver(protocol.ItemCookedNobleMeat, 4, 0)}, 2, 90, 6, 0, 0, "Barriga cheia, lança firme!"},
	{32, 105, "A Fortaleza Perdida", "Precisamos enfraquecer as Ruínas: derrube 3 Besteiros da Vigília e depois 1 Executor de Ferro.",
		[]QuestStep{hunt("Besteiros da Vigília", 3, protocol.MobTypeVigilCrossbowman), hunt("Executor de Ferro", 1, protocol.MobTypeIronEnforcer)}, 3, 480, 14, protocol.ItemVigilHelmet, 1, "Você honra a Guarda. Este elmo é seu."},
	{40, 106, "Penas para Flechas", "Fico sem flechas toda semana. Me traga 8 Penas?",
		[]QuestStep{deliver(uint8(MatFeathers), 8, 0)}, 2, 70, 6, 0, 0, "Agora sim, aljava cheia!"},
	{41, 106, "Ursos na Trilha", "Um Urso-Pardo bloqueia a trilha do Bosque. Afaste-o de vez.",
		[]QuestStep{hunt("Urso-Pardo do Bosque", 1, 110)}, 3, 260, 12, protocol.ItemHuntersQuiver, 1, "Corajoso! Fique com minha aljava reserva."},
	{50, 107, "Lírios para o Altar", "O altar precisa de flores puras. Traga 4 Lírios-do-Rio.",
		[]QuestStep{deliver(uint8(MatRiverLily), 4, 0)}, 2, 60, 7, protocol.ItemHerbalRemedy, 1, "Que a Luz o acompanhe."},
	{51, 107, "Descanso aos Mortos", "Os mortos-vivos perturbam o cemitério. Dê descanso a 3 Zumbis.",
		[]QuestStep{hunt("Zumbis", 3, protocol.MobTypeZombie)}, 3, 240, 12, protocol.ItemHealingPotion, 3, "As almas agradecem. E eu também."},
	{60, 108, "Cristais de Quartzo", "Preciso de 3 Quartzos para calibrar meu telescópio.",
		[]QuestStep{deliver(uint8(MatQuartz), 3, 0)}, 2, 110, 7, protocol.ItemManaPotion, 1, "As estrelas estarão mais nítidas esta noite."},
	{61, 108, "Fragmentos Estelares", "Uma chuva de meteoros caiu no Santuário. Traga 2 Rochas Estelares com Qualidade 65+.",
		[]QuestStep{deliver(uint8(MatStarRock), 2, 65)}, 3, 320, 12, protocol.ItemArcaneOrb, 1, "Extraordinário! Este orbe ressoa com elas."},
	{70, 109, "Carne para o Posto", "O posto está sem carne. Traga 5 Carnes de Caça.",
		[]QuestStep{deliver(uint8(MatGameMeat), 5, 0)}, 2, 80, 6, 0, 0, "Isso alimenta a matilha de caçadores por uma semana."},
	{71, 109, "A Grande Caçada", "Prove seu valor: abata 3 Cervos-Galheiros e 2 Javalis Selvagens, e me traga 3 Couros de Javali bem tirados (Qualidade 60+).",
		[]QuestStep{hunt("Cervos-Galheiros", 3, 102), hunt("Javalis Selvagens", 2, protocol.MobTypeWildBoar, 120), deliver(uint8(MatBoarLeather), 3, 60)}, 3, 420, 14, protocol.ItemAutopsyDagger, 1, "Esse é um caçador! Leve minha melhor adaga de autópsia."},
	{80, 114, "Linha e Agulha", "Acabaram minhas linhas grossas. Traga 6, querida(o).",
		[]QuestStep{deliver(uint8(MatRoughThread), 6, 0)}, 2, 70, 6, 0, 0, "Divino! Já posso terminar o vestido."},
	{81, 114, "Couro de Lobo Impecável", "Um nobre encomendou um casaco. Preciso de 4 Couros de Lobo com Qualidade 70+.",
		[]QuestStep{deliver(uint8(MatWolfLeather), 4, 70)}, 3, 300, 12, protocol.ItemWolfLeatherPants, 1, "Perfeitos, sem um furo! Leve estas calças."},
	{90, 115, "Ingredientes do Dia", "Hoje tem ensopado! Traga 4 Carnes de Caça e 3 Ervas Medicinais.",
		[]QuestStep{deliver(uint8(MatGameMeat), 4, 0), deliver(uint8(MatHerbs), 3, 0)}, 2, 90, 7, protocol.ItemCookedNobleMeat, 2, "Vai sair o melhor ensopado da Vila!"},
	{91, 115, "O Trevo da Sorte", "Dizem que o Trevo-Dourado dá sabor de festa. Me traz 2?",
		[]QuestStep{deliver(uint8(MatGoldenClover), 2, 0)}, 3, 200, 12, protocol.ItemCookedNobleMeat, 3, "Sabor de festa! A casa agradece."},
	{100, 112, "Ervas da Montanha", "Meu chá precisa de ervas. Traga 5 Ervas Medicinais.",
		[]QuestStep{deliver(uint8(MatHerbs), 5, 0)}, 2, 60, 7, protocol.ItemHerbalRemedy, 1, "Um bom chá acalma até o mais feroz dos espíritos."},
	{110, 113, "Pedra para a Estátua", "Preciso de 6 blocos de Calcário para uma nova estátua.",
		[]QuestStep{deliver(uint8(MatLimestone), 6, 0)}, 2, 70, 7, 0, 0, "A pedra já sussurra o que quer ser."},
	{120, 111, "Silêncio na Mata", "Víboras do Musgo andam mordendo meus informantes. Elimine 3.",
		[]QuestStep{hunt("Víboras-do-Musgo", 3, 116)}, 2, 120, 7, 0, 0, "Silêncio... é assim que eu gosto."},
	{130, 116, "Respeito à Matilha", "Caçadores mataram demais por aqui. Devolva à terra 3 Presas de Lobo.",
		[]QuestStep{deliver(protocol.ItemSharpWolfFang, 3, 0)}, 2, 40, 9, 0, 0, "A matilha sentirá sua gratidão."},
	{140, JewelerID, "Prata para Joias", "Preciso de 4 Pratas para uma encomenda real.",
		[]QuestStep{deliver(uint8(MatSilver), 4, 0)}, 2, 160, 7, 0, 0, "Brilha como a lua cheia!"},
	{141, JewelerID, "O Rubi Perfeito", "Um colecionador quer um Rubi de Fogo com Qualidade 80+.",
		[]QuestStep{deliver(uint8(MatFireRuby), 1, 80)}, 3, 380, 14, protocol.ItemBloodRubyRing, 1, "Que lapidação natural! Este anel é seu."},
}

// QuestByID devolve a definição do favor.
func QuestByID(id uint16) (QuestDef, bool) {
	for _, q := range QuestDefs {
		if q.ID == id {
			return q, true
		}
	}
	return QuestDef{}, false
}

// QuestOffer escolhe um favor que o NPC pode pedir agora (respeitando corações e o último feito).
func QuestOffer(npcID uint32, hearts int, last uint16) (QuestDef, bool) {
	var pool []QuestDef
	for _, q := range QuestDefs {
		if q.NPC == npcID && hearts >= q.MinHearts && q.ID != last {
			pool = append(pool, q)
		}
	}
	if len(pool) == 0 {
		for _, q := range QuestDefs {
			if q.NPC == npcID && hearts >= q.MinHearts {
				pool = append(pool, q)
			}
		}
	}
	if len(pool) == 0 {
		return QuestDef{}, false
	}
	return pool[rand.Intn(len(pool))], true
}

// StepText descreve o passo para o jogador.
func (st QuestStep) Text(progress int) string {
	if st.Kind == "hunt" {
		return fmt.Sprintf("Abater %s: %d/%d", st.Label, min(progress, st.Count), st.Count)
	}
	s := fmt.Sprintf("Entregar %d× %s", st.Qty, ItemName(st.Item))
	if st.MinQuality > 0 {
		s += fmt.Sprintf(" (Qualidade %d+)", st.MinQuality)
	}
	return s
}

// SocialSnapshot: dados do jogador com o NPC (para a UI).
func (p *Player) SocialSnapshot(npcID uint32) (NPCSocial, ActiveQuest, bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	s := p.socialLocked(npcID)
	if s.Quest == nil {
		return *s, ActiveQuest{}, false
	}
	return *s, *s.Quest, true
}

// SetQuest começa (ou limpa, com def nil) um favor.
func (p *Player) SetQuest(npcID uint32, q *ActiveQuest, now float64, finished bool) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	s := p.socialLocked(npcID)
	s.Quest = q
	if finished {
		s.QuestDone++
		s.QuestEnd = now
	}
}

// QuestWait: horas até o NPC pedir outro favor.
func (p *Player) QuestWait(npcID uint32, now float64) float64 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	s := p.socialLocked(npcID)
	if s.QuestDone == 0 {
		return 0
	}
	return max(0, QuestCooldownGH-(now-s.QuestEnd))
}

// CreditKill avança os favores de caça do jogador; devolve (npc, texto) dos que mudaram.
func (p *Player) CreditKill(mobType uint8) map[uint32]string {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	out := map[uint32]string{}
	for npcID, s := range p.Social {
		if s.Quest == nil {
			continue
		}
		def, ok := QuestByID(s.Quest.DefID)
		if !ok || s.Quest.Step >= len(def.Steps) {
			continue
		}
		st := def.Steps[s.Quest.Step]
		if st.Kind != "hunt" {
			continue
		}
		for _, m := range st.Mobs {
			if m == mobType {
				s.Quest.Progress++
				out[npcID] = st.Text(s.Quest.Progress)
				if s.Quest.Progress >= st.Count {
					s.Quest.Step++
					s.Quest.Progress = 0
				}
				break
			}
		}
	}
	return out
}

// LastQuestID: último favor concluído com o NPC (para não repetir o mesmo em seguida).
func (p *Player) LastQuestID(npcID uint32) uint16 {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	return p.socialLocked(npcID).LastQuest
}

func (p *Player) SetLastQuestID(npcID uint32, id uint16) {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	p.socialLocked(npcID).LastQuest = id
}
