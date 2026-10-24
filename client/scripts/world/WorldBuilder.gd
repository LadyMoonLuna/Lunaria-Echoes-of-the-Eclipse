extends RefCounted
## Monta a paisagem viva de uma zona aberta: terreno com colisão, Rio Prateado sinuoso, lagos,
## brejo, estradas de terra/pedra com pontes, vegetação por bioma (MultiMesh), rochas, cavernas
## nas montanhas e a vida aquática (peixes, piranhas, tartarugas, rãs, caranguejos, garças,
## libélulas, vitórias-régias e juncos).

const Terrain = preload("res://scripts/world/Terrain.gd")
const LunariaTextures = preload("res://scripts/models/LunariaTextures.gd")
const FaunaData = preload("res://scripts/world/FaunaData.gd")

const VEG_LIMIT := 2600
const GRASS_LIMIT := 2400

## Constrói tudo e devolve o nó raiz da paisagem.
static func build(zone: int, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "LivingLandscape"
	parent.add_child(root)
	if not Terrain.is_open_zone(zone):
		return root
	Terrain.prepare(zone)
	_build_terrain(zone, root)
	_build_water(zone, root)
	_build_roads(zone, root)
	_build_vegetation(zone, root)
	_build_caves(zone, root)
	_build_river_life(zone, root)
	_build_fauna_ponds(zone, root)
	_build_volcano_glow(zone, root)
	return root

static func _build_volcano_glow(zone: int, root: Node3D) -> void:
	var b := Terrain.biome(zone)
	if not b.has("volcano"):
		return
	var v: Array = b["volcano"]
	var top := Terrain.height(zone, float(v[0]), float(v[1]))
	var lava := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 9.0
	cm.height = 0.4
	lava.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#ff5a1a")
	m.emission_enabled = true
	m.emission = Color("#ff4a10")
	m.emission_energy_multiplier = 3.5
	lava.material_override = m
	lava.position = Vector3(float(v[0]), top + 0.5, float(v[1]))
	root.add_child(lava)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ff6a2a")
	glow.light_energy = 6.0
	glow.omni_range = 45.0
	glow.position = lava.position + Vector3(0, 6, 0)
	root.add_child(glow)
	var pulse := lava.create_tween().set_loops()
	pulse.tween_property(m, "emission_energy_multiplier", 5.0, 1.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(m, "emission_energy_multiplier", 2.5, 1.6).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------------------
# Terreno
# ---------------------------------------------------------------------------

static func _build_terrain(zone: int, root: Node3D) -> void:
	var b := Terrain.biome(zone)
	var grid := Terrain.grid_for(zone)
	var N := Terrain.N
	var step := Terrain.STEP
	var half := Terrain.HALF
	var low: Color = b["ground"][0]
	var mid: Color = b["ground"][1]
	var high: Color = b["ground"][2]
	var snow_line: float = b["snow"]
	var detail := Terrain._noise(zone, "veg")

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(N):
		for i in range(N):
			var x := -half + i * step
			var z := -half + j * step
			var h := grid[j * N + i]
			var hx := grid[j * N + mini(i + 1, N - 1)] - grid[j * N + maxi(i - 1, 0)]
			var hz := grid[mini(j + 1, N - 1) * N + i] - grid[maxi(j - 1, 0) * N + i]
			var normal := Vector3(-hx, 2.0 * step, -hz).normalized()
			var slope := 1.0 - normal.y
			var t := clampf(h / 30.0, 0.0, 1.0)
			var col := low.lerp(mid, clampf(detail.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)).lerp(high, t * 0.6)
			col = col.lerp(high, smoothstep(0.08, 0.35, slope)) # encostas de rocha
			if h > snow_line:
				col = col.lerp(Color("#f4f8fb"), smoothstep(snow_line, snow_line + 8.0, h))
			if h < -0.3:
				col = col.lerp(Color("#5a4a36"), 0.55) # leito e margens de lama
			st.set_color(col)
			st.set_normal(normal)
			st.set_uv(Vector2(x, z) / 6.0)
			st.add_vertex(Vector3(x, h, z))
	for j in range(N - 1):
		for i in range(N - 1):
			var a := j * N + i
			var c := a + N
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(c)
			st.add_index(a + 1)
			st.add_index(c + 1)
			st.add_index(c)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	LunariaTextures.apply(mat, "ground", 4.0, true)
	mi.material_override = mat
	root.add_child(mi)

	# Colisão: HeightMapShape3D (1 unidade entre amostras -> escala STEP)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	shape.map_data = grid
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	body.add_child(cs)
	root.add_child(body)

# ---------------------------------------------------------------------------
# Água
# ---------------------------------------------------------------------------

static func _water_material(zone: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var col := Color(0.22, 0.45, 0.55, 0.78)
	match zone:
		14:
			col = Color(0.55, 0.78, 0.9, 0.82) # degelo
		16:
			col = Color(0.25, 0.32, 0.18, 0.86) # água parada do brejo
		11, 12:
			col = Color(0.3, 0.55, 0.5, 0.8)
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _build_water(zone: int, root: Node3D) -> void:
	var wmat := _water_material(zone)
	var wy := Terrain.water_y(zone)
	# Rio: faixa que acompanha as curvas
	if Terrain.has_river(zone):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var have := false
		var z := -Terrain.HALF
		while z <= Terrain.HALF:
			var rv := Terrain.river_at(zone, z)
			if rv.is_empty():
				have = false
				z += 3.0
				continue
			var cx: float = rv[0]
			var w: float = float(rv[1]) * 0.62
			var l := Vector3(cx - w, wy, z)
			var r := Vector3(cx + w, wy, z)
			if have:
				for v in [prev_l, prev_r, l, prev_r, r, l]:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
			prev_l = l
			prev_r = r
			have = true
			z += 3.0
		var river := MeshInstance3D.new()
		river.name = "RioPrateado"
		river.mesh = st.commit()
		river.material_override = wmat
		root.add_child(river)
	# Lagos
	for l in Terrain.lakes(zone):
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = float(l[2]) * 1.08
		cyl.bottom_radius = float(l[2]) * 1.08
		cyl.height = 0.05
		cyl.radial_segments = 40
		disc.mesh = cyl
		disc.material_override = wmat
		disc.position = Vector3(float(l[0]), wy, float(l[1]))
		root.add_child(disc)
	# Brejo: lâmina d'água em toda a zona (as poças são onde o chão afunda)
	if Terrain.biome(zone).get("marsh", false):
		var plane := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(600, 600)
		plane.mesh = pm
		plane.material_override = wmat
		plane.position = Vector3(0, wy, 0)
		root.add_child(plane)

# ---------------------------------------------------------------------------
# Estradas e pontes
# ---------------------------------------------------------------------------

static func _build_roads(zone: int, root: Node3D) -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color("#8a7458") if zone != 0 else Color("#9a9184")
	road_mat.roughness = 0.95
	LunariaTextures.apply(road_mat, "cobblestone" if zone == 0 else "ground", 2.4, true)
	var hw := Terrain.ROAD_HALF_WIDTH
	for road in Terrain.roads_for(zone):
		var pts: PackedVector2Array = road
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var bridge_from := -1
		for k in range(pts.size()):
			var p := pts[k]
			var on_water := Terrain.is_water(zone, p.x, p.y, 0.5)
			if on_water and bridge_from < 0:
				bridge_from = maxi(k - 1, 0)
			elif not on_water and bridge_from >= 0:
				_build_bridge(zone, root, pts[bridge_from], p)
				bridge_from = -1
			if k == pts.size() - 1:
				break
			var q := pts[k + 1]
			if on_water or Terrain.is_water(zone, q.x, q.y, 0.5):
				continue
			var dir := (q - p).normalized()
			var nrm := Vector2(-dir.y, dir.x) * hw
			var a := Vector3(p.x + nrm.x, Terrain.height(zone, p.x + nrm.x, p.y + nrm.y) + 0.07, p.y + nrm.y)
			var b2 := Vector3(p.x - nrm.x, Terrain.height(zone, p.x - nrm.x, p.y - nrm.y) + 0.07, p.y - nrm.y)
			var c := Vector3(q.x + nrm.x, Terrain.height(zone, q.x + nrm.x, q.y + nrm.y) + 0.07, q.y + nrm.y)
			var d := Vector3(q.x - nrm.x, Terrain.height(zone, q.x - nrm.x, q.y - nrm.y) + 0.07, q.y - nrm.y)
			for v in [a, b2, c, b2, d, c]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		var mi := MeshInstance3D.new()
		mi.name = "Estrada"
		mi.mesh = st.commit()
		mi.material_override = road_mat
		root.add_child(mi)

static func _build_bridge(zone: int, root: Node3D, from: Vector2, to: Vector2) -> void:
	var dir := to - from
	var length := dir.length() + 8.0
	var mid := (from + to) * 0.5
	var y := maxf(Terrain.height(zone, from.x, from.y), Terrain.height(zone, to.x, to.y)) + 0.35
	var bridge := StaticBody3D.new()
	bridge.name = "Ponte"
	bridge.position = Vector3(mid.x, y, mid.y)
	bridge.rotation.y = atan2(dir.x, dir.y)
	root.add_child(bridge)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#7a5a3a")
	LunariaTextures.apply(wood, "planks", 1.2)
	var deck := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.6, 0.35, length)
	deck.mesh = bm
	deck.material_override = wood
	bridge.add_child(deck)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bm.size
	cs.shape = box
	bridge.add_child(cs)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.18, 0.9, length)
		rail.mesh = rm
		rail.material_override = wood
		rail.position = Vector3(side * 2.7, 0.6, 0)
		bridge.add_child(rail)
		for k in range(4):
			var post := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.18
			pm.bottom_radius = 0.22
			pm.height = 3.2
			post.mesh = pm
			post.material_override = wood
			post.position = Vector3(side * 2.7, -1.2, -length * 0.5 + 2.0 + k * (length - 4.0) / 3.0)
			bridge.add_child(post)

# ---------------------------------------------------------------------------
# Vegetação e rochas (MultiMesh)
# ---------------------------------------------------------------------------

## Malhas de cada espécie: lista de [malha, cor]. As peças são combinadas e tingidas por bioma.
static func _species_parts(kind: String, grass_col: Color) -> Array:
	var trunk := Color("#5b4330")
	match kind:
		"oak":
			return [[_cyl(0.3, 0.42, 3.4, Vector3(0, 1.7, 0)), trunk],
				[_sphere(2.3, Vector3(0, 4.6, 0), Vector3(1.1, 0.85, 1.1)), Color("#3f7a34")],
				[_sphere(1.6, Vector3(1.0, 4.0, 0.6), Vector3.ONE), Color("#4a8a3a")]]
		"pine":
			return [[_cyl(0.22, 0.32, 2.6, Vector3(0, 1.3, 0)), trunk],
				[_cone(2.0, 3.0, Vector3(0, 3.2, 0)), Color("#2d5a34")],
				[_cone(1.5, 2.6, Vector3(0, 4.8, 0)), Color("#2f6237")],
				[_cone(0.9, 2.0, Vector3(0, 6.2, 0)), Color("#336b3b")]]
		"snowpine":
			return [[_cyl(0.22, 0.32, 2.6, Vector3(0, 1.3, 0)), trunk],
				[_cone(2.0, 3.0, Vector3(0, 3.2, 0)), Color("#3c6248")],
				[_cone(1.4, 2.5, Vector3(0, 4.8, 0)), Color("#e8f0f4")],
				[_cone(0.8, 1.8, Vector3(0, 6.1, 0)), Color("#ffffff")]]
		"birch":
			return [[_cyl(0.16, 0.2, 4.6, Vector3(0, 2.3, 0)), Color("#e8e4dc")],
				[_sphere(1.4, Vector3(0, 5.0, 0), Vector3(0.9, 1.4, 0.9)), Color("#7fae4a")]]
		"acacia":
			return [[_cyl(0.2, 0.3, 4.2, Vector3(0, 2.1, 0)), trunk],
				[_sphere(3.4, Vector3(0, 4.6, 0), Vector3(1.0, 0.22, 1.0)), Color("#6c8a32")]]
		"dead":
			return [[_cyl(0.18, 0.3, 4.0, Vector3(0, 2.0, 0)), Color("#5c534a")],
				[_cyl(0.06, 0.1, 1.8, Vector3(0.5, 3.0, 0), Vector3(0, 0, -45)), Color("#5c534a")],
				[_cyl(0.06, 0.1, 1.5, Vector3(-0.4, 3.4, 0.2), Vector3(20, 0, 40)), Color("#5c534a")]]
		"willow":
			return [[_cyl(0.3, 0.45, 2.8, Vector3(0, 1.4, 0)), Color("#4a3e2e")],
				[_sphere(2.4, Vector3(0, 3.6, 0), Vector3(1.0, 1.25, 1.0)), Color("#5e7a3a")]]
		"cactus":
			return [[_capsule(0.38, 3.2, Vector3(0, 1.6, 0)), Color("#4f8a46")],
				[_capsule(0.24, 1.3, Vector3(0.55, 1.9, 0), Vector3(0, 0, -30)), Color("#4f8a46")],
				[_capsule(0.22, 1.1, Vector3(-0.5, 2.2, 0), Vector3(0, 0, 25)), Color("#4f8a46")]]
		"bush":
			return [[_sphere(0.9, Vector3(0, 0.6, 0), Vector3(1.2, 0.8, 1.1)), grass_col.darkened(0.25)],
				[_sphere(0.6, Vector3(0.6, 0.45, 0.3), Vector3.ONE), grass_col.darkened(0.15)]]
		"mushroom":
			return [[_cyl(0.18, 0.25, 1.2, Vector3(0, 0.6, 0)), Color("#e8dcc8")],
				[_sphere(0.8, Vector3(0, 1.25, 0), Vector3(1.0, 0.45, 1.0)), Color("#b0463e")]]
		"reed":
			return [[_cyl(0.03, 0.05, 1.6, Vector3(0, 0.8, 0)), Color("#7a8a3a")],
				[_cyl(0.03, 0.05, 1.3, Vector3(0.2, 0.65, 0.1), Vector3(0, 0, -8)), Color("#6f7e34")],
				[_capsule(0.06, 0.35, Vector3(0, 1.6, 0)), Color("#6b4a2a")]]
		"termite":
			return [[_cone(0.9, 2.6, Vector3(0, 1.3, 0)), Color("#9c6c42")]]
		"basalt":
			return [[_hexcol(0.6, 2.4, Vector3(0, 1.2, 0)), Color("#3c3a3b")],
				[_hexcol(0.55, 1.6, Vector3(1.0, 0.8, 0.2)), Color("#454244")],
				[_hexcol(0.5, 3.0, Vector3(-0.8, 1.5, 0.5)), Color("#363435")]]
		"crystal":
			return [[_hexcol(0.35, 2.4, Vector3(0, 1.0, 0), Vector3(0, 0, 12)), Color("#9ad8ff")],
				[_hexcol(0.25, 1.6, Vector3(0.5, 0.7, 0.2), Vector3(0, 0, -20)), Color("#b9a4ff")]]
		"rock":
			return [[_rock(1.0, Vector3(0, 0.3, 0)), Color("#7d7a74")]]
	return [[_sphere(1.0, Vector3(0, 0.5, 0), Vector3.ONE), grass_col]]

static func _xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos)

