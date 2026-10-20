"""Clipes de animação procedurais (keyframes de pose) para todos os humanoides.

Canais (graus, exceto root_y em metros):
  torso, arm_r, arm_l, leg_r, leg_l : [rx, ry, rz] aplicados aos pivôs de mesmo nome
  root   : [rx, ry, rz] no pivô 'pose' (corpo inteiro, centrado a 0,6 m do chão)
  root_y : deslocamento vertical do corpo

Convenções de rotação (personagem olhando para -Z):
  braço/perna rx > 0  -> balança para FRENTE;  braço_r rz > 0 -> abre para fora
  torso rx < 0        -> inclina para frente;  torso ry > 0 -> gira para a esquerda
"""

CHANNELS = ["torso", "arm_r", "arm_l", "leg_r", "leg_l", "root", "root_y"]


def k(t, **ch):
    return [round(t, 4), {name: (list(v) if isinstance(v, (list, tuple)) else v) for name, v in ch.items()}]


def clip(length, loop, keys, desc):
    return {"length": length, "loop": loop, "keys": keys, "desc": desc}


CLIPS = {
    "idle": clip(2.0, True, [
        k(0.0, torso=(0, 0, 0), arm_r=(6, 0, 7), arm_l=(6, 0, -7), root_y=0.0),
        k(1.0, torso=(-2.5, 0, 0.6), arm_r=(9, 0, 9), arm_l=(9, 0, -9), leg_r=(1, 0, 0), leg_l=(-1, 0, 0), root_y=-0.012),
        k(2.0, torso=(0, 0, 0), arm_r=(6, 0, 7), arm_l=(6, 0, -7), root_y=0.0),
    ], "Respiração no tórax e leve troca de peso (2,0 s, loop)."),

    "walk": clip(1.0, True, [
        k(0.0, leg_r=(26, 0, 0), leg_l=(-24, 0, 0), arm_r=(-20, 0, 6), arm_l=(22, 0, -6), torso=(-2, 4, 0), root_y=-0.01),
        k(0.25, leg_r=(0, 0, 0), leg_l=(4, 0, 0), arm_r=(0, 0, 6), arm_l=(0, 0, -6), torso=(-2, 0, 0), root_y=0.03),
        k(0.5, leg_r=(-24, 0, 0), leg_l=(26, 0, 0), arm_r=(22, 0, 6), arm_l=(-20, 0, -6), torso=(-2, -4, 0), root_y=-0.01),
        k(0.75, leg_r=(4, 0, 0), leg_l=(0, 0, 0), arm_r=(0, 0, 6), arm_l=(0, 0, -6), torso=(-2, 0, 0), root_y=0.03),
        k(1.0, leg_r=(26, 0, 0), leg_l=(-24, 0, 0), arm_r=(-20, 0, 6), arm_l=(22, 0, -6), torso=(-2, 4, 0), root_y=-0.01),
    ], "Passo natural de patrulha (1,0 s, loop)."),

    "run": clip(0.7, True, [
        k(0.0, leg_r=(48, 0, 0), leg_l=(-38, 0, 0), arm_r=(-38, 0, 10), arm_l=(42, 0, -10), torso=(-15, 6, 0), root_y=-0.03),
        k(0.175, leg_r=(5, 0, 0), leg_l=(10, 0, 0), arm_r=(0, 0, 10), arm_l=(0, 0, -10), torso=(-15, 0, 0), root_y=0.06),
        k(0.35, leg_r=(-38, 0, 0), leg_l=(48, 0, 0), arm_r=(42, 0, 10), arm_l=(-38, 0, -10), torso=(-15, -6, 0), root_y=-0.03),
        k(0.525, leg_r=(10, 0, 0), leg_l=(5, 0, 0), arm_r=(0, 0, 10), arm_l=(0, 0, -10), torso=(-15, 0, 0), root_y=0.06),
        k(0.7, leg_r=(48, 0, 0), leg_l=(-38, 0, 0), arm_r=(-38, 0, 10), arm_l=(42, 0, -10), torso=(-15, 6, 0), root_y=-0.03),
    ], "Corrida com tronco inclinado 15° para frente (0,7 s, loop)."),

    "dodge_roll": clip(0.45, False, [
        k(0.0),
        k(0.08, torso=(-35, 0, 0), leg_r=(70, 0, 0), leg_l=(60, 0, 0), arm_r=(50, 0, 10), arm_l=(50, 0, -10), root_y=-0.3),
        k(0.16, torso=(-50, 0, 0), leg_r=(95, 0, 0), leg_l=(95, 0, 0), arm_r=(80, 0, 0), arm_l=(80, 0, 0), root=(-120, 0, 0), root_y=-0.2),
        k(0.3, torso=(-50, 0, 0), leg_r=(95, 0, 0), leg_l=(95, 0, 0), arm_r=(80, 0, 0), arm_l=(80, 0, 0), root=(-300, 0, 0), root_y=-0.25),
        k(0.37, torso=(-25, 0, 0), leg_r=(60, 0, 0), leg_l=(30, 0, 0), arm_r=(30, 0, 30), arm_l=(10, 0, -30), root=(-360, 0, 0), root_y=-0.25),
        k(0.45, root=(-360, 0, 0)),
    ], "Esquiva: agacha (0–5), rola com o ombro (6–20) e recupera (21–27)."),

    "attack_1h": clip(0.5, False, [
        k(0.0),
        k(0.13, torso=(0, -32, 0), arm_r=(135, 0, 45), arm_l=(20, 0, -15), leg_r=(-10, 0, 0), leg_l=(12, 0, 0)),
        k(0.27, torso=(-8, 34, 0), arm_r=(45, 0, -35), arm_l=(10, 0, -25), leg_r=(-10, 0, 0), leg_l=(12, 0, 0), root_y=-0.04),
        k(0.36, torso=(-6, 30, 0), arm_r=(40, 0, -30), arm_l=(10, 0, -25), root_y=-0.04),
        k(0.5),
    ], "Corte diagonal da direita para a esquerda com giro de quadril."),

    "attack_2h_heavy": clip(0.6, False, [
        k(0.0),
        k(0.22, torso=(14, -12, 0), arm_r=(170, 0, 5), arm_l=(165, 0, -5), leg_r=(-12, 0, 0), leg_l=(15, 0, 0)),
        k(0.36, torso=(-32, 8, 0), arm_r=(45, 0, 0), arm_l=(45, 0, 0), leg_r=(-15, 0, 0), leg_l=(28, 0, 0), root_y=-0.12),
        k(0.46, torso=(-30, 6, 0), arm_r=(40, 0, 0), arm_l=(40, 0, 0), leg_r=(-15, 0, 0), leg_l=(28, 0, 0), root_y=-0.12),
        k(0.6),
    ], "Golpe esmagador de cima para baixo com o peso do corpo (Ferreiro)."),

    "attack_2h_sweep": clip(0.6, False, [
        k(0.0),
        k(0.16, torso=(-6, -65, 0), arm_r=(80, 0, 55), arm_l=(70, 0, 20), leg_r=(-12, 0, 0), leg_l=(14, 0, 0)),
        k(0.38, torso=(-10, 75, 0), arm_r=(80, 0, -40), arm_l=(75, 0, -55), leg_r=(-12, 0, 0), leg_l=(14, 0, 0), root_y=-0.05),
        k(0.46, torso=(-8, 70, 0), arm_r=(75, 0, -35), arm_l=(70, 0, -50), root_y=-0.05),
        k(0.6),
    ], "Corte horizontal amplo de 180° com as duas mãos (Ceifador)."),

    "attack_bow": clip(0.55, False, [
        k(0.0),
        k(0.12, torso=(0, -25, 0), arm_l=(90, 25, -5), arm_r=(85, 0, 0)),
        k(0.3, torso=(0, -32, 0), arm_l=(90, 30, -5), arm_r=(85, 0, -45), leg_r=(-8, 0, 0), leg_l=(10, 0, 0)),
        k(0.36, torso=(4, -30, 0), arm_l=(92, 30, -5), arm_r=(70, 0, -20)),
        k(0.55),
    ], "Estica o arco para frente, puxa a corda até o queixo e solta com recuo."),

    "attack_cast": clip(0.5, False, [
        k(0.0),
        k(0.15, torso=(6, -10, 0), arm_r=(35, 0, 10), arm_l=(30, 0, -30)),
        k(0.26, torso=(-12, 8, 0), arm_r=(85, 0, 0), arm_l=(60, 0, -10), leg_r=(-10, 0, 0), leg_l=(14, 0, 0), root_y=-0.03),
        k(0.36, torso=(-10, 6, 0), arm_r=(80, 0, 0), arm_l=(55, 0, -10), root_y=-0.03),
        k(0.5),
    ], "Empurra o cajado à frente disparando o orbe arcano (Iniciado)."),

    "attack_throw": clip(0.5, False, [
        k(0.0),
        k(0.16, torso=(10, -28, 0), arm_r=(165, 0, 25), arm_l=(60, 0, -20), leg_r=(-14, 0, 0), leg_l=(12, 0, 0)),
        k(0.3, torso=(-16, 22, 0), arm_r=(40, 0, -10), arm_l=(20, 0, -20), leg_r=(-14, 0, 0), leg_l=(18, 0, 0)),
        k(0.5),
    ], "Arremesso por cima do ombro como uma granada (Alquimista)."),

    "skill_q": clip(0.6, False, [
        k(0.0),
        k(0.1, torso=(-20, 0, 0), leg_r=(40, 0, 0), leg_l=(40, 0, 0), arm_r=(20, 0, 20), root_y=-0.15),
        k(0.22, torso=(10, -20, 0), arm_r=(170, 0, 10), arm_l=(150, 0, -10), leg_r=(30, 0, 0), leg_l=(-10, 0, 0), root_y=0.35),
        k(0.34, torso=(-35, 15, 0), arm_r=(40, 0, -10), arm_l=(40, 0, 0), leg_r=(-10, 0, 0), leg_l=(40, 0, 0), root_y=-0.18),
        k(0.45, torso=(-30, 12, 0), arm_r=(35, 0, -10), arm_l=(35, 0, 0), leg_r=(-10, 0, 0), leg_l=(40, 0, 0), root_y=-0.18),
        k(0.6),
    ], "Salto curto girando o tronco num golpe forte no chão."),

    "skill_q_support": clip(0.6, False, [
        k(0.0),
        k(0.22, torso=(8, 0, 0), arm_r=(172, 0, 8), arm_l=(172, 0, -8), root_y=0.02),
        k(0.45, torso=(10, 0, 0), arm_r=(176, 0, 4), arm_l=(176, 0, -4), root_y=0.03),
        k(0.6),
    ], "Ergue a arma/frasco acima da cabeça enquanto o anel de cura se expande."),

    "skill_r_shield": clip(0.6, False, [
        k(0.0),
        k(0.14, torso=(-6, 20, 0), arm_l=(85, -10, 10), arm_r=(25, 0, 25), leg_r=(-22, 0, 0), leg_l=(22, 0, 0), root_y=-0.07),
        k(0.45, torso=(-6, 20, 0), arm_l=(88, -10, 10), arm_r=(25, 0, 25), leg_r=(-22, 0, 0), leg_l=(22, 0, 0), root_y=-0.07),
        k(0.6),
    ], "Crava o pé de trás e levanta o escudo diante do peito (Parry)."),

    "skill_r_sharpen": clip(0.6, False, [
        k(0.0),
        k(0.18, torso=(6, -10, 0), arm_r=(120, 0, -20), arm_l=(70, 0, 30)),
        k(0.28, torso=(-14, 6, 0), arm_r=(65, 0, -35), arm_l=(70, 0, 30), root_y=-0.05),
        k(0.4, torso=(-12, 4, 0), arm_r=(70, 0, -30), arm_l=(72, 0, 30), root_y=-0.05),
        k(0.6),
    ], "Bate o martelo contra a própria manopla gerando a onda de afiação."),

    "skill_r_backflip": clip(0.6, False, [
        k(0.0),
        k(0.08, torso=(-20, 0, 0), leg_r=(45, 0, 0), leg_l=(45, 0, 0), root_y=-0.18),
        k(0.25, torso=(20, 0, 0), arm_l=(110, 0, 0), arm_r=(110, 0, -20), leg_r=(60, 0, 0), leg_l=(60, 0, 0), root=(180, 0, 0), root_y=0.5),
        k(0.42, torso=(10, 0, 0), leg_r=(40, 0, 0), leg_l=(20, 0, 0), root=(340, 0, 0), root_y=0.1),
        k(0.5, root=(360, 0, 0), torso=(-10, 0, 0), leg_r=(25, 0, 0), leg_l=(25, 0, 0), root_y=-0.12),
        k(0.6, root=(360, 0, 0)),
    ], "Mortal para trás disparando para baixo no ar (Batedor)."),

    "skill_f_spin": clip(0.9, False, [
        k(0.0),
        k(0.12, torso=(-10, -40, 0), arm_r=(90, 0, 80), arm_l=(80, 0, -80), root_y=-0.08),
        k(0.45, torso=(-10, 0, 0), arm_r=(90, 0, 85), arm_l=(85, 0, -85), root=(0, 200, 0), root_y=-0.06),
        k(0.72, torso=(-10, 0, 0), arm_r=(90, 0, 85), arm_l=(85, 0, -85), root=(0, 360, 0), root_y=-0.08),
        k(0.9, root=(0, 360, 0)),
    ], "Giro completo de 360° com a arma estendida (furacão de lâmina)."),

    "skill_f_slam": clip(0.9, False, [
        k(0.0),
        k(0.15, torso=(-20, 0, 0), leg_r=(45, 0, 0), leg_l=(45, 0, 0), root_y=-0.2),
        k(0.35, torso=(18, 0, 0), arm_r=(175, 0, 5), arm_l=(175, 0, -5), leg_r=(30, 0, 0), leg_l=(10, 0, 0), root_y=0.55),
        k(0.52, torso=(-45, 0, 0), arm_r=(60, 0, 0), arm_l=(60, 0, 0), leg_r=(60, 0, 0), leg_l=(-15, 0, 0), root_y=-0.3),
        k(0.72, torso=(-42, 0, 0), arm_r=(55, 0, 0), arm_l=(55, 0, 0), leg_r=(60, 0, 0), leg_l=(-15, 0, 0), root_y=-0.3),
        k(0.9),
    ], "Salto alto cravando a arma com as duas mãos no chão (Ground Slam)."),

    "skill_z": clip(0.8, False, [
        k(0.0),
        k(0.12, torso=(-15, 0, 0), arm_r=(30, 0, 10), arm_l=(30, 0, -10), root_y=-0.06),
        k(0.3, torso=(20, 0, 0), arm_r=(15, 0, 75), arm_l=(15, 0, -75), root_y=0.02),
        k(0.62, torso=(22, 0, 0), arm_r=(15, 0, 80), arm_l=(15, 0, -80), root_y=0.02),
        k(0.8),
    ], "Despertar da linhagem: abre os braços, arqueia o peito e olha para cima."),

    "kneel_autopsy": clip(1.2, True, [
        k(0.0, root_y=-0.36, leg_l=(85, 0, 0), leg_r=(-20, 0, 0), torso=(-28, 0, 0), arm_r=(60, 0, -10), arm_l=(40, 0, -20)),
        k(0.6, root_y=-0.36, leg_l=(85, 0, 0), leg_r=(-20, 0, 0), torso=(-30, 4, 0), arm_r=(72, 0, -18), arm_l=(42, 0, -20)),
        k(1.2, root_y=-0.36, leg_l=(85, 0, 0), leg_r=(-20, 0, 0), torso=(-28, 0, 0), arm_r=(60, 0, -10), arm_l=(40, 0, -20)),
    ], "Ajoelhado diante do cadáver, mexendo com a faca de caça (loop)."),

    "death_fall": clip(1.0, False, [
        k(0.0),
        k(0.3, torso=(-12, 0, 0), leg_r=(35, 0, 0), leg_l=(28, 0, 0), arm_r=(20, 0, 20), arm_l=(20, 0, -20), root_y=-0.2),
        k(0.65, torso=(10, 0, 0), leg_r=(20, 0, 0), leg_l=(10, 0, 0), arm_r=(40, 0, 50), arm_l=(40, 0, -50), root=(55, 0, 10), root_y=-0.3),
        k(1.0, torso=(5, 0, 0), leg_r=(8, 0, 0), leg_l=(-4, 0, 0), arm_r=(30, 0, 70), arm_l=(20, 0, -60), root=(90, 0, 8), root_y=-0.47),
    ], "Perde as forças nos joelhos e cai de costas, mantendo o último quadro."),

    "beast_bite": clip(0.55, False, [
        k(0.0),
        k(0.15, root=(10, 0, 0), arm_r=(25, 0, 0), arm_l=(25, 0, 0), leg_r=(-15, 0, 0), leg_l=(-15, 0, 0), root_y=0.04),
        k(0.3, root=(-14, 0, 0), arm_r=(-25, 0, 0), arm_l=(-25, 0, 0), leg_r=(20, 0, 0), leg_l=(20, 0, 0), root_y=-0.05),
        k(0.38, root=(-12, 0, 0), arm_r=(-22, 0, 0), arm_l=(-22, 0, 0), leg_r=(18, 0, 0), leg_l=(18, 0, 0), root_y=-0.05),
        k(0.55),
    ], "Investida com mordida (quadrúpedes)."),

    "beast_death": clip(0.9, False, [
        k(0.0),
        k(0.3, root=(0, 0, 35), arm_r=(20, 0, 10), arm_l=(15, 0, -10), root_y=-0.12),
        k(0.9, root=(0, 0, 86), arm_r=(25, 0, 25), arm_l=(10, 0, -15), leg_r=(20, 0, 0), leg_l=(5, 0, 0), root_y=-0.36),
    ], "Tomba de lado e mantém o último quadro (cadáver de quadrúpede)."),
}
