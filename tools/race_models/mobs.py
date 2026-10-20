"""Criaturas (mobs) de Lunaria, com pelagem em tufos, asas de penas/membrana e
texturas em todas as peças. IDs iguais aos tipos do servidor (MobEntity.gd)."""

import math

from modelkit import (Model, humanoid, fur_tufts, feather_wing, membrane_wing, v_add, v_lerp, v_scale)
from races_base import belt, eyes, tail
import races_base


def M(mob_id, key, name, title, desc, color, scale=1.0):
    return Model(mob_id, key, name, title, desc, color, scale=scale, kind="mob", seed=300 + mob_id)


def _hand(weapon, rot=(0, 0, 0), offset=(0, 0, 0)):
    return {"weapon": "weapon_" + weapon, "rot": list(rot), "offset": list(offset)}


# ---------------------------------------------------------------------------
# Quadrúpede (lobos)
# ---------------------------------------------------------------------------

def _wolf(m, fur, fur_light, skin, eye, claw, mist=None, mane=1.0):
    m.body_w = 1.0
    m.extra_actions = {"attack": "beast_bite", "death": "beast_death", "hit": "beast_bite"}
    # Corpo
    m.part("capsule", [0.2, 0.95], (0, 0.62, 0.05), fur, rot=(90, 0, 0))
    m.part("sphere", [0.23], (0, 0.65, -0.3), fur, scale=(0.95, 1.08, 1.1))
    m.part("sphere", [0.19], (0, 0.62, 0.4), fur, scale=(1.0, 1.0, 1.05))
    m.part("sphere", [0.16], (0, 0.52, -0.22), fur_light, scale=(0.8, 0.8, 1.3))
    # Pescoço e cabeça
    m.seg((0, 0.7, -0.38), (0, 0.84, -0.6), 0.14, 0.11, fur)
    m.part("sphere", [0.12], (0, 0.88, -0.66), fur, scale=(0.95, 0.9, 1.1))
    m.seg((0, 0.85, -0.74), (0, 0.81, -0.97), 0.07, 0.036, fur)
    m.seg((0, 0.79, -0.72), (0, 0.765, -0.93), 0.05, 0.028, fur_light)
    m.part("sphere", [0.026], (0, 0.83, -0.98), skin)
    for dx in (-0.025, 0.025):
        m.part("cylinder", [0.0, 0.006, 0.028], (dx, 0.765, -0.9), claw, rot=(180, 0, 0))
    m.part("sphere", [0.018], (0.05, 0.915, -0.75), eye, scale=(1.4, 0.7, 1), mirror=True)
    m.part("cylinder", [0.0, 0.045, 0.12], (0.06, 0.99, -0.62), fur, rot=(-12, 0, -16), scale=(1, 1, 0.45), mirror=True)
    m.part("cylinder", [0.0, 0.03, 0.08], (0.06, 0.985, -0.628), skin, rot=(-12, 0, -16), scale=(1, 1, 0.3), mirror=True)
    # Pernas dianteiras (canal arm_*) e traseiras (canal leg_*)
    m.group("arm_r", (0.12, 0.6, -0.3), mirror=True)
    m.chain([(0.12, 0.6, -0.3), (0.13, 0.35, -0.28), (0.12, 0.1, -0.33)], [0.065, 0.045, 0.035],
            fur, group="arm_r", mirror=True, joints=fur)
    m.part("sphere", [0.045], (0.12, 0.04, -0.37), fur, scale=(1, 0.6, 1.3), group="arm_r", mirror=True)
    m.group("leg_r", (0.12, 0.62, 0.42), mirror=True)
    m.chain([(0.12, 0.62, 0.42), (0.14, 0.4, 0.53), (0.13, 0.22, 0.43), (0.12, 0.06, 0.47)],
            [0.075, 0.05, 0.035, 0.03], fur, group="leg_r", mirror=True, joints=fur)
    m.part("sphere", [0.043], (0.12, 0.035, 0.44), fur, scale=(1, 0.6, 1.3), group="leg_r", mirror=True)
    for g, base in (("arm_r", (0.12, 0.025, -0.42)), ("leg_r", (0.12, 0.025, 0.4))):
        for dx in (-0.02, 0.0, 0.02):
            m.part("cylinder", [0.0, 0.008, 0.035], v_add(base, (dx, 0, 0)), claw, rot=(-80, 0, 0), group=g, mirror=True)
    # Cauda espessa
    pts = [(0, 0.68, 0.6), (0, 0.6, 0.8), (0, 0.48, 0.98), (0, 0.36, 1.1)]
    last = tail(m, pts, [0.06, 0.08, 0.075, 0.045], fur, amp=12)
    fur_tufts(m, (0, 0.5, 0.95), (0.07, 0.12, 0.14), 28, fur, group="tail1", length=0.07, bias=(0, -0.3, 0.6))
    fur_tufts(m, (0, 0.38, 1.08), (0.05, 0.06, 0.08), 14, fur_light, group=last, length=0.06, bias=(0, -0.4, 0.8))
    # Pelagem: costas, juba no pescoço, bochechas e peito
    fur_tufts(m, (0, 0.66, 0.05), (0.2, 0.2, 0.55), int(70 * mane), fur, length=0.07,
              bias=(0, 0.1, 0.9), region=lambda x, y, z: y > 0.15, seed=1)
    fur_tufts(m, (0, 0.76, -0.48), (0.16 * mane, 0.16 * mane, 0.16), int(46 * mane), fur_light, length=0.09 * mane,
              bias=(0, -0.2, 0.7), seed=2)
    fur_tufts(m, (0, 0.86, -0.7), (0.1, 0.08, 0.06), 14, fur_light, length=0.05, bias=(0, -0.4, 0.5),
              region=lambda x, y, z: abs(x) > 0.5, seed=3)
    fur_tufts(m, (0, 0.5, -0.28), (0.13, 0.08, 0.14), 18, fur_light, length=0.06, bias=(0, -0.9, 0.2),
              region=lambda x, y, z: y < 0, seed=4)
    if mist:
        for i, (x, z) in enumerate(((0.12, -0.38), (-0.12, -0.38), (0.12, 0.45), (-0.12, 0.45))):
            m.part("sphere", [0.07], (x, 0.09, z), mist, scale=(1.6, 0.5, 1.6),
                   anim={"type": "bob", "amp": 0.03, "speed": 1.4, "phase": i})
    m.anchor("hand_r", "arm_r", (0.12, 0.05, -0.37))
    m.anchor("hand_l", "arm_l", (-0.12, 0.05, -0.37))
    m.anchor("back", None, (0, 0.85, 0.05))


