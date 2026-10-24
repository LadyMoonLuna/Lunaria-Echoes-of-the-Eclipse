// worlddump exporta, em JSON, a geografia que o cliente precisa para desenhar o mundo:
// grade das zonas, portais externos, covis de criaturas (perigos que as estradas contornam)
// e as constantes do Rio Prateado. Uso: go run ./cmd/worlddump > ../tools/world_dump.json
package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"sort"

	"lunaria/server/internal/world"
)

type zoneOut struct {
	ID   uint8  `json:"id"`
	Name string `json:"name"`
	Col  int    `json:"col"`
	Row  int    `json:"row"`
}

type portalOut struct {
	ID   uint8   `json:"id"`
	From uint8   `json:"from"`
	To   uint8   `json:"to"`
	X    float64 `json:"x"`
	Z    float64 `json:"z"`
	Name string  `json:"name"`
}

type dangerOut struct {
	Zone   uint8   `json:"zone"`
	X      float64 `json:"x"`
	Z      float64 `json:"z"`
	Radius float64 `json:"radius"`
	Name   string  `json:"name"`
}

func main() {
	out := map[string]interface{}{}
	var zones []zoneOut
	for id, g := range world.ZoneGrid {
		zones = append(zones, zoneOut{id, world.GetZoneName(id), g[0], g[1]})
	}
	sort.Slice(zones, func(i, j int) bool { return zones[i].ID < zones[j].ID })
	out["zones"] = zones

	// Portais entre zonas abertas: o portal fica na borda da zona de origem, do lado de onde a viagem de volta chega
	var portals []portalOut
	for id, p := range world.OfficialPortals {
		_, a := world.ZoneGrid[p.FromZoneID]
		_, b := world.ZoneGrid[p.TargetZoneID]
		if !a || !b {
			continue
		}
		back, ok := world.FindPortal(p.TargetZoneID, p.FromZoneID)
		if !ok {
			continue
		}
		x, z := float64(back.TargetX), float64(back.TargetZ)
		scale := 285.0 / math.Max(math.Abs(x), math.Abs(z))
		portals = append(portals, portalOut{id, p.FromZoneID, p.TargetZoneID, x * scale, z * scale, p.Name})
	}
	sort.Slice(portals, func(i, j int) bool { return portals[i].ID < portals[j].ID })
	out["portals"] = portals

	// Covis de criaturas: raio maior para chefes (estradas passam bem longe, até de noite)
	var dangers []dangerOut
	for _, m := range world.NewMobManager().GetAllMobs() {
		if _, ok := world.ZoneGrid[m.ZoneID]; !ok {
			continue
		}
		r := 38.0
		if m.MaxHP >= 2500 {
			r = 75
		} else if m.MaxHP >= 900 {
			r = 55
		}
		dangers = append(dangers, dangerOut{m.ZoneID, float64(m.SpawnX), float64(m.SpawnZ), r, m.Name})
	}
	sort.Slice(dangers, func(i, j int) bool {
		if dangers[i].Zone != dangers[j].Zone {
			return dangers[i].Zone < dangers[j].Zone
		}
		if dangers[i].X != dangers[j].X {
			return dangers[i].X < dangers[j].X
		}
		return dangers[i].Z < dangers[j].Z
	})
	out["dangers"] = dangers
	// Prédios da Vila com porta para o interior (os portais de porta ficam fora da lista acima)
	type buildingOut struct {
		Key       string  `json:"key"`
		Name      string  `json:"name"`
		Interior  uint8   `json:"interior"`
		X         float32 `json:"x"`
		Z         float32 `json:"z"`
		W         float32 `json:"w"`
		D         float32 `json:"d"`
		H         float32 `json:"h"`
		Door      string  `json:"door"`
		InPortal  uint8   `json:"in_portal"`
		OutPortal uint8   `json:"out_portal"`
	}
	var buildings []buildingOut
	for _, b := range world.VillageBuildings {
		buildings = append(buildings, buildingOut{b.Key, b.Name, b.Interior, b.X, b.Z, b.W, b.D, b.H, b.Door, b.InPortal, b.OutPortal})
	}
	out["buildings"] = buildings
	out["interior"] = map[string]float32{"half": world.InteriorHalf, "door_z": world.InteriorDoorZ, "arrive_z": world.InteriorArriveZ,
		"forge_fire_x": world.ForgeFirePos[0], "forge_fire_z": world.ForgeFirePos[1], "forge_fire_r": world.ForgeFireRadius}
	// Forja (forge.go): receitas de ligas, blueprints por partes e etiquetas dos materiais
	type partOut struct {
		Name     string   `json:"name"`
		Tags     []string `json:"tags"`
		Role     string   `json:"role"`
		Share    float32  `json:"share"`
		Optional bool     `json:"optional"`
	}
	type bpOut struct {
		ID        uint8     `json:"id"`
		Name      string    `json:"name"`
		Kind      uint8     `json:"kind"`
		Slot      uint8     `json:"slot"`
		Tool      uint8     `json:"tool"`
		BaseATK   int       `json:"base_atk"`
		BaseDEF   int       `json:"base_def"`
		MassScale float32   `json:"mass_scale"`
		DurScale  float32   `json:"dur_scale"`
		Basic     bool      `json:"basic"`
		Price     uint32    `json:"price"`
		Scroll    uint8     `json:"scroll"`
		Parts     []partOut `json:"parts"`
	}
	var bps []bpOut
	for _, b := range world.Blueprints {
		o := bpOut{b.ID, b.Name, b.Kind, b.Slot, uint8(b.Tool), b.BaseATK, b.BaseDEF, b.MassScale, b.DurScale, b.Basic, b.Price, b.ScrollID, nil}
		for _, pt := range b.Parts {
			o.Parts = append(o.Parts, partOut{pt.Name, pt.Tags, pt.Role, pt.Share, pt.Optional})
		}
		bps = append(bps, o)
	}
	type recipeOut struct {
		Output uint16     `json:"output"`
		Qty    uint8      `json:"qty"`
		Groups [][]uint16 `json:"groups"`
	}
	var recipes []recipeOut
	for _, r := range world.AlloyRecipes {
		recipes = append(recipes, recipeOut{r.Output, r.Qty, r.Groups})
	}
	tags := map[string][]string{}
	for id, m := range world.MaterialsDB {
		tags[fmt.Sprint(id)] = world.MaterialTags(m)
	}
	specials := map[string]string{}
	for id, sp := range world.AlloySpecial {
		specials[fmt.Sprint(id)] = sp
	}
	out["forge"] = map[string]interface{}{"blueprints": bps, "recipes": recipes, "tags": tags, "tag_names": world.TagNames,
		"specials": specials, "stat_cap": 600, "anvil": world.ForgeAnvilPos}
	out["river"] = map[string]float64{
		"source_gz": world.RiverSourceGZ, "mouth_gz": world.RiverMouthGZ, "mouth_lake_r": world.RiverMouthLakeR,
		"span": world.ZoneSpan,
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	_ = enc.Encode(out)
}
