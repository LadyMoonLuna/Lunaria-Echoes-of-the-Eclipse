package network

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"sort"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Amizade com os NPCs: conversa limitada (0x63 ação 1), presentes (2) e favores (3/4/5).

type questView struct {
	ID     uint16   `json:"id"`
	Title  string   `json:"title"`
	Intro  string   `json:"intro"`
	Steps  []string `json:"steps"`
	Step   int      `json:"step"`
	Ready  bool     `json:"ready"` // todos os passos feitos: falta só entregar
	Reward string   `json:"reward"`
}

type socialState struct {
	NPC       uint32     `json:"npc"`
	Points    int        `json:"points"`
	Hearts    int        `json:"hearts"`
	TalkWait  float64    `json:"talk_wait"` // horas de jogo
	GiftWait  float64    `json:"gift_wait"`
	QuestWait float64    `json:"quest_wait"`
	CanGift   bool       `json:"can_gift"`
	CanQuest  bool       `json:"can_quest"`
	HasQuests bool       `json:"has_quests"`
	Quest     *questView `json:"quest"`
	Msg       string     `json:"msg"`
	Taste     int        `json:"taste"`
	Gifts     []giftItem `json:"gifts"` // o que o jogador pode oferecer
}

type giftItem struct {
	ID world.ItemID `json:"id"`
	Q  uint8        `json:"q"`
	N  int          `json:"n"`
}

func rewardText(def world.QuestDef) string {
	s := fmt.Sprintf("%d Sollares · +%d Afiança", def.Gold, def.Friendship)
	if def.RewardItem != 0 {
		s += fmt.Sprintf(" · %d× %s", max(1, int(def.RewardQty)), world.ItemName(def.RewardItem))
	}
	return s
}

func npcHasQuests(npcID uint32) bool {
	for _, q := range world.QuestDefs {
		if q.NPC == npcID {
			return true
		}
	}
	return false
}

func (s *Server) sendSocialState(p *world.Player, npcID uint32, msg string, taste int) {
	now := s.clock.ElapsedHours()
	pts := p.GetFriendship(npcID)
	st := socialState{NPC: npcID, Points: pts, Hearts: world.Hearts(pts), Msg: msg, Taste: taste,
		TalkWait: p.TalkWait(npcID, now), GiftWait: p.GiftWait(npcID, now), QuestWait: p.QuestWait(npcID, now),
		HasQuests: npcHasQuests(npcID), Gifts: []giftItem{}}
	st.CanGift = st.Hearts >= 2
	st.CanQuest = st.Hearts >= 2 && st.HasQuests
	if _, aq, ok := p.SocialSnapshot(npcID); ok {
		if def, found := world.QuestByID(aq.DefID); found {
			v := &questView{Steps: []string{}, ID: def.ID, Title: def.Title, Intro: def.Intro, Step: aq.Step, Reward: rewardText(def), Ready: aq.Step >= len(def.Steps)}
			for i, stp := range def.Steps {
				prog := 0
				if i < aq.Step {
					prog = stp.Count
				} else if i == aq.Step {
					prog = aq.Progress
				}
				v.Steps = append(v.Steps, stp.Text(prog))
			}
			st.Quest = v
		}
	}
	if st.CanGift {
		p.Mu.RLock()
		ids := make([]world.ItemID, 0, len(p.Inventory))
		for id, n := range p.Inventory {
			if n > 0 && id < world.CustomItemFirstID {
				ids = append(ids, id)
			}
		}
		p.Mu.RUnlock()
		sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
		for _, id := range ids {
			if p.IsSoulbound(id) {
				continue
			}
			counts := map[uint8]int{}
			for _, q := range p.UnitQualities(id) {
				counts[q]++
			}
			for q, n := range counts {
				st.Gifts = append(st.Gifts, giftItem{ID: id, Q: q, N: n})
			}
		}
	}
	body, _ := json.Marshal(st)
	writeTCP(p, protocol.SerializeJSONPacket(protocol.PacketTypeSocialState, body))
}

func (s *Server) handleSocialAction(playerID uint32, data []byte) {
	if len(data) < protocol.SocialActionPacketSize {
		return
	}
	npcID := binary.LittleEndian.Uint32(data[1:5])
	action, item, quality := data[5], binary.LittleEndian.Uint16(data[6:8]), data[8]
	s.mu.RLock()
	p := s.players[playerID]
	npc := s.npcs[npcID]
	s.mu.RUnlock()
	if p == nil || npc == nil {
		return
	}
	p.Mu.RLock()
	px, py, pz, zone := p.PosX, p.PosY, p.PosZ, p.ZoneID
	p.Mu.RUnlock()
	if action != protocol.SocialActionState && (npc.GetZone() != zone || !npc.CanInteract(px, py, pz)) {
		s.sendSocialState(p, npcID, "Chegue mais perto para falar.", 0)
		return
	}
	now := s.clock.ElapsedHours()
	var msg string
	taste := 0
	switch action {
	case protocol.SocialActionTalk:
		r := p.Talk(npcID, now)
		switch {
		case !r.OK:
			msg = fmt.Sprintf("Já conversamos há pouco. Volte daqui a %s.", gameHoursText(r.WaitHours))
		case r.Capped:
			msg = "Foi bom conversar! (A partir de 2 corações, a amizade cresce com presentes e favores.)"
		default:
			msg = fmt.Sprintf("Foi bom conversar! (+%d Afiança)", r.Gained)
		}
		s.sendFriendshipSync(p, npcID)
	case protocol.SocialActionGift:
		msg, taste = s.giveGift(p, npcID, item, quality, now)
	case protocol.SocialActionQuest:
		msg = s.requestQuest(p, npcID, now)
	case protocol.SocialActionTurnIn:
		msg = s.turnInQuest(p, npcID, now)
	case protocol.SocialActionAbandon:
		if _, _, ok := p.SocialSnapshot(npcID); ok {
			p.SetQuest(npcID, nil, now, false)
			msg = "Tudo bem, outro dia você me ajuda."
		}
	}
	s.sendSocialState(p, npcID, msg, taste)
}

