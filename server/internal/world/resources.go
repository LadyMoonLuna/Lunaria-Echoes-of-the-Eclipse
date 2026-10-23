package world

import (
	"math"
	"math/rand"
	"sync"
	"time"
)

// Nós de coleta espalhados pelos mapas (Tecla E).
const (
	NodeTree    uint8 = 1 // Árvore — exige Machado
	NodeRock    uint8 = 2 // Rocha — exige Picareta
	NodeOre     uint8 = 3 // Veio de metal — exige Picareta
	NodeCrystal uint8 = 4 // Cristal — exige Picareta
	NodeVine    uint8 = 5 // Vinha/cipó/arbusto/cogumelo — arma cortante (1x) ou Tesoura (2x)
	NodeWater   uint8 = 6 // Fonte de água/ácido/orvalho — exige Frasco Vazio
	NodeMud     uint8 = 7 // Barreiro na margem do rio (barro/argila) — com as mãos ou Picareta (mais)
)

// HarvestRange: distância máxima (m) para coletar um nó.
const HarvestRange float32 = 4.0

// ResourceNode é um ponto de coleta no mundo.
type ResourceNode struct {
	ID         uint32
	ZoneID     uint8
	Kind       uint8
	MaterialID uint16
	Tier       uint8 // = raridade do material
	X, Z       float32
	DepletedAt time.Time
	RespawnIn  time.Duration
	DriedUp    bool // poça/riacho que secou no calor; só volta com chuva ou tempo ameno
	Purified   bool // Fonte Purificada da Vila: água sempre de alta qualidade
}

// Fonte de Água Purificada no centro da Vila (mesmo ponto onde os NPCs bebem).
var PurifiedFountainPos = [2]float32{0, 0}

const PurifiedFountainRadius float32 = 3.4

// Available informa se o nó já voltou a crescer.
func (n *ResourceNode) Available() bool {
	return !n.DriedUp && (n.DepletedAt.IsZero() || time.Since(n.DepletedAt) >= n.RespawnIn)
}

// BaseYield: recursos por coleta (materiais raros rendem menos).
func (n *ResourceNode) BaseYield() uint8 {
	switch {
	case n.Tier <= 1:
		return 3
	case n.Tier <= 3:
		return 2
	default:
		return 1
	}
}

var liquidMaterials = map[uint16]bool{MatPureWater: true, MatToxicWater: true, MatLunarDew: true, MatAcidSap: true}

// NodeKindForMaterial escolhe o tipo de nó pelo material.
func NodeKindForMaterial(materialID uint16) uint8 {
	if liquidMaterials[materialID] {
		return NodeWater
	}
	if materialID == MatMud || materialID == MatClay {
		return NodeMud
	}
	switch MaterialsDB[materialID].Category {
	case MatWood:
		return NodeTree
	case MatStone:
		return NodeRock
	case MatMetal:
		return NodeOre
	case MatCrystal:
		return NodeCrystal
	default:
		return NodeVine
	}
}

type spawnEntry struct {
	material uint16
	weight   int
}

