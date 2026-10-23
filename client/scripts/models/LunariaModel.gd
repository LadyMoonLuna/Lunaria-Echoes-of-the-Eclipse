extends Node3D
## Modelo 3D procedural de Lunaria: raças, NPCs, armas, trajes e companheiros.
##
## Monta o personagem a partir de primitivas descritas em LunariaModelData.gd
## (gerado por tools/race_models/build.py). Não precisa importar assets.
##
## Uso:
##   const LunariaModel = preload("res://scripts/models/LunariaModel.gd")
##   var heroi := LunariaModel.create_race(22, 1)   # Draconato de Cinzas, Espadachim
##   add_child(heroi)                               # pés na origem, olhando para -Z
##   heroi.set_move_speed(velocity.length())        # idle / walk / run automáticos
##   heroi.play_action(1)                           # ataque básico da classe
##   heroi.play("death_fall", true)                 # cai e mantém o último quadro

const Data = preload("res://scripts/models/LunariaModelData.gd")
const LunariaTextures = preload("res://scripts/models/LunariaTextures.gd")
const LunariaStyle = preload("res://scripts/models/LunariaStyle.gd")
const SCRIPT_PATH: String = "res://scripts/models/LunariaModel.gd"
const BLEND_TIME: float = 0.15
const LIMB_CHANNELS: Array = ["torso", "arm_r", "arm_l", "leg_r", "leg_l"]
const DEFAULT_ACTIONS: Dictionary = {
	"1": "attack_1h", "2": "dodge_roll", "3": "skill_q", "4": "skill_r_shield", "5": "skill_f_spin", "6": "skill_z"
}

const HD_DIR: String = "res://assets/models/hd/"
## Nomes aceitos para as animações de um .glb HD (Mixamo/Blender), por clipe do jogo.
const HD_ANIM_NAMES: Dictionary = {
	"idle": ["Idle"], "walk": ["Walk"], "run": ["Run"], "dodge_roll": ["Dodge_Roll", "Roll"],
	"attack_1h": ["Attack_Melee_1H", "Attack"], "attack_2h_heavy": ["Attack_Melee_2H_Heavy", "Attack_2H_Heavy", "Attack"],
	"attack_2h_sweep": ["Attack_Melee_2H_Heavy", "Attack_2H_Sweep", "Attack"], "attack_bow": ["Attack_Bow_Shoot", "Attack"],
	"attack_cast": ["Attack_Cast_Throw", "Attack_Cast", "Attack"], "attack_throw": ["Attack_Cast_Throw", "Attack_Throw", "Attack"],
	"skill_q": ["Skill_Q_Strike"], "skill_q_support": ["Skill_Q_Strike", "Skill_Q_Support"],
	"skill_r_shield": ["Skill_R_Tactical"], "skill_r_sharpen": ["Skill_R_Tactical"], "skill_r_backflip": ["Skill_R_Tactical"],
	"skill_f_spin": ["Skill_F_Ultimate"], "skill_f_slam": ["Skill_F_Ultimate"], "skill_z": ["Skill_Z_Racial"],
	"kneel_autopsy": ["Interact_Autopsy_Kneel"], "death_fall": ["Death_Fall", "Death"],
	"beast_bite": ["Attack", "Bite"], "beast_death": ["Death_Fall", "Death"],
}
## Ossos das mãos/costas procurados num esqueleto HD (Mixamo, Blender Rigify, genérico).
const HD_BONES: Dictionary = {
	"hand_r": ["mixamorig_RightHand", "mixamorig:RightHand", "RightHand", "hand.R", "Hand_R", "hand_r"],
	"hand_l": ["mixamorig_LeftHand", "mixamorig:LeftHand", "LeftHand", "hand.L", "Hand_L", "hand_l"],
	"back": ["mixamorig_Spine2", "mixamorig:Spine2", "Spine2", "spine.003", "Chest", "chest"],
}

