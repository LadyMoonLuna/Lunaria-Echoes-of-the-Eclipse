extends CanvasLayer

signal identity_confirmed(race_id: int, class_id: int)

var selected_race: int = 1
var is_open: bool = false

# Metadados Completos das Raças de Lunaria Online
const RACES_DATA := {
	1: {
		"name": "Valeriano",
		"title": "Humano — Nobreza da Coroa Solar",
		"lore": "Descendentes do império solar dourado de Valéria. Disciplinados, honrados e equilibrados em corpo e mente.",
		"color": Color("#4fc3f7"),
		"accent": Color("#ffd54f"),
		"stats": {"FOR": 6, "DES": 6, "CON": 6, "AGI": 6, "INT": 6, "ESP": 6, "PER": 7, "SOR": 7},
		"skill_z_name": "Ímpeto Valeriano",
		"skill_z_desc": "Restaura +40 Stamina, cura +25 HP e concede +25% de dano bônus por 10s (Recarga: 10s).",
		"passive_name": "Fôlego Real",
		"passive_desc": "+15% de regeneração contínua de Stamina em combate.",
		"order_evo": "Alto Valeriano (Ordem: Estandarte Dourado da Coroa, Liderança Imperial)",
		"chaos_evo": "Andarilho do Éter (Caos: Rasga fendas no espaço, distorção e dano etéreo)",
		"npc_reaction": "Garrick: 'Cidadão de Valéria! Nossas forjas forjaram o império. Venha aprender o aço comigo!'"
	},
	2: {
		"name": "Noctari",
		"title": "Elfo da Lua — Guardião Astral do Véu",
		"lore": "Filhos da Noite Eterna e das estrelas cadentes. Canalizadores naturais de energias astrais e magias lunares.",
		"color": Color("#b388ff"),
		"accent": Color("#ea80fc"),
		"stats": {"FOR": 4, "DES": 8, "CON": 4, "AGI": 8, "INT": 9, "ESP": 7, "PER": 5, "SOR": 5},
		"skill_z_name": "Explosão Lunar / Umbral",
		"skill_z_desc": "Onda estelar radial (5.5m) que causa dano mágico elevado e cura +30 HP (Recarga: 10s).",
		"passive_name": "Passo Astral",
		"passive_desc": "+25% de dano e chance crítica sob a noite (dobrado na Lua Cheia).",
		"order_evo": "Arconte Lunar (Ordem: Brilho sagrado de Selene, cura e purificação celestial)",
		"chaos_evo": "Espectro Umbral (Caos: Véu de Nyx, passos invisíveis e emboscada nas trevas)",
		"npc_reaction": "Lyra: 'Ah, sangue Noctari... O luar em suas veias ressoa perfeitamente com a Alquimia!'"
	},
	3: {
		"name": "Kharad",
		"title": "Forjado das Cinzas — Artífice Pétreo da Montanha",
		"lore": "Nascidos nas forjas profundas e fortalezas subterrâneas. Sua pele é dura como granito e seu coração arde como magma.",
		"color": Color("#ffb74d"),
		"accent": Color("#ff9800"),
		"stats": {"FOR": 9, "DES": 4, "CON": 10, "AGI": 3, "INT": 4, "ESP": 6, "PER": 9, "SOR": 5},
		"skill_z_name": "Baluarte Rúnico / Erupção",
		"skill_z_desc": "Onda de choque vulcânica (4.5m) de dano sísmico e escudo de 70% de redução por 5s (Recarga: 10s).",
		"passive_name": "Postura de Rocha",
		"passive_desc": "Reduz passivamente 20% de todo dano recebido e concede firmeza contra atordoamento.",
		"order_evo": "Guardião Rúnico (Ordem: Aço sagrado e runas defensivas intransponíveis)",
		"chaos_evo": "Titã de Obsidiana (Caos: Magma ardente das profundezas e cataclismos de fogo)",
		"npc_reaction": "Garrick: 'Irmão Kharad! O calor da bigorna queima no seu peito! A forja te aguarda!'"
	},
	4: {
		"name": "Varkai",
		"title": "Sangue-Feral — Predador Primordial das Selvas",
		"lore": "Descendentes de linhagens draconianas e lupinas ancestrais. Dotados de sentidos apurados e ferocidade selvagem.",
		"color": Color("#ff5252"),
		"accent": Color("#ff1744"),
		"stats": {"FOR": 8, "DES": 7, "CON": 7, "AGI": 8, "INT": 3, "ESP": 4, "PER": 6, "SOR": 7},
		"skill_z_name": "Sopro Dracônico / Rugido Predatório",
		"skill_z_desc": "Cone frontal feroz (5.5m) de alto impacto com roubo de vida por inimigo atingido (Recarga: 10s).",
		"passive_name": "Sangue Fervilhante",
		"passive_desc": "+20% de dano aumentado e tenacidade quando a vida cair abaixo de 35%.",
		"order_evo": "Soberano Dracônico (Ordem: Chamas reais ancestrais, nobreza e asas de dragão)",
		"chaos_evo": "Fera do Frenesi (Caos: Instinto sanguinário incontrolável e fúria devastadora)",
		"npc_reaction": "Capitão Randel: 'Controle seus instintos ferozes dentro das muralhas, Varkai, e você será um grande trunfo!'"
	},
	5: {
		"name": "Dhampir",
		"title": "Linhagem Sanguínea — Vampiro Crepuscular",
		"lore": "Híbridos entre a mortalidade e a maldição dos vampiros nobres, sedentos por essência vital.",
		"color": Color("#e91e63"), "accent": Color("#ad1457"),
		"stats": {"FOR": 8, "DES": 9, "CON": 6, "AGI": 9, "INT": 8, "ESP": 3, "PER": 6, "SOR": 6},
		"skill_z_name": "Sede de Sangue", "skill_z_desc": "Drena 45 HP do alvo num estalo sombrio.",
		"passive_name": "Vampirismo Inato", "passive_desc": "+10% de Roubo de Vida passivo.",
		"order_evo": "Lorde Noturno", "chaos_evo": "Vampiro Carmesim", "npc_reaction": "Lyra: 'Cuidado para não morder nossos cidadãos!'"
	},
	6: {
		"name": "Licantropo Primordial",
		"title": "Fera da Lua — Alfa Ancestral",
		"lore": "Lobisomens puros despertados pela energia da lua cheia, dotados de força esmagadora.",
		"color": Color("#ff6f00"), "accent": Color("#e65100"),
		"stats": {"FOR": 12, "DES": 9, "CON": 11, "AGI": 10, "INT": 2, "ESP": 3, "PER": 7, "SOR": 6},
		"skill_z_name": "Uivo da Fera Ancestral", "skill_z_desc": "Aterroriza inimigos em 8m e ganha velocidade de ataque.",
		"passive_name": "Fúria Lupina", "passive_desc": "+25% dano sob a noite.",
		"order_evo": "Guardião da Matilha", "chaos_evo": "Lupino Devorador", "npc_reaction": "Garrick: 'Um verdadeiro titã da floresta!'"
	},
	7: {
		"name": "Revenant",
		"title": "Espectro da Cripta — Retornado das Cinzas",
		"lore": "Espíritos guerreiros amaldiçoados que rejeitaram os portões do além.",
		"color": Color("#a7ffeb"), "accent": Color("#00bfa5"),
		"stats": {"FOR": 7, "DES": 6, "CON": 9, "AGI": 5, "INT": 9, "ESP": 10, "PER": 6, "SOR": 3},
		"skill_z_name": "Pacto das Cinzas", "skill_z_desc": "Explosão de cinzas em 5m prendendo inimigos.",
		"passive_name": "Tenacidade Fúnebre", "passive_desc": "Sobrevive por 4s com 1 HP ao receber dano letal.",
		"order_evo": "Cavaleiro do Túmulo", "chaos_evo": "Arauto da Desolação", "npc_reaction": "Capitão Randel: 'Ele respira... mas parece que veio da cripta.'"
	},
	8: {
		"name": "Celestino",
		"title": "Natus Solaris — Emissário do Sol Divino",
		"lore": "Abordados por chamas sagradas dos arcontes celestes que purificam corrupções.",
		"color": Color("#fff176"), "accent": Color("#ffd700"),
		"stats": {"FOR": 6, "DES": 6, "CON": 7, "AGI": 7, "INT": 10, "ESP": 12, "PER": 6, "SOR": 8},
		"skill_z_name": "Chama Sagrada", "skill_z_desc": "Feixe purificador solar que queima inimigos e cura aliados.",
		"passive_name": "Aura Radiante", "passive_desc": "Dano contínuo de calor sagrado ao redor de dia.",
		"order_evo": "Serafim Dourado", "chaos_evo": "Chama da Purgação", "npc_reaction": "Lyra: 'Uma bênção viva dos céus!'"
	},
	9: {
		"name": "Abissal",
		"title": "Umbralis — Filho das Sombras Cósmicas",
		"lore": "Seres que vagam entre o vácuo interdimensional e o espaço estelar.",
		"color": Color("#7c4dff"), "accent": Color("#651fff"),
		"stats": {"FOR": 6, "DES": 7, "CON": 8, "AGI": 6, "INT": 12, "ESP": 8, "PER": 6, "SOR": 5},
		"skill_z_name": "Mergulho Abissal", "skill_z_desc": "Teleporta pelo éter detonando ondas de vácuo.",
		"passive_name": "Corpo de Éter", "passive_desc": "12% de chance de evasão total.",
		"order_evo": "Mago do Vácuo", "chaos_evo": "Singularidade Negra", "npc_reaction": "Garrick: 'Sua presença arrepia os pelos da forja.'"
	},
	10: {
		"name": "Autômato Rúnico",
		"title": "Gélido Mecânico — Colosso da Forja Ancestral",
		"lore": "Construído por antigos artífices rúnicos, animado por um núcleo de éter eterno.",
		"color": Color("#00e5ff"), "accent": Color("#00b0ff"),
		"stats": {"FOR": 10, "DES": 5, "CON": 12, "AGI": 4, "INT": 8, "ESP": 6, "PER": 10, "SOR": 4},
		"skill_z_name": "Sobrecarga Arcana", "skill_z_desc": "Descarga de alta voltagem atordoando oponentes em 6m.",
		"passive_name": "Blindagem de Adamante", "passive_desc": "-20% de dano físico e imunidade a venenos.",
		"order_evo": "Sentinela Rúnica", "chaos_evo": "Colosso de Sobrecarga", "npc_reaction": "Garrick: 'Arte mecânica incomparável!'"
	},
	11: {
		"name": "Alto Valeriano",
		"title": "Evolução da Ordem — Estandarte da Coroa",
		"lore": "O apogeu da linhagem solar imperial valeriana com liderança e honra supremas.",
		"color": Color("#ffd700"), "accent": Color("#ffea00"),
		"stats": {"FOR": 10, "DES": 8, "CON": 9, "AGI": 8, "INT": 9, "ESP": 9, "PER": 9, "SOR": 9},
		"skill_z_name": "Estandarte Real", "skill_z_desc": "Cura aliados (+50 HP) e concede +35% de dano solar.",
		"passive_name": "Soberania da Coroa", "passive_desc": "+30% de Stamina máxima e fôlego ininterrupto.",
		"order_evo": "Ascendido", "chaos_evo": "Nenhum", "npc_reaction": "Capitão Randel: 'Saudai o imperador da luz!'"
	},
	12: {
		"name": "Andarilho do Éter",
		"title": "Evolução do Caos — Rasgador da Tapeçaria",
		"lore": "Valeriano que abraçou a distorção dimensional, dominando o espaço e a gravidade.",
		"color": Color("#ba68c8"), "accent": Color("#e040fb"),
		"stats": {"FOR": 8, "DES": 10, "CON": 7, "AGI": 12, "INT": 10, "ESP": 8, "PER": 10, "SOR": 10},
		"skill_z_name": "Fenda Dimensional", "skill_z_desc": "Teleporta 6 metros liberando explosão de vácuo.",
		"passive_name": "Forma Etérea", "passive_desc": "18% de chance de ignorar golpes recebidos.",
		"order_evo": "Nenhum", "chaos_evo": "Ascendido", "npc_reaction": "Lyra: 'O espaço ao seu redor dobra-se!'"
	},
	13: {
		"name": "Arconte Lunar",
		"title": "Evolução da Ordem — Santidade de Selene",
		"lore": "Noctari agraciado com a luz purificadora da Deusa Selene.",
		"color": Color("#00e5ff"), "accent": Color("#80d8ff"),
		"stats": {"FOR": 5, "DES": 11, "CON": 6, "AGI": 11, "INT": 14, "ESP": 11, "PER": 8, "SOR": 8},
		"skill_z_name": "Luz de Selene", "skill_z_desc": "Pilar de luz lunar em 6m curando +70 HP e cegando inimigos.",
		"passive_name": "Coração Estelar", "passive_desc": "+40% de poder mágico sob qualquer luar.",
		"order_evo": "Ascendido", "chaos_evo": "Nenhum", "npc_reaction": "Lyra: 'A pureza de Selene caminha entre nós.'"
	},
	14: {
		"name": "Espectro Umbral",
		"title": "Evolução do Caos — Sombra de Nyx",
		"lore": "Noctari consumido pelo manto das trevas absolutas e assassinatos noturnos.",
		"color": Color("#7c4dff"), "accent": Color("#b388ff"),
		"stats": {"FOR": 6, "DES": 13, "CON": 5, "AGI": 14, "INT": 12, "ESP": 9, "PER": 11, "SOR": 9},
		"skill_z_name": "Manto de Nyx", "skill_z_desc": "Invisibilidade de 4s com +120% de dano crítico no primeiro golpe.",
		"passive_name": "Assassino das Trevas", "passive_desc": "+35% de velocidade e +30% crítico permanente.",
		"order_evo": "Nenhum", "chaos_evo": "Ascendido", "npc_reaction": "Capitão Randel: 'Fique onde posso ver seus olhos!'"
	},
	15: {
		"name": "Guardião Rúnico",
		"title": "Evolução da Ordem — Muralha de Adamante",
		"lore": "Kharad abençoado com as runas sagradas de proteção inabalável.",
		"color": Color("#ffb74d"), "accent": Color("#ffe082"),
		"stats": {"FOR": 13, "DES": 6, "CON": 15, "AGI": 5, "INT": 7, "ESP": 9, "PER": 12, "SOR": 7},
		"skill_z_name": "Muralha Rúnica", "skill_z_desc": "Absorve 85% de dano por 6s e reflete 50% de volta.",
		"passive_name": "Baluarte Inabalável", "passive_desc": "Imune a controle de grupo e +400 HP Máximo.",
		"order_evo": "Ascendido", "chaos_evo": "Nenhum", "npc_reaction": "Garrick: 'Uma fortaleza viva!'"
	},
	16: {
		"name": "Titã de Obsidiana",
		"title": "Evolução do Caos — Fogo do Centro da Terra",
		"lore": "Kharad que canalizou o magma primitivo tornando seu corpo uma erupção contínua.",
		"color": Color("#ff3d00"), "accent": Color("#ff6e40"),
		"stats": {"FOR": 15, "DES": 5, "CON": 17, "AGI": 4, "INT": 6, "ESP": 7, "PER": 10, "SOR": 6},
		"skill_z_name": "Erupção Magma", "skill_z_desc": "Gêiser vulcânico de 5.5m incendiando inimigos.",
		"passive_name": "Corpo Magmático", "passive_desc": "Retaliação contínua de fogo contra atacantes.",
		"order_evo": "Nenhum", "chaos_evo": "Ascendido", "npc_reaction": "Garrick: 'A terra treme sob seus passos!'"
	},
	17: {
		"name": "Soberano Dracônico",
		"title": "Evolução da Ordem — Majestade Dracônica",
		"lore": "Varkai que refinou seu sangue draconiano para a dignidade de um dragão ancestral.",
		"color": Color("#e53935"), "accent": Color("#ff1744"),
		"stats": {"FOR": 13, "DES": 10, "CON": 11, "AGI": 11, "INT": 6, "ESP": 7, "PER": 9, "SOR": 10},
		"skill_z_name": "Chamas Reais", "skill_z_desc": "Sopro colunar de 7m de chamas com roubo de vida massivo.",
		"passive_name": "Escamas do Soberano", "passive_desc": "Reduz 35% do dano mágico recebido.",
		"order_evo": "Ascendido", "chaos_evo": "Nenhum", "npc_reaction": "Capitão Randel: 'Uma força digna de liderar exércitos!'"
	},
	18: {
		"name": "Fera do Frenesi",
		"title": "Evolução do Caos — Carnificina Incontrolável",
		"lore": "Varkai que sucumbiu completamente aos instintos predatórios assassinos.",
		"color": Color("#ad1457"), "accent": Color("#c2185b"),
		"stats": {"FOR": 14, "DES": 11, "CON": 10, "AGI": 13, "INT": 4, "ESP": 5, "PER": 10, "SOR": 11},
		"skill_z_name": "Frenesi Destruidor", "skill_z_desc": "4 garras rápidas consecutivas com roubo de vida.",
		"passive_name": "Carnificina Feral", "passive_desc": "Abates curam +20% de HP total instantaneamente.",
		"order_evo": "Nenhum", "chaos_evo": "Ascendido", "npc_reaction": "Capitão Randel: 'Segure sua fúria, soldado!'"
	},
	19: {
		"name": "Sylvari",
		"title": "Nascido da Seiva — Espírito Vegetal",
		"lore": "Filhos da Grande Árvore Ancestral em comunhão perfeita com a floresta.",
		"color": Color("#81c784"), "accent": Color("#4caf50"),
		"stats": {"FOR": 5, "DES": 7, "CON": 8, "AGI": 6, "INT": 8, "ESP": 10, "PER": 6, "SOR": 5},
		"skill_z_name": "Raízes Vivas", "skill_z_desc": "Prende e drena vida de inimigos em 6m.",
		"passive_name": "Vínculo com a Seiva", "passive_desc": "+3 HP/s contínuo na natureza.",
		"order_evo": "Ancião da Seiva", "chaos_evo": "Brambler Feroz", "npc_reaction": "Lyra: 'Que aroma fresco de folhas!'"
	},
	20: {
		"name": "Esporiano",
		"title": "Myconid — Protetor dos Cogumelos",
		"lore": "Seres fúngicos que habitam cavernas úmidas, manipuladores de toxinas e esporos.",
		"color": Color("#9c27b0"), "accent": Color("#ba68c8"),
		"stats": {"FOR": 4, "DES": 5, "CON": 10, "AGI": 4, "INT": 10, "ESP": 9, "PER": 8, "SOR": 5},
		"skill_z_name": "Nuvem de Esporos", "skill_z_desc": "Nuvem venenosa que cega atacantes em 5m.",
		"passive_name": "Simbiose Fúngica", "passive_desc": "Imunidade total a venenos.",
		"order_evo": "Xamã Micótico", "chaos_evo": "Fungo Voraz", "npc_reaction": "Lyra: 'Cuidado onde espalha seus esporos!'"
	},
	21: {
		"name": "Aracne",
		"title": "Tecelã da Bruma — Fiação Mortal",
		"lore": "Mestiços de aranha capazes de tecer fios de aço imperceptíveis.",
		"color": Color("#eceff1"), "accent": Color("#cfd8dc"),
		"stats": {"FOR": 6, "DES": 11, "CON": 5, "AGI": 10, "INT": 7, "ESP": 4, "PER": 12, "SOR": 5},
		"skill_z_name": "Teia Prateada", "skill_z_desc": "Dispara teia imobilizante por 3s.",
		"passive_name": "Pernas de Seda", "passive_desc": "Imune a reduções de velocidade.",
		"order_evo": "Tecelã da Noite", "chaos_evo": "Aracne Predadora", "npc_reaction": "Capitão Randel: 'Não deixe fios pelo quartel!'"
	},
	22: {
		"name": "Draconato de Cinzas",
		"title": "Escama-Negra — Cria dos Vulcões",
		"lore": "Draconianos nativos de caldeiras de magma com escamas de pura rocha negra.",
		"color": Color("#ff6d00"), "accent": Color("#ff9e80"),
		"stats": {"FOR": 12, "DES": 5, "CON": 12, "AGI": 5, "INT": 8, "ESP": 6, "PER": 6, "SOR": 4},
		"skill_z_name": "Sopro de Cinzas", "skill_z_desc": "Cone frontal de brasas ardentes e fumaça.",
		"passive_name": "Escama-Negra", "passive_desc": "Imunidade a chamas e +15% de armadura.",
		"order_evo": "Dragão da Forja", "chaos_evo": "Cataclismo de Cinzas", "npc_reaction": "Garrick: 'Suas escamas dispensam avental de forja!'"
	},
	23: {
		"name": "Quimera",
		"title": "Costurado — Mutante Bio-Reativo",
		"lore": "Criação alquímica combinando o melhor de diversas espécies predadoras.",
		"color": Color("#76ff03"), "accent": Color("#b2ff59"),
		"stats": {"FOR": 9, "DES": 8, "CON": 9, "AGI": 8, "INT": 6, "ESP": 2, "PER": 10, "SOR": 5},
		"skill_z_name": "Mutação Bioquímica", "skill_z_desc": "Onda bio-ácida frontal adaptativa.",
		"passive_name": "Corpo Reativo", "passive_desc": "+25% resistência ao último dano sofrido.",
		"order_evo": "Quimera Perfeita", "chaos_evo": "Aberração Alfa", "npc_reaction": "Lyra: 'Fascinante resultado biológico!'"
	},
	24: {
		"name": "Boreal",
		"title": "Coração de Geada — Glacial Puro",
		"lore": "Habitantes das geleiras eternas do norte com sangue de gelo inerte.",
		"color": Color("#80d8ff"), "accent": Color("#40c4ff"),
		"stats": {"FOR": 8, "DES": 6, "CON": 9, "AGI": 5, "INT": 9, "ESP": 8, "PER": 6, "SOR": 4},
		"skill_z_name": "Crio-Armadura", "skill_z_desc": "Armadura de cristal de gelo com congelamento radial.",
		"passive_name": "Coração Glacial", "passive_desc": "+25% dano de frio e imunidade a congelamento.",
		"order_evo": "Guardião da Geada", "chaos_evo": "Nevasca Perpétua", "npc_reaction": "Garrick: 'Abaixe a temperatura ao lado da forja!'"
	},
	25: {
		"name": "Thalassiano",
		"title": "Maré Negra — Soberano dos Mares",
		"lore": "Criaturas do abismo oceânico que comandam pressões marinhas violentas.",
		"color": Color("#006064"), "accent": Color("#00b4d8"),
		"stats": {"FOR": 7, "DES": 8, "CON": 7, "AGI": 9, "INT": 9, "ESP": 8, "PER": 5, "SOR": 5},
		"skill_z_name": "Maré Abissal", "skill_z_desc": "Gêiser d'água sob pressão arrastando alvos.",
		"passive_name": "Filho do Oceano", "passive_desc": "+30% velocidade e cura na chuva.",
		"order_evo": "Lorde das Marés", "chaos_evo": "Monstro das Fossas", "npc_reaction": "Lyra: 'Traga água marinha para meus elixires!'"
	},
	26: {
		"name": "Cambion",
		"title": "Sangue de Enxofre — Herdeiro Infernal",
		"lore": "Nascidos de pactos abissais com chamas negras e correntes incandescentes.",
		"color": Color("#c62828"), "accent": Color("#ff5252"),
		"stats": {"FOR": 11, "DES": 8, "CON": 8, "AGI": 7, "INT": 9, "ESP": 2, "PER": 5, "SOR": 6},
		"skill_z_name": "Correntes Infernais", "skill_z_desc": "Correntes do tártaro prendem alvos.",
		"passive_name": "Sangue de Enxofre", "passive_desc": "Converte vida em poder devastador.",
		"order_evo": "Juiz do Inferno", "chaos_evo": "Demônio da Praga", "npc_reaction": "Capitão Randel: 'Sem pactos sombrios aqui!'"
	},
	27: {
		"name": "Nephilim",
		"title": "Híbrido Crepúsculo — Luz e Sombra",
		"lore": "Fruto da união de um anjo e um demônio, equilibrando duas forças primordiais.",
		"color": Color("#ffd700"), "accent": Color("#1a237e"),
		"stats": {"FOR": 9, "DES": 9, "CON": 8, "AGI": 8, "INT": 10, "ESP": 10, "PER": 7, "SOR": 7},
		"skill_z_name": "Julgamento Nephilim", "skill_z_desc": "Feixe duplo divino e sombrio desintegrando defesas.",
		"passive_name": "Dualidade Cósmica", "passive_desc": "Alterna bônus sagrado e necrótico.",
		"order_evo": "Avatar Cósmico", "chaos_evo": "Crepúsculo Eterno", "npc_reaction": "Lyra: 'Que equilíbrio impressionante de auras!'"
	},
	28: {
		"name": "Errante Temporal",
		"title": "Cronomante — Manipulador dos Fios do Tempo",
		"lore": "Místicos que aprenderam a desacelerar e rebobinar o fluxo da ampulheta cósmica.",
		"color": Color("#ffd54f"), "accent": Color("#ffb300"),
		"stats": {"FOR": 5, "DES": 10, "CON": 5, "AGI": 12, "INT": 12, "ESP": 9, "PER": 8, "SOR": 9},
		"skill_z_name": "Reversão Temporal", "skill_z_desc": "Rebobina posição e vida de 3 segundos atrás.",
		"passive_name": "Fios do Tempo", "passive_desc": "-15% no cooldown de habilidades ativas.",
		"order_evo": "Senhor das Linhas Temporais", "chaos_evo": "Anomalia Cronológica", "npc_reaction": "Garrick: 'Espero que não rebobine o ferro da bigorna!'"
	},
	29: {
		"name": "Meio-Celestial",
		"title": "Descendência Divina — Asas de Luz",
		"lore": "Herdeiros de anjos celestes emanando luz dourada e restauração sagrada.",
		"color": Color("#fff59d"), "accent": Color("#ffd700"),
		"stats": {"FOR": 8, "DES": 8, "CON": 8, "AGI": 8, "INT": 9, "ESP": 11, "PER": 7, "SOR": 7},
		"skill_z_name": "Asas de Luz", "skill_z_desc": "Cura +65 HP e restaura +40 Stamina.",
		"passive_name": "Graça Divina", "passive_desc": "+15% de cura e dano sagrado passivo.",
		"order_evo": "Arcanjo Guardião", "chaos_evo": "Solar Radiante", "npc_reaction": "Lyra: 'A bênção do sol brilha em você!'"
	},
	30: {
		"name": "Pyromante",
		"title": "Fogo Vivo — Renascido das Cinzas",
		"lore": "Mestres da combustão que canalizam o elemento ígneo diretamente em seu sangue.",
		"color": Color("#ff3d00"), "accent": Color("#ff6d00"),
		"stats": {"FOR": 6, "DES": 8, "CON": 7, "AGI": 8, "INT": 12, "ESP": 6, "PER": 7, "SOR": 6},
		"skill_z_name": "Combustão", "skill_z_desc": "Explosão de fogo em 6m desferindo 2.8x de dano.",
		"passive_name": "Chama da Vida", "passive_desc": "Revive com 50% de HP uma vez ao receber dano fatal.",
		"order_evo": "Arquimago das Chamas", "chaos_evo": "Fênix Incandescente", "npc_reaction": "Garrick: 'Cuidado para não queimar minha oficina!'"
	},
	31: {
		"name": "Gigante de Gelo",
		"title": "Colosso Glacial (1.45x) — Força das Geleiras",
		"lore": "Estatura colossal e ossos forjados em permafrost indestrutível.",
		"color": Color("#80deea"), "accent": Color("#00e5ff"),
		"stats": {"FOR": 14, "DES": 4, "CON": 15, "AGI": 4, "INT": 6, "ESP": 6, "PER": 9, "SOR": 4},
		"skill_z_name": "Memória Molecular", "skill_z_desc": "Pancada com estalagmites e +350 HP Máximo por 15s.",
		"passive_name": "Massa Glacial", "passive_desc": "Escala de 1.45x e +25% de tenacidade e absorção a frio.",
		"order_evo": "Titã do Inverno", "chaos_evo": "Avalanche Viva", "npc_reaction": "Capitão Randel: 'Abaixe a cabeça ao cruzar o portão!'"
	},
	32: {
		"name": "Drago Terra",
		"title": "Carapaça Telúrica — Muralha de Pedra",
		"lore": "Draconianos telúricos com casca espessa impenetrável como montanhas.",
		"color": Color("#8d6e63"), "accent": Color("#6d4c41"),
		"stats": {"FOR": 12, "DES": 5, "CON": 14, "AGI": 4, "INT": 5, "ESP": 6, "PER": 10, "SOR": 5},
		"skill_z_name": "Insulto Sísmico", "skill_z_desc": "Taunt forçando foco de todos os monstros em 10m.",
		"passive_name": "Carapaça Telúrica", "passive_desc": "-35% de todo dano físico sofrido permanentemente.",
		"order_evo": "Bastião Dracônico", "chaos_evo": "Fissura Vulcânica", "npc_reaction": "Garrick: 'Sua pele é mais dura que minha bigorna!'"
	},
	33: {
		"name": "Drago Água",
		"title": "Maré Dracônica — Soberano das Correntes",
		"lore": "Draconianos fluídos mestres da hidrocinese e ondas marinhas.",
		"color": Color("#29b6f6"), "accent": Color("#0277bd"),
		"stats": {"FOR": 8, "DES": 9, "CON": 9, "AGI": 8, "INT": 9, "ESP": 9, "PER": 7, "SOR": 7},
		"skill_z_name": "Bênção de Netuno", "skill_z_desc": "Onda marítima em cone empurrando e atordoando.",
		"passive_name": "Correnteza", "passive_desc": "+2.5 HP/s na água ou sob chuva torrencial.",
		"order_evo": "Leviatã Sagrado", "chaos_evo": "Tsunami Feral", "npc_reaction": "Lyra: 'A água responde ao seu comando!'"
	},
	34: {
		"name": "Drago Raio",
		"title": "Fulgor Tempestuoso — Eletricidade Áurea",
		"lore": "Draconianos que armazenam megawatts de energia pura em suas escamas.",
		"color": Color("#ffd600"), "accent": Color("#ffff00"),
		"stats": {"FOR": 8, "DES": 11, "CON": 7, "AGI": 12, "INT": 10, "ESP": 5, "PER": 8, "SOR": 7},
		"skill_z_name": "Descarga Elétrica", "skill_z_desc": "Feixe perfurante de choque rápido (1.85x).",
		"passive_name": "Condutor de Alta Tensão", "passive_desc": "+20% de velocidade de movimento.",
		"order_evo": "Relâmpago Dourado", "chaos_evo": "Sobrecarga Tempestuosa", "npc_reaction": "Garrick: 'Faíscas saltam da sua ponta dos dedos!'"
	},
	35: {
		"name": "Drago Místico",
		"title": "Infusão Arcana — Guardião das Runas",
		"lore": "Draconianos com chifres arcanos em espiral e veias pulsando mana.",
		"color": Color("#ab47bc"), "accent": Color("#e1bee7"),
		"stats": {"FOR": 6, "DES": 8, "CON": 8, "AGI": 7, "INT": 13, "ESP": 10, "PER": 6, "SOR": 6},
		"skill_z_name": "Infusão Arcana", "skill_z_desc": "Círculo rúnico concedendo +40% dano mágico por 10s.",
		"passive_name": "Sangue Rúnico", "passive_desc": "+30% de mana e amplificação mágica.",
		"order_evo": "Arquidrago Rúnico", "chaos_evo": "Emanador do Éter", "npc_reaction": "Lyra: 'Runas antigas brilham em seus chifres!'"
	},
	36: {
		"name": "Orc",
		"title": "Fúria Verde — Poder Marcial Implacável",
		"lore": "Guerreiros musculosos que suportam dor extrema e devoram resíduos para cura.",
		"color": Color("#558b2f"), "accent": Color("#76ff03"),
		"stats": {"FOR": 13, "DES": 6, "CON": 13, "AGI": 6, "INT": 3, "ESP": 3, "PER": 9, "SOR": 5},
		"skill_z_name": "Ataque Devastador", "skill_z_desc": "Golpe triplo esmagador (3.2x dano).",
		"passive_name": "Fisiologia Brutal", "passive_desc": "-20% dano sofrido e digestão de carcaças orgânicas.",
		"order_evo": "Chefe de Guerra", "chaos_evo": "Berserker de Sangue", "npc_reaction": "Capitão Randel: 'Use essa força contra os monstros das muralhas!'"
	},
	37: {
		"name": "Anão",
		"title": "Aço e Forja (0.82x) — Mestre da Bigorna",
		"lore": "Ferreiros natos compactos, inabaláveis contra golpes e mestres do martelo.",
		"color": Color("#d7ccc8"), "accent": Color("#8d6e63"),
		"stats": {"FOR": 11, "DES": 5, "CON": 13, "AGI": 4, "INT": 6, "ESP": 7, "PER": 12, "SOR": 5},
		"skill_z_name": "Martelo Ancestral", "skill_z_desc": "Choque de bigorna com atordoamento em 5.5m.",
		"passive_name": "Resistência da Montanha", "passive_desc": "Estatura de 0.82x com firmeza e maestria na forja.",
		"order_evo": "Grão-Forjador", "chaos_evo": "Demolidor Sísmico", "npc_reaction": "Garrick: 'Irmão de barba e aço! A forja é sua casa!'"
	},
	38: {
		"name": "Elfo",
		"title": "Silvestre Esguio — Graça das Copas",
		"lore": "Arqueiros ágeis com passos velozes e comunhão com a brisa florestal.",
		"color": Color("#aed581"), "accent": Color("#c5e1a5"),
		"stats": {"FOR": 5, "DES": 11, "CON": 5, "AGI": 12, "INT": 10, "ESP": 8, "PER": 7, "SOR": 6},
		"skill_z_name": "Disparo Élfico", "skill_z_desc": "Disparo perfurante luminoso de longo alcance.",
		"passive_name": "Graça da Floresta", "passive_desc": "+15% precisão e custo reduzido em rolamentos.",
		"order_evo": "Sentinela Élfica", "chaos_evo": "Rastreador Fantasma", "npc_reaction": "Lyra: 'A leveza élfica é incomparável.'"
	},
	39: {
		"name": "Elfo Solar (Azgher)",
		"title": "Devoto do Sol — Espada Dourada de Azgher",
		"lore": "Elfos desérticos jurados ao Deus Azgher, empunhando lâminas solares sagradas.",
		"color": Color("#ffb300"), "accent": Color("#ffd54f"),
		"stats": {"FOR": 6, "DES": 10, "CON": 6, "AGI": 10, "INT": 11, "ESP": 10, "PER": 7, "SOR": 7},
		"skill_z_name": "Espada Solar de Azgher", "skill_z_desc": "Lâmina incandescente em fogo sagrado purificador.",
		"passive_name": "Bênção de Azgher", "passive_desc": "+25% dano sob sol e céu limpo.",
		"order_evo": "Paladino de Azgher", "chaos_evo": "Labareda Dourada", "npc_reaction": "Lyra: 'Que o sol de Azgher ilumine sua jornada!'"
	},
	40: {
		"name": "Elfo Lunar (Tenebra)",
		"title": "Devoto da Noite — Manto de Tenebra",
		"lore": "Elfos da escuridão jurados à Deusa Tenebra, movendo-se pelas sombras.",
		"color": Color("#5c6bc0"), "accent": Color("#9fa8da"),
		"stats": {"FOR": 5, "DES": 11, "CON": 5, "AGI": 12, "INT": 10, "ESP": 8, "PER": 8, "SOR": 8},
		"skill_z_name": "Manto de Tenebra", "skill_z_desc": "Mergulho nas sombras com ataque crítico garantido.",
		"passive_name": "Véu de Tenebra", "passive_desc": "+30% crítico e passos sem som à noite.",
		"order_evo": "Sacerdote de Tenebra", "chaos_evo": "Lâmina da Penumbra", "npc_reaction": "Capitão Randel: 'Tenebra vela por você nas sombras.'"
	},
	41: {
		"name": "Fadinha",
		"title": "Pó Estelar Alado (0.55x) — Minúscula e Ágil",
		"lore": "Fadas diminutas com asas de borboleta reluzentes, rápidas e curativas.",
		"color": Color("#f48fb1"), "accent": Color("#f8bbd0"),
		"stats": {"FOR": 3, "DES": 10, "CON": 4, "AGI": 13, "INT": 11, "ESP": 11, "PER": 5, "SOR": 10},
		"skill_z_name": "Pó de Fada Estelar", "skill_z_desc": "Nuvem de pó de fada curando aliados e cegando monstros.",
		"passive_name": "Forma Minúscula", "passive_desc": "Escala diminuta de 0.55x e voo leve.",
		"order_evo": "Fada Rainha", "chaos_evo": "Fada Travessa", "npc_reaction": "Lyra: 'Que criaturinha adorável!'"
	},
	42: {
		"name": "Goblin",
		"title": "Trapaceiro Astuto (0.75x) — Mestre das Bombas",
		"lore": "Pequenos e velozes, especialistas em truques sujos, bombas de fumaça e ouro.",
		"color": Color("#7cb342"), "accent": Color("#cddc39"),
		"stats": {"FOR": 6, "DES": 12, "CON": 5, "AGI": 13, "INT": 6, "ESP": 3, "PER": 10, "SOR": 12},
		"skill_z_name": "Truque Sujo Goblin", "skill_z_desc": "Bomba de fumaça e pólvora cegando oponentes.",
		"passive_name": "Trapaceiro Nato", "passive_desc": "Escala de 0.75x e +20% drop de ouro.",
		"order_evo": "Engenheiro Trapaceiro", "chaos_evo": "Gatuno Voraz", "npc_reaction": "Garrick: 'Mantenha as mãos longe dos meus lingotes!'"
	},
	43: {
		"name": "Demi-Humano Escorpião",
		"title": "Aguilhão Peçonhento — Quitina Vorpal",
		"lore": "Híbridos com cauda articulada de escorpião e ferrão venenoso mortal.",
		"color": Color("#6a1b9a"), "accent": Color("#ba68c8"),
		"stats": {"FOR": 9, "DES": 10, "CON": 8, "AGI": 10, "INT": 7, "ESP": 3, "PER": 11, "SOR": 6},
		"skill_z_name": "Aguilhão de Toxina Vorpal", "skill_z_desc": "Estocada rápida de veneno corrosivo.",
		"passive_name": "Quitina Vorpal", "passive_desc": "+20% dano contra alvos envenenados.",
		"order_evo": "Escorpião Rei", "chaos_evo": "Peçonha Mortal", "npc_reaction": "Lyra: 'Seu veneno é valioso para a alquimia!'"
	},
	44: {
		"name": "Demi-Humano Tartaruga",
		"title": "Casco de Titã (1.35x) — Lar Doce Casca",
		"lore": "Híbridos robustos com carapaça gigante impenetrável nas costas.",
		"color": Color("#33691e"), "accent": Color("#81c784"),
		"stats": {"FOR": 9, "DES": 4, "CON": 16, "AGI": 3, "INT": 6, "ESP": 8, "PER": 9, "SOR": 5},
		"skill_z_name": "Lar Doce Casca", "skill_z_desc": "Encolhe na carapaça absorvendo 85% de dano por 4s.",
		"passive_name": "Casco de Titã", "passive_desc": "Escala de 1.35x e -45% dano recebido permanente.",
		"order_evo": "Mestre Quelônio", "chaos_evo": "Tartaruga Fortaleza", "npc_reaction": "Capitão Randel: 'Você é a própria barricada!'"
	},
	45: {
		"name": "Meio-Demônio (Succubus)",
		"title": "Sedução das Trevas — Drenar Força Vital",
		"lore": "Descendentes demoníacos com chifres sedutores e asas de morcego que drenam a vitalidade.",
		"color": Color("#c2185b"), "accent": Color("#f06292"),
		"stats": {"FOR": 8, "DES": 10, "CON": 7, "AGI": 10, "INT": 11, "ESP": 4, "PER": 8, "SOR": 8},
		"skill_z_name": "Drenar Força Vital", "skill_z_desc": "Sifão demoníaco drenando 55 HP do alvo.",
		"passive_name": "Charme Demoníaco", "passive_desc": "25% chance de anular ataques recebidos.",
		"order_evo": "Rainha das Trevas", "chaos_evo": "Succubus Abissal", "npc_reaction": "Lyra: 'Uma aura perigosamente atraente...'"
	},
	46: {
		"name": "Demi-Humano Lobo",
		"title": "Espírito Lupino — Predador da Matilha",
		"lore": "Híbridos lupinos com orelhas e cauda felpuda, velozes e ferozes em combate.",
		"color": Color("#78909c"), "accent": Color("#90a4ae"),
		"stats": {"FOR": 12, "DES": 9, "CON": 10, "AGI": 11, "INT": 3, "ESP": 4, "PER": 8, "SOR": 7},
		"skill_z_name": "Despertar Forma Bestial", "skill_z_desc": "Uivo brutal com +35% velocidade e garras vorazes.",
		"passive_name": "Instinto Lupino", "passive_desc": "+15% dano físico e faro apurado.",
		"order_evo": "Lobo Alfa Guardião", "chaos_evo": "Lobo Feral Devorador", "npc_reaction": "Capitão Randel: 'Um excelente farejador e batedor!'"
	}
}

