"""NPCs da Vila do Refúgio e do mundo (IDs do servidor)."""

import math

from modelkit import Model, humanoid, v_add
from races_base import eyes, belt, hair_long, hair_short, pointed_ears


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


def nyx():
    m = N(111, "nyx", "Nyx Sombraveloz", "Mestra das Lâminas Silentes",
          "Assassina Umbryss esguia de pele cinza-lavanda, olhos violeta brilhantes e cabelo preto curto. "
          "Veste couro negro justo com faixas roxas, capuz baixo, máscara cobrindo o nariz e duas adagas curvas nas costas.",
          "#7e57c2", scale=0.97)
    skin = m.mat("skin", "#b9a7c9", rough=0.5)
    leather = m.mat("night_leather", "#17131d", rough=0.6)
    sash = m.mat("violet_sash", "#5e35b1", rough=0.8, double=True)
    steel = m.mat("dagger_steel", "#c5cae9", rough=0.2, metal=0.95)
    hair = m.mat("hair", "#0d0b12", rough=0.8)
    eye = m.mat("eye", "#e1bee7", emit="#ab47bc", energy=4.0)
    humanoid(m, skin, leather, leather, leather, hands=leather, forearm=leather, w=0.92)
    eyes(m, eye)
    hair_short(m, hair)
    m.part("box", [0.2, 0.06, 0.04], (0, 1.68, -0.12), leather)  # máscara
    m.part("sphere", [0.17], (0, 1.76, 0.03), leather, scale=(1.05, 1.0, 1.1))  # capuz
    m.part("box", [0.42, 0.06, 0.25], (0, 1.02, 0), sash, rot=(0, 0, 8))
    m.part("box", [0.08, 0.4, 0.02], (0.08, 0.8, -0.13), sash, rot=(0, 0, -6))
    for side in (-1, 1):
        m.part("box", [0.03, 0.42, 0.012], (0.1 * side, 1.35, 0.2), steel, rot=(0, 0, 35 * side))
        m.part("box", [0.05, 0.1, 0.03], (0.1 * side + 0.11 * side, 1.55, 0.2), leather, rot=(0, 0, 35 * side))
    return m


def tao():
    m = N(112, "tao", "Mestre Tao Ferroventre", "Grão-Mestre do Punho Celeste",
          "Monge Kharad idoso e atarracado, careca, de longas sobrancelhas e barba branca. Túnica laranja de monge "
          "amarrada na cintura, peito musculoso à mostra, faixas nas mãos e um colar de contas de madeira.",
          "#ffb74d", scale=0.92)
    skin = m.mat("skin", "#c4906a", rough=0.6)
    robe = m.mat("monk_robe", "#ef6c00", rough=0.85, double=True)
    wrap = m.mat("hand_wrap", "#efe6d2", rough=0.9)
    beard = m.mat("white_beard", "#f5f5f5", rough=0.95)
    beads = m.mat("wood_beads", "#6d4c41", rough=0.5)
    sandal = m.mat("sandal", "#4e342e", rough=0.8)
    humanoid(m, skin, skin, robe, sandal, hands=wrap, forearm=wrap, w=1.2)
    eyes(m, m.mat("iris", "#2e1f14", rough=0.3))
    m.part("sphere", [0.2], (0, 1.27, -0.02), skin, scale=(1.35, 1.25, 0.9))
    m.part("box", [0.5, 0.55, 0.05], (0.12, 1.15, 0.0), robe, rot=(0, 0, -25))
    m.part("torus", [0.19 * 1.2, 0.22 * 1.2], (0, 0.98, 0), robe, scale=(1.05, 1, 0.8))
    m.part("capsule", [0.07, 0.26], (0, 1.56, -0.1), beard, rot=(15, 0, 0))
    m.part("box", [0.07, 0.015, 0.03], (0.05, 1.79, -0.12), beard, rot=(0, 0, -15), mirror=True)
    for i in range(10):
        a = math.radians(i * 36)
        m.part("sphere", [0.022], (math.sin(a) * 0.15, 1.5 - (1 - math.cos(a)) * 0.04, -0.12 + math.cos(a) * 0.05 - 0.02), beads)
    return m