static func _cyl(top: float, bottom: float, h: float, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Array:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 7
	m.rings = 1
	return [m, _xf(pos, rot)]

static func _cone(r: float, h: float, pos: Vector3) -> Array:
	return _cyl(0.0, r, h, pos)

static func _hexcol(r: float, h: float, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Array:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 6
	m.rings = 1
	return [m, _xf(pos, rot)]

static func _sphere(r: float, pos: Vector3, scl: Vector3) -> Array:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 9
	m.rings = 5
	return [m, Transform3D(Basis.from_scale(scl), pos)]

static func _capsule(r: float, h: float, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Array:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 7
	m.rings = 2
	return [m, _xf(pos, rot)]

static func _rock(r: float, pos: Vector3) -> Array:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 1.4
	m.radial_segments = 6
	m.rings = 3
	return [m, Transform3D(Basis.from_scale(Vector3(1.3, 0.8, 1.0)), pos)]

## Junta as peças de uma espécie numa malha só (uma superfície por peça, cada uma com sua cor).
static func _species_mesh(kind: String, grass_col: Color) -> ArrayMesh:
	var out := ArrayMesh.new()
	for part in _species_parts(kind, grass_col):
		var geo: Array = part[0]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(geo[0], 0, geo[1])
		st.generate_normals()
		st.commit(out)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[1]
		mat.roughness = 0.9
		if kind == "crystal":
			mat.emission_enabled = true
			mat.emission = (part[1] as Color) * 0.6
			mat.emission_energy_multiplier = 1.4
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out

static func _build_vegetation(zone: int, root: Node3D) -> void:
	var b := Terrain.biome(zone)
	var spacing: float = b["spacing"]
	var glade: float = b["glade"]
	var grass_col: Color = b["grass_col"]
	var table: Array = b["veg"]
	var total_w := 0
	for e in table:
		total_w += int(e[1])
	var vegn := Terrain._noise(zone, "veg")
	var rng := RandomNumberGenerator.new()
	rng.seed = zone * 4513 + 17
	var placements := {} # kind -> Array[Transform3D]
	var count := 0
	var portals := Terrain.portals_of(zone)
	var z := -Terrain.HALF + 4.0
	# Se a densidade passar do limite, sorteia por toda a zona (não só a primeira metade)
	var expected := pow(600.0 / spacing, 2) * (1.0 - glade) * 0.9
	var keep_chance := minf(1.0, float(VEG_LIMIT) / maxf(expected, 1.0))
	while z < Terrain.HALF - 4.0 and count < VEG_LIMIT:
		var x := -Terrain.HALF + 4.0
		while x < Terrain.HALF - 4.0 and count < VEG_LIMIT:
			var px := x + rng.randf_range(-spacing * 0.45, spacing * 0.45)
			var pz := z + rng.randf_range(-spacing * 0.45, spacing * 0.45)
			x += spacing
			if rng.randf() > keep_chance:
				continue
			if (vegn.get_noise_2d(px, pz) * 0.5 + 0.5) < glade:
				continue # clareira
			if not _free_spot(zone, px, pz, portals, 7.0):
				continue
			var kind := _pick(table, total_w, rng)
			var h := Terrain.height(zone, px, pz)
			if Terrain.is_water(zone, px, pz, 3.0):
				if kind != "reed" and not b.get("marsh", false):
					continue
				kind = "reed"
			if h > float(b["snow"]) and kind in ["pine", "oak", "birch"]:
				kind = "snowpine"
			var s := rng.randf_range(0.75, 1.35)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)), Vector3(px, h - 0.15, pz))
			if not placements.has(kind):
				placements[kind] = []
			placements[kind].append(xf)
			count += 1
		z += spacing
	# Vegetação ao redor do oásis (palmeiras = acácias altas) e juncos nas margens do rio
	if b.has("oasis"):
		var o: Array = b["oasis"]
		for k in range(14):
			var ang := TAU * k / 14.0
			var rr := 30.0 + rng.randf() * 6.0
			var ox := float(o[0]) + cos(ang) * rr
			var oz := float(o[1]) + sin(ang) * rr
			if not placements.has("acacia"):
				placements["acacia"] = []
			placements["acacia"].append(Transform3D(Basis.from_scale(Vector3(0.9, 1.6, 0.9)), Vector3(ox, Terrain.height(zone, ox, oz) - 0.1, oz)))
	if Terrain.has_river(zone) and zone != 14:
		var rz := -Terrain.HALF
		while rz < Terrain.HALF:
			var rv := Terrain.river_at(zone, rz)
			if not rv.is_empty():
				for side in [-1.0, 1.0]:
					if rng.randf() < 0.55:
						var bx: float = float(rv[0]) + side * (float(rv[1]) * 0.5 + rng.randf_range(0.0, 2.5))
						if _free_spot(zone, bx, rz, portals, 4.0):
							if not placements.has("reed"):
								placements["reed"] = []
							placements["reed"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(bx, Terrain.height(zone, bx, rz) - 0.1, rz)))
			rz += 5.0
	for kind in placements:
		_add_multimesh(root, _species_mesh(kind, grass_col), placements[kind], "Veg_%s" % kind)
	_build_vegetation_colliders(root, placements)
	_build_grass(zone, root, rng, portals)

