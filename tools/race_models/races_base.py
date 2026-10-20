"""Raças 1-18 de Lunaria: as 4 raças base, suas evoluções e as raças secretas.

Descrições seguem o Guia de Direção de Arte (Art Bible) do projeto.
"""

import math

from modelkit import Model, humanoid, fur_tufts, v_add, v_lerp


# ---------------------------------------------------------------------------
# Peças reutilizáveis
# ---------------------------------------------------------------------------

def eyes(m, iris, sclera=None, r=0.019, y=1.72, x=0.045):
    if sclera:
        m.part("sphere", [r], (x, y, -0.11), sclera, mirror=True)
        m.part("sphere", [r * 0.55], (x, y, -0.126), iris, mirror=True)
    else:
        m.part("sphere", [r], (x, y, -0.112), iris, mirror=True)


def hair_short(m, mat):
    m.part("sphere", [0.133], (0, 1.75, 0.02), mat, scale=(1.03, 0.92, 1.04))
    m.part("sphere", [0.06], (0.07, 1.82, -0.07), mat, scale=(1.4, 0.6, 1.0), mirror=True)


def hair_long(m, mat, length=0.55):
    m.part("sphere", [0.134], (0, 1.745, 0.025), mat, scale=(1.04, 1.03, 1.04))
    m.part("capsule", [0.1, length], (0, 1.75 - length / 2, 0.11), mat, scale=(1.25, 1, 0.45))
    m.part("capsule", [0.032, 0.3], (0.1, 1.6, -0.03), mat, rot=(0, 0, -6), mirror=True)


def hair_slick(m, mat):
    m.part("sphere", [0.133], (0, 1.75, 0.03), mat, scale=(1.03, 0.95, 1.06))
    m.part("prism", [0.12, 0.08, 0.06], (0, 1.84, -0.1), mat, rot=(-60, 0, 0))


def pointed_ears(m, mat, length=0.13, back=0.0, up=-68):
    m.part("cylinder", [0.0, 0.026, length], (0.13 + length * 0.1, 1.735, 0.01 + back * 0.4), mat,
           rot=(back * 120, 0, up), mirror=True)


def belt(m, strap, buckle, y=1.02, w=1.0):
    m.part("torus", [0.18 * w, 0.205 * w], (0, y, 0), strap, scale=(1.05, 1, 0.8))
    m.part("box", [0.06, 0.05, 0.025], (0, y, -0.165), buckle)


def tail(m, points, radii, mat, tip=None, amp=7.0):
    parent = None
    for i in range(len(points) - 1):
        g = m.group("tail%d" % i, points[i], parent,
                    anim={"type": "sway", "axis": [0, 1, 0], "amp": amp + 3 * i, "speed": 1.6, "phase": i * 0.8})
        m.seg(points[i], points[i + 1], radii[i], radii[i + 1], mat, group=g)
        m.part("sphere", [radii[i]], points[i], mat, group=g)
        parent = g
    if tip:
        m.part("sphere", [max(radii[-2] * 0.9, 0.02)], points[-1], tip, group=parent)
    return parent


def crack_lines(m, mat, rng, n, box=((-0.18, 0.18), (1.05, 1.5)), z=-0.152, group=None, w=0.012):
    for _ in range(n):
        x = rng.uniform(*box[0])
        y = rng.uniform(*box[1])
        m.part("box", [w, rng.uniform(0.05, 0.14), 0.012], (x, y, z), mat,
               rot=(0, 0, rng.uniform(-40, 40)), group=group)


def starter_clothes(m, w=1.0):
    """Vestes iniciais: camisa de linho, colete de couro e metal escovado."""
    linen = m.mat("linen", "#cdbb98", rough=0.9)
    leather = m.mat("leather", "#6b4a32", rough=0.75)
    pants = m.mat("pants", "#4f3e30", rough=0.85)
    boots = m.mat("boots", "#33251b", rough=0.7)
    metal = m.mat("brushed_metal", "#a8adb3", rough=0.35, metal=0.85)
    return linen, leather, pants, boots, metal


# ---------------------------------------------------------------------------
# 1 / 11 / 12 — Valeriano e evoluções
# ---------------------------------------------------------------------------

def _valeriano(m, hair_col="#4e342e"):
    skin = m.mat("skin", "#e0b48f", rough=0.55)
    linen, leather, pants, boots, metal = starter_clothes(m)
    hair = m.mat("hair", hair_col, rough=0.6)
    iris = m.mat("iris", "#3e6b8a", rough=0.3)
    white = m.mat("sclera", "#f4f1ec", rough=0.3)
    humanoid(m, skin, linen, pants, boots, w=1.0)
    eyes(m, iris, white)
    hair_short(m, hair)
    m.part("sphere", [0.2], (0, 1.3, -0.01), leather, scale=(1.22, 1.2, 0.8))
    m.part("box", [0.02, 0.3, 0.02], (0.06, 1.3, -0.166), metal, mirror=True)
    belt(m, leather, metal)
    m.part("cylinder", [0.062, 0.062, 0.09], (0.3, 0.98, -0.1), leather, rot=(30, 0, 6), group="arm_r", mirror=True)
    return skin, hair


def valeriano():
    m = Model(1, "valeriano", "Valeriano", "Humano das Terras do Refúgio",
              "Proporções atléticas clássicas e pele em tons humanos variados. Os Valerianos começam a jornada "
              "com vestes simples de linho, couro e metal escovado — e a coragem de quem nasceu entre muralhas.",
              "#ffd700", scale=1.0, seed=1)
    _valeriano(m)
    m.light("#ffe0a0", 0.25, 2.0, (0, 1.4, -0.7))
    return m


