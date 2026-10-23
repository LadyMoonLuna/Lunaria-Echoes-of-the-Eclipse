"""Armas, companheiros e trajes que faltavam para as 12 Classes Básicas oficiais (IDs 1 a 12).

Mesmas convenções de gear.py: armas com pivô na empunhadura e lâmina ao longo de +Y;
companheiros orbitam/acompanham o personagem; trajes para um corpo de largura 1.0.
"""

import math

from modelkit import Model, v_add


def W(key, name, desc, color):
    return Model(0, key, name, "Arma", desc, color, kind="weapon")


def C(key, name, desc, color):
    return Model(0, key, name, "Companheiro", desc, color, kind="companion")


def O(key, name, desc, color):
    return Model(0, key, name, "Traje de Classe", desc, color, kind="outfit")


# ---------------------------------------------------------------------------
# Armas
# ---------------------------------------------------------------------------

def assassin_dagger():
    m = W("assassin_dagger", "Adaga Curva do Assassino", "Lâmina negra curva com fio violeta envenenado (usada em par).", "#7c4dff")
    steel = m.mat("blade_black_steel", "#2b2d33", rough=0.2, metal=0.9)
    edge = m.mat("venom_edge", "#d1c4e9", emit="#7c4dff", energy=2.2)
    wrap = m.mat("grip_wrap", "#1a1420", rough=0.9)
    m.part("cylinder", [0.017, 0.019, 0.12], (0, 0, 0), wrap)
    m.part("box", [0.09, 0.018, 0.028], (0, 0.07, 0), steel)
    m.part("box", [0.036, 0.24, 0.008], (0.006, 0.2, 0), steel, rot=(0, 0, -6))
    m.part("box", [0.006, 0.22, 0.01], (0.025, 0.2, 0), edge, rot=(0, 0, -6))
    m.part("prism", [0.036, 0.06, 0.008], (0.02, 0.35, 0), steel, rot=(0, 0, -12))
    return m


def heavy_gauntlet():
    m = W("heavy_gauntlet", "Manopla Pesada de Chi", "Manopla de aço com nós reforçados e runas de Chi (usada em par).", "#ffab40")
    steel = m.mat("plate_gauntlet", "#8d939a", rough=0.3, metal=0.9)
    knuckle = m.mat("knuckle_iron", "#4a4d52", rough=0.35, metal=0.9)
    chi = m.mat("chi_rune", "#ffe0b2", emit="#ff9100", energy=2.5, anim={"type": "glow", "speed": 2.0, "min": 0.6, "max": 1.3})
    m.part("sphere", [0.075], (0, 0.02, 0), steel, scale=(1.05, 1.2, 1.1))
    m.part("cylinder", [0.07, 0.062, 0.16], (0, -0.08, 0), steel)
    for i in range(4):
        m.part("box", [0.03, 0.035, 0.035], ((i - 1.5) * 0.034, 0.09, -0.05), knuckle)
    m.part("torus", [0.05, 0.058], (0, -0.04, 0), chi)
    return m


def colossal_shield():
    m = W("colossal_shield", "Escudo Colossal do Bastião", "Grande escudo torre de aço e bronze com emblema de cidadela.", "#ffd54f")
    steel = m.mat("plate_shield", "#9aa3ab", rough=0.3, metal=0.9)
    bronze = m.mat("bronze_rim", "#b8862f", rough=0.3, metal=0.9)
    emblem = m.mat("gold_emblem", "#ffd54f", rough=0.2, metal=1.0, emit="#ffb300", energy=0.6)
    m.part("box", [0.62, 1.0, 0.06], (0, 0.1, -0.08), steel)
    m.part("box", [0.66, 0.05, 0.08], (0, 0.6, -0.08), bronze)
    m.part("box", [0.66, 0.05, 0.08], (0, -0.4, -0.08), bronze)
    m.part("box", [0.05, 1.0, 0.08], (0.31, 0.1, -0.08), bronze, mirror=True)
    m.part("box", [0.18, 0.24, 0.03], (0, 0.16, -0.125), emblem)
    m.part("prism", [0.18, 0.1, 0.03], (0, 0.33, -0.125), emblem)
    m.part("box", [0.04, 0.2, 0.04], (0, 0.05, 0.0), m.mat("grip_leather", "#3b2a1e", rough=0.8))
    return m