def lobo_bruma():
    m = M(1, "lobo_bruma", "Lobo da Bruma", "Matilha do Bosque Sussurrante",
          "Quadrúpede ágil de pelagem cinza densa em camadas, focinho longo, olhos vermelhos luminosos e névoa "
          "enrolando nas patas.", "#90a4ae", scale=1.0)
    fur = m.mat("fur_grey", "#5c6670", rough=0.95)
    fur_l = m.mat("fur_grey_light", "#8a949c", rough=0.95)
    skin = m.mat("nose_leather", "#141416", rough=0.4)
    eye = m.mat("eye_red", "#ff8a80", emit="#ff1744", energy=6.0)
    claw = m.mat("claw", "#2b2b2e", rough=0.3)
    mist = m.mat("mist", "#b3c7d6", emit="#81a4c0", energy=0.5, alpha=0.16)
    _wolf(m, fur, fur_l, skin, eye, claw, mist)
    m.primary = "fur_grey"
    m.light("#ff1744", 0.2, 1.5, (0, 0.9, -0.9))
    return m


def lobo_alfa():
    m = M(6, "lobo_alfa", "Lobo Alfa", "Senhor da Matilha",
          "Lobo majestoso 1,45 vez maior, de pelagem prateada brilhante, juba espessa em volta do pescoço e olhos "
          "dourados; as pontas do pelo brilham em azul sob o luar.", "#cfd8dc", scale=1.45)
    fur = m.mat("fur_silver", "#c9d1dc", rough=0.85, emit="#3f7bd6", energy=0.35)
    fur_l = m.mat("fur_silver_tips", "#eef3fa", rough=0.8, emit="#64b5f6", energy=0.6)
    skin = m.mat("nose_leather", "#1b1b20", rough=0.4)
    eye = m.mat("eye_gold", "#fff59d", emit="#ffd600", energy=7.0)
    claw = m.mat("claw", "#3a3a40", rough=0.3)
    _wolf(m, fur, fur_l, skin, eye, claw, mane=1.6)
    m.primary = "fur_silver"
    m.light("#64b5f6", 0.5, 3.0, (0, 1.0, -0.5))
    return m