def iolanthe():
    m = N(113, "iolanthe", "Iolanthe Mármore-Lunar", "Escultora de Almas",
          "Jovem Elarin de orelhas pontudas e longos cabelos prateados presos com um cinzel. Avental de couro "
          "cinza coberto de pó de mármore sobre vestido azul-lunar, luvas de trabalho e uma pequena estatueta luminosa no cinto.",
          "#b0bec5", scale=0.96)
    skin = m.mat("skin", "#f1dccb", rough=0.5)
    dress = m.mat("moon_dress", "#5c6bc0", rough=0.8, double=True)
    apron = m.mat("dusty_apron", "#8d8d8d", rough=0.95)
    hair = m.mat("silver_hair", "#e0e6ee", rough=0.6)
    marble = m.mat("marble", "#eceff1", rough=0.35)
    glow = m.mat("lunar_glow", "#e3f2fd", emit="#90caf9", energy=3.0)
    humanoid(m, skin, dress, dress, m.mat("boots", "#3e3e46", rough=0.7), hands=apron, w=0.94)
    eyes(m, m.mat("iris", "#5c6bc0", rough=0.3))
    hair_long(m, hair, length=0.6)
    pointed_ears(m, skin)
    m.part("cylinder", [0.4 * 0.6, 0.3, 0.55], (0, 0.75, 0), dress)
    m.part("box", [0.34, 0.62, 0.03], (0, 1.05, -0.17), apron)
    m.part("box", [0.012, 0.18, 0.012], (0.06, 1.84, 0.1), m.mat("chisel", "#9e9e9e", metal=0.9, rough=0.3), rot=(0, 0, 30))
    m.part("sphere", [0.05], (0.2, 0.92, -0.08), marble, scale=(0.8, 1.3, 0.8))
    m.part("sphere", [0.02], (0.2, 0.99, -0.12), glow)
    m.light("#90caf9", 0.5, 2.0, (0.2, 0.95, -0.15))
    return m


def fiorella():
    m = N(114, "fiorella", "Madame Fiorella Agulhadouro", "Tecelã Carmesim",
          "Cambion elegante de pele rosada, pequenos chifres curvos e cabelo vermelho em coque alto atravessado por "
          "agulhas douradas. Vestido carmesim com espartilho bordado, fita métrica no pescoço e carretéis de fio de aço no cinto.",
          "#e53950", scale=0.98)
    skin = m.mat("skin", "#e8b4a8", rough=0.5)
    gown = m.mat("crimson_gown", "#b71c1c", rough=0.6, double=True)
    corset = m.mat("corset", "#3b0a12", rough=0.5)
    gold = m.mat("gold_needle", "#ffd54f", rough=0.2, metal=1.0)
    hair = m.mat("red_hair", "#c62828", rough=0.6)
    horn = m.mat("horn", "#2b1b1b", rough=0.4)
    tape = m.mat("measuring_tape", "#fff59d", rough=0.8, double=True)
    humanoid(m, skin, gown, gown, m.mat("heels", "#1a0a0a", rough=0.4), w=0.95)
    eyes(m, m.mat("iris", "#ffb300", emit="#ff6f00", energy=1.5))
    m.part("sphere", [0.135], (0, 1.75, 0.02), hair, scale=(1.04, 1.0, 1.05))
    m.part("sphere", [0.09], (0, 1.92, 0.05), hair)
    for x in (-0.05, 0.05):
        m.part("cylinder", [0.004, 0.004, 0.22], (x, 1.94, 0.05), gold, rot=(0, 0, 70 if x > 0 else -70))
    m.part("cylinder", [0.0, 0.025, 0.1], (0.08, 1.86, -0.02), horn, rot=(-20, 0, -35), mirror=True)
    m.part("cylinder", [0.42, 0.24, 0.62], (0, 0.62, 0), gown)
    m.part("sphere", [0.19], (0, 1.2, -0.01), corset, scale=(1.05, 1.2, 0.8))
    m.part("box", [0.03, 0.4, 0.01], (0.06, 1.38, -0.13), tape, rot=(0, 0, 4), mirror=True)
    for x in (-0.16, 0.16):
        m.part("cylinder", [0.04, 0.04, 0.05], (x, 0.98, -0.12), m.mat("steel_thread", "#cfd8dc", metal=0.9, rough=0.25), rot=(90, 0, 0))
    return m