def short_mace():
    m = W("short_mace", "Maça Curta de Ferro", "Maça de cabeça flangeada, curta para lutar atrás do escudo.", "#90a4ae")
    iron = m.mat("iron_mace", "#7d8790", rough=0.35, metal=0.9)
    grip = m.mat("grip_leather", "#3b2a1e", rough=0.8)
    m.part("cylinder", [0.02, 0.022, 0.42], (0, 0.12, 0), grip)
    m.part("sphere", [0.07], (0, 0.38, 0), iron)
    for i in range(6):
        a = math.radians(i * 60)
        m.part("box", [0.02, 0.12, 0.05], (math.cos(a) * 0.065, 0.38, math.sin(a) * 0.065), iron, rot=(0, -i * 60, 0))
    return m


def sculptor_chisel():
    m = W("sculptor_chisel", "Adaga de Cinzel do Luar", "Cinzel prateado afiado como adaga, com brilho de luar.", "#e1f5fe")
    silver = m.mat("silver_chisel", "#e3e9ee", rough=0.15, metal=0.95)
    moon = m.mat("moon_edge", "#e1f5fe", emit="#81d4fa", energy=2.5)
    wood = m.mat("handle_wood", "#6d4c41", rough=0.8)
    m.part("cylinder", [0.02, 0.024, 0.13], (0, 0, 0), wood)
    m.part("torus", [0.02, 0.028], (0, 0.07, 0), silver)
    m.part("box", [0.03, 0.22, 0.012], (0, 0.19, 0), silver)
    m.part("box", [0.034, 0.02, 0.014], (0, 0.31, 0), moon)
    return m


def coiled_whip():
    m = W("coiled_whip", "Chicote Bestial Enrolado", "Chicote de couro trançado enrolado na mão, ponta com garra de fera.", "#8d6e63")
    leather = m.mat("whip_leather", "#5d4037", rough=0.75)
    claw = m.mat("claw_tip", "#efe6d6", rough=0.4)
    m.part("cylinder", [0.022, 0.026, 0.2], (0, 0.02, 0), leather)
    m.part("sphere", [0.03], (0, 0.13, 0), m.mat("brass_cap", "#c9a24a", rough=0.3, metal=0.9))
    for i in range(3):
        m.part("torus", [0.07 - i * 0.01, 0.085 - i * 0.01], (0.08, 0.05 + i * 0.03, 0), leather, rot=(0, 0, 90))
    m.part("cylinder", [0.0, 0.015, 0.05], (0.08, -0.06, 0), claw, rot=(180, 0, 0))
    return m


def golden_needle():
    m = W("golden_needle", "Agulha Rúnica Dourada", "Agulha longa de ouro com fio de aço brilhante saindo do olho (usada em par).", "#ffd740")
    gold = m.mat("gold_needle", "#ffd54f", rough=0.15, metal=1.0)
    thread = m.mat("steel_thread", "#e0f7fa", emit="#18ffff", energy=3.0, anim={"type": "glow", "speed": 3.0, "min": 0.5, "max": 1.3})
    m.part("cylinder", [0.0, 0.012, 0.5], (0, 0.2, 0), gold)
    m.part("torus", [0.008, 0.014], (0, -0.04, 0), gold, rot=(90, 0, 0))
    for i in range(3):
        m.part("cylinder", [0.002, 0.002, 0.45], (0.03 + i * 0.02, 0.0, -0.05 - i * 0.02), thread, rot=(70, 0, 20 + i * 15))
    return m


def giant_cleaver():
    m = W("giant_cleaver", "Cutelo de Açougueiro Gigante", "Cutelo enorme de lâmina retangular com manchas de caça.", "#bcaaa4")
    steel = m.mat("cleaver_steel", "#b0b8bf", rough=0.3, metal=0.9)
    edge = m.mat("cleaver_edge", "#eceff1", rough=0.1, metal=1.0)
    bone = m.mat("bone_handle", "#e6dccb", rough=0.5)
    m.part("cylinder", [0.024, 0.028, 0.26], (0, 0.02, 0), bone)
    m.part("box", [0.3, 0.46, 0.02], (0.1, 0.38, 0), steel)
    m.part("box", [0.02, 0.46, 0.024], (0.25, 0.38, 0), edge)
    m.part("cylinder", [0.03, 0.03, 0.022], (0.0, 0.56, 0), m.mat("hang_hole", "#1b1b1b"), rot=(90, 0, 0))
    return m


