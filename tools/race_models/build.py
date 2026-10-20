#!/usr/bin/env python3
"""Gera todos os modelos 3D de Lunaria a partir das fontes em Python.

Saídas:
  client/scripts/models/LunariaModelData.gd  -> dados consumidos por LunariaModel.gd (Godot)
  client/assets/models/<tipo>/<nome>.glb      -> arquivos glTF binários (Blender / Godot / Mixamo)
  docs/previews/racas_3d_preview.html         -> preview web interativo (mesmos dados)

Uso:  python3 tools/race_models/build.py [--no-glb]
"""

import base64
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

from clips import CLIPS  # noqa: E402
from gear import LOADOUTS, OUTFITS, WEAPONS  # noqa: E402
from gltf import export_glb  # noqa: E402
from mobs import MOBS  # noqa: E402
from npcs import NPCS  # noqa: E402
from races import ALL as LEGENDARY  # noqa: E402
from races_base import ALL_BASE  # noqa: E402
from texmap import assign  # noqa: E402

GD_OUT = os.path.join(REPO, "client", "scripts", "models", "LunariaModelData.gd")
GLB_DIR = os.path.join(REPO, "client", "assets", "models")
TEX_DIR = os.path.join(REPO, "client", "assets", "textures")
HTML_TEMPLATE = os.path.join(HERE, "preview_template.html")
HTML_OUT = os.path.join(REPO, "docs", "previews", "racas_3d_preview.html")
GLB_FOLDERS = {"race": "races", "npc": "npcs", "mob": "mobs", "weapon": "weapons", "companion": "weapons", "outfit": "outfits"}


def _dump(v):
    return json.dumps(v, ensure_ascii=False, separators=(",", ":"))


def _preview_textures(models):
    """Texturas usadas, em JPEG leve (data URI), para embutir no preview web."""
    from PIL import Image
    used = sorted({s["tex"] for m in models for s in m["materials"].values() if "tex" in s})
    out = {}
    for name in used:
        entry = {}
        for kind, q in (("albedo", 82), ("normal", 90)):
            img = Image.open(os.path.join(TEX_DIR, "%s_%s.png" % (name, kind))).convert("RGB")
            bio = io.BytesIO()
            img.save(bio, "JPEG", quality=q)
            entry[kind] = "data:image/jpeg;base64," + base64.b64encode(bio.getvalue()).decode()
        out[name] = entry
    return out


def main():
    races = sorted((fn().to_dict() for fn in ALL_BASE + LEGENDARY), key=lambda d: d["id"])
    models = races + [fn().to_dict() for fn in NPCS] + [fn().to_dict() for fn in MOBS] + \
        [fn().to_dict() for fn in WEAPONS] + [fn().to_dict() for fn in OUTFITS]
    plain = assign(models)
    by_uid = {m["uid"]: m for m in models}
    assert len(by_uid) == len(models), "uid duplicado"
    for cls, lo in LOADOUTS.items():
        for slot in ("hand_r", "hand_l"):
            if slot in lo:
                assert lo[slot]["weapon"] in by_uid, lo[slot]["weapon"]
        assert lo["outfit"] in by_uid, lo["outfit"]
        assert lo.get("companion", "weapon_iron_dagger") in by_uid
        for clip in lo["actions"].values():
            assert clip in CLIPS, clip
    for m in models:
        for h in (m.get("gear") or {}).values():
            assert h["weapon"] in by_uid, (m["uid"], h["weapon"])

    os.makedirs(os.path.dirname(GD_OUT), exist_ok=True)
    with open(GD_OUT, "w", encoding="utf-8") as f:
        f.write("# ARQUIVO GERADO por tools/race_models/build.py — não edite à mão.\n")
        f.write("# Edite as fontes em tools/race_models/ e rode o build novamente.\n")
        f.write("extends RefCounted\n\n")
        f.write("const MODELS := {\n")
        for uid, model in by_uid.items():
            f.write('\t"%s": %s,\n' % (uid, _dump(model)))
        f.write("}\n\n")
        f.write("const CLIPS := %s\n\n" % _dump(CLIPS))
        f.write("const LOADOUTS := %s\n" % _dump(LOADOUTS))

    with open(HTML_TEMPLATE, encoding="utf-8") as f:
        html = f.read()
    payload = {"models": models, "clips": CLIPS, "loadouts": LOADOUTS}
    html = html.replace("/*__LUNARIA_DATA__*/null", _dump(payload))
    html = html.replace("/*__LUNARIA_TEX__*/null", _dump(_preview_textures(models)))
    os.makedirs(os.path.dirname(HTML_OUT), exist_ok=True)
    with open(HTML_OUT, "w", encoding="utf-8") as f:
        f.write(html)

    if "--no-glb" not in sys.argv:
        for m in models:
            folder = os.path.join(GLB_DIR, GLB_FOLDERS[m["kind"]])
            os.makedirs(folder, exist_ok=True)
            name = m["key"] if m["kind"] in ("weapon", "companion", "outfit") else "%02d_%s" % (m["id"], m["key"]) \
                if m["kind"] == "race" else "%d_%s" % (m["id"], m["key"])
            export_glb(m, os.path.join(folder, name + ".glb"), CLIPS if m["kind"] in ("race", "npc", "mob") else None,
                       tex_dir=TEX_DIR)

    counts = {}
    for m in models:
        counts[m["kind"]] = counts.get(m["kind"], 0) + 1
    print("Modelos:", ", ".join("%s=%d" % kv for kv in sorted(counts.items())),
          "| clipes:", len(CLIPS), "| classes:", len(LOADOUTS))
    textured = sum(1 for m in models for s in m["materials"].values() if "tex" in s)
    print("Materiais com textura: %d | lisos (efeitos, olhos, brilhos): %d" % (textured, len(plain)))
    print("OK ->", os.path.relpath(GD_OUT, REPO), ",", os.path.relpath(HTML_OUT, REPO),
          "e", os.path.relpath(GLB_DIR, REPO))


if __name__ == "__main__":
    main()
