package world

import (
	"fmt"
	"math"
	"math/rand"
)

// Fauna de Lunaria: 10 espécies por região aberta (fauna_data.go, gerado por tools/gen_fauna.py).
// Cada espécie tem corpo, temperamento, tamanho e massa reais: a massa decide quanto o corpo pesa
// para ser arrastado e quanto couro e carne ele rende. Peixes e bichos d'água vivem no Rio Prateado
// (ou nas lagoas das regiões sem rio) e são criaturas de verdade: têm vida, morrem e deixam corpo.

// Corpos (desenho no cliente e anatomia na autópsia)
const (
	FaunaQuadruped uint8 = 1
	FaunaBird      uint8 = 2
	FaunaSerpent   uint8 = 3
	FaunaInsect    uint8 = 4
	FaunaArachnid  uint8 = 5
	FaunaFish      uint8 = 6
	FaunaAmphibian uint8 = 7
	FaunaReptile   uint8 = 8
	FaunaCrab      uint8 = 9
)

// Temperamentos
const (
	TemperPassive     uint8 = 1 // foge de quem chega perto e de quem ataca
	TemperNeutral     uint8 = 2 // ignora, mas revida se for atacado
	TemperAggressive  uint8 = 3 // caça quem entra no seu campo de visão
	TemperTerritorial uint8 = 4 // avisa e ataca só quem invade o território (bem perto)
)

// Habitat aquático
const (
	HabitatLand  uint8 = 0
	HabitatRiver uint8 = 1 // Rio Prateado
	HabitatPond  uint8 = 2 // lagoas e canais da própria região
)

// FaunaDef descreve uma espécie.
type FaunaDef struct {
	Type    uint8
	Zone    uint8
	Name    string
	Body    uint8
	Temper  uint8
	HP      uint16
	Damage  int
	Speed   float32
	Scale   float32 // tamanho no cliente (1.0 ≈ um javali)
	MassKg  float32
	Color   string
	Habitat uint8
	Group   int // indivíduos por bando/cardume
	Hide    uint16
}

const (
	FaunaFirstType      uint8   = 100
	FaunaLastType       uint8   = 239
	faunaFirstMobID     uint32  = 20000
	faunaAggroRange     float32 = 16
	faunaTerritoryRange float32 = 7
	faunaFleeRange      float32 = 9
	faunaReach          float32 = 2.2
)

var faunaByType = map[uint8]FaunaDef{}

// FaunaByType devolve a espécie do tipo de mob (ok = false para monstros que não são fauna).
func FaunaByType(t uint8) (FaunaDef, bool) {
	d, ok := faunaByType[t]
	return d, ok
}

// IsFauna informa se o tipo de mob é uma espécie da fauna.
func IsFauna(t uint8) bool {
	_, ok := faunaByType[t]
	return ok
}

// Massa (kg) dos monstros antigos, para arrastar o corpo.
var monsterMassKg = map[uint8]float32{
	1: 45, 2: 75, 3: 75, 4: 70, 5: 140, 6: 95, 7: 160, 10: 75, 11: 420, 12: 85, 13: 110, 14: 250,
	15: 120, 16: 900, 17: 60, 18: 220, 19: 400, 20: 1500, 21: 900, 22: 3000, 23: 95, 24: 110, 25: 90, 26: 75,
}

// CorpseMassKg: quanto pesa o corpo da criatura.
func CorpseMassKg(mobType uint8) float32 {
	if d, ok := faunaByType[mobType]; ok {
		return d.MassKg
	}
	if m, ok := monsterMassKg[mobType]; ok {
		return m
	}
	return 70
}

// FaunaPond: lagoa das regiões sem rio (o cliente desenha a água no mesmo lugar).
type FaunaPond struct{ X, Z, R float32 }

// FaunaPonds: 3 lagoas fixas por região sem rio (mesma semente em servidor e cliente).
func FaunaPonds(zone uint8) []FaunaPond {
	if _, river := GlobalZ(zone, 0); river {
		return nil
	}
	if _, open := ZoneGrid[zone]; !open && zone != ZoneAncientSewers {
		return nil
	}
	rng := rand.New(rand.NewSource(int64(9100 + int(zone)*37)))
	var out []FaunaPond
	for len(out) < 3 {
		x := float32(rng.Float64()*440 - 220)
		z := float32(rng.Float64()*440 - 220)
		if math.Hypot(float64(x), float64(z)) < 70 {
			continue
		}
		out = append(out, FaunaPond{x, z, 14 + float32(rng.Float64()*8)})
	}
	return out
}

// InFaunaWater: o ponto está na água onde a espécie vive.
func InFaunaWater(d FaunaDef, zone uint8, x, z float32) bool {
	switch d.Habitat {
	case HabitatRiver:
		return IsRiverWater(zone, x, z)
	case HabitatPond:
		for _, p := range FaunaPonds(zone) {
			if (x-p.X)*(x-p.X)+(z-p.Z)*(z-p.Z) <= p.R*p.R {
				return true
			}
		}
	}
	return false
}