def alto_valeriano():
    m = Model(11, "alto_valeriano", "Alto Valeriano", "Caminho da Ordem",
              "O sangue valeriano desperta sob o Sol: mechas douradas luminosas nascem nos cabelos, os olhos se "
              "tornam ouro puro e uma coroa solar sutil passa a flutuar sobre a testa.",
              "#ffd700", scale=1.02, seed=11)
    _valeriano(m, "#6d4c2a")
    gold = m.mat("solar_gold", "#ffe082", emit="#ffc400", energy=3.0,
                 anim={"type": "glow", "speed": 1.2, "min": 0.7, "max": 1.3})
    eye = m.mat("eye_gold", "#fff59d", emit="#ffd600", energy=6.0)
    m.part("sphere", [0.02], (0.045, 1.72, -0.114), eye, mirror=True)
    for x in (-0.07, 0.0, 0.08):
        m.part("box", [0.022, 0.012, 0.2], (x, 1.855, 0.0), gold, rot=(10, 0, x * 60))
    m.group("crown", (0, 1.92, -0.02), anim={"type": "bob", "amp": 0.012, "speed": 1.5})
    m.part("torus", [0.1, 0.112], (0, 1.92, -0.02), gold, rot=(-14, 0, 0), group="crown")
    for i in range(7):
        a = math.radians(-90 + (i - 3) * 24)
        p = (math.cos(a) * 0.106, 1.94, math.sin(a) * 0.106 - 0.02)
        m.part("cylinder", [0.0, 0.012, 0.06 if i != 3 else 0.09], v_add(p, (0, 0.025, 0)), gold, group="crown")
    m.light("#ffd54f", 0.5, 2.5, (0, 1.8, -0.7))
    return m


