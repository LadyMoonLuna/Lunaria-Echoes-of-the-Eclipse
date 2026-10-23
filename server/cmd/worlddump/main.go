// worlddump exporta, em JSON, a geografia que o cliente precisa para desenhar o mundo:
// grade das zonas, portais externos, covis de criaturas (perigos que as estradas contornam)
// e as constantes do Rio Prateado. Uso: go run ./cmd/worlddump > ../tools/world_dump.json
package main

import (
	"encoding/json"
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
	out["river"] = map[string]float64{
		"source_gz": world.RiverSourceGZ, "mouth_gz": world.RiverMouthGZ, "mouth_lake_r": world.RiverMouthLakeR,
		"span": world.ZoneSpan,
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	_ = enc.Encode(out)
}