# ---------------------------------------------------------------------------
# Humanoides
# ---------------------------------------------------------------------------

def saqueador():
    m = M(2, "saqueador", "Saqueador Deserdado", "Ruínas da Vigília",
          "Bandido de armadura de couro remendada vermelho-ferrugem, escudo redondo de ferro amassado com cravos, "
          "espada curta lascada, bandana e cachecol.", "#bf5a3c", scale=1.0)
    skin = m.mat("skin", "#c99a7c", rough=0.55)
    leather = m.mat("rust_leather", "#94402c", rough=0.75)
    pants = m.mat("patched_pants", "#4a3a2e", rough=0.9)
    boots = m.mat("boots", "#2e241c", rough=0.8)
    cloth = m.mat("bandana_cloth", "#6b1e1e", rough=0.85, double=True)
    iron = m.mat("rivet_iron", "#7d8287", rough=0.4, metal=0.8)
    iris = m.mat("iris", "#4b3621", rough=0.3)
    humanoid(m, skin, leather, pants, boots, w=1.05)
    eyes(m, iris, m.mat("sclera", "#efe9e2", rough=0.3))
    m.part("sphere", [0.136], (0, 1.76, 0.015), cloth, scale=(1.04, 0.8, 1.05))
    m.part("box", [0.03, 0.12, 0.02], (0.06, 1.74, 0.13), cloth, rot=(30, 0, 25), mirror=True)
    m.part("torus", [0.07, 0.11], (0, 1.56, -0.01), cloth, scale=(1.1, 1.3, 1.0))
    m.part("sphere", [0.2], (0, 1.3, -0.01), leather, scale=(1.26, 1.22, 0.84))
    for i in range(5):
        m.part("box", [0.06, 0.05, 0.015], (-0.12 + i * 0.06, 1.25 + (i % 2) * 0.12, -0.17), pants, rot=(0, 0, 10 * i))
    for x in (-0.1, 0.0, 0.1):
        m.part("sphere", [0.01], (x, 1.42, -0.16), iron)
    belt(m, m.mat("belt", "#3b2a1e", rough=0.8), iron, w=1.05)
    m.part("box", [0.08, 0.1, 0.05], (0.2, 0.92, -0.06), m.mat("pouch", "#5a4030", rough=0.9), rot=(0, -20, 0))
    m.part("box", [0.24, 0.05, 0.26], (0.33, 1.58, 0), leather, rot=(0, 0, -26), group="arm_r")
    m.gear = {"hand_r": _hand("raider_short_sword", (-60, 0, 0)), "hand_l": _hand("raider_round_shield", (0, 40, 0), (-0.08, 0.1, 0.02))}
    m.extra_actions = {"attack": "attack_1h", "block": "skill_r_shield", "death": "death_fall"}
    m.primary = "rust_leather"
    m.shield_material = ("weapon_raider_round_shield", "dented_iron")
    return m


def besteiro():
    m = M(3, "besteiro", "Besteiro da Vigília", "Torre da Vigília",
          "Atirador de gibão acolchoado verde-caçador, braçadeiras de couro, capuz e besta pesada de madeira com "
          "braços de ferro.", "#43a047", scale=1.0)
    skin = m.mat("skin", "#d2a586", rough=0.55)
    gamb = m.mat("hunter_gambeson", "#2e6b3e", rough=0.85)
    leather = m.mat("bracer_leather", "#5a3f2b", rough=0.8)
    pants = m.mat("pants", "#3b3328", rough=0.9)
    hood = m.mat("hood_cloth", "#24502f", rough=0.85, double=True)
    iris = m.mat("iris", "#37474f", rough=0.3)
    humanoid(m, skin, gamb, pants, leather, forearm=leather, w=1.0)
    eyes(m, iris, m.mat("sclera", "#efe9e2", rough=0.3))
    m.part("sphere", [0.145], (0, 1.75, 0.03), hood, scale=(1.05, 1.1, 1.12))
    m.part("cylinder", [0.0, 0.08, 0.16], (0, 1.82, 0.16), hood, rot=(115, 0, 0))
    m.part("torus", [0.1, 0.17], (0, 1.55, 0.02), hood, scale=(1.1, 1.3, 1.0))
    for i in range(4):
        m.part("torus", [0.19 - i * 0.004, 0.205 - i * 0.004], (0, 1.12 + i * 0.1, 0), leather, scale=(1.2, 0.3, 0.84))
    belt(m, leather, m.mat("buckle", "#9aa3ab", rough=0.3, metal=0.9))
    m.part("cylinder", [0.045, 0.04, 0.38], (0.2, 0.9, 0.08), leather, rot=(15, 0, -12))
    for i in range(4):
        m.part("cylinder", [0.004, 0.004, 0.16], (0.19 + i * 0.012, 1.12, 0.1), m.mat("bolt_shaft", "#b08a5a", rough=0.7), rot=(15, 0, -12))
    m.gear = {"hand_r": _hand("heavy_crossbow", (-90, 0, 0), (0, 0.02, 0))}
    m.extra_actions = {"attack": "attack_bow", "death": "death_fall"}
    m.primary = "hunter_gambeson"
    return m


