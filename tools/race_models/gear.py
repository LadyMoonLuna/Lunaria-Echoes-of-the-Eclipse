"""Armas, trajes de classe, companheiros e loadouts das classes 0 a 27 (IDs de server/internal/protocol/packets.go).

Armas: origem (pivô) exatamente na empunhadura, lâmina/haste ao longo de +Y,
frente em -Z — prontas para serem presas na mão (âncoras hand_r / hand_l).
Trajes: peças posicionadas para um corpo de largura 1.0; o cliente escala o
eixo X pela largura do corpo (body_w) de cada raça ao vestir.
"""

import math

from modelkit import Model, v_add, v_lerp
from gear_classes import OUTFITS_CLASSES, WEAPONS_CLASSES


def W(key, name, desc, color):
    return Model(0, key, name, "Arma", desc, color, kind="weapon")


# ---------------------------------------------------------------------------
# Armas
# ---------------------------------------------------------------------------

def iron_dagger():
    m = W("iron_dagger", "Adaga Curta de Ferro", "Arma inicial do Viajante.", "#b0bec5")
    iron = m.mat("iron", "#9ea7ad", rough=0.35, metal=0.85)
    wood = m.mat("wrap", "#4e3423", rough=0.9)
    m.part("cylinder", [0.018, 0.02, 0.11], (0, 0, 0), wood)
    m.part("box", [0.1, 0.02, 0.03], (0, 0.065, 0), iron)
    m.part("box", [0.04, 0.2, 0.008], (0, 0.17, 0), iron)
    m.part("prism", [0.04, 0.05, 0.008], (0, 0.295, 0), iron)
    m.part("sphere", [0.022], (0, -0.065, 0), iron)
    return m


def wooden_staff():
    m = W("wooden_staff", "Bastão de Madeira Simples", "Arma inicial alternativa do Viajante.", "#8d6e63")
    wood = m.mat("wood", "#7a5536", rough=0.9)
    m.part("cylinder", [0.022, 0.026, 1.5], (0, 0.15, 0), wood)
    m.part("sphere", [0.04], (0, 0.92, 0), wood, scale=(1, 1.3, 1))
    m.part("torus", [0.024, 0.034], (0, 0.0, 0), m.mat("cord", "#c8b88a", rough=1.0))
    return m


def knight_longsword():
    m = W("knight_longsword", "Espada Longa de Cavaleiro", "1,1 m de aço polido com guarda em cruz.", "#64b5f6")
    steel = m.mat("blade_steel", "#e3eaf2", rough=0.15, metal=0.95, emit="#64b5f6", energy=0.25)
    guard = m.mat("guard", "#2f3338", rough=0.3, metal=0.9)
    grip = m.mat("leather_grip", "#3b2a1e", rough=0.85)
    gold = m.mat("gold", "#d4ac0d", rough=0.25, metal=0.95)
    m.part("cylinder", [0.019, 0.021, 0.22], (0, 0, 0), grip)
    m.part("sphere", [0.032], (0, -0.13, 0), gold)
    m.part("box", [0.26, 0.035, 0.045], (0, 0.125, 0), guard)
    m.part("sphere", [0.022], (0.13, 0.125, 0), gold, mirror=True)
    m.part("box", [0.055, 0.8, 0.012], (0, 0.54, 0), steel)
    m.part("box", [0.012, 0.74, 0.016], (0, 0.52, 0), guard)
    m.part("prism", [0.055, 0.12, 0.012], (0, 1.0, 0), steel)
    return m


def heater_shield():
    m = W("heater_shield", "Escudo Triangular (Heater)", "Escudo medieval com borda de aço e brasão do Sol Partido.", "#1b4f72")
    wood = m.mat("painted_wood", "#1b4f72", rough=0.7)
    steel = m.mat("rim_steel", "#bdc3c7", rough=0.25, metal=0.9)
    gold = m.mat("emblem_gold", "#d4ac0d", rough=0.3, metal=0.9)
    strap = m.mat("strap", "#3b2a1e", rough=0.9)
    z = -0.07
    m.part("box", [0.5, 0.36, 0.035], (0, 0.13, z), wood)
    m.part("prism", [0.5, 0.36, 0.035], (0, -0.23, z), wood, rot=(0, 0, 180))
    m.part("box", [0.52, 0.03, 0.05], (0, 0.31, z), steel)
    m.plank((0.25, 0.3, z), (0.0, -0.42, z), 0.03, 0.05, steel)
    m.plank((-0.25, 0.3, z), (0.0, -0.42, z), 0.03, 0.05, steel)
    m.part("box", [0.03, 0.3, 0.05], (0.25, 0.16, z), steel, mirror=True)
    m.part("cylinder", [0.075, 0.075, 0.02], (0, 0.08, z - 0.025), gold, rot=(90, 0, 0))
    m.part("box", [0.014, 0.18, 0.02], (0, 0.08, z - 0.04), wood, rot=(0, 0, 25))
    m.part("box", [0.06, 0.12, 0.02], (0, 0, -0.03), strap)
    return m


def recurve_bow():
    m = W("recurve_bow", "Arco Recurvo de Madeira e Ouro", "Seguro na mão esquerda; a corda fica voltada para o arqueiro (+Z).", "#69f0ae")
    wood = m.mat("bow_wood", "#6d4426", rough=0.6)
    gold = m.mat("bow_gold", "#e0b43a", rough=0.25, metal=0.9)
    string = m.mat("bowstring", "#f5f5f0", rough=0.6)
    grip = m.mat("grip", "#2e2018", rough=0.9)
    m.part("cylinder", [0.022, 0.022, 0.12], (0, 0, 0), grip)
    pts = [(0, 0.06, 0), (0, 0.28, -0.07), (0, 0.5, -0.06), (0, 0.6, 0.0)]
    for sgn in (1, -1):
        p = [(x, y * sgn, z) for x, y, z in pts]
        m.chain(p, [0.02, 0.016, 0.011, 0.007], wood)
        m.part("sphere", [0.012], p[-1], gold)
        m.part("torus", [0.017, 0.024], p[1], gold, rot=(20 * sgn, 0, 0))
    m.part("cylinder", [0.002, 0.002, 1.18], (0, 0, 0.0), string)
    return m


def steel_arrow():
    m = W("steel_arrow", "Flecha de Ponta de Aço", "Penas verdes; segurada na mão direita para puxar a corda.", "#69f0ae")
    shaft = m.mat("shaft", "#c8a26b", rough=0.7)
    steel = m.mat("arrowhead", "#cfd8dc", rough=0.2, metal=0.9)
    feather = m.mat("green_feather", "#2e7d32", rough=0.8, double=True)
    m.part("cylinder", [0.006, 0.006, 0.72], (0, 0.26, 0), shaft)
    m.part("cylinder", [0.0, 0.018, 0.06], (0, 0.65, 0), steel)
    for a in (0, 120, 240):
        m.part("prism", [0.03, 0.1, 0.003], (math.sin(math.radians(a)) * 0.012, -0.04, math.cos(math.radians(a)) * 0.012),
               feather, rot=(0, a, 0))
    return m


def crystal_staff():
    m = W("crystal_staff", "Cajado de Cristal Arcano", "1,7 m de madeira negra retorcida sustentando um cristal azul flutuante.", "#00e5ff")
    wood = m.mat("black_wood", "#1d1512", rough=0.7)
    gold = m.mat("gold", "#d4ac0d", rough=0.3, metal=0.9)
    crystal = m.mat("arcane_crystal", "#b3f5ff", rough=0.05, metal=0.2, emit="#00b8ff", energy=3.5, alpha=0.9,
                    anim={"type": "glow", "speed": 2.0, "min": 0.6, "max": 1.4})
    pts = [(0, -0.7, 0), (0.015, -0.2, 0.01), (-0.012, 0.3, -0.01), (0.01, 0.78, 0.0), (0, 0.95, 0)]
    m.chain(pts, [0.024, 0.026, 0.024, 0.026, 0.03], wood)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        m.chain([(0, 0.92, 0), (math.cos(a) * 0.06, 1.0, math.sin(a) * 0.06), (math.cos(a) * 0.035, 1.12, math.sin(a) * 0.035)],
                [0.014, 0.01, 0.0], wood)
    m.part("torus", [0.028, 0.038], (0, 0.86, 0), gold)
    m.group("crystal", (0, 1.06, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 80})
    m.part("cylinder", [0.0, 0.045, 0.1], (0, 1.11, 0), crystal, group="crystal")
    m.part("cylinder", [0.045, 0.0, 0.07], (0, 1.025, 0), crystal, group="crystal")
    m.light("#00b8ff", 0.6, 2.0, (0, 1.06, 0))
    return m