def iron_wok():
    m = W("iron_wok", "Wok de Ferro", "Frigideira de ferro fundido usada como escudo e para servir banquetes.", "#455a64")
    iron = m.mat("cast_iron", "#2e3236", rough=0.45, metal=0.8)
    wood = m.mat("handle_wood", "#6d4c41", rough=0.8)
    m.part("cylinder", [0.02, 0.022, 0.3], (0, 0.0, 0), wood)
    m.part("sphere", [0.26], (0, 0.36, -0.06), iron, scale=(1.0, 1.0, 0.3))
    m.part("torus", [0.24, 0.27], (0, 0.36, -0.1), iron, rot=(90, 0, 0))
    return m


# ---------------------------------------------------------------------------
# Companheiros
# ---------------------------------------------------------------------------

def guardian_statue():
    m = C("guardian_statue", "Estátua Guardiã", "Pequena estátua de mármore esculpida pelo Escultor, que orbita e o ajuda.", "#eceff1")
    marble = m.mat("marble", "#f1efe9", rough=0.2)
    moon = m.mat("moon_glow", "#e1f5fe", emit="#81d4fa", energy=3.0)
    m.group("orbit", (0, 0, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 90})
    c = (0.9, 1.1, 0)
    m.group("body", c, "orbit", anim={"type": "bob", "amp": 0.08, "speed": 2.5})
    m.part("box", [0.16, 0.05, 0.16], v_add(c, (0, -0.2, 0)), marble, group="body")
    m.part("capsule", [0.06, 0.22], v_add(c, (0, -0.05, 0)), marble, group="body")
    m.part("sphere", [0.055], v_add(c, (0, 0.12, 0)), marble, group="body")
    m.part("box", [0.015, 0.2, 0.015], v_add(c, (0.07, -0.02, 0)), marble, rot=(0, 0, 20), group="body")
    m.part("sphere", [0.012], v_add(c, (0, 0.13, -0.05)), moon, group="body")
    m.light("#81d4fa", 0.3, 1.5, c)
    return m


def tamed_beast():
    m = C("tamed_beast", "Fera Domada", "Lobo de pelagem castanha que acompanha o Domador e ataca ao comando do chicote.", "#8d6e63")
    fur = m.mat("fur", "#7b5a43", rough=1.0)
    belly = m.mat("fur_light", "#c8a98a", rough=1.0)
    eye = m.mat("eye_amber", "#ffe082", emit="#ffab00", energy=4.0)
    collar = m.mat("collar_leather", "#3e2723", rough=0.8)
    c = (0.75, 0.0, 0.25)
    m.group("body", c, anim={"type": "bob", "amp": 0.03, "speed": 3.0})
    m.part("capsule", [0.13, 0.55], v_add(c, (0, 0.42, 0)), fur, rot=(90, 0, 0), group="body")
    m.part("sphere", [0.12], v_add(c, (0, 0.38, 0)), belly, scale=(0.9, 0.8, 2.2), group="body")
    m.part("sphere", [0.11], v_add(c, (0, 0.55, -0.36)), fur, group="body")
    m.part("box", [0.08, 0.07, 0.12], v_add(c, (0, 0.52, -0.48)), fur, group="body")
    # Pares explícitos: mirror=True espelharia em torno do centro do personagem, não da fera
    for side in (-1, 1):
        m.part("cylinder", [0.0, 0.04, 0.09], v_add(c, (side * 0.06, 0.66, -0.34)), fur, group="body")
        m.part("sphere", [0.016], v_add(c, (side * 0.045, 0.58, -0.45)), eye, group="body")
        for dz in (-0.22, 0.22):
            m.part("capsule", [0.04, 0.32], v_add(c, (side * 0.08, 0.16, dz)), fur, group="body")
    m.part("torus", [0.1, 0.12], v_add(c, (0, 0.5, -0.28)), collar, rot=(70, 0, 0), group="body")
    m.part("cylinder", [0.05, 0.02, 0.3], v_add(c, (0, 0.5, 0.42)), fur, rot=(-50, 0, 0), group="body")
    return m