## false = ignora os .glb HD e usa sempre os modelos procedurais.
static var use_hd: bool = true
static var _mesh_cache: Dictionary = {}

var uid: String = ""
var kind: String = ""
var model_name: String = ""
var body_w: float = 1.0
var class_id: int = -1

var _data: Dictionary = {}
var _materials: Dictionary = {}    # nome -> StandardMaterial3D
var _weapons: Dictionary = {}      # encaixe -> modelo da arma
var _groups: Dictionary = {}       # nome -> Node3D
var _pivots: Dictionary = {}       # nome -> Vector3 (posição no modelo)
var _anchors: Dictionary = {}      # nome -> Node3D
var _anim_groups: Array = []       # [{node, anim, base_pos}]
var _anim_materials: Array = []    # [{mat, anim, energy, alpha}]
var _hd: bool = false
var _hd_anim: AnimationPlayer = null
var _hd_current: String = ""
var _gear_nodes: Array = []
var _gear_anims: Array = []
var _rest_pose: Dictionary = {}
var _articulated: bool = false

var _time: float = 0.0
var _move_speed: float = 0.0
var _loco_phase: float = 0.0
var _oneshot: String = ""
var _oneshot_t: float = 0.0
var _oneshot_hold: bool = false
var _loop_override: String = ""
var _source: String = ""
var _blend_from: Dictionary = {}
var _blend_t: float = 1.0
var _applied: Dictionary = {}


# ---------------------------------------------------------------------------
# API estática
# ---------------------------------------------------------------------------

static func race_uid(race_id: int) -> String:
	return "race_%d" % race_id


static func npc_uid(npc_id: int) -> String:
	return "npc_%d" % npc_id


static func has_model(model_uid: String) -> bool:
	return Data.MODELS.has(model_uid)


static func get_uids(of_kind: String) -> Array:
	var out: Array = []
	for k in Data.MODELS.keys():
		if Data.MODELS[k]["kind"] == of_kind:
			out.append(k)
	return out


static func get_clip_names() -> Array:
	return Data.CLIPS.keys()


static func get_info(model_uid: String) -> Dictionary:
	if not has_model(model_uid):
		return {}
	var d: Dictionary = Data.MODELS[model_uid]
	return {"uid": model_uid, "id": d["id"], "kind": d["kind"], "name": d["name"], "title": d["title"],
		"lore": d["lore"], "color": Color(d["color"])}


## Cria qualquer modelo pelo uid ("race_19", "npc_100", "weapon_knight_longsword"...).
static func create(model_uid: String, with_lights: bool = true) -> Node3D:
	var hd := hd_path(model_uid)
	if not has_model(model_uid) and hd == "":
		return null
	var m: Node3D = load(SCRIPT_PATH).new()
	if hd != "":
		m._build_hd(Data.MODELS.get(model_uid, {"uid": model_uid, "kind": "", "name": model_uid, "key": model_uid}), load(hd))
	else:
		m._build(Data.MODELS[model_uid], with_lights)
	return m


## Caminho do .glb detalhado (HD) deste modelo, se existir. Raças aceitam variantes _m e _f.
static func hd_path(model_uid: String) -> String:
	if not use_hd:
		return ""
	for cand in [model_uid, model_uid + "_m", model_uid + "_f"]:
		var path: String = HD_DIR + cand + ".glb"
		if ResourceLoader.exists(path):
			return path
	return ""


## Cria uma raça já vestida e armada com a classe indicada (-1 = sem equipamento).
static func create_race(race_id: int, p_class_id: int = -1, with_lights: bool = true) -> Node3D:
	var m := create(race_uid(race_id), with_lights)
	if m and p_class_id >= 0:
		m.set_class(p_class_id)
	return m


static func create_npc(npc_id: int, with_lights: bool = true) -> Node3D:
	return create(npc_uid(npc_id), with_lights)


