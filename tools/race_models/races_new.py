"""Raças 29-47 de Lunaria (docs/design/racas_propostas.md).

IDs iguais a server/internal/protocol/packets.go (RaceHalfCelestial=29 ... RaceWolfDemi=46, RaceManamancer=47).
A estatura (scale) segue _get_race_scale() do cliente.
"""

import math

from modelkit import Model, humanoid, fur_tufts, v_add, v_lerp
from races import _wing
from races_base import belt, crack_lines, eyes, hair_long, hair_short, hair_slick, pointed_ears, starter_clothes, tail


# ---------------------------------------------------------------------------
# Peças comuns
# ---------------------------------------------------------------------------

def _dressed(m, skin_col, w=1.0, iris_col="#3e6b8a", vest=True):
    skin = m.mat("skin", skin_col, rough=0.55)
    linen, leather, pants, boots, metal = starter_clothes(m)
    iris = m.mat("iris", iris_col, rough=0.3)
    white = m.mat("sclera", "#f4f1ec", rough=0.3)
    humanoid(m, skin, linen, pants, boots, w=w)
    eyes(m, iris, white)
    if vest:
        m.part("sphere", [0.2], (0, 1.3, -0.01), leather, scale=(1.22 * w, 1.2, 0.8))
    belt(m, leather, metal, w=w)
    return skin, leather, metal


def _horns(m, mat, points, radii):
    m.chain(points, radii, mat, mirror=True)


def _drago(m, scale_col, belly_col, horn_col, eye_col):
    """Base dracônica: escamas, chifres para trás, cauda e olhos fendidos."""
    scale = m.mat("scale_body", scale_col, rough=0.35, metal=0.3)
    belly = m.mat("scale_belly", belly_col, rough=0.5)
    horn = m.mat("horn", horn_col, rough=0.25, metal=0.2)
    eye = m.mat("eye_drago", eye_col, emit=eye_col, energy=5.0)
    leather = m.mat("leather", "#3e2c22", rough=0.8)
    humanoid(m, scale, belly, leather, scale, eye=eye, w=1.05)
    m.part("sphere", [0.134], (0, 1.75, 0.03), scale, scale=(1.04, 0.95, 1.08))
    m.part("box", [0.08, 0.04, 0.08], (0, 1.66, -0.12), scale)  # focinho curto
    _horns(m, horn, [(0.06, 1.82, 0.0), (0.09, 1.9, 0.1), (0.1, 1.9, 0.22), (0.09, 1.84, 0.3)],
           [0.028, 0.022, 0.012, 0.0])
    for i in range(3):
        m.part("box", [0.14, 0.03, 0.14], (0.3, 1.55 - i * 0.08, 0), scale, rot=(0, 0, -30 - i * 12),
               group="arm_r", mirror=True)
    for i in range(5):
        m.part("cylinder", [0.0, 0.03, 0.06], (0, 1.6 - i * 0.12, 0.17 + i * 0.01), horn, rot=(-70, 0, 0))
    tail(m, [(0, 0.95, 0.12), (0, 0.72, 0.38), (0.05, 0.42, 0.62), (0.12, 0.2, 0.9), (0.15, 0.12, 1.12)],
         [0.09, 0.075, 0.06, 0.04, 0.0], scale)
    return scale, horn


def _membrane_wing(m, side, mem, bone, group):
    root = (side * 0.1, 1.45, 0.16)
    elbow = (side * 0.45, 1.8, 0.34)
    tip = (side * 0.85, 1.9, 0.46)
    m.chain([root, elbow, tip], [0.025, 0.018, 0.006], bone, group=group)
    for i in range(4):
        t = (i + 1) / 4
        base = v_lerp(elbow, tip, t * 0.9)
        end = v_add(base, (side * 0.05, -0.55 + 0.1 * t, 0.05))
        m.chain([base, end], [0.01, 0.004], bone, group=group)
        m.plank(v_lerp(root, base, 0.5), v_lerp(base, end, 0.6), 0.32, 0.008, mem, group=group)


def _wing_group(m, name, side):
    return m.group(name, (side * 0.1, 1.45, 0.16),
                   anim={"type": "sway", "axis": [0, side, 0], "amp": 10.0, "speed": 1.4})


# ---------------------------------------------------------------------------
# 29-31 — Raças base
# ---------------------------------------------------------------------------

