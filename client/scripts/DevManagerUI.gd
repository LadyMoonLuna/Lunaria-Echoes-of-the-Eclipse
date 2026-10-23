extends Control
class_name DevManagerUI

# Painel Unificado de Desenvolvimento (Tecla F10)
# Gerencia Raças, Classes, Mundo/Lua/Clima, Drops, Bestiário e Teleportes.

# ==============================================================================
# DEV MANAGER UNIFICADO (F10) — LUNARIA: ECHOES OF THE ECLIPSE
# ==============================================================================
# Janela centralizada com 6 Abas (TabContainer) para controle de:
# 1. Raças (28 Linhagens)
# 2. Classes & Nível (15 Classes + Tiers 1-6 + Painel de Nível Rápido)
# 3. Mundo, Lua & Clima (Relógio, 10 Luas e 4 Climas via Pacote TCP 0x22)
# 4. Drops & Itens (Kit 12 Slots, Categorias de Itens e Chances de Drop)
# 5. Bestiário (12 Criaturas, Bosses, Status, Táticas e Drops Rápidos)
# 6. Teleportes & Ferramentas Extras (7 Zonas, Autópsia Teste e Monitor de Provações)
# ==============================================================================

var is_open: bool = false
var selected_tier: int = 1 # 1=Comum, 2=Incomum, 3=Rara, 4=Épica, 5=Única, 6=Lendária

# Provações Secretas (Trials Tracker)
var untouched_kills: int = 0
var low_hp_kills: int = 0
var perfect_autopsies_streak: int = 0

var status_label: Label = null
var tab_container: TabContainer = null
var trials_label: Label = null
var tier_buttons: Array[Button] = []
var canvas_layer: CanvasLayer = null

const TIER_NAMES := ["", "Comum (T1)", "Incomum (T2)", "Rara (T3)", "Épica (T4)", "Única (T5)", "Lendária (T6)"]
const TIER_COLORS := [
	Color(1, 1, 1),
	Color("#b0bec5"), # T1 Comum
	Color("#66bb6a"), # T2 Incomum
	Color("#42a5f5"), # T3 Rara
	Color("#ab47bc"), # T4 Épica
	Color("#ffa726"), # T5 Única
	Color("#ffd700")  # T6 Lendária
]

# ------------------------------------------------------------------------------
# BANCO DE DADOS: 12 CLASSES BÁSICAS + 9 CLASSES SECRETAS ÚNICAS (19 A 27) & HABILIDADES
# ------------------------------------------------------------------------------
const CLASSES_DEV_DATA := [
	{
		"id": 1,
		"name": "Guerreiro",
		"desc": "Combatente com espada. [Passiva] Sangue de Batalha (+15% Defesa, +10% Dano com Espadas).",
		"passive": "Sangue de Batalha (+15% Defesa Física e +10% Dano com Espadas)",
		"skill_q": "Corte Duplo (1.8x dano + sangramento)",
		"skill_r": "Investida Imparável (Dash 6m empurra e quebra postura)",
		"skill_f": "Julgamento da Espada (2.6x dano sísmico 4.5m; +40% em alvos <35% HP)",
		"color": Color("#4fc3f7")
	},
	{
		"id": 2,
		"name": "Mago",
		"desc": "Conjurador arcano com cajado/orbe. [Passiva] Ressonância Arcana (+20% Mágico e Mana).",
		"passive": "Ressonância Arcana (+20% Dano Mágico e regeneração contínua de Mana)",
		"skill_q": "Orbe de Magma (1.9x dano de fogo a 18m em área)",
		"skill_r": "Prisão Glacial (Congela e empurra em 5m por 2s)",
		"skill_f": "Chuva de Meteoros (2.8x dano arcano/fogo em raio de 6m)",
		"color": Color("#ba68c8")
	},
	{
		"id": 3,
		"name": "Arqueiro",
		"desc": "Atirador ágil de precisão à distância. [Passiva] Olho de Falcão (+20% Crítico, +12% Vel).",
		"passive": "Olho de Falcão (+20% Taxa Crítica à distância e +12% Velocidade)",
		"skill_q": "Tiro Perfurante (1.85x dano perfurante a 24m)",
		"skill_r": "Salto Acrobático (Mortal para trás disparando flecha que prende por 2s)",
		"skill_f": "Tempestade de Mil Flechas (2.6x dano em área de 6m)",
		"color": Color("#81c784")
	},
	{
		"id": 4,
		"name": "Assassino",
		"desc": "Lâmina dupla letal e passos furtivos. [Passiva] Lâmina Silenciosa (+35% Crítico costas, +15% Esquiva).",
		"passive": "Lâmina Silenciosa (+35% Dano Crítico pelas costas e +15% Esquiva)",
		"skill_q": "Passo das Sombras (Teleporta para as costas com 1.9x dano + veneno)",
		"skill_r": "Cortina de Fumaça (Furtivo/intangível por 2.5s e +30% velocidade)",
		"skill_f": "Lótus de Sangue (8 cortes letais em 4m com 2.7x dano e hemorragia)",
		"color": Color("#e57373")
	},
	{
		"id": 5,
		"name": "Lutador",
		"desc": "Mestre dos punhos pesados de Chi. [Passiva] Punhos de Ferro & Chi (ignora 25% armadura).",
		"passive": "Punhos de Ferro & Chi (Ignora 25% armadura, escudo a cada 3 socos)",
		"skill_q": "Gancho Demolidor (Soco explosivo de Chi com 1.85x dano e atordoamento)",
		"skill_r": "Postura do Lótus Marcial (Purifica debuffs, cura +40 HP, -50% dano por 3s)",
		"skill_f": "Meteoro de Um Punho (Cratera sísmica de 5.5m com 2.75x dano)",
		"color": Color("#ffb74d")
	},
	{
		"id": 6,
		"name": "Escudeiro",
		"desc": "Defensor colossal com escudo e maça. [Passiva] Fortaleza Viva (+35% Defesa Total).",
		"passive": "Fortaleza Viva (+35% Defesa Total, reflete 20% dano e converte Defesa em Ataque)",
		"skill_q": "Esmagamento de Bastião (1.7x dano e Taunt em monstros em 8m)",
		"skill_r": "Formação Impenetrável (Bloqueia 80% do dano por 4s e concede escudo aos aliados)",
		"skill_f": "Cidadela Inabalável (Cúpula dourada, cura +70 HP e impede mortes por 4s)",
		"color": Color("#fff176")
	},
	{
		"id": 7,
		"name": "Ferreiro",
		"desc": "Mestre da forja com martelo colossal estilo Overgeared. [Passiva] Orgulho do Criador (+25% Dano).",
		"passive": "Orgulho do Criador (Equipamentos nunca quebram, +25% dano com armas forjadas)",
		"skill_q": "Golpe da Bigorna Incandescente (1.85x dano fogo/físico, racha 30% armadura)",
		"skill_r": "Afiação & Têmpera em Campo (Repara armas e +25% Ataque e Defesa por 10s)",
		"skill_f": "Dança do Arsenal Forjado (4 armas espectrais girando em 5.5m com 2.7x dano)",
		"color": Color("#ff9800")
	},
	{
		"id": 8,
		"name": "Alquimista",
		"desc": "Especialista químico em catalisadores e frascos. [Passiva] Reação Sintética (+35% poções).",
		"passive": "Reação Sintética (+35% potência de poções e ácido cumulativo)",
		"skill_q": "Frasco de Fogo Grego & Cura (Cura +45 HP aliados e queima com 1.8x dano)",
		"skill_r": "Bomba de Ácido Corrosivo (Derrete 35% defesa inimiga e desacelera)",
		"skill_f": "Transmutação do Behemoth Químico (2.6x dano e +30% status por 8s)",
		"color": Color("#69f0ae")
	},
	{
		"id": 9,
		"name": "Escultor",
		"desc": "Mestre escultor com cinzel e adaga estilo Moonlight Sculptor. [Passiva] Olho da Escultura & Estátua Viva.",
		"passive": "Olho da Escultura & Estátua Viva (+25% Crítico enxergando falhas e Estátua Guardiã)",
		"skill_q": "Entalhe em Velocidade (5 cortes precisos com 1.9x dano que reduzem defesa)",
		"skill_r": "Estátua Explosiva / Pele de Mármore (Explosão e 50% redução de dano)",
		"skill_f": "Técnica Secreta: Escultura do Luar (2.8x Dano Verdadeiro e Colosso Esculpido)",
		"color": Color("#80deea")
	},
	{
		"id": 10,
		"name": "Domador",
		"desc": "Senhor da matilha com chicote bestial estilo The Taming Master. [Passiva] Senhor da Matilha.",
		"passive": "Senhor da Matilha (Fera Domada leal ataca a cada 1.8s e divide dano)",
		"skill_q": "Estalo do Chicote: Investida! (Chicoteia a 9m e fera rasga alvo com 1.9x dano)",
		"skill_r": "Fusão & Uivo Bestial (Cura +50 HP seu e da fera, +30% velocidade)",
		"skill_f": "Debandada das Feras Primordiais (Feras domadas atropelam em 7m com 2.8x dano)",
		"color": Color("#ffd740")
	},
	{
		"id": 11,
		"name": "Alfaiate de Guerra",
		"desc": "Combatente tático com fios de aço monofilamento e agulhas rúnicas blindadas.",
		"passive": "Fios Monofilamento & Seda Blindada (Cortes a 10m e defesa de armadura pesada)",
		"skill_q": "Teia de Fios Retalhadores (Cone de 8m fatiando com 1.85x dano)",
		"skill_r": "Costurar Sombras / Marionete (Prende alvos por 2.5s e concede esquiva ao grupo)",
		"skill_f": "Gaiola de Fios Carmesins (Redoma triturando alvos em 6m com 2.7x dano)",
		"color": Color("#ce93d8")
	},
	{
		"id": 12,
		"name": "Chef de Caça",
		"desc": "Mestre gourmet de caça com cutelo gigante e wok de ferro temperado.",
		"passive": "Células Gourmet & Mestre Açougueiro (Zona Verde Autópsia +50%, devorar dá buffs)",
		"skill_q": "Desossar a Vivo! (Cutelo 1.9x dano arranca bife curativo +35 HP do alvo)",
		"skill_r": "Banquete na Wok Flamejante (Bloqueia projéteis, cura +55 HP e +25% Dano)",
		"skill_f": "Trinchar o Behemoth (Cutelo flamejante com 2.8x em 5.5m e reduz defesa boss metade)",
		"color": Color("#ff7043")
	},
	{
		"id": 27,
		"name": "Ceifador do Eclipse",
		"desc": "Classe Secreta (Tier 5): Foice colossal com colheita de almas e roubo de vida pleno.",
		"passive": "Sede Abissal (10% roubo de vida, +40% na Lua de Sangue, +20% no Eclipse)",
		"skill_q": "Colheita Noturna (1.75x dano em arco amplo com roubo de vida)",
		"skill_r": "Drenagem Abissal (+45 HP e lentidão nos alvos)",
		"skill_f": "Dança do Eclipse Total (2.4x dano em 6.0m)",
		"color": Color("#d500f9")
	},
	{
		"id": 35,
		"name": "Artífice Rúnico",
		"desc": "Classe Secreta (Tier 5): Martelo-canhão movido a núcleos estelares e engrenagens.",
		"passive": "Ignição Titanomecânica (Dano híbrido físico/elétrico por FOR e INT)",
		"skill_q": "Salva Rúnica (1.75x em 3 disparos perfurantes)",
		"skill_r": "Sobrecarga Eletrostática (Raios nas armas do grupo por 8s)",
		"skill_f": "Bombardeio Titanomecânico (2.4x dano orbital em 6.5m)",
		"color": Color("#ff6d00")
	},
	{
		"id": 36,
		"name": "Criador de Homúnculos",
		"desc": "Classe Secreta (Tier 5): Vida sintética e quimera transmissora de bioplasma regenerativo.",
		"passive": "Vínculo Quimérico (Mini-Homúnculo regenera mestre e ataca alvos)",
		"skill_q": "Infusão Mutagênica (1.75x dano dissolvendo resistências)",
		"skill_r": "Névoa de Bioplasma (Cura +50 HP continuamente e cega monstros)",
		"skill_f": "Frenesi do Quimera Supremo (2.4x explosão de garras e ácido em 6m)",
		"color": Color("#00b0ff")
	},
	{
		"id": 28,
		"name": "Dançarino Astral",
		"desc": "Classe Secreta (Tier 5): Duelista cósmico com lâminas estelares duplas em prata e ciano.",
		"passive": "Graça das Constelações (+25% crítico inato e esquiva ao custo de 10 stamina)",
		"skill_q": "Corte Cadente (2.0x dano veloz)",
		"skill_r": "Valsa dos Espelhos (1.5s I-Frame + contra-ataque refletor)",
		"skill_f": "Constelação de Mil Lâminas (3.0x dano omnidirecional em 5.5m)",
		"color": Color("#80d8ff")
	},
	{
		"id": 29,
		"name": "Inquisidor das Cinzas",
		"desc": "Classe Secreta (Tier 5): Executor fanático com mangual e correntes incandescentes carmesins.",
		"passive": "Fervor do Mártir (Até +60% de dano adicional quanto menor for a sua vida atual)",
		"skill_q": "Chicote de Penitência (2.2x + roubo de vida em 8m)",
		"skill_r": "Selo de Excomunhão (+35 HP e queima em 5m)",
		"skill_f": "Crucificação de Cinzas (3.2x dano em 6m)",
		"color": Color("#ff5252")
	},
	{
		"id": 30,
		"name": "Necromante de Ossos",
		"desc": "Classe Secreta (Tier 5): Manipulador sombrio de ossos e crânio de cristal verde-esmeralda.",
		"passive": "Colheita de Ossos (Cura +20 HP instantâneos por monstro abatido)",
		"skill_q": "Lança de Fêmur (2.0x perfurante a 16m)",
		"skill_r": "Explosão Óssea & Escudo (5.0m e couraça protetora de ossos)",
		"skill_f": "Legião do Ossuário (3.0x dano em 6m)",
		"color": Color("#ccff90")
	},
	{
		"id": 37,
		"name": "Domador Primordial",
		"desc": "Classe Secreta (Tier 5): Guerreiro feral com lança e Lobo Espiritual Prateado leal ao seu lado.",
		"passive": "Espírito Alfa (+25% dano constante de todas as fontes de ataque)",
		"skill_q": "Investida do Alfa (2.1x dano rompendo linhas inimigas)",
		"skill_r": "Uivo da Alcateia (+50 HP cura e buff de crítico ao grupo)",
		"skill_f": "Fúria do Behemoth (3.0x frontal sísmico em 5m)",
		"color": Color("#ffd740")
	},
	{
		"id": 38,
		"name": "Cavaleiro da Ruptura",
		"desc": "Classe Secreta (Tier 5): Colosso espacial com espada de obsidiana e escudo gravitacional do Vazio.",
		"passive": "Armadura Singular (-30% de todo dano físico e mágico recebido)",
		"skill_q": "Esmagamento Gravitacional (Puxa monstros em 5m + 1.9x)",
		"skill_r": "Singularidade Reversa (Absorve 80% dano e implode)",
		"skill_f": "Colapso Estelar (2.8x em 6.5m + atordoa monstros)",
		"color": Color("#7c4dff")
	},
	{
		"id": 39,
		"name": "Arauto da Tempestade",
		"desc": "Classe Secreta (Tier 5): Avatar dos trovões com alabarda de ouro e relâmpagos celestiais.",
		"passive": "Condutividade Celestial (+35% de dano na Chuva e choque estático ao ser atacado)",
		"skill_q": "Lança do Trovão (2.1x veloz a 18m)",
		"skill_r": "Passo de Relâmpago (Surto elétrico 4m + velocidade)",
		"skill_f": "Ira dos Céus (3.1x tempestade de raios em 6m)",
		"color": Color("#40c4ff")
	}
]

