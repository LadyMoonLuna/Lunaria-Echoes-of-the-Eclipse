extends Node3D
## Modelo 3D procedural de uma raça de Lunaria.
##
## Monta o personagem a partir de primitivas definidas em RaceModelData.gd
## (gerado por tools/race_models/build.py). Não precisa de importação de
## assets: funciona direto no editor e em builds exportados.
##
## Uso:
##   const RaceModel = preload("res://scripts/models/RaceModel.gd")
##   var modelo = RaceModel.create(19)   # pés na origem, olhando para -Z
##   add_child(modelo)
##   modelo.set_move_speed(velocity.length())   # balanço de caminhada

const RaceModelData = preload("res://scripts/models/RaceModelData.gd")
const SCRIPT_PATH: String = "res://scripts/models/RaceModel.gd"

const WALK_SWING_DEG: float = 32.0
const WALK_FREQ: float = 7.0
const WALK_GROUPS: Dictionary = {"leg_r": 1.0, "leg_l": -1.0, "arm_r": -0.8, "arm_l": 0.8}

static var _mesh_cache: Dictionary = {}

var race_id: int = 0
var race_name: String = ""
var _anim_groups: Array = []      # [{node, anim, base_pos}]
var _walk_groups: Array = []      # [{node, sign}]
var _anim_materials: Array = []   # [{mat, anim, energy, alpha}]
var _time: float = 0.0
var _walk_amount: float = 0.0
var _move_speed: float = 0.0


static func has_model(id: int) -> bool:
	return RaceModelData.MODELS.has(str(id))


static func get_model_ids() -> Array:
	var ids: Array = []
	for k in RaceModelData.MODELS.keys():
		ids.append(int(k))
	ids.sort()
	return ids


static func get_info(id: int) -> Dictionary:
	if not has_model(id):
		return {}
	var d: Dictionary = RaceModelData.MODELS[str(id)]
	return {"id": d["id"], "name": d["name"], "title": d["title"], "lore": d["lore"], "color": Color(d["color"])}


## Cria o modelo da raça (ou null se a raça ainda não tem modelo).
static func create(id: int, with_lights: bool = true) -> Node3D:
	if not has_model(id):
		return null
	var m: Node3D = load(SCRIPT_PATH).new()
	m._build(RaceModelData.MODELS[str(id)], with_lights)
	return m


## Velocidade horizontal do personagem (m/s) — controla o balanço de pernas e braços.
func set_move_speed(speed: float) -> void:
	_move_speed = speed


func _build(d: Dictionary, with_lights: bool) -> void:
	race_id = int(d["id"])
	race_name = d["name"]
	name = "RaceModel_%s" % d["key"]
	scale = Vector3.ONE * float(d.get("scale", 1.0))

	var mats: Dictionary = {}
	for key in d["materials"]:
		mats[key] = _make_material(d["materials"][key])

	var groups: Dictionary = {}
	var pivots: Dictionary = {}
	for g in d["groups"]:
		var node := Node3D.new()
		node.name = g["name"]
		var pivot := _vec(g["pivot"])
		var parent_name: String = g.get("parent", "")
		var parent_pivot := Vector3.ZERO
		if parent_name != "":
			parent_pivot = pivots[parent_name]
		node.position = pivot - parent_pivot
		if parent_name != "":
			groups[parent_name].add_child(node)
		else:
			add_child(node)
		groups[g["name"]] = node
		pivots[g["name"]] = pivot
		if g.has("anim"):
			_anim_groups.append({"node": node, "anim": g["anim"], "base_pos": node.position})
		if WALK_GROUPS.has(g["name"]):
			_walk_groups.append({"node": node, "sign": WALK_GROUPS[g["name"]]})

	for p in d["parts"]:
		var mi := MeshInstance3D.new()
		mi.mesh = _get_mesh(p["shape"], p["size"])
		var mat: Material = mats[p["mat"]]
		mi.material_override = mat
		var group_name: String = p.get("group", "")
		var gp := Vector3.ZERO
		if group_name != "":
			gp = pivots[group_name]
		mi.position = _vec(p["pos"]) - gp
		if p.has("rot"):
			mi.rotation_degrees = _vec(p["rot"])
		if p.has("scale"):
			mi.scale = _vec(p["scale"])
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if group_name != "":
			groups[group_name].add_child(mi)
		else:
			add_child(mi)

	if with_lights:
		for l in d["lights"]:
			var light := OmniLight3D.new()
			light.light_color = Color(l["color"])
			light.light_energy = float(l["energy"])
			light.omni_range = float(l["range"])
			light.position = _vec(l["pos"])
			light.shadow_enabled = false
			add_child(light)