def orc():
    m = Model(36, "orc", "Orkhan", "Espadachim da Aurora das Estepes Cinzentas",
              "Corpo largo e musculoso de pele verde-musgo, presas inferiores salientes, cicatrizes de honra, "
              "trança guerreira e ombreira de osso.", "#558b2f", scale=1.08, seed=29)
    skin, leather, metal = _dressed(m, "#6b8e3d", w=1.15, iris_col="#c62828")
    hair = m.mat("hair", "#1b1b1b", rough=0.7)
    fang = m.mat("fang", "#f1e9d2", rough=0.4)
    bone = m.mat("bone_pauldron", "#e0d6bd", rough=0.6)
    scar = m.mat("scar", "#8a6d4e", rough=0.7)
    m.part("sphere", [0.06], (0, 1.86, 0.05), hair, scale=(0.6, 0.6, 1.6))
    m.chain([(0, 1.84, 0.12), (0, 1.7, 0.2), (0, 1.5, 0.22)], [0.03, 0.026, 0.018], hair)
    m.part("cylinder", [0.0, 0.012, 0.05], (0.035, 1.66, -0.11), fang, mirror=True)
    m.part("box", [0.012, 0.07, 0.01], (0.05, 1.73, -0.12), scar, rot=(0, 0, 20))
    m.part("sphere", [0.11], (0.3, 1.52, 0), bone, scale=(1.2, 0.7, 1.1), group="arm_r", mirror=True)
    for i in range(3):
        m.part("cylinder", [0.0, 0.02, 0.08], (0.3 + i * 0.04, 1.6, 0.02 - i * 0.03), bone, rot=(0, 0, -50),
               group="arm_r", mirror=True)
    m.light("#9ccc65", 0.25, 2.0, (0, 1.4, -0.7))
    return m


def goblin():
    m = Model(42, "goblin", "Gnarlin", "Trapaceiro das Cavernas",
              "Baixinho e magro, pele verde-limão, orelhas enormes e pontudas, nariz adunco, sorriso cheio de "
              "dentes e bolsas de bugigangas penduradas no cinto.", "#9ccc65", scale=0.75, seed=30)
    skin, leather, metal = _dressed(m, "#8bc34a", w=0.9, iris_col="#ffd600")
    pointed_ears(m, skin, length=0.22, up=-80)
    nose = m.mat("skin_nose", "#7cb342", rough=0.55)
    m.part("cylinder", [0.0, 0.025, 0.07], (0, 1.69, -0.14), nose, rot=(-80, 0, 0))
    pouch = m.mat("pouch", "#5d4037", rough=0.8)
    coin = m.mat("coin", "#ffca28", rough=0.3, metal=0.9)
    for x in (-0.15, 0.0, 0.15):
        m.part("sphere", [0.045], (x, 0.95, -0.16 if x == 0 else -0.12), pouch)
    m.part("cylinder", [0.02, 0.02, 0.006], (0.0, 0.99, -0.2), coin, rot=(90, 0, 0))
    hood = m.mat("hood", "#4e342e", rough=0.85)
    m.part("sphere", [0.14], (0, 1.76, 0.03), hood, scale=(1.05, 0.95, 1.1))
    m.light("#cddc39", 0.2, 1.8, (0, 1.3, -0.6))
    return m


def elfo():
    m = Model(38, "elfo", "Elarin", "Guardião das Florestas Antigas",
              "Esguio e elegante, orelhas longas e pontudas, cabelos longos loiro-claros, túnica verde-floresta "
              "e braçadeiras de couro gravadas com folhas.", "#81c784", scale=1.02, seed=31)
    skin, leather, metal = _dressed(m, "#f1d3b6", w=0.92, iris_col="#2e7d32", vest=False)
    hair = m.mat("hair", "#e8d79a", rough=0.5)
    tunic = m.mat("forest_green_tunic", "#2e5e32", rough=0.8)
    leaf = m.mat("leaf", "#66bb6a", rough=0.7)
    pointed_ears(m, skin, length=0.17)
    hair_long(m, hair, 0.6)
    m.part("sphere", [0.2], (0, 1.28, -0.01), tunic, scale=(1.12, 1.3, 0.8))
    m.part("cylinder", [0.2, 0.26, 0.4], (0, 0.82, 0), tunic)
    for side in (1, -1):
        m.part("box", [0.05, 0.02, 0.03], (side * 0.06, 1.86, -0.08), leaf, rot=(0, 0, side * 30))
    m.light("#a5d6a7", 0.25, 2.0, (0, 1.5, -0.7))
    return m


# ---------------------------------------------------------------------------
# 32-33 — Evoluções élficas
# ---------------------------------------------------------------------------

