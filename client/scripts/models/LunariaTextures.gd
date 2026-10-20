extends RefCounted
## Biblioteca de texturas PBR de Lunaria (client/assets/textures/).
##
## Cada textura tem três mapas tileáveis: _albedo (detalhe neutro que multiplica a cor
## do material), _normal (relevo) e _orm (oclusão, aspereza, metálico). A projeção é
## triplanar, então funciona em qualquer malha sem precisar de UV.
##
## Uso:
##   const LunariaTextures = preload("res://scripts/models/LunariaTextures.gd")
##   LunariaTextures.apply(mat, "cobblestone")        # ladrilho padrão do material
##   LunariaTextures.apply(mat, "wood", 0.8)          # 1 repetição a cada 0,8 m
##   LunariaTextures.apply(mat, "stone", 0.9, true)   # coordenadas do mundo (cenário)

const TEX_DIR: String = "res://assets/textures/"
const DEFAULT_TILE: Dictionary = {
	"chainmail": 0.22, "cloth": 0.35, "linen": 0.35, "leather": 0.45, "scales": 0.35, "feather": 0.3,
	"skin": 0.5, "fur": 0.4, "hair": 0.35, "bone": 0.3, "metal_brushed": 0.5, "metal_hammered": 0.5,
	"wood": 0.6, "planks": 1.2, "bark": 0.6, "stone": 0.9, "cobblestone": 1.8, "stone_blocks": 2.4,
	"roof_tiles": 1.6, "marble": 0.8, "crystal": 0.4, "obsidian": 0.5, "fungal": 0.4, "moss": 0.4,
	"leaf": 0.25, "plaster": 1.5, "ground": 3.0,
}

static var _cache: Dictionary = {}


static func has_texture(tex_name: String) -> bool:
	return DEFAULT_TILE.has(tex_name) and ResourceLoader.exists(TEX_DIR + tex_name + "_albedo.png")


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[path] = tex
	return tex


## Aplica a textura ao material. tile_m = metros por repetição (<= 0 usa o padrão).
## world_space = true projeta pelas coordenadas do mundo (bom para pisos e muros contínuos).
static func apply(mat: StandardMaterial3D, tex_name: String, tile_m: float = 0.0, world_space: bool = false) -> void:
	if mat == null or not has_texture(tex_name):
		return
	var albedo := _load(TEX_DIR + tex_name + "_albedo.png")
	var normal := _load(TEX_DIR + tex_name + "_normal.png")
	var orm := _load(TEX_DIR + tex_name + "_orm.png")
	if albedo:
		mat.albedo_texture = albedo
	if normal:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 1.0
	if orm:
		mat.roughness_texture = orm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.ao_enabled = true
		mat.ao_texture = orm
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.ao_light_affect = 0.6
	var tile := tile_m if tile_m > 0.0 else float(DEFAULT_TILE.get(tex_name, 0.5))
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world_space
	mat.uv1_triplanar_sharpness = 4.0
	mat.uv1_scale = Vector3.ONE / tile
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