def holy_mace():
    m = W("holy_mace", "Maça Sagrada Dourada", "Maça de aletas com o Sol gravado.", "#ffd54f")
    gold = m.mat("holy_gold", "#ffcf40", rough=0.2, metal=0.95, emit="#ffb300", energy=0.4)
    grip = m.mat("white_wrap", "#efe9dc", rough=0.9)
    m.part("cylinder", [0.02, 0.022, 0.36], (0, 0.08, 0), grip)
    m.part("sphere", [0.03], (0, -0.12, 0), gold)
    m.part("sphere", [0.06], (0, 0.36, 0), gold)
    for i in range(6):
        a = math.radians(i * 60)
        m.part("box", [0.012, 0.14, 0.06], (math.cos(a) * 0.055, 0.36, math.sin(a) * 0.055), gold, rot=(0, -math.degrees(a), 0))
    m.part("cylinder", [0.0, 0.02, 0.06], (0, 0.46, 0), gold)
    return m


def solar_talisman():
    m = W("solar_talisman", "Talismã / Orbe Solar", "Orbe flutuante acima da mão esquerda.", "#ffd54f")
    gold = m.mat("gold", "#ffcf40", rough=0.2, metal=0.95)
    sun = m.mat("sun_orb", "#fff8e1", emit="#ffc400", energy=4.0, anim={"type": "glow", "speed": 2.2, "min": 0.7, "max": 1.3})
    m.group("orb", (0, 0.16, 0), anim={"type": "bob", "amp": 0.03, "speed": 2.0})
    m.part("sphere", [0.055], (0, 0.16, 0), sun, group="orb")
    m.group("rays", (0, 0.16, 0), "orb", anim={"type": "spin", "axis": [0, 1, 0], "speed": 60})
    m.part("torus", [0.075, 0.085], (0, 0.16, 0), gold, rot=(70, 0, 0), group="rays")
    for i in range(8):
        a = math.radians(i * 45)
        m.part("cylinder", [0.0, 0.01, 0.04], (math.cos(a) * 0.1, 0.16, math.sin(a) * 0.1), sun,
               rot=(90, -math.degrees(a) + 90, 0), group="rays")
    m.light("#ffc400", 0.5, 2.0, (0, 0.16, 0))
    return m


def forge_warhammer():
    m = W("forge_warhammer", "Martelo de Forja de Guerra", "Martelo colossal de duas mãos, ferro negro com fissuras de brasa.", "#ff6d00")
    iron = m.mat("black_iron", "#1e1f22", rough=0.45, metal=0.85)
    wood = m.mat("ash_handle", "#5a3d27", rough=0.85)
    ember = m.mat("ember_crack", "#ffcc80", emit="#ff6d00", energy=3.5, anim={"type": "glow", "speed": 1.4, "min": 0.6, "max": 1.3})
    m.part("cylinder", [0.026, 0.03, 1.1], (0, 0.2, 0), wood)
    m.part("torus", [0.028, 0.04], (0, -0.1, 0), iron)
    m.part("box", [0.24, 0.22, 0.42], (0, 0.82, 0), iron)
    m.part("box", [0.26, 0.04, 0.44], (0, 0.82, 0), m.mat("band", "#3a3c40", rough=0.3, metal=0.9))
    for i in range(5):
        m.part("box", [0.008, 0.12, 0.01], ((i - 2) * 0.045, 0.83, -0.212), ember, rot=(0, 0, (i - 2) * 18))
        m.part("box", [0.008, 0.12, 0.01], ((i - 2) * 0.045, 0.83, 0.212), ember, rot=(0, 0, -(i - 2) * 18))
    return m


def alchemy_flask():
    m = W("alchemy_flask", "Frasco Esférico Alquímico", "Vidro cheio de líquido verde/roxo brilhante, pronto para ser arremessado.", "#00e676")
    glass = m.mat("glass", "#e0f2f1", rough=0.02, metal=0.1, alpha=0.35)
    liquid = m.mat("liquid", "#b9f6ca", emit="#00e676", energy=3.5, anim={"type": "glow", "speed": 2.6, "min": 0.6, "max": 1.4})
    cork = m.mat("cork", "#a1795a", rough=1.0)
    m.part("sphere", [0.07], (0, 0.07, -0.02), glass)
    m.part("sphere", [0.058], (0, 0.06, -0.02), liquid)
    m.part("cylinder", [0.018, 0.022, 0.06], (0, 0.16, -0.02), glass)
    m.part("cylinder", [0.019, 0.017, 0.025], (0, 0.2, -0.02), cork)
    m.light("#00e676", 0.4, 1.5, (0, 0.07, -0.02))
    return m


def injector_gauntlet():
    m = W("injector_gauntlet", "Manopla Injetora de Latão", "Vestida na mão esquerda, com tubos e ampola de reagente.", "#00e676")
    brass = m.mat("brass", "#c9a24a", rough=0.25, metal=0.95)
    tube = m.mat("tube_glow", "#b9f6ca", emit="#00e676", energy=2.5, alpha=0.8)
    leather = m.mat("leather", "#3b2a1e", rough=0.8)
    m.part("sphere", [0.06], (0, 0, 0), leather, scale=(1, 1.15, 1))
    m.part("cylinder", [0.062, 0.055, 0.16], (0, 0.1, 0.02), brass, rot=(-28, 0, 0))
    m.part("cylinder", [0.02, 0.02, 0.09], (0.05, 0.14, 0.05), tube, rot=(-28, 0, 0))
    m.part("cylinder", [0.008, 0.008, 0.18], (-0.04, 0.1, 0.04), tube, rot=(-28, 0, 10))
    m.part("cylinder", [0.0, 0.008, 0.05], (0, -0.06, -0.03), brass, rot=(160, 0, 0))
    return m


def eclipse_scythe():
    m = W("eclipse_scythe", "Foice Colossal do Eclipse", "2,0 m de haste retorcida e lâmina negra com fio vermelho-sangue.", "#d50000")
    haft = m.mat("haft", "#151116", rough=0.5, metal=0.3)
    blade = m.mat("black_blade", "#0c0b0f", rough=0.15, metal=0.85, double=True)
    edge = m.mat("blood_edge", "#ff8a80", emit="#d50000", energy=3.5, anim={"type": "glow", "speed": 1.8, "min": 0.6, "max": 1.4})
    bone = m.mat("bone", "#d8d0c0", rough=0.5)
    pts = [(0, -0.6, 0), (0.02, 0.0, 0.0), (-0.02, 0.6, 0.0), (0.0, 1.38, 0)]
    m.chain(pts, [0.025, 0.027, 0.025, 0.03], haft)
    m.part("sphere", [0.05], (0, 1.4, 0), bone)
    arc = [(0, 1.42, 0)]
    for i in range(1, 9):
        t = i / 8
        arc.append((0, 1.42 + 0.22 * math.sin(t * math.pi * 0.9), -0.7 * t))
    for i in range(len(arc) - 1):
        wdt = 0.13 * (1 - i / 8) + 0.02
        m.plank(arc[i], arc[i + 1], 0.012, wdt, blade, roll=0)
        m.plank(v_add(arc[i], (0, -wdt * 0.5, 0)), v_add(arc[i + 1], (0, -wdt * 0.5, 0)), 0.014, 0.012, edge)
    m.part("torus", [0.028, 0.04], (0, 0.0, 0), m.mat("crimson_wrap", "#7f0000", rough=0.8))
    return m