def elfo_solar():
    m = Model(39, "elfo_solar", "Solarin", "Bênção do Sol",
              "Elarin de cabelos de ouro, armadura branca e dourada com um disco solar no peito e um halo de "
              "raios atrás da cabeça.", "#ffca28", scale=1.05, seed=32)
    skin, leather, metal = _dressed(m, "#f3cfa6", w=0.95, iris_col="#ff8f00", vest=False)
    hair = m.mat("hair", "#ffd54f", rough=0.45)
    plate = m.mat("plate_white", "#f5f2e8", rough=0.3, metal=0.6)
    gold = m.mat("gold_trim", "#ffb300", rough=0.25, metal=0.9)
    sun = m.mat("sun_glow", "#fff176", emit="#ffab00", energy=4.0,
                anim={"type": "glow", "speed": 1.0, "min": 0.8, "max": 1.3})
    pointed_ears(m, skin, length=0.17)
    hair_long(m, hair, 0.55)
    m.part("sphere", [0.2], (0, 1.3, -0.01), plate, scale=(1.22, 1.22, 0.82))
    m.part("cylinder", [0.06, 0.06, 0.02], (0, 1.34, -0.17), sun, rot=(90, 0, 0))
    m.part("torus", [0.06, 0.075], (0, 1.34, -0.17), gold, rot=(90, 0, 0))
    m.part("sphere", [0.1], (0.3, 1.52, 0), plate, scale=(1.2, 0.8, 1.1), group="arm_r", mirror=True)
    g = m.group("halo", (0, 1.78, 0.2), anim={"type": "spin", "axis": [0, 0, 1], "speed": 20.0})
    for i in range(12):
        a = math.radians(i * 30)
        m.plank((math.cos(a) * 0.14, 1.78 + math.sin(a) * 0.14, 0.2),
                (math.cos(a) * 0.26, 1.78 + math.sin(a) * 0.26, 0.2), 0.03, 0.01, sun, group=g)
    m.light("#ffca28", 0.6, 2.5, (0, 1.6, -0.5))
    return m


def elfo_lunar():
    m = Model(40, "elfo_lunar", "Lunarin", "Bênção da Lua",
              "Elarin de pele pálida e cabelos prateados, manto azul-noite com crescentes bordados e um "
              "diadema de lua crescente na testa.", "#90caf9", scale=1.03, seed=33)
    skin, leather, metal = _dressed(m, "#e3e8f0", w=0.9, iris_col="#90caf9", vest=False)
    hair = m.mat("hair", "#dfe6ee", rough=0.4)
    cloak = m.mat("night_robe", "#1a237e", rough=0.75)
    silver = m.mat("silver_trim", "#cfd8dc", rough=0.2, metal=0.95)
    moon = m.mat("moon_glow", "#e3f2fd", emit="#90caf9", energy=3.0)
    pointed_ears(m, skin, length=0.18)
    hair_long(m, hair, 0.7)
    m.part("sphere", [0.2], (0, 1.3, 0.0), cloak, scale=(1.18, 1.25, 0.82))
    m.part("cylinder", [0.24, 0.36, 0.95], (0, 0.75, 0.02), cloak)
    m.part("torus", [0.04, 0.05], (0, 1.82, -0.11), moon, rot=(90, 0, 0), scale=(1, 1, 1))
    m.part("box", [0.03, 0.03, 0.02], (0.015, 1.83, -0.13), cloak)
    m.part("torus", [0.13, 0.14], (0, 1.79, 0.0), silver, rot=(-12, 0, 0))
    m.light("#90caf9", 0.4, 2.2, (0, 1.6, -0.6))
    return m


# ---------------------------------------------------------------------------
# 34-37 — Dragos (secretos)
# ---------------------------------------------------------------------------

def drago_terra():
    m = Model(32, "drago_terra", "Terravyrn", "Escamas de Rocha",
              "Dracônico atarracado de escamas marrom-terra que viram placas de pedra nos ombros, chifres "
              "grossos e cristais de âmbar brotando das costas.", "#8d6e63", scale=1.1, seed=34)
    scale, horn = _drago(m, "#6d4c41", "#bcaaa4", "#4e342e", "#ffb300")
    rock = m.mat("rock_plate", "#795548", rough=0.95)
    amber = m.mat("crystal_amber", "#ffb300", rough=0.15, emit="#ff8f00", energy=1.0)
    for i in range(4):
        m.part("box", [0.2, 0.08, 0.2], (0.32, 1.58 - i * 0.05, 0.0), rock, rot=(10, 0, -20 - i * 8),
               group="arm_r", mirror=True)
    for x, y in ((0.08, 1.45), (-0.06, 1.3), (0.04, 1.15)):
        m.part("cylinder", [0.0, 0.04, 0.14], (x, y, 0.2), amber, rot=(-60, 0, x * 100))
    m.light("#ffb300", 0.3, 2.0, (0, 1.4, -0.7))
    return m


