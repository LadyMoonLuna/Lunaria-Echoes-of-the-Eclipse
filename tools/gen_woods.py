"""Gera server/internal/world/catalog_woods_data.go: as árvores de Lunaria e seus subprodutos.

Cada madeira tem Tronco, Seiva, Galhos, Folhas e (algumas) Frutos. IDs estáveis: 5000 + índice × 5 + produto
(0 tronco, 1 seiva, 2 galhos, 3 folhas, 4 fruto). Raridades: 1 Comum, 2 Incomum, 3 Rara, 4 Épica, 5 Única,
9 Transcendente (só a Yggdrasil, que não pode ser cortada; seus subprodutos são Míticos).

Uso: python3 tools/gen_woods.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Zonas: 0 Vila, 1 Bosque, 2 Ruínas/Norte Gelado, 3 Santuário, 4 Fronteira das Cinzas, 8 Esgotos, 9 Bosque Ralo,
# 10 Campos, 11 Savana, 12 Deserto de Sal, 13 Planalto dos Ventos, 14 Picos Gelados, 15 Colinas de Basalto, 16 Pântano
TEMPERATE = [0, 1, 9, 10, 13]
COLD = [2, 13, 14]
DRY = [11, 12]
WARM = [10, 11]
ASH = [4, 15]
MARSH = [16, 9]

# (nome, raridade, zonas, fruto ou "", cor da folha, cor do tronco, (térmica, elétrica, mágica))
WOODS = [
    # 20 Comuns
    ("Abeto-Branco", 1, COLD + [1], "", "#3c6b4a", "#6e5a44", (30, 5, 20)),
    ("Faia-Comum", 1, TEMPERATE, "Faias (Nozes de Faia)", "#5f8f3a", "#8a7560", (35, 5, 15)),
    ("Bétula-Prateada", 1, [1, 2, 13, 9], "", "#8db35a", "#e8e4dc", (25, 10, 30)),
    ("Carvalho-Roble", 1, TEMPERATE, "Bolotas", "#3f7a34", "#5b4330", (40, 5, 20)),
    ("Castanheiro", 1, [0, 1, 9], "Castanhas", "#4f8a3a", "#6b4a2a", (35, 5, 15)),
    ("Nogueira", 1, [0, 9, 10], "Nozes", "#55803c", "#5a4026", (35, 5, 20)),
    ("Macieira-Brava", 1, [0, 9, 10], "Maçã-Brava", "#5c9a42", "#6e5236", (30, 5, 25)),
    ("Pereira-Silvestre", 1, [0, 10, 13], "Pera-Silvestre", "#64a048", "#6a5034", (30, 5, 25)),
    ("Ameixeira", 1, [0, 9], "Ameixa", "#5a8d3e", "#5e4032", (30, 5, 25)),
    ("Cerejeira-Brava", 1, [0, 1, 13], "Cereja-Brava", "#c0607a", "#6b3f35", (30, 5, 35)),
    ("Choupo", 1, [10, 13, 16], "", "#7aa84e", "#b0a58e", (20, 10, 15)),
    ("Olmo", 1, TEMPERATE, "", "#4a7f36", "#6a5444", (40, 5, 15)),
    ("Tília", 1, [0, 1, 9], "Flores de Tília", "#8fbf4a", "#7a6650", (25, 5, 35)),
    ("Freixo-Comum", 1, TEMPERATE, "", "#5a8a40", "#a08b70", (35, 10, 20)),
    ("Plátano", 1, [0, 10], "", "#6a9a44", "#a89878", (30, 5, 15)),
    ("Acácia-Dourada", 1, WARM + [12], "Vagens de Acácia", "#a8a83a", "#7a5a34", (55, 5, 20)),
    ("Pinheiro-Manso", 1, [9, 10, 13], "Pinhão", "#2f6237", "#5b4330", (45, 5, 15)),
    ("Laranjeira-Amarga", 1, [10, 11], "Laranja-Amarga", "#3e7a30", "#6a5236", (35, 5, 25)),
    ("Figueira", 1, DRY + [10], "Figo", "#4f7a34", "#8a7a66", (40, 5, 25)),
    ("Oliveira", 1, DRY + [13], "Azeitona", "#7a8a5a", "#7a6a50", (45, 5, 25)),
    # 15 Incomuns
    ("Teixo", 2, [1, 2, 9], "Bagas de Teixo", "#2a5a34", "#7a3a2a", (35, 15, 45)),
    ("Cedro-Vermelho", 2, [1, 13, 2], "", "#365f38", "#8a3e2a", (45, 10, 30)),
    ("Mogno-Silvestre", 2, [9, 11], "", "#4a7036", "#7a3424", (50, 10, 25)),
    ("Sândalo", 2, [11, 3], "", "#5a7a46", "#b08a5a", (35, 10, 55)),
    ("Cipreste-dos-Pântanos", 2, MARSH, "", "#3a5a3a", "#6a5848", (30, 15, 35)),
    ("Sequoia-Jovem", 2, [1, 14, 13], "", "#2f5a34", "#8a4a32", (40, 10, 30)),
    ("Baobá", 2, DRY, "Fruto de Baobá", "#7a8a3a", "#9a8a72", (60, 5, 30)),
    ("Tamarindeiro", 2, WARM, "Tamarindo", "#5a8a3a", "#6a5034", (50, 5, 30)),
    ("Romãzeira", 2, [10, 11, 0], "Romã", "#5a8040", "#6a4a34", (40, 10, 40)),
    ("Sabugueiro", 2, [0, 9, 16], "Bagas de Sabugueiro", "#5a8a44", "#8a7a64", (25, 10, 45)),
    ("Zimbro", 2, COLD + [13], "Bagas de Zimbro", "#3a6a4a", "#7a5a44", (30, 10, 40)),
    ("Bordo-de-Açúcar", 2, [1, 2, 13], "", "#c0602a", "#7a6048", (35, 10, 35)),
    ("Pau-Brasil", 2, [11, 9], "", "#4a7a34", "#a03a2a", (45, 10, 35)),
    ("Ébano-Pálido", 2, [3, 8], "", "#4a5a4a", "#3a3434", (40, 15, 50)),
    ("Mangueira-Selvagem", 2, [11, 16], "Manga-Selvagem", "#3a7a34", "#6a5034", (45, 5, 30)),
    # 10 Raras
    ("Pau-Ferro Negro", 3, ASH, "", "#3a4a3a", "#2a2626", (75, 15, 30)),
    ("Ébano-da-Meia-Noite", 3, [3, 8], "", "#2a3a4a", "#141418", (35, 20, 75)),
    ("Pau-Rosa", 3, [11, 16], "", "#5a7a4a", "#b06070", (40, 15, 55)),
    ("Jacarandá-Lunar", 3, [3, 13], "Vagens Lunares", "#8a7ad0", "#4a3a5a", (30, 25, 80)),
    ("Cedro-das-Brumas", 3, [1, 16], "", "#5a7a7a", "#6a6a70", (30, 20, 65)),
    ("Salgueiro-Chorão-de-Prata", 3, MARSH + [2], "", "#a8c0b8", "#c0c0c8", (25, 30, 70)),
    ("Árvore-do-Sangue", 3, [3, 4], "Fruto Rubro", "#8a1a1a", "#4a1414", (55, 15, 70)),
    ("Pinheiro-de-Gelo", 3, [14, 2], "Pinha Gélida", "#a0d0e8", "#8aa0b0", (5, 20, 60)),
    ("Palmeira-de-Fogo", 3, ASH + [12], "Coco Ígneo", "#d06a2a", "#7a4a2a", (95, 15, 45)),
    ("Carvalho-Trovejante", 3, [13, 15], "Bolotas Elétricas", "#4a6a8a", "#4a4050", (40, 85, 40)),
    # 5 Épicas
    ("Freixo-Estelar", 4, [3, 13], "Fruto Estelar", "#9ab0ff", "#c8c8e0", (40, 45, 90)),
    ("Sequoia-Ancestral", 4, [1, 14], "", "#2a5030", "#6a3424", (55, 20, 70)),
    ("Árvore-de-Cristal", 4, [3, 2], "Fruta-Cristal", "#b0e8ff", "#d8f0ff", (20, 60, 95)),
    ("Cerejeira-Eclipse", 4, [3, 8], "Cereja Negra", "#4a1a4a", "#2a1a2a", (35, 35, 95)),
    ("Teixo-do-Vazio", 4, [8, 4], "Bagas do Vazio", "#2a1a3a", "#1a1424", (30, 40, 98)),
    # 3 Únicas
    ("Árvore-da-Aurora", 5, [13], "Fruto da Aurora", "#ffb070", "#e8c8a0", (60, 60, 98)),
    ("Árvore-Espelho-Lunar", 5, [3], "Fruto Lunar", "#e0e8ff", "#b8c0d8", (25, 50, 100)),
    ("Árvore-Fênix", 5, [4], "Fruto Fênix", "#ff6a2a", "#8a2a1a", (100, 40, 95)),
    # 1 Transcendente
    ("Yggdrasil", 9, [], "Fruto de Yggdrasil", "#7fe0a0", "#6a5038", (70, 70, 100)),
]

WEIGHTS = {1: 5, 2: 3, 3: 2, 4: 1, 5: 1}


def main():
    counts = {}
    for w in WOODS:
        counts[w[1]] = counts.get(w[1], 0) + 1
    assert counts == {1: 20, 2: 15, 3: 10, 4: 5, 5: 3, 9: 1}, counts
    lines = [
        "// ARQUIVO GERADO por tools/gen_woods.py — não edite à mão.",
        "package world",
        "",
        "// WoodCatalog: madeiras de Lunaria (ver catalog_woods.go).",
        "var WoodCatalog = []WoodDef{",
    ]
    for i, (name, rar, zones, fruit, leaf, bark, cond) in enumerate(WOODS):
        z = ", ".join(str(x) for x in zones)
        lines.append('\t{%d, "%s", %d, []uint8{%s}, "%s", "%s", "%s", %d, %d, %d, %d},' % (
            i, name, rar, z, fruit, leaf, bark, cond[0], cond[1], cond[2], WEIGHTS.get(rar, 0)))
    lines.append("}")
    out = ROOT / "server/internal/world/catalog_woods_data.go"
    out.write_text("\n".join(lines) + "\n")
    print("escrito", out, len(WOODS), "madeiras")


if __name__ == "__main__":
    main()
