extends RefCounted
## Relevo vivo de Lunaria: cada zona aberta (600 x 600 m) tem altura, biomas, o Rio Prateado,
## lagos, cordilheiras nas bordas sem portal (com passagens nos portais), dunas, vulcão e brejos.
##
## A altura é determinística (mesma semente em todo cliente). Os pontos em que o servidor põe
## jogadores (praças centrais, portais, interior da Vila) ficam planos na altura 0, e os NPCs,
## criaturas e itens são apoiados no chão pelo cliente (o servidor só conhece X/Z).
##
## Uso:
##   const LunariaTerrain = preload("res://scripts/world/Terrain.gd")
##   LunariaTerrain.prepare(zone)            # calcula grade final (com estradas)
##   var y := LunariaTerrain.height(zone, x, z)

const Data = preload("res://scripts/world/WorldData.gd")

const HALF := 300.0
const STEP := 4.0
const N := 151 # vértices por lado (600 m / 4 m + 1)
const ROAD_CELL := 10.0
const ROAD_N := 61
const ROAD_HALF_WIDTH := 2.6
const WATER_RIVER_Y := -0.7
const RIVER_BED_Y := -2.4

## Biomas por zona. ground = [baixo, médio, alto/rocha]; snow = altura da neve (999 = nunca).
const BIOMES := {
	0: {"name": "Vila do Refúgio", "ground": [Color("#5d8a3e"), Color("#6f8f47"), Color("#7b776a")], "amp": 7.0, "scale": 210.0,
		"offset": 0.0, "wall": 26.0, "peaks": 0.0, "snow": 999.0, "veg": [["oak", 5], ["birch", 2], ["pine", 2], ["bush", 3], ["rock", 1]],
		"spacing": 9.0, "glade": 0.48, "grass": 0.55, "grass_col": Color("#7aa04a"), "lakes": []},
	1: {"name": "Bosque Sussurrante", "ground": [Color("#33572b"), Color("#3f6532"), Color("#6a6a5c")], "amp": 10.0, "scale": 170.0,
		"offset": 0.0, "wall": 34.0, "peaks": 0.0, "snow": 999.0, "veg": [["oak", 5], ["pine", 5], ["birch", 1], ["bush", 3], ["mushroom", 1], ["rock", 1]],
		"spacing": 5.5, "glade": 0.36, "grass": 0.4, "grass_col": Color("#4f7d36"), "lakes": [[-100.0, 40.0, 20.0, 3.0]]},
	9: {"name": "Bosque Ralo", "ground": [Color("#557d38"), Color("#6a8c40"), Color("#7a7464")], "amp": 9.0, "scale": 190.0,
		"offset": 0.0, "wall": 30.0, "peaks": 0.0, "snow": 999.0, "veg": [["oak", 4], ["birch", 3], ["pine", 2], ["bush", 4], ["rock", 2]],
		"spacing": 9.5, "glade": 0.5, "grass": 0.6, "grass_col": Color("#86a84c"), "lakes": [[-180.0, -40.0, 16.0, 2.5]]},
	10: {"name": "Campos Rasteiros", "ground": [Color("#7f9a48"), Color("#93a552"), Color("#8a8266")], "amp": 6.0, "scale": 240.0,
		"offset": 0.0, "wall": 22.0, "peaks": 0.0, "snow": 999.0, "veg": [["bush", 6], ["oak", 1], ["rock", 2], ["birch", 1]],
		"spacing": 17.0, "glade": 0.55, "grass": 0.85, "grass_col": Color("#a7b55a"), "lakes": [[-150.0, 120.0, 18.0, 2.5], [170.0, -200.0, 14.0, 2.0]]},
	11: {"name": "Savana Dourada", "ground": [Color("#b49a52"), Color("#c2a45a"), Color("#9c7d58")], "amp": 6.5, "scale": 230.0,
		"offset": 0.0, "wall": 24.0, "peaks": 0.0, "snow": 999.0, "veg": [["acacia", 5], ["bush", 3], ["termite", 2], ["rock", 2], ["dead", 1]],
		"spacing": 21.0, "glade": 0.45, "grass": 0.8, "grass_col": Color("#d1b45e"), "lakes": []},
	12: {"name": "Deserto de Sal", "ground": [Color("#e3d3a4"), Color("#d8c08a"), Color("#b98c5e")], "amp": 5.0, "scale": 260.0,
		"offset": 0.0, "wall": 30.0, "peaks": 0.0, "dunes": 9.0, "snow": 999.0, "veg": [["cactus", 5], ["rock", 3], ["dead", 2]],
		"spacing": 30.0, "glade": 0.5, "grass": 0.06, "grass_col": Color("#c9b06e"), "lakes": [[-130.0, -120.0, 26.0, 2.5]], "oasis": [-130.0, -120.0]},
	13: {"name": "Planalto dos Ventos", "ground": [Color("#6e8a4c"), Color("#86906a"), Color("#8e8b84")], "amp": 16.0, "scale": 180.0,
		"offset": 0.0, "wall": 40.0, "peaks": 10.0, "snow": 42.0, "veg": [["pine", 4], ["rock", 5], ["bush", 3], ["birch", 1]],
		"spacing": 13.0, "glade": 0.5, "grass": 0.55, "grass_col": Color("#9aa565"), "lakes": [], "caves": 2},
	2: {"name": "Ruínas da Vigília", "ground": [Color("#8c968c"), Color("#b4bcc0"), Color("#e8eef2")], "amp": 12.0, "scale": 190.0,
		"offset": 0.0, "wall": 44.0, "peaks": 8.0, "snow": 16.0, "veg": [["snowpine", 5], ["pine", 2], ["rock", 4], ["dead", 1]],
		"spacing": 12.0, "glade": 0.48, "grass": 0.2, "grass_col": Color("#a7b0a0"), "lakes": [], "caves": 2},
	14: {"name": "Picos Gelados", "ground": [Color("#cfd8de"), Color("#e8eef2"), Color("#ffffff")], "amp": 14.0, "scale": 150.0,
		"offset": 0.0, "wall": 60.0, "peaks": 38.0, "snow": 4.0, "veg": [["snowpine", 4], ["rock", 4], ["crystal", 1]],
		"spacing": 15.0, "glade": 0.5, "grass": 0.0, "grass_col": Color("#dfe7ea"), "lakes": [], "glacier": true, "caves": 4},
	15: {"name": "Colinas de Basalto", "ground": [Color("#8c7d5a"), Color("#7d6d58"), Color("#4c4846")], "amp": 15.0, "scale": 160.0,
		"offset": 0.0, "wall": 36.0, "peaks": 9.0, "snow": 999.0, "veg": [["basalt", 4], ["dead", 2], ["bush", 3], ["acacia", 1], ["rock", 3]],
		"spacing": 15.0, "glade": 0.5, "grass": 0.35, "grass_col": Color("#a49460"), "lakes": [], "caves": 3},
	4: {"name": "Fronteira das Cinzas", "ground": [Color("#4a3f3a"), Color("#3a3230"), Color("#262222")], "amp": 10.0, "scale": 170.0,
		"offset": 0.0, "wall": 40.0, "peaks": 6.0, "snow": 999.0, "veg": [["dead", 4], ["basalt", 4], ["rock", 3], ["crystal", 1]],
		"spacing": 16.0, "glade": 0.5, "grass": 0.05, "grass_col": Color("#6a5a50"), "lakes": [], "volcano": [165.0, -150.0, 75.0, 58.0], "caves": 2},
	3: {"name": "Santuário do Eclipse", "ground": [Color("#4d4a63"), Color("#5c5878"), Color("#7a7690")], "amp": 11.0, "scale": 180.0,
		"offset": 0.0, "wall": 34.0, "peaks": 5.0, "snow": 999.0, "veg": [["dead", 3], ["crystal", 2], ["birch", 2], ["rock", 3]],
		"spacing": 12.0, "glade": 0.5, "grass": 0.35, "grass_col": Color("#7d7a9a"), "lakes": [[-160.0, -150.0, 22.0, 3.0]]},
	16: {"name": "Pântano das Brumas", "ground": [Color("#3e4a2e"), Color("#4b5734"), Color("#5c5a48")], "amp": 1.6, "scale": 140.0,
		"offset": 0.45, "wall": 26.0, "peaks": 0.0, "snow": 999.0, "veg": [["willow", 5], ["reed", 5], ["mushroom", 2], ["dead", 2]],
		"spacing": 8.0, "glade": 0.4, "grass": 0.6, "grass_col": Color("#5f6f38"), "lakes": [], "marsh": true},
}