def drago_agua():
    m = Model(33, "drago_agua", "Hydravyrn", "Fluxo das Marés",
              "Dracônico esguio de escamas azul-turquesa, barbatanas translúcidas nos braços e na cabeça e "
              "gotas de água flutuando em volta.", "#29b6f6", scale=1.02, seed=35)
    _drago(m, "#0288d1", "#b3e5fc", "#e1f5fe", "#00e5ff")
    fin = m.mat("fin", "#4fc3f7", rough=0.2, alpha=0.7, double=True)
    drop = m.mat("water_drop", "#b3e5fc", emit="#29b6f6", energy=2.0, alpha=0.6)
    m.plank((0.3, 1.45, 0.05), (0.34, 1.05, 0.12), 0.1, 0.01, fin, group="arm_r", mirror=True)
    m.plank((0, 1.84, 0.05), (0, 1.75, 0.25), 0.1, 0.01, fin)
    g = m.group("drops", (0, 1.2, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 40.0})
    for i in range(6):
        a = math.radians(i * 60)
        m.part("sphere", [0.025], (math.cos(a) * 0.45, 1.2 + 0.1 * math.sin(a * 2), math.sin(a) * 0.45), drop, group=g)
    m.light("#29b6f6", 0.45, 2.2, (0, 1.4, -0.7))
    return m


def drago_raio():
    m = Model(34, "drago_raio", "Fulgravyrn", "Carga Estática",
              "Dracônico ágil de escamas amarelo-elétrico e preto, chifres em zigue-zague e arcos de "
              "eletricidade saltando entre os espinhos.", "#ffee58", scale=1.0, seed=36)
    _drago(m, "#f9a825", "#212121", "#212121", "#fff176")
    bolt = m.mat("spark", "#fffde7", emit="#ffee58", energy=6.0, anim={"type": "flicker", "speed": 9.0, "min": 0.6, "max": 1.0})
    for side in (1, -1):
        pts = [(side * 0.08, 1.85, 0.0), (side * 0.14, 1.95, 0.05), (side * 0.1, 2.02, 0.1), (side * 0.16, 2.1, 0.12)]
        for a, b in zip(pts, pts[1:]):
            m.plank(a, b, 0.015, 0.01, bolt)
    for i in range(4):
        y = 1.55 - i * 0.14
        m.plank((0.0, y, 0.24), (0.06 * (1 if i % 2 else -1), y - 0.07, 0.28), 0.012, 0.008, bolt)
    m.light("#ffee58", 0.6, 2.4, (0, 1.6, -0.5))
    return m


def drago_mistico():
    m = Model(35, "drago_mistico", "Arcavyrn", "Sangue Arcano",
              "Dracônico de escamas violeta com runas luminosas, chifres de cristal e três orbes arcanos "
              "girando em volta do corpo.", "#ab47bc", scale=1.0, seed=37)
    _drago(m, "#6a1b9a", "#ce93d8", "#e1bee7", "#ea80fc")
    rune = m.mat("rune_glow", "#f3e5f5", emit="#e040fb", energy=3.5)
    orb = m.mat("orb_arcane", "#e1bee7", emit="#d500f9", energy=5.0)
    crack_lines(m, rune, m.rng, 8, box=((-0.18, 0.18), (1.05, 1.5)), z=-0.152, w=0.008)
    g = m.group("orbs", (0, 1.3, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 60.0})
    for i in range(3):
        a = math.radians(i * 120)
        m.part("sphere", [0.05], (math.cos(a) * 0.5, 1.4, math.sin(a) * 0.5), orb, group=g)
    m.light("#d500f9", 0.6, 2.4, (0, 1.4, -0.6))
    return m


# ---------------------------------------------------------------------------
# 38 — Pyrael
# ---------------------------------------------------------------------------

