"""Kit de modelagem procedural low-poly para Lunaria.

Cada modelo é descrito como uma lista de primitivas (box, sphere, cylinder,
capsule, torus, prism) agrupadas em pivôs animáveis. O resultado é um
dicionário puro (JSON) consumido tanto pelo cliente Godot (RaceModel.gd)
quanto pelo preview web — garantindo que o preview seja idêntico ao jogo.

Convenções (iguais às do Godot 4):
  * Y para cima, personagem olhando para -Z, lado direito do personagem = +X.
  * Pés na origem; altura nominal de um humanoide ~1.85 m.
  * Rotações em graus, ordem de Euler YXZ (padrão do Node3D).
  * Grupos cujo nome é leg_l/leg_r/arm_l/arm_r recebem o balanço de caminhada.
"""

import math
import random

# ---------------------------------------------------------------------------
# Matemática de rotação (matrizes 3x3 em listas de linhas)
# ---------------------------------------------------------------------------


def _rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def _ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def _rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def euler_to_mat(rot):
    x, y, z = (math.radians(v) for v in rot)
    return mmul(_ry(y), mmul(_rx(x), _rz(z)))


def mat_to_euler(m):
    x = math.asin(max(-1.0, min(1.0, -m[1][2])))
    if abs(math.cos(x)) > 1e-6:
        y = math.atan2(m[0][2], m[2][2])
        z = math.atan2(m[1][0], m[1][1])
    else:
        y = math.atan2(-m[2][0], m[0][0])
        z = 0.0
    return (math.degrees(x), math.degrees(y), math.degrees(z))


def align_y(d, roll=0.0):
    """Rotação (Euler YXZ, graus) que aponta o eixo +Y local na direção d."""
    l = math.sqrt(sum(c * c for c in d)) or 1.0
    dx, dy, dz = (c / l for c in d)
    a = math.acos(max(-1.0, min(1.0, dy)))
    b = math.atan2(dx, dz) if abs(math.sin(a)) > 1e-6 else 0.0
    return mat_to_euler(mmul(_ry(b), mmul(_rx(a), _ry(math.radians(roll)))))


def basis_euler(y_dir, z_hint=(0, 0, 1)):
    """Euler YXZ de uma base com +Y ao longo de y_dir e +Z o mais próximo possível de z_hint."""
    def norm(v):
        l = math.sqrt(sum(c * c for c in v)) or 1.0
        return tuple(c / l for c in v)

    def cross(a, b):
        return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])

    y = norm(y_dir)
    x = cross(y, z_hint)
    if math.sqrt(sum(c * c for c in x)) < 1e-6:
        x = cross(y, (1, 0, 0))
    x = norm(x)
    z = cross(x, y)
    mat = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
    return mat_to_euler(mat)


def v_add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def v_sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def v_scale(a, s):
    return tuple(x * s for x in a)


def v_len(a):
    return math.sqrt(sum(x * x for x in a))


def v_lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def _r(v):
    if isinstance(v, (list, tuple)):
        return [_r(x) for x in v]
    if isinstance(v, float):
        out = round(v, 4)
        return 0.0 if out == 0 else out
    return v


def _swap_side(name):
    if name is None:
        return None
    if name.endswith("_r"):
        return name[:-2] + "_l"
    if name.endswith("_l"):
        return name[:-2] + "_r"
    return name


def _mirror_anim(anim):
    if not anim:
        return anim
    out = dict(anim)
    if "axis" in out:
        ax = out["axis"]
        out["axis"] = [ax[0], -ax[1], -ax[2]]
    return out


# ---------------------------------------------------------------------------
# Modelo
# ---------------------------------------------------------------------------