def bartolomeu():
    m = N(115, "bartolomeu", "Chef Bartolomeu Brasa-Alta", "Mestre do Banquete",
          "Orkhan enorme de pele verde-oliva, presas inferiores e bigode ruivo trançado. Dólmã branco de chef manchado, "
          "chapéu alto, avental de couro, um cutelo gigante no ombro e um wok de ferro preto pendurado nas costas.",
          "#ff7043", scale=1.05)
    skin = m.mat("skin", "#7f9a5a", rough=0.6)
    white = m.mat("chef_white", "#f5f5f0", rough=0.8)
    apron = m.mat("leather_apron", "#5d4037", rough=0.8)
    mustache = m.mat("mustache", "#d84315", rough=0.9)
    tusk = m.mat("tusk", "#fff8e1", rough=0.4)
    steel = m.mat("cleaver", "#b0bec5", rough=0.25, metal=0.95)
    wok = m.mat("black_wok", "#1c1c1c", rough=0.5, metal=0.8)
    humanoid(m, skin, white, m.mat("checked_pants", "#37474f", rough=0.9), m.mat("boots", "#2b1f1a", rough=0.7),
             hands=skin, forearm=white, w=1.4)
    eyes(m, m.mat("iris", "#3e2723", rough=0.3))
    m.part("sphere", [0.2], (0, 1.24, -0.02), white, scale=(1.55, 1.4, 1.05))
    m.part("cylinder", [0.13, 0.15, 0.24], (0, 1.97, 0.02), white)
    m.part("sphere", [0.16], (0, 2.1, 0.02), white, scale=(1.1, 0.6, 1.1))
    m.part("box", [0.44, 0.7, 0.03], (0, 1.02, -0.24), apron, rot=(5, 0, 0))
    m.part("capsule", [0.022, 0.12], (0.06, 1.66, -0.13), mustache, rot=(0, 0, 70), mirror=True)
    m.part("cylinder", [0.0, 0.018, 0.06], (0.04, 1.64, -0.13), tusk, rot=(0, 0, 10), mirror=True)
    m.part("box", [0.22, 0.14, 0.012], (0.32, 1.7, 0.02), steel, rot=(0, 0, -30), group="arm_r")
    m.part("cylinder", [0.03, 0.03, 0.14], (0.24, 1.58, 0.02), apron, rot=(0, 0, -30), group="arm_r")
    m.part("sphere", [0.24], (0, 1.3, 0.26), wok, scale=(1.0, 1.0, 0.3))
    return m