def pyromante():
    m = Model(30, "pyromante", "Pyrael", "Pacto da Chama",
              "Humano de pele morena rachada por veios de brasa, cabelo como labaredas, manto carmesim "
              "chamuscado e chamas dançando nas mãos.", "#ff5722", scale=1.0, seed=38)
    skin, leather, metal = _dressed(m, "#a1775a", w=1.0, iris_col="#ff6d00", vest=False)
    ember = m.mat("ember", "#ffab40", emit="#ff3d00", energy=3.0, anim={"type": "flicker", "speed": 6.0, "min": 0.6, "max": 1.0})
    flame = m.mat("flame", "#ffd180", emit="#ff6d00", energy=5.0, alpha=0.8,
                  anim={"type": "flicker", "speed": 8.0, "min": 0.6, "max": 1.0})
    robe = m.mat("crimson_robe", "#8e1b10", rough=0.8)
    m.part("sphere", [0.2], (0, 1.3, 0.0), robe, scale=(1.2, 1.25, 0.82))
    m.part("cylinder", [0.22, 0.34, 0.8], (0, 0.8, 0.02), robe)
    crack_lines(m, ember, m.rng, 6, box=((-0.07, 0.07), (1.64, 1.78)), z=-0.12, w=0.005)
    for i in range(6):
        a = math.radians(i * 60)
        m.part("cylinder", [0.0, 0.04, 0.16], (math.cos(a) * 0.07, 1.86, math.sin(a) * 0.07 + 0.02), flame,
               rot=(math.sin(a) * 20, 0, -math.cos(a) * 20))
    for side, arm in ((1, "arm_r"), (-1, "arm_l")):
        m.part("sphere", [0.06], (side * 0.32, 0.86, -0.17), flame, group=arm)
    m.light("#ff6d00", 0.8, 2.6, (0, 1.2, -0.6))
    return m


# ---------------------------------------------------------------------------
# 39-45 — Demi-humanos e linhagens novas
# ---------------------------------------------------------------------------

def escorpiao():
    m = Model(43, "escorpiao", "Escarion", "Carapaça do Deserto",
              "Demi-humano de carapaça âmbar segmentada sobre o tronco e os braços, olhos múltiplos e uma "
              "cauda articulada que se curva sobre a cabeça com um ferrão venenoso.", "#bf8f00", scale=1.02, seed=39)
    skin, leather, metal = _dressed(m, "#c8a272", w=1.0, iris_col="#1b1b1b", vest=False)
    chitin = m.mat("chitin_amber", "#a87000", rough=0.25, metal=0.3)
    venom = m.mat("venom", "#76ff03", emit="#64dd17", energy=4.0)
    for i in range(5):
        m.part("box", [0.4 - i * 0.03, 0.06, 0.3], (0, 1.48 - i * 0.09, 0.0), chitin)
    m.part("sphere", [0.1], (0.3, 1.52, 0), chitin, scale=(1.2, 0.8, 1.1), group="arm_r", mirror=True)
    pts = [(0, 1.0, 0.15), (0, 1.2, 0.4), (0, 1.55, 0.55), (0, 1.9, 0.45), (0, 2.05, 0.2), (0, 1.98, 0.02)]
    last = tail(m, pts, [0.07, 0.065, 0.06, 0.05, 0.04, 0.03], chitin, amp=4.0)
    m.part("cylinder", [0.0, 0.03, 0.12], (0, 1.92, -0.04), venom, rot=(150, 0, 0), group=last)
    m.light("#ffb300", 0.3, 2.0, (0, 1.4, -0.7))
    return m


def tartaruga():
    m = Model(44, "tartaruga", "Testudar", "Casco Ancestral",
              "Demi-humano robusto e baixo, pele verde-oliva, casco hexagonal enorme nas costas, plastrão "
              "no peito e olhar sereno de quem já viu séculos.", "#2e7d32", scale=1.35, seed=40)
    skin = m.mat("skin", "#7a8f4a", rough=0.7)
    shell = m.mat("shell_bone", "#5d4a2e", rough=0.6)
    plastron = m.mat("plastron_bone", "#d7c58f", rough=0.6)
    leather = m.mat("leather", "#4e3b2a", rough=0.85)
    iris = m.mat("iris", "#3e2723", rough=0.3)
    humanoid(m, skin, plastron, leather, skin, w=1.2)
    eyes(m, iris, None)
    m.part("sphere", [0.36], (0, 1.25, 0.18), shell, scale=(1.05, 1.15, 0.6))
    for i in range(7):
        a = math.radians(i * 60)
        r = 0 if i == 6 else 0.17
        m.part("cylinder", [0.08, 0.08, 0.03], (math.cos(a) * r, 1.28 + math.sin(a) * r, 0.39), plastron,
               rot=(90, 0, 0), scale=(1, 1, 1))
    for i in range(3):
        m.part("box", [0.24, 0.015, 0.02], (0, 1.18 + i * 0.1, -0.16), shell)
    m.light("#a5d6a7", 0.2, 1.8, (0, 1.4, -0.7))
    return m