# ---------------------------------------------------------------------------
# Trajes
# ---------------------------------------------------------------------------

def _shell(m, mat, sleeves=None, pants=None, boots=None):
    m.part("sphere", [0.2], (0, 1.285, 0), mat, scale=(1.27, 1.42, 0.85))
    if sleeves:
        m.part("capsule", [0.067, 0.36], (0.28, 1.3, 0), sleeves, rot=(0, 0, 8), group="arm_r", mirror=True)
        m.part("sphere", [0.092], (0.26, 1.47, 0), sleeves, group="arm_r", mirror=True)
    if pants:
        m.part("capsule", [0.094, 0.52], (0.11, 0.7, 0), pants, group="leg_r", mirror=True)
        m.part("capsule", [0.124, 0.38], (0, 0.98, 0), pants, rot=(0, 0, 90), group="pose")
    if boots:
        m.part("capsule", [0.079, 0.3], (0.11, 0.22, 0), boots, group="leg_r", mirror=True)
        m.part("box", [0.14, 0.075, 0.27], (0.11, 0.037, -0.05), boots, group="leg_r", mirror=True)


def outfit_assassin():
    m = O("assassin", "Assassino", "Couro negro justo, capuz e lenço cobrindo o rosto, faixas violeta.", "#7c4dff")
    leather = m.mat("black_leather", "#1d1a22", rough=0.7)
    sash = m.mat("violet_sash", "#4a148c", rough=0.8)
    boots = m.mat("soft_boots", "#151218", rough=0.85)
    _shell(m, leather, leather, leather, boots)
    m.part("sphere", [0.145], (0, 1.76, 0.02), m.mat("hood", "#211d27", rough=0.85), scale=(1.05, 1.0, 1.1))
    m.part("box", [0.2, 0.07, 0.04], (0, 1.66, -0.11), m.mat("mask", "#2b2433", rough=0.8))
    m.part("torus", [0.19, 0.215], (0, 1.02, 0), sash, scale=(1.05, 1, 0.82))
    m.part("box", [0.05, 0.28, 0.01], (0.12, 0.86, -0.16), sash, rot=(0, 0, 8))
    return m


def outfit_fighter():
    m = O("fighter", "Lutador", "Faixas de pano nas mãos, calça larga marcial, faixa de cintura e braços à mostra.", "#ffab40")
    gi = m.mat("gi_cloth", "#f3ead7", rough=0.9)
    belt = m.mat("black_belt", "#1b1b1b", rough=0.8)
    wrap = m.mat("hand_wrap", "#e8dcc4", rough=0.95)
    m.part("sphere", [0.2], (0, 1.285, 0), gi, scale=(1.27, 1.42, 0.85))
    m.part("capsule", [0.11, 0.52], (0.11, 0.7, 0), gi, group="leg_r", mirror=True)
    m.part("capsule", [0.124, 0.38], (0, 0.98, 0), gi, rot=(0, 0, 90), group="pose")
    m.part("torus", [0.19, 0.22], (0, 1.02, 0), belt, scale=(1.05, 1, 0.82))
    m.part("cylinder", [0.065, 0.065, 0.12], (0.31, 0.95, -0.08), wrap, rot=(30, 0, 6), group="arm_r", mirror=True)
    return m


def outfit_shieldbearer():
    m = O("shieldbearer", "Escudeiro", "Armadura pesada de placas douradas e aço, gorjal alto e saiote de malha.", "#ffd54f")
    plate = m.mat("plate_armor", "#aeb6bd", rough=0.25, metal=0.9)
    gold = m.mat("gold_trim", "#d4a017", rough=0.25, metal=0.95)
    mail = m.mat("chainmail", "#8c949b", rough=0.55, metal=0.8)
    boots = m.mat("steel_boots", "#9aa3ab", rough=0.3, metal=0.85)
    _shell(m, plate, plate, mail, boots)
    m.part("sphere", [0.12], (0.3, 1.5, 0), plate, scale=(1.3, 0.8, 1.2), group="arm_r", mirror=True)
    m.part("torus", [0.11, 0.125], (0.3, 1.5, 0), gold, rot=(0, 0, 70), group="arm_r", mirror=True)
    m.part("cylinder", [0.09, 0.11, 0.12], (0, 1.58, 0), plate)
    m.part("cylinder", [0.24, 0.3, 0.3], (0, 0.9, 0), mail, group="pose")
    return m