# ------------------------------------------------------------------------------
# BANCO DE DADOS: 46 RAÇAS & LINHAGENS COMPLETAS
# ------------------------------------------------------------------------------
const RACES_DATA := [
	# Raças Base (1-4)
	{
		"id": 1, "group": "BASE", "name": "Valeriano", "badge": "Base Solar", "color": Color("#ffd700"),
		"stats": "FOR: 6 | DES: 6 | CON: 6 | AGI: 6 | INT: 6 | ESP: 6 | MAS: 7 | SOR: 7",
		"passive": "Linhagem Solar: +15% regeneração contínua de Stamina mesmo atacando.",
		"skill_z": "Ímpeto Valeriano [Z]: Restaura +40 Stamina, +25 HP e concede +25% Dano por 10s."
	},
	{
		"id": 2, "group": "BASE", "name": "Noctari", "badge": "Base Lunar", "color": Color("#00e5ff"),
		"stats": "FOR: 4 | DES: 8 | CON: 4 | AGI: 8 | INT: 9 | ESP: 7 | MAS: 5 | SOR: 5",
		"passive": "Sintonia Noturna: +25% Dano Mágico e Esquiva à noite (dobrado em Lua Cheia).",
		"skill_z": "Explosão Lunar [Z]: Detonação mágica estelar em 5.5m causando alto dano arcano e cura +30 HP."
	},
	{
		"id": 3, "group": "BASE", "name": "Kharad", "badge": "Base Forja", "color": Color("#ff9800"),
		"stats": "FOR: 9 | DES: 4 | CON: 10 | AGI: 3 | INT: 4 | ESP: 6 | MAS: 9 | SOR: 5",
		"passive": "Pele Pétrea: -20% dano recebido permanente e imunidade a desequilíbrio.",
		"skill_z": "Baluarte Rúnico [Z]: Erupção de magma em 4.5m e escudo de 70% de redução por 5s."
	},
	{
		"id": 4, "group": "BASE", "name": "Varkai", "badge": "Base Feral", "color": Color("#ff5722"),
		"stats": "FOR: 8 | DES: 7 | CON: 7 | AGI: 8 | INT: 3 | ESP: 4 | MAS: 6 | SOR: 7",
		"passive": "Sangue Fervilhante: Abaixo de 35% HP ganha +20% dano e +30% velocidade.",
		"skill_z": "Sopro Dracônico [Z]: Cone frontal de 5.5m de alto impacto e roubo de vida."
	},

	# Secretas Clássicas (5-10)
	{
		"id": 5, "group": "SECRET", "name": "Dhampir", "badge": "Vampírico", "color": Color("#e91e63"),
		"stats": "FOR: 8 | DES: 9 | CON: 6 | AGI: 9 | INT: 8 | ESP: 3 | MAS: 6 | SOR: 6",
		"passive": "Vampirismo: +10% de Roubo de Vida passivo permanente em todos os ataques.",
		"skill_z": "Sede de Sangue [Z]: Drena 45 HP do alvo num estalo sombrio restaurando a própria vida."
	},
	{
		"id": 6, "group": "SECRET", "name": "Licantropo Primordial", "badge": "Lupino Alfa", "color": Color("#ff6f00"),
		"stats": "FOR: 12 | DES: 9 | CON: 11 | AGI: 10 | INT: 2 | ESP: 3 | MAS: 7 | SOR: 6",
		"passive": "Fúria Lupina: +25% de dano e velocidade durante a noite ou Luas especiais.",
		"skill_z": "Uivo da Fera Ancestral [Z]: Uivo estarrecedor que aterroriza monstros e bufa velocidade em 40%."
	},
	{
		"id": 7, "group": "SECRET", "name": "Revenant", "badge": "Cinzas", "color": Color("#a7ffeb"),
		"stats": "FOR: 7 | DES: 6 | CON: 9 | AGI: 5 | INT: 9 | ESP: 10 | MAS: 6 | SOR: 3",
		"passive": "Tenacidade Fúnebre: Ao receber dano letal, sobrevive por 4s com 1 HP para lutar.",
		"skill_z": "Pacto das Cinzas [Z]: Explosão de cinzas em 5m prendendo inimigos e drenando essência."
	},
	{
		"id": 8, "group": "SECRET", "name": "Celestino", "badge": "Luz Solar", "color": Color("#fff176"),
		"stats": "FOR: 6 | DES: 6 | CON: 7 | AGI: 7 | INT: 10 | ESP: 12 | MAS: 6 | SOR: 8",
		"passive": "Aura Radiante: Inimigos próximos sofrem dano contínuo de calor sagrado de dia.",
		"skill_z": "Chama Sagrada [Z]: Feixe purificador solar que queima inimigos e cura aliados no trajeto."
	},
	{
		"id": 9, "group": "SECRET", "name": "Abissal", "badge": "Sombra Cósmica", "color": Color("#7c4dff"),
		"stats": "FOR: 6 | DES: 7 | CON: 8 | AGI: 6 | INT: 12 | ESP: 8 | MAS: 6 | SOR: 5",
		"passive": "Corpo de Éter: 12% de chance constante de esquivar totalmente de qualquer impacto.",
		"skill_z": "Mergulho Abissal [Z]: Teleporta pelo éter detonando ondas de vácuo gravitacional."
	},
	{
		"id": 10, "group": "SECRET", "name": "Autômato Rúnico", "badge": "Gélido Rúnico", "color": Color("#80deea"),
		"stats": "FOR: 10 | DES: 5 | CON: 12 | AGI: 4 | INT: 8 | ESP: 6 | MAS: 10 | SOR: 4",
		"passive": "Blindagem de Adamante: -20% de dano físico e imunidade permanente a venenos.",
		"skill_z": "Sobrecarga Arcana [Z]: Detona descarga elétrica em anel de 6m atordoando monstros."
	},

	# Evoluções Ordem e Caos (11-18)
	{
		"id": 11, "group": "EVOLUTION", "name": "Alto Valeriano", "badge": "Ordem Solar", "color": Color("#ffe082"),
		"stats": "FOR: 10 | DES: 8 | CON: 9 | AGI: 8 | INT: 9 | ESP: 9 | MAS: 9 | SOR: 9",
		"passive": "Soberania da Coroa: +30% de Stamina máxima e regeneração ininterrupta.",
		"skill_z": "Estandarte Real [Z]: Cura +50 HP em aliados e energiza armas com +35% de dano solar."
	},
	{
		"id": 12, "group": "EVOLUTION", "name": "Andarilho do Éter", "badge": "Caos Cósmico", "color": Color("#ce93d8"),
		"stats": "FOR: 8 | DES: 10 | CON: 7 | AGI: 12 | INT: 10 | ESP: 8 | MAS: 10 | SOR: 10",
		"passive": "Forma Etérea: 18% de chance de desviar totalmente de qualquer ataque recebido.",
		"skill_z": "Fenda Dimensional [Z]: Rasga a tapeçaria da realidade, teleportando 6m com vácuo."
	},
	{
		"id": 13, "group": "EVOLUTION", "name": "Arconte Lunar", "badge": "Ordem Selene", "color": Color("#80d8ff"),
		"stats": "FOR: 5 | DES: 11 | CON: 6 | AGI: 11 | INT: 14 | ESP: 11 | MAS: 8 | SOR: 8",
		"passive": "Coração Estelar: +40% de poder mágico sob qualquer fase da lua.",
		"skill_z": "Luz de Selene [Z]: Pilar de luz lunar curando +70 HP e cegando inimigos com dano sagrado."
	},
	{
		"id": 14, "group": "EVOLUTION", "name": "Espectro Umbral", "badge": "Caos Nyx", "color": Color("#b388ff"),
		"stats": "FOR: 6 | DES: 13 | CON: 5 | AGI: 14 | INT: 12 | ESP: 9 | MAS: 11 | SOR: 9",
		"passive": "Assassino das Trevas: +35% de velocidade e +30% de dano crítico permanente.",
		"skill_z": "Manto de Nyx [Z]: Invisibilidade por 4s; próximo ataque causa +120% Dano Crítico garantido."
	},
	{
		"id": 15, "group": "EVOLUTION", "name": "Guardião Rúnico", "badge": "Ordem Forja", "color": Color("#ffcc80"),
		"stats": "FOR: 13 | DES: 6 | CON: 15 | AGI: 5 | INT: 7 | ESP: 9 | MAS: 12 | SOR: 7",
		"passive": "Baluarte Inabalável: Imune a controle de grupo e bônus de +400 HP Máximo.",
		"skill_z": "Muralha Rúnica [Z]: Absorve 85% de dano por 6s e reflete 50% de volta aos atacantes."
	},
	{
		"id": 16, "group": "EVOLUTION", "name": "Titã de Obsidiana", "badge": "Caos Magma", "color": Color("#ffab91"),
		"stats": "FOR: 15 | DES: 5 | CON: 17 | AGI: 4 | INT: 6 | ESP: 7 | MAS: 10 | SOR: 6",
		"passive": "Corpo Magmático: Atacantes corpo-a-corpo sofrem retaliação de fogo constante.",
		"skill_z": "Erupção Magma [Z]: Racha o solo liberando gêiser vulcânico de 5.5m que incendeia inimigos."
	},
	{
		"id": 17, "group": "EVOLUTION", "name": "Soberano Dracônico", "badge": "Ordem Dracônica", "color": Color("#ff8a65"),
		"stats": "FOR: 13 | DES: 10 | CON: 11 | AGI: 11 | INT: 6 | ESP: 7 | MAS: 9 | SOR: 10",
		"passive": "Escamas do Soberano: Reduz 35% do dano mágico recebido e amplifica dano elemental em 30%.",
		"skill_z": "Chamas Reais [Z]: Sopro colunar de 7m que incinera oponentes e rouba vida em massa."
	},
	{
		"id": 18, "group": "EVOLUTION", "name": "Fera do Frenesi", "badge": "Caos Feral", "color": Color("#ff1744"),
		"stats": "FOR: 14 | DES: 11 | CON: 10 | AGI: 13 | INT: 4 | ESP: 5 | MAS: 10 | SOR: 11",
		"passive": "Carnificina Feral: Abates concedem +20% de cura total instantânea.",
		"skill_z": "Frenesi Destruidor [Z]: Salto devastador desferindo 4 garras com roubo de vida."
	},

	# Novas Raças Secretas (19-28)
	{
		"id": 19, "group": "NEW", "name": "Sylvari", "badge": "Nascido da Seiva", "color": Color("#81c784"),
		"stats": "FOR: 5 | DES: 7 | CON: 8 | AGI: 6 | INT: 8 | ESP: 10 | MAS: 6 | SOR: 5",
		"passive": "Vínculo com a Seiva: +3 HP/s contínuo enquanto permanecer em terreno natural.",
		"skill_z": "Raízes Vivas [Z]: Raízes brotam do solo em 6m prendendo e drenando vida de oponentes."
	},
	{
		"id": 20, "group": "NEW", "name": "Esporiano", "badge": "Véu Fúngico", "color": Color("#9c27b0"),
		"stats": "FOR: 4 | DES: 5 | CON: 10 | AGI: 4 | INT: 10 | ESP: 9 | MAS: 8 | SOR: 5",
		"passive": "Simbiose Fúngica: Imunidade total a venenos e regeneração sob toxinas.",
		"skill_z": "Nuvem de Esporos [Z]: Libera nuvem fúngica de veneno e confusão cegando atacantes em 5m."
	},
	{
		"id": 21, "group": "NEW", "name": "Aracne", "badge": "Tecelã da Bruma", "color": Color("#eceff1"),
		"stats": "FOR: 6 | DES: 11 | CON: 5 | AGI: 10 | INT: 7 | ESP: 4 | MAS: 12 | SOR: 5",
		"passive": "Pernas de Seda: Velocidade de movimento nunca é reduzida por lentidão.",
		"skill_z": "Teia Prateada [Z]: Dispara projétil de teia que imobiliza o alvo por 3 segundos."
	},
	{
		"id": 22, "group": "NEW", "name": "Draconato de Cinzas", "badge": "Escama-Negra", "color": Color("#ff6e40"),
		"stats": "FOR: 12 | DES: 5 | CON: 12 | AGI: 5 | INT: 8 | ESP: 6 | MAS: 6 | SOR: 4",
		"passive": "Escama-Negra: Imunidade a chamas e +15% de armadura física permanente.",
		"skill_z": "Sopro de Cinzas [Z]: Cone frontal de brasas incandescentes e queima cumulativa."
	},
	{
		"id": 23, "group": "NEW", "name": "Quimera", "badge": "Costurado", "color": Color("#76ff03"),
		"stats": "FOR: 9 | DES: 8 | CON: 9 | AGI: 8 | INT: 6 | ESP: 2 | MAS: 10 | SOR: 5",
		"passive": "Corpo Reativo: Adaptação celular concedendo +25% de resistência ao último dano.",
		"skill_z": "Mutação Bioquímica [Z]: Onda de choque bio-ácida frontal adaptativa de alto impacto."
	},
	{
		"id": 24, "group": "NEW", "name": "Boreal", "badge": "Coração de Geada", "color": Color("#80d8ff"),
		"stats": "FOR: 8 | DES: 6 | CON: 9 | AGI: 5 | INT: 9 | ESP: 8 | MAS: 6 | SOR: 4",
		"passive": "Coração Glacial: +25% dano de frio e imunidade a congelamento e hipotermia.",
		"skill_z": "Crio-Armadura [Z]: Armadura de gelo puro absorvendo dano e congelando atacantes."
	},
	{
		"id": 25, "group": "NEW", "name": "Thalassiano", "badge": "Maré Negra", "color": Color("#006064"),
		"stats": "FOR: 7 | DES: 8 | CON: 7 | AGI: 9 | INT: 9 | ESP: 8 | MAS: 5 | SOR: 5",
		"passive": "Filho do Oceano: +30% de velocidade e cura na chuva e áreas aquáticas.",
		"skill_z": "Maré Abissal [Z]: Erupção de gêiser d'água sob pressão arrastando alvos."
	},
	{
		"id": 26, "group": "NEW", "name": "Cambion", "badge": "Sangue de Enxofre", "color": Color("#ff5252"),
		"stats": "FOR: 11 | DES: 8 | CON: 8 | AGI: 7 | INT: 9 | ESP: 2 | MAS: 5 | SOR: 6",
		"passive": "Sangue de Enxofre: Ataques convertem 5% da vida máxima em poder ofensivo dobrado.",
		"skill_z": "Correntes Infernais [Z]: Correntes do tártaro prendem alvos queimando suas almas."
	},
	{
		"id": 27, "group": "NEW", "name": "Nephilim", "badge": "Híbrido Crepúsculo", "color": Color("#ffe082"),
		"stats": "FOR: 9 | DES: 9 | CON: 8 | AGI: 8 | INT: 10 | ESP: 10 | MAS: 7 | SOR: 7",
		"passive": "Dualidade Cósmica: Alterna bônus de dano sagrado e necrótico a cada golpe.",
		"skill_z": "Julgamento Nephilim [Z]: Feixe duplo divino e sombrio desintegrando defesas."
	},
	{
		"id": 28, "group": "NEW", "name": "Errante Temporal", "badge": "Cronomante", "color": Color("#ffd54f"),
		"stats": "FOR: 5 | DES: 10 | CON: 5 | AGI: 12 | INT: 12 | ESP: 9 | MAS: 8 | SOR: 9",
		"passive": "Fios do Tempo: Reduz o cooldown de todas as habilidades de classe em 15%.",
		"skill_z": "Reversão Temporal [Z]: Rebobina posição e vida para 3 segundos atrás."
	},

	# 18 Novas Raças do RPG (29-46)
	{
		"id": 29, "group": "RPG", "name": "Meio-Celestial", "badge": "RPG Divino", "color": Color("#fff59d"),
		"stats": "FOR: 8 | DES: 8 | CON: 8 | AGI: 8 | INT: 9 | ESP: 11 | MAS: 7 | SOR: 7",
		"passive": "Graça Divina: +15% de cura recebida e dano sagrado radiante passivo.",
		"skill_z": "Asas de Luz [Z]: Abre asas celestes curando +65 HP e restaurando +40 Stamina."
	},
	{
		"id": 30, "group": "RPG", "name": "Pyromante", "badge": "RPG Chamas", "color": Color("#ff3d00"),
		"stats": "FOR: 6 | DES: 8 | CON: 7 | AGI: 8 | INT: 12 | ESP: 6 | MAS: 7 | SOR: 6",
		"passive": "Chama da Vida: Revive automaticamente com 50% de HP uma vez ao receber dano fatal.",
		"skill_z": "Combustão [Z]: Detona explosão de fogo em 6m desferindo 2.8x de dano elemental."
	},
	{
		"id": 31, "group": "RPG", "name": "Gigante de Gelo", "badge": "RPG Glacial (1.45x)", "color": Color("#80deea"),
		"stats": "FOR: 14 | DES: 4 | CON: 15 | AGI: 4 | INT: 6 | ESP: 6 | MAS: 9 | SOR: 4",
		"passive": "Massa Glacial: Escala de 1.45x, alta tenacidade e +25% de absorção contra frio.",
		"skill_z": "Memória Molecular [Z]: Pancada de estalagmites e +350 HP Máximo por 15s."
	},
	{
		"id": 32, "group": "RPG", "name": "Drago Terra", "badge": "RPG Carapaça", "color": Color("#8d6e63"),
		"stats": "FOR: 12 | DES: 5 | CON: 14 | AGI: 4 | INT: 5 | ESP: 6 | MAS: 10 | SOR: 5",
		"passive": "Carapaça Telúrica: Reduz passivamente 35% de todo dano físico sofrido.",
		"skill_z": "Insulto Sísmico [Z]: Provoca monstros em 10m forçando seu foco e quebrando posturas."
	},
	{
		"id": 33, "group": "RPG", "name": "Drago Água", "badge": "RPG Marés", "color": Color("#29b6f6"),
		"stats": "FOR: 8 | DES: 9 | CON: 9 | AGI: 8 | INT: 9 | ESP: 9 | MAS: 7 | SOR: 7",
		"passive": "Correnteza: Recupera continuamente +2.5 HP/s na água ou sob chuva torrencial.",
		"skill_z": "Bênção de Netuno [Z]: Dispara onda marinha em cone empurrando e atordoando inimigos."
	},
	{
		"id": 34, "group": "RPG", "name": "Drago Raio", "badge": "RPG Fulgor", "color": Color("#ffd600"),
		"stats": "FOR: 8 | DES: 11 | CON: 7 | AGI: 12 | INT: 10 | ESP: 5 | MAS: 8 | SOR: 7",
		"passive": "Condutor de Alta Tensão: +20% de velocidade e chance de choque elétrico em contra-ataques.",
		"skill_z": "Descarga Elétrica [Z]: Feixe perfurante de choque rápido de longo alcance (1.85x)."
	},
	{
		"id": 35, "group": "RPG", "name": "Drago Místico", "badge": "RPG Rúnico", "color": Color("#ab47bc"),
		"stats": "FOR: 6 | DES: 8 | CON: 8 | AGI: 7 | INT: 13 | ESP: 10 | MAS: 6 | SOR: 6",
		"passive": "Sangue Rúnico: +30% de mana e amplificação mágica elemental contínua.",
		"skill_z": "Infusão Arcana [Z]: Círculo rúnico protetor de 6m com +40% de dano mágico por 10s."
	},
	{
		"id": 36, "group": "RPG", "name": "Orc", "badge": "RPG Brutal", "color": Color("#558b2f"),
		"stats": "FOR: 13 | DES: 6 | CON: 13 | AGI: 6 | INT: 3 | ESP: 3 | MAS: 9 | SOR: 5",
		"passive": "Fisiologia Brutal: -20% dano passivo e capacidade de ingerir qualquer lixo orgânico para cura.",
		"skill_z": "Ataque Devastador [Z]: Golpe esmagador brutal com força tripla (3.2x dano)."
	},
	{
		"id": 37, "group": "RPG", "name": "Anão", "badge": "RPG Forja (0.82x)", "color": Color("#d7ccc8"),
		"stats": "FOR: 11 | DES: 5 | CON: 13 | AGI: 4 | INT: 6 | ESP: 7 | MAS: 12 | SOR: 5",
		"passive": "Resistência da Montanha: Estatura de 0.82x com firmeza e maestria superior na forja.",
		"skill_z": "Martelo Ancestral [Z]: Pancada de bigorna que atordoa oponentes em raio de 5.5m."
	},
	{
		"id": 38, "group": "RPG", "name": "Elfo", "badge": "RPG Silvestre", "color": Color("#aed581"),
		"stats": "FOR: 5 | DES: 11 | CON: 5 | AGI: 12 | INT: 10 | ESP: 8 | MAS: 7 | SOR: 6",
		"passive": "Graça da Floresta: +15% de precisão de disparo e custo reduzido em esquivas.",
		"skill_z": "Disparo Élfico [Z]: Projétil perfurante luminoso de éter que atravessa múltiplos alvos."
	},
	{
		"id": 39, "group": "RPG", "name": "Elfo Solar (Azgher)", "badge": "RPG Solar", "color": Color("#ffb300"),
		"stats": "FOR: 6 | DES: 10 | CON: 6 | AGI: 10 | INT: 11 | ESP: 10 | PER: 7 | SOR: 7",
		"passive": "Bênção de Azgher: +25% de dano solar durante o dia sob céu limpo.",
		"skill_z": "Espada Solar de Azgher [Z]: Incendeia a lâmina com corte colunar de chamas radiantes."
	},
	{
		"id": 40, "group": "RPG", "name": "Elfo Lunar (Tenebra)", "badge": "RPG Sombra", "color": Color("#5c6bc0"),
		"stats": "FOR: 5 | DES: 11 | CON: 5 | AGI: 12 | INT: 10 | ESP: 8 | MAS: 8 | SOR: 8",
		"passive": "Véu de Tenebra: +30% de chance crítica e passos sem som durante a noite.",
		"skill_z": "Manto de Tenebra [Z]: Mergulho nas sombras obtendo invisibilidade e ataque crítico."
	},
	{
		"id": 41, "group": "RPG", "name": "Fadinha", "badge": "RPG Alado (0.55x)", "color": Color("#f48fb1"),
		"stats": "FOR: 3 | DES: 10 | CON: 4 | AGI: 13 | INT: 11 | ESP: 11 | MAS: 5 | SOR: 10",
		"passive": "Forma Minúscula: Estatura minúscula de 0.55x com voo leve e hitbox reduzida.",
		"skill_z": "Pó de Fada Estelar [Z]: Espalha pó cintilante curando aliados e cegando monstros."
	},
	{
		"id": 42, "group": "RPG", "name": "Goblin", "badge": "RPG Trapaceiro (0.75x)", "color": Color("#7cb342"),
		"stats": "FOR: 6 | DES: 12 | CON: 5 | AGI: 13 | INT: 6 | ESP: 3 | MAS: 10 | SOR: 12",
		"passive": "Trapaceiro Nato: Estatura de 0.75x com +20% de drop de ouro e bônus pelas costas.",
		"skill_z": "Truque Sujo Goblin [Z]: Bomba de fumaça e pólvora cegando e atordoando oponentes."
	},
	{
		"id": 43, "group": "RPG", "name": "Demi-Humano Escorpião", "badge": "RPG Peçonha", "color": Color("#6a1b9a"),
		"stats": "FOR: 9 | DES: 10 | CON: 8 | AGI: 10 | INT: 7 | ESP: 3 | MAS: 11 | SOR: 6",
		"passive": "Quitina Vorpal: +20% de dano contra alvos envenenados e resistência alta a toxinas.",
		"skill_z": "Aguilhão de Toxina Vorpal [Z]: Estocada com ferrão traseiro injetando peçonha corrosiva."
	},
	{
		"id": 44, "group": "RPG", "name": "Demi-Humano Tartaruga", "badge": "RPG Blindado (1.35x)", "color": Color("#33691e"),
		"stats": "FOR: 9 | DES: 4 | CON: 16 | AGI: 3 | INT: 6 | ESP: 8 | MAS: 9 | SOR: 5",
		"passive": "Casco de Titã: Escala robusta de 1.35x com -45% de dano sofrido permanentemente.",
		"skill_z": "Lar Doce Casca [Z]: Encolhe na carapaça absorvendo 85% de dano e repelindo inimigos."
	},
	{
		"id": 45, "group": "RPG", "name": "Meio-Demônio (Succubus)", "badge": "RPG Vampírico", "color": Color("#c2185b"),
		"stats": "FOR: 8 | DES: 10 | CON: 7 | AGI: 10 | INT: 11 | ESP: 4 | MAS: 8 | SOR: 8",
		"passive": "Charme Demoníaco: 25% de chance passiva de anular completamente ataques recebidos.",
		"skill_z": "Drenar Força Vital [Z]: Sifão demoníaco drenando 55 HP do alvo para o jogador."
	},
	{
		"id": 46, "group": "RPG", "name": "Demi-Humano Lobo", "badge": "RPG Feral", "color": Color("#78909c"),
		"stats": "FOR: 12 | DES: 9 | CON: 10 | AGI: 11 | INT: 3 | ESP: 4 | MAS: 8 | SOR: 7",
		"passive": "Instinto Lupino: +15% de dano físico e rastreamento de alvos com baixa integridade.",
		"skill_z": "Despertar Forma Bestial [Z]: Uivo brutal liberando +35% de velocidade e garras vorazes."
	},
	{
		"id": 47, "group": "SECRET", "name": "Manamante", "badge": "Sangue Azul", "color": Color("#3d5afe"),
		"stats": "FOR: 3 | DES: 6 | CON: 8 | AGI: 6 | INT: 13 | ESP: 11 | MAS: 7 | SOR: 4",
		"passive": "Afinidade Mágica: +18% de dano. Sangue Azul: Vida e Mana são uma só reserva (Vida alta, Stamina baixa).",
		"skill_z": "Coração de Mana [Z]: Queima 15% da Vida máxima numa explosão arcana de 7m (escala com INT)."
	}
]