# Referências de Nós UI
var main_panel: PanelContainer = null
var race_cards: Dictionary = {}
var race_title_label: Label = null
var race_subtitle_label: Label = null
var race_lore_label: Label = null
var stats_grid: GridContainer = null
var stat_labels: Dictionary = {}
var skill_z_card: PanelContainer = null
var skill_z_label: Label = null
var passive_card: PanelContainer = null
var passive_label: Label = null
var evo_order_label: Label = null
var evo_chaos_label: Label = null
var npc_reaction_label: Label = null
var traveler_notice_panel: PanelContainer = null
var confirm_button: Button = null

func _ready() -> void:
	layer = 25
	_build_ui()
	_select_race(selected_race)
	open_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.keycode == KEY_TAB or (event.keycode == KEY_ESCAPE and is_open):
			if is_open:
				close_menu()
			else:
				open_menu()
			get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world_node := get_parent()
	if world_node and world_node.get("local_player") and is_instance_valid(world_node.local_player):
		world_node.local_player.set("is_menu_open", true)

func close_menu() -> void:
	is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var world_node := get_parent()
	if world_node and world_node.get("local_player") and is_instance_valid(world_node.local_player):
		world_node.local_player.set("is_menu_open", false)

func _build_ui() -> void:
	# Fundo Escurecido Scrim
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.85)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	# Container Central
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	# Painel Principal com Borda Dourada Imperial
	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(980, 620)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	panel_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.8)
	panel_style.shadow_size = 18
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	main_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(root_vbox)

	# Cabeçalho Cinematográfico
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	root_vbox.add_child(header_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "LUNARIA: DESPERTAR DAS LINHAGENS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	header_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "Escolha sua Raça Ancestral. Seu sangue ditará suas habilidades inatas e provações divinas."
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 12)
	subtitle_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	header_vbox.add_child(subtitle_lbl)

	# Seletor das 4 Raças Base (Botões/Cartões Horizontais Grandes)
	var races_hbox := HBoxContainer.new()
	races_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	races_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(races_hbox)

	for rid in [1, 2, 3, 4]:
		var r_info: Dictionary = RACES_DATA[rid]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 56)
		btn.text = "%s\n[%s]" % [r_info["name"].to_upper(), r_info["title"].split("—")[0].strip_edges()]
		btn.add_theme_font_size_override("font_size", 12)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): _select_race(rid))
		races_hbox.add_child(btn)
		race_cards[rid] = btn

	# Área de Detalhes da Linhagem (Dividida em 2 Colunas: Esquerda Atributos & Lore, Direita Habilidades & Evoluções)
	var details_hbox := HBoxContainer.new()
	details_hbox.add_theme_constant_override("separation", 18)
	details_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(details_hbox)

	# COLUNA ESQUERDA: Lore, Subtítulo e Atributos Iniciais
	var col_left := VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 8)
	details_hbox.add_child(col_left)

	var lore_panel := PanelContainer.new()
	var lore_style := StyleBoxFlat.new()
	lore_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	lore_style.border_color = Color(0.3, 0.42, 0.6, 0.5)
	lore_style.set_border_width_all(1)
	lore_style.set_corner_radius_all(6)
	lore_style.content_margin_left = 12
	lore_style.content_margin_right = 12
	lore_style.content_margin_top = 10
	lore_style.content_margin_bottom = 10
	lore_panel.add_theme_stylebox_override("panel", lore_style)
	col_left.add_child(lore_panel)

	var lore_vbox := VBoxContainer.new()
	lore_vbox.add_theme_constant_override("separation", 4)
	lore_panel.add_child(lore_vbox)

	race_title_label = Label.new()
	race_title_label.text = "Linhagem: Valeriano"
	race_title_label.add_theme_font_size_override("font_size", 16)
	race_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lore_vbox.add_child(race_title_label)

	race_subtitle_label = Label.new()
	race_subtitle_label.text = "Humano — Cidadão da Coroa"
	race_subtitle_label.add_theme_font_size_override("font_size", 11)
	race_subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	lore_vbox.add_child(race_subtitle_label)

	race_lore_label = Label.new()
	race_lore_label.text = "Lore da Raça..."
	race_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	race_lore_label.add_theme_font_size_override("font_size", 11)
	race_lore_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	lore_vbox.add_child(race_lore_label)

	# Grid de Atributos Base Iniciais (8 atributos)
	var stats_title := Label.new()
	stats_title.text = "ATRIBUTOS BASE INICIAIS DA RAÇA:"
	stats_title.add_theme_font_size_override("font_size", 11)
	stats_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	col_left.add_child(stats_title)

	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", lore_style)
	col_left.add_child(stats_panel)

	stats_grid = GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 6)
	stats_panel.add_child(stats_grid)

	stat_labels.clear()
	var stat_keys := ["FOR", "DES", "CON", "AGI", "INT", "ESP", "PER", "SOR"]
	for k in stat_keys:
		var slot := PanelContainer.new()
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.15, 0.22, 0.85)
		slot_style.border_color = Color(0.35, 0.45, 0.65, 0.4)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(4)
		slot_style.content_margin_left = 6
		slot_style.content_margin_right = 6
		slot_style.content_margin_top = 4
		slot_style.content_margin_bottom = 4
		slot.add_theme_stylebox_override("panel", slot_style)
		stats_grid.add_child(slot)

		var lbl := Label.new()
		lbl.text = "%s: 10" % k
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		slot.add_child(lbl)
		stat_labels[k] = lbl

	# COLUNA DIREITA: Skill [Z], Passiva Inata, Caminho da Ordem vs Caos, e Reação dos NPCs
	var col_right := VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 8)
	details_hbox.add_child(col_right)

	# Card Skill Z
	skill_z_card = PanelContainer.new()
	var skill_style := StyleBoxFlat.new()
	skill_style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	skill_style.border_color = Color(0.2, 0.7, 0.9, 0.6)
	skill_style.set_border_width_all(1)
	skill_style.set_corner_radius_all(6)
	skill_style.content_margin_left = 12
	skill_style.content_margin_right = 12
	skill_style.content_margin_top = 8
	skill_style.content_margin_bottom = 8
	skill_z_card.add_theme_stylebox_override("panel", skill_style)
	col_right.add_child(skill_z_card)

	var sz_vbox := VBoxContainer.new()
	sz_vbox.add_theme_constant_override("separation", 2)
	skill_z_card.add_child(sz_vbox)

	var sz_head := Label.new()
	sz_head.text = "⚡ HABILIDADE RACIAL ATIVA [TECLA Z]:"
	sz_head.add_theme_font_size_override("font_size", 11)
	sz_head.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	sz_vbox.add_child(sz_head)

	skill_z_label = Label.new()
	skill_z_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_z_label.add_theme_font_size_override("font_size", 11)
	sz_vbox.add_child(skill_z_label)

	# Card Passiva Inata
	passive_card = PanelContainer.new()
	var pass_style := skill_style.duplicate()
	pass_style.border_color = Color(0.4, 0.85, 0.4, 0.6)
	passive_card.add_theme_stylebox_override("panel", pass_style)
	col_right.add_child(passive_card)

	var pass_vbox := VBoxContainer.new()
	pass_vbox.add_theme_constant_override("separation", 2)
	passive_card.add_child(pass_vbox)

	var pass_head := Label.new()
	pass_head.text = "🛡️ PASSIVA DE LINHAGEM INATA:"
	pass_head.add_theme_font_size_override("font_size", 11)
	pass_head.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	pass_vbox.add_child(pass_head)

	passive_label = Label.new()
	passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_label.add_theme_font_size_override("font_size", 11)
	pass_vbox.add_child(passive_label)

	# Card Futuras Evoluções (Ordem vs Caos)
	var evo_card := PanelContainer.new()
	var evo_style := skill_style.duplicate()
	evo_style.border_color = Color(0.85, 0.65, 0.25, 0.6)
	evo_card.add_theme_stylebox_override("panel", evo_style)
	col_right.add_child(evo_card)

	var evo_vbox := VBoxContainer.new()
	evo_vbox.add_theme_constant_override("separation", 4)
	evo_card.add_child(evo_vbox)

	var evo_head := Label.new()
	evo_head.text = "🌌 EVOLUÇÕES CÓSMICAS FUTURAS (NÍVEL 10+):"
	evo_head.add_theme_font_size_override("font_size", 11)
	evo_head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	evo_vbox.add_child(evo_head)

	evo_order_label = Label.new()
	evo_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evo_order_label.add_theme_font_size_override("font_size", 11)
	evo_order_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	evo_vbox.add_child(evo_order_label)

	evo_chaos_label = Label.new()
	evo_chaos_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evo_chaos_label.add_theme_font_size_override("font_size", 11)
	evo_chaos_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.6))
	evo_vbox.add_child(evo_chaos_label)

	# Reação dos NPCs
	npc_reaction_label = Label.new()
	npc_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	npc_reaction_label.add_theme_font_size_override("font_size", 11)
	npc_reaction_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	col_right.add_child(npc_reaction_label)

	# Banner de Explicação Obrigatória do Viajante Sem Classe
	traveler_notice_panel = PanelContainer.new()
	var notice_style := StyleBoxFlat.new()
	notice_style.bg_color = Color(0.16, 0.11, 0.04, 0.95)
	notice_style.border_color = Color(0.95, 0.75, 0.25, 0.9)
	notice_style.set_border_width_all(1)
	notice_style.set_corner_radius_all(6)
	notice_style.content_margin_left = 12
	notice_style.content_margin_right = 12
	notice_style.content_margin_top = 8
	notice_style.content_margin_bottom = 8
	traveler_notice_panel.add_theme_stylebox_override("panel", notice_style)
	root_vbox.add_child(traveler_notice_panel)

	var notice_lbl := Label.new()
	notice_lbl.text = "⚔️ AVISO DE JORNADA: Você iniciará sua jornada como um Viajante (Sem Classe). Procure os Mestres na Vila do Refúgio (Garrick, Lyra, Randel) para aprender sua Classe Básica!"
	notice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_lbl.add_theme_font_size_override("font_size", 11)
	notice_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	traveler_notice_panel.add_child(notice_lbl)

	# Botão de Confirmação da Linhagem
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_hbox)

	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(400, 44)
	confirm_button.text = "DESPERTAR COMO VIAJANTE (CONFIRMAR RAÇA)"
	confirm_button.add_theme_font_size_override("font_size", 13)
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.45, 0.22, 0.95)
	btn_style.border_color = Color(0.4, 0.9, 0.45, 0.95)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	var btn_hov := btn_style.duplicate()
	btn_hov.bg_color = Color(0.25, 0.55, 0.28, 1.0)
	confirm_button.add_theme_stylebox_override("normal", btn_style)
	confirm_button.add_theme_stylebox_override("hover", btn_hov)
	confirm_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	confirm_button.pressed.connect(_on_confirm_pressed)
	footer_hbox.add_child(confirm_button)