static var _noise_cache: Dictionary = {}
static var _grid_cache: Dictionary = {}   # zone -> PackedFloat32Array (altura final, N x N)
static var _road_cache: Dictionary = {}   # zone -> Array[PackedVector2Array]
static var _road_dist_cache: Dictionary = {} # zone -> PackedFloat32Array (distância até a estrada, grade N x N)

# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

static func is_open_zone(zone: int) -> bool:
	return Data.ZONES.has(zone)

static func biome(zone: int) -> Dictionary:
	return BIOMES.get(zone, BIOMES[0])

## Altura final (com estradas) se a zona já foi preparada; senão a altura base analítica.
static func height(zone: int, x: float, z: float) -> float:
	if not is_open_zone(zone):
		return 0.0
	if _grid_cache.has(zone):
		return _sample_grid(_grid_cache[zone], x, z)
	return base_height(zone, x, z)

## Gera (uma vez) a grade final da zona: relevo + estradas achatadas.
static func prepare(zone: int) -> void:
	if not is_open_zone(zone) or _grid_cache.has(zone):
		return
	var grid := PackedFloat32Array()
	grid.resize(N * N)
	for j in range(N):
		var z := -HALF + j * STEP
		for i in range(N):
			var x := -HALF + i * STEP
			grid[j * N + i] = base_height(zone, x, z)
	var roads := roads_for(zone)
	_flatten_roads(zone, grid, roads)
	_grid_cache[zone] = grid

