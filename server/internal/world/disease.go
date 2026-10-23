package world

import "time"

// Doenças do Mundo Vivo: algumas ficam só em quem pegou; outras são infecciosas e passam de pessoa
// para pessoa por proximidade. Muitos doentes da mesma doença numa cidade viram EPIDEMIA.

// DiseaseInfo descreve uma doença.
type DiseaseInfo struct {
	Name          string
	HPPerMinute   float32 // dano enquanto há sintomas
	NeedsMult     float32 // fome e sede caem mais rápido
	Contagious    bool
	SpreadRadius  float32       // distância de contágio (m)
	SpreadPerMin  float64       // chance por minuto de passar para cada pessoa no raio
	Incubation    time.Duration // período sem sintomas (mas já transmite)
	Severe        bool          // só a Igreja cura (o remédio de ervas não basta)
	ImmunityAfter time.Duration // quem se cura fica imune por um tempo
}

const (
	DiseaseRiverFever = "Febre do Rio"
	DiseaseGut        = "Infecção Intestinal"
	DiseaseDysentery  = "Disenteria"
	DiseaseSludgeWorm = "Verme do Lodo"
	DiseaseMistFlu    = "Gripe da Bruma"
	DiseaseGreyPlague = "Peste Cinzenta"
)

var DiseaseDB = map[string]DiseaseInfo{
	DiseaseRiverFever: {Name: DiseaseRiverFever, HPPerMinute: 10, NeedsMult: 1.5, ImmunityAfter: 20 * time.Minute},
	DiseaseGut:        {Name: DiseaseGut, HPPerMinute: 8, NeedsMult: 1.6, ImmunityAfter: 20 * time.Minute},
	DiseaseSludgeWorm: {Name: DiseaseSludgeWorm, HPPerMinute: 6, NeedsMult: 2.0, ImmunityAfter: 30 * time.Minute},
	DiseaseDysentery: {Name: DiseaseDysentery, HPPerMinute: 12, NeedsMult: 1.8, Contagious: true,
		SpreadRadius: 3, SpreadPerMin: 0.06, Incubation: 2 * time.Minute, ImmunityAfter: 30 * time.Minute},
	DiseaseMistFlu: {Name: DiseaseMistFlu, HPPerMinute: 4, NeedsMult: 1.2, Contagious: true,
		SpreadRadius: 5, SpreadPerMin: 0.12, Incubation: 90 * time.Second, ImmunityAfter: 40 * time.Minute},
	DiseaseGreyPlague: {Name: DiseaseGreyPlague, HPPerMinute: 18, NeedsMult: 1.5, Contagious: true,
		SpreadRadius: 4, SpreadPerMin: 0.10, Incubation: 3 * time.Minute, Severe: true, ImmunityAfter: 2 * time.Hour},
}

type weighted struct {
	name   string
	weight float64
}

// Doenças da água do rio (pesos)
var riverDiseases = []weighted{{DiseaseRiverFever, 35}, {DiseaseGut, 25}, {DiseaseDysentery, 25}, {DiseaseSludgeWorm, 15}}

func pickWeighted(list []weighted, roll float64) string {
	total := 0.0
	for _, w := range list {
		total += w.weight
	}
	acc := 0.0
	for _, w := range list {
		acc += w.weight / total
		if roll < acc {
			return w.name
		}
	}
	return list[len(list)-1].name
}

const (
	ColdFluChancePerMin    = 0.02 // muito frio (Frio > 80) pode trazer a Gripe da Bruma
	ZombieBitePlagueChance = 0.10 // mordida de zumbi pode passar a Peste Cinzenta
	BurialPlagueChance     = 0.05 // enterrar corpo não purificado
	EpidemicMinCases       = 4    // doentes da mesma doença na cidade
	EpidemicFraction       = 0.25 // ou 25% dos moradores vivos
	EpidemicSpreadMult     = 1.5  // na epidemia o contágio acelera
	ContagionCheckInterval = 10 * time.Second
)

// Disease devolve a ficha da doença (desconhecidas usam a Febre do Rio).
func Disease(name string) DiseaseInfo {
	if d, ok := DiseaseDB[name]; ok {
		return d
	}
	return DiseaseDB[DiseaseRiverFever]
}

// InfectLocked contamina o NPC (chamar travado). Falha se já doente ou imune.
func (npc *NPC) InfectLocked(disease string, now time.Time) bool {
	if npc.IsDead || npc.Sick || now.Before(npc.ImmuneTo[disease]) {
		return false
	}
	npc.Sick, npc.Disease, npc.InfectedAt = true, disease, now
	return true
}

// Infect contamina o NPC.
func (npc *NPC) Infect(disease string) bool {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	return npc.InfectLocked(disease, time.Now())
}

// SymptomaticLocked: passou a incubação e o NPC já sente a doença (e procura cura).
func (npc *NPC) SymptomaticLocked(now time.Time) bool {
	return npc.Sick && now.Sub(npc.InfectedAt) >= Disease(npc.Disease).Incubation
}

// CureLocked cura a doença e dá imunidade temporária.
func (npc *NPC) CureLocked(now time.Time) {
	if !npc.Sick {
		return
	}
	if npc.ImmuneTo == nil {
		npc.ImmuneTo = map[string]time.Time{}
	}
	npc.ImmuneTo[npc.Disease] = now.Add(Disease(npc.Disease).ImmunityAfter)
	npc.Sick, npc.Disease = false, ""
}

// SickState devolve (doente, doença, contagiosa) sem travar por fora.
func (npc *NPC) SickState() (bool, string, bool) {
	npc.mu.RLock()
	defer npc.mu.RUnlock()
	return npc.Sick, npc.Disease, npc.Sick && Disease(npc.Disease).Contagious
}

// ContagionChance: chance de contágio em dt minutos (acelerada na epidemia).
func ContagionChance(d DiseaseInfo, dtMinutes float64, epidemic bool) float64 {
	p := d.SpreadPerMin * dtMinutes
	if epidemic {
		p *= EpidemicSpreadMult
	}
	return min(p, 0.9)
}