def hammer_cannon():
    m = W("hammer_cannon", "Martelo-Canhão Rúnico", "Malho pesado à frente, turbina rúnica atrás e cano de disparo no centro.", "#2979ff")
    bronze = m.mat("bronze", "#9a7034", rough=0.3, metal=0.95)
    iron = m.mat("iron", "#2a2c30", rough=0.4, metal=0.9)
    rune = m.mat("rune_turbine", "#b3e5fc", emit="#2979ff", energy=4.0, anim={"type": "glow", "speed": 3.0, "min": 0.6, "max": 1.4})
    m.part("cylinder", [0.026, 0.028, 1.0], (0, 0.15, 0), iron)
    m.part("box", [0.2, 0.2, 0.2], (0, 0.75, -0.18), bronze)
    m.part("box", [0.22, 0.04, 0.22], (0, 0.75, -0.18), iron)
    m.part("cylinder", [0.06, 0.06, 0.4], (0, 0.75, 0), iron, rot=(90, 0, 0))
    m.part("cylinder", [0.035, 0.035, 0.42], (0, 0.75, -0.01), m.mat("bore", "#050505", rough=1.0), rot=(90, 0, 0))
    m.part("cylinder", [0.11, 0.09, 0.16], (0, 0.75, 0.2), bronze, rot=(90, 0, 0))
    m.group("turbine", (0, 0.75, 0.29), anim={"type": "spin", "axis": [0, 0, 1], "speed": 400})
    for i in range(6):
        a = math.radians(i * 60)
        m.part("box", [0.02, 0.09, 0.01], (math.cos(a) * 0.05, 0.75 + math.sin(a) * 0.05, 0.29), rune,
               rot=(0, 20, math.degrees(a) - 90), group="turbine")
    m.part("torus", [0.09, 0.105], (0, 0.75, 0.29), rune, rot=(90, 0, 0))
    m.light("#2979ff", 0.5, 2.0, (0, 0.75, 0.3))
    return m


def philosopher_chalice():
    m = W("philosopher_chalice", "Cálice da Pedra Filosofal", "Cálice dourado com a Pedra emitindo raios carmesins.", "#ff1744")
    gold = m.mat("gold", "#d4ac0d", rough=0.2, metal=0.95)
    stone = m.mat("philosopher_stone", "#ff8a80", rough=0.05, emit="#ff1744", energy=4.5, anim={"type": "glow", "speed": 2.0, "min": 0.6, "max": 1.4})
    ray = m.mat("crimson_ray", "#ff8a80", emit="#ff1744", energy=4.0, alpha=0.6)
    m.part("cylinder", [0.04, 0.05, 0.015], (0, -0.05, 0), gold)
    m.part("cylinder", [0.012, 0.012, 0.12], (0, 0.02, 0), gold)
    m.part("cylinder", [0.065, 0.025, 0.09], (0, 0.12, 0), gold)
    m.group("stone", (0, 0.2, 0), anim={"type": "bob", "amp": 0.015, "speed": 2.4})
    m.part("sphere", [0.035], (0, 0.2, 0), stone, rot=(0, 45, 45), scale=(1, 1.3, 1), group="stone")
    m.group("rays", (0, 0.2, 0), "stone", anim={"type": "spin", "axis": [0, 1, 0], "speed": 90})
    for i in range(6):
        a = math.radians(i * 60)
        m.plank((0, 0.2, 0), (math.cos(a) * 0.16, 0.27, math.sin(a) * 0.16), 0.008, 0.003, ray, group="rays")
    m.light("#ff1744", 0.6, 2.0, (0, 0.2, 0))
    return m


def hunting_knife():
    m = W("hunting_knife", "Faca de Caça (Autópsia)", "Usada no mini-game de autópsia.", "#bcaaa4")
    steel = m.mat("steel", "#cfd8dc", rough=0.2, metal=0.9)
    bone = m.mat("bone_handle", "#e6dccb", rough=0.5)
    m.part("cylinder", [0.016, 0.018, 0.11], (0, 0, 0), bone)
    m.part("box", [0.06, 0.012, 0.025], (0, 0.06, 0), steel)
    m.part("box", [0.032, 0.16, 0.006], (0.004, 0.145, 0), steel)
    m.part("prism", [0.032, 0.05, 0.006], (0.004, 0.25, 0), steel)
    return m


def homunculus():
    m = Model(0, "homunculus", "Mini-Homúnculo", "Companheiro",
              "Criatura flutuante de 50 cm feita de cristal vermelho e sombras, que orbita o Demiurgo Alquímico.",
              "#ff1744", kind="companion")
    crystal = m.mat("red_crystal", "#ff8a80", rough=0.05, metal=0.3, emit="#d50000", energy=2.2, alpha=0.9,
                    anim={"type": "glow", "speed": 2.0, "min": 0.6, "max": 1.3})
    shadow = m.mat("shadow", "#120a10", emit="#4a0010", energy=0.4, alpha=0.7)
    eye = m.mat("eye", "#ffffff", emit="#ffea00", energy=6.0)
    m.group("orbit", (0, 0, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 180})
    c = (1.1, 1.4, 0)
    m.group("body", c, "orbit", anim={"type": "bob", "amp": 0.12, "speed": 4.5})
    m.part("cylinder", [0.0, 0.08, 0.16], v_add(c, (0, 0.08, 0)), crystal, group="body")
    m.part("cylinder", [0.08, 0.0, 0.2], v_add(c, (0, -0.1, 0)), crystal, group="body")
    m.part("sphere", [0.06], v_add(c, (0, 0.2, 0)), shadow, group="body")
    m.part("sphere", [0.012], v_add(c, (-0.02, 0.21, -0.05)), eye, group="body")
    m.part("sphere", [0.012], v_add(c, (0.02, 0.21, -0.05)), eye, group="body")
    for i in range(4):
        a = math.radians(i * 90)
        m.part("sphere", [0.03], v_add(c, (math.cos(a) * 0.1, -0.15, math.sin(a) * 0.1)), shadow, group="body")
    m.light("#d50000", 0.5, 2.0, c)
    return m


WEAPONS_BASE = [iron_dagger, wooden_staff, knight_longsword, heater_shield, recurve_bow, steel_arrow, crystal_staff,
           holy_mace, solar_talisman, forge_warhammer, alchemy_flask, injector_gauntlet, eclipse_scythe,
           hammer_cannon, philosopher_chalice, hunting_knife, homunculus]


# ---------------------------------------------------------------------------
# Armas das criaturas
# ---------------------------------------------------------------------------

def raider_short_sword():
    m = W("raider_short_sword", "Espada Curta Lascada", "Lâmina de ferro cheia de lascas do Saqueador Deserdado.", "#90a4ae")
    iron = m.mat("chipped_iron", "#8c9399", rough=0.45, metal=0.8)
    grip = m.mat("grip_wrap", "#3b2a1e", rough=0.9)
    m.part("cylinder", [0.018, 0.02, 0.14], (0, 0, 0), grip)
    m.part("box", [0.16, 0.03, 0.04], (0, 0.08, 0), iron)
    m.part("box", [0.05, 0.5, 0.01], (0, 0.34, 0), iron)
    m.part("prism", [0.05, 0.08, 0.01], (0, 0.63, 0), iron)
    for y in (0.22, 0.4, 0.52):
        m.part("box", [0.015, 0.02, 0.012], (0.026, y, 0), m.mat("notch", "#3a3d40", rough=0.6), rot=(0, 0, 40))
    return m


def raider_round_shield():
    m = W("raider_round_shield", "Escudo Redondo Amassado", "Escudo de ferro com cravos; brilha em azul quando o Saqueador bloqueia.", "#78909c")
    iron = m.mat("dented_iron", "#6f767c", rough=0.5, metal=0.8)
    wood = m.mat("shield_wood", "#5a3f2b", rough=0.85)
    z = -0.06
    m.part("cylinder", [0.3, 0.3, 0.04], (0, 0.06, z), wood, rot=(90, 0, 0))
    m.part("torus", [0.28, 0.32], (0, 0.06, z), iron, rot=(90, 0, 0))
    m.part("sphere", [0.08], (0, 0.06, z - 0.02), iron, scale=(1, 1, 0.6))
    for i in range(8):
        a = math.radians(i * 45)
        m.part("cylinder", [0.0, 0.02, 0.06], (math.cos(a) * 0.2, 0.06 + math.sin(a) * 0.2, z - 0.04), iron, rot=(-90, 0, 0))
    m.part("box", [0.06, 0.12, 0.02], (0, 0, -0.03), m.mat("strap", "#3b2a1e", rough=0.9))
    return m