func gameHoursText(h float64) string {
	if h >= 1 {
		return fmt.Sprintf("%.0f h de jogo", h+0.49)
	}
	return fmt.Sprintf("%.0f min de jogo", h*60+0.5)
}

var tasteLines = map[int]string{
	2:  "😍 Eu AMO isso! Como você sabia?",
	1:  "😊 Que gentileza, eu gosto disso!",
	0:  "🙂 Obrigado... é um presente simpático.",
	-1: "😕 Hum... não é bem o meu gosto.",
	-2: "😠 Sério? Eu detesto isso!",
}

func (s *Server) giveGift(p *world.Player, npcID uint32, item world.ItemID, quality uint8, now float64) (string, int) {
	if world.Hearts(p.GetFriendship(npcID)) < 2 {
		return "Ainda não temos intimidade para presentes (2 corações).", 0
	}
	if w := p.GiftWait(npcID, now); w > 0 {
		return fmt.Sprintf("Já recebi um presente seu hoje. (Daqui a %s)", gameHoursText(w)), 0
	}
	if p.IsSoulbound(item) || p.TakeItemUnits(item, quality, 1) == 0 {
		return "Você não tem esse item.", 0
	}
	r := p.Gift(npcID, item, quality, now)
	if !r.OK {
		p.AddItemWithQuality(item, 1, quality) // devolve
		return r.Reason, 0
	}
	s.sendInventorySync(p)
	s.sendFriendshipSync(p, npcID)
	sign := "+"
	if r.Delta < 0 {
		sign = ""
	}
	return fmt.Sprintf("%s (%s%d Afiança)", tasteLines[r.Taste], sign, r.Delta), r.Taste
}

func (s *Server) requestQuest(p *world.Player, npcID uint32, now float64) string {
	hearts := world.Hearts(p.GetFriendship(npcID))
	if hearts < 2 {
		return "Ainda não confio em você para pedir favores (2 corações)."
	}
	if _, _, ok := p.SocialSnapshot(npcID); ok {
		return "Você ainda está me ajudando com aquele favor."
	}
	if w := p.QuestWait(npcID, now); w > 0 {
		return fmt.Sprintf("Por enquanto não preciso de nada. Volte daqui a %s.", gameHoursText(w))
	}
	soc, _, _ := p.SocialSnapshot(npcID)
	last := uint16(0)
	if soc.QuestDone > 0 {
		last = p.LastQuestID(npcID)
	}
	def, ok := world.QuestOffer(npcID, hearts, last)
	if !ok {
		return "Não tenho nenhum favor para pedir agora."
	}
	p.SetQuest(npcID, &world.ActiveQuest{DefID: def.ID}, now, false)
	return "📜 " + def.Intro
}

// turnInQuest entrega o passo atual (itens) ou recebe a recompensa quando tudo está feito.
func (s *Server) turnInQuest(p *world.Player, npcID uint32, now float64) string {
	_, aq, ok := p.SocialSnapshot(npcID)
	if !ok {
		return "Você não está fazendo nenhum favor para mim."
	}
	def, found := world.QuestByID(aq.DefID)
	if !found {
		p.SetQuest(npcID, nil, now, false)
		return ""
	}
	for aq.Step < len(def.Steps) {
		st := def.Steps[aq.Step]
		if st.Kind == "hunt" {
			return fmt.Sprintf("Ainda falta: %s.", st.Text(aq.Progress))
		}
		// Entrega: usa primeiro as unidades de menor Qualidade que ainda servem
		var ok []world.FamilyUnit
		for _, u := range p.FamilyUnits(st.Item) { // pior Qualidade que ainda serve primeiro
			if u.Quality >= st.MinQuality && len(ok) < st.Qty {
				ok = append(ok, u)
			}
		}
		if len(ok) < st.Qty {
			return fmt.Sprintf("Ainda falta: %s (você tem %d que servem).", st.Text(0), len(ok))
		}
		for _, u := range ok {
			p.TakeItemUnits(u.ID, u.Quality, 1)
		}
		aq.Step++
		aq.Progress = 0
		p.SetQuest(npcID, &world.ActiveQuest{DefID: aq.DefID, Step: aq.Step}, now, false)
		s.sendInventorySync(p)
	}
	// Tudo feito: recompensa
	p.SetQuest(npcID, nil, now, true)
	p.SetLastQuestID(npcID, def.ID)
	p.AddGold(def.Gold)
	p.AddFriendship(npcID, def.Friendship)
	if def.RewardItem != 0 {
		p.AddItemWithQuality(def.RewardItem, max(1, def.RewardQty), 80)
	}
	s.sendInventorySync(p)
	s.sendFriendshipSync(p, npcID)
	s.sendPlayerStats(p)
	return fmt.Sprintf("✅ %s (Recompensa: %s)", def.Thanks, rewardText(def))
}

// creditQuestKill avança favores de caça do jogador que abateu a criatura.
func (s *Server) creditQuestKill(p *world.Player, mobType uint8) {
	for npcID, text := range p.CreditKill(mobType) {
		s.sendPlayerNPCSay(p, npcID, "📜 Favor: "+text)
	}
}