def thorne():
    m = N(116, "thorne", "Thorne, o Eremita das Feras", "Mestre Secreto do Senhor das Feras",
          "Ulvar grisalho e magro, orelhas de lobo e barba desgrenhada. Manto de peles costuradas, colar de presas, "
          "cajado de madeira retorcida e uma loba cinzenta de olhos âmbar sempre ao seu lado.",
          "#8d6e63", scale=1.0)
    skin = m.mat("skin", "#a1887f", rough=0.7)
    fur = m.mat("fur_mantle", "#6d5a4a", rough=1.0)
    grey = m.mat("wolf_grey", "#8e8e8e", rough=1.0)
    hair = m.mat("grey_hair", "#bdbdbd", rough=0.9)
    fang = m.mat("fang", "#efe6d6", rough=0.4)
    wood = m.mat("twisted_wood", "#4e342e", rough=0.9)
    amber = m.mat("amber_eye", "#ffe082", emit="#ffab00", energy=4.0)
    humanoid(m, skin, m.mat("hide_tunic", "#5d4330", rough=0.85), m.mat("hide_pants", "#3e2c20", rough=0.9),
             m.mat("wrapped_feet", "#2f241c", rough=0.9), w=0.96)
    eyes(m, amber)
    m.part("sphere", [0.14], (0, 1.76, 0.03), hair, scale=(1.08, 1.0, 1.1))
    m.part("capsule", [0.08, 0.2], (0, 1.58, -0.09), hair, rot=(15, 0, 0))
    m.part("cylinder", [0.0, 0.04, 0.11], (0.1, 1.9, 0.02), hair, rot=(0, 0, -20), mirror=True)
    m.part("sphere", [0.24], (0, 1.45, 0.05), fur, scale=(1.5, 0.7, 1.2))
    m.part("box", [0.5, 0.8, 0.04], (0, 1.0, 0.18), fur, rot=(-5, 0, 0))
    for i in range(5):
        m.part("cylinder", [0.0, 0.012, 0.05], (-0.08 + i * 0.04, 1.42, -0.16), fang, rot=(180, 0, 0))
    m.part("cylinder", [0.02, 0.025, 1.7], (0.35, 0.85, -0.1), wood, rot=(0, 0, 4), group="arm_r")
    m.part("sphere", [0.05], (0.36, 1.72, -0.1), wood)
    # Cinza, a loba
    m.group("wolf", (-0.6, 0.0, 0.1), anim={"type": "bob", "amp": 0.02, "speed": 2.5})
    m.part("capsule", [0.13, 0.55], (-0.6, 0.42, 0.1), grey, rot=(90, 0, 0), group="wolf")
    m.part("sphere", [0.11], (-0.6, 0.56, -0.26), grey, group="wolf")
    m.part("box", [0.08, 0.07, 0.12], (-0.6, 0.53, -0.38), grey, group="wolf")
    m.part("sphere", [0.016], (-0.645, 0.59, -0.35), amber, group="wolf")
    m.part("sphere", [0.016], (-0.555, 0.59, -0.35), amber, group="wolf")
    m.part("cylinder", [0.0, 0.04, 0.09], (-0.65, 0.68, -0.24), grey, group="wolf")
    m.part("cylinder", [0.0, 0.04, 0.09], (-0.55, 0.68, -0.24), grey, group="wolf")
    for x in (-0.68, -0.52):
        for z in (-0.12, 0.32):
            m.part("capsule", [0.04, 0.32], (x, 0.16, z), grey, group="wolf")
    m.part("cylinder", [0.05, 0.02, 0.3], (-0.6, 0.5, 0.52), grey, rot=(-50, 0, 0), group="wolf")
    return m



# ---------------------------------------------------------------------------
# Mundo Vivo: aprendizes, Coveiro e caçadores da Igreja
# ---------------------------------------------------------------------------

def bran():
    m = N(117, "bran", "Bran", "Aprendiz da Forja",
          "Rapaz de 15 anos, filho do Garrick: ombros já largos, sardas, cabelo ruivo curto e despenteado. "
          "Avental de couro grande demais para ele, luvas remendadas e um martelinho de aprendiz no cinto.",
          "#ffb74d", scale=0.86)
    skin = m.mat("skin_freckled", "#e2b08c", rough=0.6)
    hair = m.mat("ginger_hair", "#c1501f", rough=0.9)
    shirt = m.mat("rough_shirt", "#8d7b68", rough=0.9)
    apron = m.mat("big_apron", "#5a3a22", rough=0.85)
    iron = m.mat("small_hammer", "#5f646b", rough=0.4, metal=0.85)
    freckle = m.mat("freckle", "#b9734f", rough=0.6)
    humanoid(m, skin, shirt, m.mat("pants", "#4a3b2e", rough=0.9), m.mat("boots", "#2e231b", rough=0.8),
             hands=m.mat("patched_glove", "#6d4c35", rough=0.8), w=1.05)
    eyes(m, m.mat("iris", "#3b6d3a", rough=0.3), m.mat("sclera", "#f3eee8", rough=0.3))
    hair_short(m, hair)
    m.part("sphere", [0.05], (0.06, 1.85, -0.06), hair, scale=(1.2, 0.5, 1.0), rot=(0, 0, 25), mirror=True)
    for x in (-0.05, -0.03, 0.03, 0.05):
        m.part("sphere", [0.006], (x, 1.69, -0.125), freckle)
    m.part("box", [0.38, 0.78, 0.03], (0, 1.0, -0.19), apron, rot=(3, 0, 0))
    belt(m, apron, iron, y=0.98, w=1.05)
    m.part("cylinder", [0.012, 0.012, 0.26], (0.2, 0.86, -0.12), m.mat("handle", "#6d4c35", rough=0.8))
    m.part("box", [0.08, 0.05, 0.05], (0.2, 0.99, -0.12), iron)
    return m