# ------------------------------------------------------------------------------
# BANCO DE DADOS: CATÁLOGO DE ITENS POR CATEGORIA
# ------------------------------------------------------------------------------
const ITEMS_DATA := [
	# 1. Utilitários & Consumíveis
	{"id": 1, "name": "Frasco de Vidro Vazio / Poção de Vida", "cat": "UTIL", "slot": "Consumível", "rate": "80.0%", "secret": false, "desc": "Frasco de alquimia ou poção curativa essencial (+50 HP)."},
	{"id": 2, "name": "Frasco de Stamina", "cat": "UTIL", "slot": "Consumível", "rate": "40.0%", "secret": false, "desc": "Restaura 60 pontos de Stamina instantaneamente."},
	{"id": 3, "name": "Elixir de Mana", "cat": "UTIL", "slot": "Consumível", "rate": "35.0%", "secret": false, "desc": "Restaura éter arcano para habilidades contínuas."},
	{"id": 4, "name": "Carne Nobre Assada", "cat": "UTIL", "slot": "Alimento", "rate": "70.0%", "secret": false, "desc": "Refeição suculenta que regenera HP fora de combate."},
	{"id": 5, "name": "Carne Crua de Lobo", "cat": "UTIL", "slot": "Alimento", "rate": "100.0%", "secret": false, "desc": "Carne fresca colhida de predadores selvagens."},
	{"id": 6, "name": "Pelagem Cinzenta", "cat": "UTIL", "slot": "Material", "rate": "100.0%", "secret": false, "desc": "Pele espessa utilizada em alfaiataria e couro."},

	# 2. Partes Anatômicas & Órgãos de Autópsia
	{"id": 7, "name": "Presa Lupina Afiada", "cat": "ANAT", "slot": "Órgão/Troféu", "rate": "25.0%", "secret": false, "desc": "Dente afiado como navalha extraído em autópsia limpa."},
	{"id": 8, "name": "Garra de Fera", "cat": "ANAT", "slot": "Órgão/Troféu", "rate": "20.0%", "secret": false, "desc": "Garra curvada de predador, essencial para forja de adagas."},
	{"id": 9, "name": "Olho da Coruja Noturna", "cat": "ANAT", "slot": "Órgão Místico", "rate": "15.0%", "secret": false, "desc": "Globo ocular cristalizado com sensibilidade à penumbra."},
	{"id": 18, "name": "Asa de Morcego Primordial", "cat": "ANAT", "slot": "Órgão", "rate": "30.0%", "secret": false, "desc": "Membrana alada colhida nas profundezas dos esgotos."},
	{"id": 19, "name": "Glândula Venenosa", "cat": "ANAT", "slot": "Órgão", "rate": "25.0%", "secret": false, "desc": "Bolsa intacta de toxina corrosiva de alta periculosidade."},
	{"id": 24, "name": "Escama de Dragão de Cinzas", "cat": "ANAT", "slot": "Troféu Raro", "rate": "5.0%", "secret": false, "desc": "Fragmento blindado impérvio a calor extremo."},

	# 3. Equipamentos dos 12 Slots
	{"id": 10, "name": "Espada Longa de Ferro", "cat": "EQUIP", "slot": "Mão Primária", "rate": "15.0%", "secret": false, "desc": "Lâmina forjada equilibrada para combate corporal."},
	{"id": 11, "name": "Escudo de Madeira Reforçado", "cat": "EQUIP", "slot": "Mão Secundária", "rate": "15.0%", "secret": false, "desc": "Escudo resistente com encaixes de ferro batido."},
	{"id": 12, "name": "Arco de Bordo Longo", "cat": "EQUIP", "slot": "Longo Alcance", "rate": "15.0%", "secret": false, "desc": "Arco flexível capaz de disparos precisos a grande distância."},
	{"id": 13, "name": "Cajado do Aprendiz", "cat": "EQUIP", "slot": "Arma Mágica", "rate": "15.0%", "secret": false, "desc": "Madeira entalhada canalizadora de energia do éter."},
	{"id": 20, "name": "Armadura de Prata Imperial", "cat": "EQUIP", "slot": "Peitoral (Tronco)", "rate": "10.0%", "secret": false, "desc": "Couraça nobre concedendo defesa física e espiritual elevada."},
	{"id": 21, "name": "Elmo de Ferro Batido", "cat": "EQUIP", "slot": "Cabeça", "rate": "12.0%", "secret": false, "desc": "Proteção craniana com frestas de visão tática."},
	{"id": 22, "name": "Botas de Couro de Fera", "cat": "EQUIP", "slot": "Pés", "rate": "15.0%", "secret": false, "desc": "Calçado silencioso garantindo tração firme no terreno."},
	{"id": 23, "name": "Luvas de Malha Pesada", "cat": "EQUIP", "slot": "Mãos", "rate": "15.0%", "secret": false, "desc": "Protege os dedos contra impacto sem comprometer o manejo."},
	{"id": 25, "name": "Calças de Aço Temperado", "cat": "EQUIP", "slot": "Pernas", "rate": "12.0%", "secret": false, "desc": "Perneiras com articulações reforçadas para mobilidade."},
	{"id": 26, "name": "Ombreiras Rúnicas", "cat": "EQUIP", "slot": "Ombros", "rate": "10.0%", "secret": false, "desc": "Guarda-ombros gravados com runas de proteção elemental."},
	{"id": 27, "name": "Cinto do Conquistador", "cat": "EQUIP", "slot": "Cintura", "rate": "12.0%", "secret": false, "desc": "Cinto de couro grosso com fivela de bronze pesado."},
	{"id": 28, "name": "Amuleto do Eclipse", "cat": "EQUIP", "slot": "Pescoço (Colar)", "rate": "8.0%", "secret": false, "desc": "Talismã lapidado que vibra com o ciclo da lua."},
	{"id": 29, "name": "Anel de Presa Ancestral", "cat": "EQUIP", "slot": "Dedo (Anel)", "rate": "5.0%", "secret": false, "desc": "Aro entalhado em marfim fóssil aumentando poder crítico."},

	# 4. Relíquias Secretas de 0.1% Drop Rate
	{"id": 14, "name": "Cálice da Alma Partida", "cat": "SECRET", "slot": "Relíquia Secreta (Revenant)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Relíquia da morte necessária para despertar o Revenant da Cripta. Drop de Acólito do Eclipse."},
	{"id": 15, "name": "Chave Rúnica da Cripta", "cat": "SECRET", "slot": "Relíquia Secreta (Guardião)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Chave sagrada antiga das catacumbas da Vigília. Drop do Comandante Vaelen."},
	{"id": 16, "name": "Medalhão da Vigília", "cat": "SECRET", "slot": "Relíquia Secreta (Cavaleiro)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Insígnia dos cavaleiros juramentados do passado. Drop do Executor de Ferro."},
	{"id": 17, "name": "Tomo da Foice do Eclipse", "cat": "SECRET", "slot": "Relíquia Secreta (Ceifador)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Grimório profano contendo a liturgia do Ceifador. Drop de Acólitos e Cultistas."},
	{"id": 30, "name": "Casulo de Seda Prateada", "cat": "SECRET", "slot": "Relíquia Secreta (Aracne)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Casulo cristalino que abriga os segredos da linhagem Aracne. Drop de feras no Bosque."},

	# 5. Quadrante 4: Drops de Criaturas e Raid Bosses
	{"id": 42, "name": "Casulo de Seda Perfeito", "cat": "UTIL", "slot": "Material/Autópsia", "rate": "100.0%", "secret": false, "desc": "Seda densa e brilhante da Aranha Tecelã."},
	{"id": 43, "name": "Coração da Rainha Aranha", "cat": "ANAT", "slot": "Relíquia (+12 INT, +8 ESP)", "rate": "100.0%", "secret": false, "desc": "Coração pulsante e gélido de Arachna."},
	{"id": 44, "name": "Olho Multifacetado de Arachna", "cat": "SECRET", "slot": "Relíquia Secreta (Aracne)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Desbloqueia a Raça Secreta 21 Aracne (Tecelão da Bruma)."},
	{"id": 45, "name": "Manto de Seda Imperial", "cat": "EQUIP", "slot": "Capa / Manto (+45 HP, +6 INT, +5 ESP)", "rate": "100.0%", "secret": false, "desc": "Manto lendário tecido por Arachna."},
	{"id": 46, "name": "Ácido Puro", "cat": "UTIL", "slot": "Material Corrosivo", "rate": "100.0%", "secret": false, "desc": "Fluido cáustico corrosivo colhido do Lodo Ácido."},
	{"id": 47, "name": "Ferrão de Escorpião Abissal", "cat": "SECRET", "slot": "Relíquia Secreta (Escorpião)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Ferrão letal que desbloqueia a Raça Demi-Humano Escorpião."},
	{"id": 48, "name": "Veneno Vorpal", "cat": "ANAT", "slot": "Toxina Letal", "rate": "100.0%", "secret": false, "desc": "Toxina negra de altíssima letalidade."},
	{"id": 49, "name": "Retalho Quimérico Costurado", "cat": "ANAT", "slot": "Tecido Mutagênico", "rate": "100.0%", "secret": false, "desc": "Tecido mutagênico do Experimento Nº 0."},
	{"id": 50, "name": "Núcleo de Gelo Antigo", "cat": "ANAT", "slot": "Fragmento Glacial", "rate": "100.0%", "secret": false, "desc": "Fragmento glacial ancestral extraído de Golens e Ymir."},
	{"id": 51, "name": "Escama Dracônica Primordial", "cat": "ANAT", "slot": "Escama Superior", "rate": "100.0%", "secret": false, "desc": "Escama blindada resistente a impacto e gelo extremo."},
	{"id": 52, "name": "Coração de Geada Eterna", "cat": "SECRET", "slot": "Relíquia Secreta (Boreal)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Coração de Ymir que desperta a Raça 24 Boreal (Gigante de Gelo)."},
	{"id": 53, "name": "Insígnia do Guarda Carmesim", "cat": "EQUIP", "slot": "Distintivo Real", "rate": "100.0%", "secret": false, "desc": "Emblema de honra dos guardas góticos de Vesperian."},
	{"id": 54, "name": "Sangue Puro do Progenitor", "cat": "SECRET", "slot": "Relíquia Secreta (Dhampir)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Sangue milenar de Lorde Vesperian que desperta a Raça Dhampir/Vampiro!"},
	{"id": 55, "name": "Anel Carmesim de Vesperian", "cat": "EQUIP", "slot": "Anel (+6 FOR, +6 CON, +10% Roubo de Vida)", "rate": "100.0%", "secret": false, "desc": "Anel de prata e rubi de Lorde Vesperian."}
]

