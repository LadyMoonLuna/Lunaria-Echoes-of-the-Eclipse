extends RefCounted
## Estilo visual anime de Lunaria (inspirado em Sword Art Online / Fate).
##
## - Sombreamento em faixas (toon diffuse + toon specular), como cel-shading.
## - Luz de recorte (rim light) para destacar a silhueta.
## - Contorno de tinta por "casco invertido" (segunda passada com a malha inflada e faces de
##   trás), igual ao traço preto dos personagens de anime.
##
## Uso:
##   const LunariaStyle = preload("res://scripts/models/LunariaStyle.gd")
##   LunariaStyle.anime(mat)                 # cel-shading + contorno
##   LunariaStyle.anime(mat, false)          # só cel-shading (cenário)

const OUTLINE_WIDTH: float = 0.0045   # metros, no espaço da malha
const RIM_STRENGTH: float = 0.35

static var enabled: bool = true
static var outlines_enabled: bool = true
static var _outline_cache: Dictionary = {}


static func anime(mat: StandardMaterial3D, outline: bool = true, outline_width: float = OUTLINE_WIDTH) -> void:
	if mat == null or not enabled:
		return
	if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.rim_enabled = true
	mat.rim = RIM_STRENGTH
	mat.rim_tint = 0.65
	var glowing := mat.emission_enabled and mat.emission_energy_multiplier >= 1.5
	var transparent := mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if outline and outlines_enabled and not glowing and not transparent:
		mat.next_pass = outline_material(mat.albedo_color, outline_width)


## Material do contorno: cor da superfície escurecida (traço colorido, não preto chapado).
static func outline_material(base: Color, width: float = OUTLINE_WIDTH) -> StandardMaterial3D:
	var ink := Color(base.r * 0.22, base.g * 0.2, base.b * 0.26, 1.0)
	var key := "%s|%.4f" % [ink.to_html(false), width]
	if _outline_cache.has(key):
		return _outline_cache[key]
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = ink
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = width
	o.disable_receive_shadows = true
	_outline_cache[key] = o
	return o