static func mob_uid(mob_type: int) -> String:
	return "mob_%d" % mob_type


## Cria uma criatura (mob) com suas armas próprias já nas mãos.
static func create_mob(mob_type: int, with_lights: bool = true) -> Node3D:
	return create(mob_uid(mob_type), with_lights)


# ---------------------------------------------------------------------------
# API de instância
# ---------------------------------------------------------------------------

## Velocidade horizontal (m/s): mistura idle, walk e run automaticamente.
func set_move_speed(speed: float) -> void:
	_move_speed = speed


## Toca um clipe uma vez. hold_last = mantém o último quadro (ex.: death_fall).
func play(clip_name: String, hold_last: bool = false) -> void:
	if not Data.CLIPS.has(clip_name):
		return
	var clip: Dictionary = Data.CLIPS[clip_name]
	if clip["loop"]:
		_loop_override = clip_name
		_oneshot = ""
		return
	_oneshot = clip_name
	_oneshot_t = 0.0
	_oneshot_hold = hold_last


## Volta para a locomoção (encerra kneel_autopsy, death_fall mantido etc.).
func stop_override() -> void:
	_oneshot = ""
	_oneshot_hold = false
	_loop_override = ""


func is_playing_action() -> bool:
	return _oneshot != ""


## Toca a animação correspondente à ação do jogo (1=básico, 2=esquiva, 3=Q, 4=R, 5=F, 6=Z).
func play_action(action_type: int) -> void:
	var actions: Dictionary = DEFAULT_ACTIONS
	var key := str(class_id)
	if Data.LOADOUTS.has(key):
		actions = Data.LOADOUTS[key]["actions"]
	play(actions.get(str(action_type), DEFAULT_ACTIONS.get(str(action_type), "attack_1h")))


## Veste o traje da classe, coloca as armas nas mãos e invoca o companheiro.
func set_class(p_class_id: int) -> void:
	class_id = p_class_id
	_clear_gear()
	var key := str(p_class_id)
	if not Data.LOADOUTS.has(key):
		return
	var lo: Dictionary = Data.LOADOUTS[key]
	if lo.has("outfit") and has_model(lo["outfit"]) and not _hd:
		_add_outfit(Data.MODELS[lo["outfit"]])
	for slot in ["hand_r", "hand_l"]:
		if lo.has(slot):
			_attach(slot, lo[slot])
	if lo.has("companion"):
		var comp := create(lo["companion"], true)
		if comp:
			add_child(comp)
			_gear_nodes.append(comp)


## Ponto de encaixe (hand_r, hand_l, back) para prender itens extras.
func get_anchor(anchor_name: String) -> Node3D:
	return _anchors.get(anchor_name, null)


## Material do modelo pelo nome (ex.: "fur_grey"), para efeitos de brilho no jogo.
func get_material(mat_name: String) -> StandardMaterial3D:
	return _materials.get(mat_name, null)


## Material principal (pelagem, armadura...) usado pelos efeitos de lua e estado dos mobs.
func get_primary_material() -> StandardMaterial3D:
	return _materials.get(_data.get("primary", ""), null)


## Material do escudo da criatura (brilha quando ela bloqueia).
func get_shield_material() -> StandardMaterial3D:
	var sm: Array = _data.get("shield_material", [])
	if sm.size() < 2:
		return null
	for w in _weapons.values():
		if is_instance_valid(w) and w.uid == sm[0]:
			return w.get_material(sm[1])
	return null


## Ações das criaturas: "attack", "block", "hit", "death".
func play_creature(action: String) -> void:
	var actions: Dictionary = _data.get("extra_actions", {})
	var clip: String = actions.get(action, "")
	if clip == "":
		return
	play(clip, action == "death")


## Coloca o modelo direto no último quadro da animação de morte (cadáveres).
func pose_dead() -> void:
	var clip: String = _data.get("extra_actions", {}).get("death", "death_fall")
	if not Data.CLIPS.has(clip):
		return
	play(clip, true)
	_oneshot_t = float(Data.CLIPS[clip]["length"])
	_source = clip
	_blend_t = 1.0


