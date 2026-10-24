package world

import (
	"fmt"
	"math"
	"sync"
)

// Forja — Mini-Games (Parte 1, servidor): as 7 notas enviadas pelo cliente, a dificuldade do Ponto
// de Fusão pela diferença de condutividade, a Nota de Criação (CraftQuality) que mexe em atributos,
// durabilidade e raridade, e a Reforja Seletiva de peças de Metal/Liga antes da montagem final.

const (
	MaxMiniGameScore    float32 = 1.20
	HarmonyFusionScore  float32 = 0.95 // Ponto de Fusão perfeito: Bônus de Harmonia Híbrida
	HarmonyCondBonus    float32 = 1.25 // +25% nas 3 condutividades
	HarmonyDurBonus     float32 = 1.20 // +20% de durabilidade
	ReforgeStaminaCost  float32 = 15
	ReforgeDeniedMsg            = "🔒 Apenas partes puramente de Metal ou Liga podem ser derretidas na Reforja!"
	DivinePrefix                = "★ Divino "
	craftQualityUnitMul float32 = 80 // Qualidade da unidade (0-100) = CraftQuality × 80
)

// Faixas da Nota de Criação
const (
	CraftDefective  = "Defeituoso"
	CraftImperfect  = "Imperfeito"
	CraftSolid      = "Firme"
	CraftMasterwork = "Obra-Prima"
	CraftDivine     = "Divino"
)

// CraftScores: notas dos 7 mini-games (0.0 a 1.20 cada).
type CraftScores struct {
	Melt       float32 // 1: Derreter Metais
	FusionPt   float32 // 2: Ponto de Fusão de Condutividades
	Mold       float32 // 3: Colocar nas Formas
	PrepMetal  float32 // 4: Preparar o Metal / Escória
	ShapePart  float32 // 5: Preparar a Peça na Bigorna
	Temper     float32 // 6: Temperar a Peça
	Assembly   float32 // 7: Montagem Final
	FromClient bool    // false = forja antiga, sem mini-games (atributos sem modificador)
}

func clampScore(v float32) float32 {
	if v != v || v < 0 { // NaN ou negativo
		return 0
	}
	return min(v, MaxMiniGameScore)
}

// Clamp limita as notas ao intervalo permitido (o cliente nunca é confiável).
func (c CraftScores) Clamp() CraftScores {
	c.Melt, c.FusionPt, c.Mold = clampScore(c.Melt), clampScore(c.FusionPt), clampScore(c.Mold)
	c.PrepMetal, c.ShapePart, c.Temper, c.Assembly = clampScore(c.PrepMetal), clampScore(c.ShapePart), clampScore(c.Temper), clampScore(c.Assembly)
	return c
}

// ScoresFromBytes: notas no fio como u8 (valor/200 → 0.0 a 1.20); ordem dos 7 mini-games.
func ScoresFromBytes(b []byte) CraftScores {
	f := func(i int) float32 {
		if i < len(b) {
			return float32(b[i]) / 200
		}
		return 0
	}
	return CraftScores{Melt: f(0), FusionPt: f(1), Mold: f(2), PrepMetal: f(3), ShapePart: f(4), Temper: f(5), Assembly: f(6), FromClient: true}.Clamp()
}

// CraftQuality = mini-games ponderados + Maestria×0,005 + (Força+Destreza)×0,002.
func (p *Player) CraftQuality(c CraftScores) float32 {
	c = c.Clamp()
	p.Mu.RLock()
	mas, str, dex := p.MAS, p.STR, p.DEX
	p.Mu.RUnlock()
	return craftQualityFor(c, mas, str, dex)
}

func craftQualityFor(c CraftScores, mas, str, dex uint8) float32 {
	return c.Melt*0.14 + c.Mold*0.12 + c.PrepMetal*0.14 + c.ShapePart*0.18 + c.Temper*0.18 + c.Assembly*0.24 +
		float32(mas)*0.005 + float32(int(str)+int(dex))*0.002
}

// CraftTier devolve a faixa da Nota de Criação.
func CraftTier(q float32) string {
	switch {
	case q < 0.50:
		return CraftDefective
	case q < 0.75:
		return CraftImperfect
	case q < 0.95:
		return CraftSolid
	case q < 1.10:
		return CraftMasterwork
	}
	return CraftDivine
}

