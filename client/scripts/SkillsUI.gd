extends CanvasLayer

var is_open: bool = false
var active_tab_index: int = 0

# Dados Raciais para Tab 1
const RACIAL_DETAILS := {
	1: {
		"name": "Valeriano (Humano Solar)",
		"skill_z_name": "Ímpeto Valeriano [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "O sangue solar ferve em suas veias! Restaura imediatamente +40 de Stamina, cura +25 de Vida e concede um bônus de +25% de dano em todos os ataques e habilidades por 10 segundos.",
		"passive_name": "Fôlego Real (Passiva Inata)",
		"passive_desc": "+15% de regeneração contínua de Stamina mesmo durante a execução de ataques e esquivas.",
		"color": Color("#ffd700"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	2: {
		"name": "Noctari (Elfo da Lua)",
		"skill_z_name": "Explosão Lunar / Umbral [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Libera uma detonação mágica estelar em um raio de 5.5m ao redor do jogador, causando dano arcano massivo baseado em Inteligência e curando +30 de Vida instantaneamente.",
		"passive_name": "Passo Astral (Passiva Inata)",
		"passive_desc": "+25% de dano mágico e físico sob o luar noturno. Durante a Lua Cheia, o bônus é dobrado (+50%).",
		"color": Color("#b388ff"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	3: {
		"name": "Kharad (Anão de Pedra & Magma)",
		"skill_z_name": "Baluarte Rúnico / Erupção [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Bate com força telúrica no chão, desferindo uma erupção de magma em raio de 4.5m e ativando um escudo que reduz 70% de todo dano recebido durante 5 segundos.",
		"passive_name": "Postura de Rocha (Passiva Inata)",
		"passive_desc": "Reduz passivamente 20% de todo dano recebido de Monstros e concede imunidade a perda de equilíbrio por golpes pesados.",
		"color": Color("#ff9800"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	4: {
		"name": "Varkai (Sangue Dracônico / Lupino)",
		"skill_z_name": "Sopro Dracônico / Rugido Predatório [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Expele um cone devastador de fogo e garras frontais (5.5m) que despedaça as armaduras inimigas e rouba +20 de Vida para cada alvo atingido pelo ataque.",
		"passive_name": "Sangue Fervilhante (Passiva Inata)",
		"passive_desc": "Quando sua vida cai abaixo de 35%, seus sentidos primordiais entram em hiperatividade, concedendo +20% de dano aumentado e 30% de velocidade de movimento.",
		"color": Color("#ff1744"),
		"status": "Linhagem Base — Pronta para Despertar no Nível 10"
	},
	11: {
		"name": "Alto Valeriano (Ordem Solar)",
		"skill_z_name": "Estandarte Dourado da Coroa [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Ergue o estandarte sagrado imperial, curando +50 HP em aliados, restaurando +60 Stamina e energizando armas com dano solar divino (+35% de dano por 12s).",
		"passive_name": "Soberania da Coroa (Passiva Ascendida)",
		"passive_desc": "+30% de Stamina máxima e regeneração ininterrupta.",
		"color": Color("#ffd700"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	12: {
		"name": "Andarilho do Éter (Caos Espacial)",
		"skill_z_name": "Fenda Dimensional [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Rasga a tapeçaria da realidade, teleportando 6 metros para a direção de movimento e gerando uma explosão de vácuo etéreo que ignora armaduras físicas.",
		"passive_name": "Forma Etérea (Passiva Ascendida)",
		"passive_desc": "18% de chance constante de desviar totalmente de qualquer ataque recebido.",
		"color": Color("#ba68c8"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	},
	21: {
		"name": "Arconte Lunar (Ordem de Selene)",
		"skill_z_name": "Luz Purificadora de Selene [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Invoca um pilar de luz lunar concentrada (6.0m) que purifica aliados curando +70 HP e cega monstros desferindo dano sagrado estelar.",
		"passive_name": "Coração Estelar (Passiva Ascendida)",
		"passive_desc": "+40% de poder mágico sob qualquer fase da lua.",
		"color": Color("#00e5ff"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	22: {
		"name": "Espectro Umbral (Caos de Nyx)",
		"skill_z_name": "Manto de Nyx [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Dissolve seu corpo nas sombras tornando-se invisível por 4 segundos. O próximo ataque desferido após a quebra do manto causa +120% de Dano Crítico garantido.",
		"passive_name": "Assassino das Trevas (Passiva Ascendida)",
		"passive_desc": "+35% de velocidade de movimento e +30% de dano crítico permanente.",
		"color": Color("#7c4dff"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	},
	31: {
		"name": "Guardião Rúnico (Ordem da Bigorna)",
		"skill_z_name": "Muralha Rúnica Ancestral [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Grava runas sagradas de proteção na pele, absorvendo 85% de dano por 6s e refletindo 50% de volta aos atacantes.",
		"passive_name": "Baluarte Inabalável (Passiva Ascendida)",
		"passive_desc": "Imune a qualquer efeito de controle de grupo e bônus de +400 HP Máximo.",
		"color": Color("#ffb74d"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	32: {
		"name": "Titã de Obsidiana (Caos de Magma)",
		"skill_z_name": "Geiser de Magma Profundo [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Racha o solo liberando uma geiser vulcânica de 5.5m que incendeia inimigos causando dano de queimação contínua e repulsão violenta.",
		"passive_name": "Corpo Magmático (Passiva Ascendida)",
		"passive_desc": "Atacantes corpo-a-corpo sofrem retaliação de dano de fogo constante.",
		"color": Color("#ff3d00"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	},
	41: {
		"name": "Soberano Dracônico (Ordem Dracônica)",
		"skill_z_name": "Sopro Real do Dragão Ancestral [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Dispara um sopro colunar de chamas ancestrais de 7.0m que incinera tudo em seu caminho e rouba vida em massa.",
		"passive_name": "Escamas do Soberano (Passiva Ascendida)",
		"passive_desc": "Reduz 35% do dano mágico recebido e amplifica dano elemental em 30%.",
		"color": Color("#e53935"),
		"status": "Linhagem Cósmica Ascendida (Caminho da Ordem)"
	},
	42: {
		"name": "Fera do Frenesi (Caos Sangrento)",
		"skill_z_name": "Frenesi Voraz Sangrento [Z]",
		"skill_z_cost": "Sem custo de Stamina | Recarga: 10.0s",
		"skill_z_desc": "Dispara um salto devastador desferindo 4 garras cortantes rápidas; cada golpe restaura +20 HP e aumenta sua velocidade em 50%.",
		"passive_name": "Carnificina Feral (Passiva Ascendida)",
		"passive_desc": "Abates concedem +20% de cura total instantânea.",
		"color": Color("#ad1457"),
		"status": "Linhagem Cósmica Ascendida (Caminho do Caos)"
	}
}

# Dados de Classes e Habilidades Ativas
const CLASS_ACTIVE_SKILLS := {
	0: { # Viajante
		"name": "Viajante (Sem Classe)",
		"tier_name": "Tier 0 — Aventureiro Iniciante",
		"desc": "Você ainda não escolheu um caminho marcial. Visite os Mestres Garrick, Lyra ou Capitão Randel na Vila do Refúgio para aprender uma Classe Básica!",
		"color": Color("#cfd8dc"),
		"evolved_titles": {
			0: "Aventureiro Iniciante",
			1: "Aventureiro Iniciante",
			2: "Aventureiro Iniciante",
			3: "Aventureiro Iniciante",
			4: "Aventureiro Iniciante",
			5: "Aventureiro Iniciante",
			6: "Aventureiro Iniciante"
		},
		"passive": {
			"name": "Instinto de Sobrevivência",
			"desc": "Sem especialização ativa. +5% de velocidade de movimento ao fugir de perigos.",
			"tier_scaling": "Sem bônus de Tier ativo."
		},
		"basic": {"name": "Golpe Simples [LMB]", "desc": "Pancada inicial desarmada ou com arma improvisada (1.0x dano).", "range": "2.5m", "cost": "0 Stamina", "cd": "0.35s"},
		"q": {"name": "Investida Cautelosa [Q]", "desc": "Passo rápido à frente desferindo uma estocada simples (1.2x dano).", "range": "3.5m", "cost": "15 Stamina", "cd": "2.5s"},
		"r": {"name": "Respirar Fundo [R]", "desc": "Postura defensiva temporária que recupera +15 de Stamina.", "range": "Pessoal", "cost": "0 Stamina", "cd": "6.0s"},
		"f": {"name": "Instinto de Sobrevivência [F]", "desc": "Salto para trás e foco aumentado reduzindo dano recebido por 2s.", "range": "Pessoal", "cost": "20 Stamina", "cd": "12.0s"}
	},
	1: { # Espadachim
		"name": "Espadachim",
		"tier_name": "Tier 1 a Tier 6 (Vanguarda Celestial)",
		"desc": "Combatente corpo a corpo balanceado, mestre de espada e escudo com foco em cortes rápidos, defesas perfeitas e impactos sísmicos.",
		"color": Color("#64b5f6"),
		"evolved_titles": {
			1: "Espadachim Comum",
			2: "Guarda Valente (Incomum)",
			3: "Cavaleiro Rúnico (Rara)",
			4: "Mestre de Armas (Épica)",
			5: "Senhor da Guerra (Única)",
			6: "Vanguarda Celestial (Lendária)"
		},
		"passive": {
			"name": "Determinação Inquebrável",
			"desc": "Reduz passivamente todo dano físico recebido em +10% a +26% e amplifica a taxa de regeneração de Stamina em +15% a +39% enquanto estiver em postura de combate.",
			"tier_scaling": "T1 Comum: 1.0x (10% Red / 15% Regen) | T2 Incomum: 1.20x (12% / 18%) | T3 Rara: 1.45x (14.5% / 21.8%) | T4 Épica: 1.75x (17.5% / 26.3%) | T5 Única: 2.15x (21.5% / 32.3%) | T6 Lendária: 2.60x (26% / 39%)"
		},
		"basic": {"name": "Corte da Lâmina [LMB]", "desc": "Golpe rápido de espada em arco frontal (1.0x dano base).", "range": "3.8m", "cost": "0 Stamina", "cd": "0.35s"},
		"q": {"name": "Corte Crescente [Q]", "desc": "Talho ascendente poderoso que corta alvos em cone amplo (1.75x dano).", "range": "4.2m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Postura de Ferro [R]", "desc": "Parry impenetrável que reduz 70% de dano por 2.5s e causa choque nos inimigos.", "range": "Pessoal", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Impacto Sísmico [F]", "desc": "Salto esmagador cravando a lâmina no solo, liberando onda sísmica de 4.5m (2.4x dano).", "range": "4.5m Radial", "cost": "25 Stamina", "cd": "12.0s"}
	},
	2: { # Batedor
		"name": "Batedor",
		"tier_name": "Tier 1 a Tier 6 (Predador Lunar)",
		"desc": "Atirador veloz de longo alcance armado com arco composto e flechas táticas de controle e perfuração.",
		"color": Color("#69f0ae"),
		"evolved_titles": {
			1: "Batedor Comum",
			2: "Rastreador Silvestre (Incomum)",
			3: "Atirador Furtivo (Rara)",
			4: "Patrulheiro Mestre (Épica)",
			5: "Falcão da Noite (Única)",
			6: "Predador Lunar (Lendária)"
		},
		"passive": {
			"name": "Olho de Lince & Disparo Fatal",
			"desc": "Concede bônus passivo de +12% a +31% de Chance Crítica e +15% a +39% de Velocidade de Movimento permanente.",
			"tier_scaling": "T1 Comum: 1.0x (12% Crítico / 15% Vel) | T2 Incomum: 1.20x (14.4% / 18%) | T3 Rara: 1.45x (17.4% / 21.8%) | T4 Épica: 1.75x (21% / 26.3%) | T5 Única: 2.15x (25.8% / 32.3%) | T6 Lendária: 2.60x (31.2% / 39%)"
		},
		"basic": {"name": "Disparo Rápido [LMB]", "desc": "Flecha balística veloz de longo alcance (1.0x dano).", "range": "16.0m", "cost": "0 Stamina", "cd": "0.30s"},
		"q": {"name": "Disparo Perfurante [Q]", "desc": "Flecha pontiaguda de alta velocidade que atravessa múltiplos alvos (1.75x dano).", "range": "22.0m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Chuva de Estrepes [R]", "desc": "Dispara armadilhas de espinhos que reduzem a movimentação dos monstros em 40% por 3s.", "range": "14.0m", "cost": "20 Stamina", "cd": "6.0s"},
		"f": {"name": "Saraivada Estelar [F]", "desc": "Dispara 3 flechas encantadas simultâneas em cone frontal aberto (2.4x dano total).", "range": "18.0m", "cost": "25 Stamina", "cd": "12.0s"}
	},
	3: { # Iniciado Arcano
		"name": "Iniciado Arcano",
		"tier_name": "Tier 1 a Tier 6 (Feiticeiro do Infinito)",
		"desc": "Conjurador de magias elementais do cosmos, capaz de explodir esferas arcanas e congelar inimigos em área.",
		"color": Color("#ea80fc"),
		"evolved_titles": {
			1: "Iniciado Arcano Comum",
			2: "Aprendiz Elemental (Incomum)",
			3: "Mago Rúnico (Rara)",
			4: "Arquimago das Estrelas (Épica)",
			5: "Sábio Celestial (Única)",
			6: "Feiticeiro do Infinito (Lendária)"
		},
		"passive": {
			"name": "Ressonância Arcana Cósmica",
			"desc": "Amplifica o dano mágico arcano em +15% a +39% e concede regeneração contínua de +20% a +52% de mana/stamina após conjurações.",
			"tier_scaling": "T1 Comum: 1.0x (15% Dano / 20% Regen) | T2 Incomum: 1.20x (18% / 24%) | T3 Rara: 1.45x (21.8% / 29%) | T4 Épica: 1.75x (26.3% / 35%) | T5 Única: 2.15x (32.3% / 43%) | T6 Lendária: 2.60x (39% / 52%)"
		},
		"basic": {"name": "Orbe Arcano [LMB]", "desc": "Projétil de energia cósmica concentrada com velocidade de 16m/s (1.0x dano).", "range": "14.0m", "cost": "0 Stamina", "cd": "0.38s"},
		"q": {"name": "Cometa Elemental [Q]", "desc": "Grande esfera de fogo estelar que explode em um raio de 2.8m (1.75x dano).", "range": "18.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Nova de Gelo [R]", "desc": "Onda congelante de 5.0m radial que paralisa e desacelera monstros por 1.5s.", "range": "5.0m Radial", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Maelstrom Cósmico [F]", "desc": "Tempestade arcana colossal de devastação massiva em raio de 6.5m (2.4x dano).", "range": "6.5m Radial", "cost": "25 Stamina", "cd": "14.0s"}
	},
	4: { # Acólito da Aurora
		"name": "Acólito da Aurora",
		"tier_name": "Tier 1 a Tier 6 (Santo da Aurora Cósmica)",
		"desc": "Guerreiro sagrado empunhando maça e talismã, alternando entre ataques de contusão divina e orações curativas.",
		"color": Color("#ffd54f"),
		"evolved_titles": {
			1: "Acólito da Aurora Comum",
			2: "Clérigo Solene (Incomum)",
			3: "Templário Sagrado (Rara)",
			4: "Bispo Radiante (Épica)",
			5: "Sumo Pontífice (Única)",
			6: "Santo da Aurora Cósmica (Lendária)"
		},
		"passive": {
			"name": "Graça Divina Radiante",
			"desc": "Aumenta a eficácia de todas as curas sagradas em +20% a +52% e cria uma aura protetora que reduz 15% do dano de Trevas sofrido.",
			"tier_scaling": "T1 Comum: 1.0x (20% Cura) | T2 Incomum: 1.20x (24% Cura) | T3 Rara: 1.45x (29% Cura) | T4 Épica: 1.75x (35% Cura) | T5 Única: 2.15x (43% Cura) | T6 Lendária: 2.60x (52% Cura)"
		},
		"basic": {"name": "Golpe da Fé [LMB]", "desc": "Pancada de maça abençoada causando dano sagrado puro (1.0x dano).", "range": "4.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Círculo de Luz [Q]", "desc": "Impacto sagrado que causa dano aos monstros e cura +40 HP em aliados em 6.0m.", "range": "6.0m", "cost": "15 Stamina", "cd": "3.5s"},
		"r": {"name": "Lança do Julgamento [R]", "desc": "Feixe divino perfurante lançado a até 15m que purifica os alvos.", "range": "15.0m", "cost": "20 Stamina", "cd": "6.5s"},
		"f": {"name": "Égide Sagrada [F]", "desc": "Explosão celestial restaurando +65 HP no grupo e desferindo 2.4x dano sagrado.", "range": "7.0m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	},
	5: { # Ferreiro Combatente
		"name": "Ferreiro Combatente",
		"tier_name": "Tier 1 a Tier 6 (Titã Vulcânico)",
		"desc": "Força bruta com martelo colossal de forja, capaz de forjar armas de guerra e esmagar couraças.",
		"color": Color("#ff9800"),
		"evolved_titles": {
			1: "Ferreiro Combatente Comum",
			2: "Forjador de Guerra (Incomum)",
			3: "Armeiro Blindado (Rara)",
			4: "Grão-Forjador (Épica)",
			5: "Mestre das Bigornas (Única)",
			6: "Titã Vulcânico (Lendária)"
		},
		"passive": {
			"name": "Pancada Incandescente & Couraça de Forja",
			"desc": "Concede +15% a +39% de dano de contusão/atordoamento contra couraças pesadas e adiciona +20% a +52% de Armadura base aos equipamentos equipados.",
			"tier_scaling": "T1 Comum: 1.0x (15% Dano / 20% Armadura) | T2 Incomum: 1.20x (18% / 24%) | T3 Rara: 1.45x (21.8% / 29%) | T4 Épica: 1.75x (26.3% / 35%) | T5 Única: 2.15x (32.3% / 43%) | T6 Lendária: 2.60x (39% / 52%)"
		},
		"basic": {"name": "Martelada Pesada [LMB]", "desc": "Golpe esmagador contundente que atordoa armaduras leves (1.0x dano).", "range": "4.0m", "cost": "0 Stamina", "cd": "0.40s"},
		"q": {"name": "Golpe de Bigorna [Q]", "desc": "Impacto pesado concentrado no topo do crânio do alvo (1.75x dano).", "range": "4.2m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Afiação de Combate [R]", "desc": "Martela a bigorna conferindo um buff de +25% de dano para o grupo por 10s.", "range": "Grupo 12m", "cost": "20 Stamina", "cd": "10.0s"},
		"f": {"name": "Fúria do Vulcão [F]", "desc": "Impacto sísmico frontal telegrafado de 4.5m abrindo fendas incandescentes (2.4x dano).", "range": "4.5m Frontal", "cost": "25 Stamina", "cd": "13.0s"}
	},
	6: { # Alquimista
		"name": "Alquimista",
		"tier_name": "Tier 1 a Tier 6 (Alquimista do Éter Cósmico)",
		"desc": "Manipulador de frascos químicos, elixires curativos e bombas cáusticas de ácido.",
		"color": Color("#00e676"),
		"evolved_titles": {
			1: "Alquimista Comum",
			2: "Boticário Rebelde (Incomum)",
			3: "Químico Cáustico (Rara)",
			4: "Grão-Quimicista (Épica)",
			5: "Transmutador Mestre (Única)",
			6: "Alquimista do Éter Cósmico (Lendária)"
		},
		"passive": {
			"name": "Catalisador Tóxico & Transmutação Vital",
			"desc": "Ácidos, elixires e compostos químicos causam +25% a +65% de dano corrosivo contínuo ao longo do tempo. Abates transmutam +15 a +39 HP instantâneos.",
			"tier_scaling": "T1 Comum: 1.0x (25% Ácido / +15 HP) | T2 Incomum: 1.20x (30% / +18 HP) | T3 Rara: 1.45x (36.3% / +21.8 HP) | T4 Épica: 1.75x (43.8% / +26.3 HP) | T5 Única: 2.15x (53.8% / +32.3 HP) | T6 Lendária: 2.60x (65% / +39 HP)"
		},
		"basic": {"name": "Frasco Cáustico [LMB]", "desc": "Arremesso de ampola corrosiva com alcance médio (1.0x dano).", "range": "13.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Frasco de Éter [Q]", "desc": "Frasco que detona causando dano em área e curando +40 HP em aliados em 6.0m.", "range": "14.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Bomba de Ácido [R]", "desc": "Arremessa poça corrosiva de 3.5m que reduz armaduras dos inimigos por 4s.", "range": "12.0m", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Detonação Catalítica [F]", "desc": "Reação química em cadeia que explode violentamente em área de 5.5m (2.4x dano).", "range": "5.5m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	},
	7: { # Ceifador do Eclipse (Classe Secreta 7)
		"name": "Ceifador do Eclipse",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Soberano da Meia-Noite)",
		"desc": "Espírito das sombras portando uma foice colossal. Cada golpe ceifa as almas e o sangue dos inimigos.",
		"color": Color("#d500f9"),
		"is_secret": true,
		"evolved_titles": {
			1: "Ceifador Comum",
			2: "Ceifador Incomum",
			3: "Ceifador Raro",
			4: "Ceifador Épico",
			5: "Ceifador das Sombras (Única)",
			6: "Soberano da Meia-Noite (Lendária)"
		},
		"passive": {
			"name": "Ceifa de Almas & Lifesteal Sombrio",
			"desc": "Converte de 15% (Tier 5) a 25% (Tier 6) de todo o dano infligido em regeneração imediata de Vida, e ganha +20% de bônus de dano durante a Noite ou Eclipse.",
			"tier_scaling": "Tier 5 Única (Base): 15% Lifesteal + 20% Dano Noturno | Tier 6 Lendária: 25% Lifesteal + 35% Dano Noturno"
		},
		"unlock_hint": "Falar com Varis (NPC 104) à noite possuindo Essência da Noite e Nível 15+, ou consumir o Frasco do Eclipse sob a Lua Cheia.",
		"basic": {"name": "Foice das Sombras [LMB]", "desc": "Varredura ampla de longo melee de 4.8m com lifesteal embutido (1.0x dano).", "range": "4.8m", "cost": "0 Stamina", "cd": "0.38s"},
		"q": {"name": "Colheita Noturna [Q]", "desc": "Corte espiral que suga essência vital de todos os alvos no caminho (1.75x dano).", "range": "5.0m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Drenagem Abissal [R]", "desc": "Vórtice escuro que paralisa alvos e restaura +45 HP contínuos ao usuário.", "range": "Pessoal 5m", "cost": "20 Stamina", "cd": "6.5s"},
		"f": {"name": "Dança do Eclipse Total [F]", "desc": "Giro fatal de foice cobrindo 6.0m com dano devastador e roubo de vida pleno (2.4x dano).", "range": "6.0m Radial", "cost": "25 Stamina", "cd": "12.0s"}
	},
	8: { # Artífice Rúnico (Classe Secreta 8)
		"name": "Artífice Rúnico",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Engenheiro Arcano Supremo)",
		"desc": "Híbrido mecânico armado com martelo-canhão movido a núcleos de forja estelar.",
		"color": Color("#ff6d00"),
		"is_secret": true,
		"evolved_titles": {
			1: "Artífice Comum",
			2: "Artífice Incomum",
			3: "Artífice Raro",
			4: "Artífice Épico",
			5: "Artífice Rúnico Mecânico (Única)",
			6: "Engenheiro Arcano Supremo (Lendária)"
		},
		"passive": {
			"name": "Sobrecarga de Pólvora & Canhão Arcano",
			"desc": "O canhão de mão ganha +25% (Tier 5) a +40% (Tier 6) de dano em área e reduz o tempo de recarga de todas as habilidades de longo alcance em 20%.",
			"tier_scaling": "Tier 5 Única (Base): +25% Dano em Área | Tier 6 Lendária: +40% Dano em Área + Pulso Eletrostático Crítico"
		},
		"unlock_hint": "Forjar a Liga Rúnica Estelar na Bigorna de Garrick (NPC 100) com Força >= 20 e Constituição >= 15 durante Neblina ou à Noite.",
		"basic": {"name": "Canhonada Rúnica [LMB]", "desc": "Pancada física e detonação de pólvora simultâneas (1.0x dano).", "range": "15.0m", "cost": "0 Stamina", "cd": "0.38s"},
		"q": {"name": "Salva Rúnica [Q]", "desc": "Três cartuchos energizados disparados em rápida sucessão frontal (1.75x dano).", "range": "16.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Sobrecarga Eletrostática [R]", "desc": "Pulso elétrico que concede raios nas armas do grupo por 8s.", "range": "Grupo 10m", "cost": "20 Stamina", "cd": "8.0s"},
		"f": {"name": "Bombardeio Titanomecânico [F]", "desc": "Disparo orbital com estilhaços energizados de 6.5m (2.4x dano).", "range": "6.5m Radial", "cost": "25 Stamina", "cd": "14.0s"}
	},
	9: { # Criador de Homúnculos (Classe Secreta 9)
		"name": "Criador de Homúnculos",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Demiurgo da Vida Sintética)",
		"desc": "Mestre da vida sintética acompanhado por uma quimera flutuante transmissora de elixires.",
		"color": Color("#00b0ff"),
		"is_secret": true,
		"evolved_titles": {
			1: "Criador Comum",
			2: "Criador Incomum",
			3: "Criador Raro",
			4: "Criador Épico",
			5: "Transmutador de Homúnculos (Única)",
			6: "Demiurgo da Vida Sintética (Lendária)"
		},
		"passive": {
			"name": "Sintonia Biótica Quimérica",
			"desc": "O homúnculo companheiro herda +30% (Tier 5) a +50% (Tier 6) de todos os atributos do criador, regenerando periodicamente a vida do mestre em combate.",
			"tier_scaling": "Tier 5 Única (Base): +30% Atributos herdados + Cura contínua | Tier 6 Lendária: +50% Atributos herdados + Pulso Biótico Duplo"
		},
		"unlock_hint": "Combinar Órgão Perfeito de Aberração (extraído via autópsia bem-sucedida) com os Frascos de Lyra (NPC 103) durante a Chuva.",
		"basic": {"name": "Pulso Quimérico [LMB]", "desc": "Onda biótica disparada pelo homúnculo que causa dano e regenera o mestre (1.0x dano).", "range": "14.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Infusão Mutagênica [Q]", "desc": "Elixir abissal corrosivo que dissolve resistências inimigas (1.75x dano).", "range": "15.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Névoa de Bioplasma [R]", "desc": "Nuvem esverdeada curando aliados continuamente e cegando monstros.", "range": "4.5m Área", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Frenesi do Quimera Supremo [F]", "desc": "O homúnculo cresce e desfere uma explosão de garras e ácido colossais (2.4x dano).", "range": "6.0m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	},
	10: { # Dançarino Astral (Classe Secreta 10)
		"name": "Dançarino Astral",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Soberano das Constelações)",
		"desc": "Duelista cósmico mestre de esquivas fluidas e cortes críticos que brilham como cometas estelares.",
		"color": Color("#80d8ff"),
		"is_secret": true,
		"evolved_titles": {
			1: "Dançarino Comum",
			2: "Dançarino Incomum",
			3: "Dançarino Raro",
			4: "Dançarino Épico",
			5: "Dançarino Astral (Única)",
			6: "Soberano das Constelações (Lendária)"
		},
		"passive": {
			"name": "Dança Intocável dos Cometas",
			"desc": "Esquivas custam apenas 10 Stamina, concedem +25% (Tier 5) a +45% (Tier 6) de Dano Crítico após cada evasão e garantem +15% de chance de Esquiva Perfeita.",
			"tier_scaling": "Tier 5 Única (Base): Esquiva 10 Stamina + 25% Dano Crítico | Tier 6 Lendária: Esquiva 8 Stamina + 45% Dano Crítico + I-Frames estendidos"
		},
		"unlock_hint": "Realizar 10 abates consecutivos de monstros sem sofrer nenhum dano (Untouched Kills >= 10) e falar com Mestre Aurelius (NPC 108) à Noite.",
		"basic": {"name": "Corte Astral [LMB]", "desc": "Corte rápido com +25% de chance crítica permanente e esquiva barata de 10 stamina.", "range": "3.8m", "cost": "0 Stamina", "cd": "0.32s"},
		"q": {"name": "Corte Cadente [Q]", "desc": "Salto veloz que corta o espaço desferindo dano massivo (2.0x dano).", "range": "4.5m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Valsa dos Espelhos [R]", "desc": "Janela de 1.5s de invulnerabilidade total (I-Frame) seguida de contra-ataque refletor.", "range": "Pessoal", "cost": "20 Stamina", "cd": "6.0s"},
		"f": {"name": "Constelação de Mil Lâminas [F]", "desc": "Dança de cortes omnidirecionais devastando inimigos em raio de 5.5m (3.0x dano).", "range": "5.5m Radial", "cost": "25 Stamina", "cd": "12.0s"}
	},
	11: { # Inquisidor das Cinzas (Classe Secreta 11)
		"name": "Inquisidor das Cinzas",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Grão-Inquisidor das Chamas)",
		"desc": "Executor fanático cuja força cresce exponencialmente quanto mais próximo estiver da morte.",
		"color": Color("#ff5252"),
		"is_secret": true,
		"evolved_titles": {
			1: "Inquisidor Comum",
			2: "Inquisidor Incomum",
			3: "Inquisidor Raro",
			4: "Inquisidor Épico",
			5: "Inquisidor das Cinzas (Única)",
			6: "Grão-Inquisidor das Chamas (Lendária)"
		},
		"passive": {
			"name": "Fúria Penitente na Beira da Morte",
			"desc": "Quando sua vida cai abaixo de 50%, seu dano é amplificado de +60% (Tier 5) até +100% (Tier 6), tornando-se completamente imune a atordoamento e medo.",
			"tier_scaling": "Tier 5 Única (Base): Até +60% Dano com HP baixo + Imunidade a Stun | Tier 6 Lendária: Até +100% Dano com HP baixo + Fogo Sagrado puro"
		},
		"unlock_hint": "Realizar 3 abates de monstros à beira da morte (com HP <= 30%) e conversar com a Irmã Seraphina (NPC 107) estando com menos de 30% de Vida.",
		"basic": {"name": "Chama Penitente [LMB]", "desc": "Golpe ardente que ganha até +60% de dano conforme o HP diminui.", "range": "4.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Chicote de Penitência [Q]", "desc": "Chicote de fogo sagrado de 8.0m que causa 2.2x dano e rouba vida.", "range": "8.0m", "cost": "15 Stamina", "cd": "3.5s"},
		"r": {"name": "Selo de Excomunhão [R]", "desc": "Purificação sagrada que regenera +35 HP e incendeia inimigos em raio de 5.0m.", "range": "5.0m Radial", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Crucificação de Cinzas [F]", "desc": "Pilares de cinzas incandescentes que incineram uma área de 6.0m (3.2x dano).", "range": "6.0m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	},
	12: { # Necromante de Ossos (Classe Secreta 12)
		"name": "Necromante de Ossos",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Lorde do Ossuário Eterno)",
		"desc": "Manipulador anatômico que canaliza a essência dos ossos e extrai vitalidade de cada abate (+20 HP).",
		"color": Color("#ccff90"),
		"is_secret": true,
		"evolved_titles": {
			1: "Necromante Comum",
			2: "Necromante Incomum",
			3: "Necromante Raro",
			4: "Necromante Épico",
			5: "Necromante de Ossos (Única)",
			6: "Lorde do Ossuário Eterno (Lendária)"
		},
		"passive": {
			"name": "Ceifa do Ossuário & Toque Esmeralda",
			"desc": "Cada criatura abatida restaura instantaneamente +20 HP (Tier 5) a +40 HP (Tier 6) e ergue uma farpa óssea ao redor que reduz o próximo dano sofrido em 50%.",
			"tier_scaling": "Tier 5 Única (Base): +20 HP por abate + Farpa Óssea 50% | Tier 6 Lendária: +40 HP por abate + Barreira de Ossos Completa"
		},
		"unlock_hint": "Completar 5 autópsias perfeitas consecutivas na Zona Verde (Streak >= 5) e conversar com o Alquimista Fantasma (NPC 110) nos esgotos entre 00:00 e 04:00.",
		"basic": {"name": "Toque do Sepulcro [LMB]", "desc": "Projétil de ossos fragmentados. Cada abate regenera +20 HP instantâneos.", "range": "14.0m", "cost": "0 Stamina", "cd": "0.36s"},
		"q": {"name": "Lança de Fêmur [Q]", "desc": "Dispara uma lança de fêmur calcificado que perfura a 16m causando 2.0x dano.", "range": "16.0m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Explosão Óssea & Escudo [R]", "desc": "Detona fragmentos ósseos em 5.0m e ergue uma barreira de ossos protetora.", "range": "5.0m Radial", "cost": "20 Stamina", "cd": "7.5s"},
		"f": {"name": "Legião do Ossuário [F]", "desc": "Ergue um vórtice de ossatura profana cobrindo 6.0m com 3.0x de dano letal.", "range": "6.0m Radial", "cost": "25 Stamina", "cd": "13.0s"}
	},
	13: { # Domador Primordial (Classe Secreta 13)
		"name": "Domador Primordial",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Avatar da Fera Ancestral)",
		"desc": "Guerreiro feral possuído pelo Espírito Alfa, infligindo +25% de dano constante com garras devastadoras.",
		"color": Color("#ffd740"),
		"is_secret": true,
		"evolved_titles": {
			1: "Domador Comum",
			2: "Domador Incomum",
			3: "Domador Raro",
			4: "Domador Épico",
			5: "Domador Primordial (Única)",
			6: "Avatar da Fera Ancestral (Lendária)"
		},
		"passive": {
			"name": "Espírito Lupino Primal",
			"desc": "Um Lobo Espiritual Prateado translúcido acompanha seus passos e desfere patadas sincronizadas causando +25% (Tier 5) a +45% (Tier 6) de dano físico e fareja monstros de elite.",
			"tier_scaling": "Tier 5 Única (Base): Lobo Espiritual +25% Dano + Faro de Elites | Tier 6 Lendária: Lobo Ancestral +45% Dano + Uivo de Cura Duplo"
		},
		"unlock_hint": "Derrotar o Lobo Alfa sozinho sem usar armadura de peito sob a Lua Cheia, ou conversar com Kaelen (NPC 109) possuindo Força >= 15 e Espírito >= 15.",
		"basic": {"name": "Patada Selvagem [LMB]", "desc": "Ataque corporal com ferocidade primal e dano aumentado em +25% permanentemente.", "range": "4.2m", "cost": "0 Stamina", "cd": "0.34s"},
		"q": {"name": "Investida do Alfa [Q]", "desc": "Avanço bestial rompendo as linhas inimigas com impacto violento (2.1x dano).", "range": "5.5m", "cost": "15 Stamina", "cd": "3.2s"},
		"r": {"name": "Uivo da Alcateia [R]", "desc": "Uivo ressonante que cura +50 HP e concede buff de ataque crítico a todo o grupo.", "range": "Grupo 10m", "cost": "20 Stamina", "cd": "8.0s"},
		"f": {"name": "Fúria do Behemoth [F]", "desc": "Impacto frontal titânico gerando onda de choque sísmica devastadora (3.0x dano).", "range": "5.0m Frontal", "cost": "25 Stamina", "cd": "12.0s"}
	},
	14: { # Cavaleiro da Ruptura (Classe Secreta 14)
		"name": "Cavaleiro da Ruptura",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Guardião da Singularidade)",
		"desc": "Colosso dimensional envolto em malha espacial. Reduz 30% de todo o dano recebido e dobra a gravidade.",
		"color": Color("#7c4dff"),
		"is_secret": true,
		"evolved_titles": {
			1: "Cavaleiro Comum",
			2: "Cavaleiro Incomum",
			3: "Cavaleiro Raro",
			4: "Cavaleiro Épico",
			5: "Cavaleiro da Ruptura (Única)",
			6: "Guardião da Singularidade (Lendária)"
		},
		"passive": {
			"name": "Colosso da Singularidade",
			"desc": "Reduz passivamente 30% (Tier 5) a 50% (Tier 6) de todo o dano recebido e reflete 20% do impacto com um pulso de vácuo gravitacional que atrai inimigos para o corte.",
			"tier_scaling": "Tier 5 Única (Base): 30% Redução de Dano + 20% Reflexão Vácuo | Tier 6 Lendária: 50% Redução de Dano + Singularidade Gravitacional Total"
		},
		"unlock_hint": "Bloquear/Parryar o golpe devastador de um Chefe de Elite (Executor ou Lobo Alfa) com Constituição >= 20 durante Eclipse ou Lua de Sangue e falar com Capitão Randel (NPC 105).",
		"basic": {"name": "Golpe de Fenda [LMB]", "desc": "Golpe pesado imbuído de gravidade e resistência passiva de -30% a danos.", "range": "4.2m", "cost": "0 Stamina", "cd": "0.40s"},
		"q": {"name": "Esmagamento Gravitacional [Q]", "desc": "Atrai todos os monstros em 5.0m para junto de si e esmaga o solo (1.9x dano).", "range": "5.0m Puxão", "cost": "15 Stamina", "cd": "3.5s"},
		"r": {"name": "Singularidade Reversa [R]", "desc": "Postura de bloqueio que absorve 80% do dano e implode o espaço ao redor.", "range": "4.5m Radial", "cost": "20 Stamina", "cd": "7.0s"},
		"f": {"name": "Colapso Estelar [F]", "desc": "Cria um buraco negro em 6.5m que atordoa todos os inimigos e desintegra matéria (2.8x dano).", "range": "6.5m Radial", "cost": "25 Stamina", "cd": "14.0s"}
	},
	15: { # Arauto da Tempestade (Classe Secreta 15)
		"name": "Arauto da Tempestade",
		"tier_name": "Tier 5 (Única) -> Tier 6 (Soberano dos Relâmpagos)",
		"desc": "Avatar dos trovões cuja fúria cresce em +35% durante chuvas, empunhando dardos de relâmpago puro.",
		"color": Color("#40c4ff"),
		"is_secret": true,
		"evolved_titles": {
			1: "Arauto Comum",
			2: "Arauto Incomum",
			3: "Arauto Raro",
			4: "Arauto Épico",
			5: "Arauto da Tempestade (Única)",
			6: "Soberano dos Relâmpagos (Lendária)"
		},
		"passive": {
			"name": "Condutividade Celestial",
			"desc": "Ataques e feitiços elétricos causam +35% (Tier 5) a +60% (Tier 6) de dano durante Clima de Chuva e Tempestade. Golpes básicos têm chance de liberar arcos de choque em cadeia.",
			"tier_scaling": "Tier 5 Única (Base): +35% Dano Elétrico na Chuva + Choque | Tier 6 Lendária: +60% Dano Elétrico + Relâmpagos Celestiais Contínuos"
		},
		"unlock_hint": "Conjurar a Habilidade Suprema [F] nas proximidades da Torre Arcana (coords 20, -18) durante uma Chuva/Tempestade intensa (Weather == 1).",
		"basic": {"name": "Faísca Elétrica [LMB]", "desc": "Dardos elétricos estáticos que causam +35% de dano durante climas chuvosos.", "range": "15.0m", "cost": "0 Stamina", "cd": "0.34s"},
		"q": {"name": "Lança do Trovão [Q]", "desc": "Arremessa um raio concentrado a 18m que detona ao impacto (2.1x dano).", "range": "18.0m", "cost": "15 Stamina", "cd": "3.0s"},
		"r": {"name": "Passo de Relâmpago [R]", "desc": "Surto elétrico que concede velocidade e eletrocuta/atordoa monstros próximos.", "range": "4.0m Radial", "cost": "20 Stamina", "cd": "6.5s"},
		"f": {"name": "Ira dos Céus [F]", "desc": "Tempestade cataclísmica de raios cobrindo 6.0m com devastação celestial (3.1x dano).", "range": "6.0m Radial", "cost": "25 Stamina", "cd": "12.0s"}
	}
}

# Referências de Nós
var main_panel: PanelContainer = null
var tab_buttons: Array[Button] = []
var tab_containers: Array[Control] = []
var selected_custom_slot: String = "LMB"
var pending_keybinds: Dictionary = {
	"LMB": 1,
	"Q": 3,
	"R": 4,
	"F": 5,
	"Z": 6
}

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	_switch_tab(0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_open:
			close_menu()
			get_viewport().set_input_as_handled()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)
	_refresh_current_tab()

func close_menu() -> void:
	is_open = false
	visible = false
	var world := get_parent()
	var any_other_open := false
	if world:
		if world.get("char_select_ui") and world.char_select_ui.get("is_open"):
			any_other_open = true
		if world.get("attributes_ui") and world.attributes_ui.get("is_open"):
			any_other_open = true
		if world.get("inventory_ui") and world.inventory_ui.get("is_open"):
			any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(960, 600)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.05, 0.07, 0.11, 0.98)
	p_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.8)
	p_style.shadow_size = 18
	p_style.content_margin_left = 20
	p_style.content_margin_right = 20
	p_style.content_margin_top = 16
	p_style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(root_vbox)

	# Barra de Título e Fechar
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "LUNARIA — COMPÊNDIO DE HABILIDADES & PASSIVAS [TECLA H]"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " ✕ Fechar "
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	top_bar.add_child(close_btn)

	# Barra de Abas (4 Abas)
	var tabs_bar := HBoxContainer.new()
	tabs_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tabs_bar)

	tab_buttons.clear()
	var tab_names := [
		"⚡ 1. Raciais [Tecla Z]",
		"⚔️ 2. Ativas [LMB, Q, R, F]",
		"🌌 3. Classes Secretas & Passivas",
		"🎯 4. Customizar Slots de Ação"
	]
	for i in range(4):
		var t_btn := Button.new()
		t_btn.text = tab_names[i]
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size = Vector2(0, 36)
		t_btn.add_theme_font_size_override("font_size", 11)
		t_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx: int = i
		t_btn.pressed.connect(func(): _switch_tab(idx))
		tabs_bar.add_child(t_btn)
		tab_buttons.append(t_btn)

	# Separador
	root_vbox.add_child(HSeparator.new())

	# Containers das 4 Abas
	tab_containers.clear()
	for i in range(4):
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(scroll)
		tab_containers.append(scroll)

func _switch_tab(idx: int) -> void:
	active_tab_index = idx
	for i in range(tab_buttons.size()):
		var btn: Button = tab_buttons[i]
		var is_sel: bool = (i == idx)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4

		if is_sel:
			style.bg_color = Color(0.2, 0.32, 0.5, 0.95)
			style.border_color = Color(0.9, 0.8, 0.3, 0.95)
			style.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		else:
			style.bg_color = Color(0.08, 0.1, 0.15, 0.8)
			style.border_color = Color(0.25, 0.35, 0.5, 0.4)
			style.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

		tab_containers[i].visible = is_sel

	_refresh_current_tab()

func _refresh_current_tab() -> void:
	var world := get_parent()
	var my_race: int = 1
	var my_class: int = 0
	var my_tier: int = 1
	var my_level: int = 1
	if world:
		if world.get("my_race_id"): my_race = world.my_race_id
		if world.get("my_class_id"): my_class = world.my_class_id
		if world.get("my_class_tier"): my_tier = world.my_class_tier
		if world.get("my_level"): my_level = world.my_level

	match active_tab_index:
		0: _build_tab_1_racial(my_race)
		1: _build_tab_2_class_actives(my_class, my_tier, my_level)
		2: _build_tab_3_passives_and_trials(my_class, my_tier, my_level)
		3: _build_tab_4_customize_slots(my_race, my_class)

# ABA 1: Habilidades & Passivas Raciais
func _build_tab_1_racial(race_id: int) -> void:
	var container: ScrollContainer = tab_containers[0]
	for ch in container.get_children():
		ch.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	var r_info: Dictionary = RACIAL_DETAILS.get(race_id, RACIAL_DETAILS[1])

	# Banner da Raça Atual
	var banner := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.08, 0.11, 0.17, 0.95)
	b_style.border_color = r_info["color"]
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(8)
	b_style.content_margin_left = 16
	b_style.content_margin_right = 16
	b_style.content_margin_top = 12
	b_style.content_margin_bottom = 12
	banner.add_theme_stylebox_override("panel", b_style)
	vbox.add_child(banner)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 4)
	banner.add_child(bvbox)

	var r_name_lbl := Label.new()
	r_name_lbl.text = "Linhagem Sanguínea: %s" % r_info["name"]
	r_name_lbl.add_theme_font_size_override("font_size", 16)
	r_name_lbl.add_theme_color_override("font_color", r_info["color"])
	bvbox.add_child(r_name_lbl)

	var r_status_lbl := Label.new()
	r_status_lbl.text = "[ %s ]" % r_info["status"]
	r_status_lbl.add_theme_font_size_override("font_size", 11)
	r_status_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	bvbox.add_child(r_status_lbl)

	# Card da Habilidade Ativa [Tecla Z]
	var card_z := PanelContainer.new()
	var z_style := StyleBoxFlat.new()
	z_style.bg_color = Color(0.07, 0.1, 0.15, 0.9)
	z_style.border_color = Color(0.3, 0.85, 1.0, 0.7)
	z_style.set_border_width_all(1)
	z_style.set_corner_radius_all(6)
	z_style.content_margin_left = 14
	z_style.content_margin_right = 14
	z_style.content_margin_top = 10
	z_style.content_margin_bottom = 10
	card_z.add_theme_stylebox_override("panel", z_style)
	vbox.add_child(card_z)

	var zvbox := VBoxContainer.new()
	zvbox.add_theme_constant_override("separation", 4)
	card_z.add_child(zvbox)

	var z_head := Label.new()
	z_head.text = "⚡ HABILIDADE RACIAL ATIVA: %s" % r_info["skill_z_name"]
	z_head.add_theme_font_size_override("font_size", 13)
	z_head.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	zvbox.add_child(z_head)

	var z_cost := Label.new()
	z_cost.text = r_info["skill_z_cost"]
	z_cost.add_theme_font_size_override("font_size", 10)
	z_cost.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	zvbox.add_child(z_cost)

	var z_desc := Label.new()
	z_desc.text = r_info["skill_z_desc"]
	z_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	z_desc.add_theme_font_size_override("font_size", 11)
	z_desc.add_theme_color_override("font_color", Color(0.9, 0.94, 0.98))
	zvbox.add_child(z_desc)

	# Card da Passiva Inata de Linhagem
	var card_pass := PanelContainer.new()
	var pass_style := z_style.duplicate()
	pass_style.border_color = Color(0.4, 0.95, 0.45, 0.7)
	card_pass.add_theme_stylebox_override("panel", pass_style)
	vbox.add_child(card_pass)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 4)
	card_pass.add_child(pvbox)

	# ABA 2: Habilidades Ativas de Classe (LMB, Q, R, F)
func _build_tab_2_class_actives(class_id: int, class_tier: int, level: int) -> void:
	var container: ScrollContainer = tab_containers[1]
	for ch in container.get_children():
		ch.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	var c_info: Dictionary = CLASS_ACTIVE_SKILLS.get(class_id, CLASS_ACTIVE_SKILLS[0])
	var clamped_tier: int = clampi(class_tier, 1, 6)
	var ev_titles: Dictionary = c_info.get("evolved_titles", {})
	var evolved_title: String = ev_titles.get(clamped_tier, c_info.get("tier_name", "Tier %d" % clamped_tier))
	var tier_names: Array = ["", "Tier 1 Comum", "Tier 2 Incomum", "Tier 3 Rara", "Tier 4 Épica", "Tier 5 Única", "Tier 6 Lendária"]
	var tier_badge: String = tier_names[clamped_tier] if clamped_tier < tier_names.size() else ("Tier %d" % clamped_tier)

	# Banner da Classe
	var banner := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.08, 0.11, 0.17, 0.95)
	b_style.border_color = c_info["color"]
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(8)
	b_style.content_margin_left = 16
	b_style.content_margin_right = 16
	b_style.content_margin_top = 10
	b_style.content_margin_bottom = 10
	banner.add_theme_stylebox_override("panel", b_style)
	vbox.add_child(banner)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 3)
	banner.add_child(bvbox)

	var c_title := Label.new()
	c_title.text = "Classe Atual: %s — %s [%s] (Nível %d)" % [c_info["name"], evolved_title, tier_badge, level]
	c_title.add_theme_font_size_override("font_size", 15)
	c_title.add_theme_color_override("font_color", c_info["color"])
	bvbox.add_child(c_title)

	var c_desc := Label.new()
	c_desc.text = c_info["desc"]
	c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_desc.add_theme_font_size_override("font_size", 11)
	c_desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	bvbox.add_child(c_desc)

	# Card da Passiva Exclusiva da Classe
	var pass_info: Dictionary = c_info.get("passive", {
		"name": "Passiva de Combate",
		"desc": "Concede bônus contínuos ao combatente.",
		"tier_scaling": "Escala conforme o Tier da Classe."
	})
	var card_pass := PanelContainer.new()
	var pass_style := StyleBoxFlat.new()
	pass_style.bg_color = Color(0.06, 0.11, 0.15, 0.95)
	pass_style.border_color = Color(0.3, 0.95, 0.65, 0.85)
	pass_style.set_border_width_all(1)
	pass_style.set_corner_radius_all(6)
	pass_style.content_margin_left = 14
	pass_style.content_margin_right = 14
	pass_style.content_margin_top = 10
	pass_style.content_margin_bottom = 10
	card_pass.add_theme_stylebox_override("panel", pass_style)
	vbox.add_child(card_pass)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 4)
	card_pass.add_child(pvbox)

	var pass_head := Label.new()
	pass_head.text = "🛡️ PASSIVA EXCLUSIVA DA CLASSE: %s" % pass_info["name"]
	pass_head.add_theme_font_size_override("font_size", 13)
	pass_head.add_theme_color_override("font_color", Color(0.35, 1.0, 0.7))
	pvbox.add_child(pass_head)

	var pass_desc := Label.new()
	pass_desc.text = pass_info["desc"]
	pass_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pass_desc.add_theme_font_size_override("font_size", 11)
	pass_desc.add_theme_color_override("font_color", Color(0.88, 0.95, 0.98))
	pvbox.add_child(pass_desc)

	var pass_scale := Label.new()
	pass_scale.text = "📈 %s" % pass_info.get("tier_scaling", "")
	pass_scale.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pass_scale.add_theme_font_size_override("font_size", 10)
	pass_scale.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	pvbox.add_child(pass_scale)

	var mult_label := Label.new()
	var tier_mults: Dictionary = {1: "1.0x (Padrão)", 2: "1.20x (+20%)", 3: "1.45x (+45%)", 4: "1.75x (+75%)", 5: "2.15x (+115%)", 6: "2.60x (+160% Máximo)"}
	mult_label.text = "✨ Potência Ativa da Passiva: [%s] — Multiplicador Atual: %s" % [tier_badge, tier_mults.get(clamped_tier, "1.0x")]
	mult_label.add_theme_font_size_override("font_size", 10)
	mult_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	pvbox.add_child(mult_label)

	# 4 Slots de Habilidades Ativas
	var skills_list := [
		{"slot": "[LMB] Ataque Básico", "data": c_info["basic"], "color": Color("#ffffff")},
		{"slot": "[Q] Habilidade 1", "data": c_info["q"], "color": Color("#64b5f6")},
		{"slot": "[R] Habilidade 2", "data": c_info["r"], "color": Color("#ffd54f")},
		{"slot": "[F] Habilidade Suprema", "data": c_info["f"], "color": Color("#ff5252")}
	]

	for item in skills_list:
		var s_data: Dictionary = item["data"]
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.09, 0.14, 0.9)
		card_style.border_color = Color(0.3, 0.42, 0.6, 0.5)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		vbox.add_child(card)

		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 2)
		card.add_child(cvbox)

		var s_head := Label.new()
		s_head.text = "%s: %s" % [item["slot"], s_data["name"]]
		s_head.add_theme_font_size_override("font_size", 12)
		s_head.add_theme_color_override("font_color", item["color"])
		cvbox.add_child(s_head)

		var s_meta := Label.new()
		s_meta.text = "Alcance: %s  |  Custo: %s  |  Recarga: %s" % [s_data["range"], s_data["cost"], s_data["cd"]]
		s_meta.add_theme_font_size_override("font_size", 10)
		s_meta.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
		cvbox.add_child(s_meta)

		var s_body := Label.new()
		s_body.text = s_data["desc"]
		s_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_body.add_theme_font_size_override("font_size", 11)
		s_body.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96))
		cvbox.add_child(s_body)

# ABA 3: Passivas de Classe, Provação & Catálogo de Classes Secretas
func _build_tab_3_passives_and_trials(class_id: int, class_tier: int, level: int) -> void:
	var container: ScrollContainer = tab_containers[2]
	for ch in container.get_children():
		ch.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	# Seção de Passivas de Especialização
	var pass_panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.11, 0.17, 0.95)
	p_style.border_color = Color(0.4, 0.6, 0.85, 0.7)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(8)
	p_style.content_margin_left = 16
	p_style.content_margin_right = 16
	p_style.content_margin_top = 12
	p_style.content_margin_bottom = 12
	pass_panel.add_theme_stylebox_override("panel", p_style)
	vbox.add_child(pass_panel)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 4)
	pass_panel.add_child(pvbox)

	var p_title := Label.new()
	p_title.text = "🛡️ SEU CAMINHO MARCIAL ATIVO:"
	p_title.add_theme_font_size_override("font_size", 14)
	p_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	pvbox.add_child(p_title)

	var my_c_info: Dictionary = CLASS_ACTIVE_SKILLS.get(class_id, CLASS_ACTIVE_SKILLS[0])
	var p_desc := Label.new()
	if class_id == 0:
		p_desc.text = "Viajantes não possuem especialização marcial ativa. Visite os Mestres na Vila do Refúgio para aprender uma Classe Básica."
	else:
		var clamped_tier: int = clampi(class_tier, 1, 6)
		var ev_titles: Dictionary = my_c_info.get("evolved_titles", {})
		var ev_name: String = ev_titles.get(clamped_tier, my_c_info["name"])
		var tier_mults: Dictionary = {1: "1.0x", 2: "1.20x", 3: "1.45x", 4: "1.75x", 5: "2.15x", 6: "2.60x"}
		p_desc.text = "Classe Ativa: %s — Título Evolvido: %s (Tier %d)\nPassiva: %s\nPotência do Tier: %s de eficácia amplificada." % [
			my_c_info["name"], ev_name, class_tier,
			my_c_info.get("passive", {}).get("name", "Passiva"),
			tier_mults.get(clamped_tier, "1.0x")
		]
	p_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_desc.add_theme_font_size_override("font_size", 11)
	p_desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	pvbox.add_child(p_desc)

	# Se for Classe Única (Tier 5): Exibe a Provação Especial Lendária!
	if class_tier >= 5 or class_id in [7, 8, 9, 10, 11, 12, 13, 14, 15]:
		var trial_panel := PanelContainer.new()
		var t_style := StyleBoxFlat.new()
		t_style.bg_color = Color(0.12, 0.06, 0.16, 0.98)
		t_style.border_color = Color(0.95, 0.82, 0.35, 0.95)
		t_style.set_border_width_all(2)
		t_style.set_corner_radius_all(10)
		t_style.shadow_color = Color(0.8, 0.2, 0.9, 0.4)
		t_style.shadow_size = 14
		t_style.content_margin_left = 18
		t_style.content_margin_right = 18
		t_style.content_margin_top = 14
		t_style.content_margin_bottom = 14
		trial_panel.add_theme_stylebox_override("panel", t_style)
		vbox.add_child(trial_panel)

		var tvbox := VBoxContainer.new()
		tvbox.add_theme_constant_override("separation", 8)
		trial_panel.add_child(tvbox)

		var quest_name: String = "As Três Colheitas sob o Sol Negro"
		var quest_lore: String = "Abata 3 Criaturas de Elite ou Chefes (Lobo Alfa, Licantropo Alfa, Executor) sem tombar em batalha para provar seu valor perante o cosmos e ascender ao TIER 6 LENDÁRIO."
		if class_id == 8:
			quest_name = "O Metal que Caiu do Céu"
			quest_lore = "Colete a liga divina do cosmos abatendo 3 Monstros de Elite sem morrer para ascender a Engenheiro Arcano Supremo (Tier 6)."
		elif class_id == 9:
			quest_name = "Magnum Opus Transmutacional"
			quest_lore = "Transmute a centelha da vida sintética definitiva com a essência de 3 Criaturas de Elite para despertar como Demiurgo (Tier 6)."

		var t_head := Label.new()
		t_head.text = "👑 PROVAÇÃO ESPECIAL LENDÁRIA (TIER 5 -> TIER 6): %s" % quest_name
		t_head.add_theme_font_size_override("font_size", 14)
		t_head.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		tvbox.add_child(t_head)

		var t_desc := Label.new()
		t_desc.text = quest_lore
		t_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_desc.add_theme_font_size_override("font_size", 11)
		t_desc.add_theme_color_override("font_color", Color(0.9, 0.85, 0.95))
		tvbox.add_child(t_desc)

		var progress_bar := ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 24)
		progress_bar.max_value = 3
		progress_bar.value = 3 if class_tier == 6 else 0
		tvbox.add_child(progress_bar)

		var t_status := Label.new()
		if class_tier == 6:
			t_status.text = "STATUS: PROVAÇÃO CONCLUÍDA! VOCÊ DESPERTOU A CLASSE LENDÁRIA (TIER 6)!"
			t_status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		else:
			t_status.text = "PROGRESSO: 0 / 3 Colheitas Cósmicas Concluídas (Requer Nível 45+)"
			t_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		t_status.add_theme_font_size_override("font_size", 11)
		tvbox.add_child(t_status)
	else:
		var hint_panel := PanelContainer.new()
		var h_style := StyleBoxFlat.new()
		h_style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		h_style.border_color = Color(0.3, 0.4, 0.55, 0.4)
		h_style.set_border_width_all(1)
		h_style.set_corner_radius_all(6)
		h_style.content_margin_left = 14
		h_style.content_margin_right = 14
		h_style.content_margin_top = 10
		h_style.content_margin_bottom = 10
		hint_panel.add_theme_stylebox_override("panel", h_style)
		vbox.add_child(hint_panel)

		var hint_lbl := Label.new()
		hint_lbl.text = "ℹ️ DICA DE ASCENSÃO: Classes Básicas evoluem nos marcos de Nível 10 (Tier 2 Incomum), Nível 25 (Tier 3 Rara) e Nível 45 (Tier 4 Épica). Desafios e provações no mundo desbloqueiam as 9 Classes Secretas (Tier 5 Única)."
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.add_theme_font_size_override("font_size", 11)
		hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
		hint_panel.add_child(hint_lbl)

	# =========================================================================
	# CATÁLOGO COMPLETO DAS 9 CLASSES SECRETAS & DESAFIOS DE OBTENÇÃO
	# =========================================================================
	var cat_header := PanelContainer.new()
	var ch_style := StyleBoxFlat.new()
	ch_style.bg_color = Color(0.1, 0.07, 0.16, 0.95)
	ch_style.border_color = Color(0.85, 0.55, 1.0, 0.9)
	ch_style.set_border_width_all(2)
	ch_style.set_corner_radius_all(8)
	ch_style.content_margin_left = 16
	ch_style.content_margin_right = 16
	ch_style.content_margin_top = 12
	ch_style.content_margin_bottom = 12
	cat_header.add_theme_stylebox_override("panel", ch_style)
	vbox.add_child(cat_header)

	var ch_vbox := VBoxContainer.new()
	ch_vbox.add_theme_constant_override("separation", 4)
	cat_header.add_child(ch_vbox)

	var cat_title := Label.new()
	cat_title.text = "🔮 CATÁLOGO DAS 9 CLASSES SECRETAS & DESAFIOS DE OBTENÇÃO (Tier 5 Única -> Tier 6 Lendária)"
	cat_title.add_theme_font_size_override("font_size", 14)
	cat_title.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	ch_vbox.add_child(cat_title)

	var cat_sub := Label.new()
	cat_sub.text = "As 9 Classes Secretas (7 a 15) iniciam no Tier 5 Única, resetam o personagem para o Nível 1 concedendo +10 Pontos de Atributo por nível (ao invés de 5), e podem ascender ao Tier 6 Lendária (+12 pontos por nível) superando a Provação das Colheitas Cósmicas. Abaixo estão todas as pistas e requisitos para desbloquear cada uma no mundo de Lunaria:"
	cat_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cat_sub.add_theme_font_size_override("font_size", 11)
	cat_sub.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	ch_vbox.add_child(cat_sub)

	# Itera pelas 9 Classes Secretas (7 a 15)
	for sec_id in range(7, 16):
		var s_info: Dictionary = CLASS_ACTIVE_SKILLS.get(sec_id)
		if not s_info:
			continue

		var s_card := PanelContainer.new()
		var sc_style := StyleBoxFlat.new()
		sc_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
		var sc_col: Color = s_info.get("color", Color(0.7, 0.7, 0.7))
		sc_style.border_color = Color(sc_col.r, sc_col.g, sc_col.b, 0.75)
		sc_style.set_border_width_all(1)
		sc_style.set_corner_radius_all(6)
		sc_style.content_margin_left = 14
		sc_style.content_margin_right = 14
		sc_style.content_margin_top = 10
		sc_style.content_margin_bottom = 10
		s_card.add_theme_stylebox_override("panel", sc_style)
		vbox.add_child(s_card)

		var sc_vbox := VBoxContainer.new()
		sc_vbox.add_theme_constant_override("separation", 4)
		s_card.add_child(sc_vbox)

		# Linha de Título + Badge de Status
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		sc_vbox.add_child(top_row)

		var s_name := Label.new()
		s_name.text = "Classe Secreta #%d: %s" % [sec_id, s_info["name"]]
		s_name.add_theme_font_size_override("font_size", 13)
		s_name.add_theme_color_override("font_color", sc_col)
		top_row.add_child(s_name)

		var s_badge := Label.new()
		if class_id == sec_id:
			s_badge.text = "[ ✅ SUA CLASSE ATUAL ]"
			s_badge.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			s_badge.text = "[ 🔒 DESAFIO NO MUNDO ]"
			s_badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		s_badge.add_theme_font_size_override("font_size", 10)
		top_row.add_child(s_badge)

		# Títulos Evoluídos (T5 e T6)
		var evs: Dictionary = s_info.get("evolved_titles", {})
		var t_row := Label.new()
		t_row.text = "Evoluções: Tier 5 Única [%s]  ➔  Tier 6 Lendária [%s]" % [evs.get(5, "Única"), evs.get(6, "Lendária")]
		t_row.add_theme_font_size_override("font_size", 10)
		t_row.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		sc_vbox.add_child(t_row)

		# Descrição
		var s_desc := Label.new()
		s_desc.text = s_info["desc"]
		s_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_desc.add_theme_font_size_override("font_size", 11)
		s_desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
		sc_vbox.add_child(s_desc)

		# Passiva Exclusiva
		var pass_data: Dictionary = s_info.get("passive", {})
		var pass_l := Label.new()
		pass_l.text = "🛡️ Passiva Exclusiva: %s — %s\n📈 %s" % [pass_data.get("name", ""), pass_data.get("desc", ""), pass_data.get("tier_scaling", "")]
		pass_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pass_l.add_theme_font_size_override("font_size", 10)
		pass_l.add_theme_color_override("font_color", Color(0.45, 0.95, 0.65))
		sc_vbox.add_child(pass_l)

		# 3 Skills Ativas
		var sk_l := Label.new()
		var q_data: Dictionary = s_info.get("q", {})
		var r_data: Dictionary = s_info.get("r", {})
		var f_data: Dictionary = s_info.get("f", {})
		sk_l.text = "⚡ Habilidades Ativas: [Q] %s | [R] %s | [F] %s" % [q_data.get("name", ""), r_data.get("name", ""), f_data.get("name", "")]
		sk_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sk_l.add_theme_font_size_override("font_size", 10)
		sk_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		sc_vbox.add_child(sk_l)

		# Caixa de Dica / Desafio de Obtenção (com estilo especial em dourado)
		var hint_panel := PanelContainer.new()
		var hp_style := StyleBoxFlat.new()
		hp_style.bg_color = Color(0.12, 0.1, 0.05, 0.85)
		hp_style.border_color = Color(0.9, 0.75, 0.25, 0.8)
		hp_style.set_border_width_all(1)
		hp_style.set_corner_radius_all(4)
		hp_style.content_margin_left = 10
		hp_style.content_margin_right = 10
		hp_style.content_margin_top = 6
		hp_style.content_margin_bottom = 6
		hint_panel.add_theme_stylebox_override("panel", hp_style)
		sc_vbox.add_child(hint_panel)

		var hint_lbl := Label.new()
		hint_lbl.text = "📜 COMO DESBLOQUEAR NO JOGO: %s\n⭐ BÔNUS: Reseta para Nível 1 com +10 StatPoints/Nível (Tier 5) e +12 StatPoints/Nível (Tier 6 Lendária)." % s_info.get("unlock_hint", "Desafio secreto.")
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.add_theme_font_size_override("font_size", 10)
		hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		hint_panel.add_child(hint_lbl)