# ------------------------------------------------------------------------------
# BANCO DE DADOS: BESTIÁRIO COMPLETO DE LUNARIA (TODAS AS CRIATURAS & BOSSES)
# ------------------------------------------------------------------------------
const BESTIARY_DATA := [
	# ZoneID 1 — Bosque Sussurrante (600x600m)
	{
		"name": "Lobo da Bruma",
		"zone": "Bosque Sussurrante",
		"zone_id": 1,
		"hp": "220 HP",
		"speed": "6.2 m/s",
		"tactics": "Predador ágil que caça em bandos e cerca o jogador pelas costas.",
		"spawn": "Comum a qualquer hora do dia e da noite no bosque.",
		"drops_desc": "Carne Crua (100%), Pelagem (100%), Presa Lupina (25%), Casulo (0.1%).",
		"loot_ids": [5, 6, 7, 30],
		"color": Color("#90a4ae")
	},
	{
		"name": "Lobo Alfa (Chefe da Alcateia)",
		"zone": "Bosque Sussurrante",
		"zone_id": 1,
		"hp": "750 HP",
		"speed": "7.0 m/s",
		"tactics": "Uivo atordoante que convoca matilha e investida sísmica de alto impacto.",
		"spawn": "🌕 Spawn Exclusivo na LUA CHEIA (Fase 4 do Relógio).",
		"drops_desc": "Presa Alfa Ancestral (100%), Garra de Titã (100%), Medalhão (15%), Casulo (0.5%).",
		"loot_ids": [7, 8, 29, 30],
		"color": Color("#ffd54f")
	},
	{
		"name": "Licantropo Alfa (Raid Boss Feral)",
		"zone": "Bosque Sussurrante",
		"zone_id": 1,
		"hp": "2200 HP",
		"speed": "8.5 m/s",
		"tactics": "Salto letal devastador, ataques que ignoram bloqueio comum e rápida regeneração.",
		"spawn": "🩸 Spawn Exclusivo na LUA DE SANGUE (Fase 8 do Relógio).",
		"drops_desc": "Coração Carmesim (100%), Garras de Sangue (100%), Amuleto do Eclipse (25%), Casulo (2.0%).",
		"loot_ids": [7, 8, 28, 30],
		"color": Color("#e53935")
	},
	{
		"name": "Aranha Tecelã da Bruma",
		"zone": "Bosque Sussurrante",
		"zone_id": 1,
		"hp": "380 HP",
		"speed": "5.0 m/s",
		"tactics": "Cospe teias pegajosas que causam lentidão e ataca com presas venenosas.",
		"spawn": "Espalhada pelas árvores da floresta no Bosque Sussurrante.",
		"drops_desc": "Casulo de Seda Perfeito (100%), Glândula de Veneno (25%).",
		"loot_ids": [42, 19],
		"color": Color("#ba68c8")
	},
	{
		"name": "★ Arachna, a Rainha Tecelã [RAID BOSS] ★",
		"zone": "Bosque Sussurrante",
		"zone_id": 1,
		"hp": "6800 HP",
		"speed": "6.5 m/s",
		"tactics": "Raid Boss aracnídeo colossal ligado à raça Aracne! Patas articuladas gigantes, invoca aranhas e lança casulos.",
		"spawn": "🕸️ Ninho de Teias em (120, -120) no Bosque Sussurrante.",
		"drops_desc": "Coração da Rainha Aranha (100%), Manto de Seda Imperial (100%), Olho de Arachna (0.1% — Desbloqueia Raça Aracne!).",
		"loot_ids": [43, 45, 44],
		"color": Color("#e040fb")
	},

	# ZoneID 8 — Esgotos Antigos (600x600m)
	{
		"name": "Lodo Ácido Corrosivo",
		"zone": "Esgotos Antigos",
		"zone_id": 8,
		"hp": "320 HP",
		"speed": "3.6 m/s",
		"tactics": "Corrói durabilidade de armaduras e explode em poça cáustica.",
		"spawn": "Canais lamacentos e dutos dos Esgotos Antigos.",
		"drops_desc": "Ácido Puro (100%), Lixo Orgânico (100%).",
		"loot_ids": [46, 28],
		"color": Color("#76ff03")
	},
	{
		"name": "Escorpião Abissal Gigante",
		"zone": "Esgotos Antigos",
		"zone_id": 8,
		"hp": "540 HP",
		"speed": "4.8 m/s",
		"tactics": "Ataca com ferrão letal nos canais dos esgotos, aplicando veneno vorpal.",
		"spawn": "Túneis alagados e galerias dos Esgotos Antigos.",
		"drops_desc": "Veneno Vorpal (100%), Ferrão de Escorpião Abissal (0.1% — Desbloqueia Raça Demi-Humano Escorpião!).",
		"loot_ids": [48, 47],
		"color": Color("#26a69a")
	},
	{
		"name": "Mini-Boss Quimera Costurada Nº 0",
		"zone": "Esgotos Antigos",
		"zone_id": 8,
		"hp": "2800 HP",
		"speed": "5.2 m/s",
		"tactics": "Fera colossal de várias cabeças, cicatrizes luminosas e patadas brutais nos túneis profundos.",
		"spawn": "Laboratório subterrâneo dos Esgotos Antigos em (0, 110).",
		"drops_desc": "Retalho Quimérico (100%), Glândula de Veneno Mutante (100%), Placa Deformada (100%).",
		"loot_ids": [49, 19, 10],
		"color": Color("#ff7043")
	},

	# ZoneID 2 — Ruínas da Vigília & Norte Gelado (600x600m)
	{
		"name": "Saqueador Deserdado",
		"zone": "Ruínas da Vigília",
		"zone_id": 2,
		"hp": "350 HP",
		"speed": "4.5 m/s",
		"tactics": "Ladrão oportunista armado com espada curva e esquiva rápida.",
		"spawn": "Comum entre as muralhas desmoronadas e pátios.",
		"drops_desc": "Frasco de Vidro (80%), Carne Assada (70%), Anel de Presa (4%).",
		"loot_ids": [1, 4, 10, 29],
		"color": Color("#b0bec5")
	},
	{
		"name": "Besteiro da Vigília",
		"zone": "Ruínas da Vigília",
		"zone_id": 2,
		"hp": "200 HP",
		"speed": "3.8 m/s",
		"tactics": "Atirador à distância com virotes perfurantes e dispersão de estrepes.",
		"spawn": "Posicionado em torres de vigia e parapeitos de pedra.",
		"drops_desc": "Frascos (80%), Carne Assada (70%), Arco Longo (15%), Anel (5%).",
		"loot_ids": [1, 4, 12, 29],
		"color": Color("#78909c")
	},
	{
		"name": "Acólito do Eclipse",
		"zone": "Ruínas da Vigília",
		"zone_id": 2,
		"hp": "240 HP",
		"speed": "4.0 m/s",
		"tactics": "Conjurador com projéteis do vazio e chamas escuras.",
		"spawn": "Patrulha altares em ruínas e salas subterrâneas.",
		"drops_desc": "Cálice da Alma (0.1%), Tomo do Ceifador (0.1%), Casulo de Seda (0.1%).",
		"loot_ids": [3, 14, 17, 30],
		"color": Color("#ab47bc")
	},
	{
		"name": "Executor de Ferro",
		"zone": "Ruínas da Vigília",
		"zone_id": 2,
		"hp": "650 HP",
		"speed": "3.2 m/s",
		"tactics": "Tanque colossal com machado de duas mãos, armadura pesada e atordoamento frontal.",
		"spawn": "Guarda os portões da cidadela e arcos principais.",
		"drops_desc": "Fragmentos de Ferro (100%), Medalhão da Vigília (0.1%), Espada de Ferro (15%).",
		"loot_ids": [10, 16, 20, 21],
		"color": Color("#546e7a")
	},
	{
		"name": "Comandante Vaelen, o Traidor (Boss)",
		"zone": "Ruínas da Vigília",
		"zone_id": 2,
		"hp": "3200 HP",
		"speed": "5.5 m/s",
		"tactics": "Mestre de armas: combo veloz de 3 golpes, estocada com parry e redemoinho mortal.",
		"spawn": "Trono da Cidadela nas Ruínas da Vigília.",
		"drops_desc": "Espada de Vaelen (100%), Chave Rúnica da Cripta (0.1%), Armadura Imperial (25%).",
		"loot_ids": [10, 15, 20, 28],
		"color": Color("#ff9800")
	},
	{
		"name": "Golem de Gelo Antigo",
		"zone": "Ruínas da Vigília & Norte Gelado",
		"zone_id": 2,
		"hp": "720 HP",
		"speed": "3.4 m/s",
		"tactics": "Monólito de rocha e gelo com pisada congelante e alta resistência a dano cortante.",
		"spawn": "Habita o setor norte nevado da ZoneID 2.",
		"drops_desc": "Núcleo de Gelo Antigo (100%), Placa de Aço Pesada (100%).",
		"loot_ids": [50, 10],
		"color": Color("#4fc3f7")
	},
	{
		"name": "Draco de Geada Selvagem",
		"zone": "Ruínas da Vigília & Norte Gelado",
		"zone_id": 2,
		"hp": "950 HP",
		"speed": "5.8 m/s",
		"tactics": "Rasante com asas de gelo, bafo de geada e patadas perfurantes.",
		"spawn": "Cumes e penhascos nevados das Ruínas da Vigília.",
		"drops_desc": "Escama Dracônica Primordial (100%), Carne Nobre Assada (100%).",
		"loot_ids": [51, 4],
		"color": Color("#29b6f6")
	},
	{
		"name": "★ Ymir, o Patriarca Gigante de Gelo [BOSS] ★",
		"zone": "Ruínas da Vigília & Norte Gelado",
		"zone_id": 2,
		"hp": "5200 HP",
		"speed": "4.5 m/s",
		"tactics": "Titã colossal de gelo empunhando clava glacial rúnica, barreira de estalactites e pisada sísmica.",
		"spawn": "❄️ Trono de Gelo em (0, 150) na ZoneID 2.",
		"drops_desc": "Núcleo de Gelo Ancestral (100%), Coração de Geada Eterna (0.1% — Desbloqueia Gigante de Gelo / Boreal!).",
		"loot_ids": [50, 52],
		"color": Color("#00e5ff")
	},

	# ZoneID 3 — Santuário do Eclipse (600x600m)
	{
		"name": "Cultista Sombrio",
		"zone": "Santuário do Eclipse",
		"zone_id": 3,
		"hp": "400 HP",
		"speed": "4.2 m/s",
		"tactics": "Feiticeiro fanático que invoca orbes de sombra e debuffs contínuos.",
		"spawn": "Círculos rituais e escadarias do templo.",
		"drops_desc": "Cinzas do Eclipse (100%), Frascos (60%), Amuleto do Eclipse (8%).",
		"loot_ids": [3, 14, 17, 28],
		"color": Color("#8e24aa")
	},
	{
		"name": "Gárgula de Pedra",
		"zone": "Santuário do Eclipse",
		"zone_id": 3,
		"hp": "580 HP",
		"speed": "5.0 m/s",
		"tactics": "Blindagem de pedra impenetrável; mergulha dos céus causando impacto em área.",
		"spawn": "Gárgulas empoleiradas nas colunatas do Santuário.",
		"drops_desc": "Núcleo de Pedra (100%), Asa de Pedra (35%), Ombreiras Rúnicas (10%).",
		"loot_ids": [9, 24, 26, 28],
		"color": Color("#607d8b")
	},
	{
		"name": "Inquisidor Vex (Mini-Boss)",
		"zone": "Santuário do Eclipse",
		"zone_id": 3,
		"hp": "1400 HP",
		"speed": "4.8 m/s",
		"tactics": "Chicote flamejante de correntes carmesins; puxa o jogador e queima continuamente.",
		"spawn": "Pátio dos Sacrifícios no Santuário.",
		"drops_desc": "Correntes da Inquisição (100%), Cinzas Sagradas (100%), Tomo do Ceifador (20%).",
		"loot_ids": [10, 17, 20, 28],
		"color": Color("#d32f2f")
	},
	{
		"name": "★ Malakor, o Arauto do Eclipse [RAID BOSS] ★",
		"zone": "Santuário do Eclipse",
		"zone_id": 3,
		"hp": "7500 HP",
		"speed": "6.0 m/s",
		"tactics": "Deus do eclipse: vórtices gravitacionais, chuva de meteoros cósmicos e eclipse total.",
		"spawn": "Câmara Central do Santuário do Eclipse.",
		"drops_desc": "Foice do Eclipse (100%), Coroa de Malakor (100%), Tomo (20%), Cálice da Alma (20%).",
		"loot_ids": [14, 17, 20, 28, 30],
		"color": Color("#d500f9")
	},
	{
		"name": "Guarda Sanguinário de Vesperian",
		"zone": "Santuário do Eclipse",
		"zone_id": 3,
		"hp": "680 HP",
		"speed": "5.0 m/s",
		"tactics": "Protege a Cripta Carmesim. Armadura gótica negra e carmesim com alabarda sangrenta.",
		"spawn": "Entrada da Cripta Carmesim a Noroeste da ZoneID 3.",
		"drops_desc": "Insígnia do Guarda Carmesim (100%), Sangue Lunar Puro (100%).",
		"loot_ids": [53, 10],
		"color": Color("#ef5350")
	},
	{
		"name": "★ LORDE VESPERIAN, O PROGENITOR VAMPIRO [RAID BOSS SECRETO] ★",
		"zone": "Santuário do Eclipse",
		"zone_id": 3,
		"hp": "8500 HP",
		"speed": "6.8 m/s",
		"tactics": "O primeiro vampiro da história de Lunaria! Teleporte de névoa de sangue, drena vida em área e invoca morcegos abissais.",
		"spawn": "🩸 Cripta Carmesim em (-140, 140) na ZoneID 3 — Desperta à Noite, Lua de Sangue ou Eclipse!",
		"drops_desc": "Sangue Puro do Progenitor (0.1% — Desbloqueia a Raça Dhampir/Vampiro!), Tomo da Foice do Eclipse, Anel Carmesim de Vesperian.",
		"loot_ids": [55, 17, 54],
		"color": Color("#b71c1c")
	}
]