// faunaSpawnPoints: bando/cardume de cada espécie num ponto coerente com o habitat.
func faunaSpawnPoints(d FaunaDef, rng *rand.Rand) [][2]float32 {
	var center [2]float32
	switch d.Habitat {
	case HabitatRiver:
		for tries := 0; tries < 50; tries++ {
			z := float32(rng.Float64()*500 - 250)
			if cx, _, ok := RiverAt(d.Zone, z); ok {
				center = [2]float32{float32(cx), z}
				break
			}
		}
	case HabitatPond:
		ponds := FaunaPonds(d.Zone)
		if len(ponds) > 0 {
			p := ponds[rng.Intn(len(ponds))]
			center = [2]float32{p.X, p.Z}
		}
	default:
		for {
			center = [2]float32{float32(rng.Float64()*480 - 240), float32(rng.Float64()*480 - 240)}
			if d.Zone != ZoneVillage || math.Hypot(float64(center[0]), float64(center[1])) > 100 {
				break // nada de bichos dentro dos muros da Vila
			}
		}
	}
	pts := make([][2]float32, 0, d.Group)
	for i := 0; i < d.Group; i++ {
		spread := float32(4 + 3*d.Scale)
		p := [2]float32{center[0] + (rng.Float32()*2-1)*spread, center[1] + (rng.Float32()*2-1)*spread}
		if d.Habitat != HabitatLand && !InFaunaWater(d, d.Zone, p[0], p[1]) {
			p = center // peixes nunca nascem em seco
		}
		pts = append(pts, p)
	}
	return pts
}

// spawnFauna povoa todas as regiões com a fauna do catálogo.
func (mm *MobManager) spawnFauna() {
	id := faunaFirstMobID
	for _, d := range FaunaCatalog {
		rng := rand.New(rand.NewSource(int64(d.Type) * 7919))
		for _, p := range faunaSpawnPoints(d, rng) {
			m := NewMobWithZone(id, d.Name, d.Type, d.Zone, p[0], 0, p[1], d.HP, d.Speed)
			m.WanderX, m.WanderZ = p[0], p[1]
			mm.Mobs[id] = m
			id++
		}
	}
}

// faunaQty: quantidade que o corpo rende (bichos maiores dão mais couro e carne).
func faunaQty(mass, per float32, maxQ int) uint8 {
	q := 1 + int(mass/per)
	return uint8(min(maxQ, max(1, q)))
}

// faunaOrgans: anatomia de cada corpo (couro/escamas/penas, carne, sangue, órgãos e venenos).
func faunaOrgans(d FaunaDef) []CorpseOrgan {
	var out []CorpseOrgan
	add := func(t uint8, mat uint16, name string, qty uint8, diff uint8) {
		out = append(out, CorpseOrgan{Index: uint8(len(out)), Name: name, OrganType: t, ItemReward: uint8(mat), Quantity: qty, Difficulty: diff})
	}
	big := d.MassKg >= 5
	hideName := map[uint16]string{MatScales: "Escamas", MatFeathers: "Penas", MatBones: "Carapaça e Ossos", MatSpiderWeb: "Fiandeiras e Teia",
		MatScorpionChitin: "Quitina", MatRawHide: "Pele Crua", MatThickFur: "Pelagem", MatWolfLeather: "Couro", MatBoarLeather: "Couro Grosso"}[d.Hide]
	hideDiff := uint8(2 + min(6, int(d.MassKg/120)))
	add(OrganPelt, d.Hide, fmt.Sprintf("%s de %s", hideName, d.Name), faunaQty(d.MassKg, 150, 4), hideDiff)
	switch d.Body {
	case FaunaInsect, FaunaArachnid:
		add(OrganGuts, MatElasticGuts, "Tendões e Fiandeiras", 1, 4)
		add(OrganEyes, MatFacetedEyes, "Olhos Multifacetados", 1, 7)
		if d.Temper == TemperAggressive || d.Body == FaunaArachnid {
			add(OrganVenomSac, MatVorpalSac, "Bolsa de Veneno", 1, 8)
		}
		return out
	case FaunaCrab:
		add(OrganGuts, MatGameMeat, fmt.Sprintf("Carne de %s", d.Name), faunaQty(d.MassKg, 3, 3), 3)
		return out
	}
	add(OrganGuts, MatGameMeat, fmt.Sprintf("Carne de %s", d.Name), faunaQty(d.MassKg, 60, 6), 2)
	if d.Body != FaunaFish {
		add(OrganBlood, MatFreshBlood, fmt.Sprintf("Sangue de %s", d.Name), 1, 3)
	}
	if big {
		add(OrganHeart, MatPulsingHeart, fmt.Sprintf("Coração de %s", d.Name), 1, 6)
		if d.Body == FaunaQuadruped || d.Body == FaunaAmphibian || d.Body == FaunaReptile {
			add(OrganLiver, MatFilterLiver, fmt.Sprintf("Fígado de %s", d.Name), 1, 5)
			add(OrganLungs, MatLungs, fmt.Sprintf("Pulmões de %s", d.Name), 1, 6)
		}
	}
	if (d.Body == FaunaQuadruped || d.Body == FaunaReptile || d.Body == FaunaSerpent) && d.Damage > 0 {
		add(OrganFangOrClaw, MatSharpFangs, fmt.Sprintf("Presas e Garras de %s", d.Name), 1, 4)
	}
	if d.Body == FaunaSerpent && d.Temper != TemperPassive && d.MassKg < 20 {
		add(OrganVenomSac, MatVorpalSac, "Bolsa de Veneno", 1, 9)
	}
	if d.Body == FaunaBird || d.Body == FaunaFish {
		add(OrganEyes, MatFacetedEyes, fmt.Sprintf("Olhos de %s", d.Name), 1, 6)
	}
	return out
}

func init() {
	for _, d := range FaunaCatalog {
		faunaByType[d.Type] = d
	}
}
