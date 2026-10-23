# ARQUIVO GERADO por tools/gen_world_data.py a partir de tools/world_dump.json — não edite à mão.
# Para atualizar: cd server && go run ./cmd/worlddump > ../tools/world_dump.json && python3 tools/gen_world_data.py
extends RefCounted

## Zonas abertas na grade do mundo (col = leste, row = norte; cada célula tem 600 m).
const ZONES := {
	0: {"name": "Vila do Refúgio & Arredores", "col": 0, "row": 0},
	1: {"name": "Bosque Sussurrante / Floresta", "col": 0, "row": -1},
	2: {"name": "Ruínas da Vigília & Norte Gelado", "col": 0, "row": 2},
	3: {"name": "Santuário do Eclipse", "col": -1, "row": 0},
	4: {"name": "Fronteira das Cinzas", "col": 2, "row": 0},
	9: {"name": "Bosque Ralo", "col": 0, "row": -2},
	10: {"name": "Campos Rasteiros", "col": 0, "row": -3},
	11: {"name": "Savana Dourada", "col": 0, "row": -4},
	12: {"name": "Deserto de Sal Escaldante", "col": 0, "row": -5},
	13: {"name": "Planalto dos Ventos", "col": 0, "row": 1},
	14: {"name": "Picos Gelados", "col": 0, "row": 3},
	15: {"name": "Colinas de Basalto", "col": 1, "row": 0},
	16: {"name": "Pântano das Brumas", "col": -2, "row": 0},
}

## Portais entre zonas abertas: posição do portal na zona de origem.
const PORTALS := [
	{"id": 1, "from": 0, "to": 1, "x": 0.0, "z": -285.0, "name": "Portal Sul da Vila -> Floresta"},
	{"id": 2, "from": 1, "to": 0, "x": 0.0, "z": 285.0, "name": "Entrada Norte da Floresta -> Vila"},
	{"id": 3, "from": 0, "to": 13, "x": 0.0, "z": 285.0, "name": "Portal Norte da Vila -> Planalto dos Ventos"},
	{"id": 4, "from": 13, "to": 0, "x": 0.0, "z": -285.0, "name": "Entrada Sul do Planalto -> Vila"},
	{"id": 5, "from": 0, "to": 3, "x": -285.0, "z": 0.0, "name": "Portal Oeste da Vila -> Santuário"},
	{"id": 6, "from": 3, "to": 0, "x": 285.0, "z": 0.0, "name": "Entrada Leste do Santuário -> Vila"},
	{"id": 7, "from": 0, "to": 15, "x": 285.0, "z": 0.0, "name": "Portal Leste da Vila -> Colinas de Basalto"},
	{"id": 8, "from": 15, "to": 0, "x": -285.0, "z": 0.0, "name": "Entrada Oeste das Colinas -> Vila"},
	{"id": 17, "from": 13, "to": 2, "x": 0.0, "z": 285.0, "name": "Portal Norte do Planalto -> Ruínas"},
	{"id": 18, "from": 2, "to": 13, "x": 0.0, "z": -285.0, "name": "Entrada Sul das Ruínas -> Planalto"},
	{"id": 19, "from": 2, "to": 14, "x": 0.0, "z": 285.0, "name": "Portal Norte das Ruínas -> Picos Gelados"},
	{"id": 20, "from": 14, "to": 2, "x": 0.0, "z": -285.0, "name": "Entrada Sul dos Picos -> Ruínas"},
	{"id": 21, "from": 15, "to": 4, "x": 285.0, "z": 0.0, "name": "Portal Leste das Colinas -> Fronteira das Cinzas"},
	{"id": 22, "from": 4, "to": 15, "x": -285.0, "z": 0.0, "name": "Entrada Oeste das Cinzas -> Colinas"},
	{"id": 23, "from": 1, "to": 9, "x": 0.0, "z": -285.0, "name": "Portal Sul do Bosque -> Bosque Ralo"},
	{"id": 24, "from": 9, "to": 1, "x": 0.0, "z": 285.0, "name": "Entrada Norte do Bosque Ralo -> Bosque"},
	{"id": 25, "from": 9, "to": 10, "x": 0.0, "z": -285.0, "name": "Portal Sul do Bosque Ralo -> Campos Rasteiros"},
	{"id": 26, "from": 10, "to": 9, "x": 0.0, "z": 285.0, "name": "Entrada Norte dos Campos -> Bosque Ralo"},
	{"id": 27, "from": 10, "to": 11, "x": 0.0, "z": -285.0, "name": "Portal Sul dos Campos -> Savana Dourada"},
	{"id": 28, "from": 11, "to": 10, "x": 0.0, "z": 285.0, "name": "Entrada Norte da Savana -> Campos"},
	{"id": 29, "from": 11, "to": 12, "x": 0.0, "z": -285.0, "name": "Portal Sul da Savana -> Deserto de Sal"},
	{"id": 30, "from": 12, "to": 11, "x": 0.0, "z": 285.0, "name": "Entrada Norte do Deserto -> Savana"},
	{"id": 31, "from": 3, "to": 16, "x": -285.0, "z": 0.0, "name": "Portal Oeste do Santuário -> Pântano das Brumas"},
	{"id": 32, "from": 16, "to": 3, "x": 285.0, "z": 0.0, "name": "Entrada Leste do Pântano -> Santuário"},
]