def heavy_crossbow():
    m = W("heavy_crossbow", "Besta Pesada da Vigília", "Coronha de madeira e braços de ferro, segurada à frente.", "#8d6e63")
    wood = m.mat("crossbow_wood", "#6b4a32", rough=0.7)
    iron = m.mat("crossbow_iron", "#4a4f55", rough=0.4, metal=0.85)
    string = m.mat("bowstring", "#e8e2d0", rough=0.7)
    m.part("box", [0.06, 0.7, 0.07], (0, 0.2, 0), wood)
    m.part("box", [0.62, 0.035, 0.035], (0, 0.5, 0), iron)
    m.plank((0.31, 0.5, 0), (0.0, 0.32, 0.0), 0.004, 0.004, string)
    m.plank((-0.31, 0.5, 0), (0.0, 0.32, 0.0), 0.004, 0.004, string)
    m.part("cylinder", [0.006, 0.006, 0.4], (0, 0.38, -0.04), m.mat("bolt", "#b08a5a", rough=0.7))
    m.part("box", [0.05, 0.08, 0.04], (0, 0.02, 0.05), iron)
    return m


def shadow_orb_staff():
    m = W("shadow_orb_staff", "Cajado do Orbe Sombrio", "Cajado retorcido com um orbe de sombras flutuante.", "#7e57c2")
    wood = m.mat("dark_wood", "#24161f", rough=0.7)
    orb = m.mat("shadow_orb", "#e1bee7", emit="#aa00ff", energy=4.0, anim={"type": "glow", "speed": 2.0, "min": 0.6, "max": 1.4})
    m.chain([(0, -0.7, 0), (0.02, 0.0, 0.0), (-0.02, 0.6, 0), (0, 0.95, 0)], [0.022, 0.024, 0.022, 0.03], wood)
    for i in range(3):
        a = math.radians(i * 120)
        m.chain([(0, 0.93, 0), (math.cos(a) * 0.06, 1.02, math.sin(a) * 0.06), (math.cos(a) * 0.03, 1.12, math.sin(a) * 0.03)], [0.012, 0.008, 0.0], wood)
    m.group("orb", (0, 1.08, 0), anim={"type": "bob", "amp": 0.03, "speed": 2.0})
    m.part("sphere", [0.06], (0, 1.08, 0), orb, group="orb")
    m.light("#aa00ff", 0.5, 2.0, (0, 1.08, 0))
    return m


def darkness_orb():
    m = W("darkness_orb", "Orbe de Trevas", "Orbe de trevas flutuando acima da mão do Cultista.", "#4a148c")
    orb = m.mat("darkness_core", "#120018", rough=0.2, emit="#4a148c", energy=1.5)
    halo = m.mat("darkness_halo", "#ce93d8", emit="#d500f9", energy=3.0, alpha=0.5)
    m.group("orb", (0, 0.2, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 70})
    m.part("sphere", [0.08], (0, 0.2, 0), orb, group="orb")
    m.part("torus", [0.1, 0.115], (0, 0.2, 0), halo, rot=(60, 0, 0), group="orb")
    m.part("torus", [0.1, 0.115], (0, 0.2, 0), halo, rot=(-60, 0, 0), group="orb")
    m.light("#d500f9", 0.5, 2.0, (0, 0.2, 0))
    return m


def executioner_mace():
    m = W("executioner_mace", "Maça do Executor", "Maça de ferro colossal com aletas, de duas mãos.", "#455a64")
    iron = m.mat("black_iron", "#24262a", rough=0.45, metal=0.85)
    leather = m.mat("grip_leather", "#3b2a1e", rough=0.9)
    m.part("cylinder", [0.03, 0.034, 1.0], (0, 0.25, 0), leather)
    m.part("sphere", [0.15], (0, 0.82, 0), iron)
    for i in range(8):
        a = math.radians(i * 45)
        m.part("box", [0.02, 0.26, 0.12], (math.cos(a) * 0.14, 0.82, math.sin(a) * 0.14), iron, rot=(0, -math.degrees(a), 0))
    m.part("cylinder", [0.0, 0.04, 0.12], (0, 1.0, 0), iron)
    return m


def traitor_greatsword():
    m = W("traitor_greatsword", "Espadão do Traidor", "Espadão largo do Comandante Vaelen, com o brasão riscado.", "#cfd8dc")
    steel = m.mat("greatsword_steel", "#d5dde4", rough=0.18, metal=0.95)
    gold = m.mat("tarnished_gold", "#9c7c22", rough=0.35, metal=0.9)
    grip = m.mat("grip", "#2a1d14", rough=0.9)
    m.part("cylinder", [0.022, 0.024, 0.32], (0, 0.02, 0), grip)
    m.part("sphere", [0.04], (0, -0.16, 0), gold)
    m.part("box", [0.36, 0.05, 0.06], (0, 0.2, 0), gold)
    m.part("box", [0.1, 1.1, 0.016], (0, 0.78, 0), steel)
    m.part("box", [0.02, 1.0, 0.02], (0, 0.75, 0), gold)
    m.part("prism", [0.1, 0.16, 0.016], (0, 1.41, 0), steel)
    return m


def primordial_scythe():
    m = W("primordial_scythe", "Foice Primordial do Eclipse", "Foice de Malakor, haste negra e lâmina violeta radiante.", "#aa00ff")
    haft = m.mat("void_haft", "#140a1e", rough=0.4, metal=0.5)
    blade = m.mat("eclipse_blade", "#e1bee7", emit="#aa00ff", energy=4.0, double=True,
                  anim={"type": "glow", "speed": 1.6, "min": 0.6, "max": 1.4})
    m.chain([(0, -0.7, 0), (0.03, 0.2, 0), (-0.03, 0.9, 0), (0, 1.5, 0)], [0.03, 0.033, 0.03, 0.035], haft)
    arc = [(0, 1.52, 0)]
    for i in range(1, 10):
        t = i / 9
        arc.append((0, 1.52 + 0.3 * math.sin(t * math.pi * 0.9), -0.95 * t))
    for i in range(len(arc) - 1):
        m.plank(arc[i], arc[i + 1], 0.012, 0.18 * (1 - i / 9) + 0.03, blade)
    m.light("#aa00ff", 0.8, 3.0, (0, 1.6, -0.4))
    return m


MOB_WEAPONS = [raider_short_sword, raider_round_shield, heavy_crossbow, shadow_orb_staff, darkness_orb,
               executioner_mace, traitor_greatsword, primordial_scythe]


WEAPONS = WEAPONS_BASE + MOB_WEAPONS + WEAPONS_CLASSES


# ---------------------------------------------------------------------------
# Trajes das classes
# ---------------------------------------------------------------------------

def O(key, name, desc, color):
    return Model(0, key, name, "Traje de Classe", desc, color, kind="outfit")


def _shell(m, mat, sleeves=None, pants=None, boots=None, long_sleeve=False):
    m.part("sphere", [0.2], (0, 1.285, 0), mat, scale=(1.27, 1.42, 0.85))
    if sleeves:
        m.part("capsule", [0.067, 0.36], (0.28, 1.3, 0), sleeves, rot=(0, 0, 8), group="arm_r", mirror=True)
        m.part("sphere", [0.092], (0.26, 1.47, 0), sleeves, group="arm_r", mirror=True)
        if long_sleeve:
            m.part("capsule", [0.058, 0.3], (0.31, 1.05, -0.06), sleeves, rot=(30, 0, 6), group="arm_r", mirror=True)
    if pants:
        m.part("capsule", [0.094, 0.52], (0.11, 0.7, 0), pants, group="leg_r", mirror=True)
        m.part("capsule", [0.124, 0.38], (0, 0.98, 0), pants, rot=(0, 0, 90), group="pose")
    if boots:
        m.part("capsule", [0.079, 0.3], (0.11, 0.22, 0), boots, group="leg_r", mirror=True)
        m.part("box", [0.14, 0.075, 0.27], (0.11, 0.037, -0.05), boots, group="leg_r", mirror=True)


def _skirt(m, mat, top_r, bottom_r, h, top_y=1.0):
    m.part("cylinder", [top_r, bottom_r, h], (0, top_y - h / 2, 0), mat, group="pose")