def outfit_sculptor():
    m = O("sculptor", "Escultor", "Túnica cinza de artesão com avental de couro sujo de pó de mármore e capa de luar.", "#e1f5fe")
    tunic = m.mat("grey_tunic", "#78858f", rough=0.9)
    apron = m.mat("apron", "#6d5844", rough=0.85)
    cape = m.mat("moon_cape", "#1a2a4a", rough=0.8, double=True)
    _shell(m, tunic, tunic, tunic, m.mat("worn_boots", "#3a2a1f", rough=0.9))
    m.part("box", [0.34, 0.6, 0.02], (0, 1.05, -0.18), apron)
    m.part("box", [0.5, 0.95, 0.02], (0, 1.0, 0.2), cape, group="pose")
    return m


def outfit_tamer():
    m = O("tamer", "Domador", "Peles de fera sobre os ombros, colete de couro e braceletes com dentes.", "#8d6e63")
    leather = m.mat("leather", "#5d4330", rough=0.8)
    fur = m.mat("fur_mantle", "#8a6a4f", rough=1.0)
    fang = m.mat("fang", "#efe6d6", rough=0.4)
    _shell(m, leather, leather, leather, m.mat("worn_boots", "#3a2a1f", rough=0.9))
    m.part("sphere", [0.16], (0.2, 1.52, 0.02), fur, scale=(1.4, 0.7, 1.2), mirror=True)
    for i in range(5):
        m.part("cylinder", [0.0, 0.012, 0.05], (-0.1 + i * 0.05, 1.42, -0.17), fang, rot=(180, 0, 0))
    return m


def outfit_tailor():
    m = O("tailor", "Alfaiate de Guerra", "Casaca vermelha sob medida com bordados de fio de aço e luvas finas.", "#d50000")
    coat = m.mat("crimson_coat", "#8e1b1b", rough=0.6)
    embroidery = m.mat("embroidery_gold", "#ffd54f", rough=0.3, metal=0.8)
    pants = m.mat("navy_pants", "#1b2340", rough=0.8)
    _shell(m, coat, coat, pants, m.mat("leather_boots", "#1b1410", rough=0.6))
    m.part("cylinder", [0.24, 0.3, 0.5], (0, 0.88, 0), coat, group="pose")
    for i in range(4):
        m.part("sphere", [0.012], (0, 1.42 - i * 0.1, -0.17), embroidery)
    m.part("box", [0.4, 0.02, 0.02], (0, 1.52, -0.15), embroidery)
    return m


def outfit_chef():
    m = O("chef", "Chef de Caça", "Dólmã branca manchada, avental de açougueiro, lenço vermelho e chapéu de chef.", "#ff7043")
    jacket = m.mat("chef_cloth", "#f2efe8", rough=0.85)
    apron = m.mat("butcher_apron", "#7b5e4a", rough=0.85)
    scarf = m.mat("red_scarf", "#c62828", rough=0.8)
    _shell(m, jacket, jacket, m.mat("check_pants", "#3d3d3d", rough=0.85), m.mat("worn_boots", "#3a2a1f", rough=0.9))
    m.part("box", [0.36, 0.7, 0.02], (0, 1.0, -0.18), apron)
    m.part("torus", [0.07, 0.09], (0, 1.57, 0), scarf)
    m.part("cylinder", [0.11, 0.13, 0.2], (0, 1.93, 0.02), jacket)
    m.part("sphere", [0.15], (0, 2.04, 0.02), jacket, scale=(1, 0.6, 1))
    return m


# ---------------------------------------------------------------------------
# Armas das Classes Secretas Variantes (13 a 18)
# ---------------------------------------------------------------------------