def pip():
    m = N(118, "pip", "Pip", "Aprendiz de Alquimia",
          "Menina franzina de óculos redondos e tranças castanhas, jaleco verde-água manchado de reagentes, "
          "bolsa de frascos a tiracolo e um tubo de ensaio brilhante sempre na mão.",
          "#4db6ac", scale=0.84)
    skin = m.mat("skin", "#f0c8a8", rough=0.55)
    hair = m.mat("braids", "#6d4c41", rough=0.9)
    coat = m.mat("lab_coat", "#9fd8cf", rough=0.85)
    stain = m.mat("reagent_stain", "#7b1fa2", rough=0.6)
    glass = m.mat("lens", "#e0f7fa", rough=0.05, metal=0.2)
    rim = m.mat("brass_rim", "#b8863b", rough=0.3, metal=0.9)
    glow = m.mat("vial_glow", "#76ff03", emit="#64dd17", energy=3.0)
    humanoid(m, skin, coat, m.mat("skirt", "#37474f", rough=0.9), m.mat("shoes", "#3e2723", rough=0.8), w=0.92)
    eyes(m, m.mat("iris", "#5d4037", rough=0.3), m.mat("sclera", "#f5f2ee", rough=0.3))
    hair_short(m, hair)
    for x in (-0.12, 0.12):
        m.chain([(x, 1.68, 0.02), (x * 1.05, 1.5, 0.03), (x * 1.1, 1.36, 0.02)], [0.035, 0.03, 0.022], hair)
    m.part("torus", [0.026, 0.032], (0.045, 1.72, -0.125), rim, rot=(90, 0, 0), mirror=True)
    m.part("cylinder", [0.026, 0.026, 0.004], (0.045, 1.72, -0.127), glass, rot=(90, 0, 0), mirror=True)
    m.part("box", [0.08, 0.06, 0.01], (-0.08, 1.15, -0.17), stain, rot=(0, 0, 20))
    m.part("box", [0.03, 0.62, 0.02], (0, 1.2, -0.05), m.mat("strap", "#5d4037", rough=0.8), rot=(0, 0, 38))
    m.part("box", [0.16, 0.12, 0.08], (0.2, 0.95, 0.0), m.mat("vial_bag", "#6d4c41", rough=0.85))
    m.part("cylinder", [0.018, 0.018, 0.12], (0.3, 1.0, -0.2), glow, group="arm_r")
    return m


def tilda():
    m = N(119, "tilda", "Tilda", "Ajudante de Cozinha",
          "Jovem Orkhan de pele verde-clara e presinhas, coque alto preso com uma colher de pau, avental branco "
          "encardido sobre vestido de linho e uma panela de cobre debaixo do braço.",
          "#aed581", scale=0.92)
    skin = m.mat("skin", "#9ccc65", rough=0.6)
    hair = m.mat("dark_bun", "#3e2723", rough=0.9)
    linen = m.mat("linen_dress", "#a1887f", rough=0.9)
    white = m.mat("kitchen_white", "#eeeeea", rough=0.85)
    copper = m.mat("copper_pot", "#c56b3a", rough=0.35, metal=0.9)
    tusk = m.mat("tusk", "#fff8e1", rough=0.4)
    humanoid(m, skin, linen, linen, m.mat("clogs", "#5d4037", rough=0.8), w=1.08)
    eyes(m, m.mat("iris", "#4e342e", rough=0.3))
    hair_short(m, hair)
    m.part("sphere", [0.08], (0, 1.92, 0.04), hair)
    m.part("cylinder", [0.008, 0.008, 0.24], (0, 1.94, 0.04), m.mat("spoon", "#a1887f", rough=0.8), rot=(0, 0, 70))
    m.part("cylinder", [0.0, 0.012, 0.035], (0.035, 1.645, -0.125), tusk, mirror=True)
    m.part("box", [0.36, 0.6, 0.025], (0, 1.0, -0.19), white, rot=(4, 0, 0))
    m.part("cylinder", [0.12, 0.1, 0.12], (-0.33, 1.05, -0.05), copper, group="arm_l")
    return m