def andarilho_eter():
    m = Model(12, "andarilho_eter", "Andarilho do Éter", "Caminho do Caos",
              "Os que tocaram o vazio entre as estrelas voltam marcados: pontas dos cabelos e antebraços "
              "escurecem com textura de galáxia roxa e os olhos passam a brilhar em violeta.",
              "#8e44ad", scale=1.0, seed=12)
    _valeriano(m, "#2b2333")
    void = m.mat("void", "#2a0f3d", rough=0.3, emit="#8e44ad", energy=1.2,
                 anim={"type": "glow", "speed": 0.9, "min": 0.6, "max": 1.4})
    star = m.mat("void_star", "#ffffff", emit="#e1bee7", energy=5.0)
    eye = m.mat("eye_violet", "#e1bee7", emit="#aa00ff", energy=6.0)
    m.part("sphere", [0.02], (0.045, 1.72, -0.114), eye, mirror=True)
    m.part("capsule", [0.054, 0.31], (0.31, 1.05, -0.06), void, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("sphere", [0.056], (0.32, 0.9, -0.14), void, scale=(0.9, 1.15, 0.9), group="arm_r", mirror=True)
    for i in range(5):
        m.part("sphere", [0.006], (0.33, 1.15 - i * 0.06, -0.09 - i * 0.025), star, group="arm_r", mirror=True)
    for i in range(6):
        a = math.radians(i * 60 + 20)
        m.part("cylinder", [0.0, 0.03, 0.09], (math.cos(a) * 0.12, 1.76, math.sin(a) * 0.12 + 0.02), void,
               rot=(math.sin(a) * 50, 0, -math.cos(a) * 50))
    m.group("motes", (0, 1.2, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 30})
    for i in range(8):
        a = i * 2 * math.pi / 8
        m.part("sphere", [0.012], (math.cos(a) * 0.45, 0.8 + (i % 4) * 0.25, math.sin(a) * 0.45), star, group="motes")
    m.light("#aa00ff", 0.5, 2.5, (0, 1.4, -0.7))
    return m


# ---------------------------------------------------------------------------
# 2 / 13 / 14 — Noctari e evoluções
# ---------------------------------------------------------------------------

def _noctari(m, skin_col="#ebf5fb", eye_col="#18ffff"):
    skin = m.mat("skin", skin_col, rough=0.35)
    hair = m.mat("hair_silver", "#e8eef4", rough=0.4, metal=0.3)
    robe = m.mat("robe", "#1c2747", rough=0.6)
    trim = m.mat("silver_trim", "#cfd8dc", rough=0.2, metal=0.9)
    boots = m.mat("boots", "#141a2e", rough=0.6)
    eye = m.mat("eye", "#e0ffff", emit=eye_col, energy=5.0)
    humanoid(m, skin, robe, robe, boots, w=0.9)
    eyes(m, eye)
    hair_long(m, hair, 0.7)
    pointed_ears(m, skin, length=0.17, back=0.35, up=-75)
    m.part("cylinder", [0.2, 0.27, 0.44], (0, 0.82, 0), robe)
    belt(m, trim, trim, w=0.95)
    m.part("box", [0.025, 0.4, 0.02], (0, 1.28, -0.158), trim)
    return skin, hair, robe, trim


def noctari():
    m = Model(2, "noctari", "Noctari", "Elfo da Lua",
              "Esbeltos e altos, de orelhas longas inclinadas para trás, pele pálida azulada, cabelos prateados "
              "e olhos ciano-lunares. Os Noctari se movem como a luz da lua sobre a água.",
              "#00e5ff", scale=1.06, seed=2)
    _noctari(m)
    m.light("#00e5ff", 0.35, 2.2, (0, 1.6, -0.7))
    return m


def arconte_lunar():
    m = Model(13, "arconte_lunar", "Arconte Lunar", "Caminho da Ordem",
              "Tatuagens astrais prateadas acendem no rosto e nos braços, e uma meia-lua de cristal prateado "
              "passa a flutuar atrás das costas do Arconte.",
              "#00e5ff", scale=1.07, seed=13)
    _noctari(m)
    tattoo = m.mat("astral_tattoo", "#e0f7fa", emit="#b3e5fc", energy=3.0,
                   anim={"type": "glow", "speed": 1.0, "min": 0.5, "max": 1.3})
    crystal = m.mat("moon_crystal", "#e3f2fd", rough=0.05, metal=0.5, emit="#80d8ff", energy=1.8, alpha=0.85)
    m.part("box", [0.008, 0.07, 0.008], (0.06, 1.68, -0.11), tattoo, rot=(0, 0, 25), mirror=True)
    m.part("box", [0.008, 0.04, 0.008], (0.0, 1.79, -0.12), tattoo)
    for i in range(3):
        m.part("box", [0.008, 0.07, 0.008], (0.335, 1.12 - i * 0.07, -0.085 - i * 0.03), tattoo,
               rot=(30, 0, 20 * (-1) ** i), group="arm_r", mirror=True)
    m.group("crescent", (0, 1.55, 0.3), anim={"type": "bob", "amp": 0.03, "speed": 1.1})
    for i in range(13):
        a = math.radians(-120 + i * 20)
        r = 0.32
        thick = 0.05 * math.sin(math.pi * i / 12) + 0.012
        m.part("box", [thick, 0.09, 0.03], (math.sin(a) * r, 1.55 + math.cos(a) * r, 0.3), crystal,
               rot=(0, 0, -math.degrees(a)), group="crescent")
    m.light("#80d8ff", 0.5, 2.5, (0, 1.6, -0.7))
    return m


def espectro_umbral():
    m = Model(14, "espectro_umbral", "Espectro Umbral", "Caminho do Caos",
              "A pele escurece até o cinza-noite, a esclera dos olhos fica totalmente negra com uma pupila branca "
              "brilhante, e sombras vivas escorrem dos pés a cada passo.",
              "#7c4dff", scale=1.06, seed=14)
    skin, hair, robe, trim = _noctari(m, "#2c3e50", "#ffffff")
    black = m.mat("black_sclera", "#020205", rough=0.2)
    pupil = m.mat("pupil", "#ffffff", emit="#ffffff", energy=6.0)
    shadow = m.mat("shadow", "#1a0f2e", emit="#4527a0", energy=0.6, alpha=0.55,
                   anim={"type": "flicker", "speed": 3.0, "min": 0.4, "max": 1.0})
    m.part("sphere", [0.022], (0.045, 1.72, -0.11), black, mirror=True)
    m.part("sphere", [0.008], (0.045, 1.72, -0.131), pupil, mirror=True)
    for i in range(10):
        a = i * 2 * math.pi / 10
        m.part("sphere", [0.07 + 0.03 * (i % 3)], (math.cos(a) * 0.22, 0.05, math.sin(a) * 0.22), shadow,
               scale=(1, 0.5, 1), anim={"type": "bob", "amp": 0.04, "speed": 1.5, "phase": i})
    m.light("#7c4dff", 0.4, 2.2, (0, 1.4, -0.7))
    return m


# ---------------------------------------------------------------------------
# 3 / 15 / 16 — Kharad e evoluções
# ---------------------------------------------------------------------------

def _kharad(m, crack_col="#ff5722"):
    rock = m.mat("basalt", "#2e4053", rough=0.95)
    rock_d = m.mat("basalt_dark", "#1f2b38", rough=0.95)
    crack = m.mat("ember_crack", "#ffab91", emit=crack_col, energy=3.0,
                  anim={"type": "glow", "speed": 1.3, "min": 0.55, "max": 1.3})
    kilt = m.mat("leather_kilt", "#4a3426", rough=0.8)
    eye = m.mat("eye", "#ffccbc", emit=crack_col, energy=5.0)
    humanoid(m, rock, rock, rock_d, rock_d, eye=eye, w=1.32)
    m.part("sphere", [0.11], (0, 1.63, -0.02), rock, scale=(1.5, 0.8, 1.1))
    m.part("box", [0.16, 0.035, 0.05], (0, 1.76, -0.1), rock_d)
    m.part("cylinder", [0.24, 0.3, 0.32], (0, 0.83, 0), kilt)
    belt(m, kilt, rock_d, w=1.25)
    crack_lines(m, crack, m.rng, 9, box=((-0.24, 0.24), (1.08, 1.48)), z=-0.155)
    crack_lines(m, crack, m.rng, 3, box=((-0.08, 0.08), (1.66, 1.75)), z=-0.122, w=0.008)
    for side in ("arm_r", "leg_r"):
        for i in range(3):
            if side == "arm_r":
                p = (0.41 + 0.01 * i, 1.32 - i * 0.13, -0.05 - i * 0.03)
            else:
                p = (0.15, 0.78 - i * 0.2, -0.085)
            m.part("box", [0.012, 0.08, 0.012], p, crack, rot=(0, 0, 20 - i * 15), group=side, mirror=True)
    return rock, rock_d, crack


def kharad():
    m = Model(3, "kharad", "Kharad", "Forjado das Cinzas",
              "Baixos e largos, de musculatura densa e pele de rocha basáltica cinza-escura cortada por fendas "
              "que brilham em laranja-brasa — como se carregassem uma forja dentro do peito.",
              "#ff9800", scale=0.83, seed=3)
    _kharad(m)
    m.light("#ff5722", 0.45, 2.2, (0, 1.3, -0.7))
    return m


def guardiao_runico():
    m = Model(15, "guardiao_runico", "Guardião Rúnico", "Caminho da Ordem",
              "Placas geométricas de aço e ouro se encravam nos ombros e no peito, e runas azuis brilhantes são "
              "esculpidas na própria pele de pedra do Guardião.",
              "#ff9800", scale=0.85, seed=15)
    _kharad(m)
    steel = m.mat("steel", "#9aa4ad", rough=0.25, metal=0.9)
    gold = m.mat("gold", "#d4ac0d", rough=0.25, metal=0.95)
    rune = m.mat("rune_blue", "#b3e5fc", emit="#00b0ff", energy=3.5,
                 anim={"type": "glow", "speed": 1.6, "min": 0.5, "max": 1.3})
    m.part("box", [0.32, 0.22, 0.05], (0, 1.34, -0.15), steel, rot=(-6, 0, 0))
    m.part("box", [0.2, 0.04, 0.055], (0, 1.45, -0.155), gold, rot=(-6, 0, 0))
    m.part("box", [0.06, 0.06, 0.02], (0, 1.34, -0.18), rune, rot=(0, 0, 45))
    m.part("box", [0.24, 0.06, 0.26], (0.38, 1.58, 0), steel, rot=(0, 0, -24), group="arm_r", mirror=True)
    m.part("box", [0.2, 0.03, 0.22], (0.38, 1.62, 0), gold, rot=(0, 0, -24), group="arm_r", mirror=True)
    for i in range(3):
        m.part("box", [0.03, 0.03, 0.012], (0.06 * (i - 1), 1.18, -0.165), rune, rot=(0, 0, 45))
        m.part("box", [0.03, 0.012, 0.012], (0.415, 1.3 - i * 0.1, -0.06), rune, group="arm_r", mirror=True)
    m.light("#00b0ff", 0.5, 2.2, (0, 1.3, -0.7))
    return m


def tita_obsidiana():
    m = Model(16, "tita_obsidiana", "Titã de Obsidiana", "Caminho do Caos",
              "Chifres curtos de pedra vulcânica negra e polida rompem a testa e os ombros, e veias de lava "
              "incandescente escorrem vivas pelo peito do Titã.",
              "#ff3d00", scale=0.87, seed=16)
    rock, rock_d, crack = _kharad(m, "#ff3d00")
    obs = m.mat("obsidian", "#141218", rough=0.05, metal=0.5)
    lava = m.mat("lava", "#ffd180", emit="#ff3d00", energy=4.5,
                 anim={"type": "glow", "speed": 0.9, "min": 0.7, "max": 1.3})
    m.chain([(0.06, 1.8, -0.06), (0.09, 1.9, -0.08), (0.1, 1.97, -0.04)], [0.03, 0.02, 0.0], obs, mirror=True)
    for i, (dx, dz) in enumerate(((0, 0), (0.06, 0.05), (-0.05, 0.06))):
        m.part("cylinder", [0.0, 0.035, 0.13], (0.4 + dx, 1.62, dz), obs, rot=(10 * i, 0, -20), group="arm_r", mirror=True)
    for x in (-0.08, 0.0, 0.09):
        m.chain([(x, 1.5, -0.15), (x * 1.3 + 0.02, 1.32, -0.165), (x * 0.8, 1.12, -0.155)], [0.016, 0.014, 0.008], lava)
    m.light("#ff3d00", 0.7, 2.5, (0, 1.3, -0.7))
    return m


# ---------------------------------------------------------------------------
# 4 / 17 / 18 — Varkai e evoluções
# ---------------------------------------------------------------------------

def _varkai(m, ears=True, fur_tail=True, fur_col="#8d6e4c"):
    skin = m.mat("skin", "#c9a27e", rough=0.6)
    fur = m.mat("fur", fur_col, rough=1.0)
    leather = m.mat("leather", "#4a3528", rough=0.8)
    claw = m.mat("claw_black", "#111114", rough=0.25, metal=0.2)
    fang = m.mat("fang", "#f5f0e6", rough=0.4)
    eye = m.mat("eye_amber", "#ffe082", emit="#ffab00", energy=5.0)
    pupil = m.mat("slit", "#110800", rough=0.3)
    humanoid(m, skin, leather, leather, leather, w=1.05)
    m.part("sphere", [0.021], (0.046, 1.72, -0.11), eye, scale=(1.2, 0.9, 1), mirror=True)
    m.part("box", [0.005, 0.026, 0.005], (0.046, 1.72, -0.131), pupil, mirror=True)
    m.part("sphere", [0.134], (0, 1.75, 0.025), fur, scale=(1.04, 0.95, 1.05))
    m.part("cylinder", [0.0, 0.006, 0.025], (0.022, 1.64, -0.115), fang, rot=(180, 0, 0), mirror=True)
    if ears:
        m.part("cylinder", [0.0, 0.045, 0.12], (0.08, 1.88, 0.02), fur, rot=(-8, 0, -18), scale=(1, 1, 0.5), mirror=True)
    for dx in (-0.018, 0.0, 0.018):
        m.part("cylinder", [0.0, 0.006, 0.04], (0.32 + dx, 0.84, -0.17), claw, rot=(25, 0, 0), group="arm_r", mirror=True)
    m.part("sphere", [0.2], (0, 1.3, -0.01), leather, scale=(1.22, 1.2, 0.8))
    if fur_tail:
        last = tail(m, [(0, 0.98, 0.12), (0, 0.8, 0.32), (0.05, 0.6, 0.5), (0.1, 0.5, 0.72)], [0.05, 0.055, 0.05, 0.035], fur)
        fur_tufts(m, (0.03, 0.7, 0.42), (0.05, 0.1, 0.1), 22, fur, group="tail1", length=0.05, bias=(0, -0.3, 0.6))
        fur_tufts(m, (0.08, 0.55, 0.62), (0.05, 0.06, 0.08), 16, fur, group=last, length=0.05, bias=(0.2, -0.3, 0.7))
    if ears:
        fur_tufts(m, (0.08, 1.87, 0.02), (0.035, 0.05, 0.02), 6, fur, length=0.03, thickness=0.012,
                  bias=(0.3, 0.6, 0), mirror=True)
    fur_tufts(m, (0, 1.76, 0.03), (0.13, 0.11, 0.13), 26, fur, length=0.05, bias=(0, 0.2, 0.6),
              region=lambda x, y, z: y > -0.1 and z > -0.4)
    return skin, fur, claw


def varkai():
    m = Model(4, "varkai", "Varkai", "Sangue-Feral",
              "Corpo atlético de postura felina e lupina, orelhas peludas no topo da cabeça, caninos aparentes, "
              "garras negras, cauda longa e olhos fendidos cor de âmbar.",
              "#ff1744", scale=1.0, seed=4)
    _varkai(m)
    m.light("#ffab00", 0.25, 2.0, (0, 1.6, -0.7))
    return m


def soberano_draconico():
    m = Model(17, "soberano_draconico", "Soberano Dracônico", "Caminho da Ordem",
              "O sangue de dragão prevalece: um par de chifres nobres curvados para trás, placas de escamas "
              "vermelhas e douradas nos ombros e braços, e uma cauda reptiliana.",
              "#ff1744", scale=1.04, seed=17)
    _varkai(m, ears=False, fur_tail=False)
    horn = m.mat("noble_horn", "#3a2a24", rough=0.2, metal=0.3)
    red = m.mat("scale_red", "#9b1b1b", rough=0.3, metal=0.5)
    gold = m.mat("scale_gold", "#d4a017", rough=0.25, metal=0.9)
    m.chain([(0.06, 1.82, -0.02), (0.1, 1.93, 0.05), (0.12, 1.95, 0.18), (0.11, 1.88, 0.28)],
            [0.03, 0.024, 0.014, 0.0], horn, mirror=True)
    for i in range(4):
        mat = red if i % 2 == 0 else gold
        m.part("box", [0.22 - i * 0.02, 0.04, 0.22], (0.32 + i * 0.03, 1.6 - i * 0.07, 0), mat,
               rot=(0, 0, -25 - i * 14), group="arm_r", mirror=True)
    for i in range(3):
        m.part("box", [0.1, 0.03, 0.08], (0.3 + i * 0.006, 1.2 - i * 0.09, -0.04), red, rot=(0, 0, 8), group="arm_r", mirror=True)
    tail(m, [(0, 0.95, 0.12), (0, 0.72, 0.38), (0.05, 0.42, 0.62), (0.12, 0.18, 0.9), (0.15, 0.1, 1.15)],
         [0.09, 0.075, 0.06, 0.04, 0.0], red)
    m.light("#ff1744", 0.4, 2.2, (0, 1.4, -0.7))
    return m


def fera_frenesi():
    m = Model(18, "fera_frenesi", "Fera do Frenesi", "Caminho do Caos",
              "A fera vence o homem: pelagem densa e eriçada cobre ombros e costas, o focinho semi-lupino fica "
              "mais pronunciado e as garras longas vivem manchadas de carmesim.",
              "#ad1457", scale=1.06, seed=18)
    skin, fur, claw = _varkai(m, fur_col="#4a2c22")
    blood = m.mat("blood_claw", "#7f0000", rough=0.3, emit="#b71c1c", energy=0.6)
    m.part("box", [0.1, 0.07, 0.1], (0, 1.68, -0.15), fur, rot=(10, 0, 0))
    m.part("sphere", [0.02], (0, 1.69, -0.205), claw)
    fur_tufts(m, (0, 1.42, 0.06), (0.26, 0.16, 0.16), 70, fur, length=0.09, bias=(0, 0.3, 0.7),
              region=lambda x, y, z: y > -0.2 and z > -0.3)
    fur_tufts(m, (0.3, 1.38, 0), (0.08, 0.16, 0.08), 20, fur, group="arm_r", length=0.06, bias=(0.5, -0.4, 0.3), mirror=True)
    for i in range(18):
        a = math.radians(-70 + i * 140 / 17)
        y = 1.42 + 0.12 * math.sin(i * 1.7)
        p = (math.sin(a) * 0.22, y, math.cos(a) * 0.13 + 0.02)
        m.part("cylinder", [0.0, 0.03, 0.13], p, fur, rot=(55 * math.cos(a), 0, -60 * math.sin(a)))
    for dx in (-0.02, 0.0, 0.02):
        m.part("cylinder", [0.0, 0.007, 0.08], (0.32 + dx, 0.81, -0.19), blood, rot=(30, 0, 0), group="arm_r", mirror=True)
    m.light("#ff1744", 0.35, 2.0, (0, 1.6, -0.7))
    return m


# ---------------------------------------------------------------------------
# 5 a 10 — Raças secretas
# ---------------------------------------------------------------------------

def dhampir():
    m = Model(5, "dhampir", "Dhampir", "Vampiro Progenitor",
              "Pele branca marmórea e fria, rosto aristocrático e cadavérico, olhos vermelho-rubi luminosos, "
              "presas longas, unhas negras afiadas e gola alta gótica vermelha e preta.",
              "#d500f9", scale=1.04, seed=5)
    skin = m.mat("marble_skin", "#f3efef", rough=0.25)
    coat = m.mat("gothic_coat", "#15090c", rough=0.45, metal=0.15)
    red = m.mat("blood_velvet", "#7b0d1e", rough=0.6, double=True)
    hair = m.mat("hair", "#0c0a0d", rough=0.35, metal=0.2)
    eye = m.mat("eye_ruby", "#ff8a80", emit="#e74c3c", energy=6.0)
    fang = m.mat("fang", "#ffffff", rough=0.2)
    nail = m.mat("nail", "#050505", rough=0.2)
    silver = m.mat("silver", "#c0c6cc", rough=0.2, metal=0.9)
    humanoid(m, skin, coat, coat, coat, hands=skin, w=0.94)
    eyes(m, eye)
    hair_slick(m, hair)
    m.part("cylinder", [0.0, 0.006, 0.032], (0.02, 1.635, -0.114), fang, rot=(180, 0, 0), mirror=True)
    for dx in (-0.018, 0.0, 0.018):
        m.part("cylinder", [0.0, 0.005, 0.03], (0.32 + dx, 0.85, -0.17), nail, rot=(25, 0, 0), group="arm_r", mirror=True)
    m.part("cylinder", [0.2, 0.13, 0.26], (0, 1.62, 0.03), red)
    m.part("cylinder", [0.21, 0.14, 0.27], (0, 1.62, 0.045), coat, scale=(1, 1, 1))
    m.part("cylinder", [0.24, 0.36, 0.7], (0, 0.75, 0.04), coat)
    m.part("box", [0.03, 0.42, 0.02], (0, 1.28, -0.16), red)
    m.part("sphere", [0.025], (0, 1.45, -0.165), silver)
    m.light("#e74c3c", 0.35, 2.0, (0, 1.6, -0.7))
    return m


def licantropo():
    m = Model(6, "licantropo", "Licantropo Primordial", "Raid Boss / Raça",
              "Lobisomem bípede colossal de 2,30 m, com pernas digitígradas, tórax gigante coberto de pelagem "
              "negra e carmesim, cabeça lupina feroz marcada de cicatrizes e olhos ardendo em sangue.",
              "#ff6f00", scale=1.22, seed=6)
    fur = m.mat("fur_black", "#1b1517", rough=1.0)
    fur_r = m.mat("fur_crimson", "#6d1414", rough=1.0)
    skin = m.mat("muzzle", "#3a2e2c", rough=0.7)
    claw = m.mat("claw", "#e0d8cc", rough=0.3)
    eye = m.mat("eye_blood", "#ff8a80", emit="#ff1744", energy=7.0)
    scar = m.mat("scar", "#8a5a54", rough=0.6)
    m.body_w = 1.35
    # Pernas digitígradas
    m.group("leg_r", (0.15, 0.95, 0), mirror=True)
    m.chain([(0.15, 0.95, 0), (0.16, 0.6, -0.16), (0.16, 0.25, 0.08), (0.16, 0.04, -0.06)],
            [0.12, 0.09, 0.065, 0.05], fur, group="leg_r", mirror=True, joints=fur)
    m.part("box", [0.14, 0.06, 0.2], (0.16, 0.03, -0.12), skin, group="leg_r", mirror=True)
    for dx in (-0.04, 0.0, 0.04):
        m.part("cylinder", [0.0, 0.014, 0.06], (0.16 + dx, 0.03, -0.25), claw, rot=(-80, 0, 0), group="leg_r", mirror=True)
    # Tronco colossal e corcunda
    m.part("sphere", [0.17], (0, 1.0, 0.02), fur, scale=(1.4, 1.0, 1.0))
    m.part("sphere", [0.26], (0, 1.32, -0.02), fur, scale=(1.35, 1.2, 0.9))
    m.part("sphere", [0.22], (0, 1.38, -0.12), fur_r, scale=(1.1, 0.95, 0.5))
    m.part("sphere", [0.2], (0, 1.55, 0.12), fur, scale=(1.5, 0.9, 1.0))
    # Cabeça lupina
    m.part("sphere", [0.14], (0, 1.68, -0.12), fur, scale=(1.0, 0.95, 1.1))
    m.part("box", [0.12, 0.1, 0.2], (0, 1.64, -0.3), skin, rot=(8, 0, 0))
    m.part("box", [0.1, 0.04, 0.16], (0, 1.58, -0.27), skin, rot=(14, 0, 0))
    m.part("sphere", [0.025], (0, 1.68, -0.405), m.mat("nose", "#0a0a0a", rough=0.2))
    m.part("sphere", [0.022], (0.06, 1.72, -0.22), eye, scale=(1.4, 0.6, 1), mirror=True)
    m.part("cylinder", [0.0, 0.06, 0.18], (0.08, 1.84, -0.06), fur, rot=(-15, 0, -14), scale=(1, 1, 0.5), mirror=True)
    for dx in (-0.03, 0.03):
        m.part("cylinder", [0.0, 0.008, 0.04], (dx, 1.57, -0.36), claw, rot=(180, 0, 0))
    m.part("box", [0.008, 0.12, 0.01], (-0.06, 1.7, -0.25), scar, rot=(0, 0, 30))
    m.part("box", [0.008, 0.1, 0.01], (0.12, 1.36, -0.22), scar, rot=(0, 0, -20))
    # Braços enormes com garras
    m.group("arm_r", (0.36, 1.48, 0), mirror=True)
    m.part("sphere", [0.14], (0.36, 1.48, 0), fur, group="arm_r", mirror=True)
    m.part("capsule", [0.1, 0.42], (0.42, 1.24, 0), fur, rot=(0, 0, 12), group="arm_r", mirror=True)
    m.part("capsule", [0.09, 0.4], (0.47, 0.92, -0.08), fur_r, rot=(25, 0, 8), group="arm_r", mirror=True)
    m.part("sphere", [0.085], (0.49, 0.72, -0.16), skin, scale=(1, 0.9, 1.2), group="arm_r", mirror=True)
    for dx in (-0.04, 0.0, 0.04):
        m.part("cylinder", [0.0, 0.014, 0.12], (0.49 + dx, 0.62, -0.22), claw, rot=(20, 0, 0), group="arm_r", mirror=True)
    fur_tufts(m, (0, 1.4, 0.02), (0.36, 0.3, 0.26), 110, fur, length=0.09, bias=(0, 0.3, 0.7),
              region=lambda x, y, z: z > -0.5, seed=61)
    fur_tufts(m, (0, 1.36, -0.12), (0.26, 0.24, 0.12), 40, fur_r, length=0.07, bias=(0, -0.5, -0.4), seed=62)
    fur_tufts(m, (0, 1.7, -0.1), (0.15, 0.13, 0.14), 34, fur, length=0.07, bias=(0, 0.2, 0.8), seed=63)
    fur_tufts(m, (0.15, 0.7, -0.05), (0.12, 0.25, 0.12), 26, fur, group="leg_r", length=0.06, bias=(0, -0.4, 0.4),
              seed=64, mirror=True)
    m.anchor("hand_r", "arm_r", (0.49, 0.7, -0.17))
    m.anchor("hand_l", "arm_l", (-0.49, 0.7, -0.17))
    m.anchor("back", None, (0, 1.4, 0.3))
    tail(m, [(0, 0.98, 0.15), (0, 0.8, 0.4), (0.05, 0.6, 0.6), (0.12, 0.45, 0.82)], [0.07, 0.09, 0.08, 0.04], fur)
    m.light("#ff1744", 0.4, 2.5, (0, 1.7, -0.9))
    return m


def revenant():
    m = Model(7, "revenant", "Amaldiçoado das Cinzas", "Revenant",
              "Guerreiro morto-vivo de pele cinza ressecada colada aos ossos. No centro do peito, costelas "
              "expostas protegem uma chama azul-ciano que pulsa como um coração espiritual.",
              "#69f0ae", scale=1.02, seed=7)
    skin = m.mat("dry_skin", "#7a7c72", rough=0.9)
    bone = m.mat("bone", "#d8d0c0", rough=0.6)
    rag = m.mat("rags", "#2a2a2c", rough=1.0, double=True)
    iron = m.mat("rusted_iron", "#5a4a3c", rough=0.7, metal=0.6)
    flame = m.mat("soul_flame", "#e0ffff", emit="#00ffff", energy=5.0, alpha=0.9,
                  anim={"type": "glow", "speed": 3.0, "min": 0.5, "max": 1.4})
    socket = m.mat("socket", "#050607", rough=0.5)
    eye = m.mat("eye", "#e0ffff", emit="#00ffff", energy=6.0)
    humanoid(m, skin, skin, rag, iron, w=0.92, torso=False)
    m.part("sphere", [0.2], (0, 1.27, 0.02), skin, scale=(1.1, 1.45, 0.7))
    m.part("sphere", [0.07], (0, 1.33, -0.07), socket, scale=(1.2, 1.4, 0.8))
    m.part("sphere", [0.045], (0, 1.33, -0.09), flame, anim={"type": "pulse", "amp": 0.18, "speed": 4.5})
    m.part("cylinder", [0.0, 0.03, 0.09], (0, 1.38, -0.09), flame)
    for i in range(4):
        y = 1.45 - i * 0.075
        m.part("torus", [0.11 - i * 0.004, 0.122 - i * 0.004], (0, y, -0.06), bone, scale=(1.2, 1, 0.75), rot=(8, 0, 0))
    m.part("box", [0.025, 0.32, 0.02], (0, 1.3, -0.14), bone)
    m.part("sphere", [0.028], (0.045, 1.72, -0.1), socket, mirror=True)
    m.part("sphere", [0.01], (0.045, 1.72, -0.12), eye, mirror=True)
    m.part("box", [0.07, 0.02, 0.02], (0, 1.64, -0.112), bone)
    m.part("cylinder", [0.22, 0.3, 0.5], (0, 0.8, 0), rag)
    m.part("box", [0.3, 0.08, 0.3], (0.33, 1.56, 0), iron, rot=(0, 0, -20), group="arm_r")
    m.light("#00ffff", 0.6, 2.2, (0, 1.35, -0.6))
    return m


def celestino():
    m = Model(8, "celestino", "Celestino", "Serafim Astral",
              "Corpo humanoide esculpido em mármore branco com veias de ouro, rosto sereno de olhos sem pupila "
              "emitindo luz dourada e quatro asas de lâminas de luz translúcida flutuando desconectadas das costas.",
              "#fff59d", scale=1.08, seed=8)
    marble = m.mat("marble", "#f5f3ee", rough=0.18, metal=0.05)
    gold = m.mat("gold_vein", "#ffd54f", rough=0.2, metal=0.9, emit="#ffb300", energy=1.0)
    eye = m.mat("eye_light", "#fffde7", emit="#ffd600", energy=7.0)
    blade = m.mat("light_blade", "#fff8c4", emit="#ffd54f", energy=3.5, alpha=0.6, double=True,
                  anim={"type": "glow", "speed": 1.3, "min": 0.7, "max": 1.3})
    humanoid(m, marble, marble, marble, marble, eye=eye, w=0.96)
    crack_lines(m, gold, m.rng, 10, box=((-0.2, 0.2), (1.05, 1.5)), z=-0.152, w=0.006)
    crack_lines(m, gold, m.rng, 3, box=((-0.07, 0.07), (1.66, 1.78)), z=-0.12, w=0.005)
    m.part("sphere", [0.133], (0, 1.75, 0.02), marble, scale=(1.03, 0.93, 1.04))
    m.part("torus", [0.12, 0.13], (0, 1.82, 0.0), gold, rot=(-10, 0, 0))
    for k, (side, y, ang) in enumerate(((1, 1.55, 35), (1, 1.3, 10), (-1, 1.55, 35), (-1, 1.3, 10))):
        g = m.group("lightwing%d" % k, (side * 0.18, y, 0.3),
                    anim={"type": "sway", "axis": [0, side, 0], "amp": 6.0, "speed": 1.2, "phase": k})
        base = (side * 0.18, y, 0.3)
        for j in range(3):
            tip = v_add(base, (side * (0.5 - j * 0.08), 0.32 - j * 0.22 + (ang - 20) * 0.004, 0.08 + j * 0.03))
            m.plank(v_lerp(base, tip, 0.1), tip, 0.06, 0.01, blade, group=g)
    m.light("#ffd54f", 0.7, 2.5, (0, 1.6, 0.4))
    return m


def abissal():
    m = Model(9, "abissal", "Abissal", "Filho do Eclipse",
              "Silhueta inteiramente negra e fosca com textura de céu estrelado profundo, rosto sem traços com "
              "dois olhos roxos e um mini buraco negro com anel de fogo girando no centro do tórax.",
              "#18ffff", scale=1.04, seed=9)
    void = m.mat("void_matte", "#07070c", rough=0.95)
    star = m.mat("star", "#ffffff", emit="#e8eaf6", energy=4.0,
                 anim={"type": "glow", "speed": 2.5, "min": 0.3, "max": 1.2})
    eye = m.mat("eye_violet", "#ea80fc", emit="#aa00ff", energy=7.0)
    hole = m.mat("event_horizon", "#000000", rough=1.0)
    fire = m.mat("ring_fire", "#ffcc80", emit="#ff6d00", energy=4.0,
                 anim={"type": "glow", "speed": 4.0, "min": 0.6, "max": 1.4})
    fire2 = m.mat("ring_violet", "#e1bee7", emit="#aa00ff", energy=3.0)
    humanoid(m, void, void, void, void, w=0.95)
    m.part("sphere", [0.02], (0.045, 1.72, -0.112), eye, scale=(1.5, 0.6, 1), mirror=True)
    for i in range(40):
        y = m.rng.uniform(0.1, 1.82)
        a = m.rng.uniform(0, 2 * math.pi)
        r = 0.1 if y > 1.6 else (0.24 if y > 1.0 else 0.12)
        x = math.cos(a) * r * (1 if y > 1.0 else 0.4) + (0 if y > 1.0 else (0.11 if i % 2 else -0.11))
        m.part("sphere", [0.006], (x, y, math.sin(a) * r * 0.75), star)
    m.part("sphere", [0.075], (0, 1.3, -0.1), hole)
    m.group("accretion", (0, 1.3, -0.12), anim={"type": "spin", "axis": [0, 0, 1], "speed": 140})
    m.part("torus", [0.08, 0.1], (0, 1.3, -0.12), fire, rot=(90, 0, 0), group="accretion")
    m.part("torus", [0.1, 0.11], (0, 1.3, -0.12), fire2, rot=(90, 0, 0), scale=(1, 1, 0.6), group="accretion")
    m.light("#aa00ff", 0.6, 2.5, (0, 1.3, -0.7))
    return m


def automato():
    m = Model(10, "automato", "Autômato Rúnico", "Alma Forjada",
              "Corpo de placas de bronze envelhecido e ferro negro, com engrenagens aparentes nos cotovelos e "
              "joelhos, elmo sem boca com visor horizontal ciano e um núcleo de cristal giratório no peito.",
              "#00e5ff", scale=1.04, seed=10)
    bronze = m.mat("aged_bronze", "#8c6a3b", rough=0.4, metal=0.9)
    iron = m.mat("black_iron", "#24262a", rough=0.45, metal=0.85)
    visor = m.mat("visor", "#e0ffff", emit="#00e5ff", energy=5.0)
    core = m.mat("core_crystal", "#b2ebf2", rough=0.05, emit="#00e5ff", energy=3.5, alpha=0.9,
                 anim={"type": "glow", "speed": 2.0, "min": 0.6, "max": 1.3})
    humanoid(m, iron, bronze, iron, bronze, hands=iron, forearm=bronze, w=1.06, head=False)
    m.part("box", [0.22, 0.24, 0.24], (0, 1.72, 0), bronze)
    m.part("box", [0.24, 0.03, 0.05], (0, 1.73, -0.11), iron)
    m.part("box", [0.2, 0.018, 0.02], (0, 1.73, -0.135), visor)
    m.part("box", [0.03, 0.08, 0.2], (0, 1.86, 0.0), iron)
    m.part("box", [0.34, 0.06, 0.24], (0, 1.45, 0), iron)
    m.part("sphere", [0.09], (0, 1.3, -0.12), iron, scale=(1, 1, 0.4))
    m.part("sphere", [0.05], (0, 1.3, -0.15), core, scale=(0.75, 1.2, 0.75), rot=(0, 45, 0),
           anim={"type": "spin", "axis": [0, 1, 0], "speed": 90})

    def gear(center, group, axis_rot):
        m.part("torus", [0.03, 0.055], center, iron, rot=axis_rot, group=group)
        for t in range(8):
            ta = t * math.pi / 4
            off = (0, math.cos(ta) * 0.06, math.sin(ta) * 0.06)
            m.part("box", [0.03, 0.022, 0.022], v_add(center, off), bronze, rot=(math.degrees(ta), 0, 0), group=group)

    gear((0.33, 1.16, -0.02), "arm_r", (0, 0, 90))
    gear((-0.33, 1.16, -0.02), "arm_l", (0, 0, 90))
    gear((0.15, 0.5, -0.02), "leg_r", (0, 0, 90))
    gear((-0.15, 0.5, -0.02), "leg_l", (0, 0, 90))
    m.light("#00e5ff", 0.5, 2.2, (0, 1.4, -0.7))
    return m


ALL_BASE = [valeriano, noctari, kharad, varkai, dhampir, licantropo, revenant, celestino, abissal, automato,
            alto_valeriano, andarilho_eter, arconte_lunar, espectro_umbral, guardiao_runico, tita_obsidiana,
            soberano_draconico, fera_frenesi]