def _robed(m, robe, trim, skin, eye, hood_depth=0.04, w=0.95):
    humanoid(m, skin, robe, robe, robe, w=w)
    m.part("cylinder", [0.21, 0.42, 1.0], (0, 0.52, 0.0), robe)
    m.part("torus", [0.4, 0.43], (0, 0.05, 0), trim)
    m.part("sphere", [0.155], (0, 1.74, hood_depth), robe, scale=(1.05, 1.12, 1.12))
    m.part("sphere", [0.115], (0, 1.71, -0.04), m.mat("hood_shadow", "#050307", rough=1.0), scale=(1.0, 1.05, 0.8))
    m.part("sphere", [0.016], (0.04, 1.72, -0.12), eye, mirror=True)
    m.part("box", [0.05, 0.9, 0.02], (0, 0.6, -0.24), trim, rot=(-12, 0, 0))


def acolito_eclipse():
    m = M(4, "acolito_eclipse", "Acólito do Eclipse", "Culto do Santuário",
          "Acólito de túnica roxo-escura com bordados ocultistas, rosto pálido escondido no capuz e cajado retorcido "
          "com um orbe de sombras flutuante.", "#7e57c2", scale=1.0)
    robe = m.mat("eclipse_robe", "#3a1d55", rough=0.8, double=True)
    trim = m.mat("occult_embroidery", "#b39ddb", rough=0.4, metal=0.6, emit="#7c4dff", energy=0.5)
    skin = m.mat("pale_skin", "#d9cfc9", rough=0.5)
    eye = m.mat("eye_violet", "#e1bee7", emit="#aa00ff", energy=6.0)
    _robed(m, robe, trim, skin, eye)
    for i in range(3):
        m.part("box", [0.012, 0.08, 0.012], (0.06 * (i - 1), 1.35, -0.165), trim, rot=(0, 0, 20 * (i - 1)))
    m.gear = {"hand_r": _hand("shadow_orb_staff", (-8, 0, 0), (0, 0.05, 0))}
    m.extra_actions = {"attack": "attack_cast", "death": "death_fall"}
    m.primary = "eclipse_robe"
    return m


def cultista():
    m = M(10, "cultista", "Cultista Sombrio", "Seita das Trevas",
          "Túnica violeta rasgada, capuz profundo, amuletos de osso, adagas rituais no cinto e fumaça escorrendo da barra.",
          "#5e35b1", scale=1.0)
    robe = m.mat("tattered_robe", "#2b1a38", rough=0.85, double=True)
    trim = m.mat("bone_charm", "#e0d8c8", rough=0.5)
    skin = m.mat("pale_skin", "#cfc4be", rough=0.5)
    eye = m.mat("eye_violet", "#e1bee7", emit="#d500f9", energy=6.0)
    smoke = m.mat("dark_smoke", "#1a1024", emit="#4a148c", energy=0.6, alpha=0.4,
                  anim={"type": "flicker", "speed": 2.0, "min": 0.5, "max": 1.0})
    _robed(m, robe, trim, skin, eye)
    for i in range(10):
        a = i * 2 * math.pi / 10
        m.part("box", [0.08, 0.16 + (i % 3) * 0.06, 0.01], (math.cos(a) * 0.42, 0.08, math.sin(a) * 0.42), robe,
               rot=(0, -math.degrees(a) + 90, 0))
        m.part("sphere", [0.08], (math.cos(a) * 0.45, 0.06, math.sin(a) * 0.45), smoke, scale=(1.3, 0.5, 1.3),
               anim={"type": "bob", "amp": 0.04, "speed": 1.3, "phase": i})
    for i in range(4):
        m.part("sphere", [0.018], (-0.14 + i * 0.09, 1.0, -0.17), trim, scale=(1, 1.4, 0.7))
    m.part("box", [0.02, 0.18, 0.006], (0.22, 0.92, -0.08), m.mat("ritual_dagger", "#b0bec5", rough=0.2, metal=0.9), rot=(0, 0, 15))
    m.gear = {"hand_l": _hand("darkness_orb", (0, 0, 0))}
    m.extra_actions = {"attack": "attack_cast", "death": "death_fall"}
    m.primary = "tattered_robe"
    return m


