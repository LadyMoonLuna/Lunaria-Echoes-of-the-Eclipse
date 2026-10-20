"""Exportador glTF 2.0 binário (.glb) sem dependências externas.

Gera malhas das primitivas (box, sphere, cylinder, capsule, torus, prism) nas
mesmas convenções do Godot, materiais PBR (albedo, roughness, metallic,
emissão com KHR_materials_emissive_strength), luzes pontuais e os clipes de
animação do corpo (rotação dos pivôs torso/braços/pernas e do pivô 'pose').
Hierarquia de nós = hierarquia de pivôs do modelo, então o arquivo abre no
Blender pronto para ajustes, rigging ou para virar referência de escultura.
"""

import json
import math
import os
import struct


# ---------------------------------------------------------------------------
# Geometria das primitivas
# ---------------------------------------------------------------------------

def _box(sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    pos, nor, idx = [], [], []
    faces = [((1, 0, 0), (0, 1, 0), (0, 0, 1)), ((-1, 0, 0), (0, 1, 0), (0, 0, -1)),
             ((0, 1, 0), (0, 0, 1), (1, 0, 0)), ((0, -1, 0), (0, 0, -1), (1, 0, 0)),
             ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (-1, 0, 0), (0, 1, 0))]
    for n, u, v in faces:
        base = len(pos)
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = [n[i] * (hx, hy, hz)[i] + u[i] * a * (hx, hy, hz)[i] + v[i] * b * (hx, hy, hz)[i] for i in range(3)]
            pos.append(p)
            nor.append(list(n))
        # garante sentido anti-horário visto de fora
        cross = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
        if sum(cross[i] * n[i] for i in range(3)) > 0:
            idx += [base, base + 1, base + 2, base, base + 2, base + 3]
        else:
            idx += [base, base + 2, base + 1, base, base + 3, base + 2]
    return pos, nor, idx


def _lathe(profile, segs):
    """Superfície de revolução em torno de Y. profile = [(raio, y, nr, ny)]."""
    pos, nor, idx = [], [], []
    for r, y, nr, ny in profile:
        for s in range(segs + 1):
            a = 2 * math.pi * s / segs
            c, sn = math.cos(a), math.sin(a)
            pos.append([r * sn, y, r * c])
            nor.append([nr * sn, ny, nr * c])
    row = segs + 1
    for i in range(len(profile) - 1):
        for s in range(segs):
            a, b = i * row + s, i * row + s + 1
            c, d = (i + 1) * row + s, (i + 1) * row + s + 1
            idx += [a, b, d, a, d, c]
    return pos, nor, idx


def _sphere(r, segs=16, rings=10):
    prof = []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        ny, nr = math.cos(phi), math.sin(phi)
        prof.append((r * nr, r * ny, nr, ny))
    pos, nor, idx = _lathe(prof, segs)
    return pos, nor, [i for t in range(0, len(idx), 3) for i in (idx[t], idx[t + 2], idx[t + 1])]


def _cylinder(top, bottom, h, segs=14):
    hy = h / 2
    slope = (bottom - top) / h if h else 0
    ln = math.sqrt(1 + slope * slope)
    side = [(top, hy, 1 / ln, slope / ln), (bottom, -hy, 1 / ln, slope / ln)]
    pos, nor, idx = _lathe(side, segs)
    idx = [i for t in range(0, len(idx), 3) for i in (idx[t], idx[t + 2], idx[t + 1])]
    for y, r, ny in ((hy, top, 1), (-hy, bottom, -1)):
        if r <= 0:
            continue
        c = len(pos)
        pos.append([0, y, 0])
        nor.append([0, ny, 0])
        for s in range(segs + 1):
            a = 2 * math.pi * s / segs
            pos.append([r * math.sin(a), y, r * math.cos(a)])
            nor.append([0, ny, 0])
        for s in range(segs):
            if ny > 0:
                idx += [c, c + 1 + s, c + 2 + s]
            else:
                idx += [c, c + 2 + s, c + 1 + s]
    return pos, nor, idx


