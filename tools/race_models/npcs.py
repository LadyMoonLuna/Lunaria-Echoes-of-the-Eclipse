"""NPCs da Vila do Refúgio e do mundo (IDs do servidor)."""

import math

from modelkit import Model, humanoid, v_add
from races_base import eyes, belt


def N(npc_id, key, name, title, desc, color, scale=1.0):
    return Model(npc_id, key, name, title, desc, color, scale=scale, kind="npc", seed=npc_id)


def garrick():
    m = N(100, "garrick", "Garrick", "Mestre Ferreiro",
          "Homem robusto de sangue Kharad, tronco largo como um barril e braços musculosos marcados por "
          "queimaduras e fuligem. Careca, de barba longa trançada em três pontas presas por anéis de bronze, "
          "com as pontas levemente chamuscadas. Ranzinza, porém honrado.",
          "#ff9800", scale=0.9)
    skin = m.mat("skin_soot", "#b98a6a", rough=0.7)
    scar = m.mat("burn_scar", "#8e5a48", rough=0.6)
    beard = m.mat("beard", "#5b3a26", rough=0.95)
    bronze = m.mat("bronze_ring", "#b5813a", rough=0.3, metal=0.9)
    singe = m.mat("singed", "#ffab40", emit="#ff6d00", energy=1.6)
    apron = m.mat("bison_apron", "#4a2e1b", rough=0.85)
    linen = m.mat("dark_linen", "#2f2a26", rough=0.9)
    iron = m.mat("beaten_iron", "#4b4f55", rough=0.45, metal=0.85)
    glove = m.mat("forge_glove", "#3a2617", rough=0.75)
    boots = m.mat("steel_toe", "#2a211b", rough=0.6)
    steel = m.mat("steel_cap", "#9aa3ab", rough=0.3, metal=0.9)
    rag = m.mat("grease_rag", "#6e6656", rough=1.0, double=True)
    iris = m.mat("iris", "#3b2a1e", rough=0.3)
    humanoid(m, skin, linen, linen, boots, hands=glove, forearm=glove, w=1.32)
    eyes(m, iris, m.mat("sclera", "#efe8df", rough=0.3))
    m.part("sphere", [0.2], (0, 1.24, -0.02), linen, scale=(1.45, 1.35, 0.95))
    m.part("box", [0.06, 0.018, 0.03], (0.045, 1.765, -0.112), beard, rot=(0, 0, -12), mirror=True)
    m.part("box", [0.02, 0.06, 0.01], (0.09, 1.69, -0.11), scar, rot=(0, 0, 20))
    # Barba trançada em três pontas
    m.part("sphere", [0.11], (0, 1.62, -0.08), beard, scale=(1.1, 0.9, 0.7))
    for x in (-0.045, 0.0, 0.045):
        m.chain([(x, 1.58, -0.12), (x * 1.1, 1.45, -0.15), (x * 1.2, 1.32, -0.16)], [0.03, 0.022, 0.014], beard)
        m.part("torus", [0.016, 0.026], (x * 1.1, 1.45, -0.15), bronze)
        m.part("sphere", [0.016], (x * 1.2, 1.31, -0.16), singe)
    # Avental e ombreira única de ferro (ombro esquerdo)
    m.part("box", [0.4, 0.72, 0.03], (0, 1.06, -0.2), apron, rot=(4, 0, 0))
    m.part("box", [0.03, 0.3, 0.02], (0.12, 1.5, -0.14), apron, rot=(0, 0, -20), mirror=True)
    for k in range(3):
        m.part("box", [0.22 - k * 0.03, 0.04, 0.26], (-0.36 - k * 0.03, 1.6 - k * 0.07, 0), iron,
               rot=(0, 0, 25 + k * 14), group="arm_l")
    # Braços nus com cicatrizes, luvas grossas até o cotovelo
    m.part("capsule", [0.08, 0.34], (0.37, 1.3, 0), skin, rot=(0, 0, 8), group="arm_r", mirror=True)
    m.part("box", [0.015, 0.08, 0.01], (0.42, 1.32, -0.06), scar, rot=(0, 0, 30), group="arm_r")
    m.part("box", [0.015, 0.06, 0.01], (-0.41, 1.25, -0.06), scar, rot=(0, 0, -15), group="arm_l")
    m.part("cylinder", [0.072, 0.066, 0.14], (0.41, 1.13, -0.03), glove, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("capsule", [0.08, 0.3], (0.11 * 1.32, 0.22, 0), boots, group="leg_r", mirror=True)
    m.part("box", [0.16, 0.06, 0.08], (0.11 * 1.32, 0.04, -0.15), steel, group="leg_r", mirror=True)
    # Cinto com tenaz, correntes e pano de graxa
    belt(m, apron, bronze, y=0.97, w=1.35)
    m.chain([(0.24, 0.95, -0.1), (0.27, 0.72, -0.12), (0.25, 0.6, -0.14)], [0.012, 0.01, 0.006], iron)
    m.chain([(0.24, 0.95, -0.08), (0.29, 0.72, -0.08), (0.3, 0.6, -0.1)], [0.012, 0.01, 0.006], iron)
    for i in range(6):
        m.part("torus", [0.012, 0.02], (-0.24 + i * 0.012, 0.92 - i * 0.04, -0.1 - i * 0.008), iron, rot=(0, 90 * (i % 2), 80))
    m.part("box", [0.1, 0.2, 0.01], (-0.2, 0.84, -0.17), rag, rot=(6, 20, -8))
    m.light("#ff9800", 0.3, 2.0, (0, 1.4, -0.8))
    return m


def lyra():
    m = N(103, "lyra", "Lyra", "Mestra Alquimista",
          "Jovem de traços finos, mestiça de Valeriano e Noctari. Cabelos prateado-lavanda num coque bagunçado "
          "espetado por hastes de vidro, óculos de latão com lentes verdes na testa, túnica ametista com bordas "
          "douradas e bandoleira com tubos de ensaio brilhantes.",
          "#d500f9", scale=0.93)
    skin = m.mat("skin", "#f0d7c4", rough=0.45)
    hair = m.mat("hair_lavender", "#d8cbe6", rough=0.45, metal=0.15)
    tunic = m.mat("amethyst_tunic", "#5b2c6f", rough=0.7, double=True)
    gold = m.mat("gold_trim", "#d4ac0d", rough=0.3, metal=0.9)
    vest = m.mat("light_leather", "#c9a57c", rough=0.75)
    glove = m.mat("dark_glove", "#2b1f1a", rough=0.6)
    brass = m.mat("brass", "#c9a24a", rough=0.25, metal=0.95)
    lens = m.mat("green_lens", "#b9f6ca", rough=0.05, emit="#2ecc71", energy=1.5, alpha=0.7)
    glass = m.mat("glass_rod", "#e0f7fa", rough=0.05, alpha=0.6)
    vial_g = m.mat("vial_green", "#b9f6ca", emit="#2ecc71", energy=3.5, alpha=0.9)
    vial_b = m.mat("vial_blue", "#b3e5fc", emit="#00d2ff", energy=3.5, alpha=0.9)
    splash = m.mat("glow_splash", "#e0f7fa", emit="#00d2ff", energy=2.0)
    eye = m.mat("eye_green", "#b9f6ca", emit="#2ecc71", energy=1.6)
    herb = m.mat("dried_herbs", "#7d8a4a", rough=1.0)
    book = m.mat("recipe_book", "#5d3a1a", rough=0.7)
    humanoid(m, skin, tunic, tunic, m.mat("boots", "#2b1f1a", rough=0.7), hands=glove, w=0.9)
    eyes(m, eye, m.mat("sclera", "#f5f3f0", rough=0.3))
    # Cabelo em coque bagunçado com hastes de vidro
    m.part("sphere", [0.134], (0, 1.745, 0.02), hair, scale=(1.04, 1.0, 1.04))
    m.part("sphere", [0.075], (0.0, 1.85, 0.1), hair, scale=(1.1, 0.9, 1.0))
    m.part("capsule", [0.025, 0.2], (0.11, 1.64, -0.04), hair, rot=(0, 0, -10), mirror=True)
    m.part("cylinder", [0.005, 0.005, 0.22], (0.03, 1.9, 0.1), glass, rot=(-20, 0, -35))
    m.part("cylinder", [0.005, 0.005, 0.22], (-0.03, 1.9, 0.12), glass, rot=(-35, 0, 30))
    m.part("cylinder", [0.0, 0.006, 0.12], (0.12, 1.735, 0.01), skin, rot=(0, 0, -70), mirror=True)
    # Óculos de latão na testa
    m.part("torus", [0.028, 0.038], (0.045, 1.8, -0.11), brass, rot=(70, 0, 0), mirror=True)
    m.part("cylinder", [0.03, 0.03, 0.006], (0.045, 1.8, -0.112), lens, rot=(70, 0, 0), mirror=True)
    m.part("torus", [0.128, 0.136], (0, 1.79, 0), m.mat("strap", "#3b2a1e", rough=0.8), rot=(-8, 0, 0))
    # Túnica assimétrica, colete manchado, bandoleira com 5 tubos
    m.part("cylinder", [0.2, 0.31, 0.55], (0, 0.75, 0), tunic)
    m.part("box", [0.2, 0.3, 0.02], (0.08, 0.45, -0.12), tunic, rot=(8, 0, 6))
    m.part("torus", [0.3, 0.32], (0, 0.48, 0), gold, rot=(0, 0, 8))
    m.part("sphere", [0.2], (0, 1.28, -0.02), vest, scale=(1.22, 1.15, 0.82))
    for p in ((0.08, 1.2, -0.17), (-0.05, 1.33, -0.17), (0.12, 1.38, -0.15), (-0.1, 1.15, -0.16)):
        m.part("sphere", [0.012], p, splash, scale=(1.4, 1, 0.4))
    m.part("box", [0.05, 0.56, 0.025], (0, 1.3, -0.165), m.mat("bandolier", "#3b2a1e", rough=0.8), rot=(0, 0, 33))
    for i in range(5):
        t = (i - 2) * 0.085
        m.part("cylinder", [0.012, 0.012, 0.06], (t * 0.84, 1.3 - t * 0.55, -0.185), vial_g if i % 2 else vial_b, rot=(0, 0, 33))
    belt(m, m.mat("belt", "#3b2a1e", rough=0.8), gold, w=0.92)
    m.part("sphere", [0.06], (0.2, 0.9, -0.04), herb, scale=(1, 1.2, 0.8))
    m.part("box", [0.12, 0.15, 0.04], (-0.21, 0.88, -0.02), book, rot=(0, 20, -5))
    m.light("#2ecc71", 0.35, 2.0, (0, 1.3, -0.7))
    return m


def varis():
    m = N(104, "varis", "Varis", "Contrabandista do Beco Sombrio",
          "Alto, magro e levemente curvado, como quem vive nas sombras. Capuz profundo de couro negro, máscara "
          "carmesim sobre a metade inferior do rosto e apenas olhos amarelos brilhando. Sobretudo de couro com "
          "barra suja de lama, ombreiras como penas de corvo e frascos de veneno por dentro.",
          "#f1c40f", scale=0.98)
    skin = m.mat("skin", "#c49c82", rough=0.5)
    coat = m.mat("black_coat", "#17202a", rough=0.7, double=True)
    mask = m.mat("crimson_mask", "#641e16", rough=0.8)
    mud = m.mat("sewer_mud", "#3a3226", rough=1.0)
    suede = m.mat("suede", "#2a2420", rough=0.95)
    eye = m.mat("eye_yellow", "#fff59d", emit="#f1c40f", energy=6.0)
    poison = m.mat("poison", "#e1bee7", emit="#8e24aa", energy=3.0, alpha=0.9)
    steel = m.mat("dagger_steel", "#b0bec5", rough=0.2, metal=0.9)
    gold = m.mat("eclipse_coin", "#d4ac0d", rough=0.3, metal=0.9)
    shadow = m.mat("hood_shadow", "#030304", rough=1.0)
    humanoid(m, skin, coat, coat, suede, hands=m.mat("glove", "#111317", rough=0.6), forearm=coat, w=0.88)
    m.rest_pose = {"torso": [-12, 0, 0]}
    m.part("sphere", [0.14], (0, 1.73, 0.02), coat, scale=(1.15, 1.2, 1.2))
    m.part("sphere", [0.115], (0, 1.71, -0.035), shadow, scale=(1.0, 1.05, 0.8))
    m.part("sphere", [0.016], (0.04, 1.73, -0.115), eye, scale=(1.4, 0.7, 1), mirror=True)
    m.part("sphere", [0.11], (0, 1.64, -0.06), mask, scale=(1.05, 0.65, 0.75))
    m.part("cylinder", [0.2, 0.42, 1.12], (0, 0.75, 0.02), coat)
    m.part("box", [0.02, 1.0, 0.02], (0.05, 0.8, -0.2), coat, rot=(-10, 0, -2), mirror=True)
    m.part("torus", [0.39, 0.43], (0, 0.22, 0.02), mud)
    for k in range(4):
        m.part("box", [0.16 - k * 0.02, 0.025, 0.24], (0.27 + k * 0.03, 1.58 - k * 0.055, 0), coat,
               rot=(0, 0, -20 - k * 12), group="arm_r", mirror=True)
    for i in range(4):
        m.part("cylinder", [0.012, 0.012, 0.05], (0.11 + i * 0.03, 1.2, -0.13), poison)
    m.part("torus", [0.02, 0.03], (-0.12, 1.15, -0.13), steel, rot=(90, 0, 0))
    m.part("cylinder", [0.002, 0.002, 0.06], (-0.12, 1.11, -0.13), steel)
    for i in range(2):
        m.part("sphere", [0.03], (-0.06 - i * 0.05, 1.05, -0.14), m.mat("coin_pouch", "#4a3a2a", rough=0.9))
    m.part("sphere", [0.012], (-0.06, 1.08, -0.165), gold)
    for sgn in (1, -1):
        m.part("box", [0.02, 0.22, 0.008], (0.2 * sgn, 0.85, -0.08), steel, rot=(0, 0, 18 * sgn))
        m.part("cylinder", [0.014, 0.014, 0.08], (0.18 * sgn, 0.99, -0.08), m.mat("hilt", "#1a1a1a", rough=0.5))
    m.light("#f1c40f", 0.2, 1.5, (0, 1.7, -0.5))
    return m


def randel():
    m = N(105, "randel", "Capitão Randel", "Comandante da Guarda",
          "Porte militar imponente, armadura completa de aço polido com frisos dourados e o Sol Partido gravado "
          "no peitoral, capa longa azul-real e rosto veterano de barba curta grisalha com cicatriz na bochecha.",
          "#d4ac0d", scale=1.0)
    skin = m.mat("skin", "#d2a586", rough=0.55)
    steel = m.mat("polished_steel", "#bdc3c7", rough=0.18, metal=0.85)
    gold = m.mat("gold_trim", "#d4ac0d", rough=0.25, metal=0.95)
    cape = m.mat("royal_blue", "#1b4f72", rough=0.75, double=True)
    beard = m.mat("grey_beard", "#9e9e9e", rough=0.9)
    scar = m.mat("scar", "#a16f5c", rough=0.6)
    iris = m.mat("iris", "#4a5a6a", rough=0.3)
    humanoid(m, skin, steel, steel, steel, hands=steel, forearm=steel, w=1.08)
    eyes(m, iris, m.mat("sclera", "#f0ece6", rough=0.3))
    m.part("sphere", [0.132], (0, 1.75, 0.025), beard, scale=(1.03, 0.9, 1.04))
    m.part("sphere", [0.1], (0, 1.65, -0.05), beard, scale=(1.05, 0.7, 0.75))
    m.part("box", [0.008, 0.07, 0.01], (0.075, 1.7, -0.105), scar, rot=(0, 0, 25))
    m.part("sphere", [0.2], (0, 1.33, -0.035), steel, scale=(1.3, 1.25, 0.72))
    m.part("cylinder", [0.06, 0.06, 0.01], (0, 1.36, -0.18), gold, rot=(90, 0, 0))
    m.part("box", [0.008, 0.12, 0.012], (0, 1.36, -0.188), steel, rot=(0, 0, 30))
    for i in range(8):
        a = math.radians(i * 45)
        m.part("box", [0.008, 0.03, 0.01], (math.sin(a) * 0.085, 1.36 + math.cos(a) * 0.085, -0.182), gold, rot=(0, 0, -i * 45))
    for k in range(3):
        m.part("sphere", [0.12 - k * 0.012], (0.3 + k * 0.025, 1.54 - k * 0.05, 0), steel,
               scale=(1.25, 0.55, 1.15), rot=(0, 0, -22 - 10 * k), group="arm_r", mirror=True)
        m.part("torus", [0.11 - k * 0.012, 0.118 - k * 0.012], (0.3 + k * 0.025, 1.54 - k * 0.05, 0), gold,
               scale=(1.25, 0.55, 1.15), rot=(0, 0, -22 - 10 * k), group="arm_r", mirror=True)
    m.part("box", [0.03, 0.36, 0.02], (0.07, 1.32, -0.17), gold, mirror=True)
    belt(m, gold, gold, w=1.06)
    m.part("box", [0.32, 0.3, 0.04], (0, 0.82, -0.12), steel, rot=(6, 0, 0))
    m.group("cape", (0, 1.52, 0.17), anim={"type": "sway", "axis": [1, 0, 0], "amp": 3.0, "speed": 1.1})
    m.part("box", [0.56, 1.3, 0.03], (0, 0.88, 0.22), cape, rot=(-6, 0, 0), group="cape")
    m.part("box", [0.58, 0.05, 0.05], (0, 1.52, 0.17), gold, group="cape")
    m.light("#ffd54f", 0.2, 2.0, (0, 1.5, -0.8))
    return m


def valen():
    m = N(106, "valen", "Guarda Valen", "Patrulheiro da Vila",
          "Armadura de infantaria leve para a ronda: cota de malha sob um peitoral simples de aço, gibão azul-"
          "marinho, elmo fechado estilo bascinet e uma lanterna de ferro de luz amarela pendurada no cinto.",
          "#64b5f6", scale=1.0)
    skin = m.mat("skin", "#d2a586", rough=0.55)
    mail = m.mat("chainmail", "#8c949b", rough=0.55, metal=0.8)
    steel = m.mat("steel", "#aab2b9", rough=0.25, metal=0.9)
    navy = m.mat("navy_gambeson", "#1b2a4a", rough=0.85)
    iron = m.mat("lantern_iron", "#2b2d31", rough=0.5, metal=0.8)
    flame = m.mat("lantern_light", "#fff59d", emit="#ffc400", energy=5.0,
                  anim={"type": "glow", "speed": 5.0, "min": 0.75, "max": 1.15})
    slit = m.mat("visor_slit", "#050506", rough=1.0)
    humanoid(m, skin, navy, navy, steel, hands=mail, forearm=mail, w=1.02)
    m.part("sphere", [0.145], (0, 1.73, 0.0), steel, scale=(1.0, 1.15, 1.08))
    m.part("cylinder", [0.0, 0.07, 0.2], (0, 1.68, -0.15), steel, rot=(-90, 0, 0), scale=(1, 1, 0.8))
    m.part("box", [0.14, 0.012, 0.02], (0, 1.74, -0.155), slit)
    for i in range(5):
        m.part("sphere", [0.006], (-0.04 + i * 0.02, 1.66, -0.2 + abs(i - 2) * 0.012), slit)
    m.part("cylinder", [0.13, 0.16, 0.1], (0, 1.57, 0.02), mail)
    m.part("sphere", [0.2], (0, 1.3, -0.03), steel, scale=(1.24, 1.15, 0.7))
    m.part("cylinder", [0.22, 0.29, 0.3], (0, 0.86, 0), navy)
    m.part("sphere", [0.09], (0.28, 1.52, 0), steel, scale=(1.2, 0.6, 1.1), rot=(0, 0, -22), group="arm_r", mirror=True)
    belt(m, m.mat("belt", "#3b2a1e", rough=0.8), steel, w=1.02)
    lp = (0.23, 0.82, -0.07)
    m.group("lantern", v_add(lp, (0, 0.14, 0)), anim={"type": "sway", "axis": [1, 0, 0], "amp": 6.0, "speed": 2.0})
    m.part("cylinder", [0.002, 0.002, 0.08], v_add(lp, (0, 0.1, 0)), iron, group="lantern")
    m.part("cylinder", [0.04, 0.045, 0.012], v_add(lp, (0, 0.06, 0)), iron, group="lantern")
    m.part("cylinder", [0.035, 0.035, 0.08], lp, flame, group="lantern")
    for i in range(4):
        a = math.radians(i * 90 + 45)
        m.part("box", [0.008, 0.09, 0.008], v_add(lp, (math.cos(a) * 0.038, 0, math.sin(a) * 0.038)), iron, group="lantern")
    m.part("cylinder", [0.045, 0.04, 0.012], v_add(lp, (0, -0.05, 0)), iron, group="lantern")
    m.light("#ffc400", 0.8, 3.5, lp)
    return m


def ghost_alchemist():
    m = N(107, "ghost_alchemist", "Alquimista Fantasma", "Evento Secreto das 03h",
          "Idoso curvado sem as pernas inferiores: a túnica rasgada se desfaz em fumaça ectoplásmica acima do chão. "
          "Todo translúcido em verde fantasmagórico, com correntes enferrujadas quebradas nos pulsos e um incensário "
          "rachado nas mãos.",
          "#48c9b0", scale=0.98)
    ecto = m.mat("ectoplasm", "#a3e4d7", emit="#48c9b0", energy=0.9, alpha=0.5, double=True,
                 anim={"type": "flicker", "speed": 2.2, "min": 0.65, "max": 1.0})
    ecto_d = m.mat("ecto_robe", "#76d7c4", emit="#2a9d8f", energy=0.6, alpha=0.42, double=True,
                   anim={"type": "flicker", "speed": 1.7, "min": 0.6, "max": 1.0})
    eye = m.mat("eye", "#ffffff", emit="#48c9b0", energy=7.0)
    rust = m.mat("rusted_chain", "#7a4a2a", rough=0.8, metal=0.6, emit="#48c9b0", energy=0.2)
    censer = m.mat("cracked_censer", "#6f6a5a", rough=0.5, metal=0.7)
    smoke = m.mat("censer_smoke", "#d1f2eb", emit="#48c9b0", energy=1.5, alpha=0.35)
    m.rest_pose = {"torso": [-20, 0, 0], "root_y": 0.25}
    m.body_w = 0.9
    m.part("sphere", [0.2], (0, 1.27, 0), ecto_d, scale=(1.1, 1.45, 0.78))
    m.part("sphere", [0.125], (0, 1.68, -0.03), ecto, scale=(1, 1.1, 1.02))
    m.part("sphere", [0.15], (0, 1.72, 0.03), ecto_d, scale=(1.1, 1.15, 1.15))
    m.part("sphere", [0.016], (0.04, 1.69, -0.14), eye, mirror=True)
    m.part("cylinder", [0.04, 0.0, 0.18], (0, 1.52, -0.12), ecto, rot=(-20, 0, 0))
    m.group("arm_r", (0.24, 1.45, 0), mirror=True)
    m.part("capsule", [0.06, 0.34], (0.27, 1.28, -0.02), ecto_d, rot=(20, 0, 8), group="arm_r", mirror=True)
    m.part("capsule", [0.05, 0.3], (0.22, 1.08, -0.16), ecto, rot=(70, 0, -30), group="arm_r", mirror=True)
    m.part("sphere", [0.05], (0.12, 1.02, -0.28), ecto, group="arm_r", mirror=True)
    m.part("torus", [0.05, 0.065], (0.2, 1.06, -0.18), rust, rot=(70, 0, -30), group="arm_r", mirror=True)
    for i in range(3):
        m.part("torus", [0.016, 0.026], (0.24 + i * 0.012, 1.02 - i * 0.04, -0.14), rust, rot=(0, 90 * (i % 2), 70), group="arm_r", mirror=True)
    m.anchor("hand_r", "arm_r", (0.12, 1.0, -0.28))
    m.anchor("hand_l", "arm_l", (-0.12, 1.0, -0.28))
    # Túnica que se desfaz em fumaça
    for i in range(5):
        y = 0.95 - i * 0.16
        r = 0.32 - i * 0.05
        m.part("cylinder", [r + 0.04, r, 0.16], (0.02 * math.sin(i), y, 0.02), ecto_d,
               anim={"type": "sway", "axis": [0, 0, 1], "amp": 4 + i * 3, "speed": 1.4, "phase": i})
    for i in range(6):
        a = i * 2 * math.pi / 6
        m.part("sphere", [0.06], (math.cos(a) * 0.12, 0.25, math.sin(a) * 0.12), smoke,
               anim={"type": "bob", "amp": 0.06, "speed": 1.2, "phase": i})
    cp = (0, 0.88, -0.32)
    m.group("censer", v_add(cp, (0, 0.14, 0)), anim={"type": "sway", "axis": [1, 0, 0], "amp": 10.0, "speed": 1.6})
    m.part("cylinder", [0.002, 0.002, 0.12], v_add(cp, (0, 0.09, 0)), rust, group="censer")
    m.part("sphere", [0.05], cp, censer, scale=(1, 0.8, 1), group="censer")
    m.part("box", [0.005, 0.06, 0.01], v_add(cp, (0.03, 0.0, -0.04)), m.mat("crack", "#0a0a0a", rough=1.0), rot=(0, 0, 30), group="censer")
    for i in range(4):
        m.part("sphere", [0.025 + 0.01 * i], v_add(cp, (0.01 * i, 0.06 + i * 0.07, 0)), smoke, group="censer",
               anim={"type": "bob", "amp": 0.03, "speed": 2.0, "phase": i})
    m.light("#48c9b0", 0.7, 3.0, (0, 1.2, -0.4))
    return m


NPCS = [garrick, lyra, varis, randel, valen, ghost_alchemist]