static func grid_for(zone: int) -> PackedFloat32Array:
	prepare(zone)
	return _grid_cache.get(zone, PackedFloat32Array())

static func _sample_grid(grid: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + HALF) / STEP, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / STEP, 0.0, N - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := grid[j * N + i]
	var h10 := grid[j * N + i + 1]
	var h01 := grid[(j + 1) * N + i]
	var h11 := grid[(j + 1) * N + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

# ---------------------------------------------------------------------------
# Rio Prateado (mesma fórmula do servidor: server/internal/world/river.go)
# ---------------------------------------------------------------------------

static func global_z(zone: int, z: float) -> float:
	var info: Dictionary = Data.ZONES.get(zone, {})
	if info.is_empty() or int(info["col"]) != 0:
		return INF
	return float(info["row"]) * Data.ZONE_SPAN + z

static func river_x(gz: float) -> float:
	return 116.0 + 14.0 * sin(gz / 83.0) + 7.0 * sin(gz / 31.0 + 1.7) + 3.0 * sin(gz / 13.0 + 0.4)

static func river_width(gz: float) -> float:
	return 7.0 + (Data.RIVER_SOURCE_GZ - gz) / 600.0

## [centro_x, largura] do rio na altura z da zona, ou [] se não há rio ali.
static func river_at(zone: int, z: float) -> Array:
	var gz := global_z(zone, z)
	if gz == INF or gz > Data.RIVER_SOURCE_GZ or gz < Data.RIVER_MOUTH_GZ:
		return []
	return [river_x(gz), river_width(gz)]

static func has_river(zone: int) -> bool:
	return not river_at(zone, 0.0).is_empty() or not river_at(zone, 290.0).is_empty() or not river_at(zone, -290.0).is_empty()

## Lagos da zona: [x, z, raio, profundidade] — inclui o lago glacial (nascente) e o Grande Lago (foz).
static func lakes(zone: int) -> Array:
	var out: Array = biome(zone).get("lakes", []).duplicate()
	var info: Dictionary = Data.ZONES.get(zone, {})
	if not info.is_empty() and int(info["col"]) == 0:
		var row := float(info["row"])
		var src_z: float = Data.RIVER_SOURCE_GZ - row * Data.ZONE_SPAN
		if absf(src_z) < HALF:
			out.append([river_x(Data.RIVER_SOURCE_GZ), src_z, 40.0, 4.0])
		var mouth_z: float = Data.RIVER_MOUTH_GZ - row * Data.ZONE_SPAN
		if absf(mouth_z) < HALF:
			out.append([river_x(Data.RIVER_MOUTH_GZ), mouth_z, Data.RIVER_MOUTH_LAKE_R, 4.0])
	return out

static func water_y(zone: int) -> float:
	return -0.05 if biome(zone).get("marsh", false) else WATER_RIVER_Y

## Ponto dentro d'água (rio, lago ou poça do brejo)?
static func is_water(zone: int, x: float, z: float, margin: float = 0.0) -> bool:
	var r := river_at(zone, z)
	if not r.is_empty() and absf(x - float(r[0])) < float(r[1]) * 0.5 + margin:
		return true
	for l in lakes(zone):
		if Vector2(x - float(l[0]), z - float(l[1])).length() < float(l[2]) + margin:
			return true
	if biome(zone).get("marsh", false):
		return base_height(zone, x, z) < water_y(zone) + 0.05 - margin * 0.1
	return false

# ---------------------------------------------------------------------------
# Relevo
# ---------------------------------------------------------------------------

static func _noise(zone: int, kind: String) -> FastNoiseLite:
	var key := "%d:%s" % [zone, kind]
	if _noise_cache.has(key):
		return _noise_cache[key]
	var n := FastNoiseLite.new()
	n.seed = zone * 7919 + kind.hash() % 1000
	match kind:
		"base":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 4
			n.frequency = 1.0 / float(biome(zone)["scale"])
		"ridge":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
			n.fractal_octaves = 4
			n.frequency = 1.0 / 120.0
		"detail":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 1.0 / 28.0
		"veg":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 3
			n.frequency = 1.0 / 70.0
		"wiggle":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 1.0 / 45.0
	_noise_cache[key] = n
	return n

## Lados da zona com portal: {"n": x_do_portal, ...}. Os outros lados viram cordilheira.
static func portal_sides(zone: int) -> Dictionary:
	var sides := {}
	for p in Data.PORTALS:
		if int(p["from"]) != zone:
			continue
		var px: float = p["x"]
		var pz: float = p["z"]
		if pz > 200.0:
			sides["n"] = px
		elif pz < -200.0:
			sides["s"] = px
		elif px > 200.0:
			sides["e"] = pz
		elif px < -200.0:
			sides["w"] = pz
	return sides

static func portals_of(zone: int) -> Array:
	var out: Array = []
	for p in Data.PORTALS:
		if int(p["from"]) == zone:
			out.append(p)
	return out

## Altura sem as estradas (analítica).
static func base_height(zone: int, x: float, z: float) -> float:
	var b := biome(zone)
	var amp: float = b["amp"]
	var h: float = _noise(zone, "base").get_noise_2d(x, z) * amp + float(b["offset"])
	h += _noise(zone, "detail").get_noise_2d(x, z) * amp * 0.18
	var ridge: float = _noise(zone, "ridge").get_noise_2d(x, z) * 0.5 + 0.5

	# Picos internos (longe da praça central)
	var peaks: float = b.get("peaks", 0.0)
	if peaks > 0.0:
		var mask := smoothstep(70.0, 160.0, Vector2(x, z).length())
		h += ridge * ridge * peaks * mask

	# Dunas (deserto): cristas tortas pelo vento
	var dunes: float = b.get("dunes", 0.0)
	if dunes > 0.0:
		var warp := _noise(zone, "detail").get_noise_2d(x * 0.5, z * 0.5) * 3.0
		var d := 0.5 + 0.5 * sin((x * 0.7 + z * 0.45) / 15.0 + warp)
		h += dunes * d * d * smoothstep(40.0, 90.0, Vector2(x, z).length())

	# Cordilheiras nas bordas; nos lados com portal abre-se um desfiladeiro (passagem)
	var wall: float = b.get("wall", 0.0)
	if wall > 0.0:
		var sides := portal_sides(zone)
		var edges := {"n": [HALF - z, x], "s": [HALF + z, x], "e": [HALF - x, z], "w": [HALF + x, z]}
		for side in edges:
			var dist: float = edges[side][0]
			if dist > 95.0:
				continue
			var m := smoothstep(95.0, 8.0, dist)
			if sides.has(side):
				var lateral: float = absf(float(edges[side][1]) - float(sides[side]))
				m *= smoothstep(26.0, 85.0, lateral)
			h += wall * m * (0.55 + 0.45 * ridge)

	# Vulcão
	if b.has("volcano"):
		var v: Array = b["volcano"]
		var dv := Vector2(x - float(v[0]), z - float(v[1])).length()
		if dv < float(v[2]):
			var cone: float = pow(1.0 - dv / float(v[2]), 1.6) * float(v[3])
			var crater: float = smoothstep(12.0, 0.0, dv) * 14.0
			h = maxf(h, cone - crater)

	# Brejo: poças onde o terreno afunda
	if b.get("marsh", false):
		h -= maxf(0.0, -_noise(zone, "veg").get_noise_2d(x * 1.7, z * 1.7)) * 2.4

	# Lagos
	for l in lakes(zone):
		var dl := Vector2(x - float(l[0]), z - float(l[1])).length()
		var r: float = l[2]
		if dl < r * 1.6:
			h = lerpf(h, -float(l[3]), smoothstep(r * 1.6, r * 0.7, dl))

	# Rio: vale e leito
	var rv := river_at(zone, z)
	if not rv.is_empty():
		var dr := absf(x - float(rv[0]))
		var w: float = rv[1]
		if dr < w * 4.0:
			h = lerpf(h, minf(h, 0.6), smoothstep(w * 4.0, w * 1.2, dr))
			h = lerpf(h, RIVER_BED_Y, smoothstep(w * 0.95, w * 0.3, dr))

	# Áreas planas na altura 0: interior da Vila, praça central e portais
	if zone == 0:
		var core := maxf(absf(x), absf(z))
		h = lerpf(h, 0.0, smoothstep(125.0, 90.0, core))
	h = lerpf(h, 0.0, smoothstep(48.0, 24.0, Vector2(x, z).length()))
	for p in portals_of(zone):
		var dp := Vector2(x - float(p["x"]), z - float(p["z"])).length()
		h = lerpf(h, 0.0, smoothstep(40.0, 20.0, dp))
	return h

# ---------------------------------------------------------------------------
# Estradas: A* que foge de covis, água, encostas e bordas — e nunca sai reta
# ---------------------------------------------------------------------------

## Pares de pontos ligados por estrada na zona.
static func road_links(zone: int) -> Array:
	var links: Array = []
	var ports := portals_of(zone)
	if zone == 0:
		# Dos portões da muralha (±80 m) até o portal de cada lado
		for p in ports:
			var px: float = p["x"]
			var pz: float = p["z"]
			var gate := Vector2(0.0, 92.0 * signf(pz)) if absf(pz) > absf(px) else Vector2(92.0 * signf(px), 0.0)
			links.append([gate, Vector2(px, pz) * 0.93])
		return links
	for p in ports:
		links.append([Vector2(0.0, 0.0), Vector2(float(p["x"]), float(p["z"])) * 0.93])
	return links

static func roads_for(zone: int) -> Array:
	if _road_cache.has(zone):
		return _road_cache[zone]
	var roads: Array = []
	if is_open_zone(zone):
		var cost := _road_cost_grid(zone)
		for link in road_links(zone):
			var path := _astar(cost, link[0], link[1], zone)
			if path.size() >= 2:
				roads.append(_smooth(path))
	_road_cache[zone] = roads
	return roads

static func _cell_center(i: int, j: int) -> Vector2:
	return Vector2(-HALF + i * ROAD_CELL, -HALF + j * ROAD_CELL)

static func _road_cost_grid(zone: int) -> PackedFloat32Array:
	var cost := PackedFloat32Array()
	cost.resize(ROAD_N * ROAD_N)
	var dangers: Array = Data.DANGERS.get(zone, [])
	var wiggle := _noise(zone, "wiggle")
	for j in range(ROAD_N):
		for i in range(ROAD_N):
			var c := _cell_center(i, j)
			var v := 1.0 + (wiggle.get_noise_2d(c.x, c.y) * 0.5 + 0.5) * 1.6
			# Encostas
			var h := base_height(zone, c.x, c.y)
			var hx := base_height(zone, c.x + ROAD_CELL, c.y)
			var hz := base_height(zone, c.x, c.y + ROAD_CELL)
			v += (absf(hx - h) + absf(hz - h)) * 1.4
			# Covis de criaturas: nunca por dentro, e com folga
			for dz in dangers:
				var dd := Vector2(c.x - float(dz[0]), c.y - float(dz[1])).length()
				var r: float = dz[2]
				if dd < r:
					v += 600.0
				elif dd < r * 1.8:
					v += 45.0 * (1.0 - (dd - r) / (r * 0.8))
			# Água: o rio só se cruza por ponte (curta); lagos e brejo fundo, nunca
			var rv := river_at(zone, c.y)
			if not rv.is_empty() and absf(c.x - float(rv[0])) < float(rv[1]) * 0.6 + 2.0:
				v += 70.0
			for l in lakes(zone):
				if Vector2(c.x - float(l[0]), c.y - float(l[1])).length() < float(l[2]) + 6.0:
					v += 900.0
			if h < water_y(zone) + 0.1:
				v += 80.0
			# Muralha da Vila (só os portões)
			if zone == 0 and maxf(absf(c.x), absf(c.y)) < 88.0:
				v += 2000.0
			# Bordas da zona
			if maxf(absf(c.x), absf(c.y)) > 275.0:
				v += 25.0
			cost[j * ROAD_N + i] = v
	return cost

static func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(round((p.x + HALF) / ROAD_CELL)), 0, ROAD_N - 1), clampi(int(round((p.y + HALF) / ROAD_CELL)), 0, ROAD_N - 1))

