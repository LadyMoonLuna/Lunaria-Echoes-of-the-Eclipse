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


WEAPONS_CLASSES = [assassin_dagger, heavy_gauntlet, colossal_shield, short_mace, sculptor_chisel, coiled_whip,
                   golden_needle, giant_cleaver, iron_wok, guardian_statue, tamed_beast]
OUTFITS_CLASSES = [outfit_assassin, outfit_fighter, outfit_shieldbearer, outfit_sculptor, outfit_tamer, outfit_tailor,
                   outfit_chef]
