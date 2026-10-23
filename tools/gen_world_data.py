#!/usr/bin/env python3
"""Gera client/scripts/world/WorldData.gd a partir de tools/world_dump.json.

O JSON sai do próprio servidor (go run ./cmd/worlddump > ../tools/world_dump.json), então portais,
covis de criaturas e o Rio Prateado do cliente nunca divergem do servidor.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
d = json.loads((ROOT / "tools/world_dump.json").read_text())

lines = [
    "# ARQUIVO GERADO por tools/gen_world_data.py a partir de tools/world_dump.json — não edite à mão.",
    "# Para atualizar: cd server && go run ./cmd/worlddump > ../tools/world_dump.json && python3 tools/gen_world_data.py",
    "extends RefCounted",
    "",
    "## Zonas abertas na grade do mundo (col = leste, row = norte; cada célula tem 600 m).",
    "const ZONES := {",
]
for z in d["zones"]:
    lines.append('\t%d: {"name": "%s", "col": %d, "row": %d},' % (z["id"], z["name"], z["col"], z["row"]))
lines += ["}", "", "## Portais entre zonas abertas: posição do portal na zona de origem.", "const PORTALS := ["]
for p in d["portals"]:
    lines.append('\t{"id": %d, "from": %d, "to": %d, "x": %.1f, "z": %.1f, "name": "%s"},' % (
        p["id"], p["from"], p["to"], p["x"], p["z"], p["name"]))
lines += ["]", "", "## Covis de criaturas (perigo): as estradas passam longe deles, mesmo à noite.", "const DANGERS := {"]
by_zone = {}
for g in d["dangers"]:
    by_zone.setdefault(g["zone"], []).append(g)
for zid in sorted(by_zone):
    items = ", ".join('[%.1f, %.1f, %.1f, "%s"]' % (g["x"], g["z"], g["radius"], g["name"]) for g in by_zone[zid])
    lines.append("\t%d: [%s]," % (zid, items))
r = d["river"]
lines += ["}", "",
          "## Rio Prateado (mesma fórmula de server/internal/world/river.go).",
          "const RIVER_SOURCE_GZ := %.1f" % r["source_gz"],
          "const RIVER_MOUTH_GZ := %.1f" % r["mouth_gz"],
          "const RIVER_MOUTH_LAKE_R := %.1f" % r["mouth_lake_r"],
          "const ZONE_SPAN := %.1f" % r["span"], "",
          "## Prédios da Vila (server/internal/world/interiors.go): porta -> zona interna.",
          "const BUILDINGS := ["]
for b in d["buildings"]:
    lines.append('\t{"key": "%s", "name": "%s", "interior": %d, "x": %.1f, "z": %.1f, "w": %.1f, "d": %.1f, "h": %.1f, "door": "%s", "in_portal": %d, "out_portal": %d},' % (
        b["key"], b["name"], b["interior"], b["x"], b["z"], b["w"], b["d"], b["h"], b["door"], b["in_portal"], b["out_portal"]))
i = d["interior"]
lines += ["]", "",
          "## Sala interna dos prédios (porta na parede sul).",
          "const INTERIOR_HALF := %.1f" % i["half"],
          "const INTERIOR_DOOR_Z := %.1f" % i["door_z"],
          "const INTERIOR_ARRIVE_Z := %.1f" % i["arrive_z"],
          "const FORGE_FIRE := Vector3(%.1f, 0.0, %.1f)" % (i["forge_fire_x"], i["forge_fire_z"]),
          "const FORGE_FIRE_RADIUS := %.1f" % i["forge_fire_r"], ""]
out = ROOT / "client/scripts/world/WorldData.gd"
out.write_text("\n".join(lines))
print("WorldData.gd: %d zonas, %d portais, %d covis" % (len(d["zones"]), len(d["portals"]), len(d["dangers"])))