## Raio do tronco (m, antes da escala) das espécies sólidas; arbustos, juncos, cogumelos e pedrinhas
## ficam sem colisão para o jogador passar por cima ou por dentro.
const SOLID_TRUNKS := {
	"oak": 0.42, "pine": 0.32, "snowpine": 0.32, "birch": 0.22, "acacia": 0.3, "dead": 0.3,
	"willow": 0.45, "cactus": 0.4, "termite": 0.8, "basalt": 0.9, "crystal": 0.4,
}

## Um único corpo estático com um cilindro por tronco (barato para a física e cobre a zona inteira).
static func _build_vegetation_colliders(root: Node3D, placements: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "VegColliders"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for kind in placements:
		if not SOLID_TRUNKS.has(kind):
			continue
		var r: float = SOLID_TRUNKS[kind]
		for xf in placements[kind]:
			var t: Transform3D = xf
			var sc: Vector3 = t.basis.get_scale()
			var cyl := CylinderShape3D.new()
			cyl.radius = r * sc.x
			cyl.height = 3.0 * sc.y
			var cs := CollisionShape3D.new()
			cs.shape = cyl
			cs.position = t.origin + Vector3(0, cyl.height * 0.5, 0)
			body.add_child(cs)

static func _free_spot(zone: int, x: float, z: float, portals: Array, road_gap: float) -> bool:
	if Vector2(x, z).length() < 30.0:
		return false # praça central (pontos de chegada e marcos)
	if zone == 0 and maxf(absf(x), absf(z)) < 98.0:
		return false # dentro e rente à muralha da Vila
	for p in portals:
		if Vector2(x - float(p["x"]), z - float(p["z"])).length() < 26.0:
			return false
	if Terrain.road_distance(zone, x, z) < road_gap:
		return false
	return true

static func _pick(table: Array, total_w: int, rng: RandomNumberGenerator) -> String:
	var r := rng.randi_range(0, total_w - 1)
	for e in table:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return table[0][0]

## Divide a vegetação em blocos de 80 m, cada um com o nó no centro do bloco. A distância de
## visibilidade é medida por bloco: um único MultiMesh da zona inteira (nó na origem) sumia por
## completo quando a câmera passava de 260 m do centro do mapa — as árvores "paravam de carregar".
const VEG_CHUNK := 80.0

static func _add_multimesh(root: Node3D, mesh: Mesh, xfs: Array, node_name: String) -> void:
	if xfs.is_empty():
		return
	var buckets := {}
	for xf in xfs:
		var t: Transform3D = xf
		var key := Vector2i(floori(t.origin.x / VEG_CHUNK), floori(t.origin.z / VEG_CHUNK))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(t)
	for key in buckets:
		var list: Array = buckets[key]
		var center := Vector3((key.x + 0.5) * VEG_CHUNK, 0.0, (key.y + 0.5) * VEG_CHUNK)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for k in range(list.size()):
			var t2: Transform3D = list[k]
			t2.origin -= center
			mm.set_instance_transform(k, t2)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [node_name, key.x, key.y]
		mmi.multimesh = mm
		mmi.position = center
		mmi.visibility_range_end = 260.0
		root.add_child(mmi)

static func _build_grass(zone: int, root: Node3D, rng: RandomNumberGenerator, portals: Array) -> void:
	var b := Terrain.biome(zone)
	var chance: float = b["grass"]
	if chance <= 0.0:
		return
	var tuft := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(4):
		var blade := CylinderMesh.new()
		blade.top_radius = 0.0
		blade.bottom_radius = 0.07
		blade.height = 0.7
		blade.radial_segments = 3
		blade.rings = 1
		var ang := TAU * k / 4.0
		st.append_from(blade, 0, Transform3D(Basis.from_euler(Vector3(0.25 * cos(ang), 0, 0.25 * sin(ang))), Vector3(cos(ang) * 0.12, 0.3, sin(ang) * 0.12)))
	st.generate_normals()
	st.commit(tuft)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = b["grass_col"]
	gm.roughness = 1.0
	tuft.surface_set_material(0, gm)
	var xfs: Array = []
	var tries := 0
	while xfs.size() < GRASS_LIMIT and tries < GRASS_LIMIT * 3:
		tries += 1
		if rng.randf() > chance:
			continue
		var x := rng.randf_range(-290.0, 290.0)
		var z := rng.randf_range(-290.0, 290.0)
		if Terrain.is_water(zone, x, z, 0.5) or (zone == 0 and maxf(absf(x), absf(z)) < 92.0):
			continue
		var h := Terrain.height(zone, x, z)
		if h > float(b["snow"]):
			continue
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)), Vector3(x, h - 0.05, z)))
	_add_multimesh(root, tuft, xfs, "Capim")