def fadinha():
    m = Model(41, "fadinha", "Faelith", "Asas de Cristal",
              "Pequenina e brilhante, cabelos rosa em coque, vestido de pétalas, orelhas pontudas e quatro "
              "asas de cristal translúcido que soltam pó cintilante.", "#f48fb1", scale=0.55, seed=41)
    skin = m.mat("skin", "#ffe0d0", rough=0.5)
    dress = m.mat("petal_cloth", "#f8bbd0", rough=0.7)
    hair = m.mat("hair", "#f06292", rough=0.45)
    iris = m.mat("iris", "#7b1fa2", rough=0.3)
    white = m.mat("sclera", "#ffffff", rough=0.3)
    wing = m.mat("wing_crystal", "#e1f5fe", emit="#f8bbd0", energy=1.2, alpha=0.45, double=True)
    dust = m.mat("dust", "#fff9c4", emit="#ffeb3b", energy=5.0, anim={"type": "flicker", "speed": 5.0, "min": 0.6, "max": 1.0})
    humanoid(m, skin, dress, dress, skin, w=0.85)
    eyes(m, iris, white, r=0.024)
    pointed_ears(m, skin, length=0.12)
    hair_short(m, hair)
    m.part("sphere", [0.07], (0, 1.9, 0.06), hair)
    m.part("cylinder", [0.14, 0.32, 0.4], (0, 0.88, 0), dress)
    for k, (side, y, up) in enumerate(((1, 1.5, 1), (-1, 1.5, 1), (1, 1.3, -1), (-1, 1.3, -1))):
        g = m.group("fairywing%d" % k, (side * 0.06, y, 0.16),
                    anim={"type": "sway", "axis": [0, side, 0], "amp": 25.0, "speed": 6.0, "phase": k})
        m.plank((side * 0.06, y, 0.16), (side * 0.5, y + up * 0.3, 0.3), 0.22, 0.006, wing, group=g)
    for i in range(6):
        m.part("sphere", [0.012], (m.rng.uniform(-0.4, 0.4), m.rng.uniform(0.8, 1.7), 0.3), dust)
    m.light("#f48fb1", 0.5, 2.0, (0, 1.4, 0.3))
    return m


def meio_celestial():
    m = Model(29, "meio_celestial", "Aurelith", "Graça Celeste",
              "Filho de anjo e mortal: pele clara com leve brilho, cabelos brancos, túnica branca com "
              "bordas douradas, halo tênue e asas de penas brancas.", "#fff59d", scale=1.04, seed=42)
    skin, leather, metal = _dressed(m, "#f6e3d0", w=0.96, iris_col="#ffca28", vest=False)
    hair = m.mat("hair", "#f5f5f5", rough=0.45)
    tunic = m.mat("white_robe", "#fafafa", rough=0.7)
    gold = m.mat("gold_trim", "#ffd54f", rough=0.25, metal=0.9)
    feather = m.mat("feather_white", "#ffffff", rough=0.8)
    bone = m.mat("wing_bone", "#eeeeee", rough=0.6)
    halo = m.mat("halo_glow", "#fffde7", emit="#ffd600", energy=5.0)
    hair_slick(m, hair)
    m.part("sphere", [0.2], (0, 1.3, 0.0), tunic, scale=(1.18, 1.25, 0.82))
    m.part("cylinder", [0.22, 0.32, 0.6], (0, 0.85, 0), tunic)
    m.part("torus", [0.2, 0.215], (0, 1.0, 0), gold, scale=(1.05, 1, 0.8))
    m.part("torus", [0.1, 0.115], (0, 2.0, 0.05), halo, rot=(80, 0, 0))
    for side in (1, -1):
        _wing(m, side, feather, bone, _wing_group(m, "wing_%s" % ("r" if side > 0 else "l"), side))
    m.light("#fff59d", 0.6, 2.5, (0, 1.7, 0.3))
    return m