def _capsule(r, h, segs=14, rings=5):
    mid = max(0.0, h / 2 - r)
    prof = []
    for i in range(rings + 1):
        phi = (math.pi / 2) * i / rings
        prof.append((r * math.sin(phi), mid + r * math.cos(phi), math.sin(phi), math.cos(phi)))
    for i in range(rings + 1):
        phi = math.pi / 2 + (math.pi / 2) * i / rings
        prof.append((r * math.sin(phi), -mid + r * math.cos(phi), math.sin(phi), math.cos(phi)))
    pos, nor, idx = _lathe(prof, segs)
    return pos, nor, [i for t in range(0, len(idx), 3) for i in (idx[t], idx[t + 2], idx[t + 1])]


def _torus(inner, outer, rings=24, segs=8):
    R, t = (inner + outer) / 2, (outer - inner) / 2
    pos, nor, idx = [], [], []
    for i in range(rings + 1):
        u = 2 * math.pi * i / rings
        cu, su = math.cos(u), math.sin(u)
        for j in range(segs + 1):
            v = 2 * math.pi * j / segs
            cv, sv = math.cos(v), math.sin(v)
            pos.append([(R + t * cv) * cu, t * sv, (R + t * cv) * su])
            nor.append([cv * cu, sv, cv * su])
    row = segs + 1
    for i in range(rings):
        for j in range(segs):
            a, b, c, d = i * row + j, i * row + j + 1, (i + 1) * row + j, (i + 1) * row + j + 1
            idx += [a, b, d, a, d, c]
    return pos, nor, idx


def _prism(w, h, d):
    x, y, z = w / 2, h / 2, d / 2
    A, B, C = (-x, -y), (x, -y), (0, y)
    pos, nor, idx = [], [], []

    def tri(p, q, r, n):
        b = len(pos)
        pos.extend([list(p), list(q), list(r)])
        nor.extend([list(n)] * 3)
        idx.extend([b, b + 1, b + 2])

    tri((*A, z), (*B, z), (*C, z), (0, 0, 1))
    tri((*A, -z), (*C, -z), (*B, -z), (0, 0, -1))
    for P, Q in ((B, C), (C, A), (A, B)):
        ex, ey = Q[0] - P[0], Q[1] - P[1]
        ln = math.hypot(ex, ey) or 1
        n = (ey / ln, -ex / ln, 0)
        tri((*P, z), (*P, -z), (*Q, -z), n)
        tri((*P, z), (*Q, -z), (*Q, z), n)
    return pos, nor, idx


def geometry(shape, s):
    if shape == "box":
        return _box(*s)
    if shape == "sphere":
        return _sphere(s[0])
    if shape == "cylinder":
        return _cylinder(s[0], s[1], s[2])
    if shape == "capsule":
        return _capsule(s[0], max(s[1], 2 * s[0]))
    if shape == "torus":
        return _torus(s[0], s[1])
    if shape == "prism":
        return _prism(*s)
    return _box(0.05, 0.05, 0.05)


# ---------------------------------------------------------------------------
# Rotação
# ---------------------------------------------------------------------------

def quat_yxz(deg):
    x, y, z = (math.radians(v) / 2 for v in deg)
    qx = (math.sin(x), 0, 0, math.cos(x))
    qy = (0, math.sin(y), 0, math.cos(y))
    qz = (0, 0, math.sin(z), math.cos(z))

    def mul(a, b):
        ax, ay, az, aw = a
        bx, by, bz, bw = b
        return (aw * bx + ax * bw + ay * bz - az * by,
                aw * by - ax * bz + ay * bw + az * bx,
                aw * bz + ax * by - ay * bx + az * bw,
                aw * bw - ax * bx - ay * by - az * bz)

    return mul(mul(qy, qx), qz)