func _attach(slot: String, h: Dictionary) -> void:
	if not _anchors.has(slot):
		return
	var weapon := create(h["weapon"], true)
	if weapon:
		weapon.position = _vec(h["offset"])
		weapon.rotation_degrees = _vec(h["rot"])
		_anchors[slot].add_child(weapon)
		_gear_nodes.append(weapon)
		_weapons[slot] = weapon


# ---------------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------------

func _build(d: Dictionary, with_lights: bool) -> void:
	uid = d["uid"]
	kind = d["kind"]
	model_name = d["name"]
	body_w = float(d.get("body_w", 1.0))
	name = "LunariaModel_%s" % d["key"]
	scale = Vector3.ONE * float(d.get("scale", 1.0))
	_rest_pose = d.get("rest_pose", {})

	_data = d
	var mats := _make_materials(d["materials"], _anim_materials)
	_materials = mats
	_add_groups(d["groups"], 1.0, null, _anim_groups)
	_add_parts(d["parts"], mats, 1.0, null)
	_articulated = _groups.has("pose")

	for anchor_name in d.get("anchors", {}):
		var a: Dictionary = d["anchors"][anchor_name]
		var node := Node3D.new()
		node.name = "Anchor_" + anchor_name
		var group_name: String = a.get("group", "") if a.get("group") != null else ""
		var gp: Vector3 = _pivots.get(group_name, Vector3.ZERO)
		node.position = _vec(a["pos"]) - gp
		node.rotation_degrees = _vec(a["rot"])
		_groups.get(group_name, self).add_child(node)
		_anchors[anchor_name] = node

	# Armas próprias das criaturas (mobs não usam set_class)
	for slot in d.get("gear", {}):
		_attach(slot, d["gear"][slot])

	if with_lights:
		for l in d.get("lights", []):
			var light := OmniLight3D.new()
			light.light_color = Color(l["color"])
			light.light_energy = float(l["energy"])
			light.omni_range = float(l["range"])
			light.position = _vec(l["pos"])
			add_child(light)


func _add_groups(groups: Array, x_scale: float, created: Variant, anim_list: Array) -> void:
	for g in groups:
		var node := Node3D.new()
		node.name = g["name"]
		var pivot := _vec(g["pivot"])
		pivot.x *= x_scale
		var parent_name: String = g.get("parent", "") if g.get("parent") != null else ""
		var parent: Node3D = _groups.get(parent_name, self)
		var parent_pivot: Vector3 = _pivots.get(parent_name, Vector3.ZERO)
		node.position = pivot - parent_pivot
		parent.add_child(node)
		_groups[g["name"]] = node
		_pivots[g["name"]] = pivot
		if created != null:
			created.append(node)
		if g.has("anim"):
			anim_list.append({"node": node, "anim": g["anim"], "base_pos": node.position})


