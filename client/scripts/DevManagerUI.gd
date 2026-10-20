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
# BANCO DE DADOS: 15 CLASSES & HABILIDADES
# ------------------------------------------------------------------------------
const CLASSES_DEV_DATA := [
	{
		"id": 1,
		"name": "Espadachim",
		"desc": "Combatente equilibrado armado com espada longa e escudo de aço temperado.",
		"passive": "Determinação do Aço (+10% defesa e dano melee por FOR)",
		"skill_q": "Corte Crescente (1.75x dano)",
		"skill_r": "Postura de Ferro (70% defesa e parry)",
		"skill_f": "Impacto Sísmico (2.4x dano em raio de 4.5m)",
		"color": Color("#4fc3f7")
	},
	{
		"id": 2,
		"name": "Batedor",
		"desc": "Arqueiro ágil de longo alcance com flechas táticas e passos silenciosos.",
		"passive": "Olho do Falcão (+15% alcance/precisão e +25% crítico na Lua Nova)",
		"skill_q": "Disparo Perfurante (1.75x perfura alvos)",
		"skill_r": "Chuva de Estrepes (lentidão 40% em área)",
		"skill_f": "Saraivada Estelar (3 flechas 2.4x dano)",
		"color": Color("#81c784")
	},
	{
		"id": 3,
		"name": "Iniciado",
		"desc": "Conjurador do éter e magias elementais cósmicas com cajado de foco.",
		"passive": "Ressonância do Éter (+15% magia e +15% dano na Gibosa Crescente)",
		"skill_q": "Cometa Elemental (1.75x dano em área)",
		"skill_r": "Nova de Gelo (congelamento 5m)",
		"skill_f": "Maelstrom Cósmico (2.4x dano em 6.5m)",
		"color": Color("#ba68c8")
	},
	{
		"id": 4,
		"name": "Acólito",
		"desc": "Guerreiro sagrado com maça, talismã e orações solares purificadoras.",
		"passive": "Graça Sagrada (Cura aliados e +20% dano no Quarto Minguante)",
		"skill_q": "Círculo de Luz (1.75x dano e cura +40 HP)",
		"skill_r": "Lança do Julgamento (feixe sagrado 15m)",
		"skill_f": "Égide Sagrada (+65 HP grupo e 2.4x dano)",
		"color": Color("#fff176")
	},
	{
		"id": 5,
		"name": "Ferreiro",
		"desc": "Combatente pesado de forja com martelo colossal e chamas de bigorna.",
		"passive": "Coração de Brasa (+15% dano contundente de FOR e na Gibosa Minguante)",
		"skill_q": "Golpe de Bigorna (1.75x dano)",
		"skill_r": "Afiação de Combate (+25% dano grupo)",
		"skill_f": "Fúria do Vulcão (2.4x frontal 4.5m)",
		"color": Color("#ffb74d")
	},
	{
		"id": 6,
		"name": "Alquimista",
		"desc": "Especialista em frascos cáusticos, névoas corrosivas e reações químicas.",
		"passive": "Mestria Catalítica (Poças corrosivas e quebra de resistências)",
		"skill_q": "Frasco de Éter (1.75x e cura +40 HP)",
		"skill_r": "Bomba de Ácido (poça corrosiva 3.5m)",
		"skill_f": "Detonação Catalítica (2.4x dano em 5.5m)",
		"color": Color("#69f0ae")
	},
	{
		"id": 7,
		"name": "Ceifador do Eclipse",
		"desc": "Classe Secreta: Foice colossal com colheita de almas e roubo de vida pleno.",
		"passive": "Sede Abissal (10% roubo de vida, +40% na Lua de Sangue, +20% no Eclipse)",
		"skill_q": "Colheita Noturna (1.75x dano)",
		"skill_r": "Drenagem Abissal (+45 HP e lentidão)",
		"skill_f": "Dança do Eclipse Total (2.4x dano em 6.0m)",
		"color": Color("#d500f9")
	},
	{
		"id": 8,
		"name": "Artífice Rúnico",
		"desc": "Classe Secreta: Martelo-canhão movido a núcleos estelares e engrenagens.",
		"passive": "Ignição Titanomecânica (Dano híbrido físico/elétrico por FOR e INT)",
		"skill_q": "Salva Rúnica (1.75x em 3 disparos)",
		"skill_r": "Sobrecarga Eletrostática (Raios no grupo)",
		"skill_f": "Bombardeio Titanomecânico (2.4x em 6.5m)",
		"color": Color("#ff6d00")
	},
	{
		"id": 9,
		"name": "Criador de Homúnculos",
		"desc": "Classe Secreta: Vida sintética e quimera transmissora de bioplasma regenerativo.",
		"passive": "Vínculo Quimérico (Mini-Homúnculo regenera mestre e ataca alvos)",
		"skill_q": "Infusão Mutagênica (1.75x dano)",
		"skill_r": "Névoa de Bioplasma (Cura +50 HP e cega em 4.5m)",
		"skill_f": "Frenesi do Quimera Supremo (2.4x em 6m)",
		"color": Color("#00b0ff")
	},
	{
		"id": 10,
		"name": "Dançarino Astral",
		"desc": "Classe Secreta: Duelista cósmico com lâminas estelares duplas em prata e ciano.",
		"passive": "Graça das Constelações (+25% crítico inato e esquiva ao custo de 10 stamina)",
		"skill_q": "Corte Cadente (2.0x dano veloz)",
		"skill_r": "Valsa dos Espelhos (1.5s I-Frame + contra-ataque)",
		"skill_f": "Constelação de Mil Lâminas (3.0x dano em 5.5m)",
		"color": Color("#80d8ff")
	},
	{
		"id": 11,
		"name": "Inquisidor das Cinzas",
		"desc": "Classe Secreta: Executor fanático com mangual e correntes incandescentes carmesins.",
		"passive": "Fervor do Mártir (Até +60% de dano adicional quanto menor for a sua vida atual)",
		"skill_q": "Chicote de Penitência (2.2x + roubo de vida em 8m)",
		"skill_r": "Selo de Excomunhão (+35 HP e queima em 5m)",
		"skill_f": "Crucificação de Cinzas (3.2x dano em 6m)",
		"color": Color("#ff5252")
	},
	{
		"id": 12,
		"name": "Necromante de Ossos",
		"desc": "Classe Secreta: Manipulador sombrio de ossos e crânio de cristal verde-esmeralda.",
		"passive": "Colheita de Ossos (Cura +20 HP instantâneos por monstro abatido)",
		"skill_q": "Lança de Fêmur (2.0x perfurante 16m)",
		"skill_r": "Explosão Óssea & Escudo (5.0m e couraça protetora)",
		"skill_f": "Legião do Ossuário (3.0x dano em 6m)",
		"color": Color("#ccff90")
	},
	{
		"id": 13,
		"name": "Domador Primordial",
		"desc": "Classe Secreta: Guerreiro feral com lança e Lobo Espiritual Prateado leal ao seu lado.",
		"passive": "Espírito Alfa (+25% dano constante de todas as fontes de ataque)",
		"skill_q": "Investida do Alfa (2.1x dano em 5.5m)",
		"skill_r": "Uivo da Alcateia (+50 HP cura e buff de crítico)",
		"skill_f": "Fúria do Behemoth (3.0x frontal sísmico 5m)",
		"color": Color("#ffd740")
	},
	{
		"id": 14,
		"name": "Cavaleiro da Ruptura",
		"desc": "Classe Secreta: Colosso espacial com espada de obsidiana e escudo gravitacional do Vazio.",
		"passive": "Armadura Singular (-30% de todo dano físico e mágico recebido)",
		"skill_q": "Esmagamento Gravitacional (Puxa monstros em 5m + 1.9x)",
		"skill_r": "Singularidade Reversa (Absorve 80% dano e implode)",
		"skill_f": "Colapso Estelar (2.8x em 6.5m + atordoa monstros)",
		"color": Color("#7c4dff")
	},
	{
		"id": 15,
		"name": "Arauto da Tempestade",
		"desc": "Classe Secreta: Avatar dos trovões com alabarda de ouro e relâmpagos celestiais.",
		"passive": "Condutividade Celestial (+35% de dano na Chuva e choque estático ao ser atacado)",
		"skill_q": "Lança do Trovão (2.1x veloz 18m)",
		"skill_r": "Passo de Relâmpago (Surto elétrico 4m + velocidade)",
		"skill_f": "Ira dos Céus (3.1x tempestade de raios em 6m)",
		"color": Color("#40c4ff")
	}
]