func _select_race(rid: int) -> void:
	selected_race = rid
	_update_race_button_states()
	_update_race_details()

func _update_race_button_states() -> void:
	for rid in race_cards.keys():
		var btn: Button = race_cards[rid]
		var r_data: Dictionary = RACES_DATA[rid]
		var is_sel: bool = (rid == selected_race)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4

		if is_sel:
			style.bg_color = r_data["color"].darkened(0.65)
			style.border_color = r_data["accent"]
			style.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		else:
			style.bg_color = Color(0.08, 0.1, 0.15, 0.75)
			style.border_color = Color(0.25, 0.32, 0.45, 0.4)
			style.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

func _update_race_details() -> void:
	var r_data: Dictionary = RACES_DATA.get(selected_race, RACES_DATA[1])

	if race_title_label:
		race_title_label.text = "Linhagem Ancestral: %s" % r_data["name"]
		race_title_label.add_theme_color_override("font_color", r_data["accent"])

	if race_subtitle_label:
		race_subtitle_label.text = r_data["title"]

	if race_lore_label:
		race_lore_label.text = r_data["lore"]

	if stats_grid:
		var st: Dictionary = r_data["stats"]
		for k in st.keys():
			if stat_labels.has(k):
				stat_labels[k].text = "%s: %d" % [k, st[k]]

	if skill_z_label:
		skill_z_label.text = "%s\n%s" % [r_data["skill_z_name"], r_data["skill_z_desc"]]

	if passive_label:
		passive_label.text = "%s\n%s" % [r_data["passive_name"], r_data["passive_desc"]]

	if evo_order_label:
		evo_order_label.text = "⚖️ Ordem: %s" % r_data["order_evo"]

	if evo_chaos_label:
		evo_chaos_label.text = "🔥 Caos: %s" % r_data["chaos_evo"]

	if npc_reaction_label:
		npc_reaction_label.text = "🗣️ %s" % r_data["npc_reaction"]

	if confirm_button:
		confirm_button.text = "DESPERTAR COMO VIAJANTE (%s)" % r_data["name"].to_upper()

func _on_confirm_pressed() -> void:
	print("[CharacterSelectUI] Linhagem confirmada: Raça %d (Iniciando como Viajante / Sem Classe 0)" % selected_race)
	identity_confirmed.emit(selected_race, 0)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.get("my_player_id") and nm.my_player_id > 0:
		nm.send_select_identity(selected_race, 0, 0)
	close_menu()