class Model:
    def __init__(self, race_id, key, name, title, lore, color, scale=1.0, seed=7, kind="race"):
        self.kind = kind
        self.gear = None
        self.extra_actions = None
        self.primary = None
        self.shield_material = None
        self.body_w = 1.0
        self.anchors = {}
        self.rest_pose = None
        self.race_id = race_id
        self.key = key
        self.name = name
        self.title = title
        self.lore = lore
        self.color = color
        self.scale = scale
        self.mats = {}
        self.groups = []
        self._group_names = set()
        self.parts = []
        self.lights = []
        self._auto = 0
        self.rng = random.Random(seed)

    # -- materiais ---------------------------------------------------------
    def mat(self, name, color, rough=0.6, metal=0.0, emit=None, energy=1.0,
            alpha=1.0, double=False, anim=None, unshaded=False):
        spec = {"color": color, "rough": rough, "metal": metal}
        if emit:
            spec["emit"] = emit
            spec["energy"] = energy
        if alpha < 1.0:
            spec["alpha"] = alpha
        if double:
            spec["double"] = True
        if unshaded:
            spec["unshaded"] = True
        if anim:
            spec["anim"] = anim
        self.mats[name] = spec
        return name

    # -- grupos ------------------------------------------------------------
    def group(self, name, pivot, parent=None, anim=None, mirror=False):
        if mirror:
            mp = (-pivot[0], pivot[1], pivot[2])
            self.group(_swap_side(name), mp, _swap_side(parent), _mirror_anim(anim))
        assert name not in self._group_names, name
        assert parent is None or parent in self._group_names, parent
        g = {"name": name, "pivot": _r(list(pivot))}
        if parent:
            g["parent"] = parent
        if anim:
            g["anim"] = anim
        self.groups.append(g)
        self._group_names.add(name)
        return name

    def _auto_group(self, pivot, parent, anim):
        self._auto += 1
        return self.group("fx%d" % self._auto, pivot, parent, anim)

    # -- partes ------------------------------------------------------------
    def part(self, shape, size, pos, mat, rot=(0, 0, 0), scale=None,
             group=None, anim=None, mirror=False):
        assert mat in self.mats, mat
        if mirror:
            self.part(shape, size, (-pos[0], pos[1], pos[2]), mat,
                      (rot[0], -rot[1], -rot[2]), scale, _swap_side(group),
                      _mirror_anim(anim))
        if anim:
            group = self._auto_group(pos, group, anim)
        p = {"shape": shape, "size": _r(list(size)), "pos": _r(list(pos)), "mat": mat}
        if any(abs(v) > 1e-6 for v in rot):
            p["rot"] = _r(list(rot))
        if scale is not None:
            p["scale"] = _r(list(scale))
        if group:
            p["group"] = group
        self.parts.append(p)

    def seg(self, p0, p1, r0, r1, mat, group=None, mirror=False, sides="cylinder"):
        """Cilindro/cone ligando p0 (raio r0) a p1 (raio r1)."""
        d = v_sub(p1, p0)
        self.part("cylinder", (r1, r0, v_len(d)), v_lerp(p0, p1, 0.5), mat,
                  align_y(d), group=group, mirror=mirror)

    def plank(self, p0, p1, width, thick, mat, roll=0.0, group=None, mirror=False):
        """Caixa achatada ligando p0 a p1 (penas, lâminas, placas)."""
        d = v_sub(p1, p0)
        self.part("box", (width, v_len(d), thick), v_lerp(p0, p1, 0.5), mat,
                  align_y(d, roll), group=group, mirror=mirror)

    def chain(self, points, radii, mat, group=None, mirror=False, joints=None):
        """Sequência de segmentos cônicos (chifres, caudas, pernas de aranha)."""
        for i in range(len(points) - 1):
            self.seg(points[i], points[i + 1], radii[i], radii[i + 1], mat, group, mirror)
            if joints and 0 < i + 1 < len(points) - 1:
                self.part("sphere", [radii[i + 1] * 1.15], points[i + 1], joints,
                          group=group, mirror=mirror)

    def anchor(self, name, group, pos, rot=(0, 0, 0)):
        """Ponto de encaixe (mão, costas) onde armas e acessórios são presos."""
        self.anchors[name] = {"group": group, "pos": _r(list(pos)), "rot": _r(list(rot))}

    @property
    def uid(self):
        if self.kind in ("race", "npc", "mob"):
            return "%s_%d" % (self.kind, self.race_id)
        return "%s_%s" % (self.kind, self.key)

    def _articulate(self):
        """Insere os pivôs 'pose' (corpo inteiro) e 'torso' para as animações.

        Tudo acima do quadril passa a seguir o tronco; pernas, caudas e saias
        seguem o pivô do corpo. Trajes (kind=outfit) usam a mesma regra, mas
        apontam para os pivôs do corpo onde serão vestidos.
        """
        def target(y, name=None):
            if name and (name in ("leg_l", "leg_r") or name.startswith("tail")):
                return "pose"
            return "torso" if y > 0.97 else "pose"

        groups = []
        if self.kind != "outfit":
            groups = [{"name": "pose", "pivot": [0.0, 0.6, 0.0]},
                      {"name": "torso", "pivot": [0.0, 0.98, 0.0], "parent": "pose"}]
        for g in self.groups:
            g = dict(g)
            if "parent" not in g:
                g["parent"] = target(g["pivot"][1], g["name"])
            groups.append(g)
        parts = []
        for p in self.parts:
            p = dict(p)
            if "group" not in p:
                p["group"] = "torso" if p["pos"][1] > 1.0 else "pose"
            parts.append(p)
        return groups, parts

    def light(self, color, energy, rng, pos):
        self.lights.append({"color": color, "energy": energy, "range": rng, "pos": _r(list(pos))})

    # -- exportação ----------------------------------------------------------
    def to_dict(self):
        groups, parts = self.groups, self.parts
        if self.kind in ("race", "npc", "mob", "outfit"):
            groups, parts = self._articulate()
        anchors = {}
        for k, a in self.anchors.items():
            a = dict(a)
            if a["group"] is None and self.kind in ("race", "npc", "mob"):
                a["group"] = "torso" if a["pos"][1] > 0.97 else "pose"
            anchors[k] = a
        out = {
            "uid": self.uid,
            "kind": self.kind,
            "id": self.race_id,
            "key": self.key,
            "name": self.name,
            "title": self.title,
            "lore": self.lore,
            "color": self.color,
            "scale": self.scale,
            "materials": self.mats,
            "groups": groups,
            "parts": parts,
            "lights": self.lights,
            "body_w": self.body_w,
            "anchors": anchors,
        }
        if self.rest_pose:
            out["rest_pose"] = self.rest_pose
        for key in ("gear", "extra_actions", "primary", "shield_material"):
            if getattr(self, key):
                out[key] = getattr(self, key)
        return out