// zoneResourceTables: o que nasce em cada zona (e com que frequência).
var zoneResourceTables = map[uint8][]spawnEntry{
	ZoneVillage: {{MatPineRefuge, 12}, {MatGreyOak, 6}, {MatStormCedar, 1}, {MatRawStone, 8}, {MatLimestone, 5},
		{MatCopper, 5}, {MatTin, 4}, {MatIron, 5}, {MatQuartz, 3}, {MatThornVine, 5}, {MatPureWater, 3}, {MatHerbs, 5}},
	ZoneForest: {{MatPineRefuge, 8}, {MatGreyOak, 8}, {MatStormCedar, 4}, {MatWhisperEbony, 2}, {MatBloodWillow, 1},
		{MatSolarAsh, 1}, {MatThornVine, 6}, {MatSteelLiana, 2}, {MatGlowMushroom, 4}, {MatParasiteMycel, 1}, {MatHerbs, 4},
		{MatPureWater, 3}, {MatLunarDew, 2}},
	ZoneRuins: {{MatRawStone, 6}, {MatBasalt, 4}, {MatLimestone, 4}, {MatIron, 6}, {MatSilver, 3}, {MatTitanium, 3},
		{MatLunarMithril, 2}, {MatQuartz, 4}, {MatManaCrystal, 2}, {MatZeroSapphire, 1}, {MatGreyOak, 2}},
	ZoneSanctuary: {{MatStarRock, 2}, {MatVoidStone, 3}, {MatManaCrystal, 4}, {MatBlackSunShard, 1}, {MatSolarAsh, 2},
		{MatLunarDew, 3}, {MatQuartz, 3}, {MatSilver, 2}},
	ZoneAshFrontier: {{MatObsidianRock, 4}, {MatBasalt, 5}, {MatCrimsonOrich, 1}, {MatAbyssTungsten, 2}, {MatFireRuby, 2},
		{MatIronwood, 2}, {MatAcidSap, 3}, {MatIron, 3}, {MatAdamantine, 1}},
	ZoneSparseWoods: {{MatPineRefuge, 8}, {MatGreyOak, 6}, {MatStormCedar, 2}, {MatThornVine, 5}, {MatHerbs, 6},
		{MatGlowMushroom, 3}, {MatRawStone, 4}, {MatCopper, 3}, {MatPureWater, 2}},
	ZoneGrasslands: {{MatHerbs, 9}, {MatThornVine, 6}, {MatRawStone, 5}, {MatLimestone, 5}, {MatCopper, 3}, {MatTin, 3},
		{MatGreyOak, 3}, {MatPureWater, 3}},
	ZoneSavanna: {{MatIronwood, 3}, {MatRawStone, 5}, {MatLimestone, 4}, {MatCopper, 4}, {MatIron, 3}, {MatThornVine, 5},
		{MatHerbs, 4}, {MatQuartz, 2}},
	ZoneSaltDesert: {{MatRawStone, 4}, {MatLimestone, 6}, {MatQuartz, 5}, {MatFireRuby, 2}, {MatStarRock, 1}, {MatIron, 3},
		{MatAcidSap, 3}},
	ZoneWindPlateau: {{MatPineRefuge, 6}, {MatRawStone, 8}, {MatBasalt, 3}, {MatIron, 5}, {MatCopper, 3}, {MatSilver, 2},
		{MatHerbs, 4}, {MatThornVine, 3}, {MatPureWater, 2}},
	ZoneFrozenPeaks: {{MatRawStone, 6}, {MatBasalt, 4}, {MatSilver, 4}, {MatTitanium, 3}, {MatLunarMithril, 2},
		{MatZeroSapphire, 2}, {MatManaCrystal, 3}, {MatQuartz, 4}},
	ZoneBasaltHills: {{MatBasalt, 8}, {MatObsidianRock, 3}, {MatRawStone, 5}, {MatIron, 5}, {MatCopper, 3}, {MatFireRuby, 1},
		{MatThornVine, 3}, {MatIronwood, 2}},
	ZoneMistMarsh: {{MatBloodWillow, 3}, {MatWhisperEbony, 2}, {MatThornVine, 6}, {MatSteelLiana, 3}, {MatGlowMushroom, 6},
		{MatParasiteMycel, 3}, {MatToxicWater, 5}, {MatLunarDew, 3}, {MatHerbs, 5}},
	ZoneAncientSewers: {{MatToxicWater, 5}, {MatIronEaterFungi, 2}, {MatGlowMushroom, 4}, {MatParasiteMycel, 2},
		{MatIron, 3}, {MatTin, 3}, {MatRawStone, 3}},
}

// A Raiz de Yggdrasil é única: um nó fixo no coração do Bosque.
var uniqueNodes = []ResourceNode{
	{ZoneID: ZoneForest, MaterialID: MatYggdrasilRoot, X: -60, Z: -40},
}

// Densidade: cada zona aberta tem ~42 agrupamentos (bosques, pedreiras, veios, canteiros, fontes)
// de 3 a 7 nós cada — em torno de 200 nós por zona de 600x600 m.
const (
	clustersPerOpenZone = 42
	minClusterSize      = 3
	maxClusterSize      = 7
)

// ResourceNodeManager guarda os nós de todas as zonas.
type ResourceNodeManager struct {
	mu    sync.Mutex
	nodes map[uint32]*ResourceNode
}