# ------------------------------------------------------------------------------
# INICIALIZAÇÃO E CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	_build_ui()

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_tree().current_scene
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)
	_update_trials_label()

func close_menu() -> void:
	is_open = false
	visible = false
	var world := get_tree().current_scene
	var any_other_open := false
	if world:
		if world.get("char_select_ui") and world.char_select_ui.get("is_open"): any_other_open = true
		if world.get("attributes_ui") and world.attributes_ui.get("is_open"): any_other_open = true
		if world.get("inventory_ui") and world.inventory_ui.get("is_open"): any_other_open = true
		if world.get("skills_ui") and world.skills_ui.get("is_open"): any_other_open = true
		if world.get("dev_drop_rates_ui") and world.dev_drop_rates_ui.get("is_open"): any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------
# CONSTRUÇÃO DA INTERFACE (TABCONTAINER COM 6 ABAS)
# ------------------------------------------------------------------------------
func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	# Fundo semi-transparente para o painel de dev
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 0.94)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "=== LUNARIA ONLINE: DEV MANAGER (F9) ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	status_label = Label.new()
	status_label.text = "✦ Pronto. Escolha uma ferramenta nas abas abaixo para disparar ações instantâneas no servidor."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(status_label)

	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)

	# Monta cada uma das 6 Abas funcionais
	_build_tab_races()
	_build_tab_classes()
	_build_tab_world()
	_build_tab_items()
	_build_tab_bestiary()
	_build_tab_teleports()

	var close_btn := Button.new()
	close_btn.text = "Fechar Dev Manager (F9)"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(func(): close_menu())
	vbox.add_child(close_btn)