def outfit_traveler():
    m = O("traveler", "Viajante", "Camisa de linho bege folgada com cinto de corda, calças de couro marrom e botas gastas.", "#cdbb98")
    linen = m.mat("linen", "#d3c19c", rough=0.95)
    pants = m.mat("brown_leather", "#5d4330", rough=0.8)
    boots = m.mat("worn_boots", "#3a2a1f", rough=0.9)
    rope = m.mat("rope", "#b59f72", rough=1.0)
    _shell(m, linen, linen, pants, boots)
    m.part("torus", [0.19, 0.21], (0, 1.03, 0), rope, scale=(1.05, 1, 0.82))
    m.part("cylinder", [0.008, 0.008, 0.16], (0.08, 0.95, -0.16), rope, rot=(0, 0, 10))
    m.part("cylinder", [0.24, 0.27, 0.16], (0, 1.02, 0), linen, group="pose")
    return m


def outfit_swordsman():
    m = O("swordsman", "Espadachim", "Peitoral de aço sobre cota de malha, ombreiras simétricas e tabardo azul e branco.", "#64b5f6")
    mail = m.mat("chainmail", "#8c949b", rough=0.55, metal=0.8)
    steel = m.mat("steel_plate", "#cfd6dc", rough=0.2, metal=0.9)
    blue = m.mat("tabard_blue", "#1f4e8c", rough=0.8, double=True)
    white = m.mat("tabard_white", "#eeeeea", rough=0.8)
    boots = m.mat("steel_boots", "#9aa3ab", rough=0.3, metal=0.85)
    pants = m.mat("padded", "#2a3443", rough=0.85)
    _shell(m, mail, mail, pants, boots)
    m.part("sphere", [0.2], (0, 1.33, -0.035), steel, scale=(1.28, 1.25, 0.72))
    m.part("box", [0.02, 0.34, 0.02], (0, 1.32, -0.18), m.mat("ridge", "#e9eef2", rough=0.15, metal=0.95))
    for k in range(3):
        m.part("sphere", [0.11 - k * 0.012], (0.29 + k * 0.025, 1.53 - k * 0.05, 0), steel,
               scale=(1.2, 0.55, 1.15), rot=(0, 0, -20 - 10 * k), group="arm_r", mirror=True)
    m.group("tabard", (0, 1.0, -0.16), anim={"type": "sway", "axis": [1, 0, 0], "amp": 3.0, "speed": 1.5})
    m.part("box", [0.26, 0.46, 0.02], (0, 0.78, -0.16), blue, rot=(6, 0, 0), group="tabard")
    m.part("box", [0.06, 0.46, 0.022], (0, 0.78, -0.162), white, rot=(6, 0, 0), group="tabard")
    m.part("box", [0.36, 0.44, 0.02], (0, 0.8, 0.15), blue, rot=(-8, 0, 0), group="pose")
    m.part("torus", [0.185, 0.21], (0, 1.02, 0), m.mat("belt", "#3b2a1e", rough=0.8), scale=(1.05, 1, 0.82))
    return m