def runic_sword():
    m = W("runic_sword", "Espada Rúnica", "Lâmina longa gravada com runas de fogo e gelo que brilham alternadas.", "#40c4ff")
    steel = m.mat("blade_steel", "#d6dde3", rough=0.15, metal=0.95)
    fire = m.mat("rune_fire", "#ffccbc", emit="#ff5722", energy=3.0, anim={"type": "glow", "speed": 1.6, "min": 0.5, "max": 1.3})
    ice = m.mat("rune_ice", "#e1f5fe", emit="#40c4ff", energy=3.0, anim={"type": "glow", "speed": 1.6, "min": 1.3, "max": 0.5})
    grip = m.mat("grip_leather", "#2a1f33", rough=0.8)
    m.part("cylinder", [0.022, 0.024, 0.22], (0, 0.0, 0), grip)
    m.part("box", [0.26, 0.04, 0.05], (0, 0.13, 0), steel)
    m.part("box", [0.07, 0.95, 0.018], (0, 0.62, 0), steel)
    m.part("prism", [0.07, 0.1, 0.018], (0, 1.15, 0), steel)
    for i in range(5):
        m.part("box", [0.03, 0.06, 0.022], (0, 0.3 + i * 0.16, 0), fire if i % 2 == 0 else ice)
    return m


def arcane_orb():
    m = W("arcane_orb", "Orbe Arcano Flutuante", "Esfera de cristal com chama e geada girando dentro, flutuando sobre a mão.", "#7c4dff")
    glass = m.mat("crystal_orb", "#e8eaf6", rough=0.02, alpha=0.45)
    core = m.mat("orb_core", "#b388ff", emit="#7c4dff", energy=4.5, anim={"type": "glow", "speed": 2.2, "min": 0.6, "max": 1.4})
    m.group("float", (0, 0.14, 0), anim={"type": "bob", "amp": 0.03, "speed": 2.0})
    m.part("sphere", [0.09], (0, 0.16, -0.02), glass, group="float")
    m.part("sphere", [0.05], (0, 0.16, -0.02), core, group="float")
    m.light("#7c4dff", 0.4, 1.5, (0, 0.16, -0.02))
    return m


def silver_crossbow():
    m = W("silver_crossbow", "Besta de Prata", "Besta de prata com cruz sagrada gravada e virotes de prata.", "#eceff1")
    silver = m.mat("silver", "#dfe3e6", rough=0.15, metal=1.0)
    wood = m.mat("dark_wood", "#3e2723", rough=0.7)
    string = m.mat("string", "#cfd8dc", rough=0.9)
    m.part("box", [0.05, 0.05, 0.55], (0, 0.04, -0.22), wood)
    m.part("box", [0.6, 0.03, 0.04], (0, 0.06, -0.42), silver)
    m.part("cylinder", [0.004, 0.004, 0.58], (0, 0.08, -0.36), string, rot=(0, 0, 90))
    m.part("box", [0.012, 0.012, 0.36], (0, 0.09, -0.28), silver)
    m.part("box", [0.06, 0.008, 0.02], (0, 0.075, -0.1), silver)
    m.part("box", [0.02, 0.06, 0.02], (0, 0.075, -0.1), silver)
    return m


def holy_stake():
    m = W("holy_stake", "Estaca Sagrada", "Estaca de freixo com ponta de prata e fita benta.", "#d7ccc8")
    wood = m.mat("ash_wood", "#a1887f", rough=0.8)
    silver = m.mat("silver", "#dfe3e6", rough=0.15, metal=1.0)
    ribbon = m.mat("blessed_ribbon", "#fff8e1", emit="#ffd54f", energy=1.0)
    m.part("cylinder", [0.022, 0.026, 0.3], (0, 0.1, 0), wood)
    m.part("cylinder", [0.0, 0.022, 0.08], (0, 0.29, 0), silver)
    m.part("torus", [0.024, 0.032], (0, 0.02, 0), ribbon)
    return m


def golden_spear():
    m = W("golden_spear", "Lança Dourada da Valquíria", "Lança longa de ouro com lâmina em asa e faíscas de trovão.", "#ffd54f")
    gold = m.mat("gold", "#ffca28", rough=0.15, metal=1.0)
    shaft = m.mat("white_shaft", "#f5f5f5", rough=0.4)
    spark = m.mat("thunder", "#fffde7", emit="#ffee58", energy=4.0, anim={"type": "flicker", "speed": 8.0, "min": 0.4, "max": 1.0})
    m.part("cylinder", [0.02, 0.022, 1.7], (0, 0.45, 0), shaft)
    m.part("cylinder", [0.0, 0.05, 0.32], (0, 1.45, 0), gold)
    m.part("box", [0.18, 0.04, 0.02], (0, 1.28, 0), gold)
    m.part("box", [0.006, 0.26, 0.006], (0.03, 1.45, 0), spark, rot=(0, 0, 10))
    return m


