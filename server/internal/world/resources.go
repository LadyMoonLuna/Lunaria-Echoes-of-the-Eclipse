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
}

// Available informa se o nó já voltou a crescer.
func (n *ResourceNode) Available() bool {
	return n.DepletedAt.IsZero() || time.Since(n.DepletedAt) >= n.RespawnIn
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
		{MatCopper, 5}, {MatTin, 4}, {MatIron, 5}, {MatQuartz, 3}, {MatThornVine, 5}, {MatPureWater, 3}},
	ZoneForest: {{MatPineRefuge, 8}, {MatGreyOak, 8}, {MatStormCedar, 4}, {MatWhisperEbony, 2}, {MatBloodWillow, 1},
		{MatSolarAsh, 1}, {MatThornVine, 6}, {MatSteelLiana, 2}, {MatGlowMushroom, 4}, {MatParasiteMycel, 1},
		{MatPureWater, 3}, {MatLunarDew, 2}},
	ZoneRuins: {{MatRawStone, 6}, {MatBasalt, 4}, {MatLimestone, 4}, {MatIron, 6}, {MatSilver, 3}, {MatTitanium, 3},
		{MatLunarMithril, 2}, {MatQuartz, 4}, {MatManaCrystal, 2}, {MatZeroSapphire, 1}, {MatGreyOak, 2}},
	ZoneSanctuary: {{MatStarRock, 2}, {MatVoidStone, 3}, {MatManaCrystal, 4}, {MatBlackSunShard, 1}, {MatSolarAsh, 2},
		{MatLunarDew, 3}, {MatQuartz, 3}, {MatSilver, 2}},
	ZoneAshFrontier: {{MatObsidianRock, 4}, {MatBasalt, 5}, {MatCrimsonOrich, 1}, {MatAbyssTungsten, 2}, {MatFireRuby, 2},
		{MatIronwood, 2}, {MatAcidSap, 3}, {MatIron, 3}, {MatAdamantine, 1}},
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
	for zone := uint8(0); zone <= ZoneAncientSewers; zone++ {
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
				add(ResourceNode{ZoneID: zone, MaterialID: m, X: x, Z: z})
			}
		}
	}
	for _, n := range uniqueNodes {
		add(n)
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
		if !n.DepletedAt.IsZero() && time.Since(n.DepletedAt) >= n.RespawnIn {
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