func _add_parts(parts: Array, mats: Dictionary, x_scale: float, created: Variant) -> void:
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _get_mesh(p["shape"], p["size"])
		var mat: Material = mats[p["mat"]]
		mi.material_override = mat
		var group_name: String = p.get("group", "")
		var pos := _vec(p["pos"])
		pos.x *= x_scale
		mi.position = pos - _pivots.get(group_name, Vector3.ZERO)
		if p.has("rot"):
			mi.rotation_degrees = _vec(p["rot"])
		var sc := _vec(p["scale"]) if p.has("scale") else Vector3.ONE
		if x_scale != 1.0:
			sc.x *= x_scale
		mi.scale = sc
		if (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_groups.get(group_name, self).add_child(mi)
		if created != null:
			created.append(mi)


func _add_outfit(od: Dictionary) -> void:
	var mats := _make_materials(od["materials"], _gear_anims)
	# Pivôs do traje valem só durante a montagem; o corpo mantém os seus registros.
	var groups_before := _groups.duplicate()
	var pivots_before := _pivots.duplicate()
	_add_groups(od["groups"], body_w, _gear_nodes, _gear_anims)
	_add_parts(od["parts"], mats, body_w, _gear_nodes)
	_groups = groups_before
	_pivots = pivots_before


func _clear_gear() -> void:
	_weapons.clear()
	for n in _gear_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_gear_nodes.clear()
	_gear_anims.clear()


func _make_materials(specs: Dictionary, anim_list: Array) -> Dictionary:
	var out: Dictionary = {}
	for key in specs:
		var spec: Dictionary = specs[key]
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
		if spec.has("tex"):
			LunariaTextures.apply(mat, spec["tex"], float(spec.get("tile", 0.0)))
		LunariaStyle.anime(mat, not spec.get("no_outline", false), float(spec.get("outline", LunariaStyle.OUTLINE_WIDTH)))
		if spec.has("anim"):
			anim_list.append({"mat": mat, "anim": spec["anim"], "energy": energy, "alpha": alpha})
		out[key] = mat
	return out


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
			sp.radial_segments = 32
			sp.rings = 16
			mesh = sp
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = s[0]
			c.bottom_radius = s[1]
			c.height = s[2]
			c.radial_segments = 24
			c.rings = 1
			mesh = c
		"capsule":
			var cap := CapsuleMesh.new()
			cap.radius = s[0]
			cap.height = maxf(s[1], s[0] * 2.0 + 0.001)
			cap.radial_segments = 24
			cap.rings = 8
			mesh = cap
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = s[0]
			t.outer_radius = s[1]
			t.rings = 36
			t.ring_segments = 12
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


# ---------------------------------------------------------------------------
# Animação
# ---------------------------------------------------------------------------

static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func _sample(clip: Dictionary, t: float) -> Dictionary:
	var keys: Array = clip["keys"]
	if t <= float(keys[0][0]):
		return keys[0][1]
	for i in range(keys.size() - 1):
		var t0 := float(keys[i][0])
		var t1 := float(keys[i + 1][0])
		if t <= t1:
			var f := _smooth((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
			var p0: Dictionary = keys[i][1]
			var p1: Dictionary = keys[i + 1][1]
			var out: Dictionary = {}
			for ch in LIMB_CHANNELS + ["root"]:
				if p0.has(ch) or p1.has(ch):
					var a: Array = p0.get(ch, [0, 0, 0])
					var b: Array = p1.get(ch, [0, 0, 0])
					out[ch] = [lerpf(a[0], b[0], f), lerpf(a[1], b[1], f), lerpf(a[2], b[2], f)]
			if p0.has("root_y") or p1.has("root_y"):
				out["root_y"] = lerpf(float(p0.get("root_y", 0.0)), float(p1.get("root_y", 0.0)), f)
			return out
	return keys[keys.size() - 1][1]


static func _add_weighted(acc: Dictionary, pose: Dictionary, w: float) -> void:
	if w <= 0.0:
		return
	for ch in pose:
		if ch == "root_y":
			acc[ch] = float(acc.get(ch, 0.0)) + float(pose[ch]) * w
		else:
			var a: Array = acc.get(ch, [0.0, 0.0, 0.0])
			var v: Array = pose[ch]
			acc[ch] = [a[0] + v[0] * w, a[1] + v[1] * w, a[2] + v[2] * w]


func _target_pose(delta: float) -> Dictionary:
	if _oneshot != "":
		var clip: Dictionary = Data.CLIPS[_oneshot]
		_oneshot_t += delta
		if _oneshot_t >= float(clip["length"]) and not _oneshot_hold:
			_oneshot = ""
		else:
			_set_source(_oneshot)
			return _sample(clip, minf(_oneshot_t, float(clip["length"])))
	if _loop_override != "":
		_set_source(_loop_override)
		var lc: Dictionary = Data.CLIPS[_loop_override]
		return _sample(lc, fmod(_time, float(lc["length"])))

	_set_source("loco")
	var s := _move_speed
	var run_w := clampf((s - 3.0) / 3.0, 0.0, 1.0)
	var walk_w := clampf(s / 2.0, 0.0, 1.0) * (1.0 - run_w)
	var idle_w := 1.0 - walk_w - run_w
	_loco_phase = fmod(_loco_phase + delta * lerpf(1.0, 1.0 / 0.7, run_w) * (1.0 if s > 0.15 else 0.0), 1.0)
	var pose: Dictionary = {}
	_add_weighted(pose, _sample(Data.CLIPS["idle"], fmod(_time, 2.0)), idle_w)
	_add_weighted(pose, _sample(Data.CLIPS["walk"], _loco_phase * 1.0), walk_w)
	_add_weighted(pose, _sample(Data.CLIPS["run"], _loco_phase * 0.7), run_w)
	return pose


func _set_source(src: String) -> void:
	if src != _source:
		_source = src
		_blend_from = _applied.duplicate(true)
		_blend_t = 0.0


func _apply_pose(target: Dictionary, delta: float) -> void:
	_blend_t = minf(_blend_t + delta / BLEND_TIME, 1.0)
	var w := _smooth(_blend_t)
	for ch in LIMB_CHANNELS + ["root"]:
		var tv: Array = target.get(ch, [0.0, 0.0, 0.0])
		var fv: Array = _blend_from.get(ch, tv)
		var v := Vector3(
			rad_to_deg(lerp_angle(deg_to_rad(fv[0]), deg_to_rad(tv[0]), w)),
			rad_to_deg(lerp_angle(deg_to_rad(fv[1]), deg_to_rad(tv[1]), w)),
			rad_to_deg(lerp_angle(deg_to_rad(fv[2]), deg_to_rad(tv[2]), w)))
		_applied[ch] = [v.x, v.y, v.z]
		var rest: Array = _rest_pose.get(ch, [0.0, 0.0, 0.0])
		var node_name: String = "pose" if ch == "root" else ch
		var node: Node3D = _groups.get(node_name, null)
		if node:
			node.rotation_degrees = v + Vector3(rest[0], rest[1], rest[2])
	var ty := float(target.get("root_y", 0.0))
	var y := lerpf(float(_blend_from.get("root_y", ty)), ty, w)
	_applied["root_y"] = y
	var pose_node: Node3D = _groups["pose"]
	pose_node.position.y = _pivots["pose"].y + y + float(_rest_pose.get("root_y", 0.0))


# ---------------------------------------------------------------------------
# Modelos HD (.glb esculpido + rig)
# ---------------------------------------------------------------------------

func _build_hd(d: Dictionary, scene: PackedScene) -> void:
	_hd = true
	_data = d
	uid = d.get("uid", "")
	kind = d.get("kind", "")
	model_name = d.get("name", uid)
	name = "LunariaHD_%s" % d.get("key", uid)
	var inst := scene.instantiate() as Node3D
	add_child(inst)
	# Altura alvo: humanoides ~1,85 m x escala da raça; armas mantêm o tamanho do arquivo
	if kind in ["race", "npc", "mob"]:
		var box := _local_aabb(inst, Transform3D.IDENTITY)
		if box.size.y > 0.001:
			var target_h := 1.85 * float(d.get("scale", 1.0))
			inst.scale = Vector3.ONE * (target_h / box.size.y)
			inst.position.y = -box.position.y * inst.scale.y
	_hd_anim = _find_child_of_type(inst, "AnimationPlayer") as AnimationPlayer
	var skel := _find_child_of_type(inst, "Skeleton3D") as Skeleton3D
	if skel:
		for slot in HD_BONES:
			for bone_name in HD_BONES[slot]:
				if skel.find_bone(bone_name) >= 0:
					var att := BoneAttachment3D.new()
					att.bone_name = bone_name
					skel.add_child(att)
					var holder := Node3D.new()
					holder.name = "Anchor_" + slot
					att.add_child(holder)
					_anchors[slot] = holder
					break
	for slot in d.get("gear", {}):
		_attach(slot, d["gear"][slot])


func _hd_anim_name(clip: String) -> String:
	if _hd_anim == null:
		return ""
	var wanted: Array = HD_ANIM_NAMES.get(clip, [clip])
	for anim_name in _hd_anim.get_animation_list():
		var short: String = anim_name.get_slice("|", anim_name.get_slice_count("|") - 1)
		for w in wanted + [clip]:
			if short.to_lower() == String(w).to_lower():
				return anim_name
	return ""


func _process_hd(delta: float) -> void:
	if _hd_anim == null:
		return
	var clip := ""
	if _oneshot != "":
		_oneshot_t += delta
		var length := float(Data.CLIPS.get(_oneshot, {"length": 0.6})["length"])
		var anim_name := _hd_anim_name(_oneshot)
		if anim_name != "":
			length = _hd_anim.get_animation(anim_name).length
		if _oneshot_t >= length and not _oneshot_hold:
			_oneshot = ""
		else:
			clip = _oneshot
	if clip == "":
		clip = _loop_override if _loop_override != "" else ("run" if _move_speed > 3.0 else ("walk" if _move_speed > 0.15 else "idle"))
	var target := _hd_anim_name(clip)
	if target != "" and target != _hd_current:
		_hd_current = target
		_hd_anim.play(target, BLEND_TIME)


static func _find_child_of_type(node: Node, type_name: String) -> Node:
	for c in node.get_children():
		if c.is_class(type_name):
			return c
		var found := _find_child_of_type(c, type_name)
		if found:
			return found
	return null


static func _local_aabb(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var has := false
	var t := xform
	if node is Node3D:
		t = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = t * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in node.get_children():
		var cb := _local_aabb(c, t)
		if cb.size != Vector3.ZERO:
			box = cb if not has else box.merge(cb)
			has = true
	return box


func _process(delta: float) -> void:
	_time += delta
	var t := _time
	if _hd:
		_process_hd(delta)
		return
	if _articulated:
		_apply_pose(_target_pose(delta), delta)

	for list in [_anim_groups, _gear_anims]:
		for a in list:
			if a.has("node"):
				var node: Node3D = a["node"]
				if not is_instance_valid(node):
					continue
				var an: Dictionary = a["anim"]
				var ph := float(an.get("phase", 0.0))
				match an["type"]:
					"spin":
						node.basis = Basis(_vec(an["axis"]).normalized(), deg_to_rad(float(an["speed"]) * t))
					"sway":
						node.basis = Basis(_vec(an["axis"]).normalized(), deg_to_rad(float(an["amp"])) * sin(float(an["speed"]) * t + ph))
					"bob":
						var base: Vector3 = a["base_pos"]
						node.position.y = base.y + float(an["amp"]) * sin(float(an["speed"]) * t + ph)
					"pulse":
						node.scale = Vector3.ONE * (1.0 + float(an["amp"]) * sin(float(an["speed"]) * t + ph))
			else:
				var mat: StandardMaterial3D = a["mat"]
				var an2: Dictionary = a["anim"]
				var lo := float(an2["min"])
				var hi := float(an2["max"])
				var spd := float(an2["speed"])
				if an2["type"] == "glow":
					mat.emission_energy_multiplier = float(a["energy"]) * lerpf(lo, hi, 0.5 + 0.5 * sin(spd * t))
				elif an2["type"] == "flicker":
					var n := 0.5 + 0.5 * sin(spd * t) * sin(spd * 1.73 * t + 1.3)
					mat.albedo_color.a = float(a["alpha"]) * lerpf(lo, hi, n)