// NewResourceNodeManager gera os nós de forma determinística (mesmo mapa a cada boot).
func NewResourceNodeManager() *ResourceNodeManager {
	m := &ResourceNodeManager{nodes: make(map[uint32]*ResourceNode)}
	var nextID uint32 = 1
	add := func(n ResourceNode) {
		n.ID = nextID
		nextID++
		n.Kind = NodeKindForMaterial(n.MaterialID)
		n.Tier = MaterialsDB[n.MaterialID].Rarity
		n.RespawnIn = time.Duration(45+int(n.Tier)*30) * time.Second
		m.nodes[n.ID] = &n
	}
	for zone := uint8(0); zone < ZoneCount; zone++ {
		table, ok := zoneResourceTables[zone]
		if !ok {
			continue
		}
		rng := rand.New(rand.NewSource(int64(1000 + int(zone)*97)))
		total := 0
		for _, e := range table {
			total += e.weight
		}
		pick := func() uint16 {
			r := rng.Intn(total)
			for _, e := range table {
				if r < e.weight {
					return e.material
				}
				r -= e.weight
			}
			return table[0].material
		}
		for c := 0; c < clustersPerOpenZone; c++ {
			mat := pick()
			// Centro do agrupamento longe do spawn/praça e dentro dos limites da zona
			var cx, cz float64
			for {
				cx = rng.Float64()*520 - 260
				cz = rng.Float64()*520 - 260
				if math.Hypot(cx, cz) > 40 {
					break
				}
			}
			size := minClusterSize + rng.Intn(maxClusterSize-minClusterSize+1)
			spread := 9.0
			switch NodeKindForMaterial(mat) {
			case NodeTree:
				spread = 16.0 // bosques mais abertos
			case NodeWater:
				size = 1 + rng.Intn(2) // fontes são raras e pequenas
				spread = 5.0
			}
			for k := 0; k < size; k++ {
				m := mat
				if rng.Float64() < 0.2 {
					m = pick() // um pouco de variedade dentro do grupo
					if NodeKindForMaterial(m) == NodeWater {
						m = mat
					}
				}
				ang := rng.Float64() * 2 * math.Pi
				dist := 2.5 + rng.Float64()*spread
				x := float32(cx + math.Cos(ang)*dist)
				z := float32(cz + math.Sin(ang)*dist)
				if IsRiverWater(zone, x, z) {
					continue // nada nasce dentro do leito do rio
				}
				add(ResourceNode{ZoneID: zone, MaterialID: m, X: x, Z: z})
			}
		}
	}
	for _, n := range uniqueNodes {
		add(n)
	}
	// Fonte de Água Purificada no centro da praça da Vila: nunca seca e enche os frascos na hora
	add(ResourceNode{ZoneID: ZoneVillage, MaterialID: MatPureWater, X: PurifiedFountainPos[0], Z: PurifiedFountainPos[1] + PurifiedFountainRadius})
	m.nodes[nextID-1].RespawnIn = 2 * time.Second
	m.nodes[nextID-1].Purified = true
	// Barreiros de barro e argila ao longo das margens do Rio Prateado
	for zone := uint8(0); zone < ZoneCount; zone++ {
		rng := rand.New(rand.NewSource(int64(7000 + int(zone)*131)))
		side := 1.0
		for z := float32(-280); z <= 280; z += 32 {
			cx, w, ok := RiverAt(zone, z)
			if !ok {
				continue
			}
			side = -side
			mat := MatMud
			if rng.Float64() < 0.35 {
				mat = MatClay
			}
			x := float32(cx + side*(w/2+1.5+rng.Float64()*2))
			if x < -290 || x > 290 {
				continue
			}
			add(ResourceNode{ZoneID: zone, MaterialID: mat, X: x, Z: z + float32(rng.Float64()*8-4)})
		}
	}
	return m
}

// Get devolve uma cópia do nó.
func (m *ResourceNodeManager) Get(id uint32) (ResourceNode, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	n, ok := m.nodes[id]
	if !ok {
		return ResourceNode{}, false
	}
	return *n, true
}

// Deplete marca o nó como coletado (volta a crescer depois de RespawnIn).
func (m *ResourceNodeManager) Deplete(id uint32) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if n, ok := m.nodes[id]; ok {
		n.DepletedAt = time.Now()
	}
}

// InZone lista os nós de uma zona.
func (m *ResourceNodeManager) InZone(zone uint8) []ResourceNode {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]ResourceNode, 0)
	for id := uint32(1); id <= uint32(len(m.nodes)); id++ {
		if n, ok := m.nodes[id]; ok && n.ZoneID == zone {
			out = append(out, *n)
		}
	}
	return out
}

// RespawnedZones devolve as zonas onde algum nó acabou de voltar (para re-sincronizar).
func (m *ResourceNodeManager) RespawnedZones() []uint8 {
	m.mu.Lock()
	defer m.mu.Unlock()
	zones := map[uint8]bool{}
	for _, n := range m.nodes {
		if !n.DriedUp && !n.DepletedAt.IsZero() && time.Since(n.DepletedAt) >= n.RespawnIn {
			n.DepletedAt = time.Time{}
			zones[n.ZoneID] = true
		}
	}
	out := make([]uint8, 0, len(zones))
	for z := range zones {
		out = append(out, z)
	}
	return out
}

// IsEvaporable: pequenos agrupamentos de água que secam no calor.
func IsEvaporable(materialID uint16) bool {
	return materialID == MatPureWater || materialID == MatToxicWater || materialID == MatLunarDew
}

// UpdateEvaporation seca ou reabastece as águas rasas de uma zona conforme a temperatura.
// chance = probabilidade de cada poça secar nesta chamada. Retorna true se algo mudou.
func (m *ResourceNodeManager) UpdateEvaporation(zone uint8, tempC float32, raining bool, roll func() float32) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	changed := false
	for _, n := range m.nodes {
		if n.ZoneID != zone || !IsEvaporable(n.MaterialID) || n.Purified {
			continue
		}
		switch {
		case n.DriedUp && (raining || tempC < WaterRefillTemp):
			n.DriedUp = false
			n.DepletedAt = time.Time{}
			changed = true
		case !n.DriedUp && !raining && tempC > WaterDryTemp && roll() < (tempC-WaterDryTemp)*EvaporationChancePerDegree:
			n.DriedUp = true
			changed = true
		}
	}
	return changed
}

// SetPuddles seca (dry=true) ou enche todas as águas rasas de uma zona (comando DEV).
func (m *ResourceNodeManager) SetPuddles(zone uint8, dry bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, n := range m.nodes {
		if n.ZoneID == zone && IsEvaporable(n.MaterialID) {
			n.DriedUp = dry
			if !dry {
				n.DepletedAt = time.Time{}
			}
		}
	}
}
