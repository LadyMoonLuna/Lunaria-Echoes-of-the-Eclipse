#!/usr/bin/env python3
"""Gera os modelos 3D das raças a partir de races.py.

Saídas:
  client/scripts/models/RaceModelData.gd   -> dados consumidos por RaceModel.gd (Godot)
  docs/previews/racas_3d_preview.html      -> preview web interativo (mesmos dados)

Uso:  python3 tools/race_models/build.py
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

from races import ALL  # noqa: E402

GD_OUT = os.path.join(REPO, "client", "scripts", "models", "RaceModelData.gd")
HTML_TEMPLATE = os.path.join(HERE, "preview_template.html")
HTML_OUT = os.path.join(REPO, "docs", "previews", "racas_3d_preview.html")


def main():
    models = [fn().to_dict() for fn in ALL]
    data = {str(m["id"]): m for m in models}

    os.makedirs(os.path.dirname(GD_OUT), exist_ok=True)
    with open(GD_OUT, "w", encoding="utf-8") as f:
        f.write("# ARQUIVO GERADO por tools/race_models/build.py — não edite à mão.\n")
        f.write("# Edite tools/race_models/races.py e rode o build novamente.\n")
        f.write("extends RefCounted\n\n")
        f.write("const MODELS := {\n")
        for key, model in data.items():
            f.write('\t"%s": %s,\n' % (key, json.dumps(model, ensure_ascii=False, separators=(",", ":"))))
        f.write("}\n")

    with open(HTML_TEMPLATE, encoding="utf-8") as f:
        html = f.read()
    html = html.replace("/*__RACE_DATA__*/null", json.dumps(models, ensure_ascii=False, separators=(",", ":")))
    os.makedirs(os.path.dirname(HTML_OUT), exist_ok=True)
    with open(HTML_OUT, "w", encoding="utf-8") as f:
        f.write(html)

    for m in models:
        print("  #%d %-20s %3d partes, %2d grupos, %2d materiais" % (
            m["id"], m["name"], len(m["parts"]), len(m["groups"]), len(m["materials"])))
    print("OK ->", os.path.relpath(GD_OUT, REPO), "e", os.path.relpath(HTML_OUT, REPO))


if __name__ == "__main__":
    main()