# ---------------------------------------------------------------------------
# Cavernas nas encostas das montanhas
# ---------------------------------------------------------------------------

static func _build_caves(zone: int, root: Node3D) -> void:
	var want: int = Terrain.biome(zone).get("caves", 0)
	if want <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = zone * 991 + 3
	var placed: Array = []
	var tries := 0
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color("#6d6a66") if zone != 14 else Color("#b8c4cc")
	LunariaTextures.apply(rock, "stone", 1.5)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.03)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	while placed.size() < want and tries < 400:
		tries += 1
		var x := rng.randf_range(-250.0, 250.0)
		var z := rng.randf_range(-250.0, 250.0)
		var h := Terrain.height(zone, x, z)
		var gx := Terrain.height(zone, x + 3.0, z) - Terrain.height(zone, x - 3.0, z)
		var gz := Terrain.height(zone, x, z + 3.0) - Terrain.height(zone, x, z - 3.0)
		var slope := Vector2(gx, gz).length() / 6.0
		if slope < 0.45 or h < 8.0 or Terrain.road_distance(zone, x, z) < 25.0:
			continue
		var too_close := false
		for q in placed:
			if q.distance_to(Vector2(x, z)) < 90.0:
				too_close = true
		if too_close:
			continue
		placed.append(Vector2(x, z))
		var cave := Node3D.new()
		cave.name = "Caverna"
		cave.position = Vector3(x, h - 0.6, z)
		cave.rotation.y = atan2(-gx, -gz) # a boca olha encosta abaixo
		root.add_child(cave)
		var mouth := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.6
		sm.height = 5.2
		mouth.mesh = sm
		mouth.material_override = dark
		mouth.scale = Vector3(1.2, 1.0, 0.45)
		mouth.position = Vector3(0, 1.8, 0)
		cave.add_child(mouth)
		var arch := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.8
		tm.outer_radius = 4.2
		arch.mesh = tm
		arch.material_override = rock
		arch.rotation_degrees = Vector3(90, 0, 0)
		arch.position = Vector3(0, 1.8, 0.3)
		arch.scale = Vector3(1.15, 1.0, 1.0)
		cave.add_child(arch)
		var lbl := Label3D.new()
		lbl.text = "🕳️ Caverna"
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 22
		lbl.outline_size = 6
		lbl.modulate = Color(0.85, 0.85, 0.9, 0.85)
		lbl.position = Vector3(0, 6.0, 0)
		lbl.visibility_range_end = 70.0
		cave.add_child(lbl)