def outfit_scout():
    m = O("scout", "Batedor", "Casaco leve verde-floresta e marrom, capuz nos ombros, luvas de arqueiro e aljava nas costas.", "#69f0ae")
    green = m.mat("forest_green", "#2f5d34", rough=0.8, double=True)
    brown = m.mat("leather_brown", "#5a3f2b", rough=0.8)
    boots = m.mat("soft_boots", "#3d2b1f", rough=0.85)
    shaft = m.mat("arrow_shaft", "#c8a26b", rough=0.7)
    feather = m.mat("green_feather", "#43a047", rough=0.8, double=True)
    _shell(m, green, green, brown, boots)
    m.part("cylinder", [0.24, 0.31, 0.38], (0, 0.84, 0), green, group="pose")
    m.part("torus", [0.1, 0.2], (0, 1.55, 0.06), green, scale=(1.15, 1.2, 1.1))
    m.part("sphere", [0.12], (0, 1.52, 0.15), green, scale=(1.2, 0.8, 0.7))
    m.part("cylinder", [0.058, 0.055, 0.16], (0.31, 0.99, -0.1), brown, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("box", [0.06, 0.5, 0.02], (0, 1.28, -0.12), brown, rot=(0, 0, 35))
    q = (0.08, 1.3, 0.2)
    m.part("cylinder", [0.05, 0.045, 0.45], q, brown, rot=(-10, 0, -20))
    for i in range(5):
        tip = v_add(q, (-0.08 + i * 0.012, 0.3, 0.03 + (i % 2) * 0.02))
        m.part("cylinder", [0.004, 0.004, 0.18], v_add(tip, (0.02, -0.06, -0.01)), shaft, rot=(-10, 0, -20))
        m.part("prism", [0.03, 0.06, 0.003], tip, feather, rot=(-10, i * 40, -20))
    return m


def outfit_initiate():
    m = O("initiate", "Iniciado", "Túnica longa azul-noturno com bordados dourados, manto curto e grimório preso por corrente.", "#00e5ff")
    robe = m.mat("night_robe", "#141c46", rough=0.75)
    gold = m.mat("gold_embroidery", "#d4ac0d", rough=0.3, metal=0.85, emit="#ffb300", energy=0.25)
    book = m.mat("grimoire", "#5b1f1f", rough=0.7)
    page = m.mat("page", "#f1e6c8", rough=0.9)
    chain = m.mat("chain", "#b0b6bc", rough=0.3, metal=0.9)
    _shell(m, robe, robe, None, None, long_sleeve=True)
    m.part("cylinder", [0.075, 0.09, 0.08], (0.32, 0.93, -0.12), robe, rot=(30, 0, 6), group="arm_r", mirror=True)
    _skirt(m, robe, 0.23, 0.42, 0.95)
    m.part("torus", [0.4, 0.43], (0, 0.07, 0), gold, group="pose")
    m.part("box", [0.04, 0.9, 0.02], (0, 0.55, -0.3), gold, rot=(-14, 0, 0), group="pose")
    m.part("cylinder", [0.3, 0.36, 0.14], (0, 1.5, 0.01), robe)
    m.part("torus", [0.33, 0.36], (0, 1.43, 0.01), gold)
    m.part("box", [0.02, 0.36, 0.02], (0.06, 1.28, -0.172), gold, mirror=True)
    m.part("torus", [0.19, 0.21], (0, 1.02, 0), gold, scale=(1.05, 1, 0.82))
    m.part("cylinder", [0.006, 0.006, 0.12], (0.2, 0.93, -0.07), chain, rot=(0, 0, 15))
    m.part("box", [0.1, 0.13, 0.04], (0.24, 0.82, -0.06), book, rot=(0, -20, 10))
    m.part("box", [0.09, 0.12, 0.03], (0.235, 0.82, -0.08), page, rot=(0, -20, 10))
    return m


def outfit_acolyte():
    m = O("acolyte", "Acólito", "Vestes clericais brancas com placas de ouro no peito e ombros e estola com o símbolo solar/lunar.", "#ffd54f")
    white = m.mat("cleric_white", "#f4f1ea", rough=0.75)
    gold = m.mat("gold_plate", "#e3b52f", rough=0.2, metal=0.95)
    stole = m.mat("stole", "#c9a227", rough=0.6, double=True)
    _shell(m, white, white, None, None, long_sleeve=True)
    _skirt(m, white, 0.23, 0.4, 0.95)
    m.part("box", [0.24, 0.16, 0.05], (0, 1.38, -0.15), gold, rot=(-8, 0, 0))
    m.part("sphere", [0.105], (0.29, 1.52, 0), gold, scale=(1.25, 0.55, 1.15), rot=(0, 0, -22), group="arm_r", mirror=True)
    m.part("box", [0.06, 0.95, 0.015], (0.075, 0.95, -0.165), stole, rot=(4, 0, -3), mirror=True)
    m.part("cylinder", [0.03, 0.03, 0.01], (0.075, 0.62, -0.185), m.mat("sun_sigil", "#fff8e1", emit="#ffc400", energy=2.5), rot=(90, 0, 0))
    m.part("cylinder", [0.03, 0.03, 0.01], (-0.075, 0.62, -0.185), m.mat("moon_sigil", "#e3f2fd", emit="#80d8ff", energy=2.0), rot=(90, 0, 0))
    m.part("torus", [0.19, 0.21], (0, 1.02, 0), gold, scale=(1.05, 1, 0.82))
    return m


def outfit_blacksmith():
    m = O("blacksmith", "Forjador de Estrelas", "Peitoral de couro reforçado com placas de ferro rebitadas, braçadeira mecânica e cinto de ferramentas.", "#ff6d00")
    leather = m.mat("reinforced_leather", "#4a2e1b", rough=0.8)
    iron = m.mat("riveted_iron", "#45484d", rough=0.4, metal=0.85)
    rivet = m.mat("rivet", "#b0b6bc", rough=0.3, metal=0.9)
    pants = m.mat("work_pants", "#3a2f27", rough=0.9)
    boots = m.mat("steel_toe", "#2a2522", rough=0.6)
    _shell(m, leather, None, pants, boots)
    for i, y in enumerate((1.42, 1.3, 1.18)):
        m.part("box", [0.28 - i * 0.02, 0.09, 0.03], (0, y, -0.16), iron)
        for x in (-0.11, 0.11):
            m.part("sphere", [0.01], (x * (1 - i * 0.07), y, -0.178), rivet)
    m.part("cylinder", [0.072, 0.066, 0.24], (0.31, 1.04, -0.07), iron, rot=(30, 0, 6), group="arm_r")
    m.part("torus", [0.07, 0.085], (0.31, 1.12, -0.03), rivet, rot=(30, 0, 6), group="arm_r")
    m.part("torus", [0.04, 0.06], (0.37, 1.04, -0.08), rivet, rot=(30, 0, 96), group="arm_r")
    m.part("torus", [0.19, 0.215], (0, 1.02, 0), leather, scale=(1.05, 1, 0.82))
    for i in range(4):
        a = math.radians(200 + i * 35)
        m.part("box", [0.03, 0.08, 0.02], (math.cos(a) * 0.21, 0.96, math.sin(a) * 0.17), iron)
    return m


def outfit_alchemist():
    m = O("alchemist", "Transmutador", "Casaco longo de couro resistente a ácido, bandoleira de poções e mochila com tanque de vidro borbulhante.", "#00e676")
    coat = m.mat("acid_coat", "#3b2717", rough=0.75, double=True)
    strap = m.mat("bandolier", "#2a1d14", rough=0.8)
    glass = m.mat("tank_glass", "#e0f2f1", rough=0.02, alpha=0.35)
    brew = m.mat("green_brew", "#b9f6ca", emit="#00e676", energy=3.0, alpha=0.85,
                 anim={"type": "glow", "speed": 1.6, "min": 0.6, "max": 1.3})
    brass = m.mat("brass", "#c9a24a", rough=0.25, metal=0.95)
    _shell(m, coat, coat, m.mat("pants", "#2b231d", rough=0.9), m.mat("boots", "#241b15", rough=0.8), long_sleeve=True)
    _skirt(m, coat, 0.23, 0.36, 0.7)
    m.part("box", [0.06, 0.56, 0.025], (0, 1.28, -0.15), strap, rot=(0, 0, -35))
    cols = ["#00e676", "#00d2ff", "#d500f9", "#ffea00", "#00e676"]
    for i, c in enumerate(cols):
        t = (i - 2) * 0.09
        potion = m.mat("potion%d" % i, "#ffffff", emit=c, energy=3.0, alpha=0.9)
        m.part("cylinder", [0.013, 0.013, 0.05], (t * 0.82 + 0.005, 1.28 - t * 0.57, -0.17), potion, rot=(0, 0, -35))
    m.part("box", [0.3, 0.36, 0.14], (0, 1.3, 0.22), strap)
    m.part("cylinder", [0.07, 0.07, 0.3], (0, 1.33, 0.32), glass)
    m.part("cylinder", [0.06, 0.06, 0.22], (0, 1.3, 0.32), brew)
    m.part("torus", [0.068, 0.082], (0, 1.48, 0.32), brass)
    m.part("torus", [0.068, 0.082], (0, 1.18, 0.32), brass)
    for i in range(4):
        m.part("sphere", [0.012], (0.02 * (i - 1.5), 1.25 + i * 0.05, 0.3 + 0.01 * (i % 2)), brew,
               anim={"type": "bob", "amp": 0.03, "speed": 3.0, "phase": i})
    return m


def outfit_reaper():
    m = O("reaper", "Ceifador da Lua Negra", "Manto negro rasgado de caçador sombrio com ombreiras de crânio de corvo e detalhes carmesins.", "#d50000")
    cloak = m.mat("torn_cloak", "#0d0b0e", rough=0.85, double=True)
    crimson = m.mat("crimson", "#8b0000", rough=0.6, emit="#d50000", energy=0.4)
    bone = m.mat("raven_skull", "#e0d8c8", rough=0.5)
    beak = m.mat("beak", "#1a1a1a", rough=0.3)
    _shell(m, cloak, cloak, cloak, m.mat("boots", "#141114", rough=0.6), long_sleeve=True)
    m.group("cloak", (0, 1.5, 0.17), anim={"type": "sway", "axis": [1, 0, 0], "amp": 4.0, "speed": 1.3})
    for i in range(7):
        x = (i - 3) * 0.075
        length = 1.0 - (i % 3) * 0.18
        m.part("box", [0.08, length, 0.02], (x, 1.5 - length / 2, 0.2 + abs(x) * 0.15), cloak,
               rot=(-6, 0, -x * 15), group="cloak")
    m.part("torus", [0.14, 0.25], (0, 1.55, 0.04), cloak, scale=(1.1, 1.3, 1.0))
    m.part("sphere", [0.07], (0.3, 1.6, 0), bone, scale=(1.1, 0.9, 1.2), group="arm_r", mirror=True)
    m.part("cylinder", [0.0, 0.025, 0.12], (0.3, 1.58, -0.1), beak, rot=(-80, 0, 0), group="arm_r", mirror=True)
    m.part("sphere", [0.014], (0.33, 1.62, -0.05), m.mat("socket_glow", "#ff8a80", emit="#d50000", energy=4.0), group="arm_r", mirror=True)
    m.part("box", [0.06, 0.56, 0.025], (0, 1.24, -0.15), crimson, rot=(0, 0, 32))
    m.part("torus", [0.19, 0.21], (0, 1.02, 0), crimson, scale=(1.05, 1, 0.82))
    return m


def outfit_artificer():
    m = O("artificer", "Engenheiro Rúnico", "Armadura Steampunk-Rúnica de bronze, tubos de pressão luminosos nas costas e monóculo rúnico.", "#2979ff")
    bronze = m.mat("bronze_armor", "#9a7034", rough=0.3, metal=0.95)
    iron = m.mat("iron", "#2a2c30", rough=0.4, metal=0.9)
    tube = m.mat("pressure_tube", "#b3e5fc", emit="#2979ff", energy=3.0, alpha=0.85,
                 anim={"type": "glow", "speed": 2.4, "min": 0.5, "max": 1.4})
    lens = m.mat("rune_lens", "#e3f2fd", emit="#2979ff", energy=4.0, alpha=0.8)
    _shell(m, bronze, bronze, iron, bronze, long_sleeve=True)
    m.part("sphere", [0.2], (0, 1.33, -0.035), bronze, scale=(1.3, 1.25, 0.74))
    m.part("sphere", [0.12], (0.3, 1.53, 0), bronze, scale=(1.3, 0.7, 1.2), rot=(0, 0, -25), group="arm_r", mirror=True)
    m.part("box", [0.3, 0.38, 0.12], (0, 1.32, 0.2), iron)
    for x in (-0.09, 0.0, 0.09):
        m.part("cylinder", [0.025, 0.025, 0.42], (x, 1.42, 0.27), tube)
        m.part("torus", [0.025, 0.035], (x, 1.62, 0.27), bronze)
    m.part("torus", [0.028, 0.038], (0.045, 1.72, -0.125), bronze, rot=(90, 0, 0))
    m.part("cylinder", [0.03, 0.03, 0.006], (0.045, 1.72, -0.128), lens, rot=(90, 0, 0))
    m.part("cylinder", [0.003, 0.003, 0.1], (0.075, 1.68, -0.12), m.mat("monocle_chain", "#d4ac0d", rough=0.3, metal=0.9), rot=(0, 0, 20))
    return m


def outfit_homunculus():
    m = O("homunculus_creator", "Demiurgo Alquímico", "Traje real de alquimista supremo em preto, ouro e carmesim.", "#ff1744")
    black = m.mat("royal_black", "#121014", rough=0.55, metal=0.1)
    gold = m.mat("royal_gold", "#d4ac0d", rough=0.25, metal=0.95)
    crimson = m.mat("royal_crimson", "#8b0f1f", rough=0.6, double=True)
    _shell(m, black, black, black, m.mat("boots", "#0c0a0c", rough=0.4, metal=0.3), long_sleeve=True)
    _skirt(m, black, 0.23, 0.34, 0.55)
    m.part("box", [0.03, 0.4, 0.02], (0, 1.28, -0.17), gold)
    for i in range(4):
        m.part("sphere", [0.012], (0.04, 1.42 - i * 0.08, -0.172), gold, mirror=True)
    m.part("cylinder", [0.17, 0.12, 0.14], (0, 1.62, 0.03), crimson)
    m.part("box", [0.06, 0.56, 0.025], (0, 1.24, -0.155), crimson, rot=(0, 0, -32))
    m.group("cape", (0, 1.52, 0.17), anim={"type": "sway", "axis": [1, 0, 0], "amp": 3.0, "speed": 1.2})
    m.part("box", [0.5, 0.6, 0.02], (0, 1.2, 0.2), crimson, rot=(-6, 0, 0), group="cape")
    m.part("torus", [0.19, 0.21], (0, 1.02, 0), gold, scale=(1.05, 1, 0.82))
    m.part("sphere", [0.1], (0.29, 1.52, 0), gold, scale=(1.2, 0.5, 1.1), rot=(0, 0, -22), group="arm_r", mirror=True)
    return m


OUTFITS = [outfit_traveler, outfit_swordsman, outfit_scout, outfit_initiate, outfit_acolyte, outfit_blacksmith,
           outfit_alchemist, outfit_reaper, outfit_artificer, outfit_homunculus] + OUTFITS_CLASSES


# ---------------------------------------------------------------------------
# Loadouts: o que cada classe veste, segura e como se move
# ---------------------------------------------------------------------------
# rot = orientação da arma dentro da mão (Euler YXZ em graus); +Y da arma
# aponta para frente/alto conforme a postura de prontidão de cada arma.

def _hand(weapon, rot=(0, 0, 0), offset=(0, 0, 0)):
    return {"weapon": "weapon_" + weapon, "rot": list(rot), "offset": list(offset)}


LOADOUTS = {
    # O Viajante começa de mãos vazias: a arma só aparece quando houver uma no inventário
    "0": {"name": "Viajante", "outfit": "outfit_traveler",
          "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_r_shield", "5": "skill_f_spin"}},
    # --- 6 Classes Básicas de Combate ---
    "1": {"name": "Espadachim da Aurora", "outfit": "outfit_swordsman",
          "hand_r": _hand("knight_longsword", (-62, 0, 0)),
          "actions": {"1": "attack_1h", "3": "attack_2h_sweep", "4": "skill_q", "5": "skill_f_slam"}},
    "2": {"name": "Arcanista", "outfit": "outfit_initiate",
          "hand_r": _hand("crystal_staff", (-8, 0, 0), (0, 0.05, 0)),
          "actions": {"1": "attack_cast", "3": "attack_cast", "4": "skill_q_support", "5": "skill_f_slam"}},
    "3": {"name": "Sentinela dos Ventos", "outfit": "outfit_scout",
          "hand_l": _hand("recurve_bow", (0, 0, 0)),
          "hand_r": _hand("steel_arrow", (-80, 0, 0)),
          "actions": {"1": "attack_bow", "3": "attack_bow", "4": "skill_r_backflip", "5": "attack_bow"}},
    "4": {"name": "Lâmina Silente", "outfit": "outfit_assassin",
          "hand_r": _hand("assassin_dagger", (-70, 0, 0)),
          "hand_l": _hand("assassin_dagger", (-70, 0, 0)),
          "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_r_backflip", "5": "skill_f_spin"}},
    "5": {"name": "Punho Celeste", "outfit": "outfit_fighter",
          "hand_r": _hand("heavy_gauntlet", (0, 0, 0)),
          "hand_l": _hand("heavy_gauntlet", (0, 0, 0)),
          "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_r_shield", "5": "skill_f_slam"}},
    "6": {"name": "Guardião do Bastião", "outfit": "outfit_shieldbearer",
          "hand_r": _hand("short_mace", (-55, 0, 0)),
          "hand_l": _hand("colossal_shield", (0, 40, 0), (-0.12, 0.1, 0.02)),
          "actions": {"1": "attack_1h", "3": "skill_r_shield", "4": "skill_r_shield", "5": "skill_f_slam"}},
    # --- 6 Classes Básicas de Produção Combatentes ---
    "7": {"name": "Forjador de Estrelas", "outfit": "outfit_blacksmith",
          "hand_r": _hand("forge_warhammer", (160, 0, -8)),
          "actions": {"1": "attack_2h_heavy", "3": "skill_q", "4": "skill_r_sharpen", "5": "skill_f_spin"}},
    "8": {"name": "Transmutador", "outfit": "outfit_alchemist",
          "hand_r": _hand("alchemy_flask", (0, 0, 0)),
          "hand_l": _hand("injector_gauntlet", (0, 0, 0)),
          "actions": {"1": "attack_throw", "3": "attack_throw", "4": "attack_throw", "5": "skill_f_slam"}},
    "9": {"name": "Escultor de Almas", "outfit": "outfit_sculptor",
          "hand_r": _hand("sculptor_chisel", (-70, 0, 0)),
          "companion": "companion_guardian_statue",
          "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_q_support", "5": "skill_f_spin"}},
    "10": {"name": "Senhor das Feras", "outfit": "outfit_tamer",
           "hand_r": _hand("coiled_whip", (0, 0, 0)),
           "companion": "companion_tamed_beast",
           "actions": {"1": "attack_1h", "3": "attack_throw", "4": "skill_q_support", "5": "skill_f_slam"}},
    "11": {"name": "Tecelão Carmesim", "outfit": "outfit_tailor",
           "hand_r": _hand("golden_needle", (-80, 0, 0)),
           "hand_l": _hand("golden_needle", (-80, 0, 0)),
           "actions": {"1": "attack_cast", "3": "attack_2h_sweep", "4": "attack_cast", "5": "skill_f_spin"}},
    "12": {"name": "Mestre do Banquete", "outfit": "outfit_chef",
           "hand_r": _hand("giant_cleaver", (-50, 0, 0)),
           "hand_l": _hand("iron_wok", (0, 40, 0), (-0.1, 0.1, 0.02)),
           "actions": {"1": "attack_2h_heavy", "3": "attack_2h_heavy", "4": "skill_r_shield", "5": "skill_f_slam"}},
    # --- Variantes Secretas (13 a 18) ---
    "13": {"name": "Lâmina Rúnica", "outfit": "outfit_swordsman",
           "hand_r": _hand("runic_sword", (-62, 0, 0)),
           "hand_l": _hand("arcane_orb", (0, 0, 0)),
           "actions": {"1": "attack_1h", "3": "attack_2h_sweep", "4": "skill_r_shield", "5": "attack_cast"}},
    "14": {"name": "Inquisidor de Prata", "outfit": "outfit_scout",
           "hand_r": _hand("silver_crossbow", (0, 0, 0)),
           "hand_l": _hand("holy_stake", (-70, 0, 0)),
           "actions": {"1": "attack_bow", "3": "attack_bow", "4": "attack_throw", "5": "skill_f_slam"}},
    "15": {"name": "Valquíria Celeste", "outfit": "outfit_valkyrie",
           "hand_r": _hand("golden_spear", (-62, 0, 0)),
           "hand_l": _hand("winged_shield", (0, 40, 0), (-0.1, 0.12, 0.02)),
           "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_r_backflip", "5": "skill_f_slam"}},
    "16": {"name": "Punho Fantasma", "outfit": "outfit_assassin",
           "hand_r": _hand("shadow_gauntlet", (0, 0, 0)),
           "hand_l": _hand("shadow_gauntlet", (0, 0, 0)),
           "actions": {"1": "attack_1h", "3": "skill_q", "4": "dodge_roll", "5": "skill_f_spin"}},
    "17": {"name": "Forjador Carmesim", "outfit": "outfit_blacksmith",
           "hand_r": _hand("crimson_hammer", (160, 0, -8)),
           "hand_l": _hand("living_sword", (-62, 0, 0)),
           "actions": {"1": "attack_2h_heavy", "3": "attack_2h_heavy", "4": "skill_r_sharpen", "5": "skill_f_spin"}},
    "18": {"name": "Doutor Corvo", "outfit": "outfit_plague_doctor",
           "hand_r": _hand("scalpel", (-70, 0, 0)),
           "hand_l": _hand("censer", (0, 0, 0)),
           "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_q_support", "5": "attack_throw"}},
    # --- Classes Únicas Exclusivas de Raça (19 a 26) ---
    "19": {"name": "Algoz Vorpal", "outfit": "outfit_assassin",
           "hand_r": _hand("vorpal_stinger", (-70, 0, 0)),
           "hand_l": _hand("vorpal_stinger", (-70, 0, 0)),
           "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_r_backflip", "5": "skill_f_spin"}},
    "20": {"name": "Senhor da Teia Escarlate", "outfit": "outfit_tailor",
           "hand_r": _hand("golden_needle", (-80, 0, 0)),
           "hand_l": _hand("golden_needle", (-80, 0, 0)),
           "actions": {"1": "attack_cast", "3": "attack_2h_sweep", "4": "skill_q_support", "5": "skill_f_spin"}},
    "21": {"name": "Rei-Lobo do Eclipse", "outfit": "outfit_tamer",
           "hand_r": _hand("heavy_gauntlet", (0, 0, 0)),
           "hand_l": _hand("heavy_gauntlet", (0, 0, 0)),
           "companion": "companion_tamed_beast",
           "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_q_support", "5": "skill_f_slam"}},
    "22": {"name": "Runomante Ancestral", "outfit": "outfit_blacksmith",
           "hand_r": _hand("forge_warhammer", (160, 0, -8)),
           "actions": {"1": "attack_2h_heavy", "3": "attack_2h_heavy", "4": "skill_r_sharpen", "5": "skill_f_slam"}},
    "23": {"name": "Colosso Abissal", "outfit": "outfit_shieldbearer",
           "hand_r": _hand("short_mace", (-55, 0, 0)),
           "hand_l": _hand("colossal_shield", (0, 40, 0), (-0.12, 0.1, 0.02)),
           "actions": {"1": "attack_1h", "3": "skill_f_spin", "4": "skill_r_shield", "5": "skill_f_slam"}},
    "24": {"name": "Arquifada de Yggdra", "outfit": "outfit_initiate",
           "hand_r": _hand("crystal_staff", (-8, 0, 0), (0, 0.05, 0)),
           "actions": {"1": "attack_cast", "3": "attack_cast", "4": "skill_q_support", "5": "skill_f_slam"}},
    "25": {"name": "Conde Escarlate", "outfit": "outfit_tailor",
           "hand_r": _hand("living_sword", (-62, 0, 0)),
           "actions": {"1": "attack_1h", "3": "attack_throw", "4": "skill_r_backflip", "5": "skill_f_slam"}},
    "26": {"name": "Barão Engrenagem", "outfit": "outfit_artificer",
           "hand_r": _hand("hammer_cannon", (160, 0, -8)),
           "actions": {"1": "attack_2h_heavy", "3": "attack_throw", "4": "dodge_roll", "5": "skill_f_slam"}},
    # --- Classes Únicas Gerais (27 a 30 e 35 a 39) ---
    "27": {"name": "Ceifador da Lua Negra", "outfit": "outfit_reaper",
           "hand_r": _hand("eclipse_scythe", (-20, 0, 20)),
           "actions": {"1": "attack_2h_sweep", "3": "skill_q", "4": "skill_r_backflip", "5": "skill_f_spin"}},
    "35": {"name": "Engenheiro Rúnico", "outfit": "outfit_artificer",
           "hand_r": _hand("hammer_cannon", (160, 0, -8)),
           "actions": {"1": "attack_2h_heavy", "3": "skill_q", "4": "skill_r_sharpen", "5": "skill_f_slam"}},
    "36": {"name": "Demiurgo Alquímico", "outfit": "outfit_homunculus_creator",
           "hand_r": _hand("philosopher_chalice", (0, 0, 0)),
           "companion": "companion_homunculus",
           "actions": {"1": "attack_cast", "3": "skill_q_support", "4": "attack_cast", "5": "skill_f_slam"}},
    "28": {"name": "Bailarino das Estrelas", "outfit": "outfit_assassin",
           "hand_r": _hand("assassin_dagger", (-70, 0, 0)),
           "hand_l": _hand("assassin_dagger", (-70, 0, 0)),
           "actions": {"1": "attack_1h", "3": "skill_f_spin", "4": "skill_r_backflip", "5": "skill_f_spin"}},
    "29": {"name": "Inquisidor da Chama Branca", "outfit": "outfit_acolyte",
           "hand_r": _hand("executioner_mace", (-55, 0, 0)),
           "actions": {"1": "attack_2h_heavy", "3": "attack_2h_sweep", "4": "skill_q_support", "5": "skill_f_slam"}},
    "30": {"name": "Arauto do Ossuário", "outfit": "outfit_initiate",
           "hand_r": _hand("shadow_orb_staff", (-8, 0, 0), (0, 0.05, 0)),
           "actions": {"1": "attack_cast", "3": "attack_cast", "4": "skill_q_support", "5": "skill_f_slam"}},
    "37": {"name": "Senhor da Selva Primordial", "outfit": "outfit_tamer",
           "hand_r": _hand("primordial_scythe", (-20, 0, 20)),
           "companion": "companion_tamed_beast",
           "actions": {"1": "attack_2h_sweep", "3": "skill_q", "4": "skill_q_support", "5": "skill_f_slam"}},
    "38": {"name": "Cavaleiro do Vazio", "outfit": "outfit_shieldbearer",
           "hand_r": _hand("traitor_greatsword", (-62, 0, 0)),
           "hand_l": _hand("colossal_shield", (0, 40, 0), (-0.12, 0.1, 0.02)),
           "actions": {"1": "attack_2h_heavy", "3": "skill_q", "4": "skill_r_shield", "5": "skill_f_slam"}},
    "39": {"name": "Arauto do Trovão", "outfit": "outfit_initiate",
           "hand_r": _hand("crystal_staff", (-8, 0, 0), (0, 0.05, 0)),
           "actions": {"1": "attack_cast", "3": "attack_cast", "4": "skill_r_backflip", "5": "skill_f_slam"}},
    # --- Classes Lendárias (31 a 34) ---
    "31": {"name": "Herdeiro da Forja Divina", "outfit": "outfit_blacksmith",
           "hand_r": _hand("knight_longsword", (-62, 0, 0)),
           "companion": "companion_six_swords",
           "actions": {"1": "attack_1h", "3": "attack_2h_sweep", "4": "skill_f_spin", "5": "skill_f_slam"}},
    "32": {"name": "Mestre Escultor do Luar", "outfit": "outfit_sculptor",
           "hand_r": _hand("sculptor_chisel", (-70, 0, 0)),
           "companion": "companion_guardian_statue",
           "actions": {"1": "attack_1h", "3": "attack_2h_sweep", "4": "skill_q_support", "5": "skill_f_spin"}},
    "33": {"name": "Imperador Dracônico", "outfit": "outfit_tamer",
           "hand_r": _hand("coiled_whip", (0, 0, 0)),
           "companion": "companion_elder_dragon",
           "actions": {"1": "attack_1h", "3": "skill_q", "4": "skill_q_support", "5": "skill_f_slam"}},
    "34": {"name": "Soberano do Sol Negro", "outfit": "outfit_reaper",
           "hand_r": _hand("black_sun_blade", (-62, 0, 0)),
           "actions": {"1": "attack_2h_heavy", "3": "attack_2h_sweep", "4": "skill_r_shield", "5": "skill_f_slam"}},
}
for _l in LOADOUTS.values():
    _l["actions"].update({"2": "dodge_roll", "6": "skill_z"})