def mortimer():
    m = N(120, "mortimer", "Mortimer, o Coveiro", "Guardião do Cemitério",
          "Homem alto e encurvado de rosto encovado, barba grisalha rala e olheiras fundas. Sobretudo preto puído, "
          "chapéu de abas largas, lanterna de vela pendurada no cinto, rosário da Igreja no pescoço e uma pá enorme.",
          "#78909c", scale=1.06)
    skin = m.mat("pale_skin", "#cdbfb0", rough=0.6)
    coat = m.mat("worn_black_coat", "#1f1f24", rough=0.9)
    hat = m.mat("wide_hat", "#151518", rough=0.85)
    beard = m.mat("grey_stubble", "#9e9e9e", rough=0.95)
    iron = m.mat("shovel_iron", "#6b6f73", rough=0.5, metal=0.8)
    wood = m.mat("shovel_wood", "#5d4037", rough=0.9)
    flame = m.mat("candle_flame", "#ffcc80", emit="#ffa726", energy=3.5)
    silver = m.mat("rosary_silver", "#cfd8dc", rough=0.3, metal=0.9)
    humanoid(m, skin, coat, m.mat("trousers", "#2b2b30", rough=0.9), m.mat("mud_boots", "#3a2e24", rough=0.9), w=0.9)
    eyes(m, m.mat("iris", "#455a64", rough=0.3), m.mat("sclera", "#e8e2da", rough=0.3))
    m.part("box", [0.03, 0.012, 0.01], (0.045, 1.695, -0.118), m.mat("eye_bags", "#8d7f74", rough=0.6), mirror=True)
    m.part("sphere", [0.09], (0, 1.62, -0.06), beard, scale=(1.1, 0.8, 0.8))
    m.part("cylinder", [0.3, 0.3, 0.02], (0, 1.86, 0.0), hat)
    m.part("cylinder", [0.13, 0.14, 0.16], (0, 1.94, 0.0), hat)
    m.part("box", [0.46, 0.9, 0.04], (0, 0.88, 0.14), coat, rot=(-4, 0, 0))
    m.part("torus", [0.1, 0.112], (0, 1.45, -0.04), silver, rot=(70, 0, 0))
    m.part("box", [0.02, 0.05, 0.01], (0, 1.34, -0.14), silver)
    belt(m, m.mat("belt", "#3e2723", rough=0.8), silver, w=0.92)
    m.part("box", [0.07, 0.11, 0.07], (-0.2, 0.86, -0.08), m.mat("lantern_cage", "#424242", rough=0.4, metal=0.7))
    m.part("sphere", [0.02], (-0.2, 0.87, -0.08), flame)
    m.part("cylinder", [0.02, 0.02, 1.25], (0.36, 0.85, -0.12), wood, rot=(8, 0, 0), group="arm_r")
    m.part("box", [0.2, 0.26, 0.02], (0.36, 0.2, -0.2), iron, rot=(8, 0, 0), group="arm_r")
    return m