def executor():
    m = M(5, "executor", "Executor de Ferro", "Carrasco das Ruínas",
          "Bruto colossal 1,4 vez maior em armadura de placas de ferro negro, ombreiras imensas, elmo fechado de balde "
          "e maça de ferro gigantesca com aletas.", "#546e7a", scale=1.4)
    iron = m.mat("black_iron_plate", "#2a2c31", rough=0.4, metal=0.85)
    iron_d = m.mat("dark_iron", "#1a1b1f", rough=0.45, metal=0.85)
    leather = m.mat("strap_leather", "#3b2a1e", rough=0.8)
    cloth = m.mat("executioner_hood", "#5a1414", rough=0.85, double=True)
    slit = m.mat("visor_slit", "#ff6d00", emit="#ff3d00", energy=2.5)
    humanoid(m, iron_d, iron, iron_d, iron, hands=iron, forearm=iron, w=1.3, head=False)
    m.part("cylinder", [0.14, 0.15, 0.26], (0, 1.72, 0), iron)
    m.part("box", [0.2, 0.014, 0.02], (0, 1.75, -0.15), slit)
    m.part("box", [0.02, 0.1, 0.02], (0, 1.68, -0.15), slit)
    m.part("cylinder", [0.2, 0.1, 0.22], (0, 1.57, 0.02), cloth)
    for k in range(3):
        m.part("sphere", [0.16 - k * 0.015], (0.36 + k * 0.03, 1.56 - k * 0.07, 0), iron, scale=(1.3, 0.55, 1.2),
               rot=(0, 0, -20 - k * 12), group="arm_r", mirror=True)
        m.part("cylinder", [0.0, 0.03, 0.12], (0.38 + k * 0.03, 1.66 - k * 0.07, 0.05), iron_d, rot=(0, 0, -30), group="arm_r", mirror=True)
    m.part("box", [0.08, 0.6, 0.03], (0, 1.28, -0.18), leather, rot=(0, 0, 32))
    belt(m, leather, iron, w=1.3)
    for i in range(6):
        m.part("torus", [0.016, 0.026], (-0.25 + i * 0.012, 0.95 - i * 0.05, -0.14), iron, rot=(0, 90 * (i % 2), 80))
    m.gear = {"hand_r": _hand("executioner_mace", (160, 0, -8))}
    m.extra_actions = {"attack": "attack_2h_heavy", "death": "death_fall"}
    m.primary = "black_iron_plate"
    return m


def licantropo_alfa():
    m = races_base.licantropo()
    m.kind = "mob"
    m.race_id = 7
    m.key = "licantropo_alfa"
    m.name = "Licantropo Alfa"
    m.title = "Raid Boss da Lua de Sangue"
    m.lore = ("Gigante bípede de ombros cobertos de espinhos musculares, pelagem negro-carmesim eriçada, focinho lupino "
              "alongado, olhos vermelho-sangue e garras longas nas duas mãos.")
    m.scale = 1.8
    spike = m.mat("muscle_spike", "#2a1214", rough=0.3, metal=0.2)
    chain = m.mat("torn_chain", "#55575c", rough=0.4, metal=0.85)
    fur_tufts(m, (0, 1.42, 0.0), (0.34, 0.3, 0.24), 90, "fur_black", length=0.1, bias=(0, 0.4, 0.6),
              region=lambda x, y, z: y > -0.1, seed=7)
    fur_tufts(m, (0, 1.38, -0.12), (0.26, 0.24, 0.12), 40, "fur_crimson", length=0.07, bias=(0, -0.5, -0.4), seed=8)
    fur_tufts(m, (0.42, 1.24, 0), (0.1, 0.22, 0.1), 26, "fur_black", group="arm_r", length=0.07, bias=(0.5, -0.4, 0.2),
              seed=9, mirror=True)
    for i in range(6):
        a = math.radians(-60 + i * 24)
        m.part("cylinder", [0.0, 0.04, 0.2], (math.sin(a) * 0.3, 1.62 + 0.04 * (i % 2), math.cos(a) * 0.12 + 0.05),
               spike, rot=(-30, 0, -math.degrees(a) * 0.8))
    for i in range(3):
        m.part("torus", [0.03, 0.05], (0.47, 0.88 - i * 0.07, -0.1 - i * 0.02), chain, rot=(0, 90 * (i % 2), 70),
               group="arm_r", mirror=True)
    m.extra_actions = {"attack": "attack_2h_heavy", "death": "death_fall"}
    m.primary = "fur_black"
    return m