func _make_material(spec: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(spec["color"])
	mat.roughness = float(spec.get("rough", 0.6))
	mat.metallic = float(spec.get("metal", 0.0))
	var energy := 0.0
	if spec.has("emit"):
		mat.emission_enabled = true
		mat.emission = Color(spec["emit"])
		energy = float(spec.get("energy", 1.0))
		mat.emission_energy_multiplier = energy
	var alpha := float(spec.get("alpha", 1.0))
	if spec.get("unshaded", false):
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(spec.get("emit", spec["color"]))
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
	if spec.get("double", false):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if spec.has("anim"):
		_anim_materials.append({"mat": mat, "anim": spec["anim"], "energy": energy, "alpha": alpha})
	return mat


static func _get_mesh(shape: String, s: Array) -> Mesh:
	var key := shape + str(s)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: Mesh
	match shape:
		"box":
			var b := BoxMesh.new()
			b.size = Vector3(s[0], s[1], s[2])
			mesh = b
		"sphere":
			var sp := SphereMesh.new()
			sp.radius = s[0]
			sp.height = s[0] * 2.0
			sp.radial_segments = 16
			sp.rings = 8
			mesh = sp
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = s[0]
			c.bottom_radius = s[1]
			c.height = s[2]
			c.radial_segments = 12
			c.rings = 1
			mesh = c
		"capsule":
			var cap := CapsuleMesh.new()
			cap.radius = s[0]
			cap.height = maxf(s[1], s[0] * 2.0 + 0.001)
			cap.radial_segments = 12
			cap.rings = 4
			mesh = cap
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = s[0]
			t.outer_radius = s[1]
			t.rings = 20
			t.ring_segments = 8
			mesh = t
		"prism":
			var pr := PrismMesh.new()
			pr.size = Vector3(s[0], s[1], s[2])
			mesh = pr
		_:
			mesh = BoxMesh.new()
	_mesh_cache[key] = mesh
	return mesh


static func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _process(delta: float) -> void:
	_time += delta
	var t := _time

	for a in _anim_groups:
		var node: Node3D = a["node"]
		var an: Dictionary = a["anim"]
		var ph := float(an.get("phase", 0.0))
		match an["type"]:
			"spin":
				var axis := _vec(an["axis"]).normalized()
				node.basis = Basis(axis, deg_to_rad(float(an["speed"]) * t))
			"sway":
				var axis2 := _vec(an["axis"]).normalized()
				node.basis = Basis(axis2, deg_to_rad(float(an["amp"])) * sin(float(an["speed"]) * t + ph))
			"bob":
				var base: Vector3 = a["base_pos"]
				node.position.y = base.y + float(an["amp"]) * sin(float(an["speed"]) * t + ph)
			"pulse":
				node.scale = Vector3.ONE * (1.0 + float(an["amp"]) * sin(float(an["speed"]) * t + ph))

	var target_walk := clampf(_move_speed / 5.0, 0.0, 1.0)
	_walk_amount = lerpf(_walk_amount, target_walk, clampf(delta * 8.0, 0.0, 1.0))
	var swing := _walk_amount * deg_to_rad(WALK_SWING_DEG) * sin(t * WALK_FREQ)
	for w in _walk_groups:
		(w["node"] as Node3D).rotation.x = swing * float(w["sign"])

	for m in _anim_materials:
		var mat: StandardMaterial3D = m["mat"]
		var an2: Dictionary = m["anim"]
		var lo := float(an2["min"])
		var hi := float(an2["max"])
		var spd := float(an2["speed"])
		match an2["type"]:
			"glow":
				mat.emission_energy_multiplier = float(m["energy"]) * lerpf(lo, hi, 0.5 + 0.5 * sin(spd * t))
			"flicker":
				var n := 0.5 + 0.5 * sin(spd * t) * sin(spd * 1.73 * t + 1.3)
				mat.albedo_color.a = float(m["alpha"]) * lerpf(lo, hi, n)