# ------------------------------------------------------------------------------
# ABA 1: 🧬 RAÇAS (TODAS AS 28 LINHAGENS)
# ------------------------------------------------------------------------------
func _build_tab_races() -> void:
	var page := VBoxContainer.new()
	page.name = "🧬 Raças"
	page.add_theme_constant_override("separation", 10)
	tab_container.add_child(page)

	var lbl := Label.new()
	lbl.text = "Painel da aba 🧬 Raças em funcionamento."
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	page.add_child(lbl)

	# Barra Superior com botão de Entidade Divina/Maligna
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	page.add_child(top_h)

	var entity_test_btn := _create_action_btn("👑 Testar Tela da Entidade Divina/Maligna (Modal de Escolha)", Color(0.55, 0.35, 0.1), func():
		var world = get_parent()
		if world and world.get("entity_offer_ui"):
			world.entity_offer_ui.open_offer(1)
			_set_status("Modal de Oferta de Evolução da Entidade aberto para teste!")
		else:
			_set_status("EntityOfferUI não encontrada no nó World.")
	)
	top_h.add_child(entity_test_btn)

	var tip_lbl := Label.new()
	tip_lbl.text = "Clique em [Ativar Raça] para alterar visual, modelo 3D e status no Servidor (ActionMode=99)."
	tip_lbl.add_theme_font_size_override("font_size", 11)
	tip_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	top_h.add_child(tip_lbl)

	# Lista Rolável de Raças
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var v_cards := VBoxContainer.new()
	v_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_cards.add_theme_constant_override("separation", 8)
	scroll.add_child(v_cards)

	for r in RACES_DATA:
		var card := _create_race_card(r)
		v_cards.add_child(card)

func _create_race_card(race: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.07, 0.09, 0.14, 0.95)
	var col: Color = race["color"]
	p_style.border_color = Color(col.r, col.g, col.b, 0.6)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 8
	p_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", p_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vb)

	var title_h := HBoxContainer.new()
	title_h.add_theme_constant_override("separation", 8)
	info_vb.add_child(title_h)

	var name_lbl := Label.new()
	name_lbl.text = "#%02d %s" % [race["id"], race["name"]]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", col)
	title_h.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = "[%s]" % race["badge"]
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title_h.add_child(badge_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "Atributos Base: %s" % race["stats"]
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	info_vb.add_child(stats_lbl)

	var pass_lbl := Label.new()
	pass_lbl.text = "Passiva: %s" % race["passive"]
	pass_lbl.add_theme_font_size_override("font_size", 11)
	pass_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	info_vb.add_child(pass_lbl)

	var z_lbl := Label.new()
	z_lbl.text = "Habilidade [Z]: %s" % race["skill_z"]
	z_lbl.add_theme_font_size_override("font_size", 11)
	z_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	info_vb.add_child(z_lbl)

	var activate_btn := Button.new()
	activate_btn.text = " Ativar Raça "
	activate_btn.custom_minimum_size = Vector2(120, 36)
	activate_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.9)
	b_style.border_color = col
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(6)
	activate_btn.add_theme_stylebox_override("normal", b_style)
	var rid: int = race["id"]
	var rname: String = race["name"]
	activate_btn.pressed.connect(func(): _activate_race_dev(rid, rname))
	hbox.add_child(activate_btn)

	return panel

func _activate_race_dev(race_id: int, race_name: String) -> void:
	print("[DevManagerUI] Solicitando Raça Dev #%d (%s)..." % [race_id, race_name])
	var world = get_tree().current_scene
	if not world or not world.has_method("request_class_or_race_change"):
		world = get_parent()
	if world and world.has_method("request_class_or_race_change"):
		world.request_class_or_race_change(true, race_id, 1, race_name, "DEV F9")
		_set_status("Confirmação de Raça aberta para: #%d %s!" % [race_id, race_name])
	else:
		var nm := get_node_or_null("/root/NetworkManager")
		if nm:
			nm.send_select_identity(race_id, 0, 99)
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player._change_race(race_id)
		_set_status("Raça ativada diretamente: #%d %s (ActionMode=99)!" % [race_id, race_name])

# ------------------------------------------------------------------------------
# ABA 2: ⚔️ CLASSES & NÍVEL (15 CLASSES + TIERS 1 A 6)
# ------------------------------------------------------------------------------
func _build_tab_classes() -> void:
	var page := VBoxContainer.new()
	page.name = "⚔️ Classes"
	page.add_theme_constant_override("separation", 10)
	tab_container.add_child(page)

	var lbl := Label.new()
	lbl.text = "Painel da aba ⚔️ Classes em funcionamento."
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	page.add_child(lbl)

	# 1. Painel de Nível Rápido (Sem NPC)
	var lvl_panel := PanelContainer.new()
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	lp_style.border_color = Color(0.85, 0.7, 0.25, 0.6)
	lp_style.set_border_width_all(1)
	lp_style.set_corner_radius_all(6)
	lp_style.content_margin_left = 12
	lp_style.content_margin_right = 12
	lp_style.content_margin_top = 8
	lp_style.content_margin_bottom = 8
	lvl_panel.add_theme_stylebox_override("panel", lp_style)
	page.add_child(lvl_panel)

	var lvl_vb := VBoxContainer.new()
	lvl_vb.add_theme_constant_override("separation", 6)
	lvl_panel.add_child(lvl_vb)

	var lvl_title := Label.new()
	lvl_title.text = "📈 CONTROLE RÁPIDO DE NÍVEL & STATUS (Pacote 0x22 — Cmd 8):"
	lvl_title.add_theme_font_size_override("font_size", 12)
	lvl_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lvl_vb.add_child(lvl_title)

	var lvl_hb := HBoxContainer.new()
	lvl_hb.add_theme_constant_override("separation", 8)
	lvl_vb.add_child(lvl_hb)

	lvl_hb.add_child(_create_action_btn("⬆️ +1 Nível", Color(0.18, 0.45, 0.25), func():
		_net().send_dev_level_control(1)
		_set_status("Comando enviado: +1 Nível (pontos de status concedidos conforme Tier).")
	))
	lvl_hb.add_child(_create_action_btn("⬆️ +5 Níveis", Color(0.2, 0.55, 0.3), func():
		_net().send_dev_level_control(5)
		_set_status("Comando enviado: +5 Níveis adicionados!")
	))
	lvl_hb.add_child(_create_action_btn("👑 Nível Máximo (50)", Color(0.65, 0.5, 0.15), func():
		_net().send_dev_level_control(50)
		_set_status("Comando enviado: Definido Nível 50 Máximo!")
	))
	lvl_hb.add_child(_create_action_btn("💖 Full HP/Stam + 20 Pts Status", Color(0.2, 0.6, 0.7), func():
		_net().send_dev_level_control(99)
		_set_status("Comando enviado: 100% HP/Stamina restaurados e +20 StatPoints livres!")
	))
	lvl_hb.add_child(_create_action_btn("🔄 Resetar Nv. 1", Color(0.6, 0.2, 0.2), func():
		_net().send_dev_level_control(0)
		_set_status("Comando enviado: Resetado para Nível 1 e atributos alocados limpos.")
	))

	# 2. Seletor de Tier de Raridade
	var tier_box := HBoxContainer.new()
	tier_box.add_theme_constant_override("separation", 6)
	page.add_child(tier_box)

	var t_lbl := Label.new()
	t_lbl.text = "🎯 Tier de Raridade Ativo: "
	t_lbl.add_theme_font_size_override("font_size", 12)
	t_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	tier_box.add_child(t_lbl)

	tier_buttons.clear()
	for i in range(1, 7):
		var t_btn := Button.new()
		t_btn.text = " %s " % TIER_NAMES[i]
		t_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		t_btn.add_theme_font_size_override("font_size", 11)
		var tid: int = i
		t_btn.pressed.connect(func(): _select_tier(tid))
		tier_box.add_child(t_btn)
		tier_buttons.append(t_btn)
	_update_tier_buttons_visual()

	# 3. Lista das 15 Classes
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var v_cards := VBoxContainer.new()
	v_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_cards.add_theme_constant_override("separation", 8)
	scroll.add_child(v_cards)

	for c in CLASSES_DEV_DATA:
		var card := _create_class_card(c)
		v_cards.add_child(card)

func _select_tier(tier_id: int) -> void:
	selected_tier = tier_id
	_update_tier_buttons_visual()
	_set_status("Tier ativo alterado para: %s" % TIER_NAMES[tier_id])

func _update_tier_buttons_visual() -> void:
	for i in range(tier_buttons.size()):
		var tid: int = i + 1
		var btn: Button = tier_buttons[i]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)
		if tid == selected_tier:
			style.bg_color = Color(0.2, 0.45, 0.75, 0.95)
			style.border_color = TIER_COLORS[tid]
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
		else:
			style.bg_color = Color(0.1, 0.12, 0.16, 0.8)
			style.border_color = Color(0.3, 0.35, 0.45)
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		btn.add_theme_stylebox_override("normal", style)

