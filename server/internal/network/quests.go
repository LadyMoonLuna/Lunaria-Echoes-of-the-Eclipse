package network

import (
	"fmt"
	"log"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Missão "O Aprendiz do Ferreiro" (Garrick, NPC 100) em três partes:
//  1. Garrick entrega um Machado Velho (T1) e pede Pinho do Refúgio para o cabo e a bainha de uma espada.
//  2. Entrega uma Picareta Desgastada (T1) e pede Cobre colhido nas redondezas da Vila.
//  3. Entrega a Adaga de Autópsia e pede Couro de Javali do Bosque Sussurrante.
//
// Ao final, forja a Espada Longa de Aço com os materiais trazidos.
const (
	QuestBlacksmithApprentice uint8 = 1

	questStageNotStarted uint8 = 0
	questStageDone       uint8 = 4
	questStateDoneWire   uint8 = 255
)

type questPart struct {
	gift     world.ItemID // ferramenta entregue ao começar a parte
	material uint16       // material pedido
	need     uint8
	reward   uint32 // Sollares ao entregar
	intro    string
	reminder string
	thanks   string
}

var blacksmithQuest = []questPart{
	{
		gift: world.ItemStoneAxe, material: world.MatPineRefuge, need: 5, reward: 40,
		intro:    "Quer aprender o ofício, é? Tome este Machado Velho. Preciso de 5 Pinhos do Refúgio para o cabo e a bainha de uma espada — os pinheiros perto da Vila servem.",
		reminder: "Ainda faltam Pinhos do Refúgio para a espada. Use o Machado Velho nos pinheiros da Vila.",
		thanks:   "Pinho bom, sem nós! Isso vira um cabo firme.",
	},
	{
		gift: world.ItemStonePickaxe, material: world.MatCopper, need: 5, reward: 60,
		intro:    "Agora a guarda da espada. Leve esta Picareta Desgastada e me traga 5 Cobres — há veios esverdeados nas pedras ao redor da Vila.",
		reminder: "O cobre está nos veios esverdeados das rochas perto da Vila. Preciso de 5.",
		thanks:   "Cobre puro! A guarda vai brilhar como o pôr do sol.",
	},
	{
		gift: protocol.ItemAutopsyDagger, material: world.MatBoarLeather, need: 3, reward: 100,
		intro:    "Falta o couro do punho. Tome esta Adaga de Autópsia — sem uma lâmina não se abre carcaça nenhuma. Cace Javalis no Bosque Sussurrante e me traga 3 Couros de Javali.",
		reminder: "Os Javalis vivem logo na entrada do Bosque Sussurrante. Esfole-os com a Adaga de Autópsia e traga 3 Couros.",
		thanks:   "Couro curtido na medida certa. Agora, à forja!",
	},
}

func questStage(p *world.Player) uint8 {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.GarrickQuestStage
}

func setQuestStage(p *world.Player, stage uint8) {
	p.Mu.Lock()
	p.GarrickQuestStage = stage
	p.Mu.Unlock()
}

// sendQuestState envia o progresso da missão ao cliente (0x47) para o HUD.
func (s *Server) sendQuestState(p *world.Player) {
	stage := questStage(p)
	switch {
	case stage == questStageNotStarted:
		pkt := protocol.SerializeQuestState(QuestBlacksmithApprentice, 0, 0, 0)
		writeTCP(p, pkt[:])
	case stage >= questStageDone:
		pkt := protocol.SerializeQuestState(QuestBlacksmithApprentice, questStateDoneWire, 0, 0)
		writeTCP(p, pkt[:])
	default:
		part := blacksmithQuest[stage-1]
		have := uint8(min(255, len(p.FamilyUnits(world.ItemID(part.material)))))
		if have > part.need {
			have = part.need
		}
		pkt := protocol.SerializeQuestState(QuestBlacksmithApprentice, stage, have, part.need)
		writeTCP(p, pkt[:])
	}
}

// handleBlacksmithQuest conversa com Garrick sobre a missão. Retorna true se a fala da missão bastou.
func (s *Server) handleBlacksmithQuest(p *world.Player, npcID uint32) bool {
	stage := questStage(p)
	if stage >= questStageDone {
		return false
	}
	if stage == questStageNotStarted {
		s.startQuestPart(p, npcID, 1)
		return true
	}
	part := blacksmithQuest[stage-1]
	units := p.FamilyUnits(world.ItemID(part.material)) // couro de qualquer javali serve
	if len(units) < int(part.need) {
		s.BroadcastNPCSay(npcID, part.reminder)
		return false // deixa o resto da conversa (presentes, classe) acontecer
	}
	for _, u := range units[len(units)-int(part.need):] { // entrega as melhores
		p.TakeItemUnits(u.ID, u.Quality, 1)
	}
	p.AddGold(part.reward)
	s.BroadcastNPCSay(npcID, fmt.Sprintf("%s (+%d Sollares)", part.thanks, part.reward))
	log.Printf("[MISSÃO] Jogador #%d concluiu a parte %d de O Aprendiz do Ferreiro\n", p.ID, stage)
	if int(stage) < len(blacksmithQuest) {
		s.startQuestPart(p, npcID, stage+1)
	} else {
		setQuestStage(p, questStageDone)
		p.AddItem(protocol.ItemIronLongsword, 1)
		s.BroadcastNPCSay(npcID, "Pinho, cobre e couro de javali... e o seu suor. Aqui está a sua Espada Longa de Aço, aprendiz. Você fez por merecer!")
		s.sendInventorySync(p)
		s.sendQuestState(p)
	}
	return true
}

func (s *Server) startQuestPart(p *world.Player, npcID uint32, stage uint8) {
	part := blacksmithQuest[stage-1]
	setQuestStage(p, stage)
	p.AddItem(part.gift, 1)
	s.BroadcastNPCSay(npcID, part.intro)
	s.sendInventorySync(p)
	s.sendQuestState(p)
}