static func _astar(cost: PackedFloat32Array, from: Vector2, to: Vector2, _zone: int) -> PackedVector2Array:
	var start := _to_cell(from)
	var goal := _to_cell(to)
	var total := ROAD_N * ROAD_N
	var g := PackedFloat32Array()
	g.resize(total)
	g.fill(INF)
	var came := PackedInt32Array()
	came.resize(total)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(total)
	var s_idx := start.y * ROAD_N + start.x
	var goal_idx := goal.y * ROAD_N + goal.x
	g[s_idx] = 0.0
	var open: Array = [[_heur(start, goal), s_idx]]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while not open.is_empty():
		# fila de prioridade simples (a grade tem 3.721 células)
		var best := 0
		for k in range(1, open.size()):
			if open[k][0] < open[best][0]:
				best = k
		var cur: int = open[best][1]
		open.remove_at(best)
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		if cur == goal_idx:
			break
		var cx := cur % ROAD_N
		var cz := cur / ROAD_N
		for d in dirs:
			var nx: int = cx + d.x
			var nz: int = cz + d.y
			if nx < 0 or nz < 0 or nx >= ROAD_N or nz >= ROAD_N:
				continue
			var n_idx := nz * ROAD_N + nx
			if closed[n_idx] == 1:
				continue
			var step_len := 1.4142 if d.x != 0 and d.y != 0 else 1.0
			var ng := g[cur] + step_len * (cost[cur] + cost[n_idx]) * 0.5
			if ng < g[n_idx]:
				g[n_idx] = ng
				came[n_idx] = cur
				open.append([ng + _heur(Vector2i(nx, nz), goal), n_idx])
	var path := PackedVector2Array()
	if came[goal_idx] == -1 and goal_idx != s_idx:
		return path
	var idx := goal_idx
	while idx != -1:
		path.append(_cell_center(idx % ROAD_N, idx / ROAD_N))
		idx = came[idx]
	path.reverse()
	path[0] = from
	path[path.size() - 1] = to
	return path

