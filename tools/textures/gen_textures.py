#!/usr/bin/env python3
"""Gera a biblioteca de texturas PBR tileáveis de Lunaria.

Cada material gera três PNGs sem emenda (tileáveis) em client/assets/textures/:
  <nome>_albedo.png  detalhe de cor quase neutro, MULTIPLICADO pela cor do material
                     (uma textura de couro serve para couro marrom, negro ou vermelho)
  <nome>_normal.png  mapa normal (convenção OpenGL / Y+, igual ao Godot e ao glTF)
  <nome>_orm.png     R = oclusão, G = aspereza (roughness), B = metálico (255; o valor
                     final vem do fator do material) — formato ORM do glTF

Também gera docs/previews/texturas.png (folha de contato de todas as texturas).

Uso:  python3 tools/textures/gen_textures.py
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(REPO, "client", "assets", "textures")
SHEET = os.path.join(REPO, "docs", "previews", "texturas.png")
N = 256


# ---------------------------------------------------------------------------
# Ruídos periódicos (tileáveis)
# ---------------------------------------------------------------------------

def _rng(seed):
    return np.random.default_rng(seed)


def value_noise(freq_x, freq_y, seed):
    """Ruído de valor periódico com interpolação suave (tileável)."""
    g = _rng(seed).random((freq_y, freq_x))
    ys = np.arange(N) * freq_y / N
    xs = np.arange(N) * freq_x / N
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % freq_y
    x1 = (x0 + 1) % freq_x
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(base, octaves, seed, stretch=(1, 1)):
    out = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        f = base * (2 ** o)
        out += amp * value_noise(max(1, int(f * stretch[0])), max(1, int(f * stretch[1])), seed + o * 101)
        total += amp
        amp *= 0.5
    return out / total


def voronoi(count, seed, jitter=1.0, grid=None):
    """Voronoi periódico. Retorna (F1, F2, id da célula) normalizados em pixels/N."""
    rng = _rng(seed)
    if grid:
        gx, gy = grid
        pts = []
        for j in range(gy):
            for i in range(gx):
                off = 0.5 * (j % 2) if grid[0] == grid[1] else 0
                pts.append(((i + 0.5 + off + rng.uniform(-0.5, 0.5) * jitter) / gx,
                            (j + 0.5 + rng.uniform(-0.5, 0.5) * jitter) / gy))
        pts = np.array(pts) % 1.0
    else:
        pts = rng.random((count, 2))
    yy, xx = np.mgrid[0:N, 0:N] / N
    f1 = np.full((N, N), 9.0)
    f2 = np.full((N, N), 9.0)
    cid = np.zeros((N, N), dtype=int)
    for k, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, 1 - dx)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, k, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid


def norm01(a):
    a = a - a.min()
    m = a.max()
    return a / m if m > 0 else a


def stripes(freq, axis, seed, warp=0.0, warp_freq=4):
    yy, xx = np.mgrid[0:N, 0:N] / N
    coord = yy if axis == "y" else xx
    if warp:
        coord = coord + warp * (fbm(warp_freq, 3, seed) - 0.5)
    return 0.5 + 0.5 * np.sin(2 * np.pi * freq * coord)


def per_cell(cid, seed, lo=0.0, hi=1.0):
    vals = _rng(seed).uniform(lo, hi, cid.max() + 1)
    return vals[cid]


# ---------------------------------------------------------------------------
# Materiais: cada função retorna (altura, detalhe de cor, aspereza) em 0..1
# ---------------------------------------------------------------------------

def t_wood():
    grain = stripes(9, "x", 11, warp=0.35, warp_freq=3)
    fine = fbm(24, 3, 12, stretch=(1, 0.12))
    knots = 1 - norm01(voronoi(3, 13)[0]) ** 0.3
    h = 0.55 * grain + 0.35 * fine + 0.1 * knots
    return h, 0.6 + 0.4 * h, 0.75 - 0.2 * fine


def t_planks():
    h, col, r = t_wood()
    yy, xx = np.mgrid[0:N, 0:N] / N
    board = (xx * 4) % 1.0
    gap = np.clip(np.minimum(board, 1 - board) * 40, 0, 1)
    row = np.floor(xx * 4).astype(int)
    shift = (row * 0.37) % 1.0
    joint = np.clip(np.abs(((yy + shift) % 1.0) - 0.5) * 2 * 40 - 38, 0, 1) * 0 + 1
    tone = per_cell(row, 14, 0.82, 1.0)
    h = h * gap * joint
    return h, col * tone * (0.55 + 0.45 * gap), r


def t_bark():
    ridges = stripes(7, "x", 21, warp=0.6, warp_freq=2) ** 2
    cracks = norm01(voronoi(18, 22, grid=(6, 3))[1] - voronoi(18, 22, grid=(6, 3))[0])
    noise = fbm(10, 4, 23, stretch=(1, 0.3))
    h = 0.5 * ridges + 0.3 * noise + 0.2 * np.clip(cracks * 4, 0, 1)
    return h, 0.45 + 0.55 * h, 0.9 - 0.1 * h


def t_leather():
    f1, f2, _ = voronoi(70, 31)
    wrinkle = np.clip((f2 - f1) * 18, 0, 1)
    pores = fbm(48, 2, 32)
    h = 0.65 * wrinkle + 0.35 * pores
    return h, 0.72 + 0.28 * h, 0.62 - 0.18 * wrinkle + 0.1 * pores


def t_cloth():
    yy, xx = np.mgrid[0:N, 0:N] / N
    f = 48
    warp_t = 0.5 + 0.5 * np.sin(2 * np.pi * f * xx)
    weft_t = 0.5 + 0.5 * np.sin(2 * np.pi * f * yy)
    checker = (np.floor(xx * f) + np.floor(yy * f)) % 2
    weave = np.where(checker > 0, warp_t, weft_t)
    noise = fbm(16, 3, 41)
    h = 0.7 * weave + 0.3 * noise
    return h, 0.78 + 0.22 * h, 0.85 + 0.1 * noise


def t_linen():
    yy, xx = np.mgrid[0:N, 0:N] / N
    slub = fbm(8, 3, 51, stretch=(0.2, 1))
    weave = 0.5 * stripes(64, "x", 52) + 0.5 * stripes(64, "y", 53)
    h = 0.6 * weave + 0.4 * slub
    return h, 0.82 + 0.18 * h, 0.92


def t_fur():
    strands = fbm(64, 3, 61, stretch=(1, 0.08))
    clumps = fbm(6, 3, 62)
    h = 0.7 * strands + 0.3 * clumps
    return h, 0.55 + 0.45 * h, 0.95


def t_hair():
    strands = fbm(96, 2, 71, stretch=(1, 0.04))
    sheen = stripes(3, "x", 72, warp=0.3)
    h = 0.75 * strands + 0.25 * sheen
    return h, 0.62 + 0.38 * h, 0.55 - 0.15 * strands


def t_skin():
    pores = fbm(96, 2, 81)
    soft = fbm(6, 4, 82)
    h = pores
    return h, 0.92 + 0.08 * soft, 0.62 + 0.15 * pores


def t_scales():
    f1, f2, cid = voronoi(0, 91, jitter=0.15, grid=(10, 10))
    yy, xx = np.mgrid[0:N, 0:N] / N
    dome = 1 - np.clip(f1 * 10 * 1.2, 0, 1)
    edge = np.clip((f2 - f1) * 40, 0, 1)
    h = 0.75 * dome * edge + 0.25 * fbm(32, 2, 92)
    tone = per_cell(cid, 93, 0.82, 1.0)
    return h, (0.55 + 0.45 * h) * tone, 0.4 + 0.3 * (1 - edge)


def t_chainmail():
    yy, xx = np.mgrid[0:N, 0:N] / N
    f = 16
    cx = (xx * f) % 1.0
    cy = (yy * f + 0.5 * (np.floor(xx * f) % 2)) % 1.0
    d = np.sqrt((cx - 0.5) ** 2 + (cy - 0.5) ** 2)
    ring = np.clip(1 - np.abs(d - 0.32) * 9, 0, 1)
    h = ring
    return h, 0.35 + 0.65 * ring, 0.45 - 0.2 * ring + 0.35 * (1 - ring)


def t_metal_brushed():
    streak = fbm(128, 2, 101, stretch=(0.02, 1))
    smudge = fbm(4, 4, 102)
    h = 0.5 * streak + 0.5 * smudge * 0.4
    return h, 0.88 + 0.12 * streak, 0.32 + 0.18 * smudge


def t_metal_hammered():
    f1, f2, _ = voronoi(60, 111)
    dents = norm01(f1) ** 0.6
    smudge = fbm(5, 4, 112)
    h = 0.8 * dents + 0.2 * smudge
    return h, 0.8 + 0.2 * dents, 0.4 + 0.25 * smudge


def t_stone():
    rock = fbm(4, 6, 121)
    f1, f2, _ = voronoi(12, 122)
    crack = np.clip((f2 - f1) * 30, 0, 1)
    h = 0.75 * rock * (0.6 + 0.4 * crack) + 0.25 * fbm(32, 2, 123)
    return h, 0.62 + 0.38 * h, 0.9 - 0.15 * rock


def t_cobblestone():
    f1, f2, cid = voronoi(0, 131, jitter=0.7, grid=(5, 5))
    mortar = np.clip((f2 - f1) * 22, 0, 1)
    dome = np.clip(1 - f1 * 4.5, 0, 1) ** 0.5
    rough_n = fbm(24, 3, 132)
    h = mortar * (0.55 + 0.35 * dome + 0.1 * rough_n)
    tone = per_cell(cid, 133, 0.78, 1.0)
    return h, (0.35 + 0.65 * mortar) * tone * (0.85 + 0.15 * rough_n), 0.92 - 0.12 * dome


def t_stone_blocks():
    yy, xx = np.mgrid[0:N, 0:N] / N
    rows = 4
    row = np.floor(yy * rows)
    shift = (row % 2) * 0.5
    bx = (xx * 2 + shift) % 1.0
    by = (yy * rows) % 1.0
    mortar = np.clip(np.minimum(np.minimum(bx, 1 - bx) * 2 * 30, np.minimum(by, 1 - by) * 30), 0, 1)
    block_id = (row * 4 + np.floor(xx * 2 + shift)).astype(int)
    tone = per_cell(block_id, 141, 0.8, 1.0)
    rock = fbm(8, 5, 142)
    h = mortar * (0.7 + 0.3 * rock)
    return h, (0.4 + 0.6 * mortar) * tone * (0.8 + 0.2 * rock), 0.9


def t_roof_tiles():
    yy, xx = np.mgrid[0:N, 0:N] / N
    rows = 8
    row = np.floor(yy * rows)
    shift = (row % 2) * 0.5
    tx = (xx * 6 + shift) % 1.0
    ty = (yy * rows) % 1.0
    curve = np.sin(np.pi * tx) * 0.6 + ty * 0.4
    edge = np.clip(np.minimum(tx, 1 - tx) * 25, 0, 1) * np.clip((1 - ty) * 18, 0, 1)
    tile_id = (row * 6 + np.floor(xx * 6 + shift)).astype(int)
    tone = per_cell(tile_id, 151, 0.8, 1.0)
    h = curve * edge
    return h, (0.45 + 0.55 * h) * tone, 0.8


def t_marble():
    yy, xx = np.mgrid[0:N, 0:N] / N
    turb = fbm(3, 6, 161)
    veins = np.abs(np.sin(2 * np.pi * (xx * 2 + yy + turb * 2.2)))
    veins = 1 - np.clip(veins * 6, 0, 1) * 0 - (1 - veins) ** 12
    h = 0.15 * fbm(16, 3, 162) + 0.1 * veins
    return h, 0.86 + 0.14 * veins, 0.18 + 0.08 * fbm(8, 3, 163)


def t_crystal():
    f1, f2, cid = voronoi(14, 171)
    facet = per_cell(cid, 172)
    edge = np.clip((f2 - f1) * 25, 0, 1)
    h = 0.6 * facet + 0.4 * edge
    return h, 0.8 + 0.2 * facet, 0.08 + 0.1 * (1 - edge)


def t_obsidian():
    f1, f2, _ = voronoi(8, 181)
    ripple = 0.5 + 0.5 * np.sin(f1 * 60)
    h = 0.4 * ripple + 0.6 * fbm(6, 4, 182)
    return h, 0.85 + 0.15 * ripple, 0.06 + 0.08 * ripple


def t_bone():
    pores = 1 - norm01(voronoi(120, 191)[0]) ** 0.25
    grain = fbm(20, 3, 192, stretch=(1, 0.3))
    h = 0.5 * grain + 0.5 * (1 - pores * 0.5)
    return h, 0.8 + 0.2 * grain - 0.15 * pores, 0.55 + 0.2 * pores


def t_fungal():
    f1, _, _ = voronoi(40, 201)
    spots = np.clip(1 - f1 * 30, 0, 1)
    gills = stripes(40, "x", 202, warp=0.15)
    noise = fbm(12, 4, 203)
    h = 0.4 * noise + 0.35 * gills + 0.25 * spots
    return h, 0.7 + 0.2 * noise + 0.1 * spots, 0.75


def t_moss():
    tuft = fbm(24, 4, 211)
    clumps = fbm(4, 3, 212)
    h = 0.6 * tuft + 0.4 * clumps
    return h, 0.55 + 0.45 * h, 1.0


def t_leaf():
    yy, xx = np.mgrid[0:N, 0:N] / N
    midrib = np.clip(1 - np.abs(((xx * 2) % 1.0) - 0.5) * 30, 0, 1)
    veins = np.clip(1 - np.abs(np.sin(2 * np.pi * (yy * 8 + np.abs(((xx * 2) % 1.0) - 0.5) * 3))) * 6, 0, 1)
    cells = fbm(48, 2, 221)
    h = 0.4 * midrib + 0.3 * veins + 0.3 * cells
    return h, 0.75 + 0.25 * cells - 0.15 * veins, 0.6


def t_feather():
    yy, xx = np.mgrid[0:N, 0:N] / N
    barbs = 0.5 + 0.5 * np.sin(2 * np.pi * (yy * 40 + np.abs(((xx * 4) % 1.0) - 0.5) * 18))
    rachis = np.clip(1 - np.abs(((xx * 4) % 1.0) - 0.5) * 40, 0, 1)
    h = 0.7 * barbs * (1 - rachis) + 0.3 * rachis
    return h, 0.75 + 0.25 * barbs, 0.6


def t_plaster():
    lumps = fbm(6, 5, 231)
    fine = fbm(64, 2, 232)
    cracks = np.clip((voronoi(10, 233)[1] - voronoi(10, 233)[0]) * 60, 0, 1)
    h = 0.6 * lumps + 0.25 * fine + 0.15 * cracks
    return h, (0.85 + 0.15 * lumps) * (0.8 + 0.2 * cracks), 0.95


def t_ground():
    dirt = fbm(5, 6, 241)
    pebbles = np.clip(1 - voronoi(90, 242)[0] * 50, 0, 1)
    grass = np.clip(fbm(40, 3, 243, stretch=(1, 0.3)) * 1.6 - 0.6, 0, 1)
    h = 0.5 * dirt + 0.3 * pebbles + 0.2 * grass
    return h, 0.6 + 0.4 * dirt + 0.15 * pebbles, 0.95


TEXTURES = {
    "wood": ("Madeira", t_wood), "planks": ("Tábuas", t_planks), "bark": ("Casca de árvore", t_bark),
    "leather": ("Couro", t_leather), "cloth": ("Tecido trançado", t_cloth), "linen": ("Linho", t_linen),
    "fur": ("Pelagem", t_fur), "hair": ("Cabelo", t_hair), "skin": ("Pele", t_skin), "scales": ("Escamas", t_scales),
    "chainmail": ("Cota de malha", t_chainmail), "metal_brushed": ("Metal escovado", t_metal_brushed),
    "metal_hammered": ("Metal batido", t_metal_hammered), "stone": ("Rocha", t_stone),
    "cobblestone": ("Calçamento", t_cobblestone), "stone_blocks": ("Blocos de pedra", t_stone_blocks),
    "roof_tiles": ("Telhas", t_roof_tiles), "marble": ("Mármore", t_marble), "crystal": ("Cristal", t_crystal),
    "obsidian": ("Obsidiana", t_obsidian), "bone": ("Osso", t_bone), "fungal": ("Fungo", t_fungal),
    "moss": ("Musgo", t_moss), "leaf": ("Folha", t_leaf), "feather": ("Pena", t_feather),
    "plaster": ("Reboco", t_plaster), "ground": ("Terra batida", t_ground),
}

# Força do relevo por material
NORMAL_STRENGTH = {"marble": 1.0, "crystal": 2.0, "obsidian": 1.5, "skin": 0.0, "metal_brushed": 1.5,
                   "linen": 2.5, "hair": 2.5, "leather": 2.0, "stone": 3.0, "fur": 2.5}


def to_normal(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    s = strength * N / 64
    nx, ny, nz = -dx * s, dy * s, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / ln, ny / ln, nz / ln], axis=-1) * 0.5 + 0.5
    return (rgb * 255).astype(np.uint8)


def ao_from_height(h):
    blur = h.copy()
    for _ in range(4):
        blur = (blur + np.roll(blur, 1, 0) + np.roll(blur, -1, 0) + np.roll(blur, 1, 1) + np.roll(blur, -1, 1)) / 5
    return np.clip(1 - np.clip(blur - h, 0, 1) * 3, 0.55, 1)


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for key, (label, fn) in TEXTURES.items():
        h, col, rough = fn()
        h = norm01(h)
        col = np.clip(np.broadcast_to(col, (N, N)), 0, 1)
        rough = np.clip(np.broadcast_to(rough, (N, N)), 0.03, 1)
        albedo = (np.stack([col] * 3, axis=-1) * 255).astype(np.uint8)
        strength = NORMAL_STRENGTH.get(key, 3.0)
        normal = to_normal(h, strength)
        ao = ao_from_height(h) if strength > 0 else np.ones_like(h)
        # Aspereza normalizada para 70–100%: o material mantém sua aspereza média e ganha variação
        rough_map = 0.7 + 0.3 * norm01(rough) if np.ptp(rough) > 1e-6 else np.ones_like(rough)
        orm = np.stack([ao, rough_map, np.ones_like(rough)], axis=-1)
        Image.fromarray(albedo, "RGB").save(os.path.join(OUT, key + "_albedo.png"), optimize=True)
        Image.fromarray(normal, "RGB").save(os.path.join(OUT, key + "_normal.png"), optimize=True)
        Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, key + "_orm.png"), optimize=True)
        tiles.append((key, label, albedo, normal))
        print("  %-15s ok" % key)

    # Folha de contato: albedo iluminado pelo normal map (visual de relevo) + nome
    cols = 7
    cell = 168
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 40)), (11, 10, 20))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    light = np.array([-0.45, 0.55, 0.7])
    light = light / np.linalg.norm(light)
    for i, (key, label, albedo, normal) in enumerate(tiles):
        n = normal.astype(float) / 255 * 2 - 1
        shade = np.clip((n * light).sum(-1), 0, 1) * 0.75 + 0.35
        lit = np.clip(albedo.astype(float) * shade[..., None] * np.array([0.92, 0.88, 1.0]), 0, 255).astype(np.uint8)
        img = Image.fromarray(lit).resize((cell - 8, cell - 8))
        x, y = (i % cols) * cell, (i // cols) * (cell + 40)
        sheet.paste(img, (x + 4, y + 4))
        draw.text((x + 6, y + cell - 2), label, fill=(232, 228, 244), font=font)
        draw.text((x + 6, y + cell + 15), key, fill=(140, 134, 170), font=font)
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    sheet.save(SHEET, optimize=True)
    print("OK -> %d texturas em %s e folha %s" % (len(tiles), os.path.relpath(OUT, REPO), os.path.relpath(SHEET, REPO)))


if __name__ == "__main__":
    main()