// ApplyCraftQuality aplica a Nota de Criação em atributos, durabilidade, peso, raridade e nome.
func ApplyCraftQuality(st ForgedStats, q float32) ForgedStats {
	attr, dur, weight := 1.0, 1.0, 1.0
	rarity := int(st.Rarity)
	switch CraftTier(q) {
	case CraftDefective:
		attr, dur = 0.60, 0.50
		rarity--
	case CraftImperfect:
		attr = 0.85
	case CraftSolid: // 1,00 em 0,75 até 1,15 em 0,95
		attr = 1.0 + 0.15*float64((q-0.75)/0.20)
	case CraftMasterwork:
		attr, dur, weight = 1.35, 1.35, 0.85
		rarity++
	case CraftDivine:
		attr, dur = 1.65, 1.65
		rarity++
		if q >= 1.18 {
			rarity++ // perto da nota máxima: +2 Tiers
		}
		st.Name = DivinePrefix + st.Name
	}
	scale := func(v int, m float64) int { return int(math.Round(float64(v) * m)) }
	st.ATK, st.DEF, st.HP = scale(st.ATK, attr), scale(st.DEF, attr), scale(st.HP, attr)
	st.Durability = min(9999, scale(st.Durability, dur))
	st.Weight = float32(math.Round(float64(st.Weight)*weight*10) / 10)
	st.Rarity = uint8(max(int(RarityCommon), min(int(RarityMythic), rarity)))
	return st
}

// UnitQualityFromCraft: Qualidade (0-100) da unidade criada a partir da Nota de Criação.
func UnitQualityFromCraft(q float32) uint8 {
	return uint8(min(100, max(1, int(q*craftQualityUnitMul+0.5))))
}

// --- Ponto de Fusão (Mini-game 2) ---

// ConductivityDiff: divergência média das 3 condutividades entre os materiais (média dos pares).
func ConductivityDiff(mats []MaterialDef) float32 {
	if len(mats) < 2 {
		return 0
	}
	var sum float64
	pairs := 0
	for i := 0; i < len(mats); i++ {
		for j := i + 1; j < len(mats); j++ {
			a, b := mats[i], mats[j]
			sum += (math.Abs(float64(a.CondThermal-b.CondThermal)) + math.Abs(float64(a.CondElectric-b.CondElectric)) +
				math.Abs(float64(a.CondMagic-b.CondMagic))) / 3.0
			pairs++
		}
	}
	return float32(sum / float64(pairs))
}

// FusionDifficulty (0.0 a 1.0): cresce com a diferença de condutividade e com a raridade média.
func FusionDifficulty(mats []MaterialDef) float32 {
	if len(mats) == 0 {
		return 0
	}
	var rar float32
	for _, m := range mats {
		rar += float32(m.Rarity)
	}
	rar /= float32(len(mats))
	d := ConductivityDiff(mats)/100*0.6 + (rar-1)/7*0.4
	return max(0, min(1, d))
}

// ApplyHarmony: Bônus de Harmonia Híbrida (+25% nas condutividades, +20% de durabilidade).
func ApplyHarmony(m MaterialDef) MaterialDef {
	boost := func(v int) int { return min(100, int(math.Round(float64(v)*float64(HarmonyCondBonus)))) }
	m.CondThermal, m.CondElectric, m.CondMagic = boost(m.CondThermal), boost(m.CondElectric), boost(m.CondMagic)
	if m.Durability < 9999 {
		m.Durability = min(9999, int(math.Round(float64(m.Durability)*float64(HarmonyDurBonus))))
	}
	return m
}

// --- Reforja Seletiva ---

// PartScores: notas dos mini-games 1, 3, 4, 5 e 6 de uma peça já trabalhada.
type PartScores struct {
	Material uint8
	Scores   CraftScores
	Reforges int
}

// ForgeSession: peças trabalhadas de uma blueprint antes da montagem final.
type ForgeSession struct {
	BlueprintID uint8
	Parts       map[int]PartScores
}

var forgeSessions = struct {
	sync.Mutex
	byPlayer map[uint32]*ForgeSession
}{byPlayer: map[uint32]*ForgeSession{}}