# ---------------------------------------------------------------------------
# Esqueleto humanoide base
# ---------------------------------------------------------------------------


def humanoid(m, skin, top, bottom, boots, hands=None, forearm=None, eye=None,
             w=1.0, head=True, neck=True, torso=True):
    """Corpo humanoide padrão. Retorna pontos de referência úteis."""
    hands = hands or skin
    forearm = forearm or skin
    m.body_w = w
    m.anchor("hand_r", "arm_r", (0.32 * w, 0.88, -0.15))
    m.anchor("hand_l", "arm_l", (-0.32 * w, 0.88, -0.15))
    m.anchor("back", None, (0, 1.32, 0.19))
    m.group("leg_r", (0.11 * w, 0.94, 0), mirror=True)
    m.part("capsule", [0.085 * w, 0.5], (0.11 * w, 0.7, 0), bottom, group="leg_r", mirror=True)
    m.part("capsule", [0.07 * w, 0.46], (0.11 * w, 0.3, 0), boots, group="leg_r", mirror=True)
    m.part("box", [0.13 * w, 0.07, 0.26], (0.11 * w, 0.035, -0.05), boots, group="leg_r", mirror=True)

    m.part("capsule", [0.115, 0.36 * w], (0, 0.98, 0), bottom, rot=(0, 0, 90))
    if torso:
        m.part("sphere", [0.2], (0, 1.27, 0), top, scale=(1.2 * w, 1.45, 0.78))
    if neck:
        m.part("cylinder", [0.05, 0.056, 0.14], (0, 1.57, 0), skin)
    if head:
        m.part("sphere", [0.125], (0, 1.71, 0), skin, scale=(1, 1.1, 1.02))
    if eye:
        m.part("sphere", [0.019], (0.045, 1.72, -0.112), eye, mirror=True)

    m.group("arm_r", (0.26 * w, 1.47, 0), mirror=True)
    m.part("sphere", [0.085 * w], (0.26 * w, 1.47, 0), top, group="arm_r", mirror=True)
    m.part("capsule", [0.058 * w, 0.34], (0.28 * w, 1.3, 0), top, rot=(0, 0, 8), group="arm_r", mirror=True)
    m.part("capsule", [0.05 * w, 0.3], (0.31 * w, 1.05, -0.06), forearm, rot=(30, 0, 6), group="arm_r", mirror=True)
    m.part("sphere", [0.052], (0.32 * w, 0.9, -0.14), hands, scale=(0.9, 1.15, 0.9), group="arm_r", mirror=True)
    return {
        "head": (0, 1.71, 0),
        "hand_r": (0.32 * w, 0.9, -0.14),
        "shoulder_r": (0.26 * w, 1.47, 0),
        "back": (0, 1.35, 0.15),
    }