def gargula():
    m = M(11, "gargula", "Gárgula de Pedra", "Sentinela das Ruínas",
          "Corpo de pedra cinza curvado, rachado e com musgo, grandes asas de rocha com membranas de pedra e dedos "
          "ósseos, cabeça demoníaca com chifres e olhos de âmbar.", "#90a4ae", scale=1.05)
    stone = m.mat("gargoyle_stone", "#6f767c", rough=0.95)
    stone_d = m.mat("dark_stone", "#4b5156", rough=0.95)
    membrane = m.mat("stone_membrane", "#5b6369", rough=0.9, double=True)
    moss = m.mat("moss", "#4f6b2f", rough=1.0)
    eye = m.mat("eye_amber", "#ffe0b2", emit="#ff9100", energy=6.0)
    m.rest_pose = {"torso": [-18, 0, 0]}
    humanoid(m, stone, stone, stone_d, stone_d, w=1.15, head=False)
    m.part("sphere", [0.14], (0, 1.68, -0.06), stone, scale=(1.05, 0.95, 1.1))
    m.part("box", [0.12, 0.08, 0.12], (0, 1.62, -0.18), stone_d, rot=(10, 0, 0))
    m.part("sphere", [0.02], (0.05, 1.7, -0.17), eye, mirror=True)
    m.chain([(0.07, 1.78, -0.06), (0.12, 1.88, 0.0), (0.12, 1.94, 0.12)], [0.03, 0.02, 0.0], stone_d, mirror=True)
    for dx in (-0.02, 0.0, 0.02):
        m.part("cylinder", [0.0, 0.01, 0.06], (0.32 + dx, 0.82, -0.18), stone_d, rot=(25, 0, 0), group="arm_r", mirror=True)
        m.part("cylinder", [0.0, 0.012, 0.07], (0.12 + dx * 1.6, 0.03, -0.2), stone_d, rot=(-80, 0, 0), group="leg_r", mirror=True)
    for p in ((0.12, 1.45, -0.14), (-0.15, 1.2, -0.15), (0.3, 1.6, 0.05), (-0.05, 1.86, 0.02)):
        m.part("sphere", [0.05], p, moss, scale=(1.4, 0.5, 1.2))
    m.group("wing_r", (0.14, 1.48, 0.18), anim={"type": "sway", "axis": [0, 1, 0], "amp": 6.0, "speed": 1.0})
    m.group("wing_l", (-0.14, 1.48, 0.18), anim={"type": "sway", "axis": [0, -1, 0], "amp": 6.0, "speed": 1.0})
    membrane_wing(m, (0.14, 1.48, 0.18), 1, 1.0, stone_d, membrane, "wing_r")
    membrane_wing(m, (-0.14, 1.48, 0.18), -1, 1.0, stone_d, membrane, "wing_l")
    tail(m, [(0, 0.95, 0.12), (0, 0.7, 0.4), (0.05, 0.4, 0.6), (0.1, 0.15, 0.75)], [0.06, 0.05, 0.04, 0.02], stone)
    m.extra_actions = {"attack": "attack_1h", "death": "death_fall"}
    m.primary = "gargoyle_stone"
    return m