# ABA 4: Customizar Slots de Ação
func _build_tab_4_customize_slots(race_id: int, class_id: int) -> void:
	var container: ScrollContainer = tab_containers[3]
	for ch in container.get_children():
		ch.queue_free()

	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		var p_bindings: Dictionary = world.local_player.get("skill_slot_bindings")
		if p_bindings and p_bindings.size() > 0:
			for k in p_bindings.keys():
				pending_keybinds[k] = p_bindings[k]

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(vbox)

	# Cabeçalho Informativo
	var header_panel := PanelContainer.new()
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	hp_style.border_color = Color(0.35, 0.75, 1.0, 0.8)
	hp_style.set_border_width_all(1)
	hp_style.set_corner_radius_all(8)
	hp_style.content_margin_left = 16
	hp_style.content_margin_right = 16
	hp_style.content_margin_top = 10
	hp_style.content_margin_bottom = 10
	header_panel.add_theme_stylebox_override("panel", hp_style)
	vbox.add_child(header_panel)

	var h_vbox := VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 4)
	header_panel.add_child(h_vbox)

	var h_title := Label.new()
	h_title.text = "🎯 CUSTOMIZAÇÃO DA BARRA DE AÇÃO & KEYBINDS"
	h_title.add_theme_font_size_override("font_size", 14)
	h_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	h_vbox.add_child(h_title)

	var h_sub := Label.new()
	h_sub.text = "Clique em um dos 5 Slots abaixo para selecioná-lo e, em seguida, escolha uma habilidade da sua gaveta para equipar!"
	h_sub.add_theme_font_size_override("font_size", 11)
	h_sub.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	h_vbox.add_child(h_sub)

	# Catálogo de Habilidades disponíveis para o jogador
	var class_info: Dictionary = CLASS_ACTIVE_SKILLS.get(class_id, CLASS_ACTIVE_SKILLS[0])
	var race_info: Dictionary = RACIAL_DETAILS.get(race_id, RACIAL_DETAILS[1])

	var available_skills := [
		{
			"action_id": 1,
			"name": class_info["basic"]["name"],
			"type": "Ataque Básico",
			"cost": class_info["basic"]["cost"],
			"cd": class_info["basic"]["cd"],
			"range": class_info["basic"]["range"],
			"desc": class_info["basic"]["desc"],
			"color": Color("#64b5f6")
		},
		{
			"action_id": 3,
			"name": class_info["q"]["name"],
			"type": "Habilidade Tática 1",
			"cost": class_info["q"]["cost"],
			"cd": class_info["q"]["cd"],
			"range": class_info["q"]["range"],
			"desc": class_info["q"]["desc"],
			"color": Color("#4fc3f7")
		},
		{
			"action_id": 4,
			"name": class_info["r"]["name"],
			"type": "Habilidade Tática 2",
			"cost": class_info["r"]["cost"],
			"cd": class_info["r"]["cd"],
			"range": class_info["r"]["range"],
			"desc": class_info["r"]["desc"],
			"color": Color("#81c784")
		},
		{
			"action_id": 5,
			"name": class_info["f"]["name"],
			"type": "Habilidade Suprema",
			"cost": class_info["f"]["cost"],
			"cd": class_info["f"]["cd"],
			"range": class_info["f"]["range"],
			"desc": class_info["f"]["desc"],
			"color": Color("#ffb74d")
		},
		{
			"action_id": 6,
			"name": race_info["skill_z_name"],
			"type": "Poder Racial Sagrado/Umbral",
			"cost": race_info["skill_z_cost"],
			"cd": "10.0s",
			"range": "5.5m Área / Cone",
			"desc": race_info["skill_z_desc"],
			"color": race_info["color"]
		},
		{
			"action_id": 2,
			"name": "Rolamento Tático [Shift]",
			"type": "Mobilidade / Esquiva",
			"cost": "20 Stamina",
			"cd": "1.2s",
			"range": "6.0m Salto",
			"desc": "Salto veloz com quadros de invulnerabilidade contra ataques de mobs e projéteis.",
			"color": Color("#e0e0e0")
		}
	]

	var get_skill_by_action := func(act_id: int) -> Dictionary:
		for s in available_skills:
			if s["action_id"] == act_id:
				return s
		return available_skills[0]

	# 1. Os 5 Slots da Barra
	var slots_title := Label.new()
	slots_title.text = "1. SELECIONE O SLOT DA BARRA DE AÇÃO:"
	slots_title.add_theme_font_size_override("font_size", 12)
	slots_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(slots_title)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(slots_hbox)

	var slot_defs := [
		{"key": "LMB", "label": "Clique Esq (LMB)"},
		{"key": "Q", "label": "Tecla Q"},
		{"key": "R", "label": "Tecla R"},
		{"key": "F", "label": "Tecla F"},
		{"key": "Z", "label": "Tecla Z"}
	]

	for s_def in slot_defs:
		var skey: String = s_def["key"]
		var assigned_act: int = pending_keybinds.get(skey, 1)
		var current_skill: Dictionary = get_skill_by_action.call(assigned_act)
		var is_selected: bool = (selected_custom_slot == skey)

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(170, 95)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var s_style := StyleBoxFlat.new()
		s_style.set_corner_radius_all(8)
		s_style.content_margin_left = 10
		s_style.content_margin_right = 10
		s_style.content_margin_top = 8
		s_style.content_margin_bottom = 8

		if is_selected:
			s_style.bg_color = Color(0.18, 0.28, 0.45, 0.98)
			s_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
			s_style.set_border_width_all(3)
		else:
			s_style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
			s_style.border_color = Color(0.25, 0.35, 0.5, 0.5)
			s_style.set_border_width_all(1)

		slot_btn.add_theme_stylebox_override("normal", s_style)
		slot_btn.add_theme_stylebox_override("hover", s_style)
		slot_btn.add_theme_stylebox_override("pressed", s_style)

		var sel_key := skey
		slot_btn.pressed.connect(func():
			selected_custom_slot = sel_key
			_build_tab_4_customize_slots(race_id, class_id)
		)

		var s_inner_vbox := VBoxContainer.new()
		s_inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		s_inner_vbox.add_theme_constant_override("separation", 4)
		s_inner_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(s_inner_vbox)

		var badge := Label.new()
		badge.text = "[ %s ]" % s_def["label"]
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if is_selected else Color(0.65, 0.8, 1.0))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_inner_vbox.add_child(badge)

		var sk_name := Label.new()
		sk_name.text = current_skill["name"]
		sk_name.add_theme_font_size_override("font_size", 11)
		sk_name.add_theme_color_override("font_color", current_skill["color"])
		sk_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sk_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_inner_vbox.add_child(sk_name)

		var sk_type := Label.new()
		sk_type.text = current_skill["type"]
		sk_type.add_theme_font_size_override("font_size", 9)
		sk_type.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		sk_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_inner_vbox.add_child(sk_type)

		slots_hbox.add_child(slot_btn)

	vbox.add_child(HSeparator.new())

	# 2. Gaveta de Habilidades Desbloqueadas
	var drawer_title := Label.new()
	drawer_title.text = "2. GAVETA DE HABILIDADES DESBLOQUEADAS (Atribuir ao Slot '%s'):" % selected_custom_slot
	drawer_title.add_theme_font_size_override("font_size", 12)
	drawer_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	vbox.add_child(drawer_title)

	var skills_vbox := VBoxContainer.new()
	skills_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(skills_vbox)

	for sk in available_skills:
		var card := PanelContainer.new()
		var c_style := StyleBoxFlat.new()
		c_style.bg_color = Color(0.07, 0.09, 0.14, 0.9)
		c_style.border_color = Color(0.2, 0.3, 0.45, 0.5)
		c_style.set_border_width_all(1)
		c_style.set_corner_radius_all(6)
		c_style.content_margin_left = 12
		c_style.content_margin_right = 12
		c_style.content_margin_top = 8
		c_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", c_style)
		skills_vbox.add_child(card)

		var chbox := HBoxContainer.new()
		chbox.add_theme_constant_override("separation", 14)
		card.add_child(chbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		chbox.add_child(info_vbox)

		var row1 := HBoxContainer.new()
		row1.add_theme_constant_override("separation", 10)
		info_vbox.add_child(row1)

		var name_l := Label.new()
		name_l.text = sk["name"]
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.add_theme_color_override("font_color", sk["color"])
		row1.add_child(name_l)

		var type_l := Label.new()
		type_l.text = "• %s" % sk["type"]
		type_l.add_theme_font_size_override("font_size", 10)
		type_l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		row1.add_child(type_l)

		var stats_l := Label.new()
		stats_l.text = "Custo: %s | Recarga: %s | Alcance: %s" % [sk["cost"], sk["cd"], sk["range"]]
		stats_l.add_theme_font_size_override("font_size", 10)
		stats_l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5))
		info_vbox.add_child(stats_l)

		var desc_l := Label.new()
		desc_l.text = sk["desc"]
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.add_theme_font_size_override("font_size", 10)
		desc_l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		info_vbox.add_child(desc_l)

		var assign_btn := Button.new()
		assign_btn.text = " Equipar em [%s] " % selected_custom_slot
		assign_btn.custom_minimum_size = Vector2(140, 36)
		assign_btn.add_theme_font_size_override("font_size", 11)
		assign_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var act_id: int = sk["action_id"]
		assign_btn.pressed.connect(func():
			pending_keybinds[selected_custom_slot] = act_id
			_save_and_apply_keybinds()
			_build_tab_4_customize_slots(race_id, class_id)
		)
		chbox.add_child(assign_btn)

	vbox.add_child(HSeparator.new())

	# 3. Rodapé com Salvar e Restaurar
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(footer_hbox)

	var save_btn := Button.new()
	save_btn.text = " 💾 Salvar & Aplicar Slots de Ação "
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.custom_minimum_size = Vector2(0, 38)
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	save_btn.pressed.connect(func():
		_save_and_apply_keybinds()
		close_menu()
	)
	footer_hbox.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = " 🔄 Restaurar Padrão "
	reset_btn.custom_minimum_size = Vector2(180, 38)
	reset_btn.add_theme_font_size_override("font_size", 12)
	reset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset_btn.pressed.connect(func():
		pending_keybinds = {"LMB": 1, "Q": 3, "R": 4, "F": 5, "Z": 6}
		_save_and_apply_keybinds()
		_build_tab_4_customize_slots(race_id, class_id)
	)
	footer_hbox.add_child(reset_btn)

func _save_and_apply_keybinds() -> void:
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.apply_skill_keybinds(pending_keybinds)
	if world and world.has_method("_setup_action_bar"):
		world._setup_action_bar()
	if world and world.has_method("show_loot_toast"):
		world.show_loot_toast("Slots de Ação salvos e sincronizados com sucesso!")
