# Texturas de Lunaria

Biblioteca de 27 texturas PBR tileáveis (sem emenda), geradas por `gen_textures.py`, em `client/assets/textures/`:

| Mapa | Conteúdo |
| :--- | :--- |
| `<nome>_albedo.png` | Detalhe de cor quase neutro, multiplicado pela cor do material (uma textura serve para várias cores) |
| `<nome>_normal.png` | Relevo (convenção OpenGL, igual ao Godot e ao glTF) |
| `<nome>_orm.png` | R = oclusão, G = aspereza (70–100% da aspereza do material), B = metálico |

Texturas: madeira, tábuas, casca de árvore, couro, tecido trançado, linho, pelagem, cabelo, pele, escamas, cota de
malha, metal escovado, metal batido, rocha, calçamento, blocos de pedra, telhas, mármore, cristal, obsidiana, osso,
fungo, musgo, folha, pena, reboco e terra batida. A folha de contato fica em `docs/previews/texturas.png`.

## Regerar

```bash
python3 tools/textures/gen_textures.py   # texturas
python3 tools/race_models/build.py       # reaplica nos modelos, .glb e preview
```

## Onde são usadas

- **Personagens, NPCs, armas e trajes:** cada material recebe uma textura pelo nome (`tools/race_models/texmap.py`).
  Olhos, runas, fogo, magia e outros brilhos continuam lisos de propósito.
- **Cenário** (`World.gd`): piso, muros, calçamento, casas, telhados, portas, móveis, forja, bueiro, obeliscos e marcos.
- **Mobs e cadáveres** (`MobEntity.gd`, `CorpseEntity.gd`): o corpo principal de cada tipo de mob.
- **`.glb`**: UVs em metros e referência às texturas da pasta acima (KHR_texture_transform para o tamanho do ladrilho).

## Usar em código novo

```gdscript
const LunariaTextures = preload("res://scripts/models/LunariaTextures.gd")
var mat := StandardMaterial3D.new()
mat.albedo_color = Color("#6b4a32")
LunariaTextures.apply(mat, "leather")              # ladrilho padrão
LunariaTextures.apply(mat, "cobblestone", 1.5, true) # 1 repetição a cada 1,5 m, em coordenadas do mundo
```

A projeção é triplanar: funciona em qualquer malha, sem precisar de UV.