def paladin():
    m = N(121, "paladin", "Paladino da Luz", "Caçador da Igreja",
          "Cavaleiro de armadura de placas branca e dourada, tabardo com o sol da Igreja, elmo fechado com "
          "visor em cruz, capa marfim, escudo-torre com o sol radiante e maça de guerra benta.",
          "#fff59d", scale=1.08)
    plate = m.mat("white_plate", "#e8e6df", rough=0.3, metal=0.85)
    gold = m.mat("holy_gold", "#e0b44c", rough=0.25, metal=0.95)
    tabard = m.mat("sun_tabard", "#f5f0e1", rough=0.8, double=True)
    cape = m.mat("ivory_cape", "#efe7d2", rough=0.85, double=True)
    glow = m.mat("holy_glow", "#fff9c4", emit="#ffeb3b", energy=3.0)
    humanoid(m, plate, plate, plate, plate, hands=plate, forearm=plate, w=1.18)
    m.part("sphere", [0.15], (0, 1.75, 0.0), plate, scale=(1.0, 1.08, 1.05))
    m.part("box", [0.14, 0.018, 0.01], (0, 1.74, -0.148), m.mat("visor_slit", "#111111", rough=0.9))
    m.part("box", [0.018, 0.1, 0.01], (0, 1.73, -0.149), m.mat("visor_slit2", "#111111", rough=0.9))
    m.part("cylinder", [0.0, 0.03, 0.12], (0, 1.94, 0.0), gold)
    m.part("sphere", [0.2], (0, 1.28, -0.01), plate, scale=(1.4, 1.25, 0.95))
    m.part("box", [0.3, 0.75, 0.02], (0, 0.98, -0.2), tabard)
    m.part("sphere", [0.06], (0, 1.18, -0.215), gold, scale=(1, 1, 0.2))
    m.part("box", [0.55, 1.1, 0.03], (0, 0.95, 0.22), cape, rot=(-6, 0, 0))
    m.part("sphere", [0.12], (0.3, 1.55, 0), plate, scale=(1.2, 0.8, 1.1), mirror=True)
    m.part("box", [0.06, 0.9, 0.5], (-0.45, 1.0, -0.12), plate, group="arm_l")
    m.part("sphere", [0.1], (-0.48, 1.05, -0.12), gold, scale=(0.3, 1, 1), group="arm_l")
    m.part("cylinder", [0.02, 0.02, 0.6], (0.36, 0.95, -0.25), m.mat("mace_grip", "#5d4037", rough=0.8), rot=(70, 0, 0), group="arm_r")
    m.part("sphere", [0.08], (0.36, 1.05, -0.53), gold, group="arm_r")
    m.part("sphere", [0.03], (0.36, 1.05, -0.62), glow, group="arm_r")
    return m


def cleric():
    m = N(122, "cleric", "Clériga da Luz", "Caçadora da Igreja",
          "Sacerdotisa de túnica branca com bordados dourados, mitra baixa, estola azul-celeste com sóis, "
          "cajado coroado por um sol de cristal que brilha ao curar os aliados, e um livro de preces no quadril.",
          "#81d4fa", scale=1.0)
    skin = m.mat("skin", "#e9c6a5", rough=0.55)
    robe = m.mat("white_robe", "#f7f5ef", rough=0.85)
    gold = m.mat("gold_trim", "#d9a93f", rough=0.3, metal=0.9)
    stole = m.mat("sky_stole", "#4fc3f7", rough=0.7, double=True)
    hair = m.mat("blonde_hair", "#e6c56a", rough=0.85)
    crystal = m.mat("sun_crystal", "#fffde7", emit="#ffee58", energy=4.5)
    humanoid(m, skin, robe, robe, m.mat("sandals", "#a1887f", rough=0.8), w=0.94)
    eyes(m, m.mat("iris", "#1e88e5", rough=0.3), m.mat("sclera", "#f5f2ee", rough=0.3))
    hair_long(m, hair, 0.5)
    m.part("cylinder", [0.11, 0.13, 0.12], (0, 1.9, 0.02), robe)
    m.part("box", [0.03, 0.1, 0.01], (0, 1.92, -0.11), gold)
    m.part("cylinder", [0.26, 0.38, 0.9], (0, 0.55, 0), robe)
    m.part("torus", [0.37, 0.39], (0, 0.12, 0), gold)
    m.part("box", [0.08, 0.9, 0.015], (0.08, 1.05, -0.17), stole, rot=(0, 0, 4), mirror=True)
    m.part("box", [0.14, 0.18, 0.05], (-0.24, 0.9, -0.02), m.mat("prayer_book", "#6d4c41", rough=0.8))
    m.part("cylinder", [0.018, 0.018, 1.6], (0.35, 0.85, -0.12), gold, group="arm_r")
    m.part("torus", [0.08, 0.1], (0.35, 1.7, -0.12), gold, rot=(90, 0, 0), group="arm_r")
    m.part("sphere", [0.06], (0.35, 1.7, -0.12), crystal, group="arm_r")
    return m