def gigante_gelo():
    m = Model(31, "gigante_gelo", "Jotunar", "Sangue Glacial",
              "Colosso de pele azul-pálida, barba e cabelos de gelo, ombreiras de pele de urso branco e "
              "cristais de gelo crescendo nos ombros e antebraços.", "#b3e5fc", scale=1.45, seed=43)
    skin = m.mat("skin", "#a7c4d6", rough=0.6)
    fur = m.mat("fur_white", "#eceff1", rough=1.0)
    beard = m.mat("beard_ice", "#e1f5fe", rough=0.4)
    leather = m.mat("leather", "#455a64", rough=0.85)
    ice = m.mat("crystal_ice", "#b3e5fc", rough=0.05, emit="#4fc3f7", energy=1.0, alpha=0.85)
    eye = m.mat("eye_frost", "#e1f5fe", emit="#40c4ff", energy=5.0)
    humanoid(m, skin, leather, leather, fur, eye=eye, w=1.25)
    m.part("sphere", [0.134], (0, 1.76, 0.03), beard, scale=(1.05, 0.9, 1.05))
    m.part("cylinder", [0.09, 0.02, 0.22], (0, 1.55, -0.08), beard, rot=(10, 0, 0))
    for side in (1, -1):
        m.part("sphere", [0.14], (side * 0.32, 1.5, 0), fur, scale=(1.3, 0.8, 1.2), group="arm_r" if side > 0 else "arm_l")
    fur_tufts(m, (0, 1.5, 0), (0.4, 0.1, 0.2), 30, fur, length=0.06)
    for i in range(4):
        m.part("cylinder", [0.0, 0.04, 0.18], (0.3 + i * 0.03, 1.62, 0.05 - i * 0.04), ice, rot=(-20, 0, -30),
               group="arm_r", mirror=True)
        m.part("cylinder", [0.0, 0.03, 0.12], (0.34, 1.1 - i * 0.06, 0.04), ice, rot=(0, 0, -70),
               group="arm_r", mirror=True)
    m.light("#40c4ff", 0.4, 2.4, (0, 1.6, -0.7))
    return m


def sucubo():
    m = Model(45, "sucubo", "Lilitara", "Encanto Infernal",
              "Meio-demônio de pele lavanda, chifres curvos negros, cabelos vinho longos, asas de morcego e "
              "uma cauda fina terminada em ponta de coração.", "#d81b60", scale=1.0, seed=44)
    skin, leather, metal = _dressed(m, "#c9a3c9", w=0.92, iris_col="#ff1744", vest=False)
    hair = m.mat("hair", "#6a0f2a", rough=0.45)
    horn = m.mat("horn_black", "#1a1014", rough=0.2, metal=0.3)
    mem = m.mat("membrane", "#4a148c", rough=0.6, double=True)
    bone = m.mat("wing_bone", "#2a1a2e", rough=0.5)
    corset = m.mat("velvet_corset", "#880e4f", rough=0.6)
    heart = m.mat("heart_glow", "#ff4081", emit="#ff1744", energy=3.0)
    hair_long(m, hair, 0.65)
    m.part("sphere", [0.2], (0, 1.28, 0.0), corset, scale=(1.1, 1.2, 0.8))
    _horns(m, horn, [(0.06, 1.83, -0.02), (0.11, 1.9, 0.02), (0.15, 1.88, 0.1), (0.13, 1.8, 0.14)],
           [0.024, 0.018, 0.01, 0.0])
    for side in (1, -1):
        _membrane_wing(m, side, mem, bone, _wing_group(m, "wing_%s" % ("r" if side > 0 else "l"), side))
    last = tail(m, [(0, 0.98, 0.12), (0, 0.75, 0.35), (0.08, 0.5, 0.5), (0.15, 0.35, 0.68)],
                [0.022, 0.02, 0.016, 0.012], skin)
    m.part("sphere", [0.04], (0.15, 0.35, 0.7), heart, scale=(1, 1, 0.4), group=last)
    m.light("#ff4081", 0.45, 2.2, (0, 1.4, -0.6))
    return m


def manamante():
    m = Model(47, "manamante", "Manamante", "Sangue Azul",
              "Humano de pele pálida com veias azuis luminosas, olhos de mana pura, robe azul-cobalto com "
              "runas e um cristal-coração pulsando no peito.", "#3d5afe", scale=1.0, seed=45)
    skin = m.mat("skin", "#e8e4f0", rough=0.5)
    linen, leather, pants, boots, metal = starter_clothes(m)
    eye = m.mat("eye_mana", "#e3f2fd", emit="#2979ff", energy=6.0)
    vein = m.mat("mana_vein", "#82b1ff", emit="#2962ff", energy=3.0)
    robe = m.mat("cobalt_robe", "#1a2a80", rough=0.75)
    heart = m.mat("mana_heart", "#bbdefb", emit="#2979ff", energy=6.0,
                  anim={"type": "glow", "speed": 1.6, "min": 0.6, "max": 1.4})
    hair = m.mat("hair", "#0d1b4a", rough=0.5)
    humanoid(m, skin, robe, pants, boots, eye=eye, w=0.95)
    hair_short(m, hair)
    m.part("sphere", [0.2], (0, 1.3, 0.0), robe, scale=(1.18, 1.25, 0.82))
    m.part("cylinder", [0.22, 0.36, 0.85], (0, 0.78, 0.02), robe)
    m.part("prism", [0.07, 0.1, 0.05], (0, 1.34, -0.17), heart)
    crack_lines(m, vein, m.rng, 5, box=((-0.07, 0.07), (1.64, 1.78)), z=-0.12, w=0.004)
    for side, arm in ((1, "arm_r"), (-1, "arm_l")):
        for i in range(3):
            m.part("box", [0.006, 0.08, 0.006], (side * (0.31 + i * 0.01), 1.1 - i * 0.07, -0.08), vein, group=arm)
    m.light("#2979ff", 0.6, 2.4, (0, 1.4, -0.6))
    return m


