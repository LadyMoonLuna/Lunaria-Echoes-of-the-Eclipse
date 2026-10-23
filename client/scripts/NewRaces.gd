extends RefCounted
## Raças 29–45 (docs/design/racas_propostas.md). Números iguais a server/internal/world/races_new.go.
## Usado pelo menu de raças (F10), pela seleção de personagem e pelas cores de aura.

const DATA := {
	29: {"name": "Orc", "group": "BASE", "color": Color("#558b2f"), "stats": [10, 5, 9, 5, 3, 5, 7, 6],
		"lore": "Clãs guerreiros das estepes cinzentas. Pele verde-musgo, presas e cicatrizes de honra.",
		"passive": "Pele Grossa: -8% de dano recebido e +12% de dano corpo a corpo.",
		"skill_z": "Fúria de Sangue [Z]: Cura 15% da Vida e ativa o buff de combate por 8s (Recarga: 25s)."},
	30: {"name": "Goblin", "group": "BASE", "color": Color("#9ccc65"), "stats": [4, 10, 5, 10, 4, 4, 5, 8],
		"lore": "Pequenos, espertos e gananciosos. Mestres de armadilhas e fugas impossíveis.",
		"passive": "Sorte do Trapaceiro: alta Sorte e Agilidade, Stamina farta.",
		"skill_z": "Bomba de Fumaça [Z]: 1s de invulnerabilidade, dano e lentidão em 3,5m (Recarga: 30s)."},
	31: {"name": "Elfo", "group": "BASE", "color": Color("#81c784"), "stats": [4, 9, 5, 9, 8, 6, 5, 4],
		"lore": "Guardiões das florestas antigas. Olhos aguçados e longevidade de séculos.",
		"passive": "Graça Élfica: +8% de dano total.",
		"skill_z": "Flecha Precisa [Z]: Disparo de longo alcance (12m) (Recarga: 12s)."},
	32: {"name": "Elfo Solar", "group": "EVOLUTION", "color": Color("#ffca28"), "stats": [11, 10, 8, 10, 7, 9, 8, 7],
		"lore": "Evolução élfica abençoada pelo sol. Cabelos de ouro e armadura radiante.",
		"passive": "Bênção do Sol: +12% de dano durante o dia.",
		"skill_z": "Lança do Sol [Z]: Buff de 20s e cone de fogo solar de 8m (Recarga: 40s)."},
	33: {"name": "Elfo Lunar", "group": "EVOLUTION", "color": Color("#90caf9"), "stats": [8, 13, 6, 13, 9, 7, 8, 6],
		"lore": "Evolução élfica guiada pela lua. Sombras prateadas e passos silenciosos.",
		"passive": "Bênção da Lua: +12% de dano à noite.",
		"skill_z": "Véu Lunar [Z]: Lentidão de 50% e dano em 6m (Recarga: 35s)."},
	34: {"name": "Drago da Terra", "group": "SECRET", "color": Color("#8d6e63"), "stats": [11, 4, 13, 4, 3, 6, 9, 8],
		"lore": "Dracônico de escamas de pedra. Lento, mas quase impossível de derrubar.",
		"passive": "Escamas de Rocha: -20% de dano recebido. Último Fôlego: revive com 20% (20 min).",
		"skill_z": "Abraço da Terra [Z]: Puxa inimigos em 6m, causa dano e cura 15% (Recarga: 30s)."},
	35: {"name": "Drago da Água", "group": "SECRET", "color": Color("#29b6f6"), "stats": [8, 10, 9, 8, 6, 7, 6, 4],
		"lore": "Dracônico das marés. Escamas azul-turquesa e barbatanas nos braços.",
		"passive": "Fluxo das Marés: +15% de dano (+10% na chuva). Último Fôlego.",
		"skill_z": "Maré Curativa [Z]: Cura 12% (24% na chuva) (Recarga: 8s)."},
	36: {"name": "Drago do Raio", "group": "SECRET", "color": Color("#ffee58"), "stats": [5, 11, 6, 11, 9, 6, 5, 5],
		"lore": "Dracônico da tempestade. Faíscas correm pelos chifres a cada passo.",
		"passive": "Carga Estática: +10% de dano. Último Fôlego.",
		"skill_z": "Relâmpago [Z]: Buff de 6s e raio de 12m que atordoa 1s (Recarga: 20s)."},
	37: {"name": "Drago Místico", "group": "SECRET", "color": Color("#ab47bc"), "stats": [3, 5, 5, 6, 13, 12, 8, 6],
		"lore": "Dracônico arcano, nascido de cristais de mana. Runas brilham nas escamas.",
		"passive": "Sangue Arcano: +15% de dano. Último Fôlego.",
		"skill_z": "Ruptura Arcana [Z]: Explosão arcana de 7m (Recarga: 40s)."},
	38: {"name": "Pyromante", "group": "SECRET", "color": Color("#ff5722"), "stats": [6, 7, 6, 7, 11, 9, 6, 6],
		"lore": "Humano que fez pacto com a chama. A pele racha em brasas quando se enfurece.",
		"passive": "Chama Interior: +12% de dano (-15% na chuva). Renascer das Cinzas: revive com 20% (20 min).",
		"skill_z": "Combustão Interna [Z]: Gasta 40% da Vida, buff de 15s e explosão de 7m (Recarga: 60s)."},
	39: {"name": "Escorpião", "group": "NEW", "color": Color("#bf8f00"), "stats": [7, 11, 8, 10, 4, 4, 9, 5],
		"lore": "Demi-humano dos desertos. Carapaça âmbar e cauda com ferrão venenoso.",
		"passive": "Carapaça do Deserto: Destreza e Percepção altas.",
		"skill_z": "Ferrão Tóxico [Z]: Gasta 20% da Vida, veneno e lentidão em 5m (Recarga: 45s)."},
	40: {"name": "Tartaruga", "group": "NEW", "color": Color("#2e7d32"), "stats": [8, 3, 15, 3, 5, 8, 10, 6],
		"lore": "Demi-humano de casco milenar. Paciente, sábio e inabalável.",
		"passive": "Casco Ancestral: -15% de dano recebido.",
		"skill_z": "Carapaça [Z]: -70% de dano por 6s e cura 18% (Recarga: 20s)."},
	41: {"name": "Fadinha", "group": "NEW", "color": Color("#f48fb1"), "stats": [2, 9, 3, 11, 13, 11, 4, 5],
		"lore": "Minúscula e brilhante, com asas de cristal. Frágil, mas cheia de magia.",
		"passive": "Asas de Cristal: +15% de dano, mas +10% de dano recebido.",
		"skill_z": "Pó de Fada [Z]: Cura 10% (grupo em 7m) e lentidão em 5m (Recarga: 30s)."},
	42: {"name": "Meio-Celestial", "group": "NEW", "color": Color("#fff59d"), "stats": [6, 6, 7, 7, 8, 12, 6, 6],
		"lore": "Filho de um anjo e de um mortal. Halo tênue e asas de penas brancas.",
		"passive": "Graça Celeste: +12% de dano.",
		"skill_z": "Bênção Celeste [Z]: Buff de 12s, cura 15% e cura aliados em 7m (Recarga: 60s)."},
	43: {"name": "Gigante de Gelo", "group": "NEW", "color": Color("#b3e5fc"), "stats": [14, 5, 16, 4, 5, 8, 10, 8],
		"lore": "Colosso das montanhas geladas. Barba de gelo e pele azul-pálida.",
		"passive": "Sangue Glacial: -12% de dano recebido e +12% de dano à noite ou na névoa.",
		"skill_z": "Inverno Eterno [Z]: Buff de 30s, congela 2s e dano em 6m (Recarga: 45s)."},
	44: {"name": "Súcubo", "group": "NEW", "color": Color("#d81b60"), "stats": [6, 11, 7, 11, 11, 7, 6, 11],
		"lore": "Meio-demônio sedutora. Chifres, asas de morcego e cauda em ponta de coração.",
		"passive": "Encanto Infernal: Sorte e Inteligência altas.",
		"skill_z": "Beijo Drenante [Z]: Atordoa um alvo a 10m por 2s e cura 8% (Recarga: 45s)."},
	45: {"name": "Manamante", "group": "SECRET", "color": Color("#3d5afe"), "stats": [3, 6, 8, 6, 13, 11, 7, 4],
		"lore": "Seu sangue é mana pura e azul. Conjura com a própria Vida.",
		"passive": "Sangue Azul: Mana e Vida são uma só reserva (+18% de dano).",
		"skill_z": "Coração de Mana [Z]: Gasta 15% da Vida numa explosão arcana de 7m (Recarga: 20s)."},
}

const STAT_NAMES := ["FOR", "DES", "CON", "AGI", "INT", "ESP", "PER", "SOR"]

static func has(race_id: int) -> bool:
	return DATA.has(race_id)

static func color(race_id: int, fallback: Color = Color("#ffd700")) -> Color:
	return DATA[race_id]["color"] if DATA.has(race_id) else fallback

static func stats_text(race_id: int) -> String:
	var parts: Array[String] = []
	var s: Array = DATA[race_id]["stats"]
	for i in STAT_NAMES.size():
		parts.append("%s: %d" % [STAT_NAMES[i], s[i]])
	return " | ".join(parts)

## Entradas no formato do menu de raças (DevRaceMenuUI).
static func dev_entries() -> Array:
	var out: Array = []
	for rid in DATA.keys():
		var d: Dictionary = DATA[rid]
		out.append({
			"id": rid, "group": d["group"], "name": d["name"], "badge": "✨ Raça %d" % rid,
			"color": d["color"], "lore": d["lore"], "stats": stats_text(rid),
			"passive": d["passive"], "skill_z": d["skill_z"],
		})
	return out