func _create_class_card(c_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.07, 0.09, 0.14, 0.95)
	var col: Color = c_data["color"]
	p_style.border_color = Color(col.r, col.g, col.b, 0.6)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 8
	p_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", p_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vb)

	var title_lbl := Label.new()
	title_lbl.text = "Classe #%02d: %s" % [c_data["id"], c_data["name"]]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", col)
	info_vb.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = c_data["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	info_vb.add_child(desc_lbl)

	var pass_lbl := Label.new()
	pass_lbl.text = "Passiva: %s" % c_data["passive"]
	pass_lbl.add_theme_font_size_override("font_size", 11)
	pass_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	info_vb.add_child(pass_lbl)

	var skills_lbl := Label.new()
	skills_lbl.text = "Habilidades: [Q] %s | [R] %s | [F] %s" % [c_data["skill_q"], c_data["skill_r"], c_data["skill_f"]]
	skills_lbl.add_theme_font_size_override("font_size", 11)
	skills_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	info_vb.add_child(skills_lbl)

	var set_btn := Button.new()
	set_btn.text = " Definir Classe & Tier "
	set_btn.custom_minimum_size = Vector2(160, 36)
	set_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.9)
	b_style.border_color = col
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(6)
	set_btn.add_theme_stylebox_override("normal", b_style)
	var cid: int = c_data["id"]
	var cname: String = c_data["name"]
	set_btn.pressed.connect(func(): _activate_class_dev(cid, cname))
	hbox.add_child(set_btn)

	return panel

func _activate_class_dev(class_id: int, target_class_name: String) -> void:
	print("[DevManagerUI] Solicitando Classe Dev #%d (%s) no Tier %d..." % [class_id, target_class_name, selected_tier])
	var world = get_tree().current_scene
	if not world or not world.has_method("request_class_or_race_change"):
		world = get_parent()
	if world and world.has_method("request_class_or_race_change"):
		world.request_class_or_race_change(false, class_id, selected_tier, target_class_name, "DEV F9")
		_set_status("Confirmação de Classe aberta para: #%d %s (Tier %d)!" % [class_id, target_class_name, selected_tier])
	else:
		var nm := get_node_or_null("/root/NetworkManager")
		if nm:
			nm.send_select_identity(selected_tier, class_id, 98)
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player._change_class(class_id)
		_set_status("Classe definida: #%d %s no [%s] (ActionMode=98)!" % [class_id, target_class_name, TIER_NAMES[selected_tier]])

# ------------------------------------------------------------------------------
# ABA 3: 🌙 MUNDO, LUA & CLIMA (RELÓGIO, 10 LUAS E 4 CLIMAS)
# ------------------------------------------------------------------------------
func _build_tab_world() -> void:
	var page := VBoxContainer.new()
	page.name = "🌙 Mundo & Lua"
	page.add_theme_constant_override("separation", 14)
	tab_container.add_child(page)

	var lbl := Label.new()
	lbl.text = "Painel da aba 🌙 Mundo & Lua em funcionamento."
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	page.add_child(lbl)

	# 1. CONTROLE DE HORÁRIO DO RELÓGIO
	var sec1_card := PanelContainer.new()
	sec1_card.add_theme_stylebox_override("panel", _get_card_style(Color(0.85, 0.7, 0.25)))
	page.add_child(sec1_card)

	var vb1 := VBoxContainer.new()
	vb1.add_theme_constant_override("separation", 8)
	sec1_card.add_child(vb1)

	var s1_title := Label.new()
	s1_title.text = "🕒 1. RELÓGIO DO MUNDO (Pacote 0x22 — Cmd 1 Avançar / Cmd 4 Definir Exato)"
	s1_title.add_theme_font_size_override("font_size", 13)
	s1_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vb1.add_child(s1_title)

	var h_times := HBoxContainer.new()
	h_times.add_theme_constant_override("separation", 8)
	vb1.add_child(h_times)

	h_times.add_child(_create_action_btn("⏩ +1 Hora", Color(0.2, 0.45, 0.7), func():
		_net().send_skip_time(1)
		_set_status("Avançado +1 hora no relógio do servidor.")
	))
	h_times.add_child(_create_action_btn("⏩ +6 Horas", Color(0.2, 0.45, 0.7), func():
		_net().send_skip_time(6)
		_set_status("Avançado +6 horas no relógio do servidor.")
	))

	var hour_presets: Array = [
		{"name": "03:00 Madrugada (Esgotos)", "val": 3},
		{"name": "06:00 Amanhecer", "val": 6},
		{"name": "12:00 Meio-Dia", "val": 12},
		{"name": "18:00 Anoitecer", "val": 18},
		{"name": "00:00 Meia-Noite", "val": 0}
	]
	for hp in hour_presets:
		var btn := _create_action_btn(hp["name"], Color(0.25, 0.35, 0.5), func():
			_net().send_set_hour(hp["val"])
			_set_status("Horário definido diretamente para %s." % hp["name"])
		)
		h_times.add_child(btn)

	# 2. CONTROLE DAS 10 FASES DA LUA
	var sec2_card := PanelContainer.new()
	sec2_card.add_theme_stylebox_override("panel", _get_card_style(Color(0.7, 0.5, 0.9)))
	page.add_child(sec2_card)

	var vb2 := VBoxContainer.new()
	vb2.add_theme_constant_override("separation", 8)
	sec2_card.add_child(vb2)

	var s2_title := Label.new()
	s2_title.text = "🌙 2. FASES DA LUA (Pacote 0x22 — Cmd 2 Ciclar / Cmd 5 Definir Exato) — Ativa Bosses em Cheia (4) e Sangue (8)"
	s2_title.add_theme_font_size_override("font_size", 13)
	s2_title.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	vb2.add_child(s2_title)

	var h_moon_cycle := HBoxContainer.new()
	vb2.add_child(h_moon_cycle)
	h_moon_cycle.add_child(_create_action_btn("⏭ Passar Próxima Fase da Lua", Color(0.45, 0.25, 0.75), func():
		_net().send_cycle_moon()
		_set_status("Ciclando para a próxima fase da lua no servidor.")
	))

	var grid_moon := GridContainer.new()
	grid_moon.columns = 5
	grid_moon.add_theme_constant_override("h_separation", 6)
	grid_moon.add_theme_constant_override("v_separation", 6)
	vb2.add_child(grid_moon)

	var moons: Array = [
		{"name": "0: Lua Nova", "val": 0, "col": Color(0.25, 0.28, 0.35)},
		{"name": "1: Lua Crescente", "val": 1, "col": Color(0.3, 0.35, 0.45)},
		{"name": "2: Quarto Crescente", "val": 2, "col": Color(0.35, 0.4, 0.55)},
		{"name": "3: Gibosa Crescente", "val": 3, "col": Color(0.3, 0.35, 0.45)},
		{"name": "4: Lua Cheia 🌕 [Lobo Alfa]", "val": 4, "col": Color(0.85, 0.65, 0.15)},
		{"name": "5: Gibosa Minguante", "val": 5, "col": Color(0.35, 0.4, 0.55)},
		{"name": "6: Quarto Minguante", "val": 6, "col": Color(0.3, 0.35, 0.45)},
		{"name": "7: Lua Minguante", "val": 7, "col": Color(0.25, 0.4, 0.6)},
		{"name": "8: Lua de Sangue 🩸 [Licantropo]", "val": 8, "col": Color(0.8, 0.2, 0.2)},
		{"name": "9: Eclipse Total 🌑", "val": 9, "col": Color(0.5, 0.15, 0.65)}
	]
	for m in moons:
		var btn := _create_action_btn(m["name"], m["col"], func():
			_net().send_set_moon(m["val"])
			_set_status("Fase da Lua definida para: %s!" % m["name"])
		)
		grid_moon.add_child(btn)

	# 3. CONTROLE DE CLIMA
	var sec3_card := PanelContainer.new()
	sec3_card.add_theme_stylebox_override("panel", _get_card_style(Color(0.2, 0.7, 0.7)))
	page.add_child(sec3_card)

	var vb3 := VBoxContainer.new()
	vb3.add_theme_constant_override("separation", 8)
	sec3_card.add_child(vb3)

	var s3_title := Label.new()
	s3_title.text = "⛈️ 3. CONTROLE DE CLIMA (Pacote 0x22 — Cmd 3 Alternar / Cmd 6 Definir Exato)"
	s3_title.add_theme_font_size_override("font_size", 13)
	s3_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.9))
	vb3.add_child(s3_title)

	var h_weather := HBoxContainer.new()
	h_weather.add_theme_constant_override("separation", 8)
	vb3.add_child(h_weather)

	h_weather.add_child(_create_action_btn("⏭ Alternar Clima", Color(0.2, 0.5, 0.6), func():
		_net().send_cycle_weather()
		_set_status("Ciclando para o próximo clima no servidor.")
	))

	var weathers: Array = [
		{"name": "☀ Limpo (0)", "val": 0, "col": Color(0.25, 0.5, 0.35)},
		{"name": "🌧 Chuva / Tempestade (1)", "val": 1, "col": Color(0.35, 0.45, 0.6)},
		{"name": "🌫 Neblina Densa (2)", "val": 2, "col": Color(0.5, 0.55, 0.65)},
		{"name": "🩸 Névoa Carmesim (3)", "val": 3, "col": Color(0.75, 0.25, 0.35)}
	]
	for w in weathers:
		var btn := _create_action_btn(w["name"], w["col"], func():
			_net().send_set_weather(w["val"])
			_set_status("Clima definido para: %s!" % w["name"])
		)
		h_weather.add_child(btn)

# ------------------------------------------------------------------------------
# ABA 4: 🎒 DROPS & ITENS (TAXAS DE DROP + PEGAR QUALQUER ITEM)
# ------------------------------------------------------------------------------
func _build_tab_items() -> void:
	var page := VBoxContainer.new()
	page.name = "📦 Drops"
	page.add_theme_constant_override("separation", 10)
	tab_container.add_child(page)

	var lbl := Label.new()
	lbl.text = "Painel da aba 📦 Drops em funcionamento."
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	page.add_child(lbl)

	# Destaques do Topo
	var top_box := HBoxContainer.new()
	top_box.add_theme_constant_override("separation", 10)
	page.add_child(top_box)

	top_box.add_child(_create_action_btn("📦 Pegar Kit Completo dos 12 Equipamentos", Color(0.18, 0.45, 0.25), func():
		_net().send_give_item(255)
		_set_status("Comando enviado: Kit Completo dos 12 Equipamentos entregue no inventário!")
	))

	top_box.add_child(_create_action_btn("🧪 +5 Frascos de Vidro Vazios", Color(0.25, 0.45, 0.65), func():
		_net().send_give_item(1)
		_set_status("Comando enviado: +5 Frascos adicionados ao inventário!")
	))

	top_box.add_child(_create_action_btn("📊 Abrir Tabela Flutuante de Drop Rates", Color(0.4, 0.25, 0.65), func():
		var world = get_parent()
		if world and world.get("dev_drop_rates_ui"):
			world.dev_drop_rates_ui.toggle_menu()
		_net().send_dev_get_drop_rates()
		_set_status("Painel de Taxas de Drop alternado e sincronizado com o servidor!")
	))

	# Lista de Itens Organizados por Categoria
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var v_items := VBoxContainer.new()
	v_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_items.add_theme_constant_override("separation", 8)
	scroll.add_child(v_items)

	var cat_titles: Dictionary = {
		"UTIL": "🧪 1. Utilitários & Consumíveis",
		"ANAT": "🦴 2. Partes Anatômicas & Órgãos de Autópsia",
		"EQUIP": "🛡️ 3. Equipamentos dos 12 Slots",
		"SECRET": "✨ 4. Relíquias Secretas de 0.1% Drop Rate"
	}

	for cat_code in ["UTIL", "ANAT", "EQUIP", "SECRET"]:
		var cat_lbl := Label.new()
		cat_lbl.text = cat_titles[cat_code]
		cat_lbl.add_theme_font_size_override("font_size", 13)
		cat_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if cat_code == "SECRET" else Color(0.8, 0.9, 1.0))
		v_items.add_child(cat_lbl)

		for it in ITEMS_DATA:
			if it["cat"] != cat_code:
				continue
			var card := _create_item_card(it)
			v_items.add_child(card)

		v_items.add_child(HSeparator.new())