# ---------------------------------------------------------------------------
# Vida aquática (só visual): peixes, piranhas, tartarugas, rãs, caranguejos, garças, libélulas
# ---------------------------------------------------------------------------

static func _creature_mat(col: Color, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.5
	if emissive:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.2
	return m

## Pontos de água para a fauna: [x, z, direção_do_fluxo (rad), largura]
static func _water_spots(zone: int, rng: RandomNumberGenerator, n: int) -> Array:
	var spots: Array = []
	var lks := Terrain.lakes(zone)
	var tries := 0
	while spots.size() < n and tries < n * 20:
		tries += 1
		if Terrain.has_river(zone) and (lks.is_empty() or rng.randf() < 0.7):
			var z := rng.randf_range(-280.0, 280.0)
			var rv := Terrain.river_at(zone, z)
			if rv.is_empty():
				continue
			var x: float = float(rv[0]) + rng.randf_range(-0.25, 0.25) * float(rv[1])
			var ahead := Terrain.river_at(zone, z - 4.0)
			var dirx: float = (float(ahead[0]) - float(rv[0])) if not ahead.is_empty() else 0.0
			spots.append([x, z, atan2(dirx, -4.0), float(rv[1])])
		elif not lks.is_empty():
			var l: Array = lks[rng.randi_range(0, lks.size() - 1)]
			var ang := rng.randf() * TAU
			var rr := rng.randf() * float(l[2]) * 0.7
			spots.append([float(l[0]) + cos(ang) * rr, float(l[1]) + sin(ang) * rr, rng.randf() * TAU, float(l[2])])
		elif Terrain.biome(zone).get("marsh", false):
			var x2 := rng.randf_range(-250.0, 250.0)
			var z2 := rng.randf_range(-250.0, 250.0)
			if Terrain.is_water(zone, x2, z2):
				spots.append([x2, z2, rng.randf() * TAU, 6.0])
	return spots

## Lagoas da fauna nas regiões sem rio (mesmas de server/internal/world/fauna.go FaunaPonds).
static func _build_fauna_ponds(zone: int, root: Node3D) -> void:
	var ponds: Array = FaunaData.PONDS.get(zone, [])
	if ponds.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "LagoasDaFauna"
	root.add_child(holder)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.18, 0.38, 0.48, 0.82)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic = 0.3
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.28, 0.22, 0.15)
	for p in ponds:
		var px: float = p[0]
		var pz: float = p[1]
		var pr: float = p[2]
		var gy: float = Terrain.height(zone, px, pz)
		var bank := MeshInstance3D.new()
		var bank_mesh := CylinderMesh.new()
		bank_mesh.top_radius = pr + 1.5
		bank_mesh.bottom_radius = pr + 2.0
		bank_mesh.height = 0.3
		bank_mesh.radial_segments = 32
		bank.mesh = bank_mesh
		bank.material_override = mud
		bank.position = Vector3(px, gy - 0.05, pz)
		holder.add_child(bank)
		var surf := MeshInstance3D.new()
		var surf_mesh := CylinderMesh.new()
		surf_mesh.top_radius = pr
		surf_mesh.bottom_radius = pr
		surf_mesh.height = 0.05
		surf_mesh.radial_segments = 32
		surf.mesh = surf_mesh
		surf.material_override = water
		surf.position = Vector3(px, gy + 0.2, pz)
		holder.add_child(surf)