## Covis de criaturas (perigo): as estradas passam longe deles, mesmo à noite.
const DANGERS := {
	1: [[-60.0, 200.0, 38.0, "Javali Selvagem"], [-42.0, 248.0, 38.0, "Javali Selvagem"], [-25.0, 215.0, 38.0, "Javali Selvagem"], [-15.0, 192.0, 38.0, "Javali Selvagem"], [8.0, 185.0, 38.0, "Javali Selvagem"], [20.0, 230.0, 38.0, "Javali Selvagem"], [38.0, 205.0, 38.0, "Javali Selvagem"], [55.0, -45.0, 38.0, "Lobo da Bruma"], [55.0, 175.0, 38.0, "Javali Selvagem"], [65.0, -52.0, 38.0, "Lobo da Bruma"], [75.0, -60.0, 38.0, "Lobo Alfa"], [88.0, -72.0, 55.0, "Licantropo Alfa"], [105.0, -100.0, 38.0, "Aranha Tecelã da Bruma"], [115.0, -110.0, 38.0, "Aranha Tecelã da Bruma"], [120.0, -120.0, 75.0, "Arachna, a Rainha Tecelã"]],
	2: [[-40.0, 130.0, 38.0, "Golem de Gelo Antigo"], [-15.0, 70.0, 38.0, "Saqueador Deserdado"], [-8.0, 80.0, 38.0, "Acólito do Eclipse"], [0.0, 90.0, 75.0, "Comandante Vaelen"], [0.0, 150.0, 75.0, "Ymir, o Patriarca Jotunar"], [0.0, 175.0, 55.0, "Draco de Geada Selvagem"], [8.0, 82.0, 38.0, "Executor de Ferro"], [15.0, 72.0, 38.0, "Besteiro da Vigília"], [40.0, 130.0, 38.0, "Golem de Gelo Antigo"]],
	3: [[-140.0, 140.0, 75.0, "Lorde Vesperian, o Progenitor Vampiro"], [-135.0, 135.0, 38.0, "Guarda Sanguinário de Vesperian"], [-125.0, 125.0, 38.0, "Guarda Sanguinário de Vesperian"], [-88.0, 88.0, 75.0, "Malakor, o Arauto do Eclipse"], [-85.0, 80.0, 55.0, "Inquisidor Vex"], [-80.0, 72.0, 38.0, "Cultista Sombrio"], [-78.0, 82.0, 38.0, "Gárgula de Pedra"], [-75.0, 75.0, 38.0, "Cultista Sombrio"]],
	9: [[-162.0, 102.0, 38.0, "Lobo da Bruma"], [-150.0, 90.0, 38.0, "Lobo da Bruma"], [-102.0, -170.0, 38.0, "Javali Selvagem"], [-90.0, -160.0, 38.0, "Javali Selvagem"], [60.0, 180.0, 38.0, "Javali Selvagem"], [190.0, -150.0, 38.0, "Lobo da Bruma"]],
	10: [[-212.0, -190.0, 38.0, "Saqueador Deserdado"], [-200.0, -200.0, 38.0, "Saqueador Deserdado"], [-182.0, 52.0, 38.0, "Javali Selvagem"], [-170.0, 40.0, 38.0, "Javali Selvagem"], [200.0, -60.0, 38.0, "Javali Selvagem"]],
	11: [[-200.0, -132.0, 38.0, "Lobo da Bruma"], [-190.0, -120.0, 55.0, "Lobo Alfa"], [-178.0, -110.0, 38.0, "Lobo da Bruma"], [220.0, 160.0, 38.0, "Javali Selvagem"], [232.0, 150.0, 38.0, "Javali Selvagem"]],
	12: [[-210.0, 170.0, 38.0, "Lodo Ácido Corrosivo"], [-160.0, -60.0, 38.0, "Escorpião Abissal Gigante"], [140.0, -190.0, 38.0, "Escorpião Abissal Gigante"], [170.0, 90.0, 38.0, "Escorpião Abissal Gigante"]],
	13: [[-192.0, 140.0, 38.0, "Besteiro da Vigília"], [-180.0, 120.0, 38.0, "Saqueador Deserdado"], [-168.0, 132.0, 38.0, "Saqueador Deserdado"], [210.0, -150.0, 38.0, "Besteiro da Vigília"]],
	14: [[-150.0, 60.0, 38.0, "Golem de Gelo Antigo"], [-60.0, 230.0, 55.0, "Draco de Geada Selvagem"], [200.0, -40.0, 38.0, "Golem de Gelo Antigo"]],
	15: [[-40.0, -200.0, 38.0, "Gárgula de Pedra"], [60.0, 190.0, 38.0, "Gárgula de Pedra"], [180.0, -170.0, 38.0, "Executor de Ferro"]],
	16: [[-190.0, 170.0, 38.0, "Aranha Tecelã da Bruma"], [-178.0, 182.0, 38.0, "Aranha Tecelã da Bruma"], [-120.0, -60.0, 38.0, "Lodo Ácido Corrosivo"], [80.0, 150.0, 38.0, "Lodo Ácido Corrosivo"], [150.0, -180.0, 38.0, "Aranha Tecelã da Bruma"]],
}

## Rio Prateado (mesma fórmula de server/internal/world/river.go).
const RIVER_SOURCE_GZ := 1950.0
const RIVER_MOUTH_GZ := -2370.0
const RIVER_MOUTH_LAKE_R := 75.0
const ZONE_SPAN := 600.0