# ------------------------------------------------------------------------------
# BANCO DE DADOS: 28 RAÇAS & LINHAGENS
# ------------------------------------------------------------------------------
const RACES_DATA := [
	# Raças Base (1-4)
	{
		"id": 1, "group": "BASE", "name": "Valeriano", "badge": "Base Solar", "color": Color("#ffd700"),
		"stats": "FOR: 6 | DES: 6 | CON: 6 | AGI: 6 | INT: 6 | ESP: 6 | MAS: 7 | SOR: 7",
		"passive": "Linhagem Solar: +10% Regeneração de Stamina durante o dia sob céu limpo.",
		"skill_z": "Bênção Solar [Z]: Pulso radiante purifica debuffs e concede +15% Velocidade por 6s."
	},
	{
		"id": 2, "group": "BASE", "name": "Noctari", "badge": "Base Lunar", "color": Color("#00e5ff"),
		"stats": "FOR: 4 | DES: 8 | CON: 4 | AGI: 8 | INT: 9 | ESP: 7 | MAS: 5 | SOR: 5",
		"passive": "Sintonia Noturna: +15% de Dano Mágico e Esquiva durante as horas da noite.",
		"skill_z": "Manto da Penumbra [Z]: Salto etéreo para as sombras com invisibilidade por 3s."
	},
	{
		"id": 3, "group": "BASE", "name": "Kharad", "badge": "Base Forja", "color": Color("#ff9800"),
		"stats": "FOR: 9 | DES: 4 | CON: 10 | AGI: 3 | INT: 4 | ESP: 6 | MAS: 9 | SOR: 5",
		"passive": "Pele Pétrea: Reduz em 15% todo dano físico recebido e imunidade a sangramento.",
		"skill_z": "Bastião Sísmico [Z]: Bate no solo gerando escudo de 25% do HP Máximo por 5s."
	},
	{
		"id": 4, "group": "BASE", "name": "Varkai", "badge": "Base Feral", "color": Color("#ff5722"),
		"stats": "FOR: 8 | DES: 7 | CON: 7 | AGI: 9 | INT: 3 | ESP: 4 | MAS: 6 | SOR: 6",
		"passive": "Instinto Predador: +20% Velocidade de Movimento e +10% Crítico com armas de corte.",
		"skill_z": "Salto Predatório [Z]: Investida feroz de 8m causando atordoamento de 1.5s."
	},
	# Secretas Clássicas (5-10)
	{
		"id": 5, "group": "SECRET", "name": "Sanguis", "badge": "Secreta Vampírica", "color": Color("#e91e63"),
		"stats": "FOR: 7 | DES: 8 | CON: 5 | AGI: 8 | INT: 8 | ESP: 4 | MAS: 5 | SOR: 5",
		"passive": "Vampirismo: +8% de Roubo de Vida passivo em todos os ataques corporais.",
		"skill_z": "Festim Sanguíneo [Z]: Drena 40 HP do alvo, transferindo-os diretamente para você."
	},
	{
		"id": 6, "group": "SECRET", "name": "Licantropo Primordial", "badge": "Secreta Lupina", "color": Color("#ff6f00"),
		"stats": "FOR: 10 | DES: 6 | CON: 8 | AGI: 9 | INT: 2 | ESP: 5 | MAS: 5 | SOR: 5",
		"passive": "Fúria da Matilha: +25% de Dano Físico e +30% de Velocidade durante Lua Cheia ou Sangue.",
		"skill_z": "Forma Feral [Z]: Uivo aterrorizante que causa lentidão e aumenta o dano em 30% por 8s."
	},
	{
		"id": 7, "group": "SECRET", "name": "Natus Solaris", "badge": "Secreta Solar", "color": Color("#fff176"),
		"stats": "FOR: 6 | DES: 6 | CON: 6 | AGI: 6 | INT: 9 | ESP: 10 | MAS: 4 | SOR: 3",
		"passive": "Aura Radiante: Queima inimigos ao redor (dano contínuo de fogo) durante o dia.",
		"skill_z": "Chama da Criação [Z]: Feixe de luz de 12m que cura aliados e calcina inimigos."
	},
	{
		"id": 8, "group": "SECRET", "name": "Umbralis", "badge": "Secreta Abissal", "color": Color("#7c4dff"),
		"stats": "FOR: 5 | DES: 9 | CON: 5 | AGI: 9 | INT: 9 | ESP: 4 | MAS: 5 | SOR: 4",
		"passive": "Corpo de Éter: 10% de chance de desviar completamente de qualquer golpe físico.",
		"skill_z": "Vácuo Espacial [Z]: Teleporta 6m para frente explodindo vácuo de trevas."
	},
	{
		"id": 9, "group": "SECRET", "name": "Draconato Vulcânico", "badge": "Secreta Dracônica", "color": Color("#d32f2f"),
		"stats": "FOR: 9 | DES: 5 | CON: 9 | AGI: 5 | INT: 7 | ESP: 5 | MAS: 5 | SOR: 5",
		"passive": "Escamas de Magma: Imunidade a queimaduras e +15% de Armadura contra dano cortante.",
		"skill_z": "Sopro Dracônico [Z]: Expele cone de chamas frontais (5m) causando alto dano de fogo."
	},
	{
		"id": 10, "group": "SECRET", "name": "Gélido", "badge": "Secreta Gélida", "color": Color("#80deea"),
		"stats": "FOR: 5 | DES: 7 | CON: 7 | AGI: 5 | INT: 9 | ESP: 8 | MAS: 4 | SOR: 5",
		"passive": "Presença Glacial: Inimigos que te atacam sofrem lentidão temporária de 20%.",
		"skill_z": "Esquife de Gelo [Z]: Congela o alvo por 2s e cria uma barreira protetora de gelo."
	},
	# Evoluções Ordem e Caos (11-18)
	{
		"id": 11, "group": "EVOLUTION", "name": "Alto Valeriano", "badge": "Ordem Solar", "color": Color("#ffe082"),
		"stats": "FOR: 7 | DES: 7 | CON: 7 | AGI: 7 | INT: 7 | ESP: 7 | MAS: 8 | SOR: 8",
		"passive": "Liderança Real: +20% de Stamina máxima e regeneração contínua ininterrupta.",
		"skill_z": "Estandarte Imperial [Z]: Cura +45 HP em aliados e concede +30% Dano por 12s."
	},
	{
		"id": 12, "group": "EVOLUTION", "name": "Andarilho do Éter", "badge": "Caos Cósmico", "color": Color("#ce93d8"),
		"stats": "FOR: 5 | DES: 8 | CON: 5 | AGI: 8 | INT: 10 | ESP: 8 | MAS: 5 | SOR: 5",
		"passive": "Corpo Etéreo: 15% de chance de ignorar completamente qualquer golpe físico ou mágico.",
		"skill_z": "Fenda Dimensional [Z]: Rasga o espaço, teleportando 6m à frente com explosão de vácuo."
	},
	{
		"id": 13, "group": "EVOLUTION", "name": "Arconte Lunar", "badge": "Ordem Selene", "color": Color("#80d8ff"),
		"stats": "FOR: 5 | DES: 9 | CON: 5 | AGI: 9 | INT: 10 | ESP: 8 | MAS: 4 | SOR: 4",
		"passive": "Bênção da Lua: +35% de poder mágico e regeneração contínua sob qualquer fase lunar.",
		"skill_z": "Luz Purificadora [Z]: Cascata lunar de 6m curando +60 HP e cegando inimigos."
	},
	{
		"id": 14, "group": "EVOLUTION", "name": "Espectro Umbral", "badge": "Caos Nyx", "color": Color("#b388ff"),
		"stats": "FOR: 4 | DES: 10 | CON: 4 | AGI: 10 | INT: 9 | ESP: 7 | MAS: 5 | SOR: 5",
		"passive": "Véu Noturno: +30% de velocidade de movimento e +20% de dano crítico permanente.",
		"skill_z": "Manto das Sombras [Z]: Invisibilidade por 4s; o próximo golpe causa +100% de Crítico."
	},
	{
		"id": 15, "group": "EVOLUTION", "name": "Guardião Rúnico", "badge": "Ordem Forja", "color": Color("#ffcc80"),
		"stats": "FOR: 10 | DES: 4 | CON: 11 | AGI: 3 | INT: 5 | ESP: 7 | MAS: 10 | SOR: 4",
		"passive": "Pele de Adamante: Reduz em 25% o dano físico e reflete 15% do impacto.",
		"skill_z": "Armadura Rúnica [Z]: Absorve 80% do dano por 6s e reflete 40% de volta aos agressores."
	},
	{
		"id": 16, "group": "EVOLUTION", "name": "Titã de Obsidiana", "badge": "Caos Magma", "color": Color("#ffab91"),
		"stats": "FOR: 11 | DES: 3 | CON: 11 | AGI: 3 | INT: 5 | ESP: 5 | MAS: 9 | SOR: 7",
		"passive": "Coração Vulcânico: Cada golpe desferido causa dano adicional de fogo por segundo.",
		"skill_z": "Fúria do Vulcão [Z]: Onda de magma de 8m causando atordoamento e queimaduras."
	},
	{
		"id": 17, "group": "EVOLUTION", "name": "Predador Alfa", "badge": "Ordem Alcateia", "color": Color("#ff8a65"),
		"stats": "FOR: 9 | DES: 8 | CON: 8 | AGI: 10 | INT: 3 | ESP: 5 | MAS: 6 | SOR: 5",
		"passive": "Espírito da Alcateia: +20% de dano e velocidade quando acompanhado de aliados.",
		"skill_z": "Uivo Convocador [Z]: Uivo retumbante que aterroriza monstros e bufa aliados."
	},
	{
		"id": 18, "group": "EVOLUTION", "name": "Fera do Frenesi", "badge": "Caos Feral", "color": Color("#ff1744"),
		"stats": "FOR: 10 | DES: 8 | CON: 7 | AGI: 10 | INT: 2 | ESP: 3 | MAS: 7 | SOR: 7",
		"passive": "Sede de Sangue: Cada ataque consecutivo aumenta a velocidade de ataque em +5% (máx 50%).",
		"skill_z": "Garras Sanguinárias [Z]: Salto devastador desferindo 4 cortes rápidos com roubo de vida."
	},
	# Novas Raças Secretas (19-28)
	{
		"id": 19, "group": "NEW", "name": "Revenant da Cripta", "badge": "Morte & Retorno", "color": Color("#a7ffeb"),
		"stats": "FOR: 8 | DES: 6 | CON: 9 | AGI: 6 | INT: 7 | ESP: 8 | MAS: 5 | SOR: 5",
		"passive": "Tenacidade Fúnebre: Ao ter o HP zerado, sobrevive por 4s com 1 HP para lutar.",
		"skill_z": "Abraço do Túmulo [Z]: Mãos cadavéricas brotam do solo prendendo inimigos em 5m."
	},
	{
		"id": 20, "group": "NEW", "name": "Guardião da Aurora", "badge": "Luz Solar", "color": Color("#ffff8d"),
		"stats": "FOR: 7 | DES: 6 | CON: 8 | AGI: 6 | INT: 8 | ESP: 9 | MAS: 5 | SOR: 5",
		"passive": "Luz Imutável: Imunidade a cegueira e +20% de Resistência Mágica.",
		"skill_z": "Escudo da Alvorada [Z]: Barreira solar que protege todo o grupo e queima agressores."
	},
	{
		"id": 21, "group": "NEW", "name": "Ceifador do Crepúsculo", "badge": "Vazio Cósmico", "color": Color("#ea80fc"),
		"stats": "FOR: 7 | DES: 9 | CON: 6 | AGI: 9 | INT: 9 | ESP: 6 | MAS: 4 | SOR: 4",
		"passive": "Sentença de Morte: Golpes contra alvos com menos de 30% HP causam +35% dano.",
		"skill_z": "Foice Espectral [Z]: Giro cósmico de 360 graus cortando o tecido da realidade."
	},
	{
		"id": 22, "group": "NEW", "name": "Draconato de Cinzas", "badge": "Fogo & Fúria", "color": Color("#ff6e40"),
		"stats": "FOR: 9 | DES: 6 | CON: 9 | AGI: 6 | INT: 7 | ESP: 6 | MAS: 6 | SOR: 5",
		"passive": "Bafo de Cinzas: Ataques básicos aplicam queima cumulativa no alvo.",
		"skill_z": "Explosão de Cinzas [Z]: Detona cinzas ardentes em raio de 6m atordoando monstros."
	},
	{
		"id": 23, "group": "NEW", "name": "Tecelão do Éter", "badge": "Tempo & Mana", "color": Color("#b388ff"),
		"stats": "FOR: 4 | DES: 8 | CON: 5 | AGI: 8 | INT: 11 | ESP: 10 | MAS: 4 | SOR: 4",
		"passive": "Fios do Tempo: Reduz o cooldown de todas as suas habilidades ativas em 15%.",
		"skill_z": "Fuso Temporal [Z]: Rebobina a posição e restaura a vida aos valores de 3s atrás."
	},
	{
		"id": 24, "group": "NEW", "name": "Quimera de Obsidiana", "badge": "Rocha & Fogo", "color": Color("#ffab40"),
		"stats": "FOR: 10 | DES: 5 | CON: 10 | AGI: 5 | INT: 6 | ESP: 6 | MAS: 7 | SOR: 5",
		"passive": "Armadura Vulcânica: 20% do dano sofrido é convertido em Stamina instantânea.",
		"skill_z": "Erupção Terrestre [Z]: Espinhos pontiagudos de obsidiana emergem do chão em linha."
	},
	{
		"id": 25, "group": "NEW", "name": "Espírito da Tempestade", "badge": "Raio & Trovão", "color": Color("#80d8ff"),
		"stats": "FOR: 6 | DES: 9 | CON: 6 | AGI: 10 | INT: 9 | ESP: 8 | MAS: 3 | SOR: 3",
		"passive": "Condutância Elétrica: Seus ataques têm 20% de chance de encadear raio elétrico.",
		"skill_z": "Surto Voltaico [Z]: Transforma-se em puro raio percorrendo 10m e eletrocutando alvos."
	},
	{
		"id": 26, "group": "NEW", "name": "Parasita Abissal", "badge": "Sombra & Roubo", "color": Color("#b39ddb"),
		"stats": "FOR: 6 | DES: 8 | CON: 7 | AGI: 8 | INT: 9 | ESP: 6 | MAS: 5 | SOR: 5",
		"passive": "Sifão Vital: Concede bônus permanente temporário ao drenar a força de inimigos.",
		"skill_z": "Tentáculos do Abismo [Z]: Puxa até 3 monstros para perto de você causando dano."
	},
	{
		"id": 27, "group": "NEW", "name": "Aracne Tecelã", "badge": "Veneno & Teia", "color": Color("#a5d6a7"),
		"stats": "FOR: 7 | DES: 9 | CON: 6 | AGI: 9 | INT: 8 | ESP: 5 | MAS: 5 | SOR: 5",
		"passive": "Pernas de Seda: Velocidade de movimento nunca é reduzida por efeitos de lentidão.",
		"skill_z": "Teia Paralisante [Z]: Lança rede de seda densa que imobiliza o alvo por 2.5s."
	},
	{
		"id": 28, "group": "NEW", "name": "Seraphim Corrompido", "badge": "Luz Caída", "color": Color("#ffe082"),
		"stats": "FOR: 8 | DES: 8 | CON: 7 | AGI: 8 | INT: 9 | ESP: 9 | MAS: 3 | SOR: 2",
		"passive": "Graça Maculada: Alterna entre bônus de luz solar de dia e poder do vazio à noite.",
		"skill_z": "Julgamento Maculado [Z]: Feixe divino bipartido de luz pura e trevas simultâneas."
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
	{"id": 30, "name": "Casulo de Seda Prateada", "cat": "SECRET", "slot": "Relíquia Secreta (Aracne)", "rate": "0.1% [SECRETO]", "secret": true, "desc": "Casulo cristalino que abriga os segredos da linhagem Aracne. Drop de feras no Bosque."}
]

# ------------------------------------------------------------------------------
# BANCO DE DADOS: BESTIÁRIO COMPLETO DE LUNARIA (12 CRIATURAS)
# ------------------------------------------------------------------------------
const BESTIARY_DATA := [
	# Bosque Sussurrante (Zona 4)
	{
		"name": "Lobo da Bruma",
		"zone": "Bosque Sussurrante",
		"zone_id": 4,
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
		"zone_id": 4,
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
		"zone_id": 4,
		"hp": "2200 HP",
		"speed": "8.5 m/s",
		"tactics": "Salto letal devastador, ataques que ignoram bloqueio comum e rápida regeneração.",
		"spawn": "🩸 Spawn Exclusivo na LUA DE SANGUE (Fase 8 do Relógio).",
		"drops_desc": "Coração Carmesim (100%), Garras de Sangue (100%), Amuleto do Eclipse (25%), Casulo (2.0%).",
		"loot_ids": [7, 8, 28, 30],
		"color": Color("#e53935")
	},

	# Ruínas da Vigília (Zona 5)
	{
		"name": "Saqueador Deserdado",
		"zone": "Ruínas da Vigília",
		"zone_id": 5,
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
		"zone_id": 5,
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
		"zone_id": 5,
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
		"zone_id": 5,
		"hp": "650 HP",
		"speed": "3.2 m/s",
		"tactics": "Tanque colossal com machado de duas mãos, armadura pesada e atordoamento frontal.",
		"spawn": "Guarda os portões da cidadela e arcos principais.",
		"drops_desc": "Fragmentos de Ferro (100%), Medalhão da Vigília (0.1%), Espada de Ferro (15%).",
		"loot_ids": [10, 16, 20, 21],
		"color": Color("#546e7a")
	},
	{
		"name": "Comandante Vaelen (Boss da Vigília)",
		"zone": "Ruínas da Vigília",
		"zone_id": 5,
		"hp": "3200 HP",
		"speed": "5.5 m/s",
		"tactics": "Mestre de armas: combo veloz de 3 golpes, estocada com parry e redemoinho mortal.",
		"spawn": "Trono da Cidadela nas Ruínas da Vigília.",
		"drops_desc": "Espada de Vaelen (100%), Chave Rúnica da Cripta (0.1%), Armadura Imperial (25%).",
		"loot_ids": [10, 15, 20, 28],
		"color": Color("#ff9800")
	},

	# Santuário do Eclipse (Zona 6)
	{
		"name": "Cultista Sombrio",
		"zone": "Santuário do Eclipse",
		"zone_id": 6,
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
		"zone_id": 6,
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
		"zone_id": 6,
		"hp": "1400 HP",
		"speed": "4.8 m/s",
		"tactics": "Chicote flamejante de correntes carmesins; puxa o jogador e queima continuamente.",
		"spawn": "Pátio dos Sacrifícios no Santuário.",
		"drops_desc": "Correntes da Inquisição (100%), Cinzas Sagradas (100%), Tomo do Ceifador (20%).",
		"loot_ids": [10, 17, 20, 28],
		"color": Color("#d32f2f")
	},
	{
		"name": "Malakor, o Arauto do Eclipse (Raid Boss Supremo)",
		"zone": "Santuário do Eclipse",
		"zone_id": 6,
		"hp": "7500 HP",
		"speed": "6.0 m/s",
		"tactics": "Deus do eclipse: vórtices gravitacionais, chuva de meteoros cósmicos e eclipse total.",
		"spawn": "Câmara Central do Santuário do Eclipse.",
		"drops_desc": "Foice do Eclipse (100%), Coroa de Malakor (100%), Tomo (20%), Cálice da Alma (20%).",
		"loot_ids": [14, 17, 20, 28, 30],
		"color": Color("#d500f9")
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
	print("[DevManagerUI] Ativando Raça Dev #%d (%s) com ActionMode=99..." % [race_id, race_name])
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_select_identity(race_id, 0, 99)
	var world = get_parent()
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
		NetworkManager.send_dev_level_control(1)
		_set_status("Comando enviado: +1 Nível (pontos de status concedidos conforme Tier).")
	))
	lvl_hb.add_child(_create_action_btn("⬆️ +5 Níveis", Color(0.2, 0.55, 0.3), func():
		NetworkManager.send_dev_level_control(5)
		_set_status("Comando enviado: +5 Níveis adicionados!")
	))
	lvl_hb.add_child(_create_action_btn("👑 Nível Máximo (50)", Color(0.65, 0.5, 0.15), func():
		NetworkManager.send_dev_level_control(50)
		_set_status("Comando enviado: Definido Nível 50 Máximo!")
	))
	lvl_hb.add_child(_create_action_btn("💖 Full HP/Stam + 20 Pts Status", Color(0.2, 0.6, 0.7), func():
		NetworkManager.send_dev_level_control(99)
		_set_status("Comando enviado: 100% HP/Stamina restaurados e +20 StatPoints livres!")
	))
	lvl_hb.add_child(_create_action_btn("🔄 Resetar Nv. 1", Color(0.6, 0.2, 0.2), func():
		NetworkManager.send_dev_level_control(0)
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

func _activate_class_dev(class_id: int, class_name: String) -> void:
	print("[DevManagerUI] Definindo Classe Dev #%d (%s) no Tier %d com ActionMode=98..." % [class_id, class_name, selected_tier])
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_select_identity(selected_tier, class_id, 98)
	var world = get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player._change_class(class_id)
	_set_status("Classe definida: #%d %s no [%s] (ActionMode=98)!" % [class_id, class_name, TIER_NAMES[selected_tier]])

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
		NetworkManager.send_skip_time(1)
		_set_status("Avançado +1 hora no relógio do servidor.")
	))
	h_times.add_child(_create_action_btn("⏩ +6 Horas", Color(0.2, 0.45, 0.7), func():
		NetworkManager.send_skip_time(6)
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
			NetworkManager.send_set_hour(hp["val"])
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
		NetworkManager.send_cycle_moon()
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
			NetworkManager.send_set_moon(m["val"])
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
		NetworkManager.send_cycle_weather()
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
			NetworkManager.send_set_weather(w["val"])
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
		NetworkManager.send_give_item(255)
		_set_status("Comando enviado: Kit Completo dos 12 Equipamentos entregue no inventário!")
	))

	top_box.add_child(_create_action_btn("🧪 +5 Frascos de Vidro Vazios", Color(0.25, 0.45, 0.65), func():
		NetworkManager.send_give_item(1)
		_set_status("Comando enviado: +5 Frascos adicionados ao inventário!")
	))

	top_box.add_child(_create_action_btn("📊 Abrir Tabela Flutuante de Drop Rates", Color(0.4, 0.25, 0.65), func():
		var world = get_parent()
		if world and world.get("dev_drop_rates_ui"):
			world.dev_drop_rates_ui.toggle_menu()
		NetworkManager.send_dev_get_drop_rates()
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
		NetworkManager.send_give_item(iid)
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
		NetworkManager.send_dev_teleport(zid)
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
			NetworkManager.send_give_item(lid)
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
			NetworkManager.send_dev_teleport(tp["val"])
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
	s3_title.text = "🏆 3. MONITOR DE PROVAÇÕES SECRETAS (CLASSES SECRETAS 10 A 15):"
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