def flower(m, center, radius, petal_mat, core_mat, petals=5, tilt=25.0, group=None, phase=0.0):
    """Flor noturna: miolo + pétalas em leque."""
    m.part("sphere", [radius * 0.45], center, core_mat, group=group)
    for i in range(petals):
        ang = phase + i * 2 * math.pi / petals
        off = (math.cos(ang) * radius, 0.0, math.sin(ang) * radius)
        rot = (0, -math.degrees(ang), tilt)
        m.part("sphere", [radius * 0.75], v_add(center, off), petal_mat,
               rot=rot, scale=(1.0, 0.25, 0.55), group=group)


def mushroom(m, base, height, cap_r, stem_mat, cap_mat, tilt=(0, 0, 0), group=None, spot_mat=None):
    """Cogumelo pequeno: haste + chapéu achatado (+ pintas opcionais)."""
    rot_m = euler_to_mat(tilt)
    up = (rot_m[0][1], rot_m[1][1], rot_m[2][1])
    top = v_add(base, v_scale(up, height))
    m.part("cylinder", [cap_r * 0.28, cap_r * 0.38, height], v_lerp(base, top, 0.5), stem_mat, rot=tilt, group=group)
    m.part("sphere", [cap_r], top, cap_mat, rot=tilt, scale=(1, 0.45, 1), group=group)
    if spot_mat:
        m.part("sphere", [cap_r * 0.22], v_add(top, v_scale(up, cap_r * 0.42)), spot_mat, group=group)


BODY_GROUPS = (None, "leg_l", "leg_r", "arm_l", "arm_r")


def ghost_copy(m, ghost_mat, offset):
    """Duplica as partes do corpo como eco translúcido (Cronari)."""
    body = [p for p in m.parts if p.get("group") in BODY_GROUPS
            and m.mats[p["mat"]].get("alpha", 1.0) >= 1.0]
    for p in body:
        q = dict(p)
        q["pos"] = _r(list(v_add(p["pos"], offset)))
        q["mat"] = ghost_mat
        m.parts.append(q)


# ---------------------------------------------------------------------------
# Detalhes: pelagem, penas e membranas
# ---------------------------------------------------------------------------


def fur_tufts(m, center, radii, count, mat, group=None, length=0.08, thickness=0.022,
              bias=(0, 0, 0.6), region=None, seed=0, mirror=False):
    """Tufos de pelo (cones) espalhados sobre um elipsoide, apontando para fora + bias.

    region(nx, ny, nz) -> bool limita onde nascem os tufos (ex.: só nas costas).
    """
    rng = random.Random(seed or len(m.parts) + 17)
    count = int(count * 1.7)  # pelagem densa
    placed, tries = 0, 0
    while placed < count and tries < count * 20:
        tries += 1
        u, v = rng.uniform(-1, 1), rng.uniform(0, 2 * math.pi)
        r = math.sqrt(1 - u * u)
        n = (r * math.cos(v), u, r * math.sin(v))
        if region and not region(*n):
            continue
        p = (center[0] + n[0] * radii[0], center[1] + n[1] * radii[1], center[2] + n[2] * radii[2])
        d = (n[0] + bias[0], n[1] + bias[1], n[2] + bias[2])
        ln = length * rng.uniform(0.7, 1.3)
        dn = v_scale(d, 1.0 / (v_len(d) or 1))
        mid = v_add(p, v_scale(dn, ln * 0.45))
        th = thickness * rng.uniform(0.8, 1.25)
        # Mecha macia: elipsoide alongado e achatado, deitado na direção do pelo
        m.part("sphere", [ln * 0.5], mid, mat, rot=basis_euler(dn, n),
               scale=(th / ln * 2.6, 1.0, th / ln * 1.6), group=group, mirror=mirror)
        placed += 1