// IsReforgeable: só peças de Metal ou Liga voltam ao fogo.
func IsReforgeable(m MaterialDef) bool {
	return m.Category == MatMetal || m.Category == MatAlloy
}

// WorkPart registra as notas de uma peça. Na primeira vez é o trabalho normal; depois é Reforja:
// só Metal/Liga, custa 15 de Stamina e substitui a nota antiga (o metal não se perde).
func (p *Player) WorkPart(bpID uint8, partIdx int, matID uint8, sc CraftScores) (reforged bool, err error) {
	bp, ok := GetBlueprint(bpID)
	if !ok || partIdx < 0 || partIdx >= len(bp.Parts) {
		return false, fmt.Errorf("peça inválida")
	}
	if !p.KnowsBlueprint(bpID) {
		return false, fmt.Errorf("você ainda não aprendeu a blueprint %s", bp.Name)
	}
	p.Mu.RLock()
	m, okMat := p.materialLocked(matID)
	known := p.DiscoveredMaterials[uint16(matID)]
	p.Mu.RUnlock()
	if !okMat || !known || !PartAccepts(bp.Parts[partIdx], m) {
		return false, fmt.Errorf("esse material não serve para a peça %s", bp.Parts[partIdx].Name)
	}
	forgeSessions.Lock()
	defer forgeSessions.Unlock()
	s := forgeSessions.byPlayer[p.ID]
	if s == nil || s.BlueprintID != bpID {
		s = &ForgeSession{BlueprintID: bpID, Parts: map[int]PartScores{}}
		forgeSessions.byPlayer[p.ID] = s
	}
	prev, again := s.Parts[partIdx]
	if again && prev.Material == matID {
		if !IsReforgeable(m) {
			return false, fmt.Errorf("%s", ReforgeDeniedMsg)
		}
		p.Mu.Lock()
		if p.Stamina < ReforgeStaminaCost {
			p.Mu.Unlock()
			return false, fmt.Errorf("sem fôlego para a Reforja (precisa de %.0f de Stamina)", ReforgeStaminaCost)
		}
		p.Stamina -= ReforgeStaminaCost
		p.Mu.Unlock()
		s.Parts[partIdx] = PartScores{Material: matID, Scores: sc.Clamp(), Reforges: prev.Reforges + 1}
		return true, nil
	}
	s.Parts[partIdx] = PartScores{Material: matID, Scores: sc.Clamp()}
	return false, nil
}

// SessionScores: as notas finais da forja juntando as peças trabalhadas (média ponderada pelo
// tamanho de cada peça) com as notas globais do pacote final (fallback e Montagem).
func (p *Player) SessionScores(bp BlueprintDef, picks []uint8, global CraftScores) CraftScores {
	forgeSessions.Lock()
	s := forgeSessions.byPlayer[p.ID]
	forgeSessions.Unlock()
	if s == nil || s.BlueprintID != bp.ID {
		return global
	}
	var w, melt, mold, prep, shape, temper float32
	for i, part := range bp.Parts {
		if i >= len(picks) || picks[i] == 0 {
			continue
		}
		sc := global
		if ps, ok := s.Parts[i]; ok && ps.Material == picks[i] {
			sc = ps.Scores
		}
		w += part.Share
		melt += sc.Melt * part.Share
		mold += sc.Mold * part.Share
		prep += sc.PrepMetal * part.Share
		shape += sc.ShapePart * part.Share
		temper += sc.Temper * part.Share
	}
	if w <= 0 {
		return global
	}
	out := global
	out.Melt, out.Mold, out.PrepMetal, out.ShapePart, out.Temper = melt/w, mold/w, prep/w, shape/w, temper/w
	return out.Clamp()
}

// EndForgeSession apaga as peças trabalhadas (depois da montagem final).
func (p *Player) EndForgeSession() {
	forgeSessions.Lock()
	delete(forgeSessions.byPlayer, p.ID)
	forgeSessions.Unlock()
}

// MaterialFor: material do catálogo ou liga sintética do jogador.
func (p *Player) MaterialFor(id uint8) (MaterialDef, bool) {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return p.materialLocked(id)
}