def winged_shield():
    m = W("winged_shield", "Escudo Alado", "Escudo redondo dourado com asas de penas brancas nas laterais.", "#fff59d")
    gold = m.mat("gold", "#ffca28", rough=0.2, metal=1.0)
    feather = m.mat("feather_white", "#ffffff", rough=0.8)
    m.part("cylinder", [0.3, 0.3, 0.05], (0, 0.1, -0.08), gold, rot=(90, 0, 0))
    m.part("sphere", [0.07], (0, 0.1, -0.11), gold)
    for side in (-1, 1):
        for k in range(3):
            m.part("box", [0.24 - k * 0.04, 0.05, 0.012], (side * (0.36 + k * 0.03), 0.18 - k * 0.07, -0.08), feather,
                   rot=(0, 0, side * (25 + k * 12)))
    return m


def shadow_gauntlet():
    m = W("shadow_gauntlet", "Manopla Sombria", "Manopla negra de couro e aço com névoa violeta nos nós dos dedos (usada em par).", "#7e57c2")
    leather = m.mat("black_leather", "#1d1a22", rough=0.7)
    steel = m.mat("dark_steel", "#3a3442", rough=0.3, metal=0.85)
    mist = m.mat("shadow_mist", "#b39ddb", emit="#673ab7", energy=2.5, alpha=0.7, anim={"type": "glow", "speed": 1.5, "min": 0.5, "max": 1.2})
    m.part("sphere", [0.07], (0, 0.02, 0), leather, scale=(1.0, 1.15, 1.05))
    m.part("cylinder", [0.066, 0.058, 0.15], (0, -0.08, 0), leather)
    for i in range(4):
        m.part("box", [0.028, 0.03, 0.03], ((i - 1.5) * 0.032, 0.085, -0.05), steel)
    m.part("sphere", [0.06], (0, 0.09, -0.06), mist)
    return m


def crimson_hammer():
    m = W("crimson_hammer", "Martelo Carmesim", "Martelo de forja de ferro sangrento com veias pulsantes.", "#c62828")
    iron = m.mat("blood_iron", "#4a1414", rough=0.4, metal=0.85)
    vein = m.mat("blood_vein", "#ff8a80", emit="#d50000", energy=2.5, anim={"type": "glow", "speed": 1.2, "min": 0.5, "max": 1.3})
    wood = m.mat("dark_wood", "#2b1b17", rough=0.8)
    m.part("cylinder", [0.024, 0.028, 0.7], (0, 0.15, 0), wood)
    m.part("box", [0.18, 0.16, 0.32], (0, 0.56, 0), iron)
    for i in range(3):
        m.part("box", [0.006, 0.14, 0.008], ((i - 1) * 0.05, 0.56, -0.162), vein, rot=(0, 0, (i - 1) * 20))
    return m


def living_sword():
    m = W("living_sword", "Espada Viva", "Espada demoníaca com olho no guarda-mão e lâmina orgânica dentada.", "#b71c1c")
    flesh = m.mat("blade_flesh", "#5d1010", rough=0.35, metal=0.4)
    bone = m.mat("bone_teeth", "#e6dccb", rough=0.4)
    eye = m.mat("demon_eye", "#ffeb3b", emit="#ff6f00", energy=5.0)
    m.part("cylinder", [0.022, 0.024, 0.2], (0, 0.0, 0), m.mat("grip_wrap", "#1a0d0d", rough=0.9))
    m.part("sphere", [0.05], (0, 0.13, 0), flesh, scale=(1.6, 0.8, 0.8))
    m.part("sphere", [0.02], (0, 0.13, -0.035), eye)
    m.part("box", [0.08, 0.8, 0.02], (0, 0.55, 0), flesh)
    for i in range(6):
        m.part("cylinder", [0.0, 0.012, 0.035], (0.045, 0.25 + i * 0.11, 0), bone, rot=(0, 0, -90))
    return m