def selene():
    m = N(123, "selene", "Mestra Joalheira Selene Lapidária", "Joalheira",
          "Elarin esguia de cabelos prateados presos num coque com grampos de safira, monóculo de lapidação "
          "dourado no olho direito, avental de veludo azul-noite cheio de bolsinhos, luvas finas de seda, "
          "colares de pedras coloridas e uma pinça de ourives na mão.",
          "#ba68c8", scale=0.98)
    skin = m.mat("skin", "#f1d2c0", rough=0.5)
    hair = m.mat("silver_hair", "#d8dde3", rough=0.6)
    velvet = m.mat("night_velvet", "#1f2a5a", rough=0.9)
    dress = m.mat("lilac_silk", "#9575cd", rough=0.6)
    gold = m.mat("gold", "#e8bd4f", rough=0.25, metal=0.95)
    sapph = m.mat("sapphire", "#2962ff", emit="#448aff", energy=1.5)
    ruby = m.mat("ruby", "#d50000", emit="#ff1744", energy=1.5)
    emer = m.mat("emerald", "#00c853", emit="#00e676", energy=1.2)
    lens = m.mat("monocle_lens", "#e3f2fd", rough=0.05, metal=0.2)
    humanoid(m, skin, dress, dress, m.mat("shoes", "#3e2723", rough=0.7),
             hands=m.mat("silk_gloves", "#f5f5f5", rough=0.5), w=0.92)
    eyes(m, m.mat("iris", "#7e57c2", rough=0.3), m.mat("sclera", "#f6f2ee", rough=0.3))
    pointed_ears(m, skin)
    hair_short(m, hair)
    m.part("sphere", [0.075], (0, 1.86, 0.08), hair)
    for x, c in ((-0.05, sapph), (0.0, sapph), (0.05, sapph)):
        m.part("sphere", [0.012], (x, 1.9, 0.12), c)
    m.part("torus", [0.024, 0.03], (-0.045, 1.72, -0.125), gold, rot=(90, 0, 0))
    m.part("cylinder", [0.024, 0.024, 0.004], (-0.045, 1.72, -0.127), lens, rot=(90, 0, 0))
    m.chain([(-0.07, 1.72, -0.12), (-0.11, 1.6, -0.1), (-0.12, 1.45, -0.08)], [0.004, 0.004, 0.004], gold)
    m.part("box", [0.36, 0.72, 0.03], (0, 1.0, -0.19), velvet, rot=(3, 0, 0))
    for i, c in enumerate((ruby, sapph, emer, ruby, sapph)):
        m.part("box", [0.05, 0.05, 0.02], (-0.12 + i * 0.06, 0.9, -0.21), velvet)
        m.part("sphere", [0.012], (-0.12 + i * 0.06, 0.93, -0.215), c)
    m.part("torus", [0.11, 0.122], (0, 1.47, -0.03), gold, rot=(72, 0, 0))
    for i, c in enumerate((ruby, emer, sapph)):
        m.part("sphere", [0.018], (-0.05 + i * 0.05, 1.38, -0.13), c)
    m.part("cylinder", [0.006, 0.003, 0.14], (0.32, 0.92, -0.2), gold, rot=(60, 0, 0), group="arm_r")
    m.part("sphere", [0.014], (0.32, 0.96, -0.27), sapph, group="arm_r")
    return m


NPCS = [garrick, lyra, varis, randel, valen, ghost_alchemist, nyx, tao, iolanthe, fiorella, bartolomeu, thorne,
        bran, pip, tilda, mortimer, paladin, cleric, selene]