def _hex(c):
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def _srgb_to_linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


# ---------------------------------------------------------------------------
# Amostragem de clipes (mesma interpolação do cliente)
# ---------------------------------------------------------------------------

def _smooth(t):
    return t * t * (3 - 2 * t)


def sample_clip(clip, t):
    keys = clip["keys"]
    if t <= keys[0][0]:
        return keys[0][1]
    for i in range(len(keys) - 1):
        t0, p0 = keys[i]
        t1, p1 = keys[i + 1]
        if t <= t1:
            f = _smooth((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
            out = {}
            for ch in set(p0) | set(p1):
                a = p0.get(ch, 0.0 if ch == "root_y" else [0, 0, 0])
                b = p1.get(ch, 0.0 if ch == "root_y" else [0, 0, 0])
                if ch == "root_y":
                    out[ch] = a + (b - a) * f
                else:
                    out[ch] = [a[j] + (b[j] - a[j]) * f for j in range(3)]
            return out
    return keys[-1][1]


# ---------------------------------------------------------------------------
# Escrita
# ---------------------------------------------------------------------------

class _Buf:
    def __init__(self):
        self.data = bytearray()
        self.views, self.accessors = [], []

    def add(self, fmt, values, count, comp, typ, target=None, minmax=None):
        while len(self.data) % 4:
            self.data.append(0)
        off = len(self.data)
        self.data += struct.pack("<%d%s" % (len(values), fmt), *values)
        view = {"buffer": 0, "byteOffset": off, "byteLength": len(self.data) - off}
        if target:
            view["target"] = target
        self.views.append(view)
        acc = {"bufferView": len(self.views) - 1, "componentType": comp, "count": count, "type": typ}
        if minmax:
            acc["min"], acc["max"] = minmax
        self.accessors.append(acc)
        return len(self.accessors) - 1


def box_uv(pos, nor):
    """UV em metros por projeção de caixa (eixo dominante da normal), como o triplanar do Godot."""
    uv = []
    for p, n in zip(pos, nor):
        ax = max(range(3), key=lambda i: abs(n[i]))
        if ax == 0:
            uv.append([p[2] * (1 if n[0] < 0 else -1), -p[1]])
        elif ax == 1:
            uv.append([p[0], p[2] * (1 if n[1] > 0 else -1)])
        else:
            uv.append([p[0] * (1 if n[2] > 0 else -1), -p[1]])
    return uv


def export_glb(model, path, clips=None, tex_dir=None):
    """tex_dir: pasta com as texturas PNG; o .glb as referencia por caminho relativo."""
    buf = _Buf()
    gl = {"asset": {"version": "2.0", "generator": "Lunaria race_models"}, "scene": 0,
          "scenes": [{"name": model["name"], "nodes": [0]}], "nodes": [], "meshes": [], "materials": []}
    used_ext = set()

    tex_index = {}

    def texture(name):
        if name not in tex_index:
            rel = os.path.relpath(os.path.join(tex_dir, name + ".png"), os.path.dirname(path)).replace(os.sep, "/")
            gl.setdefault("images", []).append({"uri": rel})
            gl.setdefault("samplers", [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}])
            gl.setdefault("textures", []).append({"source": len(gl["images"]) - 1, "sampler": 0})
            tex_index[name] = len(gl["textures"]) - 1
        return tex_index[name]

    mat_index = {}
    for key, m in model["materials"].items():
        rgb = [_srgb_to_linear(v) for v in _hex(m.get("emit", m["color"]) if m.get("unshaded") else m["color"])]
        mat = {"name": key, "pbrMetallicRoughness": {"baseColorFactor": rgb + [m.get("alpha", 1.0)],
                                                     "metallicFactor": m.get("metal", 0.0),
                                                     "roughnessFactor": m.get("rough", 0.6)}}
        if m.get("emit"):
            mat["emissiveFactor"] = [_srgb_to_linear(v) for v in _hex(m["emit"])]
            if m.get("energy", 1.0) != 1.0 and not m.get("unshaded"):
                mat.setdefault("extensions", {})["KHR_materials_emissive_strength"] = {"emissiveStrength": m["energy"]}
                used_ext.add("KHR_materials_emissive_strength")
        if m.get("alpha", 1.0) < 1.0:
            mat["alphaMode"] = "BLEND"
        if m.get("double"):
            mat["doubleSided"] = True
        if m.get("unshaded"):
            mat.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            used_ext.add("KHR_materials_unlit")
        if m.get("tex") and tex_dir:
            inv = 1.0 / m.get("tile", 0.5)
            xf = {"KHR_texture_transform": {"scale": [inv, inv]}}
            used_ext.add("KHR_texture_transform")
            pbr = mat["pbrMetallicRoughness"]
            pbr["baseColorTexture"] = {"index": texture(m["tex"] + "_albedo"), "extensions": xf}
            pbr["metallicRoughnessTexture"] = {"index": texture(m["tex"] + "_orm"), "extensions": xf}
            mat["normalTexture"] = {"index": texture(m["tex"] + "_normal"), "extensions": xf}
            mat["occlusionTexture"] = {"index": texture(m["tex"] + "_orm"), "strength": 0.6, "extensions": xf}
        mat_index[key] = len(gl["materials"])
        gl["materials"].append(mat)

    geo_cache, mesh_cache = {}, {}

    def mesh_for(shape, size, mat):
        gkey = (shape, tuple(size))
        if gkey not in geo_cache:
            pos, nor, idx = geometry(shape, size)
            flat_p = [c for p in pos for c in p]
            flat_n = [c for n in nor for c in n]
            mn = [min(p[i] for p in pos) for i in range(3)]
            mx = [max(p[i] for p in pos) for i in range(3)]
            a_p = buf.add("f", flat_p, len(pos), 5126, "VEC3", 34962, (mn, mx))
            a_n = buf.add("f", flat_n, len(nor), 5126, "VEC3", 34962)
            a_t = buf.add("f", [c for t in box_uv(pos, nor) for c in t], len(pos), 5126, "VEC2", 34962)
            if len(pos) < 65536:
                a_i = buf.add("H", idx, len(idx), 5123, "SCALAR", 34963)
            else:
                a_i = buf.add("I", idx, len(idx), 5125, "SCALAR", 34963)
            geo_cache[gkey] = (a_p, a_n, a_t, a_i)
        mkey = (gkey, mat)
        if mkey not in mesh_cache:
            a_p, a_n, a_t, a_i = geo_cache[gkey]
            gl["meshes"].append({"name": "%s_%s" % (shape, mat), "primitives": [
                {"attributes": {"POSITION": a_p, "NORMAL": a_n, "TEXCOORD_0": a_t}, "indices": a_i,
                 "material": mat_index[mat]}]})
            mesh_cache[mkey] = len(gl["meshes"]) - 1
        return mesh_cache[mkey]

    nodes = gl["nodes"]
    s = model.get("scale", 1.0)
    nodes.append({"name": model["uid"], "children": [], "scale": [s, s, s]})
    group_node, pivots = {}, {}
    groups = list(model["groups"])
    if model["kind"] == "outfit":
        # Trajes referenciam os pivôs do corpo: recria um esqueleto padrão (largura 1.0)
        groups = [{"name": "pose", "pivot": [0, 0.6, 0]}, {"name": "torso", "pivot": [0, 0.98, 0], "parent": "pose"},
                  {"name": "arm_r", "pivot": [0.26, 1.47, 0], "parent": "torso"},
                  {"name": "arm_l", "pivot": [-0.26, 1.47, 0], "parent": "torso"},
                  {"name": "leg_r", "pivot": [0.11, 0.94, 0], "parent": "pose"},
                  {"name": "leg_l", "pivot": [-0.11, 0.94, 0], "parent": "pose"}] + groups
    for g in groups:
        parent_pivot = pivots[g["parent"]] if g.get("parent") else [0, 0, 0]
        node = {"name": g["name"], "translation": [g["pivot"][i] - parent_pivot[i] for i in range(3)], "children": []}
        nodes.append(node)
        idx = len(nodes) - 1
        group_node[g["name"]] = idx
        pivots[g["name"]] = g["pivot"]
        nodes[group_node[g["parent"]] if g.get("parent") else 0]["children"].append(idx)

    for i, p in enumerate(model["parts"]):
        gp = pivots[p["group"]] if p.get("group") else [0, 0, 0]
        node = {"name": "%s_%d" % (p["mat"], i), "mesh": mesh_for(p["shape"], p["size"], p["mat"]),
                "translation": [p["pos"][j] - gp[j] for j in range(3)]}
        if p.get("rot"):
            node["rotation"] = list(quat_yxz(p["rot"]))
        if p.get("scale"):
            node["scale"] = p["scale"]
        nodes.append(node)
        nodes[group_node[p["group"]] if p.get("group") else 0]["children"].append(len(nodes) - 1)

    if model.get("lights"):
        used_ext.add("KHR_lights_punctual")
        lights = []
        for l in model["lights"]:
            lights.append({"type": "point", "color": _hex(l["color"]), "intensity": l["energy"] * 8, "range": l["range"]})
            nodes.append({"name": "light_%d" % (len(lights) - 1), "translation": l["pos"],
                          "extensions": {"KHR_lights_punctual": {"light": len(lights) - 1}}})
            nodes[0]["children"].append(len(nodes) - 1)
        gl.setdefault("extensions", {})["KHR_lights_punctual"] = {"lights": lights}

    if clips and "pose" in group_node:
        rest = model.get("rest_pose", {})
        anims = []
        for name, clip in clips.items():
            fps = 30
            n = max(2, int(round(clip["length"] * fps)) + 1)
            times = [clip["length"] * i / (n - 1) for i in range(n)]
            samples = [sample_clip(clip, t) for t in times]
            t_acc = buf.add("f", times, n, 5126, "SCALAR", None, ([0.0], [clip["length"]]))
            channels, samplers = [], []
            for ch, node_name in (("torso", "torso"), ("arm_r", "arm_r"), ("arm_l", "arm_l"),
                                  ("leg_r", "leg_r"), ("leg_l", "leg_l"), ("root", "pose")):
                if node_name not in group_node:
                    continue
                vals = []
                for smp in samples:
                    e = smp.get(ch, [0, 0, 0])
                    r = rest.get(ch, [0, 0, 0])
                    vals += list(quat_yxz([e[j] + r[j] for j in range(3)]))
                o_acc = buf.add("f", vals, n, 5126, "VEC4")
                samplers.append({"input": t_acc, "output": o_acc, "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": group_node[node_name], "path": "rotation"}})
            base = pivots["pose"]
            vals = []
            for smp in samples:
                vals += [base[0], base[1] + smp.get("root_y", 0.0) + rest.get("root_y", 0.0), base[2]]
            o_acc = buf.add("f", vals, n, 5126, "VEC3")
            samplers.append({"input": t_acc, "output": o_acc, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": group_node["pose"], "path": "translation"}})
            anims.append({"name": name, "channels": channels, "samplers": samplers})
        gl["animations"] = anims

    if used_ext:
        gl["extensionsUsed"] = sorted(used_ext)
    while len(buf.data) % 4:
        buf.data.append(0)
    gl["buffers"] = [{"byteLength": len(buf.data)}]
    gl["bufferViews"] = buf.views
    gl["accessors"] = buf.accessors

    js = json.dumps(gl, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(buf.data)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(buf.data), 0x004E4942))
        f.write(buf.data)
