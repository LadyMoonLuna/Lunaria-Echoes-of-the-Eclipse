extends RefCounted
## Modelos procedurais da fauna (FaunaData.SPECIES): um desenho por tipo de corpo, escalado pelo
## tamanho real da espécie e pintado com a cor dela. Usado pelo bicho vivo e pelo corpo caído.

const FaunaData = preload("res://scripts/world/FaunaData.gd")

static func is_fauna(mob_type: int) -> bool:
	return FaunaData.SPECIES.has(mob_type)

static func species(mob_type: int) -> Dictionary:
	return FaunaData.SPECIES.get(mob_type, {})

static func species_name(mob_type: int) -> String:
	return str(species(mob_type).get("name", "Criatura"))

## Altura da etiqueta de nome acima do bicho.
static func tag_height(mob_type: int) -> float:
	var s: float = species(mob_type).get("scale", 1.0)
	return 0.6 + 1.3 * s

static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _box(sx: float, sy: float, sz: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return b

static func _sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 12
	s.rings = 6
	return s

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 12
	return c

## Monta o bicho dentro de `root` (escala aplicada no próprio root). Devolve o material principal.
static func build(root: Node3D, mob_type: int, dead := false) -> StandardMaterial3D:
	var sp := species(mob_type)
	var body: int = sp.get("body", 1)
	var s: float = sp.get("scale", 1.0)
	var col: Color = sp.get("color", Color(0.5, 0.4, 0.3))
	if dead:
		col = col.darkened(0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	var dark := StandardMaterial3D.new()
	dark.albedo_color = col.darkened(0.45)
	dark.roughness = 0.9
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.05, 0.05, 0.05) if not dead else Color(0.3, 0.3, 0.3)
	var beak := StandardMaterial3D.new()
	beak.albedo_color = Color(0.85, 0.65, 0.25)
	root.scale = Vector3(s, s, s)
	match body:
		1: # quadrúpede
			_part(root, _capsule(0.32, 1.2), mat, Vector3(0, 0.62, 0), Vector3(PI / 2, 0, 0))
			_part(root, _box(0.3, 0.3, 0.42), mat, Vector3(0, 0.82, -0.72))
			_part(root, _box(0.14, 0.14, 0.18), dark, Vector3(0, 0.76, -0.98))
			for sx in [-0.09, 0.09]:
				_part(root, _box(0.06, 0.14, 0.04), dark, Vector3(sx, 1.02, -0.66))
				_part(root, _sphere(0.035), eye, Vector3(sx * 1.4, 0.88, -0.93))
			for lx in [-0.18, 0.18]:
				for lz in [-0.38, 0.38]:
					_part(root, _box(0.11, 0.5, 0.11), dark, Vector3(lx, 0.25, lz))
			_part(root, _box(0.07, 0.07, 0.35), dark, Vector3(0, 0.72, 0.72), Vector3(0.6, 0, 0))
		2: # ave
			_part(root, _sphere(0.26, 0.5), mat, Vector3(0, 0.45, 0))
			_part(root, _sphere(0.14), mat, Vector3(0, 0.72, -0.18))
			_part(root, _box(0.06, 0.05, 0.16), beak, Vector3(0, 0.7, -0.36))
			for wx in [-1.0, 1.0]:
				_part(root, _box(0.42, 0.04, 0.26), dark, Vector3(wx * 0.3, 0.5, 0.02), Vector3(0, 0, wx * 0.25))
				_part(root, _box(0.03, 0.22, 0.03), dark, Vector3(wx * 0.08, 0.12, 0))
				_part(root, _sphere(0.025), eye, Vector3(wx * 0.08, 0.76, -0.28))
			_part(root, _box(0.18, 0.03, 0.28), dark, Vector3(0, 0.45, 0.32), Vector3(-0.3, 0, 0))
		3: # serpente: segmentos ondulando no chão
			for i in 8:
				var r := 0.11 - absf(i - 2) * 0.008
				_part(root, _sphere(maxf(r, 0.05)), mat, Vector3(sin(i * 0.9) * 0.18, 0.1, -0.5 + i * 0.16))
			_part(root, _box(0.18, 0.1, 0.22), dark, Vector3(0, 0.12, -0.66))
			for ex in [-0.06, 0.06]:
				_part(root, _sphere(0.02), eye, Vector3(ex, 0.17, -0.72))
		4: # inseto
			_part(root, _sphere(0.22, 0.32), mat, Vector3(0, 0.25, 0.2))
			_part(root, _sphere(0.14), dark, Vector3(0, 0.25, -0.1))
			_part(root, _sphere(0.1), dark, Vector3(0, 0.27, -0.3))
			_part(root, _box(0.03, 0.03, 0.3), dark, Vector3(0, 0.38, -0.45), Vector3(-0.5, 0, 0))
			for side in [-1.0, 1.0]:
				for k in 3:
					_part(root, _box(0.3, 0.03, 0.03), dark, Vector3(side * 0.18, 0.14, -0.15 + k * 0.15), Vector3(0, 0, side * -0.5))
		5: # aracnídeo
			_part(root, _sphere(0.26), mat, Vector3(0, 0.3, 0.22))
			_part(root, _sphere(0.16), dark, Vector3(0, 0.27, -0.12))
			for side in [-1.0, 1.0]:
				for k in 4:
					_part(root, _box(0.5, 0.035, 0.035), dark, Vector3(side * 0.3, 0.24, -0.25 + k * 0.12), Vector3(0, (k - 1.5) * 0.25 * side, side * -0.6))
			for ex in [-0.05, 0.05]:
				_part(root, _sphere(0.025), eye, Vector3(ex, 0.33, -0.26))
		6: # peixe
			_part(root, _sphere(0.2, 0.36), mat, Vector3(0, 0.0, 0)).scale = Vector3(0.7, 1.0, 2.0)
			_part(root, _box(0.04, 0.3, 0.2), dark, Vector3(0, 0.0, 0.48))
			_part(root, _box(0.03, 0.14, 0.2), dark, Vector3(0, 0.18, 0.0))
			for ex in [-0.09, 0.09]:
				_part(root, _sphere(0.03), eye, Vector3(ex, 0.04, -0.3))
		7: # anfíbio / mamífero aquático baixo
			_part(root, _capsule(0.24, 0.9), mat, Vector3(0, 0.26, 0), Vector3(PI / 2, 0, 0))
			_part(root, _sphere(0.18), mat, Vector3(0, 0.32, -0.5))
			for ex in [-0.08, 0.08]:
				_part(root, _sphere(0.035), eye, Vector3(ex, 0.42, -0.62))
			for lx in [-0.22, 0.22]:
				for lz in [-0.25, 0.28]:
					_part(root, _box(0.14, 0.18, 0.12), dark, Vector3(lx, 0.09, lz))
			_part(root, _box(0.16, 0.05, 0.4), dark, Vector3(0, 0.18, 0.62))
		8: # réptil
			_part(root, _capsule(0.2, 1.0), mat, Vector3(0, 0.22, 0), Vector3(PI / 2, 0, 0))
			_part(root, _box(0.22, 0.14, 0.32), mat, Vector3(0, 0.24, -0.62))
			_part(root, _box(0.12, 0.08, 0.6), dark, Vector3(0, 0.16, 0.75))
			for lx in [-0.24, 0.24]:
				for lz in [-0.3, 0.3]:
					_part(root, _box(0.22, 0.06, 0.08), dark, Vector3(lx, 0.1, lz))
			for ex in [-0.08, 0.08]:
				_part(root, _sphere(0.03), eye, Vector3(ex, 0.32, -0.7))
		9: # caranguejo
			_part(root, _sphere(0.3, 0.24), mat, Vector3(0, 0.22, 0)).scale = Vector3(1.3, 1.0, 1.0)
			for side in [-1.0, 1.0]:
				_part(root, _box(0.16, 0.12, 0.2), mat, Vector3(side * 0.42, 0.26, -0.3))
				for k in 3:
					_part(root, _box(0.32, 0.03, 0.03), dark, Vector3(side * 0.38, 0.12, -0.05 + k * 0.12), Vector3(0, 0, side * -0.5))
				_part(root, _sphere(0.03), eye, Vector3(side * 0.07, 0.38, -0.24))
		_:
			_part(root, _box(0.6, 0.5, 0.9), mat, Vector3(0, 0.3, 0))
	return mat