static func _heur(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length() * 1.0

## Suaviza o caminho em curvas (Chaikin) — estradas sinuosas, como as de mercadores.
static func _smooth(path: PackedVector2Array) -> PackedVector2Array:
	var pts := path
	for _it in range(4):
		var out := PackedVector2Array()
		out.append(pts[0])
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		out.append(pts[pts.size() - 1])
		pts = out
	# reamostra a cada ~3 m
	var res := PackedVector2Array()
	res.append(pts[0])
	var acc := 0.0
	for k in range(1, pts.size()):
		acc += pts[k].distance_to(pts[k - 1])
		if acc >= 3.0:
			res.append(pts[k])
			acc = 0.0
	if res[res.size() - 1] != pts[pts.size() - 1]:
		res.append(pts[pts.size() - 1])
	return res

## Distância aproximada de (x,z) até a estrada mais próxima (grade de 4 m, até 24 m; além disso = 99).
static func road_distance(zone: int, x: float, z: float) -> float:
	if not _road_dist_cache.has(zone):
		_road_dist_cache[zone] = _build_road_distance(zone)
	var grid: PackedFloat32Array = _road_dist_cache[zone]
	var i := clampi(int(round((x + HALF) / STEP)), 0, N - 1)
	var j := clampi(int(round((z + HALF) / STEP)), 0, N - 1)
	return grid[j * N + i]

static func _build_road_distance(zone: int) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(N * N)
	grid.fill(99.0)
	var reach := 24.0
	for road in roads_for(zone):
		for p in road:
			var i0 := int((p.x - reach + HALF) / STEP)
			var j0 := int((p.y - reach + HALF) / STEP)
			var span := int(reach * 2.0 / STEP) + 1
			for j in range(maxi(j0, 0), mini(j0 + span, N)):
				for i in range(maxi(i0, 0), mini(i0 + span, N)):
					var d := Vector2(-HALF + i * STEP - p.x, -HALF + j * STEP - p.y).length()
					if d < grid[j * N + i]:
						grid[j * N + i] = d
	return grid

static func _flatten_roads(zone: int, grid: PackedFloat32Array, roads: Array) -> void:
	var wy := water_y(zone)
	for road in roads:
		var pts: PackedVector2Array = road
		# altura da estrada = relevo suavizado ao longo do caminho (sem degraus), acima d'água
		var hs := PackedFloat32Array()
		for p in pts:
			hs.append(base_height(zone, p.x, p.y))
		var smooth := PackedFloat32Array()
		smooth.resize(hs.size())
		for k in range(hs.size()):
			var s := 0.0
			var c := 0
			for o in range(-6, 7):
				var q := clampi(k + o, 0, hs.size() - 1)
				s += hs[q]
				c += 1
			smooth[k] = maxf(s / c, wy + 0.45)
		for k in range(pts.size()):
			var p := pts[k]
			if is_water(zone, p.x, p.y, 1.0):
				continue # na ponte o leito do rio fica intacto
			var i0 := int((p.x - 8.0 + HALF) / STEP)
			var j0 := int((p.y - 8.0 + HALF) / STEP)
			for j in range(maxi(j0, 0), mini(j0 + 5, N)):
				for i in range(maxi(i0, 0), mini(i0 + 5, N)):
					var vx := -HALF + i * STEP
					var vz := -HALF + j * STEP
					var d := Vector2(vx - p.x, vz - p.y).length()
					if d > 8.0 or is_water(zone, vx, vz):
						continue
					var w := smoothstep(8.0, ROAD_HALF_WIDTH + 0.6, d)
					grid[j * N + i] = lerpf(grid[j * N + i], smooth[k], w)