def inquisidor():
    m = M(12, "inquisidor_vex", "Inquisidor Vex", "Mini-Boss",
          "Figura alta e esguia de túnica carmesim e negra com gola alta, máscara de ferro, selos sagrados, correntes "
          "e uma foice longa de lâmina carmesim.", "#c62828", scale=1.12)
    robe = m.mat("inquisitor_robe", "#5a0f18", rough=0.8, double=True)
    black = m.mat("black_robe", "#120b10", rough=0.75, double=True)
    iron = m.mat("iron_mask", "#6f747a", rough=0.3, metal=0.9)
    gold = m.mat("holy_seal_gold", "#d4ac0d", rough=0.25, metal=0.9)
    page = m.mat("seal_page", "#f1e6c8", rough=0.9)
    eye = m.mat("eye_red", "#ff8a80", emit="#ff1744", energy=6.0)
    _robed(m, robe, gold, m.mat("pale_skin", "#d9cfc9", rough=0.5), eye, w=0.88)
    m.part("box", [0.1, 0.12, 0.03], (0, 1.7, -0.13), iron)
    m.part("box", [0.08, 0.008, 0.01], (0, 1.72, -0.148), m.mat("mask_slit", "#ff1744", emit="#ff1744", energy=3.0))
    m.part("cylinder", [0.2, 0.14, 0.24], (0, 1.62, 0.04), black)
    m.part("box", [0.3, 0.9, 0.02], (0, 0.75, 0.2), black, rot=(-6, 0, 0))
    for i in range(4):
        m.part("box", [0.05, 0.12, 0.004], (-0.15 + i * 0.1, 1.05, -0.2), page, rot=(5, 0, (i - 1.5) * 8))
        m.part("cylinder", [0.015, 0.015, 0.008], (-0.15 + i * 0.1, 1.1, -0.205), gold, rot=(90, 0, 0))
    m.gear = {"hand_r": _hand("eclipse_scythe", (-20, 0, 20))}
    m.extra_actions = {"attack": "attack_2h_sweep", "death": "death_fall"}
    m.primary = "inquisitor_robe"
    return m


def vaelen():
    m = M(13, "vaelen", "Comandante Vaelen, o Traidor", "Boss",
          "Armadura completa de aço escuro com ombreiras douradas, capa real rasgada, brasão de cavaleiro riscado, "
          "rosto marcado e espadão largo.", "#ffd54f", scale=1.15)
    steel = m.mat("dark_steel", "#454b54", rough=0.25, metal=0.9)
    gold = m.mat("gold_pauldron", "#c9a227", rough=0.25, metal=0.95)
    cape = m.mat("torn_royal_cape", "#1b3a5c", rough=0.8, double=True)
    skin = m.mat("scarred_skin", "#b88a70", rough=0.6)
    scar = m.mat("scar", "#8a5a48", rough=0.6)
    hair = m.mat("hair", "#2a2420", rough=0.5)
    iris = m.mat("iris", "#5d4037", rough=0.3)
    humanoid(m, skin, steel, steel, steel, hands=steel, forearm=steel, w=1.12)
    eyes(m, iris, m.mat("sclera", "#efe9e2", rough=0.3))
    races_base.hair_short(m, hair)
    m.part("box", [0.01, 0.1, 0.01], (-0.07, 1.71, -0.108), scar, rot=(0, 0, -25))
    m.part("box", [0.01, 0.08, 0.01], (0.03, 1.66, -0.118), scar, rot=(0, 0, 40))
    m.part("sphere", [0.2], (0, 1.33, -0.035), steel, scale=(1.32, 1.25, 0.74))
    m.part("box", [0.1, 0.008, 0.012], (0, 1.36, -0.185), scar, rot=(0, 0, 35))
    for k in range(3):
        m.part("sphere", [0.13 - k * 0.012], (0.31 + k * 0.025, 1.55 - k * 0.05, 0), gold, scale=(1.3, 0.55, 1.2),
               rot=(0, 0, -22 - 10 * k), group="arm_r", mirror=True)
    m.group("cape", (0, 1.52, 0.17), anim={"type": "sway", "axis": [1, 0, 0], "amp": 3.0, "speed": 1.0})
    for i in range(6):
        x = (i - 2.5) * 0.09
        length = 1.25 - (i % 3) * 0.22
        m.part("box", [0.1, length, 0.025], (x, 1.52 - length / 2, 0.2 + abs(x) * 0.1), cape, rot=(-6, 0, 0), group="cape")
    belt(m, gold, gold, w=1.1)
    m.gear = {"hand_r": _hand("traitor_greatsword", (-62, 0, 0))}
    m.extra_actions = {"attack": "attack_2h_heavy", "death": "death_fall"}
    m.primary = "dark_steel"
    return m