def anao():
    m = Model(37, "anao", "Dvergar", "Resistência da Montanha",
              "Baixo e largo, barba ruiva longa e trançada com anéis de bronze, avental de couro de forja, "
              "braços grossos marcados por fuligem e um elmo de ferro com abas.", "#d7ccc8", scale=0.82, seed=37)
    skin, leather, metal = _dressed(m, "#d9a98a", w=1.2, iris_col="#5d4037")
    beard = m.mat("beard", "#b5542a", rough=0.8)
    bronze = m.mat("bronze_ring", "#c58b3a", rough=0.3, metal=0.9)
    iron = m.mat("iron_helm", "#6d7378", rough=0.4, metal=0.85)
    apron = m.mat("apron", "#5a3d2b", rough=0.85)
    m.part("sphere", [0.138], (0, 1.78, 0.02), iron, scale=(1.05, 0.75, 1.05))
    m.part("torus", [0.13, 0.15], (0, 1.74, 0.02), iron, scale=(1, 1, 1))
    m.part("sphere", [0.11], (0, 1.6, -0.08), beard, scale=(1.1, 1.0, 0.7))
    for x in (-0.04, 0.04):
        m.chain([(x, 1.55, -0.12), (x, 1.38, -0.14), (x * 0.8, 1.22, -0.13)], [0.035, 0.03, 0.02], beard)
        m.part("torus", [0.025, 0.035], (x, 1.38, -0.14), bronze, rot=(90, 0, 0))
    m.part("box", [0.34, 0.6, 0.02], (0, 1.05, -0.2), apron)
    m.light("#ff8a50", 0.25, 2.0, (0, 1.4, -0.7))
    return m


def lobo():
    m = Model(46, "lobo", "Ulvar", "Olfato & Instinto",
              "Demi-humano de pelagem cinza, orelhas de lobo eretas, focinho curto, olhos prateados, cauda "
              "espessa e armadura leve de couro com dentes de lobo pendurados.", "#78909c", scale=1.02, seed=46)
    skin = m.mat("skin", "#b9a18a", rough=0.6)
    fur = m.mat("fur", "#78909c", rough=1.0)
    leather = m.mat("leather", "#3e3a36", rough=0.8)
    fang = m.mat("fang", "#f5f0e6", rough=0.4)
    eye = m.mat("eye_silver", "#eceff1", emit="#b0bec5", energy=4.0)
    humanoid(m, skin, leather, leather, leather, eye=eye, w=1.05)
    m.part("sphere", [0.135], (0, 1.75, 0.025), fur, scale=(1.04, 0.95, 1.06))
    m.part("box", [0.08, 0.06, 0.1], (0, 1.67, -0.13), fur)
    m.part("sphere", [0.018], (0, 1.68, -0.185), leather)
    m.part("cylinder", [0.0, 0.05, 0.14], (0.08, 1.9, 0.02), fur, rot=(-5, 0, -15), scale=(1, 1, 0.5), mirror=True)
    m.part("sphere", [0.2], (0, 1.3, -0.01), leather, scale=(1.22, 1.2, 0.8))
    for i in range(4):
        m.part("cylinder", [0.0, 0.012, 0.05], (-0.09 + i * 0.06, 1.42, -0.17), fang, rot=(180, 0, 0))
    last = tail(m, [(0, 0.98, 0.12), (0, 0.82, 0.3), (0.04, 0.62, 0.46), (0.08, 0.48, 0.62)],
                [0.06, 0.07, 0.06, 0.04], fur)
    fur_tufts(m, (0.04, 0.7, 0.4), (0.06, 0.1, 0.1), 22, fur, group="tail1", length=0.05, bias=(0, -0.3, 0.6))
    fur_tufts(m, (0, 1.5, 0.05), (0.2, 0.08, 0.15), 24, fur, length=0.05)
    m.light("#b0bec5", 0.3, 2.0, (0, 1.6, -0.7))
    return m


ALL_NEW = [anao, lobo, orc, goblin, elfo, elfo_solar, elfo_lunar, drago_terra, drago_agua, drago_raio, drago_mistico,
           pyromante, escorpiao, tartaruga, fadinha, meio_celestial, gigante_gelo, sucubo, manamante]
