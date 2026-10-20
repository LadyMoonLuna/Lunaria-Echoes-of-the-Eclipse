"""Modelos 3D das 10 raças lendárias (IDs 19-28) de Lunaria."""

import math

from modelkit import (Model, humanoid, flower, mushroom, ghost_copy,
                      v_add, v_lerp, euler_to_mat, mmul, mat_to_euler, align_y)


# ---------------------------------------------------------------------------
# 19 — Sylvari
# ---------------------------------------------------------------------------
def sylvari():
    m = Model(19, "sylvari", "Sylvari", "Nascido da Seiva",
              "Quando o sangue das batalhas começou a envenenar o solo do Bosque Sussurrante, "
              "a antiga Árvore-Mãe chorou lágrimas de âmbar e moldou guardiões feitos de madeira viva, "
              "folhas lunares e seiva dourada. Os Sylvari parecem elfos esculpidos em carvalho e flores "
              "que desabrocham à noite.",
              "#4caf50", scale=1.04)
    bark = m.mat("bark", "#7a5536", rough=0.95)
    bark_d = m.mat("bark_dark", "#4e3423", rough=0.95)
    moss = m.mat("moss", "#5f8f2f", rough=1.0)
    leaf = m.mat("leaf", "#2e7d32", rough=0.8, double=True)
    leaf_l = m.mat("leaf_lunar", "#c8f0f4", rough=0.4, emit="#80deea", energy=1.1, double=True)
    sap = m.mat("sap", "#ffb300", rough=0.2, emit="#ffa000", energy=2.6,
                anim={"type": "glow", "speed": 1.6, "min": 0.55, "max": 1.3})
    petal = m.mat("petal", "#f3e5f5", rough=0.5, emit="#ce93d8", energy=1.6, double=True,
                  anim={"type": "glow", "speed": 0.9, "min": 0.6, "max": 1.4})
    eye = m.mat("eye", "#ffd54f", emit="#ffb300", energy=5.0)

    humanoid(m, bark, bark, bark_d, bark_d, eye=eye, w=0.92)

    # Faixa de musgo cruzando o peito e veias de seiva âmbar
    m.part("box", [0.06, 0.42, 0.31], (0, 1.25, 0), moss, rot=(0, 0, 32))
    m.part("box", [0.022, 0.3, 0.02], (0.07, 1.22, -0.152), sap, rot=(0, 0, 12), mirror=True)
    m.part("box", [0.02, 0.18, 0.02], (0, 1.12, -0.156), sap)
    m.part("box", [0.018, 0.22, 0.02], (0.3, 1.06, -0.1), sap, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("box", [0.08, 0.3, 0.02], (0.0, 1.0, -0.12), moss, rot=(8, 0, 0))

    # Orelhas élficas de madeira
    m.part("cylinder", [0.0, 0.026, 0.13], (0.135, 1.735, 0.01), bark, rot=(0, 0, -68), mirror=True)

    # Cabelo de folhas (verdes e lunares) com leve balanço
    m.group("hair", (0, 1.75, 0.02), anim={"type": "sway", "axis": [0, 0, 1], "amp": 3.0, "speed": 1.3})
    leaves = [
        ((0.0, 1.86, 0.03), (20, 0, 0), leaf, (0.55, 1.5, 0.16)),
        ((0.085, 1.83, 0.04), (22, 0, -38), leaf_l, (0.5, 1.4, 0.16)),
        ((-0.085, 1.83, 0.04), (22, 0, 38), leaf, (0.5, 1.4, 0.16)),
        ((0.12, 1.76, 0.06), (35, 0, -62), leaf, (0.45, 1.3, 0.16)),
        ((-0.12, 1.76, 0.06), (35, 0, 62), leaf_l, (0.45, 1.3, 0.16)),
        ((0.05, 1.74, 0.12), (70, 0, -18), leaf_l, (0.5, 1.5, 0.16)),
        ((-0.05, 1.74, 0.12), (70, 0, 18), leaf, (0.5, 1.5, 0.16)),
        ((0.0, 1.62, 0.13), (12, 0, 0), leaf, (0.6, 2.3, 0.16)),
        ((0.07, 1.58, 0.11), (10, 0, -10), leaf_l, (0.45, 1.9, 0.16)),
        ((-0.07, 1.58, 0.11), (10, 0, 10), leaf_l, (0.45, 1.9, 0.16)),
    ]
    for pos, rot, mat, sc in leaves:
        m.part("sphere", [0.085], pos, mat, rot=rot, scale=sc, group="hair")
    m.part("sphere", [0.128], (0, 1.75, 0.025), leaf, scale=(1.03, 1.0, 1.0), group="hair")

    # Galhos-chifre
    m.chain([(0.06, 1.83, 0.0), (0.1, 1.95, 0.02), (0.13, 2.04, 0.06)], [0.022, 0.014, 0.004], bark_d, mirror=True)
    m.seg((0.1, 1.95, 0.02), (0.17, 1.99, -0.01), 0.01, 0.003, bark_d, mirror=True)

    # Flores noturnas no ombro e no cabelo
    flower(m, (0.27, 1.585, 0.0), 0.05, petal, sap, petals=6, group="arm_r")
    flower(m, (-0.1, 1.86, -0.03), 0.04, petal, sap, petals=5, tilt=35, group="hair")
    flower(m, (-0.05, 1.37, -0.16), 0.03, petal, sap, petals=5, tilt=60)

    # Raízes nos pés
    for ang in (-35, 15):
        m.part("cylinder", [0.004, 0.02, 0.16], (0.13, 0.025, -0.13), bark_d,
               rot=(-86, ang - 10, 0), group="leg_r", mirror=True)
    m.part("cylinder", [0.02, 0.04, 0.12], (0.11, 0.48, 0), moss, group="leg_r", mirror=True)

    m.light("#ffcc66", 0.6, 2.5, (0, 1.3, -0.7))
    return m


# ---------------------------------------------------------------------------
# 20 — Myconid
# ---------------------------------------------------------------------------
def myconid():
    m = Model(20, "myconid", "Myconid", "Esporiano do Véu Fúngico",
              "Nas galerias subterrâneas e úmidas dos Esgotos Antigos da Vila, colônias de fungos "
              "bioluminescentes cresceram sobre os corpos de antigos alquimistas e guerreiros esquecidos. "
              "Ao longo de séculos, o micélio absorveu as memórias e almas dos mortos, erguendo-se em corpos "
              "humanoides cobertos por mantos de cogumelos azuis e violetas que brilham no escuro.",
              "#9c27b0", scale=0.97, seed=20)
    flesh = m.mat("flesh", "#c8b8ae", rough=0.9)
    flesh_d = m.mat("flesh_dark", "#7d6458", rough=0.9)
    cap = m.mat("cap_violet", "#5e35b1", rough=0.5, emit="#7c4dff", energy=0.7)
    cap_b = m.mat("cap_blue", "#1565c0", rough=0.5, emit="#40c4ff", energy=0.9)
    gill = m.mat("gill", "#d1c4e9", rough=0.8, emit="#b388ff", energy=0.4)
    spot = m.mat("spot", "#e0f7fa", emit="#18ffff", energy=3.2,
                 anim={"type": "glow", "speed": 1.2, "min": 0.5, "max": 1.3})
    mantle = m.mat("mantle", "#2a1660", rough=0.95)
    eye = m.mat("eye", "#84ffff", emit="#18ffff", energy=5.0)
    spore = m.mat("spore", "#e1bee7", emit="#b388ff", energy=4.0, alpha=0.85,
                  anim={"type": "glow", "speed": 2.4, "min": 0.3, "max": 1.4})
    myc = m.mat("mycelium", "#e8eaf6", rough=0.6, emit="#b2ebf2", energy=0.8)

    humanoid(m, flesh, mantle, flesh_d, flesh_d, w=1.18, head=False)

    # Cabeça: rosto fúngico sob um enorme chapéu de cogumelo
    m.part("sphere", [0.12], (0, 1.69, 0), flesh, scale=(1.05, 1.0, 1.0))
    m.part("sphere", [0.024], (0.045, 1.7, -0.105), eye, scale=(1.2, 0.8, 1), mirror=True)
    m.part("box", [0.06, 0.012, 0.01], (0, 1.64, -0.115), flesh_d)
    m.group("cap", (0, 1.8, 0), anim={"type": "bob", "amp": 0.008, "speed": 1.6})
    m.part("cylinder", [0.3, 0.2, 0.05], (0, 1.8, 0), gill, group="cap")
    m.part("sphere", [0.32], (0, 1.85, 0), cap, scale=(1, 0.5, 1), group="cap")
    m.part("torus", [0.29, 0.33], (0, 1.81, 0), cap_b, scale=(1, 0.6, 1), group="cap")
    for i in range(14):
        a = i * 2.39996
        rr = 0.08 + 0.2 * ((i * 0.37) % 1.0)
        x, z = math.cos(a) * rr, math.sin(a) * rr
        y = 1.85 + 0.16 * math.sqrt(max(0.0, 1 - (rr / 0.32) ** 2))
        m.part("sphere", [0.022 + 0.012 * (i % 3)], (x, y, z), spot, scale=(1, 0.5, 1), group="cap")

    # Manto de cogumelos
    m.part("cylinder", [0.25, 0.4, 0.72], (0, 0.93, 0.02), mantle)
    m.part("torus", [0.36, 0.43], (0, 0.58, 0.02), cap)
    m.part("sphere", [0.2], (0, 1.5, 0.02), mantle, scale=(1.55, 0.55, 1.15))
    clusters = [
        ((0.27, 1.55, 0.02), 0.09, (0, 0, -35), cap_b),
        ((0.22, 1.6, 0.1), 0.06, (25, 0, -20), cap),
        ((0.32, 1.5, -0.05), 0.05, (-20, 0, -55), cap),
        ((0.0, 1.58, 0.16), 0.08, (45, 0, 0), cap),
        ((0.12, 1.4, 0.2), 0.06, (60, 0, -15), cap_b),
        ((-0.09, 1.25, 0.22), 0.07, (70, 0, 10), cap_b),
        ((0.3, 0.7, 0.2), 0.07, (50, 0, -40), cap_b),
        ((0.38, 0.62, -0.05), 0.06, (-10, 0, -70), cap),
        ((0.0, 0.62, 0.42), 0.06, (75, 0, 0), cap),
    ]
    for base, r, tilt, cmat in clusters:
        mushroom(m, base, r * 0.9, r, myc, cmat, tilt, spot_mat=spot)
        mushroom(m, (-base[0], base[1] - 0.04, base[2] - 0.03), r * 0.8, r * 0.85, myc,
                 cap if cmat == cap_b else cap_b, (tilt[0], -tilt[1], -tilt[2]), spot_mat=spot)
    mushroom(m, (0.31, 1.15, -0.04), 0.05, 0.045, myc, cap_b, (0, 0, -60), group="arm_r", spot_mat=spot)

    # Micélio saindo dos pés
    for ang in (-50, 0, 40):
        m.part("cylinder", [0.003, 0.012, 0.22], (0.13, 0.015, -0.12), myc,
               rot=(-88, ang, 0), group="leg_r", mirror=True)

    # Nuvem de esporos orbitando
    m.group("spores", (0, 1.2, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 22})
    for i in range(16):
        a = i * 2 * math.pi / 16 + m.rng.uniform(-0.2, 0.2)
        r = m.rng.uniform(0.42, 0.62)
        y = 1.2 + m.rng.uniform(-0.6, 0.75)
        m.part("sphere", [m.rng.uniform(0.012, 0.024)], (math.cos(a) * r, y, math.sin(a) * r), spore,
               group="spores", anim={"type": "bob", "amp": 0.06, "speed": 1.0 + (i % 4) * 0.35, "phase": i})

    m.light("#7c4dff", 0.7, 3.0, (0, 1.6, -0.7))
    return m


# ---------------------------------------------------------------------------
# 21 — Aracne (Tecelões da Bruma)
# ---------------------------------------------------------------------------
def aracne():
    m = Model(21, "aracne", "Aracne", "Tecelão da Bruma",
              "Ocultos nas fendas escuras onde a Bruma de Cinzavale nunca se dissipa, os Tecelões da Bruma "
              "são os filhos de Arachna, a Dama do Fio Prateado. Possuem pele pálida como porcelana, seis olhos "
              "rubros (quatro menores na testa) e a capacidade de produzir seda mais resistente que o aço de "
              "Garrick e veneno neurotóxico.",
              "#eceff1", scale=1.02, seed=21)
    skin = m.mat("porcelain", "#f4efea", rough=0.22)
    cloth = m.mat("silk_black", "#18181d", rough=0.45, metal=0.15)
    silver = m.mat("silver", "#d5dde2", rough=0.18, metal=0.95)
    chitin = m.mat("chitin", "#1d1d24", rough=0.25, metal=0.35)
    hair = m.mat("hair", "#0e0e12", rough=0.5)
    eye = m.mat("eye", "#ff1744", emit="#ff1744", energy=3.5)
    silk = m.mat("silk", "#ffffff", rough=0.3, emit="#e0f7fa", energy=0.9, alpha=0.7)
    venom = m.mat("venom", "#b2ff59", emit="#76ff03", energy=2.5,
                  anim={"type": "glow", "speed": 2.0, "min": 0.4, "max": 1.2})

    humanoid(m, skin, cloth, cloth, cloth, w=0.88)

    # Seis olhos rubros: dois principais + quatro na testa
    m.part("sphere", [0.02], (0.045, 1.72, -0.113), eye, scale=(1.3, 0.8, 1), mirror=True)
    m.part("sphere", [0.011], (0.024, 1.775, -0.114), eye, mirror=True)
    m.part("sphere", [0.01], (0.062, 1.765, -0.104), eye, mirror=True)
    # Presas com veneno
    m.part("cylinder", [0.0, 0.006, 0.025], (0.014, 1.635, -0.112), venom, rot=(180, 0, 0), mirror=True)

    # Cabelo longo negro e tiara prateada
    m.part("sphere", [0.133], (0, 1.735, 0.028), hair, scale=(1.04, 1.04, 1.04))
    m.part("capsule", [0.1, 0.62], (0, 1.45, 0.11), hair, scale=(1.25, 1, 0.45))
    m.part("capsule", [0.035, 0.34], (0.1, 1.58, -0.02), hair, rot=(0, 0, -6), mirror=True)
    m.part("torus", [0.123, 0.134], (0, 1.81, 0.0), silver, rot=(-12, 0, 0))
    m.part("sphere", [0.016], (0, 1.825, -0.126), venom)

    # Vestes: corpete prateado, cinto e saia de seda
    m.part("box", [0.03, 0.42, 0.02], (0, 1.24, -0.158), silver)
    m.part("torus", [0.18, 0.21], (0, 1.02, 0), silver, scale=(1.05, 1, 0.8))
    m.part("cylinder", [0.2, 0.3, 0.48], (0, 0.82, 0), cloth)
    m.part("cylinder", [0.07, 0.068, 0.12], (0.3, 1.0, -0.09), silver, rot=(30, 0, 6), group="arm_r", mirror=True)

    # Quatro patas de aranha nas costas (balançam como se tateassem a bruma)
    legs = [
        ((0.07, 1.4, 0.14), (0.42, 1.82, 0.32), (0.66, 1.15, 0.38), 0.0),
        ((0.07, 1.24, 0.15), (0.5, 1.5, 0.42), (0.78, 0.72, 0.5), 1.4),
    ]
    for idx, (p0, knee, tip, phase) in enumerate(legs):
        g = m.group("sleg%d_r" % idx, p0, mirror=True,
                    anim={"type": "sway", "axis": [0, 1, 0], "amp": 7.0, "speed": 1.7, "phase": phase})
        mid = v_lerp(knee, tip, 0.55)
        m.chain([p0, knee, mid, tip], [0.03, 0.024, 0.017, 0.0], chitin, group=g, mirror=True, joints=silver)
        m.part("sphere", [0.036], p0, silver, group=g, mirror=True)
    m.part("sphere", [0.09], (0, 1.32, 0.15), chitin, scale=(1.2, 1.3, 0.7))
    m.part("sphere", [0.03], (0, 1.32, 0.205), eye, scale=(1, 1.6, 0.5))

    # Fios de seda pendendo das mãos
    m.part("cylinder", [0.003, 0.003, 0.5], (0.33, 0.62, -0.16), silk, group="arm_r", mirror=True)
    m.part("cylinder", [0.002, 0.002, 0.7], (0.12, 1.0, 0.22), silk, rot=(10, 0, -8), mirror=True)

    m.light("#ff1744", 0.45, 2.0, (0, 1.75, -0.7))
    return m


# ---------------------------------------------------------------------------
# 22 — Draconato de Cinzas (Escama-Negra)
# ---------------------------------------------------------------------------
def draconato():
    m = Model(22, "draconato", "Draconato de Cinzas", "Escama-Negra",
              "Enquanto os Varkai são descendentes de humanos que beberam sangue de feras e dragões, os "
              "Escama-Negra são a prole pura dos Dragões Primordiais que dormiam sob os vulcões de Lunaria. "
              "Com chifres de obsidiana, cauda pesada, placas de escamas negras nos ombros e olhos de ouro "
              "derretido, eles caminham como reis antigos entre os mortais.",
              "#ff6d00", scale=1.14, seed=22)
    scale_ = m.mat("scale_black", "#1b1b20", rough=0.4, metal=0.45)
    plate = m.mat("scale_plate", "#2a2a31", rough=0.28, metal=0.7)
    obs = m.mat("obsidian", "#2a2536", rough=0.08, metal=0.6, emit="#3d1a00", energy=0.4)
    belly = m.mat("belly", "#3b2a22", rough=0.6)
    magma = m.mat("magma", "#ff6d00", emit="#ff3d00", energy=3.0,
                  anim={"type": "glow", "speed": 1.1, "min": 0.6, "max": 1.35})
    eye = m.mat("eye_gold", "#ffd740", emit="#ffab00", energy=6.5)
    claw = m.mat("claw", "#d7ccc8", rough=0.3)

    humanoid(m, scale_, scale_, scale_, plate, w=1.18, head=False)

    # Cabeça dracônica com focinho
    m.part("sphere", [0.13], (0, 1.73, 0.01), scale_, scale=(1, 1.0, 1.1))
    m.part("box", [0.15, 0.085, 0.17], (0, 1.68, -0.14), scale_, rot=(10, 0, 0))
    m.part("box", [0.13, 0.04, 0.15], (0, 1.625, -0.12), plate, rot=(4, 0, 0))
    m.part("sphere", [0.012], (0.035, 1.705, -0.225), magma, mirror=True)
    m.part("sphere", [0.022], (0.058, 1.75, -0.105), eye, scale=(1.5, 0.65, 1), mirror=True)
    m.part("box", [0.07, 0.015, 0.06], (0.055, 1.775, -0.1), plate, rot=(0, 0, -12), mirror=True)

    # Chifres de obsidiana varridos para trás
    m.chain([(0.07, 1.82, -0.01), (0.11, 1.93, 0.08), (0.14, 1.98, 0.22), (0.15, 1.97, 0.36)],
            [0.042, 0.032, 0.018, 0.0], obs, mirror=True)
    m.chain([(0.11, 1.75, 0.04), (0.17, 1.78, 0.14), (0.2, 1.76, 0.24)], [0.024, 0.014, 0.0], obs, mirror=True)
    for i, y in enumerate((1.86, 1.77, 1.62, 1.5, 1.36, 1.2)):
        z = 0.12 + 0.06 * min(i, 2) if i < 3 else 0.17
        m.part("cylinder", [0.0, 0.03 - i * 0.002, 0.11 - i * 0.008], (0, y, z), obs, rot=(60, 0, 0))

    # Placas de escamas sobrepostas nos ombros
    m.part("box", [0.26, 0.05, 0.28], (0.3, 1.6, 0.0), plate, rot=(0, 0, -22), group="arm_r", mirror=True)
    m.part("box", [0.24, 0.05, 0.26], (0.37, 1.53, 0.0), plate, rot=(0, 0, -42), group="arm_r", mirror=True)
    m.part("box", [0.2, 0.045, 0.22], (0.41, 1.44, 0.0), plate, rot=(0, 0, -62), group="arm_r", mirror=True)
    m.part("cylinder", [0.0, 0.028, 0.12], (0.33, 1.67, 0.02), obs, rot=(0, 0, -25), group="arm_r", mirror=True)
    m.part("cylinder", [0.0, 0.022, 0.09], (0.42, 1.58, 0.02), obs, rot=(0, 0, -45), group="arm_r", mirror=True)

    # Placas do ventre e veias de magma
    for i in range(5):
        y = 1.42 - i * 0.085
        m.part("box", [0.24 - abs(i - 2) * 0.03, 0.06, 0.04], (0, y, -0.145 + abs(i - 2) * 0.005), belly)
    m.part("box", [0.02, 0.32, 0.02], (0.13, 1.26, -0.13), magma, rot=(0, 25, 14), mirror=True)
    m.part("box", [0.016, 0.24, 0.016], (0.32, 1.05, -0.1), magma, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("box", [0.016, 0.3, 0.016], (0.14, 0.7, -0.08), magma, rot=(0, 0, 5), group="leg_r", mirror=True)

    # Garras
    for dx in (-0.02, 0.0, 0.02):
        m.part("cylinder", [0.0, 0.008, 0.05], (0.32 + dx, 0.84, -0.17), claw, rot=(20, 0, 0), group="arm_r", mirror=True)
        m.part("cylinder", [0.0, 0.01, 0.05], (0.11 + dx * 1.5, 0.03, -0.19), claw, rot=(-80, 0, 0), group="leg_r", mirror=True)

    # Cauda pesada, articulada em 3 segmentos que ondulam
    pts = [(0, 0.95, 0.12), (0, 0.78, 0.42), (0, 0.5, 0.72), (0, 0.24, 1.0), (0, 0.12, 1.34)]
    rad = [0.13, 0.105, 0.08, 0.055, 0.0]
    parent = None
    for i in range(4):
        g = m.group("tail%d" % i, pts[i], parent,
                    anim={"type": "sway", "axis": [0, 1, 0], "amp": 6.0 + i * 2.5, "speed": 1.3, "phase": i * 0.7})
        m.seg(pts[i], pts[i + 1], rad[i], rad[i + 1], scale_, group=g)
        m.part("sphere", [rad[i]], pts[i], scale_, group=g)
        mid = v_lerp(pts[i], pts[i + 1], 0.5)
        m.part("cylinder", [0.0, 0.024, 0.1 - i * 0.015], v_add(mid, (0, rad[i] * 0.85, 0)), obs,
               rot=(35, 0, 0), group=g)
        parent = g

    m.light("#ff6d00", 0.8, 3.0, (0, 1.2, -0.4))
    return m


# ---------------------------------------------------------------------------
# 23 — Quimera
# ---------------------------------------------------------------------------
def quimera():
    m = Model(23, "quimera", "Quimera", "Obra-Prima Proibida",
              "A obra-prima proibida do antigo Mestre Alquimista que foi traído pelos guardas e jogado nos "
              "esgotos da vila. Em sua loucura subterrânea às três da manhã, ele descobriu como fundir carne "
              "mortal com órgãos perfeitos das feras de Lunaria, criando um ser mutante capaz de remodelar a "
              "própria biologia conforme se alimenta.",
              "#76ff03", scale=1.05, seed=23)
    flesh = m.mat("flesh", "#c49a84", rough=0.6)
    mut = m.mat("flesh_mutant", "#6f7f52", rough=0.55, metal=0.1)
    scar = m.mat("stitch", "#2b1d16", rough=0.9)
    fur = m.mat("fur", "#4e3629", rough=1.0)
    bone = m.mat("bone", "#efe7da", rough=0.5)
    claw = m.mat("claw", "#20262b", rough=0.3, metal=0.3)
    acid = m.mat("acid", "#b2ff59", emit="#64dd17", energy=3.2,
                 anim={"type": "glow", "speed": 2.6, "min": 0.4, "max": 1.4})
    eye_g = m.mat("eye_acid", "#ccff90", emit="#76ff03", energy=6.0)
    eye_y = m.mat("eye_yellow", "#ffff8d", emit="#ffea00", energy=5.0)
    leather = m.mat("leather", "#3e2c22", rough=0.8)

    # Corpo humano costurado; braço direito será substituído por um membro bestial
    m.group("leg_r", (0.12, 0.94, 0), mirror=True)
    m.part("capsule", [0.092, 0.5], (0.12, 0.7, 0), fur, group="leg_r", mirror=True)
    m.part("capsule", [0.075, 0.46], (0.12, 0.3, 0), mut, group="leg_r", mirror=True)
    m.part("box", [0.14, 0.07, 0.24], (0.12, 0.035, -0.05), claw, group="leg_r", mirror=True)
    for dx in (-0.035, 0.0, 0.035):
        m.part("cylinder", [0.0, 0.012, 0.06], (0.12 + dx, 0.03, -0.19), bone, rot=(-80, 0, 0), group="leg_r", mirror=True)
    m.part("capsule", [0.12, 0.4], (0, 0.98, 0), leather, rot=(0, 0, 90))
    m.part("sphere", [0.2], (0, 1.27, 0), flesh, scale=(1.3, 1.45, 0.82))
    m.part("sphere", [0.17], (0.1, 1.32, 0.02), mut, scale=(1.0, 1.2, 0.85))
    m.part("cylinder", [0.055, 0.06, 0.14], (0, 1.57, 0), flesh)
    m.part("torus", [0.055, 0.066], (0, 1.56, 0), scar)
    m.part("sphere", [0.125], (0, 1.71, 0), flesh, scale=(1, 1.08, 1.02))
    m.part("sphere", [0.09], (0.05, 1.74, 0.02), mut, scale=(1.0, 1.0, 1.1))
    m.part("sphere", [0.027], (0.048, 1.725, -0.11), eye_g, mirror=False)
    m.part("sphere", [0.016], (-0.045, 1.715, -0.113), eye_y)
    m.part("box", [0.08, 0.03, 0.05], (0, 1.635, -0.1), mut)
    for dx in (-0.025, 0.0, 0.025):
        m.part("cylinder", [0.0, 0.007, 0.03], (dx, 1.615, -0.12), bone, rot=(180, 0, 0))
    # Chifre único e toco quebrado
    m.chain([(0.07, 1.82, -0.02), (0.12, 1.94, -0.04), (0.14, 2.04, 0.02)], [0.03, 0.018, 0.0], bone)
    m.part("cylinder", [0.018, 0.026, 0.04], (-0.07, 1.82, 0.0), bone, rot=(0, 0, 20))

    # Costuras pelo corpo
    m.part("box", [0.012, 0.42, 0.02], (0.015, 1.27, -0.16), scar, rot=(0, 0, -8))
    for i in range(6):
        m.part("box", [0.05, 0.008, 0.02], (0.015 + (i - 2.5) * -0.006, 1.1 + i * 0.07, -0.162), scar)
    m.part("box", [0.3, 0.012, 0.02], (0, 1.08, -0.15), scar, rot=(0, 0, 6))

    # Braço esquerdo humano, costurado no ombro
    m.group("arm_l", (-0.27, 1.47, 0))
    m.part("sphere", [0.082], (-0.27, 1.47, 0), flesh, group="arm_l")
    m.part("torus", [0.075, 0.088], (-0.28, 1.4, 0), scar, rot=(0, 0, 8), group="arm_l")
    m.part("capsule", [0.056, 0.34], (-0.29, 1.3, 0), flesh, rot=(0, 0, -8), group="arm_l")
    m.part("capsule", [0.05, 0.3], (-0.32, 1.05, -0.06), flesh, rot=(30, 0, -6), group="arm_l")
    m.part("sphere", [0.052], (-0.33, 0.9, -0.14), flesh, scale=(0.9, 1.15, 0.9), group="arm_l")

    # Braço direito bestial com garra gigante
    m.group("arm_r", (0.3, 1.5, 0))
    m.part("sphere", [0.13], (0.31, 1.5, 0.0), fur, scale=(1.1, 1.0, 1.1), group="arm_r")
    m.part("capsule", [0.095, 0.38], (0.36, 1.28, 0), mut, rot=(0, 0, 12), group="arm_r")
    m.part("capsule", [0.09, 0.36], (0.4, 1.0, -0.07), mut, rot=(28, 0, 8), group="arm_r")
    m.part("sphere", [0.1], (0.42, 0.82, -0.16), mut, scale=(1.1, 0.9, 1.2), group="arm_r")
    for i, (dx, dz) in enumerate(((-0.06, -0.06), (0.0, -0.09), (0.06, -0.06), (0.08, 0.04))):
        p0 = (0.42 + dx, 0.8, -0.16 + dz)
        p1 = (0.42 + dx * 1.6, 0.66, -0.2 + dz * 1.8)
        m.chain([p0, p1, v_add(p1, (0, -0.06, -0.06))], [0.022, 0.012, 0.0], bone, group="arm_r")
    for i in range(3):
        m.part("cylinder", [0.0, 0.02, 0.09], (0.36 + i * 0.02, 1.2 - i * 0.12, 0.08), bone,
               rot=(70, 0, -20), group="arm_r")

    # Bolsas de ácido pulsantes e espinhos dorsais
    sacs = [((0.1, 1.38, 0.16), 0.085, 0.0), ((-0.09, 1.22, 0.17), 0.07, 1.5), ((0.02, 1.52, 0.13), 0.06, 3.0)]
    for pos, r, ph in sacs:
        m.part("sphere", [r], pos, acid, scale=(1, 1.15, 0.8),
               anim={"type": "pulse", "amp": 0.12, "speed": 3.2, "phase": ph})
    for i, y in enumerate((1.58, 1.45, 1.3, 1.15, 1.02)):
        m.part("cylinder", [0.0, 0.025, 0.12 - i * 0.012], (0.0, y, 0.15 + (0.02 if 0 < i < 4 else 0)), bone, rot=(65, 0, 0))

    # Cauda de lagarto com ferrão ácido
    pts = [(0, 0.98, 0.12), (0.05, 0.8, 0.4), (0.12, 0.55, 0.62), (0.16, 0.42, 0.88), (0.15, 0.55, 1.08)]
    rad = [0.09, 0.07, 0.055, 0.035, 0.02]
    parent = None
    for i in range(4):
        g = m.group("tail%d" % i, pts[i], parent,
                    anim={"type": "sway", "axis": [0, 1, 0], "amp": 7.0 + 3 * i, "speed": 1.8, "phase": i * 0.8})
        m.seg(pts[i], pts[i + 1], rad[i], rad[i + 1], mut, group=g)
        m.part("sphere", [rad[i]], pts[i], mut, group=g)
        parent = g
    m.part("sphere", [0.04], pts[-1], acid, group=parent)
    m.seg(pts[-1], (0.14, 0.68, 1.02), 0.022, 0.0, bone, group=parent)

    m.light("#76ff03", 0.6, 2.5, (0, 1.3, 0.5))
    return m


# ---------------------------------------------------------------------------
# 24 — Boreal
# ---------------------------------------------------------------------------
def boreal():
    m = Model(24, "boreal", "Boreal", "Guardião da Nevasca Eterna",
              "Ao norte distante das Ruínas da Vigília, além das muralhas geladas onde o sol nunca derrete a "
              "neve eterna, vivem os Boreais. Seus cabelos são brancos como nevasca, sua pele é azul-pálida e "
              "fria ao toque, e sua respiração condensa em cristais de gelo mesmo ao meio-dia. Dizem que eles "
              "guardam a prisão de gelo dos antigos deuses caídos.",
              "#80d8ff", scale=1.08, seed=24)
    skin = m.mat("skin_ice", "#b9e3f7", rough=0.35)
    hair = m.mat("hair_snow", "#fbfdff", rough=0.6, emit="#e1f5fe", energy=0.25)
    fur = m.mat("fur", "#eef1f3", rough=1.0)
    cloth = m.mat("cloth", "#1b3b5e", rough=0.75)
    silver = m.mat("silver", "#cfd8dc", rough=0.2, metal=0.9)
    crystal = m.mat("ice_crystal", "#a5e8ff", rough=0.05, metal=0.2, emit="#40c4ff", energy=1.8, alpha=0.82,
                    anim={"type": "glow", "speed": 0.8, "min": 0.7, "max": 1.3})
    eye = m.mat("eye", "#e1f5fe", emit="#80d8ff", energy=6.0)
    breath = m.mat("breath", "#ffffff", emit="#b3e5fc", energy=2.2, alpha=0.75)

    humanoid(m, skin, cloth, cloth, fur, eye=eye, w=0.98)

    # Cabelos brancos como nevasca
    m.part("sphere", [0.134], (0, 1.74, 0.025), hair, scale=(1.04, 1.05, 1.04))
    m.group("hair", (0, 1.72, 0.08), anim={"type": "sway", "axis": [1, 0, 0], "amp": 2.5, "speed": 1.1})
    m.part("capsule", [0.11, 0.78], (0, 1.38, 0.13), hair, scale=(1.3, 1, 0.42), rot=(-6, 0, 0), group="hair")
    m.part("capsule", [0.04, 0.4], (0.1, 1.56, -0.03), hair, rot=(0, 0, -5), mirror=True)

    # Coroa de gelo
    for i in range(7):
        a = math.radians(-90 + (i - 3) * 26)
        p = (math.cos(a) * 0.115, 1.83, math.sin(a) * 0.115 + 0.01)
        h = 0.14 if i == 3 else 0.09 - abs(i - 3) * 0.008
        m.part("cylinder", [0.0, 0.018, h], v_add(p, (0, h * 0.4, 0)), crystal,
               rot=(-12 * math.sin(a) * -1, 0, -12 * math.cos(a)))
    m.part("torus", [0.112, 0.124], (0, 1.82, 0.01), silver)

    # Manto de pele e capa
    m.part("torus", [0.12, 0.27], (0, 1.53, 0.01), fur, scale=(1.05, 1.4, 0.95))
    m.group("cape", (0, 1.52, 0.17), anim={"type": "sway", "axis": [1, 0, 0], "amp": 3.0, "speed": 1.2})
    m.part("box", [0.52, 1.1, 0.03], (0, 0.98, 0.21), cloth, rot=(-7, 0, 0), group="cape")
    m.part("box", [0.54, 0.06, 0.05], (0, 0.44, 0.27), fur, rot=(-7, 0, 0), group="cape")
    m.part("cylinder", [0.22, 0.3, 0.4], (0, 0.86, 0), cloth)
    m.part("torus", [0.2, 0.235], (0, 1.02, 0), silver, scale=(1.05, 1, 0.82))
    m.part("box", [0.1, 0.36, 0.02], (0, 1.3, -0.152), silver)

    # Ombreiras de cristal de gelo
    for i, (rot, h) in enumerate((((0, 0, -20), 0.22), ((15, 0, -50), 0.16), ((-20, 0, -35), 0.14), ((5, 0, -5), 0.12))):
        mrot = euler_to_mat(rot)
        up = (mrot[0][1], mrot[1][1], mrot[2][1])
        base = (0.3, 1.55, 0.0 + (i - 1.5) * 0.04)
        m.part("cylinder", [0.0, 0.035, h], v_add(base, tuple(c * h * 0.5 for c in up)), crystal, rot=rot,
               group="arm_r", mirror=True)
    m.part("sphere", [0.1], (0.28, 1.52, 0), fur, scale=(1.2, 0.8, 1.1), group="arm_r", mirror=True)
    m.part("cylinder", [0.06, 0.06, 0.1], (0.31, 0.98, -0.1), silver, rot=(30, 0, 6), group="arm_r", mirror=True)

    # Respiração que condensa em cristais
    for i in range(4):
        p = (0.03 * (i - 1.5), 1.64 - 0.02 * i, -0.18 - 0.05 * i)
        m.part("box", [0.022 - i * 0.003] * 3, p, breath, rot=(45, 45, 0),
               anim={"type": "bob", "amp": 0.02, "speed": 2.0, "phase": i * 0.9})

    # Flocos de gelo orbitando
    m.group("frost", (0, 1.1, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": -18})
    for i in range(10):
        a = i * 2 * math.pi / 10
        r = 0.55 + 0.08 * (i % 2)
        m.part("box", [0.03, 0.03, 0.03], (math.cos(a) * r, 0.5 + (i * 0.37 % 1.0) * 1.3, math.sin(a) * r),
               crystal, rot=(45, i * 20, 45), group="frost")

    m.light("#80d8ff", 0.7, 3.0, (0, 1.6, -0.7))
    return m


# ---------------------------------------------------------------------------
# 25 — Thalassiano
# ---------------------------------------------------------------------------
def thalassiano():
    m = Model(25, "thalassiano", "Thalassiano", "Herdeiro das Marés Lunares",
              "Quando a Lua rachou no céu, as marés enlouqueceram e engoliram o reino insular de Thalassia. "
              "Seus cidadãos não morreram afogados: o poder lunar nas águas profundas transformou seus pulmões "
              "e escamas, criando uma raça anfíbia de olhos bioluminescentes que governa a pressão dos oceanos "
              "e a fúria das tempestades.",
              "#006064", scale=1.05, seed=25)
    skin = m.mat("scale_teal", "#0f8c96", rough=0.28, metal=0.3)
    dark = m.mat("scale_dark", "#06474f", rough=0.35, metal=0.3)
    belly = m.mat("belly", "#8fd3c9", rough=0.4)
    fin = m.mat("fin", "#4dd0e1", rough=0.2, emit="#00e5ff", energy=0.7, alpha=0.82, double=True)
    glow = m.mat("biolum", "#a7ffeb", emit="#1de9b6", energy=4.0,
                 anim={"type": "glow", "speed": 1.5, "min": 0.35, "max": 1.3})
    eye = m.mat("eye", "#84ffff", emit="#18ffff", energy=7.0)
    pearl = m.mat("pearl", "#fff8e1", rough=0.1, metal=0.4)
    coral = m.mat("coral", "#ff7a59", rough=0.6)
    gold = m.mat("gold", "#ffca28", rough=0.2, metal=0.95)
    water = m.mat("storm_water", "#80deea", rough=0.0, emit="#00b8d4", energy=2.0, alpha=0.6,
                  anim={"type": "glow", "speed": 3.0, "min": 0.5, "max": 1.5})

    humanoid(m, skin, skin, dark, skin, hands=skin, w=1.0)
    m.part("sphere", [0.15], (0, 1.24, -0.04), belly, scale=(1.05, 1.5, 0.6))

    # Olhos grandes bioluminescentes
    m.part("sphere", [0.026], (0.048, 1.72, -0.106), eye, scale=(1.35, 0.9, 1), mirror=True)
    # Crista e barbatanas-orelha
    m.part("prism", [0.3, 0.14, 0.014], (0, 1.86, 0.05), fin, rot=(0, 90, 0))
    m.part("prism", [0.14, 0.15, 0.012], (0.135, 1.73, 0.04), fin, rot=(0, 75, -28), mirror=True)
    # Guelras
    for i in range(3):
        m.part("box", [0.008, 0.06, 0.02], (0.05 + i * 0.008, 1.57, -0.025 + i * 0.022), dark, mirror=True)
    # Pintas bioluminescentes
    spots = [(0.075, 1.775, -0.09), (0.09, 1.67, -0.08), (0.17, 1.35, -0.07), (0.19, 1.2, -0.04), (0.14, 1.05, -0.11)]
    for p in spots:
        m.part("sphere", [0.012], p, glow, mirror=True)
    for i in range(3):
        m.part("sphere", [0.01], (0.335, 1.32 - i * 0.07, -0.03), glow, group="arm_r", mirror=True)

    # Barbatana dorsal, barbatanas dos antebraços e panturrilhas
    m.part("prism", [0.36, 0.34, 0.015], (0, 1.32, 0.2), fin, rot=(15, 90, 0))
    m.part("prism", [0.2, 0.12, 0.012], (0.36, 1.06, 0.0), fin, rot=(30, 90, 6), group="arm_r", mirror=True)
    m.part("prism", [0.18, 0.12, 0.012], (0.11, 0.33, 0.1), fin, rot=(0, 90, 0), group="leg_r", mirror=True)
    m.part("prism", [0.16, 0.06, 0.08], (0.11, 0.03, -0.2), fin, rot=(-90, 0, 0), group="leg_r", mirror=True)
    m.part("prism", [0.08, 0.05, 0.012], (0.345, 0.88, -0.17), fin, rot=(30, 90, 0), group="arm_r", mirror=True)

    # Joias: colar de pérolas, ombreira de coral, braçadeiras douradas
    m.part("torus", [0.1, 0.112], (0, 1.53, -0.01), gold, rot=(-18, 0, 0))
    for i in range(7):
        a = math.radians(200 + i * 20)
        m.part("sphere", [0.016], (math.cos(a) * 0.12, 1.5 - 0.02 * math.sin(math.pi * i / 6), math.sin(a) * 0.12 - 0.02), pearl)
    m.chain([(0.3, 1.56, 0.0), (0.36, 1.66, 0.02), (0.4, 1.74, -0.01)], [0.025, 0.015, 0.004], coral, group="arm_r")
    m.chain([(0.34, 1.6, 0.03), (0.42, 1.65, 0.07)], [0.014, 0.003], coral, group="arm_r")
    m.part("sphere", [0.09], (0.28, 1.52, 0), coral, scale=(1.2, 0.7, 1.1), group="arm_r")
    m.part("cylinder", [0.058, 0.058, 0.08], (0.3, 1.0, -0.09), gold, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("torus", [0.18, 0.205], (0, 1.02, 0), gold, scale=(1.05, 1, 0.8))
    m.part("box", [0.14, 0.32, 0.02], (0, 0.84, -0.14), dark, rot=(6, 0, 0))

    # Orbes de tempestade orbitando
    m.group("storm", (0, 1.3, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 45})
    for i in range(3):
        a = i * 2 * math.pi / 3
        m.part("sphere", [0.05], (math.cos(a) * 0.55, 1.3 + 0.12 * math.sin(a * 2), math.sin(a) * 0.55), water,
               group="storm", anim={"type": "bob", "amp": 0.05, "speed": 2.2, "phase": i * 2})

    m.light("#18ffff", 0.7, 3.0, (0, 1.6, -0.7))
    return m


# ---------------------------------------------------------------------------
# 26 — Cambion
# ---------------------------------------------------------------------------
def cambion():
    m = Model(26, "cambion", "Cambion", "Herdeiro do Abismo Ardente",
              "Quando o Santuário do Eclipse abriu fendas para o submundo, legiões infernais marcharam sobre "
              "Lunaria. Os Cambions são os descendentes daqueles que sobreviveram ao cruzamento entre mortais e "
              "os senhores da guerra do abismo ardente. Possuem chifres recurvados para trás, pele em tons de "
              "cinza-carvão ou carmesim e olhos que brilham no escuro.",
              "#c62828", scale=1.06, seed=26)
    skin = m.mat("skin_charcoal", "#3b3537", rough=0.55)
    crim = m.mat("skin_crimson", "#8e1c1c", rough=0.5)
    horn = m.mat("horn", "#4a3a36", rough=0.2, metal=0.35)
    armor = m.mat("armor", "#2a0e0e", rough=0.3, metal=0.65)
    gold = m.mat("gold", "#b8860b", rough=0.25, metal=0.9)
    cloth = m.mat("cloth", "#4a0a0a", rough=0.85, double=True)
    ember = m.mat("ember", "#ff6d00", emit="#ff3d00", energy=3.2,
                  anim={"type": "glow", "speed": 2.2, "min": 0.4, "max": 1.4})
    eye = m.mat("eye", "#fff59d", emit="#ffab00", energy=7.0)

    humanoid(m, skin, armor, armor, armor, hands=crim, forearm=crim, eye=eye, w=1.06)

    # Chifres recurvados para trás
    m.chain([(0.055, 1.81, -0.05), (0.09, 1.91, 0.0), (0.12, 1.96, 0.11), (0.125, 1.92, 0.23), (0.11, 1.83, 0.29)],
            [0.036, 0.03, 0.022, 0.012, 0.0], horn, mirror=True)
    # Marcas carmesim no rosto e brasas pelo corpo
    m.part("box", [0.008, 0.06, 0.01], (0.045, 1.68, -0.115), ember, mirror=True)
    m.part("box", [0.012, 0.18, 0.012], (0.31, 1.06, -0.1), ember, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("box", [0.012, 0.16, 0.012], (0.12, 0.3, -0.07), ember, group="leg_r", mirror=True)
    m.part("box", [0.08, 0.025, 0.012], (0.0, 1.66, -0.12), crim)

    # Couraça, ombreiras com espinhos, cinto dourado e tabardo
    m.part("sphere", [0.2], (0, 1.32, -0.03), armor, scale=(1.28, 1.25, 0.72))
    m.part("box", [0.03, 0.34, 0.02], (0, 1.3, -0.175), gold)
    m.part("sphere", [0.032], (0, 1.38, -0.18), ember)
    m.part("sphere", [0.11], (0.29, 1.52, 0), armor, scale=(1.2, 0.85, 1.15), group="arm_r", mirror=True)
    m.part("torus", [0.1, 0.12], (0.29, 1.48, 0), gold, scale=(1.15, 1, 1.1), group="arm_r", mirror=True)
    m.part("cylinder", [0.0, 0.03, 0.14], (0.32, 1.62, 0.0), horn, rot=(0, 0, -30), group="arm_r", mirror=True)
    m.part("cylinder", [0.0, 0.022, 0.1], (0.36, 1.56, 0.05), horn, rot=(20, 0, -55), group="arm_r", mirror=True)
    m.part("torus", [0.18, 0.21], (0, 1.02, 0), gold, scale=(1.05, 1, 0.8))
    m.part("box", [0.08, 0.06, 0.03], (0, 1.02, -0.17), gold)
    m.group("tabard", (0, 1.0, -0.15), anim={"type": "sway", "axis": [1, 0, 0], "amp": 3.0, "speed": 1.5})
    m.part("box", [0.18, 0.5, 0.02], (0, 0.74, -0.15), cloth, rot=(6, 0, 0), group="tabard")
    m.part("box", [0.38, 0.45, 0.02], (0, 0.77, 0.15), cloth, rot=(-8, 0, 0))

    # Cauda com ponta de lança
    pts = [(0, 0.95, 0.13), (0, 0.72, 0.36), (0.06, 0.42, 0.52), (0.14, 0.2, 0.7), (0.2, 0.18, 0.92)]
    parent = None
    for i in range(4):
        g = m.group("tail%d" % i, pts[i], parent,
                    anim={"type": "sway", "axis": [0, 1, 0], "amp": 8.0 + 4 * i, "speed": 1.6, "phase": i * 0.9})
        m.seg(pts[i], pts[i + 1], 0.04 - i * 0.007, 0.033 - i * 0.007, crim, group=g)
        parent = g
    m.part("prism", [0.12, 0.14, 0.02], (0.24, 0.18, 1.0), horn, rot=(90, 0, -20), group=parent)

    m.light("#ff3d00", 0.7, 2.8, (0, 1.3, -0.7))
    return m


# ---------------------------------------------------------------------------
# 27 — Nephilim
# ---------------------------------------------------------------------------
def _wing(m, side, feather_mat, bone_mat, group):
    """Asa em leque construída pena a pena. side=+1 (direita) ou -1 (esquerda)."""
    root = (side * 0.1, 1.45, 0.16)
    elbow = (side * 0.5, 1.82, 0.36)
    tip = (side * 0.95, 1.95, 0.5)
    m.chain([root, elbow, tip], [0.035, 0.025, 0.008], bone_mat, group=group)
    n = 11
    for i in range(n):
        t = i / (n - 1)
        if t < 0.5:
            base = v_lerp(root, elbow, t * 2)
        else:
            base = v_lerp(elbow, tip, (t - 0.5) * 2)
        length = 0.42 + 0.55 * t
        ang = math.radians(-8 - 38 * t) * side
        d = (-math.sin(ang), -math.cos(ang), 0.08 + 0.12 * t)
        end = v_add(base, tuple(c * length for c in d))
        m.plank(base, end, 0.075 + 0.03 * t, 0.012, feather_mat, roll=0, group=group)
    for i in range(7):
        t = i / 6
        base = v_lerp(root, tip, t)
        m.plank(base, v_add(base, (side * 0.06, -0.2 - 0.1 * t, 0.06)), 0.06, 0.014, feather_mat, group=group)


def nephilim():
    m = Model(27, "nephilim", "Nephilim", "Híbrido do Crepúsculo",
              "A maior heresia da história de Lunaria. Antes da queda dos céus, um Serafim do Trono Solar e uma "
              "Dama da Corte do Eclipse quebraram o juramento eterno e conceberam uma criança no exato instante do "
              "pôr do sol. O Nephilim carrega uma asa de luz dourada no ombro direito e uma asa de penas negras no "
              "ombro esquerdo, sendo caçado tanto pelos fanáticos da luz quanto pelos monstros da escuridão.",
              "#ffd700", scale=1.04, seed=27)
    skin = m.mat("skin", "#e9d2bd", rough=0.5)
    white = m.mat("robe_white", "#f6f1e3", rough=0.7)
    black = m.mat("robe_black", "#16121c", rough=0.6)
    gold = m.mat("gold", "#ffc107", rough=0.2, metal=0.9, emit="#ffb300", energy=0.35)
    hair = m.mat("hair", "#efe0b4", rough=0.5)
    light_f = m.mat("feather_light", "#fff8c4", rough=0.3, emit="#ffd54f", energy=3.2, alpha=0.88, double=True,
                    anim={"type": "glow", "speed": 1.4, "min": 0.75, "max": 1.25})
    dark_f = m.mat("feather_dark", "#0e0b14", rough=0.35, metal=0.3, emit="#4a148c", energy=0.35, double=True)
    eye_g = m.mat("eye_gold", "#fff59d", emit="#ffd600", energy=6.0)
    eye_v = m.mat("eye_violet", "#e1bee7", emit="#aa00ff", energy=6.0)
    halo_g = m.mat("halo_gold", "#fff59d", emit="#ffd54f", energy=5.0)
    halo_v = m.mat("halo_void", "#311b92", emit="#6200ea", energy=2.5)

    humanoid(m, skin, white, white, gold, w=0.96)
    # Metade esquerda em sombra: manga, ombreira e perna escuras
    m.part("capsule", [0.062, 0.35], (-0.275, 1.3, 0), black, rot=(0, 0, -8), group="arm_l")
    m.part("sphere", [0.095], (-0.26, 1.48, 0), black, scale=(1.2, 0.9, 1.15), group="arm_l")
    m.part("capsule", [0.089, 0.52], (-0.106, 0.7, 0), black, group="leg_l")
    m.part("sphere", [0.17], (-0.08, 1.27, -0.02), black, scale=(0.75, 1.62, 0.84))
    m.part("sphere", [0.095], (0.26, 1.48, 0), gold, scale=(1.2, 0.85, 1.15), group="arm_r")

    # Olhos de cores opostas e cabelo platinado
    m.part("sphere", [0.02], (0.045, 1.72, -0.112), eye_g)
    m.part("sphere", [0.02], (-0.045, 1.72, -0.112), eye_v)
    m.part("sphere", [0.133], (0, 1.745, 0.025), hair, scale=(1.04, 1.03, 1.04))
    m.part("capsule", [0.09, 0.36], (0, 1.6, 0.1), hair, scale=(1.3, 1, 0.5))
    m.part("capsule", [0.03, 0.22], (0.1, 1.66, -0.04), hair, rot=(0, 0, -8), mirror=True)

    # Auréola partida: metade de luz, metade de vazio
    m.group("halo", (0, 2.0, 0.08), anim={"type": "bob", "amp": 0.015, "speed": 1.4})
    for i in range(14):
        a = math.radians(i * (360 / 14))
        p = (math.cos(a) * 0.15, 2.0, math.sin(a) * 0.15 + 0.08)
        mat = halo_g if math.cos(a) > 0 else halo_v
        if i in (3, 11):
            continue  # fendas da auréola
        m.part("box", [0.065, 0.016, 0.022], p, mat, rot=(0, -math.degrees(a) + 90, 0), group="halo")

    # Cinto, faixa e saia bicolor
    m.part("torus", [0.18, 0.205], (0, 1.02, 0), gold, scale=(1.05, 1, 0.8))
    m.part("box", [0.14, 0.52, 0.02], (0.075, 0.75, -0.14), white, rot=(5, 0, 0))
    m.part("box", [0.14, 0.52, 0.02], (-0.075, 0.75, -0.14), black, rot=(5, 0, 0))
    m.part("box", [0.03, 0.44, 0.025], (0.0, 1.27, -0.157), gold)

    # Asas: luz dourada à direita, penas negras à esquerda
    m.group("wing_r", (0.1, 1.45, 0.16), anim={"type": "sway", "axis": [0, 1, 0], "amp": 7.0, "speed": 1.3})
    m.group("wing_l", (-0.1, 1.45, 0.16), anim={"type": "sway", "axis": [0, -1, 0], "amp": 7.0, "speed": 1.3})
    _wing(m, 1, light_f, gold, "wing_r")
    _wing(m, -1, dark_f, black, "wing_l")

    m.light("#ffd54f", 0.8, 3.0, (0.3, 1.6, 0.3))
    return m


# ---------------------------------------------------------------------------
# 28 — Cronomante / Errante Temporal
# ---------------------------------------------------------------------------
def cronomante():
    m = Model(28, "cronomante", "Cronomante", "Errante Temporal — O Eco do Relógio Quebrado",
              "Você já se perguntou por que o Dia em Lunaria dura 80 minutos e a Noite dura 40 minutos? Na Guerra "
              "Antiga, o Grande Relógio Astral que regia o tempo do mundo foi despedaçado para impedir que a Noite "
              "Eterna durasse para sempre. Alguns raros mortais caíram dentro das engrenagens quebradas do tempo e "
              "voltaram deslocados da linha temporal — seus corpos piscam levemente com areia dourada estelar, pois "
              "eles existem meio segundo no futuro.",
              "#ffd54f", scale=1.0, seed=28)
    skin = m.mat("skin", "#d9c2a7", rough=0.5)
    robe = m.mat("robe", "#1c1650", rough=0.75)
    robe_in = m.mat("robe_inner", "#2f2470", rough=0.7)
    trim = m.mat("trim", "#ffd54f", rough=0.3, metal=0.8, emit="#ffb300", energy=0.5)
    brass = m.mat("brass", "#c9a24a", rough=0.25, metal=0.95)
    sand = m.mat("star_sand", "#fff3c4", emit="#ffd54f", energy=4.5,
                 anim={"type": "glow", "speed": 3.5, "min": 0.3, "max": 1.4})
    dial = m.mat("dial", "#fff3c4", rough=0.4, emit="#ffe082", energy=1.1, alpha=0.85, double=True)
    ink = m.mat("clock_ink", "#2b1d00", rough=0.4, metal=0.6)
    eye = m.mat("eye", "#fff8e1", emit="#ffd54f", energy=7.0)
    ghost = m.mat("future_echo", "#ffe082", emit="#ffca28", energy=1.6, alpha=0.13, unshaded=True,
                  anim={"type": "flicker", "speed": 7.0, "min": 0.0, "max": 1.0})

    humanoid(m, skin, robe, robe, robe, hands=skin, forearm=robe_in, eye=eye, w=0.95)

    # Manto longo com bainha dourada e capuz
    m.part("cylinder", [0.2, 0.42, 0.98], (0, 0.53, 0.0), robe)
    m.part("torus", [0.4, 0.44], (0, 0.06, 0), trim)
    m.part("box", [0.06, 0.92, 0.02], (0, 0.56, -0.25), trim, rot=(-12, 0, 0))
    m.part("sphere", [0.155], (0, 1.73, 0.04), robe, scale=(1.05, 1.08, 1.05))
    m.part("torus", [0.13, 0.155], (0, 1.73, -0.04), trim, rot=(-80, 0, 0), scale=(1.0, 1.0, 1.15))
    m.part("sphere", [0.11], (0, 1.56, 0.06), robe, scale=(1.9, 0.6, 1.3))
    m.part("cylinder", [0.06, 0.065, 0.06], (0.31, 0.96, -0.11), trim, rot=(30, 0, 6), group="arm_r", mirror=True)

    # Ampulheta rúnica no cinto
    m.part("torus", [0.19, 0.215], (0, 1.02, 0), brass, scale=(1.05, 1, 0.82))
    hg = (0.19, 0.92, -0.12)
    m.part("cylinder", [0.04, 0.04, 0.012], v_add(hg, (0, 0.07, 0)), brass)
    m.part("cylinder", [0.04, 0.04, 0.012], v_add(hg, (0, -0.07, 0)), brass)
    m.part("cylinder", [0.032, 0.004, 0.064], v_add(hg, (0, 0.033, 0)), dial)
    m.part("cylinder", [0.004, 0.032, 0.064], v_add(hg, (0, -0.033, 0)), dial)
    m.part("cylinder", [0.02, 0.028, 0.025], v_add(hg, (0, -0.05, 0)), sand)

    # Mostrador do Relógio Astral quebrado atrás da cabeça
    c = (0, 1.78, 0.26)
    m.group("dial", c, anim={"type": "bob", "amp": 0.02, "speed": 1.2})
    m.part("cylinder", [0.27, 0.27, 0.012], c, dial, rot=(90, 0, 0), group="dial")
    m.part("torus", [0.265, 0.29], c, brass, rot=(90, 0, 0), group="dial")
    m.part("torus", [0.07, 0.08], c, brass, rot=(90, 0, 0), group="dial")
    for i in range(12):
        a = math.radians(i * 30)
        p = v_add(c, (math.sin(a) * 0.23, math.cos(a) * 0.23, -0.008))
        big = i % 3 == 0
        m.part("box", [0.012 if not big else 0.02, 0.04 if not big else 0.055, 0.008], p, ink,
               rot=(0, 0, -math.degrees(a)), group="dial")
    m.part("box", [0.012, 0.36, 0.014], v_add(c, (0.05, -0.02, -0.01)), ink, rot=(0, 0, 32), group="dial")
    m.part("box", [0.01, 0.16, 0.014], v_add(c, (0.13, 0.05, -0.01)), ink, rot=(0, 0, -20), group="dial")
    m.group("hand_hour", c, "dial", anim={"type": "spin", "axis": [0, 0, 1], "speed": -12})
    m.part("box", [0.018, 0.13, 0.008], v_add(c, (0, 0.055, -0.014)), brass, group="hand_hour")
    m.group("hand_min", c, "dial", anim={"type": "spin", "axis": [0, 0, 1], "speed": 70})
    m.part("box", [0.01, 0.2, 0.008], v_add(c, (0, 0.09, -0.02)), sand, group="hand_min")
    m.part("sphere", [0.018], v_add(c, (0, 0, -0.02)), brass, group="dial")

    # Engrenagens quebradas orbitando
    m.group("gears", (0, 1.15, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 16})
    for k, (a_deg, y, r) in enumerate(((20, 0.85, 0.09), (140, 1.35, 0.07), (260, 0.55, 0.11))):
        a = math.radians(a_deg)
        gc = (math.cos(a) * 0.6, y, math.sin(a) * 0.6)
        g = m.group("gear%d" % k, gc, "gears",
                    anim={"type": "spin", "axis": [0, 1, 0], "speed": 60 * (1 if k % 2 else -1)})
        m.part("torus", [r * 0.6, r], gc, brass, group=g)
        teeth = 9
        for t in range(teeth):
            if t == 4:
                continue  # dente partido
            ta = t * 2 * math.pi / teeth
            m.part("box", [r * 0.35, r * 0.25, r * 0.3], v_add(gc, (math.cos(ta) * r * 1.08, 0, math.sin(ta) * r * 1.08)),
                   brass, rot=(0, -math.degrees(ta), 0), group=g)
        m.part("box", [r * 1.6, r * 0.15, r * 0.18], gc, brass, group=g)

    # Fragmentos de ponteiros flutuando ao redor dos ombros
    for i, (p, rot) in enumerate((((0.42, 1.7, -0.05), (0, 0, 35)), ((-0.45, 1.6, 0.05), (20, 0, -25)), ((0.38, 1.25, 0.2), (0, 40, 70)))):
        m.part("prism", [0.035, 0.16, 0.01], p, brass, rot=rot,
               anim={"type": "bob", "amp": 0.04, "speed": 1.5, "phase": i * 2.1})

    # Areia estelar dourada espiralando
    m.group("sand", (0, 1.0, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 38})
    for i in range(22):
        t = i / 22
        a = t * math.pi * 6
        r = 0.32 + 0.16 * math.sin(t * math.pi)
        m.part("sphere", [0.01 + 0.008 * (i % 3)], (math.cos(a) * r, 0.15 + t * 1.75, math.sin(a) * r), sand,
               group="sand", anim={"type": "bob", "amp": 0.05, "speed": 1.4 + (i % 5) * 0.3, "phase": i})

    # Eco do futuro: cópia translúcida meio passo à frente
    ghost_copy(m, ghost, (0.0, 0.0, -0.14))

    m.light("#ffd54f", 0.8, 3.0, (0, 1.5, -0.7))
    return m


ALL = [sylvari, myconid, aracne, draconato, quimera, boreal, thalassiano, cambion, nephilim, cronomante]