def malakor():
    m = M(14, "malakor", "Malakor, o Arauto do Eclipse", "Raid Boss",
          "Ser abissal colossal 2,2 vezes maior, corpo negro como o vazio com aura roxa do eclipse, asas primordiais "
          "de sombra com camadas de penas e membranas, coroa de chifres escuros e a foice primordial do eclipse.",
          "#aa00ff", scale=2.2)
    void = m.mat("void_body", "#0a0612", rough=0.6, metal=0.2, emit="#6a1b9a", energy=0.25)
    star = m.mat("void_star", "#ffffff", emit="#e1bee7", energy=4.0)
    horn = m.mat("eclipse_horn", "#1a1022", rough=0.2, metal=0.4)
    feather = m.mat("shadow_feather", "#140a1e", rough=0.4, metal=0.3, emit="#7c4dff", energy=0.5, double=True)
    covert = m.mat("shadow_covert", "#1e1030", rough=0.45, emit="#aa00ff", energy=0.4, double=True)
    membrane = m.mat("eclipse_membrane", "#2a0f3d", rough=0.5, emit="#aa00ff", energy=0.8, alpha=0.8, double=True)
    eye = m.mat("eye_eclipse", "#ea80fc", emit="#d500f9", energy=8.0)
    aura = m.mat("eclipse_aura", "#e040fb", emit="#aa00ff", energy=2.5, alpha=0.35,
                 anim={"type": "flicker", "speed": 2.0, "min": 0.5, "max": 1.0})
    humanoid(m, void, void, void, void, w=1.15)
    m.part("sphere", [0.02], (0.045, 1.72, -0.112), eye, scale=(1.6, 0.6, 1), mirror=True)
    for i in range(30):
        y = m.rng.uniform(0.2, 1.8)
        a = m.rng.uniform(0, 2 * math.pi)
        m.part("sphere", [0.006], (math.cos(a) * 0.2, y, math.sin(a) * 0.15), star)
    for i in range(7):
        a = math.radians(-90 + (i - 3) * 28)
        base = (math.cos(a) * 0.11, 1.82, math.sin(a) * 0.11 + 0.01)
        h = 0.16 if i == 3 else 0.11 - abs(i - 3) * 0.01
        m.chain([base, v_add(base, (math.cos(a) * 0.04, h * 0.6, math.sin(a) * 0.04 + 0.03)),
                 v_add(base, (math.cos(a) * 0.05, h, math.sin(a) * 0.05 + 0.08))], [0.02, 0.012, 0.0], horn)
    m.group("wing_r", (0.12, 1.45, 0.17), anim={"type": "sway", "axis": [0, 1, 0], "amp": 8.0, "speed": 0.9})
    m.group("wing_l", (-0.12, 1.45, 0.17), anim={"type": "sway", "axis": [0, -1, 0], "amp": 8.0, "speed": 0.9})
    for side, g in ((1, "wing_r"), (-1, "wing_l")):
        feather_wing(m, (side * 0.12, 1.45, 0.17), side, 1.25, feather, covert, horn, g)
        membrane_wing(m, (side * 0.14, 1.5, 0.22), side, 0.95, horn, membrane, g)
    # Coroa do eclipse aos pés: anéis de energia girando (não encobrem o corpo)
    m.group("eclipse_rings", (0, 0.05, 0), anim={"type": "spin", "axis": [0, 1, 0], "speed": 25})
    for i, r in enumerate((0.55, 0.7, 0.85)):
        m.part("torus", [r - 0.015, r], (0, 0.04 + i * 0.03, 0), aura, group="eclipse_rings")
    m.gear = {"hand_r": _hand("primordial_scythe", (-20, 0, 20))}
    m.extra_actions = {"attack": "attack_2h_sweep", "death": "death_fall"}
    m.primary = "void_body"
    m.light("#aa00ff", 1.0, 5.0, (0, 1.4, -0.6))
    return m


MOBS = [lobo_bruma, saqueador, besteiro, acolito_eclipse, executor, lobo_alfa, licantropo_alfa, cultista, gargula,
        inquisidor, vaelen, malakor]