func _create_item_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	var is_secret: bool = item.get("secret", false)
	p_style.border_color = Color(0.9, 0.75, 0.25, 0.9) if is_secret else Color(0.3, 0.4, 0.55, 0.5)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(5)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 6
	p_style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", p_style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.add_theme_constant_override("separation", 2)
	hb.add_child(info_vb)

	var title_h := HBoxContainer.new()
	title_h.add_theme_constant_override("separation", 8)
	info_vb.add_child(title_h)

	var name_lbl := Label.new()
	name_lbl.text = "#%02d %s" % [item["id"], item["name"]]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if is_secret else Color(0.9, 0.95, 1.0))
	title_h.add_child(name_lbl)

	var slot_lbl := Label.new()
	slot_lbl.text = "[%s]" % item["slot"]
	slot_lbl.add_theme_font_size_override("font_size", 10)
	slot_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	title_h.add_child(slot_lbl)

	var rate_lbl := Label.new()
	rate_lbl.text = "Drop: %s" % item["rate"]
	rate_lbl.add_theme_font_size_override("font_size", 10)
	rate_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4) if is_secret else Color(0.5, 0.9, 0.6))
	title_h.add_child(rate_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	info_vb.add_child(desc_lbl)

	var give_btn := Button.new()
	give_btn.text = " + Pegar Item "
	give_btn.custom_minimum_size = Vector2(100, 30)
	give_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.2, 0.4, 0.25, 0.9)
	b_style.border_color = Color(0.35, 0.85, 0.45)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(5)
	give_btn.add_theme_stylebox_override("normal", b_style)
	var iid: int = item["id"]
	var iname: String = item["name"]
	give_btn.pressed.connect(func():
		_net().send_give_item(iid)
		_set_status("Item #%d (%s) adicionado diretamente ao inventário!" % [iid, iname])
	)
	hb.add_child(give_btn)

	return panel

# ------------------------------------------------------------------------------
# ABA 5: 🐉 BESTIÁRIO (CRIATURAS, STATUS & DROPS)
# ------------------------------------------------------------------------------
func _build_tab_bestiary() -> void:
	var page := VBoxContainer.new()
	page.name = "🐉 Bestiário"
	page.add_theme_constant_override("separation", 10)
	tab_container.add_child(page)

	var lbl := Label.new()
	lbl.text = "Painel da aba 🐉 Bestiário em funcionamento."
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	page.add_child(lbl)

	var header_lbl := Label.new()
	header_lbl.text = "Catálogo completo de monstros e chefes de Lunaria. Teleporte para suas zonas ou colete seus drops diretamente."
	header_lbl.add_theme_font_size_override("font_size", 11)
	header_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	page.add_child(header_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var v_mobs := VBoxContainer.new()
	v_mobs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_mobs.add_theme_constant_override("separation", 8)
	scroll.add_child(v_mobs)

	for m in BESTIARY_DATA:
		var card := _create_mob_card(m)
		v_mobs.add_child(card)

func _create_mob_card(mob: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	var col: Color = mob["color"]
	p_style.border_color = Color(col.r, col.g, col.b, 0.7)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 8
	p_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", p_style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	panel.add_child(hb)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.add_theme_constant_override("separation", 2)
	hb.add_child(info_vb)

	var title_h := HBoxContainer.new()
	title_h.add_theme_constant_override("separation", 8)
	info_vb.add_child(title_h)

	var name_lbl := Label.new()
	name_lbl.text = mob["name"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", col)
	title_h.add_child(name_lbl)

	var loc_lbl := Label.new()
	loc_lbl.text = "[%s]" % mob["zone"]
	loc_lbl.add_theme_font_size_override("font_size", 10)
	loc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	title_h.add_child(loc_lbl)

	var stat_lbl := Label.new()
	stat_lbl.text = "Status: %s | Velocidade: %s" % [mob["hp"], mob["speed"]]
	stat_lbl.add_theme_font_size_override("font_size", 10)
	stat_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	info_vb.add_child(stat_lbl)

	var spawn_lbl := Label.new()
	spawn_lbl.text = "Condição de Spawn: %s" % mob["spawn"]
	spawn_lbl.add_theme_font_size_override("font_size", 10)
	spawn_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	info_vb.add_child(spawn_lbl)

	var tac_lbl := Label.new()
	tac_lbl.text = "Tática: %s" % mob["tactics"]
	tac_lbl.add_theme_font_size_override("font_size", 10)
	tac_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	info_vb.add_child(tac_lbl)

	var drop_lbl := Label.new()
	drop_lbl.text = "Drops & Órgãos: %s" % mob["drops_desc"]
	drop_lbl.add_theme_font_size_override("font_size", 10)
	drop_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	info_vb.add_child(drop_lbl)

	# Botoes de Ação
	var btn_vb := VBoxContainer.new()
	btn_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vb.add_theme_constant_override("separation", 6)
	hb.add_child(btn_vb)

	var tp_btn := Button.new()
	tp_btn.text = " Teleportar até a Zona "
	tp_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tp_btn.add_theme_font_size_override("font_size", 10)
	var zid: int = mob["zone_id"]
	var zname: String = mob["zone"]
	tp_btn.pressed.connect(func():
		_net().send_dev_teleport(zid)
		_set_status("Teleportando até a zona: %s (Destino #%d)!" % [zname, zid])
	)
	btn_vb.add_child(tp_btn)

	var loot_btn := Button.new()
	loot_btn.text = " Pegar Drops desta Criatura "
	loot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	loot_btn.add_theme_font_size_override("font_size", 10)
	var loot_ids: Array = mob["loot_ids"]
	var mname: String = mob["name"]
	loot_btn.pressed.connect(func():
		for lid in loot_ids:
			_net().send_give_item(lid)
		_set_status("Drops da criatura %s adicionados ao inventário!" % mname)
	)
	btn_vb.add_child(loot_btn)

	return panel

# ------------------------------------------------------------------------------
# ABA 6: ⚡ TELEPORTES & FERRAMENTAS EXTRAS
# ------------------------------------------------------------------------------
func _build_tab_teleports() -> void:
	var page := VBoxContainer.new()
	page.name = "⚡ Teleportes"
	page.add_theme_constant_override("separation", 14)
	tab_container.add_child(page)

	var lbl := Label.new()
	lbl.text = "Painel da aba ⚡ Teleportes em funcionamento."
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	page.add_child(lbl)

	# 1. Teleportes Instantâneos (Pacote 0x22 Cmd 9 via 0x36 RESPAWN)
	var sec1_card := PanelContainer.new()
	sec1_card.add_theme_stylebox_override("panel", _get_card_style(Color(0.2, 0.6, 0.85)))
	page.add_child(sec1_card)

	var vb1 := VBoxContainer.new()
	vb1.add_theme_constant_override("separation", 8)
	sec1_card.add_child(vb1)

	var s1_title := Label.new()
	s1_title.text = "🚀 1. TELEPORTES INSTANTÂNEOS SEGUROS (Pacote 0x22 — Cmd 9 com Proteção I-Frame 0x36):"
	s1_title.add_theme_font_size_override("font_size", 13)
	s1_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vb1.add_child(s1_title)

	var grid_tp := GridContainer.new()
	grid_tp.columns = 4
	grid_tp.add_theme_constant_override("h_separation", 8)
	grid_tp.add_theme_constant_override("v_separation", 8)
	vb1.add_child(grid_tp)

	var teleports: Array = [
		{"name": "🏛️ Praça Central da Vila (0, 0)", "val": 0, "col": Color(0.2, 0.35, 0.55)},
		{"name": "⛪ Igreja da Luz (-20, -15)", "val": 1, "col": Color(0.55, 0.5, 0.2)},
		{"name": "🔮 Torre do Mago (20, -15)", "val": 2, "col": Color(0.45, 0.25, 0.6)},
		{"name": "🐀 Entrada dos Esgotos (-21, -19)", "val": 3, "col": Color(0.35, 0.4, 0.3)},
		{"name": "🌲 Bosque Sussurrante (52, -42)", "val": 4, "col": Color(0.25, 0.5, 0.3)},
		{"name": "⚔️ Ruínas da Vigília (0, 62)", "val": 5, "col": Color(0.6, 0.35, 0.2)},
		{"name": "🌑 Santuário do Eclipse (-82, 82)", "val": 6, "col": Color(0.65, 0.15, 0.35)}
	]
	for tp in teleports:
		var btn := _create_action_btn(tp["name"], tp["col"], func():
			_net().send_dev_teleport(tp["val"])
			_set_status("Teleportando com segurança para %s..." % tp["name"])
		)
		grid_tp.add_child(btn)

	# 2. Ferramentas Extras de Simulação
	var sec2_card := PanelContainer.new()
	sec2_card.add_theme_stylebox_override("panel", _get_card_style(Color(0.85, 0.4, 0.2)))
	page.add_child(sec2_card)

	var vb2 := VBoxContainer.new()
	vb2.add_theme_constant_override("separation", 8)
	sec2_card.add_child(vb2)

	var s2_title := Label.new()
	s2_title.text = "🔬 2. SIMULAÇÃO DE PUZZLE ANATÔMICO & AUTOPSIA:"
	s2_title.add_theme_font_size_override("font_size", 13)
	s2_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	vb2.add_child(s2_title)

	var h_autopsy := HBoxContainer.new()
	h_autopsy.add_theme_constant_override("separation", 10)
	vb2.add_child(h_autopsy)

	h_autopsy.add_child(_create_action_btn("🔬 Abrir Autópsia de Teste (Simular Puzzle Anatômico)", Color(0.55, 0.2, 0.3), func():
		var world = get_parent()
		if world and world.get("autopsy_ui"):
			var test_organs: Array = [
				{"index": 0, "name": "Coração Lupino Pulsante", "rarity": 2, "hp": 100, "cut_zone": 50},
				{"index": 1, "name": "Glândula de Bruma Noturna", "rarity": 3, "hp": 100, "cut_zone": 60},
				{"index": 2, "name": "Núcleo Etéreo Cristalizado", "rarity": 4, "hp": 100, "cut_zone": 75}
			]
			world.autopsy_ui.open_autopsy(9999, 1, 12345, test_organs)
			_set_status("Interface de Autópsia de Teste aberta com 3 órgãos simulados!")
		else:
			_set_status("AutopsyUI não encontrada no nó World.")
	))

	# 3. Monitor de Provações Secretas (Trials Tracker)
	var sec3_card := PanelContainer.new()
	sec3_card.add_theme_stylebox_override("panel", _get_card_style(Color(0.4, 0.8, 0.4)))
	page.add_child(sec3_card)

	var vb3 := VBoxContainer.new()
	vb3.add_theme_constant_override("separation", 8)
	sec3_card.add_child(vb3)

	var s3_title := Label.new()
	s3_title.text = "🏆 3. MONITOR DE PROVAÇÕES SECRETAS (CLASSES SECRETAS 19 A 27):"
	s3_title.add_theme_font_size_override("font_size", 13)
	s3_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	vb3.add_child(s3_title)

	trials_label = Label.new()
	trials_label.add_theme_font_size_override("font_size", 11)
	trials_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vb3.add_child(trials_label)
	_update_trials_label()

	var h_trials := HBoxContainer.new()
	h_trials.add_theme_constant_override("separation", 8)
	vb3.add_child(h_trials)

	h_trials.add_child(_create_action_btn("+1 Untouched Kill (Meta 10 - Astral)", Color(0.2, 0.45, 0.3), func():
		untouched_kills += 1
		_update_trials_label()
		_set_status("Untouched Kills: %d/10" % untouched_kills)
	))
	h_trials.add_child(_create_action_btn("+1 Low HP Kill (Meta 5 - Inquisidor)", Color(0.55, 0.25, 0.25), func():
		low_hp_kills += 1
		_update_trials_label()
		_set_status("Low HP Kills: %d/5" % low_hp_kills)
	))
	h_trials.add_child(_create_action_btn("+1 Autópsia Perfeita (Meta 5 - Necro)", Color(0.25, 0.45, 0.55), func():
		perfect_autopsies_streak += 1
		_update_trials_label()
		_set_status("Perfect Autopsies Streak: %d/5" % perfect_autopsies_streak)
	))
	h_trials.add_child(_create_action_btn("Resetar Provações Dev", Color(0.4, 0.15, 0.15), func():
		untouched_kills = 0
		low_hp_kills = 0
		perfect_autopsies_streak = 0
		_update_trials_label()
		_set_status("Contadores de provações resetados.")
	))

func _update_trials_label() -> void:
	if not trials_label:
		return
	trials_label.text = "• Untouched Kills (Sem sofrer dano): %d/10 (Dançarino Astral)\n• Low HP Kills (HP <= 30%%): %d/5 (Inquisidor das Cinzas)\n• Perfect Autopsies Streak: %d/5 (Necromante de Ossos)" % [
		untouched_kills, low_hp_kills, perfect_autopsies_streak
	]

# ------------------------------------------------------------------------------
# HELPERS DE ESTILO E FEEDBACK
# ------------------------------------------------------------------------------
func _create_action_btn(text: String, bg_color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = " " + text + " "
	btn.add_theme_font_size_override("font_size", 11)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(bg_color.r * 1.3, bg_color.g * 1.3, bg_color.b * 1.3, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
	btn.pressed.connect(callback)
	return btn

func _get_card_style(border_col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	s.border_color = border_col
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = "[DEV F10] " + msg
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

## Acesso ao autoload NetworkManager sem depender do identificador global (compila também com --check-only).
func _net() -> Node:
	return get_node("/root/NetworkManager")