def scalpel():
    m = W("scalpel", "Bisturi Cirúrgico", "Bisturi fino de aço polido usado pelo Doutor Corvo.", "#cfd8dc")
    steel = m.mat("surgical_steel", "#e3e9ee", rough=0.1, metal=1.0)
    m.part("cylinder", [0.012, 0.014, 0.14], (0, 0.0, 0), steel)
    m.part("box", [0.02, 0.07, 0.004], (0.004, 0.1, 0), steel)
    m.part("prism", [0.02, 0.03, 0.004], (0.004, 0.15, 0), steel)
    return m


def censer():
    m = W("censer", "Incensário do Corvo", "Incensário de latão pendurado em correntes, soltando fumaça verde purificadora.", "#7cb342")
    brass = m.mat("brass", "#c9a24a", rough=0.3, metal=0.95)
    smoke = m.mat("green_smoke", "#c5e1a5", emit="#7cb342", energy=1.5, alpha=0.4, anim={"type": "glow", "speed": 1.0, "min": 0.4, "max": 1.0})
    m.part("cylinder", [0.004, 0.004, 0.3], (0, -0.12, 0), brass)
    m.group("swing", (0, 0, 0), anim={"type": "sway", "axis": [1, 0, 0], "amp": 12.0, "speed": 1.8})
    m.part("sphere", [0.07], (0, -0.32, 0), brass, group="swing", scale=(1, 1.2, 1))
    m.part("sphere", [0.09], (0, -0.2, 0), smoke, group="swing")
    return m


def outfit_plague_doctor():
    m = O("plague_doctor", "Médico da Peste", "Sobretudo de couro encerado, chapéu de aba larga e máscara de corvo com lentes.", "#7cb342")
    coat = m.mat("waxed_leather", "#2b2622", rough=0.55)
    hat = m.mat("black_hat", "#1a1714", rough=0.7)
    mask = m.mat("crow_mask", "#d7ccc8", rough=0.6)
    lens = m.mat("lens_glass", "#a5d6a7", emit="#7cb342", energy=1.5)
    _shell(m, coat, coat, coat, m.mat("leather_boots", "#1b1410", rough=0.6))
    m.part("cylinder", [0.24, 0.34, 0.75], (0, 0.82, 0), coat, group="pose")
    m.part("cylinder", [0.0, 0.05, 0.22], (0, 1.68, -0.2), mask, rot=(-80, 0, 0))
    m.part("sphere", [0.025], (0.045, 1.74, -0.12), lens, mirror=True)
    m.part("cylinder", [0.25, 0.25, 0.02], (0, 1.86, 0.02), hat)
    m.part("cylinder", [0.13, 0.14, 0.14], (0, 1.93, 0.02), hat)
    return m


def outfit_valkyrie():
    m = O("valkyrie", "Valquíria da Égide", "Armadura dourada e branca com elmo alado e saia de placas.", "#fff59d")
    gold = m.mat("gold_plate", "#e0b84a", rough=0.25, metal=0.95)
    white = m.mat("white_cloth", "#f5f5f5", rough=0.8)
    feather = m.mat("feather_white", "#ffffff", rough=0.8)
    _shell(m, gold, white, white, m.mat("steel_boots", "#c9b58a", rough=0.3, metal=0.85))
    m.part("cylinder", [0.24, 0.32, 0.32], (0, 0.88, 0), gold, group="pose")
    m.part("sphere", [0.14], (0, 1.78, 0.02), gold, scale=(1.05, 0.8, 1.05))
    for side in (-1, 1):
        m.part("box", [0.16, 0.05, 0.012], (side * 0.17, 1.84, 0.0), feather, rot=(0, 0, side * 30))
    return m


WEAPONS_CLASSES = [assassin_dagger, heavy_gauntlet, colossal_shield, short_mace, sculptor_chisel, coiled_whip,
                   golden_needle, giant_cleaver, iron_wok, guardian_statue, tamed_beast,
                   runic_sword, arcane_orb, silver_crossbow, holy_stake, golden_spear, winged_shield,
                   shadow_gauntlet, crimson_hammer, living_sword, scalpel, censer]
OUTFITS_CLASSES = [outfit_assassin, outfit_fighter, outfit_shieldbearer, outfit_sculptor, outfit_tamer, outfit_tailor,
                   outfit_chef, outfit_plague_doctor, outfit_valkyrie]