static func _build_river_life(zone: int, root: Node3D) -> void:
	var has_water: bool = Terrain.has_river(zone) or not Terrain.lakes(zone).is_empty() or bool(Terrain.biome(zone).get("marsh", false))
	if not has_water:
		return
	var life := Node3D.new()
	life.name = "VidaAquatica"
	root.add_child(life)
	var rng := RandomNumberGenerator.new()
	rng.seed = zone * 6007 + 11
	var wy := Terrain.water_y(zone)
	var warm: bool = zone in [10, 11, 12, 16]
	var cold: bool = zone in [2, 13, 14]
	# Peixes, tartarugas, garças e caranguejos agora são criaturas de verdade no servidor (FaunaData):
	# têm vida e deixam corpo. Aqui ficam só plantas d'água e insetos de enfeite.
	# Rãs e vitórias-régias (lagos e brejo), garças nas águas rasas, caranguejos de rio
	for spot in _water_spots(zone, rng, 6 if zone == 16 else 3):
		_lily_and_frog(life, spot, wy, rng)
	if warm or zone in [0, 1, 9]:
		for spot in _water_spots(zone, rng, 5):
			_dragonfly(life, spot, wy, rng)

static func _fish_school(parent: Node3D, spot: Array, wy: float, col: Color, n: int, size: float, rng: RandomNumberGenerator, piranha: bool = false) -> void:
	var school := Node3D.new()
	school.name = "Piranhas" if piranha else "Cardume"
	school.position = Vector3(spot[0], wy - 0.35, spot[1])
	school.rotation.y = spot[2]
	parent.add_child(school)
	var body_mat := _creature_mat(col)
	var belly_mat := _creature_mat(Color("#ff7043") if piranha else col.lightened(0.3))
	for k in range(n):
		var fish := Node3D.new()
		fish.position = Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.2, 0.15), rng.randf_range(-1.5, 1.5))
		school.add_child(fish)
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = size * 0.35
		cm.height = size * 1.6
		cm.radial_segments = 6
		cm.rings = 2
		body.mesh = cm
		body.material_override = body_mat
		body.rotation_degrees = Vector3(90, 0, 0)
		fish.add_child(body)
		var belly := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = size * 0.28
		bs.height = size * 0.5
		belly.mesh = bs
		belly.material_override = belly_mat
		belly.position = Vector3(0, -size * 0.12, 0)
		fish.add_child(belly)
		var tail := MeshInstance3D.new()
		var tm := PrismMesh.new()
		tm.size = Vector3(size * 0.5, size * 0.5, 0.02)
		tail.mesh = tm
		tail.material_override = body_mat
		tail.position = Vector3(0, 0, size * 0.9)
		tail.rotation_degrees = Vector3(90, 90, 0)
		fish.add_child(tail)
	# Nadam rio acima e abaixo, em vaivém
	var span: float = minf(10.0, float(spot[3]) * 0.8 + 3.0)
	var tw := school.create_tween().set_loops()
	var dur := rng.randf_range(4.0, 7.0)
	tw.tween_property(school, "position:z", school.position.z + span, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(school, "rotation:y", school.rotation.y + PI, 0.6)
	tw.tween_property(school, "position:z", school.position.z, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(school, "rotation:y", school.rotation.y, 0.6)

static func _bank_point(zone: int, spot: Array, rng: RandomNumberGenerator) -> Vector3:
	var x: float = spot[0]
	var z: float = spot[1]
	var rv := Terrain.river_at(zone, z)
	if not rv.is_empty():
		x = float(rv[0]) + (1.0 if rng.randf() < 0.5 else -1.0) * (float(rv[1]) * 0.5 + 0.8)
	return Vector3(x, Terrain.height(zone, x, z), z)

static func _turtle(parent: Node3D, zone: int, spot: Array, rng: RandomNumberGenerator) -> void:
	var p := _bank_point(zone, spot, rng)
	var t := Node3D.new()
	t.name = "Tartaruga"
	t.position = p
	t.rotation.y = rng.randf() * TAU
	parent.add_child(t)
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.5
	shell.mesh = sm
	shell.material_override = _creature_mat(Color("#4e5b3a"))
	shell.position = Vector3(0, 0.2, 0)
	shell.scale = Vector3(1.0, 0.7, 1.25)
	t.add_child(shell)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.12
	hm.height = 0.24
	head.mesh = hm
	head.material_override = _creature_mat(Color("#7d8a54"))
	head.position = Vector3(0, 0.18, -0.6)
	t.add_child(head)
	for k in range(4):
		var leg := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.1
		lm.height = 0.2
		leg.mesh = lm
		leg.material_override = head.material_override
		leg.position = Vector3(0.32 * (1 if k % 2 == 0 else -1), 0.06, 0.32 * (1 if k < 2 else -1))
		t.add_child(leg)
	var tw := head.create_tween().set_loops()
	tw.tween_property(head, "position:z", -0.68, 2.5)
	tw.tween_property(head, "position:z", -0.55, 2.5)

static func _lily_and_frog(parent: Node3D, spot: Array, wy: float, rng: RandomNumberGenerator) -> void:
	var g := Node3D.new()
	g.name = "VitoriaRegia"
	g.position = Vector3(spot[0], wy + 0.03, spot[1])
	parent.add_child(g)
	var pad_mat := _creature_mat(Color("#3f7a3a"))
	for k in range(rng.randi_range(3, 6)):
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := rng.randf_range(0.35, 0.8)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.03
		cm.radial_segments = 10
		pad.mesh = cm
		pad.material_override = pad_mat
		pad.position = Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0))
		g.add_child(pad)
		if k == 0:
			var flower := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.16
			fm.height = 0.2
			flower.mesh = fm
			flower.material_override = _creature_mat(Color("#f3a6c8"))
			flower.position = pad.position + Vector3(0.1, 0.08, 0)
			g.add_child(flower)
	var frog := MeshInstance3D.new()
	var frm := SphereMesh.new()
	frm.radius = 0.14
	frm.height = 0.18
	frog.mesh = frm
	frog.material_override = _creature_mat(Color("#6aa83a"))
	frog.position = Vector3(0, 0.1, 0)
	g.add_child(frog)
	var tw := frog.create_tween().set_loops()
	tw.tween_interval(rng.randf_range(2.0, 5.0))
	tw.tween_property(frog, "position:y", 0.45, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(frog, "position:y", 0.1, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

static func _heron(parent: Node3D, zone: int, spot: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spot[0] * 13.0 + spot[1] * 7.0)
	var p := _bank_point(zone, spot, rng)
	var h := Node3D.new()
	h.name = "Garca"
	h.position = p
	h.rotation.y = rng.randf() * TAU
	parent.add_child(h)
	var white := _creature_mat(Color("#f2f2ee"))
	var yellow := _creature_mat(Color("#e0b030"))
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.28
	bm.height = 0.6
	body.mesh = bm
	body.material_override = white
	body.position = Vector3(0, 1.0, 0)
	body.scale = Vector3(0.8, 0.9, 1.4)
	h.add_child(body)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.05
	nm.bottom_radius = 0.07
	nm.height = 0.7
	neck.mesh = nm
	neck.material_override = white
	neck.position = Vector3(0, 1.45, -0.25)
	neck.rotation_degrees = Vector3(-20, 0, 0)
	h.add_child(neck)
	var beak := MeshInstance3D.new()
	var bk := CylinderMesh.new()
	bk.top_radius = 0.0
	bk.bottom_radius = 0.04
	bk.height = 0.4
	beak.mesh = bk
	beak.material_override = yellow
	beak.position = Vector3(0, 1.8, -0.55)
	beak.rotation_degrees = Vector3(-80, 0, 0)
	h.add_child(beak)
	for side in [-0.08, 0.08]:
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.02
		lm.bottom_radius = 0.02
		lm.height = 0.9
		leg.mesh = lm
		leg.material_override = yellow
		leg.position = Vector3(side, 0.45, 0)
		h.add_child(leg)
	var tw := h.create_tween().set_loops()
	tw.tween_interval(rng.randf_range(3.0, 7.0))
	tw.tween_property(h, "rotation:y", h.rotation.y + 0.8, 1.2)
	tw.tween_interval(rng.randf_range(2.0, 5.0))
	tw.tween_property(h, "rotation:y", h.rotation.y, 1.2)

static func _crab(parent: Node3D, zone: int, spot: Array, rng: RandomNumberGenerator) -> void:
	var p := _bank_point(zone, spot, rng)
	var c := MeshInstance3D.new()
	c.name = "Caranguejo"
	var cm := SphereMesh.new()
	cm.radius = 0.16
	cm.height = 0.14
	c.mesh = cm
	c.material_override = _creature_mat(Color("#b0503a"))
	c.position = p + Vector3(0, 0.08, 0)
	c.scale = Vector3(1.4, 0.8, 1.0)
	parent.add_child(c)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "position:x", p.x + 0.8, 1.4)
	tw.tween_interval(rng.randf_range(0.5, 2.0))
	tw.tween_property(c, "position:x", p.x - 0.6, 1.6)

static func _dragonfly(parent: Node3D, spot: Array, wy: float, rng: RandomNumberGenerator) -> void:
	var d := MeshInstance3D.new()
	d.name = "Libelula"
	var cm := CapsuleMesh.new()
	cm.radius = 0.03
	cm.height = 0.3
	d.mesh = cm
	d.material_override = _creature_mat(Color("#3fd0e0"), true)
	d.position = Vector3(spot[0], wy + 0.9, spot[1])
	d.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(d)
	var tw := d.create_tween().set_loops()
	for k in range(4):
		var off := Vector3(rng.randf_range(-3, 3), rng.randf_range(-0.3, 0.6), rng.randf_range(-3, 3))
		tw.tween_property(d, "position", d.position + off, rng.randf_range(0.6, 1.4)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(d, "position", d.position, 1.0)