def feather_wing(m, root, side, span, feather_mat, covert_mat, bone_mat, group, droop=0.0, layers=3):
    """Asa de ave em camadas: ossos, rêmiges primárias/secundárias e coberteiras arredondadas."""
    elbow = (root[0] + side * span * 0.42, root[1] + span * 0.34, root[2] + span * 0.18)
    tip = (root[0] + side * span, root[1] + span * 0.42 - droop, root[2] + span * 0.3)
    m.chain([root, elbow, tip], [0.045, 0.032, 0.01], bone_mat, group=group, joints=bone_mat)
    rows = [(1.0, 16, feather_mat, 0.0), (0.62, 13, covert_mat, 0.035), (0.36, 11, covert_mat, 0.07)][:layers]
    for scale_len, n, mat, zoff in rows:
        for i in range(n):
            t = i / (n - 1)
            base = v_lerp(root, elbow, t * 2) if t < 0.5 else v_lerp(elbow, tip, (t - 0.5) * 2)
            base = v_add(base, (0, -zoff * 0.5, -zoff))
            length = span * (0.32 + 0.55 * t) * scale_len
            ang = math.radians(-6 - 40 * t)
            d = (-math.sin(ang) * side, -math.cos(ang), 0.12 + 0.1 * t)
            end = v_add(base, v_scale(d, length / v_len(d)))
            width = span * (0.1 + 0.045 * t) * (0.8 + 0.4 * scale_len)
            m.plank(base, end, width, 0.01, mat, group=group)
            m.part("sphere", [width * 0.5], end, mat, scale=(1, 0.5, 0.25), group=group)
            if scale_len == 1.0:
                m.seg(base, end, 0.004, 0.002, bone_mat, group=group)


def membrane_wing(m, root, side, span, bone_mat, membrane_mat, group, fingers=4):
    """Asa de morcego/gárgula: braço ósseo, dedos longos e painéis de membrana entre eles."""
    wrist = (root[0] + side * span * 0.45, root[1] + span * 0.38, root[2] + span * 0.2)
    m.chain([root, wrist], [0.05, 0.035], bone_mat, group=group)
    m.part("sphere", [0.04], wrist, bone_mat, group=group)
    tips = []
    for f in range(fingers):
        t = f / (fingers - 1)
        ang = math.radians(15 - 105 * t)
        d = (math.cos(ang) * side, math.sin(ang), 0.15)
        length = span * (0.75 - 0.18 * t)
        mid = v_add(wrist, v_scale(d, length * 0.5))
        tipp = v_add(v_add(wrist, v_scale(d, length)), (0, -span * 0.05 * t, 0.02))
        m.chain([wrist, mid, tipp], [0.022, 0.016, 0.004], bone_mat, group=group, joints=bone_mat)
        m.part("cylinder", [0.0, 0.012, 0.06], v_add(tipp, (side * 0.02, 0, 0)), bone_mat,
               rot=(0, 0, -90 * side), group=group)
        tips.append((mid, tipp))
    body_anchor = (root[0], root[1] - span * 0.45, root[2] + 0.02)
    edges = [body_anchor] + [t[1] for t in reversed(tips)]
    for i in range(len(edges) - 1):
        a, b = edges[i], edges[i + 1]
        steps = 8
        for s in range(steps):
            f0 = (s + 0.5) / steps
            pa = v_lerp(wrist, a, f0)
            pb = v_lerp(wrist, b, f0)
            width = v_len(v_sub(pa, pb))
            if width < 0.01:
                continue
            m.part("box", (span / steps * 1.15, width, 0.008), v_lerp(pa, pb, 0.5), membrane_mat,
                   basis_euler(v_sub(pb, pa), (0, 0, 1)), group=group)
